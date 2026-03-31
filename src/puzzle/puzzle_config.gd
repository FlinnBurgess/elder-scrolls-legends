class_name PuzzleConfig
extends RefCounted

## Builds match state dictionaries from puzzle configuration dictionaries.
##
## Puzzle configs define a board state for kill-or-survive puzzles.
## The player always goes first on turn 1. Magicka is fixed (no turn gain),
## card draw is suppressed (only card-effect draws), and mulligan is skipped.

const LANE_REGISTRY_PATH := "res://data/legends/registries/lane_registry.json"
const STANDARD_RUNE_THRESHOLDS := [25, 20, 15, 10, 5]


static func build_puzzle_match_state(config: Dictionary) -> Dictionary:
	var puzzle_type := str(config.get("type", "kill"))
	var puzzle_name := str(config.get("name", "Untitled Puzzle"))

	var p_cfg: Dictionary = config.get("player", {})
	var e_cfg: Dictionary = config.get("enemy", {})

	var p_health := int(p_cfg.get("health", 30))
	var e_health := int(e_cfg.get("health", 30))
	var p_max_magicka := int(p_cfg.get("max_magicka", 12))
	var p_cur_magicka := int(p_cfg.get("current_magicka", p_max_magicka))
	var e_max_magicka := int(e_cfg.get("max_magicka", 3))
	var e_cur_magicka := int(e_cfg.get("current_magicka", e_max_magicka))
	var has_ring := bool(p_cfg.get("has_ring", false))

	var p_hand_ids := _to_string_array(p_cfg.get("hand", []))
	var p_deck_ids := _to_string_array(p_cfg.get("deck", []))
	var p_discard_ids := _to_string_array(p_cfg.get("discard", []))
	var p_support_ids := _to_string_array(p_cfg.get("supports", []))
	var p_field := _build_lane_creatures("player_1", p_cfg.get("field_creatures", []))
	var p_shadow := _build_lane_creatures("player_1", p_cfg.get("shadow_creatures", []))

	var e_hand_ids := _to_string_array(e_cfg.get("hand", []))
	var e_deck_ids := _to_string_array(e_cfg.get("deck", []))
	var e_discard_ids := _to_string_array(e_cfg.get("discard", []))
	var e_support_ids := _to_string_array(e_cfg.get("supports", []))
	var e_field := _build_lane_creatures("player_2", e_cfg.get("field_creatures", []))
	var e_shadow := _build_lane_creatures("player_2", e_cfg.get("shadow_creatures", []))

	_reassign_instance_ids("player_1", p_hand_ids, p_deck_ids, p_field, p_shadow, p_discard_ids)
	_reassign_instance_ids("player_2", e_hand_ids, e_deck_ids, e_field, e_shadow, e_discard_ids)

	var p_runes := _runes_for_health(p_health)
	var e_runes := []  # Puzzles: enemy starts with no runes remaining

	var p1 := _build_player("player_1", p_health, p_max_magicka, p_cur_magicka,
		p_runes, has_ring, 3 if has_ring else 0, p_hand_ids, p_deck_ids, p_discard_ids)
	var p2 := _build_player("player_2", e_health, e_max_magicka, e_cur_magicka,
		e_runes, false, 0, e_hand_ids, e_deck_ids, e_discard_ids)

	# Place supports
	var p1_support_start: int = p_hand_ids.size() + p_deck_ids.size() + p_discard_ids.size() + p_field.size() + p_shadow.size() + 1
	for i in range(p_support_ids.size()):
		p1["support"].append(_make_card("player_1", p_support_ids[i], "support", p1_support_start + i))
	var p2_support_start: int = e_hand_ids.size() + e_deck_ids.size() + e_discard_ids.size() + e_field.size() + e_shadow.size() + 1
	for i in range(e_support_ids.size()):
		p2["support"].append(_make_card("player_2", e_support_ids[i], "support", p2_support_start + i))

	var lanes := _build_lanes(config.get("lanes", []), p_field, p_shadow, e_field, e_shadow)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	return {
		"rules_version": "0.1.0",
		"match_format": "puzzle",
		"phase": "action",
		"turn_number": 1,
		"winner_player_id": "",
		"event_log": [],
		"replay_log": [],
		"pending_event_queue": [],
		"trigger_registry": [],
		"last_timing_result": {"processed_events": [], "trigger_resolutions": []},
		"resolved_once_triggers": {},
		"next_event_sequence": 0,
		"next_trigger_resolution_sequence": 0,
		"starting_player_id": "player_1",
		"active_player_id": "player_1",
		"priority_player_id": "player_1",
		"rng_seed": rng.randi(),
		"rng_state": rng.state,
		"players": [p1, p2],
		"lanes": lanes,
		"mulligan": {"pending_player_ids": []},
		"puzzle_mode": true,
		"puzzle_type": puzzle_type,
		"puzzle_name": puzzle_name,
		"puzzle_suppress_draw": true,
		"puzzle_suppress_magicka_gain": true,
	}


static func validate_config(config: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var name_str := str(config.get("name", ""))
	if name_str.is_empty():
		errors.append("Puzzle name is required.")
	elif name_str.length() > 40:
		errors.append("Puzzle name must be 40 characters or fewer.")

	var ptype := str(config.get("type", ""))
	if ptype != "kill" and ptype != "survive":
		errors.append("Puzzle type must be 'kill' or 'survive'.")

	var lanes_cfg: Array = []
	var raw_lanes = config.get("lanes", [])
	if typeof(raw_lanes) == TYPE_ARRAY:
		lanes_cfg = raw_lanes
	if lanes_cfg.size() != 2:
		errors.append("Exactly 2 lanes required.")
	else:
		var total_width := 0
		for lane in lanes_cfg:
			var w := int(lane.get("width", 0))
			if w < 1:
				errors.append("Each lane width must be at least 1.")
			total_width += w
		if total_width != 8:
			errors.append("Lane widths must sum to 8 (got %d)." % total_width)

	for side_key in ["player", "enemy"]:
		var side: Dictionary = config.get(side_key, {})
		var max_m := int(side.get("max_magicka", 0))
		var cur_m := int(side.get("current_magicka", 0))
		if max_m < 0:
			errors.append("%s max magicka must be non-negative." % side_key.capitalize())
		if cur_m < 0:
			errors.append("%s current magicka must be non-negative." % side_key.capitalize())

	return {"valid": errors.is_empty(), "errors": errors}


static func _runes_for_health(health: int) -> Array:
	var runes: Array = []
	for threshold in STANDARD_RUNE_THRESHOLDS:
		if threshold <= health:
			runes.append(threshold)
	return runes


static func _to_string_array(input) -> Array:
	var result: Array = []
	if typeof(input) != TYPE_ARRAY:
		return result
	for item in input:
		result.append(str(item))
	return result


static func _build_lane_creatures(player_id: String, entries) -> Array:
	var creatures: Array = []
	if typeof(entries) != TYPE_ARRAY:
		return creatures
	for i in range(entries.size()):
		var entry = entries[i]
		if typeof(entry) == TYPE_STRING:
			creatures.append(_make_lane_creature(player_id, entry, 100 + i))
		elif typeof(entry) == TYPE_DICTIONARY:
			var def_id := str(entry.get("definition_id", ""))
			var overrides := {}
			for key in entry:
				if key != "definition_id" and key != "extras":
					overrides[key] = entry[key]
			var creature := _make_lane_creature(player_id, def_id, 100 + i, overrides)
			var extras = entry.get("extras", {})
			if typeof(extras) == TYPE_DICTIONARY:
				for key in extras:
					creature[key] = extras[key]
			creatures.append(creature)
	return creatures


static func _build_player(player_id: String, health: int, max_magicka: int,
		current_magicka: int, rune_thresholds: Array, has_ring: bool,
		ring_charges: int, hand_ids: Array, deck_ids: Array,
		discard_ids: Array = []) -> Dictionary:
	var hand: Array = []
	for i in range(hand_ids.size()):
		hand.append(_make_card(player_id, hand_ids[i], "hand", hand.size() + 1))
	var deck: Array = []
	var reversed_ids := deck_ids.duplicate()
	reversed_ids.reverse()
	for i in range(reversed_ids.size()):
		deck.append(_make_card(player_id, reversed_ids[i], "deck", hand.size() + deck.size() + 1))
	var discard: Array = []
	var discard_start_index := hand.size() + deck.size() + 1
	for i in range(discard_ids.size()):
		discard.append(_make_card(player_id, discard_ids[i], "discard", discard_start_index + i))

	return {
		"player_id": player_id,
		"health": health,
		"rune_thresholds": rune_thresholds.duplicate(),
		"deck": deck,
		"hand": hand,
		"support": [],
		"discard": discard,
		"banished": [],
		"max_magicka": max_magicka,
		"current_magicka": current_magicka,
		"temporary_magicka": 0,
		"turns_started": 1,
		"has_ring_of_magicka": has_ring,
		"ring_of_magicka_charges": ring_charges if has_ring else 0,
		"ring_of_magicka_used_this_turn": false,
		"mulligan_complete": true,
		"mulligan_discarded_instance_ids": [],
	}


static func _make_card(player_id: String, definition_id: String, zone: String, index: int) -> Dictionary:
	return {
		"instance_id": "%s_card_%03d" % [player_id, index],
		"definition_id": definition_id,
		"owner_player_id": player_id,
		"controller_player_id": player_id,
		"zone": zone,
		"keywords": [],
		"granted_keywords": [],
		"status_markers": [],
		"triggered_abilities": [],
		"damage_marked": 0,
		"power_bonus": 0,
		"health_bonus": 0,
	}


static func _make_lane_creature(player_id: String, definition_id: String,
		index: int, overrides: Dictionary = {}) -> Dictionary:
	var card := _make_card(player_id, definition_id, "lane", index)
	card["can_attack"] = overrides.get("can_attack", true)
	card["turns_in_play"] = overrides.get("turns_in_play", 1)
	card["attached_items"] = []
	if overrides.has("damage_marked"):
		card["damage_marked"] = int(overrides["damage_marked"])
	if overrides.has("power_bonus"):
		card["power_bonus"] = int(overrides["power_bonus"])
	if overrides.has("health_bonus"):
		card["health_bonus"] = int(overrides["health_bonus"])
	if overrides.has("keywords"):
		card["keywords"] = overrides["keywords"].duplicate()
	if overrides.has("granted_keywords"):
		card["granted_keywords"] = overrides["granted_keywords"].duplicate()
	if overrides.has("status_markers"):
		card["status_markers"] = overrides["status_markers"].duplicate()
	return card


static func _reassign_instance_ids(player_id: String, hand_ids: Array,
		deck_ids: Array, field_creatures: Array, shadow_creatures: Array,
		discard_ids: Array = []) -> void:
	var next_index := hand_ids.size() + deck_ids.size() + discard_ids.size() + 1
	for creature in field_creatures:
		creature["instance_id"] = "%s_card_%03d" % [player_id, next_index]
		next_index += 1
	for creature in shadow_creatures:
		creature["instance_id"] = "%s_card_%03d" % [player_id, next_index]
		next_index += 1


static func _build_lanes(lanes_cfg: Array, p1_field: Array, p1_shadow: Array,
		p2_field: Array, p2_shadow: Array) -> Array:
	var lane_registry := _load_lane_registry()
	var lane_type_lookup := {}
	for raw_record in lane_registry.get("lane_types", []):
		if typeof(raw_record) == TYPE_DICTIONARY:
			lane_type_lookup[str(raw_record.get("id", ""))] = raw_record

	# Map lane index to creature arrays: index 0 = field, index 1 = shadow
	var creature_arrays := [
		{"player_1": p1_field, "player_2": p2_field},
		{"player_1": p1_shadow, "player_2": p2_shadow},
	]

	var lane_ids: Array[String] = ["field", "shadow"]
	var lanes: Array = []

	for lane_idx in range(lanes_cfg.size()):
		var lane_cfg: Dictionary = lanes_cfg[lane_idx] if lane_idx < lanes_cfg.size() else {}
		var lane_type_id := str(lane_cfg.get("lane_type", lane_ids[lane_idx]))
		var slot_capacity := int(lane_cfg.get("width", 4))
		var lane_id := lane_ids[lane_idx]
		var lane_record: Dictionary = lane_type_lookup.get(lane_type_id, {})
		var lane_creatures: Dictionary = creature_arrays[lane_idx]

		var lane_rule_payload := {}
		if not lane_record.is_empty():
			var availability: Array = []
			var raw_avail = lane_record.get("availability", [])
			if typeof(raw_avail) == TYPE_ARRAY:
				availability = raw_avail.duplicate()
			var source_ids: Array = []
			var raw_sources = lane_record.get("source_ids", [])
			if typeof(raw_sources) == TYPE_ARRAY:
				source_ids = raw_sources.duplicate()
			var effects: Array = []
			var raw_effects = lane_record.get("effects", [])
			if typeof(raw_effects) == TYPE_ARRAY:
				effects = raw_effects.duplicate(true)
			lane_rule_payload = {
				"display_name": str(lane_record.get("display_name", lane_id)),
				"description": str(lane_record.get("description", "")),
				"icon": str(lane_record.get("icon", "")),
				"implementation_bucket": str(lane_record.get("implementation_bucket", "")),
				"availability": availability,
				"source_ids": source_ids,
				"effects": effects,
			}

		var player_slots := {
			"player_1": lane_creatures.get("player_1", []).duplicate(true),
			"player_2": lane_creatures.get("player_2", []).duplicate(true),
		}
		for pid in player_slots:
			var slot_list: Array = player_slots[pid]
			for slot_index in range(slot_list.size()):
				var creature = slot_list[slot_index]
				if typeof(creature) == TYPE_DICTIONARY:
					creature["lane_id"] = lane_id
					creature["slot_index"] = slot_index
					if not creature.has("entered_lane_on_turn"):
						creature["entered_lane_on_turn"] = 0
		lanes.append({
			"lane_id": lane_id,
			"lane_type": lane_record.get("id", lane_id),
			"slot_capacity": slot_capacity,
			"player_slots": player_slots,
			"lane_rule_payload": lane_rule_payload,
		})

	return lanes


static func _load_lane_registry() -> Dictionary:
	var file := FileAccess.open(LANE_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("PuzzleConfig: Failed to open lane registry")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PuzzleConfig: Lane registry JSON did not parse into a dictionary")
		return {}
	return parsed
