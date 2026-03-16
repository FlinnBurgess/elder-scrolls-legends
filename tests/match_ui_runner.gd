extends SceneTree

const MatchScreen = preload("res://src/ui/match_screen.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const CardDisplayComponent = preload("res://src/ui/components/CardDisplayComponent.gd")
const PlayerAvatarComponent = preload("res://src/ui/components/PlayerAvatarComponent.gd")
const PlayerMagickaComponent = preload("res://src/ui/components/PlayerMagickaComponent.gd")
const TEST_VIEWPORT_SIZE := Vector2i(2560, 1600)
const DISPLAY_RUNE_THRESHOLDS := [25, 20, 15, 10, 5]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = TEST_VIEWPORT_SIZE
	var screen := MatchScreen.new()
	screen.size = TEST_VIEWPORT_SIZE
	root.add_child(screen)
	await process_frame
	if not await _run_all_tests(screen):
		quit(1)
		return
	print("MATCH_UI_OK")
	quit(0)


func _run_all_tests(screen: MatchScreen) -> bool:
	if not _test_layout_hierarchy(screen):
		return false
	if not await _test_avatar_band_containment(screen):
		return false
	if not _test_board_presentation_regressions(screen):
		return false
	if not _test_player_surface_presentation(screen):
		return false
	if not _test_card_frame_presentation(screen):
		return false
	if not await _test_match_card_display_modes(screen):
		return false
	if not _test_turn_state_presentation(screen):
		return false
	if not await _test_feedback_presentation_wave(screen):
		return false
	if not _test_play_interaction_highlighting(screen):
		return false
	if not _test_placeholder_layout_stability(screen):
		return false
	if not await _test_support_row_click_placement(screen):
		return false
	if not await _test_live_lane_click_delivery(screen):
		return false
	if not _test_local_match_flow(screen):
		return false
	if not _test_unaffordable_creature_play_is_blocked(screen):
		return false
	if not _test_target_highlighting(screen):
		return false
	if not _test_combat_feedback(screen):
		return false
	if not _test_ring_and_help_affordances(screen):
		return false
	return _test_prophecy_prompt_flow(screen)


func _test_layout_hierarchy(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Layout hierarchy scenario should load."):
		return false
	var match_layout := screen.find_child("MatchLayout", true, false) as Control
	var match_content := screen.find_child("MatchContent", true, false) as Control
	var board_column := screen.find_child("BoardColumn", true, false)
	var battlefield := screen.find_child("BattlefieldPanel", true, false)
	var opponent_band := screen.find_child("OpponentBand", true, false)
	var player_band := screen.find_child("PlayerBand", true, false)
	var opponent_avatar := screen.find_child("player_2_avatar_component", true, false) as PlayerAvatarComponent
	var player_avatar := screen.find_child("player_1_avatar_component", true, false) as PlayerAvatarComponent
	var debug_overlay := screen.find_child("DebugOverlay", true, false)
	var debug_tabs := screen.find_child("DebugTabs", true, false)
	var field_lane_panel := screen.find_child("field_lane_panel", true, false) as Control
	var shadow_lane_panel := screen.find_child("shadow_lane_panel", true, false) as Control
	var field_player_row := screen.find_child("field_player_1_lane_row", true, false) as HBoxContainer
	return (
		_assert(match_layout != null, "Expected a named match layout root.") and
		_assert(match_layout is MarginContainer and match_content != null, "Expected the refreshed layout to use a padded margin shell.") and
		_assert(board_column != null, "Expected a named board column for the recomposed layout.") and
		_assert(battlefield != null, "Expected a named battlefield panel for the recomposed layout.") and
		_assert(opponent_band != null, "Expected a named opponent band for the recomposed layout.") and
		_assert(player_band != null, "Expected a named local-player band for the recomposed layout.") and
		_assert(opponent_avatar != null and player_avatar != null, "Expected both combatants to mount the reusable avatar component in the player bands.") and
		_assert(debug_overlay != null and debug_tabs != null, "Expected debug overlay with history/state tabs.") and
		_assert(is_equal_approx(match_layout.anchor_right, 1.0) and is_equal_approx(match_layout.anchor_bottom, 1.0), "Match layout should anchor to the full screen rect.") and
		_assert(match_layout.get_theme_constant("margin_left") >= 20 and match_layout.get_theme_constant("margin_right") >= 20, "Layout shell should add visible outer horizontal padding.") and
		_assert(match_layout.get_theme_constant("margin_top") >= 20 and match_layout.get_theme_constant("margin_bottom") >= 20, "Layout shell should add visible outer vertical padding.") and
		_assert(opponent_band.get_index() < battlefield.get_index(), "Opponent band should render above the battlefield.") and
		_assert(battlefield.get_index() < player_band.get_index(), "Battlefield should render above the local-player band.") and
		_assert(board_column.get_theme_constant("separation") >= 22, "Board column should have larger separation between major regions.") and
		_assert(opponent_band.custom_minimum_size.y >= 210.0 and player_band.custom_minimum_size.y >= 210.0, "Player bands should reserve taller presentation space for identity and placeholders.") and
		_assert(opponent_avatar.custom_minimum_size.x >= 180.0 and player_avatar.custom_minimum_size.x >= 180.0 and opponent_avatar.custom_minimum_size.x <= 200.0 and player_avatar.custom_minimum_size.x <= 200.0, "Avatar components should reserve meaningful width without dominating the band.") and
		_assert(battlefield.custom_minimum_size.y >= 340.0, "Battlefield panel should still reserve primary board space after the fit rebalance.") and
		_assert(field_lane_panel != null and shadow_lane_panel != null, "Expected named Field and Shadow lane panels.") and
		_assert(field_player_row != null and field_player_row.alignment == BoxContainer.ALIGNMENT_CENTER, "Lane rows should center their slot groups instead of bunching into a corner.") and
		_assert(field_player_row != null and field_player_row.get_theme_constant("separation") >= 14, "Lane rows should use wider slot spacing.") and
		_assert(battlefield.size.y >= opponent_band.size.y and battlefield.size.y >= player_band.size.y, "Battlefield should receive at least as much vertical emphasis as each player band.")
	)


func _test_board_presentation_regressions(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for board regression verification."):
		return false
	var player_band := screen.find_child("PlayerBand", true, false) as Control
	var battlefield := screen.find_child("BattlefieldPanel", true, false) as Control
	var turn_banner_overlay := screen.find_child("TurnBannerOverlay", true, false) as Control
	var turn_banner_row := turn_banner_overlay.get_child(0) as Control if turn_banner_overlay != null and turn_banner_overlay.get_child_count() > 0 else null
	var lane_card := screen.find_child("lane_player_1_vanguard_card", true, false) as Button
	var lane_content := lane_card.get_meta("content_root", null) as Control if lane_card != null else null
	var lane_display := lane_card.get_meta("card_display_component", null) as Control if lane_card != null else null
	var lane_instance_id := str(lane_card.get_meta("instance_id", "")) if lane_card != null else ""
	var lane_badges := _find_direct_child_by_name_prefix(lane_content, "%s_combat_badges" % lane_instance_id)
	var guard_card := screen.find_child("lane_player_2_bone_guard_card", true, false) as Button
	var guard_content := guard_card.get_meta("content_root", null) as Control if guard_card != null else null
	var guard_instance_id := str(guard_card.get_meta("instance_id", "")) if guard_card != null else ""
	var guard_badges := _find_direct_child_by_name_prefix(guard_content, "%s_combat_badges" % guard_instance_id)
	return (
		_assert(turn_banner_overlay != null and turn_banner_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Turn banner overlay should stay mouse-transparent over the battlefield.") and
		_assert(turn_banner_row != null and turn_banner_row.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Turn banner row should not intercept board clicks while the banner is visible.") and
		_assert(lane_card != null and lane_card.clip_contents, "Board cards should clip presentation content to the visible card frame.") and
		_assert(lane_content != null and lane_content.size.y <= lane_card.size.y, "Board card content should stay inside the visible card frame height.") and
		_assert(lane_display != null and (_card_display_mode(lane_display) == CardDisplayComponent.PRESENTATION_CREATURE_BOARD_MINIMAL), "Lane creatures should render through the creature-board minimal card display mode.") and
		_assert(lane_display != null and lane_display.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Visible board-card art should not absorb clicks away from the owning button.") and
		_assert(lane_content != null and _all_controls_ignore_mouse(lane_content), "Visible board-card content should remain mouse-transparent so the button press path stays reachable.") and
		_assert(lane_badges != null and _badge_row_contains_text(lane_badges, "READY"), "Minimal lane creatures should keep the earlier readiness chip row on the card face.") and
		_assert(guard_card != null and guard_badges != null and _badge_row_contains_text(guard_badges, "WAITING") and _badge_row_contains_text(guard_badges, "GUARD"), "Minimal guard creatures should keep the earlier WAITING/GUARD chip row on the card face.")
	)


func _test_avatar_band_containment(screen: MatchScreen) -> bool:
	var compact_size := Vector2i(1600, 900)
	root.size = compact_size
	screen.size = compact_size
	await _await_frames(2)
	var result := false
	if _assert(screen.load_scenario("local_match"), "Local match scenario should load for avatar containment verification."):
		await _await_frames(2)
		var opponent_avatar_overlay := screen.find_child("OpponentAvatarOverlay", true, false) as Control
		var player_avatar_overlay := screen.find_child("PlayerAvatarOverlay", true, false) as Control
		var opponent_avatar := screen.find_child("player_2_avatar_component", true, false) as PlayerAvatarComponent
		var player_avatar := screen.find_child("player_1_avatar_component", true, false) as PlayerAvatarComponent
		result = (
			_assert(opponent_avatar_overlay != null and player_avatar_overlay != null, "Expected both avatar overlays during avatar containment verification.") and
			_assert(opponent_avatar != null and player_avatar != null, "Expected both avatar components during avatar containment verification.") and
			_assert(opponent_avatar != null and _avatar_badge_is_on_left(opponent_avatar), "Opponent avatar should keep the health badge on the left-hand side.") and
			_assert(player_avatar != null and _avatar_badge_is_on_left(player_avatar), "Local avatar should keep the health badge on the left-hand side.") and
			_assert(opponent_avatar != null and _avatar_runes_deplete_right_to_left(opponent_avatar), "Opponent avatar should keep rune depletion ordered from right to left.") and
			_assert(player_avatar != null and _avatar_runes_deplete_right_to_left(player_avatar), "Local avatar should keep rune depletion ordered from right to left.") and
			_assert(opponent_avatar != null and player_avatar != null and _float_arrays_match(_avatar_orientation_signature(opponent_avatar), _avatar_orientation_signature(player_avatar)), "Opponent/top presentation should not horizontally mirror the avatar badge or rune ordering.")
		)
	root.size = TEST_VIEWPORT_SIZE
	screen.size = TEST_VIEWPORT_SIZE
	await _await_frames(2)
	return result


func _test_placeholder_layout_stability(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for placeholder verification."):
		return false
	var active_player := _active_player(screen.get_match_state())
	var summon_card := _find_hand_card(active_player, "Field Guardian")
	var select_ok := screen.select_card(str(summon_card.get("instance_id", "")))
	screen.clear_selection()
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
		_assert(_placeholder_has_width_protection(hand_empty), "Empty-hand placeholders should reserve horizontal width.") and
		_assert(select_support_ok, "Selecting a support-lab card should still work during placeholder verification.") and
		_assert(_placeholder_has_width_protection(hand_empty_after), "Empty-hand placeholders should stay width-protected after support-card selection refreshes.")
	)


func _test_player_surface_presentation(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for player-surface verification."):
		return false
	var match_state := screen.get_match_state()
	var opponent_state := _player_state(match_state, "player_2")
	var player_state := _player_state(match_state, "player_1")
	var opponent_avatar := screen.find_child("player_2_avatar_component", true, false) as PlayerAvatarComponent
	var player_avatar := screen.find_child("player_1_avatar_component", true, false) as PlayerAvatarComponent
	var opponent_magicka_component := screen.find_child("player_2_magicka_component", true, false) as PlayerMagickaComponent
	var player_magicka_component := screen.find_child("player_1_magicka_component", true, false) as PlayerMagickaComponent
	var old_player_magicka_label := screen.find_child("player_1_magicka_label", true, false)
	var old_player_magicka_bar := screen.find_child("player_1_magicka_bar", true, false)
	var player_ring_label := screen.find_child("player_1_ring_label", true, false) as Label
	var player_deck_button := screen.find_child("player_1_deck_button", true, false) as Button
	var player_discard_button := screen.find_child("player_1_discard_button", true, false) as Button
	if not _assert(player_discard_button != null, "Expected a visible discard pile surface for the local player."):
		return false
	player_discard_button.emit_signal("pressed")
	return (
		_assert(opponent_avatar != null and player_avatar != null, "Expected mounted avatar components for both players.") and
		_assert(opponent_avatar != null and opponent_avatar.health == int(opponent_state.get("health", 0)), "Opponent avatar should reflect the scenario health total through the component root API.") and
		_assert(player_avatar != null and player_avatar.health == int(player_state.get("health", 0)), "Local avatar should reflect the scenario health total through the component root API.") and
		_assert(opponent_avatar != null and opponent_avatar.get_rune_states() == _expected_rune_states(opponent_state), "Opponent avatar runes should reflect the scenario rune thresholds through the component root API.") and
		_assert(player_avatar != null and player_avatar.get_rune_states() == _expected_rune_states(player_state), "Local avatar runes should reflect the scenario rune thresholds through the component root API.") and
		_assert(opponent_avatar != null and opponent_avatar.is_opponent(), "Opponent avatar should use opponent/top presentation.") and
		_assert(player_avatar != null and not player_avatar.is_opponent(), "Local avatar should use local/bottom presentation.") and
			_assert(opponent_magicka_component != null and player_magicka_component != null, "Expected mounted magicka components for both players.") and
			_assert(old_player_magicka_label == null and old_player_magicka_bar == null, "Old inline magicka label/blob row should not be rebuilt once the component is integrated.") and
			_assert(player_magicka_component != null and player_magicka_component.get_segment_count() == int(player_state.get("max_magicka", 0)), "Local magicka component segment count should match max_magicka.") and
			_assert(opponent_magicka_component != null and opponent_magicka_component.get_display_text() == _expected_magicka_text(opponent_state), "Opponent magicka component should reflect spendable/max text through the root API.") and
			_assert(player_magicka_component != null and player_magicka_component.get_display_text() == _expected_magicka_text(player_state), "Local magicka component should reflect spendable/max text through the root API.") and
			_assert(opponent_magicka_component != null and opponent_magicka_component.get_segment_states() == _expected_magicka_states(opponent_state), "Opponent magicka component should reflect the current unlocked/spent/locked state.") and
			_assert(player_magicka_component != null and player_magicka_component.get_segment_states() == _expected_magicka_states(player_state), "Local magicka component should reflect the current unlocked/spent/locked state.") and
		_assert(player_ring_label != null and player_ring_label.text.contains("Ring of Magicka"), "Ring surface should show the Ring of Magicka label.") and
		_assert(player_deck_button != null and player_deck_button.text.contains("Deck"), "Deck pile surface should be visible and labeled.") and
		_assert(player_discard_button.text.contains("Discard"), "Discard pile surface should be visible and labeled.")
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
	var field_guardian_display := field_guardian_button.get_meta("card_display_component", null) as Control if field_guardian_button != null else null
	var shadow_raider_display := shadow_raider_button.get_meta("card_display_component", null) as Control if shadow_raider_button != null else null
	var field_guardian_art := field_guardian_display.find_child("ArtTexture", true, false) as TextureRect if field_guardian_display != null else null
	var field_guardian_rarity := field_guardian_display.find_child("RarityLabel", true, false) as Label if field_guardian_display != null else null
	var field_guardian_rules := field_guardian_display.find_child("RulesLabel", true, false) as RichTextLabel if field_guardian_display != null else null
	var field_guardian_power := field_guardian_display.find_child("AttackLabel", true, false) as Label if field_guardian_display != null else null
	var field_guardian_health := field_guardian_display.find_child("HealthLabel", true, false) as Label if field_guardian_display != null else null
	var shadow_raider_power := shadow_raider_display.find_child("AttackLabel", true, false) as Label if shadow_raider_display != null else null
	var hidden_opponent_button := screen.find_child("hand_player_2_skeletal_sentry_card", true, false) as Button
	var hidden_card_back := screen.find_child("player_2_skeletal_sentry_card_back", true, false) as PanelContainer
	if not _assert(field_guardian_button != null and shadow_raider_button != null and steel_sword_button != null, "Expected named local hand card frames for the fan layout."):
		return false
	field_guardian_button.emit_signal("mouse_entered")
	var hover_scale := field_guardian_button.scale.x
	var hover_z := field_guardian_button.z_index
	field_guardian_button.emit_signal("mouse_exited")
	return (
		_assert(local_hand_row != null and opponent_hand_row != null, "Expected named hand surfaces for both players.") and
		_assert(local_hand_row != null, "Local hand surface should exist as a floating overlay.") and
		_assert(field_guardian_button.text.is_empty(), "Rich card frames should use composed child controls instead of multiline button text.") and
		_assert(field_guardian_button != null and field_guardian_button.custom_minimum_size == CardDisplayComponent.FULL_MINIMUM_SIZE, "Local hand cards should use the shared full-card footprint.") and
		_assert(field_guardian_display != null and (_card_display_mode(field_guardian_display) == CardDisplayComponent.PRESENTATION_FULL), "Visible non-board cards should render through the full card display mode.") and
		_assert(field_guardian_art != null and field_guardian_art.texture != null, "Card frames should surface the placeholder art texture through the shared component.") and
		_assert(field_guardian_rarity != null, "Card frames should have a rarity marker node.") and
		_assert(field_guardian_rules != null and field_guardian_rules.text.contains("Placeholder boosted creature"), "Card frames should surface rules text directly on the frame.") and
		_assert(field_guardian_power != null and _color_reads_green(field_guardian_power.get_theme_color("font_color")), "Buffed creature power should color green.") and
		_assert(field_guardian_health != null and _color_reads_green(field_guardian_health.get_theme_color("font_color")), "Buffed creature health should color green.") and
		_assert(shadow_raider_power != null and _color_reads_red(shadow_raider_power.get_theme_color("font_color")), "Reduced creature power should color red.") and
		_assert(field_guardian_button.position.x + field_guardian_button.size.x > shadow_raider_button.position.x, "Local hand cards should intentionally overlap instead of sitting in a plain row.") and
		_assert(hover_scale > 1.0 and hover_z > 0, "Local hand hover should enlarge and raise the hovered card.") and
		_assert(is_equal_approx(field_guardian_button.scale.x, 1.0), "Hover emphasis should reset cleanly after the pointer leaves.") and
		_assert(grand_colossus_button != null and grand_colossus_button.self_modulate.a < 0.9, "Unaffordable local hand cards should be visually muted.") and
		_assert(hidden_opponent_button != null and hidden_opponent_button.disabled, "Opponent hand cards should render as hidden backs rather than selectable text frames.") and
		_assert(hidden_card_back != null, "Opponent hand should render a card back panel.")
	)


func _test_match_card_display_modes(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for card-display integration verification."):
		return false
	await _await_frames(2)
	var lane_card := screen.find_child("lane_player_1_vanguard_card", true, false) as Button
	var lane_display := lane_card.get_meta("card_display_component", null) as Control if lane_card != null else null
	var lane_instance_id := str(lane_card.get_meta("instance_id", "")) if lane_card != null else ""
	var hand_card := screen.find_child("hand_player_1_field_guardian_card", true, false) as Button
	var hand_display := hand_card.get_meta("card_display_component", null) as Control if hand_card != null else null
	if not _assert(lane_card != null and lane_display != null and hand_display != null, "Expected live hand and lane card buttons to expose shared card-display components."):
		return false
	var preview_before := _find_node_by_name_prefix(screen, "lane_hover_preview_")
	var hand_mode := _card_display_mode(hand_display)
	var lane_mode := _card_display_mode(lane_display)
	lane_card.emit_signal("mouse_entered")
	await _await_frames(2)
	var preview_immediate := _find_node_by_name_prefix(screen, "lane_hover_preview_")
	await create_timer(1.1).timeout
	await _await_frames(2)
	var preview_after_delay := _find_node_by_name_prefix(screen, "lane_hover_preview_") as Control
	var preview_component = preview_after_delay.get_child(0) if preview_after_delay != null and preview_after_delay.get_child_count() > 0 else preview_after_delay
	var preview_mode_matches := preview_component != null and (_card_display_mode(preview_component) == CardDisplayComponent.PRESENTATION_FULL)
	var preview_ignores_mouse := preview_after_delay != null and preview_after_delay.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var preview_overlays := false
	if preview_after_delay != null:
		var preview_center := preview_after_delay.get_global_rect().get_center()
		var card_center := lane_card.get_global_rect().get_center()
		preview_overlays = absf(preview_center.x - card_center.x) < preview_after_delay.size.x * 0.5 and absf(preview_center.y - card_center.y) < preview_after_delay.size.y * 0.5
	lane_card.emit_signal("mouse_exited")
	await _await_frames(2)
	var preview_after_exit := _find_node_by_name_prefix(screen, "lane_hover_preview_")
	var attacker_click_ok := _click_control(lane_card)
	await process_frame
	var attack_state_after_hover := screen.get_interaction_state()
	return (
		_assert(hand_mode == CardDisplayComponent.PRESENTATION_FULL, "Visible non-board cards should keep the full card display mode in match UI.") and
		_assert(lane_mode == CardDisplayComponent.PRESENTATION_CREATURE_BOARD_MINIMAL, "Lane creatures should use creature-board minimal rendering in match UI.") and
		_assert(preview_before == null and preview_immediate == null, "Lane hover previews should wait about one second before appearing.") and
		_assert(preview_mode_matches, "Lane hover previews should render as floating full card displays.") and
		_assert(preview_ignores_mouse, "Lane hover previews should stay mouse-transparent so they do not block board interaction.") and
		_assert(preview_overlays, "Lane hover previews should overlay the hovered lane card.") and
		_assert(preview_after_exit == null, "Lane hover previews should clear when the pointer leaves the lane card.") and
		_assert(attacker_click_ok, "After a hover-preview cycle, real pointer clicks should still reach the lane creature.") and
		_assert(attack_state_after_hover.get("selection_mode", "") == "attack", "After a hover-preview cycle, clicking the lane creature should still enter attack targeting mode.") and
		_assert(screen.get_selected_instance_id() == lane_instance_id, "After a hover-preview cycle, clicking the lane creature should still select that same board card.") and
		_assert(not attack_state_after_hover.get("valid_target_instance_ids", []).is_empty(), "After a hover-preview cycle, legal attack targets should still be surfaced.")
	)


func _test_turn_state_presentation(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for turn-state verification."):
		return false
	var turn_banner_panel := screen.find_child("TurnBannerPanel", true, false) as Control
	var turn_banner_label := screen.find_child("TurnBannerLabel", true, false) as Label
	var end_turn_button := _find_button_with_text(screen, "End Turn")
	var player_band := screen.find_child("PlayerBand", true, false) as Control
	var initial_state := screen.get_interaction_state()
	var initial_banner_visible := turn_banner_panel.visible if turn_banner_panel != null else false
	var initial_banner_text := turn_banner_label.text if turn_banner_label != null else ""
	var initial_end_turn_disabled := end_turn_button.disabled if end_turn_button != null else true
	var initial_border_width := _button_border_width(end_turn_button, "disabled" if initial_end_turn_disabled else "normal")
	var initial_brightness := _button_background_brightness(end_turn_button, "disabled" if initial_end_turn_disabled else "normal")
	if not _assert(screen.end_turn_action(), "Advancing the scenario turn should succeed for turn-state verification."):
		return false
	var next_state := screen.get_interaction_state()
	var next_banner_visible := turn_banner_panel.visible if turn_banner_panel != null else false
	var next_banner_text := turn_banner_label.text if turn_banner_label != null else ""
	var next_end_turn_disabled := end_turn_button.disabled if end_turn_button != null else true
	var next_border_width := _button_border_width(end_turn_button, "disabled" if next_end_turn_disabled else "normal")
	var next_brightness := _button_background_brightness(end_turn_button, "disabled" if next_end_turn_disabled else "normal")
	var next_hand_button := screen.find_child("hand_player_1_field_guardian_card", true, false) as Button
	var ready_banner_visible := initial_banner_visible if bool(initial_state.get("local_turn", false)) else next_banner_visible
	var ready_banner_text := initial_banner_text if bool(initial_state.get("local_turn", false)) else next_banner_text
	var ready_end_turn_disabled := initial_end_turn_disabled if bool(initial_state.get("local_turn", false)) else next_end_turn_disabled
	var ready_border_width := initial_border_width if bool(initial_state.get("local_turn", false)) else next_border_width
	var ready_brightness := initial_brightness if bool(initial_state.get("local_turn", false)) else next_brightness
	var ready_state := initial_state if bool(initial_state.get("local_turn", false)) else next_state
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
		_assert(ready_banner_visible, "A transient turn banner should appear when the local player becomes active.") and
		_assert(ready_banner_text == "Your Turn", "Transient turn banner should clearly announce the local turn owner.") and
		_assert(bool(ready_state.get("local_turn", false)) and not bool(ready_state.get("local_controls_locked", true)), "Interaction state should report the opening turn as locally actionable.") and
		_assert(not ready_end_turn_disabled, "End Turn should be usable on the local player's turn.") and
		_assert(ready_border_width >= 2, "End Turn should gain a stronger CTA border treatment when it is ready.") and
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
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for detach verification."):
		return false
	active_player = _active_player(screen.get_match_state())
	summon_card = _find_hand_card(active_player, "Field Guardian")
	summon_id = str(summon_card.get("instance_id", ""))
	var detach_ok := screen.detach_hand_card(summon_id)
	var detach_state := screen.get_interaction_state()
	var detached_button := screen.find_child("hand_player_1_field_guardian_card", true, false) as Button
	var detached_button_hidden := detached_button != null and not detached_button.visible
	screen.clear_selection()
	var after_cancel_state := screen.get_interaction_state()
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for detach play verification."):
		return false
	active_player = _active_player(screen.get_match_state())
	summon_card = _find_hand_card(active_player, "Field Guardian")
	summon_id = str(summon_card.get("instance_id", ""))
	var detach_play_ok := screen.detach_hand_card(summon_id)
	var play_result := screen.play_selected_to_lane("shadow", 0)
	return (
		_assert(select_ok, "Selecting a hand creature should expose interaction highlights.") and
		_assert(field_guardian_button != null and field_guardian_button.scale.x > 1.0, "Selected local hand cards should remain visually lifted for readability.") and
		_assert(interaction_state.get("selection_mode", "") == "summon", "Creature hand selection should enter summon interaction mode.") and
		_assert(interaction_state.get("valid_lane_slot_keys", []).size() >= 2, "Summon selection should highlight multiple valid drop slots.") and
		_assert(not interaction_state.get("valid_lane_slot_keys", []).has("field:player_2:1"), "Opponent lane slots should not be listed as valid summon drops.") and
		_assert(invalid_state.get("invalid_lane_slot_keys", []).has("field:player_2:1"), "Clicking an invalid drop slot should record invalid slot feedback.") and
		_assert(invalid_slot_message.contains("Select a creature that can be summoned"), "Invalid summon target feedback should explain the required drop zone.") and
		_assert(detach_ok, "Playable hand creatures should support detach-and-follow interaction.") and
		_assert(bool(detach_state.get("detached_active", false)), "Detaching a hand card should activate detached state.") and
		_assert(detached_button_hidden, "Detached card button should be hidden in the hand.") and
		_assert(not bool(after_cancel_state.get("detached_active", false)), "Clearing selection should cancel detached state.") and
		_assert(detach_play_ok, "Detach for play verification should start successfully.") and
		_assert(bool(play_result.get("is_valid", false)), "Playing a detached card to a lane should resolve successfully.") and
		_assert(_lane_contains(screen.get_match_state(), "shadow", str(active_player.get("player_id", "")), summon_id), "Successful detach-and-play should place the card into the requested lane.")
	)


func _test_support_row_click_placement(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("support_lab"), "Support lab should load for support play verification."):
		return false
	await _await_frames(2)
	var active_player := _active_player(screen.get_match_state())
	var support_card := _find_hand_card(active_player, "Battle Drum")
	if not _assert(not support_card.is_empty(), "Support lab should expose a hand support for play verification."):
		return false
	var support_id := str(support_card.get("instance_id", ""))
	var select_ok := screen.select_card(support_id)
	await process_frame
	var interaction_state := screen.get_interaction_state()
	var play_result := screen.play_or_activate_selected()
	await process_frame
	var match_state := screen.get_match_state()
	var played_support := screen.find_child("support_%s_card" % support_id, true, false) as Button
	var played_support_display := played_support.get_meta("card_display_component", null) as Control if played_support != null else null
	return (
		_assert(select_ok, "Selecting the support-lab support should succeed.") and
		_assert(interaction_state.get("selection_mode", "") == "support", "Hand support selection should enter support interaction mode.") and
		_assert(interaction_state.get("valid_target_instance_ids", []).is_empty(), "Hand support placement should not mis-highlight lane cards as support targets.") and
		_assert(bool(play_result.get("is_valid", false)), "Playing a selected support should succeed.") and
		_assert(screen.get_selected_instance_id().is_empty(), "Successful support plays should clear selection after placement.") and
		_assert(_support_contains(match_state, "player_1", support_id), "Playing a support should place it into the local support zone.") and
		_assert(played_support_display != null and (_card_display_mode(played_support_display) == CardDisplayComponent.PRESENTATION_SUPPORT_BOARD_MINIMAL), "Played supports should render in the support-board minimal display mode in the support row.") and
		_assert(_find_hand_card(_active_player(match_state), "Battle Drum").is_empty(), "Successful support plays should remove the support from hand.")
	)


func _test_live_lane_click_delivery(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for live board-click verification."):
		return false
	await _await_frames(3)
	var attacker := _find_lane_card(screen.get_match_state(), "Vanguard Captain")
	var defender := _find_lane_card(screen.get_match_state(), "Bone Guard")
	var attacker_card := screen.find_child("lane_player_1_vanguard_card", true, false) as Button
	var attacker_click_ok := _click_control(attacker_card)
	await process_frame
	var attack_state := screen.get_interaction_state()
	var defender_card := screen.find_child("lane_player_2_bone_guard_card", true, false) as Button
	var defender_click_ok := _click_control(defender_card)
	await process_frame
	var match_state := screen.get_match_state()
	return (
		_assert(not attacker.is_empty(), "Live click verification requires a ready local attacker in the scenario.") and
		_assert(not defender.is_empty(), "Live click verification requires a legal enemy defender in the scenario.") and
		_assert(attacker_click_ok, "Real pointer clicks should be deliverable to the ready local lane creature.") and
		_assert(attack_state.get("selection_mode", "") == "attack", "A real click on the ready local lane creature should enter attack targeting mode.") and
		_assert(attack_state.get("valid_target_instance_ids", []).has(str(defender.get("instance_id", ""))), "A real lane-creature click should surface valid attack targets.") and
		_assert(defender_click_ok, "Real pointer clicks should be deliverable to a legal defender target.") and
		_assert(screen.get_selected_instance_id().is_empty(), "A completed legal attack through the live click path should clear selection afterward.") and
		_assert(not _lane_contains(match_state, "field", "player_2", str(defender.get("instance_id", ""))), "A legal attack should still resolve through the same live click interaction flow.")
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
	var attacker_card := screen.find_child("lane_player_1_vanguard_card", true, false) as Button
	var attacker_select_ok := attacker_card != null
	if attacker_card != null:
		attacker_card.emit_signal("pressed")
	var attack_state := screen.get_interaction_state()
	var attack_bone_guard := _find_lane_card(screen.get_match_state(), "Bone Guard")
	var opponent_avatar := screen.find_child("player_2_avatar_component", true, false) as Control
	if opponent_avatar != null:
		var click_event := InputEventMouseButton.new()
		click_event.pressed = true
		click_event.button_index = MOUSE_BUTTON_LEFT
		opponent_avatar.gui_input.emit(click_event)
	var invalid_attack_state := screen.get_interaction_state()
	var invalid_attack_message := screen.get_status_message()
	return (
		_assert(item_select_ok, "Selecting the sandbox item should succeed.") and
		_assert(item_state.get("selection_mode", "") == "item", "Item selection should enter item targeting mode.") and
		_assert(item_state.get("valid_target_instance_ids", []).has(str(vanguard.get("instance_id", ""))), "Item selection should highlight the valid friendly equip target.") and
		_assert(item_state.get("valid_target_instance_ids", []).has(str(bone_guard.get("instance_id", ""))), "Item highlights should follow current engine legality, including sandbox enemy targets when legal.") and
		_assert(invalid_item_state.get("invalid_lane_slot_keys", []).has("field:player_1:1"), "Invalid non-creature item drops should be surfaced for feedback.") and
		_assert(invalid_item_message.contains("Select a creature"), "Invalid item drop feedback should explain that a creature target is required.") and
		_assert(attacker_select_ok, "Selecting the sandbox attacker through the visible board-card button should succeed.") and
		_assert(screen.get_selected_instance_id() == str(attacker.get("instance_id", "")), "Real lane-card clicks should select the ready local attacker.") and
		_assert(attack_state.get("selection_mode", "") == "attack", "Lane creature selection should enter attack targeting mode.") and
		_assert(attack_state.get("valid_target_instance_ids", []).has(str(attack_bone_guard.get("instance_id", ""))), "Attack selection should highlight valid enemy defenders.") and
		_assert(attack_state.get("valid_target_player_ids", []).is_empty(), "Enemy player should not highlight while Guard blocks face attacks.") and
		_assert(invalid_attack_state.get("invalid_player_ids", []).has("player_2"), "Blocked face attacks should mark the enemy player as an invalid target.") and
		_assert(invalid_attack_message.contains("can't attack"), "Invalid face attacks should explain why the target is blocked.")
	)


func _test_combat_feedback(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should load for combat feedback verification."):
		return false
	var active_player := _active_player(screen.get_match_state())
	var summon_card := _find_hand_card(active_player, "Field Guardian")
	var summon_id := str(summon_card.get("instance_id", ""))
	if not _assert(screen.select_card(str(summon_card.get("instance_id", ""))), "Field Guardian should be selectable for readiness feedback verification."):
		return false
	var summon_result := screen.play_selected_to_lane("shadow", 0)
	var summoned_card := screen.find_child("lane_%s_card" % summon_id, true, false) as Button
	var summoned_content := summoned_card.get_meta("content_root", null) as Control if summoned_card != null else null
	var summoned_badges := _find_direct_child_by_name_prefix(summoned_content, "%s_combat_badges" % summon_id)
	var attacker := _find_lane_card(screen.get_match_state(), "Vanguard Captain")
	var defender := _find_lane_card(screen.get_match_state(), "Bone Guard")
	var attacker_card := screen.find_child("lane_player_1_vanguard_card", true, false) as Button
	var defender_card := screen.find_child("lane_player_2_bone_guard_card", true, false) as Button
	if not _assert(attacker_card != null, "Combat feedback verification requires the visible local attacker button."):
		return false
	attacker_card.emit_signal("pressed")
	var attack_state := screen.get_interaction_state()
	if not _assert(defender_card != null, "Combat feedback verification requires the visible defender button."):
		return false
	defender_card.emit_signal("pressed")
	var feedback_state := screen.get_feedback_state()
	var attack_banner := _find_node_by_name_prefix(screen, "feedback_attack_")
	var damage_popup := _find_node_by_name_prefix(screen, "feedback_damage_")
	var removal_toast := _find_node_by_name_prefix(screen, "feedback_removal_")
	return (
		_assert(bool(summon_result.get("is_valid", false)), "Summoning the readiness test creature should succeed.") and
		_assert(summoned_card != null and summoned_badges != null and _badge_row_contains_text(summoned_badges, "WAITING") and _badge_row_contains_text(summoned_badges, "GUARD"), "Freshly summoned shadow-lane creatures should keep the earlier WAITING/GUARD chip row on the minimal card face when the creature has Guard.") and
		_assert(attack_state.get("valid_target_instance_ids", []).has(str(defender.get("instance_id", ""))), "The ready local attacker should expose the Guard defender as a valid board target before the click resolves.") and
		_assert(screen.get_selected_instance_id().is_empty(), "Successful board-button combat should clear selection after the attack resolves.") and
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
	var active_player := _active_player(screen.get_match_state())
	var charges_before := int(active_player.get("ring_of_magicka_charges", 0))
	var ring_ok := screen.use_ring()
	var active_after := _active_player(screen.get_match_state())
	var charges_after := int(active_after.get("ring_of_magicka_charges", 0))
	var player_ring_label := screen.find_child("player_1_ring_label", true, false) as Label
	var player_magicka_component := screen.find_child("player_1_magicka_component", true, false) as PlayerMagickaComponent
	return (
		_assert(ring_ok, "Active local player should be able to use the Ring of Magicka.") and
		_assert(charges_after == charges_before - 1, "Ring usage should spend exactly one charge.") and
		_assert(player_ring_label != null and player_ring_label.text.contains("Ring of Magicka"), "Ring surface should still display after a Ring charge is spent.") and
			_assert(player_magicka_component != null and player_magicka_component.get_display_text() == _expected_magicka_text(active_after), "Magicka component text should update after Ring-granted temporary magicka.") and
			_assert(player_magicka_component != null and player_magicka_component.get_segment_states() == _expected_magicka_states(active_after), "Magicka component segments should show the live temporary-magicka state after Ring usage.") and
			_assert(player_magicka_component != null and player_magicka_component.get_segment_states().has(PlayerMagickaComponent.STATE_TEMPORARY), "Ring usage should surface a yellow temporary-magicka segment while the temp resource is active.")
	)


func _test_prophecy_prompt_flow(screen: MatchScreen) -> bool:
	if not _assert(screen.load_scenario("prophecy_lab"), "Prophecy scenario should load." ):
		return false
	var pending_ids := screen.get_pending_prophecy_ids()
	if not _assert(pending_ids.size() == 1, "Expected exactly one pending Prophecy card."):
		return false
	var prophecy_id := str(pending_ids[0])
	var select_ok := screen.select_card(prophecy_id)
	var play_result := screen.play_selected_to_lane("field", 1)
	var active_prophecy_ids := screen.get_pending_prophecy_ids()
	var responding_player_id := "player_2"
	return (
		_assert(select_ok, "Selecting the pending Prophecy card should succeed.") and
		_assert(bool(play_result.get("is_valid", false)), "Playing the pending Prophecy creature through the UI should succeed.") and
		_assert(active_prophecy_ids.is_empty(), "Prophecy window should close after the free play resolves.") and
		_assert(_lane_contains(screen.get_match_state(), "field", responding_player_id, prophecy_id), "Prophecy creature should land in the requested lane.")
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
	var has_normal_draw_feedback_surface := draw_popup != null or draw_toast != null
	if not _assert(screen.load_scenario("local_match"), "Local match scenario should reload for explicit rune-break feedback verification."):
		return false
	var opponent_avatar := screen.find_child("player_2_avatar_component", true, false) as PlayerAvatarComponent
	var baseline_rune_signature := _avatar_rune_size_signature(opponent_avatar)
	var rune_result: Dictionary = MatchTiming.apply_player_damage(screen.get_match_state(), "player_2", 5, {"reason": "ui_test"})
	screen._record_feedback_from_events(rune_result.get("events", []))
	screen.clear_selection()
	var rune_feedback := screen.get_feedback_state()
	var rune_toast := _find_node_by_name_prefix(screen, "feedback_rune_toast_")
	var rune_banner := _find_node_by_name_prefix(screen, "feedback_rune_banner_")
	var has_rune_feedback_surface := rune_toast != null and rune_banner != null
	var active_rune_signature := _avatar_rune_size_signature(opponent_avatar)
	for feedback in screen._rune_feedbacks:
		if typeof(feedback) == TYPE_DICTIONARY:
			feedback["expires_at_ms"] = 0
	for feedback in screen._draw_feedbacks:
		if typeof(feedback) == TYPE_DICTIONARY and bool(feedback.get("from_rune_break", false)):
			feedback["expires_at_ms"] = 0
	screen.clear_selection()
	await _await_frames(2)
	var post_cycle_rune_signature := _avatar_rune_size_signature(opponent_avatar)
	var expired_rune_banner := _find_node_by_name_prefix(screen, "feedback_rune_banner_")
	if not _assert(screen.load_scenario("prophecy_lab"), "Prophecy scenario should reload for rune-break presentation verification."):
		return false
	var prophecy_ids := screen.get_pending_prophecy_ids()
	if not _assert(prophecy_ids.size() == 1, "Prophecy presentation scenario should expose a single pending Prophecy card."):
		return false
	var prophecy_id := str(prophecy_ids[0])
	var prophecy_overlay := screen.find_child("prophecy_local_vbox", true, false) as Control
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
		_assert(has_normal_draw_feedback_surface, "Normal draws should surface visible player-surface feedback instead of updating silently.") and
		_assert(opponent_avatar != null, "Rune-break presentation verification requires the mounted opponent avatar component.") and
		_assert(rune_feedback.get("runes", []).size() >= 1, "Rune breaks should register a presentation payload for the broken rune.") and
		_assert(rune_feedback.get("draws", []).size() >= 1, "Rune-break draws should register a visible draw payload.") and
		_assert(_float_arrays_match(baseline_rune_signature, active_rune_signature), "Rune-break feedback should not inflate avatar rune token size while SHATTER feedback is active.") and
		_assert(_float_arrays_match(baseline_rune_signature, post_cycle_rune_signature), "Avatar rune tokens should return to and stay at their compact size after the rune-break feedback cycle.") and
		_assert(prophecy_overlay != null and prophecy_overlay.visible, "Pending Prophecy should show a card overlay on the board.") and
		_assert((prophecy_badge != null and prophecy_free_badge != null) or prophecy_card_banner != null or prophecy_overlay != null, "Pending Prophecy cards should render stronger interrupt badges directly on the card frame.") and
		_assert(has_rune_feedback_surface, "Rune breaks should add both a player-surface toast and a shatter-style rune banner.") and
		_assert(expired_rune_banner == null, "Rune-break feedback banners should clear when the transient presentation expires.") and
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


func _card_display_mode(node: Node) -> String:
	if node == null or not node.has_method("get_presentation_mode"):
		return ""
	return str(node.call("get_presentation_mode"))


func _find_direct_child_by_name_prefix(parent: Node, prefix: String) -> Node:
	if parent == null:
		return null
	for child in parent.get_children():
		if str(child.name).begins_with(prefix):
			return child
	return null


func _badge_row_contains_text(parent: Node, text: String) -> bool:
	if parent == null:
		return false
	for child in parent.get_children():
		for label in child.find_children("*", "Label", true, false):
			if (label as Label).text == text:
				return true
	return false


func _active_player(match_state: Dictionary) -> Dictionary:
	var active_player_id := str(match_state.get("active_player_id", ""))
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == active_player_id:
			return player
	return {}


func _player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


func _expected_rune_states(player: Dictionary) -> Array:
	var rune_thresholds: Array = player.get("rune_thresholds", [])
	var states: Array = []
	for threshold in DISPLAY_RUNE_THRESHOLDS:
		states.append(rune_thresholds.has(threshold))
	return states


func _expected_magicka_text(player: Dictionary) -> String:
	var current := maxi(0, int(player.get("current_magicka", 0)))
	var temporary := maxi(0, int(player.get("temporary_magicka", 0)))
	var max_magicka := maxi(0, int(player.get("max_magicka", 0)))
	return "%d/%d" % [current + temporary, max_magicka]


func _expected_magicka_states(player: Dictionary) -> Array:
	var states: Array = []
	var raw_current := int(player.get("current_magicka", 0))
	var raw_max := int(player.get("max_magicka", 0))
	var raw_temp := int(player.get("temporary_magicka", 0))
	var segment_count := maxi(1, maxi(raw_max, raw_current + raw_temp))
	var current := maxi(0, mini(segment_count, raw_current))
	var max_magicka := maxi(0, mini(segment_count, raw_max))
	var temporary := maxi(0, mini(segment_count - current, raw_temp))
	for slot_index in range(segment_count):
		var state := PlayerMagickaComponent.STATE_LOCKED
		if slot_index < current:
			state = PlayerMagickaComponent.STATE_REMAINING
		elif slot_index < current + temporary:
			state = PlayerMagickaComponent.STATE_TEMPORARY
		elif slot_index < max_magicka:
			state = PlayerMagickaComponent.STATE_SPENT
		states.append(state)
	return states


func _lane_contains(match_state: Dictionary, lane_id: String, player_id: String, instance_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
				return true
	return false


func _support_contains(match_state: Dictionary, player_id: String, instance_id: String) -> bool:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) != player_id:
			continue
		for card in player.get("support", []):
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


func _all_controls_ignore_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _all_controls_ignore_mouse(child):
			return false
	return true


func _avatar_layout_controls(component: PlayerAvatarComponent) -> Array:
	if component == null:
		return []
	var controls: Array = [
		component.find_child("MedallionOuter", true, false) as Control,
		component.find_child("HealthBadge", true, false) as Control,
	]
	for threshold in DISPLAY_RUNE_THRESHOLDS:
		controls.append(component.get_rune_anchor(threshold))
	return controls


func _avatar_orientation_signature(component: PlayerAvatarComponent) -> Array:
	if component == null:
		return []
	var medallion := component.find_child("MedallionOuter", true, false) as Control
	var badge := component.find_child("HealthBadge", true, false) as Control
	if medallion == null or badge == null:
		return []
	var signature: Array = [badge.position.x - medallion.position.x]
	for threshold in DISPLAY_RUNE_THRESHOLDS:
		var rune := component.get_rune_anchor(threshold)
		if rune == null:
			return []
		signature.append((rune as Control).position.x - medallion.position.x)
	return signature


func _avatar_rune_size_signature(component: PlayerAvatarComponent) -> Array:
	if component == null:
		return []
	var signature: Array = []
	for threshold in DISPLAY_RUNE_THRESHOLDS:
		var rune := component.get_rune_anchor(threshold)
		if rune == null:
			return []
		signature.append_array([
			(rune as Control).size.x,
			(rune as Control).size.y,
		])
	return signature


func _avatar_badge_is_on_left(component: PlayerAvatarComponent) -> bool:
	if component == null:
		return false
	var medallion := component.find_child("MedallionOuter", true, false) as Control
	var badge := component.find_child("HealthBadge", true, false) as Control
	if medallion == null or badge == null:
		return false
	return badge.get_global_rect().get_center().x < medallion.get_global_rect().get_center().x


func _avatar_runes_deplete_right_to_left(component: PlayerAvatarComponent) -> bool:
	if component == null:
		return false
	var previous_center_x := INF
	for threshold in DISPLAY_RUNE_THRESHOLDS:
		var rune := component.get_rune_anchor(threshold)
		if rune == null:
			return false
		var center_x := (rune as Control).get_global_rect().get_center().x
		if center_x >= previous_center_x:
			return false
		previous_center_x = center_x
	return true


func _float_arrays_match(left: Array, right: Array, tolerance := 1.0) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if absf(float(left[index]) - float(right[index])) > tolerance:
			return false
	return true


func _control_fits_inside(container: Control, target: Control) -> bool:
	if container == null or target == null:
		return false
	return container.get_global_rect().grow(0.5).encloses(target.get_global_rect())


func _controls_fit_inside(container: Control, controls: Array) -> bool:
	if container == null:
		return false
	var container_rect := container.get_global_rect().grow(0.5)
	for control in controls:
		if not (control is Control):
			return false
		if not container_rect.encloses((control as Control).get_global_rect()):
			return false
	return true


func _click_control(control: Control) -> bool:
	if control == null:
		return false
	var center := control.get_global_rect().position + control.get_global_rect().size * 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	press.global_position = center
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = center
	release.global_position = center
	root.push_input(release)
	return true


func _await_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false