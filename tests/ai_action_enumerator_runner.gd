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
	_test_pending_prophecy_window_enumerates_targeted_action_plays(failures)
	_test_action_variants_include_double_card_and_exalt(failures)
	_test_action_immune_conditional_excludes_target(failures)
	_test_action_immune_status_excludes_target(failures)
	_test_protect_friendly_from_actions_excludes_targets(failures)
	_test_creature_2_power_or_less_excludes_high_power_targets(failures)
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
		"summon_creature:player_2:player_2_lane_choice:lane=field:slot=-1",
		"summon_creature:player_2:player_2_lane_choice:lane=shadow:slot=-1",
	], "Creature summons should enumerate one action per legal lane with packed-array positioning.", failures)


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
		"play_item:player_1:player_1_mobilize_kit:target=player_1_attacker",
		"play_item:player_1:player_1_mobilize_kit:lane=shadow:slot=0",
	], "Item play should enumerate friendly creature targets and Mobilize lane options deterministically.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "activate_support")), [
		"activate_support:player_1:player_1_arsenal:target=player_1_attacker",
		"activate_support:player_1:player_1_arsenal:target=player_2_defender",
		"activate_support:player_1:player_1_arsenal:player=player_1",
		"activate_support:player_1:player_1_arsenal:player=player_2",
	], "Support activation should enumerate board targets and player targets.", failures)
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
		"summon_creature:player_2:player_2_summoned_prophecy:lane=field:slot=-1:response=prophecy",
		"summon_creature:player_2:player_2_summoned_prophecy:lane=shadow:slot=-1:response=prophecy",
	], "Creature Prophecy windows should enumerate one action per legal lane with packed-array positioning.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "decline_prophecy")), [
		"decline_prophecy:player_2:player_2_summoned_prophecy:response=prophecy",
	], "Prophecy windows should include an explicit decline action.", failures)


func _test_pending_prophecy_window_enumerates_targeted_action_plays(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 0})
	var active_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	active_player["hand"] = []
	opponent["hand"] = []
	var prophecy_bolt := ScenarioFixtures.make_card(str(opponent.get("player_id", "")), "prophecy_bolt", {
		"zone": "deck",
		"card_type": "action",
		"cost": 4,
		"action_target_mode": "creature_or_player",
		"rules_tags": [MatchTiming.RULE_TAG_PROPHECY],
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "deal_damage", "target": "event_target", "amount": 4}],
		}],
	})
	ScenarioFixtures.set_deck_cards(opponent, [prophecy_bolt])
	var attacker := ScenarioFixtures.summon_creature(active_player, match_state, "prophecy_breaker", "field", 6, 6, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var attack_result := MatchCombat.resolve_attack(match_state, str(active_player.get("player_id", "")), str(attacker.get("instance_id", "")), {
		"type": MatchCombat.TARGET_TYPE_PLAYER,
		"player_id": str(opponent.get("player_id", "")),
	})
	VerificationAssertions.assert_true(bool(attack_result.get("is_valid", false)), "Prophecy setup attack should resolve successfully.", failures)
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state)
	_assert_surface_consistency(match_state, surface, failures, "prophecy-action-surface")
	VerificationAssertions.assert_equal(str(surface.get("decision_player_id", "")), str(opponent.get("player_id", "")), "Pending Prophecy should switch the legal actor to the responding player.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "play_action")), [
		"play_action:player_2:player_2_prophecy_bolt:target=player_1_prophecy_breaker:response=prophecy",
		"play_action:player_2:player_2_prophecy_bolt:player=player_1:response=prophecy",
		"play_action:player_2:player_2_prophecy_bolt:player=player_2:response=prophecy",
	], "Targeted action Prophecy plays should enumerate one action per valid creature/player target so the AI can pick the best free-cast target.", failures)
	VerificationAssertions.assert_equal(_action_ids(_actions_for_kind(surface, "decline_prophecy")), [
		"decline_prophecy:player_2:player_2_prophecy_bolt:response=prophecy",
	], "Targeted action Prophecy windows should still expose an explicit decline action.", failures)


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


func _test_action_immune_conditional_excludes_target(failures: Array) -> void:
	# Daedric Titan: "While you have another creature in each lane, your opponent can't target it with actions."
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 1})
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Player has another creature in each lane + Daedric Titan in shadow
	ScenarioFixtures.summon_creature(player, match_state, "field_ally", "field", 2, 2)
	ScenarioFixtures.summon_creature(player, match_state, "shadow_ally", "shadow", 1, 1)
	ScenarioFixtures.summon_creature(player, match_state, "titan", "shadow", 6, 4, [], -1, {
		"passive_abilities": [{"type": "action_immune_conditional", "condition": "creature_in_each_lane"}],
	})
	# Opponent has a targeted action in hand
	ScenarioFixtures.add_hand_card(opponent, "javelin", {
		"card_type": "action",
		"cost": 5,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "destroy_creature", "target": "event_target"}],
		}],
	})
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, oid)
	var action_plays := _actions_for_kind(surface, "play_action")
	for action in action_plays:
		var params: Dictionary = action.get("parameters", {})
		var target_id := str(params.get("target_instance_id", ""))
		VerificationAssertions.assert_true(
			target_id != pid + "_titan",
			"Action should not enumerate conditionally immune creature (Daedric Titan) as a valid target.",
			failures
		)
	# Now remove the field creature so the condition is no longer met
	var lanes: Array = match_state.get("lanes", [])
	for lane in lanes:
		var slots: Array = lane.get("player_slots", {}).get(pid, [])
		for i in range(slots.size() - 1, -1, -1):
			if typeof(slots[i]) == TYPE_DICTIONARY and str(slots[i].get("instance_id", "")).ends_with("_field_ally"):
				slots.remove_at(i)
	var surface2 := MatchActionEnumerator.enumerate_legal_actions(match_state, oid)
	var action_plays2 := _actions_for_kind(surface2, "play_action")
	var titan_targetable := false
	for action in action_plays2:
		var params: Dictionary = action.get("parameters", {})
		if str(params.get("target_instance_id", "")) == pid + "_titan":
			titan_targetable = true
			break
	VerificationAssertions.assert_true(
		titan_targetable,
		"Action should enumerate Daedric Titan as a target when creature_in_each_lane condition is NOT met.",
		failures
	)


func _test_action_immune_status_excludes_target(failures: Array) -> void:
	# Creature with action_immune status (e.g. from Ebonthread Cloak) should not be targetable by opponent actions
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 1})
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Player has a creature with action_immune status
	var giant := ScenarioFixtures.summon_creature(player, match_state, "giant", "field", 10, 10)
	EvergreenRules.add_status(giant, "action_immune")
	# Opponent has a targeted action in hand
	ScenarioFixtures.add_hand_card(opponent, "javelin", {
		"card_type": "action",
		"cost": 5,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "destroy_creature", "target": "event_target"}],
		}],
	})
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, oid)
	var action_plays := _actions_for_kind(surface, "play_action")
	for action in action_plays:
		var params: Dictionary = action.get("parameters", {})
		var target_id := str(params.get("target_instance_id", ""))
		VerificationAssertions.assert_true(
			target_id != pid + "_giant",
			"Action should not target creature with action_immune status (e.g. Ebonthread Cloak).",
			failures
		)


func _test_protect_friendly_from_actions_excludes_targets(failures: Array) -> void:
	# Tavyar the Knight: "Your opponent can't target other friendly creatures with actions."
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 1})
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Player has Tavyar (protector) and another creature in the same lane
	ScenarioFixtures.summon_creature(player, match_state, "tavyar", "field", 3, 5, [], -1, {
		"passive_abilities": [{"type": "protect_friendly_from_actions"}],
	})
	ScenarioFixtures.summon_creature(player, match_state, "ally", "field", 5, 5)
	ScenarioFixtures.summon_creature(player, match_state, "shadow_ally", "shadow", 3, 3)
	# Opponent has a targeted action in hand
	ScenarioFixtures.add_hand_card(opponent, "javelin", {
		"card_type": "action",
		"cost": 5,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "destroy_creature", "target": "event_target"}],
		}],
	})
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, oid)
	var action_plays := _actions_for_kind(surface, "play_action")
	var tavyar_targetable := false
	var non_tavyar_targeted := false
	for action in action_plays:
		var params: Dictionary = action.get("parameters", {})
		var target_id := str(params.get("target_instance_id", ""))
		if target_id == pid + "_tavyar":
			tavyar_targetable = true
		elif target_id == pid + "_ally" or target_id == pid + "_shadow_ally":
			non_tavyar_targeted = true
	VerificationAssertions.assert_true(
		tavyar_targetable,
		"Action should still be able to target Tavyar (the protector) itself.",
		failures
	)
	VerificationAssertions.assert_true(
		not non_tavyar_targeted,
		"Action should not target other friendly creatures while Tavyar is on board.",
		failures
	)


func _test_creature_2_power_or_less_excludes_high_power_targets(failures: Array) -> void:
	# Execute (action_target_mode "creature_2_power_or_less") must not enumerate creatures with power > 2 as targets.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 1})
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Player has a high-power creature (8/8) and a low-power creature (2/2)
	ScenarioFixtures.summon_creature(player, match_state, "big", "field", 8, 8)
	ScenarioFixtures.summon_creature(player, match_state, "small", "shadow", 2, 2)
	# Opponent has Execute in hand
	ScenarioFixtures.add_hand_card(opponent, "execute", {
		"card_type": "action",
		"cost": 1,
		"action_target_mode": "creature_2_power_or_less",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "destroy_creature", "target": "event_target"}],
		}],
	})
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, oid)
	var action_plays := _actions_for_kind(surface, "play_action")
	var big_targeted := false
	var small_targeted := false
	for action in action_plays:
		var params: Dictionary = action.get("parameters", {})
		var target_id := str(params.get("target_instance_id", ""))
		if target_id == pid + "_big":
			big_targeted = true
		elif target_id == pid + "_small":
			small_targeted = true
	VerificationAssertions.assert_true(
		not big_targeted,
		"creature_2_power_or_less must not enumerate an 8-power creature as a target.",
		failures
	)
	VerificationAssertions.assert_true(
		small_targeted,
		"creature_2_power_or_less should still enumerate a 2-power creature as a target.",
		failures
	)