class_name MatchTiming
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")

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

const RULE_TAG_PROPHECY := "prophecy"
const RULE_TAG_OUT_OF_CARDS := "out_of_cards"

const WINDOW_INTERRUPT := "interrupt"
const WINDOW_IMMEDIATE := "immediate"
const WINDOW_AFTER := "after"

const EVENT_TURN_STARTED := "turn_started"
const EVENT_TURN_ENDING := "turn_ending"
const EVENT_CARD_PLAYED := "card_played"
const EVENT_SUPPORT_ACTIVATED := "support_activated"
const EVENT_CREATURE_SUMMONED := "creature_summoned"
const EVENT_DAMAGE_RESOLVED := "damage_resolved"
const EVENT_CREATURE_DESTROYED := "creature_destroyed"
const EVENT_CARD_DRAWN := "card_drawn"
const EVENT_RUNE_BROKEN := "rune_broken"
const EVENT_PROPHECY_WINDOW_OPENED := "prophecy_window_opened"
const EVENT_PROPHECY_DECLINED := "prophecy_declined"
const EVENT_OUT_OF_CARDS_PLAYED := "out_of_cards_played"
const EVENT_CARD_OVERDRAW := "card_overdraw"

const MAX_HAND_SIZE := 10

const FAMILY_START_OF_TURN := "start_of_turn"
const FAMILY_END_OF_TURN := "end_of_turn"
const FAMILY_ON_PLAY := "on_play"
const FAMILY_ACTIVATE := "activate"
const FAMILY_SUMMON := "summon"
const FAMILY_ON_DAMAGE := "on_damage"
const FAMILY_ON_DEATH := "on_death"
const FAMILY_LAST_GASP := "last_gasp"
const FAMILY_SLAY := "slay"
const FAMILY_PILFER := "pilfer"
const FAMILY_VETERAN := "veteran"
const FAMILY_EXPERTISE := "expertise"
const FAMILY_PLOT := "plot"
const FAMILY_RUNE_BREAK := "rune_break"
const FAMILY_ON_FRIENDLY_DEATH := "on_friendly_death"
const FAMILY_ON_ATTACK := "on_attack"
const FAMILY_ON_EQUIP := "on_equip"
const FAMILY_AFTER_ACTION_PLAYED := "after_action_played"
const FAMILY_ON_WARD_BROKEN := "on_ward_broken"
const FAMILY_ON_FRIENDLY_SLAY := "on_friendly_slay"
const FAMILY_ON_MOVE := "on_move"
const FAMILY_ITEM_DETACHED := "item_detached"
const FAMILY_ON_ENEMY_RUNE_DESTROYED := "on_enemy_rune_destroyed"
const FAMILY_ON_ENEMY_SHACKLED := "on_enemy_shackled"
const FAMILY_ON_PLAYER_HEALED := "on_player_healed"
const FAMILY_ON_MAX_MAGICKA_GAINED := "on_max_magicka_gained"
const FAMILY_ON_CREATURE_HEALED := "on_creature_healed"

const EVENT_CARD_EQUIPPED := "card_equipped"

const PLAYER_ZONE_ORDER := [ZONE_HAND, ZONE_SUPPORT, ZONE_DISCARD, ZONE_BANISHED, ZONE_DECK]
const RANDOM_KEYWORD_POOL := ["breakthrough", "charge", "drain", "guard", "lethal", "regenerate", "ward"]
const ZONE_PRIORITY := {
	ZONE_LANE: 0,
	"support": 1,
	ZONE_HAND: 2,
	ZONE_DISCARD: 3,
	ZONE_BANISHED: 4,
	ZONE_DECK: 5,
	ZONE_GENERATED: 6,
	"": 9,
}
const FAMILY_SPECS := {
	FAMILY_START_OF_TURN: {"event_type": EVENT_TURN_STARTED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_END_OF_TURN: {"event_type": EVENT_TURN_ENDING, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_PLAY: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_ACTIVATE: {"event_type": EVENT_SUPPORT_ACTIVATED, "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_SUMMON: {"event_type": EVENT_CREATURE_SUMMONED, "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_ON_DAMAGE: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "either"},
	FAMILY_ON_DEATH: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "subject"},
	FAMILY_LAST_GASP: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "subject"},
	FAMILY_SLAY: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "killer"},
	FAMILY_PILFER: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "source", "target_type": "player", "min_amount": 1},
	FAMILY_VETERAN: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "target", "require_survived": true, "min_amount": 1},
	FAMILY_EXPERTISE: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "controller", "min_played_cost": 5},
	FAMILY_PLOT: {"event_type": EVENT_TURN_ENDING, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_RUNE_BREAK: {"event_type": EVENT_RUNE_BROKEN, "window": WINDOW_INTERRUPT, "match_role": "controller"},
	FAMILY_ON_FRIENDLY_DEATH: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_ATTACK: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "source", "damage_kind": "combat"},
	FAMILY_ON_EQUIP: {"event_type": EVENT_CARD_EQUIPPED, "window": WINDOW_AFTER, "match_role": "target"},
	FAMILY_AFTER_ACTION_PLAYED: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "controller", "required_played_card_type": "action"},
	FAMILY_ON_WARD_BROKEN: {"event_type": "ward_removed", "window": WINDOW_AFTER, "match_role": "target"},
	FAMILY_ON_FRIENDLY_SLAY: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "friendly_killer"},
	FAMILY_ON_MOVE: {"event_type": "card_moved", "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ITEM_DETACHED: {"event_type": "attached_item_detached", "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_ON_ENEMY_RUNE_DESTROYED: {"event_type": EVENT_RUNE_BROKEN, "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_ON_ENEMY_SHACKLED: {"event_type": "status_granted", "window": WINDOW_AFTER, "match_role": "opponent_target", "required_event_status_id": "shackled"},
	FAMILY_ON_PLAYER_HEALED: {"event_type": "player_healed", "window": WINDOW_AFTER, "match_role": "target_player_is_controller"},
	FAMILY_ON_MAX_MAGICKA_GAINED: {"event_type": "max_magicka_gained", "window": WINDOW_AFTER, "match_role": "target_player_is_controller"},
	FAMILY_ON_CREATURE_HEALED: {"event_type": "creature_healed", "window": WINDOW_AFTER, "match_role": "any_player"},
}


static func ensure_match_state(match_state: Dictionary) -> void:
	ExtendedMechanicPacks.ensure_match_state(match_state)
	if not match_state.has("pending_event_queue") or typeof(match_state["pending_event_queue"]) != TYPE_ARRAY:
		match_state["pending_event_queue"] = []
	if not match_state.has("replay_log") or typeof(match_state["replay_log"]) != TYPE_ARRAY:
		match_state["replay_log"] = []
	if not match_state.has("event_log") or typeof(match_state["event_log"]) != TYPE_ARRAY:
		match_state["event_log"] = []
	if not match_state.has("trigger_registry") or typeof(match_state["trigger_registry"]) != TYPE_ARRAY:
		match_state["trigger_registry"] = []
	if not match_state.has("last_timing_result") or typeof(match_state["last_timing_result"]) != TYPE_DICTIONARY:
		match_state["last_timing_result"] = {"processed_events": [], "trigger_resolutions": []}
	if not match_state.has("resolved_once_triggers") or typeof(match_state["resolved_once_triggers"]) != TYPE_DICTIONARY:
		match_state["resolved_once_triggers"] = {}
	if not match_state.has("next_event_sequence"):
		match_state["next_event_sequence"] = 0
	if not match_state.has("next_trigger_resolution_sequence"):
		match_state["next_trigger_resolution_sequence"] = 0
	if not match_state.has("pending_prophecy_windows") or typeof(match_state["pending_prophecy_windows"]) != TYPE_ARRAY:
		match_state["pending_prophecy_windows"] = []
	if not match_state.has("pending_discard_choices") or typeof(match_state["pending_discard_choices"]) != TYPE_ARRAY:
		match_state["pending_discard_choices"] = []
	if not match_state.has("pending_rune_break_queue") or typeof(match_state["pending_rune_break_queue"]) != TYPE_ARRAY:
		match_state["pending_rune_break_queue"] = []
	if not match_state.has("out_of_cards_sequence"):
		match_state["out_of_cards_sequence"] = 0


static func get_supported_trigger_families() -> Array:
	return [
		FAMILY_START_OF_TURN,
		FAMILY_END_OF_TURN,
		FAMILY_ON_PLAY,
		FAMILY_ACTIVATE,
		FAMILY_SUMMON,
		FAMILY_ON_DAMAGE,
		FAMILY_ON_DEATH,
		FAMILY_LAST_GASP,
		FAMILY_SLAY,
		FAMILY_PILFER,
		FAMILY_VETERAN,
		FAMILY_EXPERTISE,
		FAMILY_PLOT,
		FAMILY_RUNE_BREAK,
		FAMILY_ON_FRIENDLY_DEATH,
		FAMILY_ON_ATTACK,
		FAMILY_ON_EQUIP,
		FAMILY_AFTER_ACTION_PLAYED,
		FAMILY_ON_WARD_BROKEN,
		FAMILY_ON_FRIENDLY_SLAY,
		FAMILY_ON_MOVE,
		FAMILY_ITEM_DETACHED,
		FAMILY_ON_ENEMY_RUNE_DESTROYED,
		FAMILY_ON_ENEMY_SHACKLED,
		FAMILY_ON_PLAYER_HEALED,
		FAMILY_ON_MAX_MAGICKA_GAINED,
	]


# --- Target choice mechanic ---


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
	var source_card := _find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return []
	var controller_id := str(source_card.get("controller_player_id", ""))
	var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
	var source_lane_index := _get_card_lane_index(match_state, source_instance_id)
	var targets: Array = []
	match target_mode:
		"any_creature":
			targets = _all_lane_creatures(match_state)
		"another_creature":
			targets = _all_lane_creatures(match_state)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"enemy_creature":
			targets = _player_lane_creatures(match_state, opponent_id)
		"friendly_creature":
			targets = _player_lane_creatures(match_state, controller_id)
		"another_friendly_creature":
			targets = _player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"another_friendly_creature_in_lane":
			if source_lane_index >= 0:
				targets = _lane_creatures_for_player(match_state, source_lane_index, controller_id)
				targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"creature_or_player":
			targets = _all_lane_creatures(match_state)
			targets.append({"player_id": opponent_id})
		"enemy_creature_in_lane":
			if source_lane_index >= 0:
				targets = _lane_creatures_for_player(match_state, source_lane_index, opponent_id)
		"any_creature_in_lane":
			if source_lane_index >= 0:
				targets = _lane_creatures_at(match_state, source_lane_index)
				targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"enemy_support":
			for player in match_state.get("players", []):
				if typeof(player) != TYPE_DICTIONARY or str(player.get("player_id", "")) != opponent_id:
					continue
				for card in player.get("support", []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
	# Apply additional filters from trigger descriptor
	var max_power := int(trigger.get("target_filter_max_power", -1))
	if max_power >= 0:
		targets = targets.filter(func(c): return c.has("instance_id") and EvergreenRules.get_power(c) <= max_power)
	if bool(trigger.get("target_filter_wounded", false)):
		targets = targets.filter(func(c): return c.has("instance_id") and EvergreenRules.has_status(c, EvergreenRules.STATUS_WOUNDED))
	# Convert to target info format
	var result: Array = []
	for t in targets:
		if t.has("player_id"):
			result.append({"player_id": str(t.get("player_id", ""))})
		elif t.has("instance_id"):
			result.append({"instance_id": str(t.get("instance_id", ""))})
	return result


static func get_all_valid_targets(match_state: Dictionary, source_instance_id: String) -> Array:
	var source_card := _find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return []
	var all_targets: Array = []
	var seen_ids: Dictionary = {}
	for ability in get_target_mode_abilities(source_card):
		var mode := str(ability.get("target_mode", ""))
		for target_info in get_valid_targets_for_mode(match_state, source_instance_id, mode, ability):
			var key := str(target_info.get("instance_id", target_info.get("player_id", "")))
			if not seen_ids.has(key):
				seen_ids[key] = true
				all_targets.append(target_info)
	return all_targets


static func resolve_targeted_effect(match_state: Dictionary, source_instance_id: String, target_info: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var source_card := _find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return {"is_valid": false, "errors": ["Source card not found."], "events": [], "trigger_resolutions": []}
	var abilities := get_target_mode_abilities(source_card)
	if abilities.is_empty():
		return {"is_valid": false, "errors": ["No target_mode abilities on card."], "events": [], "trigger_resolutions": []}
	# Determine which ability matches the chosen target
	var chosen_instance_id := str(target_info.get("target_instance_id", ""))
	var chosen_player_id := str(target_info.get("target_player_id", ""))
	var matching_ability: Dictionary = {}
	if not chosen_instance_id.is_empty():
		for ability in abilities:
			var valid := get_valid_targets_for_mode(match_state, source_instance_id, str(ability.get("target_mode", "")), ability)
			for v in valid:
				if str(v.get("instance_id", "")) == chosen_instance_id:
					matching_ability = ability
					break
			if not matching_ability.is_empty():
				break
	elif not chosen_player_id.is_empty():
		for ability in abilities:
			var valid := get_valid_targets_for_mode(match_state, source_instance_id, str(ability.get("target_mode", "")), ability)
			for v in valid:
				if str(v.get("player_id", "")) == chosen_player_id:
					matching_ability = ability
					break
			if not matching_ability.is_empty():
				break
	if matching_ability.is_empty():
		return {"is_valid": false, "errors": ["No matching ability for chosen target."], "events": [], "trigger_resolutions": []}
	# Build trigger entry with chosen target injected
	var source_location := MatchMutations.find_card_location(match_state, source_instance_id)
	var lane_index := int(source_location.get("lane_index", -1))
	var slot_index := int(source_location.get("slot_index", -1))
	var controller_id := str(source_card.get("controller_player_id", ""))
	var trigger := {
		"trigger_id": "%s_target_choice" % source_instance_id,
		"trigger_index": 0,
		"source_instance_id": source_instance_id,
		"owner_player_id": str(source_card.get("owner_player_id", controller_id)),
		"controller_player_id": controller_id,
		"source_zone": ZONE_LANE,
		"lane_index": lane_index,
		"slot_index": slot_index,
		"descriptor": matching_ability.duplicate(true),
		"_chosen_target_id": chosen_instance_id if not chosen_instance_id.is_empty() else "",
		"_chosen_target_player_id": chosen_player_id if not chosen_player_id.is_empty() else "",
	}
	# Build synthetic event
	var lanes: Array = match_state.get("lanes", [])
	var lane_id := ""
	if lane_index >= 0 and lane_index < lanes.size():
		lane_id = str(lanes[lane_index].get("lane_id", ""))
	var event := {
		"event_type": EVENT_CREATURE_SUMMONED,
		"source_instance_id": source_instance_id,
		"player_id": controller_id,
		"lane_id": lane_id,
		"lane_index": lane_index,
		"target_instance_id": chosen_instance_id,
		"target_player_id": chosen_player_id,
	}
	# Build resolution record
	var resolution := _build_trigger_resolution(match_state, trigger, event)
	GameLogger.log_trigger_resolution(match_state, resolution, trigger)
	# Apply effects
	var generated_events := _apply_effects(match_state, trigger, event, resolution)
	# Publish any generated events (cascading effects)
	var timing_result := publish_events(match_state, generated_events, {
		"parent_event_id": "targeted_effect_%s" % source_instance_id,
	})
	var all_events: Array = generated_events + timing_result.get("processed_events", [])
	var all_resolutions: Array = [resolution] + timing_result.get("trigger_resolutions", [])
	return {"is_valid": true, "events": all_events, "trigger_resolutions": all_resolutions}


# --- Target choice helpers ---


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


static func has_pending_prophecy(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_prophecies(match_state, player_id).is_empty()


static func get_pending_prophecies(match_state: Dictionary, player_id: String = "") -> Array:
	ensure_match_state(match_state)
	var matches: Array = []
	for raw_window in match_state.get("pending_prophecy_windows", []):
		if typeof(raw_window) != TYPE_DICTIONARY:
			continue
		var window: Dictionary = raw_window
		if not player_id.is_empty() and str(window.get("player_id", "")) != player_id:
			continue
		matches.append(window.duplicate(true))
	return matches


static func has_pending_discard_choice(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_discard_choice(match_state, player_id).is_empty()


static func get_pending_discard_choice(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw_choice in match_state.get("pending_discard_choices", []):
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw_choice.get("player_id", "")) != player_id:
			continue
		return raw_choice.duplicate(true)
	return {}


static func resolve_pending_discard_choice(match_state: Dictionary, player_id: String, chosen_instance_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var choices: Array = match_state.get("pending_discard_choices", [])
	var choice_index := -1
	var choice := {}
	for i in range(choices.size()):
		if typeof(choices[i]) == TYPE_DICTIONARY and str(choices[i].get("player_id", "")) == player_id:
			choice_index = i
			choice = choices[i]
			break
	if choice_index == -1:
		return {"is_valid": false, "errors": ["No pending discard choice for player %s." % player_id]}
	var candidate_ids: Array = choice.get("candidate_instance_ids", [])
	if not candidate_ids.has(chosen_instance_id):
		return {"is_valid": false, "errors": ["Card %s is not a valid candidate." % chosen_instance_id]}
	var discard_player := _get_player_state(match_state, player_id)
	if discard_player.is_empty():
		choices.remove_at(choice_index)
		return {"is_valid": false, "errors": ["Unknown player_id: %s" % player_id]}
	var discard_pile: Array = discard_player.get(ZONE_DISCARD, [])
	var pick_index := -1
	for d_index in range(discard_pile.size()):
		var d_card = discard_pile[d_index]
		if typeof(d_card) == TYPE_DICTIONARY and str(d_card.get("instance_id", "")) == chosen_instance_id:
			pick_index = d_index
			break
	if pick_index == -1:
		choices.remove_at(choice_index)
		return {"is_valid": false, "errors": ["Card %s not found in discard pile." % chosen_instance_id]}
	var picked_card: Dictionary = discard_pile[pick_index]
	discard_pile.remove_at(pick_index)
	var generated_events: Array = []
	if _overflow_card_to_discard(discard_player, picked_card, player_id, ZONE_DISCARD, generated_events):
		choices.remove_at(choice_index)
		return {"is_valid": true, "errors": [], "events": generated_events}
	picked_card["zone"] = ZONE_HAND
	discard_player[ZONE_HAND].append(picked_card)
	var buff_power := int(choice.get("buff_power", 0))
	var buff_health := int(choice.get("buff_health", 0))
	if buff_power != 0 or buff_health != 0:
		picked_card["power_bonus"] = int(picked_card.get("power_bonus", 0)) + buff_power
		picked_card["health_bonus"] = int(picked_card.get("health_bonus", 0)) + buff_health
	generated_events.append({
		"event_type": "card_drawn",
		"player_id": player_id,
		"source_instance_id": str(choice.get("source_instance_id", "")),
		"drawn_instance_id": chosen_instance_id,
		"source_zone": ZONE_DISCARD,
		"target_zone": ZONE_HAND,
		"reason": str(choice.get("reason", "discard_choice")),
	})
	choices.remove_at(choice_index)
	var timing_result := publish_events(match_state, generated_events)
	return {
		"is_valid": true,
		"errors": [],
		"card": picked_card,
		"events": timing_result.get("processed_events", []),
		"trigger_resolutions": timing_result.get("trigger_resolutions", []),
	}


static func decline_pending_discard_choice(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var choices: Array = match_state.get("pending_discard_choices", [])
	for i in range(choices.size()):
		if typeof(choices[i]) == TYPE_DICTIONARY and str(choices[i].get("player_id", "")) == player_id:
			choices.remove_at(i)
			return {"is_valid": true, "errors": []}
	return {"is_valid": false, "errors": ["No pending discard choice for player %s." % player_id]}


static func apply_player_damage(match_state: Dictionary, player_id: String, amount: int, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var result := {
		"applied_damage": 0,
		"events": [],
		"broken_runes": [],
		"player_lost": false,
		"pending_prophecy_opened": false,
	}
	if amount <= 0:
		return result
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return result
	var previous_health := int(player.get("health", 0))
	var new_health := previous_health - amount
	player["health"] = new_health
	result["applied_damage"] = amount
	if new_health <= 0:
		result["player_lost"] = true
		return result

	var crossed_thresholds: Array = []
	for raw_threshold in player.get("rune_thresholds", []):
		var threshold := int(raw_threshold)
		if previous_health > threshold and new_health <= threshold:
			crossed_thresholds.append(threshold)
	if crossed_thresholds.is_empty():
		return result

	var queue: Array = match_state.get("pending_rune_break_queue", [])
	for threshold in crossed_thresholds:
		queue.append({
			"player_id": player_id,
			"threshold": threshold,
			"reason": str(context.get("reason", "damage")),
			"source_instance_id": str(context.get("source_instance_id", "")),
			"source_controller_player_id": str(context.get("source_controller_player_id", "")),
			"causing_player_id": str(context.get("causing_player_id", context.get("source_controller_player_id", ""))),
			"timing_window": str(context.get("timing_window", WINDOW_INTERRUPT)),
		})
	match_state["pending_rune_break_queue"] = queue

	var rune_result := _resume_pending_rune_breaks(match_state)
	result["events"] = rune_result.get("events", [])
	result["broken_runes"] = rune_result.get("broken_runes", [])
	result["pending_prophecy_opened"] = bool(rune_result.get("pending_prophecy_opened", false))
	result["player_lost"] = bool(rune_result.get("player_lost", false))
	return result


static func draw_cards(match_state: Dictionary, player_id: String, count: int, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var result := {
		"cards": [],
		"events": [],
		"player_lost": false,
		"pending_prophecy_opened": false,
	}
	if count <= 0:
		return result
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return result

	for _index in range(count):
		var deck: Array = player.get(ZONE_DECK, [])
		if deck.is_empty():
			var fatigue_result := _resolve_out_of_cards(match_state, player_id, context)
			result["events"].append_array(fatigue_result.get("events", []))
			result["player_lost"] = bool(fatigue_result.get("player_lost", false))
			break

		var drawn_card: Dictionary = deck.pop_back()
		var hand: Array = player.get(ZONE_HAND, [])
		var allow_prophecy := bool(context.get("allow_prophecy_interrupt", false))
		var is_prophecy := allow_prophecy and _can_open_prophecy_window(match_state, player_id, drawn_card)
		if hand.size() >= MAX_HAND_SIZE and not is_prophecy:
			drawn_card["zone"] = ZONE_DISCARD
			player[ZONE_DISCARD].append(drawn_card)
			result["events"].append({
				"event_type": EVENT_CARD_OVERDRAW,
				"player_id": player_id,
				"instance_id": str(drawn_card.get("instance_id", "")),
				"card_name": str(drawn_card.get("name", "")),
				"source_zone": ZONE_DECK,
			})
			continue
		drawn_card["zone"] = ZONE_HAND
		hand.append(drawn_card)
		result["cards"].append(drawn_card)
		var draw_event := {
			"event_type": EVENT_CARD_DRAWN,
			"player_id": player_id,
			"source_instance_id": str(context.get("source_instance_id", "")),
			"source_controller_player_id": str(context.get("source_controller_player_id", "")),
			"drawn_instance_id": str(drawn_card.get("instance_id", "")),
			"source_zone": ZONE_DECK,
			"target_zone": ZONE_HAND,
			"reason": str(context.get("reason", "draw")),
			"timing_window": str(context.get("timing_window", WINDOW_AFTER)),
		}
		if context.has("rune_threshold"):
			draw_event["rune_threshold"] = int(context.get("rune_threshold", -1))
		result["events"].append(draw_event)

		if bool(context.get("allow_prophecy_interrupt", false)) and _can_open_prophecy_window(match_state, player_id, drawn_card):
			result["pending_prophecy_opened"] = true
			result["events"].append(_open_prophecy_window(match_state, player_id, drawn_card, context))
			break
	return result


static func _overflow_card_to_discard(player: Dictionary, card: Dictionary, player_id: String, source_zone: String, events: Array) -> bool:
	var hand: Array = player.get(ZONE_HAND, [])
	if hand.size() < MAX_HAND_SIZE:
		return false
	card["zone"] = ZONE_DISCARD
	player[ZONE_DISCARD].append(card)
	events.append({
		"event_type": EVENT_CARD_OVERDRAW,
		"player_id": player_id,
		"instance_id": str(card.get("instance_id", "")),
		"card_name": str(card.get("name", "")),
		"source_zone": source_zone,
	})
	return true


static func destroy_front_rune(match_state: Dictionary, player_id: String, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var result := {
		"is_valid": false,
		"events": [],
		"destroyed_threshold": -1,
		"player_lost": false,
	}
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return result
	result["is_valid"] = true

	var thresholds: Array = player.get("rune_thresholds", [])
	if thresholds.is_empty():
		player["health"] = 0
		append_match_win_if_needed(match_state, player_id, _get_opposing_player_id(match_state.get("players", []), player_id), result["events"])
		result["player_lost"] = true
		return result

	var destroyed_threshold := int(thresholds[0])
	thresholds.remove_at(0)
	player["rune_thresholds"] = thresholds
	player["health"] = destroyed_threshold
	result["destroyed_threshold"] = destroyed_threshold
	result["events"].append({
		"event_type": EVENT_RUNE_BROKEN,
		"player_id": player_id,
		"threshold": destroyed_threshold,
		"source_instance_id": str(context.get("source_instance_id", "")),
		"source_controller_player_id": str(context.get("source_controller_player_id", "")),
		"causing_player_id": str(context.get("causing_player_id", context.get("source_controller_player_id", ""))),
		"reason": str(context.get("reason", "forced_rune_break")),
		"draw_card": false,
		"timing_window": str(context.get("timing_window", WINDOW_IMMEDIATE)),
	})
	return result


static func decline_pending_prophecy(match_state: Dictionary, player_id: String, instance_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var window_index := _find_pending_prophecy_window_index(match_state, player_id, instance_id)
	if window_index == -1:
		return _invalid_result("No pending Prophecy window exists for %s." % instance_id)
	var window := _consume_pending_prophecy_window(match_state, window_index)
	var events: Array = [{
		"event_type": EVENT_PROPHECY_DECLINED,
		"player_id": player_id,
		"drawn_instance_id": instance_id,
		"source_instance_id": str(window.get("source_instance_id", "")),
		"reason": RULE_TAG_PROPHECY,
		"timing_window": WINDOW_INTERRUPT,
	}]
	# If hand is at or over max size, discard the card instead of keeping it
	var player := _get_player_state(match_state, player_id)
	var hand: Array = player.get(ZONE_HAND, [])
	if hand.size() > MAX_HAND_SIZE:
		var card_index := -1
		for i in range(hand.size()):
			if str(hand[i].get("instance_id", "")) == instance_id:
				card_index = i
				break
		if card_index != -1:
			var card: Dictionary = hand[card_index]
			hand.remove_at(card_index)
			card["zone"] = ZONE_DISCARD
			player[ZONE_DISCARD].append(card)
			events.append({
				"event_type": EVENT_CARD_OVERDRAW,
				"player_id": player_id,
				"instance_id": instance_id,
				"card_name": str(card.get("name", "")),
				"source_zone": ZONE_HAND,
			})
	var resume_result := _resume_pending_rune_breaks(match_state)
	events.append_array(resume_result.get("events", []))
	var timing_result := publish_events(match_state, events)
	return {
		"is_valid": true,
		"errors": [],
		"events": timing_result.get("processed_events", []),
		"trigger_resolutions": timing_result.get("trigger_resolutions", []),
		"card": _find_card_anywhere(match_state, instance_id),
	}


static func play_pending_prophecy(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	if str(match_state.get("active_player_id", "")) == player_id:
		return _invalid_result("Prophecy free play is only available during the opponent's turn.")
	var window_index := _find_pending_prophecy_window_index(match_state, player_id, instance_id)
	if window_index == -1:
		return _invalid_result("No pending Prophecy window exists for %s." % instance_id)
	var card: Dictionary = _find_card_anywhere(match_state, instance_id)
	if card.is_empty() or str(card.get("zone", "")) != ZONE_HAND:
		return _invalid_result("Pending Prophecy card %s must still be in hand to be played." % instance_id)

	var card_type := str(card.get("card_type", ""))
	if card_type == CARD_TYPE_CREATURE:
		var lane_id := str(options.get("lane_id", ""))
		if lane_id.is_empty():
			return _invalid_result("Creature Prophecy play requires a lane_id.")
		var lane_rules: Variant = load("res://src/core/match/lane_rules.gd")
		var validation_options := options.duplicate(true)
		validation_options["played_for_free"] = true
		var validation: Dictionary = lane_rules.validate_summon_from_hand(match_state, player_id, instance_id, lane_id, validation_options)
		if not bool(validation.get("is_valid", false)):
			return validation
		_consume_pending_prophecy_window(match_state, window_index)
		var summon_options := options.duplicate(true)
		summon_options["event_context"] = {"timing_window": WINDOW_INTERRUPT}
		summon_options["played_for_free"] = true
		summon_options["play_event_overrides"] = {
			"played_for_free": true,
			"reason": RULE_TAG_PROPHECY,
		}
		summon_options["summon_event_overrides"] = {
			"played_for_free": true,
			"reason": RULE_TAG_PROPHECY,
		}
		var original_priority := str(match_state.get("priority_player_id", ""))
		match_state["priority_player_id"] = player_id
		var summon_result: Dictionary = lane_rules.summon_from_hand(match_state, player_id, instance_id, lane_id, summon_options)
		var processed_events: Array = summon_result.get("events", []).duplicate(true)
		var trigger_resolutions: Array = summon_result.get("trigger_resolutions", []).duplicate(true)
		var resume_result := _resume_pending_rune_breaks(match_state)
		if not resume_result.get("events", []).is_empty():
			var resumed_timing := publish_events(match_state, resume_result.get("events", []))
			processed_events.append_array(resumed_timing.get("processed_events", []))
			trigger_resolutions.append_array(resumed_timing.get("trigger_resolutions", []))
		match_state["priority_player_id"] = original_priority
		summon_result["events"] = processed_events
		summon_result["trigger_resolutions"] = trigger_resolutions
		return summon_result

	if card_type == CARD_TYPE_ACTION:
		var player := _get_player_state(match_state, player_id)
		var hand_index := _find_card_index(player.get(ZONE_HAND, []), instance_id)
		if hand_index == -1:
			return _invalid_result("Pending Prophecy card %s is no longer in hand." % instance_id)
		_consume_pending_prophecy_window(match_state, window_index)
		var played_card: Dictionary = player[ZONE_HAND][hand_index]
		player[ZONE_HAND].remove_at(hand_index)
		played_card["zone"] = ZONE_DISCARD
		player[ZONE_DISCARD].append(played_card)
		var original_priority := str(match_state.get("priority_player_id", ""))
		match_state["priority_player_id"] = player_id
		var timing_result := publish_events(match_state, [{
			"event_type": EVENT_CARD_PLAYED,
			"playing_player_id": player_id,
			"player_id": player_id,
			"source_instance_id": instance_id,
			"source_controller_player_id": player_id,
			"source_zone": ZONE_HAND,
			"target_zone": ZONE_DISCARD,
			"card_type": card_type,
			"played_cost": int(played_card.get("cost", 0)),
			"played_for_free": true,
			"reason": RULE_TAG_PROPHECY,
			"timing_window": WINDOW_INTERRUPT,
			"target_instance_id": str(options.get("target_instance_id", "")),
			"target_player_id": str(options.get("target_player_id", "")),
			"lane_id": str(options.get("lane_id", "")),
			"rules_tags": played_card.get("rules_tags", []).duplicate() if typeof(played_card.get("rules_tags", [])) == TYPE_ARRAY else [],
		}])
		var processed_events: Array = timing_result.get("processed_events", []).duplicate(true)
		var trigger_resolutions: Array = timing_result.get("trigger_resolutions", []).duplicate(true)
		var resume_result := _resume_pending_rune_breaks(match_state)
		if not resume_result.get("events", []).is_empty():
			var resumed_timing := publish_events(match_state, resume_result.get("events", []))
			processed_events.append_array(resumed_timing.get("processed_events", []))
			trigger_resolutions.append_array(resumed_timing.get("trigger_resolutions", []))
		match_state["priority_player_id"] = original_priority
		return {
			"is_valid": true,
			"errors": [],
			"card": played_card,
			"events": processed_events,
			"trigger_resolutions": trigger_resolutions,
		}

	return _invalid_result("Prophecy free play is not implemented for card type `%s`." % card_type)


static func play_action_from_hand(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var action_owner_validation := _validate_action_owner(match_state, player_id, "Action play")
	if not bool(action_owner_validation.get("is_valid", false)):
		return action_owner_validation
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return _invalid_result("Unknown player_id: %s" % player_id)
	var hand_index := _find_card_index(player.get(ZONE_HAND, []), instance_id)
	if hand_index == -1:
		return _invalid_result("Card %s is not in %s's hand." % [instance_id, player_id])
	var played_card: Dictionary = player[ZONE_HAND][hand_index]
	if str(played_card.get("card_type", "")) != CARD_TYPE_ACTION:
		return _invalid_result("Card %s is not an action." % instance_id)
	ExtendedMechanicPacks.apply_pre_play_options(played_card, options)
	if str(played_card.get("card_type", "")) != CARD_TYPE_ACTION:
		return _invalid_result("Selected mode for %s is not playable as an action." % instance_id)
	var played_for_free := bool(options.get("played_for_free", false))
	var base_action_cost := int(played_card.get("cost", 0)) + (1 if bool(options.get("exalt", false)) else 0)
	var action_cost_reduction := int(player.get("next_card_cost_reduction", 0))
	action_cost_reduction += _get_aura_cost_reduction(match_state, player_id, played_card)
	var play_cost := 0 if played_for_free else maxi(0, base_action_cost - action_cost_reduction)
	if play_cost > _get_available_magicka(player):
		return _invalid_result("Player does not have enough magicka to play %s." % instance_id)
	if play_cost > 0:
		_spend_magicka(match_state, player_id, play_cost)
	if action_cost_reduction > 0:
		player["next_card_cost_reduction"] = 0
	player[ZONE_HAND].remove_at(hand_index)
	played_card["zone"] = ZONE_DISCARD
	player[ZONE_DISCARD].append(played_card)
	var timing_result := publish_events(match_state, [{
		"event_type": EVENT_CARD_PLAYED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": player_id,
		"source_zone": ZONE_HAND,
		"target_zone": ZONE_DISCARD,
		"card_type": CARD_TYPE_ACTION,
		"played_cost": play_cost,
		"played_for_free": played_for_free,
		"reason": str(options.get("reason", "play_action")),
		"timing_window": str(options.get("timing_window", WINDOW_AFTER)),
		"target_instance_id": str(options.get("target_instance_id", "")),
		"target_player_id": str(options.get("target_player_id", "")),
		"lane_id": str(options.get("lane_id", "")),
		"rules_tags": played_card.get("rules_tags", []).duplicate() if typeof(played_card.get("rules_tags", [])) == TYPE_ARRAY else [],
	}])
	return {
		"is_valid": true,
		"errors": [],
		"card": played_card,
		"events": timing_result.get("processed_events", []),
		"trigger_resolutions": timing_result.get("trigger_resolutions", []),
	}


static func append_match_win_if_needed(match_state: Dictionary, loser_player_id: String, winner_player_id: String, events: Array) -> void:
	var losing_player := _get_player_state(match_state, loser_player_id)
	if losing_player.is_empty() or int(losing_player.get("health", 0)) > 0:
		return
	if not str(match_state.get("winner_player_id", "")).is_empty():
		return
	match_state["winner_player_id"] = winner_player_id
	events.append({
		"event_type": "match_won",
		"winner_player_id": winner_player_id,
		"loser_player_id": loser_player_id,
	})


static func publish_events(match_state: Dictionary, events: Array, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var queue: Array = match_state["pending_event_queue"]
	for raw_event in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		queue.append(_normalize_event(match_state, raw_event, context))
	var processed_events: Array = []
	var trigger_resolutions: Array = []
	while not queue.is_empty():
		var event: Dictionary = queue.pop_front()
		processed_events.append(event)
		_append_event_log(match_state, event)
		GameLogger.log_event(match_state, event)
		ExtendedMechanicPacks.observe_event(match_state, event)
		_append_replay_entry(match_state, {
			"entry_type": "event_processed",
			"event_id": str(event.get("event_id", "")),
			"event_type": str(event.get("event_type", "")),
			"timing_window": str(event.get("timing_window", WINDOW_AFTER)),
		})
		for trigger in _find_matching_triggers(match_state, event):
			var resolution := _build_trigger_resolution(match_state, trigger, event)
			trigger_resolutions.append(resolution)
			GameLogger.log_trigger_resolution(match_state, resolution, trigger)
			_mark_once_trigger_if_needed(match_state, trigger)
			_append_replay_entry(match_state, resolution)
			for generated_event in _apply_effects(match_state, trigger, event, resolution):
				queue.append(_normalize_event(match_state, generated_event, {
					"parent_event_id": str(event.get("event_id", "")),
					"produced_by_resolution_id": str(resolution.get("resolution_id", "")),
				}))
	recalculate_auras(match_state)
	# After auras recalculate, check for creatures that should die due to lost aura health
	var aura_death_events: Array = []
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size() - 1, -1, -1):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if EvergreenRules.get_remaining_health(card) <= 0:
					var instance_id := str(card.get("instance_id", ""))
					var destroy_result := MatchMutations.move_card_to_zone(match_state, instance_id, "discard")
					if bool(destroy_result.get("is_valid", false)):
						aura_death_events.append({
							"event_type": "creature_destroyed",
							"source_instance_id": instance_id,
							"controller_player_id": str(card.get("controller_player_id", "")),
							"reason": "aura_health_loss",
						})
	if not aura_death_events.is_empty():
		for raw_event in aura_death_events:
			queue.append(_normalize_event(match_state, raw_event, {}))
		while not queue.is_empty():
			var event: Dictionary = queue.pop_front()
			processed_events.append(event)
			_append_event_log(match_state, event)
			GameLogger.log_event(match_state, event)
			ExtendedMechanicPacks.observe_event(match_state, event)
			_append_replay_entry(match_state, {
				"entry_type": "event_processed",
				"event_id": str(event.get("event_id", "")),
				"event_type": str(event.get("event_type", "")),
				"timing_window": str(event.get("timing_window", WINDOW_AFTER)),
			})
			for trigger in _find_matching_triggers(match_state, event):
				var resolution := _build_trigger_resolution(match_state, trigger, event)
				trigger_resolutions.append(resolution)
				GameLogger.log_trigger_resolution(match_state, resolution, trigger)
				_mark_once_trigger_if_needed(match_state, trigger)
				_append_replay_entry(match_state, resolution)
				for generated_event in _apply_effects(match_state, trigger, event, resolution):
					queue.append(_normalize_event(match_state, generated_event, {
						"parent_event_id": str(event.get("event_id", "")),
						"produced_by_resolution_id": str(resolution.get("resolution_id", "")),
					}))
		recalculate_auras(match_state)
	var result := {
		"processed_events": processed_events,
		"trigger_resolutions": trigger_resolutions,
	}
	match_state["last_timing_result"] = result
	return result


static func recalculate_auras(match_state: Dictionary) -> void:
	# Step 1: Clear all aura bonuses on lane creatures
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				card["aura_power_bonus"] = 0
				card["aura_health_bonus"] = 0
				card["aura_keywords"] = []

	# Step 2: Collect aura sources (lane creatures + support cards), skip silenced
	var aura_sources: Array = []
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not card.has("aura"):
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				aura_sources.append({
					"card": card,
					"aura": card["aura"],
					"player_id": str(card.get("controller_player_id", player_id)),
					"lane_index": lane_index,
					"zone": "lane",
				})
	for player in match_state.get("players", []):
		var player_id := str(player.get("player_id", ""))
		for support_card in player.get("support", []):
			if typeof(support_card) != TYPE_DICTIONARY:
				continue
			if not support_card.has("aura"):
				continue
			aura_sources.append({
				"card": support_card,
				"aura": support_card["aura"],
				"player_id": player_id,
				"lane_index": -1,
				"zone": "support",
			})

	# Step 3: Apply each aura
	for source in aura_sources:
		var aura: Dictionary = source["aura"]
		var source_player_id: String = source["player_id"]
		var source_lane_index: int = source["lane_index"]
		var source_card: Dictionary = source["card"]

		# Evaluate condition
		if aura.has("condition") and not _evaluate_aura_condition(match_state, source_card, source_player_id, source_lane_index, aura["condition"]):
			continue

		var power_bonus := int(aura.get("power", 0))
		var health_bonus := int(aura.get("health", 0))
		var aura_kws: Array = aura.get("keywords", [])

		# Handle per_count multiplier
		if bool(aura.get("per_count", false)) and aura.has("condition"):
			var count := _get_aura_condition_count(match_state, source_card, source_player_id, source_lane_index, aura["condition"])
			power_bonus *= count
			health_bonus *= count

		# Find targets
		var targets := _get_aura_targets(match_state, source_card, source_player_id, source_lane_index, aura)
		for target in targets:
			target["aura_power_bonus"] = int(target.get("aura_power_bonus", 0)) + power_bonus
			target["aura_health_bonus"] = int(target.get("aura_health_bonus", 0)) + health_bonus
			for kw in aura_kws:
				var existing: Array = target.get("aura_keywords", [])
				if not existing.has(kw):
					existing.append(kw)
				target["aura_keywords"] = existing

	# Step 4: Recalculate player magicka auras from lane creatures
	for player in match_state.get("players", []):
		var pid := str(player.get("player_id", ""))
		var old_bonus := int(player.get("aura_max_magicka_bonus", 0))
		var new_bonus := 0
		for lane in lanes:
			var player_slots: Dictionary = lane.get("player_slots", {})
			for card in player_slots.get(pid, []):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not card.has("magicka_aura"):
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				new_bonus += int(card["magicka_aura"])
		var delta := new_bonus - old_bonus
		if delta != 0:
			player["max_magicka"] = maxi(0, int(player.get("max_magicka", 0)) + delta)
			player["current_magicka"] = mini(int(player.get("current_magicka", 0)), int(player["max_magicka"]))
			player["aura_max_magicka_bonus"] = new_bonus


static func _evaluate_aura_condition(match_state: Dictionary, source_card: Dictionary, player_id: String, lane_index: int, condition) -> bool:
	var condition_type := ""
	if typeof(condition) == TYPE_DICTIONARY:
		condition_type = str(condition.get("type", ""))
	elif typeof(condition) == TYPE_STRING:
		condition_type = condition
	match condition_type:
		"magicka_gte_7":
			var player := _find_player_by_id(match_state, player_id)
			return int(player.get("max_magicka", 0)) >= 7
		"has_item":
			var items: Array = source_card.get("attached_items", [])
			return not items.is_empty()
		"empty_hand":
			var player := _find_player_by_id(match_state, player_id)
			var hand: Array = player.get("hand", [])
			return hand.is_empty()
		"most_creatures_in_lane":
			if lane_index < 0:
				return false
			var lanes_arr: Array = match_state.get("lanes", [])
			if lane_index >= lanes_arr.size():
				return false
			var lane: Dictionary = lanes_arr[lane_index]
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			var my_count := 0
			var max_opponent_count := 0
			for pid in player_slots_by_id.keys():
				var count: int = player_slots_by_id[pid].size()
				if str(pid) == player_id:
					my_count = count
				else:
					max_opponent_count = maxi(max_opponent_count, count)
			return my_count > max_opponent_count
		"no_enemies_in_lane":
			if lane_index < 0:
				return false
			var lanes_arr: Array = match_state.get("lanes", [])
			if lane_index >= lanes_arr.size():
				return false
			var lane: Dictionary = lanes_arr[lane_index]
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			for pid in player_slots_by_id.keys():
				if str(pid) != player_id and player_slots_by_id[pid].size() > 0:
					return false
			return true
		"your_turn":
			return str(match_state.get("active_player_id", "")) == player_id
		"count_friendly_with_keyword":
			# Always true — the count is used as a multiplier via per_count
			return true
	return false


static func _get_aura_condition_count(match_state: Dictionary, source_card: Dictionary, player_id: String, _lane_index: int, condition) -> int:
	var condition_type := ""
	var keyword_id := ""
	if typeof(condition) == TYPE_DICTIONARY:
		condition_type = str(condition.get("type", ""))
		keyword_id = str(condition.get("keyword", ""))
	elif typeof(condition) == TYPE_STRING:
		condition_type = condition
	if condition_type == "count_friendly_with_keyword" and not keyword_id.is_empty():
		var source_instance_id := str(source_card.get("instance_id", ""))
		var count := 0
		for lane in match_state.get("lanes", []):
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			if not player_slots_by_id.has(player_id):
				continue
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == source_instance_id:
					continue
				if EvergreenRules.has_keyword(card, keyword_id):
					count += 1
		return count
	return 1


static func _get_aura_targets(match_state: Dictionary, source_card: Dictionary, player_id: String, source_lane_index: int, aura: Dictionary) -> Array:
	var scope: String = str(aura.get("scope", ""))
	var target_filter: String = str(aura.get("target", ""))
	var filter_subtype: String = str(aura.get("filter_subtype", ""))
	var filter_attribute: String = str(aura.get("filter_attribute", ""))
	var source_instance_id := str(source_card.get("instance_id", ""))
	var targets: Array = []

	if scope == "self":
		# Self-aura — only the source card itself (must be in lane)
		if str(source_card.get("zone", source_card.get("card_type", ""))) != "support":
			targets.append(source_card)
		return targets

	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		if scope == "same_lane" and lane_index != source_lane_index:
			continue
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		if not player_slots_by_id.has(player_id):
			continue
		for card in player_slots_by_id[player_id]:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			# "other_friendly" excludes self, "all_friendly" includes self
			if target_filter == "other_friendly" and str(card.get("instance_id", "")) == source_instance_id:
				continue
			if not filter_subtype.is_empty():
				var subtypes: Array = card.get("subtypes", [])
				if not subtypes.has(filter_subtype):
					continue
			if not filter_attribute.is_empty():
				var attributes: Array = card.get("attributes", [])
				if not attributes.has(filter_attribute):
					continue
			targets.append(card)
	return targets


static func _find_player_by_id(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func rebuild_trigger_registry(match_state: Dictionary) -> Array:
	ensure_match_state(match_state)
	var registry: Array = []
	var players: Array = match_state.get("players", [])
	for player in players:
		var player_id := str(player.get("player_id", ""))
		for zone_name in PLAYER_ZONE_ORDER:
			var cards = player.get(zone_name, [])
			if typeof(cards) != TYPE_ARRAY:
				continue
			for card in cards:
				_append_card_triggers(registry, card, zone_name, player_id)
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots = player_slots_by_id[player_id]
			if typeof(slots) != TYPE_ARRAY:
				continue
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				_append_card_triggers(registry, card, ZONE_LANE, str(player_id), lane_index, slot_index)
				if typeof(card) == TYPE_DICTIONARY:
					for attached_item in card.get("attached_items", []):
						_append_card_triggers(registry, attached_item, ZONE_LANE, str(player_id), lane_index, slot_index)
	_inject_granted_triggers(match_state, registry, lanes)
	match_state["trigger_registry"] = registry.duplicate(true)
	return registry


static func _inject_granted_triggers(match_state: Dictionary, registry: Array, lanes: Array) -> void:
	for player in match_state.get("players", []):
		var player_id := str(player.get("player_id", ""))
		var support_cards: Array = player.get(ZONE_SUPPORT, [])
		var granted_triggers: Array = []
		for support_card in support_cards:
			if typeof(support_card) != TYPE_DICTIONARY:
				continue
			if EvergreenRules.has_raw_status(support_card, EvergreenRules.STATUS_SILENCED):
				continue
			var grants = support_card.get("grants_trigger", [])
			if typeof(grants) != TYPE_ARRAY:
				continue
			for grant in grants:
				if typeof(grant) == TYPE_DICTIONARY:
					granted_triggers.append(grant)
		if granted_triggers.is_empty():
			continue
		for lane_index in range(lanes.size()):
			var lane: Dictionary = lanes[lane_index]
			var slots = lane.get("player_slots", {}).get(player_id, [])
			if typeof(slots) != TYPE_ARRAY:
				continue
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var instance_id := str(card.get("instance_id", ""))
				for g_index in range(granted_triggers.size()):
					var descriptor: Dictionary = granted_triggers[g_index].duplicate(true)
					if not str(descriptor.get("target_mode", "")).is_empty():
						continue
					registry.append({
						"trigger_id": "%s_granted_%d" % [instance_id, g_index],
						"trigger_index": -1,
						"source_instance_id": instance_id,
						"owner_player_id": str(card.get("owner_player_id", player_id)),
						"controller_player_id": str(card.get("controller_player_id", player_id)),
						"source_zone": ZONE_LANE,
						"lane_index": lane_index,
						"slot_index": slot_index,
						"descriptor": descriptor,
					})


static func _append_card_triggers(registry: Array, card, zone_name: String, controller_player_id: String, lane_index := -1, slot_index := -1) -> void:
	if typeof(card) != TYPE_DICTIONARY:
		return
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY or raw_triggers.is_empty():
		return
	for trigger_index in range(raw_triggers.size()):
		var raw_trigger = raw_triggers[trigger_index]
		if typeof(raw_trigger) != TYPE_DICTIONARY:
			continue
		var descriptor: Dictionary = raw_trigger
		if not bool(descriptor.get("enabled", true)):
			continue
		if not str(descriptor.get("target_mode", "")).is_empty():
			continue  # Target-choice triggers resolved manually via resolve_targeted_effect
		var instance_id := str(card.get("instance_id", ""))
		var trigger_id := str(descriptor.get("id", "%s_trigger_%d" % [instance_id, trigger_index]))
		registry.append({
			"trigger_id": trigger_id,
			"trigger_index": trigger_index,
			"source_instance_id": instance_id,
			"owner_player_id": str(card.get("owner_player_id", controller_player_id)),
			"controller_player_id": str(card.get("controller_player_id", controller_player_id)),
			"source_zone": zone_name,
			"lane_index": lane_index,
			"slot_index": slot_index,
			"descriptor": descriptor.duplicate(true),
		})


static func _find_matching_triggers(match_state: Dictionary, event: Dictionary) -> Array:
	var matches: Array = []
	for trigger in rebuild_trigger_registry(match_state):
		if not _trigger_matches_event(match_state, trigger, event):
			continue
		trigger["sort_key"] = _build_trigger_sort_key(match_state, trigger)
		_insert_sorted_trigger(matches, trigger)
	return matches


static func _trigger_matches_event(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> bool:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	if descriptor.is_empty():
		return false
	if _is_once_trigger_consumed(match_state, trigger):
		return false
	if not _matches_required_zone(trigger, descriptor):
		return false
	# Triggers with target_mode require manual resolution via resolve_targeted_effect;
	# skip them during automatic event processing so they don't fire with no chosen target.
	if not str(descriptor.get("target_mode", "")).is_empty() and str(trigger.get("_chosen_target_id", "")).is_empty() and str(trigger.get("_chosen_target_player_id", "")).is_empty():
		return false
	var event_type := str(event.get("event_type", ""))
	var family := str(descriptor.get("family", ""))
	var family_spec: Dictionary = FAMILY_SPECS.get(family, {})
	var expected_event_type := str(descriptor.get("event_type", family_spec.get("event_type", "")))
	if event_type != expected_event_type:
		return false
	if not _matches_trigger_role(match_state, trigger, descriptor, family_spec, event):
		return false
	return _matches_conditions(match_state, trigger, descriptor, family_spec, event)


static func _matches_required_zone(trigger: Dictionary, descriptor: Dictionary) -> bool:
	if descriptor.has("required_zone"):
		return str(descriptor.get("required_zone", "")) == str(trigger.get("source_zone", ""))
	var required_zones = descriptor.get("required_zones", [])
	if typeof(required_zones) == TYPE_ARRAY and not required_zones.is_empty():
		return required_zones.has(str(trigger.get("source_zone", "")))
	return true


static func _matches_trigger_role(match_state: Dictionary, trigger: Dictionary, descriptor: Dictionary, family_spec: Dictionary, event: Dictionary) -> bool:
	var source_instance_id := str(trigger.get("source_instance_id", ""))
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var role := str(descriptor.get("match_role", family_spec.get("match_role", "source")))
	match role:
		"controller":
			return str(event.get("player_id", event.get("playing_player_id", event.get("controller_player_id", "")))) == controller_player_id
		"opponent_player":
			var event_player_id := str(event.get("player_id", event.get("playing_player_id", event.get("controller_player_id", ""))))
			return not event_player_id.is_empty() and event_player_id != controller_player_id
		"source":
			return str(event.get("source_instance_id", event.get("attacker_instance_id", ""))) == source_instance_id
		"target":
			return _event_target_instance_id(event) == source_instance_id
		"subject":
			return _event_subject_instance_id(event) == source_instance_id
		"killer":
			return str(event.get("destroyed_by_instance_id", "")) == source_instance_id
		"either":
			return str(event.get("source_instance_id", "")) == source_instance_id or _event_target_instance_id(event) == source_instance_id or _event_subject_instance_id(event) == source_instance_id
		"any_player":
			return true
		"friendly_killer":
			var killer_id := str(event.get("destroyed_by_instance_id", ""))
			if killer_id.is_empty() or killer_id == source_instance_id:
				return false
			var killer_card := _find_card_anywhere(match_state, killer_id)
			return str(killer_card.get("controller_player_id", "")) == controller_player_id
		"target_player_is_controller":
			return str(event.get("target_player_id", "")) == controller_player_id
		"opponent_target":
			var target_id := _event_target_instance_id(event)
			if target_id.is_empty():
				return false
			var target_card := _find_card_anywhere(match_state, target_id)
			return not target_card.is_empty() and str(target_card.get("controller_player_id", "")) != controller_player_id
	return false


static func _matches_conditions(match_state: Dictionary, trigger: Dictionary, descriptor: Dictionary, family_spec: Dictionary, event: Dictionary) -> bool:
	var target_type := str(descriptor.get("target_type", family_spec.get("target_type", "")))
	if not target_type.is_empty() and str(event.get("target_type", "")) != target_type:
		return false
	var min_amount := int(descriptor.get("min_amount", family_spec.get("min_amount", 0)))
	if min_amount > 0 and int(event.get("amount", 0)) < min_amount:
		return false
	var min_played_cost := int(descriptor.get("min_played_cost", family_spec.get("min_played_cost", 0)))
	if min_played_cost > 0 and int(event.get("played_cost", 0)) < min_played_cost:
		return false
	var require_survived := bool(descriptor.get("require_survived", family_spec.get("require_survived", false)))
	if require_survived and bool(event.get("target_destroyed", false)):
		return false
	var required_damage_kind := str(descriptor.get("damage_kind", family_spec.get("damage_kind", "")))
	if not required_damage_kind.is_empty() and str(event.get("damage_kind", "")) != required_damage_kind:
		return false
	var required_played_card_type := str(descriptor.get("required_played_card_type", family_spec.get("required_played_card_type", "")))
	if not required_played_card_type.is_empty() and str(event.get("card_type", "")) != required_played_card_type:
		return false
	var required_played_rules_tag := str(descriptor.get("required_played_rules_tag", ""))
	if not required_played_rules_tag.is_empty():
		var event_rules_tags = event.get("rules_tags", [])
		if typeof(event_rules_tags) != TYPE_ARRAY or not event_rules_tags.has(required_played_rules_tag):
			return false
	if bool(descriptor.get("exclude_self", false)):
		var event_source_id := str(event.get("source_instance_id", event.get("subject_instance_id", "")))
		if event_source_id == str(trigger.get("source_instance_id", "")):
			return false
	if bool(descriptor.get("require_same_lane", false)):
		var trigger_lane_index := int(trigger.get("lane_index", -1))
		var event_lane_id := str(event.get("lane_id", ""))
		var lanes: Array = match_state.get("lanes", [])
		if trigger_lane_index < 0 or trigger_lane_index >= lanes.size():
			return false
		if str(lanes[trigger_lane_index].get("lane_id", "")) != event_lane_id:
			return false
	var max_source_cost := int(descriptor.get("max_event_source_cost", -1))
	if max_source_cost >= 0:
		var cost_check_card := _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
		if cost_check_card.is_empty() or int(cost_check_card.get("cost", 999)) > max_source_cost:
			return false
	var required_event_source_zone := str(descriptor.get("required_event_source_zone", ""))
	if not required_event_source_zone.is_empty() and str(event.get("source_zone", "")) != required_event_source_zone:
		return false
	var required_event_target_zone := str(descriptor.get("required_event_target_zone", ""))
	if not required_event_target_zone.is_empty() and str(event.get("target_zone", "")) != required_event_target_zone:
		return false
	var required_event_status_id := str(descriptor.get("required_event_status_id", family_spec.get("required_event_status_id", "")))
	if not required_event_status_id.is_empty() and str(event.get("status_id", "")) != required_event_status_id:
		return false
	var required_target_keyword := str(descriptor.get("required_target_keyword", ""))
	if not required_target_keyword.is_empty():
		var rtk_target_id := str(event.get("target_instance_id", ""))
		var rtk_target := _find_card_anywhere(match_state, rtk_target_id)
		if rtk_target.is_empty() or not EvergreenRules.has_keyword(rtk_target, required_target_keyword):
			return false
	return ExtendedMechanicPacks.matches_additional_conditions(match_state, trigger, descriptor, event)


static func _build_trigger_sort_key(match_state: Dictionary, trigger: Dictionary) -> String:
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var priority_player_id := str(match_state.get("priority_player_id", match_state.get("active_player_id", "")))
	var controller_rank := 0 if controller_player_id == priority_player_id else 1
	var zone_name := str(trigger.get("source_zone", ""))
	var zone_rank := int(ZONE_PRIORITY.get(zone_name, 9))
	var lane_index := maxi(-1, int(trigger.get("lane_index", -1))) + 1
	var slot_index := maxi(-1, int(trigger.get("slot_index", -1))) + 1
	var trigger_index := int(trigger.get("trigger_index", 0))
	return "%02d|%02d|%02d|%02d|%s|%02d" % [controller_rank, zone_rank, lane_index, slot_index, str(trigger.get("source_instance_id", "")), trigger_index]


static func _insert_sorted_trigger(matches: Array, trigger: Dictionary) -> void:
	var sort_key := str(trigger.get("sort_key", ""))
	for index in range(matches.size()):
		if sort_key < str(matches[index].get("sort_key", "")):
			matches.insert(index, trigger)
			return
	matches.append(trigger)


static func _build_trigger_resolution(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Dictionary:
	match_state["next_trigger_resolution_sequence"] = int(match_state.get("next_trigger_resolution_sequence", 0)) + 1
	var resolution_id := "trigger_%04d" % int(match_state["next_trigger_resolution_sequence"])
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var family := str(descriptor.get("family", descriptor.get("event_type", "")))
	return {
		"entry_type": "trigger_resolved",
		"resolution_id": resolution_id,
		"trigger_id": str(trigger.get("trigger_id", "")),
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"controller_player_id": str(trigger.get("controller_player_id", "")),
		"family": family,
		"event_id": str(event.get("event_id", "")),
		"event_type": str(event.get("event_type", "")),
		"timing_window": str(descriptor.get("window", FAMILY_SPECS.get(family, {}).get("window", WINDOW_AFTER))),
	}


static func _mark_once_trigger_if_needed(match_state: Dictionary, trigger: Dictionary) -> void:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	if bool(descriptor.get("once_per_instance", false)):
		var resolved_once_triggers: Dictionary = match_state.get("resolved_once_triggers", {})
		resolved_once_triggers[str(trigger.get("trigger_id", ""))] = true
		match_state["resolved_once_triggers"] = resolved_once_triggers
	if bool(descriptor.get("once_per_turn", false)):
		var resolved_turn_triggers: Dictionary = match_state.get("resolved_turn_triggers", {})
		resolved_turn_triggers[str(trigger.get("trigger_id", ""))] = true
		match_state["resolved_turn_triggers"] = resolved_turn_triggers


static func _is_once_trigger_consumed(match_state: Dictionary, trigger: Dictionary) -> bool:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	if bool(descriptor.get("once_per_instance", false)):
		var resolved_once_triggers: Dictionary = match_state.get("resolved_once_triggers", {})
		if bool(resolved_once_triggers.get(str(trigger.get("trigger_id", "")), false)):
			return true
	if bool(descriptor.get("once_per_turn", false)):
		var resolved_turn_triggers: Dictionary = match_state.get("resolved_turn_triggers", {})
		if bool(resolved_turn_triggers.get(str(trigger.get("trigger_id", "")), false)):
			return true
	return false


static func _apply_effects(match_state: Dictionary, trigger: Dictionary, event: Dictionary, resolution: Dictionary) -> Array:
	var generated_events: Array = []
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var reason := str(descriptor.get("family", "trigger"))
	for raw_effect in descriptor.get("effects", []):
		if typeof(raw_effect) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = raw_effect
		if not ExtendedMechanicPacks.effect_is_enabled(match_state, trigger, effect):
			continue
		if bool(effect.get("require_event_target_alive", false)):
			var alive_check_id := _event_target_instance_id(event)
			if alive_check_id.is_empty():
				continue
			var alive_check_card := _find_card_anywhere(match_state, alive_check_id)
			if alive_check_card.is_empty() or str(alive_check_card.get("zone", "")) != ZONE_LANE:
				continue
		var op := str(effect.get("op", ""))
		match op:
			"log":
				generated_events.append({
					"event_type": "timing_effect_logged",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"message": str(effect.get("message", str(descriptor.get("family", "trigger")))),
				})
			"reveal_opponent_top_deck":
				var controller_id := str(trigger.get("controller_player_id", ""))
				var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
				var opponent := _get_player_state(match_state, opponent_id)
				if not opponent.is_empty():
					var deck: Array = opponent.get(ZONE_DECK, [])
					if not deck.is_empty():
						generated_events.append({
							"event_type": "opponent_top_deck_revealed",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"controller_player_id": controller_id,
							"revealed_card": deck.back().duplicate(true),
						})
			"modify_stats":
				var stat_multiplier := _resolve_count_multiplier(match_state, trigger, event, effect)
				var base_power := int(event.get("amount", 0)) if bool(effect.get("power_from_event_amount", false)) else int(effect.get("power", 0))
				var base_health := int(event.get("amount", 0)) if bool(effect.get("health_from_event_amount", false)) else int(effect.get("health", 0))
				var total_power := base_power * stat_multiplier
				var total_health := base_health * stat_multiplier
				var is_temp := str(effect.get("duration", "")) == "end_of_turn"
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.apply_stat_bonus(card, total_power, total_health, reason)
					if is_temp:
						EvergreenRules.add_temporary_stat_bonus(card, total_power, total_health, int(match_state.get("turn_number", 0)))
					generated_events.append({
						"event_type": "stats_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"power_bonus": total_power,
						"health_bonus": total_health,
						"reason": reason,
					})
			"grant_status":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var status_id := str(effect.get("status_id", ""))
					if status_id == EvergreenRules.STATUS_COVER:
						var offset := int(effect.get("expires_on_turn_offset", 1))
						EvergreenRules.grant_cover(card, int(match_state.get("turn_number", 0)) + offset, reason)
					else:
						EvergreenRules.add_status(card, status_id)
					generated_events.append({
						"event_type": "status_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"status_id": status_id,
					})
			"grant_keyword":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.ensure_card_state(card)
					var keyword_id := str(effect.get("keyword_id", ""))
					var granted_keywords: Array = card.get("granted_keywords", [])
					if not granted_keywords.has(keyword_id):
						granted_keywords.append(keyword_id)
						card["granted_keywords"] = granted_keywords
					if keyword_id == EvergreenRules.KEYWORD_GUARD and EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER):
						EvergreenRules.remove_status(card, EvergreenRules.STATUS_COVER)
						card.erase("cover_expires_on_turn")
						card.erase("cover_granted_by")
					generated_events.append({
						"event_type": "keyword_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"keyword_id": keyword_id,
					})
			"grant_random_keyword":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.ensure_card_state(card)
					var candidates: Array = []
					for kw in RANDOM_KEYWORD_POOL:
						if not EvergreenRules.has_keyword(card, kw):
							candidates.append(kw)
					if candidates.is_empty():
						continue
					var pick: String = str(candidates[_deterministic_index(match_state, str(card.get("instance_id", "")), candidates.size())])
					var granted_keywords: Array = card.get("granted_keywords", [])
					if not granted_keywords.has(pick):
						granted_keywords.append(pick)
						card["granted_keywords"] = granted_keywords
					if pick == EvergreenRules.KEYWORD_GUARD and EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER):
						EvergreenRules.remove_status(card, EvergreenRules.STATUS_COVER)
						card.erase("cover_expires_on_turn")
						card.erase("cover_granted_by")
					generated_events.append({
						"event_type": "keyword_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"keyword_id": pick,
					})
			"remove_keyword":
				var keyword_to_remove := str(effect.get("keyword_id", ""))
				if not keyword_to_remove.is_empty():
					for card in _resolve_card_targets(match_state, trigger, event, effect):
						if EvergreenRules.remove_keyword(card, keyword_to_remove):
							generated_events.append({
								"event_type": "keyword_removed",
								"source_instance_id": str(trigger.get("source_instance_id", "")),
								"target_instance_id": str(card.get("instance_id", "")),
								"keyword_id": keyword_to_remove,
								"reason": reason,
							})
			"restore_creature_health":
				var restore_amount := int(effect.get("amount", -1))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var healed := EvergreenRules.restore_health(card, restore_amount)
					if healed > 0:
						generated_events.append({
							"event_type": "creature_healed",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"target_instance_id": str(card.get("instance_id", "")),
							"amount": healed,
							"reason": reason,
						})
			"heal":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var heal_player := _get_player_state(match_state, player_id)
					if heal_player.is_empty():
						continue
					var heal_amount := int(effect.get("amount", 0)) * _resolve_count_multiplier(match_state, trigger, event, effect)
					if bool(effect.get("amount_from_event", false)):
						heal_amount = int(event.get("amount", 0))
					if heal_amount <= 0:
						continue
					heal_player["health"] = int(heal_player.get("health", 0)) + heal_amount
					generated_events.append({
						"event_type": "player_healed",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_player_id": player_id,
						"amount": heal_amount,
					})
			"gain_max_magicka":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var magicka_player := _get_player_state(match_state, player_id)
					if magicka_player.is_empty():
						continue
					var gain := int(effect.get("amount", 1))
					magicka_player["max_magicka"] = int(magicka_player.get("max_magicka", 0)) + gain
					magicka_player["current_magicka"] = int(magicka_player.get("current_magicka", 0)) + gain
					generated_events.append({
						"event_type": "max_magicka_gained",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_player_id": player_id,
						"amount": gain,
					})
			"deal_damage":
				var damage_amount := int(effect.get("amount", 0)) * _resolve_count_multiplier(match_state, trigger, event, effect)
				var damage_source_id := str(trigger.get("source_instance_id", ""))
				var deal_damage_targets := _resolve_card_targets(match_state, trigger, event, effect)
				if deal_damage_targets.is_empty():
					# Fall back to player damage if a chosen player target exists
					var chosen_player := str(trigger.get("_chosen_target_player_id", ""))
					if not chosen_player.is_empty() and damage_amount > 0:
						var custom_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, {"op": "damage", "amount": damage_amount, "target_player": "chosen_target_player"})
						generated_events.append_array(custom_result.get("events", []))
				for card in deal_damage_targets:
					if damage_amount <= 0:
						continue
					var damage_result := EvergreenRules.apply_damage_to_creature(card, damage_amount)
					if bool(damage_result.get("ward_removed", false)):
						generated_events.append({
							"event_type": "ward_removed",
							"source_instance_id": damage_source_id,
							"target_instance_id": str(card.get("instance_id", "")),
						})
					var applied := int(damage_result.get("applied", 0))
					generated_events.append({
						"event_type": "damage_resolved",
						"source_instance_id": damage_source_id,
						"target_instance_id": str(card.get("instance_id", "")),
						"target_type": "creature",
						"amount": applied,
						"reason": reason,
					})
					if EvergreenRules.is_creature_destroyed(card, false):
						var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
						if bool(card_location.get("is_valid", false)):
							var controller_pid := str(card.get("controller_player_id", ""))
							var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
							if bool(moved.get("is_valid", false)):
								generated_events.append({
									"event_type": "creature_destroyed",
									"instance_id": str(card.get("instance_id", "")),
									"source_instance_id": str(card.get("instance_id", "")),
									"owner_player_id": str(card.get("owner_player_id", "")),
									"controller_player_id": controller_pid,
									"destroyed_by_instance_id": damage_source_id,
									"lane_id": str(card_location.get("lane_id", "")),
									"source_zone": ZONE_LANE,
								})
			"draw_cards":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var draw_count := int(effect.get("count", 1)) * _resolve_count_multiplier(match_state, trigger, event, effect)
						var draw_result := draw_cards(match_state, player_id, draw_count, {
							"reason": reason,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"source_controller_player_id": str(trigger.get("controller_player_id", "")),
						})
						generated_events.append_array(draw_result.get("events", []))
						var drawn_cards: Array = draw_result.get("cards", [])
						if effect.has("post_draw_cost_set"):
							var set_cost := int(effect.get("post_draw_cost_set", 0))
							for drawn_card in drawn_cards:
								if typeof(drawn_card) == TYPE_DICTIONARY:
									drawn_card["cost"] = set_cost
						elif effect.has("post_draw_cost_reduce"):
							var reduce_amount := int(effect.get("post_draw_cost_reduce", 0))
							var cost_threshold := int(effect.get("cost_threshold", 0))
							for drawn_card in drawn_cards:
								if typeof(drawn_card) == TYPE_DICTIONARY:
									var card_cost := int(drawn_card.get("cost", 0))
									if cost_threshold > 0 and card_cost < cost_threshold:
										continue
									drawn_card["cost"] = maxi(0, card_cost - reduce_amount)
			"draw_filtered":
				var filter_max_cost := int(effect.get("max_cost", -1))
				var filter_card_type := str(effect.get("required_card_type", ""))
				var filter_subtype := str(effect.get("required_subtype", ""))
				var filter_rules_tag := str(effect.get("required_rules_tag", ""))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var draw_player := _get_player_state(match_state, player_id)
					if draw_player.is_empty():
						continue
					var deck: Array = draw_player.get(ZONE_DECK, [])
					var candidates: Array = []
					for deck_index in range(deck.size()):
						var deck_card = deck[deck_index]
						if typeof(deck_card) != TYPE_DICTIONARY:
							continue
						if filter_max_cost >= 0 and int(deck_card.get("cost", 0)) > filter_max_cost:
							continue
						if not filter_card_type.is_empty() and str(deck_card.get("card_type", "")) != filter_card_type:
							continue
						if not filter_subtype.is_empty():
							var subtypes = deck_card.get("subtypes", [])
							if typeof(subtypes) != TYPE_ARRAY or not subtypes.has(filter_subtype):
								continue
						if not filter_rules_tag.is_empty():
							var deck_card_tags = deck_card.get("rules_tags", [])
							if typeof(deck_card_tags) != TYPE_ARRAY or not deck_card_tags.has(filter_rules_tag):
								continue
						candidates.append(deck_index)
					if candidates.is_empty():
						continue
					var pick_index: int = candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_draw_filtered", candidates.size())]
					var picked_card: Dictionary = deck[pick_index]
					deck.remove_at(pick_index)
					if _overflow_card_to_discard(draw_player, picked_card, player_id, ZONE_DECK, generated_events):
						continue
					picked_card["zone"] = ZONE_HAND
					draw_player[ZONE_HAND].append(picked_card)
					generated_events.append({
						"event_type": "card_drawn",
						"player_id": player_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"drawn_instance_id": str(picked_card.get("instance_id", "")),
						"source_zone": ZONE_DECK,
						"target_zone": ZONE_HAND,
						"reason": reason,
					})
			"discard":
				var discard_targets := [] if effect.has("target_player") and not effect.has("target") else _resolve_card_targets(match_state, trigger, event, effect)
				if discard_targets.is_empty() and effect.has("target_player"):
					for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var discard_result := MatchMutations.discard_from_hand(match_state, player_id, int(effect.get("count", 1)), {
							"selection": str(effect.get("selection", "front")),
						})
						generated_events.append_array(discard_result.get("events", []))
				else:
					for card in discard_targets:
						var discard_result := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
						generated_events.append_array(discard_result.get("events", []))
			"banish":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var banish_result := MatchMutations.banish_card(match_state, str(card.get("instance_id", "")))
					generated_events.append_array(banish_result.get("events", []))
			"banish_and_return_end_of_turn":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var bar_controller_id := str(card.get("controller_player_id", card.get("owner_player_id", "")))
					var bar_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					var bar_lane_id := str(bar_location.get("lane_id", ""))
					var bar_snapshot: Dictionary = card.duplicate(true)
					var bar_result := MatchMutations.banish_card(match_state, str(card.get("instance_id", "")))
					generated_events.append_array(bar_result.get("events", []))
					if bool(bar_result.get("is_valid", false)):
						var pending: Array = match_state.get("pending_eot_returns", [])
						pending.append({
							"card_snapshot": bar_snapshot,
							"controller_player_id": bar_controller_id,
							"lane_id": bar_lane_id,
							"turn_number": int(match_state.get("turn_number", 0)),
						})
						match_state["pending_eot_returns"] = pending
			"unsummon":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var unsummon_result := MatchMutations.unsummon_card(match_state, str(card.get("instance_id", "")))
					generated_events.append_array(unsummon_result.get("events", []))
			"sacrifice":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var sacrifice_result := MatchMutations.sacrifice_card(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")))
					generated_events.append_array(sacrifice_result.get("events", []))
			"silence":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					if _is_immune_to_effect(match_state, card, "silence"):
						continue
					var silence_result := MatchMutations.silence_card(card, {"reason": reason})
					generated_events.append_array(silence_result.get("events", []))
			"shackle":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					if _is_immune_to_effect(match_state, card, "shackle"):
						continue
					EvergreenRules.add_status(card, EvergreenRules.STATUS_SHACKLED)
					card["shackle_expires_on_turn"] = int(match_state.get("turn_number", 0)) + 1
					generated_events.append({"event_type": "status_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "status_id": "shackled", "reason": reason})
			"destroy_creature":
				var destroy_source_id := str(trigger.get("source_instance_id", ""))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					if not bool(card_location.get("is_valid", false)):
						continue
					var controller_pid := str(card.get("controller_player_id", ""))
					var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
					if bool(moved.get("is_valid", false)):
						generated_events.append({
							"event_type": "creature_destroyed",
							"instance_id": str(card.get("instance_id", "")),
							"source_instance_id": str(card.get("instance_id", "")),
							"owner_player_id": str(card.get("owner_player_id", "")),
							"controller_player_id": controller_pid,
							"destroyed_by_instance_id": destroy_source_id,
							"lane_id": str(card_location.get("lane_id", "")),
							"source_zone": ZONE_LANE,
						})
			"generate_card_to_hand":
				var gen_template: Dictionary = effect.get("card_template", {})
				if gen_template.is_empty():
					continue
				var gen_count := int(effect.get("count", 1))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var gen_player := _get_player_state(match_state, player_id)
					if gen_player.is_empty():
						continue
					var hand: Array = gen_player.get(ZONE_HAND, [])
					for _i in range(gen_count):
						var generated_card := MatchMutations.build_generated_card(match_state, player_id, gen_template)
						if _overflow_card_to_discard(gen_player, generated_card, player_id, ZONE_GENERATED, generated_events):
							continue
						generated_card["zone"] = ZONE_HAND
						hand.append(generated_card)
						generated_events.append({"event_type": "card_drawn", "player_id": player_id, "source_instance_id": str(generated_card.get("instance_id", "")), "reason": reason})
			"change":
				var change_template := _resolve_effect_template(match_state, trigger, event, effect)
				if change_template.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var change_result := MatchMutations.change_card(card, change_template, {"reason": reason})
					generated_events.append_array(change_result.get("events", []))
			"copy":
				var source_cards := _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source")))
				if source_cards.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var copy_result := MatchMutations.copy_card(card, source_cards[0], {
						"preserve_modifiers": bool(effect.get("preserve_modifiers", false)),
						"preserve_damage": bool(effect.get("preserve_damage", false)),
						"preserve_statuses": bool(effect.get("preserve_statuses", false)),
					})
					generated_events.append_array(copy_result.get("events", []))
			"transform":
				var transform_template := _resolve_effect_template(match_state, trigger, event, effect)
				if transform_template.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var transform_result := MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), transform_template, {"reason": reason})
					generated_events.append_array(transform_result.get("events", []))
			"steal":
				var stealing_players := _resolve_player_targets(match_state, trigger, event, effect)
				if stealing_players.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var steal_result := MatchMutations.steal_card(match_state, stealing_players[0], str(card.get("instance_id", "")), {
						"slot_index": int(effect.get("slot_index", -1)),
					})
					generated_events.append_array(steal_result.get("events", []))
			"consume":
				var consumers := _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("consumer_target", "self")))
				if consumers.is_empty():
					continue
				var consumer: Dictionary = consumers[0]
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var consume_result := MatchMutations.consume_card(match_state, str(consumer.get("controller_player_id", "")), str(consumer.get("instance_id", "")), str(card.get("instance_id", "")), {
						"reason": reason,
						"destination_zone": str(effect.get("destination_zone", MatchMutations.ZONE_DISCARD)),
					})
					generated_events.append_array(consume_result.get("events", []))
			"move_between_lanes":
				var raw_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", event.get("lane_id", ""))))
				if raw_lane_id != "other_lane" and raw_lane_id.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var dest_lane_id := raw_lane_id
					if dest_lane_id == "other_lane":
						var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
						var current_lane_id := str(card_location.get("lane_id", ""))
						dest_lane_id = ""
						for lane in match_state.get("lanes", []):
							var lid := str(lane.get("lane_id", ""))
							if lid != current_lane_id and not lid.is_empty():
								dest_lane_id = lid
								break
					if dest_lane_id.is_empty():
						continue
					var move_result := MatchMutations.move_card_between_lanes(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")), dest_lane_id, {
						"slot_index": int(effect.get("slot_index", -1)),
					})
					generated_events.append_array(move_result.get("events", []))
			"summon_from_effect":
				var summon_players := _resolve_player_targets(match_state, trigger, event, effect)
				if summon_players.is_empty():
					continue
				var summon_lane_ids: Array = []
				if bool(effect.get("all_lanes", false)):
					for lane in match_state.get("lanes", []):
						summon_lane_ids.append(str(lane.get("lane_id", "")))
				else:
					var single_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", event.get("lane_id", ""))))
					if single_lane_id == "other_lane":
						var source_lane_id := str(event.get("lane_id", ""))
						for lane in match_state.get("lanes", []):
							var lid := str(lane.get("lane_id", ""))
							if lid != source_lane_id and not lid.is_empty():
								single_lane_id = lid
								break
					if single_lane_id.is_empty() or single_lane_id == "other_lane":
						var trigger_lane_index := int(trigger.get("lane_index", -1))
						var lanes: Array = match_state.get("lanes", [])
						if trigger_lane_index >= 0 and trigger_lane_index < lanes.size():
							single_lane_id = str(lanes[trigger_lane_index].get("lane_id", ""))
					if single_lane_id.is_empty() or single_lane_id == "other_lane":
						continue
					summon_lane_ids.append(single_lane_id)
				if bool(effect.get("require_wounded_enemy_in_lane", false)):
					var controller_id := str(trigger.get("controller_player_id", ""))
					var opp_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
					var filtered_lane_ids: Array = []
					for check_lane in match_state.get("lanes", []):
						var check_lid := str(check_lane.get("lane_id", ""))
						if not summon_lane_ids.has(check_lid):
							continue
						var has_wounded := false
						for card in check_lane.get("player_slots", {}).get(opp_id, []):
							if typeof(card) == TYPE_DICTIONARY and int(card.get("damage_marked", 0)) > 0:
								has_wounded = true
								break
						if has_wounded:
							filtered_lane_ids.append(check_lid)
					summon_lane_ids = filtered_lane_ids
				var summon_template: Dictionary = effect.get("card_template", {})
				if summon_template.is_empty():
					for source_card in _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source"))):
						for s_lane_id in summon_lane_ids:
							var summon_existing := MatchMutations.summon_card_to_lane(match_state, summon_players[0], str(source_card.get("instance_id", "")), s_lane_id, {
								"slot_index": int(effect.get("slot_index", -1)),
							})
							if not bool(summon_existing.get("is_valid", false)):
								continue
							generated_events.append_array(summon_existing.get("events", []))
							generated_events.append(_build_summon_event(summon_existing["card"], summon_players[0], s_lane_id, int(summon_existing.get("slot_index", -1)), reason))
				else:
					for player_id in summon_players:
						for s_lane_id in summon_lane_ids:
							var generated_card := MatchMutations.build_generated_card(match_state, player_id, summon_template)
							var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, generated_card, s_lane_id, {
								"slot_index": int(effect.get("slot_index", -1)),
								"source_zone": MatchMutations.ZONE_GENERATED,
							})
							if not bool(summon_result.get("is_valid", false)):
								continue
							generated_events.append_array(summon_result.get("events", []))
							generated_events.append(_build_summon_event(summon_result["card"], player_id, s_lane_id, int(summon_result.get("slot_index", -1)), reason))
			"summon_copies_to_lane":
				var copies_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", event.get("lane_id", ""))))
				var copies_players := _resolve_player_targets(match_state, trigger, event, effect)
				var copies_template: Dictionary = effect.get("card_template", {})
				if copies_lane_id.is_empty() or copies_players.is_empty() or copies_template.is_empty():
					continue
				var copies_count := int(effect.get("count", 0))
				var fill_lane := bool(effect.get("fill_lane", false))
				for player_id in copies_players:
					var remaining := copies_count
					if fill_lane:
						var lane_data := _get_lane_open_slots(match_state, copies_lane_id, player_id)
						remaining = int(lane_data.get("open_slots", 0))
					for _i in range(remaining):
						var gen_card := MatchMutations.build_generated_card(match_state, player_id, copies_template)
						var summon_res := MatchMutations.summon_card_to_lane(match_state, player_id, gen_card, copies_lane_id, {
							"source_zone": MatchMutations.ZONE_GENERATED,
						})
						if not bool(summon_res.get("is_valid", false)):
							break
						generated_events.append_array(summon_res.get("events", []))
						generated_events.append(_build_summon_event(summon_res["card"], player_id, copies_lane_id, int(summon_res.get("slot_index", -1)), reason))
			"summon_copy_to_other_lane":
				var copy_sources := _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source")))
				if copy_sources.is_empty():
					continue
				var copy_source: Dictionary = copy_sources[0]
				var source_lane_id := str(event.get("lane_id", ""))
				var other_lane_id := ""
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) != source_lane_id:
						other_lane_id = str(lane.get("lane_id", ""))
						break
				if other_lane_id.is_empty():
					continue
				var copy_template := copy_source.duplicate(true)
				copy_template.erase("instance_id")
				copy_template.erase("zone")
				copy_template.erase("damage_marked")
				copy_template.erase("power_bonus")
				copy_template.erase("health_bonus")
				copy_template.erase("granted_keywords")
				copy_template.erase("status_markers")
				var copy_player_id := str(trigger.get("controller_player_id", ""))
				var gen_card := MatchMutations.build_generated_card(match_state, copy_player_id, copy_template)
				var summon_res := MatchMutations.summon_card_to_lane(match_state, copy_player_id, gen_card, other_lane_id, {
					"source_zone": MatchMutations.ZONE_GENERATED,
				})
				if bool(summon_res.get("is_valid", false)):
					generated_events.append_array(summon_res.get("events", []))
					generated_events.append(_build_summon_event(summon_res["card"], copy_player_id, other_lane_id, int(summon_res.get("slot_index", -1)), reason))
			"draw_from_discard_filtered":
				var discard_filter_card_type := str(effect.get("required_card_type", ""))
				var discard_filter_subtype := str(effect.get("required_subtype", ""))
				var is_player_choice := bool(effect.get("player_choice", false))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var discard_player := _get_player_state(match_state, player_id)
					if discard_player.is_empty():
						continue
					var discard_pile: Array = discard_player.get(ZONE_DISCARD, [])
					var discard_candidates: Array = []
					var candidate_instance_ids: Array = []
					for d_index in range(discard_pile.size()):
						var d_card = discard_pile[d_index]
						if typeof(d_card) != TYPE_DICTIONARY:
							continue
						if not discard_filter_card_type.is_empty() and str(d_card.get("card_type", "")) != discard_filter_card_type:
							continue
						if not discard_filter_subtype.is_empty():
							var d_subtypes = d_card.get("subtypes", [])
							if typeof(d_subtypes) != TYPE_ARRAY or not d_subtypes.has(discard_filter_subtype):
								continue
						discard_candidates.append(d_index)
						candidate_instance_ids.append(str(d_card.get("instance_id", "")))
					if discard_candidates.is_empty():
						continue
					if is_player_choice:
						match_state["pending_discard_choices"].append({
							"player_id": player_id,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"candidate_instance_ids": candidate_instance_ids,
							"buff_power": int(effect.get("buff_power", 0)),
							"buff_health": int(effect.get("buff_health", 0)),
							"reason": reason,
						})
					else:
						var pick_idx: int = discard_candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_draw_discard", discard_candidates.size())]
						var picked_discard_card: Dictionary = discard_pile[pick_idx]
						discard_pile.remove_at(pick_idx)
						if _overflow_card_to_discard(discard_player, picked_discard_card, player_id, ZONE_DISCARD, generated_events):
							continue
						picked_discard_card["zone"] = ZONE_HAND
						discard_player[ZONE_HAND].append(picked_discard_card)
						generated_events.append({
							"event_type": "card_drawn",
							"player_id": player_id,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"drawn_instance_id": str(picked_discard_card.get("instance_id", "")),
							"source_zone": ZONE_DISCARD,
							"target_zone": ZONE_HAND,
							"reason": reason,
						})
			"equip_items_from_discard":
				var equip_self := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if equip_self.is_empty():
					continue
				var equip_count := int(effect.get("count", 2))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var equip_player := _get_player_state(match_state, player_id)
					if equip_player.is_empty():
						continue
					var equip_discard: Array = equip_player.get(ZONE_DISCARD, [])
					var item_candidates: Array = []
					for edi in range(equip_discard.size()):
						var ed_card = equip_discard[edi]
						if typeof(ed_card) == TYPE_DICTIONARY and str(ed_card.get("card_type", "")) == CARD_TYPE_ITEM:
							item_candidates.append({"index": edi, "cost": int(ed_card.get("cost", 0))})
					item_candidates.sort_custom(func(a, b): return int(a.get("cost", 0)) > int(b.get("cost", 0)))
					var equipped := 0
					for candidate in item_candidates:
						if equipped >= equip_count:
							break
						var pick_idx: int = int(candidate.get("index", 0))
						for already_equipped in range(equipped):
							if pick_idx > 0:
								pick_idx -= 1
						var actual_item: Dictionary = equip_discard[pick_idx]
						equip_discard.remove_at(pick_idx)
						var attach_result := MatchMutations.attach_item_to_creature(match_state, player_id, actual_item, str(equip_self.get("instance_id", "")), {"source_zone": ZONE_DISCARD})
						if bool(attach_result.get("is_valid", false)):
							generated_events.append_array(attach_result.get("events", []))
							equipped += 1
			"shuffle_hand_to_deck_and_draw":
				var shuffle_filter_tag := str(effect.get("required_rules_tag", ""))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var shuffle_player := _get_player_state(match_state, player_id)
					if shuffle_player.is_empty():
						continue
					var hand: Array = shuffle_player.get(ZONE_HAND, [])
					var deck: Array = shuffle_player.get(ZONE_DECK, [])
					var to_shuffle: Array = []
					for hi in range(hand.size() - 1, -1, -1):
						var h_card = hand[hi]
						if typeof(h_card) != TYPE_DICTIONARY:
							continue
						if not shuffle_filter_tag.is_empty():
							var tags = h_card.get("rules_tags", [])
							if typeof(tags) != TYPE_ARRAY or not tags.has(shuffle_filter_tag):
								continue
						to_shuffle.append(h_card)
						hand.remove_at(hi)
					var draw_count := to_shuffle.size()
					for shuffled_card in to_shuffle:
						shuffled_card["zone"] = ZONE_DECK
						var ins_pos := _deterministic_index(match_state, str(shuffled_card.get("instance_id", "")) + "_shuffle_back", deck.size() + 1)
						deck.insert(ins_pos, shuffled_card)
					if draw_count > 0:
						var redraw_result := draw_cards(match_state, player_id, draw_count, {"reason": reason, "source_instance_id": str(trigger.get("source_instance_id", ""))})
						generated_events.append_array(redraw_result.get("events", []))
			"change_lane_types":
				var new_lane_type := str(effect.get("lane_type", "shadow"))
				for lane in match_state.get("lanes", []):
					lane["lane_type"] = new_lane_type
					generated_events.append({"event_type": "lane_type_changed", "lane_id": str(lane.get("lane_id", "")), "new_lane_type": new_lane_type, "source_instance_id": str(trigger.get("source_instance_id", ""))})
			"trigger_friendly_last_gasps":
				var tflg_controller_id := str(trigger.get("controller_player_id", ""))
				var tflg_self_id := str(trigger.get("source_instance_id", ""))
				for lane in match_state.get("lanes", []):
					for card in lane.get("player_slots", {}).get(tflg_controller_id, []):
						if typeof(card) != TYPE_DICTIONARY:
							continue
						if str(card.get("instance_id", "")) == tflg_self_id:
							continue
						var raw_triggers = card.get("triggered_abilities", [])
						if typeof(raw_triggers) != TYPE_ARRAY:
							continue
						for raw_trigger in raw_triggers:
							if typeof(raw_trigger) != TYPE_DICTIONARY:
								continue
							if str(raw_trigger.get("family", "")) != FAMILY_LAST_GASP:
								continue
							var fake_trigger := {
								"trigger_id": str(card.get("instance_id", "")) + "_retrigger_lg",
								"source_instance_id": str(card.get("instance_id", "")),
								"controller_player_id": tflg_controller_id,
								"owner_player_id": str(card.get("owner_player_id", tflg_controller_id)),
								"source_zone": ZONE_LANE,
								"lane_index": int(card.get("lane_index", -1)),
								"descriptor": raw_trigger.duplicate(true),
							}
							var fake_event := {"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "source_instance_id": str(card.get("instance_id", "")), "controller_player_id": tflg_controller_id}
							var fake_resolution := _build_trigger_resolution(match_state, fake_trigger, fake_event)
							generated_events.append_array(_apply_effects(match_state, fake_trigger, fake_event, fake_resolution))
			"summon_random_from_discard":
				var srd_filter_card_type := str(effect.get("required_card_type", "creature"))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var srd_player := _get_player_state(match_state, player_id)
					if srd_player.is_empty():
						continue
					var srd_discard: Array = srd_player.get(ZONE_DISCARD, [])
					var srd_candidates: Array = []
					for srd_i in range(srd_discard.size()):
						var srd_card = srd_discard[srd_i]
						if typeof(srd_card) != TYPE_DICTIONARY:
							continue
						if not srd_filter_card_type.is_empty() and str(srd_card.get("card_type", "")) != srd_filter_card_type:
							continue
						srd_candidates.append(srd_i)
					if srd_candidates.is_empty():
						continue
					var srd_pick: int = srd_candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_srd", srd_candidates.size())]
					var srd_picked: Dictionary = srd_discard[srd_pick]
					srd_discard.remove_at(srd_pick)
					MatchMutations.reset_transient_state(srd_picked)
					var srd_lane_id := ""
					var srd_lane_index := int(trigger.get("lane_index", -1))
					var srd_lanes: Array = match_state.get("lanes", [])
					if srd_lane_index >= 0 and srd_lane_index < srd_lanes.size():
						srd_lane_id = str(srd_lanes[srd_lane_index].get("lane_id", ""))
					if srd_lane_id.is_empty():
						srd_lane_id = str(event.get("lane_id", ""))
					if srd_lane_id.is_empty() and not srd_lanes.is_empty():
						srd_lane_id = str(srd_lanes[0].get("lane_id", ""))
					if srd_lane_id.is_empty():
						continue
					var srd_result := MatchMutations.summon_card_to_lane(match_state, player_id, srd_picked, srd_lane_id, {})
					if bool(srd_result.get("is_valid", false)):
						generated_events.append_array(srd_result.get("events", []))
						generated_events.append(_build_summon_event(srd_result["card"], player_id, srd_lane_id, int(srd_result.get("slot_index", -1)), reason))
			"destroy_all_except_random":
				var controller_id := str(trigger.get("controller_player_id", ""))
				var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
				var destroy_source_id := str(trigger.get("source_instance_id", ""))
				for lane in match_state.get("lanes", []):
					var lane_id := str(lane.get("lane_id", ""))
					var player_slots: Dictionary = lane.get("player_slots", {})
					for pid in player_slots.keys():
						var slots: Array = player_slots[pid]
						if slots.size() <= 1:
							continue
						var survivor_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_survivor_" + str(pid) + "_" + lane_id, slots.size())
						for slot_idx in range(slots.size() - 1, -1, -1):
							if slot_idx == survivor_idx:
								continue
							var card = slots[slot_idx]
							if typeof(card) != TYPE_DICTIONARY:
								continue
							var card_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
							if not bool(card_loc.get("is_valid", false)):
								continue
							var cpid := str(card.get("controller_player_id", ""))
							var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
							if bool(moved.get("is_valid", false)):
								generated_events.append({"event_type": "creature_destroyed", "instance_id": str(card.get("instance_id", "")), "source_instance_id": str(card.get("instance_id", "")), "owner_player_id": str(card.get("owner_player_id", "")), "controller_player_id": cpid, "destroyed_by_instance_id": destroy_source_id, "lane_id": lane_id, "source_zone": ZONE_LANE})
			"steal_items":
				var steal_items_receiver := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if steal_items_receiver.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var items_to_steal: Array = card.get("attached_items", []).duplicate()
					for item in items_to_steal:
						if typeof(item) != TYPE_DICTIONARY:
							continue
						var host_items: Array = card.get("attached_items", [])
						var idx := -1
						for i in range(host_items.size()):
							if typeof(host_items[i]) == TYPE_DICTIONARY and str(host_items[i].get("instance_id", "")) == str(item.get("instance_id", "")):
								idx = i
								break
						if idx >= 0:
							host_items.remove_at(idx)
							card["attached_items"] = host_items
						item["controller_player_id"] = str(trigger.get("controller_player_id", ""))
						var receiver_items: Array = steal_items_receiver.get("attached_items", [])
						receiver_items.append(item)
						steal_items_receiver["attached_items"] = receiver_items
						generated_events.append({"event_type": "item_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "item_instance_id": str(item.get("instance_id", ""))})
			"steal_keywords":
				var steal_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if steal_source.is_empty():
					continue
				EvergreenRules.ensure_card_state(steal_source)
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					for kw in RANDOM_KEYWORD_POOL:
						if EvergreenRules.has_keyword(card, kw):
							EvergreenRules.remove_keyword(card, kw)
							var granted: Array = steal_source.get("granted_keywords", [])
							if not granted.has(kw):
								granted.append(kw)
								steal_source["granted_keywords"] = granted
							generated_events.append({"event_type": "keyword_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": kw})
			"copy_keywords_to_friendly":
				var kw_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if kw_source.is_empty():
					continue
				var source_keywords: Array = []
				for kw in RANDOM_KEYWORD_POOL:
					if EvergreenRules.has_keyword(kw_source, kw):
						source_keywords.append(kw)
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.ensure_card_state(card)
					var granted: Array = card.get("granted_keywords", [])
					for kw in source_keywords:
						if not granted.has(kw):
							granted.append(kw)
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": kw})
					card["granted_keywords"] = granted
			"grant_extra_attack":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["has_attacked_this_turn"] = false
					generated_events.append({
						"event_type": "extra_attack_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
					})
			"copy_from_opponent_deck":
				var copy_filter_card_type := str(effect.get("required_card_type", ""))
				var controller_id := str(trigger.get("controller_player_id", ""))
				var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
				var opponent := _get_player_state(match_state, opponent_id)
				if opponent.is_empty():
					continue
				var opp_deck: Array = opponent.get(ZONE_DECK, [])
				var copy_candidates: Array = []
				for d_idx in range(opp_deck.size()):
					var d_card = opp_deck[d_idx]
					if typeof(d_card) != TYPE_DICTIONARY:
						continue
					if not copy_filter_card_type.is_empty() and str(d_card.get("card_type", "")) != copy_filter_card_type:
						continue
					copy_candidates.append(d_idx)
				if copy_candidates.is_empty():
					continue
				var pick: int = copy_candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_copy_opp", copy_candidates.size())]
				var source_card_for_copy: Dictionary = opp_deck[pick]
				var copy_tmpl: Dictionary = source_card_for_copy.duplicate(true)
				copy_tmpl.erase("instance_id")
				copy_tmpl.erase("zone")
				copy_tmpl.erase("damage_marked")
				copy_tmpl.erase("power_bonus")
				copy_tmpl.erase("health_bonus")
				copy_tmpl.erase("granted_keywords")
				copy_tmpl.erase("status_markers")
				var gen_copy := MatchMutations.build_generated_card(match_state, controller_id, copy_tmpl)
				var cth_player := _get_player_state(match_state, controller_id)
				if not cth_player.is_empty():
					if _overflow_card_to_discard(cth_player, gen_copy, controller_id, ZONE_GENERATED, generated_events):
						continue
					gen_copy["zone"] = ZONE_HAND
					var cth_hand: Array = cth_player.get(ZONE_HAND, [])
					cth_hand.append(gen_copy)
					generated_events.append({"event_type": "card_drawn", "player_id": controller_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "drawn_instance_id": str(gen_copy.get("instance_id", "")), "reason": reason})
			"double_stats":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var current_power := EvergreenRules.get_power(card)
					var current_health := EvergreenRules.get_health(card)
					EvergreenRules.apply_stat_bonus(card, current_power, current_health, reason)
					generated_events.append({
						"event_type": "stats_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"power_bonus": current_power,
						"health_bonus": current_health,
						"reason": reason,
					})
			"copy_card_to_hand":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var copy_template: Dictionary = card.duplicate(true)
					copy_template.erase("instance_id")
					copy_template.erase("zone")
					copy_template.erase("damage_marked")
					copy_template.erase("power_bonus")
					copy_template.erase("health_bonus")
					copy_template.erase("granted_keywords")
					copy_template.erase("status_markers")
					for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var gen_card := MatchMutations.build_generated_card(match_state, player_id, copy_template)
						var ccth_player := _get_player_state(match_state, player_id)
						if ccth_player.is_empty():
							continue
						if _overflow_card_to_discard(ccth_player, gen_card, player_id, ZONE_GENERATED, generated_events):
							continue
						gen_card["zone"] = ZONE_HAND
						var ccth_hand: Array = ccth_player.get(ZONE_HAND, [])
						ccth_hand.append(gen_card)
						generated_events.append({"event_type": "card_drawn", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "drawn_instance_id": str(gen_card.get("instance_id", "")), "reason": reason})
			"return_to_hand":
				var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not source_card.is_empty():
					var rth_owner_id := str(source_card.get("owner_player_id", ""))
					var rth_player := _get_player_state(match_state, rth_owner_id)
					if not rth_player.is_empty() and rth_player.get(ZONE_HAND, []).size() >= MAX_HAND_SIZE:
						var move_result := MatchMutations.move_card_to_zone(match_state, str(source_card.get("instance_id", "")), ZONE_DISCARD, {"reason": reason})
						generated_events.append_array(move_result.get("events", []))
						generated_events.append({
							"event_type": EVENT_CARD_OVERDRAW,
							"player_id": rth_owner_id,
							"instance_id": str(source_card.get("instance_id", "")),
							"card_name": str(source_card.get("name", "")),
							"source_zone": str(source_card.get("zone", "")),
						})
					else:
						var move_result := MatchMutations.move_card_to_zone(match_state, str(source_card.get("instance_id", "")), ZONE_HAND, {"reason": reason})
						generated_events.append_array(move_result.get("events", []))
			"generate_card_to_deck":
				var gen_template: Dictionary = effect.get("card_template", {})
				if not gen_template.is_empty():
					for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var gen_card := MatchMutations.build_generated_card(match_state, player_id, gen_template)
						var player := _get_player_state(match_state, player_id)
						if player.is_empty():
							continue
						var deck: Array = player.get(ZONE_DECK, [])
						gen_card["zone"] = ZONE_DECK
						var insert_pos := _deterministic_index(match_state, str(gen_card.get("instance_id", "")), deck.size() + 1)
						deck.insert(insert_pos, gen_card)
						generated_events.append({"event_type": "card_shuffled_to_deck", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "inserted_instance_id": str(gen_card.get("instance_id", "")), "reason": reason})
			_:
				var custom_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, effect)
				if bool(custom_result.get("handled", false)):
					generated_events.append_array(custom_result.get("events", []))
	return generated_events


static func _resolve_card_targets(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	var target := str(effect.get("target", "self"))
	var targets := _resolve_card_targets_by_name(match_state, trigger, event, target)
	var filter_subtype := str(effect.get("target_filter_subtype", ""))
	if not filter_subtype.is_empty():
		var filtered: Array = []
		for card in targets:
			var subtypes: Array = card.get("subtypes", [])
			if typeof(subtypes) == TYPE_ARRAY and subtypes.has(filter_subtype):
				filtered.append(card)
		targets = filtered
	var filter_keyword := str(effect.get("target_filter_keyword", ""))
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
	return targets


static func _resolve_card_targets_by_name(match_state: Dictionary, trigger: Dictionary, event: Dictionary, target: String) -> Array:
	var targets: Array = []
	match target:
		"self":
			var self_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not self_card.is_empty():
				targets.append(self_card)
		"host":
			var host_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			var host_id := str(host_source.get("attached_to_instance_id", "")) if not host_source.is_empty() else ""
			if not host_id.is_empty():
				var host_card := _find_card_anywhere(match_state, host_id)
				if not host_card.is_empty():
					targets.append(host_card)
		"event_source":
			var source_card := _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
			if not source_card.is_empty():
				targets.append(source_card)
		"event_target":
			var target_card := _find_card_anywhere(match_state, _event_target_instance_id(event))
			if not target_card.is_empty():
				targets.append(target_card)
		"event_subject":
			var subject_card := _find_card_anywhere(match_state, str(event.get("instance_id", event.get("drawn_instance_id", ""))))
			if not subject_card.is_empty():
				targets.append(subject_card)
		"event_killer":
			var killer_card := _find_card_anywhere(match_state, str(event.get("destroyed_by_instance_id", "")))
			if not killer_card.is_empty():
				targets.append(killer_card)
		"all_enemies_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var controller_id := str(trigger.get("controller_player_id", ""))
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"all_friendly_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var controller_id := str(trigger.get("controller_player_id", ""))
			var self_id := str(trigger.get("source_instance_id", ""))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(controller_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != self_id:
						targets.append(card)
		"all_enemies":
			var controller_id := str(trigger.get("controller_player_id", ""))
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"all_friendly":
			var controller_id := str(trigger.get("controller_player_id", ""))
			var self_id := str(trigger.get("source_instance_id", ""))
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(controller_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != self_id:
						targets.append(card)
		"all_creatures_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var self_id := str(trigger.get("source_instance_id", ""))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != self_id:
							targets.append(card)
		"chosen_target":
			var chosen_id := str(trigger.get("_chosen_target_id", ""))
			if not chosen_id.is_empty():
				var chosen_card := _find_card_anywhere(match_state, chosen_id)
				if not chosen_card.is_empty():
					targets.append(chosen_card)
		"random_enemy":
			var all_enemies := _resolve_card_targets_by_name(match_state, trigger, event, "all_enemies")
			if not all_enemies.is_empty():
				targets.append(all_enemies[randi() % all_enemies.size()])
		"random_friendly":
			var all_friendly := _resolve_card_targets_by_name(match_state, trigger, event, "all_friendly")
			if not all_friendly.is_empty():
				targets.append(all_friendly[randi() % all_friendly.size()])
		"random_enemy_in_lane":
			var all_enemies_lane := _resolve_card_targets_by_name(match_state, trigger, event, "all_enemies_in_lane")
			if not all_enemies_lane.is_empty():
				targets.append(all_enemies_lane[randi() % all_enemies_lane.size()])
		"random_friendly_in_lane":
			var all_friendly_lane := _resolve_card_targets_by_name(match_state, trigger, event, "all_friendly_in_lane")
			if not all_friendly_lane.is_empty():
				targets.append(all_friendly_lane[randi() % all_friendly_lane.size()])
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
	return targets


static func _resolve_player_targets(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	var target_player := str(effect.get("target_player", "controller"))
	match target_player:
		"controller":
			return [str(trigger.get("controller_player_id", ""))]
		"opponent":
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), str(trigger.get("controller_player_id", "")))
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
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var lane_index := int(trigger.get("lane_index", -1))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						count += 1
		"friendly_discard_creatures":
			var player := _get_player_state(match_state, controller_player_id)
			if not player.is_empty():
				for card in player.get("discard", []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						count += 1
		"destroyed_enemy_runes":
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var opponent := _get_player_state(match_state, opponent_id)
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


static func _resolve_effect_template(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var template: Dictionary = effect.get("card_template", {})
	if not template.is_empty():
		return template
	var source_cards := _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source")))
	return {} if source_cards.is_empty() else source_cards[0].duplicate(true)


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


static func _get_lane_open_slots(match_state: Dictionary, lane_id: String, player_id: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		var player_slots: Array = lane.get("player_slots", {}).get(player_id, [])
		var slot_capacity := int(lane.get("slot_capacity", 0))
		return {"open_slots": maxi(0, slot_capacity - player_slots.size())}
	return {"open_slots": 0}


static func _resume_pending_rune_breaks(match_state: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var result := {
		"events": [],
		"broken_runes": [],
		"player_lost": false,
		"pending_prophecy_opened": false,
	}
	var queue: Array = match_state.get("pending_rune_break_queue", [])
	while not queue.is_empty() and not has_pending_prophecy(match_state):
		var entry: Dictionary = queue[0]
		queue.remove_at(0)
		var player_id := str(entry.get("player_id", ""))
		var player := _get_player_state(match_state, player_id)
		if player.is_empty():
			continue
		var threshold := int(entry.get("threshold", -1))
		var thresholds: Array = player.get("rune_thresholds", [])
		var threshold_index := -1
		for i in range(thresholds.size()):
			if int(thresholds[i]) == threshold:
				threshold_index = i
				break
		if threshold_index == -1:
			continue
		thresholds.remove_at(threshold_index)
		player["rune_thresholds"] = thresholds
		result["broken_runes"].append(threshold)
		result["events"].append({
			"event_type": EVENT_RUNE_BROKEN,
			"player_id": player_id,
			"threshold": threshold,
			"source_instance_id": str(entry.get("source_instance_id", "")),
			"source_controller_player_id": str(entry.get("source_controller_player_id", "")),
			"causing_player_id": str(entry.get("causing_player_id", entry.get("source_controller_player_id", ""))),
			"reason": str(entry.get("reason", "damage")),
			"draw_card": true,
			"timing_window": str(entry.get("timing_window", WINDOW_INTERRUPT)),
		})
		var draw_result := draw_cards(match_state, player_id, 1, {
			"reason": EVENT_RUNE_BROKEN,
			"source_instance_id": str(entry.get("source_instance_id", "")),
			"source_controller_player_id": str(entry.get("source_controller_player_id", "")),
			"allow_prophecy_interrupt": true,
			"timing_window": str(entry.get("timing_window", WINDOW_INTERRUPT)),
			"rune_threshold": threshold,
		})
		result["events"].append_array(draw_result.get("events", []))
		if bool(draw_result.get("player_lost", false)):
			result["player_lost"] = true
			break
		if bool(draw_result.get("pending_prophecy_opened", false)):
			result["pending_prophecy_opened"] = true
			break
	match_state["pending_rune_break_queue"] = queue
	return result


static func _resolve_out_of_cards(match_state: Dictionary, player_id: String, context: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return {"events": [], "player_lost": false}
	var out_of_cards_card := _build_out_of_cards_card(match_state, player_id)
	player[ZONE_DISCARD].append(out_of_cards_card)
	var out_of_cards_event := {
		"event_type": EVENT_OUT_OF_CARDS_PLAYED,
		"player_id": player_id,
		"source_instance_id": str(out_of_cards_card.get("instance_id", "")),
		"source_zone": ZONE_GENERATED,
		"target_zone": ZONE_DISCARD,
		"reason": RULE_TAG_OUT_OF_CARDS,
		"timing_window": str(context.get("timing_window", WINDOW_IMMEDIATE)),
	}
	var rune_result := destroy_front_rune(match_state, player_id, {
		"reason": RULE_TAG_OUT_OF_CARDS,
		"source_instance_id": str(out_of_cards_card.get("instance_id", "")),
		"source_controller_player_id": player_id,
		"causing_player_id": player_id,
		"timing_window": str(context.get("timing_window", WINDOW_IMMEDIATE)),
	})
	if int(rune_result.get("destroyed_threshold", -1)) > 0:
		out_of_cards_event["destroyed_threshold"] = int(rune_result.get("destroyed_threshold", -1))
		out_of_cards_event["resulting_health"] = int(_get_player_state(match_state, player_id).get("health", 0))
	var events: Array = [out_of_cards_event]
	events.append_array(rune_result.get("events", []))
	return {
		"events": events,
		"player_lost": bool(rune_result.get("player_lost", false)),
		"card": out_of_cards_card,
	}


static func _can_open_prophecy_window(match_state: Dictionary, player_id: String, card: Dictionary) -> bool:
	if str(match_state.get("active_player_id", "")) == player_id:
		return false
	return _is_prophecy_card(card)


static func _open_prophecy_window(match_state: Dictionary, player_id: String, card: Dictionary, context: Dictionary) -> Dictionary:
	var windows: Array = match_state.get("pending_prophecy_windows", [])
	windows.append({
		"player_id": player_id,
		"instance_id": str(card.get("instance_id", "")),
		"source_instance_id": str(context.get("source_instance_id", "")),
		"rune_threshold": int(context.get("rune_threshold", -1)),
		"opened_during_player_id": str(match_state.get("active_player_id", "")),
		"card_type": str(card.get("card_type", "")),
	})
	match_state["pending_prophecy_windows"] = windows
	return {
		"event_type": EVENT_PROPHECY_WINDOW_OPENED,
		"player_id": player_id,
		"source_instance_id": str(context.get("source_instance_id", "")),
		"drawn_instance_id": str(card.get("instance_id", "")),
		"card_type": str(card.get("card_type", "")),
		"reason": RULE_TAG_PROPHECY,
		"free_play": true,
		"rune_threshold": int(context.get("rune_threshold", -1)),
		"timing_window": str(context.get("timing_window", WINDOW_INTERRUPT)),
	}


static func _find_pending_prophecy_window_index(match_state: Dictionary, player_id: String, instance_id: String) -> int:
	var windows: Array = match_state.get("pending_prophecy_windows", [])
	for index in range(windows.size()):
		var window = windows[index]
		if typeof(window) != TYPE_DICTIONARY:
			continue
		if str(window.get("player_id", "")) == player_id and str(window.get("instance_id", "")) == instance_id:
			return index
	return -1


static func _consume_pending_prophecy_window(match_state: Dictionary, index: int) -> Dictionary:
	var windows: Array = match_state.get("pending_prophecy_windows", [])
	if index < 0 or index >= windows.size():
		return {}
	var window = windows[index]
	windows.remove_at(index)
	match_state["pending_prophecy_windows"] = windows
	return window if typeof(window) == TYPE_DICTIONARY else {}


static func _build_out_of_cards_card(match_state: Dictionary, player_id: String) -> Dictionary:
	match_state["out_of_cards_sequence"] = int(match_state.get("out_of_cards_sequence", 0)) + 1
	return {
		"instance_id": "%s_out_of_cards_%03d" % [player_id, int(match_state.get("out_of_cards_sequence", 0))],
		"definition_id": "out_of_cards",
		"name": "Out of Cards",
		"controller_player_id": player_id,
		"owner_player_id": player_id,
		"card_type": "special",
		"cost": 0,
		"zone": ZONE_DISCARD,
		"rules_tags": [RULE_TAG_OUT_OF_CARDS],
		"generated_by_rules": true,
	}


static func _is_prophecy_card(card: Dictionary) -> bool:
	return _dictionary_has_string(card.get("rules_tags", []), RULE_TAG_PROPHECY) or _dictionary_has_string(card.get("keywords", []), RULE_TAG_PROPHECY)


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


static func _is_immune_to_effect(match_state: Dictionary, target_card: Dictionary, effect_type: String) -> bool:
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


static func process_end_of_turn_returns(match_state: Dictionary, turn_number: int) -> void:
	var pending: Array = match_state.get("pending_eot_returns", [])
	if pending.is_empty():
		return
	var remaining: Array = []
	var events: Array = []
	for entry in pending:
		if int(entry.get("turn_number", -1)) != turn_number:
			remaining.append(entry)
			continue
		var snapshot: Dictionary = entry.get("card_snapshot", {})
		var controller_id := str(entry.get("controller_player_id", ""))
		var lane_id := str(entry.get("lane_id", ""))
		if snapshot.is_empty() or controller_id.is_empty() or lane_id.is_empty():
			continue
		var template := {
			"definition_id": str(snapshot.get("definition_id", "")),
			"name": str(snapshot.get("name", "")),
			"card_type": str(snapshot.get("card_type", "creature")),
			"subtypes": snapshot.get("subtypes", []),
			"attributes": snapshot.get("attributes", []),
			"cost": int(snapshot.get("cost", 0)),
			"power": int(snapshot.get("base_power", snapshot.get("power", 0))),
			"health": int(snapshot.get("base_health", snapshot.get("health", 0))),
			"base_power": int(snapshot.get("base_power", 0)),
			"base_health": int(snapshot.get("base_health", 0)),
			"keywords": snapshot.get("keywords", []),
			"rules_text": str(snapshot.get("rules_text", "")),
		}
		if snapshot.has("triggered_abilities"):
			template["triggered_abilities"] = snapshot["triggered_abilities"]
		if snapshot.has("aura"):
			template["aura"] = snapshot["aura"]
		var generated_card := MatchMutations.build_generated_card(match_state, controller_id, template)
		var summon_result := MatchMutations.summon_card_to_lane(match_state, controller_id, generated_card, lane_id, {
			"source_zone": MatchMutations.ZONE_GENERATED,
		})
		if bool(summon_result.get("is_valid", false)):
			events.append_array(summon_result.get("events", []))
			events.append(_build_summon_event(summon_result["card"], controller_id, lane_id, int(summon_result.get("slot_index", -1)), "end_of_turn_return"))
	match_state["pending_eot_returns"] = remaining
	if not events.is_empty():
		publish_events(match_state, events)


static func _event_subject_instance_id(event: Dictionary) -> String:
	return str(event.get("instance_id", event.get("source_instance_id", "")))


static func _event_target_instance_id(event: Dictionary) -> String:
	if event.has("target_instance_id"):
		return str(event.get("target_instance_id", ""))
	if str(event.get("target_type", "")) == "creature":
		return str(event.get("instance_id", ""))
	return ""