extends SceneTree

const AdventureRunManagerScript := preload("res://src/adventure/adventure_run_manager.gd")
const AdventureCatalogScript := preload("res://src/adventure/adventure_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_cleanup_test_files()

	_test_start_run()
	_test_full_winning_run()
	_test_loss_with_revive()
	_test_loss_without_revive()
	_test_save_load_round_trip()
	_test_has_active_run()
	_test_abandon_run()
	_test_match_state_save_load_clear()
	_test_clear_run_also_clears_match_state()

	_cleanup_test_files()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ADVENTURE_RUN_MANAGER_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_start_run() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_1")
	_assert(manager.state == AdventureRunManagerScript.State.VIEWING_MAP, "start_run: state should be VIEWING_MAP")
	_assert(manager.adventure_id == "the_dragon_crisis", "start_run: adventure_id should match")
	_assert(manager.deck_id == "dragons_of_skyrim", "start_run: deck_id should match")
	_assert(manager.current_node_id == "node_1", "start_run: current_node_id should be node_1")
	_assert(manager.revives_remaining == 1, "start_run: should have 1 revive")
	_assert(manager.completed_node_ids.is_empty(), "start_run: no completed nodes")
	_cleanup_test_files()


func _test_full_winning_run() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	_assert(not adventure.is_empty(), "full_win: should load adventure")

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_1")

	# Win all 6 nodes
	for i in range(6):
		var node_id := "node_%d" % (i + 1)
		_assert(manager.current_node_id == node_id, "full_win: should be on %s, got %s" % [node_id, manager.current_node_id])
		manager.start_match()
		_assert(manager.state == AdventureRunManagerScript.State.IN_MATCH, "full_win: should be IN_MATCH for %s" % node_id)
		manager.record_win(adventure)

	_assert(manager.state == AdventureRunManagerScript.State.RUN_COMPLETE, "full_win: should be RUN_COMPLETE")
	_assert(manager.run_won == true, "full_win: run_won should be true")
	_assert(manager.completed_node_ids.size() == 6, "full_win: should have 6 completed nodes, got %d" % manager.completed_node_ids.size())
	_cleanup_test_files()


func _test_loss_with_revive() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_1")

	# Win node 1
	manager.start_match()
	manager.record_win(adventure)
	_assert(manager.current_node_id == "node_2", "revive: should advance to node_2")

	# Lose node 2 (should use revive)
	manager.start_match()
	manager.record_loss()
	_assert(manager.state == AdventureRunManagerScript.State.VIEWING_MAP, "revive: should be back on map")
	_assert(manager.revives_remaining == 0, "revive: should have 0 revives")
	_assert(manager.current_node_id == "node_2", "revive: should still be on node_2")

	# Win node 2 after retry
	manager.start_match()
	manager.record_win(adventure)
	_assert(manager.current_node_id == "node_3", "revive: should advance to node_3")
	_cleanup_test_files()


func _test_loss_without_revive() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_1")

	# Use up revive
	manager.start_match()
	manager.record_loss()
	_assert(manager.revives_remaining == 0, "no_revive: should have 0 revives after first loss")

	# Lose again — run should end
	manager.start_match()
	manager.record_loss()
	_assert(manager.state == AdventureRunManagerScript.State.RUN_COMPLETE, "no_revive: should be RUN_COMPLETE")
	_assert(manager.run_won == false, "no_revive: run_won should be false")
	_cleanup_test_files()


func _test_save_load_round_trip() -> void:
	_cleanup_test_files()

	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var manager = AdventureRunManagerScript.new()
	var deck := [{"card_id": "c1", "quantity": 2}, {"card_id": "c2", "quantity": 1}]
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", deck, "node_1")

	# Win first node
	manager.start_match()
	manager.record_win(adventure)

	# Load and verify
	var loaded = AdventureRunManagerScript.load_run()
	_assert(loaded != null, "save_load: loaded should not be null")
	if loaded == null:
		return
	_assert(loaded.state == AdventureRunManagerScript.State.VIEWING_MAP, "save_load: state should be VIEWING_MAP, got %d" % loaded.state)
	_assert(loaded.adventure_id == "the_dragon_crisis", "save_load: adventure_id should match")
	_assert(loaded.deck_id == "dragons_of_skyrim", "save_load: deck_id should match")
	_assert(loaded.current_node_id == "node_2", "save_load: should be on node_2")
	_assert(loaded.completed_node_ids.size() == 1, "save_load: should have 1 completed node")
	_assert(loaded.revives_remaining == 1, "save_load: should have 1 revive")
	_assert(loaded.deck_cards.size() == 2, "save_load: should have 2 deck entries")
	_cleanup_test_files()


func _test_has_active_run() -> void:
	_cleanup_test_files()

	_assert(AdventureRunManagerScript.has_active_run() == false, "has_active: should be false initially")

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_1")
	_assert(AdventureRunManagerScript.has_active_run() == true, "has_active: should be true after start")

	manager.clear_run()
	_assert(AdventureRunManagerScript.has_active_run() == false, "has_active: should be false after clear")
	_cleanup_test_files()


func _test_abandon_run() -> void:
	_cleanup_test_files()

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_1")
	_assert(AdventureRunManagerScript.has_active_run() == true, "abandon: should have active run")

	manager.abandon_run()
	_assert(manager.state == AdventureRunManagerScript.State.RUN_COMPLETE, "abandon: state should be RUN_COMPLETE")
	_assert(manager.run_won == false, "abandon: run_won should be false")
	_assert(AdventureRunManagerScript.has_active_run() == false, "abandon: should not have active run")
	_cleanup_test_files()


func _test_match_state_save_load_clear() -> void:
	_cleanup_test_files()

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_1")

	var test_state := {"phase": "action", "turn_number": 5}
	manager.save_match_state(test_state)
	_assert(AdventureRunManagerScript.has_saved_match_state() == true, "match_state: should have saved state")

	var loaded := AdventureRunManagerScript.load_match_state()
	_assert(not loaded.is_empty(), "match_state: loaded should not be empty")
	_assert(str(loaded.get("phase", "")) == "action", "match_state: phase should be action")
	_assert(int(loaded.get("turn_number", 0)) == 5, "match_state: turn should be 5")

	manager.clear_match_state()
	_assert(AdventureRunManagerScript.has_saved_match_state() == false, "match_state: should be cleared")
	_cleanup_test_files()


func _test_clear_run_also_clears_match_state() -> void:
	_cleanup_test_files()

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_1")
	manager.save_match_state({"phase": "action"})
	_assert(AdventureRunManagerScript.has_saved_match_state() == true, "clear_run_ms: should have match state")

	manager.clear_run()
	_assert(AdventureRunManagerScript.has_active_run() == false, "clear_run_ms: no active run")
	_assert(AdventureRunManagerScript.has_saved_match_state() == false, "clear_run_ms: no match state")
	_cleanup_test_files()


func _cleanup_test_files() -> void:
	var dir := DirAccess.open("user://adventure/")
	if dir != null:
		if FileAccess.file_exists("user://adventure/run.json"):
			dir.remove("run.json")
		if FileAccess.file_exists("user://adventure/match_state.json"):
			dir.remove("match_state.json")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
