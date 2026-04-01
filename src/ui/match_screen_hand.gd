class_name MatchScreenHand
extends RefCounted

var _screen  # MatchScreen reference
var _detached_card_state := {}
var _insertion_preview := {}


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


func _detach_hand_card(instance_id: String) -> void:
	_cancel_detached_card_silent()
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
	if _screen._selected_support_row_target_player_id(_screen._selected_card()).is_empty() or target_card.is_empty():
		return false
	var target_location = _screen.MatchMutations.find_card_location(_screen._match_state, str(target_card.get("instance_id", "")))
	if not bool(target_location.get("is_valid", false)) or str(target_location.get("zone", "")) != _screen.MatchMutations.ZONE_SUPPORT:
		return false
	_play_selected_to_support_row(str(target_card.get("controller_player_id", "")))
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
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}
	_screen._selected_instance_id = ""
	_screen._refresh_ui()


func _cancel_detached_card_silent() -> void:
	_screen._selection._clear_hand_insertion_preview()
	_screen._betray._clear_sacrifice_hover()
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
