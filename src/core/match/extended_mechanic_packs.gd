class_name ExtendedMechanicPacks
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")

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
	if options.has("betray_sacrifice_instance_ids"):
		card["pending_betray_sacrifices"] = options.get("betray_sacrifice_instance_ids", []).duplicate()
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
	# Subtype on board condition (e.g., "if you have another Orc")
	var required_board_subtype := str(descriptor.get("required_subtype_on_board", ""))
	if not required_board_subtype.is_empty():
		var trigger_source_id := str(trigger.get("source_instance_id", ""))
		if not _has_friendly_with_subtype(match_state, str(trigger.get("controller_player_id", "")), required_board_subtype, trigger_source_id):
			return false
	# Wounded enemy in lane condition
	if bool(descriptor.get("required_wounded_enemy_in_lane", false)):
		if not _has_wounded_enemy_in_lane(match_state, trigger):
			return false
	# Enemy in lane condition
	if bool(descriptor.get("required_enemy_in_lane", false)):
		if not _has_enemy_in_lane(match_state, trigger):
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
	# Minimum destroyed enemy runes condition
	var min_runes := int(descriptor.get("min_destroyed_enemy_runes", 0))
	if min_runes > 0:
		var opponent := _get_opponent(match_state, str(trigger.get("controller_player_id", "")))
		var max_runes := int(opponent.get("max_rune_count", 5))
		var current_runes := int(opponent.get("rune_count", max_runes))
		var destroyed_runes := max_runes - current_runes
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
	return true


static func apply_custom_effect(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	match str(effect.get("op", "")):
		"assemble":
			return {"handled": true, "events": _resolve_assemble(match_state, trigger, effect)}
		"betray_replay":
			return {"handled": true, "events": _resolve_betray_replay(match_state, trigger, event)}
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


static func _resolve_betray_replay(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Array:
	var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
	if source_card.is_empty():
		return []
	var pending_ids: Array = _ensure_array(source_card.get("pending_betray_sacrifice_ids", source_card.get("pending_betray_sacrifices", []))).duplicate()
	if pending_ids.is_empty():
		return []
	var events: Array = []
	var sacrifice_instance_id := str(pending_ids[0])
	pending_ids.remove_at(0)
	source_card["pending_betray_sacrifices"] = pending_ids
	var sacrifice_result := MatchMutations.sacrifice_card(match_state, str(trigger.get("controller_player_id", "")), sacrifice_instance_id, {"reason": "betray"})
	if not bool(sacrifice_result.get("is_valid", false)):
		return events
	events.append_array(sacrifice_result.get("events", []))
	events.append({
		"event_type": EVENT_CARD_PLAYED,
		"playing_player_id": str(trigger.get("controller_player_id", "")),
		"player_id": str(trigger.get("controller_player_id", "")),
		"source_instance_id": str(source_card.get("instance_id", "")),
		"source_controller_player_id": str(trigger.get("controller_player_id", "")),
		"source_zone": ZONE_DISCARD,
		"target_zone": ZONE_DISCARD,
		"card_type": str(source_card.get("card_type", CARD_TYPE_ACTION)),
		"played_cost": 0,
		"played_for_free": true,
		"reason": "betray_replay",
		"target_instance_id": str(event.get("target_instance_id", "")),
		"target_player_id": str(event.get("target_player_id", "")),
		"lane_id": str(event.get("lane_id", "")),
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
	var events: Array = []
	for card in _collect_owned_cards(match_state, str(trigger.get("controller_player_id", "")), [ZONE_HAND, ZONE_DECK, ZONE_DISCARD]):
		if str(card.get("shout_chain_id", card.get("definition_id", ""))) != shout_chain_id:
			continue
		var change_result := MatchMutations.change_card(card, next_template, {"reason": "shout_upgrade"})
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