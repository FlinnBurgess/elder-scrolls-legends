class_name EffectStats
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
		"modify_stats":
			var stat_multiplier := MatchEffectParams._resolve_count_multiplier(match_state, trigger, event, effect)
			var consumed_info: Dictionary = trigger.get("_consumed_card_info", {})
			if consumed_info.is_empty():
				var source_card_for_info := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not source_card_for_info.is_empty():
					consumed_info = source_card_for_info.get("_consumed_card_info", {})
			var base_power := int(event.get("amount", 0)) if bool(effect.get("power_from_event_amount", false)) else int(effect.get("power", 0))
			var base_health := int(event.get("amount", 0)) if bool(effect.get("health_from_event_amount", false)) else int(effect.get("health", 0))
			if str(effect.get("power_source", "")) == "consumed_creature_power" and not consumed_info.is_empty():
				base_power = int(consumed_info.get("power", 0))
			if str(effect.get("health_source", "")) == "consumed_creature_health" and not consumed_info.is_empty():
				base_health = int(consumed_info.get("health", 0))
			var ms_power_source := str(effect.get("power_source", ""))
			if ms_power_source == "self_power" or bool(effect.get("power_from_self_power", false)):
				var ms_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not ms_source.is_empty():
					base_power = EvergreenRules.get_power(ms_source)
			elif ms_power_source == "self_health":
				var ms_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not ms_source.is_empty():
					base_power = EvergreenRules.get_remaining_health(ms_source)
			elif ms_power_source == "event_power_gained":
				base_power = int(event.get("power_bonus", event.get("amount", 0)))
			elif ms_power_source == "event_power_reduced":
				base_power = absi(mini(int(event.get("power_bonus", 0)), 0))
			elif ms_power_source == "event_power_reduced_sign":
				base_power = -1 if int(event.get("power_bonus", 0)) < 0 else 0
			elif ms_power_source == "damage_amount":
				base_power = int(event.get("amount", 0))
			var ms_health_source := str(effect.get("health_source", ""))
			if ms_health_source == "self_power" or bool(effect.get("health_from_self_power", false)):
				var ms_source_h := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not ms_source_h.is_empty():
					base_health = EvergreenRules.get_power(ms_source_h)
			elif ms_health_source == "event_health_reduced":
				base_health = absi(mini(int(event.get("health_bonus", 0)), 0))
			elif ms_health_source == "event_health_reduced_sign":
				base_health = -1 if int(event.get("health_bonus", 0)) < 0 else 0
			var total_power := base_power * stat_multiplier
			var total_health := base_health * stat_multiplier
			var is_temp := str(effect.get("duration", "")) == "end_of_turn" or bool(effect.get("temporary", false)) or bool(effect.get("expires_end_of_turn", false))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				EvergreenRules.apply_stat_bonus(card, total_power, total_health, reason)
				if is_temp:
					EvergreenRules.add_temporary_stat_bonus(card, total_power, total_health, int(match_state.get("turn_number", 0)))
				generated_events.append({
					"event_type": "stats_modified",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"source_controller_player_id": str(trigger.get("controller_player_id", "")),
					"player_id": str(card.get("controller_player_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"power_bonus": total_power,
					"health_bonus": total_health,
					"reason": reason,
				})
		"set_stats":
			var set_power_val: Variant = effect.get("power", null)
			var set_health_val: Variant = effect.get("health", null)
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var power_diff := 0
				var health_diff := 0
				if set_power_val != null:
					power_diff = int(set_power_val) - EvergreenRules.get_power(card)
				if set_health_val != null:
					health_diff = int(set_health_val) - EvergreenRules.get_health(card)
				EvergreenRules.apply_stat_bonus(card, power_diff, health_diff, reason)
				generated_events.append({
					"event_type": "stats_set",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"new_power": EvergreenRules.get_power(card),
					"new_health": EvergreenRules.get_health(card),
					"reason": reason,
				})
		"set_power":
			var sp_value := int(effect.get("value", effect.get("amount", 1)))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var power_diff := sp_value - EvergreenRules.get_power(card)
				EvergreenRules.apply_stat_bonus(card, power_diff, 0, reason)
				generated_events.append({
					"event_type": "stats_set",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"new_power": EvergreenRules.get_power(card),
					"reason": reason,
				})
		"set_health":
			var sh_amount := int(effect.get("amount", 0))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				card["health"] = sh_amount
				card["base_health"] = sh_amount
				EvergreenRules.ensure_card_state(card)
				generated_events.append({
					"event_type": "stats_modified",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"source_controller_player_id": str(trigger.get("controller_player_id", "")),
					"player_id": str(card.get("controller_player_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"reason": reason,
				})
		"double_stats":
			var ds_stat := str(effect.get("stat", "both"))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var current_power := EvergreenRules.get_power(card)
				var current_health := EvergreenRules.get_health(card)
				var power_bonus := current_power if ds_stat in ["both", "power"] else 0
				var health_bonus := current_health if ds_stat in ["both", "health"] else 0
				EvergreenRules.apply_stat_bonus(card, power_bonus, health_bonus, reason)
				generated_events.append({
					"event_type": "stats_modified",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"source_controller_player_id": str(trigger.get("controller_player_id", "")),
					"player_id": str(card.get("controller_player_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"power_bonus": power_bonus,
					"health_bonus": health_bonus,
					"reason": reason,
				})
		"double_health":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var dh_current := int(card.get("health", 0))
				card["health"] = dh_current * 2
				card["base_health"] = int(card.get("base_health", 0)) * 2
				EvergreenRules.ensure_card_state(card)
				generated_events.append({
					"event_type": "stats_modified",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"source_controller_player_id": str(trigger.get("controller_player_id", "")),
					"player_id": str(card.get("controller_player_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"health_bonus": dh_current,
					"reason": reason,
				})
		"set_power_equal_to_health":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var current_health := EvergreenRules.get_health(card)
				var power_diff := current_health - EvergreenRules.get_power(card)
				EvergreenRules.apply_stat_bonus(card, power_diff, 0, reason)
				generated_events.append({
					"event_type": "stats_set",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"new_power": EvergreenRules.get_power(card),
					"reason": reason,
				})
		"set_power_to_health":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var sph_health := int(card.get("health", 0))
				card["power"] = sph_health
				card["base_power"] = sph_health
				EvergreenRules.ensure_card_state(card)
				generated_events.append({
					"event_type": "stats_modified",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"source_controller_player_id": str(trigger.get("controller_player_id", "")),
					"player_id": str(card.get("controller_player_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"reason": reason,
				})
		"swap_stats":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var current_power := EvergreenRules.get_power(card)
				var current_health := EvergreenRules.get_health(card)
				var power_diff := current_health - current_power
				var health_diff := current_power - current_health
				EvergreenRules.apply_stat_bonus(card, power_diff, health_diff, reason)
				generated_events.append({
					"event_type": "stats_swapped",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"new_power": EvergreenRules.get_power(card),
					"new_health": EvergreenRules.get_health(card),
					"reason": reason,
				})
		"conditional_double_stat":
			var cds_stat := str(effect.get("stat", "both"))
			var cds_required_attr := str(effect.get("required_friendly_attribute", ""))
			if not cds_required_attr.is_empty():
				var cds_has_attr := false
				var cds_controller := str(trigger.get("controller_player_id", ""))
				for lane in match_state.get("lanes", []):
					for card in lane.get("player_slots", {}).get(cds_controller, []):
						if typeof(card) == TYPE_DICTIONARY:
							var attrs: Array = card.get("attributes", [])
							if typeof(attrs) == TYPE_ARRAY and attrs.has(cds_required_attr):
								cds_has_attr = true
								break
					if cds_has_attr:
						break
				if not cds_has_attr:
					return
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var current_power := EvergreenRules.get_power(card)
				var current_health := EvergreenRules.get_health(card)
				var power_bonus := current_power if cds_stat in ["both", "power"] else 0
				var health_bonus := current_health if cds_stat in ["both", "health"] else 0
				EvergreenRules.apply_stat_bonus(card, power_bonus, health_bonus, reason)
				generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "source_controller_player_id": str(trigger.get("controller_player_id", "")), "player_id": str(card.get("controller_player_id", "")), "target_instance_id": str(card.get("instance_id", "")), "power_bonus": power_bonus, "health_bonus": health_bonus, "reason": reason})
		"modify_stats_per_keyword":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var mspk_count := 0
				for kw in card.get("keywords", []):
					mspk_count += 1
				for kw in card.get("granted_keywords", []):
					mspk_count += 1
				var mspk_power := int(effect.get("power_per_keyword", 0)) * mspk_count
				var mspk_health := int(effect.get("health_per_keyword", 0)) * mspk_count
				EvergreenRules.apply_stat_bonus(card, mspk_power, mspk_health, reason)
				generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "source_controller_player_id": str(trigger.get("controller_player_id", "")), "player_id": str(card.get("controller_player_id", "")), "target_instance_id": str(card.get("instance_id", "")), "power_bonus": mspk_power, "health_bonus": mspk_health, "reason": reason})
		"set_all_friendly_power_to_max":
			var safptm_controller_id := str(trigger.get("controller_player_id", ""))
			var safptm_max_power := 0
			var safptm_friendlies := MatchTimingHelpers._player_lane_creatures(match_state, safptm_controller_id)
			for card in safptm_friendlies:
				var p := EvergreenRules.get_power(card)
				if p > safptm_max_power:
					safptm_max_power = p
			for card in safptm_friendlies:
				if EvergreenRules.get_power(card) < safptm_max_power:
					card["power"] = safptm_max_power
					card["base_power"] = safptm_max_power
					EvergreenRules.ensure_card_state(card)
					generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "source_controller_player_id": str(trigger.get("controller_player_id", "")), "player_id": str(card.get("controller_player_id", "")), "target_instance_id": str(card.get("instance_id", "")), "reason": reason})
		"spend_all_magicka_for_stats":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var ctrl_id := str(card.get("controller_player_id", ""))
				var p := MatchTimingHelpers._get_player_state(match_state, ctrl_id)
				if p.is_empty():
					return
				var available := int(p.get("current_magicka", 0)) + int(p.get("temporary_magicka", 0))
				p["current_magicka"] = 0
				p["temporary_magicka"] = 0
				if available > 0:
					card["power"] = available
					card["health"] = available
					card["base_power"] = available
					card["base_health"] = available
					EvergreenRules.ensure_card_state(card)
					generated_events.append({
						"event_type": "creature_stats_changed",
						"source_instance_id": str(card.get("instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"new_power": available,
						"new_health": available,
					})
		"modify_cost":
			var mc_amount := int(effect.get("amount", -1))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				card["cost"] = maxi(0, int(card.get("cost", 0)) + mc_amount)
				generated_events.append({
					"event_type": "cost_modified",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"amount": mc_amount,
				})
		"reduce_cost_in_hand":
			var rcih_amount := int(effect.get("amount", 1))
			var rcih_controller := str(trigger.get("controller_player_id", ""))
			var rcih_player := MatchTimingHelpers._get_player_state(match_state, rcih_controller)
			if not rcih_player.is_empty():
				var rcih_hand: Array = rcih_player.get(ZONE_HAND, [])
				var rcih_target := str(effect.get("target", ""))
				var rcih_filter_raw = effect.get("filter", {})
				var rcih_filter: Dictionary = rcih_filter_raw if typeof(rcih_filter_raw) == TYPE_DICTIONARY else {}
				var rcih_filter_card_type := str(rcih_filter.get("card_type", ""))
				for card in rcih_hand:
					if typeof(card) != TYPE_DICTIONARY:
						continue
					if rcih_target == "all_creatures_in_hand" and str(card.get("card_type", "")) != "creature":
						continue
					if not rcih_filter_card_type.is_empty() and str(card.get("card_type", "")) != rcih_filter_card_type:
						continue
					var current_cost := int(card.get("cost", 0))
					card["cost"] = maxi(0, current_cost - rcih_amount)
				generated_events.append({"event_type": "hand_costs_reduced", "player_id": rcih_controller, "amount": rcih_amount, "reason": reason})
		"reduce_cost_top_of_deck":
			var rctd_controller_id := str(trigger.get("controller_player_id", ""))
			var rctd_player := MatchTimingHelpers._get_player_state(match_state, rctd_controller_id)
			if not rctd_player.is_empty():
				var rctd_deck: Array = rctd_player.get(ZONE_DECK, [])
				if not rctd_deck.is_empty():
					var rctd_top: Dictionary = rctd_deck.back()
					var rctd_amount := int(effect.get("amount", 1))
					rctd_top["cost"] = maxi(0, int(rctd_top.get("cost", 0)) - rctd_amount)
					generated_events.append({
						"event_type": "cost_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(rctd_top.get("instance_id", "")),
						"amount": -rctd_amount,
					})
