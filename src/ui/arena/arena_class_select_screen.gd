class_name ArenaClassSelectScreen
extends Control

signal class_selected(attribute_ids: Array)
signal back_pressed

const REGISTRY_PATH := "res://data/legends/registries/attribute_class_registry.json"
const ArenaRunManagerScript = preload("res://src/arena/arena_run_manager.gd")

const ATTRIBUTE_TINTS := {
	"strength": Color(0.84, 0.39, 0.31, 1.0),
	"intelligence": Color(0.42, 0.62, 0.96, 1.0),
	"willpower": Color(0.92, 0.78, 0.38, 1.0),
	"agility": Color(0.4, 0.76, 0.52, 1.0),
	"endurance": Color(0.58, 0.46, 0.72, 1.0),
}

var _is_built := false
var _class_options: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_class_options()
	_build_ui()


func _load_class_options() -> void:
	# Use saved options if available (persists across reopens/restarts)
	var saved := ArenaRunManagerScript.load_class_options()
	if saved.size() == 3:
		_class_options = saved
		return

	# Generate new options
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("ArenaClassSelectScreen: cannot open %s" % REGISTRY_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("ArenaClassSelectScreen: invalid JSON in %s" % REGISTRY_PATH)
		return
	var registry: Dictionary = json.data
	var all_classes: Array = registry.get("dual_classes", [])
	all_classes.shuffle()
	_class_options = all_classes.slice(0, 3)
	ArenaRunManagerScript.save_class_options(_class_options)


func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(700, 0)
	root.add_theme_constant_override("separation", 32)
	center.add_child(root)

	# Title
	var title := Label.new()
	title.text = "Choose Your Class"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	# Class options row
	var options_row := HBoxContainer.new()
	options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	options_row.add_theme_constant_override("separation", 24)
	root.add_child(options_row)

	for class_data in _class_options:
		var card := _build_class_card(class_data)
		options_row.add_child(card)

	# Back button
	var back_spacer := Control.new()
	back_spacer.custom_minimum_size = Vector2(0, 16)
	root.add_child(back_spacer)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(back_row)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(200, 44)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	back_row.add_child(back_button)


func _build_class_card(class_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 160)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Class name
	var name_label := Label.new()
	name_label.text = str(class_data.get("display_name", "Unknown"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	# Attribute labels
	var attr_ids: Array = class_data.get("attribute_ids", [])
	var attr_row := HBoxContainer.new()
	attr_row.alignment = BoxContainer.ALIGNMENT_CENTER
	attr_row.add_theme_constant_override("separation", 8)
	vbox.add_child(attr_row)

	for attr_id in attr_ids:
		var attr_label := Label.new()
		attr_label.text = str(attr_id).capitalize()
		attr_label.add_theme_font_size_override("font_size", 14)
		var tint: Color = ATTRIBUTE_TINTS.get(str(attr_id), Color.WHITE)
		attr_label.add_theme_color_override("font_color", tint)
		attr_row.add_child(attr_label)

		# Separator between attributes
		if attr_id != attr_ids.back():
			var sep := Label.new()
			sep.text = "+"
			sep.add_theme_font_size_override("font_size", 14)
			sep.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
			attr_row.add_child(sep)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Select button
	var select_button := Button.new()
	select_button.text = "Select"
	select_button.custom_minimum_size = Vector2(0, 40)
	select_button.pressed.connect(func() -> void: class_selected.emit(attr_ids))
	vbox.add_child(select_button)

	return panel
