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
}
const LOOT_KINDS := ["copper", "tools", "meds", "powercore", "circuit"]
const RARITY := {
	"book": 0, "copper": 0, "tools": 1,
	"meds": 2, "circuit": 2, "relic": 2, "powercore": 3,
}
const RARITY_NAMES := ["普通", "少见", "稀有", "珍稀"]
const RARITY_COLORS := [Color("bfc3ce"), Color("e4be76"), Color("ffa271"), Color("ff7873")]
const EPOCH := "2026-07-11T00:00:00"

var station := START_STATION
var locker: Array[Dictionary] = []
var wide_bag := false
var collected: Dictionary = {}
var gear: Dictionary = {}
var next_id := 1
var market_usage: Dictionary = {}

func date_text(extra_days: int = 0) -> String:
	var start := Time.get_unix_time_from_datetime_string(EPOCH)
	return Time.get_date_string_from_unix_time(start + (day - 1 + extra_days) * 86400).replace("-", ".")

func weather() -> String:
	return ["阴", "小雨", "雾", "晴"][(day - 1) % 4]

func news() -> String:
	return super.news().replace("收购价", "今日报价")

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
	if slot < 0 or slot >= LOOT_KINDS.size() or not trip_active:
		return ""
	if slot in collected.get(station, []):
		return ""
	if slot == 3 and not gear.crowbar or slot == 4 and not gear.light:
		return ""
	return LOOT_KINDS[slot]

func picked(container: String, id: int) -> Dictionary:
	if container == "ground":
		var kind := ground_kind(id)
		return {} if kind.is_empty() else {"kind": kind, "rotated": false}
	return find_entry(container, id)

func can_place(selection: Dictionary, target: String, cell: Vector2i) -> bool:
	if target not in ["bag", "locker"] or trip_active and target == "locker":
		return false
	var source: String = selection.source
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
	var terms: Array = profile[side].get(kind, [])
	if terms.is_empty():
		return {}
	var used: int = market_usage.get(market_key(market_station, side, kind), 0)
	return {
		"price": snappedf(float(terms[0]) * market_multiplier(kind), 0.1),
		"remaining": maxi(0, int(terms[1]) - used),
	}

func market_key(location: String, side: String, kind: String) -> String:
	return "%s/%s/%s" % [location, side, kind]

func record_trade(side: String, kind: String) -> void:
	var key := market_key(station, side, kind)
	market_usage[key] = market_usage.get(key, 0) + 1

func sell(id: int) -> float:
	var entry := find_entry("bag", id)
	if trip_active or entry.is_empty():
		return 0.0
	var offer := market_offer("demand", entry.kind)
	if offer.is_empty() or offer.remaining == 0:
		return 0.0
	var paid: float = offer.price
	inventory.erase(entry)
	account += paid
	record_trade("demand", entry.kind)
	return paid

func purchase(kind: String) -> String:
	if trip_active:
		return "回到车厢后可交易。"
	var offer := market_offer("stock", kind)
	if offer.is_empty():
		return "本站不出售这件物品。"
	if offer.remaining == 0:
		return "今天的库存已售完。"
	var cost: float = offer.price
	if account < cost:
		return "电力余额不足。"
	var bounds := bag_size()
	for rotated in [false, true]:
		var shape := footprint(kind, rotated)
		for y in range(bounds.y):
			for x in range(bounds.x):
				var cell := Vector2i(x, y)
				if fits(inventory, bounds, Rect2i(cell, shape)):
					inventory.append(make_entry(kind, cell, rotated))
					account -= cost
					record_trade("stock", kind)
					return ""
	return "背包没有合适的空位。"

func next_day() -> void:
	super.next_day()
	market_usage.clear()

func depart(loadout: Dictionary, radiation: int) -> String:
	if trip_active:
		return "已经出发。"
	if radiation >= 3 and not loadout.heavy:
		return "高辐射区需要加强防护服。"
	var rent := 30.0 if loadout.heavy else 12.0
	if account < rent:
		return "电力余额不足，无法租用防护服。"
	var bounds := LARGE if loadout.wide else SMALL
	for entry in inventory:
		if not Rect2i(Vector2i.ZERO, bounds).encloses(item_rect(entry)):
			return "有物品超出所选背包的边界，请先在柜子里整理。"
	account -= rent
	gear = loadout.duplicate()
	wide_bag = loadout.wide
	trip_active = true
	return ""

func save_next_day(path: String) -> Error:
	if trip_active:
		return ERR_BUSY
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var data := {
		"version": 1, "day": day + 1, "account": account, "station": station,
		"wide": wide_bag, "bag": inventory, "locker": locker,
	}
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	err = file.get_error()
	file.close()
	if err == OK:
		err = DirAccess.rename_absolute(temp, path)
	if err != OK:
		DirAccess.remove_absolute(temp)
		return err
	next_day()
	collected.clear()
	return OK

func load_cabin(path: String, known_stations: Array) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version") != 1:
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
	trip_active = false
	collected.clear()
	market_usage.clear()
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
		cargo.append({"id": 0, "kind": entry.kind, "x": cell.x, "y": cell.y, "rotated": entry.rotated})
	return {"entries": cargo}
