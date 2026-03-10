class_name MatchActionEnumerator
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")

const FORMAT_VERSION := 1
const ACTION_PHASE := "action"
const TIMING_ACTION := "action"
const TIMING_INTERRUPT := "interrupt"
const KIND_RING_USE := "use_ring"
const KIND_END_TURN := "end_turn"
const KIND_SUMMON_CREATURE := "summon_creature"
const KIND_ATTACK := "attack"
const KIND_PLAY_SUPPORT := "play_support"
const KIND_PLAY_ITEM := "play_item"
const KIND_ACTIVATE_SUPPORT := "activate_support"
const KIND_PLAY_ACTION := "play_action"
const KIND_DECLINE_PROPHECY := "decline_prophecy"
const ACTION_KIND_ORDER := {
	KIND_SUMMON_CREATURE: 10,
	KIND_DECLINE_PROPHECY: 11,
	KIND_RING_USE: 20,
	KIND_SUMMON_CREATURE + ":turn": 30,
	KIND_ATTACK: 40,
	KIND_PLAY_SUPPORT: 50,
	KIND_PLAY_ITEM: 60,
	KIND_ACTIVATE_SUPPORT: 70,
	KIND_PLAY_ACTION: 80,
	KIND_END_TURN: 90,
}


static func enumerate_legal_actions(match_state: Dictionary, player_id: String = "") -> Dictionary:
	MatchTiming.ensure_match_state(match_state)
	var requested_player_id := player_id
	var decision_player_id := _resolve_decision_player_id(match_state, player_id)
	var result := {
		"format_version": FORMAT_VERSION,
		"requested_player_id": requested_player_id,
		"decision_player_id": decision_player_id,
		"active_player_id": str(match_state.get("active_player_id", "")),
		"phase": str(match_state.get("phase", "")),
		"timing_window": TIMING_INTERRUPT if MatchTiming.has_pending_prophecy(match_state) else TIMING_ACTION,
		"has_pending_prophecy": MatchTiming.has_pending_prophecy(match_state),
		"winner_player_id": str(match_state.get("winner_player_id", "")),
		"blocked_reason": "",
		"actions": [],
	}
	if decision_player_id.is_empty():
		result["blocked_reason"] = "No legal actor could be determined from the current match state."
		return result
	if not str(result.get("winner_player_id", "")).is_empty():
		result["blocked_reason"] = "Match already has a winner."
		return result
	if MatchTiming.has_pending_prophecy(match_state):
		var pending_player_id := _resolve_pending_prophecy_player_id(match_state)
		if decision_player_id != pending_player_id:
			result["blocked_reason"] = "Pending Prophecy window belongs to another player."
			return result
		result["actions"] = _enumerate_pending_prophecy_actions(match_state, decision_player_id)
	else:
		if str(match_state.get("phase", "")) != ACTION_PHASE:
			result["blocked_reason"] = "Actions can only be enumerated during the action phase."
			return result
		if decision_player_id != str(match_state.get("active_player_id", "")):
			result["blocked_reason"] = "Only the active player can act during the action phase."
			return result
		var actions: Array = []
		actions.append_array(_enumerate_ring_actions(match_state, decision_player_id))
		actions.append_array(_enumerate_creature_summons(match_state, decision_player_id, false))
		actions.append_array(_enumerate_attacks(match_state, decision_player_id))
		actions.append_array(_enumerate_support_plays(match_state, decision_player_id))
		actions.append_array(_enumerate_item_plays(match_state, decision_player_id, false))
		actions.append_array(_enumerate_support_activations(match_state, decision_player_id))
		actions.append_array(_enumerate_action_plays(match_state, decision_player_id, false))
		actions.append(_build_descriptor(KIND_END_TURN, match_state, decision_player_id, {}, {}, {
			"timing_window": TIMING_ACTION,
			"order_key": ACTION_KIND_ORDER[KIND_END_TURN],
		}))
		result["actions"] = actions
	_assign_sequences(result.get("actions", []))
	return result


static func action_is_legal(match_state: Dictionary, action: Dictionary) -> bool:
	var player_id := str(action.get("player_id", ""))
	var source_instance_id := str(action.get("source_instance_id", ""))
	var parameters: Dictionary = action.get("parameters", {}).duplicate(true)
	match str(action.get("kind", "")):
		KIND_RING_USE:
			return MatchTurnLoop.can_activate_ring_of_magicka(match_state, player_id)
		KIND_END_TURN:
			if MatchTiming.has_pending_prophecy(match_state):
				return false
			var clone := match_state.duplicate(true)
			var active_before := str(clone.get("active_player_id", ""))
			MatchTurnLoop.end_turn(clone, player_id)
			return active_before != str(clone.get("active_player_id", ""))
		KIND_SUMMON_CREATURE:
			if str(action.get("response_kind", "")) == MatchTiming.RULE_TAG_PROPHECY:
				return bool(MatchTiming.play_pending_prophecy(match_state.duplicate(true), player_id, source_instance_id, parameters).get("is_valid", false))
			return bool(LaneRules.validate_summon_from_hand(match_state, player_id, source_instance_id, str(parameters.get("lane_id", "")), {
				"slot_index": int(parameters.get("slot_index", -1)),
			}).get("is_valid", false))
		KIND_ATTACK:
			return bool(MatchCombat.validate_attack(match_state, player_id, source_instance_id, parameters.get("target", {})).get("is_valid", false))
		KIND_PLAY_SUPPORT:
			return bool(PersistentCardRules.play_support_from_hand(match_state.duplicate(true), player_id, source_instance_id, parameters).get("is_valid", false))
		KIND_PLAY_ITEM:
			return bool(PersistentCardRules.play_item_from_hand(match_state.duplicate(true), player_id, source_instance_id, parameters).get("is_valid", false))
		KIND_ACTIVATE_SUPPORT:
			if not bool(PersistentCardRules.validate_activate_support(match_state, player_id, source_instance_id).get("is_valid", false)):
				return false
			return bool(PersistentCardRules.activate_support(match_state.duplicate(true), player_id, source_instance_id, parameters).get("is_valid", false))
		KIND_PLAY_ACTION:
			if str(action.get("response_kind", "")) == MatchTiming.RULE_TAG_PROPHECY:
				return bool(MatchTiming.play_pending_prophecy(match_state.duplicate(true), player_id, source_instance_id, parameters).get("is_valid", false))
			return bool(MatchTiming.play_action_from_hand(match_state.duplicate(true), player_id, source_instance_id, parameters).get("is_valid", false))
		KIND_DECLINE_PROPHECY:
			return bool(MatchTiming.decline_pending_prophecy(match_state.duplicate(true), player_id, source_instance_id).get("is_valid", false))
	return false


static func _enumerate_pending_prophecy_actions(match_state: Dictionary, player_id: String) -> Array:
	var actions: Array = []
	for window in MatchTiming.get_pending_prophecies(match_state, player_id):
		var instance_id := str(window.get("instance_id", window.get("drawn_instance_id", "")))
		var card := _find_card(match_state, instance_id)
		if card.is_empty():
			continue
		var card_type := str(card.get("card_type", ""))
		if card_type == "creature":
			actions.append_array(_enumerate_creature_prophecy_plays(match_state, player_id, card))
		elif card_type == "action":
			var play_action := _build_descriptor(KIND_PLAY_ACTION, match_state, player_id, card, {}, {
				"timing_window": TIMING_INTERRUPT,
				"response_kind": MatchTiming.RULE_TAG_PROPHECY,
				"played_for_free": true,
				"order_key": ACTION_KIND_ORDER[KIND_SUMMON_CREATURE],
			})
			if action_is_legal(match_state, play_action):
				actions.append(play_action)
		var decline_action := _build_descriptor(KIND_DECLINE_PROPHECY, match_state, player_id, card, {}, {
			"timing_window": TIMING_INTERRUPT,
			"response_kind": MatchTiming.RULE_TAG_PROPHECY,
			"played_for_free": false,
			"order_key": ACTION_KIND_ORDER[KIND_DECLINE_PROPHECY],
		})
		if action_is_legal(match_state, decline_action):
			actions.append(decline_action)
	return actions


static func _enumerate_creature_prophecy_plays(match_state: Dictionary, player_id: String, card: Dictionary) -> Array:
	var actions: Array = []
	for lane in match_state.get("lanes", []):
		var lane_id := str(lane.get("lane_id", ""))
		var slots: Array = lane.get("player_slots", {}).get(player_id, [])
		for slot_index in range(slots.size()):
			var descriptor := _build_descriptor(KIND_SUMMON_CREATURE, match_state, player_id, card, {
				"lane_id": lane_id,
				"slot_index": slot_index,
			}, {
				"timing_window": TIMING_INTERRUPT,
				"response_kind": MatchTiming.RULE_TAG_PROPHECY,
				"played_for_free": true,
				"order_key": ACTION_KIND_ORDER[KIND_SUMMON_CREATURE],
			})
			if action_is_legal(match_state, descriptor):
				actions.append(descriptor)
	return actions


static func _enumerate_ring_actions(match_state: Dictionary, player_id: String) -> Array:
	if not MatchTurnLoop.can_activate_ring_of_magicka(match_state, player_id):
		return []
	return [_build_descriptor(KIND_RING_USE, match_state, player_id, {}, {}, {
		"timing_window": TIMING_ACTION,
		"order_key": ACTION_KIND_ORDER[KIND_RING_USE],
	})]


static func _enumerate_creature_summons(match_state: Dictionary, player_id: String, played_for_free: bool) -> Array:
	var actions: Array = []
	for card in _player_zone_cards(match_state, player_id, MatchMutations.ZONE_HAND):
		if str(card.get("card_type", "")) != "creature":
			continue
		for lane in match_state.get("lanes", []):
			var lane_id := str(lane.get("lane_id", ""))
			var slots: Array = lane.get("player_slots", {}).get(player_id, [])
			for slot_index in range(slots.size()):
				var descriptor := _build_descriptor(KIND_SUMMON_CREATURE, match_state, player_id, card, {
					"lane_id": lane_id,
					"slot_index": slot_index,
				}, {
					"timing_window": TIMING_ACTION,
					"played_for_free": played_for_free,
					"order_key": ACTION_KIND_ORDER[KIND_SUMMON_CREATURE + ":turn"],
				})
				if action_is_legal(match_state, descriptor):
					actions.append(descriptor)
	return actions


static func _enumerate_attacks(match_state: Dictionary, player_id: String) -> Array:
	var actions: Array = []
	for card in _lane_cards_for_player(match_state, player_id):
		var attacker_instance_id := str(card.get("instance_id", ""))
		for target_card in _enemy_lane_cards(match_state, player_id, str(card.get("lane_id", ""))):
			var creature_target := {"type": MatchCombat.TARGET_TYPE_CREATURE, "instance_id": str(target_card.get("instance_id", ""))}
			var attack_creature := _build_descriptor(KIND_ATTACK, match_state, player_id, card, {
				"target": creature_target,
			}, {
				"timing_window": TIMING_ACTION,
				"order_key": ACTION_KIND_ORDER[KIND_ATTACK],
			})
			if action_is_legal(match_state, attack_creature):
				actions.append(attack_creature)
		var defending_player_id := _opposing_player_id(match_state, player_id)
		if not defending_player_id.is_empty():
			var player_target := {"type": MatchCombat.TARGET_TYPE_PLAYER, "player_id": defending_player_id}
			var attack_player := _build_descriptor(KIND_ATTACK, match_state, player_id, card, {
				"target": player_target,
			}, {
				"timing_window": TIMING_ACTION,
				"order_key": ACTION_KIND_ORDER[KIND_ATTACK],
			})
			if action_is_legal(match_state, attack_player):
				actions.append(attack_player)
	return actions


static func _enumerate_support_plays(match_state: Dictionary, player_id: String) -> Array:
	var actions: Array = []
	for card in _player_zone_cards(match_state, player_id, MatchMutations.ZONE_HAND):
		if str(card.get("card_type", "")) != "support":
			continue
		var descriptor := _build_descriptor(KIND_PLAY_SUPPORT, match_state, player_id, card, {}, {
			"timing_window": TIMING_ACTION,
			"order_key": ACTION_KIND_ORDER[KIND_PLAY_SUPPORT],
		})
		if action_is_legal(match_state, descriptor):
			actions.append(descriptor)
	return actions


static func _enumerate_item_plays(match_state: Dictionary, player_id: String, played_for_free: bool) -> Array:
	var actions: Array = []
	for card in _player_zone_cards(match_state, player_id, MatchMutations.ZONE_HAND):
		if str(card.get("card_type", "")) != "item":
			continue
		for target_card in _all_lane_cards(match_state):
			var descriptor := _build_descriptor(KIND_PLAY_ITEM, match_state, player_id, card, {
				"target_instance_id": str(target_card.get("instance_id", "")),
			}, {
				"timing_window": TIMING_ACTION,
				"played_for_free": played_for_free,
				"order_key": ACTION_KIND_ORDER[KIND_PLAY_ITEM],
			})
			if action_is_legal(match_state, descriptor):
				actions.append(descriptor)
		if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_MOBILIZE):
			for lane_option in EvergreenRules.get_mobilize_lane_options(match_state, player_id):
				var mobilize_descriptor := _build_descriptor(KIND_PLAY_ITEM, match_state, player_id, card, {
					"lane_id": str(lane_option.get("lane_id", "")),
					"slot_index": int(lane_option.get("slot_index", -1)),
				}, {
					"timing_window": TIMING_ACTION,
					"played_for_free": played_for_free,
					"order_key": ACTION_KIND_ORDER[KIND_PLAY_ITEM],
					"generated_target": {
						"kind": "mobilize_recruit",
						"lane_id": str(lane_option.get("lane_id", "")),
						"slot_index": int(lane_option.get("slot_index", -1)),
					},
				})
				if action_is_legal(match_state, mobilize_descriptor):
					actions.append(mobilize_descriptor)
	return actions


static func _enumerate_support_activations(match_state: Dictionary, player_id: String) -> Array:
	var actions: Array = []
	for card in _player_zone_cards(match_state, player_id, MatchMutations.ZONE_SUPPORT):
		if not bool(PersistentCardRules.validate_activate_support(match_state, player_id, str(card.get("instance_id", ""))).get("is_valid", false)):
			continue
		var requirements := _collect_target_requirements(_activation_triggers(card))
		for parameters in _expand_target_parameter_sets(match_state, requirements):
			var descriptor := _build_descriptor(KIND_ACTIVATE_SUPPORT, match_state, player_id, card, parameters, {
				"timing_window": TIMING_ACTION,
				"order_key": ACTION_KIND_ORDER[KIND_ACTIVATE_SUPPORT],
			})
			if action_is_legal(match_state, descriptor):
				actions.append(descriptor)
	return actions


static func _enumerate_action_plays(match_state: Dictionary, player_id: String, played_for_free: bool) -> Array:
	var actions: Array = []
	for card in _player_zone_cards(match_state, player_id, MatchMutations.ZONE_HAND):
		if str(card.get("card_type", "")) != "action":
			continue
		for variant in _action_play_variants(card):
			var variant_card: Dictionary = variant.get("card", card).duplicate(true)
			var base_parameters: Dictionary = variant.get("parameters", {}).duplicate(true)
			var requirements := _collect_target_requirements(_play_triggers(variant_card))
			for target_parameters in _expand_target_parameter_sets(match_state, requirements):
				var parameters := base_parameters.duplicate(true)
				for key in target_parameters.keys():
					parameters[key] = target_parameters[key]
				var descriptor := _build_descriptor(KIND_PLAY_ACTION, match_state, player_id, variant_card, parameters, {
					"timing_window": TIMING_ACTION,
					"played_for_free": played_for_free,
					"order_key": ACTION_KIND_ORDER[KIND_PLAY_ACTION],
					"variant_label": str(variant.get("label", "")),
				})
				if action_is_legal(match_state, descriptor):
					actions.append(descriptor)
	return actions


static func _action_play_variants(card: Dictionary) -> Array:
	var variants: Array = [{"card": card.duplicate(true), "parameters": {}, "label": ""}]
	var double_options: Array = _clone_array(card.get("double_card_options", []))
	if not double_options.is_empty():
		variants = []
		for index in range(double_options.size()):
			var choice: Variant = index
			if typeof(double_options[index]) == TYPE_DICTIONARY:
				choice = double_options[index].get("id", index)
			var clone: Dictionary = card.duplicate(true)
			ExtendedMechanicPacks.apply_pre_play_options(clone, {"double_card_choice": choice})
			variants.append({
				"card": clone,
				"parameters": {"double_card_choice": choice},
				"label": str(choice),
			})
	if _card_has_exalt_variant(card):
		var exalted: Array = []
		for variant in variants:
			exalted.append(variant)
			var exalt_clone: Dictionary = variant.get("card", card).duplicate(true)
			var exalt_parameters: Dictionary = variant.get("parameters", {}).duplicate(true)
			exalt_parameters["exalt"] = true
			ExtendedMechanicPacks.apply_pre_play_options(exalt_clone, exalt_parameters)
			exalted.append({
				"card": exalt_clone,
				"parameters": exalt_parameters,
				"label": "%s:exalt" % str(variant.get("label", "base")),
			})
		variants = exalted
	return variants


static func _card_has_exalt_variant(card: Dictionary) -> bool:
	for trigger in _play_triggers(card):
		for effect in trigger.get("effects", []):
			if typeof(effect) == TYPE_DICTIONARY and str(effect.get("required_source_status", "")) == EvergreenRules.STATUS_EXALTED:
				return true
	return false


static func _play_triggers(card: Dictionary) -> Array:
	var triggers: Array = []
	for raw_trigger in card.get("triggered_abilities", []):
		if typeof(raw_trigger) != TYPE_DICTIONARY:
			continue
		var trigger: Dictionary = raw_trigger
		var family := str(trigger.get("family", ""))
		if family == MatchTiming.FAMILY_ON_PLAY:
			triggers.append(trigger)
			continue
		if str(trigger.get("event_type", "")) == MatchTiming.EVENT_CARD_PLAYED:
			var match_role := str(trigger.get("match_role", "source"))
			if match_role == "source" or match_role == "either" or match_role == "subject":
				triggers.append(trigger)
	return triggers


static func _activation_triggers(card: Dictionary) -> Array:
	var triggers: Array = []
	for raw_trigger in card.get("triggered_abilities", []):
		if typeof(raw_trigger) == TYPE_DICTIONARY and str(raw_trigger.get("family", "")) == MatchTiming.FAMILY_ACTIVATE:
			triggers.append(raw_trigger)
	return triggers


static func _collect_target_requirements(triggers: Array) -> Dictionary:
	var requirements := {
		"needs_player_target": false,
		"needs_card_target": false,
		"needs_lane_id": false,
	}
	for trigger in triggers:
		for raw_effect in trigger.get("effects", []):
			if typeof(raw_effect) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = raw_effect
			if str(effect.get("target_player", "")) == "target_player":
				requirements["needs_player_target"] = true
			var target := str(effect.get("target", ""))
			var source_target := str(effect.get("source_target", ""))
			var consumer_target := str(effect.get("consumer_target", ""))
			if target == "event_target" or source_target == "event_target" or consumer_target == "event_target":
				requirements["needs_card_target"] = true
			var op := str(effect.get("op", ""))
			if (op == "move_between_lanes" or op == "summon_from_effect") and str(effect.get("lane_id", "")).is_empty() and str(effect.get("target_lane_id", "")).is_empty():
				requirements["needs_lane_id"] = true
	return requirements


static func _expand_target_parameter_sets(match_state: Dictionary, requirements: Dictionary) -> Array:
	var parameter_sets: Array = [{}]
	if bool(requirements.get("needs_player_target", false)):
		var expanded_player_sets: Array = []
		for parameters in parameter_sets:
			for player_id in _player_ids(match_state):
				var next_parameters: Dictionary = parameters.duplicate(true)
				next_parameters["target_player_id"] = player_id
				expanded_player_sets.append(next_parameters)
		parameter_sets = expanded_player_sets
	if bool(requirements.get("needs_card_target", false)):
		var expanded_card_sets: Array = []
		for parameters in parameter_sets:
			for card in _all_lane_cards(match_state):
				var next_parameters: Dictionary = parameters.duplicate(true)
				next_parameters["target_instance_id"] = str(card.get("instance_id", ""))
				expanded_card_sets.append(next_parameters)
		parameter_sets = expanded_card_sets
	if bool(requirements.get("needs_lane_id", false)):
		var expanded_lane_sets: Array = []
		for parameters in parameter_sets:
			for lane in match_state.get("lanes", []):
				var next_parameters: Dictionary = parameters.duplicate(true)
				next_parameters["lane_id"] = str(lane.get("lane_id", ""))
				expanded_lane_sets.append(next_parameters)
		parameter_sets = expanded_lane_sets
	return parameter_sets


static func _build_descriptor(kind: String, match_state: Dictionary, player_id: String, source_card: Dictionary, parameters: Dictionary, extras: Dictionary) -> Dictionary:
	var action := {
		"id": "",
		"kind": kind,
		"player_id": player_id,
		"timing_window": str(extras.get("timing_window", TIMING_ACTION)),
		"response_kind": str(extras.get("response_kind", "")),
		"played_for_free": bool(extras.get("played_for_free", false)),
		"variant_label": str(extras.get("variant_label", "")),
		"source_instance_id": str(source_card.get("instance_id", "")),
		"source_card": _card_summary(source_card),
		"parameters": parameters.duplicate(true),
		"target": _build_target_summary(match_state, parameters, extras),
		"generated_target": extras.get("generated_target", {}).duplicate(true),
		"cost": _build_cost_summary(kind, source_card, parameters, extras),
		"order_key": int(extras.get("order_key", 999)),
	}
	action["id"] = _build_action_id(action)
	return action


static func _build_cost_summary(kind: String, source_card: Dictionary, parameters: Dictionary, extras: Dictionary) -> Dictionary:
	var played_for_free := bool(extras.get("played_for_free", false))
	var base_cost := 0 if source_card.is_empty() else int(source_card.get("cost", 0))
	var total_cost := 0 if played_for_free else base_cost + (1 if bool(parameters.get("exalt", false)) else 0)
	if kind == KIND_ACTIVATE_SUPPORT:
		total_cost = 0 if played_for_free else int(source_card.get("activation_cost", 0))
	return {
		"resource": "magicka",
		"base_cost": base_cost,
		"total_cost": total_cost,
		"played_for_free": played_for_free,
		"activation_cost": int(source_card.get("activation_cost", 0)),
	}


static func _build_target_summary(match_state: Dictionary, parameters: Dictionary, extras: Dictionary) -> Dictionary:
	if parameters.has("target"):
		var attack_target: Dictionary = parameters.get("target", {})
		if str(attack_target.get("type", "")) == MatchCombat.TARGET_TYPE_PLAYER:
			return {
				"kind": "player",
				"player_id": str(attack_target.get("player_id", "")),
			}
		var attack_card := _find_card(match_state, str(attack_target.get("instance_id", "")))
		return {
			"kind": "card",
			"instance_id": str(attack_target.get("instance_id", "")),
			"card": _card_summary(attack_card),
		}
	if parameters.has("target_instance_id"):
		var target_card := _find_card(match_state, str(parameters.get("target_instance_id", "")))
		return {
			"kind": "card",
			"instance_id": str(parameters.get("target_instance_id", "")),
			"card": _card_summary(target_card),
		}
	if parameters.has("target_player_id"):
		return {
			"kind": "player",
			"player_id": str(parameters.get("target_player_id", "")),
		}
	if parameters.has("lane_id"):
		return {
			"kind": "lane_slot",
			"lane_id": str(parameters.get("lane_id", "")),
			"slot_index": int(parameters.get("slot_index", -1)),
		}
	if extras.has("generated_target"):
		return extras.get("generated_target", {}).duplicate(true)
	return {}


static func _build_action_id(action: Dictionary) -> String:
	var parts: Array = [str(action.get("kind", "")), str(action.get("player_id", "")), str(action.get("source_instance_id", ""))]
	var parameters: Dictionary = action.get("parameters", {})
	if parameters.has("lane_id"):
		parts.append("lane=%s" % str(parameters.get("lane_id", "")))
	if parameters.has("slot_index"):
		parts.append("slot=%d" % int(parameters.get("slot_index", -1)))
	if parameters.has("target_instance_id"):
		parts.append("target=%s" % str(parameters.get("target_instance_id", "")))
	if parameters.has("target_player_id"):
		parts.append("player=%s" % str(parameters.get("target_player_id", "")))
	if parameters.has("target"):
		var attack_target: Dictionary = parameters.get("target", {})
		parts.append("target_type=%s" % str(attack_target.get("type", "")))
		if attack_target.has("instance_id"):
			parts.append("target=%s" % str(attack_target.get("instance_id", "")))
		if attack_target.has("player_id"):
			parts.append("player=%s" % str(attack_target.get("player_id", "")))
	if bool(parameters.get("exalt", false)):
		parts.append("exalt")
	if parameters.has("double_card_choice"):
		parts.append("double=%s" % str(parameters.get("double_card_choice", "")))
	if str(action.get("response_kind", "")).is_empty() == false:
		parts.append("response=%s" % str(action.get("response_kind", "")))
	return ":".join(parts)


static func _assign_sequences(actions: Array) -> void:
	for index in range(actions.size()):
		actions[index]["sequence"] = index


static func _resolve_decision_player_id(match_state: Dictionary, requested_player_id: String) -> String:
	if MatchTiming.has_pending_prophecy(match_state):
		if not requested_player_id.is_empty():
			return requested_player_id
		return _resolve_pending_prophecy_player_id(match_state)
	return requested_player_id if not requested_player_id.is_empty() else str(match_state.get("active_player_id", ""))


static func _resolve_pending_prophecy_player_id(match_state: Dictionary) -> String:
	var windows := MatchTiming.get_pending_prophecies(match_state)
	if windows.is_empty():
		return ""
	return str(windows[0].get("player_id", ""))


static func _player_zone_cards(match_state: Dictionary, player_id: String, zone_name: String) -> Array:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player.get(zone_name, [])
	return []


static func _lane_cards_for_player(match_state: Dictionary, player_id: String) -> Array:
	var cards: Array = []
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				cards.append(card)
	return cards


static func _enemy_lane_cards(match_state: Dictionary, player_id: String, lane_id: String) -> Array:
	var cards: Array = []
	var opponent_id := _opposing_player_id(match_state, player_id)
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for card in lane.get("player_slots", {}).get(opponent_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				cards.append(card)
	return cards


static func _all_lane_cards(match_state: Dictionary) -> Array:
	var cards: Array = []
	for lane in match_state.get("lanes", []):
		for player_id in _player_ids(match_state):
			for card in lane.get("player_slots", {}).get(player_id, []):
				if typeof(card) == TYPE_DICTIONARY:
					cards.append(card)
	return cards


static func _player_ids(match_state: Dictionary) -> Array:
	var ids: Array = []
	for player in match_state.get("players", []):
		ids.append(str(player.get("player_id", "")))
	return ids


static func _opposing_player_id(match_state: Dictionary, player_id: String) -> String:
	for candidate in _player_ids(match_state):
		if candidate != player_id:
			return candidate
	return ""


static func _find_card(match_state: Dictionary, instance_id: String) -> Dictionary:
	var lookup := MatchMutations.find_card_location(match_state, instance_id)
	return lookup.get("card", {}) if bool(lookup.get("is_valid", false)) else {}


static func _card_summary(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	return {
		"instance_id": str(card.get("instance_id", "")),
		"definition_id": str(card.get("definition_id", "")),
		"name": str(card.get("name", "")),
		"card_type": str(card.get("card_type", "")),
		"zone": str(card.get("zone", "")),
		"controller_player_id": str(card.get("controller_player_id", "")),
		"owner_player_id": str(card.get("owner_player_id", "")),
		"cost": int(card.get("cost", 0)),
		"activation_cost": int(card.get("activation_cost", 0)),
		"power": EvergreenRules.get_power(card),
		"health": EvergreenRules.get_health(card),
		"remaining_health": EvergreenRules.get_remaining_health(card),
		"lane_id": str(card.get("lane_id", "")),
		"slot_index": int(card.get("slot_index", -1)),
		"keywords": _clone_array(card.get("keywords", [])),
		"granted_keywords": _clone_array(card.get("granted_keywords", [])),
		"rules_tags": _clone_array(card.get("rules_tags", [])),
	}


static func _clone_array(value) -> Array:
	return value.duplicate(true) if typeof(value) == TYPE_ARRAY else []