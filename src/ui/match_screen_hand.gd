class_name MatchScreenHand
extends RefCounted

var _screen  # MatchScreen reference
var _detached_card_state := {}
var _insertion_preview := {}

func _init(screen) -> void:
	_screen = screen


func _detach_hand_card(instance_id: String) -> void:
	_cancel_detached_card_silent()
	select_card(instance_id)
	var button: Button = _card_buttons.get(instance_id)
	if button != null:
		button.visible = false
	var card := _card_from_instance_id(instance_id)
	var preview_size := _hand_card_display_size()
	var base_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "detached_hand_card_%s" % instance_id
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 500
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	wrapper.add_child(component)
	add_child(wrapper)
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	var mouse_pos := get_viewport().get_mouse_position()
	wrapper.position = mouse_pos + Vector2(-preview_size.x * 0.5, -preview_size.y * 0.62)
	_detached_card_state = {
		"instance_id": instance_id,
		"preview": wrapper,
		"card_data": card.duplicate(true),
	}


func _is_local_hand_card(instance_id: String) -> bool:
	var location := MatchMutations.find_card_location(_match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return false
	return str(location.get("zone", "")) == MatchMutations.ZONE_HAND and str(location.get("player_id", "")) == PLAYER_ORDER[1]


func _try_resolve_detached_card_via_lane(target_instance_id: String) -> void:
	var target_location := MatchMutations.find_card_location(_match_state, target_instance_id)
	if not bool(target_location.get("is_valid", false)) or str(target_location.get("zone", "")) != MatchMutations.ZONE_LANE:
		return
	var selected_card := _selected_card()
	if not _selected_support_row_target_player_id(selected_card).is_empty():
		_play_selected_to_support_row(_selected_support_row_target_player_id(selected_card))
		return
	var lane_id := str(target_location.get("lane_id", ""))
	var target_player := _target_lane_player_id()
	if _selected_card_wants_lane(selected_card, target_player):
		if _selected_action_mode(selected_card) == SELECTION_MODE_ACTION:
			_targeting._play_action_to_lane(lane_id)
			return
		var slot_index := _get_insertion_index_or_default(lane_id, target_player)
		if slot_index >= 0:
			var validation := _validate_selected_lane_play(lane_id, target_player, slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})


func _try_resolve_selected_support_row_card(target_card: Dictionary) -> bool:
	if _selected_support_row_target_player_id(_selected_card()).is_empty() or target_card.is_empty():
		return false
	var target_location := MatchMutations.find_card_location(_match_state, str(target_card.get("instance_id", "")))
	if not bool(target_location.get("is_valid", false)) or str(target_location.get("zone", "")) != MatchMutations.ZONE_SUPPORT:
		return false
	_play_selected_to_support_row(str(target_card.get("controller_player_id", "")))
	return true


func _play_selected_to_support_row(player_id: String) -> Dictionary:
	var card := _selected_card()
	var validation := _validate_selected_support_play(player_id)
	if not bool(validation.get("is_valid", false)):
		return _report_invalid_interaction(str(validation.get("errors", [validation.get("message", "Cannot place this support there.")])[0]))
	var result := {}
	if _overlays._is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id)
		return _finalize_engine_result(result, "Played %s into %s's support row." % [_card_name(card), _player_name(player_id)])
	result = PersistentCardRules.play_support_from_hand(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id)
	return _finalize_engine_result(result, "Placed %s into %s's support row." % [_card_name(card), _player_name(player_id)])


func _cancel_detached_card() -> void:
	_clear_insertion_preview()
	_betray._clear_sacrifice_hover()
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}
	_selected_instance_id = ""
	_refresh_ui()


func _cancel_detached_card_silent() -> void:
	_clear_insertion_preview()
	_betray._clear_sacrifice_hover()
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}


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
		_clear_insertion_preview(false)
	var spacer := Control.new()
	spacer.name = "insertion_spacer"
	spacer.set_meta("is_insertion_spacer", true)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 0)
	row.add_child(spacer)
	row.move_child(spacer, index)
	var target_width: float = CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE.x
	var tween := create_tween()
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
	return _first_open_slot_index(lane_id, player_id)


func _first_valid_lane_slot_index(lane_id: String, player_id: String) -> int:
	for slot_index in range(_lane_slots(lane_id, player_id).size()):
		if bool(_validate_selected_lane_play(lane_id, player_id, slot_index).get("is_valid", false)):
			return slot_index
	return -1

