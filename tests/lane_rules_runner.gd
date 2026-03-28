extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")


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
		_test_armor_lane_both_players_get_doubled()
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


func _summon_creature(player: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int) -> Dictionary:
	var creature := _append_creature_to_hand(player, label)
	creature["power"] = power
	creature["health"] = health
	var result := LaneRules.summon_from_hand(match_state, player["player_id"], creature["instance_id"], lane_id)
	_assert(result["is_valid"], "Expected summon of %s to succeed." % label)
	return creature


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