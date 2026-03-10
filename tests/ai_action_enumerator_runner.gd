extends SceneTree

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")
const VerificationAssertions = preload("res://tests/support/verification_assertions.gd")


func _initialize() -> void:
	var failures: Array = []
	_test_ring_end_turn_and_summon_slots(failures)
	_test_targeted_actions_and_attack_targets(failures)
	_test_pending_prophecy_window_switches_priority(failures)
	_test_action_variants_include_double_card_and_exalt(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("AI_ACTION_ENUMERATOR_OK")
	quit(0)


func _test_ring_end_turn_and_summon_slots(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var first_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	MatchTurnLoop.end_turn(match_state, str(first_player.get("player_id", "")))
	var player: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	player["support"] = []
	player["deck"] = []
	ScenarioFixtures.summon_creature(player, match_state, "field_anchor", "field", 2, 2, [], 0, {"cost": 0})
	ScenarioFixtures.summon_creature(player, match_state, "shadow_anchor", "shadow", 2, 2, [], 0, {"cost": 0})
	ScenarioFixtures.add_hand_card(player, "lane_choice", {"card_type": "creature", "cost": 1, "power": 3, "health": 3})
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state)
	_assert_surface_consistency(match_state, surface, failures, "turn-surface")
	VerificationAssertions.assert_equal(str(surface.get("decision_player_id", "")), str(player.get("player_id", "")), "Turn surface should enumerate the active player's actions.", failures)
	VerificationAssertions.assert_equal(str(surface.get("timing_window", "")), "action", "Normal turn enumeration should use the action timing window.", failures)
	VerificationAssertions.assert_equal(_actions_for_kind(surface, "use_ring").size(), 1, "Second player turn should expose exactly one Ring action before use.", failures)
	VerificationAssertions.assert_equal(_actions_for_kind(surface, "end_turn").size(), 1, "Turn surface should expose exactly one end-turn action.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "summon_creature")), [
		"summon_creature:player_2:player_2_lane_choice:lane=field:slot=1",
		"summon_creature:player_2:player_2_lane_choice:lane=field:slot=2",
		"summon_creature:player_2:player_2_lane_choice:lane=field:slot=3",
		"summon_creature:player_2:player_2_lane_choice:lane=shadow:slot=1",
		"summon_creature:player_2:player_2_lane_choice:lane=shadow:slot=2",
		"summon_creature:player_2:player_2_lane_choice:lane=shadow:slot=3",
	], "Creature summons should enumerate every legal lane/slot in deterministic order.", failures)


func _test_targeted_actions_and_attack_targets(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	player["support"] = []
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "attacker", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var defender := ScenarioFixtures.summon_creature(opponent, match_state, "defender", "field", 2, 5, [], 0, {"cost": 0})
	player["support"].append(ScenarioFixtures.make_card(str(player.get("player_id", "")), "arsenal", {
		"zone": "support",
		"card_type": "support",
		"cost": 0,
		"activation_cost": 1,
		"support_uses": 1,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [{"op": "grant_keyword", "target": "event_target", "keyword": "guard"}],
		}],
	}))
	ScenarioFixtures.add_hand_card(player, "war_banner", {"card_type": "support", "cost": 0})
	ScenarioFixtures.add_hand_card(player, "dagger", {"card_type": "item", "cost": 0, "equip_power_bonus": 1})
	ScenarioFixtures.add_hand_card(player, "mobilize_kit", {
		"card_type": "item",
		"cost": 0,
		"equip_power_bonus": 1,
		"keywords": [EvergreenRules.KEYWORD_MOBILIZE],
	})
	ScenarioFixtures.add_hand_card(player, "firebolt", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "damage", "target_player": "target_player", "amount": 1}],
		}],
	})
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state)
	_assert_surface_consistency(match_state, surface, failures, "targeted-surface")
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "attack")), [
		"attack:player_1:player_1_attacker:target_type=creature:target=player_2_defender",
		"attack:player_1:player_1_attacker:target_type=player:player=player_2",
	], "Attack enumeration should include both opposing creatures and the opposing player when no Guard prevents face attacks.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "play_support")), [
		"play_support:player_1:player_1_war_banner",
	], "Support play should be exposed as an explicit legal action.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "play_item")), [
		"play_item:player_1:player_1_dagger:target=player_1_attacker",
		"play_item:player_1:player_1_dagger:target=player_2_defender",
		"play_item:player_1:player_1_mobilize_kit:target=player_1_attacker",
		"play_item:player_1:player_1_mobilize_kit:target=player_2_defender",
		"play_item:player_1:player_1_mobilize_kit:lane=shadow:slot=0",
	], "Item play should enumerate creature targets and Mobilize lane options deterministically.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "activate_support")), [
		"activate_support:player_1:player_1_arsenal:target=player_1_attacker",
		"activate_support:player_1:player_1_arsenal:target=player_2_defender",
	], "Support activation should enumerate explicit board targets.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "play_action")), [
		"play_action:player_1:player_1_firebolt:player=player_1",
		"play_action:player_1:player_1_firebolt:player=player_2",
	], "Targeted actions should expose explicit player targets in player-order.", failures)


func _test_pending_prophecy_window_switches_priority(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 0})
	var active_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	active_player["hand"] = []
	opponent["hand"] = []
	var prophecy_creature := ScenarioFixtures.make_card(str(opponent.get("player_id", "")), "summoned_prophecy", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 5,
		"power": 3,
		"health": 4,
		"rules_tags": [MatchTiming.RULE_TAG_PROPHECY],
	})
	ScenarioFixtures.set_deck_cards(opponent, [prophecy_creature])
	var attacker := ScenarioFixtures.summon_creature(active_player, match_state, "prophecy_breaker", "field", 6, 6, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var attack_result := MatchCombat.resolve_attack(match_state, str(active_player.get("player_id", "")), str(attacker.get("instance_id", "")), {
		"type": MatchCombat.TARGET_TYPE_PLAYER,
		"player_id": str(opponent.get("player_id", "")),
	})
	VerificationAssertions.assert_true(bool(attack_result.get("is_valid", false)), "Prophecy setup attack should resolve successfully.", failures)
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state)
	_assert_surface_consistency(match_state, surface, failures, "prophecy-surface")
	VerificationAssertions.assert_equal(str(surface.get("decision_player_id", "")), str(opponent.get("player_id", "")), "Pending Prophecy should switch the legal actor to the responding player.", failures)
	VerificationAssertions.assert_equal(str(surface.get("timing_window", "")), "interrupt", "Pending Prophecy should enumerate inside the interrupt window.", failures)
	VerificationAssertions.assert_equal(_actions_for_kind(surface, "end_turn").size(), 0, "Normal turn actions should be hidden while a Prophecy window is pending.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "summon_creature")), [
		"summon_creature:player_2:player_2_summoned_prophecy:lane=field:slot=0:response=prophecy",
		"summon_creature:player_2:player_2_summoned_prophecy:lane=field:slot=1:response=prophecy",
		"summon_creature:player_2:player_2_summoned_prophecy:lane=field:slot=2:response=prophecy",
		"summon_creature:player_2:player_2_summoned_prophecy:lane=field:slot=3:response=prophecy",
		"summon_creature:player_2:player_2_summoned_prophecy:lane=shadow:slot=0:response=prophecy",
		"summon_creature:player_2:player_2_summoned_prophecy:lane=shadow:slot=1:response=prophecy",
		"summon_creature:player_2:player_2_summoned_prophecy:lane=shadow:slot=2:response=prophecy",
		"summon_creature:player_2:player_2_summoned_prophecy:lane=shadow:slot=3:response=prophecy",
	], "Creature Prophecy windows should enumerate every legal free-play lane/slot.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "decline_prophecy")), [
		"decline_prophecy:player_2:player_2_summoned_prophecy:response=prophecy",
	], "Prophecy windows should include an explicit decline action.", failures)


func _test_action_variants_include_double_card_and_exalt(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	player["support"] = []
	ScenarioFixtures.add_hand_card(player, "double_spell", {
		"card_type": "action",
		"cost": 0,
		"double_card_options": [
			{"id": "spark_half", "card_template": {"definition_id": "spark_half", "name": "Spark", "card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]}},
			{"id": "blast_half", "card_template": {"definition_id": "blast_half", "name": "Blast", "card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 3}]}]}},
		],
	})
	ScenarioFixtures.add_hand_card(player, "exalt_action", {
		"card_type": "action",
		"cost": 2,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "damage", "target_player": "target_player", "amount": 2, "required_source_status": EvergreenRules.STATUS_EXALTED}],
		}],
	})
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state)
	_assert_surface_consistency(match_state, surface, failures, "action-variants")
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "play_action")), [
		"play_action:player_1:player_1_double_spell:player=player_1:double=spark_half",
		"play_action:player_1:player_1_double_spell:player=player_2:double=spark_half",
		"play_action:player_1:player_1_double_spell:player=player_1:double=blast_half",
		"play_action:player_1:player_1_double_spell:player=player_2:double=blast_half",
		"play_action:player_1:player_1_exalt_action:player=player_1",
		"play_action:player_1:player_1_exalt_action:player=player_2",
		"play_action:player_1:player_1_exalt_action:player=player_1:exalt",
		"play_action:player_1:player_1_exalt_action:player=player_2:exalt",
	], "Action play should enumerate current variant choices such as double-card splits and exalt toggles.", failures)


func _assert_surface_consistency(match_state: Dictionary, surface: Dictionary, failures: Array, label: String) -> void:
	var repeated_surface := MatchActionEnumerator.enumerate_legal_actions(match_state, str(surface.get("requested_player_id", "")))
	VerificationAssertions.assert_equal(_surface_signature(surface), _surface_signature(repeated_surface), "%s should be deterministic across repeated enumeration." % label, failures)
	var seen_ids := {}
	for action in surface.get("actions", []):
		var action_id := str(action.get("id", ""))
		VerificationAssertions.assert_true(not seen_ids.has(action_id), "%s should not emit duplicate action ids (`%s`)." % [label, action_id], failures)
		seen_ids[action_id] = true
		VerificationAssertions.assert_true(MatchActionEnumerator.action_is_legal(match_state, action), "%s emitted an illegal action: %s" % [label, action_id], failures)


func _surface_signature(surface: Dictionary) -> Dictionary:
	return {
		"decision_player_id": str(surface.get("decision_player_id", "")),
		"active_player_id": str(surface.get("active_player_id", "")),
		"timing_window": str(surface.get("timing_window", "")),
		"blocked_reason": str(surface.get("blocked_reason", "")),
		"actions": _action_ids(surface.get("actions", [])),
	}


func _actions_for_kind(surface: Dictionary, kind: String) -> Array:
	var actions: Array = []
	for action in surface.get("actions", []):
		if str(action.get("kind", "")) == kind:
			actions.append(action)
	return actions


func _action_ids(actions: Array) -> Array:
	var ids: Array = []
	for action in actions:
		ids.append(str(action.get("id", "")))
	return ids