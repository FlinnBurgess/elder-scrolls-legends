class_name ErrorReportWriter
extends RefCounted

const REPORT_PATH := "res://reports/error_reports.jsonl"


static func write_report(report: Dictionary) -> void:
	var dir := DirAccess.open("res://")
	if dir != null and not dir.dir_exists("reports"):
		dir.make_dir("reports")
	var file := FileAccess.open(REPORT_PATH, FileAccess.READ_WRITE)
	if file == null:
		# File doesn't exist yet — create it
		file = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ErrorReportWriter: Failed to open report file at %s" % REPORT_PATH)
		return
	file.seek_end()
	file.store_line(JSON.stringify(report))
	file.flush()
	file.close()


static func build_match_snapshot(match_state: Dictionary, match_history_entries: Array) -> Dictionary:
	var snapshot := {}
	var turn_number := int(match_state.get("turn_number", 0))
	var active_player_id := str(match_state.get("active_player_id", ""))
	snapshot["turn"] = {
		"number": turn_number,
		"active_player": active_player_id,
	}

	var players_dict := {}
	var local_id := "player_1"
	for player in match_state.get("players", []):
		var pid := str(player.get("player_id", ""))
		var key := "local" if pid == local_id else "opponent"
		players_dict[key] = _build_player_snapshot(player)
	snapshot["players"] = players_dict

	var board := {}
	var lanes: Array = match_state.get("lanes", [])
	for lane in lanes:
		var lane_id := str(lane.get("lane_id", ""))
		var player_slots: Dictionary = lane.get("player_slots", {})
		var lane_data := {}
		for pid in player_slots.keys():
			var slot_key := "player_cards" if pid == local_id else "opponent_cards"
			var cards: Array = []
			for card in player_slots[pid]:
				if typeof(card) == TYPE_DICTIONARY:
					cards.append(_build_card_snapshot(card))
			lane_data[slot_key] = cards
		board[lane_id] = lane_data
	snapshot["board"] = board

	var supports := {}
	for player in match_state.get("players", []):
		var pid := str(player.get("player_id", ""))
		var key := "local" if pid == local_id else "opponent"
		var support_cards: Array = []
		for card in player.get("support", []):
			if typeof(card) == TYPE_DICTIONARY:
				support_cards.append(_build_card_snapshot(card))
		supports[key] = support_cards
	snapshot["supports"] = supports

	var history: Array = []
	for entry in match_history_entries:
		if typeof(entry) == TYPE_DICTIONARY:
			history.append(_build_history_entry_snapshot(entry))
	snapshot["match_history"] = history

	var ring := {}
	for player in match_state.get("players", []):
		var pid := str(player.get("player_id", ""))
		var key := "local" if pid == local_id else "opponent"
		ring[key] = {
			"has_ring": bool(player.get("has_ring", false)),
			"ring_charges": int(player.get("ring_charges", 0)),
			"ring_used_this_turn": bool(player.get("ring_used_this_turn", false)),
		}
	snapshot["ring_of_magicka"] = ring

	return snapshot


static func build_arena_draft_snapshot(pick_options: Array, deck: Array, current_pick: int, total_picks: int, card_database: Dictionary) -> Dictionary:
	var snapshot := {}
	snapshot["current_pick"] = current_pick
	snapshot["total_picks"] = total_picks

	var options: Array = []
	for card in pick_options:
		if typeof(card) == TYPE_DICTIONARY:
			options.append(_build_card_snapshot(card))
	snapshot["pick_options"] = options

	var deck_cards: Array = []
	for entry in deck:
		var card_id := str(entry.get("card_id", ""))
		var card: Dictionary = card_database.get(card_id, {})
		deck_cards.append({
			"card_id": card_id,
			"name": str(card.get("name", card_id)),
			"quantity": int(entry.get("quantity", 0)),
		})
	snapshot["deck"] = deck_cards

	return snapshot


static func build_deck_editor_snapshot(deck_name: String, deck_attribute_ids: Array, deck_quantities: Dictionary, card_by_id: Dictionary) -> Dictionary:
	var snapshot := {}
	snapshot["deck_name"] = deck_name
	snapshot["deck_attributes"] = deck_attribute_ids.duplicate()

	var deck_cards: Array = []
	for card_id in deck_quantities.keys():
		var qty: int = int(deck_quantities[card_id])
		var card: Dictionary = card_by_id.get(card_id, {})
		deck_cards.append({
			"card_id": card_id,
			"name": str(card.get("name", card_id)),
			"quantity": qty,
		})
	snapshot["deck"] = deck_cards

	return snapshot


# --- Private helpers ---

static func _build_player_snapshot(player: Dictionary) -> Dictionary:
	var hand_cards: Array = []
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY:
			hand_cards.append(_build_card_snapshot(card))

	var discard_cards: Array = []
	for card in player.get("discard", []):
		if typeof(card) == TYPE_DICTIONARY:
			discard_cards.append(_build_card_snapshot(card))

	return {
		"health": int(player.get("health", 0)),
		"magicka": {
			"current": int(player.get("current_magicka", 0)),
			"max": int(player.get("max_magicka", 0)),
		},
		"runes": _get_active_runes(player),
		"hand": hand_cards,
		"discard": discard_cards,
	}


static func _get_active_runes(player: Dictionary) -> Array:
	var thresholds := [25, 20, 15, 10, 5]
	var active: Array = []
	var health := int(player.get("health", 0))
	var rune_count := int(player.get("rune_count", 5))
	# Return the remaining rune thresholds
	for i in range(rune_count):
		if i < thresholds.size():
			active.append(thresholds[i])
	return active


static func _build_card_snapshot(card: Dictionary) -> Dictionary:
	var snapshot := {
		"name": str(card.get("name", "")),
		"card_type": str(card.get("card_type", "")),
		"cost": int(card.get("cost", 0)),
	}
	if card.has("power"):
		snapshot["power"] = int(card.get("power", 0))
	if card.has("health"):
		snapshot["health"] = int(card.get("health", 0))
	if card.has("damage"):
		snapshot["damage"] = int(card.get("damage", 0))
	var keywords: Array = card.get("keywords", [])
	if not keywords.is_empty():
		snapshot["keywords"] = keywords.duplicate()
	var statuses: Array = card.get("statuses", [])
	if not statuses.is_empty():
		snapshot["statuses"] = statuses.duplicate()
	if card.has("rules_text"):
		snapshot["rules_text"] = str(card.get("rules_text", ""))
	return snapshot


static func _build_history_entry_snapshot(entry: Dictionary) -> Dictionary:
	var snapshot := {
		"action_type": str(entry.get("action_type", "")),
		"player_id": str(entry.get("player_id", "")),
	}
	var source_card: Dictionary = entry.get("source_card", {})
	if not source_card.is_empty():
		snapshot["source_card"] = str(source_card.get("name", ""))
	var targets: Array = entry.get("targets", [])
	if not targets.is_empty():
		var target_names: Array = []
		for target in targets:
			if typeof(target) == TYPE_DICTIONARY:
				var target_card: Dictionary = target.get("card", {})
				target_names.append(str(target_card.get("name", "")))
		snapshot["targets"] = target_names
	return snapshot
