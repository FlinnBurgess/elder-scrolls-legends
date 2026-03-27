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
	EvergreenRules.KEYWORD_RALLY,
	EvergreenRules.KEYWORD_REGENERATE,
	EvergreenRules.KEYWORD_WARD,
]


static func get_catalog_seeds() -> Array:
	return CardCatalog._card_seeds()


static func ensure_match_state(match_state: Dictionary) -> void:
	for player in match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY:
			ensure_player_state(player)


static func ensure_player_state(player: Dictionary) -> void:
	if not player.has("cards_played_this_turn"):
		player["cards_played_this_turn"] = 0
	if not player.has("noncreature_plays_this_turn"):
		player["noncreature_plays_this_turn"] = 0
	if not player.has("empower_count_this_turn"):
		player["empower_count_this_turn"] = 0
	if not player.has("creature_summons_this_turn"):
		player["creature_summons_this_turn"] = 0
	if not player.has("creatures_died_this_turn"):
		player["creatures_died_this_turn"] = 0
	if not player.has("invades_this_turn"):
		player["invades_this_turn"] = 0
	if not player.has("wax_wane_state"):
		player["wax_wane_state"] = WAX


static func reset_turn_state(player: Dictionary) -> void:
	ensure_player_state(player)
	# permanent_empower: accumulate empower bonus across turns
	if bool(player.get("_permanent_empower_active", false)):
		player["_permanent_empower_accumulated"] = int(player.get("_permanent_empower_accumulated", 0)) + int(player.get("empower_count_this_turn", 0))
	player["cards_played_this_turn"] = 0
	player["noncreature_plays_this_turn"] = 0
	player["empower_count_this_turn"] = 0
	player["creature_summons_this_turn"] = 0
	player["creatures_died_this_turn"] = 0
	player["invades_this_turn"] = 0
	player["pilfer_or_drain_count_this_turn"] = 0
	player["_double_summon_this_turn"] = false


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
	if event_type == "creature_destroyed":
		# Increment death counter for both players (Ghost Fanatic counts all deaths)
		for p in match_state.get("players", []):
			if typeof(p) == TYPE_DICTIONARY:
				ensure_player_state(p)
				p["creatures_died_this_turn"] = int(p.get("creatures_died_this_turn", 0)) + 1
		return
	if event_type == EVENT_CREATURE_SUMMONED:
		var summon_player := _get_player_state(match_state, str(event.get("source_controller_player_id", event.get("player_id", ""))))
		if not summon_player.is_empty():
			ensure_player_state(summon_player)
			summon_player["creature_summons_this_turn"] = int(summon_player.get("creature_summons_this_turn", 0)) + 1
		return
	if event_type == "invade_triggered":
		var invade_player := _get_player_state(match_state, str(event.get("player_id", "")))
		if not invade_player.is_empty():
			ensure_player_state(invade_player)
			invade_player["invades_this_turn"] = int(invade_player.get("invades_this_turn", 0)) + 1
		return
	if event_type == EVENT_DAMAGE_RESOLVED and str(event.get("target_type", "")) == "player":
		var source_player := _get_player_state(match_state, str(event.get("source_controller_player_id", "")))
		var target_player_id := str(event.get("target_player_id", ""))
		if source_player.is_empty() or target_player_id.is_empty() or str(source_player.get("player_id", "")) == target_player_id:
			return
		ensure_player_state(source_player)
		source_player["empower_count_this_turn"] = int(source_player.get("empower_count_this_turn", 0)) + 1
		# Track pilfer/drain for cost reduction (The Ultimate Heist)
		# Counts all friendly-to-enemy player damage (same scope as FAMILY_ON_FRIENDLY_PILFER_OR_DRAIN)
		source_player["pilfer_or_drain_count_this_turn"] = int(source_player.get("pilfer_or_drain_count_this_turn", 0)) + 1


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
		if int(descriptor.get("exalt_cost", 0)) > 0:
			var exalt_source_id := str(trigger.get("source_instance_id", ""))
			var exalt_source := _find_card_anywhere(match_state, exalt_source_id)
			if not exalt_source.is_empty() and not EvergreenRules.has_raw_status(exalt_source, EvergreenRules.STATUS_EXALTED):
				return false
		if bool(descriptor.get("plot_bonus", false)) and int(controller.get("cards_played_this_turn", 0)) < 2:
			return false
		var req_summon_idx := int(descriptor.get("required_summon_index_this_turn", 0))
		if req_summon_idx > 0 and int(controller.get("creature_summons_this_turn", 0)) != req_summon_idx:
			return false
		var required_phase := str(descriptor.get("required_wax_wane_phase", ""))
		if not required_phase.is_empty() and required_phase != str(controller.get("wax_wane_state", WAX)) and not bool(controller.get("_dual_wax_wane", false)):
			return false
	if bool(descriptor.get("invaded_this_turn", false)):
		if int(controller.get("invades_this_turn", 0)) <= 0:
			return false
	# Prevent on_invade triggers (e.g. Keeper of the Gates) from re-triggering
	# on invade events that were themselves produced by an on_invade trigger.
	if str(descriptor.get("family", "")) == "on_invade" and bool(event.get("from_on_invade", false)):
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
	# Required attribute in hand condition
	var required_hand_attr := str(descriptor.get("required_attribute_in_hand", ""))
	if not required_hand_attr.is_empty():
		var hand: Array = controller.get("hand", [])
		var raih_found := false
		for card in hand:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var attrs = card.get("attributes", [])
			if typeof(attrs) == TYPE_ARRAY and attrs.has(required_hand_attr):
				raih_found = true
				break
			# Neutral cards have empty attributes array
			if required_hand_attr == "neutral" and typeof(attrs) == TYPE_ARRAY and attrs.is_empty():
				raih_found = true
				break
		if not raih_found:
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
	# Marked target alive condition (e.g. Miscarcand Lich)
	if bool(descriptor.get("if_marked_target_alive", false)):
		var mark_source_id := str(trigger.get("source_instance_id", ""))
		var marked_alive := false
		for lane in match_state.get("lanes", []):
			for pid in lane.get("player_slots", {}).keys():
				for card in lane.get("player_slots", {}).get(pid, []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("_marked_by", "")) == mark_source_id:
						marked_alive = true
		if not marked_alive:
			return false
	# Required target is the marked creature (e.g. Preying Elytra)
	var req_target := str(descriptor.get("required_target", ""))
	if req_target == "marked":
		var rt_source_id := str(trigger.get("source_instance_id", ""))
		var rt_event_target_id := str(event.get("target_instance_id", ""))
		if rt_event_target_id.is_empty():
			return false
		var rt_target_card := _find_card_anywhere(match_state, rt_event_target_id)
		if rt_target_card.is_empty() or str(rt_target_card.get("_marked_by", "")) != rt_source_id:
			return false
	# Max magicka threshold conditions
	var req_magicka_gte := int(descriptor.get("required_max_magicka_gte", 0))
	if req_magicka_gte > 0 and int(controller.get("max_magicka", 0)) < req_magicka_gte:
		return false
	var req_magicka_lt := int(descriptor.get("required_max_magicka_lt", 0))
	if req_magicka_lt > 0 and int(controller.get("max_magicka", 0)) >= req_magicka_lt:
		return false
	# Required friendly creature with minimum power
	var rfcmp := int(descriptor.get("required_friendly_creature_min_power", 0))
	if rfcmp > 0:
		var rfcmp_controller := str(trigger.get("controller_player_id", ""))
		var rfcmp_found := false
		for lane in match_state.get("lanes", []):
			for card in lane.get("player_slots", {}).get(rfcmp_controller, []):
				if typeof(card) == TYPE_DICTIONARY and EvergreenRules.get_power(card) >= rfcmp:
					rfcmp_found = true
					break
			if rfcmp_found:
				break
		if not rfcmp_found:
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
		if required_phase != str(controller.get("wax_wane_state", WAX)) and not bool(controller.get("_dual_wax_wane", false)):
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
			var _shout_upgrade_all := str(effect.get("scope", "")) == "all"
			return {"handled": true, "events": _resolve_shout_upgrade(match_state, trigger, _shout_upgrade_all)}
		"invade":
			return {"handled": true, "events": _resolve_invade(match_state, trigger)}
		"buff_oblivion_gate_summon":
			return {"handled": true, "events": _resolve_gate_buff(match_state, trigger, event)}
		"track_treasure_hunt":
			return {"handled": true, "events": _resolve_treasure_hunt(match_state, trigger, event, effect)}
		"damage":
			var dmg_amount_raw = effect.get("amount", 0)
			if str(dmg_amount_raw) == "destroy_front_rune":
				var dmg_controller_id := str(trigger.get("controller_player_id", ""))
				var dmg_opponent := _get_opponent(match_state, dmg_controller_id)
				var dmg_opponent_id := str(dmg_opponent.get("player_id", ""))
				var dmg_events: Array = []
				if not dmg_opponent_id.is_empty():
					var dmg_rune_result: Dictionary = _timing_rules().destroy_front_rune(match_state, dmg_opponent_id, {"source_instance_id": str(trigger.get("source_instance_id", ""))})
					dmg_events.append_array(dmg_rune_result.get("events", []))
				return {"handled": true, "events": dmg_events}
			var dmg_total := int(dmg_amount_raw) * _count_source_multiplier(match_state, trigger, effect)
			return {"handled": true, "events": _resolve_player_damage(match_state, trigger, event, effect, dmg_total)}
		"empower_damage":
			var controller := _get_player_state(match_state, str(trigger.get("controller_player_id", "")))
			ensure_player_state(controller)
			var empower_amount := int(effect.get("amount", 0)) + int(effect.get("amount_per_damage", 0)) * int(controller.get("empower_count_this_turn", 0))
			return {"handled": true, "events": _resolve_player_damage(match_state, trigger, event, effect, empower_amount)}
		"gain_magicka":
			var gm_player := _get_player_state(match_state, str(trigger.get("controller_player_id", "")))
			if gm_player.is_empty():
				return {"handled": true, "events": []}
			var gm_base := int(effect.get("amount", 0))
			var gm_count := _resolve_gain_magicka_count(match_state, trigger, effect)
			var gm_amount := gm_base * gm_count
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
			var srfc_min_cost := int(srfc_filter.get("min_cost", -1))
			var srfc_exact_cost := int(srfc_filter.get("exact_cost", -1))
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
				if srfc_min_cost >= 0 and int(seed.get("cost", 0)) < srfc_min_cost:
					continue
				if srfc_exact_cost >= 0 and int(seed.get("cost", 0)) != srfc_exact_cost:
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
			# Fall back to event lane_id (e.g. action played to a specific lane)
			if srfc_lane_id.is_empty():
				srfc_lane_id = str(event.get("lane_id", ""))
			if srfc_lane_id.is_empty() and not srfc_lanes.is_empty():
				srfc_lane_id = str(srfc_lanes[0].get("lane_id", ""))
			if srfc_lane_id.is_empty():
				return {"handled": true, "events": []}
			var srfc_gen := MatchMutations.build_generated_card(match_state, srfc_controller_id, srfc_template)
			# Try the target lane first; if full, overflow to the other lane
			var srfc_result := MatchMutations.summon_card_to_lane(match_state, srfc_controller_id, srfc_gen, srfc_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
			if not bool(srfc_result.get("is_valid", false)):
				# Overflow: try the other lane
				var srfc_other_lane_id := ""
				for srfc_lane in srfc_lanes:
					var srfc_lid := str(srfc_lane.get("lane_id", ""))
					if srfc_lid != srfc_lane_id and not srfc_lid.is_empty():
						srfc_other_lane_id = srfc_lid
						break
				if not srfc_other_lane_id.is_empty():
					srfc_result = MatchMutations.summon_card_to_lane(match_state, srfc_controller_id, srfc_gen, srfc_other_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
					if bool(srfc_result.get("is_valid", false)):
						srfc_lane_id = srfc_other_lane_id
				if not bool(srfc_result.get("is_valid", false)):
					return {"handled": true, "events": []}
			var srfc_events: Array = srfc_result.get("events", []).duplicate()
			srfc_events.append(_timing_rules()._build_summon_event(srfc_result["card"], srfc_controller_id, srfc_lane_id, int(srfc_result.get("slot_index", -1)), "summon_from_catalog"))
			_timing_rules()._check_summon_abilities(match_state, srfc_result["card"])
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
			var grth_req_subtype := str(grth_filter.get("required_subtype", grth_filter.get("subtype", "")))
			var grth_req_rules_tag := str(grth_filter.get("rules_tag", grth_filter.get("tag", "")))
			var grth_req_keyword := str(grth_filter.get("keyword", ""))
			var grth_name_contains := str(grth_filter.get("name_contains", ""))
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
				if not grth_req_keyword.is_empty():
					var grth_kws = seed.get("keywords", [])
					if typeof(grth_kws) != TYPE_ARRAY or not grth_kws.has(grth_req_keyword):
						continue
				if not grth_name_contains.is_empty():
					var grth_card_name := str(seed.get("name", ""))
					if grth_card_name.findn(grth_name_contains) < 0:
						continue
				grth_candidates.append(seed)
			if grth_candidates.is_empty():
				return {"handled": true, "events": []}
			var grth_count := int(effect.get("count", 1))
			var grth_all_events: Array = []
			var grth_hand: Array = grth_player.get(MatchMutations.ZONE_HAND, [])
			for grth_i in range(grth_count):
				if grth_hand.size() >= MatchTiming.MAX_HAND_SIZE:
					break
				var grth_seq := str(match_state.get("generated_card_sequence", 0))
				var grth_pick: Dictionary = grth_candidates[_timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_grth_" + grth_seq + "_" + str(grth_i), grth_candidates.size())]
				var grth_template: Dictionary = grth_pick.duplicate(true)
				grth_template["definition_id"] = str(grth_template.get("card_id", ""))
				var grth_gen := MatchMutations.build_generated_card(match_state, grth_controller_id, grth_template)
				grth_gen["zone"] = MatchMutations.ZONE_HAND
				grth_hand.append(grth_gen)
				grth_all_events.append({"event_type": "card_drawn", "player_id": grth_controller_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "drawn_instance_id": str(grth_gen.get("instance_id", "")), "source_zone": MatchMutations.ZONE_GENERATED, "target_zone": MatchMutations.ZONE_HAND, "reason": "generate_random_to_hand"})
			return {"handled": true, "events": grth_all_events}
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
			if not rrhcc_chosen.has("_base_cost"):
				rrhcc_chosen["_base_cost"] = int(rrhcc_chosen.get("cost", 0))
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
			var srfd_max_cost := int(srfd_filter.get("max_cost", -1))
			var srfd_cost_equals_source := str(srfd_filter.get("cost_equals_source", ""))
			if srfd_cost_equals_source == "controller_current_magicka":
				srfd_max_cost = int(srfd_player.get("current_magicka", srfd_player.get("max_magicka", 12)))
				# exact cost match for this source
			var srfd_exact_cost := -1
			if srfd_cost_equals_source == "controller_current_magicka":
				srfd_exact_cost = srfd_max_cost
				srfd_max_cost = -1
			var srfd_req_subtype := str(srfd_filter.get("subtype", ""))
			for i in range(srfd_deck.size()):
				var card = srfd_deck[i]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not srfd_req_card_type.is_empty() and str(card.get("card_type", "")) != srfd_req_card_type:
					continue
				if srfd_max_cost >= 0 and int(card.get("cost", 0)) > srfd_max_cost:
					continue
				if srfd_exact_cost >= 0 and int(card.get("cost", 0)) != srfd_exact_cost:
					continue
				if not srfd_req_subtype.is_empty():
					var srfd_subtypes = card.get("subtypes", [])
					if typeof(srfd_subtypes) != TYPE_ARRAY or not srfd_subtypes.has(srfd_req_subtype):
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
			_timing_rules()._check_summon_abilities(match_state, srbtc_result["card"])
			return {"handled": true, "events": srbtc_events}
		"look_at_top_deck_may_discard":
			var ltdmd_controller_id := str(trigger.get("controller_player_id", ""))
			var ltdmd_player := _get_player_state(match_state, ltdmd_controller_id)
			if ltdmd_player.is_empty():
				return {"handled": true, "events": []}
			var ltdmd_deck: Array = ltdmd_player.get("deck", [])
			if ltdmd_deck.is_empty():
				return {"handled": true, "events": []}
			var ltdmd_top_card: Dictionary = ltdmd_deck.back()
			if typeof(ltdmd_top_card) != TYPE_DICTIONARY:
				return {"handled": true, "events": []}
			var ltdmd_choices: Array = match_state.get("pending_top_deck_choices", [])
			ltdmd_choices.append({
				"player_id": ltdmd_controller_id,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"revealed_card": ltdmd_top_card.duplicate(true),
			})
			match_state["pending_top_deck_choices"] = ltdmd_choices
			return {"handled": true, "events": [{"event_type": "top_deck_revealed_for_choice", "player_id": ltdmd_controller_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "revealed_card": ltdmd_top_card.duplicate(true)}]}
		"transform_random_by_cost":
			var trbc_targets: Array = _timing_rules()._resolve_card_targets(match_state, trigger, event, effect)
			var trbc_events: Array = []
			var trbc_offset := int(effect.get("cost_offset", 0))
			for trbc_card in trbc_targets:
				var trbc_target_cost := int(trbc_card.get("cost", trbc_card.get("base_cost", 0)))
				var trbc_desired_cost := maxi(0, trbc_target_cost + trbc_offset)
				var trbc_seeds: Array = CardCatalog._card_seeds()
				var trbc_candidates: Array = []
				for seed in trbc_seeds:
					if typeof(seed) != TYPE_DICTIONARY:
						continue
					if not bool(seed.get("collectible", true)):
						continue
					if str(seed.get("card_type", "")) != "creature":
						continue
					if int(seed.get("cost", 0)) != trbc_desired_cost:
						continue
					trbc_candidates.append(seed)
				if trbc_candidates.is_empty():
					continue
				var trbc_pick: Dictionary = trbc_candidates[_timing_rules()._deterministic_index(match_state, str(trbc_card.get("instance_id", "")) + "_trbc", trbc_candidates.size())]
				var trbc_template: Dictionary = trbc_pick.duplicate(true)
				trbc_template["definition_id"] = str(trbc_template.get("card_id", ""))
				var trbc_result := MatchMutations.transform_card(match_state, str(trbc_card.get("instance_id", "")), trbc_template, {"reason": "transform_random_by_cost"})
				trbc_events.append_array(trbc_result.get("events", []))
			return {"handled": true, "events": trbc_events}
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
		"draw_filtered_or_move_to_bottom":
			var dfomb_controller_id := str(trigger.get("controller_player_id", ""))
			var dfomb_player := _get_player_state(match_state, dfomb_controller_id)
			if dfomb_player.is_empty():
				return {"handled": true, "events": []}
			var dfomb_deck: Array = dfomb_player.get("deck", [])
			if dfomb_deck.is_empty():
				return {"handled": true, "events": []}
			var dfomb_top_card: Dictionary = dfomb_deck.back()
			if typeof(dfomb_top_card) != TYPE_DICTIONARY:
				return {"handled": true, "events": []}
			var dfomb_filter_raw = effect.get("filter", {})
			var dfomb_filter: Dictionary = dfomb_filter_raw if typeof(dfomb_filter_raw) == TYPE_DICTIONARY else {}
			var dfomb_required_type := str(dfomb_filter.get("card_type", ""))
			var dfomb_card_type := str(dfomb_top_card.get("card_type", ""))
			if not dfomb_required_type.is_empty() and dfomb_card_type == dfomb_required_type:
				dfomb_deck.pop_back()
				var dfomb_hand: Array = dfomb_player.get("hand", [])
				dfomb_hand.append(dfomb_top_card)
				return {"handled": true, "events": [{"event_type": "card_drawn", "player_id": dfomb_controller_id, "instance_id": str(dfomb_top_card.get("instance_id", "")), "source": "draw_filtered"}]}
			else:
				dfomb_deck.pop_back()
				dfomb_deck.insert(0, dfomb_top_card)
				return {"handled": true, "events": [{"event_type": "card_moved_to_bottom", "player_id": dfomb_controller_id, "instance_id": str(dfomb_top_card.get("instance_id", ""))}]}
		"vision_and_transform":
			var vat_targets: Array = _timing_rules()._resolve_card_targets(match_state, trigger, event, effect)
			if vat_targets.is_empty():
				return {"handled": true, "events": []}
			var vat_target: Dictionary = vat_targets[0]
			var vat_seeds: Array = CardCatalog._card_seeds()
			var vat_creatures: Array = []
			for seed in vat_seeds:
				if typeof(seed) == TYPE_DICTIONARY and str(seed.get("card_type", "")) == "creature" and bool(seed.get("collectible", true)):
					vat_creatures.append(seed)
			if vat_creatures.size() < 2:
				return {"handled": true, "events": []}
			var vat_idx1: int = _timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_vat1", vat_creatures.size())
			var vat_idx2: int = _timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_vat2", vat_creatures.size())
			var vat_t1: Dictionary = vat_creatures[vat_idx1].duplicate(true)
			vat_t1["definition_id"] = str(vat_t1.get("card_id", ""))
			var vat_t2: Dictionary = vat_creatures[vat_idx2].duplicate(true)
			vat_t2["definition_id"] = str(vat_t2.get("card_id", ""))
			var vat_target_id := str(vat_target.get("instance_id", ""))
			var vat_pending: Array = match_state.get("pending_player_choices", [])
			vat_pending.append({
				"player_id": str(trigger.get("controller_player_id", "")),
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"prompt": "Choose a creature to transform into:",
				"mode": "card",
				"options": [{"label": str(vat_t1.get("name", "")), "card": vat_t1}, {"label": str(vat_t2.get("name", "")), "card": vat_t2}],
				"effects_per_option": [
					[{"op": "transform", "target_instance_id": vat_target_id, "card_template": vat_t1}],
					[{"op": "transform", "target_instance_id": vat_target_id, "card_template": vat_t2}],
				],
				"trigger": trigger.duplicate(true),
				"event": event.duplicate(true),
			})
			return {"handled": true, "events": [{"event_type": "player_choice_pending", "player_id": str(trigger.get("controller_player_id", ""))}]}
		"guess_opponent_card":
			var goc_controller := str(trigger.get("controller_player_id", ""))
			var goc_opponent := ""
			for player in match_state.get("players", []):
				if str(player.get("player_id", "")) != goc_controller:
					goc_opponent = str(player.get("player_id", ""))
					break
			var goc_opp := _get_player_state(match_state, goc_opponent)
			if goc_opp.is_empty():
				return {"handled": true, "events": []}
			var goc_opp_deck: Array = goc_opp.get("deck", [])
			if goc_opp_deck.size() < 2:
				return {"handled": true, "events": []}
			var goc_card1: Dictionary = goc_opp_deck[goc_opp_deck.size() - 1].duplicate(true) if typeof(goc_opp_deck[goc_opp_deck.size() - 1]) == TYPE_DICTIONARY else {}
			var goc_card2: Dictionary = goc_opp_deck[goc_opp_deck.size() - 2].duplicate(true) if typeof(goc_opp_deck[goc_opp_deck.size() - 2]) == TYPE_DICTIONARY else {}
			goc_card1.erase("instance_id")
			goc_card2.erase("instance_id")
			var goc_pending: Array = match_state.get("pending_player_choices", [])
			goc_pending.append({
				"player_id": goc_controller,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"prompt": "Guess which card your opponent has:",
				"mode": "card",
				"options": [{"label": str(goc_card1.get("name", "")), "card": goc_card1}, {"label": str(goc_card2.get("name", "")), "card": goc_card2}],
				"effects_per_option": [
					[{"op": "copy_card_to_hand", "card_template": goc_card1, "target_player": "controller"}],
					[{"op": "copy_card_to_hand", "card_template": goc_card2, "target_player": "controller"}],
				],
				"trigger": trigger.duplicate(true),
				"event": event.duplicate(true),
			})
			return {"handled": true, "events": [{"event_type": "player_choice_pending", "player_id": goc_controller}]}
		"opponent_gives_card_from_hand":
			var ogcfh_controller := str(trigger.get("controller_player_id", ""))
			var ogcfh_opponent := ""
			for player in match_state.get("players", []):
				if str(player.get("player_id", "")) != ogcfh_controller:
					ogcfh_opponent = str(player.get("player_id", ""))
					break
			var ogcfh_opp := _get_player_state(match_state, ogcfh_opponent)
			var ogcfh_my := _get_player_state(match_state, ogcfh_controller)
			if ogcfh_opp.is_empty() or ogcfh_my.is_empty():
				return {"handled": true, "events": []}
			var ogcfh_opp_hand: Array = ogcfh_opp.get("hand", [])
			if ogcfh_opp_hand.is_empty():
				return {"handled": true, "events": []}
			# Opponent gives cheapest card
			var ogcfh_idx := 0
			var ogcfh_min_cost := 999
			for i in range(ogcfh_opp_hand.size()):
				if typeof(ogcfh_opp_hand[i]) == TYPE_DICTIONARY:
					var c := int(ogcfh_opp_hand[i].get("cost", 0))
					if c < ogcfh_min_cost:
						ogcfh_min_cost = c
						ogcfh_idx = i
			var ogcfh_given: Dictionary = ogcfh_opp_hand[ogcfh_idx]
			ogcfh_opp_hand.remove_at(ogcfh_idx)
			ogcfh_given["zone"] = "hand"
			ogcfh_given["controller_player_id"] = ogcfh_controller
			ogcfh_my.get("hand", []).append(ogcfh_given)
			return {"handled": true, "events": [{"event_type": "card_given_from_opponent", "player_id": ogcfh_controller, "from_player_id": ogcfh_opponent, "instance_id": str(ogcfh_given.get("instance_id", ""))}]}
		"trade_hand_card_for_opponent_deck":
			var thcfod_controller := str(trigger.get("controller_player_id", ""))
			var thcfod_my := _get_player_state(match_state, thcfod_controller)
			if thcfod_my.is_empty():
				return {"handled": true, "events": []}
			var thcfod_hand: Array = thcfod_my.get("hand", [])
			if thcfod_hand.is_empty():
				return {"handled": true, "events": []}
			var thcfod_candidates: Array = []
			for card in thcfod_hand:
				if typeof(card) == TYPE_DICTIONARY:
					thcfod_candidates.append(str(card.get("instance_id", "")))
			var thcfod_pending: Array = match_state.get("pending_hand_selections", [])
			thcfod_pending.append({
				"player_id": thcfod_controller,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"candidate_instance_ids": thcfod_candidates,
				"prompt": "Choose a card to trade:",
				"then_op": "trade_for_opponent_deck",
				"then_context": {},
			})
			return {"handled": true, "events": [{"event_type": "hand_selection_pending", "player_id": thcfod_controller}]}
		"waves_of_the_fallen_choice":
			var wotf_controller := str(trigger.get("controller_player_id", ""))
			var wotf_lane_id := str(event.get("lane_id", "field"))
			var wotf_pending: Array = match_state.get("pending_player_choices", [])
			wotf_pending.append({
				"player_id": wotf_controller,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"prompt": "Waves of the Fallen:",
				"mode": "text",
				"options": [
					{"label": "Debuff Enemies", "description": "Set all enemy creatures in this lane to 2/2"},
					{"label": "Buff Friendlies", "description": "Set all friendly creatures in this lane to 5/5"},
				],
				"effects_per_option": [
					[{"op": "set_stats", "target": "all_enemies_in_event_lane", "power": 2, "health": 2}],
					[{"op": "set_stats", "target": "all_friendly_in_event_lane", "power": 5, "health": 5}],
				],
				"trigger": trigger.duplicate(true),
				"event": event.duplicate(true),
			})
			return {"handled": true, "events": [{"event_type": "player_choice_pending", "player_id": wotf_controller}]}
		"merchant_offer":
			var mo_controller := str(trigger.get("controller_player_id", ""))
			var mo_opponent := ""
			for player in match_state.get("players", []):
				if str(player.get("player_id", "")) != mo_controller:
					mo_opponent = str(player.get("player_id", ""))
					break
			var mo_seeds: Array = CardCatalog._card_seeds()
			var mo_collectible: Array = []
			for seed in mo_seeds:
				if typeof(seed) == TYPE_DICTIONARY and bool(seed.get("collectible", true)):
					mo_collectible.append(seed)
			if mo_collectible.size() < 2:
				return {"handled": true, "events": []}
			var mo_pick1_idx: int = _timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_mo1", mo_collectible.size())
			var mo_pick2_idx: int = _timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_mo2", mo_collectible.size())
			var mo_t1: Dictionary = mo_collectible[mo_pick1_idx].duplicate(true)
			mo_t1["definition_id"] = str(mo_t1.get("card_id", ""))
			var mo_t2: Dictionary = mo_collectible[mo_pick2_idx].duplicate(true)
			mo_t2["definition_id"] = str(mo_t2.get("card_id", ""))
			var mo_pending: Array = match_state.get("pending_player_choices", [])
			mo_pending.append({
				"player_id": mo_controller,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"prompt": "The Merchant has two cards for sale. Choose one:",
				"mode": "card",
				"options": [{"label": str(mo_t1.get("name", "")), "card": mo_t1}, {"label": str(mo_t2.get("name", "")), "card": mo_t2}],
				"effects_per_option": [
					[{"op": "generate_card_to_hand", "card_template": mo_t1, "target_player": "controller"}, {"op": "generate_card_to_hand", "card_template": mo_t2, "target_player": "opponent"}],
					[{"op": "generate_card_to_hand", "card_template": mo_t2, "target_player": "controller"}, {"op": "generate_card_to_hand", "card_template": mo_t1, "target_player": "opponent"}],
				],
				"trigger": trigger.duplicate(true),
				"event": event.duplicate(true),
			})
			return {"handled": true, "events": [{"event_type": "player_choice_pending", "player_id": mo_controller}]}
		"transform_deck_to_dragons":
			var ttd_controller := str(trigger.get("controller_player_id", ""))
			var ttd_player := _get_player_state(match_state, ttd_controller)
			if ttd_player.is_empty():
				return {"handled": true, "events": []}
			var ttd_deck: Array = ttd_player.get("deck", [])
			var ttd_seeds: Array = CardCatalog._card_seeds()
			var ttd_dragons: Array = []
			for seed in ttd_seeds:
				if typeof(seed) == TYPE_DICTIONARY:
					var subtypes: Array = seed.get("subtypes", [])
					if typeof(subtypes) == TYPE_ARRAY and subtypes.has("Dragon"):
						ttd_dragons.append(seed)
			if ttd_dragons.is_empty():
				return {"handled": true, "events": []}
			for di in range(ttd_deck.size()):
				var card: Dictionary = ttd_deck[di]
				if typeof(card) != TYPE_DICTIONARY or str(card.get("card_type", "")) != "creature":
					continue
				var pick: Variant = ttd_dragons[_timing_rules()._deterministic_index(match_state, str(card.get("instance_id", "")) + "_ttd", ttd_dragons.size())]
				var template: Dictionary = pick.duplicate(true)
				template["definition_id"] = str(template.get("card_id", ""))
				MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), template, {"reason": "transform_deck_to_dragons"})
			return {"handled": true, "events": [{"event_type": "deck_transformed_to_dragons", "player_id": ttd_controller}]}
		"apply_cost_reduction_aura":
			var acra_controller := str(trigger.get("controller_player_id", ""))
			var acra_filter_raw = effect.get("filter", {})
			var acra_filter: Dictionary = acra_filter_raw if typeof(acra_filter_raw) == TYPE_DICTIONARY else {}
			var acra_amount := int(effect.get("amount", 1))
			var acra_filter_subtype := str(acra_filter.get("subtype", ""))
			# Store as a persistent aura on the match state
			var acra_auras: Array = match_state.get("card_cost_reduction_auras", [])
			acra_auras.append({"controller_player_id": acra_controller, "filter_subtype": acra_filter_subtype, "amount": acra_amount, "source_instance_id": str(trigger.get("source_instance_id", ""))})
			match_state["card_cost_reduction_auras"] = acra_auras
			return {"handled": true, "events": [{"event_type": "cost_reduction_aura_applied", "player_id": acra_controller, "filter_subtype": acra_filter_subtype, "amount": acra_amount}]}
		"look_at_top_deck_may_discard_then_draw":
			var ltdmd_td_controller := str(trigger.get("controller_player_id", ""))
			var ltdmd_td_player := _get_player_state(match_state, ltdmd_td_controller)
			if ltdmd_td_player.is_empty():
				return {"handled": true, "events": []}
			var ltdmd_td_deck: Array = ltdmd_td_player.get("deck", [])
			# Look at top, may discard (AI always discards non-creatures for simplicity)
			if not ltdmd_td_deck.is_empty():
				var ltdmd_td_top: Dictionary = ltdmd_td_deck.back()
				if typeof(ltdmd_td_top) == TYPE_DICTIONARY and str(ltdmd_td_top.get("card_type", "")) != "creature":
					ltdmd_td_deck.pop_back()
					ltdmd_td_top["zone"] = "discard"
					var ltdmd_td_discard: Array = ltdmd_td_player.get("discard", [])
					ltdmd_td_discard.append(ltdmd_td_top)
			# Then draw
			if not ltdmd_td_deck.is_empty():
				var ltdmd_td_drawn: Dictionary = ltdmd_td_deck.pop_back()
				ltdmd_td_drawn["zone"] = "hand"
				var ltdmd_td_hand: Array = ltdmd_td_player.get("hand", [])
				ltdmd_td_hand.append(ltdmd_td_drawn)
				return {"handled": true, "events": [{"event_type": "card_drawn", "player_id": ltdmd_td_controller, "instance_id": str(ltdmd_td_drawn.get("instance_id", "")), "source": "look_then_draw"}]}
			return {"handled": true, "events": []}
		"steal_top_deck_card":
			var stdc_controller := str(trigger.get("controller_player_id", ""))
			var stdc_opponent := ""
			for player in match_state.get("players", []):
				if str(player.get("player_id", "")) != stdc_controller:
					stdc_opponent = str(player.get("player_id", ""))
					break
			var stdc_opp_player := _get_player_state(match_state, stdc_opponent)
			var stdc_my_player := _get_player_state(match_state, stdc_controller)
			if stdc_opp_player.is_empty() or stdc_my_player.is_empty():
				return {"handled": true, "events": []}
			var stdc_opp_deck: Array = stdc_opp_player.get("deck", [])
			if stdc_opp_deck.is_empty():
				return {"handled": true, "events": []}
			var stdc_stolen: Dictionary = stdc_opp_deck.pop_back()
			stdc_stolen["zone"] = "hand"
			stdc_stolen["controller_player_id"] = stdc_controller
			var stdc_hand: Array = stdc_my_player.get("hand", [])
			stdc_hand.append(stdc_stolen)
			return {"handled": true, "events": [{"event_type": "card_stolen_from_deck", "player_id": stdc_controller, "from_player_id": stdc_opponent, "instance_id": str(stdc_stolen.get("instance_id", ""))}]}
		"generate_random_shouts_to_hand":
			var grsh_controller := str(trigger.get("controller_player_id", ""))
			var grsh_player := _get_player_state(match_state, grsh_controller)
			if grsh_player.is_empty():
				return {"handled": true, "events": []}
			var grsh_count := int(effect.get("count", 3))
			var grsh_set_cost: Variant = effect.get("set_cost", null)
			var grsh_seeds: Array = CardCatalog._card_seeds()
			var grsh_shouts: Array = []
			for seed in grsh_seeds:
				if typeof(seed) == TYPE_DICTIONARY:
					var tags: Array = seed.get("rules_tags", [])
					if typeof(tags) == TYPE_ARRAY and tags.has("shout") and int(seed.get("shout_level", 0)) == 1:
						grsh_shouts.append(seed)
			var grsh_events: Array = []
			var grsh_hand: Array = grsh_player.get("hand", [])
			for i in range(grsh_count):
				if grsh_shouts.is_empty():
					break
				var pick_idx: int = _timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_grsh_" + str(i), grsh_shouts.size())
				var grsh_pick: Dictionary = grsh_shouts[pick_idx]
				var grsh_template: Dictionary = grsh_pick.duplicate(true)
				grsh_template["definition_id"] = str(grsh_template.get("card_id", ""))
				if grsh_set_cost != null:
					grsh_template["cost"] = int(grsh_set_cost)
				var grsh_card := MatchMutations.build_generated_card(match_state, grsh_controller, grsh_template)
				grsh_card["zone"] = "hand"
				grsh_hand.append(grsh_card)
				grsh_events.append({"event_type": "card_generated_to_hand", "player_id": grsh_controller, "instance_id": str(grsh_card.get("instance_id", ""))})
			return {"handled": true, "events": grsh_events}
		"win_game_if_all_attributes":
			var wgiaa_controller := str(trigger.get("controller_player_id", ""))
			var wgiaa_found: Dictionary = {}
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(wgiaa_controller, []):
					if typeof(card) == TYPE_DICTIONARY:
						for attr in card.get("attributes", []):
							wgiaa_found[str(attr)] = true
			var wgiaa_all := wgiaa_found.has("strength") and wgiaa_found.has("intelligence") and wgiaa_found.has("willpower") and wgiaa_found.has("agility") and wgiaa_found.has("endurance")
			if wgiaa_all:
				match_state["winner_player_id"] = wgiaa_controller
				match_state["win_reason"] = "unite_the_houses"
				return {"handled": true, "events": [{"event_type": "game_won", "player_id": wgiaa_controller, "reason": "all_attributes_in_play"}]}
			return {"handled": true, "events": []}
		"check_win_condition":
			var cwc_condition := str(effect.get("condition", ""))
			var cwc_controller := str(trigger.get("controller_player_id", ""))
			if cwc_condition == "both_lanes_have_friendly":
				var cwc_lanes_with_friendly := 0
				for lane in match_state.get("lanes", []):
					var cwc_slots: Array = lane.get("player_slots", {}).get(cwc_controller, [])
					for card in cwc_slots:
						if typeof(card) == TYPE_DICTIONARY:
							cwc_lanes_with_friendly += 1
							break
				if cwc_lanes_with_friendly >= 2:
					match_state["winner_player_id"] = cwc_controller
					match_state["win_reason"] = "check_win_condition"
					return {"handled": true, "events": [{"event_type": "game_won", "player_id": cwc_controller, "reason": "both_lanes_have_friendly"}]}
			return {"handled": true, "events": []}
		"summon_conditional_atronach":
			var sca_controller := str(trigger.get("controller_player_id", ""))
			var sca_condition_raw = effect.get("condition", {})
			var sca_condition: Dictionary = sca_condition_raw if typeof(sca_condition_raw) == TYPE_DICTIONARY else {}
			var sca_min_power := int(sca_condition.get("required_friendly_creature_min_power", 0))
			var sca_has_condition := false
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(sca_controller, []):
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules.get_power(card) >= sca_min_power:
						sca_has_condition = true
						break
				if sca_has_condition:
					break
			var sca_lane_id := str(event.get("lane_id", "field"))
			var sca_events: Array = []
			if sca_has_condition:
				var sca_template_raw = effect.get("on_met", {})
				var sca_template: Dictionary = sca_template_raw if typeof(sca_template_raw) == TYPE_DICTIONARY else {}
				var sca_card := MatchMutations.build_generated_card(match_state, sca_controller, sca_template)
				var sca_summon := MatchMutations.summon_card_to_lane(match_state, sca_controller, sca_card, sca_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
				if bool(sca_summon.get("is_valid", false)):
					sca_events.append_array(sca_summon.get("events", []))
					sca_events.append(_timing_rules()._build_summon_event(sca_summon["card"], sca_controller, sca_lane_id, int(sca_summon.get("slot_index", -1)), "summon_conditional_atronach"))
					_timing_rules()._check_summon_abilities(match_state, sca_summon["card"])
			else:
				var sca_unmet_raw = effect.get("on_unmet", {})
				var sca_unmet: Dictionary = sca_unmet_raw if typeof(sca_unmet_raw) == TYPE_DICTIONARY else {}
				var sca_filter: Dictionary = sca_unmet.get("filter", {}) if typeof(sca_unmet.get("filter", {})) == TYPE_DICTIONARY else {}
				var sca_custom_result := apply_custom_effect(match_state, trigger, event, {"op": "summon_random_from_catalog", "filter": {"card_type": "creature", "required_subtype": str(sca_filter.get("subtype", "Atronach"))}})
				sca_events.append_array(sca_custom_result.get("events", []))
			return {"handled": true, "events": sca_events}
		"summon_imposter":
			var si_controller := str(trigger.get("controller_player_id", ""))
			var si_best_power := 0
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(si_controller, []):
					if typeof(card) == TYPE_DICTIONARY:
						var p := EvergreenRules.get_power(card)
						if p > si_best_power:
							si_best_power = p
			var si_template := {"definition_id": "hom_str_imposter", "name": "Imposter", "card_type": "creature", "subtypes": [], "attributes": ["strength"], "cost": si_best_power, "power": si_best_power, "health": si_best_power, "base_power": si_best_power, "base_health": si_best_power, "rules_text": ""}
			var si_card := MatchMutations.build_generated_card(match_state, si_controller, si_template)
			var si_lane_id := str(event.get("lane_id", "field"))
			var si_summon := MatchMutations.summon_card_to_lane(match_state, si_controller, si_card, si_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
			if bool(si_summon.get("is_valid", false)):
				var si_events: Array = si_summon.get("events", []).duplicate()
				si_events.append(_timing_rules()._build_summon_event(si_summon["card"], si_controller, si_lane_id, int(si_summon.get("slot_index", -1)), "summon_imposter"))
				return {"handled": true, "events": si_events}
			return {"handled": true, "events": []}
		"lockpick_gamble":
			var lg_controller_id := str(trigger.get("controller_player_id", ""))
			var lg_player := _get_player_state(match_state, lg_controller_id)
			if lg_player.is_empty():
				return {"handled": true, "events": []}
			var lg_roll: int = _timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_lockpick", 2)
			if lg_roll == 0:
				# Success: put another Lockpick into hand with +1 cost
				var lg_template := {"definition_id": "hos_agi_lockpick", "name": "Lockpick", "card_type": "action", "attributes": ["agility"], "cost": 3, "power": 0, "health": 0, "base_power": 0, "base_health": 0, "rules_text": "50% chance: Put another Lockpick into your hand. 50% chance: Draw a card and reduce its cost by 2.", "triggered_abilities": [{"family": "on_play", "effects": [{"op": "lockpick_gamble"}]}]}
				var lg_card := MatchMutations.build_generated_card(match_state, lg_controller_id, lg_template)
				lg_card["zone"] = "hand"
				var lg_hand: Array = lg_player.get("hand", [])
				lg_hand.append(lg_card)
				return {"handled": true, "events": [{"event_type": "lockpick_success", "player_id": lg_controller_id}]}
			else:
				# Fail: draw a card and reduce its cost by 2
				var lg_deck: Array = lg_player.get("deck", [])
				if lg_deck.is_empty():
					return {"handled": true, "events": [{"event_type": "lockpick_fail_empty_deck", "player_id": lg_controller_id}]}
				var lg_drawn: Dictionary = lg_deck.pop_back()
				lg_drawn["zone"] = "hand"
				var lg_current_cost := int(lg_drawn.get("cost", 0))
				lg_drawn["cost"] = maxi(0, lg_current_cost - 2)
				var lg_hand: Array = lg_player.get("hand", [])
				lg_hand.append(lg_drawn)
				return {"handled": true, "events": [{"event_type": "lockpick_fail_draw", "player_id": lg_controller_id, "instance_id": str(lg_drawn.get("instance_id", "")), "cost_reduced_by": 2}]}
		# --- Boon Ops ---
		"boon_marked_for_death":
			var bmd_stacks := int(effect.get("stacks", 1))
			var bmd_effect := {"target_player": "opponent", "amount": bmd_stacks}
			return {"handled": true, "events": _resolve_player_damage(match_state, trigger, event, bmd_effect, bmd_stacks)}
		"boon_soul_tear":
			var bst_controller_id := str(trigger.get("controller_player_id", ""))
			var bst_player := _get_player_state(match_state, bst_controller_id)
			if bst_player.is_empty():
				return {"handled": true, "events": []}
			var bst_destroyed_id := str(event.get("source_instance_id", event.get("instance_id", "")))
			var bst_destroyed := _find_card_anywhere(match_state, bst_destroyed_id)
			var bst_cost := int(bst_destroyed.get("cost", 1)) if not bst_destroyed.is_empty() else 1
			var bst_candidates: Array = []
			for bst_seed in CardCatalog._card_seeds():
				if typeof(bst_seed) != TYPE_DICTIONARY:
					continue
				if not bool(bst_seed.get("collectible", true)):
					continue
				if str(bst_seed.get("card_type", "")) != "creature":
					continue
				if int(bst_seed.get("cost", 0)) != bst_cost:
					continue
				bst_candidates.append(bst_seed)
			if bst_candidates.is_empty():
				return {"handled": true, "events": []}
			var bst_pick: Dictionary = bst_candidates[_timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_bst_" + bst_destroyed_id, bst_candidates.size())]
			var bst_template := bst_pick.duplicate(true)
			bst_template["definition_id"] = str(bst_template.get("card_id", ""))
			var bst_hand: Array = bst_player.get(MatchMutations.ZONE_HAND, [])
			if bst_hand.size() >= MatchTiming.MAX_HAND_SIZE:
				return {"handled": true, "events": []}
			var bst_gen := MatchMutations.build_generated_card(match_state, bst_controller_id, bst_template)
			bst_gen["zone"] = MatchMutations.ZONE_HAND
			bst_hand.append(bst_gen)
			return {"handled": true, "events": [{"event_type": "card_drawn", "player_id": bst_controller_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "drawn_instance_id": str(bst_gen.get("instance_id", "")), "source_zone": MatchMutations.ZONE_GENERATED, "target_zone": MatchMutations.ZONE_HAND, "reason": "soul_tear"}]}
		"boon_first_lesson":
			var bfl_stacks := int(effect.get("stacks", 1))
			var bfl_controller_id := str(trigger.get("controller_player_id", ""))
			var bfl_player := _get_player_state(match_state, bfl_controller_id)
			if not bfl_player.is_empty():
				bfl_player["_first_lesson_discount"] = bfl_stacks
			return {"handled": true, "events": []}
		"boon_battleground":
			var bb_controller_id := str(trigger.get("controller_player_id", ""))
			var bb_lane_id := str(event.get("lane_id", ""))
			if bb_lane_id != "field":
				return {"handled": true, "events": []}
			var bb_creature_id := str(event.get("source_instance_id", ""))
			if bb_creature_id.is_empty():
				return {"handled": true, "events": []}
			var bb_events: Array = []
			for bb_lane in match_state.get("lanes", []):
				if str(bb_lane.get("lane_id", "")) != "field":
					continue
				for bb_card in bb_lane.get("player_slots", {}).get(bb_controller_id, []):
					if typeof(bb_card) == TYPE_DICTIONARY and str(bb_card.get("instance_id", "")) == bb_creature_id:
						EvergreenRules.grant_cover(bb_card, int(match_state.get("turn_number", 0)) + 1, "battleground")
						bb_events.append({"event_type": "status_granted", "source_instance_id": bb_creature_id, "target_instance_id": bb_creature_id, "status_id": "cover"})
						break
				break
			return {"handled": true, "events": bb_events}
		"boon_shattered_fate":
			var bsf_stacks := int(effect.get("stacks", 1))
			var bsf_controller_id := str(trigger.get("controller_player_id", ""))
			var bsf_creature_id := str(event.get("source_instance_id", ""))
			if bsf_creature_id.is_empty():
				return {"handled": true, "events": []}
			if not bool(event.get("played_for_free", false)) and str(event.get("reason", "")) != "prophecy":
				return {"handled": true, "events": []}
			var bsf_events: Array = []
			for bsf_lane in match_state.get("lanes", []):
				for bsf_card in bsf_lane.get("player_slots", {}).get(bsf_controller_id, []):
					if typeof(bsf_card) == TYPE_DICTIONARY and str(bsf_card.get("instance_id", "")) == bsf_creature_id:
						EvergreenRules.apply_stat_bonus(bsf_card, bsf_stacks, bsf_stacks, "shattered_fate")
						bsf_events.append({"event_type": "creature_stats_changed", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": bsf_creature_id, "bonus_power": bsf_stacks, "bonus_health": bsf_stacks})
						break
			return {"handled": true, "events": bsf_events}
		"boon_harbingers_call":
			var hc_stacks := int(effect.get("stacks", 1))
			var hc_controller_id := str(trigger.get("controller_player_id", ""))
			var hc_has_friendly := false
			for hc_lane in match_state.get("lanes", []):
				var hc_slots = hc_lane.get("player_slots", {}).get(hc_controller_id, [])
				if typeof(hc_slots) == TYPE_ARRAY and not hc_slots.is_empty():
					hc_has_friendly = true
					break
			if hc_has_friendly:
				return {"handled": true, "events": []}
			var hc_candidates: Array = []
			for hc_seed in CardCatalog._card_seeds():
				if typeof(hc_seed) != TYPE_DICTIONARY:
					continue
				if not bool(hc_seed.get("collectible", true)):
					continue
				if str(hc_seed.get("card_type", "")) != "creature":
					continue
				if int(hc_seed.get("cost", 0)) != hc_stacks:
					continue
				hc_candidates.append(hc_seed)
			if hc_candidates.is_empty():
				return {"handled": true, "events": []}
			var hc_pick: Dictionary = hc_candidates[_timing_rules()._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_hc", hc_candidates.size())]
			var hc_template := hc_pick.duplicate(true)
			hc_template["definition_id"] = str(hc_template.get("card_id", ""))
			var hc_gen := MatchMutations.build_generated_card(match_state, hc_controller_id, hc_template)
			var hc_result := MatchMutations.summon_card_to_lane(match_state, hc_controller_id, hc_gen, "field", {"source_zone": MatchMutations.ZONE_GENERATED})
			if not bool(hc_result.get("is_valid", false)):
				hc_result = MatchMutations.summon_card_to_lane(match_state, hc_controller_id, hc_gen, "shadow", {"source_zone": MatchMutations.ZONE_GENERATED})
			if not bool(hc_result.get("is_valid", false)):
				return {"handled": true, "events": []}
			var hc_events: Array = hc_result.get("events", []).duplicate()
			hc_events.append(_timing_rules()._build_summon_event(hc_result["card"], hc_controller_id, "field", int(hc_result.get("slot_index", -1)), "harbingers_call"))
			_timing_rules()._check_summon_abilities(match_state, hc_result["card"])
			return {"handled": true, "events": hc_events}
		"boon_holy_ground":
			var hg_stacks := int(effect.get("stacks", 1))
			var hg_controller_id := str(trigger.get("controller_player_id", ""))
			var hg_events: Array = []
			for hg_lane in match_state.get("lanes", []):
				if str(hg_lane.get("lane_id", "")) != "field":
					continue
				for hg_card in hg_lane.get("player_slots", {}).get(hg_controller_id, []):
					if typeof(hg_card) != TYPE_DICTIONARY:
						continue
					EvergreenRules.apply_stat_bonus(hg_card, 0, hg_stacks, "holy_ground")
					hg_events.append({"event_type": "creature_stats_changed", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(hg_card.get("instance_id", "")), "bonus_power": 0, "bonus_health": hg_stacks})
				break
			return {"handled": true, "events": hg_events}
		"boon_runic_ward":
			var rw_controller_id := str(trigger.get("controller_player_id", ""))
			var rw_player := _get_player_state(match_state, rw_controller_id)
			if rw_player.is_empty():
				return {"handled": true, "events": []}
			var rw_charges := int(rw_player.get("_runic_ward_charges", 0))
			if rw_charges <= 0:
				return {"handled": true, "events": []}
			rw_player["_runic_ward_charges"] = rw_charges - 1
			var rw_template := {}
			for rw_seed in CardCatalog._card_seeds():
				if typeof(rw_seed) == TYPE_DICTIONARY and str(rw_seed.get("card_id", "")) == "int_camlorn_sentinel":
					rw_template = rw_seed.duplicate(true)
					rw_template["definition_id"] = str(rw_seed.get("card_id", ""))
					break
			rw_template["generated_by_rules"] = true
			var rw_gen := MatchMutations.build_generated_card(match_state, rw_controller_id, rw_template)
			var rw_result := MatchMutations.summon_card_to_lane(match_state, rw_controller_id, rw_gen, "field", {"source_zone": MatchMutations.ZONE_GENERATED})
			if not bool(rw_result.get("is_valid", false)):
				rw_result = MatchMutations.summon_card_to_lane(match_state, rw_controller_id, rw_gen, "shadow", {"source_zone": MatchMutations.ZONE_GENERATED})
			if not bool(rw_result.get("is_valid", false)):
				return {"handled": true, "events": []}
			var rw_events: Array = rw_result.get("events", []).duplicate()
			rw_events.append(_timing_rules()._build_summon_event(rw_result["card"], rw_controller_id, "field", int(rw_result.get("slot_index", -1)), "runic_ward"))
			return {"handled": true, "events": rw_events}
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


static func _resolve_shout_upgrade(match_state: Dictionary, trigger: Dictionary, upgrade_all: bool = false) -> Array:
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	if source_card.is_empty():
		return []
	var controller_id := str(trigger.get("controller_player_id", ""))
	var events: Array = []
	var source_instance_id := str(trigger.get("source_instance_id", ""))
	if upgrade_all:
		# Upgrade ALL shouts owned by the player (e.g. Call Dragon), excluding the source card itself
		for card in _collect_owned_cards(match_state, controller_id, [ZONE_HAND, ZONE_DECK, ZONE_DISCARD]):
			if str(card.get("instance_id", "")) == source_instance_id:
				continue
			var card_levels = card.get("shout_levels", [])
			if typeof(card_levels) != TYPE_ARRAY or card_levels.is_empty():
				continue
			var card_current_level := maxi(1, int(card.get("shout_level", 1)))
			if card_current_level >= card_levels.size():
				continue
			var card_next_level := card_current_level + 1
			var card_next_template = card_levels[card_next_level - 1]
			if typeof(card_next_template) != TYPE_DICTIONARY:
				continue
			var card_chain_id := str(card.get("shout_chain_id", card.get("definition_id", "")))
			var enriched_template: Dictionary = card_next_template.duplicate(true)
			enriched_template["shout_levels"] = card_levels.duplicate(true)
			if not enriched_template.has("shout_chain_id"):
				enriched_template["shout_chain_id"] = card_chain_id
			var prev_cost := int(card.get("cost", 0))
			var change_result := MatchMutations.change_card(card, enriched_template, {"reason": "shout_upgrade"})
			card["cost"] = prev_cost
			if enriched_template.has("art_path"):
				card["art_path"] = str(enriched_template.get("art_path", ""))
			events.append_array(change_result.get("events", []))
	else:
		# Upgrade only copies of the same shout chain
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
		for card in _collect_owned_cards(match_state, controller_id, [ZONE_HAND, ZONE_DECK, ZONE_DISCARD]):
			if str(card.get("shout_chain_id", card.get("definition_id", ""))) != shout_chain_id:
				continue
			var prev_cost := int(card.get("cost", 0))
			var change_result := MatchMutations.change_card(card, enriched_template, {"reason": "shout_upgrade"})
			card["cost"] = prev_cost
			if enriched_template.has("art_path"):
				card["art_path"] = str(enriched_template.get("art_path", ""))
			events.append_array(change_result.get("events", []))
	return events


static func _resolve_invade(match_state: Dictionary, trigger: Dictionary) -> Array:
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	# Tag invade events triggered by on_invade (e.g. Keeper of the Gates) so they
	# don't re-trigger on_invade, preventing infinite recursion.
	var from_on_invade := str(trigger.get("descriptor", {}).get("family", "")) == "on_invade"
	var invade_event := {
		"event_type": "invade_triggered",
		"player_id": controller_player_id,
		"controller_player_id": controller_player_id,
	}
	if from_on_invade:
		invade_event["from_on_invade"] = true
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
		invade_event["gate_instance_id"] = str(gate_card.get("instance_id", ""))
		invade_event["gate_level"] = 1
		events.append(invade_event)
		return events
	var next_level := mini(5, maxi(1, int(gate.get("gate_level", 1)) + 1))
	var change_result := MatchMutations.change_card(gate, _build_gate_template(next_level), {"reason": "invade"})
	gate["gate_level"] = next_level
	gate["cannot_attack"] = true
	var generated_events: Array = change_result.get("events", []).duplicate(true)
	generated_events.append({
		"event_type": "oblivion_gate_upgraded",
		"source_instance_id": str(gate.get("instance_id", "")),
		"gate_level": next_level,
	})
	# Apply Daedra cost reduction aura when reaching level 3
	if next_level == 3:
		var auras: Array = match_state.get("card_cost_reduction_auras", [])
		auras.append({"controller_player_id": controller_player_id, "filter_subtype": "Daedra", "amount": 1, "source_instance_id": str(gate.get("instance_id", ""))})
		match_state["card_cost_reduction_auras"] = auras
		generated_events.append({"event_type": "cost_reduction_aura_applied", "player_id": controller_player_id, "filter_subtype": "Daedra", "amount": 1})
	invade_event["gate_instance_id"] = str(gate.get("instance_id", ""))
	invade_event["gate_level"] = next_level
	generated_events.append(invade_event)
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
	var keyword_count := clampi(int(gate.get("gate_level", 1)) - 3, 0, 2)
	for keyword_id in _choose_gate_keywords(match_state, target, keyword_count):
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


static func _count_source_multiplier(match_state: Dictionary, trigger: Dictionary, effect: Dictionary) -> int:
	var count_source := str(effect.get("count_source", ""))
	if count_source.is_empty():
		return 1
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var count := 0
	match count_source:
		"friendly_creatures":
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(controller_player_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						count += 1
		_:
			return 1
	return maxi(count, 1)


static func _resolve_player_damage(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary, amount: int) -> Array:
	if amount <= 0:
		return []
	var events: Array = []
	for player_id in _resolve_player_targets(match_state, event, effect, str(trigger.get("controller_player_id", "")), trigger):
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
	var gate_level := clampi(level, 1, 5)
	return {
		"definition_id": "generated_oblivion_gate",
		"name": "Oblivion Gate",
		"art_path": "res://assets/images/cards/joo_neu_oblivion_gate.png",
		"card_type": "creature",
		"cost": 3,
		"power": 0,
		"health": 4 + (gate_level - 1) * 2,
		"subtypes": ["Portal"],
		"attributes": ["neutral"],
		"gate_level": gate_level,
		"cannot_attack": true,
		"grants_immunity": ["silence"],
		"innate_statuses": ["permanent_shackle"],
		"rules_tags": [RULE_TAG_OBLIVION_GATE],
		"rules_text": _gate_rules_text(gate_level),
		"triggered_abilities": [{
			"id": "oblivion_gate_buff",
			"event_type": EVENT_CREATURE_SUMMONED,
			"match_role": "controller",
			"required_zone": ZONE_LANE,
			"required_event_source_subtype": "Daedra",
			"excluded_event_source_rule_tag": RULE_TAG_OBLIVION_GATE,
			"effects": [{"op": "buff_oblivion_gate_summon", "target": "event_source"}],
		}],
	}


static func _gate_rules_text(level: int) -> String:
	var text := "Immune to Silence. Permanently Shackled. When you summon a Daedra, give it "
	if level <= 1:
		text += "+0/+1."
	else:
		text += "+1/+1."
	if level >= 3:
		text += " Daedra you summon cost 1 less."
	if level == 4:
		text += " When you summon a Daedra, give it a random keyword."
	elif level >= 5:
		text += " When you summon a Daedra, give it two random keywords."
	return text


static func _find_player_gate(match_state: Dictionary, player_id: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != SHADOW_LANE_ID:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and _card_has_string(card, "rules_tags", RULE_TAG_OBLIVION_GATE):
				return card
	return {}


static func _choose_gate_keywords(match_state: Dictionary, card: Dictionary, count: int) -> Array:
	if count <= 0:
		return []
	var candidates: Array = []
	for keyword_id in GATE_KEYWORD_POOL:
		if not EvergreenRules.has_keyword(card, keyword_id):
			candidates.append(keyword_id)
	var picks: Array = []
	for i in range(mini(count, candidates.size())):
		var idx: int = _timing_rules()._deterministic_index(match_state, str(card.get("instance_id", "")) + "_gate_kw_%d" % i, candidates.size())
		picks.append(candidates[idx])
		candidates.remove_at(idx)
	return picks


static func _collect_factotums(match_state: Dictionary, player_id: String, source_instance_id: String) -> Array:
	var cards: Array = []
	var source_card := _find_card_anywhere(match_state, source_instance_id)
	if not source_card.is_empty():
		cards.append(source_card)
	for card in _collect_owned_cards(match_state, player_id, [ZONE_HAND, ZONE_DECK]):
		if _card_has_string(card, "subtypes", "Factotum") or _card_has_string(card, "subtypes", "factotum"):
			cards.append(card)
	return cards


static func _collect_factotums_except_self(match_state: Dictionary, player_id: String, source_instance_id: String) -> Array:
	var cards: Array = []
	for card in _collect_owned_cards(match_state, player_id, [ZONE_HAND, ZONE_DECK]):
		if str(card.get("instance_id", "")) == source_instance_id:
			continue
		if _card_has_string(card, "subtypes", "Factotum") or _card_has_string(card, "subtypes", "factotum"):
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


static func _resolve_player_targets(match_state: Dictionary, event: Dictionary, effect: Dictionary, controller_player_id: String, trigger: Dictionary = {}) -> Array:
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
		"chosen_target_player":
			var chosen_pid := str(trigger.get("_chosen_target_player_id", ""))
			return [] if chosen_pid.is_empty() else [chosen_pid]
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


static func _resolve_gain_magicka_count(match_state: Dictionary, trigger: Dictionary, effect: Dictionary) -> int:
	var count_source := str(effect.get("count_source", ""))
	if count_source.is_empty():
		return 1
	var controller_id := str(trigger.get("controller_player_id", ""))
	match count_source:
		"enemy_creatures_same_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index < 0 or lane_index >= lanes.size():
				return 0
			var opponent_id := ""
			for player in match_state.get("players", []):
				if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != controller_id:
					opponent_id = str(player.get("player_id", ""))
					break
			var count := 0
			for card in lanes[lane_index].get("player_slots", {}).get(opponent_id, []):
				if typeof(card) == TYPE_DICTIONARY:
					count += 1
			return count
	return 1


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
		"modify_card_cost":
			var cost_amount := int(then_context.get("amount", 0))
			var original_cost := int(chosen_card.get("cost", 0))
			chosen_card["cost"] = maxi(0, original_cost + cost_amount)
			if not chosen_card.has("_base_cost"):
				chosen_card["_base_cost"] = original_cost
			return [{"event_type": "card_cost_modified", "source_instance_id": source_instance_id, "target_instance_id": str(chosen_card.get("instance_id", "")), "player_id": player_id, "amount": cost_amount}]
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
		"trade_for_opponent_deck":
			var tfo_opponent := ""
			for player in match_state.get("players", []):
				if str(player.get("player_id", "")) != player_id:
					tfo_opponent = str(player.get("player_id", ""))
					break
			var tfo_opp := _get_player_state(match_state, tfo_opponent)
			if tfo_opp.is_empty():
				return []
			var tfo_opp_deck: Array = tfo_opp.get("deck", [])
			if tfo_opp_deck.is_empty():
				return []
			# Discard the chosen card
			var tfo_my := _get_player_state(match_state, player_id)
			var tfo_hand: Array = tfo_my.get("hand", [])
			var tfo_chosen_idx := -1
			for i in range(tfo_hand.size()):
				if typeof(tfo_hand[i]) == TYPE_DICTIONARY and str(tfo_hand[i].get("instance_id", "")) == str(chosen_card.get("instance_id", "")):
					tfo_chosen_idx = i
					break
			if tfo_chosen_idx >= 0:
				var tfo_removed: Dictionary = tfo_hand[tfo_chosen_idx]
				tfo_hand.remove_at(tfo_chosen_idx)
				tfo_removed["zone"] = "discard"
				tfo_my.get("discard", []).append(tfo_removed)
			# Draw random from opponent deck
			var tfo_pick_idx: int = _timing_rules()._deterministic_index(match_state, source_instance_id + "_barter", tfo_opp_deck.size())
			var tfo_gained: Dictionary = tfo_opp_deck[tfo_pick_idx]
			tfo_opp_deck.remove_at(tfo_pick_idx)
			tfo_gained["zone"] = "hand"
			tfo_gained["controller_player_id"] = player_id
			tfo_hand.append(tfo_gained)
			return [{"event_type": "card_traded", "player_id": player_id, "discarded_id": str(chosen_card.get("instance_id", "")), "gained_id": str(tfo_gained.get("instance_id", ""))}]
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
		var prev_cost := int(card.get("cost", 0))
		var change_result := MatchMutations.change_card(card, enriched_template, {"reason": "shout_upgrade"})
		card["cost"] = prev_cost
		if enriched_template.has("art_path"):
			card["art_path"] = str(enriched_template.get("art_path", ""))
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
				if _card_matches_target_mode(action_target_mode, card, player_id, match_state, action_card):
					return true
	if action_target_mode == "creature_or_player" or action_target_mode == "any_creature_or_player":
		return true
	return false


static func _card_matches_target_mode(target_mode: String, card: Dictionary, controller_player_id: String, match_state: Dictionary = {}, source_card: Dictionary = {}) -> bool:
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
			return EvergreenRules.has_status(card, EvergreenRules.STATUS_WOUNDED)
		"enemy_support_or_neutral_creature":
			if card_controller == controller_player_id:
				return false
			var attrs: Array = card.get("attributes", [])
			return typeof(attrs) == TYPE_ARRAY and attrs.has("neutral")
		"enemy_creature_or_support":
			return card_controller != controller_player_id
		"creature_1_power_or_less":
			var c1pol_max := 1
			var c1pol_empower := int(source_card.get("_empower_target_bonus", 0))
			if c1pol_empower > 0 and not match_state.is_empty():
				var c1pol_player := _get_player_state(match_state, controller_player_id)
				if not c1pol_player.is_empty():
					ensure_player_state(c1pol_player)
					c1pol_max += c1pol_empower * (int(c1pol_player.get("empower_count_this_turn", 0)) + int(c1pol_player.get("_permanent_empower_accumulated", 0)))
			return EvergreenRules.get_power(card) <= c1pol_max
		"creature_4_power_or_less":
			return EvergreenRules.get_power(card) <= 4
		"creature_4_power_or_more":
			return EvergreenRules.get_power(card) >= 4
		"creature_with_0_power":
			return EvergreenRules.get_power(card) == 0
		"enemy_creature_3_power_or_less":
			return card_controller != controller_player_id and EvergreenRules.get_power(card) <= 3
		"creature_in_other_lane":
			return true
		"friendly_creature_without_guard":
			return card_controller == controller_player_id and not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD)
		"enemy_creature_optional":
			return card_controller != controller_player_id
		"another_friendly_creature_optional":
			return card_controller == controller_player_id
		"any_creature_or_player":
			return true
		"enemy_creature_less_power_than_self_health":
			return card_controller != controller_player_id
		"two_creatures", "three_creatures":
			return true
		"creature_in_hand":
			return true
		"opponent_discard_card":
			return card_controller != controller_player_id
		"choose_lane_and_owner":
			return true
		"friendly_creature_with_3_items":
			if card_controller != controller_player_id:
				return false
			var items = card.get("attached_items", [])
			return typeof(items) == TYPE_ARRAY and items.size() >= 3
		"another_creature_with_cover":
			return EvergreenRules.has_status(card, EvergreenRules.STATUS_COVER)
		"enemy_creature_and_friendly_creature":
			return true
	return true
