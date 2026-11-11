extends Node2D
## Original procedural scenery: no reference-game images are embedded.

var host
var font: SystemFont
var elapsed: float = 0.0
var grit: Array[Vector3] = []
var glow_texture: GradientTexture2D

func setup(owner_node) -> void:
	host = owner_node
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	glow_texture = GradientTexture2D.new()
	glow_texture.width = 192
	glow_texture.height = 192
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(0.5, 0.0)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
	glow_texture.gradient = gradient
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	for i in range(650):
		grit.append(Vector3(rng.randf_range(0, 3600), rng.randf_range(566, 705), rng.randf_range(2, 11)))

func _process(delta: float) -> void:
	if host == null:
		return
	if not host.paused:
		elapsed += delta
	queue_redraw()

func rect(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func label_at(text: String, at: Vector2, size: int = 16, color: String = "a4b9b5") -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color))

func glow(at: Vector2, radius: float, tint: Color) -> void:
	if glow_texture != null:
		draw_texture_rect(glow_texture, Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)

func person(at: Vector2, tint: String, phase: float = 0.0) -> void:
	var shift: float = sin(elapsed * 1.8 + phase) * 1.5
	draw_rect(Rect2(at.x - 6, at.y - 27 + shift, 12, 19), Color(tint))
	rect(at.x - 5, at.y - 38 + shift, 10, 10, "9eaaa0")
	rect(at.x - 6, at.y - 9, 4, 9, "273a3d")
	rect(at.x + 2, at.y - 9, 4, 9, "273a3d")

func cable(x: float, y: float, width: float, sag: float, tint: String = "10252a") -> void:
	var points := PackedVector2Array()
	for i in range(21):
		var t: float = float(i) / 20.0
		points.append(Vector2(x + t * width, y + sin(t * PI) * sag))
	draw_polyline(points, Color(tint), 4.0)

func _draw() -> void:
	if host == null or font == null:
		return
	var left: float = host.camera.position.x - 680.0
	draw_rect(Rect2(left, -40, 1400, 840), Color("0a171d"))
	if host.area == "base":
		draw_station()
	else:
		draw_surface(left)
	draw_player_light()
	if host.area == "surface":
		draw_loot()
		draw_dog()
	for i in range(48):
		var px: float = fposmod(float(i) * 119.0 + elapsed * (3.0 + float(i % 4)), 3700.0)
		var py: float = 165.0 + fposmod(float(i) * 71.0 + elapsed * 2.5, 382.0)
		draw_rect(Rect2(px, py, 2, 2), Color(0.64, 0.79, 0.71, 0.16))

func draw_station() -> void:
	rect(0, 100, 1280, 475, "182a2f")
	for x in range(0, 1280, 40):
		for y in range(150, 560, 40):
			draw_rect(Rect2(x, y, 39, 39), Color("20363a") if int(x / 40 + y / 40) % 5 != 0 else Color("1a3034"))
	rect(0, 100, 1280, 26, "0d1d23")
	rect(0, 146, 1280, 4, "415754")
	rect(0, 155, 1280, 6, "8d7353")
	for x in [22, 350, 682, 1020, 1250]:
		rect(x, 126, 26, 434, "14262b")
		rect(x + 3, 126, 4, 434, "314647")
		cable(float(x + 22), 143, 306, 28)
	for x in [125, 477, 810, 1120]:
		rect(x, 180, 96, 5, "c3c5a3")
		glow(Vector2(x + 48, 191), 130, Color("b6d4bc"))
	label_at("14", Vector2(55, 240), 34, "e2b26c")
	label_at("大世界", Vector2(119, 229), 26, "dae1cc")
	label_at("DASHIJIE  /  战时生活区", Vector2(120, 252), 12, "759a97")
	rect(55, 272, 1140, 3, "48666a")
	label_at("公共用电优先保障通风与排水   /   地表作业请凭证登记", Vector2(455, 244), 15, "9bab98")
	# A stationary, lived-in carriage is the player's home.
	rect(55, 365, 269, 181, "415557")
	rect(61, 370, 257, 120, "9aa394")
	rect(61, 490, 257, 25, "557b77")
	rect(61, 517, 257, 27, "263b40")
	for x in [76, 135, 253]:
		rect(x, 395, 47, 53, "12262e")
		rect(x + 4, 400, 38, 42, "657b70")
		rect(x + 6, 420, 35, 20, "d8ad69")
		rect(x + 23, 398, 3, 47, "334b4d")
	rect(195, 387, 43, 143, "75887f")
	rect(200, 398, 33, 45, "172f35")
	rect(214, 388, 2, 140, "314b50")
	rect(226, 467, 4, 7, "e1c58c")
	label_at("住处  014-06", Vector2(99, 354), 16, "bdc9b5")
	label_at("休息并存档", Vector2(112, 508), 12, "c7d4c3")
	rect(66, 546, 244, 7, "0c1a20")
	for x in [98, 271]:
		draw_circle(Vector2(x, 552), 10, Color("10242a"))
	person(Vector2(283, 460), "8f7b63", 2.0)
	# Shop counters are separate physical destinations.
	draw_counter(400, "回收窗口", "RECOVERY", "5c827b")
	draw_counter(585, "充电窗口", "ENERGY", "b48d51")
	draw_counter(775, "整备维修", "WORKSHOP", "607c85")
	draw_counter(965, "回收管理处", "PERMIT", "8b7163")
	for x in [402, 588, 780, 971]:
		person(Vector2(x + 35, 499), "69766a", float(x))
	label_at("泵站", Vector2(780, 278), 16, "c7c9ad")
	for x in [782, 825, 868]:
		rect(x, 292, 33, 69, "203e44")
		draw_circle(Vector2(x + 16, 317), 12, Color("32575a"))
		draw_line(Vector2(x + 16, 317), Vector2(x + 16 + sin(elapsed * 4) * 10, 317 + cos(elapsed * 4) * 10), Color("86a29a"), 3)
		rect(x + 11, 342, 12, 5, "8bc2a3" if host.state.goal_complete else "bc7d53")
	if host.state.goal_complete:
		glow(Vector2(832, 329), 100, Color("6dc3ac"))
		label_at("排水恢复  /  正常运行", Vector2(760, 380), 13, "8bccb0")
	else:
		label_at("等待工业控制器", Vector2(756, 380), 13, "d4a16b")
	# Exit shaft with recognizable checkpoint architecture.
	rect(1120, 306, 118, 254, "0a171d")
	rect(1114, 301, 8, 259, "56756f")
	rect(1238, 301, 8, 259, "56756f")
	for y in range(332, 550, 26):
		draw_line(Vector2(1132, y), Vector2(1219, y - 16), Color("2f474a"), 5)
	rect(1123, 279, 114, 24, "506e61")
	label_at("地表出口 ↑", Vector2(1130, 297), 16, "e2e4c6")
	rect(1095, 460, 23, 100, "3d5959")
	rect(1100, 472, 14, 14, "e2b268")
	label_at("检查站", Vector2(1148, 588), 13, "6e928b")
	# Platform edge, rails, scraps, and warm reflections.
	rect(0, 560, 1280, 13, "758176")
	rect(0, 575, 1280, 5, "c1a06b")
	rect(0, 582, 1280, 138, "0a1920")
	for x in range(0, 1280, 31):
		rect(x, 580, 18, 4, "645d46")
		rect(x, 626, 15, 57, "26383b")
	rect(0, 627, 1280, 4, "6b8583")
	rect(0, 677, 1280, 4, "536967")
	for v in grit:
		if v.x < 1280 and v.y > 590:
			draw_rect(Rect2(v.x, v.y, v.z, 2), Color("21373d"))

func draw_counter(x: float, title: String, english: String, tint: String) -> void:
	rect(x - 30, 440, 120, 120, "152a2f")
	rect(x - 25, 444, 110, 63, tint)
	rect(x - 18, 450, 96, 53, "15272d")
	rect(x - 32, 505, 124, 9, "8b998a")
	rect(x - 24, 515, 109, 45, "365052")
	rect(x - 24, 521, 109, 3, "54716c")
	label_at(title, Vector2(x - 28, 419), 17, "cbd4be")
	label_at(english, Vector2(x - 21, 434), 10, "78928a")
	if english == "ENERGY":
		rect(x - 13, 465, 17, 29, "d9b56e")
		rect(x - 7, 459, 5, 6, "d9b56e")
		glow(Vector2(x + 7, 478), 58, Color("e8b269"))
	if english == "PERMIT" and host.state.permit:
		rect(x + 49, 454, 22, 32, "b7d5bd")
		label_at("✓", Vector2(x + 52, 477), 18, "2d6b5d")

func draw_surface(left: float) -> void:
	var camera_x: float = host.camera.position.x
	# Far skyline scrolls more slowly than the playable architecture.
	for i in range(-8, 48):
		var x: float = float(i) * 135.0 + camera_x * 0.58
		var top: float = 165.0 + float(posmod(i * 71, 130))
		draw_rect(Rect2(x, top, 99, 395 - top), Color("142a31"))
		for wx in range(3):
			for wy in range(7):
				if posmod(i * 13 + wx * 7 + wy * 3, 8) == 0:
					draw_rect(Rect2(x + 13 + wx * 25, top + 17 + wy * 20, 7, 4), Color("355054"))
	# Pearl-like tower silhouette is a fictional skyline cue, not a map.
	var tower: float = 700.0 + camera_x * 0.68
	draw_line(Vector2(tower, 155), Vector2(tower, 370), Color("253f44"), 6)
	draw_circle(Vector2(tower, 226), 18, Color("253f44"))
	draw_circle(Vector2(tower, 292), 30, Color("253f44"))
	draw_line(Vector2(tower, 139), Vector2(tower, 160), Color("40534e"), 2)
	for i in range(6):
		var fog_y: float = 350.0 + i * 34.0
		draw_rect(Rect2(left, fog_y, 1400, 31), Color(0.13, 0.26, 0.28, 0.06))
	# Foreground buildings with rooms, pillars, pipes and broken floors.
	rect(320, 170, 950, 390, "1e3538")
	rect(350, 206, 894, 343, "0d2027")
	for x in range(360, 1240, 68):
		rect(x, 211, 50, 142, "243b3d")
		rect(x + 4, 215, 42, 132, "122b32")
		if x % 3 == 0:
			for j in range(3):
				draw_line(Vector2(x + 3, 239 + j * 33), Vector2(x + 47, 252 + j * 33), Color("4e5147"), 7)
	for x in [330, 675, 1010, 1235]:
		rect(x, 170, 21, 390, "31474a")
		rect(x + 3, 174, 4, 384, "52605b")
	rect(352, 182, 470, 22, "263d40")
	label_at("百货配送中心", Vector2(378, 200), 20, "77958b")
	label_at("废墟回收区  /  请保留返程电量", Vector2(368, 366), 13, "6a8a85")
	for x in [484, 1125]:
		rect(x, 444, 64, 110, "334748")
		rect(x + 5, 451, 54, 48, "1b333b")
		for y in range(457, 493, 10):
			rect(x + 12, y, 37, 3, "59716a")
	# Hospital annex.
	rect(1360, 284, 302, 276, "233b3d")
	rect(1384, 324, 249, 221, "11252d")
	rect(1380, 291, 276, 24, "536158")
	label_at("社区医院  旧物资间", Vector2(1390, 310), 17, "c3d1bb")
	rect(1468, 369, 55, 57, "8e9d8a")
	rect(1491, 376, 9, 43, "4e7769")
	rect(1476, 392, 39, 9, "4e7769")
	# Shelter, shallow flooded section, and abandoned cables.
	rect(1900, 430, 190, 130, "243e40")
	rect(1927, 455, 124, 105, "0c2028")
	rect(1934, 459, 111, 101, "355754")
	rect(1988, 461, 4, 98, "172c30")
	rect(1943, 469, 91, 15, "8ba993")
	label_at("人防休整点", Vector2(1929, 450), 16, "c3dbb7")
	glow(Vector2(1988, 478), 100, Color("6cbd9d"))
	label_at("可用一次  +120秒", Vector2(1910, 592), 12, "6c9489")
	draw_rect(Rect2(1693, 552, 150, 15), Color(0.17, 0.38, 0.41, 0.6))
	for i in range(12):
		var wx: float = 1697.0 + fposmod(float(i) * 16.0 + elapsed * 7.0, 138.0)
		draw_line(Vector2(wx, 557 + i % 4), Vector2(wx + 10, 557 + i % 4), Color("487776"), 1)
	# Deep office/industrial block, gated by the special recovery permit.
	rect(2220, 196, 400, 364, "1a3034")
	for x in range(2240, 2600, 55):
		rect(x, 219, 36, 271, "284146")
		rect(x + 3, 224, 29, 258, "10272e")
	cable(2130, 232, 440, 58)
	label_at("旧办公区", Vector2(2250, 188), 20, "6d8e88")
	rect(2790, 175, 750, 385, "1e3337")
	rect(2810, 212, 700, 338, "0e2028")
	for x in range(2840, 3470, 77):
		rect(x, 270, 49, 130, "2b4447")
		for y in range(278, 395, 16):
			rect(x + 5, y, 39, 8, "102831")
			rect(x + 33, y + 2, 3, 3, "7da896")
	label_at("专项回收区  /  旧数据机房", Vector2(2825, 203), 20, "b1b7a2")
	rect(2696, 154, 14, 406, "75674f")
	rect(2681, 156, 47, 19, "d0a369")
	label_at("凭证进入", Vector2(2635, 143), 16, "d2ab74")
	if not host.state.permit:
		for y in range(190, 550, 24):
			draw_line(Vector2(2690, y), Vector2(2716, y + 20), Color("c29359"), 5)
	else:
		glow(Vector2(2703, 180), 60, Color("7bc2a0"))
	# Platforms and ladders exactly match the collision geometry in main.gd.
	for platform in host.platform_rects:
		draw_rect(platform, Color("3e5353"))
		draw_rect(Rect2(platform.position.x, platform.position.y, platform.size.x, 3), Color("829080"))
		for px in range(int(platform.position.x) + 8, int(platform.end.x), 47):
			rect(px, platform.position.y + 8, 24, 5, "22383b")
	for ladder in host.ladders:
		draw_line(ladder.position + Vector2(2, 0), Vector2(ladder.position.x + 2, ladder.end.y), Color("7f8e78"), 3)
		draw_line(ladder.position + Vector2(20, 0), Vector2(ladder.position.x + 20, ladder.end.y), Color("7f8e78"), 3)
		for y in range(int(ladder.position.y) + 5, int(ladder.end.y), 16):
			draw_line(Vector2(ladder.position.x + 2, y), Vector2(ladder.position.x + 20, y), Color("5c7770"), 3)
	# Road bed and rock grain.
	rect(0, 560, 3600, 160, "12262d")
	rect(0, 560, 3600, 8, "52635c")
	rect(0, 570, 3600, 4, "283c3b")
	for v in grit:
		if v.x > left - 20 and v.x < left + 1420:
			draw_rect(Rect2(v.x, v.y, v.z, 2 + fmod(v.z, 3)), Color("23393b") if int(v.x) % 3 else Color("354747"))
	for x in range(150, 3540, 260):
		cable(float(x), 125 + (x % 3) * 17, 260, 55, "0a1b22")
		for k in range(5):
			rect(x + 37 * k, 565, 13 + k, 4 + k * 2, "3e4a45")
	# Distinct return gate.
	rect(55, 390, 133, 170, "263f42")
	rect(76, 419, 89, 141, "0a1b23")
	for y in range(430, 560, 18):
		rect(84, y, 73, 3, "4f706a")
	label_at("↓ 大世界检查站", Vector2(45, 377), 17, "b2c9aa")
	glow(Vector2(125, 410), 120, Color("b4c795"))
	# Long shafts of light and light rain preserve depth.
	for x in [385, 1260, 2110, 2760]:
		draw_colored_polygon(PackedVector2Array([Vector2(x, 158), Vector2(x + 28, 158), Vector2(x + 145, 556), Vector2(x - 28, 556)]), Color(0.52, 0.73, 0.63, 0.028))
	for i in range(66):
		var rx: float = left + fposmod(float(i * 97) - elapsed * 27, 1400)
		var ry: float = 100 + fposmod(float(i * 53) + elapsed * 190, 460)
		if rx < 310 or (rx > 1270 and rx < 1360) or (rx > 1660 and rx < 1900) or (rx > 2090 and rx < 2220):
			draw_line(Vector2(rx, ry), Vector2(rx - 4, ry + 12), Color(0.52, 0.72, 0.69, 0.18), 1)

func draw_player_light() -> void:
	if not host.lamp_on or host.state.battery <= 0:
		return
	var origin: Vector2 = host.player.position + Vector2(12 * host.player.facing, -19)
	var end: Vector2 = origin + Vector2(250 * host.player.facing, 0)
	draw_colored_polygon(PackedVector2Array([origin, end + Vector2(0, -64), end + Vector2(0, 75)]), Color(0.98, 0.85, 0.54, 0.045))
	glow(origin, 96, Color("e4bd79"))

func draw_loot() -> void:
	for entry in host.loot:
		if bool(entry.get("taken", false)):
			continue
		var at: Vector2 = entry["position"]
		var data: Dictionary = entry["data"]
		var is_heavy: bool = float(data["kg"]) >= 3.0
		var width: float = 28.0 if is_heavy else 19.0
		var height: float = 24.0 if is_heavy else 15.0
		var color: Color = Color(str(data["color"]))
		if bool(entry.get("sealed", false)):
			color = Color("617878")
		draw_rect(Rect2(at.x - width / 2, at.y - height, width, height), Color("091b23").lightened(0.08))
		draw_rect(Rect2(at.x - width / 2 + 2, at.y - height + 2, width - 4, height - 4), color)
		draw_line(at + Vector2(-width / 2 + 2, -height + 5), at + Vector2(width / 2 - 2, -height + 5), color.lightened(0.25), 2)
		if str(data["kind"]) == "meds":
			draw_line(at + Vector2(0, -height + 4), at + Vector2(0, -3), Color("3e6b60"), 3)
			draw_line(at + Vector2(-5, -height / 2), at + Vector2(5, -height / 2), Color("3e6b60"), 3)
		if bool(data.get("controlled", false)):
			draw_rect(Rect2(at.x - 5, at.y - height - 7, 10, 5), Color("e6aa70"))
		if bool(entry.get("scanned", false)):
			var safe: bool = int(data.get("contamination", 0)) <= 60
			draw_circle(at + Vector2(0, -height - 12), 3, Color("9bc2a4") if safe else Color("d17b61"))
		if host.nearest != null and str(host.nearest.get("id", "")) == str(entry["id"]):
			var pulse: float = sin(elapsed * 5) * 0.18 + 0.7
			draw_rect(Rect2(at.x - width / 2 - 5, at.y - height - 5, width + 10, height + 10), Color(0.91, 0.75, 0.45, pulse), false, 1)
			glow(at + Vector2(0, -10), 40, color)

func draw_dog() -> void:
	var at: Vector2 = Vector2(host.dog_x, 559)
	var direction: float = host.dog_direction
	var staggered: bool = host.dog_stun > 0.0
	var phase: float = sin(elapsed * 15.0) * 5.0 if not staggered else 0.0
	draw_rect(Rect2(at.x - 20, at.y - 24, 38, 15), Color("17272a"))
	draw_rect(Rect2(at.x - 17, at.y - 25, 33, 4), Color("546963"))
	draw_rect(Rect2(at.x + 14 * direction - 8, at.y - 32, 17, 17), Color("25383a"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(12 * direction, -29), at + Vector2(14 * direction, -40), at + Vector2(21 * direction, -29)]), Color("354745"))
	draw_circle(at + Vector2(20 * direction, -26), 2, Color("e4a06f"))
	for x in [-13, 10]:
		draw_line(at + Vector2(x, -12), at + Vector2(x + phase, 0), Color("344d4c"), 4)
	draw_line(at + Vector2(-16 * direction, -20), at + Vector2(-32 * direction, -32), Color("344d4c"), 4)
	if staggered:
		for j in range(3):
			draw_circle(at + Vector2(sin(elapsed * 4 + j * 2.0) * 16, -46), 2, Color("d7b975"))
	elif host.dog_alert:
		label_at("!", at + Vector2(-3, -48), 21, "d2926e")
