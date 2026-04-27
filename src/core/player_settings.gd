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


static func get_favourite_card_ids() -> Array:
	var data := _load_raw()
	var raw: Variant = data.get("favourite_card_ids", [])
	var result: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for value in raw:
			result.append(str(value))
	return result


static func is_favourite_card(card_id: String) -> bool:
	return get_favourite_card_ids().has(card_id)


static func set_favourite_card(card_id: String, favourite: bool) -> void:
	if card_id.is_empty():
		return
	var data := _load_raw()
	var ids: Array = []
	var raw: Variant = data.get("favourite_card_ids", [])
	if typeof(raw) == TYPE_ARRAY:
		for value in raw:
			ids.append(str(value))
	if favourite:
		if not ids.has(card_id):
			ids.append(card_id)
	else:
		ids.erase(card_id)
	data["favourite_card_ids"] = ids
	_save_raw(data)
