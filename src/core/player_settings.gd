class_name PlayerSettings
extends RefCounted

const AvatarRegistry = preload("res://src/core/avatar_registry.gd")

const SETTINGS_PATH := "user://player_settings.json"


static func _load_raw() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func _save_raw(data: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("PlayerSettings: cannot open %s for writing" % SETTINGS_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))


static func get_avatar_id() -> String:
	var data := _load_raw()
	var stored := str(data.get("avatar_id", ""))
	return AvatarRegistry.resolve_avatar_id(stored)


static func set_avatar_id(avatar_id: String) -> void:
	var resolved := AvatarRegistry.resolve_avatar_id(avatar_id)
	var data := _load_raw()
	data["avatar_id"] = resolved
	_save_raw(data)


static func get_avatar_full_texture() -> Texture2D:
	return AvatarRegistry.load_full_texture(get_avatar_id())


static func get_avatar_top_half_texture() -> Texture2D:
	return AvatarRegistry.load_top_half_texture(get_avatar_id())
