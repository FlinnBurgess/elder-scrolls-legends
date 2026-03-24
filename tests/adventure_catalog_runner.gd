extends SceneTree

const AdventureCatalogScript := preload("res://src/adventure/adventure_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_load_adventure()
	_test_load_all_adventures()
	_test_get_adventures_for_deck()
	_test_get_ordered_node_list()
	_test_validate_adventure_valid()
	_test_validate_adventure_missing_fields()
	_test_validate_adventure_broken_links()
	_test_get_start_node()

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ADVENTURE_CATALOG_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_load_adventure() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	_assert(not adventure.is_empty(), "load_adventure: should load the_dragon_crisis")
	_assert(str(adventure.get("id", "")) == "the_dragon_crisis", "load_adventure: id should match")
	_assert(str(adventure.get("name", "")) == "The Dragon Crisis", "load_adventure: name should match")
	_assert(adventure.has("nodes"), "load_adventure: should have nodes")
	_assert(adventure.has("start_node"), "load_adventure: should have start_node")


func _test_load_all_adventures() -> void:
	var adventures := AdventureCatalogScript.load_all_adventures()
	_assert(adventures.size() >= 4, "load_all: should have at least 4 adventures, got %d" % adventures.size())
	var ids: Array = []
	for a in adventures:
		ids.append(str(a.get("id", "")))
	_assert("the_dragon_crisis" in ids, "load_all: should contain the_dragon_crisis")
	_assert("the_five_tenets" in ids, "load_all: should contain the_five_tenets")
	_assert("eye_of_magnus" in ids, "load_all: should contain eye_of_magnus")
	_assert("blood_of_sovngarde" in ids, "load_all: should contain blood_of_sovngarde")


func _test_get_adventures_for_deck() -> void:
	var dragon_adventures := AdventureCatalogScript.get_adventures_for_deck("dragons_of_skyrim")
	_assert(dragon_adventures.size() >= 1, "for_deck: dragons should have at least 1 adventure")
	var found := false
	for a in dragon_adventures:
		if str(a.get("id", "")) == "the_dragon_crisis":
			found = true
	_assert(found, "for_deck: dragons should have the_dragon_crisis")

	# A deck that doesn't match any specific adventure shouldn't get adventures with restricted allowed_deck_ids
	var fake_adventures := AdventureCatalogScript.get_adventures_for_deck("nonexistent_deck")
	# All current adventures have allowed_deck_ids set, so nonexistent deck should get none
	_assert(fake_adventures.size() == 0, "for_deck: nonexistent deck should get 0 adventures, got %d" % fake_adventures.size())


func _test_get_ordered_node_list() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var ordered := AdventureCatalogScript.get_ordered_node_list(adventure)
	_assert(ordered.size() == 6, "ordered_nodes: should have 6 nodes, got %d" % ordered.size())
	_assert(str(ordered[0].get("id", "")) == "node_1", "ordered_nodes: first should be node_1")
	_assert(str(ordered[5].get("id", "")) == "node_6", "ordered_nodes: last should be node_6")
	_assert(str(ordered[2].get("type", "")) == "mini_boss", "ordered_nodes: node_3 should be mini_boss")
	_assert(str(ordered[5].get("type", "")) == "final_boss", "ordered_nodes: node_6 should be final_boss")


func _test_validate_adventure_valid() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var result := AdventureCatalogScript.validate_adventure(adventure)
	_assert(result.get("is_valid", false) == true, "validate_valid: the_dragon_crisis should be valid")
	_assert(result.get("errors", []).size() == 0, "validate_valid: should have 0 errors")


func _test_validate_adventure_missing_fields() -> void:
	var bad_adventure := {"nodes": {}}
	var result := AdventureCatalogScript.validate_adventure(bad_adventure)
	_assert(result.get("is_valid", true) == false, "validate_missing: should be invalid")
	var errors: Array = result.get("errors", [])
	_assert(errors.size() >= 2, "validate_missing: should have multiple errors, got %d" % errors.size())


func _test_validate_adventure_broken_links() -> void:
	var bad_adventure := {
		"id": "test",
		"name": "Test",
		"start_node": "node_1",
		"nodes": {
			"node_1": {"type": "combat", "enemy_deck": "foo", "next": ["node_99"]},
		}
	}
	var result := AdventureCatalogScript.validate_adventure(bad_adventure)
	_assert(result.get("is_valid", true) == false, "validate_broken: should be invalid")
	var errors: Array = result.get("errors", [])
	var found_link_error := false
	for error in errors:
		if "node_99" in str(error):
			found_link_error = true
	_assert(found_link_error, "validate_broken: should report broken link to node_99")


func _test_get_start_node() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var start_node := AdventureCatalogScript.get_start_node(adventure)
	_assert(not start_node.is_empty(), "start_node: should return a node")
	_assert(str(start_node.get("type", "")) == "combat", "start_node: first node should be combat")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
