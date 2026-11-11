extends Node2D

const DataScript = preload("res://scripts/state.gd")
const PlayerScript = preload("res://scripts/player.gd")
const WorldScript = preload("res://scripts/world.gd")

var state = DataScript.new()
var player
var world
var camera: Camera2D
var ui: Control
var ui_layer: CanvasLayer
var panel: Control = null
var panel_title: String = ""
var paused: bool = false
var game_started: bool = false
var area: String = "base"
var lamp_on: bool = true
var cutter: bool = false
var shelter_used: bool = false
var elapsed: float = 0.0
var loot: Array[Dictionary] = []
var nearest: Variant = null
var dog_x: float = 1510.0
var dog_direction: float = -1.0
var dog_alert: bool = false
var dog_stun: float = 0.0
var dog_hit_cooldown: float = 0.0
var shove_cooldown: float = 0.0
var drop_serial: int = 0
var notices: Array[String] = []
var notice_time: float = 0.0
var save_path: String
var font: SystemFont
var hud_labels: Dictionary = {}
var hud_bars: Dictionary = {}
var interaction_label: Label
var notice_label: Label
var location_label: Label
var objective_label: Label
var controls_label: Label
var ambient: AudioStreamPlayer
var sound: AudioStreamPlayer
var sound_on: bool = true
var sfx: Dictionary = {}
var geometry: Node2D
var capture_path: String = ""
var capture_scene: String = "base"
var smoke_mode: bool = false
var input_smoke: bool = false
var capture_ready: bool = false

var platform_rects: Array[Rect2] = [
	Rect2(340, 400, 910, 16), Rect2(760, 240, 400, 16),
	Rect2(1380, 430, 260, 15), Rect2(2240, 400, 360, 16),
	Rect2(2830, 400, 670, 16), Rect2(3000, 240, 350, 16),
]
var ladders: Array[Rect2] = [
	Rect2(815, 400, 22, 160), Rect2(1085, 240, 22, 160),
	Rect2(1510, 430, 22, 130), Rect2(2395, 400, 22, 160),
	Rect2(2905, 400, 22, 160), Rect2(3120, 240, 22, 160),
]

func _ready() -> void:
	get_tree().auto_accept_quit = false
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var game_directory: String = OS.get_executable_path().get_base_dir() if OS.has_feature("template") else ProjectSettings.globalize_path("res://")
	save_path = game_directory.path_join("saves/slot_1.json")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--scene="):
			capture_scene = argument.trim_prefix("--scene=")
		if argument.begins_with("--save-file="):
			save_path = argument.trim_prefix("--save-file=")
		if argument == "--smoke":
			smoke_mode = true
		if argument == "--input-smoke":
			input_smoke = true
	world = WorldScript.new()
	add_child(world)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.position_smoothing_enabled = false
	add_child(camera)
	player = PlayerScript.new()
	player.host = self
	player.position = Vector2(220, 560)
	add_child(player)
	world.setup(self)
	build_geometry()
	build_ui()
	build_audio()
	if capture_path != "" or smoke_mode or input_smoke:
		game_started = true
		if capture_scene == "surface" or input_smoke:
			state.start_trip()
			enter_surface()
			player.position = Vector2(900, 400)
			camera.position.x = 920
		if capture_scene == "title":
			game_started = false
			show_title()
		elif capture_scene == "market":
			state.take(state.item("copper"))
			state.take(state.item("meds"))
			show_market()
		elif capture_scene == "inspection":
			state.start_trip()
			state.take(state.item("copper"))
			state.take(state.item("controller"))
			state.take(state.item("meds", 85))
			return_from_trip()
		if input_smoke:
			call_deferred("run_input_smoke")
		elif smoke_mode:
			call_deferred("run_game_smoke")
		else:
			call_deferred("capture_preview")
	else:
		show_title()

func build_geometry() -> void:
	if geometry != null:
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node2D.new()
	add_child(geometry)
	add_floor(Rect2(-100, 560, 3800 if area == "surface" else 1600, 140), false)
	if area == "surface":
		for platform in platform_rects:
			add_floor(platform, true)

func add_floor(bounds: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2 if one_way else 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	collision.shape = shape
	collision.position = bounds.get_center()
	collision.one_way_collision = one_way
	collision.one_way_collision_margin = 6.0
	body.add_child(collision)
	geometry.add_child(body)

func skin(fill: Color, border: Color = Color("314c51")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(14)
	return style

func ui_label(text: String, size: int, color: String = "d0d9c9") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(color))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func build_ui() -> void:
	# Post-processing sits behind the readable HUD.
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 1
	add_child(fx_layer)
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment(){vec2 p=UV*2.0-1.0; float edge=smoothstep(0.45,1.32,length(p*vec2(0.8,1.0))); float lines=step(0.65,fract(FRAGCOORD.y*0.5))*0.035; COLOR=vec4(0.005,0.015,0.02,edge*0.42+lines);}"
	material.shader = shader
	vignette.material = material
	fx_layer.add_child(vignette)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 3
	add_child(ui_layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui)
	var bar := PanelContainer.new()
	bar.position = Vector2(22, 16)
	bar.size = Vector2(1236, 77)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", skin(Color(0.035, 0.08, 0.10, 0.96)))
	ui.add_child(bar)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 22)
	bar.add_child(line)
	var logo := VBoxContainer.new()
	logo.custom_minimum_size.x = 184
	line.add_child(logo)
	logo.add_child(ui_label("地铁 2026", 25, "e8bd7b"))
	logo.add_child(ui_label("回收员值班记录  /  DEMO 01", 11, "779b96"))
	for key in ["battery", "bag", "time"]:
		var box := VBoxContainer.new()
		box.custom_minimum_size.x = 184
		line.add_child(box)
		var label := ui_label("", 15)
		box.add_child(label)
		hud_labels[key] = label
		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(184, 7)
		progress.show_percentage = false
		progress.add_theme_stylebox_override("background", skin(Color("1c343b"), Color("1c343b")))
		progress.add_theme_stylebox_override("fill", skin(Color("88afa4"), Color("88afa4")))
		box.add_child(progress)
		hud_bars[key] = progress
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 175
	line.add_child(details)
	hud_labels["account"] = ui_label("", 17, "e3bc80")
	hud_labels["health"] = ui_label("", 13, "91a89d")
	details.add_child(hud_labels["account"])
	details.add_child(hud_labels["health"])
	location_label = ui_label("", 13, "809f9b")
	location_label.position = Vector2(30, 106)
	ui.add_child(location_label)
	var objective_box := PanelContainer.new()
	objective_box.position = Vector2(940, 106)
	objective_box.size = Vector2(314, 64)
	objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_box.add_theme_stylebox_override("panel", skin(Color(0.045, 0.09, 0.11, 0.93), Color("50635a")))
	objective_label = ui_label("", 13, "c7c7a8")
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_box.add_child(objective_label)
	ui.add_child(objective_box)
	notice_label = ui_label("", 15, "e0bd85")
	notice_label.position = Vector2(30, 134)
	notice_label.size = Vector2(790, 75)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(notice_label)
	var bottom := PanelContainer.new()
	bottom.position = Vector2(0, 673)
	bottom.size = Vector2(1280, 47)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_stylebox_override("panel", skin(Color(0.025, 0.06, 0.08, 0.96), Color("1b343c")))
	controls_label = ui_label("A D 移动    空格 跳跃    W S 爬梯    E 互动    Tab 终端    R 检测    F 驱赶    L 手电    M 静音    Esc 暂停    F11 全屏", 13, "8da8a1")
	bottom.add_child(controls_label)
	ui.add_child(bottom)
	interaction_label = ui_label("", 17, "e8ce9f")
	interaction_label.position = Vector2(170, 625)
	interaction_label.size = Vector2(940, 32)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.add_theme_color_override("font_shadow_color", Color("06151d"))
	interaction_label.add_theme_constant_override("shadow_outline_size", 8)
	ui.add_child(interaction_label)
	update_hud()

func make_action(text: String, callback: Callable, disabled: bool = false) -> Dictionary:
	return {"text": text, "callback": callback, "disabled": disabled}

func open_panel(title: String, body: String, actions: Array, is_pause: bool = false) -> void:
	close_panel()
	paused = is_pause
	panel_title = title
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.045, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var container := PanelContainer.new()
	container.position = Vector2(320, 75)
	container.size = Vector2(640, 570)
	container.add_theme_stylebox_override("panel", skin(Color("10242d"), Color("738676")))
	panel.add_child(container)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 592
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	content.add_child(ui_label("SHANGHAI UNDERGROUND   /   DAY %02d" % state.day, 11, "779f9a"))
	content.add_child(ui_label(title, 28, "e5c188"))
	var description := ui_label(body, 16, "bdcec3")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 578
	content.add_child(description)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	content.add_child(spacer)
	for action in actions:
		var button := Button.new()
		button.text = str(action["text"])
		button.disabled = bool(action.get("disabled", false))
		button.custom_minimum_size.y = 45
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color("dfd7bb"))
		button.add_theme_color_override("font_disabled_color", Color("607b7b"))
		button.add_theme_stylebox_override("normal", skin(Color("1e3a42"), Color("45635f")))
		button.add_theme_stylebox_override("hover", skin(Color("345158"), Color("c1ac7b")))
		button.add_theme_stylebox_override("focus", skin(Color("2c484f"), Color("cfb681")))
		button.add_theme_stylebox_override("pressed", skin(Color("405c5c"), Color("e0c287")))
		button.add_theme_stylebox_override("disabled", skin(Color("122b34"), Color("28474b")))
		button.pressed.connect(action["callback"])
		content.add_child(button)
	if content.get_child_count() > 4:
		content.get_child(4).grab_focus.call_deferred()

func close_panel() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	panel_title = ""
	paused = false

func show_title() -> void:
	var actions: Array = []
	if FileAccess.file_exists(save_path):
		actions.append(make_action("继续上次值班", continue_game))
	actions.append(make_action("开始新的值班", begin_new_game))
	actions.append(make_action("操作与目标", show_help))
	actions.append(make_action("退出", func(): get_tree().quit()))
	open_panel("下一站  地面", "核战第十年，上海。\n\n你是一名新上岗的回收员。地表还有很多东西，地下的人们需要它们。\n\n今天，豫园的排水泵站正在等一个控制器。\n先完成两次带货返回，再办理特许回收证。", actions, true)

func begin_new_game() -> void:
	state = DataScript.new()
	game_started = true
	close_panel()
	enter_base()
	player.position.x = 220
	notify("先向右走到充电窗口整备，再去最右侧检查站出发。")
	ambient.play()

func continue_game() -> void:
	if not state.load_game(save_path):
		open_panel("存档无法读取", "存档没有通过校验。可以返回标题，开始一份新值班记录。", [make_action("返回标题", show_title)], true)
		return
	game_started = true
	close_panel()
	enter_base()
	player.position.x = 220
	notify("值班记录已恢复。" + state.news())
	ambient.play()

func show_help() -> void:
	open_panel("回收员操作手册", "A / D 或方向键：移动；空格：跳跃。\nW / S：在梯子上攀爬；E：回收或使用设施。\nR：检测周围物资，消耗2 Wh；F：驱赶近处动物。\nTab：打开终端和背包；Q：放下最后一件物资。\nL：开关手电；M：静音；Esc：暂停。\n\n电卡余额在站内，工具消耗随身电池。\n有污染的物资会被拒收；无证携带管制品会被没收。\n在住处休息才会存档，同时进入下一天。\n\n目标：两次带货安全返回 → 办理特许证 →\n回收控制器并在管理处交付，让泵站重新上线。", [make_action("返回", show_title if not game_started else close_panel)], true)

func can_move() -> bool:
	return game_started and not paused and panel == null

func on_ladder(at: Vector2) -> bool:
	if area != "surface":
		return false
	for ladder in ladders:
		if absf(at.x - ladder.get_center().x) < 25 and at.y >= ladder.position.y - 7 and at.y <= ladder.end.y + 10:
			return true
	return false

func _process(delta: float) -> void:
	if player == null:
		return
	if not paused:
		elapsed += delta
		shove_cooldown = maxf(0, shove_cooldown - delta)
		if game_started and area == "surface":
			var pressure: float = 1.65 if player.position.x > 2680 else 1.0
			state.trip_time = maxf(0.0, state.trip_time - delta * pressure)
			if lamp_on:
				state.battery = maxf(0.0, state.battery - delta * 0.11)
			update_dog(delta)
			if state.trip_time <= 0:
				fail_trip("超出作业时限，检查站派出了接应人员")
		if notice_time > 0:
			notice_time = maxf(0, notice_time - delta)
	var target_x: float = clampf(player.position.x, 640.0, 2960.0) if area == "surface" else 640.0
	camera.position.x = lerpf(camera.position.x, target_x, minf(1, delta * 8.0))
	find_nearest()
	update_hud()

func update_hud() -> void:
	if hud_labels.is_empty():
		return
	hud_labels["battery"].text = "随身电量  %.0f / %.0f Wh" % [state.battery, state.battery_capacity()]
	hud_labels["bag"].text = "背包  %.1f / %.0f kg" % [state.weight(), state.bag_capacity()]
	hud_labels["time"].text = "作业余量  %02d:%02d" % [int(state.trip_time) / 60, int(state.trip_time) % 60] if area == "surface" else "站内安全  /  可整备"
	hud_labels["account"].text = "电卡  %.1f Wh" % state.account
	hud_labels["health"].text = "体力 %.0f%%    %s" % [state.health, "特许回收员" if state.permit else "普通回收员"]
	hud_bars["battery"].value = state.battery / state.battery_capacity() * 100
	hud_bars["bag"].value = state.weight() / state.bag_capacity() * 100
	hud_bars["time"].value = state.trip_time / 210.0 * 100 if area == "surface" else 100
	location_label.text = "第 %02d 天  /  %s" % [state.day, "地表 · 大世界旧街区" if area == "surface" else "地下 · 大世界站"]
	if state.goal_complete:
		objective_label.text = "泵站已重新上线\n你带回的控制器已经投入使用。"
	elif state.permit:
		objective_label.text = "泵站委托  /  特许回收证已取得\n回收工业控制器，交给回收管理处。"
	else:
		objective_label.text = "特许资格  /  带货返回 %d / 2 次\n管理处办理：180 Wh" % mini(state.successful_trips, 2)
	notice_label.text = "\n".join(notices) if notice_time > 0 else ""
	interaction_label.text = interaction_text() if panel == null and game_started else ""

func notify(text: String) -> void:
	notices.append(text)
	while notices.size() > 2:
		notices.pop_front()
	notice_time = 7.0
	print("[Metro] " + text)

func find_nearest() -> void:
	nearest = null
	var candidates: Array[Dictionary] = []
	if area == "base":
		for pair in [["home", 215.0], ["market", 430.0], ["charge", 615.0], ["gear", 805.0], ["permit", 995.0], ["exit", 1175.0]]:
			candidates.append({"id": pair[0], "position": Vector2(pair[1], 560)})
	else:
		candidates.append({"id": "return", "position": Vector2(120, 560)})
		candidates.append({"id": "shelter", "position": Vector2(1985, 560)})
		if not state.permit:
			candidates.append({"id": "gate", "position": Vector2(2695, 560)})
		for entry in loot:
			if not bool(entry.get("taken", false)):
				candidates.append(entry)
	var closest: float = 63.0
	for candidate in candidates:
		var distance: float = player.position.distance_to(candidate["position"])
		if distance < closest:
			closest = distance
			nearest = candidate

func interaction_text() -> String:
	if nearest == null:
		return "前往最右侧地表出口，开始本次回收。" if area == "base" else "靠近物资按 E 回收。沿梯子可到达上层。"
	var id: String = str(nearest["id"])
	match id:
		"home": return "[ E ] 车厢住处  /  休息与存档"
		"market": return "[ E ] 回收窗口  /  出售检测合格的普通物资"
		"charge": return "[ E ] 充电窗口  /  将电卡余额取为随身电量"
		"gear": return "[ E ] 整备维修  /  背包、电池与应急工作"
		"permit": return "[ E ] 回收管理处  /  特许回收证与政府委托"
		"exit": return "[ E ] 出站登记  /  进入地表回收区"
		"return": return "[ E ] 返回地下  /  人员与物资检查"
		"shelter": return "[ E ] 人防休整点  /  +120秒、恢复体力、消耗20 Wh" if not shelter_used else "休整点储备已耗尽  /  本次已使用"
		"gate": return "专项回收区  /  需要特许回收证，不能继续前进"
	var data: Dictionary = nearest["data"]
	var tag: String = "  [管制]" if bool(data.get("controlled", false)) else ""
	if bool(nearest.get("scanned", false)):
		tag += "  污染过高" if int(data.get("contamination", 0)) > 60 else "  初筛通过"
	else:
		tag += "  [R 检测]"
	var operation: String = "切割回收 · 18 Wh" if bool(nearest.get("sealed", false)) else "回收"
	return "[ E ] %s  %s  /  %.1f kg  /  参考 %.0f Wh%s" % [operation, data["name"], data["kg"], state.price(data), tag]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F11 or event.keycode == KEY_F11):
		var game_window := get_window()
		game_window.mode = Window.MODE_MAXIMIZED if game_window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_M:
		sound_on = not sound_on
		ambient.stream_paused = not sound_on
		notify("声音已开启。" if sound_on else "已静音。")
		return
	if not game_started:
		return
	if event.physical_keycode == KEY_ESCAPE:
		if panel != null:
			close_panel()
		else:
			show_pause()
		return
	if event.physical_keycode == KEY_TAB:
		if panel != null and panel_title == "回收员终端":
			close_panel()
		elif panel == null:
			show_inventory()
		return
	if panel != null:
		return
	match event.physical_keycode:
		KEY_E: interact()
		KEY_R: scan_loot()
		KEY_Q:
			if area == "surface" and not state.inventory.is_empty():
				drop_item(state.inventory.size() - 1)
		KEY_L:
			lamp_on = not lamp_on
			notify("手电已开启，每秒消耗0.11 Wh。" if lamp_on else "手电已关闭。")
		KEY_F: shove_dog()

func interact() -> void:
	find_nearest()
	if nearest == null:
		return
	match str(nearest["id"]):
		"home": show_home()
		"market": show_market()
		"charge": show_charge()
		"gear": show_gear()
		"permit": show_permit()
		"exit": show_departure()
		"return": return_from_trip()
		"shelter": use_shelter()
		"gate": notify("请到回收管理处办理特许回收证。")
		_: collect_loot(nearest)

func show_charge() -> void:
	var body: String = "电卡余额 %.1f Wh　|　站点可兑付 %.1f Wh\n随身电池 %.1f / %.0f Wh\n\n取电会等额扣除账户余额。银行有余额，仍要看本窗口的实际储备。" % [state.account, state.station_stock, state.battery, state.battery_capacity()]
	open_panel("充电窗口", body, [
		make_action("提取 40 Wh", func(): do_charge(40.0)),
		make_action("尽可能充满", func(): do_charge(9999.0)),
		make_action("返回站厅", close_panel)])

func do_charge(amount: float) -> void:
	var received: float = state.charge(amount)
	play_sound("charge")
	notify("已提取 %.1f Wh，账户和站点储备同步扣减。" % received if received > 0 else "当前无法取电：电池已满、余额不足或窗口储备不足。")
	show_charge()

func show_market() -> void:
	var body: String = state.news() + "\n\n"
	var ordinary_value: float = 0.0
	for entry in state.inventory:
		if not bool(entry.get("controlled", false)):
			ordinary_value += state.price(entry)
			body += "%s　%.1f Wh\n" % [entry["name"], state.price(entry)]
	body += "\n可结算合计 %.1f Wh。管制品请交回收管理处。" % ordinary_value
	open_panel("回收窗口", body, [make_action("出售全部普通物资  +%.1f Wh" % ordinary_value, sell_goods, ordinary_value <= 0), make_action("返回站厅", close_panel)])

func sell_goods() -> void:
	var earned: float = state.sell_normal()
	notify("普通物资结算完成，电卡收入 %.1f Wh。" % earned)
	play_sound("sell")
	show_market()

func show_gear() -> void:
	open_panel("整备维修", "账户余额 %.0f Wh\n\n背包容量 %.0f kg；电池容量 %.0f Wh。\n升级电池只增加容量，不会凭空充满。\n\n若已无力周转，可以协助维修台完成临时工作。\n每天一次，余额不足60 Wh时开放。" % [state.account, state.bag_capacity(), state.battery_capacity()], [
		make_action("扩容背包至17 kg  /  95 Wh", func(): buy("bag"), state.bag_upgraded),
		make_action("扩容电池至240 Wh  /  110 Wh", func(): buy("battery"), state.battery_upgraded),
		make_action("临时维修工作  +45 Wh", do_emergency_work, state.account >= 60 or state.aid_used),
		make_action("返回站厅", close_panel)])

func do_emergency_work() -> void:
	if state.emergency_work():
		notify("完成临时维修，获得45 Wh。明天可再申请。")
	show_gear()

func buy(kind: String) -> void:
	var message: String = state.buy_upgrade(kind)
	notify(message if message != "" else "办理完成。新装备已经可以使用。")
	play_sound("sell")
	if kind == "permit":
		show_permit()
	else:
		show_gear()

func show_permit() -> void:
	var body: String
	if state.permit:
		body = "证件状态：特许回收证有效。\n\n政府委托：为豫园排水泵站回收工业控制器。\n持证期间可合法携带管制品，通过检查后在此交付。\n报酬：每件基础170 Wh + 发现奖40 Wh。\n\n" + ("泵站已恢复运行，你可以继续回收。" if state.goal_complete else "目标设备在旧配送中心上层或专项回收区机房。")
	else:
		body = "目前为普通回收员，无权携带管制物品进入生活区。\n\n办理特许回收证：\n• 带货安全返回两次，目前 %d / 2。\n• 办理费用180 Wh。\n\n取得证件后，可进入专项回收区，为政府回收工业控制器。" % mini(state.successful_trips, 2)
	var has_controlled: bool = false
	for entry in state.inventory:
		if bool(entry.get("controlled", false)):
			has_controlled = true
	open_panel("回收管理处", body, [
		make_action("办理特许回收证  /  180 Wh", func(): buy("permit"), state.permit or state.successful_trips < 2),
		make_action("交付管制物资并领取报酬", deliver_goods, not state.permit or not has_controlled),
		make_action("返回站厅", close_panel)])

func deliver_goods() -> void:
	var was_complete: bool = state.goal_complete
	var earned: float = state.deliver_controlled()
	notify("政府交售完成，获得 %.0f Wh。" % earned)
	play_sound("sell")
	if earned > 0 and not was_complete:
		open_panel("泵站重新上线", "你带回的控制器已经装上了豫园泵站。\n\n这一次，背包里的旧设备没有留在收购清单上。\n它让一座地下社区的排水系统重新转动。\n\nDemo的主要委托已完成。你可以继续探索、升级装备，或回到住处休息存档。", [make_action("回到站厅看看", close_panel)])
	else:
		show_permit()

func show_departure() -> void:
	var body: String = "地表路线：大世界旧街区\n作业时限：3分30秒；深入专项区后消耗更快。\n随身电量 %.0f Wh　|　背包 %.0f kg\n\n出站租赁防护服12 Wh。\n可另租切割器，打开封闭设备箱：租金14 Wh，\n每次作业另消耗随身电量18 Wh。\n\n返回入口在地图最左侧。R可检测附近物资。" % [state.battery, state.bag_capacity()]
	open_panel("地表出站登记", body, [
		make_action("轻装出发  /  12 Wh", func(): depart(false)),
		make_action("携带切割器出发  /  26 Wh", func(): depart(true)),
		make_action("继续整备", close_panel)])

func depart(with_cutter: bool) -> void:
	if with_cutter and state.account < 26:
		notify("携带切割器出发需要26 Wh账户余额。")
		return
	var message: String = state.start_trip()
	if message != "":
		notify(message)
		return
	cutter = with_cutter
	if cutter:
		state.account -= 14.0
	close_panel()
	enter_surface()
	notify("出站完成。左侧入口可随时返回；先检测，再决定搬什么。")
	play_sound("charge")

func enter_surface() -> void:
	area = "surface"
	shelter_used = false
	lamp_on = true
	player.position = Vector2(220, 560)
	player.velocity = Vector2.ZERO
	player.ladder_mode = false
	dog_x = 1530.0
	dog_stun = 0.0
	dog_hit_cooldown = 0.0
	build_geometry()
	spawn_loot()
	camera.position.x = 640

func enter_base() -> void:
	area = "base"
	player.position = Vector2(1070, 560)
	player.velocity = Vector2.ZERO
	player.ladder_mode = false
	player.set_collision_mask_value(2, true)
	state.trip_active = false
	camera.position.x = 640
	nearest = null
	build_geometry()

func spawn_loot() -> void:
	loot.clear()
	var placements: Array = [
		["copper", 398, 560, false, 0], ["book", 600, 400, false, 0],
		["meds", 846, 400, false, 0], ["controller", 1050, 400, false, 0],
		["powercore", 1140, 240, true, 0], ["tools", 1240, 560, false, 0],
		["meds", 1470, 430, false, 0], ["copper", 1635, 560, false, 86],
		["relic", 2250, 560, false, 0], ["circuit", 2440, 400, true, 0],
		["book", 2565, 400, false, 0], ["tools", 2870, 400, false, 0],
		["controller", 3070, 240, true, 0], ["powercore", 3370, 400, false, 0],
		["meds", 3435, 560, false, 0]]
	for i in range(placements.size()):
		var value: Array = placements[i]
		loot.append({"id": "loot_%d" % i, "position": Vector2(value[1], value[2]), "data": state.item(str(value[0]), int(value[4])), "sealed": bool(value[3]), "scanned": false, "taken": false})

func collect_loot(entry: Dictionary) -> bool:
	if not state.trip_active or bool(entry.get("taken", false)):
		return false
	var data: Dictionary = entry["data"]
	if not state.can_take(data):
		notify("背包装不下了。按Tab查看背包，或Q放下一件物资。")
		return false
	if bool(entry.get("sealed", false)):
		if not cutter:
			notify("这件设备需要切割器。下次出站可在检查站租赁。")
			return false
		if not state.spend_energy(18.0):
			notify("切割需要18 Wh随身电量，电卡里的余额不能直接驱动工具。")
			return false
	if not state.take(data):
		return false
	entry["taken"] = true
	play_sound("pickup")
	var extra: String = "这是管制物品，无证返回会被没收。" if bool(data.get("controlled", false)) and not state.permit else ""
	notify("已回收 %s，背包 %.1f / %.0f kg。%s" % [data["name"], state.weight(), state.bag_capacity(), extra])
	return true

func scan_loot() -> void:
	if area != "surface":
		return
	if not state.spend_energy(2.0):
		notify("检测仪需要2 Wh随身电量。")
		return
	var count: int = 0
	var dirty: int = 0
	for entry in loot:
		if not bool(entry.get("taken", false)) and player.position.distance_to(entry["position"]) < 340:
			entry["scanned"] = true
			count += 1
			if int(entry["data"].get("contamination", 0)) > 60:
				dirty += 1
	play_sound("scan")
	notify("检测完成：附近%d件物资，%d件污染过高。消耗2 Wh。" % [count, dirty])

func return_from_trip() -> void:
	if not state.trip_active:
		return
	var report: Dictionary = state.inspect()
	enter_base()
	var body: String = "检查通过：%d件，留在背包中，尚未出售。\n" % report["accepted"].size()
	if not report["confiscated"].is_empty():
		body += "\n无证管制品已没收：\n" + "、".join(report["confiscated"]) + "\n无回收报酬。持证后可合法交售。\n"
	if not report["rejected"].is_empty():
		body += "\n污染过高，隔离拒收：\n" + "、".join(report["rejected"]) + "\n"
	body += "\n带货安全返回记录：%d / 2次。\n到回收窗口出售普通物资，管制品交管理处。" % mini(state.successful_trips, 2)
	open_panel("入口检查回执", body, [make_action("前往回收窗口", func(): player.position.x = 430; close_panel()), make_action("返回站厅", close_panel)])
	play_sound("sell")

func use_shelter() -> void:
	if shelter_used:
		notify("本休整点的储备在本次行动中已使用。")
		return
	if not state.spend_energy(20):
		notify("休整服务需要20 Wh随身电量。")
		return
	shelter_used = true
	state.trip_time = minf(210, state.trip_time + 120)
	state.health = minf(100, state.health + 35)
	dog_stun = 3.0
	notify("补充防护耗材并休整：作业余量增加120秒，体力恢复。消耗20 Wh。")
	play_sound("charge")

func update_dog(delta: float) -> void:
	dog_stun = maxf(0, dog_stun - delta)
	dog_hit_cooldown = maxf(0, dog_hit_cooldown - delta)
	if dog_stun > 0:
		dog_alert = false
		return
	var distance: float = absf(player.position.x - dog_x)
	dog_alert = distance < 250 and player.position.y > 470
	if dog_alert:
		dog_direction = signf(player.position.x - dog_x)
		dog_x += dog_direction * 112 * delta
	else:
		dog_x += dog_direction * 36 * delta
		if dog_x < 1330: dog_direction = 1
		if dog_x > 1650: dog_direction = -1
	dog_x = clampf(dog_x, 1260, 1850)
	if distance < 32 and player.position.y > 525 and dog_hit_cooldown <= 0:
		state.health -= 19.0
		player.hurt_time = 0.8
		dog_hit_cooldown = 1.4
		play_sound("hurt")
		notify("被流浪动物咬伤。F可驱赶；爬上高处也能避开。")
		if state.health <= 0:
			fail_trip("体力耗尽，回收队将你带回地下")

func shove_dog() -> void:
	if area != "surface" or shove_cooldown > 0:
		return
	shove_cooldown = 1.0
	play_sound("scan")
	if absf(player.position.x - dog_x) < 95 and player.position.y > 480:
		dog_stun = 3.5
		dog_x = clampf(dog_x + signf(dog_x - player.position.x) * 70, 1260, 1850)
		notify("动物被驱开了。趁现在拉开距离。")
	else:
		notify("挥动工具。需要更靠近才能驱赶动物。")

func fail_trip(reason: String) -> void:
	if area != "surface":
		return
	var fee: float = state.rescue()
	enter_base()
	open_panel("作业中止", reason + "。\n\n本次携带的回收物资遗失，账户扣除%.0f Wh接应费用。\n应急电量已补至至少25 Wh，可以继续周转。\n\n余额不足时可到维修台接临时工作；也可在住处休息进入次日。" % fee, [make_action("返回站厅", close_panel)])

func drop_item(index: int) -> void:
	if index < 0 or index >= state.inventory.size() or area != "surface":
		return
	var entry: Dictionary = state.inventory[index]
	state.inventory.remove_at(index)
	drop_serial += 1
	loot.append({"id": "drop_%d" % drop_serial, "position": player.position + Vector2(25 * player.facing, 0), "data": entry, "sealed": false, "scanned": true, "taken": false})
	notify("已放下 %s，可以再回来取。" % entry["name"])
	if panel != null:
		show_inventory()

func show_inventory() -> void:
	var body: String = "背包 %.1f / %.0f kg　|　随身 %.0f Wh　|　电卡 %.0f Wh\n\n" % [state.weight(), state.bag_capacity(), state.battery, state.account]
	if area == "surface":
		body += "切割器：%s\n\n" % ("已租赁，每次切割18 Wh" if cutter else "本次未携带")
	if state.inventory.is_empty():
		body += "背包是空的。\n"
	for entry in state.inventory:
		body += "%s%s　%.1f kg　参考%.0f Wh\n" % ["[管制] " if bool(entry.get("controlled", false)) else "", entry["name"], entry["kg"], state.price(entry)]
	body += "\n" + state.news()
	var actions: Array = []
	if area == "surface":
		body += "\n地表终端不会暂停作业倒计时。Esc暂停游戏。"
		for i in range(state.inventory.size()):
			var index: int = i
			actions.append(make_action("放下 " + str(state.inventory[i]["name"]), func(): drop_item(index)))
	actions.append(make_action("关闭终端", close_panel))
	open_panel("回收员终端", body, actions)

func show_home() -> void:
	open_panel("车厢住处", "一张床、一盏灯，还有你今天带回来的东西。\n\n关闭电器，免费休息并存档。存档后必定进入下一天，\n站内供电窗口补充储备，市场新闻也可能变化。\n\n当前是第%d天。上次存档前的行动不会自动保存。" % state.day, [make_action("关闭电器  休息并存档", sleep_and_save), make_action("返回站厅", close_panel)])

func sleep_and_save() -> void:
	var old_day: int = state.day
	var old_stock: float = state.station_stock
	var old_aid: bool = state.aid_used
	state.next_day()
	var error: Error = state.save_game(save_path)
	if error != OK:
		state.day = old_day
		state.station_stock = old_stock
		state.aid_used = old_aid
		notify("无法写入存档，未进入下一日。请确认游戏目录可写。")
		return
	close_panel()
	notify("第%d天，值班记录已保存。%s" % [state.day, state.news()])
	play_sound("charge")

func show_pause() -> void:
	open_panel("值班暂停", "游戏时间已暂停。\n\n请在住处休息存档。直接退出不会保存当前进度。", [make_action("继续", close_panel), make_action("操作手册", show_help), make_action("退出游戏", confirm_quit)], true)

func confirm_quit() -> void:
	open_panel("结束值班", "只有在住处休息时才会存档。\n确定退出并放弃上次存档之后的行动吗？", [make_action("返回游戏", close_panel), make_action("退出，不保存", func(): get_tree().quit())], true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not game_started:
			get_tree().quit()
		else:
			confirm_quit()

func synth(frequency: float, duration: float, metallic: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var frames: int = int(duration * 22050)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t: float = float(i) / 22050.0
		var envelope: float = minf(1.0, t * 90) * pow(1.0 - float(i) / float(frames), 2)
		var wave: float = sin(TAU * frequency * t) + (sin(TAU * frequency * 1.51 * t) * 0.35 if metallic else 0.0)
		bytes.encode_s16(i * 2, int(wave * envelope * 6000))
	stream.data = bytes
	return stream

func build_audio() -> void:
	sound = AudioStreamPlayer.new()
	sound.volume_db = -9
	add_child(sound)
	sfx = {"pickup": synth(570, 0.12), "sell": synth(840, 0.25, true), "scan": synth(290, 0.18, true), "charge": synth(440, 0.36, true), "hurt": synth(85, 0.21, true)}
	ambient = AudioStreamPlayer.new()
	ambient.volume_db = -29
	var hum := AudioStreamWAV.new()
	hum.format = AudioStreamWAV.FORMAT_16_BITS
	hum.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(44100 * 2)
	for i in range(44100):
		var t: float = float(i) / 22050.0
		var signal_value: float = sin(t * TAU * 55) * 0.55 + sin(t * TAU * 82) * 0.20 + sin(t * TAU * 111) * 0.10
		samples.encode_s16(i * 2, int(signal_value * 9000))
	hum.data = samples
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_end = 44100
	ambient.stream = hum
	add_child(ambient)

func play_sound(key: String) -> void:
	if not sound_on or sound == null:
		return
	sound.stream = sfx[key]
	sound.play()

func capture_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
	var error: Error = get_viewport().get_texture().get_image().save_png(capture_path)
	print("CAPTURE_RESULT=", error, " PATH=", capture_path)
	capture_ready = true
	get_tree().quit(0 if error == OK else 1)

func run_game_smoke() -> void:
	# Integration coverage uses the same public handlers as the UI.
	await get_tree().physics_frame
	await get_tree().physics_frame
	state.account = 1000.0
	assert(state.start_trip() == "")
	enter_surface()
	assert(collect_loot(loot[0]))
	assert(collect_loot(loot[3]))
	var first: Dictionary = state.inspect()
	assert(first["confiscated"].size() == 1)
	assert(state.successful_trips == 1)
	enter_base()
	assert(state.sell_normal() > 0)
	assert(state.start_trip() == "")
	enter_surface()
	assert(collect_loot(loot[1]))
	state.inspect()
	enter_base()
	state.sell_normal()
	assert(state.buy_upgrade("permit") == "")
	assert(state.start_trip() == "")
	enter_surface()
	assert(collect_loot(loot[3]))
	state.inspect()
	enter_base()
	assert(state.deliver_controlled() == 210)
	assert(state.goal_complete)
	assert(state.save_game(save_path) == OK)
	var loaded = DataScript.new()
	assert(loaded.load_game(save_path))
	assert(loaded.goal_complete and loaded.permit)
	print("INTEGRATION_SMOKE_PASS: recover -> confiscate -> sell -> second return -> permit -> deliver -> save/load")
	loaded = null
	get_tree().quit()

func simulated_key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func wait_physics(frames: int) -> void:
	for frame in range(frames):
		await get_tree().physics_frame

func run_input_smoke(quit_after: bool = true) -> void:
	player.position = Vector2(220, 560)
	await wait_physics(3)
	simulated_key(KEY_D, true)
	await wait_physics(45)
	simulated_key(KEY_D, false)
	assert(player.position.x > 340, "Horizontal input must move the player")
	simulated_key(KEY_SPACE, true)
	await wait_physics(4)
	simulated_key(KEY_SPACE, false)
	await wait_physics(10)
	assert(player.position.y < 530, "Jump must leave the ground")
	await wait_physics(60)
	assert(player.is_on_floor(), "Player must land on solid floor")
	player.position = Vector2(826, 560)
	player.velocity = Vector2.ZERO
	simulated_key(KEY_W, true)
	await wait_physics(78)
	simulated_key(KEY_W, false)
	assert(player.position.y < 412, "Ladder must reach first floor")
	simulated_key(KEY_A, true)
	await wait_physics(60)
	simulated_key(KEY_A, false)
	await wait_physics(3)
	assert(player.position.y < 408, "Upper platform must support the player")
	player.position = Vector2(600, 400)
	await wait_physics(3)
	simulated_key(KEY_E, true)
	await wait_physics(2)
	simulated_key(KEY_E, false)
	assert(state.inventory.size() == 1, "E must collect nearby loot")
	assert(not collect_loot(loot[1]), "Collected loot cannot be duplicated")
	simulated_key(KEY_Q, true)
	await wait_physics(2)
	simulated_key(KEY_Q, false)
	assert(state.inventory.is_empty(), "Q must put an item back in the world")
	assert(loot.size() == 16, "Dropped item remains recoverable")
	state.permit = false
	player.position.x = 2740
	await wait_physics(3)
	assert(player.position.x <= 2670, "Permit gate must stop an unlicensed player")
	state.permit = true
	player.position = Vector2(2700, 560)
	simulated_key(KEY_D, true)
	await wait_physics(15)
	simulated_key(KEY_D, false)
	assert(player.position.x > 2720, "Licensed player must pass the gate")
	print("INPUT_SMOKE_PASS: move, jump, land, ladder, upper floor, E pickup, anti-duplication, Q drop, permit gate")
	if quit_after:
		get_tree().quit()
