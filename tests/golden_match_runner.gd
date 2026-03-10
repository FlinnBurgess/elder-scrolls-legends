extends SceneTree

const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")
const VerificationAsserts = preload("res://tests/support/verification_assertions.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run_all_tests()
	_finish()


func _run_all_tests() -> void:
	_test_seeded_rally_golden_replay_and_state()
	_test_prophecy_overflow_golden_snapshot()
	_test_hidden_zone_owner_routed_discard_snapshot()


func _finish() -> void:
	if _failures.is_empty():
		print("GOLDEN_MATCH_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_seeded_rally_golden_replay_and_state() -> void:
	var match_state := ScenarioFixtures.create_started_match({"deck_size": 18, "seed": 211, "first_player_index": 0})
	var active_player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var attacker := ScenarioFixtures.summon_creature(active_player, match_state, "rally_attacker", "field", 3, 3, ["rally"], 0)
	var first_hand_creature := ScenarioFixtures.add_hand_card(active_player, "hand_one", {"card_type": "creature", "power": 2, "health": 2})
	var second_hand_creature := ScenarioFixtures.add_hand_card(active_player, "hand_two", {"card_type": "creature", "power": 4, "health": 4})
	ScenarioFixtures.set_rng_seed(match_state, 211)
	match_state["replay_log"] = []
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var attack_result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {"type": "player", "player_id": opponent["player_id"]})
	VerificationAsserts.assert_true(bool(attack_result.get("is_valid", false)), "Golden rally scenario should resolve successfully.", _failures)
	VerificationAsserts.assert_equal({
		"opponent_health": int(opponent.get("health", 0)),
		"hand_bonuses": [
			{"instance_id": str(first_hand_creature.get("instance_id", "")), "power_bonus": int(first_hand_creature.get("power_bonus", 0)), "health_bonus": int(first_hand_creature.get("health_bonus", 0))},
			{"instance_id": str(second_hand_creature.get("instance_id", "")), "power_bonus": int(second_hand_creature.get("power_bonus", 0)), "health_bonus": int(second_hand_creature.get("health_bonus", 0))},
		],
	}, {
		"opponent_health": 27,
		"hand_bonuses": [
			{"instance_id": "player_1_hand_one", "power_bonus": 1, "health_bonus": 1},
			{"instance_id": "player_1_hand_two", "power_bonus": 0, "health_bonus": 0},
		],
	}, "Golden rally scenario should keep the seeded Rally buff target stable.", _failures)
	VerificationAsserts.assert_equal(ScenarioFixtures.replay_signature(match_state), [
		{"entry_type": "event_processed", "event_type": "attack_declared", "timing_window": "after"},
		{"entry_type": "event_processed", "event_type": "rally_resolved", "timing_window": "after"},
		{"entry_type": "event_processed", "event_type": "damage_resolved", "timing_window": "after"},
		{"entry_type": "event_processed", "event_type": "attack_resolved", "timing_window": "after"},
	], "Golden rally scenario should lock the replay signature for seeded combat output.", _failures)


func _test_prophecy_overflow_golden_snapshot() -> void:
	var match_state := ScenarioFixtures.create_started_match({"deck_size": 20, "seed": 313, "first_player_index": 0})
	var active_player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var prophecy_card := ScenarioFixtures.make_card(opponent["player_id"], "decline_prophecy", {"zone": "deck", "card_type": "action", "rules_tags": ["prophecy"]})
	ScenarioFixtures.set_deck_cards(opponent, [prophecy_card])
	while opponent["hand"].size() < 10:
		ScenarioFixtures.add_hand_card(opponent, "fill_%02d" % opponent["hand"].size(), {"card_type": "action"})
	var attacker := ScenarioFixtures.summon_creature(active_player, match_state, "prophecy_breaker", "field", 6, 6, [], 0)
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var attack_result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {"type": "player", "player_id": opponent["player_id"]})
	VerificationAsserts.assert_true(bool(attack_result.get("is_valid", false)), "Golden Prophecy-overflow setup should resolve successfully.", _failures)
	VerificationAsserts.assert_true(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Rune-break Prophecy draw should leave a pending Prophecy window before decline.", _failures)
	var decline_result := MatchTiming.decline_pending_prophecy(match_state, opponent["player_id"], prophecy_card["instance_id"])
	VerificationAsserts.assert_true(bool(decline_result.get("is_valid", false)), "Golden Prophecy-overflow decline should succeed.", _failures)
	VerificationAsserts.assert_equal({
		"opponent_health": int(opponent.get("health", 0)),
		"rune_thresholds": opponent.get("rune_thresholds", []).duplicate(),
		"hand_size": opponent["hand"].size(),
		"contains_prophecy": ScenarioFixtures.contains_instance(opponent["hand"], prophecy_card["instance_id"]),
		"prophecy_zone": str(prophecy_card.get("zone", "")),
		"pending_prophecy": MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]),
	}, {
		"opponent_health": 24,
		"rune_thresholds": [20, 15, 10, 5],
		"hand_size": 11,
		"contains_prophecy": true,
		"prophecy_zone": "hand",
		"pending_prophecy": false,
	}, "Golden Prophecy-overflow scenario should preserve the hand-overflow exception after decline.", _failures)
	VerificationAsserts.assert_replay_contains_sequence(ScenarioFixtures.replay_signature(match_state), [
		{"entry_type": "event_processed", "event_type": MatchTiming.EVENT_RUNE_BROKEN},
		{"entry_type": "event_processed", "event_type": MatchTiming.EVENT_CARD_DRAWN},
		{"entry_type": "event_processed", "event_type": MatchTiming.EVENT_PROPHECY_WINDOW_OPENED},
		{"entry_type": "event_processed", "event_type": MatchTiming.EVENT_PROPHECY_DECLINED},
	], "Golden Prophecy-overflow scenario should record rune-break and Prophecy replay milestones in order.", _failures)


func _test_hidden_zone_owner_routed_discard_snapshot() -> void:
	var match_state := ScenarioFixtures.create_standard_match({"deck_size": 12, "seed": 419, "first_player_index": 0})
	ScenarioFixtures.set_all_magicka(match_state, 10)
	match_state["phase"] = "action"
	var player_one := ScenarioFixtures.player(match_state, 0)
	var player_two := ScenarioFixtures.player(match_state, 1)
	player_one["hand"] = []
	player_two["hand"] = []
	var stolen_card := ScenarioFixtures.add_hand_card(player_two, "stolen_hidden", {"card_type": "action"})
	var steal_result := MatchMutations.steal_card(match_state, player_one["player_id"], stolen_card["instance_id"])
	VerificationAsserts.assert_true(bool(steal_result.get("is_valid", false)), "Golden hidden-zone steal fixture should succeed.", _failures)
	var discard_result := MatchMutations.discard_from_hand(match_state, player_one["player_id"], 1, {"selection": "front"})
	VerificationAsserts.assert_true(bool(discard_result.get("is_valid", false)), "Golden hidden-zone discard should succeed.", _failures)
	VerificationAsserts.assert_equal({
		"stealer_discard": ScenarioFixtures.card_instance_ids(player_one.get("discard", [])),
		"owner_discard": ScenarioFixtures.card_instance_ids(player_two.get("discard", [])),
		"owner_player_id": str(stolen_card.get("owner_player_id", "")),
		"controller_player_id": str(stolen_card.get("controller_player_id", "")),
		"move_events": discard_result.get("events", []).size(),
	}, {
		"stealer_discard": [],
		"owner_discard": ["player_2_stolen_hidden"],
		"owner_player_id": "player_2",
		"controller_player_id": "player_2",
		"move_events": 1,
	}, "Golden hidden-zone discard scenario should route the card to its owner and reset control.", _failures)