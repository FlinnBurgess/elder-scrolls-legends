class_name MatchScreenHand
extends RefCounted

var _screen  # MatchScreen reference
var _detached_card_state := {}
var _insertion_preview := {}
var _drag_state := {}  # {instance_id, start_pos} — set on mouse-down, cleared on release/cancel
var _drag_active := false  # true once drag threshold exceeded — suppresses the Button.pressed click
var _drag_position_offset := Vector2.ZERO  # offset tweened to zero so the card smoothly catches up to cursor
var _drag_offset_tween: Tween = null

const DRAG_THRESHOLD_PX := 8.0


const PRESET_FULL_RECT = Control.PRESET_FULL_RECT
const PRESET_TOP_LEFT = Control.PRESET_TOP_LEFT
const PRESET_TOP_RIGHT = Control.PRESET_TOP_RIGHT
const PRESET_BOTTOM_LEFT = Control.PRESET_BOTTOM_LEFT
const PRESET_BOTTOM_RIGHT = Control.PRESET_BOTTOM_RIGHT
const PRESET_CENTER_TOP = Control.PRESET_CENTER_TOP
const PRESET_CENTER_BOTTOM = Control.PRESET_CENTER_BOTTOM
const PRESET_CENTER = Control.PRESET_CENTER
const SIZE_EXPAND_FILL = Control.SIZE_EXPAND_FILL
const SIZE_SHRINK_CENTER = Control.SIZE_SHRINK_CENTER
const SIZE_SHRINK_END = Control.SIZE_SHRINK_END
const SIZE_FILL = Control.SIZE_FILL

func _init(screen) -> void:
	_screen = screen


func _detach_hand_card(instance_id: String, skip_select := false) -> void:
	_cancel_detached_card_silent()
	if not skip_select:
		_screen.select_card(instance_id)
	var button: Button = _screen._card_buttons.get(instance_id)
	if button != null:
		button.visible = false
	var card = _screen._card_from_instance_id(instance_id)
	var preview_size = _screen._hand_card_display_size()
	var base_size = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "detached_hand_card_%s" % instance_id
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 500
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	wrapper.add_child(component)
	_screen.add_child(wrapper)
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	var mouse_pos = _screen.get_viewport().get_mouse_position()
	wrapper.position = mouse_pos + Vector2(-preview_size.x * 0.5, -preview_size.y * 0.62)
	_detached_card_state = {
		"instance_id": instance_id,
		"preview": wrapper,
		"card_data": card.duplicate(true),
	}


func _is_local_hand_card(instance_id: String) -> bool:
	var location = _screen.MatchMutations.find_card_location(_screen._match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return false
	return str(location.get("zone", "")) == _screen.MatchMutations.ZONE_HAND and str(location.get("player_id", "")) == _screen.PLAYER_ORDER[1]


func _try_resolve_detached_card_via_lane(target_instance_id: String) -> void:
	var target_location = _screen.MatchMutations.find_card_location(_screen._match_state, target_instance_id)
	if not bool(target_location.get("is_valid", false)) or str(target_location.get("zone", "")) != _screen.MatchMutations.ZONE_LANE:
		return
	var selected_card = _screen._selected_card()
	if not _screen._selected_support_row_target_player_id(selected_card).is_empty():
		_play_selected_to_support_row(_screen._selected_support_row_target_player_id(selected_card))
		return
	var lane_id := str(target_location.get("lane_id", ""))
	var target_player = _screen._target_lane_player_id()
	if _screen._selected_card_wants_lane(selected_card, target_player):
		if _screen._selected_action_mode(selected_card) == _screen.SELECTION_MODE_ACTION:
			_screen._targeting._play_action_to_lane(lane_id)
			return
		var slot_index := _get_insertion_index_or_default(lane_id, target_player)
		if slot_index >= 0:
			var validation = _screen._validate_selected_lane_play(lane_id, target_player, slot_index)
			if bool(validation.get("is_valid", false)):
				_screen.play_selected_to_lane(lane_id, slot_index)
			else:
				_screen._report_invalid_interaction(validation.get("message", "Cannot play into %s." % _screen._lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})


func _try_resolve_selected_support_row_card(target_card: Dictionary) -> bool:
	var selected: Dictionary = _screen._selected_card()
	if _screen._selected_support_row_target_player_id(selected).is_empty() or target_card.is_empty():
		return false
	var target_location = _screen.MatchMutations.find_card_location(_screen._match_state, str(target_card.get("instance_id", "")))
	if not bool(target_location.get("is_valid", false)) or str(target_location.get("zone", "")) != _screen.MatchMutations.ZONE_SUPPORT:
		return false
	var player_id: String = str(target_card.get("controller_player_id", ""))
	# If support zone is full, sacrifice the clicked support and play the new one
	if _screen.PersistentCardRules.is_support_zone_full(_screen._match_state, player_id):
		var sacrifice_id: String = str(target_card.get("instance_id", ""))
		var sacrifice_name: String = _screen._card_name(target_card)
		var played_name: String = _screen._card_name(selected)
		var result = _screen.PersistentCardRules.play_support_with_sacrifice(_screen._match_state, player_id, _screen._selected_instance_id, sacrifice_id)
		_screen._finalize_engine_result(result, "Sacrificed %s to play %s." % [sacrifice_name, played_name])
		return true
	_play_selected_to_support_row(player_id)
	return true


func _play_selected_to_support_row(player_id: String) -> Dictionary:
	var card = _screen._selected_card()
	var validation = _screen._validate_selected_support_play(player_id)
	if not bool(validation.get("is_valid", false)):
		return _screen._report_invalid_interaction(str(validation.get("errors", [validation.get("message", "Cannot place this support there.")])[0]))
	var result := {}
	if _screen._overlays._is_pending_prophecy_card(card):
		result = _screen.MatchTiming.play_pending_prophecy(_screen._match_state, str(card.get("controller_player_id", "")), _screen._selected_instance_id)
		return _screen._finalize_engine_result(result, "Played %s into %s's support row." % [_screen._card_name(card), _screen._player_name(player_id)])
	result = _screen.PersistentCardRules.play_support_from_hand(_screen._match_state, str(card.get("controller_player_id", "")), _screen._selected_instance_id)
	return _screen._finalize_engine_result(result, "Placed %s into %s's support row." % [_screen._card_name(card), _screen._player_name(player_id)])


func _cancel_detached_card() -> void:
	_screen._selection._clear_hand_insertion_preview()
	_screen._betray._clear_sacrifice_hover()
	_screen._betray._clear_support_sacrifice_hover()
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}
	_clear_drag_offset()
	_screen._selected_instance_id = ""
	_screen._refresh_ui()


func _cancel_detached_card_silent() -> void:
	_screen._selection._clear_hand_insertion_preview()
	_screen._betray._clear_sacrifice_hover()
	_screen._betray._clear_support_sacrifice_hover()
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}
	_clear_drag_offset()


func _set_insertion_preview(lane_id: String, player_id: String, index: int, row: HBoxContainer) -> void:
	if not _insertion_preview.is_empty():
		var same_lane := str(_insertion_preview.get("lane_id", "")) == lane_id and str(_insertion_preview.get("player_id", "")) == player_id
		if same_lane and int(_insertion_preview.get("index", -1)) == index:
			return
		if same_lane:
			var spacer: Control = _insertion_preview.get("spacer")
			if spacer != null and is_instance_valid(spacer) and spacer.get_parent() == row:
				row.move_child(spacer, index)
				_insertion_preview["index"] = index
				return
		_screen._selection._clear_hand_insertion_preview(false)
	var spacer := Control.new()
	spacer.name = "insertion_spacer"
	spacer.set_meta("is_insertion_spacer", true)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 0)
	row.add_child(spacer)
	row.move_child(spacer, index)
	var target_width: float = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE.x
	var tween = _screen.create_tween()
	tween.tween_property(spacer, "custom_minimum_size:x", target_width, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_insertion_preview = {
		"lane_id": lane_id,
		"player_id": player_id,
		"index": index,
		"spacer": spacer,
		"tween": tween,
	}


func _get_insertion_index_or_default(lane_id: String, player_id: String) -> int:
	if not _insertion_preview.is_empty() and str(_insertion_preview.get("lane_id", "")) == lane_id and str(_insertion_preview.get("player_id", "")) == player_id:
		return int(_insertion_preview.get("index", -1))
	return _screen._first_open_slot_index(lane_id, player_id)


func _first_valid_lane_slot_index(lane_id: String, player_id: String) -> int:
	for slot_index in range(_screen._lane_slots(lane_id, player_id).size()):
		if bool(_screen._validate_selected_lane_play(lane_id, player_id, slot_index).get("is_valid", false)):
			return slot_index
	return -1


# --- Drag-and-drop hand card support ---

func _on_hand_card_gui_input(event: InputEvent, instance_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var btn := event as InputEventMouseButton
	if btn.button_index != MOUSE_BUTTON_LEFT or not btn.pressed:
		return
	# Don't start a drag if another interaction mode is active
	if not _detached_card_state.is_empty() or not _screen._targeting._targeting_arrow_state.is_empty():
		return
	if not _screen._targeting._pending_summon_target.is_empty() or not _screen._overlays._pending_exalt.is_empty():
		return
	if not _screen._overlays._hand_selection_state.is_empty() or not _screen._betray._pending_betray.is_empty():
		return
	_drag_state = {"instance_id": instance_id, "start_pos": btn.global_position}
	_drag_active = false


func _handle_drag_release(global_mouse_pos: Vector2) -> bool:
	## Called from _input on left mouse release. Returns true if a drag was resolved.
	if not _drag_active:
		_drag_state = {}
		return false
	_drag_state = {}
	_drag_active = false
	_clear_drag_offset()
	if _detached_card_state.is_empty():
		return false
	_resolve_drag_drop(global_mouse_pos)
	return true


func _clear_drag_offset() -> void:
	_drag_position_offset = Vector2.ZERO
	if _drag_offset_tween != null and _drag_offset_tween.is_valid():
		_drag_offset_tween.kill()
	_drag_offset_tween = null


func _process_drag_motion(mouse_pos: Vector2) -> void:
	if _drag_state.is_empty() or _drag_active:
		return
	var start_pos: Vector2 = _drag_state.get("start_pos", Vector2.ZERO)
	if mouse_pos.distance_to(start_pos) < DRAG_THRESHOLD_PX:
		return
	# Threshold exceeded — begin drag by detaching the card
	var instance_id: String = _drag_state.get("instance_id", "")
	if instance_id.is_empty() or not _is_local_hand_card(instance_id):
		_drag_state = {}
		return
	var card: Dictionary = _screen._card_from_instance_id(instance_id)
	var mode = _screen._selection._selected_action_mode(card)
	# Items and targeted actions enter targeting mode on click, not detach — don't drag them
	if mode == _screen.SELECTION_MODE_ITEM:
		_drag_state = {}
		return
	if mode == _screen.SELECTION_MODE_ACTION and _screen._targeting._action_needs_explicit_target(card):
		_drag_state = {}
		return
	if mode == _screen.SELECTION_MODE_NONE:
		_drag_state = {}
		return
	_drag_active = true
	# Capture the hand card button's screen position before detaching (which hides it)
	var button: Button = _screen._card_buttons.get(instance_id)
	var card_screen_pos := Vector2.ZERO
	if button != null and is_instance_valid(button):
		card_screen_pos = button.global_position
	_detach_hand_card(instance_id)
	# Start the preview at the card's original position and smoothly catch up to the cursor
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		var target_pos: Vector2 = mouse_pos + Vector2(-preview.size.x * 0.5, -preview.size.y * 0.62)
		_drag_position_offset = card_screen_pos - target_pos
		preview.position = target_pos + _drag_position_offset
		if _drag_offset_tween != null and _drag_offset_tween.is_valid():
			_drag_offset_tween.kill()
		_drag_offset_tween = _screen.create_tween()
		_drag_offset_tween.tween_property(self, "_drag_position_offset", Vector2.ZERO, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _resolve_drag_drop(global_mouse_pos: Vector2) -> void:
	# Find what's under the cursor and resolve the detached card play.
	var selected_card: Dictionary = _screen._selected_card()
	var player_id: String = _screen._target_lane_player_id()
	# Check each lane panel (covers both the row and the full lane area)
	var lane_entries: Array = _screen._lane_entries()
	for lane_entry in lane_entries:
		var lane_id := str(lane_entry.get("id", ""))
		var panel: PanelContainer = _screen._lane_panels.get(lane_id)
		if panel == null or not is_instance_valid(panel) or not _control_contains_point(panel, global_mouse_pos):
			continue
		if not _screen._selected_card_wants_lane(selected_card, player_id):
			continue
		if _screen._selection._selected_action_mode(selected_card) == _screen.SELECTION_MODE_ACTION:
			_screen._targeting._play_action_to_lane(lane_id)
			return
		var slot_index := _get_insertion_index_or_default(lane_id, player_id)
		if slot_index >= 0:
			var validation = _screen._validate_selected_lane_play(lane_id, player_id, slot_index)
			if bool(validation.get("is_valid", false)):
				_screen.play_selected_to_lane(lane_id, slot_index)
				return
			else:
				_screen._report_invalid_interaction(validation.get("message", "Cannot play into %s." % _screen._lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})
				return
	# Check support row
	if not _screen._selected_support_row_target_player_id(selected_card).is_empty():
		_play_selected_to_support_row(_screen._selected_support_row_target_player_id(selected_card))
		return
	# Nothing valid under cursor — cancel
	_cancel_detached_card()


func _control_contains_point(ctrl: Control, global_pos: Vector2) -> bool:
	var local_pos := ctrl.get_global_transform().affine_inverse() * global_pos
	return Rect2(Vector2.ZERO, ctrl.size).has_point(local_pos)
