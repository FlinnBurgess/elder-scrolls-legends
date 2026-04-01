class_name MatchScreenHover
extends RefCounted

var _screen  # MatchScreen reference
var _lane_hover_preview_pending := {}
var _support_hover_preview_pending := {}

func _init(screen) -> void:
	_screen = screen


func _on_local_hand_card_mouse_entered(button: Button) -> void:
	_hovered_hand_instance_id = str(button.get_meta("instance_id", ""))
	var card := _card_from_instance_id(_hovered_hand_instance_id)
	_error_report_hovered_type = "card"
	_error_report_hovered_context = "%s (in hand)" % str(card.get("name", _hovered_hand_instance_id))
	_apply_local_hand_hover_state(button, true)


func _on_local_hand_card_mouse_exited(button: Button) -> void:
	if _hovered_hand_instance_id == str(button.get_meta("instance_id", "")):
		_hovered_hand_instance_id = ""
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""
	var hand_component = button.get_meta("card_display_component", null)
	if hand_component != null and is_instance_valid(hand_component) and hand_component.has_method("reset_relationship_view"):
		hand_component.reset_relationship_view()
	_apply_local_hand_hover_state(button, false)


func _apply_local_hand_hover_state(button: Button, hovered: bool) -> void:
	if button == null:
		return
	var base_position: Vector2 = button.get_meta("base_position", button.position)
	var hand_index := int(button.get_meta("hand_index", button.z_index))
	var selected := str(button.get_meta("instance_id", "")) == _selected_instance_id
	var locked := bool(button.get_meta("presentation_locked", false))
	var card_size: Vector2 = button.get_meta("card_size", button.size)
	var affordable := bool(button.get_meta("affordable", false))
	var affordable_rise := card_size.y * 0.06 if affordable else 0.0
	# How far the card needs to rise to be fully visible, plus margin from screen bottom.
	# Subtract affordable_rise so all raised cards reach the same absolute Y regardless of
	# their resting offset.
	var bottom_margin := 24.0
	var rise_amount := card_size.y * 0.85 + bottom_margin - affordable_rise
	# Determine target state
	var any_selected := not _selected_instance_id.is_empty()
	var target_position := base_position
	var target_size := card_size
	var target_scale := Vector2.ONE
	var target_z := hand_index
	# Hand selection mode: eligible cards are raised and clickable, ineligible are dimmed
	var hand_selection_active := not _overlays._hand_selection_state.is_empty()
	var hand_selection_eligible := hand_selection_active and (_overlays._hand_selection_state.get("candidate_ids", []) as Array).has(str(button.get_meta("instance_id", "")))
	var hand_selection_ineligible := hand_selection_active and not hand_selection_eligible
	# When any card is selected (placement mode), non-selected hand cards ignore mouse
	# so they don't block clicks on the board/support surface beneath them
	var target_filter := Control.MOUSE_FILTER_IGNORE if (any_selected and not selected) else Control.MOUSE_FILTER_STOP
	if hand_selection_ineligible:
		target_filter = Control.MOUSE_FILTER_IGNORE
	var raised := false
	if hand_selection_eligible:
		target_filter = Control.MOUSE_FILTER_STOP
		target_scale = Vector2(1.05, 1.05)
		target_position = base_position + Vector2(0.0, -rise_amount)
		target_z = 110
		raised = true
	elif not locked and selected:
		target_filter = Control.MOUSE_FILTER_IGNORE
		target_scale = Vector2(1.05, 1.05)
		target_position = base_position + Vector2(0.0, -rise_amount)
		target_z = 110
		raised = true
	if hovered and not hand_selection_active:
		target_filter = Control.MOUSE_FILTER_STOP
		target_scale = Vector2(1.1, 1.1) if selected else Vector2(1.05, 1.05)
		target_position = base_position + Vector2(0.0, -rise_amount - (20.0 if selected else 0.0))
		target_z = 120 if selected else 100
		raised = true
	# When raised, extend button height downward to create an invisible hit zone
	# that prevents hover oscillation when the card moves away from the cursor
	if raised:
		var extend := base_position.y - target_position.y
		target_size = Vector2(card_size.x, card_size.y + extend)
	# Apply non-animated properties immediately
	button.z_index = target_z
	button.mouse_filter = target_filter
	button.scale = target_scale
	button.pivot_offset = card_size * 0.5
	button.size = target_size
	button.modulate = Color(0.4, 0.4, 0.4, 0.7) if hand_selection_ineligible else Color.WHITE
	# Pin content to original card dimensions at the top of the (possibly taller) button
	var content_root: Control = button.get_meta("content_root", null) if button.has_meta("content_root") else null
	if content_root != null:
		content_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		content_root.position = Vector2.ZERO
		content_root.size = card_size
	# Animate position (the rise/fall)
	var tween_key := "hand_hover_tween"
	var existing_tween: Tween = button.get_meta(tween_key, null) if button.has_meta(tween_key) else null
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	var tween := create_tween()
	tween.tween_property(button, "position", target_position, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	button.set_meta(tween_key, tween)
	# Bob animation for affordable cards at rest
	var bob_key := "hand_bob_tween"
	var existing_bob: Tween = button.get_meta(bob_key, null) if button.has_meta(bob_key) else null
	if existing_bob != null and existing_bob.is_valid():
		existing_bob.kill()
	if affordable and not raised:
		var bob_button := button
		var bob_pos := target_position
		var bob_k := bob_key
		tween.finished.connect(func(): _start_hand_card_bob(bob_button, bob_pos, bob_k))


func _process_lane_card_hover_preview() -> void:
	if _lane_hover_preview_button_ref != null:
		var active_button = _lane_hover_preview_button_ref.get_ref() as Button
		if active_button == null or not is_instance_valid(active_button):
			_clear_lane_card_hover_preview()
		elif _lane_hover_preview_instance_id != "":
			_position_lane_card_hover_preview(active_button)
	if _lane_hover_preview_pending.is_empty():
		return
	if Time.get_ticks_msec() - int(_lane_hover_preview_pending.get("entered_at_ms", 0)) < CARD_HOVER_PREVIEW_DELAY_MS:
		return
	var button_ref := _lane_hover_preview_pending.get("button_ref") as WeakRef
	var button := button_ref.get_ref() as Button if button_ref != null else null
	var instance_id := str(_lane_hover_preview_pending.get("instance_id", ""))
	_lane_hover_preview_pending = {}
	if button == null or not is_instance_valid(button):
		return
	var card := _card_from_instance_id(instance_id)
	if card.is_empty() or str(card.get("card_type", "")) != "creature":
		return
	_show_lane_card_hover_preview(button, card, instance_id)


func _clear_lane_card_hover_preview() -> void:
	_lane_hover_preview_pending = {}
	_lane_hover_preview_instance_id = ""
	_lane_hover_preview_button_ref = null
	if _card_hover_preview_layer == null:
		return
	for child in _card_hover_preview_layer.get_children():
		if str(child.name).begins_with("lane_hover_preview_"):
			child.queue_free()


func _position_lane_card_hover_preview(button: Button) -> void:
	if button == null or _card_hover_preview_layer == null:
		return
	var preview := _card_hover_preview_layer.get_node_or_null("lane_hover_preview_%s" % _lane_hover_preview_instance_id) as Control
	if preview == null:
		return
	var preview_size := preview.size
	var layer_origin := _card_hover_preview_layer.get_global_rect().position
	var button_rect := button.get_global_rect()
	var target_position := Vector2(
		button_rect.get_center().x - preview_size.x * 0.5 - layer_origin.x,
		button_rect.get_center().y - preview_size.y * 0.5 - layer_origin.y
	)
	target_position.x = clampf(target_position.x, 0.0, maxf(_card_hover_preview_layer.size.x - preview_size.x, 0.0))
	target_position.y = clampf(target_position.y, 0.0, maxf(_card_hover_preview_layer.size.y - preview_size.y, 0.0))
	preview.position = target_position


func _get_active_hover_preview_component():
	if _card_hover_preview_layer == null:
		return null
	# Check lane hover preview
	if _lane_hover_preview_instance_id != "":
		var preview := _card_hover_preview_layer.get_node_or_null("lane_hover_preview_%s" % _lane_hover_preview_instance_id)
		if preview != null and preview.get_child_count() > 0:
			return preview.get_child(0)
	# Check support hover preview
	if _support_hover_preview_instance_id != "":
		var preview := _card_hover_preview_layer.get_node_or_null("support_hover_preview_%s" % _support_hover_preview_instance_id)
		if preview != null and preview.get_child_count() > 0:
			return preview.get_child(0)
	return null


func _on_support_card_mouse_entered(button: Button, instance_id: String) -> void:
	_clear_support_card_hover_preview()
	_support_hover_preview_pending = {
		"instance_id": instance_id,
		"button_ref": weakref(button),
		"entered_at_ms": Time.get_ticks_msec(),
	}
	var card := _card_from_instance_id(instance_id)
	var side := "player" if str(card.get("controller_player_id", "")) == _local_player_id() else "opponent"
	_error_report_hovered_type = "card"
	_error_report_hovered_context = "%s (support, %s side)" % [str(card.get("name", instance_id)), side]


func _on_support_card_mouse_exited(instance_id: String) -> void:
	if str(_support_hover_preview_pending.get("instance_id", "")) == instance_id:
		_support_hover_preview_pending = {}
	if _support_hover_preview_instance_id == instance_id:
		_clear_support_card_hover_preview()
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""

