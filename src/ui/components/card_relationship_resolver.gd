class_name CardRelationshipResolver
extends RefCounted

## Derives card relationships from card data for the relationship cycling display.
## Returns an array of relationship entries, each being either:
##   {"type": "card", "card_data": Dictionary}  — show a different card
##   {"type": "text", "text": String}            — replace rules text on the original card

const CardSynergyExtractor = preload("res://src/deck/card_synergy_extractor.gd")
const RELATED_CARD_OPS := ["summon_from_effect", "generate_card_to_hand", "fill_lane_with", "summon_copies_to_lane", "equip_generated_item", "transform"]


static func resolve(card: Dictionary, context: Dictionary = {}) -> Array:
	var relationships: Array = []
	var seen_card_ids: Dictionary = {}
	_resolve_card_relationships(card, relationships, seen_card_ids)
	_resolve_contextual_text(card, relationships, context)
	return relationships


static func _resolve_card_relationships(card: Dictionary, relationships: Array, seen_card_ids: Dictionary) -> void:
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var effects: Array = ability.get("effects", [])
		_scan_effects_for_card_templates(effects, relationships, seen_card_ids)


static func _scan_effects_for_card_templates(effects: Array, relationships: Array, seen_card_ids: Dictionary) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var op := str(effect.get("op", ""))
		if RELATED_CARD_OPS.has(op):
			var template_raw = effect.get("card_template", null)
			if template_raw != null and typeof(template_raw) == TYPE_DICTIONARY:
				var template: Dictionary = template_raw as Dictionary
				var def_id := str(template.get("definition_id", ""))
				if not def_id.is_empty() and not seen_card_ids.has(def_id):
					seen_card_ids[def_id] = true
					var card_data: Dictionary = template.duplicate(true)
					if not card_data.has("art_path") and not def_id.is_empty():
						card_data["art_path"] = "res://assets/images/cards/" + def_id + ".png"
					relationships.append({"type": "card", "card_data": card_data})
		# Descend into choose_one / choose_two choices
		if op == "choose_one" or op == "choose_two":
			var choices: Array = effect.get("choices", [])
			for choice in choices:
				if typeof(choice) == TYPE_DICTIONARY:
					var choice_effects: Array = choice.get("effects", [])
					_scan_effects_for_card_templates(choice_effects, relationships, seen_card_ids)


static func _resolve_contextual_text(card: Dictionary, relationships: Array, context: Dictionary) -> void:
	var synergy_subtypes: Array = CardSynergyExtractor.extract_synergy_subtypes(card)
	for subtype in synergy_subtypes:
		var text := _subtype_count_text(subtype, context)
		relationships.append({"type": "text", "text": text})

	var synergy_rules_tags: Array = CardSynergyExtractor.extract_synergy_rules_tags(card)
	for tag in synergy_rules_tags:
		var text := _rules_tag_count_text(tag, context)
		relationships.append({"type": "text", "text": text})

	var synergy_attributes: Array = CardSynergyExtractor.extract_synergy_attributes(card)
	for attribute in synergy_attributes:
		var attr_str := str(attribute)
		var display_name := attr_str.substr(0, 1).to_upper() + attr_str.substr(1)
		var count := _get_attribute_count(attr_str, context)
		if count >= 0:
			var zone := _context_zone_label(context)
			relationships.append({"type": "text", "text": "You have %d %s card%s %s." % [count, display_name, "s" if count != 1 else "", zone]})
		else:
			relationships.append({"type": "text", "text": "Synergy: %s cards" % display_name})


static func _subtype_count_text(subtype: String, context: Dictionary) -> String:
	var count := _get_subtype_count(subtype, context)
	if count >= 0:
		var zone := _context_zone_label(context)
		return "You have %d %s%s %s." % [count, subtype, "s" if count != 1 else "", zone]
	return "Synergy: %s" % subtype


static func _get_subtype_count(subtype: String, context: Dictionary) -> int:
	# context can provide: "deck_cards", "board_cards", "hand_cards" arrays
	# and "zone" string: "match", "deck_editor", "arena_draft"
	var zone := str(context.get("zone", ""))
	if zone == "match":
		return _count_subtype_in_arrays(subtype, [
			context.get("board_cards", []),
			context.get("hand_cards", []),
		])
	if zone == "deck_editor" or zone == "arena_draft":
		return _count_subtype_in_arrays(subtype, [
			context.get("deck_cards", []),
		])
	return -1


static func _get_attribute_count(attribute: String, context: Dictionary) -> int:
	var zone := str(context.get("zone", ""))
	if zone == "match":
		return _count_attribute_in_arrays(attribute, [
			context.get("board_cards", []),
			context.get("hand_cards", []),
		])
	if zone == "deck_editor" or zone == "arena_draft":
		return _count_attribute_in_arrays(attribute, [
			context.get("deck_cards", []),
		])
	return -1


static func _context_zone_label(context: Dictionary) -> String:
	var zone := str(context.get("zone", ""))
	match zone:
		"match":
			return "in play and hand"
		"deck_editor", "arena_draft":
			return "in your deck"
		_:
			return ""


static func _count_subtype_in_arrays(subtype: String, arrays: Array) -> int:
	var count := 0
	for arr in arrays:
		if typeof(arr) != TYPE_ARRAY:
			continue
		for card in arr:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var subtypes: Array = card.get("subtypes", [])
			for st in subtypes:
				if str(st).to_lower() == subtype.to_lower():
					count += 1
					break
	return count


static func _rules_tag_count_text(tag: String, context: Dictionary) -> String:
	var display_name := tag.substr(0, 1).to_upper() + tag.substr(1)
	var count := _get_rules_tag_count(tag, context)
	if count >= 0:
		var zone := _context_zone_label(context)
		return "You have %d %s%s %s." % [count, display_name, "s" if count != 1 else "", zone]
	return "Synergy: %ss" % display_name


static func _get_rules_tag_count(tag: String, context: Dictionary) -> int:
	var zone := str(context.get("zone", ""))
	if zone == "match":
		return _count_rules_tag_in_arrays(tag, [
			context.get("board_cards", []),
			context.get("hand_cards", []),
		])
	if zone == "deck_editor" or zone == "arena_draft":
		return _count_rules_tag_in_arrays(tag, [
			context.get("deck_cards", []),
		])
	return -1


static func _count_rules_tag_in_arrays(tag: String, arrays: Array) -> int:
	var count := 0
	for arr in arrays:
		if typeof(arr) != TYPE_ARRAY:
			continue
		for card in arr:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var tags: Array = card.get("rules_tags", [])
			for t in tags:
				if str(t).to_lower() == tag.to_lower():
					count += 1
					break
	return count


static func _count_attribute_in_arrays(attribute: String, arrays: Array) -> int:
	var count := 0
	for arr in arrays:
		if typeof(arr) != TYPE_ARRAY:
			continue
		for card in arr:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var attributes: Array = card.get("attributes", [])
			for attr in attributes:
				if str(attr).to_lower() == attribute.to_lower():
					count += 1
					break
	return count
