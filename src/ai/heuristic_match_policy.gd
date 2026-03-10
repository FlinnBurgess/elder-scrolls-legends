class_name HeuristicMatchPolicy
extends RefCounted

const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const MatchStateEvaluator = preload("res://src/ai/match_state_evaluator.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")

const LETHAL_BONUS := 500000.0
const WIN_BONUS := 1000000.0
const DEFAULT_MIN_ACTION_GAIN := 0.6
const DEFAULT_TOP_CANDIDATES := 3
const DEFAULT_LOOKAHEAD_DEPTH := 1
const DEFAULT_LOOKAHEAD_DISCOUNT := 0.85


static func choose_action(match_state: Dictionary, player_id: String = "", options: Dictionary = {}) -> Dictionary:
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, player_id)
	var decision_player_id := str(surface.get("decision_player_id", ""))
	if decision_player_id.is_empty() or not str(surface.get("blocked_reason", "")).is_empty():
		return {"is_valid": false, "surface": surface, "reason": str(surface.get("blocked_reason", "No legal actor could be determined.")), "chosen_action": {}}
	var baseline := MatchStateEvaluator.evaluate_state(match_state, decision_player_id)
	var ranked := _rank_actions(match_state, surface, decision_player_id, baseline, _merged_options(options), DEFAULT_LOOKAHEAD_DEPTH)
	if ranked.is_empty():
		return {"is_valid": false, "surface": surface, "reason": "No legal actions were available.", "chosen_action": {}}
	var chosen := _select_final_candidate(ranked, surface, baseline, _merged_options(options))
	return {
		"is_valid": true,
		"surface": surface,
		"decision_player_id": decision_player_id,
		"baseline_score": baseline,
		"chosen_action": chosen.get("action", {}).duplicate(true),
		"chosen_score": float(chosen.get("total_score", -1000000.0)),
		"projected_gain": float(chosen.get("relative_gain", 0.0)),
		"reason": str(chosen.get("reason", "highest_score")),
		"considered_actions": _considered_summary(ranked),
	}


static func _rank_actions(match_state: Dictionary, surface: Dictionary, player_id: String, baseline: float, options: Dictionary, lookahead_depth: int) -> Array:
	var scored: Array = []
	for action in surface.get("actions", []):
		var candidate := _score_action_immediate(match_state, action, player_id, baseline)
		scored.append(candidate)
	scored.sort_custom(_sort_scored_actions)
	if lookahead_depth <= 0:
		return scored
	var top_count := mini(int(options.get("top_candidate_lookahead", DEFAULT_TOP_CANDIDATES)), scored.size())
	for index in range(top_count):
		var candidate: Dictionary = scored[index]
		if _is_pass_action(candidate.get("action", {})) or not _can_continue_turn(candidate.get("simulated_state", {}), player_id):
			continue
		var continuation_gain := _best_followup_gain(candidate.get("simulated_state", {}), player_id, options, lookahead_depth)
		candidate["continuation_gain"] = continuation_gain * float(options.get("lookahead_discount", DEFAULT_LOOKAHEAD_DISCOUNT))
		candidate["total_score"] = float(candidate.get("immediate_score", -1000000.0)) + float(candidate.get("continuation_gain", 0.0))
		candidate["relative_gain"] = float(candidate.get("total_score", -1000000.0)) - baseline
		scored[index] = candidate
	scored.sort_custom(_sort_scored_actions)
	return scored


static func _score_action_immediate(match_state: Dictionary, action: Dictionary, player_id: String, baseline: float) -> Dictionary:
	var execution := MatchActionExecutor.clone_and_execute(match_state, action)
	if not bool(execution.get("is_valid", false)):
		return {
			"action": action.duplicate(true),
			"immediate_score": -1000000.0,
			"total_score": -1000000.0,
			"relative_gain": -1000000.0,
			"reason": "illegal_after_simulation",
			"simulated_state": execution.get("match_state", {}),
		}
	var simulated_state: Dictionary = execution.get("match_state", {})
	var state_score := MatchStateEvaluator.evaluate_state(simulated_state, player_id)
	var tactical_bonus := _tactical_bonus(match_state, simulated_state, action, player_id)
	var total := state_score + tactical_bonus
	var reason := "highest_score"
	if float(tactical_bonus) >= LETHAL_BONUS:
		reason = "lethal"
	elif str(action.get("kind", "")) == MatchActionEnumerator.KIND_DECLINE_PROPHECY:
		reason = "decline_prophecy"
	return {
		"action": action.duplicate(true),
		"state_score": state_score,
		"tactical_bonus": tactical_bonus,
		"continuation_gain": 0.0,
		"immediate_score": total,
		"total_score": total,
		"relative_gain": total - baseline,
		"reason": reason,
		"forced": float(tactical_bonus) >= LETHAL_BONUS or str(simulated_state.get("winner_player_id", "")) == player_id,
		"simulated_state": simulated_state,
	}


static func _best_followup_gain(match_state: Dictionary, player_id: String, options: Dictionary, remaining_depth: int) -> float:
	if remaining_depth <= 0 or not _can_continue_turn(match_state, player_id):
		return 0.0
	var baseline := MatchStateEvaluator.evaluate_state(match_state, player_id)
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, player_id)
	var ranked := _rank_actions(match_state, surface, player_id, baseline, options, remaining_depth - 1)
	if ranked.is_empty():
		return 0.0
	var best_non_pass := _best_non_pass_candidate(ranked)
	if best_non_pass.is_empty():
		return 0.0
	if bool(best_non_pass.get("forced", false)):
		return maxf(0.0, float(best_non_pass.get("total_score", baseline)) - baseline)
	if float(best_non_pass.get("relative_gain", 0.0)) < float(options.get("min_action_gain", DEFAULT_MIN_ACTION_GAIN)):
		return 0.0
	return maxf(0.0, float(best_non_pass.get("total_score", baseline)) - baseline)


static func _select_final_candidate(ranked: Array, surface: Dictionary, baseline: float, options: Dictionary) -> Dictionary:
	if bool(surface.get("has_pending_prophecy", false)):
		return ranked[0]
	var best_non_pass := _best_non_pass_candidate(ranked)
	var best_end_turn := _best_candidate_for_kind(ranked, MatchActionEnumerator.KIND_END_TURN)
	if best_non_pass.is_empty():
		return best_end_turn if not best_end_turn.is_empty() else ranked[0]
	if bool(best_non_pass.get("forced", false)):
		return best_non_pass
	if float(best_non_pass.get("relative_gain", 0.0)) >= float(options.get("min_action_gain", DEFAULT_MIN_ACTION_GAIN)):
		return best_non_pass
	return best_end_turn if not best_end_turn.is_empty() else ranked[0]


static func _tactical_bonus(before_state: Dictionary, after_state: Dictionary, action: Dictionary, player_id: String) -> float:
	var kind := str(action.get("kind", ""))
	var opponent_id := _opposing_player_id(before_state, player_id)
	var before_player := _find_player(before_state, player_id)
	var after_player := _find_player(after_state, player_id)
	var before_opponent := _find_player(before_state, opponent_id)
	var after_opponent := _find_player(after_state, opponent_id)
	if before_player.is_empty() or after_player.is_empty() or before_opponent.is_empty() or after_opponent.is_empty():
		return 0.0
	var bonus := 0.0
	if str(after_state.get("winner_player_id", "")) == player_id:
		bonus += WIN_BONUS
	var spent_magicka := maxf(0.0, float(int(before_player.get("current_magicka", 0)) + int(before_player.get("temporary_magicka", 0)) - int(after_player.get("current_magicka", 0)) - int(after_player.get("temporary_magicka", 0))))
	bonus += spent_magicka * 0.45 if kind != MatchActionEnumerator.KIND_END_TURN else 0.0
	bonus += float(_creature_count(before_state, opponent_id) - _creature_count(after_state, opponent_id)) * 2.3
	bonus -= float(_creature_count(before_state, player_id) - _creature_count(after_state, player_id)) * 1.9
	bonus += float(_guard_count(before_state, opponent_id) - _guard_count(after_state, opponent_id)) * 1.7
	bonus += float(_incoming_face_threat(before_state, player_id) - _incoming_face_threat(after_state, player_id)) * 2.2
	match kind:
		MatchActionEnumerator.KIND_RING_USE:
			bonus -= 1.15
		MatchActionEnumerator.KIND_ATTACK:
			if str(action.get("target", {}).get("kind", "")) == "player":
				bonus += float(int(before_opponent.get("health", 0)) - int(after_opponent.get("health", 0))) * 0.25
			else:
				bonus += _attack_trade_bonus(before_state, after_state, action)
		MatchActionEnumerator.KIND_SUMMON_CREATURE:
			var source_card: Dictionary = action.get("source_card", {})
			bonus += float(int(source_card.get("power", 0))) * 0.4 + float(int(source_card.get("health", 0))) * 0.25
			if str(action.get("parameters", {}).get("lane_id", "")) == "shadow":
				bonus += 0.55
		MatchActionEnumerator.KIND_PLAY_ITEM:
			bonus += 0.75
		MatchActionEnumerator.KIND_PLAY_SUPPORT:
			bonus += 0.45
		MatchActionEnumerator.KIND_ACTIVATE_SUPPORT:
			bonus += 0.65
		MatchActionEnumerator.KIND_PLAY_ACTION:
			bonus += 0.55
		MatchActionEnumerator.KIND_DECLINE_PROPHECY:
			bonus += 0.15
	return bonus


static func _attack_trade_bonus(before_state: Dictionary, after_state: Dictionary, action: Dictionary) -> float:
	var attacker_id := str(action.get("source_instance_id", ""))
	var defender_id := str(action.get("target", {}).get("instance_id", action.get("target", {}).get("card", {}).get("instance_id", "")))
	var attacker_before := _find_card(before_state, attacker_id)
	var attacker_after := _find_card(after_state, attacker_id)
	var defender_before := _find_card(before_state, defender_id)
	var defender_after := _find_card(after_state, defender_id)
	var bonus := 0.0
	if defender_after.is_empty() and not defender_before.is_empty():
		bonus += 4.5
	if defender_after.is_empty() and not attacker_after.is_empty():
		bonus += 1.25
	if attacker_after.is_empty() and not attacker_before.is_empty():
		bonus -= 3.0
	return bonus


static func _best_non_pass_candidate(ranked: Array) -> Dictionary:
	for candidate in ranked:
		if not _is_pass_action(candidate.get("action", {})):
			return candidate
	return {}


static func _best_candidate_for_kind(ranked: Array, kind: String) -> Dictionary:
	for candidate in ranked:
		if str(candidate.get("action", {}).get("kind", "")) == kind:
			return candidate
	return {}


static func _is_pass_action(action: Dictionary) -> bool:
	var kind := str(action.get("kind", ""))
	return kind == MatchActionEnumerator.KIND_END_TURN or kind == MatchActionEnumerator.KIND_DECLINE_PROPHECY


static func _can_continue_turn(match_state: Dictionary, player_id: String) -> bool:
	return str(match_state.get("winner_player_id", "")).is_empty() and str(match_state.get("active_player_id", "")) == player_id and not MatchTiming.has_pending_prophecy(match_state)


static func _considered_summary(ranked: Array) -> Array:
	var summary: Array = []
	for candidate in ranked:
		summary.append({
			"id": str(candidate.get("action", {}).get("id", "")),
			"kind": str(candidate.get("action", {}).get("kind", "")),
			"score": float(candidate.get("total_score", 0.0)),
			"gain": float(candidate.get("relative_gain", 0.0)),
			"reason": str(candidate.get("reason", "highest_score")),
		})
	return summary


static func _sort_scored_actions(a: Dictionary, b: Dictionary) -> bool:
	var a_score := float(a.get("total_score", -1000000.0))
	var b_score := float(b.get("total_score", -1000000.0))
	if not is_equal_approx(a_score, b_score):
		return a_score > b_score
	var a_gain := float(a.get("relative_gain", -1000000.0))
	var b_gain := float(b.get("relative_gain", -1000000.0))
	if not is_equal_approx(a_gain, b_gain):
		return a_gain > b_gain
	return str(a.get("action", {}).get("id", "")) < str(b.get("action", {}).get("id", ""))


static func _find_player(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _opposing_player_id(match_state: Dictionary, player_id: String) -> String:
	for player in match_state.get("players", []):
		var candidate := str(player.get("player_id", ""))
		if candidate != player_id:
			return candidate
	return ""


static func _creature_count(match_state: Dictionary, player_id: String) -> int:
	var count := 0
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				count += 1
	return count


static func _guard_count(match_state: Dictionary, player_id: String) -> int:
	var count := 0
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and MatchStateEvaluator._array_has_string(card.get("keywords", []), "guard"):
				count += 1
	return count


static func _incoming_face_threat(match_state: Dictionary, player_id: String) -> int:
	return MatchStateEvaluator._incoming_face_threat(match_state, player_id)


static func _find_card(match_state: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for player in match_state.get("players", []):
		for zone_name in ["hand", "support", "discard", "banished", "deck"]:
			for card in player.get(zone_name, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return card
	for lane in match_state.get("lanes", []):
		for slots in lane.get("player_slots", {}).values():
			for card in slots:
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return card
	return {}


static func _merged_options(options: Dictionary) -> Dictionary:
	return {
		"min_action_gain": float(options.get("min_action_gain", DEFAULT_MIN_ACTION_GAIN)),
		"top_candidate_lookahead": int(options.get("top_candidate_lookahead", DEFAULT_TOP_CANDIDATES)),
		"lookahead_discount": float(options.get("lookahead_discount", DEFAULT_LOOKAHEAD_DISCOUNT)),
	}