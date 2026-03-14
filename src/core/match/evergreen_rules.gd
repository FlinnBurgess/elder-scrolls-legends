class_name EvergreenRules
extends RefCounted

const REGISTRY_PATH := "res://data/legends/registries/keyword_effect_registry.json"
const CARD_TYPE_CREATURE := "creature"
const KEYWORD_BREAKTHROUGH := "breakthrough"
const KEYWORD_CHARGE := "charge"
const KEYWORD_DRAIN := "drain"
const KEYWORD_GUARD := "guard"
const KEYWORD_LETHAL := "lethal"
const KEYWORD_MOBILIZE := "mobilize"
const KEYWORD_RALLY := "rally"
const KEYWORD_REGENERATE := "regenerate"
const KEYWORD_WARD := "ward"
const STATUS_COVER := "cover"
const STATUS_EXALTED := "exalted"
const STATUS_SHACKLED := "shackled"
const STATUS_SILENCED := "silenced"
const STATUS_WOUNDED := "wounded"

static var _cached_registry: Dictionary = {}
static var _cached_keyword_ids: Array = []
static var _cached_status_ids: Array = []


static func get_registry() -> Dictionary:
	_ensure_registry_loaded()
	return _cached_registry.duplicate(true)


static func get_supported_keywords() -> Array:
	_ensure_registry_loaded()
	return _cached_keyword_ids.duplicate()


static func get_supported_statuses() -> Array:
	_ensure_registry_loaded()
	return _cached_status_ids.duplicate()


static func ensure_card_state(card: Dictionary) -> void:
	if not card.has("keywords") or typeof(card["keywords"]) != TYPE_ARRAY:
		card["keywords"] = []
	if not card.has("granted_keywords") or typeof(card["granted_keywords"]) != TYPE_ARRAY:
		card["granted_keywords"] = []
	if not card.has("status_markers") or typeof(card["status_markers"]) != TYPE_ARRAY:
		card["status_markers"] = []
	if not card.has("attached_items") or typeof(card["attached_items"]) != TYPE_ARRAY:
		card["attached_items"] = []
	if not card.has("damage_marked"):
		card["damage_marked"] = 0
	if not card.has("power_bonus"):
		card["power_bonus"] = 0
	if not card.has("health_bonus"):
		card["health_bonus"] = 0


static func has_keyword(card: Dictionary, keyword_id: String) -> bool:
	ensure_card_state(card)
	if has_raw_status(card, STATUS_SILENCED):
		return false
	for key in ["keywords", "granted_keywords"]:
		var values := _ensure_array(card.get(key, []))
		if values.has(keyword_id):
			return true
	for item in get_attached_items(card):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if _ensure_array(item.get("equip_keywords", [])).has(keyword_id):
			return true
	return false


static func remove_keyword(card: Dictionary, keyword_id: String) -> bool:
	ensure_card_state(card)
	var removed := false
	for key in ["keywords", "granted_keywords"]:
		var values := _ensure_array(card.get(key, []))
		while values.has(keyword_id):
			values.erase(keyword_id)
			removed = true
		card[key] = values
	return removed


static func has_status(card: Dictionary, status_id: String) -> bool:
	if not has_raw_status(card, status_id):
		return false
	if status_id in [STATUS_COVER, STATUS_EXALTED] and has_raw_status(card, STATUS_SILENCED):
		return false
	return true


static func has_raw_status(card: Dictionary, status_id: String) -> bool:
	ensure_card_state(card)
	return _ensure_array(card.get("status_markers", [])).has(status_id)


static func add_status(card: Dictionary, status_id: String) -> bool:
	ensure_card_state(card)
	var statuses := _ensure_array(card.get("status_markers", []))
	if statuses.has(status_id):
		return false
	statuses.append(status_id)
	card["status_markers"] = statuses
	return true


static func remove_status(card: Dictionary, status_id: String) -> bool:
	ensure_card_state(card)
	var statuses := _ensure_array(card.get("status_markers", []))
	if not statuses.has(status_id):
		return false
	statuses.erase(status_id)
	card["status_markers"] = statuses
	return true


static func grant_cover(card: Dictionary, cover_expires_on_turn: int, source := "shadow_lane_entry") -> bool:
	ensure_card_state(card)
	if has_raw_status(card, STATUS_COVER):
		return false
	add_status(card, STATUS_COVER)
	card["cover_expires_on_turn"] = cover_expires_on_turn
	card["cover_granted_by"] = source
	return true


static func is_cover_active(match_state: Dictionary, card: Dictionary) -> bool:
	if not has_status(card, STATUS_COVER):
		return false
	return int(match_state.get("turn_number", 0)) <= int(card.get("cover_expires_on_turn", -1))


static func refresh_for_controller_turn(card: Dictionary, current_turn_number: int) -> Dictionary:
	ensure_card_state(card)
	card["has_attacked_this_turn"] = false
	var result := {
		"cover_expired": false,
		"shackle_cleared": false,
		"regenerate_healed": 0,
	}
	if has_raw_status(card, STATUS_COVER) and int(card.get("cover_expires_on_turn", -1)) <= current_turn_number:
		remove_status(card, STATUS_COVER)
		card.erase("cover_expires_on_turn")
		card.erase("cover_granted_by")
		result["cover_expired"] = true
	if has_raw_status(card, STATUS_SHACKLED):
		remove_status(card, STATUS_SHACKLED)
		result["shackle_cleared"] = true
	if has_keyword(card, KEYWORD_REGENERATE):
		result["regenerate_healed"] = restore_health(card)
	_sync_wounded_status(card)
	return result


static func apply_damage_to_creature(card: Dictionary, amount: int) -> Dictionary:
	ensure_card_state(card)
	var requested := maxi(0, amount)
	if requested <= 0:
		return {
			"applied": 0,
			"ward_removed": false,
			"remaining_health": get_remaining_health(card),
		}
	if has_keyword(card, KEYWORD_WARD):
		remove_keyword(card, KEYWORD_WARD)
		return {
			"applied": 0,
			"ward_removed": true,
			"remaining_health": get_remaining_health(card),
		}
	var applied := mini(requested, get_remaining_health(card))
	card["damage_marked"] = int(card.get("damage_marked", 0)) + applied
	_sync_wounded_status(card)
	return {
		"applied": applied,
		"ward_removed": false,
		"remaining_health": get_remaining_health(card),
	}


static func restore_health(card: Dictionary, amount := -1) -> int:
	ensure_card_state(card)
	var damage_marked := int(card.get("damage_marked", 0))
	if damage_marked <= 0:
		_sync_wounded_status(card)
		return 0
	var healed := damage_marked if amount < 0 else mini(damage_marked, maxi(0, amount))
	card["damage_marked"] = damage_marked - healed
	_sync_wounded_status(card)
	return healed


static func apply_stat_bonus(card: Dictionary, power_bonus: int, health_bonus: int, _reason := "") -> Dictionary:
	ensure_card_state(card)
	card["power_bonus"] = int(card.get("power_bonus", 0)) + power_bonus
	card["health_bonus"] = int(card.get("health_bonus", 0)) + health_bonus
	_sync_wounded_status(card)
	return {
		"power_bonus": int(card.get("power_bonus", 0)),
		"health_bonus": int(card.get("health_bonus", 0)),
	}


static func sync_derived_state(card: Dictionary) -> void:
	ensure_card_state(card)
	_sync_wounded_status(card)


static func resolve_rally(match_state: Dictionary, attacker: Dictionary) -> Dictionary:
	if not has_keyword(attacker, KEYWORD_RALLY):
		return {"triggered": false}
	var controller_player := _get_player_state(match_state, str(attacker.get("controller_player_id", "")))
	if controller_player.is_empty():
		return {"triggered": false}
	var candidates: Array = []
	for card in controller_player.get("hand", []):
		if typeof(card) != TYPE_DICTIONARY:
			continue
		ensure_card_state(card)
		if str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
			candidates.append(card)
	if candidates.is_empty():
		return {"triggered": false}
	var selected_index := _choose_deterministic_candidate_index(match_state, str(attacker.get("instance_id", "")), candidates)
	var target: Dictionary = candidates[selected_index]
	apply_stat_bonus(target, 1, 1, KEYWORD_RALLY)
	return {
		"triggered": true,
		"target_instance_id": str(target.get("instance_id", "")),
		"power_bonus": 1,
		"health_bonus": 1,
	}


static func get_mobilize_lane_options(match_state: Dictionary, player_id: String) -> Array:
	var options: Array = []
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		if not player_slots_by_id.has(player_id):
			continue
		var player_slots: Array = player_slots_by_id[player_id]
		var occupancy := player_slots.size()
		var slot_capacity := int(lane.get("slot_capacity", 0))
		if occupancy == 0 and slot_capacity > 0:
			options.append({
				"lane_id": str(lane.get("lane_id", "")),
				"lane_index": lane_index,
				"lane_type": str(lane.get("lane_type", lane.get("lane_id", ""))),
				"slot_index": 0,
				"open_slot_indices": [0],
			})
	return options


static func build_mobilize_recruit(player_id: String, instance_id: String) -> Dictionary:
	var recruit := {
		"instance_id": instance_id,
		"definition_id": "generated_recruit",
		"owner_player_id": player_id,
		"controller_player_id": player_id,
		"card_type": CARD_TYPE_CREATURE,
		"zone": "generated",
		"power": 1,
		"health": 1,
		"rules_tags": [KEYWORD_MOBILIZE],
	}
	ensure_card_state(recruit)
	return recruit


static func get_attached_items(card: Dictionary) -> Array:
	ensure_card_state(card)
	return _ensure_array(card.get("attached_items", []))


static func is_creature_destroyed(card: Dictionary, destroyed_by_lethal: bool) -> bool:
	if destroyed_by_lethal:
		return true
	return get_remaining_health(card) <= 0


static func get_remaining_health(card: Dictionary) -> int:
	return max(0, get_health(card) - int(card.get("damage_marked", 0)))


static func get_power(card: Dictionary) -> int:
	var base_value := 0
	if card.has("power"):
		base_value = int(card.get("power", 0))
	elif card.has("current_power"):
		base_value = int(card.get("current_power", 0))
	else:
		base_value = int(card.get("base_power", 0))
	return max(0, base_value + int(card.get("power_bonus", 0)) + _sum_attached_item_bonus(card, "equip_power_bonus"))


static func get_health(card: Dictionary) -> int:
	var base_value := 0
	if card.has("health"):
		base_value = int(card.get("health", 0))
	elif card.has("current_health"):
		base_value = int(card.get("current_health", 0))
	else:
		base_value = int(card.get("base_health", 0))
	return max(0, base_value + int(card.get("health_bonus", 0)) + _sum_attached_item_bonus(card, "equip_health_bonus"))


static func _sync_wounded_status(card: Dictionary) -> void:
	if int(card.get("damage_marked", 0)) > 0:
		add_status(card, STATUS_WOUNDED)
	else:
		remove_status(card, STATUS_WOUNDED)


static func _sum_attached_item_bonus(card: Dictionary, field_name: String) -> int:
	var total := 0
	for item in get_attached_items(card):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		total += int(item.get(field_name, 0))
	return total


static func _choose_deterministic_candidate_index(match_state: Dictionary, attacker_instance_id: String, candidates: Array) -> int:
	var fingerprint_parts := [
		str(match_state.get("rng_seed", 0)),
		str(match_state.get("turn_number", 0)),
		attacker_instance_id,
	]
	for card in candidates:
		fingerprint_parts.append(str(card.get("instance_id", "")))
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed_from_text("|".join(fingerprint_parts))
	var selected := rng.randi_range(0, candidates.size() - 1)
	match_state["rng_state"] = rng.state
	return selected


static func _get_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _ensure_registry_loaded() -> void:
	if not _cached_registry.is_empty():
		return
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open evergreen keyword registry: %s" % REGISTRY_PATH)
		_cached_registry = {}
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Evergreen keyword registry did not parse into a dictionary.")
		_cached_registry = {}
		return
	_cached_registry = parsed
	_cached_keyword_ids = []
	for keyword in _cached_registry.get("keywords", []):
		if typeof(keyword) == TYPE_DICTIONARY:
			_cached_keyword_ids.append(str(keyword.get("id", "")))
	_cached_status_ids = []
	for status in _cached_registry.get("status_markers", []):
		if typeof(status) == TYPE_DICTIONARY:
			_cached_status_ids.append(str(status.get("id", "")))


static func _stable_seed_from_text(text: String) -> int:
	var seed_value: int = 1469598103934665603
	for byte in text.to_utf8_buffer():
		seed_value = int((seed_value * 1099511628211 + int(byte)) % 9223372036854775783)
	return seed_value


static func _ensure_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []