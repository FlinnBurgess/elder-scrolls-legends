class_name EvergreenRules
extends RefCounted

const GameLogger = preload("res://src/core/match/game_logger.gd")
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
const STATUS_DAMAGE_IMMUNE := "damage_immune"

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
	if not card.has("aura_power_bonus"):
		card["aura_power_bonus"] = 0
	if not card.has("aura_health_bonus"):
		card["aura_health_bonus"] = 0
	if not card.has("aura_keywords") or typeof(card["aura_keywords"]) != TYPE_ARRAY:
		card["aura_keywords"] = []


static func has_keyword(card: Dictionary, keyword_id: String) -> bool:
	ensure_card_state(card)
	# Aura keywords bypass silence — check first
	if _ensure_array(card.get("aura_keywords", [])).has(keyword_id):
		return true
	# Item-granted keywords bypass silence — items provide their own bonuses
	var consumed_equip := _ensure_array(card.get("_consumed_equip_keywords", []))
	for item in get_attached_items(card):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if _ensure_array(item.get("equip_keywords", [])).has(keyword_id) and not consumed_equip.has(keyword_id):
			return true
	if has_raw_status(card, STATUS_SILENCED):
		return false
	for key in ["keywords", "granted_keywords"]:
		var values := _ensure_array(card.get(key, []))
		if values.has(keyword_id):
			return true
	return false


static func count_keyword(card: Dictionary, keyword_id: String) -> int:
	ensure_card_state(card)
	var count := 0
	# Aura keywords
	for kw in _ensure_array(card.get("aura_keywords", [])):
		if kw == keyword_id:
			count += 1
	# Item-granted keywords (skip consumed ones like ward after it's broken)
	var ck_consumed := _ensure_array(card.get("_consumed_equip_keywords", []))
	for item in get_attached_items(card):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		for kw in _ensure_array(item.get("equip_keywords", [])):
			if kw == keyword_id and not ck_consumed.has(kw):
				count += 1
	if has_raw_status(card, STATUS_SILENCED):
		return count
	for key in ["keywords", "granted_keywords"]:
		for kw in _ensure_array(card.get(key, [])):
			if kw == keyword_id:
				count += 1
	return count


static func remove_keyword(card: Dictionary, keyword_id: String) -> bool:
	GameLogger.trc("Evergreen", "rm_keyword", "card:%s,kw:%s" % [str(card.get("name", card.get("instance_id", "?"))), keyword_id])
	ensure_card_state(card)
	var removed := false
	for key in ["keywords", "granted_keywords"]:
		var values := _ensure_array(card.get(key, []))
		while values.has(keyword_id):
			values.erase(keyword_id)
			removed = true
		card[key] = values
	# Track consumed equip keywords so items don't re-grant them (e.g., ward)
	for item in get_attached_items(card):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if _ensure_array(item.get("equip_keywords", [])).has(keyword_id):
			var consumed: Array = card.get("_consumed_equip_keywords", [])
			if not consumed.has(keyword_id):
				consumed.append(keyword_id)
			card["_consumed_equip_keywords"] = consumed
			removed = true
			break
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
	GameLogger.trc("Evergreen", "add_status", "card:%s,st:%s" % [str(card.get("name", card.get("instance_id", "?"))), status_id])
	ensure_card_state(card)
	var statuses := _ensure_array(card.get("status_markers", []))
	if statuses.has(status_id):
		return false
	statuses.append(status_id)
	card["status_markers"] = statuses
	return true


static func remove_status(card: Dictionary, status_id: String) -> bool:
	GameLogger.trc("Evergreen", "rm_status", "card:%s,st:%s" % [str(card.get("name", card.get("instance_id", "?"))), status_id])
	ensure_card_state(card)
	var statuses := _ensure_array(card.get("status_markers", []))
	if not statuses.has(status_id):
		return false
	statuses.erase(status_id)
	card["status_markers"] = statuses
	return true


static func grant_cover(card: Dictionary, cover_expires_on_turn: int, source := "shadow_lane_entry") -> bool:
	GameLogger.trc("Evergreen", "grant_cover", "card:%s" % [str(card.get("name", card.get("instance_id", "?")))])
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
	if has_raw_status(card, STATUS_SHACKLED) and int(card.get("shackle_expires_on_turn", -1)) <= current_turn_number:
		remove_status(card, STATUS_SHACKLED)
		card.erase("shackle_expires_on_turn")
		result["shackle_cleared"] = true
	if card.has("_immune_until_turn") and int(card.get("_immune_until_turn", -1)) <= current_turn_number:
		card.erase("_immune_until_turn")
		card.erase("_immunity_type")
	if has_keyword(card, KEYWORD_REGENERATE):
		result["regenerate_healed"] = restore_health(card)
	_sync_wounded_status(card)
	return result


static func apply_damage_to_creature(card: Dictionary, amount: int) -> Dictionary:
	GameLogger.trc("Evergreen", "apply_dmg", "card:%s,amt:%s" % [str(card.get("name", card.get("instance_id", "?"))), str(amount)])
	ensure_card_state(card)
	var requested := maxi(0, amount)
	if requested <= 0:
		return {
			"applied": 0,
			"ward_removed": false,
			"remaining_health": get_remaining_health(card),
		}
	if has_status(card, STATUS_DAMAGE_IMMUNE) or bool(card.get("aura_damage_immune", false)):
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
	var remaining := get_remaining_health(card)
	var marked := mini(requested, remaining)
	card["damage_marked"] = int(card.get("damage_marked", 0)) + marked
	var applied := requested
	_sync_wounded_status(card)
	return {
		"applied": applied,
		"ward_removed": false,
		"remaining_health": get_remaining_health(card),
	}


static func restore_health(card: Dictionary, amount := -1) -> int:
	GameLogger.trc("Evergreen", "restore_hp", "card:%s,amt:%s" % [str(card.get("name", card.get("instance_id", "?"))), str(amount)])
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
	GameLogger.trc("Evergreen", "stat_bonus", "card:%s,p:%s,h:%s" % [str(card.get("name", card.get("instance_id", "?"))), str(power_bonus), str(health_bonus)])
	ensure_card_state(card)
	card["power_bonus"] = int(card.get("power_bonus", 0)) + power_bonus
	card["health_bonus"] = int(card.get("health_bonus", 0)) + health_bonus
	# Items transfer stat buffs through equip bonuses so the creature gains them
	if str(card.get("card_type", "")) == "item":
		card["equip_power_bonus"] = int(card.get("equip_power_bonus", 0)) + power_bonus
		card["equip_health_bonus"] = int(card.get("equip_health_bonus", 0)) + health_bonus
	_sync_wounded_status(card)
	return {
		"power_bonus": int(card.get("power_bonus", 0)),
		"health_bonus": int(card.get("health_bonus", 0)),
	}


static func add_temporary_stat_bonus(card: Dictionary, power: int, health: int, turn_number: int) -> void:
	var temp_bonuses: Array = card.get("temporary_stat_bonuses", [])
	temp_bonuses.append({"power": power, "health": health, "turn": turn_number})
	card["temporary_stat_bonuses"] = temp_bonuses


static func clear_temporary_stat_bonuses(card: Dictionary, turn_number: int) -> Dictionary:
	var temp_bonuses: Array = card.get("temporary_stat_bonuses", [])
	if temp_bonuses.is_empty():
		return {"power_reverted": 0, "health_reverted": 0}
	var power_reverted := 0
	var health_reverted := 0
	var remaining: Array = []
	for bonus in temp_bonuses:
		if int(bonus.get("turn", -1)) <= turn_number:
			power_reverted += int(bonus.get("power", 0))
			health_reverted += int(bonus.get("health", 0))
		else:
			remaining.append(bonus)
	if power_reverted != 0 or health_reverted != 0:
		apply_stat_bonus(card, -power_reverted, -health_reverted, "temp_bonus_expired")
	if remaining.is_empty():
		card.erase("temporary_stat_bonuses")
	else:
		card["temporary_stat_bonuses"] = remaining
	return {"power_reverted": power_reverted, "health_reverted": health_reverted}


static func add_temporary_keyword(card: Dictionary, keyword_id: String, turn_number: int) -> void:
	var temp_keywords: Array = card.get("temporary_keywords", [])
	temp_keywords.append({"keyword_id": keyword_id, "turn": turn_number})
	card["temporary_keywords"] = temp_keywords


static func clear_temporary_keywords(card: Dictionary, turn_number: int) -> Array:
	var temp_keywords: Array = card.get("temporary_keywords", [])
	if temp_keywords.is_empty():
		return []
	var removed: Array = []
	var remaining: Array = []
	for entry in temp_keywords:
		if int(entry.get("turn", -1)) <= turn_number:
			var kw := str(entry.get("keyword_id", ""))
			remove_keyword(card, kw)
			removed.append(kw)
		else:
			remaining.append(entry)
	if remaining.is_empty():
		card.erase("temporary_keywords")
	else:
		card["temporary_keywords"] = remaining
	return removed


static func sync_derived_state(card: Dictionary) -> void:
	ensure_card_state(card)
	_sync_wounded_status(card)


static func resolve_rally(match_state: Dictionary, attacker: Dictionary) -> Array:
	var rally_count := count_keyword(attacker, KEYWORD_RALLY)
	if rally_count == 0:
		return []
	var controller_player := _get_player_state(match_state, str(attacker.get("controller_player_id", "")))
	if controller_player.is_empty():
		return []
	var candidates: Array = []
	for card in controller_player.get("hand", []):
		if typeof(card) != TYPE_DICTIONARY:
			continue
		ensure_card_state(card)
		if str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
			candidates.append(card)
	if candidates.is_empty():
		return []
	var results: Array = []
	for i in range(rally_count):
		var suffix := str(attacker.get("instance_id", ""))
		if i > 0:
			suffix += "_rally_" + str(i)
		var selected_index := _choose_deterministic_candidate_index(match_state, suffix, candidates)
		var target: Dictionary = candidates[selected_index]
		apply_stat_bonus(target, 1, 1, KEYWORD_RALLY)
		results.append({
			"triggered": true,
			"target_instance_id": str(target.get("instance_id", "")),
			"power_bonus": 1,
			"health_bonus": 1,
		})
	return results


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


static func build_mobilize_recruit(player_id: String, instance_id: String, item_definition_id: String = "") -> Dictionary:
	var recruit_race := _recruit_race_for_item(item_definition_id)
	var recruit := {
		"instance_id": instance_id,
		"definition_id": "generated_recruit",
		"name": "Recruit",
		"owner_player_id": player_id,
		"controller_player_id": player_id,
		"card_type": CARD_TYPE_CREATURE,
		"subtypes": [recruit_race] if not recruit_race.is_empty() else [],
		"attributes": ["neutral"],
		"cost": 0,
		"base_power": 1,
		"base_health": 1,
		"zone": "generated",
		"power": 1,
		"health": 1,
		"rules_text": "",
		"rules_tags": [KEYWORD_MOBILIZE],
		"art_path": "res://assets/images/cards/recruit_%s.png" % recruit_race.to_lower().replace(" ", "_"),
	}
	ensure_card_state(recruit)
	return recruit


const _MOBILIZE_RECRUIT_RACE := {
	# Argonian Recruit
	"end_black_marsh_warden": "Argonian",
	# Breton Recruit
	"aw_str_covenant_plate": "Breton",
	"aw_str_ebonthread_cloak": "Breton",
	"aw_end_poisoned_dagger": "Breton",
	"aw_int_staff_of_ice": "Breton",
	# Dark Elf Recruit
	"aw_agi_inspiring_soldier": "Dark Elf",
	# High Elf Recruit
	"aw_tri_ayrenns_chosen": "High Elf",
	# Imperial Recruit
	"aw_tri_clivia_tharn": "Imperial",
	"aw_tri_empire_recruiter": "Imperial",
	"aw_end_imperial_lackey": "Imperial",
	"aw_end_strategic_deployment": "Imperial",
	# Khajiit Recruit
	"moe_wil_rebel_warden": "Khajiit",
	# Nord Recruit
	"aw_wil_renowned_instructor": "Nord",
	# Orc Recruit
	"aw_end_cruel_axe": "Orc",
	"aw_end_covenant_mail": "Orc",
	# Redguard Recruit
	"aw_tri_covenant_masterpiece": "Redguard",
	"tc_tri_enchanted_ring": "Redguard",
	"aw_int_lion_guard_armaments": "Redguard",
	"aw_str_ornamented_sword": "Redguard",
}


static func _recruit_race_for_item(item_definition_id: String) -> String:
	return _MOBILIZE_RECRUIT_RACE.get(item_definition_id, "Imperial")


static func get_attached_items(card: Dictionary) -> Array:
	ensure_card_state(card)
	return _ensure_array(card.get("attached_items", []))


static func is_creature_destroyed(card: Dictionary, destroyed_by_lethal: bool) -> bool:
	if destroyed_by_lethal and not _has_temporary_immunity(card, "lethal"):
		return true
	return get_remaining_health(card) <= 0


static func _has_temporary_immunity(card: Dictionary, immunity_type: String) -> bool:
	if not card.has("_immune_until_turn"):
		return false
	var card_immunity := str(card.get("_immunity_type", ""))
	return card_immunity == immunity_type or card_immunity == "all"


static func has_temporary_immunity_with_turn(card: Dictionary, immunity_type: String, current_turn: int) -> bool:
	if not card.has("_immune_until_turn"):
		return false
	if int(card.get("_immune_until_turn", -1)) < current_turn:
		return false
	var card_immunity := str(card.get("_immunity_type", ""))
	return card_immunity == immunity_type or card_immunity == "all"


static func get_remaining_health(card: Dictionary) -> int:
	return max(0, get_health(card) - int(card.get("damage_marked", 0)))


static func get_power(card: Dictionary) -> int:
	if _has_passive(card, "power_equals_health"):
		return max(0, get_health(card))
	var base_value := 0
	if card.has("power"):
		base_value = int(card.get("power", 0))
	elif card.has("current_power"):
		base_value = int(card.get("current_power", 0))
	else:
		base_value = int(card.get("base_power", 0))
	return max(0, base_value + int(card.get("power_bonus", 0)) + int(card.get("aura_power_bonus", 0)) + _sum_attached_item_bonus(card, "equip_power_bonus"))


static func get_health(card: Dictionary) -> int:
	var base_value := 0
	if card.has("health"):
		base_value = int(card.get("health", 0))
	elif card.has("current_health"):
		base_value = int(card.get("current_health", 0))
	else:
		base_value = int(card.get("base_health", 0))
	return max(0, base_value + int(card.get("health_bonus", 0)) + int(card.get("aura_health_bonus", 0)) + _sum_attached_item_bonus(card, "equip_health_bonus"))


static func _sync_wounded_status(card: Dictionary) -> void:
	if int(card.get("damage_marked", 0)) > 0:
		add_status(card, STATUS_WOUNDED)
	else:
		remove_status(card, STATUS_WOUNDED)


static func _has_passive(card: Dictionary, passive_type: String) -> bool:
	var passives = card.get("passive_abilities", [])
	if typeof(passives) != TYPE_ARRAY:
		return false
	for p in passives:
		if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == passive_type:
			return true
	return false


static func has_subtype(card: Dictionary, subtype: String) -> bool:
	if _has_passive(card, "all_subtypes"):
		return true
	var subtypes = card.get("subtypes", [])
	return typeof(subtypes) == TYPE_ARRAY and subtypes.has(subtype)


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
