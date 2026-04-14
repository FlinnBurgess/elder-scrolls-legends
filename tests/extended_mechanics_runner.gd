extends SceneTree

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchTargeting = preload("res://src/core/match/match_targeting.gd")
const MatchAuras = preload("res://src/core/match/match_auras.gd")
const MatchTriggers = preload("res://src/core/match/match_triggers.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const EffectSacrifice = preload("res://src/core/match/effects/effect_sacrifice.gd")
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
		_test_beast_form_change_fires_summon_and_preserves_buffs() and
		_test_beast_form_targeted_summon_fires_immediately() and
		_test_beast_form_targeted_summon_defers_on_controller_turn() and
		_test_set_power_with_duration_expires() and
		_test_set_power_duration_cleared_on_change() and
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
		_test_optional_consume_for_keyword_grants_drain() and
		_test_treasure_hunt_count_based() and
		_test_wax_and_wane_pack() and
		_test_dual_wax_wane() and
		_test_wax_creature_turn_trigger() and
		_test_on_friendly_wax_target_mode() and
		_test_aldora_the_daring_pack() and
		_test_mistveil_warden_pack() and
		_test_murkwater_guide_pack() and
		_test_ratway_prospector_pack() and
		_test_ruthless_freebooter_pack() and
		_test_treasure_map_pack() and
		_test_choose_cost_lock_blocks_opponent_summon() and
		_test_choose_cost_lock_allows_different_cost() and
		_test_filter_unique_cost_reduction() and
		_test_guess_opponent_card_varies_per_instance() and
		_test_unstoppable_rage_deal_damage_to_lane() and
		_test_dark_rebirth_sacrifice_and_resummon() and
		_test_recall_and_resummon_preserves_state_triggers_summon() and
		_test_trial_of_flame_destroy_all_except_strongest() and
		_test_vivec_cannot_lose_expires_on_exalted_death() and
		_test_vivec_cannot_lose_expires_on_silence() and
		_test_stampede_sentinel_blocks_action_damage_to_player() and
		_test_stampede_sentinel_does_not_block_combat_damage_to_player() and
		_test_battle_self_single_destruction() and
		_test_playing_card_mutation_and_summon() and
		_test_madness_beckons_generates_iom_card() and
		_test_play_prophecy_from_hand_opens_prophecy_window() and
		_test_required_friendly_attribute_count_neutral() and
		_test_required_friendly_attribute_count_not_met_blocks_target() and
		_test_summon_from_hand_to_full_lane_auto_summons() and
		_test_consume_and_reduce_matching_subtype_cost() and
		_test_adoring_fan_death_sets_return_timer() and
		_test_adoring_fan_returns_after_timer_expires() and
		_test_adoring_fan_non_death_discard_has_no_timer() and
		_test_adoring_fan_waits_when_lanes_full() and
		_test_upgrade_chain_summon_advances_and_caps() and
		_test_upgrade_chain_overflows_to_other_lane() and
		_test_summon_from_effect_overflows_to_other_lane() and
		_test_reanimate_action_summons_from_discard() and
		_test_summon_from_discard_exact_cost_filter() and
		_test_monster_perfection_lab_equips_item_from_deck() and
		_test_monster_perfection_lab_no_trigger_without_3_items() and
		_test_monster_perfection_lab_decline_keeps_lab() and
		_test_ultimate_heist_drops_hp_to_rune_threshold() and
		_test_ultimate_heist_stolen_prophecy_opens_window() and
		_test_ultimate_heist_no_runes_kills_opponent() and
		_test_ruin_shambler_consume_only_this_turn_with_buff_per_consumed() and
		_test_dro_mathra_reaper_on_discard_leave_triggers() and
		_test_transform_deck_preserves_definition_id_and_art_path() and
		_test_conditional_drawn_card_bonus_sets_base_cost() and
		_test_banish_by_name_from_opponent() and
		_test_double_max_magicka_gain_works_on_first_gain() and
		_test_magicka_aura_visible_to_aura_conditions() and
		_test_grant_keyword_to_all_copies_spreads_to_hand_and_deck() and
		_test_haskill_random_cost_trigger_draws_on_match() and
		_test_haskill_random_cost_trigger_no_draw_on_mismatch() and
		_test_shuffle_into_deck_respects_count() and
		_test_on_friendly_summon_copy_no_infinite_loop() and
		_test_hannibal_traven_learn_and_last_gasp_queues_free_plays() and
		_test_sotha_sil_end_of_turn_summons_imperfect_with_exalted() and
		_test_renegade_magister_doubles_action_damage() and
		_test_renegade_magister_aoe_doubles_each_target() and
		_test_renegade_magister_no_loop_on_own_damage() and
		_test_renegade_magister_ignores_friendly_creature_damage() and
		_test_delayed_destroy_fires_at_start_of_turn() and
		_test_consume_and_copy_veteran_single_consume_then_copies_ability() and
		_test_consume_and_copy_veteran_fires_on_veteran_trigger() and
		_test_strange_brew_transforms_hand_creature_with_cost_reduction() and
		_test_optional_discard_and_summon_discards_and_summons_to_other_lane() and
		_test_blind_moth_priest_glow_flag() and
		_test_emperors_attendant_hand_selection_modify_stats() and
		_test_sacrifice_and_absorb_stats_uses_remaining_health() and
		_test_forsaken_champion_aura_from_targeted_creature() and
		_test_all_other_enemies_excludes_chosen_target() and
		_test_drain_action_does_not_double_heal() and
		_test_equip_random_item_fires_on_play_effects() and
		_test_unicorn_aura_only_grants_charge_to_lower_power() and
		_test_heretic_conjurer_pilfer_transforms_summoned_to_daedra() and
		_test_heretic_conjurer_transform_clears_gate_restrictions() and
		_test_equip_from_effect_does_not_trigger_expertise() and
		_test_shackle_immune_clears_existing_shackle() and
		_test_shackle_immune_blocks_new_shackle() and
		_test_multi_battle_summon_fires_two_sequential_battles() and
		_test_multi_battle_summon_skips_second_if_source_dies() and
		_test_discard_from_hand_filter_picks_highest_cost_action()
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
				"op": "change",
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


func _test_beast_form_change_fires_summon_and_preserves_buffs() -> bool:
	# Beast Form uses "change" (not "transform"), so:
	# 1) The werewolf form's summon ability should fire (e.g. draw a card)
	# 2) Existing buffs should be preserved after the change
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	# Werewolf form has a summon: draw a card
	var beast := ScenarioFixtures.summon_creature(player, match_state, "huntmate", "field", 3, 3, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"match_role": "opponent_player",
			"required_zone": "lane",
			"effects": [{
				"op": "change",
				"target": "self",
				"card_template": {
					"definition_id": "huntmate_werewolf",
					"name": "Huntmate Werewolf",
					"card_type": "creature",
					"power": 4, "health": 4,
					"triggered_abilities": [{"family": "summon", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 1}]}],
				},
			}],
		}],
	})
	# Apply a +2/+2 buff before the change
	EvergreenRules.apply_stat_bonus(beast, 2, 2)
	var hand_before: int = (player.get("hand", []) as Array).size()
	var damage_result := MatchTiming.apply_player_damage(match_state, str(opponent.get("player_id", "")), 6, {
		"source_instance_id": str(beast.get("instance_id", "")),
		"source_controller_player_id": str(player.get("player_id", "")),
	})
	MatchTiming.publish_events(match_state, damage_result.get("events", []))
	var hand_after: int = (player.get("hand", []) as Array).size()
	return (
		_assert(str(beast.get("definition_id", "")) == "huntmate_werewolf", "Beast should change into werewolf form.") and
		_assert(hand_after > hand_before, "Werewolf summon ability (draw a card) should fire after Beast Form change.") and
		_assert(EvergreenRules.get_power(beast) == 6, "Changed beast should have 4 base + 2 buff = 6 power.") and
		_assert(EvergreenRules.get_health(beast) == 6, "Changed beast should have 4 base + 2 buff = 6 health.")
	)


func _test_beast_form_targeted_summon_fires_immediately() -> bool:
	# When a beast form creature transforms on the OPPONENT's turn (rune break
	# while the opponent attacks), the targeted summon should auto-resolve
	# immediately since the controller can't interact.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	# Make it the OPPONENT's turn so auto-pick kicks in
	match_state["active_player_id"] = str(opponent.get("player_id", ""))
	# Summon an enemy creature that the werewolf's summon will target
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_target", "field", 2, 3)
	# Wound the enemy so it qualifies for "destroy a wounded enemy creature"
	EvergreenRules.apply_damage_to_creature(enemy, 1)
	# Create a beast form creature with a targeted summon: destroy a wounded enemy
	var beast := ScenarioFixtures.summon_creature(player, match_state, "aela_test", "field", 3, 3, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"match_role": "opponent_player",
			"required_zone": "lane",
			"effects": [{
				"op": "change",
				"target": "self",
				"card_template": {
					"definition_id": "aela_werewolf",
					"name": "Aela Werewolf",
					"card_type": "creature",
					"power": 5, "health": 5,
					"triggered_abilities": [{"family": "summon", "target_mode": "wounded_enemy_creature", "effects": [{"op": "destroy_creature", "target": "chosen_target"}]}],
				},
			}],
		}],
	})
	# Break opponent rune to trigger beast form (on opponent's turn)
	var damage_result := MatchTiming.apply_player_damage(match_state, str(opponent.get("player_id", "")), 6, {
		"source_instance_id": str(beast.get("instance_id", "")),
		"source_controller_player_id": str(player.get("player_id", "")),
	})
	MatchTiming.publish_events(match_state, damage_result.get("events", []))
	# The enemy creature should be destroyed immediately — no pending target
	var enemy_zone := str(enemy.get("zone", ""))
	var has_pending := MatchTiming.has_pending_summon_effect_target(match_state, str(player.get("player_id", "")))
	return (
		_assert(str(beast.get("definition_id", "")) == "aela_werewolf", "Beast should transform into werewolf form.") and
		_assert(enemy_zone == "discard", "Wounded enemy should be destroyed immediately by beast form summon, got zone: %s." % enemy_zone) and
		_assert(not has_pending, "There should be no pending summon effect targets — the targeted summon should have resolved immediately.")
	)


func _test_beast_form_targeted_summon_defers_on_controller_turn() -> bool:
	# When a beast form creature transforms on its CONTROLLER's turn (e.g. player
	# attacks, breaks a rune, triggers beast form), the targeted summon should
	# defer to let the player choose a target via the UI.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	# active_player_id is already player (first_player_index: 0)
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_target", "field", 2, 3)
	EvergreenRules.apply_damage_to_creature(enemy, 1)
	var beast := ScenarioFixtures.summon_creature(player, match_state, "aela_test", "field", 3, 3, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"match_role": "opponent_player",
			"required_zone": "lane",
			"effects": [{
				"op": "change",
				"target": "self",
				"card_template": {
					"definition_id": "aela_werewolf",
					"name": "Aela Werewolf",
					"card_type": "creature",
					"power": 5, "health": 5,
					"triggered_abilities": [{"family": "summon", "target_mode": "wounded_enemy_creature", "effects": [{"op": "destroy_creature", "target": "chosen_target"}]}],
				},
			}],
		}],
	})
	var damage_result := MatchTiming.apply_player_damage(match_state, str(opponent.get("player_id", "")), 6, {
		"source_instance_id": str(beast.get("instance_id", "")),
		"source_controller_player_id": pid,
	})
	MatchTiming.publish_events(match_state, damage_result.get("events", []))
	# Enemy should still be alive — destruction deferred pending player choice
	var enemy_zone := str(enemy.get("zone", ""))
	var has_pending := MatchTiming.has_pending_summon_effect_target(match_state, pid)
	return (
		_assert(str(beast.get("definition_id", "")) == "aela_werewolf", "Beast should transform into werewolf form.") and
		_assert(enemy_zone == "lane", "Wounded enemy should NOT be destroyed yet — waiting for player targeting, got zone: %s." % enemy_zone) and
		_assert(has_pending, "There should be a pending summon effect target for the player to choose.")
	)


func _test_set_power_with_duration_expires() -> bool:
	# set_power with duration "start_of_next_turn" should expire at end of turn.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	# Summon Shrine Guardian (player's creature)
	ScenarioFixtures.summon_creature(player, match_state, "shrine_guardian_test", "field", 8, 8, [EvergreenRules.KEYWORD_GUARD], -1, {
		"triggered_abilities": [{
			"family": "on_enemy_summon",
			"required_zone": "lane",
			"effects": [{"op": "set_power", "target": "event_summoned_creature", "value": 0, "duration": "start_of_next_turn"}],
		}],
	})
	# Summon an enemy creature — should have its power reduced to 0
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_creature", "field", 4, 3)
	var power_after_summon := EvergreenRules.get_power(enemy)
	if not _assert(power_after_summon == 0, "Enemy creature should have power set to 0 after summon (got %d)." % power_after_summon):
		return false
	# End the turn — temporary bonus should be cleared
	MatchTurnLoop.end_turn(match_state, pid)
	var power_after_turn_end := EvergreenRules.get_power(enemy)
	return _assert(power_after_turn_end == 4, "Enemy creature power should revert to 4 after turn ends (got %d)." % power_after_turn_end)


func _test_set_power_duration_cleared_on_change() -> bool:
	# When a creature has a temporary set_power debuff and then transforms via
	# beast form (change), the temp debuff should be cleared as part of the
	# change — the creature is becoming a new form and temp effects don't carry.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Shrine Guardian (player's creature) with on_enemy_summon → set power 0
	ScenarioFixtures.summon_creature(player, match_state, "shrine_guardian_test", "field", 8, 8, [EvergreenRules.KEYWORD_GUARD], -1, {
		"triggered_abilities": [{
			"family": "on_enemy_summon",
			"required_zone": "lane",
			"effects": [{"op": "set_power", "target": "event_summoned_creature", "value": 0, "duration": "start_of_next_turn"}],
		}],
	})
	# Summon Aela during opponent's turn — Shrine Guardian debuffs her
	match_state["active_player_id"] = oid
	var aela := ScenarioFixtures.summon_creature(opponent, match_state, "aela_test", "field", 3, 3, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"match_role": "opponent_player",
			"required_zone": "lane",
			"effects": [{
				"op": "change",
				"target": "self",
				"card_template": {
					"definition_id": "aela_werewolf",
					"name": "Aela Werewolf",
					"card_type": "creature",
					"power": 5, "health": 5,
					"triggered_abilities": [],
				},
			}],
		}],
	})
	if not _assert(EvergreenRules.get_power(aela) == 0, "Aela should be debuffed to 0 power after summon."):
		return false
	# Break PLAYER's rune to trigger Aela's beast form (match_role "opponent_player"
	# means Aela fires when her controller's opponent = player has a rune broken).
	var damage_result := MatchTiming.apply_player_damage(match_state, pid, 6, {
		"source_instance_id": str(aela.get("instance_id", "")),
		"source_controller_player_id": oid,
	})
	MatchTiming.publish_events(match_state, damage_result.get("events", []))
	var power_after_change := EvergreenRules.get_power(aela)
	return (
		_assert(str(aela.get("definition_id", "")) == "aela_werewolf", "Aela should have changed to werewolf form.") and
		_assert(power_after_change == 5, "Aela werewolf should have 5 power — temp debuff cleared by change (got %d)." % power_after_change)
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
	# Mystic of Ancient Rites: empower bonuses persist for actions IN HAND only, not deck
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon a creature with permanent_empower passive
	ScenarioFixtures.summon_creature(player, match_state, "mystic", "field", 2, 3, [], -1, {
		"passive_abilities": [{"type": "permanent_empower"}],
	})
	# Add an empower action to hand BEFORE dealing damage (so it's in hand during turn end)
	var storm_in_hand := ScenarioFixtures.add_hand_card(player, "perm_storm_hand", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "event_target", "amount": 3, "empower_bonus": 1}]}]})
	# Deal damage twice = empower count 2
	for i in range(2):
		var ping := ScenarioFixtures.add_hand_card(player, "ping_perm_%d" % i, {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
		MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": oid})
	# End turn (empower_count=2 should be stamped onto hand action cards as _permanent_empower_bonus)
	MatchTurnLoop.end_turn(match_state, pid)
	MatchTurnLoop.end_turn(match_state, oid)
	# New turn: empower_count_this_turn reset to 0
	var empower_count := int(player.get("empower_count_this_turn", 0))
	var card_bonus := int(storm_in_hand.get("_permanent_empower_bonus", 0))
	# Deal 1 more damage this turn = empower count 1, total empower for hand card = 1 + 2 = 3
	var ping_new := ScenarioFixtures.add_hand_card(player, "ping_perm_new", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping_new.get("instance_id", "")), {"target_player_id": oid})
	# Play the hand card: base 3 + empower_bonus 1 * (1 this turn + 2 permanent) = 6 damage
	var target := _summon_generated_creature(match_state, oid, "perm_target", "field", 1, 10)
	MatchTiming.play_action_from_hand(match_state, pid, str(storm_in_hand.get("instance_id", "")), {"target_instance_id": str(target.get("instance_id", ""))})
	var target_health := EvergreenRules.get_remaining_health(target)
	# Now test that a card NOT in hand during the turn end does NOT get permanent bonus
	var target2 := _summon_generated_creature(match_state, oid, "perm_target2", "field", 1, 10)
	var storm_from_deck := ScenarioFixtures.add_hand_card(player, "perm_storm_deck", {"card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "event_target", "amount": 3, "empower_bonus": 1}]}]})
	MatchTiming.play_action_from_hand(match_state, pid, str(storm_from_deck.get("instance_id", "")), {"target_instance_id": str(target2.get("instance_id", ""))})
	var target2_health := EvergreenRules.get_remaining_health(target2)
	return (
		_assert(empower_count == 0, "Empower count should reset to 0 at start of new turn, got %d." % empower_count) and
		_assert(card_bonus == 2, "Hand card should have _permanent_empower_bonus=2 from previous turn, got %d." % card_bonus) and
		_assert(target_health == 4, "Hand card: base 3 + (1+2) empower = 6 damage, 10hp should have 4hp, got %d." % target_health) and
		_assert(target2_health == 6, "Deck card: base 3 + 1 empower (no permanent) = 4 damage, 10hp should have 6hp, got %d." % target2_health)
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
	var l5_ok := l5_text.find("2 random keywords") != -1
	return (
		_assert(l1_ok, "Level 1 gate rules_text should mention +0/+1 (got: %s)." % [l1_text]) and
		_assert(l2_ok, "Level 2 gate rules_text should mention +1/+1 without cost reduction (got: %s)." % [l2_text]) and
		_assert(l3_ok, "Level 3 gate rules_text should mention cost reduction without keywords (got: %s)." % [l3_text]) and
		_assert(has_daedra_aura, "Level 3 gate should add a Daedra cost reduction aura to match_state.") and
		_assert(daedra_effective_cost == 4, "Daedra in hand should cost 1 less with level 3+ gate (got: %d)." % [daedra_effective_cost]) and
		_assert(non_daedra_effective_cost == 5, "Non-Daedra should not get cost reduction (got: %d)." % [non_daedra_effective_cost]) and
		_assert(l4_ok, "Level 4 gate rules_text should mention 'a random keyword' (got: %s)." % [l4_text]) and
		_assert(l5_ok, "Level 5 gate rules_text should mention '2 random keywords' (got: %s)." % [l5_text]) and
		_assert(int(gate.get("health", 0)) == 12, "Level 5 gate should have health 12 (4 + 4*2) (got: %d)." % [int(gate.get("health", 0))])
	)


func _test_invade_gate_level_capped_at_five() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Create 12 invade actions to go well past old level 5 cap
	var invade_cards: Array = []
	for i in range(12):
		invade_cards.append(ScenarioFixtures.add_hand_card(player, "cap_invade_%d" % i, {
			"card_type": "action",
			"cost": 0,
			"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
		}))
	for card in invade_cards:
		MatchTiming.play_action_from_hand(match_state, pid, str(card.get("instance_id", "")))
	var gate := _find_lane_card(match_state, "shadow", pid, "generated_oblivion_gate")
	var gate_level := int(gate.get("gate_level", 0))
	# Summon a Daedra to check keyword count (capped at 8 = pool size)
	var daedra := ScenarioFixtures.summon_creature(player, match_state, "cap_daedra", "field", 1, 1, [], -1, {"subtypes": ["Daedra"]})
	var granted: Array = daedra.get("granted_keywords", [])
	return (
		_assert(gate_level == 12, "Gate level should be uncapped (got: %d)." % [gate_level]) and
		_assert(granted.size() == 8, "Summoned Daedra should get at most 8 keywords (pool size) from high-level gate (got: %d)." % [granted.size()])
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


func _test_optional_consume_for_keyword_grants_drain() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var player_id := str(player.get("player_id", ""))
	var opponent_id := str(opponent.get("player_id", ""))
	var fledgling := ScenarioFixtures.summon_creature(player, match_state, "fledgling", "field", 4, 3, [], -1, {
		"triggered_abilities": [{"family": "start_of_turn", "required_zone": "lane", "effects": [{"op": "optional_consume_for_keyword", "target": "self", "keyword_id": "drain", "duration": "end_of_turn"}]}],
	})
	var meal := ScenarioFixtures.summon_creature(player, match_state, "meal", "field", 1, 1)
	MatchMutations.discard_card(match_state, str(meal.get("instance_id", "")), {"reason": "test_setup"})
	# End both turns so player's start_of_turn fires, creating a pending consume selection
	MatchTurnLoop.end_turn(match_state, player_id)
	MatchTurnLoop.end_turn(match_state, opponent_id)
	var has_pending := MatchTiming.has_pending_consume_selection(match_state, player_id)
	if not _assert(has_pending, "optional_consume_for_keyword should create a pending consume selection"):
		return false
	# Resolve consume selection
	var resolve_result := MatchTiming.resolve_consume_selection(match_state, player_id, str(meal.get("instance_id", "")))
	if not _assert(bool(resolve_result.get("is_valid", false)), "resolve_consume_selection should succeed"):
		return false
	return _assert(EvergreenRules.has_keyword(fledgling, "drain"), "optional_consume_for_keyword should grant drain after consuming a creature")


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


func _test_on_friendly_wax_target_mode() -> bool:
	# Frazzled Alfiq's on_friendly_wax has target_mode: "creature_or_player" —
	# playing another wax card should queue pending_summon_effect_targets for the Alfiq,
	# NOT auto-fire at the opponent. Player picks the damage target.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Pre-place Frazzled Alfiq in field lane
	var alfiq := ScenarioFixtures.summon_creature(player, match_state, "frazzled_alfiq", "field", 1, 2, [], -1, {
		"cost": 2,
		"triggered_abilities": [
			{"family": "wax", "required_zone": "lane", "target_mode": "creature_or_player", "effects": [{"op": "deal_damage", "target": "chosen_target", "amount": 1}]},
			{"family": "wane", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}]},
			{"family": "on_friendly_wax", "required_zone": "lane", "target_mode": "creature_or_player", "effects": [{"op": "deal_damage", "target": "chosen_target", "amount": 1}]},
			{"family": "on_friendly_wane", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}]},
		],
	})
	# Resolve Alfiq's own wax summon target (picks opponent face)
	if MatchTiming.has_pending_summon_effect_target(match_state, pid):
		MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_player_id": oid})
	var opponent_health_after_alfiq := int(opponent.get("health", 30))
	# Place an enemy creature as a potential damage target
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_target", "field", 0, 3)
	var enemy_id := str(enemy.get("instance_id", ""))
	# Add a cheap wax creature to hand and play it during wax phase
	var wax_buddy := ScenarioFixtures.add_hand_card(player, "wax_buddy", {
		"card_type": "creature",
		"cost": 0,
		"triggered_abilities": [
			{"family": "wax", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}]},
		],
	})
	# Opponent health before playing buddy
	var opp_hp_before := int(opponent.get("health", 30))
	LaneRules.summon_from_hand(match_state, pid, str(wax_buddy.get("instance_id", "")), "field", {})
	# Alfiq's on_friendly_wax should NOT auto-fire — instead it should queue pending targeting
	var opp_hp_after_play := int(opponent.get("health", 30))
	var has_pending := MatchTiming.has_pending_summon_effect_target(match_state, pid)
	if not _assert(has_pending, "on_friendly_wax with target_mode should queue pending_summon_effect_targets."):
		return false
	# Opponent health should be unchanged (no auto-fire)
	if not _assert(opp_hp_after_play == opp_hp_before, "on_friendly_wax should NOT auto-fire damage before player picks target. HP: %d -> %d" % [opp_hp_before, opp_hp_after_play]):
		return false
	# Resolve targeting — pick the enemy creature
	var resolve := MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": enemy_id})
	var enemy_health_after := EvergreenRules.get_remaining_health(enemy)
	return (
		_assert(bool(resolve.get("is_valid", false)), "Resolving on_friendly_wax target should succeed.") and
		_assert(enemy_health_after == 2, "Enemy creature should take 1 damage from on_friendly_wax, health: 3 -> 2, got %d." % enemy_health_after)
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
		_test_treasure_map_count_based_hunt() and
		_test_draw_if_top_deck_subtype_draws_animal() and
		_test_draw_if_top_deck_subtype_moves_non_animal_to_bottom()
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


func _test_filter_unique_cost_reduction() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Place Star-Sung Bard in lane with filter_unique cost reduction aura
	var bard := ScenarioFixtures.summon_creature(player, match_state, "star_sung_bard", "field", 2, 3, [], -1, {
		"cost": 3,
		"cost_reduction_aura": {"scope": "hand", "target": "friendly", "amount": 1, "filter_unique": true},
	})
	# Add a unique creature to hand (should get discount)
	var unique_card := ScenarioFixtures.add_hand_card(player, "unique_creature", {
		"card_type": "creature", "cost": 5, "power": 3, "health": 3, "is_unique": true,
	})
	# Add a non-unique creature to hand (should NOT get discount)
	var common_card := ScenarioFixtures.add_hand_card(player, "common_creature", {
		"card_type": "creature", "cost": 5, "power": 3, "health": 3,
	})
	var unique_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, unique_card)
	var common_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, common_card)
	return (
		_assert(unique_cost == 4, "Unique card should cost 1 less with Star-Sung Bard (got %d)." % unique_cost) and
		_assert(common_cost == 5, "Non-unique card should NOT be discounted (got %d)." % common_cost)
	)


func _test_guess_opponent_card_varies_per_instance() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Give opponent 5 distinct hand cards and 10 distinct deck cards
	for i in range(5):
		ScenarioFixtures.add_hand_card(opponent, "opp_hand_%d" % i, {
			"card_type": "creature", "cost": i + 1, "power": i + 1, "health": i + 1,
			"definition_id": "opp_hand_def_%d" % i,
		})
	for i in range(10):
		ScenarioFixtures.make_card(oid, "opp_deck_%d" % i, {
			"zone": "deck", "card_type": "creature", "cost": i + 1, "power": i + 1, "health": i + 1,
			"definition_id": "opp_deck_def_%d" % i,
		})
	# Summon two copies of Caius Cosades (on_correct mode)
	var caius1 := ScenarioFixtures.summon_creature(player, match_state, "caius_1", "field", 3, 4, [], -1, {
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "lane", "effects": [{"op": "guess_opponent_card", "on_correct": [{"op": "modify_stats", "target": "all_creatures_in_hand", "power": 1, "health": 1}]}]}],
	})
	# Read first pending choice options
	var pending1: Array = match_state.get("pending_player_choices", [])
	if not _assert(pending1.size() >= 1, "First Caius should create a pending choice."):
		return false
	var first_options: Array = pending1[pending1.size() - 1].get("options", [])
	var first_labels: Array = []
	for opt in first_options:
		first_labels.append(str(opt.get("label", "")))
	# Resolve the choice so it clears
	MatchTiming.resolve_pending_player_choice(match_state, pid, 0)
	# Summon second copy
	var caius2 := ScenarioFixtures.summon_creature(player, match_state, "caius_2", "shadow", 3, 4, [], -1, {
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "lane", "effects": [{"op": "guess_opponent_card", "on_correct": [{"op": "modify_stats", "target": "all_creatures_in_hand", "power": 1, "health": 1}]}]}],
	})
	var pending2: Array = match_state.get("pending_player_choices", [])
	if not _assert(pending2.size() >= 1, "Second Caius should create a pending choice."):
		return false
	var second_options: Array = pending2[pending2.size() - 1].get("options", [])
	var second_labels: Array = []
	for opt in second_options:
		second_labels.append(str(opt.get("label", "")))
	# With 5 hand cards and 10 deck cards, different instances should pick different cards
	var labels_differ: bool = str(first_labels[0]) != str(second_labels[0]) or str(first_labels[1]) != str(second_labels[1])
	return (
		_assert(first_options.size() == 2, "First Caius should show exactly 2 options.") and
		_assert(second_options.size() == 2, "Second Caius should show exactly 2 options.") and
		_assert(labels_differ, "Different Caius instances should show different card pairs (got %s both times)." % [str(first_labels)])
	)


func _test_grant_keyword_to_all_copies_spreads_to_hand_and_deck() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var nereid_abilities := [
		{"family": "summon", "effects": [{"op": "grant_random_keyword", "target": "self"}]},
		{"family": "on_keyword_gained", "required_zone": "lane", "effects": [{"op": "grant_keyword_to_all_copies", "target": "self", "subtype": "Nereid"}]},
	]
	var sister_in_hand := ScenarioFixtures.add_hand_card(player, "nereid_sister_a", {
		"card_type": "creature", "cost": 0, "power": 4, "health": 5, "name": "Nereid Sister",
		"triggered_abilities": nereid_abilities,
	})
	var sister_in_hand_2 := ScenarioFixtures.add_hand_card(player, "nereid_sister_b", {
		"card_type": "creature", "cost": 0, "power": 4, "health": 5, "name": "Nereid Sister",
		"triggered_abilities": nereid_abilities,
	})
	var sister_in_deck := ScenarioFixtures.make_card(pid, "nereid_sister_c", {
		"card_type": "creature", "cost": 0, "power": 4, "health": 5, "name": "Nereid Sister",
		"triggered_abilities": nereid_abilities,
	})
	sister_in_deck["zone"] = "deck"
	player["deck"].append(sister_in_deck)
	LaneRules.summon_from_hand(match_state, pid, str(sister_in_hand.get("instance_id", "")), "field", {})
	var summoned_keywords: Array = sister_in_hand.get("granted_keywords", [])
	if not _assert(summoned_keywords.size() > 0, "Summoned Nereid Sister should gain a random keyword."):
		return false
	var granted_keyword: String = str(summoned_keywords[0])
	var hand_keywords: Array = sister_in_hand_2.get("granted_keywords", [])
	var deck_keywords: Array = sister_in_deck.get("granted_keywords", [])
	return (
		_assert(hand_keywords.has(granted_keyword), "Nereid Sister in hand should receive the granted keyword '%s' (got: %s)." % [granted_keyword, str(hand_keywords)]) and
		_assert(deck_keywords.has(granted_keyword), "Nereid Sister in deck should receive the granted keyword '%s' (got: %s)." % [granted_keyword, str(deck_keywords)])
	)


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


func _test_unstoppable_rage_deal_damage_to_lane() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon a 5-power friendly creature in field lane
	var friendly := ScenarioFixtures.summon_creature(player, match_state, "friendly_brute", "field", 5, 5)
	# Summon 2 enemy creatures in field lane (3hp each)
	var enemy1 := ScenarioFixtures.summon_creature(opponent, match_state, "enemy1", "field", 2, 3)
	var enemy2 := ScenarioFixtures.summon_creature(opponent, match_state, "enemy2", "field", 2, 3)
	# Another friendly creature in field lane (should also take damage)
	var friendly2 := ScenarioFixtures.summon_creature(player, match_state, "friendly2", "field", 1, 10)
	# Unstoppable Rage: deal damage equal to target creature's power to all other creatures in lane
	var rage := ScenarioFixtures.add_hand_card(player, "unstoppable_rage", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "friendly_creature",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage_to_lane", "target": "event_target", "damage_source": "event_target", "exclude_self": true}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(rage.get("instance_id", "")), {"target_instance_id": str(friendly.get("instance_id", ""))})
	if not _assert(bool(result.get("is_valid", false)), "Unstoppable Rage should be playable."):
		return false
	# enemy1 and enemy2 had 3hp, took 5 damage -> destroyed
	var e1_loc := MatchMutations.find_card_location(match_state, str(enemy1.get("instance_id", "")))
	var e2_loc := MatchMutations.find_card_location(match_state, str(enemy2.get("instance_id", "")))
	if not _assert(str(e1_loc.get("zone", "")) == "discard", "Unstoppable Rage: enemy1 (3hp) should be destroyed by 5 damage."):
		return false
	if not _assert(str(e2_loc.get("zone", "")) == "discard", "Unstoppable Rage: enemy2 (3hp) should be destroyed by 5 damage."):
		return false
	# friendly2 had 10hp, took 5 damage -> 5hp remaining
	if not _assert(EvergreenRules.get_remaining_health(friendly2) == 5, "Unstoppable Rage: friendly2 (10hp) should have 5hp remaining after 5 damage."):
		return false
	# The source creature should NOT take damage from itself
	return _assert(EvergreenRules.get_remaining_health(friendly) == 5, "Unstoppable Rage: source creature should not damage itself.")


func _test_dark_rebirth_sacrifice_and_resummon() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon a creature to sacrifice
	var target := ScenarioFixtures.summon_creature(player, match_state, "summon_target", "field", 3, 3, [], -1, {
		"definition_id": "test_summon_creature",
	})
	var target_id := str(target.get("instance_id", ""))
	# Dark Rebirth: sacrifice target, resummon a copy
	var rebirth := ScenarioFixtures.add_hand_card(player, "dark_rebirth", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "friendly_creature",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "sacrifice_and_resummon", "target": "event_target"}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(rebirth.get("instance_id", "")), {"target_instance_id": target_id})
	if not _assert(bool(result.get("is_valid", false)), "Dark Rebirth should be playable."):
		return false
	# Original creature should be in discard
	var orig_loc := MatchMutations.find_card_location(match_state, target_id)
	if not _assert(str(orig_loc.get("zone", "")) == "discard", "Dark Rebirth: original creature should be sacrificed to discard."):
		return false
	# A new copy should exist in the field lane with base stats
	var copy: Dictionary = {}
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != "field":
			continue
		for card in lane.get("player_slots", {}).get(pid, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "test_summon_creature" and str(card.get("instance_id", "")) != target_id:
				copy = card
	if not _assert(not copy.is_empty(), "Dark Rebirth: a copy of the creature should be summoned in the same lane."):
		return false
	return (
		_assert(EvergreenRules.get_power(copy) == 3, "Dark Rebirth: copy should have original base power (3).") and
		_assert(EvergreenRules.get_health(copy) == 3, "Dark Rebirth: copy should have original base health (3).")
	)


func _test_recall_and_resummon_preserves_state_triggers_summon() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon a creature with a summon ability (draw a card) in field lane
	var target := ScenarioFixtures.summon_creature(player, match_state, "recall_target", "field", 2, 3, [], -1, {
		"definition_id": "test_recall_creature",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_SUMMON, "effects": [{"op": "draw", "target": "friendly_player", "count": 1}]}],
	})
	var target_id := str(target.get("instance_id", ""))
	if not _assert(not target.is_empty(), "Recall test: target creature should be summoned."):
		return false
	# Apply a stat buff to verify state preservation
	EvergreenRules.apply_stat_bonus(target, 3, 2)
	var power_before: int = EvergreenRules.get_power(target)
	var health_before: int = EvergreenRules.get_health(target)
	# Seed a card so the summon draw has something to draw
	ScenarioFixtures.set_deck_cards(player, [ScenarioFixtures.make_card(pid, "draw_fodder", {"card_type": "action", "cost": 0})])
	var hand_before: int = player.get("hand", []).size()
	# Play recall_and_resummon targeting the creature
	var action := ScenarioFixtures.add_hand_card(player, "recall_action", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "friendly_creature",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "effects": [{"op": "recall_and_resummon", "target": "event_target"}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(action.get("instance_id", "")), {"target_instance_id": target_id})
	if not _assert(bool(result.get("is_valid", false)), "Recall and resummon action should be playable."):
		return false
	# Creature should now be in shadow lane (opposite of field)
	var loc := MatchMutations.find_card_location(match_state, target_id)
	if not _assert(str(loc.get("lane_id", "")) == "shadow", "Recall: creature should be in opposite lane (shadow)."):
		return false
	# Same instance — not a copy
	if not _assert(str(loc.get("zone", "")) == "lane", "Recall: creature should still be on the board."):
		return false
	# Stat buffs preserved
	if not _assert(EvergreenRules.get_power(target) == power_before, "Recall: power buff should be preserved (%d)." % power_before):
		return false
	if not _assert(EvergreenRules.get_health(target) == health_before, "Recall: health buff should be preserved (%d)." % health_before):
		return false
	# Summon ability should have triggered (drew a card)
	var hand_after: int = player.get("hand", []).size()
	# hand_before includes the action card we added, which was consumed, so net is: hand_before - 1 (action played) + 1 (drawn) = hand_before
	return _assert(hand_after == hand_before, "Recall: summon ability should trigger, drawing a card (hand: %d -> %d, expected %d)." % [hand_before, hand_after, hand_before])


func _test_trial_of_flame_destroy_all_except_strongest() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Player has a 5-power and a 2-power creature in field
	var p_strong := ScenarioFixtures.summon_creature(player, match_state, "p_strong", "field", 5, 5)
	var p_weak := ScenarioFixtures.summon_creature(player, match_state, "p_weak", "field", 2, 2)
	# Opponent has an 8-power and two 3-power creatures in field
	var o_strong := ScenarioFixtures.summon_creature(opponent, match_state, "o_strong", "field", 8, 8)
	var o_weak1 := ScenarioFixtures.summon_creature(opponent, match_state, "o_weak1", "field", 3, 3)
	var o_weak2 := ScenarioFixtures.summon_creature(opponent, match_state, "o_weak2", "field", 3, 3)
	# Trial of Flame: destroy all except strongest on each side
	var trial := ScenarioFixtures.add_hand_card(player, "trial_of_flame", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "choose_lane",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "destroy_all_except_strongest_in_lane", "target": "chosen_lane"}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(trial.get("instance_id", "")), {"lane_id": "field"})
	if not _assert(bool(result.get("is_valid", false)), "Trial of Flame should be playable."):
		return false
	# Player's strong (5-power) survives, weak (2-power) destroyed
	var ps_loc := MatchMutations.find_card_location(match_state, str(p_strong.get("instance_id", "")))
	var pw_loc := MatchMutations.find_card_location(match_state, str(p_weak.get("instance_id", "")))
	if not _assert(str(ps_loc.get("zone", "")) == "lane", "Trial of Flame: player's strongest creature should survive."):
		return false
	if not _assert(str(pw_loc.get("zone", "")) == "discard", "Trial of Flame: player's weaker creature should be destroyed."):
		return false
	# Opponent's strong (8-power) survives, both weaks destroyed
	var os_loc := MatchMutations.find_card_location(match_state, str(o_strong.get("instance_id", "")))
	var ow1_loc := MatchMutations.find_card_location(match_state, str(o_weak1.get("instance_id", "")))
	var ow2_loc := MatchMutations.find_card_location(match_state, str(o_weak2.get("instance_id", "")))
	if not _assert(str(os_loc.get("zone", "")) == "lane", "Trial of Flame: opponent's strongest creature should survive."):
		return false
	if not _assert(str(ow1_loc.get("zone", "")) == "discard", "Trial of Flame: opponent's weaker creature should be destroyed."):
		return false
	return _assert(str(ow2_loc.get("zone", "")) == "discard", "Trial of Flame: opponent's second weaker creature should be destroyed.")


func _test_vivec_cannot_lose_expires_on_exalted_death() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon Vivec with cannot_lose passive
	ScenarioFixtures.summon_creature(player, match_state, "vivec", "field", 5, 5, [], -1, {
		"passive_abilities": [{"type": "cannot_lose", "condition": "has_exalted_creature"}],
	})
	# Summon an exalted creature
	var exalted := ScenarioFixtures.summon_creature(player, match_state, "exalted_creature", "field", 3, 3)
	EvergreenRules.add_status(exalted, EvergreenRules.STATUS_EXALTED)
	var exalted_id := str(exalted.get("instance_id", ""))
	# Set player health to 0 — cannot_lose should prevent loss
	player["health"] = 0
	player["rune_thresholds"] = []
	if not _assert(str(match_state.get("winner_player_id", "")).is_empty(), "Vivec: no winner yet while exalted creature lives."):
		return false
	# Destroy the exalted creature
	MatchMutations.discard_card(match_state, exalted_id)
	var events: Array = [{"event_type": "creature_destroyed", "instance_id": exalted_id, "controller_player_id": pid}]
	MatchTiming.publish_events(match_state, events)
	return _assert(str(match_state.get("winner_player_id", "")) == oid, "Vivec: player should lose after exalted creature is destroyed at 0 HP.")


func _test_vivec_cannot_lose_expires_on_silence() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon Vivec with cannot_lose passive
	ScenarioFixtures.summon_creature(player, match_state, "vivec", "field", 5, 5, [], -1, {
		"passive_abilities": [{"type": "cannot_lose", "condition": "has_exalted_creature"}],
	})
	# Summon an exalted creature
	var exalted := ScenarioFixtures.summon_creature(player, match_state, "exalted_creature", "field", 3, 3)
	EvergreenRules.add_status(exalted, EvergreenRules.STATUS_EXALTED)
	# Set player health to 0
	player["health"] = 0
	player["rune_thresholds"] = []
	# Silence the exalted creature — exalted status is suppressed
	MatchMutations.silence_card(exalted, {}, match_state)
	var events: Array = [{"event_type": "card_silenced", "source_instance_id": str(exalted.get("instance_id", ""))}]
	MatchTiming.publish_events(match_state, events)
	return _assert(str(match_state.get("winner_player_id", "")) == oid, "Vivec: player should lose after only exalted creature is silenced at 0 HP.")


func _test_stampede_sentinel_blocks_action_damage_to_player() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Opponent has Stampede Sentinel (grants_immunity: action_damage, support_damage)
	ScenarioFixtures.summon_creature(opponent, match_state, "stampede_sentinel", "field", 7, 7, [], -1, {
		"grants_immunity": ["action_damage", "support_damage"],
	})
	var health_before := int(opponent.get("health", 0))
	# Player plays an action that deals 5 damage to opponent
	var bolt := ScenarioFixtures.add_hand_card(player, "lightning_bolt", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "auto",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "amount": 5, "target_player": "opponent"}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(bolt.get("instance_id", "")))
	if not _assert(bool(result.get("is_valid", false)), "Stampede Sentinel: action should be playable."):
		return false
	var health_after := int(opponent.get("health", 0))
	return _assert(health_after == health_before, "Stampede Sentinel: action damage to player should be blocked (health: %d -> %d)." % [health_before, health_after])


func _test_stampede_sentinel_does_not_block_combat_damage_to_player() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Opponent has Stampede Sentinel
	ScenarioFixtures.summon_creature(opponent, match_state, "stampede_sentinel", "field", 7, 7, [], -1, {
		"grants_immunity": ["action_damage", "support_damage"],
	})
	# Player has an attacker with charge
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "charger", "field", 3, 3, [EvergreenRules.KEYWORD_CHARGE])
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var health_before := int(opponent.get("health", 0))
	var attack_result := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": oid})
	if not _assert(bool(attack_result.get("is_valid", false)), "Stampede Sentinel: combat attack should be valid."):
		return false
	var health_after := int(opponent.get("health", 0))
	return _assert(health_after == health_before - 3, "Stampede Sentinel: combat damage should NOT be blocked (health: %d -> %d, expected %d)." % [health_before, health_after, health_before - 3])


func _test_battle_self_single_destruction() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon a 5/5 creature to battle itself
	var target := ScenarioFixtures.summon_creature(player, match_state, "target", "field", 5, 5)
	var target_id := str(target.get("instance_id", ""))
	# Play an action with battle_self
	var drive_mad := ScenarioFixtures.add_hand_card(player, "drive_mad", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "effects": [{"op": "battle_creature", "target": "event_target", "battle_self": true}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(drive_mad.get("instance_id", "")), {"target_instance_id": target_id})
	if not _assert(bool(result.get("is_valid", false)), "Battle self: action should be playable."):
		return false
	# Creature should be destroyed (in discard)
	var loc := MatchMutations.find_card_location(match_state, target_id)
	if not _assert(str(loc.get("zone", "")) == "discard", "Battle self: creature should be in discard after battling itself."):
		return false
	# Should only appear once in the discard pile
	var discard: Array = player.get("discard", [])
	var count := 0
	for c in discard:
		if typeof(c) == TYPE_DICTIONARY and str(c.get("instance_id", "")) == target_id:
			count += 1
	if not _assert(count == 1, "Battle self: creature should appear exactly once in discard (found %d)." % count):
		return false
	# Count creature_destroyed events — should be exactly 1
	var destroy_events := 0
	for evt in result.get("events", []):
		if typeof(evt) == TYPE_DICTIONARY and str(evt.get("event_type", "")) == "creature_destroyed" and str(evt.get("instance_id", "")) == target_id:
			destroy_events += 1
	return _assert(destroy_events == 1, "Battle self: should emit exactly 1 creature_destroyed event (found %d)." % destroy_events)


func _test_playing_card_mutation_and_summon() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Generate a Playing Card via build_generated_card to trigger mutation
	var template := {
		"definition_id": MatchMutations.PLAYING_CARD_ID,
		"name": "Playing Card",
		"card_type": "action",
		"cost": 0,
		"rules_text": "",
	}
	var generated := MatchMutations.build_generated_card(match_state, pid, template)
	# Verify cost was assigned between 2 and 9
	var assigned_cost := int(generated.get("cost", 0))
	if not _assert(assigned_cost >= 2 and assigned_cost <= 9, "Playing Card: cost should be 2-9, got %d." % assigned_cost):
		return false
	# Verify the locked cost field matches
	if not _assert(int(generated.get("_playing_card_assigned_cost", 0)) == assigned_cost, "Playing Card: _playing_card_assigned_cost should match cost."):
		return false
	# Verify rules_text is dynamically set
	var expected_text := "Summon a random creature with cost %d." % assigned_cost
	if not _assert(str(generated.get("rules_text", "")) == expected_text, "Playing Card: rules_text should be '%s', got '%s'." % [expected_text, str(generated.get("rules_text", ""))]):
		return false
	# Verify art_path uses cost-specific image
	var expected_art := "res://assets/images/cards/playing-card-%d.png" % assigned_cost
	if not _assert(str(generated.get("art_path", "")) == expected_art, "Playing Card: art_path should be '%s'." % expected_art):
		return false
	# Verify action_target_mode is choose_lane
	if not _assert(str(generated.get("action_target_mode", "")) == "choose_lane", "Playing Card: action_target_mode should be choose_lane."):
		return false
	# Verify triggered_abilities have the correct summon filter
	var abilities: Array = generated.get("triggered_abilities", [])
	if not _assert(abilities.size() == 1, "Playing Card: should have exactly 1 triggered ability."):
		return false
	var effects: Array = abilities[0].get("effects", [])
	if not _assert(effects.size() == 1, "Playing Card: should have exactly 1 effect."):
		return false
	var filter: Dictionary = effects[0].get("filter", {})
	if not _assert(int(filter.get("exact_cost", -1)) == assigned_cost, "Playing Card: filter exact_cost should be %d." % assigned_cost):
		return false
	# Now play the card and verify it summons a creature in the target lane
	generated["zone"] = "hand"
	player.get("hand", []).append(generated)
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(generated.get("instance_id", "")), {"lane_id": "field"})
	if not _assert(bool(play_result.get("is_valid", false)), "Playing Card: should be playable with lane targeting."):
		return false
	# Check for a creature_summoned event in the field lane
	var found_summoned := false
	for evt in play_result.get("events", []):
		if typeof(evt) == TYPE_DICTIONARY and str(evt.get("event_type", "")) == "creature_summoned" and str(evt.get("lane_id", "")) == "field":
			found_summoned = true
			break
	return _assert(found_summoned, "Playing Card: should summon a creature into the target lane.")


func _test_madness_beckons_generates_iom_card() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var beckons := ScenarioFixtures.add_hand_card(player, "madness_beckons", {
		"card_type": "action", "cost": 0,
		"definition_id": "fom_neu_madness_beckons",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "madness_beckons"}]}],
	})
	# Track existing hand instance_ids before play
	var hand_ids_before: Array = []
	for c in player.get("hand", []):
		if typeof(c) == TYPE_DICTIONARY:
			hand_ids_before.append(str(c.get("instance_id", "")))
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(beckons.get("instance_id", "")), {})
	if not _assert(bool(result.get("is_valid", false)), "Madness Beckons: should be playable."):
		return false
	# Find the new card in hand (one that wasn't there before and isn't the beckons card)
	var new_card: Dictionary = {}
	for c in player.get("hand", []):
		if typeof(c) == TYPE_DICTIONARY and not hand_ids_before.has(str(c.get("instance_id", ""))):
			new_card = c
			break
	if not _assert(not new_card.is_empty(), "Madness Beckons: should add a new card to hand."):
		return false
	# The new card should be from the valid pool
	var valid_ids: Array = [
		"iom_agi_crazed_hunger", "iom_end_dark_seducer", "iom_wil_fortress_guard",
		"iom_neu_giant_chicken", "iom_str_grummite_magus", "iom_int_icy_shambles",
		MatchMutations.PLAYING_CARD_ID,
	]
	var new_def_id := str(new_card.get("definition_id", ""))
	if not _assert(valid_ids.has(new_def_id), "Madness Beckons: generated card '%s' should be from IOM pool." % new_def_id):
		return false
	# If it's a Playing Card, verify it was mutated
	if new_def_id == MatchMutations.PLAYING_CARD_ID:
		var pc_cost := int(new_card.get("cost", 0))
		if not _assert(pc_cost >= 2 and pc_cost <= 9, "Madness Beckons: Playing Card cost should be 2-9, got %d." % pc_cost):
			return false
	return true


func _test_play_prophecy_from_hand_opens_prophecy_window() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Create a creature with summon: play_prophecy_from_hand
	var beetle := ScenarioFixtures.add_hand_card(player, "assassin_beetle", {
		"card_type": "creature",
		"cost": 0,
		"power": 2,
		"health": 2,
		"rules_tags": ["prophecy"],
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "play_prophecy_from_hand"}]}],
	})
	# Add a prophecy creature to hand as a candidate
	var prophecy_card := ScenarioFixtures.add_hand_card(player, "prophecy_target", {
		"card_type": "creature",
		"cost": 3,
		"power": 3,
		"health": 3,
		"rules_tags": ["prophecy"],
	})
	var prophecy_instance_id := str(prophecy_card.get("instance_id", ""))
	# Summon the beetle to trigger play_prophecy_from_hand
	var summon_result := LaneRules.summon_from_hand(match_state, player_id, str(beetle.get("instance_id", "")), "field")
	if not _assert(bool(summon_result.get("is_valid", false)), "play_prophecy_from_hand: beetle summon should be valid."):
		return false
	# A pending hand selection should exist
	var selection := MatchTiming.get_pending_hand_selection(match_state, player_id)
	if not _assert(not selection.is_empty(), "play_prophecy_from_hand: should create a pending hand selection."):
		return false
	if not _assert(str(selection.get("then_op", "")) == "play_card_from_hand_free", "play_prophecy_from_hand: then_op should be play_card_from_hand_free."):
		return false
	# Resolve the hand selection by choosing the prophecy card
	var resolve_result := MatchTiming.resolve_pending_hand_selection(match_state, player_id, prophecy_instance_id)
	if not _assert(bool(resolve_result.get("is_valid", false)), "play_prophecy_from_hand: resolving hand selection should be valid."):
		return false
	# After resolving, no prophecy window — instead a pending free play should exist
	if not _assert(not MatchTiming.has_pending_prophecy(match_state, player_id), "play_prophecy_from_hand: should NOT open a prophecy window (auto-keep)."):
		return false
	if not _assert(MatchTiming.has_pending_free_play(match_state, player_id), "play_prophecy_from_hand: should create a pending free play."):
		return false
	# The card should be marked with _play_for_free
	var marked := false
	for card in player.get("hand", []):
		if str(card.get("instance_id", "")) == prophecy_instance_id:
			marked = bool(card.get("_play_for_free", false))
			break
	if not _assert(marked, "play_prophecy_from_hand: chosen card should have _play_for_free flag."):
		return false
	# Playing the free-play card as a creature should work without spending magicka
	player["current_magicka"] = 0  # zero magicka — should still work because it's free
	var play_result := LaneRules.summon_from_hand(match_state, player_id, prophecy_instance_id, "field")
	if not _assert(bool(play_result.get("is_valid", false)), "play_prophecy_from_hand: free-play card should summon even with 0 magicka."):
		return false
	# After playing, the pending free play should be consumed
	return _assert(not MatchTiming.has_pending_free_play(match_state, player_id), "play_prophecy_from_hand: pending free play should be consumed after playing.")


func _test_required_friendly_attribute_count_neutral() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Place a neutral creature in lane to satisfy the condition
	ScenarioFixtures.summon_creature(player, match_state, "neutral_body", "field", 0, 3, [], -1, {
		"attributes": ["neutral"],
	})
	# Summon Hulking Fabricant analog: +3/+3 if friendly neutral in play
	var fabricant := ScenarioFixtures.add_hand_card(player, "hulking_fabricant", {
		"card_type": "creature", "cost": 0, "power": 5, "health": 5,
		"triggered_abilities": [{"family": "summon", "required_friendly_attribute_count": {"attribute": "neutral", "min": 1}, "effects": [{"op": "modify_stats", "target": "self", "power": 3, "health": 3}]}],
	})
	var summon_result := LaneRules.summon_from_hand(match_state, pid, str(fabricant.get("instance_id", "")), "field")
	if not _assert(bool(summon_result.get("is_valid", false)), "Fabricant: summon should be valid."):
		return false
	# The +3/+3 buff should have been applied
	if not _assert(EvergreenRules.get_power(fabricant) == 8, "Fabricant: power should be 8 (5 base + 3 buff), got %d." % EvergreenRules.get_power(fabricant)):
		return false
	return _assert(EvergreenRules.get_health(fabricant) == 8, "Fabricant: health should be 8 (5 base + 3 buff), got %d." % EvergreenRules.get_health(fabricant))


func _test_required_friendly_attribute_count_not_met_blocks_target() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Place a NON-neutral creature — condition should NOT be met
	ScenarioFixtures.summon_creature(player, match_state, "non_neutral_body", "field", 2, 3, [], -1, {
		"attributes": ["strength"],
	})
	# Place an enemy creature as a potential silence target
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_target", "field", 3, 3, ["guard"])
	# Add Verminous Fabricant analog: Silence another creature if neutral in play
	var fabricant := ScenarioFixtures.add_hand_card(player, "verminous_fabricant", {
		"card_type": "creature", "cost": 0, "power": 2, "health": 2,
		"triggered_abilities": [{"family": "summon", "target_mode": "another_creature", "required_friendly_attribute_count": {"attribute": "neutral", "min": 1}, "effects": [{"op": "silence", "target": "chosen_target"}]}],
	})
	# Simulate summon to check valid targets — should be empty because no neutral in play
	var sim_state := match_state.duplicate(true)
	LaneRules.summon_from_hand(sim_state, pid, str(fabricant.get("instance_id", "")), "field")
	var valid_targets := MatchTargeting.get_all_valid_targets(sim_state, str(fabricant.get("instance_id", "")))
	if not _assert(valid_targets.is_empty(), "Fabricant: no valid targets should be offered without neutral in play, got %d." % valid_targets.size()):
		return false
	# Also verify resolve_targeted_effect rejects the attempt
	LaneRules.summon_from_hand(match_state, pid, str(fabricant.get("instance_id", "")), "field")
	var resolve_result := MatchTiming.resolve_targeted_effect(match_state, str(fabricant.get("instance_id", "")), {"target_instance_id": str(enemy.get("instance_id", ""))}, {"allowed_families": ["summon"]})
	if not _assert(not bool(resolve_result.get("is_valid", false)), "Fabricant: resolve_targeted_effect should reject when condition not met."):
		return false
	# Enemy should still have Guard (not silenced)
	return _assert(EvergreenRules.has_keyword(enemy, "guard"), "Fabricant: enemy should still have Guard — silence should not have fired.")


func _test_summon_from_hand_to_full_lane_auto_summons() -> bool:
	# Opponent goes first so we can end their turn to trigger the ability
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 1})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Fill opponent's field lane to capacity (4 creatures)
	for i in range(4):
		ScenarioFixtures.summon_creature(opponent, match_state, "opp_fill_%d" % i, "field", 1, 1)
	# Put Green Pact Ambusher analog in player's hand with end_of_turn trigger
	var ambusher := ScenarioFixtures.add_hand_card(player, "ambusher", {
		"card_type": "creature", "cost": 2, "power": 4, "health": 1,
		"keywords": ["guard"],
		"triggered_abilities": [{"family": "end_of_turn", "match_role": "opponent_player", "required_zone": "hand", "required_opponent_full_lane": true, "effects": [{"op": "summon_from_hand_to_full_lane", "target": "self"}]}],
	})
	var ambusher_id := str(ambusher.get("instance_id", ""))
	# End opponent's turn to trigger the ability
	MatchTurnLoop.end_turn(match_state, oid)
	# Ambusher should no longer be in hand
	var still_in_hand := false
	for card in player.get("hand", []):
		if str(card.get("instance_id", "")) == ambusher_id:
			still_in_hand = true
			break
	if not _assert(not still_in_hand, "Ambusher should be removed from hand after auto-summon."):
		return false
	# Ambusher should be in the field lane (opponent's full lane)
	var found_in_lane := false
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(pid, []):
			if str(card.get("instance_id", "")) == ambusher_id:
				found_in_lane = true
				break
	if not _assert(found_in_lane, "Ambusher should be summoned to the opponent's full lane."):
		return false
	# No pending hand selection should exist (auto-summon, not a pick phase)
	var pending := MatchTiming.get_pending_hand_selection(match_state, pid)
	return _assert(pending.is_empty(), "No pending hand selection should exist — summon should be automatic.")


func _test_consume_and_reduce_matching_subtype_cost() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Set up deck with Dark Elf creatures and a non-Dark-Elf creature
	var dark_elf_in_deck := ScenarioFixtures.make_card(pid, "dark_elf_deck_1", {
		"card_type": "creature", "cost": 5, "power": 3, "health": 3,
		"subtypes": ["Dark Elf"],
	})
	var dark_elf_in_deck_2 := ScenarioFixtures.make_card(pid, "dark_elf_deck_2", {
		"card_type": "creature", "cost": 4, "power": 2, "health": 2,
		"subtypes": ["Dark Elf"],
	})
	var nord_in_deck := ScenarioFixtures.make_card(pid, "nord_deck_1", {
		"card_type": "creature", "cost": 3, "power": 2, "health": 2,
		"subtypes": ["Nord"],
	})
	ScenarioFixtures.set_deck_cards(player, [dark_elf_in_deck, dark_elf_in_deck_2, nord_in_deck])
	# Put a Dark Elf creature in the discard pile for consuming
	var meal := ScenarioFixtures.make_card(pid, "dark_elf_meal", {
		"card_type": "creature", "cost": 2, "power": 1, "health": 1,
		"subtypes": ["Dark Elf"],
	})
	meal["zone"] = "discard"
	player["discard"] = [meal]
	# Add Rimmen Purveyor analog to hand: consume + reduce matching subtype cost
	var purveyor := ScenarioFixtures.add_hand_card(player, "purveyor", {
		"card_type": "creature", "cost": 0, "power": 4, "health": 4,
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "consume_and_reduce_matching_subtype_cost", "target_mode": "any_creature", "cost_reduction": 1}]}],
	})
	var purveyor_id := str(purveyor.get("instance_id", ""))
	# Summon the purveyor — should create a pending consume selection
	var summon_result := LaneRules.summon_from_hand(match_state, pid, purveyor_id, "field")
	if not _assert(bool(summon_result.get("is_valid", false)), "Purveyor: summon should be valid."):
		return false
	if not _assert(MatchTiming.has_pending_consume_selection(match_state, pid), "Purveyor: should have pending consume selection after summon."):
		return false
	# Resolve the consume — pick the Dark Elf meal
	var meal_id := str(meal.get("instance_id", ""))
	var consume_result := MatchTiming.resolve_consume_selection(match_state, pid, meal_id)
	if not _assert(bool(consume_result.get("is_valid", false)), "Purveyor: consume selection should be valid."):
		return false
	# Should NOT have another pending consume (only one creature should be consumed)
	if not _assert(not MatchTiming.has_pending_consume_selection(match_state, pid), "Purveyor: should NOT have another pending consume after resolving."):
		return false
	# Dark Elf deck creatures should have cost reduced by 1
	var deck: Array = player.get("deck", [])
	var de1_cost := -1
	var de2_cost := -1
	var nord_cost := -1
	for card in deck:
		var iid := str(card.get("instance_id", ""))
		if iid.ends_with("dark_elf_deck_1"):
			de1_cost = int(card.get("cost", -1))
		elif iid.ends_with("dark_elf_deck_2"):
			de2_cost = int(card.get("cost", -1))
		elif iid.ends_with("nord_deck_1"):
			nord_cost = int(card.get("cost", -1))
	if not _assert(de1_cost == 4, "Purveyor: Dark Elf deck creature 1 cost should be 4 (was 5), got %d." % de1_cost):
		return false
	if not _assert(de2_cost == 3, "Purveyor: Dark Elf deck creature 2 cost should be 3 (was 4), got %d." % de2_cost):
		return false
	return _assert(nord_cost == 3, "Purveyor: Nord deck creature cost should remain 3 (unchanged), got %d." % nord_cost)


func _test_adoring_fan_death_sets_return_timer() -> bool:
	# Opponent goes first so they can attack
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 1})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon Adoring Fan analog with last_gasp -> schedule_return_from_discard
	var fan := ScenarioFixtures.summon_creature(player, match_state, "adoring_fan", "field", 0, 1, ["guard"], -1, {
		"self_immunity": ["silence"],
		"triggered_abilities": [{"family": "last_gasp", "effects": [{"op": "schedule_return_from_discard", "target": "self"}]}],
	})
	var fan_id := str(fan.get("instance_id", ""))
	# Summon a big attacker on opponent's side to kill the fan
	var killer := ScenarioFixtures.summon_creature(opponent, match_state, "killer", "field", 5, 5)
	killer["entered_lane_on_turn"] = 0
	killer["has_attacked_this_turn"] = false
	fan["entered_lane_on_turn"] = 0
	# Attack the fan
	MatchCombat.resolve_attack(match_state, oid, str(killer.get("instance_id", "")), {
		"type": "creature",
		"instance_id": fan_id,
	})
	# Fan should be in discard with a return timer
	var found := false
	for card in player.get("discard", []):
		if str(card.get("instance_id", "")) == fan_id:
			found = true
			var timer := int(card.get("_return_from_discard_timer", -1))
			if not _assert(timer >= 1 and timer <= 10, "Adoring Fan: return timer should be 1-10, got %d." % timer):
				return false
			if not _assert(str(card.get("_return_from_discard_controller", "")) == pid, "Adoring Fan: controller should match."):
				return false
			break
	return _assert(found, "Adoring Fan: should be in discard after death.")


func _test_adoring_fan_returns_after_timer_expires() -> bool:
	# Opponent goes first so they can attack
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 1})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon and kill adoring fan
	var fan := ScenarioFixtures.summon_creature(player, match_state, "adoring_fan", "field", 0, 1, ["guard"], -1, {
		"self_immunity": ["silence"],
		"triggered_abilities": [{"family": "last_gasp", "effects": [{"op": "schedule_return_from_discard", "target": "self"}]}],
	})
	var fan_id := str(fan.get("instance_id", ""))
	var killer := ScenarioFixtures.summon_creature(opponent, match_state, "killer", "field", 5, 5)
	killer["entered_lane_on_turn"] = 0
	killer["has_attacked_this_turn"] = false
	fan["entered_lane_on_turn"] = 0
	MatchCombat.resolve_attack(match_state, oid, str(killer.get("instance_id", "")), {
		"type": "creature",
		"instance_id": fan_id,
	})
	# Force timer to 1 so it triggers on next turn start
	for card in player.get("discard", []):
		if str(card.get("instance_id", "")) == fan_id:
			card["_return_from_discard_timer"] = 1
			break
	# Cycle turns: opponent ends -> player's turn starts (timer decrements and fires)
	MatchTurnLoop.end_turn(match_state, oid)
	# Fan should now be in a lane, not in discard
	var in_discard := false
	for card in player.get("discard", []):
		if str(card.get("instance_id", "")) == fan_id:
			in_discard = true
			break
	if not _assert(not in_discard, "Adoring Fan: should no longer be in discard after timer expired."):
		return false
	var in_lane := _card_in_zone(match_state, fan_id, "lane")
	return _assert(in_lane, "Adoring Fan: should be in a lane after returning from discard.")


func _test_adoring_fan_non_death_discard_has_no_timer() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Manually place a card in discard (not via death) — simulate a discard effect
	var fan := ScenarioFixtures.make_card(pid, "adoring_fan_no_death", {
		"card_type": "creature", "cost": 3, "power": 0, "health": 1,
		"self_immunity": ["silence"],
		"triggered_abilities": [{"family": "last_gasp", "effects": [{"op": "schedule_return_from_discard", "target": "self"}]}],
	})
	fan["zone"] = "discard"
	player["discard"].append(fan)
	# The card should NOT have a return timer since it wasn't killed
	var has_timer := fan.has("_return_from_discard_timer")
	return _assert(not has_timer, "Adoring Fan: non-death discard should NOT have a return timer.")


func _test_adoring_fan_waits_when_lanes_full() -> bool:
	# Opponent goes first so they can attack
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 1})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon and kill adoring fan
	var fan := ScenarioFixtures.summon_creature(player, match_state, "adoring_fan_full", "field", 0, 1, ["guard"], -1, {
		"self_immunity": ["silence"],
		"triggered_abilities": [{"family": "last_gasp", "effects": [{"op": "schedule_return_from_discard", "target": "self"}]}],
	})
	var fan_id := str(fan.get("instance_id", ""))
	var killer := ScenarioFixtures.summon_creature(opponent, match_state, "killer_full", "field", 5, 5)
	killer["entered_lane_on_turn"] = 0
	killer["has_attacked_this_turn"] = false
	fan["entered_lane_on_turn"] = 0
	MatchCombat.resolve_attack(match_state, oid, str(killer.get("instance_id", "")), {
		"type": "creature",
		"instance_id": fan_id,
	})
	# Force timer to 1
	for card in player.get("discard", []):
		if str(card.get("instance_id", "")) == fan_id:
			card["_return_from_discard_timer"] = 1
			break
	# Fill all lanes for the player
	for lane in match_state.get("lanes", []):
		var lane_id := str(lane.get("lane_id", ""))
		var slots: Array = lane.get("player_slots", {}).get(pid, [])
		var capacity := int(lane.get("slot_capacity", 4))
		var fill_count := capacity - slots.size()
		for i in range(fill_count):
			ScenarioFixtures.summon_creature(player, match_state, "filler_%s_%d" % [lane_id, i], lane_id, 1, 1)
	# Cycle turns
	MatchTurnLoop.end_turn(match_state, oid)
	# Fan should STILL be in discard with timer reset to 1
	var still_in_discard := false
	var timer_val := -1
	for card in player.get("discard", []):
		if str(card.get("instance_id", "")) == fan_id:
			still_in_discard = true
			timer_val = int(card.get("_return_from_discard_timer", -1))
			break
	if not _assert(still_in_discard, "Adoring Fan: should stay in discard when all lanes are full."):
		return false
	return _assert(timer_val == 1, "Adoring Fan: timer should be set to 1 to retry next turn, got %d." % timer_val)


func _test_upgrade_chain_summon_advances_and_caps() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	var chain_templates := [
		{"definition_id": "t_flame", "name": "Flame Atronach", "card_type": "creature", "subtypes": ["Daedra"], "attributes": ["intelligence"], "cost": 3, "power": 3, "health": 3, "base_power": 3, "base_health": 3, "keywords": ["breakthrough"], "rules_text": "Breakthrough"},
		{"definition_id": "t_frost", "name": "Frost Atronach", "card_type": "creature", "subtypes": ["Daedra"], "attributes": ["intelligence"], "cost": 5, "power": 5, "health": 5, "base_power": 5, "base_health": 5, "keywords": ["guard"], "rules_text": "Guard"},
		{"definition_id": "t_lava", "name": "Lava Atronach", "card_type": "creature", "subtypes": ["Daedra"], "attributes": ["intelligence"], "cost": 7, "power": 8, "health": 8, "base_power": 8, "base_health": 8, "keywords": ["breakthrough", "guard", "ward"], "rules_text": "Breakthrough, Guard, Ward"},
	]
	var conjurer := ScenarioFixtures.summon_creature(player, match_state, "conjurer", "field", 2, 3, [], -1, {
		"triggered_abilities": [{
			"event_type": MatchTiming.EVENT_TURN_ENDING,
			"match_role": "controller",
			"required_zone": "lane",
			"family": "expertise",
			"min_noncreature_plays_this_turn": 1,
			"effects": [{"op": "summon_from_effect", "lane": "same", "upgrade_chain": chain_templates, "upgrade_chain_text_prefix": "Expertise: Summon a "}],
		}],
	})
	# Play a 0-cost action to satisfy expertise's "noncreature play" requirement, then end turn
	var ping1 := ScenarioFixtures.add_hand_card(player, "ping1", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 0}]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping1.get("instance_id", "")), {"target_player_id": pid})
	MatchTurnLoop.end_turn(match_state, pid)
	# --- Verify trigger 1: Flame Atronach ---
	var flame_found := false
	for card in _lane_creatures(match_state, "field", pid):
		if str(card.get("definition_id", "")) == "t_flame":
			flame_found = true
			break
	if not _assert(flame_found, "Upgrade chain trigger 1 should summon Flame Atronach."):
		return false
	if not _assert(str(conjurer.get("rules_text", "")).find("Frost Atronach") >= 0, "After first trigger, rules_text should show Frost Atronach next. Got: %s" % str(conjurer.get("rules_text", ""))):
		return false
	# --- Trigger 2: Frost Atronach ---
	MatchTurnLoop.end_turn(match_state, oid)  # opponent passes
	var ping2 := ScenarioFixtures.add_hand_card(player, "ping2", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 0}]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping2.get("instance_id", "")), {"target_player_id": pid})
	MatchTurnLoop.end_turn(match_state, pid)
	var frost_found := false
	for card in _lane_creatures(match_state, "field", pid):
		if str(card.get("definition_id", "")) == "t_frost":
			frost_found = true
			break
	if not _assert(frost_found, "Upgrade chain trigger 2 should summon Frost Atronach."):
		return false
	if not _assert(str(conjurer.get("rules_text", "")).find("Lava Atronach") >= 0, "After second trigger, rules_text should show Lava Atronach next. Got: %s" % str(conjurer.get("rules_text", ""))):
		return false
	# --- Trigger 3: Lava Atronach (last in chain) ---
	MatchTurnLoop.end_turn(match_state, oid)
	var ping3 := ScenarioFixtures.add_hand_card(player, "ping3", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 0}]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping3.get("instance_id", "")), {"target_player_id": pid})
	MatchTurnLoop.end_turn(match_state, pid)
	var lava_found := false
	for card in _lane_creatures(match_state, "field", pid):
		if str(card.get("definition_id", "")) == "t_lava":
			lava_found = true
			break
	if not _assert(lava_found, "Upgrade chain trigger 3 should summon Lava Atronach."):
		return false
	# --- Verify chain index is capped at last entry ---
	return _assert(int(conjurer.get("_upgrade_chain_index", -1)) == 2, "Upgrade chain index should stay capped at last entry (2). Got: %d" % int(conjurer.get("_upgrade_chain_index", -1)))


func _test_upgrade_chain_overflows_to_other_lane() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	var chain_templates := [
		{"definition_id": "t_flame", "name": "Flame Atronach", "card_type": "creature", "subtypes": ["Daedra"], "attributes": ["intelligence"], "cost": 3, "power": 3, "health": 3, "base_power": 3, "base_health": 3, "keywords": ["breakthrough"], "rules_text": "Breakthrough"},
	]
	# Summon conjurer to field lane
	var conjurer := ScenarioFixtures.summon_creature(player, match_state, "uc_conjurer", "field", 2, 3, [], -1, {
		"triggered_abilities": [{
			"event_type": MatchTiming.EVENT_TURN_ENDING,
			"match_role": "controller",
			"required_zone": "lane",
			"family": "expertise",
			"min_noncreature_plays_this_turn": 1,
			"effects": [{"op": "summon_from_effect", "lane": "same", "upgrade_chain": chain_templates, "upgrade_chain_text_prefix": "Expertise: Summon a "}],
		}],
	})
	# Fill remaining field lane slots
	for i in range(3):
		ScenarioFixtures.summon_creature(player, match_state, "filler_%d" % i, "field", 1, 1)
	# Verify field is full (4/4)
	if not _assert(_lane_creatures(match_state, "field", pid).size() == 4, "Field lane should be full (4 creatures)."):
		return false
	# Play an action and end turn to trigger expertise
	var ping := ScenarioFixtures.add_hand_card(player, "uc_ping", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 0}]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(ping.get("instance_id", "")), {"target_player_id": pid})
	MatchTurnLoop.end_turn(match_state, pid)
	# Flame Atronach should appear in shadow lane (overflow)
	var found_in_shadow := false
	for card in _lane_creatures(match_state, "shadow", pid):
		if str(card.get("definition_id", "")) == "t_flame":
			found_in_shadow = true
			break
	return _assert(found_in_shadow, "Upgrade chain should overflow to the other lane when source lane is full.")


func _test_summon_from_effect_overflows_to_other_lane() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Add 3 supports so count_source "friendly_supports" returns 3
	for i in range(3):
		player.get("support", []).append({"instance_id": "support_%d" % i, "definition_id": "test_support_%d" % i, "card_type": "support", "support_uses_remaining": 3})
	# Summon a creature with summon: summon 1 token per friendly support in same lane
	var token_template := {"definition_id": "t_soldier", "name": "Soldier", "card_type": "creature", "subtypes": ["Imperial"], "attributes": ["willpower"], "cost": 2, "power": 2, "health": 2, "base_power": 2, "base_health": 2}
	var summoner := ScenarioFixtures.add_hand_card(player, "sfe_overflow_summoner", {
		"card_type": "creature", "cost": 0, "power": 3, "health": 2,
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "summon_from_effect", "lane": "same", "card_template": token_template, "count_source": "friendly_supports"}]}],
	})
	# Fill field lane to 3/4 so only 1 slot remains (summoner will take it)
	for i in range(3):
		ScenarioFixtures.summon_creature(player, match_state, "sfe_filler_%d" % i, "field", 1, 1)
	if not _assert(_lane_creatures(match_state, "field", pid).size() == 3, "Field lane should have 3 creatures before summon."):
		return false
	# Summon the summoner to field — takes the last slot, then 3 tokens need to overflow
	var summon_result := LaneRules.summon_from_hand(match_state, pid, str(summoner.get("instance_id", "")), "field")
	if not _assert(bool(summon_result.get("is_valid", false)), "Summoner should summon successfully."):
		return false
	# All 3 tokens should appear in shadow lane (overflow)
	var shadow_soldiers: Array = []
	for card in _lane_creatures(match_state, "shadow", pid):
		if str(card.get("definition_id", "")) == "t_soldier":
			shadow_soldiers.append(card)
	return _assert(shadow_soldiers.size() == 3, "All 3 tokens should overflow to shadow lane, found %d." % shadow_soldiers.size())


func _test_reanimate_action_summons_from_discard() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Put a creature in the discard pile
	var dead_creature := ScenarioFixtures.make_card(pid, "dead_warrior", {
		"card_type": "creature", "power": 5, "health": 5, "base_power": 5, "base_health": 5, "cost": 5,
	})
	dead_creature["zone"] = "discard"
	player["discard"].append(dead_creature)
	var dead_id := str(dead_creature.get("instance_id", ""))
	# Add a Reanimate-like action to hand (action with summon_from_discard, no power filter)
	var reanimate := ScenarioFixtures.add_hand_card(player, "reanimate", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "summon_from_discard", "target_player": "controller"}]}],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(reanimate.get("instance_id", "")))
	if not _assert(bool(play_result.get("is_valid", false)), "Reanimate action should play successfully."):
		return false
	# Should have a pending discard choice (player picks which creature to summon)
	var pending: Array = match_state.get("pending_discard_choices", [])
	if not _assert(not pending.is_empty(), "Reanimate should create a pending discard choice for the player."):
		return false
	var choice: Dictionary = pending[0]
	var candidates: Array = choice.get("candidate_instance_ids", [])
	return _assert(candidates.has(dead_id), "Dead creature should be in the summon candidates. Got: %s" % str(candidates))


func _test_summon_from_discard_exact_cost_filter() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Put a 0-cost creature and a 1-cost creature in discard
	var zero_cost := ScenarioFixtures.make_card(pid, "zero_cost_creature", {
		"card_type": "creature", "power": 1, "health": 1, "base_power": 1, "base_health": 1, "cost": 0,
	})
	zero_cost["zone"] = "discard"
	player["discard"].append(zero_cost)
	var one_cost := ScenarioFixtures.make_card(pid, "one_cost_creature", {
		"card_type": "creature", "power": 2, "health": 2, "base_power": 2, "base_health": 2, "cost": 1,
	})
	one_cost["zone"] = "discard"
	player["discard"].append(one_cost)
	var one_cost_id := str(one_cost.get("instance_id", ""))
	var zero_cost_id := str(zero_cost.get("instance_id", ""))
	# Summon a creature with summon_from_discard + exact_cost: 1 (like Apprentice Necromancer)
	var necro := ScenarioFixtures.summon_creature(player, match_state, "necro", "field", 3, 3, [], -1, {
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "summon_from_discard", "filter": {"card_type": "creature", "exact_cost": 1}}]}],
	})
	if necro.is_empty():
		return _assert(false, "Necromancer should summon successfully.")
	# Should have a pending discard choice
	var pending: Array = match_state.get("pending_discard_choices", [])
	if not _assert(not pending.is_empty(), "Should create a pending discard choice."):
		return false
	var candidates: Array = pending[0].get("candidate_instance_ids", [])
	if not _assert(candidates.has(one_cost_id), "1-cost creature should be in candidates."):
		return false
	return _assert(not candidates.has(zero_cost_id), "0-cost creature should NOT be in candidates with exact_cost: 1 filter. Got: %s" % str(candidates))


func _test_monster_perfection_lab_equips_item_from_deck() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon a creature and attach 3 items to it
	var creature := ScenarioFixtures.summon_creature(player, match_state, "equipped_creature", "field", 3, 3)
	var creature_id := str(creature.get("instance_id", ""))
	for i in range(3):
		var item := ScenarioFixtures.make_card(pid, "equip_%d" % i, {"card_type": "item", "cost": 0})
		MatchMutations.attach_item_to_creature(match_state, pid, item, creature_id)
	# Place Monster Perfection Lab as a support
	var lab := ScenarioFixtures.add_hand_card(player, "lab", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "end_of_turn", "required_zone": "support", "effects": [{"op": "sacrifice_and_equip_from_deck", "target": "friendly_creature_with_3_items"}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(lab.get("instance_id", "")))
	# Put an item in the deck
	var deck_item := ScenarioFixtures.make_card(pid, "deck_sword", {"card_type": "item", "cost": 2, "name": "Deck Sword", "equip_power_bonus": 3})
	ScenarioFixtures.set_deck_cards(player, [deck_item])
	# End the turn — should queue a cancellable pending_summon_effect_targets
	MatchTurnLoop.end_turn(match_state, pid)
	if not _assert(MatchTiming.has_pending_summon_effect_target(match_state, pid), "Lab should queue a pending summon effect target after end of turn."):
		return false
	# Step 1: Player selects the creature with 3+ items
	var resolve_result := MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": creature_id})
	if not _assert(bool(resolve_result.get("is_valid", false)), "Resolving summon effect target should succeed."):
		return false
	# Step 2: A deck selection should now be pending — player picks the item
	if not _assert(MatchTiming.has_pending_deck_selection(match_state, pid), "Deck selection should be pending after choosing creature."):
		return false
	var deck_item_id := str(deck_item.get("instance_id", ""))
	var deck_resolve := MatchTiming.resolve_pending_deck_selection(match_state, pid, deck_item_id)
	if not _assert(bool(deck_resolve.get("is_valid", false)), "Resolving deck selection should succeed."):
		return false
	var attached: Array = creature.get("attached_items", [])
	var lab_card := MatchTimingHelpers._find_card_anywhere(match_state, str(lab.get("instance_id", "")))
	var deck_after: Array = player.get("deck", [])
	return (
		_assert(attached.size() == 4, "Creature should have 4 items (3 original + 1 from deck), got %d." % attached.size()) and
		_assert(lab_card.is_empty() or str(lab_card.get("zone", "")) == "discard", "Lab should be sacrificed (gone or in discard), found zone: %s." % str(lab_card.get("zone", ""))) and
		_assert(deck_after.size() == 0, "Deck item should have been removed from deck, got %d cards." % deck_after.size())
	)


func _test_monster_perfection_lab_no_trigger_without_3_items() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon a creature with only 2 items — not enough to trigger
	var creature := ScenarioFixtures.summon_creature(player, match_state, "under_equipped", "field", 3, 3)
	var creature_id := str(creature.get("instance_id", ""))
	for i in range(2):
		var item := ScenarioFixtures.make_card(pid, "equip_%d" % i, {"card_type": "item", "cost": 0})
		MatchMutations.attach_item_to_creature(match_state, pid, item, creature_id)
	# Place Monster Perfection Lab as a support
	var lab := ScenarioFixtures.add_hand_card(player, "lab_no_trigger", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "end_of_turn", "required_zone": "support", "effects": [{"op": "sacrifice_and_equip_from_deck", "target": "friendly_creature_with_3_items"}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(lab.get("instance_id", "")))
	var deck_item := ScenarioFixtures.make_card(pid, "deck_sword", {"card_type": "item", "cost": 2})
	ScenarioFixtures.set_deck_cards(player, [deck_item])
	# End the turn — lab should NOT trigger (no creature with 3+ items)
	MatchTurnLoop.end_turn(match_state, pid)
	var lab_card := MatchTimingHelpers._find_card_anywhere(match_state, str(lab.get("instance_id", "")))
	var deck_after: Array = player.get("deck", [])
	return (
		_assert(str(lab_card.get("zone", "")) == "support", "Lab should still be in support zone when no valid target, got: %s." % str(lab_card.get("zone", ""))) and
		_assert(deck_after.size() == 1, "Deck should be untouched (1 item), got %d." % deck_after.size())
	)


func _test_monster_perfection_lab_decline_keeps_lab() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon a creature with 3 items
	var creature := ScenarioFixtures.summon_creature(player, match_state, "equipped_creature", "field", 3, 3)
	var creature_id := str(creature.get("instance_id", ""))
	for i in range(3):
		var item := ScenarioFixtures.make_card(pid, "equip_%d" % i, {"card_type": "item", "cost": 0})
		MatchMutations.attach_item_to_creature(match_state, pid, item, creature_id)
	# Place Monster Perfection Lab
	var lab := ScenarioFixtures.add_hand_card(player, "lab_decline", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "end_of_turn", "required_zone": "support", "effects": [{"op": "sacrifice_and_equip_from_deck", "target": "friendly_creature_with_3_items"}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(lab.get("instance_id", "")))
	var deck_item := ScenarioFixtures.make_card(pid, "deck_sword", {"card_type": "item", "cost": 2})
	ScenarioFixtures.set_deck_cards(player, [deck_item])
	# End the turn — queues targeting
	MatchTurnLoop.end_turn(match_state, pid)
	if not _assert(MatchTiming.has_pending_summon_effect_target(match_state, pid), "Lab should queue pending target."):
		return false
	# Player declines — lab should stay, nothing happens
	MatchTiming.decline_pending_summon_effect_target(match_state, pid)
	var lab_card := MatchTimingHelpers._find_card_anywhere(match_state, str(lab.get("instance_id", "")))
	var deck_after: Array = player.get("deck", [])
	return (
		_assert(str(lab_card.get("zone", "")) == "support", "Lab should remain in support zone after decline, got: %s." % str(lab_card.get("zone", ""))) and
		_assert(deck_after.size() == 1, "Deck should be untouched after decline, got %d." % deck_after.size()) and
		_assert(creature.get("attached_items", []).size() == 3, "Creature should still have 3 items after decline, got %d." % creature.get("attached_items", []).size())
	)


func _make_heist_action(player_state: Dictionary) -> Dictionary:
	return ScenarioFixtures.add_hand_card(player_state, "the_ultimate_heist", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "destroy_front_rune_and_steal_draw"}]}],
	})


func _test_ultimate_heist_drops_hp_to_rune_threshold() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	opponent["health"] = 30
	opponent["rune_thresholds"] = [25, 20, 15, 10, 5]
	# Add a non-prophecy card to opponent's deck so the draw doesn't open a prophecy window
	var deck_card := ScenarioFixtures.make_card(oid, "filler", {"zone": "deck", "card_type": "creature", "cost": 1, "power": 1, "health": 1})
	opponent.get("deck", []).append(deck_card)
	var heist := _make_heist_action(player)
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(heist.get("instance_id", "")))
	return (
		_assert(bool(play_result.get("is_valid", false)), "Ultimate Heist: play should be valid.") and
		_assert(int(opponent.get("health", -1)) == 25, "Ultimate Heist: opponent HP should drop to 25, got %d." % int(opponent.get("health", -1))) and
		_assert(opponent.get("rune_thresholds", []).size() == 4, "Ultimate Heist: opponent should have 4 runes left, got %d." % opponent.get("rune_thresholds", []).size())
	)


func _test_ultimate_heist_stolen_prophecy_opens_window() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	opponent["health"] = 30
	opponent["rune_thresholds"] = [25, 20, 15, 10, 5]
	# Add a prophecy card to opponent's deck (top = last element)
	var prophecy_card := ScenarioFixtures.make_card(oid, "stolen_prophecy", {"zone": "deck", "card_type": "action", "cost": 4, "rules_tags": ["prophecy"]})
	opponent.get("deck", []).append(prophecy_card)
	var heist := _make_heist_action(player)
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(heist.get("instance_id", "")))
	if not _assert(bool(play_result.get("is_valid", false)), "Ultimate Heist prophecy: play should be valid."):
		return false
	# The stolen prophecy should be in the controller's hand
	var found_in_hand := false
	for card in player.get("hand", []):
		if str(card.get("instance_id", "")) == str(prophecy_card.get("instance_id", "")):
			found_in_hand = true
			break
	return (
		_assert(found_in_hand, "Ultimate Heist prophecy: stolen card should be in controller's hand.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, pid), "Ultimate Heist prophecy: should open a prophecy window for the controller.")
	)


func _test_ultimate_heist_no_runes_kills_opponent() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	opponent["health"] = 30
	opponent["rune_thresholds"] = []
	var heist := _make_heist_action(player)
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(heist.get("instance_id", "")))
	return (
		_assert(bool(play_result.get("is_valid", false)), "Ultimate Heist no runes: play should be valid.") and
		_assert(int(opponent.get("health", -1)) == 0, "Ultimate Heist no runes: opponent HP should be 0, got %d." % int(opponent.get("health", -1))) and
		_assert(str(match_state.get("winner_player_id", "")) == pid, "Ultimate Heist no runes: controller should win the match.")
	)


func _test_ruin_shambler_consume_only_this_turn_with_buff_per_consumed() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Pre-populate discard with a creature from a previous turn (should NOT be consumed)
	var old_discard := ScenarioFixtures.make_card(pid, "old_discard", {
		"card_type": "creature", "cost": 2, "power": 5, "health": 5,
	})
	old_discard["zone"] = "discard"
	old_discard["entered_discard_on_turn"] = -1
	player["discard"] = [old_discard]
	# Stack deck with 3 creatures (will be milled)
	ScenarioFixtures.set_deck_cards(player, [
		ScenarioFixtures.make_card(pid, "mill_c", {"card_type": "creature", "cost": 1, "power": 3, "health": 3}),
		ScenarioFixtures.make_card(pid, "mill_b", {"card_type": "creature", "cost": 1, "power": 2, "health": 2}),
		ScenarioFixtures.make_card(pid, "mill_a", {"card_type": "creature", "cost": 1, "power": 1, "health": 1}),
	])
	# Add Ruin Shambler to hand: summon: mill 3, consume all creatures in discard this turn +1/+1 each
	var shambler := ScenarioFixtures.add_hand_card(player, "ruin_shambler", {
		"card_type": "creature", "cost": 0, "power": 1, "health": 1,
		"triggered_abilities": [{"family": "summon", "effects": [
			{"op": "mill", "target_player": "controller", "count": 3},
			{"op": "consume_all_creatures_in_discard_this_turn", "target": "self", "buff_per_consumed": {"power": 1, "health": 1}},
		]}],
	})
	var shambler_id := str(shambler.get("instance_id", ""))
	var summon_result := LaneRules.summon_from_hand(match_state, pid, shambler_id, "field")
	if not _assert(bool(summon_result.get("is_valid", false)), "Ruin Shambler: summon should be valid."):
		return false
	# Should have consumed only the 3 milled creatures (this turn), not the old discard
	# Base 1/1 + 3 * (+1/+1) = 4/4
	var power := EvergreenRules.get_power(shambler)
	var health := EvergreenRules.get_health(shambler)
	if not _assert(power == 4 and health == 4, "Ruin Shambler should be 4/4 (1/1 base + 3x +1/+1), got %d/%d." % [power, health]):
		return false
	# The old discard creature should still be in discard (not consumed)
	return _assert(_contains_instance(player.get("discard", []), str(old_discard.get("instance_id", ""))), "Ruin Shambler should NOT consume creatures from previous turns.")


func _test_dro_mathra_reaper_on_discard_leave_triggers() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	player["health"] = 20
	# Summon Dro-m'Athra Reaper with on_discard_leave: +0/+1 to self, heal controller 1
	var reaper := ScenarioFixtures.summon_creature(player, match_state, "reaper", "field", 3, 2, [], -1, {
		"triggered_abilities": [
			{"family": "on_discard_leave", "required_zone": "lane", "effects": [
				{"op": "modify_stats", "target": "self", "power": 0, "health": 1},
				{"op": "heal", "target_player": "controller", "amount": 1},
			]},
		],
	})
	# Put a creature in discard
	var meal := ScenarioFixtures.make_card(pid, "meal", {
		"card_type": "creature", "cost": 1, "power": 1, "health": 1,
	})
	meal["zone"] = "discard"
	player["discard"] = [meal]
	# Consume the creature (moves it from discard to banished → card_moved event with source_zone=discard)
	var consume_result := MatchMutations.consume_card(match_state, pid, str(reaper.get("instance_id", "")), str(meal.get("instance_id", "")), {"reason": "test"})
	MatchTiming.publish_events(match_state, consume_result.get("events", []))
	# Reaper should have triggered: +0/+1
	var reaper_health := EvergreenRules.get_health(reaper)
	if not _assert(reaper_health >= 4, "Dro-m'Athra Reaper should get +0/+1 when creature leaves discard, got health %d (expected >=4: base 2 + consume_stat 1 + on_discard_leave 1)." % reaper_health):
		return false
	# Player should have healed 1
	return _assert(int(player.get("health", 0)) == 21, "Dro-m'Athra Reaper on_discard_leave should heal controller for 1, got %d." % int(player.get("health", 0)))


func _test_transform_deck_preserves_definition_id_and_art_path() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var deck_card := ScenarioFixtures.make_card(str(player.get("player_id", "")), "deck_fodder", {"card_type": "creature", "cost": 2, "power": 2, "health": 2})
	deck_card["zone"] = "deck"
	player["deck"] = [deck_card]
	# Simulate what transform_deck does: use a raw catalog seed as template
	var seed_template := {"card_id": "str_fiery_imp", "name": "Fiery Imp", "card_type": "creature", "cost": 1, "power": 1, "health": 1, "base_power": 1, "base_health": 1, "keywords": [], "rules_tags": [], "triggered_abilities": [], "subtypes": ["Imp"], "attributes": ["strength"], "rarity": "common", "effect_ids": [], "rules_text": "", "support_uses": 0, "collectible": true}
	# Map card_id -> definition_id as the fix does
	if seed_template.has("card_id") and not seed_template.has("definition_id"):
		seed_template["definition_id"] = seed_template["card_id"]
	MatchMutations.change_card(deck_card, seed_template)
	return (
		_assert(str(deck_card.get("definition_id", "")) == "str_fiery_imp", "Transformed card should have definition_id from seed's card_id, got '%s'." % str(deck_card.get("definition_id", ""))) and
		_assert(str(deck_card.get("art_path", "")).find("str_fiery_imp") >= 0, "Transformed card art_path should reference the new definition_id, got '%s'." % str(deck_card.get("art_path", "")))
	)


func _test_conditional_drawn_card_bonus_sets_base_cost() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	# Create an action card as if just drawn
	var drawn_action := ScenarioFixtures.add_hand_card(player, "drawn_action", {"card_type": "action", "cost": 5, "name": "Test Action"})
	# Create a support trigger simulating Gates of Madness on_card_drawn
	var trigger := {"source_instance_id": "gates_test", "controller_player_id": str(player.get("player_id", ""))}
	var effect := {"op": "conditional_drawn_card_bonus", "creature_item": {"power": 1, "health": 1}, "action_support": {"cost_reduction": 1}}
	var event := {"drawn_instance_id": str(drawn_action.get("instance_id", ""))}
	# Manually apply the effect logic: save _base_cost then reduce
	if not drawn_action.has("_base_cost"):
		drawn_action["_base_cost"] = int(drawn_action.get("cost", 0))
	drawn_action["cost"] = maxi(0, int(drawn_action.get("cost", 0)) - int(effect["action_support"]["cost_reduction"]))
	return (
		_assert(int(drawn_action.get("_base_cost", -1)) == 5, "Drawn action should have _base_cost preserved at 5, got %d." % int(drawn_action.get("_base_cost", -1))) and
		_assert(int(drawn_action.get("cost", -1)) == 4, "Drawn action cost should be reduced to 4, got %d." % int(drawn_action.get("cost", -1)))
	)


func _test_banish_by_name_from_opponent() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Put 2 imps and 1 wolf in opponent discard (unique labels, shared definition_id)
	var discard_imp_1 := ScenarioFixtures.make_card(oid, "discard_imp_1", {"definition_id": "imp", "zone": "discard", "card_type": "creature", "name": "Fiery Imp"})
	var discard_imp_2 := ScenarioFixtures.make_card(oid, "discard_imp_2", {"definition_id": "imp", "zone": "discard", "card_type": "creature", "name": "Fiery Imp"})
	var discard_wolf := ScenarioFixtures.make_card(oid, "discard_wolf", {"definition_id": "wolf", "zone": "discard", "card_type": "creature", "name": "Wolf"})
	opponent["discard"].append(discard_imp_1)
	opponent["discard"].append(discard_imp_2)
	opponent["discard"].append(discard_wolf)
	# Put 1 imp and 1 wolf in opponent deck
	var deck_imp := ScenarioFixtures.make_card(oid, "deck_imp", {"definition_id": "imp", "zone": "deck", "card_type": "creature", "name": "Fiery Imp"})
	var deck_wolf := ScenarioFixtures.make_card(oid, "deck_wolf", {"definition_id": "wolf", "zone": "deck", "card_type": "creature", "name": "Wolf"})
	var deck_other := ScenarioFixtures.make_card(oid, "deck_troll", {"definition_id": "troll", "zone": "deck", "card_type": "creature", "name": "Troll"})
	ScenarioFixtures.set_deck_cards(opponent, [deck_imp, deck_wolf, deck_other])
	# Summon Piercing Twilight — target_mode on trigger, effect is banish_by_name_from_opponent
	# Summon triggers with target_mode are skipped during publish_events and resolved
	# via the UI's resolve_targeted_effect (for hand summons).
	var twilight := ScenarioFixtures.add_hand_card(player, "piercing_twilight", {
		"card_type": "creature", "cost": 0, "power": 4, "health": 4,
		"triggered_abilities": [{"family": "summon", "target_mode": "opponent_discard_card", "effects": [{"op": "banish_by_name_from_opponent"}]}],
	})
	LaneRules.summon_from_hand(match_state, pid, str(twilight.get("instance_id", "")), "field")
	# For hand summons, the UI resolves target_mode via resolve_targeted_effect (not pending system).
	# Simulate the UI choosing an imp from the opponent's discard pile.
	var chosen_id := str(discard_imp_1.get("instance_id", ""))
	var twilight_id := str(twilight.get("instance_id", ""))
	var result := MatchTiming.resolve_targeted_effect(match_state, twilight_id, {"target_instance_id": chosen_id})
	if not _assert(bool(result.get("is_valid", false)), "resolve_targeted_effect should succeed for opponent discard target."):
		return false
	# Count remaining imps in discard and deck
	var discard_imps := 0
	for card in opponent.get("discard", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "imp":
			discard_imps += 1
	var deck_imps := 0
	for card in opponent.get("deck", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "imp":
			deck_imps += 1
	# Wolf should still be in discard and deck
	var discard_wolves := 0
	for card in opponent.get("discard", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "wolf":
			discard_wolves += 1
	var deck_wolves := 0
	for card in opponent.get("deck", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "wolf":
			deck_wolves += 1
	return (
		_assert(discard_imps == 0, "All imps should be banished from discard, got %d." % discard_imps) and
		_assert(deck_imps == 0, "All imps should be banished from deck, got %d." % deck_imps) and
		_assert(discard_wolves == 1, "Wolves in discard should be untouched, got %d." % discard_wolves) and
		_assert(deck_wolves == 1, "Wolves in deck should be untouched, got %d." % deck_wolves)
	)


func _test_double_max_magicka_gain_works_on_first_gain() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	player["max_magicka"] = 10
	player["current_magicka"] = 10
	# Place Pure-Blood Elder analog in lane with the doubling trigger
	var elder := ScenarioFixtures.summon_creature(player, match_state, "pbe", "field", 8, 8, [], -1, {
		"cost": 0,
		"triggered_abilities": [{"family": "on_gain_max_magicka", "required_zone": "lane", "effects": [{"op": "double_max_magicka_gain"}]}],
	})
	# Now summon a Tree Minder analog with gain_max_magicka summon trigger
	var tree_minder := ScenarioFixtures.summon_creature(player, match_state, "tree_minder", "field", 1, 1, [], -1, {
		"cost": 0,
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "gain_max_magicka", "target_player": "controller", "amount": 1}]}],
	})
	# The first gain should be doubled: 10 + 2 = 12
	var final_max := int(player.get("max_magicka", 0))
	return _assert(final_max == 12, "First gain_max_magicka should be doubled by Pure-Blood Elder (expected 12, got %d)." % final_max)


func _test_magicka_aura_visible_to_aura_conditions() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	player["max_magicka"] = 16
	player["current_magicka"] = 16
	# Place a creature with a self-aura gated on min_max_magicka_18
	var elder := ScenarioFixtures.summon_creature(player, match_state, "pbe_aura", "field", 8, 8, [], -1, {
		"cost": 0,
		"aura": {"scope": "self", "condition": "min_max_magicka_18", "power": 8, "health": 8, "keywords": ["breakthrough"]},
	})
	# Place a creature with magicka_aura +2 (like Betty Netch)
	var netch := ScenarioFixtures.summon_creature(player, match_state, "netch", "field", 0, 5, [], -1, {
		"cost": 0,
		"magicka_aura": 2,
	})
	# Recalculate auras — magicka aura should apply before condition check
	MatchAuras.recalculate_auras(match_state)
	var aura_power := int(elder.get("aura_power_bonus", 0))
	var aura_kws: Array = elder.get("aura_keywords", [])
	return (
		_assert(aura_power == 8, "Elder should get +8 aura power when magicka aura pushes max to 18 (got %d)." % aura_power) and
		_assert(aura_kws.has("breakthrough"), "Elder should get Breakthrough keyword from aura.")
	)


func _test_haskill_random_cost_trigger_draws_on_match() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var haskill := ScenarioFixtures.summon_creature(player, match_state, "haskill", "field", 3, 5, [], -1, {
		"triggered_abilities": [
			{"family": "end_of_turn", "required_zone": "lane", "effects": [{"op": "random_cost_trigger"}]},
			{"family": "on_friendly_card_played", "required_zone": "lane", "effects": [{"op": "check_cost_trigger_match", "on_match": [{"op": "draw_cards", "target_player": "controller", "count": 1}]}]},
		],
	})
	# End the turn to trigger random_cost_trigger
	MatchTiming.publish_events(match_state, [{"event_type": "turn_ending", "player_id": pid, "source_controller_player_id": pid, "turn_number": 1}])
	var chosen_cost = haskill.get("active_cost_trigger", null)
	if not _assert(chosen_cost != null, "Haskill should have active_cost_trigger after end of turn."):
		return false
	# Add a card with the matching cost to hand and a draw target in deck
	var matching_card := ScenarioFixtures.add_hand_card(player, "cost_match", {"card_type": "creature", "cost": int(chosen_cost), "power": 1, "health": 1})
	player["deck"] = [ScenarioFixtures.make_card(pid, "draw_target", {"zone": "deck", "card_type": "creature", "cost": 0, "power": 1, "health": 1})]
	var hand_before: int = player.get("hand", []).size()
	# Play the matching card
	LaneRules.summon_from_hand(match_state, pid, str(matching_card.get("instance_id", "")), "field", {})
	var hand_after: int = player.get("hand", []).size()
	# Hand should have net +0 (played 1, drew 1) meaning the draw fired
	# But since the card was removed from hand (-1) and one was drawn (+1), hand_after == hand_before - 1 + 1 = hand_before
	var old_cost := int(chosen_cost)
	var new_cost = haskill.get("active_cost_trigger", null)
	return (
		_assert(hand_after == hand_before, "Playing a card matching Haskill's cost should draw a card (hand size: %d -> %d, expected %d)." % [hand_before, hand_after, hand_before]) and
		_assert(new_cost != null, "Haskill should have a new active_cost_trigger after the match.")
	)


func _test_haskill_random_cost_trigger_no_draw_on_mismatch() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var haskill := ScenarioFixtures.summon_creature(player, match_state, "haskill", "field", 3, 5, [], -1, {
		"triggered_abilities": [
			{"family": "end_of_turn", "required_zone": "lane", "effects": [{"op": "random_cost_trigger"}]},
			{"family": "on_friendly_card_played", "required_zone": "lane", "effects": [{"op": "check_cost_trigger_match", "on_match": [{"op": "draw_cards", "target_player": "controller", "count": 1}]}]},
		],
	})
	# End the turn to trigger random_cost_trigger
	MatchTiming.publish_events(match_state, [{"event_type": "turn_ending", "player_id": pid, "source_controller_player_id": pid, "turn_number": 1}])
	var chosen_cost := int(haskill.get("active_cost_trigger", 0))
	# Add a card with a cost guaranteed to NOT match (outside 0-12 range but played for free)
	var mismatched_cost := 99
	var mismatch_card := ScenarioFixtures.add_hand_card(player, "cost_mismatch", {"card_type": "creature", "cost": mismatched_cost, "power": 1, "health": 1})
	player["deck"] = [ScenarioFixtures.make_card(pid, "draw_target", {"zone": "deck", "card_type": "creature", "cost": 0, "power": 1, "health": 1})]
	var hand_before: int = player.get("hand", []).size()
	LaneRules.summon_from_hand(match_state, pid, str(mismatch_card.get("instance_id", "")), "field", {"played_for_free": true})
	var hand_after: int = player.get("hand", []).size()
	# Hand should shrink by 1 (played 1, drew 0)
	return (
		_assert(hand_after == hand_before - 1, "Playing a card NOT matching Haskill's cost should NOT draw (hand size: %d -> %d, expected %d)." % [hand_before, hand_after, hand_before - 1]) and
		_assert(int(haskill.get("active_cost_trigger", -1)) == chosen_cost, "Haskill's cost should NOT change when the played card doesn't match.")
	)


func _test_shuffle_into_deck_respects_count() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var deck_before: int = player.get("deck", []).size()
	var token_template := {"definition_id": "t_lava_atronach", "name": "Lava Atronach", "card_type": "creature", "subtypes": ["Daedra", "Atronach"], "attributes": ["intelligence"], "cost": 7, "power": 8, "health": 8, "base_power": 8, "base_health": 8, "keywords": ["breakthrough", "guard", "ward"]}
	var summoner := ScenarioFixtures.add_hand_card(player, "sid_count_summoner", {
		"card_type": "creature", "cost": 0, "power": 3, "health": 3,
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "shuffle_into_deck", "card_template": token_template, "count": 3}]}],
	})
	var summon_result := LaneRules.summon_from_hand(match_state, pid, str(summoner.get("instance_id", "")), "field")
	if not _assert(bool(summon_result.get("is_valid", false)), "Summoner should summon successfully."):
		return false
	var deck_after: int = player.get("deck", []).size()
	var added: int = deck_after - deck_before
	return _assert(added == 3, "shuffle_into_deck with count:3 should add 3 cards to deck, got %d." % added)


func _test_on_friendly_summon_copy_no_infinite_loop() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Place a creature with on_friendly_summon: summon copy_of event_summoned_creature in other lane
	# (like Conjuration Tutor's second ability)
	ScenarioFixtures.summon_creature(player, match_state, "copy_summoner", "field", 3, 3, [], -1, {
		"triggered_abilities": [{"family": "on_friendly_summon", "required_zone": "lane", "required_summon_subtype": "Atronach", "effects": [{"op": "summon_from_effect", "lane": "other", "copy_of": "event_summoned_creature"}]}],
	})
	# Now summon an Atronach from hand — should create 1 copy, not infinite
	var atronach := ScenarioFixtures.add_hand_card(player, "test_atronach", {
		"card_type": "creature", "cost": 0, "power": 5, "health": 5,
		"subtypes": ["Daedra", "Atronach"],
	})
	var summon_result := LaneRules.summon_from_hand(match_state, pid, str(atronach.get("instance_id", "")), "field")
	if not _assert(bool(summon_result.get("is_valid", false)), "Atronach should summon successfully."):
		return false
	# Original Atronach in field + copy_summoner in field = 2 field creatures
	var field_count := _lane_creatures(match_state, "field", pid).size()
	# Copy should be in shadow lane = 1 shadow creature
	var shadow_count := _lane_creatures(match_state, "shadow", pid).size()
	return (
		_assert(field_count == 2, "Field should have copy_summoner + atronach = 2, got %d." % field_count) and
		_assert(shadow_count == 1, "Shadow should have 1 copy (no infinite loop), got %d." % shadow_count)
	)


func _test_hannibal_traven_learn_and_last_gasp_queues_free_plays() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon Hannibal Traven with learn_action + last_gasp abilities
	var hannibal := ScenarioFixtures.summon_creature(player, match_state, "hannibal", "field", 5, 5, [], -1, {
		"triggered_abilities": [
			{"family": "after_action_played", "required_zone": "lane", "effects": [{"op": "learn_action", "target": "event_action"}]},
			{"family": "last_gasp", "effects": [{"op": "play_learned_actions"}]},
		],
	})
	if not _assert(not hannibal.is_empty(), "Hannibal should summon successfully."):
		return false
	# Give opponent a creature for Hannibal to suicide into
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_blocker", "field", 5, 5)
	# Play two cheap actions while Hannibal is in lane
	var action_a := ScenarioFixtures.add_hand_card(player, "bolt_a", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "creature_or_player",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "effects": [{"op": "deal_damage", "target": "event_target", "amount": 1}]}],
	})
	var action_b := ScenarioFixtures.add_hand_card(player, "bolt_b", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}],
	})
	var action_a_id := str(action_a.get("instance_id", ""))
	var action_b_id := str(action_b.get("instance_id", ""))
	# Play action A targeting enemy creature
	var play_a := MatchTiming.play_action_from_hand(match_state, pid, action_a_id, {"target_instance_id": str(enemy.get("instance_id", ""))})
	if not _assert(bool(play_a.get("is_valid", false)), "Action A should be playable: %s" % str(play_a.get("errors", []))):
		return false
	# Play action B targeting opponent
	var play_b := MatchTiming.play_action_from_hand(match_state, pid, action_b_id, {"target_player_id": oid})
	if not _assert(bool(play_b.get("is_valid", false)), "Action B should be playable: %s" % str(play_b.get("errors", []))):
		return false
	# Both actions should now be in discard and learned by Hannibal
	var learned: Array = hannibal.get("_learned_actions", [])
	if not _assert(learned.size() == 2, "Hannibal should have learned 2 actions, got %d." % learned.size()):
		return false
	# Kill Hannibal by attacking into the enemy (mutual kill: 5 vs 5)
	ScenarioFixtures.ready_for_attack(hannibal, match_state)
	var attack := MatchCombat.resolve_attack(match_state, pid, str(hannibal.get("instance_id", "")), {"type": "creature", "instance_id": str(enemy.get("instance_id", ""))})
	if not _assert(bool(attack.get("is_valid", false)), "Attack should resolve: %s" % str(attack.get("errors", []))):
		return false
	# After Last Gasp, learned actions should be in hand as free plays
	var hand: Array = player.get("hand", [])
	var hand_ids: Array = []
	for c in hand:
		hand_ids.append(str(c.get("instance_id", "")))
	var pending_fps: Array = match_state.get("pending_free_plays", [])
	var pending_ids: Array = []
	for fp in pending_fps:
		pending_ids.append(str(fp.get("instance_id", "")))
	return (
		_assert(hand_ids.has(action_a_id), "Action A should be back in hand after Last Gasp (hand: %s)." % str(hand_ids)) and
		_assert(hand_ids.has(action_b_id), "Action B should be back in hand after Last Gasp (hand: %s)." % str(hand_ids)) and
		_assert(pending_ids.has(action_a_id), "Action A should be in pending_free_plays (pending: %s)." % str(pending_ids)) and
		_assert(pending_ids.has(action_b_id), "Action B should be in pending_free_plays (pending: %s)." % str(pending_ids))
	)


func _test_sotha_sil_end_of_turn_summons_imperfect_with_exalted() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	player["max_magicka"] = 15
	player["current_magicka"] = 15
	# Summon Sotha Sil with end_of_turn: summon Awakened Imperfect if exalted creature in play
	var sotha_sil := ScenarioFixtures.summon_creature(player, match_state, "sotha_sil", "field", 8, 8, [], -1, {
		"triggered_abilities": [
			{"family": "end_of_turn", "required_zone": "lane", "required_exalted_creature_in_play": true, "effects": [
				{"op": "summon_from_effect", "lane": "same", "card_template": {
					"definition_id": "hom_int_awakened_imperfect",
					"name": "Awakened Imperfect",
					"card_type": "creature",
					"subtypes": ["Automaton"],
					"attributes": ["neutral"],
					"cost": 8, "power": 8, "health": 8, "base_power": 8, "base_health": 8,
					"keywords": ["breakthrough", "guard"],
					"rules_text": "Breakthrough, Guard",
				}},
			]},
		],
	})
	# Mark Sotha Sil as exalted
	EvergreenRules.add_status(sotha_sil, EvergreenRules.STATUS_EXALTED)
	# End turn — should summon an Awakened Imperfect
	MatchTurnLoop.end_turn(match_state, pid)
	var field_creatures := _lane_creatures(match_state, "field", pid)
	var imperfect_count := 0
	for c in field_creatures:
		if str(c.get("definition_id", "")) == "hom_int_awakened_imperfect":
			imperfect_count += 1
	return _assert(imperfect_count == 1, "Sotha Sil end_of_turn should summon 1 Awakened Imperfect when exalted creature in play, got %d." % imperfect_count)


func _test_renegade_magister_doubles_action_damage() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon Renegade Magister in field lane
	var magister := ScenarioFixtures.summon_creature(player, match_state, "renegade_magister", "field", 5, 5, [], -1, {
		"definition_id": "mc_int_renegade_magister",
		"triggered_abilities": [{"family": "after_friendly_action_damages_enemy", "required_zone": "lane", "effects": [{"op": "deal_damage", "target": "event_damaged_creature", "amount_source": "event_damage_amount"}]}],
	})
	# Summon an enemy creature with 10 health in field lane
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_target", "field", 1, 10)
	# Play Firebolt (deal 2 damage to a creature)
	var firebolt := ScenarioFixtures.add_hand_card(player, "firebolt", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "event_target", "amount": 2}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(firebolt.get("instance_id", "")), {"target_instance_id": str(enemy.get("instance_id", ""))})
	if not _assert(bool(result.get("is_valid", false)), "Renegade Magister: Firebolt should be playable."):
		return false
	# Enemy should take 2 (Firebolt) + 2 (Magister) = 4 damage, leaving 6hp
	return _assert(EvergreenRules.get_remaining_health(enemy) == 6, "Renegade Magister: enemy should take 4 total damage (2 + 2), got %dhp remaining." % EvergreenRules.get_remaining_health(enemy))


func _test_renegade_magister_aoe_doubles_each_target() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon Renegade Magister in field lane
	var magister := ScenarioFixtures.summon_creature(player, match_state, "renegade_magister", "field", 5, 5, [], -1, {
		"definition_id": "mc_int_renegade_magister",
		"triggered_abilities": [{"family": "after_friendly_action_damages_enemy", "required_zone": "lane", "effects": [{"op": "deal_damage", "target": "event_damaged_creature", "amount_source": "event_damage_amount"}]}],
	})
	# Summon two enemy creatures in field lane
	var enemy1 := ScenarioFixtures.summon_creature(opponent, match_state, "enemy1", "field", 1, 10)
	var enemy2 := ScenarioFixtures.summon_creature(opponent, match_state, "enemy2", "field", 1, 10)
	# Play "deal 2 to all enemies" (like an AoE action)
	var aoe := ScenarioFixtures.add_hand_card(player, "test_aoe", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "all_enemies", "amount": 2}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(aoe.get("instance_id", "")), {})
	if not _assert(bool(result.get("is_valid", false)), "Renegade Magister AoE: action should be playable."):
		return false
	# Each enemy takes 2 (AoE) + 2 (Magister) = 4 damage, leaving 6hp
	return (
		_assert(EvergreenRules.get_remaining_health(enemy1) == 6, "Renegade Magister AoE: enemy1 should have 6hp, got %d." % EvergreenRules.get_remaining_health(enemy1)) and
		_assert(EvergreenRules.get_remaining_health(enemy2) == 6, "Renegade Magister AoE: enemy2 should have 6hp, got %d." % EvergreenRules.get_remaining_health(enemy2))
	)


func _test_renegade_magister_no_loop_on_own_damage() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	# Summon Renegade Magister
	var magister := ScenarioFixtures.summon_creature(player, match_state, "renegade_magister", "field", 5, 5, [], -1, {
		"definition_id": "mc_int_renegade_magister",
		"triggered_abilities": [{"family": "after_friendly_action_damages_enemy", "required_zone": "lane", "effects": [{"op": "deal_damage", "target": "event_damaged_creature", "amount_source": "event_damage_amount"}]}],
	})
	# Enemy with enough health to survive multiple hits
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_target", "field", 1, 20)
	# Firebolt deals 2 -> Magister deals 2 -> should NOT re-trigger (total = 4, not infinite)
	var firebolt := ScenarioFixtures.add_hand_card(player, "firebolt", {
		"card_type": "action", "cost": 0,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "event_target", "amount": 2}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(firebolt.get("instance_id", "")), {"target_instance_id": str(enemy.get("instance_id", ""))})
	if not _assert(bool(result.get("is_valid", false)), "Renegade Magister no-loop: Firebolt should be playable."):
		return false
	# 20 - 2 - 2 = 16. If it looped, health would be much lower.
	return _assert(EvergreenRules.get_remaining_health(enemy) == 16, "Renegade Magister no-loop: enemy should have 16hp (no infinite loop), got %d." % EvergreenRules.get_remaining_health(enemy))


func _test_renegade_magister_ignores_friendly_creature_damage() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	# Summon Renegade Magister
	var magister := ScenarioFixtures.summon_creature(player, match_state, "renegade_magister", "field", 5, 5, [], -1, {
		"definition_id": "mc_int_renegade_magister",
		"triggered_abilities": [{"family": "after_friendly_action_damages_enemy", "required_zone": "lane", "effects": [{"op": "deal_damage", "target": "event_damaged_creature", "amount_source": "event_damage_amount"}]}],
	})
	# Friendly creature that will be targeted by our own AoE
	var friendly := ScenarioFixtures.summon_creature(player, match_state, "friendly_target", "field", 1, 10)
	# AoE that hits all creatures (including friendly)
	var aoe := ScenarioFixtures.add_hand_card(player, "test_aoe_all", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "deal_damage", "target": "all_enemies", "amount": 3}, {"op": "deal_damage", "target": "all_friendly", "amount": 3}]}],
	})
	var result := MatchTiming.play_action_from_hand(match_state, pid, str(aoe.get("instance_id", "")), {})
	if not _assert(bool(result.get("is_valid", false)), "Renegade Magister friendly: AoE should be playable."):
		return false
	# Friendly creature should only take 3 from AoE, not doubled (Magister ignores friendly damage)
	return _assert(EvergreenRules.get_remaining_health(friendly) == 7, "Renegade Magister: friendly creature should only take 3 damage (not doubled), got %dhp." % EvergreenRules.get_remaining_health(friendly))


func _test_delayed_destroy_fires_at_start_of_turn() -> bool:
	# Player 0 goes first, opponent goes second
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon an enemy creature as the delayed destroy target
	var target := ScenarioFixtures.summon_creature(opponent, match_state, "target_creature", "field", 2, 3)
	var target_id := str(target.get("instance_id", ""))
	# Create Writ of Execution analog in hand with delayed_destroy + on_destroy_effects
	var writ := ScenarioFixtures.add_hand_card(player, "writ_of_execution", {
		"card_type": "action",
		"cost": 4,
		"effect_ids": ["destroy"],
		"action_target_mode": "enemy_creature",
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "delayed_destroy", "target": "event_target", "trigger_at": "start_of_turn", "on_destroy_effects": [{"op": "generate_card_to_hand", "card_template": {"definition_id": "completed_contract", "name": "Completed Contract", "card_type": "action", "attributes": ["willpower"], "cost": 0, "power": 0, "health": 0, "base_power": 0, "base_health": 0, "rules_text": "Gain 1 magicka.", "triggered_abilities": [{"family": "on_play", "effects": [{"op": "gain_magicka", "amount": 1}]}]}}]}]}],
	})
	# Play the Writ targeting the enemy creature
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(writ.get("instance_id", "")), {"target_instance_id": target_id})
	if not _assert(bool(play_result.get("is_valid", false)), "Delayed destroy: Writ should be playable."):
		return false
	# Pending delayed destroys should be queued
	var dd_pending: Array = match_state.get("pending_delayed_destroys", [])
	if not _assert(dd_pending.size() == 1, "Delayed destroy: should have 1 pending entry, got %d." % dd_pending.size()):
		return false
	# Target should still be alive
	if not _assert(_card_in_zone(match_state, target_id, "lane"), "Delayed destroy: target should still be in lane before turn cycle."):
		return false
	# End player turn, opponent turn starts and ends, then player's turn starts
	MatchTurnLoop.end_turn(match_state, pid)
	MatchTurnLoop.end_turn(match_state, oid)
	# Now it's player's turn again — delayed destroy should have fired
	if not _assert(not _card_in_zone(match_state, target_id, "lane"), "Delayed destroy: target should be destroyed after controller's turn starts."):
		return false
	# Completed Contract should be in hand
	var found_contract := false
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "completed_contract":
			found_contract = true
			break
	if not _assert(found_contract, "Delayed destroy: Completed Contract should be generated in hand."):
		return false
	# Pending should be cleared
	dd_pending = match_state.get("pending_delayed_destroys", [])
	return _assert(dd_pending.is_empty(), "Delayed destroy: pending list should be empty after resolution.")


func _test_consume_and_copy_veteran_single_consume_then_copies_ability() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Put a creature with a veteran ability (+4/+4) in the discard pile
	var meal := ScenarioFixtures.make_card(pid, "veteran_meal", {
		"card_type": "creature", "cost": 3, "power": 1, "health": 1,
		"triggered_abilities": [{"family": "veteran", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 4, "health": 4}]}],
	})
	meal["zone"] = "discard"
	player["discard"] = [meal]
	# Add Pact Outcast analog to hand: summon consume_and_copy_veteran
	var outcast := ScenarioFixtures.add_hand_card(player, "pact_outcast", {
		"card_type": "creature", "cost": 0, "power": 5, "health": 5,
		"triggered_abilities": [
			{"family": "summon", "effects": [{"op": "consume_and_copy_veteran", "target_mode": "any_creature"}]},
			{"family": "veteran", "effects": [{"op": "consume_and_copy_veteran", "target_mode": "any_creature"}]},
		],
	})
	var outcast_id := str(outcast.get("instance_id", ""))
	# Summon — should create a pending consume selection
	var summon_result := LaneRules.summon_from_hand(match_state, pid, outcast_id, "field")
	if not _assert(bool(summon_result.get("is_valid", false)), "Pact Outcast: summon should be valid."):
		return false
	if not _assert(MatchTiming.has_pending_consume_selection(match_state, pid), "Pact Outcast: should have pending consume after summon."):
		return false
	# Resolve consume — pick the veteran meal
	var meal_id := str(meal.get("instance_id", ""))
	var consume_result := MatchTiming.resolve_consume_selection(match_state, pid, meal_id)
	if not _assert(bool(consume_result.get("is_valid", false)), "Pact Outcast: consume selection should be valid."):
		return false
	# Should NOT have another pending consume (no infinite loop)
	if not _assert(not MatchTiming.has_pending_consume_selection(match_state, pid), "Pact Outcast: should NOT have another pending consume after resolving."):
		return false
	# The consumed veteran ability (+4/+4) should have fired immediately on the outcast
	var outcast_card := MatchTimingHelpers._find_card_anywhere(match_state, outcast_id)
	var p := EvergreenRules.get_power(outcast_card)
	var h := EvergreenRules.get_health(outcast_card)
	return _assert(p == 9 and h == 9, "Pact Outcast: should be 9/9 (5/5 base + 4/4 veteran) after consuming, got %d/%d." % [p, h])


func _test_consume_and_copy_veteran_fires_on_veteran_trigger() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	# Summon Pact Outcast analog in lane — already consumed once on summon (simulate by placing directly)
	var outcast := ScenarioFixtures.summon_creature(player, match_state, "pact_outcast", "field", 5, 5, [], -1, {
		"triggered_abilities": [
			{"family": "summon", "effects": [{"op": "consume_and_copy_veteran", "target_mode": "any_creature"}]},
			{"family": "veteran", "effects": [{"op": "consume_and_copy_veteran", "target_mode": "any_creature"}]},
		],
	})
	var outcast_id := str(outcast.get("instance_id", ""))
	# Put a veteran creature (+3/+3) in discard for the veteran-trigger consume
	var meal := ScenarioFixtures.make_card(pid, "veteran_meal_2", {
		"card_type": "creature", "cost": 2, "power": 2, "health": 2,
		"triggered_abilities": [{"family": "veteran", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 3, "health": 3}]}],
	})
	meal["zone"] = "discard"
	player["discard"] = [meal]
	# Enemy blocker to attack into
	var blocker := ScenarioFixtures.summon_creature(opponent, match_state, "blocker", "field", 1, 1)
	ScenarioFixtures.ready_for_attack(outcast, match_state)
	# Attack — should trigger veteran, which fires consume_and_copy_veteran pre-consume
	var attack_result := MatchCombat.resolve_attack(match_state, pid, outcast_id, {
		"type": "creature", "instance_id": str(blocker.get("instance_id", "")),
	})
	if not _assert(bool(attack_result.get("is_valid", false)), "Pact Outcast veteran: attack should resolve."):
		return false
	# Should have a pending consume selection from the veteran trigger
	if not _assert(MatchTiming.has_pending_consume_selection(match_state, pid), "Pact Outcast veteran: should have pending consume after veteran trigger fires."):
		return false
	# Resolve the consume
	var meal_id := str(meal.get("instance_id", ""))
	var consume_result := MatchTiming.resolve_consume_selection(match_state, pid, meal_id)
	if not _assert(bool(consume_result.get("is_valid", false)), "Pact Outcast veteran: consume selection should resolve."):
		return false
	if not _assert(not MatchTiming.has_pending_consume_selection(match_state, pid), "Pact Outcast veteran: no pending consume after resolving."):
		return false
	# Outcast should have +3/+3 from the consumed veteran ability (get_health is max, not current)
	var outcast_card := MatchTimingHelpers._find_card_anywhere(match_state, outcast_id)
	var p := EvergreenRules.get_power(outcast_card)
	var h := EvergreenRules.get_health(outcast_card)
	return _assert(p == 8 and h == 8, "Pact Outcast veteran: should be 8/8 (5+3/5+3 max stats), got %d/%d." % [p, h])


func _test_strange_brew_transforms_hand_creature_with_cost_reduction() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Add Strange Brew to hand (action, cost 1)
	var brew := ScenarioFixtures.add_hand_card(player, "tc_int_strange_brew", {
		"card_type": "action",
		"cost": 1,
		"triggered_abilities": [{"family": "on_play", "target_mode": "creature_in_hand", "effects": [{"op": "transform_in_hand_to_random", "cost_increase": 2, "cost_reduce": 2}]}],
	})
	var brew_id := str(brew.get("instance_id", ""))
	# Add a creature in hand (cost 3) as the transform target
	var creature := ScenarioFixtures.add_hand_card(player, "test_creature", {
		"card_type": "creature",
		"cost": 3,
		"power": 2,
		"health": 2,
	})
	var creature_id := str(creature.get("instance_id", ""))
	# Play the action
	var play_result := MatchTiming.play_action_from_hand(match_state, player_id, brew_id, {"lane_id": "field"})
	if not _assert(bool(play_result.get("is_valid", false)), "Strange Brew: play should be valid."):
		return false
	# Should create a pending hand selection
	var selection := MatchTiming.get_pending_hand_selection(match_state, player_id)
	if not _assert(not selection.is_empty(), "Strange Brew: should create pending hand selection."):
		return false
	if not _assert(str(selection.get("then_op", "")) == "transform_in_hand_to_random", "Strange Brew: then_op should be transform_in_hand_to_random, got '%s'." % str(selection.get("then_op", ""))):
		return false
	# Resolve the hand selection by choosing the creature
	var resolve_result := MatchTiming.resolve_pending_hand_selection(match_state, player_id, creature_id)
	if not _assert(bool(resolve_result.get("is_valid", false)), "Strange Brew: resolving hand selection should be valid."):
		return false
	# The creature should have been transformed — its definition_id should no longer be "test_creature"
	var transformed := MatchTimingHelpers._find_card_anywhere(match_state, creature_id)
	if not _assert(not transformed.is_empty(), "Strange Brew: transformed card should still exist."):
		return false
	if not _assert(str(transformed.get("definition_id", "")) != "test_creature", "Strange Brew: creature should be transformed to a different card, still '%s'." % str(transformed.get("definition_id", ""))):
		return false
	# The transformed card should still be a creature (not a support or action)
	if not _assert(str(transformed.get("card_type", "")) == "creature", "Strange Brew: transformed card should be a creature, got '%s'." % str(transformed.get("card_type", ""))):
		return false
	# The transformed card's cost should be reduced by 2 from whatever it was transformed into
	# Since it was a cost-3 creature transformed into a cost-5 creature, reduced by 2 → cost 3
	var final_cost := int(transformed.get("cost", -1))
	if not _assert(final_cost == 3, "Strange Brew: cost should be 3 (5 - 2 reduction), got %d." % final_cost):
		return false
	return true


func _test_optional_discard_and_summon_discards_and_summons_to_other_lane() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Add a fodder card to hand so there's something to discard
	var fodder := ScenarioFixtures.add_hand_card(player, "fodder", {
		"card_type": "action", "cost": 1,
	})
	var fodder_id := str(fodder.get("instance_id", ""))
	# Summon Fortress Guard analog in field lane with optional_discard_and_summon
	var guard := ScenarioFixtures.summon_creature(player, match_state, "fortress_guard", "field", 3, 4, ["guard"], -1, {
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "optional_discard_and_summon", "discard_count": 1, "card_template": {"definition_id": "colovian_trooper", "name": "Colovian Trooper", "card_type": "creature", "subtypes": ["Imperial"], "attributes": ["willpower"], "cost": 2, "power": 2, "health": 2, "base_power": 2, "base_health": 2, "keywords": ["guard"], "rules_text": "Guard"}, "lane": "other"}]}],
	})
	if guard.is_empty():
		return _assert(false, "Fortress Guard analog should summon.")
	# Should have a pending hand selection
	var selection := MatchTiming.get_pending_hand_selection(match_state, pid)
	if not _assert(not selection.is_empty(), "optional_discard_and_summon: should create pending hand selection."):
		return false
	if not _assert(str(selection.get("then_op", "")) == "discard_and_summon_from_discard", "optional_discard_and_summon: then_op should be discard_and_summon_from_discard."):
		return false
	# Resolve by choosing the fodder card
	var resolve_result := MatchTiming.resolve_pending_hand_selection(match_state, pid, fodder_id)
	if not _assert(bool(resolve_result.get("is_valid", false)), "optional_discard_and_summon: resolve should be valid."):
		return false
	# Fodder should be in discard
	var found_in_discard := false
	for card in player.get("discard", []):
		if str(card.get("instance_id", "")) == fodder_id:
			found_in_discard = true
			break
	if not _assert(found_in_discard, "optional_discard_and_summon: chosen card should be in discard."):
		return false
	# Colovian Trooper should be in the shadow lane (other lane from field)
	var shadow_creatures := _lane_creatures(match_state, "shadow", pid)
	var found_trooper := false
	for card in shadow_creatures:
		if str(card.get("definition_id", "")) == "colovian_trooper":
			found_trooper = true
			if not _assert(int(card.get("power", 0)) == 2 and int(card.get("health", 0)) == 2, "optional_discard_and_summon: Colovian Trooper should be 2/2."):
				return false
			break
	return _assert(found_trooper, "optional_discard_and_summon: Colovian Trooper should be summoned in shadow lane.")


func _test_blind_moth_priest_glow_flag() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon Blind Moth Priest for player
	var priest := ScenarioFixtures.summon_creature(player, match_state, "blind_moth_priest", "field", 2, 3, [], -1, {
		"definition_id": "joo_wil_blind_moth_priest",
	})
	# Put a prophecy card on top of opponent's deck
	var prophecy_card := ScenarioFixtures.make_card(oid, "prophecy_top", {
		"card_type": "creature", "cost": 1, "power": 1, "health": 1,
		"rules_tags": ["prophecy"],
	})
	opponent["deck"] = [prophecy_card]
	# Recalculate auras — should set _blind_moth_active
	MatchAuras.recalculate_auras(match_state)
	var priest_on_board := _find_lane_card(match_state, "field", pid, "joo_wil_blind_moth_priest")
	if not _assert(not priest_on_board.is_empty(), "blind_moth_priest: Priest should be on the board."):
		return false
	if not _assert(bool(priest_on_board.get("_blind_moth_active", false)), "blind_moth_priest: Should glow when opponent has prophecy on top of deck."):
		return false
	# Replace opponent's deck with a non-prophecy card
	var normal_card := ScenarioFixtures.make_card(oid, "normal_top", {
		"card_type": "creature", "cost": 1, "power": 1, "health": 1,
	})
	opponent["deck"] = [normal_card]
	MatchAuras.recalculate_auras(match_state)
	priest_on_board = _find_lane_card(match_state, "field", pid, "joo_wil_blind_moth_priest")
	if not _assert(not bool(priest_on_board.get("_blind_moth_active", false)), "blind_moth_priest: Should NOT glow when opponent has no prophecy on top."):
		return false
	# Empty deck — should not glow
	opponent["deck"] = []
	MatchAuras.recalculate_auras(match_state)
	priest_on_board = _find_lane_card(match_state, "field", pid, "joo_wil_blind_moth_priest")
	if not _assert(not bool(priest_on_board.get("_blind_moth_active", false)), "blind_moth_priest: Should NOT glow when opponent deck is empty."):
		return false
	# Not the controller's turn — should not glow even with prophecy on top
	opponent["deck"] = [prophecy_card]
	match_state["priority_player_id"] = oid
	MatchAuras.recalculate_auras(match_state)
	priest_on_board = _find_lane_card(match_state, "field", pid, "joo_wil_blind_moth_priest")
	return _assert(not bool(priest_on_board.get("_blind_moth_active", false)), "blind_moth_priest: Should NOT glow on opponent's turn.")


func _lane_creatures(match_state: Dictionary, lane_id: String, player_id: String) -> Array:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == lane_id:
			return lane.get("player_slots", {}).get(player_id, [])
	return []


func _test_draw_if_top_deck_subtype_draws_animal() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Set up deck: top card is a Beast (Animal)
	var beast_card := ScenarioFixtures.make_card(pid, "deck_beast", {
		"card_type": "creature", "cost": 3, "power": 2, "health": 2,
		"subtypes": ["Beast"],
	})
	var filler_card := ScenarioFixtures.make_card(pid, "deck_filler", {
		"card_type": "creature", "cost": 1, "power": 1, "health": 1,
	})
	ScenarioFixtures.set_deck_cards(player, [filler_card, beast_card])  # beast on top (back)
	# Add Obstinate Goat analog to hand
	var goat := ScenarioFixtures.add_hand_card(player, "obstinate_goat", {
		"card_type": "creature", "cost": 0, "power": 3, "health": 2,
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "draw_if_top_deck_subtype", "subtype": "Beast", "else_bottom": true}]}],
	})
	var hand_before: int = player.get("hand", []).size()
	LaneRules.summon_from_hand(match_state, pid, str(goat.get("instance_id", "")), "field")
	# Beast was on top — should have been drawn into hand
	var hand_after: int = player.get("hand", []).size()
	var deck_after: Array = player.get("deck", [])
	if not _assert(ScenarioFixtures.contains_instance(player.get("hand", []), str(beast_card.get("instance_id", ""))),
		"draw_if_top_deck_subtype: Beast should be drawn into hand."):
		return false
	return _assert(deck_after.size() == 1, "draw_if_top_deck_subtype: deck should have 1 card remaining, got %d." % deck_after.size())


func _test_draw_if_top_deck_subtype_moves_non_animal_to_bottom() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Set up deck: top card is NOT a Beast
	var non_beast := ScenarioFixtures.make_card(pid, "deck_nord", {
		"card_type": "creature", "cost": 3, "power": 2, "health": 2,
		"subtypes": ["Nord"],
	})
	var bottom_card := ScenarioFixtures.make_card(pid, "deck_bottom", {
		"card_type": "creature", "cost": 1, "power": 1, "health": 1,
	})
	ScenarioFixtures.set_deck_cards(player, [bottom_card, non_beast])  # non_beast on top (back)
	# Add Obstinate Goat analog to hand
	var goat := ScenarioFixtures.add_hand_card(player, "obstinate_goat", {
		"card_type": "creature", "cost": 0, "power": 3, "health": 2,
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "draw_if_top_deck_subtype", "subtype": "Beast", "else_bottom": true}]}],
	})
	var hand_before: int = player.get("hand", []).size()
	LaneRules.summon_from_hand(match_state, pid, str(goat.get("instance_id", "")), "field")
	# Non-beast was on top — should NOT be drawn, should be moved to bottom
	var hand_after: int = player.get("hand", []).size()
	var deck_after: Array = player.get("deck", [])
	if not _assert(hand_after == hand_before - 1, "draw_if_top_deck_subtype else_bottom: hand should not gain cards (goat left hand). Before: %d, After: %d" % [hand_before, hand_after]):
		return false
	if not _assert(deck_after.size() == 2, "draw_if_top_deck_subtype else_bottom: deck should still have 2 cards, got %d." % deck_after.size()):
		return false
	# The non-beast should now be at the bottom (index 0), and bottom_card should be on top (back)
	var new_top_id := str(deck_after.back().get("instance_id", ""))
	var new_bottom_id := str(deck_after[0].get("instance_id", ""))
	if not _assert(new_top_id == str(bottom_card.get("instance_id", "")),
		"draw_if_top_deck_subtype else_bottom: bottom_card should now be on top. Got: %s" % new_top_id):
		return false
	return _assert(new_bottom_id == str(non_beast.get("instance_id", "")),
		"draw_if_top_deck_subtype else_bottom: non-beast should now be on bottom. Got: %s" % new_bottom_id)


func _test_emperors_attendant_hand_selection_modify_stats() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Add a creature in hand as a candidate for the buff
	var hand_creature := ScenarioFixtures.add_hand_card(player, "hand_target", {
		"card_type": "creature", "cost": 3, "power": 2, "health": 3,
	})
	var hand_creature_id := str(hand_creature.get("instance_id", ""))
	# Summon Emperor's Attendant analog (power 1) with select_card_from_hand + modify_stats
	var attendant := ScenarioFixtures.summon_creature(player, match_state, "emperors_attendant", "field", 1, 1, [], -1, {
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "select_card_from_hand", "filter": {"card_type": "creature"}, "then_op": "modify_stats", "then_context": {"power_source": "self_power", "health_source": "self_power"}, "prompt": "Choose a creature in your hand to buff."}]}],
	})
	if attendant.is_empty():
		return _assert(false, "Emperor's Attendant should summon.")
	# Should have a pending hand selection
	var selection := MatchTiming.get_pending_hand_selection(match_state, pid)
	if not _assert(not selection.is_empty(), "Emperor's Attendant: should create a pending hand selection."):
		return false
	if not _assert(str(selection.get("then_op", "")) == "modify_stats", "Emperor's Attendant: then_op should be modify_stats."):
		return false
	# Resolve by choosing the hand creature
	var resolve_result := MatchTiming.resolve_pending_hand_selection(match_state, pid, hand_creature_id)
	if not _assert(bool(resolve_result.get("is_valid", false)), "Emperor's Attendant: resolving hand selection should be valid."):
		return false
	# The hand creature should now have +1/+1 (attendant power was 1)
	var final_power := EvergreenRules.get_power(hand_creature)
	var final_health := EvergreenRules.get_health(hand_creature)
	if not _assert(final_power == 3, "Emperor's Attendant: hand creature power should be 3 (2+1), got %d." % final_power):
		return false
	return _assert(final_health == 4, "Emperor's Attendant: hand creature health should be 4 (3+1), got %d." % final_health)


func _test_sacrifice_and_absorb_stats_uses_remaining_health() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon the sacrifice target with 4/6 base, then deal 2 damage so remaining health = 4
	var victim := ScenarioFixtures.summon_creature(player, match_state, "victim", "field", 4, 6)
	EvergreenRules.apply_damage_to_creature(victim, 2)
	if not _assert(EvergreenRules.get_remaining_health(victim) == 4, "Victim should have 4 remaining health."):
		return false
	# Summon the absorber directly (no target_mode — we manually fire the effect)
	var absorber := ScenarioFixtures.summon_creature(player, match_state, "absorber", "field", 3, 3)
	var absorber_id := str(absorber.get("instance_id", ""))
	# Directly apply sacrifice_and_absorb_stats by simulating the effect with a resolved target
	var trigger := {"source_instance_id": absorber_id, "controller_player_id": pid}
	var event := {}
	var effect := {"op": "sacrifice_and_absorb_stats", "target": "event_target"}
	var sae_event := {"event_type": "creature_summoned", "target_instance_id": str(victim.get("instance_id", ""))}
	var gen_events: Array = []
	EffectSacrifice.apply("sacrifice_and_absorb_stats", match_state, trigger, sae_event, effect, gen_events, {"reason": "summon"})
	var final_absorber := MatchTimingHelpers._find_card_anywhere(match_state, absorber_id)
	var final_power := EvergreenRules.get_power(final_absorber)
	var final_health := EvergreenRules.get_remaining_health(final_absorber)
	return (
		_assert(final_power == 7, "Absorber power should be 3+4=7, got %d." % final_power) and
		_assert(final_health == 7, "Absorber health should be 3+4=7 (remaining, not max), got %d." % final_health)
	)


func _test_forsaken_champion_aura_from_targeted_creature() -> bool:
	# Forsaken Champion summon should target a friendly creature and grant an aura
	# that buffs all friendly creatures sharing that creature's subtype.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))

	# Place an Orc in the field lane
	var orc := ScenarioFixtures.summon_creature(player, match_state, "orc_ally", "field", 2, 2, [], -1, {"subtypes": ["Orc"]})

	# Place a non-Orc in the field lane (should NOT get the buff)
	var elf := ScenarioFixtures.summon_creature(player, match_state, "elf_ally", "field", 3, 3, [], -1, {"subtypes": ["High Elf"]})

	# Add Forsaken Champion to hand with its triggered ability
	var champion := ScenarioFixtures.add_hand_card(player, "forsaken_champion", {
		"card_type": "creature",
		"cost": 5,
		"power": 3,
		"health": 3,
		"subtypes": ["Reachman"],
		"triggered_abilities": [{
			"family": "summon",
			"target_mode": "friendly_creature",
			"effects": [{"op": "grant_aura_by_chosen_subtype", "target": "chosen_target", "power": 1, "health": 1}],
		}],
	})

	# Summon Forsaken Champion — summon-family triggers with target_mode use the
	# pending_summon_effect_targets system, not the normal trigger registry.
	LaneRules.summon_from_hand(match_state, pid, str(champion.get("instance_id", "")), "field", {})
	# Queue the pending summon effect target (normally done by UI or _check_summon_abilities)
	MatchTiming._check_summon_effect_target_mode(match_state, _find_lane_card(match_state, "field", pid, "test_forsaken_champion"))
	# Resolve targeting by picking the Orc
	var orc_id := str(orc.get("instance_id", ""))
	MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": orc_id})

	# Find the champion in the lane to check its aura
	var lane_champion := _find_lane_card(match_state, "field", pid, "test_forsaken_champion")
	var aura: Dictionary = lane_champion.get("aura", {})
	var has_subtype_filter := not str(aura.get("filter_subtype", "")).is_empty() or not (aura.get("filter_subtypes_any", []) as Array).is_empty()

	# Recalculate auras and check bonuses
	MatchAuras.recalculate_auras(match_state)

	var orc_aura_bonus := int(orc.get("aura_power_bonus", 0))
	var elf_aura_bonus := int(elf.get("aura_power_bonus", 0))

	# No pending_player_choices should have been created (old bugged behavior)
	var pending: Array = match_state.get("pending_player_choices", [])
	var no_pending := pending.is_empty()

	return (
		_assert(not aura.is_empty(), "Forsaken Champion should have an aura dict after summon.") and
		_assert(has_subtype_filter, "Aura should have a subtype filter from the targeted creature.") and
		_assert(no_pending, "Should NOT create pending_player_choices — target is chosen via creature targeting, not a choice UI.") and
		_assert(str(aura.get("filter_subtype", "")) == "Orc", "Aura should filter by targeted creature's subtype 'Orc', got '%s'." % str(aura.get("filter_subtype", ""))) and
		_assert(int(aura.get("power", 0)) == 1, "Aura power bonus should be 1.") and
		_assert(int(aura.get("health", 0)) == 1, "Aura health bonus should be 1.") and
		_assert(orc_aura_bonus == 1, "Orc should get +1 power from aura, got %d." % orc_aura_bonus) and
		_assert(elf_aura_bonus == 0, "High Elf should NOT get aura bonus, got %d." % elf_aura_bonus)
	)


func _test_all_other_enemies_excludes_chosen_target() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	# Summon 3 enemy creatures: the chosen target (5hp) and two others (3hp each)
	var chosen_enemy := ScenarioFixtures.summon_creature(opponent, match_state, "chosen_enemy", "field", 2, 5)
	var other_enemy1 := ScenarioFixtures.summon_creature(opponent, match_state, "other_enemy1", "field", 2, 3)
	var other_enemy2 := ScenarioFixtures.summon_creature(opponent, match_state, "other_enemy2", "shadow", 2, 3)
	var chosen_id := str(chosen_enemy.get("instance_id", ""))
	# Create a Frostscale Dragon-style creature: deal 4 to chosen, 1 to all other enemies
	var dragon := ScenarioFixtures.add_hand_card(player, "frostscale", {
		"card_type": "creature", "cost": 0, "power": 6, "health": 6,
		"triggered_abilities": [{"family": "summon", "target_mode": "enemy_creature", "effects": [
			{"op": "deal_damage", "target": "chosen_target", "amount": 4},
			{"op": "deal_damage", "target": "all_other_enemies", "amount": 1},
		]}],
	})
	LaneRules.summon_from_hand(match_state, pid, str(dragon.get("instance_id", "")), "field", {})
	MatchTiming._check_summon_effect_target_mode(match_state, _find_lane_card(match_state, "field", pid, "test_frostscale"))
	MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": chosen_id})
	# Chosen target: 5hp - 4 damage = 1hp (should NOT also take the 1 AoE damage)
	var chosen_hp := EvergreenRules.get_remaining_health(chosen_enemy)
	var other1_hp := EvergreenRules.get_remaining_health(other_enemy1)
	var other2_hp := EvergreenRules.get_remaining_health(other_enemy2)
	return (
		_assert(chosen_hp == 1, "all_other_enemies: chosen target should only take 4 damage (5hp -> 1hp), got %dhp." % chosen_hp) and
		_assert(other1_hp == 2, "all_other_enemies: other enemy1 should take 1 damage (3hp -> 2hp), got %dhp." % other1_hp) and
		_assert(other2_hp == 2, "all_other_enemies: other enemy2 should take 1 damage (3hp -> 2hp), got %dhp." % other2_hp)
	)


func _test_drain_action_does_not_double_heal() -> bool:
	# Regression: Death Scythe had both drain keyword AND an explicit heal effect,
	# causing double healing. Drain on deal_damage already heals; no extra heal needed.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Set player HP to 20 so we can measure healing
	player["health"] = 20
	# Simulate 3 creatures having died this turn
	player["creatures_died_this_turn"] = 3
	# Summon an enemy target with enough HP to survive
	var target := ScenarioFixtures.summon_creature(opponent, match_state, "target_creature", "field", 1, 10)
	# Create a Death Scythe-like action: drain keyword + deal_damage with creatures_died_this_turn
	var scythe := ScenarioFixtures.add_hand_card(player, "death_scythe_test", {
		"card_type": "action", "cost": 0,
		"keywords": ["drain"],
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "effects": [
			{"op": "deal_damage", "target": "event_target", "amount_source": "creatures_died_this_turn"},
		]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(scythe.get("instance_id", "")), {"target_instance_id": str(target.get("instance_id", ""))})
	var target_hp := EvergreenRules.get_remaining_health(target)
	var player_hp := int(player.get("health", 0))
	return (
		_assert(target_hp == 7, "Death Scythe should deal 3 damage (10hp -> 7hp), got %dhp." % target_hp) and
		_assert(player_hp == 23, "Drain should heal for 3 only (20hp -> 23hp), got %dhp." % player_hp)
	)


func _test_equip_random_item_fires_on_play_effects() -> bool:
	var match_state := _build_started_match()
	var pid := "player_1"
	var oid := "player_2"
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	# Give opponent standard runes and enough HP so a rune breaks
	opponent["health"] = 30
	opponent["rune_thresholds"] = [25, 20, 15, 10, 5]
	# Summon attacker for player
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "attacker", "field", 6, 5)
	attacker["entered_lane_on_turn"] = 0
	# Summon Haafingar Marauder-like creature with on_enemy_rune_destroyed trigger
	var marauder := ScenarioFixtures.summon_creature(player, match_state, "test_marauder", "field", 1, 3, [], -1, {
		"triggered_abilities": [{"family": "on_enemy_rune_destroyed", "required_zone": "lane", "effects": [{"op": "equip_random_item_from_catalog", "target": "event_source"}]}],
	})
	# Attack face — attacker has 6 power, opponent at 30hp, rune at 25 → breaks
	var result := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": oid})
	# The attacker should now have an attached item
	var attached: Array = attacker.get("attached_items", [])
	# Check that a card_played event was emitted for the item (triggering on_play effects)
	var events: Array = result.get("events", [])
	var found_card_played := false
	for evt in events:
		if typeof(evt) != TYPE_DICTIONARY:
			continue
		if str(evt.get("event_type", "")) == "card_played" and str(evt.get("reason", "")) == "equip_random_item":
			found_card_played = true
			break
	return (
		_assert(not attached.is_empty(), "Attacker should have an attached item after rune break with Marauder on board.") and
		_assert(found_card_played, "equip_random_item_from_catalog should emit a card_played event so item on_play effects fire.")
	)


func _test_unicorn_aura_only_grants_charge_to_lower_power() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	# Unicorn: 2/3 with aura granting Charge to same-lane friendlies with less power
	var unicorn := ScenarioFixtures.summon_creature(player, match_state, "unicorn", "field", 2, 3, [], -1, {
		"cost": 3,
		"aura": {"scope": "same_lane", "target": "other_friendly", "filter_less_power_than_self": true, "keywords": ["charge"]},
	})
	# 1-power creature should get Charge (1 < 2)
	var small := ScenarioFixtures.summon_creature(player, match_state, "small", "field", 1, 1, [], -1, {"cost": 1})
	# 2-power creature should NOT get Charge (2 == 2, not less)
	var equal := ScenarioFixtures.summon_creature(player, match_state, "equal", "field", 2, 2, [], -1, {"cost": 2})
	# 3-power creature should NOT get Charge (3 > 2)
	var bigger := ScenarioFixtures.summon_creature(player, match_state, "bigger", "field", 3, 3, [], -1, {"cost": 3})
	MatchAuras.recalculate_auras(match_state)
	var small_kws: Array = small.get("aura_keywords", [])
	var equal_kws: Array = equal.get("aura_keywords", [])
	var bigger_kws: Array = bigger.get("aura_keywords", [])
	return (
		_assert(small_kws.has("charge"), "1-power creature should get Charge from Unicorn (power 2).") and
		_assert(not equal_kws.has("charge"), "2-power creature should NOT get Charge from Unicorn (equal power).") and
		_assert(not bigger_kws.has("charge"), "3-power creature should NOT get Charge from Unicorn (higher power).")
	)


func _test_heretic_conjurer_pilfer_transforms_summoned_to_daedra() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var opp_id := str(opponent.get("player_id", ""))
	# Summon a creature with Heretic Conjurer's pilfer ability
	var conjurer := ScenarioFixtures.summon_creature(player, match_state, "heretic_conjurer", "field", 2, 3, [], -1, {
		"cost": 5,
		"triggered_abilities": [{"family": "pilfer", "required_zone": "lane", "effects": [{"op": "enable_transform_summoned_to_daedra"}]}],
	})
	ScenarioFixtures.ready_for_attack(conjurer, match_state)
	# Attack opponent player to trigger pilfer
	var attack := MatchCombat.resolve_attack(match_state, pid, str(conjurer.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(attack.get("is_valid", false)), "Pilfer attack should resolve."):
		return false
	# Verify the flag was set
	var p_state := ScenarioFixtures.player(match_state, 0)
	if not _assert(bool(p_state.get("_transform_summoned_to_daedra_this_turn", false)), "Player should have transform flag after pilfer."):
		return false
	# Summon a plain creature from hand — it should be transformed into a Daedra
	var victim := ScenarioFixtures.add_hand_card(player, "plain_creature", {"card_type": "creature", "cost": 0, "power": 1, "health": 1, "subtypes": ["Nord"]})
	LaneRules.summon_from_hand(match_state, pid, str(victim.get("instance_id", "")), "field", {})
	# The card should now be a Daedra (transformed in-place, same instance_id)
	var transformed := MatchTimingHelpers._find_card_anywhere(match_state, str(victim.get("instance_id", "")))
	var subtypes: Array = transformed.get("subtypes", [])
	return (
		_assert(not transformed.is_empty(), "Transformed creature should still exist in a lane.") and
		_assert(subtypes.has("Daedra"), "Summoned creature should be transformed into a Daedra (got subtypes: %s)." % [str(subtypes)]) and
		_assert(str(transformed.get("definition_id", "")) != "plain_creature", "Definition should change from original (got: %s)." % [str(transformed.get("definition_id", ""))])
	)


func _test_heretic_conjurer_transform_clears_gate_restrictions() -> bool:
	# When Heretic Conjurer's pilfer chains through invade (summoned Daedra has invade summon),
	# the Oblivion Gate also gets transformed. The gate's cannot_attack and grants_immunity
	# must be cleared so the resulting Daedra can attack and be silenced normally.
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Simulate: set the transform flag directly, then generate an Oblivion Gate and transform it
	player["_transform_summoned_to_daedra_this_turn"] = true
	# Build a card with Oblivion Gate properties
	var gate_template := {
		"definition_id": "generated_oblivion_gate",
		"name": "Oblivion Gate",
		"card_type": "creature",
		"power": 0,
		"health": 4,
		"base_power": 0,
		"base_health": 4,
		"cost": 3,
		"subtypes": ["Portal"],
		"attributes": ["neutral"],
		"cannot_attack": true,
		"grants_immunity": ["silence"],
		"innate_statuses": ["permanent_shackle"],
	}
	var gate := MatchMutations.build_generated_card(match_state, pid, gate_template)
	var summon_result := MatchMutations.summon_card_to_lane(match_state, pid, gate, "field", {"source_zone": MatchMutations.ZONE_GENERATED})
	if not _assert(bool(summon_result.get("is_valid", false)), "Gate should summon."):
		return false
	var gate_id := str(gate.get("instance_id", ""))
	# Publish the creature_summoned event — this triggers the transform
	MatchTiming.publish_events(match_state, [{"event_type": "creature_summoned", "player_id": pid, "source_instance_id": gate_id, "source_controller_player_id": pid, "lane_id": "field"}])
	var transformed := MatchTimingHelpers._find_card_anywhere(match_state, gate_id)
	var t_subtypes: Array = transformed.get("subtypes", [])
	var t_statuses: Array = transformed.get("status_markers", [])
	return (
		_assert(not transformed.is_empty(), "Transformed gate should still exist.") and
		_assert(t_subtypes.has("Daedra"), "Gate should be transformed into a Daedra (got: %s)." % [str(t_subtypes)]) and
		_assert(not bool(transformed.get("cannot_attack", false)), "cannot_attack should be cleared after transform.") and
		_assert(not t_statuses.has("permanent_shackle"), "permanent_shackle status should be cleared after transform.") and
		_assert(transformed.get("grants_immunity", []).is_empty() or not transformed.get("grants_immunity", []).has("silence"), "Silence immunity from gate should be cleared after transform.")
	)


func _test_equip_from_effect_does_not_trigger_expertise() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Creature with expertise: +1/+1 at end of turn if a non-creature was played
	var expert := ScenarioFixtures.summon_creature(player, match_state, "expert", "field", 2, 2, [], -1, {
		"triggered_abilities": [{
			"event_type": MatchTiming.EVENT_TURN_ENDING,
			"match_role": "controller",
			"required_zone": "lane",
			"family": "expertise",
			"min_noncreature_plays_this_turn": 1,
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}],
		}],
	})
	# Simulate an item equipped via effect (source_zone = "generated", not "hand")
	ExtendedMechanicPacks.ensure_player_state(player)
	ExtendedMechanicPacks.observe_event(match_state, {
		"event_type": "card_played",
		"playing_player_id": pid,
		"player_id": pid,
		"source_instance_id": "fake_item_001",
		"source_controller_player_id": pid,
		"source_zone": MatchMutations.ZONE_GENERATED,
		"target_zone": "attached_item",
		"card_type": "item",
		"played_cost": 0,
		"played_for_free": true,
		"reason": "equip_random_item",
	})
	var noncreature_count := int(player.get("noncreature_plays_this_turn", 0))
	# End turn and check expertise didn't trigger
	MatchTurnLoop.end_turn(match_state, pid)
	return (
		_assert(noncreature_count == 0, "noncreature_plays_this_turn should be 0 after effect-equipped items (got %d)." % noncreature_count) and
		_assert(EvergreenRules.get_power(expert) == 2 and EvergreenRules.get_health(expert) == 2, "Expertise should NOT trigger from items equipped via effects (expert stats should remain 2/2, got %d/%d)." % [EvergreenRules.get_power(expert), EvergreenRules.get_health(expert)])
	)

func _test_shackle_immune_clears_existing_shackle() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon a creature and shackle it
	var creature := ScenarioFixtures.summon_creature(player, match_state, "shackle_target", "field", 3, 3)
	EvergreenRules.add_status(creature, EvergreenRules.STATUS_SHACKLED)
	creature["shackle_expires_on_turn"] = int(match_state.get("turn_number", 0)) + 1
	# Grant shackle_immune via effect resolution (simulating Expunge)
	var trigger := {"source_instance_id": pid + "_expunge"}
	var event := {"source_instance_id": pid + "_expunge", "target_instance_id": pid + "_shackle_target"}
	var effect := {"op": "grant_status", "target": "event_target", "status_id": "shackle_immune", "expires_end_of_turn": true}
	EffectKeywords.apply("grant_status", match_state, trigger, event, effect, [], {})
	return (
		_assert(EvergreenRules.has_raw_status(creature, "shackle_immune"), "shackle_immune status should be granted.") and
		_assert(not EvergreenRules.has_status(creature, EvergreenRules.STATUS_SHACKLED), "Existing shackle should be removed when shackle_immune is granted.") and
		_assert(not creature.has("shackle_expires_on_turn"), "shackle_expires_on_turn should be erased when shackle is cleared by immunity.")
	)

func _test_shackle_immune_blocks_new_shackle() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Summon a creature and grant shackle_immune
	var creature := ScenarioFixtures.summon_creature(player, match_state, "immune_target", "field", 3, 3)
	EvergreenRules.add_status(creature, "shackle_immune")
	# Try to shackle via the "shackle" op
	var trigger := {"source_instance_id": pid + "_shackler"}
	var event := {"source_instance_id": pid + "_shackler", "target_instance_id": pid + "_immune_target"}
	var effect_shackle := {"op": "shackle", "target": "event_target"}
	EffectKeywords.apply("shackle", match_state, trigger, event, effect_shackle, [], {})
	if not _assert(not EvergreenRules.has_status(creature, EvergreenRules.STATUS_SHACKLED), "Shackle op should be blocked by shackle_immune status."):
		return false
	# Try to shackle via the "grant_status" op with status_id=shackled
	var effect_grant := {"op": "grant_status", "target": "event_target", "status_id": "shackled"}
	EffectKeywords.apply("grant_status", match_state, trigger, event, effect_grant, [], {})
	return _assert(not EvergreenRules.has_status(creature, EvergreenRules.STATUS_SHACKLED), "grant_status with shackled should be blocked by shackle_immune status.")


func _test_multi_battle_summon_fires_two_sequential_battles() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var enemy: Dictionary = ScenarioFixtures.player(match_state, 1)
	# Summon two enemy creatures as battle targets
	var enemy_a := ScenarioFixtures.summon_creature(enemy, match_state, "enemy_a", "field", 1, 5)
	var enemy_b := ScenarioFixtures.summon_creature(enemy, match_state, "enemy_b", "field", 1, 5)
	var enemy_a_id := str(enemy_a.get("instance_id", ""))
	var enemy_b_id := str(enemy_b.get("instance_id", ""))
	# Add Hunter-Killers to hand: two summon battle_creature abilities
	var hunter := ScenarioFixtures.add_hand_card(player, "hunter_killers", {
		"card_type": "creature", "cost": 0, "power": 3, "health": 4,
		"triggered_abilities": [
			{"family": "summon", "target_mode": "enemy_creature", "effects": [{"op": "battle_creature", "target": "chosen_target"}]},
			{"family": "summon", "target_mode": "enemy_creature", "effects": [{"op": "battle_creature", "target": "chosen_target"}]},
		],
	})
	var hunter_id := str(hunter.get("instance_id", ""))
	LaneRules.summon_from_hand(match_state, pid, hunter_id, "field")
	# Engine doesn't auto-queue pending entries for hand-played creatures — simulate
	# what the UI does for multi-ability summon cards.
	var lane_hunter := _find_lane_card(match_state, "field", pid, "test_hunter_killers")
	MatchTiming._check_summon_effect_target_mode(match_state, lane_hunter)
	# Should have TWO pending summon effect target entries
	if not _assert(MatchTiming.has_pending_summon_effect_target(match_state, pid), "Multi-battle: should have pending summon effect target after summon."):
		return false
	# Resolve first battle target -> enemy_a
	var result1 := MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": enemy_a_id})
	if not _assert(bool(result1.get("is_valid", false)), "Multi-battle: first battle resolution should be valid."):
		return false
	# enemy_a should have taken 3 damage
	if not _assert(EvergreenRules.get_remaining_health(enemy_a) == 2, "Multi-battle: enemy_a should have 2 HP remaining after first battle (got %d)." % EvergreenRules.get_remaining_health(enemy_a)):
		return false
	# Should still have a second pending target
	if not _assert(MatchTiming.has_pending_summon_effect_target(match_state, pid), "Multi-battle: should have second pending target after first battle resolves."):
		return false
	# Resolve second battle target -> enemy_b
	var result2 := MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": enemy_b_id})
	if not _assert(bool(result2.get("is_valid", false)), "Multi-battle: second battle resolution should be valid."):
		return false
	# enemy_b should have taken 3 damage
	if not _assert(EvergreenRules.get_remaining_health(enemy_b) == 2, "Multi-battle: enemy_b should have 2 HP remaining after second battle (got %d)." % EvergreenRules.get_remaining_health(enemy_b)):
		return false
	# No more pending targets
	return _assert(not MatchTiming.has_pending_summon_effect_target(match_state, pid), "Multi-battle: no pending targets after both battles resolve.")


func _test_multi_battle_summon_skips_second_if_source_dies() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var enemy: Dictionary = ScenarioFixtures.player(match_state, 1)
	# Enemy creature strong enough to kill Hunter-Killers in the first battle
	var enemy_a := ScenarioFixtures.summon_creature(enemy, match_state, "big_enemy", "field", 10, 10)
	var enemy_b := ScenarioFixtures.summon_creature(enemy, match_state, "small_enemy", "field", 1, 1)
	var enemy_a_id := str(enemy_a.get("instance_id", ""))
	# Hunter-Killers with low health so it dies in the first battle
	var hunter := ScenarioFixtures.add_hand_card(player, "hunter_killers_dies", {
		"card_type": "creature", "cost": 0, "power": 3, "health": 4,
		"triggered_abilities": [
			{"family": "summon", "target_mode": "enemy_creature", "effects": [{"op": "battle_creature", "target": "chosen_target"}]},
			{"family": "summon", "target_mode": "enemy_creature", "effects": [{"op": "battle_creature", "target": "chosen_target"}]},
		],
	})
	var hunter_id := str(hunter.get("instance_id", ""))
	LaneRules.summon_from_hand(match_state, pid, hunter_id, "field")
	var lane_hunter := _find_lane_card(match_state, "field", pid, "test_hunter_killers_dies")
	MatchTiming._check_summon_effect_target_mode(match_state, lane_hunter)
	if not _assert(MatchTiming.has_pending_summon_effect_target(match_state, pid), "Multi-battle death: should have pending target after summon."):
		return false
	# Resolve first battle — Hunter-Killers fights 10/10, should die
	var result1 := MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": enemy_a_id})
	if not _assert(bool(result1.get("is_valid", false)), "Multi-battle death: first battle resolution should be valid."):
		return false
	# Hunter-Killers should be dead
	var loc := MatchMutations.find_card_location(match_state, hunter_id)
	if not _assert(str(loc.get("zone", "")) == "discard", "Multi-battle death: Hunter-Killers should be in discard after fighting 10/10."):
		return false
	# Second pending entry exists but source is dead, so decline should clear it
	if MatchTiming.has_pending_summon_effect_target(match_state, pid):
		MatchTiming.decline_pending_summon_effect_target(match_state, pid)
	return _assert(not MatchTiming.has_pending_summon_effect_target(match_state, pid), "Multi-battle death: no pending targets after source creature dies.")


func _test_discard_from_hand_filter_picks_highest_cost_action() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var opp_id := str(opponent.get("player_id", ""))
	# Give opponent a mix of cards: creature, cheap action, expensive action
	var opp_creature := ScenarioFixtures.add_hand_card(opponent, "opp_creature", {"card_type": "creature", "cost": 10})
	var opp_cheap_action := ScenarioFixtures.add_hand_card(opponent, "opp_cheap_action", {"card_type": "action", "cost": 2})
	var opp_expensive_action := ScenarioFixtures.add_hand_card(opponent, "opp_expensive_action", {"card_type": "action", "cost": 7, "name": "Javelin of Destruction"})
	var expensive_id := str(opp_expensive_action.get("instance_id", ""))
	# Player summons creature with discard_from_hand filter: highest cost action
	var magus := ScenarioFixtures.add_hand_card(player, "test_magus", {
		"card_type": "creature", "cost": 0, "power": 5, "health": 5,
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "discard_from_hand", "target_player": "opponent", "filter": {"card_type": "action", "highest_cost": true}}]}],
	})
	LaneRules.summon_from_hand(match_state, pid, str(magus.get("instance_id", "")), "field", {})
	# Verify: expensive action was discarded, cheap action and creature remain
	var opp_hand_ids: Array = []
	for c in opponent.get("hand", []):
		opp_hand_ids.append(str(c.get("instance_id", "")))
	if not _assert(not opp_hand_ids.has(expensive_id), "Discard filter: highest cost action should be removed from hand."):
		return false
	if not _assert(opp_hand_ids.has(str(opp_creature.get("instance_id", ""))), "Discard filter: creature should remain in hand."):
		return false
	if not _assert(opp_hand_ids.has(str(opp_cheap_action.get("instance_id", ""))), "Discard filter: cheap action should remain in hand."):
		return false
	# Verify: card_discarded event has revealed_card and controller_player_id
	var found_reveal := false
	for evt in match_state.get("event_log", []):
		if str(evt.get("event_type", "")) == "card_discarded" and str(evt.get("instance_id", "")) == expensive_id:
			if not _assert(not evt.get("revealed_card", {}).is_empty(), "Discard filter: card_discarded event should have revealed_card."):
				return false
			if not _assert(str(evt.get("controller_player_id", "")) == pid, "Discard filter: controller_player_id should be the summoning player."):
				return false
			if not _assert(str(evt.get("player_id", "")) == opp_id, "Discard filter: player_id should be the opponent."):
				return false
			found_reveal = true
			break
	return _assert(found_reveal, "Discard filter: should find card_discarded event with reveal data.")