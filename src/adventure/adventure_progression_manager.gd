class_name AdventureProgressionManager
extends RefCounted

## Manages all persistent cross-run progression for Path of Tamriel:
## per-deck levels/XP, star powers, equipped relics, card swaps, permanent augments,
## account-wide unlocked relics, adventure completion history, and last selected deck.

const PROGRESSION_DIR := "res://data/deck_progression/"
const GLOBAL_CONFIG_PATH := "res://data/adventure_progression.json"

const _DEFAULT_SAVE_DIR := "user://adventure/"
static var _save_dir_override: String = ""

# --- Persistent state ---

## Per-deck progression: { deck_id: { xp: int, equipped_relics: [relic_id...] } }
## Level, star powers, card swaps, and permanent augments are derived from XP + reward track.
var deck_data: Dictionary = {}

## Account-wide unlocked relic IDs
var unlocked_relics: Array = []

## Adventure completion history: { adventure_id: { completed: bool, completion_count: int } }
var adventure_completions: Dictionary = {}

## Last selected deck ID (auto-loaded on adventure mode entry)
var last_selected_deck_id: String = ""

# --- Cached config (loaded from data files) ---

var _global_config: Dictionary = {}
var _deck_progression_cache: Dictionary = {}  # deck_id -> progression data


# --- Initialization ---

func _init() -> void:
	_load_global_config()


# --- Deck Level & XP ---

func get_deck_xp(deck_id: String) -> int:
	return int(_get_deck_entry(deck_id).get("xp", 0))


func get_deck_level(deck_id: String) -> int:
	var xp := get_deck_xp(deck_id)
	var thresholds: Array = _get_xp_thresholds()
	var level := 0
	var total := 0
	for i in range(thresholds.size()):
		total += int(thresholds[i])
		if xp >= total:
			level = i + 1
		else:
			break
	return level


func get_xp_for_next_level(deck_id: String) -> Dictionary:
	## Returns { current_xp: int, xp_into_level: int, xp_needed: int, is_max: bool }
	var xp := get_deck_xp(deck_id)
	var thresholds: Array = _get_xp_thresholds()
	var total := 0
	for i in range(thresholds.size()):
		var threshold := int(thresholds[i])
		if xp < total + threshold:
			return {
				"current_xp": xp,
				"xp_into_level": xp - total,
				"xp_needed": threshold,
				"is_max": false,
			}
		total += threshold
	return {"current_xp": xp, "xp_into_level": 0, "xp_needed": 0, "is_max": true}


func award_xp(deck_id: String, amount: int) -> Dictionary:
	## Awards XP and processes any level-ups. Returns summary:
	## { old_level: int, new_level: int, rewards: Array, new_star_powers: Array, new_relic_slots: int }
	var old_level := get_deck_level(deck_id)
	var entry := _get_deck_entry(deck_id)
	entry["xp"] = int(entry.get("xp", 0)) + amount
	deck_data[deck_id] = entry
	var new_level := get_deck_level(deck_id)

	var rewards: Array = []
	var new_star_powers: Array = []
	var new_relic_slots := 0

	if new_level > old_level:
		var progression := _get_deck_progression(deck_id)
		var reward_track: Array = progression.get("reward_track", [])
		var star_powers: Array = progression.get("star_powers", [])
		var star_levels: Array = _get_star_power_levels()
		var relic_levels: Array = _get_relic_slot_levels()

		for level in range(old_level + 1, new_level + 1):
			# Process reward track entry for this level
			for reward in reward_track:
				if int(reward.get("level", 0)) == level:
					rewards.append(reward)
					_apply_reward(deck_id, reward)

			# Check for star power unlock
			for si in range(star_levels.size()):
				if int(star_levels[si]) == level and si < star_powers.size():
					new_star_powers.append(star_powers[si])

			# Check for relic slot unlock
			if level in relic_levels:
				new_relic_slots += 1

	save()
	return {
		"old_level": old_level,
		"new_level": new_level,
		"rewards": rewards,
		"new_star_powers": new_star_powers,
		"new_relic_slots": new_relic_slots,
	}


# --- Reward Application ---

func _apply_reward(deck_id: String, reward: Dictionary) -> void:
	var reward_type := str(reward.get("type", ""))
	var entry := _get_deck_entry(deck_id)
	match reward_type:
		"card_swap":
			var swaps: Array = entry.get("card_swaps", [])
			swaps.append({
				"remove": str(reward.get("remove", "")),
				"add": str(reward.get("add", "")),
			})
			entry["card_swaps"] = swaps
		"permanent_augment":
			var augments: Array = entry.get("permanent_augments", [])
			augments.append({
				"card_id": str(reward.get("card_id", "")),
				"augment_id": str(reward.get("augment_id", "")),
			})
			entry["permanent_augments"] = augments
		# Cumulative bonuses are stored as totals
		"starting_gold":
			entry["starting_gold"] = int(entry.get("starting_gold", 0)) + int(reward.get("value", 0))
		"max_health":
			entry["max_health_bonus"] = int(entry.get("max_health_bonus", 0)) + int(reward.get("value", 0))
		"reroll_tokens":
			entry["bonus_reroll_tokens"] = int(entry.get("bonus_reroll_tokens", 0)) + int(reward.get("value", 0))
		"revives":
			entry["bonus_revives"] = int(entry.get("bonus_revives", 0)) + int(reward.get("value", 0))
	deck_data[deck_id] = entry


# --- Effective Deck Computation ---

func get_starting_gold(deck_id: String) -> int:
	return int(_get_deck_entry(deck_id).get("starting_gold", 0))


func get_max_health_bonus(deck_id: String) -> int:
	return int(_get_deck_entry(deck_id).get("max_health_bonus", 0))


func get_bonus_reroll_tokens(deck_id: String) -> int:
	return int(_get_deck_entry(deck_id).get("bonus_reroll_tokens", 0))


func get_bonus_revives(deck_id: String) -> int:
	return int(_get_deck_entry(deck_id).get("bonus_revives", 0))


func get_card_swaps(deck_id: String) -> Array:
	return _get_deck_entry(deck_id).get("card_swaps", [])


func get_permanent_augments(deck_id: String) -> Array:
	return _get_deck_entry(deck_id).get("permanent_augments", [])


func get_effective_deck_cards(deck_id: String, base_cards: Array) -> Array:
	## Returns deck cards with card swaps applied. Does NOT apply augments
	## (those are applied at match time via AugmentRules).
	var cards := base_cards.duplicate(true)
	var swaps := get_card_swaps(deck_id)
	for swap in swaps:
		var remove_id := str(swap.get("remove", ""))
		var add_id := str(swap.get("add", ""))
		if remove_id.is_empty() or add_id.is_empty():
			continue
		# Find and replace the first instance of the removed card
		var replaced := false
		for i in range(cards.size()):
			if str(cards[i].get("card_id", "")) == remove_id:
				# Reduce quantity by 1 or remove entry
				var qty := int(cards[i].get("quantity", 1))
				if qty > 1:
					cards[i]["quantity"] = qty - 1
				else:
					cards.remove_at(i)
				replaced = true
				break
		if replaced:
			# Check if the added card already exists
			var found := false
			for i in range(cards.size()):
				if str(cards[i].get("card_id", "")) == add_id:
					cards[i]["quantity"] = int(cards[i].get("quantity", 1)) + 1
					found = true
					break
			if not found:
				cards.append({"card_id": add_id, "quantity": 1})
	return cards


# --- Star Powers ---

func get_active_star_powers(deck_id: String) -> Array:
	## Returns star power boon definitions for the deck's current level.
	var level := get_deck_level(deck_id)
	var progression := _get_deck_progression(deck_id)
	var star_powers: Array = progression.get("star_powers", [])
	var star_levels: Array = _get_star_power_levels()
	var active: Array = []
	for i in range(mini(star_levels.size(), star_powers.size())):
		if level >= int(star_levels[i]):
			active.append(star_powers[i])
	return active


func get_unlocked_star_count(deck_id: String) -> int:
	return get_active_star_powers(deck_id).size()


# --- Relic Slots ---

func get_unlocked_relic_slot_count(deck_id: String) -> int:
	var level := get_deck_level(deck_id)
	var relic_levels: Array = _get_relic_slot_levels()
	var count := 0
	for rl in relic_levels:
		if level >= int(rl):
			count += 1
	return count


func get_equipped_relics(deck_id: String) -> Array:
	return _get_deck_entry(deck_id).get("equipped_relics", [])


func equip_relic(deck_id: String, relic_id: String) -> bool:
	if relic_id not in unlocked_relics:
		return false
	var slots := get_unlocked_relic_slot_count(deck_id)
	var equipped: Array = get_equipped_relics(deck_id)
	if equipped.size() >= slots:
		return false
	if relic_id in equipped:
		return false
	equipped.append(relic_id)
	var entry := _get_deck_entry(deck_id)
	entry["equipped_relics"] = equipped
	deck_data[deck_id] = entry
	save()
	return true


func unequip_relic(deck_id: String, relic_id: String) -> void:
	var entry := _get_deck_entry(deck_id)
	var equipped: Array = entry.get("equipped_relics", [])
	equipped.erase(relic_id)
	entry["equipped_relics"] = equipped
	deck_data[deck_id] = entry
	save()


# --- Adventure Completion ---

func record_adventure_completion(adventure_id: String, adventure: Dictionary) -> Dictionary:
	## Records an adventure completion and returns rewards earned:
	## { first_clear_reward: Variant, bonus_reward: Variant }
	var result := {"first_clear_reward": null, "bonus_reward": null}

	var entry: Dictionary = adventure_completions.get(adventure_id, {})
	var was_completed: bool = bool(entry.get("completed", false))
	entry["completed"] = true
	entry["completion_count"] = int(entry.get("completion_count", 0)) + 1
	adventure_completions[adventure_id] = entry

	# First clear reward
	if not was_completed:
		var reward = adventure.get("first_completion_reward", {})
		if typeof(reward) == TYPE_DICTIONARY and not reward.is_empty():
			_apply_completion_reward(reward)
			result["first_clear_reward"] = reward

	# Random bonus reward
	var drop_rate: float = float(_global_config.get("adventure_completion_bonus_drop_rate", 0.1))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < drop_rate:
		var pool: Array = adventure.get("completion_reward_pool", [])
		if not pool.is_empty():
			var reward := _pick_weighted_reward(pool, rng)
			if not reward.is_empty():
				_apply_completion_reward(reward)
				result["bonus_reward"] = reward

	save()
	return result


func is_adventure_completed(adventure_id: String) -> bool:
	var entry: Dictionary = adventure_completions.get(adventure_id, {})
	return bool(entry.get("completed", false))


func _apply_completion_reward(reward: Dictionary) -> void:
	var reward_type := str(reward.get("type", ""))
	match reward_type:
		"relic":
			var relic_id := str(reward.get("relic_id", ""))
			if not relic_id.is_empty() and relic_id not in unlocked_relics:
				unlocked_relics.append(relic_id)


func _pick_weighted_reward(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total_weight := 0.0
	for entry in pool:
		total_weight += float(entry.get("weight", 1))
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	for entry in pool:
		cumulative += float(entry.get("weight", 1))
		if roll <= cumulative:
			return entry
	return pool.back() if not pool.is_empty() else {}


# --- Save / Load ---

func save() -> void:
	_ensure_save_dir()
	var path := _get_save_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("AdventureProgressionManager: failed to write '%s': %s" % [path, FileAccess.get_open_error()])
		return
	var data := {
		"deck_data": deck_data,
		"unlocked_relics": unlocked_relics,
		"adventure_completions": adventure_completions,
		"last_selected_deck_id": last_selected_deck_id,
	}
	file.store_string(JSON.stringify(data, "\t"))


static func load_progression() -> AdventureProgressionManager:
	var path := _get_save_path()
	var script := load("res://src/adventure/adventure_progression_manager.gd")
	var manager = script.new()
	if not FileAccess.file_exists(path):
		return manager
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AdventureProgressionManager: failed to read '%s': %s" % [path, FileAccess.get_open_error()])
		return manager
	var text := file.get_as_text()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("AdventureProgressionManager: failed to parse '%s': %s" % [path, json.get_error_message()])
		return manager
	if not json.data is Dictionary:
		return manager
	var data: Dictionary = json.data
	manager.deck_data = data.get("deck_data", {}) if data.get("deck_data") is Dictionary else {}
	manager.unlocked_relics = Array(data.get("unlocked_relics", []))
	manager.adventure_completions = data.get("adventure_completions", {}) if data.get("adventure_completions") is Dictionary else {}
	manager.last_selected_deck_id = str(data.get("last_selected_deck_id", ""))
	return manager


func clear_save() -> void:
	var path := _get_save_path()
	if FileAccess.file_exists(path):
		var dir := DirAccess.open(_get_save_dir())
		if dir != null:
			dir.remove("progression.json")


# --- Config Helpers ---

func _get_deck_entry(deck_id: String) -> Dictionary:
	if not deck_data.has(deck_id):
		deck_data[deck_id] = {"xp": 0, "equipped_relics": []}
	var entry = deck_data[deck_id]
	if not entry is Dictionary:
		entry = {"xp": 0, "equipped_relics": []}
		deck_data[deck_id] = entry
	return entry


func _get_deck_progression(deck_id: String) -> Dictionary:
	if _deck_progression_cache.has(deck_id):
		return _deck_progression_cache[deck_id]
	var path := PROGRESSION_DIR + deck_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AdventureProgressionManager: no progression data at '%s'" % path)
		_deck_progression_cache[deck_id] = {}
		return {}
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AdventureProgressionManager: invalid progression data at '%s'" % path)
		_deck_progression_cache[deck_id] = {}
		return {}
	_deck_progression_cache[deck_id] = parsed
	return parsed


func _load_global_config() -> void:
	var file := FileAccess.open(GLOBAL_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("AdventureProgressionManager: failed to load global config at '%s'" % GLOBAL_CONFIG_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_global_config = parsed


func _get_xp_thresholds() -> Array:
	return _global_config.get("xp_thresholds", [])


func _get_star_power_levels() -> Array:
	return _global_config.get("star_power_levels", [5, 15, 25])


func _get_relic_slot_levels() -> Array:
	return _global_config.get("relic_slot_levels", [10, 20, 30])


# --- Storage Paths ---

static func set_save_dir_override(dir_path: String) -> void:
	_save_dir_override = dir_path


static func _get_save_dir() -> String:
	return _save_dir_override if not _save_dir_override.is_empty() else _DEFAULT_SAVE_DIR


static func _get_save_path() -> String:
	return _get_save_dir() + "progression.json"


static func _ensure_save_dir() -> void:
	var dir := _get_save_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
