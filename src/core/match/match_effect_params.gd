class_name MatchEffectParams
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const Helpers = preload("res://src/core/match/match_timing_helpers.gd")

const ZONE_HAND := "hand"
const ZONE_DECK := "deck"
const CARD_TYPE_CREATURE := "creature"


static func _resolve_copies_in_hand_and_deck(match_state: Dictionary, trigger: Dictionary, effect: Dictionary) -> Array:
	var targets: Array = []
	var controller_id := str(trigger.get("controller_player_id", ""))
	var match_field := str(effect.get("match", ""))
	var definition_id := ""
	if match_field == "consumed_creature_name":
		var consumed := _get_consumed_card_info(trigger)
		if consumed.is_empty():
			var source := Helpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not source.is_empty():
				consumed = source.get("_consumed_card_info", {})
		definition_id = str(consumed.get("definition_id", ""))
	if not definition_id.is_empty():
		var player := Helpers._get_player_state(match_state, controller_id)
		if not player.is_empty():
			for card in player.get(ZONE_HAND, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == definition_id:
					targets.append(card)
			for card in player.get(ZONE_DECK, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == definition_id:
					targets.append(card)
	return targets


## Resolve an effect amount, checking for consumed_creature_* source references.


static func _resolve_consumed_amount(trigger: Dictionary, effect: Dictionary) -> int:
	return _resolve_amount(trigger, effect, {}, {})


static func _resolve_amount(trigger: Dictionary, effect: Dictionary, match_state: Dictionary, event: Dictionary) -> int:
	var amount_source := str(effect.get("amount_source", ""))
	if amount_source.is_empty():
		return int(effect.get("amount", 0))
	if amount_source.begins_with("consumed_creature_"):
		var consumed_info: Dictionary = _get_consumed_card_info(trigger)
		if amount_source == "consumed_creature_power":
			return int(consumed_info.get("power", 0))
		elif amount_source == "consumed_creature_health":
			return int(consumed_info.get("health", 0))
	if amount_source == "self_power":
		var source_card := Helpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
		if not source_card.is_empty():
			return EvergreenRules.get_power(source_card)
	if amount_source == "self_health":
		var source_card := Helpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
		if not source_card.is_empty():
			return EvergreenRules.get_remaining_health(source_card)
	if amount_source == "self_power_plus_health":
		var source_card := Helpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
		if not source_card.is_empty():
			return EvergreenRules.get_power(source_card) + EvergreenRules.get_remaining_health(source_card)
	if amount_source == "damage_taken":
		return int(event.get("damage_amount", event.get("amount", 0)))
	if amount_source == "heal_amount":
		return int(event.get("amount", 0))
	if amount_source == "oblivion_gate_level":
		var controller_id := str(trigger.get("controller_player_id", ""))
		var gate := ExtendedMechanicPacks._find_player_gate(match_state, controller_id)
		return int(gate.get("gate_level", 0))
	if amount_source == "destroyed_creature_power":
		var destroyed_id := str(event.get("target_instance_id", ""))
		var destroyed_card := Helpers._find_card_anywhere(match_state, destroyed_id)
		if not destroyed_card.is_empty():
			return EvergreenRules.get_power(destroyed_card)
		return 0
	if amount_source == "slain_creature_cost":
		var slain_id := str(event.get("instance_id", event.get("source_instance_id", "")))
		var slain_card := Helpers._find_card_anywhere(match_state, slain_id)
		if not slain_card.is_empty():
			return int(slain_card.get("cost", 0))
		return 0
	if amount_source == "creatures_died_this_turn":
		var controller_id := str(trigger.get("controller_player_id", ""))
		var player := Helpers._get_player_state(match_state, controller_id)
		return int(player.get("creatures_died_this_turn", 0))
	if amount_source == "event_damage_amount":
		return int(event.get("damage_amount", event.get("amount", 0)))
	if amount_source.ends_with("_counter"):
		var counter_name := amount_source.substr(0, amount_source.length() - 8)
		var source_card := Helpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
		if not source_card.is_empty():
			return int(source_card.get("_counter_" + counter_name, 0))
		return 0
	return int(effect.get("amount", 0))


## Get consumed card info from trigger context or from the source card.


static func _get_consumed_card_info(trigger: Dictionary) -> Dictionary:
	var info: Dictionary = trigger.get("_consumed_card_info", {})
	if not info.is_empty():
		return info
	# Fallback: check the source card for stored consumed info
	# This is used when effects fire via resolve_targeted_effect after consume
	return {}


static func _resolve_count_multiplier(match_state: Dictionary, trigger: Dictionary, _event: Dictionary, effect: Dictionary) -> int:
	var count_source := str(effect.get("count_source", ""))
	if count_source.is_empty():
		return 1
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var exclude_self := bool(effect.get("count_exclude_self", false))
	var self_instance_id := str(trigger.get("source_instance_id", ""))
	var count := 0
	match count_source:
		"friendly_creatures":
			var required_attr := str(effect.get("count_required_attribute", ""))
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(controller_player_id, [])
				for card in slots:
					if typeof(card) != TYPE_DICTIONARY:
						continue
					if exclude_self and str(card.get("instance_id", "")) == self_instance_id:
						continue
					if not required_attr.is_empty():
						var attrs = card.get("attributes", [])
						if typeof(attrs) != TYPE_ARRAY or not attrs.has(required_attr):
							continue
					count += 1
		"enemy_creatures_same_lane":
			var opponent_id := Helpers._get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var lane_index := int(trigger.get("lane_index", -1))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						count += 1
		"friendly_discard_creatures":
			var player := Helpers._get_player_state(match_state, controller_player_id)
			if not player.is_empty():
				for card in player.get("discard", []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						count += 1
		"destroyed_enemy_runes":
			var opponent_id := Helpers._get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var opponent := Helpers._get_player_state(match_state, opponent_id)
			if not opponent.is_empty():
				var remaining: Variant = opponent.get("rune_thresholds", [])
				count = 5 - (remaining.size() if typeof(remaining) == TYPE_ARRAY else 0)
		"friendly_creatures_with_keyword":
			var required_kw := str(effect.get("count_required_keyword", ""))
			if not required_kw.is_empty():
				for lane in match_state.get("lanes", []):
					var slots = lane.get("player_slots", {}).get(controller_player_id, [])
					for card in slots:
						if typeof(card) != TYPE_DICTIONARY:
							continue
						if exclude_self and str(card.get("instance_id", "")) == self_instance_id:
							continue
						if EvergreenRules.has_keyword(card, required_kw):
							count += 1
		"all_enemy_creatures":
			var aec_opponent_id := Helpers._get_opposing_player_id(match_state.get("players", []), controller_player_id)
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(aec_opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						count += 1
		"enemies_in_target_lane":
			var eitl_opponent_id := Helpers._get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var eitl_target_id := str(_event.get("target_instance_id", trigger.get("_chosen_target_id", "")))
			var eitl_lane_id := ""
			if not eitl_target_id.is_empty():
				var eitl_loc := MatchMutations.find_card_location(match_state, eitl_target_id)
				eitl_lane_id = str(eitl_loc.get("lane_id", ""))
			if not eitl_lane_id.is_empty():
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) == eitl_lane_id:
						var slots = lane.get("player_slots", {}).get(eitl_opponent_id, [])
						for card in slots:
							if typeof(card) == TYPE_DICTIONARY:
								count += 1
		"friendly_subtype_count", "friendly_creatures_with_subtype":
			var fsc_subtype := str(effect.get("count_subtype", ""))
			if not fsc_subtype.is_empty():
				for lane in match_state.get("lanes", []):
					var slots = lane.get("player_slots", {}).get(controller_player_id, [])
					for card in slots:
						if typeof(card) != TYPE_DICTIONARY:
							continue
						if exclude_self and str(card.get("instance_id", "")) == self_instance_id:
							continue
						var subtypes = card.get("subtypes", [])
						if typeof(subtypes) == TYPE_ARRAY and subtypes.has(fsc_subtype):
							count += 1
		"other_friendly_creatures":
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(controller_player_id, [])
				for card in slots:
					if typeof(card) != TYPE_DICTIONARY:
						continue
					if str(card.get("instance_id", "")) == self_instance_id:
						continue
					count += 1
		"enemy_creatures_in_lane":
			var ecil_opponent_id := Helpers._get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var ecil_lane_index := int(trigger.get("lane_index", -1))
			var ecil_lanes: Array = match_state.get("lanes", [])
			if ecil_lane_index >= 0 and ecil_lane_index < ecil_lanes.size():
				var slots = ecil_lanes[ecil_lane_index].get("player_slots", {}).get(ecil_opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						count += 1
		"undead_creatures_in_play":
			var undead_subtypes: Array = ExtendedMechanicPacks.SUBTYPE_GROUPS.get("Undead", [])
			for lane in match_state.get("lanes", []):
				for pid in lane.get("player_slots", {}).keys():
					for card in lane.get("player_slots", {}).get(pid, []):
						if typeof(card) != TYPE_DICTIONARY:
							continue
						if exclude_self and str(card.get("instance_id", "")) == self_instance_id:
							continue
						var subtypes = card.get("subtypes", [])
						if typeof(subtypes) == TYPE_ARRAY:
							for st in subtypes:
								if undead_subtypes.has(st):
									count += 1
									break
		"actions_in_discard":
			var aid_player := Helpers._get_player_state(match_state, controller_player_id)
			if not aid_player.is_empty():
				for card in aid_player.get("discard", []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "action":
						count += 1
		"copies_in_discard":
			var cid_name := str(effect.get("count_card_name", ""))
			if not cid_name.is_empty():
				var cid_player := Helpers._get_player_state(match_state, controller_player_id)
				if not cid_player.is_empty():
					for card in cid_player.get("discard", []):
						if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == cid_name:
							count += 1
		"friendly_supports":
			var fs_player := Helpers._get_player_state(match_state, controller_player_id)
			if not fs_player.is_empty():
				for card in fs_player.get("support", []):
					if typeof(card) == TYPE_DICTIONARY:
						count += 1
		"self_power":
			var sp_source := Helpers._find_card_anywhere(match_state, self_instance_id)
			if not sp_source.is_empty():
				count = EvergreenRules.get_power(sp_source)
		"deaths_this_turn":
			var dtt_event_log: Array = match_state.get("event_log", [])
			for i in range(dtt_event_log.size() - 1, -1, -1):
				var logged = dtt_event_log[i]
				if str(logged.get("event_type", "")) == "turn_started":
					break
				if str(logged.get("event_type", "")) == "creature_destroyed":
					count += 1
		"friendly_deaths_this_turn":
			var fdtt_event_log: Array = match_state.get("event_log", [])
			for i in range(fdtt_event_log.size() - 1, -1, -1):
				var logged = fdtt_event_log[i]
				if str(logged.get("event_type", "")) == "turn_started":
					break
				if str(logged.get("event_type", "")) == "creature_destroyed":
					if str(logged.get("controller_player_id", "")) == controller_player_id:
						count += 1
		"opponent_cards_drawn_this_turn":
			var ocdtt_opponent_id := Helpers._get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var ocdtt_event_log: Array = match_state.get("event_log", [])
			for i in range(ocdtt_event_log.size() - 1, -1, -1):
				var logged = ocdtt_event_log[i]
				if str(logged.get("event_type", "")) == "turn_started":
					break
				if str(logged.get("event_type", "")) == "card_drawn":
					if str(logged.get("player_id", "")) == ocdtt_opponent_id:
						count += 1
		"other_cards_played_this_turn":
			var ocptt_player := Helpers._get_player_state(match_state, controller_player_id)
			if not ocptt_player.is_empty():
				count = maxi(0, int(ocptt_player.get("cards_played_this_turn", 0)) - 1)
		"friendly_creatures_chosen_lane":
			var fccl_lane_id := str(_event.get("lane_id", ""))
			if not fccl_lane_id.is_empty():
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) == fccl_lane_id:
						var slots = lane.get("player_slots", {}).get(controller_player_id, [])
						for card in slots:
							if typeof(card) == TYPE_DICTIONARY:
								count += 1
		"skeevers_summoned_this_game":
			var ssthg_player := Helpers._get_player_state(match_state, controller_player_id)
			if not ssthg_player.is_empty():
				count = int(ssthg_player.get("skeevers_summoned_this_game", 0))
		"friendly_deaths_in_lane_this_turn":
			var trigger_lane_index := int(trigger.get("lane_index", -1))
			if trigger_lane_index < 0:
				return 0
			var lanes: Array = match_state.get("lanes", [])
			if trigger_lane_index >= lanes.size():
				return 0
			var lane_id := str(lanes[trigger_lane_index].get("lane_id", ""))
			var event_log: Array = match_state.get("event_log", [])
			for i in range(event_log.size() - 1, -1, -1):
				var logged = event_log[i]
				if str(logged.get("event_type", "")) == "turn_started":
					break
				if str(logged.get("event_type", "")) == "creature_destroyed":
					if str(logged.get("lane_id", "")) == lane_id:
						if str(logged.get("controller_player_id", "")) == controller_player_id:
							count += 1
	return count


static func _deterministic_index(match_state: Dictionary, context_id: String, pool_size: int) -> int:
	if pool_size <= 0:
		return 0
	var fingerprint := "%s|%s|%s" % [str(match_state.get("rng_seed", 0)), str(match_state.get("turn_number", 0)), context_id]
	var seed_value: int = 1469598103934665603
	for byte in fingerprint.to_utf8_buffer():
		seed_value = int((seed_value * 1099511628211 + int(byte)) % 9223372036854775783)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randi_range(0, pool_size - 1)

