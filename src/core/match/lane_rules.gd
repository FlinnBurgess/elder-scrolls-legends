class_name LaneRules
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const CARD_TYPE_CREATURE := "creature"
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
	var occupied := player_slots.size()
	var slot_capacity := int(lane.get("slot_capacity", 0))
	var open_slot_indices: Array = []
	if occupied < slot_capacity:
		for open_index in range(occupied + 1):
			open_slot_indices.append(open_index)

	return {
		"is_valid": true,
		"errors": [],
		"lane_id": lane_id,
		"lane_type": str(lane.get("lane_type", lane_id)),
		"slot_capacity": slot_capacity,
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
	if not bool(options.get("played_for_free", false)) and PersistentCardRules.get_effective_play_cost(match_state, player_id, card) > _get_available_magicka(player):
		return _invalid_result("Player does not have enough magicka to play %s." % instance_id)
	var validation := _validate_lane_entry(match_state, player_id, card, lane_id, options)
	validation["player_index"] = player_lookup["player_index"]
	validation["hand_index"] = hand_index
	return validation


static func summon_from_hand(match_state: Dictionary, player_id: String, instance_id: String, lane_id: String, options: Dictionary = {}) -> Dictionary:
	var validation := validate_summon_from_hand(match_state, player_id, instance_id, lane_id, options)
	if not validation["is_valid"]:
		return validation
	var player_lookup := _find_player(match_state.get("players", []), player_id)
	if not bool(player_lookup.get("is_valid", false)):
		return player_lookup
	var player: Dictionary = player_lookup["player"]
	var hand_index := _find_card_index(player.get(ZONE_HAND, []), instance_id)
	if hand_index >= 0:
		ExtendedMechanicPacks.apply_pre_play_options(player[ZONE_HAND][hand_index], options)
	var hand_card: Dictionary = player.get(ZONE_HAND, [])[hand_index]
	var play_cost := 0 if bool(options.get("played_for_free", false)) else PersistentCardRules.get_effective_play_cost(match_state, player_id, hand_card)
	if play_cost > 0:
		_spend_magicka(match_state, player_id, play_cost)
	PersistentCardRules._consume_cost_reduction(match_state, player_id)
	var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, instance_id, lane_id, options)
	if not bool(summon_result.get("is_valid", false)):
		return summon_result
	var card: Dictionary = summon_result["card"]
	var play_event := {
		"event_type": MatchTiming.EVENT_CARD_PLAYED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": str(card.get("instance_id", "")),
		"source_controller_player_id": player_id,
		"source_zone": ZONE_HAND,
		"target_zone": ZONE_LANE,
		"card_type": str(card.get("card_type", "")),
		"played_cost": int(card.get("cost", 0)),
	}
	var summon_event := {
		"event_type": MatchTiming.EVENT_CREATURE_SUMMONED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": str(card.get("instance_id", "")),
		"source_controller_player_id": player_id,
		"lane_id": lane_id,
		"slot_index": int(summon_result.get("slot_index", -1)),
		"granted_cover": bool(summon_result.get("granted_cover", false)),
	}
	for key in _ensure_dictionary(options.get("play_event_overrides", {})).keys():
		play_event[key] = options["play_event_overrides"][key]
	for key in _ensure_dictionary(options.get("summon_event_overrides", {})).keys():
		summon_event[key] = options["summon_event_overrides"][key]
	var publish_list := [play_event, summon_event]
	if bool(summon_result.get("granted_cover", false)):
		publish_list.append({
			"event_type": "status_granted",
			"source_instance_id": str(card.get("instance_id", "")),
			"target_instance_id": str(card.get("instance_id", "")),
			"status_id": "cover",
		})
	var timing_result := MatchTiming.publish_events(match_state, publish_list, _ensure_dictionary(options.get("event_context", {})))

	return {
		"is_valid": true,
		"errors": [],
		"lane_id": lane_id,
		"lane_index": summon_result["lane_index"],
		"slot_index": summon_result["slot_index"],
		"card": card,
		"granted_cover": bool(summon_result.get("granted_cover", false)),
		"events": timing_result.get("processed_events", []),
		"trigger_resolutions": timing_result.get("trigger_resolutions", []),
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
	var move_options := options.duplicate()
	move_options["preserve_entered_lane_on_turn"] = true
	var move_result := MatchMutations.move_card_between_lanes(match_state, player_id, instance_id, target_lane_id, move_options)
	if not bool(move_result.get("is_valid", false)):
		return move_result

	return {
		"is_valid": true,
		"errors": [],
		"from_lane_id": validation["source_lane_id"],
		"to_lane_id": target_lane_id,
		"slot_index": move_result["slot_index"],
		"card": move_result["card"],
		"granted_cover": bool(move_result.get("granted_cover", false)),
	}


static func _validate_lane_entry(match_state: Dictionary, player_id: String, card: Dictionary, lane_id: String, options: Dictionary = {}) -> Dictionary:
	return MatchMutations.validate_lane_entry(match_state, player_id, card, lane_id, options)


static func _apply_lane_entry(match_state: Dictionary, player_id: String, card: Dictionary, validation: Dictionary) -> void:
	var lane: Dictionary = match_state["lanes"][validation["lane_index"]]
	var player_slots: Array = lane["player_slots"][player_id]
	EvergreenRules.ensure_card_state(card)
	card["controller_player_id"] = player_id
	if not card.has("owner_player_id"):
		card["owner_player_id"] = player_id
	card["zone"] = ZONE_LANE
	card["lane_id"] = validation["lane_id"]
	card["slot_index"] = validation["slot_index"]
	card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0))
	if bool(validation.get("granted_cover", false)):
		var cover_offset := 1 if str(card.get("controller_player_id", "")) == str(match_state.get("active_player_id", "")) else 0
		EvergreenRules.grant_cover(card, int(match_state.get("turn_number", 0)) + cover_offset)
	player_slots.insert(validation["slot_index"], card)
	MatchMutations._reindex_player_slots(player_slots)


static func _grant_cover(card: Dictionary, cover_expires_on_turn: int) -> void:
	EvergreenRules.grant_cover(card, cover_expires_on_turn)


static func _should_grant_cover(match_state: Dictionary, lane: Dictionary, card: Dictionary) -> bool:
	if str(lane.get("lane_type", lane.get("lane_id", ""))) != SHADOW_LANE_ID:
		return false
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
		return false
	var self_immunities = card.get("self_immunity", [])
	if typeof(self_immunities) == TYPE_ARRAY and self_immunities.has("cover"):
		return false
	return not EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER)


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


static func _get_available_magicka(player: Dictionary) -> int:
	return maxi(0, int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0)))


static func _spend_magicka(match_state: Dictionary, player_id: String, amount: int) -> void:
	var player_lookup := _find_player(match_state.get("players", []), player_id)
	if not bool(player_lookup.get("is_valid", false)):
		return
	var player: Dictionary = player_lookup["player"]
	var remaining := amount
	var temporary_magicka := int(player.get("temporary_magicka", 0))
	if temporary_magicka > 0:
		var temporary_spent := mini(temporary_magicka, remaining)
		player["temporary_magicka"] = temporary_magicka - temporary_spent
		remaining -= temporary_spent
	if remaining > 0:
		player["current_magicka"] = maxi(0, int(player.get("current_magicka", 0)) - remaining)


static func _find_creature_on_board(lanes: Array, instance_id: String) -> Dictionary:
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
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


static func _find_open_slot(_slots: Array) -> int:
	# With packed arrays, this function is unused — open slot is always at size()
	return _slots.size()


static func _is_creature(card: Dictionary) -> bool:
	return str(card.get("card_type", "")) == CARD_TYPE_CREATURE


static func _has_keyword(card: Dictionary, keyword_id: String) -> bool:
	return EvergreenRules.has_keyword(card, keyword_id)


static func _has_status(card: Dictionary, status_id: String) -> bool:
	return EvergreenRules.has_status(card, status_id)


static func _ensure_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


static func _ensure_dictionary(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


static func _invalid_result(message: String) -> Dictionary:
	return {
		"is_valid": false,
		"errors": [message],
	}