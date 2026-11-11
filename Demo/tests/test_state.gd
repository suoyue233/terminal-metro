@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "game_state"

const Data = preload("res://scripts/state.gd")
var failures: int = 0
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	assert_true(value, message)

func test_economy_recovery_permit_and_save() -> void:
	checks = 0
	failures = 0
	var state = Data.new()
	state.battery = 100
	state.account = 100
	state.station_stock = 15
	check(state.charge(40) == 15, "Charging must respect station stock")
	check(state.account == 85 and state.battery == 115 and state.station_stock == 0, "Charging conserves energy and money")
	check(state.charge(-9) == 0, "Negative withdrawal is not a deposit exploit")
	check(not state.spend_energy(-8), "Negative tool consumption is rejected")
	check(not state.spend_energy(999), "No battery overdraft")
	check(state.buy_upgrade("permit") != "", "Early permit purchase is blocked")
	check(state.start_trip() == "", "Prepared player can depart")
	check(state.start_trip() != "", "Double departure cannot double-charge")
	check(state.take(state.item("powercore")), "Heavy equipment fits an empty bag")
	check(not state.take(state.item("powercore")), "Weight limit is enforced")
	state.inventory.clear()
	state.take(state.item("controller"))
	state.take(state.item("copper", 85))
	state.take(state.item("meds"))
	var report: Dictionary = state.inspect()
	check(report["confiscated"].size() == 1, "Unlicensed control items are confiscated")
	check(report["rejected"].size() == 1, "Contamination is checked separately")
	check(state.inventory.size() == 1 and state.successful_trips == 1, "Only accepted cargo enters station")
	state.inspect()
	check(state.successful_trips == 1, "Repeated inspection does not grant free progression")
	check(state.sell_normal() == 54, "Ordinary goods are paid at market price")
	check(state.sell_normal() == 0, "Goods cannot be sold twice")
	state.account = 1000
	state.successful_trips = 2
	check(state.buy_upgrade("permit") == "", "Two returns unlock paid permit")
	state.start_trip()
	state.take(state.item("controller"))
	state.inspect()
	check(state.inventory.size() == 1, "Licensed control item passes inspection")
	check(state.sell_normal() == 0, "Market cannot sell control items")
	check(state.deliver_controlled() == 210 and state.goal_complete, "Government delivery pays and completes objective")
	var before: float = state.account
	check(state.deliver_controlled() == 0 and state.account == before, "Delivery cannot duplicate money")
	state.battery = 80
	state.buy_upgrade("battery")
	check(state.battery == 80 and state.battery_capacity() == 240, "Capacity upgrade does not manufacture electricity")
	state.day = 2
	check(is_equal_approx(state.price(state.item("meds")), 78.3), "Daily news affects relevant prices")
	var path: String = ProjectSettings.globalize_path("res://tests/state_save.json")
	check(state.save_game(path) == OK, "Save writes successfully")
	var restored = Data.new()
	check(restored.load_game(path), "Save loads successfully")
	check(restored.permit and restored.goal_complete and restored.battery_upgraded, "Progression survives loading")
	check(is_equal_approx(restored.account, state.account), "Account survives loading")
	var broken: String = ProjectSettings.globalize_path("res://tests/broken_save.json")
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string('{"version":1,"account":-99}')
	file.close()
	var stable_balance: float = restored.account
	check(not restored.load_game(broken) and restored.account == stable_balance, "Bad save cannot partially mutate a live state")
	state.account = 0
	state.battery = 0
	state.rescue()
	check(state.battery >= 25 and state.account == 0, "Rescue never creates debt or leaves no emergency power")
	check(state.emergency_work(), "Emergency work recovers spending money")
	check(not state.emergency_work(), "Emergency work cannot be farmed in one day")
	state.next_day()
	check(state.emergency_work(), "Resting restores access to daily recovery work")
	print("STATE_TESTS: %d checks, %d failures" % [checks, failures])
	assert_eq(checks, 32, "All 32 original state checks must run")
