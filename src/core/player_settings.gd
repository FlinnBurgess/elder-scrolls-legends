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


# AI opponent pool: stores the set of deck entry IDs the player has *excluded*
# from the random AI pool on the deck-select screen. Storing the excluded set
# (rather than the included set) makes new decks default to "in the pool".

static func get_ai_pool_disabled_ids() -> Dictionary:
	var data := _load_raw()
	var ids: Dictionary = {}
	var raw: Variant = data.get("ai_pool_disabled_deck_ids", [])
	if typeof(raw) == TYPE_ARRAY:
		for value in raw:
			ids[str(value)] = true
	return ids


static func set_ai_pool_enabled(entry_id: String, enabled: bool) -> void:
	if entry_id.is_empty():
		return
	var data := _load_raw()
	var ids: Array = []
	var raw: Variant = data.get("ai_pool_disabled_deck_ids", [])
	if typeof(raw) == TYPE_ARRAY:
		for value in raw:
			var id_str := str(value)
			if id_str != entry_id:
				ids.append(id_str)
	if not enabled:
		ids.append(entry_id)
	data["ai_pool_disabled_deck_ids"] = ids
	_save_raw(data)


# AI engine selection: which decision policy the local-match AI uses.
# "heuristic" (default) — fast scoring + lookahead, peeks at opponent info.
# "ismcts" — Information Set Monte Carlo Tree Search; reasons over hidden info.

const AI_ENGINE_HEURISTIC := "heuristic"
const AI_ENGINE_ISMCTS := "ismcts"


static func get_ai_engine() -> String:
	var data := _load_raw()
	var engine := str(data.get("ai_engine", AI_ENGINE_HEURISTIC))
	if engine != AI_ENGINE_ISMCTS:
		return AI_ENGINE_HEURISTIC
	return AI_ENGINE_ISMCTS


static func set_ai_engine(engine: String) -> void:
	var resolved := AI_ENGINE_ISMCTS if engine == AI_ENGINE_ISMCTS else AI_ENGINE_HEURISTIC
	var data := _load_raw()
	data["ai_engine"] = resolved
	_save_raw(data)
