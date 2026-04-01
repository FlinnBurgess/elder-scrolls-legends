class_name MatchScreenSelection
extends RefCounted

var _screen  # MatchScreen reference


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


func _selected_card() -> Dictionary:
	return _screen._card_from_instance_id(_screen._selected_instance_id)


func _selected_action_mode(card: Dictionary) -> String:
	if card.is_empty():
		return _screen.SELECTION_MODE_NONE
	if _screen.MatchTiming.has_pending_prophecy(_screen._match_state) and not _screen._overlays._is_pending_prophecy_card(card):
		return _screen.SELECTION_MODE_NONE
	if _screen._overlays._is_pending_prophecy_card(card):
		var prophecy_type := str(card.get("card_type", ""))
		if prophecy_type == "creature":
			return _screen.SELECTION_MODE_SUMMON
		if prophecy_type == "item":
			return _screen.SELECTION_MODE_ITEM
		if prophecy_type == "support":
			return _screen.SELECTION_MODE_SUPPORT
		if prophecy_type == "action":
			return _screen.SELECTION_MODE_ACTION
		return _screen.SELECTION_MODE_NONE
	if str(card.get("controller_player_id", "")) != _screen._active_player_id():
		return _screen.SELECTION_MODE_NONE
	var location = _screen.MatchMutations.find_card_location(_screen._match_state, str(card.get("instance_id", "")))
	if not bool(location.get("is_valid", false)):
		return _screen.SELECTION_MODE_NONE
	match str(location.get("zone", "")):
		_screen.MatchMutations.ZONE_HAND:
			match str(card.get("card_type", "")):
				"creature":
					return _screen.SELECTION_MODE_SUMMON
				"item":
					return _screen.SELECTION_MODE_ITEM
				"support":
					return _screen.SELECTION_MODE_SUPPORT
				"action":
					return _screen.SELECTION_MODE_ACTION
		_screen.MatchMutations.ZONE_SUPPORT:
			return _screen.SELECTION_MODE_SUPPORT
		_screen.MatchMutations.ZONE_LANE:
			if _screen._card_display._lane_readiness_badge_text(card) == "READY":
				return _screen.SELECTION_MODE_ATTACK
	return _screen.SELECTION_MODE_NONE


func _try_resolve_selected_card_target(target_instance_id: String) -> bool:
	var selected_card := _selected_card()
	var target_card = _screen._card_from_instance_id(target_instance_id)
	if selected_card.is_empty() or target_card.is_empty():
		return false
	if not _selected_action_consumes_card_click(target_card):
		return false
	if _is_card_target_valid_for_selected(target_instance_id):
		_screen._reset_invalid_feedback()
		_screen._targeting.target_selected_card(target_instance_id)
	else:
		_screen._report_invalid_interaction("%s can't target %s right now." % [_screen._card_display._card_name(selected_card), _screen._card_display._card_name(target_card)], {"instance_ids": [target_instance_id]})
	return true


func _try_resolve_selected_player_target(player_id: String) -> bool:
	var selected_card := _selected_card()
	if selected_card.is_empty():
		return false
	var mode := _selected_action_mode(selected_card)
	if mode == _screen.SELECTION_MODE_SUMMON:
		_screen._report_invalid_interaction("Select a lane slot to summon this creature.", {"player_ids": [player_id]})
		return true
	if mode == _screen.SELECTION_MODE_ACTION and not _screen._targeting._targeting_arrow_state.is_empty():
		var atm := str(selected_card.get("action_target_mode", ""))
		if not atm.is_empty() and atm.find("player") == -1:
			_screen._report_invalid_interaction("%s can only target creatures." % _screen._card_display._card_name(selected_card), {"player_ids": [player_id]})
			return true
		var saved_action_id = _screen._selected_instance_id
		var saved_action_card := selected_card.duplicate(true)
		var action_state: Dictionary = _screen._match_state.duplicate(true)
		var controller_id := str(selected_card.get("controller_player_id", ""))
		var validation: Dictionary
		_screen.GameLogger.suppress()
		if _screen._overlays._is_pending_prophecy_card(selected_card):
			validation = _screen.MatchTiming.play_pending_prophecy(action_state, controller_id, _screen._selected_instance_id, {"target_player_id": player_id})
		else:
			validation = _screen.MatchTiming.play_action_from_hand(action_state, controller_id, _screen._selected_instance_id, {"target_player_id": player_id})
		_screen.GameLogger.unsuppress()
		if bool(validation.get("is_valid", false)):
			_screen._reset_invalid_feedback()
			if _screen._overlays._check_exalt_action(selected_card, {"target_player_id": player_id}, _screen._overlays._is_pending_prophecy_card(selected_card)):
				return true
			var result: Dictionary
			if _screen._overlays._is_pending_prophecy_card(selected_card):
				result = _screen.MatchTiming.play_pending_prophecy(_screen._match_state, controller_id, _screen._selected_instance_id, {"target_player_id": player_id})
			else:
				result = _screen.MatchTiming.play_action_from_hand(_screen._match_state, _screen._active_player_id(), _screen._selected_instance_id, {"target_player_id": player_id})
			var finalized = _screen._finalize_engine_result(result, "%s targeted %s." % [_screen._card_display._card_name(selected_card), _screen._player_name(player_id)])
			if bool(finalized.get("is_valid", false)):
				_screen._betray._check_betray_mode(saved_action_id, saved_action_card)
		else:
			_screen._report_invalid_interaction("%s can't target %s right now." % [_screen._card_display._card_name(selected_card), _screen._player_name(player_id)], {"player_ids": [player_id]})
		return true
	if mode != _screen.SELECTION_MODE_ATTACK or player_id == _screen._active_player_id():
		return false
	if _is_player_target_valid_for_selected(player_id):
		_screen._reset_invalid_feedback()
		_screen._targeting.attack_selected_player(player_id)
	else:
		_screen._report_invalid_interaction("%s can't attack %s right now." % [_screen._card_display._card_name(selected_card), _screen._player_name(player_id)], {"player_ids": [player_id]})
	return true


func _selected_action_consumes_card_click(target_card: Dictionary) -> bool:
	var selected_card := _selected_card()
	var mode := _selected_action_mode(selected_card)
	if mode == _screen.SELECTION_MODE_NONE:
		return false
	var target_location = _screen.MatchMutations.find_card_location(_screen._match_state, str(target_card.get("instance_id", "")))
	if not bool(target_location.get("is_valid", false)):
		return false
	var target_zone := str(target_location.get("zone", ""))
	match mode:
		_screen.SELECTION_MODE_ITEM:
			return target_zone == _screen.MatchMutations.ZONE_LANE
		_screen.SELECTION_MODE_ACTION:
			return target_zone == _screen.MatchMutations.ZONE_LANE
		_screen.SELECTION_MODE_SUPPORT:
			return _screen._targeting._selected_support_uses_card_targets(selected_card) and target_zone == _screen.MatchMutations.ZONE_LANE
		_screen.SELECTION_MODE_ATTACK:
			if target_zone != _screen.MatchMutations.ZONE_LANE:
				return false
			var is_enemy := str(target_card.get("controller_player_id", "")) != str(selected_card.get("controller_player_id", ""))
			if is_enemy:
				return true
			var atk_cond: Dictionary = selected_card.get("attack_condition", {})
			return bool(atk_cond.get("can_attack_friendly", false))
	return false


func _selected_card_wants_lane(card: Dictionary, player_id: String) -> bool:
	if card.is_empty() or player_id != _screen._target_lane_player_id():
		return false
	var mode := _selected_action_mode(card)
	if mode == _screen.SELECTION_MODE_SUMMON:
		return true
	if mode == _screen.SELECTION_MODE_ACTION and not _screen._hand._detached_card_state.is_empty() and not _screen._targeting._action_needs_explicit_target(card):
		return true
	return false


func _validate_selected_lane_play(lane_id: String, player_id: String, slot_index: int) -> Dictionary:
	var card := _selected_card()
	if not _selected_card_wants_lane(card, player_id):
		return {"is_valid": false, "message": "Select a creature that can be summoned into %s." % _screen._lane_name(lane_id)}
	if _selected_action_mode(card) == _screen.SELECTION_MODE_ACTION:
		var action_state: Dictionary = _screen._match_state.duplicate(true)
		_screen.GameLogger.suppress()
		var action_validation = _screen.MatchTiming.play_action_from_hand(action_state, _screen._active_player_id(), _screen._selected_instance_id, {"lane_id": lane_id})
		_screen.GameLogger.unsuppress()
		return action_validation
	if _screen._overlays._is_pending_prophecy_card(card):
		var prophecy_state: Dictionary = _screen._match_state.duplicate(true)
		_screen.GameLogger.suppress()
		var prophecy_validation = _screen.MatchTiming.play_pending_prophecy(prophecy_state, str(card.get("controller_player_id", "")), _screen._selected_instance_id, {"lane_id": lane_id, "slot_index": slot_index})
		_screen.GameLogger.unsuppress()
		return prophecy_validation
	return _screen.LaneRules.validate_summon_from_hand(_screen._match_state, _screen._active_player_id(), _screen._selected_instance_id, lane_id, {"slot_index": slot_index})


func _is_card_target_valid_for_selected(target_instance_id: String) -> bool:
	var selected_card := _selected_card()
	var mode := _selected_action_mode(selected_card)
	if mode == _screen.SELECTION_MODE_NONE:
		return false
	_screen.GameLogger.suppress()
	var result := _is_card_target_valid_for_selected_inner(selected_card, mode, target_instance_id)
	_screen.GameLogger.unsuppress()
	return result


func _is_card_target_valid_for_selected_inner(selected_card: Dictionary, mode: String, target_instance_id: String) -> bool:
	match mode:
		_screen.SELECTION_MODE_ITEM:
			var item_state: Dictionary = _screen._match_state.duplicate(true)
			return bool(_screen.PersistentCardRules.play_item_from_hand(item_state, str(selected_card.get("controller_player_id", "")), _screen._selected_instance_id, {"target_instance_id": target_instance_id}).get("is_valid", false))
		_screen.SELECTION_MODE_ACTION:
			if not _screen._targeting._action_target_mode_allows(selected_card, target_instance_id):
				return false
			var action_state: Dictionary = _screen._match_state.duplicate(true)
			if _screen._overlays._is_pending_prophecy_card(selected_card):
				return bool(_screen.MatchTiming.play_pending_prophecy(action_state, str(selected_card.get("controller_player_id", "")), _screen._selected_instance_id, {"target_instance_id": target_instance_id}).get("is_valid", false))
			return bool(_screen.MatchTiming.play_action_from_hand(action_state, str(selected_card.get("controller_player_id", "")), _screen._selected_instance_id, {"target_instance_id": target_instance_id}).get("is_valid", false))
		_screen.SELECTION_MODE_SUPPORT:
			if not _screen._targeting._selected_support_uses_card_targets(selected_card):
				return false
			var location = _screen.MatchMutations.find_card_location(_screen._match_state, target_instance_id)
			if not (bool(location.get("is_valid", false)) and str(location.get("zone", "")) == _screen.MatchMutations.ZONE_LANE):
				return false
			# Validate against target_mode if present (e.g. friendly_creature)
			var support_tm = _screen._targeting._get_activate_target_mode(selected_card)
			if not support_tm.is_empty():
				var valid_targets = _screen.MatchTiming.get_valid_targets_for_mode(_screen._match_state, _screen._selected_instance_id, support_tm)
				for vt in valid_targets:
					if str(vt.get("instance_id", "")) == target_instance_id:
						return true
				return false
			return true
		_screen.SELECTION_MODE_ATTACK:
			return bool(_screen.MatchCombat.validate_attack(_screen._match_state, str(selected_card.get("controller_player_id", "")), _screen._selected_instance_id, {"type": "creature", "instance_id": target_instance_id}).get("is_valid", false))
	return false


func _is_player_target_valid_for_selected(player_id: String) -> bool:
	var selected_card := _selected_card()
	if _selected_action_mode(selected_card) != _screen.SELECTION_MODE_ATTACK:
		return false
	return bool(_screen.MatchCombat.validate_attack(_screen._match_state, str(selected_card.get("controller_player_id", "")), _screen._selected_instance_id, {"type": "player", "player_id": player_id}).get("is_valid", false))


func _lane_cards() -> Array:
	var cards: Array = []
	for lane in _screen._lane_entries():
		var lane_id := str(lane.get("id", ""))
		for player_id in _screen.PLAYER_ORDER:
			for card in _screen._lane_slots(lane_id, player_id):
				if typeof(card) == TYPE_DICTIONARY and not card.is_empty():
					cards.append(card)
	return cards


func _valid_lane_slot_keys() -> Array:
	var keys: Array = []
	if _selected_action_mode(_selected_card()) != _screen.SELECTION_MODE_SUMMON:
		return keys
	var player_id = _screen._target_lane_player_id()
	for lane in _screen._lane_entries():
		var lane_id := str(lane.get("id", ""))
		var slots = _screen._lane_slots(lane_id, player_id)
		var slot_capacity = _screen._lane_slot_capacity(lane_id)
		if slots.size() < slot_capacity:
			var append_index: int = slots.size()
			if bool(_validate_selected_lane_play(lane_id, player_id, append_index).get("is_valid", false)):
				keys.append(_screen._lane_slot_key(lane_id, player_id, append_index))
		elif slots.size() >= slot_capacity and slots.size() > 0:
			# Full lane with friendly creatures — sacrifice-to-play is available
			keys.append(_screen._lane_slot_key(lane_id, player_id, slots.size()))
	return keys


func _valid_lane_ids() -> Array:
	var ids: Array = []
	var card := _selected_card()
	if not _selected_support_row_target_player_id(card).is_empty():
		for lane in _screen._lane_entries():
			ids.append(str(lane.get("id", "")))
		return ids
	if _selected_action_mode(card) == _screen.SELECTION_MODE_ACTION and not _screen._hand._detached_card_state.is_empty() and not _screen._targeting._action_needs_explicit_target(card):
		for lane in _screen._lane_entries():
			ids.append(str(lane.get("id", "")))
		return ids
	for slot_key in _valid_lane_slot_keys():
		var lane_id := str(slot_key).split(":")[0]
		if not ids.has(lane_id):
			ids.append(lane_id)
	return ids


func _valid_card_target_ids() -> Array:
	var ids: Array = []
	if not _screen._targeting._pending_summon_target.is_empty():
		var source_id := str(_screen._targeting._pending_summon_target.get("source_instance_id", ""))
		for target_info in _screen.MatchTiming.get_all_valid_targets(_screen._match_state, source_id):
			var tid := str(target_info.get("instance_id", ""))
			if not tid.is_empty():
				ids.append(tid)
		return ids
	var mode := _selected_action_mode(_selected_card())
	if mode != _screen.SELECTION_MODE_ITEM and mode != _screen.SELECTION_MODE_SUPPORT and mode != _screen.SELECTION_MODE_ATTACK:
		return ids
	for card in _lane_cards():
		var instance_id := str(card.get("instance_id", ""))
		if _is_card_target_valid_for_selected(instance_id):
			ids.append(instance_id)
	return ids


func _valid_player_target_ids() -> Array:
	var ids: Array = []
	if not _screen._betray._pending_betray.is_empty() and _screen._betray._pending_betray.has("sacrifice_instance_id"):
		var action_card: Dictionary = _screen._betray._pending_betray.get("action_card", {})
		var atm := str(action_card.get("action_target_mode", ""))
		if atm == "creature_or_player" or atm.is_empty():
			for player in _screen._match_state.get("players", []):
				if typeof(player) == TYPE_DICTIONARY:
					ids.append(str(player.get("player_id", "")))
		return ids
	if not _screen._targeting._pending_summon_target.is_empty():
		var source_id := str(_screen._targeting._pending_summon_target.get("source_instance_id", ""))
		for target_info in _screen.MatchTiming.get_all_valid_targets(_screen._match_state, source_id):
			var pid := str(target_info.get("player_id", ""))
			if not pid.is_empty():
				ids.append(pid)
		return ids
	if _selected_action_mode(_selected_card()) != _screen.SELECTION_MODE_ATTACK:
		return ids
	for player_id in _screen.PLAYER_ORDER:
		if player_id != _screen._active_player_id() and _is_player_target_valid_for_selected(player_id):
			ids.append(player_id)
	return ids


func _card_interaction_state(card: Dictionary, surface: String) -> String:
	var instance_id := str(card.get("instance_id", ""))
	if _screen._copy_array(_screen._invalid_feedback.get("instance_ids", [])).has(instance_id):
		return "invalid"
	if not _screen._betray._pending_betray.is_empty() and surface == "lane":
		if _screen._betray._pending_betray.has("sacrifice_instance_id"):
			# Replay targeting phase — highlight valid replay targets
			var action_card: Dictionary = _screen._betray._pending_betray.get("action_card", {})
			var sacrifice_id := str(_screen._betray._pending_betray.get("sacrifice_instance_id", ""))
			if instance_id != sacrifice_id and _screen.ExtendedMechanicPacks._card_matches_target_mode(str(action_card.get("action_target_mode", "")), card, _screen._active_player_id(), _screen._match_state, action_card):
				return "valid"
			return "invalid"
		else:
			# Sacrifice selection phase — highlight friendly creatures
			if str(card.get("controller_player_id", "")) == _screen._active_player_id() and str(card.get("card_type", "")) == "creature":
				var is_targeted: bool = bool(_screen._betray._pending_betray.get("is_targeted", false))
				if is_targeted:
					var action_card: Dictionary = _screen._betray._pending_betray.get("action_card", {})
					if _screen.ExtendedMechanicPacks.betray_replay_has_valid_target(_screen._match_state, _screen._active_player_id(), action_card, instance_id):
						return "valid_betray"
				else:
					return "valid_betray"
			return "invalid"
	if not _screen._targeting._pending_summon_target.is_empty() and surface == "lane":
		var source_id := str(_screen._targeting._pending_summon_target.get("source_instance_id", ""))
		var valid_targets = _screen.MatchTiming.get_all_valid_targets(_screen._match_state, source_id)
		for t in valid_targets:
			if str(t.get("instance_id", "")) == instance_id:
				return "valid"
		return "invalid"
	var mode := _selected_action_mode(_selected_card())
	if mode == _screen.SELECTION_MODE_ITEM and surface == "lane":
		return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	if mode == _screen.SELECTION_MODE_SUPPORT and surface == "lane" and _screen._targeting._selected_support_uses_card_targets(_selected_card()):
		return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	if mode == _screen.SELECTION_MODE_ATTACK and surface == "lane":
		var selected_card := _selected_card()
		if not selected_card.is_empty() and str(card.get("controller_player_id", "")) != str(selected_card.get("controller_player_id", "")):
			return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	if mode == _screen.SELECTION_MODE_ACTION and surface == "lane" and not _screen._targeting._targeting_arrow_state.is_empty():
		return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	return "default"


func _lane_panel_interaction_state(lane_id: String) -> String:
	if _screen._copy_array(_screen._invalid_feedback.get("lane_ids", [])).has(lane_id):
		return "invalid"
	var card := _selected_card()
	var mode := _selected_action_mode(card)
	var wants_lane: bool = mode == _screen.SELECTION_MODE_SUMMON or (mode == _screen.SELECTION_MODE_ACTION and not _screen._hand._detached_card_state.is_empty() and not _screen._targeting._action_needs_explicit_target(card))
	if not wants_lane:
		return "default"
	return "valid" if _valid_lane_ids().has(lane_id) else "invalid"


func _lane_row_interaction_state(lane_id: String, player_id: String) -> String:
	var card := _selected_card()
	var mode := _selected_action_mode(card)
	var wants_lane: bool = mode == _screen.SELECTION_MODE_SUMMON or (mode == _screen.SELECTION_MODE_ACTION and not _screen._hand._detached_card_state.is_empty() and not _screen._targeting._action_needs_explicit_target(card))
	if not wants_lane:
		return "default"
	if player_id != _screen._target_lane_player_id():
		return "default"
	return "valid" if _valid_lane_ids().has(lane_id) else "invalid"


func _can_resolve_selected_action(card: Dictionary) -> bool:
	if card.is_empty():
		_screen._status_message = "Select a card first."
		return false
	if _screen.MatchTiming.has_pending_prophecy(_screen._match_state) and not _screen._overlays._is_pending_prophecy_card(card):
		_screen._status_message = "Resolve the pending Prophecy before taking other actions."
		return false
	if _screen._overlays._is_pending_prophecy_card(card):
		return true
	var controller_player_id := str(card.get("controller_player_id", ""))
	if controller_player_id != _screen._active_player_id():
		_screen._status_message = "Only the active player's public cards can act right now."
		return false
	return true


func _selected_support_row_target_player_id(card: Dictionary) -> String:
	if card.is_empty() or str(card.get("card_type", "")) != "support":
		return ""
	if _screen._overlays._is_pending_prophecy_card(card):
		return str(card.get("controller_player_id", ""))
	var location = _screen.MatchMutations.find_card_location(_screen._match_state, str(card.get("instance_id", "")))
	if not bool(location.get("is_valid", false)):
		return ""
	return str(card.get("controller_player_id", "")) if str(location.get("zone", "")) == _screen.MatchMutations.ZONE_HAND else ""


func _selected_card_wants_support_row(card: Dictionary, player_id: String) -> bool:
	return not player_id.is_empty() and _selected_support_row_target_player_id(card) == player_id


func _validate_selected_support_play(player_id: String) -> Dictionary:
	var card := _selected_card()
	var target_player_id := _selected_support_row_target_player_id(card)
	if target_player_id.is_empty():
		return {"is_valid": false, "message": "Select a support card from hand to place it here."}
	if not _selected_card_wants_support_row(card, player_id):
		return {"is_valid": false, "message": "%s can only be placed into %s's support row." % [_screen._card_display._card_name(card), _screen._player_name(target_player_id)]}
	_screen.GameLogger.suppress()
	var support_validation: Dictionary
	if _screen._overlays._is_pending_prophecy_card(card):
		var prophecy_state: Dictionary = _screen._match_state.duplicate(true)
		support_validation = _screen.MatchTiming.play_pending_prophecy(prophecy_state, str(card.get("controller_player_id", "")), _screen._selected_instance_id)
	else:
		var support_state: Dictionary = _screen._match_state.duplicate(true)
		support_validation = _screen.PersistentCardRules.play_support_from_hand(support_state, str(card.get("controller_player_id", "")), _screen._selected_instance_id)
	_screen.GameLogger.unsuppress()
	return support_validation


func _enter_prophecy_targeting_mode(instance_id: String) -> void:
	_screen._targeting._cancel_targeting_mode_silent()
	_screen._selected_instance_id = instance_id
	var card = _screen._card_from_instance_id(instance_id)
	# Use the prophecy card wrapper position as arrow origin
	var card_wrapper: Control = _screen._overlays._prophecy_overlay_state.get("card_wrapper")
	var arrow_origin := Vector2.ZERO
	if card_wrapper != null and is_instance_valid(card_wrapper):
		var card_size := card_wrapper.size
		arrow_origin = card_wrapper.global_position + Vector2(card_size.x * 0.5, 0.0)
	else:
		var viewport_size = _screen.get_viewport_rect().size
		arrow_origin = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5)
	_screen._targeting_arrow = _create_targeting_arrow()
	_screen._targeting._targeting_arrow_state = {
		"instance_id": instance_id,
		"origin": arrow_origin,
		"button": null,
	}
	_screen._status_message = "Select a target for %s." % _screen._card_display._card_name(card)
	_screen._refresh_ui()


func _update_hand_insertion_preview_from_mouse(mouse_pos: Vector2) -> void:
	var card := _selected_card()
	if card.is_empty() or _selected_action_mode(card) != _screen.SELECTION_MODE_SUMMON:
		_clear_hand_insertion_preview()
		return
	var target_player = _screen._target_lane_player_id()
	var found_lane := ""
	var found_row: HBoxContainer = null
	for lane in _screen._lane_entries():
		var lane_id := str(lane.get("id", ""))
		var row_key = _screen._lane_row_key(lane_id, target_player)
		var row_panel: PanelContainer = _screen._lane_row_panels.get(row_key)
		if row_panel == null or not is_instance_valid(row_panel):
			continue
		var panel_rect := Rect2(row_panel.global_position, row_panel.size)
		if panel_rect.has_point(mouse_pos):
			var slots = _screen._lane_slots(lane_id, target_player)
			var slot_capacity = _screen._lane_slot_capacity(lane_id)
			if slots.size() < slot_capacity:
				found_lane = lane_id
				found_row = _screen._lane_row_containers.get(row_key)
			break
	if found_lane.is_empty() or found_row == null:
		_clear_hand_insertion_preview()
		return
	var insertion_index := _compute_insertion_index(found_row, mouse_pos.x)
	_screen._hand._set_insertion_preview(found_lane, target_player, insertion_index, found_row)


func _compute_insertion_index(row: HBoxContainer, mouse_global_x: float) -> int:
	var card_children: Array = []
	for child in row.get_children():
		if child.has_meta("is_insertion_spacer"):
			continue
		card_children.append(child)
	for i in range(card_children.size()):
		var child: Control = card_children[i]
		var center_x := child.global_position.x + child.size.x * 0.5
		if mouse_global_x < center_x:
			return i
	return card_children.size()


func _clear_hand_insertion_preview(animate := true) -> void:
	if _screen._hand._insertion_preview.is_empty():
		return
	var spacer: Control = _screen._hand._insertion_preview.get("spacer")
	var tween: Tween = _screen._hand._insertion_preview.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	_screen._hand._insertion_preview = {}
	if spacer == null or not is_instance_valid(spacer):
		return
	if not animate or spacer.get_parent() == null:
		if spacer.get_parent() != null:
			spacer.get_parent().remove_child(spacer)
		spacer.queue_free()
		return
	var out_tween = _screen.create_tween()
	out_tween.tween_property(spacer, "custom_minimum_size:x", 0.0, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	var spacer_ref: WeakRef = weakref(spacer)
	out_tween.finished.connect(_screen._queue_free_weak.bind(spacer_ref))


func _create_targeting_arrow() -> Line2D:
	var arrow := Line2D.new()
	arrow.width = 6.0
	arrow.default_color = Color(1.0, 0.85, 0.2, 0.9)
	arrow.z_index = 500
	arrow.antialiased = true
	_screen.add_child(arrow)
	return arrow


func _enter_targeting_mode(instance_id: String) -> void:
	_screen._targeting._cancel_targeting_mode_silent()
	_screen.select_card(instance_id)
	var button: Button = _screen._card_buttons.get(instance_id)
	var arrow_origin := Vector2.ZERO
	if button != null:
		# Card is now raised because select_card sets _screen._selected_instance_id and _refresh_ui
		# applies the raised state. Set mouse_filter to ignore so the card doesn't intercept clicks.
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_pos := button.global_position
		var card_size: Vector2 = button.get_meta("card_size", button.size)
		arrow_origin = card_pos + Vector2(card_size.x * 0.5, 0.0)
	else:
		# Card has no visible button (e.g. an item just equipped to a creature).
		# Store the host creature's instance_id so _update_targeting_arrow can
		# dynamically track the host button (global_position isn't valid on the
		# same frame buttons are created, so we can't read it here).
		var location = _screen.MatchMutations.find_card_location(_screen._match_state, instance_id)
		if str(location.get("zone", "")) == _screen.MatchMutations.ZONE_ATTACHED_ITEM:
			var host_card: Dictionary = location.get("host_card", {})
			var host_id := str(host_card.get("instance_id", ""))
			if not host_id.is_empty():
				_screen._host_arrow_instance_id = host_id
		if _screen._host_arrow_instance_id.is_empty():
			var viewport_size = _screen.get_viewport_rect().size
			arrow_origin = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5)
	_screen._targeting_arrow = _create_targeting_arrow()
	_screen._targeting._targeting_arrow_state = {
		"instance_id": instance_id,
		"origin": arrow_origin,
		"button": button,
	}


func _cancel_targeting_mode() -> void:
	if _screen._targeting_arrow != null and is_instance_valid(_screen._targeting_arrow):
		_screen._targeting_arrow.queue_free()
	_screen._targeting_arrow = null
	_screen._targeting._targeting_arrow_state = {}
	_screen._selected_instance_id = ""
	_screen._refresh_ui()


func _support_has_choose_lane_and_owner(card: Dictionary) -> bool:
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		if str(trigger.get("family", "")) == "activate" and str(trigger.get("target_mode", "")) == "choose_lane_and_owner":
			return true
	return false


func _show_lane_and_owner_choice(support_instance_id: String) -> void:
	var lanes: Array = _screen._match_state.get("lanes", [])
	var options: Array = []
	for lane in lanes:
		var lane_id := str(lane.get("lane_id", ""))
		var lane_name := str(lane.get("display_name", lane_id)).capitalize()
		var _opp_id = _screen.PLAYER_ORDER[0] if _screen._local_player_id() == _screen.PLAYER_ORDER[1] else _screen.PLAYER_ORDER[1]
		for pid_label in [{"pid": _screen._local_player_id(), "label": "Your side"}, {"pid": _opp_id, "label": "Opponent's side"}]:
			var slots: Array = lane.get("player_slots", {}).get(str(pid_label["pid"]), [])
			if slots.size() < 4:  # Lane not full
				options.append({"label": "%s — %s" % [lane_name, str(pid_label["label"])], "lane_id": lane_id, "player_id": str(pid_label["pid"])})
	if options.is_empty():
		_screen._report_invalid_interaction("No available lanes.")
		return
	# Build a simple choice overlay
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 480
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.07, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	overlay.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Choose where to summon Target:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1.0))
	vbox.add_child(title)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	for opt in options:
		var btn := Button.new()
		btn.text = str(opt["label"])
		btn.custom_minimum_size = Vector2(200, 50)
		_screen._apply_button_style(btn, Color(0.15, 0.16, 0.2, 0.95), Color(0.4, 0.38, 0.5, 0.8), Color.WHITE)
		var captured_lane := str(opt["lane_id"])
		var captured_pid := str(opt["player_id"])
		var captured_sid := support_instance_id
		var captured_overlay := overlay
		btn.pressed.connect(func():
			captured_overlay.queue_free()
			var result = _screen.PersistentCardRules.activate_support(_screen._match_state, _screen._active_player_id(), captured_sid, {"lane_id": captured_lane, "target_player_id": captured_pid})
			_screen._finalize_engine_result(result, "Activated support.")
		)
		hbox.add_child(btn)
	_screen.add_child(overlay)


func _check_pending_forced_play() -> void:
	var local_id = _screen._local_player_id()
	if not _screen.MatchTiming.has_pending_forced_play(_screen._match_state, local_id):
		return
	# Don't interrupt other active interactions
	if not _screen._targeting._pending_summon_target.is_empty() or not _screen._selected_instance_id.is_empty():
		return
	if not _screen._hand._detached_card_state.is_empty() or not _screen._targeting._targeting_arrow_state.is_empty():
		return
	var pending = _screen.MatchTiming.get_pending_forced_play(_screen._match_state, local_id)
	var instance_id := str(pending.get("instance_id", ""))
	var card = _screen._card_from_instance_id(instance_id)
	if card.is_empty():
		_screen.MatchTiming.consume_pending_forced_play(_screen._match_state, local_id)
		return
	# Consume the pending entry and auto-select the card for play
	_screen.MatchTiming.consume_pending_forced_play(_screen._match_state, local_id)
	_screen._selected_instance_id = instance_id
	_screen._status_message = "Choose a lane for %s." % _screen._card_display._card_name(card)
	_screen._refresh_ui()


func _check_pending_turn_trigger_target() -> void:
	var local_id = _screen._local_player_id()
	if not _screen.MatchTiming.has_pending_turn_trigger_target(_screen._match_state, local_id):
		if _screen._pending_end_turn:
			_screen._complete_end_turn(_screen._pending_end_turn_player_id)
		return
	if not _screen._targeting._pending_summon_target.is_empty():
		return
	var pending = _screen.MatchTiming.get_pending_turn_trigger_target(_screen._match_state, local_id)
	var source_id := str(pending.get("source_instance_id", ""))
	var card = _screen._card_from_instance_id(source_id)
	if card.is_empty():
		_screen.MatchTiming.decline_pending_turn_trigger_target(_screen._match_state, local_id)
		_check_pending_turn_trigger_target()  # Check for more
		return
	var target_mode := str(pending.get("target_mode", ""))
	var valid_targets = _screen.MatchTiming.get_valid_targets_for_mode(_screen._match_state, source_id, target_mode, {})
	if valid_targets.is_empty():
		_screen.MatchTiming.decline_pending_turn_trigger_target(_screen._match_state, local_id)
		_check_pending_turn_trigger_target()  # Check for more
		return
	_screen._targeting._pending_summon_target = {
		"source_instance_id": source_id,
		"is_turn_trigger": true,
	}
	_screen._selected_instance_id = source_id
	_enter_targeting_mode(source_id)
	var family := str(pending.get("family", ""))
	if family == "end_of_turn" or family == "expertise":
		_screen._status_message = "%s: Choose a target." % str(card.get("name", "Creature"))
	else:
		var phase_name := "Wax" if family == "wax" else "Wane"
		_screen._status_message = "%s — %s: Choose a target." % [str(card.get("name", "Creature")), phase_name]
	_screen._targeting._show_summon_skip_button()
	_screen._refresh_ui()


# --- Betray choice ---


func _cancel_betray_mode() -> void:
	_screen._betray._pending_betray = {}
	_screen._betray._dismiss_betray_skip_button()
	_screen._targeting._cancel_targeting_mode_silent()
	_screen._status_message = "Betray declined."
	_screen._refresh_ui()


# ── Exalt prompt ──────────────────────────────────────────────────────────────
