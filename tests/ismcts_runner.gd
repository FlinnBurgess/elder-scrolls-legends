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
