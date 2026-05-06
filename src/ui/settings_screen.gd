class_name SettingsScreen
extends Control

signal back_pressed
signal select_avatar_pressed

const UITheme = preload("res://src/ui/ui_theme.gd")
const PlayerSettings = preload("res://src/core/player_settings.gd")

var _avatar_preview: TextureRect
var _ismcts_budget_row: Control
var _ismcts_budget_label: Label
var _ismcts_budget_slider: HSlider


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	refresh_avatar_preview()


func _build_ui() -> void:
	UITheme.add_background(self)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(600, 0)
	root.add_theme_constant_override("separation", 28)
	center.add_child(root)

	var title := Label.new()
	title.text = "Settings"
	UITheme.style_title(title, 56)
	root.add_child(title)

	root.add_child(UITheme.make_separator(480.0))

	var avatar_panel := PanelContainer.new()
	UITheme.style_panel(avatar_panel)
	root.add_child(avatar_panel)

	var avatar_row := HBoxContainer.new()
	avatar_row.add_theme_constant_override("separation", 20)
	avatar_panel.add_child(avatar_row)

	_avatar_preview = TextureRect.new()
	_avatar_preview.custom_minimum_size = Vector2(96, 96)
	_avatar_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_row.add_child(_avatar_preview)

	var label_col := VBoxContainer.new()
	label_col.size_flags_horizontal = SIZE_EXPAND_FILL
	label_col.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_row.add_child(label_col)

	var heading := Label.new()
	heading.text = "Avatar"
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	label_col.add_child(heading)

	var select_btn := Button.new()
	select_btn.text = "Select Avatar"
	select_btn.custom_minimum_size = Vector2(260, 60)
	UITheme.style_button(select_btn, 26)
	select_btn.pressed.connect(func() -> void: select_avatar_pressed.emit())
	label_col.add_child(select_btn)

	root.add_child(_build_ai_engine_panel())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	root.add_child(spacer)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(back_row)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(260, 64)
	UITheme.style_button(back_button, 28, true)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	back_row.add_child(back_button)


func _build_ai_engine_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	UITheme.style_panel(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var heading := Label.new()
	heading.text = "AI Engine"
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	col.add_child(heading)

	var description := Label.new()
	description.text = "Heuristic = faster, uses simple scoring based on what it can see.\nISMCTS = slower, reasons under hidden info (experimental)."
	description.add_theme_font_size_override("font_size", 20)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(description)

	var dropdown := OptionButton.new()
	dropdown.add_theme_font_size_override("font_size", 24)
	dropdown.custom_minimum_size = Vector2(360, 56)
	dropdown.add_item("Heuristic", 0)
	dropdown.add_item("ISMCTS (experimental)", 1)
	var current := PlayerSettings.get_ai_engine()
	dropdown.select(1 if current == PlayerSettings.AI_ENGINE_ISMCTS else 0)
	dropdown.item_selected.connect(_on_ai_engine_selected)
	col.add_child(dropdown)

	# ISMCTS thinking-time slider — only meaningful when ISMCTS is selected.
	_ismcts_budget_row = _build_ismcts_budget_row()
	col.add_child(_ismcts_budget_row)
	_ismcts_budget_row.visible = current == PlayerSettings.AI_ENGINE_ISMCTS

	return panel


func _build_ismcts_budget_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	_ismcts_budget_label = Label.new()
	_ismcts_budget_label.add_theme_font_size_override("font_size", 20)
	_ismcts_budget_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	row.add_child(_ismcts_budget_label)

	_ismcts_budget_slider = HSlider.new()
	_ismcts_budget_slider.custom_minimum_size = Vector2(360, 36)
	_ismcts_budget_slider.min_value = float(PlayerSettings.ISMCTS_BUDGET_MIN_MS) / 1000.0
	_ismcts_budget_slider.max_value = float(PlayerSettings.ISMCTS_BUDGET_MAX_MS) / 1000.0
	_ismcts_budget_slider.step = 0.1
	_ismcts_budget_slider.value = float(PlayerSettings.get_ismcts_budget_ms()) / 1000.0
	_ismcts_budget_slider.value_changed.connect(_on_ismcts_budget_changed)
	row.add_child(_ismcts_budget_slider)

	_update_ismcts_budget_label(_ismcts_budget_slider.value)
	return row


func _on_ai_engine_selected(index: int) -> void:
	var engine := PlayerSettings.AI_ENGINE_ISMCTS if index == 1 else PlayerSettings.AI_ENGINE_HEURISTIC
	PlayerSettings.set_ai_engine(engine)
	if _ismcts_budget_row != null:
		_ismcts_budget_row.visible = engine == PlayerSettings.AI_ENGINE_ISMCTS


func _on_ismcts_budget_changed(value: float) -> void:
	var ms := int(round(value * 1000.0))
	PlayerSettings.set_ismcts_budget_ms(ms)
	_update_ismcts_budget_label(value)


func _update_ismcts_budget_label(value: float) -> void:
	if _ismcts_budget_label == null:
		return
	_ismcts_budget_label.text = "Max thinking time: %.1fs" % value


func refresh_avatar_preview() -> void:
	if _avatar_preview == null:
		return
	_avatar_preview.texture = PlayerSettings.get_avatar_full_texture()
