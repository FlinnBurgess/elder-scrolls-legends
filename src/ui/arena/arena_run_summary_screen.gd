class_name ArenaRunSummaryScreen
extends Control

signal return_pressed

var _is_built := false
var _wins: int = 0
var _losses: int = 0
var _wins_label: Label
var _losses_label: Label
var _title_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


func set_run_result(wins: int, losses: int) -> void:
	_wins = wins
	_losses = losses
	_refresh()


func _refresh() -> void:
	if not _is_built:
		return
	_wins_label.text = "Wins: %d" % _wins
	_losses_label.text = "Losses: %d" % _losses
	if _wins >= 9:
		_title_label.text = "Arena Champion!"
		_title_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38, 1.0))
	else:
		_title_label.text = "Run Complete"
		_title_label.add_theme_color_override("font_color", Color.WHITE)


func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 280)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Run Complete"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)

	# Win/Loss record
	var record_row := HBoxContainer.new()
	record_row.alignment = BoxContainer.ALIGNMENT_CENTER
	record_row.add_theme_constant_override("separation", 32)
	vbox.add_child(record_row)

	_wins_label = Label.new()
	_wins_label.text = "Wins: 0"
	_wins_label.add_theme_font_size_override("font_size", 24)
	_wins_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
	record_row.add_child(_wins_label)

	_losses_label = Label.new()
	_losses_label.text = "Losses: 0"
	_losses_label.add_theme_font_size_override("font_size", 24)
	_losses_label.add_theme_color_override("font_color", Color(0.84, 0.39, 0.31, 1.0))
	record_row.add_child(_losses_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Return button
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var return_button := Button.new()
	return_button.text = "Return to Main Menu"
	return_button.custom_minimum_size = Vector2(240, 48)
	return_button.pressed.connect(func() -> void: return_pressed.emit())
	btn_row.add_child(return_button)
