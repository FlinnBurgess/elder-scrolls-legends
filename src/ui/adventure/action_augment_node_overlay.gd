class_name ActionAugmentNodeOverlay
extends Control

signal augment_selected(card_id: String, augment_id: String)
signal reroll_requested

const CardDisplayComponentScript = preload("res://src/ui/components/CardDisplayComponent.gd")

const CARD_SIZE := Vector2(220, 384)

var _pairs: Array = []  # Array of {card: Dictionary, augment: Dictionary}
var _reroll_tokens: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_data(pairs: Array, reroll_tokens: int = 0) -> void:
	_pairs = pairs
	_reroll_tokens = reroll_tokens
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

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
	title.text = "Augment an Action"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Each pair as a row: card on left, augment description + choose button on right
	for pair in _pairs:
		vbox.add_child(_build_pair_row(pair))

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


func _build_pair_row(pair: Dictionary) -> Control:
	var card: Dictionary = pair.get("card", {})
	var augment: Dictionary = pair.get("augment", {})
	var card_id := str(card.get("card_id", ""))
	var augment_id := str(augment.get("id", ""))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Card display (smaller for action augment rows)
	var card_container := Control.new()
	var small_size := Vector2(160, 280)
	card_container.custom_minimum_size = small_size

	var display := CardDisplayComponentScript.new()
	display.custom_minimum_size = small_size
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_container.add_child(display)
	display.ready.connect(func() -> void: display.set_card(card))
	hbox.add_child(card_container)

	# Augment info + choose button
	var aug_panel := PanelContainer.new()
	aug_panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	style.border_color = Color(0.3, 0.6, 0.6, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	aug_panel.add_theme_stylebox_override("panel", style)

	var aug_vbox := VBoxContainer.new()
	aug_vbox.add_theme_constant_override("separation", 8)
	aug_panel.add_child(aug_vbox)

	var aug_name := Label.new()
	aug_name.text = str(augment.get("name", ""))
	aug_name.add_theme_font_size_override("font_size", 16)
	aug_name.modulate = Color(0.3, 0.9, 0.8, 1.0)
	aug_vbox.add_child(aug_name)

	var aug_desc := Label.new()
	aug_desc.text = str(augment.get("description", ""))
	aug_desc.add_theme_font_size_override("font_size", 14)
	aug_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aug_vbox.add_child(aug_desc)

	var choose_btn := Button.new()
	choose_btn.text = "Choose"
	choose_btn.custom_minimum_size = Vector2(120, 40)
	choose_btn.pressed.connect(func() -> void:
		augment_selected.emit(card_id, augment_id)
	)
	aug_vbox.add_child(choose_btn)

	hbox.add_child(aug_panel)
	return hbox
