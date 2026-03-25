extends SceneTree

const AdventureCatalogScript := preload("res://src/adventure/adventure_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_load_adventure()
	_test_load_all_adventures()
	_test_get_adventures_for_deck()
	_test_get_ordered_node_list()
	_test_get_graph_layers()
	_test_get_graph_layers_branching()
	_test_validate_adventure_valid()
	_test_validate_adventure_missing_fields()
	_test_validate_adventure_broken_links()
	_test_validate_adventure_new_node_types()
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

	var fake_adventures := AdventureCatalogScript.get_adventures_for_deck("nonexistent_deck")
	_assert(fake_adventures.size() == 0, "for_deck: nonexistent deck should get 0 adventures, got %d" % fake_adventures.size())


func _test_get_ordered_node_list() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var ordered := AdventureCatalogScript.get_ordered_node_list(adventure)
	# With branching, ordered follows first path: node_a -> node_b -> node_mini -> node_d -> node_e -> node_boss
	_assert(ordered.size() >= 4, "ordered_nodes: should have at least 4 nodes following first path, got %d" % ordered.size())
	_assert(str(ordered[0].get("id", "")) == "node_boon_start", "ordered_nodes: first should be node_boon_start")


func _test_get_graph_layers() -> void:
	# Test with a simple linear adventure
	var linear_adventure := {
		"start_node": "n1",
		"nodes": {
			"n1": {"type": "combat", "enemy_deck": "e1", "next": ["n2"]},
			"n2": {"type": "final_boss", "enemy_deck": "e2", "next": []},
		}
	}
	var layers := AdventureCatalogScript.get_graph_layers(linear_adventure)
	_assert(layers.size() == 2, "graph_layers_linear: should have 2 layers, got %d" % layers.size())
	_assert(layers[0].size() == 1, "graph_layers_linear: layer 0 should have 1 node")
	_assert(layers[1].size() == 1, "graph_layers_linear: layer 1 should have 1 node")


func _test_get_graph_layers_branching() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var layers := AdventureCatalogScript.get_graph_layers(adventure)
	# Expected layers: [node_boon_start], [node_a], [node_b, node_c], [node_mini], [node_boon], [node_d], [node_e, node_f], [node_boss]
	_assert(layers.size() == 8, "graph_layers_branch: should have 8 layers, got %d" % layers.size())
	_assert(layers[0].size() == 1, "graph_layers_branch: layer 0 should have 1 node (node_boon_start)")
	_assert(layers[1].size() == 1, "graph_layers_branch: layer 1 should have 1 node (node_a)")
	_assert(layers[2].size() == 2, "graph_layers_branch: layer 2 should have 2 nodes (branch)")
	_assert(layers[3].size() == 1, "graph_layers_branch: layer 3 should have 1 node (mini-boss)")
	_assert(layers[4].size() == 1, "graph_layers_branch: layer 4 should have 1 node (node_boon)")
	_assert(layers[5].size() == 1, "graph_layers_branch: layer 5 should have 1 node (node_d)")
	_assert(layers[6].size() == 2, "graph_layers_branch: layer 6 should have 2 nodes (branch)")
	_assert(layers[7].size() == 1, "graph_layers_branch: layer 7 should have 1 node (boss)")


func _test_validate_adventure_valid() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var result := AdventureCatalogScript.validate_adventure(adventure)
	_assert(result.get("is_valid", false) == true, "validate_valid: the_dragon_crisis should be valid")
	_assert(result.get("errors", []).size() == 0, "validate_valid: should have 0 errors, got: %s" % str(result.get("errors", [])))


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


func _test_validate_adventure_new_node_types() -> void:
	# Non-combat nodes should be valid without enemy_deck
	var adventure := {
		"id": "test_noncombat",
		"name": "Test Non-Combat",
		"start_node": "n1",
		"nodes": {
			"n1": {"type": "healer", "next": ["n2"]},
			"n2": {"type": "reinforcement", "next": ["n3"]},
			"n3": {"type": "shop", "next": []},
		}
	}
	var result := AdventureCatalogScript.validate_adventure(adventure)
	_assert(result.get("is_valid", false) == true, "validate_noncombat: non-combat nodes without enemy_deck should be valid, errors: %s" % str(result.get("errors", [])))


func _test_get_start_node() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var start_node := AdventureCatalogScript.get_start_node(adventure)
	_assert(not start_node.is_empty(), "start_node: should return a node")
	_assert(str(start_node.get("type", "")) == "boon", "start_node: first node should be boon")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
