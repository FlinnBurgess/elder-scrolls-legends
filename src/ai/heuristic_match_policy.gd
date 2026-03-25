class_name HeuristicMatchPolicy
extends RefCounted

## Core AI decision-making policy using heuristic evaluation with optional
## lookahead.
##
## The policy scores every legal action by simulating it, evaluating the
## resulting board state, and adding a tactical bonus. The top candidates are
## optionally evaluated one ply deeper to account for multi-action turns.
##
## All scoring weights are read from an `options` dictionary rather than
## hardcoded constants. When no options are provided, the defaults match the
## midrange profile — preserving the original behaviour for tests and any
## callers that don't pass options.
##
## Quality and archetype are threaded in via the options dict built by
## AIPlayProfile.build_options(). Quality controls decision precision (noise,
## lookahead depth); archetype controls strategic priorities (face damage vs
## board control vs card advantage).

const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const MatchStateEvaluator = preload("res://src/ai/match_state_evaluator.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")

const LETHAL_BONUS := 500000.0
const WIN_BONUS := 1000000.0

# Default values for options — match the midrange profile in AIPlayProfile.
# These are used when no options dict is provided, ensuring backward compatibility
# with existing tests and callers.
const DEFAULT_MIN_ACTION_GAIN := 0.6
const DEFAULT_TOP_CANDIDATES := 3
const DEFAULT_LOOKAHEAD_DEPTH := 1
const DEFAULT_LOOKAHEAD_DISCOUNT := 0.85


static func choose_mulligan(match_state: Dictionary, player_id: String) -> Array:
	var player := _find_player(match_state, player_id)
	if player.is_empty():
		return []
	var hand: Array = player.get("hand", [])
	if hand.is_empty():
		return []
	var seen_definition_ids := {}
	var discard_ids: Array = []
	for card in hand:
		var instance_id := str(card.get("instance_id", ""))
		var definition_id := str(card.get("definition_id", ""))
		var cost := int(card.get("cost", 0))
		var keep_score := _mulligan_keep_score(card, cost)
		if seen_definition_ids.has(definition_id):
			keep_score -= 1.5
		seen_definition_ids[definition_id] = true
		if keep_score < 0.0:
			discard_ids.append(instance_id)
	return discard_ids


static func _mulligan_keep_score(card: Dictionary, cost: int) -> float:
	var score := 0.0
	if cost <= 2:
		score = 3.0
	elif cost == 3:
		score = 2.0
	elif cost == 4:
		score = 1.0
	else:
		score = 1.0 - float(cost - 4) * 1.0
	var keywords: Array = card.get("keywords", [])
	for kw in keywords:
		if str(kw) in ["guard", "charge", "drain", "prophecy"]:
			score += 0.5
	return score


static func choose_action(match_state: Dictionary, player_id: String = "", options: Dictionary = {}) -> Dictionary:
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, player_id)
	var decision_player_id := str(surface.get("decision_player_id", ""))
	if decision_player_id.is_empty() or not str(surface.get("blocked_reason", "")).is_empty():
		return {"is_valid": false, "surface": surface, "reason": str(surface.get("blocked_reason", "No legal actor could be determined.")), "chosen_action": {}}
	var merged := _merged_options(options)
	var baseline := MatchStateEvaluator.evaluate_state(match_state, decision_player_id, merged)
	# Lookahead depth can be overridden by quality scaling (low quality = no lookahead).
	var lookahead := int(merged.get("lookahead_depth", DEFAULT_LOOKAHEAD_DEPTH))
	var ranked := _rank_actions(match_state, surface, decision_player_id, baseline, merged, lookahead)
	if ranked.is_empty():
		return {"is_valid": false, "surface": surface, "reason": "No legal actions were available.", "chosen_action": {}}

	# Apply score noise for lower-quality AI: adds random perturbation so the AI
	# occasionally picks suboptimal actions, simulating weaker play.
	var noise_amplitude := float(merged.get("score_noise", 0.0))
	if noise_amplitude > 0.0:
		_apply_score_noise(ranked, noise_amplitude, match_state)

	var chosen := _select_final_candidate(ranked, surface, baseline, merged)
	var decision_reason := _decision_reason(chosen, ranked, surface, merged)
	return {
		"is_valid": true,
		"surface": surface,
		"decision_player_id": decision_player_id,
		"baseline_score": baseline,
		"chosen_action": chosen.get("action", {}).duplicate(true),
		"chosen_score": float(chosen.get("total_score", -1000000.0)),
		"projected_gain": float(chosen.get("relative_gain", 0.0)),
		"reason": str(chosen.get("reason", "highest_score")),
		"behavior_label": str(chosen.get("behavior_label", "highest_score")),
		"decision_reason": decision_reason,
		"action_summary": str(chosen.get("action_summary", _action_summary(chosen.get("action", {})))),
		"decision_summary": _candidate_summary(chosen, decision_reason),
		"considered_actions": _considered_summary(ranked),
	}


static func describe_choice(choice: Dictionary, max_candidates: int = 3) -> String:
	if not bool(choice.get("is_valid", false)):
		return "invalid_choice reason=%s" % str(choice.get("reason", "unknown"))
	var sections: Array = [str(choice.get("decision_summary", ""))]
	var considered: Array = choice.get("considered_actions", [])
	var limit := mini(max_candidates, considered.size())
	if limit > 0:
		var top: Array = []
		for index in range(limit):
			var candidate: Dictionary = considered[index]
			top.append(str(candidate.get("summary", candidate.get("id", ""))))
		sections.append("top=%s" % " || ".join(top))
	return " || ".join(sections)


static func _rank_actions(match_state: Dictionary, surface: Dictionary, player_id: String, baseline: float, options: Dictionary, lookahead_depth: int) -> Array:
	var scored: Array = []
	for action in surface.get("actions", []):
		var candidate := _score_action_immediate(match_state, action, player_id, baseline, options)
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


static func _score_action_immediate(match_state: Dictionary, action: Dictionary, player_id: String, baseline: float, options: Dictionary = {}) -> Dictionary:
	var execution := MatchActionExecutor.clone_and_execute(match_state, action)
	var action_summary := _action_summary(action)
	if not bool(execution.get("is_valid", false)):
		return {
			"action": action.duplicate(true),
			"immediate_score": -1000000.0,
			"total_score": -1000000.0,
			"relative_gain": -1000000.0,
			"reason": "illegal_after_simulation",
			"behavior_label": "illegal_after_simulation",
			"action_summary": action_summary,
			"simulated_state": execution.get("match_state", {}),
		}
	var simulated_state: Dictionary = execution.get("match_state", {})
	# Pass options to evaluate_state so archetype-specific weights are used.
	var state_score := MatchStateEvaluator.evaluate_state(simulated_state, player_id, options)
	var tactical_bonus := _tactical_bonus(match_state, simulated_state, action, player_id, options)
	var total := state_score + tactical_bonus
	var reason := "highest_score"
	if float(tactical_bonus) >= LETHAL_BONUS:
		reason = "lethal"
	elif str(action.get("kind", "")) == MatchActionEnumerator.KIND_DECLINE_PROPHECY:
		reason = "decline_prophecy"
	var behavior_label := _classify_candidate(match_state, simulated_state, action, player_id, reason)
	return {
		"action": action.duplicate(true),
		"state_score": state_score,
		"tactical_bonus": tactical_bonus,
		"continuation_gain": 0.0,
		"immediate_score": total,
		"total_score": total,
		"relative_gain": total - baseline,
		"reason": reason,
		"behavior_label": behavior_label,
		"action_summary": action_summary,
		"forced": float(tactical_bonus) >= LETHAL_BONUS or str(simulated_state.get("winner_player_id", "")) == player_id,
		"simulated_state": simulated_state,
	}


static func _best_followup_gain(match_state: Dictionary, player_id: String, options: Dictionary, remaining_depth: int) -> float:
	if remaining_depth <= 0 or not _can_continue_turn(match_state, player_id):
		return 0.0
	var baseline := MatchStateEvaluator.evaluate_state(match_state, player_id, options)
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


## Compute tactical bonus for an action based on how it changes the board.
##
## All weights are read from the options dictionary, falling back to the midrange
## defaults (the original hardcoded values) when no options are provided. This
## allows archetype profiles to shift priorities — e.g. aggro values face damage
## much higher than control, which prioritises creature removal.
static func _tactical_bonus(before_state: Dictionary, after_state: Dictionary, action: Dictionary, player_id: String, options: Dictionary = {}) -> float:
	var kind := str(action.get("kind", ""))
	var opponent_id := _opposing_player_id(before_state, player_id)
	var before_player := _find_player(before_state, player_id)
	var after_player := _find_player(after_state, player_id)
	var before_opponent := _find_player(before_state, opponent_id)
	var after_opponent := _find_player(after_state, opponent_id)
	if before_player.is_empty() or after_player.is_empty() or before_opponent.is_empty() or after_opponent.is_empty():
		return 0.0

	# Read archetype-sensitive weights from options, defaulting to midrange values.
	var creature_killed_w := float(options.get("creature_killed_bonus", 2.3))
	var own_creature_lost_w := float(options.get("own_creature_lost_penalty", 1.9))
	var guard_removed_w := float(options.get("guard_removed_bonus", 1.7))
	var threat_reduction_w := float(options.get("threat_reduction_weight", 2.2))
	var face_damage_w := float(options.get("face_damage_bonus", 0.25))
	var shadow_lane_w := float(options.get("shadow_lane_bonus", 0.55))
	var summon_power_w := float(options.get("summon_power_weight", 0.4))
	var summon_health_w := float(options.get("summon_health_weight", 0.25))

	var bonus := 0.0
	if str(after_state.get("winner_player_id", "")) == player_id:
		bonus += WIN_BONUS
	var spent_magicka := maxf(0.0, float(int(before_player.get("current_magicka", 0)) + int(before_player.get("temporary_magicka", 0)) - int(after_player.get("current_magicka", 0)) - int(after_player.get("temporary_magicka", 0))))
	bonus += spent_magicka * 0.45 if kind != MatchActionEnumerator.KIND_END_TURN else 0.0
	bonus += float(_creature_count(before_state, opponent_id) - _creature_count(after_state, opponent_id)) * creature_killed_w
	bonus -= float(_creature_count(before_state, player_id) - _creature_count(after_state, player_id)) * own_creature_lost_w
	bonus += float(_guard_count(before_state, opponent_id) - _guard_count(after_state, opponent_id)) * guard_removed_w
	bonus += float(_incoming_face_threat(before_state, player_id) - _incoming_face_threat(after_state, player_id)) * threat_reduction_w
	match kind:
		MatchActionEnumerator.KIND_RING_USE:
			bonus -= 1.15
		MatchActionEnumerator.KIND_ATTACK:
			if str(action.get("target", {}).get("kind", "")) == "player":
				bonus += float(int(before_opponent.get("health", 0)) - int(after_opponent.get("health", 0))) * face_damage_w
				# Compensate for creatures summoned by rune-break side effects
				# (boons like Runic Ward, prophecy creatures). Breaking runes is
				# inevitable for winning — without this offset the AI refuses to
				# attack face when rune breaks spawn creatures.
				bonus += _rune_break_summon_offset(before_state, after_state, opponent_id, player_id, options)
			else:
				bonus += _attack_trade_bonus(before_state, after_state, action)
		MatchActionEnumerator.KIND_SUMMON_CREATURE:
			var source_card: Dictionary = action.get("source_card", {})
			bonus += float(int(source_card.get("power", 0))) * summon_power_w + float(int(source_card.get("health", 0))) * summon_health_w
			if str(action.get("parameters", {}).get("lane_id", "")) == "shadow":
				bonus += shadow_lane_w
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


## Offset state-evaluation penalties caused by opponent creatures that appeared
## as a side effect of a face attack (rune-break boon summons, prophecy plays).
##
## These creatures are an inevitable cost of dealing face damage — the AI must
## break runes to win. Without this offset the board-value and threat penalties
## from rune-break summons dominate, causing the AI to avoid face attacks.
## The offset is 85% of the total penalty so the AI still slightly prefers
## lines that avoid unnecessary rune breaks when better options exist.
static func _rune_break_summon_offset(before_state: Dictionary, after_state: Dictionary, opponent_id: String, player_id: String, options: Dictionary) -> float:
	# Identify creatures that appeared on the opponent's board during the action.
	var before_ids := {}
	for lane in before_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(opponent_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				before_ids[str(card.get("instance_id", ""))] = true
	var new_creature_value := 0.0
	var new_creature_count := 0
	var new_guard_count := 0
	for lane in after_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(opponent_id, []):
			if typeof(card) == TYPE_DICTIONARY and not before_ids.has(str(card.get("instance_id", ""))):
				new_creature_count += 1
				new_creature_value += MatchStateEvaluator._creature_value(after_state, card)
				if MatchStateEvaluator._array_has_string(card.get("keywords", []), "guard"):
					new_guard_count += 1
	if new_creature_count == 0:
		return 0.0
	const OFFSET_FRACTION := 0.85
	# Offset the board-value penalty (opponent creatures weighted 1.25x in evaluator).
	var offset := new_creature_value * 1.25 * OFFSET_FRACTION
	# Offset the creature-count and guard-count tactical penalties.
	offset += float(new_creature_count) * float(options.get("creature_killed_bonus", 2.3)) * OFFSET_FRACTION
	offset += float(new_guard_count) * float(options.get("guard_removed_bonus", 1.7)) * OFFSET_FRACTION
	# Offset the face-threat reduction from new guards blocking AI attackers.
	var ai_threat_before := MatchStateEvaluator._incoming_face_threat(before_state, opponent_id)
	var ai_threat_after := MatchStateEvaluator._incoming_face_threat(after_state, opponent_id)
	var threat_decrease := maxi(0, ai_threat_before - ai_threat_after)
	if threat_decrease > 0:
		var threat_w := float(options.get("incoming_threat_weight", 3.5))
		offset += float(threat_decrease) * threat_w * 0.55 * OFFSET_FRACTION
	return offset


## Apply random noise to candidate scores to simulate lower-quality play.
##
## The noise is seeded from the match turn number so that within a single match
## the AI is consistently "sloppy" or "sharp", but different matches produce
## different noise patterns. Forced actions (lethal lines) are never perturbed.
static func _apply_score_noise(ranked: Array, amplitude: float, match_state: Dictionary) -> void:
	var turn := int(match_state.get("turn_number", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(turn * 7919 + ranked.size())
	for i in range(ranked.size()):
		var candidate: Dictionary = ranked[i]
		# Never add noise to forced/lethal actions — the AI should always take lethal.
		if bool(candidate.get("forced", false)):
			continue
		var noise := rng.randf_range(-amplitude, amplitude)
		candidate["total_score"] = float(candidate.get("total_score", 0.0)) + noise
		candidate["relative_gain"] = float(candidate.get("relative_gain", 0.0)) + noise
		ranked[i] = candidate
	ranked.sort_custom(_sort_scored_actions)


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
			"action_summary": str(candidate.get("action_summary", _action_summary(candidate.get("action", {})))),
			"behavior_label": str(candidate.get("behavior_label", "highest_score")),
			"state_score": float(candidate.get("state_score", 0.0)),
			"tactical_bonus": float(candidate.get("tactical_bonus", 0.0)),
			"continuation_gain": float(candidate.get("continuation_gain", 0.0)),
			"score": float(candidate.get("total_score", 0.0)),
			"gain": float(candidate.get("relative_gain", 0.0)),
			"reason": str(candidate.get("reason", "highest_score")),
			"summary": _candidate_summary(candidate, str(candidate.get("reason", "highest_score"))),
		})
	return summary


static func _decision_reason(chosen: Dictionary, ranked: Array, surface: Dictionary, options: Dictionary) -> String:
	if bool(surface.get("has_pending_prophecy", false)):
		return "prophecy_decline" if str(chosen.get("action", {}).get("kind", "")) == MatchActionEnumerator.KIND_DECLINE_PROPHECY else "prophecy_play"
	if str(chosen.get("reason", "")) == "lethal" or bool(chosen.get("forced", false)):
		return "lethal"
	if _is_pass_action(chosen.get("action", {})):
		var best_non_pass := _best_non_pass_candidate(ranked)
		if best_non_pass.is_empty() or float(best_non_pass.get("relative_gain", 0.0)) < float(options.get("min_action_gain", DEFAULT_MIN_ACTION_GAIN)):
			return "no_profitable_play"
		return "pass"
	return str(chosen.get("behavior_label", chosen.get("reason", "highest_score")))


static func _classify_candidate(before_state: Dictionary, after_state: Dictionary, action: Dictionary, player_id: String, reason: String) -> String:
	if reason == "lethal" or str(after_state.get("winner_player_id", "")) == player_id:
		return "lethal_line"
	if MatchTiming.has_pending_prophecy(before_state) or str(action.get("response_kind", "")) == MatchTiming.RULE_TAG_PROPHECY:
		return "prophecy_decline" if str(action.get("kind", "")) == MatchActionEnumerator.KIND_DECLINE_PROPHECY else "prophecy_play"
	if _is_pass_action(action):
		return "pass_no_profitable_play"
	var opponent_id := _opposing_player_id(before_state, player_id)
	var before_player := _find_player(before_state, player_id)
	var threat_before := _incoming_face_threat(before_state, player_id)
	var threat_after := _incoming_face_threat(after_state, player_id)
	var guard_before := _guard_count(before_state, player_id)
	var guard_after := _guard_count(after_state, player_id)
	var enemy_creatures_before := _creature_count(before_state, opponent_id)
	var enemy_creatures_after := _creature_count(after_state, opponent_id)
	if threat_after < threat_before or guard_after > guard_before or (int(before_player.get("health", 30)) <= 12 and enemy_creatures_after < enemy_creatures_before):
		return "defensive_stabilization"
	var kind := str(action.get("kind", ""))
	if kind == MatchActionEnumerator.KIND_ATTACK:
		return "face_pressure" if str(action.get("target", {}).get("kind", "")) == "player" else "board_control"
	if kind in [
		MatchActionEnumerator.KIND_RING_USE,
		MatchActionEnumerator.KIND_SUMMON_CREATURE,
		MatchActionEnumerator.KIND_PLAY_SUPPORT,
		MatchActionEnumerator.KIND_PLAY_ITEM,
		MatchActionEnumerator.KIND_ACTIVATE_SUPPORT,
		MatchActionEnumerator.KIND_PLAY_ACTION,
	]:
		return "tempo_development"
	return "highest_score"


static func _candidate_summary(candidate: Dictionary, decision_reason: String) -> String:
	return "%s | %s | reason=%s | score=%s gain=%s state=%s tactic=%s follow=%s" % [
		str(candidate.get("behavior_label", "highest_score")),
		str(candidate.get("action_summary", _action_summary(candidate.get("action", {})))),
		decision_reason,
		_format_score(float(candidate.get("total_score", 0.0))),
		_format_score(float(candidate.get("relative_gain", 0.0))),
		_format_score(float(candidate.get("state_score", 0.0))),
		_format_score(float(candidate.get("tactical_bonus", 0.0))),
		_format_score(float(candidate.get("continuation_gain", 0.0))),
	]


static func _action_summary(action: Dictionary) -> String:
	var action_id := str(action.get("id", ""))
	if not action_id.is_empty():
		return action_id
	return "%s:%s:%s" % [
		str(action.get("kind", "unknown")),
		str(action.get("player_id", "")),
		str(action.get("source_instance_id", "")),
	]


static func _format_score(value: float) -> String:
	return "%0.2f" % value


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


## Merge caller-provided options with defaults.
##
## All profile weight keys from AIPlayProfile are included here with their
## midrange defaults, so callers that don't pass any options get identical
## behaviour to the original hardcoded constants.
static func _merged_options(options: Dictionary) -> Dictionary:
	return {
		# Decision thresholds
		"min_action_gain": float(options.get("min_action_gain", DEFAULT_MIN_ACTION_GAIN)),
		"top_candidate_lookahead": int(options.get("top_candidate_lookahead", DEFAULT_TOP_CANDIDATES)),
		"lookahead_discount": float(options.get("lookahead_discount", DEFAULT_LOOKAHEAD_DISCOUNT)),
		"lookahead_depth": int(options.get("lookahead_depth", DEFAULT_LOOKAHEAD_DEPTH)),
		# Quality-driven noise (0.0 = no noise = perfect play)
		"score_noise": float(options.get("score_noise", 0.0)),
		# Tactical bonus weights (archetype-sensitive)
		"face_damage_bonus": float(options.get("face_damage_bonus", 0.25)),
		"shadow_lane_bonus": float(options.get("shadow_lane_bonus", 0.55)),
		"creature_killed_bonus": float(options.get("creature_killed_bonus", 2.3)),
		"own_creature_lost_penalty": float(options.get("own_creature_lost_penalty", 1.9)),
		"guard_removed_bonus": float(options.get("guard_removed_bonus", 1.7)),
		"threat_reduction_weight": float(options.get("threat_reduction_weight", 2.2)),
		"summon_power_weight": float(options.get("summon_power_weight", 0.4)),
		"summon_health_weight": float(options.get("summon_health_weight", 0.25)),
		# State evaluator weights (archetype-sensitive)
		"health_weight": float(options.get("health_weight", 2.5)),
		"rune_weight": float(options.get("rune_weight", 1.25)),
		"hand_weight": float(options.get("hand_weight", 0.8)),
		"opponent_hand_weight": float(options.get("opponent_hand_weight", 0.45)),
		"support_base_value": float(options.get("support_base_value", 1.1)),
		"incoming_threat_weight": float(options.get("incoming_threat_weight", 3.5)),
	}
