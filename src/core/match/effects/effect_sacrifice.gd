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
				var sasd_cost := int(card.get("cost", 0))
				var sasd_target_cost := sasd_cost + int(effect.get("cost_offset", 1))
				var sasd_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				var sasd_lane_id := str(sasd_location.get("lane_id", ""))
				var sasd_sac := MatchMutations.sacrifice_card(match_state, sasd_controller_id, str(card.get("instance_id", "")), {"reason": reason})
				generated_events.append_array(sasd_sac.get("events", []))
				generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": sasd_controller_id, "lane_id": sasd_lane_id})
				var sasd_player := MatchTimingHelpers._get_player_state(match_state, sasd_controller_id)
				if not sasd_player.is_empty():
					var sasd_deck: Array = sasd_player.get(ZONE_DECK, [])
					var sasd_candidates: Array = []
					for sasd_card in sasd_deck:
						if str(sasd_card.get("card_type", "")) == CARD_TYPE_CREATURE and int(sasd_card.get("cost", 0)) == sasd_target_cost:
							sasd_candidates.append(sasd_card)
					if not sasd_candidates.is_empty():
						var sasd_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_sac_summon", sasd_candidates.size())
						var sasd_summon_target: Dictionary = sasd_candidates[sasd_idx]
						sasd_deck.erase(sasd_summon_target)
						sasd_summon_target.erase("zone")
						if not sasd_lane_id.is_empty():
							var sasd_result := MatchMutations.summon_card_to_lane(match_state, sasd_controller_id, sasd_summon_target, sasd_lane_id, {"source_zone": ZONE_DECK})
							if bool(sasd_result.get("is_valid", false)):
								generated_events.append_array(sasd_result.get("events", []))
								generated_events.append(MatchSummonTiming._build_summon_event(sasd_result["card"], sasd_controller_id, sasd_lane_id, int(sasd_result.get("slot_index", -1)), reason))
								_MT()._check_summon_abilities(match_state, sasd_result["card"])
		"sacrifice_and_equip_from_deck":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var saed_controller_id := str(card.get("controller_player_id", ""))
				var saed_items: Array = card.get("attached_items", [])
				var saed_item_templates: Array = []
				for saed_item in saed_items:
					saed_item_templates.append(saed_item.duplicate(true))
				var saed_sac := MatchMutations.sacrifice_card(match_state, saed_controller_id, str(card.get("instance_id", "")), {"reason": reason})
				generated_events.append_array(saed_sac.get("events", []))
				# Summon a creature from deck and equip the items
				var saed_player := MatchTimingHelpers._get_player_state(match_state, saed_controller_id)
				if not saed_player.is_empty():
					var saed_deck: Array = saed_player.get(ZONE_DECK, [])
					var saed_candidates: Array = []
					for saed_dc in saed_deck:
						if str(saed_dc.get("card_type", "")) == CARD_TYPE_CREATURE:
							saed_candidates.append(saed_dc)
					if not saed_candidates.is_empty():
						var saed_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_sac_equip", saed_candidates.size())
						var saed_target: Dictionary = saed_candidates[saed_idx]
						saed_deck.erase(saed_target)
						saed_target.erase("zone")
						var saed_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, saed_controller_id)
						if not saed_lane_id.is_empty():
							var saed_result := MatchMutations.summon_card_to_lane(match_state, saed_controller_id, saed_target, saed_lane_id, {"source_zone": ZONE_DECK})
							if bool(saed_result.get("is_valid", false)):
								generated_events.append_array(saed_result.get("events", []))
								generated_events.append(MatchSummonTiming._build_summon_event(saed_result["card"], saed_controller_id, saed_lane_id, int(saed_result.get("slot_index", -1)), reason))
								for saed_item_t in saed_item_templates:
									var saed_new_item := MatchMutations.build_generated_card(match_state, saed_controller_id, saed_item_t)
									var saed_equip := MatchMutations.attach_item_to_creature(match_state, saed_controller_id, saed_new_item, str(saed_result["card"].get("instance_id", "")), {"reason": reason})
									generated_events.append_array(saed_equip.get("events", []))
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
			# Player chooses to consume from discard
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
		"consume_all_creatures_in_discard_this_turn":
			var cacidt_controller_id := str(trigger.get("controller_player_id", ""))
			var cacidt_source_id := str(trigger.get("source_instance_id", ""))
			var cacidt_player := MatchTimingHelpers._get_player_state(match_state, cacidt_controller_id)
			if not cacidt_player.is_empty():
				var cacidt_discard: Array = cacidt_player.get(ZONE_DISCARD, [])
				var cacidt_targets: Array = []
				for cacidt_card in cacidt_discard:
					if typeof(cacidt_card) == TYPE_DICTIONARY and str(cacidt_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						cacidt_targets.append(cacidt_card)
				if not cacidt_targets.is_empty():
					generated_events.append({"event_type": "mass_consume", "source_instance_id": cacidt_source_id, "player_id": cacidt_controller_id, "count": cacidt_targets.size()})
				for cacidt_target in cacidt_targets:
					var cacidt_result := MatchMutations.consume_card(match_state, cacidt_controller_id, cacidt_source_id, str(cacidt_target.get("instance_id", "")), {"reason": reason})
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
			var cacv_player := MatchTimingHelpers._get_player_state(match_state, cacv_controller_id)
			if not cacv_player.is_empty():
				var cacv_discard: Array = cacv_player.get(ZONE_DISCARD, [])
				var cacv_candidates: Array = []
				for cacv_card in cacv_discard:
					if typeof(cacv_card) != TYPE_DICTIONARY or str(cacv_card.get("card_type", "")) != CARD_TYPE_CREATURE:
						continue
					var cacv_triggers = cacv_card.get("triggered_abilities", [])
					if typeof(cacv_triggers) == TYPE_ARRAY:
						for cacv_t in cacv_triggers:
							if typeof(cacv_t) == TYPE_DICTIONARY and str(cacv_t.get("family", "")) == FAMILY_VETERAN:
								cacv_candidates.append(cacv_card)
								break
				if not cacv_candidates.is_empty():
					var cacv_candidate_ids: Array = []
					for cacv_c in cacv_candidates:
						cacv_candidate_ids.append(str(cacv_c.get("instance_id", "")))
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
