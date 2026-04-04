class_name PuzzleSelectScreen
extends Control

signal puzzle_selected(puzzle_entry: Dictionary)
signal builder_requested
signal edit_requested(config: Dictionary)
signal back_requested

const PuzzleCodecScript = preload("res://src/puzzle/puzzle_codec.gd")
const PuzzlePersistenceScript = preload("res://src/puzzle/puzzle_persistence.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")

var _custom_list_container: VBoxContainer
var _custom_section_body: VBoxContainer
var _import_dialog: PanelContainer
var _import_input: TextEdit
var _import_error_label: Label


func _ready() -> void:
	_build_ui()


func refresh() -> void:
	# Clear all sections and rebuild so pack solved status updates
	for child in _custom_list_container.get_children():
		child.queue_free()
	_build_puzzle_pack_sections()
	_build_custom_puzzles_section()


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
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(120, 56)
	UITheme.style_button(back_button, 22, true)
	back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Puzzles"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	UITheme.style_title(title, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	root.add_child(UITheme.make_separator(0.0))

	# Scrollable puzzle list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	root.add_child(scroll)

	_custom_list_container = VBoxContainer.new()
	_custom_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_custom_list_container.add_theme_constant_override("separation", 20)
	scroll.add_child(_custom_list_container)

	# Build sections — puzzle packs first, then custom
	_build_puzzle_pack_sections()
	_build_custom_puzzles_section()

	# Bottom action buttons
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 16)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom_row)

	var import_btn := Button.new()
	import_btn.text = "Import Puzzle"
	import_btn.custom_minimum_size = Vector2(240, 60)
	UITheme.style_button(import_btn, 22)
	import_btn.pressed.connect(_show_import_dialog)
	bottom_row.add_child(import_btn)

	var builder_btn := Button.new()
	builder_btn.text = "Create Puzzle"
	builder_btn.custom_minimum_size = Vector2(240, 60)
	UITheme.style_button(builder_btn, 22)
	builder_btn.pressed.connect(func(): builder_requested.emit())
	bottom_row.add_child(builder_btn)

	# Import dialog (hidden by default)
	_build_import_dialog()


func _build_puzzle_pack_sections() -> void:
	var packs_dir := "res://data/puzzle_packs"
	var dir := DirAccess.open(packs_dir)
	if dir == null:
		return
	var folders: Array[String] = []
	dir.list_dir_begin()
	var folder := dir.get_next()
	while not folder.is_empty():
		if dir.current_is_dir() and not folder.begins_with("."):
			folders.append(folder)
		folder = dir.get_next()
	dir.list_dir_end()
	var pack_entries: Array[Dictionary] = []
	for f in folders:
		var index_path := packs_dir.path_join(f).path_join("index.json")
		var file := FileAccess.open(index_path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		pack_entries.append({"path": packs_dir.path_join(f), "order": int(parsed.get("order", 999)), "parsed": parsed})
	pack_entries.sort_custom(func(a, b): return a["order"] < b["order"])
	for entry in pack_entries:
		_build_pack_section_from_data(entry["path"], entry["parsed"])


func _build_pack_section_from_data(pack_path: String, parsed: Dictionary) -> void:
	var pack_name := str(parsed.get("display_name", "Puzzle Pack"))
	var puzzles: Array = parsed.get("puzzles", [])
	if puzzles.is_empty():
		return

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	_custom_list_container.add_child(section)

	var header_btn := Button.new()
	header_btn.text = pack_name
	header_btn.custom_minimum_size = Vector2(0, 60)
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITheme.style_button(header_btn, 26)
	section.add_child(header_btn)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	section.add_child(grid)

	header_btn.pressed.connect(func(): grid.visible = not grid.visible)

	for entry in puzzles:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var puzzle_id := str(entry.get("id", ""))
		var puzzle_name := str(entry.get("name", "Untitled"))
		var puzzle_file := str(entry.get("file", ""))
		if puzzle_file.is_empty():
			continue

		# Load the puzzle config JSON
		var puzzle_path := pack_path.path_join(puzzle_file)
		var puzzle_file_handle := FileAccess.open(puzzle_path, FileAccess.READ)
		if puzzle_file_handle == null:
			continue
		var config = JSON.parse_string(puzzle_file_handle.get_as_text())
		if typeof(config) != TYPE_DICTIONARY:
			continue

		var code := PuzzleCodecScript.encode(config)

		var solved := PuzzlePersistenceScript.is_pack_solved(puzzle_id)
		var btn := Button.new()
		btn.text = puzzle_name
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		if solved:
			UITheme.style_button_accent(btn, Color(0.4, 0.75, 0.4), 20)
		else:
			UITheme.style_button(btn, 20)
		var puzzle_entry := {"id": puzzle_id, "name": puzzle_name, "code": code, "solved": solved}
		btn.pressed.connect(func(): _on_puzzle_clicked(puzzle_entry))

		grid.add_child(btn)


func _build_custom_puzzles_section() -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	_custom_list_container.add_child(section)

	# Section header (expandable)
	var header_btn := Button.new()
	header_btn.text = "Custom Puzzles"
	header_btn.custom_minimum_size = Vector2(0, 60)
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITheme.style_button(header_btn, 26)
	section.add_child(header_btn)

	_custom_section_body = VBoxContainer.new()
	_custom_section_body.add_theme_constant_override("separation", 6)
	section.add_child(_custom_section_body)

	header_btn.pressed.connect(func(): _custom_section_body.visible = not _custom_section_body.visible)

	_refresh_custom_puzzles()


func _refresh_custom_puzzles() -> void:
	for child in _custom_section_body.get_children():
		child.queue_free()

	var puzzles: Array = PuzzlePersistenceScript.list_puzzles()
	for entry in puzzles:
		_add_puzzle_row(entry)

	if puzzles.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No custom puzzles yet"
		empty_label.add_theme_font_size_override("font_size", 20)
		empty_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		_custom_section_body.add_child(empty_label)


func _add_puzzle_row(entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 52)

	# Solved indicator
	var solved := bool(entry.get("solved", false))
	var indicator := Label.new()
	indicator.text = "+" if solved else " "
	indicator.add_theme_font_size_override("font_size", 24)
	indicator.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if solved else Color(0.3, 0.3, 0.3))
	indicator.custom_minimum_size = Vector2(30, 0)
	row.add_child(indicator)

	# Name button (clickable to play)
	var name_btn := Button.new()
	name_btn.text = str(entry.get("name", "Untitled"))
	name_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.custom_minimum_size = Vector2(0, 52)
	UITheme.style_button(name_btn, 22)
	var entry_copy := entry.duplicate()
	name_btn.pressed.connect(func(): _on_puzzle_clicked(entry_copy))
	row.add_child(name_btn)

	# Edit button
	var edit_btn := Button.new()
	edit_btn.text = "Edit"
	edit_btn.custom_minimum_size = Vector2(90, 52)
	UITheme.style_button(edit_btn, 20)
	var code_for_edit := str(entry.get("code", ""))
	edit_btn.pressed.connect(func(): _on_edit_puzzle(code_for_edit))
	row.add_child(edit_btn)

	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "X"
	delete_btn.custom_minimum_size = Vector2(52, 52)
	UITheme.style_button_accent(delete_btn, Color(0.8, 0.3, 0.3), 20)
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
	card.custom_minimum_size = Vector2(600, 350)
	UITheme.style_panel(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 24)
	card_margin.add_theme_constant_override("margin_right", 24)
	card_margin.add_theme_constant_override("margin_top", 24)
	card_margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(card_margin)
	card_margin.add_child(vbox)

	var import_title := Label.new()
	import_title.text = "Import Puzzle Code"
	UITheme.style_title(import_title, 28)
	import_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(import_title)

	_import_input = TextEdit.new()
	_import_input.placeholder_text = "Paste puzzle code here..."
	_import_input.size_flags_vertical = SIZE_EXPAND_FILL
	_import_input.custom_minimum_size = Vector2(0, 140)
	_import_input.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_import_input)

	_import_error_label = Label.new()
	_import_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	_import_error_label.add_theme_font_size_override("font_size", 18)
	_import_error_label.visible = false
	vbox.add_child(_import_error_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button(cancel_btn, 22, true)
	cancel_btn.pressed.connect(_dismiss_import_dialog)
	btn_row.add_child(cancel_btn)

	var import_btn := Button.new()
	import_btn.text = "Import"
	import_btn.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button(import_btn, 22)
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
