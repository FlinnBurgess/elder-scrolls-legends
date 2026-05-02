extends SceneTree

const AIDeckFingerprinter = preload("res://src/ai/ai_deck_fingerprinter.gd")
const VerificationAssertions = preload("res://tests/support/verification_assertions.gd")


func _initialize() -> void:
	var failures: Array = []
	_test_empty_registry(failures)
	_test_unique_observation_collapses_posterior(failures)
	_test_neutral_observation_keeps_posterior_balanced(failures)
	_test_sample_deck_uses_distribution(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("AI_DECK_FINGERPRINTER_OK")
	quit(0)


func _test_empty_registry(failures: Array) -> void:
	var belief := AIDeckFingerprinter.init({})
	var posterior: Dictionary = belief.get("posterior", {})
	VerificationAssertions.assert_true(posterior.is_empty(), "Empty registry should produce empty posterior", failures)
	# Update on empty belief should be a no-op.
	belief = AIDeckFingerprinter.update(belief, "any_card")
	VerificationAssertions.assert_true(belief.get("posterior", {}).is_empty(), "Update on empty belief stays empty", failures)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	VerificationAssertions.assert_equal(AIDeckFingerprinter.sample_deck(belief, rng), "", "Sample on empty belief returns ''", failures)


func _test_unique_observation_collapses_posterior(failures: Array) -> void:
	# Three decks with disjoint remembered sets — observe a card unique to A.
	var memory := {
		"deck_a": ["a1", "a2", "a3"],
		"deck_b": ["b1", "b2", "b3"],
		"deck_c": ["c1", "c2", "c3"],
	}
	var belief := AIDeckFingerprinter.init(memory)
	var posterior: Dictionary = belief.get("posterior", {})
	VerificationAssertions.assert_equal(posterior.size(), 3, "Posterior should start over 3 decks", failures)
	# Observe a card unique to deck_a; deck_a should dominate posterior.
	belief = AIDeckFingerprinter.update(belief, "a1")
	belief = AIDeckFingerprinter.update(belief, "a2")
	var top := AIDeckFingerprinter.top_belief(belief)
	VerificationAssertions.assert_equal(str(top.get("deck_name", "")), "deck_a", "Top belief should be deck_a after observing two of its unique cards", failures)
	VerificationAssertions.assert_true(float(top.get("p", 0.0)) > 0.5, "Top belief P should exceed 0.5 with two unique observations", failures)


func _test_neutral_observation_keeps_posterior_balanced(failures: Array) -> void:
	# Two decks share a card — observation should keep posterior near uniform.
	var memory := {
		"deck_x": ["shared", "x_unique"],
		"deck_y": ["shared", "y_unique"],
	}
	var belief := AIDeckFingerprinter.init(memory)
	belief = AIDeckFingerprinter.update(belief, "shared")
	var posterior: Dictionary = belief.get("posterior", {})
	var px := float(posterior.get("deck_x", 0.0))
	var py := float(posterior.get("deck_y", 0.0))
	VerificationAssertions.assert_true(absf(px - py) < 0.05, "Shared-card observation should leave posterior nearly balanced (px=%f, py=%f)" % [px, py], failures)


func _test_sample_deck_uses_distribution(failures: Array) -> void:
	var memory := {
		"deck_a": ["a1"],
		"deck_b": ["b1"],
	}
	var belief := AIDeckFingerprinter.init(memory)
	# Skew posterior heavily toward deck_a.
	belief = AIDeckFingerprinter.update(belief, "a1")
	belief = AIDeckFingerprinter.update(belief, "a1")
	belief = AIDeckFingerprinter.update(belief, "a1")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var draws_a := 0
	var trials := 200
	for _i in range(trials):
		if AIDeckFingerprinter.sample_deck(belief, rng) == "deck_a":
			draws_a += 1
	# With heavy skew toward A, expect ~80%+ of draws.
	VerificationAssertions.assert_true(draws_a > trials * 0.6, "sample_deck should weight by posterior (got %d/%d for deck_a)" % [draws_a, trials], failures)
