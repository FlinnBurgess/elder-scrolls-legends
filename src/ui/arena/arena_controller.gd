class_name ArenaController
extends Control

signal return_to_menu

const ArenaClassSelectScreenScript = preload("res://src/ui/arena/arena_class_select_screen.gd")
const ArenaDraftScreenScript = preload("res://src/ui/arena/arena_draft_screen.gd")
const ArenaRunStatusScreenScript = preload("res://src/ui/arena/arena_run_status_screen.gd")
const ArenaMatchResultScreenScript = preload("res://src/ui/arena/arena_match_result_screen.gd")
const ArenaRunSummaryScreenScript = preload("res://src/ui/arena/arena_run_summary_screen.gd")
const ArenaRunManagerScript = preload("res://src/arena/arena_run_manager.gd")
const ArenaDraftEngineScript = preload("res://src/arena/arena_draft_engine.gd")
const ArenaEloManagerScript = preload("res://src/arena/arena_elo_manager.gd")
const BossRelicSystemScript = preload("res://src/arena/boss_relic_system.gd")
const MatchScreenScript = preload("res://src/ui/match_screen.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")

var _run_manager = null  # ArenaRunManager instance
var _card_database: Dictionary = {}
var _current_screen: Control = null
var _last_match_won: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_card_database()
	if ArenaRunManagerScript.has_active_run():
		_run_manager = ArenaRunManagerScript.load_run()
		_show_run_status()
	else:
		_show_class_select()


func _load_card_database() -> void:
	var result := CardCatalog.load_default()
	_card_database = result.get("card_by_id", {})


func _clear_screen() -> void:
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null


# --- Screen Navigation ---

func _show_class_select() -> void:
	_clear_screen()
	var screen := ArenaClassSelectScreenScript.new()
	screen.class_selected.connect(_on_class_selected)
	screen.back_pressed.connect(func(): return_to_menu.emit())
	add_child(screen)
	_current_screen = screen


func _on_class_selected(attribute_ids: Array) -> void:
	_run_manager = ArenaRunManagerScript.new()
	_run_manager.start_run(attribute_ids)
	_show_draft()


func _show_draft() -> void:
	_clear_screen()
	var screen := ArenaDraftScreenScript.new()
	screen.draft_complete.connect(_on_draft_complete)
	add_child(screen)
	_current_screen = screen
	screen.start_draft(_run_manager.class_attributes, _card_database)


func _on_draft_complete(deck: Array) -> void:
	_run_manager.complete_draft(deck)
	_show_run_status()


func _show_run_status() -> void:
	_clear_screen()
	# Assign boss relic when approaching the boss match
	if _run_manager.current_match >= 9 and _run_manager.boss_relic == null:
		_run_manager.boss_relic = BossRelicSystemScript.pick_random_relic()
		_run_manager.save_run()
	var screen := ArenaRunStatusScreenScript.new()
	screen.fight_pressed.connect(_on_fight_pressed)
	screen.abandon_pressed.connect(_on_abandon_pressed)
	add_child(screen)
	_current_screen = screen
	screen.set_run_data(
		_run_manager.wins,
		_run_manager.losses,
		_run_manager.current_match,
		_run_manager.boss_relic,
		_run_manager.deck,
		_card_database
	)


func _on_fight_pressed() -> void:
	var match_num: int = _run_manager.current_match
	var config: Dictionary = _run_manager.start_match()

	# Set quality from Elo-based difficulty
	var elo: int = ArenaEloManagerScript.get_elo()
	if match_num >= 9:
		config["quality"] = 1.0
	else:
		var difficulties: Array = ArenaEloManagerScript.get_opponent_difficulties(elo)
		config["quality"] = difficulties[match_num - 1]

	# Build AI deck
	var ai_deck: Array = ArenaDraftEngineScript.draft_ai_deck(
		config["attribute_ids"],
		_card_database,
		config["deck_size"],
		config["quality"]
	)

	# Convert decks to flat card ID arrays for MatchScreen
	var player_deck_ids := _deck_to_card_ids(_run_manager.deck)
	var ai_deck_ids := _deck_to_card_ids(ai_deck)

	# Build boss config if this is the boss match (match 9)
	var boss_config := {}
	if match_num >= 9 and _run_manager.boss_relic != null:
		boss_config = BossRelicSystemScript.get_boss_config(_run_manager.boss_relic)

	_clear_screen()
	var match_screen := MatchScreenScript.new()
	match_screen.name = "ArenaMatch"
	match_screen._arena_mode = true
	match_screen.return_to_main_menu_requested.connect(_on_match_ended.bind(match_screen))
	add_child(match_screen)
	_current_screen = match_screen
	if not boss_config.is_empty():
		match_screen.start_arena_boss_match(player_deck_ids, ai_deck_ids, boss_config)
	else:
		match_screen.start_match_with_decks(player_deck_ids, ai_deck_ids)


func _on_match_ended(match_screen: Control) -> void:
	_last_match_won = match_screen.did_local_player_win()
	if _last_match_won:
		_run_manager.record_win()
	else:
		_run_manager.record_loss()
	_show_match_result()


func _show_match_result() -> void:
	_clear_screen()
	var screen := ArenaMatchResultScreenScript.new()
	screen.continue_pressed.connect(_on_match_result_continue)
	add_child(screen)
	_current_screen = screen
	screen.set_result(_last_match_won)


func _on_match_result_continue() -> void:
	if _run_manager.state == ArenaRunManagerScript.State.RUN_COMPLETE:
		_show_run_summary()
	elif _run_manager.state == ArenaRunManagerScript.State.POST_MATCH_PICK:
		_show_post_win_pick()
	else:
		_show_run_status()


func _show_post_win_pick() -> void:
	_clear_screen()
	var screen := ArenaDraftScreenScript.new()
	screen.draft_complete.connect(_on_post_win_pick_complete)
	add_child(screen)
	_current_screen = screen
	screen.start_bonus_pick(_run_manager.deck, _run_manager.class_attributes, _card_database)


func _on_post_win_pick_complete(new_deck: Array) -> void:
	# Find the card that was added by diffing old and new decks
	var picked_card := _find_added_card(_run_manager.deck, new_deck)
	_run_manager.complete_post_match_pick(picked_card)
	_show_run_status()


func _show_run_summary() -> void:
	_clear_screen()
	var screen := ArenaRunSummaryScreenScript.new()
	screen.return_pressed.connect(_on_run_summary_return)
	add_child(screen)
	_current_screen = screen
	screen.set_run_result(_run_manager.wins, _run_manager.losses)


func _on_run_summary_return() -> void:
	# Update Elo based on run performance
	var current_elo: int = ArenaEloManagerScript.get_elo()
	var new_elo: int = ArenaEloManagerScript.update_elo_after_run(current_elo, _run_manager.wins)
	ArenaEloManagerScript.save_elo(new_elo)
	_run_manager = null
	return_to_menu.emit()


func _on_abandon_pressed() -> void:
	_run_manager.abandon_run()
	_run_manager = null
	return_to_menu.emit()


# --- Helpers ---

static func _deck_to_card_ids(deck: Array) -> Array:
	var ids: Array = []
	for entry in deck:
		var card_id: String = str(entry.get("card_id", ""))
		var quantity: int = int(entry.get("quantity", 0))
		for _i in range(quantity):
			ids.append(card_id)
	return ids


static func _find_added_card(old_deck: Array, new_deck: Array) -> Dictionary:
	var old_qty := {}
	for entry in old_deck:
		old_qty[entry["card_id"]] = entry.get("quantity", 0)
	for entry in new_deck:
		var cid: String = entry["card_id"]
		var new_q: int = entry.get("quantity", 0)
		var old_q: int = old_qty.get(cid, 0)
		if new_q > old_q:
			return {"card_id": cid}
	return {}
