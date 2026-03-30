class_name MatchMutations
extends RefCounted

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")

const CARD_TYPE_CREATURE := "creature"
const CARD_TYPE_ITEM := "item"
const ZONE_HAND := "hand"
const ZONE_SUPPORT := "support"
const ZONE_DECK := "deck"
const ZONE_LANE := "lane"
const ZONE_ATTACHED_ITEM := "attached_item"
const ZONE_DISCARD := "discard"
const ZONE_BANISHED := "banished"
const ZONE_GENERATED := "generated"
const PLAYER_ZONE_ORDER := [ZONE_HAND, ZONE_SUPPORT, ZONE_DISCARD, ZONE_BANISHED, ZONE_DECK]
const IDENTITY_FIELDS := [
	"definition_id", "name", "card_type", "cost", "power", "health", "base_power", "base_health",
	"keywords", "rules_tags", "triggered_abilities", "support_uses", "subtypes", "attributes",
	"class_id", "rarity", "is_unique", "effect_ids", "rules_text", "source_ids", "collectible",
	"generated_by_rules", "shout_level", "shout_chain_id", "shout_levels", "action_target_mode",
	"innate_statuses"
]


static func find_card_location(match_state: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return _invalid_result("instance_id is required.")
	for player_index in range(match_state.get("players", []).size()):
		var player: Dictionary = match_state["players"][player_index]
		for zone_name in PLAYER_ZONE_ORDER:
			var cards = player.get(zone_name, [])
			if typeof(cards) != TYPE_ARRAY:
				continue
			for card_index in range(cards.size()):
				var card = cards[card_index]
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return {
						"is_valid": true,
						"errors": [],
						"location_type": "player_zone",
						"player_index": player_index,
						"player_id": str(player.get("player_id", "")),
						"zone": zone_name,
						"card_index": card_index,
						"card": card,
					}
	for lane_index in range(match_state.get("lanes", []).size()):
		var lane: Dictionary = match_state["lanes"][lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots = player_slots_by_id[player_id]
			if typeof(slots) != TYPE_ARRAY:
				continue
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return {
						"is_valid": true,
						"errors": [],
						"location_type": "lane_slot",
						"lane_index": lane_index,
						"lane_id": str(lane.get("lane_id", "")),
						"player_id": str(player_id),
						"zone": ZONE_LANE,
						"slot_index": slot_index,
						"card": card,
					}
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var attached_items: Array = card.get("attached_items", [])
				for attached_index in range(attached_items.size()):
					var attached_item = attached_items[attached_index]
					if typeof(attached_item) == TYPE_DICTIONARY and str(attached_item.get("instance_id", "")) == instance_id:
						return {
							"is_valid": true,
							"errors": [],
							"location_type": ZONE_ATTACHED_ITEM,
							"lane_index": lane_index,
							"lane_id": str(lane.get("lane_id", "")),
							"player_id": str(player_id),
							"zone": ZONE_ATTACHED_ITEM,
							"slot_index": slot_index,
							"attached_index": attached_index,
							"host_card": card,
							"host_instance_id": str(card.get("instance_id", "")),
							"card": attached_item,
						}
	return _invalid_result("Card %s could not be found." % instance_id)


static func attach_item_to_creature(match_state: Dictionary, controller_player_id: String, item_source, target_instance_id: String, options: Dictionary = {}) -> Dictionary:
	var target_location := find_card_location(match_state, target_instance_id)
	if not bool(target_location.get("is_valid", false)):
		return target_location
	if str(target_location.get("zone", "")) != ZONE_LANE:
		return _invalid_result("Items can only be attached to creatures in a lane.")
	var target_card: Dictionary = target_location["card"]
	if str(target_card.get("card_type", "")) != CARD_TYPE_CREATURE:
		return _invalid_result("Items can only be attached to creature cards.")

	var item: Dictionary = {}
	var source_location: Dictionary = {}
	var source_zone := str(options.get("source_zone", ""))
	if typeof(item_source) == TYPE_STRING:
		source_location = find_card_location(match_state, str(item_source))
		if not bool(source_location.get("is_valid", false)):
			return source_location
		item = source_location["card"]
		source_zone = str(source_location.get("zone", source_zone))
	elif typeof(item_source) == TYPE_DICTIONARY:
		item = item_source
		if source_zone.is_empty():
			source_zone = str(item.get("zone", ZONE_GENERATED))
	else:
		return _invalid_result("attach_item_to_creature requires an instance_id or card dictionary.")

	if str(item.get("card_type", "")) != CARD_TYPE_ITEM:
		return _invalid_result("Only item cards can be attached to creatures.")

	if not source_location.is_empty():
		_detach_card(match_state, source_location)
	_clear_lane_state(item)
	_clear_attachment_state(item)
	item["controller_player_id"] = str(target_card.get("controller_player_id", controller_player_id))
	if not item.has("owner_player_id"):
		item["owner_player_id"] = controller_player_id
	item["zone"] = ZONE_ATTACHED_ITEM
	item["attached_to_instance_id"] = str(target_card.get("instance_id", ""))
	EvergreenRules.ensure_card_state(target_card)
	var attached_items: Array = target_card.get("attached_items", [])
	attached_items.append(item)
	target_card["attached_items"] = attached_items
	return {
		"is_valid": true,
		"errors": [],
		"card": item,
		"host": target_card,
		"events": [
			_build_move_event(item, source_zone, ZONE_ATTACHED_ITEM, str(item.get("controller_player_id", controller_player_id))),
			{
				"event_type": "card_equipped",
				"player_id": controller_player_id,
				"source_instance_id": str(item.get("instance_id", "")),
				"target_instance_id": str(target_card.get("instance_id", "")),
				"controller_player_id": str(item.get("controller_player_id", controller_player_id)),
			}
		],
	}


static func detach_all_attached_items(match_state: Dictionary, host_instance_id: String, options: Dictionary = {}) -> Dictionary:
	var host_location := find_card_location(match_state, host_instance_id)
	if not bool(host_location.get("is_valid", false)):
		return host_location
	return _move_attached_items_to_owner_discard(match_state, host_location["card"], options)


static func validate_lane_entry(match_state: Dictionary, player_id: String, card: Dictionary, lane_id: String, options: Dictionary = {}) -> Dictionary:
	if str(card.get("card_type", "")) != CARD_TYPE_CREATURE:
		return _invalid_result("Only creature cards can enter lanes.")
	var lane_index := _find_lane_index(match_state.get("lanes", []), lane_id)
	if lane_index == -1:
		return _invalid_result("Unknown lane_id: %s" % lane_id)
	var lane: Dictionary = match_state["lanes"][lane_index]
	var player_slots_by_id: Dictionary = lane.get("player_slots", {})
	if not player_slots_by_id.has(player_id):
		return _invalid_result("Lane %s does not track player_id %s." % [lane_id, player_id])
	var player_slots: Array = player_slots_by_id[player_id]
	var slot_capacity := int(lane.get("slot_capacity", 0))
	var requested_slot := int(options.get("slot_index", -1))
	var slot_index := requested_slot
	if requested_slot == -1:
		slot_index = _find_open_slot(player_slots, slot_capacity)
		if slot_index == -1:
			return _invalid_result("Lane %s is full for %s." % [lane_id, player_id])
	else:
		if requested_slot < 0 or requested_slot > player_slots.size():
			return _invalid_result("Requested slot %d is out of range for lane %s." % [requested_slot, lane_id])
		if player_slots.size() >= slot_capacity:
			return _invalid_result("Lane %s is full for %s." % [lane_id, player_id])
	# Sewer lane restriction: creatures with more than 2 health cannot be played here
	var lane_type := str(lane.get("lane_type", lane_id))
	var lane_payload: Dictionary = lane.get("lane_rule_payload", {})
	var lane_effects: Array = lane_payload.get("effects", [])
	for le in lane_effects:
		if typeof(le) != TYPE_DICTIONARY:
			continue
		for le_eff in le.get("effects", []):
			if typeof(le_eff) == TYPE_DICTIONARY and str(le_eff.get("op", "")) == "lane_sewer_restrict":
				var max_health := int(le_eff.get("max_health", 2))
				var card_health := int(card.get("health", card.get("base_health", 0)))
				if card_health > max_health:
					return _invalid_result("Creatures with more than %d health cannot be played in this lane." % max_health)
	return {
		"is_valid": true,
		"errors": [],
		"lane_id": lane_id,
		"lane_index": lane_index,
		"slot_index": slot_index,
		"lane_type": lane_type,
		"lane_rule_payload": lane_payload,
		"granted_cover": false,
	}


static func summon_card_to_lane(match_state: Dictionary, controller_player_id: String, card_source, lane_id: String, options: Dictionary = {}) -> Dictionary:
	var card: Dictionary = {}
	var source_location: Dictionary = {}
	var source_zone := str(options.get("source_zone", ""))
	if typeof(card_source) == TYPE_STRING:
		source_location = find_card_location(match_state, str(card_source))
		if not bool(source_location.get("is_valid", false)):
			return source_location
		card = source_location["card"]
		source_zone = str(source_location.get("zone", source_zone))
	elif typeof(card_source) == TYPE_DICTIONARY:
		card = card_source
		if source_zone.is_empty():
			source_zone = str(card.get("zone", ZONE_GENERATED))
	else:
		return _invalid_result("summon_card_to_lane requires an instance_id or card dictionary.")
	var validation := validate_lane_entry(match_state, controller_player_id, card, lane_id, options)
	if not validation["is_valid"]:
		return validation
	if not source_location.is_empty():
		_detach_card(match_state, source_location)
	_apply_lane_entry(match_state, controller_player_id, card, validation, options)
	return {
		"is_valid": true,
		"errors": [],
		"lane_id": lane_id,
		"lane_index": validation["lane_index"],
		"slot_index": validation["slot_index"],
		"card": card,
		"granted_cover": bool(validation.get("granted_cover", false)),
		"events": [_build_move_event(card, source_zone, ZONE_LANE, controller_player_id)],
	}


static func move_card_to_zone(match_state: Dictionary, instance_id: String, zone_name: String, options: Dictionary = {}) -> Dictionary:
	if not PLAYER_ZONE_ORDER.has(zone_name):
		return _invalid_result("Unsupported destination zone: %s" % zone_name)
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	var card: Dictionary = location["card"]
	var target_player_id := str(options.get("target_player_id", card.get("owner_player_id", location.get("player_id", ""))))
	var player_lookup := _find_player(match_state.get("players", []), target_player_id)
	if not bool(player_lookup.get("is_valid", false)):
		return player_lookup
	if str(location.get("zone", "")) == ZONE_LANE and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
		_move_attached_items_to_owner_discard(match_state, card, {"reason": str(options.get("reason", "host_left_play"))})
	_detach_card(match_state, location)
	var target_cards: Array = player_lookup["player"][zone_name]
	var insert_index := int(options.get("insert_index", -1))
	if insert_index >= 0 and insert_index <= target_cards.size():
		target_cards.insert(insert_index, card)
	else:
		target_cards.append(card)
	if options.has("owner_player_id"):
		card["owner_player_id"] = str(options.get("owner_player_id", ""))
	elif not card.has("owner_player_id"):
		card["owner_player_id"] = target_player_id
	card["controller_player_id"] = target_player_id
	card["zone"] = zone_name
	_clear_lane_state(card)
	_clear_attachment_state(card)
	if zone_name == ZONE_HAND or zone_name == ZONE_DISCARD or zone_name == ZONE_BANISHED:
		reset_transient_state(card)
	if zone_name == ZONE_HAND:
		apply_first_turn_hand_cost(match_state, card, target_player_id)
	return {
		"is_valid": true,
		"errors": [],
		"card": card,
		"source_zone": str(location.get("zone", "")),
		"target_zone": zone_name,
		"player_id": target_player_id,
		"events": [_build_move_event(card, str(location.get("zone", "")), zone_name, target_player_id)],
	}


static func move_card_between_lanes(match_state: Dictionary, controller_player_id: String, instance_id: String, target_lane_id: String, options: Dictionary = {}) -> Dictionary:
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	if str(location.get("zone", "")) != ZONE_LANE:
		return _invalid_result("Card %s is not on the board." % instance_id)
	if str(location.get("player_id", "")) != controller_player_id:
		return _invalid_result("Card %s is not controlled by %s." % [instance_id, controller_player_id])
	var destination_controller := str(options.get("override_controller_player_id", controller_player_id))
	if str(location.get("lane_id", "")) == target_lane_id and destination_controller == controller_player_id:
		return _invalid_result("Card %s is already in lane %s." % [instance_id, target_lane_id])
	var card: Dictionary = location["card"]
	var validation := validate_lane_entry(match_state, destination_controller, card, target_lane_id, options)
	if not validation["is_valid"]:
		return validation
	_detach_card(match_state, location)
	_apply_lane_entry(match_state, destination_controller, card, validation, options)
	_sync_attached_item_controllers(card)
	return {
		"is_valid": true,
		"errors": [],
		"from_lane_id": str(location.get("lane_id", "")),
		"to_lane_id": target_lane_id,
		"slot_index": validation["slot_index"],
		"card": card,
		"granted_cover": bool(validation.get("granted_cover", false)),
		"events": [_build_move_event(card, ZONE_LANE, ZONE_LANE, destination_controller)],
	}


static func discard_card(match_state: Dictionary, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	var destination_player_id := str(options.get("target_player_id", location["card"].get("owner_player_id", location.get("player_id", ""))))
	return move_card_to_zone(match_state, instance_id, ZONE_DISCARD, {
		"target_player_id": destination_player_id,
		"owner_player_id": str(location["card"].get("owner_player_id", destination_player_id)),
	})


static func banish_card(match_state: Dictionary, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	var destination_player_id := str(options.get("target_player_id", location["card"].get("owner_player_id", location.get("player_id", ""))))
	return move_card_to_zone(match_state, instance_id, ZONE_BANISHED, {
		"target_player_id": destination_player_id,
		"owner_player_id": str(location["card"].get("owner_player_id", destination_player_id)),
	})


static func unsummon_card(match_state: Dictionary, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	if str(location.get("zone", "")) != ZONE_LANE:
		return _invalid_result("Only lane cards can be unsummoned.")
	var destination_player_id := str(options.get("target_player_id", location["card"].get("owner_player_id", "")))
	return move_card_to_zone(match_state, instance_id, ZONE_HAND, {
		"target_player_id": destination_player_id,
		"owner_player_id": str(location["card"].get("owner_player_id", destination_player_id)),
	})


static func sacrifice_card(match_state: Dictionary, controller_player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	if str(location.get("zone", "")) != ZONE_LANE:
		return _invalid_result("Only lane cards can be sacrificed.")
	if str(location.get("player_id", "")) != controller_player_id:
		return _invalid_result("Card %s is not controlled by %s." % [instance_id, controller_player_id])
	var result := discard_card(match_state, instance_id, options)
	if bool(result.get("is_valid", false)):
		result["events"].append({
			"event_type": "card_sacrificed",
			"source_instance_id": instance_id,
			"controller_player_id": controller_player_id,
		})
	return result


static func discard_from_hand(match_state: Dictionary, player_id: String, count: int, options: Dictionary = {}) -> Dictionary:
	var player_lookup := _find_player(match_state.get("players", []), player_id)
	if not bool(player_lookup.get("is_valid", false)):
		return player_lookup
	var player: Dictionary = player_lookup["player"]
	var hand: Array = player.get(ZONE_HAND, [])
	var cards: Array = []
	var events: Array = []
	for _index in range(maxi(0, count)):
		if hand.is_empty():
			break
		var selected_index := hand.size() - 1 if str(options.get("selection", "front")) == "back" else 0
		var card: Dictionary = hand[selected_index]
		hand.remove_at(selected_index)
		var destination_player_id := str(card.get("owner_player_id", player_id))
		var destination_lookup := _find_player(match_state.get("players", []), destination_player_id)
		if not bool(destination_lookup.get("is_valid", false)):
			destination_player_id = player_id
			destination_lookup = player_lookup
		card["controller_player_id"] = destination_player_id
		card["zone"] = ZONE_DISCARD
		_clear_lane_state(card)
		destination_lookup["player"][ZONE_DISCARD].append(card)
		cards.append(card)
		events.append(_build_move_event(card, ZONE_HAND, ZONE_DISCARD, destination_player_id))
	return {"is_valid": true, "errors": [], "cards": cards, "events": events}


static func steal_card(match_state: Dictionary, controller_player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	var current_zone := str(location.get("zone", ""))
	if current_zone == ZONE_LANE:
		var result := move_card_between_lanes(match_state, str(location.get("player_id", "")), instance_id, str(location.get("lane_id", "")), {
			"slot_index": -1,
			"apply_shadow_cover": false,
			"preserve_entered_lane_on_turn": true,
			"override_controller_player_id": controller_player_id,
		})
		if bool(result.get("is_valid", false)):
			result["card"]["controller_player_id"] = controller_player_id
			result["events"].append({
				"event_type": "card_stolen",
				"source_instance_id": instance_id,
				"controller_player_id": controller_player_id,
			})
		return result
	var zone_result := move_card_to_zone(match_state, instance_id, current_zone, {
		"target_player_id": controller_player_id,
		"owner_player_id": str(location["card"].get("owner_player_id", controller_player_id)),
	})
	if bool(zone_result.get("is_valid", false)):
		zone_result["events"].append({
			"event_type": "card_stolen",
			"source_instance_id": instance_id,
			"controller_player_id": controller_player_id,
		})
	return zone_result


static func update_card_owner(match_state: Dictionary, instance_id: String, owner_player_id: String) -> Dictionary:
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	location["card"]["owner_player_id"] = owner_player_id
	return {
		"is_valid": true,
		"errors": [],
		"card": location["card"],
		"events": [{"event_type": "card_owner_changed", "source_instance_id": instance_id, "owner_player_id": owner_player_id}],
	}


static func build_generated_card(match_state: Dictionary, controller_player_id: String, template: Dictionary) -> Dictionary:
	match_state["generated_card_sequence"] = int(match_state.get("generated_card_sequence", 0)) + 1
	var card := template.duplicate(true)
	var def_id := str(card.get("definition_id", ""))
	if not def_id.is_empty() and not card.has("triggered_abilities"):
		for seed in CardCatalog._card_seeds():
			if typeof(seed) == TYPE_DICTIONARY and str(seed.get("card_id", "")) == def_id:
				var seed_abilities: Array = seed.get("triggered_abilities", [])
				if not seed_abilities.is_empty():
					card["triggered_abilities"] = seed_abilities.duplicate(true)
				var seed_aura = seed.get("aura", null)
				if seed_aura != null and not card.has("aura"):
					card["aura"] = seed_aura.duplicate(true)
				var seed_innate: Array = seed.get("innate_statuses", [])
				if not seed_innate.is_empty() and not card.has("innate_statuses"):
					card["innate_statuses"] = seed_innate.duplicate(true)
				if seed.has("first_turn_hand_cost") and not card.has("first_turn_hand_cost"):
					card["first_turn_hand_cost"] = int(seed["first_turn_hand_cost"])
				break
	if not card.has("art_path") and not def_id.is_empty():
		card["art_path"] = "res://assets/images/cards/" + def_id + ".png"
	if not card.has("instance_id") or str(card.get("instance_id", "")).is_empty():
		card["instance_id"] = "%s_generated_%03d" % [controller_player_id, int(match_state.get("generated_card_sequence", 0))]
	if not card.has("owner_player_id"):
		card["owner_player_id"] = controller_player_id
	card["controller_player_id"] = controller_player_id
	card["zone"] = str(card.get("zone", ZONE_GENERATED))
	if bool(card.get("stats_from_max_magicka", false)):
		var max_magicka := 0
		for player in match_state.get("players", []):
			if str(player.get("player_id", "")) == controller_player_id:
				max_magicka = int(player.get("max_magicka", 0))
				break
		card["cost"] = max_magicka
		card["power"] = max_magicka
		card["health"] = max_magicka
		card["base_power"] = max_magicka
		card["base_health"] = max_magicka
		card.erase("stats_from_max_magicka")
	EvergreenRules.ensure_card_state(card)
	return card


static func silence_card(card: Dictionary, options: Dictionary = {}, match_state: Dictionary = {}) -> Dictionary:
	var previous_definition_id := str(card.get("definition_id", ""))
	var events: Array = []
	if not match_state.is_empty():
		var detached := _move_attached_items_to_owner_discard(match_state, card, {"reason": str(options.get("reason", "silence"))})
		events.append_array(detached.get("events", []))
	EvergreenRules.ensure_card_state(card)
	card["keywords"] = []
	card["granted_keywords"] = []
	card["triggered_abilities"] = []
	card["power_bonus"] = 0
	card["health_bonus"] = 0
	card["status_markers"] = [EvergreenRules.STATUS_SILENCED]
	card.erase("aura")
	card.erase("cover_expires_on_turn")
	card.erase("cover_granted_by")
	card.erase("shackle_expires_on_turn")
	card.erase("temporary_stat_bonuses")
	card.erase("temporary_keywords")
	EvergreenRules.sync_derived_state(card)
	return {
		"is_valid": true,
		"errors": [],
		"card": card,
		"events": events + [{"event_type": "card_silenced", "source_instance_id": str(card.get("instance_id", "")), "definition_id": previous_definition_id}],
	}


static func change_card(card: Dictionary, template: Dictionary, options: Dictionary = {}) -> Dictionary:
	var previous_definition_id := str(card.get("definition_id", ""))
	var preserved := _preserve_card_state(card, {
		"modifiers": true,
		"damage": true,
		"statuses": true,
		"attack_state": true,
		"entered_lane": true,
	})
	_apply_identity(card, template)
	# art_path is not an identity field — update from template or derive from new definition_id
	if template.has("art_path"):
		card["art_path"] = str(template["art_path"])
	else:
		card["art_path"] = "res://assets/images/cards/" + str(card.get("definition_id", "")) + ".png"
	_restore_card_state(card, preserved, options)
	card["changed_from"] = previous_definition_id
	EvergreenRules.sync_derived_state(card)
	return {"is_valid": true, "errors": [], "card": card, "events": [{"event_type": "card_changed", "source_instance_id": str(card.get("instance_id", ""))}]}


static func copy_card(target_card: Dictionary, source_card: Dictionary, options: Dictionary = {}) -> Dictionary:
	var preserved := _preserve_card_state(target_card, {
		"modifiers": bool(options.get("preserve_modifiers", false)),
		"damage": bool(options.get("preserve_damage", false)),
		"statuses": bool(options.get("preserve_statuses", false)),
		"attack_state": true,
		"entered_lane": true,
	})
	_apply_identity(target_card, _extract_identity(source_card))
	# art_path is not an identity field — copy from source or derive from new definition_id
	var source_art := str(source_card.get("art_path", ""))
	if not source_art.is_empty():
		target_card["art_path"] = source_art
	else:
		target_card["art_path"] = "res://assets/images/cards/" + str(target_card.get("definition_id", "")) + ".png"
	reset_transient_state(target_card)
	_restore_card_state(target_card, preserved, options)
	target_card["copied_from"] = str(source_card.get("definition_id", source_card.get("instance_id", "")))
	EvergreenRules.sync_derived_state(target_card)
	return {"is_valid": true, "errors": [], "card": target_card, "events": [{"event_type": "card_copied", "source_instance_id": str(target_card.get("instance_id", "")), "copied_from_instance_id": str(source_card.get("instance_id", ""))}]}


static func transform_card(match_state: Dictionary, instance_id: String, template: Dictionary, options: Dictionary = {}) -> Dictionary:
	var location := find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	var card: Dictionary = location["card"]
	var previous_definition_id := str(card.get("definition_id", ""))
	var detached := _move_attached_items_to_owner_discard(match_state, card, {"reason": str(options.get("reason", "transform"))})
	var preserved := _preserve_card_state(card, {"attack_state": true, "entered_lane": true})
	_apply_identity(card, template)
	# art_path is not an identity field — update it from the template or derive from new definition_id
	if template.has("art_path"):
		card["art_path"] = str(template["art_path"])
	else:
		card["art_path"] = "res://assets/images/cards/" + str(card.get("definition_id", "")) + ".png"
	reset_transient_state(card)
	_restore_card_state(card, preserved, options)
	card["transformed_from"] = previous_definition_id
	EvergreenRules.sync_derived_state(card)
	var events: Array = detached.get("events", []).duplicate(true)
	events.append({"event_type": "card_transformed", "source_instance_id": instance_id, "from_definition_id": previous_definition_id})
	if str(location.get("zone", "")) == ZONE_LANE and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
		events.append({
			"event_type": "creature_summoned",
			"player_id": str(card.get("controller_player_id", "")),
			"source_instance_id": instance_id,
			"source_controller_player_id": str(card.get("controller_player_id", "")),
			"lane_id": str(card.get("lane_id", "")),
			"slot_index": int(card.get("slot_index", -1)),
			"reason": str(options.get("reason", "transform")),
		})
	return {"is_valid": true, "errors": [], "card": card, "events": events}


static func consume_card(match_state: Dictionary, controller_player_id: String, consumer_instance_id: String, target_instance_id: String, options: Dictionary = {}) -> Dictionary:
	var consumer_location := find_card_location(match_state, consumer_instance_id)
	var target_location := find_card_location(match_state, target_instance_id)
	if not bool(consumer_location.get("is_valid", false)):
		return consumer_location
	if not bool(target_location.get("is_valid", false)):
		return target_location
	var consumer: Dictionary = consumer_location["card"]
	if str(consumer.get("controller_player_id", consumer_location.get("player_id", ""))) != controller_player_id:
		return _invalid_result("Consumer %s is not controlled by %s." % [consumer_instance_id, controller_player_id])
	var target: Dictionary = target_location["card"]
	var power_gain := int(options.get("power_gain", EvergreenRules.get_power(target)))
	var health_gain := int(options.get("health_gain", EvergreenRules.get_health(target)))
	var destination_zone := str(options.get("destination_zone", ZONE_BANISHED))
	var moved := banish_card(match_state, target_instance_id, options) if destination_zone == ZONE_BANISHED else discard_card(match_state, target_instance_id, options)
	if not bool(moved.get("is_valid", false)):
		return moved
	EvergreenRules.apply_stat_bonus(consumer, power_gain, health_gain, str(options.get("reason", "consume")))
	var consumer_lane_id := str(consumer.get("lane_id", ""))
	if consumer_lane_id.is_empty():
		# Look up lane from location
		var consumer_lane_index := int(consumer_location.get("lane_index", -1))
		if consumer_lane_index >= 0:
			var lanes: Array = match_state.get("lanes", [])
			if consumer_lane_index < lanes.size():
				consumer_lane_id = str(lanes[consumer_lane_index].get("lane_id", ""))
	var events: Array = moved.get("events", []).duplicate(true)
	events.append({
		"event_type": "card_consumed",
		"source_instance_id": consumer_instance_id,
		"target_instance_id": target_instance_id,
		"power_gain": power_gain,
		"health_gain": health_gain,
		"lane_id": consumer_lane_id,
		"player_id": controller_player_id,
	})
	return {"is_valid": true, "errors": [], "card": consumer, "events": events}


static func _apply_lane_entry(match_state: Dictionary, controller_player_id: String, card: Dictionary, validation: Dictionary, options: Dictionary = {}) -> void:
	var lane: Dictionary = match_state["lanes"][validation["lane_index"]]
	var lane_controller_player_id := str(options.get("override_controller_player_id", controller_player_id))
	var player_slots: Array = lane["player_slots"][lane_controller_player_id]
	EvergreenRules.ensure_card_state(card)
	_apply_innate_statuses(card)
	card["controller_player_id"] = lane_controller_player_id
	if not card.has("owner_player_id"):
		card["owner_player_id"] = lane_controller_player_id
	card["zone"] = ZONE_LANE
	card["lane_id"] = validation["lane_id"]
	card["slot_index"] = validation["slot_index"]
	if not bool(options.get("preserve_entered_lane_on_turn", false)) or not card.has("entered_lane_on_turn"):
		card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0))
		card["has_attacked_this_turn"] = false
	_sync_attached_item_controllers(card)
	player_slots.insert(validation["slot_index"], card)
	_reindex_player_slots(player_slots)


static func _detach_card(match_state: Dictionary, location: Dictionary) -> void:
	if str(location.get("location_type", "")) == "player_zone":
		var player: Dictionary = match_state["players"][int(location.get("player_index", -1))]
		var zone_name := str(location.get("zone", ""))
		var cards: Array = player[zone_name]
		cards.remove_at(int(location.get("card_index", -1)))
		return
	if str(location.get("location_type", "")) == ZONE_ATTACHED_ITEM:
		var host_card: Dictionary = location.get("host_card", {})
		EvergreenRules.ensure_card_state(host_card)
		var attached_items: Array = host_card.get("attached_items", [])
		attached_items.remove_at(int(location.get("attached_index", -1)))
		host_card["attached_items"] = attached_items
		return
	if str(location.get("location_type", "")) == "lane_slot":
		var lane: Dictionary = match_state["lanes"][int(location.get("lane_index", -1))]
		var player_slots: Array = lane["player_slots"][str(location.get("player_id", ""))]
		player_slots.remove_at(int(location.get("slot_index", -1)))
		_reindex_player_slots(player_slots)


static func _apply_identity(card: Dictionary, template: Dictionary) -> void:
	for key in IDENTITY_FIELDS:
		if template.has(key):
			card[key] = _clone_variant(template[key])
		else:
			card.erase(key)
	EvergreenRules.ensure_card_state(card)


static func _extract_identity(card: Dictionary) -> Dictionary:
	var identity := {}
	for key in IDENTITY_FIELDS:
		if card.has(key):
			identity[key] = _clone_variant(card[key])
	return identity


static func _preserve_card_state(card: Dictionary, flags: Dictionary) -> Dictionary:
	var preserved := {
		"instance_id": str(card.get("instance_id", "")),
		"owner_player_id": str(card.get("owner_player_id", "")),
		"controller_player_id": str(card.get("controller_player_id", "")),
		"zone": str(card.get("zone", "")),
		"lane_id": str(card.get("lane_id", "")),
		"slot_index": int(card.get("slot_index", -1)),
	}
	if bool(flags.get("modifiers", false)):
		preserved["power_bonus"] = int(card.get("power_bonus", 0))
		preserved["health_bonus"] = int(card.get("health_bonus", 0))
		preserved["granted_keywords"] = _clone_variant(card.get("granted_keywords", []))
	if bool(flags.get("damage", false)):
		preserved["damage_marked"] = int(card.get("damage_marked", 0))
	if bool(flags.get("statuses", false)):
		preserved["status_markers"] = _clone_variant(card.get("status_markers", []))
		if card.has("cover_expires_on_turn"):
			preserved["cover_expires_on_turn"] = int(card.get("cover_expires_on_turn", -1))
		if card.has("cover_granted_by"):
			preserved["cover_granted_by"] = str(card.get("cover_granted_by", ""))
	if bool(flags.get("attack_state", false)):
		preserved["has_attacked_this_turn"] = bool(card.get("has_attacked_this_turn", false))
	if bool(flags.get("entered_lane", false)) and card.has("entered_lane_on_turn"):
		preserved["entered_lane_on_turn"] = int(card.get("entered_lane_on_turn", -1))
	return preserved


static func _restore_card_state(card: Dictionary, preserved: Dictionary, _options: Dictionary = {}) -> void:
	card["instance_id"] = preserved["instance_id"]
	card["owner_player_id"] = preserved["owner_player_id"]
	card["controller_player_id"] = preserved["controller_player_id"]
	card["zone"] = preserved["zone"]
	if str(preserved.get("lane_id", "")).is_empty():
		card.erase("lane_id")
	else:
		card["lane_id"] = preserved["lane_id"]
	if int(preserved.get("slot_index", -1)) == -1:
		card.erase("slot_index")
	else:
		card["slot_index"] = preserved["slot_index"]
	for key in ["power_bonus", "health_bonus", "granted_keywords", "damage_marked", "status_markers", "has_attacked_this_turn", "entered_lane_on_turn"]:
		if preserved.has(key):
			card[key] = _clone_variant(preserved[key])
	if preserved.has("cover_expires_on_turn"):
		card["cover_expires_on_turn"] = int(preserved.get("cover_expires_on_turn", -1))
	if preserved.has("cover_granted_by"):
		card["cover_granted_by"] = str(preserved.get("cover_granted_by", ""))


static func reset_transient_state(card: Dictionary) -> void:
	card["power_bonus"] = 0
	card["health_bonus"] = 0
	card["granted_keywords"] = []
	card["damage_marked"] = 0
	card["status_markers"] = []
	_apply_innate_statuses(card)
	card.erase("cover_expires_on_turn")
	card.erase("cover_granted_by")
	card.erase("temporary_stat_bonuses")
	card.erase("temporary_keywords")
	card.erase("_consumed_equip_keywords")


static func restore_definition_state(card: Dictionary) -> void:
	var def_id := str(card.get("definition_id", ""))
	if def_id.is_empty():
		return
	for seed in CardCatalog._card_seeds():
		if typeof(seed) == TYPE_DICTIONARY and str(seed.get("card_id", "")) == def_id:
			card["keywords"] = seed.get("keywords", []).duplicate(true)
			var seed_abilities: Array = seed.get("triggered_abilities", [])
			card["triggered_abilities"] = seed_abilities.duplicate(true)
			var seed_aura = seed.get("aura", null)
			if seed_aura != null:
				card["aura"] = seed_aura.duplicate(true)
			elif card.has("aura"):
				card.erase("aura")
			break


static func apply_first_turn_hand_cost(match_state: Dictionary, card: Dictionary, player_id: String) -> void:
	if not card.has("first_turn_hand_cost"):
		return
	var player := {}
	for p in match_state.get("players", []):
		if str(p.get("player_id", "")) == player_id:
			player = p
			break
	if player.is_empty():
		return
	if int(player.get("turns_started", 0)) == 1:
		card["cost"] = int(card.get("first_turn_hand_cost", card.get("cost", 0)))


static func _apply_innate_statuses(card: Dictionary) -> void:
	var innate: Array = card.get("innate_statuses", [])
	if innate.is_empty():
		return
	var markers: Array = card.get("status_markers", [])
	for status_id in innate:
		if not markers.has(status_id):
			markers.append(status_id)
	card["status_markers"] = markers


static func _clear_lane_state(card: Dictionary) -> void:
	card.erase("lane_id")
	card.erase("slot_index")
	card.erase("entered_lane_on_turn")


static func _clear_attachment_state(card: Dictionary) -> void:
	card.erase("attached_to_instance_id")


static func _sync_attached_item_controllers(card: Dictionary) -> void:
	EvergreenRules.ensure_card_state(card)
	for item in card.get("attached_items", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		item["controller_player_id"] = str(card.get("controller_player_id", ""))
		item["zone"] = ZONE_ATTACHED_ITEM
		item["attached_to_instance_id"] = str(card.get("instance_id", ""))


static func _move_attached_items_to_owner_discard(match_state: Dictionary, host_card: Dictionary, options: Dictionary = {}) -> Dictionary:
	EvergreenRules.ensure_card_state(host_card)
	var attached_items: Array = host_card.get("attached_items", [])
	if attached_items.is_empty():
		return {"is_valid": true, "errors": [], "items": [], "events": []}
	var moved_items: Array = []
	var events: Array = []
	for item in attached_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var destination_player_id := str(item.get("owner_player_id", host_card.get("owner_player_id", "")))
		var destination_lookup := _find_player(match_state.get("players", []), destination_player_id)
		if not bool(destination_lookup.get("is_valid", false)):
			continue
		_clear_attachment_state(item)
		item["controller_player_id"] = destination_player_id
		item["zone"] = ZONE_DISCARD
		destination_lookup["player"][ZONE_DISCARD].append(item)
		moved_items.append(item)
		events.append(_build_move_event(item, ZONE_ATTACHED_ITEM, ZONE_DISCARD, destination_player_id))
		events.append({
			"event_type": "attached_item_detached",
			"source_instance_id": str(item.get("instance_id", "")),
			"target_instance_id": str(host_card.get("instance_id", "")),
			"reason": str(options.get("reason", "host_left_play")),
		})
	host_card["attached_items"] = []
	return {"is_valid": true, "errors": [], "items": moved_items, "events": events}


static func _build_move_event(card: Dictionary, source_zone: String, target_zone: String, controller_player_id: String) -> Dictionary:
	return {
		"event_type": "card_moved",
		"source_instance_id": str(card.get("instance_id", "")),
		"owner_player_id": str(card.get("owner_player_id", "")),
		"controller_player_id": controller_player_id,
		"source_zone": source_zone,
		"target_zone": target_zone,
	}



static func _find_player(players: Array, player_id: String) -> Dictionary:
	for index in range(players.size()):
		var player: Dictionary = players[index]
		if str(player.get("player_id", "")) == player_id:
			return {"is_valid": true, "errors": [], "player_index": index, "player": player}
	return _invalid_result("Unknown player_id: %s" % player_id)


static func _find_lane_index(lanes: Array, lane_id: String) -> int:
	for index in range(lanes.size()):
		if str(lanes[index].get("lane_id", "")) == lane_id:
			return index
	return -1


static func _is_lane_slot_open(match_state: Dictionary, lane_id: String, player_id: String, slot_index: int) -> bool:
	var lane_index := _find_lane_index(match_state.get("lanes", []), lane_id)
	if lane_index == -1 or slot_index < 0:
		return false
	var lane: Dictionary = match_state["lanes"][lane_index]
	var player_slots_by_id: Dictionary = lane.get("player_slots", {})
	if not player_slots_by_id.has(player_id):
		return false
	var slots: Array = player_slots_by_id[player_id]
	var slot_capacity := int(lane.get("slot_capacity", 0))
	return slots.size() < slot_capacity and slot_index <= slots.size()


static func _find_open_slot(slots: Array, slot_capacity: int = -1) -> int:
	if slot_capacity == -1:
		# Legacy fallback — should not be needed with packed arrays
		return slots.size()
	if slots.size() < slot_capacity:
		return slots.size()
	return -1


static func _reindex_player_slots(player_slots: Array) -> void:
	for i in range(player_slots.size()):
		if typeof(player_slots[i]) == TYPE_DICTIONARY:
			player_slots[i]["slot_index"] = i


static func _clone_variant(value):
	if typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return value


static func _invalid_result(message: String) -> Dictionary:
	return {"is_valid": false, "errors": [message]}