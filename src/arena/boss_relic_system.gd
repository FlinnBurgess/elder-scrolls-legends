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
			return "The boss starts with 80 health."
		BossRelic.CORUNDUM:
			return "The boss's creatures gain +1 attack."
		BossRelic.MOONSTONE:
			return "When a boss rune breaks, the boss draws a free 0-cost card."
		BossRelic.QUICKSILVER:
			return "At the start of your turn, you take 1 damage."
		BossRelic.EBONY:
			return "A 0/6 City Gates blocks one lane. Creatures cannot be summoned in the other lane until it is destroyed."
		BossRelic.MALACHITE:
			return "The boss starts with a 0/4 Guard creature in each lane."
	return ""


static func apply_relic_to_match_config(relic: BossRelic, config: Dictionary) -> Dictionary:
	match relic:
		BossRelic.IRON:
			config.boss_health = 80
		BossRelic.CORUNDUM:
			config.boss_creature_attack_bonus = 1
		BossRelic.MOONSTONE:
			config.boss_rune_break_card = true
		BossRelic.QUICKSILVER:
			config.player_start_of_turn_damage = 1
		BossRelic.EBONY:
			config.boss_city_gates = true
		BossRelic.MALACHITE:
			config.boss_starting_guards = [{"attack": 0, "health": 4, "guard": true}]
	return config
