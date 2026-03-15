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
	]


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
		drawn_card["zone"] = ZONE_HAND
		player[ZONE_HAND].append(drawn_card)
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
	var play_cost := 0 if played_for_free else int(played_card.get("cost", 0)) + (1 if bool(options.get("exalt", false)) else 0)
	if play_cost > _get_available_magicka(player):
		return _invalid_result("Player does not have enough magicka to play %s." % instance_id)
	if play_cost > 0:
		_spend_magicka(match_state, player_id, play_cost)
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
	var result := {
		"processed_events": processed_events,
		"trigger_resolutions": trigger_resolutions,
	}
	match_state["last_timing_result"] = result
	return result


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
	match_state["trigger_registry"] = registry.duplicate(true)
	return registry


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
	var event_type := str(event.get("event_type", ""))
	var family := str(descriptor.get("family", ""))
	var family_spec: Dictionary = FAMILY_SPECS.get(family, {})
	var expected_event_type := str(descriptor.get("event_type", family_spec.get("event_type", "")))
	if event_type != expected_event_type:
		return false
	if not _matches_trigger_role(trigger, descriptor, family_spec, event):
		return false
	return _matches_conditions(match_state, trigger, descriptor, family_spec, event)


static func _matches_required_zone(trigger: Dictionary, descriptor: Dictionary) -> bool:
	if descriptor.has("required_zone"):
		return str(descriptor.get("required_zone", "")) == str(trigger.get("source_zone", ""))
	var required_zones = descriptor.get("required_zones", [])
	if typeof(required_zones) == TYPE_ARRAY and not required_zones.is_empty():
		return required_zones.has(str(trigger.get("source_zone", "")))
	return true


static func _matches_trigger_role(trigger: Dictionary, descriptor: Dictionary, family_spec: Dictionary, event: Dictionary) -> bool:
	var source_instance_id := str(trigger.get("source_instance_id", ""))
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var role := str(descriptor.get("match_role", family_spec.get("match_role", "source")))
	match role:
		"controller":
			return str(event.get("player_id", event.get("playing_player_id", ""))) == controller_player_id
		"opponent_player":
			var event_player_id := str(event.get("player_id", event.get("playing_player_id", "")))
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
	var required_damage_kind := str(descriptor.get("damage_kind", ""))
	if not required_damage_kind.is_empty() and str(event.get("damage_kind", "")) != required_damage_kind:
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
	if not bool(descriptor.get("once_per_instance", false)):
		return
	var resolved_once_triggers: Dictionary = match_state.get("resolved_once_triggers", {})
	resolved_once_triggers[str(trigger.get("trigger_id", ""))] = true
	match_state["resolved_once_triggers"] = resolved_once_triggers


static func _is_once_trigger_consumed(match_state: Dictionary, trigger: Dictionary) -> bool:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	if not bool(descriptor.get("once_per_instance", false)):
		return false
	var resolved_once_triggers: Dictionary = match_state.get("resolved_once_triggers", {})
	return bool(resolved_once_triggers.get(str(trigger.get("trigger_id", "")), false))


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
		var op := str(effect.get("op", ""))
		match op:
			"log":
				generated_events.append({
					"event_type": "timing_effect_logged",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"message": str(effect.get("message", str(descriptor.get("family", "trigger")))),
				})
			"modify_stats":
				var stat_multiplier := _resolve_count_multiplier(match_state, trigger, event, effect)
				var total_power := int(effect.get("power", 0)) * stat_multiplier
				var total_health := int(effect.get("health", 0)) * stat_multiplier
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.apply_stat_bonus(card, total_power, total_health, reason)
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
					generated_events.append({
						"event_type": "keyword_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"keyword_id": pick,
					})
			"heal":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var heal_player := _get_player_state(match_state, player_id)
					if heal_player.is_empty():
						continue
					var heal_amount := int(effect.get("amount", 0))
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
					generated_events.append({
						"event_type": "max_magicka_gained",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_player_id": player_id,
						"amount": gain,
					})
			"deal_damage":
				var damage_amount := int(effect.get("amount", 0))
				var damage_source_id := str(trigger.get("source_instance_id", ""))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					if damage_amount <= 0:
						continue
					var damage_result := EvergreenRules.apply_damage_to_creature(card, damage_amount)
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
						var draw_result := draw_cards(match_state, player_id, int(effect.get("count", 1)), {
							"reason": reason,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"source_controller_player_id": str(trigger.get("controller_player_id", "")),
						})
						generated_events.append_array(draw_result.get("events", []))
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
					var silence_result := MatchMutations.silence_card(card, {"reason": reason})
					generated_events.append_array(silence_result.get("events", []))
			"shackle":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.add_status(card, EvergreenRules.STATUS_SHACKLED)
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
					for _i in range(gen_count):
						var generated_card := MatchMutations.build_generated_card(match_state, player_id, gen_template)
						var move_result := MatchMutations.move_card_to_zone(match_state, str(generated_card.get("instance_id", "")), ZONE_HAND, {"reason": reason})
						if bool(move_result.get("is_valid", false)):
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
				var lane_id := str(effect.get("lane_id", effect.get("target_lane_id", event.get("lane_id", ""))))
				if lane_id.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var move_result := MatchMutations.move_card_between_lanes(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")), lane_id, {
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
						continue
					summon_lane_ids.append(single_lane_id)
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
			_:
				var custom_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, effect)
				if bool(custom_result.get("handled", false)):
					generated_events.append_array(custom_result.get("events", []))
	return generated_events


static func _resolve_card_targets(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	var target := str(effect.get("target", "self"))
	return _resolve_card_targets_by_name(match_state, trigger, event, target)


static func _resolve_card_targets_by_name(match_state: Dictionary, trigger: Dictionary, event: Dictionary, target: String) -> Array:
	var targets: Array = []
	match target:
		"self":
			var self_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not self_card.is_empty():
				targets.append(self_card)
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
		var threshold_index := thresholds.find(threshold)
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


static func _event_subject_instance_id(event: Dictionary) -> String:
	return str(event.get("instance_id", event.get("source_instance_id", "")))


static func _event_target_instance_id(event: Dictionary) -> String:
	if event.has("target_instance_id"):
		return str(event.get("target_instance_id", ""))
	if str(event.get("target_type", "")) == "creature":
		return str(event.get("instance_id", ""))
	return ""