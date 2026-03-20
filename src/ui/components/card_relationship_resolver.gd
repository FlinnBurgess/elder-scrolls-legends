class_name CardRelationshipResolver
extends RefCounted

## Derives card relationships from card data for the relationship cycling display.
## Returns an array of relationship entries, each being either:
##   {"type": "card", "card_data": Dictionary}  — show a different card
##   {"type": "text", "text": String}            — replace rules text on the original card

const RELATED_CARD_OPS := ["summon_from_effect", "generate_card_to_hand"]


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
		for effect in effects:
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var op := str(effect.get("op", ""))
			if not RELATED_CARD_OPS.has(op):
				continue
			var template_raw = effect.get("card_template", null)
			if template_raw == null or typeof(template_raw) != TYPE_DICTIONARY:
				continue
			var template: Dictionary = template_raw as Dictionary
			var def_id := str(template.get("definition_id", ""))
			if def_id.is_empty() or seen_card_ids.has(def_id):
				continue
			seen_card_ids[def_id] = true
			relationships.append({"type": "card", "card_data": template.duplicate(true)})


static func _resolve_contextual_text(card: Dictionary, relationships: Array, context: Dictionary) -> void:
	_resolve_subtype_board_requirement(card, relationships, context)
	_resolve_aura_subtype_synergy(card, relationships, context)
	_resolve_aura_attribute_synergy(card, relationships, context)
	_resolve_cost_reduction_subtype(card, relationships, context)


static func _resolve_subtype_board_requirement(card: Dictionary, relationships: Array, context: Dictionary) -> void:
	var abilities: Array = card.get("triggered_abilities", [])
	var seen_subtypes: Dictionary = {}
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var required_subtype := str(ability.get("required_subtype_on_board", ""))
		if required_subtype.is_empty() or seen_subtypes.has(required_subtype):
			continue
		seen_subtypes[required_subtype] = true
		var text := _subtype_count_text(required_subtype, context)
		relationships.append({"type": "text", "text": text})


static func _resolve_aura_subtype_synergy(card: Dictionary, relationships: Array, context: Dictionary) -> void:
	var aura_raw = card.get("aura", null)
	if aura_raw == null or typeof(aura_raw) != TYPE_DICTIONARY:
		return
	var aura: Dictionary = aura_raw as Dictionary
	var filter_subtype := str(aura.get("filter_subtype", ""))
	if filter_subtype.is_empty():
		return
	var text := _subtype_count_text(filter_subtype, context)
	relationships.append({"type": "text", "text": text})


static func _resolve_aura_attribute_synergy(card: Dictionary, relationships: Array, context: Dictionary) -> void:
	var aura_raw = card.get("aura", null)
	if aura_raw == null or typeof(aura_raw) != TYPE_DICTIONARY:
		return
	var aura: Dictionary = aura_raw as Dictionary
	var filter_attribute := str(aura.get("filter_attribute", ""))
	if filter_attribute.is_empty():
		return
	var display_name := filter_attribute.substr(0, 1).to_upper() + filter_attribute.substr(1)
	var count := _get_attribute_count(filter_attribute, context)
	if count >= 0:
		var zone := _context_zone_label(context)
		relationships.append({"type": "text", "text": "You have %d %s card%s %s." % [count, display_name, "s" if count != 1 else "", zone]})
	else:
		relationships.append({"type": "text", "text": "Synergy: %s cards" % display_name})


static func _resolve_cost_reduction_subtype(card: Dictionary, relationships: Array, context: Dictionary) -> void:
	var cra_raw = card.get("cost_reduction_aura", null)
	if cra_raw == null or typeof(cra_raw) != TYPE_DICTIONARY:
		return
	var cra: Dictionary = cra_raw as Dictionary
	var filter_subtype := str(cra.get("filter_subtype", ""))
	if filter_subtype.is_empty():
		return
	var text := _subtype_count_text(filter_subtype, context)
	relationships.append({"type": "text", "text": text})


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
