extends RefCounted
## Economy and progression. No rendering or input dependencies.

const SAVE_VERSION := 1
const ITEMS := {
	"copper": {"name": "铜线束", "kg": 1.5, "value": 30.0, "color": "c18c59"},
	"tools": {"name": "维修工具", "kg": 2.0, "value": 46.0, "color": "86a6a3"},
	"book": {"name": "维修手册", "kg": 0.6, "value": 24.0, "color": "beaf7f"},
	"meds": {"name": "密封医疗包", "kg": 0.8, "value": 54.0, "color": "d1d9c5"},
	"circuit": {"name": "通信电路板", "kg": 0.9, "value": 66.0, "color": "6fb2a2"},
	"controller": {"name": "工业控制器", "kg": 3.8, "value": 170.0, "controlled": true, "color": "dd9874"},
	"powercore": {"name": "备用电源组件", "kg": 6.5, "value": 132.0, "color": "a6bbc1"},
	"relic": {"name": "旧式照相机", "kg": 1.3, "value": 74.0, "color": "b8a998"},
}

var account: float = 220.0
var battery: float = 120.0
var station_stock: float = 400.0
var day: int = 1
var successful_trips: int = 0
var total_sales: float = 0.0
var permit: bool = false
var bag_upgraded: bool = false
var battery_upgraded: bool = false
var goal_complete: bool = false
var aid_used: bool = false
var inventory: Array[Dictionary] = []
var health: float = 100.0
var trip_time: float = 210.0
var trip_active: bool = false

func battery_capacity() -> float:
	return 240.0 if battery_upgraded else 160.0

func bag_capacity() -> float:
	return 17.0 if bag_upgraded else 12.0

func weight() -> float:
	var result: float = 0.0
	for entry in inventory:
		result += float(entry.get("kg", 0.0))
	return result

func item(kind: String, contamination: int = 0) -> Dictionary:
	if not ITEMS.has(kind):
		return {}
	var entry: Dictionary = ITEMS[kind].duplicate(true)
	entry["kind"] = kind
	entry["contamination"] = contamination
	return entry

func market_multiplier(kind: String) -> float:
	var cycle: int = (day - 1) % 3
	if cycle == 0 and kind == "copper":
		return 1.35
	if cycle == 1 and kind == "meds":
		return 1.45
	if cycle == 2 and kind == "circuit":
		return 1.30
	return 1.0

func news() -> String:
	match (day - 1) % 3:
		0: return "排水泵站抢修中：铜线束收购价上涨35%。"
		1: return "区域医院补充储备：医疗包收购价上涨45%。"
		_: return "南线通信检修：通信电路板收购价上涨30%。"

func price(entry: Dictionary) -> float:
	return snappedf(float(entry.get("value", 0.0)) * market_multiplier(str(entry.get("kind", ""))), 0.1)

func can_take(entry: Dictionary) -> bool:
	return not entry.is_empty() and weight() + float(entry.get("kg", 0.0)) <= bag_capacity() + 0.001

func take(entry: Dictionary) -> bool:
	if not can_take(entry):
		return false
	inventory.append(entry.duplicate(true))
	return true

func spend_energy(amount: float) -> bool:
	if amount < 0.0 or battery + 0.0001 < amount:
		return false
	battery = maxf(0.0, battery - amount)
	return true

func charge(request: float) -> float:
	if request <= 0.0:
		return 0.0
	var amount: float = minf(request, minf(account, minf(station_stock, battery_capacity() - battery)))
	amount = maxf(0.0, amount)
	account -= amount
	station_stock -= amount
	battery += amount
	return amount

func start_trip() -> String:
	if trip_active:
		return "已经在作业中。"
	if not inventory.is_empty():
		return "先去回收窗口处理背包里的物资，再出发。"
	if battery < 25.0:
		return "至少带25 Wh电量出站。先到充电窗口取电。"
	if account < 12.0:
		return "防护服租赁需要12 Wh。可在维修台领取应急工作。"
	account -= 12.0
	trip_time = 210.0
	health = 100.0
	trip_active = true
	return ""

func inspect() -> Dictionary:
	var report: Dictionary = {"accepted": [], "confiscated": [], "rejected": [], "earned": 0.0}
	if not trip_active:
		return report
	var had_cargo: bool = not inventory.is_empty()
	var accepted: Array[Dictionary] = []
	for entry in inventory:
		if int(entry.get("contamination", 0)) > 60:
			report["rejected"].append(str(entry["name"]))
		elif bool(entry.get("controlled", false)) and not permit:
			report["confiscated"].append(str(entry["name"]))
		else:
			accepted.append(entry)
			report["accepted"].append(str(entry["name"]))
	inventory = accepted
	if had_cargo:
		successful_trips += 1
	trip_active = false
	return report

func sell_normal() -> float:
	if trip_active:
		return 0.0
	var earned: float = 0.0
	var keep: Array[Dictionary] = []
	for entry in inventory:
		if bool(entry.get("controlled", false)):
			keep.append(entry)
		else:
			earned += price(entry)
	inventory = keep
	account += earned
	total_sales += earned
	return earned

func deliver_controlled() -> float:
	if not permit or trip_active:
		return 0.0
	var earned: float = 0.0
	var keep: Array[Dictionary] = []
	for entry in inventory:
		if bool(entry.get("controlled", false)):
			earned += float(entry["value"]) + 40.0
			goal_complete = true
		else:
			keep.append(entry)
	inventory = keep
	account += earned
	total_sales += earned
	return earned

func buy_upgrade(kind: String) -> String:
	if trip_active:
		return "请返回站内办理。"
	match kind:
		"bag":
			if bag_upgraded: return "背包已经升级。"
			if account < 95.0: return "需要95 Wh账户余额。"
			account -= 95.0
			bag_upgraded = true
		"battery":
			if battery_upgraded: return "电池已经升级。"
			if account < 110.0: return "需要110 Wh账户余额。"
			account -= 110.0
			battery_upgraded = true
		"permit":
			if permit: return "已经持有特许回收证。"
			if successful_trips < 2: return "需要完成两次带货安全返回。"
			if account < 180.0: return "办理费用为180 Wh。"
			account -= 180.0
			permit = true
		_: return "未知项目。"
	return ""

func rescue() -> float:
	var fee: float = minf(account, 25.0)
	account -= fee
	inventory.clear()
	battery = maxf(battery, 25.0)
	health = 100.0
	trip_active = false
	return fee

func emergency_work() -> bool:
	if trip_active or aid_used or account >= 60.0:
		return false
	account += 45.0
	aid_used = true
	return true

func next_day() -> void:
	day += 1
	station_stock = 400.0
	aid_used = false
	health = 100.0

func save_game(path: String) -> Error:
	if trip_active:
		return ERR_BUSY
	var values: Dictionary = {"version": SAVE_VERSION}
	for key in ["account", "battery", "station_stock", "day", "successful_trips", "total_sales", "permit", "bag_upgraded", "battery_upgraded", "goal_complete", "aid_used", "inventory"]:
		values[key] = get(key)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(values, "\t"))
	return OK

func load_game(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		return false
	# Validate the full payload before changing any live state.
	for key in ["account", "battery", "station_stock", "day", "successful_trips", "total_sales"]:
		if not parsed.has(key) or not (parsed[key] is float or parsed[key] is int):
			return false
		if not is_finite(float(parsed[key])) or float(parsed[key]) < 0.0:
			return false
	for key in ["permit", "bag_upgraded", "battery_upgraded", "goal_complete", "aid_used"]:
		if not parsed.get(key) is bool:
			return false
	if not parsed.get("inventory") is Array:
		return false
	var checked: Array[Dictionary] = []
	for raw in parsed["inventory"]:
		if not raw is Dictionary or not ITEMS.has(str(raw.get("kind", ""))):
			return false
		checked.append(item(str(raw["kind"]), clampi(int(raw.get("contamination", 0)), 0, 100)))
	for key in ["account", "station_stock", "total_sales", "permit", "bag_upgraded", "battery_upgraded", "goal_complete", "aid_used"]:
		set(key, parsed[key])
	day = maxi(1, int(parsed["day"]))
	successful_trips = int(parsed["successful_trips"])
	battery = clampf(float(parsed["battery"]), 0.0, battery_capacity())
	inventory = checked
	health = 100.0
	trip_active = false
	return true
