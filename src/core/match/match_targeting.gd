class_name MatchTargeting
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")
const MatchEffectParams = preload("res://src/core/match/match_effect_params.gd")

const ZONE_HAND := "hand"
const ZONE_DECK := "deck"
const ZONE_LANE := "lane"
const ZONE_SUPPORT := "support"
const ZONE_DISCARD := "discard"
const ZONE_BANISHED := "banished"
const ZONE_GENERATED := "generated"

const CARD_TYPE_CREATURE := "creature"
const CARD_TYPE_ACTION := "action"
const CARD_TYPE_ITEM := "item"
const CARD_TYPE_SUPPORT := "support"


static func get_target_mode_abilities(card: Dictionary) -> Array:
	var abilities: Array = []
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY:
		return abilities
	for trigger in raw_triggers:
		if typeof(trigger) == TYPE_DICTIONARY and not str(trigger.get("target_mode", "")).is_empty():
			abilities.append(trigger)
	return abilities


static func get_valid_targets_for_mode(match_state: Dictionary, source_instance_id: String, target_mode: String, trigger: Dictionary = {}) -> Array:
	var source_card := MatchTimingHelpers._find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return []
	var controller_id := str(source_card.get("controller_player_id", ""))
	var opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), controller_id)
	var source_lane_index := MatchTimingHelpers._get_card_lane_index(match_state, source_instance_id)
	var targets: Array = []
	match target_mode:
		"any_creature":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
		"another_creature":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"enemy_creature":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, opponent_id)
		"friendly_creature":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, controller_id)
		"another_friendly_creature":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"another_friendly_creature_in_lane":
			if source_lane_index >= 0:
				targets = MatchTimingHelpers._lane_creatures_for_player(match_state, source_lane_index, controller_id)
				targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"creature_or_player":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets.append({"player_id": opponent_id})
		"enemy_creature_in_lane":
			if source_lane_index >= 0:
				targets = MatchTimingHelpers._lane_creatures_for_player(match_state, source_lane_index, opponent_id)
		"any_creature_in_lane":
			if source_lane_index >= 0:
				targets = MatchTimingHelpers._lane_creatures_at(match_state, source_lane_index)
				targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"creature_less_power_than_self":
			var self_power := EvergreenRules.get_power(source_card)
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id and EvergreenRules.get_power(c) < self_power)
		"creature_in_lane_less_power":
			var self_power_cilp := EvergreenRules.get_power(source_card)
			if source_lane_index >= 0:
				targets = MatchTimingHelpers._lane_creatures_at(match_state, source_lane_index)
				targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id and EvergreenRules.get_power(c) < self_power_cilp)
		"another_neutral_creature":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets = targets.filter(func(c):
				if str(c.get("instance_id", "")) == source_instance_id:
					return false
				var attrs = c.get("attributes", [])
				return typeof(attrs) == TYPE_ARRAY and attrs.has("neutral"))
		"enemy_creature_2_power_or_less":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, opponent_id)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) <= 2)
		"friendly_creature_5_power":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id and EvergreenRules.get_power(c) >= 5)
		"friendly_discard_creature_less_power":
			var self_power_fdclp := EvergreenRules.get_power(source_card)
			for player in match_state.get("players", []):
				if str(player.get("player_id", "")) != controller_id:
					continue
				for card in player.get("discard", []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature" and EvergreenRules.get_power(card) < self_power_fdclp:
						targets.append(card)
		"wounded_enemy_creature":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, opponent_id)
			targets = targets.filter(func(c): return EvergreenRules.has_status(c, EvergreenRules.STATUS_WOUNDED))
		"enemy_support":
			for player in match_state.get("players", []):
				if typeof(player) != TYPE_DICTIONARY or str(player.get("player_id", "")) != opponent_id:
					continue
				for card in player.get("support", []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"enemy_creature_or_support":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, opponent_id)
			for player in match_state.get("players", []):
				if typeof(player) != TYPE_DICTIONARY or str(player.get("player_id", "")) != opponent_id:
					continue
				for card in player.get("support", []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"creature_1_power_or_less":
			var c1pol_max := 1
			var c1pol_empower := int(source_card.get("_empower_target_bonus", 0))
			if c1pol_empower > 0:
				c1pol_max += c1pol_empower * MatchTimingHelpers._get_empower_amount(match_state, controller_id)
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) <= c1pol_max)
		"creature_4_power_or_less":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) <= 4)
		"creature_4_power_or_more":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) >= 4)
		"creature_with_0_power":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) == 0)
		"enemy_creature_3_power_or_less":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, opponent_id)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) <= 3)
		"creature_in_other_lane":
			var other_lane_index := -1
			for li in range(match_state.get("lanes", []).size()):
				if li != source_lane_index:
					other_lane_index = li
					break
			if other_lane_index >= 0:
				targets = MatchTimingHelpers._lane_creatures_at(match_state, other_lane_index)
		"friendly_creature_without_guard":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return not EvergreenRules.has_keyword(c, EvergreenRules.KEYWORD_GUARD))
		"enemy_creature_optional":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, opponent_id)
		"another_friendly_creature_optional":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"any_creature_or_player":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets.append({"player_id": controller_id})
			targets.append({"player_id": opponent_id})
		"enemy_creature_less_power_than_self_health":
			var self_health_eclptsh := EvergreenRules.get_remaining_health(source_card)
			targets = MatchTimingHelpers._player_lane_creatures(match_state, opponent_id)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) < self_health_eclptsh)
		"two_creatures", "three_creatures":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
		"creature_in_hand":
			var cih_player := MatchTimingHelpers._get_player_state(match_state, controller_id)
			if not cih_player.is_empty():
				for card in cih_player.get(ZONE_HAND, []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						targets.append(card)
		"opponent_discard_card":
			var odc_opponent := MatchTimingHelpers._get_player_state(match_state, opponent_id)
			if not odc_opponent.is_empty():
				for card in odc_opponent.get(ZONE_DISCARD, []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"choose_lane_and_owner":
			# Return both player IDs as targets — UI will present lane selection
			targets.append({"player_id": controller_id})
			targets.append({"player_id": opponent_id})
		"friendly_creature_with_3_items":
			targets = MatchTimingHelpers._player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c):
				var items = c.get("attached_items", [])
				return typeof(items) == TYPE_ARRAY and items.size() >= 3)
		"another_creature_with_cover":
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id and EvergreenRules.has_status(c, EvergreenRules.STATUS_COVER))
		"enemy_creature_and_friendly_creature":
			# Return all creatures — UI handles the two-step pick
			targets = MatchTimingHelpers._all_lane_creatures(match_state)
		"friendly_creature_other_lane_from_primary":
			var primary_id_fcolp := str(source_card.get("_primary_target_id", ""))
			if not primary_id_fcolp.is_empty():
				var primary_card_fcolp := MatchTimingHelpers._find_card_anywhere(match_state, primary_id_fcolp)
				if not primary_card_fcolp.is_empty():
					var primary_lane_idx := MatchTimingHelpers._get_card_lane_index(match_state, primary_id_fcolp)
					for li in range(match_state.get("lanes", []).size()):
						if li != primary_lane_idx:
							targets.append_array(MatchTimingHelpers._lane_creatures_for_player(match_state, li, controller_id))
	# Apply additional filters from trigger descriptor
	var max_power := int(trigger.get("target_filter_max_power", -1))
	if max_power >= 0:
		targets = targets.filter(func(c): return c.has("instance_id") and EvergreenRules.get_power(c) <= max_power)
	if bool(trigger.get("target_filter_wounded", false)):
		targets = targets.filter(func(c): return c.has("instance_id") and EvergreenRules.has_status(c, EvergreenRules.STATUS_WOUNDED))
	if bool(trigger.get("required_friendly_higher_power", false)):
		var max_friendly_power := 0
		for lane in match_state.get("lanes", []):
			for card in lane.get("player_slots", {}).get(controller_id, []):
				if typeof(card) == TYPE_DICTIONARY:
					var p := EvergreenRules.get_power(card)
					if p > max_friendly_power:
						max_friendly_power = p
		targets = targets.filter(func(c): return c.has("instance_id") and EvergreenRules.get_power(c) < max_friendly_power)
	# Filter out creatures immune to action targeting (e.g. Iron Atronach, Nahagliiv)
	if str(source_card.get("card_type", "")) == "action":
		targets = targets.filter(func(c):
			if not c.has("instance_id"):
				return true
			var immunities = c.get("self_immunity", [])
			if typeof(immunities) != TYPE_ARRAY or not immunities.has("action_targeting"):
				return true
			return str(c.get("controller_player_id", "")) == controller_id
		)
		# protect_friendly_from_actions: if opponent has a creature with this passive,
		# we can't target their other creatures with actions
		var protectors: Dictionary = {}
		for lane in match_state.get("lanes", []):
			for pid in lane.get("player_slots", {}).keys():
				if pid == controller_id:
					continue
				for card in lane.get("player_slots", {}).get(pid, []):
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "protect_friendly_from_actions"):
						protectors[pid] = str(card.get("instance_id", ""))
		if not protectors.is_empty():
			targets = targets.filter(func(c):
				if not c.has("instance_id"):
					return true
				var c_controller := str(c.get("controller_player_id", ""))
				if not protectors.has(c_controller):
					return true
				return str(c.get("instance_id", "")) == protectors[c_controller]
			)
		# action_immune_conditional: creature immune to opponent actions when condition met
		targets = targets.filter(func(c):
			if not c.has("instance_id"):
				return true
			if str(c.get("controller_player_id", "")) == controller_id:
				return true  # Own creatures are always targetable
			if not EvergreenRules._has_passive(c, "action_immune_conditional"):
				return true
			var aic_passives = c.get("passive_abilities", [])
			if typeof(aic_passives) != TYPE_ARRAY:
				return true
			for p in aic_passives:
				if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "action_immune_conditional":
					continue
				var aic_cond := str(p.get("condition", ""))
				if aic_cond == "creature_in_each_lane":
					var aic_controller := str(c.get("controller_player_id", ""))
					var aic_has_in_each := true
					for aic_lane in match_state.get("lanes", []):
						var aic_slots: Array = aic_lane.get("player_slots", {}).get(aic_controller, [])
						if aic_slots.is_empty():
							aic_has_in_each = false
							break
					if aic_has_in_each:
						return false  # Condition met, immune
			return true
		)
		# action_immune status: opponent's actions cannot target this creature
		targets = targets.filter(func(c):
			if not c.has("instance_id"):
				return true
			if str(c.get("controller_player_id", "")) == controller_id:
				return true
			return not EvergreenRules.has_raw_status(c, "action_immune")
		)
	# enemy_dragon immunity: can't be targeted by enemy Dragons
	var source_subtypes = source_card.get("subtypes", [])
	if typeof(source_subtypes) == TYPE_ARRAY and source_subtypes.has("Dragon"):
		targets = targets.filter(func(c):
			if not c.has("instance_id"):
				return true
			if str(c.get("controller_player_id", "")) == controller_id:
				return true
			var ed_immunities = c.get("self_immunity", [])
			return not (typeof(ed_immunities) == TYPE_ARRAY and ed_immunities.has("enemy_dragon"))
		)
	# Convert to target info format
	var result: Array = []
	for t in targets:
		if t.has("player_id"):
			result.append({"player_id": str(t.get("player_id", ""))})
		elif t.has("instance_id"):
			result.append({"instance_id": str(t.get("instance_id", ""))})
	return result


static func get_all_valid_targets(match_state: Dictionary, source_instance_id: String) -> Array:
	var source_card := MatchTimingHelpers._find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return []
	var is_secondary := source_card.has("_primary_target_id")
	var all_targets: Array = []
	var seen_ids: Dictionary = {}
	for ability in get_target_mode_abilities(source_card):
		var mode := str(ability.get("secondary_target_mode", "")) if is_secondary else str(ability.get("target_mode", ""))
		if mode.is_empty():
			continue
		for target_info in get_valid_targets_for_mode(match_state, source_instance_id, mode, ability):
			var key := str(target_info.get("instance_id", target_info.get("player_id", "")))
			if not seen_ids.has(key):
				seen_ids[key] = true
				all_targets.append(target_info)
	return all_targets


static func _resolve_card_targets(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	var target := str(effect.get("target", "self"))
	# copies_in_hand_and_deck needs effect context, handled here instead of _resolve_card_targets_by_name
	if target == "copies_in_hand_and_deck":
		return MatchEffectParams._resolve_copies_in_hand_and_deck(match_state, trigger, effect)
	# For random_* targets with filters, resolve the full set first so filters apply before random pick
	var _rct_is_random := target.begins_with("random_") and _effect_has_target_filters(effect)
	var resolve_target := target
	if _rct_is_random:
		resolve_target = target.replace("random_", "all_")
	var targets := _resolve_card_targets_by_name(match_state, trigger, event, resolve_target)
	# friendly_by_name: filter by card name from the effect dict
	if target == "friendly_by_name":
		var fbn_name := str(effect.get("name", ""))
		if not fbn_name.is_empty():
			var fbn_filtered: Array = []
			for card in targets:
				if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == fbn_name:
					fbn_filtered.append(card)
			targets = fbn_filtered
	var filter_subtype := str(effect.get("target_filter_subtype", ""))
	var filter_subtypes_arr = effect.get("target_filter_subtypes", [])
	if not filter_subtype.is_empty():
		var fs_group: Array = ExtendedMechanicPacks.SUBTYPE_GROUPS.get(filter_subtype, [])
		var filtered: Array = []
		for card in targets:
			var subtypes: Array = card.get("subtypes", [])
			if typeof(subtypes) != TYPE_ARRAY:
				continue
			if not fs_group.is_empty():
				var fs_match := false
				for st in subtypes:
					if fs_group.has(st):
						fs_match = true
						break
				if fs_match:
					filtered.append(card)
			elif subtypes.has(filter_subtype):
				filtered.append(card)
		targets = filtered
	elif typeof(filter_subtypes_arr) == TYPE_ARRAY and not filter_subtypes_arr.is_empty():
		var expanded_subtypes: Array = []
		for fs in filter_subtypes_arr:
			var group: Array = ExtendedMechanicPacks.SUBTYPE_GROUPS.get(str(fs), [])
			if not group.is_empty():
				for g in group:
					if not expanded_subtypes.has(g):
						expanded_subtypes.append(g)
			else:
				if not expanded_subtypes.has(str(fs)):
					expanded_subtypes.append(str(fs))
		var filtered: Array = []
		for card in targets:
			var subtypes = card.get("subtypes", [])
			if typeof(subtypes) != TYPE_ARRAY:
				continue
			for es in expanded_subtypes:
				if subtypes.has(es):
					filtered.append(card)
					break
		targets = filtered
	var filter_keyword := str(effect.get("target_filter_keyword", effect.get("filter_keyword", "")))
	if not filter_keyword.is_empty():
		var filtered: Array = []
		for card in targets:
			if EvergreenRules.has_keyword(card, filter_keyword):
				filtered.append(card)
		targets = filtered
	var filter_attribute := str(effect.get("target_filter_attribute", ""))
	if not filter_attribute.is_empty():
		var filtered: Array = []
		for card in targets:
			var attrs: Array = card.get("attributes", [])
			if typeof(attrs) == TYPE_ARRAY and attrs.has(filter_attribute):
				filtered.append(card)
		targets = filtered
	var filter_definition_id := str(effect.get("target_filter_definition_id", ""))
	if not filter_definition_id.is_empty():
		var filtered: Array = []
		for card in targets:
			if str(card.get("definition_id", "")) == filter_definition_id:
				filtered.append(card)
		targets = filtered
	var filter_max_power := int(effect.get("target_filter_max_power", -1))
	if filter_max_power >= 0:
		var filtered: Array = []
		for card in targets:
			if EvergreenRules.get_power(card) <= filter_max_power:
				filtered.append(card)
		targets = filtered
	if bool(effect.get("target_filter_wounded", false)):
		var filtered: Array = []
		for card in targets:
			if EvergreenRules.has_status(card, EvergreenRules.STATUS_WOUNDED):
				filtered.append(card)
		targets = filtered
	# For random_* targets with filters: pick one random from the filtered set
	if _rct_is_random and targets.size() > 1:
		targets = [targets[randi() % targets.size()]]
	return targets


static func _effect_has_target_filters(effect: Dictionary) -> bool:
	return (not str(effect.get("target_filter_subtype", "")).is_empty()
		or not str(effect.get("target_filter_definition_id", "")).is_empty()
		or not str(effect.get("target_filter_keyword", effect.get("filter_keyword", ""))).is_empty()
		or not str(effect.get("target_filter_attribute", "")).is_empty()
		or int(effect.get("target_filter_max_power", -1)) >= 0
		or bool(effect.get("target_filter_wounded", false))
		or (typeof(effect.get("target_filter_subtypes", [])) == TYPE_ARRAY and not effect.get("target_filter_subtypes", []).is_empty()))


static func _resolve_card_targets_by_name(match_state: Dictionary, trigger: Dictionary, event: Dictionary, target: String) -> Array:
	var targets: Array = []
	match target:
		"self":
			var self_card := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not self_card.is_empty():
				targets.append(self_card)
		"assemble_targets":
			targets.append_array(ExtendedMechanicPacks._collect_factotums(match_state, str(trigger.get("controller_player_id", "")), str(trigger.get("source_instance_id", ""))))
		"assemble_targets_except_self":
			targets.append_array(ExtendedMechanicPacks._collect_factotums_except_self(match_state, str(trigger.get("controller_player_id", "")), str(trigger.get("source_instance_id", ""))))
		"host", "wielder":
			var host_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			var host_id := str(host_source.get("attached_to_instance_id", "")) if not host_source.is_empty() else ""
			if not host_id.is_empty():
				var host_card := MatchTimingHelpers._find_card_anywhere(match_state, host_id)
				if not host_card.is_empty():
					targets.append(host_card)
		"event_source":
			var source_card := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
			if not source_card.is_empty():
				targets.append(source_card)
		"event_summoned_creature":
			var summoned_card := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
			if not summoned_card.is_empty():
				targets.append(summoned_card)
		"event_target":
			var target_card := MatchTimingHelpers._find_card_anywhere(match_state, MatchTimingHelpers._event_target_instance_id(event))
			if not target_card.is_empty():
				targets.append(target_card)
		"event_subject", "event_drawn_card", "event_action":
			var subject_card := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("instance_id", event.get("drawn_instance_id", event.get("source_instance_id", "")))))
			if not subject_card.is_empty():
				targets.append(subject_card)
		"event_killer":
			var killer_card := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("destroyed_by_instance_id", "")))
			if not killer_card.is_empty():
				targets.append(killer_card)
		"event_damaged_creature", "damaged_creature":
			var dmc_id := MatchTimingHelpers._event_target_instance_id(event)
			if dmc_id.is_empty():
				dmc_id = str(event.get("instance_id", ""))
			if not dmc_id.is_empty():
				var dmc_card := MatchTimingHelpers._find_card_anywhere(match_state, dmc_id)
				if not dmc_card.is_empty():
					targets.append(dmc_card)
		"damage_source":
			var ds_id := str(event.get("source_instance_id", event.get("attacker_instance_id", "")))
			if not ds_id.is_empty():
				var ds_card := MatchTimingHelpers._find_card_anywhere(match_state, ds_id)
				if not ds_card.is_empty():
					targets.append(ds_card)
		"last_drawn_card":
			var ldc_id := str(event.get("drawn_instance_id", event.get("instance_id", "")))
			if not ldc_id.is_empty():
				var ldc_card := MatchTimingHelpers._find_card_anywhere(match_state, ldc_id)
				if not ldc_card.is_empty():
					targets.append(ldc_card)
		"last_summoned":
			var ls_id := str(event.get("source_instance_id", ""))
			if not ls_id.is_empty():
				var ls_card := MatchTimingHelpers._find_card_anywhere(match_state, ls_id)
				if not ls_card.is_empty():
					targets.append(ls_card)
		"last_stolen":
			var lst_id := str(event.get("target_instance_id", event.get("stolen_instance_id", "")))
			if lst_id.is_empty():
				var lst_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not lst_source.is_empty():
					lst_id = str(lst_source.get("_stolen_instance_id", ""))
			if not lst_id.is_empty():
				var lst_card := MatchTimingHelpers._find_card_anywhere(match_state, lst_id)
				if not lst_card.is_empty():
					targets.append(lst_card)
		"aimed_creature":
			var aim_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not aim_source.is_empty():
				var aim_target_id := str(aim_source.get("_aimed_at_instance_id", ""))
				if not aim_target_id.is_empty():
					var aim_card := MatchTimingHelpers._find_card_anywhere(match_state, aim_target_id)
					if not aim_card.is_empty():
						targets.append(aim_card)
		"moved_creatures":
			var mc_ids: Array = trigger.get("_moved_creature_ids", [])
			if not mc_ids.is_empty():
				for mc_id in mc_ids:
					var mc_card := MatchTimingHelpers._find_card_anywhere(match_state, str(mc_id))
					if not mc_card.is_empty():
						targets.append(mc_card)
			else:
				var mc_id := str(event.get("source_instance_id", event.get("moved_instance_id", "")))
				if not mc_id.is_empty():
					var mc_card := MatchTimingHelpers._find_card_anywhere(match_state, mc_id)
					if not mc_card.is_empty():
						targets.append(mc_card)
		"consuming_creature":
			var consumer_id := str(event.get("source_instance_id", ""))
			if not consumer_id.is_empty():
				var consumer_card := MatchTimingHelpers._find_card_anywhere(match_state, consumer_id)
				if not consumer_card.is_empty():
					targets.append(consumer_card)
		"copies_in_hand_and_deck":
			# Resolved in _resolve_card_targets where effect dict is available
			pass
		"all_enemies_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var controller_id := str(trigger.get("controller_player_id", ""))
			var opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), controller_id)
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"all_friendly_in_lane", "other_friendly_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var controller_id := str(trigger.get("controller_player_id", ""))
			var self_id := str(trigger.get("source_instance_id", ""))
			var exclude_self := target == "other_friendly_in_lane"
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(controller_id, [])
				for card in slots:
					if typeof(card) != TYPE_DICTIONARY:
						continue
					if exclude_self and str(card.get("instance_id", "")) == self_id:
						continue
					targets.append(card)
		"all_enemies", "all_other_enemies":
			var controller_id := str(trigger.get("controller_player_id", ""))
			var opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), controller_id)
			var ae_self_id := str(trigger.get("source_instance_id", "")) if target == "all_other_enemies" else ""
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						if not ae_self_id.is_empty() and str(card.get("instance_id", "")) == ae_self_id:
							continue
						targets.append(card)
		"all_friendly", "all_other_friendly", "all_friendly_creatures", "all_friendly_by_subtype", \
		"other_friendly_creatures", "other_friendly_by_subtype":
			var controller_id := str(trigger.get("controller_player_id", ""))
			var self_id := str(trigger.get("source_instance_id", ""))
			var exclude_self := target in ["all_other_friendly", "other_friendly_creatures", "other_friendly_by_subtype"]
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(controller_id, [])
				for card in slots:
					if typeof(card) != TYPE_DICTIONARY:
						continue
					if exclude_self and str(card.get("instance_id", "")) == self_id:
						continue
					targets.append(card)
		"all_creatures", "all_other_creatures":
			var self_id := str(trigger.get("source_instance_id", ""))
			var exclude_self := target == "all_other_creatures"
			for lane in match_state.get("lanes", []):
				var player_slots: Dictionary = lane.get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY:
							if exclude_self and str(card.get("instance_id", "")) == self_id:
								continue
							targets.append(card)
		"all_other_creatures_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var self_id := str(trigger.get("source_instance_id", ""))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != self_id:
							targets.append(card)
		"all_creatures_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY:
							targets.append(card)
		"chosen_target", "chosen_friendly_creature", "chosen_friendly", "chosen_enemy", \
		"chosen_friendly_optional", "chosen_targets", "chosen_target_pair":
			var chosen_id := str(trigger.get("_chosen_target_id", ""))
			if not chosen_id.is_empty():
				var chosen_card := MatchTimingHelpers._find_card_anywhere(match_state, chosen_id)
				if not chosen_card.is_empty():
					targets.append(chosen_card)
		"primary_target":
			var primary_id := str(trigger.get("_primary_target_id", ""))
			if not primary_id.is_empty():
				var primary_card := MatchTimingHelpers._find_card_anywhere(match_state, primary_id)
				if not primary_card.is_empty():
					targets.append(primary_card)
		"secondary_target":
			var sec_id := str(trigger.get("_chosen_target_id", ""))
			if not sec_id.is_empty():
				var sec_card := MatchTimingHelpers._find_card_anywhere(match_state, sec_id)
				if not sec_card.is_empty():
					targets.append(sec_card)
		"chosen_target_1", "chosen_target_2", "chosen_target_3":
			var ct_ids: Array = trigger.get("_chosen_target_ids", [])
			var ct_suffix := int(target.substr(target.length() - 1))
			var ct_idx := ct_suffix - 1
			if ct_idx >= 0 and ct_idx < ct_ids.size():
				var ct_card := MatchTimingHelpers._find_card_anywhere(match_state, str(ct_ids[ct_idx]))
				if not ct_card.is_empty():
					targets.append(ct_card)
		"secretly_chosen_target":
			var sct_source_id := str(trigger.get("source_instance_id", ""))
			var sct_source := MatchTimingHelpers._find_card_anywhere(match_state, sct_source_id)
			if not sct_source.is_empty():
				var sct_target_id := str(sct_source.get("_secretly_chosen_target_id", ""))
				if not sct_target_id.is_empty():
					var sct_target := MatchTimingHelpers._find_card_anywhere(match_state, sct_target_id)
					if not sct_target.is_empty():
						targets.append(sct_target)
		"random_enemy", "random_enemy_creature":
			var all_enemies := _resolve_card_targets_by_name(match_state, trigger, event, "all_enemies")
			if not all_enemies.is_empty():
				targets.append(all_enemies[randi() % all_enemies.size()])
		"random_friendly":
			var all_friendly := _resolve_card_targets_by_name(match_state, trigger, event, "all_friendly")
			if not all_friendly.is_empty():
				targets.append(all_friendly[randi() % all_friendly.size()])
		"random_other_friendly":
			var all_other_friendly := _resolve_card_targets_by_name(match_state, trigger, event, "all_other_friendly")
			if not all_other_friendly.is_empty():
				targets.append(all_other_friendly[randi() % all_other_friendly.size()])
		"random_enemy_in_lane":
			var all_enemies_lane := _resolve_card_targets_by_name(match_state, trigger, event, "all_enemies_in_lane")
			if not all_enemies_lane.is_empty():
				targets.append(all_enemies_lane[randi() % all_enemies_lane.size()])
		"random_friendly_in_lane":
			var all_friendly_lane := _resolve_card_targets_by_name(match_state, trigger, event, "all_friendly_in_lane")
			if not all_friendly_lane.is_empty():
				targets.append(all_friendly_lane[randi() % all_friendly_lane.size()])
		"random_creature":
			var all_creatures := _resolve_card_targets_by_name(match_state, trigger, event, "all_creatures")
			if not all_creatures.is_empty():
				targets.append(all_creatures[randi() % all_creatures.size()])
		"random_friendly_in_each_lane", "friendly_in_each_lane":
			var rfiel_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				var rfiel_slots = lane.get("player_slots", {}).get(rfiel_controller_id, [])
				var rfiel_candidates: Array = []
				for card in rfiel_slots:
					if typeof(card) == TYPE_DICTIONARY:
						rfiel_candidates.append(card)
				if not rfiel_candidates.is_empty():
					targets.append(rfiel_candidates[randi() % rfiel_candidates.size()])
		"random_enemy_in_each_lane":
			var reiel_controller_id := str(trigger.get("controller_player_id", ""))
			var reiel_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), reiel_controller_id)
			for lane in match_state.get("lanes", []):
				var reiel_slots = lane.get("player_slots", {}).get(reiel_opponent_id, [])
				var reiel_candidates: Array = []
				for card in reiel_slots:
					if typeof(card) == TYPE_DICTIONARY:
						reiel_candidates.append(card)
				if not reiel_candidates.is_empty():
					targets.append(reiel_candidates[randi() % reiel_candidates.size()])
		"random_creature_in_hand":
			var rcih_controller_id := str(trigger.get("controller_player_id", ""))
			var rcih_player := MatchTimingHelpers._get_player_state(match_state, rcih_controller_id)
			if not rcih_player.is_empty():
				var rcih_candidates: Array = []
				for card in rcih_player.get(ZONE_HAND, []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						rcih_candidates.append(card)
				if not rcih_candidates.is_empty():
					targets.append(rcih_candidates[randi() % rcih_candidates.size()])
		"all_friendly_in_event_lane", "all_creatures_in_event_lane", "all_enemies_in_event_lane":
			var event_lane_id := str(event.get("lane_id", ""))
			if not event_lane_id.is_empty():
				var controller_id := str(trigger.get("controller_player_id", ""))
				var friendly_only := target == "all_friendly_in_event_lane"
				var enemies_only := target == "all_enemies_in_event_lane"
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) != event_lane_id:
						continue
					var player_slots: Dictionary = lane.get("player_slots", {})
					for pid in player_slots.keys():
						if friendly_only and str(pid) != controller_id:
							continue
						if enemies_only and str(pid) == controller_id:
							continue
						for card in player_slots[pid]:
							if typeof(card) == TYPE_DICTIONARY:
								targets.append(card)
		"top_friendly_creature_in_deck":
			var tfcid_controller_id := str(trigger.get("controller_player_id", ""))
			var tfcid_player := MatchTimingHelpers._get_player_state(match_state, tfcid_controller_id)
			if not tfcid_player.is_empty():
				var tfcid_deck: Array = tfcid_player.get(ZONE_DECK, [])
				for i in range(tfcid_deck.size() - 1, -1, -1):
					var tfcid_card = tfcid_deck[i]
					if typeof(tfcid_card) == TYPE_DICTIONARY and str(tfcid_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						targets.append(tfcid_card)
						break
		"top_creatures_in_deck", "creatures_in_deck":
			var tcid_controller_id := str(trigger.get("controller_player_id", ""))
			var tcid_player := MatchTimingHelpers._get_player_state(match_state, tcid_controller_id)
			if not tcid_player.is_empty():
				var tcid_deck: Array = tcid_player.get(ZONE_DECK, [])
				for i in range(tcid_deck.size() - 1, -1, -1):
					var tcid_card = tcid_deck[i]
					if typeof(tcid_card) == TYPE_DICTIONARY and str(tcid_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						targets.append(tcid_card)
		"highest_cost_creature_in_opponent_hand":
			var hccioh_controller_id := str(trigger.get("controller_player_id", ""))
			var hccioh_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), hccioh_controller_id)
			var hccioh_player := MatchTimingHelpers._get_player_state(match_state, hccioh_opponent_id)
			if not hccioh_player.is_empty():
				var hccioh_best: Dictionary = {}
				var hccioh_best_cost := -1
				for card in hccioh_player.get(ZONE_HAND, []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						var card_cost := int(card.get("cost", 0))
						if card_cost > hccioh_best_cost:
							hccioh_best = card
							hccioh_best_cost = card_cost
				if not hccioh_best.is_empty():
					targets.append(hccioh_best)
		"all_enemies_with_less_power":
			var aewlp_controller_id := str(trigger.get("controller_player_id", ""))
			var aewlp_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), aewlp_controller_id)
			var aewlp_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			var aewlp_self_power := EvergreenRules.get_power(aewlp_source) if not aewlp_source.is_empty() else 0
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(aewlp_opponent_id, []):
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules.get_power(card) < aewlp_self_power:
						targets.append(card)
		"all_enemies_with_same_name":
			var aewsn_target_id := MatchTimingHelpers._event_target_instance_id(event)
			var aewsn_target := MatchTimingHelpers._find_card_anywhere(match_state, aewsn_target_id)
			var aewsn_def_id := str(aewsn_target.get("definition_id", "")) if not aewsn_target.is_empty() else ""
			if not aewsn_def_id.is_empty():
				var aewsn_controller_id := str(trigger.get("controller_player_id", ""))
				var aewsn_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), aewsn_controller_id)
				for lane in match_state.get("lanes", []):
					for card in lane.get("player_slots", {}).get(aewsn_opponent_id, []):
						if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == aewsn_def_id:
							if str(card.get("instance_id", "")) != aewsn_target_id:
								targets.append(card)
		"all_enemies_in_chosen_lane":
			var aeicl_controller_id := str(trigger.get("controller_player_id", ""))
			var aeicl_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), aeicl_controller_id)
			var aeicl_lane_id := str(trigger.get("_chosen_lane_id", event.get("lane_id", "")))
			for lane in match_state.get("lanes", []):
				if str(lane.get("lane_id", "")) == aeicl_lane_id:
					for card in lane.get("player_slots", {}).get(aeicl_opponent_id, []):
						if typeof(card) == TYPE_DICTIONARY:
							targets.append(card)
		"all_friendly_in_target_lane":
			var afitl_controller_id := str(trigger.get("controller_player_id", ""))
			var afitl_lane_id := str(event.get("lane_id", ""))
			if not afitl_lane_id.is_empty():
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) == afitl_lane_id:
						for card in lane.get("player_slots", {}).get(afitl_controller_id, []):
							if typeof(card) == TYPE_DICTIONARY:
								targets.append(card)
		"all_friendly_with_keyword":
			var afwk_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(afwk_controller_id, []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"all_friendly_animals":
			var afa_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(afa_controller_id, []):
					if typeof(card) == TYPE_DICTIONARY:
						var afa_subtypes = card.get("subtypes", [])
						if typeof(afa_subtypes) == TYPE_ARRAY and (afa_subtypes.has("Beast") or afa_subtypes.has("Animal")):
							targets.append(card)
		"all_friendly_oblivion_gates":
			var afog_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(afog_controller_id, []):
					if typeof(card) == TYPE_DICTIONARY:
						var afog_tags = card.get("rules_tags", [])
						if typeof(afog_tags) == TYPE_ARRAY and afog_tags.has("oblivion_gate"):
							targets.append(card)
		"crowned_creatures":
			for lane in match_state.get("lanes", []):
				var player_slots: Dictionary = lane.get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY and EvergreenRules.has_raw_status(card, "crowned"):
							targets.append(card)
		"damaged_enemy":
			var de_controller_id := str(trigger.get("controller_player_id", ""))
			var de_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), de_controller_id)
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(de_opponent_id, []):
					if typeof(card) == TYPE_DICTIONARY and int(card.get("damage_marked", 0)) > 0:
						targets.append(card)
		"treasure_card", "treasure_card_copy":
			var tc_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not tc_source.is_empty():
				var tc_id := str(tc_source.get("_treasure_card_instance_id", ""))
				if not tc_id.is_empty():
					var tc_card := MatchTimingHelpers._find_card_anywhere(match_state, tc_id)
					if not tc_card.is_empty():
						targets.append(tc_card)
		"friendly_by_name":
			var fbn_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(fbn_controller_id, []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"all_creatures_in_hand":
			var acih_controller_id := str(trigger.get("controller_player_id", ""))
			var acih_player := MatchTimingHelpers._get_player_state(match_state, acih_controller_id)
			if not acih_player.is_empty():
				for card in acih_player.get(ZONE_HAND, []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature":
						targets.append(card)
		"all":
			for lane in match_state.get("lanes", []):
				var player_slots: Dictionary = lane.get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY:
							targets.append(card)
	return targets


static func _resolve_player_targets(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	var target_player := str(effect.get("target_player", "controller"))
	match target_player:
		"controller":
			return [str(trigger.get("controller_player_id", ""))]
		"opponent":
			var opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), str(trigger.get("controller_player_id", "")))
			return [] if opponent_id.is_empty() else [opponent_id]
		"event_player":
			var player_id := str(event.get("player_id", event.get("playing_player_id", event.get("target_player_id", ""))))
			return [] if player_id.is_empty() else [player_id]
		"target_player":
			var event_target_player := str(event.get("target_player_id", ""))
			return [] if event_target_player.is_empty() else [event_target_player]
		"chosen_target_player":
			var chosen_pid := str(trigger.get("_chosen_target_player_id", ""))
			return [] if chosen_pid.is_empty() else [chosen_pid]
	return []

