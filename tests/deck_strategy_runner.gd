extends SceneTree

const DeckStrategy = preload("res://src/ai/deck_strategy.gd")
const DeckStrategyCode = preload("res://src/ai/deck_strategy_code.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const HeuristicMatchPolicy = preload("res://src/ai/heuristic_match_policy.gd")


func _initialize() -> void:
	var failures: Array = []

	_test_empty_strategy(failures)
	_test_validate_dangling_refs(failures)
	_test_evaluate_condition_max_magicka(failures)
	_test_evaluate_condition_enemy_creature_power(failures)
	_test_evaluate_condition_enemy_keyword(failures)
	_test_magicka_gate_penalizes_early_play(failures)
	_test_magicka_gate_neutral_when_condition_met(failures)
	_test_magicka_gate_strict_uses_large_bonus(failures)
	_test_combo_rewards_in_order(failures)
	_test_combo_penalizes_out_of_order(failures)
	_test_combo_neutral_for_other_cards(failures)
	_test_attack_target_face_priority(failures)
	_test_attack_target_avoid_guards(failures)
	_test_mulligan_keep_overrides_default(failures)
	_test_mulligan_toss_overrides_default(failures)
	_test_codec_round_trip(failures)
	_test_codec_invalid_prefix(failures)
	_test_bias_score_returns_adjustment(failures)
	_test_heuristic_mulligan_respects_strategy(failures)

	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("DECK_STRATEGY_OK")
	quit(0)


# ── Schema / validation ──

func _test_empty_strategy(failures: Array) -> void:
	_assert(DeckStrategy.is_empty(DeckStrategy.empty_strategy()), "empty_strategy should be is_empty", failures)
	_assert(DeckStrategy.is_empty({}), "empty dict should be is_empty", failures)
	_assert(not DeckStrategy.is_empty({"rules": [{"type": "magicka_gate"}]}), "non-empty rules should not be is_empty", failures)


func _test_validate_dangling_refs(failures: Array) -> void:
	var strategy := {"rules": [
		{"type": DeckStrategy.RULE_PLAY_WHEN, "card_ids": ["card_a", "card_b"], "condition": {}},
		{"type": DeckStrategy.RULE_MULLIGAN, "entries": [{"card_id": "card_c", "direction": "keep"}]},
	]}
	var result := DeckStrategy.validate(strategy, ["card_a"])
	var warnings: Array = result.get("warnings", [])
	_assert(warnings.size() == 2, "expected 2 dangling warnings, got %d" % warnings.size(), failures)
	_assert(warnings[0].get("dangling_card_ids", []) == ["card_b"], "first warning should flag card_b", failures)


# ── Condition evaluator ──

func _test_evaluate_condition_max_magicka(failures: Array) -> void:
	var state := _make_state(7, 30, 30, [])
	var cond := {"predicate": DeckStrategy.PRED_MAX_MAGICKA, "op": ">=", "value": 7}
	_assert(DeckStrategy.evaluate_condition(cond, state, "ai"), "max_magicka >= 7 should be true at 7", failures)
	cond["value"] = 8
	_assert(not DeckStrategy.evaluate_condition(cond, state, "ai"), "max_magicka >= 8 should be false at 7", failures)


func _test_evaluate_condition_enemy_creature_power(failures: Array) -> void:
	var state := _make_state(5, 30, 30, [{"power": 6, "owner": "human"}])
	var cond := {"predicate": DeckStrategy.PRED_ENEMY_HAS_CREATURE_WITH_POWER, "value": 5}
	_assert(DeckStrategy.evaluate_condition(cond, state, "ai"), "should detect enemy creature with power >= 5", failures)
	cond["value"] = 7
	_assert(not DeckStrategy.evaluate_condition(cond, state, "ai"), "should not detect enemy creature with power >= 7", failures)


func _test_evaluate_condition_enemy_keyword(failures: Array) -> void:
	var state := _make_state(5, 30, 30, [{"power": 3, "owner": "human", "keywords": ["guard"]}])
	var cond := {"predicate": DeckStrategy.PRED_ENEMY_HAS_KEYWORD, "keyword": "guard"}
	_assert(DeckStrategy.evaluate_condition(cond, state, "ai"), "should detect enemy guard", failures)
	cond["keyword"] = "charge"
	_assert(not DeckStrategy.evaluate_condition(cond, state, "ai"), "should not detect enemy charge", failures)


# ── Score adjustment: play-when ──

func _test_magicka_gate_penalizes_early_play(failures: Array) -> void:
	var state := _make_state(3, 30, 30, [])
	_add_hand_card(state, "ai", "inst1", "expensive_finisher")
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_PLAY_WHEN,
		"card_ids": ["expensive_finisher"],
		"condition": {"predicate": DeckStrategy.PRED_MAX_MAGICKA, "op": ">=", "value": 7},
	}]}
	var action := {"kind": MatchActionEnumerator.KIND_PLAY_ACTION, "source_instance_id": "inst1"}
	var result := DeckStrategy.compute_score_adjustment(strategy, state, {}, action, "ai")
	_assert(float(result.get("adjustment", 0.0)) < 0.0, "expected negative adjustment for early play, got %s" % result.get("adjustment"), failures)
	_assert(is_equal_approx(float(result.get("adjustment", 0.0)), -DeckStrategy.BONUS_SOFT), "expected -BONUS_SOFT, got %s" % result.get("adjustment"), failures)


func _test_magicka_gate_neutral_when_condition_met(failures: Array) -> void:
	var state := _make_state(8, 30, 30, [])
	_add_hand_card(state, "ai", "inst1", "expensive_finisher")
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_PLAY_WHEN,
		"card_ids": ["expensive_finisher"],
		"condition": {"predicate": DeckStrategy.PRED_MAX_MAGICKA, "op": ">=", "value": 7},
	}]}
	var action := {"kind": MatchActionEnumerator.KIND_PLAY_ACTION, "source_instance_id": "inst1"}
	var result := DeckStrategy.compute_score_adjustment(strategy, state, {}, action, "ai")
	_assert(is_equal_approx(float(result.get("adjustment", 99.0)), 0.0), "expected 0 adjustment when gate met, got %s" % result.get("adjustment"), failures)


func _test_magicka_gate_strict_uses_large_bonus(failures: Array) -> void:
	var state := _make_state(3, 30, 30, [])
	_add_hand_card(state, "ai", "inst1", "expensive_finisher")
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_PLAY_WHEN,
		"card_ids": ["expensive_finisher"],
		"condition": {"predicate": DeckStrategy.PRED_MAX_MAGICKA, "op": ">=", "value": 7},
		"strict": true,
	}]}
	var action := {"kind": MatchActionEnumerator.KIND_PLAY_ACTION, "source_instance_id": "inst1"}
	var result := DeckStrategy.compute_score_adjustment(strategy, state, {}, action, "ai")
	_assert(is_equal_approx(float(result.get("adjustment", 0.0)), -DeckStrategy.BONUS_STRICT), "strict gate should use BONUS_STRICT, got %s" % result.get("adjustment"), failures)


# ── Score adjustment: combo ──

func _test_combo_rewards_in_order(failures: Array) -> void:
	# Combo step 0 nothing on board → playing card_a (step 0) is "next due" and should reward.
	var state := _make_state(5, 30, 30, [])
	_add_hand_card(state, "ai", "inst1", "card_a")
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_COMBO,
		"card_ids": ["card_a", "card_b", "card_c"],
		"strict": true,
	}]}
	var action := {"kind": MatchActionEnumerator.KIND_PLAY_ACTION, "source_instance_id": "inst1"}
	var result := DeckStrategy.compute_score_adjustment(strategy, state, {}, action, "ai")
	_assert(float(result.get("adjustment", 0.0)) > 0.0, "in-order combo play should reward, got %s" % result.get("adjustment"), failures)


func _test_combo_penalizes_out_of_order(failures: Array) -> void:
	var state := _make_state(5, 30, 30, [])
	_add_hand_card(state, "ai", "inst1", "card_c")  # step 2, but step 0 not yet done
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_COMBO,
		"card_ids": ["card_a", "card_b", "card_c"],
	}]}
	var action := {"kind": MatchActionEnumerator.KIND_PLAY_ACTION, "source_instance_id": "inst1"}
	var result := DeckStrategy.compute_score_adjustment(strategy, state, {}, action, "ai")
	_assert(float(result.get("adjustment", 0.0)) < 0.0, "out-of-order combo play should penalize, got %s" % result.get("adjustment"), failures)


func _test_combo_neutral_for_other_cards(failures: Array) -> void:
	var state := _make_state(5, 30, 30, [])
	_add_hand_card(state, "ai", "inst1", "unrelated_card")
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_COMBO,
		"card_ids": ["card_a", "card_b"],
	}]}
	var action := {"kind": MatchActionEnumerator.KIND_PLAY_ACTION, "source_instance_id": "inst1"}
	var result := DeckStrategy.compute_score_adjustment(strategy, state, {}, action, "ai")
	_assert(is_equal_approx(float(result.get("adjustment", 99.0)), 0.0), "unrelated card should be neutral, got %s" % result.get("adjustment"), failures)


# ── Score adjustment: attack target ──

func _test_attack_target_face_priority(failures: Array) -> void:
	var state := _make_state(5, 30, 30, [])
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_ATTACK_TARGET,
		"value": DeckStrategy.ATTACK_FACE,
	}]}
	var face_action := {"kind": MatchActionEnumerator.KIND_ATTACK, "target": {"kind": "player"}}
	var face_result := DeckStrategy.compute_score_adjustment(strategy, state, {}, face_action, "ai")
	_assert(float(face_result.get("adjustment", 0.0)) > 0.0, "face attack with face priority should reward", failures)
	var creature_action := {"kind": MatchActionEnumerator.KIND_ATTACK, "target": {"kind": "creature", "instance_id": "x"}}
	var creature_result := DeckStrategy.compute_score_adjustment(strategy, state, {}, creature_action, "ai")
	_assert(float(creature_result.get("adjustment", 0.0)) < 0.0, "creature attack with face priority should penalize", failures)


func _test_attack_target_avoid_guards(failures: Array) -> void:
	var state := _make_state(5, 30, 30, [{"power": 3, "owner": "human", "keywords": ["guard"], "instance_id": "guard1"}])
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_ATTACK_TARGET,
		"value": DeckStrategy.ATTACK_AVOID_GUARDS,
	}]}
	var action := {"kind": MatchActionEnumerator.KIND_ATTACK, "target": {"kind": "creature", "instance_id": "guard1"}}
	var result := DeckStrategy.compute_score_adjustment(strategy, state, {}, action, "ai")
	_assert(float(result.get("adjustment", 0.0)) < 0.0, "attacking guard with avoid_guards should penalize", failures)


# ── Mulligan ──

func _test_mulligan_keep_overrides_default(failures: Array) -> void:
	var hand := [{"instance_id": "i1", "definition_id": "expensive", "cost": 8}]
	var base_discards := ["i1"]  # cost-based default would discard
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_MULLIGAN,
		"entries": [{"card_id": "expensive", "direction": "keep"}],
	}]}
	var result := DeckStrategy.apply_mulligan_rules(strategy, hand, base_discards)
	_assert(not result.has("i1"), "expected keep rule to remove i1 from discards, got %s" % str(result), failures)


func _test_mulligan_toss_overrides_default(failures: Array) -> void:
	var hand := [{"instance_id": "i1", "definition_id": "low_cost", "cost": 1}]
	var base_discards: Array = []  # cost-based default would keep
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_MULLIGAN,
		"entries": [{"card_id": "low_cost", "direction": "toss"}],
	}]}
	var result := DeckStrategy.apply_mulligan_rules(strategy, hand, base_discards)
	_assert(result.has("i1"), "expected toss rule to add i1 to discards, got %s" % str(result), failures)


# ── Codec ──

func _test_codec_round_trip(failures: Array) -> void:
	var strategy := {"rules": [
		{"type": DeckStrategy.RULE_PLAY_WHEN, "card_ids": ["card_a"], "condition": {"predicate": "max_magicka", "op": ">=", "value": 7}, "strict": false},
		{"type": DeckStrategy.RULE_COMBO, "card_ids": ["a", "b"], "strict": true},
	]}
	var encoded := DeckStrategyCode.encode(strategy)
	_assert(str(encoded.get("error", "")).is_empty(), "encode error: %s" % encoded.get("error"), failures)
	_assert(str(encoded.get("code", "")).begins_with(DeckStrategyCode.PREFIX), "encoded should start with prefix", failures)
	var decoded := DeckStrategyCode.decode(encoded.get("code", ""))
	_assert(str(decoded.get("error", "")).is_empty(), "decode error: %s" % decoded.get("error"), failures)
	var round_strategy: Dictionary = decoded.get("strategy", {})
	_assert(round_strategy.get("rules", []).size() == 2, "round-trip should have 2 rules", failures)
	_assert(str(round_strategy["rules"][0].get("type", "")) == DeckStrategy.RULE_PLAY_WHEN, "first rule type preserved", failures)


func _test_codec_invalid_prefix(failures: Array) -> void:
	var decoded := DeckStrategyCode.decode("XX:not-a-real-code")
	_assert(not str(decoded.get("error", "")).is_empty(), "expected error for invalid prefix", failures)


# ── ISMCTS bias helper ──

func _test_bias_score_returns_adjustment(failures: Array) -> void:
	var state := _make_state(3, 30, 30, [])
	_add_hand_card(state, "ai", "inst1", "gated_card")
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_PLAY_WHEN,
		"card_ids": ["gated_card"],
		"condition": {"predicate": DeckStrategy.PRED_MAX_MAGICKA, "op": ">=", "value": 7},
	}]}
	var action := {"kind": MatchActionEnumerator.KIND_PLAY_ACTION, "source_instance_id": "inst1"}
	var bias := DeckStrategy.bias_score(strategy, state, action, "ai")
	_assert(is_equal_approx(bias, -DeckStrategy.BONUS_SOFT), "bias_score should equal adjustment, got %s" % bias, failures)


# ── Heuristic policy integration ──

func _test_heuristic_mulligan_respects_strategy(failures: Array) -> void:
	# An expensive card would be discarded by default; "keep" rule must override.
	var state := _make_state(1, 30, 30, [])
	for player in state.get("players", []):
		if str(player.get("player_id", "")) == "ai":
			player["hand"] = [
				{"instance_id": "i_finisher", "definition_id": "expensive_finisher", "cost": 8, "keywords": []},
				{"instance_id": "i_cheap", "definition_id": "cheap_creature", "cost": 1, "keywords": []},
			]
	var without_strategy := HeuristicMatchPolicy.choose_mulligan(state, "ai", {})
	_assert(without_strategy.has("i_finisher"), "default mulligan should discard cost-8 card, got %s" % str(without_strategy), failures)
	var strategy := {"rules": [{
		"type": DeckStrategy.RULE_MULLIGAN,
		"entries": [{"card_id": "expensive_finisher", "direction": "keep"}],
	}]}
	var with_strategy := HeuristicMatchPolicy.choose_mulligan(state, "ai", {"strategy": strategy})
	_assert(not with_strategy.has("i_finisher"), "keep rule should preserve i_finisher, got %s" % str(with_strategy), failures)


# ── Helpers ──

func _make_state(ai_max_magicka: int, ai_health: int, human_health: int, enemy_creatures: Array) -> Dictionary:
	var lanes := [
		{"lane_id": "field", "player_slots": {"ai": [], "human": []}},
		{"lane_id": "shadow", "player_slots": {"ai": [], "human": []}},
	]
	for ec in enemy_creatures:
		var card := {
			"card_type": "creature",
			"definition_id": "enemy_def",
			"instance_id": str(ec.get("instance_id", "ec_%d" % randi())),
			"base_power": int(ec.get("power", 1)),
			"base_health": 5,
			"keywords": ec.get("keywords", []),
		}
		lanes[0]["player_slots"][str(ec.get("owner", "human"))].append(card)
	return {
		"players": [
			{"player_id": "ai", "max_magicka": ai_max_magicka, "current_magicka": ai_max_magicka, "temporary_magicka": 0, "health": ai_health, "hand": [], "graveyard": [], "rune_thresholds": [25, 20, 15, 10, 5]},
			{"player_id": "human", "max_magicka": ai_max_magicka, "current_magicka": ai_max_magicka, "temporary_magicka": 0, "health": human_health, "hand": [], "graveyard": [], "rune_thresholds": [25, 20, 15, 10, 5]},
		],
		"lanes": lanes,
		"active_player_id": "ai",
		"phase": "action",
	}


func _add_hand_card(state: Dictionary, player_id: String, instance_id: String, definition_id: String) -> void:
	for player in state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			player["hand"].append({
				"instance_id": instance_id,
				"definition_id": definition_id,
				"card_type": "action",
				"cost": 4,
				"keywords": [],
			})
			return


func _assert(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		push_error(message)
		failures.append(message)
