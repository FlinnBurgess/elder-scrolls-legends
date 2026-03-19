class_name MatchTurnLoop
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const PHASE_READY_FOR_FIRST_TURN := "ready_for_first_turn"
const PHASE_ACTION := "action"
const MAX_MAGICKA_CAP := 12


static func begin_first_turn(match_state: Dictionary) -> Dictionary:
	if match_state.get("phase", "") != PHASE_READY_FOR_FIRST_TURN:
		push_error("First turn can only begin from ready_for_first_turn.")
		return match_state

	var active_player_id := String(match_state.get("active_player_id", ""))
	if active_player_id.is_empty():
		push_error("Match is missing an active player for first turn start.")
		return match_state

	return _start_turn(match_state, active_player_id)


static func end_turn(match_state: Dictionary, player_id: String) -> Dictionary:
	if not _validate_action_owner(match_state, player_id, "End turn"):
		return match_state
	MatchTiming.publish_events(match_state, [{
		"event_type": MatchTiming.EVENT_TURN_ENDING,
		"player_id": player_id,
		"turn_number": int(match_state.get("turn_number", 0)),
		"source_controller_player_id": player_id,
	}])
	MatchTiming.process_end_of_turn_returns(match_state, int(match_state.get("turn_number", 0)))
	_clear_temporary_stat_bonuses(match_state)

	var player := _get_player_state(match_state, player_id)
	ExtendedMechanicPacks.toggle_wax_wane(player)
	player["current_magicka"] = 0
	player["temporary_magicka"] = 0
	player["ring_of_magicka_used_this_turn"] = false

	var next_player_id := _get_next_player_id(match_state.get("players", []), player_id)
	if next_player_id.is_empty():
		push_error("Could not determine the next player after ending turn.")
		return match_state

	match_state["active_player_id"] = next_player_id
	match_state["priority_player_id"] = next_player_id
	return _start_turn(match_state, next_player_id)


static func gain_temporary_magicka(match_state: Dictionary, player_id: String, amount: int) -> Dictionary:
	if amount <= 0:
		push_error("Temporary magicka gains must be positive.")
		return match_state

	if not _validate_action_owner(match_state, player_id, "Temporary magicka gain"):
		return match_state

	var player := _get_player_state(match_state, player_id)
	player["temporary_magicka"] = int(player.get("temporary_magicka", 0)) + amount
	return match_state


static func activate_ring_of_magicka(match_state: Dictionary, player_id: String) -> Dictionary:
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
	var player := _get_player_state(match_state, player_id)
	ExtendedMechanicPacks.ensure_player_state(player)
	ExtendedMechanicPacks.reset_turn_state(player)
	_refresh_board_state_for_turn(match_state, player_id)
	player["turns_started"] = int(player.get("turns_started", 0)) + 1
	player["temporary_magicka"] = 0
	var current_max := int(player.get("max_magicka", 0))
	player["max_magicka"] = maxi(current_max, mini(MAX_MAGICKA_CAP, current_max + 1))
	player["current_magicka"] = int(player["max_magicka"])
	player["ring_of_magicka_used_this_turn"] = false

	match_state["turn_number"] = int(match_state.get("turn_number", 0)) + 1
	match_state["priority_player_id"] = player_id
	match_state["resolved_turn_triggers"] = {}
	var draw_result := MatchTiming.draw_cards(match_state, player_id, 1, {
		"reason": MatchTiming.EVENT_TURN_STARTED,
		"source_controller_player_id": player_id,
	})
	var events: Array = draw_result.get("events", []).duplicate(true)
	var drawn_cards: Array = draw_result.get("cards", [])
	var drawn_instance_id := ""
	if not drawn_cards.is_empty():
		drawn_instance_id = str(drawn_cards[0].get("instance_id", ""))
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
	return match_state


static func _refresh_board_state_for_turn(match_state: Dictionary, player_id: String) -> void:
	var current_turn_number := int(match_state.get("turn_number", 0))
	var regenerate_events: Array = []
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		if not player_slots_by_id.has(player_id):
			continue

		var slots: Array = player_slots_by_id[player_id]
		for slot_index in range(slots.size()):
			var card = slots[slot_index]
			if card == null:
				continue

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