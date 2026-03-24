class_name AdventureResultScreen
extends Control

signal return_pressed

var _is_built := false
var _won := false
var _adventure_name := ""
var _title_label: Label
var _subtitle_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


func set_result(won: bool, adventure_name: String) -> void:
	_won = won
	_adventure_name = adventure_name
	_refresh()


func _refresh() -> void:
	if not _is_built:
		return
	if _won:
		_title_label.text = "Victory!"
		_title_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38, 1.0))
	else:
		_title_label.text = "Defeat"
		_title_label.add_theme_color_override("font_color", Color(0.84, 0.39, 0.31, 1.0))
	_subtitle_label.text = _adventure_name


func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

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

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(top_spacer)

	_title_label = Label.new()
	_title_label.text = "Victory!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = ""
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	vbox.add_child(_subtitle_label)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(bottom_spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var return_btn := Button.new()
	return_btn.text = "Return to Main Menu"
	return_btn.custom_minimum_size = Vector2(240, 48)
	return_btn.pressed.connect(func() -> void: return_pressed.emit())
	btn_row.add_child(return_btn)
