extends SceneTree

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return
	print("EXTENDED_MECHANICS_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_assemble_pack() and
		_test_assemble_choose_one_targets() and
		_test_assemble_choose_two() and
		_test_assemble_choose_two_grants_triggers() and
		_test_assemble_granted_trigger_stacking() and
		_test_yagrums_workshop_doubles_neutral_summon() and
		_test_yagrums_workshop_doubles_assemble() and
		_test_yagrums_workshop_clears_at_end_of_turn() and
		_test_beast_form_pack() and
		_test_veteran_hook() and
		_test_action_pack_matrix() and
		_test_empower_and_expertise_hooks() and
		_test_empower_deal_damage() and
		_test_empower_cost_reduction() and
		_test_empower_destroy_creature() and
		_test_empower_add_support_uses() and
		_test_empower_summon_stat_bonus() and
		_test_empower_resets_at_end_of_turn() and
		_test_empower_summon_random_cost_scaling() and
		_test_empower_banish_per_attribute() and
		_test_empower_permanent_across_turns() and
		_test_invade_and_shout_pack() and
		_test_invade_gate_level_capped_at_five() and
		_test_choose_one_repeat() and
		_test_invade_gate_ward_target() and
		_test_summon_daedra_by_gate_level() and
		_test_treasure_hunt_and_consume_pack() and
		_test_treasure_hunt_count_based() and
		_test_wax_and_wane_pack() and
		_test_dual_wax_wane() and
		_test_wax_creature_turn_trigger() and
		_test_aldora_the_daring_pack() and
		_test_mistveil_warden_pack() and
		_test_murkwater_guide_pack() and
		_test_ratway_prospector_pack() and
		_test_ruthless_freebooter_pack() and
		_test_treasure_map_pack() and
		_test_choose_cost_lock_blocks_opponent_summon() and
		_test_choose_cost_lock_allows_different_cost()
	)


func _test_assemble_pack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var assemble_creature := ScenarioFixtures.add_hand_card(player, "assemble_leader", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["factotum"],
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "lane",
			"effects": [{"op": "assemble", "choices": [{"power": 1, "health": 1}]}],
		}],
	})
	var hand_factotum := ScenarioFixtures.add_hand_card(player, "hand_factotum", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["factotum"],
	})
	var deck_factotum := ScenarioFixtures.make_card(str(player.get("player_id", "")), "deck_factotum", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["factotum"],
	})
	player["deck"].append(deck_factotum)
	var summon_result := LaneRules.summon_from_hand(match_state, str(player.get("player_id", "")), str(assemble_creature.get("instance_id", "")), "field", {"assemble_choice": 0})
	return (
		_assert(bool(summon_result.get("is_valid", false)), "Assemble creature should be playable through the normal summon path.") and
		_assert(EvergreenRules.get_power(assemble_creature) == 2 and EvergreenRules.get_health(assemble_creature) == 2, "Assemble should buff the played Factotum.") and
		_assert(EvergreenRules.get_power(hand_factotum) == 2 and EvergreenRules.get_health(hand_factotum) == 2, "Assemble should buff Factotums in hand.") and
		_assert(EvergreenRules.get_power(deck_factotum) == 2 and EvergreenRules.get_health(deck_factotum) == 2, "Assemble should buff Factotums in deck.")
	)


func _test_assemble_choose_one_targets() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Assemble creature with choose_one using assemble_targets
	var assemble_creature := ScenarioFixtures.add_hand_card(player, "assemble_chooser", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 2,
		"subtypes": ["Factotum"],
		"triggered_abilities": [{
			"family": "summon",
			"effects": [{"op": "choose_one", "choices": [
				{"label": "+2/+0", "effects": [{"op": "modify_stats", "target": "assemble_targets", "power": 2, "health": 0}]},
				{"label": "Lethal", "effects": [{"op": "grant_keyword", "target": "assemble_targets", "keyword_id": "lethal"}]},
			]}],
		}],
	})
	var hand_factotum := ScenarioFixtures.add_hand_card(player, "hand_facto", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["Factotum"],
	})
	var deck_factotum := ScenarioFixtures.make_card(pid, "deck_facto", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["Factotum"],
	})
	player["deck"].append(deck_factotum)
	# Also place a non-Factotum in hand — should NOT be buffed
	var non_factotum := ScenarioFixtures.add_hand_card(player, "non_facto", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["Nord"],
	})
	# Place a Factotum already in lane — should NOT be buffed
	var lane_factotum := ScenarioFixtures.summon_creature(player, match_state, "lane_facto", "field", 1, 1, [], -1, {
		"subtypes": ["Factotum"],
	})
	LaneRules.summon_from_hand(match_state, pid, str(assemble_creature.get("instance_id", "")), "field", {})
	# Should now have a pending choice
	var choice := MatchTiming.get_pending_player_choice(match_state, pid)
	if choice.is_empty():
		return _assert(false, "Assemble choose_one should produce a pending player choice.")
	# Choose option 0: +2/+0
	MatchTiming.resolve_pending_player_choice(match_state, pid, 0)
	return (
		_assert(EvergreenRules.get_power(assemble_creature) == 3, "Assemble choose_one should buff the played creature (+2 power).") and
		_assert(EvergreenRules.get_power(hand_factotum) == 3, "Assemble choose_one should buff Factotums in hand.") and
		_assert(EvergreenRules.get_power(deck_factotum) == 3, "Assemble choose_one should buff Factotums in deck.") and
		_assert(EvergreenRules.get_power(non_factotum) == 1, "Assemble choose_one should NOT buff non-Factotums in hand.") and
		_assert(EvergreenRules.get_power(lane_factotum) == 1, "Assemble choose_one should NOT buff Factotums already in lane.")
	)


func _test_assemble_choose_two() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Assembled Titan: choose_two with 4 options, player picks 2
	var titan := ScenarioFixtures.add_hand_card(player, "titan", {
		"card_type": "creature",
		"cost": 0,
		"power": 4,
		"health": 4,
		"subtypes": ["Factotum"],
		"triggered_abilities": [{
			"family": "summon",
			"effects": [{"op": "choose_two", "choices": [
				{"label": "+2/+0", "effects": [{"op": "modify_stats", "target": "assemble_targets", "power": 2, "health": 0}]},
				{"label": "+0/+2", "effects": [{"op": "modify_stats", "target": "assemble_targets", "power": 0, "health": 2}]},
				{"label": "Deal 2 damage", "effects": [{"op": "damage", "target_player": "opponent", "amount": 2}, {"op": "grant_triggered_ability", "target": "assemble_targets_except_self", "ability": {"family": "summon", "effects": [{"op": "damage", "target_player": "opponent", "amount": 2}]}}]},
				{"label": "Gain 2 health", "effects": [{"op": "heal", "target_player": "controller", "amount": 2}, {"op": "grant_triggered_ability", "target": "assemble_targets_except_self", "ability": {"family": "summon", "effects": [{"op": "heal", "target_player": "controller", "amount": 2}]}}]},
			]}],
		}],
	})
	var hand_factotum := ScenarioFixtures.add_hand_card(player, "hand_facto2", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["Factotum"],
	})
	LaneRules.summon_from_hand(match_state, pid, str(titan.get("instance_id", "")), "field", {})
	# First choice should be pending
	var choice1 := MatchTiming.get_pending_player_choice(match_state, pid)
	if choice1.is_empty():
		return _assert(false, "Choose two should produce first pending choice.")
	if choice1.get("options", []).size() != 4:
		return _assert(false, "First choice should have 4 options, got %d." % choice1.get("options", []).size())
	# Choose option 0: +2/+0
	MatchTiming.resolve_pending_player_choice(match_state, pid, 0)
	# Second choice should now be pending with 3 remaining options
	var choice2 := MatchTiming.get_pending_player_choice(match_state, pid)
	if choice2.is_empty():
		return _assert(false, "Choose two should produce second pending choice after first resolution.")
	if choice2.get("options", []).size() != 3:
		return _assert(false, "Second choice should have 3 options (chosen removed), got %d." % choice2.get("options", []).size())
	# Choose option 0 of remaining (which is +0/+2, since +2/+0 was removed)
	MatchTiming.resolve_pending_player_choice(match_state, pid, 0)
	# Titan should have +2/+0 and +0/+2 = net +2/+2
	return (
		_assert(EvergreenRules.get_power(titan) == 6, "Titan should be 4+2=6 power after both choices.") and
		_assert(EvergreenRules.get_health(titan) == 6, "Titan should be 4+2=6 health after both choices.") and
		_assert(EvergreenRules.get_power(hand_factotum) == 3, "Hand Factotum should get +2 power from assemble_targets.") and
		_assert(EvergreenRules.get_health(hand_factotum) == 3, "Hand Factotum should get +2 health from assemble_targets.") and
		_assert(not MatchTiming.has_pending_player_choice(match_state, pid), "No more pending choices after both resolved.")
	)


func _test_assemble_choose_two_grants_triggers() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	# Titan with damage/heal choices that grant triggered abilities + text
	var titan := ScenarioFixtures.add_hand_card(player, "titan_trig", {
		"card_type": "creature",
		"cost": 0,
		"power": 4,
		"health": 4,
		"subtypes": ["Factotum"],
		"triggered_abilities": [{
			"family": "summon",
			"effects": [{"op": "choose_two", "choices": [
				{"label": "+2/+0", "effects": [{"op": "modify_stats", "target": "assemble_targets", "power": 2, "health": 0}]},
				{"label": "+0/+2", "effects": [{"op": "modify_stats", "target": "assemble_targets", "power": 0, "health": 2}]},
				{"label": "Deal 2 damage", "effects": [{"op": "damage", "target_player": "opponent", "amount": 2}, {"op": "grant_triggered_ability", "target": "assemble_targets_except_self", "assemble_label": "assemble_damage", "text_template": "Summon: Deal {amount} damage to your opponent.", "ability": {"family": "summon", "effects": [{"op": "damage", "target_player": "opponent", "amount": 2}]}}]},
				{"label": "Gain 2 health", "effects": [{"op": "heal", "target_player": "controller", "amount": 2}, {"op": "grant_triggered_ability", "target": "assemble_targets_except_self", "assemble_label": "assemble_heal", "text_template": "Summon: You gain {amount} health.", "ability": {"family": "summon", "effects": [{"op": "heal", "target_player": "controller", "amount": 2}]}}]},
			]}],
		}],
	})
	var hand_factotum := ScenarioFixtures.add_hand_card(player, "hand_facto3", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["Factotum"],
	})
	var opponent_health_before := int(opponent.get("health", 30))
	LaneRules.summon_from_hand(match_state, pid, str(titan.get("instance_id", "")), "field", {})
	# Choose "Deal 2 damage" (index 2) first
	MatchTiming.resolve_pending_player_choice(match_state, pid, 2)
	# Choose "Gain 2 health" (now index 2 in the remaining 3 options: +2/+0, +0/+2, Gain 2 health)
	MatchTiming.resolve_pending_player_choice(match_state, pid, 2)
	# Immediate effects: opponent takes 2 damage, player gains 2 health
	var opponent_health_after := int(opponent.get("health", 30))
	var player_health_after := int(player.get("health", 30))
	# Hand Factotum should have gained summon triggers for both effects
	var facto_abilities: Array = hand_factotum.get("triggered_abilities", [])
	var summon_count := 0
	for ability in facto_abilities:
		if typeof(ability) == TYPE_DICTIONARY and str(ability.get("family", "")) == "summon":
			summon_count += 1
	# Rules text should include both assembled effects
	var facto_rules := str(hand_factotum.get("rules_text", ""))
	return (
		_assert(opponent_health_after == opponent_health_before - 2, "Opponent should take 2 damage immediately.") and
		_assert(player_health_after == 32, "Player should gain 2 health immediately (30 + 2).") and
		_assert(summon_count == 2, "Hand Factotum should gain 2 summon triggers from assemble, got %d." % summon_count) and
		_assert("Deal 2 damage" in facto_rules, "Hand Factotum rules_text should include damage text, got: %s" % facto_rules) and
		_assert("gain 2 health" in facto_rules, "Hand Factotum rules_text should include heal text, got: %s" % facto_rules)
	)


func _test_assemble_granted_trigger_stacking() -> bool:
	# When the same assemble effect is granted twice (e.g. via Yagrum's Workshop),
	# the amount should stack (2→4) and the text should update accordingly.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var hand_factotum := ScenarioFixtures.add_hand_card(player, "stack_facto", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["Factotum"],
		"rules_text": "Assemble: +0/+2 or Guard.",
	})
	# Simulate granting the damage trigger twice (as if Yagrum's Workshop doubled it)
	var grant_effect := {
		"op": "grant_triggered_ability",
		"target": "assemble_targets_except_self",
		"assemble_label": "assemble_damage",
		"text_template": "Summon: Deal {amount} damage to your opponent.",
		"ability": {"family": "summon", "effects": [{"op": "damage", "target_player": "opponent", "amount": 2}]},
	}
	# Build a fake trigger context pointing at some other source
	var fake_trigger := {
		"source_instance_id": "fake_source",
		"controller_player_id": pid,
		"descriptor": {"effects": [grant_effect]},
	}
	MatchTiming._apply_effects(match_state, fake_trigger, {}, {})
	# First grant: should have 1 summon trigger with amount 2
	var abilities: Array = hand_factotum.get("triggered_abilities", [])
	var first_amount := 0
	for ab in abilities:
		if typeof(ab) == TYPE_DICTIONARY and str(ab.get("_assemble_label", "")) == "assemble_damage":
			for eff in ab.get("effects", []):
				if typeof(eff) == TYPE_DICTIONARY:
					first_amount = int(eff.get("amount", 0))
	var rules_after_first := str(hand_factotum.get("rules_text", ""))
	# Grant again — should stack to amount 4
	MatchTiming._apply_effects(match_state, fake_trigger, {}, {})
	abilities = hand_factotum.get("triggered_abilities", [])
	var stacked_amount := 0
	var summon_trigger_count := 0
	for ab in abilities:
		if typeof(ab) == TYPE_DICTIONARY and str(ab.get("_assemble_label", "")) == "assemble_damage":
			summon_trigger_count += 1
			for eff in ab.get("effects", []):
				if typeof(eff) == TYPE_DICTIONARY:
					stacked_amount = int(eff.get("amount", 0))
	var rules_after_second := str(hand_factotum.get("rules_text", ""))
	return (
		_assert(first_amount == 2, "First grant should set amount to 2, got %d." % first_amount) and
		_assert("Deal 2 damage" in rules_after_first, "After first grant, text should say 'Deal 2 damage', got: %s" % rules_after_first) and
		_assert(stacked_amount == 4, "Second grant should stack amount to 4, got %d." % stacked_amount) and
		_assert(summon_trigger_count == 1, "Should have 1 stacked trigger, not 2 separate ones, got %d." % summon_trigger_count) and
		_assert("Deal 4 damage" in rules_after_second, "After second grant, text should say 'Deal 4 damage', got: %s" % rules_after_second)
	)


func _test_yagrums_workshop_doubles_neutral_summon() -> bool:
	# Full integration: place Workshop support, activate it, then summon a neutral creature
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	# Place Workshop in support zone
	var workshop := ScenarioFixtures.make_card(pid, "workshop", {
		"card_type": "support",
		"definition_id": "test_workshop",
		"support_uses": 3,
		"remaining_support_uses": 3,
		"triggered_abilities": [{"family": "activate", "effects": [{"op": "grant_double_summon_this_turn"}]}],
	})
	workshop["zone"] = "support"
	player["support"].append(workshop)
	# Activate the workshop
	var activate_result := PersistentCardRules.activate_support(match_state, pid, str(workshop.get("instance_id", "")))
	if not bool(activate_result.get("is_valid", false)):
		return _assert(false, "Workshop activation should succeed, got: %s" % str(activate_result.get("errors", [])))
	# Verify the flag was set
	if not bool(player.get("_double_summon_this_turn", false)):
		return _assert(false, "Player should have _double_summon_this_turn after activating Workshop.")
	var opponent_health_before := int(opponent.get("health", 30))
	# Neutral creature that deals 2 damage on summon
	var neutral_creature := ScenarioFixtures.add_hand_card(player, "neutral_summoner", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"attributes": [],
		"triggered_abilities": [{
			"family": "summon",
			"effects": [{"op": "damage", "target_player": "opponent", "amount": 2}],
		}],
	})
	LaneRules.summon_from_hand(match_state, pid, str(neutral_creature.get("instance_id", "")), "field", {})
	var opponent_health_after := int(opponent.get("health", 30))
	# Should have dealt 2 damage twice = 4 total
	return _assert(opponent_health_after == opponent_health_before - 4, "Neutral summon should fire twice with Workshop, opponent lost %d (expected 4)." % (opponent_health_before - opponent_health_after))


func _test_yagrums_workshop_doubles_assemble() -> bool:
	# An assemble choose_one should produce two separate choice prompts
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	player["_double_summon_this_turn"] = true
	var sentry := ScenarioFixtures.add_hand_card(player, "sentry_ws", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"attributes": [],
		"subtypes": ["Factotum"],
		"triggered_abilities": [{
			"family": "summon",
			"effects": [{"op": "choose_one", "choices": [
				{"label": "+2/+0", "effects": [{"op": "modify_stats", "target": "assemble_targets", "power": 2, "health": 0}]},
				{"label": "Guard", "effects": [{"op": "grant_keyword", "target": "assemble_targets", "keyword_id": "guard"}]},
			]}],
		}],
	})
	LaneRules.summon_from_hand(match_state, pid, str(sentry.get("instance_id", "")), "field", {})
	# First choice from first trigger
	var choice1 := MatchTiming.get_pending_player_choice(match_state, pid)
	if choice1.is_empty():
		return _assert(false, "Should have first assemble choice pending.")
	MatchTiming.resolve_pending_player_choice(match_state, pid, 0)  # +2/+0
	# Second choice from doubled trigger
	var choice2 := MatchTiming.get_pending_player_choice(match_state, pid)
	if choice2.is_empty():
		return _assert(false, "Should have second assemble choice pending (doubled by Workshop).")
	MatchTiming.resolve_pending_player_choice(match_state, pid, 0)  # +2/+0 again
	# Sentry should have +4/+0 total (doubled)
	return (
		_assert(EvergreenRules.get_power(sentry) == 5, "Sentry should be 1+2+2=5 power after doubled assemble, got %d." % EvergreenRules.get_power(sentry)) and
		_assert(not MatchTiming.has_pending_player_choice(match_state, pid), "No more pending choices.")
	)


func _test_yagrums_workshop_clears_at_end_of_turn() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["_double_summon_this_turn"] = true
	ExtendedMechanicPacks.reset_turn_state(player)
	return _assert(not bool(player.get("_double_summon_this_turn", false)), "Double summon flag should be cleared after turn reset.")


func _test_beast_form_pack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var beast := ScenarioFixtures.summon_creature(player, match_state, "beast_former", "field", 2, 2, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"match_role": "opponent_player",
			"required_zone": "lane",
			"effects": [{
				"op": "transform",
				"target": "self",
				"card_template": {"definition_id": "werewolf_form", "name": "Werewolf Form", "card_type": "creature", "power": 4, "health": 4},
			}],
		}],
	})
	var damage_result := MatchTiming.apply_player_damage(match_state, str(opponent.get("player_id", "")), 6, {
		"source_instance_id": str(beast.get("instance_id", "")),
		"source_controller_player_id": str(player.get("player_id", "")),
	})
	MatchTiming.publish_events(match_state, damage_result.get("events", []))
	return (
		_assert(str(beast.get("definition_id", "")) == "werewolf_form", "Breaking an enemy rune should transform Beast Form creatures.") and
		_assert(EvergreenRules.get_power(beast) == 4 and EvergreenRules.get_health(beast) == 4, "Transformed Beast Form creature should take on the werewolf template stats.")
	)


func _test_veteran_hook() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var veteran := ScenarioFixtures.summon_creature(player, match_state, "veteran_scout", "field", 3, 4, [EvergreenRules.KEYWORD_CHARGE], -1, {
		"triggered_abilities": [{
			"event_type": "attack_resolved",
			"match_role": "source",
			"required_zone": "lane",
			"require_attacker_survived": true,
			"once_per_instance": true,
			"effects": [{"op": "modify_stats", "target": "self", "power": 2, "health": 0}],
		}],
	})
	var first_target := _summon_generated_creature(match_state, str(opponent.get("player_id", "")), "first_dummy", "field", 1, 1)
	var first_attack := MatchCombat.resolve_attack(match_state, str(player.get("player_id", "")), str(veteran.get("instance_id", "")), {"type": "creature", "instance_id": str(first_target.get("instance_id", ""))})
	if not (
		_assert(bool(first_attack.get("is_valid", false)), "Veteran fixture attack should resolve: %s" % [str(first_attack.get("errors", []))]) and
		_assert(EvergreenRules.get_power(veteran) == 5, "Veteran hook should fire after the creature survives its first attack.")
	):
		return false
	MatchTurnLoop.end_turn(match_state, str(player.get("player_id", "")))
	MatchTurnLoop.end_turn(match_state, str(opponent.get("player_id", "")))
	var second_target := _summon_generated_creature(match_state, str(opponent.get("player_id", "")), "second_dummy", "field", 1, 1)
	var second_attack := MatchCombat.resolve_attack(match_state, str(player.get("player_id", "")), str(veteran.get("instance_id", "")), {"type": "creature", "instance_id": str(second_target.get("instance_id", ""))})
	return (
		_assert(bool(second_attack.get("is_valid", false)), "Veteran should still be able to attack on later turns.") and
		_assert(EvergreenRules.get_power(veteran) == 5, "Veteran hook should remain once-per-instance after the first successful attack.")
	)


func _test_action_pack_matrix() -> bool:
	return (
		_test_double_card_choice() and
		_test_plot_hook() and
		_test_exalt_action_bonus() and
		_test_betray_replay() and
		_test_mushroom_tower_grants_betray() and
		_test_betray_no_creatures_skips() and
		_test_betray_targeted_skip_no_replay_target()
	)


func _test_double_card_choice() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var double_card := ScenarioFixtures.add_hand_card(player, "double_spell", {
		"card_type": "action",
		"cost": 0,
		"double_card_options": [
			{"id": "spark_half", "card_template": {"definition_id": "spark_half", "name": "Spark", "card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]}},
			{"id": "blast_half", "card_template": {"definition_id": "blast_half", "name": "Blast", "card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 3}]}]}},
		],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(double_card.get("instance_id", "")), {"double_card_choice": "blast_half", "target_player_id": str(opponent.get("player_id", ""))})
	return (
		_assert(bool(play_result.get("is_valid", false)), "Double card should resolve through the generic action play path.") and
		_assert(str(double_card.get("definition_id", "")) == "blast_half", "Double card should adopt the chosen half before resolving.") and
		_assert(int(opponent.get("health", 0)) == 27, "Chosen double-card half should drive the resolved effect payload (health=%d)." % int(opponent.get("health", 0)))
	)


func _test_plot_hook() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var filler := ScenarioFixtures.add_hand_card(player, "filler_action", {"card_type": "action", "cost": 0})
	var plot_card := ScenarioFixtures.add_hand_card(player, "plot_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"event_type": MatchTiming.EVENT_CARD_PLAYED,
			"match_role": "source",
			"required_zone": "discard",
			"min_cards_played_this_turn": 2,
			"effects": [{"op": "damage", "target_player": "target_player", "amount": 2}],
		}],
	})
	var filler_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(filler.get("instance_id", "")))
	var plot_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(plot_card.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	return (
		_assert(bool(filler_play.get("is_valid", false)) and bool(plot_play.get("is_valid", false)), "Plot fixture actions should be playable.") and
		_assert(int(opponent.get("health", 0)) == 28, "Plot should trigger only when the card is the second play of the turn.")
	)


func _test_exalt_action_bonus() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var exalt_card := ScenarioFixtures.add_hand_card(player, "exalt_action", {
		"card_type": "action",
		"cost": 2,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "damage", "target_player": "target_player", "amount": 2, "required_source_status": EvergreenRules.STATUS_EXALTED}],
		}],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(exalt_card.get("instance_id", "")), {"exalt": true, "target_player_id": str(opponent.get("player_id", ""))})
	return (
		_assert(bool(play_result.get("is_valid", false)), "Exalt action should be playable through the generic action path.") and
		_assert(int(player.get("current_magicka", 0)) == 7, "Exalt should charge one extra magicka on top of the base action cost.") and
		_assert(int(opponent.get("health", 0)) == 28, "Exalted action should unlock its exalt-gated bonus effect.")
	)


func _test_betray_replay() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var fodder := ScenarioFixtures.summon_creature(player, match_state, "betray_fodder", "field", 1, 1)
	var betray_card := ScenarioFixtures.add_hand_card(player, "betray_action", {
		"card_type": "action",
		"cost": 0,
		"keywords": ["betray"],
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [
				{"op": "damage", "target_player": "target_player", "amount": 1},
			],
		}],
	})
	var player_id := str(player.get("player_id", ""))
	var opponent_id := str(opponent.get("player_id", ""))
	# Play the action normally (first resolution)
	var play_result := MatchTiming.play_action_from_hand(match_state, player_id, str(betray_card.get("instance_id", "")), {
		"target_player_id": opponent_id,
	})
	if not _assert(bool(play_result.get("is_valid", false)), "Betray action should be playable."):
		return false
	if not _assert(int(opponent.get("health", 0)) == 29, "First betray play should deal 1 damage (health=%d)." % int(opponent.get("health", 0))):
		return false
	# Verify betray eligibility
	if not _assert(ExtendedMechanicPacks.action_has_betray(match_state, player_id, betray_card), "Card with betray keyword should be detected as betray."):
		return false
	# Execute the betray replay as a separate step
	var replay_result := MatchTiming.execute_betray_replay(match_state, player_id, str(betray_card.get("instance_id", "")), str(fodder.get("instance_id", "")), {
		"target_player_id": opponent_id,
	})
	return (
		_assert(bool(replay_result.get("is_valid", false)), "Betray replay should succeed.") and
		_assert(int(opponent.get("health", 0)) == 28, "Betray replay should deal 1 more damage (health=%d)." % int(opponent.get("health", 0))) and
		_assert(_contains_instance(player.get("discard", []), str(fodder.get("instance_id", ""))), "Betray should sacrifice the chosen creature to discard.")
	)


func _test_mushroom_tower_grants_betray() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Create a non-betray action
	var action_card := ScenarioFixtures.make_card(player_id, "plain_action", {
		"card_type": "action",
		"cost": 0,
	})
	# Without Mushroom Tower — should not have betray
	if not _assert(not ExtendedMechanicPacks.action_has_betray(match_state, player_id, action_card), "Action without betray keyword should not have betray."):
		return false
	# Place Mushroom Tower in support zone
	var tower := ScenarioFixtures.make_card(player_id, "mushroom_tower", {
		"card_type": "support",
		"definition_id": "hom_end_mushroom_tower",
		"support_uses": 0,
	})
	tower["zone"] = "support"
	player["support"].append(tower)
	# With Mushroom Tower — should have betray
	return _assert(ExtendedMechanicPacks.action_has_betray(match_state, player_id, action_card), "Mushroom Tower should grant betray to all actions.")


func _test_betray_no_creatures_skips() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var candidates := ExtendedMechanicPacks.get_betray_sacrifice_candidates(match_state, player_id)
	return _assert(candidates.is_empty(), "Should have no sacrifice candidates when no friendly creatures in lanes.")


func _test_betray_targeted_skip_no_replay_target() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon a single friendly creature
	var lone_creature := ScenarioFixtures.summon_creature(player, match_state, "lone_creature", "field", 2, 2)
	# Create a targeted action that targets friendly creatures
	var targeted_action := ScenarioFixtures.make_card(player_id, "friendly_target_action", {
		"card_type": "action",
		"cost": 0,
		"keywords": ["betray"],
		"action_target_mode": "friendly_creature",
	})
	# Sacrificing the only creature leaves no valid replay target
	var has_target := ExtendedMechanicPacks.betray_replay_has_valid_target(match_state, player_id, targeted_action, str(lone_creature.get("instance_id", "")))
	return _assert(not has_target, "Should have no valid replay target when sacrificing the only friendly creature for a friendly_creature targeted action.")


func _test_empower_and_expertise_hooks() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var expert := ScenarioFixtures.summon_creature(player, match_state, "expert", "field", 2, 2, [], -1, {
		"triggered_abilities": [{
			"event_type": MatchTiming.EVENT_TURN_ENDING,
			"match_role": "controller",
			"required_zone": "lane",
			"min_noncreature_plays_this_turn": 1,
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}],
		}],
	})
	var ping := ScenarioFixtures.add_hand_card(player, "ping_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}],
	})
	var empower := ScenarioFixtures.add_hand_card(player, "empower_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "empower_damage", "target_player": "target_player", "amount": 1, "amount_per_damage": 1}]}],
	})
	var ping_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(ping.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	var empower_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(empower.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	MatchTurnLoop.end_turn(match_state, str(player.get("player_id", "")))
	return (
		_assert(bool(ping_play.get("is_valid", false)) and bool(empower_play.get("is_valid", false)), "Empower fixture actions should both be playable.") and
		_assert(int(opponent.get("health", 0)) == 27, "Empower should scale from damage already dealt to the opponent this turn.") and
		_assert(EvergreenRules.get_power(expert) == 3 and EvergreenRules.get_health(expert) == 3, "Expertise hook should trigger at end of turn after a non-creature play.")
	)


func _test_empower_deal_damage() -> bool:
	# Channeled Storm: Deal 3 damage + 1 per empower. Hit face twice (2 damage each), then play.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Two pings to face for 1 damage each = 2 empower
	var ping1 := ScenarioFixtures.add_hand_card(player, "ping1", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
	var ping2 := ScenarioFixtures.add_hand_card(player, "ping2", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping1.get("instance_id", "")), {"target_player_id": oid})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping2.get("instance_id", "")), {"target_player_id": oid})
	# Now play empower action: deal_damage with amount=3, empower_bonus=1, empower_amount=2 -> 5 damage
	var target := ScenarioFixtures.summon_creature(opponent, match_state, "target_creature", "field", 1, 10)
	var storm := ScenarioFixtures.add_hand_card(player, "channeled_storm", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "event_target", "amount": 3, "empower_bonus": 1}]}]})
	var storm_play := MatchTiming.play_action_from_hand(match_state, pid, str(storm.get("instance_id", "")), {"target_instance_id": str(target.get("instance_id", ""))})
	var target_health := EvergreenRules.get_remaining_health(target)
	return (
		_assert(bool(storm_play.get("is_valid", false)), "Empower deal_damage action should be playable.") and
		_assert(target_health == 5, "Empower deal_damage: 3 base + 2 empower = 5 damage to 10hp creature, expected 5hp remaining, got %d." % target_health)
	)


func _test_empower_cost_reduction() -> bool:
	# Empower cost reduction: action costs 1 less per instance of damage to opponent
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Deal damage to opponent 3 separate times = empower count 3
	for i in range(3):
		var ping := ScenarioFixtures.add_hand_card(player, "ping_cr_%d" % i, {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
		MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# Empower cost reduction card: base cost 7, empower reduces by 1 per instance = cost 4
	var costly := ScenarioFixtures.add_hand_card(player, "empower_costly", {"card_type": "action", "cost": 7, "self_cost_reduction": {"type": "empower", "amount": 1}, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "modify_stats", "target": "all_creatures", "power": -2, "health": -2}]}]})
	var effective_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, costly)
	var costly_play := MatchTiming.play_action_from_hand(match_state, pid, str(costly.get("instance_id", "")))
	return (
		_assert(effective_cost == 4, "Empower cost reduction: 7 base - 3 empower = 4, got %d." % effective_cost) and
		_assert(bool(costly_play.get("is_valid", false)), "Empower cost-reduced action should be playable with 10 magicka.")
	)


func _test_empower_destroy_creature() -> bool:
	# Luminous Shards style: destroy creature with max_power, empower increases threshold
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Deal damage to opponent 2 separate times = empower count 2
	for i in range(2):
		var ping := ScenarioFixtures.add_hand_card(player, "ping_dc_%d" % i, {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
		MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# Target: 3-power creature (should be destroyable with max_power 1 + 2 empower = 3)
	var target := ScenarioFixtures.summon_creature(opponent, match_state, "power3", "field", 3, 5)
	var shards := ScenarioFixtures.add_hand_card(player, "luminous_shards", {"card_type": "action", "cost": 0, "action_target_mode": "creature_1_power_or_less", "_empower_target_bonus": 1, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "destroy_creature", "target": "event_target", "max_power": 1, "empower_bonus": 1}]}]})
	var shards_play := MatchTiming.play_action_from_hand(match_state, pid, str(shards.get("instance_id", "")), {"target_instance_id": str(target.get("instance_id", ""))})
	var target_still_alive := _card_in_zone(match_state, str(target.get("instance_id", "")), "lane")
	return (
		_assert(bool(shards_play.get("is_valid", false)), "Empower destroy_creature action should be playable.") and
		_assert(not target_still_alive, "Empower destroy_creature: max_power 1 + 2 empower = 3, should destroy 3-power creature.")
	)


func _test_empower_add_support_uses() -> bool:
	# Alchemy style: add support uses, empower adds more
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Place a support with 1 remaining use
	var support := ScenarioFixtures.add_hand_card(player, "test_support", {"card_type": "support", "cost": 0, "support_uses": 1, "triggered_abilities": [{"family": "activate", "effects": [{"op": "damage", "target_player": "opponent", "amount": 1}]}]})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(support.get("instance_id", "")))
	# Deal damage to opponent 2 separate times = empower count 2
	for i in range(2):
		var ping := ScenarioFixtures.add_hand_card(player, "ping_asu_%d" % i, {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
		MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# Play alchemy: add 1 use + 2 empower = 3 uses added
	var alchemy := ScenarioFixtures.add_hand_card(player, "alchemy", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "add_support_uses", "target": "all_friendly_activated_supports", "amount": 1, "empower_bonus": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(alchemy.get("instance_id", "")))
	var remaining_uses := int(support.get("remaining_support_uses", 0))
	return _assert(remaining_uses == 4, "Empower add_support_uses: 1 base + 1 initial + 2 empower = 4 uses, got %d." % remaining_uses)


func _test_empower_summon_stat_bonus() -> bool:
	# Ayrenn's Chosen style: summon_from_effect with empower_stat_bonus
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Deal damage to opponent 2 separate times = empower count 2
	for i in range(2):
		var ping := ScenarioFixtures.add_hand_card(player, "ping_sfe_%d" % i, {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
		MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# Summon from effect: base 1/1 + empower_stat_bonus 1 * 2 empower = 3/3
	var summon_action := ScenarioFixtures.add_hand_card(player, "empower_summon", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "summon_from_effect", "lane_id": "field", "card_template": {"definition_id": "test_recruit", "name": "Recruit", "card_type": "creature", "subtypes": [], "attributes": [], "cost": 1, "power": 1, "health": 1, "base_power": 1, "base_health": 1}, "empower_stat_bonus": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(summon_action.get("instance_id", "")))
	# Find the summoned recruit in the field lane
	var summoned := _find_lane_card(match_state, "field", pid, "test_recruit")
	return (
		_assert(not summoned.is_empty(), "Empower summon_from_effect should summon a creature.") and
		_assert(EvergreenRules.get_power(summoned) == 3, "Empower summon stat: 1 base + 2 empower = 3 power, got %d." % EvergreenRules.get_power(summoned)) and
		_assert(EvergreenRules.get_remaining_health(summoned) == 3, "Empower summon stat: 1 base + 2 empower = 3 health, got %d." % EvergreenRules.get_remaining_health(summoned))
	)


func _test_empower_resets_at_end_of_turn() -> bool:
	# Empower bonus should reset at end of turn
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon target creature (during player's turn, for opponent - use generated to bypass action owner check)
	var target := _summon_generated_creature(match_state, oid, "target_reset", "field", 1, 10)
	# Deal damage to opponent 2 separate times = empower count 2
	for i in range(2):
		var ping := ScenarioFixtures.add_hand_card(player, "ping_reset_%d" % i, {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
		MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# Verify empower is active
	ExtendedMechanicPacks.ensure_player_state(player)
	var empower_before := int(player.get("empower_count_this_turn", 0))
	# End turn, opponent passes, back to player
	MatchTurnLoop.end_turn(match_state, pid)
	MatchTurnLoop.end_turn(match_state, oid)
	# Empower should be reset
	var empower_after := int(player.get("empower_count_this_turn", 0))
	# Play an empower damage action with no face damage this turn: should only do base damage
	var storm := ScenarioFixtures.add_hand_card(player, "storm_reset", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "event_target", "amount": 3, "empower_bonus": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(storm.get("instance_id", "")), {"target_instance_id": str(target.get("instance_id", ""))})
	var target_health := EvergreenRules.get_remaining_health(target)
	return (
		_assert(empower_before == 2, "Empower count should be 2 after 2 damage instances, got %d." % empower_before) and
		_assert(empower_after == 0, "Empower should reset to 0 after turn ends, got %d." % empower_after) and
		_assert(target_health == 7, "After reset, empower deal_damage should only do base 3 damage, target should have 7hp, got %d." % target_health)
	)


func _test_empower_summon_random_cost_scaling() -> bool:
	# Wish style: summon_random_creature with max_cost scaled by empower
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Deal damage 3 times = empower count 3
	for i in range(3):
		var ping := ScenarioFixtures.add_hand_card(player, "ping_src_%d" % i, {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
		MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# Count creatures in lanes before
	var creatures_before := 0
	for lane in match_state.get("lanes", []):
		creatures_before += lane.get("player_slots", {}).get(pid, []).size()
	# Play summon_random_creature: max_cost=2, empower_bonus_cost=1, empower=3 -> max_cost=5
	var wish := ScenarioFixtures.add_hand_card(player, "empower_wish", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "summon_random_creature", "max_cost": 2, "empower_bonus_cost": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(wish.get("instance_id", "")))
	# Count after — should have 1 more creature
	var creatures_after := 0
	var summoned_cost := -1
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(pid, []):
			creatures_after += 1
			if str(card.get("instance_id", "")).contains("generated"):
				summoned_cost = int(card.get("cost", 0))
	return (
		_assert(creatures_after == creatures_before + 1, "Empower summon_random_creature should summon exactly 1 creature.") and
		_assert(summoned_cost >= 0 and summoned_cost <= 5, "Empower summon: max_cost 2 + 3 empower = 5, summoned cost %d should be <= 5." % summoned_cost)
	)


func _test_empower_banish_per_attribute() -> bool:
	# Soul Shred style: banish count_per_attribute cards, empower adds to per-attribute count
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Give opponent deck with 2 attributes (intelligence, strength) — 10 cards total
	opponent["deck"] = []
	for i in range(5):
		opponent["deck"].append(ScenarioFixtures.make_card(oid, "int_card_%d" % i, {"zone": "deck", "card_type": "creature", "attributes": ["intelligence"]}))
	for i in range(5):
		opponent["deck"].append(ScenarioFixtures.make_card(oid, "str_card_%d" % i, {"zone": "deck", "card_type": "creature", "attributes": ["strength"]}))
	var initial_deck_size: int = opponent["deck"].size()
	# Deal damage once = empower count 1
	var ping := ScenarioFixtures.add_hand_card(player, "ping_bpa", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# Play banish: count_per_attribute=2, empower_bonus=1, empower=1 -> 3 per attribute * 2 attributes = 6 banished
	var shred := ScenarioFixtures.add_hand_card(player, "empower_shred", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "banish_from_opponent_deck", "count_per_attribute": 2, "empower_bonus": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(shred.get("instance_id", "")))
	var remaining_deck_size: int = opponent["deck"].size()
	var banished_count: int = initial_deck_size - remaining_deck_size
	return _assert(banished_count == 6, "Empower banish: (2 base + 1 empower) * 2 attributes = 6 banished, got %d." % banished_count)


func _test_empower_permanent_across_turns() -> bool:
	# Mystic of Ancient Rites: empower bonuses persist across turns
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon a creature with permanent_empower passive
	ScenarioFixtures.summon_creature(player, match_state, "mystic", "field", 2, 3, [], -1, {
		"passive_abilities": [{"type": "permanent_empower"}],
	})
	# Deal damage twice = empower count 2
	for i in range(2):
		var ping := ScenarioFixtures.add_hand_card(player, "ping_perm_%d" % i, {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
		MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# End turn (empower_count=2 should be accumulated into _permanent_empower_accumulated)
	MatchTurnLoop.end_turn(match_state, pid)
	MatchTurnLoop.end_turn(match_state, oid)
	# New turn: empower_count_this_turn reset to 0, but _permanent_empower_accumulated = 2
	var empower_count := int(player.get("empower_count_this_turn", 0))
	var permanent_accumulated := int(player.get("_permanent_empower_accumulated", 0))
	# Deal 1 more damage this turn = empower count 1, total empower = 1 + 2 = 3
	var ping_new := ScenarioFixtures.add_hand_card(player, "ping_perm_new", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping_new.get("instance_id", "")), {"target_player_id": oid})
	# Play empowered action: base 3 + empower_bonus 1 * total_empower 3 = 6 damage
	var target := _summon_generated_creature(match_state, oid, "perm_target", "field", 1, 10)
	var storm := ScenarioFixtures.add_hand_card(player, "perm_storm", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "event_target", "amount": 3, "empower_bonus": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(storm.get("instance_id", "")), {"target_instance_id": str(target.get("instance_id", ""))})
	var target_health := EvergreenRules.get_remaining_health(target)
	return (
		_assert(empower_count == 0, "Empower count should reset to 0 at start of new turn, got %d." % empower_count) and
		_assert(permanent_accumulated == 2, "Permanent empower should accumulate 2 from previous turn, got %d." % permanent_accumulated) and
		_assert(target_health == 4, "Permanent empower: base 3 + (1+2) empower = 6 damage, 10hp target should have 4hp, got %d." % target_health)
	)


func _test_invade_and_shout_pack() -> bool:
	return _test_invade_gate_progression() and _test_invade_gate_rules_text_and_cost_reduction() and _test_shout_upgrades()


func _test_invade_gate_progression() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var invade_one := ScenarioFixtures.add_hand_card(player, "invade_one", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
	})
	var invade_two := ScenarioFixtures.add_hand_card(player, "invade_two", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
	})
	var first_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(invade_one.get("instance_id", "")))
	var gate := _find_lane_card(match_state, "shadow", str(player.get("player_id", "")), "generated_oblivion_gate")
	var first_daedra := ScenarioFixtures.summon_creature(player, match_state, "first_daedra", "field", 1, 1, [], -1, {"subtypes": ["Daedra"]})
	var second_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(invade_two.get("instance_id", "")))
	var second_daedra := ScenarioFixtures.summon_creature(player, match_state, "second_daedra", "field", 1, 1, [], -1, {"subtypes": ["Daedra"]})
	return (
		_assert(bool(first_play.get("is_valid", false)) and bool(second_play.get("is_valid", false)), "Invade actions should be playable.") and
		_assert(not gate.is_empty() and int(gate.get("gate_level", 0)) == 2 and int(gate.get("health", 0)) == 6, "Repeated Invade plays should create and then upgrade the Oblivion Gate (gate=%s)." % [str(gate)]) and
		_assert(int(EvergreenRules.get_health(first_daedra)) == 2, "Level 1 Oblivion Gate should grant +0/+1 to summoned Daedra.") and
		_assert(int(EvergreenRules.get_power(second_daedra)) == 2 and int(EvergreenRules.get_health(second_daedra)) == 2, "Higher-level Oblivion Gates should increase summoned Daedra buffs.") and
		_assert(bool(gate.get("cannot_attack", false)), "Generated Oblivion Gates should be unable to attack.") and
		_assert(str(gate.get("rules_text", "")).find("+1/+1") != -1, "Level 2 gate should have +1/+1 in rules_text (got: %s)." % [str(gate.get("rules_text", ""))]) and
		_assert(int(gate.get("cost", -1)) == 3, "Generated Oblivion Gate should have cost 3.") and
		_assert(str(gate.get("rules_text", "")).find("cost 1 less") == -1, "Level 2 gate should NOT mention cost reduction.")
	)


func _test_invade_gate_rules_text_and_cost_reduction() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Create 5 invade actions
	var invade_cards: Array = []
	for i in range(5):
		invade_cards.append(ScenarioFixtures.add_hand_card(player, "invade_%d" % i, {
			"card_type": "action",
			"cost": 0,
			"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
		}))
	# Invade 1 — creates level 1 gate
	MatchTiming.play_action_from_hand(match_state, pid, str(invade_cards[0].get("instance_id", "")))
	var gate := _find_lane_card(match_state, "shadow", pid, "generated_oblivion_gate")
	var l1_text := str(gate.get("rules_text", ""))
	var l1_ok := l1_text.find("+0/+1") != -1
	# Invade 2 — level 2
	MatchTiming.play_action_from_hand(match_state, pid, str(invade_cards[1].get("instance_id", "")))
	var l2_text := str(gate.get("rules_text", ""))
	var l2_ok := l2_text.find("+1/+1") != -1 and l2_text.find("cost 1 less") == -1
	# Invade 3 — level 3 (cost reduction kicks in)
	MatchTiming.play_action_from_hand(match_state, pid, str(invade_cards[2].get("instance_id", "")))
	var l3_text := str(gate.get("rules_text", ""))
	var l3_ok := l3_text.find("cost 1 less") != -1 and l3_text.find("random keyword") == -1
	var auras: Array = match_state.get("card_cost_reduction_auras", [])
	var has_daedra_aura := false
	for aura in auras:
		if str(aura.get("filter_subtype", "")) == "Daedra" and str(aura.get("controller_player_id", "")) == pid:
			has_daedra_aura = true
	# Verify effective cost reduction applies to Daedra in hand
	var daedra_in_hand := ScenarioFixtures.add_hand_card(player, "cost_test_daedra", {"card_type": "creature", "cost": 5, "subtypes": ["Daedra"]})
	var non_daedra_in_hand := ScenarioFixtures.add_hand_card(player, "cost_test_non_daedra", {"card_type": "creature", "cost": 5, "subtypes": ["Nord"]})
	var daedra_effective_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, daedra_in_hand)
	var non_daedra_effective_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, non_daedra_in_hand)
	# Invade 4 — level 4 (one random keyword)
	MatchTiming.play_action_from_hand(match_state, pid, str(invade_cards[3].get("instance_id", "")))
	var l4_text := str(gate.get("rules_text", ""))
	var l4_ok := l4_text.find("a random keyword") != -1 and l4_text.find("two random") == -1
	# Invade 5 — level 5 (two random keywords)
	MatchTiming.play_action_from_hand(match_state, pid, str(invade_cards[4].get("instance_id", "")))
	var l5_text := str(gate.get("rules_text", ""))
	var l5_ok := l5_text.find("two random keywords") != -1
	return (
		_assert(l1_ok, "Level 1 gate rules_text should mention +0/+1 (got: %s)." % [l1_text]) and
		_assert(l2_ok, "Level 2 gate rules_text should mention +1/+1 without cost reduction (got: %s)." % [l2_text]) and
		_assert(l3_ok, "Level 3 gate rules_text should mention cost reduction without keywords (got: %s)." % [l3_text]) and
		_assert(has_daedra_aura, "Level 3 gate should add a Daedra cost reduction aura to match_state.") and
		_assert(daedra_effective_cost == 4, "Daedra in hand should cost 1 less with level 3+ gate (got: %d)." % [daedra_effective_cost]) and
		_assert(non_daedra_effective_cost == 5, "Non-Daedra should not get cost reduction (got: %d)." % [non_daedra_effective_cost]) and
		_assert(l4_ok, "Level 4 gate rules_text should mention 'a random keyword' (got: %s)." % [l4_text]) and
		_assert(l5_ok, "Level 5 gate rules_text should mention 'two random keywords' (got: %s)." % [l5_text]) and
		_assert(int(gate.get("health", 0)) == 12, "Level 5 gate should have health 12 (4 + 4*2) (got: %d)." % [int(gate.get("health", 0))])
	)


func _test_invade_gate_level_capped_at_five() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Create 8 invade actions to go well past level 5
	var invade_cards: Array = []
	for i in range(8):
		invade_cards.append(ScenarioFixtures.add_hand_card(player, "cap_invade_%d" % i, {
			"card_type": "action",
			"cost": 0,
			"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
		}))
	for card in invade_cards:
		MatchTiming.play_action_from_hand(match_state, pid, str(card.get("instance_id", "")))
	var gate := _find_lane_card(match_state, "shadow", pid, "generated_oblivion_gate")
	var gate_level := int(gate.get("gate_level", 0))
	# Summon a Daedra to check keyword count
	var daedra := ScenarioFixtures.summon_creature(player, match_state, "cap_daedra", "field", 1, 1, [], -1, {"subtypes": ["Daedra"]})
	var granted: Array = daedra.get("granted_keywords", [])
	return (
		_assert(gate_level == 5, "Gate level should cap at 5 (got: %d)." % [gate_level]) and
		_assert(granted.size() <= 2, "Summoned Daedra should get at most 2 keywords from level 5 gate (got: %d)." % [granted.size()])
	)


func _test_choose_one_repeat() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var action := ScenarioFixtures.add_hand_card(player, "repeat_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [
			{"op": "choose_one", "choices": [
				{"label": "Option A", "effects": [{"op": "gain_magicka", "amount": 1}]},
				{"label": "Option B", "effects": [{"op": "gain_magicka", "amount": 2}]},
			], "repeat": 3},
		]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(action.get("instance_id", "")))
	var pending: Array = match_state.get("pending_player_choices", [])
	var player_pending := 0
	for choice in pending:
		if str(choice.get("player_id", "")) == pid:
			player_pending += 1
	return _assert(player_pending == 3, "choose_one with repeat:3 should create 3 pending choices (got: %d)." % [player_pending])


func _test_invade_gate_ward_target() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Create a gate first via invade
	var invade_action := ScenarioFixtures.add_hand_card(player, "ward_invade", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(invade_action.get("instance_id", "")))
	var gate := _find_lane_card(match_state, "shadow", pid, "generated_oblivion_gate")
	# Summon a creature with grant_keyword targeting all_friendly_oblivion_gates
	var keeper := ScenarioFixtures.summon_creature(player, match_state, "ward_keeper", "field", 3, 4, [], -1, {
		"subtypes": ["Daedra"],
		"triggered_abilities": [{"family": MatchTiming.FAMILY_SUMMON, "effects": [
			{"op": "grant_keyword", "target": "all_friendly_oblivion_gates", "keyword_id": "ward"},
		]}],
	})
	return (
		_assert(not gate.is_empty(), "Gate should exist after invade.") and
		_assert(EvergreenRules.has_keyword(gate, "ward"), "Oblivion Gate should have Ward after Sigil Keeper effect (keywords: %s)." % [str(gate.get("granted_keywords", []))])
	)


func _test_summon_daedra_by_gate_level() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Invade twice to get a level 2 gate, then play the summon action
	for i in range(2):
		var inv := ScenarioFixtures.add_hand_card(player, "srd_invade_%d" % i, {
			"card_type": "action",
			"cost": 0,
			"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
		})
		MatchTiming.play_action_from_hand(match_state, pid, str(inv.get("instance_id", "")))
	var gate := _find_lane_card(match_state, "shadow", pid, "generated_oblivion_gate")
	var gate_level := int(gate.get("gate_level", 0))
	# Now play the summon_random_daedra_by_gate_level action (invade + summon)
	var summon_action := ScenarioFixtures.add_hand_card(player, "srd_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [
			{"op": "invade"},
			{"op": "summon_random_daedra_by_gate_level"},
		]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(summon_action.get("instance_id", "")))
	# Gate should now be level 3 after the third invade
	var updated_gate_level := int(gate.get("gate_level", 0))
	# Find any summoned creature in field lane that isn't the gate or the keeper
	var summoned_daedra := {}
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == "shadow":
			continue
		for card in lane.get("player_slots", {}).get(pid, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != "srd_action":
				summoned_daedra = card
				break
	return (
		_assert(updated_gate_level == 3, "Gate should be level 3 after 3 invades (got: %d)." % [updated_gate_level]) and
		_assert(not summoned_daedra.is_empty(), "summon_random_daedra_by_gate_level should summon a creature to a lane.") and
		_assert(int(summoned_daedra.get("cost", -1)) == 3, "Summoned Daedra should have cost equal to gate level 3 (got: %d)." % [int(summoned_daedra.get("cost", -1))])
	)


func _test_shout_upgrades() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var shout_levels := [
		{"definition_id": "voice_level_1", "name": "Word I", "card_type": "action", "cost": 0, "shout_chain_id": "voice", "shout_level": 1},
		{"definition_id": "voice_level_2", "name": "Word II", "card_type": "action", "cost": 0, "shout_chain_id": "voice", "shout_level": 2},
		{"definition_id": "voice_level_3", "name": "Word III", "card_type": "action", "cost": 0, "shout_chain_id": "voice", "shout_level": 3},
	]
	var first_shout := ScenarioFixtures.add_hand_card(player, "shout_a", {
		"card_type": "action",
		"cost": 0,
		"definition_id": "voice_level_1",
		"shout_chain_id": "voice",
		"shout_level": 1,
		"shout_levels": shout_levels,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "upgrade_shout"}]}],
	})
	var second_shout := ScenarioFixtures.add_hand_card(player, "shout_b", {
		"card_type": "action",
		"cost": 0,
		"definition_id": "voice_level_1",
		"shout_chain_id": "voice",
		"shout_level": 1,
		"shout_levels": shout_levels,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "upgrade_shout"}]}],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(first_shout.get("instance_id", "")))
	return (
		_assert(bool(play_result.get("is_valid", false)), "Shout card should be playable.") and
		_assert(str(second_shout.get("definition_id", "")) == "voice_level_2", "Playing a Shout should upgrade the remaining copies in hand, deck, and discard.")
	)


func _test_treasure_hunt_and_consume_pack() -> bool:
	return _test_treasure_hunt_completion() and _test_consume_reuse()


func _test_treasure_hunt_completion() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	# Multi-type treasure hunt: needs one item AND one action to complete, then +2/+2
	var treasure_hunter := ScenarioFixtures.summon_creature(player, match_state, "treasure_hunter", "field", 2, 2, [], -1, {
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["item", "action"], "effects": [{"op": "modify_stats", "target": "self", "power": 2, "health": 2}]},
		],
	})
	player["deck"] = [
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "filler", {"zone": "deck", "card_type": "creature"}),
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "draw_action", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "draw_item", {"zone": "deck", "card_type": "item"}),
	]
	# Draw 2 cards: item (top) then action — both match, completing the hunt
	var draw_result := MatchTiming.draw_cards(match_state, str(player.get("player_id", "")), 2, {"reason": "treasure_test", "source_controller_player_id": str(player.get("player_id", ""))})
	MatchTiming.publish_events(match_state, draw_result.get("events", []))
	var hunt_complete := EvergreenRules.get_power(treasure_hunter) == 4 and EvergreenRules.get_health(treasure_hunter) == 4
	if not _assert(hunt_complete, "Treasure Hunt should track matching draws and fire effects once all required types are found."):
		return false
	# Draw again — the hunt is spent, should NOT trigger again
	var draw_result2 := MatchTiming.draw_cards(match_state, str(player.get("player_id", "")), 1, {"reason": "treasure_test", "source_controller_player_id": str(player.get("player_id", ""))})
	MatchTiming.publish_events(match_state, draw_result2.get("events", []))
	return _assert(EvergreenRules.get_power(treasure_hunter) == 4 and EvergreenRules.get_health(treasure_hunter) == 4, "Treasure Hunt should be spent after completing — subsequent draws should not re-trigger.")


func _test_treasure_hunt_count_based() -> bool:
	# Single-type hunt with count 3 (like Abandoned Imperfect pattern)
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var hunter := ScenarioFixtures.summon_creature(player, match_state, "count_hunter", "field", 1, 1, [], -1, {
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action"], "hunt_count": 3, "effects": [{"op": "modify_stats", "target": "self", "power": 5, "health": 5}]},
		],
	})
	player["deck"] = [
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "filler", {"zone": "deck", "card_type": "creature"}),
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "action3", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "action2", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "action1", {"zone": "deck", "card_type": "action"}),
	]
	# Draw 2 actions — should be 2/3, NOT complete
	var draw1 := MatchTiming.draw_cards(match_state, str(player.get("player_id", "")), 2, {"reason": "test", "source_controller_player_id": str(player.get("player_id", ""))})
	MatchTiming.publish_events(match_state, draw1.get("events", []))
	if not _assert(EvergreenRules.get_power(hunter) == 1 and EvergreenRules.get_health(hunter) == 1, "Treasure Hunt with count 3 should NOT complete after only 2 matching draws."):
		return false
	# Draw 3rd action — should complete (3/3)
	var draw2 := MatchTiming.draw_cards(match_state, str(player.get("player_id", "")), 1, {"reason": "test", "source_controller_player_id": str(player.get("player_id", ""))})
	MatchTiming.publish_events(match_state, draw2.get("events", []))
	if not _assert(EvergreenRules.get_power(hunter) == 6 and EvergreenRules.get_health(hunter) == 6, "Treasure Hunt with count 3 should complete after 3 matching draws (+5/+5)."):
		return false
	# Draw a non-matching card — should not re-trigger (spent)
	var draw3 := MatchTiming.draw_cards(match_state, str(player.get("player_id", "")), 1, {"reason": "test", "source_controller_player_id": str(player.get("player_id", ""))})
	MatchTiming.publish_events(match_state, draw3.get("events", []))
	return _assert(EvergreenRules.get_power(hunter) == 6 and EvergreenRules.get_health(hunter) == 6, "Treasure Hunt should be spent after count-based completion.")


func _test_consume_reuse() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var consumer := ScenarioFixtures.summon_creature(player, match_state, "consumer", "field", 2, 2, [], -1, {
		"triggered_abilities": [{"event_type": "test_consume", "match_role": "source", "required_zone": "lane", "effects": [{"op": "consume", "consumer_target": "self", "target": "event_target"}]}],
	})
	var meal := ScenarioFixtures.summon_creature(player, match_state, "meal", "field", 1, 3)
	MatchMutations.discard_card(match_state, str(meal.get("instance_id", "")), {"reason": "test_consume_setup"})
	MatchTiming.publish_events(match_state, [{"event_type": "test_consume", "player_id": str(player.get("player_id", "")), "source_instance_id": str(consumer.get("instance_id", "")), "target_instance_id": str(meal.get("instance_id", ""))}])
	return (
		_assert(EvergreenRules.get_power(consumer) == 3 and EvergreenRules.get_health(consumer) == 5, "Extended mechanic packs should continue to reuse the shared Consume mutation pipeline.") and
		_assert(_contains_instance(player.get("discard", []), str(meal.get("instance_id", ""))), "Consume should continue routing eaten cards through the shared destination-zone handling.")
	)


func _test_wax_and_wane_pack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var wax_card := ScenarioFixtures.add_hand_card(player, "wax_spell", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [
				{"op": "damage", "target_player": "target_player", "amount": 1, "required_wax_wane_phase": "wax"},
				{"op": "damage", "target_player": "target_player", "amount": 2, "required_wax_wane_phase": "wane"},
			],
		}],
	})
	var wane_card := ScenarioFixtures.add_hand_card(player, "wane_spell", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [
				{"op": "damage", "target_player": "target_player", "amount": 1, "required_wax_wane_phase": "wax"},
				{"op": "damage", "target_player": "target_player", "amount": 2, "required_wax_wane_phase": "wane"},
			],
		}],
	})
	var wax_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(wax_card.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	MatchTurnLoop.end_turn(match_state, str(player.get("player_id", "")))
	MatchTurnLoop.end_turn(match_state, str(opponent.get("player_id", "")))
	var wane_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(wane_card.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	return (
		_assert(bool(wax_play.get("is_valid", false)) and bool(wane_play.get("is_valid", false)), "Wax/Wane fixture actions should be playable across turns.") and
		_assert(int(opponent.get("health", 0)) == 27, "Wax/Wane should swap between its two effect packages at the end of the controller's turn.")
	)


func _test_dual_wax_wane() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	# Player starts in wax phase. Enable dual wax/wane, then play a wane-only spell.
	# Without dual, the wane effect should not fire. With dual, both should fire.
	var spell := ScenarioFixtures.add_hand_card(player, "dual_test_spell", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [
				{"op": "damage", "target_player": "target_player", "amount": 3, "required_wax_wane_phase": "wax"},
				{"op": "damage", "target_player": "target_player", "amount": 5, "required_wax_wane_phase": "wane"},
			],
		}],
	})
	# Confirm player is in wax phase
	var initial_phase := str(player.get("wax_wane_state", "wax"))
	# Enable dual wax/wane
	player["_dual_wax_wane"] = true
	var play_result := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(spell.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	# Both wax (3) and wane (5) effects should fire: 30 - 8 = 22
	var health_after_dual := int(opponent.get("health", 0))
	# End turn to verify dual flag is cleared and toggle proceeds normally
	MatchTurnLoop.end_turn(match_state, str(player.get("player_id", "")))
	var phase_after_end := str(player.get("wax_wane_state", ""))
	var dual_after_end := bool(player.get("_dual_wax_wane", false))
	# Play another spell next turn to confirm only wane fires (dual cleared)
	MatchTurnLoop.end_turn(match_state, str(opponent.get("player_id", "")))
	var spell2 := ScenarioFixtures.add_hand_card(player, "dual_test_spell_2", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [
				{"op": "damage", "target_player": "target_player", "amount": 3, "required_wax_wane_phase": "wax"},
				{"op": "damage", "target_player": "target_player", "amount": 5, "required_wax_wane_phase": "wane"},
			],
		}],
	})
	MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(spell2.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	# Only wane (5) should fire: 22 - 5 = 17
	var health_after_normal := int(opponent.get("health", 0))
	return (
		_assert(initial_phase == "wax", "Player should start in wax phase.") and
		_assert(bool(play_result.get("is_valid", false)), "Dual wax/wane spell should be playable.") and
		_assert(health_after_dual == 22, "Both wax and wane effects should fire when dual_wax_wane is active.") and
		_assert(phase_after_end == "wane", "Phase should toggle normally to wane after dual turn.") and
		_assert(not dual_after_end, "Dual wax/wane flag should be cleared at end of turn.") and
		_assert(health_after_normal == 17, "Only wane effect should fire after dual flag is cleared.")
	)


func _test_wax_creature_turn_trigger() -> bool:
	# Wax/wane effects fire on summon only, not on turn start.
	# Summoning during wax phase should fire the wax effect immediately.
	# Subsequent turn starts should NOT re-trigger the effect.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var player_id := str(player.get("player_id", ""))
	var opponent_id := str(opponent.get("player_id", ""))
	# Player starts in wax phase. Summon a creature with wax: +2/+0 and wane: +0/+1.
	var creature := ScenarioFixtures.summon_creature(player, match_state, "wax_creature", "field", 2, 3, [], -1, {
		"cost": 0,
		"triggered_abilities": [
			{"family": "wax", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 2, "health": 0}]},
			{"family": "wane", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 1}]},
		],
	})
	# Wax effect should have fired on summon: 2 + 2 = 4 power
	var power_after_summon := EvergreenRules.get_power(creature)
	var health_after_summon := EvergreenRules.get_health(creature)
	# End turn and come back — effects should NOT re-trigger
	MatchTurnLoop.end_turn(match_state, player_id)
	MatchTurnLoop.end_turn(match_state, opponent_id)
	var power_after_turn := EvergreenRules.get_power(creature)
	var health_after_turn := EvergreenRules.get_health(creature)
	# Now summon another creature during wane phase
	var creature2 := ScenarioFixtures.summon_creature(player, match_state, "wane_creature", "field", 1, 1, [], -1, {
		"cost": 0,
		"triggered_abilities": [
			{"family": "wax", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 3, "health": 0}]},
			{"family": "wane", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 2}]},
		],
	})
	# Wane effect should fire: 1 + 0 = 1 power, 1 + 2 = 3 health
	var c2_power := EvergreenRules.get_power(creature2)
	var c2_health := EvergreenRules.get_health(creature2)
	return (
		_assert(not creature.is_empty(), "Creature should be summoned successfully.") and
		_assert(power_after_summon == 4, "Wax effect should fire on summon: 2 + 2 = 4 power.") and
		_assert(health_after_summon == 3, "Health unchanged by wax effect (wax gives +2/+0).") and
		_assert(power_after_turn == 4, "Power should NOT change on subsequent turn starts.") and
		_assert(health_after_turn == 3, "Health should NOT change on subsequent turn starts.") and
		_assert(not creature2.is_empty(), "Second creature should be summoned.") and
		_assert(c2_power == 1, "Wane effect gives +0/+2, power stays at 1.") and
		_assert(c2_health == 3, "Wane effect should fire on summon: 1 + 2 = 3 health.")
	)


func _test_aldora_the_daring_pack() -> bool:
	return (
		_test_aldora_treasure_hunt_completion() and
		_test_aldora_skywag_summon() and
		_test_aldora_skywag_buff() and
		_test_aldora_skywag_lane_full() and
		_test_aldora_multiple_hunters_trigger_skywag() and
		_test_aldora_spent_hunt_no_skywag()
	)


func _test_aldora_treasure_hunt_completion() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Aldora: treasure hunt for action, creature, item, support → +6/+6
	var aldora := ScenarioFixtures.summon_creature(player, match_state, "aldora", "field", 3, 3, [], -1, {
		"definition_id": "cwc_str_aldora_the_daring",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action", "creature", "item", "support"], "effects": [{"op": "modify_stats", "target": "self", "power": 6, "health": 6}]},
		],
	})
	# Deck: top→item, action, support, creature (pop_back draws, so last element is drawn first)
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "deck_creature", {"zone": "deck", "card_type": "creature"}),
		ScenarioFixtures.make_card(player_id, "deck_support", {"zone": "deck", "card_type": "support"}),
		ScenarioFixtures.make_card(player_id, "deck_action", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(player_id, "deck_item", {"zone": "deck", "card_type": "item"}),
	]
	# Draw 3 cards (item, action, support) — hunt NOT complete yet
	var draw1 := MatchTiming.draw_cards(match_state, player_id, 3, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw1.get("events", []))
	if not _assert(EvergreenRules.get_power(aldora) == 3 and EvergreenRules.get_health(aldora) == 3, "Aldora should still be 3/3 after finding 3 of 4 types."):
		return false
	# Draw 4th card (creature) — hunt completes → +6/+6 = 9/9
	var draw2 := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw2.get("events", []))
	if not _assert(EvergreenRules.get_power(aldora) == 9 and EvergreenRules.get_health(aldora) == 9, "Aldora should be 9/9 after completing treasure hunt (+6/+6)."):
		return false
	# Add another action to deck and draw it — hunt is spent, no further buff
	player["deck"].append(ScenarioFixtures.make_card(player_id, "extra_action", {"zone": "deck", "card_type": "action"}))
	var draw3 := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw3.get("events", []))
	return _assert(EvergreenRules.get_power(aldora) == 9 and EvergreenRules.get_health(aldora) == 9, "Aldora should stay 9/9 after hunt is spent.")


func _test_aldora_skywag_summon() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Aldora with both abilities: treasure hunt + on_friendly_treasure_found
	var aldora := ScenarioFixtures.summon_creature(player, match_state, "aldora_sky", "field", 3, 3, [], -1, {
		"definition_id": "cwc_str_aldora_the_daring",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action", "creature", "item", "support"], "effects": [{"op": "modify_stats", "target": "self", "power": 6, "health": 6}]},
			{"family": "on_friendly_treasure_found", "required_zone": "lane", "effects": [{"op": "summon_or_buff", "card_template": {"definition_id": "cwc_str_skywag", "name": "Skywag", "card_type": "creature", "subtypes": ["Beast"], "attributes": ["strength"], "cost": 1, "power": 1, "health": 1, "base_power": 1, "base_health": 1, "rules_text": ""}, "buff_power": 1, "buff_health": 1}]},
		],
	})
	# Deck with one action card
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "deck_action", {"zone": "deck", "card_type": "action"}),
	]
	# Draw the action — partial hunt match → treasure_found → Skywag summoned
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	var skywag := _find_lane_card(match_state, "field", player_id, "cwc_str_skywag")
	return (
		_assert(not skywag.is_empty(), "Skywag should be summoned to Aldora's lane when a treasure is found.") and
		_assert(EvergreenRules.get_power(skywag) == 1 and EvergreenRules.get_health(skywag) == 1, "Skywag should be 1/1 on initial summon.")
	)


func _test_aldora_skywag_buff() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var aldora := ScenarioFixtures.summon_creature(player, match_state, "aldora_buff", "field", 3, 3, [], -1, {
		"definition_id": "cwc_str_aldora_the_daring",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action", "creature", "item", "support"], "effects": [{"op": "modify_stats", "target": "self", "power": 6, "health": 6}]},
			{"family": "on_friendly_treasure_found", "required_zone": "lane", "effects": [{"op": "summon_or_buff", "card_template": {"definition_id": "cwc_str_skywag", "name": "Skywag", "card_type": "creature", "subtypes": ["Beast"], "attributes": ["strength"], "cost": 1, "power": 1, "health": 1, "base_power": 1, "base_health": 1, "rules_text": ""}, "buff_power": 1, "buff_health": 1}]},
		],
	})
	# Pre-place Skywag in field lane
	var skywag := _summon_generated_creature(match_state, player_id, "skywag_existing", "field", 1, 1)
	skywag["definition_id"] = "cwc_str_skywag"
	# Deck with one action card
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "deck_action", {"zone": "deck", "card_type": "action"}),
	]
	# Draw the action — treasure_found → Skywag already exists → buff +1/+1
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	return (
		_assert(EvergreenRules.get_power(skywag) == 2 and EvergreenRules.get_health(skywag) == 2, "Existing Skywag should be buffed to 2/2 when a treasure is found.") and
		_assert(_find_lane_card(match_state, "field", player_id, "cwc_str_skywag") == skywag, "Should not summon a second Skywag when one already exists.")
	)


func _test_aldora_skywag_lane_full() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Aldora in field lane
	var aldora := ScenarioFixtures.summon_creature(player, match_state, "aldora_full", "field", 3, 3, [], -1, {
		"definition_id": "cwc_str_aldora_the_daring",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action", "creature", "item", "support"], "effects": [{"op": "modify_stats", "target": "self", "power": 6, "health": 6}]},
			{"family": "on_friendly_treasure_found", "required_zone": "lane", "effects": [{"op": "summon_or_buff", "card_template": {"definition_id": "cwc_str_skywag", "name": "Skywag", "card_type": "creature", "subtypes": ["Beast"], "attributes": ["strength"], "cost": 1, "power": 1, "health": 1, "base_power": 1, "base_health": 1, "rules_text": ""}, "buff_power": 1, "buff_health": 1}]},
		],
	})
	# Fill remaining 3 slots (4 total = capacity)
	_summon_generated_creature(match_state, player_id, "filler1", "field", 1, 1)
	_summon_generated_creature(match_state, player_id, "filler2", "field", 1, 1)
	_summon_generated_creature(match_state, player_id, "filler3", "field", 1, 1)
	# Deck with one action
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "deck_action", {"zone": "deck", "card_type": "action"}),
	]
	# Draw the action — treasure found but lane full, no Skywag on board → nothing happens
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	var skywag_field := _find_lane_card(match_state, "field", player_id, "cwc_str_skywag")
	var skywag_shadow := _find_lane_card(match_state, "shadow", player_id, "cwc_str_skywag")
	return _assert(skywag_field.is_empty() and skywag_shadow.is_empty(), "Skywag should NOT be summoned when Aldora's lane is full and Skywag is not on board.")


func _test_aldora_multiple_hunters_trigger_skywag() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Aldora with both abilities
	var aldora := ScenarioFixtures.summon_creature(player, match_state, "aldora_multi", "field", 3, 3, [], -1, {
		"definition_id": "cwc_str_aldora_the_daring",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action", "creature", "item", "support"], "effects": [{"op": "modify_stats", "target": "self", "power": 6, "health": 6}]},
			{"family": "on_friendly_treasure_found", "required_zone": "lane", "effects": [{"op": "summon_or_buff", "card_template": {"definition_id": "cwc_str_skywag", "name": "Skywag", "card_type": "creature", "subtypes": ["Beast"], "attributes": ["strength"], "cost": 1, "power": 1, "health": 1, "base_power": 1, "base_health": 1, "rules_text": ""}, "buff_power": 1, "buff_health": 1}]},
		],
	})
	# Second treasure hunter also looking for actions
	var hunter2 := ScenarioFixtures.summon_creature(player, match_state, "hunter2", "field", 2, 2, [], -1, {
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}]},
		],
	})
	# Deck with one action
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "deck_action", {"zone": "deck", "card_type": "action"}),
	]
	# Draw the action — BOTH hunters match → two treasure_found events
	# First treasure_found → summon Skywag (1/1), second → buff Skywag to 2/2
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	var skywag := _find_lane_card(match_state, "field", player_id, "cwc_str_skywag")
	return (
		_assert(not skywag.is_empty(), "Skywag should be summoned when multiple hunters find treasure.") and
		_assert(EvergreenRules.get_power(skywag) == 2 and EvergreenRules.get_health(skywag) == 2, "Skywag should be 2/2 — summoned on first find, buffed +1/+1 on second find.")
	)


func _test_aldora_spent_hunt_no_skywag() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Aldora with both abilities
	var aldora := ScenarioFixtures.summon_creature(player, match_state, "aldora_spent", "field", 3, 3, [], -1, {
		"definition_id": "cwc_str_aldora_the_daring",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action", "creature", "item", "support"], "effects": [{"op": "modify_stats", "target": "self", "power": 6, "health": 6}]},
			{"family": "on_friendly_treasure_found", "required_zone": "lane", "effects": [{"op": "summon_or_buff", "card_template": {"definition_id": "cwc_str_skywag", "name": "Skywag", "card_type": "creature", "subtypes": ["Beast"], "attributes": ["strength"], "cost": 1, "power": 1, "health": 1, "base_power": 1, "base_health": 1, "rules_text": ""}, "buff_power": 1, "buff_health": 1}]},
		],
	})
	# Deck: action, creature, item, support, then another action
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "extra_action", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(player_id, "deck_creature", {"zone": "deck", "card_type": "creature"}),
		ScenarioFixtures.make_card(player_id, "deck_support", {"zone": "deck", "card_type": "support"}),
		ScenarioFixtures.make_card(player_id, "deck_item", {"zone": "deck", "card_type": "item"}),
		ScenarioFixtures.make_card(player_id, "deck_action", {"zone": "deck", "card_type": "action"}),
	]
	# Draw all 4 types to complete hunt
	var draw1 := MatchTiming.draw_cards(match_state, player_id, 4, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw1.get("events", []))
	# Aldora should be 9/9 and Skywag should exist (summoned + 3 buffs = 4/4)
	if not _assert(EvergreenRules.get_power(aldora) == 9, "Aldora should be 9/9 after completing treasure hunt."):
		return false
	var skywag := _find_lane_card(match_state, "field", player_id, "cwc_str_skywag")
	if not _assert(not skywag.is_empty(), "Skywag should exist after Aldora's treasure hunt."):
		return false
	var skywag_power_before := EvergreenRules.get_power(skywag)
	var skywag_health_before := EvergreenRules.get_health(skywag)
	# Draw another action — Aldora's hunt is spent, should NOT trigger another treasure_found
	var draw2 := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw2.get("events", []))
	return _assert(
		EvergreenRules.get_power(skywag) == skywag_power_before and EvergreenRules.get_health(skywag) == skywag_health_before,
		"Skywag should NOT be buffed further after Aldora's hunt is spent."
	)


func _test_mistveil_warden_pack() -> bool:
	return (
		_test_mistveil_warden_buffs_guard_creature() and
		_test_mistveil_warden_buffs_guard_item() and
		_test_mistveil_warden_ignores_non_guard() and
		_test_mistveil_warden_item_equip_transfers_buff()
	)


func _test_mistveil_warden_buffs_guard_creature() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon Mistveil Warden with treasure hunt for Guard
	var warden := ScenarioFixtures.summon_creature(player, match_state, "mistveil_warden", "field", 2, 4, [], -1, {
		"definition_id": "cwc_end_mistveil_warden",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["guard"], "effects": [{"op": "modify_stats", "target": "treasure_card", "power": 1, "health": 2}]},
		],
	})
	# Stack deck with a Guard creature (Fharun Defender: 1/4, Guard)
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "guard_creature", {"zone": "deck", "card_type": "creature", "keywords": ["guard"], "power": 1, "health": 4, "base_power": 1, "base_health": 4}),
	]
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	# Find the drawn card in hand (instance_id = player_id + "_" + label)
	var hand: Array = player.get("hand", [])
	var drawn_card: Dictionary = {}
	for c in hand:
		if str(c.get("instance_id", "")).ends_with("guard_creature"):
			drawn_card = c
			break
	if not _assert(not drawn_card.is_empty(), "Guard creature should be in hand after draw."):
		return false
	return (
		_assert(int(drawn_card.get("power_bonus", 0)) == 1, "Guard creature should have +1 power bonus from Mistveil Warden.") and
		_assert(int(drawn_card.get("health_bonus", 0)) == 2, "Guard creature should have +2 health bonus from Mistveil Warden.")
	)


func _test_mistveil_warden_buffs_guard_item() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var warden := ScenarioFixtures.summon_creature(player, match_state, "mistveil_warden2", "field", 2, 4, [], -1, {
		"definition_id": "cwc_end_mistveil_warden",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["guard"], "effects": [{"op": "modify_stats", "target": "treasure_card", "power": 1, "health": 2}]},
		],
	})
	# Stack deck with a Guard item (Legion Shield: +1/+3, Guard)
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "guard_item", {"zone": "deck", "card_type": "item", "keywords": ["guard"], "equip_power_bonus": 1, "equip_health_bonus": 3, "equip_keywords": ["guard"]}),
	]
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	var hand: Array = player.get("hand", [])
	var drawn_item: Dictionary = {}
	for c in hand:
		if str(c.get("instance_id", "")).ends_with("guard_item"):
			drawn_item = c
			break
	if not _assert(not drawn_item.is_empty(), "Guard item should be in hand after draw."):
		return false
	return (
		_assert(int(drawn_item.get("power_bonus", 0)) == 1, "Guard item should have +1 power bonus.") and
		_assert(int(drawn_item.get("health_bonus", 0)) == 2, "Guard item should have +2 health bonus.") and
		_assert(int(drawn_item.get("equip_power_bonus", 0)) == 2, "Guard item equip_power_bonus should be 1+1=2.") and
		_assert(int(drawn_item.get("equip_health_bonus", 0)) == 5, "Guard item equip_health_bonus should be 3+2=5.")
	)


func _test_mistveil_warden_ignores_non_guard() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var warden := ScenarioFixtures.summon_creature(player, match_state, "mistveil_warden3", "field", 2, 4, [], -1, {
		"definition_id": "cwc_end_mistveil_warden",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["guard"], "effects": [{"op": "modify_stats", "target": "treasure_card", "power": 1, "health": 2}]},
		],
	})
	# Stack deck with a non-Guard creature
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "no_guard", {"zone": "deck", "card_type": "creature", "keywords": [], "power": 3, "health": 3, "base_power": 3, "base_health": 3}),
	]
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	var hand: Array = player.get("hand", [])
	var drawn_card: Dictionary = {}
	for c in hand:
		if str(c.get("instance_id", "")).ends_with("no_guard"):
			drawn_card = c
			break
	if not _assert(not drawn_card.is_empty(), "Non-guard creature should be in hand."):
		return false
	return (
		_assert(int(drawn_card.get("power_bonus", 0)) == 0, "Non-guard creature should NOT be buffed.") and
		_assert(int(drawn_card.get("health_bonus", 0)) == 0, "Non-guard creature should NOT be buffed.")
	)


func _test_mistveil_warden_item_equip_transfers_buff() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var warden := ScenarioFixtures.summon_creature(player, match_state, "mistveil_warden4", "field", 2, 4, [], -1, {
		"definition_id": "cwc_end_mistveil_warden",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["guard"], "effects": [{"op": "modify_stats", "target": "treasure_card", "power": 1, "health": 2}]},
		],
	})
	# A target creature to equip the item on
	var target := ScenarioFixtures.summon_creature(player, match_state, "equip_target", "field", 3, 3, [], -1, {
		"definition_id": "test_creature",
	})
	# Stack deck with Legion Shield (Guard, +1/+3)
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "guard_item2", {"zone": "deck", "card_type": "item", "keywords": ["guard"], "equip_power_bonus": 1, "equip_health_bonus": 3, "equip_keywords": ["guard"]}),
	]
	# Draw the Guard item — Mistveil Warden buffs it to +2/+5
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	# Find the buffed item in hand
	var hand: Array = player.get("hand", [])
	var item: Dictionary = {}
	for c in hand:
		if str(c.get("instance_id", "")).ends_with("guard_item2"):
			item = c
			break
	if not _assert(not item.is_empty(), "Guard item should be in hand."):
		return false
	# Equip the item onto the target creature
	var target_id := str(target.get("instance_id", ""))
	var equip_result := MatchMutations.attach_item_to_creature(match_state, player_id, item, target_id)
	if not _assert(bool(equip_result.get("is_valid", false)), "Equipping buffed item should succeed."):
		return false
	# Target creature should now have buffed stats: 3+2=5 power, 3+5=8 health
	return (
		_assert(EvergreenRules.get_power(target) == 5, "Creature with buffed item should have 3+2=5 power.") and
		_assert(EvergreenRules.get_health(target) == 8, "Creature with buffed item should have 3+5=8 health.")
	)


func _test_murkwater_guide_pack() -> bool:
	return (
		_test_murkwater_guide_copies_zero_cost() and
		_test_murkwater_guide_copy_has_unique_id() and
		_test_murkwater_guide_ignores_nonzero_cost() and
		_test_murkwater_guide_spent_no_second_copy()
	)


func _test_murkwater_guide_copies_zero_cost() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var guide := ScenarioFixtures.summon_creature(player, match_state, "murkwater_guide", "field", 4, 2, [], -1, {
		"definition_id": "cwc_agi_murkwater_guide",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["zero_cost"], "effects": [{"op": "generate_card_to_hand", "target": "treasure_card_copy"}]},
		],
	})
	# Stack deck with a 0-cost card
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "zero_cost_card", {"zone": "deck", "card_type": "creature", "cost": 0, "definition_id": "str_nord_firebrand", "power": 1, "health": 1, "base_power": 1, "base_health": 1}),
	]
	var hand_before: int = player.get("hand", []).size()
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	var hand: Array = player.get("hand", [])
	# Should have drawn 1 card + 1 copy = 2 new cards in hand
	if not _assert(hand.size() == hand_before + 2, "Hand should have 2 new cards (drawn + copy)."):
		return false
	# Both cards should share the same definition_id
	var copy_count := 0
	for c in hand:
		if str(c.get("definition_id", "")) == "str_nord_firebrand":
			copy_count += 1
	return _assert(copy_count >= 2, "Hand should have at least 2 cards with definition_id 'str_nord_firebrand'.")


func _test_murkwater_guide_copy_has_unique_id() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var guide := ScenarioFixtures.summon_creature(player, match_state, "murkwater_guide_id", "field", 4, 2, [], -1, {
		"definition_id": "cwc_agi_murkwater_guide",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["zero_cost"], "effects": [{"op": "generate_card_to_hand", "target": "treasure_card_copy"}]},
		],
	})
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "zero_cost_unique", {"zone": "deck", "card_type": "creature", "cost": 0, "definition_id": "str_nord_firebrand", "power": 1, "health": 1, "base_power": 1, "base_health": 1}),
	]
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	# Find all Nord Firebrands in hand — they must have different instance_ids
	var hand: Array = player.get("hand", [])
	var ids: Array = []
	for c in hand:
		if str(c.get("definition_id", "")) == "str_nord_firebrand":
			ids.append(str(c.get("instance_id", "")))
	if not _assert(ids.size() == 2, "Should have 2 Nord Firebrands in hand."):
		return false
	return _assert(ids[0] != ids[1], "Original and copy must have different instance_ids (got '%s' and '%s')." % [ids[0], ids[1]])


func _test_murkwater_guide_ignores_nonzero_cost() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var guide := ScenarioFixtures.summon_creature(player, match_state, "murkwater_guide2", "field", 4, 2, [], -1, {
		"definition_id": "cwc_agi_murkwater_guide",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["zero_cost"], "effects": [{"op": "generate_card_to_hand", "target": "treasure_card_copy"}]},
		],
	})
	# Stack deck with a non-zero-cost card
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "costly_card", {"zone": "deck", "card_type": "creature", "cost": 3, "power": 2, "health": 2}),
	]
	var hand_before: int = player.get("hand", []).size()
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	var hand: Array = player.get("hand", [])
	return _assert(hand.size() == hand_before + 1, "Hand should only have 1 new card (no copy for non-zero cost).")


func _test_murkwater_guide_spent_no_second_copy() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var guide := ScenarioFixtures.summon_creature(player, match_state, "murkwater_guide3", "field", 4, 2, [], -1, {
		"definition_id": "cwc_agi_murkwater_guide",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["zero_cost"], "effects": [{"op": "generate_card_to_hand", "target": "treasure_card_copy"}]},
		],
	})
	# Stack deck with two 0-cost cards
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "second_zero", {"zone": "deck", "card_type": "creature", "cost": 0, "definition_id": "str_nord_firebrand", "power": 1, "health": 1}),
		ScenarioFixtures.make_card(player_id, "first_zero", {"zone": "deck", "card_type": "creature", "cost": 0, "definition_id": "str_nord_firebrand", "power": 1, "health": 1}),
	]
	# Draw first 0-cost — triggers hunt, creates copy
	var draw1 := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw1.get("events", []))
	var hand_after_first: int = player.get("hand", []).size()
	# Draw second 0-cost — hunt is spent, no copy
	var draw2 := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw2.get("events", []))
	var hand: Array = player.get("hand", [])
	return _assert(hand.size() == hand_after_first + 1, "Second 0-cost draw should NOT create a copy (hunt spent).")


func _test_ratway_prospector_pack() -> bool:
	return (
		_test_ratway_prospector_treasure_hunt() and
		_test_ratway_prospector_cover_on_attack() and
		_test_ratway_prospector_cover_persists_each_attack()
	)


func _test_ratway_prospector_treasure_hunt() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var prospector := ScenarioFixtures.summon_creature(player, match_state, "ratway_th", "field", 1, 2, [], -1, {
		"definition_id": "cwc_str_ratway_prospector",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["support", "item", "action"], "effects": [{"op": "modify_stats", "target": "self", "power": 5, "health": 5}]},
			{"family": "on_attack", "required_zone": "lane", "effects": [{"op": "grant_status", "target": "self", "status_id": "cover"}]},
		],
	})
	# Stack deck: support, item, action — draws complete the multi-type hunt
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "deck_action", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(player_id, "deck_item", {"zone": "deck", "card_type": "item"}),
		ScenarioFixtures.make_card(player_id, "deck_support", {"zone": "deck", "card_type": "support"}),
	]
	# Draw 2 — partial match (support + item found, action still missing)
	var draw1 := MatchTiming.draw_cards(match_state, player_id, 2, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw1.get("events", []))
	if not _assert(EvergreenRules.get_power(prospector) == 1, "Hunt incomplete after 2 draws — power stays 1."):
		return false
	# Draw 3rd — action completes the hunt
	var draw2 := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw2.get("events", []))
	return (
		_assert(EvergreenRules.get_power(prospector) == 6, "Hunt complete: 1 + 5 = 6 power.") and
		_assert(EvergreenRules.get_health(prospector) == 7, "Hunt complete: 2 + 5 = 7 health.")
	)


func _test_ratway_prospector_cover_on_attack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var player_id := str(player.get("player_id", ""))
	var opponent_id := str(opponent.get("player_id", ""))
	var prospector := ScenarioFixtures.summon_creature(player, match_state, "ratway_cover", "field", 1, 2, [], -1, {
		"definition_id": "cwc_str_ratway_prospector",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["support", "item", "action"], "effects": [{"op": "modify_stats", "target": "self", "power": 5, "health": 5}]},
			{"family": "on_attack", "required_zone": "lane", "effects": [{"op": "grant_status", "target": "self", "status_id": "cover"}]},
		],
	})
	ScenarioFixtures.ready_for_attack(prospector, match_state)
	var dummy := _summon_generated_creature(match_state, opponent_id, "dummy_target", "field", 1, 1)
	# Verify no cover before attack
	if not _assert(not EvergreenRules.is_cover_active(match_state, prospector), "No cover before attacking."):
		return false
	# Attack
	var attack := MatchCombat.resolve_attack(match_state, player_id, str(prospector.get("instance_id", "")), {"type": "creature", "instance_id": str(dummy.get("instance_id", ""))})
	if not _assert(bool(attack.get("is_valid", false)), "Attack should resolve."):
		return false
	return _assert(EvergreenRules.is_cover_active(match_state, prospector), "Prospector should have cover after attacking.")


func _test_ratway_prospector_cover_persists_each_attack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var player_id := str(player.get("player_id", ""))
	var opponent_id := str(opponent.get("player_id", ""))
	var prospector := ScenarioFixtures.summon_creature(player, match_state, "ratway_multi", "field", 3, 5, [], -1, {
		"definition_id": "cwc_str_ratway_prospector",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["support", "item", "action"], "effects": [{"op": "modify_stats", "target": "self", "power": 5, "health": 5}]},
			{"family": "on_attack", "required_zone": "lane", "effects": [{"op": "grant_status", "target": "self", "status_id": "cover"}]},
		],
	})
	ScenarioFixtures.ready_for_attack(prospector, match_state)
	var dummy1 := _summon_generated_creature(match_state, opponent_id, "dummy1", "field", 1, 1)
	# First attack — gains cover
	MatchCombat.resolve_attack(match_state, player_id, str(prospector.get("instance_id", "")), {"type": "creature", "instance_id": str(dummy1.get("instance_id", ""))})
	if not _assert(EvergreenRules.is_cover_active(match_state, prospector), "Cover after first attack."):
		return false
	# Advance turns so cover expires and prospector can attack again
	MatchTurnLoop.end_turn(match_state, player_id)
	MatchTurnLoop.end_turn(match_state, opponent_id)
	if not _assert(not EvergreenRules.is_cover_active(match_state, prospector), "Cover should expire at start of next turn."):
		return false
	# Second attack — gains cover again
	var dummy2 := _summon_generated_creature(match_state, opponent_id, "dummy2", "field", 1, 1)
	var attack2 := MatchCombat.resolve_attack(match_state, player_id, str(prospector.get("instance_id", "")), {"type": "creature", "instance_id": str(dummy2.get("instance_id", ""))})
	if not _assert(bool(attack2.get("is_valid", false)), "Second attack should resolve."):
		return false
	return _assert(EvergreenRules.is_cover_active(match_state, prospector), "Cover should be re-granted after second attack.")


func _test_ruthless_freebooter_pack() -> bool:
	return (
		_test_ruthless_freebooter_drain_hunt() and
		_test_ruthless_freebooter_lethal_hunt() and
		_test_ruthless_freebooter_both_hunts_independent() and
		_test_ruthless_freebooter_spent_hunts_no_retrigger()
	)


func _test_ruthless_freebooter_drain_hunt() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var freebooter := ScenarioFixtures.summon_creature(player, match_state, "freebooter_drain", "field", 2, 2, [], -1, {
		"definition_id": "cwc_agi_ruthless_freebooter",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["drain"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}, {"op": "grant_keyword", "target": "self", "keyword_id": "drain"}]},
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["lethal"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}, {"op": "grant_keyword", "target": "self", "keyword_id": "lethal"}]},
		],
	})
	# Stack deck with a drain creature
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "drain_creature", {"zone": "deck", "card_type": "creature", "keywords": ["drain"]}),
	]
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	return (
		_assert(EvergreenRules.get_power(freebooter) == 3, "Drain hunt: 2 + 1 = 3 power.") and
		_assert(EvergreenRules.get_health(freebooter) == 3, "Drain hunt: 2 + 1 = 3 health.") and
		_assert(EvergreenRules.has_keyword(freebooter, "drain"), "Drain hunt grants drain keyword.")
	)


func _test_ruthless_freebooter_lethal_hunt() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var freebooter := ScenarioFixtures.summon_creature(player, match_state, "freebooter_lethal", "field", 2, 2, [], -1, {
		"definition_id": "cwc_agi_ruthless_freebooter",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["drain"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}, {"op": "grant_keyword", "target": "self", "keyword_id": "drain"}]},
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["lethal"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}, {"op": "grant_keyword", "target": "self", "keyword_id": "lethal"}]},
		],
	})
	# Stack deck with a lethal creature
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "lethal_creature", {"zone": "deck", "card_type": "creature", "keywords": ["lethal"]}),
	]
	var draw := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	return (
		_assert(EvergreenRules.get_power(freebooter) == 3, "Lethal hunt: 2 + 1 = 3 power.") and
		_assert(EvergreenRules.get_health(freebooter) == 3, "Lethal hunt: 2 + 1 = 3 health.") and
		_assert(EvergreenRules.has_keyword(freebooter, "lethal"), "Lethal hunt grants lethal keyword.")
	)


func _test_ruthless_freebooter_both_hunts_independent() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var freebooter := ScenarioFixtures.summon_creature(player, match_state, "freebooter_both", "field", 2, 2, [], -1, {
		"definition_id": "cwc_agi_ruthless_freebooter",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["drain"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}, {"op": "grant_keyword", "target": "self", "keyword_id": "drain"}]},
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["lethal"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}, {"op": "grant_keyword", "target": "self", "keyword_id": "lethal"}]},
		],
	})
	# Stack deck: drain creature first, then lethal creature
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "lethal_card", {"zone": "deck", "card_type": "creature", "keywords": ["lethal"]}),
		ScenarioFixtures.make_card(player_id, "drain_card", {"zone": "deck", "card_type": "creature", "keywords": ["drain"]}),
	]
	# Draw drain card — only drain hunt fires
	var draw1 := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw1.get("events", []))
	if not _assert(EvergreenRules.get_power(freebooter) == 3, "After drain draw: 2 + 1 = 3 power."):
		return false
	if not _assert(EvergreenRules.has_keyword(freebooter, "drain"), "Has drain after first draw."):
		return false
	if not _assert(not EvergreenRules.has_keyword(freebooter, "lethal"), "No lethal yet after first draw."):
		return false
	# Draw lethal card — lethal hunt fires independently
	var draw2 := MatchTiming.draw_cards(match_state, player_id, 1, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw2.get("events", []))
	return (
		_assert(EvergreenRules.get_power(freebooter) == 4, "After both hunts: 2 + 1 + 1 = 4 power.") and
		_assert(EvergreenRules.get_health(freebooter) == 4, "After both hunts: 2 + 1 + 1 = 4 health.") and
		_assert(EvergreenRules.has_keyword(freebooter, "drain"), "Still has drain.") and
		_assert(EvergreenRules.has_keyword(freebooter, "lethal"), "Now has lethal too.")
	)


func _test_ruthless_freebooter_spent_hunts_no_retrigger() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var freebooter := ScenarioFixtures.summon_creature(player, match_state, "freebooter_spent", "field", 2, 2, [], -1, {
		"definition_id": "cwc_agi_ruthless_freebooter",
		"triggered_abilities": [
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["drain"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}, {"op": "grant_keyword", "target": "self", "keyword_id": "drain"}]},
			{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["lethal"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}, {"op": "grant_keyword", "target": "self", "keyword_id": "lethal"}]},
		],
	})
	# Stack deck: drain, lethal, then another drain
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "extra_drain", {"zone": "deck", "card_type": "creature", "keywords": ["drain"]}),
		ScenarioFixtures.make_card(player_id, "lethal_card", {"zone": "deck", "card_type": "creature", "keywords": ["lethal"]}),
		ScenarioFixtures.make_card(player_id, "drain_card", {"zone": "deck", "card_type": "creature", "keywords": ["drain"]}),
	]
	# Draw all 3 — drain and lethal complete, extra drain does nothing
	var draw := MatchTiming.draw_cards(match_state, player_id, 3, {"reason": "test", "source_controller_player_id": player_id})
	MatchTiming.publish_events(match_state, draw.get("events", []))
	return (
		_assert(EvergreenRules.get_power(freebooter) == 4, "Spent hunts: 2 + 1 + 1 = 4 power (no extra from 2nd drain).") and
		_assert(EvergreenRules.get_health(freebooter) == 4, "Spent hunts: 2 + 1 + 1 = 4 health (no extra from 2nd drain).")
	)


func _test_treasure_map_pack() -> bool:
	return (
		_test_treasure_map_finds_hunt_match() and
		_test_treasure_map_no_hunt_draws_top() and
		_test_treasure_map_spent_hunt_draws_top() and
		_test_treasure_map_multi_type_only_unfound() and
		_test_treasure_map_keyword_hunt() and
		_test_treasure_map_zero_cost_hunt() and
		_test_treasure_map_removes_from_deck() and
		_test_treasure_map_count_based_hunt()
	)


## Helper: add Treasure Map to player hand with proper item definition
func _add_treasure_map_to_hand(player: Dictionary) -> Dictionary:
	var player_id := str(player.get("player_id", ""))
	return ScenarioFixtures.add_hand_card(player, "treasure_map", {
		"definition_id": "cwc_neu_treasure_map",
		"card_type": "item",
		"cost": 3,
		"equip_power_bonus": 1,
		"equip_health_bonus": 1,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "draw_or_treasure_hunt", "target": "wielder"}]}],
	})


func _test_treasure_map_finds_hunt_match() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon creature with Treasure Hunt - Item
	var hunter := ScenarioFixtures.summon_creature(player, match_state, "item_hunter", "field", 3, 2, [], -1, {
		"definition_id": "cwc_str_relic_hunter",
		"triggered_abilities": [{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["item"], "effects": [{"op": "modify_stats", "target": "treasure_card", "power": 1, "health": 1}]}],
	})
	# Stack deck: creature on top, item buried underneath
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "buried_item", {"zone": "deck", "card_type": "item", "cost": 2}),
		ScenarioFixtures.make_card(player_id, "top_creature", {"zone": "deck", "card_type": "creature", "cost": 1}),
	]
	var hand_before: int = player.get("hand", []).size()
	var tm := _add_treasure_map_to_hand(player)
	var result := PersistentCardRules.play_item_from_hand(match_state, player_id, str(tm.get("instance_id", "")), {"target_instance_id": str(hunter.get("instance_id", ""))})
	if not _assert(bool(result.get("is_valid", false)), "Treasure Map play should be valid."):
		return false
	# Should have drawn the buried item (not the top creature)
	var hand: Array = player.get("hand", [])
	var found_item := false
	for card in hand:
		if str(card.get("instance_id", "")).ends_with("buried_item"):
			found_item = true
			break
	return _assert(found_item, "Treasure Map should draw matching item from deck, not top card.")


func _test_treasure_map_no_hunt_draws_top() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon a plain creature with no treasure hunt
	var plain := ScenarioFixtures.summon_creature(player, match_state, "plain_creature", "field", 2, 2)
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "bottom_card", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(player_id, "top_card", {"zone": "deck", "card_type": "creature"}),
	]
	var tm := _add_treasure_map_to_hand(player)
	PersistentCardRules.play_item_from_hand(match_state, player_id, str(tm.get("instance_id", "")), {"target_instance_id": str(plain.get("instance_id", ""))})
	var hand: Array = player.get("hand", [])
	var found_top := false
	for card in hand:
		if str(card.get("instance_id", "")).ends_with("top_card"):
			found_top = true
			break
	return _assert(found_top, "With no treasure hunt, Treasure Map should draw from top of deck.")


func _test_treasure_map_spent_hunt_draws_top() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon creature with spent treasure hunt
	var hunter := ScenarioFixtures.summon_creature(player, match_state, "spent_hunter", "field", 3, 2, [], -1, {
		"definition_id": "cwc_str_relic_hunter",
		"triggered_abilities": [{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["item"], "effects": [{"op": "modify_stats", "target": "treasure_card", "power": 1, "health": 1}]}],
	})
	hunter["_th_0_spent"] = true
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "buried_item", {"zone": "deck", "card_type": "item"}),
		ScenarioFixtures.make_card(player_id, "top_creature", {"zone": "deck", "card_type": "creature"}),
	]
	var tm := _add_treasure_map_to_hand(player)
	PersistentCardRules.play_item_from_hand(match_state, player_id, str(tm.get("instance_id", "")), {"target_instance_id": str(hunter.get("instance_id", ""))})
	var hand: Array = player.get("hand", [])
	var found_top := false
	for card in hand:
		if str(card.get("instance_id", "")).ends_with("top_creature"):
			found_top = true
			break
	return _assert(found_top, "With spent treasure hunt, Treasure Map should draw from top.")


func _test_treasure_map_multi_type_only_unfound() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon Ratway Prospector with multi-type hunt (support, item, action)
	# Mark support and item as already found — only action remains
	var hunter := ScenarioFixtures.summon_creature(player, match_state, "ratway", "field", 1, 2, [], -1, {
		"definition_id": "cwc_str_ratway_prospector",
		"triggered_abilities": [{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["support", "item", "action"], "effects": [{"op": "modify_stats", "target": "self", "power": 5, "health": 5}]}],
	})
	hunter["_th_0_found"] = ["support", "item"]
	# Deck: support on bottom (already found type), action buried, creature on top
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "support_card", {"zone": "deck", "card_type": "support"}),
		ScenarioFixtures.make_card(player_id, "action_card", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(player_id, "top_creature", {"zone": "deck", "card_type": "creature"}),
	]
	var tm := _add_treasure_map_to_hand(player)
	PersistentCardRules.play_item_from_hand(match_state, player_id, str(tm.get("instance_id", "")), {"target_instance_id": str(hunter.get("instance_id", ""))})
	var hand: Array = player.get("hand", [])
	var found_action := false
	for card in hand:
		if str(card.get("instance_id", "")).ends_with("action_card"):
			found_action = true
			break
	return _assert(found_action, "Multi-type hunt: should draw the unfound action type, not support or top.")


func _test_treasure_map_keyword_hunt() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon creature hunting for drain keyword
	var hunter := ScenarioFixtures.summon_creature(player, match_state, "drain_hunter", "field", 2, 2, [], -1, {
		"triggered_abilities": [{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["drain"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}]}],
	})
	# Deck: non-drain on top, drain buried
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "drain_creature", {"zone": "deck", "card_type": "creature", "keywords": ["drain"]}),
		ScenarioFixtures.make_card(player_id, "top_vanilla", {"zone": "deck", "card_type": "creature"}),
	]
	var tm := _add_treasure_map_to_hand(player)
	PersistentCardRules.play_item_from_hand(match_state, player_id, str(tm.get("instance_id", "")), {"target_instance_id": str(hunter.get("instance_id", ""))})
	var hand: Array = player.get("hand", [])
	var found_drain := false
	for card in hand:
		if str(card.get("instance_id", "")).ends_with("drain_creature"):
			found_drain = true
			break
	return _assert(found_drain, "Keyword hunt: should find drain creature buried in deck.")


func _test_treasure_map_zero_cost_hunt() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon creature hunting for zero-cost cards
	var hunter := ScenarioFixtures.summon_creature(player, match_state, "zero_hunter", "field", 4, 2, [], -1, {
		"triggered_abilities": [{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["zero_cost"], "effects": [{"op": "generate_card_to_hand", "target": "treasure_card_copy"}]}],
	})
	# Deck: cost-3 on top, zero-cost buried
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "zero_cost_card", {"zone": "deck", "card_type": "creature", "cost": 0}),
		ScenarioFixtures.make_card(player_id, "top_expensive", {"zone": "deck", "card_type": "creature", "cost": 3}),
	]
	var tm := _add_treasure_map_to_hand(player)
	PersistentCardRules.play_item_from_hand(match_state, player_id, str(tm.get("instance_id", "")), {"target_instance_id": str(hunter.get("instance_id", ""))})
	var hand: Array = player.get("hand", [])
	var found_zero := false
	for card in hand:
		if str(card.get("instance_id", "")).ends_with("zero_cost_card"):
			found_zero = true
			break
	return _assert(found_zero, "Zero-cost hunt: should find 0-cost card buried in deck.")


func _test_treasure_map_removes_from_deck() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var hunter := ScenarioFixtures.summon_creature(player, match_state, "rem_hunter", "field", 3, 2, [], -1, {
		"triggered_abilities": [{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["item"], "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}]}],
	})
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "only_item", {"zone": "deck", "card_type": "item"}),
		ScenarioFixtures.make_card(player_id, "top_creature", {"zone": "deck", "card_type": "creature"}),
	]
	if not _assert(player["deck"].size() == 2, "Deck starts with 2 cards."):
		return false
	var tm := _add_treasure_map_to_hand(player)
	PersistentCardRules.play_item_from_hand(match_state, player_id, str(tm.get("instance_id", "")), {"target_instance_id": str(hunter.get("instance_id", ""))})
	# Deck should have 1 card left (the creature), item was removed and moved to hand
	return _assert(player["deck"].size() == 1, "Drawn card should be removed from deck (1 card left).")


func _test_treasure_map_count_based_hunt() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Scroll Seeker: hunt_count 2 actions, still hunting for action type
	var hunter := ScenarioFixtures.summon_creature(player, match_state, "scroll_seeker", "field", 1, 2, [], -1, {
		"triggered_abilities": [{"family": "treasure_hunt", "required_zone": "lane", "hunt_types": ["action"], "hunt_count": 2, "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}]}],
	})
	# Deck: creature on top, action buried
	player["deck"] = [
		ScenarioFixtures.make_card(player_id, "buried_action", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(player_id, "top_creature", {"zone": "deck", "card_type": "creature"}),
	]
	var tm := _add_treasure_map_to_hand(player)
	PersistentCardRules.play_item_from_hand(match_state, player_id, str(tm.get("instance_id", "")), {"target_instance_id": str(hunter.get("instance_id", ""))})
	var hand: Array = player.get("hand", [])
	var found_action := false
	for card in hand:
		if str(card.get("instance_id", "")).ends_with("buried_action"):
			found_action = true
			break
	return _assert(found_action, "Count-based hunt: should find action even when hunt_count > 1.")


func _test_choose_cost_lock_blocks_opponent_summon() -> bool:
	var match_state := _build_started_match()
	var p1: Dictionary = ScenarioFixtures.player(match_state, 0)
	var p2: Dictionary = ScenarioFixtures.player(match_state, 1)
	var p1_id := str(p1.get("player_id", ""))
	var p2_id := str(p2.get("player_id", ""))
	# Summon a creature with choose_cost_lock
	var darkfire := ScenarioFixtures.add_hand_card(p1, "darkfire", {
		"card_type": "creature",
		"cost": 0,
		"power": 7,
		"health": 7,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "lane",
			"effects": [{"op": "choose_cost_lock", "target_player": "opponent"}],
		}],
	})
	LaneRules.summon_from_hand(match_state, p1_id, str(darkfire.get("instance_id", "")), "field")
	if not _assert(MatchTiming.has_pending_player_choice(match_state, p1_id), "Should have pending choice after summoning cost lock creature."):
		return false
	# Select cost 1 (index 1 in options ["0","1","2",...])
	var resolve_result := MatchTiming.resolve_pending_player_choice(match_state, p1_id, 1)
	if not _assert(bool(resolve_result.get("is_valid", false)), "Resolving cost lock choice should succeed."):
		return false
	# Verify the lock is on p2
	var p2_locks: Array = p2.get("cost_locks", [])
	if not _assert(p2_locks.size() == 1 and int(p2_locks[0].get("cost", -1)) == 1, "Opponent should have cost lock for cost 1."):
		return false
	# Opponent tries to summon a cost-1 creature — should fail
	var blocked_creature := ScenarioFixtures.add_hand_card(p2, "blocked_imp", {
		"card_type": "creature",
		"cost": 1,
		"power": 1,
		"health": 1,
	})
	var blocked_result := LaneRules.validate_summon_from_hand(match_state, p2_id, str(blocked_creature.get("instance_id", "")), "field")
	return _assert(not bool(blocked_result.get("is_valid", true)), "Opponent should NOT be able to summon cost-1 creature when cost 1 is locked.")


func _test_choose_cost_lock_allows_different_cost() -> bool:
	var match_state := _build_started_match()
	var p1: Dictionary = ScenarioFixtures.player(match_state, 0)
	var p2: Dictionary = ScenarioFixtures.player(match_state, 1)
	var p1_id := str(p1.get("player_id", ""))
	var p2_id := str(p2.get("player_id", ""))
	# Summon and lock cost 1
	var darkfire := ScenarioFixtures.add_hand_card(p1, "darkfire2", {
		"card_type": "creature",
		"cost": 0,
		"power": 7,
		"health": 7,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "lane",
			"effects": [{"op": "choose_cost_lock", "target_player": "opponent"}],
		}],
	})
	LaneRules.summon_from_hand(match_state, p1_id, str(darkfire.get("instance_id", "")), "field")
	MatchTiming.resolve_pending_player_choice(match_state, p1_id, 1)
	# Opponent summons a cost-2 creature — should succeed
	var allowed_creature := ScenarioFixtures.add_hand_card(p2, "allowed_bear", {
		"card_type": "creature",
		"cost": 2,
		"power": 2,
		"health": 2,
	})
	var allowed_result := LaneRules.validate_summon_from_hand(match_state, p2_id, str(allowed_creature.get("instance_id", "")), "field")
	return _assert(bool(allowed_result.get("is_valid", false)), "Opponent SHOULD be able to summon cost-2 creature when cost 1 is locked.")


func _build_started_match() -> Dictionary:
	return ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 0})


func _summon_generated_creature(match_state: Dictionary, player_id: String, label: String, lane_id: String, power: int, health: int) -> Dictionary:
	var card := ScenarioFixtures.make_card(player_id, label, {"zone": MatchMutations.ZONE_GENERATED, "card_type": "creature", "cost": 0, "power": power, "health": health})
	var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, card, lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
	return summon_result.get("card", {})


func _find_lane_card(match_state: Dictionary, lane_id: String, player_id: String, definition_id: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == definition_id:
				return card
	return {}


func _card_in_zone(match_state: Dictionary, instance_id: String, zone: String) -> bool:
	var location := MatchMutations.find_card_location(match_state, instance_id)
	return bool(location.get("is_valid", false)) and str(location.get("zone", "")) == zone


func _contains_instance(cards: Array, instance_id: String) -> bool:
	for card in cards:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
			return true
	return false


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false