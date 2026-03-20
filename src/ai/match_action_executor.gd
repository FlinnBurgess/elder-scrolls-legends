class_name MatchActionExecutor
extends RefCounted

const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")


static func execute_action(match_state: Dictionary, action: Dictionary) -> Dictionary:
	if not MatchActionEnumerator.action_is_legal(match_state, action):
		return {"is_valid": false, "errors": ["Action is not legal in the current state."], "match_state": match_state}
	var player_id := str(action.get("player_id", ""))
	var source_instance_id := str(action.get("source_instance_id", ""))
	var parameters: Dictionary = action.get("parameters", {}).duplicate(true)
	var kind := str(action.get("kind", ""))
	var result := {"is_valid": true, "errors": [], "events": [], "trigger_resolutions": [], "match_state": match_state}
	match kind:
		MatchActionEnumerator.KIND_RING_USE:
			MatchTurnLoop.activate_ring_of_magicka(match_state, player_id)
		MatchActionEnumerator.KIND_END_TURN:
			var active_before := str(match_state.get("active_player_id", ""))
			MatchTurnLoop.end_turn(match_state, player_id)
			result["is_valid"] = active_before != str(match_state.get("active_player_id", ""))
			if not bool(result.get("is_valid", false)):
				result["errors"] = ["End turn did not advance priority to the opposing player."]
		MatchActionEnumerator.KIND_SUMMON_CREATURE:
			if str(action.get("response_kind", "")) == MatchTiming.RULE_TAG_PROPHECY:
				result = MatchTiming.play_pending_prophecy(match_state, player_id, source_instance_id, parameters)
			else:
				var lane_id := str(parameters.get("lane_id", ""))
				var options := parameters.duplicate(true)
				options.erase("lane_id")
				options.erase("summon_target_instance_id")
				options.erase("summon_target_player_id")
				result = LaneRules.summon_from_hand(match_state, player_id, source_instance_id, lane_id, options)
			# Resolve targeted summon effect if target was pre-selected
			if bool(result.get("is_valid", false)):
				var summon_target_id := str(parameters.get("summon_target_instance_id", ""))
				var summon_target_pid := str(parameters.get("summon_target_player_id", ""))
				if not summon_target_id.is_empty() or not summon_target_pid.is_empty():
					var target_info := {}
					if not summon_target_id.is_empty():
						target_info["target_instance_id"] = summon_target_id
					if not summon_target_pid.is_empty():
						target_info["target_player_id"] = summon_target_pid
					var effect_result := MatchTiming.resolve_targeted_effect(match_state, source_instance_id, target_info)
					result["events"] = result.get("events", []) + effect_result.get("events", [])
					result["trigger_resolutions"] = result.get("trigger_resolutions", []) + effect_result.get("trigger_resolutions", [])
		MatchActionEnumerator.KIND_ATTACK:
			result = MatchCombat.resolve_attack(match_state, player_id, source_instance_id, parameters.get("target", {}).duplicate(true))
		MatchActionEnumerator.KIND_PLAY_SUPPORT:
			result = PersistentCardRules.play_support_from_hand(match_state, player_id, source_instance_id, parameters)
		MatchActionEnumerator.KIND_PLAY_ITEM:
			result = PersistentCardRules.play_item_from_hand(match_state, player_id, source_instance_id, parameters)
		MatchActionEnumerator.KIND_ACTIVATE_SUPPORT:
			result = PersistentCardRules.activate_support(match_state, player_id, source_instance_id, parameters)
		MatchActionEnumerator.KIND_PLAY_ACTION:
			if str(action.get("response_kind", "")) == MatchTiming.RULE_TAG_PROPHECY:
				result = MatchTiming.play_pending_prophecy(match_state, player_id, source_instance_id, parameters)
			else:
				result = MatchTiming.play_action_from_hand(match_state, player_id, source_instance_id, parameters)
		MatchActionEnumerator.KIND_DECLINE_PROPHECY:
			result = MatchTiming.decline_pending_prophecy(match_state, player_id, source_instance_id)
		MatchActionEnumerator.KIND_CHOOSE_DISCARD:
			result = MatchTiming.resolve_pending_discard_choice(match_state, player_id, str(parameters.get("chosen_instance_id", "")))
		MatchActionEnumerator.KIND_DECLINE_DISCARD:
			result = MatchTiming.decline_pending_discard_choice(match_state, player_id)
		MatchActionEnumerator.KIND_CHOOSE_HAND_SELECTION:
			result = MatchTiming.resolve_pending_hand_selection(match_state, player_id, str(parameters.get("chosen_instance_id", "")))
		MatchActionEnumerator.KIND_DECLINE_HAND_SELECTION:
			result = MatchTiming.decline_pending_hand_selection(match_state, player_id)
		_:
			return {"is_valid": false, "errors": ["Unsupported action kind: %s" % kind], "match_state": match_state}
	result["match_state"] = match_state
	return result


static func clone_and_execute(match_state: Dictionary, action: Dictionary) -> Dictionary:
	var clone := match_state.duplicate(true)
	var result := execute_action(clone, action)
	result["match_state"] = clone
	return result