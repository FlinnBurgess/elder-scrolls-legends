class_name AdventureDeckLoader
extends RefCounted

const PLAYER_DECKS_DIR := "res://data/decks/adventure/"
const ENEMY_DECKS_DIR := "res://data/decks/adventure/enemies/"


static func load_player_deck(deck_id: String) -> Dictionary:
	return _find_deck_by_id(PLAYER_DECKS_DIR, deck_id)


static func load_enemy_deck(deck_id: String) -> Dictionary:
	return _find_deck_by_id(ENEMY_DECKS_DIR, deck_id)


static func list_player_decks() -> Array:
	return _list_decks_in_dir(PLAYER_DECKS_DIR)


static func deck_to_card_ids(deck_cards: Array) -> Array:
	var ids: Array = []
	for entry in deck_cards:
		var card_id: String = str(entry.get("card_id", ""))
		var quantity: int = int(entry.get("quantity", 0))
		for _i in range(quantity):
			ids.append(card_id)
	return ids


static func _find_deck_by_id(dir_path: String, deck_id: String) -> Dictionary:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("AdventureDeckLoader: cannot open directory '%s'" % dir_path)
		return {}
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			var data := _load_json_file(dir_path + file_name)
			if str(data.get("deck_id", "")) == deck_id:
				return data
		file_name = dir.get_next()
	dir.list_dir_end()
	push_error("AdventureDeckLoader: deck '%s' not found in '%s'" % [deck_id, dir_path])
	return {}


static func _list_decks_in_dir(dir_path: String) -> Array:
	var decks: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("AdventureDeckLoader: cannot open directory '%s'" % dir_path)
		return decks
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			var data := _load_json_file(dir_path + file_name)
			if not data.is_empty():
				decks.append(data)
		file_name = dir.get_next()
	dir.list_dir_end()
	return decks


static func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
