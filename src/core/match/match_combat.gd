class_name MatchCombat
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const PHASE_ACTION := "action"
const TARGET_TYPE_CREATURE := "creature"
const TARGET_TYPE_PLAYER := "player"
const ZONE_LANE := "lane"
const ZONE_DISCARD := "discard"


static func can_attack(match_state: Dictionary, player_id: String, attacker_instance_id: String, target: Dictionary) -> bool:
	return bool(validate_attack(match_state, player_id, attacker_instance_id, target).get("is_valid", false))


static func validate_attack(match_state: Dictionary, player_id: String, attacker_instance_id: String, target: Dictionary) -> Dictionary:
	var action_validation := _validate_action_owner(match_state, player_id, "Attack")
	if not action_validation["is_valid"]:
		return action_validation

	var attacker_lookup := _find_creature_on_board(match_state.get("lanes", []), attacker_instance_id)
	if not attacker_lookup["is_valid"]:
		return attacker_lookup

	if str(attacker_lookup["player_id"]) != player_id:
		return _invalid_result("Creature %s is not controlled by %s." % [attacker_instance_id, player_id])

	var attacker: Dictionary = attacker_lookup["card"]
	var readiness_validation := _validate_attacker_readiness(match_state, attacker)
	if not readiness_validation["is_valid"]:
		return readiness_validation

	var defending_player_id := _get_opposing_player_id(match_state.get("players", []), player_id)
	if defending_player_id.is_empty():
		return _invalid_result("Could not determine the defending player for attack validation.")

	var enemy_guards := _get_lane_guard_instance_ids(match_state, attacker_lookup["lane_index"], defending_player_id)
	var target_type := str(target.get("type", ""))
	if target_type == TARGET_TYPE_PLAYER:
		return _validate_player_attack_target(attacker_lookup, defending_player_id, enemy_guards, target)
	if target_type == TARGET_TYPE_CREATURE:
		return _validate_creature_attack_target(match_state, attacker_lookup, defending_player_id, enemy_guards, target)

	return _invalid_result("Unknown attack target type: %s" % target_type)


static func resolve_attack(match_state: Dictionary, player_id: String, attacker_instance_id: String, target: Dictionary) -> Dictionary:
	var validation := validate_attack(match_state, player_id, attacker_instance_id, target)
	if not validation["is_valid"]:
		return validation

	var attacker: Dictionary = validation["attacker"]
	attacker["has_attacked_this_turn"] = true
	if EvergreenRules.has_raw_status(attacker, EvergreenRules.STATUS_COVER):
		EvergreenRules.remove_status(attacker, EvergreenRules.STATUS_COVER)
		attacker.erase("cover_expires_on_turn")
		attacker.erase("cover_granted_by")

	var events: Array = []
	events.append({
		"event_type": "attack_declared",
		"attacking_player_id": player_id,
		"defending_player_id": str(validation.get("defending_player_id", "")),
		"attacker_instance_id": str(attacker.get("instance_id", "")),
		"lane_id": str(validation.get("lane_id", "")),
		"target_type": str(validation.get("target_type", "")),
		"target_instance_id": str(validation.get("target_instance_id", "")),
		"target_player_id": str(validation.get("target_player_id", "")),
	})
	var rally_results := EvergreenRules.resolve_rally(match_state, attacker)
	for rally_result in rally_results:
		events.append({
			"event_type": "rally_resolved",
			"source_instance_id": str(attacker.get("instance_id", "")),
			"target_instance_id": str(rally_result.get("target_instance_id", "")),
			"power_bonus": int(rally_result.get("power_bonus", 0)),
			"health_bonus": int(rally_result.get("health_bonus", 0)),
		})

	if str(validation.get("target_type", "")) == TARGET_TYPE_PLAYER:
		var player_result := _resolve_player_attack(match_state, validation, attacker, events)
		var player_timing_result := MatchTiming.publish_events(match_state, events)
		player_result["events"] = player_timing_result.get("processed_events", [])
		player_result["trigger_resolutions"] = player_timing_result.get("trigger_resolutions", [])
		_record_events(match_state, player_result["events"])
		return player_result

	var creature_result := _resolve_creature_attack(match_state, validation, attacker, events)
	var creature_timing_result := MatchTiming.publish_events(match_state, events)
	# Merge phase1 (inline-published defender death) and phase2 (attacker death + remaining) results
	var all_events: Array = []
	var all_triggers: Array = []
	if creature_result.has("_phase1_timing"):
		all_events.append_array(creature_result["_phase1_timing"].get("processed_events", []))
		all_triggers.append_array(creature_result["_phase1_timing"].get("trigger_resolutions", []))
		creature_result.erase("_phase1_timing")
	all_events.append_array(creature_timing_result.get("processed_events", []))
	all_triggers.append_array(creature_timing_result.get("trigger_resolutions", []))
	creature_result["events"] = all_events
	creature_result["trigger_resolutions"] = all_triggers
	_record_events(match_state, creature_result["events"])
	return creature_result


static func _validate_player_attack_target(attacker_lookup: Dictionary, defending_player_id: String, enemy_guards: Array, target: Dictionary) -> Dictionary:
	if str(target.get("player_id", "")) != defending_player_id:
		return _invalid_result("Creatures can only attack the opposing player.")

	if not enemy_guards.is_empty() and not EvergreenRules.has_status(attacker_lookup["card"], "ignore_guard"):
		return _invalid_result("Guard creatures in lane %s must be attacked first." % attacker_lookup["lane_id"])

	return {
		"is_valid": true,
		"errors": [],
		"target_type": TARGET_TYPE_PLAYER,
		"attacker": attacker_lookup["card"],
		"attacker_instance_id": attacker_lookup["card"].get("instance_id", ""),
		"lane_id": attacker_lookup["lane_id"],
		"defending_player_id": defending_player_id,
		"target_player_id": defending_player_id,
		"guard_instance_ids": enemy_guards,
	}


static func _validate_creature_attack_target(match_state: Dictionary, attacker_lookup: Dictionary, defending_player_id: String, enemy_guards: Array, target: Dictionary) -> Dictionary:
	var target_instance_id := str(target.get("instance_id", ""))
	var defender_lookup := _find_creature_on_board(match_state.get("lanes", []), target_instance_id)
	if not defender_lookup["is_valid"]:
		return defender_lookup

	if str(defender_lookup["player_id"]) != defending_player_id:
		return _invalid_result("Creatures can only attack enemy creatures.")

	var attacker_can_attack_any_lane := EvergreenRules.has_status(attacker_lookup["card"], "attack_any_lane")
	if str(defender_lookup["lane_id"]) != str(attacker_lookup["lane_id"]) and not attacker_can_attack_any_lane:
		return _invalid_result("Creatures can only attack enemy creatures in the same lane.")

	var defender: Dictionary = defender_lookup["card"]
	if _is_cover_active(match_state, defender) and not _has_keyword(defender, EvergreenRules.KEYWORD_GUARD):
		return _invalid_result("Covered creatures cannot be attacked by enemy creatures.")

	var attacker_ignores_guard := EvergreenRules.has_status(attacker_lookup["card"], "ignore_guard")
	if not enemy_guards.is_empty() and not _has_keyword(defender, EvergreenRules.KEYWORD_GUARD) and not attacker_ignores_guard:
		return _invalid_result("Guard creatures in lane %s must be attacked first." % attacker_lookup["lane_id"])

	return {
		"is_valid": true,
		"errors": [],
		"target_type": TARGET_TYPE_CREATURE,
		"attacker": attacker_lookup["card"],
		"attacker_instance_id": attacker_lookup["card"].get("instance_id", ""),
		"lane_id": attacker_lookup["lane_id"],
		"defending_player_id": defending_player_id,
		"target_instance_id": target_instance_id,
		"defender": defender,
		"defender_lookup": defender_lookup,
		"guard_instance_ids": enemy_guards,
	}


static func _resolve_player_attack(match_state: Dictionary, validation: Dictionary, attacker: Dictionary, events: Array) -> Dictionary:
	var damage := maxi(0, EvergreenRules.get_power(attacker))
	var applied_damage_result := MatchTiming.apply_player_damage(match_state, str(validation.get("target_player_id", "")), damage, {
		"reason": "combat",
		"source_instance_id": str(attacker.get("instance_id", "")),
		"source_controller_player_id": str(attacker.get("controller_player_id", "")),
	})
	var applied_damage := int(applied_damage_result.get("applied_damage", 0))
	if applied_damage > 0:
		events.append(_build_damage_event(attacker, TARGET_TYPE_PLAYER, {
			"player_id": validation.get("target_player_id", ""),
		}, applied_damage, "combat"))
		events.append_array(applied_damage_result.get("events", []))

	var drained := _resolve_drain(match_state, attacker, applied_damage, events)
	_set_winner_if_needed(match_state, str(validation.get("target_player_id", "")), str(attacker.get("controller_player_id", "")), events)
	var result := {
		"is_valid": true,
		"errors": [],
		"target_type": TARGET_TYPE_PLAYER,
		"events": events,
		"damage_to_player": applied_damage,
		"drain_heal": drained,
		"attacker_instance_id": attacker.get("instance_id", ""),
		"target_player_id": validation.get("target_player_id", ""),
	}
	events.append({
		"event_type": "attack_resolved",
		"attacker_instance_id": attacker.get("instance_id", ""),
		"target_type": TARGET_TYPE_PLAYER,
		"target_player_id": validation.get("target_player_id", ""),
		"damage_to_player": applied_damage,
		"drain_heal": drained,
	})
	return result


static func _resolve_creature_attack(match_state: Dictionary, validation: Dictionary, attacker: Dictionary, events: Array) -> Dictionary:
	var defender: Dictionary = validation["defender"]
	var attacker_remaining_before := EvergreenRules.get_remaining_health(attacker)
	var defender_remaining_before := EvergreenRules.get_remaining_health(defender)
	var damage_to_defender := maxi(0, EvergreenRules.get_power(attacker))
	var damage_to_attacker := maxi(0, EvergreenRules.get_power(defender))
	# Damage redirect: if a creature is protected by another (e.g., Jauffre), redirect damage
	var defender_damage_target: Dictionary = defender
	var defender_redirect_id := str(defender.get("_protected_by", ""))
	if not defender_redirect_id.is_empty():
		var defender_protector := _find_creature_on_board(match_state.get("lanes", []), defender_redirect_id)
		if bool(defender_protector.get("is_valid", false)):
			defender_damage_target = defender_protector["card"]
	var attacker_damage_target: Dictionary = attacker
	var attacker_redirect_id := str(attacker.get("_protected_by", ""))
	if not attacker_redirect_id.is_empty():
		var attacker_protector := _find_creature_on_board(match_state.get("lanes", []), attacker_redirect_id)
		if bool(attacker_protector.get("is_valid", false)):
			attacker_damage_target = attacker_protector["card"]
	var defender_damage := EvergreenRules.apply_damage_to_creature(defender_damage_target, damage_to_defender)
	var attacker_damage := EvergreenRules.apply_damage_to_creature(attacker_damage_target, damage_to_attacker)
	var applied_to_defender := int(defender_damage.get("applied", 0))
	var applied_to_attacker := int(attacker_damage.get("applied", 0))

	if bool(defender_damage.get("ward_removed", false)):
		events.append(_build_ward_event(attacker, defender_damage_target))
	if bool(attacker_damage.get("ward_removed", false)):
		events.append(_build_ward_event(defender, attacker_damage_target))

	if applied_to_defender > 0:
		events.append(_build_damage_event(attacker, TARGET_TYPE_CREATURE, defender_damage_target, applied_to_defender, "combat"))

	if applied_to_attacker > 0:
		var retaliation_event := _build_damage_event(defender, TARGET_TYPE_CREATURE, attacker_damage_target, applied_to_attacker, "combat")
		retaliation_event["is_retaliation"] = true
		events.append(retaliation_event)

	var defender_destroyed := EvergreenRules.is_creature_destroyed(defender_damage_target, applied_to_defender > 0 and EvergreenRules.has_keyword(attacker, EvergreenRules.KEYWORD_LETHAL))
	var attacker_destroyed := EvergreenRules.is_creature_destroyed(attacker_damage_target, applied_to_attacker > 0 and EvergreenRules.has_keyword(defender, EvergreenRules.KEYWORD_LETHAL))
	var breakthrough_damage := 0
	if defender_destroyed and EvergreenRules.has_keyword(attacker, EvergreenRules.KEYWORD_BREAKTHROUGH):
		breakthrough_damage = maxi(0, damage_to_defender - defender_remaining_before)
		if breakthrough_damage > 0:
			var applied_breakthrough_result := MatchTiming.apply_player_damage(match_state, str(validation.get("defending_player_id", "")), breakthrough_damage, {
				"reason": "breakthrough",
				"source_instance_id": str(attacker.get("instance_id", "")),
				"source_controller_player_id": str(attacker.get("controller_player_id", "")),
			})
			var applied_breakthrough := int(applied_breakthrough_result.get("applied_damage", 0))
			breakthrough_damage = applied_breakthrough
			events.append(_build_damage_event(attacker, TARGET_TYPE_PLAYER, {
				"player_id": validation.get("defending_player_id", ""),
			}, applied_breakthrough, "breakthrough"))
			events.append_array(applied_breakthrough_result.get("events", []))
			_set_winner_if_needed(match_state, str(validation.get("defending_player_id", "")), str(attacker.get("controller_player_id", "")), events)

	var total_drain := _resolve_drain(match_state, attacker, applied_to_defender, events)
	# When both creatures die simultaneously, publish the defender's death events inline
	# before discarding the attacker/protector. This ensures slay effects on the defender's
	# killer resolve while the attacker/protector is still in the lane — preventing slay
	# draw effects from pulling the just-died attacker/protector out of the discard pile.
	var phase1_timing: Dictionary = {}
	if defender_destroyed and attacker_destroyed:
		var phase1_events: Array = events.duplicate()
		events.clear()
		var def_destroy_lookup: Dictionary = validation["defender_lookup"] if defender_damage_target == defender else _find_creature_on_board(match_state.get("lanes", []), str(defender_damage_target.get("instance_id", "")))
		if bool(def_destroy_lookup.get("is_valid", false)):
			_destroy_creature(match_state, def_destroy_lookup, str(attacker.get("instance_id", "")), phase1_events)
		phase1_timing = MatchTiming.publish_events(match_state, phase1_events)
		var atk_destroy_lookup: Dictionary = _find_creature_on_board(match_state.get("lanes", []), str(attacker_damage_target.get("instance_id", "")))
		if atk_destroy_lookup["is_valid"]:
			_destroy_creature(match_state, atk_destroy_lookup, str(defender.get("instance_id", "")), events, true)
	else:
		if defender_destroyed:
			var def_destroy_lookup: Dictionary = validation["defender_lookup"] if defender_damage_target == defender else _find_creature_on_board(match_state.get("lanes", []), str(defender_damage_target.get("instance_id", "")))
			if bool(def_destroy_lookup.get("is_valid", false)):
				_destroy_creature(match_state, def_destroy_lookup, str(attacker.get("instance_id", "")), events)
		if attacker_destroyed:
			var atk_destroy_lookup: Dictionary = _find_creature_on_board(match_state.get("lanes", []), str(attacker_damage_target.get("instance_id", "")))
			if atk_destroy_lookup["is_valid"]:
				_destroy_creature(match_state, atk_destroy_lookup, str(defender.get("instance_id", "")), events, true)

	var result := {
		"is_valid": true,
		"errors": [],
		"target_type": TARGET_TYPE_CREATURE,
		"events": events,
		"attacker_instance_id": attacker.get("instance_id", ""),
		"target_instance_id": defender.get("instance_id", ""),
		"attacker_destroyed": attacker_destroyed,
		"defender_destroyed": defender_destroyed,
		"breakthrough_damage": breakthrough_damage,
		"drain_heal": total_drain,
	}
	if not phase1_timing.is_empty():
		result["_phase1_timing"] = phase1_timing
	events.append({
		"event_type": "attack_resolved",
		"attacker_instance_id": attacker.get("instance_id", ""),
		"target_type": TARGET_TYPE_CREATURE,
		"target_instance_id": defender.get("instance_id", ""),
		"attacker_destroyed": attacker_destroyed,
		"defender_destroyed": defender_destroyed,
		"breakthrough_damage": breakthrough_damage,
		"drain_heal": total_drain,
	})
	return result


static func _validate_attacker_readiness(match_state: Dictionary, attacker: Dictionary) -> Dictionary:
	if bool(attacker.get("cannot_attack", false)):
		return _invalid_result("This creature cannot attack.")
	if EvergreenRules.has_status(attacker, EvergreenRules.STATUS_SHACKLED):
		return _invalid_result("Shackled creatures cannot attack.")

	var attack_condition = attacker.get("attack_condition", {})
	if typeof(attack_condition) == TYPE_DICTIONARY and not attack_condition.is_empty():
		if not _check_attack_condition(match_state, attacker, attack_condition):
			return _invalid_result("This creature can't attack right now.")

	if bool(attacker.get("has_attacked_this_turn", false)):
		# Check for grant_extra_attack passives on supports/creatures
		var extra_attacks := int(attacker.get("extra_attacks_remaining", 0))
		if extra_attacks <= 0 and not _has_extra_attack_passive(match_state, attacker):
			return _invalid_result("Creatures can only attack once per turn.")

	# lane_attack_limit passive: only one creature in the lane can attack per turn
	if _lane_attack_limit_reached(match_state, attacker):
		return _invalid_result("Only one creature in this lane can attack each turn.")

	if _entered_lane_this_turn(match_state, attacker) and not EvergreenRules.has_keyword(attacker, EvergreenRules.KEYWORD_CHARGE):
		return _invalid_result("Creatures without Charge cannot attack on the turn they enter a lane.")

	return {
		"is_valid": true,
		"errors": [],
	}


static func _check_attack_condition(match_state: Dictionary, attacker: Dictionary, condition: Dictionary) -> bool:
	var type := str(condition.get("type", ""))
	match type:
		"lane_full":
			var controller_id := str(attacker.get("controller_player_id", ""))
			var lane_id := str(attacker.get("lane_id", ""))
			for lane in match_state.get("lanes", []):
				if str(lane.get("lane_id", "")) == lane_id:
					var slots = lane.get("player_slots", {}).get(controller_id, [])
					var capacity := int(lane.get("slot_capacity", 4))
					return slots.size() >= capacity
		"action_played_this_turn":
			var controller_id := str(attacker.get("controller_player_id", ""))
			var player := _get_player_state(match_state, controller_id)
			return int(player.get("noncreature_plays_this_turn", 0)) > 0
	return true


static func _has_extra_attack_passive(match_state: Dictionary, attacker: Dictionary) -> bool:
	var controller_id := str(attacker.get("controller_player_id", ""))
	# Check supports and lane creatures for grant_extra_attack passive
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(controller_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var passives = card.get("passive_abilities", [])
			if typeof(passives) != TYPE_ARRAY:
				continue
			for p in passives:
				if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "grant_extra_attack":
					continue
				var condition = p.get("condition", {})
				if typeof(condition) == TYPE_DICTIONARY and not condition.is_empty():
					var max_power := int(condition.get("max_power", -1))
					if max_power >= 0 and EvergreenRules.get_power(attacker) > max_power:
						continue
				return true
	for support in _get_player_state(match_state, controller_id).get("support", []):
		if typeof(support) != TYPE_DICTIONARY:
			continue
		var passives = support.get("passive_abilities", [])
		if typeof(passives) != TYPE_ARRAY:
			continue
		for p in passives:
			if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "grant_extra_attack":
				continue
			var condition = p.get("condition", {})
			if typeof(condition) == TYPE_DICTIONARY and not condition.is_empty():
				var max_power := int(condition.get("max_power", -1))
				if max_power >= 0 and EvergreenRules.get_power(attacker) > max_power:
					continue
			return true
	return false


static func _lane_attack_limit_reached(match_state: Dictionary, attacker: Dictionary) -> bool:
	var attacker_id := str(attacker.get("instance_id", ""))
	var lane_id := str(attacker.get("lane_id", ""))
	if lane_id.is_empty():
		return false
	# Check if any creature in this lane has the lane_attack_limit passive
	var has_limit := false
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for pid in lane.get("player_slots", {}).keys():
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "lane_attack_limit"):
					has_limit = true
					break
			if has_limit:
				break
		if has_limit:
			break
	if not has_limit:
		return false
	# Check if another creature in this lane has already attacked
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for pid in lane.get("player_slots", {}).keys():
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == attacker_id:
					continue
				if bool(card.get("has_attacked_this_turn", false)):
					return true
	return false


static func _entered_lane_this_turn(match_state: Dictionary, attacker: Dictionary) -> bool:
	return int(attacker.get("entered_lane_on_turn", -1)) == int(match_state.get("turn_number", 0))


static func _is_cover_active(match_state: Dictionary, defender: Dictionary) -> bool:
	return EvergreenRules.is_cover_active(match_state, defender)


static func _get_lane_guard_instance_ids(match_state: Dictionary, lane_index: int, player_id: String) -> Array:
	var guards: Array = []
	var lanes: Array = match_state.get("lanes", [])
	if lane_index < 0 or lane_index >= lanes.size():
		return guards

	var lane: Dictionary = lanes[lane_index]
	var player_slots_by_id: Dictionary = lane.get("player_slots", {})
	if player_slots_by_id.has(player_id):
		for card in player_slots_by_id[player_id]:
			if card == null:
				continue
			if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
				guards.append(str(card.get("instance_id", "")))

	# Check other lanes for creatures that guard both lanes
	for other_lane_index in range(lanes.size()):
		if other_lane_index == lane_index:
			continue
		var other_slots = lanes[other_lane_index].get("player_slots", {}).get(player_id, [])
		for card in other_slots:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD) and EvergreenRules.has_status(card, "guards_both_lanes"):
				var cid := str(card.get("instance_id", ""))
				if not guards.has(cid):
					guards.append(cid)
	return guards


static func _build_ward_event(source: Dictionary, target: Dictionary) -> Dictionary:
	return {
		"event_type": "ward_removed",
		"source_instance_id": str(source.get("instance_id", "")),
		"target_instance_id": str(target.get("instance_id", "")),
	}


static func _build_damage_event(source: Dictionary, target_type: String, target, amount: int, damage_kind: String) -> Dictionary:
	var event := {
		"event_type": "damage_resolved",
		"damage_kind": damage_kind,
		"source_instance_id": str(source.get("instance_id", "")),
		"source_controller_player_id": str(source.get("controller_player_id", "")),
		"target_type": target_type,
		"amount": amount,
		"source_keywords": _collect_relevant_keywords(source),
	}
	if target_type == TARGET_TYPE_CREATURE:
		event["target_instance_id"] = str(target.get("instance_id", ""))
		event["target_controller_player_id"] = str(target.get("controller_player_id", ""))
		event["target_remaining_health"] = EvergreenRules.get_remaining_health(target)
		event["target_destroyed"] = EvergreenRules.get_remaining_health(target) <= 0
	else:
		event["target_player_id"] = str(target.get("player_id", ""))
		event["target_health"] = int(target.get("health", 0))
	return event


static func _collect_relevant_keywords(card: Dictionary) -> Array:
	var keywords: Array = []
	for keyword_id in [
		EvergreenRules.KEYWORD_BREAKTHROUGH,
		EvergreenRules.KEYWORD_DRAIN,
		EvergreenRules.KEYWORD_GUARD,
		EvergreenRules.KEYWORD_LETHAL,
		EvergreenRules.KEYWORD_CHARGE,
		EvergreenRules.KEYWORD_WARD,
		EvergreenRules.KEYWORD_RALLY,
		EvergreenRules.KEYWORD_REGENERATE,
	]:
		if _has_keyword(card, keyword_id):
			keywords.append(keyword_id)
	return keywords


static func _resolve_drain(match_state: Dictionary, attacker: Dictionary, damage_dealt: int, events: Array) -> int:
	if damage_dealt <= 0:
		return 0
	if not EvergreenRules.has_keyword(attacker, EvergreenRules.KEYWORD_DRAIN):
		return 0

	var controller_player_id := str(attacker.get("controller_player_id", ""))
	if controller_player_id != str(match_state.get("active_player_id", "")):
		if not EvergreenRules._has_passive(attacker, "drain_on_both_turns"):
			return 0

	var player := _get_player_state(match_state, controller_player_id)
	var heal_amount := damage_dealt * MatchTiming._get_heal_multiplier(match_state, controller_player_id)
	player["health"] = int(player.get("health", 0)) + heal_amount
	events.append({
		"event_type": "player_healed",
		"target_player_id": controller_player_id,
		"source_instance_id": str(attacker.get("instance_id", "")),
		"amount": heal_amount,
		"reason": EvergreenRules.KEYWORD_DRAIN,
	})
	return heal_amount


static func _is_creature_destroyed(card: Dictionary, destroyed_by_lethal: bool) -> bool:
	return EvergreenRules.is_creature_destroyed(card, destroyed_by_lethal)


static func _get_remaining_health(card: Dictionary) -> int:
	return EvergreenRules.get_remaining_health(card)


static func _get_power(card: Dictionary) -> int:
	return EvergreenRules.get_power(card)


static func _get_health(card: Dictionary) -> int:
	return EvergreenRules.get_health(card)


static func _destroy_creature(match_state: Dictionary, lookup: Dictionary, destroyed_by_instance_id: String, events: Array, is_retaliation_kill := false) -> void:
	var card := MatchMutations.find_card_location(match_state, str(lookup.get("card", {}).get("instance_id", "")))
	if not bool(card.get("is_valid", false)):
		return
	var destroyed_controller_player_id := str(card["card"].get("controller_player_id", ""))
	var moved := MatchMutations.discard_card(match_state, str(card["card"].get("instance_id", "")))
	if not bool(moved.get("is_valid", false)):
		return
	var destroyed_card: Dictionary = moved["card"]
	var destroy_event := {
		"event_type": "creature_destroyed",
		"instance_id": str(destroyed_card.get("instance_id", "")),
		"source_instance_id": str(destroyed_card.get("instance_id", "")),
		"owner_player_id": str(destroyed_card.get("owner_player_id", lookup.get("player_id", ""))),
		"controller_player_id": destroyed_controller_player_id,
		"destroyed_by_instance_id": destroyed_by_instance_id,
		"lane_id": str(lookup.get("lane_id", "")),
		"source_zone": ZONE_LANE,
	}
	if is_retaliation_kill:
		destroy_event["is_retaliation_kill"] = true
	events.append(destroy_event)


static func _record_events(match_state: Dictionary, events: Array) -> void:
	match_state["last_combat_events"] = events.duplicate(true)


static func _set_winner_if_needed(match_state: Dictionary, damaged_player_id: String, winner_player_id: String, events: Array) -> void:
	MatchTiming.append_match_win_if_needed(match_state, damaged_player_id, winner_player_id, events)


static func _validate_action_owner(match_state: Dictionary, player_id: String, action_name: String) -> Dictionary:
	if match_state.get("phase", "") != PHASE_ACTION:
		return _invalid_result("%s can only be used during the action phase." % action_name)

	if String(match_state.get("active_player_id", "")) != player_id:
		return _invalid_result("%s is only legal for the active player." % action_name)

	if _find_player_index(match_state.get("players", []), player_id) == -1:
		return _invalid_result("Unknown player_id: %s" % player_id)

	return {
		"is_valid": true,
		"errors": [],
	}


static func _get_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	var players: Array = match_state.get("players", [])
	var player_index := _find_player_index(players, player_id)
	if player_index == -1:
		push_error("Unknown player_id: %s" % player_id)
		return {}
	return players[player_index]


static func _get_opposing_player_id(players: Array, player_id: String) -> String:
	for player in players:
		var candidate_id := str(player.get("player_id", ""))
		if candidate_id != player_id:
			return candidate_id
	return ""


static func _find_creature_on_board(lanes: Array, instance_id: String) -> Dictionary:
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if card != null and str(card.get("instance_id", "")) == instance_id:
					return {
						"is_valid": true,
						"errors": [],
						"lane_index": lane_index,
						"lane_id": str(lane.get("lane_id", "")),
						"player_id": str(player_id),
						"slot_index": slot_index,
						"card": card,
					}
	return _invalid_result("Creature %s is not on the board." % instance_id)


static func _find_player_index(players: Array, player_id: String) -> int:
	for index in range(players.size()):
		if str(players[index].get("player_id", "")) == player_id:
			return index
	return -1


static func _has_keyword(card: Dictionary, keyword_id: String) -> bool:
	return EvergreenRules.has_keyword(card, keyword_id)


static func _has_status(card: Dictionary, status_id: String) -> bool:
	return EvergreenRules.has_status(card, status_id)


static func _ensure_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


static func _invalid_result(message: String) -> Dictionary:
	return {
		"is_valid": false,
		"errors": [message],
	}