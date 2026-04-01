class_name MatchSummonTiming
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")
const MatchTargeting = preload("res://src/core/match/match_targeting.gd")

const EVENT_CREATURE_SUMMONED := "creature_summoned"


static func _resolve_effect_template(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var template: Dictionary = effect.get("card_template", {})
	if not template.is_empty():
		return template
	var copy_source := str(effect.get("copy_of", effect.get("source_target", "event_source")))
	var source_cards := MatchTargeting._resolve_card_targets_by_name(match_state, trigger, event, copy_source)
	return {} if source_cards.is_empty() else source_cards[0].duplicate(true)


static func _process_treasure_hunt(match_state: Dictionary, trigger: Dictionary, event: Dictionary, descriptor: Dictionary) -> Dictionary:
	var events: Array = []
	var source_id := str(trigger.get("source_instance_id", ""))
	var source := MatchTimingHelpers._find_card_anywhere(match_state, source_id)
	if source.is_empty():
		return {"events": events, "hunt_complete": false}
	var trigger_index := int(trigger.get("trigger_index", 0))
	var spent_key := "_th_%d_spent" % trigger_index
	if bool(source.get(spent_key, false)):
		return {"events": events, "hunt_complete": false}
	var hunt_types = descriptor.get("hunt_types", [])
	if typeof(hunt_types) != TYPE_ARRAY or hunt_types.is_empty():
		return {"events": events, "hunt_complete": false}
	# Get the drawn card from the event
	var drawn_id := str(event.get("drawn_instance_id", event.get("instance_id", "")))
	if drawn_id.is_empty():
		return {"events": events, "hunt_complete": false}
	var drawn_card := MatchTimingHelpers._find_card_anywhere(match_state, drawn_id)
	if drawn_card.is_empty():
		return {"events": events, "hunt_complete": false}
	var controller_id := str(trigger.get("controller_player_id", ""))
	var hunt_count := int(descriptor.get("hunt_count", 0))
	var is_multi_type: bool = hunt_types.size() > 1 and not hunt_types.has("any") and hunt_count == 0
	if is_multi_type:
		# Multi-type hunt (e.g. Aldora: Action, Creature, Item, Support) — need one of each type
		var found_key := "_th_%d_found" % trigger_index
		var found_types: Array = []
		var raw_found = source.get(found_key, [])
		if typeof(raw_found) == TYPE_ARRAY:
			found_types = raw_found.duplicate()
		# Find which unfound type this drawn card matches
		var matched_type := ""
		for ht in hunt_types:
			if found_types.has(str(ht)):
				continue
			if _card_matches_treasure_hunt(drawn_card, [ht]):
				matched_type = str(ht)
				break
		if matched_type.is_empty():
			return {"events": events, "hunt_complete": false}
		found_types.append(matched_type)
		source[found_key] = found_types
		source["_treasure_card_instance_id"] = drawn_id
		events.append({
			"event_type": "treasure_found",
			"source_instance_id": source_id,
			"controller_player_id": controller_id,
			"player_id": controller_id,
			"count": found_types.size(),
			"drawn_instance_id": drawn_id,
		})
		if found_types.size() >= hunt_types.size():
			source[spent_key] = true
			return {"events": events, "hunt_complete": true}
	else:
		# Single-type or "any" hunt — count matches until hunt_count reached
		if not _card_matches_treasure_hunt(drawn_card, hunt_types):
			return {"events": events, "hunt_complete": false}
		if hunt_count <= 0:
			hunt_count = 1
		var count_key := "_th_%d_count" % trigger_index
		var current_count := int(source.get(count_key, 0))
		current_count += 1
		source[count_key] = current_count
		source["_treasure_card_instance_id"] = drawn_id
		events.append({
			"event_type": "treasure_found",
			"source_instance_id": source_id,
			"controller_player_id": controller_id,
			"player_id": controller_id,
			"count": current_count,
			"drawn_instance_id": drawn_id,
		})
		if current_count >= hunt_count:
			source[spent_key] = true
			return {"events": events, "hunt_complete": true}
	return {"events": events, "hunt_complete": false}


static func _card_matches_treasure_hunt(card: Dictionary, hunt_types: Array) -> bool:
	if hunt_types.has("any"):
		return true
	var card_type := str(card.get("card_type", ""))
	for ht in hunt_types:
		var hunt_type := str(ht)
		match hunt_type:
			"creature", "action", "item", "support":
				if card_type == hunt_type:
					return true
			"zero_cost":
				if int(card.get("cost", 0)) == 0:
					return true
			"neutral":
				# Neutral cards have no primary attributes (attributes array is empty after normalization)
				var neutral_attrs = card.get("attributes", [])
				if typeof(neutral_attrs) != TYPE_ARRAY or neutral_attrs.is_empty():
					return true
			_:
				# Check as a keyword
				if EvergreenRules.has_keyword(card, hunt_type):
					return true
				# Check in base keywords array
				var keywords = card.get("keywords", [])
				if typeof(keywords) == TYPE_ARRAY and keywords.has(hunt_type):
					return true
				# Check as an attribute
				var attributes = card.get("attributes", [])
				if typeof(attributes) == TYPE_ARRAY and attributes.has(hunt_type):
					return true
	return false


static func _resolve_summon_lane_id(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary, controller_id: String) -> String:
	var lane_id := str(effect.get("lane_id", effect.get("target_lane_id", "")))
	if lane_id == "same":
		lane_id = str(event.get("lane_id", ""))
	if lane_id == "other_lane":
		var source_lane := str(event.get("lane_id", ""))
		for lane in match_state.get("lanes", []):
			var lid := str(lane.get("lane_id", ""))
			if lid != source_lane and not lid.is_empty():
				lane_id = lid
				break
	if lane_id.is_empty() or lane_id == "other_lane":
		var trigger_lane_index := int(trigger.get("lane_index", -1))
		var lanes: Array = match_state.get("lanes", [])
		if trigger_lane_index >= 0 and trigger_lane_index < lanes.size():
			lane_id = str(lanes[trigger_lane_index].get("lane_id", ""))
	if lane_id.is_empty():
		# Fall back to lane with most open slots
		var best_lane := ""
		var best_open := -1
		for lane in match_state.get("lanes", []):
			var lid := str(lane.get("lane_id", ""))
			var open_info := MatchTimingHelpers._get_lane_open_slots(match_state, lid, controller_id)
			var open_count := int(open_info.get("open_slots", 0))
			if open_count > best_open:
				best_open = open_count
				best_lane = lid
		lane_id = best_lane
	return lane_id


static func _build_summon_event(card: Dictionary, player_id: String, lane_id: String, slot_index: int, reason: String) -> Dictionary:
	return {
		"event_type": EVENT_CREATURE_SUMMONED,
		"player_id": player_id,
		"playing_player_id": player_id,
		"source_instance_id": str(card.get("instance_id", "")),
		"source_controller_player_id": str(card.get("controller_player_id", player_id)),
		"lane_id": lane_id,
		"slot_index": slot_index,
		"reason": reason,
	}


## Budget summon loop: summon random Daedra from the catalog until the budget is exhausted
## or all lanes are full. If a summoned creature has a targeting summon ability, the loop
## pauses by saving remaining budget to pending_budget_summons; it resumes after targeting resolves.

