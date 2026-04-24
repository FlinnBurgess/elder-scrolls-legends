class_name SettingsScreen
extends Control

signal back_pressed
signal select_avatar_pressed

const UITheme = preload("res://src/ui/ui_theme.gd")
const PlayerSettings = preload("res://src/core/player_settings.gd")

var _avatar_preview: TextureRect


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
	root.custom_minimum_size = Vector2(520, 0)
	root.add_theme_constant_override("separation", 24)
	center.add_child(root)

	var title := Label.new()
	title.text = "Settings"
	UITheme.style_title(title, 44)
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
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	label_col.add_child(heading)

	var select_btn := Button.new()
	select_btn.text = "Select Avatar"
	select_btn.custom_minimum_size = Vector2(220, 52)
	UITheme.style_button(select_btn, 20)
	select_btn.pressed.connect(func() -> void: select_avatar_pressed.emit())
	label_col.add_child(select_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	root.add_child(spacer)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(back_row)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(220, 56)
	UITheme.style_button(back_button, 22, true)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	back_row.add_child(back_button)


func refresh_avatar_preview() -> void:
	if _avatar_preview == null:
		return
	_avatar_preview.texture = PlayerSettings.get_avatar_full_texture()
