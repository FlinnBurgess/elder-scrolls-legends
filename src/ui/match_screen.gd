class_name MatchScreen
extends Control

const HeuristicMatchPolicy = preload("res://src/ai/heuristic_match_policy.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchDebugScenarios = preload("res://src/ui/match_debug_scenarios.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const CARD_DISPLAY_COMPONENT_SCRIPT := preload("res://src/ui/components/CardDisplayComponent.gd")
const CARD_DISPLAY_COMPONENT_SCENE := preload("res://scenes/ui/components/CardDisplayComponent.tscn")
const PLAYER_AVATAR_SCENE := preload("res://scenes/ui/components/PlayerAvatarComponent.tscn")
const PLAYER_MAGICKA_SCENE := preload("res://scenes/ui/components/PlayerMagickaComponent.tscn")

const LANE_REGISTRY_PATH := "res://data/legends/registries/lane_registry.json"
const PLAYER_ORDER := ["player_2", "player_1"]
const DISPLAY_RUNE_THRESHOLDS := [25, 20, 15, 10, 5]
const ATTACK_FEEDBACK_DURATION_MS := 520
const DAMAGE_FEEDBACK_DURATION_MS := 1050
const REMOVAL_FEEDBACK_DURATION_MS := 1280
const DRAW_FEEDBACK_DURATION_MS := 1800
const RUNE_FEEDBACK_DURATION_MS := 2100
const TURN_BANNER_DURATION_MS := 1600
const CARD_HOVER_PREVIEW_DELAY_MS := 1000
const LOCAL_MATCH_AI_SCENARIO_ID := "local_match"
const LOCAL_MATCH_AI_ACTION_DELAY_MS := 320
const SELECTION_MODE_NONE := "none"
const SELECTION_MODE_SUMMON := "summon"
const SELECTION_MODE_ITEM := "item"
const SELECTION_MODE_SUPPORT := "support"
const SELECTION_MODE_ATTACK := "attack"
const SELECTION_MODE_ACTION := "action"
const HELP_TEXT := {
	"guard": "Guard creatures must be attacked before other legal targets in the same lane.",
	"charge": "Charge creatures can attack immediately instead of waiting a turn cycle.",
	"cover": "Cover protects a creature from direct attacks until the granted turn window expires.",
	"ward": "Ward blocks the next source of damage that would hit this creature.",
	"drain": "Drain heals the controlling player for damage dealt to the opposing player.",
	"breakthrough": "Breakthrough deals excess combat damage to the defending player.",
	"lethal": "Any amount of combat damage from Lethal destroys the opposing creature.",
	"mobilize": "Mobilize can create and equip a Recruit if no target creature is chosen and a lane is provided.",
	"rally": "Rally buffs a creature in hand after this creature hits the enemy player.",
	"regenerate": "Regenerate clears damage at the start of its controller's next turn.",
	"shackled": "Shackled creatures skip attacking until the shackle clears on their controller's turn.",
	"silenced": "Silence strips keywords, statuses, triggers, and attached items from the card.",
	"wounded": "Wounded marks that the creature currently has damage on it.",
	"prophecy": "Prophecy cards can be played for free during the opponent's turn when drawn from a broken rune.",
	"ring_of_magicka": "The second player may spend one Ring charge per turn for +1 magicka that turn.",
}

var _match_state: Dictionary = {}
var _selected_instance_id := ""
var _selected_pile_player_id := ""
var _selected_pile_zone := ""
var _status_message := ""
var _scenario_id: String = MatchDebugScenarios.DEFAULT_SCENARIO_ID
var _keyword_registry := {}
var _lane_registry := {}
var _keyword_display_names := {}
var _status_display_names := {}

var _end_turn_button: Button
var _turn_banner_panel: PanelContainer
var _turn_banner_label: Label
var _turn_banner_detail_label: Label
var _match_end_overlay: PanelContainer
var _match_end_title_label: Label
var _match_end_detail_label: Label
var _player_sections := {}
var _lane_panels := {}
var _lane_row_panels := {}
var _lane_row_containers := {}
var _lane_header_buttons := {}
var _card_buttons := {}
var _lane_slot_buttons := {}
var _invalid_feedback := {}
var _detached_card_state := {}
var _insertion_preview := {}
var _targeting_arrow_state := {}
var _targeting_arrow: Line2D
var _prophecy_overlay_state := {}
var _prophecy_card_overlay: Control
var _attack_feedbacks: Array = []
var _damage_feedbacks: Array = []
var _removal_feedbacks: Array = []
var _draw_feedbacks: Array = []
var _rune_feedbacks: Array = []
var _feedback_sequence := 0
var _history_text: TextEdit
var _replay_text: TextEdit
var _state_text: TextEdit
var _local_hand_overlay: Control
var _opponent_hand_overlay: Control
var _player_avatar_overlay: Control
var _opponent_avatar_overlay: Control
var _card_hover_preview_layer: Control
var _lane_hover_preview_pending := {}
var _lane_hover_preview_instance_id := ""
var _lane_hover_preview_button_ref: WeakRef
var _support_hover_preview_pending := {}
var _support_hover_preview_instance_id := ""
var _support_hover_preview_button_ref: WeakRef
var _last_turn_owner_id := ""
var _turn_banner_until_ms := 0
var _queued_ai_step_at_ms := -1
var _paused_ai_step_delay_ms := -1
var _ai_waiting_for_turn_banner := false
var _local_match_ai_action_count := 0
var _pending_layout_scale_frames := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	set_process(true)
	_load_registries()
	_build_ui()
	resized.connect(_apply_match_layout_scale)
	load_scenario(_scenario_id)


func _process(_delta: float) -> void:
	if _turn_banner_panel == null:
		return
	var should_show := _turn_banner_until_ms > Time.get_ticks_msec()
	if _turn_banner_panel.visible != should_show:
		_turn_banner_panel.visible = should_show
	_process_lane_card_hover_preview()
	_process_support_card_hover_preview()
	_process_local_match_ai_turn()
	if _pending_layout_scale_frames > 0:
		_pending_layout_scale_frames -= 1
		_apply_match_layout_scale()


func get_available_scenarios() -> Array:
	return MatchDebugScenarios.list_scenarios()


func get_match_state() -> Dictionary:
	return _match_state


func get_status_message() -> String:
	return _status_message


func get_selected_instance_id() -> String:
	return _selected_instance_id


func get_pending_prophecy_ids() -> Array:
	var ids: Array = []
	for window in MatchTiming.get_pending_prophecies(_match_state):
		ids.append(str(window.get("instance_id", "")))
	return ids


func get_interaction_state() -> Dictionary:
	return {
		"selection_mode": _selected_action_mode(_selected_card()),
		"local_turn": _is_local_player_turn(),
		"local_controls_locked": _should_dim_local_interaction_surfaces(),
		"turn_banner_visible": _is_turn_banner_active(),
		"valid_lane_slot_keys": _valid_lane_slot_keys(),
		"valid_lane_ids": _valid_lane_ids(),
		"valid_target_instance_ids": _valid_card_target_ids(),
		"valid_target_player_ids": _valid_player_target_ids(),
		"invalid_lane_slot_keys": _copy_array(_invalid_feedback.get("lane_slot_keys", [])),
		"invalid_lane_ids": _copy_array(_invalid_feedback.get("lane_ids", [])),
		"invalid_target_instance_ids": _copy_array(_invalid_feedback.get("instance_ids", [])),
		"invalid_player_ids": _copy_array(_invalid_feedback.get("player_ids", [])),
		"detached_active": not _detached_card_state.is_empty(),
		"detached_instance_id": str(_detached_card_state.get("instance_id", "")),
	}


func get_local_match_ai_pacing_state() -> Dictionary:
	return {
		"banner_visible": _is_turn_banner_active(),
		"turn_banner_ms_remaining": _turn_banner_ms_remaining(),
		"waiting_for_turn_banner": _ai_waiting_for_turn_banner,
		"queued_delay_ms_remaining": _local_match_ai_delay_remaining_ms(),
		"paused_delay_ms_remaining": _paused_ai_step_delay_ms,
		"action_count": _local_match_ai_action_count,
	}


func get_feedback_state() -> Dictionary:
	_prune_feedback_state()
	return {
		"attacks": _attack_feedbacks.duplicate(true),
		"damage": _damage_feedbacks.duplicate(true),
		"removals": _removal_feedbacks.duplicate(true),
		"draws": _draw_feedbacks.duplicate(true),
		"runes": _rune_feedbacks.duplicate(true),
	}


func detach_hand_card(instance_id: String) -> bool:
	if not _is_local_hand_card(instance_id):
		return false
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return false
	var mode := _selected_action_mode(card)
	if mode == SELECTION_MODE_NONE:
		return false
	_detach_hand_card(instance_id)
	return true


func is_card_detached() -> bool:
	return not _detached_card_state.is_empty()


func load_scenario(scenario_id: String) -> bool:
	_cancel_detached_card_silent()
	_dismiss_prophecy_overlay()
	_reset_invalid_feedback()
	_clear_feedback_state()
	_reset_local_match_ai_queue()
	_local_match_ai_action_count = 0
	var next_state: Dictionary = MatchDebugScenarios.build_scenario(scenario_id)
	if next_state.is_empty():
		_status_message = "Failed to load scenario %s." % scenario_id
		_refresh_ui()
		return false
	_scenario_id = scenario_id
	_match_state = next_state
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	var scenario_timing_result: Dictionary = _match_state.get("last_timing_result", {})
	var scenario_events := _copy_array(scenario_timing_result.get("processed_events", []))
	if scenario_events.is_empty():
		scenario_events = _recent_presentation_events_from_history()
	_record_feedback_from_events(scenario_events)
	_status_message = "Loaded %s." % _scenario_label(scenario_id)
	_refresh_ui()
	return true


func _process_local_match_ai_turn() -> void:
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
	if _is_local_prophecy_interrupt_open():
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
		_schedule_local_match_ai_step(LOCAL_MATCH_AI_ACTION_DELAY_MS)
		return
	_reset_local_match_ai_queue()


func _execute_local_match_ai_step() -> Dictionary:
	if not _is_local_match_ai_enabled():
		return {"did_execute": false, "yield_reason": "disabled"}
	if _has_match_winner():
		return {"did_execute": false, "yield_reason": "match_complete"}
	if _is_local_prophecy_interrupt_open():
		return {"did_execute": false, "yield_reason": "waiting_on_local_prophecy"}
	if not _ai_controls_current_decision_window():
		return {"did_execute": false, "yield_reason": "no_ai_window"}
	var ai_player_id := _ai_player_id()
	var choice := HeuristicMatchPolicy.choose_action(_match_state, ai_player_id)
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
	if not _prophecy_overlay_state.is_empty() and not bool(_prophecy_overlay_state.get("is_local", true)):
		_animate_enemy_prophecy_resolution(action, result)
	else:
		_refresh_ui()
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
	if _is_local_prophecy_interrupt_open():
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


func select_card(instance_id: String) -> bool:
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		_status_message = "Card %s is not available to inspect." % instance_id
		_refresh_ui()
		return false
	_reset_invalid_feedback()
	_clear_pile_selection()
	_selected_instance_id = instance_id
	_status_message = _selection_prompt(card)
	_refresh_ui()
	return true


func clear_selection() -> void:
	_cancel_detached_card_silent()
	_reset_invalid_feedback()
	_selected_instance_id = ""
	_clear_pile_selection()
	_status_message = "Selection cleared."
	_refresh_ui()


func play_selected_to_lane(lane_id: String, slot_index := -1) -> Dictionary:
	var card := _selected_card()
	if card.is_empty():
		return _invalid_ui_result("Select a creature first.")
	if not _can_resolve_selected_action(card):
		return _invalid_ui_result(_status_message)
	var options := {}
	if slot_index >= 0:
		options["slot_index"] = slot_index
	var result := {}
	if _is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id, options.merged({"lane_id": lane_id}, true))
	else:
		result = LaneRules.summon_from_hand(_match_state, _active_player_id(), _selected_instance_id, lane_id, options)
	return _finalize_engine_result(result, "Played %s into %s." % [_card_name(card), _lane_name(lane_id)])


func play_or_activate_selected() -> Dictionary:
	var card := _selected_card()
	if card.is_empty():
		return _invalid_ui_result("Select a card first.")
	if not _can_resolve_selected_action(card):
		return _invalid_ui_result(_status_message)
	var location := MatchMutations.find_card_location(_match_state, _selected_instance_id)
	var result := {}
	if _is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id)
	elif bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_HAND:
		match str(card.get("card_type", "")):
			"support":
				result = PersistentCardRules.play_support_from_hand(_match_state, _active_player_id(), _selected_instance_id)
			"creature":
				return _invalid_ui_result("Select a lane to summon this creature.")
			"item":
				return _invalid_ui_result("Select a friendly creature to equip this item.")
			"action":
				result = MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id)
			_:
				return _invalid_ui_result("Selected card cannot be played from the UI yet.")
	elif bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_SUPPORT:
		result = PersistentCardRules.activate_support(_match_state, _active_player_id(), _selected_instance_id)
	else:
		return _invalid_ui_result("Selected card has no direct action. Choose a lane or target instead.")
	return _finalize_engine_result(result, "Resolved %s." % _card_name(card))


func target_selected_card(target_instance_id: String) -> Dictionary:
	var selected_card := _selected_card()
	if selected_card.is_empty():
		return _invalid_ui_result("Select a card first.")
	if not _can_resolve_selected_action(selected_card):
		return _invalid_ui_result(_status_message)
	var target_location := MatchMutations.find_card_location(_match_state, target_instance_id)
	if not bool(target_location.get("is_valid", false)):
		return _invalid_ui_result("Target %s is not on the board." % target_instance_id)
	var target_card: Dictionary = target_location.get("card", {})
	var selected_location := MatchMutations.find_card_location(_match_state, _selected_instance_id)
	var result := {}
	if bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_HAND and str(selected_card.get("card_type", "")) == "item":
		result = PersistentCardRules.play_item_from_hand(_match_state, _active_player_id(), _selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_HAND and str(selected_card.get("card_type", "")) == "action":
		result = MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_SUPPORT:
		result = PersistentCardRules.activate_support(_match_state, _active_player_id(), _selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_LANE:
		result = MatchCombat.resolve_attack(_match_state, _active_player_id(), _selected_instance_id, {"type": "creature", "instance_id": target_instance_id})
	else:
		return _invalid_ui_result("Current selection does not use card targets.")
	return _finalize_engine_result(result, "Resolved %s onto %s." % [_card_name(selected_card), _card_name(target_card)])


func attack_selected_player(player_id: String) -> Dictionary:
	var selected_card := _selected_card()
	if selected_card.is_empty():
		return _invalid_ui_result("Select an attacking creature first.")
	if not _can_resolve_selected_action(selected_card):
		return _invalid_ui_result(_status_message)
	var result := MatchCombat.resolve_attack(_match_state, _active_player_id(), _selected_instance_id, {"type": "player", "player_id": player_id})
	return _finalize_engine_result(result, "%s attacked %s." % [_card_name(selected_card), _player_name(player_id)])


func decline_prophecy(instance_id: String) -> Dictionary:
	var player_id := _pending_prophecy_player_id(instance_id)
	if player_id.is_empty():
		return _invalid_ui_result("No pending Prophecy exists for %s." % instance_id)
	var card := _card_from_instance_id(instance_id)
	var result := MatchTiming.decline_pending_prophecy(_match_state, player_id, instance_id)
	return _finalize_engine_result(result, "Declined %s." % _card_name(card), false)


func use_ring() -> bool:
	if MatchTiming.has_pending_prophecy(_match_state):
		_status_message = "Resolve the open Prophecy window before taking further turn actions."
		_refresh_ui()
		return false
	var player_id := _active_player_id()
	if not MatchTurnLoop.can_activate_ring_of_magicka(_match_state, player_id):
		_status_message = "%s cannot use the Ring of Magicka right now." % _player_name(player_id)
		_refresh_ui()
		return false
	MatchTurnLoop.activate_ring_of_magicka(_match_state, player_id)
	_selected_instance_id = ""
	_status_message = "%s used the Ring of Magicka." % _player_name(player_id)
	_refresh_ui()
	return true


func end_turn_action() -> bool:
	if MatchTiming.has_pending_prophecy(_match_state):
		_status_message = "Resolve the open Prophecy window before ending the turn."
		_refresh_ui()
		return false
	var player_id := _active_player_id()
	MatchTurnLoop.end_turn(_match_state, player_id)
	var timing_result: Dictionary = _match_state.get("last_timing_result", {})
	_record_feedback_from_events(_copy_array(timing_result.get("processed_events", [])))
	_selected_instance_id = ""
	_status_message = "Ended %s's turn." % _player_name(player_id)
	_refresh_ui()
	return true


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.name = "MatchLayout"
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 22)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 22)
	add_child(root)
	var content := VBoxContainer.new()
	content.name = "MatchContent"
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	root.add_child(content)

	_card_hover_preview_layer = Control.new()
	_card_hover_preview_layer.name = "CardHoverPreviewLayer"
	_card_hover_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_hover_preview_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_card_hover_preview_layer)

	_opponent_avatar_overlay = Control.new()
	_opponent_avatar_overlay.name = "OpponentAvatarOverlay"
	_opponent_avatar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opponent_avatar_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_opponent_avatar_overlay)

	_player_avatar_overlay = Control.new()
	_player_avatar_overlay.name = "PlayerAvatarOverlay"
	_player_avatar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_avatar_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_player_avatar_overlay)

	_opponent_hand_overlay = Control.new()
	_opponent_hand_overlay.name = "OpponentHandOverlay"
	_opponent_hand_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opponent_hand_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_opponent_hand_overlay)

	_local_hand_overlay = Control.new()
	_local_hand_overlay.name = "LocalHandOverlay"
	_local_hand_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_local_hand_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_local_hand_overlay)

	_prophecy_card_overlay = Control.new()
	_prophecy_card_overlay.name = "ProphecyCardOverlay"
	_prophecy_card_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prophecy_card_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_prophecy_card_overlay.z_index = 450
	add_child(_prophecy_card_overlay)

	var main_row := HBoxContainer.new()
	main_row.name = "MainRow"
	main_row.size_flags_horizontal = SIZE_EXPAND_FILL
	main_row.size_flags_vertical = SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 28)
	content.add_child(main_row)

	var board_column := VBoxContainer.new()
	board_column.name = "BoardColumn"
	board_column.size_flags_horizontal = SIZE_EXPAND_FILL
	board_column.size_flags_vertical = SIZE_EXPAND_FILL
	board_column.add_theme_constant_override("separation", 22)
	main_row.add_child(board_column)

	# Create end turn button early so it can be placed in the player section
	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = Vector2(0, 54)
	_end_turn_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_end_turn_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(_end_turn_button, Color(0.25, 0.14, 0.13, 0.98), Color(0.69, 0.35, 0.27, 0.94), Color(0.98, 0.93, 0.9, 1.0))
	_end_turn_button.pressed.connect(_on_end_turn_pressed)

	for player_id in PLAYER_ORDER:
		var section := _build_player_section(player_id)
		_player_sections[player_id] = section
		board_column.add_child(section["panel"])
		if player_id == PLAYER_ORDER[0]:
			var lanes_panel := _build_lanes_panel()
			board_column.add_child(lanes_panel)

	_match_end_overlay = _build_match_end_overlay()
	root.add_child(_match_end_overlay)

	var debug_overlay := PanelContainer.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	debug_overlay.custom_minimum_size = Vector2(360, 240)
	debug_overlay.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	debug_overlay.anchor_left = 0.0
	debug_overlay.anchor_top = 1.0
	debug_overlay.anchor_right = 0.0
	debug_overlay.anchor_bottom = 1.0
	debug_overlay.offset_left = 24
	debug_overlay.offset_top = -264
	debug_overlay.offset_right = 384
	debug_overlay.offset_bottom = -24
	_apply_panel_style(debug_overlay, Color(0.08, 0.09, 0.12, 0.92), Color(0.24, 0.27, 0.34, 0.72), 1, 10)
	add_child(debug_overlay)

	var debug_box := _build_panel_box(debug_overlay, 8, 10)

	var tabs := TabContainer.new()
	tabs.name = "DebugTabs"
	tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	debug_box.add_child(tabs)

	_history_text = _build_read_only_text("History")
	tabs.add_child(_history_text)
	_replay_text = _build_read_only_text("Replay")
	tabs.add_child(_replay_text)
	_state_text = _build_read_only_text("State")
	tabs.add_child(_state_text)


func _build_player_section(player_id: String) -> Dictionary:
	var is_opponent := player_id == PLAYER_ORDER[0]
	var panel := PanelContainer.new()
	panel.name = "OpponentBand" if is_opponent else "PlayerBand"
	panel.custom_minimum_size = Vector2(0, 220)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_apply_panel_style(panel, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	var box := _build_panel_box(panel, 12, 14)

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 16)
	content_row.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_child(content_row)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero_row.size_flags_horizontal = SIZE_EXPAND_FILL
	content_row.add_child(hero_row)

	var avatar_component := PLAYER_AVATAR_SCENE.instantiate()
	avatar_component.name = "%s_avatar_component" % player_id
	avatar_component.custom_minimum_size = Vector2(282, 264)
	avatar_component.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar_component.gui_input.connect(_on_avatar_gui_input.bind(player_id))
	hero_row.add_child(avatar_component)

	var identity_column := VBoxContainer.new()
	identity_column.size_flags_horizontal = SIZE_EXPAND_FILL
	identity_column.add_theme_constant_override("separation", 8)
	hero_row.add_child(identity_column)
	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 10)
	resource_row.size_flags_horizontal = SIZE_EXPAND_FILL
	identity_column.add_child(resource_row)

	var magicka_mount := CenterContainer.new()
	magicka_mount.name = "%s_magicka_mount" % player_id
	magicka_mount.custom_minimum_size = Vector2(180, 172)
	magicka_mount.size_flags_horizontal = SIZE_EXPAND_FILL
	magicka_mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var magicka_component := PLAYER_MAGICKA_SCENE.instantiate()
	magicka_component.name = "%s_magicka_component" % player_id
	magicka_component.custom_minimum_size = Vector2(172, 172)
	magicka_component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magicka_mount.add_child(magicka_component)

	resource_row.add_child(magicka_mount)

	# Overlay for repositioned magicka (populated after panel is built)
	var magicka_overlay := Control.new()
	magicka_overlay.name = "%s_magicka_overlay" % player_id
	magicka_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magicka_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var ring_panel := PanelContainer.new()
	ring_panel.name = "%s_ring_panel" % player_id
	ring_panel.custom_minimum_size = Vector2(0, 54)
	ring_panel.size_flags_horizontal = 0
	_apply_panel_style(ring_panel, Color(0.18, 0.14, 0.08, 0.96), Color(0.63, 0.53, 0.26, 0.94), 1, 10)
	if not is_opponent:
		ring_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		ring_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ring_panel.gui_input.connect(_on_ring_panel_input)
	resource_row.add_child(ring_panel)
	var ring_box := _build_panel_box(ring_panel, 4, 8)
	var ring_label := Label.new()
	ring_label.name = "%s_ring_label" % player_id
	ring_label.add_theme_font_size_override("font_size", 14)
	ring_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78, 1.0))
	ring_box.add_child(ring_label)
	var ring_row := HBoxContainer.new()
	ring_row.name = "%s_ring_row" % player_id
	ring_row.add_theme_constant_override("separation", 4)
	ring_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ring_box.add_child(ring_row)

	var pile_column := VBoxContainer.new()
	pile_column.custom_minimum_size = Vector2(108, 0)
	pile_column.add_theme_constant_override("separation", 8)
	hero_row.add_child(pile_column)

	var deck_button := Button.new()
	deck_button.name = "%s_deck_button" % player_id
	deck_button.custom_minimum_size = Vector2(0, 48)
	deck_button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(deck_button, Color(0.15, 0.16, 0.2, 0.98), Color(0.36, 0.39, 0.49, 0.92), Color(0.92, 0.94, 0.98, 1.0), 1, 10)
	deck_button.pressed.connect(_on_pile_pressed.bind(player_id, MatchMutations.ZONE_DECK))
	pile_column.add_child(deck_button)

	var discard_button := Button.new()
	discard_button.name = "%s_discard_button" % player_id
	discard_button.custom_minimum_size = Vector2(0, 48)
	discard_button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(discard_button, Color(0.2, 0.12, 0.16, 0.98), Color(0.58, 0.32, 0.39, 0.94), Color(0.97, 0.92, 0.94, 1.0), 1, 10)
	discard_button.pressed.connect(_on_pile_pressed.bind(player_id, MatchMutations.ZONE_DISCARD))
	pile_column.add_child(discard_button)

	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	rows.size_flags_vertical = SIZE_SHRINK_CENTER
	content_row.add_child(rows)

	var support_surface := Control.new()
	support_surface.name = "%s_support_surface" % player_id
	support_surface.focus_mode = Control.FOCUS_NONE
	support_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(support_surface)

	var support_row := HBoxContainer.new()
	support_row.name = "%s_support_row" % player_id
	support_row.add_theme_constant_override("separation", 16)
	support_row.alignment = BoxContainer.ALIGNMENT_END
	support_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	support_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_surface.add_child(support_row)

	# End turn button – bottom-right of local player section
	if not is_opponent:
		var end_turn_row := HBoxContainer.new()
		end_turn_row.size_flags_horizontal = SIZE_SHRINK_END
		_end_turn_button.size_flags_horizontal = 0
		_end_turn_button.custom_minimum_size = Vector2(140, 54)
		end_turn_row.add_child(_end_turn_button)
		box.add_child(end_turn_row)

	var hand_row := Control.new()
	hand_row.name = "%s_hand_row" % player_id
	hand_row.clip_contents = false
	hand_row.set_meta("player_id", player_id)

	if not is_opponent and _local_hand_overlay != null:
		# Local hand floats at the bottom of the screen, separate from the band layout
		hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_local_hand_overlay.add_child(hand_row)
		# Re-layout hand cards when the viewport/overlay resizes
		_local_hand_overlay.resized.connect(_on_hand_surface_resized.bind(hand_row))
	elif is_opponent and _opponent_hand_overlay != null:
		# Opponent hand floats at the top of the screen, separate from the band layout
		hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_opponent_hand_overlay.add_child(hand_row)

	# Reposition magicka and pile buttons into an absolute overlay on the panel
	# so they don't affect the flow layout that other tests depend on.
	panel.add_child(magicka_overlay)
	magicka_mount.reparent(magicka_overlay)
	magicka_mount.size_flags_horizontal = 0
	magicka_mount.size_flags_vertical = 0
	deck_button.reparent(magicka_overlay)
	discard_button.reparent(magicka_overlay)
	ring_panel.reparent(magicka_overlay)
	var pile_btn_width := 108.0
	var pile_btn_height := 48.0
	var pile_gap := 8.0
	var magicka_w := magicka_mount.custom_minimum_size.x
	var magicka_h := magicka_mount.custom_minimum_size.y
	if is_opponent:
		# Top-right of opponent section: magicka, then deck, then discard to the left
		var margin := 14.0
		magicka_mount.anchor_left = 1.0
		magicka_mount.anchor_right = 1.0
		magicka_mount.anchor_top = 0.0
		magicka_mount.anchor_bottom = 0.0
		magicka_mount.offset_left = -magicka_w - margin
		magicka_mount.offset_right = -margin
		magicka_mount.offset_top = margin
		magicka_mount.offset_bottom = magicka_h + margin
		# Deck button – left of magicka, vertically centered on magicka
		var deck_left := magicka_mount.offset_left - pile_gap - pile_btn_width
		var pile_center_y := margin + magicka_h * 0.5
		deck_button.set_anchors_preset(PRESET_TOP_RIGHT)
		deck_button.offset_left = deck_left
		deck_button.offset_right = deck_left + pile_btn_width
		deck_button.offset_top = pile_center_y - pile_btn_height - pile_gap * 0.5
		deck_button.offset_bottom = pile_center_y - pile_gap * 0.5
		# Discard button – left of deck
		discard_button.set_anchors_preset(PRESET_TOP_RIGHT)
		discard_button.offset_left = deck_left
		discard_button.offset_right = deck_left + pile_btn_width
		discard_button.offset_top = pile_center_y + pile_gap * 0.5
		discard_button.offset_bottom = pile_center_y + pile_gap * 0.5 + pile_btn_height
		# Ring panel – below magicka
		var ring_w := pile_btn_width
		ring_panel.set_anchors_preset(PRESET_TOP_RIGHT)
		ring_panel.offset_left = magicka_mount.offset_left
		ring_panel.offset_right = magicka_mount.offset_right
		ring_panel.offset_top = magicka_mount.offset_bottom + pile_gap
		ring_panel.offset_bottom = magicka_mount.offset_bottom + pile_gap + 54.0
	else:
		# Bottom-right, left of end turn button
		var margin := 14.0
		var end_turn_width := 140.0 + 12.0
		magicka_mount.anchor_left = 1.0
		magicka_mount.anchor_right = 1.0
		magicka_mount.anchor_top = 1.0
		magicka_mount.anchor_bottom = 1.0
		magicka_mount.offset_left = -magicka_w - margin - end_turn_width
		magicka_mount.offset_right = -margin - end_turn_width
		magicka_mount.offset_top = -magicka_h - margin
		magicka_mount.offset_bottom = -margin
		# Deck button – left of magicka, vertically centered on magicka
		var deck_left := magicka_mount.offset_left - pile_gap - pile_btn_width
		var pile_center_y := -margin - magicka_h * 0.5
		deck_button.set_anchors_preset(PRESET_BOTTOM_RIGHT)
		deck_button.offset_left = deck_left
		deck_button.offset_right = deck_left + pile_btn_width
		deck_button.offset_top = pile_center_y - pile_btn_height - pile_gap * 0.5
		deck_button.offset_bottom = pile_center_y - pile_gap * 0.5
		# Discard button – below deck
		discard_button.set_anchors_preset(PRESET_BOTTOM_RIGHT)
		discard_button.offset_left = deck_left
		discard_button.offset_right = deck_left + pile_btn_width
		discard_button.offset_top = pile_center_y + pile_gap * 0.5
		discard_button.offset_bottom = pile_center_y + pile_gap * 0.5 + pile_btn_height
		# Ring panel – left of deck/discard stack, vertically centered on magicka
		var ring_w := 130.0
		var ring_h := 54.0
		var ring_right := deck_left - pile_gap
		ring_panel.set_anchors_preset(PRESET_BOTTOM_RIGHT)
		ring_panel.offset_left = ring_right - ring_w
		ring_panel.offset_right = ring_right
		ring_panel.offset_top = pile_center_y - ring_h * 0.5
		ring_panel.offset_bottom = pile_center_y + ring_h * 0.5

	# Reparent avatar and support into their own screen-level overlay
	var avatar_overlay: Control = _opponent_avatar_overlay if is_opponent else _player_avatar_overlay
	if avatar_overlay != null:
		avatar_component.reparent(avatar_overlay)
		avatar_component.size_flags_horizontal = 0
		avatar_component.size_flags_vertical = 0
		avatar_component.clip_contents = true
		support_surface.reparent(avatar_overlay)
		support_surface.size_flags_horizontal = 0
		support_surface.size_flags_vertical = 0
		var avatar_w := 300.0
		var avatar_h := 282.0
		var avatar_gap := 12.0
		var support_h := 144.0
		# Force avatar to its intended size immediately so internal layout is stable
		avatar_component.size = Vector2(avatar_w, avatar_h)
		if is_opponent:
			# Opponent: centred horizontally, below the opponent hand area
			var top_y := 64.0
			avatar_component.set_anchors_preset(PRESET_CENTER_TOP)
			avatar_component.offset_left = -avatar_w * 0.5
			avatar_component.offset_right = avatar_w * 0.5
			avatar_component.offset_top = top_y
			avatar_component.offset_bottom = top_y + avatar_h
			# Supports row to the left of the avatar, right-aligned to grow leftward
			var support_right := -avatar_w * 0.5 - avatar_gap
			support_surface.set_anchors_preset(PRESET_CENTER_TOP)
			support_surface.offset_right = support_right
			support_surface.offset_left = support_right - 600.0
			support_surface.offset_top = top_y + (avatar_h - support_h) * 0.5
			support_surface.offset_bottom = top_y + (avatar_h + support_h) * 0.5
		else:
			# Player: centred horizontally, above the player hand area
			var bottom_margin := 180.0
			avatar_component.set_anchors_preset(PRESET_CENTER_BOTTOM)
			avatar_component.offset_left = -avatar_w * 0.5
			avatar_component.offset_right = avatar_w * 0.5
			avatar_component.offset_top = -avatar_h - bottom_margin
			avatar_component.offset_bottom = -bottom_margin
			# Supports row to the left of the avatar, right-aligned to grow leftward
			var support_right := -avatar_w * 0.5 - avatar_gap
			support_surface.set_anchors_preset(PRESET_CENTER_BOTTOM)
			support_surface.offset_right = support_right
			support_surface.offset_left = support_right - 600.0
			support_surface.offset_top = -avatar_h - bottom_margin + (avatar_h - support_h) * 0.5
			support_surface.offset_bottom = -avatar_h - bottom_margin + (avatar_h + support_h) * 0.5

	return {
		"player_id": player_id,
		"panel": panel,
		"avatar_component": avatar_component,
		"magicka_component": magicka_component,
		"ring_panel": ring_panel,
		"ring_label": ring_label,
		"ring_row": ring_row,
		"deck_button": deck_button,
		"discard_button": discard_button,
		"support_surface": support_surface,
		"support_row": support_row,
		"hand_row": hand_row,
	}


func _build_match_end_overlay() -> PanelContainer:
	var overlay := PanelContainer.new()
	overlay.name = "MatchEndOverlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 80
	_apply_panel_style(overlay, Color(0.04, 0.05, 0.07, 0.78), Color(0.84, 0.71, 0.42, 0.96), 2, 18)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.name = "MatchEndCard"
	card.custom_minimum_size = Vector2(360, 220)
	_apply_panel_style(card, Color(0.1, 0.11, 0.16, 0.98), Color(0.88, 0.74, 0.44, 0.98), 2, 16)
	center.add_child(card)
	var box := _build_panel_box(card, 18, 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_match_end_title_label = Label.new()
	_match_end_title_label.name = "MatchEndTitle"
	_match_end_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_end_title_label.add_theme_font_size_override("font_size", 34)
	box.add_child(_match_end_title_label)
	_match_end_detail_label = Label.new()
	_match_end_detail_label.name = "MatchEndDetailLabel"
	_match_end_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_end_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_match_end_detail_label.add_theme_font_size_override("font_size", 17)
	_match_end_detail_label.custom_minimum_size = Vector2(320, 0)
	box.add_child(_match_end_detail_label)
	var hint := Label.new()
	hint.name = "MatchEndHintLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.84, 0.86, 0.92, 0.9))
	hint.text = "Match complete. Reload or switch scenarios to keep inspecting presentation state."
	box.add_child(hint)
	return overlay


func _build_lanes_panel() -> Control:
	var lanes_row := HBoxContainer.new()
	lanes_row.name = "BattlefieldPanel"
	lanes_row.custom_minimum_size = Vector2(0, 740)
	lanes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes_row.size_flags_horizontal = SIZE_EXPAND_FILL
	lanes_row.size_flags_vertical = SIZE_EXPAND_FILL
	lanes_row.size_flags_stretch_ratio = 2.8
	lanes_row.add_theme_constant_override("separation", 18)

	var lane_list := _lane_entries()
	for i in lane_list.size():
		lanes_row.add_child(_build_lane_separator())
		var lane = lane_list[i]
		var lane_id := str(lane.get("id", ""))
		var lane_panel := PanelContainer.new()
		lane_panel.name = "%s_lane_panel" % lane_id
		lane_panel.custom_minimum_size = Vector2(0, 252)
		lane_panel.size_flags_horizontal = SIZE_EXPAND_FILL
		lane_panel.size_flags_vertical = SIZE_EXPAND_FILL
		lane_panel.size_flags_stretch_ratio = 1.0
		_apply_panel_style(lane_panel, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
		lane_panel.gui_input.connect(_on_lane_panel_gui_input.bind(lane_id))
		lanes_row.add_child(lane_panel)
		_lane_panels[lane_id] = lane_panel
		var lane_box := _build_panel_box(lane_panel, 8, 10)

		for player_id in PLAYER_ORDER:
			var row_panel := PanelContainer.new()
			row_panel.name = "%s_%s_lane_row_panel" % [lane_id, player_id]
			row_panel.custom_minimum_size = Vector2(0, 352)
			row_panel.size_flags_horizontal = SIZE_EXPAND_FILL
			row_panel.size_flags_vertical = SIZE_EXPAND_FILL
			_apply_panel_style(row_panel, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
			row_panel.gui_input.connect(_on_lane_row_gui_input.bind(lane_id, player_id))
			lane_box.add_child(row_panel)
			_lane_row_panels[_lane_row_key(lane_id, player_id)] = row_panel
			var row_box := _build_panel_box(row_panel, 4, 6)
			# Let clicks on non-button children fall through to the row panel
			row_panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var row := HBoxContainer.new()
			row.name = "%s_%s_lane_row" % [lane_id, player_id]
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.size_flags_horizontal = SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 34)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_box.add_child(row)
			_lane_row_containers[_lane_row_key(lane_id, player_id)] = row

	lanes_row.add_child(_build_lane_separator())

	var banner_overlay := MarginContainer.new()
	banner_overlay.name = "TurnBannerOverlay"
	banner_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	banner_overlay.add_theme_constant_override("margin_left", 48)
	banner_overlay.add_theme_constant_override("margin_top", 24)
	banner_overlay.add_theme_constant_override("margin_right", 48)
	banner_overlay.add_theme_constant_override("margin_bottom", 24)
	banner_overlay.z_index = 40
	add_child(banner_overlay)
	var banner_center := CenterContainer.new()
	banner_center.size_flags_horizontal = SIZE_EXPAND_FILL
	banner_center.size_flags_vertical = SIZE_EXPAND_FILL
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_overlay.add_child(banner_center)
	_turn_banner_panel = PanelContainer.new()
	_turn_banner_panel.name = "TurnBannerPanel"
	_turn_banner_panel.visible = false
	_turn_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_banner_panel.custom_minimum_size = Vector2(336, 72)
	banner_center.add_child(_turn_banner_panel)
	var banner_box := _build_panel_box(_turn_banner_panel, 10, 16)
	var banner_column := VBoxContainer.new()
	banner_column.add_theme_constant_override("separation", 3)
	banner_box.add_child(banner_column)
	_turn_banner_label = Label.new()
	_turn_banner_label.name = "TurnBannerLabel"
	_turn_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner_label.add_theme_font_size_override("font_size", 28)
	banner_column.add_child(_turn_banner_label)
	_turn_banner_detail_label = Label.new()
	_turn_banner_detail_label.name = "TurnBannerDetailLabel"
	_turn_banner_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner_detail_label.add_theme_font_size_override("font_size", 13)
	banner_column.add_child(_turn_banner_detail_label)
	return lanes_row


func _build_lane_separator() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.45, 0.75, 0.8)
	sep.custom_minimum_size = Vector2(2, 0)
	sep.size_flags_vertical = SIZE_EXPAND_FILL
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep


func _build_read_only_text(tab_name: String) -> TextEdit:
	var text := TextEdit.new()
	text.name = tab_name
	text.editable = false
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.size_flags_vertical = SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 13)
	text.custom_minimum_size = Vector2(0, 0)
	return text


func _build_panel_box(panel: PanelContainer, separation: int = 12, padding: int = 16) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_bottom", padding)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color, border_width := 1, corner_radius := 10) -> void:
	panel.add_theme_stylebox_override("panel", _build_style_box(fill, border, border_width, corner_radius))


func _apply_button_style(button: Button, fill: Color, border: Color, font_color: Color, border_width := 1, corner_radius := 9) -> void:
	button.add_theme_stylebox_override("normal", _build_style_box(fill, border, border_width, corner_radius))
	button.add_theme_stylebox_override("hover", _build_style_box(fill.lightened(0.08), border.lightened(0.08), border_width, corner_radius))
	button.add_theme_stylebox_override("pressed", _build_style_box(fill.darkened(0.1), border, border_width, corner_radius))
	button.add_theme_stylebox_override("disabled", _build_style_box(fill.darkened(0.18), border.darkened(0.22), border_width, corner_radius))
	button.add_theme_stylebox_override("focus", _build_style_box(fill.lightened(0.04), border.lightened(0.12), border_width, corner_radius))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color.darkened(0.4))


func _apply_surface_button_style(button: Button, surface: String, hidden := false, selected := false, muted := false, interaction_state := "default", card: Dictionary = {}, locked := false) -> void:
	var fill := Color(0.17, 0.18, 0.22, 0.96)
	var border := Color(0.42, 0.44, 0.53, 0.9)
	var font_color := Color(0.95, 0.96, 0.98, 1.0)
	if hidden:
		fill = Color(0.11, 0.11, 0.14, 0.98)
		border = Color(0.3, 0.28, 0.22, 0.9)
	else:
		match surface:
			"lane":
				fill = Color(0.19, 0.16, 0.12, 0.98)
				border = Color(0.66, 0.54, 0.29, 0.94)
			"hand":
				fill = Color(0.14, 0.15, 0.2, 0.99)
				border = Color(0.45, 0.51, 0.68, 0.94)
			"support":
				fill = Color(0.14, 0.18, 0.18, 0.98)
				border = Color(0.35, 0.58, 0.56, 0.92)
		if surface == "hand" and _is_pending_prophecy_card(card):
			fill = fill.lerp(Color(0.24, 0.12, 0.31, 0.99), 0.72)
			border = Color(0.93, 0.73, 0.98, 1.0)
			font_color = Color(1.0, 0.96, 1.0, 1.0)
		var draw_feedback := _active_draw_feedback_for_instance(str(card.get("instance_id", "")))
		if surface == "hand" and not hidden and not draw_feedback.is_empty():
			if bool(draw_feedback.get("from_rune_break", false)):
				fill = fill.lerp(Color(0.33, 0.16, 0.1, 0.99), 0.56)
				border = Color(1.0, 0.78, 0.46, 1.0)
			else:
				fill = fill.lerp(Color(0.16, 0.24, 0.31, 0.99), 0.48)
				border = Color(0.66, 0.9, 1.0, 1.0)
		if surface == "lane" and str(card.get("card_type", "")) == "creature":
			if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
				fill = fill.lerp(Color(0.31, 0.24, 0.14, 0.99), 0.46)
				border = border.lerp(Color(0.99, 0.85, 0.46, 1.0), 0.72)
			var readiness_state := _creature_readiness_state(card)
			match str(readiness_state.get("id", "")):
				"ready":
					fill = fill.lerp(Color(0.15, 0.24, 0.18, 0.99), 0.34)
					border = border.lerp(Color(0.62, 0.95, 0.64, 1.0), 0.54)
				"summoning_sick":
					fill = fill.lerp(Color(0.29, 0.16, 0.11, 0.99), 0.42)
					border = border.lerp(Color(0.96, 0.63, 0.34, 1.0), 0.58)
				"spent":
					fill = fill.darkened(0.08)
					border = border.lerp(Color(0.62, 0.67, 0.76, 0.96), 0.42)
				"disabled":
					fill = fill.lerp(Color(0.23, 0.14, 0.24, 0.99), 0.4)
					border = border.lerp(Color(0.82, 0.58, 0.94, 1.0), 0.54)
	if muted:
		fill = fill.darkened(0.18)
		border = border.darkened(0.12)
		font_color = Color(0.84, 0.84, 0.88, 0.96)
	if locked and interaction_state == "default" and not selected:
		fill = fill.darkened(0.26)
		border = border.darkened(0.18)
		font_color = font_color.lerp(Color(0.72, 0.74, 0.8, 0.92), 0.5)
	if interaction_state == "valid":
		fill = fill.lerp(Color(0.2, 0.31, 0.23, 0.98), 0.48)
		border = Color(0.74, 0.94, 0.68, 1.0)
	elif interaction_state == "invalid":
		fill = fill.lerp(Color(0.31, 0.12, 0.13, 0.99), 0.72)
		border = Color(0.98, 0.48, 0.44, 1.0)
	if selected:
		border = Color(0.98, 0.88, 0.58, 1.0)
		fill = fill.lightened(0.04)
	_apply_button_style(button, fill, border, font_color, 2 if selected else 1, 10 if surface == "hand" else 8)
	button.self_modulate = _locked_surface_modulate(locked, muted)


func _apply_lane_panel_style(panel: PanelContainer, lane_id: String) -> void:
	if panel == null:
		return
	var fill := Color(0, 0, 0, 0)
	var border := Color(0, 0, 0, 0)
	var border_width := 0
	var interaction_state := _lane_panel_interaction_state(lane_id)
	if interaction_state == "valid":
		fill = _lane_panel_fill(lane_id).lightened(0.05)
		border = Color(0.74, 0.94, 0.68, 1.0)
		border_width = 2
	elif interaction_state == "invalid":
		fill = _lane_panel_fill(lane_id).lerp(Color(0.27, 0.12, 0.14, 0.98), 0.58)
		border = Color(0.98, 0.48, 0.44, 1.0)
		border_width = 2
	_apply_panel_style(panel, fill, border, border_width, 12)


func _apply_lane_header_style(button: Button, lane_id: String) -> void:
	if button == null:
		return
	var fill := _lane_header_fill(lane_id)
	var border := _lane_panel_border(lane_id)
	var interaction_state := _lane_panel_interaction_state(lane_id)
	if interaction_state == "valid":
		fill = fill.lightened(0.06)
		border = Color(0.74, 0.94, 0.68, 1.0)
	elif interaction_state == "invalid":
		fill = fill.lerp(Color(0.28, 0.12, 0.14, 1.0), 0.52)
		border = Color(0.98, 0.48, 0.44, 1.0)
	_apply_button_style(button, fill, border, Color(0.96, 0.95, 0.9, 1.0), 2 if interaction_state != "default" else 1, 10)


func _apply_lane_row_panel_style(panel: PanelContainer, lane_id: String, player_id: String) -> void:
	if panel == null:
		return
	var fill := Color(0, 0, 0, 0)
	var border := Color(0, 0, 0, 0)
	var border_width := 0
	var interaction_state := _lane_row_interaction_state(lane_id, player_id)
	if interaction_state == "valid":
		fill = _lane_row_fill(lane_id).lightened(0.05)
		border = Color(0.74, 0.94, 0.68, 1.0)
		border_width = 2
	elif interaction_state == "invalid":
		fill = _lane_row_fill(lane_id).lerp(Color(0.28, 0.12, 0.14, 0.98), 0.56)
		border = Color(0.98, 0.48, 0.44, 1.0)
		border_width = 2
	_apply_panel_style(panel, fill, border, border_width, 10)




func _locked_surface_modulate(locked: bool, muted: bool) -> Color:
	if locked:
		return Color(0.78, 0.8, 0.88, 0.64)
	if muted:
		return Color(0.74, 0.74, 0.78, 0.72)
	return Color(1, 1, 1, 1)


func _build_style_box(fill: Color, border: Color, border_width := 1, corner_radius := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	return style


func _lane_panel_fill(lane_id: String) -> Color:
	return Color(0.1, 0.1, 0.15, 0.98) if lane_id == "shadow" else Color(0.17, 0.17, 0.18, 0.97)


func _lane_panel_border(lane_id: String) -> Color:
	return Color(0.42, 0.41, 0.61, 0.94) if lane_id == "shadow" else Color(0.53, 0.54, 0.48, 0.9)


func _lane_row_fill(lane_id: String) -> Color:
	return Color(0.13, 0.13, 0.17, 0.94) if lane_id == "shadow" else Color(0.21, 0.21, 0.22, 0.92)


func _lane_row_border(lane_id: String) -> Color:
	return Color(0.29, 0.31, 0.45, 0.88) if lane_id == "shadow" else Color(0.34, 0.35, 0.34, 0.82)


func _lane_header_fill(lane_id: String) -> Color:
	return Color(0.16, 0.15, 0.23, 0.98) if lane_id == "shadow" else Color(0.23, 0.22, 0.18, 0.98)


func _lane_marker_text(lane_id: String) -> String:
	return "SHADOW • Cover on entry" if lane_id == "shadow" else "FIELD • Open battle"


func _lane_marker_color(lane_id: String) -> Color:
	return Color(0.82, 0.8, 0.98, 0.96) if lane_id == "shadow" else Color(0.9, 0.88, 0.74, 0.96)



func _refresh_ui() -> void:
	_prune_feedback_state()
	_clear_lane_card_hover_preview()
	_clear_support_card_hover_preview()
	_card_buttons = {}
	_lane_slot_buttons = {}
	_refresh_turn_presentation()
	_refresh_prophecy_overlay()
	_refresh_player_sections()
	_refresh_lanes()
	_apply_match_layout_scale()
	_refresh_debug_tabs()
	_refresh_end_turn_button()
	_refresh_match_end_overlay()
	_apply_presentation_feedback()
	if not _detached_card_state.is_empty():
		var detached_id: String = str(_detached_card_state.get("instance_id", ""))
		var detached_button: Button = _card_buttons.get(detached_id)
		if detached_button != null:
			detached_button.visible = false
		elif not _has_active_prophecy_overlay(detached_id):
			_cancel_detached_card_silent()
	if not _targeting_arrow_state.is_empty():
		var arrow_id: String = str(_targeting_arrow_state.get("instance_id", ""))
		var arrow_button: Button = _card_buttons.get(arrow_id)
		if arrow_button != null:
			arrow_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif not _has_active_prophecy_overlay(arrow_id):
			_cancel_targeting_mode_silent()
	_pending_layout_scale_frames = 2


func _apply_match_layout_scale() -> void:
	var layout := find_child("MatchLayout", true, false) as Control
	var content := find_child("MatchContent", true, false) as Control
	if layout == null or content == null:
		return
	content.pivot_offset = Vector2.ZERO
	content.scale = Vector2.ONE
	var window = get_tree().root
	var layout_size := Vector2(window.size) if window != null else Vector2.ZERO
	if layout_size.x <= 0.0 or layout_size.y <= 0.0:
		layout_size = size if size.x > 0.0 and size.y > 0.0 else layout.size
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		layout_size = Vector2(minf(layout_size.x, viewport_size.x), minf(layout_size.y, viewport_size.y))
	var available: Vector2 = layout_size - Vector2(48, 44)
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var needed: Vector2 = content.get_combined_minimum_size()
	if needed.x <= 0.0 or needed.y <= 0.0:
		return
	var scale_factor: float = min(1.0, min(available.x / needed.x, available.y / needed.y))
	content.scale = Vector2(scale_factor, scale_factor)


func _refresh_player_sections() -> void:
	for player_id in PLAYER_ORDER:
		var section: Dictionary = _player_sections.get(player_id, {})
		var player := _player_state(player_id)
		if section.is_empty() or player.is_empty():
			continue
		var is_opponent: bool = player_id == PLAYER_ORDER[0]
		var panel: PanelContainer = section["panel"]
		panel.self_modulate = Color(0.82, 0.84, 0.9, 0.78) if _should_dim_local_surface(player_id) else Color(1, 1, 1, 1)
		var avatar_component = section.get("avatar_component")
		if avatar_component != null:
			avatar_component.apply_player_state(player, is_opponent)

		var magicka_component = section.get("magicka_component")
		if magicka_component != null:
			magicka_component.apply_player_state(player)

		var ring_panel: PanelContainer = section["ring_panel"]
		ring_panel.visible = bool(player.get("has_ring_of_magicka", false))
		var ring_label: Label = section["ring_label"]
		ring_label.text = _ring_panel_text(player)
		var ring_row: HBoxContainer = section["ring_row"]
		_refresh_ring_row(ring_row, player)

		var deck_button: Button = section["deck_button"]
		deck_button.text = _pile_button_text("Deck", player.get("deck", []).size())
		deck_button.tooltip_text = _pile_button_tooltip(player, MatchMutations.ZONE_DECK)

		var discard_button: Button = section["discard_button"]
		discard_button.text = _pile_button_text("Discard", player.get("discard", []).size())
		discard_button.tooltip_text = _pile_button_tooltip(player, MatchMutations.ZONE_DISCARD)

		var support_row: HBoxContainer = section["support_row"]
		_clear_children(support_row)
		for support in player.get("support", []):
			support_row.add_child(_build_card_button(support, true, "support"))

		var hand_row: Control = section["hand_row"]
		_clear_children(hand_row)
		var hand_public := _is_hand_public(player_id)
		for card in player.get("hand", []):
			if _has_active_prophecy_overlay(str(card.get("instance_id", ""))):
				continue
			hand_row.add_child(_build_card_button(card, hand_public, "hand"))
		if hand_row.get_child_count() == 0:
			var placeholder := _build_placeholder_label("Hand empty")
			hand_row.add_child(placeholder)
			_layout_hand_placeholder(hand_row, placeholder)
		else:
			_layout_hand_cards(hand_row, player_id)


func _refresh_lanes() -> void:
	_clear_insertion_preview()
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var lane_panel: PanelContainer = _lane_panels.get(lane_id)
		_apply_lane_panel_style(lane_panel, lane_id)
		var header: Button = _lane_header_buttons.get(lane_id)
		if header != null:
			header.text = _lane_header_text(lane_id)
			header.tooltip_text = _lane_description(lane_id)
			_apply_lane_header_style(header, lane_id)
		for player_id in PLAYER_ORDER:
			var row_panel: PanelContainer = _lane_row_panels.get(_lane_row_key(lane_id, player_id))
			_apply_lane_row_panel_style(row_panel, lane_id, player_id)
			var row: HBoxContainer = _lane_row_containers.get(_lane_row_key(lane_id, player_id))
			if row == null:
				continue
			_clear_children(row)
			var slots := _lane_slots(lane_id, player_id)
			for card in slots:
				if typeof(card) == TYPE_DICTIONARY:
					row.add_child(_build_card_button(card, true, "lane"))


func _refresh_debug_tabs() -> void:
	_history_text.text = _history_text_value()
	_replay_text.text = _replay_text_value()
	_state_text.text = JSON.stringify(_match_state, "  ")


func _refresh_prophecy_overlay() -> void:
	var has_prophecy := MatchTiming.has_pending_prophecy(_match_state)
	var overlay_active := not _prophecy_overlay_state.is_empty()
	if has_prophecy and not overlay_active:
		var windows := MatchTiming.get_pending_prophecies(_match_state)
		if not windows.is_empty():
			var window: Dictionary = windows[0]
			var instance_id := str(window.get("instance_id", ""))
			var player_id := str(window.get("player_id", ""))
			if player_id == _local_player_id():
				_show_local_prophecy_overlay(instance_id)
			else:
				_show_enemy_prophecy_overlay(instance_id)
	elif not has_prophecy and overlay_active:
		var phase: String = str(_prophecy_overlay_state.get("phase", ""))
		if phase != "animating":
			_dismiss_prophecy_overlay()


func _show_local_prophecy_overlay(instance_id: String) -> void:
	_dismiss_prophecy_overlay()
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size
	var hand_top_y := viewport_size.y - card_size.y * 0.35

	var vbox := VBoxContainer.new()
	vbox.name = "prophecy_local_vbox"
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_END

	var card_wrapper := Control.new()
	card_wrapper.name = "prophecy_card_wrapper"
	card_wrapper.custom_minimum_size = card_size
	card_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	card_wrapper.add_child(component)
	vbox.add_child(card_wrapper)

	var button_row := HBoxContainer.new()
	button_row.name = "prophecy_button_row"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)

	var play_button := Button.new()
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(card_size.x * 0.45, 46)
	play_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(play_button, Color(0.21, 0.12, 0.29, 0.99), Color(0.92, 0.72, 0.98, 1.0), Color(0.99, 0.96, 1.0, 1.0), 2, 10)
	play_button.pressed.connect(_on_prophecy_play_pressed.bind(instance_id))
	button_row.add_child(play_button)

	var keep_button := Button.new()
	keep_button.text = "Keep"
	keep_button.custom_minimum_size = Vector2(card_size.x * 0.45, 46)
	keep_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(keep_button, Color(0.22, 0.11, 0.14, 0.98), Color(0.78, 0.45, 0.47, 0.96), Color(0.99, 0.95, 0.95, 1.0), 1, 10)
	keep_button.pressed.connect(_on_prophecy_keep_pressed.bind(instance_id))
	button_row.add_child(keep_button)

	vbox.add_child(button_row)

	var total_height := card_size.y + 12.0 + 46.0
	var top_y := hand_top_y - total_height - 16.0
	vbox.position = Vector2((viewport_size.x - card_size.x) * 0.5, top_y)
	vbox.size = Vector2(card_size.x, total_height)

	_prophecy_card_overlay.add_child(vbox)
	_prophecy_overlay_state = {
		"instance_id": instance_id,
		"player_id": _local_player_id(),
		"is_local": true,
		"vbox": vbox,
		"card_wrapper": card_wrapper,
		"component": component,
		"phase": "active",
	}
	_selected_instance_id = instance_id


func _show_enemy_prophecy_overlay(instance_id: String) -> void:
	_dismiss_prophecy_overlay()
	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "prophecy_enemy_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x := (viewport_size.x - card_size.x) * 0.5
	var pos_y := viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_prophecy_card_overlay.add_child(card_back)
	_prophecy_overlay_state = {
		"instance_id": instance_id,
		"player_id": _pending_prophecy_player_id(instance_id),
		"is_local": false,
		"card_back": card_back,
		"phase": "active",
	}


func _dismiss_prophecy_overlay() -> void:
	if _prophecy_overlay_state.is_empty():
		return
	var vbox: Control = _prophecy_overlay_state.get("vbox")
	if vbox != null and is_instance_valid(vbox):
		vbox.queue_free()
	var card_back: Control = _prophecy_overlay_state.get("card_back")
	if card_back != null and is_instance_valid(card_back):
		card_back.queue_free()
	_prophecy_overlay_state = {}


func _has_active_prophecy_overlay(instance_id: String) -> bool:
	if _prophecy_overlay_state.is_empty():
		return false
	return str(_prophecy_overlay_state.get("instance_id", "")) == instance_id


func _animate_enemy_prophecy_resolution(action: Dictionary, _result: Dictionary) -> void:
	var card_back: PanelContainer = _prophecy_overlay_state.get("card_back")
	if card_back == null or not is_instance_valid(card_back):
		_dismiss_prophecy_overlay()
		_refresh_ui()
		return
	var action_kind := str(action.get("kind", ""))
	var is_play := action_kind == MatchActionEnumerator.KIND_SUMMON_CREATURE or action_kind == MatchActionEnumerator.KIND_PLAY_ACTION or action_kind == MatchActionEnumerator.KIND_PLAY_ITEM
	_prophecy_overlay_state["phase"] = "animating"
	if is_play:
		# Flip animation: scale X to 0, swap to card face, scale back
		var instance_id := str(_prophecy_overlay_state.get("instance_id", ""))
		var card := _card_from_instance_id(instance_id)
		card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
		var tween := create_tween()
		tween.tween_property(card_back, "scale:x", 0.0, 0.2)
		tween.tween_callback(func():
			# Replace card back content with card face
			for child in card_back.get_children():
				child.queue_free()
			if not card.is_empty():
				var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
				component.mouse_filter = Control.MOUSE_FILTER_IGNORE
				component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
				component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
				card_back.add_child(component)
		)
		tween.tween_property(card_back, "scale:x", 1.0, 0.2)
		tween.tween_interval(0.4)
		tween.tween_callback(func():
			_dismiss_prophecy_overlay()
			_refresh_ui()
		)
	else:
		# Decline: slide up into opponent hand area
		card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card_back, "position:y", -card_back.size.y, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(card_back, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(func():
			_dismiss_prophecy_overlay()
			_refresh_ui()
		)


func _refresh_end_turn_button() -> void:
	var has_pending_prophecy := MatchTiming.has_pending_prophecy(_match_state)
	var local_turn := _is_local_player_turn()
	var match_complete := _has_match_winner()
	_end_turn_button.disabled = match_complete or not local_turn or has_pending_prophecy
	_refresh_end_turn_button_style(has_pending_prophecy)
	if match_complete:
		_end_turn_button.tooltip_text = "Match complete. No further turn actions are available."


func _build_card_button(card: Dictionary, public_view: bool, surface := "default") -> Button:
	var button := Button.new()
	var instance_id := str(card.get("instance_id", ""))
	var hidden := not public_view and not _is_pending_prophecy_card(card)
	var selected := instance_id == _selected_instance_id
	var muted := _should_mute_card(card, public_view, surface)
	var interaction_state := _card_interaction_state(card, surface)
	var locked := _should_dim_card_for_turn(card, surface, interaction_state)
	button.name = "%s_%s_card" % [surface, instance_id]
	button.custom_minimum_size = _surface_button_minimum_size(surface)
	button.clip_contents = surface != "hand"
	button.text = ""
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked and interaction_state == "default" else Control.CURSOR_POINTING_HAND
	button.set_meta("instance_id", instance_id)
	button.set_meta("surface", surface)
	button.set_meta("presentation_locked", locked)
	_apply_surface_button_style(button, surface, hidden, selected, muted, interaction_state, card, locked)
	button.pressed.connect(_on_card_pressed.bind(str(card.get("instance_id", ""))))
	button.tooltip_text = ""
	button.disabled = hidden
	button.set_meta("card_display_component", null)
	_populate_card_button_content(button, card, public_view, surface)
	_apply_card_feedback_decoration(button, card, surface)
	_card_buttons[instance_id] = button
	if surface == "hand" and public_view and str(card.get("controller_player_id", "")) == PLAYER_ORDER[1]:
		button.mouse_entered.connect(_on_local_hand_card_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_local_hand_card_mouse_exited.bind(button))
	if surface == "lane" and str(card.get("card_type", "")) == "creature":
		button.mouse_entered.connect(_on_lane_card_mouse_entered.bind(button, instance_id))
		button.mouse_exited.connect(_on_lane_card_mouse_exited.bind(instance_id))
	if surface == "support":
		button.mouse_entered.connect(_on_support_card_mouse_entered.bind(button, instance_id))
		button.mouse_exited.connect(_on_support_card_mouse_exited.bind(instance_id))
	return button


func _build_placeholder_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.83, 0.85, 0.89, 0.9))
	label.custom_minimum_size = Vector2(176, 44)
	return label


func _surface_button_minimum_size(surface: String) -> Vector2:
	match surface:
		"lane":
			return CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE
		"hand":
			return CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
		"support":
			return CARD_DISPLAY_COMPONENT_SCRIPT.SUPPORT_BOARD_MINIMUM_SIZE
		_:
			return Vector2(132, 80)


func _surface_font_size(surface: String) -> int:
	match surface:
		"lane":
			return 13
		"hand":
			return 15
		"support":
			return 14
		_:
			return 15


func _on_hand_surface_resized(hand_surface: Control) -> void:
	if hand_surface == null:
		return
	var player_id := str(hand_surface.get_meta("player_id", ""))
	var has_card := false
	for child in hand_surface.get_children():
		if child is Button:
			has_card = true
			break
	if has_card:
		_layout_hand_cards(hand_surface, player_id)
	elif hand_surface.get_child_count() > 0 and hand_surface.get_child(0) is Label:
		_layout_hand_placeholder(hand_surface, hand_surface.get_child(0) as Label)
	_apply_match_layout_scale()


func _layout_hand_cards(hand_surface: Control, player_id: String) -> void:
	var cards: Array[Button] = []
	for child in hand_surface.get_children():
		if child is Button:
			cards.append(child as Button)
	if cards.is_empty():
		return
	var card_size := _surface_button_minimum_size("hand")
	var count := cards.size()
	var is_local := player_id == PLAYER_ORDER[1]
	if is_local:
		_layout_local_hand_cards(hand_surface, cards, card_size, count)
	else:
		_layout_opponent_hand_cards(hand_surface, cards, card_size, count)


func _layout_local_hand_cards(hand_surface: Control, cards: Array[Button], card_size: Vector2, count: int) -> void:
	# Cards fan out at the bottom-center of the screen, mostly off the bottom edge.
	var overlay_size := get_viewport_rect().size
	card_size = _hand_card_display_size()
	var overlap_step := card_size.x * 0.45
	var total_width := card_size.x + overlap_step * float(max(0, count - 1))
	var start_x := (overlay_size.x - total_width) * 0.5
	# Cards sit with the top ~35% peeking above the bottom edge
	var base_y := overlay_size.y - card_size.y * 0.35
	for index in range(count):
		var button := cards[index]
		var position := Vector2(start_x + overlap_step * index, base_y)
		button.size = card_size
		button.position = position
		button.pivot_offset = card_size * 0.5
		button.rotation_degrees = 0.0
		button.scale = Vector2.ONE
		button.z_index = index
		button.set_meta("hand_index", index)
		button.set_meta("base_position", position)
		button.set_meta("card_size", card_size)
		# Make button background transparent — the CardDisplayComponent provides
		# all visual framing, and the button may extend beyond the card as a hit zone
		var empty_style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, empty_style)
	for button in cards:
		_apply_local_hand_hover_state(button, false)


func _layout_opponent_hand_cards(hand_surface: Control, cards: Array[Button], card_size: Vector2, count: int) -> void:
	# Cards peek from the top edge of the screen, mirroring the local hand at the bottom.
	var overlay_size := get_viewport_rect().size
	var target_height := overlay_size.y * 0.30
	var aspect_ratio := card_size.x / card_size.y
	card_size = Vector2(target_height * aspect_ratio, target_height)
	var overlap_step := card_size.x * 0.45
	var total_width := card_size.x + overlap_step * float(max(0, count - 1))
	var start_x := (overlay_size.x - total_width) * 0.5
	# Cards sit with only a sliver (~10%) peeking below the top edge
	var base_y := -(card_size.y * 0.90)
	for index in range(count):
		var button := cards[index]
		var position := Vector2(start_x + overlap_step * index, base_y)
		button.size = card_size
		button.position = position
		# Pivot at bottom-center so the fan radiates toward us (opponent faces the player)
		button.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)
		var fan_offset := float(index) - float(count - 1) * 0.5
		button.rotation_degrees = fan_offset * -1.5
		button.scale = Vector2.ONE
		button.z_index = index
		button.set_meta("hand_index", index)
		button.set_meta("base_position", position)
		button.set_meta("card_size", card_size)
		var empty_style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, empty_style)


func _layout_hand_placeholder(hand_surface: Control, placeholder: Label) -> void:
	if hand_surface == null or placeholder == null:
		return
	placeholder.position = Vector2.ZERO
	placeholder.size = Vector2(max(hand_surface.size.x, 220.0), placeholder.custom_minimum_size.y)


func _on_local_hand_card_mouse_entered(button: Button) -> void:
	_apply_local_hand_hover_state(button, true)


func _on_local_hand_card_mouse_exited(button: Button) -> void:
	_apply_local_hand_hover_state(button, false)


func _apply_local_hand_hover_state(button: Button, hovered: bool) -> void:
	if button == null:
		return
	var base_position: Vector2 = button.get_meta("base_position", button.position)
	var hand_index := int(button.get_meta("hand_index", button.z_index))
	var selected := str(button.get_meta("instance_id", "")) == _selected_instance_id
	var locked := bool(button.get_meta("presentation_locked", false))
	var card_size: Vector2 = button.get_meta("card_size", button.size)
	# How far the card needs to rise to be fully visible, plus margin from screen bottom
	var bottom_margin := 24.0
	var rise_amount := card_size.y * 0.85 + bottom_margin
	# Determine target state
	var any_selected := not _selected_instance_id.is_empty()
	var target_position := base_position
	var target_size := card_size
	var target_scale := Vector2.ONE
	var target_z := hand_index
	# When any card is selected (placement mode), non-selected hand cards ignore mouse
	# so they don't block clicks on the board/support surface beneath them
	var target_filter := Control.MOUSE_FILTER_IGNORE if (any_selected and not selected) else Control.MOUSE_FILTER_STOP
	var raised := false
	if not locked:
		if selected:
			target_filter = Control.MOUSE_FILTER_IGNORE
			target_scale = Vector2(1.05, 1.05)
			target_position = base_position + Vector2(0.0, -rise_amount)
			target_z = 110
			raised = true
		if hovered:
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


func _on_lane_card_mouse_entered(button: Button, instance_id: String) -> void:
	_clear_lane_card_hover_preview()
	_lane_hover_preview_pending = {
		"instance_id": instance_id,
		"button_ref": weakref(button),
		"entered_at_ms": Time.get_ticks_msec(),
	}


func _on_lane_card_mouse_exited(instance_id: String) -> void:
	if str(_lane_hover_preview_pending.get("instance_id", "")) == instance_id:
		_lane_hover_preview_pending = {}
	if _lane_hover_preview_instance_id == instance_id:
		_clear_lane_card_hover_preview()


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


func _hand_card_display_size() -> Vector2:
	var base := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var target_height := get_viewport_rect().size.y * 0.30
	var aspect_ratio := base.x / base.y
	return Vector2(target_height * aspect_ratio, target_height)


func _add_hover_preview_to_layer(card: Dictionary, instance_id: String, name_prefix: String) -> Control:
	var preview_size := _hand_card_display_size()
	# Replicate how hand cards render: a CardDisplayComponent built at base
	# size (220x384) with PRESET_FULL_RECT inside a larger container. When
	# the component enters the tree, NOTIFICATION_RESIZED fires and updates
	# geometry to the container size, while fonts stay at the base scale —
	# exactly matching the hand card rendering path.
	var base_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "%s_%s" % [name_prefix, instance_id]
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 400
	# Start at base size so component._ready() sets fonts at scale 1.0
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	wrapper.add_child(component)
	# Add to tree — _ready() fires with base size, fonts set at scale 1.0
	_card_hover_preview_layer.add_child(wrapper)
	# Now resize to preview size — NOTIFICATION_RESIZED updates geometry only,
	# fonts stay at scale 1.0, matching exactly how hand cards render
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	return wrapper


func _show_lane_card_hover_preview(button: Button, card: Dictionary, instance_id: String) -> void:
	_clear_lane_card_hover_preview()
	if _card_hover_preview_layer == null:
		return
	var preview := _add_hover_preview_to_layer(card, instance_id, "lane_hover_preview")
	_lane_hover_preview_instance_id = instance_id
	_lane_hover_preview_button_ref = weakref(button)
	_position_lane_card_hover_preview(button)


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


func _clear_lane_card_hover_preview() -> void:
	_lane_hover_preview_pending = {}
	_lane_hover_preview_instance_id = ""
	_lane_hover_preview_button_ref = null
	if _card_hover_preview_layer == null:
		return
	for child in _card_hover_preview_layer.get_children():
		if str(child.name).begins_with("lane_hover_preview_"):
			child.queue_free()


func _on_support_card_mouse_entered(button: Button, instance_id: String) -> void:
	_clear_support_card_hover_preview()
	_support_hover_preview_pending = {
		"instance_id": instance_id,
		"button_ref": weakref(button),
		"entered_at_ms": Time.get_ticks_msec(),
	}


func _on_support_card_mouse_exited(instance_id: String) -> void:
	if str(_support_hover_preview_pending.get("instance_id", "")) == instance_id:
		_support_hover_preview_pending = {}
	if _support_hover_preview_instance_id == instance_id:
		_clear_support_card_hover_preview()


func _process_support_card_hover_preview() -> void:
	if _support_hover_preview_button_ref != null:
		var active_button = _support_hover_preview_button_ref.get_ref() as Button
		if active_button == null or not is_instance_valid(active_button):
			_clear_support_card_hover_preview()
		elif _support_hover_preview_instance_id != "":
			_position_support_card_hover_preview(active_button)
	if _support_hover_preview_pending.is_empty():
		return
	if Time.get_ticks_msec() - int(_support_hover_preview_pending.get("entered_at_ms", 0)) < CARD_HOVER_PREVIEW_DELAY_MS:
		return
	var button_ref := _support_hover_preview_pending.get("button_ref") as WeakRef
	var button := button_ref.get_ref() as Button if button_ref != null else null
	var instance_id := str(_support_hover_preview_pending.get("instance_id", ""))
	_support_hover_preview_pending = {}
	if button == null or not is_instance_valid(button):
		return
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	_show_support_card_hover_preview(button, card, instance_id)


func _show_support_card_hover_preview(button: Button, card: Dictionary, instance_id: String) -> void:
	_clear_support_card_hover_preview()
	if _card_hover_preview_layer == null:
		return
	var preview := _add_hover_preview_to_layer(card, instance_id, "support_hover_preview")
	_support_hover_preview_instance_id = instance_id
	_support_hover_preview_button_ref = weakref(button)
	_position_support_card_hover_preview(button)


func _position_support_card_hover_preview(button: Button) -> void:
	if button == null or _card_hover_preview_layer == null:
		return
	var preview := _card_hover_preview_layer.get_node_or_null("support_hover_preview_%s" % _support_hover_preview_instance_id) as Control
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


func _clear_support_card_hover_preview() -> void:
	_support_hover_preview_pending = {}
	_support_hover_preview_instance_id = ""
	_support_hover_preview_button_ref = null
	if _card_hover_preview_layer == null:
		return
	for child in _card_hover_preview_layer.get_children():
		if str(child.name).begins_with("support_hover_preview_"):
			child.queue_free()


func _populate_card_button_content(button: Button, card: Dictionary, public_view: bool, surface: String) -> void:
	var hidden := not public_view and not _is_pending_prophecy_card(card)
	var instance_id := str(card.get("instance_id", ""))
	var content_root := Control.new()
	content_root.name = "%s_content_root" % instance_id
	content_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	button.add_child(content_root)
	button.set_meta("content_root", content_root)
	if hidden:
		var card_back := PanelContainer.new()
		card_back.name = "%s_card_back" % instance_id
		card_back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)
		content_root.add_child(card_back)
		_set_mouse_passthrough_recursive(content_root)
		return
	var component := _build_card_display_component(card, surface, instance_id)
	if component != null:
		content_root.add_child(component)
		button.set_meta("card_display_component", component)
	_add_card_overlay_badges(content_root, card, public_view, surface, instance_id)
	_set_mouse_passthrough_recursive(content_root)


func _build_card_display_component(card: Dictionary, surface: String, instance_id: String) -> Control:
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	if component == null:
		return null
	component.name = "%s_card_display" % instance_id
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, _card_presentation_mode(card, surface))
	return component


func _card_presentation_mode(card: Dictionary, surface: String) -> String:
	match surface:
		"lane":
			return CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_CREATURE_BOARD_MINIMAL if str(card.get("card_type", "")) == "creature" else CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL
		"support":
			return CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_SUPPORT_BOARD_MINIMAL if str(card.get("card_type", "")) == "support" else CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL
		_:
			return CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL


func _add_card_overlay_badges(content_root: Control, card: Dictionary, public_view: bool, surface: String, instance_id: String) -> void:
	if surface == "lane":
		var lane_badges := _build_lane_status_badges(card, instance_id)
		if lane_badges != null:
			content_root.add_child(lane_badges)
	if surface == "hand":
		var hand_badges := _build_hand_emphasis_badges(card, public_view, surface, instance_id)
		if hand_badges != null:
			content_root.add_child(hand_badges)


func _build_lane_status_badges(card: Dictionary, instance_id: String) -> HBoxContainer:
	if str(card.get("card_type", "")) != "creature":
		return null
	var row := HBoxContainer.new()
	row.name = "%s_combat_badges" % instance_id
	row.position = Vector2(8, 8)
	row.add_theme_constant_override("separation", 4)
	row.add_child(_build_text_badge("%s_readiness" % instance_id, _lane_readiness_badge_text(card), Color(0.17, 0.2, 0.27, 0.99), Color(0.55, 0.67, 0.84, 0.94), Color(0.9, 0.94, 0.99, 1.0), 9, Vector2(0, 20)))
	if _lane_readiness_badge_text(card) == "READY":
		var readiness_badge := row.get_child(0) as PanelContainer
		_apply_panel_style(readiness_badge, Color(0.16, 0.28, 0.18, 0.99), Color(0.58, 0.92, 0.61, 0.98), 1, 8)
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
		row.add_child(_build_text_badge("%s_guard" % instance_id, "GUARD", Color(0.31, 0.22, 0.1, 0.99), Color(0.95, 0.78, 0.4, 0.98), Color(1.0, 0.96, 0.88, 1.0), 9, Vector2(0, 20)))
	if EvergreenRules.is_cover_active(_match_state, card):
		row.add_child(_build_text_badge("%s_cover" % instance_id, "COVER", Color(0.17, 0.15, 0.28, 0.99), Color(0.77, 0.67, 0.97, 0.98), Color(0.98, 0.95, 1.0, 1.0), 9, Vector2(0, 20)))
	return row


func _lane_readiness_badge_text(card: Dictionary) -> String:
	if str(card.get("controller_player_id", "")) != _active_player_id():
		return "WAITING"
	if bool(card.get("cannot_attack", false)) or EvergreenRules.has_status(card, EvergreenRules.STATUS_SHACKLED):
		return "WAITING"
	if bool(card.get("has_attacked_this_turn", false)):
		return "WAITING"
	if _entered_lane_this_turn(card) and not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_CHARGE):
		return "WAITING"
	return "READY"


func _build_hand_emphasis_badges(card: Dictionary, public_view: bool, surface: String, instance_id: String) -> HBoxContainer:
	var draw_feedback := _active_draw_feedback_for_instance(instance_id)
	if not _is_pending_prophecy_card(card) and not (public_view and not draw_feedback.is_empty()):
		return null
	var row := HBoxContainer.new()
	row.name = "%s_emphasis_row" % instance_id
	row.position = Vector2(16, 54)
	row.add_theme_constant_override("separation", 4)
	if _is_pending_prophecy_card(card):
		row.add_child(_build_text_badge("%s_prophecy_window" % instance_id, "PROPHECY", Color(0.28, 0.14, 0.34, 0.99), Color(0.94, 0.75, 0.98, 1.0), Color(1.0, 0.96, 1.0, 1.0), 10, Vector2(0, 22)))
		row.add_child(_build_text_badge("%s_prophecy_free" % instance_id, "FREE INTERRUPT", Color(0.18, 0.12, 0.3, 0.99), Color(0.72, 0.84, 1.0, 0.98), Color(0.95, 0.98, 1.0, 1.0), 10, Vector2(0, 22)))
	if public_view and not draw_feedback.is_empty():
		row.add_child(_build_text_badge("%s_draw_feedback" % instance_id, _draw_feedback_badge_text(draw_feedback), _draw_feedback_badge_fill(draw_feedback), _draw_feedback_badge_border(draw_feedback), Color(1.0, 0.97, 0.92, 1.0), 10, Vector2(0, 22)))
	return row


func _set_mouse_passthrough_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough_recursive(child)


func _build_value_badge(name_prefix: String, text: String, fill: Color, border: Color, font_color: Color, font_size: int, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "%s_badge" % name_prefix
	panel.custom_minimum_size = min_size
	_apply_panel_style(panel, fill, border, 1, 8)
	var box := _build_panel_box(panel, 0, 6)
	var label := Label.new()
	label.name = "%s_label" % name_prefix
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	box.add_child(label)
	return panel


func _build_text_badge(name_prefix: String, text: String, fill: Color, border: Color, font_color: Color, font_size: int, min_size: Vector2) -> PanelContainer:
	return _build_value_badge(name_prefix, text, fill, border, font_color, font_size, min_size)


func _draw_feedback_badge_text(feedback: Dictionary) -> String:
	return "RUNE DRAW" if bool(feedback.get("from_rune_break", false)) else "DRAWN"


func _draw_feedback_badge_fill(feedback: Dictionary) -> Color:
	return Color(0.32, 0.16, 0.09, 0.99) if bool(feedback.get("from_rune_break", false)) else Color(0.15, 0.22, 0.31, 0.99)


func _draw_feedback_badge_border(feedback: Dictionary) -> Color:
	return Color(1.0, 0.79, 0.46, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.66, 0.9, 1.0, 1.0)


func _surface_content_padding(surface: String) -> int:
	match surface:
		"lane":
			return int(round(4.0 * _surface_scale_factor(surface)))
		"hand":
			return int(round(8.0 * _surface_scale_factor(surface)))
		"support":
			return int(round(6.0 * _surface_scale_factor(surface)))
		_:
			return 6


func _surface_art_height(surface: String) -> float:
	match surface:
		"lane":
			return 18.0 * _surface_scale_factor(surface)
		"hand":
			return 64.0 * _surface_scale_factor(surface)
		"support":
			return 48.0 * _surface_scale_factor(surface)
		_:
			return 40.0


func _surface_scale_factor(surface: String) -> float:
	match surface:
		"lane":
			return CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE.x / 136.0
		"hand":
			return CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE.x / 156.0
		"support":
			return CARD_DISPLAY_COMPONENT_SCRIPT.SUPPORT_BOARD_MINIMUM_SIZE.x / 96.0
		_:
			return 1.0


func _surface_name_font_size(surface: String) -> int:
	match surface:
		"lane":
			return 11
		"hand":
			return 14
		"support":
			return 12
		_:
			return 13


func _surface_meta_font_size(surface: String) -> int:
	return 9 if surface == "lane" else 11


func _surface_rules_font_size(surface: String) -> int:
	match surface:
		"lane":
			return 9
		"hand":
			return 10
		"support":
			return 9
		_:
			return 10


func _surface_art_fill(surface: String) -> Color:
	match surface:
		"lane":
			return Color(0.24, 0.19, 0.14, 0.94)
		"support":
			return Color(0.14, 0.22, 0.22, 0.94)
		_:
			return Color(0.19, 0.16, 0.13, 0.94)


func _surface_art_border(surface: String) -> Color:
	match surface:
		"lane":
			return Color(0.62, 0.47, 0.28, 0.9)
		"support":
			return Color(0.42, 0.63, 0.61, 0.9)
		_:
			return Color(0.72, 0.58, 0.34, 0.9)


func _card_type_line(card: Dictionary, surface := "default") -> String:
	var card_type := str(card.get("card_type", "")).capitalize()
	if surface == "lane":
		return card_type
	return "%s • Cost %d" % [card_type, int(card.get("cost", 0))]


func _card_stat_line(card: Dictionary) -> String:
	if str(card.get("card_type", "")) != "creature":
		return ""
	return "%d / %d" % [EvergreenRules.get_power(card), EvergreenRules.get_remaining_health(card)]


func _card_rules_preview(card: Dictionary, surface := "default") -> String:
	var rules_text := str(card.get("rules_text", "")).strip_edges()
	rules_text = rules_text.replace("\n", " ")
	if not rules_text.is_empty():
		if surface == "lane" and rules_text.length() > 40:
			return "%s…" % rules_text.substr(0, 39).strip_edges()
		return rules_text
	if surface == "lane":
		return "Placeholder rules surface."
	return "No final rules text yet. Placeholder frame keeps the identity readable."


func _card_rarity_text(card: Dictionary) -> String:
	var rarity := str(card.get("rarity", "common")).strip_edges().to_lower()
	return "common" if rarity.is_empty() else rarity


func _rarity_color(card: Dictionary) -> Color:
	match _card_rarity_text(card):
		"legendary":
			return Color(0.98, 0.82, 0.42, 1.0)
		"epic":
			return Color(0.78, 0.62, 0.98, 1.0)
		"rare":
			return Color(0.54, 0.82, 0.99, 1.0)
		"uncommon":
			return Color(0.64, 0.9, 0.64, 1.0)
		_:
			return Color(0.86, 0.86, 0.86, 0.96)


func _stat_color(card: Dictionary, stat: String) -> Color:
	var current := EvergreenRules.get_power(card) if stat == "power" else EvergreenRules.get_remaining_health(card)
	var printed := _printed_power(card) if stat == "power" else _printed_health(card)
	if current > printed:
		return Color(0.56, 0.94, 0.56, 1.0)
	if current < printed:
		return Color(0.97, 0.48, 0.43, 1.0)
	return Color(0.98, 0.94, 0.86, 1.0)


func _printed_power(card: Dictionary) -> int:
	if card.has("power"):
		return int(card.get("power", 0))
	if card.has("current_power"):
		return int(card.get("current_power", 0))
	return int(card.get("base_power", 0))


func _printed_health(card: Dictionary) -> int:
	if card.has("health"):
		return int(card.get("health", 0))
	if card.has("current_health"):
		return int(card.get("current_health", 0))
	return int(card.get("base_health", 0))


func _should_mute_card(card: Dictionary, public_view: bool, surface: String) -> bool:
	if surface != "hand" or not public_view or _is_pending_prophecy_card(card):
		return false
	if str(card.get("controller_player_id", "")) != PLAYER_ORDER[1]:
		return false
	var player := _player_state(str(card.get("controller_player_id", "")))
	if player.is_empty():
		return false
	var available := int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
	return int(card.get("cost", 0)) > available


func _should_dim_card_for_turn(card: Dictionary, surface: String, interaction_state: String) -> bool:
	if surface != "hand" and surface != "support" and surface != "lane":
		return false
	if not _should_dim_local_interaction_surfaces():
		return false
	if str(card.get("controller_player_id", "")) != _local_player_id():
		return false
	if _is_pending_prophecy_card(card):
		return false
	if interaction_state == "valid":
		return false
	if str(card.get("instance_id", "")) == _selected_instance_id and _selected_action_mode(card) != SELECTION_MODE_NONE:
		return false
	return true


func _creature_readiness_state(card: Dictionary) -> Dictionary:
	if str(card.get("card_type", "")) != "creature":
		return {
			"id": "default",
			"label": "READY",
			"fill": Color(0.16, 0.28, 0.18, 0.98),
			"border": Color(0.58, 0.9, 0.62, 0.96),
			"font": Color(0.95, 0.99, 0.96, 1.0),
		}
	if bool(card.get("cannot_attack", false)) or EvergreenRules.has_status(card, EvergreenRules.STATUS_SHACKLED):
		return {
			"id": "disabled",
			"label": "DISABLED",
			"fill": Color(0.25, 0.14, 0.28, 0.99),
			"border": Color(0.8, 0.57, 0.93, 0.98),
			"font": Color(0.98, 0.94, 1.0, 1.0),
		}
	if bool(card.get("has_attacked_this_turn", false)):
		return {
			"id": "spent",
			"label": "SPENT",
			"fill": Color(0.18, 0.2, 0.26, 0.98),
			"border": Color(0.62, 0.68, 0.78, 0.94),
			"font": Color(0.89, 0.92, 0.98, 1.0),
		}
	if _entered_lane_this_turn(card) and not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_CHARGE):
		return {
			"id": "summoning_sick",
			"label": "SUMMONING SICK",
			"fill": Color(0.31, 0.18, 0.11, 0.99),
			"border": Color(0.96, 0.62, 0.32, 0.98),
			"font": Color(1.0, 0.95, 0.88, 1.0),
		}
	if str(card.get("controller_player_id", "")) == _active_player_id():
		return {
			"id": "ready",
			"label": "READY",
			"fill": Color(0.16, 0.28, 0.18, 0.99),
			"border": Color(0.58, 0.92, 0.61, 0.98),
			"font": Color(0.95, 0.99, 0.96, 1.0),
		}
	return {
		"id": "waiting",
		"label": "WAITING",
		"fill": Color(0.17, 0.2, 0.27, 0.99),
		"border": Color(0.55, 0.67, 0.84, 0.94),
		"font": Color(0.9, 0.94, 0.99, 1.0),
	}


func _entered_lane_this_turn(card: Dictionary) -> bool:
	return int(card.get("entered_lane_on_turn", -1)) == int(_match_state.get("turn_number", 0))


func _clear_pile_selection() -> void:
	_selected_pile_player_id = ""
	_selected_pile_zone = ""



func _on_ring_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		use_ring()


func _on_end_turn_pressed() -> void:
	end_turn_action()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos := (event as InputEventMouseMotion).position
		if not _detached_card_state.is_empty():
			var preview: Control = _detached_card_state.get("preview")
			if preview != null and is_instance_valid(preview):
				preview.position = mouse_pos + Vector2(-preview.size.x * 0.5, -preview.size.y * 0.62)
			_update_insertion_preview_from_mouse(mouse_pos)
		if not _targeting_arrow_state.is_empty():
			_update_targeting_arrow(mouse_pos)
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_RIGHT and button_event.pressed:
			if not _targeting_arrow_state.is_empty():
				_cancel_targeting_mode()
				get_viewport().set_input_as_handled()
			elif not _detached_card_state.is_empty():
				_cancel_detached_card()
				get_viewport().set_input_as_handled()
			elif not _selected_instance_id.is_empty():
				clear_selection()
				get_viewport().set_input_as_handled()


func _on_card_pressed(instance_id: String) -> void:
	if not _targeting_arrow_state.is_empty():
		if _try_resolve_selected_card_target(instance_id):
			return
		_report_invalid_interaction("Not a valid target.", {"instance_ids": [instance_id]})
		return
	if not _detached_card_state.is_empty():
		var target_card := _card_from_instance_id(instance_id)
		if _try_resolve_selected_support_row_card(target_card):
			return
		if _try_resolve_selected_card_target(instance_id):
			return
		_try_resolve_detached_card_via_lane(instance_id)
		return
	if _is_local_hand_card(instance_id):
		var card := _card_from_instance_id(instance_id)
		var mode := _selected_action_mode(card)
		if mode == SELECTION_MODE_ITEM or mode == SELECTION_MODE_ACTION:
			_enter_targeting_mode(instance_id)
			return
		elif mode != SELECTION_MODE_NONE:
			_detach_hand_card(instance_id)
			return
	var target_card := _card_from_instance_id(instance_id)
	if _try_resolve_selected_support_row_card(target_card):
		return
	if _try_resolve_selected_card_target(instance_id):
		return
	select_card(instance_id)



func _on_lane_row_gui_input(event: InputEvent, lane_id: String, player_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if button_event.button_index != MOUSE_BUTTON_LEFT or not button_event.pressed:
		return
	var card := _selected_card()
	if card.is_empty():
		return
	if not _targeting_arrow_state.is_empty() and _selected_action_mode(card) == SELECTION_MODE_ACTION:
		_play_action_to_lane(lane_id)
		accept_event()
		return
	if not _selected_support_row_target_player_id(card).is_empty():
		_play_selected_to_support_row(_selected_support_row_target_player_id(card))
		accept_event()
		return
	if _selected_card_wants_lane(card, _target_lane_player_id()):
		var slot_index := _get_insertion_index_or_default(lane_id, _target_lane_player_id())
		if slot_index >= 0:
			var validation := _validate_selected_lane_play(lane_id, _target_lane_player_id(), slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
				accept_event()
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})
				accept_event()


func _on_lane_panel_gui_input(event: InputEvent, lane_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if button_event.button_index != MOUSE_BUTTON_LEFT or not button_event.pressed:
		return
	var card := _selected_card()
	if card.is_empty():
		return
	if not _targeting_arrow_state.is_empty() and _selected_action_mode(card) == SELECTION_MODE_ACTION:
		_play_action_to_lane(lane_id)
		accept_event()
		return
	if not _selected_support_row_target_player_id(card).is_empty():
		_play_selected_to_support_row(_selected_support_row_target_player_id(card))
		accept_event()
		return
	var target_player := _target_lane_player_id()
	if _selected_card_wants_lane(card, target_player):
		var slot_index := _get_insertion_index_or_default(lane_id, target_player)
		if slot_index >= 0:
			var validation := _validate_selected_lane_play(lane_id, target_player, slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
				accept_event()
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})
				accept_event()


func _on_lane_pressed(lane_id: String) -> void:
	var card := _selected_card()
	if not _targeting_arrow_state.is_empty() and _selected_action_mode(card) == SELECTION_MODE_ACTION:
		_play_action_to_lane(lane_id)
		return
	var target_player := _target_lane_player_id()
	if not _selected_support_row_target_player_id(card).is_empty():
		_play_selected_to_support_row(_selected_support_row_target_player_id(card))
		return
	var slot_index := _get_insertion_index_or_default(lane_id, target_player)
	if slot_index >= 0 and _selected_card_wants_lane(card, target_player):
		var validation := _validate_selected_lane_play(lane_id, target_player, slot_index)
		if bool(validation.get("is_valid", false)):
			play_selected_to_lane(lane_id, slot_index)
		else:
			_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
				"lane_ids": [lane_id],
			})
		return
	_status_message = "Lane details: %s." % _lane_name(lane_id)
	_refresh_ui()




func _on_avatar_gui_input(event: InputEvent, player_id: String) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_player_pressed(player_id)


func _on_player_pressed(player_id: String) -> void:
	if _try_resolve_selected_player_target(player_id):
		return
	_clear_pile_selection()
	_status_message = "%s selected." % _player_name(player_id)
	_refresh_ui()


func _on_pile_pressed(player_id: String, zone: String) -> void:
	_reset_invalid_feedback()
	_selected_instance_id = ""
	_selected_pile_player_id = player_id
	_selected_pile_zone = zone
	_status_message = "Inspecting %s's %s." % [_player_name(player_id), _identifier_to_name(zone)]
	_refresh_ui()


func _on_prophecy_play_pressed(instance_id: String) -> void:
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	_selected_instance_id = instance_id
	var mode := _selected_action_mode(card)
	match mode:
		SELECTION_MODE_SUMMON:
			_detach_prophecy_card(instance_id)
		SELECTION_MODE_ITEM, SELECTION_MODE_ACTION:
			_enter_prophecy_targeting_mode(instance_id)
		_:
			play_or_activate_selected()


func _on_prophecy_keep_pressed(instance_id: String) -> void:
	_dismiss_prophecy_overlay()
	decline_prophecy(instance_id)


func _load_registries() -> void:
	_keyword_registry = EvergreenRules.get_registry()
	for keyword in _keyword_registry.get("keywords", []):
		if typeof(keyword) == TYPE_DICTIONARY:
			_keyword_display_names[str(keyword.get("id", ""))] = str(keyword.get("display_name", keyword.get("id", "")))
	for status in _keyword_registry.get("status_markers", []):
		if typeof(status) == TYPE_DICTIONARY:
			_status_display_names[str(status.get("id", ""))] = str(status.get("display_name", status.get("id", "")))
	var file := FileAccess.open(LANE_REGISTRY_PATH, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_lane_registry = parsed



func _selected_card() -> Dictionary:
	return _card_from_instance_id(_selected_instance_id)


func _selected_action_mode(card: Dictionary) -> String:
	if card.is_empty():
		return SELECTION_MODE_NONE
	if MatchTiming.has_pending_prophecy(_match_state) and not _is_pending_prophecy_card(card):
		return SELECTION_MODE_NONE
	if _is_pending_prophecy_card(card):
		var prophecy_type := str(card.get("card_type", ""))
		if prophecy_type == "creature":
			return SELECTION_MODE_SUMMON
		if prophecy_type == "item":
			return SELECTION_MODE_ITEM
		if prophecy_type == "support":
			return SELECTION_MODE_SUPPORT
		if prophecy_type == "action":
			return SELECTION_MODE_ACTION
		return SELECTION_MODE_NONE
	if str(card.get("controller_player_id", "")) != _active_player_id():
		return SELECTION_MODE_NONE
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	if not bool(location.get("is_valid", false)):
		return SELECTION_MODE_NONE
	match str(location.get("zone", "")):
		MatchMutations.ZONE_HAND:
			match str(card.get("card_type", "")):
				"creature":
					return SELECTION_MODE_SUMMON
				"item":
					return SELECTION_MODE_ITEM
				"support":
					return SELECTION_MODE_SUPPORT
				"action":
					return SELECTION_MODE_ACTION
		MatchMutations.ZONE_SUPPORT:
			return SELECTION_MODE_SUPPORT
		MatchMutations.ZONE_LANE:
			return SELECTION_MODE_ATTACK
	return SELECTION_MODE_NONE


func _try_resolve_selected_card_target(target_instance_id: String) -> bool:
	var selected_card := _selected_card()
	var target_card := _card_from_instance_id(target_instance_id)
	if selected_card.is_empty() or target_card.is_empty():
		return false
	if not _selected_action_consumes_card_click(target_card):
		return false
	if _is_card_target_valid_for_selected(target_instance_id):
		_reset_invalid_feedback()
		target_selected_card(target_instance_id)
	else:
		_report_invalid_interaction("%s can't target %s right now." % [_card_name(selected_card), _card_name(target_card)], {"instance_ids": [target_instance_id]})
	return true


func _try_resolve_selected_player_target(player_id: String) -> bool:
	var selected_card := _selected_card()
	if selected_card.is_empty():
		return false
	var mode := _selected_action_mode(selected_card)
	if mode == SELECTION_MODE_SUMMON:
		_report_invalid_interaction("Select a lane slot to summon this creature.", {"player_ids": [player_id]})
		return true
	if mode == SELECTION_MODE_ACTION and not _targeting_arrow_state.is_empty():
		var action_state: Dictionary = _match_state.duplicate(true)
		var validation := MatchTiming.play_action_from_hand(action_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"target_player_id": player_id})
		if bool(validation.get("is_valid", false)):
			_reset_invalid_feedback()
			var result := MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id, {"target_player_id": player_id})
			_finalize_engine_result(result, "%s targeted %s." % [_card_name(selected_card), _player_name(player_id)])
		else:
			_report_invalid_interaction("%s can't target %s right now." % [_card_name(selected_card), _player_name(player_id)], {"player_ids": [player_id]})
		return true
	if mode != SELECTION_MODE_ATTACK or player_id == _active_player_id():
		return false
	if _is_player_target_valid_for_selected(player_id):
		_reset_invalid_feedback()
		attack_selected_player(player_id)
	else:
		_report_invalid_interaction("%s can't attack %s right now." % [_card_name(selected_card), _player_name(player_id)], {"player_ids": [player_id]})
	return true


func _selected_action_consumes_card_click(target_card: Dictionary) -> bool:
	var selected_card := _selected_card()
	var mode := _selected_action_mode(selected_card)
	if mode == SELECTION_MODE_NONE:
		return false
	var target_location := MatchMutations.find_card_location(_match_state, str(target_card.get("instance_id", "")))
	if not bool(target_location.get("is_valid", false)):
		return false
	var target_zone := str(target_location.get("zone", ""))
	match mode:
		SELECTION_MODE_ITEM:
			return target_zone == MatchMutations.ZONE_LANE
		SELECTION_MODE_ACTION:
			return target_zone == MatchMutations.ZONE_LANE
		SELECTION_MODE_SUPPORT:
			return _selected_support_uses_card_targets(selected_card) and target_zone == MatchMutations.ZONE_LANE
		SELECTION_MODE_ATTACK:
			return target_zone == MatchMutations.ZONE_LANE and str(target_card.get("controller_player_id", "")) != str(selected_card.get("controller_player_id", ""))
	return false


func _selected_card_wants_lane(card: Dictionary, player_id: String) -> bool:
	if card.is_empty() or player_id != _target_lane_player_id():
		return false
	return _selected_action_mode(card) == SELECTION_MODE_SUMMON


func _validate_selected_lane_play(lane_id: String, player_id: String, slot_index: int) -> Dictionary:
	var card := _selected_card()
	if not _selected_card_wants_lane(card, player_id):
		return {"is_valid": false, "message": "Select a creature that can be summoned into %s." % _lane_name(lane_id)}
	if _is_pending_prophecy_card(card):
		var prophecy_state: Dictionary = _match_state.duplicate(true)
		return MatchTiming.play_pending_prophecy(prophecy_state, str(card.get("controller_player_id", "")), _selected_instance_id, {"lane_id": lane_id, "slot_index": slot_index})
	return LaneRules.validate_summon_from_hand(_match_state, _active_player_id(), _selected_instance_id, lane_id, {"slot_index": slot_index})


func _is_card_target_valid_for_selected(target_instance_id: String) -> bool:
	var selected_card := _selected_card()
	var mode := _selected_action_mode(selected_card)
	if mode == SELECTION_MODE_NONE:
		return false
	match mode:
		SELECTION_MODE_ITEM:
			var item_state: Dictionary = _match_state.duplicate(true)
			return bool(PersistentCardRules.play_item_from_hand(item_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"target_instance_id": target_instance_id}).get("is_valid", false))
		SELECTION_MODE_ACTION:
			var action_state: Dictionary = _match_state.duplicate(true)
			return bool(MatchTiming.play_action_from_hand(action_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"target_instance_id": target_instance_id}).get("is_valid", false))
		SELECTION_MODE_SUPPORT:
			if not _selected_support_uses_card_targets(selected_card):
				return false
			var location := MatchMutations.find_card_location(_match_state, target_instance_id)
			return bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_LANE
		SELECTION_MODE_ATTACK:
			return bool(MatchCombat.validate_attack(_match_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"type": "creature", "instance_id": target_instance_id}).get("is_valid", false))
	return false


func _is_player_target_valid_for_selected(player_id: String) -> bool:
	var selected_card := _selected_card()
	if _selected_action_mode(selected_card) != SELECTION_MODE_ATTACK:
		return false
	return bool(MatchCombat.validate_attack(_match_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"type": "player", "player_id": player_id}).get("is_valid", false))


func _lane_cards() -> Array:
	var cards: Array = []
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		for player_id in PLAYER_ORDER:
			for card in _lane_slots(lane_id, player_id):
				if typeof(card) == TYPE_DICTIONARY and not card.is_empty():
					cards.append(card)
	return cards


func _valid_lane_slot_keys() -> Array:
	var keys: Array = []
	if _selected_action_mode(_selected_card()) != SELECTION_MODE_SUMMON:
		return keys
	var player_id := _target_lane_player_id()
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var slots := _lane_slots(lane_id, player_id)
		var slot_capacity := _lane_slot_capacity(lane_id)
		if slots.size() < slot_capacity:
			var append_index := slots.size()
			if bool(_validate_selected_lane_play(lane_id, player_id, append_index).get("is_valid", false)):
				keys.append(_lane_slot_key(lane_id, player_id, append_index))
	return keys


func _valid_lane_ids() -> Array:
	var ids: Array = []
	if not _selected_support_row_target_player_id(_selected_card()).is_empty():
		for lane in _lane_entries():
			ids.append(str(lane.get("id", "")))
		return ids
	for slot_key in _valid_lane_slot_keys():
		var lane_id := str(slot_key).split(":")[0]
		if not ids.has(lane_id):
			ids.append(lane_id)
	return ids


func _valid_card_target_ids() -> Array:
	var ids: Array = []
	var mode := _selected_action_mode(_selected_card())
	if mode != SELECTION_MODE_ITEM and mode != SELECTION_MODE_SUPPORT and mode != SELECTION_MODE_ATTACK:
		return ids
	for card in _lane_cards():
		var instance_id := str(card.get("instance_id", ""))
		if _is_card_target_valid_for_selected(instance_id):
			ids.append(instance_id)
	return ids


func _valid_player_target_ids() -> Array:
	var ids: Array = []
	if _selected_action_mode(_selected_card()) != SELECTION_MODE_ATTACK:
		return ids
	for player_id in PLAYER_ORDER:
		if player_id != _active_player_id() and _is_player_target_valid_for_selected(player_id):
			ids.append(player_id)
	return ids




func _card_interaction_state(card: Dictionary, surface: String) -> String:
	var instance_id := str(card.get("instance_id", ""))
	if _copy_array(_invalid_feedback.get("instance_ids", [])).has(instance_id):
		return "invalid"
	var mode := _selected_action_mode(_selected_card())
	if mode == SELECTION_MODE_ITEM and surface == "lane":
		return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	if mode == SELECTION_MODE_SUPPORT and surface == "lane" and _selected_support_uses_card_targets(_selected_card()):
		return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	if mode == SELECTION_MODE_ATTACK and surface == "lane":
		var selected_card := _selected_card()
		if not selected_card.is_empty() and str(card.get("controller_player_id", "")) != str(selected_card.get("controller_player_id", "")):
			return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	return "default"


func _lane_panel_interaction_state(lane_id: String) -> String:
	if _copy_array(_invalid_feedback.get("lane_ids", [])).has(lane_id):
		return "invalid"
	if _selected_action_mode(_selected_card()) != SELECTION_MODE_SUMMON:
		return "default"
	return "valid" if _valid_lane_ids().has(lane_id) else "invalid"


func _lane_row_interaction_state(lane_id: String, player_id: String) -> String:
	if _selected_action_mode(_selected_card()) != SELECTION_MODE_SUMMON:
		return "default"
	if player_id != _target_lane_player_id():
		return "invalid"
	return "valid" if _valid_lane_ids().has(lane_id) else "invalid"



func _can_resolve_selected_action(card: Dictionary) -> bool:
	if card.is_empty():
		_status_message = "Select a card first."
		return false
	if MatchTiming.has_pending_prophecy(_match_state) and not _is_pending_prophecy_card(card):
		_status_message = "Resolve the pending Prophecy before taking other actions."
		return false
	if _is_pending_prophecy_card(card):
		return true
	var controller_player_id := str(card.get("controller_player_id", ""))
	if controller_player_id != _active_player_id():
		_status_message = "Only the active player's public cards can act right now."
		return false
	return true


func _selected_support_row_target_player_id(card: Dictionary) -> String:
	if card.is_empty() or str(card.get("card_type", "")) != "support":
		return ""
	if _is_pending_prophecy_card(card):
		return str(card.get("controller_player_id", ""))
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	if not bool(location.get("is_valid", false)):
		return ""
	return str(card.get("controller_player_id", "")) if str(location.get("zone", "")) == MatchMutations.ZONE_HAND else ""


func _selected_card_wants_support_row(card: Dictionary, player_id: String) -> bool:
	return not player_id.is_empty() and _selected_support_row_target_player_id(card) == player_id


func _selected_support_uses_card_targets(card: Dictionary) -> bool:
	if card.is_empty() or _selected_action_mode(card) != SELECTION_MODE_SUPPORT or _is_pending_prophecy_card(card):
		return false
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	return bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_SUPPORT


func _validate_selected_support_play(player_id: String) -> Dictionary:
	var card := _selected_card()
	var target_player_id := _selected_support_row_target_player_id(card)
	if target_player_id.is_empty():
		return {"is_valid": false, "message": "Select a support card from hand to place it here."}
	if not _selected_card_wants_support_row(card, player_id):
		return {"is_valid": false, "message": "%s can only be placed into %s's support row." % [_card_name(card), _player_name(target_player_id)]}
	if _is_pending_prophecy_card(card):
		var prophecy_state: Dictionary = _match_state.duplicate(true)
		return MatchTiming.play_pending_prophecy(prophecy_state, str(card.get("controller_player_id", "")), _selected_instance_id)
	var support_state: Dictionary = _match_state.duplicate(true)
	return PersistentCardRules.play_support_from_hand(support_state, str(card.get("controller_player_id", "")), _selected_instance_id)


func _finalize_engine_result(result: Dictionary, success_message: String, clear_selection_on_success := true) -> Dictionary:
	if bool(result.get("is_valid", false)):
		_cancel_detached_card_silent()
		_cancel_targeting_mode_silent()
		_dismiss_prophecy_overlay()
		_reset_invalid_feedback()
		if clear_selection_on_success:
			_selected_instance_id = ""
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = success_message
	else:
		_status_message = str(result.get("errors", ["Action failed."])[0])
	_refresh_ui()
	return result


func _invalid_ui_result(message: String) -> Dictionary:
	_status_message = message
	_refresh_ui()
	return {"is_valid": false, "errors": [message]}


func _report_invalid_interaction(message: String, feedback := {}) -> Dictionary:
	_invalid_feedback = {
		"lane_slot_keys": _copy_array(feedback.get("lane_slot_keys", [])),
		"lane_ids": _copy_array(feedback.get("lane_ids", [])),
		"instance_ids": _copy_array(feedback.get("instance_ids", [])),
		"player_ids": _copy_array(feedback.get("player_ids", [])),
	}
	_status_message = message
	_refresh_ui()
	return {"is_valid": false, "errors": [message]}


func _reset_invalid_feedback() -> void:
	_invalid_feedback = {
		"lane_slot_keys": [],
		"lane_ids": [],
		"instance_ids": [],
		"player_ids": [],
	}


func _recent_presentation_events_from_history() -> Array:
	var recent: Array = []
	var history: Array = _match_state.get("event_log", [])
	for index in range(history.size() - 1, -1, -1):
		var event = history[index]
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("event_type", ""))
		if event_type == "turn_started" and not recent.is_empty():
			break
		if event_type == MatchTiming.EVENT_RUNE_BROKEN or event_type == MatchTiming.EVENT_CARD_DRAWN or event_type == MatchTiming.EVENT_PROPHECY_WINDOW_OPENED or event_type == "match_won":
			recent.push_front(event)
			if recent.size() >= 8:
				break
	return recent


func _clear_feedback_state() -> void:
	_attack_feedbacks.clear()
	_damage_feedbacks.clear()
	_removal_feedbacks.clear()
	_draw_feedbacks.clear()
	_rune_feedbacks.clear()


func _record_feedback_from_events(events: Array) -> void:
	if events.is_empty():
		return
	var damage_stacks := {}
	var removal_stacks := {}
	var draw_stacks := {}
	var rune_stacks := {}
	var now := _feedback_now_ms()
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("event_type", ""))
		match event_type:
			"attack_declared":
				_attack_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"attacker_instance_id": str(event.get("attacker_instance_id", "")),
					"attacker_player_id": str(event.get("attacking_player_id", "")),
					"target_type": str(event.get("target_type", "")),
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": str(event.get("target_player_id", "")),
					"expires_at_ms": now + ATTACK_FEEDBACK_DURATION_MS,
				})
			"damage_resolved":
				var damage_target_key := _damage_target_key(event)
				var damage_stack := int(damage_stacks.get(damage_target_key, 0))
				damage_stacks[damage_target_key] = damage_stack + 1
				_damage_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"target_kind": str(event.get("target_type", "")),
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": str(event.get("target_player_id", "")),
					"text": "-%d" % int(event.get("amount", 0)),
					"color": Color(1.0, 0.56, 0.47, 1.0),
					"stack_index": damage_stack,
					"expires_at_ms": now + DAMAGE_FEEDBACK_DURATION_MS,
				})
			"ward_removed":
				var ward_target_key := "creature:%s" % str(event.get("target_instance_id", ""))
				var ward_stack := int(damage_stacks.get(ward_target_key, 0))
				damage_stacks[ward_target_key] = ward_stack + 1
				_damage_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"target_kind": MatchCombat.TARGET_TYPE_CREATURE,
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": "",
					"text": "WARD",
					"color": Color(0.74, 0.9, 1.0, 1.0),
					"stack_index": ward_stack,
					"expires_at_ms": now + DAMAGE_FEEDBACK_DURATION_MS,
				})
			"creature_destroyed":
				var row_key := "%s:%s" % [str(event.get("lane_id", "")), str(event.get("controller_player_id", ""))]
				var removal_stack := int(removal_stacks.get(row_key, 0))
				removal_stacks[row_key] = removal_stack + 1
				var destroyed_card := _card_from_instance_id(str(event.get("instance_id", "")))
				_removal_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"lane_id": str(event.get("lane_id", "")),
					"player_id": str(event.get("controller_player_id", "")),
					"instance_id": str(event.get("instance_id", "")),
					"text": "%s falls" % _card_name(destroyed_card),
					"stack_index": removal_stack,
					"expires_at_ms": now + REMOVAL_FEEDBACK_DURATION_MS,
				})
			"card_drawn":
				var draw_player_id := str(event.get("player_id", ""))
				var draw_stack := int(draw_stacks.get(draw_player_id, 0))
				draw_stacks[draw_player_id] = draw_stack + 1
				var drawn_instance_id := str(event.get("drawn_instance_id", ""))
				var drawn_card := _card_from_instance_id(drawn_instance_id)
				var show_card_name := _should_reveal_drawn_card(draw_player_id, drawn_card)
				_draw_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"player_id": draw_player_id,
					"drawn_instance_id": drawn_instance_id,
					"card_name": _card_name(drawn_card) if show_card_name else "",
					"show_card_name": show_card_name,
					"from_rune_break": str(event.get("reason", "")) == MatchTiming.EVENT_RUNE_BROKEN,
					"stack_index": draw_stack,
					"expires_at_ms": now + DRAW_FEEDBACK_DURATION_MS,
				})
			"rune_broken":
				var rune_player_id := str(event.get("player_id", ""))
				var rune_stack := int(rune_stacks.get(rune_player_id, 0))
				rune_stacks[rune_player_id] = rune_stack + 1
				_rune_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"player_id": rune_player_id,
					"threshold": int(event.get("threshold", -1)),
					"draw_card": bool(event.get("draw_card", false)),
					"stack_index": rune_stack,
					"expires_at_ms": now + RUNE_FEEDBACK_DURATION_MS,
				})


func _apply_presentation_feedback() -> void:
	_clear_feedback_overlays()
	for feedback in _attack_feedbacks:
		_apply_attack_feedback(feedback)
	for feedback in _damage_feedbacks:
		_apply_damage_feedback(feedback)
	for feedback in _removal_feedbacks:
		_apply_removal_feedback(feedback)
	for feedback in _draw_feedbacks:
		_apply_draw_feedback(feedback)
	for feedback in _rune_feedbacks:
		_apply_rune_feedback(feedback)


func _clear_feedback_overlays() -> void:
	for section in _player_sections.values():
		_clear_feedback_children(section.get("avatar_component"))
		_clear_feedback_children(section.get("hand_row"))
	for row_panel in _lane_row_panels.values():
		_clear_feedback_children(row_panel)


func _clear_feedback_children(node) -> void:
	if not (node is Node):
		return
	for child in (node as Node).get_children():
		if str(child.name).begins_with("feedback_"):
			child.queue_free()
		else:
			_clear_feedback_children(child)


func _apply_attack_feedback(feedback: Dictionary) -> void:
	var attacker_button: Button = _card_buttons.get(str(feedback.get("attacker_instance_id", "")))
	if attacker_button != null:
		_animate_card_motion(attacker_button, _attack_offset_for_player(str(feedback.get("attacker_player_id", ""))), 1.04)
		_add_feedback_banner(attacker_button, "feedback_attack_%s" % str(feedback.get("feedback_id", "0")), "ATTACK", Color(0.36, 0.2, 0.09, 0.98), Color(0.98, 0.78, 0.42, 1.0), Color(1.0, 0.96, 0.87, 1.0), 8.0)
	if str(feedback.get("target_type", "")) == MatchCombat.TARGET_TYPE_CREATURE:
		var defender_button: Button = _card_buttons.get(str(feedback.get("target_instance_id", "")))
		if defender_button != null:
			_animate_card_motion(defender_button, _attack_offset_for_player(str(feedback.get("attacker_player_id", ""))) * -0.38, 1.02)
			_add_feedback_banner(defender_button, "feedback_block_%s" % str(feedback.get("feedback_id", "0")), "BLOCK", Color(0.18, 0.18, 0.24, 0.98), Color(0.76, 0.82, 0.96, 0.96), Color(0.96, 0.98, 1.0, 1.0), 8.0)


func _apply_damage_feedback(feedback: Dictionary) -> void:
	var target_kind := str(feedback.get("target_kind", ""))
	if target_kind == MatchCombat.TARGET_TYPE_CREATURE:
		var target_button: Button = _card_buttons.get(str(feedback.get("target_instance_id", "")))
		if target_button != null:
			_add_feedback_popup(target_button, "feedback_damage_%s" % str(feedback.get("feedback_id", "0")), str(feedback.get("text", "-0")), feedback.get("color", Color(1, 1, 1, 1)), 10.0 + float(feedback.get("stack_index", 0)) * 18.0)
	elif target_kind == MatchCombat.TARGET_TYPE_PLAYER:
		var section: Dictionary = _player_sections.get(str(feedback.get("target_player_id", "")), {})
		var avatar: Control = section.get("avatar_component")
		if avatar != null:
			_add_feedback_popup(avatar, "feedback_damage_%s" % str(feedback.get("feedback_id", "0")), str(feedback.get("text", "-0")), feedback.get("color", Color(1, 1, 1, 1)), 12.0 + float(feedback.get("stack_index", 0)) * 18.0)


func _apply_removal_feedback(feedback: Dictionary) -> void:
	var row_key := _lane_row_key(str(feedback.get("lane_id", "")), str(feedback.get("player_id", "")))
	var row_panel: PanelContainer = _lane_row_panels.get(row_key)
	if row_panel == null:
		return
	var toast := PanelContainer.new()
	toast.name = "feedback_removal_%s" % str(feedback.get("feedback_id", "0"))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_right = 1.0
	toast.offset_left = 14
	toast.offset_right = -14
	toast.offset_top = 42.0 + float(feedback.get("stack_index", 0)) * 24.0
	toast.offset_bottom = toast.offset_top + 24.0
	toast.z_index = 20
	_apply_panel_style(toast, Color(0.32, 0.12, 0.12, 0.96), Color(0.96, 0.55, 0.46, 0.98), 1, 6)
	row_panel.add_child(toast)
	var toast_box := _build_panel_box(toast, 0, 4)
	var toast_label := Label.new()
	toast_label.name = "%s_label" % toast.name
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 11)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.92, 1.0))
	toast_label.text = str(feedback.get("text", "Creature removed"))
	toast_box.add_child(toast_label)
	var tween := create_tween()
	tween.tween_property(toast, "position", Vector2(0, -14), 0.2)
	tween.parallel().tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.8)
	tween.finished.connect(_queue_free_weak.bind(weakref(toast)))


func _apply_draw_feedback(feedback: Dictionary) -> void:
	var player_id := str(feedback.get("player_id", ""))
	var section: Dictionary = _player_sections.get(player_id, {})
	var avatar: Control = section.get("avatar_component")
	if avatar != null:
		_add_feedback_popup(avatar, "feedback_draw_popup_%s" % str(feedback.get("feedback_id", "0")), _draw_feedback_popup_text(feedback), _draw_feedback_popup_color(feedback), 14.0 + float(feedback.get("stack_index", 0)) * 18.0)
	var hand_row: Control = section.get("hand_row")
	if hand_row != null:
		_add_feedback_toast(hand_row, "feedback_draw_toast_%s" % str(feedback.get("feedback_id", "0")), _draw_feedback_toast_text(feedback), _draw_feedback_toast_fill(feedback), _draw_feedback_toast_border(feedback), Color(1.0, 0.97, 0.93, 1.0), 10.0 + float(feedback.get("stack_index", 0)) * 24.0)
	var drawn_instance_id := str(feedback.get("drawn_instance_id", ""))
	var card_button: Button = _card_buttons.get(drawn_instance_id)
	if card_button != null:
		_add_feedback_banner(card_button, "feedback_draw_banner_%s" % str(feedback.get("feedback_id", "0")), _draw_feedback_badge_text(feedback), _draw_feedback_toast_fill(feedback), _draw_feedback_toast_border(feedback), Color(1.0, 0.97, 0.92, 1.0), 8.0)


func _apply_rune_feedback(feedback: Dictionary) -> void:
	var player_id := str(feedback.get("player_id", ""))
	var section: Dictionary = _player_sections.get(player_id, {})
	var avatar_component = section.get("avatar_component")
	if avatar_component != null:
		_add_feedback_toast(avatar_component, "feedback_rune_toast_%s" % str(feedback.get("feedback_id", "0")), _rune_feedback_toast_text(feedback), Color(0.31, 0.13, 0.11, 0.98), Color(1.0, 0.73, 0.42, 1.0), Color(1.0, 0.95, 0.89, 1.0), 8.0 + float(feedback.get("stack_index", 0)) * 22.0)
		var token_panel = avatar_component.get_rune_anchor(int(feedback.get("threshold", -1)))
		if token_panel is Control:
			_add_feedback_banner_over_target(avatar_component as Control, token_panel as Control, "feedback_rune_banner_%s" % str(feedback.get("feedback_id", "0")), "SHATTER", Color(0.39, 0.14, 0.09, 0.99), Color(1.0, 0.78, 0.48, 1.0), Color(1.0, 0.96, 0.9, 1.0), 4.0)


func _apply_card_feedback_decoration(button: Button, card: Dictionary, surface: String) -> void:
	var instance_id := str(card.get("instance_id", ""))
	var modulate_color := Color(1, 1, 1, 1)
	var applied_damage := false
	if surface == "lane" and str(card.get("card_type", "")) == "creature":
		for feedback in _damage_feedbacks:
			if str(feedback.get("target_kind", "")) == MatchCombat.TARGET_TYPE_CREATURE and str(feedback.get("target_instance_id", "")) == instance_id:
				modulate_color = Color(1.0, 0.92, 0.92, 1.0)
				applied_damage = true
				break
	if surface == "hand":
		var draw_feedback := _active_draw_feedback_for_instance(instance_id)
		var can_reveal_draw := _should_reveal_drawn_card(str(card.get("controller_player_id", "")), card)
		if can_reveal_draw and not draw_feedback.is_empty():
			modulate_color = Color(1.0, 0.98, 0.94, 1.0) if bool(draw_feedback.get("from_rune_break", false)) else Color(0.95, 0.99, 1.0, 1.0)
			_add_feedback_banner(button, "feedback_hand_draw_%s" % instance_id, _draw_feedback_badge_text(draw_feedback), _draw_feedback_toast_fill(draw_feedback), _draw_feedback_toast_border(draw_feedback), Color(1.0, 0.97, 0.92, 1.0), 8.0)
		if _is_pending_prophecy_card(card):
			modulate_color = Color(1.0, 0.97, 1.0, 1.0)
			_add_feedback_banner(button, "feedback_hand_prophecy_%s" % instance_id, "PROPHECY", Color(0.28, 0.14, 0.34, 0.99), Color(0.94, 0.75, 0.98, 1.0), Color(1.0, 0.96, 1.0, 1.0), 30.0 if not applied_damage else 8.0)
	button.modulate = modulate_color


func _add_feedback_banner(container: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	var banner := PanelContainer.new()
	banner.name = name
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.anchor_right = 1.0
	banner.offset_left = 8
	banner.offset_right = -8
	banner.offset_top = top_offset
	banner.offset_bottom = top_offset + 20.0
	banner.z_index = 12
	_apply_panel_style(banner, fill, border, 1, 6)
	container.add_child(banner)
	var box := _build_panel_box(banner, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(_queue_free_weak.bind(weakref(banner)))


func _add_feedback_banner_over_target(container: Control, target: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	if container == null or target == null:
		return
	var target_origin := container.get_global_transform_with_canvas().affine_inverse() * target.get_global_transform_with_canvas().origin
	var banner_size := Vector2(maxf(target.size.x + 28.0, 54.0), 20.0)
	var banner_position := Vector2(target_origin.x + (target.size.x - banner_size.x) * 0.5, target_origin.y + top_offset)
	if container.size.x > 0.0:
		banner_position.x = clampf(banner_position.x, 0.0, maxf(container.size.x - banner_size.x, 0.0))
	if container.size.y > 0.0:
		banner_position.y = clampf(banner_position.y, 0.0, maxf(container.size.y - banner_size.y, 0.0))
	var banner := PanelContainer.new()
	banner.name = name
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.position = banner_position
	banner.size = banner_size
	banner.z_index = 12
	_apply_panel_style(banner, fill, border, 1, 6)
	container.add_child(banner)
	var box := _build_panel_box(banner, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(_queue_free_weak.bind(weakref(banner)))


func _add_feedback_popup(container: Control, name: String, text: String, font_color: Color, top_offset: float) -> void:
	var label := Label.new()
	label.name = name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_right = 1.0
	label.offset_left = 0
	label.offset_right = 0
	label.offset_top = top_offset
	label.offset_bottom = top_offset + 26.0
	label.z_index = 18
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	container.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", Vector2(0, -24), 0.22)
	tween.parallel().tween_property(label, "scale", Vector2(1.08, 1.08), 0.18)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.7)
	tween.finished.connect(_queue_free_weak.bind(weakref(label)))


func _add_feedback_toast(container: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	var toast := PanelContainer.new()
	toast.name = name
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_right = 1.0
	toast.offset_left = 12
	toast.offset_right = -12
	toast.offset_top = top_offset
	toast.offset_bottom = top_offset + 24.0
	toast.z_index = 18
	_apply_panel_style(toast, fill, border, 1, 7)
	container.add_child(toast)
	var box := _build_panel_box(toast, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.parallel().tween_property(toast, "position", Vector2(0, -10), 0.26)
	tween.tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.75)
	tween.finished.connect(_queue_free_weak.bind(weakref(toast)))


func _should_reveal_drawn_card(player_id: String, card: Dictionary) -> bool:
	if card.is_empty():
		return false
	if _is_hand_public(player_id):
		return true
	return _is_pending_prophecy_card(card)


func _active_draw_feedback_for_instance(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for feedback in _draw_feedbacks:
		if str(feedback.get("drawn_instance_id", "")) == instance_id:
			return feedback
	return {}


func _draw_feedback_popup_text(feedback: Dictionary) -> String:
	if bool(feedback.get("show_card_name", false)):
		return "+ %s" % str(feedback.get("card_name", "Card"))
	return "+1 CARD"


func _draw_feedback_popup_color(feedback: Dictionary) -> Color:
	return Color(1.0, 0.81, 0.48, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.72, 0.91, 1.0, 1.0)


func _draw_feedback_toast_text(feedback: Dictionary) -> String:
	var prefix := "RUNE DRAW" if bool(feedback.get("from_rune_break", false)) else "DRAW"
	if bool(feedback.get("show_card_name", false)):
		return "%s • %s" % [prefix, str(feedback.get("card_name", "Card"))]
	return "%s • card added to hand" % prefix


func _draw_feedback_toast_fill(feedback: Dictionary) -> Color:
	return Color(0.32, 0.16, 0.09, 0.98) if bool(feedback.get("from_rune_break", false)) else Color(0.14, 0.22, 0.31, 0.98)


func _draw_feedback_toast_border(feedback: Dictionary) -> Color:
	return Color(1.0, 0.79, 0.46, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.66, 0.9, 1.0, 1.0)


func _rune_feedback_toast_text(feedback: Dictionary) -> String:
	var threshold := int(feedback.get("threshold", -1))
	var draw_suffix := " • draw triggered" if bool(feedback.get("draw_card", false)) else ""
	if threshold > 0:
		return "RUNE %d SHATTERED%s" % [threshold, draw_suffix]
	return "RUNE BREAK%s" % draw_suffix


func _animate_card_motion(button: Button, offset: Vector2, end_scale: float) -> void:
	var content_variant = button.get_meta("content_root", null)
	if not (content_variant is Control):
		return
	var content := content_variant as Control
	content.pivot_offset = Vector2(button.custom_minimum_size.x * 0.5, button.custom_minimum_size.y * 0.5)
	content.position = Vector2.ZERO
	content.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(content, "position", offset, 0.11)
	tween.parallel().tween_property(content, "scale", Vector2(end_scale, end_scale), 0.11)
	tween.tween_property(content, "position", Vector2.ZERO, 0.16)
	tween.parallel().tween_property(content, "scale", Vector2.ONE, 0.16)


func _attack_offset_for_player(player_id: String) -> Vector2:
	return Vector2(0, 16) if player_id == PLAYER_ORDER[0] else Vector2(0, -16)


func _damage_target_key(event: Dictionary) -> String:
	var target_type := str(event.get("target_type", ""))
	if target_type == MatchCombat.TARGET_TYPE_PLAYER:
		return "player:%s" % str(event.get("target_player_id", ""))
	return "creature:%s" % str(event.get("target_instance_id", ""))


func _prune_feedback_state() -> void:
	var now := _feedback_now_ms()
	_attack_feedbacks = _feedbacks_after(_attack_feedbacks, now)
	_damage_feedbacks = _feedbacks_after(_damage_feedbacks, now)
	_removal_feedbacks = _feedbacks_after(_removal_feedbacks, now)
	_draw_feedbacks = _feedbacks_after(_draw_feedbacks, now)
	_rune_feedbacks = _feedbacks_after(_rune_feedbacks, now)


func _feedbacks_after(entries: Array, now: int) -> Array:
	var remaining: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if int(entry.get("expires_at_ms", 0)) > now:
			remaining.append(entry)
	return remaining


func _feedback_now_ms() -> int:
	return Time.get_ticks_msec()


func _next_feedback_id() -> int:
	_feedback_sequence += 1
	return _feedback_sequence


func _copy_array(value) -> Array:
	return value.duplicate() if typeof(value) == TYPE_ARRAY else []


func _card_from_instance_id(instance_id: String) -> Dictionary:
	if instance_id.is_empty() or _match_state.is_empty():
		return {}
	var location := MatchMutations.find_card_location(_match_state, instance_id)
	if bool(location.get("is_valid", false)):
		return location.get("card", {})
	for window in MatchTiming.get_pending_prophecies(_match_state):
		if str(window.get("instance_id", "")) == instance_id:
			return _find_card_in_player_hand(str(window.get("player_id", "")), instance_id)
	return {}


func _find_card_in_player_hand(player_id: String, instance_id: String) -> Dictionary:
	var player := _player_state(player_id)
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
			return card
	return {}


func _player_state(player_id: String) -> Dictionary:
	for player in _match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


func _active_player_id() -> String:
	return str(_match_state.get("active_player_id", ""))


func _local_player_id() -> String:
	return PLAYER_ORDER[1]


func _is_local_player_turn() -> bool:
	return _active_player_id() == _local_player_id()


func _should_dim_local_interaction_surfaces() -> bool:
	return not _is_local_player_turn() and not _is_local_prophecy_interrupt_open()


func _should_dim_local_surface(player_id: String) -> bool:
	return player_id == _local_player_id() and _should_dim_local_interaction_surfaces()


func _has_pending_prophecy_for_player(player_id: String) -> bool:
	return not MatchTiming.get_pending_prophecies(_match_state, player_id).is_empty()


func _is_local_prophecy_interrupt_open() -> bool:
	return _has_pending_prophecy_for_player(_local_player_id())


func _is_local_match_ai_enabled() -> bool:
	return _scenario_id == LOCAL_MATCH_AI_SCENARIO_ID


func _ai_player_id() -> String:
	return PLAYER_ORDER[0]


func _ai_controls_current_decision_window() -> bool:
	if not _is_local_match_ai_enabled() or _has_match_winner():
		return false
	if _is_local_prophecy_interrupt_open():
		return false
	var ai_player_id := _ai_player_id()
	if MatchTiming.has_pending_prophecy(_match_state):
		return _has_pending_prophecy_for_player(ai_player_id)
	return _active_player_id() == ai_player_id


func _target_lane_player_id() -> String:
	if _is_pending_prophecy_card(_selected_card()):
		return str(_selected_card().get("controller_player_id", ""))
	return _active_player_id()


func _player_name(player_id: String) -> String:
	var player := _player_state(player_id)
	if player.is_empty():
		return player_id
	return str(player.get("display_name", player_id))


func _turn_state_text() -> String:
	return "Your Turn" if _is_local_player_turn() else "Opponent's Turn"



func _turn_state_fill() -> Color:
	return Color(0.34, 0.19, 0.09, 0.98) if _is_local_player_turn() else Color(0.12, 0.17, 0.28, 0.97)


func _turn_state_border() -> Color:
	return Color(0.99, 0.78, 0.44, 1.0) if _is_local_player_turn() else Color(0.62, 0.81, 0.99, 0.98)


func _turn_state_font_color() -> Color:
	return Color(1.0, 0.96, 0.9, 1.0) if _is_local_player_turn() else Color(0.92, 0.96, 1.0, 1.0)


func _refresh_turn_presentation() -> void:
	var active_player := _active_player_id()
	if active_player.is_empty():
		return
	if active_player != _last_turn_owner_id:
		_last_turn_owner_id = active_player
		_turn_banner_until_ms = Time.get_ticks_msec() + TURN_BANNER_DURATION_MS
		if active_player == _ai_player_id() and _is_local_match_ai_enabled():
			_arm_local_match_ai_turn_pacing()
		else:
			_reset_local_match_ai_queue()
	if _turn_banner_panel != null:
		_apply_panel_style(_turn_banner_panel, _turn_state_fill(), _turn_state_border(), 2, 14)
		_turn_banner_panel.visible = _turn_banner_until_ms > Time.get_ticks_msec()
	if _turn_banner_label != null:
		_turn_banner_label.text = _turn_state_text()
		_turn_banner_label.add_theme_color_override("font_color", _turn_state_font_color())
	if _turn_banner_detail_label != null:
		_turn_banner_detail_label.text = _player_name(active_player)
		_turn_banner_detail_label.add_theme_color_override("font_color", _turn_state_font_color().lerp(Color(0.8, 0.84, 0.92, 0.96), 0.32))



func _refresh_match_end_overlay() -> void:
	if _match_end_overlay == null:
		return
	var winner_player_id := _match_winner_id()
	var visible := not winner_player_id.is_empty()
	_match_end_overlay.visible = visible
	if not visible:
		return
	var local_won := winner_player_id == _local_player_id()
	_apply_panel_style(_match_end_overlay, Color(0.04, 0.05, 0.07, 0.78), Color(0.88, 0.74, 0.44, 0.96) if local_won else Color(0.9, 0.42, 0.42, 0.96), 2, 18)
	if _match_end_title_label != null:
		_match_end_title_label.text = "Victory" if local_won else "Defeat"
		_match_end_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84, 1.0) if local_won else Color(1.0, 0.9, 0.9, 1.0))
	if _match_end_detail_label != null:
		_match_end_detail_label.text = _match_end_detail_text(winner_player_id)
		_match_end_detail_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.99, 0.96))


func _refresh_end_turn_button_style(has_pending_prophecy: bool) -> void:
	var fill := Color(0.18, 0.15, 0.16, 0.96)
	var border := Color(0.39, 0.36, 0.4, 0.88)
	var font_color := Color(0.82, 0.84, 0.88, 0.96)
	var border_width := 1
	var font_size := 17
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = Vector2(140, 54)
	_end_turn_button.self_modulate = Color(0.92, 0.92, 0.96, 0.95)
	if _has_match_winner():
		_end_turn_button.tooltip_text = "Match complete. No further turn actions are available."
	elif _is_local_player_turn() and not has_pending_prophecy:
		fill = Color(0.56, 0.2, 0.08, 0.99)
		border = Color(1.0, 0.76, 0.43, 1.0)
		font_color = Color(1.0, 0.97, 0.92, 1.0)
		border_width = 2
		font_size = 18
		_end_turn_button.custom_minimum_size = Vector2(140, 62)
		_end_turn_button.tooltip_text = "Your turn is live. End the turn when you are finished acting."
		_end_turn_button.self_modulate = Color(1, 1, 1, 1)
	elif has_pending_prophecy and _is_local_player_turn():
		_end_turn_button.tooltip_text = "Resolve the open Prophecy window before ending the turn."
	else:
		_end_turn_button.tooltip_text = "Unavailable while the opponent is taking their turn."
	_end_turn_button.add_theme_font_size_override("font_size", font_size)
	_apply_button_style(_end_turn_button, fill, border, font_color, border_width, 12)


func _has_match_winner() -> bool:
	return not _match_winner_id().is_empty()


func _match_winner_id() -> String:
	return str(_match_state.get("winner_player_id", ""))


func _match_end_detail_text(winner_player_id: String) -> String:
	if winner_player_id.is_empty():
		return ""
	var loser_player_id := PLAYER_ORDER[0] if winner_player_id == PLAYER_ORDER[1] else PLAYER_ORDER[1]
	if winner_player_id == _local_player_id():
		return "%s has fallen. %s wins the match." % [_player_name(loser_player_id), _player_name(winner_player_id)]
	return "%s wins the match. %s is out of actions." % [_player_name(winner_player_id), _player_name(_local_player_id())]



func _ring_summary(player: Dictionary) -> String:
	if not bool(player.get("has_ring_of_magicka", false)):
		return "None"
	return "%d charge(s)" % int(player.get("ring_of_magicka_charges", 0))


func _health_panel_fill(player: Dictionary, is_opponent: bool) -> Color:
	var health := int(player.get("health", 0))
	if health <= 10:
		return Color(0.36, 0.12, 0.12, 0.98)
	if is_opponent:
		return Color(0.31, 0.13, 0.12, 0.98)
	return Color(0.24, 0.12, 0.14, 0.98)


func _health_panel_border(player: Dictionary, is_opponent: bool) -> Color:
	var health := int(player.get("health", 0))
	if health <= 10:
		return Color(0.88, 0.4, 0.28, 0.98)
	return Color(0.74, 0.44, 0.28, 0.94) if is_opponent else Color(0.67, 0.46, 0.33, 0.94)


func _refresh_rune_row(rune_row: HBoxContainer, player: Dictionary, player_id: String, is_opponent: bool) -> void:
	_clear_children(rune_row)
	var remaining_runes: Array = player.get("rune_thresholds", [])
	for threshold in DISPLAY_RUNE_THRESHOLDS:
		rune_row.add_child(_build_rune_token(player_id, int(threshold), remaining_runes.has(threshold), is_opponent))


func _build_rune_token(player_id: String, threshold: int, active: bool, is_opponent: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "%s_rune_%d" % [player_id, threshold]
	panel.custom_minimum_size = Vector2(42, 28)
	var fill := Color(0.48, 0.18, 0.14, 0.98) if active else Color(0.12, 0.12, 0.14, 0.94)
	var border := Color(0.89, 0.69, 0.39, 0.96) if active else Color(0.31, 0.32, 0.37, 0.88)
	if is_opponent and active:
		fill = Color(0.45, 0.16, 0.13, 0.98)
	_apply_panel_style(panel, fill, border, 1, 8)
	var box := _build_panel_box(panel, 0, 4)
	var label := Label.new()
	label.text = str(threshold)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84, 0.98) if active else Color(0.62, 0.64, 0.7, 0.8))
	box.add_child(label)
	return panel


func _magicka_summary_text(player: Dictionary) -> String:
	var current := maxi(0, int(player.get("current_magicka", 0)))
	var max_magicka := maxi(0, int(player.get("max_magicka", 0)))
	var temporary := maxi(0, int(player.get("temporary_magicka", 0)))
	var text := "Magicka %d / %d" % [current, max_magicka]
	if temporary > 0:
		text += " • +%d temp" % temporary
	return text


func _ring_panel_text(_player: Dictionary) -> String:
	return "Ring of Magicka"


func _refresh_ring_row(ring_row: HBoxContainer, player: Dictionary) -> void:
	_clear_children(ring_row)
	var charges := maxi(0, mini(3, int(player.get("ring_of_magicka_charges", 0))))
	for index in range(3):
		ring_row.add_child(_build_ring_token(index, index < charges))


func _build_ring_token(index: int, active: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "ring_%d" % index
	panel.custom_minimum_size = Vector2(18, 18)
	_apply_panel_style(panel, Color(0.7, 0.57, 0.24, 0.98) if active else Color(0.12, 0.12, 0.14, 0.94), Color(0.96, 0.87, 0.58, 0.98) if active else Color(0.31, 0.3, 0.28, 0.86), 1, 9)
	return panel


func _pile_button_text(title: String, count: int) -> String:
	return "%s\n%d" % [title, count]


func _pile_button_tooltip(player: Dictionary, zone: String) -> String:
	var count: int = player.get(zone, []).size()
	if zone == MatchMutations.ZONE_DISCARD:
		return "%s's discard pile has %d card(s). Click to inspect public discard contents." % [_player_name(str(player.get("player_id", ""))), count]
	return "%s's deck has %d card(s) remaining. Click to inspect the count surface." % [_player_name(str(player.get("player_id", ""))), count]


func _lane_entries() -> Array:
	return _lane_registry.get("lanes", [
		{"id": "field", "display_name": "Field Lane", "description": "Default combat lane."},
		{"id": "shadow", "display_name": "Shadow Lane", "description": "New creatures gain Cover briefly here."},
	])


func _lane_name(lane_id: String) -> String:
	for lane in _lane_entries():
		if str(lane.get("id", "")) == lane_id:
			return str(lane.get("display_name", lane_id))
	return lane_id


func _lane_description(lane_id: String) -> String:
	for lane in _lane_entries():
		if str(lane.get("id", "")) == lane_id:
			return str(lane.get("description", lane_id))
	return lane_id


func _lane_header_text(lane_id: String) -> String:
	var occupancy: Array = []
	for player_id in PLAYER_ORDER:
		occupancy.append("%s %d" % [_player_name(player_id), _occupied_slots(lane_id, player_id)])
	return "%s\n%s" % [_lane_name(lane_id), _join_parts(occupancy, " | ")]


func _lane_slots(lane_id: String, player_id: String) -> Array:
	for lane in _match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == lane_id:
			return lane.get("player_slots", {}).get(player_id, [])
	return []


func _lane_slot_capacity(lane_id: String) -> int:
	for lane in _match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == lane_id:
			return int(lane.get("slot_capacity", 0))
	return 0


func _occupied_slots(lane_id: String, player_id: String) -> int:
	return _lane_slots(lane_id, player_id).size()


func _first_open_slot_index(lane_id: String, player_id: String) -> int:
	var slots := _lane_slots(lane_id, player_id)
	var slot_capacity := _lane_slot_capacity(lane_id)
	if slots.size() < slot_capacity:
		return slots.size()
	return -1


func _is_hand_public(player_id: String) -> bool:
	return player_id == PLAYER_ORDER[1]


func _is_pending_prophecy_card(card: Dictionary) -> bool:
	if card.is_empty():
		return false
	for window in MatchTiming.get_pending_prophecies(_match_state, str(card.get("controller_player_id", ""))):
		if str(window.get("instance_id", "")) == str(card.get("instance_id", "")):
			return true
	return false


func _pending_prophecy_player_id(instance_id: String) -> String:
	for window in MatchTiming.get_pending_prophecies(_match_state):
		if str(window.get("instance_id", "")) == instance_id:
			return str(window.get("player_id", ""))
	return ""


func _selection_prompt(card: Dictionary) -> String:
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	if _is_pending_prophecy_card(card):
		return "Selected %s. It is pending Prophecy; play it for free or keep it in hand." % _card_name(card)
	if not bool(location.get("is_valid", false)):
		return "Inspecting %s." % _card_name(card)
	match str(location.get("zone", "")):
		MatchMutations.ZONE_HAND:
			match str(card.get("card_type", "")):
				"creature":
					return "Selected %s. Click a friendly lane slot to summon it." % _card_name(card)
				"item":
					return "Selected %s. Click a friendly creature to equip it." % _card_name(card)
				"support":
					return "Selected %s. Click your support row to place it." % _card_name(card)
				_:
					return "Selected %s." % _card_name(card)
		MatchMutations.ZONE_SUPPORT:
				return "Selected %s. Click a target to activate it." % _card_name(card)
		MatchMutations.ZONE_LANE:
			return "Selected %s. Click an opposing creature or player to attack if legal." % _card_name(card)
		_:
			return "Selected %s." % _card_name(card)


func _card_name(card: Dictionary) -> String:
	if card.is_empty():
		return "Unknown Card"
	var name := str(card.get("name", ""))
	if not name.is_empty():
		return name
	return _identifier_to_name(str(card.get("definition_id", card.get("instance_id", "card"))))


func _card_button_text(card: Dictionary, public_view: bool) -> String:
	if not public_view and not _is_pending_prophecy_card(card):
		return "Hidden Card"
	var lines: Array = []
	var prefix := "▶ " if str(card.get("instance_id", "")) == _selected_instance_id else ""
	lines.append("%s%s" % [prefix, _card_name(card)])
	lines.append("Cost %d | %s" % [int(card.get("cost", 0)), str(card.get("card_type", "")).capitalize()])
	if str(card.get("card_type", "")) == "creature":
		lines.append("%d / %d" % [EvergreenRules.get_power(card), EvergreenRules.get_remaining_health(card)])
	var tags := _card_tag_text(card)
	if not tags.is_empty():
		lines.append(tags)
	return _join_parts(lines, "\n")


func _card_tooltip(card: Dictionary, public_view: bool) -> String:
	if not public_view and not _is_pending_prophecy_card(card):
		return "Opponent hand card. Full details are hidden until it becomes public."
	return _card_inspector_text(card)


func _card_inspector_text(card: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s" % _card_name(card))
	lines.append("Type %s | Cost %d" % [str(card.get("card_type", "")).capitalize(), int(card.get("cost", 0))])
	if str(card.get("card_type", "")) == "creature":
		lines.append("Power %d | Health %d" % [EvergreenRules.get_power(card), EvergreenRules.get_remaining_health(card)])
	lines.append("Zone %s | Controller %s" % [str(card.get("zone", "unknown")), _player_name(str(card.get("controller_player_id", "")))])
	var tags := _card_tag_text(card)
	if not tags.is_empty():
		lines.append("Tags: %s" % tags)
	var attached_items: Array = card.get("attached_items", [])
	if attached_items.size() > 0:
		var names: Array = []
		for item in attached_items:
			if typeof(item) == TYPE_DICTIONARY:
				names.append(_card_name(item))
		lines.append("Attached: %s" % _join_parts(names, ", "))
	var rules_text := str(card.get("rules_text", ""))
	if not rules_text.is_empty():
		lines.append("Rules: %s" % rules_text)
	return _join_parts(lines, "\n")


func _card_tag_text(card: Dictionary) -> String:
	var terms: Array = []
	for keyword in card.get("keywords", []):
		terms.append(_term_label(str(keyword)))
	for keyword in card.get("granted_keywords", []):
		terms.append(_term_label(str(keyword)))
	for status in card.get("status_markers", []):
		var status_id := str(status)
		if status_id == EvergreenRules.STATUS_COVER and not EvergreenRules.is_cover_active(_match_state, card):
			continue
		terms.append(_term_label(status_id))
	for rule_tag in card.get("rules_tags", []):
		terms.append(_term_label(str(rule_tag)))
	return _join_parts(_unique_terms(terms), ", ")


func _term_label(term_id: String) -> String:
	if _keyword_display_names.has(term_id):
		return str(_keyword_display_names[term_id])
	if _status_display_names.has(term_id):
		return str(_status_display_names[term_id])
	if HELP_TEXT.has(term_id):
		return _identifier_to_name(term_id)
	return _identifier_to_name(term_id)




func _history_text_value() -> String:
	var lines: Array = []
	for event in _match_state.get("event_log", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		lines.append(_format_event_line(event))
	if lines.is_empty():
		return "No processed events yet."
	return _join_parts(lines, "\n")


func _replay_text_value() -> String:
	var lines: Array = []
	for entry in _match_state.get("replay_log", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_type := str(entry.get("entry_type", "entry"))
		var summary := [entry_type]
		if entry.has("family"):
			summary.append(str(entry.get("family", "")))
		if entry.has("event_type"):
			summary.append(str(entry.get("event_type", "")))
		if entry.has("source_instance_id"):
			summary.append(str(entry.get("source_instance_id", "")))
		lines.append("- %s" % _join_parts(summary, " | "))
	if lines.is_empty():
		return "No replay entries yet."
	return _join_parts(lines, "\n")


func _format_event_line(event: Dictionary) -> String:
	var parts: Array = [str(event.get("event_type", "event"))]
	for field in ["source_instance_id", "target_instance_id", "player_id", "lane_id", "reason"]:
		var value := str(event.get(field, ""))
		if not value.is_empty():
			parts.append("%s=%s" % [field, value])
	return "- %s" % _join_parts(parts, " | ")


func _scenario_label(scenario_id: String) -> String:
	for scenario in MatchDebugScenarios.list_scenarios():
		if str(scenario.get("id", "")) == scenario_id:
			return str(scenario.get("label", scenario_id))
	return scenario_id


func _identifier_to_name(value: String) -> String:
	var parts := value.replace("_", " ").split(" ", false)
	var titled: Array = []
	for part in parts:
		if part.is_empty():
			continue
		titled.append(part.substr(0, 1).to_upper() + part.substr(1))
	return _join_parts(titled, " ")


func _is_local_hand_card(instance_id: String) -> bool:
	var location := MatchMutations.find_card_location(_match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return false
	return str(location.get("zone", "")) == MatchMutations.ZONE_HAND and str(location.get("player_id", "")) == PLAYER_ORDER[1]


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


func _detach_prophecy_card(instance_id: String) -> void:
	_cancel_detached_card_silent()
	_selected_instance_id = instance_id
	var card := _card_from_instance_id(instance_id)
	var preview_size := _hand_card_display_size()
	var base_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "detached_prophecy_card_%s" % instance_id
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
	# Hide the prophecy overlay while dragging — it rebuilds on cancel via _refresh_ui
	var vbox: Control = _prophecy_overlay_state.get("vbox")
	if vbox != null and is_instance_valid(vbox):
		vbox.visible = false
	_status_message = "Click a friendly lane slot to summon %s." % _card_name(card)
	_refresh_ui()


func _enter_prophecy_targeting_mode(instance_id: String) -> void:
	_cancel_targeting_mode_silent()
	_selected_instance_id = instance_id
	var card := _card_from_instance_id(instance_id)
	# Use the prophecy card wrapper position as arrow origin
	var card_wrapper: Control = _prophecy_overlay_state.get("card_wrapper")
	var arrow_origin := Vector2.ZERO
	if card_wrapper != null and is_instance_valid(card_wrapper):
		var card_size := card_wrapper.size
		arrow_origin = card_wrapper.global_position + Vector2(card_size.x * 0.5, 0.0)
	else:
		var viewport_size := get_viewport_rect().size
		arrow_origin = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5)
	_targeting_arrow = _create_targeting_arrow()
	_targeting_arrow_state = {
		"instance_id": instance_id,
		"origin": arrow_origin,
		"button": null,
	}
	_status_message = "Select a target for %s." % _card_name(card)
	_refresh_ui()


func _cancel_detached_card() -> void:
	_clear_insertion_preview()
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}
	_selected_instance_id = ""
	_refresh_ui()


func _cancel_detached_card_silent() -> void:
	_clear_insertion_preview()
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}


func _update_insertion_preview_from_mouse(mouse_pos: Vector2) -> void:
	var card := _selected_card()
	if card.is_empty() or _selected_action_mode(card) != SELECTION_MODE_SUMMON:
		_clear_insertion_preview()
		return
	var target_player := _target_lane_player_id()
	var found_lane := ""
	var found_row: HBoxContainer = null
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var row_key := _lane_row_key(lane_id, target_player)
		var row_panel: PanelContainer = _lane_row_panels.get(row_key)
		if row_panel == null or not is_instance_valid(row_panel):
			continue
		var panel_rect := Rect2(row_panel.global_position, row_panel.size)
		if panel_rect.has_point(mouse_pos):
			var slots := _lane_slots(lane_id, target_player)
			var slot_capacity := _lane_slot_capacity(lane_id)
			if slots.size() < slot_capacity:
				found_lane = lane_id
				found_row = _lane_row_containers.get(row_key)
			break
	if found_lane.is_empty() or found_row == null:
		_clear_insertion_preview()
		return
	var insertion_index := _compute_insertion_index(found_row, mouse_pos.x)
	_set_insertion_preview(found_lane, target_player, insertion_index, found_row)


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


func _set_insertion_preview(lane_id: String, player_id: String, index: int, row: HBoxContainer) -> void:
	if not _insertion_preview.is_empty():
		if str(_insertion_preview.get("lane_id", "")) == lane_id and str(_insertion_preview.get("player_id", "")) == player_id and int(_insertion_preview.get("index", -1)) == index:
			return
		_clear_insertion_preview()
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


func _clear_insertion_preview() -> void:
	if _insertion_preview.is_empty():
		return
	var spacer: Control = _insertion_preview.get("spacer")
	var tween: Tween = _insertion_preview.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	if spacer != null and is_instance_valid(spacer):
		if spacer.get_parent() != null:
			spacer.get_parent().remove_child(spacer)
		spacer.queue_free()
	_insertion_preview = {}


func _get_insertion_index_or_default(lane_id: String, player_id: String) -> int:
	if not _insertion_preview.is_empty() and str(_insertion_preview.get("lane_id", "")) == lane_id and str(_insertion_preview.get("player_id", "")) == player_id:
		return int(_insertion_preview.get("index", -1))
	return _first_open_slot_index(lane_id, player_id)


func _create_targeting_arrow() -> Line2D:
	var arrow := Line2D.new()
	arrow.width = 6.0
	arrow.default_color = Color(1.0, 0.85, 0.2, 0.9)
	arrow.z_index = 500
	arrow.antialiased = true
	add_child(arrow)
	return arrow


func _update_targeting_arrow(mouse_pos: Vector2) -> void:
	if _targeting_arrow == null or not is_instance_valid(_targeting_arrow):
		return
	var origin: Vector2 = _targeting_arrow_state.get("origin", Vector2.ZERO)
	var start := origin
	var end_point := mouse_pos
	var mid := (start + end_point) * 0.5
	var diff := end_point - start
	var perp := Vector2(-diff.y, diff.x).normalized()
	var control := mid + perp * diff.length() * 0.25
	var points := PackedVector2Array()
	var segments := 20
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := (1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * control + t * t * end_point
		points.append(p)
	# Arrowhead
	var tip := points[points.size() - 1]
	var prev := points[points.size() - 2]
	var arrow_dir := (tip - prev).normalized()
	var arrow_perp := Vector2(-arrow_dir.y, arrow_dir.x)
	var arrow_size := 14.0
	points.append(tip - arrow_dir * arrow_size + arrow_perp * arrow_size * 0.5)
	points.append(tip)
	points.append(tip - arrow_dir * arrow_size - arrow_perp * arrow_size * 0.5)
	points.append(tip)
	_targeting_arrow.points = points


func _enter_targeting_mode(instance_id: String) -> void:
	_cancel_targeting_mode_silent()
	select_card(instance_id)
	var button: Button = _card_buttons.get(instance_id)
	if button == null:
		return
	# Card is now raised because select_card sets _selected_instance_id and _refresh_ui
	# applies the raised state. Set mouse_filter to ignore so the card doesn't intercept clicks.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_pos := button.global_position
	var card_size: Vector2 = button.get_meta("card_size", button.size)
	var arrow_origin := card_pos + Vector2(card_size.x * 0.5, 0.0)
	_targeting_arrow = _create_targeting_arrow()
	_targeting_arrow_state = {
		"instance_id": instance_id,
		"origin": arrow_origin,
		"button": button,
	}


func _play_action_to_lane(lane_id: String) -> void:
	var card := _selected_card()
	if card.is_empty():
		return
	var options := {"lane_id": lane_id}
	var result := MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id, options)
	_finalize_engine_result(result, "Played %s." % _card_name(card))


func _cancel_targeting_mode() -> void:
	if _targeting_arrow != null and is_instance_valid(_targeting_arrow):
		_targeting_arrow.queue_free()
	_targeting_arrow = null
	_targeting_arrow_state = {}
	_selected_instance_id = ""
	_refresh_ui()


func _cancel_targeting_mode_silent() -> void:
	if _targeting_arrow != null and is_instance_valid(_targeting_arrow):
		_targeting_arrow.queue_free()
	_targeting_arrow = null
	_targeting_arrow_state = {}


func _queue_free_weak(node_ref: WeakRef) -> void:
	var node = node_ref.get_ref()
	if node != null and is_instance_valid(node):
		node.queue_free()


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
	if _is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id)
		return _finalize_engine_result(result, "Played %s into %s's support row." % [_card_name(card), _player_name(player_id)])
	result = PersistentCardRules.play_support_from_hand(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id)
	return _finalize_engine_result(result, "Placed %s into %s's support row." % [_card_name(card), _player_name(player_id)])




func _first_valid_lane_slot_index(lane_id: String, player_id: String) -> int:
	for slot_index in range(_lane_slots(lane_id, player_id).size()):
		if bool(_validate_selected_lane_play(lane_id, player_id, slot_index).get("is_valid", false)):
			return slot_index
	return -1


func _lane_slot_key(lane_id: String, player_id: String, slot_index: int) -> String:
	return "%s:%s:%d" % [lane_id, player_id, slot_index]


func _lane_row_key(lane_id: String, player_id: String) -> String:
	return "%s:%s" % [lane_id, player_id]


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _unique_terms(values: Array) -> Array:
	var unique: Array = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique


func _join_parts(values: Array, separator: String) -> String:
	if values.is_empty():
		return ""
	var strings := PackedStringArray()
	for value in values:
		strings.append(str(value))
	return separator.join(strings)
