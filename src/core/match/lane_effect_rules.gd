extends RefCounted

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")


static func inject_lane_triggers(match_state: Dictionary, registry: Array) -> void:
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var lane_id := str(lane.get("lane_id", ""))
		var lane_type := str(lane.get("lane_type", lane_id))
		var payload: Dictionary = lane.get("lane_rule_payload", {})
		var effects: Array = payload.get("effects", [])
		for effect_index in range(effects.size()):
			var effect: Dictionary = effects[effect_index]
			if typeof(effect) != TYPE_DICTIONARY or effect.is_empty():
				continue
			var descriptor: Dictionary = effect.duplicate(true)
			descriptor["_lane_trigger"] = true
			descriptor["_lane_id"] = lane_id
			descriptor["_lane_index"] = lane_index
			descriptor["_lane_type"] = lane_type
			var trigger_id := "lane_%s_effect_%d" % [lane_id, effect_index]
			registry.append({
				"trigger_id": trigger_id,
				"trigger_index": -1,
				"source_instance_id": trigger_id,
				"owner_player_id": "",
				"controller_player_id": "",
				"source_zone": "lane_effect",
				"lane_index": lane_index,
				"slot_index": -1,
				"descriptor": descriptor,
			})


static func apply_lane_effect(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var op := str(effect.get("op", ""))
	match op:
		"lane_grant_cover":
			return _resolve_lane_grant_cover(match_state, trigger, event)
		"lane_dementia_damage":
			return _resolve_lane_dementia_damage(match_state, trigger, event, effect)
		"lane_mania_draw":
			return _resolve_lane_mania_draw(match_state, trigger, event, effect)
		"lane_armor_double_health":
			return _resolve_lane_armor_double_health(match_state, trigger, event, effect)
		"lane_armory_buff_random":
			return _resolve_lane_armory_buff_random(match_state, trigger, event, effect)
		"lane_ballista_damage":
			return _resolve_lane_ballista_damage(match_state, trigger, event, effect)
		"lane_grant_keyword":
			return _resolve_lane_grant_keyword(match_state, trigger, event, effect)
		"lane_stat_bonus":
			return _resolve_lane_stat_bonus(match_state, trigger, event, effect)
		"lane_barracks_draw":
			return _resolve_lane_barracks_draw(match_state, trigger, event, effect)
		"lane_campfire_share_keywords":
			return _resolve_lane_campfire_share_keywords(match_state, trigger, event, effect)
		"lane_champions_arena_extra_attack":
			return _resolve_lane_champions_arena_extra_attack(match_state, trigger, event, effect)
		"lane_eclipse_trigger_last_gasp":
			return _resolve_lane_eclipse_trigger_last_gasp(match_state, trigger, event, effect)
		"lane_flanking_buff_other_lane":
			return _resolve_lane_flanking_buff_other_lane(match_state, trigger, event, effect)
		"lane_fortifications_buff_guard":
			return _resolve_lane_fortifications_buff_guard(match_state, trigger, event, effect)
		"lane_fountain_grant_ward":
			return _resolve_lane_fountain_grant_ward(match_state, trigger, event, effect)
		"lane_graveyard_summon_draugr":
			return _resolve_lane_graveyard_summon_draugr(match_state, trigger, event, effect)
		"lane_hall_of_mirrors_copy":
			return _resolve_lane_hall_of_mirrors_copy(match_state, trigger, event, effect)
		"lane_heist_gain_magicka":
			return _resolve_lane_heist_gain_magicka(match_state, trigger, event, effect)
		"lane_king_of_hill_grant_guard":
			return _resolve_lane_king_of_hill_grant_guard(match_state, trigger, event, effect)
		"lane_library_reduce_action_cost":
			return _resolve_lane_library_reduce_action_cost(match_state, trigger, event, effect)
		"lane_liquid_courage_buff":
			return _resolve_lane_liquid_courage_buff(match_state, trigger, event, effect)
		"lane_lucky_random_keyword":
			return _resolve_lane_lucky_random_keyword(match_state, trigger, event, effect)
		"lane_madness_transform":
			return _resolve_lane_madness_transform(match_state, trigger, event, effect)
		"lane_mage_tower_summon":
			return _resolve_lane_mage_tower_summon(match_state, trigger, event, effect)
		"lane_monastery_buff_random":
			return _resolve_lane_monastery_buff_random(match_state, trigger, event, effect)
		"lane_order_set_stats_to_cost":
			return _resolve_lane_order_set_stats_to_cost(match_state, trigger, event, effect)
		"lane_plunder_attach_item":
			return _resolve_lane_plunder_attach_item(match_state, trigger, event, effect)
		"lane_reanimation_resurrect":
			return _resolve_lane_reanimation_resurrect(match_state, trigger, event, effect)
		"lane_sewer_restrict":
			return _resolve_lane_sewer_restrict(match_state, trigger, event, effect)
		"lane_surplus_reduce_cost":
			return _resolve_lane_surplus_reduce_cost(match_state, trigger, event, effect)
		"lane_temple_heal":
			return _resolve_lane_temple_heal(match_state, trigger, event, effect)
		"lane_torment_damage":
			return _resolve_lane_torment_damage(match_state, trigger, event, effect)
		"lane_warzone_damage":
			return _resolve_lane_warzone_damage(match_state, trigger, event, effect)
		"lane_windy_switch":
			return _resolve_lane_windy_switch(match_state, trigger, event, effect)
		"lane_zoo_transform":
			return _resolve_lane_zoo_transform(match_state, trigger, event, effect)
		_:
			return {"handled": false, "events": []}


static func _resolve_lane_grant_cover(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Dictionary:
	var creature_id := str(event.get("source_instance_id", ""))
	if creature_id.is_empty():
		return {"handled": true, "events": []}

	var location := MatchMutations.find_card_location(match_state, creature_id)
	if not bool(location.get("is_valid", false)):
		return {"handled": true, "events": []}
	var card: Dictionary = location.get("card", {})

	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	# For summon events, lane_id is on the event; for move events, read from the card
	var event_lane_id := str(event.get("lane_id", str(card.get("lane_id", ""))))
	if lane_id != event_lane_id:
		return {"handled": true, "events": []}

	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
		return {"handled": true, "events": []}

	var self_immunities = card.get("self_immunity", [])
	if typeof(self_immunities) == TYPE_ARRAY and self_immunities.has("cover"):
		return {"handled": true, "events": []}

	if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER):
		return {"handled": true, "events": []}

	var cover_offset := 1 if str(card.get("controller_player_id", "")) == str(match_state.get("active_player_id", "")) else 0
	EvergreenRules.grant_cover(card, int(match_state.get("turn_number", 0)) + cover_offset)

	var events: Array = [{
		"event_type": "status_granted",
		"source_instance_id": creature_id,
		"target_instance_id": creature_id,
		"status_id": "cover",
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": event_lane_id,
		"granted_by": "lane_effect",
	}]
	return {"handled": true, "events": events}


static func _resolve_lane_dementia_damage(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var active_player_id := str(event.get("player_id", ""))
	if active_player_id.is_empty():
		return {"handled": true, "events": []}

	var lane: Dictionary = {}
	for l in match_state.get("lanes", []):
		if str(l.get("lane_id", "")) == lane_id:
			lane = l
			break
	if lane.is_empty():
		return {"handled": true, "events": []}

	var highest_per_player := {}
	var player_slots: Dictionary = lane.get("player_slots", {})
	for pid in player_slots:
		var max_power := -1
		for card in player_slots[pid]:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var power := EvergreenRules.get_power(card)
			if power > max_power:
				max_power = power
		if max_power >= 0:
			highest_per_player[str(pid)] = max_power

	if highest_per_player.is_empty():
		return {"handled": true, "events": []}
	var best_power := -1
	var best_owner := ""
	var tied := false
	for pid in highest_per_player:
		var power: int = highest_per_player[pid]
		if power > best_power:
			best_power = power
			best_owner = pid
			tied = false
		elif power == best_power:
			tied = true

	if tied or best_owner != active_player_id:
		return {"handled": true, "events": []}

	var opponent_id := ""
	for player in match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != active_player_id:
			opponent_id = str(player.get("player_id", ""))
			break
	if opponent_id.is_empty():
		return {"handled": true, "events": []}

	var amount := int(effect.get("amount", 3))
	var damage_result: Dictionary = _timing_rules().apply_player_damage(match_state, opponent_id, amount, {
		"reason": "lane_effect_dementia",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": active_player_id,
	})

	var events: Array = [{
		"event_type": "damage_resolved",
		"damage_kind": "lane_effect_dementia",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": active_player_id,
		"target_type": "player",
		"target_player_id": opponent_id,
		"amount": int(damage_result.get("applied_damage", 0)),
		"lane_id": lane_id,
	}]
	events.append_array(damage_result.get("events", []))
	return {"handled": true, "events": events}


static func _resolve_lane_mania_draw(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var active_player_id := str(event.get("player_id", ""))
	if active_player_id.is_empty():
		return {"handled": true, "events": []}

	var lane: Dictionary = {}
	for l in match_state.get("lanes", []):
		if str(l.get("lane_id", "")) == lane_id:
			lane = l
			break
	if lane.is_empty():
		return {"handled": true, "events": []}

	var highest_per_player := {}
	var player_slots: Dictionary = lane.get("player_slots", {})
	for pid in player_slots:
		var max_health := -1
		for card in player_slots[pid]:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var health := EvergreenRules.get_remaining_health(card)
			if health > max_health:
				max_health = health
		if max_health >= 0:
			highest_per_player[str(pid)] = max_health

	if highest_per_player.is_empty():
		return {"handled": true, "events": []}
	var best_health := -1
	var best_owner := ""
	var tied := false
	for pid in highest_per_player:
		var health: int = highest_per_player[pid]
		if health > best_health:
			best_health = health
			best_owner = pid
			tied = false
		elif health == best_health:
			tied = true

	if tied or best_owner != active_player_id:
		return {"handled": true, "events": []}

	var draw_result: Dictionary = _timing_rules().draw_cards(match_state, active_player_id, 1, {
		"reason": "lane_effect_mania",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": active_player_id,
	})

	var events: Array = [{
		"event_type": "card_drawn",
		"draw_reason": "lane_effect_mania",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"player_id": active_player_id,
		"lane_id": lane_id,
	}]
	events.append_array(draw_result.get("events", []))
	return {"handled": true, "events": events}


static func _resolve_lane_armor_double_health(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var creature_id := str(event.get("source_instance_id", ""))
	if creature_id.is_empty():
		return {"handled": true, "events": []}

	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var event_lane_id := str(event.get("lane_id", ""))
	if lane_id != event_lane_id:
		return {"handled": true, "events": []}

	var location := MatchMutations.find_card_location(match_state, creature_id)
	if not bool(location.get("is_valid", false)):
		return {"handled": true, "events": []}
	var card: Dictionary = location.get("card", {})

	var current_health := EvergreenRules.get_health(card)
	if current_health <= 0:
		return {"handled": true, "events": []}

	EvergreenRules.apply_stat_bonus(card, 0, current_health)

	var events: Array = [{
		"event_type": "stat_modified",
		"source_instance_id": creature_id,
		"target_instance_id": creature_id,
		"power_change": 0,
		"health_change": current_health,
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": lane_id,
		"granted_by": "lane_effect_armor",
	}]
	return {"handled": true, "events": events}


static func _resolve_lane_armory_buff_random(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var creature_id := str(event.get("source_instance_id", ""))
	if creature_id.is_empty():
		return {"handled": true, "events": []}

	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var event_lane_id := str(event.get("lane_id", ""))
	if lane_id != event_lane_id:
		return {"handled": true, "events": []}

	var location := MatchMutations.find_card_location(match_state, creature_id)
	if not bool(location.get("is_valid", false)):
		return {"handled": true, "events": []}
	var summoned_card: Dictionary = location.get("card", {})
	var player_id := str(summoned_card.get("controller_player_id", ""))

	var lane: Dictionary = {}
	for l in match_state.get("lanes", []):
		if str(l.get("lane_id", "")) == lane_id:
			lane = l
			break
	if lane.is_empty():
		return {"handled": true, "events": []}

	var friendly_creatures: Array = []
	var slot_array: Array = lane.get("player_slots", {}).get(player_id, [])
	for card in slot_array:
		if typeof(card) == TYPE_DICTIONARY:
			friendly_creatures.append(card)

	if friendly_creatures.is_empty():
		return {"handled": true, "events": []}

	var target_card: Dictionary
	if int(friendly_creatures.size()) == 1:
		target_card = friendly_creatures[0]
	else:
		var selected_idx := EvergreenRules._choose_deterministic_candidate_index(match_state, creature_id, friendly_creatures)
		target_card = friendly_creatures[selected_idx]

	EvergreenRules.apply_stat_bonus(target_card, 1, 1)

	var target_id := str(target_card.get("instance_id", ""))
	var events: Array = [{
		"event_type": "stat_modified",
		"source_instance_id": creature_id,
		"target_instance_id": target_id,
		"power_change": 1,
		"health_change": 1,
		"player_id": player_id,
		"lane_id": lane_id,
		"granted_by": "lane_effect_armory",
	}]
	return {"handled": true, "events": events}


# --- Helper: get creature entering lane (works for both summon and move events) ---
static func _get_creature_entering_lane(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Dictionary:
	var creature_id := str(event.get("source_instance_id", ""))
	if creature_id.is_empty():
		return {}
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var location := MatchMutations.find_card_location(match_state, creature_id)
	if not bool(location.get("is_valid", false)):
		return {}
	var card: Dictionary = location.get("card", {})
	# For summon events, check event.lane_id; for move events, check card.lane_id
	var event_lane_id := str(event.get("lane_id", str(card.get("lane_id", ""))))
	if lane_id != event_lane_id:
		return {}
	return card


# --- Helper: get summoned creature verified in this lane ---
static func _get_summoned_creature_in_lane(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Dictionary:
	var creature_id := str(event.get("source_instance_id", ""))
	if creature_id.is_empty():
		return {}
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var event_lane_id := str(event.get("lane_id", ""))
	if lane_id != event_lane_id:
		return {}
	var location := MatchMutations.find_card_location(match_state, creature_id)
	if not bool(location.get("is_valid", false)):
		return {}
	return location.get("card", {})


# --- Helper: get lane dict by id ---
static func _get_lane(match_state: Dictionary, lane_id: String) -> Dictionary:
	for l in match_state.get("lanes", []):
		if str(l.get("lane_id", "")) == lane_id:
			return l
	return {}


# --- Helper: get opponent player id ---
static func _get_opponent_id(match_state: Dictionary, player_id: String) -> String:
	for player in match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != player_id:
			return str(player.get("player_id", ""))
	return ""


# --- Generic: grant keyword on summon ---
static func _resolve_lane_grant_keyword(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var keyword := str(effect.get("keyword", ""))
	if keyword.is_empty():
		return {"handled": true, "events": []}
	if EvergreenRules.has_keyword(card, keyword):
		return {"handled": true, "events": []}
	EvergreenRules.ensure_card_state(card)
	var granted: Array = card.get("granted_keywords", [])
	if not granted.has(keyword):
		granted.append(keyword)
		card["granted_keywords"] = granted
	return {"handled": true, "events": [{
		"event_type": "keyword_granted",
		"source_instance_id": str(event.get("source_instance_id", "")),
		"target_instance_id": str(event.get("source_instance_id", "")),
		"keyword_id": keyword,
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"granted_by": "lane_effect",
	}]}


# --- Generic: stat bonus on summon/move ---
static func _resolve_lane_stat_bonus(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var card := _get_creature_entering_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var power_bonus := int(effect.get("power", 0))
	var health_bonus := int(effect.get("health", 0))
	EvergreenRules.apply_stat_bonus(card, power_bonus, health_bonus)
	return {"handled": true, "events": [{
		"event_type": "stat_modified",
		"source_instance_id": str(event.get("source_instance_id", "")),
		"target_instance_id": str(event.get("source_instance_id", "")),
		"power_change": power_bonus,
		"health_change": health_bonus,
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"granted_by": "lane_effect",
	}]}


# --- Barracks: draw if summoned creature has power >= min_power ---
static func _resolve_lane_barracks_draw(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var min_power := int(effect.get("min_power", 4))
	if EvergreenRules.get_power(card) < min_power:
		return {"handled": true, "events": []}
	var player_id := str(card.get("controller_player_id", ""))
	var draw_result: Dictionary = _timing_rules().draw_cards(match_state, player_id, 1, {
		"reason": "lane_effect_barracks",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": player_id,
	})
	var events: Array = [{"event_type": "card_drawn", "draw_reason": "lane_effect_barracks", "player_id": player_id, "lane_id": str(trigger.get("descriptor", {}).get("_lane_id", ""))}]
	events.append_array(draw_result.get("events", []))
	return {"handled": true, "events": events}


# --- Campfire: share keywords from summoned creature to all other friendlies in lane ---
static func _resolve_lane_campfire_share_keywords(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var keywords: Array = card.get("keywords", [])
	var granted_kw: Array = card.get("granted_keywords", [])
	var all_keywords: Array = []
	for kw in keywords:
		if not all_keywords.has(kw):
			all_keywords.append(kw)
	for kw in granted_kw:
		if not all_keywords.has(kw):
			all_keywords.append(kw)
	if all_keywords.is_empty():
		return {"handled": true, "events": []}
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var lane := _get_lane(match_state, lane_id)
	var player_id := str(card.get("controller_player_id", ""))
	var creature_id := str(card.get("instance_id", ""))
	var events: Array = []
	var slot_array: Array = lane.get("player_slots", {}).get(player_id, [])
	for other_card in slot_array:
		if typeof(other_card) != TYPE_DICTIONARY:
			continue
		if str(other_card.get("instance_id", "")) == creature_id:
			continue
		EvergreenRules.ensure_card_state(other_card)
		var other_granted: Array = other_card.get("granted_keywords", [])
		for kw in all_keywords:
			if not EvergreenRules.has_keyword(other_card, kw):
				other_granted.append(kw)
				events.append({"event_type": "keyword_granted", "source_instance_id": creature_id, "target_instance_id": str(other_card.get("instance_id", "")), "keyword_id": kw, "player_id": player_id, "lane_id": lane_id, "granted_by": "lane_effect_campfire"})
		other_card["granted_keywords"] = other_granted
	return {"handled": true, "events": events}


# --- Champion's Arena: first creature attacking each turn gets extra attack ---
static func _resolve_lane_champions_arena_extra_attack(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var attacker_id := str(event.get("source_instance_id", event.get("attacker_instance_id", "")))
	print("[CHAMPIONS_ARENA] called — lane_id=%s attacker_id=%s event=%s" % [lane_id, attacker_id, event])
	if attacker_id.is_empty():
		print("[CHAMPIONS_ARENA] bail: attacker_id empty")
		return {"handled": true, "events": []}
	var location := MatchMutations.find_card_location(match_state, attacker_id)
	if not bool(location.get("is_valid", false)):
		print("[CHAMPIONS_ARENA] bail: card not found for %s" % attacker_id)
		return {"handled": true, "events": []}
	var card: Dictionary = location.get("card", {})
	var card_lane_id := str(location.get("lane_id", ""))
	if card_lane_id != lane_id:
		print("[CHAMPIONS_ARENA] bail: card lane_id=%s != trigger lane_id=%s" % [card_lane_id, lane_id])
		return {"handled": true, "events": []}
	var turn_key := "champions_arena_attacked_turn_%s" % lane_id
	var player_id := str(card.get("controller_player_id", ""))
	var current_turn := int(match_state.get("turn_number", 0))
	var player_turn_key := "%s_%s" % [turn_key, player_id]
	var last_attack_turn := int(match_state.get(player_turn_key, -1))
	if last_attack_turn == current_turn:
		print("[CHAMPIONS_ARENA] bail: already used this turn (turn=%d)" % current_turn)
		return {"handled": true, "events": []}
	match_state[player_turn_key] = current_turn
	card["extra_attacks_remaining"] = int(card.get("extra_attacks_remaining", 0)) + 1
	print("[CHAMPIONS_ARENA] granted extra attack to %s — extra_attacks_remaining=%d" % [attacker_id, card["extra_attacks_remaining"]])
	return {"handled": true, "events": [{
		"event_type": "extra_attack_granted",
		"source_instance_id": attacker_id,
		"player_id": player_id,
		"lane_id": lane_id,
		"granted_by": "lane_effect_champions_arena",
	}]}


# --- Eclipse: trigger last gasp on summon (simplified: emit synthetic last_gasp event) ---
static func _resolve_lane_eclipse_trigger_last_gasp(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	# Emit a synthetic last_gasp_triggered event so the timing engine picks up
	# the creature's last gasp abilities without actually destroying it
	return {"handled": true, "events": [{
		"event_type": "creature_destroyed",
		"instance_id": str(card.get("instance_id", "")),
		"controller_player_id": str(card.get("controller_player_id", "")),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"synthetic_last_gasp": true,
		"destroyed_by_instance_id": "",
	}]}


# --- Flanking: +1/+0 to friendly creatures in the OTHER lane on summon ---
static func _resolve_lane_flanking_buff_other_lane(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var player_id := str(card.get("controller_player_id", ""))
	var events: Array = []
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == lane_id:
			continue
		var slot_array: Array = lane.get("player_slots", {}).get(player_id, [])
		for other_card in slot_array:
			if typeof(other_card) != TYPE_DICTIONARY:
				continue
			EvergreenRules.apply_stat_bonus(other_card, 1, 0)
			events.append({"event_type": "stat_modified", "source_instance_id": str(card.get("instance_id", "")), "target_instance_id": str(other_card.get("instance_id", "")), "power_change": 1, "health_change": 0, "player_id": player_id, "lane_id": str(lane.get("lane_id", "")), "granted_by": "lane_effect_flanking"})
	return {"handled": true, "events": events}


# --- Fortifications: +1/+1 if summoned creature has Guard ---
static func _resolve_lane_fortifications_buff_guard(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	if not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
		return {"handled": true, "events": []}
	EvergreenRules.apply_stat_bonus(card, 1, 1)
	return {"handled": true, "events": [{
		"event_type": "stat_modified",
		"source_instance_id": str(event.get("source_instance_id", "")),
		"target_instance_id": str(event.get("source_instance_id", "")),
		"power_change": 1, "health_change": 1,
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"granted_by": "lane_effect_fortifications",
	}]}


# --- Fountain: grant Ward if power <= max_power ---
static func _resolve_lane_fountain_grant_ward(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var max_power := int(effect.get("max_power", 2))
	if EvergreenRules.get_power(card) > max_power:
		return {"handled": true, "events": []}
	if EvergreenRules.has_keyword(card, "ward"):
		return {"handled": true, "events": []}
	EvergreenRules.ensure_card_state(card)
	var granted: Array = card.get("granted_keywords", [])
	if not granted.has("ward"):
		granted.append("ward")
		card["granted_keywords"] = granted
	card["has_ward"] = true
	return {"handled": true, "events": [{
		"event_type": "keyword_granted",
		"source_instance_id": str(event.get("source_instance_id", "")),
		"target_instance_id": str(event.get("source_instance_id", "")),
		"keyword_id": "ward",
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"granted_by": "lane_effect_fountain",
	}]}


# --- Graveyard: summon 1/1 Rotting Draugr when a non-Draugr creature dies in this lane ---
static func _resolve_lane_graveyard_summon_draugr(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var destroyed_id := str(event.get("instance_id", ""))
	if destroyed_id.is_empty():
		return {"handled": true, "events": []}
	# Only trigger for creatures that died in this lane (use event's lane_id since
	# _clear_lane_state erases it from the card before it reaches discard)
	var event_lane_id := str(event.get("lane_id", ""))
	if event_lane_id != lane_id:
		return {"handled": true, "events": []}
	# Check if the destroyed creature's name was "Rotting Draugr" — look for it in discard
	var controller_id := str(event.get("controller_player_id", ""))
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) != controller_id:
			continue
		for card in player.get("discard", []):
			if str(card.get("instance_id", "")) == destroyed_id:
				if str(card.get("name", "")) == "Rotting Draugr":
					return {"handled": true, "events": []}
	# Check lane has room
	var lane := _get_lane(match_state, lane_id)
	if lane.is_empty():
		return {"handled": true, "events": []}
	var player_slots: Array = lane.get("player_slots", {}).get(controller_id, [])
	if int(player_slots.size()) >= int(lane.get("slot_capacity", 4)):
		return {"handled": true, "events": []}
	# Summon token
	var token_id := "draugr_%s_%d" % [lane_id, int(match_state.get("next_instance_id", 1000))]
	match_state["next_instance_id"] = int(match_state.get("next_instance_id", 1000)) + 1
	var token := {
		"instance_id": token_id, "definition_id": "rotting_draugr_token", "name": "Rotting Draugr",
		"card_type": "creature", "subtypes": ["Skeleton"], "attributes": ["endurance"],
		"cost": 0, "power": 1, "health": 1, "base_power": 1, "base_health": 1,
		"owner_player_id": controller_id, "controller_player_id": controller_id,
		"zone": "lane", "lane_id": lane_id, "slot_index": int(player_slots.size()),
		"keywords": [], "granted_keywords": [], "status_markers": [],
		"is_token": true, "attacks_remaining": 0,
		"entered_lane_on_turn": int(match_state.get("turn_number", 0)),
		"art_path": "res://assets/images/cards/end_rotting_draugr.png",
	}
	player_slots.append(token)
	return {"handled": true, "events": [{
		"event_type": "creature_summoned",
		"source_instance_id": token_id,
		"player_id": controller_id,
		"lane_id": lane_id,
		"granted_by": "lane_effect_graveyard",
	}]}


# --- Hall of Mirrors: copy summoned creature if it's the only friendly creature in lane ---
static func _resolve_lane_hall_of_mirrors_copy(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var lane := _get_lane(match_state, lane_id)
	var player_id := str(card.get("controller_player_id", ""))
	var player_slots: Array = lane.get("player_slots", {}).get(player_id, [])
	# "If there are no friendly creatures here when you summon one" — the summoned creature is already in the slot,
	# so there should be exactly 1 creature (the one just summoned)
	if int(player_slots.size()) != 1:
		return {"handled": true, "events": []}
	if int(player_slots.size()) >= int(lane.get("slot_capacity", 4)):
		return {"handled": true, "events": []}
	var copy_id := "%s_mirror_%d" % [str(card.get("instance_id", "")), int(match_state.get("next_instance_id", 1000))]
	match_state["next_instance_id"] = int(match_state.get("next_instance_id", 1000)) + 1
	var copy := card.duplicate(true)
	copy["instance_id"] = copy_id
	copy["slot_index"] = int(player_slots.size())
	copy["is_token"] = true
	copy["attacks_remaining"] = 0
	player_slots.append(copy)
	return {"handled": true, "events": [{
		"event_type": "creature_summoned",
		"source_instance_id": copy_id,
		"player_id": player_id,
		"lane_id": lane_id,
		"granted_by": "lane_effect_hall_of_mirrors",
	}]}


# --- Heist: gain 1 magicka when a creature in this lane pilfers ---
static func _resolve_lane_heist_gain_magicka(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var attacker_id := str(event.get("source_instance_id", ""))
	if attacker_id.is_empty():
		return {"handled": true, "events": []}
	var location := MatchMutations.find_card_location(match_state, attacker_id)
	if not bool(location.get("is_valid", false)):
		return {"handled": true, "events": []}
	var card: Dictionary = location.get("card", {})
	if str(card.get("lane_id", "")) != lane_id:
		return {"handled": true, "events": []}
	var player_id := str(card.get("controller_player_id", ""))
	var amount := int(effect.get("amount", 1))
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			player["temporary_magicka"] = int(player.get("temporary_magicka", 0)) + amount
			break
	return {"handled": true, "events": [{
		"event_type": "magicka_gained",
		"player_id": player_id,
		"amount": amount,
		"lane_id": lane_id,
		"granted_by": "lane_effect_heist",
	}]}


# --- King of the Hill: grant Guard if cost >= min_cost ---
static func _resolve_lane_king_of_hill_grant_guard(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var min_cost := int(effect.get("min_cost", 5))
	if int(card.get("cost", 0)) < min_cost:
		return {"handled": true, "events": []}
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
		return {"handled": true, "events": []}
	EvergreenRules.ensure_card_state(card)
	var granted: Array = card.get("granted_keywords", [])
	if not granted.has("guard"):
		granted.append("guard")
		card["granted_keywords"] = granted
	return {"handled": true, "events": [{
		"event_type": "keyword_granted",
		"source_instance_id": str(event.get("source_instance_id", "")),
		"target_instance_id": str(event.get("source_instance_id", "")),
		"keyword_id": "guard",
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"granted_by": "lane_effect_king_of_the_hill",
	}]}


# --- Library: reduce action cost (handled via on_cost_check — no-op as trigger, integrated elsewhere) ---
static func _resolve_lane_library_reduce_action_cost(_match_state: Dictionary, _trigger: Dictionary, _event: Dictionary, _effect: Dictionary) -> Dictionary:
	# Library is a continuous effect integrated into get_effective_play_cost
	return {"handled": true, "events": []}


# --- Liquid Courage: +2/+0 when a creature in this lane takes damage ---
static func _resolve_lane_liquid_courage_buff(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	# on_damage fires for both source and target; we want the damaged creature
	var target_id := str(event.get("target_instance_id", ""))
	if target_id.is_empty() or str(event.get("target_type", "")) == "player":
		return {"handled": true, "events": []}
	var location := MatchMutations.find_card_location(match_state, target_id)
	if not bool(location.get("is_valid", false)):
		return {"handled": true, "events": []}
	var card: Dictionary = location.get("card", {})
	if str(card.get("lane_id", "")) != lane_id:
		return {"handled": true, "events": []}
	var power_bonus := int(effect.get("power", 2))
	EvergreenRules.apply_stat_bonus(card, power_bonus, 0)
	return {"handled": true, "events": [{
		"event_type": "stat_modified",
		"source_instance_id": target_id, "target_instance_id": target_id,
		"power_change": power_bonus, "health_change": 0,
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": lane_id, "granted_by": "lane_effect_liquid_courage",
	}]}


# --- Lucky: grant a random keyword on summon ---
static func _resolve_lane_lucky_random_keyword(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var possible_keywords := ["guard", "ward", "charge", "drain", "lethal", "breakthrough", "regenerate"]
	var creature_id := str(card.get("instance_id", ""))
	var candidates: Array = []
	for kw in possible_keywords:
		if not EvergreenRules.has_keyword(card, kw):
			candidates.append(kw)
	if candidates.is_empty():
		return {"handled": true, "events": []}
	var idx: int = _timing_rules()._deterministic_index(match_state, creature_id + "_lucky", int(candidates.size()))
	var keyword: String = candidates[idx]
	EvergreenRules.ensure_card_state(card)
	var granted: Array = card.get("granted_keywords", [])
	if not granted.has(keyword):
		granted.append(keyword)
		card["granted_keywords"] = granted
	return {"handled": true, "events": [{
		"event_type": "keyword_granted",
		"source_instance_id": creature_id, "target_instance_id": creature_id,
		"keyword_id": keyword,
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"granted_by": "lane_effect_lucky",
	}]}


# --- Madness: transform pilfering creature into random creature with +1 cost ---
static func _resolve_lane_madness_transform(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var attacker_id := str(event.get("source_instance_id", ""))
	if attacker_id.is_empty():
		return {"handled": true, "events": []}
	var location := MatchMutations.find_card_location(match_state, attacker_id)
	if not bool(location.get("is_valid", false)):
		return {"handled": true, "events": []}
	var card: Dictionary = location.get("card", {})
	if str(card.get("lane_id", "")) != lane_id:
		return {"handled": true, "events": []}
	var target_cost := int(card.get("cost", 0)) + 1
	var seeds: Array = _card_catalog()._card_seeds()
	var candidates: Array = []
	for seed in seeds:
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		if not bool(seed.get("collectible", true)):
			continue
		if str(seed.get("card_type", "")) != "creature":
			continue
		if int(seed.get("cost", 0)) != target_cost:
			continue
		candidates.append(seed)
	if candidates.is_empty():
		return {"handled": true, "events": []}
	var pick: Dictionary = candidates[_timing_rules()._deterministic_index(match_state, attacker_id + "_madness", candidates.size())]
	var template: Dictionary = pick.duplicate(true)
	template["definition_id"] = str(template.get("card_id", ""))
	var result := MatchMutations.transform_card(match_state, attacker_id, template, {"reason": "lane_effect_madness"})
	# Transformed creature is treated as new — reset attack state so Charge works
	if bool(result.get("is_valid", false)):
		var transformed_card: Dictionary = result.get("card", {})
		transformed_card["has_attacked_this_turn"] = false
		transformed_card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0))
	return {"handled": true, "events": result.get("events", [])}


# --- Mage Tower: summon random creature with same cost as action played ---
static func _resolve_lane_mage_tower_summon(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var played_cost := int(event.get("played_cost", event.get("cost", 0)))
	var player_id := str(event.get("player_id", event.get("playing_player_id", "")))
	if player_id.is_empty():
		return {"handled": true, "events": []}
	# Build a trigger-like dict with controller info for the catalog lookup
	var synth_trigger := trigger.duplicate(true)
	synth_trigger["controller_player_id"] = player_id
	var custom_result: Dictionary = _extended_packs().apply_custom_effect(match_state, synth_trigger, event, {
		"op": "summon_random_from_catalog",
		"filter": {"card_type": "creature", "exact_cost": played_cost},
		"lane_id": lane_id,
	})
	if bool(custom_result.get("handled", false)):
		return {"handled": true, "events": custom_result.get("events", [])}
	return {"handled": true, "events": []}


# --- Monastery: buff random creature +1/+1 when player gains health ---
static func _resolve_lane_monastery_buff_random(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var healed_player_id := str(event.get("target_player_id", event.get("player_id", "")))
	if healed_player_id.is_empty():
		return {"handled": true, "events": []}
	var lane := _get_lane(match_state, lane_id)
	if lane.is_empty():
		return {"handled": true, "events": []}
	var friendly_creatures: Array = []
	var slot_array: Array = lane.get("player_slots", {}).get(healed_player_id, [])
	for card in slot_array:
		if typeof(card) == TYPE_DICTIONARY:
			friendly_creatures.append(card)
	if friendly_creatures.is_empty():
		return {"handled": true, "events": []}
	var target_card: Dictionary
	if int(friendly_creatures.size()) == 1:
		target_card = friendly_creatures[0]
	else:
		var selected_idx := EvergreenRules._choose_deterministic_candidate_index(match_state, healed_player_id + "_monastery", friendly_creatures)
		target_card = friendly_creatures[selected_idx]
	EvergreenRules.apply_stat_bonus(target_card, 1, 1)
	return {"handled": true, "events": [{
		"event_type": "stat_modified",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"target_instance_id": str(target_card.get("instance_id", "")),
		"power_change": 1, "health_change": 1,
		"player_id": healed_player_id,
		"lane_id": lane_id, "granted_by": "lane_effect_monastery",
	}]}


# --- Order: set stats equal to cost on summon or move ---
static func _resolve_lane_order_set_stats_to_cost(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_creature_entering_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var cost := int(card.get("cost", 0))
	var current_power := EvergreenRules.get_power(card)
	var current_health := EvergreenRules.get_health(card)
	var power_diff := cost - current_power
	var health_diff := cost - current_health
	EvergreenRules.apply_stat_bonus(card, power_diff, health_diff)
	return {"handled": true, "events": [{
		"event_type": "stat_modified",
		"source_instance_id": str(card.get("instance_id", "")),
		"target_instance_id": str(card.get("instance_id", "")),
		"power_change": power_diff, "health_change": health_diff,
		"player_id": str(card.get("controller_player_id", "")),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"granted_by": "lane_effect_order",
	}]}


# --- Plunder: attach a random item on summon ---
static func _resolve_lane_plunder_attach_item(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var player_id := str(card.get("controller_player_id", ""))
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var items: Array = []
	for seed in CardCatalog._card_seeds():
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		if not bool(seed.get("collectible", true)):
			continue
		if str(seed.get("card_type", "")) != "item":
			continue
		items.append(seed)
	if items.is_empty():
		return {"handled": true, "events": []}
	var pick: Dictionary = items[_timing_rules()._deterministic_index(match_state, str(card.get("instance_id", "")) + "_plunder", items.size())]
	var template: Dictionary = pick.duplicate(true)
	template["definition_id"] = str(template.get("card_id", ""))
	var generated := MatchMutations.build_generated_card(match_state, player_id, template)
	var attach_result := MatchMutations.attach_item_to_creature(match_state, player_id, generated, str(card.get("instance_id", "")), {"source_zone": MatchMutations.ZONE_GENERATED})
	if not bool(attach_result.get("is_valid", false)):
		return {"handled": true, "events": []}
	var events: Array = attach_result.get("events", [])
	events.append({"event_type": "lane_effect_applied", "lane_effect": "plunder", "lane_id": lane_id, "player_id": player_id, "target_instance_id": str(card.get("instance_id", "")), "item_instance_id": str(generated.get("instance_id", ""))})
	return {"handled": true, "events": events}


# --- Reanimation: resurrect non-Reanimated creature as 1/1 on first death ---
static func _resolve_lane_reanimation_resurrect(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var destroyed_id := str(event.get("instance_id", ""))
	if destroyed_id.is_empty():
		return {"handled": true, "events": []}
	var controller_id := str(event.get("controller_player_id", ""))
	# Only trigger for creatures that died in this lane (use event's lane_id since
	# _clear_lane_state erases it from the card before it reaches discard)
	var event_lane_id := str(event.get("lane_id", ""))
	if event_lane_id != lane_id:
		return {"handled": true, "events": []}
	# Find the destroyed card in discard
	var destroyed_card: Dictionary = {}
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) != controller_id:
			continue
		for card in player.get("discard", []):
			if str(card.get("instance_id", "")) == destroyed_id:
				destroyed_card = card
				break
	if destroyed_card.is_empty():
		return {"handled": true, "events": []}
	if bool(destroyed_card.get("_reanimated", false)):
		return {"handled": true, "events": []}
	# Check lane has room
	var lane := _get_lane(match_state, lane_id)
	if lane.is_empty():
		return {"handled": true, "events": []}
	var player_slots: Array = lane.get("player_slots", {}).get(controller_id, [])
	if int(player_slots.size()) >= int(lane.get("slot_capacity", 4)):
		return {"handled": true, "events": []}
	# Remove from discard and return as 1/1
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == controller_id:
			var discard: Array = player.get("discard", [])
			for i in range(discard.size()):
				if str(discard[i].get("instance_id", "")) == destroyed_id:
					discard.remove_at(i)
					break
			break
	destroyed_card["zone"] = "lane"
	destroyed_card["lane_id"] = lane_id
	destroyed_card["slot_index"] = int(player_slots.size())
	destroyed_card["power"] = 1
	destroyed_card["health"] = 1
	destroyed_card["base_power"] = 1
	destroyed_card["base_health"] = 1
	destroyed_card["damage_taken"] = 0
	destroyed_card["_reanimated"] = true
	destroyed_card["has_attacked_this_turn"] = false
	destroyed_card["status_markers"] = []
	destroyed_card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0))
	destroyed_card["granted_keywords"] = []
	destroyed_card["stat_bonuses"] = []
	destroyed_card["attached_items"] = []
	player_slots.append(destroyed_card)
	return {"handled": true, "events": [{
		"event_type": "creature_summoned",
		"source_instance_id": destroyed_id,
		"player_id": controller_id,
		"lane_id": lane_id,
		"granted_by": "lane_effect_reanimation",
	}]}


# --- Sewer: restrict summon (handled via validation — this trigger is a no-op) ---
static func _resolve_lane_sewer_restrict(_match_state: Dictionary, _trigger: Dictionary, _event: Dictionary, _effect: Dictionary) -> Dictionary:
	# Sewer restriction is checked in validate_lane_entry, not as a trigger
	return {"handled": true, "events": []}


# --- Surplus: reduce cost of random hand card by 1 on summon ---
static func _resolve_lane_surplus_reduce_cost(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var player_id := str(card.get("controller_player_id", ""))
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) != player_id:
			continue
		var hand: Array = player.get("hand", [])
		if hand.is_empty():
			return {"handled": true, "events": []}
		var creature_id := str(card.get("instance_id", ""))
		var candidates: Array = []
		for hand_card in hand:
			if typeof(hand_card) == TYPE_DICTIONARY and int(hand_card.get("cost", 0)) > 0:
				candidates.append(hand_card)
		if candidates.is_empty():
			return {"handled": true, "events": []}
		var idx := EvergreenRules._choose_deterministic_candidate_index(match_state, creature_id + "_surplus", candidates)
		var target_card: Dictionary = candidates[idx]
		target_card["cost"] = int(target_card.get("cost", 0)) - 1
		return {"handled": true, "events": [{
			"event_type": "cost_reduced",
			"source_instance_id": creature_id,
			"target_instance_id": str(target_card.get("instance_id", "")),
			"amount": 1,
			"player_id": player_id,
			"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
			"granted_by": "lane_effect_surplus",
		}]}
	return {"handled": true, "events": []}


# --- Temple: gain health on summon ---
static func _resolve_lane_temple_heal(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var player_id := str(card.get("controller_player_id", ""))
	var amount := int(effect.get("amount", 1))
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			player["health"] = int(player.get("health", 0)) + amount
			break
	return {"handled": true, "events": [{
		"event_type": "player_healed",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"target_player_id": player_id,
		"amount": amount,
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
		"granted_by": "lane_effect_temple",
	}]}


# --- Torment: deal damage to summoned creature ---
static func _resolve_lane_torment_damage(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var amount := int(effect.get("amount", 1))
	var damage_result := EvergreenRules.apply_damage_to_creature(card, amount)
	var creature_id := str(card.get("instance_id", ""))
	var events: Array = [{
		"event_type": "damage_resolved",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"target_instance_id": creature_id,
		"target_type": "creature",
		"amount": amount,
		"damage_kind": "lane_effect_torment",
		"ward_removed": bool(damage_result.get("ward_removed", false)),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
	}]
	if EvergreenRules.get_remaining_health(card) <= 0:
		var destroy := MatchMutations.discard_card(match_state, creature_id, {"reason": "lane_effect_torment"})
		events.append({"event_type": "creature_destroyed", "instance_id": creature_id, "controller_player_id": str(card.get("controller_player_id", ""))})
		events.append_array(destroy.get("events", []))
	return {"handled": true, "events": events}


# --- Warzone: deal damage to opponent on summon ---
static func _resolve_lane_warzone_damage(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var player_id := str(card.get("controller_player_id", ""))
	var opponent_id := _get_opponent_id(match_state, player_id)
	if opponent_id.is_empty():
		return {"handled": true, "events": []}
	var amount := int(effect.get("amount", 1))
	var damage_result: Dictionary = _timing_rules().apply_player_damage(match_state, opponent_id, amount, {
		"reason": "lane_effect_warzone",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": player_id,
	})
	var events: Array = [{
		"event_type": "damage_resolved",
		"damage_kind": "lane_effect_warzone",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": player_id,
		"target_type": "player",
		"target_player_id": opponent_id,
		"amount": int(damage_result.get("applied_damage", 0)),
		"lane_id": str(trigger.get("descriptor", {}).get("_lane_id", "")),
	}]
	events.append_array(damage_result.get("events", []))
	return {"handled": true, "events": events}


# --- Windy: random creature switches lanes at end of turn ---
static func _resolve_lane_windy_switch(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var active_player_id := str(event.get("player_id", ""))
	if active_player_id.is_empty():
		return {"handled": true, "events": []}
	# Collect all creatures across all lanes
	var all_creatures: Array = []
	for lane in match_state.get("lanes", []):
		for pid in lane.get("player_slots", {}).keys():
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) == TYPE_DICTIONARY:
					all_creatures.append(card)
	if all_creatures.is_empty():
		return {"handled": true, "events": []}
	var source_id := str(trigger.get("source_instance_id", ""))
	var idx := EvergreenRules._choose_deterministic_candidate_index(match_state, source_id + "_windy", all_creatures)
	var chosen: Dictionary = all_creatures[idx]
	var chosen_id := str(chosen.get("instance_id", ""))
	var chosen_lane := str(chosen.get("lane_id", ""))
	# Find the other lane
	var target_lane_id := ""
	for lane in match_state.get("lanes", []):
		var lid := str(lane.get("lane_id", ""))
		if lid != chosen_lane:
			target_lane_id = lid
			break
	if target_lane_id.is_empty():
		return {"handled": true, "events": []}
	# Check capacity in target lane
	var chosen_pid := str(chosen.get("controller_player_id", ""))
	var target_lane := _get_lane(match_state, target_lane_id)
	var target_slots: Array = target_lane.get("player_slots", {}).get(chosen_pid, [])
	if int(target_slots.size()) >= int(target_lane.get("slot_capacity", 4)):
		return {"handled": true, "events": []}
	# Move: remove from source lane
	var source_lane := _get_lane(match_state, chosen_lane)
	var source_slots: Array = source_lane.get("player_slots", {}).get(chosen_pid, [])
	for i in range(source_slots.size()):
		if str(source_slots[i].get("instance_id", "")) == chosen_id:
			source_slots.remove_at(i)
			break
	# Re-index source slots
	for i in range(source_slots.size()):
		source_slots[i]["slot_index"] = i
	# Add to target lane
	chosen["lane_id"] = target_lane_id
	chosen["slot_index"] = int(target_slots.size())
	target_slots.append(chosen)
	return {"handled": true, "events": [{
		"event_type": "card_moved",
		"source_instance_id": chosen_id,
		"player_id": chosen_pid,
		"from_lane_id": chosen_lane,
		"lane_id": target_lane_id,
		"granted_by": "lane_effect_windy",
	}]}


# --- Zoo: transform summoned creature into random Animal ---
static func _resolve_lane_zoo_transform(match_state: Dictionary, trigger: Dictionary, event: Dictionary, _effect: Dictionary) -> Dictionary:
	var card := _get_summoned_creature_in_lane(match_state, trigger, event)
	if card.is_empty():
		return {"handled": true, "events": []}
	var creature_id := str(card.get("instance_id", ""))
	var player_id := str(card.get("controller_player_id", ""))
	var synth_trigger := trigger.duplicate(true)
	synth_trigger["controller_player_id"] = player_id
	synth_trigger["source_instance_id"] = creature_id
	var custom_result: Dictionary = _extended_packs().apply_custom_effect(match_state, synth_trigger, event, {
		"op": "summon_random_from_catalog",
		"filter": {"card_type": "creature", "required_subtype": "Animal"},
	})
	if bool(custom_result.get("handled", false)):
		# Transform the existing creature rather than summoning a new one
		var catalog_events: Array = custom_result.get("events", [])
		return {"handled": true, "events": catalog_events}
	return {"handled": true, "events": []}


static func _resolve_lane_ballista_damage(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))
	var active_player_id := str(event.get("player_id", ""))
	if active_player_id.is_empty():
		return {"handled": true, "events": []}

	var lane: Dictionary = {}
	for l in match_state.get("lanes", []):
		if str(l.get("lane_id", "")) == lane_id:
			lane = l
			break
	if lane.is_empty():
		return {"handled": true, "events": []}

	var counts_per_player := {}
	var player_slots: Dictionary = lane.get("player_slots", {})
	for pid in player_slots:
		var count := 0
		for card in player_slots[pid]:
			if typeof(card) == TYPE_DICTIONARY:
				count += 1
		if count > 0:
			counts_per_player[str(pid)] = count

	if counts_per_player.is_empty():
		return {"handled": true, "events": []}

	var best_count := -1
	var best_owner := ""
	var tied := false
	for pid in counts_per_player:
		var count: int = counts_per_player[pid]
		if count > best_count:
			best_count = count
			best_owner = pid
			tied = false
		elif count == best_count:
			tied = true

	if tied or best_owner != active_player_id:
		return {"handled": true, "events": []}

	var opponent_id := ""
	for player in match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != active_player_id:
			opponent_id = str(player.get("player_id", ""))
			break
	if opponent_id.is_empty():
		return {"handled": true, "events": []}

	var amount := int(effect.get("amount", 2))
	var damage_result: Dictionary = _timing_rules().apply_player_damage(match_state, opponent_id, amount, {
		"reason": "lane_effect_ballista_tower",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": active_player_id,
	})

	var events: Array = [{
		"event_type": "damage_resolved",
		"damage_kind": "lane_effect_ballista_tower",
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"source_controller_player_id": active_player_id,
		"target_type": "player",
		"target_player_id": opponent_id,
		"amount": int(damage_result.get("applied_damage", 0)),
		"lane_id": lane_id,
	}]
	events.append_array(damage_result.get("events", []))
	return {"handled": true, "events": events}


static func _timing_rules():
	return load("res://src/core/match/match_timing.gd")


static func _extended_packs():
	return load("res://src/core/match/extended_mechanic_packs.gd")


static func _card_catalog():
	return load("res://src/deck/card_catalog.gd")
