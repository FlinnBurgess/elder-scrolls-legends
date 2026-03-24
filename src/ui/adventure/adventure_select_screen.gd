class_name AdventureSelectScreen
extends Control

signal adventure_selected(adventure: Dictionary)
signal back_pressed

var _adventures: Array = []
var _adventure_buttons: Array = []
var _selected_index := -1
var _start_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func set_adventures(adventures: Array) -> void:
	_adventures = adventures
	_build_ui()


func _build_ui() -> void:
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(400, 0)
	center.set_anchors_and_offsets_preset(PRESET_CENTER)
	center.grow_horizontal = GROW_DIRECTION_BOTH
	center.grow_vertical = GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 12)
	add_child(center)

	var title := Label.new()
	title.text = "Choose Your Adventure"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	center.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	for i in range(_adventures.size()):
		var adventure: Dictionary = _adventures[i]
		var btn := Button.new()
		btn.text = str(adventure.get("name", "Unknown Adventure"))
		btn.custom_minimum_size = Vector2(400, 48)
		btn.pressed.connect(_on_adventure_clicked.bind(i))
		center.add_child(btn)
		_adventure_buttons.append(btn)

	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(0, 12)
	center.add_child(btn_spacer)

	_start_button = Button.new()
	_start_button.text = "Begin Adventure"
	_start_button.custom_minimum_size = Vector2(400, 52)
	_start_button.disabled = true
	_start_button.pressed.connect(_on_start_pressed)
	center.add_child(_start_button)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(400, 44)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	center.add_child(back_btn)


func _on_adventure_clicked(index: int) -> void:
	_selected_index = index
	_start_button.disabled = false
	for i in range(_adventure_buttons.size()):
		var btn: Button = _adventure_buttons[i]
		if i == index:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.65, 1.0)
			style.border_color = Color(0.4, 0.65, 0.9, 1.0)
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", style)
		else:
			btn.remove_theme_stylebox_override("normal")


func _on_start_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _adventures.size():
		return
	adventure_selected.emit(_adventures[_selected_index])
