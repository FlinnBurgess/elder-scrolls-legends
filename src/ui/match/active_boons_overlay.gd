class_name ActiveBoonsOverlay
extends Control

const BoonCatalogScript = preload("res://src/adventure/boon_catalog.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_boons(active_boons: Array) -> void:
	for child in get_children():
		child.queue_free()

	# Semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	# Centered panel — use anchor 0.5 + grow both directions for true centering
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(400, 0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	vbox.add_child(margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(inner_vbox)

	# Title
	var title := Label.new()
	title.text = "Active Boons"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(title)

	var separator := HSeparator.new()
	inner_vbox.add_child(separator)

	if active_boons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No active boons."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner_vbox.add_child(empty_label)
	else:
		# Count stacks per boon
		var counts: Dictionary = {}
		for boon_id in active_boons:
			var key := str(boon_id)
			counts[key] = counts.get(key, 0) + 1

		var shown: Dictionary = {}
		for boon_id in active_boons:
			var key := str(boon_id)
			if shown.has(key):
				continue
			shown[key] = true
			var boon_data := BoonCatalogScript.get_boon(key)
			var boon_name := str(boon_data.get("name", key)) if not boon_data.is_empty() else key
			var boon_desc := str(boon_data.get("description", "")) if not boon_data.is_empty() else ""
			var stacks: int = counts.get(key, 1)

			var entry_vbox := VBoxContainer.new()
			entry_vbox.add_theme_constant_override("separation", 2)
			inner_vbox.add_child(entry_vbox)

			var name_label := Label.new()
			if stacks > 1:
				name_label.text = "%s (x%d)" % [boon_name, stacks]
			else:
				name_label.text = boon_name
			name_label.add_theme_font_size_override("font_size", 16)
			name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0, 1.0))
			entry_vbox.add_child(name_label)

			if not boon_desc.is_empty():
				var desc_label := Label.new()
				desc_label.text = boon_desc
				desc_label.add_theme_font_size_override("font_size", 13)
				desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
				desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				entry_vbox.add_child(desc_label)

	# Close button
	var sep2 := HSeparator.new()
	inner_vbox.add_child(sep2)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(queue_free)
	var close_hbox := HBoxContainer.new()
	close_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	close_hbox.add_child(close_btn)
	inner_vbox.add_child(close_hbox)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		queue_free()
