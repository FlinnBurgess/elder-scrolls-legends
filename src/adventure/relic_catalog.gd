class_name RelicCatalog
extends RefCounted

const RELICS_PATH := "res://data/relics.json"

static var _cached_relics: Array = []


static func get_all_relics() -> Array:
	_ensure_loaded()
	return _cached_relics.duplicate(true)


static func get_relic(relic_id: String) -> Dictionary:
	_ensure_loaded()
	for relic in _cached_relics:
		if typeof(relic) == TYPE_DICTIONARY and str(relic.get("id", "")) == relic_id:
			return relic.duplicate(true)
	return {}


static func _ensure_loaded() -> void:
	if not _cached_relics.is_empty():
		return
	var file := FileAccess.open(RELICS_PATH, FileAccess.READ)
	if file == null:
		push_error("RelicCatalog: failed to open '%s'" % RELICS_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("RelicCatalog: relics.json did not parse into an array")
		return
	_cached_relics = parsed


static func clear_cache() -> void:
	_cached_relics = []
