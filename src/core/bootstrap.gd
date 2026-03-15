extends Node

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const MatchScreen = preload("res://src/ui/match_screen.gd")
const DeckbuilderScreen = preload("res://src/ui/deckbuilder_screen.gd")

const DECKS_DIR := "res://data/decks/"

var _main_menu: Control
var _active_screen: Control


func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print("Bootstrap scene ready (headless).")
		return
	_show_main_menu()


func _show_main_menu() -> void:
	if _active_screen != null:
		_active_screen.queue_free()
		_active_screen = null

	if _main_menu != null:
		_main_menu.visible = true
		return

	_main_menu = Control.new()
	_main_menu.name = "MainMenu"
	_main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_main_menu)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(320, 0)
	center.add_theme_constant_override("separation", 16)
	_main_menu.add_child(center)

	var title := Label.new()
	title.text = "The Elder Scrolls: Legends"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	center.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	center.add_child(spacer)

	var match_button := Button.new()
	match_button.text = "Match"
	match_button.custom_minimum_size = Vector2(320, 52)
	match_button.pressed.connect(_on_match_pressed)
	center.add_child(match_button)

	var deckbuilder_button := Button.new()
	deckbuilder_button.text = "Deck Builder"
	deckbuilder_button.custom_minimum_size = Vector2(320, 52)
	deckbuilder_button.pressed.connect(_on_deckbuilder_pressed)
	center.add_child(deckbuilder_button)


func _on_match_pressed() -> void:
	var decks := _load_random_decks()
	if decks.is_empty():
		return
	_main_menu.visible = false
	var match_screen := MatchScreen.new()
	match_screen.name = "Match"
	add_child(match_screen)
	_active_screen = match_screen
	match_screen.start_match_with_decks(decks[0], decks[1])


func _on_deckbuilder_pressed() -> void:
	_main_menu.visible = false
	var deckbuilder_screen := DeckbuilderScreen.new()
	deckbuilder_screen.name = "Deckbuilder"
	add_child(deckbuilder_screen)
	_active_screen = deckbuilder_screen


func _unhandled_input(event: InputEvent) -> void:
	if _active_screen == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_show_main_menu()


func _load_random_decks() -> Array:
	var deck_files := _list_deck_files()
	if deck_files.size() < 2:
		push_error("Need at least 2 deck files in %s" % DECKS_DIR)
		return []
	deck_files.shuffle()
	var deck_one := _load_deck_card_ids(deck_files[0])
	var deck_two := _load_deck_card_ids(deck_files[1])
	if deck_one.is_empty() or deck_two.is_empty():
		return []
	return [deck_one, deck_two]


func _list_deck_files() -> Array:
	var files: Array = []
	var dir := DirAccess.open(DECKS_DIR)
	if dir == null:
		push_error("Cannot open deck directory: %s" % DECKS_DIR)
		return []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			files.append(DECKS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files


func _load_deck_card_ids(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open deck file: %s" % path)
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("Invalid deck JSON in: %s" % path)
		return []
	var deck: Dictionary = json.data
	var card_ids: Array = []
	for entry in deck.get("cards", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var card_id := str(entry.get("card_id", ""))
		var quantity := int(entry.get("quantity", 0))
		for _i in range(quantity):
			card_ids.append(card_id)
	return card_ids
