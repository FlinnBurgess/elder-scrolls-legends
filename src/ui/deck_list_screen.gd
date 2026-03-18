class_name DeckListScreen
extends Control

const DeckPersistenceClass = preload("res://src/deck/deck_persistence.gd")
const DeckCreationModalClass = preload("res://src/ui/deck_creation_modal.gd")

signal edit_deck_requested(deck_name: String)

var _deck_list_container: VBoxContainer
var _create_button: Button
var _is_built := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	refresh()


func refresh() -> void:
	_clear_children(_deck_list_container)
	var deck_names: Array[String] = DeckPersistenceClass.list_decks()
	for deck_name in deck_names:
		_deck_list_container.add_child(_build_deck_row(deck_name))
	if deck_names.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No decks yet. Create one to get started!"
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_deck_list_container.add_child(empty_label)


func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	# Title
	var title := Label.new()
	title.text = "My Decks"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# Create New Deck button
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(button_row)

	_create_button = Button.new()
	_create_button.text = "Create New Deck"
	_create_button.custom_minimum_size = Vector2(200, 44)
	_create_button.add_theme_font_size_override("font_size", 16)
	_create_button.pressed.connect(_on_create_pressed)
	button_row.add_child(_create_button)

	# Scrollable deck list
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(scroll)

	_deck_list_container = VBoxContainer.new()
	_deck_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_deck_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_deck_list_container)


func _build_deck_row(deck_name: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	# Deck name button (clickable to edit)
	var name_button := Button.new()
	name_button.text = deck_name
	name_button.size_flags_horizontal = SIZE_EXPAND_FILL
	name_button.custom_minimum_size = Vector2(0, 40)
	name_button.add_theme_font_size_override("font_size", 16)
	name_button.pressed.connect(_on_deck_selected.bind(deck_name))
	row.add_child(name_button)

	# Delete button
	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(80, 40)
	delete_button.add_theme_font_size_override("font_size", 14)
	delete_button.pressed.connect(_on_delete_pressed.bind(deck_name))
	row.add_child(delete_button)

	return row


func _on_create_pressed() -> void:
	var modal := DeckCreationModalClass.new()
	modal.confirmed.connect(_on_create_confirmed.bind(modal))
	modal.cancelled.connect(_on_modal_cancelled.bind(modal))
	add_child(modal)


func _on_create_confirmed(deck_name: String, attribute_ids: Array, modal: Control) -> void:
	modal.queue_free()
	var definition := {
		"name": deck_name,
		"attribute_ids": attribute_ids,
		"cards": [],
	}
	DeckPersistenceClass.save_deck(deck_name, definition)
	edit_deck_requested.emit(deck_name)


func _on_modal_cancelled(modal: Control) -> void:
	modal.queue_free()


func _on_deck_selected(deck_name: String) -> void:
	edit_deck_requested.emit(deck_name)


func _on_delete_pressed(deck_name: String) -> void:
	var dialog := _build_confirm_dialog(deck_name)
	add_child(dialog)


func _build_confirm_dialog(deck_name: String) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	overlay.add_child(backdrop)

	# Center
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)

	# Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 180)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "Delete deck \"%s\"?" % deck_name
	msg.add_theme_font_size_override("font_size", 18)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.pressed.connect(overlay.queue_free)
	button_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Delete"
	confirm_btn.custom_minimum_size = Vector2(100, 36)
	confirm_btn.pressed.connect(_on_delete_confirmed.bind(deck_name, overlay))
	button_row.add_child(confirm_btn)

	return overlay


func _on_delete_confirmed(deck_name: String, dialog: Control) -> void:
	dialog.queue_free()
	DeckPersistenceClass.delete_deck(deck_name)
	refresh()


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
