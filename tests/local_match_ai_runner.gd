extends SceneTree

const MatchScreen = preload("res://src/ui/match_screen.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := MatchScreen.new()
	root.add_child(screen)
	await process_frame
	if not await _run_all_tests(screen):
		await create_timer(4.0).timeout
		quit(1)
		return
	await create_timer(4.0).timeout
	print("LOCAL_MATCH_AI_OK")
	quit(0)


func _run_all_tests(screen: MatchScreen) -> bool:
	if not await _test_ai_turn_executes_and_returns_control(screen):
		return false
	await create_timer(3.0).timeout
	return await _test_human_prophecy_interrupt_pauses_and_resumes_ai(screen)


func _test_ai_turn_executes_and_returns_control(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for AI orchestration verification."):
		return false
	if not _assert(screen.end_turn_action(), "Ending the local player's turn should succeed."):
		return false
	var locked_state := screen.get_interaction_state()
	var ai_player_after_turn_start := _player_state(screen.get_match_state(), "player_2").duplicate(true)
	var ai_lane_count_after_turn_start := _count_lane_cards(screen.get_match_state(), "player_2")
	var status_after_turn_start := screen.get_status_message()
	var ai_status_changed := false
	for _index in range(12):
		await process_frame
		if screen.get_status_message() != status_after_turn_start:
			ai_status_changed = true
		if _active_player_id(screen.get_match_state()) == "player_1":
			break
	var ai_player_after_actions := _player_state(screen.get_match_state(), "player_2")
	var ai_visible_change: bool = (
		int(ai_player_after_actions.get("ring_of_magicka_charges", 0)) != int(ai_player_after_turn_start.get("ring_of_magicka_charges", 0)) or
		int(ai_player_after_actions.get("temporary_magicka", 0)) != int(ai_player_after_turn_start.get("temporary_magicka", 0)) or
		ai_player_after_actions.get("hand", []).size() != ai_player_after_turn_start.get("hand", []).size() or
		_count_lane_cards(screen.get_match_state(), "player_2") != ai_lane_count_after_turn_start
	)
	var final_state := screen.get_interaction_state()
	return (
		_assert(bool(locked_state.get("local_controls_locked", false)), "Local controls should lock as soon as the AI turn begins.") and
		_assert(ai_status_changed, "AI turn execution should update the visible status line after the human ends turn.") and
		_assert(ai_visible_change or _active_player_id(screen.get_match_state()) == "player_1", "AI should take at least one visible/legal action or finish the turn cleanly.") and
		_assert(_active_player_id(screen.get_match_state()) == "player_1", "Control should return to the human after the AI turn completes.") and
		_assert(not bool(final_state.get("local_controls_locked", true)), "Local controls should unlock again after the AI turn completes.")
	)


func _test_human_prophecy_interrupt_pauses_and_resumes_ai(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for Prophecy interrupt verification."):
		return false
	var match_state := screen.get_match_state()
	var player_one := _player_state(match_state, "player_1")
	var player_two := _player_state(match_state, "player_2")
	if player_one.is_empty() or player_two.is_empty():
		return _assert(false, "Expected both local-match players to exist.")
	player_two["hand"] = []
	player_two["support"] = []
	player_two["has_ring_of_magicka"] = false
	player_two["ring_of_magicka_charges"] = 0
	player_two["ring_of_magicka_used_this_turn"] = true
	player_one["health"] = 16
	player_one["rune_thresholds"] = [15, 10, 5]
	player_one["hand"] = []
	ScenarioFixtures.set_deck_cards(player_one, [ScenarioFixtures.make_card("player_1", "interrupt_guard", {
		"name": "Interrupt Guard",
		"zone": "deck",
		"card_type": "creature",
		"cost": 2,
		"power": 3,
		"health": 3,
		"keywords": ["guard"],
		"rules_tags": [MatchTiming.RULE_TAG_PROPHECY],
	})])
	_clear_lane_cards(match_state, "player_1")
	screen.clear_selection()
	if not _assert(screen.end_turn_action(), "Ending the human turn should succeed before the AI-triggered Prophecy test."):
		return false
	var prophecy_opened := false
	for _index in range(8):
		await process_frame
		if screen.get_pending_prophecy_ids().size() == 1:
			prophecy_opened = true
			break
	if not _assert(prophecy_opened, "AI turn should be able to break a rune and open a human Prophecy window."):
		return false
	var interrupt_state := screen.get_interaction_state()
	var pause_event_count: int = match_state.get("event_log", []).size()
	for _index in range(3):
		await process_frame
	var paused_state := screen.get_interaction_state()
	var paused_ok: bool = bool(paused_state.get("local_controls_locked", false)) == false and match_state.get("event_log", []).size() == pause_event_count
	var pending_ids := screen.get_pending_prophecy_ids()
	if not _assert(pending_ids.size() == 1, "Prophecy window should stay open until the human resolves it."):
		return false
	var prophecy_id := str(pending_ids[0])
	if not _assert(screen.select_card(prophecy_id), "Human should be able to select the pending Prophecy card during the AI turn."):
		return false
	var prophecy_result := screen.play_selected_to_lane("field", 0)
	if not _assert(bool(prophecy_result.get("is_valid", false)), "Human Prophecy response should resolve successfully during the AI turn."):
		return false
	var resume_state := screen.get_interaction_state()
	for _index in range(8):
		await process_frame
		if _active_player_id(screen.get_match_state()) == "player_1":
			break
	var final_state := screen.get_interaction_state()
	return (
		_assert(not bool(interrupt_state.get("local_controls_locked", true)), "Human local controls should unlock when a Prophecy interrupt opens during the AI turn.") and
		_assert(paused_ok, "AI progression should pause while the human Prophecy window remains unresolved.") and
		_assert(bool(resume_state.get("local_controls_locked", false)), "After resolving the Prophecy, local controls should lock again while the AI resumes its turn.") and
		_assert(screen.get_pending_prophecy_ids().is_empty(), "Prophecy window should close after the human resolves it.") and
		_assert(_active_player_id(screen.get_match_state()) == "player_1", "After the interrupt resolves, the AI should finish and return control to the human.") and
		_assert(not bool(final_state.get("local_controls_locked", true)), "Human controls should be unlocked again once the AI turn fully ends.")
	)


func _active_player_id(match_state: Dictionary) -> String:
	return str(match_state.get("active_player_id", ""))


func _player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


func _clear_lane_cards(match_state: Dictionary, player_id: String) -> void:
	for lane in match_state.get("lanes", []):
		var slots: Array = lane.get("player_slots", {}).get(player_id, [])
		for slot_index in range(slots.size()):
			slots[slot_index] = null


func _count_lane_cards(match_state: Dictionary, player_id: String) -> int:
	var count := 0
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				count += 1
	return count
func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false