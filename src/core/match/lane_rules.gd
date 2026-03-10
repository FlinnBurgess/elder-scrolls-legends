class_name LaneRules
extends RefCounted

const CARD_TYPE_CREATURE := "creature"
const KEYWORD_GUARD := "guard"
const STATUS_COVER := "cover"
const ZONE_HAND := "hand"
const ZONE_LANE := "lane"
const SHADOW_LANE_ID := "shadow"


static func get_lane_occupancy(match_state: Dictionary, lane_id: String, player_id: String) -> Dictionary:
	var lane_index := _find_lane_index(match_state.get("lanes", []), lane_id)
	if lane_index == -1:
		return _invalid_result("Unknown lane_id: %s" % lane_id)

	var lane: Dictionary = match_state["lanes"][lane_index]
	var player_slots_by_id: Dictionary = lane.get("player_slots", {})
	if not player_slots_by_id.has(player_id):
		return _invalid_result("Lane %s does not track player_id %s." % [lane_id, player_id])

	var player_slots: Array = player_slots_by_id[player_id]
	var occupied := 0
	var open_slot_indices: Array = []
	for slot_index in range(player_slots.size()):
		if player_slots[slot_index] == null:
			open_slot_indices.append(slot_index)
		else:
			occupied += 1

	return {
		"is_valid": true,
		"errors": [],
		"lane_id": lane_id,
		"lane_type": str(lane.get("lane_type", lane_id)),
		"slot_capacity": int(lane.get("slot_capacity", player_slots.size())),
		"occupancy": occupied,
		"open_slot_indices": open_slot_indices,
		"lane_rule_payload": lane.get("lane_rule_payload", {}),
	}


static func validate_summon_from_hand(match_state: Dictionary, player_id: String, instance_id: String, lane_id: String, options: Dictionary = {}) -> Dictionary:
	var player_lookup := _find_player(match_state.get("players", []), player_id)
	if not player_lookup["is_valid"]:
		return player_lookup

	var player: Dictionary = player_lookup["player"]
	var hand_index := _find_card_index(player.get(ZONE_HAND, []), instance_id)
	if hand_index == -1:
		return _invalid_result("Card %s is not in %s's hand." % [instance_id, player_id])

	var card: Dictionary = player[ZONE_HAND][hand_index]
	var validation := _validate_lane_entry(match_state, player_id, card, lane_id, options)
	validation["player_index"] = player_lookup["player_index"]
	validation["hand_index"] = hand_index
	return validation


static func summon_from_hand(match_state: Dictionary, player_id: String, instance_id: String, lane_id: String, options: Dictionary = {}) -> Dictionary:
	var validation := validate_summon_from_hand(match_state, player_id, instance_id, lane_id, options)
	if not validation["is_valid"]:
		return validation

	var player: Dictionary = match_state["players"][validation["player_index"]]
	var card: Dictionary = player[ZONE_HAND][validation["hand_index"]]
	player[ZONE_HAND].remove_at(validation["hand_index"])
	_apply_lane_entry(match_state, player_id, card, validation)

	return {
		"is_valid": true,
		"errors": [],
		"lane_id": lane_id,
		"lane_index": validation["lane_index"],
		"slot_index": validation["slot_index"],
		"card": card,
		"granted_cover": bool(validation.get("granted_cover", false)),
	}


static func validate_move(match_state: Dictionary, player_id: String, instance_id: String, target_lane_id: String, options: Dictionary = {}) -> Dictionary:
	var source := _find_creature_on_board(match_state.get("lanes", []), instance_id)
	if not source["is_valid"]:
		return source

	if str(source["player_id"]) != player_id:
		return _invalid_result("Creature %s is not controlled by %s." % [instance_id, player_id])

	if str(source["lane_id"]) == target_lane_id:
		return _invalid_result("Creature %s is already in lane %s." % [instance_id, target_lane_id])

	var validation := _validate_lane_entry(match_state, player_id, source["card"], target_lane_id, options)
	validation["source_lane_index"] = source["lane_index"]
	validation["source_lane_id"] = source["lane_id"]
	validation["source_slot_index"] = source["slot_index"]
	return validation


static func move_creature(match_state: Dictionary, player_id: String, instance_id: String, target_lane_id: String, options: Dictionary = {}) -> Dictionary:
	var validation := validate_move(match_state, player_id, instance_id, target_lane_id, options)
	if not validation["is_valid"]:
		return validation

	var source_lane: Dictionary = match_state["lanes"][validation["source_lane_index"]]
	var source_slots: Array = source_lane["player_slots"][player_id]
	var card: Dictionary = source_slots[validation["source_slot_index"]]
	source_slots[validation["source_slot_index"]] = null
	_apply_lane_entry(match_state, player_id, card, validation)

	return {
		"is_valid": true,
		"errors": [],
		"from_lane_id": validation["source_lane_id"],
		"to_lane_id": target_lane_id,
		"slot_index": validation["slot_index"],
		"card": card,
		"granted_cover": bool(validation.get("granted_cover", false)),
	}


static func _validate_lane_entry(match_state: Dictionary, player_id: String, card: Dictionary, lane_id: String, options: Dictionary = {}) -> Dictionary:
	if not _is_creature(card):
		return _invalid_result("Only creature cards can enter lanes.")

	var lane_index := _find_lane_index(match_state.get("lanes", []), lane_id)
	if lane_index == -1:
		return _invalid_result("Unknown lane_id: %s" % lane_id)

	var lane: Dictionary = match_state["lanes"][lane_index]
	var player_slots_by_id: Dictionary = lane.get("player_slots", {})
	if not player_slots_by_id.has(player_id):
		return _invalid_result("Lane %s does not track player_id %s." % [lane_id, player_id])

	var player_slots: Array = player_slots_by_id[player_id]
	var requested_slot := int(options.get("slot_index", -1))
	var slot_index := requested_slot
	if requested_slot == -1:
		slot_index = _find_open_slot(player_slots)
		if slot_index == -1:
			return _invalid_result("Lane %s is full for %s." % [lane_id, player_id])
	else:
		if requested_slot < 0 or requested_slot >= player_slots.size():
			return _invalid_result("Requested slot %d is out of range for lane %s." % [requested_slot, lane_id])
		if player_slots[requested_slot] != null:
			return _invalid_result("Requested slot %d in lane %s is already occupied." % [requested_slot, lane_id])

	return {
		"is_valid": true,
		"errors": [],
		"lane_id": lane_id,
		"lane_index": lane_index,
		"slot_index": slot_index,
		"lane_type": str(lane.get("lane_type", lane_id)),
		"lane_rule_payload": lane.get("lane_rule_payload", {}),
		"granted_cover": _should_grant_cover(match_state, lane, card),
	}


static func _apply_lane_entry(match_state: Dictionary, player_id: String, card: Dictionary, validation: Dictionary) -> void:
	var lane: Dictionary = match_state["lanes"][validation["lane_index"]]
	var player_slots: Array = lane["player_slots"][player_id]
	card["controller_player_id"] = player_id
	if not card.has("owner_player_id"):
		card["owner_player_id"] = player_id
	card["zone"] = ZONE_LANE
	card["lane_id"] = validation["lane_id"]
	card["slot_index"] = validation["slot_index"]
	card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0))
	if bool(validation.get("granted_cover", false)):
		_grant_cover(card, int(match_state.get("turn_number", 0)) + 1)
	player_slots[validation["slot_index"]] = card


static func _grant_cover(card: Dictionary, cover_expires_on_turn: int) -> void:
	var status_markers := _ensure_array(card.get("status_markers", []))
	if not status_markers.has(STATUS_COVER):
		status_markers.append(STATUS_COVER)
	card["status_markers"] = status_markers
	card["cover_expires_on_turn"] = cover_expires_on_turn
	card["cover_granted_by"] = "shadow_lane_entry"


static func _should_grant_cover(match_state: Dictionary, lane: Dictionary, card: Dictionary) -> bool:
	if str(lane.get("lane_type", lane.get("lane_id", ""))) != SHADOW_LANE_ID:
		return false
	if _has_keyword(card, KEYWORD_GUARD):
		return false
	return not _has_status(card, STATUS_COVER)


static func _find_player(players: Array, player_id: String) -> Dictionary:
	for index in range(players.size()):
		var player: Dictionary = players[index]
		if str(player.get("player_id", "")) == player_id:
			return {
				"is_valid": true,
				"errors": [],
				"player_index": index,
				"player": player,
			}
	return _invalid_result("Unknown player_id: %s" % player_id)


static func _find_lane_index(lanes: Array, lane_id: String) -> int:
	for index in range(lanes.size()):
		if str(lanes[index].get("lane_id", "")) == lane_id:
			return index
	return -1


static func _find_card_index(cards: Array, instance_id: String) -> int:
	for index in range(cards.size()):
		if str(cards[index].get("instance_id", "")) == instance_id:
			return index
	return -1


static func _find_creature_on_board(lanes: Array, instance_id: String) -> Dictionary:
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if card != null and str(card.get("instance_id", "")) == instance_id:
					return {
						"is_valid": true,
						"errors": [],
						"lane_index": lane_index,
						"lane_id": str(lane.get("lane_id", "")),
						"player_id": str(player_id),
						"slot_index": slot_index,
						"card": card,
					}
	return _invalid_result("Creature %s is not on the board." % instance_id)


static func _find_open_slot(slots: Array) -> int:
	for index in range(slots.size()):
		if slots[index] == null:
			return index
	return -1


static func _is_creature(card: Dictionary) -> bool:
	return str(card.get("card_type", "")) == CARD_TYPE_CREATURE


static func _has_keyword(card: Dictionary, keyword_id: String) -> bool:
	for key in ["keywords", "granted_keywords"]:
		var values := _ensure_array(card.get(key, []))
		if values.has(keyword_id):
			return true
	return false


static func _has_status(card: Dictionary, status_id: String) -> bool:
	return _ensure_array(card.get("status_markers", [])).has(status_id)


static func _ensure_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


static func _invalid_result(message: String) -> Dictionary:
	return {
		"is_valid": false,
		"errors": [message],
	}