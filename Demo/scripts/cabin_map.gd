extends Control
## Line geometry follows the central area of the Shentong Metro D202501 diagram.

const STATIONS := {
	"四川北路": [Vector2(710, 378), Vector2(-68, -23)],
	"海伦路": [Vector2(710, 314), Vector2(-48, -26)],
	"邮电新村": [Vector2(794, 235), Vector2(10, -16)],
	"四平路": [Vector2(855, 170), Vector2(3, 10)],
	"同济大学": [Vector2(925, 100), Vector2(-58, -25)],
	"国权路": [Vector2(991, 34), Vector2(-61, 9)],
	"五角场": [Vector2(1018, 7), Vector2(15, 1)],
	"曲阜路": [Vector2(602, 443), Vector2(-52, -23)],
	"中兴路": [Vector2(602, 312), Vector2(-53, -30)],
	"西藏北路": [Vector2(626, 211), Vector2(-57, -23)],
	"虹口足球场": [Vector2(710, 170), Vector2(-80, -26)],
	"曲阳路": [Vector2(782, 170), Vector2(-31, -26)],
	"鞍山新村": [Vector2(982, 170), Vector2(-16, -26)],
	"江浦路": [Vector2(1127, 170), Vector2(-22, 9)],
	"黄兴路": [Vector2(1194, 145), Vector2(9, 2)],
	"延吉中路": [Vector2(1215, 111), Vector2(10, -17)],
	"宝山路": [Vector2(638, 314), Vector2(-22, 10)],
	"临平路": [Vector2(819, 314), Vector2(-28, -25)],
	"大连路": [Vector2(928, 316), Vector2(-18, -26)],
	"杨树浦路": [Vector2(1001, 407), Vector2(-71, -24)],
	"浦东大道": [Vector2(1001, 561), Vector2(11, 0)],
	"世纪大道": [Vector2(1001, 750), Vector2(-26, -26)],
	"天潼路": [Vector2(710, 443), Vector2(-57, 9)],
	"国际客运中心": [Vector2(800, 443), Vector2(7, 8)],
	"提篮桥": [Vector2(850, 387), Vector2(-41, -23)],
	"江浦公园": [Vector2(1127, 243), Vector2(-48, 10)],
	"宁国路": [Vector2(1200, 243), Vector2(-9, -23)],
	"抚顺路": [Vector2(1062, 100), Vector2(10, -20)],
	"南京东路": [Vector2(710, 550), Vector2(-65, -24)],
	"豫园": [Vector2(710, 642), Vector2(-22, 8)],
	"老西门": [Vector2(656, 733), Vector2(11, -11)],
	"大世界": [Vector2(656, 642), Vector2(-39, -25)],
	"人民广场": [Vector2(602, 550), Vector2(-69, -24)],
	"平凉路": [Vector2(1127, 306), Vector2(11, -12)],
	"丹阳路": [Vector2(1127, 366), Vector2(11, -12)],
	"昌邑路": [Vector2(1127, 435), Vector2(10, 5)],
	"民生路": [Vector2(1127, 617), Vector2(12, 4)],
	"上海火车站": [Vector2(492, 314), Vector2(-40, 9)],
	"中潭路": [Vector2(420, 314), Vector2(-18, -25)],
	"镇坪路": [Vector2(348, 314), Vector2(-31, 9)],
	"曹杨路": [Vector2(202, 314), Vector2(-35, -25)],
	"金沙江路": [Vector2(73, 442), Vector2(10, -22)],
	"中山公园": [Vector2(73, 587), Vector2(10, -22)],
	"延安西路": [Vector2(73, 660), Vector2(10, -21)],
	"宜山路": [Vector2(73, 822), Vector2(10, 9)],
	"上海体育馆": [Vector2(106, 920), Vector2(-31, -25)],
	"上海体育场": [Vector2(275, 947), Vector2(-32, -25)],
	"东安路": [Vector2(348, 947), Vector2(-24, 10)],
	"大木桥路": [Vector2(454, 947), Vector2(-29, -26)],
	"鲁班路": [Vector2(498, 947), Vector2(-16, -23)],
	"西藏南路": [Vector2(656, 947), Vector2(-31, -25)],
	"南浦大桥": [Vector2(720, 947), Vector2(-11, -25)],
	"塘桥": [Vector2(805, 947), Vector2(-14, -25)],
	"蓝村路": [Vector2(910, 947), Vector2(-41, -24)],
	"向城路": [Vector2(1001, 842), Vector2(-57, -16)],
	"陆家浜路": [Vector2(656, 822), Vector2(10, -18)],
	"中华艺术宫": [Vector2(656, 1024), Vector2(10, -12)],
	"耀华路": [Vector2(656, 1095), Vector2(-43, -22)],
	"虹桥路": [Vector2(73, 733), Vector2(12, -24)],
	"交通大学": [Vector2(202, 733), Vector2(-38, 10)],
	"上海图书馆": [Vector2(258, 733), Vector2(-40, -25)],
	"陕西南路": [Vector2(454, 733), Vector2(-31, 10)],
	"一大会址·新天地": [Vector2(547, 733), Vector2(-42, -24)],
	"南京西路": [Vector2(454, 551), Vector2(-55, 8)],
	"嘉善路": [Vector2(454, 822), Vector2(-44, -23)],
	"龙华中路": [Vector2(348, 1058), Vector2(-44, -24)],
	"龙华": [Vector2(239, 1058), Vector2(-16, -24)],
	"龙漕路": [Vector2(154, 1058), Vector2(-21, 9)],
	"杨高中路": [Vector2(1127, 750), Vector2(12, -18)],
	"迎春路": [Vector2(1127, 791), Vector2(12, -12)],
	"龙阳路": [Vector2(1127, 876), Vector2(-57, -17)],
	"芳芯路": [Vector2(1127, 965), Vector2(13, -13)],
	"北中路": [Vector2(1127, 1095), Vector2(12, -13)],
	"汉中路": [Vector2(484, 443), Vector2(-10, -27)],
}
const LINES := [
	[4, "472881", [
		"宝山路", "海伦路", "临平路", "大连路", Vector2(954, 325), Vector2(975, 344),
		Vector2(992, 372), "杨树浦路", "浦东大道", "世纪大道", "向城路", Vector2(1001, 851),
		Vector2(993, 883), Vector2(973, 914), Vector2(946, 936), "蓝村路", "塘桥", "南浦大桥",
		"西藏南路", "鲁班路", "大木桥路", "东安路", "上海体育场", Vector2(171, 947),
		Vector2(141, 941), "上海体育馆", Vector2(86, 891), Vector2(74, 855), "宜山路", "虹桥路",
		"延安西路", "中山公园", "金沙江路", Vector2(73, 407), Vector2(80, 373), Vector2(100, 342),
		Vector2(130, 324), Vector2(170, 314), "曹杨路", "镇坪路", "中潭路", "上海火车站",
		"宝山路",
	]],
	[8, "008cbd", [
		Vector2(656, 1115), "耀华路", "中华艺术宫", "西藏南路", "陆家浜路", "老西门",
		"大世界", Vector2(650, 613), Vector2(635, 592), "人民广场", "曲阜路", "中兴路",
		Vector2(602, 269), Vector2(610, 242), "西藏北路", Vector2(660, 181), Vector2(685, 171), "虹口足球场",
		"曲阳路", "四平路", "鞍山新村", "江浦路", Vector2(1151, 169), Vector2(1174, 159),
		"黄兴路", Vector2(1206, 129), "延吉中路", Vector2(1218, 92), Vector2(1218, 0),
	]],
	[10, "ad95c1", [
		Vector2(0, 733), "虹桥路", "交通大学", "上海图书馆", "陕西南路", "一大会址·新天地",
		"老西门", Vector2(695, 693), Vector2(707, 668), "豫园", "南京东路", "天潼路",
		"四川北路", "海伦路", "邮电新村", "四平路", "同济大学", "国权路",
		"五角场", Vector2(1025, 0),
	]],
	[12, "007861", [
		Vector2(0, 1058), "龙漕路", "龙华", "龙华中路", Vector2(383, 1045), Vector2(439, 993),
		Vector2(453, 962), "大木桥路", "嘉善路", "陕西南路", "南京西路", Vector2(454, 490),
		Vector2(465, 466), "汉中路", "曲阜路", "天潼路", "国际客运中心", "提篮桥",
		"大连路", Vector2(981, 261), Vector2(1003, 248), Vector2(1025, 243), "江浦公园", "宁国路",
		Vector2(1455, 243),
	]],
	[18, "b08a55", [
		Vector2(957, 0), "国权路", "抚顺路", "江浦路", "江浦公园", "平凉路",
		"丹阳路", "昌邑路", "民生路", "杨高中路", "迎春路", "龙阳路",
		"芳芯路", "北中路", Vector2(1127, 1115),
	]],
]
const OTHER_LINES := [
	["f3c638", [Vector2(67, 820), Vector2(67, 404), Vector2(76, 370), Vector2(105, 342), Vector2(146, 318), Vector2(170, 308), Vector2(638, 308), Vector2(699, 249), Vector2(710, 222), Vector2(710, 22), Vector2(719, 0)]],
	["f3c638", [Vector2(67, 820), Vector2(67, 897), Vector2(77, 926), Vector2(144, 986), Vector2(154, 1011), Vector2(154, 1058), Vector2(111, 1101), Vector2(83, 1115), Vector2(0, 1115)]],
	["d61535", [Vector2(492, 0), Vector2(492, 442), Vector2(602, 550), Vector2(602, 641), Vector2(530, 709), Vector2(504, 714), Vector2(333, 714), Vector2(306, 724), Vector2(202, 822), Vector2(105, 921), Vector2(48, 975), Vector2(39, 1004), Vector2(39, 1058), Vector2(0, 1103)]],
	["7ebc30", [Vector2(0, 587), Vector2(348, 587), Vector2(375, 560), Vector2(401, 550), Vector2(838, 550), Vector2(865, 554), Vector2(978, 667), Vector2(990, 691), Vector2(991, 750), Vector2(1128, 877), Vector2(1455, 877)]],
	["e86923", [Vector2(343, 0), Vector2(348, 29), Vector2(348, 1055), Vector2(372, 1083), Vector2(401, 1095), Vector2(887, 1095), Vector2(920, 1078), Vector2(1184, 822)]],
	["71bfd9", [Vector2(0, 894), Vector2(73, 822), Vector2(656, 822), Vector2(711, 765), Vector2(743, 750), Vector2(1127, 750), Vector2(1275, 602), Vector2(1302, 587), Vector2(1455, 587)]],
	["d686ae", [Vector2(0, 442), Vector2(474, 442), Vector2(474, 642), Vector2(488, 676), Vector2(547, 733), Vector2(547, 1115)]],
	["575029", [Vector2(0, 206), Vector2(130, 206), Vector2(161, 218), Vector2(204, 263), Vector2(214, 328), Vector2(263, 379), Vector2(275, 403), Vector2(275, 495), Vector2(288, 526), Vector2(384, 622), Vector2(411, 637), Vector2(430, 641), Vector2(710, 641), Vector2(787, 562), Vector2(1001, 562), Vector2(1127, 436), Vector2(1355, 436), Vector2(1379, 448), Vector2(1418, 477), Vector2(1418, 587), Vector2(1455, 624)]],
	["6a1730", [Vector2(0, 110), Vector2(202, 312), Vector2(202, 1005), Vector2(211, 1028), Vector2(302, 1115)]],
	["d90866", [Vector2(760, 1115), Vector2(910, 947), Vector2(910, 860), Vector2(923, 832), Vector2(1252, 505), Vector2(1286, 478), Vector2(1455, 478)]],
	["8dcab9", [Vector2(1139, 894), Vector2(1149, 921), Vector2(1237, 1009), Vector2(1255, 1047), Vector2(1255, 1115)]],
]
const OTHER_TRANSFERS := {
	"世纪大道": [2, 6, 9], "浦东大道": [14], "南京东路": [2], "豫园": [14],
	"人民广场": [1, 2], "虹口足球场": [3], "宝山路": [3], "昌邑路": [14], "民生路": [6],
	"上海火车站": [1, 3], "中潭路": [3], "镇坪路": [3, 7], "曹杨路": [3, 11, 14],
	"金沙江路": [3, 13], "中山公园": [2, 3], "延安西路": [3], "宜山路": [3, 9],
	"上海体育馆": [1], "东安路": [7], "蓝村路": [6], "汉中路": [1, 13], "陆家浜路": [9], "耀华路": [7],
	"交通大学": [11], "陕西南路": [1], "一大会址·新天地": [13], "南京西路": [2, 13],
	"嘉善路": [9], "龙华中路": [7], "龙华": [11], "龙漕路": [3], "杨高中路": [9], "龙阳路": [2, 7, 16],
}
const RIVER := [Vector2(1437, 0), Vector2(1437, 205), Vector2(1425, 250), Vector2(1402, 295), Vector2(1330, 367), Vector2(1298, 382), Vector2(1100, 382), Vector2(1063, 395), Vector2(972, 486), Vector2(940, 496), Vector2(765, 496), Vector2(744, 503), Vector2(731, 526), Vector2(730, 599), Vector2(758, 632), Vector2(765, 648), Vector2(765, 930), Vector2(748, 959), Vector2(711, 983), Vector2(671, 1004), Vector2(485, 1004), Vector2(450, 1024), Vector2(388, 1090), Vector2(385, 1115)]

const PROJECTION := Vector2(0.564, 0.44)
const ORIGIN := Vector2(12, 9)
const INK := Color("292a36")
const PAPER := Color("faf9f3")

var current: String
var selected: String
var font: Font
var planned: Array = []
var captions: Dictionary = {}

func setup(ui_font: Font, location: String, destination: String, on_select: Callable) -> void:
	font = ui_font
	current = location
	selected = destination
	planned = route(location, destination)
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	layout_captions()
	for station in STATIONS:
		var center := project(STATIONS[station][0])
		var caption: Vector2 = captions[station]
		var label_size := font.get_string_size(station, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.position = center - Vector2(9, 9)
		hit.size = Vector2(18, 18)
		hit.tooltip_text = station
		hit.pressed.connect(on_select.bind(station))
		add_child(hit)
		var text_hit := Button.new()
		text_hit.flat = true
		text_hit.focus_mode = Control.FOCUS_NONE
		text_hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		text_hit.position = caption
		text_hit.size = Vector2(label_size.x, 15)
		text_hit.tooltip_text = station
		text_hit.pressed.connect(on_select.bind(station))
		add_child(text_hit)

static func station_lines(station: String) -> Array:
	var result: Array = OTHER_TRANSFERS.get(station, []).duplicate()
	for line in LINES:
		if station in line[2]:
			result.append(line[0])
	result.sort()
	return result

static func station_info(station: String) -> Dictionary:
	var index := STATIONS.keys().find(station)
	var ruins := [
		"沿街商铺遗址\n地下停车库",
		"社区诊所旧址\n废弃居民楼",
		"废弃学校\n旧货仓库",
		"通信机房旧址\n废弃公交车场",
	]
	var level := [1, 2, 1, 2, 2, 3, 3][index % 7] as int
	return {"outside": ruins[index % ruins.size()], "radiation": level}

static func route(from: String, to: String) -> Array:
	if not STATIONS.has(to):
		return []
	return routes_from(from, to).get(to, [])

static func routes_from(from: String, until: String = "") -> Dictionary:
	if not STATIONS.has(from):
		return {}
	var paths := {from: [from]}
	var frontier: Array = [from]
	while not frontier.is_empty():
		var here: String = frontier.pop_front()
		if here == until:
			break
		for line in LINES:
			var stops: Array = line[2].filter(func(point: Variant) -> bool: return point is String)
			var loop: bool = stops.front() == stops.back()
			if loop:
				stops.pop_back()
			var index := stops.find(here)
			if index == -1:
				continue
			for adjacent in [index - 1, index + 1]:
				if loop:
					adjacent = posmod(adjacent, stops.size())
				if adjacent < 0 or adjacent >= stops.size():
					continue
				var next: String = stops[adjacent]
				if not paths.has(next):
					paths[next] = paths[here] + [next]
					frontier.append(next)
	return paths

func layout_captions() -> void:
	var used: Array[Rect2] = []
	for station in STATIONS:
		var center := project(STATIONS[station][0])
		used.append(Rect2(center - Vector2(8, 7), Vector2(16, 14)))
	for station in STATIONS:
		var center := project(STATIONS[station][0])
		var preferred: Vector2 = STATIONS[station][1]
		var width := font.get_string_size(station, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var offsets: Array[Vector2] = [
			preferred, Vector2(10, -8), Vector2(-width - 10, -8),
			Vector2(-width / 2, -25), Vector2(-width / 2, 9),
			Vector2(8, -23), Vector2(8, 9), Vector2(-width - 8, -23), Vector2(-width - 8, 9),
			Vector2(-width / 2, -43), Vector2(-width / 2, 26),
			Vector2(13, -42), Vector2(-width - 13, -42),
			Vector2(13, 28), Vector2(-width - 13, 28),
			Vector2(53, -8), Vector2(-width - 53, -8),
		]
		for radius in [34, 44, 54, 64, 78]:
			for step in range(16):
				var around := Vector2.from_angle(step * TAU / 16.0) * float(radius)
				offsets.append(around - Vector2(width / 2.0, 8))
		for offset in offsets:
			var box := Rect2(center + offset, Vector2(width, 16))
			if box.position.x < 1 or box.position.y < 1 or box.end.x > 848 or box.end.y > 503:
				continue
			if used.any(func(other: Rect2) -> bool: return other.intersects(box.grow(2))):
				continue
			captions[station] = box.position
			used.append(box)
			break
		if not captions.has(station):
			captions[station] = center + preferred

func project(point: Vector2) -> Vector2:
	return point * PROJECTION + ORIGIN

func plot(points: Array, color: Color, width: float) -> void:
	var vertices := PackedVector2Array()
	for point in points:
		vertices.append(project(STATIONS[point][0] if point is String else point))
	draw_polyline(vertices, color, width, true)

func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	plot(RIVER, Color("a9ddea"), 14.0)
	for line in OTHER_LINES:
		plot(line[1], Color(line[0]), 2.6)
	for line in LINES:
		plot(line[2], Color(line[1]), 4.0)
	if planned.size() > 1:
		for line in LINES:
			var last := ""
			var segment: Array = []
			for point in line[2]:
				segment.append(point)
				if point is String:
					var index := planned.find(last)
					if index != -1 and absi(planned.find(point) - index) == 1 and point in planned:
						plot(segment, PAPER, 11.0)
						plot(segment, Color(line[1]), 7.0)
					segment = [point]
					last = point
	for station in STATIONS:
		var center := project(STATIONS[station][0])
		var caption: Vector2 = captions[station]
		var in_route: bool = station in planned
		var interchange := station_lines(station).size() > 1
		if station == current:
			draw_circle(center, 11, Color("f3d09b"))
		if station == selected and station != current:
			draw_circle(center, 11, Color("c9b6e7"))
		if interchange:
			draw_capsule(center, INK, 4.5)
			draw_capsule(center, PAPER, 3.0)
		else:
			draw_stop(station, center, caption)
		var label_width := font.get_string_size(station, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var label_rect := Rect2(caption, Vector2(label_width, 16))
		var edge := center.clamp(label_rect.position, label_rect.end)
		if center.distance_to(edge) > 24.0:
			draw_line(center.move_toward(edge, 6.0), edge, Color("837a86"), 1.0, true)
		draw_rect(label_rect.grow_individual(2, 0, 2, 0), Color(PAPER, 0.94))
		draw_string(font, caption + Vector2(0, 13), station, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK if in_route else Color("464350"))

func draw_capsule(center: Vector2, tint: Color, radius: float) -> void:
	var offset := Vector2(4, 0)
	draw_line(center - offset, center + offset, tint, radius * 2, true)
	draw_circle(center - offset, radius, tint, true, -1.0, true)
	draw_circle(center + offset, radius, tint, true, -1.0, true)

func draw_stop(station: String, center: Vector2, caption: Vector2) -> void:
	for line in LINES:
		var points: Array = line[2]
		var index := points.find(station)
		if index == -1:
			continue
		var adjacent: Variant = points[index - 1] if index > 0 else points[index + 1]
		var neighbor: Vector2 = STATIONS[adjacent][0] if adjacent is String else adjacent
		var outward := (center - project(neighbor)).orthogonal().normalized()
		var toward := caption + Vector2(12, 8) - center
		if outward.dot(toward) < 0:
			outward *= -1
		draw_line(center, center + outward * 6, Color(line[1]), 4.0, true)
		return
