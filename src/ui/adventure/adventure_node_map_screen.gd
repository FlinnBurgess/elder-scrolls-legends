class_name AdventureNodeMapScreen
extends Control

signal node_selected(node_id: String)
signal abandon_pressed

const AdventureCatalogScript = preload("res://src/adventure/adventure_catalog.gd")

var _adventure: Dictionary = {}
var _completed_node_ids: Array = []
var _current_node_id: String = ""
var _revives_remaining: int = 0
var _gold: int = 0
var _max_health_bonus: int = 0
var _reachable_node_ids: Array = []
var _node_buttons: Dictionary = {}  # node_id -> Button
var _revives_label: Label
var _gold_label: Label
var _health_label: Label
var _adventure_name_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func set_map_data(adventure: Dictionary, current_node_id: String, completed_node_ids: Array, revives_remaining: int, gold: int = 0, max_health_bonus: int = 0) -> void:
	_adventure = adventure
	_current_node_id = current_node_id
	_completed_node_ids = completed_node_ids
	_revives_remaining = revives_remaining
	_gold = gold
	_max_health_bonus = max_health_bonus
	_reachable_node_ids = _compute_reachable_nodes()
	_build_ui()


func _compute_reachable_nodes() -> Array:
	# If current_node_id is set, that's the only reachable node
	if not _current_node_id.is_empty():
		return [_current_node_id]

	# If current_node_id is empty, we're at a branch point — find nodes
	# that are in the `next` array of the last completed node
	var nodes: Dictionary = _adventure.get("nodes", {})
	for i in range(_completed_node_ids.size() - 1, -1, -1):
		var last_completed: String = str(_completed_node_ids[i])
		var node: Dictionary = nodes.get(last_completed, {})
		var next_nodes: Array = node.get("next", [])
		if next_nodes.size() > 1:
			var reachable: Array = []
			for nid in next_nodes:
				var nid_str: String = str(nid)
				if nid_str not in _completed_node_ids:
					reachable.append(nid_str)
			if not reachable.is_empty():
				return reachable
	return []


func _build_ui() -> void:
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

	# Node graph in a scroll container
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var center_margin := MarginContainer.new()
	center_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	center_margin.add_theme_constant_override("margin_left", 100)
	center_margin.add_theme_constant_override("margin_right", 100)
	center_margin.add_theme_constant_override("margin_top", 24)
	center_margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(center_margin)

	var graph_vbox := VBoxContainer.new()
	graph_vbox.add_theme_constant_override("separation", 4)
	graph_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	center_margin.add_child(graph_vbox)

	# Build graph layers
	var layers := AdventureCatalogScript.get_graph_layers(_adventure)
	for i in range(layers.size()):
		var layer: Array = layers[i]
		var layer_container := _build_layer(layer)
		graph_vbox.add_child(layer_container)

		# Connector between layers
		if i < layers.size() - 1:
			var next_layer: Array = layers[i + 1]
			var connector := _build_layer_connector(layer, next_layer)
			graph_vbox.add_child(connector)

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

	_health_label = Label.new()
	var total_health := 30 + _max_health_bonus
	_health_label.text = "HP: %d" % total_health
	_health_label.add_theme_font_size_override("font_size", 18)
	_health_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
	if _max_health_bonus > 0:
		_health_label.text = "HP: %d (+%d)" % [total_health, _max_health_bonus]
	hbox.add_child(_health_label)

	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % _gold
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
	hbox.add_child(_gold_label)

	_revives_label = Label.new()
	_revives_label.text = "Revives: %d" % _revives_remaining
	_revives_label.add_theme_font_size_override("font_size", 18)
	_revives_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0) if _revives_remaining > 0 else Color(0.84, 0.39, 0.31, 1.0))
	hbox.add_child(_revives_label)

	return header


func _build_layer(layer: Array) -> Control:
	if layer.size() == 1:
		# Single node — centered
		var center := HBoxContainer.new()
		center.alignment = BoxContainer.ALIGNMENT_CENTER
		center.size_flags_horizontal = SIZE_EXPAND_FILL
		var btn := _build_node_button(layer[0])
		center.add_child(btn)
		return center
	else:
		# Multiple nodes — spread horizontally
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 60)
		hbox.size_flags_horizontal = SIZE_EXPAND_FILL
		for node_data in layer:
			var btn := _build_node_button(node_data)
			hbox.add_child(btn)
		return hbox


func _build_node_button(node_data: Dictionary) -> Button:
	var node_id: String = str(node_data.get("id", ""))
	var node_type: String = str(node_data.get("type", "combat"))
	var headline: String = str(node_data.get("headline", "Unknown"))
	var is_completed := node_id in _completed_node_ids
	var is_reachable := node_id in _reachable_node_ids

	var type_icon := _get_type_icon(node_type)
	var type_label := _get_type_label(node_type)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(280, 56)

	if is_completed:
		btn.text = "%s %s — %s  (Done)" % [type_icon, type_label, headline]
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.7, 0.5, 0.7))
	elif is_reachable:
		btn.text = "%s %s — %s" % [type_icon, type_label, headline]
		btn.pressed.connect(func() -> void: node_selected.emit(node_id))
		var style := _get_node_style(node_type)
		btn.add_theme_stylebox_override("normal", style)
	else:
		# Greyed out — visible but not interactable
		btn.text = "%s %s — %s" % [type_icon, type_label, headline]
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4, 0.5))

	_node_buttons[node_id] = btn
	return btn


func _get_type_icon(node_type: String) -> String:
	match node_type:
		"combat": return "[Battle]"
		"mini_boss": return "[Boss]"
		"final_boss": return "[BOSS]"
		"healer": return "[Heal]"
		"reinforcement": return "[Card]"
		"shop": return "[Shop]"
	return "[?]"


func _get_type_label(node_type: String) -> String:
	match node_type:
		"combat": return "Battle"
		"mini_boss": return "Mini-Boss"
		"final_boss": return "Final Boss"
		"healer": return "Healer"
		"reinforcement": return "Recruit"
		"shop": return "Shop"
	return "Unknown"


func _get_node_style(node_type: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match node_type:
		"final_boss":
			style.bg_color = Color(0.5, 0.15, 0.15, 1.0)
			style.border_color = Color(0.9, 0.3, 0.3, 1.0)
		"mini_boss":
			style.bg_color = Color(0.4, 0.3, 0.15, 1.0)
			style.border_color = Color(0.9, 0.7, 0.3, 1.0)
		"healer":
			style.bg_color = Color(0.15, 0.4, 0.2, 1.0)
			style.border_color = Color(0.3, 0.8, 0.4, 1.0)
		"reinforcement":
			style.bg_color = Color(0.2, 0.25, 0.45, 1.0)
			style.border_color = Color(0.4, 0.5, 0.9, 1.0)
		"shop":
			style.bg_color = Color(0.4, 0.35, 0.15, 1.0)
			style.border_color = Color(0.9, 0.75, 0.3, 1.0)
		_:
			style.bg_color = Color(0.2, 0.35, 0.55, 1.0)
			style.border_color = Color(0.4, 0.6, 0.9, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _build_layer_connector(layer: Array, next_layer: Array) -> Control:
	# Simple text connector between layers
	var is_branch := layer.size() > 1 or next_layer.size() > 1
	var connector := Label.new()
	if is_branch:
		if layer.size() > 1:
			connector.text = "\\  /"
		else:
			connector.text = "/  \\"
	else:
		connector.text = "|"
	connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	connector.add_theme_font_size_override("font_size", 14)

	# Color based on whether we've passed this point
	var all_completed := true
	for node_data in layer:
		if str(node_data.get("id", "")) not in _completed_node_ids:
			all_completed = false
			break
	if all_completed:
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
