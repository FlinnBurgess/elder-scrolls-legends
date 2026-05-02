class_name AIDeckMemory
extends RefCounted

## Persistent registry of cards the AI has observed across past matches against
## each saved deck. Used by the ISMCTS policy to seed prior knowledge so the
## AI's behaviour gradually adapts to a player's recurring decks.
##
## Storage: user://ai_memory.json
## {
##   "decks": {
##     "<deck_name>": {
##       "remembered_def_ids": ["str_morkul_gatekeeper", ...],
##       "matches_played": 12,
##       "last_seen_iso": "2026-05-02T12:34:56"
##     }
##   }
## }
##
## Deck-mutation handling: memory is keyed by deck_name (stable across edits),
## but `get_remembered_filtered` drops def_ids that are no longer in the deck's
## current contents. Result: minor edits adapt smoothly; major rebuilds decay
## naturally as the player keeps playing.

const STORAGE_PATH := "user://ai_memory.json"
const GROWTH_PER_MATCH := 2


static func _load_raw() -> Dictionary:
	if not FileAccess.file_exists(STORAGE_PATH):
		return {"decks": {}}
	var file := FileAccess.open(STORAGE_PATH, FileAccess.READ)
	if file == null:
		return {"decks": {}}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"decks": {}}
	if not parsed.has("decks") or typeof(parsed["decks"]) != TYPE_DICTIONARY:
		parsed["decks"] = {}
	return parsed


static func _save_raw(data: Dictionary) -> void:
	var file := FileAccess.open(STORAGE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("AIDeckMemory: cannot open %s for writing" % STORAGE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))


static func list_known_decks() -> Array:
	var data := _load_raw()
	var decks: Dictionary = data.get("decks", {})
	var names: Array = []
	for key in decks.keys():
		names.append(str(key))
	return names


static func get_remembered(deck_name: String) -> Array:
	if deck_name.is_empty():
		return []
	var data := _load_raw()
	var entry: Dictionary = data.get("decks", {}).get(deck_name, {})
	var raw: Variant = entry.get("remembered_def_ids", [])
	var result: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for value in raw:
			result.append(str(value))
	return result


## Returns remembered def_ids that are still present in the deck's current
## contents. Drops cards the player has since removed.
##
## current_contents: Dictionary[def_id → count] of the deck's current cards.
static func get_remembered_filtered(deck_name: String, current_contents: Dictionary) -> Array:
	var remembered := get_remembered(deck_name)
	if remembered.is_empty():
		return []
	var filtered: Array = []
	for def_id in remembered:
		if int(current_contents.get(def_id, 0)) > 0:
			filtered.append(def_id)
	return filtered


## Record that a match was played against deck_name. Updates remembered set:
##  1. Filter old remembered against current_contents (mutation cleanup).
##  2. Pick up to GROWTH_PER_MATCH new def_ids from observed_def_ids that are
##     in current_contents and not yet remembered.
##  3. Cap remembered set size at total cards in deck.
##  4. Increment matches_played; refresh last_seen_iso.
static func record_match(deck_name: String, observed_def_ids: Array, current_contents: Dictionary) -> void:
	if deck_name.is_empty():
		return
	var data := _load_raw()
	var decks: Dictionary = data.get("decks", {})
	var entry: Dictionary = decks.get(deck_name, {})
	var existing: Array = []
	var raw: Variant = entry.get("remembered_def_ids", [])
	if typeof(raw) == TYPE_ARRAY:
		for value in raw:
			existing.append(str(value))
	# Filter out removed cards.
	var kept: Array = []
	var kept_lookup: Dictionary = {}
	for def_id in existing:
		if int(current_contents.get(def_id, 0)) > 0 and not kept_lookup.has(def_id):
			kept.append(def_id)
			kept_lookup[def_id] = true
	# Compute deck size cap.
	var deck_size := 0
	for def_id in current_contents.keys():
		deck_size += int(current_contents[def_id])
	# Add up to GROWTH_PER_MATCH new def_ids from observed that match the deck.
	var added := 0
	for raw_def_id in observed_def_ids:
		if added >= GROWTH_PER_MATCH:
			break
		if kept.size() >= deck_size:
			break
		var def_id := str(raw_def_id)
		if def_id.is_empty():
			continue
		if kept_lookup.has(def_id):
			continue
		if int(current_contents.get(def_id, 0)) <= 0:
			continue
		kept.append(def_id)
		kept_lookup[def_id] = true
		added += 1
	entry["remembered_def_ids"] = kept
	entry["matches_played"] = int(entry.get("matches_played", 0)) + 1
	entry["last_seen_iso"] = Time.get_datetime_string_from_system()
	decks[deck_name] = entry
	data["decks"] = decks
	_save_raw(data)


static func forget_deck(deck_name: String) -> void:
	if deck_name.is_empty():
		return
	var data := _load_raw()
	var decks: Dictionary = data.get("decks", {})
	decks.erase(deck_name)
	data["decks"] = decks
	_save_raw(data)


static func forget_all() -> void:
	_save_raw({"decks": {}})
