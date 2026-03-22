extends SceneTree

const HeuristicMatchPolicy = preload("res://src/ai/heuristic_match_policy.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")
const VerificationAssertions = preload("res://tests/support/verification_assertions.gd")


func _initialize() -> void:
	var failures: Array = []
	_test_takes_legal_lethal(failures)
	_test_clears_guard_when_required(failures)
	_test_prefers_favorable_trade_over_face(failures)
	_test_develops_curve_in_shadow_lane(failures)
	_test_uses_ring_when_it_unblocks_curve(failures)
	_test_uses_item_to_set_up_lethal(failures)
	_test_plays_support_when_it_is_the_only_profitable_development(failures)
	_test_uses_support_activation_to_remove_a_threat(failures)
	_test_plays_strong_prophecy(failures)
	_test_declines_bad_prophecy(failures)
	_test_ends_turn_when_only_bad_ring_remains(failures)
	_test_prioritizes_ongoing_effect_creature(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("AI_POLICY_OK")
	quit(0)


func _test_takes_legal_lethal(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["health"] = 4
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "lethal_attacker", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	_assert_policy_pick(match_state, "attack:player_1:player_1_lethal_attacker:target_type=player:player=player_2", failures, "Policy should take lethal when a direct lethal attack is available.")


func _test_clears_guard_when_required(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["health"] = 2
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "guard_breaker", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.summon_creature(opponent, match_state, "guard_wall", "field", 1, 1, ["guard"], 0, {"cost": 0})
	_assert_policy_pick(match_state, "attack:player_1:player_1_guard_breaker:target_type=creature:target=player_2_guard_wall", failures, "Policy should clear required Guard instead of trying to race through it.")


func _test_prefers_favorable_trade_over_face(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "trader", "field", 4, 5, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.summon_creature(opponent, match_state, "face_bait", "field", 4, 4, [], 0, {"cost": 0})
	_assert_policy_pick(match_state, "attack:player_1:player_1_trader:target_type=creature:target=player_2_face_bait", failures, "Policy should prefer a favorable trade over a low-value face attack.")


func _test_develops_curve_in_shadow_lane(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 2, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "curve_two_drop", {"card_type": "creature", "cost": 2, "power": 3, "health": 2})
	ScenarioFixtures.add_hand_card(player, "late_drop", {"card_type": "creature", "cost": 6, "power": 6, "health": 6})
	_assert_policy_pick(match_state, "summon_creature:player_1:player_1_curve_two_drop:lane=shadow:slot=-1", failures, "Policy should spend mana on a curve-appropriate creature and favor protective shadow-lane development.")


func _test_uses_ring_when_it_unblocks_curve(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 1, "first_player_index": 0})
	var first_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	MatchTurnLoop.end_turn(match_state, str(first_player.get("player_id", "")))
	var player: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "ring_curve", {"card_type": "creature", "cost": 3, "power": 4, "health": 4})
	_assert_policy_pick(match_state, "use_ring:player_2:", failures, "Policy should use the Ring when it unlocks a strong immediate follow-up on curve.")


func _test_uses_item_to_set_up_lethal(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["health"] = 3
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "equipped_attacker", "field", 2, 2, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.add_hand_card(player, "power_dagger", {"card_type": "item", "cost": 0, "equip_power_bonus": 1})
	_assert_policy_pick(match_state, "play_item:player_1:player_1_power_dagger:target=player_1_equipped_attacker", failures, "Policy should use an item when shallow lookahead reveals immediate lethal on the next action.")


func _test_plays_support_when_it_is_the_only_profitable_development(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 2, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "totem", {
		"card_type": "support",
		"cost": 2,
		"support_uses": 2,
		"activation_cost": 1,
	})
	_assert_policy_pick(match_state, "play_support:player_1:player_1_totem", failures, "Policy should play a support when it is the only meaningful development available.")


func _test_uses_support_activation_to_remove_a_threat(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	player["health"] = 5
	var guard_target := ScenarioFixtures.summon_creature(player, match_state, "guard_target", "field", 2, 2, [], 0, {"cost": 0})
	player["support"] = [ScenarioFixtures.make_card(str(player.get("player_id", "")), "ballista", {
		"zone": "support",
		"card_type": "support",
		"cost": 0,
		"activation_cost": 1,
		"support_uses": 1,
		"remaining_support_uses": 1,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [{"op": "grant_keyword", "target": "event_target", "keyword_id": "guard"}],
		}],
	})]
	ScenarioFixtures.summon_creature(opponent, match_state, "activation_target", "field", 6, 6, [], 0, {"cost": 0})
	_assert_policy_pick(match_state, "activate_support:player_1:player_1_ballista:target=player_1_guard_target", failures, "Policy should use a support activation when it creates the Guard needed to prevent an immediate loss.")


func _test_plays_strong_prophecy(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var active_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var responding_player: Dictionary = ScenarioFixtures.player(match_state, 1)
	active_player["hand"] = []
	responding_player["hand"] = []
	responding_player["health"] = 8
	ScenarioFixtures.summon_creature(active_player, match_state, "enemy_target", "field", 5, 5, [], 0, {"cost": 0})
	var prophecy := ScenarioFixtures.make_card(str(responding_player.get("player_id", "")), "guard_prophecy", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 4,
		"power": 3,
		"health": 5,
		"keywords": ["guard"],
		"rules_tags": [MatchTiming.RULE_TAG_PROPHECY],
	})
	ScenarioFixtures.set_deck_cards(responding_player, [prophecy])
	MatchTiming.apply_player_damage(match_state, str(responding_player.get("player_id", "")), 6, {"reason": "test_rune_break", "source_controller_player_id": str(active_player.get("player_id", ""))})
	_assert_policy_pick(match_state, "summon_creature:player_2:player_2_guard_prophecy", failures, "Policy should play a strong Prophecy creature when the free Guard body meaningfully stabilizes the board.")


func _test_declines_bad_prophecy(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var active_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var responding_player: Dictionary = ScenarioFixtures.player(match_state, 1)
	active_player["hand"] = []
	responding_player["hand"] = []
	ScenarioFixtures.summon_creature(responding_player, match_state, "fragile_friend", "field", 1, 1, [], 0, {"cost": 0})
	var prophecy := ScenarioFixtures.make_card(str(responding_player.get("player_id", "")), "awkward_prophecy", {
		"zone": "deck",
		"card_type": "action",
		"cost": 4,
		"rules_tags": [MatchTiming.RULE_TAG_PROPHECY],
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "damage", "target": "event_target", "amount": 2}],
		}],
	})
	ScenarioFixtures.set_deck_cards(responding_player, [prophecy])
	MatchTiming.apply_player_damage(match_state, str(responding_player.get("player_id", "")), 6, {"reason": "test_rune_break", "source_controller_player_id": str(active_player.get("player_id", ""))})
	_assert_policy_pick(match_state, "decline_prophecy:player_2:player_2_awkward_prophecy:response=prophecy", failures, "Policy should decline a Prophecy that only produces a bad self-damaging board tradeoff.")


func _test_ends_turn_when_only_bad_ring_remains(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 1, "first_player_index": 0})
	var first_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	MatchTurnLoop.end_turn(match_state, str(first_player.get("player_id", "")))
	var player: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "too_expensive", {"card_type": "creature", "cost": 7, "power": 7, "health": 7})
	_assert_policy_pick(match_state, "end_turn:player_2:", failures, "Policy should end the turn when Ring usage does not unlock a worthwhile follow-up.")


func _test_prioritizes_ongoing_effect_creature(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	# A 4/5 attacker that can kill either target.
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "threat_hunter", "field", 4, 5, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	# Vanilla 3/3 — decent stats but no ongoing threat.
	ScenarioFixtures.summon_creature(opponent, match_state, "vanilla_brute", "field", 3, 3, [], 0, {"cost": 0})
	# 0/4 with start_of_turn deal 4 damage — a Trebuchet-style ongoing threat.
	ScenarioFixtures.summon_creature(opponent, match_state, "siege_engine", "field", 0, 4, [], 1, {
		"cost": 4,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_START_OF_TURN,
			"required_zone": "lane",
			"effects": [{"op": "deal_damage", "target": "random_enemy", "amount": 4}],
		}],
	})
	_assert_policy_pick(match_state, "attack:player_1:player_1_threat_hunter:target_type=creature:target=player_2_siege_engine", failures, "Policy should prioritize a 0-power creature with a dangerous ongoing effect over a vanilla creature with higher stats.")


func _assert_policy_pick(match_state: Dictionary, expected_prefix: String, failures: Array, message: String) -> void:
	var choice := HeuristicMatchPolicy.choose_action(match_state)
	var probe := HeuristicMatchPolicy.describe_choice(choice)
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "%s\nPolicy returned an invalid choice.\n%s" % [message, probe], failures)
	var action: Dictionary = choice.get("chosen_action", {})
	var action_id := str(action.get("id", ""))
	VerificationAssertions.assert_true(action_id.begins_with(expected_prefix), "%s\nExpected prefix: %s\nActual: %s\n%s" % [message, expected_prefix, action_id, probe], failures)
	var execution := MatchActionExecutor.clone_and_execute(match_state, action)
	VerificationAssertions.assert_true(bool(execution.get("is_valid", false)), "%s\nChosen action should remain executable after selection: %s\n%s" % [message, action_id, probe], failures)
