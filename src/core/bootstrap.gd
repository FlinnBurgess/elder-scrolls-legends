extends Node

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const DeckPersistence = preload("res://src/deck/deck_persistence.gd")
const DeckValidator = preload("res://src/deck/deck_validator.gd")
const MatchScreen = preload("res://src/ui/match_screen.gd")
const DeckbuilderScreen = preload("res://src/ui/deckbuilder_screen.gd")
const ArenaControllerScript = preload("res://src/ui/arena/arena_controller.gd")
const AdventureControllerScript = preload("res://src/ui/adventure/adventure_controller.gd")
const TestMatchConfig = preload("res://data/test_match_config.gd")
const PuzzleSelectScreenScript = preload("res://src/ui/puzzle/puzzle_select_screen.gd")
const PuzzleConfigScript = preload("res://src/puzzle/puzzle_config.gd")
const PuzzleCodecScript = preload("res://src/puzzle/puzzle_codec.gd")
const PuzzlePersistenceScript = preload("res://src/puzzle/puzzle_persistence.gd")
const AIPlayProfile = preload("res://src/ai/ai_play_profile.gd")
const PuzzleBuilderScreenScript = preload("res://src/ui/puzzle/puzzle_builder_screen.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")
const DeckCardListClass = preload("res://src/ui/components/deck_card_list.gd")
const SettingsScreenScript = preload("res://src/ui/settings_screen.gd")
const AvatarCarouselScreenScript = preload("res://src/ui/avatar_carousel_screen.gd")
const PlayerSettings = preload("res://src/core/player_settings.gd")

const DECKS_DIR := "res://data/decks/"

var _main_menu: Control
var _active_screen: Control
var _pause_overlay: Control
var _deck_select_screen: Control
var _deck_select_buttons: Array = []
var _deck_entries: Array = []
var _deck_ai_pool_enabled: Dictionary = {}
var _selected_deck_index := -1
var _start_match_button: Button
var _deck_select_card_list: DeckCardList
var _deck_select_card_lookup: Dictionary = {}
var _deck_select_hover_layer: Control
var _match_button: Button
var _test_match_picker: Control
var _current_test_match_filename := ""
var _puzzle_screen: Control
var _current_puzzle_entry: Dictionary = {}
var _current_puzzle_config: Dictionary = {}
var _settings_screen: Control
var _avatar_carousel_screen: Control


func _ready() -> void:
	var window_size := DisplayServer.window_get_size()
	print("Window resolution: %dx%d" % [window_size.x, window_size.y])
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
	if _avatar_carousel_screen != null:
		if is_instance_valid(_avatar_carousel_screen):
			_avatar_carousel_screen.queue_free()
		_avatar_carousel_screen = null
	if _settings_screen != null:
		if is_instance_valid(_settings_screen):
			_settings_screen.queue_free()
		_settings_screen = null
	_deck_select_card_list = null
	_deck_select_hover_layer = null

	if _main_menu != null:
		_main_menu.visible = true
		return

	_main_menu = Control.new()
	_main_menu.name = "MainMenu"
	_main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_main_menu)

	UITheme.add_background(_main_menu)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 12)
	_main_menu.add_child(center)

	center.add_child(UITheme.make_separator())

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 12)
	center.add_child(spacer_top)

	var title := Label.new()
	title.text = "The Elder Scrolls"
	UITheme.style_title(title, 56)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "L E G E N D S"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_section_label(subtitle, 30)
	center.add_child(subtitle)

	center.add_child(UITheme.make_separator())

	var spacer_mid := Control.new()
	spacer_mid.custom_minimum_size = Vector2(0, 40)
	center.add_child(spacer_mid)

	var buttons_data := [
		["Match", _on_match_pressed],
		["Adventure", _on_adventure_pressed],
		["Arena", _on_arena_pressed],
		["Puzzles", _on_puzzles_pressed],
		["Test Match Creator", _on_test_match_creator_pressed],
		["Deck Builder", _on_deckbuilder_pressed],
		["Settings", _on_settings_pressed],
	]
	for entry in buttons_data:
		var btn := Button.new()
		btn.text = entry[0]
		btn.custom_minimum_size = Vector2(480, 72)
		btn.pressed.connect(entry[1])
		UITheme.style_button(btn, 28)
		center.add_child(btn)
		if entry[0] == "Match":
			_match_button = btn
			btn.gui_input.connect(_on_match_button_gui_input)

	var spacer_quit := Control.new()
	spacer_quit.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer_quit)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(480, 72)
	quit_button.pressed.connect(get_tree().quit)
	UITheme.style_button(quit_button, 28, true)
	center.add_child(quit_button)


func _on_match_pressed() -> void:
	GameLogger.trc("App", "screen", "to:deck_select")
	_main_menu.visible = false
	_show_deck_select_screen()


func _on_adventure_pressed() -> void:
	GameLogger.trc("App", "screen", "to:adventure")
	_main_menu.visible = false
	var adventure_controller := AdventureControllerScript.new()
	adventure_controller.name = "AdventureController"
	adventure_controller.return_to_menu.connect(_show_main_menu)
	add_child(adventure_controller)
	_active_screen = adventure_controller


func _on_arena_pressed() -> void:
	GameLogger.trc("App", "screen", "to:arena")
	_main_menu.visible = false
	var arena_controller := ArenaControllerScript.new()
	arena_controller.name = "ArenaController"
	arena_controller.return_to_menu.connect(_show_main_menu)
	add_child(arena_controller)
	_active_screen = arena_controller


func _on_puzzles_pressed() -> void:
	GameLogger.trc("App", "screen", "to:puzzles")
	_main_menu.visible = false
	_puzzle_screen = PuzzleSelectScreenScript.new()
	_puzzle_screen.name = "PuzzleSelectScreen"
	_puzzle_screen.puzzle_selected.connect(_on_puzzle_selected)
	_puzzle_screen.builder_requested.connect(_on_puzzle_builder_requested)
	_puzzle_screen.edit_requested.connect(_on_puzzle_edit_requested)
	_puzzle_screen.back_requested.connect(_on_puzzle_back)
	add_child(_puzzle_screen)
	_active_screen = _puzzle_screen


func _on_puzzle_selected(entry: Dictionary) -> void:
	var code := str(entry.get("code", ""))
	var result: Dictionary = PuzzleCodecScript.decode(code)
	if not str(result.get("error", "")).is_empty():
		push_error("Failed to decode puzzle: %s" % result.get("error"))
		return
	_current_puzzle_entry = entry
	_current_puzzle_config = result.get("config", {})
	_start_puzzle_match()


func _start_puzzle_match() -> void:
	var puzzle_state := PuzzleConfigScript.build_puzzle_match_state(_current_puzzle_config)
	var puzzle_type := str(_current_puzzle_config.get("type", "kill"))
	var ai_options := {}
	if puzzle_type == "survive":
		ai_options = AIPlayProfile.build_survive_puzzle_options()

	if _puzzle_screen != null:
		_puzzle_screen.visible = false

	var match_screen := MatchScreen.new()
	match_screen.name = "PuzzleMatch"
	match_screen.puzzle_retry_requested.connect(_on_puzzle_retry.bind(match_screen))
	match_screen.puzzle_return_to_select_requested.connect(_on_puzzle_return_to_select.bind(match_screen))
	match_screen.puzzle_next_requested.connect(_on_puzzle_next.bind(match_screen))
	match_screen.return_to_main_menu_requested.connect(_on_puzzle_return_to_select.bind(match_screen))
	add_child(match_screen)
	_active_screen = match_screen
	match_screen.start_puzzle_match(puzzle_state, _current_puzzle_config,
		str(_current_puzzle_entry.get("id", "")), ai_options, _current_puzzle_has_next())


func _current_puzzle_has_next() -> bool:
	var pack_puzzles: Array = _current_puzzle_entry.get("pack_puzzles", [])
	var pack_index := int(_current_puzzle_entry.get("pack_index", -1))
	return pack_index >= 0 and pack_index + 1 < pack_puzzles.size()


func _on_puzzle_retry(match_screen: Control) -> void:
	match_screen.queue_free()
	_start_puzzle_match()


func _on_puzzle_next(match_screen: Control) -> void:
	if not _current_puzzle_has_next():
		_on_puzzle_return_to_select(match_screen)
		return
	var pack_path := str(_current_puzzle_entry.get("pack_path", ""))
	var pack_puzzles: Array = _current_puzzle_entry.get("pack_puzzles", [])
	var pack_index := int(_current_puzzle_entry.get("pack_index", -1))
	var next_index := pack_index + 1
	var next_meta: Dictionary = pack_puzzles[next_index]
	var puzzle_file := str(next_meta.get("file", ""))
	if pack_path.is_empty() or puzzle_file.is_empty():
		_on_puzzle_return_to_select(match_screen)
		return
	var file_handle := FileAccess.open(pack_path.path_join(puzzle_file), FileAccess.READ)
	if file_handle == null:
		_on_puzzle_return_to_select(match_screen)
		return
	var config = JSON.parse_string(file_handle.get_as_text())
	if typeof(config) != TYPE_DICTIONARY:
		_on_puzzle_return_to_select(match_screen)
		return
	match_screen.queue_free()
	_current_puzzle_entry = {
		"id": str(next_meta.get("id", "")),
		"name": str(next_meta.get("name", "Untitled")),
		"pack_path": pack_path,
		"pack_puzzles": pack_puzzles,
		"pack_index": next_index,
	}
	_current_puzzle_config = config
	_start_puzzle_match()


func _on_puzzle_return_to_select(match_screen: Control) -> void:
	match_screen.queue_free()
	# Mark solved if player won
	var puzzle_id := str(_current_puzzle_entry.get("id", ""))
	if not puzzle_id.is_empty():
		# Check the match state for a win — the match_screen is being freed
		# so we rely on the puzzle_id tracking; completion is marked in _complete_end_turn
		pass
	if _puzzle_screen != null:
		_puzzle_screen.visible = true
		_active_screen = _puzzle_screen
		# Refresh the list in case completion status changed
		if _puzzle_screen.has_method("refresh"):
			_puzzle_screen.refresh()
	else:
		_show_main_menu()


func _on_puzzle_back() -> void:
	if _puzzle_screen != null:
		_puzzle_screen.queue_free()
		_puzzle_screen = null
	_show_main_menu()


func _on_test_match_creator_pressed() -> void:
	GameLogger.trc("App", "screen", "to:test_match_creator")
	_main_menu.visible = false
	var builder := PuzzleBuilderScreenScript.new()
	builder.builder_mode = "test_match"
	builder.name = "TestMatchCreator"
	builder.back_requested.connect(func():
		builder.queue_free()
		_show_main_menu()
	)
	builder.play_requested.connect(_on_builder_play.bind(builder))
	add_child(builder)
	_active_screen = builder


func _on_puzzle_builder_requested() -> void:
	_open_puzzle_builder()


func _on_puzzle_edit_requested(config: Dictionary) -> void:
	_open_puzzle_builder(config)


func _open_puzzle_builder(config: Dictionary = {}) -> void:
	if _puzzle_screen != null:
		_puzzle_screen.visible = false
	var builder := PuzzleBuilderScreenScript.new()
	builder.name = "PuzzleBuilder"
	builder.back_requested.connect(_on_builder_back.bind(builder))
	builder.play_requested.connect(_on_builder_play.bind(builder))
	add_child(builder)
	if not config.is_empty():
		builder.load_config(config)
	_active_screen = builder


func _on_builder_back(builder: Control) -> void:
	builder.queue_free()
	if _puzzle_screen != null:
		_puzzle_screen.refresh()
		_puzzle_screen.visible = true
		_active_screen = _puzzle_screen
	else:
		_show_main_menu()


func _on_builder_play(config: Dictionary, builder: Control) -> void:
	builder.visible = false

	if builder.builder_mode == "test_match":
		_on_builder_play_test_match(config, builder)
		return

	_current_puzzle_config = config
	_current_puzzle_entry = {}
	var puzzle_state := PuzzleConfigScript.build_puzzle_match_state(config)
	var puzzle_type := str(config.get("type", "kill"))
	var ai_options := {}
	if puzzle_type == "survive":
		ai_options = AIPlayProfile.build_survive_puzzle_options()

	var match_screen := MatchScreen.new()
	match_screen.name = "PuzzleBuilderTest"
	match_screen.puzzle_retry_requested.connect(func():
		match_screen.queue_free()
		_on_builder_play(config, builder)
	)
	match_screen.puzzle_return_to_select_requested.connect(func():
		match_screen.queue_free()
		builder.visible = true
		_active_screen = builder
	)
	match_screen.return_to_main_menu_requested.connect(func():
		match_screen.queue_free()
		builder.visible = true
		_active_screen = builder
	)
	add_child(match_screen)
	_active_screen = match_screen
	match_screen.start_puzzle_match(puzzle_state, config, "", ai_options)


func _on_builder_play_test_match(config: Dictionary, builder: Control) -> void:
	var test_state := PuzzleConfigScript.build_test_match_state(config)
	var match_screen := MatchScreen.new()
	match_screen.name = "TestMatchCreatorMatch"
	match_screen.test_match_restart_requested.connect(func():
		match_screen.queue_free()
		_on_builder_play_test_match(config, builder)
	)
	match_screen.return_to_main_menu_requested.connect(func():
		match_screen.queue_free()
		builder.visible = true
		_active_screen = builder
	)
	add_child(match_screen)
	_active_screen = match_screen
	match_screen.start_test_match(test_state)


func _show_deck_select_screen() -> void:
	var player_entries := _load_valid_player_deck_entries()
	var default_entries := _load_deck_entries()
	_deck_entries = player_entries + default_entries
	if _deck_entries.is_empty():
		push_error("No deck files found in %s" % DECKS_DIR)
		_main_menu.visible = true
		return

	# Seed the AI-pool toggle state from persisted player settings.
	var disabled_ids := PlayerSettings.get_ai_pool_disabled_ids()
	_deck_ai_pool_enabled.clear()
	for entry in _deck_entries:
		var id := _deck_entry_id(entry)
		_deck_ai_pool_enabled[id] = not disabled_ids.has(id)

	_selected_deck_index = -1
	_deck_select_buttons.clear()

	_deck_select_screen = Control.new()
	_deck_select_screen.name = "DeckSelect"
	_deck_select_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_deck_select_screen)

	UITheme.add_background(_deck_select_screen)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	_deck_select_screen.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(120, 56)
	UITheme.style_button(back_button, 22, true)
	back_button.pressed.connect(_on_deck_select_back_pressed)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Choose Your Deck"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_title(title, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	root.add_child(UITheme.make_separator(0.0))

	_load_deck_select_card_lookup()

	var content_row := HBoxContainer.new()
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 24)
	root.add_child(content_row)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.add_child(left_spacer)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(720, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	content_row.add_child(list)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 192)
	content_row.add_child(right_margin)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_col)

	var cards_title := Label.new()
	cards_title.text = "Deck Contents"
	UITheme.style_section_label(cards_title, 20)
	right_col.add_child(cards_title)

	right_col.add_child(UITheme.make_separator(0.0))

	_deck_select_card_list = DeckCardListClass.new()
	var card_list_scroll := _deck_select_card_list.create_scroll_container()
	right_col.add_child(card_list_scroll)

	_deck_select_hover_layer = Control.new()
	_deck_select_hover_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_select_hover_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_select_screen.add_child(_deck_select_hover_layer)
	_deck_select_card_list.enable_hover_preview(_deck_select_hover_layer, _deck_select_card_lookup)

	# "AI" header sits above the AI-pool checkbox column on every deck row.
	var ai_header_row := HBoxContainer.new()
	ai_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_header_row.add_theme_constant_override("separation", 12)
	list.add_child(ai_header_row)

	var ai_header_label := Label.new()
	ai_header_label.text = "AI"
	ai_header_label.custom_minimum_size = Vector2(48, 0)
	ai_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_header_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	UITheme.style_section_label(ai_header_label, 26)
	ai_header_row.add_child(ai_header_label)

	var ai_header_spacer := Control.new()
	ai_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_header_row.add_child(ai_header_spacer)

	# Decks live in their own inner VBox so the gap below the AI header stays tight
	# while deck rows keep their normal vertical rhythm.
	var decks_inner := VBoxContainer.new()
	decks_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decks_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	decks_inner.add_theme_constant_override("separation", 10)
	list.add_child(decks_inner)

	if not player_entries.is_empty():
		var my_decks_label := Label.new()
		my_decks_label.text = "My Decks"
		my_decks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_section_label(my_decks_label, 24)
		decks_inner.add_child(my_decks_label)

	var defaults_container: VBoxContainer = null
	var defaults_scroll: ScrollContainer = null
	var defaults_toggle_button: Button = null
	var defaults_start_index := player_entries.size()
	var default_count := default_entries.size()
	var start_collapsed := not player_entries.is_empty()

	for i in range(_deck_entries.size()):
		if i == defaults_start_index and not default_entries.is_empty():
			if not player_entries.is_empty():
				var defaults_spacer := Control.new()
				defaults_spacer.custom_minimum_size = Vector2(0, 12)
				decks_inner.add_child(defaults_spacer)
			defaults_toggle_button = Button.new()
			defaults_toggle_button.flat = true
			defaults_toggle_button.focus_mode = Control.FOCUS_NONE
			defaults_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			defaults_toggle_button.add_theme_font_size_override("font_size", 24)
			defaults_toggle_button.add_theme_color_override("font_color", UITheme.TEXT_SECTION)
			defaults_toggle_button.add_theme_color_override("font_hover_color", UITheme.GOLD)
			defaults_toggle_button.add_theme_color_override("font_pressed_color", UITheme.GOLD_BRIGHT)
			decks_inner.add_child(defaults_toggle_button)

			defaults_scroll = ScrollContainer.new()
			defaults_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			defaults_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			defaults_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			defaults_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
			defaults_scroll.visible = not start_collapsed
			decks_inner.add_child(defaults_scroll)

			defaults_container = VBoxContainer.new()
			defaults_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			defaults_container.add_theme_constant_override("separation", 10)
			defaults_scroll.add_child(defaults_container)

			_update_defaults_toggle_label(defaults_toggle_button, defaults_scroll, default_count)
			defaults_toggle_button.pressed.connect(_on_defaults_toggle_pressed.bind(defaults_toggle_button, defaults_scroll, default_count))

		var parent_container: Container = defaults_container if i >= defaults_start_index else decks_inner
		var entry: Dictionary = _deck_entries[i]
		var entry_id := _deck_entry_id(entry)
		if not _deck_ai_pool_enabled.has(entry_id):
			_deck_ai_pool_enabled[entry_id] = true

		var deck_row := HBoxContainer.new()
		deck_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck_row.add_theme_constant_override("separation", 12)

		var ai_pool_checkbox := CheckBox.new()
		ai_pool_checkbox.button_pressed = bool(_deck_ai_pool_enabled[entry_id])
		ai_pool_checkbox.tooltip_text = "Include this deck in the AI opponent pool"
		ai_pool_checkbox.custom_minimum_size = Vector2(48, 48)
		ai_pool_checkbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ai_pool_checkbox.focus_mode = Control.FOCUS_NONE
		UITheme.style_checkbox(ai_pool_checkbox, 22, 36, UITheme.GOLD)
		ai_pool_checkbox.toggled.connect(_on_deck_ai_pool_toggled.bind(entry_id))
		deck_row.add_child(ai_pool_checkbox)

		var deck_button := Button.new()
		deck_button.custom_minimum_size = Vector2(0, 60)
		deck_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_button(deck_button, 24)
		deck_button.pressed.connect(_on_deck_selected.bind(i))
		# Build rich content: name | attribute icons | card count
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12
		content.offset_right = -12
		deck_button.add_child(content)
		var name_label := Label.new()
		name_label.text = str(entry.get("name", "Unknown"))
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(name_label)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(spacer)
		var attr_ids: Array = entry.get("attribute_ids", [])
		for attr_id in attr_ids:
			var icon_path := "res://assets/images/attributes/%s-small.png" % str(attr_id)
			if ResourceLoader.exists(icon_path):
				var icon := TextureRect.new()
				icon.texture = load(icon_path)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(32, 32)
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				content.add_child(icon)
		var count_label := Label.new()
		count_label.text = "%d cards" % int(entry.get("card_count", 0))
		count_label.add_theme_font_size_override("font_size", 20)
		count_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(count_label)
		deck_row.add_child(deck_button)
		parent_container.add_child(deck_row)
		_deck_select_buttons.append(deck_button)

	# Bottom action buttons
	var button_spacer := Control.new()
	button_spacer.custom_minimum_size = Vector2(0, 8)
	root.add_child(button_spacer)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 16)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(action_row)

	_start_match_button = Button.new()
	_start_match_button.text = "Start Match"
	_start_match_button.custom_minimum_size = Vector2(240, 64)
	_start_match_button.disabled = true
	UITheme.style_button(_start_match_button, 24)
	_start_match_button.pressed.connect(_on_start_match_pressed)
	action_row.add_child(_start_match_button)

	var random_decks_button := Button.new()
	random_decks_button.text = "Random Decks"
	random_decks_button.custom_minimum_size = Vector2(240, 64)
	UITheme.style_button(random_decks_button, 24)
	random_decks_button.pressed.connect(_on_random_decks_pressed)
	action_row.add_child(random_decks_button)


func _update_defaults_toggle_label(button: Button, container: Control, count: int) -> void:
	var arrow := "\u25BC" if container.visible else "\u25B6"
	button.text = "%s  Default Decks (%d)" % [arrow, count]


func _on_defaults_toggle_pressed(button: Button, container: Control, count: int) -> void:
	container.visible = not container.visible
	_update_defaults_toggle_label(button, container, count)


func _on_deck_selected(index: int) -> void:
	_selected_deck_index = index
	_start_match_button.disabled = false
	for i in range(_deck_select_buttons.size()):
		var btn: Button = _deck_select_buttons[i]
		if i == index:
			UITheme.style_button_selected(btn)
		else:
			UITheme.style_button(btn, 20)

	if _deck_select_card_list != null:
		var entry: Dictionary = _deck_entries[index]
		var card_ids: Array
		if entry.has("card_ids"):
			card_ids = entry.get("card_ids", [])
		else:
			card_ids = _load_deck_card_ids(entry.get("path", ""))
		_deck_select_card_list.set_deck(_card_ids_to_entries(card_ids), _deck_select_card_lookup)


func _card_ids_to_entries(card_ids: Array) -> Array:
	var counts: Dictionary = {}
	for id in card_ids:
		var key := str(id)
		counts[key] = int(counts.get(key, 0)) + 1
	var entries: Array = []
	for id in counts.keys():
		entries.append({"card_id": id, "quantity": counts[id]})
	return entries


func _load_deck_select_card_lookup() -> void:
	_deck_select_card_lookup.clear()
	var catalog := CardCatalog.load_default()
	for card in catalog.get("cards", []):
		_deck_select_card_lookup[str(card.get("card_id", ""))] = card


func _on_start_match_pressed() -> void:
	GameLogger.trc("App", "start_match", "deck_idx:%s" % [str(_selected_deck_index)])
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

	var enemy_entry := _pick_random_enemy_deck_entry(_deck_entry_id(selected_entry))
	if enemy_entry.is_empty():
		return
	var enemy_deck_ids := _entry_to_card_ids(enemy_entry)
	if enemy_deck_ids.is_empty():
		return

	_deck_select_screen.queue_free()
	_deck_select_screen = null
	_deck_select_card_list = null
	_deck_select_hover_layer = null

	var match_screen := MatchScreen.new()
	match_screen.name = "Match"
	match_screen.return_to_main_menu_requested.connect(_show_main_menu)
	add_child(match_screen)
	_active_screen = match_screen
	var ai_options := {
		"human_deck_name": str(selected_entry.get("name", "")),
		"ai_deck_name": str(enemy_entry.get("name", "")),
	}
	match_screen.start_match_with_decks(player_deck_ids, enemy_deck_ids, -1, -1, ai_options)


func _on_random_decks_pressed() -> void:
	var catalog := CardCatalog.load_default()
	var all_cards: Array = []
	for card in catalog.get("cards", []):
		if bool(card.get("collectible", true)):
			all_cards.append(card)
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
	_deck_select_card_list = null
	_deck_select_hover_layer = null

	var match_screen := MatchScreen.new()
	match_screen.name = "Match"
	match_screen.return_to_main_menu_requested.connect(_show_main_menu)
	add_child(match_screen)
	_active_screen = match_screen
	# Random decks: empty human_deck_name is the explicit bypass — AI makes
	# no attempt to identify or remember a freshly randomized deck.
	match_screen.start_match_with_decks(player_deck_ids, enemy_deck_ids, -1, -1, {"human_deck_name": ""})


func _on_deck_select_back_pressed() -> void:
	if _deck_select_screen != null:
		_deck_select_screen.queue_free()
		_deck_select_screen = null
	_deck_select_card_list = null
	_deck_select_hover_layer = null
	_main_menu.visible = true


func _deck_entry_id(entry: Dictionary) -> String:
	var path := str(entry.get("path", ""))
	if not path.is_empty():
		return "default:" + path
	return "player:" + str(entry.get("name", ""))


func _on_deck_ai_pool_toggled(pressed: bool, entry_id: String) -> void:
	_deck_ai_pool_enabled[entry_id] = pressed
	PlayerSettings.set_ai_pool_enabled(entry_id, pressed)


func _entry_to_card_ids(entry: Dictionary) -> Array:
	if entry.has("card_ids"):
		return (entry.get("card_ids", []) as Array).duplicate()
	return _load_deck_card_ids(str(entry.get("path", "")))


func _pick_random_enemy_deck(exclude_id: String) -> Array:
	var picked := _pick_random_enemy_deck_entry(exclude_id)
	if picked.is_empty():
		return []
	return _entry_to_card_ids(picked)


func _pick_random_enemy_deck_entry(exclude_id: String) -> Dictionary:
	var candidates: Array = []
	for entry in _deck_entries:
		var entry_id := _deck_entry_id(entry)
		if entry_id == exclude_id:
			continue
		if not bool(_deck_ai_pool_enabled.get(entry_id, true)):
			continue
		candidates.append(entry)
	if candidates.is_empty():
		for entry in _deck_entries:
			if _deck_entry_id(entry) != exclude_id:
				candidates.append(entry)
	if candidates.is_empty():
		return {}
	candidates.shuffle()
	return candidates[0]


func _load_valid_player_deck_entries() -> Array:
	var catalog_data := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_data.get("card_by_id", {})
	if card_by_id.is_empty():
		push_warning("Deck select: card catalog is empty, skipping player decks")
		return []

	var entries: Array = []
	var deck_names := DeckPersistence.list_decks()
	print("[DeckSelect] Found %d decks: %s" % [deck_names.size(), str(deck_names)])
	for deck_name in deck_names:
		var definition := DeckPersistence.load_deck(deck_name)
		if definition.is_empty():
			print("[DeckSelect] SKIP '%s': failed to load (empty definition)" % deck_name)
			continue
		print("[DeckSelect] Loaded '%s': attribute_ids=%s, card_count=%d" % [deck_name, str(definition.get("attribute_ids", [])), definition.get("cards", []).size()])
		var validation := DeckValidator.validate_deck(definition, card_by_id)
		if not validation.get("is_valid", false):
			print("[DeckSelect] SKIP '%s': validation failed: %s" % [deck_name, str(validation.get("errors", []))])
			continue
		print("[DeckSelect] PASS '%s'" % deck_name)
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
	var has_autosave := TestMatchConfig.has_autosave()

	_main_menu.visible = false

	_test_match_picker = Control.new()
	_test_match_picker.name = "TestMatchPicker"
	_test_match_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_test_match_picker.z_index = 100
	add_child(_test_match_picker)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_test_match_picker.add_child(bg)

	# Centre the panel using anchors
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -260
	panel.offset_bottom = 260
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	UITheme.style_panel(panel)
	_test_match_picker.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(outer_vbox)

	var title := Label.new()
	title.text = "Test Match Configs"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_title(title, 28)
	outer_vbox.add_child(title)

	outer_vbox.add_child(UITheme.make_separator(0.0))

	# Autosave section
	if has_autosave:
		var autosave_config := TestMatchConfig.load_autosave()
		var autosave_row := HBoxContainer.new()
		autosave_row.add_theme_constant_override("separation", 8)
		outer_vbox.add_child(autosave_row)

		var autosave_btn := Button.new()
		var autosave_name := str(autosave_config.get("name", "")).strip_edges()
		var autosave_text := autosave_name if not autosave_name.is_empty() else "Test Match Creator (Autosave)"
		var autosave_desc := str(autosave_config.get("description", ""))
		if not autosave_desc.is_empty():
			autosave_text += "  —  " + autosave_desc
		autosave_btn.text = autosave_text
		autosave_btn.custom_minimum_size = Vector2(0, 52)
		autosave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		autosave_btn.clip_text = true
		UITheme.style_button(autosave_btn, 20)
		autosave_btn.pressed.connect(_on_test_match_selected.bind(TestMatchConfig.AUTOSAVE_FILENAME))
		autosave_row.add_child(autosave_btn)

		var reset_btn := Button.new()
		reset_btn.text = "Reset"
		reset_btn.custom_minimum_size = Vector2(80, 52)
		reset_btn.tooltip_text = "Delete the autosave config"
		UITheme.style_button_accent(reset_btn, Color(0.8, 0.3, 0.3), 18)
		reset_btn.pressed.connect(_on_test_match_reset_autosave)
		autosave_row.add_child(reset_btn)

		outer_vbox.add_child(UITheme.make_separator(0.0))

	if configs.is_empty() and not has_autosave:
		var empty_label := Label.new()
		empty_label.text = "No test matches configured"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer_vbox.add_child(empty_label)
	elif not configs.is_empty():
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
			launch_btn.custom_minimum_size = Vector2(0, 52)
			launch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			launch_btn.clip_text = true
			UITheme.style_button(launch_btn, 20)
			var filename: String = config_entry.get("filename", "")
			launch_btn.pressed.connect(_on_test_match_selected.bind(filename))
			row.add_child(launch_btn)

			var delete_btn := Button.new()
			delete_btn.text = "X"
			delete_btn.custom_minimum_size = Vector2(52, 52)
			delete_btn.tooltip_text = "Delete this config"
			UITheme.style_button_accent(delete_btn, Color(0.8, 0.3, 0.3), 18)
			delete_btn.pressed.connect(_on_test_match_delete.bind(filename))
			row.add_child(delete_btn)

	outer_vbox.add_child(UITheme.make_separator(0.0))

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 48)
	UITheme.style_button(back_btn, 22, true)
	back_btn.pressed.connect(_on_test_match_picker_back)
	outer_vbox.add_child(back_btn)


func _on_match_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		_show_test_match_picker()


func _on_test_match_selected(filename: String) -> void:
	if _test_match_picker != null:
		_test_match_picker.queue_free()
		_test_match_picker = null

	_current_test_match_filename = filename
	var test_state := TestMatchConfig.build_test_match_state_from_file(filename)
	if test_state.is_empty():
		push_error("TestMatchConfig returned an empty match state for '%s'" % filename)
		_main_menu.visible = true
		return
	var match_screen := MatchScreen.new()
	match_screen.name = "Match"
	match_screen.return_to_main_menu_requested.connect(_show_main_menu)
	match_screen.test_match_restart_requested.connect(_on_test_match_restart.bind(match_screen))
	add_child(match_screen)
	_active_screen = match_screen
	match_screen.start_test_match(test_state)


func _on_test_match_restart(match_screen: Control) -> void:
	match_screen.queue_free()
	_on_test_match_selected(_current_test_match_filename)


func _on_test_match_reset_autosave() -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 110
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_test_match_picker.add_child(overlay)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.6)
	overlay.add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(450, 0)
	UITheme.style_panel(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var msg := Label.new()
	msg.text = "Reset the autosave config?"
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 48)
	UITheme.style_button(cancel_btn, 20, true)
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Reset"
	confirm_btn.custom_minimum_size = Vector2(120, 48)
	UITheme.style_button_accent(confirm_btn, Color(0.8, 0.3, 0.3), 20)
	confirm_btn.pressed.connect(func():
		overlay.queue_free()
		TestMatchConfig.reset_autosave()
		_show_test_match_picker()
	)
	btn_row.add_child(confirm_btn)


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
	GameLogger.trc("App", "screen", "to:deckbuilder")
	_main_menu.visible = false
	var deckbuilder_screen := DeckbuilderScreen.new()
	deckbuilder_screen.name = "Deckbuilder"
	deckbuilder_screen.back_to_menu_requested.connect(_show_main_menu)
	add_child(deckbuilder_screen)
	_active_screen = deckbuilder_screen


func _on_settings_pressed() -> void:
	GameLogger.trc("App", "screen", "to:settings")
	_main_menu.visible = false
	_settings_screen = SettingsScreenScript.new()
	_settings_screen.name = "Settings"
	_settings_screen.back_pressed.connect(_on_settings_back)
	_settings_screen.select_avatar_pressed.connect(_on_select_avatar_pressed)
	add_child(_settings_screen)
	_active_screen = _settings_screen


func _on_settings_back() -> void:
	if _settings_screen != null:
		_settings_screen.queue_free()
		_settings_screen = null
	_active_screen = null
	_show_main_menu()


func _on_select_avatar_pressed() -> void:
	GameLogger.trc("App", "screen", "to:avatar_carousel")
	if _settings_screen != null:
		_settings_screen.visible = false
	_avatar_carousel_screen = AvatarCarouselScreenScript.new()
	_avatar_carousel_screen.name = "AvatarCarousel"
	_avatar_carousel_screen.back_pressed.connect(_on_avatar_carousel_back)
	add_child(_avatar_carousel_screen)
	_active_screen = _avatar_carousel_screen


func _on_avatar_carousel_back() -> void:
	if _avatar_carousel_screen != null:
		_avatar_carousel_screen.queue_free()
		_avatar_carousel_screen = null
	if _settings_screen != null:
		_settings_screen.visible = true
		if _settings_screen.has_method("refresh_avatar_preview"):
			_settings_screen.refresh_avatar_preview()
		_active_screen = _settings_screen
	else:
		_active_screen = null
		_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
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
	bg.color = Color(0.04, 0.05, 0.07, 0.78)
	_pause_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	UITheme.style_panel(panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = "Paused"
	UITheme.style_title(title, 30)
	vbox.add_child(title)

	vbox.add_child(UITheme.make_separator(260.0))

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size = Vector2(260, 52)
	UITheme.style_button(resume_button, 20)
	resume_button.pressed.connect(_dismiss_pause_menu)
	vbox.add_child(resume_button)

	var main_menu_button := Button.new()
	main_menu_button.text = "Return to Main Menu"
	main_menu_button.custom_minimum_size = Vector2(260, 52)
	UITheme.style_button(main_menu_button, 20, true)
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
