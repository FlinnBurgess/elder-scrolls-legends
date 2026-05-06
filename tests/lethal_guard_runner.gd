extends SceneTree

const LethalGuard = preload("res://src/ai/lethal_guard.gd")
const ISMCTSMatchPolicy = preload("res://src/ai/ismcts_match_policy.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")
const VerificationAssertions = preload("res://tests/support/verification_assertions.gd")


func _initialize() -> void:
	var failures: Array = []
	_test_offensive_lethal_with_attack(failures)
	_test_compute_visible_threat_no_threat(failures)
	_test_compute_visible_threat_naked_attacker(failures)
	_test_compute_visible_threat_guard_absorbs(failures)
	_test_defensive_returns_threat_reducers(failures)
	_test_no_threat_returns_empty(failures)
	_test_policy_takes_lethal_via_guard(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("LETHAL_GUARD_OK")
	quit(0)


# ── Offensive ──

func _test_offensive_lethal_with_attack(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	ai["hand"] = []
	opp["health"] = 4
	var attacker := ScenarioFixtures.summon_creature(ai, match_state, "killer", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var lethal := LethalGuard.find_offensive_lethal(match_state, str(ai.get("player_id", "")), 3)
	VerificationAssertions.assert_true(not lethal.is_empty(), "Should find a single-action offensive lethal", failures)
	VerificationAssertions.assert_equal(str(lethal.get("kind", "")), MatchActionEnumerator.KIND_ATTACK, "First step of lethal sequence should be an attack", failures)


# ── Defensive threat math ──

func _test_compute_visible_threat_no_threat(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai_pid := str(ScenarioFixtures.player(match_state, 0).get("player_id", ""))
	var threat := LethalGuard.compute_visible_threat(match_state, ai_pid)
	VerificationAssertions.assert_equal(threat, 0, "Empty board has zero threat", failures)


func _test_compute_visible_threat_naked_attacker(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	ScenarioFixtures.summon_creature(opp, match_state, "incoming", "field", 5, 5, [], 0, {"cost": 0})
	var threat := LethalGuard.compute_visible_threat(match_state, str(ai.get("player_id", "")))
	VerificationAssertions.assert_equal(threat, 5, "Single 5-power attacker with no AI guards = 5 incoming", failures)


func _test_compute_visible_threat_guard_absorbs(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	ScenarioFixtures.summon_creature(opp, match_state, "incoming", "field", 5, 5, [], 0, {"cost": 0})
	ScenarioFixtures.summon_creature(ai, match_state, "wall", "field", 1, 4, ["guard"], 0, {"cost": 0})
	var threat := LethalGuard.compute_visible_threat(match_state, str(ai.get("player_id", "")))
	VerificationAssertions.assert_equal(threat, 1, "5 attack vs 4-hp guard = 1 face damage overflow", failures)


# ── Defensive candidate selection ──

func _test_defensive_returns_threat_reducers(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	ai["health"] = 5
	# AI has a 5/5 attacker that can kill opponent's threat.
	var blocker := ScenarioFixtures.summon_creature(ai, match_state, "blocker", "field", 5, 5, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(blocker, match_state)
	# Opponent has a 6-power threat that would otherwise lethal the AI next turn.
	ScenarioFixtures.summon_creature(opp, match_state, "the_threat", "field", 6, 4, [], 0, {"cost": 0})
	var ai_pid := str(ai.get("player_id", ""))
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, ai_pid)
	var guard_result := LethalGuard.evaluate(match_state, ai_pid, surface)
	VerificationAssertions.assert_true(guard_result.has("restricted_actions"), "Defensive guard should fire when 6-power threat > 5 health", failures)
	# The restricted set should include an attack against the_threat.
	var restricted: Array = guard_result.get("restricted_actions", [])
	var has_kill_attack := false
	for action in restricted:
		if str(action.get("kind", "")) != MatchActionEnumerator.KIND_ATTACK:
			continue
		var target: Dictionary = action.get("parameters", {}).get("target", {})
		if str(target.get("type", "")) == "creature" and str(target.get("instance_id", "")).find("the_threat") >= 0:
			has_kill_attack = true
	VerificationAssertions.assert_true(has_kill_attack, "Restricted set must include the attack that kills the lethal threat", failures)


func _test_no_threat_returns_empty(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai_pid := str(ScenarioFixtures.player(match_state, 0).get("player_id", ""))
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, ai_pid)
	var guard_result := LethalGuard.evaluate(match_state, ai_pid, surface)
	VerificationAssertions.assert_true(not guard_result.has("forced_action"), "No threat → no forced action", failures)
	VerificationAssertions.assert_true(not guard_result.has("restricted_actions"), "No threat → no restriction", failures)


# ── End-to-end via policy ──

func _test_policy_takes_lethal_via_guard(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	ai["hand"] = []
	opp["health"] = 4
	var attacker := ScenarioFixtures.summon_creature(ai, match_state, "lethal_attacker", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var ai_pid := str(ai.get("player_id", ""))
	var choice = ISMCTSMatchPolicy.choose_action(match_state, ai_pid, {"ismcts_budget_ms": 200})
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "Policy returns valid choice", failures)
	VerificationAssertions.assert_equal(str(choice.get("reason", "")), "offensive_lethal", "Policy should report offensive_lethal as the reason", failures)
	var action: Dictionary = choice.get("chosen_action", {})
	VerificationAssertions.assert_equal(str(action.get("kind", "")), MatchActionEnumerator.KIND_ATTACK, "Chosen action is the lethal attack", failures)
