extends SceneTree

const HeuristicMatchPolicy = preload("res://src/ai/heuristic_match_policy.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")
const VerificationAssertions = preload("res://tests/support/verification_assertions.gd")


func _initialize() -> void:
	var failures: Array = []
	_test_tempo_probe(failures)
	_test_defense_probe(failures)
	_test_guard_probe(failures)
	_test_prophecy_play_probe(failures)
	_test_prophecy_decline_probe(failures)
	_test_no_good_play_probe(failures)
	_test_cover_probe(failures)
	_test_readiness_probe(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("AI_BEHAVIOR_PROBE_OK")
	quit(0)


func _test_tempo_probe(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 2, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "curve_two_drop", {"card_type": "creature", "cost": 2, "power": 3, "health": 2})
	ScenarioFixtures.add_hand_card(player, "late_drop", {"card_type": "creature", "cost": 6, "power": 6, "health": 6})
	_assert_probe("tempo", match_state, "summon_creature:player_1:player_1_curve_two_drop:lane=shadow:slot=-1", "tempo_development", failures, "Tempo probe should prefer on-curve shadow-lane development.")


func _test_defense_probe(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	player["health"] = 5
	ScenarioFixtures.summon_creature(player, match_state, "guard_target", "field", 2, 2, [], 0, {"cost": 0})
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
	_assert_probe("defense", match_state, "activate_support:player_1:player_1_ballista:target=player_1_guard_target", "defensive_stabilization", failures, "Defense probe should choose the stabilization line that creates Guard against lethal pressure.")


func _test_guard_probe(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["health"] = 2
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "guard_breaker", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.summon_creature(opponent, match_state, "guard_wall", "field", 1, 1, ["guard"], 0, {"cost": 0})
	_assert_probe("guard", match_state, "attack:player_1:player_1_guard_breaker:target_type=creature:target=player_2_guard_wall", "defensive_stabilization", failures, "Guard probe should keep the required Guard-clearing line stable.")


func _test_prophecy_play_probe(failures: Array) -> void:
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
	_assert_probe("prophecy_play", match_state, "summon_creature:player_2:player_2_guard_prophecy", "prophecy_play", failures, "Prophecy probe should choose a strong stabilizing Prophecy play.")


func _test_prophecy_decline_probe(failures: Array) -> void:
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
	_assert_probe("prophecy_decline", match_state, "decline_prophecy:player_2:player_2_awkward_prophecy:response=prophecy", "prophecy_decline", failures, "Prophecy probe should keep bad Prophecy declines stable.")


func _test_no_good_play_probe(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 1, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "too_expensive", {"card_type": "creature", "cost": 7, "power": 7, "health": 7})
	_assert_probe("no_good_play", match_state, "end_turn:player_1:", "pass_no_profitable_play", failures, "No-good-play probe should end the turn when no worthwhile line exists.")


func _test_cover_probe(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "shadow_raider", "shadow", 3, 3, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.summon_creature(opponent, match_state, "covered_blocker", "shadow", 2, 2, [], 0, {"cost": 0, "cover": true})
	_assert_probe("cover", match_state, "attack:player_1:player_1_shadow_raider:target_type=player:player=player_2", "face_pressure", failures, "Cover probe should keep attacking face when the only opposing lane creature is still protected by Cover.")


func _test_readiness_probe(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	ScenarioFixtures.summon_creature(player, match_state, "sleepy_guard", "field", 3, 4, ["guard"], 0, {"cost": 0})
	_assert_probe("readiness", match_state, "end_turn:player_1:", "pass_no_profitable_play", failures, "Readiness probe should end turn rather than treating an unready creature as an available attack line.")


func _assert_probe(name: String, match_state: Dictionary, expected_prefix: String, expected_label: String, failures: Array, message: String) -> void:
	var choice := HeuristicMatchPolicy.choose_action(match_state)
	var probe := HeuristicMatchPolicy.describe_choice(choice)
	print("AI_PROBE %s :: %s" % [name, probe])
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "%s\n%s" % [message, probe], failures)
	var action: Dictionary = choice.get("chosen_action", {})
	var action_id := str(action.get("id", ""))
	VerificationAssertions.assert_true(action_id.begins_with(expected_prefix), "%s\nExpected prefix: %s\nActual: %s\n%s" % [message, expected_prefix, action_id, probe], failures)
	VerificationAssertions.assert_equal(str(choice.get("behavior_label", "")), expected_label, "%s\nExpected behavior label: %s\n%s" % [message, expected_label, probe], failures)
	VerificationAssertions.assert_true(not str(choice.get("decision_summary", "")).is_empty(), "%s\nProbe summary should not be empty.\n%s" % [message, probe], failures)
	var considered: Array = choice.get("considered_actions", [])
	VerificationAssertions.assert_true(not considered.is_empty() and not str(considered[0].get("summary", "")).is_empty(), "%s\nConsidered-action probe summaries should be present.\n%s" % [message, probe], failures)
	var execution := MatchActionExecutor.clone_and_execute(match_state, action)
	VerificationAssertions.assert_true(bool(execution.get("is_valid", false)), "%s\nChosen action should remain executable after selection: %s\n%s" % [message, action_id, probe], failures)