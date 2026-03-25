class_name BoonCatalog
extends RefCounted

const BOONS_PATH := "res://data/boons.json"

static var _cached_boons: Array = []


static func get_all_boons() -> Array:
	_ensure_loaded()
	return _cached_boons.duplicate(true)


static func get_boon(boon_id: String) -> Dictionary:
	_ensure_loaded()
	for boon in _cached_boons:
		if typeof(boon) == TYPE_DICTIONARY and str(boon.get("id", "")) == boon_id:
			return boon.duplicate(true)
	return {}


static func get_available_boons(active_boon_ids: Array) -> Array:
	_ensure_loaded()
	var result: Array = []
	for boon in _cached_boons:
		if typeof(boon) != TYPE_DICTIONARY:
			continue
		var boon_id := str(boon.get("id", ""))
		if boon_id.is_empty():
			continue
		var stackable := bool(boon.get("stackable", false))
		if not stackable and active_boon_ids.has(boon_id):
			continue
		result.append(boon.duplicate(true))
	return result


static func get_random_boon_offerings(active_boon_ids: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var available := get_available_boons(active_boon_ids)
	if available.is_empty():
		return []
	var shuffled := available.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var result: Array = []
	for i in range(min(count, shuffled.size())):
		result.append(shuffled[i])
	return result


static func _ensure_loaded() -> void:
	if not _cached_boons.is_empty():
		return
	var file := FileAccess.open(BOONS_PATH, FileAccess.READ)
	if file == null:
		push_error("BoonCatalog: failed to open '%s'" % BOONS_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("BoonCatalog: boons.json did not parse into an array")
		return
	_cached_boons = parsed
