class_name MatchScreenAI
extends RefCounted

var _screen  # MatchScreen reference
var _ai_waiting_for_turn_banner := false
var _local_match_ai_action_count := 0
var _ai_enabled := false
var _ai_options: Dictionary = {}

func _init(screen) -> void:
	_screen = screen


func _process_local_match_ai_turn() -> void:
	if not _overlays._mulligan_overlay_state.is_empty():
		return
	if not _overlays._spell_reveal_state.is_empty():
		return
	if not _overlays._deck_reveal_state.is_empty():
		return
	if not _is_local_match_ai_enabled() or _has_match_winner():
		_reset_local_match_ai_queue()
		return
	var ai_has_prophecy := _has_pending_prophecy_for_player(_ai_player_id())
	if _is_local_player_turn() and not ai_has_prophecy:
		_reset_local_match_ai_queue()
		return
	if ai_has_prophecy and _queued_ai_step_at_ms < 0 and _paused_ai_step_delay_ms < 0:
		_schedule_local_match_ai_step(LOCAL_MATCH_AI_ACTION_DELAY_MS * 3)
		return
	var now_ms := Time.get_ticks_msec()
	if _local_player_has_pending_interrupt():
		_pause_local_match_ai_queue(now_ms)
		return
	_resume_local_match_ai_queue(now_ms)
	if not _ai_controls_current_decision_window():
		_reset_local_match_ai_queue()
		return
	if _ai_waiting_for_turn_banner:
		if _is_turn_banner_active():
			return
		_ai_waiting_for_turn_banner = false
	if _queued_ai_step_at_ms > now_ms:
		return
	_queued_ai_step_at_ms = -1
	var step := _execute_local_match_ai_step()
	if not bool(step.get("did_execute", false)):
		if str(step.get("yield_reason", "")) != "waiting_on_local_prophecy":
			_reset_local_match_ai_queue()
		return
	_local_match_ai_action_count += 1
	var yield_reason := str(step.get("yield_reason", ""))
	if yield_reason == "continue" or yield_reason == "waiting_on_local_prophecy":
		var step_action: Dictionary = step.get("action", {})
		var step_delay := LOCAL_MATCH_AI_ACTION_DELAY_MS
		if str(step_action.get("kind", "")) == MatchActionEnumerator.KIND_ATTACK:
			step_delay = LOCAL_MATCH_AI_ATTACK_DELAY_MS
		_schedule_local_match_ai_step(step_delay)
		return
	_reset_local_match_ai_queue()


func _execute_local_match_ai_step() -> Dictionary:
	if not _is_local_match_ai_enabled():
		return {"did_execute": false, "yield_reason": "disabled"}
	if _has_match_winner():
		return {"did_execute": false, "yield_reason": "match_complete"}
	if _local_player_has_pending_interrupt():
		return {"did_execute": false, "yield_reason": "waiting_on_local_prophecy"}
	if not _ai_controls_current_decision_window():
		return {"did_execute": false, "yield_reason": "no_ai_window"}
	var ai_player_id := _ai_player_id()
	var choice := HeuristicMatchPolicy.choose_action(_match_state, ai_player_id, _ai_options)
	if not bool(choice.get("is_valid", false)):
		return {
			"did_execute": false,
			"yield_reason": str(choice.get("reason", "invalid_choice")),
			"choice": choice.duplicate(true),
		}
	var action: Dictionary = choice.get("chosen_action", {}).duplicate(true)
	if action.is_empty():
		return {
			"did_execute": false,
			"yield_reason": "missing_action",
			"choice": choice.duplicate(true),
		}
	var result := MatchActionExecutor.execute_action(_match_state, action)
	if not bool(result.get("is_valid", false)):
		_status_message = str(result.get("errors", ["AI action failed."])[0])
		_refresh_ui()
		return {
			"did_execute": false,
			"yield_reason": "action_failed",
			"choice": choice.duplicate(true),
			"action": action.duplicate(true),
			"result": result.duplicate(true),
		}
	_cancel_detached_card_silent()
	_reset_invalid_feedback()
	_selected_instance_id = ""
	_record_feedback_from_events(_ai_feedback_events(action, result))
	_status_message = _ai_action_status_message(action)
	# Survive puzzle: AI just ended its turn — check if player survived
	if _puzzle_mode and _puzzle_type == "survive" and str(action.get("kind", "")) == MatchActionEnumerator.KIND_END_TURN:
		if str(_match_state.get("winner_player_id", "")).is_empty():
			_match_state["winner_player_id"] = _local_player_id()
			_status_message = "Puzzle Complete!"
			_refresh_ui()
			return {"did_execute": true, "yield_reason": "match_complete", "action": action.duplicate(true), "result": result.duplicate(true)}
	if not _overlays._prophecy_overlay_state.is_empty() and not bool(_overlays._prophecy_overlay_state.get("is_local", true)):
		_animate_enemy_prophecy_resolution(action, result)
	else:
		var is_enemy := str(action.get("kind", "")) != "" and str(action.get("player_id", "")) != _local_player_id()
		if is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_PLAY_ACTION:
			_animate_enemy_spell_reveal(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_SUMMON_CREATURE and _has_summon_target(action):
			_animate_enemy_creature_summon_reveal(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_SUMMON_CREATURE:
			_animate_enemy_creature_play(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_PLAY_ITEM:
			_animate_enemy_item_reveal(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_ATTACK:
			_animate_enemy_attack_arrow(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_ACTIVATE_SUPPORT and _has_support_activation_target(action):
			_animate_enemy_support_activation_arrow(action, result)
		else:
			_refresh_ui()
	if _arena_mode:
		match_state_changed.emit(_match_state.duplicate(true))
	return {
		"did_execute": true,
		"yield_reason": _ai_post_action_state(),
		"choice": choice.duplicate(true),
		"action": action.duplicate(true),
		"result": result.duplicate(true),
	}


func _ai_feedback_events(action: Dictionary, result: Dictionary) -> Array:
	var events := _copy_array(result.get("events", []))
	if str(action.get("kind", "")) == MatchActionEnumerator.KIND_END_TURN:
		var timing_result: Dictionary = _match_state.get("last_timing_result", {})
		var processed_events := _copy_array(timing_result.get("processed_events", []))
		if not processed_events.is_empty():
			events = processed_events
	return events


func _ai_action_status_message(action: Dictionary) -> String:
	var player_name := _player_name(str(action.get("player_id", "")))
	var source_name := _ai_action_source_name(action)
	match str(action.get("kind", "")):
		MatchActionEnumerator.KIND_RING_USE:
			return "%s used the Ring of Magicka." % player_name
		MatchActionEnumerator.KIND_END_TURN:
			return "%s ended the turn." % player_name
		MatchActionEnumerator.KIND_SUMMON_CREATURE:
			return "%s played %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_ATTACK:
			return "%s attacked %s with %s." % [player_name, _ai_action_target_name(action), source_name]
		MatchActionEnumerator.KIND_PLAY_SUPPORT:
			return "%s played %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_PLAY_ITEM:
			return "%s used %s on %s." % [player_name, source_name, _ai_action_target_name(action)]
		MatchActionEnumerator.KIND_ACTIVATE_SUPPORT:
			return "%s activated %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_PLAY_ACTION:
			return "%s resolved %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_DECLINE_PROPHECY:
			return "%s declined %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_CHOOSE_DISCARD:
			return "%s drew %s from the discard pile." % [player_name, source_name]
		MatchActionEnumerator.KIND_DECLINE_DISCARD:
			return "%s had no valid discard choices." % player_name
		_:
			return "%s acted." % player_name


func _ai_action_source_name(action: Dictionary) -> String:
	var source_card: Dictionary = action.get("source_card", {})
	if not source_card.is_empty():
		return _card_name(source_card)
	return "the current action"


func _ai_action_target_name(action: Dictionary) -> String:
	var target: Dictionary = action.get("target", {})
	match str(target.get("kind", "")):
		"player":
			return _player_name(str(target.get("player_id", "")))
		"card":
			return _card_name(target.get("card", {}))
		"lane_slot":
			return "%s lane" % _lane_name(str(target.get("lane_id", "")))
		"mobilize_recruit":
			return "%s lane recruit" % _lane_name(str(target.get("lane_id", "")))
		_:
			return "the target"


func _ai_post_action_state() -> String:
	if _has_match_winner():
		return "match_complete"
	if _local_player_has_pending_interrupt():
		return "waiting_on_local_prophecy"
	if _is_local_player_turn():
		return "returned_to_local_player"
	if _ai_controls_current_decision_window():
		return "continue"
	return "idle"


func _reset_local_match_ai_queue() -> void:
	_queued_ai_step_at_ms = -1
	_paused_ai_step_delay_ms = -1
	_ai_waiting_for_turn_banner = false


func _schedule_local_match_ai_step(delay_ms: int) -> void:
	_queued_ai_step_at_ms = Time.get_ticks_msec() + maxi(delay_ms, 0)
	_paused_ai_step_delay_ms = -1


func _pause_local_match_ai_queue(now_ms: int) -> void:
	if _queued_ai_step_at_ms < 0:
		return
	_paused_ai_step_delay_ms = maxi(_queued_ai_step_at_ms - now_ms, 0)
	_queued_ai_step_at_ms = -1


func _resume_local_match_ai_queue(now_ms: int) -> void:
	if _paused_ai_step_delay_ms < 0 or _queued_ai_step_at_ms >= 0:
		return
	_queued_ai_step_at_ms = now_ms + _paused_ai_step_delay_ms
	_paused_ai_step_delay_ms = -1


func _local_match_ai_delay_remaining_ms() -> int:
	if _queued_ai_step_at_ms < 0:
		return -1
	return maxi(_queued_ai_step_at_ms - Time.get_ticks_msec(), 0)


func _is_turn_banner_active() -> bool:
	return _turn_banner_ms_remaining() > 0


func _turn_banner_ms_remaining() -> int:
	return maxi(_turn_banner_until_ms - Time.get_ticks_msec(), 0)


func _arm_local_match_ai_turn_pacing() -> void:
	_reset_local_match_ai_queue()
	_local_match_ai_action_count = 0
	_ai_waiting_for_turn_banner = true


func _is_local_match_ai_enabled() -> bool:
	return _ai_enabled or _scenario_id == LOCAL_MATCH_AI_SCENARIO_ID


func _ai_player_id() -> String:
	return PLAYER_ORDER[0]


func _ai_controls_current_decision_window() -> bool:
	if not _is_local_match_ai_enabled() or _has_match_winner():
		return false
	if _local_player_has_pending_interrupt():
		return false
	var ai_player_id := _ai_player_id()
	if MatchTiming.has_pending_hand_selection(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_discard_choice(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_player_choice(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_secondary_target(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_consume_selection(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_deck_selection(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_summon_effect_target(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_turn_trigger_target(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_prophecy(_match_state):
		return _has_pending_prophecy_for_player(ai_player_id)
	return _active_player_id() == ai_player_id


static func _build_ai_play_profile(ai_options: Dictionary, card_by_id: Dictionary) -> Dictionary:
	if ai_options.is_empty():
		return {}
	var quality := float(ai_options.get("quality", 1.0))
	var ai_deck_ids: Array = ai_options.get("ai_deck_ids", [])
	if ai_deck_ids.is_empty():
		return AIPlayProfile.build_options(0.0, quality)
	var archetype := DeckArchetypeDetector.detect(ai_deck_ids, card_by_id)
	var aggro_score := float(archetype.get("aggro_score", 0.0))
	return AIPlayProfile.build_options(aggro_score, quality)


func get_local_match_ai_pacing_state() -> Dictionary:
	return {
		"banner_visible": _is_turn_banner_active(),
		"turn_banner_ms_remaining": _turn_banner_ms_remaining(),
		"waiting_for_turn_banner": _ai_waiting_for_turn_banner,
		"queued_delay_ms_remaining": _local_match_ai_delay_remaining_ms(),
		"paused_delay_ms_remaining": _paused_ai_step_delay_ms,
		"action_count": _local_match_ai_action_count,
	}

