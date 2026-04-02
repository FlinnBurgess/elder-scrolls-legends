class_name DeckListScreen
extends Control

const DeckPersistenceClass = preload("res://src/deck/deck_persistence.gd")
const DeckCreationModalClass = preload("res://src/ui/deck_creation_modal.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")
const DeckCodeClass = preload("res://src/deck/deck_code.gd")
const DeckValidatorClass = preload("res://src/deck/deck_validator.gd")
const DeckEditorScreenClass = preload("res://src/ui/deck_editor_screen.gd")

signal edit_deck_requested(deck_name: String)
signal back_pressed

var _deck_list_container: VBoxContainer
var _create_button: Button
var _is_built := false
var _card_id_to_deck_code := {}
var _deck_code_to_card_id := {}
var _card_by_id := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var catalog_result := CardCatalog.load_default()
	_card_id_to_deck_code = catalog_result.get("card_id_to_deck_code", {})
	_deck_code_to_card_id = catalog_result.get("deck_code_to_card_id", {})
	_card_by_id = catalog_result.get("card_by_id", {})
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

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(500, 0)
	root.add_theme_constant_override("separation", 16)
	center.add_child(root)

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

	var import_button := Button.new()
	import_button.text = "Import Deck"
	import_button.custom_minimum_size = Vector2(200, 44)
	import_button.add_theme_font_size_override("font_size", 16)
	import_button.pressed.connect(_on_import_pressed)
	button_row.add_child(import_button)

	# Scrollable deck list
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	root.add_child(scroll)

	_deck_list_container = VBoxContainer.new()
	_deck_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_deck_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_deck_list_container)

	# Spacer before back button
	var back_spacer := Control.new()
	back_spacer.custom_minimum_size = Vector2(0, 16)
	root.add_child(back_spacer)

	# Back button
	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(0, 44)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	root.add_child(back_button)


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

	# Validation error indicator
	var definition := DeckPersistenceClass.load_deck(deck_name)
	if not definition.is_empty():
		var validation := DeckValidatorClass.validate_deck(definition, _card_by_id)
		var errors: Array = validation.get("errors", [])
		if not errors.is_empty():
			var error_btn := Button.new()
			error_btn.text = "!"
			error_btn.custom_minimum_size = Vector2(40, 40)
			error_btn.add_theme_font_size_override("font_size", 18)
			error_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			var error_style := StyleBoxFlat.new()
			error_style.bg_color = Color(0.7, 0.15, 0.15, 1.0)
			error_style.set_corner_radius_all(6)
			error_style.set_content_margin_all(4)
			error_btn.add_theme_stylebox_override("normal", error_style)
			var hover_style := StyleBoxFlat.new()
			hover_style.bg_color = Color(0.85, 0.2, 0.2, 1.0)
			hover_style.set_corner_radius_all(6)
			hover_style.set_content_margin_all(4)
			error_btn.add_theme_stylebox_override("hover", hover_style)
			error_btn.pressed.connect(_on_validation_error_pressed.bind(deck_name, errors))
			row.add_child(error_btn)

	# Export button
	var export_button := Button.new()
	export_button.text = "Export"
	export_button.custom_minimum_size = Vector2(80, 40)
	export_button.add_theme_font_size_override("font_size", 14)
	export_button.pressed.connect(_on_export_deck_pressed.bind(deck_name, export_button))
	row.add_child(export_button)

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


func _on_export_deck_pressed(deck_name: String, btn: Button) -> void:
	var definition: Dictionary = DeckPersistenceClass.load_deck(deck_name)
	var result: Dictionary = DeckCodeClass.encode(definition, _card_id_to_deck_code)
	if result.get("error", "") != "":
		btn.text = "Error!"
	else:
		DisplayServer.clipboard_set(result.get("code", ""))
		btn.text = "Copied!"
	btn.disabled = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		btn.text = "Export"
		btn.disabled = false
	)


func _on_import_pressed() -> void:
	var clipboard_text := DisplayServer.clipboard_get()
	if clipboard_text.is_empty():
		_show_import_error("Clipboard is empty. Copy a deck code first.")
		return

	var result: Dictionary = DeckCodeClass.decode(clipboard_text.strip_edges(), _deck_code_to_card_id)
	if result.get("error", "") != "":
		_show_import_error(result.get("error", "Unknown error"))
		return

	var cards: Array = result.get("cards", [])
	var unknown: Array = result.get("unknown_codes", [])

	# Infer attributes from the decoded cards
	var attribute_set := {}
	for entry in cards:
		var card: Dictionary = _card_by_id.get(entry.get("card_id", ""), {})
		for attr in card.get("attributes", []):
			attribute_set[attr] = true
	var attribute_ids: Array = attribute_set.keys()
	attribute_ids.sort()

	# Show name-only modal for the imported deck
	var modal := DeckCreationModalClass.new()
	modal.confirmed.connect(_on_import_confirmed.bind(modal, cards, attribute_ids, unknown))
	modal.cancelled.connect(_on_modal_cancelled.bind(modal))
	add_child(modal)
	modal.set_name_only_mode("Import Deck")


func _on_import_confirmed(deck_name: String, _attribute_ids_from_modal: Array, modal: Control, cards: Array, inferred_attribute_ids: Array, unknown_codes: Array) -> void:
	modal.queue_free()
	var definition := {
		"name": deck_name,
		"attribute_ids": inferred_attribute_ids,
		"cards": cards,
	}
	DeckPersistenceClass.save_deck(deck_name, definition)
	if not unknown_codes.is_empty():
		push_warning("Import: %d unknown card codes were skipped: %s" % [unknown_codes.size(), str(unknown_codes)])
	edit_deck_requested.emit(deck_name)


func _show_import_error(message: String) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 150)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.border_color = Color(0.6, 0.3, 0.3, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Import Failed"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	vbox.add_child(title_label)

	var msg_label := Label.new()
	msg_label.text = message
	msg_label.add_theme_font_size_override("font_size", 14)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(100, 36)
	ok_btn.pressed.connect(overlay.queue_free)
	vbox.add_child(ok_btn)

	add_child(overlay)


func _on_validation_error_pressed(deck_name: String, errors: Array) -> void:
	DeckEditorScreenClass.show_validation_errors_overlay(
		self, "Validation Errors: %s" % deck_name, errors, Color(0.7, 0.3, 0.3, 1.0))


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
