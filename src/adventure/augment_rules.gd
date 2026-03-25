class_name AugmentRules
extends RefCounted

const AugmentCatalogScript = preload("res://src/adventure/augment_catalog.gd")


## Build a dictionary mapping card_id -> Array of augment effect dictionaries.
static func build_augment_map(augments: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry in augments:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var card_id := str(entry.get("card_id", ""))
		var augment_id := str(entry.get("augment_id", ""))
		if card_id.is_empty() or augment_id.is_empty():
			continue
		var augment := AugmentCatalogScript.get_augment(augment_id)
		if augment.is_empty():
			continue
		if not result.has(card_id):
			result[card_id] = []
		result[card_id].append(augment)
	return result


## Apply augment effects to a card dictionary (modifying it in place).
## Called during match initialization for each player deck card that has augments.
static func apply_augments_to_card(card: Dictionary, augment_list: Array) -> void:
	for augment in augment_list:
		var effects: Dictionary = augment.get("effects", {})
		if effects.is_empty():
			continue
		_apply_effects(card, effects)
		# Track augment info on the card for display purposes.
		if not card.has("_augments"):
			card["_augments"] = []
		card["_augments"].append({
			"id": str(augment.get("id", "")),
			"name": str(augment.get("name", "")),
			"description": str(augment.get("description", "")),
		})


static func _apply_effects(card: Dictionary, effects: Dictionary) -> void:
	# Stat modifications — update both base stats and runtime stats (power/health)
	# so the augment is reflected in the match engine after hydration.
	if effects.has("power"):
		var power_delta := int(effects["power"])
		card["base_power"] = int(card.get("base_power", 0)) + power_delta
		card["power"] = int(card.get("power", 0)) + power_delta
	if effects.has("health"):
		var health_delta := int(effects["health"])
		card["base_health"] = int(card.get("base_health", 0)) + health_delta
		card["health"] = int(card.get("health", 0)) + health_delta
	if effects.has("cost"):
		card["cost"] = maxi(0, int(card.get("cost", 0)) + int(effects["cost"]))

	# Keyword grant
	if effects.has("keyword"):
		var kw: String = str(effects["keyword"])
		var keywords: Array = card.get("keywords", [])
		if kw not in keywords:
			keywords.append(kw)
			card["keywords"] = keywords

	# Triggered ability grant
	if effects.has("triggered_ability"):
		var ability = effects["triggered_ability"]
		if typeof(ability) == TYPE_DICTIONARY:
			var abilities: Array = card.get("triggered_abilities", [])
			abilities.append(ability.duplicate(true))
			card["triggered_abilities"] = abilities

	# Extra effect (append to first on_play trigger's effects array)
	if effects.has("extra_effect"):
		var extra = effects["extra_effect"]
		if typeof(extra) == TYPE_DICTIONARY:
			_append_extra_effect(card, extra.duplicate(true))

	# Boost damage (increase amount on existing damage effects)
	if effects.has("boost_damage"):
		var boost: int = int(effects["boost_damage"])
		_boost_damage_effects(card, boost)

	# Summon buff (add post-summon stat modifier to summon effects)
	if effects.has("summon_buff"):
		var buff = effects["summon_buff"]
		if typeof(buff) == TYPE_DICTIONARY:
			_apply_summon_buff(card, buff)


static func _append_extra_effect(card: Dictionary, extra_effect: Dictionary) -> void:
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var family := str(ability.get("family", ""))
		if family in ["on_play", "summon"]:
			var effects: Array = ability.get("effects", [])
			effects.append(extra_effect)
			ability["effects"] = effects
			return
	# No on_play trigger found — create one.
	abilities.append({
		"family": "on_play",
		"effects": [extra_effect],
	})
	card["triggered_abilities"] = abilities


static func _boost_damage_effects(card: Dictionary, boost: int) -> void:
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var effects: Array = ability.get("effects", [])
		for effect in effects:
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var op := str(effect.get("op", ""))
			if op in ["deal_damage", "damage"]:
				effect["amount"] = int(effect.get("amount", 0)) + boost


static func _apply_summon_buff(card: Dictionary, buff: Dictionary) -> void:
	# Add a modify_stats effect after each summon effect in the card's abilities.
	var abilities: Array = card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var effects: Array = ability.get("effects", [])
		var new_effects: Array = []
		for effect in effects:
			new_effects.append(effect)
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var op := str(effect.get("op", ""))
			if op in ["summon_from_effect", "summon_random_from_catalog", "summon_random_from_discard", "fill_lane_with"]:
				new_effects.append({
					"op": "modify_stats",
					"target": "last_summoned",
					"power": int(buff.get("power", 0)),
					"health": int(buff.get("health", 0)),
				})
		ability["effects"] = new_effects
