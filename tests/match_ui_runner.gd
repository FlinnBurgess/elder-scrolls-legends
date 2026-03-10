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
		_test_layout_hierarchy(screen) and
		_test_placeholder_layout_stability(screen) and
		_test_local_match_flow(screen) and
		_test_ring_and_help_affordances(screen) and
		_test_prophecy_prompt_flow(screen)
	)


func _test_layout_hierarchy(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Layout hierarchy scenario should load."):
		return false
	var match_layout := screen.find_child("MatchLayout", true, false) as Control
	var match_content := screen.find_child("MatchContent", true, false) as Control
	var scenario_bar := screen.find_child("ScenarioBar", true, false) as Control
	var board_column := screen.find_child("BoardColumn", true, false)
	var utility_column := screen.find_child("UtilityColumn", true, false)
	var battlefield := screen.find_child("BattlefieldPanel", true, false)
	var opponent_band := screen.find_child("OpponentBand", true, false)
	var player_band := screen.find_child("PlayerBand", true, false)
	var inspector_panel := screen.find_child("InspectorRailPanel", true, false)
	var debug_panel := screen.find_child("DebugRailPanel", true, false)
	var debug_tabs := screen.find_child("DebugTabs", true, false)
	var play_button := _find_button_with_text(screen, "Play / Act")
	var field_lane_header := screen.find_child("field_lane_header", true, false) as Button
	var field_player_row_panel := screen.find_child("field_player_1_lane_row_panel", true, false)
	var field_player_row := screen.find_child("field_player_1_lane_row", true, false) as HBoxContainer
	var battlefield_title := _find_label_with_text(screen, "Battlefield")
	var actions_title := _find_label_with_text(screen, "Turn Actions")
	var supports_title := _find_label_with_text(screen, "Supports")
	var row_label := _find_first_label(field_player_row_panel)
	return (
		_assert(match_layout != null, "Expected a named match layout root.") and
		_assert(match_layout is MarginContainer and match_content != null, "Expected the refreshed layout to use a padded margin shell.") and
		_assert(scenario_bar != null, "Expected a named scenario bar in the refreshed layout.") and
		_assert(board_column != null, "Expected a named board column for the recomposed layout.") and
		_assert(utility_column != null, "Expected a named utility column for the recomposed layout.") and
		_assert(battlefield != null, "Expected a named battlefield panel for the recomposed layout.") and
		_assert(opponent_band != null, "Expected a named opponent band for the recomposed layout.") and
		_assert(player_band != null, "Expected a named local-player band for the recomposed layout.") and
		_assert(inspector_panel != null, "Expected a compact inspector/help panel in the utility rail.") and
		_assert(debug_panel != null and debug_tabs != null, "Expected secondary history/state tabs in the utility rail.") and
		_assert(is_equal_approx(match_layout.anchor_right, 1.0) and is_equal_approx(match_layout.anchor_bottom, 1.0), "Match layout should anchor to the full screen rect.") and
		_assert(match_layout.get_theme_constant("margin_left") >= 20 and match_layout.get_theme_constant("margin_right") >= 20, "Layout shell should add visible outer horizontal padding.") and
		_assert(match_layout.get_theme_constant("margin_top") >= 20 and match_layout.get_theme_constant("margin_bottom") >= 20, "Layout shell should add visible outer vertical padding.") and
		_assert(_panel_has_padding(scenario_bar, 14), "Scenario bar should include inner padding instead of sitting flush to its panel edges.") and
		_assert(_panel_has_padding(battlefield, 16), "Battlefield panel should include stronger internal padding.") and
		_assert(_panel_has_padding(inspector_panel, 16), "Inspector rail should include stronger internal padding.") and
		_assert(scenario_bar.custom_minimum_size.y >= 56.0, "Scenario bar should have more breathing room in the refreshed layout.") and
		_assert(board_column.get_index() < utility_column.get_index(), "Board column should precede the utility column.") and
		_assert(opponent_band.get_index() < battlefield.get_index(), "Opponent band should render above the battlefield.") and
		_assert(battlefield.get_index() < player_band.get_index(), "Battlefield should render above the local-player band.") and
		_assert(inspector_panel.get_index() < debug_panel.get_index(), "Compact inspector/help should appear before the lower-priority debug tabs.") and
		_assert(board_column.get_theme_constant("separation") >= 18, "Board column should have larger separation between major regions.") and
		_assert(opponent_band.custom_minimum_size.y >= 180.0 and player_band.custom_minimum_size.y >= 180.0, "Player bands should have taller minimum sizing for readability.") and
		_assert(utility_column.custom_minimum_size.x >= 336.0, "Utility rail should reserve enough width for larger text and spacing.") and
		_assert(battlefield.custom_minimum_size.y >= 390.0, "Battlefield panel should reserve more height for a roomier board presentation.") and
		_assert(battlefield_title != null and battlefield_title.get_theme_font_size("font_size") >= 22, "Battlefield heading should use stronger typography.") and
		_assert(actions_title != null and actions_title.get_theme_font_size("font_size") >= 20, "Action heading should use stronger typography.") and
		_assert(supports_title != null and supports_title.get_theme_font_size("font_size") >= 17, "Section labels should be more readable than the previous pass.") and
		_assert(row_label != null and row_label.get_theme_font_size("font_size") >= 16, "Lane row labels should use stronger typography.") and
		_assert(play_button != null and play_button.get_theme_font_size("font_size") >= 17, "Primary action buttons should use larger type.") and
		_assert(field_lane_header != null and field_lane_header.get_theme_font_size("font_size") >= 18, "Lane headers should use stronger typography.") and
		_assert(field_player_row != null and field_player_row.alignment == BoxContainer.ALIGNMENT_CENTER, "Lane rows should center their slot groups instead of bunching into a corner.") and
		_assert(field_player_row != null and field_player_row.get_theme_constant("separation") >= 14, "Lane rows should use wider slot spacing.") and
		_assert(board_column.size.x > utility_column.size.x, "Board column should be wider than the utility column.") and
		_assert(battlefield.size.y >= opponent_band.size.y and battlefield.size.y >= player_band.size.y, "Battlefield should receive at least as much vertical emphasis as each player band.") and
		_assert(debug_panel.size.y < board_column.size.y, "Debug rail should read as secondary compared with the full board column.")
	)


func _test_placeholder_layout_stability(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for placeholder verification."):
		return false
	var no_supports := _find_label_with_text(screen, "No supports")
	var no_prophecy := _find_label_with_text(screen, "No pending Prophecy windows.")
	var active_player := _active_player(screen.get_match_state())
	var summon_card := _find_hand_card(active_player, "Field Guardian")
	var select_ok := screen.select_card(str(summon_card.get("instance_id", "")))
	screen.clear_selection()
	var no_supports_after := _find_label_with_text(screen, "No supports")
	var no_prophecy_after := _find_label_with_text(screen, "No pending Prophecy windows.")
	if not _assert(screen.load_scenario("support_lab"), "Support lab should load for empty-hand placeholder verification."):
		return false
	var support_player := _active_player(screen.get_match_state())
	var support_card := _find_hand_card(support_player, "Battle Drum")
	if not _assert(not support_card.is_empty(), "Support lab should expose a selectable support card during placeholder verification."):
		return false
	var hand_empty := _find_label_with_text(screen, "Hand empty")
	var select_support_ok := screen.select_card(str(support_card.get("instance_id", "")))
	screen.clear_selection()
	var hand_empty_after := _find_label_with_text(screen, "Hand empty")
	return (
		_assert(select_ok, "Selecting a normal card should still work during placeholder verification.") and
		_assert(_placeholder_has_width_protection(no_supports), "Support placeholders should reserve horizontal width.") and
		_assert(_placeholder_has_width_protection(no_prophecy), "Prompt placeholders should reserve horizontal width.") and
		_assert(_placeholder_has_width_protection(no_supports_after), "Support placeholders should stay width-protected after unrelated selection refreshes.") and
		_assert(_placeholder_has_width_protection(no_prophecy_after), "Prompt placeholders should stay width-protected after unrelated selection refreshes.") and
		_assert(_placeholder_has_width_protection(hand_empty), "Empty-hand placeholders should reserve horizontal width.") and
		_assert(select_support_ok, "Selecting a support-lab card should still work during placeholder verification.") and
		_assert(_placeholder_has_width_protection(hand_empty_after), "Empty-hand placeholders should stay width-protected after support-card selection refreshes.")
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


func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child in node.get_children():
		var found_label := _find_label_with_text(child, text)
		if found_label != null:
			return found_label
	return null


func _placeholder_has_width_protection(label: Label) -> bool:
	if label == null:
		return false
	return (
		(label.size_flags_horizontal & Control.SIZE_EXPAND) != 0 and
		label.custom_minimum_size.x >= 160.0 and
		label.get_theme_font_size("font_size") >= 16
	)


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found_button := _find_button_with_text(child, text)
		if found_button != null:
			return found_button
	return null


func _find_first_label(node: Node) -> Label:
	if node == null:
		return null
	if node is Label:
		return node as Label
	for child in node.get_children():
		var found_label := _find_first_label(child)
		if found_label != null:
			return found_label
	return null


func _panel_has_padding(panel: Control, min_padding: int) -> bool:
	if panel == null or panel.get_child_count() == 0:
		return false
	var child := panel.get_child(0)
	if not (child is MarginContainer):
		return false
	var margin := child as MarginContainer
	return (
		margin.get_theme_constant("margin_left") >= min_padding and
		margin.get_theme_constant("margin_top") >= min_padding and
		margin.get_theme_constant("margin_right") >= min_padding and
		margin.get_theme_constant("margin_bottom") >= min_padding
	)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false