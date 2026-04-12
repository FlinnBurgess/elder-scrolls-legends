class_name MatchTurnLoop
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")
const MatchEffectParams = preload("res://src/core/match/match_effect_params.gd")
const MatchSummonTiming = preload("res://src/core/match/match_summon_timing.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")
const PHASE_READY_FOR_FIRST_TURN := "ready_for_first_turn"
const PHASE_ACTION := "action"
const MAX_MAGICKA_CAP := 12


static func begin_first_turn(match_state: Dictionary) -> Dictionary:
	GameLogger.trc("Turn", "begin_first_turn", "active:%s" % [str(match_state.get("active_player_id", ""))])
	if match_state.get("phase", "") != PHASE_READY_FOR_FIRST_TURN:
		push_error("First turn can only begin from ready_for_first_turn.")
		return match_state

	var active_player_id := String(match_state.get("active_player_id", ""))
	if active_player_id.is_empty():
		push_error("Match is missing an active player for first turn start.")
		return match_state

	ExtendedMechanicPacks.apply_cheesemancer_mutations(match_state)
	return _start_turn(match_state, active_player_id)


static func end_turn(match_state: Dictionary, player_id: String) -> Dictionary:
	GameLogger.trc("Turn", "end_turn", "p:%s,turn:%s" % [player_id, str(match_state.get("turn_number", 0))])
	if not _validate_action_owner(match_state, player_id, "End turn"):
		return match_state
	MatchTiming.publish_events(match_state, [{
		"event_type": MatchTiming.EVENT_TURN_ENDING,
		"player_id": player_id,
		"turn_number": int(match_state.get("turn_number", 0)),
		"source_controller_player_id": player_id,
	}])
	# Preserve end-of-turn events (e.g. Disciple of Namira draws) before
	# _start_turn overwrites last_timing_result with start-of-turn events.
	var end_of_turn_events: Array = match_state.get("last_timing_result", {}).get("processed_events", []).duplicate(true)
	MatchTiming.process_end_of_turn_returns(match_state, int(match_state.get("turn_number", 0)))
	_clear_temporary_stat_bonuses(match_state)

	var player := _get_player_state(match_state, player_id)
	ExtendedMechanicPacks.toggle_wax_wane(player)
	player["_dual_wax_wane"] = false
	player["_unspent_magicka_last_turn"] = int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
	player["current_magicka"] = 0
	player["temporary_magicka"] = 0
	player["ring_of_magicka_used_this_turn"] = false

	var next_player_id := _get_next_player_id(match_state.get("players", []), player_id)
	if next_player_id.is_empty():
		push_error("Could not determine the next player after ending turn.")
		return match_state

	match_state["active_player_id"] = next_player_id
	match_state["priority_player_id"] = next_player_id
	_start_turn(match_state, next_player_id)
	# Merge end-of-turn events into the final timing result so the UI
	# can animate triggers that fired during the turn_ending phase.
	if not end_of_turn_events.is_empty():
		var final_result: Dictionary = match_state.get("last_timing_result", {})
		var combined: Array = end_of_turn_events + final_result.get("processed_events", [])
		final_result["processed_events"] = combined
		match_state["last_timing_result"] = final_result
	return match_state


static func gain_temporary_magicka(match_state: Dictionary, player_id: String, amount: int) -> Dictionary:
	GameLogger.trc("Turn", "gain_temp_magicka", "p:%s,amt:%s" % [player_id, str(amount)])
	if amount <= 0:
		push_error("Temporary magicka gains must be positive.")
		return match_state

	if not _validate_action_owner(match_state, player_id, "Temporary magicka gain"):
		return match_state

	var player := _get_player_state(match_state, player_id)
	player["temporary_magicka"] = int(player.get("temporary_magicka", 0)) + amount
	return match_state


static func activate_ring_of_magicka(match_state: Dictionary, player_id: String) -> Dictionary:
	GameLogger.trc("Turn", "ring_activate", "p:%s" % [player_id])
	if not _validate_action_owner(match_state, player_id, "Ring of Magicka activation"):
		return match_state

	var player := _get_player_state(match_state, player_id)
	if not bool(player.get("has_ring_of_magicka", false)):
		push_error("Player does not have the Ring of Magicka.")
		return match_state

	if int(player.get("ring_of_magicka_charges", 0)) <= 0:
		push_error("Ring of Magicka has no charges remaining.")
		return match_state

	if bool(player.get("ring_of_magicka_used_this_turn", false)):
		push_error("Ring of Magicka can only be activated once per turn.")
		return match_state

	player["ring_of_magicka_used_this_turn"] = true
	player["ring_of_magicka_charges"] = int(player.get("ring_of_magicka_charges", 0)) - 1
	player["temporary_magicka"] = int(player.get("temporary_magicka", 0)) + 1

	if int(player["ring_of_magicka_charges"]) <= 0:
		player["ring_of_magicka_charges"] = 0
		player["has_ring_of_magicka"] = false

	return match_state


static func can_activate_ring_of_magicka(match_state: Dictionary, player_id: String) -> bool:
	if match_state.get("phase", "") != PHASE_ACTION:
		return false

	if String(match_state.get("active_player_id", "")) != player_id:
		return false

	var player := _get_player_state_silent(match_state, player_id)
	if player.is_empty():
		return false

	return (
		bool(player.get("has_ring_of_magicka", false)) and
		int(player.get("ring_of_magicka_charges", 0)) > 0 and
		not bool(player.get("ring_of_magicka_used_this_turn", false))
	)


static func spend_magicka(match_state: Dictionary, player_id: String, amount: int) -> Dictionary:
	GameLogger.trc("Turn", "spend_magicka", "p:%s,amt:%s" % [player_id, str(amount)])
	if amount <= 0:
		push_error("Magicka spend amount must be positive.")
		return match_state

	if not _validate_action_owner(match_state, player_id, "Spend magicka"):
		return match_state

	var player := _get_player_state(match_state, player_id)
	var available := get_available_magicka(player)
	if available < amount:
		push_error("Player does not have enough available magicka.")
		return match_state

	var remaining := amount
	var temporary_to_spend := mini(int(player.get("temporary_magicka", 0)), remaining)
	player["temporary_magicka"] = int(player.get("temporary_magicka", 0)) - temporary_to_spend
	remaining -= temporary_to_spend

	if remaining > 0:
		player["current_magicka"] = int(player.get("current_magicka", 0)) - remaining

	return match_state


static func get_available_magicka(player_state: Dictionary) -> int:
	return int(player_state.get("current_magicka", 0)) + int(player_state.get("temporary_magicka", 0))


static func _start_turn(match_state: Dictionary, player_id: String) -> Dictionary:
	GameLogger.trc("Turn", "_start_turn", "p:%s,turn:%s" % [player_id, str(int(match_state.get("turn_number", 0)) + 1)])
	var player := _get_player_state(match_state, player_id)
	ExtendedMechanicPacks.ensure_player_state(player)
	ExtendedMechanicPacks.reset_turn_state(player)
	_refresh_board_state_for_turn(match_state, player_id)
	player["turns_started"] = int(player.get("turns_started", 0)) + 1
	player["temporary_magicka"] = 0
	var suppress_magicka := bool(match_state.get("puzzle_suppress_magicka_gain", false))
	var magicka_gained := 0
	if not suppress_magicka:
		var current_max := int(player.get("max_magicka", 0))
		var new_max := maxi(current_max, mini(MAX_MAGICKA_CAP, current_max + 1))
		magicka_gained = new_max - current_max
		player["max_magicka"] = new_max
	player["current_magicka"] = int(player["max_magicka"])
	player["ring_of_magicka_used_this_turn"] = false

	match_state["turn_number"] = int(match_state.get("turn_number", 0)) + 1
	match_state["priority_player_id"] = player_id
	match_state["resolved_turn_triggers"] = {}
	if magicka_gained > 0:
		MatchTiming.publish_events(match_state, [{
			"event_type": "max_magicka_gained",
			"source_instance_id": "",
			"target_player_id": player_id,
			"amount": magicka_gained,
		}])
	var events: Array = []
	var drawn_instance_id := ""
	if not bool(match_state.get("puzzle_suppress_draw", false)):
		var draw_result := MatchTiming.draw_cards(match_state, player_id, 1, {
			"reason": MatchTiming.EVENT_TURN_STARTED,
			"source_controller_player_id": player_id,
		})
		events = draw_result.get("events", []).duplicate(true)
		var drawn_cards: Array = draw_result.get("cards", [])
		if not drawn_cards.is_empty():
			drawn_instance_id = str(drawn_cards[0].get("instance_id", ""))
	if int(player.get("turns_started", 0)) == 1:
		var first_turn_magicka_bonus := 0
		for hand_card in player.get("hand", []):
			if typeof(hand_card) == TYPE_DICTIONARY:
				MatchMutations.apply_first_turn_hand_cost(match_state, hand_card, player_id)
				first_turn_magicka_bonus += int(hand_card.get("first_turn_hand_magicka", 0))
		if first_turn_magicka_bonus > 0:
			player["temporary_magicka"] = int(player.get("temporary_magicka", 0)) + first_turn_magicka_bonus
	MatchTiming.process_delayed_destroys(match_state, player_id)
	if str(match_state.get("winner_player_id", "")).is_empty():
		match_state["phase"] = PHASE_ACTION
		events.append({
			"event_type": MatchTiming.EVENT_TURN_STARTED,
			"player_id": player_id,
			"turn_number": int(match_state.get("turn_number", 0)),
			"source_controller_player_id": player_id,
			"drawn_instance_id": drawn_instance_id,
		})
	else:
		match_state["phase"] = "complete"
	if not events.is_empty():
		MatchTiming.publish_events(match_state, events)
	_resolve_forced_attacks(match_state, player_id)
	_process_discard_return_timers(match_state, player_id)
	return match_state


static func _process_discard_return_timers(match_state: Dictionary, player_id: String) -> void:
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return
	var discard: Array = player.get("discard", [])
	var to_return: Array = []
	for card in discard:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if not card.has("_return_from_discard_timer"):
			continue
		if str(card.get("_return_from_discard_controller", "")) != player_id:
			continue
		var remaining := int(card.get("_return_from_discard_timer", 0)) - 1
		if remaining <= 0:
			to_return.append(card)
		else:
			card["_return_from_discard_timer"] = remaining
	for card in to_return:
		var lanes: Array = match_state.get("lanes", [])
		var candidate_lanes: Array = []
		for lane in lanes:
			var lane_id := str(lane.get("lane_id", ""))
			var open := MatchTimingHelpers._get_lane_open_slots(match_state, lane_id, player_id)
			if int(open.get("open_slots", 0)) > 0:
				candidate_lanes.append(lane_id)
		if candidate_lanes.is_empty():
			card["_return_from_discard_timer"] = 1
			continue
		var lane_idx := MatchEffectParams._deterministic_index(match_state, "return_discard_lane_%s_%s" % [str(card.get("instance_id", "")), str(match_state.get("turn_number", 0))], candidate_lanes.size())
		var target_lane := str(candidate_lanes[lane_idx])
		MatchMutations.restore_definition_state(card)
		card.erase("_return_from_discard_timer")
		card.erase("_return_from_discard_controller")
		var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, str(card.get("instance_id", "")), target_lane, {})
		if bool(summon_result.get("is_valid", false)):
			var summon_events: Array = summon_result.get("events", [])
			summon_events.append(MatchSummonTiming._build_summon_event(summon_result["card"], player_id, target_lane, int(summon_result.get("slot_index", -1)), "return_from_discard"))
			MatchTiming.publish_events(match_state, summon_events)


static func _refresh_board_state_for_turn(match_state: Dictionary, player_id: String) -> void:
	var current_turn_number := int(match_state.get("turn_number", 0))
	var regenerate_events: Array = []
	for lane in match_state.get("lanes", []):
		lane["_attacks_this_turn"] = 0
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		if not player_slots_by_id.has(player_id):
			continue

		var slots: Array = player_slots_by_id[player_id]
		for slot_index in range(slots.size()):
			var card = slots[slot_index]
			if card == null:
				continue

			# Clear persistent shackle if source creature is no longer in play
			var pss_source_id := str(card.get("_shackle_persistent_source_id", ""))
			if not pss_source_id.is_empty():
				var pss_loc := MatchMutations.find_card_location(match_state, pss_source_id)
				if not bool(pss_loc.get("is_valid", false)) or str(pss_loc.get("zone", "")) != "lane":
					EvergreenRules.remove_status(card, EvergreenRules.STATUS_SHACKLED)
					card.erase("shackle_expires_on_turn")
					card.erase("_shackle_persistent_source_id")

			var result := EvergreenRules.refresh_for_controller_turn(card, current_turn_number)
			var regen_healed := int(result.get("regenerate_healed", 0))
			if regen_healed > 0:
				regenerate_events.append({
					"event_type": "creature_healed",
					"source_instance_id": str(card.get("instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"amount": regen_healed,
					"reason": "regenerate",
				})

	var player := _get_player_state(match_state, player_id)
	for support in player.get("support", []):
		if typeof(support) != TYPE_DICTIONARY:
			continue
		PersistentCardRules.refresh_support_for_controller_turn(support)

	if not regenerate_events.is_empty():
		MatchTiming.publish_events(match_state, regenerate_events)


static func _clear_temporary_stat_bonuses(match_state: Dictionary) -> void:
	var current_turn := int(match_state.get("turn_number", 0))
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id:
			var slots: Array = player_slots_by_id[player_id]
			for card in slots:
				if card == null or typeof(card) != TYPE_DICTIONARY:
					continue
				EvergreenRules.clear_temporary_stat_bonuses(card, current_turn)
				EvergreenRules.clear_temporary_keywords(card, current_turn)
				var ta_list: Array = card.get("triggered_abilities", [])
				var ta_filtered: Array = ta_list.filter(func(ta):
					if bool(ta.get("_temporary", false)):
						return false
					if ta.has("expires_on_turn") and int(ta.get("expires_on_turn", -1)) < current_turn:
						return false
					if ta.has("_expires_on_turn") and int(ta.get("_expires_on_turn", -1)) < current_turn:
						return false
					return true
				)
				if ta_filtered.size() != ta_list.size():
					card["triggered_abilities"] = ta_filtered
				var temp_statuses: Array = card.get("_temp_statuses", [])
				for status_id in temp_statuses:
					EvergreenRules.remove_status(card, str(status_id))
				if not temp_statuses.is_empty():
					card["_temp_statuses"] = []
				# Promote next-turn temp statuses to temp statuses (expire next end-of-turn)
				var next_turn_temps: Array = card.get("_next_turn_temp_statuses", [])
				if not next_turn_temps.is_empty():
					var promoted: Array = card.get("_temp_statuses", [])
					promoted.append_array(next_turn_temps)
					card["_temp_statuses"] = promoted
					card["_next_turn_temp_statuses"] = []


static func _expire_shadow_cover_if_needed(card: Dictionary, current_turn_number: int) -> void:
	EvergreenRules.refresh_for_controller_turn(card, current_turn_number)


static func _validate_action_owner(match_state: Dictionary, player_id: String, action_name: String) -> bool:
	if match_state.get("phase", "") != PHASE_ACTION:
		push_error("%s can only be used during the action phase." % action_name)
		return false

	if String(match_state.get("active_player_id", "")) != player_id:
		push_error("%s is only legal for the active player." % action_name)
		return false

	if _find_player_index(match_state.get("players", []), player_id) == -1:
		push_error("Unknown player_id: %s" % player_id)
		return false

	return true


static func _get_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	var players: Array = match_state.get("players", [])
	var player_index := _find_player_index(players, player_id)
	if player_index == -1:
		push_error("Unknown player_id: %s" % player_id)
		return {}
	return players[player_index]


static func _get_player_state_silent(match_state: Dictionary, player_id: String) -> Dictionary:
	var players: Array = match_state.get("players", [])
	var player_index := _find_player_index(players, player_id)
	if player_index == -1:
		return {}
	return players[player_index]


static func _get_next_player_id(players: Array, player_id: String) -> String:
	if players.size() != 2:
		return ""

	for player in players:
		if String(player.get("player_id", "")) != player_id:
			return String(player.get("player_id", ""))
	return ""


static func _find_player_index(players: Array, player_id: String) -> int:
	for index in range(players.size()):
		if players[index].get("player_id", "") == player_id:
			return index
	return -1


static func _resolve_forced_attacks(match_state: Dictionary, player_id: String) -> void:
	if not str(match_state.get("winner_player_id", "")).is_empty():
		return
	var opposing_id := _get_next_player_id(match_state.get("players", []), player_id)
	if opposing_id.is_empty():
		return
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots: Array = lane.get("player_slots", {}).get(player_id, [])
		for card in player_slots:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if not _has_forced_attack_item(card):
				continue
			var target := _pick_forced_attack_target(match_state, card, lane_index, player_id, opposing_id)
			if target.is_empty():
				GameLogger.trc("Turn", "_resolve_forced_attacks", "skip:%s,no_targets" % str(card.get("name", card.get("instance_id", ""))))
				continue
			GameLogger.trc("Turn", "_resolve_forced_attacks", "atk:%s,tgt:%s" % [str(card.get("instance_id", "")), str(target.get("instance_id", ""))])
			MatchCombat.resolve_attack(match_state, player_id, str(card.get("instance_id", "")), target)
			if not str(match_state.get("winner_player_id", "")).is_empty():
				return


static func _has_forced_attack_item(card: Dictionary) -> bool:
	for item in EvergreenRules.get_attached_items(card):
		if typeof(item) == TYPE_DICTIONARY and bool(item.get("grants_forced_attack_at_turn_start", false)):
			return true
	return false


static func _pick_forced_attack_target(match_state: Dictionary, attacker: Dictionary, lane_index: int, _player_id: String, opposing_id: String) -> Dictionary:
	var lanes: Array = match_state.get("lanes", [])
	if lane_index < 0 or lane_index >= lanes.size():
		return {}
	# Collect guards for this lane (including guards_both_lanes from other lanes)
	var guard_ids: Array = []
	var lane: Dictionary = lanes[lane_index]
	var enemy_slots: Array = lane.get("player_slots", {}).get(opposing_id, [])
	for card in enemy_slots:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
			guard_ids.append(str(card.get("instance_id", "")))
	for other_li in range(lanes.size()):
		if other_li == lane_index:
			continue
		for card in lanes[other_li].get("player_slots", {}).get(opposing_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD) and EvergreenRules.has_status(card, "guards_both_lanes"):
				var cid := str(card.get("instance_id", ""))
				if not guard_ids.has(cid):
					guard_ids.append(cid)
	var attacker_ignores_guard := EvergreenRules.has_status(attacker, "ignore_guard")
	var has_guards := not guard_ids.is_empty() and not attacker_ignores_guard
	# Build candidate list from same-lane enemies
	var candidates: Array = []
	for card in enemy_slots:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var cid := str(card.get("instance_id", ""))
		if has_guards and not guard_ids.has(cid):
			continue
		candidates.append(card)
	if candidates.is_empty():
		return {}
	var pick: Dictionary = candidates[MatchEffectParams._deterministic_index(match_state, str(attacker.get("instance_id", "")) + "_forced_atk", candidates.size())]
	return {"type": "creature", "instance_id": str(pick.get("instance_id", ""))}