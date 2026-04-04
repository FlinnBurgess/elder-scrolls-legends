class_name ScenarioFixtures
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")


static func create_standard_match(options: Dictionary = {}) -> Dictionary:
	var bootstrap_options := {
		"seed": int(options.get("seed", 0)),
	}
	if options.has("first_player_index"):
		bootstrap_options["first_player_index"] = int(options.get("first_player_index", 0))
	var match_state := MatchBootstrap.create_standard_match(_build_player_decks(options), bootstrap_options)
	if match_state.is_empty():
		return {}
	return match_state


static func create_ready_match(options: Dictionary = {}) -> Dictionary:
	var match_state := create_standard_match(options)
	if match_state.is_empty():
		return {}
	for current_player in match_state.get("players", []):
		MatchBootstrap.apply_mulligan(match_state, str(current_player.get("player_id", "")), [])
	_apply_common_overrides(match_state, options)
	return match_state


static func create_started_match(options: Dictionary = {}) -> Dictionary:
	var match_state := create_ready_match(options)
	if match_state.is_empty():
		return {}
	if bool(options.get("begin_first_turn", true)):
		MatchTurnLoop.begin_first_turn(match_state)
	_apply_common_overrides(match_state, options)
	return match_state


static func set_rng_seed(match_state: Dictionary, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	match_state["rng_seed"] = seed
	match_state["rng_state"] = rng.state


static func set_all_magicka(match_state: Dictionary, amount: int) -> void:
	for current_player in match_state.get("players", []):
		current_player["magicka"] = amount
		current_player["max_magicka"] = amount
		current_player["current_magicka"] = amount
		current_player["temporary_magicka"] = 0


static func player(match_state: Dictionary, player_index: int) -> Dictionary:
	var players: Array = match_state.get("players", [])
	if player_index < 0 or player_index >= players.size():
		return {}
	return players[player_index]


static func summon_creature(player_state: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int, keywords: Array = [], slot_index := -1, extra: Dictionary = {}) -> Dictionary:
	var overrides := extra.duplicate(true)
	overrides["card_type"] = "creature"
	overrides["power"] = power
	overrides["health"] = health
	overrides["keywords"] = keywords.duplicate()
	var card := add_hand_card(player_state, label, overrides)
	var summon_options := {}
	if slot_index >= 0:
		summon_options["slot_index"] = slot_index
	var result := LaneRules.summon_from_hand(match_state, str(player_state.get("player_id", "")), str(card.get("instance_id", "")), lane_id, summon_options)
	if bool(extra.get("cover", false)):
		EvergreenRules.grant_cover(card, int(match_state.get("turn_number", 0)))
	return card if bool(result.get("is_valid", false)) else {}


static func add_hand_card(player_state: Dictionary, label: String, extra: Dictionary = {}) -> Dictionary:
	var player_id := str(player_state.get("player_id", ""))
	var card := make_card(player_id, label, extra)
	card["zone"] = "hand"
	var hand: Array = player_state.get("hand", [])
	var insert_index := int(extra.get("insert_index", -1))
	if insert_index >= 0 and insert_index <= hand.size():
		hand.insert(insert_index, card)
	else:
		hand.append(card)
	player_state["hand"] = hand
	return card


static func make_card(player_id: String, label: String, extra: Dictionary = {}) -> Dictionary:
	var card := {
		"instance_id": "%s_%s" % [player_id, label],
		"definition_id": str(extra.get("definition_id", "test_%s" % label)),
		"name": str(extra.get("name", "Test %s" % label)),
		"owner_player_id": str(extra.get("owner_player_id", player_id)),
		"controller_player_id": str(extra.get("controller_player_id", player_id)),
		"zone": str(extra.get("zone", "hand")),
		"card_type": str(extra.get("card_type", "creature")),
		"cost": int(extra.get("cost", 1)),
		"power": int(extra.get("power", 0)),
		"health": int(extra.get("health", 0)),
		"damage_marked": int(extra.get("damage_marked", 0)),
		"power_bonus": int(extra.get("power_bonus", 0)),
		"health_bonus": int(extra.get("health_bonus", 0)),
		"keywords": _clone_variant(extra.get("keywords", [])),
		"rules_tags": _clone_variant(extra.get("rules_tags", [])),
		"granted_keywords": _clone_variant(extra.get("granted_keywords", [])),
		"status_markers": _clone_variant(extra.get("status_markers", [])),
		"triggered_abilities": _clone_variant(extra.get("triggered_abilities", [])),
	}
	for key in extra.keys():
		card[key] = _clone_variant(extra[key])
	return card


static func set_deck_cards(player_state: Dictionary, cards: Array) -> void:
	player_state["deck"] = []
	for raw_card in cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = raw_card
		card["owner_player_id"] = str(player_state.get("player_id", ""))
		card["controller_player_id"] = str(player_state.get("player_id", ""))
		card["zone"] = "deck"
		player_state["deck"].append(card)


static func ready_for_attack(card: Dictionary, match_state: Dictionary) -> void:
	card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	card["has_attacked_this_turn"] = false
	var status_markers: Array = card.get("status_markers", [])
	status_markers.erase("shackled")
	card["status_markers"] = status_markers


static func lane_slot(match_state: Dictionary, lane_id: String, player_id: String, slot_index: int):
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		var player_slots: Array = lane.get("player_slots", {}).get(player_id, [])
		if slot_index >= 0 and slot_index < player_slots.size():
			return player_slots[slot_index]
	return null


static func find_lane_card(match_state: Dictionary, lane_id: String, player_id: String, definition_id: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == definition_id:
				return card
	return {}


static func contains_instance(cards: Array, instance_id: String) -> bool:
	for card in cards:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
			return true
	return false


static func card_instance_ids(cards: Array) -> Array:
	var instance_ids: Array = []
	for card in cards:
		if typeof(card) == TYPE_DICTIONARY:
			instance_ids.append(str(card.get("instance_id", "")))
	return instance_ids


static func replay_signature(match_state: Dictionary) -> Array:
	var signature: Array = []
	for raw_entry in match_state.get("replay_log", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = {"entry_type": str(raw_entry.get("entry_type", ""))}
		for key in ["event_type", "family", "timing_window", "source_instance_id", "drawn_instance_id"]:
			if raw_entry.has(key):
				entry[key] = _clone_variant(raw_entry[key])
		signature.append(entry)
	return signature


static func build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


static func _build_player_decks(options: Dictionary) -> Array:
	var deck_size := int(options.get("deck_size", 20))
	var prefixes: Array = options.get("player_prefixes", ["alpha", "beta"])
	return [
		build_deck(str(prefixes[0] if prefixes.size() > 0 else "alpha"), int(options.get("player_one_deck_size", deck_size))),
		build_deck(str(prefixes[1] if prefixes.size() > 1 else "beta"), int(options.get("player_two_deck_size", deck_size))),
	]


static func _apply_common_overrides(match_state: Dictionary, options: Dictionary) -> void:
	if options.has("set_all_magicka"):
		set_all_magicka(match_state, int(options.get("set_all_magicka", 0)))
	if options.has("phase"):
		match_state["phase"] = str(options.get("phase", match_state.get("phase", "")))


static func _clone_variant(value):
	if typeof(value) == TYPE_DICTIONARY:
		var cloned := {}
		for key in value.keys():
			cloned[key] = _clone_variant(value[key])
		return cloned
	if typeof(value) == TYPE_ARRAY:
		var cloned_array: Array = []
		for item in value:
			cloned_array.append(_clone_variant(item))
		return cloned_array
	return value
