extends Control

const State = preload("res://scripts/cabin_state.gd")
const Rail = preload("res://scripts/cabin_map.gd")
const CargoGrid = preload("res://scripts/cargo_grid.gd")
const SurfaceBlock = preload("res://scripts/surface_block.gd")
const SurfaceMinimap = preload("res://scripts/surface_minimap.gd")
const AutoRepair = preload("res://scripts/auto_repair.gd")
const CABIN = preload("res://art/cabin.png")

const TEXT := Color("f2eadd")
const MUTED := Color("b9b3cb")
const AMBER := Color("f0cc91")
const MINT := Color("a6dccc")
const DARK := Color("211f31")
const BORDER := Color("514b67")
const HOTSPOTS := [
	["柜子", Rect2(9, 128, 25, 76), Vector2(210, 522), "locker"],
	["出站探索", Rect2(66, 123, 63, 78), Vector2(453, 522), "gear"],
	["交易", Rect2(144, 123, 101, 49), Vector2(874, 350), "trade"],
	["电脑", Rect2(158, 176, 23, 18), Vector2(802, 571), "news"],
	["休息存档", Rect2(182, 185, 62, 10), Vector2(984, 571), "rest"],
]
const LOOT_SPOTS := [Vector2(114, 348), Vector2(266, 380), Vector2(400, 335), Vector2(563, 397), Vector2(681, 335), Vector2(710, 455)]
const RADIATION := ["", "低", "中", "高"]

var state := State.new()
var font: SystemFont
var view: Control
var screen := ""
var selection: Dictionary = {}
var grids: Array[Control] = []
var status: Label
var time_label: Label
var selected_station := ""
var outside_tab := false
var trade_supplies := false
var loadout: Dictionary = {}
var save_path: String
var pointer_position := Vector2.ZERO
var surface_block: SurfaceBlock
var surface_pack: Control
var surface_location: Label
var surface_prompt: Label
var flashlight_button: Button
var battery_panel: Control
var battery_slot_open := false
var wrench_button: Button
var vehicle_panel: Control

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	theme = ui_theme
	var directory := OS.get_executable_path().get_base_dir() if OS.has_feature("template") else ProjectSettings.globalize_path("res://")
	save_path = directory.path_join("saves/cabin_slot.json")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-file="):
			save_path = argument.trim_prefix("--save-file=")
	var has_save := FileAccess.file_exists(save_path)
	var loaded := state.load_cabin(save_path, Rail.STATIONS.keys())
	if not state.game_over_reason.is_empty():
		show_game_over()
	elif not FileAccess.file_exists(save_path + ".rules_seen"):
		show_rules("读取存档失败，已开始新游戏。" if has_save and not loaded else "")
	else:
		show_cabin("读取存档失败，已开始新游戏。" if has_save and not loaded else "")

func _process(delta: float) -> void:
	if screen == "surface" and not check_trip_timeout():
		update_trip_clock()
		var charge := state.installed_charge
		var was_lit := state.flashlight_on
		state.tick_flashlight(delta)
		if was_lit != state.flashlight_on:
			refresh_surface_light()
			report("手电筒电池已耗尽。")
		elif charge != state.installed_charge:
			refresh_equipment()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		pointer_position = event.position
	if event is InputEventMouseButton and event.pressed and not selection.is_empty():
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			rotate_selection()
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		var window := get_window()
		window.mode = Window.MODE_MAXIMIZED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	elif event.physical_keycode == KEY_E and screen == "surface" and is_instance_valid(surface_block):
		if not check_trip_timeout() and not is_instance_valid(vehicle_panel):
			surface_block.interact()
	elif event.physical_keycode in [KEY_1, KEY_KP_1] and screen == "surface":
		if not check_trip_timeout():
			var problem := state.toggle_flashlight()
			refresh_surface_light()
			report(problem)
	elif event.keycode == KEY_ESCAPE and is_instance_valid(vehicle_panel):
		close_vehicle()
	elif event.keycode == KEY_ESCAPE and not selection.is_empty():
		clear_selection()
	elif event.keycode == KEY_R and not selection.is_empty():
		rotate_selection()
	elif event.keycode == KEY_ESCAPE and screen == "news":
		show_map()
	elif event.keycode == KEY_ESCAPE and screen == "rules":
		dismiss_rules()
	elif event.keycode == KEY_ESCAPE and screen not in ["cabin", "surface", "game_over"]:
		show_cabin()
	else:
		return
	get_viewport().set_input_as_handled()

func style(fill: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	return box

func put(parent: Control, node: Control, bounds: Rect2) -> void:
	node.position = bounds.position
	node.size = bounds.size
	parent.add_child(node)

func plate(parent: Control, bounds: Rect2, color: Color, edge: Color = Color.TRANSPARENT) -> Panel:
	var block := Panel.new()
	block.mouse_filter = MOUSE_FILTER_IGNORE
	block.add_theme_stylebox_override("panel", style(color, edge))
	put(parent, block, bounds)
	return block

func label(parent: Control, message: String, bounds: Rect2, pixels: int, color: Color = TEXT, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var node := Label.new()
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.text = message
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", color)
	put(parent, node, bounds)
	return node

func wrapped(parent: Control, message: String, bounds: Rect2, pixels: int, color: Color = TEXT) -> Label:
	var node := label(parent, message, bounds, pixels, color, HORIZONTAL_ALIGNMENT_LEFT, true)
	node.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return node

func button_style(node: Button, prominent: bool = false) -> void:
	var fill := Color("463759") if prominent else Color("302b43")
	node.add_theme_stylebox_override("normal", style(fill, AMBER if prominent else BORDER))
	node.add_theme_stylebox_override("hover", style(Color("594861"), AMBER))
	node.add_theme_stylebox_override("pressed", style(Color("6a5270"), AMBER))
	node.add_theme_stylebox_override("disabled", style(Color("29263a"), Color("3b364b")))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, AMBER, 2))
	node.add_theme_color_override("font_color", AMBER if prominent else TEXT)
	node.add_theme_color_override("font_hover_color", TEXT)
	node.add_theme_color_override("font_disabled_color", Color("8f889f"))
	node.add_theme_font_size_override("font_size", 16)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func action(parent: Control, caption: String, bounds: Rect2, callback: Callable, prominent: bool = false) -> Button:
	var node := Button.new()
	node.text = caption
	button_style(node, prominent)
	node.pressed.connect(callback)
	put(parent, node, bounds)
	return node

func invisible_action(parent: Control, area: Rect2, callback: Callable) -> Button:
	var hit := action(parent, "", area, callback)
	hit.focus_mode = Control.FOCUS_NONE
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", style(Color(AMBER, 0.1), Color(AMBER, 0.85), 2))
	hit.add_theme_stylebox_override("pressed", style(Color(AMBER, 0.18), AMBER, 2))
	return hit

func cabin_art() -> void:
	var art := TextureRect.new()
	art.texture = CABIN
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = MOUSE_FILTER_IGNORE
	put(view, art, Rect2(0, 0, 1280, 720))

func begin_page(kind: String) -> void:
	if is_instance_valid(view):
		view.hide()
		view.queue_free()
	if kind != "surface":
		surface_block = null
		battery_slot_open = false
		vehicle_panel = null
	screen = kind
	selection = {}
	grids.clear()
	status = null
	time_label = null
	view = Control.new()
	view.name = kind.capitalize()
	view.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func report(message: String, color: Color = AMBER) -> void:
	if is_instance_valid(status):
		status.text = message
		status.add_theme_color_override("font_color", color)

func energy_text(amount: float) -> String:
	var rounded := snappedf(amount, 0.1)
	return str(roundi(rounded)) if is_equal_approx(rounded, roundf(rounded)) else str(rounded)

func car_power_text() -> String:
	return "%s / %d 度" % [energy_text(state.car_power), State.CAR_CAPACITY]

func power(parent: Control, at: Vector2, title: String, value: String, tint: Color) -> void:
	plate(parent, Rect2(at, Vector2(232, 64)), Color("242135"), BORDER)
	plate(parent, Rect2(at, Vector2(3, 64)), tint)
	label(parent, title, Rect2(at + Vector2(15, 0), Vector2(75, 64)), 15, MUTED)
	label(parent, value, Rect2(at + Vector2(84, 0), Vector2(133, 64)), 20, tint, HORIZONTAL_ALIGNMENT_RIGHT)

func show_cabin(message: String = "") -> void:
	begin_page("cabin")
	cabin_art()
	label(view, "终末地铁", Rect2(156, 59, 420, 60), 44)
	label(view, "%s   /   %s   /   %s" % [state.station, state.date_text(), state.weather()], Rect2(159, 126, 560, 26), 20, MINT)
	power(view, Vector2(641, 80), "车内电源", car_power_text(), MINT)
	power(view, Vector2(889, 80), "账户余额", "%s 度" % energy_text(state.account), AMBER)
	var water := action(view, "已喝水" if state.drank_today else "喝水 · %d" % state.supply_count("water"),
		Rect2(156, 163, 126, 33), use_supply.bind("water"))
	water.disabled = state.drank_today
	var ration := action(view, "已进食" if state.ate_today else "进食 · %d" % state.supply_count("ration"),
		Rect2(294, 163, 126, 33), use_supply.bind("ration"))
	ration.disabled = state.ate_today
	var has_charger := state.has_charger(state.station)
	action(view, "充电站" if has_charger else "找充电站", Rect2(432, 163, 126, 33),
		show_charger.bind("") if has_charger else find_charger)
	action(view, "电池充电", Rect2(570, 163, 126, 33), show_battery_charger.bind(""))
	var skill_caption := "汽修培训" if state.station == AutoRepair.STATION else "技能"
	action(view, skill_caption, Rect2(710, 163, 126, 33), show_skills.bind(""), state.station == AutoRepair.STATION)
	if state.is_blackout():
		label(view, "今日停电", Rect2(848, 163, 92, 33), 15, AMBER)
	if state.debt > 0.0:
		label(view, "待还欠费  %s 度" % energy_text(state.debt), Rect2(946, 163, 174, 33), 16, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	label(view, "%s\n%s\n%s" % [state.station, state.date_text(), state.weather()],
		Rect2(268, 300, 100, 73), 13, Color("322d3d"), HORIZONTAL_ALIGNMENT_CENTER)
	for spot in HOTSPOTS:
		var area: Rect2 = spot[1]
		area.position = (area.position + Vector2(32, -54)) * 4.0
		area.size *= 4.0
		var hotspot := invisible_action(view, area.grow(4), use_hotspot.bind(spot[3]))
		hotspot.tooltip_text = spot[0]
		var tag_width := 92.0 if String(spot[0]).length() > 2 else 59.0
		var tag := action(view, spot[0], Rect2(Vector2(spot[2]) - Vector2(tag_width / 2.0, 0), Vector2(tag_width, 32)), use_hotspot.bind(spot[3]))
		tag.add_theme_font_size_override("font_size", 14)
	if not message.is_empty():
		plate(view, Rect2(208, 647, 864, 38), Color("211f31e8"), BORDER)
		label(view, message, Rect2(222, 647, 836, 38), 16, MINT, HORIZONTAL_ALIGNMENT_CENTER)

func use_supply(kind: String) -> void:
	var problem := state.consume_supply(kind)
	var success := "今日已喝水。" if kind == "water" else "今日已进食。"
	show_cabin(success if problem.is_empty() else problem)

func show_skills(message: String = "") -> void:
	begin_page("skills")
	var panel := modal("技能树", Rect2(168, 94, 944, 530))
	var at_school := state.station == AutoRepair.STATION
	label(panel, "同济大学站 · 汽修培训", Rect2(24, 81, 470, 30), 18, MINT)
	label(panel, "账户余额 %s 度" % energy_text(state.account), Rect2(575, 81, 345, 30), 17, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	for branch in range(4):
		var x := 24 + branch * 226
		var active := branch == 0
		plate(panel, Rect2(x, 124, 218, 44), Color("3e334c") if active else Color("292738"), AMBER if active else BORDER)
		if active:
			label(panel, "汽修  ·  %d 级" % state.auto_repair_level, Rect2(x, 124, 218, 44), 19, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
		for index in range(AutoRepair.COURSES.size()):
			var level := index + 1
			var y := 181 + index * 91
			var learned := active and level <= state.auto_repair_level
			var available := active and level == state.auto_repair_level + 1
			var edge := MINT if learned else AMBER if available else BORDER
			plate(panel, Rect2(x + 108, y - 13, 2, 13), edge)
			plate(panel, Rect2(x, y, 218, 78), Color("322a40") if active else Color("292738"), edge)
			if not active:
				continue
			var course: Dictionary = AutoRepair.COURSES[index]
			label(panel, "%d 级 · %s" % [level, course.name], Rect2(x + 10, y + 3, 198, 24), 15, MINT if learned else TEXT)
			label(panel, AutoRepair.course_parts(course), Rect2(x + 10, y + 28, 198, 21), 13, MUTED)
			if available and at_school:
				var enroll := action(panel, "报名 · %d 度" % course.fee, Rect2(x + 10, y + 49, 198, 24), enroll_course.bind(level), true)
				enroll.add_theme_font_size_override("font_size", 13)
				enroll.disabled = state.account < course.fee
			else:
				var caption := "已掌握" if learned else "到同济大学站报名" if available else "需先学习上一级"
				label(panel, caption, Rect2(x + 10, y + 50, 198, 22), 12, MINT if learned else MUTED)
	status = label(panel, "", Rect2(24, 457, 896, 39), 16, AMBER)
	report(message)

func enroll_course(level: int) -> void:
	var problem := state.enroll_auto_repair(level)
	var message := "已掌握汽修 %d 级。" % level
	if level == 1:
		message += " 培训点已发放扳手，可在出站时携带。"
	show_skills(message if problem.is_empty() else problem)

func use_hotspot(kind: String) -> void:
	match kind:
		"locker": show_locker()
		"trade":
			trade_supplies = false
			show_trade()
		"rest": show_rest()
		"gear":
			loadout = {"heavy": false, "wide": state.wide_bag, "light": true, "crowbar": true, "wrench": state.auto_repair_level > 0}
			show_gear()
		"news":
			selected_station = ""
			outside_tab = false
			show_news()

func overlay(parent: Control, color: Color) -> void:
	var blocker := ColorRect.new()
	blocker.color = color
	blocker.mouse_filter = MOUSE_FILTER_STOP
	put(parent, blocker, Rect2(0, 0, 1280, 720))

func modal(title: String, bounds: Rect2, on_close: Callable = Callable()) -> Panel:
	cabin_art()
	overlay(view, Color("0d0b16ae"))
	var frame := plate(view, bounds, DARK, BORDER)
	label(frame, title, Rect2(24, 13, bounds.size.x - 130, 44), 28)
	action(frame, "关闭", Rect2(bounds.size.x - 88, 18, 64, 34), on_close if on_close.is_valid() else show_cabin.bind(""))
	plate(frame, Rect2(24, 66, bounds.size.x - 48, 1), BORDER)
	return frame

func show_rules(message: String) -> void:
	begin_page("rules")
	var panel := modal("简要规则", Rect2(302, 99, 676, 522), dismiss_rules)
	var rules := [
		["用电与欠费", "行车每站耗 %d 度，电脑每天耗 %d 度。充电、购物和租防护服时，余额不足可挂账。七号电池在车内充。" % [State.TRAVEL_COST_PER_STOP, State.COMPUTER_DAILY_COST]],
		["限时探索", "每次出站限时 %d 秒。出站必带装有七号电池的手电筒，按 1 开关照明。" % state.trip_limit()],
		["超时赔偿", "超时丢失随身物品。普通防护服赔偿 300 度，加强型 500 度，余额不足记作欠费。"],
		["每日生存", "每天喝水、进食，睡觉时结算。连续两天未喝水或欠费、连续三天未进食都会结束本轮。"],
	]
	for index in range(rules.size()):
		var y := 83 + index * 89
		label(panel, rules[index][0], Rect2(24, y, 628, 25), 18, MINT)
		wrapped(panel, rules[index][1], Rect2(24, y + 28, 628, 53), 16, TEXT)
	if not message.is_empty():
		label(panel, message, Rect2(24, 440, 628, 21), 14, AMBER)
	action(panel, "开始游戏", Rect2(24, 466, 628, 41), dismiss_rules, true)

func dismiss_rules() -> void:
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var seen := FileAccess.open(save_path + ".rules_seen", FileAccess.WRITE)
	if seen != null:
		seen.store_string("seen\n")
		seen.close()
	show_cabin()

func show_charger(message: String = "") -> void:
	begin_page("charger")
	var panel := modal("车辆充电 · %s" % state.station, Rect2(300, 148, 680, 424))
	var supply := state.charger_stock(state.station)
	var limit := state.car_charge_limit()
	var service := "本站今日剩余 %s 度" % energy_text(supply)
	if state.is_blackout():
		service = "今日停电，充电站暂停。"
	label(panel, service, Rect2(24, 85, 632, 33), 21, MINT if supply > 0 else AMBER)
	label(panel, "车内电源  %s" % car_power_text(), Rect2(24, 132, 302, 31), 19)
	label(panel, "账户余额  %s 度" % energy_text(state.account), Rect2(340, 132, 316, 31), 19, AMBER)
	label(panel, "充入多少就扣多少，账户不足的部分记为欠费。",
		Rect2(24, 180, 632, 25), 15, MUTED)
	vehicle_charge_option(panel, "充入", 30.0, limit, Rect2(24, 223, 170, 44))
	vehicle_charge_option(panel, "充入", 100.0, limit, Rect2(206, 223, 178, 44))
	vehicle_charge_option(panel, "充到上限", limit, limit, Rect2(396, 223, 260, 44), true)
	label(panel, "待还欠费  %s 度" % energy_text(state.debt), Rect2(24, 300, 410, 36), 17, AMBER)
	action(panel, "查其他充电站", Rect2(474, 300, 182, 36), find_charger)
	status = label(panel, "", Rect2(24, 359, 632, 32), 16, AMBER)
	report(message)

func vehicle_charge_option(parent: Control, title: String, amount: float, limit: float, bounds: Rect2, prominent: bool = false) -> void:
	var shortfall := state.credit_shortfall(amount)
	var caption := "%s %s 度" % [title, energy_text(amount)]
	var enabled := amount > 0.0 and amount <= limit
	if enabled and shortfall > 0.0:
		caption += " · 欠 %s 度" % energy_text(shortfall)
	var button := action(parent, caption, bounds, charge_vehicle.bind(amount), prominent)
	button.disabled = not enabled

func added_debt_note(previous_debt: float) -> String:
	var amount := state.debt - previous_debt
	return " · 新增欠费 %s 度" % energy_text(amount) if amount > 0.0 else ""

func charge_vehicle(requested: float) -> void:
	var previous_debt := state.debt
	var amount := state.charge_car(requested)
	var message := "已充入 %s 度%s" % [energy_text(amount), added_debt_note(previous_debt)]
	show_charger(message if amount > 0.0 else "当前无法向车辆充电。")

func show_battery_charger(message: String = "") -> void:
	begin_page("battery_charger")
	var panel := modal("电池充电 · 车内电源", Rect2(300, 126, 680, 478))
	label(panel, "半电池补满消耗 1 度，空电池消耗 2 度。", Rect2(24, 83, 620, 27), 17, MINT)
	charge_row(panel, "手电筒电池", State.NO_CELL, state.installed_charge, Rect2(24, 124, 609, 42))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	put(panel, scroll, Rect2(24, 181, 632, 187))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var index := 0
	for entry in state.inventory:
		if entry.kind != "aaa":
			continue
		index += 1
		var row := Control.new()
		row.custom_minimum_size.y = 47
		rows.add_child(row)
		charge_row(row, "备用电池 %d" % index, entry.id, entry.charge, Rect2(0, 0, 609, 42))
	if index == 0:
		label(panel, "背包里没有备用电池。", Rect2(24, 184, 632, 32), 15, MUTED)
	label(panel, "车内电源  %s" % car_power_text(), Rect2(24, 382, 632, 27), 17, AMBER)
	status = label(panel, "", Rect2(24, 424, 632, 31), 16, AMBER)
	report(message)

func charge_row(parent: Control, title: String, id: int, charge: int, bounds: Rect2) -> void:
	var text := "未装入" if charge == State.NO_CELL else "%d%%" % charge
	label(parent, "%s · %s" % [title, text], Rect2(bounds.position, Vector2(330, bounds.size.y)), 16)
	var cost := state.battery_fill_cost(charge)
	var caption := "充满 · %s 度" % energy_text(cost) if cost > 0.0 else "充电"
	var charge_button := action(parent, caption,
		Rect2(bounds.position + Vector2(bounds.size.x - 158, 0), Vector2(158, bounds.size.y)), charge_battery.bind(id))
	charge_button.disabled = cost <= 0.0 or state.car_power < cost

func charge_battery(id: int) -> void:
	var problem := state.recharge_battery(id)
	show_battery_charger("电池已充满。" if problem.is_empty() else problem)

func find_charger() -> void:
	var routes := Rail.routes_from(state.station)
	var nearest := ""
	for location in routes:
		if location == state.station or not state.has_charger(location):
			continue
		if nearest.is_empty():
			nearest = location
		var travel_cost: int = (routes[location].size() - 1) * State.TRAVEL_COST_PER_STOP
		if state.charger_stock(location) > 0.0 and state.car_power >= travel_cost:
			open_market_map(location)
			return
	if not nearest.is_empty():
		open_market_map(nearest)

func show_rest() -> void:
	begin_page("rest")
	var panel := modal("休息与存档", Rect2(340, 180, 600, 360))
	label(panel, "醒来日期   %s" % state.date_text(1), Rect2(24, 85, 480, 34), 20, MINT)
	var after := state.survival_after_day()
	label(panel, "今日饮水 · %s     结算后连续未喝 %d / 2 天" % ["已喝" if state.drank_today else "未喝", after.days_without_water],
		Rect2(24, 129, 552, 26), 16, MUTED)
	label(panel, "今日进食 · %s     结算后连续未吃 %d / 3 天" % ["已吃" if state.ate_today else "未吃", after.days_without_food],
		Rect2(24, 163, 552, 26), 16, MUTED)
	label(panel, "待还欠费 %s 度     结算后连续欠费 %d / 2 天" % [energy_text(state.debt), after.days_in_debt],
		Rect2(24, 197, 552, 26), 16, MUTED)
	label(panel, "电脑每日耗电 %d 度     结算后车内剩余 %s 度" % [State.COMPUTER_DAILY_COST, energy_text(state.overnight_power())],
		Rect2(24, 231, 552, 26), 16, MUTED)
	status = label(panel, "", Rect2(24, 259, 552, 26), 15, AMBER)
	report("今晚结算会结束本轮。" if not after.game_over_reason.is_empty() else "")
	action(panel, "睡到下一天并保存", Rect2(24, 290, 552, 43), sleep_and_save, true)

func sleep_and_save() -> void:
	var err := state.save_next_day(save_path)
	if err == OK:
		if state.game_over_reason.is_empty():
			show_cabin("已保存 · %s" % state.date_text())
		else:
			show_game_over()
	else:
		report("存档写入失败（%s）。" % error_string(err))

func show_game_over() -> void:
	begin_page("game_over")
	cabin_art()
	overlay(view, Color("0d0b16c9"))
	var panel := plate(view, Rect2(340, 205, 600, 310), DARK, BORDER)
	label(panel, "游戏结束", Rect2(28, 23, 544, 52), 34)
	wrapped(panel, state.game_over_reason, Rect2(28, 91, 544, 81), 22, AMBER)
	status = label(panel, "", Rect2(28, 193, 544, 28), 15, AMBER)
	action(panel, "开始新游戏", Rect2(28, 241, 544, 43), restart_game, true)

func restart_game() -> void:
	var fresh := State.new()
	var err := fresh.save_current(save_path)
	if err != OK:
		report("新存档写入失败（%s）。" % error_string(err))
		return
	state = fresh
	show_cabin()

func show_trade(message: String = "") -> void:
	begin_page("trade")
	var market := State.Markets.profile(state.station)
	var panel := modal("%s · %s" % [market.name, state.station], Rect2(154, 93, 972, 534))
	action(panel, "本站货物", Rect2(24, 82, 126, 34), set_trade_supplies.bind(false), not trade_supplies)
	action(panel, "生活补给", Rect2(162, 82, 126, 34), set_trade_supplies.bind(true), trade_supplies)
	label(panel, "出售背包物品", Rect2(487, 82, 450, 34), 21)
	plate(panel, Rect2(463, 91, 1, 302), BORDER)
	var row := 0
	var stock: Dictionary = State.Markets.ESSENTIALS if trade_supplies else market.stock
	for kind in stock:
		var offer := state.market_offer("stock", kind)
		var shape := state.footprint(kind)
		var y := 129 + row * 59
		label(panel, state.item_name(kind), Rect2(24, y, 255, 23), 17, state.rarity_color(kind))
		var descriptor := "满电 · 停电涨价" if kind == "aaa" and state.is_blackout() else "满电" if kind == "aaa" else state.rarity_name(kind)
		var detail := "%s · %d×%d 格 · 库存 %d" % [descriptor, shape.x, shape.y, offer.remaining]
		label(panel, detail, Rect2(24, y + 23, 255, 21), 13, MUTED)
		var shortfall := state.credit_shortfall(offer.price)
		var method := "赊购" if shortfall > 0.0 else "购买"
		var caption := "%s  %s 度" % [method, energy_text(offer.price)] if offer.remaining > 0 else "今日售罄"
		var buy := action(panel, caption, Rect2(274, y + 2, 162, 42), buy_item.bind(kind))
		buy.disabled = offer.remaining == 0
		if shortfall > 0.0 and not buy.disabled:
			buy.tooltip_text = "本次记入欠费 %s 度" % energy_text(shortfall)
		row += 1
	plate(panel, Rect2(24, 400, 924, 1), BORDER)
	label(panel, "账户余额 %s 度    待还欠费 %s 度" % [energy_text(state.account), energy_text(state.debt)],
		Rect2(24, 419, 680, 36), 19, AMBER)
	action(panel, "去线路图查报价", Rect2(765, 419, 183, 37), open_market_map.bind(state.station))
	status = label(panel, "", Rect2(24, 473, 924, 32), 16, AMBER)
	report(message)
	if state.inventory.is_empty():
		label(panel, "背包里没有可出售物品。", Rect2(487, 126, 435, 36), 16, MUTED)
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	put(panel, scroll, Rect2(487, 123, 461, 271))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for entry in state.inventory:
		var kind: String = entry.kind
		var offer := state.market_offer("demand", kind, state.station, int(entry.get("charge", State.FULL_CHARGE)))
		var item_row := Control.new()
		item_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_row.custom_minimum_size.y = 57
		rows.add_child(item_row)
		label(item_row, state.item_name(kind), Rect2(0, 6, 255, 23), 17, state.rarity_color(kind))
		var detail := "本站不收" if offer.is_empty() else "今日已满额"
		if not offer.is_empty() and offer.remaining > 0:
			detail = "今日还能收 %d 件" % offer.remaining
			action(item_row, "出售  %s 度" % energy_text(offer.price), Rect2(267, 7, 174, 40), sell_item.bind(entry.id))
		elif kind == "aaa" or not State.Markets.ESSENTIALS.has(kind):
			action(item_row, "查附近买家", Rect2(267, 7, 174, 40), find_buyer.bind(kind))
		else:
			detail = "每日补给"
		if kind == "aaa":
			detail = "电量 %d%% · %s" % [entry.charge, detail]
		label(item_row, "%s · %s" % [state.rarity_name(kind), detail], Rect2(0, 28, 255, 20), 13, MUTED)

func set_trade_supplies(enabled: bool) -> void:
	trade_supplies = enabled
	show_trade()

func buy_item(kind: String) -> void:
	var previous_debt := state.debt
	var problem := state.purchase(kind)
	var message := "已购买 %s，放入背包%s" % [state.item_name(kind), added_debt_note(previous_debt)]
	show_trade(message if problem.is_empty() else problem)

func sell_item(id: int) -> void:
	var old_debt := state.debt
	var amount := state.sell(id)
	var payment := snappedf(old_debt - state.debt, 0.1)
	if amount <= 0:
		show_trade("当前无法出售，请查看本站收购范围和额度。")
	elif payment > 0:
		show_trade("成交 %s 度 · 偿还欠费 %s 度" % [str(amount), str(payment)])
	else:
		show_trade("到账  +%s 度" % str(amount))

func open_market_map(location: String) -> void:
	selected_station = location
	outside_tab = false
	show_map()

func find_buyer(kind: String) -> void:
	var routes := Rail.routes_from(state.station)
	var destination := ""
	var best_distance := 0
	var best_price := 0.0
	for location in routes:
		var offer := state.market_offer("demand", kind, location)
		if offer.is_empty() or offer.remaining == 0:
			continue
		var distance: int = routes[location].size() - 1
		if destination.is_empty() or distance < best_distance or (distance == best_distance and offer.price > best_price):
			destination = location
			best_distance = distance
			best_price = offer.price
	if destination.is_empty():
		report("今天没有仍可收购 %s 的站点。" % state.item_name(kind))
	else:
		open_market_map(destination)

func show_news() -> void:
	show_map()
	screen = "news"
	overlay(view, Color("141021bb"))
	var card := plate(view, Rect2(318, 173, 644, 372), Color("2c253b"), Color("746582"))
	label(card, "当日新闻", Rect2(28, 20, 430, 48), 30)
	action(card, "关闭", Rect2(550, 25, 66, 36), show_map)
	label(card, "%s    地面天气 · %s" % [state.date_text(), state.weather()], Rect2(28, 75, 522, 25), 16, MINT)
	plate(card, Rect2(28, 113, 588, 1), BORDER)
	wrapped(card, state.news(), Rect2(28, 138, 588, 123), 21)
	action(card, "关闭并查看线路图", Rect2(28, 293, 588, 47), show_map, true)

func show_map() -> void:
	begin_page("map")
	overlay(view, Color("1a1728"))
	label(view, "上海地铁线路图", Rect2(40, 25, 420, 46), 34)
	label(view, "中心城区", Rect2(321, 30, 200, 45), 18, MUTED)
	action(view, "当日新闻", Rect2(1014, 28, 102, 38), show_news)
	action(view, "返回车厢", Rect2(1132, 28, 108, 38), show_cabin.bind(""))
	var paper := plate(view, Rect2(40, 89, 865, 585), Rail.PAPER)
	var map := Rail.new()
	map.setup(font, state.station, selected_station, select_station)
	put(paper, map, Rect2(8, 50, 849, 505))
	var legend_x := 19.0
	for line in Rail.LINES:
		var color := Color(line[1])
		plate(paper, Rect2(legend_x, 16, 19, 18), color)
		label(paper, str(line[0]), Rect2(legend_x, 16, 19, 18), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		label(paper, "号线", Rect2(legend_x + 26, 15, 38, 20), 13, Rail.INK)
		legend_x += 72
	label(paper, "●  当前站     ▱  换乘站", Rect2(604, 15, 235, 20), 13, Rail.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	label(paper, "站点示意依据申通地铁 D202501 版线路图", Rect2(19, 554, 810, 22), 12, Color("625b65"))
	var detail := plate(view, Rect2(923, 89, 317, 585), DARK, BORDER)
	label(detail, "当前站 · %s" % state.station, Rect2(20, 15, 280, 29), 15, MINT)
	if selected_station.is_empty():
		label(detail, "选择目的地", Rect2(20, 60, 280, 39), 26)
		wrapped(detail, "点击线路图上的站点查看站内设施、周边遗址和行车耗电。", Rect2(20, 125, 272, 92), 17, MUTED)
		label(detail, "车内电源  %s" % car_power_text(), Rect2(20, 469, 275, 32), 17, MINT)
		return
	label(detail, selected_station, Rect2(20, 49, 280, 43), 29)
	var lines := PackedStringArray()
	for line in Rail.station_lines(selected_station):
		lines.append("%d 号线" % line)
	label(detail, "  /  ".join(lines), Rect2(20, 93, 280, 22), 14, MUTED)
	action(detail, "站内设施", Rect2(20, 132, 135, 38), set_map_tab.bind(false), not outside_tab)
	action(detail, "站外情报", Rect2(162, 132, 135, 38), set_map_tab.bind(true), outside_tab)
	var info := Rail.station_info(selected_station)
	if outside_tab:
		label(detail, "区域辐射 · %s" % RADIATION[info.radiation], Rect2(20, 186, 270, 28), 18, AMBER)
		label(detail, "附近建筑遗址", Rect2(20, 224, 270, 27), 15, MUTED)
		wrapped(detail, info.outside, Rect2(20, 256, 270, 66), 17)
	else:
		show_map_market(detail, selected_station)
	plate(detail, Rect2(20, 333, 277, 1), BORDER)
	var path := Rail.route(state.station, selected_station)
	var steps := maxi(0, path.size() - 1)
	var fare := steps * State.TRAVEL_COST_PER_STOP
	label(detail, "行车路线 · %d 站" % steps, Rect2(20, 345, 275, 27), 16, MINT)
	var itinerary := "  →  ".join(PackedStringArray(path))
	wrapped(detail, itinerary, Rect2(20, 382, 276, 103), 14, MUTED)
	label(detail, "车内电源  %s" % car_power_text(), Rect2(20, 485, 275, 27), 17, MINT)
	var caption := "前往 · 耗电 %d 度" % fare
	if steps == 0:
		caption = "已在本站" if selected_station == state.station else "线路未接通"
	elif state.car_power < fare:
		caption = "车电不足 · 需 %d 度" % fare
	var go := action(detail, caption, Rect2(20, 523, 277, 43), travel, true)
	go.disabled = steps == 0 or state.car_power < fare

func show_map_market(detail: Control, location: String) -> void:
	var market := State.Markets.profile(location)
	var facility: String = "学校 · 汽修培训" if location == AutoRepair.STATION else market.facility
	label(detail, facility, Rect2(20, 183, 277, 26), 16, MINT)
	if state.has_charger(location):
		var stock := state.charger_stock(location)
		var service := "充电站停电" if state.is_blackout() else "电站余 %s 度" % energy_text(stock)
		label(detail, service, Rect2(181, 183, 116, 26), 13, MINT if stock > 0 else AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	var quotes := ScrollContainer.new()
	quotes.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	put(detail, quotes, Rect2(20, 210, 277, 119))
	var columns := Control.new()
	var demand := State.Markets.demand(location)
	columns.custom_minimum_size = Vector2(262, 24 + maxi(market.stock.size(), demand.size()) * 22)
	quotes.add_child(columns)
	map_quote_column(columns, location, market.stock, "stock", 0, "本站供应 / 度", "售罄")
	map_quote_column(columns, location, demand, "demand", 132, "本站收购 / 度", "满额")

func map_quote_column(detail: Control, location: String, items: Dictionary, side: String, x: float, title: String, exhausted: String) -> void:
	label(detail, title, Rect2(x, 0, 130, 21), 13, MUTED)
	var row := 0
	for kind in items:
		var offer := state.market_offer(side, kind, location)
		var y := 22 + row * 22
		label(detail, state.item_name(kind), Rect2(x, y, 81, 20), 12, state.rarity_color(kind))
		var price := energy_text(offer.price) if offer.remaining > 0 else exhausted
		if side == "demand" and kind == "aaa" and offer.remaining > 0:
			var empty := state.market_offer(side, kind, location, 0)
			price = "%s–%s" % [energy_text(empty.price), price]
		label(detail, price, Rect2(x + 81, y, 49, 20), 12, TEXT if offer.remaining > 0 else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		row += 1

func select_station(station: String) -> void:
	selected_station = station
	outside_tab = false
	show_map()

func set_map_tab(outside: bool) -> void:
	outside_tab = outside
	show_map()

func travel() -> void:
	var steps := Rail.route(state.station, selected_station).size() - 1
	if state.travel_to(selected_station, steps):
		show_cabin("已抵达 %s · 消耗车内电源 %d 度" % [state.station, steps * State.TRAVEL_COST_PER_STOP])

func add_grid(parent: Control, target: String, at: Vector2, pixels: int) -> void:
	var grid := CargoGrid.new()
	grid.setup(self, target, pixels)
	grid.position = at
	parent.add_child(grid)
	grids.append(grid)

func cargo_title(target: String) -> String:
	var dimensions := state.grid_size(target)
	return "%s   %d / %d 格" % ["柜子" if target == "locker" else "背包", state.used_cells(target), dimensions.x * dimensions.y]

func show_locker(message: String = "") -> void:
	begin_page("locker")
	var panel := modal("柜子与背包", Rect2(130, 113, 1020, 495))
	label(panel, cargo_title("bag"), Rect2(40, 91, 350, 34), 21)
	label(panel, cargo_title("locker"), Rect2(516, 91, 450, 34), 21)
	add_grid(panel, "bag", Vector2(40, 139), 52)
	add_grid(panel, "locker", Vector2(516, 139), 52)
	label(panel, "点选或拖动物品到目标格   /   滚轮或 R 旋转   /   右键取消", Rect2(40, 414, 930, 23), 16, MUTED)
	status = label(panel, "", Rect2(40, 447, 936, 27), 16, AMBER)
	report(message)

func click_cell(target: String, cell: Vector2i) -> void:
	if not selection.is_empty():
		move_cargo(target, cell)
		return
	var entry := state.entry_at(target, cell)
	if not entry.is_empty():
		select_cargo(target, entry.id)

func select_cargo(source: String, id: int) -> void:
	if check_trip_timeout():
		return
	if source == "ground" and is_instance_valid(surface_block) and not surface_block.can_take(id):
		report("走近物品后按 E 拾取。")
		return
	var entry := state.picked(source, id)
	if entry.is_empty():
		return
	selection = {"source": source, "id": id, "rotated": entry.rotated}
	update_cargo_preview()

func clear_selection() -> void:
	selection = {}
	report("")
	for grid in grids:
		grid.queue_redraw()

func rotate_selection() -> void:
	selection.rotated = not selection.rotated
	update_cargo_preview()

func update_cargo_preview() -> void:
	var entry := state.picked(selection.source, selection.id)
	var shape := state.footprint(entry.kind, selection.rotated)
	report("已选 %s · %s · %d × %d" % [state.item_name(entry.kind), state.rarity_name(entry.kind), shape.x, shape.y], state.rarity_color(entry.kind))
	for grid in grids:
		grid.queue_redraw()

func drag_preview() -> Control:
	var entry := state.picked(selection.source, selection.id)
	var ghost := Panel.new()
	ghost.size = Vector2(152, 36)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := state.rarity_color(entry.kind)
	ghost.add_theme_stylebox_override("panel", style(Color("322d45ee"), tint))
	label(ghost, state.item_name(entry.kind), Rect2(8, 0, 134, 36), 15, tint)
	return ghost

func move_cargo(target: String, cell: Vector2i) -> void:
	if check_trip_timeout() or selection.is_empty():
		return
	var entry := state.picked(selection.source, selection.id)
	if entry.is_empty():
		clear_selection()
		return
	if selection.source == "ground" and is_instance_valid(surface_block) and not surface_block.can_take(selection.id):
		clear_selection()
		report("走近物品后按 E 拾取。")
		return
	if not state.place(selection, target, cell):
		var problem := "放不下。试试空位、旋转，或重新摆放其他物品。"
		if target == "battery":
			problem = "从背包选择七号电池，再放入手电筒。"
		report(problem)
		return
	if check_trip_timeout():
		return
	var container_name: String = {"locker": "柜子", "bag": "背包", "battery": "手电筒"}[target]
	var message := "%s 已放入%s。" % [state.item_name(entry.kind), container_name]
	if screen == "locker":
		show_locker(message)
	else:
		show_surface(message)

func show_gear(message: String = "") -> void:
	begin_page("gear")
	var panel := modal("出站整备 · %s" % state.station, Rect2(150, 106, 980, 510))
	var radiation: int = Rail.station_info(state.station).radiation
	label(panel, "区域辐射 · %s   /   外出上限 %d 秒" % [RADIATION[radiation], state.trip_limit()], Rect2(24, 83, 530, 28), 17, AMBER)
	label(panel, "防护服租用", Rect2(24, 133, 260, 30), 20)
	label(panel, "携带装备", Rect2(360, 133, 260, 30), 20)
	label(panel, "背包规格", Rect2(692, 133, 260, 30), 20)
	action(panel, "普通防护服    %d 度" % state.suit_rent(false), Rect2(24, 178, 263, 48), choose_gear.bind("heavy", false), not loadout.heavy)
	action(panel, "加强防护服    %d 度" % state.suit_rent(true), Rect2(24, 236, 263, 48), choose_gear.bind("heavy", true), loadout.heavy)
	wrapped(panel, "超时赔偿普通 300 度、加强 500 度。高辐射区需加强防护服。", Rect2(24, 305, 263, 62), 15, MUTED)
	label(panel, "手电筒必带 · %s" % installed_battery_text(), Rect2(360, 176, 263, 26), 17, MINT)
	swap_button(panel, Rect2(360, 211, 263, 39))
	action(panel, "撬棍   %s" % ("已携带" if loadout.crowbar else "未携带"), Rect2(360, 259, 263, 40), choose_gear.bind("crowbar", not loadout.crowbar), loadout.crowbar)
	var carry_wrench: bool = loadout.get("wrench", false)
	var wrench := action(panel, "扳手   %s" % ("已携带" if carry_wrench else "未携带"), Rect2(360, 309, 263, 40), choose_gear.bind("wrench", not carry_wrench), carry_wrench)
	wrench.disabled = state.auto_repair_level == 0
	wrench.tooltip_text = "完成同济大学汽修一级培训后获得。"
	label(panel, "按 1 照明 · 每秒耗电 5%", Rect2(360, 353, 263, 24), 14, MUTED)
	action(panel, "小背包    5 × 4", Rect2(692, 178, 263, 48), choose_gear.bind("wide", false), not loadout.wide)
	action(panel, "大背包    6 × 5", Rect2(692, 236, 263, 48), choose_gear.bind("wide", true), loadout.wide)
	wrapped(panel, "出发前可在柜子里腾出空间。", Rect2(692, 308, 263, 49), 15, MUTED)
	plate(panel, Rect2(24, 385, 932, 1), BORDER)
	label(panel, "电力余额  %s 度" % str(snappedf(state.account, 0.1)), Rect2(24, 429, 247, 44), 19, AMBER)
	status = label(panel, "", Rect2(280, 421, 405, 60), 15, AMBER)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report(message)
	var rent := state.suit_rent(loadout.heavy)
	var shortfall := state.credit_shortfall(rent)
	var caption := "确认出发 · %d 度" % rent
	if shortfall > 0.0:
		caption += " · 欠 %s 度" % energy_text(shortfall)
	action(panel, caption, Rect2(700, 427, 256, 46), confirm_departure, true)

func installed_battery_text() -> String:
	return "未装七号电池" if state.installed_charge == State.NO_CELL else "%d%%" % state.installed_charge

func swap_button(parent: Control, bounds: Rect2) -> void:
	var button := action(parent, "更换电池 · 可用备用 %d" % state.usable_spares(), bounds, swap_battery)
	button.disabled = state.spare_battery().is_empty()

func swap_battery() -> void:
	if check_trip_timeout():
		return
	var problem := state.replace_battery()
	var message := "已更换七号电池 · %s。" % installed_battery_text() if problem.is_empty() else problem
	if screen == "surface":
		show_surface(message)
	else:
		show_gear(message)

func choose_gear(key: String, enabled: bool) -> void:
	loadout[key] = enabled
	show_gear()

func confirm_departure() -> void:
	var previous_debt := state.debt
	var loot_station := State.START_STATION if SurfaceBlock.supports(state.station) else ""
	var problem := state.depart(loadout, Rail.station_info(state.station).radiation, loot_station)
	if problem.is_empty():
		var debt_note := added_debt_note(previous_debt)
		show_surface("防护服已租用" + debt_note if not debt_note.is_empty() else "")
	else:
		report(problem)

func show_surface(message: String = "") -> void:
	if SurfaceBlock.supports(state.station):
		show_exploration_block(message)
	else:
		show_legacy_surface(message)

func show_exploration_block(message: String) -> void:
	if not is_instance_valid(surface_block):
		begin_page("surface")
		overlay(view, Color("191827"))
		surface_location = label(view, "", Rect2(40, 24, 770, 46), 32)
		label(view, "%s站出发    /    车电 %s" % [state.station, car_power_text()], Rect2(43, 73, 560, 25), 16, MINT)
		time_label = label(view, "", Rect2(1018, 32, 222, 41), 25, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
		surface_block = SurfaceBlock.new()
		surface_block.setup(state, font)
		surface_block.pickup_requested.connect(pick_up_surface_item)
		surface_block.extraction_requested.connect(extract_from_block)
		surface_block.vehicle_requested.connect(show_vehicle)
		var street_frame := Control.new()
		street_frame.clip_contents = true
		street_frame.mouse_filter = MOUSE_FILTER_IGNORE
		put(view, street_frame, Rect2(40, 112, 777, 524))
		put(street_frame, surface_block, Rect2(Vector2.ZERO, street_frame.size))
		var map := SurfaceMinimap.new()
		map.name = "Minimap"
		map.setup(surface_block, font)
		put(view, map, Rect2(550, 126, 250, 172))
		surface_prompt = label(view, "", Rect2(56, 584, 745, 32), 17, AMBER)
		status = label(view, "", Rect2(42, 647, 1190, 33), 16, AMBER)
		surface_block.moved.connect(update_surface_position)
	selection = {}
	update_trip_clock()
	update_surface_pack(true)
	refresh_surface_light()
	report(message)

func pick_up_surface_item(slot: int) -> void:
	if check_trip_timeout() or (is_instance_valid(surface_block) and not surface_block.can_take(slot)):
		return
	var kind := state.ground_kind(slot)
	if kind.is_empty():
		return
	if not state.pick_up_ground(slot):
		report("背包没有合适的空位。")
		return
	show_surface("已拾取%s，放入背包。" % state.item_name(kind))

func close_vehicle() -> void:
	if is_instance_valid(vehicle_panel):
		vehicle_panel.hide()
		vehicle_panel.queue_free()
		vehicle_panel = null
	if is_instance_valid(surface_block):
		surface_block.inspecting_vehicle = false

func show_vehicle(vehicle_id: String) -> void:
	if check_trip_timeout() or surface_block.nearby_vehicle() != vehicle_id:
		return
	close_vehicle()
	clear_selection()
	surface_block.inspecting_vehicle = true
	var frame := Panel.new()
	frame.name = "VehicleParts"
	frame.add_theme_stylebox_override("panel", style(DARK, AMBER))
	put(view, frame, Rect2(170, 278, 489, 298))
	vehicle_panel = frame
	label(frame, "废弃汽车", Rect2(19, 12, 230, 31), 22)
	var equipped: bool = state.gear.wrench_equipped
	var caption := "汽修 %d 级 · 扳手已装备" % state.auto_repair_level if equipped else "汽修 %d 级 · 需要装备扳手" % state.auto_repair_level
	label(frame, caption, Rect2(20, 43, 350, 23), 15, MINT if equipped else AMBER)
	action(frame, "关闭", Rect2(406, 14, 64, 34), close_vehicle)
	var y := 72
	for course in AutoRepair.COURSES:
		for kind in course.parts:
			var required := AutoRepair.required_level(kind)
			var taken := state.vehicle_part_taken(vehicle_id, kind)
			var caption_right := "已拆除" if taken else "需汽修 %d 级" % required if state.auto_repair_level < required else "拆下并收纳"
			var dimensions := state.footprint(kind)
			plate(frame, Rect2(19, y, 451, 39), Color("2e283e"), BORDER)
			label(frame, "%s   %d×%d 格" % [state.item_name(kind), dimensions.x, dimensions.y], Rect2(29, y, 250, 39), 15, state.rarity_color(kind) if not taken else MUTED)
			var button := action(frame, caption_right, Rect2(315, y + 3, 148, 33), take_vehicle_part.bind(vehicle_id, kind))
			button.disabled = not equipped or taken or state.auto_repair_level < required
			y += 43

func take_vehicle_part(vehicle_id: String, kind: String) -> void:
	if check_trip_timeout() or surface_block.nearby_vehicle() != vehicle_id:
		return
	var problem := state.salvage_vehicle_part(vehicle_id, kind)
	if not problem.is_empty():
		report(problem)
		return
	show_exploration_block("")
	show_vehicle(vehicle_id)
	report("已拆下%s，放入背包。" % state.item_name(kind))

func update_surface_position() -> void:
	var cell: Vector2i = surface_block.cell()
	var title: String = SurfaceBlock.CELL_NAMES[cell.y][cell.x]
	var location: Dictionary = surface_block.active_building()
	if not location.is_empty():
		title = "%s · %d 楼" % [location.name, surface_block.floor_index + 1]
	surface_location.text = title
	var target: Dictionary = surface_block.interaction()
	surface_prompt.text = "" if target.is_empty() else "[ E ]  " + target.caption
	if not location.is_empty() and not state.flashlight_on and target.is_empty():
		surface_prompt.text = "[ 1 ]  打开手电筒"
	if selection.get("source") == "ground" and not surface_block.can_take(selection.id):
		clear_selection()

func extract_from_block(destination: String) -> void:
	if check_trip_timeout():
		return
	var cost := state.extraction_cost(destination)
	var problem := state.extract_at(destination)
	if not problem.is_empty():
		report(problem)
		return
	var message := "已返回 %s。" % destination
	if cost > 0:
		message = "已从%s站撤离 · 车厢接应耗电 %d 度" % [destination, cost]
	show_cabin(message)

func show_legacy_surface(message: String) -> void:
	begin_page("surface")
	overlay(view, Color("191827"))
	label(view, "%s · 地表" % state.station, Rect2(40, 24, 560, 46), 34)
	label(view, "辐射 · %s   /   防护服 · %s" % [RADIATION[Rail.station_info(state.station).radiation], "加强" if state.gear.heavy else "普通"], Rect2(43, 73, 560, 25), 16, MINT)
	time_label = label(view, "", Rect2(877, 31, 220, 41), 25, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	update_trip_clock()
	action(view, "返回车厢", Rect2(1119, 32, 121, 41), return_to_cabin)
	var landscape := SurfaceScenery.new()
	landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	put(view, landscape, Rect2(40, 112, 777, 524))
	for id in range(LOOT_SPOTS.size()):
		var kind := state.ground_kind(id)
		if kind.is_empty():
			continue
		var name := state.item_name(kind)
		var dims := state.footprint(kind)
		var anchor: Vector2 = LOOT_SPOTS[id]
		var tint := state.rarity_color(kind)
		var prop := plate(landscape, Rect2(anchor - Vector2(14, -7), Vector2(28, 15)), tint, Color("211d29"))
		plate(prop, Rect2(5, 3, 14, 3), tint.lightened(0.4))
		var hotspot := action(landscape, name, Rect2(anchor - Vector2(68, 34), Vector2(136, 34)), pick_up_surface_item.bind(id))
		hotspot.tooltip_text = "%s · %d × %d 格" % [state.rarity_name(kind), dims.x, dims.y]
		hotspot.add_theme_font_size_override("font_size", 14)
		hotspot.add_theme_color_override("font_color", tint)
		hotspot.set_drag_forwarding(ground_drag.bind(hotspot, id), Callable(), Callable())
		var sprite_hit := invisible_action(landscape, prop.get_rect().grow(4), pick_up_surface_item.bind(id))
		sprite_hit.tooltip_text = "%s · %s" % [name, hotspot.tooltip_text]
		sprite_hit.set_drag_forwarding(ground_drag.bind(sprite_hit, id), Callable(), Callable())
	update_surface_pack(false)
	status = label(view, "", Rect2(42, 647, 1190, 33), 16, AMBER)
	report(message)

func update_surface_pack(walking: bool) -> void:
	if is_instance_valid(surface_pack):
		surface_pack.hide()
		surface_pack.queue_free()
	grids.clear()
	var sidebar := plate(view, Rect2(836, 112, 404, 524), DARK, BORDER)
	surface_pack = sidebar
	label(sidebar, cargo_title("bag"), Rect2(24, 17, 354, 33), 22)
	add_grid(sidebar, "bag", Vector2(24, 60), 48)
	plate(sidebar, Rect2(24, 317, 356, 1), BORDER)
	label(sidebar, "装备", Rect2(24, 323, 100, 28), 19)
	var suit := plate(sidebar, Rect2(24, 358, 126, 44), Color("302b43"), BORDER)
	label(suit, "加强防护服" if state.gear.heavy else "普通防护服", Rect2(0, 0, 126, 44), 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	flashlight_button = action(sidebar, "", Rect2(160, 358, 220, 44), toggle_battery_slot)
	flashlight_button.name = "Flashlight"
	flashlight_button.focus_mode = Control.FOCUS_NONE
	flashlight_button.tooltip_text = "点击打开电池槽。按 1 开关手电筒。"
	battery_panel = plate(sidebar, Rect2(160, 409, 220, 61), Color("292539"), BORDER)
	battery_panel.name = "BatterySlot"
	add_grid(battery_panel, "battery", Vector2(7, 4), 52)
	wrapped(battery_panel, "电池槽\n放入或取出七号电池", Rect2(68, 8, 145, 48), 14, MUTED)
	battery_panel.visible = battery_slot_open
	if walking:
		wrench_button = action(sidebar, "", Rect2(24, 409, 126, 44), toggle_wrench)
		wrench_button.name = "Wrench"
		wrench_button.focus_mode = Control.FOCUS_NONE
		wrench_button.disabled = not state.gear.wrench
		wrench_button.tooltip_text = "点击装备或收起扳手。"
	var instructions := "A / D 移动 · E 互动 · R 旋转 · 1 照明" if walking else "点击拾取或拖入背包 · R 旋转 · 1 照明"
	label(sidebar, instructions, Rect2(24, 483, 356, 26), 14, MUTED)
	refresh_equipment()

func toggle_battery_slot() -> void:
	battery_slot_open = not battery_slot_open
	battery_panel.visible = battery_slot_open
	if not battery_slot_open and selection.get("source") == "battery":
		clear_selection()

func toggle_wrench() -> void:
	if check_trip_timeout():
		return
	state.toggle_wrench()
	refresh_equipment()
	if is_instance_valid(vehicle_panel):
		show_vehicle(surface_block.nearby_vehicle())

func refresh_equipment() -> void:
	if not is_instance_valid(flashlight_button):
		return
	var caption := "手电筒 · %s · %s" % ["开" if state.flashlight_on else "关", installed_battery_text()]
	flashlight_button.text = caption
	flashlight_button.add_theme_color_override("font_color", MINT if state.flashlight_on else TEXT)
	if is_instance_valid(wrench_button) and is_instance_valid(surface_block):
		var equipped: bool = state.gear.wrench_equipped
		var caption_wrench := "未携带" if not state.gear.wrench else "已装备" if equipped else "已收起"
		wrench_button.text = "扳手 · " + caption_wrench
		wrench_button.add_theme_color_override("font_color", MINT if equipped else TEXT)
	for grid in grids:
		if grid.container == "battery":
			grid.queue_redraw()

func refresh_surface_light() -> void:
	refresh_equipment()
	if is_instance_valid(surface_block):
		surface_block.update_lighting()
		surface_block.queue_redraw()
		update_surface_position()

func ground_drag(_at: Vector2, node: Control, id: int) -> Variant:
	select_cargo("ground", id)
	if selection.get("source") != "ground" or selection.get("id") != id:
		return null
	node.set_drag_preview(drag_preview())
	return selection

func return_to_cabin() -> void:
	if check_trip_timeout():
		return
	state.end_trip()
	show_cabin("已返回 %s。" % state.station)

func update_trip_clock() -> void:
	var seconds := ceili(state.remaining_ms() / 1000.0)
	var caption := "剩余 %d 秒" % seconds
	if time_label.text == caption:
		return
	time_label.text = caption
	time_label.add_theme_color_override("font_color", Color("ff9188") if seconds <= 5 else AMBER)

func check_trip_timeout() -> bool:
	if not state.trip_active or state.remaining_ms() > 0:
		return false
	var fee := state.fail_trip()
	var debt_text := " · 尚欠 %s 度" % str(state.debt) if state.debt > 0.0 else ""
	show_cabin("外出超时 · 携带物品全部丢失 · 防护服赔偿 %d 度%s" % [fee, debt_text])
	return true

class SurfaceScenery extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("50465b"))
		draw_rect(Rect2(0, 0, 777, 133), Color("70657c"))
		draw_rect(Rect2(0, 124, 777, 98), Color("8c7681"))
		draw_rect(Rect2(0, 208, 777, 90), Color("a38b89"))
		draw_rect(Rect2(583, 36, 85, 85), Color("bea19a"))
		for skyline in [Rect2(18, 158, 94, 153), Rect2(146, 201, 60, 105), Rect2(371, 157, 96, 141), Rect2(476, 184, 42, 106), Rect2(627, 178, 122, 128)]:
			draw_rect(skyline, Color("716274"))
		draw_rect(Rect2(0, 295, 777, 229), Color("433b4c"))
		draw_rect(Rect2(0, 302, 777, 17), Color("514555"))
		for ruin in [Rect2(19, 110, 151, 205), Rect2(326, 163, 157, 155), Rect2(614, 123, 134, 190)]:
			draw_rect(ruin, Color("524656"))
			draw_rect(Rect2(ruin.position, Vector2(ruin.size.x, 13)), Color("665767"))
			for col in range(3):
				for floor_index in range(3):
					var window_at: Vector2 = ruin.position + Vector2(17 + col * 39, 36 + floor_index * 38)
					draw_rect(Rect2(window_at, Vector2(21, 26)), Color("312d41"))
		for slab in [Rect2(32, 326, 134, 10), Rect2(198, 402, 109, 8), Rect2(343, 358, 106, 10), Rect2(483, 429, 145, 11), Rect2(651, 365, 81, 8)]:
			draw_rect(slab, Color("695664"))
		for i in range(124):
			var p := Vector2((i * 97) % 775, 316 + (i * 73) % 206)
			draw_rect(Rect2(p, Vector2(3 + i % 7, 2)), Color("584959") if i % 2 == 0 else Color("383445"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("81708b"), false, 2.0)
