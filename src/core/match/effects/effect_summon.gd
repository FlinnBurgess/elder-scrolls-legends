class_name EffectSummon
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
		"summon_from_effect":
			var summon_players := MatchTargeting._resolve_player_targets(match_state, trigger, event, effect)
			if summon_players.is_empty():
				return
			var summon_lane_ids: Array = []
			if bool(effect.get("all_lanes", false)):
				for lane in match_state.get("lanes", []):
					summon_lane_ids.append(str(lane.get("lane_id", "")))
			else:
				var single_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", effect.get("lane", event.get("lane_id", "")))))
				if single_lane_id == "chosen":
					single_lane_id = str(trigger.get("_chosen_lane_id", event.get("lane_id", "")))
				if single_lane_id == "same_as_target" or single_lane_id == "same_as_marked_target":
					var _sat_target_id := ""
					if single_lane_id == "same_as_marked_target":
						var _sat_source_id := str(trigger.get("source_instance_id", ""))
						for _sat_lane in match_state.get("lanes", []):
							for _sat_pid in _sat_lane.get("player_slots", {}).keys():
								for _sat_card in _sat_lane.get("player_slots", {}).get(_sat_pid, []):
									if typeof(_sat_card) == TYPE_DICTIONARY and str(_sat_card.get("_marked_by", "")) == _sat_source_id:
										_sat_target_id = str(_sat_card.get("instance_id", ""))
					else:
						_sat_target_id = str(event.get("target_instance_id", trigger.get("_chosen_target_id", "")))
					single_lane_id = ""
					if not _sat_target_id.is_empty():
						var _sat_loc := MatchMutations.find_card_location(match_state, _sat_target_id)
						single_lane_id = str(_sat_loc.get("lane_id", ""))
				if single_lane_id == "random":
					var _rl_controller_id := str(trigger.get("controller_player_id", ""))
					var _rl_candidates: Array = []
					for _rl_lane in match_state.get("lanes", []):
						var _rl_lid := str(_rl_lane.get("lane_id", ""))
						var _rl_open := MatchTimingHelpers._get_lane_open_slots(match_state, _rl_lid, _rl_controller_id)
						if int(_rl_open.get("open_slots", 0)) > 0:
							_rl_candidates.append(_rl_lid)
					if not _rl_candidates.is_empty():
						var _rl_idx := MatchEffectParams._deterministic_index(match_state, "random_lane_%s" % str(trigger.get("source_instance_id", "")), _rl_candidates.size())
						single_lane_id = _rl_candidates[_rl_idx]
					else:
						single_lane_id = ""
				if single_lane_id == "same":
					single_lane_id = str(event.get("lane_id", ""))
				if single_lane_id == "other_lane" or single_lane_id == "other":
					var source_lane_id := str(event.get("lane_id", ""))
					if source_lane_id.is_empty():
						var tli := int(trigger.get("lane_index", -1))
						var all_lanes: Array = match_state.get("lanes", [])
						if tli >= 0 and tli < all_lanes.size():
							source_lane_id = str(all_lanes[tli].get("lane_id", ""))
					for lane in match_state.get("lanes", []):
						var lid := str(lane.get("lane_id", ""))
						if lid != source_lane_id and not lid.is_empty():
							single_lane_id = lid
							break
				if single_lane_id.is_empty() or single_lane_id == "other_lane" or single_lane_id == "other":
					var trigger_lane_index := int(trigger.get("lane_index", -1))
					var lanes: Array = match_state.get("lanes", [])
					if trigger_lane_index >= 0 and trigger_lane_index < lanes.size():
						single_lane_id = str(lanes[trigger_lane_index].get("lane_id", ""))
				if single_lane_id.is_empty() or single_lane_id == "other_lane" or single_lane_id == "other":
					return
				summon_lane_ids.append(single_lane_id)
			if bool(effect.get("require_wounded_enemy_in_lane", false)):
				var controller_id := str(trigger.get("controller_player_id", ""))
				var opp_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), controller_id)
				var filtered_lane_ids: Array = []
				for check_lane in match_state.get("lanes", []):
					var check_lid := str(check_lane.get("lane_id", ""))
					if not summon_lane_ids.has(check_lid):
						return
					var has_wounded := false
					for card in check_lane.get("player_slots", {}).get(opp_id, []):
						if typeof(card) == TYPE_DICTIONARY and int(card.get("damage_marked", 0)) > 0:
							has_wounded = true
							break
					if has_wounded:
						filtered_lane_ids.append(check_lid)
				summon_lane_ids = filtered_lane_ids
			var sfe_lane_val := str(effect.get("lane_id", effect.get("target_lane_id", effect.get("lane", ""))))
			if sfe_lane_val == "support":
				var sfe_support_template: Dictionary = effect.get("card_template", {})
				if not sfe_support_template.is_empty():
					for player_id in summon_players:
						var sfe_support_card := MatchMutations.build_generated_card(match_state, player_id, sfe_support_template)
						sfe_support_card["zone"] = ZONE_SUPPORT
						if int(sfe_support_template.get("support_uses", 0)) > 0:
							sfe_support_card["support_uses_remaining"] = int(sfe_support_template.get("support_uses", 0))
						var sfe_support_player := MatchTimingHelpers._get_player_state(match_state, player_id)
						if not sfe_support_player.is_empty():
							sfe_support_player.get(ZONE_SUPPORT, []).append(sfe_support_card)
							generated_events.append({"event_type": EVENT_CARD_PLAYED, "playing_player_id": player_id, "player_id": player_id, "source_instance_id": str(sfe_support_card.get("instance_id", "")), "source_controller_player_id": player_id, "source_zone": MatchMutations.ZONE_GENERATED, "target_zone": ZONE_SUPPORT, "card_type": "support", "reason": reason})
				return
			var summon_template: Dictionary = effect.get("card_template", {})
			if summon_template.is_empty():
				for source_card in MatchTargeting._resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source"))):
					for s_lane_id in summon_lane_ids:
						var summon_existing := MatchMutations.summon_card_to_lane(match_state, summon_players[0], str(source_card.get("instance_id", "")), s_lane_id, {
							"slot_index": int(effect.get("slot_index", -1)),
						})
						if not bool(summon_existing.get("is_valid", false)):
							return
						# Transfer ownership so the card goes to the new controller's discard when destroyed
						summon_existing["card"]["owner_player_id"] = summon_players[0]
						generated_events.append_array(summon_existing.get("events", []))
						generated_events.append(MatchSummonTiming._build_summon_event(summon_existing["card"], summon_players[0], s_lane_id, int(summon_existing.get("slot_index", -1)), reason))
						if bool(summon_existing.get("granted_cover", false)):
							generated_events.append({"event_type": "status_granted", "source_instance_id": str(summon_existing["card"].get("instance_id", "")), "target_instance_id": str(summon_existing["card"].get("instance_id", "")), "status_id": "cover"})
						_MT()._check_summon_abilities(match_state, summon_existing["card"])
			else:
				var sfe_empower_stat := int(effect.get("empower_stat_bonus", 0))
				var sfe_stat_bonus := 0
				if sfe_empower_stat > 0:
					sfe_stat_bonus = sfe_empower_stat * MatchTimingHelpers._get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
				var sfe_template := summon_template
				if sfe_stat_bonus > 0:
					sfe_template = summon_template.duplicate(true)
					sfe_template["power"] = int(sfe_template.get("power", 0)) + sfe_stat_bonus
					sfe_template["health"] = int(sfe_template.get("health", 0)) + sfe_stat_bonus
					sfe_template["base_power"] = int(sfe_template.get("base_power", 0)) + sfe_stat_bonus
					sfe_template["base_health"] = int(sfe_template.get("base_health", 0)) + sfe_stat_bonus
				var sfe_dynamic_stats := str(effect.get("dynamic_stats", ""))
				if sfe_dynamic_stats == "infestation_count":
					var sfe_dyn_player := MatchTimingHelpers._get_player_state(match_state, str(trigger.get("controller_player_id", "")))
					var sfe_dyn_count := int(sfe_dyn_player.get("_infestation_count", 0)) + 1
					sfe_dyn_player["_infestation_count"] = sfe_dyn_count
					sfe_template = summon_template.duplicate(true)
					sfe_template["power"] = sfe_dyn_count
					sfe_template["health"] = sfe_dyn_count
					sfe_template["base_power"] = sfe_dyn_count
					sfe_template["base_health"] = sfe_dyn_count
				var sfe_upgrade_subtype := str(effect.get("upgrade_if_consumed_subtype", ""))
				if not sfe_upgrade_subtype.is_empty():
					var sfe_consumed: Dictionary = trigger.get("_consumed_card_info", {})
					var sfe_consumed_subtypes = sfe_consumed.get("subtypes", [])
					if typeof(sfe_consumed_subtypes) == TYPE_ARRAY and sfe_consumed_subtypes.has(sfe_upgrade_subtype):
						var sfe_upgrade: Dictionary = effect.get("upgrade_template", {})
						if not sfe_upgrade.is_empty():
							sfe_template = sfe_upgrade
				if bool(effect.get("copy_keywords_from_consumed", false)):
					var sfe_consumed_kw: Dictionary = trigger.get("_consumed_card_info", {})
					var sfe_kw_list = sfe_consumed_kw.get("keywords", [])
					if typeof(sfe_kw_list) == TYPE_ARRAY and not sfe_kw_list.is_empty():
						sfe_template = sfe_template.duplicate(true) if sfe_template == summon_template else sfe_template
						sfe_template["keywords"] = sfe_kw_list.duplicate()
				var sfe_count := MatchEffectParams._resolve_count_multiplier(match_state, trigger, event, effect)
				for player_id in summon_players:
					for s_lane_id in summon_lane_ids:
						for _sfe_i in range(sfe_count):
							var generated_card := MatchMutations.build_generated_card(match_state, player_id, sfe_template)
							var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, generated_card, s_lane_id, {
								"slot_index": int(effect.get("slot_index", -1)),
								"source_zone": MatchMutations.ZONE_GENERATED,
							})
							if not bool(summon_result.get("is_valid", false)):
								break
							generated_events.append_array(summon_result.get("events", []))
							generated_events.append(MatchSummonTiming._build_summon_event(summon_result["card"], player_id, s_lane_id, int(summon_result.get("slot_index", -1)), reason))
							if bool(summon_result.get("granted_cover", false)):
								generated_events.append({"event_type": "status_granted", "source_instance_id": str(summon_result["card"].get("instance_id", "")), "target_instance_id": str(summon_result["card"].get("instance_id", "")), "status_id": "cover"})
							if bool(effect.get("silenced", false)):
								var silence_result := MatchMutations.silence_card(summon_result["card"], {"reason": reason}, match_state)
								generated_events.append_array(silence_result.get("events", []))
							_MT()._check_summon_abilities(match_state, summon_result["card"])
		"summon_copy":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var sc_controller := str(card.get("controller_player_id", trigger.get("controller_player_id", "")))
				var sc_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				var sc_lane_id := str(sc_loc.get("lane_id", event.get("lane_id", "field")))
				var sc_template: Dictionary = card.duplicate(true)
				sc_template.erase("instance_id")
				sc_template.erase("status_markers")
				sc_template.erase("has_attacked_this_turn")
				sc_template.erase("entered_lane_on_turn")
				var sc_copy := MatchMutations.build_generated_card(match_state, sc_controller, sc_template)
				var sc_summon := MatchMutations.summon_card_to_lane(match_state, sc_controller, sc_copy, sc_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
				if bool(sc_summon.get("is_valid", false)):
					generated_events.append_array(sc_summon.get("events", []))
					generated_events.append(MatchSummonTiming._build_summon_event(sc_summon["card"], sc_controller, sc_lane_id, int(sc_summon.get("slot_index", -1)), "summon_copy"))
					_MT()._check_summon_abilities(match_state, sc_summon["card"])
		"summon_copy_of_self":
			var scos_source_id := str(trigger.get("source_instance_id", ""))
			var scos_source := MatchTimingHelpers._find_card_anywhere(match_state, scos_source_id)
			if not scos_source.is_empty():
				var scos_controller := str(scos_source.get("controller_player_id", ""))
				var scos_loc := MatchMutations.find_card_location(match_state, scos_source_id)
				var scos_lane_id := str(scos_loc.get("lane_id", event.get("lane_id", "field")))
				var scos_template: Dictionary = scos_source.duplicate(true)
				scos_template.erase("instance_id")
				scos_template.erase("status_markers")
				scos_template.erase("has_attacked_this_turn")
				var scos_copy := MatchMutations.build_generated_card(match_state, scos_controller, scos_template)
				var scos_summon := MatchMutations.summon_card_to_lane(match_state, scos_controller, scos_copy, scos_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
				if bool(scos_summon.get("is_valid", false)):
					generated_events.append_array(scos_summon.get("events", []))
					generated_events.append(MatchSummonTiming._build_summon_event(scos_summon["card"], scos_controller, scos_lane_id, int(scos_summon.get("slot_index", -1)), "summon_copy_of_self"))
					_MT()._check_summon_abilities(match_state, scos_summon["card"])
		"summon_copies_to_lane":
			var copies_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", effect.get("lane", event.get("lane_id", "")))))
			if copies_lane_id == "chosen":
				copies_lane_id = str(trigger.get("_chosen_lane_id", event.get("lane_id", "")))
			if copies_lane_id == "same":
				copies_lane_id = str(event.get("lane_id", ""))
			if copies_lane_id == "other_lane" or copies_lane_id == "other":
				var _scl_source_lane := str(event.get("lane_id", ""))
				copies_lane_id = ""
				for _scl_lane in match_state.get("lanes", []):
					var _scl_lid := str(_scl_lane.get("lane_id", ""))
					if _scl_lid != _scl_source_lane and not _scl_lid.is_empty():
						copies_lane_id = _scl_lid
						break
			var copies_players := MatchTargeting._resolve_player_targets(match_state, trigger, event, effect)
			var copies_template: Dictionary = effect.get("card_template", {})
			if copies_lane_id.is_empty() or copies_players.is_empty() or copies_template.is_empty():
				return
			var copies_count := int(effect.get("count", 0))
			var fill_lane := bool(effect.get("fill_lane", false))
			for player_id in copies_players:
				var remaining := copies_count
				if fill_lane:
					var lane_data := MatchTimingHelpers._get_lane_open_slots(match_state, copies_lane_id, player_id)
					remaining = int(lane_data.get("open_slots", 0))
				for _i in range(remaining):
					var gen_card := MatchMutations.build_generated_card(match_state, player_id, copies_template)
					var summon_res := MatchMutations.summon_card_to_lane(match_state, player_id, gen_card, copies_lane_id, {
						"source_zone": MatchMutations.ZONE_GENERATED,
					})
					if not bool(summon_res.get("is_valid", false)):
						break
					generated_events.append_array(summon_res.get("events", []))
					generated_events.append(MatchSummonTiming._build_summon_event(summon_res["card"], player_id, copies_lane_id, int(summon_res.get("slot_index", -1)), reason))
					_MT()._check_summon_abilities(match_state, summon_res["card"])
		"summon_copy_to_other_lane":
			var copy_sources := MatchTargeting._resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source")))
			if copy_sources.is_empty():
				return
			var copy_source: Dictionary = copy_sources[0]
			var source_lane_id := str(event.get("lane_id", ""))
			var other_lane_id := ""
			for lane in match_state.get("lanes", []):
				if str(lane.get("lane_id", "")) != source_lane_id:
					other_lane_id = str(lane.get("lane_id", ""))
					break
			if other_lane_id.is_empty():
				return
			var copy_template := copy_source.duplicate(true)
			copy_template.erase("instance_id")
			copy_template.erase("zone")
			copy_template.erase("damage_marked")
			copy_template.erase("power_bonus")
			copy_template.erase("health_bonus")
			copy_template.erase("granted_keywords")
			copy_template.erase("status_markers")
			var copy_player_id := str(trigger.get("controller_player_id", ""))
			var gen_card := MatchMutations.build_generated_card(match_state, copy_player_id, copy_template)
			var summon_res := MatchMutations.summon_card_to_lane(match_state, copy_player_id, gen_card, other_lane_id, {
				"source_zone": MatchMutations.ZONE_GENERATED,
			})
			if bool(summon_res.get("is_valid", false)):
				generated_events.append_array(summon_res.get("events", []))
				generated_events.append(MatchSummonTiming._build_summon_event(summon_res["card"], copy_player_id, other_lane_id, int(summon_res.get("slot_index", -1)), reason))
				_MT()._check_summon_abilities(match_state, summon_res["card"])
		"fill_lane_with":
			var fill_controller_id := str(trigger.get("controller_player_id", ""))
			var fill_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", effect.get("lane", event.get("lane_id", "")))))
			if fill_lane_id == "chosen":
				fill_lane_id = str(trigger.get("_chosen_lane_id", event.get("lane_id", "")))
			if fill_lane_id == "same":
				fill_lane_id = str(event.get("lane_id", ""))
			if fill_lane_id == "other_lane" or fill_lane_id == "other":
				var _flt_source_lane := str(event.get("lane_id", ""))
				fill_lane_id = ""
				for _flt_lane in match_state.get("lanes", []):
					var _flt_lid := str(_flt_lane.get("lane_id", ""))
					if _flt_lid != _flt_source_lane and not _flt_lid.is_empty():
						fill_lane_id = _flt_lid
						break
			var fill_template: Dictionary = effect.get("card_template", {})
			if fill_controller_id.is_empty() or fill_template.is_empty():
				return
			var fill_lane_ids: Array = []
			if fill_lane_id == "both":
				for _fl_lane in match_state.get("lanes", []):
					fill_lane_ids.append(str(_fl_lane.get("lane_id", "")))
			elif not fill_lane_id.is_empty():
				fill_lane_ids.append(fill_lane_id)
			else:
				return
			var fill_player_ids: Array = []
			if str(effect.get("owner", "")) == "both":
				for _fp_player in match_state.get("players", []):
					fill_player_ids.append(str(_fp_player.get("player_id", "")))
			else:
				fill_player_ids.append(fill_controller_id)
			for fill_pid in fill_player_ids:
				for fill_lid in fill_lane_ids:
					var fill_open := MatchTimingHelpers._get_lane_open_slots(match_state, fill_lid, fill_pid)
					var fill_count := int(fill_open.get("open_slots", 0))
					for _i in range(fill_count):
						var fill_card := MatchMutations.build_generated_card(match_state, fill_pid, fill_template)
						var fill_result := MatchMutations.summon_card_to_lane(match_state, fill_pid, fill_card, fill_lid, {
							"source_zone": MatchMutations.ZONE_GENERATED,
						})
						if not bool(fill_result.get("is_valid", false)):
							break
						generated_events.append_array(fill_result.get("events", []))
						generated_events.append(MatchSummonTiming._build_summon_event(fill_result["card"], fill_pid, fill_lid, int(fill_result.get("slot_index", -1)), reason))
						if bool(fill_result.get("granted_cover", false)):
							generated_events.append({"event_type": "status_granted", "source_instance_id": str(fill_result["card"].get("instance_id", "")), "target_instance_id": str(fill_result["card"].get("instance_id", "")), "status_id": "cover"})
						_MT()._check_summon_abilities(match_state, fill_result["card"])
		"summon_random_from_discard":
			var srd_filter_raw = effect.get("filter", {})
			var srd_filter: Dictionary = srd_filter_raw if typeof(srd_filter_raw) == TYPE_DICTIONARY else {}
			var srd_filter_card_type := str(srd_filter.get("card_type", effect.get("required_card_type", "creature")))
			var srd_filter_subtype := str(srd_filter.get("subtype", ""))
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var srd_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if srd_player.is_empty():
					return
				var srd_discard: Array = srd_player.get(ZONE_DISCARD, [])
				var srd_candidates: Array = []
				for srd_i in range(srd_discard.size()):
					var srd_card = srd_discard[srd_i]
					if typeof(srd_card) != TYPE_DICTIONARY:
						return
					if not srd_filter_card_type.is_empty() and str(srd_card.get("card_type", "")) != srd_filter_card_type:
						return
					if not srd_filter_subtype.is_empty():
						var srd_subtypes = srd_card.get("subtypes", [])
						if typeof(srd_subtypes) != TYPE_ARRAY or not srd_subtypes.has(srd_filter_subtype):
							return
					srd_candidates.append(srd_i)
				if srd_candidates.is_empty():
					return
				var srd_pick: int = srd_candidates[MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_srd", srd_candidates.size())]
				var srd_picked: Dictionary = srd_discard[srd_pick]
				srd_discard.remove_at(srd_pick)
				MatchMutations.reset_transient_state(srd_picked)
				MatchMutations.restore_definition_state(srd_picked)
				var srd_lane_id := ""
				var srd_lane_index := int(trigger.get("lane_index", -1))
				var srd_lanes: Array = match_state.get("lanes", [])
				if srd_lane_index >= 0 and srd_lane_index < srd_lanes.size():
					srd_lane_id = str(srd_lanes[srd_lane_index].get("lane_id", ""))
				if srd_lane_id.is_empty():
					srd_lane_id = str(event.get("lane_id", ""))
				if srd_lane_id.is_empty() and not srd_lanes.is_empty():
					srd_lane_id = str(srd_lanes[0].get("lane_id", ""))
				if srd_lane_id.is_empty():
					return
				var srd_result := MatchMutations.summon_card_to_lane(match_state, player_id, srd_picked, srd_lane_id, {})
				if bool(srd_result.get("is_valid", false)):
					generated_events.append_array(srd_result.get("events", []))
					generated_events.append(MatchSummonTiming._build_summon_event(srd_result["card"], player_id, srd_lane_id, int(srd_result.get("slot_index", -1)), reason))
		"summon_from_discard":
			var sfd_controller := str(trigger.get("controller_player_id", ""))
			var sfd_player := MatchTimingHelpers._get_player_state(match_state, sfd_controller)
			if sfd_player.is_empty():
				return
			var sfd_discard: Array = sfd_player.get(ZONE_DISCARD, [])
			var sfd_source_id := str(trigger.get("source_instance_id", ""))
			var sfd_source := MatchTimingHelpers._find_card_anywhere(match_state, sfd_source_id)
			var sfd_source_power := EvergreenRules.get_power(sfd_source) if not sfd_source.is_empty() else 999
			var sfd_filter_dict: Dictionary = effect.get("filter", {}) if typeof(effect.get("filter", null)) == TYPE_DICTIONARY else {}
			var sfd_max_cost := int(sfd_filter_dict.get("max_cost", -1))
			# Build candidate list from discard
			var sfd_candidates: Array = []
			var sfd_candidate_ids: Array = []
			for di in range(sfd_discard.size()):
				var d_card: Variant = sfd_discard[di]
				if typeof(d_card) == TYPE_DICTIONARY and str(d_card.get("card_type", "")) == "creature":
					if sfd_max_cost >= 0:
						if int(d_card.get("cost", 0)) > sfd_max_cost:
							return
					elif EvergreenRules.get_power(d_card) >= sfd_source_power:
						return
					sfd_candidates.append(di)
					sfd_candidate_ids.append(str(d_card.get("instance_id", "")))
			if sfd_candidates.is_empty():
				return
			var sfd_chosen_id := str(trigger.get("_chosen_target_id", ""))
			if sfd_chosen_id.is_empty():
				# Push pending discard choice for UI
				match_state["pending_discard_choices"].append({
					"player_id": sfd_controller,
					"source_instance_id": sfd_source_id,
					"candidate_instance_ids": sfd_candidate_ids,
					"then_op": "summon_from_discard",
					"reason": "summon_from_discard",
				})
				generated_events.append({"event_type": "discard_choice_pending", "player_id": sfd_controller})
				return
			# Resolve with chosen target
			var sfd_card: Dictionary = {}
			var sfd_idx := -1
			for di in range(sfd_discard.size()):
				if typeof(sfd_discard[di]) == TYPE_DICTIONARY and str(sfd_discard[di].get("instance_id", "")) == sfd_chosen_id:
					sfd_card = sfd_discard[di]
					sfd_idx = di
					break
			if sfd_card.is_empty() or sfd_idx < 0:
				return
			sfd_discard.remove_at(sfd_idx)
			MatchMutations.restore_definition_state(sfd_card)
			var sfd_source_loc := MatchMutations.find_card_location(match_state, sfd_source_id)
			var sfd_lane_id := str(sfd_source_loc.get("lane_id", ""))
			if sfd_lane_id.is_empty():
				sfd_lane_id = str(event.get("lane_id", "field"))
			var sfd_summon := MatchMutations.summon_card_to_lane(match_state, sfd_controller, sfd_card, sfd_lane_id, {"source_zone": ZONE_DISCARD})
			if bool(sfd_summon.get("is_valid", false)):
				generated_events.append_array(sfd_summon.get("events", []))
				generated_events.append(MatchSummonTiming._build_summon_event(sfd_summon["card"], sfd_controller, sfd_lane_id, int(sfd_summon.get("slot_index", -1)), "summon_from_discard"))
		"summon_from_discard_highest_cost":
			var sfdh_controller_id := str(trigger.get("controller_player_id", ""))
			var sfdh_player := MatchTimingHelpers._get_player_state(match_state, sfdh_controller_id)
			if not sfdh_player.is_empty():
				var sfdh_discard: Array = sfdh_player.get(ZONE_DISCARD, [])
				var sfdh_best: Dictionary = {}
				var sfdh_best_cost := -1
				for sfdh_card in sfdh_discard:
					if typeof(sfdh_card) == TYPE_DICTIONARY and str(sfdh_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						var c := int(sfdh_card.get("cost", 0))
						if c > sfdh_best_cost:
							sfdh_best_cost = c
							sfdh_best = sfdh_card
				if not sfdh_best.is_empty():
					var sfdh_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, sfdh_controller_id)
					if not sfdh_lane_id.is_empty():
						sfdh_discard.erase(sfdh_best)
						MatchMutations.restore_definition_state(sfdh_best)
						sfdh_best.erase("zone")
						var sfdh_result := MatchMutations.summon_card_to_lane(match_state, sfdh_controller_id, sfdh_best, sfdh_lane_id, {"source_zone": ZONE_DISCARD})
						if bool(sfdh_result.get("is_valid", false)):
							generated_events.append_array(sfdh_result.get("events", []))
							generated_events.append(MatchSummonTiming._build_summon_event(sfdh_result["card"], sfdh_controller_id, sfdh_lane_id, int(sfdh_result.get("slot_index", -1)), reason))
							var sfdh_grant_kw := str(effect.get("grant_keyword", ""))
							if not sfdh_grant_kw.is_empty():
								EvergreenRules.ensure_card_state(sfdh_result["card"])
								var sfdh_gk: Array = sfdh_result["card"].get("granted_keywords", [])
								if not sfdh_gk.has(sfdh_grant_kw):
									sfdh_gk.append(sfdh_grant_kw)
									sfdh_result["card"]["granted_keywords"] = sfdh_gk
							if bool(effect.get("return_to_deck_end_of_turn", false)):
								sfdh_result["card"]["_return_to_deck_end_of_turn"] = true
							_MT()._check_summon_abilities(match_state, sfdh_result["card"])
		"summon_from_opponent_discard":
			var sfod_controller_id := str(trigger.get("controller_player_id", ""))
			var sfod_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), sfod_controller_id)
			var sfod_opponent := MatchTimingHelpers._get_player_state(match_state, sfod_opponent_id)
			if not sfod_opponent.is_empty():
				var sfod_discard: Array = sfod_opponent.get(ZONE_DISCARD, [])
				var sfod_candidates: Array = []
				for sfod_card in sfod_discard:
					if typeof(sfod_card) == TYPE_DICTIONARY and str(sfod_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						sfod_candidates.append(sfod_card)
				if not sfod_candidates.is_empty():
					var sfod_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_summon_opp_discard", sfod_candidates.size())
					var sfod_target: Dictionary = sfod_candidates[sfod_idx]
					sfod_discard.erase(sfod_target)
					MatchMutations.restore_definition_state(sfod_target)
					sfod_target.erase("zone")
					sfod_target["controller_player_id"] = sfod_controller_id
					sfod_target["owner_player_id"] = sfod_controller_id
					var sfod_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, sfod_controller_id)
					if not sfod_lane_id.is_empty():
						var sfod_result := MatchMutations.summon_card_to_lane(match_state, sfod_controller_id, sfod_target, sfod_lane_id, {"source_zone": ZONE_DISCARD})
						if bool(sfod_result.get("is_valid", false)):
							generated_events.append_array(sfod_result.get("events", []))
							generated_events.append(MatchSummonTiming._build_summon_event(sfod_result["card"], sfod_controller_id, sfod_lane_id, int(sfod_result.get("slot_index", -1)), reason))
							_MT()._check_summon_abilities(match_state, sfod_result["card"])
		"summon_top_creature_from_deck":
			var stcfd_controller_id := str(trigger.get("controller_player_id", ""))
			var stcfd_player := MatchTimingHelpers._get_player_state(match_state, stcfd_controller_id)
			if not stcfd_player.is_empty():
				var stcfd_deck: Array = stcfd_player.get(ZONE_DECK, [])
				var stcfd_found: Dictionary = {}
				var stcfd_found_idx := -1
				for i in range(stcfd_deck.size() - 1, -1, -1):
					var stcfd_card: Dictionary = stcfd_deck[i]
					if str(stcfd_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						stcfd_found = stcfd_card
						stcfd_found_idx = i
						break
				if not stcfd_found.is_empty():
					stcfd_deck.remove_at(stcfd_found_idx)
					stcfd_found.erase("zone")
					var stcfd_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, stcfd_controller_id)
					if not stcfd_lane_id.is_empty():
						var stcfd_result := MatchMutations.summon_card_to_lane(match_state, stcfd_controller_id, stcfd_found, stcfd_lane_id, {"source_zone": ZONE_DECK})
						if bool(stcfd_result.get("is_valid", false)):
							generated_events.append_array(stcfd_result.get("events", []))
							generated_events.append(MatchSummonTiming._build_summon_event(stcfd_result["card"], stcfd_controller_id, stcfd_lane_id, int(stcfd_result.get("slot_index", -1)), reason))
							_MT()._check_summon_abilities(match_state, stcfd_result["card"])
		"summon_from_deck_by_cost":
			var sfdc_controller_id := str(trigger.get("controller_player_id", ""))
			var sfdc_player := MatchTimingHelpers._get_player_state(match_state, sfdc_controller_id)
			if not sfdc_player.is_empty():
				var sfdc_deck: Array = sfdc_player.get(ZONE_DECK, [])
				var sfdc_max_cost := int(effect.get("max_cost", 999))
				var sfdc_min_cost := int(effect.get("min_cost", 0))
				var sfdc_exact_cost := int(effect.get("exact_cost", -1))
				var sfdc_filter_type := str(effect.get("filter_card_type", CARD_TYPE_CREATURE))
				var sfdc_candidates: Array = []
				for sfdc_card in sfdc_deck:
					if str(sfdc_card.get("card_type", "")) != sfdc_filter_type:
						return
					var sfdc_cost := int(sfdc_card.get("cost", 0))
					if sfdc_exact_cost >= 0 and sfdc_cost != sfdc_exact_cost:
						return
					if sfdc_cost < sfdc_min_cost or sfdc_cost > sfdc_max_cost:
						return
					sfdc_candidates.append(sfdc_card)
				if not sfdc_candidates.is_empty():
					var sfdc_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_deck_summon", sfdc_candidates.size())
					var sfdc_target: Dictionary = sfdc_candidates[sfdc_idx]
					sfdc_deck.erase(sfdc_target)
					sfdc_target.erase("zone")
					var sfdc_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, sfdc_controller_id)
					if not sfdc_lane_id.is_empty():
						var sfdc_result := MatchMutations.summon_card_to_lane(match_state, sfdc_controller_id, sfdc_target, sfdc_lane_id, {"source_zone": ZONE_DECK})
						if bool(sfdc_result.get("is_valid", false)):
							generated_events.append_array(sfdc_result.get("events", []))
							generated_events.append(MatchSummonTiming._build_summon_event(sfdc_result["card"], sfdc_controller_id, sfdc_lane_id, int(sfdc_result.get("slot_index", -1)), reason))
							_MT()._check_summon_abilities(match_state, sfdc_result["card"])
		"summon_from_deck_filtered":
			var sfdf_controller_id := str(trigger.get("controller_player_id", ""))
			var sfdf_player := MatchTimingHelpers._get_player_state(match_state, sfdf_controller_id)
			if not sfdf_player.is_empty():
				var sfdf_deck: Array = sfdf_player.get(ZONE_DECK, [])
				# Read filter from nested "filter" dict or top-level effect fields
				var sfdf_filter: Dictionary = effect.get("filter", {})
				if typeof(sfdf_filter) != TYPE_DICTIONARY:
					sfdf_filter = {}
				var sfdf_filter_subtype := str(sfdf_filter.get("subtype", effect.get("filter_subtype", "")))
				var sfdf_filter_attribute := str(sfdf_filter.get("attribute", effect.get("filter_attribute", "")))
				var sfdf_filter_type := str(sfdf_filter.get("card_type", effect.get("filter_card_type", CARD_TYPE_CREATURE)))
				var sfdf_exclude_unique := bool(sfdf_filter.get("exclude_unique", false))
				# Cost filtering
				var sfdf_max_cost := int(sfdf_filter.get("max_cost", effect.get("max_cost", -1)))
				var sfdf_max_cost_source := str(sfdf_filter.get("max_cost_source", ""))
				if sfdf_max_cost_source == "self_power":
					var sfdf_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if not sfdf_source.is_empty():
						sfdf_max_cost = EvergreenRules.get_power(sfdf_source)
				var sfdf_candidates: Array = []
				for sfdf_card in sfdf_deck:
					if str(sfdf_card.get("card_type", "")) != sfdf_filter_type:
						return
					if sfdf_exclude_unique and bool(sfdf_card.get("is_unique", false)):
						return
					if sfdf_max_cost >= 0 and int(sfdf_card.get("cost", 0)) >= sfdf_max_cost:
						return
					if not sfdf_filter_subtype.is_empty():
						var sfdf_subtypes = sfdf_card.get("subtypes", [])
						if typeof(sfdf_subtypes) != TYPE_ARRAY or not sfdf_subtypes.has(sfdf_filter_subtype):
							return
					if not sfdf_filter_attribute.is_empty():
						var sfdf_attrs = sfdf_card.get("attributes", [])
						if typeof(sfdf_attrs) != TYPE_ARRAY or not sfdf_attrs.has(sfdf_filter_attribute):
							return
					sfdf_candidates.append(sfdf_card)
				if not sfdf_candidates.is_empty():
					var sfdf_candidate_ids: Array = []
					for sfdf_c in sfdf_candidates:
						sfdf_candidate_ids.append(str(sfdf_c.get("instance_id", "")))
					var sfdf_then_op := "summon_support_from_deck" if sfdf_filter_type == "support" else "summon_creature_from_deck"
					var sfdf_then_context := {"reason": reason}
					if sfdf_filter_type != "support":
						sfdf_then_context["lane_id"] = MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, sfdf_controller_id)
					var sfdf_pending: Array = match_state.get("pending_deck_selections", [])
					sfdf_pending.append({
						"player_id": sfdf_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"candidate_instance_ids": sfdf_candidate_ids,
						"then_op": sfdf_then_op,
						"then_context": sfdf_then_context,
						"prompt": "Choose a card from your deck.",
					})
		"summon_all_from_discard_by_name":
			var safdbn_controller_id := str(trigger.get("controller_player_id", ""))
			var safdbn_name := str(effect.get("card_name", ""))
			if safdbn_name.is_empty():
				var safdbn_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				safdbn_name = str(safdbn_source.get("name", ""))
			var safdbn_player := MatchTimingHelpers._get_player_state(match_state, safdbn_controller_id)
			if not safdbn_player.is_empty() and not safdbn_name.is_empty():
				var safdbn_discard: Array = safdbn_player.get(ZONE_DISCARD, [])
				var safdbn_matches: Array = []
				for safdbn_card in safdbn_discard:
					if str(safdbn_card.get("name", "")) == safdbn_name:
						safdbn_matches.append(safdbn_card)
				for safdbn_card in safdbn_matches:
					safdbn_discard.erase(safdbn_card)
					MatchMutations.restore_definition_state(safdbn_card)
					safdbn_card.erase("zone")
					var safdbn_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, safdbn_controller_id)
					if not safdbn_lane_id.is_empty():
						var safdbn_result := MatchMutations.summon_card_to_lane(match_state, safdbn_controller_id, safdbn_card, safdbn_lane_id, {"source_zone": ZONE_DISCARD})
						if bool(safdbn_result.get("is_valid", false)):
							generated_events.append_array(safdbn_result.get("events", []))
							generated_events.append(MatchSummonTiming._build_summon_event(safdbn_result["card"], safdbn_controller_id, safdbn_lane_id, int(safdbn_result.get("slot_index", -1)), reason))
		"summon_each_unique_from_deck":
			var seufd_controller_id := str(trigger.get("controller_player_id", ""))
			var seufd_player := MatchTimingHelpers._get_player_state(match_state, seufd_controller_id)
			if not seufd_player.is_empty():
				var seufd_deck: Array = seufd_player.get(ZONE_DECK, [])
				var seufd_filter_dict: Dictionary = effect.get("filter", {}) if typeof(effect.get("filter", null)) == TYPE_DICTIONARY else {}
				var seufd_max_cost := int(seufd_filter_dict.get("max_cost", -1))
				var seufd_filter_subtype := str(seufd_filter_dict.get("subtype", ""))
				var seufd_costs_seen: Dictionary = {}
				var seufd_to_summon: Array = []
				# Scan from top of deck
				for i in range(seufd_deck.size() - 1, -1, -1):
					var seufd_card: Dictionary = seufd_deck[i]
					if str(seufd_card.get("card_type", "")) != CARD_TYPE_CREATURE:
						return
					var seufd_cost := int(seufd_card.get("cost", 0))
					if seufd_max_cost >= 0 and seufd_cost > seufd_max_cost:
						return
					if not seufd_filter_subtype.is_empty():
						var seufd_subtypes = seufd_card.get("subtypes", [])
						if typeof(seufd_subtypes) != TYPE_ARRAY or not seufd_subtypes.has(seufd_filter_subtype):
							return
					if seufd_costs_seen.has(seufd_cost):
						return
					seufd_costs_seen[seufd_cost] = true
					seufd_to_summon.append(seufd_card)
				for seufd_card in seufd_to_summon:
					seufd_deck.erase(seufd_card)
					seufd_card.erase("zone")
					var seufd_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, seufd_controller_id)
					if not seufd_lane_id.is_empty():
						var seufd_result := MatchMutations.summon_card_to_lane(match_state, seufd_controller_id, seufd_card, seufd_lane_id, {"source_zone": ZONE_DECK})
						if bool(seufd_result.get("is_valid", false)):
							generated_events.append_array(seufd_result.get("events", []))
							generated_events.append(MatchSummonTiming._build_summon_event(seufd_result["card"], seufd_controller_id, seufd_lane_id, int(seufd_result.get("slot_index", -1)), reason))
		"summon_random_from_collection":
			# Delegate to summon_random_from_catalog with collection filter
			var srfcoll_raw_filter = effect.get("filter", {})
			var srfcoll_src_filter: Dictionary = srfcoll_raw_filter if typeof(srfcoll_raw_filter) == TYPE_DICTIONARY else {}
			var srfcoll_filter: Dictionary = {"card_type": str(srfcoll_src_filter.get("card_type", "creature"))}
			var srfcoll_subtype := str(srfcoll_src_filter.get("subtype", effect.get("filter_subtype", "")))
			if not srfcoll_subtype.is_empty():
				srfcoll_filter["required_subtype"] = srfcoll_subtype
			if srfcoll_src_filter.has("min_cost"):
				srfcoll_filter["min_cost"] = int(srfcoll_src_filter.get("min_cost", 0))
			if srfcoll_src_filter.has("max_cost"):
				srfcoll_filter["max_cost"] = int(srfcoll_src_filter.get("max_cost", 0))
			if srfcoll_src_filter.has("exact_cost"):
				srfcoll_filter["exact_cost"] = int(srfcoll_src_filter.get("exact_cost", 0))
			var srfcoll_delegated := {"op": "summon_random_from_catalog", "filter": srfcoll_filter}
			var srfcoll_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, srfcoll_delegated)
			if bool(srfcoll_result.get("handled", false)):
				generated_events.append_array(srfcoll_result.get("events", []))
		"summon_random_daedra_by_gate_level":
			var srdg_controller_id := str(trigger.get("controller_player_id", ""))
			var srdg_gate := ExtendedMechanicPacks._find_player_gate(match_state, srdg_controller_id)
			var srdg_gate_level := int(srdg_gate.get("gate_level", 0))
			if srdg_gate.is_empty() or srdg_gate_level <= 0:
				return
			var srdg_filter: Dictionary = {"card_type": "creature", "required_subtype": "Daedra", "exact_cost": srdg_gate_level}
			var srdg_delegated := {"op": "summon_random_from_catalog", "filter": srdg_filter}
			var srdg_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, srdg_delegated)
			if bool(srdg_result.get("handled", false)):
				generated_events.append_array(srdg_result.get("events", []))
		"summon_random_daedra_total_cost":
			var srd_controller_id := str(trigger.get("controller_player_id", ""))
			var srd_budget := int(effect.get("total_cost", 10))
			var srd_summon_count := int(effect.get("_summon_count", 0))
			var srd_events = _MT()._run_budget_summon_loop(match_state, trigger, srd_controller_id, srd_budget, srd_summon_count)
			generated_events.append_array(srd_events)
		"summon_or_buff":
			# Aldora the Daring — summon token or buff existing token
			var sob_controller_id := str(trigger.get("controller_player_id", ""))
			var sob_template: Dictionary = effect.get("card_template", {})
			var sob_target_def_id := str(sob_template.get("definition_id", ""))
			# Look for an existing friendly creature matching the template's definition_id
			var sob_existing: Dictionary = {}
			if not sob_target_def_id.is_empty():
				for sob_lane in match_state.get("lanes", []):
					for sob_card in sob_lane.get("player_slots", {}).get(sob_controller_id, []):
						if typeof(sob_card) == TYPE_DICTIONARY and str(sob_card.get("definition_id", "")) == sob_target_def_id:
							sob_existing = sob_card
							break
					if not sob_existing.is_empty():
						break
			if sob_existing.is_empty() and not sob_template.is_empty():
				# No existing token — summon one
				var sob_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, sob_controller_id)
				if not sob_lane_id.is_empty():
					var sob_card := MatchMutations.build_generated_card(match_state, sob_controller_id, sob_template)
					var sob_result := MatchMutations.summon_card_to_lane(match_state, sob_controller_id, sob_card, sob_lane_id, {"source_zone": ZONE_GENERATED})
					if bool(sob_result.get("is_valid", false)):
						generated_events.append_array(sob_result.get("events", []))
						generated_events.append(MatchSummonTiming._build_summon_event(sob_result["card"], sob_controller_id, sob_lane_id, int(sob_result.get("slot_index", -1)), reason))
			elif not sob_existing.is_empty():
				# Token exists — buff it
				var sob_power := int(effect.get("buff_power", 1))
				var sob_health := int(effect.get("buff_health", 1))
				EvergreenRules.apply_stat_bonus(sob_existing, sob_power, sob_health, reason)
				generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(sob_existing.get("instance_id", "")), "power_bonus": sob_power, "health_bonus": sob_health, "reason": reason})
		"summon_from_hand_to_full_lane":
			# Allow summoning into a full lane by not checking capacity
			var sfhtfl_controller_id := str(trigger.get("controller_player_id", ""))
			var sfhtfl_player := MatchTimingHelpers._get_player_state(match_state, sfhtfl_controller_id)
			if not sfhtfl_player.is_empty():
				var sfhtfl_hand: Array = sfhtfl_player.get(ZONE_HAND, [])
				var sfhtfl_creatures: Array = []
				for sfhtfl_card in sfhtfl_hand:
					if str(sfhtfl_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						sfhtfl_creatures.append(str(sfhtfl_card.get("instance_id", "")))
				if not sfhtfl_creatures.is_empty():
					match_state["pending_hand_selections"].append({
						"player_id": sfhtfl_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"candidate_instance_ids": sfhtfl_creatures,
						"then_op": "summon_from_hand_ignore_capacity",
						"then_context": {},
						"prompt": "Choose a creature from your hand to summon.",
					})
		"summon_random_creature", "summon_random_by_cost":
			# Delegate to summon_random_from_catalog with appropriate filters
			var src_filter: Dictionary = {"card_type": "creature"}
			if op == "summon_random_by_cost":
				var src_exact_cost := int(effect.get("cost", effect.get("exact_cost", -1)))
				if src_exact_cost >= 0:
					src_filter["max_cost"] = src_exact_cost
					src_filter["min_cost"] = src_exact_cost
			var src_max_cost := int(effect.get("max_cost", -1))
			if src_max_cost >= 0:
				var src_empower_cost := int(effect.get("empower_bonus_cost", 0))
				if src_empower_cost > 0:
					src_max_cost += src_empower_cost * MatchTimingHelpers._get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
				src_filter["max_cost"] = src_max_cost
			var src_delegated := {"op": "summon_random_from_catalog", "filter": src_filter}
			for src_key in ["lane_id", "target_lane_id"]:
				if effect.has(src_key):
					src_delegated[src_key] = effect[src_key]
			var src_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, src_delegated)
			if bool(src_result.get("handled", false)):
				generated_events.append_array(src_result.get("events", []))
