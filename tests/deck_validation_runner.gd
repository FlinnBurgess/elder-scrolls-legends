extends SceneTree

const DECK_RULES_REGISTRY_SCRIPT := preload("res://src/deck/deck_rules_registry.gd")
const DECK_VALIDATOR_SCRIPT := preload("res://src/deck/deck_validator.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var registry = DECK_RULES_REGISTRY_SCRIPT.load_default()
	_assert(registry.is_ready(), "Failed to load deck rules registry: %s" % registry.get_load_error())
	if not _failures.is_empty():
		_finish()
		return

	var card_catalog := _build_card_catalog(registry)
	_test_identity_derivation(registry)
	_test_neutral_and_mono_decks(registry, card_catalog)
	_test_dual_and_triple_deck_sizes(registry, card_catalog)
	_test_class_restrictions(registry, card_catalog)
	_test_copy_limits(registry, card_catalog)
	_test_invalid_attribute_selection(registry, card_catalog)
	_test_unknown_card_rejection(registry, card_catalog)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("DECK_VALIDATION_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_identity_derivation(registry) -> void:
	var neutral_identity = DECK_VALIDATOR_SCRIPT.derive_deck_identity([], registry)
	_assert(neutral_identity.get("deck_type") == "neutral", "Expected neutral deck identity for empty attributes.")
	_assert(neutral_identity.get("min_cards") == 50, "Neutral deck minimum should be 50 cards.")

	var battlemage_identity = DECK_VALIDATOR_SCRIPT.derive_deck_identity(["intelligence", "strength"], registry)
	_assert(battlemage_identity.get("class_id") == "battlemage", "Expected Battlemage class derivation for Strength + Intelligence.")

	var guildsworn_identity = DECK_VALIDATOR_SCRIPT.derive_deck_identity(["willpower", "strength", "intelligence"], registry)
	_assert(guildsworn_identity.get("class_id") == "guildsworn", "Expected Guildsworn class derivation for Strength + Intelligence + Willpower.")
	_assert(guildsworn_identity.get("min_cards") == 75, "Triple-attribute deck minimum should be 75 cards.")


func _test_neutral_and_mono_decks(registry, card_catalog: Dictionary) -> void:
	var neutral_deck := {
		"attribute_ids": [],
		"cards": _build_entries("neutral", 50),
	}
	var neutral_result = DECK_VALIDATOR_SCRIPT.validate_deck(neutral_deck, card_catalog, registry)
	_assert(neutral_result.is_valid, "Expected a 50-card neutral deck to validate: %s" % [str(neutral_result.errors)])

	var mono_deck := {
		"attribute_ids": ["strength"],
		"cards": _combine_entries(_build_entries("strength", 38), _build_entries("neutral", 12)),
	}
	var mono_result = DECK_VALIDATOR_SCRIPT.validate_deck(mono_deck, card_catalog, registry)
	_assert(mono_result.is_valid, "Expected a mono-Strength deck with neutral cards to validate: %s" % [str(mono_result.errors)])


func _test_dual_and_triple_deck_sizes(registry, card_catalog: Dictionary) -> void:
	var dual_deck := {
		"attribute_ids": ["strength", "intelligence"],
		"cards": _build_entries("battlemage", 50),
	}
	var dual_result = DECK_VALIDATOR_SCRIPT.validate_deck(dual_deck, card_catalog, registry)
	_assert(dual_result.is_valid, "Expected a 50-card Battlemage deck to validate: %s" % [str(dual_result.errors)])

	var short_triple_deck := {
		"attribute_ids": ["strength", "intelligence", "willpower"],
		"cards": _build_entries("guildsworn", 50),
	}
	var short_triple_result = DECK_VALIDATOR_SCRIPT.validate_deck(short_triple_deck, card_catalog, registry)
	_assert(not short_triple_result.is_valid, "Expected a 50-card Guildsworn deck to fail minimum size.")
	_assert(_has_error_containing(short_triple_result.errors, "between 75 and 100"), "Expected triple-deck size error for short Guildsworn deck.")

	var valid_triple_deck := {
		"attribute_ids": ["strength", "intelligence", "willpower"],
		"cards": _build_entries("guildsworn", 75),
	}
	var valid_triple_result = DECK_VALIDATOR_SCRIPT.validate_deck(valid_triple_deck, card_catalog, registry)
	_assert(valid_triple_result.is_valid, "Expected a 75-card Guildsworn deck to validate: %s" % [str(valid_triple_result.errors)])


func _test_class_restrictions(registry, card_catalog: Dictionary) -> void:
	var mixed_class_deck := {
		"attribute_ids": ["strength", "intelligence", "willpower"],
		"cards": _combine_entries(_build_entries("guildsworn", 72), [{"card_id": "battlemage_1", "quantity": 3}]),
	}
	var mixed_class_result = DECK_VALIDATOR_SCRIPT.validate_deck(mixed_class_deck, card_catalog, registry)
	_assert(not mixed_class_result.is_valid, "Expected Battlemage class cards to be illegal in a Guildsworn deck.")
	_assert(_has_error_containing(mixed_class_result.errors, "requires `Battlemage`"), "Expected explicit class restriction error for Battlemage card in Guildsworn deck.")


func _test_copy_limits(registry, card_catalog: Dictionary) -> void:
	var over_copy_deck := {
		"attribute_ids": ["strength"],
		"cards": _combine_entries([{"card_id": "strength_1", "quantity": 4}], _build_entries("strength", 46, 2)),
	}
	var over_copy_result = DECK_VALIDATOR_SCRIPT.validate_deck(over_copy_deck, card_catalog, registry)
	_assert(not over_copy_result.is_valid, "Expected normal copy limit overflow to fail validation.")
	_assert(_has_error_containing(over_copy_result.errors, "copy limit of 3"), "Expected standard copy-limit error.")

	var unique_over_copy_deck := {
		"attribute_ids": ["strength"],
		"cards": _combine_entries([{"card_id": "unique_strength", "quantity": 2}], _build_entries("strength", 48, 3)),
	}
	var unique_over_copy_result = DECK_VALIDATOR_SCRIPT.validate_deck(unique_over_copy_deck, card_catalog, registry)
	_assert(not unique_over_copy_result.is_valid, "Expected unique-card overflow to fail validation.")
	_assert(_has_error_containing(unique_over_copy_result.errors, "copy limit of 1"), "Expected unique-card limit error.")


func _test_invalid_attribute_selection(registry, card_catalog: Dictionary) -> void:
	var invalid_attribute_deck := {
		"attribute_ids": ["strength", "neutral"],
		"cards": _build_entries("strength", 50),
	}
	var invalid_attribute_result = DECK_VALIDATOR_SCRIPT.validate_deck(invalid_attribute_deck, card_catalog, registry)
	_assert(not invalid_attribute_result.is_valid, "Expected neutral to be rejected as a selectable deck attribute.")
	_assert(_has_error_containing(invalid_attribute_result.errors, "not a selectable deck attribute"), "Expected invalid deck-attribute error.")

	var off_attribute_deck := {
		"attribute_ids": ["intelligence"],
		"cards": _build_entries("strength", 50),
	}
	var off_attribute_result = DECK_VALIDATOR_SCRIPT.validate_deck(off_attribute_deck, card_catalog, registry)
	_assert(not off_attribute_result.is_valid, "Expected off-attribute cards to be rejected from a mono deck.")
	_assert(_has_error_containing(off_attribute_result.errors, "requires the `strength` attribute"), "Expected attribute-membership error.")


func _test_unknown_card_rejection(registry, card_catalog: Dictionary) -> void:
	var unknown_card_deck := {
		"attribute_ids": ["strength"],
		"cards": _combine_entries([{"card_id": "missing_card", "quantity": 1}], _build_entries("strength", 49)),
	}
	var unknown_card_result = DECK_VALIDATOR_SCRIPT.validate_deck(unknown_card_deck, card_catalog, registry)
	_assert(not unknown_card_result.is_valid, "Expected missing catalog entries to fail validation.")
	_assert(_has_error_containing(unknown_card_result.errors, "missing from the card catalog"), "Expected unknown-card validation error.")


func _build_card_catalog(registry) -> Dictionary:
	var catalog := {}
	for index in range(1, 40):
		catalog["neutral_%d" % index] = _make_card("neutral_%d" % index, [], registry)
		catalog["strength_%d" % index] = _make_card("strength_%d" % index, ["strength"], registry)
		catalog["battlemage_%d" % index] = _make_card("battlemage_%d" % index, ["strength", "intelligence"], registry)
	for index in range(1, 30):
		catalog["guildsworn_%d" % index] = _make_card("guildsworn_%d" % index, ["strength", "intelligence", "willpower"], registry)
	catalog["unique_strength"] = _make_card("unique_strength", ["strength"], registry, true)
	return catalog


func _make_card(card_id: String, attribute_ids: Array, registry, is_unique: bool = false) -> Dictionary:
	var normalized = registry.normalize_attribute_ids(attribute_ids)
	var class_record = registry.get_class_for_attributes(normalized)
	var class_id: Variant = null
	if normalized.size() >= 2:
		class_id = class_record.get("id", null)
	return {
		"card_id": card_id,
		"name": card_id.capitalize(),
		"attributes": normalized,
		"class_id": class_id,
		"is_unique": is_unique,
	}


func _build_entries(prefix: String, total_cards: int, start_index: int = 1) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var remaining := total_cards
	var index := start_index
	while remaining > 0:
		var quantity: int = min(3, remaining)
		entries.append({
			"card_id": "%s_%d" % [prefix, index],
			"quantity": quantity,
		})
		remaining -= quantity
		index += 1
	return entries


func _combine_entries(first: Array, second: Array) -> Array:
	var combined: Array = []
	combined.append_array(first)
	combined.append_array(second)
	return combined


func _has_error_containing(errors: Array, fragment: String) -> bool:
	for error_message in errors:
		if fragment in String(error_message):
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)