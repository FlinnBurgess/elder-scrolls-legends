class_name CreatureAugmentNodeOverlay
extends Control

signal augment_selected(card_id: String, augment_id: String)
signal reroll_requested

const CardDisplayComponentScript = preload("res://src/ui/components/CardDisplayComponent.gd")

const CARD_SIZE := Vector2(220, 384)

var _creatures: Array = []  # Array of card dicts
var _augments: Array = []  # Array of augment dicts
var _reroll_tokens: int = 0
var _selected_creature_id: String = ""
var _selected_augment_id: String = ""
var _creature_buttons: Array = []  # Array of {button: Button, card_id: String}
var _augment_buttons: Array = []  # Array of {button: Button, augment_id: String}
var _apply_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_data(creatures: Array, augments: Array, reroll_tokens: int = 0) -> void:
	_creatures = creatures
	_augments = augments
	_reroll_tokens = reroll_tokens
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_creature_buttons.clear()
	_augment_buttons.clear()
	_selected_creature_id = ""
	_selected_augment_id = ""

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.1, 0.12, 0.95)
	panel_style.border_color = Color(0.3, 0.75, 0.7, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Augment a Creature"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Creatures row
	var creature_label := Label.new()
	creature_label.text = "Choose a Creature"
	creature_label.add_theme_font_size_override("font_size", 18)
	creature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(creature_label)

	var creature_row := HBoxContainer.new()
	creature_row.add_theme_constant_override("separation", 12)
	creature_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(creature_row)

	for card in _creatures:
		creature_row.add_child(_build_creature_option(card))

	# Augments row
	var augment_label := Label.new()
	augment_label.text = "Choose an Augment"
	augment_label.add_theme_font_size_override("font_size", 18)
	augment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(augment_label)

	var augment_row := HBoxContainer.new()
	augment_row.add_theme_constant_override("separation", 12)
	augment_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(augment_row)

	for augment in _augments:
		augment_row.add_child(_build_augment_option(augment))

	# Bottom buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll (%d)" % _reroll_tokens
	reroll_btn.custom_minimum_size = Vector2(140, 44)
	reroll_btn.disabled = _reroll_tokens <= 0
	reroll_btn.pressed.connect(func() -> void: reroll_requested.emit())
	btn_row.add_child(reroll_btn)

	_apply_btn = Button.new()
	_apply_btn.text = "Apply"
	_apply_btn.custom_minimum_size = Vector2(140, 44)
	_apply_btn.disabled = true
	_apply_btn.pressed.connect(func() -> void:
		if not _selected_creature_id.is_empty() and not _selected_augment_id.is_empty():
			augment_selected.emit(_selected_creature_id, _selected_augment_id)
	)
	btn_row.add_child(_apply_btn)


func _build_creature_option(card: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)

	var display := CardDisplayComponentScript.new()
	display.custom_minimum_size = CARD_SIZE
	container.add_child(display)
	display.ready.connect(func() -> void: display.set_card(card))

	var card_id := str(card.get("card_id", ""))
	var btn := Button.new()
	btn.text = "Select"
	btn.custom_minimum_size = Vector2(140, 36)
	btn.pressed.connect(func() -> void: _select_creature(card_id))
	container.add_child(btn)

	_creature_buttons.append({"button": btn, "card_id": card_id})
	return container


func _build_augment_option(augment: Dictionary) -> Control:
	var augment_id := str(augment.get("id", ""))
	var aug_name := str(augment.get("name", augment_id))
	var aug_desc := str(augment.get("description", ""))

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 100)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	style.border_color = Color(0.3, 0.6, 0.6, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 4)
	panel.add_child(text_vbox)

	var name_label := Label.new()
	name_label.text = aug_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.modulate = Color(0.3, 0.9, 0.8, 1.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = aug_desc
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(desc_label)

	container.add_child(panel)

	var btn := Button.new()
	btn.text = "Select"
	btn.custom_minimum_size = Vector2(140, 36)
	btn.pressed.connect(func() -> void: _select_augment(augment_id))
	container.add_child(btn)

	_augment_buttons.append({"button": btn, "augment_id": augment_id})
	return container


func _select_creature(card_id: String) -> void:
	_selected_creature_id = card_id
	for entry in _creature_buttons:
		var btn: Button = entry["button"]
		btn.text = "Selected" if str(entry["card_id"]) == card_id else "Select"
	_update_apply_button()


func _select_augment(augment_id: String) -> void:
	_selected_augment_id = augment_id
	for entry in _augment_buttons:
		var btn: Button = entry["button"]
		btn.text = "Selected" if str(entry["augment_id"]) == augment_id else "Select"
	_update_apply_button()


func _update_apply_button() -> void:
	if _apply_btn != null:
		_apply_btn.disabled = _selected_creature_id.is_empty() or _selected_augment_id.is_empty()
