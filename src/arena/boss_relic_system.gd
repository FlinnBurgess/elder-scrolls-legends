class_name BossRelicSystem
extends RefCounted


enum BossRelic {
	IRON,
	CORUNDUM,
	MOONSTONE,
	QUICKSILVER,
	EBONY,
	MALACHITE,
}


static func pick_random_relic() -> BossRelic:
	var values := [
		BossRelic.IRON,
		BossRelic.CORUNDUM,
		BossRelic.MOONSTONE,
		BossRelic.QUICKSILVER,
		BossRelic.EBONY,
		BossRelic.MALACHITE,
	]
	return values[randi() % values.size()]


static func get_relic_name(relic: BossRelic) -> String:
	match relic:
		BossRelic.IRON:
			return "Iron Relic"
		BossRelic.CORUNDUM:
			return "Corundum Relic"
		BossRelic.MOONSTONE:
			return "Moonstone Relic"
		BossRelic.QUICKSILVER:
			return "Quicksilver Relic"
		BossRelic.EBONY:
			return "Ebony Relic"
		BossRelic.MALACHITE:
			return "Malachite Relic"
	return ""


static func get_relic_description(relic: BossRelic) -> String:
	match relic:
		BossRelic.IRON:
			return "I start with 50 health."
		BossRelic.CORUNDUM:
			return "My creatures have +1/+0."
		BossRelic.MOONSTONE:
			return "When my opponent loses a rune, I get a free 0-cost card."
		BossRelic.QUICKSILVER:
			return "At the start of my turn, deal 1 damage to my opponent."
		BossRelic.EBONY:
			return "I start with City Gates in a lane."
		BossRelic.MALACHITE:
			return "I start with a 0/4 Guard in each lane."
	return ""


static func get_boss_config(relic: BossRelic) -> Dictionary:
	var config := {
		"relic": relic,
		"relic_name": get_relic_name(relic),
	}
	match relic:
		BossRelic.IRON:
			config["boss_health"] = 50
		BossRelic.EBONY:
			config["starting_creatures"] = [
				{"name": "City Gates", "card_type": "creature", "cost": 0, "power": 0, "health": 6, "base_power": 0, "base_health": 6, "keywords": ["guard"], "rules_text": "Guard", "subtypes": [], "attributes": [], "definition_id": "boss_city_gates", "lane_index": 0},
			]
		BossRelic.MALACHITE:
			config["starting_creatures"] = [
				{"name": "Malachite Guard", "card_type": "creature", "cost": 0, "power": 0, "health": 4, "base_power": 0, "base_health": 4, "keywords": ["guard"], "rules_text": "Guard", "subtypes": [], "attributes": [], "definition_id": "boss_malachite_guard", "lane_index": 0},
				{"name": "Malachite Guard", "card_type": "creature", "cost": 0, "power": 0, "health": 4, "base_power": 0, "base_health": 4, "keywords": ["guard"], "rules_text": "Guard", "subtypes": [], "attributes": [], "definition_id": "boss_malachite_guard", "lane_index": 1},
			]
	return config


static func get_relic_card_template(relic: BossRelic) -> Dictionary:
	var base := {
		"card_type": "support",
		"cost": 0,
		"power": 0,
		"health": 0,
		"base_power": 0,
		"base_health": 0,
		"support_uses": 0,
		"keywords": [],
		"subtypes": [],
		"attributes": [],
		"effect_ids": [],
	}
	base["name"] = get_relic_name(relic)
	base["definition_id"] = "boss_relic_%s" % BossRelic.keys()[relic].to_lower()
	base["rules_text"] = "Ongoing\n%s" % get_relic_description(relic)
	match relic:
		BossRelic.CORUNDUM:
			base["aura"] = {"scope": "all_lanes", "target": "all_friendly", "power": 1}
		BossRelic.MOONSTONE:
			base["triggered_abilities"] = [{"family": "on_enemy_rune_destroyed", "required_zone": "support", "effects": [{"op": "generate_random_to_hand", "filter": {"max_cost": 0}}]}]
		BossRelic.QUICKSILVER:
			base["triggered_abilities"] = [{"family": "start_of_turn", "required_zone": "support", "effects": [{"op": "damage", "target_player": "opponent", "amount": 1}]}]
	return base
