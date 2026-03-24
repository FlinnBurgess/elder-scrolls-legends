class_name AdventureRunManager
extends RefCounted

enum State {
	DECK_SELECT,
	ADVENTURE_SELECT,
	VIEWING_MAP,
	IN_MATCH,
	RUN_COMPLETE,
}

var state: State = State.DECK_SELECT
var adventure_id: String = ""
var deck_id: String = ""
var deck_cards: Array = []  # Array of {card_id, quantity}
var current_node_id: String = ""
var completed_node_ids: Array = []
var revives_remaining: int = 1
var run_won: bool = false
var match_config: Variant = null  # For match resume

const RUN_DIR := "user://adventure/"
const RUN_PATH := "user://adventure/run.json"
const MATCH_STATE_PATH := "user://adventure/match_state.json"
const STARTING_REVIVES := 1


func start_run(p_adventure_id: String, p_deck_id: String, p_deck_cards: Array, start_node_id: String) -> void:
	adventure_id = p_adventure_id
	deck_id = p_deck_id
	deck_cards = p_deck_cards.duplicate(true)
	current_node_id = start_node_id
	completed_node_ids = []
	revives_remaining = STARTING_REVIVES
	run_won = false
	match_config = null
	state = State.VIEWING_MAP
	save_run()


func start_match() -> void:
	state = State.IN_MATCH
	save_run()


func record_win(adventure: Dictionary) -> void:
	match_config = null
	completed_node_ids.append(current_node_id)

	var node: Dictionary = adventure.get("nodes", {}).get(current_node_id, {})
	var next_nodes: Array = node.get("next", [])

	if next_nodes.is_empty():
		# Final node — run won
		run_won = true
		state = State.RUN_COMPLETE
		clear_run()
	else:
		# Advance to next node (linear for M1)
		current_node_id = str(next_nodes[0])
		state = State.VIEWING_MAP
		save_run()


func record_loss() -> void:
	match_config = null
	if revives_remaining > 0:
		revives_remaining -= 1
		state = State.VIEWING_MAP
		save_run()
	else:
		run_won = false
		state = State.RUN_COMPLETE
		clear_run()


func abandon_run() -> void:
	run_won = false
	state = State.RUN_COMPLETE
	clear_run()


func save_run() -> void:
	_ensure_directory()
	var file := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if file == null:
		push_error("AdventureRunManager: failed to open '%s' for writing: %s" % [RUN_PATH, FileAccess.get_open_error()])
		return
	var data := {
		"state": state,
		"adventure_id": adventure_id,
		"deck_id": deck_id,
		"deck_cards": deck_cards,
		"current_node_id": current_node_id,
		"completed_node_ids": completed_node_ids,
		"revives_remaining": revives_remaining,
		"run_won": run_won,
		"match_config": match_config,
	}
	file.store_string(JSON.stringify(data, "\t"))


static func load_run() -> AdventureRunManager:
	if not FileAccess.file_exists(RUN_PATH):
		return null
	var file := FileAccess.open(RUN_PATH, FileAccess.READ)
	if file == null:
		push_error("AdventureRunManager: failed to open '%s' for reading: %s" % [RUN_PATH, FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("AdventureRunManager: failed to parse '%s': %s" % [RUN_PATH, json.get_error_message()])
		return null
	if not json.data is Dictionary:
		return null
	var data: Dictionary = json.data
	var script := load("res://src/adventure/adventure_run_manager.gd")
	var manager = script.new()
	manager.state = int(data.get("state", State.DECK_SELECT)) as State
	manager.adventure_id = str(data.get("adventure_id", ""))
	manager.deck_id = str(data.get("deck_id", ""))
	manager.deck_cards = Array(data.get("deck_cards", []))
	manager.current_node_id = str(data.get("current_node_id", ""))
	manager.completed_node_ids = Array(data.get("completed_node_ids", []))
	manager.revives_remaining = int(data.get("revives_remaining", STARTING_REVIVES))
	manager.run_won = bool(data.get("run_won", false))
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
		push_error("AdventureRunManager: failed to open '%s' for writing: %s" % [MATCH_STATE_PATH, FileAccess.get_open_error()])
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
		push_error("AdventureRunManager: failed to parse '%s': %s" % [MATCH_STATE_PATH, json.get_error_message()])
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


static func _ensure_directory() -> void:
	if not DirAccess.dir_exists_absolute(RUN_DIR):
		DirAccess.make_dir_recursive_absolute(RUN_DIR)
