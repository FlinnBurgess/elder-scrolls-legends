class_name MatchScreenTargeting
extends RefCounted

var _screen  # MatchScreen reference
var _targeting_arrow_state := {}
var _pending_summon_target := {}
var _pending_secondary_target_state := {}
var _attack_arrow_state := {}
var _support_arrow_state := {}
var _vision_card_overlay: Control = null

func _init(screen) -> void:
	_screen = screen


func target_selected_card(target_instance_id: String) -> Dictionary:
	var selected_card = _screen._selected_card()
	if selected_card.is_empty():
		return _screen._invalid_ui_result("Select a card first.")
	if not _screen._can_resolve_selected_action(selected_card):
		return _screen._invalid_ui_result(_screen._status_message)
	var target_location = _screen.MatchMutations.find_card_location(_screen._match_state, target_instance_id)
	if not bool(target_location.get("is_valid", false)):
		return _screen._invalid_ui_result("Target %s is not on the board." % target_instance_id)
	var target_card: Dictionary = target_location.get("card", {})
	var selected_location = _screen.MatchMutations.find_card_location(_screen._match_state, _screen._selected_instance_id)
	var saved_item_id := ""
	var saved_action_id := ""
	var saved_action_card := {}
	var result := {}
	if bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == _screen.MatchMutations.ZONE_HAND and str(selected_card.get("card_type", "")) == "item":
		saved_item_id = _screen._selected_instance_id
		if _screen._is_pending_prophecy_card(selected_card):
			result = _screen.MatchTiming.play_pending_prophecy(_screen._match_state, str(selected_card.get("controller_player_id", "")), _screen._selected_instance_id, {"target_instance_id": target_instance_id})
		else:
			result = _screen.PersistentCardRules.play_item_from_hand(_screen._match_state, _screen._active_player_id(), _screen._selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == _screen.MatchMutations.ZONE_HAND and str(selected_card.get("card_type", "")) == "action":
		saved_action_id = _screen._selected_instance_id
		saved_action_card = selected_card.duplicate(true)
		if _screen._check_exalt_action(selected_card, {"target_instance_id": target_instance_id}, _screen._is_pending_prophecy_card(selected_card)):
			return {"is_valid": true}
		if _screen._is_pending_prophecy_card(selected_card):
			result = _screen.MatchTiming.play_pending_prophecy(_screen._match_state, str(selected_card.get("controller_player_id", "")), _screen._selected_instance_id, {"target_instance_id": target_instance_id})
		else:
			result = _screen.MatchTiming.play_action_from_hand(_screen._match_state, _screen._active_player_id(), _screen._selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == _screen.MatchMutations.ZONE_SUPPORT:
		result = _screen.PersistentCardRules.activate_support(_screen._match_state, _screen._active_player_id(), _screen._selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == _screen.MatchMutations.ZONE_LANE:
		result = _screen.MatchCombat.resolve_attack(_screen._match_state, _screen._active_player_id(), _screen._selected_instance_id, {"type": "creature", "instance_id": target_instance_id})
	else:
		return _screen._invalid_ui_result("Current selection does not use card targets.")
	var finalized = _screen._finalize_engine_result(result, "Resolved %s onto %s." % [_screen._card_name(selected_card), _screen._card_name(target_card)])
	if bool(finalized.get("is_valid", false)) and not saved_action_id.is_empty():
		_screen._check_betray_mode(saved_action_id, saved_action_card)
	return finalized


func attack_selected_player(player_id: String) -> Dictionary:
	var selected_card = _screen._selected_card()
	if selected_card.is_empty():
		return _screen._invalid_ui_result("Select an attacking creature first.")
	if not _screen._can_resolve_selected_action(selected_card):
		return _screen._invalid_ui_result(_screen._status_message)
	var result = _screen.MatchCombat.resolve_attack(_screen._match_state, _screen._active_player_id(), _screen._selected_instance_id, {"type": "player", "player_id": player_id})
	return _screen._finalize_engine_result(result, "%s attacked %s." % [_screen._card_name(selected_card), _screen._player_name(player_id)])


func _action_needs_explicit_target(card: Dictionary) -> bool:
	var atm := str(card.get("action_target_mode", ""))
	if not atm.is_empty() and atm != "choose_lane":
		return true
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		var tm := str(trigger.get("target_mode", ""))
		if not tm.is_empty() and tm != "creature_in_hand" and tm != "two_creatures" and tm != "three_creatures":
			if not str(trigger.get("secondary_target_mode", "")).is_empty():
				continue  # Dual-target actions go through pending system
			return true
		for effect in trigger.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var target := str(effect.get("target", ""))
			var source_target := str(effect.get("source_target", ""))
			var consumer_target := str(effect.get("consumer_target", ""))
			if target == "event_target" or source_target == "event_target" or consumer_target == "event_target":
				return true
			if str(effect.get("target_player", "")) == "target_player":
				return true
	return false


func _action_target_mode_allows(action_card: Dictionary, target_instance_id: String) -> bool:
	var atm := str(action_card.get("action_target_mode", ""))
	if atm.is_empty():
		return true  # No restriction
	var controller_id := str(action_card.get("controller_player_id", ""))
	var target_card = _screen._card_from_instance_id(target_instance_id)
	if target_card.is_empty():
		return false
	# action_immune: opponent's actions cannot target this creature
	if str(target_card.get("controller_player_id", "")) != controller_id and _screen.EvergreenRules.has_raw_status(target_card, "action_immune"):
		return false
	var target_controller := str(target_card.get("controller_player_id", ""))
	var mode_allowed := true
	match atm:
		"friendly_creature", "another_friendly_creature":
			mode_allowed = target_controller == controller_id
		"enemy_creature":
			mode_allowed = target_controller != controller_id
		"wounded_enemy_creature":
			mode_allowed = target_controller != controller_id and _screen.EvergreenRules.has_status(target_card, _screen.EvergreenRules.STATUS_WOUNDED)
		"wounded_creature":
			mode_allowed = _screen.EvergreenRules.has_status(target_card, _screen.EvergreenRules.STATUS_WOUNDED)
		"any_creature", "another_creature":
			mode_allowed = true
		"enemy_support_or_neutral_creature":
			if target_controller == controller_id:
				mode_allowed = false
			else:
				var attrs: Array = target_card.get("attributes", [])
				mode_allowed = typeof(attrs) == TYPE_ARRAY and attrs.has("neutral")
		"enemy_creature_or_support":
			mode_allowed = target_controller != controller_id
		"choose_lane":
			mode_allowed = true  # Lane targeting handled by _on_lane_pressed
		"creature_1_power_or_less":
			mode_allowed = _screen.EvergreenRules.get_power(target_card) <= 1
		"creature_4_power_or_less":
			mode_allowed = _screen.EvergreenRules.get_power(target_card) <= 4
		"creature_4_power_or_more":
			mode_allowed = _screen.EvergreenRules.get_power(target_card) >= 4
		"creature_with_0_power":
			mode_allowed = _screen.EvergreenRules.get_power(target_card) == 0
		"enemy_creature_3_power_or_less":
			mode_allowed = target_controller != controller_id and _screen.EvergreenRules.get_power(target_card) <= 3
		"enemy_creature_and_friendly_creature":
			mode_allowed = true
		"friendly_creature_then_enemy_creature":
			mode_allowed = true
		"any_creature_or_player":
			mode_allowed = true
	if not mode_allowed:
		return false
	# Check triggered_abilities for additional conditions
	for trigger in action_card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		if bool(trigger.get("required_friendly_higher_power", false)):
			var target_power = _screen.EvergreenRules.get_power(target_card)
			var has_higher := false
			for lane in _screen._match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(controller_id, []):
					if typeof(card) == TYPE_DICTIONARY and _screen.EvergreenRules.get_power(card) > target_power:
						has_higher = true
						break
				if has_higher:
					break
			if not has_higher:
				return false
	return true


func _selected_support_uses_card_targets(card: Dictionary) -> bool:
	if card.is_empty() or _screen._selected_action_mode(card) != _screen.SELECTION_MODE_SUPPORT or _screen._is_pending_prophecy_card(card):
		return false
	var location = _screen.MatchMutations.find_card_location(_screen._match_state, str(card.get("instance_id", "")))
	if not (bool(location.get("is_valid", false)) and str(location.get("zone", "")) == _screen.MatchMutations.ZONE_SUPPORT):
		return false
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY or str(trigger.get("family", "")) != "activate":
			continue
		var tm := str(trigger.get("target_mode", ""))
		if not tm.is_empty() and tm != "creature_in_hand" and tm != "choose_lane_and_owner":
			return true
		for effect in trigger.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var target := str(effect.get("target", ""))
			var source_target := str(effect.get("source_target", ""))
			var consumer_target := str(effect.get("consumer_target", ""))
			if target == "event_target" or source_target == "event_target" or consumer_target == "event_target":
				return true
	return false


func _get_activate_target_mode(card: Dictionary) -> String:
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY or str(trigger.get("family", "")) != "activate":
			continue
		var tm := str(trigger.get("target_mode", ""))
		if not tm.is_empty():
			return tm
	return ""


func _update_targeting_arrow(mouse_pos: Vector2) -> void:
	if _screen._targeting_arrow == null or not is_instance_valid(_screen._targeting_arrow):
		return
	# Dynamically compute origin from the card button's current position so the
	# arrow tracks the card through tween animations and layout changes.
	var origin: Vector2 = _targeting_arrow_state.get("origin", Vector2.ZERO)
	var arrow_instance_id: String = str(_targeting_arrow_state.get("instance_id", ""))
	var arrow_button: Button = _screen._card_buttons.get(arrow_instance_id)
	# For attached items (no own button), track the host creature's button instead.
	if arrow_button == null and not _screen._host_arrow_instance_id.is_empty():
		arrow_button = _screen._card_buttons.get(_screen._host_arrow_instance_id)
	if arrow_button != null and is_instance_valid(arrow_button):
		var card_size: Vector2 = arrow_button.get_meta("card_size", arrow_button.size)
		origin = arrow_button.global_position + Vector2(card_size.x * 0.5, 0.0)
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
	_screen._targeting_arrow.points = points


func _play_action_to_lane(lane_id: String) -> void:
	var card = _screen._selected_card()
	if card.is_empty():
		return
	# Check for exalt prompt before committing the play
	if _screen._check_exalt_action(card, {"lane_id": lane_id}, _screen._is_pending_prophecy_card(card)):
		return
	var saved_instance_id = _screen._selected_instance_id
	var saved_card: Dictionary = card.duplicate(true)
	var options := {"lane_id": lane_id}
	var result := {}
	if _screen._is_pending_prophecy_card(card):
		result = _screen.MatchTiming.play_pending_prophecy(_screen._match_state, str(card.get("controller_player_id", "")), _screen._selected_instance_id, options)
	else:
		result = _screen.MatchTiming.play_action_from_hand(_screen._match_state, _screen._active_player_id(), _screen._selected_instance_id, options)
	var finalized = _screen._finalize_engine_result(result, "Played %s." % _screen._card_name(card))
	if bool(finalized.get("is_valid", false)):
		_screen._check_betray_mode(saved_instance_id, saved_card)


func _play_mobilize_item_to_lane(lane_id: String) -> void:
	var card = _screen._selected_card()
	if card.is_empty():
		return
	var saved_instance_id = _screen._selected_instance_id
	_screen._cancel_targeting_mode()
	var result = _screen.PersistentCardRules.play_item_from_hand(_screen._match_state, _screen._active_player_id(), saved_instance_id, {"lane_id": lane_id})
	var finalized = _screen._finalize_engine_result(result, "Mobilized %s." % _screen._card_name(card))
	if not bool(finalized.get("is_valid", false)):
		_screen._report_invalid_interaction(str(finalized.get("message", "Cannot Mobilize here.")), {"lane_ids": [lane_id]})


func _cancel_targeting_mode_silent() -> void:
	if _screen._targeting_arrow != null and is_instance_valid(_screen._targeting_arrow):
		_screen._targeting_arrow.queue_free()
	_screen._targeting_arrow = null
	_targeting_arrow_state = {}
	_screen._host_arrow_instance_id = ""


# --- Summon target choice ---


func _check_summon_target_mode(source_instance_id: String) -> void:
	var card = _screen._card_from_instance_id(source_instance_id)
	if card.is_empty():
		return
	var abilities = _screen.MatchTiming.get_target_mode_abilities(card)
	# Filter to summon/on_play families and wax/wane (phase-gated).
	# Exclude consume: true abilities — those are handled by pending_consume_selections.
	var active_phases = _screen._get_wax_wane_phases_for_card(card)
	abilities = abilities.filter(func(ab):
		if bool(ab.get("consume", false)):
			return false
		if not _screen.MatchTiming._summon_ability_conditions_met(_screen._match_state, card, ab):
			return false
		var family := str(ab.get("family", ""))
		if family == _screen.MatchTiming.FAMILY_SUMMON or family == _screen.MatchTiming.FAMILY_ON_PLAY:
			return true
		if family == _screen.MatchTiming.FAMILY_WAX:
			return active_phases.has("wax")
		if family == _screen.MatchTiming.FAMILY_WANE:
			return active_phases.has("wane")
		return false
	)
	if abilities.is_empty():
		return
	var valid_targets = _screen.MatchTiming.get_all_valid_targets(_screen._match_state, source_instance_id)
	if valid_targets.is_empty():
		return  # Fizzle silently — no valid targets
	_pending_summon_target = {
		"source_instance_id": source_instance_id,
	}
	_screen._selected_instance_id = source_instance_id
	_screen._enter_targeting_mode(source_instance_id)
	_screen._status_message = _summon_target_prompt(card, abilities)
	if not _is_pending_summon_mandatory():
		_show_summon_skip_button()
	_screen._refresh_ui()


func _resolve_summon_target_card(target_instance_id: String) -> void:
	var source_id := str(_pending_summon_target.get("source_instance_id", ""))
	var _rst_choice_tm := str(_pending_summon_target.get("_choice_target_mode", ""))
	var valid_targets: Array
	if not _rst_choice_tm.is_empty():
		valid_targets = _screen.MatchTiming.get_valid_targets_for_mode(_screen._match_state, source_id, _rst_choice_tm, {})
	else:
		valid_targets = _screen.MatchTiming.get_all_valid_targets(_screen._match_state, source_id)
	var is_valid := false
	for t in valid_targets:
		if str(t.get("instance_id", "")) == target_instance_id:
			is_valid = true
			break
	if not is_valid:
		_screen._report_invalid_interaction("Not a valid target.", {"instance_ids": [target_instance_id]})
		return
	var is_effect_summon := bool(_pending_summon_target.get("is_effect_summon", false))
	var is_turn_trigger := bool(_pending_summon_target.get("is_turn_trigger", false))
	_pending_summon_target = {}
	_dismiss_summon_skip_button()
	_dismiss_vision_card_overlay()
	_cancel_targeting_mode_silent()
	if is_turn_trigger:
		var result = _screen.MatchTiming.resolve_pending_turn_trigger_target(_screen._match_state, _screen._local_player_id(), {"instance_id": target_instance_id})
		_screen._finalize_engine_result(result, "Targeted %s." % _screen._card_name(_screen._card_from_instance_id(target_instance_id)))
		_screen._check_pending_turn_trigger_target()
	elif is_effect_summon:
		var result = _screen.MatchTiming.resolve_pending_summon_effect_target(_screen._match_state, _screen._local_player_id(), {"target_instance_id": target_instance_id})
		_screen._finalize_engine_result(result, "Targeted %s." % _screen._card_name(_screen._card_from_instance_id(target_instance_id)))
		_screen._check_deferred_betray()
	else:
		var result = _screen.MatchTiming.resolve_targeted_effect(_screen._match_state, source_id, {"target_instance_id": target_instance_id})
		_screen._finalize_engine_result(result, "Targeted %s." % _screen._card_name(_screen._card_from_instance_id(target_instance_id)))
		_check_pending_summon_effect_target()
		_screen._check_deferred_betray()


func _resolve_summon_target_player(player_id: String) -> void:
	var source_id := str(_pending_summon_target.get("source_instance_id", ""))
	var _rstp_choice_tm := str(_pending_summon_target.get("_choice_target_mode", ""))
	var valid_targets: Array
	if not _rstp_choice_tm.is_empty():
		valid_targets = _screen.MatchTiming.get_valid_targets_for_mode(_screen._match_state, source_id, _rstp_choice_tm, {})
	else:
		valid_targets = _screen.MatchTiming.get_all_valid_targets(_screen._match_state, source_id)
	var is_valid := false
	for t in valid_targets:
		if str(t.get("player_id", "")) == player_id:
			is_valid = true
			break
	if not is_valid:
		_screen._report_invalid_interaction("Not a valid target.", {"player_ids": [player_id]})
		return
	var is_effect_summon := bool(_pending_summon_target.get("is_effect_summon", false))
	var is_turn_trigger := bool(_pending_summon_target.get("is_turn_trigger", false))
	_pending_summon_target = {}
	_dismiss_summon_skip_button()
	_dismiss_vision_card_overlay()
	_cancel_targeting_mode_silent()
	if is_turn_trigger:
		var result = _screen.MatchTiming.resolve_pending_turn_trigger_target(_screen._match_state, _screen._local_player_id(), {"player_id": player_id})
		_screen._finalize_engine_result(result, "Targeted %s." % _screen._player_name(player_id))
		_screen._check_pending_turn_trigger_target()
	elif is_effect_summon:
		var result = _screen.MatchTiming.resolve_pending_summon_effect_target(_screen._match_state, _screen._local_player_id(), {"target_player_id": player_id})
		_screen._finalize_engine_result(result, "Targeted %s." % _screen._player_name(player_id))
		_screen._check_deferred_betray()
	else:
		var result = _screen.MatchTiming.resolve_targeted_effect(_screen._match_state, source_id, {"target_player_id": player_id})
		_screen._finalize_engine_result(result, "Targeted %s." % _screen._player_name(player_id))
		_check_pending_summon_effect_target()
		_screen._check_deferred_betray()


func _is_pending_summon_mandatory() -> bool:
	var source_id := str(_pending_summon_target.get("source_instance_id", ""))
	if source_id.is_empty():
		return false
	if bool(_pending_summon_target.get("is_effect_summon", false)):
		var pending = _screen.MatchTiming.get_pending_summon_effect_target(_screen._match_state, _screen._local_player_id())
		return bool(pending.get("mandatory", false))
	var card = _screen._card_from_instance_id(source_id)
	for ability in _screen.MatchTiming.get_target_mode_abilities(card):
		if bool(ability.get("mandatory", false)):
			return true
	return false


func _cancel_summon_target_mode() -> void:
	var is_turn_trigger := bool(_pending_summon_target.get("is_turn_trigger", false))
	if is_turn_trigger:
		_screen.MatchTiming.decline_pending_turn_trigger_target(_screen._match_state, _screen._local_player_id())
	elif bool(_pending_summon_target.get("is_effect_summon", false)):
		_screen.MatchTiming.decline_pending_summon_effect_target(_screen._match_state, _screen._local_player_id())
	_pending_summon_target = {}
	_dismiss_summon_skip_button()
	_dismiss_vision_card_overlay()
	_screen._cancel_targeting_mode()
	_screen._status_message = "Effect declined."
	_screen._refresh_ui()
	if is_turn_trigger:
		_screen._check_pending_turn_trigger_target()
	_screen._check_deferred_betray()


func _check_pending_secondary_target() -> void:
	var local_id = _screen._local_player_id()
	if not _screen.MatchTiming.has_pending_secondary_target(_screen._match_state, local_id):
		return
	if not _pending_secondary_target_state.is_empty():
		return
	if not _pending_summon_target.is_empty():
		return
	var pending = _screen.MatchTiming.get_pending_secondary_target(_screen._match_state, local_id)
	var source_id := str(pending.get("source_instance_id", ""))
	_pending_secondary_target_state = pending.duplicate(true)
	_screen._selected_instance_id = source_id
	_screen._enter_targeting_mode(source_id)
	_screen._status_message = "Choose a target for damage."
	_screen._refresh_ui()


func _resolve_secondary_target_card(target_instance_id: String) -> void:
	_pending_secondary_target_state = {}
	_cancel_targeting_mode_silent()
	var result = _screen.MatchTiming.resolve_pending_secondary_target(_screen._match_state, _screen._local_player_id(), target_instance_id)
	_screen._finalize_engine_result(result, "Dealt damage to %s." % _screen._card_name(_screen._card_from_instance_id(target_instance_id)))


func _resolve_secondary_target_player(player_id: String) -> void:
	_pending_secondary_target_state = {}
	_cancel_targeting_mode_silent()
	var result = _screen.MatchTiming.resolve_pending_secondary_target_player(_screen._match_state, _screen._local_player_id(), player_id)
	_screen._finalize_engine_result(result, "Dealt damage to %s." % _screen._player_name(player_id))


func _check_pending_summon_effect_target() -> void:
	var local_id = _screen._local_player_id()
	if not _screen.MatchTiming.has_pending_summon_effect_target(_screen._match_state, local_id):
		return
	if not _pending_summon_target.is_empty():
		return
	var pending = _screen.MatchTiming.get_pending_summon_effect_target(_screen._match_state, local_id)
	var source_id := str(pending.get("source_instance_id", ""))
	var card = _screen._card_from_instance_id(source_id)
	if card.is_empty():
		_screen.MatchTiming.decline_pending_summon_effect_target(_screen._match_state, local_id)
		return
	var choice_tm := str(pending.get("_choice_target_mode", ""))
	var valid_targets: Array
	if not choice_tm.is_empty():
		valid_targets = _screen.MatchTiming.get_valid_targets_for_mode(_screen._match_state, source_id, choice_tm, {})
	else:
		valid_targets = _screen.MatchTiming.get_all_valid_targets(_screen._match_state, source_id)
	if valid_targets.is_empty():
		_screen.MatchTiming.decline_pending_summon_effect_target(_screen._match_state, local_id)
		return
	_pending_summon_target = {
		"source_instance_id": source_id,
		"is_effect_summon": true,
		"_choice_target_mode": choice_tm,
	}
	_screen._selected_instance_id = source_id
	_screen._enter_targeting_mode(source_id)
	if not choice_tm.is_empty():
		_screen._status_message = _summon_target_prompt(card, [{"target_mode": choice_tm}])
	else:
		var abilities = _screen.MatchTiming.get_target_mode_abilities(card)
		_screen._status_message = _summon_target_prompt(card, abilities)
	var vision_data: Dictionary = pending.get("vision_card", {})
	if not vision_data.is_empty():
		_show_vision_card_overlay(vision_data)
	if not _is_pending_summon_mandatory():
		_show_summon_skip_button()
	_screen._refresh_ui()


func _summon_target_prompt(card: Dictionary, abilities: Array) -> String:
	var card_name := str(card.get("name", ""))
	var modes: Array = []
	for ability in abilities:
		modes.append(str(ability.get("target_mode", "")))
	if modes.has("creature_or_player"):
		return "%s: Choose a target." % card_name
	if modes.has("enemy_creature") or modes.has("enemy_creature_in_lane"):
		return "%s: Choose an enemy creature." % card_name
	if modes.has("friendly_creature") or modes.has("another_friendly_creature"):
		return "%s: Choose a friendly creature." % card_name
	if modes.has("enemy_support"):
		if modes.size() > 1:
			return "%s: Choose a creature or enemy support." % card_name
		return "%s: Choose an enemy support." % card_name
	return "%s: Choose a target." % card_name


func _show_summon_skip_button() -> void:
	_dismiss_summon_skip_button()
	var viewport_size = _screen.get_viewport_rect().size
	_screen._betray._summon_skip_button = Button.new()
	_screen._betray._summon_skip_button.text = "Skip"
	_screen._betray._summon_skip_button.custom_minimum_size = Vector2(120, 44)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.22, 0.28, 0.92)
	style.border_color = Color(0.6, 0.55, 0.65, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	_screen._betray._summon_skip_button.add_theme_stylebox_override("normal", style)
	_screen._betray._summon_skip_button.add_theme_stylebox_override("hover", style)
	_screen._betray._summon_skip_button.add_theme_stylebox_override("pressed", style)
	_screen._betray._summon_skip_button.add_theme_color_override("font_color", Color(0.9, 0.88, 0.92, 1.0))
	_screen._betray._summon_skip_button.add_theme_font_size_override("font_size", 16)
	_screen._betray._summon_skip_button.pressed.connect(_cancel_summon_target_mode)
	_screen._betray._summon_skip_button.z_index = 600
	_screen.add_child(_screen._betray._summon_skip_button)
	_screen._betray._summon_skip_button.position = Vector2(viewport_size.x * 0.5 - 60, viewport_size.y * 0.5 + 40)


func _dismiss_summon_skip_button() -> void:
	if _screen._betray._summon_skip_button != null and is_instance_valid(_screen._betray._summon_skip_button):
		_screen._betray._summon_skip_button.queue_free()
	_screen._betray._summon_skip_button = null


func _show_vision_card_overlay(vision_data: Dictionary) -> void:
	_dismiss_vision_card_overlay()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 470

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "Choose a creature to transform into:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var card_size: Vector2 = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE * 1.8
	var card_container := Control.new()
	card_container.custom_minimum_size = card_size
	card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(card_container)

	var card_display = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_display.custom_minimum_size = card_size
	card_display.scale = Vector2(1.8, 1.8)
	card_container.add_child(card_display)
	card_display.apply_card(vision_data, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)

	_screen.add_child(overlay)
	_vision_card_overlay = overlay


func _dismiss_vision_card_overlay() -> void:
	if _vision_card_overlay != null and is_instance_valid(_vision_card_overlay):
		_vision_card_overlay.queue_free()
	_vision_card_overlay = null
