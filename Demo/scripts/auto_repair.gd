extends RefCounted

const STATION := "同济大学"
const COURSES := [
	{"name": "基础拆装", "fee": 20, "parts": ["tire", "bolts"]},
	{"name": "车身维修", "fee": 45, "parts": ["steel_plate"]},
	{"name": "电气与动力", "fee": 80, "parts": ["car_battery", "engine"]},
]
const PART_NAMES := {
	"tire": "轮胎", "bolts": "螺丝", "steel_plate": "钢板",
	"car_battery": "汽车电池", "engine": "引擎",
}

static func required_level(kind: String) -> int:
	for index in range(COURSES.size()):
		if kind in COURSES[index].parts:
			return index + 1
	return 0

static func course_parts(course: Dictionary) -> String:
	var names := PackedStringArray()
	for kind in course.parts:
		names.append(PART_NAMES[kind])
	return "、".join(names)
