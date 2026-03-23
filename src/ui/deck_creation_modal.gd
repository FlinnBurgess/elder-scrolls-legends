class_name DeckCreationModal
extends Control

const DECK_REGISTRY_PATH := "res://data/legends/registries/attribute_class_registry.json"
const ATTRIBUTE_IDS := ["strength", "intelligence", "willpower", "agility", "endurance"]
const MAX_ATTRIBUTES := 3

signal confirmed(deck_name: String, attribute_ids: Array)
signal cancelled

var _attribute_display_names := {}
var _selected_attributes: Array[String] = []
var _attribute_buttons := {}
var _name_input: LineEdit
var _confirm_button: Button
var _is_built := false
var _name_only_mode := false
var _title_label: Label
var _attr_label: Label
var _attr_row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_attribute_labels()
	_build_ui()


func _load_attribute_labels() -> void:
	var file := FileAccess.open(DECK_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for raw_attribute in parsed.get("attributes", []):
		if typeof(raw_attribute) != TYPE_DICTIONARY:
			continue
		var attribute: Dictionary = raw_attribute
		_attribute_display_names[str(attribute.get("id", ""))] = str(attribute.get("display_name", attribute.get("id", "")))


func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

	# Semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	add_child(backdrop)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	# Modal panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
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

	# Title
	_title_label = Label.new()
	_title_label.text = "Create New Deck"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Deck name input
	var name_label := Label.new()
	name_label.text = "Deck Name"
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter deck name..."
	_name_input.add_theme_font_size_override("font_size", 16)
	_name_input.text_changed.connect(_on_name_changed)
	vbox.add_child(_name_input)

	# Attribute selection
	_attr_label = Label.new()
	_attr_label.text = "Select Attributes (1-3)"
	_attr_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_attr_label)

	_attr_row = HBoxContainer.new()
	_attr_row.add_theme_constant_override("separation", 8)
	_attr_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_attr_row)

	for attribute_id in ATTRIBUTE_IDS:
		var button := Button.new()
		button.toggle_mode = true
		button.text = _attribute_display_names.get(attribute_id, attribute_id.capitalize())
		button.custom_minimum_size = Vector2(90, 36)
		button.add_theme_font_size_override("font_size", 13)
		button.toggled.connect(_on_attribute_toggled.bind(attribute_id))
		_attr_row.add_child(button)
		_attribute_buttons[attribute_id] = button

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Button row
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 36)
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_row.add_child(cancel_button)

	_confirm_button = Button.new()
	_confirm_button.text = "Create"
	_confirm_button.custom_minimum_size = Vector2(100, 36)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	button_row.add_child(_confirm_button)


func set_name_only_mode(title_text: String) -> void:
	_name_only_mode = true
	_attr_label.visible = false
	_attr_row.visible = false
	_title_label.text = title_text
	_confirm_button.text = "Import"
	_update_button_states()


func set_edit_mode(deck_name: String, attribute_ids: Array) -> void:
	_name_input.text = deck_name
	_selected_attributes.clear()
	for attr_id in attribute_ids:
		var id_str := str(attr_id)
		_selected_attributes.append(id_str)
		if _attribute_buttons.has(id_str):
			_attribute_buttons[id_str].button_pressed = true
	_update_button_states()


func _on_name_changed(_new_text: String) -> void:
	_update_button_states()


func _on_attribute_toggled(pressed: bool, attribute_id: String) -> void:
	if pressed:
		if not _selected_attributes.has(attribute_id):
			_selected_attributes.append(attribute_id)
	else:
		_selected_attributes.erase(attribute_id)
	_update_button_states()


func _update_button_states() -> void:
	# Disable unselected attribute buttons when at max
	var at_max := _selected_attributes.size() >= MAX_ATTRIBUTES
	for attribute_id in ATTRIBUTE_IDS:
		var button: Button = _attribute_buttons[attribute_id]
		if not button.button_pressed:
			button.disabled = at_max

	# Enable confirm only when name is non-empty (and at least 1 attribute selected, unless name-only mode)
	var has_name := _name_input.text.strip_edges().length() > 0
	var has_attributes := _name_only_mode or _selected_attributes.size() > 0
	_confirm_button.disabled = not (has_name and has_attributes)


func _on_confirm_pressed() -> void:
	var deck_name := _name_input.text.strip_edges()
	confirmed.emit(deck_name, _selected_attributes.duplicate())


func _on_cancel_pressed() -> void:
	cancelled.emit()
