class_name DeckRulesRegistry
extends RefCounted

const DEFAULT_REGISTRY_PATH := "res://data/legends/registries/attribute_class_registry.json"
const DECK_TYPE_BY_ATTRIBUTE_COUNT := {
	0: "neutral",
	1: "mono",
	2: "dual",
	3: "triple",
}

var _load_error := ""
var _primary_attribute_ids: Array[String] = []
var _selectable_attribute_ids: Array[String] = []
var _attribute_records := {}
var _class_by_tuple_key := {}
var _class_by_id := {}
var _deck_size_rules := {}
var _max_attributes_per_deck := 0
var _default_copy_limit := 0
var _unique_copy_limit := 0


func _init(registry_data: Dictionary = {}) -> void:
	if registry_data.is_empty():
		_load_error = "Missing registry data."
		return
	_hydrate(registry_data)


static func load_default():
	return load_from_path(DEFAULT_REGISTRY_PATH)


static func load_from_path(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var missing_registry = new()
		missing_registry._load_error = "Unable to open registry at %s." % path
		return missing_registry

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		var invalid_registry = new()
		invalid_registry._load_error = "Unable to parse registry at %s." % path
		return invalid_registry

	return new(json.data)


func is_ready() -> bool:
	return _load_error.is_empty()


func get_load_error() -> String:
	return _load_error


func get_max_attributes_per_deck() -> int:
	return _max_attributes_per_deck


func get_default_copy_limit() -> int:
	return _default_copy_limit


func get_unique_copy_limit() -> int:
	return _unique_copy_limit


func normalize_attribute_ids(attribute_ids: Array) -> Array[String]:
	var present := {}
	for raw_attribute_id in attribute_ids:
		present[String(raw_attribute_id)] = true

	var normalized: Array[String] = []
	for attribute_id in _primary_attribute_ids:
		if present.has(attribute_id):
			normalized.append(attribute_id)

	return normalized


func describe_deck(attribute_ids: Variant) -> Dictionary:
	var validation := validate_attribute_ids(attribute_ids, true)
	var normalized = validation.get("attribute_ids", [])
	var class_record: Dictionary = validation.get("class_record", {})
	var size_rule: Dictionary = validation.get("size_rule", {})
	var class_id: Variant = null
	var class_display_name: Variant = null

	if not class_record.is_empty():
		class_id = class_record.get("id", null)
		class_display_name = class_record.get("display_name", null)

	return {
		"errors": validation.get("errors", []),
		"attribute_ids": normalized,
		"attribute_count": normalized.size(),
		"deck_type": DECK_TYPE_BY_ATTRIBUTE_COUNT.get(normalized.size(), "invalid"),
		"class_id": class_id,
		"class_display_name": class_display_name,
		"min_cards": int(size_rule.get("min_cards", 0)),
		"max_cards": int(size_rule.get("max_cards", 0)),
	}


func validate_attribute_ids(attribute_ids: Variant, include_size_rule: bool = false) -> Dictionary:
	var errors: Array[String] = []
	var normalized: Array[String] = []
	var class_record: Dictionary = {}
	var size_rule: Dictionary = {}

	if typeof(attribute_ids) != TYPE_ARRAY:
		errors.append("Attribute ids must be an array.")
		return {
			"errors": errors,
			"attribute_ids": normalized,
			"class_record": class_record,
			"size_rule": size_rule,
		}

	var seen := {}
	for raw_attribute_id in attribute_ids:
		var attribute_id := String(raw_attribute_id)
		if attribute_id.is_empty():
			errors.append("Attribute ids must be non-empty strings.")
			continue
		if not _attribute_records.has(attribute_id) or not _selectable_attribute_ids.has(attribute_id):
			errors.append("`%s` is not a selectable deck attribute." % attribute_id)
			continue
		if seen.has(attribute_id):
			errors.append("Duplicate deck attribute `%s`." % attribute_id)
			continue
		seen[attribute_id] = true

	normalized = normalize_attribute_ids(seen.keys())
	if normalized.size() > _max_attributes_per_deck:
		errors.append("Decks may use at most %d attributes." % _max_attributes_per_deck)

	if normalized.size() >= 2:
		class_record = get_class_for_attributes(normalized)
		if class_record.is_empty():
			errors.append("No class exists for attribute tuple `%s`." % _build_attribute_tuple_key(normalized))

	if include_size_rule:
		size_rule = get_deck_size_rule(normalized.size())
		if size_rule.is_empty():
			errors.append("No deck-size rule exists for %d attributes." % normalized.size())

	return {
		"errors": errors,
		"attribute_ids": normalized,
		"class_record": class_record,
		"size_rule": size_rule,
	}


func get_class_for_attributes(attribute_ids: Array) -> Dictionary:
	var normalized := normalize_attribute_ids(attribute_ids)
	return _class_by_tuple_key.get(_build_attribute_tuple_key(normalized), {})


func get_class_by_id(class_id: String) -> Dictionary:
	return _class_by_id.get(class_id, {})


func get_deck_size_rule(attribute_count: int) -> Dictionary:
	return _deck_size_rules.get(attribute_count, {})


func _hydrate(registry_data: Dictionary) -> void:
	var attribute_records: Array = registry_data.get("attributes", [])
	for raw_attribute_record in attribute_records:
		if typeof(raw_attribute_record) != TYPE_DICTIONARY:
			continue
		var attribute_record: Dictionary = raw_attribute_record
		var attribute_id := String(attribute_record.get("id", ""))
		if attribute_id.is_empty():
			continue
		_attribute_records[attribute_id] = attribute_record
		if String(attribute_record.get("kind", "")) == "primary":
			_primary_attribute_ids.append(attribute_id)
		if bool(attribute_record.get("deck_selectable", true)):
			_selectable_attribute_ids.append(attribute_id)

	for bucket_name in ["dual_classes", "triple_classes"]:
		var class_records: Array = registry_data.get(bucket_name, [])
		for raw_class_record in class_records:
			if typeof(raw_class_record) != TYPE_DICTIONARY:
				continue
			var class_record: Dictionary = raw_class_record
			var class_id := String(class_record.get("id", ""))
			var tuple_key := String(class_record.get("attribute_tuple_key", ""))
			if class_id.is_empty() or tuple_key.is_empty():
				continue
			_class_by_tuple_key[tuple_key] = class_record
			_class_by_id[class_id] = class_record

	var deck_construction: Dictionary = registry_data.get("deck_construction", {})
	_max_attributes_per_deck = int(deck_construction.get("max_attributes_per_deck", 3))
	_default_copy_limit = int(deck_construction.get("default_copy_limit", 3))
	_unique_copy_limit = int(deck_construction.get("unique_copy_limit", 1))

	var size_rules: Array = deck_construction.get("deck_size_rules", [])
	for raw_rule in size_rules:
		if typeof(raw_rule) != TYPE_DICTIONARY:
			continue
		var size_rule: Dictionary = raw_rule
		_deck_size_rules[int(size_rule.get("attribute_count", -1))] = size_rule

	if not _deck_size_rules.has(0) and _deck_size_rules.has(1):
		var one_attribute_rule: Dictionary = _deck_size_rules[1]
		_deck_size_rules[0] = {
			"attribute_count": 0,
			"min_cards": int(one_attribute_rule.get("min_cards", 50)),
			"max_cards": int(one_attribute_rule.get("max_cards", 100)),
		}

	_load_error = ""


func _build_attribute_tuple_key(attribute_ids: Array) -> String:
	return "+".join(normalize_attribute_ids(attribute_ids))