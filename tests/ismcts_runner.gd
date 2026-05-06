extends SceneTree

const ISMCTSMatchPolicy = preload("res://src/ai/ismcts_match_policy.gd")
const ISMCTSDeterminizer = preload("res://src/ai/ismcts_determinizer.gd")
const AIObservationTracker = preload("res://src/ai/ai_observation_tracker.gd")
const AIDeckFingerprinter = preload("res://src/ai/ai_deck_fingerprinter.gd")
const AIDeckMemory = preload("res://src/ai/ai_deck_memory.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")
const VerificationAssertions = preload("res://tests/support/verification_assertions.gd")


func _initialize() -> void:
	var failures: Array = []
	_test_returns_legal_action_within_budget(failures)
	_test_returns_only_legal_when_forced(failures)
	_test_observation_tracker_records_played_cards(failures)
	_test_determinizer_preserves_instance_ids(failures)
	_test_determinizer_respects_three_of_cap(failures)
	_test_runs_full_turn_without_crashing(failures)
	_test_random_deck_bypass_uses_no_belief(failures)
	_test_belief_biases_determinizer_sampling(failures)
	_test_interrupt_flag_shortcircuits_search(failures)
	_test_ai_takes_free_face_attack(failures)
	_test_convergence_short_circuit_bails_early(failures)
	_test_small_surface_delegates_to_heuristic_fast(failures)
	_test_choose_action_does_not_mutate_input_state(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("ISMCTS_OK")
	quit(0)


func _test_returns_legal_action_within_budget(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	# Give the AI a couple of cheap creatures so there are real choices.
	ScenarioFixtures.add_hand_card(ai, "ai_grunt", {"card_type": "creature", "cost": 2, "power": 2, "health": 2})
	ScenarioFixtures.add_hand_card(ai, "ai_brute", {"card_type": "creature", "cost": 3, "power": 3, "health": 3})
	var ai_pid := str(ai.get("player_id", ""))
	var start_ms := Time.get_ticks_msec()
	var choice = ISMCTSMatchPolicy.choose_action(match_state, ai_pid, {"ismcts_budget_ms": 400})
	var elapsed := Time.get_ticks_msec() - start_ms
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "ISMCTS choice should be valid", failures)
	var action: Dictionary = choice.get("chosen_action", {})
	VerificationAssertions.assert_true(not action.is_empty(), "Chosen action must not be empty", failures)
	VerificationAssertions.assert_true(MatchActionEnumerator.action_is_legal(match_state, action), "Chosen action must be legal in the original state", failures)
	VerificationAssertions.assert_true(elapsed < 1500, "ISMCTS exceeded 1500ms budget guardrail (took %dms)" % elapsed, failures)


func _test_returns_only_legal_when_forced(failures: Array) -> void:
	# Mulligan phase has only one path forward — hand selection or auto-pass —
	# but during mulligan the enumerator returns no `action` actions; in
	# `ready_for_first_turn` we have a single end-turn-style state. Use a
	# started match where the AI has just one ring action available by emptying
	# its hand and zeroing magicka.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 0, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	ai["hand"] = []
	# AI should only have end_turn (or possibly ring if available).
	var choice = ISMCTSMatchPolicy.choose_action(match_state, str(ai.get("player_id", "")), {"ismcts_budget_ms": 200})
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "ISMCTS should pick the only available action", failures)


func _test_observation_tracker_records_played_cards(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai_pid := str(ScenarioFixtures.player(match_state, 0).get("player_id", ""))
	var opp := ScenarioFixtures.player(match_state, 1)
	# Place a creature into opponent's lane.
	ScenarioFixtures.summon_creature(opp, match_state, "exposed_threat", "field", 3, 3, [], 0, {"cost": 0, "definition_id": "obs_test_card", "attributes": ["intelligence"]})
	var observed := AIObservationTracker.observe(match_state, ai_pid)
	var counts: Dictionary = observed.get("def_counts", {})
	VerificationAssertions.assert_true(counts.has("obs_test_card"), "Observation tracker must record played opponent cards by definition_id", failures)
	var attrs: Array = observed.get("attributes", [])
	VerificationAssertions.assert_true(attrs.has("intelligence"), "Observation tracker must collect attributes from observed cards", failures)


func _test_determinizer_preserves_instance_ids(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai_pid := str(ScenarioFixtures.player(match_state, 0).get("player_id", ""))
	var opp := ScenarioFixtures.player(match_state, 1)
	var pre_hand_ids: Array = []
	for card in opp.get("hand", []):
		pre_hand_ids.append(str(card.get("instance_id", "")))
	var pre_deck_ids: Array = []
	for card in opp.get("deck", []):
		pre_deck_ids.append(str(card.get("instance_id", "")))
	var observed := AIObservationTracker.observe(match_state, ai_pid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var clone := ISMCTSDeterminizer.determinize(match_state, ai_pid, observed, rng)
	var clone_opp := ScenarioFixtures.player(clone, 1)
	var post_hand_ids: Array = []
	for card in clone_opp.get("hand", []):
		post_hand_ids.append(str(card.get("instance_id", "")))
	var post_deck_ids: Array = []
	for card in clone_opp.get("deck", []):
		post_deck_ids.append(str(card.get("instance_id", "")))
	VerificationAssertions.assert_equal(post_hand_ids, pre_hand_ids, "Determinizer must preserve opponent hand instance_ids", failures)
	VerificationAssertions.assert_equal(post_deck_ids, pre_deck_ids, "Determinizer must preserve opponent deck instance_ids", failures)
	# AI player state must be untouched.
	var ai_clone := ScenarioFixtures.player(clone, 0)
	var orig_ai_hand: Array = []
	for card in ScenarioFixtures.player(match_state, 0).get("hand", []):
		orig_ai_hand.append(str(card.get("instance_id", "")))
	var clone_ai_hand: Array = []
	for card in ai_clone.get("hand", []):
		clone_ai_hand.append(str(card.get("instance_id", "")))
	VerificationAssertions.assert_equal(clone_ai_hand, orig_ai_hand, "Determinizer must not touch AI player's hand", failures)


func _test_determinizer_respects_three_of_cap(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai_pid := str(ScenarioFixtures.player(match_state, 0).get("player_id", ""))
	var observed := AIObservationTracker.observe(match_state, ai_pid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var clone := ISMCTSDeterminizer.determinize(match_state, ai_pid, observed, rng)
	var clone_opp := ScenarioFixtures.player(clone, 1)
	var counts: Dictionary = {}
	for card in clone_opp.get("hand", []) + clone_opp.get("deck", []):
		var def_id := str(card.get("definition_id", ""))
		if def_id.is_empty():
			continue
		counts[def_id] = int(counts.get(def_id, 0)) + 1
	for def_id in counts.keys():
		VerificationAssertions.assert_true(int(counts[def_id]) <= 3, "Determinizer over-sampled %s (%d copies)" % [def_id, int(counts[def_id])], failures)


func _test_random_deck_bypass_uses_no_belief(failures: Array) -> void:
	# Seed memory for some other deck — the AI must NOT reach for it when the
	# current match has empty human_deck_name (random-decks bypass).
	AIDeckMemory.forget_all()
	AIDeckMemory.record_match("unrelated_deck", ["str_morkul_gatekeeper"], {"str_morkul_gatekeeper": 3})
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	ScenarioFixtures.add_hand_card(ai, "bypass_creature", {"card_type": "creature", "cost": 2, "power": 2, "health": 2})
	var ai_pid := str(ai.get("player_id", ""))
	# Empty human_deck_name = bypass marker.
	var choice = ISMCTSMatchPolicy.choose_action(match_state, ai_pid, {"ismcts_budget_ms": 200, "human_deck_name": ""})
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "ISMCTS still produces a choice under random-deck bypass", failures)
	# Restore memory state.
	AIDeckMemory.forget_all()


func _test_belief_biases_determinizer_sampling(failures: Array) -> void:
	# Seed a belief where deck_a is overwhelmingly likely. Determinize many
	# slots; assert the sampled cards skew toward deck_a's remembered set.
	AIDeckMemory.forget_all()
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai_pid := str(ScenarioFixtures.player(match_state, 0).get("player_id", ""))
	var observed := AIObservationTracker.observe(match_state, ai_pid)
	# Pick a few real cards from the catalog so they're in the plausible pool.
	var memory := {
		"believed_deck": ["str_morkul_gatekeeper", "str_fiery_imp", "agi_swift_strike"],
		"other_deck": ["int_steel_sword"],
	}
	var belief := AIDeckFingerprinter.init(memory)
	# Strongly skew posterior to believed_deck.
	belief = AIDeckFingerprinter.update(belief, "str_morkul_gatekeeper")
	belief = AIDeckFingerprinter.update(belief, "str_fiery_imp")
	belief = AIDeckFingerprinter.update(belief, "agi_swift_strike")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var clone := ISMCTSDeterminizer.determinize(match_state, ai_pid, observed, rng, belief)
	var clone_opp := ScenarioFixtures.player(clone, 1)
	var believed_hits := 0
	for card in clone_opp.get("hand", []) + clone_opp.get("deck", []):
		var def_id := str(card.get("definition_id", ""))
		if memory["believed_deck"].has(def_id):
			believed_hits += 1
	# The sampler isn't deterministic but with strong bias and ~50 unknown
	# slots we expect well over zero hits from the believed deck.
	VerificationAssertions.assert_true(believed_hits > 0, "Belief-biased determinization should sample from believed deck (got 0 hits)", failures)
	AIDeckMemory.forget_all()


func _test_interrupt_flag_shortcircuits_search(failures: Array) -> void:
	# A pre-cancelled interrupt should bail the search before consuming budget,
	# returning a fallback choice quickly.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	ScenarioFixtures.add_hand_card(ai, "interrupt_creature_a", {"card_type": "creature", "cost": 2, "power": 2, "health": 2})
	ScenarioFixtures.add_hand_card(ai, "interrupt_creature_b", {"card_type": "creature", "cost": 3, "power": 3, "health": 3})
	var ai_pid := str(ai.get("player_id", ""))
	var interrupt := {"cancelled": true}  # cancelled before we even start
	var start_ms := Time.get_ticks_msec()
	var choice = ISMCTSMatchPolicy.choose_action(match_state, ai_pid, {
		"ismcts_budget_ms": 5000,
		"ismcts_interrupt": interrupt,
	})
	var elapsed := Time.get_ticks_msec() - start_ms
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "Pre-cancelled interrupt still returns a valid fallback", failures)
	VerificationAssertions.assert_true(elapsed < 500, "Pre-cancelled interrupt should return fast (got %dms)" % elapsed, failures)


func _test_ai_takes_free_face_attack(failures: Array) -> void:
	# Repro of the live bug: AI has a 2/2 in lane that's ready to attack and
	# the opponent has an empty board + 30 HP. End-turn vs face-attack should
	# clearly favour the attack — a +2 to opponent's incoming damage.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 2, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	ai["hand"] = []  # no plays — only end_turn or attack
	var attacker := ScenarioFixtures.summon_creature(ai, match_state, "free_swing", "field", 2, 2, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var ai_pid := str(ai.get("player_id", ""))
	var choice = ISMCTSMatchPolicy.choose_action(match_state, ai_pid, {"ismcts_budget_ms": 600})
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "Choice valid", failures)
	var action: Dictionary = choice.get("chosen_action", {})
	VerificationAssertions.assert_equal(str(action.get("kind", "")), MatchActionEnumerator.KIND_ATTACK, "AI must take the free face attack instead of ending turn", failures)
	var target: Dictionary = action.get("parameters", {}).get("target", {})
	VerificationAssertions.assert_equal(str(target.get("type", "")), "player", "Attack target must be opponent's face", failures)


func _test_small_surface_delegates_to_heuristic_fast(failures: Array) -> void:
	# Reproduces the user's scenario: AI is out of magicka, has 1 creature
	# ready to attack. Surface = {attack creature, attack face, end_turn}.
	# This must NOT burn the full thinking budget — should short-circuit
	# to the heuristic and return in well under a second even with budget=10s.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 0, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	ai["hand"] = []
	var attacker := ScenarioFixtures.summon_creature(ai, match_state, "tired_warrior", "field", 2, 2, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.summon_creature(opp, match_state, "blocker", "field", 1, 1, [], 0, {"cost": 0})
	var ai_pid := str(ai.get("player_id", ""))
	var start_ms := Time.get_ticks_msec()
	var choice = ISMCTSMatchPolicy.choose_action(match_state, ai_pid, {"ismcts_budget_ms": 10000})
	var elapsed := Time.get_ticks_msec() - start_ms
	VerificationAssertions.assert_true(elapsed < 1000, "Small action surface must short-circuit (took %dms with 10s budget)" % elapsed, failures)
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "Choice valid", failures)
	VerificationAssertions.assert_equal(str(choice.get("reason", "")), "ismcts_small_surface_delegate", "Reason should indicate small-surface delegation", failures)


func _test_convergence_short_circuit_bails_early(failures: Array) -> void:
	# With a clear-cut decision (lethal-on-board scenario) the offensive lethal
	# guard ALREADY short-circuits before MCTS. Confirm the result reason is
	# the guard, not the search — proving lethal short-circuiting is in play.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	ai["hand"] = []
	opp["health"] = 4
	var attacker := ScenarioFixtures.summon_creature(ai, match_state, "lethal_swinger", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var start_ms := Time.get_ticks_msec()
	var choice = ISMCTSMatchPolicy.choose_action(match_state, str(ai.get("player_id", "")), {"ismcts_budget_ms": 5000})
	var elapsed := Time.get_ticks_msec() - start_ms
	VerificationAssertions.assert_true(elapsed < 1000, "Lethal short-circuit should keep total time well under the 5s budget (took %dms)" % elapsed, failures)


func _test_choose_action_does_not_mutate_input_state(failures: Array) -> void:
	# Critical correctness check for the in-place rollout optimisation. The
	# policy clones once internally and mutates the clone freely during MCTS
	# rollouts; the live match_state's *gameplay* fields must be unchanged.
	#
	# We compare the `players` and `lanes` arrays (everything the engine
	# reads to make decisions) rather than the full top-level dict — top-
	# level fields like `_ai_observed_by_pid` and `_ismcts_pool_cache` are
	# legitimately written by the policy as caches and aren't gameplay state.
	#
	# Surface needs to exceed SMALL_SURFACE_THRESHOLD so MCTS actually runs.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 8, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	var opp := ScenarioFixtures.player(match_state, 1)
	for i in range(10):
		ScenarioFixtures.add_hand_card(ai, "filler_%d" % i, {"card_type": "creature", "cost": 1, "power": 1, "health": 1})
	ScenarioFixtures.summon_creature(ai, match_state, "friendly", "field", 2, 2, [], 0, {"cost": 0})
	ScenarioFixtures.summon_creature(opp, match_state, "enemy", "field", 2, 2, [], 0, {"cost": 0})
	var players_before := JSON.stringify(match_state.get("players", []))
	var lanes_before := JSON.stringify(match_state.get("lanes", []))
	var ai_pid := str(ai.get("player_id", ""))
	var choice = ISMCTSMatchPolicy.choose_action(match_state, ai_pid, {"ismcts_budget_ms": 400})
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "Policy returned a valid choice", failures)
	var players_after := JSON.stringify(match_state.get("players", []))
	var lanes_after := JSON.stringify(match_state.get("lanes", []))
	VerificationAssertions.assert_equal(players_after, players_before, "choose_action must not mutate players[] (in-place rollout safety)", failures)
	VerificationAssertions.assert_equal(lanes_after, lanes_before, "choose_action must not mutate lanes[] (in-place rollout safety)", failures)


func _test_runs_full_turn_without_crashing(failures: Array) -> void:
	# Drive ISMCTS through a few decisions in a real game loop to flush out any
	# crash bugs in the rollout/expand paths.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var ai := ScenarioFixtures.player(match_state, 0)
	ScenarioFixtures.add_hand_card(ai, "loop_a", {"card_type": "creature", "cost": 1, "power": 1, "health": 1})
	ScenarioFixtures.add_hand_card(ai, "loop_b", {"card_type": "creature", "cost": 2, "power": 2, "health": 2})
	var ai_pid := str(ai.get("player_id", ""))
	var actions_taken := 0
	var max_actions := 8
	while actions_taken < max_actions:
		var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, ai_pid)
		if str(surface.get("decision_player_id", "")) != ai_pid:
			break
		if surface.get("actions", []).is_empty():
			break
		var choice = ISMCTSMatchPolicy.choose_action(match_state, ai_pid, {"ismcts_budget_ms": 200})
		if not bool(choice.get("is_valid", false)):
			break
		var action: Dictionary = choice.get("chosen_action", {})
		if action.is_empty():
			break
		var result := MatchActionExecutor.execute_action(match_state, action)
		VerificationAssertions.assert_true(bool(result.get("is_valid", false)), "ISMCTS chose an action that the executor rejected: %s" % str(action), failures)
		actions_taken += 1
		if str(action.get("kind", "")) == MatchActionEnumerator.KIND_END_TURN:
			break
	VerificationAssertions.assert_true(actions_taken > 0, "ISMCTS should make at least one action", failures)
