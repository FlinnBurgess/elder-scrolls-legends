extends SceneTree

const MatchScreen = preload("res://src/ui/match_screen.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")


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
			_test_board_presentation_regressions(screen) and
		_test_player_surface_presentation(screen) and
		_test_card_frame_presentation(screen) and
			_test_turn_state_presentation(screen) and
			_test_feedback_presentation_wave(screen) and
		_test_play_interaction_highlighting(screen) and
		_test_placeholder_layout_stability(screen) and
		_test_local_match_flow(screen) and
			_test_unaffordable_creature_play_is_blocked(screen) and
		_test_target_highlighting(screen) and
		_test_combat_feedback(screen) and
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
	var opponent_art := screen.find_child("player_2_art_placeholder", true, false) as Control
	var player_art := screen.find_child("player_1_art_placeholder", true, false) as Control
	var inspector_panel := screen.find_child("InspectorRailPanel", true, false)
	var debug_panel := screen.find_child("DebugRailPanel", true, false)
	var debug_tabs := screen.find_child("DebugTabs", true, false)
	var play_button := _find_button_with_text(screen, "Play / Act")
	var field_lane_panel := screen.find_child("field_lane_panel", true, false) as Control
	var shadow_lane_panel := screen.find_child("shadow_lane_panel", true, false) as Control
	var field_lane_marker := screen.find_child("field_lane_marker", true, false) as Label
	var shadow_lane_marker := screen.find_child("shadow_lane_marker", true, false) as Label
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
			_assert(opponent_art != null and player_art != null, "Expected both combatants to reserve portrait/art placeholder space.") and
		_assert(inspector_panel != null, "Expected a compact inspector/help panel in the utility rail.") and
		_assert(debug_panel != null and debug_tabs != null, "Expected secondary history/state tabs in the utility rail.") and
		_assert(is_equal_approx(match_layout.anchor_right, 1.0) and is_equal_approx(match_layout.anchor_bottom, 1.0), "Match layout should anchor to the full screen rect.") and
		_assert(match_layout.get_theme_constant("margin_left") >= 20 and match_layout.get_theme_constant("margin_right") >= 20, "Layout shell should add visible outer horizontal padding.") and
		_assert(match_layout.get_theme_constant("margin_top") >= 20 and match_layout.get_theme_constant("margin_bottom") >= 20, "Layout shell should add visible outer vertical padding.") and
		_assert(_panel_has_padding(scenario_bar, 14), "Scenario bar should include inner padding instead of sitting flush to its panel edges.") and
			_assert(_panel_has_padding(battlefield, 12), "Battlefield panel should preserve clear inner padding.") and
		_assert(_panel_has_padding(inspector_panel, 16), "Inspector rail should include stronger internal padding.") and
		_assert(scenario_bar.custom_minimum_size.y >= 56.0, "Scenario bar should have more breathing room in the refreshed layout.") and
		_assert(board_column.get_index() < utility_column.get_index(), "Board column should precede the utility column.") and
		_assert(opponent_band.get_index() < battlefield.get_index(), "Opponent band should render above the battlefield.") and
		_assert(battlefield.get_index() < player_band.get_index(), "Battlefield should render above the local-player band.") and
		_assert(inspector_panel.get_index() < debug_panel.get_index(), "Compact inspector/help should appear before the lower-priority debug tabs.") and
			_assert(board_column.get_theme_constant("separation") >= 22, "Board column should have larger separation between major regions.") and
			_assert(opponent_band.custom_minimum_size.y >= 210.0 and player_band.custom_minimum_size.y >= 210.0, "Player bands should reserve taller presentation space for identity and placeholders.") and
				_assert(opponent_art.custom_minimum_size.x >= 150.0 and player_art.custom_minimum_size.x >= 150.0, "Portrait/art placeholders should reserve meaningful width without dominating the band.") and
			_assert(utility_column.custom_minimum_size.x >= 300.0, "Utility rail should remain accessible while staying secondary to the board.") and
				_assert(battlefield.custom_minimum_size.y >= 340.0, "Battlefield panel should still reserve primary board space after the fit rebalance.") and
			_assert(field_lane_panel != null and shadow_lane_panel != null, "Expected named Field and Shadow lane panels.") and
			_assert(field_lane_marker != null and shadow_lane_marker != null, "Expected persistent lane identity markers for both lanes.") and
			_assert(field_lane_marker != null and field_lane_marker.text.contains("FIELD"), "Field lane marker should stay explicitly readable.") and
			_assert(shadow_lane_marker != null and shadow_lane_marker.text.contains("SHADOW"), "Shadow lane marker should stay always visible.") and
			_assert(_panel_background_brightness(shadow_lane_panel) < _panel_background_brightness(field_lane_panel), "Shadow lane should keep a darker ambient treatment than the Field lane.") and
			_assert(battlefield_title != null and battlefield_title.get_theme_font_size("font_size") >= 24, "Battlefield heading should use stronger typography.") and
		_assert(actions_title != null and actions_title.get_theme_font_size("font_size") >= 20, "Action heading should use stronger typography.") and
		_assert(supports_title != null and supports_title.get_theme_font_size("font_size") >= 17, "Section labels should be more readable than the previous pass.") and
			_assert(row_label != null and row_label.get_theme_font_size("font_size") >= 13, "Lane row labels should stay readable after the compact battlefield rebalance.") and
		_assert(play_button != null and play_button.get_theme_font_size("font_size") >= 17, "Primary action buttons should use larger type.") and
			_assert(field_lane_header != null and field_lane_header.get_theme_font_size("font_size") >= 17, "Lane headers should stay readable after the compact battlefield rebalance.") and
		_assert(field_player_row != null and field_player_row.alignment == BoxContainer.ALIGNMENT_CENTER, "Lane rows should center their slot groups instead of bunching into a corner.") and
		_assert(field_player_row != null and field_player_row.get_theme_constant("separation") >= 14, "Lane rows should use wider slot spacing.") and
		_assert(board_column.size.x > utility_column.size.x, "Board column should be wider than the utility column.") and
		_assert(battlefield.size.y >= opponent_band.size.y and battlefield.size.y >= player_band.size.y, "Battlefield should receive at least as much vertical emphasis as each player band.") and
		_assert(debug_panel.size.y < board_column.size.y, "Debug rail should read as secondary compared with the full board column.")
	)


func _test_board_presentation_regressions(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for board regression verification."):
		return false
	var player_band := screen.find_child("PlayerBand", true, false) as Control
	var battlefield := screen.find_child("BattlefieldPanel", true, false) as Control
	var lane_card := screen.find_child("lane_player_2_bone_guard_card", true, false) as Button
	var lane_rules := screen.find_child("player_2_bone_guard_rules_label", true, false) as Label
	var lane_content := lane_card.get_meta("content_root", null) as Control if lane_card != null else null
	if lane_card != null:
		lane_card.emit_signal("pressed")
	return (
		_assert(player_band != null and player_band.get_combined_minimum_size().y <= 360.0, "Player band minimum height should stay compact enough to fit the lower zone on 16:9 layouts.") and
		_assert(battlefield != null and battlefield.get_combined_minimum_size().y <= 660.0, "Battlefield minimum height should stay compact enough to leave room for both player zones.") and
		_assert(lane_card != null and lane_card.clip_contents, "Board cards should clip presentation content to the visible card frame.") and
		_assert(lane_content != null and lane_content.size.y <= lane_card.size.y, "Board card content should stay inside the visible card frame height.") and
		_assert(lane_rules != null and lane_rules.max_lines_visible == 1, "Board card rules text should use a compact single-line preview.") and
		_assert(lane_card != null and screen.get_selected_instance_id() == str(lane_card.get_meta("instance_id", "")), "Pressing a visible board card should still select that card.")
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


func _test_player_surface_presentation(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for player-surface verification."):
		return false
	var opponent_health := screen.find_child("player_2_health_value", true, false) as Label
	var player_health := screen.find_child("player_1_health_value", true, false) as Label
	var opponent_rune_row := screen.find_child("player_2_rune_row", true, false) as HBoxContainer
	var player_rune_row := screen.find_child("player_1_rune_row", true, false) as HBoxContainer
	var player_magicka_label := screen.find_child("player_1_magicka_label", true, false) as Label
	var player_magicka_bar := screen.find_child("player_1_magicka_bar", true, false) as HBoxContainer
	var opponent_ring_label := screen.find_child("player_2_ring_label", true, false) as Label
	var player_deck_button := screen.find_child("player_1_deck_button", true, false) as Button
	var player_discard_button := screen.find_child("player_1_discard_button", true, false) as Button
	if not _assert(player_discard_button != null, "Expected a visible discard pile surface for the local player."):
		return false
	player_discard_button.emit_signal("pressed")
	var discard_inspector := screen.get_inspector_text()
	return (
		_assert(opponent_health != null and player_health != null, "Expected prominent health labels for both players.") and
		_assert(opponent_health != null and opponent_health.get_theme_font_size("font_size") >= 30, "Opponent health should use large display typography.") and
		_assert(player_health != null and player_health.get_theme_font_size("font_size") >= 30, "Local player health should use large display typography.") and
		_assert(opponent_health != null and opponent_health.text == "12", "Opponent health surface should reflect the scenario health total.") and
		_assert(player_health != null and player_health.text == "18", "Local player health surface should reflect the scenario health total.") and
		_assert(opponent_rune_row != null and opponent_rune_row.get_child_count() == 5, "Opponent rune row should show all five rune surfaces.") and
		_assert(player_rune_row != null and player_rune_row.get_child_count() == 5, "Local player rune row should show all five rune surfaces.") and
		_assert(player_magicka_label != null and player_magicka_label.text.contains("6 / 6"), "Local player magicka summary should be readable and count-based.") and
		_assert(player_magicka_bar != null and player_magicka_bar.get_child_count() == 12, "Local player magicka bar should reserve room for all 12 magicka slots.") and
		_assert(opponent_ring_label != null and opponent_ring_label.text.contains("3 / 3"), "Ring surface should show the opponent's remaining Ring charges.") and
		_assert(player_deck_button != null and player_deck_button.text.contains("Deck"), "Deck pile surface should be visible and labeled.") and
		_assert(player_discard_button.text.contains("Discard"), "Discard pile surface should be visible and labeled.") and
		_assert(discard_inspector.contains("Player One Discard"), "Discard inspection should route into the inspector rail.") and
		_assert(discard_inspector.contains("Spent Torchbearer"), "Discard inspection should list public discard contents.")
	)


func _test_card_frame_presentation(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for card-frame verification."):
		return false
	var local_hand_row := screen.find_child("player_1_hand_row", true, false) as Control
	var opponent_hand_row := screen.find_child("player_2_hand_row", true, false) as Control
	var field_guardian_button := screen.find_child("hand_player_1_field_guardian_card", true, false) as Button
	var shadow_raider_button := screen.find_child("hand_player_1_shadow_raider_card", true, false) as Button
	var steel_sword_button := screen.find_child("hand_player_1_steel_sword_card", true, false) as Button
	var grand_colossus_button := screen.find_child("hand_player_1_grand_colossus_card", true, false) as Button
	var field_guardian_art := screen.find_child("player_1_field_guardian_art_region", true, false) as Control
	var field_guardian_rarity := screen.find_child("player_1_field_guardian_rarity_marker", true, false) as Label
	var field_guardian_rules := screen.find_child("player_1_field_guardian_rules_label", true, false) as Label
	var field_guardian_power := screen.find_child("player_1_field_guardian_power_label", true, false) as Label
	var field_guardian_health := screen.find_child("player_1_field_guardian_health_label", true, false) as Label
	var shadow_raider_power := screen.find_child("player_1_shadow_raider_power_label", true, false) as Label
	var hidden_opponent_button := screen.find_child("hand_player_2_skeletal_sentry_card", true, false) as Button
	var hidden_back_label := screen.find_child("player_2_skeletal_sentry_card_back_label", true, false) as Label
	if not _assert(field_guardian_button != null and shadow_raider_button != null and steel_sword_button != null, "Expected named local hand card frames for the fan layout."):
		return false
	field_guardian_button.emit_signal("mouse_entered")
	var hover_scale := field_guardian_button.scale.x
	var hover_z := field_guardian_button.z_index
	field_guardian_button.emit_signal("mouse_exited")
	return (
		_assert(local_hand_row != null and opponent_hand_row != null, "Expected named hand surfaces for both players.") and
			_assert(local_hand_row != null and local_hand_row.custom_minimum_size.y >= 190.0, "Local hand surface should keep a deliberate held-card presentation without overgrowing the player zone.") and
		_assert(field_guardian_button.text.is_empty(), "Rich card frames should use composed child controls instead of multiline button text.") and
		_assert(field_guardian_art != null and field_guardian_art.custom_minimum_size.y >= 36.0, "Card frames should reserve a visible placeholder art region.") and
		_assert(field_guardian_rarity != null and field_guardian_rarity.text == "UNCOMMON", "Card frames should expose the rarity marker.") and
		_assert(field_guardian_rules != null and field_guardian_rules.text.contains("Placeholder boosted creature"), "Card frames should surface rules text directly on the frame.") and
		_assert(field_guardian_power != null and _color_reads_green(field_guardian_power.get_theme_color("font_color")), "Buffed creature power should color green.") and
		_assert(field_guardian_health != null and _color_reads_green(field_guardian_health.get_theme_color("font_color")), "Buffed creature health should color green.") and
		_assert(shadow_raider_power != null and _color_reads_red(shadow_raider_power.get_theme_color("font_color")), "Reduced creature power should color red.") and
		_assert(field_guardian_button.position.x + field_guardian_button.size.x > shadow_raider_button.position.x, "Local hand cards should intentionally overlap instead of sitting in a plain row.") and
		_assert(steel_sword_button.position.y < field_guardian_button.position.y, "Local hand should use an arc/fan treatment with different vertical positions.") and
		_assert(hover_scale > 1.0 and hover_z > 0, "Local hand hover should enlarge and raise the hovered card.") and
		_assert(is_equal_approx(field_guardian_button.scale.x, 1.0), "Hover emphasis should reset cleanly after the pointer leaves.") and
		_assert(grand_colossus_button != null and grand_colossus_button.self_modulate.a < 0.9, "Unaffordable local hand cards should be visually muted.") and
		_assert(hidden_opponent_button != null and hidden_opponent_button.disabled, "Opponent hand cards should render as hidden backs rather than selectable text frames.") and
		_assert(hidden_back_label != null and hidden_back_label.text.contains("CARD BACK"), "Opponent hand should visibly read as face-down card backs.")
	)


func _test_turn_state_presentation(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for turn-state verification."):
		return false
	var turn_state_panel := screen.find_child("TurnStatePanel", true, false) as Control
	var turn_state_label := screen.find_child("TurnStateLabel", true, false) as Label
	var turn_state_detail := screen.find_child("TurnStateDetailLabel", true, false) as Label
	var turn_banner_panel := screen.find_child("TurnBannerPanel", true, false) as Control
	var turn_banner_label := screen.find_child("TurnBannerLabel", true, false) as Label
	var end_turn_button := _find_button_with_text(screen, "End Turn")
	var player_band := screen.find_child("PlayerBand", true, false) as Control
	var initial_state := screen.get_interaction_state()
	var initial_turn_text := turn_state_label.text if turn_state_label != null else ""
	var initial_turn_detail := turn_state_detail.text if turn_state_detail != null else ""
	var initial_banner_visible := turn_banner_panel.visible if turn_banner_panel != null else false
	var initial_banner_text := turn_banner_label.text if turn_banner_label != null else ""
	var initial_end_turn_disabled := end_turn_button.disabled if end_turn_button != null else true
	var initial_border_width := _button_border_width(end_turn_button, "disabled" if initial_end_turn_disabled else "normal")
	var initial_brightness := _button_background_brightness(end_turn_button, "disabled" if initial_end_turn_disabled else "normal")
	if not _assert(screen.end_turn_action(), "Advancing the scenario turn should succeed for turn-state verification."):
		return false
	var next_state := screen.get_interaction_state()
	var next_turn_text := turn_state_label.text if turn_state_label != null else ""
	var next_banner_visible := turn_banner_panel.visible if turn_banner_panel != null else false
	var next_banner_text := turn_banner_label.text if turn_banner_label != null else ""
	var next_end_turn_disabled := end_turn_button.disabled if end_turn_button != null else true
	var next_border_width := _button_border_width(end_turn_button, "disabled" if next_end_turn_disabled else "normal")
	var next_brightness := _button_background_brightness(end_turn_button, "disabled" if next_end_turn_disabled else "normal")
	var next_hand_button := screen.find_child("hand_player_1_field_guardian_card", true, false) as Button
	var ready_text := initial_turn_text if bool(initial_state.get("local_turn", false)) else next_turn_text
	var ready_detail := initial_turn_detail if bool(initial_state.get("local_turn", false)) else (turn_state_detail.text if turn_state_detail != null else "")
	var ready_banner_visible := initial_banner_visible if bool(initial_state.get("local_turn", false)) else next_banner_visible
	var ready_banner_text := initial_banner_text if bool(initial_state.get("local_turn", false)) else next_banner_text
	var ready_end_turn_disabled := initial_end_turn_disabled if bool(initial_state.get("local_turn", false)) else next_end_turn_disabled
	var ready_border_width := initial_border_width if bool(initial_state.get("local_turn", false)) else next_border_width
	var ready_brightness := initial_brightness if bool(initial_state.get("local_turn", false)) else next_brightness
	var ready_state := initial_state if bool(initial_state.get("local_turn", false)) else next_state
	var locked_text := initial_turn_text if not bool(initial_state.get("local_turn", false)) else next_turn_text
	var locked_banner_visible := initial_banner_visible if not bool(initial_state.get("local_turn", false)) else next_banner_visible
	var locked_banner_text := initial_banner_text if not bool(initial_state.get("local_turn", false)) else next_banner_text
	var locked_end_turn_disabled := initial_end_turn_disabled if not bool(initial_state.get("local_turn", false)) else next_end_turn_disabled
	var locked_border_width := initial_border_width if not bool(initial_state.get("local_turn", false)) else next_border_width
	var locked_brightness := initial_brightness if not bool(initial_state.get("local_turn", false)) else next_brightness
	var locked_state := initial_state if not bool(initial_state.get("local_turn", false)) else next_state
	var locked_hand_button := next_hand_button
	if not bool(initial_state.get("local_turn", false)):
		locked_hand_button = screen.find_child("hand_player_1_field_guardian_card", true, false) as Button
	return (
		_assert(turn_state_panel != null, "Expected a persistent turn-state panel in the scenario bar.") and
		_assert(ready_text == "Your Turn", "Persistent turn-state copy should clearly identify the local player's action window.") and
		_assert(ready_detail.contains("end the turn"), "Persistent turn-state detail should explain the local player's action window.") and
		_assert(ready_banner_visible, "A transient turn banner should appear when the local player becomes active.") and
		_assert(ready_banner_text == "Your Turn", "Transient turn banner should clearly announce the local turn owner.") and
		_assert(bool(ready_state.get("local_turn", false)) and not bool(ready_state.get("local_controls_locked", true)), "Interaction state should report the opening turn as locally actionable.") and
		_assert(not ready_end_turn_disabled, "End Turn should be usable on the local player's turn.") and
		_assert(ready_border_width >= 2, "End Turn should gain a stronger CTA border treatment when it is ready.") and
		_assert(locked_text == "Opponent's Turn", "Persistent turn-state copy should clearly identify the opponent turn.") and
		_assert(locked_banner_visible, "A transient turn banner should appear when the opponent becomes active.") and
		_assert(locked_banner_text == "Opponent's Turn", "Transient turn banner should clearly announce the opponent turn owner.") and
		_assert(not bool(locked_state.get("local_turn", true)) and bool(locked_state.get("local_controls_locked", false)), "Interaction state should report local controls as presentation-locked on the opponent turn.") and
		_assert(locked_end_turn_disabled, "End Turn should read as unavailable during the opponent turn.") and
		_assert(locked_border_width <= 1, "Unavailable End Turn should fall back to a quieter border treatment.") and
		_assert(ready_brightness > locked_brightness, "End Turn should visually cool down when it becomes unavailable.") and
		_assert(player_band != null and player_band.self_modulate.a < 0.9, "Local player band should visibly dim during the opponent turn.") and
		_assert(locked_hand_button != null and locked_hand_button.self_modulate.a < 0.8, "Local hand cards should visibly dim during the opponent turn.")
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


func _test_unaffordable_creature_play_is_blocked(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for unaffordable summon verification."):
		return false
	var active_player := _active_player(screen.get_match_state())
	var expensive_card := _find_hand_card(active_player, "Grand Colossus")
	if not _assert(not expensive_card.is_empty(), "Expected an expensive creature in hand for affordability verification."):
		return false
	var expensive_id := str(expensive_card.get("instance_id", ""))
	var magicka_before := int(active_player.get("current_magicka", 0))
	var temporary_before := int(active_player.get("temporary_magicka", 0))
	var select_ok := screen.select_card(expensive_id)
	var interaction_state := screen.get_interaction_state()
	var summon_result := screen.play_selected_to_lane("field", 1)
	var active_after := _active_player(screen.get_match_state())
	return (
		_assert(select_ok, "Selecting an unaffordable creature should still succeed for inspection/feedback.") and
		_assert(interaction_state.get("selection_mode", "") == "summon", "Unaffordable creatures should still present summon interaction mode.") and
		_assert(interaction_state.get("valid_lane_slot_keys", []).is_empty(), "Unaffordable creature summons should not advertise any valid lane drop targets.") and
		_assert(not bool(summon_result.get("is_valid", true)), "UI summon attempts should fail cleanly when the creature is unaffordable.") and
		_assert(screen.get_status_message().contains("enough magicka"), "UI should surface the affordability failure reason.") and
		_assert(int(active_after.get("current_magicka", 0)) == magicka_before and int(active_after.get("temporary_magicka", 0)) == temporary_before, "Failed UI summons should not spend magicka.") and
		_assert(not _find_hand_card(active_after, "Grand Colossus").is_empty(), "Failed UI summons should leave the unaffordable creature in hand.") and
		_assert(not _lane_contains(screen.get_match_state(), "field", str(active_after.get("player_id", "")), expensive_id), "Failed UI summons should not place the creature onto the board.")
	)


func _test_play_interaction_highlighting(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for interaction highlighting."):
		return false
	var active_player := _active_player(screen.get_match_state())
	var summon_card := _find_hand_card(active_player, "Field Guardian")
	var summon_id := str(summon_card.get("instance_id", ""))
	var select_ok := screen.select_card(summon_id)
	var interaction_state := screen.get_interaction_state()
	var field_guardian_button := screen.find_child("hand_player_1_field_guardian_card", true, false) as Button
	var opponent_slot_button := screen.find_child("field_player_2_slot_1", true, false) as Button
	if opponent_slot_button != null:
		opponent_slot_button.emit_signal("pressed")
	var invalid_state := screen.get_interaction_state()
	var invalid_slot_message := screen.get_status_message()
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for drag verification."):
		return false
	active_player = _active_player(screen.get_match_state())
	summon_card = _find_hand_card(active_player, "Field Guardian")
	summon_id = str(summon_card.get("instance_id", ""))
	var drag_started := screen.start_hand_drag(summon_id)
	var invalid_drop := screen.drop_hand_drag_on_node("player_2_identity_button")
	var drag_invalid_state := screen.get_interaction_state()
	var invalid_drag_message := screen.get_status_message()
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for valid drag verification."):
		return false
	active_player = _active_player(screen.get_match_state())
	summon_card = _find_hand_card(active_player, "Field Guardian")
	summon_id = str(summon_card.get("instance_id", ""))
	var valid_drag_started := screen.start_hand_drag(summon_id)
	var valid_drop := screen.drop_hand_drag_on_node("shadow_lane_header")
	return (
		_assert(select_ok, "Selecting a hand creature should expose interaction highlights.") and
		_assert(field_guardian_button != null and field_guardian_button.scale.x > 1.0, "Selected local hand cards should remain visually lifted for readability.") and
		_assert(interaction_state.get("selection_mode", "") == "summon", "Creature hand selection should enter summon interaction mode.") and
		_assert(interaction_state.get("valid_lane_slot_keys", []).size() >= 2, "Summon selection should highlight multiple valid drop slots.") and
		_assert(not interaction_state.get("valid_lane_slot_keys", []).has("field:player_2:1"), "Opponent lane slots should not be listed as valid summon drops.") and
		_assert(invalid_state.get("invalid_lane_slot_keys", []).has("field:player_2:1"), "Clicking an invalid drop slot should record invalid slot feedback.") and
		_assert(invalid_slot_message.contains("Select a creature that can be summoned"), "Invalid summon target feedback should explain the required drop zone.") and
		_assert(drag_started, "Playable hand creatures should support drag-style direct manipulation.") and
		_assert(not bool(invalid_drop.get("is_valid", true)), "Dragging onto an invalid surface should fail cleanly.") and
		_assert(drag_invalid_state.get("invalid_player_ids", []).has("player_2"), "Invalid drag drops should identify the blocked surface for feedback.") and
		_assert(invalid_drag_message.contains("Select a lane slot"), "Invalid drag drops should explain the correct drop surface.") and
		_assert(not screen.is_hand_drag_active(), "Invalid drag drops should settle and end the drag interaction.") and
		_assert(valid_drag_started, "Valid drag verification should start successfully.") and
		_assert(bool(valid_drop.get("is_valid", false)), "Dragging a creature onto a highlighted lane should resolve through the existing command wiring.") and
		_assert(_lane_contains(screen.get_match_state(), "shadow", str(active_player.get("player_id", "")), summon_id), "Successful drag drops should place the card into the requested lane.")
	)


func _test_target_highlighting(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for target highlighting."):
		return false
	var active_player := _active_player(screen.get_match_state())
	var item_card := _find_hand_card(active_player, "Steel Sword")
	var item_id := str(item_card.get("instance_id", ""))
	var item_select_ok := screen.select_card(item_id)
	var item_state := screen.get_interaction_state()
	var vanguard := _find_lane_card(screen.get_match_state(), "Vanguard Captain")
	var bone_guard := _find_lane_card(screen.get_match_state(), "Bone Guard")
	var invalid_item_slot := screen.find_child("field_player_1_slot_1", true, false) as Button
	if invalid_item_slot != null:
		invalid_item_slot.emit_signal("pressed")
	var invalid_item_state := screen.get_interaction_state()
	var invalid_item_message := screen.get_status_message()
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for attack highlighting."):
		return false
	var attacker := _find_lane_card(screen.get_match_state(), "Vanguard Captain")
	var attacker_select_ok := screen.select_card(str(attacker.get("instance_id", "")))
	var attack_state := screen.get_interaction_state()
	var attack_bone_guard := _find_lane_card(screen.get_match_state(), "Bone Guard")
	var opponent_identity := screen.find_child("player_2_identity_button", true, false) as Button
	if opponent_identity != null:
		opponent_identity.emit_signal("pressed")
	var invalid_attack_state := screen.get_interaction_state()
	var invalid_attack_message := screen.get_status_message()
	return (
		_assert(item_select_ok, "Selecting the sandbox item should succeed.") and
		_assert(item_state.get("selection_mode", "") == "item", "Item selection should enter item targeting mode.") and
		_assert(item_state.get("valid_target_instance_ids", []).has(str(vanguard.get("instance_id", ""))), "Item selection should highlight the valid friendly equip target.") and
		_assert(item_state.get("valid_target_instance_ids", []).has(str(bone_guard.get("instance_id", ""))), "Item highlights should follow current engine legality, including sandbox enemy targets when legal.") and
		_assert(invalid_item_state.get("invalid_lane_slot_keys", []).has("field:player_1:1"), "Invalid non-creature item drops should be surfaced for feedback.") and
		_assert(invalid_item_message.contains("Select a creature"), "Invalid item drop feedback should explain that a creature target is required.") and
		_assert(attacker_select_ok, "Selecting the sandbox attacker should succeed.") and
		_assert(attack_state.get("selection_mode", "") == "attack", "Lane creature selection should enter attack targeting mode.") and
		_assert(attack_state.get("valid_target_instance_ids", []).has(str(attack_bone_guard.get("instance_id", ""))), "Attack selection should highlight valid enemy defenders.") and
		_assert(attack_state.get("valid_target_player_ids", []).is_empty(), "Enemy player should not highlight while Guard blocks face attacks.") and
		_assert(invalid_attack_state.get("invalid_player_ids", []).has("player_2"), "Blocked face attacks should mark the enemy player as an invalid target.") and
		_assert(invalid_attack_message.contains("can't attack"), "Invalid face attacks should explain why the target is blocked.")
	)


func _test_combat_feedback(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for combat feedback verification."):
		return false
	var ready_label := screen.find_child("player_1_vanguard_readiness_label", true, false) as Label
	var guard_label := screen.find_child("player_2_bone_guard_guard_emphasis_label", true, false) as Label
	var active_player := _active_player(screen.get_match_state())
	var summon_card := _find_hand_card(active_player, "Field Guardian")
	if not _assert(screen.select_card(str(summon_card.get("instance_id", ""))), "Field Guardian should be selectable for readiness feedback verification."):
		return false
	var summon_result := screen.play_selected_to_lane("shadow", 0)
	var summoning_label := screen.find_child("player_1_field_guardian_readiness_label", true, false) as Label
	var attacker := _find_lane_card(screen.get_match_state(), "Vanguard Captain")
	var defender := _find_lane_card(screen.get_match_state(), "Bone Guard")
	if not _assert(screen.select_card(str(attacker.get("instance_id", ""))), "Ready attacker should remain selectable for combat feedback verification."):
		return false
	var attack_result := screen.target_selected_card(str(defender.get("instance_id", "")))
	var feedback_state := screen.get_feedback_state()
	var attack_banner := _find_node_by_name_prefix(screen, "feedback_attack_")
	var damage_popup := _find_node_by_name_prefix(screen, "feedback_damage_")
	var removal_toast := _find_node_by_name_prefix(screen, "feedback_removal_")
	return (
		_assert(ready_label != null and ready_label.text == "READY", "Existing ready creatures should show an explicit READY badge.") and
		_assert(guard_label != null and guard_label.text == "GUARD", "Guard blockers should keep a persistent GUARD emphasis badge.") and
		_assert(bool(summon_result.get("is_valid", false)), "Summoning the readiness test creature should succeed.") and
		_assert(summoning_label != null and summoning_label.text == "SUMMONING SICK", "Freshly summoned creatures should show a distinct summoning-sickness badge.") and
		_assert(bool(attack_result.get("is_valid", false)), "Attacking the Guard blocker should still resolve through existing combat wiring.") and
		_assert(not _lane_contains(screen.get_match_state(), "field", "player_2", str(defender.get("instance_id", ""))), "The damaged Guard blocker should still die through the unchanged combat rules.") and
		_assert(feedback_state.get("attacks", []).size() >= 1, "Combat feedback should capture an attack presentation payload.") and
		_assert(feedback_state.get("damage", []).size() >= 2, "Combat feedback should capture visible damage payloads for both creatures.") and
		_assert(feedback_state.get("removals", []).size() >= 1, "Combat feedback should capture a removal announcement when a creature dies.") and
		_assert(attack_banner != null, "Attacks should add an explicit transient attack banner to the board.") and
		_assert(damage_popup != null, "Combat damage should surface a transient popup indicator.") and
		_assert(removal_toast != null, "Creature deaths should surface a transient removal toast instead of disappearing silently.")
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
	var opponent_ring_label := screen.find_child("player_2_ring_label", true, false) as Label
	var opponent_magicka_label := screen.find_child("player_2_magicka_label", true, false) as Label
	var guard_help := screen.get_help_text("guard")
	return (
		_assert(ring_ok, "Active second player should be able to use the Ring of Magicka.") and
		_assert(charges_after == charges_before - 1, "Ring usage should spend exactly one charge.") and
		_assert(opponent_ring_label != null and opponent_ring_label.text.contains("2 / 3"), "Ring surface should update after a Ring charge is spent.") and
		_assert(opponent_magicka_label != null and opponent_magicka_label.text.contains("+1 temp"), "Magicka surface should show temporary magicka granted by the Ring.") and
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


func _test_feedback_presentation_wave(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for draw feedback verification."):
		return false
	if not _assert(screen.end_turn_action(), "Ending the opening turn should surface the normal draw presentation."):
		return false
	var normal_feedback := screen.get_feedback_state()
	var normal_draws: Array = normal_feedback.get("draws", [])
	var normal_draw_player_id := str(normal_draws[0].get("player_id", "")) if normal_draws.size() > 0 else ""
	var affected_hand_row := screen.find_child("%s_hand_row" % normal_draw_player_id, true, false) as Control
	var draw_toast := _find_direct_child_by_name_prefix(affected_hand_row, "feedback_draw_toast_")
	var draw_popup := _find_node_by_name_prefix(screen, "feedback_draw_popup_")
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for explicit rune-break feedback verification."):
		return false
	var rune_result: Dictionary = MatchTiming.apply_player_damage(screen.get_match_state(), "player_2", 5, {"reason": "ui_test"})
	screen._record_feedback_from_events(rune_result.get("events", []))
	screen.clear_selection()
	var rune_feedback := screen.get_feedback_state()
	var rune_toast := _find_node_by_name_prefix(screen, "feedback_rune_toast_")
	var rune_banner := _find_node_by_name_prefix(screen, "feedback_rune_banner_")
	if not _assert(screen.load_scenario("prophecy_lab"), "Prophecy scenario should reload for rune-break presentation verification."):
		return false
	var prophecy_ids := screen.get_pending_prophecy_ids()
	if not _assert(prophecy_ids.size() == 1, "Prophecy presentation scenario should expose a single pending Prophecy card."):
		return false
	var prophecy_id := str(prophecy_ids[0])
	var prompt_title := screen.find_child("PromptTitleLabel", true, false) as Label
	var prophecy_badge := screen.find_child("%s_prophecy_window" % prophecy_id, true, false)
	var prophecy_free_badge := screen.find_child("%s_prophecy_free" % prophecy_id, true, false)
	var prophecy_card_banner := _find_node_by_name_prefix(screen, "feedback_hand_prophecy_")
	var overlay := screen.find_child("MatchEndOverlay", true, false) as Control
	var overlay_title := screen.find_child("MatchEndTitle", true, false) as Label
	var overlay_detail := screen.find_child("MatchEndDetailLabel", true, false) as Label
	var end_turn_button := _find_button_with_text(screen, "End Turn")
	var match_state := screen.get_match_state()
	match_state["winner_player_id"] = "player_1"
	match_state["phase"] = "complete"
	screen.clear_selection()
	var victory_visible := overlay != null and overlay.visible
	var victory_title := overlay_title.text if overlay_title != null else ""
	var victory_detail := overlay_detail.text if overlay_detail != null else ""
	var victory_end_turn_disabled := end_turn_button != null and end_turn_button.disabled
	match_state["winner_player_id"] = "player_2"
	screen.clear_selection()
	var defeat_title := overlay_title.text if overlay_title != null else ""
	return (
		_assert(normal_feedback.get("draws", []).size() >= 1, "Ending a turn should now register a visible draw feedback payload.") and
		_assert(draw_popup != null or draw_toast != null, "Normal draws should surface visible player-surface feedback instead of updating silently.") and
		_assert(rune_feedback.get("runes", []).size() >= 1, "Rune breaks should register a presentation payload for the broken rune.") and
		_assert(rune_feedback.get("draws", []).size() >= 1, "Rune-break draws should register a visible draw payload.") and
		_assert(prompt_title != null and prompt_title.text.contains("PROPHECY"), "Pending Prophecy interrupts should headline the prompt rail clearly.") and
		_assert((prophecy_badge != null and prophecy_free_badge != null) or prophecy_card_banner != null, "Pending Prophecy cards should render stronger interrupt badges directly on the card frame.") and
		_assert(rune_toast != null and rune_banner != null, "Rune breaks should add both a player-surface toast and a shatter-style rune banner.") and
		_assert(victory_visible and victory_title == "Victory", "Winning states should show a visible Victory overlay.") and
		_assert(victory_detail.contains("wins the match"), "Match-end overlays should include clear completion copy.") and
		_assert(victory_end_turn_disabled, "Match-end presentation should disable turn advancement controls.") and
		_assert(defeat_title == "Defeat", "Losing states should restyle the same overlay as Defeat.")
	)


func _find_hand_card(player: Dictionary, name: String) -> Dictionary:
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == name:
			return card
	return {}


func _find_lane_card(match_state: Dictionary, name: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		for player_id in ["player_1", "player_2"]:
			for card in lane.get("player_slots", {}).get(player_id, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")) == name:
					return card
	return {}


func _find_node_by_name_prefix(parent: Node, prefix: String) -> Node:
	for child in parent.find_children("*", "Node", true, false):
		if str(child.name).begins_with(prefix):
			return child
	return null


func _find_direct_child_by_name_prefix(parent: Node, prefix: String) -> Node:
	if parent == null:
		return null
	for child in parent.get_children():
		if str(child.name).begins_with(prefix):
			return child
	return null


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


func _panel_background_brightness(panel: Control) -> float:
	if panel == null:
		return 999.0
	var style := panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var color := (style as StyleBoxFlat).bg_color
		return color.r + color.g + color.b
	return 999.0


func _button_background_brightness(button: Button, style_name: String) -> float:
	if button == null:
		return 999.0
	var style := button.get_theme_stylebox(style_name)
	if style is StyleBoxFlat:
		var color := (style as StyleBoxFlat).bg_color
		return color.r + color.g + color.b
	return 999.0


func _button_border_width(button: Button, style_name: String) -> int:
	if button == null:
		return -1
	var style := button.get_theme_stylebox(style_name)
	if style is StyleBoxFlat:
		return int((style as StyleBoxFlat).border_width_top)
	return -1


func _color_reads_green(color: Color) -> bool:
	return color.g > color.r and color.g > color.b


func _color_reads_red(color: Color) -> bool:
	return color.r > color.g and color.r > color.b


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false