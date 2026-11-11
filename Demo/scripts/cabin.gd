extends Control

const State = preload("res://scripts/cabin_state.gd")
const Rail = preload("res://scripts/cabin_map.gd")
const CargoGrid = preload("res://scripts/cargo_grid.gd")
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
const LOOT_SPOTS := [Vector2(114, 348), Vector2(266, 380), Vector2(400, 335), Vector2(563, 397), Vector2(681, 335)]
const RADIATION := ["", "低", "中", "高"]

var state := State.new()
var font: SystemFont
var view: Control
var screen := ""
var selection: Dictionary = {}
var grids: Array[Control] = []
var status: Label
var selected_station := ""
var outside_tab := false
var loadout: Dictionary = {}
var save_path: String
var pointer_position := Vector2.ZERO

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
	show_cabin("读取存档失败，已开始新游戏。" if has_save and not loaded else "")

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
	elif event.keycode == KEY_ESCAPE and not selection.is_empty():
		clear_selection()
	elif event.keycode == KEY_R and not selection.is_empty():
		rotate_selection()
	elif event.keycode == KEY_ESCAPE and screen == "news":
		show_map()
	elif event.keycode == KEY_ESCAPE and screen not in ["cabin", "surface"]:
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
	screen = kind
	selection = {}
	grids.clear()
	status = null
	view = Control.new()
	view.name = kind.capitalize()
	view.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func report(message: String, color: Color = AMBER) -> void:
	if is_instance_valid(status):
		status.text = message
		status.add_theme_color_override("font_color", color)

func power(parent: Control, at: Vector2) -> void:
	plate(parent, Rect2(at, Vector2(232, 64)), Color("242135"), BORDER)
	plate(parent, Rect2(at, Vector2(3, 64)), AMBER)
	label(parent, "电力余额", Rect2(at + Vector2(15, 0), Vector2(75, 64)), 15, MUTED)
	label(parent, "%s Wh" % str(snappedf(state.account, 0.1)), Rect2(at + Vector2(90, 0), Vector2(127, 64)), 24, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)

func show_cabin(message: String = "") -> void:
	begin_page("cabin")
	cabin_art()
	label(view, "终末地铁", Rect2(156, 59, 420, 60), 44)
	label(view, "%s   /   %s   /   %s" % [state.station, state.date_text(), state.weather()], Rect2(159, 126, 560, 26), 20, MINT)
	power(view, Vector2(889, 80))
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
		plate(view, Rect2(352, 647, 576, 38), Color("211f31e8"), BORDER)
		label(view, message, Rect2(367, 647, 546, 38), 16, MINT, HORIZONTAL_ALIGNMENT_CENTER)

func use_hotspot(kind: String) -> void:
	match kind:
		"locker": show_locker()
		"trade": show_trade()
		"rest": show_rest()
		"gear":
			loadout = {"heavy": false, "wide": state.wide_bag, "light": true, "crowbar": true}
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

func modal(title: String, bounds: Rect2) -> Panel:
	cabin_art()
	overlay(view, Color("0d0b16ae"))
	var frame := plate(view, bounds, DARK, BORDER)
	label(frame, title, Rect2(24, 13, bounds.size.x - 130, 44), 28)
	action(frame, "关闭", Rect2(bounds.size.x - 88, 18, 64, 34), show_cabin.bind(""))
	plate(frame, Rect2(24, 66, bounds.size.x - 48, 1), BORDER)
	return frame

func show_rest() -> void:
	begin_page("rest")
	var panel := modal("休息与存档", Rect2(372, 230, 536, 256))
	label(panel, "醒来日期   %s" % state.date_text(1), Rect2(24, 85, 480, 34), 20, MINT)
	label(panel, "保存站点、电力余额、背包和柜内物品。", Rect2(24, 126, 480, 26), 16, MUTED)
	status = label(panel, "", Rect2(24, 161, 488, 24), 15, AMBER)
	action(panel, "睡到下一天并保存", Rect2(24, 194, 488, 40), sleep_and_save, true)

func sleep_and_save() -> void:
	var err := state.save_next_day(save_path)
	if err == OK:
		show_cabin("已保存 · %s" % state.date_text())
	else:
		report("存档写入失败（%s）。" % error_string(err))

func show_trade(message: String = "") -> void:
	begin_page("trade")
	var market := State.Markets.profile(state.station)
	var panel := modal("%s · %s" % [market.name, state.station], Rect2(154, 93, 972, 534))
	label(panel, "本站供应", Rect2(24, 82, 405, 34), 21)
	label(panel, "出售背包物品", Rect2(487, 82, 450, 34), 21)
	plate(panel, Rect2(463, 91, 1, 302), BORDER)
	var row := 0
	for kind in market.stock:
		var info: Dictionary = State.ITEMS[kind]
		var offer := state.market_offer("stock", kind)
		var shape := state.footprint(kind)
		var y := 129 + row * 59
		label(panel, info.name, Rect2(24, y, 255, 23), 17, state.rarity_color(kind))
		var detail := "%s · %d×%d 格 · 库存 %d" % [state.rarity_name(kind), shape.x, shape.y, offer.remaining]
		label(panel, detail, Rect2(24, y + 23, 255, 21), 13, MUTED)
		var caption := "购买  %s Wh" % str(offer.price) if offer.remaining > 0 else "今日售罄"
		var buy := action(panel, caption, Rect2(274, y + 2, 162, 42), buy_item.bind(kind))
		buy.disabled = offer.remaining == 0 or state.account < offer.price
		row += 1
	plate(panel, Rect2(24, 400, 924, 1), BORDER)
	label(panel, "电力余额   %s Wh" % str(snappedf(state.account, 0.1)), Rect2(24, 419, 410, 36), 21, AMBER)
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
		var offer := state.market_offer("demand", kind)
		var item_row := Control.new()
		item_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_row.custom_minimum_size.y = 57
		rows.add_child(item_row)
		label(item_row, State.ITEMS[kind].name, Rect2(0, 6, 255, 23), 17, state.rarity_color(kind))
		var detail := "本站不收" if offer.is_empty() else "今日已满额"
		if not offer.is_empty() and offer.remaining > 0:
			detail = "今日还能收 %d 件" % offer.remaining
			action(item_row, "出售  %s Wh" % str(offer.price), Rect2(267, 7, 174, 40), sell_item.bind(entry.id))
		else:
			action(item_row, "查附近买家", Rect2(267, 7, 174, 40), find_buyer.bind(kind))
		label(item_row, "%s · %s" % [state.rarity_name(kind), detail], Rect2(0, 28, 255, 20), 13, MUTED)

func buy_item(kind: String) -> void:
	var problem := state.purchase(kind)
	show_trade("已购买 %s，放入背包。" % State.ITEMS[kind].name if problem.is_empty() else problem)

func sell_item(id: int) -> void:
	var amount := state.sell(id)
	show_trade("到账  +%s Wh" % str(amount) if amount > 0 else "当前无法出售，请查看本站收购范围和额度。")

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
		report("今天没有仍可收购 %s 的站点。" % State.ITEMS[kind].name)
	else:
		open_market_map(destination)

func show_news() -> void:
	show_map()
	screen = "news"
	overlay(view, Color("141021bb"))
	var card := plate(view, Rect2(338, 192, 604, 330), Color("2c253b"), Color("746582"))
	label(card, "当日新闻", Rect2(28, 20, 430, 48), 30)
	action(card, "关闭", Rect2(510, 25, 66, 36), show_map)
	label(card, "%s    地面天气 · %s" % [state.date_text(), state.weather()], Rect2(28, 75, 522, 25), 16, MINT)
	plate(card, Rect2(28, 113, 548, 1), BORDER)
	wrapped(card, state.news(), Rect2(28, 138, 542, 78), 23)
	action(card, "关闭并查看线路图", Rect2(28, 251, 548, 47), show_map, true)

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
		label(detail, "电力余额  %s Wh" % str(snappedf(state.account, 0.1)), Rect2(20, 469, 275, 32), 17, AMBER)
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
	var fare := steps * 10
	label(detail, "行车路线 · %d 站" % steps, Rect2(20, 345, 275, 27), 16, MINT)
	var itinerary := "  →  ".join(PackedStringArray(path))
	wrapped(detail, itinerary, Rect2(20, 382, 276, 103), 14, MUTED)
	label(detail, "电力余额  %s Wh" % str(snappedf(state.account, 0.1)), Rect2(20, 485, 275, 27), 17, AMBER)
	var caption := "前往 · %d Wh" % fare
	if steps == 0:
		caption = "已在本站" if selected_station == state.station else "线路未接通"
	elif state.account < fare:
		caption = "余额不足 · 需 %d Wh" % fare
	var go := action(detail, caption, Rect2(20, 523, 277, 43), travel, true)
	go.disabled = steps == 0 or state.account < fare

func show_map_market(detail: Control, location: String) -> void:
	var market := State.Markets.profile(location)
	label(detail, market.facility, Rect2(20, 183, 277, 26), 16, MINT)
	map_quote_column(detail, location, market.stock, "stock", 20, "本站供应 / Wh", "售罄")
	map_quote_column(detail, location, market.demand, "demand", 162, "本站收购 / Wh", "满额")

func map_quote_column(detail: Control, location: String, items: Dictionary, side: String, x: float, title: String, exhausted: String) -> void:
	label(detail, title, Rect2(x, 210, 135, 21), 13, MUTED)
	var row := 0
	for kind in items:
		var offer := state.market_offer(side, kind, location)
		var y := 232 + row * 22
		label(detail, State.ITEMS[kind].name, Rect2(x, y, 81, 20), 12, state.rarity_color(kind))
		var price := str(offer.price) if offer.remaining > 0 else exhausted
		label(detail, price, Rect2(x + 81, y, 54, 20), 12, TEXT if offer.remaining > 0 else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		row += 1

func select_station(station: String) -> void:
	selected_station = station
	outside_tab = false
	show_map()

func set_map_tab(outside: bool) -> void:
	outside_tab = outside
	show_map()

func travel() -> void:
	var path := Rail.route(state.station, selected_station)
	var fare := (path.size() - 1) * 10
	if fare <= 0 or state.account < fare:
		return
	state.account -= fare
	state.station = selected_station
	show_cabin("已抵达 %s · 消耗 %d Wh" % [state.station, fare])

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
	report("已选 %s · %s · %d × %d" % [State.ITEMS[entry.kind].name, state.rarity_name(entry.kind), shape.x, shape.y], state.rarity_color(entry.kind))
	for grid in grids:
		grid.queue_redraw()

func drag_preview() -> Control:
	var entry := state.picked(selection.source, selection.id)
	var ghost := Panel.new()
	ghost.size = Vector2(152, 36)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := state.rarity_color(entry.kind)
	ghost.add_theme_stylebox_override("panel", style(Color("322d45ee"), tint))
	label(ghost, State.ITEMS[entry.kind].name, Rect2(8, 0, 134, 36), 15, tint)
	return ghost

func move_cargo(target: String, cell: Vector2i) -> void:
	if selection.is_empty():
		return
	var entry := state.picked(selection.source, selection.id)
	if entry.is_empty():
		clear_selection()
		return
	if not state.place(selection, target, cell):
		report("放不下。试试空位、旋转，或重新摆放其他物品。")
		return
	var message := "%s 已放入%s。" % [State.ITEMS[entry.kind].name, "柜子" if target == "locker" else "背包"]
	if screen == "locker":
		show_locker(message)
	else:
		show_surface(message)

func show_gear(message: String = "") -> void:
	begin_page("gear")
	var panel := modal("出站整备 · %s" % state.station, Rect2(150, 106, 980, 510))
	var radiation: int = Rail.station_info(state.station).radiation
	label(panel, "区域辐射 · %s" % RADIATION[radiation], Rect2(24, 83, 320, 28), 17, AMBER)
	label(panel, "防护服租用", Rect2(24, 133, 260, 30), 20)
	label(panel, "携带装备", Rect2(360, 133, 260, 30), 20)
	label(panel, "背包规格", Rect2(692, 133, 260, 30), 20)
	action(panel, "普通防护服    12 Wh", Rect2(24, 178, 263, 48), choose_gear.bind("heavy", false), not loadout.heavy)
	action(panel, "加强防护服    30 Wh", Rect2(24, 236, 263, 48), choose_gear.bind("heavy", true), loadout.heavy)
	wrapped(panel, "高辐射区需租用加强防护服。", Rect2(24, 308, 263, 49), 15, MUTED)
	action(panel, "手电筒   %s" % ("已携带" if loadout.light else "未携带"), Rect2(360, 178, 263, 48), choose_gear.bind("light", not loadout.light), loadout.light)
	action(panel, "撬棍   %s" % ("已携带" if loadout.crowbar else "未携带"), Rect2(360, 236, 263, 48), choose_gear.bind("crowbar", not loadout.crowbar), loadout.crowbar)
	wrapped(panel, "手电照亮暗处物资。撬棍打开卡住的物资箱。", Rect2(360, 308, 263, 62), 15, MUTED)
	action(panel, "小背包    5 × 4", Rect2(692, 178, 263, 48), choose_gear.bind("wide", false), not loadout.wide)
	action(panel, "大背包    6 × 5", Rect2(692, 236, 263, 48), choose_gear.bind("wide", true), loadout.wide)
	wrapped(panel, "出发前可在柜子里腾出空间。", Rect2(692, 308, 263, 49), 15, MUTED)
	plate(panel, Rect2(24, 385, 932, 1), BORDER)
	label(panel, "电力余额  %s Wh" % str(snappedf(state.account, 0.1)), Rect2(24, 429, 247, 44), 19, AMBER)
	status = label(panel, "", Rect2(280, 421, 405, 60), 15, AMBER)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report(message)
	action(panel, "确认出发 · %d Wh" % (30 if loadout.heavy else 12), Rect2(700, 427, 256, 46), confirm_departure, true)

func choose_gear(key: String, enabled: bool) -> void:
	loadout[key] = enabled
	show_gear()

func confirm_departure() -> void:
	var problem := state.depart(loadout, Rail.station_info(state.station).radiation)
	if problem.is_empty():
		show_surface()
	else:
		report(problem)

func show_surface(message: String = "") -> void:
	begin_page("surface")
	overlay(view, Color("191827"))
	label(view, "%s · 地表" % state.station, Rect2(40, 24, 560, 46), 34)
	label(view, "辐射 · %s   /   防护服 · %s" % [RADIATION[Rail.station_info(state.station).radiation], "加强" if state.gear.heavy else "普通"], Rect2(43, 73, 560, 25), 16, MINT)
	action(view, "返回车厢", Rect2(1119, 32, 121, 41), return_to_cabin)
	var landscape := SurfaceScenery.new()
	landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	put(view, landscape, Rect2(40, 112, 777, 524))
	for id in range(LOOT_SPOTS.size()):
		var kind := state.ground_kind(id)
		if kind.is_empty():
			continue
		var item: Dictionary = State.ITEMS[kind]
		var dims := state.footprint(kind)
		var anchor: Vector2 = LOOT_SPOTS[id]
		var tint := state.rarity_color(kind)
		var prop := plate(landscape, Rect2(anchor - Vector2(14, -7), Vector2(28, 15)), tint, Color("211d29"))
		plate(prop, Rect2(5, 3, 14, 3), tint.lightened(0.4))
		var hotspot := action(landscape, item.name, Rect2(anchor - Vector2(68, 34), Vector2(136, 34)), select_cargo.bind("ground", id))
		hotspot.tooltip_text = "%s · %d × %d 格" % [state.rarity_name(kind), dims.x, dims.y]
		hotspot.add_theme_font_size_override("font_size", 14)
		hotspot.add_theme_color_override("font_color", tint)
		hotspot.set_drag_forwarding(ground_drag.bind(hotspot, id), Callable(), Callable())
		var sprite_hit := invisible_action(landscape, prop.get_rect().grow(4), select_cargo.bind("ground", id))
		sprite_hit.tooltip_text = "%s · %s" % [item.name, hotspot.tooltip_text]
		sprite_hit.set_drag_forwarding(ground_drag.bind(sprite_hit, id), Callable(), Callable())
	var sidebar := plate(view, Rect2(836, 112, 404, 524), DARK, BORDER)
	label(sidebar, cargo_title("bag"), Rect2(24, 17, 354, 33), 22)
	add_grid(sidebar, "bag", Vector2(24, 67), 54)
	wrapped(sidebar, "点选或拖动物品到背包格子。\n滚轮或 R 旋转，右键取消。", Rect2(24, 354, 352, 67), 16, MUTED)
	var equipped := "手电 %s   /   撬棍 %s" % ["已携带" if state.gear.light else "未携带", "已携带" if state.gear.crowbar else "未携带"]
	label(sidebar, equipped, Rect2(24, 430, 354, 27), 15, MINT)
	status = label(view, "", Rect2(42, 647, 1190, 33), 16, AMBER)
	report(message)

func ground_drag(_at: Vector2, node: Control, id: int) -> Variant:
	select_cargo("ground", id)
	if selection.is_empty():
		return null
	node.set_drag_preview(drag_preview())
	return selection

func return_to_cabin() -> void:
	state.trip_active = false
	show_cabin("已返回 %s。" % state.station)

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
