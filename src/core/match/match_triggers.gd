class_name MatchTriggers
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")
const MatchEffectParams = preload("res://src/core/match/match_effect_params.gd")
const BoonRules = preload("res://src/adventure/boon_rules.gd")
const LaneEffectRules = preload("res://src/core/match/lane_effect_rules.gd")
const MatchTargeting = preload("res://src/core/match/match_targeting.gd")

const ZONE_HAND := "hand"
const ZONE_DECK := "deck"
const ZONE_LANE := "lane"
const ZONE_SUPPORT := "support"
const ZONE_DISCARD := "discard"
const ZONE_BANISHED := "banished"
const ZONE_GENERATED := "generated"

const WINDOW_INTERRUPT := "interrupt"
const WINDOW_IMMEDIATE := "immediate"
const WINDOW_AFTER := "after"

const EVENT_DAMAGE_RESOLVED := "damage_resolved"

const FAMILY_ON_PLAY := "on_play"
const FAMILY_ACTIVATE := "activate"
const FAMILY_SUMMON := "summon"
const FAMILY_END_OF_TURN := "end_of_turn"
const FAMILY_EXPERTISE := "expertise"
const FAMILY_SLAY := "slay"
const FAMILY_VETERAN := "veteran"
const FAMILY_ITEM_DETACHED := "item_detached"
const FAMILY_WAX := "wax"
const FAMILY_WANE := "wane"

const PLAYER_ZONE_ORDER := [ZONE_HAND, ZONE_SUPPORT, ZONE_DISCARD, ZONE_BANISHED, ZONE_DECK]
const ZONE_PRIORITY := {
	ZONE_LANE: 0,
	"support": 1,
	ZONE_HAND: 2,
	ZONE_DISCARD: 3,
	ZONE_BANISHED: 4,
	ZONE_DECK: 5,
	ZONE_GENERATED: 6,
	"": 9,
}

static func _get_family_specs() -> Dictionary:
	return load("res://src/core/match/match_timing.gd").FAMILY_SPECS


static func rebuild_trigger_registry(match_state: Dictionary) -> Array:
	load("res://src/core/match/match_timing.gd").ensure_match_state(match_state)
	var registry: Array = []
	var current_turn := int(match_state.get("turn_number", -1))
	var players: Array = match_state.get("players", [])
	for player in players:
		var player_id := str(player.get("player_id", ""))
		for zone_name in PLAYER_ZONE_ORDER:
			var cards = player.get(zone_name, [])
			if typeof(cards) != TYPE_ARRAY:
				continue
			for card in cards:
				_append_card_triggers(registry, card, zone_name, player_id, -1, -1, current_turn)
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots = player_slots_by_id[player_id]
			if typeof(slots) != TYPE_ARRAY:
				continue
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				_append_card_triggers(registry, card, ZONE_LANE, str(player_id), lane_index, slot_index, current_turn)
				if typeof(card) == TYPE_DICTIONARY:
					for attached_item in card.get("attached_items", []):
						_append_card_triggers(registry, attached_item, ZONE_LANE, str(player_id), lane_index, slot_index, current_turn)
	_inject_granted_triggers(match_state, registry, lanes)
	# copy_expertise_abilities: Master of Incunabula copies all friendly expertise triggers
	_inject_copied_expertise_triggers(registry, lanes)
	# Inject virtual triggers for active adventure boons
	BoonRules.inject_boon_triggers(match_state, registry)
	# Inject virtual triggers for lane effects
	LaneEffectRules.inject_lane_triggers(match_state, registry)
	match_state["trigger_registry"] = registry.duplicate(true)
	return registry


static func _inject_copied_expertise_triggers(registry: Array, lanes: Array) -> void:
	# Find creatures with copy_expertise_abilities passive
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		for player_id in lane.get("player_slots", {}).keys():
			var slots: Array = lane.get("player_slots", {}).get(player_id, [])
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not EvergreenRules._has_passive(card, "copy_expertise_abilities"):
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				var copier_id := str(card.get("instance_id", ""))
				var copier_controller := str(card.get("controller_player_id", player_id))
				# Collect expertise triggers from all other friendly creatures
				for ce_lane_index in range(lanes.size()):
					for ce_card in lanes[ce_lane_index].get("player_slots", {}).get(copier_controller, []):
						if typeof(ce_card) != TYPE_DICTIONARY:
							continue
						if str(ce_card.get("instance_id", "")) == copier_id:
							continue
						var ce_triggers = ce_card.get("triggered_abilities", [])
						if typeof(ce_triggers) != TYPE_ARRAY:
							continue
						for ce_idx in range(ce_triggers.size()):
							var ce_trigger = ce_triggers[ce_idx]
							if typeof(ce_trigger) != TYPE_DICTIONARY:
								continue
							if str(ce_trigger.get("family", "")) != FAMILY_EXPERTISE:
								continue
							registry.append({
								"trigger_id": "%s_copied_expertise_%s_%d" % [copier_id, str(ce_card.get("instance_id", "")), ce_idx],
								"trigger_index": -1,
								"source_instance_id": copier_id,
								"owner_player_id": copier_controller,
								"controller_player_id": copier_controller,
								"source_zone": ZONE_LANE,
								"lane_index": lane_index,
								"slot_index": slot_index,
								"descriptor": ce_trigger.duplicate(true),
							})


static func _inject_granted_triggers(match_state: Dictionary, registry: Array, lanes: Array) -> void:
	for player in match_state.get("players", []):
		var player_id := str(player.get("player_id", ""))
		var granted_triggers: Array = []
		for support_card in player.get(ZONE_SUPPORT, []):
			if typeof(support_card) != TYPE_DICTIONARY:
				continue
			if EvergreenRules.has_raw_status(support_card, EvergreenRules.STATUS_SILENCED):
				continue
			var grants = support_card.get("grants_trigger", [])
			if typeof(grants) != TYPE_ARRAY:
				continue
			for grant in grants:
				if typeof(grant) == TYPE_DICTIONARY:
					granted_triggers.append(grant)
		for lane in lanes:
			for lane_card in lane.get("player_slots", {}).get(player_id, []):
				if typeof(lane_card) != TYPE_DICTIONARY:
					continue
				if EvergreenRules.has_raw_status(lane_card, EvergreenRules.STATUS_SILENCED):
					continue
				var grants = lane_card.get("grants_trigger", [])
				if typeof(grants) != TYPE_ARRAY:
					continue
				for grant in grants:
					if typeof(grant) == TYPE_DICTIONARY:
						granted_triggers.append(grant)
		if granted_triggers.is_empty():
			continue
		for lane_index in range(lanes.size()):
			var lane: Dictionary = lanes[lane_index]
			var slots = lane.get("player_slots", {}).get(player_id, [])
			if typeof(slots) != TYPE_ARRAY:
				continue
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var instance_id := str(card.get("instance_id", ""))
				for g_index in range(granted_triggers.size()):
					var descriptor: Dictionary = granted_triggers[g_index].duplicate(true)
					if not str(descriptor.get("target_mode", "")).is_empty():
						continue
					var required_keyword := str(descriptor.get("required_keyword", ""))
					if not required_keyword.is_empty() and not _card_has_keyword_or_family(card, required_keyword, granted_triggers):
						continue
					registry.append({
						"trigger_id": "%s_granted_%d" % [instance_id, g_index],
						"trigger_index": -1,
						"source_instance_id": instance_id,
						"owner_player_id": str(card.get("owner_player_id", player_id)),
						"controller_player_id": str(card.get("controller_player_id", player_id)),
						"source_zone": ZONE_LANE,
						"lane_index": lane_index,
						"slot_index": slot_index,
						"descriptor": descriptor,
					})


static func _card_has_keyword_or_family(card: Dictionary, keyword: String, granted_triggers: Array) -> bool:
	if EvergreenRules.has_keyword(card, keyword):
		return true
	# Check native triggered abilities for matching family (e.g. "pilfer")
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) == TYPE_ARRAY:
		for t in raw_triggers:
			if typeof(t) == TYPE_DICTIONARY and str(t.get("family", "")) == keyword:
				return true
	# Check if any granted trigger gives this card the required family
	for gt in granted_triggers:
		if typeof(gt) != TYPE_DICTIONARY:
			continue
		if str(gt.get("family", "")) != keyword:
			continue
		var gt_req := str(gt.get("required_keyword", ""))
		if gt_req.is_empty() or EvergreenRules.has_keyword(card, gt_req):
			return true
	return false


static func _append_card_triggers(registry: Array, card, zone_name: String, controller_player_id: String, lane_index := -1, slot_index := -1, current_turn := -1) -> void:
	if typeof(card) != TYPE_DICTIONARY:
		return
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY or raw_triggers.is_empty():
		return
	for trigger_index in range(raw_triggers.size()):
		var raw_trigger = raw_triggers[trigger_index]
		if typeof(raw_trigger) != TYPE_DICTIONARY:
			continue
		var descriptor: Dictionary = raw_trigger
		if not bool(descriptor.get("enabled", true)):
			continue
		if current_turn >= 0 and descriptor.has("expires_on_turn") and int(descriptor.get("expires_on_turn", -1)) < current_turn:
			continue
		if current_turn >= 0 and descriptor.has("_expires_on_turn") and int(descriptor.get("_expires_on_turn", -1)) < current_turn:
			continue
		if not str(descriptor.get("target_mode", "")).is_empty():
			var tm_family := str(descriptor.get("family", ""))
			var tm_mode := str(descriptor.get("target_mode", ""))
			# summon/wax/wane/end_of_turn/expertise/slay triggers with target_mode are resolved via pending systems;
			# on_play with multi-target modes (two_creatures, three_creatures) also use pending;
			# activate/on_play inject targets from the event; all other families auto-resolve
			# a random valid target in _trigger_matches_event().
			if tm_family == FAMILY_SUMMON or tm_family == FAMILY_WAX or tm_family == FAMILY_WANE or tm_family == FAMILY_END_OF_TURN or tm_family == FAMILY_EXPERTISE or tm_family == FAMILY_SLAY:
				continue
			if tm_family == FAMILY_ON_PLAY and (tm_mode == "two_creatures" or tm_mode == "three_creatures"):
				continue
			if tm_family == FAMILY_ON_PLAY and not str(descriptor.get("secondary_target_mode", "")).is_empty():
				continue
			# Item on_play triggers with target_mode use pending system (equip target != ability target)
			if tm_family == FAMILY_ON_PLAY and str(card.get("card_type", "")) == "item":
				continue
		if bool(descriptor.get("consume", false)):
			var consume_family := str(descriptor.get("family", ""))
			if consume_family == FAMILY_SUMMON or consume_family == "on_play":
				continue  # Consume triggers resolved via pending_consume_selections
		var instance_id := str(card.get("instance_id", ""))
		var trigger_id := str(descriptor.get("id", "%s_trigger_%d" % [instance_id, trigger_index]))
		registry.append({
			"trigger_id": trigger_id,
			"trigger_index": trigger_index,
			"source_instance_id": instance_id,
			"owner_player_id": str(card.get("owner_player_id", controller_player_id)),
			"controller_player_id": str(card.get("controller_player_id", controller_player_id)),
			"source_zone": zone_name,
			"lane_index": lane_index,
			"slot_index": slot_index,
			"descriptor": descriptor.duplicate(true),
		})


static func _find_matching_triggers(match_state: Dictionary, event: Dictionary) -> Array:
	var matches: Array = []
	for trigger in rebuild_trigger_registry(match_state):
		if not _trigger_matches_event(match_state, trigger, event):
			continue
		trigger["sort_key"] = _build_trigger_sort_key(match_state, trigger)
		_insert_sorted_trigger(matches, trigger)
	return matches


static func _trigger_matches_event(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> bool:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	if descriptor.is_empty():
		return false
	if _is_once_trigger_consumed(match_state, trigger):
		return false
	if not _matches_required_zone(trigger, descriptor):
		return false
	# Triggers with target_mode need a target before they can fire.
	# activate/on_play: target injected from the event (UI passes target_instance_id).
	# All other families: auto-pick a random valid target so the ability fires.
	if not str(descriptor.get("target_mode", "")).is_empty() and str(trigger.get("_chosen_target_id", "")).is_empty() and str(trigger.get("_chosen_target_player_id", "")).is_empty():
		var inject_family := str(descriptor.get("family", ""))
		if inject_family == FAMILY_ACTIVATE or inject_family == FAMILY_ON_PLAY:
			var evt_target := str(event.get("target_instance_id", ""))
			var evt_player := str(event.get("target_player_id", ""))
			if not evt_target.is_empty():
				trigger["_chosen_target_id"] = evt_target
			elif not evt_player.is_empty():
				trigger["_chosen_target_player_id"] = evt_player
			else:
				return false
		else:
			var source_id := str(trigger.get("source_instance_id", ""))
			var tm := str(descriptor.get("target_mode", ""))
			var valid_targets := MatchTargeting.get_valid_targets_for_mode(match_state, source_id, tm, trigger)
			if valid_targets.is_empty():
				return false
			var ctx_id := source_id + "_auto_target_" + inject_family
			var chosen: Dictionary = valid_targets[MatchEffectParams._deterministic_index(match_state, ctx_id, valid_targets.size())]
			var chosen_id := str(chosen.get("instance_id", ""))
			var chosen_pid := str(chosen.get("player_id", ""))
			if not chosen_id.is_empty():
				trigger["_chosen_target_id"] = chosen_id
			elif not chosen_pid.is_empty():
				trigger["_chosen_target_player_id"] = chosen_pid
			else:
				return false
	var event_type := str(event.get("event_type", ""))
	var family := str(descriptor.get("family", ""))
	var family_spec: Dictionary = _get_family_specs().get(family, {})
	var expected_event_type := str(descriptor.get("event_type", family_spec.get("event_type", "")))
	if family == FAMILY_ITEM_DETACHED and event_type == "attached_item_detached":
		GameLogger.trc("Timing", "item_detach_match", "src:%s,evt_src:%s,zone:%s,expected_evt:%s" % [str(trigger.get("source_instance_id", "")), str(event.get("source_instance_id", "")), str(trigger.get("source_zone", "")), expected_event_type])
	if event_type != expected_event_type:
		# pilfer_is_slay: slay triggers also fire on pilfer events
		if family == FAMILY_SLAY and event_type == EVENT_DAMAGE_RESOLVED and str(event.get("target_type", "")) == "player" and int(event.get("amount", 0)) > 0:
			var pis_source_id := str(trigger.get("source_instance_id", ""))
			if str(event.get("source_instance_id", "")) == pis_source_id:
				var pis_controller := str(trigger.get("controller_player_id", ""))
				if _has_pilfer_is_slay_active(match_state, pis_controller):
					return _matches_conditions(match_state, trigger, descriptor, family_spec, event)
		return false
	if not _matches_trigger_role(match_state, trigger, descriptor, family_spec, event):
		if family == FAMILY_ITEM_DETACHED:
			GameLogger.trc("Timing", "item_detach_role_fail", "src:%s,evt_src:%s" % [str(trigger.get("source_instance_id", "")), str(event.get("source_instance_id", ""))])
		return false
	if family == FAMILY_ITEM_DETACHED:
		GameLogger.trc("Timing", "item_detach_role_pass", "src:%s" % str(trigger.get("source_instance_id", "")))
	return _matches_conditions(match_state, trigger, descriptor, family_spec, event)


static func _has_pilfer_is_slay_active(match_state: Dictionary, controller_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(controller_id, []):
			if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "pilfer_is_slay"):
				return true
	for support in MatchTimingHelpers._get_player_state(match_state, controller_id).get("support", []):
		if typeof(support) == TYPE_DICTIONARY and EvergreenRules._has_passive(support, "pilfer_is_slay"):
			return true
	return false


static func _has_double_max_magicka_gain(match_state: Dictionary, player_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and bool(card.get("_double_max_magicka_gain", false)):
				return true
	return false


static func _matches_required_zone(trigger: Dictionary, descriptor: Dictionary) -> bool:
	if descriptor.has("required_zone"):
		var required := str(descriptor.get("required_zone", ""))
		var actual := str(trigger.get("source_zone", ""))
		if required == actual:
			return true
		# Slay triggers fire even if the creature just died (moved from lane to discard in same combat)
		if required == ZONE_LANE and actual == ZONE_DISCARD and str(descriptor.get("family", "")) == FAMILY_SLAY:
			return true
		return false
	var required_zones = descriptor.get("required_zones", [])
	if typeof(required_zones) == TYPE_ARRAY and not required_zones.is_empty():
		return required_zones.has(str(trigger.get("source_zone", "")))
	return true


static func _matches_trigger_role(match_state: Dictionary, trigger: Dictionary, descriptor: Dictionary, family_spec: Dictionary, event: Dictionary) -> bool:
	var source_instance_id := str(trigger.get("source_instance_id", ""))
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var role := str(descriptor.get("match_role", family_spec.get("match_role", "source")))
	match role:
		"controller":
			return str(event.get("player_id", event.get("playing_player_id", event.get("controller_player_id", event.get("source_controller_player_id", ""))))) == controller_player_id
		"opponent_player":
			var event_player_id := str(event.get("player_id", event.get("playing_player_id", event.get("controller_player_id", event.get("source_controller_player_id", "")))))
			return not event_player_id.is_empty() and event_player_id != controller_player_id
		"source":
			return str(event.get("source_instance_id", event.get("attacker_instance_id", ""))) == source_instance_id
		"target":
			return MatchTimingHelpers._event_target_instance_id(event) == source_instance_id
		"subject":
			return MatchTimingHelpers._event_subject_instance_id(event) == source_instance_id
		"killer":
			if bool(event.get("is_retaliation_kill", false)):
				return false
			return str(event.get("destroyed_by_instance_id", "")) == source_instance_id
		"either":
			return str(event.get("source_instance_id", "")) == source_instance_id or MatchTimingHelpers._event_target_instance_id(event) == source_instance_id or MatchTimingHelpers._event_subject_instance_id(event) == source_instance_id
		"any_player":
			return true
		"friendly_killer":
			if bool(event.get("is_retaliation_kill", false)):
				return false
			var killer_id := str(event.get("destroyed_by_instance_id", ""))
			if killer_id.is_empty() or killer_id == source_instance_id:
				return false
			var killer_card := MatchTimingHelpers._find_card_anywhere(match_state, killer_id)
			return str(killer_card.get("controller_player_id", "")) == controller_player_id
		"target_player_is_controller":
			return str(event.get("target_player_id", "")) == controller_player_id
		"target_player_is_opponent":
			var tp_id := str(event.get("target_player_id", ""))
			return not tp_id.is_empty() and tp_id != controller_player_id
		"opponent_target":
			var target_id := MatchTimingHelpers._event_target_instance_id(event)
			if target_id.is_empty():
				return false
			var target_card := MatchTimingHelpers._find_card_anywhere(match_state, target_id)
			return not target_card.is_empty() and str(target_card.get("controller_player_id", "")) != controller_player_id
		"friendly_target":
			var ft_target_id := MatchTimingHelpers._event_target_instance_id(event)
			if ft_target_id.is_empty():
				ft_target_id = str(event.get("target_instance_id", ""))
			if ft_target_id.is_empty():
				return false
			var ft_target_card := MatchTimingHelpers._find_card_anywhere(match_state, ft_target_id)
			return not ft_target_card.is_empty() and str(ft_target_card.get("controller_player_id", "")) == controller_player_id
	return false


static func _matches_conditions(match_state: Dictionary, trigger: Dictionary, descriptor: Dictionary, family_spec: Dictionary, event: Dictionary) -> bool:
	var target_type := str(descriptor.get("target_type", family_spec.get("target_type", "")))
	if not target_type.is_empty() and str(event.get("target_type", "")) != target_type:
		return false
	var min_amount := int(descriptor.get("min_amount", family_spec.get("min_amount", 0)))
	if min_amount > 0 and int(event.get("amount", 0)) < min_amount:
		return false
	var min_played_cost := int(descriptor.get("min_played_cost", family_spec.get("min_played_cost", 0)))
	if min_played_cost > 0 and int(event.get("played_cost", 0)) < min_played_cost:
		return false
	var require_survived := bool(descriptor.get("require_survived", family_spec.get("require_survived", false)))
	if require_survived:
		# Check that the trigger's source creature is still alive in a lane
		var survive_check_id := str(trigger.get("source_instance_id", ""))
		var survive_card := MatchTimingHelpers._find_card_anywhere(match_state, survive_check_id)
		if survive_card.is_empty() or str(survive_card.get("zone", "")) != ZONE_LANE:
			return false
		if EvergreenRules.get_remaining_health(survive_card) <= 0:
			return false
	var required_min_health := int(descriptor.get("required_controller_min_health", 0))
	if required_min_health > 0:
		var rmh_controller := str(trigger.get("controller_player_id", ""))
		var rmh_player := MatchTimingHelpers._get_player_state(match_state, rmh_controller)
		if int(rmh_player.get("health", 0)) < required_min_health:
			return false
	# 1. required_controller_turn — trigger only fires on the controller's own turn
	if bool(descriptor.get("required_controller_turn", false)):
		var rct_controller := str(trigger.get("controller_player_id", ""))
		if str(match_state.get("active_player_id", "")) != rct_controller:
			return false
	# 2. required_creature_in_each_lane — controller has another creature in every lane (excludes self)
	if bool(descriptor.get("required_creature_in_each_lane", false)):
		var rciel_controller := str(trigger.get("controller_player_id", ""))
		var rciel_self_id := str(trigger.get("source_instance_id", ""))
		var rciel_lanes: Array = match_state.get("lanes", [])
		for rciel_lane in rciel_lanes:
			var rciel_slots: Array = rciel_lane.get("player_slots", {}).get(rciel_controller, [])
			var rciel_count := 0
			for rciel_card in rciel_slots:
				if typeof(rciel_card) == TYPE_DICTIONARY and str(rciel_card.get("instance_id", "")) != rciel_self_id:
					rciel_count += 1
			if rciel_count < 1:
				return false
	# 3. required_friendly_attribute_count — count friendly creatures with a specific attribute
	var rfac_spec: Dictionary = descriptor.get("required_friendly_attribute_count", {})
	if not rfac_spec.is_empty():
		var rfac_attr := str(rfac_spec.get("attribute", ""))
		var rfac_min := int(rfac_spec.get("min", rfac_spec.get("min_count", 0)))
		var rfac_exclude_self := bool(rfac_spec.get("exclude_self", false))
		var rfac_controller := str(trigger.get("controller_player_id", ""))
		var rfac_self_id := str(trigger.get("source_instance_id", ""))
		var rfac_creatures := MatchTimingHelpers._player_lane_creatures(match_state, rfac_controller)
		var rfac_count := 0
		for rfac_card in rfac_creatures:
			if rfac_exclude_self and str(rfac_card.get("instance_id", "")) == rfac_self_id:
				continue
			var rfac_attrs = rfac_card.get("attributes", [])
			if typeof(rfac_attrs) == TYPE_ARRAY and rfac_attrs.has(rfac_attr):
				rfac_count += 1
		if rfac_count < rfac_min:
			return false
	# 4. required_drawn_card_type — the drawn card must be a specific type
	var rdct_type := str(descriptor.get("required_drawn_card_type", ""))
	if not rdct_type.is_empty():
		var rdct_actual := str(event.get("drawn_card_type", ""))
		if rdct_actual.is_empty():
			var rdct_card := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
			rdct_actual = str(rdct_card.get("card_type", ""))
		if rdct_actual != rdct_type:
			return false
	# 5. required_item_in_play — controller has at least one creature with an attached item
	if bool(descriptor.get("required_item_in_play", false)):
		var riip_controller := str(trigger.get("controller_player_id", ""))
		var riip_creatures := MatchTimingHelpers._player_lane_creatures(match_state, riip_controller)
		var riip_found := false
		for riip_card in riip_creatures:
			var riip_items = riip_card.get("attached_items", [])
			if typeof(riip_items) == TYPE_ARRAY and not riip_items.is_empty():
				riip_found = true
				break
		if not riip_found:
			return false
	# 6. required_min_max_magicka — controller's max_magicka >= value
	var rmmm_val := int(descriptor.get("required_min_max_magicka", 0))
	if rmmm_val > 0:
		var rmmm_controller := str(trigger.get("controller_player_id", ""))
		var rmmm_player := MatchTimingHelpers._get_player_state(match_state, rmmm_controller)
		if int(rmmm_player.get("max_magicka", 0)) < rmmm_val:
			return false
	# 7. required_lane_full — the trigger source's lane is full for the controller
	if bool(descriptor.get("required_lane_full", false)):
		var rlf_controller := str(trigger.get("controller_player_id", ""))
		var rlf_lane_index := int(trigger.get("lane_index", -1))
		var rlf_lanes: Array = match_state.get("lanes", [])
		if rlf_lane_index < 0 or rlf_lane_index >= rlf_lanes.size():
			return false
		var rlf_lane: Dictionary = rlf_lanes[rlf_lane_index]
		var rlf_slots: Array = rlf_lane.get("player_slots", {}).get(rlf_controller, [])
		var rlf_capacity := int(rlf_lane.get("slot_capacity", 4))
		if rlf_slots.size() < rlf_capacity:
			return false
	# 8. required_no_enemies_in_lane — no enemy creatures in the trigger source's lane
	if bool(descriptor.get("required_no_enemies_in_lane", false)):
		var rneil_controller := str(trigger.get("controller_player_id", ""))
		var rneil_opponent := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), rneil_controller)
		var rneil_lane_index := int(trigger.get("lane_index", -1))
		var rneil_lanes: Array = match_state.get("lanes", [])
		if rneil_lane_index < 0 or rneil_lane_index >= rneil_lanes.size():
			return false
		var rneil_slots: Array = rneil_lanes[rneil_lane_index].get("player_slots", {}).get(rneil_opponent, [])
		var rneil_count := 0
		for rneil_card in rneil_slots:
			if typeof(rneil_card) == TYPE_DICTIONARY:
				rneil_count += 1
		if rneil_count > 0:
			return false
	# 9. required_opponent_full_lane — opponent has at least one full lane
	if bool(descriptor.get("required_opponent_full_lane", false)):
		var rofl_controller := str(trigger.get("controller_player_id", ""))
		var rofl_opponent := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), rofl_controller)
		var rofl_lanes: Array = match_state.get("lanes", [])
		var rofl_found := false
		for rofl_lane in rofl_lanes:
			var rofl_slots: Array = rofl_lane.get("player_slots", {}).get(rofl_opponent, [])
			var rofl_capacity := int(rofl_lane.get("slot_capacity", 4))
			if rofl_slots.size() >= rofl_capacity:
				rofl_found = true
				break
		if not rofl_found:
			return false
	# 10. required_action_played_this_turn — controller played a non-creature card this turn
	if bool(descriptor.get("required_action_played_this_turn", false)):
		var rapt_controller := str(trigger.get("controller_player_id", ""))
		var rapt_player := MatchTimingHelpers._get_player_state(match_state, rapt_controller)
		if int(rapt_player.get("noncreature_plays_this_turn", 0)) <= 0:
			return false
	# 11. required_cards_played_this_turn — controller played >= N cards this turn
	var rcptt_val := int(descriptor.get("required_cards_played_this_turn", 0))
	if rcptt_val > 0:
		var rcptt_controller := str(trigger.get("controller_player_id", ""))
		var rcptt_player := MatchTimingHelpers._get_player_state(match_state, rcptt_controller)
		if int(rcptt_player.get("cards_played_this_turn", 0)) < rcptt_val:
			return false
	# 12. required_played_max_cost — the played card's cost <= value
	var rpmc_val := int(descriptor.get("required_played_max_cost", -1))
	if rpmc_val >= 0:
		if int(event.get("played_cost", 999)) > rpmc_val:
			return false
	# 13. required_damage_amount — event damage amount >= value
	var rda_val := int(descriptor.get("required_damage_amount", 0))
	if rda_val > 0:
		if int(event.get("amount", 0)) < rda_val:
			return false
	# 14. required_deaths_this_turn_gte — controller's creatures died this turn >= value
	var rdtt_val := int(descriptor.get("required_deaths_this_turn_gte", 0))
	if rdtt_val > 0:
		var rdtt_controller := str(trigger.get("controller_player_id", ""))
		var rdtt_player := MatchTimingHelpers._get_player_state(match_state, rdtt_controller)
		if int(rdtt_player.get("creatures_died_this_turn", 0)) < rdtt_val:
			return false
	# 15. required_gained_health_this_turn — controller gained health this turn
	if bool(descriptor.get("required_gained_health_this_turn", false)):
		var rghtt_controller := str(trigger.get("controller_player_id", ""))
		var rghtt_player := MatchTimingHelpers._get_player_state(match_state, rghtt_controller)
		if int(rghtt_player.get("health_gained_this_turn", 0)) <= 0:
			return false
	# 16. required_card_types_in_discard_or_play — each listed type present in discard or lanes/support
	var rctidop_raw = descriptor.get("required_card_types_in_discard_or_play", {})
	var rctidop_spec: Dictionary = rctidop_raw if typeof(rctidop_raw) == TYPE_DICTIONARY else {}
	var rctidop_types_direct: Array = rctidop_raw if typeof(rctidop_raw) == TYPE_ARRAY else []
	if not rctidop_spec.is_empty() or not rctidop_types_direct.is_empty():
		var rctidop_types: Array = rctidop_types_direct if not rctidop_types_direct.is_empty() else rctidop_spec.get("types", [])
		var rctidop_controller := str(trigger.get("controller_player_id", ""))
		var rctidop_player := MatchTimingHelpers._get_player_state(match_state, rctidop_controller)
		var rctidop_found_types: Dictionary = {}
		for rctidop_card in rctidop_player.get(ZONE_DISCARD, []):
			if typeof(rctidop_card) == TYPE_DICTIONARY:
				rctidop_found_types[str(rctidop_card.get("card_type", ""))] = true
		for rctidop_card in MatchTimingHelpers._player_lane_creatures(match_state, rctidop_controller):
			rctidop_found_types[str(rctidop_card.get("card_type", ""))] = true
			for rctidop_item in rctidop_card.get("attached_items", []):
				if typeof(rctidop_item) == TYPE_DICTIONARY:
					rctidop_found_types["item"] = true
		for rctidop_card in rctidop_player.get("support", []):
			if typeof(rctidop_card) == TYPE_DICTIONARY:
				rctidop_found_types["support"] = true
		for rctidop_type in rctidop_types:
			if not rctidop_found_types.has(str(rctidop_type)):
				return false
	# 17. required_card_types_played_this_turn — each listed type was played this turn
	var rctptt_spec: Dictionary = descriptor.get("required_card_types_played_this_turn", {})
	if not rctptt_spec.is_empty():
		var rctptt_types: Array = rctptt_spec.get("types", [])
		var rctptt_controller := str(trigger.get("controller_player_id", ""))
		var rctptt_player := MatchTimingHelpers._get_player_state(match_state, rctptt_controller)
		var rctptt_played: Array = rctptt_player.get("card_types_played_this_turn", [])
		for rctptt_type in rctptt_types:
			if not rctptt_played.has(str(rctptt_type)):
				return false
	# 18. required_exalted_creature_in_play — controller has a creature with exalted: true
	if bool(descriptor.get("required_exalted_creature_in_play", false)):
		var recip_controller := str(trigger.get("controller_player_id", ""))
		var recip_creatures := MatchTimingHelpers._player_lane_creatures(match_state, recip_controller)
		var recip_found := false
		for recip_card in recip_creatures:
			if bool(recip_card.get("exalted", false)):
				recip_found = true
				break
		if not recip_found:
			return false
	# 19. required_no_crowned_creature — no friendly creature has crowned: true
	if bool(descriptor.get("required_no_crowned_creature", false)):
		var rncc_controller := str(trigger.get("controller_player_id", ""))
		var rncc_creatures := MatchTimingHelpers._player_lane_creatures(match_state, rncc_controller)
		for rncc_card in rncc_creatures:
			if bool(rncc_card.get("crowned", false)):
				return false
	# 20. required_summon_unique — the summoned creature has is_unique: true
	if bool(descriptor.get("required_summon_unique", false)):
		var rsu_card := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
		if rsu_card.is_empty() or not bool(rsu_card.get("is_unique", false)):
			return false
	# 21. required_host_min_power — for items: host creature's power >= value
	var rhmp_val := int(descriptor.get("required_host_min_power", 0))
	if rhmp_val > 0:
		var rhmp_host := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("target_instance_id", "")))
		if rhmp_host.is_empty() or EvergreenRules.get_power(rhmp_host) < rhmp_val:
			return false
	# 22. required_equipper_subtype — for items: the equipping creature has the required subtype
	var res_subtype := str(descriptor.get("required_equipper_subtype", ""))
	if not res_subtype.is_empty():
		var res_host := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("target_instance_id", "")))
		if res_host.is_empty():
			return false
		var res_subtypes = res_host.get("subtypes", [])
		if typeof(res_subtypes) != TYPE_ARRAY or not res_subtypes.has(res_subtype):
			return false
	# 22b. required_equipper_name — the equipping creature has the required name
	var res_name := str(descriptor.get("required_equipper_name", ""))
	if not res_name.is_empty():
		var rn_host := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("target_instance_id", "")))
		if rn_host.is_empty() or str(rn_host.get("name", "")) != res_name:
			return false
	var required_damage_kind := str(descriptor.get("damage_kind", family_spec.get("damage_kind", "")))
	if not required_damage_kind.is_empty() and str(event.get("damage_kind", "")) != required_damage_kind:
		return false
	if bool(descriptor.get("exclude_retaliation", family_spec.get("exclude_retaliation", false))):
		if bool(event.get("is_retaliation", false)):
			return false
	if bool(descriptor.get("exclude_battle", family_spec.get("exclude_battle", false))):
		if bool(event.get("is_battle", false)):
			return false
	if bool(descriptor.get("require_retaliation", family_spec.get("require_retaliation", false))):
		if not bool(event.get("is_retaliation", false)):
			return false
	var required_played_card_type := str(descriptor.get("required_played_card_type", family_spec.get("required_played_card_type", "")))
	if not required_played_card_type.is_empty() and str(event.get("card_type", "")) != required_played_card_type:
		return false
	var required_played_rules_tag := str(descriptor.get("required_played_rules_tag", ""))
	if not required_played_rules_tag.is_empty():
		var event_rules_tags = event.get("rules_tags", [])
		if typeof(event_rules_tags) != TYPE_ARRAY or not event_rules_tags.has(required_played_rules_tag):
			return false
	if bool(descriptor.get("exclude_self", family_spec.get("exclude_self", false))):
		var event_source_id := str(event.get("source_instance_id", event.get("subject_instance_id", "")))
		if event_source_id == str(trigger.get("source_instance_id", "")):
			return false
	if bool(descriptor.get("require_same_lane", false)):
		var trigger_lane_index := int(trigger.get("lane_index", -1))
		var event_lane_id := str(event.get("lane_id", ""))
		var lanes: Array = match_state.get("lanes", [])
		if trigger_lane_index < 0 or trigger_lane_index >= lanes.size():
			return false
		if str(lanes[trigger_lane_index].get("lane_id", "")) != event_lane_id:
			return false
	var max_source_cost := int(descriptor.get("max_event_source_cost", -1))
	if max_source_cost >= 0:
		var cost_check_card := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
		if cost_check_card.is_empty() or int(cost_check_card.get("cost", 999)) > max_source_cost:
			return false
	var required_event_source_zone := str(descriptor.get("required_event_source_zone", ""))
	if not required_event_source_zone.is_empty() and str(event.get("source_zone", "")) != required_event_source_zone:
		return false
	var required_event_target_zone := str(descriptor.get("required_event_target_zone", ""))
	if not required_event_target_zone.is_empty() and str(event.get("target_zone", "")) != required_event_target_zone:
		return false
	var required_event_status_id := str(descriptor.get("required_event_status_id", family_spec.get("required_event_status_id", "")))
	if not required_event_status_id.is_empty() and str(event.get("status_id", "")) != required_event_status_id:
		return false
	var required_target_keyword := str(descriptor.get("required_target_keyword", ""))
	if not required_target_keyword.is_empty():
		var rtk_target_id := str(event.get("target_instance_id", ""))
		var rtk_target := MatchTimingHelpers._find_card_anywhere(match_state, rtk_target_id)
		if rtk_target.is_empty() or not EvergreenRules.has_keyword(rtk_target, required_target_keyword):
			return false
	# Summon-filtering conditions — gate triggers based on properties of the summoned creature
	var _summon_card_needed := false
	var _summon_card: Dictionary = {}
	var required_summon_subtype := str(descriptor.get("required_summon_subtype", ""))
	var required_summon_keyword := str(descriptor.get("required_summon_keyword", ""))
	var required_summon_min_power := int(descriptor.get("required_summon_min_power", 0))
	var required_summon_min_health := int(descriptor.get("required_summon_min_health", 0))
	var required_summon_min_cost := int(descriptor.get("required_summon_min_cost", 0))
	if not required_summon_subtype.is_empty() or not required_summon_keyword.is_empty() or required_summon_min_power > 0 or required_summon_min_health > 0 or required_summon_min_cost > 0:
		_summon_card = MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
		if _summon_card.is_empty():
			return false
	if not required_summon_subtype.is_empty():
		var summon_subtypes = _summon_card.get("subtypes", [])
		if typeof(summon_subtypes) != TYPE_ARRAY or not summon_subtypes.has(required_summon_subtype):
			return false
	if not required_summon_keyword.is_empty():
		if not EvergreenRules.has_keyword(_summon_card, required_summon_keyword):
			return false
	if required_summon_min_power > 0:
		if EvergreenRules.get_power(_summon_card) < required_summon_min_power:
			return false
	if required_summon_min_health > 0:
		if EvergreenRules.get_health(_summon_card) < required_summon_min_health:
			return false
	if required_summon_min_cost > 0:
		if int(_summon_card.get("cost", 0)) < required_summon_min_cost:
			return false
	# Slay-filtering: gate slay triggers based on properties of the destroyed creature
	var required_slay_subtype := str(descriptor.get("required_slay_subtype", ""))
	if not required_slay_subtype.is_empty():
		var slay_victim := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
		if slay_victim.is_empty():
			return false
		var slay_subtypes = slay_victim.get("subtypes", [])
		if typeof(slay_subtypes) != TYPE_ARRAY or not slay_subtypes.has(required_slay_subtype):
			return false
	if bool(descriptor.get("require_positive_power_bonus", family_spec.get("require_positive_power_bonus", false))):
		if int(event.get("power_bonus", 0)) <= 0:
			return false
	if bool(descriptor.get("require_negative_stat_bonus", family_spec.get("require_negative_stat_bonus", false))):
		if int(event.get("power_bonus", 0)) >= 0 and int(event.get("health_bonus", 0)) >= 0:
			return false
	# Expertise: only fires at end of turn if controller played an action/item/support
	if str(descriptor.get("family", "")) == FAMILY_EXPERTISE:
		var expertise_controller := str(trigger.get("controller_player_id", ""))
		var expertise_player := MatchTimingHelpers._get_player_state(match_state, expertise_controller)
		if int(expertise_player.get("noncreature_plays_this_turn", 0)) <= 0:
			return false
	var required_wax_wane := str(descriptor.get("required_wax_wane_phase", family_spec.get("required_wax_wane_phase", "")))
	if not required_wax_wane.is_empty():
		var controller_player_id := str(trigger.get("controller_player_id", ""))
		var ww_player := MatchTimingHelpers._get_player_state(match_state, controller_player_id)
		if str(ww_player.get("wax_wane_state", "wax")) != required_wax_wane and not bool(ww_player.get("_dual_wax_wane", false)):
			return false
	return ExtendedMechanicPacks.matches_additional_conditions(match_state, trigger, descriptor, event)


static func _build_trigger_sort_key(match_state: Dictionary, trigger: Dictionary) -> String:
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var priority_player_id := str(match_state.get("priority_player_id", match_state.get("active_player_id", "")))
	var controller_rank := 0 if controller_player_id == priority_player_id else 1
	var zone_name := str(trigger.get("source_zone", ""))
	var zone_rank := int(ZONE_PRIORITY.get(zone_name, 9))
	var lane_index := maxi(-1, int(trigger.get("lane_index", -1))) + 1
	var slot_index := maxi(-1, int(trigger.get("slot_index", -1))) + 1
	var trigger_index := int(trigger.get("trigger_index", 0))
	return "%02d|%02d|%02d|%02d|%s|%02d" % [controller_rank, zone_rank, lane_index, slot_index, str(trigger.get("source_instance_id", "")), trigger_index]


static func _insert_sorted_trigger(matches: Array, trigger: Dictionary) -> void:
	var sort_key := str(trigger.get("sort_key", ""))
	for index in range(matches.size()):
		if sort_key < str(matches[index].get("sort_key", "")):
			matches.insert(index, trigger)
			return
	matches.append(trigger)


static func _build_trigger_resolution(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Dictionary:
	match_state["next_trigger_resolution_sequence"] = int(match_state.get("next_trigger_resolution_sequence", 0)) + 1
	var resolution_id := "trigger_%04d" % int(match_state["next_trigger_resolution_sequence"])
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var family := str(descriptor.get("family", descriptor.get("event_type", "")))
	return {
		"entry_type": "trigger_resolved",
		"resolution_id": resolution_id,
		"trigger_id": str(trigger.get("trigger_id", "")),
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"controller_player_id": str(trigger.get("controller_player_id", "")),
		"family": family,
		"event_id": str(event.get("event_id", "")),
		"event_type": str(event.get("event_type", "")),
		"timing_window": str(descriptor.get("window", _get_family_specs().get(family, {}).get("window", WINDOW_AFTER))),
	}


static func _mark_once_trigger_if_needed(match_state: Dictionary, trigger: Dictionary) -> void:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var is_once_per_instance := bool(descriptor.get("once_per_instance", false)) or str(descriptor.get("family", "")) == FAMILY_VETERAN
	if is_once_per_instance:
		var resolved_once_triggers: Dictionary = match_state.get("resolved_once_triggers", {})
		resolved_once_triggers[str(trigger.get("trigger_id", ""))] = true
		match_state["resolved_once_triggers"] = resolved_once_triggers
	if bool(descriptor.get("once_per_turn", false)):
		var resolved_turn_triggers: Dictionary = match_state.get("resolved_turn_triggers", {})
		resolved_turn_triggers[str(trigger.get("trigger_id", ""))] = true
		match_state["resolved_turn_triggers"] = resolved_turn_triggers


static func _is_once_trigger_consumed(match_state: Dictionary, trigger: Dictionary) -> bool:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	# Veteran is inherently once-per-instance (first attack only)
	var is_once_per_instance := bool(descriptor.get("once_per_instance", false)) or str(descriptor.get("family", "")) == FAMILY_VETERAN
	if is_once_per_instance:
		var resolved_once_triggers: Dictionary = match_state.get("resolved_once_triggers", {})
		if bool(resolved_once_triggers.get(str(trigger.get("trigger_id", "")), false)):
			return true
	if bool(descriptor.get("once_per_turn", false)):
		var resolved_turn_triggers: Dictionary = match_state.get("resolved_turn_triggers", {})
		if bool(resolved_turn_triggers.get(str(trigger.get("trigger_id", "")), false)):
			return true
	return false

