extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("COMBAT_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_readiness_restrictions_and_charge() and
		_test_lane_lock_cover_and_guard_legality() and
		_test_creature_combat_is_simultaneous_and_cleans_up_dead_creatures() and
		_test_breakthrough_and_player_damage() and
		_test_direct_player_attack_emits_events_and_applies_drain() and
		_test_attack_refreshes_on_controller_next_turn()
	)


func _test_readiness_restrictions_and_charge() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "fresh_attacker", "field", 3, 3)
	var charge_attacker := _summon_creature(active_player, match_state, "charge_attacker", "field", 2, 2, ["charge"], 1)
	var target := _summon_creature(opponent, match_state, "target", "field", 2, 2)
	_target_ready_for_attack(target, match_state)

	var fresh_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": target["instance_id"],
	})
	var charge_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], charge_attacker["instance_id"], {
		"type": "creature",
		"instance_id": target["instance_id"],
	})
	attacker["status_markers"] = ["shackled"]
	var shackled_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": target["instance_id"],
	})

	return (
		_assert(not fresh_validation["is_valid"], "Creatures without Charge should not attack on the turn they enter play.") and
		_assert(charge_validation["is_valid"], "Charge creatures should bypass summon sickness.") and
		_assert(not shackled_validation["is_valid"], "Shackled creatures should be unable to attack.")
	)


func _test_lane_lock_cover_and_guard_legality() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "attacker", "field", 3, 3)
	_target_ready_for_attack(attacker, match_state)
	var cross_lane_target := _summon_creature(opponent, match_state, "cross_lane", "shadow", 2, 2)
	_target_ready_for_attack(cross_lane_target, match_state)
	var cross_lane_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": cross_lane_target["instance_id"],
	})
	var covered_target := _summon_creature(opponent, match_state, "covered", "field", 2, 2, [], -1, {"cover": true})
	var cover_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": covered_target["instance_id"],
	})
	var guard_target := _summon_creature(opponent, match_state, "guard", "field", 2, 4, ["guard"])
	_target_ready_for_attack(guard_target, match_state)
	var plain_target := _summon_creature(opponent, match_state, "plain", "field", 2, 2)
	_target_ready_for_attack(plain_target, match_state)
	var player_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var plain_target_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": plain_target["instance_id"],
	})
	var guard_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": guard_target["instance_id"],
	})

	return (
		_assert(not cross_lane_validation["is_valid"], "Creature attacks should be lane-locked.") and
		_assert(not cover_validation["is_valid"], "Covered creatures should not be legal attack targets.") and
		_assert(not player_validation["is_valid"], "Guards in lane should block direct player attacks.") and
		_assert(not plain_target_validation["is_valid"], "Guards in lane should intercept attacks against non-Guard creatures.") and
		_assert(guard_validation["is_valid"], "Guard creatures in the same lane should remain legal targets.")
	)


func _test_creature_combat_is_simultaneous_and_cleans_up_dead_creatures() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "lethal_attacker", "field", 1, 1, ["lethal"])
	var defender := _summon_creature(opponent, match_state, "big_defender", "field", 5, 5)
	_target_ready_for_attack(attacker, match_state)
	_target_ready_for_attack(defender, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": defender["instance_id"],
	})

	return (
		_assert(result["is_valid"], "Lethal combat scenario should resolve successfully.") and
		_assert(result["attacker_destroyed"] and result["defender_destroyed"], "Combat damage should be simultaneous and lethal should still destroy the larger defender.") and
		_assert(active_player["discard"].size() == 1 and opponent["discard"].size() == 1, "Destroyed creatures should leave the board for discard.") and
		_assert(_lane_slot(match_state, "field", active_player["player_id"], 0) == null and _lane_slot(match_state, "field", opponent["player_id"], 0) == null, "Dead creatures should be removed from their lane slots.")
	)


func _test_breakthrough_and_player_damage() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "breakthrough_attacker", "field", 5, 4, ["breakthrough"])
	var defender := _summon_creature(opponent, match_state, "small_defender", "field", 2, 2)
	_target_ready_for_attack(attacker, match_state)
	_target_ready_for_attack(defender, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": defender["instance_id"],
	})

	return (
		_assert(result["is_valid"], "Breakthrough combat scenario should resolve successfully.") and
		_assert(result["breakthrough_damage"] == 3, "Breakthrough should deal excess combat damage to the opposing player.") and
		_assert(opponent["health"] == 27, "Opposing player should lose the excess Breakthrough damage.") and
		_assert(active_player["health"] == 30, "Breakthrough alone should not heal the attacking player.")
	)


func _test_direct_player_attack_emits_events_and_applies_drain() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	active_player["health"] = 24
	var attacker := _summon_creature(active_player, match_state, "drain_attacker", "field", 4, 4, ["drain"])
	_target_ready_for_attack(attacker, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})

	if not (
		_assert(result["is_valid"], "Direct player attack should resolve successfully.") and
		_assert(result["damage_to_player"] == 4, "Direct player attacks should deal attacker power as damage.") and
		_assert(result["drain_heal"] == 4, "Drain should heal for player damage dealt on the active turn.") and
		_assert(active_player["health"] == 28, "Drain should increase the attacker's controller health.") and
		_assert(opponent["health"] == 26, "Opposing player should lose the direct attack damage.") and
		_assert(match_state["last_combat_events"].size() >= 4, "Combat resolution should emit structured events.")
	):
		return false

	var event_types := []
	for event in result["events"]:
		event_types.append(str(event.get("event_type", "")))
	return _assert(event_types.has("attack_declared") and event_types.has("damage_resolved") and event_types.has("player_healed") and event_types.has("attack_resolved"), "Combat result should include declaration, damage, heal, and resolution events.")


func _test_attack_refreshes_on_controller_next_turn() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "repeat_attacker", "field", 3, 3)
	var defender_one := _summon_creature(opponent, match_state, "defender_one", "field", 1, 1)
	_target_ready_for_attack(attacker, match_state)
	_target_ready_for_attack(defender_one, match_state)

	var first_attack := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": defender_one["instance_id"],
	})
	if not _assert(first_attack["is_valid"], "First attack should resolve successfully."):
		return false

	var same_turn_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(not same_turn_validation["is_valid"], "Creature should not attack twice in the same turn."):
		return false

	MatchTurnLoop.end_turn(match_state, active_player["player_id"])
	MatchTurnLoop.end_turn(match_state, opponent["player_id"])
	var defender_two := _summon_creature(opponent, match_state, "defender_two", "field", 2, 2)
	_target_ready_for_attack(defender_two, match_state)
	var next_turn_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": defender_two["instance_id"],
	})
	return _assert(next_turn_validation["is_valid"], "Attacker should refresh for its controller's next turn.")


func _build_started_match(deck_size: int, first_player_index: int) -> Dictionary:
	var match_state := MatchBootstrap.create_standard_match([
		_build_deck("alpha", deck_size),
		_build_deck("beta", deck_size)
	], {
		"seed": 23,
		"first_player_index": first_player_index,
	})
	if match_state.is_empty():
		return {}

	for player in match_state["players"]:
		MatchBootstrap.apply_mulligan(match_state, player["player_id"], [])
	MatchTurnLoop.begin_first_turn(match_state)
	return match_state


func _summon_creature(player: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int, keywords: Array = [], slot_index := -1, extra: Dictionary = {}) -> Dictionary:
	var card := {
		"instance_id": "%s_%s" % [player["player_id"], label],
		"definition_id": "test_%s" % label,
		"owner_player_id": player["player_id"],
		"controller_player_id": player["player_id"],
		"zone": "hand",
		"card_type": "creature",
		"power": power,
		"health": health,
		"damage_marked": int(extra.get("damage_marked", 0)),
		"keywords": keywords.duplicate(),
		"granted_keywords": [],
		"status_markers": extra.get("status_markers", []).duplicate(),
	}
	player["hand"].append(card)
	var summon_options := {}
	if slot_index >= 0:
		summon_options["slot_index"] = slot_index
	var result := LaneRules.summon_from_hand(match_state, player["player_id"], card["instance_id"], lane_id, summon_options)
	_assert(result["is_valid"], "Expected summon fixture for %s to succeed." % label)
	if bool(extra.get("cover", false)):
		var status_markers: Array = card.get("status_markers", [])
		if not status_markers.has("cover"):
			status_markers.append("cover")
		card["status_markers"] = status_markers
		card["cover_expires_on_turn"] = int(match_state.get("turn_number", 0))
	return card


func _target_ready_for_attack(card: Dictionary, match_state: Dictionary) -> void:
	card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	card["has_attacked_this_turn"] = false
	var status_markers: Array = card.get("status_markers", [])
	status_markers.erase("shackled")
	card["status_markers"] = status_markers


func _lane_slot(match_state: Dictionary, lane_id: String, player_id: String, slot_index: int):
	for lane in match_state["lanes"]:
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		var player_slots: Array = lane["player_slots"][player_id]
		if slot_index >= 0 and slot_index < player_slots.size():
			return player_slots[slot_index]
		return null
	return null


func _build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true

	push_error(message)
	return false