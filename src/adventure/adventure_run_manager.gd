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
var gold: int = 0
var max_health_bonus: int = 0
var added_cards: Array = []  # Array of card_id strings added during run
var node_offerings: Dictionary = {}  # node_id -> {cards: Array, purchased_ids: Array}
var active_boons: Array = []  # Array of boon_id strings; duplicates allowed for stackable boons
var reroll_tokens: int = 1
var augments: Array = []  # Array of {card_id: String, augment_id: String}

const _DEFAULT_RUN_DIR := "user://adventure/"
static var _run_dir_override: String = ""
const STARTING_REVIVES := 1
const STARTING_REROLL_TOKENS := 1
const GOLD_PER_COMBAT := 30
const GOLD_PER_MINI_BOSS := 60
const HEALER_HEALTH_BONUS := 5


func start_run(p_adventure_id: String, p_deck_id: String, p_deck_cards: Array, start_node_id: String) -> void:
	adventure_id = p_adventure_id
	deck_id = p_deck_id
	deck_cards = p_deck_cards.duplicate(true)
	current_node_id = start_node_id
	completed_node_ids = []
	revives_remaining = STARTING_REVIVES
	run_won = false
	match_config = null
	gold = 0
	max_health_bonus = 0
	added_cards = []
	node_offerings = {}
	active_boons = []
	reroll_tokens = STARTING_REROLL_TOKENS
	augments = []
	state = State.VIEWING_MAP
	save_run()


func start_match() -> void:
	state = State.IN_MATCH
	save_run()


func record_win(adventure: Dictionary) -> void:
	match_config = null
	completed_node_ids.append(current_node_id)

	var node: Dictionary = adventure.get("nodes", {}).get(current_node_id, {})
	var node_type: String = str(node.get("type", ""))

	# Award gold based on node type
	if node_type == "mini_boss":
		gold += GOLD_PER_MINI_BOSS
	elif node_type in ["combat", "final_boss"]:
		gold += GOLD_PER_COMBAT

	var next_nodes: Array = node.get("next", [])

	if next_nodes.is_empty():
		# Final node — run won
		run_won = true
		state = State.RUN_COMPLETE
		clear_run()
	elif next_nodes.size() == 1:
		current_node_id = str(next_nodes[0])
		state = State.VIEWING_MAP
		save_run()
	else:
		# Branching — stay on map, player picks next node
		current_node_id = ""
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


func complete_non_combat_node(adventure: Dictionary) -> void:
	completed_node_ids.append(current_node_id)
	var node: Dictionary = adventure.get("nodes", {}).get(current_node_id, {})
	var next_nodes: Array = node.get("next", [])

	if next_nodes.size() == 1:
		current_node_id = str(next_nodes[0])
	else:
		# Branching — player picks next node from map
		current_node_id = ""
	state = State.VIEWING_MAP
	save_run()


func choose_next_node(node_id: String) -> void:
	current_node_id = node_id
	save_run()


func add_boon(boon_id: String) -> void:
	active_boons.append(boon_id)
	save_run()


func get_boon_stacks(boon_id: String) -> int:
	var count := 0
	for b in active_boons:
		if str(b) == boon_id:
			count += 1
	return count


func add_card(card_id: String) -> void:
	added_cards.append(card_id)
	save_run()


func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	save_run()
	return true


func apply_healer_bonus() -> void:
	max_health_bonus += HEALER_HEALTH_BONUS
	save_run()


func get_node_offering(node_id: String) -> Dictionary:
	return node_offerings.get(node_id, {})


func save_node_offering(node_id: String, cards: Array) -> void:
	node_offerings[node_id] = {"cards": cards, "purchased_ids": []}
	save_run()


func use_reroll_token() -> bool:
	if reroll_tokens <= 0:
		return false
	reroll_tokens -= 1
	save_run()
	return true


func add_augment(card_id: String, augment_id: String) -> void:
	augments.append({"card_id": card_id, "augment_id": augment_id})
	save_run()


func clear_node_offering(node_id: String) -> void:
	node_offerings.erase(node_id)
	save_run()


func mark_card_purchased(node_id: String, card_id: String) -> void:
	var offering: Dictionary = node_offerings.get(node_id, {})
	if offering.is_empty():
		return
	var purchased: Array = offering.get("purchased_ids", [])
	purchased.append(card_id)
	offering["purchased_ids"] = purchased
	save_run()


func get_full_deck_cards() -> Array:
	var full := deck_cards.duplicate(true)
	for card_id in added_cards:
		full.append({"card_id": card_id, "quantity": 1})
	return full


func abandon_run() -> void:
	run_won = false
	state = State.RUN_COMPLETE
	clear_run()


func save_run() -> void:
	_ensure_directory()
	var file := FileAccess.open(_get_run_path(), FileAccess.WRITE)
	if file == null:
		push_error("AdventureRunManager: failed to open '%s' for writing: %s" % [_get_run_path(), FileAccess.get_open_error()])
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
		"gold": gold,
		"max_health_bonus": max_health_bonus,
		"added_cards": added_cards,
		"node_offerings": node_offerings,
		"active_boons": active_boons,
		"reroll_tokens": reroll_tokens,
		"augments": augments,
	}
	file.store_string(JSON.stringify(data, "\t"))


static func load_run() -> AdventureRunManager:
	if not FileAccess.file_exists(_get_run_path()):
		return null
	var file := FileAccess.open(_get_run_path(), FileAccess.READ)
	if file == null:
		push_error("AdventureRunManager: failed to open '%s' for reading: %s" % [_get_run_path(), FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("AdventureRunManager: failed to parse '%s': %s" % [_get_run_path(), json.get_error_message()])
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
	manager.gold = int(data.get("gold", 0))
	manager.max_health_bonus = int(data.get("max_health_bonus", 0))
	manager.added_cards = Array(data.get("added_cards", []))
	manager.active_boons = Array(data.get("active_boons", []))
	manager.reroll_tokens = int(data.get("reroll_tokens", STARTING_REROLL_TOKENS))
	manager.augments = Array(data.get("augments", []))
	var offerings_raw = data.get("node_offerings", {})
	if offerings_raw is Dictionary:
		manager.node_offerings = offerings_raw
	return manager


static func has_active_run() -> bool:
	return FileAccess.file_exists(_get_run_path())


func clear_run() -> void:
	clear_match_state()
	if not FileAccess.file_exists(_get_run_path()):
		return
	var dir := DirAccess.open(_get_run_dir())
	if dir == null:
		return
	dir.remove("run.json")


func save_match_state(match_state: Dictionary) -> void:
	_ensure_directory()
	var file := FileAccess.open(_get_match_state_path(), FileAccess.WRITE)
	if file == null:
		push_error("AdventureRunManager: failed to open '%s' for writing: %s" % [_get_match_state_path(), FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(match_state, "\t"))


static func load_match_state() -> Dictionary:
	if not FileAccess.file_exists(_get_match_state_path()):
		return {}
	var file := FileAccess.open(_get_match_state_path(), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("AdventureRunManager: failed to parse '%s': %s" % [_get_match_state_path(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		return {}
	return json.data


func clear_match_state() -> void:
	if not FileAccess.file_exists(_get_match_state_path()):
		return
	var dir := DirAccess.open(_get_run_dir())
	if dir == null:
		return
	dir.remove("match_state.json")


static func has_saved_match_state() -> bool:
	return FileAccess.file_exists(_get_match_state_path())


static func set_storage_dir_override(dir_path: String) -> void:
	_run_dir_override = dir_path


static func _get_run_dir() -> String:
	return _run_dir_override if not _run_dir_override.is_empty() else _DEFAULT_RUN_DIR


static func _get_run_path() -> String:
	return _get_run_dir() + "run.json"


static func _get_match_state_path() -> String:
	return _get_run_dir() + "match_state.json"


static func _ensure_directory() -> void:
	var dir := _get_run_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
