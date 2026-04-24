class_name AvatarCarouselScreen
extends Control

signal back_pressed
signal avatar_selected(avatar_id: String)

const UITheme = preload("res://src/ui/ui_theme.gd")
const AvatarRegistry = preload("res://src/core/avatar_registry.gd")
const PlayerSettings = preload("res://src/core/player_settings.gd")

const PREVIEW_SIZE := Vector2(320, 320)

var _avatar_ids: Array = []
var _current_index := 0
var _current_selected_id := ""

var _avatar_texture_rect: TextureRect
var _avatar_name_label: Label
var _select_button: Button
var _prev_button: Button
var _next_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_avatar_ids = AvatarRegistry.list_avatar_ids()
	_current_selected_id = PlayerSettings.get_avatar_id()
	_current_index = max(0, _avatar_ids.find(_current_selected_id))
	_build_ui()
	_refresh()


func _build_ui() -> void:
	UITheme.add_background(self)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(640, 0)
	root.add_theme_constant_override("separation", 20)
	center.add_child(root)

	var title := Label.new()
	title.text = "Select Avatar"
	UITheme.style_title(title, 40)
	root.add_child(title)

	root.add_child(UITheme.make_separator(600.0))

	var carousel_row := HBoxContainer.new()
	carousel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel_row.add_theme_constant_override("separation", 16)
	root.add_child(carousel_row)

	_prev_button = Button.new()
	_prev_button.text = "<"
	_prev_button.custom_minimum_size = Vector2(64, 320)
	UITheme.style_button(_prev_button, 28)
	_prev_button.pressed.connect(_on_prev_pressed)
	carousel_row.add_child(_prev_button)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = PREVIEW_SIZE
	UITheme.style_panel(preview_panel)
	carousel_row.add_child(preview_panel)

	_avatar_texture_rect = TextureRect.new()
	_avatar_texture_rect.custom_minimum_size = PREVIEW_SIZE - Vector2(40, 40)
	_avatar_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_panel.add_child(_avatar_texture_rect)

	_next_button = Button.new()
	_next_button.text = ">"
	_next_button.custom_minimum_size = Vector2(64, 320)
	UITheme.style_button(_next_button, 28)
	_next_button.pressed.connect(_on_next_pressed)
	carousel_row.add_child(_next_button)

	_avatar_name_label = Label.new()
	_avatar_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_name_label.add_theme_font_size_override("font_size", 24)
	_avatar_name_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	root.add_child(_avatar_name_label)

	var select_row := HBoxContainer.new()
	select_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(select_row)

	_select_button = Button.new()
	_select_button.text = "Select"
	_select_button.custom_minimum_size = Vector2(260, 56)
	UITheme.style_button(_select_button, 22)
	_select_button.pressed.connect(_on_select_pressed)
	select_row.add_child(_select_button)

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


func _on_prev_pressed() -> void:
	if _avatar_ids.is_empty():
		return
	_current_index = (_current_index - 1 + _avatar_ids.size()) % _avatar_ids.size()
	_refresh()


func _on_next_pressed() -> void:
	if _avatar_ids.is_empty():
		return
	_current_index = (_current_index + 1) % _avatar_ids.size()
	_refresh()


func _on_select_pressed() -> void:
	if _avatar_ids.is_empty():
		return
	var new_id := String(_avatar_ids[_current_index])
	if new_id == _current_selected_id:
		return
	PlayerSettings.set_avatar_id(new_id)
	_current_selected_id = new_id
	avatar_selected.emit(new_id)
	_refresh()


func _refresh() -> void:
	if _avatar_ids.is_empty():
		_avatar_name_label.text = "(no avatars)"
		_select_button.disabled = true
		return
	var avatar_id := String(_avatar_ids[_current_index])
	_avatar_texture_rect.texture = AvatarRegistry.load_full_texture(avatar_id)
	_avatar_name_label.text = AvatarRegistry.display_name(avatar_id)
	var is_current := avatar_id == _current_selected_id
	_select_button.disabled = is_current
	_select_button.text = "Selected" if is_current else "Select"
