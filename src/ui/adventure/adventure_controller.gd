class_name AdventureController
extends Control

signal return_to_menu

const AdventureCatalogScript = preload("res://src/adventure/adventure_catalog.gd")
const AdventureRunManagerScript = preload("res://src/adventure/adventure_run_manager.gd")
const AdventureDeckLoaderScript = preload("res://src/adventure/adventure_deck_loader.gd")
const AdventureCardPoolScript = preload("res://src/adventure/adventure_card_pool.gd")
const AdventureDeckSelectScreenScript = preload("res://src/ui/adventure/adventure_deck_select_screen.gd")
const AdventureSelectScreenScript = preload("res://src/ui/adventure/adventure_select_screen.gd")
const AdventureNodeMapScreenScript = preload("res://src/ui/adventure/adventure_node_map_screen.gd")
const AdventureResultScreenScript = preload("res://src/ui/adventure/adventure_result_screen.gd")
const HealerNodeOverlayScript = preload("res://src/ui/adventure/healer_node_overlay.gd")
const ReinforcementNodeOverlayScript = preload("res://src/ui/adventure/reinforcement_node_overlay.gd")
const ShopNodeOverlayScript = preload("res://src/ui/adventure/shop_node_overlay.gd")
const MatchScreenScript = preload("res://src/ui/match_screen.gd")

var _run_manager = null
var _current_adventure: Dictionary = {}
var _current_screen: Control = null
var _current_overlay: Control = null
var _selected_deck: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if AdventureRunManagerScript.has_active_run():
		_run_manager = AdventureRunManagerScript.load_run()
		_current_adventure = AdventureCatalogScript.load_adventure(_run_manager.adventure_id)
		match _run_manager.state:
			AdventureRunManagerScript.State.VIEWING_MAP:
				_show_node_map()
			AdventureRunManagerScript.State.IN_MATCH:
				_resume_match()
			_:
				_show_deck_select()
	else:
		_show_deck_select()


func _clear_screen() -> void:
	_dismiss_overlay()
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null


func _dismiss_overlay() -> void:
	if _current_overlay != null:
		_current_overlay.queue_free()
		_current_overlay = null


# --- Screen Navigation ---

func _show_deck_select() -> void:
	_clear_screen()
	var screen := AdventureDeckSelectScreenScript.new()
	screen.deck_selected.connect(_on_deck_selected)
	screen.back_pressed.connect(func() -> void: return_to_menu.emit())
	add_child(screen)
	_current_screen = screen


func _on_deck_selected(deck_data: Dictionary) -> void:
	_selected_deck = deck_data
	var deck_id: String = str(deck_data.get("deck_id", ""))
	var adventures := AdventureCatalogScript.get_adventures_for_deck(deck_id)
	if adventures.size() == 1:
		_on_adventure_selected(adventures[0])
	else:
		_show_adventure_select(adventures)


func _show_adventure_select(adventures: Array) -> void:
	_clear_screen()
	var screen := AdventureSelectScreenScript.new()
	screen.adventure_selected.connect(_on_adventure_selected)
	screen.back_pressed.connect(_show_deck_select)
	add_child(screen)
	_current_screen = screen
	screen.set_adventures(adventures)


func _on_adventure_selected(adventure: Dictionary) -> void:
	_current_adventure = adventure
	var adventure_id: String = str(adventure.get("id", ""))
	var deck_id: String = str(_selected_deck.get("deck_id", ""))
	var deck_cards: Array = _selected_deck.get("cards", [])
	var start_node_id: String = str(adventure.get("start_node", ""))

	_run_manager = AdventureRunManagerScript.new()
	_run_manager.start_run(adventure_id, deck_id, deck_cards, start_node_id)
	_show_node_map()


func _show_node_map() -> void:
	_clear_screen()
	var screen := AdventureNodeMapScreenScript.new()
	screen.node_selected.connect(_on_node_selected)
	screen.abandon_pressed.connect(_on_abandon_pressed)
	add_child(screen)
	_current_screen = screen
	screen.set_map_data(
		_current_adventure,
		_run_manager.current_node_id,
		_run_manager.completed_node_ids,
		_run_manager.revives_remaining,
		_run_manager.gold,
		_run_manager.max_health_bonus,
	)


# --- Node Interaction ---

func _on_node_selected(node_id: String) -> void:
	# If current_node_id is empty, this is a branch choice
	if _run_manager.current_node_id.is_empty():
		_run_manager.choose_next_node(node_id)

	var node: Dictionary = AdventureCatalogScript.get_node_by_id(_current_adventure, node_id)
	if node.is_empty():
		push_error("AdventureController: node '%s' not found" % node_id)
		return

	var node_type: String = str(node.get("type", ""))
	match node_type:
		"combat", "mini_boss", "final_boss":
			_start_combat(node_id, node)
		"healer":
			_show_healer_overlay(node_id, node)
		"reinforcement":
			_show_reinforcement_overlay(node_id)
		"shop":
			_show_shop_overlay(node_id)


# --- Combat ---

func _start_combat(node_id: String, node: Dictionary) -> void:
	_run_manager.start_match()

	var enemy_deck_id: String = str(node.get("enemy_deck", ""))
	var enemy_deck_data := AdventureDeckLoaderScript.load_enemy_deck(enemy_deck_id)
	if enemy_deck_data.is_empty():
		push_error("AdventureController: enemy deck '%s' not found" % enemy_deck_id)
		_run_manager.state = AdventureRunManagerScript.State.VIEWING_MAP
		_run_manager.save_run()
		return

	var quality: float = float(node.get("quality", 0.5))
	var enemy_health: int = int(node.get("enemy_health", 30))

	var player_deck_ids := AdventureDeckLoaderScript.deck_to_card_ids(_run_manager.get_full_deck_cards())
	var enemy_deck_ids := AdventureDeckLoaderScript.deck_to_card_ids(enemy_deck_data.get("cards", []))

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var match_seed: int = rng.randi()
	var first_player_index: int = rng.randi_range(0, 1)

	_run_manager.match_config = {
		"node_id": node_id,
		"enemy_deck_id": enemy_deck_id,
		"quality": quality,
		"enemy_health": enemy_health,
		"match_seed": match_seed,
		"first_player_index": first_player_index,
	}
	_run_manager.save_run()

	_launch_match(player_deck_ids, enemy_deck_ids, quality, enemy_health, match_seed, first_player_index)


func _launch_match(player_deck_ids: Array, enemy_deck_ids: Array, quality: float, enemy_health: int, match_seed: int, first_player_index: int) -> void:
	_clear_screen()
	var match_screen := MatchScreenScript.new()
	match_screen.name = "AdventureMatch"
	match_screen._arena_mode = true
	match_screen.return_to_main_menu_requested.connect(_on_match_ended.bind(match_screen))
	match_screen.forfeit_requested.connect(_on_match_forfeited)
	match_screen.match_state_changed.connect(_on_match_state_changed)
	add_child(match_screen)
	_current_screen = match_screen

	var ai_options := {"quality": quality, "ai_deck_ids": enemy_deck_ids}
	var boss_config := {}
	if enemy_health != 30:
		boss_config["boss_health"] = enemy_health
	var player_total_health: int = 30 + _run_manager.max_health_bonus
	if player_total_health != 30:
		boss_config["player_health"] = player_total_health

	if not boss_config.is_empty():
		match_screen.start_arena_boss_match(player_deck_ids, enemy_deck_ids, boss_config, match_seed, first_player_index, ai_options)
	else:
		match_screen.start_match_with_decks(player_deck_ids, enemy_deck_ids, match_seed, first_player_index, ai_options)


func _resume_match() -> void:
	if AdventureRunManagerScript.has_saved_match_state():
		var saved_state: Dictionary = AdventureRunManagerScript.load_match_state()
		if saved_state.is_empty():
			_run_manager.state = AdventureRunManagerScript.State.VIEWING_MAP
			_run_manager.match_config = null
			_run_manager.save_run()
			_show_node_map()
			return
		_clear_screen()
		var match_screen := MatchScreenScript.new()
		match_screen.name = "AdventureMatch"
		match_screen._arena_mode = true
		match_screen.return_to_main_menu_requested.connect(_on_match_ended.bind(match_screen))
		match_screen.forfeit_requested.connect(_on_match_forfeited)
		match_screen.match_state_changed.connect(_on_match_state_changed)
		add_child(match_screen)
		_current_screen = match_screen
		match_screen.resume_from_state(saved_state)
	else:
		_run_manager.state = AdventureRunManagerScript.State.VIEWING_MAP
		_run_manager.match_config = null
		_run_manager.save_run()
		_show_node_map()


func _on_match_state_changed(match_state: Dictionary) -> void:
	_run_manager.save_match_state(match_state)


func _on_match_forfeited() -> void:
	_run_manager.clear_match_state()
	_run_manager.match_config = null
	_run_manager.record_loss()
	_advance_after_match()


func _on_match_ended(match_screen: Control) -> void:
	_run_manager.clear_match_state()
	_run_manager.match_config = null
	var won: bool = match_screen.did_local_player_win()
	if won:
		_run_manager.record_win(_current_adventure)
	else:
		_run_manager.record_loss()
	_advance_after_match()


func _advance_after_match() -> void:
	if _run_manager.state == AdventureRunManagerScript.State.RUN_COMPLETE:
		_show_result()
	else:
		_show_node_map()


# --- Healer Node ---

func _show_healer_overlay(node_id: String, node: Dictionary) -> void:
	_dismiss_overlay()
	var overlay := HealerNodeOverlayScript.new()
	var headline: String = str(node.get("headline", "Shrine of Arkay"))
	overlay.set_data(headline, AdventureRunManagerScript.HEALER_HEALTH_BONUS)
	overlay.closed.connect(func() -> void:
		_run_manager.apply_healer_bonus()
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	add_child(overlay)
	_current_overlay = overlay


# --- Reinforcement Node ---

func _show_reinforcement_overlay(node_id: String) -> void:
	_dismiss_overlay()
	var cards := _get_or_generate_offerings(node_id, 3)

	var overlay := ReinforcementNodeOverlayScript.new()
	overlay.card_selected.connect(func(card_id: String) -> void:
		_run_manager.add_card(card_id)
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	overlay.skipped.connect(func() -> void:
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	add_child(overlay)
	_current_overlay = overlay
	overlay.set_cards(cards)


# --- Shop Node ---

func _show_shop_overlay(node_id: String) -> void:
	_dismiss_overlay()
	var cards := _get_or_generate_offerings(node_id, 6)
	var offering: Dictionary = _run_manager.get_node_offering(node_id)
	var purchased_ids: Array = offering.get("purchased_ids", [])

	var overlay := ShopNodeOverlayScript.new()
	overlay.card_purchased.connect(func(card_id: String, cost: int) -> void:
		if _run_manager.spend_gold(cost):
			_run_manager.add_card(card_id)
			_run_manager.mark_card_purchased(node_id, card_id)
			overlay.update_gold(_run_manager.gold)
	)
	overlay.closed.connect(func() -> void:
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	add_child(overlay)
	_current_overlay = overlay
	overlay.set_shop_data(cards, _run_manager.gold, purchased_ids)


# --- Result ---

func _show_result() -> void:
	_clear_screen()
	var screen := AdventureResultScreenScript.new()
	screen.return_pressed.connect(_on_result_return)
	add_child(screen)
	_current_screen = screen
	screen.set_result(_run_manager.run_won, str(_current_adventure.get("name", "Adventure")))


func _on_result_return() -> void:
	_run_manager = null
	return_to_menu.emit()


func _on_abandon_pressed() -> void:
	_run_manager.abandon_run()
	_run_manager = null
	return_to_menu.emit()


# --- Helpers ---

func _get_deck_attribute_ids() -> Array:
	var deck_data := AdventureDeckLoaderScript.load_player_deck(_run_manager.deck_id)
	return deck_data.get("attribute_ids", [])


func _get_or_generate_offerings(node_id: String, count: int) -> Array:
	var existing: Dictionary = _run_manager.get_node_offering(node_id)
	if not existing.is_empty():
		return existing.get("cards", [])
	var attribute_ids: Array = _get_deck_attribute_ids()
	var cards := AdventureCardPoolScript.get_random_cards(attribute_ids, count)
	_run_manager.save_node_offering(node_id, cards)
	return cards
