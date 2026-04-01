class_name EffectMisc
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
		"log":
			generated_events.append({
				"event_type": "timing_effect_logged",
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"message": str(effect.get("message", str(descriptor.get("family", "trigger")))),
			})
		"reveal_opponent_top_deck":
			var controller_id := str(trigger.get("controller_player_id", ""))
			var opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), controller_id)
			var opponent := MatchTimingHelpers._get_player_state(match_state, opponent_id)
			if not opponent.is_empty():
				var deck: Array = opponent.get(ZONE_DECK, [])
				if not deck.is_empty():
					generated_events.append({
						"event_type": "opponent_top_deck_revealed",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"controller_player_id": controller_id,
						"revealed_card": deck.back().duplicate(true),
					})
		"reveal_opponent_hand_card":
			var rohc_controller_id := str(trigger.get("controller_player_id", ""))
			var rohc_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), rohc_controller_id)
			var rohc_opponent := MatchTimingHelpers._get_player_state(match_state, rohc_opponent_id)
			if not rohc_opponent.is_empty():
				var rohc_hand: Array = rohc_opponent.get(ZONE_HAND, [])
				if not rohc_hand.is_empty():
					var rohc_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_reveal_hand", rohc_hand.size())
					generated_events.append({"event_type": "opponent_hand_card_revealed", "source_instance_id": str(trigger.get("source_instance_id", "")), "controller_player_id": rohc_controller_id, "revealed_card": rohc_hand[rohc_idx].duplicate(true)})
		"mark_target":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				card["_marked_by"] = str(trigger.get("source_instance_id", ""))
				card["_mark_effect"] = effect.get("mark_effect", {})
				generated_events.append({"event_type": "creature_marked", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", ""))})
		"mark_for_resummon":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				card["_resummon_on_death"] = true
				card["_resummon_controller"] = str(trigger.get("controller_player_id", ""))
				generated_events.append({"event_type": "marked_for_resummon", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", ""))})
		"add_counter":
			var ac_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not ac_source.is_empty():
				var ac_counter_name := str(effect.get("counter", effect.get("counter_name", "counter")))
				var ac_current := int(ac_source.get("_counter_" + ac_counter_name, 0))
				ac_source["_counter_" + ac_counter_name] = ac_current + int(effect.get("amount", 1))
				var ac_threshold := int(effect.get("threshold", 0))
				var ac_new_value: int = ac_source["_counter_" + ac_counter_name]
				if ac_threshold > 0:
					generated_events.append({"event_type": "counter_updated", "source_instance_id": str(trigger.get("source_instance_id", "")), "counter": ac_counter_name, "value": ac_new_value, "threshold": ac_threshold})
				if ac_threshold > 0 and ac_source["_counter_" + ac_counter_name] >= ac_threshold:
					ac_source["_counter_" + ac_counter_name] = 0
					var ac_then_effects: Array = effect.get("then_effects", [])
					for ac_then in ac_then_effects:
						if typeof(ac_then) == TYPE_DICTIONARY:
							var ac_then_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, ac_then)
							if bool(ac_then_result.get("handled", false)):
								generated_events.append_array(ac_then_result.get("events", []))
		"aim_at":
			var aim_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				card["_aimed_by"] = str(trigger.get("source_instance_id", ""))
				var aim_amount := int(effect.get("amount", 0))
				card["_aim_damage"] = aim_amount
				if not aim_source.is_empty():
					aim_source["_aimed_at_instance_id"] = str(card.get("instance_id", ""))
				generated_events.append({"event_type": "creature_aimed_at", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "amount": aim_amount})
		"redirect_damage_to_self":
			var rdts_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not rdts_source.is_empty():
				rdts_source["_redirect_damage_to"] = str(trigger.get("source_instance_id", ""))
				for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
					card["_protected_by"] = str(trigger.get("source_instance_id", ""))
					generated_events.append({"event_type": "damage_redirect_set", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", ""))})
		"buff_random_hand_card":
			var brhc_power := int(effect.get("power", 0))
			var brhc_health := int(effect.get("health", 0))
			var brhc_controller := str(trigger.get("controller_player_id", ""))
			var brhc_player := MatchTimingHelpers._get_player_state(match_state, brhc_controller)
			if not brhc_player.is_empty():
				var brhc_hand: Array = brhc_player.get(ZONE_HAND, [])
				var brhc_filter_raw = effect.get("filter", {})
				var brhc_filter: Dictionary = brhc_filter_raw if typeof(brhc_filter_raw) == TYPE_DICTIONARY else {}
				var brhc_filter_type := str(brhc_filter.get("card_type", ""))
				var brhc_candidates: Array = []
				for card in brhc_hand:
					if typeof(card) != TYPE_DICTIONARY:
						return
					if not brhc_filter_type.is_empty() and str(card.get("card_type", "")) != brhc_filter_type:
						return
					brhc_candidates.append(card)
				if not brhc_candidates.is_empty():
					var pick: Dictionary = brhc_candidates[MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_brhc", brhc_candidates.size())]
					EvergreenRules.apply_stat_bonus(pick, brhc_power, brhc_health, reason)
					generated_events.append({"event_type": "hand_card_buffed", "player_id": brhc_controller, "instance_id": str(pick.get("instance_id", "")), "power": brhc_power, "health": brhc_health, "reason": reason})
		"top_deck_attribute_bonus":
			var tdab_controller_id := str(trigger.get("controller_player_id", ""))
			var tdab_player := MatchTimingHelpers._get_player_state(match_state, tdab_controller_id)
			var tdab_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not tdab_player.is_empty() and not tdab_source.is_empty():
				var tdab_deck: Array = tdab_player.get(ZONE_DECK, [])
				if not tdab_deck.is_empty():
					var tdab_top: Dictionary = tdab_deck.back()
					var tdab_attrs = tdab_top.get("attributes", [])
					if typeof(tdab_attrs) == TYPE_ARRAY and not tdab_attrs.is_empty():
						var tdab_attr := str(tdab_attrs[0])
						var tdab_bonuses: Dictionary = effect.get("attribute_bonuses", {})
						var tdab_bonus: Dictionary = tdab_bonuses.get(tdab_attr, {})
						if not tdab_bonus.is_empty():
							var tdab_power := int(tdab_bonus.get("power", 0))
							var tdab_health := int(tdab_bonus.get("health", 0))
							EvergreenRules.apply_stat_bonus(tdab_source, tdab_power, tdab_health, reason)
							generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(tdab_source.get("instance_id", "")), "power_bonus": tdab_power, "health_bonus": tdab_health, "reason": reason})
							var tdab_kw_list: Array = tdab_bonus.get("keywords", [])
							if tdab_kw_list.is_empty() and tdab_bonus.has("keyword"):
								tdab_kw_list = [str(tdab_bonus["keyword"])]
							for kw in tdab_kw_list:
								EvergreenRules.ensure_card_state(tdab_source)
								var tdab_granted: Array = tdab_source.get("granted_keywords", [])
								if not tdab_granted.has(str(kw)):
									tdab_granted.append(str(kw))
									tdab_source["granted_keywords"] = tdab_granted
									generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(tdab_source.get("instance_id", "")), "keyword_id": str(kw)})
		"swap_creatures":
			var sc_source_id := str(trigger.get("source_instance_id", ""))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var sc_target_id := str(card.get("instance_id", ""))
				if sc_target_id == sc_source_id:
					return
				var sc_source := MatchTimingHelpers._find_card_anywhere(match_state, sc_source_id)
				var sc_source_loc := MatchMutations.find_card_location(match_state, sc_source_id)
				var sc_target_loc := MatchMutations.find_card_location(match_state, sc_target_id)
				var sc_source_lane := str(sc_source_loc.get("lane_id", ""))
				var sc_target_lane := str(sc_target_loc.get("lane_id", ""))
				var sc_source_controller := str(sc_source.get("controller_player_id", ""))
				var sc_target_controller := str(card.get("controller_player_id", ""))
				# Steal the target to source's controller
				var sc_steal := MatchMutations.steal_card(match_state, sc_source_controller, sc_target_id, {})
				generated_events.append_array(sc_steal.get("events", []))
				# Give source to target's controller
				var sc_give := MatchMutations.steal_card(match_state, sc_target_controller, sc_source_id, {})
				generated_events.append_array(sc_give.get("events", []))
				generated_events.append({"event_type": "creatures_swapped", "source_instance_id": sc_source_id, "target_instance_id": sc_target_id})
		"grant_aura_by_chosen_subtype":
			# This requires a player choice of subtype — use pending_player_choices
			var gabcs_controller_id := str(trigger.get("controller_player_id", ""))
			var gabcs_options: Array = ["Beast", "Orc", "Dark Elf", "Nord", "Khajiit", "Argonian", "Imperial", "High Elf", "Wood Elf", "Breton", "Redguard", "Goblin", "Dragon", "Daedra", "Skeleton", "Spirit", "Vampire"]
			match_state["pending_player_choices"].append({
				"player_id": gabcs_controller_id,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"options": gabcs_options,
				"then_op": "apply_subtype_aura",
				"then_context": effect.get("aura_template", {}),
				"prompt": "Choose a creature type.",
			})
