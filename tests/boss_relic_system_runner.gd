extends SceneTree

const BossRelicSystemScript := preload("res://src/arena/boss_relic_system.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_pick_random_relic_returns_valid_values()
	_test_get_relic_name_non_empty()
	_test_get_relic_description_non_empty()
	_test_iron_relic()
	_test_corundum_relic()
	_test_moonstone_relic()
	_test_quicksilver_relic()
	_test_ebony_relic()
	_test_malachite_relic()

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("BOSS_RELIC_SYSTEM_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_pick_random_relic_returns_valid_values() -> void:
	var valid_values := [0, 1, 2, 3, 4, 5]
	var seen := {}
	for i in range(100):
		var relic: int = BossRelicSystemScript.pick_random_relic()
		_assert(relic in valid_values, "pick_random: got invalid relic value %d" % relic)
		seen[relic] = true

	# Over 100 picks we should see at least 3 distinct relics
	_assert(seen.size() >= 3, "pick_random: expected at least 3 distinct relics over 100 picks, got %d" % seen.size())


func _test_get_relic_name_non_empty() -> void:
	for relic_val in [0, 1, 2, 3, 4, 5]:
		var name: String = BossRelicSystemScript.get_relic_name(relic_val)
		_assert(name.length() > 0, "relic_name: relic %d returned empty name" % relic_val)


func _test_get_relic_description_non_empty() -> void:
	for relic_val in [0, 1, 2, 3, 4, 5]:
		var desc: String = BossRelicSystemScript.get_relic_description(relic_val)
		_assert(desc.length() > 0, "relic_desc: relic %d returned empty description" % relic_val)


func _test_iron_relic() -> void:
	var config: Dictionary = {}
	var result: Dictionary = BossRelicSystemScript.apply_relic_to_match_config(0, config)  # IRON = 0
	_assert(result.has("boss_health"), "iron: config should have boss_health")
	_assert(result.boss_health == 80, "iron: boss_health should be 80, got %s" % str(result.boss_health))


func _test_corundum_relic() -> void:
	var config: Dictionary = {}
	var result: Dictionary = BossRelicSystemScript.apply_relic_to_match_config(1, config)  # CORUNDUM = 1
	_assert(result.has("boss_creature_attack_bonus"), "corundum: config should have boss_creature_attack_bonus")
	_assert(result.boss_creature_attack_bonus == 1, "corundum: boss_creature_attack_bonus should be 1, got %s" % str(result.boss_creature_attack_bonus))


func _test_moonstone_relic() -> void:
	var config: Dictionary = {}
	var result: Dictionary = BossRelicSystemScript.apply_relic_to_match_config(2, config)  # MOONSTONE = 2
	_assert(result.has("boss_rune_break_card"), "moonstone: config should have boss_rune_break_card")
	_assert(result.boss_rune_break_card == true, "moonstone: boss_rune_break_card should be true")


func _test_quicksilver_relic() -> void:
	var config: Dictionary = {}
	var result: Dictionary = BossRelicSystemScript.apply_relic_to_match_config(3, config)  # QUICKSILVER = 3
	_assert(result.has("player_start_of_turn_damage"), "quicksilver: config should have player_start_of_turn_damage")
	_assert(result.player_start_of_turn_damage == 1, "quicksilver: player_start_of_turn_damage should be 1, got %s" % str(result.player_start_of_turn_damage))


func _test_ebony_relic() -> void:
	var config: Dictionary = {}
	var result: Dictionary = BossRelicSystemScript.apply_relic_to_match_config(4, config)  # EBONY = 4
	_assert(result.has("boss_city_gates"), "ebony: config should have boss_city_gates")
	_assert(result.boss_city_gates == true, "ebony: boss_city_gates should be true")


func _test_malachite_relic() -> void:
	var config: Dictionary = {}
	var result: Dictionary = BossRelicSystemScript.apply_relic_to_match_config(5, config)  # MALACHITE = 5
	_assert(result.has("boss_starting_guards"), "malachite: config should have boss_starting_guards")
	var guards: Array = result.boss_starting_guards
	_assert(guards.size() == 1, "malachite: should have 1 guard spec, got %d" % guards.size())
	var guard: Dictionary = guards[0]
	_assert(guard.attack == 0, "malachite: guard attack should be 0, got %s" % str(guard.attack))
	_assert(guard.health == 4, "malachite: guard health should be 4, got %s" % str(guard.health))
	_assert(guard.guard == true, "malachite: guard.guard should be true")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
