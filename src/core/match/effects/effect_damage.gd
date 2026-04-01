class_name EffectDamage
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
		"deal_damage":
			var damage_amount := MatchEffectParams._resolve_amount(trigger, effect, match_state, event) * MatchEffectParams._resolve_count_multiplier(match_state, trigger, event, effect)
			var dd_empower_bonus := int(effect.get("empower_bonus", 0))
			if dd_empower_bonus > 0:
				damage_amount += dd_empower_bonus * MatchTimingHelpers._get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
			var dd_bonus_data: Dictionary = effect.get("bonus_per_friendly_subtype", {})
			if not dd_bonus_data.is_empty():
				var dd_bonus_subtype := str(dd_bonus_data.get("subtype", ""))
				var dd_bonus_amount := int(dd_bonus_data.get("amount", 0))
				var dd_bonus_group: Array = ExtendedMechanicPacks.SUBTYPE_GROUPS.get(dd_bonus_subtype, [])
				var dd_bonus_controller := str(trigger.get("controller_player_id", ""))
				var dd_bonus_count := 0
				for dd_lane in match_state.get("lanes", []):
					for dd_card in dd_lane.get("player_slots", {}).get(dd_bonus_controller, []):
						if typeof(dd_card) != TYPE_DICTIONARY:
							continue
						var dd_card_st = dd_card.get("subtypes", [])
						if typeof(dd_card_st) != TYPE_ARRAY:
							continue
						if not dd_bonus_group.is_empty():
							for dd_st in dd_card_st:
								if dd_bonus_group.has(dd_st):
									dd_bonus_count += 1
									break
						elif dd_card_st.has(dd_bonus_subtype):
							dd_bonus_count += 1
				damage_amount += dd_bonus_count * dd_bonus_amount
			var dd_source_key := str(effect.get("damage_source", effect.get("source", "")))
			var damage_source_id := ""
			if dd_source_key == "host" or dd_source_key == "wielder":
				var dd_source_card := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				damage_source_id = str(dd_source_card.get("attached_to_instance_id", trigger.get("source_instance_id", "")))
			elif dd_source_key == "event_target":
				damage_source_id = str(event.get("target_instance_id", trigger.get("source_instance_id", "")))
			else:
				damage_source_id = str(trigger.get("source_instance_id", ""))
			var deal_damage_targets := MatchTargeting._resolve_card_targets(match_state, trigger, event, effect)
			if deal_damage_targets.is_empty():
				# Fall back to player damage if a chosen player target exists
				var chosen_player := str(trigger.get("_chosen_target_player_id", ""))
				if chosen_player.is_empty():
					chosen_player = str(event.get("target_player_id", ""))
				if not chosen_player.is_empty() and damage_amount > 0:
					var patched_trigger := trigger.duplicate(true)
					patched_trigger["_chosen_target_player_id"] = chosen_player
					var custom_result := ExtendedMechanicPacks.apply_custom_effect(match_state, patched_trigger, event, {"op": "damage", "amount": damage_amount, "target_player": "chosen_target_player"})
					generated_events.append_array(custom_result.get("events", []))
			var dd_source_creature := MatchTimingHelpers._find_card_anywhere(match_state, damage_source_id)
			var dd_has_lethal := not dd_source_creature.is_empty() and EvergreenRules.has_keyword(dd_source_creature, EvergreenRules.KEYWORD_LETHAL)
			var dd_has_drain := not dd_source_creature.is_empty() and EvergreenRules.has_keyword(dd_source_creature, EvergreenRules.KEYWORD_DRAIN)
			if dd_has_drain:
				var dd_drain_pid := str(trigger.get("controller_player_id", ""))
				if dd_drain_pid != str(match_state.get("active_player_id", "")):
					if not EvergreenRules._has_passive(dd_source_creature, "drain_on_both_turns"):
						dd_has_drain = false
			var is_action_damage := str(event.get("card_type", "")) == "action"
			for card in deal_damage_targets:
				if damage_amount <= 0:
					continue
				if is_action_damage and MatchTimingHelpers._is_immune_to_effect(match_state, card, "action_damage"):
					continue
				# Damage redirect: if creature is protected, redirect damage to protector
				var redirect_id := str(card.get("_protected_by", ""))
				if not redirect_id.is_empty():
					var protector_loc := MatchMutations.find_card_location(match_state, redirect_id)
					if bool(protector_loc.get("is_valid", false)) and str(protector_loc.get("zone", "")) == "lane":
						card = protector_loc["card"]
				var dd_remaining_before := EvergreenRules.get_remaining_health(card)
				var damage_result := EvergreenRules.apply_damage_to_creature(card, damage_amount)
				if bool(damage_result.get("ward_removed", false)):
					generated_events.append({
						"event_type": "ward_removed",
						"source_instance_id": damage_source_id,
						"target_instance_id": str(card.get("instance_id", "")),
					})
				var applied := int(damage_result.get("applied", 0))
				generated_events.append({
					"event_type": "damage_resolved",
					"source_instance_id": damage_source_id,
					"target_instance_id": str(card.get("instance_id", "")),
					"target_type": "creature",
					"amount": applied,
					"reason": reason,
				})
				if dd_has_drain and applied > 0 and not bool(damage_result.get("ward_removed", false)):
					var dd_drain_controller := str(trigger.get("controller_player_id", ""))
					var dd_drain_player := MatchTimingHelpers._get_player_state(match_state, dd_drain_controller)
					if not dd_drain_player.is_empty():
						var dd_heal := applied * MatchTimingHelpers._get_heal_multiplier(match_state, dd_drain_controller)
						dd_drain_player["health"] = int(dd_drain_player.get("health", 0)) + dd_heal
						generated_events.append({
							"event_type": "player_healed",
							"target_player_id": dd_drain_controller,
							"source_instance_id": damage_source_id,
							"amount": dd_heal,
							"reason": EvergreenRules.KEYWORD_DRAIN,
						})
				if EvergreenRules.is_creature_destroyed(card, dd_has_lethal and applied > 0):
					var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					if bool(card_location.get("is_valid", false)):
						var controller_pid := str(card.get("controller_player_id", ""))
						if bool(effect.get("banish_on_kill", false)):
							var banish_moved := MatchMutations.banish_card(match_state, str(card.get("instance_id", "")))
							if bool(banish_moved.get("is_valid", false)):
								generated_events.append_array(banish_moved.get("events", []))
						else:
							var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
							if bool(moved.get("is_valid", false)):
								generated_events.append({
									"event_type": "creature_destroyed",
									"instance_id": str(card.get("instance_id", "")),
									"source_instance_id": str(card.get("instance_id", "")),
									"owner_player_id": str(card.get("owner_player_id", "")),
									"controller_player_id": controller_pid,
									"destroyed_by_instance_id": damage_source_id,
									"lane_id": str(card_location.get("lane_id", "")),
									"source_zone": ZONE_LANE,
								})
					# Breakthrough: overflow damage to opponent
					if not bool(damage_result.get("ward_removed", false)):
						var dd_source_card := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
						if not dd_source_card.is_empty() and EvergreenRules.has_keyword(dd_source_card, EvergreenRules.KEYWORD_BREAKTHROUGH):
							var dd_overflow := maxi(0, damage_amount - dd_remaining_before)
							if dd_overflow > 0:
								var dd_opponent := str(card.get("controller_player_id", ""))
								var dd_bt_result = _MT().apply_player_damage(match_state, dd_opponent, dd_overflow, {
									"reason": "breakthrough",
									"source_instance_id": str(trigger.get("source_instance_id", "")),
									"source_controller_player_id": str(trigger.get("controller_player_id", "")),
								})
								var dd_bt_applied := int(dd_bt_result.get("applied_damage", 0))
								if dd_bt_applied > 0:
									generated_events.append({
										"event_type": "damage_resolved",
										"source_instance_id": str(trigger.get("source_instance_id", "")),
										"target_type": "player",
										"target_player_id": dd_opponent,
										"amount": dd_bt_applied,
										"reason": "breakthrough",
									})
									generated_events.append_array(dd_bt_result.get("events", []))
		"deal_damage_to_lane":
			var ddtl_damage_source := str(effect.get("damage_source", "self"))
			var ddtl_source_id := ""
			if ddtl_damage_source == "event_target":
				ddtl_source_id = MatchTimingHelpers._event_target_instance_id(event)
			else:
				ddtl_source_id = str(trigger.get("source_instance_id", ""))
			var ddtl_source := MatchTimingHelpers._find_card_anywhere(match_state, ddtl_source_id)
			if not ddtl_source.is_empty() and str(ddtl_source.get("zone", "")) == ZONE_LANE:
				var ddtl_power := EvergreenRules.get_power(ddtl_source)
				if ddtl_power <= 0:
					return
				var ddtl_location := MatchMutations.find_card_location(match_state, ddtl_source_id)
				var ddtl_lane_id := str(ddtl_location.get("lane_id", ""))
				if ddtl_lane_id.is_empty():
					return
				generated_events.append({"event_type": "lane_aoe_damage", "source_instance_id": ddtl_source_id, "lane_id": ddtl_lane_id, "amount": ddtl_power})
				var ddtl_has_lethal := EvergreenRules.has_keyword(ddtl_source, EvergreenRules.KEYWORD_LETHAL)
				var ddtl_has_drain := EvergreenRules.has_keyword(ddtl_source, EvergreenRules.KEYWORD_DRAIN)
				if ddtl_has_drain:
					var ddtl_drain_pid := str(trigger.get("controller_player_id", ""))
					if ddtl_drain_pid != str(match_state.get("active_player_id", "")):
						if not EvergreenRules._has_passive(ddtl_source, "drain_on_both_turns"):
							ddtl_has_drain = false
				var ddtl_drain_total := 0
				var ddtl_targets: Array = []
				for ddtl_lane in match_state.get("lanes", []):
					if str(ddtl_lane.get("lane_id", "")) != ddtl_lane_id:
						continue
					for ddtl_pid in ddtl_lane.get("player_slots", {}).keys():
						for ddtl_card in ddtl_lane.get("player_slots", {})[ddtl_pid]:
							if typeof(ddtl_card) != TYPE_DICTIONARY:
								continue
							if str(ddtl_card.get("instance_id", "")) == ddtl_source_id:
								continue
							ddtl_targets.append(ddtl_card)
				for ddtl_card in ddtl_targets:
					var ddtl_dmg_result := EvergreenRules.apply_damage_to_creature(ddtl_card, ddtl_power)
					var ddtl_applied := ddtl_power if not bool(ddtl_dmg_result.get("ward_removed", false)) else 0
					generated_events.append({
						"event_type": EVENT_DAMAGE_RESOLVED,
						"source_instance_id": ddtl_source_id,
						"target_instance_id": str(ddtl_card.get("instance_id", "")),
						"amount": ddtl_power,
						"damage_kind": "ability",
						"ward_removed": bool(ddtl_dmg_result.get("ward_removed", false)),
					})
					if ddtl_has_drain and ddtl_applied > 0:
						ddtl_drain_total += ddtl_applied
					if EvergreenRules.is_creature_destroyed(ddtl_card, ddtl_has_lethal and ddtl_applied > 0):
						var ddtl_destroy := MatchMutations.discard_card(match_state, str(ddtl_card.get("instance_id", "")), {"reason": "deal_damage_to_lane"})
						generated_events.append({
							"event_type": EVENT_CREATURE_DESTROYED,
							"instance_id": str(ddtl_card.get("instance_id", "")),
							"controller_player_id": str(ddtl_card.get("controller_player_id", "")),
							"killer_instance_id": ddtl_source_id,
							"lane_id": ddtl_lane_id,
						})
						generated_events.append_array(ddtl_destroy.get("events", []))
				if ddtl_has_drain and ddtl_drain_total > 0:
					var ddtl_drain_controller := str(trigger.get("controller_player_id", ""))
					var ddtl_drain_player := MatchTimingHelpers._get_player_state(match_state, ddtl_drain_controller)
					if not ddtl_drain_player.is_empty():
						var ddtl_heal := ddtl_drain_total * MatchTimingHelpers._get_heal_multiplier(match_state, ddtl_drain_controller)
						ddtl_drain_player["health"] = int(ddtl_drain_player.get("health", 0)) + ddtl_heal
						generated_events.append({
							"event_type": "player_healed",
							"target_player_id": ddtl_drain_controller,
							"source_instance_id": ddtl_source_id,
							"amount": ddtl_heal,
							"reason": EvergreenRules.KEYWORD_DRAIN,
						})
		"deal_damage_from_creature":
			var ddfc_amount := int(effect.get("amount", 1))
			var ddfc_source_target := str(effect.get("source", "event_target"))
			var ddfc_source_id := ""
			if ddfc_source_target == "event_target":
				ddfc_source_id = MatchTimingHelpers._event_target_instance_id(event)
			else:
				ddfc_source_id = str(trigger.get("source_instance_id", ""))
			var ddfc_source := MatchTimingHelpers._find_card_anywhere(match_state, ddfc_source_id)
			if ddfc_source.is_empty():
				return
			var ddfc_secondary_id := str(trigger.get("_secondary_target_id", ""))
			var ddfc_has_lethal := EvergreenRules.has_keyword(ddfc_source, EvergreenRules.KEYWORD_LETHAL)
			if not ddfc_secondary_id.is_empty():
				var ddfc_defender := MatchTimingHelpers._find_card_anywhere(match_state, ddfc_secondary_id)
				if not ddfc_defender.is_empty():
					var ddfc_result := EvergreenRules.apply_damage_to_creature(ddfc_defender, ddfc_amount)
					var ddfc_dealt := int(ddfc_result.get("applied", 0))
					generated_events.append({"event_type": "damage_resolved", "source_instance_id": ddfc_source_id, "source_controller_player_id": str(ddfc_source.get("controller_player_id", "")), "target_instance_id": ddfc_secondary_id, "target_type": "creature", "amount": ddfc_dealt, "damage_kind": "ability", "reason": reason})
					if EvergreenRules.is_creature_destroyed(ddfc_defender, ddfc_has_lethal and ddfc_dealt > 0):
						var ddfc_moved := MatchMutations.discard_card(match_state, ddfc_secondary_id)
						if bool(ddfc_moved.get("is_valid", false)):
							generated_events.append({"event_type": "creature_destroyed", "instance_id": ddfc_secondary_id, "reason": reason})
			else:
				# No secondary target pre-selected — push pending for UI, AI picks random
				var ddfc_pending: Array = match_state.get("pending_secondary_targets", [])
				ddfc_pending.append({
					"player_id": str(ddfc_source.get("controller_player_id", "")),
					"source_instance_id": ddfc_source_id,
					"damage_amount": ddfc_amount,
					"target_mode": str(effect.get("target_mode", "creature_or_player")),
					"trigger": trigger.duplicate(true),
					"event": event.duplicate(true),
				})
				match_state["pending_secondary_targets"] = ddfc_pending
				generated_events.append({"event_type": "secondary_target_pending", "player_id": str(ddfc_source.get("controller_player_id", "")), "source_instance_id": ddfc_source_id})
		"deal_damage_and_heal":
			var ddah_amount := MatchEffectParams._resolve_amount(trigger, effect, match_state, event)
			var ddah_source_id := str(trigger.get("source_instance_id", ""))
			var ddah_controller_id := str(trigger.get("controller_player_id", ""))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				if ddah_amount <= 0:
					continue
				var ddah_result := EvergreenRules.apply_damage_to_creature(card, ddah_amount)
				generated_events.append({
					"event_type": EVENT_DAMAGE_RESOLVED,
					"source_instance_id": ddah_source_id,
					"target_instance_id": str(card.get("instance_id", "")),
					"amount": ddah_amount,
					"damage_kind": "ability",
					"ward_removed": bool(ddah_result.get("ward_removed", false)),
				})
				if EvergreenRules.get_remaining_health(card) <= 0:
					var ddah_destroy := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")), {"reason": reason})
					generated_events.append({
						"event_type": EVENT_CREATURE_DESTROYED,
						"instance_id": str(card.get("instance_id", "")),
						"controller_player_id": str(card.get("controller_player_id", "")),
						"killer_instance_id": ddah_source_id,
					})
					generated_events.append_array(ddah_destroy.get("events", []))
					# Heal player for the damage amount
					var ddah_player := MatchTimingHelpers._get_player_state(match_state, ddah_controller_id)
					if not ddah_player.is_empty():
						var ddah_heal := ddah_amount * MatchTimingHelpers._get_heal_multiplier(match_state, ddah_controller_id)
						ddah_player["health"] = int(ddah_player.get("health", 0)) + ddah_heal
						generated_events.append({"event_type": "player_healed", "source_instance_id": ddah_source_id, "target_player_id": ddah_controller_id, "amount": ddah_heal})
		"battle_creature":
			var battle_source_id := str(trigger.get("source_instance_id", ""))
			# Support attacker override: "primary_target" uses the primary target from a dual-target selection
			var attacker_override := str(effect.get("attacker", ""))
			if attacker_override == "primary_target":
				var pt_id := str(trigger.get("_primary_target_id", ""))
				if not pt_id.is_empty():
					battle_source_id = pt_id
			var battle_self := bool(effect.get("battle_self", false))
			var battle_source := MatchTimingHelpers._find_card_anywhere(match_state, battle_source_id)
			for defender in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				if battle_self:
					battle_source = defender
					battle_source_id = str(defender.get("instance_id", ""))
				if battle_source.is_empty():
					break
				var attacker_power := maxi(0, EvergreenRules.get_power(battle_source))
				var defender_power := maxi(0, EvergreenRules.get_power(defender))
				var defender_remaining_before := EvergreenRules.get_remaining_health(defender)
				var attacker_remaining_before := EvergreenRules.get_remaining_health(battle_source)
				# Damage redirect for protected creatures
				var bc_def_target: Dictionary = defender
				var bc_def_redirect_id := str(defender.get("_protected_by", ""))
				if not bc_def_redirect_id.is_empty():
					var bc_protector := MatchTimingHelpers._find_card_anywhere(match_state, bc_def_redirect_id)
					if not bc_protector.is_empty() and str(bc_protector.get("zone", "")) != ZONE_DISCARD:
						bc_def_target = bc_protector
				var bc_atk_target: Dictionary = battle_source
				var bc_atk_redirect_id := str(battle_source.get("_protected_by", ""))
				if not bc_atk_redirect_id.is_empty():
					var bc_atk_protector := MatchTimingHelpers._find_card_anywhere(match_state, bc_atk_redirect_id)
					if not bc_atk_protector.is_empty() and str(bc_atk_protector.get("zone", "")) != ZONE_DISCARD:
						bc_atk_target = bc_atk_protector
				var defender_damage_result := EvergreenRules.apply_damage_to_creature(bc_def_target, attacker_power)
				var attacker_damage_result := EvergreenRules.apply_damage_to_creature(bc_atk_target, defender_power)
				if bool(defender_damage_result.get("ward_removed", false)):
					generated_events.append({"event_type": "ward_removed", "source_instance_id": battle_source_id, "target_instance_id": str(defender.get("instance_id", ""))})
				if bool(attacker_damage_result.get("ward_removed", false)):
					generated_events.append({"event_type": "ward_removed", "source_instance_id": str(defender.get("instance_id", "")), "target_instance_id": battle_source_id})
				var applied_to_defender := int(defender_damage_result.get("applied", 0))
				var applied_to_attacker := int(attacker_damage_result.get("applied", 0))
				if applied_to_defender > 0:
					generated_events.append({"event_type": "damage_resolved", "source_instance_id": battle_source_id, "source_controller_player_id": str(battle_source.get("controller_player_id", "")), "target_instance_id": str(defender.get("instance_id", "")), "target_type": "creature", "amount": applied_to_defender, "damage_kind": "combat", "is_battle": true, "reason": reason})
				if applied_to_attacker > 0:
					generated_events.append({"event_type": "damage_resolved", "source_instance_id": str(defender.get("instance_id", "")), "source_controller_player_id": str(defender.get("controller_player_id", "")), "target_instance_id": battle_source_id, "target_type": "creature", "amount": applied_to_attacker, "damage_kind": "combat", "is_battle": true, "reason": reason})
				var defender_has_lethal := EvergreenRules.has_keyword(defender, EvergreenRules.KEYWORD_LETHAL)
				var attacker_has_lethal := EvergreenRules.has_keyword(battle_source, EvergreenRules.KEYWORD_LETHAL)
				var defender_destroyed := EvergreenRules.is_creature_destroyed(defender, applied_to_defender > 0 and attacker_has_lethal)
				var attacker_destroyed := EvergreenRules.is_creature_destroyed(battle_source, applied_to_attacker > 0 and defender_has_lethal)
				# Handle breakthrough on attacker
				if defender_destroyed and EvergreenRules.has_keyword(battle_source, EvergreenRules.KEYWORD_BREAKTHROUGH):
					var bt_damage := maxi(0, attacker_power - defender_remaining_before)
					if bt_damage > 0:
						var defending_player_id := str(defender.get("controller_player_id", ""))
						var bt_result = _MT().apply_player_damage(match_state, defending_player_id, bt_damage, {"reason": "breakthrough", "source_instance_id": battle_source_id, "source_controller_player_id": str(battle_source.get("controller_player_id", ""))})
						var applied_bt := int(bt_result.get("applied_damage", 0))
						if applied_bt > 0:
							generated_events.append({"event_type": "damage_resolved", "source_instance_id": battle_source_id, "source_controller_player_id": str(battle_source.get("controller_player_id", "")), "target_type": "player", "target_player_id": defending_player_id, "amount": applied_bt, "damage_kind": "breakthrough"})
							generated_events.append_array(bt_result.get("events", []))
							_MT().append_match_win_if_needed(match_state, defending_player_id, str(battle_source.get("controller_player_id", "")), generated_events)
				if defender_destroyed:
					var def_loc := MatchMutations.find_card_location(match_state, str(defender.get("instance_id", "")))
					if bool(def_loc.get("is_valid", false)):
						var def_controller := str(defender.get("controller_player_id", ""))
						var def_moved := MatchMutations.discard_card(match_state, str(defender.get("instance_id", "")))
						if bool(def_moved.get("is_valid", false)):
							for dc_evt in def_moved.get("events", []):
								if typeof(dc_evt) == TYPE_DICTIONARY and str(dc_evt.get("event_type", "")) == "attached_item_detached":
									generated_events.append(dc_evt)
							generated_events.append({"event_type": "creature_destroyed", "instance_id": str(defender.get("instance_id", "")), "source_instance_id": str(defender.get("instance_id", "")), "owner_player_id": str(defender.get("owner_player_id", "")), "controller_player_id": def_controller, "destroyed_by_instance_id": battle_source_id, "lane_id": str(def_loc.get("lane_id", "")), "source_zone": ZONE_LANE})
				if attacker_destroyed and not battle_self:
					var atk_loc := MatchMutations.find_card_location(match_state, battle_source_id)
					if bool(atk_loc.get("is_valid", false)):
						var atk_controller := str(battle_source.get("controller_player_id", ""))
						var atk_moved := MatchMutations.discard_card(match_state, battle_source_id)
						if bool(atk_moved.get("is_valid", false)):
							for dc_evt in atk_moved.get("events", []):
								if typeof(dc_evt) == TYPE_DICTIONARY and str(dc_evt.get("event_type", "")) == "attached_item_detached":
									generated_events.append(dc_evt)
							generated_events.append({"event_type": "creature_destroyed", "instance_id": battle_source_id, "source_instance_id": battle_source_id, "owner_player_id": str(battle_source.get("owner_player_id", "")), "controller_player_id": atk_controller, "destroyed_by_instance_id": str(defender.get("instance_id", "")), "lane_id": str(atk_loc.get("lane_id", "")), "source_zone": ZONE_LANE, "is_retaliation_kill": true})
		"battle_strongest_enemy":
			for attacker in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var bse_controller := str(attacker.get("controller_player_id", ""))
				var bse_lane_idx := -1
				for li in range(match_state.get("lanes", []).size()):
					for card in match_state["lanes"][li].get("player_slots", {}).get(bse_controller, []):
						if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == str(attacker.get("instance_id", "")):
							bse_lane_idx = li
							break
					if bse_lane_idx >= 0:
						break
				if bse_lane_idx < 0:
					return
				var best_enemy: Dictionary = {}
				var best_power := -1
				for pid in match_state["lanes"][bse_lane_idx].get("player_slots", {}).keys():
					if pid == bse_controller:
						continue
					for card in match_state["lanes"][bse_lane_idx]["player_slots"][pid]:
						if typeof(card) == TYPE_DICTIONARY:
							var p := EvergreenRules.get_power(card)
							if p > best_power:
								best_power = p
								best_enemy = card
				if not best_enemy.is_empty():
					var patched := trigger.duplicate(true)
					patched["source_instance_id"] = str(attacker.get("instance_id", ""))
					patched["_chosen_target_id"] = str(best_enemy.get("instance_id", ""))
					patched["descriptor"] = {"effects": [{"op": "battle_creature", "target": "chosen_target"}]}
					generated_events.append_array(_MT()._apply_effects(match_state, patched, event, {}))
		"battle_random_enemy":
			for attacker in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var bre_controller := str(attacker.get("controller_player_id", ""))
				var enemies: Array = []
				for lane in match_state.get("lanes", []):
					for pid in lane.get("player_slots", {}).keys():
						if pid == bre_controller:
							continue
						for card in lane["player_slots"][pid]:
							if typeof(card) == TYPE_DICTIONARY:
								enemies.append(card)
				if not enemies.is_empty():
					var pick: Dictionary = enemies[MatchEffectParams._deterministic_index(match_state, str(attacker.get("instance_id", "")) + "_bre", enemies.size())]
					var patched := trigger.duplicate(true)
					patched["source_instance_id"] = str(attacker.get("instance_id", ""))
					patched["_chosen_target_id"] = str(pick.get("instance_id", ""))
					patched["descriptor"] = {"effects": [{"op": "battle_creature", "target": "chosen_target"}]}
					generated_events.append_array(_MT()._apply_effects(match_state, patched, event, {}))
		"player_battle_creature":
			# Dragon Aspect: player gains attack power and fights a creature
			var pbc_controller_id := str(trigger.get("controller_player_id", ""))
			var pbc_attack_power := int(effect.get("power", effect.get("attack_power", 3)))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var pbc_damage := pbc_attack_power
				var pbc_result := EvergreenRules.apply_damage_to_creature(card, pbc_damage)
				generated_events.append({
					"event_type": EVENT_DAMAGE_RESOLVED,
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"amount": pbc_damage,
					"damage_kind": "ability",
					"ward_removed": bool(pbc_result.get("ward_removed", false)),
				})
				# Player takes damage from the creature's power
				var pbc_creature_power := EvergreenRules.get_power(card)
				if pbc_creature_power > 0:
					var pbc_player := MatchTimingHelpers._get_player_state(match_state, pbc_controller_id)
					if not pbc_player.is_empty():
						pbc_player["health"] = int(pbc_player.get("health", 0)) - pbc_creature_power
						generated_events.append({
							"event_type": EVENT_DAMAGE_RESOLVED,
							"source_instance_id": str(card.get("instance_id", "")),
							"target_player_id": pbc_controller_id,
							"target_type": "player",
							"amount": pbc_creature_power,
							"damage_kind": "combat",
						})
				if EvergreenRules.get_remaining_health(card) <= 0:
					var pbc_destroy := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")), {"reason": reason})
					generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": str(card.get("controller_player_id", ""))})
					generated_events.append_array(pbc_destroy.get("events", []))
		"destroy_creature":
			var destroy_source_id := str(trigger.get("source_instance_id", ""))
			var dc_max_power := int(effect.get("max_power", -1))
			if dc_max_power >= 0:
				var dc_empower_bonus := int(effect.get("empower_bonus", 0))
				if dc_empower_bonus > 0:
					dc_max_power += dc_empower_bonus * MatchTimingHelpers._get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				if dc_max_power >= 0 and EvergreenRules.get_power(card) > dc_max_power:
					continue
				var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				if not bool(card_location.get("is_valid", false)):
					continue
				var controller_pid := str(card.get("controller_player_id", ""))
				var dc_power_snapshot := EvergreenRules.get_power(card)
				var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
				if bool(moved.get("is_valid", false)):
					trigger["_destroyed_creature_power"] = dc_power_snapshot
					for dc_evt in moved.get("events", []):
						if typeof(dc_evt) == TYPE_DICTIONARY and str(dc_evt.get("event_type", "")) == "attached_item_detached":
							generated_events.append(dc_evt)
					generated_events.append({
						"event_type": "creature_destroyed",
						"instance_id": str(card.get("instance_id", "")),
						"source_instance_id": str(card.get("instance_id", "")),
						"owner_player_id": str(card.get("owner_player_id", "")),
						"controller_player_id": controller_pid,
						"destroyed_by_instance_id": destroy_source_id,
						"lane_id": str(card_location.get("lane_id", "")),
						"source_zone": ZONE_LANE,
						"destroyed_creature_power": dc_power_snapshot,
					})
		"delayed_destroy":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var dd_pending: Array = match_state.get("pending_delayed_destroys", [])
				dd_pending.append({
					"target_instance_id": str(card.get("instance_id", "")),
					"controller_player_id": str(trigger.get("controller_player_id", "")),
					"on_destroy_effects": effect.get("on_destroy_effects", []),
					"source_instance_id": str(trigger.get("source_instance_id", "")),
				})
				match_state["pending_delayed_destroys"] = dd_pending
				generated_events.append({"event_type": "delayed_destroy_scheduled", "target_instance_id": str(card.get("instance_id", "")), "reason": reason})
		"destroy_creature_end_of_turn":
			var dceot_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not dceot_source.is_empty():
				dceot_source["_destroy_at_end_of_turn"] = int(match_state.get("turn_number", 0))
				generated_events.append({
					"event_type": "marked_for_destruction",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(dceot_source.get("instance_id", "")),
				})
		"destroy_all_except_strongest_in_lane":
			var daesl_controller_id := str(trigger.get("controller_player_id", ""))
			var daesl_lane_id := str(event.get("lane_id", ""))
			if daesl_lane_id.is_empty():
				daesl_lane_id = str(effect.get("lane_id", ""))
			if daesl_lane_id.is_empty():
				var daesl_loc := MatchMutations.find_card_location(match_state, str(trigger.get("source_instance_id", "")))
				daesl_lane_id = str(daesl_loc.get("lane_id", ""))
			var daesl_to_destroy: Array = []
			for lane in match_state.get("lanes", []):
				if str(lane.get("lane_id", "")) != daesl_lane_id:
					continue
				for daesl_pid in lane.get("player_slots", {}).keys():
					var daesl_side: Array = []
					for daesl_card in lane.get("player_slots", {})[daesl_pid]:
						if typeof(daesl_card) == TYPE_DICTIONARY:
							daesl_side.append(daesl_card)
					if daesl_side.size() <= 1:
						continue
					var daesl_max_power := -1
					for daesl_card in daesl_side:
						var p := EvergreenRules.get_power(daesl_card)
						if p > daesl_max_power:
							daesl_max_power = p
					for daesl_card in daesl_side:
						if EvergreenRules.get_power(daesl_card) < daesl_max_power:
							daesl_to_destroy.append(daesl_card)
			for daesl_card in daesl_to_destroy:
				var daesl_destroy := MatchMutations.discard_card(match_state, str(daesl_card.get("instance_id", "")), {"reason": reason})
				generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(daesl_card.get("instance_id", "")), "controller_player_id": str(daesl_card.get("controller_player_id", "")), "lane_id": daesl_lane_id})
				generated_events.append_array(daesl_destroy.get("events", []))
		"destroy_all_except_random":
			var controller_id := str(trigger.get("controller_player_id", ""))
			var opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), controller_id)
			var destroy_source_id := str(trigger.get("source_instance_id", ""))
			for lane in match_state.get("lanes", []):
				var lane_id := str(lane.get("lane_id", ""))
				var player_slots: Dictionary = lane.get("player_slots", {})
				for pid in player_slots.keys():
					var slots: Array = player_slots[pid]
					if slots.size() <= 1:
						continue
					var survivor_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_survivor_" + str(pid) + "_" + lane_id, slots.size())
					for slot_idx in range(slots.size() - 1, -1, -1):
						if slot_idx == survivor_idx:
							continue
						var card = slots[slot_idx]
						if typeof(card) != TYPE_DICTIONARY:
							continue
						var card_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
						if not bool(card_loc.get("is_valid", false)):
							continue
						var cpid := str(card.get("controller_player_id", ""))
						var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
						if bool(moved.get("is_valid", false)):
							generated_events.append({"event_type": "creature_destroyed", "instance_id": str(card.get("instance_id", "")), "source_instance_id": str(card.get("instance_id", "")), "owner_player_id": str(card.get("owner_player_id", "")), "controller_player_id": cpid, "destroyed_by_instance_id": destroy_source_id, "lane_id": lane_id, "source_zone": ZONE_LANE})
		"destroy_item":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var di_items: Array = card.get("attached_items", [])
				if not di_items.is_empty():
					var di_item: Dictionary = di_items[0]
					var di_result := MatchMutations.discard_card(match_state, str(di_item.get("instance_id", "")), {"reason": reason})
					generated_events.append({
						"event_type": "attached_item_detached",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"host_instance_id": str(card.get("instance_id", "")),
						"item_instance_id": str(di_item.get("instance_id", "")),
					})
					generated_events.append_array(di_result.get("events", []))
		"destroy_front_rune_and_steal_draw":
			var dfrsd_controller_id := str(trigger.get("controller_player_id", ""))
			var dfrsd_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), dfrsd_controller_id)
			var dfrsd_opponent := MatchTimingHelpers._get_player_state(match_state, dfrsd_opponent_id)
			if not dfrsd_opponent.is_empty():
				var dfrsd_thresholds: Array = dfrsd_opponent.get("rune_thresholds", [])
				if not dfrsd_thresholds.is_empty():
					var dfrsd_front: int = int(dfrsd_thresholds[0])
					dfrsd_thresholds.erase(dfrsd_front)
					generated_events.append({"event_type": EVENT_RUNE_BROKEN, "player_id": dfrsd_opponent_id, "threshold": dfrsd_front, "source_instance_id": str(trigger.get("source_instance_id", ""))})
				# Draw from opponent's deck to controller's hand
				var dfrsd_opp_deck: Array = dfrsd_opponent.get(ZONE_DECK, [])
				if not dfrsd_opp_deck.is_empty():
					var dfrsd_stolen: Dictionary = dfrsd_opp_deck.pop_back()
					dfrsd_stolen["zone"] = ZONE_HAND
					dfrsd_stolen["controller_player_id"] = dfrsd_controller_id
					dfrsd_stolen["owner_player_id"] = dfrsd_controller_id
					var dfrsd_controller := MatchTimingHelpers._get_player_state(match_state, dfrsd_controller_id)
					if not dfrsd_controller.is_empty():
						dfrsd_controller.get(ZONE_HAND, []).append(dfrsd_stolen)
						generated_events.append({"event_type": "card_stolen_from_discard", "source_instance_id": str(trigger.get("source_instance_id", "")), "stolen_instance_id": str(dfrsd_stolen.get("instance_id", "")), "from_player_id": dfrsd_opponent_id, "to_player_id": dfrsd_controller_id})
