extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")


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
		_test_sacrifice_summon_rejects_non_full_lane()
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