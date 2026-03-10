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
	if not await _test_ai_turn_waits_for_banner_before_first_action(screen):
		return false
	await create_timer(0.4).timeout
	if not await _test_ai_turn_uses_readable_inter_action_delay(screen):
		return false
	await create_timer(0.4).timeout
	return await _test_human_prophecy_interrupt_pauses_and_resumes_ai(screen)


func _test_ai_turn_waits_for_banner_before_first_action(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for AI orchestration verification."):
		return false
	if not _assert(screen.end_turn_action(), "Ending the local player's turn should succeed."):
		return false
	var locked_state := screen.get_interaction_state()
	var pacing_after_turn_start := screen.get_local_match_ai_pacing_state()
	var pre_gate_wait_seconds := maxf((float(int(pacing_after_turn_start.get("turn_banner_ms_remaining", 0)) - 120)) / 1000.0, 0.0)
	if pre_gate_wait_seconds > 0.0:
		await create_timer(pre_gate_wait_seconds).timeout
	await process_frame
	var pre_gate_pacing := screen.get_local_match_ai_pacing_state()
	var first_action_seen := await _wait_for_ai_action_count(screen, 1, 2.2)
	var first_action_pacing := screen.get_local_match_ai_pacing_state()
	var finished_turn := await _wait_for_active_player(screen, "player_1", 3.2)
	var final_state := screen.get_interaction_state()
	return (
		_assert(bool(locked_state.get("local_controls_locked", false)), "Local controls should lock as soon as the AI turn begins.") and
		_assert(bool(pacing_after_turn_start.get("banner_visible", false)), "Opponent-turn banner should be visible immediately after the human ends turn.") and
		_assert(bool(pacing_after_turn_start.get("waiting_for_turn_banner", false)), "AI pacing should explicitly wait for the opponent-turn banner before acting.") and
		_assert(int(pacing_after_turn_start.get("action_count", -1)) == 0, "No AI actions should be recorded at the start of the opponent-turn banner.") and
		_assert(bool(pre_gate_pacing.get("banner_visible", false)), "Opponent-turn banner should still be visible just before its timing window expires.") and
		_assert(int(pre_gate_pacing.get("action_count", -1)) == 0, "AI must not act while the opponent-turn banner is still visible.") and
		_assert(first_action_seen, "AI should eventually take its first paced action after the banner clears.") and
		_assert(not bool(first_action_pacing.get("banner_visible", true)), "The first AI action should not execute until after the opponent-turn banner clears.") and
		_assert(finished_turn and _active_player_id(screen.get_match_state()) == "player_1", "Control should return to the human after the paced AI turn completes.") and
		_assert(not bool(final_state.get("local_controls_locked", true)), "Local controls should unlock again after the AI turn completes.")
	)


func _test_ai_turn_uses_readable_inter_action_delay(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for AI pacing cadence verification."):
		return false
	var match_state := screen.get_match_state()
	var player_one := _player_state(match_state, "player_1")
	var player_two := _player_state(match_state, "player_2")
	if player_one.is_empty() or player_two.is_empty():
		return _assert(false, "Expected both local-match players to exist for cadence verification.")
	_clear_lane_cards(match_state, "player_1")
	_clear_lane_cards(match_state, "player_2")
	player_two["hand"] = []
	player_two["support"] = []
	player_two["has_ring_of_magicka"] = false
	player_two["ring_of_magicka_charges"] = 0
	player_two["ring_of_magicka_used_this_turn"] = true
	ScenarioFixtures.add_hand_card(player_two, "cadence_one", {
		"name": "Cadence One",
		"card_type": "creature",
		"cost": 2,
		"power": 2,
		"health": 3,
	})
	ScenarioFixtures.add_hand_card(player_two, "cadence_two", {
		"name": "Cadence Two",
		"card_type": "creature",
		"cost": 2,
		"power": 3,
		"health": 2,
	})
	ScenarioFixtures.add_hand_card(player_two, "cadence_three", {
		"name": "Cadence Three",
		"card_type": "creature",
		"cost": 1,
		"power": 1,
		"health": 2,
	})
	screen.clear_selection()
	if not _assert(screen.end_turn_action(), "Ending the local player's turn should succeed before cadence verification."):
		return false
	if not await _wait_for_ai_action_count(screen, 1, 2.2):
		return _assert(false, "Cadence scenario should produce a first AI action after the banner clears.")
	var after_first_action := screen.get_local_match_ai_pacing_state()
	var queued_delay_ms := int(after_first_action.get("queued_delay_ms_remaining", -1))
	if not _assert(queued_delay_ms >= 180, "After the first action, AI should queue a readable follow-up delay instead of acting again immediately."):
		return false
	await create_timer(maxf(float(queued_delay_ms - 120) / 1000.0, 0.0)).timeout
	await process_frame
	var before_second_action := screen.get_local_match_ai_pacing_state()
	var second_action_seen := await _wait_for_ai_action_count(screen, 2, 1.2)
	var finished_turn := await _wait_for_active_player(screen, "player_1", 3.2)
	return (
		_assert(int(before_second_action.get("action_count", 0)) == 1, "AI should hold the queued cadence and avoid a second immediate action before the delay expires.") and
		_assert(second_action_seen, "Cadence scenario should reach a second paced AI action.") and
		_assert(finished_turn, "Cadence scenario should still hand control back to the human after the paced AI turn.")
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
	var prophecy_opened := await _wait_for_pending_prophecy_count(screen, 1, 3.2)
	if not _assert(prophecy_opened, "AI turn should be able to break a rune and open a human Prophecy window."):
		return false
	var interrupt_state := screen.get_interaction_state()
	var paused_pacing := screen.get_local_match_ai_pacing_state()
	var queued_delay_ms := int(paused_pacing.get("queued_delay_ms_remaining", -1))
	await create_timer(0.25).timeout
	await process_frame
	var paused_state := screen.get_interaction_state()
	var paused_after_wait := screen.get_local_match_ai_pacing_state()
	var paused_ok: bool = (
		bool(paused_state.get("local_controls_locked", false)) == false and
		int(paused_after_wait.get("action_count", -1)) == int(paused_pacing.get("action_count", -2)) and
		int(paused_after_wait.get("paused_delay_ms_remaining", -1)) >= max(queued_delay_ms - 280, 0)
	)
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
	await create_timer(0.12).timeout
	await process_frame
	var resume_pacing := screen.get_local_match_ai_pacing_state()
	var resumed_after_cadence := await _wait_for_ai_action_count(screen, int(paused_pacing.get("action_count", 0)) + 1, 1.4)
	var returned_to_human := await _wait_for_active_player(screen, "player_1", 3.2)
	var final_state := screen.get_interaction_state()
	return (
		_assert(not bool(interrupt_state.get("local_controls_locked", true)), "Human local controls should unlock when a Prophecy interrupt opens during the AI turn.") and
		_assert(paused_ok, "AI progression should pause while the human Prophecy window remains unresolved.") and
		_assert(bool(resume_state.get("local_controls_locked", false)), "After resolving the Prophecy, local controls should lock again while the AI resumes its turn.") and
		_assert(int(resume_pacing.get("action_count", 0)) == int(paused_pacing.get("action_count", -1)), "Resolving the Prophecy should not cause the AI to skip cadence and double-act immediately.") and
		_assert(resumed_after_cadence, "After the Prophecy resolves, the AI should resume and eventually take the next paced action.") and
		_assert(screen.get_pending_prophecy_ids().is_empty(), "Prophecy window should close after the human resolves it.") and
		_assert(returned_to_human and _active_player_id(screen.get_match_state()) == "player_1", "After the interrupt resolves, the AI should finish and return control to the human.") and
		_assert(not bool(final_state.get("local_controls_locked", true)), "Human controls should be unlocked again once the AI turn fully ends.")
	)


func _wait_for_ai_action_count(screen: MatchScreen, expected_count: int, timeout_seconds: float) -> bool:
	var started_at := Time.get_ticks_msec()
	var timeout_ms := int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() - started_at <= timeout_ms:
		if int(screen.get_local_match_ai_pacing_state().get("action_count", 0)) >= expected_count:
			return true
		await process_frame
	return int(screen.get_local_match_ai_pacing_state().get("action_count", 0)) >= expected_count


func _wait_for_active_player(screen: MatchScreen, player_id: String, timeout_seconds: float) -> bool:
	var started_at := Time.get_ticks_msec()
	var timeout_ms := int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() - started_at <= timeout_ms:
		if _active_player_id(screen.get_match_state()) == player_id:
			return true
		await process_frame
	return _active_player_id(screen.get_match_state()) == player_id


func _wait_for_pending_prophecy_count(screen: MatchScreen, expected_count: int, timeout_seconds: float) -> bool:
	var started_at := Time.get_ticks_msec()
	var timeout_ms := int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() - started_at <= timeout_ms:
		if screen.get_pending_prophecy_ids().size() == expected_count:
			return true
		await process_frame
	return screen.get_pending_prophecy_ids().size() == expected_count


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