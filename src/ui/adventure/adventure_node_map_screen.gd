class_name AdventureNodeMapScreen
extends Control

signal node_fight_pressed(node_id: String)
signal abandon_pressed

var _adventure: Dictionary = {}
var _completed_node_ids: Array = []
var _current_node_id: String = ""
var _revives_remaining: int = 0
var _node_buttons: Dictionary = {}  # node_id -> Button
var _revives_label: Label
var _adventure_name_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func set_map_data(adventure: Dictionary, current_node_id: String, completed_node_ids: Array, revives_remaining: int) -> void:
	_adventure = adventure
	_current_node_id = current_node_id
	_completed_node_ids = completed_node_ids
	_revives_remaining = revives_remaining
	_build_ui()


func _build_ui() -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()
	_node_buttons.clear()

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# Header
	var header := _build_header()
	main_vbox.add_child(header)

	# Node list in a scroll container
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var node_list := VBoxContainer.new()
	node_list.size_flags_horizontal = SIZE_EXPAND_FILL
	node_list.add_theme_constant_override("separation", 8)
	scroll.add_child(node_list)

	# Center the node list
	var center_margin := MarginContainer.new()
	center_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	center_margin.add_theme_constant_override("margin_left", 200)
	center_margin.add_theme_constant_override("margin_right", 200)
	center_margin.add_theme_constant_override("margin_top", 24)
	center_margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(center_margin)

	var nodes_vbox := VBoxContainer.new()
	nodes_vbox.add_theme_constant_override("separation", 8)
	center_margin.add_child(nodes_vbox)

	# Build ordered node list
	var ordered := _get_ordered_nodes()
	for i in range(ordered.size()):
		var node_data: Dictionary = ordered[i]
		var node_id: String = node_data["id"]
		var is_completed := node_id in _completed_node_ids
		var is_current := node_id == _current_node_id

		var node_row := _build_node_row(node_data, is_completed, is_current, i + 1)
		nodes_vbox.add_child(node_row)

		# Add connector line between nodes (except after last)
		if i < ordered.size() - 1:
			var connector := _build_connector(is_completed)
			nodes_vbox.add_child(connector)

	# Footer with abandon button
	var footer := _build_footer()
	main_vbox.add_child(footer)


func _build_header() -> Control:
	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left", 24)
	header.add_theme_constant_override("margin_right", 24)
	header.add_theme_constant_override("margin_top", 16)
	header.add_theme_constant_override("margin_bottom", 16)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	header.add_child(hbox)

	_adventure_name_label = Label.new()
	_adventure_name_label.text = str(_adventure.get("name", "Adventure"))
	_adventure_name_label.add_theme_font_size_override("font_size", 24)
	_adventure_name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(_adventure_name_label)

	_revives_label = Label.new()
	_revives_label.text = "Revives: %d" % _revives_remaining
	_revives_label.add_theme_font_size_override("font_size", 18)
	_revives_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0) if _revives_remaining > 0 else Color(0.84, 0.39, 0.31, 1.0))
	hbox.add_child(_revives_label)

	return header


func _build_node_row(node_data: Dictionary, is_completed: bool, is_current: bool, index: int) -> Control:
	var node_id: String = node_data["id"]
	var node_type: String = str(node_data.get("type", "combat"))
	var headline: String = str(node_data.get("headline", "Unknown"))

	var type_label := ""
	match node_type:
		"combat":
			type_label = "Battle"
		"mini_boss":
			type_label = "Mini-Boss"
		"final_boss":
			type_label = "Final Boss"

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(400, 56)

	if is_completed:
		btn.text = "[%d] %s — %s  (Complete)" % [index, type_label, headline]
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.7, 0.5, 0.7))
	elif is_current:
		btn.text = "[%d] %s — %s" % [index, type_label, headline]
		btn.pressed.connect(func() -> void: node_fight_pressed.emit(node_id))
		# Highlight current node
		var style := StyleBoxFlat.new()
		if node_type == "final_boss":
			style.bg_color = Color(0.5, 0.15, 0.15, 1.0)
			style.border_color = Color(0.9, 0.3, 0.3, 1.0)
		elif node_type == "mini_boss":
			style.bg_color = Color(0.4, 0.3, 0.15, 1.0)
			style.border_color = Color(0.9, 0.7, 0.3, 1.0)
		else:
			style.bg_color = Color(0.2, 0.35, 0.55, 1.0)
			style.border_color = Color(0.4, 0.6, 0.9, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)
	else:
		btn.text = "[%d] %s — %s" % [index, type_label, headline]
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4, 0.5))

	_node_buttons[node_id] = btn
	return btn


func _build_connector(is_after_completed: bool) -> Control:
	var connector := Label.new()
	connector.text = "  |"
	connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	connector.add_theme_font_size_override("font_size", 14)
	if is_after_completed:
		connector.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5, 0.5))
	else:
		connector.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 0.3))
	return connector


func _build_footer() -> Control:
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_left", 24)
	footer.add_theme_constant_override("margin_right", 24)
	footer.add_theme_constant_override("margin_top", 8)
	footer.add_theme_constant_override("margin_bottom", 16)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(hbox)

	var abandon_btn := Button.new()
	abandon_btn.text = "Abandon Run"
	abandon_btn.custom_minimum_size = Vector2(200, 44)
	abandon_btn.pressed.connect(func() -> void: abandon_pressed.emit())
	hbox.add_child(abandon_btn)

	return footer


func _get_ordered_nodes() -> Array:
	var ordered: Array = []
	var start_id: String = str(_adventure.get("start_node", ""))
	var nodes: Dictionary = _adventure.get("nodes", {})
	var current_id := start_id
	while not current_id.is_empty():
		var node: Dictionary = nodes.get(current_id, {})
		if node.is_empty():
			break
		var entry := node.duplicate()
		entry["id"] = current_id
		ordered.append(entry)
		var next_nodes: Array = node.get("next", [])
		if next_nodes.size() == 1:
			current_id = str(next_nodes[0])
		else:
			break
	return ordered
