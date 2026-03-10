class_name MatchDebugScenarios
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")

const DEFAULT_SCENARIO_ID := "local_match"
const STANDARD_RUNE_THRESHOLDS := [25, 20, 15, 10, 5]


static func list_scenarios() -> Array:
	return [
		{
			"id": "local_match",
			"label": "Local Match Sandbox",
			"description": "Playable board state with creatures, item, support, end-turn flow, and Ring of Magicka access.",
		},
		{
			"id": "support_lab",
			"label": "Support Lab",
			"description": "Focused support activation sandbox with deterministic board/debug state.",
		},
		{
			"id": "prophecy_lab",
			"label": "Prophecy Lab",
			"description": "Open Prophecy interrupt window for testing prompt flow and free-play placement.",
		},
	]


static func build_scenario(scenario_id: String) -> Dictionary:
	match scenario_id:
		"support_lab":
			return _build_support_lab()
		"prophecy_lab":
			return _build_prophecy_lab()
		_:
			return _build_local_match()


static func _build_local_match() -> Dictionary:
	var match_state := ScenarioFixtures.create_started_match({
		"seed": 17,
		"first_player_index": 0,
		"set_all_magicka": 6,
	})
	if match_state.is_empty():
		return {}

	var player_one: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_two: Dictionary = ScenarioFixtures.player(match_state, 1)
	_prepare_players(match_state, {
		player_one["player_id"]: "Player One",
		player_two["player_id"]: "Player Two",
	})
	_set_player_health(player_one, 18)
	_set_player_health(player_two, 12)

	_set_deck(player_one, [
		_build_named_card(player_one["player_id"], "deck_a", {
			"name": "Battlefield Reserve",
			"card_type": "creature",
			"cost": 2,
			"power": 2,
			"health": 2,
		}),
		_build_named_card(player_one["player_id"], "deck_b", {
			"name": "Tactical Insight",
			"card_type": "action",
			"cost": 2,
			"rules_text": "Placeholder action for deck-count visibility.",
		}),
	])
	_set_deck(player_two, [
		_build_named_card(player_two["player_id"], "deck_a", {
			"name": "Graveborn Soldier",
			"card_type": "creature",
			"cost": 2,
			"power": 2,
			"health": 3,
		}),
		_build_named_card(player_two["player_id"], "deck_b", {
			"name": "Shadow Reserve",
			"card_type": "creature",
			"cost": 3,
			"power": 3,
			"health": 2,
		}),
	])

	ScenarioFixtures.add_hand_card(player_one, "field_guardian", {
		"name": "Field Guardian",
		"card_type": "creature",
		"cost": 2,
		"power": 3,
		"health": 4,
		"keywords": [EvergreenRules.KEYWORD_GUARD],
		"rules_text": "Guard.",
	})
	ScenarioFixtures.add_hand_card(player_one, "shadow_raider", {
		"name": "Shadow Raider",
		"card_type": "creature",
		"cost": 3,
		"power": 4,
		"health": 2,
		"keywords": [EvergreenRules.KEYWORD_CHARGE],
		"rules_text": "Charge.",
	})
	ScenarioFixtures.add_hand_card(player_one, "steel_sword", {
		"name": "Steel Sword",
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 2,
		"equip_health_bonus": 1,
		"rules_text": "Give a friendly creature +2/+1.",
	})
	ScenarioFixtures.add_hand_card(player_one, "arsenal", {
		"name": "Arsenal",
		"card_type": "support",
		"cost": 1,
		"activation_cost": 1,
		"support_uses": 2,
		"rules_text": "Activate: Give a creature Guard.",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [{"op": "grant_keyword", "target": "event_target", "keyword_id": EvergreenRules.KEYWORD_GUARD}],
		}],
	})

	ScenarioFixtures.add_hand_card(player_two, "skeletal_sentry", {
		"name": "Skeletal Sentry",
		"card_type": "creature",
		"cost": 2,
		"power": 2,
		"health": 3,
		"keywords": [EvergreenRules.KEYWORD_GUARD],
		"rules_text": "Guard.",
	})
	ScenarioFixtures.add_hand_card(player_two, "ring_burner", {
		"name": "Ring Burner",
		"card_type": "creature",
		"cost": 4,
		"power": 4,
		"health": 4,
		"rules_text": "Heavy creature for Ring testing.",
	})

	var vanguard := ScenarioFixtures.summon_creature(player_one, match_state, "vanguard", "field", 4, 4, [], 0, {
		"name": "Vanguard Captain",
		"cost": 4,
		"rules_text": "A sturdy attacker for the sandbox.",
	})
	ScenarioFixtures.ready_for_attack(vanguard, match_state)

	var enemy_guard := ScenarioFixtures.summon_creature(player_two, match_state, "bone_guard", "field", 2, 3, [EvergreenRules.KEYWORD_GUARD], 0, {
		"name": "Bone Guard",
		"cost": 2,
		"rules_text": "Guard.",
	})
	ScenarioFixtures.ready_for_attack(enemy_guard, match_state)

	var shadow_creature := ScenarioFixtures.summon_creature(player_two, match_state, "night_watch", "shadow", 3, 2, [], 0, {
		"name": "Night Watch",
		"cost": 3,
		"rules_text": "Starts covered in the Shadow Lane.",
	})
	EvergreenRules.grant_cover(shadow_creature, int(match_state.get("turn_number", 0)) + 1)

	_clear_logs(match_state)
	return match_state


static func _build_support_lab() -> Dictionary:
	var match_state := ScenarioFixtures.create_started_match({
		"seed": 23,
		"first_player_index": 0,
		"set_all_magicka": 8,
	})
	if match_state.is_empty():
		return {}

	var player_one: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_two: Dictionary = ScenarioFixtures.player(match_state, 1)
	_prepare_players(match_state, {
		player_one["player_id"]: "Player One",
		player_two["player_id"]: "Player Two",
	})
	_set_player_health(player_one, 22)
	_set_player_health(player_two, 22)

	ScenarioFixtures.add_hand_card(player_one, "battle_drum", {
		"name": "Battle Drum",
		"card_type": "support",
		"cost": 2,
		"activation_cost": 1,
		"support_uses": 3,
		"rules_text": "Activate: Give a friendly creature Guard.",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [{"op": "grant_keyword", "target": "event_target", "keyword_id": EvergreenRules.KEYWORD_GUARD}],
		}],
	})
	ScenarioFixtures.add_hand_card(player_one, "training_blade", {
		"name": "Training Blade",
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 1,
		"equip_health_bonus": 1,
		"rules_text": "Give a friendly creature +1/+1.",
	})

	var target := ScenarioFixtures.summon_creature(player_one, match_state, "target", "field", 2, 2, [], 0, {
		"name": "Training Target",
		"rules_text": "Use support activations and items on this creature.",
	})
	ScenarioFixtures.ready_for_attack(target, match_state)
	ScenarioFixtures.summon_creature(player_two, match_state, "dummy", "field", 1, 4, [], 0, {
		"name": "Dummy Blocker",
		"rules_text": "Enemy body for testing board updates.",
	})

	_clear_logs(match_state)
	return match_state


static func _build_prophecy_lab() -> Dictionary:
	var match_state := ScenarioFixtures.create_started_match({
		"seed": 31,
		"first_player_index": 0,
		"set_all_magicka": 6,
	})
	if match_state.is_empty():
		return {}

	var player_one: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_two: Dictionary = ScenarioFixtures.player(match_state, 1)
	_prepare_players(match_state, {
		player_one["player_id"]: "Player One",
		player_two["player_id"]: "Player Two",
	})
	_set_player_health(player_one, 20)
	_set_player_health(player_two, 30)

	var prophecy_card := _build_named_card(player_two["player_id"], "prophecy_guardian", {
		"name": "Prophecy Guardian",
		"card_type": "creature",
		"cost": 2,
		"power": 3,
		"health": 3,
		"keywords": [EvergreenRules.KEYWORD_GUARD],
		"rules_tags": ["prophecy"],
		"rules_text": "Prophecy. Guard.",
	})
	_set_deck(player_two, [prophecy_card])
	_set_deck(player_one, [_build_named_card(player_one["player_id"], "reserve", {
		"name": "Reserve",
		"card_type": "creature",
		"cost": 1,
		"power": 1,
		"health": 1,
	})])

	var attacker := ScenarioFixtures.summon_creature(player_one, match_state, "attacker", "field", 6, 6, [], 0, {
		"name": "Rune Breaker",
		"rules_text": "Used to pre-open the Prophecy window.",
	})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var damage_result := MatchTiming.apply_player_damage(match_state, player_two["player_id"], 6, {
		"reason": "scenario_setup",
		"source_instance_id": attacker["instance_id"],
		"source_controller_player_id": player_one["player_id"],
	})
	if not bool(damage_result.get("pending_prophecy_opened", false)):
		push_error("Prophecy lab failed to open a pending Prophecy window.")

	return match_state


static func _prepare_players(match_state: Dictionary, display_names: Dictionary) -> void:
	for current_player in match_state.get("players", []):
		current_player["display_name"] = str(display_names.get(str(current_player.get("player_id", "")), str(current_player.get("player_id", ""))))
		current_player["hand"] = []
		current_player["support"] = []
		current_player["discard"] = []
		current_player["banished"] = []
		current_player["deck"] = []
	for lane in match_state.get("lanes", []):
		for player_id in lane.get("player_slots", {}).keys():
			var slots: Array = lane["player_slots"][player_id]
			for slot_index in range(slots.size()):
				slots[slot_index] = null
	_clear_logs(match_state)


static func _set_player_health(player: Dictionary, health: int) -> void:
	player["health"] = health
	var remaining_runes: Array = []
	for threshold in STANDARD_RUNE_THRESHOLDS:
		if threshold <= health:
			remaining_runes.append(threshold)
	player["rune_thresholds"] = remaining_runes


static func _set_deck(player: Dictionary, cards: Array) -> void:
	ScenarioFixtures.set_deck_cards(player, cards)


static func _build_named_card(player_id: String, label: String, extra: Dictionary = {}) -> Dictionary:
	return ScenarioFixtures.make_card(player_id, label, extra)


static func _clear_logs(match_state: Dictionary) -> void:
	match_state["event_log"] = []
	match_state["replay_log"] = []
	match_state["last_timing_result"] = {"processed_events": [], "trigger_resolutions": []}
	match_state["last_combat_events"] = []