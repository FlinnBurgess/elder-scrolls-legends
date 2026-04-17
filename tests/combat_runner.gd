extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")


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
		_test_attack_refreshes_on_controller_next_turn() and
		_test_guards_both_lanes_cross_lane_targeting() and
		_test_move_to_attack_into_shadow_lane_loses_cover() and
		_test_grants_immunity_lethal_survives_combat() and
		_test_amulet_of_mara_blocks_attack_between_wielders() and
		_test_escalating_damage_sets_counter_on_card() and
		_test_wounded_enemy_damage_immunity() and
		_test_attack_condition_blocks_attack_without_action_played() and
		_test_shackle_permanent_unless_equipped() and
		_test_damage_on_own_turn_immunity()
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


func _test_guards_both_lanes_cross_lane_targeting() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]

	# Place a guards_both_lanes creature in field lane for the opponent
	var lydia := _summon_creature(opponent, match_state, "lydia", "field", 3, 8, ["guard"], -1, {"status_markers": ["guards_both_lanes"]})
	_target_ready_for_attack(lydia, match_state)

	# Place an attacker in the shadow lane (cross-lane from Lydia)
	var shadow_attacker := _summon_creature(active_player, match_state, "shadow_attacker", "shadow", 3, 3)
	_target_ready_for_attack(shadow_attacker, match_state)

	# Place an attacker in the field lane (same lane as Lydia)
	var field_attacker := _summon_creature(active_player, match_state, "field_attacker", "field", 3, 3)
	_target_ready_for_attack(field_attacker, match_state)

	# Cross-lane attacker should be able to target Lydia
	var cross_lane_attack := MatchCombat.validate_attack(match_state, active_player["player_id"], shadow_attacker["instance_id"], {
		"type": "creature",
		"instance_id": lydia["instance_id"],
	})

	# Same-lane attacker should be able to target Lydia
	var same_lane_attack := MatchCombat.validate_attack(match_state, active_player["player_id"], field_attacker["instance_id"], {
		"type": "creature",
		"instance_id": lydia["instance_id"],
	})

	# Cross-lane attacker should NOT be able to attack player (Lydia guards both lanes)
	var cross_lane_player_attack := MatchCombat.validate_attack(match_state, active_player["player_id"], shadow_attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})

	# Same-lane attacker should NOT be able to attack player
	var same_lane_player_attack := MatchCombat.validate_attack(match_state, active_player["player_id"], field_attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})

	return (
		_assert(cross_lane_attack["is_valid"], "Cross-lane attacker should be able to target a guards_both_lanes creature.") and
		_assert(same_lane_attack["is_valid"], "Same-lane attacker should be able to target a guards_both_lanes creature.") and
		_assert(not cross_lane_player_attack["is_valid"], "Guards_both_lanes should block player attacks from other lanes.") and
		_assert(not same_lane_player_attack["is_valid"], "Guards_both_lanes should block player attacks from the same lane.")
	)


func _test_move_to_attack_into_shadow_lane_loses_cover() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]

	# Place a move_to_attack creature in the field lane
	var stalker := _summon_creature(active_player, match_state, "stalker", "field", 4, 4, [], -1, {"status_markers": ["move_to_attack_any_lane"]})
	_target_ready_for_attack(stalker, match_state)

	# Place a weak enemy in the shadow lane (remove cover so it can be attacked)
	var imp := _summon_creature(opponent, match_state, "imp", "shadow", 1, 1)
	_target_ready_for_attack(imp, match_state)
	EvergreenRules.remove_status(imp, EvergreenRules.STATUS_COVER)

	# Stalker should not have cover before attacking
	_assert(not EvergreenRules.has_raw_status(stalker, EvergreenRules.STATUS_COVER), "Stalker should not have cover before cross-lane attack.")

	# Attack cross-lane: stalker moves to shadow lane then attacks
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], stalker["instance_id"], {
		"type": "creature",
		"instance_id": imp["instance_id"],
	})
	_assert(result["is_valid"], "Cross-lane move-to-attack should succeed.")

	# After attacking, the stalker should NOT have cover — it was granted by shadow lane entry then removed by attacking
	return _assert(not EvergreenRules.has_raw_status(stalker, EvergreenRules.STATUS_COVER), "Move-to-attack creature should lose cover after attacking into shadow lane.")


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


func _test_grants_immunity_lethal_survives_combat() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var immune_creature := _summon_creature(active_player, match_state, "lethal_immune", "field", 5, 5)
	immune_creature["grants_immunity"] = ["lethal"]
	var lethal_defender := _summon_creature(opponent, match_state, "lethal_defender", "field", 2, 2, ["lethal"])
	_target_ready_for_attack(immune_creature, match_state)
	_target_ready_for_attack(lethal_defender, match_state)
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], immune_creature["instance_id"], {
		"type": "creature",
		"instance_id": lethal_defender["instance_id"],
	})
	var immune_loc := MatchMutations.find_card_location(match_state, immune_creature["instance_id"])
	var defender_loc := MatchMutations.find_card_location(match_state, lethal_defender["instance_id"])
	return (
		_assert(result["is_valid"], "Attack should resolve.") and
		_assert(str(immune_loc.get("zone", "")) == "lane", "Lethal-immune creature should survive in lane. Got zone: %s." % str(immune_loc.get("zone", ""))) and
		_assert(str(defender_loc.get("zone", "")) == "discard", "Lethal defender should be destroyed. Got zone: %s." % str(defender_loc.get("zone", ""))) and
		_assert(int(immune_creature.get("damage_marked", 0)) == 2, "Immune creature should take 2 damage. Got %d." % int(immune_creature.get("damage_marked", 0)))
	)


func _test_amulet_of_mara_blocks_attack_between_wielders() -> bool:
	var match_state := _build_started_match(18, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var amulet := {"instance_id": "amulet_1", "definition_id": "mc_wil_amulet_of_mara", "name": "Amulet of Mara", "card_type": "item"}
	var amulet2 := {"instance_id": "amulet_2", "definition_id": "mc_wil_amulet_of_mara", "name": "Amulet of Mara", "card_type": "item"}
	# Attacker with amulet
	var attacker := _summon_creature(player, match_state, "mara_attacker", "field", 3, 3)
	_target_ready_for_attack(attacker, match_state)
	attacker["attached_items"] = [amulet]
	# Enemy with amulet
	var enemy_with_amulet := _summon_creature(opponent, match_state, "mara_enemy", "field", 2, 2)
	_target_ready_for_attack(enemy_with_amulet, match_state)
	enemy_with_amulet["attached_items"] = [amulet2]
	# Enemy without amulet
	var enemy_no_amulet := _summon_creature(opponent, match_state, "plain_enemy", "field", 2, 2)
	_target_ready_for_attack(enemy_no_amulet, match_state)
	# Attack amulet-wielder should be blocked
	var blocked := MatchCombat.validate_attack(match_state, pid, str(attacker.get("instance_id", "")), {
		"type": "creature", "instance_id": str(enemy_with_amulet.get("instance_id", "")),
	})
	# Attack non-amulet enemy should be allowed
	var allowed := MatchCombat.validate_attack(match_state, pid, str(attacker.get("instance_id", "")), {
		"type": "creature", "instance_id": str(enemy_no_amulet.get("instance_id", "")),
	})
	# Attack face should be allowed
	var face := MatchCombat.validate_attack(match_state, pid, str(attacker.get("instance_id", "")), {
		"type": "player", "player_id": str(opponent.get("player_id", "")),
	})
	return (
		_assert(not bool(blocked.get("is_valid", false)), "Amulet of Mara wielder should NOT be able to attack another amulet wielder.") and
		_assert(bool(allowed.get("is_valid", false)), "Amulet of Mara wielder should be able to attack enemies without amulet.") and
		_assert(bool(face.get("is_valid", false)), "Amulet of Mara wielder should be able to attack face.")
	)


func _test_escalating_damage_sets_counter_on_card() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(active_player["player_id"])
	var opid := str(opponent["player_id"])
	var attacker := _summon_creature(active_player, match_state, "escalator", "field", 3, 5)
	attacker["triggered_abilities"] = [{"family": "on_attack", "required_zone": "lane", "effects": [{"op": "escalating_damage", "target_player": "opponent", "base_amount": 2, "increment": 2, "counter_key": "esc_counter"}]}]
	attacker["effect_ids"] = ["damage"]
	_target_ready_for_attack(attacker, match_state)

	# First attack — should deal 2 escalating damage and set counter to 2
	var result := MatchCombat.resolve_attack(match_state, pid, attacker["instance_id"], {
		"type": "player",
		"player_id": opid,
	})
	if not (
		_assert(result["is_valid"], "First escalating attack should resolve.") and
		_assert(int(attacker.get("esc_counter", 0)) == 2, "Counter should be 2 after first attack, got %d." % int(attacker.get("esc_counter", 0)))
	):
		return false

	# Second attack — counter should increment to 4
	_target_ready_for_attack(attacker, match_state)
	MatchTurnLoop.end_turn(match_state, pid)
	MatchTurnLoop.end_turn(match_state, opid)
	var result2 := MatchCombat.resolve_attack(match_state, pid, attacker["instance_id"], {
		"type": "player",
		"player_id": opid,
	})
	return (
		_assert(result2["is_valid"], "Second escalating attack should resolve.") and
		_assert(int(attacker.get("esc_counter", 0)) == 4, "Counter should be 4 after second attack, got %d." % int(attacker.get("esc_counter", 0)))
	)


func _test_wounded_enemy_damage_immunity() -> bool:
	var match_state := _build_started_match(18, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Sai Sahan analog: immune to wounded enemy creature damage
	var sai := _summon_creature(player, match_state, "sai_sahan", "field", 6, 3)
	sai["grants_immunity"] = ["wounded_enemy_damage"]
	_target_ready_for_attack(sai, match_state)
	# Wounded enemy (debuffed — has health_debuff_marked but no damage_marked)
	var debuffed := _summon_creature(opponent, match_state, "debuffed_enemy", "field", 2, 4)
	EvergreenRules.apply_stat_bonus(debuffed, -1, -1, "curse")
	_target_ready_for_attack(debuffed, match_state)
	# Sai attacks the wounded (debuffed) creature — should take 0 retaliation
	var result := MatchCombat.resolve_attack(match_state, player["player_id"], sai["instance_id"], {
		"type": "creature",
		"instance_id": debuffed["instance_id"],
	})
	if not (
		_assert(result["is_valid"], "Sai attack should resolve.") and
		_assert(int(sai.get("damage_marked", 0)) == 0, "Sai should take 0 damage from wounded enemy. Got %d." % int(sai.get("damage_marked", 0)))
	):
		return false
	# Non-wounded enemy — Sai should take normal retaliation damage
	var match_state2 := _build_started_match(18, 0)
	var player2: Dictionary = match_state2["players"][0]
	var opponent2: Dictionary = match_state2["players"][1]
	var sai2 := _summon_creature(player2, match_state2, "sai_sahan2", "field", 6, 5)
	sai2["grants_immunity"] = ["wounded_enemy_damage"]
	_target_ready_for_attack(sai2, match_state2)
	var healthy := _summon_creature(opponent2, match_state2, "healthy_enemy", "field", 3, 8)
	_target_ready_for_attack(healthy, match_state2)
	var result2 := MatchCombat.resolve_attack(match_state2, player2["player_id"], sai2["instance_id"], {
		"type": "creature",
		"instance_id": healthy["instance_id"],
	})
	return (
		_assert(result2["is_valid"], "Sai attack vs healthy should resolve.") and
		_assert(int(sai2.get("damage_marked", 0)) == 3, "Sai should take 3 damage from non-wounded enemy. Got %d." % int(sai2.get("damage_marked", 0)))
	)


func _test_attack_condition_blocks_attack_without_action_played() -> bool:
	var match_state := _build_started_match(18, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Dormant Centurion analog: can only attack if an action was played this turn
	var centurion := _summon_creature(player, match_state, "centurion", "field", 3, 5)
	centurion["attack_condition"] = {"type": "action_played_this_turn"}
	_target_ready_for_attack(centurion, match_state)
	var target := _summon_creature(opponent, match_state, "target", "field", 2, 2)
	_target_ready_for_attack(target, match_state)
	# No action played yet — centurion should not be able to attack
	var blocked := MatchCombat.validate_attack(match_state, player["player_id"], centurion["instance_id"], {
		"type": "creature",
		"instance_id": target["instance_id"],
	})
	if not _assert(not blocked["is_valid"], "Centurion should not attack when no action was played this turn."):
		return false
	# Simulate an action being played
	player["noncreature_plays_this_turn"] = 1
	var allowed := MatchCombat.validate_attack(match_state, player["player_id"], centurion["instance_id"], {
		"type": "creature",
		"instance_id": target["instance_id"],
	})
	return _assert(allowed["is_valid"], "Centurion should be able to attack after an action was played this turn.")


func _test_shackle_permanent_unless_equipped() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var conscript := _summon_creature(active_player, match_state, "conscript", "field", 5, 4)
	conscript["innate_statuses"] = ["shackle_permanent_unless_equipped"]
	_target_ready_for_attack(conscript, match_state)
	var target := _summon_creature(opponent, match_state, "target", "field", 2, 2)
	_target_ready_for_attack(target, match_state)

	# Without items: should be blocked
	var blocked := MatchCombat.validate_attack(match_state, active_player["player_id"], conscript["instance_id"], {
		"type": "creature",
		"instance_id": target["instance_id"],
	})

	# Equip an item: should be allowed
	conscript["attached_items"] = [{"instance_id": "test_sword", "definition_id": "test_sword", "card_type": "item", "power": 1, "health": 1}]
	var allowed := MatchCombat.validate_attack(match_state, active_player["player_id"], conscript["instance_id"], {
		"type": "creature",
		"instance_id": target["instance_id"],
	})

	# Remove item: should be blocked again
	conscript["attached_items"] = []
	var blocked_again := MatchCombat.validate_attack(match_state, active_player["player_id"], conscript["instance_id"], {
		"type": "creature",
		"instance_id": target["instance_id"],
	})

	return (
		_assert(not blocked["is_valid"], "Craven Conscript without items should be shackled and unable to attack.") and
		_assert(allowed["is_valid"], "Craven Conscript with an equipped item should be able to attack.") and
		_assert(not blocked_again["is_valid"], "Craven Conscript should be shackled again after item is removed.")
	)


func _test_damage_on_own_turn_immunity() -> bool:
	# Armored Troll: "immune to damage on your turn"
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var troll := _summon_creature(active_player, match_state, "troll", "field", 3, 7)
	troll["self_immunity"] = ["damage_on_own_turn"]
	_target_ready_for_attack(troll, match_state)
	var big_defender := _summon_creature(opponent, match_state, "big_def", "field", 10, 10)
	_target_ready_for_attack(big_defender, match_state)
	MatchAuras.recalculate_auras(match_state)

	# Troll attacks on its own turn — should take 0 retaliation damage from defender
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], troll["instance_id"], {
		"type": "creature",
		"instance_id": big_defender["instance_id"],
	})
	if not (
		_assert(result["is_valid"], "Attack should resolve.") and
		_assert(int(troll.get("damage_marked", 0)) == 0, "Troll should take 0 retaliation damage on its controller's turn. Got %d." % int(troll.get("damage_marked", 0))) and
		_assert(int(big_defender.get("damage_marked", 0)) == 3, "Defender should still take troll's damage. Got %d." % int(big_defender.get("damage_marked", 0)))
	):
		return false

	# Now on opponent's turn, troll should be damageable (test via a fresh scenario since attack already happened)
	var match_state2 := _build_started_match(18, 0)
	var player2: Dictionary = match_state2["players"][0]
	var opponent2: Dictionary = match_state2["players"][1]
	var troll2 := _summon_creature(player2, match_state2, "troll2", "field", 3, 7)
	troll2["self_immunity"] = ["damage_on_own_turn"]
	var enemy_attacker := _summon_creature(opponent2, match_state2, "enemy_atk", "field", 4, 4)
	_target_ready_for_attack(troll2, match_state2)
	_target_ready_for_attack(enemy_attacker, match_state2)
	MatchTurnLoop.end_turn(match_state2, player2["player_id"])
	MatchAuras.recalculate_auras(match_state2)
	var result2 := MatchCombat.resolve_attack(match_state2, opponent2["player_id"], enemy_attacker["instance_id"], {
		"type": "creature",
		"instance_id": troll2["instance_id"],
	})
	return (
		_assert(result2["is_valid"], "Opponent attack should resolve.") and
		_assert(int(troll2.get("damage_marked", 0)) == 4, "Troll should take damage on opponent's turn. Got %d." % int(troll2.get("damage_marked", 0)))
	)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true

	push_error(message)
	return false