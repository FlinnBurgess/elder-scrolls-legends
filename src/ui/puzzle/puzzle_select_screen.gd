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
	bg.color = Color(0.08, 0.09, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

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
	back_button.add_theme_font_size_override("font_size", 24)
	_apply_button_style(back_button, Color(0.18, 0.19, 0.24), Color(0.4, 0.4, 0.45))
	back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Puzzles"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)

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
	import_btn.custom_minimum_size = Vector2(220, 56)
	import_btn.add_theme_font_size_override("font_size", 22)
	_apply_button_style(import_btn, Color(0.15, 0.17, 0.22), Color(0.4, 0.45, 0.55))
	import_btn.pressed.connect(_show_import_dialog)
	bottom_row.add_child(import_btn)

	var builder_btn := Button.new()
	builder_btn.text = "Create Puzzle"
	builder_btn.custom_minimum_size = Vector2(220, 56)
	builder_btn.add_theme_font_size_override("font_size", 22)
	_apply_button_style(builder_btn, Color(0.15, 0.17, 0.22), Color(0.4, 0.45, 0.55))
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
	header_btn.add_theme_font_size_override("font_size", 28)
	header_btn.custom_minimum_size = Vector2(0, 60)
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_button_style(header_btn, Color(0.14, 0.15, 0.2), Color(0.35, 0.4, 0.55))
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
		btn.add_theme_font_size_override("font_size", 20)
		if solved:
			_apply_button_style(btn, Color(0.1, 0.16, 0.1), Color(0.35, 0.6, 0.35))
		else:
			_apply_button_style(btn, Color(0.12, 0.13, 0.18), Color(0.3, 0.32, 0.4))
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
	header_btn.add_theme_font_size_override("font_size", 28)
	header_btn.custom_minimum_size = Vector2(0, 60)
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_button_style(header_btn, Color(0.14, 0.15, 0.2), Color(0.35, 0.4, 0.55))
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
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
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
	name_btn.add_theme_font_size_override("font_size", 24)
	_apply_button_style(name_btn, Color(0.12, 0.13, 0.18), Color(0.3, 0.32, 0.4))
	var entry_copy := entry.duplicate()
	name_btn.pressed.connect(func(): _on_puzzle_clicked(entry_copy))
	row.add_child(name_btn)

	# Edit button
	var edit_btn := Button.new()
	edit_btn.text = "Edit"
	edit_btn.custom_minimum_size = Vector2(80, 52)
	edit_btn.add_theme_font_size_override("font_size", 22)
	_apply_button_style(edit_btn, Color(0.14, 0.16, 0.22), Color(0.4, 0.5, 0.65))
	var code_for_edit := str(entry.get("code", ""))
	edit_btn.pressed.connect(func(): _on_edit_puzzle(code_for_edit))
	row.add_child(edit_btn)

	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "X"
	delete_btn.custom_minimum_size = Vector2(52, 52)
	delete_btn.add_theme_font_size_override("font_size", 22)
	_apply_button_style(delete_btn, Color(0.2, 0.12, 0.12), Color(0.6, 0.3, 0.3))
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
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.11, 0.16, 0.98)
	card_style.border_color = Color(0.5, 0.5, 0.55, 0.96)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)
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
	import_title.add_theme_font_size_override("font_size", 26)
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
	cancel_btn.custom_minimum_size = Vector2(130, 48)
	cancel_btn.add_theme_font_size_override("font_size", 22)
	_apply_button_style(cancel_btn, Color(0.18, 0.19, 0.24), Color(0.4, 0.4, 0.45))
	cancel_btn.pressed.connect(_dismiss_import_dialog)
	btn_row.add_child(cancel_btn)

	var import_btn := Button.new()
	import_btn.text = "Import"
	import_btn.custom_minimum_size = Vector2(130, 48)
	import_btn.add_theme_font_size_override("font_size", 22)
	_apply_button_style(import_btn, Color(0.14, 0.18, 0.24), Color(0.35, 0.5, 0.7))
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


func _apply_button_style(btn: Button, bg_color: Color, border_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.border_color = border_color.lightened(0.2)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg_color.lightened(0.25)
	pressed.border_color = border_color.lightened(0.3)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed)
