class_name EffectSacrifice
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")
const MatchEffectParams = preload("res://src/core/match/match_effect_params.gd")
const MatchAuras = preload("res://src/core/match/match_auras.gd")
const MatchTriggers = preload("res://src/core/match/match_triggers.gd")
const MatchTargeting = preload("res://src/core/match/match_targeting.gd")
const MatchSummonTiming = preload("res://src/core/match/match_summon_timing.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")

const ZONE_HAND := "hand"
const ZONE_DECK := "deck"
const ZONE_LANE := "lane"
const ZONE_SUPPORT := "support"
const ZONE_DISCARD := "discard"
const ZONE_BANISHED := "banished"
const ZONE_GENERATED := "generated"
const CARD_TYPE_CREATURE := "creature"
const CARD_TYPE_ACTION := "action"
const CARD_TYPE_ITEM := "item"
const CARD_TYPE_SUPPORT := "support"
const EVENT_CREATURE_SUMMONED := "creature_summoned"
const EVENT_CARD_PLAYED := "card_played"
const EVENT_DAMAGE_RESOLVED := "damage_resolved"
const EVENT_CREATURE_DESTROYED := "creature_destroyed"
const EVENT_CARD_DRAWN := "card_drawn"
const EVENT_RUNE_BROKEN := "rune_broken"
const EVENT_CREATURE_CONSUMED := "card_consumed"
const EVENT_CREATURE_SACRIFICED := "card_sacrificed"
const EVENT_CARD_EQUIPPED := "card_equipped"
const EVENT_CARD_OVERDRAW := "card_overdraw"
const FAMILY_SUMMON := "summon"
const FAMILY_LAST_GASP := "last_gasp"
const FAMILY_SLAY := "slay"
const FAMILY_PILFER := "pilfer"
const FAMILY_EXPERTISE := "expertise"
const FAMILY_ON_PLAY := "on_play"
const FAMILY_EXALT := "exalt"
const FAMILY_WAX := "wax"
const FAMILY_WANE := "wane"
const FAMILY_ON_EQUIP := "on_equip"
const FAMILY_ACTIVATE := "activate"
const FAMILY_VETERAN := "veteran"
const RULE_TAG_PROPHECY := "prophecy"
const WINDOW_AFTER := "after"
const WINDOW_IMMEDIATE := "immediate"
const MAX_HAND_SIZE := 10
const RANDOM_KEYWORD_POOL := ["breakthrough", "charge", "drain", "guard", "lethal", "regenerate", "ward"]

static func _MT():
	return load("res://src/core/match/match_timing.gd")


static func apply(op: String, match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary, generated_events: Array, ctx: Dictionary) -> void:
	var descriptor: Dictionary = ctx.get("descriptor", {})
	var reason: String = ctx.get("reason", "trigger")
	match op:
		"sacrifice":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				trigger["_destroyed_creature_power"] = EvergreenRules.get_power(card)
				var sacrifice_result := MatchMutations.sacrifice_card(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")))
				generated_events.append_array(sacrifice_result.get("events", []))
		"sacrifice_and_resummon":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var sar_def_id := str(card.get("definition_id", ""))
				var sar_controller := str(card.get("controller_player_id", ""))
				var sar_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				var sar_lane_id := str(sar_loc.get("lane_id", ""))
				var sar_lane_index := int(sar_loc.get("lane_index", -1))
				var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
				if bool(moved.get("is_valid", false)):
					generated_events.append({"event_type": "creature_destroyed", "instance_id": str(card.get("instance_id", "")), "reason": "sacrifice_and_resummon"})
					var sar_base_power := int(card.get("base_power", card.get("power", 0)))
					var sar_base_health := int(card.get("base_health", card.get("health", 0)))
					var sar_template := {
						"definition_id": sar_def_id,
						"card_type": CARD_TYPE_CREATURE,
						"name": str(card.get("name", "")),
						"cost": int(card.get("cost", 0)),
						"power": sar_base_power,
						"health": sar_base_health,
						"base_power": sar_base_power,
						"base_health": sar_base_health,
						"keywords": card.get("keywords", []).duplicate() if typeof(card.get("keywords", [])) == TYPE_ARRAY else [],
						"subtypes": card.get("subtypes", []).duplicate() if typeof(card.get("subtypes", [])) == TYPE_ARRAY else [],
						"attributes": card.get("attributes", []).duplicate() if typeof(card.get("attributes", [])) == TYPE_ARRAY else [],
						"rules_text": str(card.get("rules_text", "")),
					}
					var sar_copy := MatchMutations.build_generated_card(match_state, sar_controller, sar_template)
					if sar_lane_index >= 0:
						var sar_summon := MatchMutations.summon_card_to_lane(match_state, sar_controller, sar_copy, sar_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
						if bool(sar_summon.get("is_valid", false)):
							generated_events.append_array(sar_summon.get("events", []))
							generated_events.append(MatchSummonTiming._build_summon_event(sar_summon["card"], sar_controller, sar_lane_id, int(sar_summon.get("slot_index", -1)), "sacrifice_and_resummon"))
							_MT()._check_summon_abilities(match_state, sar_summon["card"])
		"recall_and_resummon":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var rar_controller := str(card.get("controller_player_id", ""))
				var rar_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				var rar_current_lane := str(rar_loc.get("lane_id", ""))
				var rar_dest_lane := ""
				for lane in match_state.get("lanes", []):
					var lid := str(lane.get("lane_id", ""))
					if lid != rar_current_lane and not lid.is_empty():
						rar_dest_lane = lid
						break
				if rar_dest_lane.is_empty():
					continue
				var rar_summon := MatchMutations.summon_card_to_lane(match_state, rar_controller, str(card.get("instance_id", "")), rar_dest_lane, {"source_zone": MatchMutations.ZONE_LANE})
				if bool(rar_summon.get("is_valid", false)):
					generated_events.append_array(rar_summon.get("events", []))
					generated_events.append(MatchSummonTiming._build_summon_event(rar_summon["card"], rar_controller, rar_dest_lane, int(rar_summon.get("slot_index", -1)), "recall_and_resummon"))
					_MT()._check_summon_abilities(match_state, rar_summon["card"])
		"sacrifice_and_summon_from_deck":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var sasd_controller_id := str(card.get("controller_player_id", ""))
				var sasd_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				var sasd_lane_id := str(sasd_location.get("lane_id", ""))
				# Resolve escalating target cost from the source card (e.g. Altar of Despair)
				var sasd_source_id := str(trigger.get("source_instance_id", ""))
				var sasd_source := MatchTimingHelpers._find_card_anywhere(match_state, sasd_source_id)
				var sasd_esc_key := str(effect.get("escalating_filter_key", ""))
				var sasd_esc_start := int(effect.get("escalating_start", 1))
				var sasd_esc_increment := int(effect.get("escalating_increment", 1))
				var sasd_target_cost: int
				if not sasd_esc_key.is_empty() and not sasd_source.is_empty():
					var sasd_esc_state_key := "_escalating_" + sasd_esc_key
					sasd_target_cost = int(sasd_source.get(sasd_esc_state_key, sasd_esc_start))
				else:
					sasd_target_cost = int(card.get("cost", 0)) + int(effect.get("cost_offset", 1))
				# Sacrifice the chosen creature
				var sasd_sac := MatchMutations.sacrifice_card(match_state, sasd_controller_id, str(card.get("instance_id", "")), {"reason": reason})
				generated_events.append_array(sasd_sac.get("events", []))
				generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": sasd_controller_id, "lane_id": sasd_lane_id})
				var sasd_player := MatchTimingHelpers._get_player_state(match_state, sasd_controller_id)
				if not sasd_player.is_empty() and not sasd_lane_id.is_empty():
					var sasd_deck: Array = sasd_player.get(ZONE_DECK, [])
					var sasd_candidates: Array = []
					for sasd_card in sasd_deck:
						if str(sasd_card.get("card_type", "")) == CARD_TYPE_CREATURE and int(sasd_card.get("cost", 0)) == sasd_target_cost:
							sasd_candidates.append(sasd_card)
					var sasd_summon_target: Dictionary
					if not sasd_candidates.is_empty():
						var sasd_idx := MatchEffectParams._deterministic_index(match_state, sasd_source_id + "_sac_summon", sasd_candidates.size())
						sasd_summon_target = sasd_candidates[sasd_idx]
						sasd_deck.erase(sasd_summon_target)
						sasd_summon_target.erase("zone")
					else:
						# No matching creature — generate a Sweet Roll
						var sasd_sweet_template := {"definition_id": "neu_sweet_roll", "name": "Sweet Roll", "card_type": "creature", "subtypes": ["Pastry"], "attributes": ["neutral"], "cost": 1, "power": 0, "health": 1, "base_power": 0, "base_health": 1, "rules_text": "There were no creatures to fetch, so we gave you this Sweet Roll. If a creature eats it, heal them.", "triggered_abilities": [{"family": "last_gasp", "effects": [{"op": "restore_creature_health", "target": "event_killer"}]}]}
						sasd_summon_target = MatchMutations.build_generated_card(match_state, sasd_controller_id, sasd_sweet_template)
					var sasd_result := MatchMutations.summon_card_to_lane(match_state, sasd_controller_id, sasd_summon_target, sasd_lane_id, {"source_zone": ZONE_DECK})
					if bool(sasd_result.get("is_valid", false)):
						generated_events.append_array(sasd_result.get("events", []))
						generated_events.append(MatchSummonTiming._build_summon_event(sasd_result["card"], sasd_controller_id, sasd_lane_id, int(sasd_result.get("slot_index", -1)), reason))
						_MT()._check_summon_abilities(match_state, sasd_result["card"])
				# Increment the escalating counter and update rules_text
				if not sasd_esc_key.is_empty() and not sasd_source.is_empty():
					var sasd_esc_state_key := "_escalating_" + sasd_esc_key
					var sasd_next_cost := sasd_target_cost + sasd_esc_increment
					sasd_source[sasd_esc_state_key] = sasd_next_cost
					var sasd_rules_tpl := str(effect.get("rules_text_template", ""))
					if not sasd_rules_tpl.is_empty():
						sasd_source["rules_text"] = sasd_rules_tpl.replace("{cost}", str(sasd_next_cost))
		"sacrifice_and_equip_from_deck":
			# Queue a cancellable targeting phase — player picks a creature with 3+ items
			var saed_controller_id := str(trigger.get("controller_player_id", ""))
			var saed_source_id := str(trigger.get("source_instance_id", ""))
			var saed_valid := MatchTargeting.get_valid_targets_for_mode(match_state, saed_source_id, "friendly_creature_with_3_items", {})
			if saed_valid.is_empty():
				return
			var saed_pending: Array = match_state.get("pending_summon_effect_targets", [])
			saed_pending.append({
				"player_id": saed_controller_id,
				"source_instance_id": saed_source_id,
				"mandatory": false,
				"_choice_target_mode": "friendly_creature_with_3_items",
				"_choice_deferred_effects": [{"op": "sacrifice_source_and_equip_from_deck", "target": "chosen_target"}],
				"_choice_trigger": trigger.duplicate(true),
				"_choice_event": event.duplicate(true),
			})
			generated_events.append({"event_type": "summon_effect_target_pending", "player_id": saed_controller_id})
		"sacrifice_source_and_equip_from_deck":
			# Deferred: player chose a creature — discard the lab, then browse deck for items
			var ssed_targets := MatchTargeting._resolve_card_targets(match_state, trigger, event, effect)
			if ssed_targets.is_empty():
				return
			var ssed_creature: Dictionary = ssed_targets[0]
			var ssed_controller_id := str(trigger.get("controller_player_id", ""))
			var ssed_source_id := str(trigger.get("source_instance_id", ""))
			# Discard the source support (the lab)
			var ssed_discard := MatchMutations.discard_card(match_state, ssed_source_id, {"reason": reason})
			generated_events.append_array(ssed_discard.get("events", []))
			# Find items in deck and queue a deck selection for the player to choose one
			var ssed_player := MatchTimingHelpers._get_player_state(match_state, ssed_controller_id)
			if not ssed_player.is_empty():
				var ssed_deck: Array = ssed_player.get(ZONE_DECK, [])
				var ssed_item_ids: Array = []
				for ssed_dc in ssed_deck:
					if typeof(ssed_dc) == TYPE_DICTIONARY and str(ssed_dc.get("card_type", "")) == "item":
						ssed_item_ids.append(str(ssed_dc.get("instance_id", "")))
				if not ssed_item_ids.is_empty():
					var ssed_pending: Array = match_state.get("pending_deck_selections", [])
					ssed_pending.append({
						"player_id": ssed_controller_id,
						"source_instance_id": ssed_source_id,
						"candidate_instance_ids": ssed_item_ids,
						"then_op": "equip_item_to_creature",
						"then_context": {"target_instance_id": str(ssed_creature.get("instance_id", "")), "reason": "monster_perfection_lab"},
					})
		"sacrifice_and_absorb_stats":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var saas_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if saas_source.is_empty():
					return
				var saas_power := EvergreenRules.get_power(card)
				var saas_health := EvergreenRules.get_health(card)
				var saas_sac := MatchMutations.sacrifice_card(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")), {"reason": reason})
				generated_events.append_array(saas_sac.get("events", []))
				generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": str(card.get("controller_player_id", ""))})
				EvergreenRules.apply_stat_bonus(saas_source, saas_power, saas_health, reason)
				generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(saas_source.get("instance_id", "")), "power_bonus": saas_power, "health_bonus": saas_health, "reason": reason})
		"consume":
			var consumers := MatchTargeting._resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("consumer_target", "self")))
			if consumers.is_empty():
				return
			var consumer: Dictionary = consumers[0]
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var consume_result := MatchMutations.consume_card(match_state, str(consumer.get("controller_player_id", "")), str(consumer.get("instance_id", "")), str(card.get("instance_id", "")), {
					"reason": reason,
					"destination_zone": str(effect.get("destination_zone", MatchMutations.ZONE_DISCARD)),
				})
				generated_events.append_array(consume_result.get("events", []))
		"consume_card":
			var cc_controller_id := str(trigger.get("controller_player_id", ""))
			var cc_source_id := str(trigger.get("source_instance_id", ""))
			var cc_candidates = _MT().get_consume_candidates(match_state, cc_controller_id)
			if not cc_candidates.is_empty():
				var cc_candidate_ids: Array = []
				for cc_card in cc_candidates:
					cc_candidate_ids.append(str(cc_card.get("instance_id", "")))
				var cc_pending: Array = match_state.get("pending_consume_selections", [])
				cc_pending.append({
					"player_id": cc_controller_id,
					"source_instance_id": cc_source_id,
					"candidate_instance_ids": cc_candidate_ids,
					"has_target_mode": false,
					"trigger_index": int(trigger.get("trigger_index", 0)),
				})
		"consume_or_sacrifice":
			# Skip if already resolved via consume selection (resolve_consume_selection re-applies effects)
			if trigger.get("_consumed_card_info", {}).is_empty():
				var cos_controller_id := str(trigger.get("controller_player_id", ""))
				var cos_source_id := str(trigger.get("source_instance_id", ""))
				var cos_candidates = _MT().get_consume_candidates(match_state, cos_controller_id)
				if not cos_candidates.is_empty():
					var cos_candidate_ids: Array = []
					for cos_c in cos_candidates:
						cos_candidate_ids.append(str(cos_c.get("instance_id", "")))
					var cos_pending: Array = match_state.get("pending_consume_selections", [])
					cos_pending.append({
						"player_id": cos_controller_id,
						"source_instance_id": cos_source_id,
						"candidate_instance_ids": cos_candidate_ids,
						"has_target_mode": false,
						"trigger_index": int(trigger.get("trigger_index", 0)),
					})
				else:
					var cos_sac := MatchMutations.sacrifice_card(match_state, cos_controller_id, cos_source_id, {"reason": reason})
					generated_events.append_array(cos_sac.get("events", []))
					generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": cos_source_id, "controller_player_id": cos_controller_id})
		"consume_all_creatures_in_discard_this_turn":
			var cacidt_controller_id := str(trigger.get("controller_player_id", ""))
			var cacidt_source_id := str(trigger.get("source_instance_id", ""))
			var cacidt_player := MatchTimingHelpers._get_player_state(match_state, cacidt_controller_id)
			if not cacidt_player.is_empty():
				var cacidt_discard: Array = cacidt_player.get(ZONE_DISCARD, [])
				var cacidt_turn := int(match_state.get("turn_number", 0))
				var cacidt_targets: Array = []
				for cacidt_card in cacidt_discard:
					if typeof(cacidt_card) == TYPE_DICTIONARY and str(cacidt_card.get("card_type", "")) == CARD_TYPE_CREATURE and int(cacidt_card.get("entered_discard_on_turn", -1)) == cacidt_turn:
						cacidt_targets.append(cacidt_card)
				if not cacidt_targets.is_empty():
					generated_events.append({"event_type": "mass_consume", "source_instance_id": cacidt_source_id, "player_id": cacidt_controller_id, "count": cacidt_targets.size()})
				var cacidt_buff: Dictionary = effect.get("buff_per_consumed", {})
				var cacidt_power_per := int(cacidt_buff.get("power", 0))
				var cacidt_health_per := int(cacidt_buff.get("health", 0))
				for cacidt_target in cacidt_targets:
					var cacidt_opts := {"reason": reason}
					if not cacidt_buff.is_empty():
						cacidt_opts["power_gain"] = cacidt_power_per
						cacidt_opts["health_gain"] = cacidt_health_per
					var cacidt_result := MatchMutations.consume_card(match_state, cacidt_controller_id, cacidt_source_id, str(cacidt_target.get("instance_id", "")), cacidt_opts)
					generated_events.append_array(cacidt_result.get("events", []))
		"optional_consume_for_keyword":
			# Handled via pending consume selection
			var ocfk_controller_id := str(trigger.get("controller_player_id", ""))
			var ocfk_candidates = _MT().get_consume_candidates(match_state, ocfk_controller_id)
			if not ocfk_candidates.is_empty():
				var ocfk_candidate_ids: Array = []
				for ocfk_c in ocfk_candidates:
					ocfk_candidate_ids.append(str(ocfk_c.get("instance_id", "")))
				var ocfk_pending: Array = match_state.get("pending_consume_selections", [])
				ocfk_pending.append({
					"player_id": ocfk_controller_id,
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"candidate_instance_ids": ocfk_candidate_ids,
					"has_target_mode": false,
					"trigger_index": int(trigger.get("trigger_index", 0)),
				})
		"consume_and_copy_veteran":
			var cacv_controller_id := str(trigger.get("controller_player_id", ""))
			var cacv_source_id := str(trigger.get("source_instance_id", ""))
			# Only check the trigger dict — source card may have stale _consumed_card_info from prior consume
			var cacv_consumed_info: Dictionary = trigger.get("_consumed_card_info", {})
			if not cacv_consumed_info.is_empty():
				# Post-consume: veteran effects are fired by resolve_consume_selection
				pass
			else:
				# Pre-consume: create pending consume selection (any creature in discard)
				var cacv_player := MatchTimingHelpers._get_player_state(match_state, cacv_controller_id)
				if not cacv_player.is_empty():
					var cacv_discard: Array = cacv_player.get(ZONE_DISCARD, [])
					var cacv_candidate_ids: Array = []
					for cacv_card in cacv_discard:
						if typeof(cacv_card) == TYPE_DICTIONARY and str(cacv_card.get("card_type", "")) == CARD_TYPE_CREATURE:
							cacv_candidate_ids.append(str(cacv_card.get("instance_id", "")))
					if not cacv_candidate_ids.is_empty():
						var cacv_pending: Array = match_state.get("pending_consume_selections", [])
						cacv_pending.append({
							"player_id": cacv_controller_id,
							"source_instance_id": cacv_source_id,
							"candidate_instance_ids": cacv_candidate_ids,
							"has_target_mode": false,
							"trigger_index": int(trigger.get("trigger_index", 0)),
						})
		"consume_and_reduce_matching_subtype_cost":
			var carmsc_controller_id := str(trigger.get("controller_player_id", ""))
			var carmsc_source_id := str(trigger.get("source_instance_id", ""))
			var carmsc_consumed_info: Dictionary = trigger.get("_consumed_card_info", {})
			if carmsc_consumed_info.is_empty():
				var carmsc_source_card := MatchTimingHelpers._find_card_anywhere(match_state, carmsc_source_id)
				if not carmsc_source_card.is_empty():
					carmsc_consumed_info = carmsc_source_card.get("_consumed_card_info", {})
			if not carmsc_consumed_info.is_empty():
				# Post-consume phase: reduce cost of matching subtype creatures in deck
				var carmsc_subtypes: Array = carmsc_consumed_info.get("subtypes", [])
				var carmsc_reduction := int(effect.get("cost_reduction", 1))
				var carmsc_player := MatchTimingHelpers._get_player_state(match_state, carmsc_controller_id)
				if not carmsc_player.is_empty() and not carmsc_subtypes.is_empty():
					var carmsc_deck: Array = carmsc_player.get(ZONE_DECK, [])
					for carmsc_card in carmsc_deck:
						if typeof(carmsc_card) != TYPE_DICTIONARY or str(carmsc_card.get("card_type", "")) != CARD_TYPE_CREATURE:
							continue
						var carmsc_card_subtypes: Array = carmsc_card.get("subtypes", [])
						if typeof(carmsc_card_subtypes) != TYPE_ARRAY:
							continue
						var carmsc_match := false
						for carmsc_st in carmsc_subtypes:
							if carmsc_card_subtypes.has(carmsc_st):
								carmsc_match = true
								break
						if carmsc_match:
							carmsc_card["cost"] = maxi(0, int(carmsc_card.get("cost", 0)) - carmsc_reduction)
					generated_events.append({"event_type": "zone_cost_reduced", "player_id": carmsc_controller_id, "zone": ZONE_DECK, "amount": carmsc_reduction, "reason": reason})
			else:
				# Pre-consume phase: create pending consume selection
				var carmsc_candidates = _MT().get_consume_candidates(match_state, carmsc_controller_id)
				if not carmsc_candidates.is_empty():
					var carmsc_candidate_ids: Array = []
					for carmsc_c in carmsc_candidates:
						carmsc_candidate_ids.append(str(carmsc_c.get("instance_id", "")))
					var carmsc_pending: Array = match_state.get("pending_consume_selections", [])
					carmsc_pending.append({
						"player_id": carmsc_controller_id,
						"source_instance_id": carmsc_source_id,
						"candidate_instance_ids": carmsc_candidate_ids,
						"has_target_mode": false,
						"trigger_index": int(trigger.get("trigger_index", 0)),
					})
