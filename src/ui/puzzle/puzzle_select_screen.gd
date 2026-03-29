class_name PuzzleSelectScreen
extends Control

signal puzzle_selected(puzzle_entry: Dictionary)
signal builder_requested
signal edit_requested(config: Dictionary)
signal back_requested

const PuzzleCodecScript = preload("res://src/puzzle/puzzle_codec.gd")
const PuzzlePersistenceScript = preload("res://src/puzzle/puzzle_persistence.gd")

var _custom_list_container: VBoxContainer
var _custom_section_body: VBoxContainer
var _import_dialog: PanelContainer
var _import_input: TextEdit
var _import_error_label: Label


func _ready() -> void:
	_build_ui()


func refresh() -> void:
	_refresh_custom_puzzles()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09, 1.0)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(80, 40)
	back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Puzzles"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)

	# Scrollable puzzle list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	root.add_child(scroll)

	_custom_list_container = VBoxContainer.new()
	_custom_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_custom_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_custom_list_container)

	# Build sections
	_build_custom_puzzles_section()

	# Import dialog (hidden by default)
	_build_import_dialog()


func _build_custom_puzzles_section() -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	_custom_list_container.add_child(section)

	# Section header (expandable)
	var header_btn := Button.new()
	header_btn.text = "Custom Puzzles"
	header_btn.add_theme_font_size_override("font_size", 20)
	header_btn.custom_minimum_size = Vector2(0, 44)
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(header_btn)

	_custom_section_body = VBoxContainer.new()
	_custom_section_body.add_theme_constant_override("separation", 4)
	section.add_child(_custom_section_body)

	header_btn.pressed.connect(func(): _custom_section_body.visible = not _custom_section_body.visible)

	_refresh_custom_puzzles()


func _refresh_custom_puzzles() -> void:
	for child in _custom_section_body.get_children():
		child.queue_free()

	# Import button
	var import_btn := Button.new()
	import_btn.text = "Import Puzzle Code"
	import_btn.custom_minimum_size = Vector2(280, 40)
	import_btn.pressed.connect(_show_import_dialog)
	_custom_section_body.add_child(import_btn)

	# Puzzle entries
	var puzzles: Array = PuzzlePersistenceScript.list_puzzles()
	for entry in puzzles:
		_add_puzzle_row(entry)

	# Builder button at bottom
	var builder_btn := Button.new()
	builder_btn.text = "Create Puzzle"
	builder_btn.custom_minimum_size = Vector2(280, 40)
	builder_btn.pressed.connect(func(): builder_requested.emit())
	_custom_section_body.add_child(builder_btn)


func _add_puzzle_row(entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 36)

	# Solved indicator
	var indicator := Label.new()
	indicator.text = "+" if bool(entry.get("solved", false)) else " "
	indicator.add_theme_font_size_override("font_size", 16)
	indicator.custom_minimum_size = Vector2(20, 0)
	row.add_child(indicator)

	# Name button (clickable to play)
	var name_btn := Button.new()
	name_btn.text = str(entry.get("name", "Untitled"))
	name_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.custom_minimum_size = Vector2(0, 36)
	var entry_copy := entry.duplicate()
	name_btn.pressed.connect(func(): _on_puzzle_clicked(entry_copy))
	row.add_child(name_btn)

	# Edit button
	var edit_btn := Button.new()
	edit_btn.text = "Edit"
	edit_btn.custom_minimum_size = Vector2(60, 36)
	var code_for_edit := str(entry.get("code", ""))
	edit_btn.pressed.connect(func(): _on_edit_puzzle(code_for_edit))
	row.add_child(edit_btn)

	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "X"
	delete_btn.custom_minimum_size = Vector2(36, 36)
	var puzzle_id := str(entry.get("id", ""))
	delete_btn.pressed.connect(func(): _on_delete_puzzle(puzzle_id))
	row.add_child(delete_btn)

	_custom_section_body.add_child(row)


func _on_puzzle_clicked(entry: Dictionary) -> void:
	puzzle_selected.emit(entry)


func _on_edit_puzzle(code: String) -> void:
	var result: Dictionary = PuzzleCodecScript.decode(code)
	var error: String = str(result.get("error", ""))
	if not error.is_empty():
		return
	var config: Dictionary = result.get("config", {})
	edit_requested.emit(config)


func _on_delete_puzzle(id: String) -> void:
	PuzzlePersistenceScript.delete_puzzle(id)
	_refresh_custom_puzzles()


func _build_import_dialog() -> void:
	_import_dialog = PanelContainer.new()
	_import_dialog.name = "ImportDialog"
	_import_dialog.visible = false
	_import_dialog.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_import_dialog.z_index = 50
	_import_dialog.mouse_filter = MOUSE_FILTER_STOP
	add_child(_import_dialog)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.05, 0.07, 0.85)
	_import_dialog.add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_import_dialog.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 300)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.11, 0.16, 0.98)
	card_style.border_color = Color(0.5, 0.5, 0.55, 0.96)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 16)
	card_margin.add_theme_constant_override("margin_right", 16)
	card_margin.add_theme_constant_override("margin_top", 16)
	card_margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(card_margin)
	card_margin.add_child(vbox)

	var title := Label.new()
	title.text = "Import Puzzle Code"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_import_input = TextEdit.new()
	_import_input.placeholder_text = "Paste puzzle code here..."
	_import_input.size_flags_vertical = SIZE_EXPAND_FILL
	_import_input.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(_import_input)

	_import_error_label = Label.new()
	_import_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	_import_error_label.add_theme_font_size_override("font_size", 14)
	_import_error_label.visible = false
	vbox.add_child(_import_error_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.pressed.connect(_dismiss_import_dialog)
	btn_row.add_child(cancel_btn)

	var import_btn := Button.new()
	import_btn.text = "Import"
	import_btn.custom_minimum_size = Vector2(100, 36)
	import_btn.pressed.connect(_on_import_confirmed)
	btn_row.add_child(import_btn)


func _show_import_dialog() -> void:
	_import_input.text = ""
	_import_error_label.visible = false
	_import_dialog.visible = true


func _dismiss_import_dialog() -> void:
	_import_dialog.visible = false


func _on_import_confirmed() -> void:
	var code := _import_input.text.strip_edges()
	if code.is_empty():
		_import_error_label.text = "Please paste a puzzle code."
		_import_error_label.visible = true
		return

	var result: Dictionary = PuzzleCodecScript.decode(code)
	var error: String = str(result.get("error", ""))
	if not error.is_empty():
		_import_error_label.text = error
		_import_error_label.visible = true
		return

	var config: Dictionary = result.get("config", {})
	var puzzle_name := str(config.get("name", "Imported Puzzle"))
	if puzzle_name.is_empty():
		puzzle_name = "Imported Puzzle"

	PuzzlePersistenceScript.add_puzzle(puzzle_name, code)
	_dismiss_import_dialog()
	_refresh_custom_puzzles()
