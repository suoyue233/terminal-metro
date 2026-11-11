extends "res://scripts/state.gd"

const Markets = preload("res://scripts/cabin_markets.gd")
const START_STATION := "邮电新村"
const SMALL := Vector2i(5, 4)
const LARGE := Vector2i(6, 5)
const LOCKER := Vector2i(8, 5)
const FOOTPRINTS := {
	"copper": Vector2i(1, 2), "tools": Vector2i(3, 1),
	"book": Vector2i(1, 2), "meds": Vector2i(2, 2),
	"circuit": Vector2i(2, 1), "powercore": Vector2i(3, 2),
	"relic": Vector2i(2, 2),
	"aaa": Vector2i.ONE, "water": Vector2i.ONE, "ration": Vector2i.ONE,
}
const SUPPLY_NAMES := {"aaa": "七号电池", "water": "饮用水", "ration": "口粮"}
const RARITY := {
	"book": 0, "copper": 0, "tools": 1,
	"meds": 2, "circuit": 2, "relic": 2, "powercore": 3,
	"aaa": 0, "water": 0, "ration": 0,
}
const RARITY_NAMES := ["普通", "少见", "稀有", "珍稀"]
const RARITY_COLORS := [Color("bfc3ce"), Color("e4be76"), Color("ffa271"), Color("ff7873")]
const EPOCH := "2026-07-11T00:00:00"
const CABIN_SAVE_VERSION := 3
const CAR_CAPACITY := 500.0
const CAR_START_POWER := 100.0
const ACCOUNT_START_POWER := 100.0
const STATION_CHARGE_CAP := 200
const TRAVEL_COST_PER_STOP := 30
const BATTERY_FILL_COST := 2.0
const COMPUTER_DAILY_COST := 2.0
const FULL_CHARGE := 100
const PICKUP_CHARGE := 50
const NO_CELL := -1
const PICKUP_TIME_MS := 5000
const BLACKOUT_INTERVAL := 5

var station := START_STATION
var locker: Array[Dictionary] = []
var wide_bag := false
var collected: Dictionary = {}
var gear: Dictionary = {}
var next_id := 1
var market_usage: Dictionary = {}
var installed_charge := FULL_CHARGE
var trip_deadline_ms := 0
var debt := 0.0
var days_in_debt := 0
var days_without_water := 0
var days_without_food := 0
var drank_today := false
var ate_today := false
var game_over_reason := ""
var car_power := CAR_START_POWER
var world_seed := randi()
var charger_used: Dictionary = {}
var trip_loot: Array[String] = []

func _init() -> void:
	account = ACCOUNT_START_POWER
	give_starter_supplies()

func date_unix(extra_days: int = 0) -> int:
	return Time.get_unix_time_from_datetime_string(EPOCH) + (day - 1 + extra_days) * 86400

func date_text(extra_days: int = 0) -> String:
	return Time.get_date_string_from_unix_time(date_unix(extra_days)).replace("-", ".")

func weather() -> String:
	return ["阴", "小雨", "雾", "晴"][(day - 1) % 4]

func news() -> String:
	var text := super.news().replace("收购价", "今日报价")
	if is_blackout():
		return text + "\n今日全线停电，充电站暂停，满电七号电池涨价 50%。"
	if is_blackout(1):
		return text + "\n明日计划停电，可提前充满备用电池。"
	return text

func is_blackout(extra_days: int = 0) -> bool:
	return (day + extra_days) % BLACKOUT_INTERVAL == 0

func has_charger(location: String) -> bool:
	return location in Markets.CHARGERS

func station_roll(location: String, purpose: String, maximum: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, day, location, purpose])
	return rng.randi_range(0, maximum)

func charger_stock(location: String) -> float:
	if is_blackout() or not has_charger(location):
		return 0.0
	var daily_supply := station_roll(location, "charger", roundi(STATION_CHARGE_CAP / 10.0)) * 10
	return maxf(0.0, daily_supply - float(charger_used.get(location, 0.0)))

func car_charge_limit() -> float:
	return minf(charger_stock(station), CAR_CAPACITY - car_power)

func charge_car(requested: float) -> float:
	if trip_active or not game_over_reason.is_empty() or not is_finite(requested) or requested <= 0.0:
		return 0.0
	var amount := car_charge_limit()
	if amount <= 0.0:
		return 0.0
	amount = minf(requested, amount)
	spend_or_owe(amount)
	car_power += amount
	charger_used[station] = float(charger_used.get(station, 0.0)) + amount
	return amount

func travel_to(destination: String, steps: int) -> bool:
	var cost := steps * TRAVEL_COST_PER_STOP
	if trip_active or not game_over_reason.is_empty() or destination == station or cost <= 0 or car_power < cost:
		return false
	car_power -= cost
	station = destination
	return true

func item_name(kind: String) -> String:
	return SUPPLY_NAMES[kind] if SUPPLY_NAMES.has(kind) else ITEMS[kind].name

func rarity_name(kind: String) -> String:
	return RARITY_NAMES[RARITY[kind]]

func rarity_color(kind: String) -> Color:
	return RARITY_COLORS[RARITY[kind]]

func bag_size() -> Vector2i:
	return LARGE if wide_bag else SMALL

func entries(container: String) -> Array[Dictionary]:
	return locker if container == "locker" else inventory

func grid_size(container: String) -> Vector2i:
	return LOCKER if container == "locker" else bag_size()

func footprint(kind: String, rotated: bool = false) -> Vector2i:
	var shape: Vector2i = FOOTPRINTS[kind]
	return Vector2i(shape.y, shape.x) if rotated else shape

func item_rect(entry: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(entry.x, entry.y), footprint(entry.kind, entry.rotated))

func entry_at(container: String, cell: Vector2i) -> Dictionary:
	for entry in entries(container):
		if item_rect(entry).has_point(cell):
			return entry
	return {}

func find_entry(container: String, id: int) -> Dictionary:
	for entry in entries(container):
		if entry.id == id:
			return entry
	return {}

func fits(cargo: Array[Dictionary], bounds: Vector2i, box: Rect2i, ignore_id: int = -1) -> bool:
	if not Rect2i(Vector2i.ZERO, bounds).encloses(box):
		return false
	for entry in cargo:
		if entry.id != ignore_id and item_rect(entry).intersects(box):
			return false
	return true

func ground_kind(slot: int) -> String:
	if slot < 0 or slot >= trip_loot.size() or not trip_active:
		return ""
	if slot in collected.get(station, []):
		return ""
	return trip_loot[slot]

func roll_loot(danger: int, crowbar: bool) -> Array[String]:
	var rare_chance := 12 + 6 * danger
	var medical := station_roll(station, "medical", 99) < rare_chance
	var circuit := station_roll(station, "circuit", 99) < rare_chance
	var powercore := danger >= 3 and crowbar and station_roll(station, "powercore", 99) < 12
	return ["copper", "tools", "meds" if medical else "book", "powercore" if powercore else "", "circuit" if circuit else ""]

func picked(container: String, id: int) -> Dictionary:
	if container == "ground":
		var kind := ground_kind(id)
		return {} if kind.is_empty() else {"kind": kind, "rotated": false}
	return find_entry(container, id)

func can_place(selection: Dictionary, target: String, cell: Vector2i) -> bool:
	if target not in ["bag", "locker"] or trip_active and target == "locker":
		return false
	var source: String = selection.source
	if source == "ground" and not pickup_problem().is_empty():
		return false
	var id: int = selection.id
	var entry := picked(source, id)
	if entry.is_empty():
		return false
	var rect := Rect2i(cell, footprint(entry.kind, selection.rotated))
	return fits(entries(target), grid_size(target), rect, id if source == target else -1)

func place(selection: Dictionary, target: String, cell: Vector2i) -> bool:
	if not can_place(selection, target, cell):
		return false
	var source: String = selection.source
	var id: int = selection.id
	var entry := picked(source, id)
	if source == "ground":
		if not collected.has(station):
			collected[station] = []
		collected[station].append(id)
		entry = make_entry(entry.kind, cell, selection.rotated)
		installed_charge -= PICKUP_CHARGE
		trip_deadline_ms -= PICKUP_TIME_MS
	elif source != target:
		entries(source).erase(entry)
	if source != target:
		entries(target).append(entry)
	entry.x = cell.x
	entry.y = cell.y
	entry.rotated = selection.rotated
	return true

func make_entry(kind: String, cell: Vector2i, rotated: bool) -> Dictionary:
	var entry := {"id": next_id, "kind": kind, "x": cell.x, "y": cell.y, "rotated": rotated}
	if kind == "aaa":
		entry.charge = FULL_CHARGE
	next_id += 1
	return entry

func used_cells(container: String) -> int:
	var occupied := 0
	for entry in entries(container):
		occupied += item_rect(entry).get_area()
	return occupied

func market_offer(side: String, kind: String, location: String = "") -> Dictionary:
	var market_station := station if location.is_empty() else location
	var profile := Markets.profile(market_station)
	var catalog: Dictionary = Markets.ESSENTIALS if side == "stock" and Markets.ESSENTIALS.has(kind) else profile[side]
	var terms: Array = catalog.get(kind, [])
	if terms.is_empty():
		return {}
	var used: int = market_usage.get(market_key(market_station, side, kind), 0)
	var multiplier := 1.5 if kind == "aaa" and is_blackout() else market_multiplier(kind)
	return {
		"price": snappedf(float(terms[0]) * multiplier, 0.1),
		"remaining": maxi(0, int(terms[1]) - used),
	}

func market_key(location: String, side: String, kind: String) -> String:
	return "%s/%s/%s" % [location, side, kind]

func record_trade(side: String, kind: String) -> void:
	var key := market_key(station, side, kind)
	market_usage[key] = market_usage.get(key, 0) + 1

func credit_shortfall(amount: float) -> float:
	return snappedf(maxf(0.0, amount - account), 0.1)

func spend_or_owe(amount: float) -> void:
	debt = snappedf(debt + credit_shortfall(amount), 0.1)
	account = maxf(0.0, account - amount)

func sell(id: int) -> float:
	var entry := find_entry("bag", id)
	if trip_active or entry.is_empty() or not game_over_reason.is_empty():
		return 0.0
	var offer := market_offer("demand", entry.kind)
	if offer.is_empty() or offer.remaining == 0:
		return 0.0
	var paid: float = offer.price
	inventory.erase(entry)
	var repayment := minf(paid, debt)
	debt = snappedf(debt - repayment, 0.1)
	account += paid - repayment
	record_trade("demand", entry.kind)
	return paid

func purchase(kind: String) -> String:
	if trip_active or not game_over_reason.is_empty():
		return "回到车厢后可交易。"
	var offer := market_offer("stock", kind)
	if offer.is_empty():
		return "本站不出售这件物品。"
	if offer.remaining == 0:
		return "今天的库存已售完。"
	var cost: float = offer.price
	if not add_supply(kind, "bag"):
		return "背包没有合适的空位。"
	spend_or_owe(cost)
	record_trade("stock", kind)
	return ""

func add_supply(kind: String, container: String) -> bool:
	var bounds := grid_size(container)
	var cargo := entries(container)
	for rotated in [false, true]:
		var shape := footprint(kind, rotated)
		for y in range(bounds.y):
			for x in range(bounds.x):
				var cell := Vector2i(x, y)
				if fits(cargo, bounds, Rect2i(cell, shape)):
					cargo.append(make_entry(kind, cell, rotated))
					return true
	return false

func give_starter_supplies() -> void:
	for kind in ["aaa", "water", "ration"]:
		if not add_supply(kind, "bag"):
			add_supply(kind, "locker")

func supply_count(kind: String) -> int:
	var count := 0
	for entry in inventory + locker:
		if entry.kind == kind:
			count += 1
	return count

func consume_supply(kind: String) -> String:
	if trip_active or not game_over_reason.is_empty() or kind not in ["water", "ration"]:
		return "当前无法使用补给。"
	var water := kind == "water"
	if (water and drank_today) or (not water and ate_today):
		return "今日已%s。" % ("喝水" if water else "进食")
	for cargo in [inventory, locker]:
		for entry in cargo:
			if entry.kind == kind:
				cargo.erase(entry)
				if water:
					drank_today = true
				else:
					ate_today = true
				return ""
	return "没有%s，可到交易窗口购买。" % item_name(kind)

func usable_spares() -> int:
	var count := 0
	for entry in inventory:
		if entry.kind == "aaa" and entry.charge >= PICKUP_CHARGE:
			count += 1
	return count

func spare_battery() -> Dictionary:
	var best: Dictionary = {}
	var charge_to_beat := maxi(installed_charge, PICKUP_CHARGE - 1)
	for entry in inventory:
		if entry.kind == "aaa" and entry.charge > charge_to_beat:
			best = entry
			charge_to_beat = entry.charge
	return best

func replace_battery() -> String:
	var entry := spare_battery()
	if entry.is_empty():
		return "背包里没有电量更高的可用七号电池。"
	var replacement: int = entry.charge
	if installed_charge == NO_CELL:
		inventory.erase(entry)
	else:
		entry.charge = installed_charge
	installed_charge = replacement
	return ""

func battery_fill_cost(charge_level: int) -> float:
	if charge_level == NO_CELL:
		return 0.0
	return ceilf((FULL_CHARGE - charge_level) * BATTERY_FILL_COST / FULL_CHARGE)

func recharge_battery(id: int) -> String:
	if trip_active or not game_over_reason.is_empty():
		return "返回车厢后可给电池充电。"
	var entry := find_entry("bag", id) if id != NO_CELL else {}
	var charge_level := installed_charge if id == NO_CELL else int(entry.get("charge", NO_CELL))
	var cost := battery_fill_cost(charge_level)
	if cost <= 0.0:
		return "这节电池无需充电。"
	if car_power < cost:
		return "车内储电不足。"
	car_power -= cost
	if id == NO_CELL:
		installed_charge = FULL_CHARGE
	else:
		entry.charge = FULL_CHARGE
	return ""

func next_day() -> void:
	super.next_day()
	market_usage.clear()
	charger_used.clear()
	car_power = overnight_power()

func overnight_power() -> float:
	return maxf(0.0, car_power - COMPUTER_DAILY_COST)

func trip_limit() -> int:
	var month: int = Time.get_datetime_dict_from_unix_time(date_unix()).month
	var forecast := weather()
	return 20 if "雨" in forecast or (forecast == "晴" and month in [6, 7, 8]) else 30

func remaining_ms() -> int:
	return maxi(0, trip_deadline_ms - Time.get_ticks_msec()) if trip_active else 0

func pickup_problem() -> String:
	if not trip_active or remaining_ms() == 0:
		return "外出时间已用完。"
	if installed_charge < PICKUP_CHARGE:
		return "手电筒电量不足，换上有电的七号电池后再拾取。"
	return ""

func suit_rent(heavy: bool) -> int:
	return 50 if heavy else 30

func depart(loadout: Dictionary, radiation: int) -> String:
	if trip_active or not game_over_reason.is_empty():
		return "已经出发。"
	if not loadout.get("light", false) or installed_charge <= 0:
		return "出站必须带手电筒并装入有电的七号电池。"
	if radiation >= 3 and not loadout.heavy:
		return "高辐射区需要加强防护服。"
	var bounds := LARGE if loadout.wide else SMALL
	for entry in inventory:
		if not Rect2i(Vector2i.ZERO, bounds).encloses(item_rect(entry)):
			return "有物品超出所选背包的边界，请先在柜子里整理。"
	spend_or_owe(suit_rent(loadout.heavy))
	gear = loadout.duplicate()
	trip_loot = roll_loot(radiation, gear.crowbar)
	wide_bag = loadout.wide
	trip_active = true
	trip_deadline_ms = Time.get_ticks_msec() + trip_limit() * 1000
	return ""

func end_trip() -> void:
	trip_active = false
	trip_deadline_ms = 0
	gear.clear()
	trip_loot.clear()

func fail_trip() -> int:
	if not trip_active:
		return 0
	var fee := 500 if gear.heavy else 300
	spend_or_owe(fee)
	inventory.clear()
	installed_charge = NO_CELL
	end_trip()
	return fee

func survival_after_day() -> Dictionary:
	var dry_days := 0 if drank_today else days_without_water + 1
	var hungry_days := 0 if ate_today else days_without_food + 1
	var overdue_days := days_in_debt + 1 if debt > 0.0 else 0
	var reasons := PackedStringArray()
	if dry_days >= 2:
		reasons.append("连续两天未喝水")
	if hungry_days >= 3:
		reasons.append("连续三天未进食")
	if overdue_days >= 2:
		reasons.append("连续两天欠费未结清")
	return {
		"days_without_water": dry_days,
		"days_without_food": hungry_days,
		"days_in_debt": overdue_days,
		"drank_today": false,
		"ate_today": false,
		"game_over_reason": "、".join(reasons),
	}

func save_next_day(path: String) -> Error:
	if trip_active or not game_over_reason.is_empty():
		return ERR_BUSY
	var data := save_data()
	data.day = day + 1
	data.charger_used = {}
	data.car_power = overnight_power()
	data.merge(survival_after_day(), true)
	var err := write_save(path, data)
	if err != OK:
		return err
	next_day()
	restore_vitals(data)
	collected.clear()
	return OK

func save_current(path: String) -> Error:
	if trip_active:
		return ERR_BUSY
	return write_save(path, save_data())

func save_data() -> Dictionary:
	return {
		"version": CABIN_SAVE_VERSION, "day": day, "account": account, "station": station,
		"wide": wide_bag, "bag": inventory, "locker": locker,
		"installed_charge": installed_charge, "debt": debt,
		"days_in_debt": days_in_debt, "days_without_water": days_without_water,
		"days_without_food": days_without_food, "drank_today": drank_today,
		"ate_today": ate_today, "game_over_reason": game_over_reason,
		"car_power": car_power, "world_seed": world_seed, "charger_used": charger_used,
	}

func write_save(path: String, data: Dictionary) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	err = file.get_error()
	file.close()
	if err == OK:
		err = DirAccess.rename_absolute(temp, path)
	if err != OK:
		DirAccess.remove_absolute(temp)
	return err

func restore_vitals(data: Dictionary) -> void:
	installed_charge = int(data.get("installed_charge", FULL_CHARGE))
	debt = float(data.get("debt", 0.0))
	days_in_debt = int(data.get("days_in_debt", 0))
	days_without_water = int(data.get("days_without_water", 0))
	days_without_food = int(data.get("days_without_food", 0))
	drank_today = data.get("drank_today", false)
	ate_today = data.get("ate_today", false)
	game_over_reason = data.get("game_over_reason", "")

func valid_vitals(data: Dictionary) -> bool:
	var amount: Variant = data.get("debt")
	if not (amount is float or amount is int) or not is_finite(amount) or amount < 0:
		return false
	return (valid_index(data.get("installed_charge"), NO_CELL, FULL_CHARGE)
		and valid_index(data.get("days_in_debt"), 0, 2)
		and valid_index(data.get("days_without_water"), 0, 2)
		and valid_index(data.get("days_without_food"), 0, 3)
		and data.get("drank_today") is bool and data.get("ate_today") is bool
		and data.get("game_over_reason") is String)

func valid_car_state(data: Dictionary) -> bool:
	var power: Variant = data.get("car_power")
	var used: Variant = data.get("charger_used")
	if not (power is float or power is int) or not is_finite(power) or power < 0 or power > CAR_CAPACITY:
		return false
	if not valid_index(data.get("world_seed"), 0, 0xffffffff) or not used is Dictionary:
		return false
	for location in used:
		var amount: Variant = used[location]
		if not has_charger(location) or not (amount is float or amount is int):
			return false
		if not is_finite(amount) or amount < 0 or amount > STATION_CHARGE_CAP:
			return false
	return true

func load_cabin(path: String, known_stations: Array) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return false
	var version: Variant = data.get("version")
	if version != 1 and version != 2 and version != CABIN_SAVE_VERSION:
		return false
	if version == CABIN_SAVE_VERSION and not valid_car_state(data):
		return false
	var needs_upgrade: bool = version == 1
	if not needs_upgrade and not valid_vitals(data):
		return false
	if data.get("station") not in known_stations or not data.get("wide") is bool:
		return false
	var balance: Variant = data.get("account")
	if not (balance is float or balance is int) or not is_finite(balance) or balance < 0:
		return false
	if not valid_index(data.get("day"), 1, 100000):
		return false
	var loaded_bag := read_cargo(data.get("bag"), LARGE if data.wide else SMALL)
	var loaded_locker := read_cargo(data.get("locker"), LOCKER)
	if loaded_bag.is_empty() or loaded_locker.is_empty():
		return false
	inventory.assign(loaded_bag.entries)
	locker.assign(loaded_locker.entries)
	# Reissue runtime IDs across both grids after validating the saved placements.
	next_id = 1
	for entry in inventory + locker:
		entry.id = next_id
		next_id += 1
	station = data.station
	wide_bag = data.wide
	account = balance
	day = int(data.day)
	if version == CABIN_SAVE_VERSION:
		car_power = float(data.car_power)
		world_seed = int(data.world_seed)
		charger_used = data.charger_used.duplicate()
	else:
		car_power = CAR_START_POWER
		world_seed = hash([station, day, account]) & 0xffffffff
		charger_used.clear()
	end_trip()
	collected.clear()
	market_usage.clear()
	restore_vitals({} if needs_upgrade else data)
	if needs_upgrade:
		give_starter_supplies()
	return true

func valid_index(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is float or value is int) and is_finite(value) and value == floor(value) and value >= minimum and value <= maximum

func read_cargo(raw: Variant, bounds: Vector2i) -> Dictionary:
	if not raw is Array:
		return {}
	var cargo: Array[Dictionary] = []
	for entry in raw:
		if not entry is Dictionary or not FOOTPRINTS.has(entry.get("kind")) or not entry.get("rotated") is bool:
			return {}
		if not valid_index(entry.get("x"), 0, bounds.x - 1) or not valid_index(entry.get("y"), 0, bounds.y - 1):
			return {}
		var cell := Vector2i(int(entry.x), int(entry.y))
		if not fits(cargo, bounds, Rect2i(cell, footprint(entry.kind, entry.rotated))):
			return {}
		var restored := {"id": 0, "kind": entry.kind, "x": cell.x, "y": cell.y, "rotated": entry.rotated}
		if entry.kind == "aaa":
			if not valid_index(entry.get("charge"), 0, FULL_CHARGE):
				return {}
			restored.charge = int(entry.charge)
		cargo.append(restored)
	return {"entries": cargo}
