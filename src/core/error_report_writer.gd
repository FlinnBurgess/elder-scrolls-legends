class_name ErrorReportWriter
extends RefCounted

const REPORT_DIR := "res://reports/bug-reports"


static func write_report(report: Dictionary) -> void:
	var dir := DirAccess.open("res://")
	if dir != null and not dir.dir_exists("reports"):
		dir.make_dir("reports")
	dir = DirAccess.open("res://reports")
	if dir != null and not dir.dir_exists("bug-reports"):
		dir.make_dir("bug-reports")
	var filename := _generate_id() + ".json"
	var path := REPORT_DIR.path_join(filename)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ErrorReportWriter: Failed to open report file at %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.flush()
	file.close()


static func _generate_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var id := ""
	for i in range(8):
		id += chars[randi() % chars.length()]
	return id


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

	# Global cost reduction auras (e.g. invade gate Daedra discount)
	var cost_auras: Array = match_state.get("card_cost_reduction_auras", [])
	if not cost_auras.is_empty():
		snapshot["card_cost_reduction_auras"] = cost_auras.duplicate(true)

	# Pending state: helps diagnose "can't do X" bugs
	var pending := {}
	if match_state.has("pending_prophecy"):
		var pp = match_state.get("pending_prophecy", {})
		if typeof(pp) == TYPE_DICTIONARY and not pp.is_empty():
			pending["prophecy"] = true
	var pending_choices: Array = match_state.get("pending_player_choices", [])
	if not pending_choices.is_empty():
		pending["player_choices"] = pending_choices.size()
	var pending_summon: Array = match_state.get("pending_summon_effect_targets", [])
	if not pending_summon.is_empty():
		pending["summon_effect_targets"] = pending_summon.size()
	var pending_turn_triggers: Array = match_state.get("pending_turn_trigger_targets", [])
	if not pending_turn_triggers.is_empty():
		pending["turn_trigger_targets"] = pending_turn_triggers.size()
	if not pending.is_empty():
		snapshot["pending"] = pending

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

	var snapshot := {
		"health": int(player.get("health", 0)),
		"magicka": {
			"current": int(player.get("current_magicka", 0)),
			"max": int(player.get("max_magicka", 0)),
		},
		"runes": _get_active_runes(player),
		"hand": hand_cards,
		"discard": discard_cards,
		"deck_size": player.get("deck", []).size(),
	}
	# Turn-scoped counters useful for debugging cost reductions and trigger conditions
	var turn_state := {}
	var _ts_keys := [
		"cards_played_this_turn", "creature_summons_this_turn",
		"noncreature_plays_this_turn", "creatures_died_this_turn",
		"pilfer_or_drain_count_this_turn", "invades_this_turn",
	]
	for key in _ts_keys:
		var val = player.get(key, 0)
		if int(val) != 0:
			turn_state[key] = int(val)
	if not turn_state.is_empty():
		snapshot["turn_state"] = turn_state
	# Active cost modifiers
	var cost_mods := {}
	var next_reduction := int(player.get("next_card_cost_reduction", 0))
	if next_reduction != 0:
		cost_mods["next_card_cost_reduction"] = next_reduction
	var first_lesson := int(player.get("_first_lesson_discount", 0))
	if first_lesson != 0:
		cost_mods["first_lesson_discount"] = first_lesson
	if not cost_mods.is_empty():
		snapshot["cost_modifiers"] = cost_mods
	return snapshot


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
	# Identity: definition_id helps identify upgraded/transformed cards
	var def_id := str(card.get("definition_id", ""))
	if not def_id.is_empty():
		snapshot["definition_id"] = def_id
	if card.has("power"):
		snapshot["power"] = int(card.get("power", 0))
	if card.has("health"):
		snapshot["health"] = int(card.get("health", 0))
	# Damage tracking: damage_marked is the actual damage counter
	var damage_marked := int(card.get("damage_marked", 0))
	if damage_marked > 0:
		snapshot["damage_marked"] = damage_marked
	# Stat modifiers: helps diagnose buff/debuff issues
	var power_bonus := int(card.get("power_bonus", 0))
	var health_bonus := int(card.get("health_bonus", 0))
	if power_bonus != 0:
		snapshot["power_bonus"] = power_bonus
	if health_bonus != 0:
		snapshot["health_bonus"] = health_bonus
	# Keywords: both innate and granted
	var keywords: Array = card.get("keywords", [])
	if not keywords.is_empty():
		snapshot["keywords"] = keywords.duplicate()
	var granted_keywords: Array = card.get("granted_keywords", [])
	if not granted_keywords.is_empty():
		snapshot["granted_keywords"] = granted_keywords.duplicate()
	var statuses: Array = card.get("statuses", [])
	if not statuses.is_empty():
		snapshot["statuses"] = statuses.duplicate()
	if card.has("rules_text"):
		snapshot["rules_text"] = str(card.get("rules_text", ""))
	# Action targeting mode: critical for diagnosing targeting bugs
	var atm := str(card.get("action_target_mode", ""))
	if not atm.is_empty():
		snapshot["action_target_mode"] = atm
	# Shout info
	var shout_level := int(card.get("shout_level", 0))
	if shout_level > 0:
		snapshot["shout_level"] = shout_level
	# Subtypes (tribal effects)
	var subtypes: Array = card.get("subtypes", [])
	if not subtypes.is_empty():
		snapshot["subtypes"] = subtypes.duplicate()
	# Attached items
	var attached_items: Array = card.get("attached_items", [])
	if not attached_items.is_empty():
		var item_summaries: Array = []
		for item in attached_items:
			if typeof(item) == TYPE_DICTIONARY:
				item_summaries.append({"name": str(item.get("name", "")), "definition_id": str(item.get("definition_id", ""))})
		if not item_summaries.is_empty():
			snapshot["attached_items"] = item_summaries
	# Augments (adventure mode)
	var augments: Array = card.get("_augments", [])
	if not augments.is_empty():
		snapshot["augments"] = augments.duplicate()
	# Cost reduction (self)
	var self_cost_reduction = card.get("self_cost_reduction", {})
	if typeof(self_cost_reduction) == TYPE_DICTIONARY and not self_cost_reduction.is_empty():
		snapshot["self_cost_reduction"] = self_cost_reduction.duplicate()
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
