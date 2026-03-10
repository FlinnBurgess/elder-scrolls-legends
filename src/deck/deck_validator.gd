class_name DeckValidator
extends RefCounted

const DeckRulesRegistryClass := preload("res://src/deck/deck_rules_registry.gd")


static func derive_deck_identity(attribute_ids: Array, registry = null) -> Dictionary:
	var active_registry = registry if registry != null else DeckRulesRegistryClass.load_default()
	if not active_registry.is_ready():
		return {
			"errors": ["Registry load failed: %s" % active_registry.get_load_error()],
			"attribute_ids": [],
			"attribute_count": 0,
			"deck_type": "invalid",
			"class_id": null,
			"class_display_name": null,
			"min_cards": 0,
			"max_cards": 0,
		}
	return active_registry.describe_deck(attribute_ids)


static func validate_deck(deck_definition: Dictionary, card_catalog: Dictionary, registry = null) -> Dictionary:
	var active_registry = registry if registry != null else DeckRulesRegistryClass.load_default()
	var result := {
		"is_valid": false,
		"errors": [],
		"identity": {},
		"card_count": 0,
		"copy_counts": {},
	}

	if not active_registry.is_ready():
		result.errors.append("Registry load failed: %s" % active_registry.get_load_error())
		return result

	var identity = active_registry.describe_deck(deck_definition.get("attribute_ids", []))
	result.identity = identity
	result.errors.append_array(identity.get("errors", []))

	var raw_entries: Variant = deck_definition.get("cards", [])
	if typeof(raw_entries) != TYPE_ARRAY:
		result.errors.append("Deck cards must be an array of `{ card_id, quantity }` entries.")
		return _finalize_result(result)

	var copy_counts := {}
	for raw_entry in raw_entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			result.errors.append("Deck entries must be dictionaries.")
			continue

		var entry: Dictionary = raw_entry
		var card_id := String(entry.get("card_id", ""))
		var quantity_variant: Variant = entry.get("quantity", 0)
		if card_id.is_empty():
			result.errors.append("Deck entries require a `card_id`.")
			continue
		if typeof(quantity_variant) != TYPE_INT:
			result.errors.append("Deck entry `%s` must use an integer quantity." % card_id)
			continue

		var quantity := int(quantity_variant)
		if quantity <= 0:
			result.errors.append("Deck entry `%s` must have a positive quantity." % card_id)
			continue

		result.card_count += quantity
		copy_counts[card_id] = int(copy_counts.get(card_id, 0)) + quantity

		var card_record: Variant = card_catalog.get(card_id, null)
		if typeof(card_record) != TYPE_DICTIONARY:
			result.errors.append("Card `%s` is missing from the card catalog." % card_id)
			continue

		_validate_card_membership(card_id, card_record, identity, active_registry, result.errors)

	result.copy_counts = copy_counts
	_enforce_deck_size(identity, result.card_count, result.errors)
	_enforce_copy_limits(copy_counts, card_catalog, active_registry, result.errors)
	return _finalize_result(result)


static func _validate_card_membership(card_id: String, card_record: Dictionary, identity: Dictionary, registry, errors: Array) -> void:
	var card_requirement := _describe_card_requirement(card_id, card_record, registry, errors)
	if card_requirement.is_empty():
		return

	var deck_attribute_ids: Array = identity.get("attribute_ids", [])
	var deck_class_id: Variant = identity.get("class_id", null)
	match String(card_requirement.get("restriction_type", "")):
		"neutral":
			return
		"attribute":
			for attribute_id in card_requirement.get("attribute_ids", []):
				if not deck_attribute_ids.has(attribute_id):
					errors.append("Card `%s` requires the `%s` attribute." % [card_id, attribute_id])
		"class":
			var required_class_id = card_requirement.get("class_id", null)
			var required_display_name = card_requirement.get("class_display_name", required_class_id)
			if deck_class_id == null:
				errors.append("Card `%s` requires the `%s` class." % [card_id, required_display_name])
			elif deck_class_id != required_class_id:
				errors.append("Card `%s` requires `%s`, but the deck is `%s`." % [card_id, required_display_name, _format_deck_identity(identity)])


static func _describe_card_requirement(card_id: String, card_record: Dictionary, registry, errors: Array) -> Dictionary:
	var raw_attribute_ids: Variant = card_record.get("attributes", [])
	var attribute_validation = registry.validate_attribute_ids(raw_attribute_ids)
	for error_message in attribute_validation.get("errors", []):
		errors.append("Card `%s`: %s" % [card_id, error_message])

	var attribute_ids = attribute_validation.get("attribute_ids", [])
	var attribute_count: int = attribute_ids.size()
	var class_id: Variant = card_record.get("class_id", null)
	if class_id is String and String(class_id).is_empty():
		class_id = null

	if attribute_count <= 1 and class_id != null:
		errors.append("Card `%s` must not declare a class id for neutral or single-attribute requirements." % card_id)
	if attribute_count >= 2:
		var class_record: Dictionary = attribute_validation.get("class_record", {})
		var derived_class_id = class_record.get("id", null)
		if class_id == null:
			errors.append("Card `%s` must declare a class id for multi-attribute requirements." % card_id)
		elif class_id != derived_class_id:
			errors.append("Card `%s` declares class `%s`, but its attributes derive `%s`." % [card_id, class_id, derived_class_id])
		return {
			"restriction_type": "class",
			"attribute_ids": attribute_ids,
			"class_id": derived_class_id,
			"class_display_name": class_record.get("display_name", derived_class_id),
		}

	if attribute_count == 1:
		return {
			"restriction_type": "attribute",
			"attribute_ids": attribute_ids,
		}

	return {
		"restriction_type": "neutral",
		"attribute_ids": [],
	}


static func _enforce_deck_size(identity: Dictionary, card_count: int, errors: Array) -> void:
	var min_cards := int(identity.get("min_cards", 0))
	var max_cards := int(identity.get("max_cards", 0))
	if min_cards <= 0 or max_cards <= 0:
		return
	if card_count < min_cards or card_count > max_cards:
		errors.append("%s decks must contain between %d and %d cards; got %d." % [_format_deck_identity(identity), min_cards, max_cards, card_count])


static func _enforce_copy_limits(copy_counts: Dictionary, card_catalog: Dictionary, registry, errors: Array) -> void:
	for card_id in copy_counts.keys():
		var card_record: Variant = card_catalog.get(card_id, null)
		if typeof(card_record) != TYPE_DICTIONARY:
			continue
		var quantity := int(copy_counts[card_id])
		var copy_limit: int = registry.get_unique_copy_limit() if bool(card_record.get("is_unique", false)) else registry.get_default_copy_limit()
		if quantity > copy_limit:
			errors.append("Card `%s` exceeds its copy limit of %d with %d copies." % [card_id, copy_limit, quantity])


static func _format_deck_identity(identity: Dictionary) -> String:
	var class_display_name: Variant = identity.get("class_display_name", null)
	if class_display_name != null:
		return String(class_display_name)

	var attribute_ids: Array = identity.get("attribute_ids", [])
	if attribute_ids.is_empty():
		return "Neutral"
	if attribute_ids.size() == 1:
		return "%s" % String(attribute_ids[0]).capitalize()
	return "%s deck" % String(identity.get("deck_type", "attribute")).capitalize()


static func _finalize_result(result: Dictionary) -> Dictionary:
	result.is_valid = result.errors.is_empty()
	return result