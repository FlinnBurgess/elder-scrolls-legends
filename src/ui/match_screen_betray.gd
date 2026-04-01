class_name MatchScreenBetray
extends RefCounted

var _screen  # MatchScreen reference
var _pending_betray := {}
var _deferred_betray := {}
var _pending_sacrifice_summon := {}
var _sacrifice_hover_target_id: String = ""
var _sacrifice_hover_label: PanelContainer = null

func _init(screen) -> void:
	_screen = screen


func _check_betray_mode(action_instance_id: String, action_card: Dictionary) -> void:
	if not ExtendedMechanicPacks.action_has_betray(_screen._match_state, _active_player_id(), action_card):
		return
	# Defer betray until pending summon effect targets are resolved
	if not _screen._pending_summon_target.is_empty() or MatchTiming.has_pending_summon_effect_target(_screen._match_state, _local_player_id()):
		_deferred_betray = {"action_instance_id": action_instance_id, "action_card": action_card.duplicate(true)}
		return
	# Re-fetch the card from discard to pick up shout upgrades that occurred during resolution
	for _p in _screen._match_state.get("players", []):
		if str(_p.get("player_id", "")) == _active_player_id():
			for discard_card in _p.get("discard", []):
				if typeof(discard_card) == TYPE_DICTIONARY and str(discard_card.get("instance_id", "")) == action_instance_id:
					action_card = discard_card
					break
			break
	var candidates := ExtendedMechanicPacks.get_betray_sacrifice_candidates(_screen._match_state, _active_player_id())
	if candidates.is_empty():
		return
	var is_targeted := not str(action_card.get("action_target_mode", "")).is_empty()
	var is_lane_targeted := _action_has_event_lane_targets(action_card)
	if is_targeted:
		var any_valid := false
		for candidate in candidates:
			if ExtendedMechanicPacks.betray_replay_has_valid_target(_screen._match_state, _active_player_id(), action_card, str(candidate.get("instance_id", ""))):
				any_valid = true
				break
		if not any_valid:
			return
	_pending_betray = {
		"action_instance_id": action_instance_id,
		"action_card": action_card,
		"is_targeted": is_targeted,
		"is_lane_targeted": is_lane_targeted,
	}
	_show_betray_skip_button()
	var card_name := str(action_card.get("name", ""))
	_screen._status_message = "Sacrifice a creature to play %s again." % card_name
	_refresh_ui()


func _check_deferred_betray() -> void:
	if _deferred_betray.is_empty():
		return
	if not _screen._pending_summon_target.is_empty() or MatchTiming.has_pending_summon_effect_target(_screen._match_state, _local_player_id()):
		return
	var deferred := _deferred_betray
	_deferred_betray = {}
	_check_betray_mode(str(deferred.get("action_instance_id", "")), deferred.get("action_card", {}))


func _action_has_event_lane_targets(action_card: Dictionary) -> bool:
	for trigger in action_card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		if str(trigger.get("family", "")) != "on_play":
			continue
		for effect in trigger.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var target_str := str(effect.get("target", ""))
			if target_str.ends_with("_in_event_lane"):
				return true
			if str(effect.get("lane", "")) == "chosen":
				return true
	return false


var _screen._summon_skip_button: Button = null


func _show_betray_skip_button() -> void:
	_dismiss_betray_skip_button()
	var viewport_size := get_viewport_rect().size
	# Prompt label
	_screen._betray_prompt_label = Label.new()
	_screen._betray_prompt_label.text = "Choose a creature to betray"
	_screen._betray_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen._betray_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25, 1.0))
	_screen._betray_prompt_label.add_theme_font_size_override("font_size", 20)
	_screen._betray_prompt_label.z_index = 600
	_screen._betray_prompt_label.size = Vector2(300, 30)
	_screen._betray_prompt_label.position = Vector2(viewport_size.x * 0.5 - 150, viewport_size.y * 0.5 + 10)
	add_child(_screen._betray_prompt_label)
	# Skip button
	_screen._betray_skip_button = Button.new()
	_screen._betray_skip_button.text = "Skip Betray"
	_screen._betray_skip_button.custom_minimum_size = Vector2(160, 50)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.22, 0.28, 0.92)
	style.border_color = Color(0.6, 0.55, 0.65, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_screen._betray_skip_button.add_theme_stylebox_override("normal", style)
	_screen._betray_skip_button.add_theme_stylebox_override("hover", style)
	_screen._betray_skip_button.add_theme_stylebox_override("pressed", style)
	_screen._betray_skip_button.add_theme_color_override("font_color", Color(0.9, 0.88, 0.92, 1.0))
	_screen._betray_skip_button.add_theme_font_size_override("font_size", 18)
	_screen._betray_skip_button.pressed.connect(_cancel_betray_mode)
	_screen._betray_skip_button.z_index = 600
	add_child(_screen._betray_skip_button)
	_screen._betray_skip_button.position = Vector2(viewport_size.x * 0.5 - 80, viewport_size.y * 0.5 + 50)


func _dismiss_betray_skip_button() -> void:
	if _screen._betray_prompt_label != null and is_instance_valid(_screen._betray_prompt_label):
		_screen._betray_prompt_label.queue_free()
	_screen._betray_prompt_label = null
	if _screen._betray_skip_button != null and is_instance_valid(_screen._betray_skip_button):
		_screen._betray_skip_button.queue_free()
	_screen._betray_skip_button = null


func _resolve_betray_sacrifice(sacrifice_instance_id: String) -> void:
	var candidates := ExtendedMechanicPacks.get_betray_sacrifice_candidates(_screen._match_state, _active_player_id())
	var is_valid_candidate := false
	for c in candidates:
		if str(c.get("instance_id", "")) == sacrifice_instance_id:
			is_valid_candidate = true
			break
	if not is_valid_candidate:
		_report_invalid_interaction("Not a valid sacrifice target.", {"instance_ids": [sacrifice_instance_id]})
		return
	var is_targeted: bool = bool(_pending_betray.get("is_targeted", false))
	if is_targeted:
		var action_card: Dictionary = _pending_betray.get("action_card", {})
		if not ExtendedMechanicPacks.betray_replay_has_valid_target(_screen._match_state, _active_player_id(), action_card, sacrifice_instance_id):
			_report_invalid_interaction("No valid replay targets if this creature is sacrificed.", {"instance_ids": [sacrifice_instance_id]})
			return
	_dismiss_betray_skip_button()
	if is_targeted:
		_pending_betray["sacrifice_instance_id"] = sacrifice_instance_id
		# Enter targeting mode for replay, arrow from player avatar
		var avatar: Control = null
		var section: Dictionary = _screen._player_sections.get(_active_player_id(), {})
		if section.has("avatar_component"):
			avatar = section.get("avatar_component") as Control
		_cancel_targeting_mode_silent()
		_screen._targeting_arrow = _create_targeting_arrow()
		var arrow_origin := Vector2.ZERO
		if avatar != null:
			arrow_origin = avatar.global_position + Vector2(avatar.size.x * 0.5, avatar.size.y * 0.5)
		else:
			var viewport_size := get_viewport_rect().size
			arrow_origin = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.85)
		_screen._targeting_arrow_state = {
			"instance_id": str(_pending_betray.get("action_instance_id", "")),
			"origin": arrow_origin,
			"button": null,
		}
		var card_name := str(_pending_betray.get("action_card", {}).get("name", ""))
		_screen._status_message = "Choose a target for %s." % card_name
		_refresh_ui()
	elif bool(_pending_betray.get("is_lane_targeted", false)):
		_pending_betray["sacrifice_instance_id"] = sacrifice_instance_id
		var card_name := str(_pending_betray.get("action_card", {}).get("name", ""))
		_screen._status_message = "Choose a lane for %s." % card_name
		_refresh_ui()
	else:
		var action_instance_id := str(_pending_betray.get("action_instance_id", ""))
		var result := MatchTiming.execute_betray_replay(_screen._match_state, _active_player_id(), action_instance_id, sacrifice_instance_id, {})
		_pending_betray = {}
		_finalize_engine_result(result, "Betray replay resolved.")


func _resolve_betray_replay_target_card(target_instance_id: String) -> void:
	var action_instance_id := str(_pending_betray.get("action_instance_id", ""))
	var sacrifice_id := str(_pending_betray.get("sacrifice_instance_id", ""))
	var replay_options := {"target_instance_id": target_instance_id}
	var result := MatchTiming.execute_betray_replay(_screen._match_state, _active_player_id(), action_instance_id, sacrifice_id, replay_options)
	_pending_betray = {}
	_cancel_targeting_mode_silent()
	_finalize_engine_result(result, "Betray replay resolved.")


func _resolve_betray_replay_target_player(player_id: String) -> void:
	var action_instance_id := str(_pending_betray.get("action_instance_id", ""))
	var sacrifice_id := str(_pending_betray.get("sacrifice_instance_id", ""))
	var replay_options := {"target_player_id": player_id}
	var result := MatchTiming.execute_betray_replay(_screen._match_state, _active_player_id(), action_instance_id, sacrifice_id, replay_options)
	_pending_betray = {}
	_cancel_targeting_mode_silent()
	_finalize_engine_result(result, "Betray replay resolved.")


func _resolve_betray_replay_lane(lane_id: String) -> void:
	var action_instance_id := str(_pending_betray.get("action_instance_id", ""))
	var sacrifice_id := str(_pending_betray.get("sacrifice_instance_id", ""))
	var replay_options := {"lane_id": lane_id}
	var result := MatchTiming.execute_betray_replay(_screen._match_state, _active_player_id(), action_instance_id, sacrifice_id, replay_options)
	_pending_betray = {}
	_finalize_engine_result(result, "Betray replay resolved.")


func _lane_is_full_with_friendly(lane_id: String, player_id: String) -> bool:
	var slots := _lane_slots(lane_id, player_id)
	var slot_capacity := _lane_slot_capacity(lane_id)
	return slots.size() >= slot_capacity and slots.size() > 0


func _find_nearest_friendly_creature_in_lane(lane_id: String, player_id: String, mouse_pos: Vector2) -> String:
	var row_key := _lane_row_key(lane_id, player_id)
	var row: HBoxContainer = _screen._lane_row_containers.get(row_key)
	if row == null or not is_instance_valid(row):
		return ""
	var best_id := ""
	var best_dist := INF
	for child in row.get_children():
		if not (child is Button):
			continue
		if child.has_meta("is_insertion_spacer"):
			continue
		var instance_id: String = child.get_meta("instance_id", "")
		if instance_id.is_empty():
			continue
		var c := _card_from_instance_id(instance_id)
		if c.is_empty():
			continue
		if str(c.get("controller_player_id", "")) != _active_player_id():
			continue
		if str(c.get("card_type", "")) != "creature":
			continue
		var ctrl := child as Control
		var center_x: float = ctrl.global_position.x + ctrl.size.x * 0.5
		var dist: float = absf(mouse_pos.x - center_x)
		if dist < best_dist:
			best_dist = dist
			best_id = instance_id
	return best_id


func _apply_sacrifice_hover(instance_id: String) -> void:
	_sacrifice_hover_target_id = instance_id
	var button: Button = _screen._card_buttons.get(instance_id)
	if button != null and is_instance_valid(button):
		_apply_betray_target_glow(button, "lane")
	var target_card := _card_from_instance_id(instance_id)
	_sacrifice_hover_label = PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	bg_style.set_corner_radius_all(4)
	bg_style.set_content_margin_all(6)
	_sacrifice_hover_label.add_theme_stylebox_override("panel", bg_style)
	_sacrifice_hover_label.z_index = 501
	_sacrifice_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "Sacrifice %s" % _card_name(target_card)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sacrifice_hover_label.add_child(label)
	add_child(_sacrifice_hover_label)
	_update_sacrifice_hover_label_position()


func _update_sacrifice_hover_from_mouse(mouse_pos: Vector2) -> void:
	if _screen._detached_card_state.is_empty():
		_clear_sacrifice_hover()
		return
	var card := _selected_card()
	if card.is_empty() or _selected_action_mode(card) != SELECTION_MODE_SUMMON:
		_clear_sacrifice_hover()
		return
	var target_player := _target_lane_player_id()
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var row_key := _lane_row_key(lane_id, target_player)
		var row_panel: PanelContainer = _screen._lane_row_panels.get(row_key)
		if row_panel == null or not is_instance_valid(row_panel):
			continue
		if not Rect2(row_panel.global_position, row_panel.size).has_point(mouse_pos):
			continue
		if not _lane_is_full_with_friendly(lane_id, target_player):
			_clear_sacrifice_hover()
			return
		var nearest_id := _find_nearest_friendly_creature_in_lane(lane_id, target_player, mouse_pos)
		if nearest_id != "" and nearest_id != _sacrifice_hover_target_id:
			_clear_sacrifice_hover()
			_apply_sacrifice_hover(nearest_id)
		elif nearest_id == "":
			_clear_sacrifice_hover()
		return
	_clear_sacrifice_hover()


func _update_sacrifice_hover_label_position() -> void:
	if _sacrifice_hover_label == null or not is_instance_valid(_sacrifice_hover_label):
		return
	var preview: Control = _screen._detached_card_state.get("preview")
	if preview == null or not is_instance_valid(preview):
		return
	var label_size := _sacrifice_hover_label.size
	_sacrifice_hover_label.position = Vector2(
		preview.position.x + preview.size.x * 0.5 - label_size.x * 0.5,
		preview.position.y + preview.size.y + 4.0
	)


func _clear_sacrifice_hover() -> void:
	if _sacrifice_hover_target_id.is_empty():
		return
	var button: Button = _screen._card_buttons.get(_sacrifice_hover_target_id)
	if button != null and is_instance_valid(button):
		var glow := button.find_child("valid_target_glow", false, false)
		if glow != null:
			glow.queue_free()
	_sacrifice_hover_target_id = ""
	if _sacrifice_hover_label != null and is_instance_valid(_sacrifice_hover_label):
		_sacrifice_hover_label.queue_free()
	_sacrifice_hover_label = null


func _resolve_sacrifice_hover() -> void:
	var sacrifice_id := _sacrifice_hover_target_id
	var detached_id := str(_screen._detached_card_state.get("instance_id", ""))
	var location := MatchMutations.find_card_location(_screen._match_state, sacrifice_id)
	var lane_id := str(location.get("lane_id", ""))
	_clear_sacrifice_hover()
	_cancel_detached_card_silent()
	_pending_sacrifice_summon = {"card_instance_id": detached_id, "lane_id": lane_id}
	_resolve_sacrifice_summon(sacrifice_id)


func _resolve_sacrifice_summon(sacrifice_instance_id: String) -> void:
	var lane_id := str(_pending_sacrifice_summon.get("lane_id", ""))
	var card_instance_id := str(_pending_sacrifice_summon.get("card_instance_id", ""))
	var sacrifice_location := MatchMutations.find_card_location(_screen._match_state, sacrifice_instance_id)
	var sacrifice_card: Dictionary = sacrifice_location.get("card", {})
	if sacrifice_card.is_empty():
		_report_invalid_interaction("Not a valid sacrifice target.", {"instance_ids": [sacrifice_instance_id]})
		return
	if str(sacrifice_card.get("controller_player_id", "")) != _active_player_id():
		_report_invalid_interaction("Not a valid sacrifice target.", {"instance_ids": [sacrifice_instance_id]})
		return
	if str(sacrifice_location.get("lane_id", "")) != lane_id:
		_report_invalid_interaction("Sacrifice target must be in the same lane.", {"instance_ids": [sacrifice_instance_id]})
		return
	var saved_instance_id := card_instance_id
	var summoned_card := _card_from_instance_id(card_instance_id)
	var sacrifice_name := _card_name(sacrifice_card)
	var summoned_name := _card_name(summoned_card)
	var result := LaneRules.summon_with_sacrifice(_screen._match_state, _active_player_id(), card_instance_id, lane_id, sacrifice_instance_id)
	_pending_sacrifice_summon = {}
	var finalized := _finalize_engine_result(result, "Sacrificed %s to play %s." % [sacrifice_name, summoned_name])
	if bool(finalized.get("is_valid", false)):
		_check_summon_target_mode(saved_instance_id)

