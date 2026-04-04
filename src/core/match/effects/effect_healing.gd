class_name EffectHealing
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
		"heal":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var heal_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if heal_player.is_empty():
					return
				var heal_amount := MatchEffectParams._resolve_amount(trigger, effect, match_state, event) * MatchEffectParams._resolve_count_multiplier(match_state, trigger, event, effect)
				if bool(effect.get("amount_from_event", false)):
					heal_amount = int(event.get("amount", 0))
				if heal_amount <= 0:
					return
				heal_amount *= MatchTimingHelpers._get_heal_multiplier(match_state, player_id)
				heal_player["health"] = int(heal_player.get("health", 0)) + heal_amount
				generated_events.append({
					"event_type": "player_healed",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_player_id": player_id,
					"amount": heal_amount,
				})
		"restore_creature_health":
			var restore_amount := int(effect.get("amount", -1))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var healed := EvergreenRules.restore_health(card, restore_amount)
				if healed > 0:
					generated_events.append({
						"event_type": "creature_healed",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"amount": healed,
						"reason": reason,
					})
		"gain_max_magicka":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var magicka_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if magicka_player.is_empty():
					return
				var gain := MatchEffectParams._resolve_amount(trigger, effect, match_state, event)
				if gain == 0:
					gain = int(effect.get("amount", 1))
				# Check for _double_max_magicka_gain from any friendly creature in play
				if MatchTriggers._has_double_max_magicka_gain(match_state, player_id):
					gain *= 2
				magicka_player["max_magicka"] = int(magicka_player.get("max_magicka", 0)) + gain
				magicka_player["current_magicka"] = int(magicka_player.get("current_magicka", 0)) + gain
				# Apply max_magicka_cap passive from any creature in play
				var gmm_cap := MatchTimingHelpers._get_max_magicka_cap(match_state)
				if gmm_cap > 0:
					for gmm_p in match_state.get("players", []):
						if typeof(gmm_p) == TYPE_DICTIONARY and int(gmm_p.get("max_magicka", 0)) > gmm_cap:
							gmm_p["max_magicka"] = gmm_cap
							if int(gmm_p.get("current_magicka", 0)) > gmm_cap:
								gmm_p["current_magicka"] = gmm_cap
				generated_events.append({
					"event_type": "max_magicka_gained",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_player_id": player_id,
					"amount": gain,
				})
		"restore_magicka":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var rm_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if rm_player.is_empty():
					return
				var restored := int(rm_player.get("max_magicka", 0)) - int(rm_player.get("current_magicka", 0))
				rm_player["current_magicka"] = int(rm_player.get("max_magicka", 0))
				generated_events.append({
					"event_type": "magicka_restored",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_player_id": player_id,
					"amount": restored,
				})
		"double_max_magicka_gain":
			# This is tracked as a flag on the source creature — actual doubling checked in gain_max_magicka
			var dmmg_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not dmmg_source.is_empty():
				dmmg_source["_double_max_magicka_gain"] = true
		"gain_unspent_magicka_from_last_turn":
			var gumflt_controller_id := str(trigger.get("controller_player_id", ""))
			var gumflt_player := MatchTimingHelpers._get_player_state(match_state, gumflt_controller_id)
			if not gumflt_player.is_empty():
				var gumflt_unspent := int(gumflt_player.get("_unspent_magicka_last_turn", 0))
				if gumflt_unspent > 0:
					gumflt_player["current_magicka"] = int(gumflt_player.get("current_magicka", 0)) + gumflt_unspent
					generated_events.append({"event_type": "magicka_restored", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_player_id": gumflt_controller_id, "amount": gumflt_unspent})
		"restore_rune":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var rr_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if rr_player.is_empty():
					return
				var rr_thresholds: Array = rr_player.get("rune_thresholds", [])
				var rr_default := [25, 20, 15, 10, 5]
				var rr_count := int(effect.get("count", 1))
				for _i in range(rr_count):
					if rr_thresholds.size() >= 5:
						break
					for rr_val in rr_default:
						if not rr_thresholds.has(rr_val):
							rr_thresholds.append(rr_val)
							rr_thresholds.sort()
							rr_thresholds.reverse()
							generated_events.append({"event_type": "rune_restored", "source_instance_id": str(trigger.get("source_instance_id", "")), "player_id": player_id, "threshold": rr_val})
							break
		"add_support_uses":
			var asu_amount := int(effect.get("amount", 1))
			var asu_empower_bonus := int(effect.get("empower_bonus", 0))
			if asu_empower_bonus > 0:
				asu_amount += asu_empower_bonus * MatchTimingHelpers._get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
			var asu_controller := str(trigger.get("controller_player_id", ""))
			var asu_player := MatchTimingHelpers._get_player_state(match_state, asu_controller)
			if not asu_player.is_empty():
				var asu_activated_only := bool(effect.get("activated_only", false))
				for card in asu_player.get(ZONE_SUPPORT, []):
					if typeof(card) == TYPE_DICTIONARY:
						var base_uses = card.get("support_uses", null)
						if asu_activated_only and (base_uses == null or int(base_uses) <= 0):
							continue
						var current_uses := int(card.get("remaining_support_uses", card.get("support_uses", 0)))
						card["remaining_support_uses"] = current_uses + asu_amount
				generated_events.append({"event_type": "support_uses_added", "player_id": asu_controller, "amount": asu_amount, "reason": reason})
		"prevent_rune_draw":
			var prd_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), str(trigger.get("controller_player_id", "")))
			var prd_opponent := MatchTimingHelpers._get_player_state(match_state, prd_opponent_id)
			if not prd_opponent.is_empty():
				prd_opponent["_rune_draw_prevented_until_turn"] = int(match_state.get("turn_number", 0)) + 1
				generated_events.append({"event_type": "rune_draw_prevented", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_player_id": prd_opponent_id})
		"cost_increase_next_turn":
			var cint_controller_id := str(trigger.get("controller_player_id", ""))
			var cint_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), cint_controller_id)
			var cint_opponent := MatchTimingHelpers._get_player_state(match_state, cint_opponent_id)
			if not cint_opponent.is_empty():
				var cint_hand: Array = cint_opponent.get(ZONE_HAND, [])
				if not cint_hand.is_empty():
					var cint_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_cost_increase", cint_hand.size())
					var cint_card: Dictionary = cint_hand[cint_idx]
					var cint_amount := int(effect.get("amount", 3))
					cint_card["cost"] = int(cint_card.get("cost", 0)) + cint_amount
					generated_events.append({"event_type": "cost_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(cint_card.get("instance_id", "")), "amount": cint_amount})
		"increase_opponent_action_cost":
			var ioac_controller_id := str(trigger.get("controller_player_id", ""))
			var ioac_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not ioac_source.is_empty():
				ioac_source["_increase_opponent_action_cost"] = int(effect.get("amount", 1))
		"set_power_cap_in_lane":
			var spcil_controller_id := str(trigger.get("controller_player_id", ""))
			var spcil_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), spcil_controller_id)
			var spcil_cap := int(effect.get("max_power", 0))
			var spcil_source_loc := MatchMutations.find_card_location(match_state, str(trigger.get("source_instance_id", "")))
			var spcil_lane_id := str(spcil_source_loc.get("lane_id", ""))
			for lane in match_state.get("lanes", []):
				if str(lane.get("lane_id", "")) != spcil_lane_id:
					continue
				for spcil_card in lane.get("player_slots", {}).get(spcil_opponent_id, []):
					if typeof(spcil_card) == TYPE_DICTIONARY and EvergreenRules.get_power(spcil_card) > spcil_cap:
						spcil_card["power"] = spcil_cap
						spcil_card["base_power"] = spcil_cap
						EvergreenRules.ensure_card_state(spcil_card)
						generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(spcil_card.get("instance_id", "")), "reason": reason})
