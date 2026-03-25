class_name AugmentCatalog
extends RefCounted

const AUGMENTS_PATH := "res://data/augments.json"

static var _cached_augments: Array = []


static func get_all_augments() -> Array:
	if not _cached_augments.is_empty():
		return _cached_augments
	var file := FileAccess.open(AUGMENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("AugmentCatalog: failed to open '%s'" % AUGMENTS_PATH)
		return []
	var text := file.get_as_text()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("AugmentCatalog: failed to parse '%s': %s" % [AUGMENTS_PATH, json.get_error_message()])
		return []
	if json.data is Array:
		_cached_augments = json.data
	return _cached_augments


static func get_augment(augment_id: String) -> Dictionary:
	for augment in get_all_augments():
		if str(augment.get("id", "")) == augment_id:
			return augment
	return {}


static func get_creature_augments(count: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for augment in get_all_augments():
		if str(augment.get("type", "")) == "creature":
			pool.append(augment)
	if pool.is_empty():
		return []
	# Fisher-Yates shuffle and take first N.
	var shuffled := pool.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled.slice(0, mini(count, shuffled.size()))


static func get_valid_action_augments(action_card: Dictionary) -> Array:
	var card_ops := _extract_ops(action_card)
	var valid: Array = []
	for augment in get_all_augments():
		if str(augment.get("type", "")) != "action":
			continue
		var target_ops: Array = augment.get("target_ops", [])
		if _ops_match(target_ops, card_ops):
			valid.append(augment)
	return valid


static func _extract_ops(card: Dictionary) -> Array:
	var ops: Array = []
	var abilities = card.get("triggered_abilities", [])
	if typeof(abilities) != TYPE_ARRAY:
		return ops
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var effects = ability.get("effects", [])
		if typeof(effects) != TYPE_ARRAY:
			continue
		for effect in effects:
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var op := str(effect.get("op", ""))
			if not op.is_empty() and op not in ops:
				ops.append(op)
	return ops


static func _ops_match(target_ops: Array, card_ops: Array) -> bool:
	for op in target_ops:
		if str(op) == "*":
			return true
		if str(op) in card_ops:
			return true
	return false
