extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("RUNES_PROPHECY_FATIGUE_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_rune_break_emits_events_and_enemy_triggers() and
		_test_prophecy_decline_discards_card_when_hand_full() and
		_test_prophecy_creature_can_be_played_for_free() and
		_test_prophecy_action_deals_damage_to_target() and
		_test_fatigue_uses_out_of_cards_and_eventual_loss() and
		_test_on_enemy_rune_destroyed_triggers_invade() and
		_test_fighters_guild_hall_triggers_on_retaliation_damage() and
		_test_prophecy_item_can_be_thrown_at_enemy() and
		_test_prophecy_item_can_be_equipped_to_friendly_creature() and
		_test_prevent_rune_draw_heals_instead_of_drawing() and
		_test_prevent_rune_draw_silenced_does_not_block() and
		_test_draw_cards_per_runes_threshold_logic() and
		_test_destroy_front_rune_draws_card_for_opponent() and
		_test_destroy_front_rune_does_nothing_when_no_runes() and
		_test_any_rune_trigger_fires_once_per_break_for_both_players() and
		_test_fate_weaver_drawing_prophecy_opens_window() and
		_test_fate_weaver_drawing_non_prophecy_does_not_open_window()
	)


func _test_rune_break_emits_events_and_enemy_triggers() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var watcher := _summon_creature(active_player, match_state, "rune_watcher", "field", 2, 2, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"match_role": "opponent_player",
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	var attacker := _summon_creature(active_player, match_state, "rune_breaker", "field", 6, 6, [], 1)
	_target_ready_for_attack(attacker, match_state)
	var hand_before: int = int(opponent["hand"].size())

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var rune_event := _first_event_of_type(result.get("events", []), MatchTiming.EVENT_RUNE_BROKEN)
	return (
		_assert(result["is_valid"], "Rune-break combat fixture should resolve.") and
		_assert(opponent["health"] == 24, "Rune-breaking attack should reduce the defending player to 24 health.") and
		_assert(opponent["rune_thresholds"] == [20, 15, 10, 5], "The 25-health rune should be removed after the first rune break.") and
		_assert(opponent["hand"].size() == hand_before + 1, "Breaking a rune should immediately draw one card.") and
		_assert(int(rune_event.get("threshold", -1)) == 25, "Rune-break event should record the destroyed threshold.") and
		_assert(_families_from_resolutions(result.get("trigger_resolutions", [])) == [MatchTiming.FAMILY_RUNE_BREAK], "Enemy rune-break triggers should resolve through MatchTiming.") and
		_assert(watcher["power_bonus"] == 1, "Rune-break trigger effects should apply to enemy watcher cards.")
	)


func _test_prophecy_decline_discards_card_when_hand_full() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var prophecy_card := _make_card(opponent["player_id"], "decline_prophecy", {
		"zone": "deck",
		"card_type": "action",
		"rules_tags": ["prophecy"],
	})
	_set_deck_cards(opponent, [prophecy_card])
	while opponent["hand"].size() < MatchTiming.MAX_HAND_SIZE:
		_add_hand_card(opponent, "fill_%02d" % opponent["hand"].size(), {"card_type": "action"})
	var attacker := _summon_creature(active_player, match_state, "prophecy_breaker", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(result["is_valid"], "Prophecy draw fixture should resolve.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Drawing a Prophecy from a rune should open a pending Prophecy window.") and
		_assert(opponent["hand"].size() == MatchTiming.MAX_HAND_SIZE + 1, "The drawn Prophecy should remain in hand temporarily while the Prophecy window is open.") and
		_assert(not _first_event_of_type(result.get("events", []), MatchTiming.EVENT_PROPHECY_WINDOW_OPENED).is_empty(), "Rune draw should emit an explicit Prophecy-window event.")
	):
		return false

	var decline_result := MatchTiming.decline_pending_prophecy(match_state, opponent["player_id"], prophecy_card["instance_id"])
	return (
		_assert(decline_result["is_valid"], "Declining a pending Prophecy should succeed.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Declining the Prophecy should clear the pending window.") and
		_assert(opponent["hand"].size() == MatchTiming.MAX_HAND_SIZE, "Declined Prophecy card should be discarded when hand was over the limit.") and
		_assert(str(prophecy_card.get("zone", "")) == "discard", "Declined Prophecy card should move to discard when hand is full.") and
		_assert(not _first_event_of_type(decline_result.get("events", []), MatchTiming.EVENT_PROPHECY_DECLINED).is_empty(), "Declining a Prophecy should emit a dedicated event.") and
		_assert(not _first_event_of_type(decline_result.get("events", []), MatchTiming.EVENT_CARD_OVERDRAW).is_empty(), "Declining a Prophecy at max hand size should emit an overdraw event.")
	)


func _test_prophecy_creature_can_be_played_for_free() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var prophecy_creature := _make_card(opponent["player_id"], "summoned_prophecy", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 5,
		"power": 3,
		"health": 4,
		"rules_tags": ["prophecy"],
	})
	_set_deck_cards(opponent, [prophecy_creature])
	var attacker := _summon_creature(active_player, match_state, "free_play_breaker", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(result["is_valid"], "Prophecy free-play setup should resolve.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Creature Prophecy draw should open a pending window.")
	):
		return false

	var play_result := MatchTiming.play_pending_prophecy(match_state, opponent["player_id"], prophecy_creature["instance_id"], {
		"lane_id": "field",
		"slot_index": 0,
	})
	var played_event := _first_event_of_type(play_result.get("events", []), MatchTiming.EVENT_CARD_PLAYED)
	var summoned_card: Variant = _lane_slot(match_state, "field", opponent["player_id"], 0)
	return (
		_assert(play_result["is_valid"], "Playing a pending creature Prophecy should succeed.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Prophecy play should consume the pending window.") and
		_assert(summoned_card == prophecy_creature, "A free-played Prophecy creature should be placed onto the board.") and
		_assert(bool(played_event.get("played_for_free", false)), "Prophecy play should mark the card-play event as free.") and
		_assert(str(played_event.get("timing_window", "")) == MatchTiming.WINDOW_INTERRUPT, "Prophecy play should run inside the interrupt timing window.")
	)


func _test_prophecy_action_deals_damage_to_target() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var target_creature := _summon_creature(active_player, match_state, "target_dummy", "field", 3, 6, [], 0)
	var prophecy_action := _make_card(opponent["player_id"], "prophecy_bolt", {
		"zone": "deck",
		"card_type": "action",
		"cost": 4,
		"rules_tags": ["prophecy"],
		"triggered_abilities": [{
			"family": "on_play",
			"effects": [{"op": "deal_damage", "target": "event_target", "amount": 4}],
		}],
	})
	_set_deck_cards(opponent, [prophecy_action])
	var attacker := _summon_creature(active_player, match_state, "rune_breaker_bolt", "field", 6, 6, [], 1)
	_target_ready_for_attack(attacker, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(result["is_valid"], "Prophecy action setup should resolve.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Action Prophecy draw should open a pending window.")
	):
		return false

	var play_result := MatchTiming.play_pending_prophecy(match_state, opponent["player_id"], prophecy_action["instance_id"], {
		"target_instance_id": target_creature["instance_id"],
	})
	var damage_event := _first_event_of_type(play_result.get("events", []), MatchTiming.EVENT_DAMAGE_RESOLVED)
	var remaining_health := int(target_creature.get("health", 0)) - int(target_creature.get("damage_marked", 0))
	return (
		_assert(play_result["is_valid"], "Playing a pending action Prophecy with a target should succeed.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Prophecy play should consume the pending window.") and
		_assert(not damage_event.is_empty(), "Prophecy action should emit a damage_resolved event.") and
		_assert(int(damage_event.get("amount", 0)) == 4, "Prophecy action should deal 4 damage.") and
		_assert(remaining_health == 2, "Target creature should have 2 health remaining after 4 damage to a 6-health creature.") and
		_assert(str(prophecy_action.get("zone", "")) == "discard", "Prophecy action should move to discard after being played.")
	)


func _test_fatigue_uses_out_of_cards_and_eventual_loss() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	active_player["deck"] = []
	active_player["hand"] = []

	var first_fatigue := MatchTiming.draw_cards(match_state, active_player["player_id"], 1, {"reason": "fatigue_test"})
	var out_of_cards_event := _first_event_of_type(first_fatigue.get("events", []), MatchTiming.EVENT_OUT_OF_CARDS_PLAYED)
	var fatigue_rune_event := _first_event_of_type(first_fatigue.get("events", []), MatchTiming.EVENT_RUNE_BROKEN)
	if not (
		_assert(not out_of_cards_event.is_empty(), "Fatigue should create an explicit Out of Cards event.") and
		_assert(int(fatigue_rune_event.get("threshold", -1)) == 25, "The first fatigue draw should destroy the 25-health rune.") and
		_assert(active_player["health"] == 25, "Out of Cards should reduce health to the destroyed rune's threshold.") and
		_assert(active_player["rune_thresholds"] == [20, 15, 10, 5], "Fatigue should remove the front rune without drawing a replacement card.") and
		_assert(_first_event_of_type(first_fatigue.get("events", []), MatchTiming.EVENT_CARD_DRAWN).is_empty(), "Fatigue should not emit a normal card-drawn event.")
	):
		return false

	var final_result := {}
	for _index in range(5):
		final_result = MatchTiming.draw_cards(match_state, active_player["player_id"], 1, {"reason": "fatigue_test"})
	return (
		_assert(bool(final_result.get("player_lost", false)), "Once all runes are gone, another empty-deck draw should lose the game.") and
		_assert(active_player["health"] == 0, "Final fatigue should reduce health to zero when no runes remain.") and
		_assert(str(match_state.get("winner_player_id", "")) == opponent["player_id"], "The opposing player should win when Out of Cards fires with no runes remaining.") and
		_assert(_count_out_of_cards(active_player) == 6, "Each empty-deck draw should create a distinct Out of Cards card in discard.")
	)


func _test_on_enemy_rune_destroyed_triggers_invade() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Create a creature with the on_enemy_rune_destroyed family (like Widow Daedra)
	var watcher := _summon_creature(active_player, match_state, "rune_invader", "shadow", 5, 3, [], 0, {
		"subtypes": ["Daedra"],
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_ENEMY_RUNE_DESTROYED,
			"required_zone": "lane",
			"effects": [{"op": "invade"}],
		}]
	})
	var attacker := _summon_creature(active_player, match_state, "face_hitter", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var families := _families_from_resolutions(result.get("trigger_resolutions", []))
	# Invade should have created an Oblivion Gate
	var gate_found := false
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == "shadow":
			for card in lane.get("player_slots", {}).get(active_player["player_id"], []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "generated_oblivion_gate":
					gate_found = true
	if not (
		_assert(result["is_valid"], "on_enemy_rune_destroyed test: attack should resolve.") and
		_assert(opponent["health"] == 24, "on_enemy_rune_destroyed test: opponent should take 6 damage.") and
		_assert(families.has(MatchTiming.FAMILY_ON_ENEMY_RUNE_DESTROYED), "on_enemy_rune_destroyed trigger should fire when enemy rune is broken.") and
		_assert(gate_found, "on_enemy_rune_destroyed with invade effect should create an Oblivion Gate.")
	):
		return false
	# Now test with existing gate (simulating Widow Daedra after an earlier invade)
	# The gate was created at level 1. Attack face again to break another rune and trigger a second invade.
	var attacker2 := _summon_creature(active_player, match_state, "face_hitter_2", "field", 6, 6, [], 1)
	_target_ready_for_attack(attacker2, match_state)
	var result2 := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker2["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var families2 := _families_from_resolutions(result2.get("trigger_resolutions", []))
	# Find the gate and check its level
	var gate_level := 0
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == "shadow":
			for card in lane.get("player_slots", {}).get(active_player["player_id"], []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "generated_oblivion_gate":
					gate_level = int(card.get("gate_level", 0))
	return (
		_assert(result2["is_valid"], "on_enemy_rune_destroyed test: second attack should resolve.") and
		_assert(families2.has(MatchTiming.FAMILY_ON_ENEMY_RUNE_DESTROYED), "on_enemy_rune_destroyed should fire on second rune break too.") and
		_assert(gate_level == 2, "Gate should be upgraded to level 2 after second invade (was %d)." % gate_level)
	)


func _test_prophecy_item_can_be_thrown_at_enemy() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Create a prophecy item card (like Spear of Embers) in the opponent's deck
	var prophecy_item := _make_card(opponent["player_id"], "prophecy_spear", {
		"card_type": "item",
		"rules_tags": ["prophecy"],
		"equip_power_bonus": 3,
		"equip_health_bonus": 3,
		"triggered_abilities": [{
			"family": "on_play",
			"target_mode": "enemy_creature_optional",
			"effects": [{"op": "deal_damage", "target": "chosen_target", "amount": 3}],
		}],
	})
	_set_deck_cards(opponent, [prophecy_item])
	# Put a creature on the active player's side (enemy from opponent's perspective)
	var target_creature := _summon_creature(active_player, match_state, "enemy_target", "field", 4, 6, [], 0)
	# Attacker breaks opponent's rune, triggering prophecy draw
	var attacker := _summon_creature(active_player, match_state, "rune_breaker_item", "field", 6, 6, [], 1)
	_target_ready_for_attack(attacker, match_state)

	var attack_result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(attack_result["is_valid"], "Prophecy item test: attack should resolve.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Item Prophecy draw should open a pending window.")
	):
		return false

	# Play the prophecy item by throwing it at the enemy creature
	var play_result := MatchTiming.play_pending_prophecy(match_state, opponent["player_id"], prophecy_item["instance_id"], {
		"target_instance_id": target_creature["instance_id"],
	})
	var remaining := int(target_creature.get("health", 0)) - int(target_creature.get("damage_marked", 0))
	return (
		_assert(bool(play_result.get("is_valid", false)), "Playing a pending item Prophecy thrown at enemy should succeed.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Prophecy play should consume the pending window.") and
		_assert(remaining == 3, "Target creature should have 3 health remaining after 3 throw damage to a 6-health creature (got %d)." % remaining) and
		_assert(str(prophecy_item.get("zone", "")) == "discard", "Thrown prophecy item should move to discard.")
	)


func _test_prophecy_item_can_be_equipped_to_friendly_creature() -> bool:
	# Regression: an equip-only prophecy item (e.g. Covenant Mail) drawn during the
	# opponent's turn must validate against friendly-creature targets. Previously the
	# UI fed validation through play_item_from_hand, which rejected it because the
	# active player was the opponent — locking the player out of equipping it.
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Friendly creature on the opponent's side (the prophecy holder) to receive the item
	var friendly_target := _summon_creature(opponent, match_state, "covenant_target", "field", 2, 3, [], 0)
	var prophecy_item := _make_card(opponent["player_id"], "prophecy_covenant_mail", {
		"card_type": "item",
		"rules_tags": ["prophecy"],
		"equip_power_bonus": 1,
		"equip_health_bonus": 4,
	})
	_set_deck_cards(opponent, [prophecy_item])
	var attacker := _summon_creature(active_player, match_state, "rune_breaker_mail", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)

	var attack_result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(attack_result["is_valid"], "Prophecy item equip test: attack should resolve.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Item Prophecy draw should open a pending window.")
	):
		return false

	var play_result := MatchTiming.play_pending_prophecy(match_state, opponent["player_id"], prophecy_item["instance_id"], {
		"target_instance_id": friendly_target["instance_id"],
	})
	var attached: Array = friendly_target.get("attached_items", [])
	var attached_id := str(attached[0].get("instance_id", "")) if attached.size() > 0 else ""
	return (
		_assert(bool(play_result.get("is_valid", false)), "Equipping a prophecy item to a friendly creature during the opponent's turn should succeed.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Prophecy play should consume the pending window.") and
		_assert(attached_id == str(prophecy_item.get("instance_id", "")), "Prophecy item should be attached to the friendly target after play.")
	)


func _test_fighters_guild_hall_triggers_on_retaliation_damage() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Add Fighters Guild Hall as a support
	var support := ScenarioFixtures.make_card(active_player["player_id"], "fighters_guild", {
		"card_type": "support",
		"zone": "support",
		"triggered_abilities": [{
			"family": "on_damage",
			"match_role": "friendly_target",
			"required_zone": "support",
			"required_controller_turn": true,
			"effects": [{"op": "modify_stats", "target": "damaged_creature", "power": 2, "health": 0}],
		}]
	})
	active_player["support"].append(support)
	# Summon attacker for active player
	var attacker := _summon_creature(active_player, match_state, "guild_fighter", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)
	# Summon a defender for opponent
	var defender := _summon_creature(opponent, match_state, "guild_target", "field", 3, 2, [], 0)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": defender["instance_id"],
	})
	var families := _families_from_resolutions(result.get("trigger_resolutions", []))
	return (
		_assert(result["is_valid"], "Fighters Guild Hall test: attack should resolve.") and
		_assert(families.has(MatchTiming.FAMILY_ON_DAMAGE), "on_damage trigger should fire when friendly creature takes retaliation damage.") and
		_assert(int(attacker.get("power_bonus", 0)) == 2, "Fighters Guild Hall should give +2/+0 to damaged creature.")
	)


func _test_prevent_rune_draw_heals_instead_of_drawing() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Summon a Varen-like creature for the opponent (the one whose runes break)
	var _varen := _summon_creature(opponent, match_state, "varen", "field", 4, 6, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"required_zone": "lane",
			"effects": [
				{"op": "heal", "target_player": "controller", "amount": 5},
				{"op": "prevent_rune_draw"},
			],
		}]
	})
	var attacker := _summon_creature(active_player, match_state, "rune_breaker", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)
	var hand_before: int = opponent["hand"].size()
	var health_before: int = opponent["health"]

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var rune_event := _first_event_of_type(result.get("events", []), MatchTiming.EVENT_RUNE_BROKEN)
	# Took 6 damage, healed 5 from Varen → net 1 health lost
	return (
		_assert(result["is_valid"], "Prevent-rune-draw fixture should resolve.") and
		_assert(opponent["hand"].size() == hand_before, "No card should be drawn when prevent_rune_draw creature is in lane.") and
		_assert(not rune_event.is_empty(), "Rune-break event should still be emitted.") and
		_assert(bool(rune_event.get("draw_card", true)) == false, "Rune-break event should have draw_card=false.") and
		_assert(opponent["health"] == health_before - 6 + 5, "Player should be healed by 5 from the rune_break trigger.")
	)


func _test_prevent_rune_draw_silenced_does_not_block() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var varen := _summon_creature(opponent, match_state, "varen_silenced", "field", 4, 6, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"required_zone": "lane",
			"effects": [
				{"op": "heal", "target_player": "controller", "amount": 5},
				{"op": "prevent_rune_draw"},
			],
		}]
	})
	# Silence Varen
	if not varen.has("status_markers"):
		varen["status_markers"] = []
	varen["status_markers"].append("silenced")
	var attacker := _summon_creature(active_player, match_state, "rune_breaker", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)
	var hand_before: int = opponent["hand"].size()

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	return (
		_assert(result["is_valid"], "Silenced Varen fixture should resolve.") and
		_assert(opponent["hand"].size() == hand_before + 1, "Silenced prevent_rune_draw creature should not block the rune draw.")
	)


func _build_started_match(deck_size: int, first_player_index: int) -> Dictionary:
	return ScenarioFixtures.create_started_match({
		"deck_size": deck_size,
		"seed": 37,
		"first_player_index": first_player_index,
		"set_all_magicka": 10,
	})


func _summon_creature(player: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int, keywords: Array = [], slot_index := -1, extra: Dictionary = {}) -> Dictionary:
	var card := ScenarioFixtures.summon_creature(player, match_state, label, lane_id, power, health, keywords, slot_index, extra)
	_assert(not card.is_empty(), "Expected summon fixture for %s to succeed." % label)
	return card


func _add_hand_card(player: Dictionary, label: String, extra: Dictionary = {}) -> Dictionary:
	return ScenarioFixtures.add_hand_card(player, label, extra)


func _make_card(player_id: String, label: String, extra: Dictionary = {}) -> Dictionary:
	return ScenarioFixtures.make_card(player_id, label, extra)


func _set_deck_cards(player: Dictionary, cards: Array) -> void:
	ScenarioFixtures.set_deck_cards(player, cards)


func _target_ready_for_attack(card: Dictionary, match_state: Dictionary) -> void:
	ScenarioFixtures.ready_for_attack(card, match_state)


func _lane_slot(match_state: Dictionary, lane_id: String, player_id: String, slot_index: int):
	return ScenarioFixtures.lane_slot(match_state, lane_id, player_id, slot_index)


func _test_destroy_front_rune_draws_card_for_opponent() -> bool:
	# Lyris Titanborn style: start_of_turn destroy_front_rune should draw a card for the opponent
	var match_state := _build_started_match(20, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Summon a creature with Lyris's start_of_turn destroy_front_rune effect
	_summon_creature(player, match_state, "lyris", "field", 5, 5, [], -1, {
		"triggered_abilities": [{"family": "start_of_turn", "required_zone": "lane", "effects": [{"op": "damage", "target_player": "opponent", "amount": "destroy_front_rune"}]}]
	})
	var hp_before: int = int(opponent.get("health", 30))
	# End player's turn — opponent's turn starts (normal turn draw happens)
	MatchTurnLoop.end_turn(match_state, pid)
	# Measure hand AFTER opponent's normal turn draw, before Lyris triggers
	var hand_before: int = opponent["hand"].size()
	# End opponent's turn — player's turn starts, Lyris fires
	MatchTurnLoop.end_turn(match_state, oid)
	var hp_after: int = int(opponent.get("health", 30))
	return (
		_assert(hp_after < hp_before, "destroy_front_rune should reduce opponent HP.") and
		_assert(opponent["hand"].size() == hand_before + 1, "destroy_front_rune should draw a card for the opponent.")
	)


func _test_destroy_front_rune_does_nothing_when_no_runes() -> bool:
	# When opponent has no runes remaining, destroy_front_rune should not deal damage
	var match_state := _build_started_match(20, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Clear all runes and set HP low
	opponent["rune_thresholds"] = []
	opponent["health"] = 3
	# Summon a creature with the destroy_front_rune effect
	_summon_creature(player, match_state, "lyris", "field", 5, 5, [], -1, {
		"triggered_abilities": [{"family": "start_of_turn", "required_zone": "lane", "effects": [{"op": "damage", "target_player": "opponent", "amount": "destroy_front_rune"}]}]
	})
	# End player's turn — opponent's turn starts (normal turn draw happens)
	MatchTurnLoop.end_turn(match_state, pid)
	# Measure hand AFTER opponent's normal turn draw
	var hand_before: int = opponent["hand"].size()
	# End opponent's turn — player's turn starts, Lyris fires (should do nothing)
	MatchTurnLoop.end_turn(match_state, oid)
	return (
		_assert(int(opponent.get("health", 0)) == 3, "destroy_front_rune with no runes should not deal damage, got %d HP." % int(opponent.get("health", 0))) and
		_assert(opponent["hand"].size() == hand_before, "destroy_front_rune with no runes should not draw a card.")
	)


func _test_any_rune_trigger_fires_once_per_break_for_both_players() -> bool:
	# A creature with on_enemy_rune_destroyed + match_role:any_player should get +1/+0
	# per rune break, regardless of which player's rune it was, and only once per break.
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var cadwell := _summon_creature(active_player, match_state, "cadwell", "field", 0, 1, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_ENEMY_RUNE_DESTROYED,
			"match_role": "any_player",
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	# Break an enemy rune
	var attacker := _summon_creature(active_player, match_state, "big_hitter", "field", 6, 6, [], 1)
	_target_ready_for_attack(attacker, match_state)
	MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var power_after_enemy_rune: int = int(cadwell.get("power_bonus", 0))

	# Switch to opponent's turn so they can attack
	var pid := str(active_player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	MatchTurnLoop.end_turn(match_state, pid)

	# Break a friendly rune (opponent attacks active player)
	var enemy_attacker := _summon_creature(opponent, match_state, "enemy_hitter", "field", 6, 6, [], 0)
	_target_ready_for_attack(enemy_attacker, match_state)
	MatchCombat.resolve_attack(match_state, oid, enemy_attacker["instance_id"], {
		"type": "player",
		"player_id": pid,
	})
	var power_after_friendly_rune: int = int(cadwell.get("power_bonus", 0))

	return (
		_assert(power_after_enemy_rune == 1, "any_player rune trigger should give +1/+0 on enemy rune break (got +%d)." % power_after_enemy_rune) and
		_assert(power_after_friendly_rune == 2, "any_player rune trigger should also fire on friendly rune break (got +%d)." % power_after_friendly_rune)
	)


func _count_out_of_cards(player: Dictionary) -> int:
	var count := 0
	for card in player.get("discard", []):
		if str(card.get("definition_id", "")) == "out_of_cards":
			count += 1
	return count


func _first_event_of_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if str(event.get("event_type", "")) == event_type:
			return event
	return {}


func _families_from_resolutions(resolutions: Array) -> Array:
	var families: Array = []
	for resolution in resolutions:
		families.append(str(resolution.get("family", "")))
	return families


func _build_deck(prefix: String, size: int) -> Array:
	return ScenarioFixtures.build_deck(prefix, size)


func _test_draw_cards_per_runes_threshold_logic() -> bool:
	# 5 runes intact → draw 2 (one for ≥4, one for ≥5)
	var ms5 := _build_started_match(20, 0)
	var p5: Dictionary = ms5["players"][0]
	p5["rune_thresholds"] = [25, 20, 15, 10, 5]
	var hand_before_5 : int = int(p5["hand"].size())
	_summon_creature(p5, ms5, "wilds_5r", "field", 5, 6, ["guard"], -1, {
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "draw_cards_per_runes", "rune_thresholds": [{"min_runes": 4, "count": 1}, {"min_runes": 5, "count": 1}]}]}],
	})
	# summon_creature adds to hand then summons (net 0), so drawn = hand_after - hand_before
	var drawn_5 : int = int(p5["hand"].size()) - hand_before_5

	# 4 runes intact → draw 1 (only the ≥4 threshold met)
	var ms4 := _build_started_match(20, 0)
	var p4: Dictionary = ms4["players"][0]
	p4["rune_thresholds"] = [20, 15, 10, 5]
	var hand_before_4 : int = int(p4["hand"].size())
	_summon_creature(p4, ms4, "wilds_4r", "field", 5, 6, ["guard"], -1, {
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "draw_cards_per_runes", "rune_thresholds": [{"min_runes": 4, "count": 1}, {"min_runes": 5, "count": 1}]}]}],
	})
	var drawn_4 : int = int(p4["hand"].size()) - hand_before_4

	# 3 runes intact → draw 0 (neither threshold met)
	var ms3 := _build_started_match(20, 0)
	var p3: Dictionary = ms3["players"][0]
	p3["rune_thresholds"] = [15, 10, 5]
	var hand_before_3 : int = int(p3["hand"].size())
	_summon_creature(p3, ms3, "wilds_3r", "field", 5, 6, ["guard"], -1, {
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "draw_cards_per_runes", "rune_thresholds": [{"min_runes": 4, "count": 1}, {"min_runes": 5, "count": 1}]}]}],
	})
	var drawn_3 : int = int(p3["hand"].size()) - hand_before_3

	return (
		_assert(drawn_5 == 2, "With 5 runes, draw_cards_per_runes should draw 2 cards (got %d)." % drawn_5) and
		_assert(drawn_4 == 1, "With 4 runes, draw_cards_per_runes should draw 1 card (got %d)." % drawn_4) and
		_assert(drawn_3 == 0, "With 3 runes, draw_cards_per_runes should draw 0 cards (got %d)." % drawn_3)
	)


func _test_fate_weaver_drawing_prophecy_opens_window() -> bool:
	# Fate Weaver: Summon: Draw a card. If it's a Prophecy, you may play it for free.
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var pid := str(active_player.get("player_id", ""))
	var prophecy_card := _make_card(pid, "fw_prophecy_target", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 3,
		"power": 3,
		"health": 3,
		"rules_tags": ["prophecy"],
	})
	_set_deck_cards(active_player, [prophecy_card])
	var fate_weaver := _summon_creature(active_player, match_state, "fate_weaver_analog", "field", 3, 3, [], -1, {
		"rules_tags": ["prophecy"],
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 1, "allow_prophecy_interrupt": true}]}],
	})
	return (
		_assert(not fate_weaver.is_empty(), "Fate Weaver analog should summon successfully.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, pid), "Drawing a Prophecy via Fate Weaver should open a pending Prophecy window.") and
		_assert(str(prophecy_card.get("zone", "")) == "hand", "Drawn Prophecy card should be in hand while the window is open.")
	)


func _test_fate_weaver_drawing_non_prophecy_does_not_open_window() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var pid := str(active_player.get("player_id", ""))
	var regular_card := _make_card(pid, "fw_regular_target", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 3,
		"power": 3,
		"health": 3,
	})
	_set_deck_cards(active_player, [regular_card])
	var fate_weaver := _summon_creature(active_player, match_state, "fate_weaver_analog2", "field", 3, 3, [], -1, {
		"rules_tags": ["prophecy"],
		"triggered_abilities": [{"family": "summon", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 1, "allow_prophecy_interrupt": true}]}],
	})
	return (
		_assert(not fate_weaver.is_empty(), "Fate Weaver analog should summon successfully.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, pid), "Drawing a non-Prophecy card via Fate Weaver should NOT open a Prophecy window.") and
		_assert(str(regular_card.get("zone", "")) == "hand", "Drawn non-Prophecy card should be in hand normally.")
	)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false