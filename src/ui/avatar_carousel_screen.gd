class_name AvatarCarouselScreen
extends Control

signal back_pressed
signal avatar_selected(avatar_id: String)

const UITheme = preload("res://src/ui/ui_theme.gd")
const AvatarRegistry = preload("res://src/core/avatar_registry.gd")
const PlayerSettings = preload("res://src/core/player_settings.gd")

const PREVIEW_SIZE := Vector2(720, 960)

var _avatar_ids: Array = []
var _current_index := 0
var _current_selected_id := ""

var _avatar_texture_rect: TextureRect
var _avatar_name_label: Label
var _select_button: Button
var _import_button: Button
var _delete_button: Button
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
	root.custom_minimum_size = Vector2(1320, 0)
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
	_prev_button.custom_minimum_size = Vector2(64, 960)
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
	_next_button.custom_minimum_size = Vector2(64, 960)
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
	select_row.add_theme_constant_override("separation", 16)
	root.add_child(select_row)

	_select_button = Button.new()
	_select_button.text = "Select"
	_select_button.custom_minimum_size = Vector2(240, 56)
	UITheme.style_button(_select_button, 22)
	_select_button.pressed.connect(_on_select_pressed)
	select_row.add_child(_select_button)

	_import_button = Button.new()
	_import_button.text = "Import…"
	_import_button.custom_minimum_size = Vector2(200, 56)
	UITheme.style_button(_import_button, 22, true)
	_import_button.pressed.connect(_on_import_pressed)
	select_row.add_child(_import_button)

	_delete_button = Button.new()
	_delete_button.text = "Delete"
	_delete_button.custom_minimum_size = Vector2(180, 56)
	UITheme.style_button(_delete_button, 22, true)
	_delete_button.pressed.connect(_on_delete_pressed)
	select_row.add_child(_delete_button)

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
		_delete_button.visible = false
		return
	var avatar_id := String(_avatar_ids[_current_index])
	_avatar_texture_rect.texture = AvatarRegistry.load_full_texture(avatar_id)
	_avatar_name_label.text = AvatarRegistry.display_name(avatar_id)
	var is_current := avatar_id == _current_selected_id
	_select_button.disabled = is_current
	_select_button.text = "Selected" if is_current else "Select"
	_delete_button.visible = AvatarRegistry.is_user_avatar(avatar_id)


func _on_import_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Image Files"])
	dialog.title = "Select Avatar Image"
	dialog.size = Vector2i(900, 600)
	dialog.use_native_dialog = true
	dialog.file_selected.connect(func(path: String) -> void:
		dialog.queue_free()
		_on_import_file_selected(path)
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _on_import_file_selected(path: String) -> void:
	var new_id := AvatarRegistry.import_user_avatar(path)
	if new_id == "":
		return
	_avatar_ids = AvatarRegistry.list_avatar_ids()
	var idx := _avatar_ids.find(new_id)
	_current_index = idx if idx >= 0 else 0
	_refresh()


func _on_delete_pressed() -> void:
	if _avatar_ids.is_empty():
		return
	var avatar_id := String(_avatar_ids[_current_index])
	if not AvatarRegistry.is_user_avatar(avatar_id):
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Avatar"
	dialog.dialog_text = "Delete '%s'?" % AvatarRegistry.display_name(avatar_id)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_confirm_delete(avatar_id)
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _confirm_delete(avatar_id: String) -> void:
	if not AvatarRegistry.delete_user_avatar(avatar_id):
		return
	if avatar_id == _current_selected_id:
		_current_selected_id = AvatarRegistry.DEFAULT_AVATAR_ID
		PlayerSettings.set_avatar_id(AvatarRegistry.DEFAULT_AVATAR_ID)
		avatar_selected.emit(AvatarRegistry.DEFAULT_AVATAR_ID)
	_avatar_ids = AvatarRegistry.list_avatar_ids()
	_current_index = clamp(_current_index, 0, max(0, _avatar_ids.size() - 1))
	_refresh()
