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
	_test_draft_progress_round_trip()
	_test_match_config_round_trip()
	_test_match_state_save_load_clear()
	_test_clear_run_also_clears_match_state()
	_test_backward_compat_old_save_format()
	_test_start_run_saves_immediately()

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


func _test_draft_progress_round_trip() -> void:
	_cleanup_test_files()

	var manager = ArenaRunManagerScript.new()
	manager.start_run(["strength", "intelligence"])
	manager.draft_progress = {
		"current_pick": 5,
		"deck": [{"card_id": "card_a", "quantity": 2}],
		"pick_options": ["card_x", "card_y", "card_z"],
		"is_bonus_pick": false,
		"total_picks": 30,
	}
	manager.save_run()

	var loaded = ArenaRunManagerScript.load_run()
	_assert(loaded != null, "draft_progress_rt: loaded should not be null")
	if loaded == null:
		return
	_assert(loaded.draft_progress != null, "draft_progress_rt: draft_progress should not be null")
	_assert(int(loaded.draft_progress["current_pick"]) == 5, "draft_progress_rt: current_pick should be 5")
	_assert(Array(loaded.draft_progress["pick_options"]).size() == 3, "draft_progress_rt: pick_options should have 3 entries")

	# complete_draft should clear draft_progress
	manager.complete_draft([{"card_id": "card_a", "quantity": 2}])
	var loaded2 = ArenaRunManagerScript.load_run()
	_assert(loaded2.draft_progress == null, "draft_progress_rt: draft_progress should be null after complete_draft")

	_cleanup_test_files()


func _test_match_config_round_trip() -> void:
	_cleanup_test_files()

	var manager = ArenaRunManagerScript.new()
	manager.start_run(["agility", "endurance"])
	manager.complete_draft([{"card_id": "c1", "quantity": 1}])
	manager.start_match()
	manager.match_config = {
		"opponent_attribute_ids": ["strength", "willpower"],
		"ai_deck": [{"card_id": "ai_c1", "quantity": 2}],
		"boss_config": {},
		"match_seed": 12345,
		"first_player_index": 0,
	}
	manager.save_run()

	var loaded = ArenaRunManagerScript.load_run()
	_assert(loaded != null, "match_config_rt: loaded should not be null")
	if loaded == null:
		return
	_assert(loaded.match_config != null, "match_config_rt: match_config should not be null")
	_assert(int(loaded.match_config["match_seed"]) == 12345, "match_config_rt: match_seed should be 12345")
	_assert(int(loaded.match_config["first_player_index"]) == 0, "match_config_rt: first_player_index should be 0")

	# record_win should clear match_config
	manager.record_win()
	var loaded2 = ArenaRunManagerScript.load_run()
	_assert(loaded2.match_config == null, "match_config_rt: match_config should be null after record_win")

	_cleanup_test_files()


func _test_match_state_save_load_clear() -> void:
	_cleanup_test_files()

	var manager = ArenaRunManagerScript.new()
	manager.start_run(["strength", "agility"])

	var test_state := {"phase": "action", "turn_number": 3, "winner_player_id": ""}
	manager.save_match_state(test_state)

	_assert(ArenaRunManagerScript.has_saved_match_state() == true, "match_state_slc: should have saved match state")

	var loaded := ArenaRunManagerScript.load_match_state()
	_assert(not loaded.is_empty(), "match_state_slc: loaded state should not be empty")
	_assert(str(loaded.get("phase", "")) == "action", "match_state_slc: phase should be action")
	_assert(int(loaded.get("turn_number", 0)) == 3, "match_state_slc: turn_number should be 3")

	manager.clear_match_state()
	_assert(ArenaRunManagerScript.has_saved_match_state() == false, "match_state_slc: should not have match state after clear")

	_cleanup_test_files()


func _test_clear_run_also_clears_match_state() -> void:
	_cleanup_test_files()

	var manager = ArenaRunManagerScript.new()
	manager.start_run(["intelligence", "willpower"])
	manager.complete_draft([{"card_id": "c1", "quantity": 1}])
	manager.save_match_state({"phase": "action"})

	_assert(ArenaRunManagerScript.has_saved_match_state() == true, "clear_run_ms: should have match state before clear")

	manager.clear_run()
	_assert(ArenaRunManagerScript.has_active_run() == false, "clear_run_ms: should not have active run after clear")
	_assert(ArenaRunManagerScript.has_saved_match_state() == false, "clear_run_ms: should not have match state after clear_run")

	_cleanup_test_files()


func _test_backward_compat_old_save_format() -> void:
	_cleanup_test_files()

	# Write a run.json without draft_progress or match_config (old format)
	if not DirAccess.dir_exists_absolute("user://arena/"):
		DirAccess.make_dir_recursive_absolute("user://arena/")
	var file := FileAccess.open("user://arena/run.json", FileAccess.WRITE)
	var json_str := JSON.stringify({
		"state": ArenaRunManagerScript.State.READY_FOR_MATCH,
		"class_attributes": ["strength", "agility"],
		"deck": [{"card_id": "c1", "quantity": 1}],
		"wins": 2,
		"losses": 1,
		"current_match": 4,
		"boss_relic": null,
		"used_opponent_attributes": [],
	}, "\t")
	file.store_string(json_str)
	file.close()

	var loaded = ArenaRunManagerScript.load_run()
	_assert(loaded != null, "backward_compat: loaded should not be null")
	if loaded == null:
		return
	_assert(loaded.draft_progress == null, "backward_compat: draft_progress should default to null")
	_assert(loaded.match_config == null, "backward_compat: match_config should default to null")
	_assert(loaded.wins == 2, "backward_compat: wins should be 2")

	_cleanup_test_files()


func _test_start_run_saves_immediately() -> void:
	_cleanup_test_files()

	var manager = ArenaRunManagerScript.new()
	_assert(ArenaRunManagerScript.has_active_run() == false, "start_run_save: no run before start")

	manager.start_run(["willpower", "endurance"])
	_assert(ArenaRunManagerScript.has_active_run() == true, "start_run_save: should have active run immediately after start_run")

	var loaded = ArenaRunManagerScript.load_run()
	_assert(loaded != null, "start_run_save: loaded should not be null")
	_assert(loaded.state == ArenaRunManagerScript.State.DRAFTING, "start_run_save: state should be DRAFTING")

	_cleanup_test_files()


func _cleanup_test_files() -> void:
	var dir := DirAccess.open("user://arena/")
	if dir != null:
		if FileAccess.file_exists("user://arena/run.json"):
			dir.remove("run.json")
		if FileAccess.file_exists("user://arena/match_state.json"):
			dir.remove("match_state.json")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
