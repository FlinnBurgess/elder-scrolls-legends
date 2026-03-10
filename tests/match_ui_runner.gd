extends SceneTree

const MatchScreen = preload("res://src/ui/match_screen.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := MatchScreen.new()
	root.add_child(screen)
	await process_frame
	if not _run_all_tests(screen):
		quit(1)
		return
	print("MATCH_UI_OK")
	quit(0)


func _run_all_tests(screen: MatchScreen) -> bool:
	return (
		_test_local_match_flow(screen) and
		_test_ring_and_help_affordances(screen) and
		_test_prophecy_prompt_flow(screen)
	)


func _test_local_match_flow(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load."):
		return false
	var active_player := _active_player(screen.get_match_state())
	var summon_card := _find_hand_card(active_player, "Field Guardian")
	if not _assert(not summon_card.is_empty(), "Expected a summonable creature in the opening hand."):
		return false
	var select_ok := screen.select_card(str(summon_card.get("instance_id", "")))
	var summon_result := screen.play_selected_to_lane("shadow", 0)
	return (
		_assert(select_ok, "Selecting a hand creature should succeed.") and
		_assert(bool(summon_result.get("is_valid", false)), "Creature summon through the match UI should succeed.") and
		_assert(_lane_contains(screen.get_match_state(), "shadow", str(active_player.get("player_id", "")), str(summon_card.get("instance_id", ""))), "Summoned creature should appear in the chosen lane.") and
		_assert(screen.get_status_message().contains("Played"), "UI should report a successful summon in the status line.")
	)


func _test_ring_and_help_affordances(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for ring verification."):
		return false
	if not _assert(screen.end_turn_action(), "Ending the first player's turn should succeed."):
		return false
	var active_player := _active_player(screen.get_match_state())
	var charges_before := int(active_player.get("ring_of_magicka_charges", 0))
	var ring_ok := screen.use_ring()
	var charges_after := int(_active_player(screen.get_match_state()).get("ring_of_magicka_charges", 0))
	var guard_help := screen.get_help_text("guard")
	return (
		_assert(ring_ok, "Active second player should be able to use the Ring of Magicka.") and
		_assert(charges_after == charges_before - 1, "Ring usage should spend exactly one charge.") and
		_assert(guard_help.contains("Guard creatures"), "Keyword help text should expose glossary guidance.")
	)


func _test_prophecy_prompt_flow(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("prophecy_lab"), "Prophecy scenario should load." ):
		return false
	var pending_ids := screen.get_pending_prophecy_ids()
	if not _assert(pending_ids.size() == 1, "Expected exactly one pending Prophecy card."):
		return false
	var prophecy_id := str(pending_ids[0])
	var select_ok := screen.select_card(prophecy_id)
	var inspector_before := screen.get_inspector_text()
	var play_result := screen.play_selected_to_lane("field", 1)
	var active_prophecy_ids := screen.get_pending_prophecy_ids()
	var responding_player_id := "player_2"
	return (
		_assert(select_ok, "Selecting the pending Prophecy card should succeed.") and
		_assert(bool(play_result.get("is_valid", false)), "Playing the pending Prophecy creature through the UI should succeed.") and
		_assert(active_prophecy_ids.is_empty(), "Prophecy window should close after the free play resolves.") and
		_assert(_lane_contains(screen.get_match_state(), "field", responding_player_id, prophecy_id), "Prophecy creature should land in the requested lane.") and
		_assert(inspector_before.contains("Prophecy"), "Inspector should reflect selected-card rules text before the play resolves.")
	)


func _find_hand_card(player: Dictionary, name: String) -> Dictionary:
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == name:
			return card
	return {}


func _active_player(match_state: Dictionary) -> Dictionary:
	var active_player_id := str(match_state.get("active_player_id", ""))
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == active_player_id:
			return player
	return {}


func _lane_contains(match_state: Dictionary, lane_id: String, player_id: String, instance_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
				return true
	return false


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false