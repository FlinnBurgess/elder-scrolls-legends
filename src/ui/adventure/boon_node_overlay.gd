class_name BoonNodeOverlay
extends Control

signal boon_selected(boon_id: String)

var _boons: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_boons(boons: Array) -> void:
	_boons = boons
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(bg)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.15, 0.97)
	panel_style.border_color = Color(0.7, 0.55, 0.1, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Choose a Boon"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A blessing to carry for the rest of your journey."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.8, 0.8, 0.8, 1.0)
	vbox.add_child(subtitle)

	var boons_hbox := HBoxContainer.new()
	boons_hbox.add_theme_constant_override("separation", 20)
	boons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(boons_hbox)

	for boon in _boons:
		boons_hbox.add_child(_build_boon_option(boon))


func _build_boon_option(boon: Dictionary) -> Control:
	var boon_id := str(boon.get("id", ""))
	var name_text := str(boon.get("name", boon_id))
	var desc_text := str(boon.get("description", ""))
	var stackable := bool(boon.get("stackable", false))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	style.border_color = Color(0.5, 0.4, 0.1, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.modulate = Color(0.95, 0.85, 0.4, 1.0)
	vbox.add_child(name_label)

	var sep := HSeparator.new()
	sep.modulate = Color(0.5, 0.4, 0.1, 0.8)
	vbox.add_child(sep)

	# Use ScrollContainer to give description a fixed height allocation
	var desc_scroll := ScrollContainer.new()
	desc_scroll.custom_minimum_size = Vector2(188, 100)
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(desc_scroll)

	var desc_label := Label.new()
	desc_label.text = desc_text
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(188, 0)
	desc_scroll.add_child(desc_label)

	if stackable:
		var stack_label := Label.new()
		stack_label.text = "Stackable"
		stack_label.add_theme_font_size_override("font_size", 11)
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack_label.modulate = Color(0.5, 0.8, 0.5, 1.0)
		vbox.add_child(stack_label)

	var select_btn := Button.new()
	select_btn.text = "Choose"
	select_btn.custom_minimum_size = Vector2(140, 40)
	select_btn.pressed.connect(func() -> void: boon_selected.emit(boon_id))
	vbox.add_child(select_btn)

	return panel
