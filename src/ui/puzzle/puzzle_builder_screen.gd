class_name PuzzleBuilderScreen
extends Control

signal play_requested(config: Dictionary)
signal back_requested

const UITheme = preload("res://src/ui/ui_theme.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")
const PuzzleCodecScript = preload("res://src/puzzle/puzzle_codec.gd")
const PuzzleConfigScript = preload("res://src/puzzle/puzzle_config.gd")
const PuzzleCardSearchOverlayScript = preload("res://src/ui/puzzle/puzzle_card_search_overlay.gd")
const PuzzleCreatureModifyOverlayScript = preload("res://src/ui/puzzle/puzzle_creature_modify_overlay.gd")
const CardDisplayComponentScript = preload("res://src/ui/components/CardDisplayComponent.gd")
const PuzzlePersistenceScript = preload("res://src/puzzle/puzzle_persistence.gd")
const LANE_REGISTRY_PATH := "res://data/legends/registries/lane_registry.json"

var _config: Dictionary = {}
var _card_by_id: Dictionary = {}
var _lane_types: Array = []

# UI refs
var _name_input: LineEdit
var _type_toggle: CheckButton
var _left_lane_width_spin: SpinBox
var _left_lane_type_dropdown: OptionButton
var _right_lane_type_dropdown: OptionButton
var _right_lane_width_label: Label
var _player_health_spin: SpinBox
var _enemy_health_spin: SpinBox
var _player_magicka_input: LineEdit
var _player_cur_magicka_input: LineEdit
var _enemy_magicka_input: LineEdit
var _enemy_cur_magicka_input: LineEdit
var _ring_check: CheckBox
var _enemy_settings_container: HBoxContainer
var _lane_config_container: HBoxContainer
var _board_container: VBoxContainer
var _player_settings_container: HBoxContainer
var _status_label: Label
var _slot_buttons: Array = []  # [side][lane_idx][slot_idx] -> Button
var _import_dialog: PanelContainer
var _import_input: TextEdit
var _import_error_label: Label

# Hover preview
var _hover_preview: Control
var _hover_timer: Timer
var _hover_card_data: Dictionary = {}
const HOVER_DELAY := 0.35
const PREVIEW_SIZE := Vector2(220, 384)

# Active overlay tracking
var _active_overlay: Control
var _pending_slot_side := ""   # "player" or "enemy"
var _pending_slot_lane := 0
var _pending_slot_index := 0
var _pending_card_target := "" # "slot", "hand", "deck", "discard", "support"
var _pending_list_side := ""


func _ready() -> void:
	_load_data()
	_init_default_config()
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY
	_hover_timer.timeout.connect(_show_hover_preview)
	add_child(_hover_timer)
	_build_ui()
	_refresh_board()


func load_config(config: Dictionary) -> void:
	_config = config.duplicate(true)
	if is_inside_tree():
		_sync_ui_from_config()
		_refresh_board()


func _load_data() -> void:
	var catalog_result := CardCatalog.load_default()
	_card_by_id = catalog_result.get("card_by_id", {})

	var file := FileAccess.open(LANE_REGISTRY_PATH, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			var raw_types = parsed.get("lane_types", [])
			if typeof(raw_types) == TYPE_ARRAY:
				for lt in raw_types:
					if typeof(lt) == TYPE_DICTIONARY:
						_lane_types.append(lt)


func _init_default_config() -> void:
	_config = {
		"name": "",
		"type": "kill",
		"lanes": [
			{"lane_type": "field", "width": 4},
			{"lane_type": "shadow", "width": 4},
		],
		"player": {
			"health": 30, "max_magicka": 12, "current_magicka": 12,
			"has_ring": false,
			"hand": [], "deck": [], "discard": [], "supports": [],
			"field_creatures": [], "shadow_creatures": [],
		},
		"enemy": {
			"health": 30, "max_magicka": 3, "current_magicka": 3,
			"hand": [], "deck": [], "discard": [], "supports": [],
			"field_creatures": [], "shadow_creatures": [],
		},
	}


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	UITheme.add_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# Top bar (back + name + toggle + action buttons)
	_build_top_bar(root)

	# Header separator
	root.add_child(UITheme.make_separator(0.0))

	# Enemy settings row (rebuilt in _refresh_board)
	_enemy_settings_container = HBoxContainer.new()
	_enemy_settings_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_enemy_settings_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_settings_container.add_theme_constant_override("separation", 24)
	root.add_child(_enemy_settings_container)

	# Lane config row (rebuilt in _refresh_board)
	_lane_config_container = HBoxContainer.new()
	_lane_config_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_lane_config_container.add_theme_constant_override("separation", 0)
	root.add_child(_lane_config_container)

	# Board area — takes all remaining vertical space
	_board_container = VBoxContainer.new()
	_board_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_board_container.size_flags_vertical = SIZE_EXPAND_FILL
	_board_container.add_theme_constant_override("separation", 0)
	root.add_child(_board_container)

	# Gap above player settings
	var player_settings_spacer := Control.new()
	player_settings_spacer.custom_minimum_size = Vector2(0, 12)
	root.add_child(player_settings_spacer)

	# Player settings row (rebuilt in _refresh_board)
	_player_settings_container = HBoxContainer.new()
	_player_settings_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_player_settings_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_settings_container.add_theme_constant_override("separation", 24)
	root.add_child(_player_settings_container)

	# Status bar
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	root.add_child(_status_label)

	# Import dialog
	_build_import_dialog()


func _build_top_bar(parent: VBoxContainer) -> void:
	# Single row: Back | Name | Kill/Survive toggle | Export Import Play
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	parent.add_child(bar)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 56)
	UITheme.style_button(back_btn, 22, true)
	back_btn.pressed.connect(func(): back_requested.emit())
	bar.add_child(back_btn)

	# Puzzle name — in the top bar
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Puzzle Name"
	_name_input.max_length = 40
	_name_input.custom_minimum_size = Vector2(300, 56)
	_name_input.add_theme_font_size_override("font_size", 22)
	_name_input.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	_name_input.add_theme_color_override("font_placeholder_color", UITheme.TEXT_MUTED)
	_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = UITheme.BTN_BG
	name_style.border_color = UITheme.GOLD_DIM
	name_style.set_border_width_all(1)
	name_style.set_corner_radius_all(4)
	name_style.set_content_margin_all(12)
	_name_input.add_theme_stylebox_override("normal", name_style)
	var name_focus := StyleBoxFlat.new()
	name_focus.bg_color = UITheme.BTN_BG_HOVER
	name_focus.border_color = UITheme.GOLD
	name_focus.set_border_width_all(2)
	name_focus.set_corner_radius_all(4)
	name_focus.set_content_margin_all(12)
	_name_input.add_theme_stylebox_override("focus", name_focus)
	_name_input.add_theme_color_override("caret_color", UITheme.GOLD)
	_name_input.text_changed.connect(func(t): _config["name"] = t)
	bar.add_child(_name_input)

	# Kill/Survive toggle — centered with panel background
	var toggle_spacer_left := Control.new()
	toggle_spacer_left.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(toggle_spacer_left)

	var toggle_panel := PanelContainer.new()
	var toggle_style := StyleBoxFlat.new()
	toggle_style.bg_color = UITheme.PANEL_BG
	toggle_style.border_color = UITheme.PANEL_BORDER
	toggle_style.set_border_width_all(2)
	toggle_style.set_corner_radius_all(6)
	toggle_style.content_margin_left = 20
	toggle_style.content_margin_right = 20
	toggle_style.content_margin_top = 8
	toggle_style.content_margin_bottom = 8
	toggle_panel.add_theme_stylebox_override("panel", toggle_style)
	bar.add_child(toggle_panel)

	var toggle_row := HBoxContainer.new()
	#toggle_row.add_theme_constant_override("separation", 6)
	toggle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_panel.add_child(toggle_row)

	var kill_label := Label.new()
	kill_label.text = "KILL"
	kill_label.add_theme_font_size_override("font_size", 26)
	kill_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)

	var survive_label := Label.new()
	survive_label.text = "SURVIVE"
	survive_label.add_theme_font_size_override("font_size", 26)
	survive_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)

	_type_toggle = CheckButton.new()
	_type_toggle.text = ""
	_type_toggle.button_pressed = false
	_type_toggle.custom_minimum_size = Vector2(0, 44)
	_type_toggle.size_flags_horizontal = SIZE_SHRINK_CENTER
	_type_toggle.toggled.connect(func(pressed):
		_config["type"] = "survive" if pressed else "kill"
		kill_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED if pressed else UITheme.GOLD_BRIGHT)
		survive_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT if pressed else UITheme.TEXT_MUTED)
	)

	toggle_row.add_child(kill_label)
	toggle_row.add_child(_type_toggle)
	toggle_row.add_child(survive_label)

	var toggle_spacer_right := Control.new()
	toggle_spacer_right.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(toggle_spacer_right)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(110, 56)
	UITheme.style_button(save_btn, 20)
	save_btn.pressed.connect(_on_save)
	bar.add_child(save_btn)

	var export_btn := Button.new()
	export_btn.text = "Export"
	export_btn.custom_minimum_size = Vector2(110, 56)
	UITheme.style_button(export_btn, 20)
	export_btn.pressed.connect(_on_export)
	bar.add_child(export_btn)

	var import_btn := Button.new()
	import_btn.text = "Import"
	import_btn.custom_minimum_size = Vector2(110, 56)
	UITheme.style_button(import_btn, 20)
	import_btn.pressed.connect(_show_import_dialog)
	bar.add_child(import_btn)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(110, 56)
	UITheme.style_button(play_btn, 20)
	play_btn.pressed.connect(_on_play)
	bar.add_child(play_btn)


func _refresh_board() -> void:
	# Clear all dynamic containers
	for container in [_enemy_settings_container, _lane_config_container, _board_container, _player_settings_container]:
		for child in container.get_children():
			child.queue_free()
	_slot_buttons.clear()

	var lane_widths: Array = [
		int(_config["lanes"][0].get("width", 4)),
		int(_config["lanes"][1].get("width", 4)),
	]

	# Enemy health/magicka
	_build_enemy_settings_row()

	# Lane config row
	_build_lane_config_row(lane_widths)

	# Spacer between lane config and enemy section
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 24)
	_board_container.add_child(top_spacer)

	# Enemy side (top half of board)
	_build_side_section("enemy", "Enemy", lane_widths)

	# Separator
	var sep := UITheme.make_separator(0.0)
	sep.custom_minimum_size.y = 24
	_board_container.add_child(sep)

	# Player side (bottom half of board)
	_build_side_section("player", "Player", lane_widths)

	# Player health/magicka/ring
	_build_player_settings_row()


func _build_enemy_settings_row() -> void:
	_enemy_settings_container.add_child(_labeled("Enemy Health:", _make_spin(1, 99, int(_config.get("enemy", {}).get("health", 30)), func(v): _config["enemy"]["health"] = int(v)), true))
	_enemy_health_spin = _enemy_settings_container.get_child(_enemy_settings_container.get_child_count() - 1).get_child(1)

	_enemy_settings_container.add_child(_labeled("Enemy Magicka:", _make_magicka_input(str(int(_config.get("enemy", {}).get("max_magicka", 3))), func(t): _config["enemy"]["max_magicka"] = _parse_int(t, 3); _config["enemy"]["current_magicka"] = _parse_int(t, 3))))
	_enemy_magicka_input = _enemy_settings_container.get_child(_enemy_settings_container.get_child_count() - 1).get_child(1)


func _build_player_settings_row() -> void:
	_player_settings_container.add_child(_labeled("Player Health:", _make_spin(1, 99, int(_config.get("player", {}).get("health", 30)), func(v): _config["player"]["health"] = int(v)), true))
	_player_health_spin = _player_settings_container.get_child(_player_settings_container.get_child_count() - 1).get_child(1)

	_player_settings_container.add_child(_labeled("Player Magicka:", _make_magicka_input(str(int(_config.get("player", {}).get("max_magicka", 12))), func(t): _config["player"]["max_magicka"] = _parse_int(t, 12); _config["player"]["current_magicka"] = _parse_int(t, 12))))
	_player_magicka_input = _player_settings_container.get_child(_player_settings_container.get_child_count() - 1).get_child(1)

	_ring_check = CheckBox.new()
	_ring_check.text = "Ring of Magicka"
	_ring_check.button_pressed = bool(_config.get("player", {}).get("has_ring", false))
	UITheme.style_checkbox(_ring_check, 24)
	_ring_check.toggled.connect(func(v): _config["player"]["has_ring"] = v)
	_player_settings_container.add_child(_ring_check)


func _build_lane_config_row(lane_widths: Array) -> void:
	var row := _lane_config_container

	# Lane 1 config — centered in the left half (25% mark)
	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(left_spacer)

	var lane1_box := HBoxContainer.new()
	lane1_box.add_theme_constant_override("separation", 10)
	lane1_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(lane1_box)

	var l1_label := Label.new()
	l1_label.text = "Lane 1:"
	UITheme.style_section_label(l1_label, 24)
	lane1_box.add_child(l1_label)

	_left_lane_type_dropdown = OptionButton.new()
	_left_lane_type_dropdown.custom_minimum_size = Vector2(180, 48)
	UITheme.style_option_button(_left_lane_type_dropdown, 22)
	_populate_lane_dropdown(_left_lane_type_dropdown)
	_select_lane_dropdown(_left_lane_type_dropdown, str(_config["lanes"][0].get("lane_type", "field")))
	_left_lane_type_dropdown.item_selected.connect(func(idx):
		_config["lanes"][0]["lane_type"] = str(_left_lane_type_dropdown.get_item_text(idx))
	)
	lane1_box.add_child(_left_lane_type_dropdown)

	_left_lane_width_spin = SpinBox.new()
	_left_lane_width_spin.min_value = 1
	_left_lane_width_spin.max_value = 7
	_left_lane_width_spin.value = int(lane_widths[0])
	_left_lane_width_spin.custom_minimum_size = Vector2(100, 48)
	UITheme.style_spin_box(_left_lane_width_spin, 22)
	_left_lane_width_spin.value_changed.connect(func(val):
		var old_w0: int = int(_config["lanes"][0].get("width", 4))
		var new_w0: int = int(val)
		_config["lanes"][0]["width"] = new_w0
		_config["lanes"][1]["width"] = 8 - new_w0
		_right_lane_width_label.text = str(8 - new_w0)
		_redistribute_overflow(old_w0, new_w0)
		_refresh_board()
	)
	lane1_box.add_child(_left_lane_width_spin)

	# Middle spacer — pushes lane configs apart
	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(mid_spacer)

	# Lane 2 config — centered in the right half (75% mark)
	var lane2_box := HBoxContainer.new()
	lane2_box.add_theme_constant_override("separation", 10)
	lane2_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(lane2_box)

	var l2_label := Label.new()
	l2_label.text = "Lane 2:"
	UITheme.style_section_label(l2_label, 24)
	lane2_box.add_child(l2_label)

	_right_lane_type_dropdown = OptionButton.new()
	_right_lane_type_dropdown.custom_minimum_size = Vector2(180, 48)
	UITheme.style_option_button(_right_lane_type_dropdown, 22)
	_populate_lane_dropdown(_right_lane_type_dropdown)
	_select_lane_dropdown(_right_lane_type_dropdown, str(_config["lanes"][1].get("lane_type", "shadow")))
	_right_lane_type_dropdown.item_selected.connect(func(idx):
		_config["lanes"][1]["lane_type"] = str(_right_lane_type_dropdown.get_item_text(idx))
	)
	lane2_box.add_child(_right_lane_type_dropdown)

	_right_lane_width_label = Label.new()
	_right_lane_width_label.text = str(int(lane_widths[1]))
	_right_lane_width_label.add_theme_font_size_override("font_size", 24)
	_right_lane_width_label.add_theme_color_override("font_color", UITheme.GOLD)
	lane2_box.add_child(_right_lane_width_label)

	# Right spacer
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(right_spacer)


func _redistribute_overflow(old_lane1_width: int, new_lane1_width: int) -> void:
	if old_lane1_width == new_lane1_width:
		return
	for side in ["player", "enemy"]:
		var cfg: Dictionary = _get_side_cfg(side)
		var lane1: Array = cfg.get("field_creatures", [])
		var lane2: Array = cfg.get("shadow_creatures", [])
		if new_lane1_width < old_lane1_width:
			# Lane 1 shrank — move overflow to front of lane 2
			var overflow: Array = []
			while lane1.size() > new_lane1_width:
				overflow.append(lane1.pop_back())
			overflow.reverse()
			for i in range(overflow.size() - 1, -1, -1):
				lane2.push_front(overflow[i])
		else:
			# Lane 1 grew — pull from front of lane 2 into end of lane 1
			var slots_gained: int = new_lane1_width - old_lane1_width
			var moved := 0
			while moved < slots_gained and not lane2.is_empty():
				lane1.append(lane2.pop_front())
				moved += 1
		cfg["field_creatures"] = lane1
		cfg["shadow_creatures"] = lane2


func _build_side_section(side: String, label_text: String, lane_widths: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.size_flags_vertical = SIZE_EXPAND_FILL
	_board_container.add_child(section)

	# Side header with clickable zones
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_child(header)

	var header_spacer := Control.new()
	header_spacer.custom_minimum_size = Vector2(0, 12)
	section.add_child(header_spacer)

	var side_label := Label.new()
	side_label.text = label_text
	side_label.custom_minimum_size = Vector2(100, 0)
	UITheme.style_section_label(side_label, 24)
	header.add_child(side_label)

	var hand_btn := Button.new()
	var hand_count: int = _get_side_cfg(side).get("hand", []).size()
	hand_btn.text = "Hand (%d)" % hand_count
	hand_btn.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button(hand_btn, 20)
	hand_btn.pressed.connect(func(): _open_list_editor(side, "hand"))
	header.add_child(hand_btn)

	var deck_btn := Button.new()
	var deck_count: int = _get_side_cfg(side).get("deck", []).size()
	deck_btn.text = "Deck (%d)" % deck_count
	deck_btn.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button(deck_btn, 20)
	deck_btn.pressed.connect(func(): _open_list_editor(side, "deck"))
	header.add_child(deck_btn)

	var discard_btn := Button.new()
	var discard_count: int = _get_side_cfg(side).get("discard", []).size()
	discard_btn.text = "Discard (%d)" % discard_count
	discard_btn.custom_minimum_size = Vector2(160, 52)
	UITheme.style_button(discard_btn, 20)
	discard_btn.pressed.connect(func(): _open_list_editor(side, "discard"))
	header.add_child(discard_btn)

	var support_btn := Button.new()
	var support_count: int = _get_side_cfg(side).get("supports", []).size()
	support_btn.text = "Supports (%d)" % support_count
	support_btn.custom_minimum_size = Vector2(170, 52)
	UITheme.style_button(support_btn, 20)
	support_btn.pressed.connect(func(): _open_list_editor(side, "supports"))
	header.add_child(support_btn)

	# Board slots — 2 lane groups
	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 32)
	board_row.size_flags_horizontal = SIZE_EXPAND_FILL
	board_row.size_flags_vertical = SIZE_EXPAND_FILL
	section.add_child(board_row)

	var lane_keys: Array[String] = ["field_creatures", "shadow_creatures"]

	for lane_idx in range(2):
		# Red vertical lane separator between lanes
		if lane_idx == 1:
			var lane_sep := VSeparator.new()
			lane_sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
			var sep_style: StyleBoxLine = lane_sep.get_theme_stylebox("separator")
			sep_style.color = UITheme.GOLD_DIM
			sep_style.thickness = 2
			sep_style.vertical = true
			lane_sep.custom_minimum_size = Vector2(2, 0)
			board_row.add_child(lane_sep)

		var width: int = int(lane_widths[lane_idx])
		var lane_frame := VBoxContainer.new()
		lane_frame.add_theme_constant_override("separation", 6)
		lane_frame.size_flags_horizontal = SIZE_EXPAND_FILL
		lane_frame.size_flags_stretch_ratio = float(width)
		lane_frame.size_flags_vertical = SIZE_EXPAND_FILL
		board_row.add_child(lane_frame)

		var slots_row := HBoxContainer.new()
		slots_row.add_theme_constant_override("separation", 32)
		slots_row.size_flags_horizontal = SIZE_EXPAND_FILL
		slots_row.size_flags_vertical = SIZE_EXPAND_FILL
		lane_frame.add_child(slots_row)

		var creatures: Array = _get_side_cfg(side).get(lane_keys[lane_idx], [])

		for slot_idx in range(width):
			var slot_frame := VBoxContainer.new()
			slot_frame.add_theme_constant_override("separation", 4)
			slot_frame.size_flags_horizontal = SIZE_EXPAND_FILL
			slot_frame.size_flags_vertical = SIZE_EXPAND_FILL
			slot_frame.size_flags_stretch_ratio = 0.8
			slots_row.add_child(slot_frame)

			var creature = creatures[slot_idx] if slot_idx < creatures.size() else null
			if creature != null:
				var def_id := ""
				if typeof(creature) == TYPE_STRING:
					def_id = creature
				elif typeof(creature) == TYPE_DICTIONARY:
					def_id = str(creature.get("definition_id", ""))
				var card_data: Dictionary = _card_by_id.get(def_id, {}).duplicate(true)

				# Apply stat overrides for display
				if typeof(creature) == TYPE_DICTIONARY:
					for key in creature:
						if key != "definition_id":
							card_data[key] = creature[key]

				# Card display component — minimal mode, hover for full
				var card_container := Control.new()
				card_container.size_flags_horizontal = SIZE_EXPAND_FILL
				card_container.size_flags_vertical = SIZE_EXPAND_FILL
				card_container.mouse_filter = MOUSE_FILTER_STOP
				slot_frame.add_child(card_container)

				var display := CardDisplayComponentScript.new()
				display.custom_minimum_size = Vector2(1, 1)
				display.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
				card_container.add_child(display)
				display.set_presentation_mode("creature_board_minimal")
				display.custom_minimum_size = Vector2(1, 1)
				display.set_interactive(true)
				display.set_card(card_data)
				display.custom_minimum_size = Vector2(1, 1)

				# Hover to show full card preview
				var cd := card_data
				card_container.mouse_entered.connect(func() -> void:
					_hover_card_data = cd
					_hover_timer.start()
				)
				card_container.mouse_exited.connect(func() -> void:
					_hover_timer.stop()
					_dismiss_hover_preview()
				)

				# Remove + Modify buttons
				var action_row := HBoxContainer.new()
				action_row.add_theme_constant_override("separation", 4)
				action_row.size_flags_horizontal = SIZE_EXPAND_FILL
				slot_frame.add_child(action_row)

				var s := side
				var li := lane_idx
				var si := slot_idx

				var remove_btn := Button.new()
				remove_btn.text = "Remove"
				remove_btn.custom_minimum_size = Vector2(0, 32)
				remove_btn.size_flags_horizontal = SIZE_EXPAND_FILL
				UITheme.style_button_accent(remove_btn, Color(0.8, 0.3, 0.3), 12)
				remove_btn.pressed.connect(func(): _remove_creature(s, li, si))
				action_row.add_child(remove_btn)

				var modify_btn := Button.new()
				modify_btn.text = "Mod"
				modify_btn.custom_minimum_size = Vector2(0, 32)
				modify_btn.size_flags_horizontal = SIZE_EXPAND_FILL
				UITheme.style_button(modify_btn, 12)
				modify_btn.pressed.connect(func(): _modify_creature(s, li, si))
				action_row.add_child(modify_btn)
			else:
				var empty_btn := Button.new()
				empty_btn.text = "+"
				empty_btn.size_flags_horizontal = SIZE_EXPAND_FILL
				empty_btn.size_flags_vertical = SIZE_EXPAND_FILL
				UITheme.style_button(empty_btn, 28, true)
				var s := side
				var li := lane_idx
				var si := slot_idx
				empty_btn.pressed.connect(func(): _on_empty_slot_clicked(s, li, si))
				slot_frame.add_child(empty_btn)


func _on_empty_slot_clicked(side: String, lane_idx: int, slot_idx: int) -> void:
	_pending_slot_side = side
	_pending_slot_lane = lane_idx
	_pending_slot_index = slot_idx
	_pending_card_target = "slot"
	_open_card_search("creature")


func _on_populated_slot_clicked(_side: String, _lane_idx: int, _slot_idx: int) -> void:
	pass  # Click on populated slot does nothing — use Remove/Modify buttons


func _remove_creature(side: String, lane_idx: int, slot_idx: int) -> void:
	var lane_key := "field_creatures" if lane_idx == 0 else "shadow_creatures"
	var creatures: Array = _get_side_cfg(side).get(lane_key, [])
	if slot_idx < creatures.size():
		creatures.remove_at(slot_idx)
	_refresh_board()


func _modify_creature(side: String, lane_idx: int, slot_idx: int) -> void:
	var lane_key := "field_creatures" if lane_idx == 0 else "shadow_creatures"
	var creatures: Array = _get_side_cfg(side).get(lane_key, [])
	if slot_idx >= creatures.size():
		return
	var creature = creatures[slot_idx]
	var overrides := {}
	if typeof(creature) == TYPE_DICTIONARY:
		overrides = creature.duplicate()
		overrides.erase("definition_id")

	var overlay := PuzzleCreatureModifyOverlayScript.new()
	add_child(overlay)
	_active_overlay = overlay
	overlay.load_overrides(overrides)
	overlay.confirmed.connect(func(new_overrides: Dictionary):
		var def_id := ""
		if typeof(creature) == TYPE_STRING:
			def_id = creature
		elif typeof(creature) == TYPE_DICTIONARY:
			def_id = str(creature.get("definition_id", ""))
		var updated := {"definition_id": def_id}
		for key in new_overrides:
			updated[key] = new_overrides[key]
		creatures[slot_idx] = updated
		_dismiss_overlay()
		_refresh_board()
	)
	overlay.cancelled.connect(func(): _dismiss_overlay())


func _open_card_search(type_hint: String = "") -> void:
	var overlay := PuzzleCardSearchOverlayScript.new()
	add_child(overlay)
	_active_overlay = overlay
	if not type_hint.is_empty():
		overlay.set_type_filter(type_hint)
	overlay.card_selected.connect(func(card_id: String):
		# Dismiss the search overlay BEFORE _on_card_selected,
		# which may reopen the list editor (setting a new _active_overlay)
		_dismiss_overlay()
		_on_card_selected(card_id)
	)
	overlay.cancelled.connect(func(): _dismiss_overlay())


func _on_card_selected(card_id: String) -> void:
	match _pending_card_target:
		"slot":
			var lane_key := "field_creatures" if _pending_slot_lane == 0 else "shadow_creatures"
			var creatures: Array = _get_side_cfg(_pending_slot_side).get(lane_key, [])
			# Pad with empty if needed
			while creatures.size() <= _pending_slot_index:
				creatures.append(null)
			creatures[_pending_slot_index] = card_id
			# Remove any trailing nulls
			while not creatures.is_empty() and creatures.back() == null:
				creatures.pop_back()
			_get_side_cfg(_pending_slot_side)[lane_key] = creatures
		"hand", "deck", "discard":
			var list: Array = _get_side_cfg(_pending_list_side).get(_pending_card_target, [])
			list.append(card_id)
			_get_side_cfg(_pending_list_side)[_pending_card_target] = list
			_refresh_board()
			_open_list_editor(_pending_list_side, _pending_card_target)
			return
		"supports":
			var list: Array = _get_side_cfg(_pending_list_side).get("supports", [])
			list.append(card_id)
			_get_side_cfg(_pending_list_side)["supports"] = list
			_refresh_board()
			_open_list_editor(_pending_list_side, "supports")
			return
	_refresh_board()


func _open_list_editor(side: String, list_key: String) -> void:
	_pending_list_side = side
	_pending_card_target = list_key

	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 55
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)
	_active_overlay = overlay

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.6)
	overlay.add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(600, 400)
	UITheme.style_panel(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var display_key := list_key.capitalize()
	var title := Label.new()
	title.text = "%s — %s" % [side.capitalize(), display_key]
	UITheme.style_title(title, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(title)

	var actual_key := list_key
	var list_data: Array = _get_side_cfg(side).get(actual_key, [])

	# Card list with reorder + remove
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(list_vbox)

	for i in range(list_data.size()):
		var entry_row := HBoxContainer.new()
		entry_row.add_theme_constant_override("separation", 8)
		entry_row.mouse_filter = MOUSE_FILTER_STOP
		list_vbox.add_child(entry_row)

		var idx_label := Label.new()
		idx_label.text = str(i + 1) + "."
		idx_label.custom_minimum_size = Vector2(30, 0)
		idx_label.add_theme_font_size_override("font_size", 18)
		idx_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		entry_row.add_child(idx_label)

		var card_id := str(list_data[i])
		var card_data: Dictionary = _card_by_id.get(card_id, {})
		var name_label := Label.new()
		name_label.text = str(card_data.get("name", card_id))
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
		entry_row.add_child(name_label)

		# Hover preview
		var cd := card_data
		entry_row.mouse_entered.connect(func() -> void:
			_hover_card_data = cd
			_hover_timer.start()
		)
		entry_row.mouse_exited.connect(func() -> void:
			_hover_timer.stop()
			_dismiss_hover_preview()
		)

		if list_key == "deck" or list_key == "discard":
			# Reorder buttons
			var up_btn := Button.new()
			up_btn.text = "^"
			up_btn.custom_minimum_size = Vector2(36, 32)
			UITheme.style_button(up_btn, 14)
			var idx_up := i
			up_btn.pressed.connect(func():
				_swap_list_items(side, actual_key, idx_up, idx_up - 1)
				_dismiss_overlay()
				_open_list_editor(side, list_key)
			)
			up_btn.disabled = i == 0
			entry_row.add_child(up_btn)

			var down_btn := Button.new()
			down_btn.text = "v"
			down_btn.custom_minimum_size = Vector2(36, 32)
			UITheme.style_button(down_btn, 14)
			var idx_down := i
			down_btn.pressed.connect(func():
				_swap_list_items(side, actual_key, idx_down, idx_down + 1)
				_dismiss_overlay()
				_open_list_editor(side, list_key)
			)
			down_btn.disabled = i == list_data.size() - 1
			entry_row.add_child(down_btn)

		var remove_btn := Button.new()
		remove_btn.text = "X"
		remove_btn.custom_minimum_size = Vector2(36, 32)
		UITheme.style_button_accent(remove_btn, Color(0.8, 0.3, 0.3), 14)
		var remove_idx := i
		remove_btn.pressed.connect(func():
			_remove_list_item(side, actual_key, remove_idx)
			_dismiss_overlay()
			_open_list_editor(side, list_key)
		)
		entry_row.add_child(remove_btn)

	if list_data.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		list_vbox.add_child(empty_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var add_btn := Button.new()
	add_btn.text = "Add Card"
	add_btn.custom_minimum_size = Vector2(120, 48)
	UITheme.style_button(add_btn, 20)
	var filter_hint := "support" if list_key == "supports" else ""
	add_btn.pressed.connect(func():
		_dismiss_overlay()
		_pending_card_target = list_key
		_pending_list_side = side
		_open_card_search(filter_hint)
	)
	btn_row.add_child(add_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_row.add_child(spacer)

	var done_btn := Button.new()
	done_btn.text = "Done"
	done_btn.custom_minimum_size = Vector2(120, 48)
	UITheme.style_button(done_btn, 20)
	done_btn.pressed.connect(func():
		_dismiss_overlay()
		_refresh_board()
	)
	btn_row.add_child(done_btn)


func _swap_list_items(side: String, key: String, from: int, to: int) -> void:
	var list: Array = _get_side_cfg(side).get(key, [])
	if from < 0 or from >= list.size() or to < 0 or to >= list.size():
		return
	var tmp = list[from]
	list[from] = list[to]
	list[to] = tmp


func _remove_list_item(side: String, key: String, idx: int) -> void:
	var list: Array = _get_side_cfg(side).get(key, [])
	if idx >= 0 and idx < list.size():
		list.remove_at(idx)


func _dismiss_overlay() -> void:
	if _active_overlay != null:
		_active_overlay.queue_free()
		_active_overlay = null


func _show_hover_preview() -> void:
	if _hover_card_data.is_empty():
		return
	_dismiss_hover_preview()

	var preview := CardDisplayComponentScript.new()
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.mouse_filter = MOUSE_FILTER_IGNORE

	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size

	var pos := mouse_pos + Vector2(20, -PREVIEW_SIZE.y * 0.5)
	pos.x = clampf(pos.x, 0, viewport_size.x - PREVIEW_SIZE.x)
	pos.y = clampf(pos.y, 0, viewport_size.y - PREVIEW_SIZE.y)

	if pos.x < mouse_pos.x + 20 and pos.x + PREVIEW_SIZE.x > mouse_pos.x:
		pos.x = mouse_pos.x - PREVIEW_SIZE.x - 20
		pos.x = maxf(pos.x, 0)

	preview.position = pos
	preview.size = PREVIEW_SIZE
	preview.z_index = 80

	var cd := _hover_card_data
	add_child(preview)
	preview.set_card(cd)

	_hover_preview = preview


func _dismiss_hover_preview() -> void:
	if _hover_preview != null:
		_hover_preview.queue_free()
		_hover_preview = null


func _get_side_cfg(side: String) -> Dictionary:
	return _config.get(side, {})


func _on_save() -> void:
	_sync_config_from_ui()
	var validation := PuzzleConfigScript.validate_config(_config)
	if not bool(validation.get("valid", false)):
		_show_error_popup("Save failed", validation.get("errors", []))
		return
	var code := PuzzleCodecScript.encode(_config)
	var puzzle_name := str(_config.get("name", "")).strip_edges()

	# Check for existing puzzle with same name
	var existing_id := ""
	for entry in PuzzlePersistenceScript.list_puzzles():
		if str(entry.get("name", "")) == puzzle_name:
			existing_id = str(entry.get("id", ""))
			break

	if existing_id.is_empty():
		PuzzlePersistenceScript.add_puzzle(puzzle_name, code)
		_show_success_popup("Puzzle '%s' saved." % puzzle_name)
	else:
		_show_overwrite_confirm(puzzle_name, code, existing_id)


func _on_export() -> void:
	_sync_config_from_ui()
	var validation := PuzzleConfigScript.validate_config(_config)
	if not bool(validation.get("valid", false)):
		_show_error_popup("Export failed", validation.get("errors", []))
		return
	var code := PuzzleCodecScript.encode(_config)
	DisplayServer.clipboard_set(code)
	_status_label.text = "Puzzle code copied to clipboard! (%d chars)" % code.length()


func _on_play() -> void:
	_sync_config_from_ui()
	var play_config := _config.duplicate(true)
	if str(play_config.get("name", "")).strip_edges().is_empty():
		play_config["name"] = "Untitled Puzzle"
	var validation := PuzzleConfigScript.validate_config(play_config)
	if not bool(validation.get("valid", false)):
		_show_error_popup("Cannot play", validation.get("errors", []))
		return
	play_requested.emit(play_config)


func _show_overwrite_confirm(puzzle_name: String, code: String, existing_id: String) -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 75
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.6)
	overlay.add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(450, 0)
	UITheme.style_panel(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var msg := Label.new()
	msg.text = "A puzzle named '%s' already exists.\nOverwrite it?" % puzzle_name
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

	var overwrite_btn := Button.new()
	overwrite_btn.text = "Overwrite"
	overwrite_btn.custom_minimum_size = Vector2(120, 48)
	UITheme.style_button_accent(overwrite_btn, Color(0.8, 0.3, 0.3), 20)
	overwrite_btn.pressed.connect(func():
		PuzzlePersistenceScript.delete_puzzle(existing_id)
		PuzzlePersistenceScript.add_puzzle(puzzle_name, code)
		overlay.queue_free()
		_show_success_popup("Puzzle '%s' saved (overwritten)." % puzzle_name)
	)
	btn_row.add_child(overwrite_btn)


func _show_success_popup(message: String) -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 75
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.6)
	overlay.add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 0)
	UITheme.style_panel(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var msg := Label.new()
	msg.text = message
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "Okay"
	ok_btn.custom_minimum_size = Vector2(120, 48)
	UITheme.style_button(ok_btn, 20)
	ok_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(ok_btn)


func _show_error_popup(title_text: String, errors: Array) -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 75
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.6)
	overlay.add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(450, 0)
	UITheme.style_panel(card, Color(0.8, 0.3, 0.3, 0.5))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(title)

	for err in errors:
		var err_label := Label.new()
		err_label.text = "• %s" % str(err)
		err_label.add_theme_font_size_override("font_size", 18)
		err_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
		err_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(err_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(120, 48)
	UITheme.style_button(ok_btn, 20)
	ok_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(ok_btn)


func _sync_config_from_ui() -> void:
	_config["name"] = _name_input.text
	_config["type"] = "survive" if _type_toggle.button_pressed else "kill"


func _sync_ui_from_config() -> void:
	if _name_input != null:
		_name_input.text = str(_config.get("name", ""))
	if _type_toggle != null:
		_type_toggle.button_pressed = str(_config.get("type", "kill")) == "survive"
	if _left_lane_width_spin != null and _config.has("lanes"):
		var lanes: Array = _config.get("lanes", [])
		if lanes.size() >= 2:
			_left_lane_width_spin.value = int(lanes[0].get("width", 4))
			_right_lane_width_label.text = str(int(lanes[1].get("width", 4)))
			_select_lane_dropdown(_left_lane_type_dropdown, str(lanes[0].get("lane_type", "field")))
			_select_lane_dropdown(_right_lane_type_dropdown, str(lanes[1].get("lane_type", "shadow")))
	var p_cfg: Dictionary = _config.get("player", {})
	var e_cfg: Dictionary = _config.get("enemy", {})
	if _player_health_spin != null:
		_player_health_spin.value = int(p_cfg.get("health", 30))
	if _enemy_health_spin != null:
		_enemy_health_spin.value = int(e_cfg.get("health", 30))
	if _player_magicka_input != null:
		_player_magicka_input.text = str(int(p_cfg.get("max_magicka", 12)))
	if _enemy_magicka_input != null:
		_enemy_magicka_input.text = str(int(e_cfg.get("max_magicka", 3)))
	if _ring_check != null:
		_ring_check.button_pressed = bool(p_cfg.get("has_ring", false))


func _populate_lane_dropdown(dropdown: OptionButton) -> void:
	dropdown.clear()
	for lt in _lane_types:
		var lt_id := str(lt.get("id", ""))
		if not lt_id.is_empty():
			dropdown.add_item(lt_id)


func _select_lane_dropdown(dropdown: OptionButton, lane_id: String) -> void:
	for i in range(dropdown.get_item_count()):
		if dropdown.get_item_text(i) == lane_id:
			dropdown.select(i)
			return


# -- Import dialog --

func _build_import_dialog() -> void:
	_import_dialog = PanelContainer.new()
	_import_dialog.visible = false
	_import_dialog.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_import_dialog.z_index = 70
	_import_dialog.mouse_filter = MOUSE_FILTER_STOP
	add_child(_import_dialog)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.6)
	_import_dialog.add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_import_dialog.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 280)
	UITheme.style_panel(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "Import Puzzle Code"
	UITheme.style_title(title, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(title)

	_import_input = TextEdit.new()
	_import_input.placeholder_text = "Paste puzzle code here..."
	_import_input.size_flags_vertical = SIZE_EXPAND_FILL
	_import_input.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(_import_input)

	_import_error_label = Label.new()
	_import_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_import_error_label.visible = false
	vbox.add_child(_import_error_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(110, 48)
	UITheme.style_button(cancel_btn, 20, true)
	cancel_btn.pressed.connect(func(): _import_dialog.visible = false)
	btn_row.add_child(cancel_btn)

	var ok_btn := Button.new()
	ok_btn.text = "Import"
	ok_btn.custom_minimum_size = Vector2(110, 48)
	UITheme.style_button(ok_btn, 20)
	ok_btn.pressed.connect(_on_import_confirmed)
	btn_row.add_child(ok_btn)


func _show_import_dialog() -> void:
	_import_input.text = ""
	_import_error_label.visible = false
	_import_dialog.visible = true


func _on_import_confirmed() -> void:
	var code := _import_input.text.strip_edges()
	if code.is_empty():
		_import_error_label.text = "Paste a puzzle code first."
		_import_error_label.visible = true
		return
	var result := PuzzleCodecScript.decode(code)
	var error := str(result.get("error", ""))
	if not error.is_empty():
		_import_error_label.text = error
		_import_error_label.visible = true
		return
	_config = result.get("config", {}).duplicate(true)
	_import_dialog.visible = false
	_sync_ui_from_config()
	_refresh_board()
	_status_label.text = "Puzzle imported successfully."


# -- Helpers --

func _labeled(text: String, control: Control, is_spin: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = text
	UITheme.style_section_label(lbl, 24)
	row.add_child(lbl)
	row.add_child(control)
	return row


func _make_spin(min_val: int, max_val: int, default_val: int, on_change: Callable) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = default_val
	spin.custom_minimum_size = Vector2(110, 48)
	UITheme.style_spin_box(spin, 22)
	spin.value_changed.connect(on_change)
	return spin


func _make_magicka_input(default_text: String, on_change: Callable) -> LineEdit:
	var input := LineEdit.new()
	input.text = default_text
	input.custom_minimum_size = Vector2(90, 48)
	input.add_theme_font_size_override("font_size", 22)
	input.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = UITheme.BTN_BG
	input_style.border_color = UITheme.GOLD_DIM
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(4)
	input_style.set_content_margin_all(8)
	input.add_theme_stylebox_override("normal", input_style)
	var input_focus := StyleBoxFlat.new()
	input_focus.bg_color = UITheme.BTN_BG_HOVER
	input_focus.border_color = UITheme.GOLD
	input_focus.set_border_width_all(2)
	input_focus.set_corner_radius_all(4)
	input_focus.set_content_margin_all(8)
	input.add_theme_stylebox_override("focus", input_focus)
	input.add_theme_color_override("caret_color", UITheme.GOLD)
	input.text_changed.connect(on_change)
	return input


func _parse_int(text: String, fallback: int) -> int:
	if text.is_valid_int():
		return int(text)
	return fallback
