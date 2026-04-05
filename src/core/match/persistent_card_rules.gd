class_name PersistentCardRules
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")

const PHASE_ACTION := "action"
const CARD_TYPE_CREATURE := "creature"
const CARD_TYPE_ITEM := "item"
const CARD_TYPE_SUPPORT := "support"
const ZONE_HAND := "hand"
const ZONE_LANE := "lane"
const ZONE_SUPPORT := "support"
const ZONE_ATTACHED_ITEM := "attached_item"


static func refresh_support_for_controller_turn(card: Dictionary) -> void:
	_ensure_support_state(card)
	card["activations_this_turn"] = 0


static func can_activate_support(match_state: Dictionary, player_id: String, instance_id: String) -> bool:
	return bool(validate_activate_support(match_state, player_id, instance_id).get("is_valid", false))


static func play_support_from_hand(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	GameLogger.trc("Persist", "play_support", "p:%s,id:%s" % [player_id, instance_id])
	var validation := _validate_hand_card(match_state, player_id, instance_id, CARD_TYPE_SUPPORT, "Support play", bool(options.get("played_for_free", false)))
	if not bool(validation.get("is_valid", false)):
		return validation
	var card: Dictionary = validation["card"]
	var play_cost := 0 if bool(options.get("played_for_free", false)) else get_effective_play_cost(match_state, player_id, card)
	if play_cost > 0:
		_spend_magicka(match_state, player_id, play_cost)
	_consume_cost_reduction(match_state, player_id)
	var moved := MatchMutations.move_card_to_zone(match_state, instance_id, ZONE_SUPPORT, {"target_player_id": player_id, "reason": str(options.get("reason", "play_support"))})
	if not bool(moved.get("is_valid", false)):
		return moved
	_ensure_support_state(card)
	var timing_result := MatchTiming.publish_events(match_state, [{
		"event_type": MatchTiming.EVENT_CARD_PLAYED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": player_id,
		"source_zone": ZONE_HAND,
		"target_zone": ZONE_SUPPORT,
		"card_type": CARD_TYPE_SUPPORT,
		"played_cost": int(card.get("cost", 0)),
		"played_for_free": bool(options.get("played_for_free", false)),
		"reason": str(options.get("reason", "play_support")),
	}])
	return {"is_valid": true, "errors": [], "card": card, "events": timing_result.get("processed_events", []), "trigger_resolutions": timing_result.get("trigger_resolutions", [])}


static func play_item_from_hand(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	GameLogger.trc("Persist", "play_item", "p:%s,id:%s" % [player_id, instance_id])
	var validation := _validate_hand_card(match_state, player_id, instance_id, CARD_TYPE_ITEM, "Item play", bool(options.get("played_for_free", false)))
	if not bool(validation.get("is_valid", false)):
		return validation
	var item_card: Dictionary = validation["card"]

	var target_card: Dictionary = {}
	var generated_events: Array = []
	var target_instance_id := str(options.get("target_instance_id", ""))
	if target_instance_id.is_empty():
		if not _card_has_mobilize(item_card):
			return _invalid_result("Items require a creature target unless Mobilize can create a Recruit.")
		var mobilize_lane := _select_mobilize_lane(match_state, player_id, str(options.get("lane_id", "")))
		if mobilize_lane.is_empty():
			return _invalid_result("Mobilize item play requires an empty friendly lane option.")
		var recruit_template := EvergreenRules.build_mobilize_recruit(player_id, "", str(item_card.get("definition_id", "")))
		var recruit := MatchMutations.build_generated_card(match_state, player_id, recruit_template)
		var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, recruit, str(mobilize_lane.get("lane_id", "")), {
			"slot_index": int(mobilize_lane.get("slot_index", -1)),
			"source_zone": MatchMutations.ZONE_GENERATED,
		})
		if not bool(summon_result.get("is_valid", false)):
			return summon_result
		target_card = summon_result["card"]
		target_instance_id = str(target_card.get("instance_id", ""))
		generated_events.append({
			"event_type": MatchTiming.EVENT_CREATURE_SUMMONED,
			"player_id": player_id,
			"playing_player_id": player_id,
			"source_instance_id": target_instance_id,
			"source_controller_player_id": player_id,
			"lane_id": str(mobilize_lane.get("lane_id", "")),
			"slot_index": int(mobilize_lane.get("slot_index", -1)),
			"reason": "mobilize",
		})
	else:
		var target_lookup := MatchMutations.find_card_location(match_state, target_instance_id)
		if not bool(target_lookup.get("is_valid", false)):
			return target_lookup
		target_card = target_lookup["card"]
		if str(target_lookup.get("zone", "")) != ZONE_LANE or str(target_card.get("card_type", "")) != CARD_TYPE_CREATURE:
			return _invalid_result("Items can only target creatures in a lane.")

	var play_cost := 0 if bool(options.get("played_for_free", false)) else get_effective_play_cost(match_state, player_id, item_card)

	# Check for throw-mode: item with on_play enemy damage ability targeting an enemy creature
	var is_throw := false
	var throw_ability := {}
	if not target_card.is_empty() and str(target_card.get("controller_player_id", "")) != player_id:
		for ta in item_card.get("triggered_abilities", []):
			if typeof(ta) == TYPE_DICTIONARY and str(ta.get("family", "")) == "on_play":
				var tm := str(ta.get("target_mode", ""))
				if tm == "enemy_creature_optional" or tm == "enemy_creature":
					is_throw = true
					throw_ability = ta
					break

	if play_cost > 0:
		_spend_magicka(match_state, player_id, play_cost)
	_consume_cost_reduction(match_state, player_id)

	if is_throw:
		# Throw mode: discard item and apply on_play effects to the target
		var player := _get_player_state(match_state, player_id)
		var hand: Array = player.get(ZONE_HAND, [])
		var hand_idx := -1
		for i in range(hand.size()):
			if typeof(hand[i]) == TYPE_DICTIONARY and str(hand[i].get("instance_id", "")) == instance_id:
				hand_idx = i
				break
		if hand_idx == -1:
			return _invalid_result("Item %s not found in hand." % instance_id)
		var thrown_card: Dictionary = hand[hand_idx]
		hand.remove_at(hand_idx)
		thrown_card["zone"] = "discard"
		player.get("discard", []).append(thrown_card)
		generated_events.append({
			"event_type": MatchTiming.EVENT_CARD_PLAYED,
			"playing_player_id": player_id,
			"player_id": player_id,
			"source_instance_id": instance_id,
			"source_controller_player_id": player_id,
			"source_zone": ZONE_HAND,
			"target_zone": "discard",
			"target_instance_id": target_instance_id,
			"card_type": CARD_TYPE_ITEM,
			"played_cost": int(item_card.get("cost", 0)),
			"played_for_free": bool(options.get("played_for_free", false)),
			"reason": "throw_item",
		})
		# Apply throw effects to the target creature
		for effect in throw_ability.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var op := str(effect.get("op", ""))
			if op == "deal_damage":
				var amount := int(effect.get("amount", 0))
				var damage_result := EvergreenRules.apply_damage_to_creature(target_card, amount)
				generated_events.append({
					"event_type": "creature_damaged",
					"source_instance_id": instance_id,
					"target_instance_id": target_instance_id,
					"amount": int(damage_result.get("applied", 0)),
					"player_id": player_id,
				})
			elif op == "shackle":
				EvergreenRules.add_status(target_card, EvergreenRules.STATUS_SHACKLED)
		var timing_result := MatchTiming.publish_events(match_state, generated_events)
		return {"is_valid": true, "errors": [], "card": thrown_card, "events": timing_result.get("processed_events", []), "trigger_resolutions": timing_result.get("trigger_resolutions", [])}

	var attach_result := MatchMutations.attach_item_to_creature(match_state, player_id, instance_id, target_instance_id, {"source_zone": ZONE_HAND})
	if not bool(attach_result.get("is_valid", false)):
		return attach_result
	generated_events.append({
		"event_type": MatchTiming.EVENT_CARD_PLAYED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": player_id,
		"source_zone": ZONE_HAND,
		"target_zone": ZONE_ATTACHED_ITEM,
		"target_instance_id": target_instance_id,
		"card_type": CARD_TYPE_ITEM,
		"played_cost": int(item_card.get("cost", 0)),
		"played_for_free": bool(options.get("played_for_free", false)),
		"reason": str(options.get("reason", "play_item")),
	})
	generated_events.append({
		"event_type": "card_equipped",
		"player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": str(attach_result["card"].get("controller_player_id", player_id)),
		"target_instance_id": target_instance_id,
	})
	var timing_result := MatchTiming.publish_events(match_state, generated_events)
	# Check for consume abilities on the played item (e.g., Bone Armor)
	MatchTiming._check_consume_abilities(match_state, attach_result["card"])
	# Check for on_play targeted abilities (e.g., Mace of Encumbrance shackle)
	_check_item_on_play_target_mode(match_state, attach_result["card"])
	# Process deferred item target checks (e.g., copies from Gardener of Swords)
	# so they queue AFTER the original item's targeting.
	_flush_deferred_item_target_checks(match_state)
	return {"is_valid": true, "errors": [], "card": attach_result["card"], "host": attach_result["host"], "events": timing_result.get("processed_events", []), "trigger_resolutions": timing_result.get("trigger_resolutions", [])}


static func validate_activate_support(match_state: Dictionary, player_id: String, instance_id: String) -> Dictionary:
	var owner_validation := _validate_action_owner(match_state, player_id, "Support activation")
	if not bool(owner_validation.get("is_valid", false)):
		return owner_validation
	var location := MatchMutations.find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	if str(location.get("zone", "")) != ZONE_SUPPORT:
		return _invalid_result("Support %s is not in the support zone." % instance_id)
	var card: Dictionary = location["card"]
	if str(card.get("card_type", "")) != CARD_TYPE_SUPPORT:
		return _invalid_result("Only support cards can be activated through support activation.")
	if str(card.get("controller_player_id", location.get("player_id", ""))) != player_id:
		return _invalid_result("Support %s is not controlled by %s." % [instance_id, player_id])
	_ensure_support_state(card)
	var max_activations := 1 + _count_extra_support_activations(match_state, player_id)
	if int(card.get("activations_this_turn", 0)) >= max_activations:
		return _invalid_result("Support has already been activated the maximum number of times this turn.")
	if card.has("remaining_support_uses") and card.get("remaining_support_uses") != null and int(card.get("remaining_support_uses", 0)) <= 0:
		if not _has_unlimited_support_uses(match_state, player_id):
			return _invalid_result("Support %s has no remaining uses." % instance_id)
	if not _has_activate_trigger(card):
		return _invalid_result("Support %s has no activate trigger descriptor." % instance_id)
	var activation_cost := int(card.get("activation_cost", 0))
	if activation_cost > _get_available_magicka(_get_player_state(match_state, player_id)):
		return _invalid_result("Player does not have enough magicka to activate support %s." % instance_id)
	return {"is_valid": true, "errors": [], "card": card}


static func activate_support(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	GameLogger.trc("Persist", "activate_support", "p:%s,id:%s" % [player_id, instance_id])
	var validation := validate_activate_support(match_state, player_id, instance_id)
	if not bool(validation.get("is_valid", false)):
		return validation
	var card: Dictionary = validation["card"]
	var activation_cost := int(card.get("activation_cost", 0))
	if activation_cost > 0:
		_spend_magicka(match_state, player_id, activation_cost)
	card["activations_this_turn"] = int(card.get("activations_this_turn", 0)) + 1
	var has_unlimited := _has_unlimited_support_uses(match_state, player_id)
	if card.has("remaining_support_uses") and card.get("remaining_support_uses") != null and not has_unlimited:
		card["remaining_support_uses"] = maxi(0, int(card.get("remaining_support_uses", 0)) - 1)
	var timing_result := MatchTiming.publish_events(match_state, [{
		"event_type": MatchTiming.EVENT_SUPPORT_ACTIVATED,
		"player_id": player_id,
		"playing_player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": player_id,
		"target_instance_id": str(options.get("target_instance_id", "")),
		"target_player_id": str(options.get("target_player_id", "")),
		"lane_id": str(options.get("lane_id", "")),
		"activation_cost": activation_cost,
	}])
	var processed_events: Array = timing_result.get("processed_events", []).duplicate(true)
	var trigger_resolutions: Array = timing_result.get("trigger_resolutions", []).duplicate(true)
	if card.has("remaining_support_uses") and card.get("remaining_support_uses") != null and int(card.get("remaining_support_uses", 0)) == 0 and not has_unlimited:
		var exhaustion_events := [{
			"event_type": "support_uses_exhausted",
			"player_id": player_id,
			"source_instance_id": instance_id,
			"remaining_uses": 0,
		}]
		var toe_template = card.get("transform_on_exhausted", null)
		if typeof(toe_template) == TYPE_DICTIONARY and not toe_template.is_empty():
			# Transform the support into the specified card instead of discarding it
			var transform_result := MatchMutations.transform_card(match_state, instance_id, toe_template, {"reason": "support_exhausted_transform"})
			exhaustion_events.append_array(transform_result.get("events", []))
			var transformed_card: Dictionary = transform_result.get("card", card)
			MatchMutations.restore_definition_state(transformed_card)
			transformed_card.erase("remaining_support_uses")
			transformed_card.erase("transform_on_exhausted")
			_ensure_support_state(transformed_card)
			transformed_card["activations_this_turn"] = 0
		else:
			var discard_result := MatchMutations.discard_card(match_state, instance_id, {"reason": "support_uses_exhausted"})
			exhaustion_events.append_array(discard_result.get("events", []))
			# Fire Last Gasp triggers on the support (they listen for creature_destroyed
			# which is never emitted for supports, so resolve them manually).
			var raw_triggers = card.get("triggered_abilities", [])
			if typeof(raw_triggers) == TYPE_ARRAY:
				for raw_trigger in raw_triggers:
					if typeof(raw_trigger) != TYPE_DICTIONARY:
						continue
					if str(raw_trigger.get("family", "")) != MatchTiming.FAMILY_LAST_GASP:
						continue
					var fake_trigger := {
						"trigger_id": instance_id + "_support_last_gasp",
						"source_instance_id": instance_id,
						"controller_player_id": player_id,
						"owner_player_id": str(card.get("owner_player_id", player_id)),
						"source_zone": "support",
						"descriptor": raw_trigger.duplicate(true),
					}
					var fake_event := {
						"event_type": MatchTiming.EVENT_CREATURE_DESTROYED,
						"instance_id": instance_id,
						"source_instance_id": instance_id,
						"controller_player_id": player_id,
					}
					var lg_resolution := MatchTiming._build_trigger_resolution(match_state, fake_trigger, fake_event)
					exhaustion_events.append_array(MatchTiming._apply_effects(match_state, fake_trigger, fake_event, lg_resolution))
		var exhaustion_timing := MatchTiming.publish_events(match_state, exhaustion_events)
		processed_events.append_array(exhaustion_timing.get("processed_events", []))
		trigger_resolutions.append_array(exhaustion_timing.get("trigger_resolutions", []))
	return {"is_valid": true, "errors": [], "card": card, "events": processed_events, "trigger_resolutions": trigger_resolutions}


static func _validate_hand_card(match_state: Dictionary, player_id: String, instance_id: String, expected_type: String, action_name: String, played_for_free: bool) -> Dictionary:
	var owner_validation := _validate_action_owner(match_state, player_id, action_name)
	if not bool(owner_validation.get("is_valid", false)):
		return owner_validation
	var location := MatchMutations.find_card_location(match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return location
	if str(location.get("player_id", "")) != player_id or str(location.get("zone", "")) != ZONE_HAND:
		return _invalid_result("Card %s is not in %s's hand." % [instance_id, player_id])
	var card: Dictionary = location["card"]
	if str(card.get("card_type", "")) != expected_type:
		return _invalid_result("Card %s is not a %s." % [instance_id, expected_type])
	if not played_for_free and get_effective_play_cost(match_state, player_id, card) > _get_available_magicka(_get_player_state(match_state, player_id)):
		return _invalid_result("Player does not have enough magicka to play %s." % instance_id)
	if not played_for_free:
		var card_cost := get_effective_play_cost(match_state, player_id, card)
		var player_state := _get_player_state(match_state, player_id)
		var cost_locks: Array = player_state.get("cost_locks", [])
		for lock in cost_locks:
			if typeof(lock) == TYPE_DICTIONARY and int(lock.get("cost", -1)) == card_cost:
				return _invalid_result("Cannot play cards with cost %d." % card_cost)
	return {"is_valid": true, "errors": [], "card": card}


static func _validate_action_owner(match_state: Dictionary, player_id: String, action_name: String) -> Dictionary:
	if match_state.get("phase", "") != PHASE_ACTION:
		return _invalid_result("%s can only be used during the action phase." % action_name)
	if str(match_state.get("active_player_id", "")) != player_id:
		return _invalid_result("%s is only legal for the active player." % action_name)
	if _get_player_state(match_state, player_id).is_empty():
		return _invalid_result("Unknown player_id: %s" % player_id)
	return {"is_valid": true, "errors": []}


static func _card_has_mobilize(card: Dictionary) -> bool:
	return EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_MOBILIZE)


static func _select_mobilize_lane(match_state: Dictionary, player_id: String, requested_lane_id: String) -> Dictionary:
	var options := EvergreenRules.get_mobilize_lane_options(match_state, player_id)
	if options.is_empty():
		return {}
	if requested_lane_id.is_empty() and options.size() == 1:
		return options[0]
	for option in options:
		if str(option.get("lane_id", "")) == requested_lane_id:
			return option
	return {}


static func _has_activate_trigger(card: Dictionary) -> bool:
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) == TYPE_DICTIONARY and str(trigger.get("family", "")) == MatchTiming.FAMILY_ACTIVATE:
			return true
	return false


static func _ensure_support_state(card: Dictionary) -> void:
	EvergreenRules.ensure_card_state(card)
	if not card.has("activations_this_turn"):
		card["activations_this_turn"] = 0
	if not card.has("remaining_support_uses"):
		var su = card.get("support_uses", null)
		card["remaining_support_uses"] = null if (su == null or int(su) == 0) else int(su)


static func _count_extra_support_activations(match_state: Dictionary, player_id: String) -> int:
	var count := 0
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "hos_wil_cauldron_keeper":
				count += 1
	return count


static func _get_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func get_effective_play_cost(match_state: Dictionary, player_id: String, card: Dictionary) -> int:
	var base_cost := int(card.get("cost", 0))
	var player := _get_player_state(match_state, player_id)
	var reduction := int(player.get("next_card_cost_reduction", 0))
	reduction += _get_aura_cost_reduction(match_state, player_id, card)
	var self_reduction = card.get("self_cost_reduction", {})
	if typeof(self_reduction) == TYPE_DICTIONARY and not self_reduction.is_empty():
		var per_source := str(self_reduction.get("per", self_reduction.get("type", self_reduction.get("source", ""))))
		var per_amount := int(self_reduction.get("amount", self_reduction.get("amount_per", 1)))
		# Handle single-key format: {"per_friendly_wounded": 3} → source="per_friendly_wounded", amount=3
		if per_source.is_empty():
			for key in self_reduction.keys():
				if key != "amount" and key != "amount_per" and key != "per" and key != "type" and key != "source":
					per_source = key
					per_amount = int(self_reduction.get(key, 1))
					break
		if per_source == "creature_summons_this_turn":
			reduction += int(player.get("creature_summons_this_turn", 0)) * per_amount
		elif per_source == "creatures_died_this_turn":
			reduction += int(player.get("creatures_died_this_turn", 0)) * per_amount
		elif per_source == "empower":
			var empower_total := int(player.get("empower_count_this_turn", 0)) + int(player.get("_permanent_empower_accumulated", 0))
			reduction += empower_total * per_amount
		elif per_source == "per_action_played_this_turn":
			reduction += int(player.get("noncreature_plays_this_turn", 0)) * per_amount
		elif per_source == "per_friendly_wounded":
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(player_id, []):
					if typeof(c) == TYPE_DICTIONARY and int(c.get("damage_marked", 0)) > 0:
						reduction += per_amount
		elif per_source == "per_friendly_creature_min_health_5":
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(player_id, []):
					if typeof(c) == TYPE_DICTIONARY and EvergreenRules.get_remaining_health(c) >= 5:
						reduction += per_amount
		elif per_source == "per_pilfer_or_drain_this_turn":
			reduction += int(player.get("pilfer_or_drain_count_this_turn", 0)) * per_amount
		elif per_source == "per_creature_in_discard":
			for c in player.get("discard", []):
				if typeof(c) == TYPE_DICTIONARY and str(c.get("card_type", "")) == "creature":
					reduction += per_amount
		elif per_source == "per_attribute_in_play":
			var seen_attrs: Dictionary = {}
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(player_id, []):
					if typeof(c) != TYPE_DICTIONARY:
						continue
					for attr in c.get("attributes", []):
						if not seen_attrs.has(str(attr)):
							seen_attrs[str(attr)] = true
			reduction += seen_attrs.size() * per_amount
		elif per_source == "if_neutral_in_play":
			var has_neutral := false
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(player_id, []):
					if typeof(c) == TYPE_DICTIONARY:
						for attr in c.get("attributes", []):
							if str(attr) == "neutral":
								has_neutral = true
			if has_neutral:
				reduction += per_amount
		elif per_source == "per_opponent_undead":
			var opp_id := ""
			for p in match_state.get("players", []):
				if str(p.get("player_id", "")) != player_id:
					opp_id = str(p.get("player_id", ""))
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(opp_id, []):
					if typeof(c) == TYPE_DICTIONARY:
						var subtypes = c.get("subtypes", [])
						if typeof(subtypes) == TYPE_ARRAY:
							for st in subtypes:
								if str(st) == "Skeleton" or str(st) == "Vampire" or str(st) == "Spirit" or str(st) == "Mummy":
									reduction += per_amount
									break
		elif per_source == "per_dragon_in_discard":
			for c in player.get("discard", []):
				if typeof(c) == TYPE_DICTIONARY and str(c.get("card_type", "")) == "creature":
					var subtypes = c.get("subtypes", [])
					if typeof(subtypes) == TYPE_ARRAY:
						for st in subtypes:
							if str(st) == "Dragon":
								reduction += per_amount
								break
		elif per_source == "unique_creatures_in_discard":
			var seen_defs: Dictionary = {}
			for c in player.get("discard", []):
				if typeof(c) == TYPE_DICTIONARY and str(c.get("card_type", "")) == "creature":
					var def_id := str(c.get("definition_id", ""))
					if not seen_defs.has(def_id):
						seen_defs[def_id] = true
			reduction += seen_defs.size() * per_amount
	# First Lesson boon: first action each turn costs N less (read-only for display)
	if str(card.get("card_type", "")) == "action":
		var first_lesson_discount := int(player.get("_first_lesson_discount", 0))
		if first_lesson_discount > 0:
			reduction += first_lesson_discount
	# Library lane: actions cost 1 less while player has a creature in a library lane
	if str(card.get("card_type", "")) == "action":
		for lane in match_state.get("lanes", []):
			var lane_payload: Dictionary = lane.get("lane_rule_payload", {})
			var lane_effects: Array = lane_payload.get("effects", [])
			for le in lane_effects:
				if typeof(le) != TYPE_DICTIONARY:
					continue
				for le_eff in le.get("effects", []):
					if typeof(le_eff) == TYPE_DICTIONARY and str(le_eff.get("op", "")) == "lane_library_reduce_action_cost":
						var slot_array: Array = lane.get("player_slots", {}).get(player_id, [])
						if not slot_array.is_empty():
							reduction += int(le_eff.get("amount", 1))
						break
	var effective := maxi(0, base_cost - reduction)
	# min_card_cost passive: all cards cost at least N
	var min_cost := _get_min_card_cost(match_state)
	if min_cost > 0 and effective < min_cost:
		effective = min_cost
	return effective


static func _get_min_card_cost(match_state: Dictionary) -> int:
	var result := 0
	for lane in match_state.get("lanes", []):
		for pid in lane.get("player_slots", {}).keys():
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var passives = card.get("passive_abilities", [])
				if typeof(passives) != TYPE_ARRAY:
					continue
				for p in passives:
					if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "min_card_cost":
						result = maxi(result, int(p.get("min_cost", 3)))
	return result


static func _get_aura_cost_reduction(match_state: Dictionary, player_id: String, card: Dictionary) -> int:
	var total := 0
	var card_type := str(card.get("card_type", ""))
	var all_aura_sources: Array = []
	for lane in match_state.get("lanes", []):
		for lane_card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(lane_card) != TYPE_DICTIONARY:
				continue
			var aura = lane_card.get("cost_reduction_aura", {})
			if typeof(aura) == TYPE_DICTIONARY and not aura.is_empty():
				all_aura_sources.append(aura)
	for support_card in _get_player_state(match_state, player_id).get("support", []):
		if typeof(support_card) != TYPE_DICTIONARY:
			continue
		var aura = support_card.get("cost_reduction_aura", {})
		if typeof(aura) == TYPE_DICTIONARY and not aura.is_empty():
			all_aura_sources.append(aura)
	for aura in all_aura_sources:
		var required_type := str(aura.get("card_type", ""))
		if not required_type.is_empty() and card_type != required_type:
			continue
		var condition := str(aura.get("condition", ""))
		if not condition.is_empty():
			if not _cost_reduction_condition_met(match_state, player_id, card, condition, aura):
				continue
		var aura_filter_subtype := str(aura.get("filter_subtype", ""))
		if not aura_filter_subtype.is_empty():
			var card_subtypes = card.get("subtypes", [])
			if typeof(card_subtypes) != TYPE_ARRAY or not card_subtypes.has(aura_filter_subtype):
				continue
		if aura.get("filter_unique", false) and not card.get("is_unique", false):
			continue
		var aura_filter_card_type := str(aura.get("filter_card_type", ""))
		if not aura_filter_card_type.is_empty() and card_type != aura_filter_card_type:
			continue
		if aura.get("filter_deals_damage", false):
			if not _cost_reduction_condition_met(match_state, player_id, card, "filter_deals_damage", aura):
				continue
		if aura.get("filter_min_power", 0) is int and int(aura.get("filter_min_power", 0)) > 0:
			if not _cost_reduction_condition_met(match_state, player_id, card, "filter_min_power", aura):
				continue
		if aura.get("filter_not_in_starting_deck", false):
			if not _cost_reduction_condition_met(match_state, player_id, card, "filter_not_in_starting_deck", aura):
				continue
		if aura.get("required_singleton_deck", false):
			if not _cost_reduction_condition_met(match_state, player_id, card, "required_singleton_deck", aura):
				continue
		total += int(aura.get("amount", 0))
	# Match-state-level cost reduction auras (e.g. Oblivion Gate Daedra discount)
	for ms_aura in match_state.get("card_cost_reduction_auras", []):
		if str(ms_aura.get("controller_player_id", "")) != player_id:
			continue
		var ms_filter_subtype := str(ms_aura.get("filter_subtype", ""))
		if not ms_filter_subtype.is_empty():
			var card_subtypes = card.get("subtypes", [])
			if typeof(card_subtypes) != TYPE_ARRAY or not card_subtypes.has(ms_filter_subtype):
				continue
		total += int(ms_aura.get("amount", 0))
	total -= _get_global_cost_increase(match_state, card_type)
	return total


static func _cost_reduction_condition_met(match_state: Dictionary, player_id: String, card: Dictionary, condition: String, aura: Dictionary) -> bool:
	match condition:
		"creature_in_each_lane":
			for lane in match_state.get("lanes", []):
				var slots: Array = lane.get("player_slots", {}).get(player_id, [])
				if slots.is_empty():
					return false
			return true
		"required_singleton_deck":
			return bool(_get_player_state(match_state, player_id).get("_singleton_deck", false))
		"filter_deals_damage":
			if str(card.get("card_type", "")) != "action":
				return false
			var effect_ids = card.get("effect_ids", [])
			return typeof(effect_ids) == TYPE_ARRAY and (effect_ids.has("damage") or effect_ids.has("deal_damage"))
		"filter_min_power":
			var min_power := int(aura.get("filter_min_power", aura.get("min_power", 5)))
			return EvergreenRules.get_power(card) >= min_power
		"filter_not_in_starting_deck":
			return bool(card.get("_not_in_starting_deck", false))
	return true


static func _get_global_cost_increase(match_state: Dictionary, card_type: String) -> int:
	var total := 0
	for lane in match_state.get("lanes", []):
		for pid in lane.get("player_slots", {}).keys():
			for lane_card in lane["player_slots"][pid]:
				if typeof(lane_card) != TYPE_DICTIONARY:
					continue
				var aura = lane_card.get("cost_increase_aura", {})
				if typeof(aura) != TYPE_DICTIONARY or aura.is_empty():
					continue
				var required_type := str(aura.get("card_type", ""))
				if not required_type.is_empty() and card_type != required_type:
					continue
				total += int(aura.get("amount", 0))
	return total


static func get_play_limit_per_turn(match_state: Dictionary, player_id: String) -> int:
	var limit := -1  # -1 = no limit
	var player := _get_player_state(match_state, player_id)
	for support_card in player.get("support", []):
		if typeof(support_card) != TYPE_DICTIONARY:
			continue
		var pl := int(support_card.get("play_limit_per_turn", -1))
		if pl >= 0 and (limit < 0 or pl < limit):
			limit = pl
	return limit


static func _has_unlimited_support_uses(match_state: Dictionary, player_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and EvergreenRules.has_status(card, "unlimited_support_uses"):
				return true
	return false


static func _consume_cost_reduction(match_state: Dictionary, player_id: String) -> void:
	var player := _get_player_state(match_state, player_id)
	if int(player.get("next_card_cost_reduction", 0)) > 0:
		player["next_card_cost_reduction"] = 0


static func _get_available_magicka(player: Dictionary) -> int:
	return maxi(0, int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0)))


static func _spend_magicka(match_state: Dictionary, player_id: String, amount: int) -> void:
	var player := _get_player_state(match_state, player_id)
	var remaining := amount
	var temporary_magicka := int(player.get("temporary_magicka", 0))
	if temporary_magicka > 0:
		var temporary_spent := mini(temporary_magicka, remaining)
		player["temporary_magicka"] = temporary_magicka - temporary_spent
		remaining -= temporary_spent
	if remaining > 0:
		player["current_magicka"] = maxi(0, int(player.get("current_magicka", 0)) - remaining)


static func _check_item_on_play_target_mode(match_state: Dictionary, item_card: Dictionary) -> void:
	var controller_id := str(item_card.get("controller_player_id", ""))
	var instance_id := str(item_card.get("instance_id", ""))
	var raw_triggers = item_card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY:
		return
	var on_play_abilities: Array = []
	for ab in raw_triggers:
		if typeof(ab) != TYPE_DICTIONARY:
			continue
		if str(ab.get("family", "")) != "on_play":
			continue
		if str(ab.get("target_mode", "")).is_empty():
			continue
		on_play_abilities.append(ab)
	if on_play_abilities.is_empty():
		return
	var valid := MatchTiming.get_all_valid_targets(match_state, instance_id)
	if valid.is_empty():
		return
	var pending_arr: Array = match_state.get("pending_summon_effect_targets", [])
	pending_arr.append({
		"player_id": controller_id,
		"source_instance_id": instance_id,
		"mandatory": true,
		"allowed_families": ["on_play"],
	})


static func _flush_deferred_item_target_checks(match_state: Dictionary) -> void:
	var deferred: Array = match_state.get("_deferred_item_target_checks", [])
	if deferred.is_empty():
		return
	match_state["_deferred_item_target_checks"] = []
	for item_card in deferred:
		if typeof(item_card) == TYPE_DICTIONARY:
			_check_item_on_play_target_mode(match_state, item_card)


static func _invalid_result(message: String) -> Dictionary:
	return {"is_valid": false, "errors": [message]}
