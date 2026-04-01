class_name MatchTimingHelpers
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")

const ZONE_HAND := "hand"
const ZONE_DECK := "deck"
const ZONE_LANE := "lane"
const ZONE_SUPPORT := "support"
const ZONE_DISCARD := "discard"
const ZONE_BANISHED := "banished"
const ZONE_GENERATED := "generated"

const CARD_TYPE_CREATURE := "creature"

const RULE_TAG_PROPHECY := "prophecy"

const PLAYER_ZONE_ORDER := [ZONE_HAND, ZONE_SUPPORT, ZONE_DISCARD, ZONE_BANISHED, ZONE_DECK]

const WINDOW_AFTER := "after"

const STATUS_EXALTED := "exalted"


static func _get_card_lane_index(match_state: Dictionary, instance_id: String) -> int:
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
		for pid in player_slots.keys():
			for card in player_slots[pid]:
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return lane_index
	return -1


static func _all_lane_creatures(match_state: Dictionary) -> Array:
	var creatures: Array = []
	for lane in match_state.get("lanes", []):
		var player_slots: Dictionary = lane.get("player_slots", {})
		for pid in player_slots.keys():
			for card in player_slots[pid]:
				if typeof(card) == TYPE_DICTIONARY:
					creatures.append(card)
	return creatures


static func _player_lane_creatures(match_state: Dictionary, player_id: String) -> Array:
	var creatures: Array = []
	for lane in match_state.get("lanes", []):
		var slots = lane.get("player_slots", {}).get(player_id, [])
		for card in slots:
			if typeof(card) == TYPE_DICTIONARY:
				creatures.append(card)
	return creatures


static func _lane_creatures_for_player(match_state: Dictionary, lane_index: int, player_id: String) -> Array:
	var creatures: Array = []
	var lanes: Array = match_state.get("lanes", [])
	if lane_index >= 0 and lane_index < lanes.size():
		var slots = lanes[lane_index].get("player_slots", {}).get(player_id, [])
		for card in slots:
			if typeof(card) == TYPE_DICTIONARY:
				creatures.append(card)
	return creatures


static func _lane_creatures_at(match_state: Dictionary, lane_index: int) -> Array:
	var creatures: Array = []
	var lanes: Array = match_state.get("lanes", [])
	if lane_index >= 0 and lane_index < lanes.size():
		var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
		for pid in player_slots.keys():
			for card in player_slots[pid]:
				if typeof(card) == TYPE_DICTIONARY:
					creatures.append(card)
	return creatures


static func _get_lane_open_slots(match_state: Dictionary, lane_id: String, player_id: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		var player_slots: Array = lane.get("player_slots", {}).get(player_id, [])
		var slot_capacity := int(lane.get("slot_capacity", 0))
		return {"open_slots": maxi(0, slot_capacity - player_slots.size())}
	return {"open_slots": 0}


static func _find_player_by_id(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _dictionary_has_string(values, expected: String) -> bool:
	if typeof(values) != TYPE_ARRAY:
		return false
	for value in values:
		if str(value) == expected:
			return true
	return false


static func _find_card_index(cards, instance_id: String) -> int:
	if typeof(cards) != TYPE_ARRAY:
		return -1
	for index in range(cards.size()):
		var card = cards[index]
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
			return index
	return -1


static func _get_opposing_player_id(players, player_id: String) -> String:
	if typeof(players) != TYPE_ARRAY:
		return ""
	for player in players:
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != player_id:
			return str(player.get("player_id", ""))
	return ""


static func _invalid_result(message: String) -> Dictionary:
	return {
		"is_valid": false,
		"errors": [message],
	}


static func _validate_action_owner(match_state: Dictionary, player_id: String, action_name: String) -> Dictionary:
	if match_state.get("phase", "") != "action":
		return _invalid_result("%s can only be used during the action phase." % action_name)
	if str(match_state.get("active_player_id", "")) != player_id:
		return _invalid_result("%s is only legal for the active player." % action_name)
	if _get_player_state(match_state, player_id).is_empty():
		return _invalid_result("Unknown player_id: %s" % player_id)
	return {"is_valid": true, "errors": []}


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


static func _get_aura_cost_reduction(match_state: Dictionary, player_id: String, card: Dictionary) -> int:
	var total := 0
	var card_type := str(card.get("card_type", ""))
	var all_aura_sources: Array = []
	for lane in match_state.get("lanes", []):
		for lane_card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(lane_card) != TYPE_DICTIONARY:
				continue
			var aura = lane_card.get("cost_reduction_aura", {})
			if typeof(aura) == TYPE_DICTIONARY and not aura.is_empty():
				all_aura_sources.append(aura)
	for support_card in _get_player_state(match_state, player_id).get("support", []):
		if typeof(support_card) != TYPE_DICTIONARY:
			continue
		var aura = support_card.get("cost_reduction_aura", {})
		if typeof(aura) == TYPE_DICTIONARY and not aura.is_empty():
			all_aura_sources.append(aura)
	for aura in all_aura_sources:
		var required_type := str(aura.get("card_type", ""))
		if not required_type.is_empty() and card_type != required_type:
			continue
		if not _cost_reduction_condition_met(match_state, player_id, card, aura):
			continue
		var aura_filter_subtype := str(aura.get("filter_subtype", ""))
		if not aura_filter_subtype.is_empty():
			var card_subtypes = card.get("subtypes", [])
			if typeof(card_subtypes) != TYPE_ARRAY or not card_subtypes.has(aura_filter_subtype):
				continue
		total += int(aura.get("amount", 0))
	# Match-state-level cost reduction auras (e.g. Oblivion Gate Daedra discount)
	for ms_aura in match_state.get("card_cost_reduction_auras", []):
		if str(ms_aura.get("controller_player_id", "")) != player_id:
			continue
		var ms_filter_subtype := str(ms_aura.get("filter_subtype", ""))
		if not ms_filter_subtype.is_empty():
			var card_subtypes = card.get("subtypes", [])
			if typeof(card_subtypes) != TYPE_ARRAY or not card_subtypes.has(ms_filter_subtype):
				continue
		total += int(ms_aura.get("amount", 0))
	total -= load("res://src/core/match/persistent_card_rules.gd")._get_global_cost_increase(match_state, card_type)
	return total


static func _cost_reduction_condition_met(match_state: Dictionary, player_id: String, card: Dictionary, aura: Dictionary) -> bool:
	var condition := str(aura.get("condition", ""))
	if condition.is_empty():
		return true
	match condition:
		"creature_in_each_lane":
			for lane in match_state.get("lanes", []):
				var slots: Array = lane.get("player_slots", {}).get(player_id, [])
				if slots.is_empty():
					return false
			return true
		"required_singleton_deck":
			return bool(_get_player_state(match_state, player_id).get("_singleton_deck", false))
		"filter_deals_damage":
			# Only reduce cost of actions that deal damage
			if str(card.get("card_type", "")) != "action":
				return false
			var effect_ids = card.get("effect_ids", [])
			return typeof(effect_ids) == TYPE_ARRAY and (effect_ids.has("damage") or effect_ids.has("deal_damage"))
		"filter_min_power":
			var min_power := int(aura.get("min_power", 5))
			return EvergreenRules.get_power(card) >= min_power
		"filter_not_in_starting_deck":
			return bool(card.get("_not_in_starting_deck", false))
	return true


static func _has_cannot_lose(match_state: Dictionary, player_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if not EvergreenRules._has_passive(card, "cannot_lose"):
				continue
			for p in card.get("passive_abilities", []):
				if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "cannot_lose":
					continue
				var condition := str(p.get("condition", ""))
				if condition == "has_exalted_creature":
					for check_lane in match_state.get("lanes", []):
						for check_card in check_lane.get("player_slots", {}).get(player_id, []):
							if typeof(check_card) == TYPE_DICTIONARY and EvergreenRules.has_status(check_card, EvergreenRules.STATUS_EXALTED):
								return true
				elif condition.is_empty():
					return true
	return false


static func _get_heal_multiplier(match_state: Dictionary, player_id: String) -> int:
	var multiplier := 1
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var passives = card.get("passive_abilities", [])
			if typeof(passives) == TYPE_ARRAY:
				for p in passives:
					if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "double_health_gain":
						multiplier *= 2
	return multiplier


static func _player_has_grants_immunity(match_state: Dictionary, player_id: String, immunity_key: String) -> bool:
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var immunities = card.get("grants_immunity", [])
			if typeof(immunities) == TYPE_ARRAY and immunities.has(immunity_key):
				return true
	return false


static func _get_max_magicka_cap(match_state: Dictionary) -> int:
	var cap := 0
	for lane in match_state.get("lanes", []):
		for player_slots in lane.get("player_slots", []):
			if typeof(player_slots) == TYPE_ARRAY:
				for card in player_slots:
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "max_magicka_cap"):
						for p in card.get("passive_abilities", []):
							if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "max_magicka_cap":
								var p_cap := int(p.get("cap", 7))
								if cap == 0 or p_cap < cap:
									cap = p_cap
			elif typeof(player_slots) == TYPE_DICTIONARY:
				for pid in player_slots.keys():
					for card in player_slots.get(pid, []):
						if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "max_magicka_cap"):
							for p in card.get("passive_abilities", []):
								if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "max_magicka_cap":
									var p_cap := int(p.get("cap", 7))
									if cap == 0 or p_cap < cap:
										cap = p_cap
	return cap


static func _get_min_card_cost(match_state: Dictionary) -> int:
	var min_cost := 0
	for lane in match_state.get("lanes", []):
		for player_slots in lane.get("player_slots", []):
			if typeof(player_slots) == TYPE_ARRAY:
				for card in player_slots:
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "min_card_cost"):
						for p in card.get("passive_abilities", []):
							if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "min_card_cost":
								min_cost = maxi(min_cost, int(p.get("min_cost", 3)))
			elif typeof(player_slots) == TYPE_DICTIONARY:
				for pid in player_slots.keys():
					for card in player_slots.get(pid, []):
						if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "min_card_cost"):
							for p in card.get("passive_abilities", []):
								if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "min_card_cost":
									min_cost = maxi(min_cost, int(p.get("min_cost", 3)))
	return min_cost


static func _is_immune_to_effect(match_state: Dictionary, target_card: Dictionary, effect_type: String) -> bool:
	var self_immunities = target_card.get("self_immunity", [])
	if typeof(self_immunities) == TYPE_ARRAY and self_immunities.has(effect_type):
		return true
	var controller_id := str(target_card.get("controller_player_id", ""))
	var target_id := str(target_card.get("instance_id", ""))
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(controller_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if str(card.get("instance_id", "")) == target_id:
				continue
			var immunities = card.get("grants_immunity", [])
			if typeof(immunities) == TYPE_ARRAY and immunities.has(effect_type):
				return true
	return false


static func _should_double_summon_trigger(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> bool:
	var family := str(trigger.get("descriptor", {}).get("family", ""))
	if family != "summon":
		return false
	var controller_id := str(trigger.get("controller_player_id", ""))
	var player := _get_player_state(match_state, controller_id)
	if not bool(player.get("_double_summon_this_turn", false)):
		return false
	# Only double for neutral cards — neutral cards have an empty attributes array
	# because "neutral" is not a primary attribute and gets filtered by normalize_attribute_ids
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	if source_card.is_empty():
		return false
	var attributes = source_card.get("attributes", [])
	if typeof(attributes) != TYPE_ARRAY:
		return false
	return attributes.is_empty() or attributes.has("neutral")


static func _update_assemble_rules_text(card: Dictionary, label: String, text_template: String) -> void:
	if label.is_empty() or text_template.is_empty():
		return
	# Calculate current stacked amount from the triggered ability
	var total_amount := 0
	for ability in card.get("triggered_abilities", []):
		if typeof(ability) == TYPE_DICTIONARY and str(ability.get("_assemble_label", "")) == label:
			for eff in ability.get("effects", []):
				if typeof(eff) == TYPE_DICTIONARY and eff.has("amount"):
					total_amount = int(eff.get("amount", 0))
					break
			break
	var new_line := text_template.replace("{amount}", str(total_amount))
	# Build assemble text tracking dict
	var assemble_texts: Dictionary = card.get("_assemble_texts", {})
	assemble_texts[label] = new_line
	card["_assemble_texts"] = assemble_texts
	# Rebuild rules_text: original text + assembled lines
	var base_text := str(card.get("_base_rules_text", card.get("rules_text", "")))
	if not card.has("_base_rules_text"):
		card["_base_rules_text"] = base_text
	var parts: Array = [base_text] if not base_text.is_empty() else []
	for key in assemble_texts.keys():
		parts.append(str(assemble_texts[key]))
	card["rules_text"] = "\n".join(parts)


static func _find_card_anywhere(match_state: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for player in match_state.get("players", []):
		for zone_name in PLAYER_ZONE_ORDER:
			var cards = player.get(zone_name, [])
			if typeof(cards) != TYPE_ARRAY:
				continue
			for card in cards:
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return card
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots = player_slots_by_id[player_id]
			if typeof(slots) != TYPE_ARRAY:
				continue
			for card in slots:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == instance_id:
					return card
				for attached_item in card.get("attached_items", []):
					if typeof(attached_item) == TYPE_DICTIONARY and str(attached_item.get("instance_id", "")) == instance_id:
						return attached_item
	return {}


static func _count_player_attributes(match_state: Dictionary, player_id: String) -> int:
	var seen: Dictionary = {}
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return 0
	for zone_name in ["deck", "hand", "discard", "support"]:
		for card in player.get(zone_name, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var attrs = card.get("attributes", [])
			if typeof(attrs) == TYPE_ARRAY:
				for attr in attrs:
					if str(attr) != "neutral":
						seen[str(attr)] = true
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var attrs = card.get("attributes", [])
			if typeof(attrs) == TYPE_ARRAY:
				for attr in attrs:
					if str(attr) != "neutral":
						seen[str(attr)] = true
	return seen.size()


static func _get_empower_amount(match_state: Dictionary, controller_player_id: String) -> int:
	var player := _get_player_state(match_state, controller_player_id)
	if player.is_empty():
		return 0
	ExtendedMechanicPacks.ensure_player_state(player)
	return int(player.get("empower_count_this_turn", 0)) + int(player.get("_permanent_empower_accumulated", 0))


static func _get_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _normalize_event(match_state: Dictionary, raw_event: Dictionary, context: Dictionary) -> Dictionary:
	match_state["next_event_sequence"] = int(match_state.get("next_event_sequence", 0)) + 1
	var event := raw_event.duplicate(true)
	event["event_id"] = "event_%04d" % int(match_state["next_event_sequence"])
	if not event.has("timing_window"):
		event["timing_window"] = str(context.get("timing_window", WINDOW_AFTER))
	if context.has("parent_event_id"):
		event["parent_event_id"] = str(context.get("parent_event_id", ""))
	if context.has("produced_by_resolution_id"):
		event["produced_by_resolution_id"] = str(context.get("produced_by_resolution_id", ""))
	return event


static func _append_event_log(match_state: Dictionary, event: Dictionary) -> void:
	var event_log: Array = match_state.get("event_log", [])
	event_log.append(event.duplicate(true))
	match_state["event_log"] = event_log


static func _append_replay_entry(match_state: Dictionary, entry: Dictionary) -> void:
	var replay_log: Array = match_state.get("replay_log", [])
	replay_log.append(entry.duplicate(true))
	match_state["replay_log"] = replay_log


static func _event_subject_instance_id(event: Dictionary) -> String:
	return str(event.get("instance_id", event.get("source_instance_id", "")))


static func _event_target_instance_id(event: Dictionary) -> String:
	if event.has("target_instance_id"):
		return str(event.get("target_instance_id", ""))
	if str(event.get("target_type", "")) == "creature":
		return str(event.get("instance_id", ""))
	return ""


static func _is_prophecy_card(card: Dictionary) -> bool:
	return _dictionary_has_string(card.get("rules_tags", []), RULE_TAG_PROPHECY) or _dictionary_has_string(card.get("keywords", []), RULE_TAG_PROPHECY)

