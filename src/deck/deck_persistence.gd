class_name DeckPersistence
extends RefCounted

const DECKS_DIR := "user://decks/"


static func save_deck(deck_name: String, definition: Dictionary) -> void:
	_ensure_directory()
	var path := _deck_path(deck_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DeckPersistence: failed to open '%s' for writing: %s" % [path, FileAccess.get_open_error()])
		return
	var data := definition.duplicate(true)
	data["name"] = deck_name
	file.store_string(JSON.stringify(data, "\t"))


static func load_deck(deck_name: String) -> Dictionary:
	var path := _deck_path(deck_name)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DeckPersistence: failed to open '%s' for reading: %s" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("DeckPersistence: failed to parse '%s': %s" % [path, json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


static func list_decks() -> Array[String]:
	_ensure_directory()
	var names: Array[String] = []
	var dir := DirAccess.open(DECKS_DIR)
	if dir == null:
		return names
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			names.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names


static func delete_deck(deck_name: String) -> bool:
	var path := _deck_path(deck_name)
	if not FileAccess.file_exists(path):
		return false
	var dir := DirAccess.open(DECKS_DIR)
	if dir == null:
		return false
	return dir.remove(_sanitize_name(deck_name) + ".json") == OK


static func _deck_path(deck_name: String) -> String:
	return DECKS_DIR + _sanitize_name(deck_name) + ".json"


static func _sanitize_name(deck_name: String) -> String:
	return deck_name.to_lower().strip_edges().replace(" ", "_").replace("/", "_").replace("\\", "_")


static func _ensure_directory() -> void:
	if not DirAccess.dir_exists_absolute(DECKS_DIR):
		DirAccess.make_dir_recursive_absolute(DECKS_DIR)
