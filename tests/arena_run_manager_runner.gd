extends SceneTree

const ArenaRunManagerScript := preload("res://src/arena/arena_run_manager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	# Clean up any leftover test files before starting
	_cleanup_test_files()

	_test_full_winning_run()
	_test_3_loss_run()
	_test_3rd_loss_on_boss()
	_test_opponent_deck_size_increases()
	_test_save_load_round_trip()
	_test_has_active_run()
	_test_abandon_run_clears_state()

	# Final cleanup
	_cleanup_test_files()

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ARENA_RUN_MANAGER_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_full_winning_run() -> void:
	# start -> draft -> 8 wins with picks -> boss win -> RUN_COMPLETE
	var manager = ArenaRunManagerScript.new()
	manager.start_run(["strength", "intelligence"])
	_assert(manager.state == ArenaRunManagerScript.State.DRAFTING, "full_win: state should be DRAFTING after start_run")

	var dummy_deck: Array = [{"card_id": "card_a", "quantity": 3}, {"card_id": "card_b", "quantity": 3}]
	manager.complete_draft(dummy_deck)
	_assert(manager.state == ArenaRunManagerScript.State.READY_FOR_MATCH, "full_win: state should be READY_FOR_MATCH after draft")

	# Win matches 1-8 with post-match picks
	for i in range(8):
		_assert(manager.state == ArenaRunManagerScript.State.READY_FOR_MATCH, "full_win: state should be READY_FOR_MATCH before match %d" % (i + 1))
		var config: Dictionary = manager.start_match()
		_assert(manager.state == ArenaRunManagerScript.State.IN_MATCH, "full_win: state should be IN_MATCH during match %d" % (i + 1))
		_assert(config.has("attribute_ids"), "full_win: config should have attribute_ids")
		_assert(config.has("deck_size"), "full_win: config should have deck_size")

		manager.record_win()
		_assert(manager.state == ArenaRunManagerScript.State.POST_MATCH_PICK, "full_win: state should be POST_MATCH_PICK after win %d" % (i + 1))

		manager.complete_post_match_pick({"card_id": "bonus_card_%d" % i})
		_assert(manager.state == ArenaRunManagerScript.State.READY_FOR_MATCH, "full_win: state should be READY_FOR_MATCH after post-match pick %d" % (i + 1))

	# Boss match (match 9) - win should complete the run
	var boss_config: Dictionary = manager.start_match()
	_assert(manager.state == ArenaRunManagerScript.State.IN_MATCH, "full_win: state should be IN_MATCH for boss")

	manager.record_win()
	_assert(manager.state == ArenaRunManagerScript.State.RUN_COMPLETE, "full_win: state should be RUN_COMPLETE after boss win")
	_assert(manager.wins == 9, "full_win: should have 9 wins, got %d" % manager.wins)
	_assert(manager.losses == 0, "full_win: should have 0 losses, got %d" % manager.losses)


func _test_3_loss_run() -> void:
	var manager = ArenaRunManagerScript.new()
	manager.start_run(["strength", "agility"])

	var dummy_deck: Array = [{"card_id": "card_a", "quantity": 3}]
	manager.complete_draft(dummy_deck)

	# Win 2, lose 1, win 1, lose 1, lose 1 -> RUN_COMPLETE
	# Match 1: win
	manager.start_match()
	manager.record_win()
	manager.complete_post_match_pick({"card_id": "pick_1"})

	# Match 2: win
	manager.start_match()
	manager.record_win()
	manager.complete_post_match_pick({"card_id": "pick_2"})

	# Match 3: loss
	manager.start_match()
	manager.record_loss()
	_assert(manager.state == ArenaRunManagerScript.State.READY_FOR_MATCH, "3_loss: should be READY_FOR_MATCH after 1st loss")

	# Match 4: win
	manager.start_match()
	manager.record_win()
	manager.complete_post_match_pick({"card_id": "pick_3"})

	# Match 5: loss
	manager.start_match()
	manager.record_loss()
	_assert(manager.state == ArenaRunManagerScript.State.READY_FOR_MATCH, "3_loss: should be READY_FOR_MATCH after 2nd loss")

	# Match 6: loss -> 3rd loss, run complete
	manager.start_match()
	manager.record_loss()
	_assert(manager.state == ArenaRunManagerScript.State.RUN_COMPLETE, "3_loss: should be RUN_COMPLETE after 3rd loss")
	_assert(manager.wins == 3, "3_loss: should have 3 wins, got %d" % manager.wins)
	_assert(manager.losses == 3, "3_loss: should have 3 losses, got %d" % manager.losses)


func _test_3rd_loss_on_boss() -> void:
	var manager = ArenaRunManagerScript.new()
	manager.start_run(["intelligence", "willpower"])

	var dummy_deck: Array = [{"card_id": "card_a", "quantity": 3}]
	manager.complete_draft(dummy_deck)

	# Win 6, lose 2, then play to boss and lose
	for i in range(6):
		manager.start_match()
		manager.record_win()
		manager.complete_post_match_pick({"card_id": "pick_%d" % i})

	# 2 losses
	manager.start_match()
	manager.record_loss()
	manager.start_match()
	manager.record_loss()

	# Boss match (match 9) - lose for 3rd loss
	_assert(manager.current_match == 9, "boss_loss: should be on match 9, got %d" % manager.current_match)
	manager.start_match()
	manager.record_loss()
	_assert(manager.state == ArenaRunManagerScript.State.RUN_COMPLETE, "boss_loss: should be RUN_COMPLETE after 3rd loss on boss")
	_assert(manager.wins == 6, "boss_loss: should have 6 wins, got %d" % manager.wins)
	_assert(manager.losses == 3, "boss_loss: should have 3 losses, got %d" % manager.losses)


func _test_opponent_deck_size_increases() -> void:
	var manager = ArenaRunManagerScript.new()
	manager.start_run(["strength", "endurance"])

	var dummy_deck: Array = [{"card_id": "card_a", "quantity": 3}]
	manager.complete_draft(dummy_deck)

	# Check deck sizes for matches 1-3
	var config_1: Dictionary = manager.start_match()
	_assert(config_1["deck_size"] == 30, "deck_size: match 1 should be 30, got %d" % config_1["deck_size"])
	manager.record_win()
	manager.complete_post_match_pick({"card_id": "pick_1"})

	var config_2: Dictionary = manager.start_match()
	_assert(config_2["deck_size"] == 31, "deck_size: match 2 should be 31, got %d" % config_2["deck_size"])
	manager.record_win()
	manager.complete_post_match_pick({"card_id": "pick_2"})

	var config_3: Dictionary = manager.start_match()
	_assert(config_3["deck_size"] == 32, "deck_size: match 3 should be 32, got %d" % config_3["deck_size"])


func _test_save_load_round_trip() -> void:
	_cleanup_test_files()

	var manager = ArenaRunManagerScript.new()
	manager.start_run(["agility", "endurance"])

	var dummy_deck: Array = [{"card_id": "card_x", "quantity": 2}, {"card_id": "card_y", "quantity": 1}]
	manager.complete_draft(dummy_deck)  # This auto-saves

	# Win a match and do a post-match pick to get more state
	manager.start_match()
	manager.record_win()  # auto-saves
	manager.complete_post_match_pick({"card_id": "bonus_z"})  # auto-saves

	# Now load the run
	var loaded = ArenaRunManagerScript.load_run()
	_assert(loaded != null, "save_load: loaded run should not be null")
	if loaded == null:
		return

	_assert(loaded.state == ArenaRunManagerScript.State.READY_FOR_MATCH, "save_load: state should be READY_FOR_MATCH, got %d" % loaded.state)
	_assert(loaded.wins == 1, "save_load: wins should be 1, got %d" % loaded.wins)
	_assert(loaded.losses == 0, "save_load: losses should be 0, got %d" % loaded.losses)
	_assert(loaded.current_match == 2, "save_load: current_match should be 2, got %d" % loaded.current_match)

	# Check class attributes preserved
	_assert(loaded.class_attributes.size() == 2, "save_load: class_attributes should have 2 entries")
	_assert("agility" in loaded.class_attributes, "save_load: class_attributes should contain agility")
	_assert("endurance" in loaded.class_attributes, "save_load: class_attributes should contain endurance")

	# Check deck preserved (should have original + bonus pick)
	var total_cards := 0
	for entry in loaded.deck:
		total_cards += entry.get("quantity", 0)
	_assert(total_cards == 4, "save_load: deck should have 4 total cards (2+1 original + 1 bonus), got %d" % total_cards)

	_cleanup_test_files()


func _test_has_active_run() -> void:
	_cleanup_test_files()

	# No file -> false
	var result_before: bool = ArenaRunManagerScript.has_active_run()
	_assert(result_before == false, "has_active_run: should be false when no file exists")

	# Save a run -> true
	var manager = ArenaRunManagerScript.new()
	manager.start_run(["strength", "willpower"])
	manager.complete_draft([{"card_id": "c1", "quantity": 1}])  # auto-saves

	var result_after: bool = ArenaRunManagerScript.has_active_run()
	_assert(result_after == true, "has_active_run: should be true after save")

	# Clear -> false
	manager.clear_run()
	var result_cleared: bool = ArenaRunManagerScript.has_active_run()
	_assert(result_cleared == false, "has_active_run: should be false after clear")

	_cleanup_test_files()


func _test_abandon_run_clears_state() -> void:
	_cleanup_test_files()

	var manager = ArenaRunManagerScript.new()
	manager.start_run(["willpower", "agility"])
	manager.complete_draft([{"card_id": "c1", "quantity": 1}])  # auto-saves

	_assert(ArenaRunManagerScript.has_active_run() == true, "abandon: should have active run before abandon")

	manager.abandon_run()
	_assert(manager.state == ArenaRunManagerScript.State.RUN_COMPLETE, "abandon: state should be RUN_COMPLETE after abandon")
	_assert(ArenaRunManagerScript.has_active_run() == false, "abandon: should have no active run after abandon")

	_cleanup_test_files()


func _cleanup_test_files() -> void:
	if FileAccess.file_exists("user://arena/run.json"):
		var dir := DirAccess.open("user://arena/")
		if dir != null:
			dir.remove("run.json")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
