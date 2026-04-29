class_name MatchScreenRefresh
extends RefCounted

var _screen  # MatchScreen reference

# Per-row hash cache for skipping unchanged lane rebuilds. Keyed by lane_row_key.
var _lane_row_hashes: Dictionary = {}

func _init(screen) -> void:
	_screen = screen


func _refresh_ui() -> void:
	var _refresh_start := Time.get_ticks_msec()
	print("[REFRESH] _refresh_ui START at %d" % _refresh_start)
	_screen._feedback._prune_feedback_state()
	_screen._hover._clear_lane_card_hover_preview()
	_screen._clear_support_card_hover_preview()
	_screen._card_buttons = {}
	_screen._lane_slot_buttons = {}
	_screen._selection._invalidate_target_validity_cache()
	_screen._selection._reset_perf_counters()
	var _t_overlays := Time.get_ticks_usec()
	_refresh_turn_presentation()
	_screen._overlays._refresh_prophecy_overlay()
	_screen._overlays._refresh_discard_choice_overlay()
	_screen._overlays._refresh_consume_selection_overlay()
	_screen._overlays._refresh_deck_selection_overlay()
	_screen._overlays._refresh_player_choice_overlay()
	_screen._targeting._refresh_pending_summon_effect_target()
	_screen._refresh_hand_selection_state()
	_screen._refresh_free_play_state()
	_screen._refresh_top_deck_choice_state()
	var _overlays_us := Time.get_ticks_usec() - _t_overlays
	var _t_sections := Time.get_ticks_usec()
	_refresh_player_sections()
	var _sections_us := Time.get_ticks_usec() - _t_sections
	var _t_lanes := Time.get_ticks_usec()
	_refresh_lanes()
	var _lanes_us := Time.get_ticks_usec() - _t_lanes
	_refresh_end_turn_button()
	_refresh_match_end_overlay()
	_screen._history._scan_and_refresh_match_history()
	_screen._feedback._apply_presentation_feedback()
	if not _screen._pending_free_play_detach_id.is_empty():
		var detach_id: String = _screen._pending_free_play_detach_id
		_screen._pending_free_play_detach_id = ""
		_screen._hand._detach_hand_card.call_deferred(detach_id, true)
	if not _screen._hand._detached_card_state.is_empty():
		var detached_id: String = str(_screen._hand._detached_card_state.get("instance_id", ""))
		var detached_button: Button = _screen._card_buttons.get(detached_id)
		if detached_button != null:
			detached_button.visible = false
		elif not _screen._overlays._has_active_prophecy_overlay(detached_id):
			_screen._hand._cancel_detached_card_silent()
	if not _screen._targeting._targeting_arrow_state.is_empty():
		var arrow_id: String = str(_screen._targeting._targeting_arrow_state.get("instance_id", ""))
		var arrow_button: Button = _screen._card_buttons.get(arrow_id)
		var summon_source_id := str(_screen._targeting._pending_summon_target.get("source_instance_id", ""))
		var is_pending_summon_source := arrow_id == summon_source_id and not summon_source_id.is_empty()
		var has_action_preview: bool = _screen._targeting._targeting_arrow_state.get("action_preview") != null
		if arrow_button != null:
			if has_action_preview:
				arrow_button.visible = false
			elif not is_pending_summon_source:
				arrow_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif not is_pending_summon_source and not has_action_preview and not _screen._overlays._has_active_prophecy_overlay(arrow_id):
			_screen._targeting._cancel_targeting_mode_silent()
	# Hide Alduin's lane card during board wipe animation (use modulate instead of
	# visible so the button still participates in container layout and has a valid
	# global_position for the fly-to-board animation)
	if not _screen._animations._board_wipe_hidden_id.is_empty():
		var wipe_btn: Button = _screen._card_buttons.get(_screen._animations._board_wipe_hidden_id)
		if wipe_btn != null:
			wipe_btn.modulate = Color(1, 1, 1, 0)
			wipe_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hide Abomination during Mecinar stitch animation
	if not _screen._animations._stitch_hidden_id.is_empty():
		var stitch_btn: Button = _screen._card_buttons.get(_screen._animations._stitch_hidden_id)
		if stitch_btn != null:
			stitch_btn.modulate = Color(1, 1, 1, 0)
			stitch_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._feedback._process_overdraw_queue()
	var _refresh_elapsed := Time.get_ticks_msec() - _refresh_start
	print("[REFRESH] _refresh_ui END took %dms (overlays=%dus sections=%dus lanes=%dus)" % [_refresh_elapsed, _overlays_us, _sections_us, _lanes_us])
	print(_screen._selection._format_perf_summary())



func _compute_support_row_hash(player_id: String, supports: Array) -> Dictionary:
	var iids: Array = []
	for c in supports:
		if typeof(c) == TYPE_DICTIONARY:
			iids.append("%s:%d:%d:%d" % [
				str(c.get("instance_id", "")),
				int(c.get("damage_marked", 0)),
				int(c.get("activations_this_turn", 0)),
				int(c.get("remaining_support_uses", -1)),
			])
	return {
		"player": player_id,
		"iids": iids,
		"selected": _screen._selected_instance_id,
		"invalid_ids": _screen._invalid_feedback.get("instance_ids", []),
		"summon_target_active": not _screen._targeting._pending_summon_target.is_empty(),
		"active_player": _screen._active_player_id(),
	}


func _compute_lane_row_hash(lane_id: String, player_id: String, slots: Array) -> Dictionary:
	var card_digests: Array = []
	for card in slots:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var statuses = card.get("status_markers", [])
		var statuses_str := ""
		if typeof(statuses) == TYPE_ARRAY:
			var sorted_statuses: Array = statuses.duplicate()
			sorted_statuses.sort()
			var status_parts: Array = []
			for s in sorted_statuses:
				status_parts.append(str(s))
			statuses_str = ",".join(status_parts)
		var attached = card.get("attached_items", [])
		card_digests.append({
			"iid": str(card.get("instance_id", "")),
			"power": int(card.get("power", 0)),
			"health": int(card.get("health", 0)),
			"damage": int(card.get("damage_marked", 0)),
			"statuses": statuses_str,
			"attacked": bool(card.get("has_attacked_this_turn", false)),
			"items": (attached.size() if typeof(attached) == TYPE_ARRAY else 0),
		})
	return {
		"lane": lane_id,
		"player": player_id,
		"cards": card_digests,
		"selected": _screen._selected_instance_id,
		"invalid_ids": _screen._invalid_feedback.get("instance_ids", []),
		"betray_active": not _screen._betray._pending_betray.is_empty(),
		"betray_phase": str(_screen._betray._pending_betray.get("sacrifice_instance_id", "")),
		"summon_target_active": not _screen._targeting._pending_summon_target.is_empty(),
		"summon_source": str(_screen._targeting._pending_summon_target.get("source_instance_id", "")),
		"targeting_arrow_iid": str(_screen._targeting._targeting_arrow_state.get("instance_id", "")),
		"selected_action_mode": _screen._selection._selected_action_mode(_screen._selection._selected_card()),
		"active_player": _screen._active_player_id(),
	}


func _compute_hand_section_hash(player_id: String, player: Dictionary, hand_public: bool) -> Dictionary:
	var hand_iids: Array = []
	for card in player.get("hand", []):
		var iid := str(card.get("instance_id", ""))
		if _screen._overlays._has_active_prophecy_overlay(iid):
			continue
		if iid in _screen._draw_animating_ids:
			continue
		hand_iids.append("%s:%d:%d" % [iid, int(card.get("cost", 0)), int(card.get("_permanent_empower_bonus", 0))])
	return {
		"iids": hand_iids,
		"selected": _screen._selected_instance_id,
		"magicka_avail": int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0)),
		"empower_count": int(player.get("empower_count_this_turn", 0)),
		"invalid_ids": _screen._invalid_feedback.get("instance_ids", []),
		"detached_id": str(_screen._hand._detached_card_state.get("instance_id", "")),
		"active_player": _screen._active_player_id(),
		"hand_public": hand_public,
		"player_id": player_id,
		"hand_sel_candidates": _screen._overlays._hand_selection_state.get("candidate_ids", []),
	}


func _refresh_player_sections() -> void:
	var _us_avatar := 0
	var _us_magicka := 0
	var _us_ring := 0
	var _us_piles := 0
	var _us_support := 0
	var _us_hand := 0
	for player_id in _screen.PLAYER_ORDER:
		var section: Dictionary = _screen._player_sections.get(player_id, {})
		var player = _screen._player_state(player_id)
		if section.is_empty() or player.is_empty():
			continue
		var is_opponent: bool = player_id == _screen.PLAYER_ORDER[0]
		var panel: PanelContainer = section["panel"]
		panel.self_modulate = Color(0.82, 0.84, 0.9, 0.78) if _screen._should_dim_local_surface(player_id) else Color(1, 1, 1, 1)
		var _t := Time.get_ticks_usec()
		var avatar_component = section.get("avatar_component")
		if avatar_component != null:
			var portrait: Texture2D = _screen.get_player_portrait(player_id)
			avatar_component.apply_player_state(player, is_opponent, portrait)
			_screen._feedback._refresh_avatar_target_glow(avatar_component, player_id)
		_us_avatar += Time.get_ticks_usec() - _t

		_t = Time.get_ticks_usec()
		var magicka_component = section.get("magicka_component")
		if magicka_component != null:
			magicka_component.apply_player_state(player)
		_us_magicka += Time.get_ticks_usec() - _t

		_t = Time.get_ticks_usec()
		var ring_panel: PanelContainer = section["ring_panel"]
		ring_panel.visible = bool(player.get("has_ring_of_magicka", false))
		var ring_label: Label = section["ring_label"]
		ring_label.text = _screen._ring_panel_text(player)
		var ring_used_this_turn := bool(player.get("ring_of_magicka_used_this_turn", false))
		if ring_used_this_turn:
			_screen._ui_builder._apply_panel_style(ring_panel, Color(0.14, 0.14, 0.14, 0.96), Color(0.35, 0.35, 0.35, 0.94), 1, 10)
			ring_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
		else:
			_screen._ui_builder._apply_panel_style(ring_panel, Color(0.18, 0.14, 0.08, 0.96), Color(0.63, 0.53, 0.26, 0.94), 1, 10)
			ring_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78, 1.0))
		var ring_row: HBoxContainer = section["ring_row"]
		_refresh_ring_row(ring_row, player)
		_us_ring += Time.get_ticks_usec() - _t

		_t = Time.get_ticks_usec()
		var deck_button: Button = section["deck_button"]
		deck_button.text = _screen._pile_button_text("Deck", player.get("deck", []).size())
		deck_button.tooltip_text = _screen._pile_button_tooltip(player, _screen.MatchMutations.ZONE_DECK)

		var discard_button: Button = section["discard_button"]
		discard_button.text = _screen._pile_button_text("Discard", player.get("discard", []).size())
		discard_button.tooltip_text = _screen._pile_button_tooltip(player, _screen.MatchMutations.ZONE_DISCARD)
		_us_piles += Time.get_ticks_usec() - _t

		_t = Time.get_ticks_usec()
		var support_row: HBoxContainer = section["support_row"]
		var supports: Array = player.get("support", [])
		var support_hash := _compute_support_row_hash(player_id, supports)
		if section.get("support_hash", null) == support_hash and (support_row.get_child_count() > 0 or supports.is_empty()):
			for child in support_row.get_children():
				if child is Button:
					var iid := str(child.get_meta("instance_id", ""))
					if not iid.is_empty():
						_screen._card_buttons[iid] = child
		else:
			section["support_hash"] = support_hash
			_screen._clear_children(support_row)
			for support_card in supports:
				support_row.add_child(_screen._card_surface._build_card_button(support_card, true, "support"))
		_us_support += Time.get_ticks_usec() - _t

		_t = Time.get_ticks_usec()
		var hand_row: Control = section["hand_row"]
		var hand_public = _screen._is_hand_public(player_id)
		var hand_hash := _compute_hand_section_hash(player_id, player, hand_public)
		if section.get("hand_hash", null) == hand_hash and hand_row.get_child_count() > 0:
			# Inputs unchanged — keep the existing buttons but re-register them so
			# downstream code (targeting, hover, animation) can find them.
			for child in hand_row.get_children():
				if child is Button:
					var iid := str(child.get_meta("instance_id", ""))
					if not iid.is_empty():
						_screen._card_buttons[iid] = child
		else:
			section["hand_hash"] = hand_hash
			_screen._clear_children(hand_row)
			for card in player.get("hand", []):
				var card_iid := str(card.get("instance_id", ""))
				if _screen._overlays._has_active_prophecy_overlay(card_iid):
					continue
				if card_iid in _screen._draw_animating_ids:
					continue
				hand_row.add_child(_screen._card_surface._build_card_button(card, hand_public, "hand"))
			if hand_row.get_child_count() == 0:
				var placeholder = _screen._card_surface._build_placeholder_label("Hand empty")
				hand_row.add_child(placeholder)
				_screen._card_surface._layout_hand_placeholder(hand_row, placeholder)
			else:
				_screen._card_surface._layout_hand_cards(hand_row, player_id)
		_us_hand += Time.get_ticks_usec() - _t
	print("[REFRESH] sections breakdown: avatar=%dus magicka=%dus ring=%dus piles=%dus support=%dus hand=%dus" % [_us_avatar, _us_magicka, _us_ring, _us_piles, _us_support, _us_hand])


func _refresh_lanes() -> void:
	var _us_panel := 0
	var _us_header := 0
	var _us_icon := 0
	var _us_row_style := 0
	var _us_row_clear := 0
	var _us_row_build := 0
	_screen._feedback._kill_active_float_tweens()
	_screen._selection._clear_hand_insertion_preview(false)
	# Reset sacrifice hover since lane buttons are being rebuilt
	_screen._betray._sacrifice_hover_target_id = ""
	if _screen._betray._sacrifice_hover_label != null and is_instance_valid(_screen._betray._sacrifice_hover_label):
		_screen._betray._sacrifice_hover_label.queue_free()
	_screen._betray._sacrifice_hover_label = null
	for lane in _screen._lane_entries():
		var lane_id := str(lane.get("id", ""))
		var _t := Time.get_ticks_usec()
		var lane_panel: PanelContainer = _screen._lane_panels.get(lane_id)
		_screen._ui_builder._apply_lane_panel_style(lane_panel, lane_id)
		var capacity = _screen._lane_slot_capacity(lane_id)
		if capacity > 0 and lane_panel != null:
			lane_panel.size_flags_stretch_ratio = float(capacity)
		_us_panel += Time.get_ticks_usec() - _t
		_t = Time.get_ticks_usec()
		var header: Button = _screen._lane_header_buttons.get(lane_id)
		if header != null:
			header.text = _screen._lane_header_text(lane_id)
			header.tooltip_text = _screen._lane_description(lane_id)
			_screen._ui_builder._apply_lane_header_style(header, lane_id)
		_us_header += Time.get_ticks_usec() - _t
		_t = Time.get_ticks_usec()
		var icon_tex: TextureRect = _screen._lane_icon_textures.get(lane_id)
		if icon_tex != null:
			var icon_path := str(lane.get("icon", ""))
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				icon_tex.texture = load(icon_path)
			else:
				icon_tex.texture = null
		_us_icon += Time.get_ticks_usec() - _t
		for player_id in _screen.PLAYER_ORDER:
			_t = Time.get_ticks_usec()
			var row_panel: PanelContainer = _screen._lane_row_panels.get(_screen._lane_row_key(lane_id, player_id))
			_screen._ui_builder._apply_lane_row_panel_style(row_panel, lane_id, player_id)
			_us_row_style += Time.get_ticks_usec() - _t
			var row: HBoxContainer = _screen._lane_row_containers.get(_screen._lane_row_key(lane_id, player_id))
			if row == null:
				continue
			var slots = _screen._lane_slots(lane_id, player_id)
			var row_hash := _compute_lane_row_hash(lane_id, player_id, slots)
			var prior_hash = _lane_row_hashes.get(_screen._lane_row_key(lane_id, player_id), null)
			if prior_hash != null and prior_hash == row_hash and row.get_child_count() > 0:
				# Inputs unchanged — keep buttons but re-register them.
				for child in row.get_children():
					if child is Button:
						var iid := str(child.get_meta("instance_id", ""))
						if not iid.is_empty():
							_screen._card_buttons[iid] = child
			else:
				_lane_row_hashes[_screen._lane_row_key(lane_id, player_id)] = row_hash
				_t = Time.get_ticks_usec()
				_screen._clear_children(row)
				_us_row_clear += Time.get_ticks_usec() - _t
				_t = Time.get_ticks_usec()
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						row.add_child(_screen._card_surface._build_card_button(card, true, "lane"))
				_us_row_build += Time.get_ticks_usec() - _t
	print("[REFRESH] lanes breakdown: panel=%dus header=%dus icon=%dus row_style=%dus row_clear=%dus row_build=%dus" % [_us_panel, _us_header, _us_icon, _us_row_style, _us_row_clear, _us_row_build])


func _refresh_end_turn_button() -> void:
	var has_pending_prophecy = _screen.MatchTiming.has_pending_prophecy(_screen._match_state)
	var local_turn = _screen._is_local_player_turn()
	var match_complete = _screen._has_match_winner()
	_screen._end_turn_button.disabled = match_complete or not local_turn or has_pending_prophecy
	_refresh_end_turn_button_style(has_pending_prophecy)
	if match_complete:
		_screen._end_turn_button.tooltip_text = "Match complete. No further turn actions are available."


func _refresh_turn_presentation() -> void:
	var active_player = _screen._active_player_id()
	if active_player.is_empty():
		return
	if active_player != _screen._last_turn_owner_id and not _screen._local_player_has_pending_interrupt():
		_screen._last_turn_owner_id = active_player
		_screen._animations._floating_card_ids.clear()
		_screen._turn_banner_until_ms = Time.get_ticks_msec() + _screen.TURN_BANNER_DURATION_MS
		if active_player == _screen._ai_system._ai_player_id() and _screen._ai_system._is_local_match_ai_enabled():
			_screen._ai_system._arm_local_match_ai_turn_pacing()
		else:
			_screen._ai_system._reset_local_match_ai_queue()
	if _screen._turn_banner_panel != null:
		_screen._ui_builder._apply_panel_style(_screen._turn_banner_panel, _screen._turn_state_fill(), _screen._turn_state_border(), 2, 14)
		_screen._turn_banner_panel.visible = _screen._turn_banner_until_ms > Time.get_ticks_msec()
	if _screen._turn_banner_label != null:
		_screen._turn_banner_label.text = _screen._turn_state_text()
		_screen._turn_banner_label.add_theme_color_override("font_color", _screen._turn_state_font_color())
	if _screen._turn_banner_detail_label != null:
		var detail_text = _screen._player_name(active_player)
		var local_player = _screen._player_state(_screen._local_player_id())
		if local_player.has("wax_wane_state"):
			var ww_phase := str(local_player.get("wax_wane_state", "wax"))
			var ww_icon := "Waxing" if ww_phase == "wax" else "Waning"
			detail_text += "  |  Moon: %s" % ww_icon
		_screen._turn_banner_detail_label.text = detail_text
		_screen._turn_banner_detail_label.add_theme_color_override("font_color", _screen._turn_state_font_color().lerp(Color(0.8, 0.84, 0.92, 0.96), 0.32))


func _refresh_match_end_overlay() -> void:
	if _screen._match_end_overlay == null:
		return
	var winner_player_id = _screen._match_winner_id()
	var visible: bool = not winner_player_id.is_empty()
	_screen._match_end_overlay.visible = visible
	if not visible:
		return
	var local_won: bool = winner_player_id == _screen._local_player_id()
	# Mark puzzle as solved on first win detection
	if _screen._puzzle_mode and local_won and not _screen._puzzle_id.is_empty():
		const PuzzlePersistence = preload("res://src/puzzle/puzzle_persistence.gd")
		if not PuzzlePersistence.is_solved(_screen._puzzle_id):
			PuzzlePersistence.mark_solved(_screen._puzzle_id)
		if not PuzzlePersistence.is_pack_solved(_screen._puzzle_id):
			PuzzlePersistence.mark_pack_solved(_screen._puzzle_id)
	_screen._ui_builder._apply_panel_style(_screen._match_end_overlay, Color(0.04, 0.05, 0.07, 0.78), Color(0.88, 0.74, 0.44, 0.96) if local_won else Color(0.9, 0.42, 0.42, 0.96), 2, 18)
	if _screen._match_end_title_label != null:
		if _screen._puzzle_mode:
			_screen._match_end_title_label.text = "Puzzle Complete!" if local_won else "Puzzle Failed"
			_screen._match_end_title_label.add_theme_font_size_override("font_size", 56)
		else:
			_screen._match_end_title_label.text = "Victory" if local_won else "Defeat"
		_screen._match_end_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84, 1.0) if local_won else Color(1.0, 0.9, 0.9, 1.0))
	if _screen._match_end_detail_label != null:
		if _screen._puzzle_mode:
			_screen._match_end_detail_label.text = _screen._match_state.get("puzzle_name", "") if local_won else "Try again!"
			_screen._match_end_detail_label.add_theme_font_size_override("font_size", 24)
			_screen._match_end_detail_label.custom_minimum_size = Vector2(540, 0)
		else:
			_screen._match_end_detail_label.text = _screen._match_end_detail_text(winner_player_id)
		_screen._match_end_detail_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.99, 0.96))
	if _screen._puzzle_mode and _screen._match_end_box != null:
		var margin_node: Node = _screen._match_end_box.get_parent()
		if margin_node != null:
			var card_panel: Node = margin_node.get_parent()
			if card_panel is PanelContainer:
				(card_panel as PanelContainer).custom_minimum_size = Vector2(640, 360)
	if _screen._match_end_button != null:
		if _screen._puzzle_mode:
			_screen._match_end_button.visible = false
			_ensure_puzzle_end_buttons(local_won)
		else:
			_screen._match_end_button.text = "Continue" if _screen._arena_mode else "Return to Main Menu"


func _ensure_puzzle_end_buttons(local_won: bool) -> void:
	if _screen._match_end_box == null:
		return
	var is_builder_test = _screen._puzzle_id.is_empty()
	if _screen._puzzle_end_retry_btn == null:
		_screen._puzzle_end_retry_btn = Button.new()
		_screen._puzzle_end_retry_btn.name = "PuzzleRetryButton"
		_screen._puzzle_end_retry_btn.text = "Retry"
		_screen._puzzle_end_retry_btn.custom_minimum_size = Vector2(420, 64)
		_screen._puzzle_end_retry_btn.add_theme_font_size_override("font_size", 24)
		_screen._puzzle_end_retry_btn.pressed.connect(func(): _screen.puzzle_retry_requested.emit())
		_screen._match_end_box.add_child(_screen._puzzle_end_retry_btn)
	if _screen._puzzle_end_next_btn == null:
		_screen._puzzle_end_next_btn = Button.new()
		_screen._puzzle_end_next_btn.name = "PuzzleNextButton"
		_screen._puzzle_end_next_btn.text = "Next Puzzle"
		_screen._puzzle_end_next_btn.custom_minimum_size = Vector2(420, 64)
		_screen._puzzle_end_next_btn.add_theme_font_size_override("font_size", 24)
		_screen._puzzle_end_next_btn.pressed.connect(func(): _screen.puzzle_next_requested.emit())
		_screen._match_end_box.add_child(_screen._puzzle_end_next_btn)
	if _screen._puzzle_end_return_btn == null:
		_screen._puzzle_end_return_btn = Button.new()
		_screen._puzzle_end_return_btn.name = "PuzzleReturnButton"
		_screen._puzzle_end_return_btn.text = "Return to Puzzle Editor" if is_builder_test else "Return to Puzzles"
		_screen._puzzle_end_return_btn.custom_minimum_size = Vector2(420, 64)
		_screen._puzzle_end_return_btn.add_theme_font_size_override("font_size", 24)
		_screen._puzzle_end_return_btn.pressed.connect(func(): _screen.puzzle_return_to_select_requested.emit())
		_screen._match_end_box.add_child(_screen._puzzle_end_return_btn)
	_screen._puzzle_end_retry_btn.visible = not local_won
	_screen._puzzle_end_next_btn.visible = local_won and _screen._puzzle_has_next


func _refresh_end_turn_button_style(has_pending_prophecy: bool) -> void:
	var fill := Color(0.18, 0.15, 0.16, 0.96)
	var border := Color(0.39, 0.36, 0.4, 0.88)
	var font_color := Color(0.82, 0.84, 0.88, 0.96)
	var border_width := 1
	var font_size := 17
	_screen._end_turn_button.text = "End Turn"
	_screen._end_turn_button.custom_minimum_size = Vector2(140, 54)
	_screen._end_turn_button.self_modulate = Color(0.92, 0.92, 0.96, 0.95)
	if _screen._has_match_winner():
		_screen._end_turn_button.tooltip_text = "Match complete. No further turn actions are available."
	elif _screen._is_local_player_turn() and not has_pending_prophecy:
		fill = Color(0.56, 0.2, 0.08, 0.99)
		border = Color(1.0, 0.76, 0.43, 1.0)
		font_color = Color(1.0, 0.97, 0.92, 1.0)
		border_width = 2
		font_size = 18
		_screen._end_turn_button.custom_minimum_size = Vector2(140, 62)
		_screen._end_turn_button.tooltip_text = "Your turn is live. End the turn when you are finished acting."
		_screen._end_turn_button.self_modulate = Color(1, 1, 1, 1)
	elif has_pending_prophecy and _screen._is_local_player_turn():
		_screen._end_turn_button.tooltip_text = "Resolve the open Prophecy window before ending the turn."
	else:
		_screen._end_turn_button.tooltip_text = "Unavailable while the opponent is taking their turn."
	_screen._end_turn_button.add_theme_font_size_override("font_size", font_size)
	_screen._ui_builder._apply_button_style(_screen._end_turn_button, fill, border, font_color, border_width, 12)


func _refresh_rune_row(rune_row: HBoxContainer, player: Dictionary, player_id: String, is_opponent: bool) -> void:
	_screen._clear_children(rune_row)
	var remaining_runes: Array = player.get("rune_thresholds", [])
	var display_thresholds: Array = player.get("_initial_rune_thresholds", _screen.DISPLAY_RUNE_THRESHOLDS)
	for threshold in display_thresholds:
		rune_row.add_child(_build_rune_token(player_id, int(threshold), remaining_runes.has(threshold), is_opponent))


func _build_rune_token(player_id: String, threshold: int, active: bool, is_opponent: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "%s_rune_%d" % [player_id, threshold]
	panel.custom_minimum_size = Vector2(42, 28)
	var fill := Color(0.48, 0.18, 0.14, 0.98) if active else Color(0.12, 0.12, 0.14, 0.94)
	var border := Color(0.89, 0.69, 0.39, 0.96) if active else Color(0.31, 0.32, 0.37, 0.88)
	if is_opponent and active:
		fill = Color(0.45, 0.16, 0.13, 0.98)
	_screen._ui_builder._apply_panel_style(panel, fill, border, 1, 8)
	var box = _screen._ui_builder._build_panel_box(panel, 0, 4)
	var label := Label.new()
	label.text = str(threshold)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84, 0.98) if active else Color(0.62, 0.64, 0.7, 0.8))
	box.add_child(label)
	return panel


func _refresh_ring_row(ring_row: HBoxContainer, player: Dictionary) -> void:
	_screen._clear_children(ring_row)
	var charges := maxi(0, mini(3, int(player.get("ring_of_magicka_charges", 0))))
	for index in range(3):
		ring_row.add_child(_build_ring_token(index, index < charges))


func _build_ring_token(index: int, active: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "ring_%d" % index
	panel.custom_minimum_size = Vector2(18, 18)
	_screen._ui_builder._apply_panel_style(panel, Color(0.7, 0.57, 0.24, 0.98) if active else Color(0.12, 0.12, 0.14, 0.94), Color(0.96, 0.87, 0.58, 0.98) if active else Color(0.31, 0.3, 0.28, 0.86), 1, 9)
	return panel
