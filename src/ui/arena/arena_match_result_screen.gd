class_name ArenaMatchResultScreen
extends Control

signal continue_pressed

var _is_built := false
var _is_victory := true
var _result_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


func set_result(is_victory: bool) -> void:
	_is_victory = is_victory
	_refresh()


func _refresh() -> void:
	if not _is_built:
		return
	if _is_victory:
		_result_label.text = "Victory!"
		_result_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
	else:
		_result_label.text = "Defeat"
		_result_label.add_theme_color_override("font_color", Color(0.84, 0.39, 0.31, 1.0))


func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

	# Semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 250)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	panel.add_child(vbox)

	# Spacer to push content to center
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(top_spacer)

	# Result label
	_result_label = Label.new()
	_result_label.text = "Victory!"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 36)
	_result_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
	vbox.add_child(_result_label)

	# Bottom spacer
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(bottom_spacer)

	# Continue button
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(200, 48)
	continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	btn_row.add_child(continue_btn)
