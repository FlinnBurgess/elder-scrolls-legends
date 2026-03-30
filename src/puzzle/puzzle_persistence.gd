class_name PuzzlePersistence
extends RefCounted

## Persists custom puzzles and completion state to user://puzzles/puzzle_data.json.

const DEFAULT_SAVE_PATH := "user://puzzles/puzzle_data.json"
const DEFAULT_DIR_PATH := "user://puzzles"

static var _save_path_override := ""


static func set_save_path(path: String) -> void:
	_save_path_override = path


static func _save_path() -> String:
	return _save_path_override if not _save_path_override.is_empty() else DEFAULT_SAVE_PATH


static func _dir_path() -> String:
	if not _save_path_override.is_empty():
		return _save_path_override.get_base_dir()
	return DEFAULT_DIR_PATH


static func load_data() -> Dictionary:
	var file := FileAccess.open(_save_path(), FileAccess.READ)
	if file == null:
		return {"puzzles": []}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"puzzles": []}
	if typeof(parsed.get("puzzles")) != TYPE_ARRAY:
		parsed["puzzles"] = []
	return parsed


static func save_data(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_dir_path())
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_error("PuzzlePersistence: Failed to open save file for writing: %s" % _save_path())
		return
	file.store_string(JSON.stringify(data, "\t"))


static func add_puzzle(name: String, code: String) -> String:
	var data := load_data()
	var puzzles: Array = data.get("puzzles", [])
	var id := _generate_id()
	puzzles.append({"id": id, "name": name, "code": code, "solved": false})
	data["puzzles"] = puzzles
	save_data(data)
	return id


static func delete_puzzle(id: String) -> void:
	var data := load_data()
	var puzzles: Array = data.get("puzzles", [])
	var filtered: Array = []
	for entry in puzzles:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) != id:
			filtered.append(entry)
	data["puzzles"] = filtered
	save_data(data)


static func mark_solved(id: String) -> void:
	var data := load_data()
	for entry in data.get("puzzles", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == id:
			entry["solved"] = true
			break
	save_data(data)


static func is_solved(id: String) -> bool:
	var data := load_data()
	for entry in data.get("puzzles", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == id:
			return bool(entry.get("solved", false))
	return false


static func list_puzzles() -> Array:
	var data := load_data()
	var result: Array = []
	for entry in data.get("puzzles", []):
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


static func mark_pack_solved(puzzle_id: String) -> void:
	var data := load_data()
	var pack_solved: Dictionary = data.get("pack_solved", {})
	pack_solved[puzzle_id] = true
	data["pack_solved"] = pack_solved
	save_data(data)


static func is_pack_solved(puzzle_id: String) -> bool:
	var data := load_data()
	var pack_solved: Dictionary = data.get("pack_solved", {})
	return bool(pack_solved.get(puzzle_id, false))


static func _generate_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var id := ""
	for i in range(12):
		id += chars[rng.randi_range(0, chars.length() - 1)]
	return id
