extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("LANE_RULES_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_lane_state_tracks_capacity_and_metadata() and
		_test_field_summon_places_creature_without_cover() and
		_test_shadow_lane_grants_cover_except_for_guard() and
		_test_lane_capacity_and_slot_validation() and
		_test_move_between_lanes_updates_slots_and_shadow_cover() and
		_test_sacrifice_summon_into_full_lane() and
		_test_sacrifice_summon_preserves_slot_position() and
		_test_sacrifice_summon_publishes_correct_events() and
		_test_sacrifice_summon_rejects_wrong_lane() and
		_test_sacrifice_summon_rejects_non_full_lane() and
		_test_dementia_lane_damages_opponent_on_turn_start() and
		_test_dementia_lane_no_damage_when_opponent_has_highest() and
		_test_dementia_lane_no_damage_on_tie() and
		_test_dementia_lane_no_damage_when_empty() and
		_test_mania_lane_draws_card_for_highest_health() and
		_test_mania_lane_no_draw_on_tie() and
		_test_mania_lane_no_draw_when_opponent_has_highest() and
		_test_mania_lane_no_draw_when_empty() and
		_test_armor_lane_doubles_health_on_summon() and
		_test_armor_lane_does_not_affect_other_lane() and
		_test_armor_lane_both_players_get_doubled() and
		_test_armory_lane_buffs_single_creature_on_summon() and
		_test_armory_lane_does_not_affect_other_lane() and
		_test_armory_lane_both_players_get_buff() and
		_test_armory_lane_buffs_random_when_multiple_creatures() and
		_test_ballista_tower_damages_opponent_when_most_creatures() and
		_test_ballista_tower_no_damage_on_tie() and
		_test_ballista_tower_no_damage_when_opponent_has_more() and
		_test_ballista_tower_no_damage_when_empty() and
		_test_barracks_draws_on_high_power_summon() and
		_test_barracks_no_draw_on_low_power() and
		_test_campfire_shares_keywords() and
		_test_flanking_buffs_other_lane() and
		_test_fortifications_buffs_guard() and
		_test_fortifications_no_buff_without_guard() and
		_test_fountain_grants_ward_low_power() and
		_test_fountain_no_ward_high_power() and
		_test_killing_field_grants_power_bonus() and
		_test_king_of_hill_grants_guard_high_cost() and
		_test_king_of_hill_no_guard_low_cost() and
		_test_liquid_courage_buffs_on_damage() and
		_test_lucky_grants_random_keyword() and
		_test_masquerade_ball_buffs_on_move() and
		_test_order_sets_stats_to_cost() and
		_test_renewal_grants_regenerate() and
		_test_siege_grants_breakthrough() and
		_test_surplus_reduces_hand_card_cost() and
		_test_temple_heals_on_summon() and
		_test_torment_damages_on_summon() and
		_test_venom_grants_lethal() and
		_test_warzone_damages_opponent_on_summon() and
		_test_sewer_blocks_high_health() and
		_test_sewer_allows_low_health() and
		_test_graveyard_spawns_draugr_on_death() and
		_test_graveyard_spawns_draugr_on_second_death() and
		_test_graveyard_dual_death_spawns_both_draugrs() and
		_test_graveyard_draugr_has_summoning_sickness() and
		_test_heist_lane_grants_magicka_on_pilfer() and
		_test_heist_lane_no_magicka_in_other_lane() and
		_test_madness_lane_transforms_on_pilfer() and
		_test_madness_lane_no_transform_in_other_lane() and
		_test_madness_lane_transformed_creature_has_summoning_sickness() and
		_test_madness_lane_transformed_charge_creature_can_attack() and
		_test_plunder_lane_attaches_item_on_summon() and
		_test_plunder_lane_does_not_affect_other_lane() and
		_test_plunder_lane_both_players_get_items() and
		_test_reanimation_resurrects_as_1_1() and
		_test_reanimation_does_not_resurrect_twice() and
		_test_reanimation_does_not_affect_other_lane() and
		_test_reanimation_has_summoning_sickness() and
		_test_reanimation_charge_can_attack_immediately()
	)


func _test_lane_state_tracks_capacity_and_metadata() -> bool:
	var match_state := _build_match()
	var player_id: String = match_state["players"][0]["player_id"]
	var field_occupancy := LaneRules.get_lane_occupancy(match_state, "field", player_id)
	var shadow_lane: Dictionary = match_state["lanes"][1]

	return (
		_assert(field_occupancy["is_valid"], "Expected field lane occupancy lookup to succeed.") and
		_assert(field_occupancy["occupancy"] == 0, "Empty lanes should report zero occupants.") and
		_assert(field_occupancy["slot_capacity"] == 4, "Standard lanes should expose four slots.") and
		_assert(field_occupancy["open_slot_indices"] == [0], "An empty lane should report a single insertion point at index zero.") and
		_assert(str(shadow_lane["lane_rule_payload"].get("description", "")).contains("Cover"), "Shadow lane payload should carry its data-driven rules description.")
	)


func _test_field_summon_places_creature_without_cover() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	var creature := _append_creature_to_hand(player, "field_summon")
	var result := LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], "field")

	if not (
		_assert(result["is_valid"], "Expected field-lane summon to succeed.") and
		_assert(not result["granted_cover"], "Field-lane summons should not gain Cover.") and
		_assert(player["hand"].find(creature) == -1, "Summoned creatures should leave the hand.")
	):
		return false

	var lane_card = match_state["lanes"][0]["player_slots"][player["player_id"]][0]
	return (
		_assert(lane_card != null, "Field lane should contain the summoned creature.") and
		_assert(lane_card["zone"] == "lane", "Summoned creature should be placed onto the board.") and
		_assert(lane_card["lane_id"] == "field" and lane_card["slot_index"] == 0, "Summoned creature should track its lane position.") and
		_assert(not _has_status(lane_card, "cover"), "Field lane should not grant Cover.")
	)


func _test_shadow_lane_grants_cover_except_for_guard() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	var shadow_creature := _append_creature_to_hand(player, "shadow_summon")
	var shadow_result := LaneRules.summon_from_hand(match_state, player["player_id"], shadow_creature["instance_id"], "shadow")
	if not _assert(shadow_result["is_valid"], "Expected shadow-lane summon to succeed."):
		return false

	# Cover is now applied via the generic lane effect trigger system
	var shadow_lane_card = match_state["lanes"][1]["player_slots"][player["player_id"]][0]
	if not (
		_assert(_has_status(shadow_lane_card, "cover"), "Shadow-lane summon should carry the Cover status marker.") and
		_assert(int(shadow_lane_card.get("cover_expires_on_turn", -1)) == int(match_state.get("turn_number", 0)) + 1, "Shadow Cover should record a one-turn expiry from the current turn.")
	):
		return false

	var guard_creature := _append_creature_to_hand(player, "guard_shadow", ["guard"])
	var guard_result := LaneRules.summon_from_hand(match_state, player["player_id"], guard_creature["instance_id"], "shadow")
	if not _assert(guard_result["is_valid"], "Guard creature should still be summonable into shadow."):
		return false

	var guard_lane_card = match_state["lanes"][1]["player_slots"][player["player_id"]][1]
	return (
		_assert(not _has_status(guard_lane_card, "cover"), "Guard creatures in shadow should not receive Cover status.") and
		_assert(not guard_lane_card.has("cover_expires_on_turn"), "Guard creatures should not get a shadow Cover expiry marker.")
	)


func _test_lane_capacity_and_slot_validation() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	for slot_index in range(4):
		var creature := _append_creature_to_hand(player, "capacity_%d" % slot_index)
		var summon_result := LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], "field", {
			"slot_index": slot_index,
		})
		if not _assert(summon_result["is_valid"], "Expected slot %d summon to succeed while filling the lane." % slot_index):
			return false

	var field_occupancy := LaneRules.get_lane_occupancy(match_state, "field", player["player_id"])
	if not _assert(field_occupancy["occupancy"] == 4, "Field lane should report four occupants once filled."):
		return false

	var overflow_creature := _append_creature_to_hand(player, "overflow")
	var overflow_result := LaneRules.validate_summon_from_hand(match_state, player["player_id"], overflow_creature["instance_id"], "field")
	if not _assert(not overflow_result["is_valid"], "Validation should reject placement when the lane is already at capacity."):
		return false

	var full_lane_creature := _append_creature_to_hand(player, "full_lane")
	var full_lane_result := LaneRules.validate_summon_from_hand(match_state, player["player_id"], full_lane_creature["instance_id"], "field")
	return _assert(not full_lane_result["is_valid"], "Validation should reject placement into a full lane.")


func _test_move_between_lanes_updates_slots_and_shadow_cover() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	var creature := _append_creature_to_hand(player, "move_target")
	var summon_result := LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], "field")
	if not _assert(summon_result["is_valid"], "Move fixture should first summon the creature into field."):
		return false

	var move_result := LaneRules.move_creature(match_state, player["player_id"], creature["instance_id"], "shadow")
	if not _assert(move_result["is_valid"], "Expected cross-lane move to succeed."):
		return false

	var field_slots: Array = match_state["lanes"][0]["player_slots"][player["player_id"]]
	var shadow_slots: Array = match_state["lanes"][1]["player_slots"][player["player_id"]]
	return (
		_assert(field_slots.size() == 0, "Source lane should be empty after moving the only creature out.") and
		_assert(shadow_slots.size() == 1, "Destination lane should contain exactly the moved creature.") and
		_assert(shadow_slots[0]["lane_id"] == "shadow" and shadow_slots[0]["slot_index"] == 0, "Moved creature should track its new lane position.") and
		_assert(_has_status(shadow_slots[0], "cover"), "Moving into shadow should apply Cover status.")
	)


func _test_sacrifice_summon_into_full_lane() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	var player_id: String = player["player_id"]
	# Fill the field lane to capacity (4 creatures)
	var creatures: Array = []
	for i in range(4):
		var creature := _append_creature_to_hand(player, "sac_fill_%d" % i)
		var summon_result := LaneRules.summon_from_hand(match_state, player_id, creature["instance_id"], "field")
		if not _assert(summon_result["is_valid"], "Expected slot %d fill to succeed." % i):
			return false
		creatures.append(creature)
	# Verify lane is full
	var field_slots: Array = match_state["lanes"][0]["player_slots"][player_id]
	if not _assert(field_slots.size() == 4, "Field lane should be full with 4 creatures."):
		return false
	# Summon a new creature by sacrificing the first one
	var new_creature := _append_creature_to_hand(player, "sac_new")
	var sacrifice_target_id: String = creatures[0]["instance_id"]
	var result := LaneRules.summon_with_sacrifice(match_state, player_id, new_creature["instance_id"], "field", sacrifice_target_id)
	if not _assert(result["is_valid"], "Sacrifice-summon should succeed."):
		return false
	# Verify lane still has 4 creatures and new creature is present
	field_slots = match_state["lanes"][0]["player_slots"][player_id]
	if not _assert(field_slots.size() == 4, "Field lane should still have 4 creatures after sacrifice-summon."):
		return false
	var found_new := false
	var found_sacrificed := false
	for slot_card in field_slots:
		if str(slot_card.get("instance_id", "")) == new_creature["instance_id"]:
			found_new = true
		if str(slot_card.get("instance_id", "")) == sacrifice_target_id:
			found_sacrificed = true
	if not _assert(found_new, "New creature should be in the lane after sacrifice-summon."):
		return false
	if not _assert(not found_sacrificed, "Sacrificed creature should not be in the lane."):
		return false
	# Verify sacrificed creature is in discard
	var discard: Array = player.get("discard", [])
	var in_discard := false
	for card in discard:
		if str(card.get("instance_id", "")) == sacrifice_target_id:
			in_discard = true
			break
	return _assert(in_discard, "Sacrificed creature should be in the discard pile.")


func _test_sacrifice_summon_preserves_slot_position() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	var player_id: String = player["player_id"]
	# Fill the field lane to capacity (4 creatures)
	var creatures: Array = []
	for i in range(4):
		var creature := _append_creature_to_hand(player, "sac_pos_%d" % i)
		var summon_result := LaneRules.summon_from_hand(match_state, player_id, creature["instance_id"], "field")
		if not _assert(summon_result["is_valid"], "Expected slot %d fill to succeed." % i):
			return false
		creatures.append(creature)
	# Sacrifice creature at slot 1 (middle) and replace with new creature
	var new_creature := _append_creature_to_hand(player, "sac_pos_new")
	var sacrifice_target_id: String = creatures[1]["instance_id"]
	var result := LaneRules.summon_with_sacrifice(match_state, player_id, new_creature["instance_id"], "field", sacrifice_target_id)
	if not _assert(result["is_valid"], "Sacrifice-summon should succeed."):
		return false
	if not _assert(int(result.get("slot_index", -1)) == 1, "New creature should be placed at slot 1 (same as sacrificed)."):
		return false
	var field_slots: Array = match_state["lanes"][0]["player_slots"][player_id]
	var actual_id := str(field_slots[1].get("instance_id", ""))
	return _assert(actual_id == new_creature["instance_id"], "New creature should physically occupy slot 1 in the lane array.")


func _test_sacrifice_summon_publishes_correct_events() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	var player_id: String = player["player_id"]
	for i in range(4):
		var creature := _append_creature_to_hand(player, "sac_evt_%d" % i)
		LaneRules.summon_from_hand(match_state, player_id, creature["instance_id"], "field")
	var new_creature := _append_creature_to_hand(player, "sac_evt_new")
	var sacrifice_id: String = match_state["lanes"][0]["player_slots"][player_id][0]["instance_id"]
	var result := LaneRules.summon_with_sacrifice(match_state, player_id, new_creature["instance_id"], "field", sacrifice_id)
	if not _assert(result["is_valid"], "Sacrifice-summon for event test should succeed."):
		return false
	var events: Array = result.get("events", [])
	# Find event indices
	var sacrifice_idx := -1
	var played_idx := -1
	var summoned_idx := -1
	for i in range(events.size()):
		var evt_type := str(events[i].get("event_type", ""))
		if evt_type == "card_sacrificed" and sacrifice_idx == -1:
			sacrifice_idx = i
		if evt_type == "card_played" and played_idx == -1:
			played_idx = i
		if evt_type == "creature_summoned" and summoned_idx == -1:
			summoned_idx = i
	return (
		_assert(sacrifice_idx >= 0, "Should publish card_sacrificed event.") and
		_assert(played_idx >= 0, "Should publish card_played event.") and
		_assert(summoned_idx >= 0, "Should publish creature_summoned event.") and
		_assert(sacrifice_idx < played_idx, "card_sacrificed should come before card_played.") and
		_assert(played_idx < summoned_idx, "card_played should come before creature_summoned.")
	)


func _test_sacrifice_summon_rejects_wrong_lane() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	var player_id: String = player["player_id"]
	# Fill field lane
	for i in range(4):
		var creature := _append_creature_to_hand(player, "sac_wl_%d" % i)
		LaneRules.summon_from_hand(match_state, player_id, creature["instance_id"], "field")
	# Put a creature in shadow lane
	var shadow_creature := _append_creature_to_hand(player, "sac_shadow")
	LaneRules.summon_from_hand(match_state, player_id, shadow_creature["instance_id"], "shadow")
	# Try to sacrifice the shadow creature while summoning into field
	var new_creature := _append_creature_to_hand(player, "sac_wl_new")
	var result := LaneRules.validate_summon_with_sacrifice(match_state, player_id, new_creature["instance_id"], "field", shadow_creature["instance_id"])
	return _assert(not result["is_valid"], "Should reject sacrifice of creature in a different lane.")


func _test_sacrifice_summon_rejects_non_full_lane() -> bool:
	var match_state := _build_match()
	var player: Dictionary = match_state["players"][0]
	var player_id: String = player["player_id"]
	# Put only 2 creatures in field (not full)
	var creatures: Array = []
	for i in range(2):
		var creature := _append_creature_to_hand(player, "sac_nf_%d" % i)
		LaneRules.summon_from_hand(match_state, player_id, creature["instance_id"], "field")
		creatures.append(creature)
	var new_creature := _append_creature_to_hand(player, "sac_nf_new")
	var result := LaneRules.validate_summon_with_sacrifice(match_state, player_id, new_creature["instance_id"], "field", creatures[0]["instance_id"])
	return _assert(not result["is_valid"], "Should reject sacrifice-summon when lane is not full.")


func _test_dementia_lane_damages_opponent_on_turn_start() -> bool:
	var match_state := _build_dementia_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Player 1 has a 5-power creature, player 2 has a 3-power creature
	_summon_creature(player_1, match_state, "p1_big", "dementia", 5, 3)
	_summon_creature(player_2, match_state, "p2_small", "dementia", 3, 3)
	var p2_health_before := int(player_2.get("health", 0))
	# End player 1's turn, start player 2's turn — player 2 does NOT have highest power
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	var p2_health_after_p2_turn := int(player_2.get("health", 0))
	# Player 2's turn started — player 1 has highest power so no damage to player 1
	var p1_health_after_p2_turn := int(player_1.get("health", 0))
	# End player 2's turn, start player 1's turn — player 1 HAS highest power
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var p2_health_after_p1_turn := int(player_2.get("health", 0))
	return (
		_assert(p2_health_after_p2_turn == p2_health_before, "Player 2 should not take dementia damage on their own turn when player 1 has highest power.") and
		_assert(p1_health_after_p2_turn == 30, "Player 1 should not take dementia damage on player 2's turn since player 2 doesn't have highest power.") and
		_assert(p2_health_after_p1_turn == p2_health_before - 3, "Player 2 should take 3 dementia damage when player 1 starts their turn with the highest power creature.")
	)


func _test_dementia_lane_no_damage_when_opponent_has_highest() -> bool:
	var match_state := _build_dementia_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Only player 2 has a creature
	_summon_creature(player_2, match_state, "p2_only", "dementia", 4, 4)
	var p1_health_before := int(player_1.get("health", 0))
	var p2_health_before := int(player_2.get("health", 0))
	# End player 1's turn (player 1 has no creature, so no damage on this turn)
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	# Player 2's turn starts — player 2 has highest power, so player 1 takes 3 damage
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	return (
		_assert(int(player_1.get("health", 0)) == p1_health_before - 3, "Player 1 should take 3 damage when player 2 has the highest power creature on player 2's turn.") and
		_assert(int(player_2.get("health", 0)) == p2_health_before, "Player 2 should not take damage when they own the highest power creature.")
	)


func _test_dementia_lane_no_damage_on_tie() -> bool:
	var match_state := _build_dementia_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Both have creatures with equal power
	_summon_creature(player_1, match_state, "p1_tied", "dementia", 4, 3)
	_summon_creature(player_2, match_state, "p2_tied", "dementia", 4, 3)
	var p1_health_before := int(player_1.get("health", 0))
	var p2_health_before := int(player_2.get("health", 0))
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	return (
		_assert(int(player_1.get("health", 0)) == p1_health_before, "Player 1 should not take damage when powers are tied.") and
		_assert(int(player_2.get("health", 0)) == p2_health_before, "Player 2 should not take damage when powers are tied.")
	)


func _test_dementia_lane_no_damage_when_empty() -> bool:
	var match_state := _build_dementia_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	var p1_health_before := int(player_1.get("health", 0))
	var p2_health_before := int(player_2.get("health", 0))
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	return (
		_assert(int(player_1.get("health", 0)) == p1_health_before, "No damage when dementia lane is empty (player 1).") and
		_assert(int(player_2.get("health", 0)) == p2_health_before, "No damage when dementia lane is empty (player 2).")
	)


func _test_mania_lane_draws_card_for_highest_health() -> bool:
	var match_state := _build_mania_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Player 1 has a higher-health creature
	_summon_creature(player_1, match_state, "p1_healthy", "mania", 2, 6)
	_summon_creature(player_2, match_state, "p2_weak", "mania", 2, 3)
	# End player 1's turn, start player 2's — player 2 does NOT have highest health
	var p2_hand_before_p2_turn := int(player_2["hand"].size())
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	var p2_hand_after_p2_turn := int(player_2["hand"].size())
	# End player 2's turn, start player 1's — player 1 HAS highest health
	var p1_hand_before_p1_turn := int(player_1["hand"].size())
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var p1_hand_after_p1_turn := int(player_1["hand"].size())
	return (
		_assert(p2_hand_after_p2_turn == p2_hand_before_p2_turn + 1, "Player 2 should only get normal turn draw (no mania bonus) when player 1 has highest health.") and
		_assert(p1_hand_after_p1_turn == p1_hand_before_p1_turn + 2, "Player 1 should draw normal + mania card when starting their turn with the highest-health creature.")
	)


func _test_mania_lane_no_draw_on_tie() -> bool:
	var match_state := _build_mania_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Both have equal health creatures
	_summon_creature(player_1, match_state, "p1_tied", "mania", 2, 5)
	_summon_creature(player_2, match_state, "p2_tied", "mania", 2, 5)
	var p1_hand_before := int(player_1["hand"].size())
	var p2_hand_before := int(player_2["hand"].size())
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	var p2_hand_after := int(player_2["hand"].size())
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var p1_hand_after := int(player_1["hand"].size())
	# Each player draws 1 card from normal turn draw, but no extra from mania
	return (
		_assert(p1_hand_after == p1_hand_before + 1, "Player 1 should only get the normal turn draw when health is tied (no mania bonus).") and
		_assert(p2_hand_after == p2_hand_before + 1, "Player 2 should only get the normal turn draw when health is tied (no mania bonus).")
	)


func _test_mania_lane_no_draw_when_opponent_has_highest() -> bool:
	var match_state := _build_mania_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Only player 2 has a creature
	_summon_creature(player_2, match_state, "p2_only", "mania", 2, 6)
	var p1_hand_before := int(player_1["hand"].size())
	var p2_hand_before := int(player_2["hand"].size())
	# End player 1's turn (no creature, no draw)
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	var p2_hand_after_p2_turn := int(player_2["hand"].size())
	# Player 2's turn starts — player 2 has highest health, draws extra
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var p1_hand_after := int(player_1["hand"].size())
	return (
		_assert(p2_hand_after_p2_turn == p2_hand_before + 2, "Player 2 should draw an extra card from mania when they have the highest-health creature on their turn.") and
		_assert(p1_hand_after == p1_hand_before + 1, "Player 1 should only get the normal turn draw when they have no creatures in the mania lane.")
	)


func _test_mania_lane_no_draw_when_empty() -> bool:
	var match_state := _build_mania_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	var p1_hand_before := int(player_1["hand"].size())
	var p2_hand_before := int(player_2["hand"].size())
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	var p2_hand_after := int(player_2["hand"].size())
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var p1_hand_after := int(player_1["hand"].size())
	return (
		_assert(p1_hand_after == p1_hand_before + 1, "No extra draw when mania lane is empty (player 1).") and
		_assert(p2_hand_after == p2_hand_before + 1, "No extra draw when mania lane is empty (player 2).")
	)


func _test_armor_lane_doubles_health_on_summon() -> bool:
	var match_state := _build_armor_match()
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "armor_target", "armor", 2, 3)
	var final_health := EvergreenRules.get_health(creature)
	return _assert(final_health == 6, "Armor lane should double creature health from 3 to 6, got %d." % final_health)


func _test_armor_lane_does_not_affect_other_lane() -> bool:
	var match_state := _build_armor_match()
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "field_target", "field", 2, 3)
	var final_health := EvergreenRules.get_health(creature)
	return _assert(final_health == 3, "Summoning in field lane should not double health, got %d." % final_health)


func _test_armor_lane_both_players_get_doubled() -> bool:
	var match_state := _build_armor_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	var c1 := _summon_creature(player_1, match_state, "p1_armor", "armor", 2, 4)
	var c2 := _summon_creature(player_2, match_state, "p2_armor", "armor", 2, 5)
	var h1 := EvergreenRules.get_health(c1)
	var h2 := EvergreenRules.get_health(c2)
	return (
		_assert(h1 == 8, "Player 1 creature health should double from 4 to 8, got %d." % h1) and
		_assert(h2 == 10, "Player 2 creature health should double from 5 to 10, got %d." % h2)
	)


func _test_armory_lane_buffs_single_creature_on_summon() -> bool:
	var match_state := _build_armory_match()
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "armory_solo", "armory", 2, 3)
	var final_power := EvergreenRules.get_power(creature)
	var final_health := EvergreenRules.get_health(creature)
	return (
		_assert(final_power == 3, "Armory lane should buff power from 2 to 3, got %d." % final_power) and
		_assert(final_health == 4, "Armory lane should buff health from 3 to 4, got %d." % final_health)
	)


func _test_armory_lane_does_not_affect_other_lane() -> bool:
	var match_state := _build_armory_match()
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "field_no_buff", "field", 2, 3)
	var final_power := EvergreenRules.get_power(creature)
	var final_health := EvergreenRules.get_health(creature)
	return (
		_assert(final_power == 2, "Field lane should not buff power, got %d." % final_power) and
		_assert(final_health == 3, "Field lane should not buff health, got %d." % final_health)
	)


func _test_armory_lane_both_players_get_buff() -> bool:
	var match_state := _build_armory_match()
	var p1: Dictionary = match_state["players"][0]
	var p2: Dictionary = match_state["players"][1]
	var c1 := _summon_creature(p1, match_state, "p1_armory", "armory", 2, 2)
	var c2 := _summon_creature(p2, match_state, "p2_armory", "armory", 3, 3)
	var p1_power := EvergreenRules.get_power(c1)
	var p1_health := EvergreenRules.get_health(c1)
	var p2_power := EvergreenRules.get_power(c2)
	var p2_health := EvergreenRules.get_health(c2)
	return (
		_assert(p1_power == 3, "P1 creature power should be 3 (2+1), got %d." % p1_power) and
		_assert(p1_health == 3, "P1 creature health should be 3 (2+1), got %d." % p1_health) and
		_assert(p2_power == 4, "P2 creature power should be 4 (3+1), got %d." % p2_power) and
		_assert(p2_health == 4, "P2 creature health should be 4 (3+1), got %d." % p2_health)
	)


func _test_armory_lane_buffs_random_when_multiple_creatures() -> bool:
	var match_state := _build_armory_match()
	var player: Dictionary = match_state["players"][0]
	var c1 := _summon_creature(player, match_state, "armory_first", "armory", 2, 2)
	# c1 gets +1/+1 from its own summon (only creature), so now 3/3
	var c2 := _summon_creature(player, match_state, "armory_second", "armory", 2, 2)
	# c2's summon triggers buff on a random friendly creature (c1 or c2)
	var total_power := EvergreenRules.get_power(c1) + EvergreenRules.get_power(c2)
	var total_health := EvergreenRules.get_health(c1) + EvergreenRules.get_health(c2)
	# c1 base 2+1(own summon) = 3, c2 base 2+1(c2 summon buff) = 3 OR c1 = 3+1 = 4, c2 base 2
	# Total: 3+3 = 6 power, 3+3 = 6 health (regardless of which got the c2 buff)
	return (
		_assert(total_power == 6, "Total power across both creatures should be 6 (2+2 base + 2 buffs), got %d." % total_power) and
		_assert(total_health == 6, "Total health across both creatures should be 6 (2+2 base + 2 buffs), got %d." % total_health)
	)


func _build_armory_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "armory"
	lane["lane_type"] = "armory"
	lane["lane_rule_payload"] = {
		"display_name": "Armory",
		"description": "After you summon a creature here, a random friendly creature here gets +1/+1.",
		"icon": "res://assets/images/lanes/armory.png",
		"implementation_bucket": "mvp",
		"availability": ["arena"],
		"source_ids": ["uesp_lanes"],
		"effects": [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_armory_buff_random"}]}],
	}
	return match_state


func _test_ballista_tower_damages_opponent_when_most_creatures() -> bool:
	var match_state := _build_ballista_tower_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Player 1 has 2 creatures, player 2 has 1
	_summon_creature(player_1, match_state, "p1_bt_a", "ballista_tower", 2, 2)
	_summon_creature(player_1, match_state, "p1_bt_b", "ballista_tower", 2, 2)
	_summon_creature(player_2, match_state, "p2_bt_a", "ballista_tower", 2, 2)
	var p2_health_before := int(player_2.get("health", 0))
	# End p1 turn, start p2 turn — p2 does NOT have most creatures
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	var p2_health_after_p2_turn := int(player_2.get("health", 0))
	# End p2 turn, start p1 turn — p1 HAS most creatures
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var p2_health_after_p1_turn := int(player_2.get("health", 0))
	return (
		_assert(p2_health_after_p2_turn == p2_health_before, "Player 2 should not take ballista damage on their own turn when player 1 has more creatures.") and
		_assert(p2_health_after_p1_turn == p2_health_before - 2, "Player 2 should take 2 ballista damage when player 1 starts turn with more creatures.")
	)


func _test_ballista_tower_no_damage_on_tie() -> bool:
	var match_state := _build_ballista_tower_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	_summon_creature(player_1, match_state, "p1_bt_tied", "ballista_tower", 2, 2)
	_summon_creature(player_2, match_state, "p2_bt_tied", "ballista_tower", 2, 2)
	var p1_health_before := int(player_1.get("health", 0))
	var p2_health_before := int(player_2.get("health", 0))
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	return (
		_assert(int(player_1.get("health", 0)) == p1_health_before, "Player 1 should not take damage when creature counts are tied.") and
		_assert(int(player_2.get("health", 0)) == p2_health_before, "Player 2 should not take damage when creature counts are tied.")
	)


func _test_ballista_tower_no_damage_when_opponent_has_more() -> bool:
	var match_state := _build_ballista_tower_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Only player 2 has creatures
	_summon_creature(player_2, match_state, "p2_bt_only", "ballista_tower", 2, 2)
	var p1_health_before := int(player_1.get("health", 0))
	var p2_health_before := int(player_2.get("health", 0))
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	# Player 2 starts turn with most creatures — player 1 takes damage
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	return (
		_assert(int(player_1.get("health", 0)) == p1_health_before - 2, "Player 1 should take 2 ballista damage when player 2 has more creatures on player 2's turn.") and
		_assert(int(player_2.get("health", 0)) == p2_health_before, "Player 2 should not take damage when they have the most creatures.")
	)


func _test_ballista_tower_no_damage_when_empty() -> bool:
	var match_state := _build_ballista_tower_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	var p1_health_before := int(player_1.get("health", 0))
	var p2_health_before := int(player_2.get("health", 0))
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	return (
		_assert(int(player_1.get("health", 0)) == p1_health_before, "No damage when ballista tower lane is empty (player 1).") and
		_assert(int(player_2.get("health", 0)) == p2_health_before, "No damage when ballista tower lane is empty (player 2).")
	)


func _build_ballista_tower_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "ballista_tower"
	lane["lane_type"] = "ballista_tower"
	lane["lane_rule_payload"] = {
		"display_name": "Ballista Tower",
		"description": "At the start of your turn, if you have the most creatures here, deal 2 damage to the opponent.",
		"icon": "res://assets/images/lanes/ballista-tower.png",
		"implementation_bucket": "mvp",
		"availability": ["arena"],
		"source_ids": ["uesp_lanes"],
		"effects": [{"family": "start_of_turn", "match_role": "any_player", "effects": [{"op": "lane_ballista_damage", "amount": 2}]}],
	}
	return match_state


func _test_barracks_draws_on_high_power_summon() -> bool:
	var match_state := _build_lane_match("barracks", "Barracks", "After you summon a creature here with 4 or more power, draw a card.", ["arena", "gauntlet"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_barracks_draw", "min_power": 4}]}])
	var player: Dictionary = match_state["players"][0]
	var hand_before := int(player["hand"].size())
	_summon_creature(player, match_state, "barracks_big", "barracks", 4, 3)
	var hand_after := int(player["hand"].size())
	return _assert(hand_after == hand_before + 1, "Barracks should draw a card when summoning 4+ power creature (hand %d -> %d, expect +1 from draw)." % [hand_before, hand_after])


func _test_barracks_no_draw_on_low_power() -> bool:
	var match_state := _build_lane_match("barracks", "Barracks", "After you summon a creature here with 4 or more power, draw a card.", ["arena", "gauntlet"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_barracks_draw", "min_power": 4}]}])
	var player: Dictionary = match_state["players"][0]
	var hand_before := int(player["hand"].size())
	_summon_creature(player, match_state, "barracks_small", "barracks", 3, 3)
	var hand_after := int(player["hand"].size())
	return _assert(hand_after == hand_before, "Barracks should NOT draw when summoning creature with < 4 power (hand should stay same).")


func _test_campfire_shares_keywords() -> bool:
	var match_state := _build_lane_match("campfire", "Campfire", "After you summon a creature here, friendly creatures gain its keyword.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_campfire_share_keywords"}]}])
	var player: Dictionary = match_state["players"][0]
	var c1 := _summon_creature(player, match_state, "camp_first", "campfire", 2, 2)
	var c2 := _append_creature_to_hand(player, "camp_guard", ["guard"])
	c2["power"] = 2
	c2["health"] = 2
	LaneRules.summon_from_hand(match_state, player["player_id"], c2["instance_id"], "campfire")
	# c1 should now have guard from campfire sharing
	return _assert(EvergreenRules.has_keyword(c1, "guard"), "Campfire should share the summoned creature's keywords to existing friendlies.")


func _test_flanking_buffs_other_lane() -> bool:
	var match_state := _build_lane_match("flanking", "Flanking", "After a creature is summoned here, give friendly creatures in the other lane +1/+0.", ["chaos_arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_flanking_buff_other_lane"}]}])
	var player: Dictionary = match_state["players"][0]
	var field_creature := _summon_creature(player, match_state, "field_flank", "field", 2, 2)
	var field_power_before := EvergreenRules.get_power(field_creature)
	_summon_creature(player, match_state, "flanking_trigger", "flanking", 2, 2)
	var field_power_after := EvergreenRules.get_power(field_creature)
	return _assert(field_power_after == field_power_before + 1, "Flanking should give +1/+0 to creatures in the other lane, got %d -> %d." % [field_power_before, field_power_after])


func _test_fortifications_buffs_guard() -> bool:
	var match_state := _build_lane_match("fortifications", "Fortifications", "Guards here have +1/+1.", ["arena", "gauntlet"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_fortifications_buff_guard"}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _append_creature_to_hand(player, "fort_guard", ["guard"])
	creature["power"] = 3
	creature["health"] = 3
	LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], "fortifications")
	return (
		_assert(EvergreenRules.get_power(creature) == 4, "Fortifications should give Guard +1 power, got %d." % EvergreenRules.get_power(creature)) and
		_assert(EvergreenRules.get_health(creature) == 4, "Fortifications should give Guard +1 health, got %d." % EvergreenRules.get_health(creature))
	)


func _test_fortifications_no_buff_without_guard() -> bool:
	var match_state := _build_lane_match("fortifications", "Fortifications", "Guards here have +1/+1.", ["arena", "gauntlet"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_fortifications_buff_guard"}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "fort_no_guard", "fortifications", 3, 3)
	return _assert(EvergreenRules.get_power(creature) == 3, "Fortifications should NOT buff non-Guard creatures, got power %d." % EvergreenRules.get_power(creature))


func _test_fountain_grants_ward_low_power() -> bool:
	var match_state := _build_lane_match("fountain", "Fountain", "Creatures with 2 power or less summoned here gain a Ward.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_fountain_grant_ward", "max_power": 2}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "fountain_low", "fountain", 2, 3)
	return _assert(EvergreenRules.has_keyword(creature, "ward"), "Fountain should grant Ward to creatures with 2 or less power.")


func _test_fountain_no_ward_high_power() -> bool:
	var match_state := _build_lane_match("fountain", "Fountain", "Creatures with 2 power or less summoned here gain a Ward.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_fountain_grant_ward", "max_power": 2}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "fountain_high", "fountain", 3, 3)
	return _assert(not EvergreenRules.has_keyword(creature, "ward"), "Fountain should NOT grant Ward to creatures with more than 2 power.")


func _test_killing_field_grants_power_bonus() -> bool:
	var match_state := _build_lane_match("killing_field", "Killing Field", "Creatures here have +1/+0.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_stat_bonus", "power": 1, "health": 0}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "kf_creature", "killing_field", 3, 3)
	return (
		_assert(EvergreenRules.get_power(creature) == 4, "Killing Field should give +1 power, got %d." % EvergreenRules.get_power(creature)) and
		_assert(EvergreenRules.get_health(creature) == 3, "Killing Field should not change health, got %d." % EvergreenRules.get_health(creature))
	)


func _test_king_of_hill_grants_guard_high_cost() -> bool:
	var match_state := _build_lane_match("king_of_the_hill", "King of the Hill", "After a creature with cost 5 or greater is summoned here, give it Guard.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_king_of_hill_grant_guard", "min_cost": 5}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _append_creature_to_hand(player, "koth_big")
	creature["cost"] = 5
	creature["power"] = 4
	creature["health"] = 4
	LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], "king_of_the_hill")
	return _assert(EvergreenRules.has_keyword(creature, "guard"), "King of the Hill should grant Guard to creatures with cost >= 5.")


func _test_king_of_hill_no_guard_low_cost() -> bool:
	var match_state := _build_lane_match("king_of_the_hill", "King of the Hill", "After a creature with cost 5 or greater is summoned here, give it Guard.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_king_of_hill_grant_guard", "min_cost": 5}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "koth_small", "king_of_the_hill", 3, 3)
	return _assert(not EvergreenRules.has_keyword(creature, "guard"), "King of the Hill should NOT grant Guard to creatures with cost < 5.")


func _test_liquid_courage_buffs_on_damage() -> bool:
	var match_state := _build_lane_match("liquid_courage", "Liquid Courage", "After a creature here takes damage, it gains +2/+0.", ["story"], [{"family": "on_damage", "match_role": "any_player", "effects": [{"op": "lane_liquid_courage_buff", "power": 2}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "lc_target", "liquid_courage", 3, 5)
	var power_before := EvergreenRules.get_power(creature)
	# Simulate damage by applying it and publishing a damage_resolved event
	EvergreenRules.apply_damage_to_creature(creature, 1)
	var damage_event := {"event_type": "damage_resolved", "source_instance_id": "test_source", "target_instance_id": str(creature.get("instance_id", "")), "target_type": "creature", "amount": 1, "damage_kind": "combat"}
	MatchTiming.publish_events(match_state, [damage_event])
	var power_after := EvergreenRules.get_power(creature)
	return _assert(power_after == power_before + 2, "Liquid Courage should give +2/+0 when creature takes damage, got %d -> %d." % [power_before, power_after])


func _test_lucky_grants_random_keyword() -> bool:
	var match_state := _build_lane_match("lucky", "Lucky", "Creatures summoned here gain a random keyword.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_lucky_random_keyword"}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "lucky_creature", "lucky", 2, 2)
	var has_any_keyword := false
	for kw in ["guard", "ward", "charge", "drain", "lethal", "breakthrough", "regenerate"]:
		if EvergreenRules.has_keyword(creature, kw):
			has_any_keyword = true
			break
	return _assert(has_any_keyword, "Lucky should grant at least one random keyword.")


func _test_masquerade_ball_buffs_on_move() -> bool:
	var match_state := _build_lane_match("masquerade_ball", "Masquerade Ball", "After a creature moves into this lane, give it +1/+1.", ["story"], [{"family": "on_move", "match_role": "any_player", "effects": [{"op": "lane_stat_bonus", "power": 1, "health": 1}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "masq_mover", "field", 2, 2)
	var power_before := EvergreenRules.get_power(creature)
	var health_before := EvergreenRules.get_health(creature)
	LaneRules.move_creature(match_state, player["player_id"], creature["instance_id"], "masquerade_ball")
	var power_after := EvergreenRules.get_power(creature)
	var health_after := EvergreenRules.get_health(creature)
	return (
		_assert(power_after == power_before + 1, "Masquerade Ball should give +1 power on move, got %d -> %d." % [power_before, power_after]) and
		_assert(health_after == health_before + 1, "Masquerade Ball should give +1 health on move, got %d -> %d." % [health_before, health_after])
	)


func _test_order_sets_stats_to_cost() -> bool:
	var match_state := _build_lane_match("order", "Order", "When a creature enters this lane, set its power and health equal to its cost.", ["story"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_order_set_stats_to_cost"}]}, {"family": "on_move", "match_role": "any_player", "effects": [{"op": "lane_order_set_stats_to_cost"}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _append_creature_to_hand(player, "order_creature")
	creature["cost"] = 5
	creature["power"] = 2
	creature["health"] = 8
	LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], "order")
	return (
		_assert(EvergreenRules.get_power(creature) == 5, "Order should set power to cost (5), got %d." % EvergreenRules.get_power(creature)) and
		_assert(EvergreenRules.get_health(creature) == 5, "Order should set health to cost (5), got %d." % EvergreenRules.get_health(creature))
	)


func _test_renewal_grants_regenerate() -> bool:
	var match_state := _build_lane_match("renewal", "Renewal", "Creatures here have Regenerate.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_grant_keyword", "keyword": "regenerate"}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "renewal_creature", "renewal", 2, 2)
	return _assert(EvergreenRules.has_keyword(creature, "regenerate"), "Renewal should grant Regenerate.")


func _test_siege_grants_breakthrough() -> bool:
	var match_state := _build_lane_match("siege", "Siege", "Creatures here have Breakthrough.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_grant_keyword", "keyword": "breakthrough"}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "siege_creature", "siege", 2, 2)
	return _assert(EvergreenRules.has_keyword(creature, "breakthrough"), "Siege should grant Breakthrough.")


func _test_surplus_reduces_hand_card_cost() -> bool:
	var match_state := _build_lane_match("surplus", "Surplus", "After you summon a creature here, reduce the cost of a random card in your hand by 1.", ["story", "arena", "gauntlet"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_surplus_reduce_cost"}]}])
	var player: Dictionary = match_state["players"][0]
	# Add a card to hand with known cost
	var hand_card := _append_creature_to_hand(player, "surplus_target")
	hand_card["cost"] = 5
	var cost_before := int(hand_card.get("cost", 0))
	_summon_creature(player, match_state, "surplus_trigger", "surplus", 2, 2)
	# The hand card's cost should have been reduced (it's the only one with cost > 0)
	var cost_after := int(hand_card.get("cost", 0))
	return _assert(cost_after == cost_before - 1, "Surplus should reduce a hand card's cost by 1, got %d -> %d." % [cost_before, cost_after])


func _test_temple_heals_on_summon() -> bool:
	var match_state := _build_lane_match("temple", "Temple", "After you summon a creature here, gain 1 health.", ["story", "arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_temple_heal", "amount": 1}]}])
	var player: Dictionary = match_state["players"][0]
	player["health"] = 25
	var health_before := int(player.get("health", 0))
	_summon_creature(player, match_state, "temple_creature", "temple", 2, 2)
	var health_after := int(player.get("health", 0))
	return _assert(health_after == health_before + 1, "Temple should heal player by 1 on summon, got %d -> %d." % [health_before, health_after])


func _test_torment_damages_on_summon() -> bool:
	var match_state := _build_lane_match("torment", "Torment", "After a creature is summoned here, deal 1 damage to it.", ["story"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_torment_damage", "amount": 1}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "torment_creature", "torment", 2, 5)
	var remaining := EvergreenRules.get_remaining_health(creature)
	return _assert(remaining == 4, "Torment should deal 1 damage to summoned creature, remaining health = %d." % remaining)


func _test_venom_grants_lethal() -> bool:
	var match_state := _build_lane_match("venom", "Venom", "Creatures in this lane have Lethal.", ["story"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_grant_keyword", "keyword": "lethal"}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "venom_creature", "venom", 2, 2)
	return _assert(EvergreenRules.has_keyword(creature, "lethal"), "Venom should grant Lethal.")


func _test_warzone_damages_opponent_on_summon() -> bool:
	var match_state := _build_lane_match("warzone", "Warzone", "After you summon a creature here, deal 1 damage to the opponent.", ["arena"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_warzone_damage", "amount": 1}]}])
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	var p2_health_before := int(player_2.get("health", 0))
	_summon_creature(player_1, match_state, "warzone_creature", "warzone", 2, 2)
	var p2_health_after := int(player_2.get("health", 0))
	return _assert(p2_health_after == p2_health_before - 1, "Warzone should deal 1 damage to opponent on summon, got %d -> %d." % [p2_health_before, p2_health_after])


func _test_sewer_blocks_high_health() -> bool:
	var match_state := _build_lane_match("sewer", "Sewer", "Creatures with more than 2 health cannot be played here.", ["story"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_sewer_restrict", "max_health": 2}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _append_creature_to_hand(player, "sewer_big")
	creature["health"] = 3
	var result := LaneRules.validate_summon_from_hand(match_state, player["player_id"], creature["instance_id"], "sewer")
	return _assert(not result["is_valid"], "Sewer should reject creatures with more than 2 health.")


func _test_sewer_allows_low_health() -> bool:
	var match_state := _build_lane_match("sewer", "Sewer", "Creatures with more than 2 health cannot be played here.", ["story"], [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_sewer_restrict", "max_health": 2}]}])
	var player: Dictionary = match_state["players"][0]
	var creature := _append_creature_to_hand(player, "sewer_small")
	creature["health"] = 2
	var result := LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], "sewer")
	return _assert(result["is_valid"], "Sewer should allow creatures with 2 or less health.")


# --- Generic lane match builder ---
func _build_lane_match(lane_id: String, display_name: String, description: String, availability: Array, effects: Array) -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = lane_id
	lane["lane_type"] = lane_id
	lane["lane_rule_payload"] = {
		"display_name": display_name,
		"description": description,
		"icon": "res://assets/images/lanes/%s.png" % lane_id.replace("_", "-"),
		"implementation_bucket": "mvp",
		"availability": availability,
		"source_ids": ["uesp_lanes"],
		"effects": effects,
	}
	return match_state


func _build_armor_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "armor"
	lane["lane_type"] = "armor"
	lane["lane_rule_payload"] = {
		"display_name": "Armor",
		"description": "After a creature is summoned here, double its health.",
		"icon": "res://assets/images/lanes/armor.png",
		"implementation_bucket": "mvp",
		"availability": ["story"],
		"source_ids": ["uesp_lanes"],
		"effects": [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_armor_double_health"}]}],
	}
	return match_state


func _build_mania_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "mania"
	lane["lane_type"] = "mania"
	lane["lane_rule_payload"] = {
		"display_name": "Mania",
		"description": "Start of turn: player with the highest-health creature here draws a card.",
		"icon": "res://assets/images/lanes/mania.png",
		"implementation_bucket": "mvp",
		"availability": ["story"],
		"source_ids": ["uesp_lanes"],
		"effects": [{"family": "start_of_turn", "match_role": "any_player", "effects": [{"op": "lane_mania_draw"}]}],
	}
	return match_state


func _build_dementia_match() -> Dictionary:
	var match_state := _build_match()
	# Convert the shadow lane (index 1) to dementia
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "dementia"
	lane["lane_type"] = "dementia"
	lane["lane_rule_payload"] = {
		"display_name": "Dementia",
		"description": "Start of turn: player with the highest-power creature here deals 3 damage to the opponent.",
		"icon": "res://assets/images/lanes/dementia.png",
		"implementation_bucket": "mvp",
		"availability": ["story"],
		"source_ids": ["uesp_lanes"],
		"effects": [{"family": "start_of_turn", "match_role": "any_player", "effects": [{"op": "lane_dementia_damage", "amount": 3}]}],
	}
	return match_state


func _build_graveyard_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "graveyard"
	lane["lane_type"] = "graveyard"
	lane["lane_rule_payload"] = {
		"display_name": "Graveyard",
		"description": "After a creature other than Rotting Draugr is destroyed, summon a 1/1 Rotting Draugr.",
		"effects": [{"family": "on_friendly_death", "match_role": "any_player", "effects": [{"op": "lane_graveyard_summon_draugr"}]}],
	}
	return match_state


func _test_graveyard_spawns_draugr_on_death() -> bool:
	var match_state := _build_graveyard_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Summon a small creature for p1 and a big creature for p2
	_summon_creature(player_1, match_state, "small_a", "graveyard", 1, 1)
	_summon_creature(player_2, match_state, "big_a", "graveyard", 5, 5)
	# Advance turn so p1's creature can attack (no summoning sickness)
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	# p1 attacks p2's big creature — p1's creature dies
	var attacker_id := str(player_1["player_id"]) + "_small_a"
	var defender_id := str(player_2["player_id"]) + "_big_a"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	var p1_slots: Array = match_state["lanes"][1].get("player_slots", {}).get(player_1["player_id"], [])
	var draugr_count := 0
	for card in p1_slots:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == "Rotting Draugr":
			draugr_count += 1
	return _assert(draugr_count == 1, "Graveyard should spawn 1 Rotting Draugr when a creature dies. Found: %d" % draugr_count)


func _test_graveyard_spawns_draugr_on_second_death() -> bool:
	var match_state := _build_graveyard_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Summon two small creatures for p1 and a big creature for p2
	_summon_creature(player_1, match_state, "small_a", "graveyard", 1, 1)
	_summon_creature(player_1, match_state, "small_b", "graveyard", 1, 1)
	_summon_creature(player_2, match_state, "big_a", "graveyard", 5, 5)
	# Advance turn so p1's creatures can attack
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	# First attack — small_a dies
	var attacker_a_id := str(player_1["player_id"]) + "_small_a"
	var defender_id := str(player_2["player_id"]) + "_big_a"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_a_id, {"type": "creature", "instance_id": defender_id})
	# Second attack — small_b dies
	var attacker_b_id := str(player_1["player_id"]) + "_small_b"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_b_id, {"type": "creature", "instance_id": defender_id})
	var p1_slots: Array = match_state["lanes"][1].get("player_slots", {}).get(player_1["player_id"], [])
	var draugr_count := 0
	for card in p1_slots:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == "Rotting Draugr":
			draugr_count += 1
	return _assert(draugr_count == 2, "Graveyard should spawn 2 Rotting Draugrs after 2 separate creature deaths. Found: %d" % draugr_count)


func _test_graveyard_dual_death_spawns_both_draugrs() -> bool:
	var match_state := _build_graveyard_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Equal-sized creatures — both die on combat
	_summon_creature(player_1, match_state, "equal_a", "graveyard", 3, 3)
	_summon_creature(player_2, match_state, "equal_b", "graveyard", 3, 3)
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var attacker_id := str(player_1["player_id"]) + "_equal_a"
	var defender_id := str(player_2["player_id"]) + "_equal_b"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	var p1_slots: Array = match_state["lanes"][1].get("player_slots", {}).get(player_1["player_id"], [])
	var p2_slots: Array = match_state["lanes"][1].get("player_slots", {}).get(player_2["player_id"], [])
	var p1_draugr := 0
	var p2_draugr := 0
	for card in p1_slots:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == "Rotting Draugr":
			p1_draugr += 1
	for card in p2_slots:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == "Rotting Draugr":
			p2_draugr += 1
	return (
		_assert(p1_draugr == 1, "Player 1 should get a draugr when their creature dies in dual combat. Found: %d" % p1_draugr) and
		_assert(p2_draugr == 1, "Player 2 should get a draugr when their creature dies in dual combat. Found: %d" % p2_draugr)
	)


func _test_graveyard_draugr_has_summoning_sickness() -> bool:
	var match_state := _build_graveyard_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	_summon_creature(player_1, match_state, "small_a", "graveyard", 1, 1)
	_summon_creature(player_2, match_state, "big_a", "graveyard", 5, 5)
	# Advance turn so p1's creature can attack
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var attacker_id := str(player_1["player_id"]) + "_small_a"
	var defender_id := str(player_2["player_id"]) + "_big_a"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	# Find the spawned draugr and check it can't attack
	var p1_slots: Array = match_state["lanes"][1].get("player_slots", {}).get(player_1["player_id"], [])
	var draugr: Dictionary = {}
	for card in p1_slots:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == "Rotting Draugr":
			draugr = card
			break
	if draugr.is_empty():
		return _assert(false, "Expected a Rotting Draugr to exist for summoning sickness check.")
	var can_attack := MatchCombat.validate_attack(match_state, player_1["player_id"], str(draugr.get("instance_id", "")), {"type": "creature", "instance_id": defender_id})
	return _assert(not bool(can_attack.get("is_valid", false)), "Rotting Draugr should have summoning sickness and cannot attack on the turn it was spawned.")


func _summon_creature(player: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int) -> Dictionary:
	var creature := _append_creature_to_hand(player, label)
	creature["power"] = power
	creature["health"] = health
	var result := LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], lane_id)
	_assert(result["is_valid"], "Expected summon of %s to succeed." % label)
	return creature


func _test_heist_lane_grants_magicka_on_pilfer() -> bool:
	var match_state := _build_heist_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var creature := _summon_creature(player, match_state, "heist_pilferer", "heist", 2, 2)
	# Make creature ready to attack
	creature["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	creature["has_attacked_this_turn"] = false
	var magicka_before := int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
	var attack_result := MatchCombat.resolve_attack(match_state, player["player_id"], creature["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var magicka_after := int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
	return (
		_assert(attack_result["is_valid"], "Heist lane pilfer attack should resolve.") and
		_assert(magicka_after == magicka_before + 1, "Heist lane should grant 1 magicka on pilfer, got %d -> %d." % [magicka_before, magicka_after])
	)


func _test_heist_lane_no_magicka_in_other_lane() -> bool:
	var match_state := _build_heist_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var creature := _summon_creature(player, match_state, "field_pilferer", "field", 2, 2)
	creature["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	creature["has_attacked_this_turn"] = false
	var magicka_before := int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
	var attack_result := MatchCombat.resolve_attack(match_state, player["player_id"], creature["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var magicka_after := int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
	return (
		_assert(attack_result["is_valid"], "Field lane attack should resolve.") and
		_assert(magicka_after == magicka_before, "Creatures in field lane should not get heist magicka, got %d -> %d." % [magicka_before, magicka_after])
	)


func _build_heist_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "heist"
	lane["lane_type"] = "heist"
	lane["lane_rule_payload"] = {
		"display_name": "Heist",
		"description": "Creatures in this lane have Pilfer: Gain 1 magicka.",
		"icon": "res://assets/images/lanes/heist.png",
		"implementation_bucket": "mvp",
		"availability": ["story"],
		"source_ids": ["uesp_lanes"],
		"effects": [{"family": "pilfer", "match_role": "any_player", "effects": [{"op": "lane_heist_gain_magicka", "amount": 1}]}],
	}
	return match_state


func _test_madness_lane_transforms_on_pilfer() -> bool:
	var match_state := _build_madness_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var creature := _summon_creature(player, match_state, "madness_pilferer", "madness", 2, 2)
	creature["cost"] = 3
	creature["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	creature["has_attacked_this_turn"] = false
	var old_definition_id := str(creature.get("definition_id", ""))
	var attack_result := MatchCombat.resolve_attack(match_state, player["player_id"], creature["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var new_definition_id := str(creature.get("definition_id", ""))
	var new_cost := int(creature.get("cost", 0))
	return (
		_assert(attack_result["is_valid"], "Madness lane pilfer attack should resolve.") and
		_assert(new_definition_id != old_definition_id, "Madness lane should transform creature on pilfer, definition_id unchanged: %s." % old_definition_id) and
		_assert(new_cost == 4, "Transformed creature should have cost 4 (original 3 + 1), got %d." % new_cost)
	)


func _test_madness_lane_no_transform_in_other_lane() -> bool:
	var match_state := _build_madness_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var creature := _summon_creature(player, match_state, "field_pilferer", "field", 2, 2)
	creature["cost"] = 3
	creature["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	creature["has_attacked_this_turn"] = false
	var old_definition_id := str(creature.get("definition_id", ""))
	var attack_result := MatchCombat.resolve_attack(match_state, player["player_id"], creature["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var new_definition_id := str(creature.get("definition_id", ""))
	return (
		_assert(attack_result["is_valid"], "Field lane attack should resolve.") and
		_assert(new_definition_id == old_definition_id, "Creatures in field lane should not be transformed by madness, got %s -> %s." % [old_definition_id, new_definition_id])
	)


func _test_madness_lane_transformed_creature_has_summoning_sickness() -> bool:
	var match_state := _build_madness_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var creature := _summon_creature(player, match_state, "madness_pilferer", "madness", 2, 2)
	creature["cost"] = 3
	creature["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	creature["has_attacked_this_turn"] = false
	# Pilfer to trigger transform
	MatchCombat.resolve_attack(match_state, player["player_id"], creature["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	# Remove charge if present so we test summoning sickness
	var keywords: Array = creature.get("keywords", [])
	keywords.erase("charge")
	creature["keywords"] = keywords
	var granted: Array = creature.get("granted_keywords", [])
	granted.erase("charge")
	creature["granted_keywords"] = granted
	EvergreenRules.sync_derived_state(creature)
	# Try to attack again — should fail due to summoning sickness
	var second_attack := MatchCombat.resolve_attack(match_state, player["player_id"], creature["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	return _assert(not second_attack["is_valid"], "Transformed creature without Charge should have summoning sickness.")


func _test_madness_lane_transformed_charge_creature_can_attack() -> bool:
	var match_state := _build_madness_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var creature := _summon_creature(player, match_state, "madness_pilferer", "madness", 2, 2)
	creature["cost"] = 3
	creature["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	creature["has_attacked_this_turn"] = false
	# Pilfer to trigger transform
	MatchCombat.resolve_attack(match_state, player["player_id"], creature["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	# Grant charge to simulate transforming into a charge creature
	var keywords: Array = creature.get("keywords", [])
	if not keywords.has("charge"):
		keywords.append("charge")
	creature["keywords"] = keywords
	EvergreenRules.sync_derived_state(creature)
	# Try to attack again — should succeed because of Charge
	var second_attack := MatchCombat.resolve_attack(match_state, player["player_id"], creature["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	return _assert(second_attack["is_valid"], "Transformed creature with Charge should be able to attack again.")


func _build_madness_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "madness"
	lane["lane_type"] = "madness"
	lane["lane_rule_payload"] = {
		"display_name": "Madness",
		"description": "Creatures here have Pilfer: Transform into a random creature with cost 1 greater.",
		"icon": "res://assets/images/lanes/madness.png",
		"implementation_bucket": "mvp",
		"availability": ["story"],
		"source_ids": ["uesp_lanes"],
		"effects": [{"family": "pilfer", "match_role": "any_player", "effects": [{"op": "lane_madness_transform"}]}],
	}
	return match_state


func _build_match() -> Dictionary:
	var match_state := MatchBootstrap.create_standard_match([
		_build_deck("alpha", 10),
		_build_deck("beta", 10)
	], {
		"seed": 17,
		"first_player_index": 0,
	})
	for player in match_state["players"]:
		MatchBootstrap.apply_mulligan(match_state, player["player_id"], [])
	MatchTurnLoop.begin_first_turn(match_state)
	for player in match_state["players"]:
		player["current_magicka"] = 10
		player["max_magicka"] = 10
		player["temporary_magicka"] = 0
	return match_state


func _build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


func _append_creature_to_hand(player: Dictionary, label: String, keywords: Array = []) -> Dictionary:
	var player_id: String = player["player_id"]
	var card := {
		"instance_id": "%s_%s" % [player_id, label],
		"definition_id": "test_%s" % label,
		"owner_player_id": player_id,
		"controller_player_id": player_id,
		"zone": "hand",
		"card_type": "creature",
		"cost": 0,
		"power": 2,
		"health": 2,
		"keywords": keywords.duplicate(),
		"granted_keywords": [],
		"status_markers": [],
	}
	player["hand"].append(card)
	return card


func _has_status(card: Dictionary, status_id: String) -> bool:
	var status_markers: Array = card.get("status_markers", [])
	return status_markers.has(status_id)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true

	push_error(message)
	return false


# --- Plunder Lane Tests ---

func _test_plunder_lane_attaches_item_on_summon() -> bool:
	var match_state := _build_plunder_match()
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "plunder_target", "plunder", 2, 3)
	var attached: Array = creature.get("attached_items", [])
	return (
		_assert(attached.size() == 1, "Plunder lane should attach exactly 1 item, got %d." % attached.size()) and
		_assert(str(attached[0].get("card_type", "")) == "item", "Attached card should be an item, got '%s'." % str(attached[0].get("card_type", "")))
	)


func _test_plunder_lane_does_not_affect_other_lane() -> bool:
	var match_state := _build_plunder_match()
	var player: Dictionary = match_state["players"][0]
	var creature := _summon_creature(player, match_state, "field_target", "field", 2, 3)
	var attached: Array = creature.get("attached_items", [])
	return _assert(attached.size() == 0, "Summoning in field lane should not attach an item, got %d." % attached.size())


func _test_plunder_lane_both_players_get_items() -> bool:
	var match_state := _build_plunder_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	var c1 := _summon_creature(player_1, match_state, "p1_plunder", "plunder", 2, 3)
	var c2 := _summon_creature(player_2, match_state, "p2_plunder", "plunder", 2, 3)
	var a1: Array = c1.get("attached_items", [])
	var a2: Array = c2.get("attached_items", [])
	return (
		_assert(a1.size() == 1, "Player 1 creature should have 1 attached item, got %d." % a1.size()) and
		_assert(a2.size() == 1, "Player 2 creature should have 1 attached item, got %d." % a2.size())
	)


func _build_plunder_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "plunder"
	lane["lane_type"] = "plunder"
	lane["lane_rule_payload"] = {
		"display_name": "Plunder",
		"description": "After a creature is summoned here, attach a random item to it.",
		"icon": "res://assets/images/lanes/plunder.png",
		"implementation_bucket": "mvp",
		"availability": ["story", "arena"],
		"source_ids": ["uesp_lanes"],
		"effects": [{"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_plunder_attach_item"}]}],
	}
	return match_state


# --- Reanimation Lane Tests ---

func _build_reanimation_match() -> Dictionary:
	var match_state := _build_match()
	var lane: Dictionary = match_state["lanes"][1]
	lane["lane_id"] = "reanimation"
	lane["lane_type"] = "reanimation"
	lane["lane_rule_payload"] = {
		"display_name": "Reanimation",
		"description": "When a non-Reanimated creature in this lane dies for the first time, return it to play as a 1/1.",
		"effects": [{"family": "on_friendly_death", "match_role": "any_player", "effects": [{"op": "lane_reanimation_resurrect"}]}],
	}
	return match_state


func _test_reanimation_resurrects_as_1_1() -> bool:
	var match_state := _build_reanimation_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	_summon_creature(player_1, match_state, "small_a", "reanimation", 2, 3)
	_summon_creature(player_2, match_state, "big_a", "reanimation", 5, 5)
	# Advance turn so p1's creature can attack
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	# p1 attacks p2's big creature — p1's creature dies
	var attacker_id := str(player_1["player_id"]) + "_small_a"
	var defender_id := str(player_2["player_id"]) + "_big_a"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	# Check that the creature was resurrected as 1/1 in the lane
	var lane_slots: Array = match_state["lanes"][1]["player_slots"].get(player_1["player_id"], [])
	var found := false
	for card in lane_slots:
		if str(card.get("instance_id", "")) == attacker_id:
			found = true
			if not _assert(EvergreenRules.get_power(card) == 1, "Reanimated creature should have 1 power, got %d." % EvergreenRules.get_power(card)):
				return false
			if not _assert(EvergreenRules.get_health(card) == 1, "Reanimated creature should have 1 health, got %d." % EvergreenRules.get_health(card)):
				return false
			if not _assert(bool(card.get("_reanimated", false)), "Reanimated creature should have _reanimated flag."):
				return false
	return _assert(found, "Creature should be resurrected in the reanimation lane.")


func _test_reanimation_does_not_resurrect_twice() -> bool:
	var match_state := _build_reanimation_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	_summon_creature(player_1, match_state, "small_a", "reanimation", 2, 3)
	_summon_creature(player_2, match_state, "big_a", "reanimation", 5, 5)
	# Advance turn so p1's creature can attack
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	# First death — creature gets reanimated as 1/1
	var attacker_id := str(player_1["player_id"]) + "_small_a"
	var defender_id := str(player_2["player_id"]) + "_big_a"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	# Advance turn so the reanimated creature can attack
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	# Second death — the 1/1 reanimated creature attacks the big creature again
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	# The reanimated creature should NOT come back a second time
	var lane_slots: Array = match_state["lanes"][1]["player_slots"].get(player_1["player_id"], [])
	var found := false
	for card in lane_slots:
		if str(card.get("instance_id", "")) == attacker_id:
			found = true
	return _assert(not found, "Reanimated creature should not resurrect a second time.")


func _test_reanimation_does_not_affect_other_lane() -> bool:
	var match_state := _build_reanimation_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Summon in field lane (not reanimation lane)
	_summon_creature(player_1, match_state, "field_a", "field", 1, 1)
	_summon_creature(player_2, match_state, "field_big", "field", 5, 5)
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var attacker_id := str(player_1["player_id"]) + "_field_a"
	var defender_id := str(player_2["player_id"]) + "_field_big"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	# Creature should NOT be resurrected in the field lane
	var field_slots: Array = match_state["lanes"][0]["player_slots"].get(player_1["player_id"], [])
	var found := false
	for card in field_slots:
		if str(card.get("instance_id", "")) == attacker_id:
			found = true
	return _assert(not found, "Creatures dying in field lane should not be resurrected by reanimation lane.")


func _test_reanimation_has_summoning_sickness() -> bool:
	var match_state := _build_reanimation_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	_summon_creature(player_1, match_state, "small_a", "reanimation", 2, 3)
	_summon_creature(player_2, match_state, "big_a", "reanimation", 5, 5)
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	var attacker_id := str(player_1["player_id"]) + "_small_a"
	var defender_id := str(player_2["player_id"]) + "_big_a"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	# The reanimated non-charge creature should not be able to attack (summoning sickness)
	var lane_slots: Array = match_state["lanes"][1]["player_slots"].get(player_1["player_id"], [])
	for card in lane_slots:
		if str(card.get("instance_id", "")) == attacker_id:
			var can_attack := MatchCombat.can_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
			return _assert(not can_attack, "Reanimated non-charge creature should have summoning sickness.")
	return _assert(false, "Reanimated creature not found in lane.")


func _test_reanimation_charge_can_attack_immediately() -> bool:
	var match_state := _build_reanimation_match()
	var player_1: Dictionary = match_state["players"][0]
	var player_2: Dictionary = match_state["players"][1]
	# Summon a creature with charge for p1
	var charge_creature := _summon_creature(player_1, match_state, "charger", "reanimation", 2, 3)
	charge_creature["keywords"] = ["charge"]
	_summon_creature(player_2, match_state, "big_a", "reanimation", 5, 5)
	# Advance turn so p1's creature can attack
	MatchTurnLoop.end_turn(match_state, player_1["player_id"])
	MatchTurnLoop.end_turn(match_state, player_2["player_id"])
	# p1's charge creature attacks and dies
	var attacker_id := str(player_1["player_id"]) + "_charger"
	var defender_id := str(player_2["player_id"]) + "_big_a"
	MatchCombat.resolve_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
	# The reanimated charge creature should be able to attack immediately
	var lane_slots: Array = match_state["lanes"][1]["player_slots"].get(player_1["player_id"], [])
	for card in lane_slots:
		if str(card.get("instance_id", "")) == attacker_id:
			var can_attack := MatchCombat.can_attack(match_state, player_1["player_id"], attacker_id, {"type": "creature", "instance_id": defender_id})
			return _assert(can_attack, "Reanimated charge creature should be able to attack immediately.")
	return _assert(false, "Reanimated charge creature not found in lane.")