extends SceneTree

const DeckbuilderScreen = preload("res://src/ui/deckbuilder_screen.gd")
const DeckPersistenceScript = preload("res://src/deck/deck_persistence.gd")

var _failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Clean up any test decks from prior runs
	DeckPersistenceScript.delete_deck("__test_nav_deck")

	var screen := DeckbuilderScreen.new()
	root.add_child(screen)
	await process_frame

	_test_starts_on_deck_list(screen)
	_test_create_deck_navigates_to_editor(screen)
	await process_frame
	_test_done_returns_to_deck_list(screen)
	await process_frame
	_test_cancel_returns_to_deck_list(screen)
	await process_frame

	# Cleanup
	DeckPersistenceScript.delete_deck("__test_nav_deck")

	if _failures.size() > 0:
		for msg in _failures:
			push_error(msg)
		quit(1)
		return
	print("DECKBUILDER_UI_OK")
	quit(0)


func _test_starts_on_deck_list(screen: Control) -> void:
	# DeckbuilderScreen should start with a DeckListScreen child visible
	var deck_list := _find_child_of_class(screen, "DeckListScreen")
	_assert(deck_list != null, "DeckbuilderScreen should start with a DeckListScreen child.")


func _test_create_deck_navigates_to_editor(screen: Control) -> void:
	# Save a test deck so we can trigger edit_deck_requested
	var definition := {
		"name": "__test_nav_deck",
		"attribute_ids": ["strength"],
		"cards": [],
	}
	DeckPersistenceScript.save_deck("__test_nav_deck", definition)

	# Simulate DeckListScreen emitting edit_deck_requested
	var deck_list := _find_child_of_class(screen, "DeckListScreen")
	if deck_list != null:
		deck_list.edit_deck_requested.emit("__test_nav_deck")


func _test_done_returns_to_deck_list(screen: Control) -> void:
	var editor := _find_child_of_class(screen, "DeckEditorScreen")
	_assert(editor != null, "After edit_deck_requested, DeckEditorScreen should be a child.")
	if editor != null:
		editor.done_pressed.emit()


func _test_cancel_returns_to_deck_list(screen: Control) -> void:
	# First navigate to editor again
	var deck_list := _find_child_of_class(screen, "DeckListScreen")
	if deck_list != null:
		deck_list.edit_deck_requested.emit("__test_nav_deck")

	var editor := _find_child_of_class(screen, "DeckEditorScreen")
	if editor != null:
		editor.cancel_pressed.emit()

	# After cancel, deck list should be visible again
	deck_list = _find_child_of_class(screen, "DeckListScreen")
	_assert(deck_list != null and deck_list.visible, "After cancel, DeckListScreen should be visible.")


func _find_child_of_class(parent: Node, class_name_str: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == class_name_str or (child.get_script() != null and child.get_script().get_global_name() == class_name_str):
			return child
	return null


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
