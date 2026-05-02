extends SceneTree

const AIDeckMemory = preload("res://src/ai/ai_deck_memory.gd")
const VerificationAssertions = preload("res://tests/support/verification_assertions.gd")


func _initialize() -> void:
	var failures: Array = []
	# Each test wipes memory at the start so they don't interfere.
	_test_growth_per_match(failures)
	_test_cap_at_deck_size(failures)
	_test_no_duplicates(failures)
	_test_filter_drops_removed_cards(failures)
	_test_record_match_drops_removed_then_grows(failures)
	_test_forget_deck(failures)
	_test_empty_deck_name_is_no_op(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("AI_DECK_MEMORY_OK")
	quit(0)


func _test_growth_per_match(failures: Array) -> void:
	AIDeckMemory.forget_all()
	var current := {"a": 3, "b": 3, "c": 3, "d": 3, "e": 3}
	AIDeckMemory.record_match("test_growth", ["a", "b", "c"], current)
	var after_one := AIDeckMemory.get_remembered("test_growth")
	VerificationAssertions.assert_equal(after_one.size(), 2, "First match should add up to 2 def_ids", failures)
	AIDeckMemory.record_match("test_growth", ["c", "d", "e"], current)
	var after_two := AIDeckMemory.get_remembered("test_growth")
	VerificationAssertions.assert_equal(after_two.size(), 4, "Second match should grow to 4 def_ids (+2)", failures)


func _test_cap_at_deck_size(failures: Array) -> void:
	AIDeckMemory.forget_all()
	# Total deck size = 3 across counts.
	var current := {"x": 1, "y": 1, "z": 1}
	AIDeckMemory.record_match("cap_test", ["x", "y", "z"], current)
	var after_one := AIDeckMemory.get_remembered("cap_test")
	VerificationAssertions.assert_equal(after_one.size(), 2, "First match adds 2", failures)
	AIDeckMemory.record_match("cap_test", ["x", "y", "z"], current)
	var after_two := AIDeckMemory.get_remembered("cap_test")
	VerificationAssertions.assert_true(after_two.size() <= 3, "Cap must respect deck size (got %d)" % after_two.size(), failures)


func _test_no_duplicates(failures: Array) -> void:
	AIDeckMemory.forget_all()
	var current := {"a": 3, "b": 3, "c": 3}
	AIDeckMemory.record_match("dup_test", ["a", "a", "a"], current)
	var remembered := AIDeckMemory.get_remembered("dup_test")
	VerificationAssertions.assert_equal(remembered.size(), 1, "Duplicate observations should not double-count", failures)
	# Subsequent match observing same card should NOT grow further.
	AIDeckMemory.record_match("dup_test", ["a"], current)
	var still := AIDeckMemory.get_remembered("dup_test")
	VerificationAssertions.assert_equal(still.size(), 1, "Re-observing the same card should not add new memory", failures)


func _test_filter_drops_removed_cards(failures: Array) -> void:
	AIDeckMemory.forget_all()
	var current_v1 := {"a": 1, "b": 1, "c": 1, "d": 1}
	AIDeckMemory.record_match("filter_test", ["a", "b", "c", "d"], current_v1)
	# Player edits deck: removes "b", adds "e".
	var current_v2 := {"a": 1, "c": 1, "d": 1, "e": 1}
	var filtered := AIDeckMemory.get_remembered_filtered("filter_test", current_v2)
	VerificationAssertions.assert_true(not filtered.has("b"), "Removed card 'b' should be filtered out of remembered", failures)


func _test_record_match_drops_removed_then_grows(failures: Array) -> void:
	AIDeckMemory.forget_all()
	var current_v1 := {"a": 1, "b": 1, "c": 1, "d": 1}
	AIDeckMemory.record_match("evolve_test", ["a", "b"], current_v1)
	var current_v2 := {"a": 1, "c": 1, "d": 1, "e": 1, "f": 1}
	# Match 2 against edited deck (b removed), AI observes 'e' and 'f'.
	AIDeckMemory.record_match("evolve_test", ["e", "f"], current_v2)
	var remembered := AIDeckMemory.get_remembered("evolve_test")
	VerificationAssertions.assert_true(not remembered.has("b"), "After re-record, removed 'b' should be gone", failures)
	VerificationAssertions.assert_true(remembered.has("a"), "Kept 'a' should remain", failures)
	VerificationAssertions.assert_true(remembered.has("e") or remembered.has("f"), "New observation should grow memory", failures)


func _test_forget_deck(failures: Array) -> void:
	AIDeckMemory.forget_all()
	AIDeckMemory.record_match("to_forget", ["a"], {"a": 1, "b": 1, "c": 1})
	VerificationAssertions.assert_equal(AIDeckMemory.get_remembered("to_forget").size(), 1, "Pre-forget memory exists", failures)
	AIDeckMemory.forget_deck("to_forget")
	VerificationAssertions.assert_equal(AIDeckMemory.get_remembered("to_forget").size(), 0, "Forget clears the deck's memory", failures)


func _test_empty_deck_name_is_no_op(failures: Array) -> void:
	AIDeckMemory.forget_all()
	AIDeckMemory.record_match("", ["a", "b"], {"a": 1, "b": 1})
	VerificationAssertions.assert_equal(AIDeckMemory.list_known_decks().size(), 0, "Empty deck name should be a no-op", failures)
