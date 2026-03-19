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
	_test_card_templates()

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
	var config: Dictionary = BossRelicSystemScript.get_boss_config(0)  # IRON = 0
	_assert(config.has("boss_health"), "iron: config should have boss_health")
	_assert(int(config.get("boss_health", 0)) == 50, "iron: boss_health should be 50, got %s" % str(config.get("boss_health", 0)))


func _test_corundum_relic() -> void:
	var config: Dictionary = BossRelicSystemScript.get_boss_config(1)  # CORUNDUM = 1
	var template: Dictionary = BossRelicSystemScript.get_relic_card_template(1)
	_assert(template.has("aura"), "corundum: template should have aura")
	var aura: Dictionary = template.get("aura", {})
	_assert(str(aura.get("scope", "")) == "all_lanes", "corundum: aura scope should be all_lanes")
	_assert(int(aura.get("power", 0)) == 1, "corundum: aura power should be 1")


func _test_moonstone_relic() -> void:
	var template: Dictionary = BossRelicSystemScript.get_relic_card_template(2)  # MOONSTONE = 2
	var abilities: Array = template.get("triggered_abilities", [])
	_assert(abilities.size() == 1, "moonstone: should have 1 triggered ability")
	var ability: Dictionary = abilities[0]
	_assert(str(ability.get("family", "")) == "on_enemy_rune_destroyed", "moonstone: family should be on_enemy_rune_destroyed")


func _test_quicksilver_relic() -> void:
	var template: Dictionary = BossRelicSystemScript.get_relic_card_template(3)  # QUICKSILVER = 3
	var abilities: Array = template.get("triggered_abilities", [])
	_assert(abilities.size() == 1, "quicksilver: should have 1 triggered ability")
	var ability: Dictionary = abilities[0]
	_assert(str(ability.get("family", "")) == "start_of_turn", "quicksilver: family should be start_of_turn")
	var effects: Array = ability.get("effects", [])
	_assert(effects.size() == 1, "quicksilver: should have 1 effect")
	_assert(int(effects[0].get("amount", 0)) == 1, "quicksilver: damage amount should be 1")


func _test_ebony_relic() -> void:
	var config: Dictionary = BossRelicSystemScript.get_boss_config(4)  # EBONY = 4
	var creatures: Array = config.get("starting_creatures", [])
	_assert(creatures.size() == 1, "ebony: should have 1 starting creature, got %d" % creatures.size())
	var gates: Dictionary = creatures[0]
	_assert(str(gates.get("name", "")) == "City Gates", "ebony: creature should be City Gates")
	_assert(int(gates.get("health", 0)) == 6, "ebony: City Gates health should be 6")
	_assert(gates.get("keywords", []).has("guard"), "ebony: City Gates should have guard")


func _test_malachite_relic() -> void:
	var config: Dictionary = BossRelicSystemScript.get_boss_config(5)  # MALACHITE = 5
	var creatures: Array = config.get("starting_creatures", [])
	_assert(creatures.size() == 2, "malachite: should have 2 starting creatures, got %d" % creatures.size())
	for i in range(creatures.size()):
		var guard: Dictionary = creatures[i]
		_assert(int(guard.get("power", -1)) == 0, "malachite: guard %d power should be 0" % i)
		_assert(int(guard.get("health", 0)) == 4, "malachite: guard %d health should be 4" % i)
		_assert(guard.get("keywords", []).has("guard"), "malachite: guard %d should have guard" % i)
		_assert(int(guard.get("lane_index", -1)) == i, "malachite: guard %d lane_index should be %d" % [i, i])


func _test_card_templates() -> void:
	for relic_val in [0, 1, 2, 3, 4, 5]:
		var template: Dictionary = BossRelicSystemScript.get_relic_card_template(relic_val)
		_assert(str(template.get("card_type", "")) == "support", "template %d: card_type should be support" % relic_val)
		_assert(int(template.get("cost", -1)) == 0, "template %d: cost should be 0" % relic_val)
		_assert(int(template.get("support_uses", -1)) == 0, "template %d: support_uses should be 0 (ongoing)" % relic_val)
		_assert(str(template.get("name", "")).length() > 0, "template %d: name should be non-empty" % relic_val)
		_assert(str(template.get("definition_id", "")).begins_with("boss_relic_"), "template %d: definition_id should start with boss_relic_" % relic_val)
		_assert(str(template.get("rules_text", "")).begins_with("Ongoing"), "template %d: rules_text should start with Ongoing" % relic_val)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
