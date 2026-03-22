class_name CardSynergyExtractor
extends RefCounted

## Extracts synergy signals from card data dictionaries.
## Used by the card relationship resolver (UI) and the AI draft engine (scoring).


## Returns deduplicated lowercase subtypes that this card's abilities care about.
## Does NOT include the card's own subtypes — only subtypes referenced by triggers,
## effects, auras, and cost reduction auras.
static func extract_synergy_subtypes(card: Dictionary) -> Array:
	var seen: Dictionary = {}
	_extract_trigger_condition_subtypes(card, seen)
	_extract_effect_filter_subtypes(card, seen)
	_extract_aura_subtype(card, seen)
	_extract_cost_reduction_subtype(card, seen)
	return seen.keys()


## Returns deduplicated lowercase rules_tags that this card's abilities care about
## (e.g. "shout"), extracted from effect filters and trigger conditions.
static func extract_synergy_rules_tags(card: Dictionary) -> Array:
	var seen: Dictionary = {}
	_extract_trigger_condition_rules_tags(card, seen)
	_extract_effect_filter_rules_tags(card, seen)
	return seen.keys()


## Returns deduplicated lowercase attributes that this card's auras or trigger conditions care about.
static func extract_synergy_attributes(card: Dictionary) -> Array:
	var seen: Dictionary = {}
	var aura_raw = card.get("aura", null)
	if aura_raw != null and typeof(aura_raw) == TYPE_DICTIONARY:
		var filter_attribute := str((aura_raw as Dictionary).get("filter_attribute", ""))
		if not filter_attribute.is_empty():
			seen[filter_attribute.to_lower()] = true
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var req_attr_count = ability.get("required_friendly_attribute_count", null)
		if req_attr_count != null and typeof(req_attr_count) == TYPE_DICTIONARY:
			var attr := str(req_attr_count.get("attribute", ""))
			if not attr.is_empty():
				seen[attr.to_lower()] = true
	return seen.keys()


static func _extract_trigger_condition_subtypes(card: Dictionary, seen: Dictionary) -> void:
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		for key in ["required_subtype_on_board", "required_event_source_subtype", "required_summon_subtype"]:
			var st := str(ability.get(key, ""))
			if not st.is_empty():
				seen[st.to_lower()] = true


static func _extract_effect_filter_subtypes(card: Dictionary, seen: Dictionary) -> void:
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var effects: Array = ability.get("effects", [])
		_scan_effects_for_filter_subtype(effects, seen)


static func _scan_effects_for_filter_subtype(effects: Array, seen: Dictionary) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		# Check direct filter
		var filter_raw = effect.get("filter", null)
		if filter_raw != null and typeof(filter_raw) == TYPE_DICTIONARY:
			var subtype := str((filter_raw as Dictionary).get("subtype", ""))
			if not subtype.is_empty():
				seen[subtype.to_lower()] = true
		# Check inside choose_one choices
		var choices: Array = effect.get("choices", [])
		for choice in choices:
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var sub_effects: Array = choice.get("effects", [])
			_scan_effects_for_filter_subtype(sub_effects, seen)


static func _extract_aura_subtype(card: Dictionary, seen: Dictionary) -> void:
	var aura_raw = card.get("aura", null)
	if aura_raw == null or typeof(aura_raw) != TYPE_DICTIONARY:
		return
	var filter_subtype := str((aura_raw as Dictionary).get("filter_subtype", ""))
	if not filter_subtype.is_empty():
		seen[filter_subtype.to_lower()] = true


static func _extract_cost_reduction_subtype(card: Dictionary, seen: Dictionary) -> void:
	var cra_raw = card.get("cost_reduction_aura", null)
	if cra_raw == null or typeof(cra_raw) != TYPE_DICTIONARY:
		return
	var filter_subtype := str((cra_raw as Dictionary).get("filter_subtype", ""))
	if not filter_subtype.is_empty():
		seen[filter_subtype.to_lower()] = true


static func _extract_trigger_condition_rules_tags(card: Dictionary, seen: Dictionary) -> void:
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var tag := str(ability.get("required_played_rules_tag", ""))
		if not tag.is_empty():
			seen[tag.to_lower()] = true


static func _extract_effect_filter_rules_tags(card: Dictionary, seen: Dictionary) -> void:
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var effects: Array = ability.get("effects", [])
		_scan_effects_for_filter_rules_tag(effects, seen)


static func _scan_effects_for_filter_rules_tag(effects: Array, seen: Dictionary) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var filter_raw = effect.get("filter", null)
		if filter_raw != null and typeof(filter_raw) == TYPE_DICTIONARY:
			var tag := str((filter_raw as Dictionary).get("rules_tag", ""))
			if not tag.is_empty():
				seen[tag.to_lower()] = true
		var choices: Array = effect.get("choices", [])
		for choice in choices:
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var sub_effects: Array = choice.get("effects", [])
			_scan_effects_for_filter_rules_tag(sub_effects, seen)
