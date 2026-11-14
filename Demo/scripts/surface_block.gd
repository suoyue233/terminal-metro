extends Control
## A side-view street block. Buildings use the same placements in the foreground and parallax layer.

const InteriorLight = preload("res://scripts/surface_light.gdshader")
const AutoRepair = preload("res://scripts/auto_repair.gd")

signal pickup_requested(slot: int)
signal extraction_requested(station: String)
signal vehicle_requested(vehicle_id: String)
signal moved

const NORTH := 0
const MIDDLE := 1
const SOUTH := 2
const SIPING := "四平路"
const TONGJI := AutoRepair.STATION
const SEGMENT := 560.0
const CELL_NAMES := [
	["校园西街", "教学楼", TONGJI],
	["文具店", SIPING, "办公街"],
	["邮电新村", "学生宿舍", "沿街商铺"],
]
const WIDTH := SEGMENT * 3
const GROUND := 416.0
const FLOOR_HEIGHT := 110.0
const SPEED := 235.0
const REACH := 43.0
## Each alley joins its row to the next row at the same horizontal position.
const JUNCTIONS := [
	{"row": NORTH, "x": 478.0}, {"row": NORTH, "x": 1364.0},
	{"row": MIDDLE, "x": 324.0}, {"row": MIDDLE, "x": 908.0},
]
const STATIONS := [
	{"name": TONGJI, "row": NORTH, "x": 1542.0},
	{"name": SIPING, "row": MIDDLE, "x": 1042.0},
	{"name": "邮电新村", "row": SOUTH, "x": 88.0},
]
const BUILDINGS := [
	{"id": "lab", "row": NORTH, "name": "实习工坊", "x": 205.0, "width": 190.0, "floors": 1, "wall": Color("5e5a61")},
	{"id": "school", "row": NORTH, "name": "教学楼", "x": 574.0, "width": 266.0, "floors": 2, "wall": Color("736163")},
	{"id": "campus_shop", "row": NORTH, "name": "校门书店", "x": 1150.0, "width": 165.0, "floors": 1, "wall": Color("59576a")},
	{"id": "shop", "row": MIDDLE, "name": "文具店", "x": 88.0, "width": 198.0, "floors": 1, "wall": Color("635957")},
	{"id": "office", "row": MIDDLE, "name": "街道办事处", "x": 585.0, "width": 255.0, "floors": 2, "wall": Color("4d6061")},
	{"id": "tower", "row": MIDDLE, "name": "写字楼", "x": 1416.0, "width": 201.0, "floors": 2, "wall": Color("4b5964")},
	{"id": "service", "row": SOUTH, "name": "社区服务站", "x": 372.0, "width": 152.0, "floors": 1, "wall": Color("625957")},
	{"id": "dorm", "row": SOUTH, "name": "学生宿舍", "x": 600.0, "width": 267.0, "floors": 2, "wall": Color("655664")},
	{"id": "repair", "row": SOUTH, "name": "沿街维修铺", "x": 1224.0, "width": 235.0, "floors": 1, "wall": Color("635552")},
]
const LOOT := [
	{"x": 217.0, "row": SOUTH, "building": "", "floor": 0},
	{"x": 726.0, "row": SOUTH, "building": "dorm", "floor": 0},
	{"x": 745.0, "row": SOUTH, "building": "dorm", "floor": 1},
	{"x": 752.0, "row": MIDDLE, "building": "office", "floor": 1},
	{"x": 210.0, "row": MIDDLE, "building": "shop", "floor": 0},
	{"x": 719.0, "row": NORTH, "building": "school", "floor": 1},
	{"x": 1495.0, "row": MIDDLE, "building": "tower", "floor": 1},
	{"x": 1361.0, "row": SOUTH, "building": "repair", "floor": 0},
	{"x": 1265.0, "row": NORTH, "building": "campus_shop", "floor": 0},
	{"x": 272.0, "row": SOUTH, "building": "", "floor": 0},
]
const VEHICLES := [
	{"id": "dorm_sedan", "row": SOUTH, "x": 535.0, "color": Color("846268")},
	{"id": "repair_sedan", "row": SOUTH, "x": 1560.0, "color": Color("677378")},
	{"id": "office_sedan", "row": MIDDLE, "x": 1184.0, "color": Color("79777e")},
	{"id": "campus_sedan", "row": NORTH, "x": 1448.0, "color": Color("7d7562")},
]

var state
var font: Font
var row := SOUTH
var player_x := 88.0
var building := ""
var floor_index := 0
var facing := 1.0
var pace := 0.0
var visited: Dictionary = {}
var fares: Dictionary = {}
var shade: ColorRect
var lighting: ShaderMaterial
var inspecting_vehicle := false

static func supports(station: String) -> bool:
	return STATIONS.any(func(entry: Dictionary) -> bool: return entry.name == station)

func setup(owner_state: RefCounted, ui_font: Font) -> void:
	state = owner_state
	font = ui_font
	mouse_filter = MOUSE_FILTER_IGNORE
	for station in STATIONS:
		fares[station.name] = state.extraction_cost(station.name)
		if station.name == state.station:
			row = station.row
			player_x = station.x
	visited[cell()] = true
	shade = ColorRect.new()
	shade.name = "InteriorLight"
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	lighting = ShaderMaterial.new()
	lighting.shader = InteriorLight
	shade.material = lighting
	shade.hide()
	add_child(shade)

func cell() -> Vector2i:
	return Vector2i(street_column(player_x), row)

static func street_column(x: float) -> int:
	return clampi(floori(x / SEGMENT), 0, CELL_NAMES[0].size() - 1)

static func map_connections() -> Array[Array]:
	var connections: Array[Array] = []
	for street in range(CELL_NAMES.size()):
		for column in range(CELL_NAMES[street].size() - 1):
			connections.append([Vector2i(column, street), Vector2i(column + 1, street)])
	for junction in JUNCTIONS:
		var column := street_column(junction.x)
		var alley := [Vector2i(column, junction.row), Vector2i(column, junction.row + 1)]
		if not connections.has(alley):
			connections.append(alley)
	return connections

func junction_destination(junction: Dictionary) -> int:
	if row == junction.row:
		return row + 1
	if row == junction.row + 1:
		return row - 1
	return -1

func junction_caption(destination: int) -> String:
	return ["去北街", "去中街", "去南街"][destination]

func _process(delta: float) -> void:
	if not state.trip_active or inspecting_vehicle or get_viewport().gui_is_dragging():
		return
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	move_horizontal(float(right) - float(left), delta)

func move_horizontal(axis: float, delta: float) -> void:
	if is_zero_approx(axis):
		if not is_zero_approx(pace):
			pace = 0.0
			queue_redraw()
		return
	var location := active_building()
	var minimum := 24.0
	var maximum := WIDTH - 24.0
	if not location.is_empty():
		minimum = location.x + 12.0
		maximum = location.x + location.width - 12.0
	player_x = clampf(player_x + axis * SPEED * delta, minimum, maximum)
	facing = signf(axis)
	pace += delta * 14.0
	position_changed()

func position_changed() -> void:
	visited[cell()] = true
	update_lighting()
	queue_redraw()
	moved.emit()

func active_building() -> Dictionary:
	for entry in BUILDINGS:
		if entry.id == building:
			return entry
	return {}

func can_take(slot: int) -> bool:
	if slot < 0 or slot >= LOOT.size() or (not building.is_empty() and not state.flashlight_on):
		return false
	var point: Dictionary = LOOT[slot]
	return point.row == row and point.building == building and point.floor == floor_index and absf(player_x - point.x) <= REACH

func nearby_vehicle() -> String:
	if building.is_empty():
		for vehicle in VEHICLES:
			if row == vehicle.row and absf(player_x - vehicle.x) <= REACH:
				return vehicle.id
	return ""

func interaction() -> Dictionary:
	var location := active_building()
	for slot in range(LOOT.size()):
		if not can_take(slot):
			continue
		var item: String = state.ground_kind(slot)
		if not item.is_empty():
			return {"kind": "pickup", "slot": slot, "caption": "拾取 %s" % state.item_name(item)}
	if not location.is_empty():
		if location.floors > 1 and absf(player_x - stair_x(location)) <= REACH:
			return {"kind": "stairs", "caption": "上二楼" if floor_index == 0 else "下一楼"}
		if floor_index == 0 and absf(player_x - door_x(location)) <= REACH:
			return {"kind": "leave", "caption": "回到街道"}
		return {}
	for station in STATIONS:
		if row == station.row and absf(player_x - station.x) <= REACH:
			var cost: int = fares[station.name]
			var caption: String = "从%s站撤离" % station.name
			if cost > 0:
				caption += " · 耗 %d 度车电" % cost
			return {"kind": "extract", "station": station.name, "caption": caption}
	for junction in JUNCTIONS:
		var destination := junction_destination(junction)
		if destination >= 0 and absf(player_x - junction.x) <= REACH:
			return {"kind": "alley", "row": destination, "x": junction.x, "caption": "穿巷" + junction_caption(destination)}
	for entry in BUILDINGS:
		if row == entry.row and absf(player_x - door_x(entry)) <= REACH:
			return {"kind": "enter", "id": entry.id, "caption": "进入%s" % entry.name}
	var vehicle := nearby_vehicle()
	if not vehicle.is_empty():
		return {"kind": "vehicle", "id": vehicle, "caption": "检查废弃汽车"}
	return {}

func interact() -> void:
	var target := interaction()
	match target.get("kind", ""):
		"pickup": pickup_requested.emit(target.slot)
		"extract": extraction_requested.emit(target.station)
		"vehicle": vehicle_requested.emit(target.id)
		"stairs":
			floor_index = 1 - floor_index
			position_changed()
		"leave":
			building = ""
			position_changed()
		"alley":
			row = target.row
			player_x = target.x
			position_changed()
		"enter":
			building = target.id
			player_x = door_x(active_building())
			position_changed()

func door_x(entry: Dictionary) -> float:
	return entry.x + 27.0

func stair_x(entry: Dictionary) -> float:
	return entry.x + entry.width - 34.0

func camera_offset() -> float:
	return clampf(player_x - size.x * 0.5, 0.0, maxf(0.0, WIDTH - size.x))

func update_lighting() -> void:
	var location := active_building()
	shade.visible = not location.is_empty()
	if not shade.visible:
		return
	var height: float = location.floors * FLOOR_HEIGHT
	shade.position = Vector2(location.x - camera_offset(), GROUND - height)
	shade.size = Vector2(location.width, height)
	lighting.set_shader_parameter("interior_size", shade.size)
	lighting.set_shader_parameter("lamp_position", Vector2(player_x - location.x + 10.0 * facing, height - floor_index * FLOOR_HEIGHT - 29.0))
	lighting.set_shader_parameter("facing", facing)
	lighting.set_shader_parameter("lamp_on", state.flashlight_on)

func _draw() -> void:
	if state == null:
		return
	var camera_x := camera_offset()
	draw_rect(Rect2(Vector2.ZERO, size), Color("40394c"))
	draw_rect(Rect2(0, 120, size.x, 176), Color("675161"))
	draw_circle(Vector2(616 - camera_x * 0.09, 113), 29, Color("a97c76"))
	for i in range(28):
		var height := float(44 + (i * 57) % 119)
		draw_rect(Rect2(i * 54 - camera_x * 0.16, 278 - height, 46, height), Color("524555"))
	if row > NORTH:
		draw_set_transform(Vector2(24 - camera_x * 0.53, 24), 0.0, Vector2.ONE * 0.73)
		for entry in BUILDINGS:
			if entry.row == row - 1:
				draw_facade(entry, true)
		for station in STATIONS:
			if station.row == row - 1:
				draw_station(station, true)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(0, 323, size.x, 28), Color("514452"))
		draw_line(Vector2(0, 323), Vector2(size.x, 323), Color("746172"), 2.0)
	draw_set_transform(Vector2(-camera_x, 0))
	draw_rect(Rect2(0, GROUND, WIDTH, size.y - GROUND), Color("292738"))
	draw_rect(Rect2(0, GROUND, WIDTH, 13), Color("6d5b69"))
	draw_rect(Rect2(0, GROUND + 13, WIDTH, 16), Color("423b51"))
	for x in range(0, int(WIDTH), 96):
		draw_rect(Rect2(x, GROUND + 59, 46, 2), Color("665367"))
	for junction in JUNCTIONS:
		var destination := junction_destination(junction)
		if destination < 0:
			continue
		var x: float = junction.x
		draw_rect(Rect2(x - 24, GROUND - 52, 48, 52), Color("3b3445"))
		draw_rect(Rect2(x - 26, GROUND - 54, 52, 4), Color("847080"))
		sign_at(junction_caption(destination), x, GROUND - 60, 76, Color("483949"))
	for entry in BUILDINGS:
		if entry.row != row:
			continue
		if entry.id == building:
			draw_interior(entry)
		else:
			draw_facade(entry, false)
	for station in STATIONS:
		if station.row == row:
			draw_station(station, false)
	for vehicle in VEHICLES:
		if vehicle.row == row:
			draw_vehicle(vehicle)
	for slot in range(LOOT.size()):
		var point: Dictionary = LOOT[slot]
		var kind: String = state.ground_kind(slot)
		if point.row == row and point.building == building and (building.is_empty() or state.flashlight_on) and not kind.is_empty():
			var tint: Color = state.rarity_color(kind)
			draw_rect(Rect2(point.x - 9, GROUND - point.floor * FLOOR_HEIGHT - 12, 18, 10), tint.darkened(0.44))
			draw_line(Vector2(point.x - 8, GROUND - point.floor * FLOOR_HEIGHT - 12), Vector2(point.x + 8, GROUND - point.floor * FLOOR_HEIGHT - 12), tint, 2.0)
	draw_player(Vector2(player_x, GROUND - floor_index * FLOOR_HEIGHT))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(Vector2.ZERO, size), Color("726176"), false, 2.0)

func draw_vehicle(vehicle: Dictionary) -> void:
	var x: float = vehicle.x
	var y := GROUND
	var paint: Color = vehicle.color
	var tires_removed: bool = state.vehicle_part_taken(vehicle.id, "tire")
	draw_rect(Rect2(x - 64, y - 6, 128, 6), Color("332b3a"))
	for offset in [-37.0, 35.0]:
		draw_circle(Vector2(x + offset, y - 10), 7 if tires_removed else 13, Color("2e2b36"))
		draw_circle(Vector2(x + offset, y - 10), 5, Color("817481"))
	var body := PackedVector2Array([
		Vector2(x - 60, y - 15), Vector2(x - 61, y - 34), Vector2(x - 43, y - 41),
		Vector2(x - 29, y - 59), Vector2(x + 17, y - 59), Vector2(x + 36, y - 40),
		Vector2(x + 57, y - 33), Vector2(x + 59, y - 15),
	])
	draw_colored_polygon(body, paint)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 39, y - 40), Vector2(x - 25, y - 55), Vector2(x + 14, y - 55), Vector2(x + 30, y - 40),
	]), Color("373642"))
	draw_rect(Rect2(x - 7, y - 55, 4, 16), paint)
	draw_rect(Rect2(x - 52, y - 22, 105, 3), paint.darkened(0.35))
	draw_rect(Rect2(x + 48, y - 31, 9, 5), Color("d0b592"))
	draw_rect(Rect2(x - 60, y - 33, 8, 5), Color("a96967"))
	if state.vehicle_part_taken(vehicle.id, "steel_plate"):
		draw_rect(Rect2(x - 21, y - 36, 40, 12), Color("413844"))

func draw_facade(entry: Dictionary, distant: bool) -> void:
	var top: float = GROUND - entry.floors * FLOOR_HEIGHT
	var wall: Color = entry.wall.lerp(Color("735f72"), 0.68) if distant else entry.wall
	draw_rect(Rect2(entry.x, top, entry.width, GROUND - top), wall)
	draw_rect(Rect2(entry.x - 4, top, entry.width + 8, 8), wall.lightened(0.24))
	draw_rect(Rect2(entry.x + entry.width - 10, top + 8, 10, GROUND - top - 8), wall.darkened(0.22))
	for level in range(entry.floors):
		var y := GROUND - level * FLOOR_HEIGHT
		draw_rect(Rect2(entry.x, y - 9, entry.width, 9), wall.darkened(0.22))
		for x in range(57, int(entry.width) - 37, 55):
			var window := Rect2(entry.x + x, y - 75, 37, 47)
			draw_rect(window.grow(3), wall.lightened(0.19))
			draw_rect(window, wall.darkened(0.46))
			draw_line(window.position + Vector2(18, 0), window.position + Vector2(18, 47), wall.lightened(0.1), 2.0)
			draw_rect(Rect2(window.position + Vector2(2, 28), Vector2(15, 17)), wall.lightened(0.13))
	draw_door(door_x(entry), GROUND, wall)
	sign_at(entry.name, entry.x + entry.width * 0.55, GROUND - 12, 110, wall.darkened(0.35))

func draw_station(entry: Dictionary, distant: bool) -> void:
	var x: float = entry.x
	var color := Color("65576e") if distant else Color("544460")
	draw_rect(Rect2(x - 46, GROUND - 79, 92, 79), color)
	draw_rect(Rect2(x - 51, GROUND - 84, 102, 9), color.lightened(0.32))
	draw_rect(Rect2(x - 30, GROUND - 46, 60, 46), color.darkened(0.56))
	for i in range(4):
		draw_rect(Rect2(x - 29, GROUND - 6 - i * 9, 58, 2), color.lightened(0.13))
	sign_at(entry.name + "站", x, GROUND - 53, 90, color.darkened(0.24))

func draw_door(x: float, y: float, wall: Color) -> void:
	draw_rect(Rect2(x - 15, y - 57, 30, 57), wall.darkened(0.48))
	draw_rect(Rect2(x - 15, y - 57, 30, 4), wall.lightened(0.31))
	draw_rect(Rect2(x + 7, y - 30, 4, 3), Color("c9a382"))

func draw_interior(entry: Dictionary) -> void:
	var top: float = GROUND - entry.floors * FLOOR_HEIGHT
	draw_rect(Rect2(entry.x, top, entry.width, GROUND - top), Color("534150"))
	for level in range(entry.floors):
		var y := GROUND - level * FLOOR_HEIGHT
		var light := Color("96727b") if level == floor_index else Color("685260")
		draw_rect(Rect2(entry.x + 8, y - 98, entry.width - 16, 97), light)
		draw_rect(Rect2(entry.x + 8, y - 24, entry.width - 16, 23), light.darkened(0.22))
		draw_rect(Rect2(entry.x, y - 3, entry.width, 8), Color("463947"))
		draw_rect(Rect2(entry.x + 63, y - 80, 54, 37), Color("b39b9b").lerp(light, 0.26))
		draw_line(Vector2(entry.x + 90, y - 80), Vector2(entry.x + 90, y - 43), light, 3.0)
		draw_rect(Rect2(entry.x + 71, y - 28, 63, 7), Color("563e4a"))
		draw_rect(Rect2(entry.x + 76, y - 21, 5, 18), Color("563e4a"))
		draw_rect(Rect2(entry.x + 125, y - 21, 5, 18), Color("563e4a"))
		draw_rect(Rect2(entry.x + 155, y - 47, 22, 45), light.darkened(0.44))
		draw_line(Vector2(entry.x + 155, y - 24), Vector2(entry.x + 177, y - 24), light, 2.0)
	draw_rect(Rect2(entry.x - 4, top, entry.width + 8, 8), Color("897383"))
	draw_door(door_x(entry), GROUND, entry.wall)
	if entry.floors > 1:
		var x := stair_x(entry)
		for step in range(10):
			draw_rect(Rect2(x - 46 + step * 5, GROUND - 4 - step * 11, 20, 4), Color("5b4855"))
		draw_line(Vector2(x - 48, GROUND - 22), Vector2(x + 3, GROUND - FLOOR_HEIGHT - 19), Color("bb9290"), 2.0)
		sign_at("楼梯", x, GROUND - 51, 42, Color("594353"))

func sign_at(caption: String, x: float, bottom: float, width: float, fill: Color) -> void:
	draw_rect(Rect2(x - width / 2.0, bottom - 21, width, 21), fill)
	draw_string(font, Vector2(x - width / 2.0, bottom - 5), caption, HORIZONTAL_ALIGNMENT_CENTER, width, 13, Color("efdbcc"))

func draw_player(at: Vector2) -> void:
	var stride := roundf(sin(pace) * 4.0)
	draw_rect(Rect2(at + Vector2(-10, -26), Vector2(9, 18)), Color("536c6f"))
	draw_rect(Rect2(at + Vector2(-6, -29), Vector2(15, 21)), Color("b9b79b"))
	draw_rect(Rect2(at + Vector2(-6, -41), Vector2(15, 14)), Color("d4d0af"))
	draw_rect(Rect2(at + Vector2(facing * 4 - 5, -37), Vector2(11, 6)), Color("273746"))
	draw_rect(Rect2(at + Vector2(facing * 6, -36), Vector2(3, 3)), Color("efc481"))
	draw_rect(Rect2(at + Vector2(-6 + stride, -9), Vector2(6, 9)), Color("314652"))
	draw_rect(Rect2(at + Vector2(3 - stride, -9), Vector2(6, 9)), Color("41505e"))
