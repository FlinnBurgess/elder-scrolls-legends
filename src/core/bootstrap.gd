extends Node

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const DeckPersistence = preload("res://src/deck/deck_persistence.gd")
const DeckValidator = preload("res://src/deck/deck_validator.gd")
const MatchScreen = preload("res://src/ui/match_screen.gd")
const DeckbuilderScreen = preload("res://src/ui/deckbuilder_screen.gd")
const ArenaControllerScript = preload("res://src/ui/arena/arena_controller.gd")
const AdventureControllerScript = preload("res://src/ui/adventure/adventure_controller.gd")
const TestMatchConfig = preload("res://data/test_match_config.gd")

const DECKS_DIR := "res://data/decks/"

var _main_menu: Control
var _active_screen: Control
var _pause_overlay: Control
var _deck_select_screen: Control
var _deck_select_buttons: Array = []
var _deck_entries: Array = []
var _selected_deck_index := -1
var _start_match_button: Button
var _match_button: Button
var _test_match_picker: Control


func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print("Bootstrap scene ready (headless).")
		return
	_show_main_menu()


func _show_main_menu() -> void:
	if _active_screen != null:
		_active_screen.queue_free()
		_active_screen = null
	if _deck_select_screen != null:
		_deck_select_screen.queue_free()
		_deck_select_screen = null

	if _main_menu != null:
		_main_menu.visible = true
		return

	_main_menu = Control.new()
	_main_menu.name = "MainMenu"
	_main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_main_menu)

	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(320, 0)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
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

	_match_button = Button.new()
	_match_button.text = "Match"
	_match_button.custom_minimum_size = Vector2(320, 52)
	_match_button.pressed.connect(_on_match_pressed)
	center.add_child(_match_button)

	var adventure_button := Button.new()
	adventure_button.text = "Adventure"
	adventure_button.custom_minimum_size = Vector2(320, 52)
	adventure_button.pressed.connect(_on_adventure_pressed)
	center.add_child(adventure_button)

	var arena_button := Button.new()
	arena_button.text = "Arena"
	arena_button.custom_minimum_size = Vector2(320, 52)
	arena_button.pressed.connect(_on_arena_pressed)
	center.add_child(arena_button)

	var deckbuilder_button := Button.new()
	deckbuilder_button.text = "Deck Builder"
	deckbuilder_button.custom_minimum_size = Vector2(320, 52)
	deckbuilder_button.pressed.connect(_on_deckbuilder_pressed)
	center.add_child(deckbuilder_button)


func _on_match_pressed() -> void:
	_main_menu.visible = false
	_show_deck_select_screen()


func _on_adventure_pressed() -> void:
	_main_menu.visible = false
	var adventure_controller := AdventureControllerScript.new()
	adventure_controller.name = "AdventureController"
	adventure_controller.return_to_menu.connect(_show_main_menu)
	add_child(adventure_controller)
	_active_screen = adventure_controller


func _on_arena_pressed() -> void:
	_main_menu.visible = false
	var arena_controller := ArenaControllerScript.new()
	arena_controller.name = "ArenaController"
	arena_controller.return_to_menu.connect(_show_main_menu)
	add_child(arena_controller)
	_active_screen = arena_controller


func _show_deck_select_screen() -> void:
	var player_entries := _load_valid_player_deck_entries()
	var default_entries := _load_deck_entries()
	_deck_entries = player_entries + default_entries
	if _deck_entries.is_empty():
		push_error("No deck files found in %s" % DECKS_DIR)
		_main_menu.visible = true
		return

	_selected_deck_index = -1
	_deck_select_buttons.clear()

	_deck_select_screen = Control.new()
	_deck_select_screen.name = "DeckSelect"
	_deck_select_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_deck_select_screen)

	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(400, 0)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 12)
	_deck_select_screen.add_child(center)

	var title := Label.new()
	title.text = "Choose Your Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	center.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	if not player_entries.is_empty():
		var my_decks_label := Label.new()
		my_decks_label.text = "My Decks"
		my_decks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		my_decks_label.add_theme_font_size_override("font_size", 16)
		my_decks_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		center.add_child(my_decks_label)

	for i in range(_deck_entries.size()):
		if i == player_entries.size() and not player_entries.is_empty():
			var defaults_spacer := Control.new()
			defaults_spacer.custom_minimum_size = Vector2(0, 4)
			center.add_child(defaults_spacer)
			var defaults_label := Label.new()
			defaults_label.text = "Default Decks"
			defaults_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			defaults_label.add_theme_font_size_override("font_size", 16)
			defaults_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
			center.add_child(defaults_label)

		var entry: Dictionary = _deck_entries[i]
		var deck_button := Button.new()
		var attributes_text := ", ".join(entry.get("attribute_ids", []))
		var card_count := int(entry.get("card_count", 0))
		deck_button.text = "%s  (%s | %d cards)" % [str(entry.get("name", "Unknown")), attributes_text, card_count]
		deck_button.custom_minimum_size = Vector2(400, 48)
		deck_button.pressed.connect(_on_deck_selected.bind(i))
		center.add_child(deck_button)
		_deck_select_buttons.append(deck_button)

	var button_spacer := Control.new()
	button_spacer.custom_minimum_size = Vector2(0, 12)
	center.add_child(button_spacer)

	_start_match_button = Button.new()
	_start_match_button.text = "Start Match"
	_start_match_button.custom_minimum_size = Vector2(400, 52)
	_start_match_button.disabled = true
	_start_match_button.pressed.connect(_on_start_match_pressed)
	center.add_child(_start_match_button)

	var random_decks_button := Button.new()
	random_decks_button.text = "Random Decks"
	random_decks_button.custom_minimum_size = Vector2(400, 48)
	random_decks_button.pressed.connect(_on_random_decks_pressed)
	center.add_child(random_decks_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(400, 44)
	back_button.pressed.connect(_on_deck_select_back_pressed)
	center.add_child(back_button)


func _on_deck_selected(index: int) -> void:
	_selected_deck_index = index
	_start_match_button.disabled = false
	for i in range(_deck_select_buttons.size()):
		var btn: Button = _deck_select_buttons[i]
		if i == index:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.65, 1.0)
			style.border_color = Color(0.4, 0.65, 0.9, 1.0)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", style)
		else:
			btn.remove_theme_stylebox_override("normal")


func _on_start_match_pressed() -> void:
	if _selected_deck_index < 0 or _selected_deck_index >= _deck_entries.size():
		return
	var selected_entry: Dictionary = _deck_entries[_selected_deck_index]
	var player_deck_ids: Array
	if selected_entry.has("card_ids"):
		player_deck_ids = selected_entry.get("card_ids", [])
	else:
		player_deck_ids = _load_deck_card_ids(selected_entry.get("path", ""))
	if player_deck_ids.is_empty():
		return

	var enemy_deck_ids := _pick_random_enemy_deck(selected_entry.get("path", ""))
	if enemy_deck_ids.is_empty():
		return

	_deck_select_screen.queue_free()
	_deck_select_screen = null

	var match_screen := MatchScreen.new()
	match_screen.name = "Match"
	match_screen.return_to_main_menu_requested.connect(_show_main_menu)
	add_child(match_screen)
	_active_screen = match_screen
	match_screen.start_match_with_decks(player_deck_ids, enemy_deck_ids)


func _on_random_decks_pressed() -> void:
	var catalog := CardCatalog.load_default()
	var all_cards: Array = catalog.get("cards", [])
	if all_cards.size() < 50:
		return

	var shuffled_p1 := all_cards.duplicate()
	shuffled_p1.shuffle()
	var player_deck_ids: Array = []
	for i in range(50):
		player_deck_ids.append(str(shuffled_p1[i].get("card_id", "")))

	var shuffled_p2 := all_cards.duplicate()
	shuffled_p2.shuffle()
	var enemy_deck_ids: Array = []
	for i in range(50):
		enemy_deck_ids.append(str(shuffled_p2[i].get("card_id", "")))

	_deck_select_screen.queue_free()
	_deck_select_screen = null

	var match_screen := MatchScreen.new()
	match_screen.name = "Match"
	match_screen.return_to_main_menu_requested.connect(_show_main_menu)
	add_child(match_screen)
	_active_screen = match_screen
	match_screen.start_match_with_decks(player_deck_ids, enemy_deck_ids)


func _on_deck_select_back_pressed() -> void:
	if _deck_select_screen != null:
		_deck_select_screen.queue_free()
		_deck_select_screen = null
	_main_menu.visible = true


func _pick_random_enemy_deck(exclude_path: String) -> Array:
	var deck_files := _list_deck_files()
	var candidates: Array = []
	for path in deck_files:
		if path != exclude_path:
			candidates.append(path)
	if candidates.is_empty():
		candidates = deck_files
	candidates.shuffle()
	return _load_deck_card_ids(candidates[0])


func _load_valid_player_deck_entries() -> Array:
	var catalog_data := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_data.get("card_by_id", {})
	if card_by_id.is_empty():
		push_warning("Deck select: card catalog is empty, skipping player decks")
		return []

	var entries: Array = []
	var deck_names := DeckPersistence.list_decks()
	for deck_name in deck_names:
		var definition := DeckPersistence.load_deck(deck_name)
		if definition.is_empty():
			push_warning("Deck select: failed to load player deck '%s'" % deck_name)
			continue
		var validation := DeckValidator.validate_deck(definition, card_by_id)
		if not validation.get("is_valid", false):
			push_warning("Deck select: player deck '%s' failed validation: %s" % [deck_name, str(validation.get("errors", []))])
			continue
		var card_ids: Array = []
		for card_entry in definition.get("cards", []):
			if typeof(card_entry) == TYPE_DICTIONARY:
				var card_id := str(card_entry.get("card_id", ""))
				var quantity := int(card_entry.get("quantity", 0))
				for _i in range(quantity):
					card_ids.append(card_id)
		entries.append({
			"name": str(definition.get("name", deck_name)),
			"attribute_ids": definition.get("attribute_ids", []),
			"card_count": card_ids.size(),
			"card_ids": card_ids,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return entries


func _load_deck_entries() -> Array:
	var entries: Array = []
	var deck_files := _list_deck_files()
	for path in deck_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var json := JSON.new()
		if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
			continue
		var deck: Dictionary = json.data
		var card_count := 0
		for card_entry in deck.get("cards", []):
			if typeof(card_entry) == TYPE_DICTIONARY:
				card_count += int(card_entry.get("quantity", 0))
		entries.append({
			"path": path,
			"name": str(deck.get("name", path.get_file())),
			"attribute_ids": deck.get("attribute_ids", []),
			"card_count": card_count,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return entries


func _show_test_match_picker() -> void:
	if _test_match_picker != null:
		_test_match_picker.queue_free()
		_test_match_picker = null

	var configs := TestMatchConfig.list_configs()

	_main_menu.visible = false

	_test_match_picker = Control.new()
	_test_match_picker.name = "TestMatchPicker"
	_test_match_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_test_match_picker.z_index = 100
	add_child(_test_match_picker)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	_test_match_picker.add_child(bg)

	# Centre the panel using anchors — anchor to centre, then offset by half-size
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -250
	panel.offset_bottom = 250
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_test_match_picker.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(outer_vbox)

	var title := Label.new()
	title.text = "Test Match Configs"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	outer_vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	outer_vbox.add_child(spacer)

	if configs.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No test matches configured"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer_vbox.add_child(empty_label)
	else:
		# Scrollable list of configs
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 100)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		outer_vbox.add_child(scroll)

		var list_vbox := VBoxContainer.new()
		list_vbox.add_theme_constant_override("separation", 8)
		list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list_vbox)

		for config_entry in configs:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			list_vbox.add_child(row)

			var launch_btn := Button.new()
			var btn_text := str(config_entry.get("name", ""))
			var desc := str(config_entry.get("description", ""))
			if not desc.is_empty():
				btn_text += "  —  " + desc
			launch_btn.text = btn_text
			launch_btn.custom_minimum_size = Vector2(400, 44)
			launch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			launch_btn.clip_text = true
			var filename: String = config_entry.get("filename", "")
			launch_btn.pressed.connect(_on_test_match_selected.bind(filename))
			row.add_child(launch_btn)

			var delete_btn := Button.new()
			delete_btn.text = "X"
			delete_btn.custom_minimum_size = Vector2(36, 44)
			delete_btn.tooltip_text = "Delete this config"
			delete_btn.pressed.connect(_on_test_match_delete.bind(filename))
			row.add_child(delete_btn)

	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	outer_vbox.add_child(bottom_spacer)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 44)
	back_btn.pressed.connect(_on_test_match_picker_back)
	outer_vbox.add_child(back_btn)


func _on_test_match_selected(filename: String) -> void:
	if _test_match_picker != null:
		_test_match_picker.queue_free()
		_test_match_picker = null

	var test_state := TestMatchConfig.build_test_match_state_from_file(filename)
	if test_state.is_empty():
		push_error("TestMatchConfig returned an empty match state for '%s'" % filename)
		_main_menu.visible = true
		return
	var match_screen := MatchScreen.new()
	match_screen.name = "Match"
	match_screen.return_to_main_menu_requested.connect(_show_main_menu)
	add_child(match_screen)
	_active_screen = match_screen
	match_screen.start_test_match(test_state)


func _on_test_match_delete(filename: String) -> void:
	TestMatchConfig.delete_config(filename)
	# Re-open the picker to refresh the list
	_show_test_match_picker()


func _on_test_match_picker_back() -> void:
	if _test_match_picker != null:
		_test_match_picker.queue_free()
		_test_match_picker = null
	_main_menu.visible = true


func _on_deckbuilder_pressed() -> void:
	_main_menu.visible = false
	var deckbuilder_screen := DeckbuilderScreen.new()
	deckbuilder_screen.name = "Deckbuilder"
	deckbuilder_screen.back_to_menu_requested.connect(_show_main_menu)
	add_child(deckbuilder_screen)
	_active_screen = deckbuilder_screen


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _main_menu != null and _main_menu.visible and event.unicode == 63:
			if _match_button != null and _match_button.is_hovered():
				get_viewport().set_input_as_handled()
				_show_test_match_picker()
				return
	if _active_screen == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _pause_overlay != null:
			_dismiss_pause_menu()
		else:
			_show_pause_menu()


func _show_pause_menu() -> void:
	if _pause_overlay != null:
		return

	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.z_index = 500
	add_child(_pause_overlay)

	# Semi-transparent background that blocks clicks
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_pause_overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 0)
	_pause_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size = Vector2(0, 44)
	resume_button.pressed.connect(_dismiss_pause_menu)
	vbox.add_child(resume_button)

	var main_menu_button := Button.new()
	main_menu_button.text = "Return to Main Menu"
	main_menu_button.custom_minimum_size = Vector2(0, 44)
	main_menu_button.pressed.connect(_on_pause_main_menu_pressed)
	vbox.add_child(main_menu_button)


func _dismiss_pause_menu() -> void:
	if _pause_overlay != null:
		_pause_overlay.queue_free()
		_pause_overlay = null


func _on_pause_main_menu_pressed() -> void:
	_dismiss_pause_menu()
	_show_main_menu()



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
