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
