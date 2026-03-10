class_name MatchBootstrap
extends RefCounted

const STANDARD_STARTING_HEALTH := 30
const STANDARD_RUNE_THRESHOLDS := [25, 20, 15, 10, 5]
const STARTING_HAND_SIZE := 3
const RING_OF_MAGICKA_CHARGES := 3
const STANDARD_BOARD_PROFILE_ID := "standard_versus"
const LANE_REGISTRY_PATH := "res://data/legends/registries/lane_registry.json"


static func create_standard_match(player_decks: Array, options: Dictionary = {}) -> Dictionary:
	if player_decks.size() != 2:
		push_error("Standard matches require exactly two player decks.")
		return {}

	var seed := int(options.get("seed", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var first_player_index := int(options.get("first_player_index", rng.randi_range(0, 1)))
	if first_player_index < 0 or first_player_index > 1:
		push_error("first_player_index must be 0 or 1.")
		return {}

	var players: Array = []
	for deck_index in range(player_decks.size()):
		var player_id := "player_%d" % [deck_index + 1]
		var receives_ring := deck_index != first_player_index
		players.append(_build_player_state(player_id, player_decks[deck_index], receives_ring, rng))

	var board_profile := _load_board_profile(STANDARD_BOARD_PROFILE_ID)
	if board_profile.is_empty():
		return {}

	var starting_player_id: String = players[first_player_index]["player_id"]
	return {
		"rules_version": "0.1.0",
		"match_format": STANDARD_BOARD_PROFILE_ID,
		"phase": "mulligan",
		"turn_number": 0,
		"starting_player_id": starting_player_id,
		"active_player_id": starting_player_id,
		"priority_player_id": starting_player_id,
		"rng_seed": seed,
		"rng_state": rng.state,
		"players": players,
		"lanes": _build_lanes(board_profile, players),
		"mulligan": {
			"pending_player_ids": [players[0]["player_id"], players[1]["player_id"]]
		}
	}


static func apply_mulligan(match_state: Dictionary, player_id: String, discard_instance_ids: Array) -> Dictionary:
	if match_state.get("phase", "") != "mulligan":
		push_error("Mulligan can only be applied during the mulligan phase.")
		return match_state

	var player_index := _find_player_index(match_state.get("players", []), player_id)
	if player_index == -1:
		push_error("Unknown player_id for mulligan: %s" % player_id)
		return match_state

	var player: Dictionary = match_state["players"][player_index]
	if bool(player.get("mulligan_complete", false)):
		push_error("Mulligan already completed for player_id: %s" % player_id)
		return match_state

	var discard_lookup := {}
	for instance_id in discard_instance_ids:
		if discard_lookup.has(instance_id):
			push_error("Discard selections must be unique for mulligan.")
			return match_state
		discard_lookup[instance_id] = true

	var discarded_cards: Array = []
	var kept_cards: Array = []
	for card in player["hand"]:
		if discard_lookup.has(card["instance_id"]):
			card["zone"] = "mulligan_set_aside"
			discarded_cards.append(card)
		else:
			card["zone"] = "hand"
			kept_cards.append(card)

	if discarded_cards.size() != discard_instance_ids.size():
		push_error("Discard selections must come from the current hand.")
		return match_state

	if player["deck"].size() < discarded_cards.size():
		push_error("Not enough cards remain in deck to finish mulligan.")
		return match_state

	for _draw_index in range(discarded_cards.size()):
		var drawn_card: Dictionary = player["deck"].pop_back()
		drawn_card["zone"] = "hand"
		kept_cards.append(drawn_card)

	for card in discarded_cards:
		card["zone"] = "deck"
		player["deck"].append(card)

	if not discarded_cards.is_empty():
		var rng := _build_mulligan_rng(match_state, player, discarded_cards)
		_shuffle_array(player["deck"], rng)
	player["hand"] = kept_cards
	player["mulligan_complete"] = true
	player["mulligan_discarded_instance_ids"] = discard_instance_ids.duplicate()

	var mulligan_state: Dictionary = match_state["mulligan"]
	var pending_player_ids: Array = mulligan_state.get("pending_player_ids", [])
	pending_player_ids.erase(player_id)

	if pending_player_ids.is_empty():
		match_state["phase"] = "ready_for_first_turn"

	return match_state


static func _build_player_state(player_id: String, deck_definition_ids: Array, receives_ring: bool, rng: RandomNumberGenerator) -> Dictionary:
	var shuffled_deck := _build_shuffled_deck(player_id, deck_definition_ids, rng)
	var opening_hand: Array = []
	for _draw_index in range(STARTING_HAND_SIZE):
		if shuffled_deck.is_empty():
			push_error("Deck must contain at least %d cards to create an opening hand." % STARTING_HAND_SIZE)
			return {}
		var card: Dictionary = shuffled_deck.pop_back()
		card["zone"] = "hand"
		opening_hand.append(card)

	return {
		"player_id": player_id,
		"health": STANDARD_STARTING_HEALTH,
		"rune_thresholds": STANDARD_RUNE_THRESHOLDS.duplicate(),
		"deck": shuffled_deck,
		"hand": opening_hand,
		"discard": [],
		"banished": [],
		"max_magicka": 0,
		"current_magicka": 0,
		"temporary_magicka": 0,
			"turns_started": 0,
		"has_ring_of_magicka": receives_ring,
		"ring_of_magicka_charges": RING_OF_MAGICKA_CHARGES if receives_ring else 0,
			"ring_of_magicka_used_this_turn": false,
		"mulligan_complete": false,
		"mulligan_discarded_instance_ids": []
	}


static func _build_shuffled_deck(player_id: String, deck_definition_ids: Array, rng: RandomNumberGenerator) -> Array:
	var deck: Array = []
	for card_index in range(deck_definition_ids.size()):
		deck.append({
			"instance_id": "%s_card_%03d" % [player_id, card_index + 1],
			"definition_id": str(deck_definition_ids[card_index]),
			"owner_player_id": player_id,
			"controller_player_id": player_id,
			"zone": "deck"
		})
	_shuffle_array(deck, rng)
	return deck


static func _build_lanes(board_profile: Dictionary, players: Array) -> Array:
	var lanes: Array = []
	var lane_ids: Array = board_profile.get("lane_ids", [])
	var slot_capacity := int(board_profile.get("slot_capacity", 0))
	var lane_type_lookup := _load_lane_type_lookup()
	for lane_id in lane_ids:
		var player_slots := {}
		for player in players:
			player_slots[player["player_id"]] = _build_empty_slots(slot_capacity)
		var lane_record: Dictionary = lane_type_lookup.get(str(lane_id), {})
		lanes.append({
			"lane_id": lane_id,
			"lane_type": lane_record.get("id", lane_id),
			"slot_capacity": slot_capacity,
			"player_slots": player_slots,
			"lane_rule_payload": _build_lane_rule_payload(lane_record)
		})
	return lanes


static func _build_empty_slots(slot_capacity: int) -> Array:
	var slots: Array = []
	for _slot_index in range(slot_capacity):
		slots.append(null)
	return slots


static func _load_board_profile(profile_id: String) -> Dictionary:
	var parsed := _load_lane_registry()
	if parsed.is_empty():
		return {}

	for board_profile in parsed.get("board_profiles", []):
		if board_profile.get("id", "") == profile_id:
			return board_profile

	push_error("Unknown board profile: %s" % profile_id)
	return {}


static func _load_lane_type_lookup() -> Dictionary:
	var parsed := _load_lane_registry()
	if parsed.is_empty():
		return {}

	var lane_type_lookup := {}
	for raw_lane_record in parsed.get("lane_types", []):
		if typeof(raw_lane_record) != TYPE_DICTIONARY:
			continue
		var lane_record: Dictionary = raw_lane_record
		lane_type_lookup[str(lane_record.get("id", ""))] = lane_record
	return lane_type_lookup


static func _build_lane_rule_payload(lane_record: Dictionary) -> Dictionary:
	if lane_record.is_empty():
		return {}

	var availability: Array = []
	var raw_availability = lane_record.get("availability", [])
	if typeof(raw_availability) == TYPE_ARRAY:
		availability = raw_availability.duplicate()

	var source_ids: Array = []
	var raw_source_ids = lane_record.get("source_ids", [])
	if typeof(raw_source_ids) == TYPE_ARRAY:
		source_ids = raw_source_ids.duplicate()

	return {
		"display_name": str(lane_record.get("display_name", lane_record.get("id", ""))),
		"description": str(lane_record.get("description", "")),
		"implementation_bucket": str(lane_record.get("implementation_bucket", "")),
		"availability": availability,
		"source_ids": source_ids,
	}


static func _load_lane_registry() -> Dictionary:
	var file := FileAccess.open(LANE_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open lane registry: %s" % LANE_REGISTRY_PATH)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Lane registry JSON did not parse into a dictionary.")
		return {}

	return parsed


static func _shuffle_array(cards: Array, rng: RandomNumberGenerator) -> void:
	if cards.size() < 2:
		return

	for index in range(cards.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current_card = cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = current_card


static func _build_mulligan_rng(match_state: Dictionary, player: Dictionary, discarded_cards: Array) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _derive_mulligan_seed(match_state, player, discarded_cards)
	return rng


static func _derive_mulligan_seed(match_state: Dictionary, player: Dictionary, discarded_cards: Array) -> int:
	var fingerprint_parts: Array = [
		str(match_state.get("rng_seed", 0)),
		str(player.get("player_id", ""))
	]

	var discarded_instance_ids: Array = []
	for card in discarded_cards:
		discarded_instance_ids.append(str(card.get("instance_id", "")))
	discarded_instance_ids.sort()

	for instance_id in discarded_instance_ids:
		fingerprint_parts.append(instance_id)

	return _stable_seed_from_text("|".join(fingerprint_parts))


static func _stable_seed_from_text(text: String) -> int:
	var seed_value: int = 1469598103934665603
	for byte in text.to_utf8_buffer():
		seed_value = int((seed_value * 1099511628211 + int(byte)) % 9223372036854775783)
	return seed_value


static func _find_player_index(players: Array, player_id: String) -> int:
	for index in range(players.size()):
		if players[index].get("player_id", "") == player_id:
			return index
	return -1