class_name ExtendedMechanicPacks
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")

const EVENT_CARD_PLAYED := "card_played"
const EVENT_DAMAGE_RESOLVED := "damage_resolved"
const EVENT_CARD_DRAWN := "card_drawn"
const EVENT_CREATURE_SUMMONED := "creature_summoned"
const EVENT_TREASURE_HUNT_COMPLETED := "treasure_hunt_completed"

const CARD_TYPE_ACTION := "action"
const ZONE_HAND := "hand"
const ZONE_DECK := "deck"
const ZONE_DISCARD := "discard"
const ZONE_LANE := "lane"
const SHADOW_LANE_ID := "shadow"

const SUBTYPE_GROUPS := {
	"Animal": ["Beast", "Fish", "Mammoth", "Mudcrab", "Netch", "Reptile", "Spider", "Skeever", "Wolf"],
}

const WAX := "wax"
const WANE := "wane"
const RULE_TAG_OBLIVION_GATE := "oblivion_gate"
const GATE_KEYWORD_POOL := [
	EvergreenRules.KEYWORD_BREAKTHROUGH,
	EvergreenRules.KEYWORD_CHARGE,
	EvergreenRules.KEYWORD_DRAIN,
	EvergreenRules.KEYWORD_GUARD,
	EvergreenRules.KEYWORD_LETHAL,
	EvergreenRules.KEYWORD_WARD,
]


static func ensure_match_state(match_state: Dictionary) -> void:
	for player in match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY:
			ensure_player_state(player)


static func ensure_player_state(player: Dictionary) -> void:
	if not player.has("cards_played_this_turn"):
		player["cards_played_this_turn"] = 0
	if not player.has("noncreature_plays_this_turn"):
		player["noncreature_plays_this_turn"] = 0
	if not player.has("damage_dealt_to_opponent_this_turn"):
		player["damage_dealt_to_opponent_this_turn"] = 0
	if not player.has("wax_wane_state"):
		player["wax_wane_state"] = WAX


static func reset_turn_state(player: Dictionary) -> void:
	ensure_player_state(player)
	player["cards_played_this_turn"] = 0
	player["noncreature_plays_this_turn"] = 0
	player["damage_dealt_to_opponent_this_turn"] = 0


static func toggle_wax_wane(player: Dictionary) -> void:
	ensure_player_state(player)
	player["wax_wane_state"] = WANE if str(player.get("wax_wane_state", WAX)) == WAX else WAX


static func observe_event(match_state: Dictionary, event: Dictionary) -> void:
	var event_type := str(event.get("event_type", ""))
	if event_type == EVENT_CARD_PLAYED:
		var player := _get_player_state(match_state, str(event.get("playing_player_id", event.get("player_id", ""))))
		if player.is_empty():
			return
		ensure_player_state(player)
		player["cards_played_this_turn"] = int(player.get("cards_played_this_turn", 0)) + 1
		if str(event.get("card_type", "")) != "creature":
			player["noncreature_plays_this_turn"] = int(player.get("noncreature_plays_this_turn", 0)) + 1
		return
	if event_type == EVENT_DAMAGE_RESOLVED and str(event.get("target_type", "")) == "player":
		var source_player := _get_player_state(match_state, str(event.get("source_controller_player_id", "")))
		var target_player_id := str(event.get("target_player_id", ""))
		if source_player.is_empty() or target_player_id.is_empty() or str(source_player.get("player_id", "")) == target_player_id:
			return
		ensure_player_state(source_player)
		source_player["damage_dealt_to_opponent_this_turn"] = int(source_player.get("damage_dealt_to_opponent_this_turn", 0)) + int(event.get("amount", 0))


static func apply_pre_play_options(card: Dictionary, options: Dictionary) -> void:
	if bool(options.get("exalt", false)):
		EvergreenRules.add_status(card, EvergreenRules.STATUS_EXALTED)
	if options.has("assemble_choice"):
		card["assemble_choice_index"] = int(options.get("assemble_choice", 0))
	if options.has("double_card_choice"):
		_apply_double_card_choice(card, options.get("double_card_choice", 0))


static func matches_additional_conditions(match_state: Dictionary, trigger: Dictionary, descriptor: Dictionary, event: Dictionary) -> bool:
	var controller := _get_player_state(match_state, str(trigger.get("controller_player_id", "")))
	if not controller.is_empty():
		ensure_player_state(controller)
		if int(descriptor.get("min_cards_played_this_turn", 0)) > int(controller.get("cards_played_this_turn", 0)):
			return false
		if int(descriptor.get("min_noncreature_plays_this_turn", 0)) > int(controller.get("noncreature_plays_this_turn", 0)):
			return false
		var required_phase := str(descriptor.get("required_wax_wane_phase", ""))
		if not required_phase.is_empty() and required_phase != str(controller.get("wax_wane_state", WAX)):
			return false
	if bool(descriptor.get("require_attacker_survived", false)) and bool(event.get("attacker_destroyed", false)):
		return false
	var required_top_deck_attr := str(descriptor.get("required_top_deck_attribute", ""))
	if not required_top_deck_attr.is_empty():
		var deck: Array = controller.get("deck", [])
		if deck.is_empty():
			return false
		var top_card = deck.back()
		if typeof(top_card) != TYPE_DICTIONARY:
			return false
		var top_attrs = top_card.get("attributes", [])
		if typeof(top_attrs) != TYPE_ARRAY or not top_attrs.has(required_top_deck_attr):
			return false
	var source_card := _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
	var required_subtype := str(descriptor.get("required_event_source_subtype", ""))
	if not required_subtype.is_empty() and not _card_has_string(source_card, "subtypes", required_subtype):
		return false
	var required_attribute := str(descriptor.get("required_event_source_attribute", ""))
	if not required_attribute.is_empty() and not _card_has_string(source_card, "attributes", required_attribute):
		return false
	var excluded_rule_tag := str(descriptor.get("excluded_event_source_rule_tag", ""))
	if not excluded_rule_tag.is_empty() and _card_has_string(source_card, "rules_tags", excluded_rule_tag):
		return false
	# Health comparison conditions
	if descriptor.has("required_more_health"):
		var opponent := _get_opponent(match_state, str(trigger.get("controller_player_id", "")))
		if controller.is_empty() or opponent.is_empty():
			return false
		if int(controller.get("health", 0)) <= int(opponent.get("health", 0)):
			return false
	if descriptor.has("required_less_health"):
		var opponent := _get_opponent(match_state, str(trigger.get("controller_player_id", "")))
		if controller.is_empty() or opponent.is_empty():
			return false
		if int(controller.get("health", 0)) >= int(opponent.get("health", 0)):
			return false
	if descriptor.has("required_not_less_health"):
		var opponent := _get_opponent(match_state, str(trigger.get("controller_player_id", "")))
		if controller.is_empty() or opponent.is_empty():
			return false
		if int(controller.get("health", 0)) < int(opponent.get("health", 0)):
			return false
	# Subtype on board condition (e.g., "if you have another Orc")
	var required_board_subtype := str(descriptor.get("required_subtype_on_board", ""))
	if not required_board_subtype.is_empty():
		var trigger_source_id := str(trigger.get("source_instance_id", ""))
		if not _has_friendly_with_subtype(match_state, str(trigger.get("controller_player_id", "")), required_board_subtype, trigger_source_id):
			return false
	# Keyword on board condition (e.g., "if you have another creature with Lethal")
	var required_board_keyword := str(descriptor.get("required_keyword_on_board", ""))
	if not required_board_keyword.is_empty():
		var trigger_source_id := str(trigger.get("source_instance_id", ""))
		if not _has_other_friendly_with_keyword(match_state, str(trigger.get("controller_player_id", "")), required_board_keyword, trigger_source_id):
			return false
	# Wounded enemy in lane condition
	if bool(descriptor.get("required_wounded_enemy_in_lane", false)):
		if not _has_wounded_enemy_in_lane(match_state, trigger):
			return false
	# Enemy in lane condition
	if bool(descriptor.get("required_enemy_in_lane", false)):
		if not _has_enemy_in_lane(match_state, trigger):
			return false
	# Required top deck card type condition (e.g., "action")
	var required_top_deck_type := str(descriptor.get("required_top_deck_card_type", ""))
	if not required_top_deck_type.is_empty():
		var deck: Array = controller.get("deck", [])
		if deck.is_empty():
			return false
		var top_card = deck.back()
		if typeof(top_card) != TYPE_DICTIONARY or str(top_card.get("card_type", "")) != required_top_deck_type:
			return false
	# Required opponent has more cards in hand condition
	if bool(descriptor.get("required_opponent_more_cards", false)):
		var opponent := _get_opponent(match_state, str(trigger.get("controller_player_id", "")))
		if controller.is_empty() or opponent.is_empty():
			return false
		var my_hand: Array = controller.get("hand", [])
		var opp_hand: Array = opponent.get("hand", [])
		if opp_hand.size() <= my_hand.size():
			return false
	# Required card type in hand condition
	var required_hand_card_type := str(descriptor.get("required_card_type_in_hand", ""))
	if not required_hand_card_type.is_empty():
		var hand: Array = controller.get("hand", [])
		var found := false
		for card in hand:
			if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == required_hand_card_type:
				found = true
				break
		if not found:
			return false
	# Creature died this turn condition
	if bool(descriptor.get("creature_died_this_turn", false)):
		var found_death := false
		var event_log: Array = match_state.get("event_log", [])
		for i in range(event_log.size() - 1, -1, -1):
			var logged = event_log[i]
			if typeof(logged) != TYPE_DICTIONARY:
				continue
			if str(logged.get("event_type", "")) == "turn_started":
				break
			if str(logged.get("event_type", "")) == "creature_destroyed":
				found_death = true
				break
		if not found_death:
			return false
	# Require controller has a creature with higher power than chosen target
	if bool(descriptor.get("required_friendly_higher_power", false)):
		var chosen_id := str(trigger.get("_chosen_target_id", ""))
		if not chosen_id.is_empty():
			var target_card := _find_card_anywhere(match_state, chosen_id)
			if not target_card.is_empty():
				var target_power := EvergreenRules.get_power(target_card)
				var has_higher := false
				for lane in match_state.get("lanes", []):
					for card in lane.get("player_slots", {}).get(str(trigger.get("controller_player_id", "")), []):
						if typeof(card) == TYPE_DICTIONARY and EvergreenRules.get_power(card) > target_power:
							has_higher = true
							break
					if has_higher:
						break
				if not has_higher:
					return false
	# Require controller took no player damage this turn
	if bool(descriptor.get("require_no_player_damage_this_turn", false)):
		var controller_id := str(trigger.get("controller_player_id", ""))
		var took_damage := false
		var elog: Array = match_state.get("event_log", [])
		for i in range(elog.size() - 1, -1, -1):
			var logged = elog[i]
			if typeof(logged) != TYPE_DICTIONARY:
				continue
			if str(logged.get("event_type", "")) == "turn_started":
				break
			if str(logged.get("event_type", "")) == "damage_resolved" and str(logged.get("target_type", "")) == "player" and str(logged.get("target_player_id", "")) == controller_id:
				took_damage = true
				break
		if took_damage:
			return false
	# Max magicka threshold conditions
	var req_magicka_gte := int(descriptor.get("required_max_magicka_gte", 0))
	if req_magicka_gte > 0 and int(controller.get("max_magicka", 0)) < req_magicka_gte:
		return false
	var req_magicka_lt := int(descriptor.get("required_max_magicka_lt", 0))
	if req_magicka_lt > 0 and int(controller.get("max_magicka", 0)) >= req_magicka_lt:
		return false
	# Minimum destroyed enemy runes condition
	var min_runes := int(descriptor.get("min_destroyed_enemy_runes", 0))
	if min_runes > 0:
		var opponent := _get_opponent(match_state, str(trigger.get("controller_player_id", "")))
		var remaining_thresholds: Variant = opponent.get("rune_thresholds", [])
		var remaining_count: int = remaining_thresholds.size() if typeof(remaining_thresholds) == TYPE_ARRAY else 0
		var destroyed_runes: int = 5 - remaining_count
		if destroyed_runes < min_runes:
			return false
	return true


static func effect_is_enabled(match_state: Dictionary, trigger: Dictionary, effect: Dictionary) -> bool:
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	var required_status := str(effect.get("required_source_status", ""))
	if not required_status.is_empty() and (source_card.is_empty() or not EvergreenRules.has_status(source_card, required_status)):
		return false
	var required_phase := str(effect.get("required_wax_wane_phase", ""))
	if not required_phase.is_empty():
		var controller := _get_player_state(match_state, str(trigger.get("controller_player_id", "")))
		ensure_player_state(controller)
		if required_phase != str(controller.get("wax_wane_state", WAX)):
			return false
	var min_friendly_attr: Dictionary = effect.get("required_min_friendly_with_attribute", {})
	if not min_friendly_attr.is_empty():
		var req_attr := str(min_friendly_attr.get("attribute", ""))
		var min_count := int(min_friendly_attr.get("count", 0))
		var controller_id := str(trigger.get("controller_player_id", ""))
		var attr_count := 0
		for lane in match_state.get("lanes", []):
			for card in lane.get("player_slots", {}).get(controller_id, []):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var attrs = card.get("attributes", [])
				if typeof(attrs) == TYPE_ARRAY and attrs.has(req_attr):
					attr_count += 1
		if attr_count < min_count:
			return false
	if bool(effect.get("require_source_uses_exhausted", false)):
		if source_card.is_empty():
			return false
		var remaining = source_card.get("remaining_support_uses", null)
		if remaining == null or int(remaining) > 0:
			return false
	if bool(effect.get("unless_min_friendly_with_attribute", false)):
		var unless_data: Dictionary = effect.get("unless_min_friendly_with_attribute_data", {})
		var unless_attr := str(unless_data.get("attribute", ""))
		var unless_count := int(unless_data.get("count", 0))
		var unless_controller_id := str(trigger.get("controller_player_id", ""))
		var unless_attr_count := 0
		for lane in match_state.get("lanes", []):
			for card in lane.get("player_slots", {}).get(unless_controller_id, []):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var attrs = card.get("attributes", [])
				if typeof(attrs) == TYPE_ARRAY and attrs.has(unless_attr):
					unless_attr_count += 1
		if unless_attr_count >= unless_count:
			return false
	return true


static func apply_custom_effect(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	match str(effect.get("op", "")):
		"assemble":
			return {"handled": true, "events": _resolve_assemble(match_state, trigger, effect)}
		"upgrade_shout":
			return {"handled": true, "events": _resolve_shout_upgrade(match_state, trigger)}
		"invade":
			return {"handled": true, "events": _resolve_invade(match_state, trigger)}
		"buff_oblivion_gate_summon":
			return {"handled": true, "events": _resolve_gate_buff(match_state, trigger, event)}
		"track_treasure_hunt":
			return {"handled": true, "events": _resolve_treasure_hunt(match_state, trigger, event, effect)}
		"damage":
			return {"handled": true, "events": _resolve_player_damage(match_state, trigger, event, effect, int(effect.get("amount", 0)))}
		"empower_damage":
			var controller := _get_player_state(match_state, str(trigger.get("controller_player_id", "")))
			ensure_player_state(controller)
			var empower_amount := int(effect.get("amount", 0)) + int(effect.get("amount_per_damage", 0)) * int(controller.get("damage_dealt_to_opponent_this_turn", 0))
			return {"handled": true, "events": _resolve_player_damage(match_state, trigger, event, effect, empower_amount)}
		"gain_magicka":
			var gm_player := _get_player_state(match_state, str(trigger.get("controller_player_id", "")))
			if gm_player.is_empty():
				return {"handled": true, "events": []}
			var gm_amount := int(effect.get("amount", 0))
			gm_player["temporary_magicka"] = int(gm_player.get("temporary_magicka", 0)) + gm_amount
			return {"handled": true, "events": [{
				"event_type": "magicka_gained",
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"player_id": str(trigger.get("controller_player_id", "")),
				"amount": gm_amount,
			}]}
		"summon_random_from_catalog":
			var srfc_filter_raw = effect.get("filter", {})
			var srfc_filter: Dictionary = srfc_filter_raw if typeof(srfc_filter_raw) == TYPE_DICTIONARY else {}
			var srfc_seeds: Array = CardCatalog._card_seeds()
			var srfc_candidates: Array = []
			var srfc_controller_id := str(trigger.get("controller_player_id", ""))
			var srfc_player := _get_player_state(match_state, srfc_controller_id)
			var srfc_max_cost := int(srfc_filter.get("max_cost", -1))
			if str(srfc_filter.get("max_cost_source", "")) == "controller_max_magicka" and not srfc_player.is_empty():
				srfc_max_cost = int(srfc_player.get("max_magicka", 12))
			var srfc_req_card_type := str(srfc_filter.get("card_type", ""))
			var srfc_req_subtype := str(srfc_filter.get("required_subtype", ""))
			for seed in srfc_seeds:
				if typeof(seed) != TYPE_DICTIONARY:
					continue
				if not bool(seed.get("collectible", true)):
					continue
				if not srfc_req_card_type.is_empty() and str(seed.get("card_type", "")) != srfc_req_card_type:
					continue
				if srfc_max_cost >= 0 and int(seed.get("cost", 0)) > srfc_max_cost:
					continue
				if not srfc_req_subtype.is_empty():
					var subtypes = seed.get("subtypes", [])
					if typeof(subtypes) != TYPE_ARRAY:
						continue
					var srfc_group: Array = SUBTYPE_GROUPS.get(srfc_req_subtype, [])
					if not srfc_group.is_empty():
						var srfc_match := false
						for st in subtypes:
							if srfc_group.has(st):
								srfc_match = true
								break
						if not srfc_match:
							continue
					elif not subtypes.has(srfc_req_subtype):
						continue
				srfc_candidates.append(seed)
			if srfc_candidates.is_empty():
				return {"handled": true, "events": []}
			var srfc_pick: Dictionary = srfc_candidates[_timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_srfc", srfc_candidates.size())]
			var srfc_template: Dictionary = srfc_pick.duplicate(true)
			srfc_template["definition_id"] = str(srfc_template.get("card_id", ""))
			var srfc_lane_id := ""
			var srfc_lane_index := int(trigger.get("lane_index", -1))
			var srfc_lanes: Array = match_state.get("lanes", [])
			if srfc_lane_index >= 0 and srfc_lane_index < srfc_lanes.size():
				srfc_lane_id = str(srfc_lanes[srfc_lane_index].get("lane_id", ""))
			if srfc_lane_id.is_empty() and not srfc_lanes.is_empty():
				srfc_lane_id = str(srfc_lanes[0].get("lane_id", ""))
			if srfc_lane_id.is_empty():
				return {"handled": true, "events": []}
			var srfc_gen := MatchMutations.build_generated_card(match_state, srfc_controller_id, srfc_template)
			var srfc_result := MatchMutations.summon_card_to_lane(match_state, srfc_controller_id, srfc_gen, srfc_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
			if not bool(srfc_result.get("is_valid", false)):
				return {"handled": true, "events": []}
			var srfc_events: Array = srfc_result.get("events", []).duplicate()
			srfc_events.append(_timing_rules()._build_summon_event(srfc_result["card"], srfc_controller_id, srfc_lane_id, int(srfc_result.get("slot_index", -1)), "summon_from_catalog"))
			return {"handled": true, "events": srfc_events}
		"generate_random_to_hand":
			var grth_filter_raw = effect.get("filter", {})
			var grth_filter: Dictionary = grth_filter_raw if typeof(grth_filter_raw) == TYPE_DICTIONARY else {}
			var grth_seeds: Array = CardCatalog._card_seeds()
			var grth_candidates: Array = []
			var grth_controller_id := str(trigger.get("controller_player_id", ""))
			var grth_player := _get_player_state(match_state, grth_controller_id)
			if grth_player.is_empty():
				return {"handled": true, "events": []}
			var grth_max_cost := int(grth_filter.get("max_cost", -1))
			var grth_req_card_type := str(grth_filter.get("card_type", ""))
			var grth_req_subtype := str(grth_filter.get("required_subtype", ""))
			var grth_req_rules_tag := str(grth_filter.get("rules_tag", ""))
			for seed in grth_seeds:
				if typeof(seed) != TYPE_DICTIONARY:
					continue
				if not bool(seed.get("collectible", true)):
					continue
				if not grth_req_card_type.is_empty() and str(seed.get("card_type", "")) != grth_req_card_type:
					continue
				if grth_max_cost >= 0 and int(seed.get("cost", 0)) > grth_max_cost:
					continue
				if not grth_req_subtype.is_empty():
					var subtypes = seed.get("subtypes", [])
					if typeof(subtypes) != TYPE_ARRAY:
						continue
					var grth_group: Array = SUBTYPE_GROUPS.get(grth_req_subtype, [])
					if not grth_group.is_empty():
						var grth_match := false
						for st in subtypes:
							if grth_group.has(st):
								grth_match = true
								break
						if not grth_match:
							continue
					elif not subtypes.has(grth_req_subtype):
						continue
				if not grth_req_rules_tag.is_empty():
					var grth_tags = seed.get("rules_tags", [])
					if typeof(grth_tags) != TYPE_ARRAY or not grth_tags.has(grth_req_rules_tag):
						continue
				grth_candidates.append(seed)
			if grth_candidates.is_empty():
				return {"handled": true, "events": []}
			var grth_seq := str(match_state.get("generated_card_sequence", 0))
			var grth_pick: Dictionary = grth_candidates[_timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_grth_" + grth_seq, grth_candidates.size())]
			var grth_template: Dictionary = grth_pick.duplicate(true)
			grth_template["definition_id"] = str(grth_template.get("card_id", ""))
			var grth_gen := MatchMutations.build_generated_card(match_state, grth_controller_id, grth_template)
			grth_gen["zone"] = MatchMutations.ZONE_HAND
			var grth_hand: Array = grth_player.get(MatchMutations.ZONE_HAND, [])
			grth_hand.append(grth_gen)
			return {"handled": true, "events": [{"event_type": "card_drawn", "player_id": grth_controller_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "drawn_instance_id": str(grth_gen.get("instance_id", "")), "source_zone": MatchMutations.ZONE_GENERATED, "target_zone": MatchMutations.ZONE_HAND, "reason": "generate_random_to_hand"}]}
		"equip_random_item_from_catalog":
			var erfc_seeds: Array = CardCatalog._card_seeds()
			var erfc_items: Array = []
			for seed in erfc_seeds:
				if typeof(seed) != TYPE_DICTIONARY:
					continue
				if not bool(seed.get("collectible", true)):
					continue
				if str(seed.get("card_type", "")) != "item":
					continue
				erfc_items.append(seed)
			if erfc_items.is_empty():
				return {"handled": true, "events": []}
			var erfc_controller_id := str(trigger.get("controller_player_id", ""))
			var erfc_targets: Array = _timing_rules()._resolve_card_targets(match_state, trigger, event, effect)
			var erfc_events: Array = []
			for erfc_card in erfc_targets:
				if str(erfc_card.get("card_type", "")) != "creature":
					continue
				var erfc_pick: Dictionary = erfc_items[_timing_rules()._deterministic_index(match_state, str(erfc_card.get("instance_id", "")) + "_erfc", erfc_items.size())]
				var erfc_template: Dictionary = erfc_pick.duplicate(true)
				erfc_template["definition_id"] = str(erfc_template.get("card_id", ""))
				var erfc_gen := MatchMutations.build_generated_card(match_state, erfc_controller_id, erfc_template)
				var erfc_result := MatchMutations.attach_item_to_creature(match_state, erfc_controller_id, erfc_gen, str(erfc_card.get("instance_id", "")), {"source_zone": MatchMutations.ZONE_GENERATED})
				if bool(erfc_result.get("is_valid", false)):
					erfc_events.append_array(erfc_result.get("events", []))
			return {"handled": true, "events": erfc_events}
		"reduce_random_hand_card_cost":
			var rrhcc_controller_id := str(trigger.get("controller_player_id", ""))
			var rrhcc_player: Dictionary = _get_player_state(match_state, rrhcc_controller_id)
			if rrhcc_player.is_empty():
				return {"handled": true, "events": []}
			var rrhcc_amount := int(effect.get("amount", 1))
			var rrhcc_filter: Dictionary = effect.get("filter", {})
			var rrhcc_subtype := str(rrhcc_filter.get("subtype", ""))
			var rrhcc_candidates: Array = []
			for rrhcc_card in rrhcc_player.get(MatchMutations.ZONE_HAND, []):
				if typeof(rrhcc_card) != TYPE_DICTIONARY:
					continue
				if not rrhcc_subtype.is_empty():
					var rrhcc_subtypes: Array = rrhcc_card.get("subtypes", [])
					if typeof(rrhcc_subtypes) != TYPE_ARRAY or not rrhcc_subtypes.has(rrhcc_subtype):
						continue
				rrhcc_candidates.append(rrhcc_card)
			if rrhcc_candidates.is_empty():
				return {"handled": true, "events": []}
			var rrhcc_chosen: Dictionary = rrhcc_candidates[randi() % rrhcc_candidates.size()]
			rrhcc_chosen["cost"] = maxi(0, int(rrhcc_chosen.get("cost", 0)) - rrhcc_amount)
			return {"handled": true, "events": [{"event_type": "card_cost_modified", "player_id": rrhcc_controller_id, "target_instance_id": str(rrhcc_chosen.get("instance_id", "")), "amount": -rrhcc_amount, "source_instance_id": str(trigger.get("source_instance_id", ""))}]}
		"conditional_equip_bonus":
			var ceb_controller_id := str(trigger.get("controller_player_id", ""))
			var ceb_player: Dictionary = _get_player_state(match_state, ceb_controller_id)
			if ceb_player.is_empty():
				return {"handled": true, "events": []}
			var ceb_condition := str(effect.get("condition", ""))
			var ceb_met := false
			if ceb_condition == "dragon_in_discard":
				for ceb_card in ceb_player.get(MatchMutations.ZONE_DISCARD, []):
					if typeof(ceb_card) == TYPE_DICTIONARY:
						var ceb_subtypes = ceb_card.get("subtypes", [])
						if typeof(ceb_subtypes) == TYPE_ARRAY and ceb_subtypes.has("Dragon"):
							ceb_met = true
							break
			if not ceb_met:
				return {"handled": true, "events": []}
			var ceb_host := _find_card_anywhere(match_state, str(event.get("target_instance_id", "")))
			if ceb_host.is_empty():
				return {"handled": true, "events": []}
			var ceb_bp := int(effect.get("bonus_power", 0))
			var ceb_bh := int(effect.get("bonus_health", 0))
			EvergreenRules.apply_stat_bonus(ceb_host, ceb_bp, ceb_bh, "conditional_equip")
			return {"handled": true, "events": [{"event_type": "creature_stats_changed", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(ceb_host.get("instance_id", "")), "bonus_power": ceb_bp, "bonus_health": ceb_bh}]}
		"grant_player_ward":
			var gpw_controller_id := str(trigger.get("controller_player_id", ""))
			var gpw_player: Dictionary = _get_player_state(match_state, gpw_controller_id)
			if gpw_player.is_empty():
				return {"handled": true, "events": []}
			gpw_player["has_ward"] = true
			return {"handled": true, "events": [{"event_type": "player_ward_granted", "player_id": gpw_controller_id, "source_instance_id": str(trigger.get("source_instance_id", ""))}]}
		"reduce_next_card_cost":
			var rncc_controller_id := str(trigger.get("controller_player_id", ""))
			var rncc_player: Dictionary = _get_player_state(match_state, rncc_controller_id)
			if rncc_player.is_empty():
				return {"handled": true, "events": []}
			var rncc_amount := int(effect.get("amount", 0))
			rncc_player["next_card_cost_reduction"] = int(rncc_player.get("next_card_cost_reduction", 0)) + rncc_amount
			return {"handled": true, "events": [{"event_type": "cost_reduction_applied", "player_id": rncc_controller_id, "amount": rncc_amount, "source_instance_id": str(trigger.get("source_instance_id", ""))}]}
		"escalating_damage":
			var esc_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if esc_source.is_empty():
				return {"handled": true, "events": []}
			var counter_key := str(effect.get("counter_key", "escalating_counter"))
			var base_amount := int(effect.get("base_amount", 0))
			var current_counter := int(esc_source.get(counter_key, 0))
			var total_amount := base_amount + current_counter
			var increment := int(effect.get("increment", base_amount))
			esc_source[counter_key] = current_counter + increment
			if effect.has("target_player"):
				return {"handled": true, "events": _resolve_player_damage(match_state, trigger, event, effect, total_amount)}
			else:
				var esc_events: Array = []
				var esc_target_name := str(effect.get("target", "event_target"))
				var esc_targets: Array = _timing_rules()._resolve_card_targets_by_name(match_state, trigger, event, esc_target_name)
				var esc_source_id := str(trigger.get("source_instance_id", ""))
				for esc_card in esc_targets:
					if total_amount <= 0:
						continue
					var dmg_result := EvergreenRules.apply_damage_to_creature(esc_card, total_amount)
					var applied := int(dmg_result.get("applied", 0))
					esc_events.append({"event_type": EVENT_DAMAGE_RESOLVED, "source_instance_id": esc_source_id, "target_instance_id": str(esc_card.get("instance_id", "")), "target_type": "creature", "amount": applied, "reason": "escalating_damage"})
					if EvergreenRules.is_creature_destroyed(esc_card, false):
						var loc := MatchMutations.find_card_location(match_state, str(esc_card.get("instance_id", "")))
						if bool(loc.get("is_valid", false)):
							var cpid := str(esc_card.get("controller_player_id", ""))
							var moved := MatchMutations.discard_card(match_state, str(esc_card.get("instance_id", "")))
							if bool(moved.get("is_valid", false)):
								esc_events.append({"event_type": "creature_destroyed", "instance_id": str(esc_card.get("instance_id", "")), "source_instance_id": str(esc_card.get("instance_id", "")), "owner_player_id": str(esc_card.get("owner_player_id", "")), "controller_player_id": cpid, "destroyed_by_instance_id": esc_source_id, "lane_id": str(loc.get("lane_id", "")), "source_zone": "lane"})
				return {"handled": true, "events": esc_events}
		"summon_random_from_deck":
			var srfd_controller_id := str(trigger.get("controller_player_id", ""))
			var srfd_player := _get_player_state(match_state, srfd_controller_id)
			if srfd_player.is_empty():
				return {"handled": true, "events": []}
			var srfd_deck: Array = srfd_player.get("deck", [])
			var srfd_candidates: Array = []
			var srfd_filter_raw = effect.get("filter", {})
			var srfd_filter: Dictionary = srfd_filter_raw if typeof(srfd_filter_raw) == TYPE_DICTIONARY else {}
			var srfd_req_card_type := str(srfd_filter.get("card_type", ""))
			for i in range(srfd_deck.size()):
				var card = srfd_deck[i]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not srfd_req_card_type.is_empty() and str(card.get("card_type", "")) != srfd_req_card_type:
					continue
				srfd_candidates.append({"index": i, "card": card})
			if srfd_candidates.is_empty():
				return {"handled": true, "events": []}
			var srfd_pick_idx: int = _timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_srfd", srfd_candidates.size())
			var srfd_picked: Dictionary = srfd_candidates[srfd_pick_idx]
			var srfd_card: Dictionary = srfd_picked["card"]
			srfd_deck.erase(srfd_card)
			var srfd_lanes: Array = match_state.get("lanes", [])
			if srfd_lanes.is_empty():
				return {"handled": true, "events": []}
			var srfd_lane_idx: int = _timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_srfd_lane", srfd_lanes.size())
			var srfd_lane_id := str(srfd_lanes[srfd_lane_idx].get("lane_id", ""))
			srfd_card["controller_player_id"] = srfd_controller_id
			srfd_card["owner_player_id"] = srfd_controller_id
			var srfd_result := MatchMutations.summon_card_to_lane(match_state, srfd_controller_id, srfd_card, srfd_lane_id, {"source_zone": "deck"})
			if not bool(srfd_result.get("is_valid", false)):
				return {"handled": true, "events": []}
			var srfd_events: Array = srfd_result.get("events", []).duplicate()
			srfd_events.append(_timing_rules()._build_summon_event(srfd_result["card"], srfd_controller_id, srfd_lane_id, int(srfd_result.get("slot_index", -1)), "summon_from_deck"))
			return {"handled": true, "events": srfd_events}
		"summon_random_by_target_cost":
			var srbtc_target_id := str(event.get("target_instance_id", ""))
			var srbtc_target := _find_card_anywhere(match_state, srbtc_target_id)
			var srbtc_base_cost := int(srbtc_target.get("cost", 0))
			var srbtc_cost_offset := int(effect.get("cost_offset", 0))
			var srbtc_exact_cost := srbtc_base_cost + srbtc_cost_offset
			var srbtc_seeds: Array = CardCatalog._card_seeds()
			var srbtc_candidates: Array = []
			for seed in srbtc_seeds:
				if typeof(seed) != TYPE_DICTIONARY:
					continue
				if not bool(seed.get("collectible", true)):
					continue
				if str(seed.get("card_type", "")) != "creature":
					continue
				if int(seed.get("cost", 0)) != srbtc_exact_cost:
					continue
				srbtc_candidates.append(seed)
			if srbtc_candidates.is_empty():
				return {"handled": true, "events": []}
			var srbtc_controller_id := str(trigger.get("controller_player_id", ""))
			var srbtc_pick: Dictionary = srbtc_candidates[_timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_srbtc", srbtc_candidates.size())]
			var srbtc_template: Dictionary = srbtc_pick.duplicate(true)
			srbtc_template["definition_id"] = str(srbtc_template.get("card_id", ""))
			var srbtc_lane_id := ""
			var srbtc_lanes: Array = match_state.get("lanes", [])
			var srbtc_lane_index := int(trigger.get("lane_index", -1))
			if srbtc_lane_index >= 0 and srbtc_lane_index < srbtc_lanes.size():
				srbtc_lane_id = str(srbtc_lanes[srbtc_lane_index].get("lane_id", ""))
			if srbtc_lane_id.is_empty() and not srbtc_lanes.is_empty():
				srbtc_lane_id = str(srbtc_lanes[0].get("lane_id", ""))
			if srbtc_lane_id.is_empty():
				return {"handled": true, "events": []}
			var srbtc_gen := MatchMutations.build_generated_card(match_state, srbtc_controller_id, srbtc_template)
			var srbtc_result := MatchMutations.summon_card_to_lane(match_state, srbtc_controller_id, srbtc_gen, srbtc_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
			if not bool(srbtc_result.get("is_valid", false)):
				return {"handled": true, "events": []}
			var srbtc_events: Array = srbtc_result.get("events", []).duplicate()
			srbtc_events.append(_timing_rules()._build_summon_event(srbtc_result["card"], srbtc_controller_id, srbtc_lane_id, int(srbtc_result.get("slot_index", -1)), "summon_from_catalog"))
			return {"handled": true, "events": srbtc_events}
		"transform_random_from_catalog":
			var trfc_filter_raw = effect.get("filter", {})
			var trfc_filter: Dictionary = trfc_filter_raw if typeof(trfc_filter_raw) == TYPE_DICTIONARY else {}
			var trfc_seeds: Array = CardCatalog._card_seeds()
			var trfc_candidates: Array = []
			var trfc_req_card_type := str(trfc_filter.get("card_type", ""))
			for seed in trfc_seeds:
				if typeof(seed) != TYPE_DICTIONARY:
					continue
				if not bool(seed.get("collectible", true)):
					continue
				if not trfc_req_card_type.is_empty() and str(seed.get("card_type", "")) != trfc_req_card_type:
					continue
				trfc_candidates.append(seed)
			if trfc_candidates.is_empty():
				return {"handled": true, "events": []}
			var trfc_targets: Array = _timing_rules()._resolve_card_targets(match_state, trigger, event, effect)
			var trfc_events: Array = []
			for trfc_card in trfc_targets:
				var trfc_pick: Dictionary = trfc_candidates[_timing_rules()._deterministic_index(match_state, str(trfc_card.get("instance_id", "")) + "_trfc", trfc_candidates.size())]
				var trfc_template: Dictionary = trfc_pick.duplicate(true)
				trfc_template["definition_id"] = str(trfc_template.get("card_id", ""))
				var trfc_result := MatchMutations.transform_card(match_state, str(trfc_card.get("instance_id", "")), trfc_template, {"reason": "transform_random"})
				trfc_events.append_array(trfc_result.get("events", []))
			return {"handled": true, "events": trfc_events}
	return {"handled": false, "events": []}


static func _resolve_assemble(match_state: Dictionary, trigger: Dictionary, effect: Dictionary) -> Array:
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	if source_card.is_empty():
		return []
	var choices = effect.get("choices", source_card.get("assemble_choices", []))
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		return []
	var choice_index := clampi(int(source_card.get("assemble_choice_index", effect.get("default_choice", 0))), 0, choices.size() - 1)
	var selected = choices[choice_index]
	if typeof(selected) != TYPE_DICTIONARY:
		return []
	var events: Array = []
	for card in _collect_factotums(match_state, str(trigger.get("controller_player_id", "")), str(source_card.get("instance_id", ""))):
		if int(selected.get("power", 0)) != 0 or int(selected.get("health", 0)) != 0:
			EvergreenRules.apply_stat_bonus(card, int(selected.get("power", 0)), int(selected.get("health", 0)), "assemble")
			events.append({
				"event_type": "stats_modified",
				"source_instance_id": str(source_card.get("instance_id", "")),
				"target_instance_id": str(card.get("instance_id", "")),
				"power_bonus": int(selected.get("power", 0)),
				"health_bonus": int(selected.get("health", 0)),
				"reason": "assemble",
			})
		for keyword_id in _ensure_array(selected.get("keywords", [])):
			if _grant_keyword(card, str(keyword_id)):
				events.append({
					"event_type": "keyword_granted",
					"source_instance_id": str(source_card.get("instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"keyword_id": str(keyword_id),
				})
	return events


static func _resolve_shout_upgrade(match_state: Dictionary, trigger: Dictionary) -> Array:
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	if source_card.is_empty():
		return []
	var levels = source_card.get("shout_levels", [])
	if typeof(levels) != TYPE_ARRAY or levels.is_empty():
		return []
	var current_level := maxi(1, int(source_card.get("shout_level", 1)))
	var next_level := mini(levels.size(), current_level + 1)
	var next_template = levels[next_level - 1]
	if typeof(next_template) != TYPE_DICTIONARY:
		return []
	var shout_chain_id := str(source_card.get("shout_chain_id", source_card.get("definition_id", "")))
	var enriched_template: Dictionary = next_template.duplicate(true)
	enriched_template["shout_levels"] = levels.duplicate(true)
	if not enriched_template.has("shout_chain_id"):
		enriched_template["shout_chain_id"] = shout_chain_id
	var events: Array = []
	for card in _collect_owned_cards(match_state, str(trigger.get("controller_player_id", "")), [ZONE_HAND, ZONE_DECK, ZONE_DISCARD]):
		if str(card.get("shout_chain_id", card.get("definition_id", ""))) != shout_chain_id:
			continue
		var change_result := MatchMutations.change_card(card, enriched_template, {"reason": "shout_upgrade"})
		events.append_array(change_result.get("events", []))
	return events


static func _resolve_invade(match_state: Dictionary, trigger: Dictionary) -> Array:
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var gate := _find_player_gate(match_state, controller_player_id)
	if gate.is_empty():
		var gate_card := MatchMutations.build_generated_card(match_state, controller_player_id, _build_gate_template(1))
		var summon_result := MatchMutations.summon_card_to_lane(match_state, controller_player_id, gate_card, SHADOW_LANE_ID, {"source_zone": MatchMutations.ZONE_GENERATED})
		if not bool(summon_result.get("is_valid", false)):
			return []
		var events: Array = summon_result.get("events", []).duplicate(true)
		events.append({
			"event_type": EVENT_CREATURE_SUMMONED,
			"player_id": controller_player_id,
			"playing_player_id": controller_player_id,
			"source_instance_id": str(gate_card.get("instance_id", "")),
			"source_controller_player_id": controller_player_id,
			"lane_id": SHADOW_LANE_ID,
			"slot_index": int(summon_result.get("slot_index", -1)),
			"reason": "invade",
		})
		return events
	var next_level := maxi(1, int(gate.get("gate_level", 1)) + 1)
	var change_result := MatchMutations.change_card(gate, _build_gate_template(next_level), {"reason": "invade"})
	gate["gate_level"] = next_level
	gate["cannot_attack"] = true
	var generated_events: Array = change_result.get("events", []).duplicate(true)
	generated_events.append({
		"event_type": "oblivion_gate_upgraded",
		"source_instance_id": str(gate.get("instance_id", "")),
		"gate_level": int(gate.get("gate_level", next_level)),
	})
	return generated_events


static func _resolve_gate_buff(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Array:
	var gate := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	var target := _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
	if gate.is_empty() or target.is_empty():
		return []
	var events: Array = []
	var power_bonus := 0 if int(gate.get("gate_level", 1)) <= 1 else 1
	EvergreenRules.apply_stat_bonus(target, power_bonus, 1, "oblivion_gate")
	events.append({
		"event_type": "stats_modified",
		"source_instance_id": str(gate.get("instance_id", "")),
		"target_instance_id": str(target.get("instance_id", "")),
		"power_bonus": power_bonus,
		"health_bonus": 1,
		"reason": "oblivion_gate",
	})
	var keyword_count := maxi(0, int(gate.get("gate_level", 1)) - 3)
	for keyword_id in _choose_gate_keywords(target, keyword_count):
		if _grant_keyword(target, keyword_id):
			events.append({
				"event_type": "keyword_granted",
				"source_instance_id": str(gate.get("instance_id", "")),
				"target_instance_id": str(target.get("instance_id", "")),
				"keyword_id": keyword_id,
			})
	return events


static func _resolve_treasure_hunt(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	var drawn_card := _find_card_anywhere(match_state, str(event.get("drawn_instance_id", "")))
	if source_card.is_empty() or drawn_card.is_empty():
		return []
	var requirements = effect.get("requirements", source_card.get("treasure_hunt_requirements", []))
	if typeof(requirements) != TYPE_ARRAY or requirements.is_empty() or bool(source_card.get("treasure_hunt_complete", false)):
		return []
	var found: Array = _ensure_array(source_card.get("treasure_hunt_found", [])).duplicate()
	for requirement_index in range(requirements.size()):
		if found.has(requirement_index):
			continue
		var requirement = requirements[requirement_index]
		if typeof(requirement) == TYPE_DICTIONARY and _card_matches_requirement(drawn_card, requirement):
			found.append(requirement_index)
			break
	source_card["treasure_hunt_found"] = found
	if found.size() < requirements.size():
		return []
	source_card["treasure_hunt_complete"] = true
	return [{
		"event_type": EVENT_TREASURE_HUNT_COMPLETED,
		"player_id": str(trigger.get("controller_player_id", "")),
		"source_instance_id": str(source_card.get("instance_id", "")),
	}]


static func _resolve_player_damage(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary, amount: int) -> Array:
	if amount <= 0:
		return []
	var events: Array = []
	for player_id in _resolve_player_targets(match_state, event, effect, str(trigger.get("controller_player_id", ""))):
		var damage_result: Dictionary = _timing_rules().apply_player_damage(match_state, player_id, amount, {
			"reason": str(effect.get("reason", "effect_damage")),
			"source_instance_id": str(trigger.get("source_instance_id", "")),
			"source_controller_player_id": str(trigger.get("controller_player_id", "")),
		})
		events.append({
			"event_type": EVENT_DAMAGE_RESOLVED,
			"damage_kind": str(effect.get("reason", "effect_damage")),
			"source_instance_id": str(trigger.get("source_instance_id", "")),
			"source_controller_player_id": str(trigger.get("controller_player_id", "")),
			"target_type": "player",
			"target_player_id": player_id,
			"amount": int(damage_result.get("applied_damage", 0)),
		})
		events.append_array(damage_result.get("events", []))
		var winner := _get_opponent(match_state, player_id)
		_timing_rules().append_match_win_if_needed(match_state, player_id, str(winner.get("player_id", "")), events)
	return events


static func _apply_double_card_choice(card: Dictionary, choice) -> void:
	var options = _ensure_array(card.get("double_card_options", []))
	if options.is_empty():
		return
	var selected_index := int(choice)
	if typeof(choice) == TYPE_STRING:
		selected_index = 0
		for index in range(options.size()):
			var option = options[index]
			if typeof(option) == TYPE_DICTIONARY and str(option.get("id", option.get("definition_id", ""))) == str(choice):
				selected_index = index
				break
	selected_index = clampi(selected_index, 0, options.size() - 1)
	var selected = options[selected_index]
	if typeof(selected) != TYPE_DICTIONARY:
		return
	var template: Dictionary = selected.get("card_template", selected)
	var instance_id := str(card.get("instance_id", ""))
	var owner_player_id := str(card.get("owner_player_id", ""))
	var controller_player_id := str(card.get("controller_player_id", ""))
	var zone := str(card.get("zone", ""))
	var status_markers: Array = _ensure_array(card.get("status_markers", [])).duplicate(true)
	var granted_keywords: Array = _ensure_array(card.get("granted_keywords", [])).duplicate(true)
	var double_card_options: Array = _ensure_array(card.get("double_card_options", [])).duplicate(true)
	for key in template.keys():
		card[key] = _clone_variant(template[key])
	card["instance_id"] = instance_id
	card["owner_player_id"] = owner_player_id
	card["controller_player_id"] = controller_player_id
	card["zone"] = zone
	card["status_markers"] = status_markers
	card["granted_keywords"] = granted_keywords
	card["double_card_options"] = double_card_options
	card["selected_double_card_index"] = selected_index
	EvergreenRules.ensure_card_state(card)


static func _build_gate_template(level: int) -> Dictionary:
	var gate_level := maxi(1, level)
	return {
		"definition_id": "generated_oblivion_gate",
		"name": "Oblivion Gate",
		"card_type": "creature",
		"power": 0,
		"health": 4 + (gate_level - 1) * 2,
		"gate_level": gate_level,
		"cannot_attack": true,
		"rules_tags": [RULE_TAG_OBLIVION_GATE],
		"triggered_abilities": [{
			"id": "oblivion_gate_buff",
			"event_type": EVENT_CREATURE_SUMMONED,
			"match_role": "controller",
			"required_zone": ZONE_LANE,
			"required_event_source_subtype": "daedra",
			"excluded_event_source_rule_tag": RULE_TAG_OBLIVION_GATE,
			"effects": [{"op": "buff_oblivion_gate_summon", "target": "event_source"}],
		}],
	}


static func _find_player_gate(match_state: Dictionary, player_id: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != SHADOW_LANE_ID:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and _card_has_string(card, "rules_tags", RULE_TAG_OBLIVION_GATE):
				return card
	return {}


static func _choose_gate_keywords(card: Dictionary, count: int) -> Array:
	var picks: Array = []
	for keyword_id in GATE_KEYWORD_POOL:
		if picks.size() >= count:
			break
		if EvergreenRules.has_keyword(card, keyword_id):
			continue
		picks.append(keyword_id)
	return picks


static func _collect_factotums(match_state: Dictionary, player_id: String, source_instance_id: String) -> Array:
	var cards: Array = []
	var source_card := _find_card_anywhere(match_state, source_instance_id)
	if not source_card.is_empty():
		cards.append(source_card)
	for card in _collect_owned_cards(match_state, player_id, [ZONE_HAND, ZONE_DECK]):
		if _card_has_string(card, "subtypes", "factotum"):
			cards.append(card)
	return cards


static func _collect_owned_cards(match_state: Dictionary, player_id: String, zones: Array) -> Array:
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return []
	var cards: Array = []
	for zone_name in zones:
		for card in _ensure_array(player.get(str(zone_name), [])):
			if typeof(card) == TYPE_DICTIONARY:
				cards.append(card)
	return cards


static func _card_matches_requirement(card: Dictionary, requirement: Dictionary) -> bool:
	if requirement.has("card_type") and str(requirement.get("card_type", "")) != str(card.get("card_type", "")):
		return false
	if requirement.has("definition_id") and str(requirement.get("definition_id", "")) != str(card.get("definition_id", "")):
		return false
	if requirement.has("subtype") and not _card_has_string(card, "subtypes", str(requirement.get("subtype", ""))):
		return false
	if requirement.has("rule_tag") and not _card_has_string(card, "rules_tags", str(requirement.get("rule_tag", ""))):
		return false
	return true


static func _grant_keyword(card: Dictionary, keyword_id: String) -> bool:
	EvergreenRules.ensure_card_state(card)
	var granted_keywords: Array = _ensure_array(card.get("granted_keywords", []))
	if granted_keywords.has(keyword_id):
		return false
	granted_keywords.append(keyword_id)
	card["granted_keywords"] = granted_keywords
	return true


static func _resolve_player_targets(match_state: Dictionary, event: Dictionary, effect: Dictionary, controller_player_id: String) -> Array:
	match str(effect.get("target_player", "target_player")):
		"controller":
			return [controller_player_id]
		"opponent":
			for player in match_state.get("players", []):
				if str(player.get("player_id", "")) != controller_player_id:
					return [str(player.get("player_id", ""))]
			return []
		"event_player":
			var event_player_id := str(event.get("player_id", event.get("playing_player_id", "")))
			return [] if event_player_id.is_empty() else [event_player_id]
		"target_player":
			var target_player_id := str(event.get("target_player_id", ""))
			return [] if target_player_id.is_empty() else [target_player_id]
	return []


static func _find_card_anywhere(match_state: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for player in match_state.get("players", []):
		if typeof(player) != TYPE_DICTIONARY:
			continue
		for zone_name in [ZONE_HAND, "support", ZONE_DISCARD, "banished", ZONE_DECK]:
			for card in _ensure_array(player.get(zone_name, [])):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return card
	for lane in match_state.get("lanes", []):
		for player_id in lane.get("player_slots", {}).keys():
			for card in _ensure_array(lane.get("player_slots", {}).get(player_id, [])):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == instance_id:
					return card
				for attached_item in _ensure_array(card.get("attached_items", [])):
					if typeof(attached_item) == TYPE_DICTIONARY and str(attached_item.get("instance_id", "")) == instance_id:
						return attached_item
	return {}


static func _get_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _card_has_string(card: Dictionary, field_name: String, expected: String) -> bool:
	if card.is_empty():
		return false
	for value in _ensure_array(card.get(field_name, [])):
		if str(value) == expected:
			return true
	return false


static func _get_opponent(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != player_id:
			return player
	return {}


static func _has_friendly_with_subtype(match_state: Dictionary, player_id: String, subtype: String, exclude_instance_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		var player_slots: Dictionary = lane.get("player_slots", {})
		var slots: Array = player_slots.get(player_id, [])
		for card in slots:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if str(card.get("instance_id", "")) == exclude_instance_id:
				continue
			if _card_has_string(card, "subtypes", subtype):
				return true
	return false


static func _has_other_friendly_with_keyword(match_state: Dictionary, player_id: String, keyword_id: String, exclude_instance_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		var player_slots: Dictionary = lane.get("player_slots", {})
		var slots: Array = player_slots.get(player_id, [])
		for card in slots:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if str(card.get("instance_id", "")) == exclude_instance_id:
				continue
			if EvergreenRules.has_keyword(card, keyword_id):
				return true
	return false


static func _has_wounded_enemy_in_lane(match_state: Dictionary, trigger: Dictionary) -> bool:
	var controller_id := str(trigger.get("controller_player_id", ""))
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	if source_card.is_empty():
		return false
	var source_lane_index := _get_card_lane_index(match_state, source_card)
	if source_lane_index < 0:
		return false
	var lanes: Array = match_state.get("lanes", [])
	if source_lane_index >= lanes.size():
		return false
	var lane: Dictionary = lanes[source_lane_index]
	var player_slots: Dictionary = lane.get("player_slots", {})
	for pid in player_slots.keys():
		if str(pid) == controller_id:
			continue
		for card in player_slots[pid]:
			if typeof(card) == TYPE_DICTIONARY and EvergreenRules.has_status(card, EvergreenRules.STATUS_WOUNDED):
				return true
	return false


static func _has_enemy_in_lane(match_state: Dictionary, trigger: Dictionary) -> bool:
	var controller_id := str(trigger.get("controller_player_id", ""))
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	if source_card.is_empty():
		return false
	var source_lane_index := _get_card_lane_index(match_state, source_card)
	if source_lane_index < 0:
		return false
	var lanes: Array = match_state.get("lanes", [])
	if source_lane_index >= lanes.size():
		return false
	var lane: Dictionary = lanes[source_lane_index]
	var player_slots: Dictionary = lane.get("player_slots", {})
	for pid in player_slots.keys():
		if str(pid) == controller_id:
			continue
		var slots: Array = player_slots.get(str(pid), [])
		if not slots.is_empty():
			return true
	return false


static func _get_card_lane_index(match_state: Dictionary, card: Dictionary) -> int:
	var instance_id := str(card.get("instance_id", ""))
	if instance_id.is_empty():
		return -1
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots: Dictionary = lane.get("player_slots", {})
		for pid in player_slots.keys():
			for slot_card in player_slots[pid]:
				if typeof(slot_card) == TYPE_DICTIONARY and str(slot_card.get("instance_id", "")) == instance_id:
					return lane_index
	return -1


static func _ensure_array(value) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


static func _clone_variant(value):
	if typeof(value) == TYPE_DICTIONARY:
		var clone := {}
		for key in value.keys():
			clone[key] = _clone_variant(value[key])
		return clone
	if typeof(value) == TYPE_ARRAY:
		var clone_array: Array = []
		for item in value:
			clone_array.append(_clone_variant(item))
		return clone_array
	return value


static func _timing_rules():
	return load("res://src/core/match/match_timing.gd")


# --- Hand selection mechanic ---


static func card_matches_hand_selection_filter(card: Dictionary, filter: Dictionary) -> bool:
	if filter.is_empty():
		return true
	if filter.has("rules_tag") and not _card_has_string(card, "rules_tags", str(filter.get("rules_tag", ""))):
		return false
	if filter.has("card_type") and str(filter.get("card_type", "")) != str(card.get("card_type", "")):
		return false
	if filter.has("subtype") and not _card_has_string(card, "subtypes", str(filter.get("subtype", ""))):
		return false
	if filter.has("keyword"):
		var kw := str(filter.get("keyword", ""))
		if not _card_has_string(card, "keywords", kw) and not _card_has_string(card, "granted_keywords", kw):
			return false
	if filter.has("attribute"):
		var attrs = card.get("attributes", [])
		if typeof(attrs) != TYPE_ARRAY or not attrs.has(str(filter.get("attribute", ""))):
			return false
	if filter.has("definition_id") and str(filter.get("definition_id", "")) != str(card.get("definition_id", "")):
		return false
	return true


static func apply_hand_selection_effect(match_state: Dictionary, player_id: String, source_instance_id: String, chosen_card: Dictionary, then_op: String, then_context: Dictionary) -> Array:
	match then_op:
		"upgrade_shout":
			return _resolve_shout_upgrade_for_card(match_state, player_id, chosen_card)
		"grant_keyword":
			var keyword_id := str(then_context.get("keyword_id", ""))
			if keyword_id.is_empty():
				return []
			EvergreenRules.ensure_card_state(chosen_card)
			var granted_keywords: Array = chosen_card.get("granted_keywords", [])
			if not granted_keywords.has(keyword_id):
				granted_keywords.append(keyword_id)
				chosen_card["granted_keywords"] = granted_keywords
			return [{"event_type": "keyword_granted", "source_instance_id": source_instance_id, "target_instance_id": str(chosen_card.get("instance_id", "")), "keyword_id": keyword_id, "zone": "hand"}]
	return []


static func _resolve_shout_upgrade_for_card(match_state: Dictionary, player_id: String, chosen_card: Dictionary) -> Array:
	var levels = chosen_card.get("shout_levels", [])
	if typeof(levels) != TYPE_ARRAY or levels.is_empty():
		return []
	var current_level := maxi(1, int(chosen_card.get("shout_level", 1)))
	var next_level := mini(levels.size(), current_level + 1)
	var next_template = levels[next_level - 1]
	if typeof(next_template) != TYPE_DICTIONARY:
		return []
	var shout_chain_id := str(chosen_card.get("shout_chain_id", chosen_card.get("definition_id", "")))
	var enriched_template: Dictionary = next_template.duplicate(true)
	enriched_template["shout_levels"] = levels.duplicate(true)
	if not enriched_template.has("shout_chain_id"):
		enriched_template["shout_chain_id"] = shout_chain_id
	var events: Array = []
	for card in _collect_owned_cards(match_state, player_id, [ZONE_HAND, ZONE_DECK, ZONE_DISCARD]):
		if str(card.get("shout_chain_id", card.get("definition_id", ""))) != shout_chain_id:
			continue
		var change_result := MatchMutations.change_card(card, enriched_template, {"reason": "shout_upgrade"})
		events.append_array(change_result.get("events", []))
	return events


# --- Betray ---


const MUSHROOM_TOWER_ID := "hom_end_mushroom_tower"


static func action_has_betray(match_state: Dictionary, player_id: String, card: Dictionary) -> bool:
	if EvergreenRules.has_keyword(card, "betray"):
		return true
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return false
	for support_card in _ensure_array(player.get("support", [])):
		if typeof(support_card) != TYPE_DICTIONARY:
			continue
		if str(support_card.get("definition_id", support_card.get("card_id", ""))) == MUSHROOM_TOWER_ID:
			return true
	return false


static func get_betray_sacrifice_candidates(match_state: Dictionary, player_id: String) -> Array:
	var candidates: Array = []
	for lane in match_state.get("lanes", []):
		for card in _ensure_array(lane.get("player_slots", {}).get(player_id, [])):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if str(card.get("card_type", "")) == "creature":
				candidates.append(card)
	return candidates


static func betray_replay_has_valid_target(match_state: Dictionary, player_id: String, action_card: Dictionary, excluding_instance_id: String) -> bool:
	var action_target_mode := str(action_card.get("action_target_mode", ""))
	if action_target_mode.is_empty():
		return true
	for lane in match_state.get("lanes", []):
		for lane_player_id in lane.get("player_slots", {}).keys():
			for card in _ensure_array(lane.get("player_slots", {}).get(lane_player_id, [])):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == excluding_instance_id:
					continue
				if _card_matches_target_mode(action_target_mode, card, player_id):
					return true
	if action_target_mode == "creature_or_player":
		return true
	return false


static func _card_matches_target_mode(target_mode: String, card: Dictionary, controller_player_id: String) -> bool:
	var card_controller := str(card.get("controller_player_id", ""))
	match target_mode:
		"any_creature":
			return true
		"enemy_creature", "enemy_creature_in_lane":
			return card_controller != controller_player_id
		"friendly_creature", "another_friendly_creature":
			return card_controller == controller_player_id
		"creature_or_player":
			return true
		"wounded_creature":
			return EvergreenRules.has_status(card, EvergreenRules.STATUS_WOUNDED) if card.has("statuses") else false
	return true