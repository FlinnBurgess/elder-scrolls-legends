extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")


static func inject_lane_triggers(match_state: Dictionary, registry: Array) -> void:
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var lane_id := str(lane.get("lane_id", ""))
		var lane_type := str(lane.get("lane_type", lane_id))
		var payload: Dictionary = lane.get("lane_rule_payload", {})
		var effects: Array = payload.get("effects", [])
		for effect_index in range(effects.size()):
			var effect: Dictionary = effects[effect_index]
			if typeof(effect) != TYPE_DICTIONARY or effect.is_empty():
				continue
			var descriptor: Dictionary = effect.duplicate(true)
			descriptor["_lane_trigger"] = true
			descriptor["_lane_id"] = lane_id
			descriptor["_lane_index"] = lane_index
			descriptor["_lane_type"] = lane_type
			var trigger_id := "lane_%s_effect_%d" % [lane_id, effect_index]
			registry.append({
				"trigger_id": trigger_id,
				"trigger_index": -1,
				"source_instance_id": trigger_id,
				"owner_player_id": "",
				"controller_player_id": "",
				"source_zone": "lane_effect",
				"lane_index": lane_index,
				"slot_index": -1,
				"descriptor": descriptor,
			})


static func apply_lane_effect(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var op := str(effect.get("op", ""))
	match op:
		"lane_grant_cover":
			return _resolve_lane_grant_cover(match_state, trigger, event)
		"lane_dementia_damage":
			return _resolve_lane_dementia_damage(match_state, trigger, event, effect)
		_:
			return {"handled": false, "events": []}


static func _resolve_lane_grant_cover(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Dictionary:
	var creature_id := str(event.get("source_instance_id", ""))
	if creature_id.is_empty():
		return {"handled": true, "events": []}

	var location := MatchMutations.find_card_location(match_state, creature_id)
	if not bool(location.get("is_valid", false)):
		return {"handled": true, "events": []}
	var card: Dictionary = location.get("card", {})

	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	# For summon events, lane_id is on the event; for move events, read from the card
	var event_lane_id := str(event.get("lane_id", str(card.get("lane_id", ""))))
	if lane_id != event_lane_id:
		return {"handled": true, "events": []}

	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
		return {"handled": true, "events": []}

	var self_immunities = card.get("self_immunity", [])
	if typeof(self_immunities) == TYPE_ARRAY and self_immunities.has("cover"):
		return {"handled": true, "events": []}

	if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER):
		return {"handled": true, "events": []}

	var cover_offset := 1 if str(card.get("controller_player_id", "")) == str(match_state.get("active_player_id", "")) else 0
	EvergreenRules.grant_cover(card, int(match_state.get("turn_number", 0)) + cover_offset)

	var events: Array = [{
		"event_type": "status_granted",
		"source_instance_id": creature_id,
		"target_instance_id": creature_id,
		"status_id": "cover",
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": event_lane_id,
		"granted_by": "lane_effect",
	}]
	return {"handled": true, "events": events}


static func _resolve_lane_dementia_damage(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var active_player_id := str(event.get("player_id", ""))
	if active_player_id.is_empty():
		return {"handled": true, "events": []}

	var lane: Dictionary = {}
	for l in match_state.get("lanes", []):
		if str(l.get("lane_id", "")) == lane_id:
			lane = l
			break
	if lane.is_empty():
		return {"handled": true, "events": []}

	var highest_per_player := {}
	var player_slots: Dictionary = lane.get("player_slots", {})
	for pid in player_slots:
		var max_power := -1
		for card in player_slots[pid]:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var power := EvergreenRules.get_power(card)
			if power > max_power:
				max_power = power
		if max_power >= 0:
			highest_per_player[str(pid)] = max_power

	if highest_per_player.is_empty():
		return {"handled": true, "events": []}
	var best_power := -1
	var best_owner := ""
	var tied := false
	for pid in highest_per_player:
		var power: int = highest_per_player[pid]
		if power > best_power:
			best_power = power
			best_owner = pid
			tied = false
		elif power == best_power:
			tied = true

	if tied or best_owner != active_player_id:
		return {"handled": true, "events": []}

	var opponent_id := ""
	for player in match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != active_player_id:
			opponent_id = str(player.get("player_id", ""))
			break
	if opponent_id.is_empty():
		return {"handled": true, "events": []}

	var amount := int(effect.get("amount", 3))
	var damage_result: Dictionary = _timing_rules().apply_player_damage(match_state, opponent_id, amount, {
		"reason": "lane_effect_dementia",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": active_player_id,
	})

	var events: Array = [{
		"event_type": "damage_resolved",
		"damage_kind": "lane_effect_dementia",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": active_player_id,
		"target_type": "player",
		"target_player_id": opponent_id,
		"amount": int(damage_result.get("applied_damage", 0)),
		"lane_id": lane_id,
	}]
	events.append_array(damage_result.get("events", []))
	return {"handled": true, "events": events}


static func _timing_rules():
	return load("res://src/core/match/match_timing.gd")
