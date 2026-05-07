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
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const DeckStrategy = preload("res://src/ai/deck_strategy.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")

const LETHAL_BONUS := 500000.0
const WIN_BONUS := 1000000.0

# Default values for options — match the midrange profile in AIPlayProfile.
# These are used when no options dict is provided, ensuring backward compatibility
# with existing tests and callers.
const DEFAULT_MIN_ACTION_GAIN := 0.6
const DEFAULT_TOP_CANDIDATES := 3
const DEFAULT_LOOKAHEAD_DEPTH := 1
const DEFAULT_LOOKAHEAD_DISCOUNT := 0.85
const ACTION_SCORING_BUDGET_MS := 5000


static func choose_mulligan(match_state: Dictionary, player_id: String, options: Dictionary = {}) -> Array:
	# Suppress trace logging during the entire decision: any nested simulation
	# path (clone_and_execute, validation probes, etc.) is silenced so the
	# trace log only shows real plays.
	GameLogger.suppress()
	var player := _find_player(match_state, player_id)
	if player.is_empty():
		GameLogger.unsuppress()
		return []
	var hand: Array = player.get("hand", [])
	if hand.is_empty():
		GameLogger.unsuppress()
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
	# Strategy mulligan rules override cost-based defaults.
	var strategy: Dictionary = options.get("strategy", {})
	if not strategy.is_empty():
		discard_ids = DeckStrategy.apply_mulligan_rules(strategy, hand, discard_ids)
	GameLogger.unsuppress()
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
	# Suppress trace logging during the entire AI decision: every action we
	# score uses clone_and_execute internally, but we wrap the whole thing as
	# belt-and-suspenders so any nested code path that bypasses clone_and_execute
	# is also silenced. The chosen action is committed to the live match state
	# OUTSIDE this function, so real plays still log normally.
	GameLogger.suppress()
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, player_id)
	var decision_player_id := str(surface.get("decision_player_id", ""))
	if decision_player_id.is_empty() or not str(surface.get("blocked_reason", "")).is_empty():
		GameLogger.unsuppress()
		return {"is_valid": false, "surface": surface, "reason": str(surface.get("blocked_reason", "No legal actor could be determined.")), "chosen_action": {}}
	var merged := _merged_options(options)
	var baseline := MatchStateEvaluator.evaluate_state(match_state, decision_player_id, merged)
	# Lookahead depth can be overridden by quality scaling (low quality = no lookahead).
	var lookahead := int(merged.get("lookahead_depth", DEFAULT_LOOKAHEAD_DEPTH))
	var ranked := _rank_actions(match_state, surface, decision_player_id, baseline, merged, lookahead)
	if ranked.is_empty():
		GameLogger.unsuppress()
		return {"is_valid": false, "surface": surface, "reason": "No legal actions were available.", "chosen_action": {}}

	# Apply score noise for lower-quality AI: adds random perturbation so the AI
	# occasionally picks suboptimal actions, simulating weaker play.
	var noise_amplitude := float(merged.get("score_noise", 0.0))
	if noise_amplitude > 0.0:
		_apply_score_noise(ranked, noise_amplitude, match_state)

	var chosen := _select_final_candidate(ranked, surface, baseline, merged)
	var decision_reason := _decision_reason(chosen, ranked, surface, merged)
	GameLogger.unsuppress()
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


static func _rank_actions(match_state: Dictionary, surface: Dictionary, player_id: String, baseline: float, options: Dictionary, lookahead_depth: int, _interrupt_chain: int = 0) -> Array:
	var scored: Array = []
	var budget_ms := int(options.get("action_scoring_budget_ms", ACTION_SCORING_BUDGET_MS))
	var start_ms := Time.get_ticks_msec()
	for action in surface.get("actions", []):
		if budget_ms > 0 and (Time.get_ticks_msec() - start_ms) > budget_ms:
			# Budget exceeded — score remaining actions with a fast heuristic fallback
			for remaining_action in surface.get("actions", []):
				if not scored.any(func(s): return s.get("action", {}).get("kind", "") == remaining_action.get("kind", "") and str(s.get("action", {}).get("source_instance_id", "")) == str(remaining_action.get("source_instance_id", ""))):
					scored.append({"action": remaining_action.duplicate(true), "immediate_score": -999999.0, "total_score": -999999.0, "relative_gain": -999999.0, "reason": "budget_exceeded"})
			break
		var candidate := _score_action_immediate(match_state, action, player_id, baseline, options)
		scored.append(candidate)
	scored.sort_custom(_sort_scored_actions)
	if lookahead_depth <= 0:
		return scored
	var top_count := mini(int(options.get("top_candidate_lookahead", DEFAULT_TOP_CANDIDATES)), scored.size())
	for index in range(top_count):
		if budget_ms > 0 and (Time.get_ticks_msec() - start_ms) > budget_ms:
			break
		var candidate: Dictionary = scored[index]
		if _is_pass_action(candidate.get("action", {})) or not _can_continue_turn(candidate.get("simulated_state", {}), player_id):
			continue
		var continuation_gain := _best_followup_gain(candidate.get("simulated_state", {}), player_id, options, lookahead_depth, _interrupt_chain)
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
	# Apply per-deck strategy adjustments (soft prior).
	var strategy: Dictionary = options.get("strategy", {})
	var strategy_adj := 0.0
	var strategy_attribution: Array = []
	if not strategy.is_empty():
		var adj_result := DeckStrategy.compute_score_adjustment(strategy, match_state, simulated_state, action, player_id)
		strategy_adj = float(adj_result.get("adjustment", 0.0))
		strategy_attribution = adj_result.get("attribution", [])
		# Diagnostic: log strategy evaluation for play actions.
		if DeckStrategy._is_play_action(str(action.get("kind", ""))):
			var def_dbg := DeckStrategy._action_played_definition_id(action, match_state, player_id)
			var p_dbg := _find_player(match_state, player_id)
			print("[strategy-debug] kind=%s def=%s max_magicka=%d strategy_adj=%.1f attrib=%s" % [
				str(action.get("kind", "")),
				def_dbg,
				int(p_dbg.get("max_magicka", 0)),
				strategy_adj,
				str(strategy_attribution),
			])
	var total := state_score + tactical_bonus + strategy_adj
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
		"strategy_adjustment": strategy_adj,
		"strategy_attribution": strategy_attribution,
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


static func _best_followup_gain(match_state: Dictionary, player_id: String, options: Dictionary, remaining_depth: int, _interrupt_chain: int = 0) -> float:
	if remaining_depth <= 0 or not _can_continue_turn(match_state, player_id):
		return 0.0
	var baseline := MatchStateEvaluator.evaluate_state(match_state, player_id, options)
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, player_id)
	# Interrupt windows (summon effect targets, secondary targets, etc.) are
	# sub-decisions of the parent action — don't consume a lookahead ply.
	# This lets the AI see through "play card → choose target → attack" sequences
	# without needing extra lookahead depth.
	var is_interrupt := str(surface.get("timing_window", "")) == MatchActionEnumerator.TIMING_INTERRUPT
	var child_depth: int
	if is_interrupt and _interrupt_chain < 3:
		child_depth = remaining_depth
	else:
		child_depth = remaining_depth - 1
	var next_chain := (_interrupt_chain + 1) if is_interrupt else 0
	var ranked := _rank_actions(match_state, surface, player_id, baseline, options, child_depth, next_chain)
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
				var face_damage := float(int(before_opponent.get("health", 0)) - int(after_opponent.get("health", 0)))
				bonus += face_damage * face_damage_w
				# The state evaluator gives a "can attack now" bonus to attack-ready
				# creatures (1.2 + power * 0.35). After attacking face the creature
				# has has_attacked_this_turn=true, so it loses that bonus in the
				# post-action evaluation. Compensate here so the AI doesn't think
				# the attack was a net loss — the readiness was converted into
				# actual face damage, not wasted.
				bonus += 1.2 + face_damage * 0.35
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
		MatchActionEnumerator.KIND_PLAY_SUPPORT_SACRIFICE:
			bonus += 0.35
		MatchActionEnumerator.KIND_ACTIVATE_SUPPORT:
			bonus += 0.65
		MatchActionEnumerator.KIND_PLAY_ACTION:
			bonus += 0.55
			bonus += _removal_efficiency_adjustment(before_state, after_state, player_id, opponent_id, spent_magicka)
			bonus += _control_action_efficiency_adjustment(before_state, after_state, action, player_id, opponent_id, spent_magicka)
			bonus += _prophecy_damage_efficiency_adjustment(before_state, action, player_id, opponent_id, options)
		MatchActionEnumerator.KIND_PLAY_ITEM:
			# _PLAY_ITEM already added +0.75 above; apply efficiency check for damage items.
			bonus += _removal_efficiency_adjustment(before_state, after_state, player_id, opponent_id, spent_magicka)
		MatchActionEnumerator.KIND_DECLINE_PROPHECY:
			bonus += 0.15
	return bonus


## Penalize high-cost removal spent on low-value targets when the AI is safe.
##
## Without this, the flat creature_killed_bonus + threat_reduction rewards + the
## spent_magicka reward cause the AI to happily burn a 5-cost removal on a 1/1
## even at full HP. We compare the value of creatures actually destroyed against
## the mana spent, and scale any "wasteful overkill" penalty by how safe the AI
## is — when at 1 HP, keeping the 1/1 alive one more turn may itself be lethal,
## so the penalty collapses to zero.
static func _removal_efficiency_adjustment(before_state: Dictionary, after_state: Dictionary, player_id: String, opponent_id: String, spent_magicka: float) -> float:
	# Free plays and near-free removal don't need efficiency policing.
	if spent_magicka <= 1.0:
		return 0.0
	# Collect opponent creatures before and after so we can identify which ones died.
	var before_cards := {}
	for lane in before_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(opponent_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				before_cards[str(card.get("instance_id", ""))] = card
	var after_ids := {}
	for lane in after_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(opponent_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				after_ids[str(card.get("instance_id", ""))] = true
	var removed_value := 0.0
	var removed_count := 0
	for instance_id in before_cards.keys():
		if not after_ids.has(instance_id):
			removed_value += MatchStateEvaluator._creature_value(before_state, before_cards[instance_id])
			removed_count += 1
	# No creatures removed — action may have other valuable effects (draw, damage
	# face, etc.) that state_score already captures. Don't penalize.
	if removed_count == 0:
		return 0.0
	# Waste = mana cost minus total value of the creatures we actually destroyed.
	# A 5-cost removal killing a value-2 creature wastes ~3 units.
	var waste := spent_magicka - removed_value
	if waste <= 0.0:
		return 0.0  # Cost-effective removal.
	# Scale by how safe the AI is. At full HP we should save removal for real
	# threats; near lethal, any creature is worth removing even inefficiently.
	var player := _find_player(before_state, player_id)
	var player_hp := maxf(0.0, float(int(player.get("health", 30))))
	const REFERENCE_MAX_HP := 30.0
	var safety_factor := clampf(player_hp / REFERENCE_MAX_HP, 0.0, 1.0)
	# Weight 1.0 per wasted mana roughly cancels the spent_magicka + creature-kill
	# bonuses when the removal is purely over-cost (e.g. 5-mana on a 1/1).
	const WASTE_PENALTY_WEIGHT := 1.0
	return -waste * WASTE_PENALTY_WEIGHT * safety_factor


## Penalize single-target PLAY_ACTION cards (silence, shackle, small damage)
## when the target barely loses any value. Without this, the +0.55 play_action
## and +0.45 * spent_magicka tactical bonuses make the AI eagerly silence vanilla
## creatures or creatures whose only ability was a summon trigger that already
## fired — a wasted card with nothing to strip.
static func _control_action_efficiency_adjustment(before_state: Dictionary, after_state: Dictionary, action: Dictionary, player_id: String, opponent_id: String, spent_magicka: float) -> float:
	var parameters: Dictionary = action.get("parameters", {})
	var target_id := str(parameters.get("target_instance_id", ""))
	if target_id.is_empty():
		return 0.0
	var before_target := _find_card(before_state, target_id)
	if before_target.is_empty():
		return 0.0
	if str(before_target.get("controller_player_id", "")) != opponent_id:
		return 0.0
	var after_target := _find_card(after_state, target_id)
	# Removal is handled separately.
	if after_target.is_empty():
		return 0.0
	var before_value := MatchStateEvaluator._creature_value(before_state, before_target)
	var after_value := MatchStateEvaluator._creature_value(after_state, after_target)
	var value_stripped := before_value - after_value
	var threat_reduction := float(_incoming_face_threat(before_state, player_id) - _incoming_face_threat(after_state, player_id))
	var total_benefit := value_stripped + maxf(0.0, threat_reduction) * 2.2
	const MIN_USEFUL_BENEFIT := 2.5
	if total_benefit >= MIN_USEFUL_BENEFIT:
		return 0.0
	# Proportional shortfall — when the target barely loses value, cancel most
	# of the generic +0.55 play_action bonus and +0.45*spent_magicka bonus so
	# the state_score delta alone decides if the action is worthwhile.
	var shortfall := clampf((MIN_USEFUL_BENEFIT - total_benefit) / MIN_USEFUL_BENEFIT, 0.0, 1.0)
	return -(0.55 + 0.45 * spent_magicka) * shortfall


## Penalize "spending" a free Prophecy damage action on a creature it can't kill
## when no follow-up exists to finish the kill, biasing the AI toward declining
## the Prophecy and saving the card for a more decisive moment.
##
## A free Prophecy damage spell pays no magicka, so spent_magicka penalties
## don't kick in — leaving the existing threat-reduction reward to make any
## partial-damage play look attractive. This function asks: would I actually
## be able to convert the partial damage into a kill (now or next turn), or
## am I "wasting" the free play that could have been a real kill later?
static func _prophecy_damage_efficiency_adjustment(before_state: Dictionary, action: Dictionary, player_id: String, opponent_id: String, options: Dictionary) -> float:
	if not bool(action.get("played_for_free", false)):
		return 0.0
	if str(action.get("response_kind", "")) != MatchTiming.RULE_TAG_PROPHECY:
		return 0.0
	var source_instance_id := str(action.get("source_instance_id", ""))
	var source_card := _find_card(before_state, source_instance_id)
	if source_card.is_empty():
		return 0.0
	var damage := _extract_pure_damage_amount(source_card)
	if damage <= 0:
		return 0.0
	var enemy_creatures := _enemy_creatures_with_locations(before_state, opponent_id)
	if enemy_creatures.is_empty():
		return 0.0  # No creature targets — let the existing scoring handle face damage.
	# Lethal-now check: any creature dies outright?
	for entry in enemy_creatures:
		var c: Dictionary = entry.get("card", {})
		var hp := int(c.get("current_health", c.get("health", 0)))
		if damage >= hp and hp > 0:
			return 0.0
	# Pick the lowest-HP enemy creature as the target the AI is most likely to chase.
	var best_entry: Dictionary = enemy_creatures[0]
	for entry in enemy_creatures:
		var c: Dictionary = entry.get("card", {})
		var b: Dictionary = best_entry.get("card", {})
		if int(c.get("current_health", c.get("health", 0))) < int(b.get("current_health", b.get("health", 0))):
			best_entry = entry
	var target_card: Dictionary = best_entry.get("card", {})
	var target_lane: String = str(best_entry.get("lane_id", ""))
	var target_hp_before := int(target_card.get("current_health", target_card.get("health", 0)))
	if target_hp_before <= 0:
		return 0.0
	var target_hp_after := target_hp_before - damage
	# Hand follow-up: any non-prophecy-source action card in hand that can finish?
	if _hand_can_finish(before_state, player_id, source_instance_id, target_hp_after):
		return 0.0
	# On-board reach (next turn). 50/50 coin flip on whether the wounded target
	# survives the opponent's remaining turn — adds variety while staying
	# deterministic (seeded from turn + target + player id).
	var optimistic := _prophecy_target_survives_coin_flip(before_state, target_card, player_id)
	if optimistic and _onboard_can_finish(before_state, player_id, opponent_id, target_lane, target_card, target_hp_after):
		return 0.0
	# Save-for-later viability: next turn can pay AND there's another playable card.
	var save_viable := _save_for_later_viable(before_state, player_id, source_card)
	# Cancel the state-eval reward perceived from partial damage. The 2.5/dmg
	# coefficient is calibrated to outweigh the AI's perceived gain (state delta +
	# play_action bonus) while still letting safety_factor / save_modulation
	# soften the penalty when the play is genuinely the right call.
	var perceived_gain := float(damage) * 2.5
	# Scale by remaining-HP fraction: barely-scratched (high fraction) takes full
	# hit; near-death (low fraction) keeps a smaller penalty since partial damage
	# was real progress.
	var fraction := float(maxi(target_hp_after, 0)) / float(maxi(1, target_hp_before))
	var progress_factor := 0.7 + 0.5 * fraction
	var base_penalty := perceived_gain * progress_factor + 2.0
	# Safety scaling: at low HP, even partial damage is worth doing — let the
	# regular reward win. Mirrors the safety_factor in _removal_efficiency_adjustment.
	var player := _find_player(before_state, player_id)
	var player_hp := maxf(0.0, float(int(player.get("health", 30))))
	const REFERENCE_MAX_HP := 30.0
	var safety_factor := clampf(player_hp / REFERENCE_MAX_HP, 0.0, 1.0)
	# If save-for-later isn't realistic (no leftover for another card), declining
	# offers little benefit so the penalty halves.
	var save_modulation := 1.0 if save_viable else 0.5
	return -base_penalty * safety_factor * save_modulation


static func _extract_pure_damage_amount(card: Dictionary) -> int:
	var triggers: Array = card.get("triggered_abilities", [])
	if triggers.size() != 1:
		return 0
	var trigger: Dictionary = triggers[0] if typeof(triggers[0]) == TYPE_DICTIONARY else {}
	var effects: Array = trigger.get("effects", [])
	if effects.size() != 1:
		return 0
	var effect: Dictionary = effects[0] if typeof(effects[0]) == TYPE_DICTIONARY else {}
	if str(effect.get("op", "")) != "deal_damage":
		return 0
	# Only single-target damage; skip AOE / pre-targeted variants.
	var tgt := str(effect.get("target", ""))
	if tgt != "event_target" and tgt != "":
		return 0
	return int(effect.get("amount", 0))


static func _enemy_creatures_with_locations(match_state: Dictionary, opponent_id: String) -> Array:
	var result: Array = []
	for lane in match_state.get("lanes", []):
		var lane_id := str(lane.get("lane_id", ""))
		for card in lane.get("player_slots", {}).get(opponent_id, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature":
				result.append({"card": card, "lane_id": lane_id})
	return result


static func _hand_can_finish(match_state: Dictionary, player_id: String, exclude_instance_id: String, remaining_hp: int) -> bool:
	if remaining_hp <= 0:
		return true
	var player := _find_player(match_state, player_id)
	for card in player.get("hand", []):
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if str(card.get("instance_id", "")) == exclude_instance_id:
			continue
		if str(card.get("card_type", "")) != "action":
			continue
		var dmg := _max_damage_from_card(card)
		if dmg >= remaining_hp:
			return true
	return false


## Return the largest single-target damage amount the card can deliver via any
## of its triggered abilities. Used as a follow-up screen for finishing wounded
## targets — keep the heuristic loose since the AI doesn't need to confirm
## targeting legality, just feasibility.
static func _max_damage_from_card(card: Dictionary) -> int:
	var max_dmg := 0
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		for effect in trigger.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			if str(effect.get("op", "")) != "deal_damage":
				continue
			max_dmg = maxi(max_dmg, int(effect.get("amount", 0)))
	return max_dmg


static func _onboard_can_finish(match_state: Dictionary, player_id: String, opponent_id: String, target_lane: String, target_card: Dictionary, remaining_hp: int) -> bool:
	if remaining_hp <= 0:
		return true
	var target_id := str(target_card.get("instance_id", ""))
	var ai_power_in_lane := 0
	var guard_hp := 0
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != target_lane:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				ai_power_in_lane += EvergreenRules.get_power(card)
		for card in lane.get("player_slots", {}).get(opponent_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			# The wounded target itself is what we're trying to reach — exclude it
			# from the guard wall so we don't double-count its own remaining HP.
			if str(card.get("instance_id", "")) == target_id:
				continue
			if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
				guard_hp += EvergreenRules.get_remaining_health(card)
	var effective_hp := remaining_hp + guard_hp
	return ai_power_in_lane >= effective_hp


## Deterministic 50/50 coin flip on whether the wounded prophecy target survives
## the opponent's remaining turn. Seeded from turn + target instance_id + player
## so the same scenario reproduces across replays but different prophecies in
## the same turn flip independently.
static func _prophecy_target_survives_coin_flip(match_state: Dictionary, target_card: Dictionary, player_id: String) -> bool:
	var seed_value := int(match_state.get("turn_number", 0))
	seed_value = seed_value * 1315423911 + str(target_card.get("instance_id", "")).hash()
	seed_value = seed_value * 1315423911 + player_id.hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randi() % 2 == 0


static func _save_for_later_viable(match_state: Dictionary, player_id: String, source_card: Dictionary) -> bool:
	var player := _find_player(match_state, player_id)
	var current_max := int(player.get("max_magicka", 0))
	var card_cost := int(source_card.get("cost", 0))
	var next_max := mini(MatchTurnLoop.MAX_MAGICKA_CAP, current_max + 1)
	if card_cost > next_max:
		return false
	var leftover := next_max - card_cost
	var source_id := str(source_card.get("instance_id", ""))
	for card in player.get("hand", []):
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if str(card.get("instance_id", "")) == source_id:
			continue
		if int(card.get("cost", 0)) <= leftover:
			return true
	return false


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
		MatchActionEnumerator.KIND_PLAY_SUPPORT_SACRIFICE,
		MatchActionEnumerator.KIND_PLAY_ITEM,
		MatchActionEnumerator.KIND_ACTIVATE_SUPPORT,
		MatchActionEnumerator.KIND_PLAY_ACTION,
	]:
		return "tempo_development"
	return "highest_score"


static func _candidate_summary(candidate: Dictionary, decision_reason: String) -> String:
	var base := "%s | %s | reason=%s | score=%s gain=%s state=%s tactic=%s follow=%s" % [
		str(candidate.get("behavior_label", "highest_score")),
		str(candidate.get("action_summary", _action_summary(candidate.get("action", {})))),
		decision_reason,
		_format_score(float(candidate.get("total_score", 0.0))),
		_format_score(float(candidate.get("relative_gain", 0.0))),
		_format_score(float(candidate.get("state_score", 0.0))),
		_format_score(float(candidate.get("tactical_bonus", 0.0))),
		_format_score(float(candidate.get("continuation_gain", 0.0))),
	]
	var attribution: Array = candidate.get("strategy_attribution", [])
	if not attribution.is_empty():
		var parts: Array = []
		for entry in attribution:
			parts.append("%s%s" % [str(entry.get("note", "")), _format_score(float(entry.get("delta", 0.0)))])
		base += " strategy=[" + ", ".join(parts) + "]"
	return base


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
		# Per-deck strategy guide (passed through unchanged — it's a structured
		# rule list, not a numeric weight).
		"strategy": options.get("strategy", {}),
	}
