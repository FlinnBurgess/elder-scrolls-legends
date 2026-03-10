class_name DemoCardCatalog
extends RefCounted

const DeckRulesRegistryClass := preload("res://src/deck/deck_rules_registry.gd")
const DEFAULT_SET_ID := "foundations_demo"
const DEFAULT_RELEASE_GROUP_ID := "core_pvp"


static func load_default() -> Dictionary:
	var registry = DeckRulesRegistryClass.load_default()
	if not registry.is_ready():
		return {
			"error": "Failed to load deck rules registry: %s" % registry.get_load_error(),
			"cards": [],
			"card_by_id": {},
		}

	var cards: Array = []
	var card_by_id := {}
	for raw_seed in _card_seeds():
		if typeof(raw_seed) != TYPE_DICTIONARY:
			continue
		var card := _build_card(raw_seed, registry)
		cards.append(card)
		card_by_id[str(card.get("card_id", ""))] = card
	return {
		"error": "",
		"cards": cards,
		"card_by_id": card_by_id,
	}


static func _build_card(seed: Dictionary, registry) -> Dictionary:
	var attributes: Array = registry.normalize_attribute_ids(seed.get("attributes", []))
	var class_id: Variant = null
	if attributes.size() >= 2:
		class_id = registry.get_class_for_attributes(attributes).get("id", null)
	return {
		"card_id": str(seed.get("card_id", "")),
		"name": str(seed.get("name", "")),
		"card_type": str(seed.get("card_type", "creature")),
		"subtypes": seed.get("subtypes", []).duplicate(true),
		"attributes": attributes,
		"class_id": class_id,
		"rarity": str(seed.get("rarity", "common")),
		"is_unique": bool(seed.get("is_unique", false)),
		"cost": int(seed.get("cost", 0)),
		"base_power": int(seed.get("base_power", 0)),
		"base_health": int(seed.get("base_health", 0)),
		"keywords": seed.get("keywords", []).duplicate(true),
		"effect_ids": seed.get("effect_ids", []).duplicate(true),
		"rules_text": str(seed.get("rules_text", "")),
		"rules_tags": seed.get("rules_tags", []).duplicate(true),
		"support_uses": int(seed.get("support_uses", 0)),
		"set_id": str(seed.get("set_id", DEFAULT_SET_ID)),
		"release_group_id": str(seed.get("release_group_id", DEFAULT_RELEASE_GROUP_ID)),
		"collectible": true,
		"generated_by_rules": false,
		"source_ids": ["workspace_demo_catalog"],
	}


static func _seed(card_id: String, name: String, attributes: Array, card_type: String, cost: int, base_power: int, base_health: int, extra: Dictionary = {}) -> Dictionary:
	return {
		"card_id": card_id,
		"name": name,
		"attributes": attributes,
		"card_type": card_type,
		"cost": cost,
		"base_power": base_power,
		"base_health": base_health,
		"rarity": str(extra.get("rarity", "common")),
		"is_unique": bool(extra.get("is_unique", false)),
		"keywords": extra.get("keywords", []).duplicate(true),
		"effect_ids": extra.get("effect_ids", []).duplicate(true),
		"rules_tags": extra.get("rules_tags", []).duplicate(true),
		"rules_text": str(extra.get("rules_text", "")),
		"subtypes": extra.get("subtypes", []).duplicate(true),
		"support_uses": int(extra.get("support_uses", 0)),
	}


static func _card_seeds() -> Array:
	return [
		_seed("neutral_watch_captain", "Watch Captain", [], "creature", 2, 2, 3, {"keywords": ["guard"], "rules_text": "Guard."}),
		_seed("neutral_market_courier", "Market Courier", [], "creature", 1, 2, 1, {"keywords": ["charge"], "rules_text": "Charge."}),
		_seed("neutral_bone_colossus", "Bone Colossus", [], "creature", 7, 7, 7, {"keywords": ["breakthrough"], "is_unique": true, "rarity": "legendary", "rules_text": "Breakthrough. Unique."}),
		_seed("neutral_prophecy_adept", "Prophecy Adept", [], "creature", 3, 3, 2, {"rules_tags": ["prophecy"], "rules_text": "Prophecy. Draw stabilizer for browser testing."}),
		_seed("neutral_spark_bolt", "Spark Bolt", [], "action", 2, 0, 0, {"effect_ids": ["damage"], "rules_text": "Deal 2 damage."}),
		_seed("neutral_field_journal", "Field Journal", [], "support", 3, 0, 0, {"support_uses": 2, "effect_ids": ["draw"], "rules_text": "Activate: Draw a card."}),
		_seed("neutral_tower_shield", "Tower Shield", [], "item", 2, 0, 0, {"effect_ids": ["equip"], "rules_text": "+0/+2 and Guard."}),
		_seed("neutral_archive_curator", "Archive Curator", [], "creature", 4, 3, 4, {"keywords": ["ward"], "rules_text": "Ward."}),
		_seed("neutral_battlefield_medic", "Battlefield Medic", [], "creature", 5, 4, 5, {"keywords": ["drain"], "rules_text": "Drain."}),
		_seed("strength_berserker", "Ash Berserker", ["strength"], "creature", 3, 4, 2, {"keywords": ["charge"], "rules_text": "Charge."}),
		_seed("strength_bulwark", "Bulwark Veteran", ["strength"], "creature", 4, 4, 5, {"keywords": ["guard"], "rules_text": "Guard."}),
		_seed("strength_battle_orders", "Battle Orders", ["strength"], "action", 2, 0, 0, {"effect_ids": ["modify_stats"], "rules_text": "Give a creature +2/+0."}),
		_seed("strength_war_axe", "War Axe", ["strength"], "item", 3, 0, 0, {"effect_ids": ["equip"], "rules_text": "+3/+0."}),
		_seed("intelligence_apprentice", "Arcane Apprentice", ["intelligence"], "creature", 2, 2, 2, {"keywords": ["ward"], "rules_text": "Ward."}),
		_seed("intelligence_volley", "Ice Volley", ["intelligence"], "action", 4, 0, 0, {"effect_ids": ["damage"], "rules_text": "Deal 3 damage to a creature."}),
		_seed("intelligence_scrollkeeper", "Scrollkeeper", ["intelligence"], "support", 3, 0, 0, {"support_uses": 2, "effect_ids": ["draw"], "rules_text": "Activate: Draw then discard."}),
		_seed("intelligence_arc_blade", "Arc Blade", ["intelligence"], "item", 2, 0, 0, {"effect_ids": ["equip"], "rules_text": "+1/+1 and Ward."}),
		_seed("willpower_healer", "Temple Healer", ["willpower"], "creature", 3, 2, 4, {"keywords": ["drain"], "rules_text": "Drain."}),
		_seed("willpower_cleric", "Sunhold Cleric", ["willpower"], "creature", 4, 3, 5, {"keywords": ["ward"], "rules_text": "Ward."}),
		_seed("willpower_blessing", "Blessing of Resolve", ["willpower"], "action", 2, 0, 0, {"effect_ids": ["heal"], "rules_text": "Restore 4 health."}),
		_seed("willpower_sanctum", "Sanctum Lantern", ["willpower"], "support", 2, 0, 0, {"support_uses": 2, "effect_ids": ["heal"], "rules_text": "Activate: Restore 2 health."}),
		_seed("battlemage_raider", "Battlemage Raider", ["strength", "intelligence"], "creature", 4, 5, 3, {"keywords": ["charge"], "rules_text": "Charge."}),
		_seed("battlemage_conjurer", "Battlemage Conjurer", ["strength", "intelligence"], "creature", 5, 4, 5, {"keywords": ["ward"], "rules_text": "Ward."}),
		_seed("battlemage_barrage", "Battlemage Barrage", ["strength", "intelligence"], "action", 5, 0, 0, {"effect_ids": ["damage"], "rules_text": "Deal 4 damage and ready an attacker."}),
		_seed("battlemage_blade", "Battlemage Blade", ["strength", "intelligence"], "item", 3, 0, 0, {"effect_ids": ["equip"], "rules_text": "+2/+2."}),
		_seed("guildsworn_sentinel", "Guildsworn Sentinel", ["strength", "intelligence", "willpower"], "creature", 5, 5, 5, {"keywords": ["guard"], "rules_text": "Guard."}),
		_seed("guildsworn_prophet", "Guildsworn Prophet", ["strength", "intelligence", "willpower"], "creature", 4, 3, 4, {"rules_tags": ["prophecy"], "rules_text": "Prophecy. Gain tempo when drawn off a rune."}),
		_seed("guildsworn_tempest", "Guildsworn Tempest", ["strength", "intelligence", "willpower"], "action", 6, 0, 0, {"effect_ids": ["damage"], "rules_text": "Deal 3 damage to all enemy creatures."}),
		_seed("guildsworn_relic", "Guildsworn Relic", ["strength", "intelligence", "willpower"], "item", 4, 0, 0, {"effect_ids": ["equip"], "rules_text": "+2/+2 and Ward."}),
		_seed("guildsworn_banner", "Guildsworn Banner", ["strength", "intelligence", "willpower"], "support", 4, 0, 0, {"support_uses": 2, "is_unique": true, "rarity": "epic", "effect_ids": ["modify_stats"], "rules_text": "Activate: Give a creature +1/+1."}),
		_seed("guildsworn_archivist", "Guildsworn Archivist", ["strength", "intelligence", "willpower"], "creature", 3, 3, 3, {"keywords": ["rally"], "rules_text": "Rally."}),
		_seed("agility_stalker", "Moonshadow Stalker", ["agility"], "creature", 3, 3, 2, {"keywords": ["lethal"], "rules_text": "Lethal."}),
		_seed("agility_shadowstep", "Shadowstep", ["agility"], "action", 1, 0, 0, {"effect_ids": ["move"], "rules_text": "Move a creature."}),
		_seed("endurance_gravecaller", "Gravecaller", ["endurance"], "creature", 4, 3, 6, {"keywords": ["regenerate"], "rules_text": "Regenerate."}),
		_seed("endurance_crypt", "Crypt Beacon", ["endurance"], "support", 3, 0, 0, {"support_uses": 2, "effect_ids": ["summon"], "rules_text": "Activate: Summon a 1/1 token."}),
	]