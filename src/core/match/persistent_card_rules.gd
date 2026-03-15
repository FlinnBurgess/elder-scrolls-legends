class_name PersistentCardRules
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")

const PHASE_ACTION := "action"
const CARD_TYPE_CREATURE := "creature"
const CARD_TYPE_ITEM := "item"
const CARD_TYPE_SUPPORT := "support"
const ZONE_HAND := "hand"
const ZONE_LANE := "lane"
const ZONE_SUPPORT := "support"
const ZONE_ATTACHED_ITEM := "attached_item"


static func refresh_support_for_controller_turn(card: Dictionary) -> void:
	_ensure_support_state(card)
	card["activation_used_this_turn"] = false


static func can_activate_support(match_state: Dictionary, player_id: String, instance_id: String) -> bool:
	return bool(validate_activate_support(match_state, player_id, instance_id).get("is_valid", false))


static func play_support_from_hand(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var validation := _validate_hand_card(match_state, player_id, instance_id, CARD_TYPE_SUPPORT, "Support play", bool(options.get("played_for_free", false)))
	if not bool(validation.get("is_valid", false)):
		return validation
	var card: Dictionary = validation["card"]
	var play_cost := 0 if bool(options.get("played_for_free", false)) else get_effective_play_cost(match_state, player_id, card)
	if play_cost > 0:
		_spend_magicka(match_state, player_id, play_cost)
	_consume_cost_reduction(match_state, player_id)
	var moved := MatchMutations.move_card_to_zone(match_state, instance_id, ZONE_SUPPORT, {"target_player_id": player_id, "reason": str(options.get("reason", "play_support"))})
	if not bool(moved.get("is_valid", false)):
		return moved
	_ensure_support_state(card)
	var timing_result := MatchTiming.publish_events(match_state, [{
		"event_type": MatchTiming.EVENT_CARD_PLAYED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": player_id,
		"source_zone": ZONE_HAND,
		"target_zone": ZONE_SUPPORT,
		"card_type": CARD_TYPE_SUPPORT,
		"played_cost": int(card.get("cost", 0)),
		"played_for_free": bool(options.get("played_for_free", false)),
		"reason": str(options.get("reason", "play_support")),
	}])
	return {"is_valid": true, "errors": [], "card": card, "events": timing_result.get("processed_events", []), "trigger_resolutions": timing_result.get("trigger_resolutions", [])}


static func play_item_from_hand(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var validation := _validate_hand_card(match_state, player_id, instance_id, CARD_TYPE_ITEM, "Item play", bool(options.get("played_for_free", false)))
	if not bool(validation.get("is_valid", false)):
		return validation
	var item_card: Dictionary = validation["card"]

	var target_card: Dictionary = {}
	var generated_events: Array = []
	var target_instance_id := str(options.get("target_instance_id", ""))
	if target_instance_id.is_empty():
		if not _card_has_mobilize(item_card):
			return _invalid_result("Items require a creature target unless Mobilize can create a Recruit.")
		var mobilize_lane := _select_mobilize_lane(match_state, player_id, str(options.get("lane_id", "")))
		if mobilize_lane.is_empty():
			return _invalid_result("Mobilize item play requires an empty friendly lane option.")
		var recruit_template := EvergreenRules.build_mobilize_recruit(player_id, "")
		var recruit := MatchMutations.build_generated_card(match_state, player_id, recruit_template)
		var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, recruit, str(mobilize_lane.get("lane_id", "")), {
			"slot_index": int(mobilize_lane.get("slot_index", -1)),
			"source_zone": MatchMutations.ZONE_GENERATED,
		})
		if not bool(summon_result.get("is_valid", false)):
			return summon_result
		target_card = summon_result["card"]
		target_instance_id = str(target_card.get("instance_id", ""))
		generated_events.append({
			"event_type": MatchTiming.EVENT_CREATURE_SUMMONED,
			"player_id": player_id,
			"playing_player_id": player_id,
			"source_instance_id": target_instance_id,
			"source_controller_player_id": player_id,
			"lane_id": str(mobilize_lane.get("lane_id", "")),
			"slot_index": int(mobilize_lane.get("slot_index", -1)),
			"reason": "mobilize",
		})
	else:
		var target_lookup := MatchMutations.find_card_location(match_state, target_instance_id)
		if not bool(target_lookup.get("is_valid", false)):
			return target_lookup
		target_card = target_lookup["card"]
		if str(target_lookup.get("zone", "")) != ZONE_LANE or str(target_card.get("card_type", "")) != CARD_TYPE_CREATURE:
			return _invalid_result("Items can only target creatures in a lane.")

	var play_cost := 0 if bool(options.get("played_for_free", false)) else get_effective_play_cost(match_state, player_id, item_card)
	if play_cost > 0:
		_spend_magicka(match_state, player_id, play_cost)
	_consume_cost_reduction(match_state, player_id)

	var attach_result := MatchMutations.attach_item_to_creature(match_state, player_id, instance_id, target_instance_id, {"source_zone": ZONE_HAND})
	if not bool(attach_result.get("is_valid", false)):
		return attach_result
	generated_events.append({
		"event_type": MatchTiming.EVENT_CARD_PLAYED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": player_id,
		"source_zone": ZONE_HAND,
		"target_zone": ZONE_ATTACHED_ITEM,
		"target_instance_id": target_instance_id,
		"card_type": CARD_TYPE_ITEM,
		"played_cost": int(item_card.get("cost", 0)),
		"played_for_free": bool(options.get("played_for_free", false)),
		"reason": str(options.get("reason", "play_item")),
	})
	generated_events.append({
		"event_type": "card_equipped",
		"player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": str(attach_result["card"].get("controller_player_id", player_id)),
		"target_instance_id": target_instance_id,
	})
	var timing_result := MatchTiming.publish_events(match_state, generated_events)
	return {"is_valid": true, "errors": [], "card": attach_result["card"], "host": attach_result["host"], "events": timing_result.get("processed_events", []), "trigger_resolutions": timing_result.get("trigger_resolutions", [])}


static func validate_activate_support(match_state: Dictionary, player_id: String, instance_id: String) -> Dictionary:
	var owner_validation := _validate_action_owner(match_state, player_id, "Support activation")
	if not bool(owner_validation.get("is_valid", false)):
		return owner_validation
	var location := MatchMutations.find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	if str(location.get("zone", "")) != ZONE_SUPPORT:
		return _invalid_result("Support %s is not in the support zone." % instance_id)
	var card: Dictionary = location["card"]
	if str(card.get("card_type", "")) != CARD_TYPE_SUPPORT:
		return _invalid_result("Only support cards can be activated through support activation.")
	if str(card.get("controller_player_id", location.get("player_id", ""))) != player_id:
		return _invalid_result("Support %s is not controlled by %s." % [instance_id, player_id])
	_ensure_support_state(card)
	if bool(card.get("activation_used_this_turn", false)):
		return _invalid_result("Supports can only be activated once per turn.")
	if card.has("remaining_support_uses") and card.get("remaining_support_uses") != null and int(card.get("remaining_support_uses", 0)) <= 0:
		return _invalid_result("Support %s has no remaining uses." % instance_id)
	if not _has_activate_trigger(card):
		return _invalid_result("Support %s has no activate trigger descriptor." % instance_id)
	var activation_cost := int(card.get("activation_cost", 0))
	if activation_cost > _get_available_magicka(_get_player_state(match_state, player_id)):
		return _invalid_result("Player does not have enough magicka to activate support %s." % instance_id)
	return {"is_valid": true, "errors": [], "card": card}


static func activate_support(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var validation := validate_activate_support(match_state, player_id, instance_id)
	if not bool(validation.get("is_valid", false)):
		return validation
	var card: Dictionary = validation["card"]
	var activation_cost := int(card.get("activation_cost", 0))
	if activation_cost > 0:
		_spend_magicka(match_state, player_id, activation_cost)
	card["activation_used_this_turn"] = true
	if card.has("remaining_support_uses") and card.get("remaining_support_uses") != null:
		card["remaining_support_uses"] = maxi(0, int(card.get("remaining_support_uses", 0)) - 1)
	var timing_result := MatchTiming.publish_events(match_state, [{
		"event_type": MatchTiming.EVENT_SUPPORT_ACTIVATED,
		"player_id": player_id,
		"playing_player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": player_id,
		"target_instance_id": str(options.get("target_instance_id", "")),
		"target_player_id": str(options.get("target_player_id", "")),
		"lane_id": str(options.get("lane_id", "")),
		"activation_cost": activation_cost,
	}])
	var processed_events: Array = timing_result.get("processed_events", []).duplicate(true)
	var trigger_resolutions: Array = timing_result.get("trigger_resolutions", []).duplicate(true)
	if card.has("remaining_support_uses") and card.get("remaining_support_uses") != null and int(card.get("remaining_support_uses", 0)) == 0:
		var exhaustion_events := [{
			"event_type": "support_uses_exhausted",
			"player_id": player_id,
			"source_instance_id": instance_id,
			"remaining_uses": 0,
		}]
		var discard_result := MatchMutations.discard_card(match_state, instance_id, {"reason": "support_uses_exhausted"})
		exhaustion_events.append_array(discard_result.get("events", []))
		var exhaustion_timing := MatchTiming.publish_events(match_state, exhaustion_events)
		processed_events.append_array(exhaustion_timing.get("processed_events", []))
		trigger_resolutions.append_array(exhaustion_timing.get("trigger_resolutions", []))
	return {"is_valid": true, "errors": [], "card": card, "events": processed_events, "trigger_resolutions": trigger_resolutions}


static func _validate_hand_card(match_state: Dictionary, player_id: String, instance_id: String, expected_type: String, action_name: String, played_for_free: bool) -> Dictionary:
	var owner_validation := _validate_action_owner(match_state, player_id, action_name)
	if not bool(owner_validation.get("is_valid", false)):
		return owner_validation
	var location := MatchMutations.find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	if str(location.get("player_id", "")) != player_id or str(location.get("zone", "")) != ZONE_HAND:
		return _invalid_result("Card %s is not in %s's hand." % [instance_id, player_id])
	var card: Dictionary = location["card"]
	if str(card.get("card_type", "")) != expected_type:
		return _invalid_result("Card %s is not a %s." % [instance_id, expected_type])
	if not played_for_free and get_effective_play_cost(match_state, player_id, card) > _get_available_magicka(_get_player_state(match_state, player_id)):
		return _invalid_result("Player does not have enough magicka to play %s." % instance_id)
	return {"is_valid": true, "errors": [], "card": card}


static func _validate_action_owner(match_state: Dictionary, player_id: String, action_name: String) -> Dictionary:
	if match_state.get("phase", "") != PHASE_ACTION:
		return _invalid_result("%s can only be used during the action phase." % action_name)
	if str(match_state.get("active_player_id", "")) != player_id:
		return _invalid_result("%s is only legal for the active player." % action_name)
	if _get_player_state(match_state, player_id).is_empty():
		return _invalid_result("Unknown player_id: %s" % player_id)
	return {"is_valid": true, "errors": []}


static func _card_has_mobilize(card: Dictionary) -> bool:
	return EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_MOBILIZE)


static func _select_mobilize_lane(match_state: Dictionary, player_id: String, requested_lane_id: String) -> Dictionary:
	var options := EvergreenRules.get_mobilize_lane_options(match_state, player_id)
	if options.is_empty():
		return {}
	if requested_lane_id.is_empty() and options.size() == 1:
		return options[0]
	for option in options:
		if str(option.get("lane_id", "")) == requested_lane_id:
			return option
	return {}


static func _has_activate_trigger(card: Dictionary) -> bool:
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) == TYPE_DICTIONARY and str(trigger.get("family", "")) == MatchTiming.FAMILY_ACTIVATE:
			return true
	return false


static func _ensure_support_state(card: Dictionary) -> void:
	EvergreenRules.ensure_card_state(card)
	if not card.has("activation_used_this_turn"):
		card["activation_used_this_turn"] = false
	if not card.has("remaining_support_uses"):
		card["remaining_support_uses"] = null if card.get("support_uses", null) == null else int(card.get("support_uses", 0))


static func _get_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func get_effective_play_cost(match_state: Dictionary, player_id: String, card: Dictionary) -> int:
	var base_cost := int(card.get("cost", 0))
	var player := _get_player_state(match_state, player_id)
	var reduction := int(player.get("next_card_cost_reduction", 0))
	reduction += _get_aura_cost_reduction(match_state, player_id, card)
	return maxi(0, base_cost - reduction)


static func _get_aura_cost_reduction(match_state: Dictionary, player_id: String, card: Dictionary) -> int:
	var total := 0
	var card_type := str(card.get("card_type", ""))
	for lane in match_state.get("lanes", []):
		for lane_card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(lane_card) != TYPE_DICTIONARY:
				continue
			var aura = lane_card.get("cost_reduction_aura", {})
			if typeof(aura) != TYPE_DICTIONARY or aura.is_empty():
				continue
			var required_type := str(aura.get("card_type", ""))
			if not required_type.is_empty() and card_type != required_type:
				continue
			total += int(aura.get("amount", 0))
	for support_card in _get_player_state(match_state, player_id).get("support", []):
		if typeof(support_card) != TYPE_DICTIONARY:
			continue
		var aura = support_card.get("cost_reduction_aura", {})
		if typeof(aura) != TYPE_DICTIONARY or aura.is_empty():
			continue
		var required_type := str(aura.get("card_type", ""))
		if not required_type.is_empty() and card_type != required_type:
			continue
		total += int(aura.get("amount", 0))
	return total


static func _consume_cost_reduction(match_state: Dictionary, player_id: String) -> void:
	var player := _get_player_state(match_state, player_id)
	if int(player.get("next_card_cost_reduction", 0)) > 0:
		player["next_card_cost_reduction"] = 0


static func _get_available_magicka(player: Dictionary) -> int:
	return maxi(0, int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0)))


static func _spend_magicka(match_state: Dictionary, player_id: String, amount: int) -> void:
	var player := _get_player_state(match_state, player_id)
	var remaining := amount
	var temporary_magicka := int(player.get("temporary_magicka", 0))
	if temporary_magicka > 0:
		var temporary_spent := mini(temporary_magicka, remaining)
		player["temporary_magicka"] = temporary_magicka - temporary_spent
		remaining -= temporary_spent
	if remaining > 0:
		player["current_magicka"] = maxi(0, int(player.get("current_magicka", 0)) - remaining)


static func _invalid_result(message: String) -> Dictionary:
	return {"is_valid": false, "errors": [message]}