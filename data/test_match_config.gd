class_name TestMatchConfig
extends RefCounted

## Test match configuration for manual testing.
##
## Edit this file to set up any match scenario you want to test.
## Press "?" while hovering the Match button on the main menu to launch.
##
## The match starts at the action phase — mulligan is skipped entirely.
## Deck order is preserved exactly as listed (index 0 is drawn first).

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")

const LANE_REGISTRY_PATH := "res://data/legends/registries/lane_registry.json"


static func build_test_match_state() -> Dictionary:
	## ── CONFIGURATION ──────────────────────────────────────────────────
	## Edit the values below to set up your test scenario.
	## Testing: Fixed slay mechanics + newly implemented stub features

	var turn_number := 1
	var first_player := "player_1"  # "player_1" (you) or "player_2" (AI)

	# Player 1 (you) — 15 magicka to afford most cards
	var p1_health := 30
	var p1_max_magicka := 15
	var p1_current_magicka := 15
	var p1_rune_thresholds := [25, 20, 15, 10, 5]
	var p1_has_ring := false
	var p1_ring_charges := 0

	# Player 1 hand — cards to test all fixed/implemented features
	var p1_hand_ids: Array = [
		"db_agi_astrid",                    # Cost 3, 2/3, Lethal. Aura: friendly Lethal creatures slay -> Completed Contract. TEST: aura grants slay
		"db_agi_brotherhood_slayer",        # Cost 3, 3/3, Prophecy. Slay: Completed Contract. TEST: slay reward + Brotherhood Sanctuary doubles it
		"end_archein_venomtongue",          # Cost 4, 1/4, Lethal. Slay: +1 max magicka. TEST: should get doubled by Sanctuary
		"dg_wil_penitus_oculatus_envoy",   # Cost 2, 2/2. Summon: give friendly creature immune to Lethal. TEST: immunity blocks lethal kill
		"joo_wil_jauffre",                 # Cost 5, 3/9. Summon: redirect damage from chosen creature to self. TEST: damage redirect
		"moe_end_zumog_phoom",             # Cost 6, 4/6. Summon: choose creature, when it dies resummon as 1/1. TEST: resummon on death
		"mc_end_pure_blood_elder",         # Cost 7, 8/8. When you gain max magicka, double it. TEST: slay +1 magicka -> +2
	]

	# Player 1 deck — Aela's Huntmate for beast form art, Gates of Madness for drawn card bonus
	# Index 0 is drawn first.
	var p1_deck_ids: Array = [
		"hos_str_aelas_huntmate",           # Cost 4, 3/3. Beast Form: +1/+1 draw a card. TEST: art changes on transform
		"iom_neu_gates_of_madness",         # Cost 3 support. Transform deck + buff drawn cards. TEST: drawn card bonus
		"end_young_mammoth",                # 4/4 — draw target for Gates bonus test
		"end_young_mammoth",
		"int_elusive_schemer",
	]

	var p1_discard_ids: Array = []

	# Brotherhood Sanctuary already in play — doubles slay rewards
	var p1_support_ids: Array = [
		"db_agi_brotherhood_sanctuary",     # Ongoing. Friendly slay rewards trigger extra time. TEST: slay doubling
	]

	# Slay creature already in lane ready to attack into enemy
	var p1_field_creatures: Array = [
		_make_lane_creature("player_1", "db_end_falkreath_defiler", 100, {"can_attack": true}),  # 3/3 Slay: draw creature from discard. TEST: slay + Sanctuary double
	]

	var p1_shadow_creatures: Array = []

	# Player 2 (AI) — weak, no runes, low magicka
	var p2_health := 30
	var p2_max_magicka := 1
	var p2_current_magicka := 1
	var p2_rune_thresholds := [25, 20, 15, 10, 5]
	var p2_has_ring := false
	var p2_ring_charges := 0

	# Player 2 hand
	var p2_hand_ids: Array = [
		"str_fiery_imp",                    # 1/1 — AI filler
	]

	# Player 2 deck
	var p2_deck_ids: Array = [
		"str_fiery_imp",
		"str_fiery_imp",
		"str_fiery_imp",
		"str_fiery_imp",
		"str_fiery_imp",
	]

	var p2_discard_ids: Array = []

	# Enemy board — Lethal creature for immunity test, plus punching bags for slay
	var p2_field_creatures: Array = [
		_make_lane_creature("player_2", "end_deadly_draugr", 200),       # 1/1 Lethal — TEST: Penitus immunity should block this
		_make_lane_creature("player_2", "str_fiery_imp", 201),           # 1/1 — slay punching bag
		_make_lane_creature("player_2", "str_fiery_imp", 202),           # 1/1 — slay punching bag
	]
	var p2_shadow_creatures: Array = [
		_make_lane_creature("player_2", "str_fiery_imp", 203),           # 1/1 — punching bag
		_make_lane_creature("player_2", "str_fiery_imp", 204),           # 1/1 — punching bag
	]

	## ── END CONFIGURATION ──────────────────────────────────────────────

	# Auto-assign unique instance IDs across all cards for each player
	_reassign_instance_ids("player_1", p1_hand_ids, p1_deck_ids,
		p1_field_creatures, p1_shadow_creatures, p1_discard_ids)
	_reassign_instance_ids("player_2", p2_hand_ids, p2_deck_ids,
		p2_field_creatures, p2_shadow_creatures)

	# Build player states
	var p1 := _build_player("player_1", p1_health, p1_max_magicka, p1_current_magicka,
		p1_rune_thresholds, p1_has_ring, p1_ring_charges,
		p1_hand_ids, p1_deck_ids, turn_number, p1_discard_ids)
	var p2 := _build_player("player_2", p2_health, p2_max_magicka, p2_current_magicka,
		p2_rune_thresholds, p2_has_ring, p2_ring_charges,
		p2_hand_ids, p2_deck_ids, turn_number)

	# Place pre-played support cards into the support zone
	var p1_support_start: int = p1["hand"].size() + p1["deck"].size() + p1["discard"].size() + p1_field_creatures.size() + p1_shadow_creatures.size() + 1
	for i in range(p1_support_ids.size()):
		p1["support"].append(_make_card("player_1", p1_support_ids[i], "support", p1_support_start + i))

	# Build lanes with creatures
	var lanes := _build_lanes_with_creatures(
		p1_field_creatures, p1_shadow_creatures,
		p2_field_creatures, p2_shadow_creatures
	)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	return {
		"rules_version": "0.1.0",
		"match_format": "standard_versus",
		"phase": "action",
		"turn_number": turn_number,
		"winner_player_id": "",
		"event_log": [],
		"replay_log": [],
		"pending_event_queue": [],
		"trigger_registry": [],
		"last_timing_result": {"processed_events": [], "trigger_resolutions": []},
		"resolved_once_triggers": {},
		"next_event_sequence": 0,
		"next_trigger_resolution_sequence": 0,
		"starting_player_id": first_player,
		"active_player_id": first_player,
		"priority_player_id": first_player,
		"rng_seed": rng.randi(),
		"rng_state": rng.state,
		"players": [p1, p2],
		"lanes": lanes,
		"mulligan": {"pending_player_ids": []},
	}


static func _build_player(player_id: String, health: int, max_magicka: int,
		current_magicka: int, rune_thresholds: Array, has_ring: bool,
		ring_charges: int, hand_ids: Array, deck_ids: Array,
		turn_number: int, discard_ids: Array = []) -> Dictionary:
	var hand: Array = []
	for i in range(hand_ids.size()):
		hand.append(_make_card(player_id, hand_ids[i], "hand", hand.size() + 1))
	var deck: Array = []
	# Reverse so that index 0 in config is drawn first (pop_back draws)
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
		"turns_started": turn_number,
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


## Create a creature card state for placing in a lane.
## Optional overrides: "damage_marked", "power_bonus", "health_bonus",
## "keywords", "status_markers", "can_attack" (default true).
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
	if overrides.has("status_markers"):
		card["status_markers"] = overrides["status_markers"].duplicate()
	return card


## Re-number instance_ids so hand, deck, and lane creatures never collide.
## Hand/deck cards are created later by _build_player using their array index,
## so we just need lane creatures to start after hand + deck count.
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


static func _build_lanes_with_creatures(
		p1_field: Array, p1_shadow: Array,
		p2_field: Array, p2_shadow: Array) -> Array:
	var lane_registry := _load_lane_registry()
	var lane_type_lookup := {}
	for raw_record in lane_registry.get("lane_types", []):
		if typeof(raw_record) == TYPE_DICTIONARY:
			lane_type_lookup[str(raw_record.get("id", ""))] = raw_record

	var board_profile := {}
	for profile in lane_registry.get("board_profiles", []):
		if profile.get("id", "") == "standard_versus":
			board_profile = profile
			break

	var slot_capacity := int(board_profile.get("slot_capacity", 4))
	var lanes: Array = []

	for lane_id in board_profile.get("lane_ids", ["field", "shadow"]):
		var lane_record: Dictionary = lane_type_lookup.get(str(lane_id), {})
		var p1_creatures: Array
		var p2_creatures: Array
		if lane_id == "field":
			p1_creatures = p1_field
			p2_creatures = p2_field
		else:
			p1_creatures = p1_shadow
			p2_creatures = p2_shadow

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
			lane_rule_payload = {
				"display_name": str(lane_record.get("display_name", lane_id)),
				"description": str(lane_record.get("description", "")),
				"implementation_bucket": str(lane_record.get("implementation_bucket", "")),
				"availability": availability,
				"source_ids": source_ids,
			}

		lanes.append({
			"lane_id": lane_id,
			"lane_type": lane_record.get("id", lane_id),
			"slot_capacity": slot_capacity,
			"player_slots": {
				"player_1": p1_creatures.duplicate(true),
				"player_2": p2_creatures.duplicate(true),
			},
			"lane_rule_payload": lane_rule_payload,
		})

	return lanes


static func _load_lane_registry() -> Dictionary:
	var file := FileAccess.open(LANE_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("TestMatchConfig: Failed to open lane registry")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("TestMatchConfig: Lane registry JSON did not parse into a dictionary")
		return {}
	return parsed
