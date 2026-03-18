extends SceneTree

const DeckPersistenceScript := preload("res://src/deck/deck_persistence.gd")

var _failures: Array[String] = []

const TEST_PREFIX := "__test_dp_"


func _initialize() -> void:
	_cleanup_test_decks()
	_test_save_load_round_trip()
	_test_list_decks()
	_test_delete_deck()
	_test_load_nonexistent()
	_test_save_overwrites()
	_cleanup_test_decks()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("DECK_PERSISTENCE_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_save_load_round_trip() -> void:
	var deck_name := TEST_PREFIX + "round_trip"
	var definition := _make_definition(["strength", "intelligence"], [
		{"card_id": "card_a", "quantity": 3},
		{"card_id": "card_b", "quantity": 1},
	])
	DeckPersistenceScript.save_deck(deck_name, definition)
	var loaded: Dictionary = DeckPersistenceScript.load_deck(deck_name)

	_assert(loaded.size() > 0, "Round-trip: loaded deck should not be empty")
	_assert(loaded.get("name") == deck_name, "Round-trip: loaded name should match '%s', got '%s'" % [deck_name, loaded.get("name", "")])

	var loaded_attrs: Array = loaded.get("attribute_ids", [])
	_assert(loaded_attrs.size() == 2, "Round-trip: expected 2 attributes, got %d" % loaded_attrs.size())
	_assert("strength" in loaded_attrs, "Round-trip: expected 'strength' in attributes")
	_assert("intelligence" in loaded_attrs, "Round-trip: expected 'intelligence' in attributes")

	var loaded_cards: Array = loaded.get("cards", [])
	_assert(loaded_cards.size() == 2, "Round-trip: expected 2 card entries, got %d" % loaded_cards.size())
	var first_card: Dictionary = loaded_cards[0] if loaded_cards.size() > 0 else {}
	_assert(first_card.get("card_id") == "card_a", "Round-trip: first card should be 'card_a'")
	_assert(first_card.get("quantity") == 3, "Round-trip: first card quantity should be 3")


func _test_list_decks() -> void:
	var name_a := TEST_PREFIX + "list_alpha"
	var name_b := TEST_PREFIX + "list_beta"
	DeckPersistenceScript.save_deck(name_a, _make_definition(["strength"], []))
	DeckPersistenceScript.save_deck(name_b, _make_definition(["intelligence"], []))

	var names: Array[String] = DeckPersistenceScript.list_decks()

	var sanitized_a := name_a.to_lower().strip_edges()
	var sanitized_b := name_b.to_lower().strip_edges()

	_assert(sanitized_a in names, "List: expected '%s' in deck list" % sanitized_a)
	_assert(sanitized_b in names, "List: expected '%s' in deck list" % sanitized_b)


func _test_delete_deck() -> void:
	var deck_name := TEST_PREFIX + "to_delete"
	DeckPersistenceScript.save_deck(deck_name, _make_definition([], []))

	var result: bool = DeckPersistenceScript.delete_deck(deck_name)
	_assert(result == true, "Delete: should return true for existing deck")

	var loaded: Dictionary = DeckPersistenceScript.load_deck(deck_name)
	_assert(loaded.is_empty(), "Delete: loading deleted deck should return empty dictionary")

	var names: Array[String] = DeckPersistenceScript.list_decks()
	var sanitized := deck_name.to_lower().strip_edges()
	_assert(sanitized not in names, "Delete: deleted deck should not appear in list_decks")

	var result_again: bool = DeckPersistenceScript.delete_deck(deck_name)
	_assert(result_again == false, "Delete: should return false for non-existent deck")


func _test_load_nonexistent() -> void:
	var loaded: Dictionary = DeckPersistenceScript.load_deck(TEST_PREFIX + "does_not_exist")
	_assert(loaded.is_empty(), "Nonexistent: loading non-existent deck should return empty dictionary")


func _test_save_overwrites() -> void:
	var deck_name := TEST_PREFIX + "overwrite"
	var original := _make_definition(["strength"], [{"card_id": "old_card", "quantity": 1}])
	DeckPersistenceScript.save_deck(deck_name, original)

	var updated := _make_definition(["intelligence", "agility"], [
		{"card_id": "new_card_a", "quantity": 2},
		{"card_id": "new_card_b", "quantity": 3},
	])
	DeckPersistenceScript.save_deck(deck_name, updated)

	var loaded: Dictionary = DeckPersistenceScript.load_deck(deck_name)
	var loaded_attrs: Array = loaded.get("attribute_ids", [])
	_assert(loaded_attrs.size() == 2, "Overwrite: expected 2 attributes after overwrite, got %d" % loaded_attrs.size())
	_assert("intelligence" in loaded_attrs, "Overwrite: expected 'intelligence' in attributes after overwrite")
	_assert("agility" in loaded_attrs, "Overwrite: expected 'agility' in attributes after overwrite")

	var loaded_cards: Array = loaded.get("cards", [])
	_assert(loaded_cards.size() == 2, "Overwrite: expected 2 card entries after overwrite, got %d" % loaded_cards.size())
	var first_card: Dictionary = loaded_cards[0] if loaded_cards.size() > 0 else {}
	_assert(first_card.get("card_id") == "new_card_a", "Overwrite: first card should be 'new_card_a' after overwrite")


func _make_definition(attribute_ids: Array, cards: Array) -> Dictionary:
	return {
		"attribute_ids": attribute_ids,
		"cards": cards,
	}


func _cleanup_test_decks() -> void:
	var names: Array[String] = DeckPersistenceScript.list_decks()
	for deck_name in names:
		if deck_name.begins_with(TEST_PREFIX):
			DeckPersistenceScript.delete_deck(deck_name)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
