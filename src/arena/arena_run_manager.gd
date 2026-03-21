class_name ArenaRunManager
extends RefCounted

enum State {
	CLASS_SELECT,
	DRAFTING,
	READY_FOR_MATCH,
	IN_MATCH,
	POST_MATCH_PICK,
	RUN_COMPLETE,
}

var state: State = State.CLASS_SELECT
var class_attributes: Array = []
var deck: Array = []  # Array of {card_id, quantity}
var wins: int = 0
var losses: int = 0
var current_match: int = 1
var boss_relic = null  # Will be set by BossRelicSystem later
var boss_deck: Array = []  # Persisted boss AI deck so retries face the same deck
var draft_progress: Variant = null  # Mid-draft state for resume
var match_config: Variant = null  # Match setup for resume (opponent attrs, AI deck, boss config, seed, first_player_index)
var _used_opponent_attributes: Array = []  # Track used opponent classes to avoid repeats

const RUN_DIR := "user://arena/"
const RUN_PATH := "user://arena/run.json"
const MATCH_STATE_PATH := "user://arena/match_state.json"
const CLASS_OPTIONS_PATH := "user://arena/class_options.json"

# All 10 dual-attribute classes
const DUAL_CLASSES: Array = [
	["strength", "agility"],       # Archer
	["intelligence", "agility"],   # Assassin
	["strength", "intelligence"],  # Battlemage
	["strength", "willpower"],     # Crusader
	["intelligence", "willpower"], # Mage
	["willpower", "agility"],      # Monk
	["agility", "endurance"],      # Scout
	["intelligence", "endurance"], # Sorcerer
	["willpower", "endurance"],    # Spellsword
	["strength", "endurance"],     # Warrior
]


func start_run(p_class_attributes: Array) -> void:
	class_attributes = p_class_attributes.duplicate()
	state = State.DRAFTING
	deck = []
	wins = 0
	losses = 0
	current_match = 1
	boss_relic = null
	boss_deck = []
	draft_progress = null
	match_config = null
	_used_opponent_attributes = []
	save_run()


func complete_draft(p_deck: Array) -> void:
	deck = p_deck.duplicate(true)
	draft_progress = null
	state = State.READY_FOR_MATCH
	save_run()


func start_match() -> Dictionary:
	state = State.IN_MATCH
	var opponent_attrs := _pick_opponent_attributes()
	_used_opponent_attributes.append(opponent_attrs)
	var deck_size := 29 + current_match
	var config := {
		"attribute_ids": opponent_attrs,
		"deck_size": deck_size,
		"quality": 0.5,  # Default; ArenaEloManager will set this later
	}
	return config


func record_win() -> void:
	wins += 1
	match_config = null
	if current_match >= 9:
		state = State.RUN_COMPLETE
		clear_run()
	else:
		state = State.POST_MATCH_PICK
		save_run()
	current_match += 1


func record_loss() -> void:
	losses += 1
	match_config = null
	current_match += 1
	if losses >= 3:
		state = State.RUN_COMPLETE
		clear_run()
	else:
		state = State.READY_FOR_MATCH
		save_run()


func complete_post_match_pick(card: Dictionary) -> void:
	# Add card to deck - find existing entry or add new one
	var found := false
	for i in range(deck.size()):
		if deck[i]["card_id"] == card["card_id"]:
			deck[i]["quantity"] += 1
			found = true
			break
	if not found:
		deck.append({"card_id": card["card_id"], "quantity": 1})
	state = State.READY_FOR_MATCH
	save_run()


func abandon_run() -> void:
	state = State.RUN_COMPLETE
	clear_run()


func save_run() -> void:
	_ensure_directory()
	var file := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ArenaRunManager: failed to open '%s' for writing: %s" % [RUN_PATH, FileAccess.get_open_error()])
		return
	var data := {
		"state": state,
		"class_attributes": class_attributes,
		"deck": deck,
		"wins": wins,
		"losses": losses,
		"current_match": current_match,
		"boss_relic": boss_relic,
		"boss_deck": boss_deck,
		"used_opponent_attributes": _used_opponent_attributes,
		"draft_progress": draft_progress,
		"match_config": match_config,
	}
	file.store_string(JSON.stringify(data, "\t"))


static func load_run() -> ArenaRunManager:
	if not FileAccess.file_exists(RUN_PATH):
		return null
	var file := FileAccess.open(RUN_PATH, FileAccess.READ)
	if file == null:
		push_error("ArenaRunManager: failed to open '%s' for reading: %s" % [RUN_PATH, FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("ArenaRunManager: failed to parse '%s': %s" % [RUN_PATH, json.get_error_message()])
		return null
	if not json.data is Dictionary:
		return null
	var data: Dictionary = json.data
	var script := load("res://src/arena/arena_run_manager.gd")
	var manager = script.new()
	manager.state = int(data.get("state", State.CLASS_SELECT)) as State
	manager.class_attributes = Array(data.get("class_attributes", []))
	manager.deck = Array(data.get("deck", []))
	manager.wins = int(data.get("wins", 0))
	manager.losses = int(data.get("losses", 0))
	manager.current_match = int(data.get("current_match", 1))
	manager.boss_relic = data.get("boss_relic")
	manager.boss_deck = Array(data.get("boss_deck", []))
	manager._used_opponent_attributes = Array(data.get("used_opponent_attributes", []))
	manager.draft_progress = data.get("draft_progress")
	manager.match_config = data.get("match_config")
	return manager


static func has_active_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)


func clear_run() -> void:
	clear_match_state()
	if not FileAccess.file_exists(RUN_PATH):
		return
	var dir := DirAccess.open(RUN_DIR)
	if dir == null:
		return
	dir.remove("run.json")


func save_match_state(match_state: Dictionary) -> void:
	_ensure_directory()
	var file := FileAccess.open(MATCH_STATE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ArenaRunManager: failed to open '%s' for writing: %s" % [MATCH_STATE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(match_state, "\t"))


static func load_match_state() -> Dictionary:
	if not FileAccess.file_exists(MATCH_STATE_PATH):
		return {}
	var file := FileAccess.open(MATCH_STATE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("ArenaRunManager: failed to parse '%s': %s" % [MATCH_STATE_PATH, json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		return {}
	return json.data


func clear_match_state() -> void:
	if not FileAccess.file_exists(MATCH_STATE_PATH):
		return
	var dir := DirAccess.open(RUN_DIR)
	if dir == null:
		return
	dir.remove("match_state.json")


static func has_saved_match_state() -> bool:
	return FileAccess.file_exists(MATCH_STATE_PATH)


static func save_class_options(options: Array) -> void:
	_ensure_directory()
	var file := FileAccess.open(CLASS_OPTIONS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ArenaRunManager: failed to open '%s' for writing: %s" % [CLASS_OPTIONS_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(options, "\t"))


static func load_class_options() -> Array:
	if not FileAccess.file_exists(CLASS_OPTIONS_PATH):
		return []
	var file := FileAccess.open(CLASS_OPTIONS_PATH, FileAccess.READ)
	if file == null:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Array:
		return []
	return json.data


static func clear_class_options() -> void:
	if not FileAccess.file_exists(CLASS_OPTIONS_PATH):
		return
	var dir := DirAccess.open(RUN_DIR)
	if dir == null:
		return
	dir.remove("class_options.json")


static func _ensure_directory() -> void:
	if not DirAccess.dir_exists_absolute(RUN_DIR):
		DirAccess.make_dir_recursive_absolute(RUN_DIR)


func _pick_opponent_attributes() -> Array:
	# Build list of available classes, excluding player's class and previously used ones
	var available: Array = []
	for dual_class in DUAL_CLASSES:
		if _arrays_equal(dual_class, class_attributes):
			continue
		var already_used := false
		for used in _used_opponent_attributes:
			if _arrays_equal(dual_class, used):
				already_used = true
				break
		if not already_used:
			available.append(dual_class)

	# If all classes have been used, allow repeats (excluding player's class)
	if available.is_empty():
		for dual_class in DUAL_CLASSES:
			if not _arrays_equal(dual_class, class_attributes):
				available.append(dual_class)

	return available[randi() % available.size()]


static func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var sorted_a := a.duplicate()
	sorted_a.sort()
	var sorted_b := b.duplicate()
	sorted_b.sort()
	for i in range(sorted_a.size()):
		if sorted_a[i] != sorted_b[i]:
			return false
	return true
