class_name EventNodeOverlay
extends Control

signal choice_selected(choice_index: int)
signal reroll_requested

var _event_data: Dictionary = {}
var _reroll_tokens: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_data(event_data: Dictionary, reroll_tokens: int = 0) -> void:
	_event_data = event_data
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
	panel_style.bg_color = Color(0.12, 0.1, 0.06, 0.95)
	panel_style.border_color = Color(0.85, 0.65, 0.2, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = str(_event_data.get("headline", "Event"))
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.95, 0.85, 0.4, 1.0)
	vbox.add_child(title)

	# Description
	var desc := Label.new()
	desc.text = str(_event_data.get("description", ""))
	desc.add_theme_font_size_override("font_size", 15)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(400, 0)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	# Choice buttons
	var choices: Array = _event_data.get("choices", [])
	var choices_vbox := VBoxContainer.new()
	choices_vbox.add_theme_constant_override("separation", 12)
	choices_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(choices_vbox)

	for i in range(choices.size()):
		var choice: Dictionary = choices[i] if typeof(choices[i]) == TYPE_DICTIONARY else {}
		var label_text := str(choice.get("label", "Choice %d" % (i + 1)))
		var choice_btn := Button.new()
		choice_btn.text = label_text
		choice_btn.custom_minimum_size = Vector2(350, 48)
		var idx := i
		choice_btn.pressed.connect(func() -> void: choice_selected.emit(idx))
		choices_vbox.add_child(choice_btn)

	# Reroll button
	var btn_center := HBoxContainer.new()
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_center)

	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll (%d)" % _reroll_tokens
	reroll_btn.custom_minimum_size = Vector2(140, 44)
	reroll_btn.disabled = _reroll_tokens <= 0
	reroll_btn.pressed.connect(func() -> void: reroll_requested.emit())
	btn_center.add_child(reroll_btn)
