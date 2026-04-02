class_name EffectTriggers
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
		"grant_triggered_ability":
			var gta_ability: Dictionary = effect.get("ability", {})
			var gta_label := str(effect.get("assemble_label", ""))
			var gta_text_template := str(effect.get("text_template", ""))
			if not gta_ability.is_empty():
				for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
					var abilities: Array = card.get("triggered_abilities", [])
					var gta_stacked := false
					if not gta_label.is_empty():
						for existing in abilities:
							if typeof(existing) == TYPE_DICTIONARY and str(existing.get("_assemble_label", "")) == gta_label:
								# Stack: increase the amount in existing effects
								for ex_eff in existing.get("effects", []):
									if typeof(ex_eff) == TYPE_DICTIONARY and ex_eff.has("amount"):
										ex_eff["amount"] = int(ex_eff.get("amount", 0)) + int(gta_ability.get("effects", [{}])[0].get("amount", 0))
								gta_stacked = true
								break
					if not gta_stacked:
						var new_ability := gta_ability.duplicate(true)
						if not gta_label.is_empty():
							new_ability["_assemble_label"] = gta_label
						abilities.append(new_ability)
					card["triggered_abilities"] = abilities
					# Update rules_text with assembled effect description
					if not gta_text_template.is_empty():
						MatchTimingHelpers._update_assemble_rules_text(card, gta_label, gta_text_template)
					generated_events.append({
						"event_type": "triggered_ability_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"ability_family": str(gta_ability.get("family", "")),
					})
		"copy_summon_ability":
			# Copy a creature's summon triggers and re-fire them as the copier's own
			var csa_source_id := str(trigger.get("source_instance_id", ""))
			var csa_controller_id := str(trigger.get("controller_player_id", ""))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var csa_triggers = card.get("triggered_abilities", [])
				if typeof(csa_triggers) != TYPE_ARRAY:
					return
				for csa_trigger in csa_triggers:
					if typeof(csa_trigger) != TYPE_DICTIONARY:
						return
					if str(csa_trigger.get("family", "")) == FAMILY_SUMMON:
						var csa_tm := str(csa_trigger.get("target_mode", ""))
						if not csa_tm.is_empty():
							# Target-mode ability: grant copied ability to source and create pending selection
							var csa_valid := MatchTargeting.get_valid_targets_for_mode(match_state, csa_source_id, csa_tm, csa_trigger)
							if not csa_valid.is_empty():
								var csa_source_card := MatchTimingHelpers._find_card_anywhere(match_state, csa_source_id)
								if not csa_source_card.is_empty():
									var csa_copied: Dictionary = csa_trigger.duplicate(true)
									csa_copied["_is_copied_summon"] = true
									var src_abilities: Array = csa_source_card.get("triggered_abilities", [])
									src_abilities.append(csa_copied)
									var csa_pending: Array = match_state.get("pending_summon_effect_targets", [])
									csa_pending.append({
										"player_id": csa_controller_id,
										"source_instance_id": csa_source_id,
										"mandatory": false,
										"allowed_families": [FAMILY_SUMMON],
									})
						else:
							# No target_mode: fire effects directly as the copier
							var csa_location := MatchMutations.find_card_location(match_state, csa_source_id)
							var csa_fake_event := {
								"event_type": EVENT_CREATURE_SUMMONED,
								"source_instance_id": csa_source_id,
								"source_controller_player_id": csa_controller_id,
								"player_id": csa_controller_id,
								"lane_id": str(csa_location.get("lane_id", "")),
								"lane_index": int(csa_location.get("lane_index", -1)),
							}
							var csa_synth_trigger: Dictionary = csa_trigger.duplicate(true)
							csa_synth_trigger["source_instance_id"] = csa_source_id
							csa_synth_trigger["controller_player_id"] = csa_controller_id
							csa_synth_trigger["lane_index"] = int(csa_location.get("lane_index", -1))
							csa_synth_trigger["descriptor"] = csa_trigger.duplicate(true)
							var csa_resolution := {"effects": csa_synth_trigger.get("effects", [])}
							generated_events.append_array(_MT()._apply_effects(match_state, csa_synth_trigger, csa_fake_event, csa_resolution))
						break
		"trigger_summon_ability":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var tsa_abilities: Array = card.get("triggered_abilities", [])
				for ability in tsa_abilities:
					if typeof(ability) != TYPE_DICTIONARY:
						return
					if str(ability.get("family", "")) == FAMILY_SUMMON:
						var tsa_tm := str(ability.get("target_mode", ""))
						if not tsa_tm.is_empty():
							var tsa_card_id := str(card.get("instance_id", ""))
							var tsa_valid := MatchTargeting.get_valid_targets_for_mode(match_state, tsa_card_id, tsa_tm, ability)
							if not tsa_valid.is_empty():
								var tsa_pending: Array = match_state.get("pending_summon_effect_targets", [])
								tsa_pending.append({
									"player_id": str(card.get("controller_player_id", "")),
									"source_instance_id": tsa_card_id,
									"mandatory": false,
									"allowed_families": [FAMILY_SUMMON],
								})
						else:
							var tsa_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
							var tsa_fake_event := {
								"event_type": EVENT_CREATURE_SUMMONED,
								"source_instance_id": str(card.get("instance_id", "")),
								"source_controller_player_id": str(card.get("controller_player_id", "")),
								"player_id": str(card.get("controller_player_id", "")),
								"lane_id": str(tsa_loc.get("lane_id", "")),
								"lane_index": int(tsa_loc.get("lane_index", -1)),
							}
							var tsa_trigger: Dictionary = ability.duplicate(true)
							tsa_trigger["source_instance_id"] = str(card.get("instance_id", ""))
							tsa_trigger["controller_player_id"] = str(card.get("controller_player_id", ""))
							tsa_trigger["lane_index"] = int(tsa_loc.get("lane_index", -1))
							tsa_trigger["descriptor"] = ability.duplicate(true)
							var tsa_resolution := {"effects": tsa_trigger.get("effects", [])}
							generated_events.append_array(_MT()._apply_effects(match_state, tsa_trigger, tsa_fake_event, tsa_resolution))
						break
		"trigger_friendly_last_gasps":
			var tflg_controller_id := str(trigger.get("controller_player_id", ""))
			var tflg_self_id := str(trigger.get("source_instance_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(tflg_controller_id, []):
					if typeof(card) != TYPE_DICTIONARY:
						continue
					if str(card.get("instance_id", "")) == tflg_self_id:
						continue
					var raw_triggers = card.get("triggered_abilities", [])
					if typeof(raw_triggers) != TYPE_ARRAY:
						continue
					for raw_trigger in raw_triggers:
						if typeof(raw_trigger) != TYPE_DICTIONARY:
							continue
						if str(raw_trigger.get("family", "")) != FAMILY_LAST_GASP:
							continue
						var fake_trigger := {
							"trigger_id": str(card.get("instance_id", "")) + "_retrigger_lg",
							"source_instance_id": str(card.get("instance_id", "")),
							"controller_player_id": tflg_controller_id,
							"owner_player_id": str(card.get("owner_player_id", tflg_controller_id)),
							"source_zone": ZONE_LANE,
							"lane_index": int(card.get("lane_index", -1)),
							"descriptor": raw_trigger.duplicate(true),
						}
						var fake_event := {"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "source_instance_id": str(card.get("instance_id", "")), "controller_player_id": tflg_controller_id, "lane_id": str(card.get("lane_id", "")), "lane_index": int(card.get("lane_index", -1))}
						var fake_resolution := MatchTriggers._build_trigger_resolution(match_state, fake_trigger, fake_event)
						generated_events.append_array(_MT()._apply_effects(match_state, fake_trigger, fake_event, fake_resolution))
		"trigger_exalt_all_friendly":
			var teaf_controller := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(teaf_controller, []):
					if typeof(card) != TYPE_DICTIONARY:
						continue
					var teaf_abilities: Array = card.get("triggered_abilities", [])
					for ability in teaf_abilities:
						if typeof(ability) != TYPE_DICTIONARY:
							continue
						if str(ability.get("family", "")) != FAMILY_SUMMON:
							continue
						var teaf_exalt_cost := int(ability.get("exalt_cost", 0))
						if teaf_exalt_cost <= 0:
							continue
						if EvergreenRules.has_status(card, EvergreenRules.STATUS_EXALTED):
							continue
						EvergreenRules.add_status(card, EvergreenRules.STATUS_EXALTED)
						var teaf_tm := str(ability.get("target_mode", ""))
						if not teaf_tm.is_empty():
							# Targeted exalt — queue pending target selection
							var teaf_card_id := str(card.get("instance_id", ""))
							var teaf_valid := MatchTargeting.get_valid_targets_for_mode(match_state, teaf_card_id, teaf_tm, ability)
							if not teaf_valid.is_empty():
								var teaf_pending: Array = match_state.get("pending_summon_effect_targets", [])
								teaf_pending.append({
									"player_id": teaf_controller,
									"source_instance_id": teaf_card_id,
									"mandatory": false,
									"allowed_families": [FAMILY_SUMMON],
								})
						else:
							var teaf_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
							var teaf_trigger: Dictionary = ability.duplicate(true)
							teaf_trigger["source_instance_id"] = str(card.get("instance_id", ""))
							teaf_trigger["controller_player_id"] = teaf_controller
							teaf_trigger["lane_index"] = int(teaf_loc.get("lane_index", -1))
							teaf_trigger["descriptor"] = ability.duplicate(true)
							generated_events.append_array(_MT()._apply_effects(match_state, teaf_trigger, event, {"effects": teaf_trigger.get("effects", [])}))
						generated_events.append({"event_type": "exalt_triggered", "instance_id": str(card.get("instance_id", "")), "reason": reason})
						break
		"trigger_all_friendly_summons":
			var tafs_controller_id := str(trigger.get("controller_player_id", ""))
			var tafs_creatures := MatchTimingHelpers._player_lane_creatures(match_state, tafs_controller_id)
			generated_events.append({"event_type": "summons_retriggered", "source_instance_id": str(trigger.get("source_instance_id", "")), "controller_player_id": tafs_controller_id, "count": tafs_creatures.size()})
			for card in tafs_creatures:
				var tafs_lane_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				var tafs_lane_id := str(tafs_lane_location.get("lane_id", ""))
				generated_events.append({
					"event_type": EVENT_CREATURE_SUMMONED,
					"player_id": tafs_controller_id,
					"playing_player_id": tafs_controller_id,
					"source_instance_id": str(card.get("instance_id", "")),
					"source_controller_player_id": tafs_controller_id,
					"lane_id": tafs_lane_id,
					"reason": "trigger_all_friendly_summons",
				})
				_MT()._check_summon_abilities(match_state, card)
		"trigger_wax":
			var tw_source_id := str(trigger.get("source_instance_id", ""))
			var tw_controller_id := str(trigger.get("controller_player_id", ""))
			generated_events.append_array(_MT()._fire_wax_wane_on_other_friendly(match_state, tw_controller_id, tw_source_id, FAMILY_WAX))
		"trigger_wane":
			var twn_source_id := str(trigger.get("source_instance_id", ""))
			var twn_controller_id := str(trigger.get("controller_player_id", ""))
			generated_events.append_array(_MT()._fire_wax_wane_on_other_friendly(match_state, twn_controller_id, twn_source_id, FAMILY_WANE))
		"enable_dual_wax_wane":
			var edww_controller_id := str(trigger.get("controller_player_id", ""))
			var edww_player := MatchTimingHelpers._get_player_state(match_state, edww_controller_id)
			if not edww_player.is_empty():
				edww_player["_dual_wax_wane"] = true
		"repeat_slay_reward":
			# Re-fire the killing creature's slay trigger effects
			var rsr_killer_id := str(event.get("destroyed_by_instance_id", ""))
			var rsr_killer := MatchTimingHelpers._find_card_anywhere(match_state, rsr_killer_id)
			if not rsr_killer.is_empty():
				var rsr_controller := str(rsr_killer.get("controller_player_id", ""))
				# Collect slay descriptors: own triggered_abilities + granted triggers from friendly cards
				var rsr_slay_descs: Array = []
				var rsr_raw_triggers = rsr_killer.get("triggered_abilities", [])
				if typeof(rsr_raw_triggers) == TYPE_ARRAY:
					for rsr_desc in rsr_raw_triggers:
						if typeof(rsr_desc) == TYPE_DICTIONARY and str(rsr_desc.get("family", "")) == FAMILY_SLAY:
							rsr_slay_descs.append(rsr_desc)
				# Also check grants_trigger from friendly lane creatures and supports
				for rsr_lane in match_state.get("lanes", []):
					for rsr_card in rsr_lane.get("player_slots", {}).get(rsr_controller, []):
						if typeof(rsr_card) != TYPE_DICTIONARY:
							return
						var rsr_grants = rsr_card.get("grants_trigger", [])
						if typeof(rsr_grants) != TYPE_ARRAY:
							return
						for rsr_grant in rsr_grants:
							if typeof(rsr_grant) != TYPE_DICTIONARY or str(rsr_grant.get("family", "")) != FAMILY_SLAY:
								return
							var rsr_req_kw := str(rsr_grant.get("required_keyword", ""))
							if not rsr_req_kw.is_empty() and not EvergreenRules.has_keyword(rsr_killer, rsr_req_kw):
								return
							rsr_slay_descs.append(rsr_grant)
				for rsr_support in MatchTimingHelpers._get_player_state(match_state, rsr_controller).get(ZONE_SUPPORT, []):
					if typeof(rsr_support) != TYPE_DICTIONARY:
						return
					var rsr_grants = rsr_support.get("grants_trigger", [])
					if typeof(rsr_grants) != TYPE_ARRAY:
						return
					for rsr_grant in rsr_grants:
						if typeof(rsr_grant) != TYPE_DICTIONARY or str(rsr_grant.get("family", "")) != FAMILY_SLAY:
							return
						var rsr_req_kw := str(rsr_grant.get("required_keyword", ""))
						if not rsr_req_kw.is_empty() and not EvergreenRules.has_keyword(rsr_killer, rsr_req_kw):
							return
						rsr_slay_descs.append(rsr_grant)
				for rsr_idx in range(rsr_slay_descs.size()):
					var rsr_desc: Dictionary = rsr_slay_descs[rsr_idx]
					var rsr_tm := str(rsr_desc.get("target_mode", ""))
					if not rsr_tm.is_empty():
						var rsr_valid := MatchTargeting.get_valid_targets_for_mode(match_state, rsr_killer_id, rsr_tm, rsr_desc)
						if not rsr_valid.is_empty():
							var rsr_pending: Array = match_state.get("pending_summon_effect_targets", [])
							rsr_pending.append({
								"player_id": rsr_controller,
								"source_instance_id": rsr_killer_id,
								"mandatory": false,
								"allowed_families": [FAMILY_SLAY],
							})
					else:
						var rsr_synth_trigger := {
							"trigger_id": "%s_repeat_slay_%d" % [rsr_killer_id, rsr_idx],
							"trigger_index": rsr_idx,
							"source_instance_id": rsr_killer_id,
							"owner_player_id": str(rsr_killer.get("owner_player_id", "")),
							"controller_player_id": rsr_controller,
							"source_zone": "lane",
							"descriptor": rsr_desc.duplicate(true),
						}
						var rsr_resolution := MatchTriggers._build_trigger_resolution(match_state, rsr_synth_trigger, event)
						generated_events.append_array(_MT()._apply_effects(match_state, rsr_synth_trigger, event, rsr_resolution))
		"grant_double_summon_this_turn":
			var gdst_controller_id := str(trigger.get("controller_player_id", ""))
			var gdst_player := MatchTimingHelpers._get_player_state(match_state, gdst_controller_id)
			if not gdst_player.is_empty():
				gdst_player["_double_summon_this_turn"] = true
				generated_events.append({"event_type": "double_summon_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "player_id": gdst_controller_id})
		"grant_double_activate":
			var gda_controller := str(trigger.get("controller_player_id", ""))
			match_state["double_activate_" + gda_controller] = true
			generated_events.append({"event_type": "double_activate_granted", "player_id": gda_controller, "reason": reason})
		"grant_effect_this_turn":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var gettt_ability: Dictionary = effect.get("granted_ability", {})
				if not gettt_ability.is_empty():
					var gettt_triggers = card.get("triggered_abilities", [])
					if typeof(gettt_triggers) != TYPE_ARRAY:
						gettt_triggers = []
					var gettt_copy: Dictionary = gettt_ability.duplicate(true)
					gettt_copy["_expires_on_turn"] = int(match_state.get("turn_number", 0))
					gettt_triggers.append(gettt_copy)
					card["triggered_abilities"] = gettt_triggers
