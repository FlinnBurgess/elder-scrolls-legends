class_name EffectDraw
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
		"draw_cards":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
					var draw_count := int(effect.get("count", 1)) * MatchEffectParams._resolve_count_multiplier(match_state, trigger, event, effect)
					if effect.has("count_if_sacrificed") and bool(event.get("is_sacrifice", false)):
						draw_count = int(effect.get("count_if_sacrificed", draw_count)) * MatchEffectParams._resolve_count_multiplier(match_state, trigger, event, effect)
					var draw_result = _MT().draw_cards(match_state, player_id, draw_count, {
						"reason": reason,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"source_controller_player_id": str(trigger.get("controller_player_id", "")),
					})
					generated_events.append_array(draw_result.get("events", []))
					var drawn_cards: Array = draw_result.get("cards", [])
					if effect.has("post_draw_cost_set"):
						var set_cost := int(effect.get("post_draw_cost_set", 0))
						for drawn_card in drawn_cards:
							if typeof(drawn_card) == TYPE_DICTIONARY:
								var original_cost := int(drawn_card.get("cost", 0))
								if set_cost != original_cost:
									drawn_card["_base_cost"] = original_cost
								drawn_card["cost"] = set_cost
					elif effect.has("post_draw_cost_reduce"):
						var reduce_amount := int(effect.get("post_draw_cost_reduce", 0))
						var cost_threshold := int(effect.get("cost_threshold", 0))
						for drawn_card in drawn_cards:
							if typeof(drawn_card) == TYPE_DICTIONARY:
								var card_cost := int(drawn_card.get("cost", 0))
								if cost_threshold > 0 and card_cost < cost_threshold:
									continue
								drawn_card["_base_cost"] = card_cost
								drawn_card["cost"] = maxi(0, card_cost - reduce_amount)
					elif effect.has("if_action_set_cost"):
						var iacs_cost := int(effect.get("if_action_set_cost", 0))
						for drawn_card in drawn_cards:
							if typeof(drawn_card) == TYPE_DICTIONARY and str(drawn_card.get("card_type", "")) == "action":
								var original_cost := int(drawn_card.get("cost", 0))
								if iacs_cost != original_cost:
									drawn_card["_base_cost"] = original_cost
								drawn_card["cost"] = iacs_cost
		"draw_filtered":
			var filter_dict: Dictionary = effect.get("filter", {}) if typeof(effect.get("filter", null)) == TYPE_DICTIONARY else {}
			var filter_max_cost := int(effect.get("max_cost", filter_dict.get("max_cost", -1)))
			var filter_card_type := str(effect.get("required_card_type", filter_dict.get("card_type", "")))
			var filter_subtype := str(effect.get("required_subtype", filter_dict.get("subtype", "")))
			var filter_rules_tag := str(effect.get("required_rules_tag", filter_dict.get("rules_tag", "")))
			var filter_name := str(filter_dict.get("name", ""))
			var filter_cost_equals_source_power: bool = filter_dict.get("cost_equals_source_power", false)
			var source_power := 0
			if filter_cost_equals_source_power:
				var source_card := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				source_power = EvergreenRules.get_power(source_card) if not source_card.is_empty() else 0
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var draw_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if draw_player.is_empty():
					return
				var deck: Array = draw_player.get(ZONE_DECK, [])
				var candidates: Array = []
				for deck_index in range(deck.size()):
					var deck_card = deck[deck_index]
					if typeof(deck_card) != TYPE_DICTIONARY:
						continue
					if filter_max_cost >= 0 and int(deck_card.get("cost", 0)) > filter_max_cost:
						continue
					if not filter_card_type.is_empty() and str(deck_card.get("card_type", "")) != filter_card_type:
						continue
					if not filter_subtype.is_empty():
						var subtypes = deck_card.get("subtypes", [])
						if typeof(subtypes) != TYPE_ARRAY or not subtypes.has(filter_subtype):
							continue
					if not filter_rules_tag.is_empty():
						var deck_card_tags = deck_card.get("rules_tags", [])
						if typeof(deck_card_tags) != TYPE_ARRAY or not deck_card_tags.has(filter_rules_tag):
							continue
					if not filter_name.is_empty() and str(deck_card.get("name", "")) != filter_name:
						continue
					if filter_cost_equals_source_power and int(deck_card.get("cost", 0)) != source_power:
						continue
					candidates.append(deck_index)
				if candidates.is_empty():
					return
				var pick_index: int = candidates[MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_draw_filtered", candidates.size())]
				var picked_card: Dictionary = deck[pick_index]
				deck.remove_at(pick_index)
				if _MT()._overflow_card_to_discard(draw_player, picked_card, player_id, ZONE_DECK, generated_events):
					return
				picked_card["zone"] = ZONE_HAND
				draw_player[ZONE_HAND].append(picked_card)
				var post_draw_mod: Dictionary = effect.get("post_draw_modify", {}) if typeof(effect.get("post_draw_modify", null)) == TYPE_DICTIONARY else {}
				if not post_draw_mod.is_empty():
					var mod_power := int(post_draw_mod.get("power", 0))
					var mod_health := int(post_draw_mod.get("health", 0))
					if mod_power != 0:
						picked_card["power_modifier"] = int(picked_card.get("power_modifier", 0)) + mod_power
					if mod_health != 0:
						picked_card["health_modifier"] = int(picked_card.get("health_modifier", 0)) + mod_health
				generated_events.append({
					"event_type": "card_drawn",
					"player_id": player_id,
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"drawn_instance_id": str(picked_card.get("instance_id", "")),
					"source_zone": ZONE_DECK,
					"target_zone": ZONE_HAND,
					"reason": reason,
				})
		"draw_from_discard_filtered":
			var dfdf_filter_dict: Dictionary = effect.get("filter", {}) if typeof(effect.get("filter", null)) == TYPE_DICTIONARY else {}
			var discard_filter_card_type := str(effect.get("required_card_type", dfdf_filter_dict.get("card_type", "")))
			var discard_filter_card_type_in: Array = dfdf_filter_dict.get("card_type_in", []) if typeof(dfdf_filter_dict.get("card_type_in", null)) == TYPE_ARRAY else []
			var discard_filter_subtype := str(effect.get("required_subtype", dfdf_filter_dict.get("subtype", "")))
			var discard_filter_match := str(effect.get("filter_match", ""))
			var is_player_choice := bool(effect.get("player_choice", false))
			# Resolve consumed creature name for filter matching
			var discard_filter_name := ""
			if discard_filter_match == "consumed_creature_name":
				var dfm_consumed := MatchEffectParams._get_consumed_card_info(trigger)
				if dfm_consumed.is_empty():
					var dfm_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if not dfm_source.is_empty():
						dfm_consumed = dfm_source.get("_consumed_card_info", {})
				discard_filter_name = str(dfm_consumed.get("definition_id", ""))
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var discard_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if discard_player.is_empty():
					return
				var discard_pile: Array = discard_player.get(ZONE_DISCARD, [])
				var discard_candidates: Array = []
				var candidate_instance_ids: Array = []
				var dfdf_source_id := str(trigger.get("source_instance_id", ""))
				for d_index in range(discard_pile.size()):
					var d_card = discard_pile[d_index]
					if typeof(d_card) != TYPE_DICTIONARY:
						continue
					# Exclude the trigger source from candidates (e.g., creature that died while slaying)
					if str(d_card.get("instance_id", "")) == dfdf_source_id:
						continue
					if not discard_filter_card_type.is_empty() and str(d_card.get("card_type", "")) != discard_filter_card_type:
						continue
					if not discard_filter_card_type_in.is_empty() and not discard_filter_card_type_in.has(str(d_card.get("card_type", ""))):
						continue
					if not discard_filter_subtype.is_empty():
						var d_subtypes = d_card.get("subtypes", [])
						if typeof(d_subtypes) != TYPE_ARRAY or not d_subtypes.has(discard_filter_subtype):
							continue
					if not discard_filter_name.is_empty() and str(d_card.get("definition_id", "")) != discard_filter_name:
						continue
					discard_candidates.append(d_index)
					candidate_instance_ids.append(str(d_card.get("instance_id", "")))
				if discard_candidates.is_empty():
					return
				if is_player_choice:
					match_state["pending_discard_choices"].append({
						"player_id": player_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"candidate_instance_ids": candidate_instance_ids,
						"buff_power": int(effect.get("buff_power", 0)),
						"buff_health": int(effect.get("buff_health", 0)),
						"draw_all_matching_name": bool(effect.get("draw_all_matching_name", false)),
						"reason": reason,
					})
				else:
					var pick_idx: int = discard_candidates[MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_draw_discard", discard_candidates.size())]
					var picked_discard_card: Dictionary = discard_pile[pick_idx]
					discard_pile.remove_at(pick_idx)
					if _MT()._overflow_card_to_discard(discard_player, picked_discard_card, player_id, ZONE_DISCARD, generated_events):
						return
					MatchMutations.restore_definition_state(picked_discard_card)
					picked_discard_card["zone"] = ZONE_HAND
					discard_player[ZONE_HAND].append(picked_discard_card)
					generated_events.append({
						"event_type": "card_drawn",
						"player_id": player_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"drawn_instance_id": str(picked_discard_card.get("instance_id", "")),
						"source_zone": ZONE_DISCARD,
						"target_zone": ZONE_HAND,
						"reason": reason,
					})
		"draw_from_deck_filtered":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var dfdf_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if dfdf_player.is_empty():
					return
				var dfdf_deck: Array = dfdf_player.get(ZONE_DECK, [])
				var dfdf_filter_raw = effect.get("filter", {})
				var dfdf_filter: Dictionary = dfdf_filter_raw if typeof(dfdf_filter_raw) == TYPE_DICTIONARY else {}
				var dfdf_candidates: Array = []
				for di in range(dfdf_deck.size()):
					var card: Dictionary = dfdf_deck[di]
					if typeof(card) != TYPE_DICTIONARY:
						continue
					var dfdf_match := true
					if dfdf_filter.has("card_type") and str(card.get("card_type", "")) != str(dfdf_filter["card_type"]):
						dfdf_match = false
					if dfdf_filter.has("multi_attribute"):
						var attrs: Array = card.get("attributes", [])
						if typeof(attrs) != TYPE_ARRAY or attrs.size() < 2:
							dfdf_match = false
					if dfdf_filter.has("cost_equals_remaining_magicka"):
						var remaining := int(dfdf_player.get("current_magicka", 0))
						if int(card.get("cost", -1)) != remaining:
							dfdf_match = false
					if dfdf_filter.has("max_cost") and int(card.get("cost", 0)) > int(dfdf_filter["max_cost"]):
						dfdf_match = false
					if dfdf_filter.has("subtype_in"):
						var dfdf_st_filter = dfdf_filter["subtype_in"]
						if typeof(dfdf_st_filter) == TYPE_ARRAY:
							var dfdf_card_subtypes = card.get("subtypes", [])
							var dfdf_st_match := false
							if typeof(dfdf_card_subtypes) == TYPE_ARRAY:
								for dfdf_st in dfdf_card_subtypes:
									if dfdf_st_filter.has(str(dfdf_st)):
										dfdf_st_match = true
										break
							if not dfdf_st_match:
								dfdf_match = false
					if dfdf_match:
						dfdf_candidates.append(di)
				if not dfdf_candidates.is_empty():
					var dfdf_is_player_choice := bool(effect.get("player_choice", false))
					if dfdf_is_player_choice:
						var dfdf_candidate_ids: Array = []
						for dfdf_ci in dfdf_candidates:
							dfdf_candidate_ids.append(str(dfdf_deck[dfdf_ci].get("instance_id", "")))
						match_state["pending_deck_selections"].append({
							"player_id": player_id,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"candidate_instance_ids": dfdf_candidate_ids,
							"then_op": "draw_card_to_hand",
							"then_context": {"reason": reason},
							"prompt": "Choose a card to draw.",
						})
					else:
						var pick_idx: int = dfdf_candidates[MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_dfdf", dfdf_candidates.size())]
						var drawn: Dictionary = dfdf_deck[pick_idx]
						dfdf_deck.remove_at(pick_idx)
						drawn["zone"] = ZONE_HAND
						var dfdf_hand: Array = dfdf_player.get(ZONE_HAND, [])
						dfdf_hand.append(drawn)
						generated_events.append({"event_type": "card_drawn", "player_id": player_id, "instance_id": str(drawn.get("instance_id", "")), "source": "draw_from_deck_filtered", "reason": reason})
		"draw_specific_from_deck":
			var dsfd_source_id := str(trigger.get("source_instance_id", ""))
			var dsfd_controller := str(trigger.get("controller_player_id", ""))
			var dsfd_player := MatchTimingHelpers._get_player_state(match_state, dsfd_controller)
			if not dsfd_player.is_empty():
				var dsfd_deck: Array = dsfd_player.get(ZONE_DECK, [])
				for di in range(dsfd_deck.size()):
					if typeof(dsfd_deck[di]) == TYPE_DICTIONARY and str(dsfd_deck[di].get("definition_id", "")) == str(MatchTimingHelpers._find_card_anywhere(match_state, dsfd_source_id).get("definition_id", "")):
						var drawn: Dictionary = dsfd_deck[di]
						dsfd_deck.remove_at(di)
						drawn["zone"] = ZONE_HAND
						var dsfd_hand: Array = dsfd_player.get(ZONE_HAND, [])
						dsfd_hand.append(drawn)
						generated_events.append({"event_type": "card_drawn", "player_id": dsfd_controller, "instance_id": str(drawn.get("instance_id", "")), "source": "draw_specific_from_deck", "reason": reason})
						break
		"draw_all_creatures_from_discard":
			var dacfd_controller := str(trigger.get("controller_player_id", ""))
			var dacfd_player := MatchTimingHelpers._get_player_state(match_state, dacfd_controller)
			if not dacfd_player.is_empty():
				var dacfd_discard: Array = dacfd_player.get(ZONE_DISCARD, [])
				var dacfd_hand: Array = dacfd_player.get(ZONE_HAND, [])
				var dacfd_to_draw: Array = []
				for card in dacfd_discard:
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature":
						dacfd_to_draw.append(card)
				for card in dacfd_to_draw:
					dacfd_discard.erase(card)
					MatchMutations.restore_definition_state(card)
					card["zone"] = ZONE_HAND
					dacfd_hand.append(card)
					generated_events.append({"event_type": "card_drawn", "player_id": dacfd_controller, "instance_id": str(card.get("instance_id", "")), "source": "draw_all_creatures_from_discard", "reason": reason})
		"draw_random_creature_from_discard":
			var drcfd_controller := str(trigger.get("controller_player_id", ""))
			var drcfd_player := MatchTimingHelpers._get_player_state(match_state, drcfd_controller)
			if not drcfd_player.is_empty():
				var drcfd_discard: Array = drcfd_player.get(ZONE_DISCARD, [])
				var drcfd_hand: Array = drcfd_player.get(ZONE_HAND, [])
				var drcfd_source_id := str(trigger.get("source_instance_id", ""))
				var drcfd_candidates: Array = []
				for card in drcfd_discard:
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature" and str(card.get("instance_id", "")) != drcfd_source_id:
						drcfd_candidates.append(card)
				if not drcfd_candidates.is_empty():
					var drcfd_picked: Dictionary = drcfd_candidates[randi() % drcfd_candidates.size()]
					drcfd_discard.erase(drcfd_picked)
					MatchMutations.restore_definition_state(drcfd_picked)
					drcfd_picked["zone"] = ZONE_HAND
					drcfd_hand.append(drcfd_picked)
					generated_events.append({"event_type": "card_drawn", "player_id": drcfd_controller, "instance_id": str(drcfd_picked.get("instance_id", "")), "source": "draw_random_creature_from_discard", "reason": reason})
		"draw_cards_per_runes":
			var dcpr_controller_id := str(trigger.get("controller_player_id", ""))
			var dcpr_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), dcpr_controller_id)
			var dcpr_opponent := MatchTimingHelpers._get_player_state(match_state, dcpr_opponent_id)
			if not dcpr_opponent.is_empty():
				var dcpr_runes_remaining: Array = dcpr_opponent.get("rune_thresholds", [25, 20, 15, 10, 5])
				var dcpr_destroyed := 5 - dcpr_runes_remaining.size()
				if dcpr_destroyed > 0:
					var dcpr_draw_result = _MT().draw_cards(match_state, dcpr_controller_id, dcpr_destroyed, {"reason": reason, "source_instance_id": str(trigger.get("source_instance_id", ""))})
					generated_events.append_array(dcpr_draw_result.get("events", []))
		"draw_copy_of_consumed":
			# Draw a copy of the last consumed card — check event for consumed card info
			var dcoc_controller_id := str(trigger.get("controller_player_id", ""))
			var dcoc_target_id := str(event.get("target_instance_id", ""))
			var dcoc_target := MatchTimingHelpers._find_card_anywhere(match_state, dcoc_target_id)
			if not dcoc_target.is_empty():
				var dcoc_copy := MatchMutations.build_generated_card(match_state, dcoc_controller_id, dcoc_target)
				var dcoc_player := MatchTimingHelpers._get_player_state(match_state, dcoc_controller_id)
				if not dcoc_player.is_empty():
					dcoc_copy["zone"] = ZONE_HAND
					var dcoc_hand: Array = dcoc_player.get(ZONE_HAND, [])
					dcoc_hand.append(dcoc_copy)
					generated_events.append({"event_type": EVENT_CARD_DRAWN, "player_id": dcoc_controller_id, "source_instance_id": str(dcoc_copy.get("instance_id", ""))})
		"draw_or_treasure_hunt":
			# Treasure Map: draw a card matching the wielder's unfound treasure hunt types,
			# or draw from the top if no active hunts or no matching card in deck.
			var doth_controller_id := str(trigger.get("controller_player_id", ""))
			var doth_player := MatchTimingHelpers._get_player_state(match_state, doth_controller_id)
			if not doth_player.is_empty():
				var doth_deck: Array = doth_player.get(ZONE_DECK, [])
				if not doth_deck.is_empty():
					# Collect unfound hunt types from the wielder's active treasure hunts
					var doth_unfound_types: Array = []
					for doth_target in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
						var doth_abilities = doth_target.get("triggered_abilities", [])
						if typeof(doth_abilities) != TYPE_ARRAY:
							continue
						for doth_idx in range(doth_abilities.size()):
							var doth_desc = doth_abilities[doth_idx]
							if typeof(doth_desc) != TYPE_DICTIONARY:
								continue
							if str(doth_desc.get("family", "")) != "treasure_hunt":
								continue
							var doth_spent_key := "_th_%d_spent" % doth_idx
							if bool(doth_target.get(doth_spent_key, false)):
								continue
							var doth_hunt_types = doth_desc.get("hunt_types", [])
							if typeof(doth_hunt_types) != TYPE_ARRAY or doth_hunt_types.is_empty():
								continue
							var doth_is_multi: bool = doth_hunt_types.size() > 1 and not doth_hunt_types.has("any") and int(doth_desc.get("hunt_count", 0)) == 0
							if doth_is_multi:
								var doth_found_key := "_th_%d_found" % doth_idx
								var doth_found: Array = []
								var doth_raw_found = doth_target.get(doth_found_key, [])
								if typeof(doth_raw_found) == TYPE_ARRAY:
									doth_found = doth_raw_found
								for doth_ht in doth_hunt_types:
									if not doth_found.has(str(doth_ht)) and not doth_unfound_types.has(str(doth_ht)):
										doth_unfound_types.append(str(doth_ht))
							else:
								for doth_ht in doth_hunt_types:
									if not doth_unfound_types.has(str(doth_ht)):
										doth_unfound_types.append(str(doth_ht))
					# Search deck for a matching card
					var doth_matching_indices: Array = []
					if not doth_unfound_types.is_empty():
						for doth_i in range(doth_deck.size()):
							if MatchSummonTiming._card_matches_treasure_hunt(doth_deck[doth_i], doth_unfound_types):
								doth_matching_indices.append(doth_i)
					if not doth_matching_indices.is_empty():
						# Pick a random matching card from the deck
						var doth_rand := MatchEffectParams._deterministic_index(match_state, "treasure_map_%s" % str(trigger.get("source_instance_id", "")), doth_matching_indices.size())
						var doth_pick_idx: int = doth_matching_indices[doth_rand]
						var doth_card: Dictionary = doth_deck[doth_pick_idx]
						doth_deck.remove_at(doth_pick_idx)
						# Move card to hand
						var doth_hand: Array = doth_player.get(ZONE_HAND, [])
						if doth_hand.size() >= MAX_HAND_SIZE:
							doth_card["zone"] = ZONE_DISCARD
							doth_player[ZONE_DISCARD].append(doth_card)
							generated_events.append({"event_type": EVENT_CARD_OVERDRAW, "player_id": doth_controller_id, "instance_id": str(doth_card.get("instance_id", "")), "source_zone": ZONE_DECK})
						else:
							doth_card["zone"] = ZONE_HAND
							doth_hand.append(doth_card)
							MatchMutations.apply_first_turn_hand_cost(match_state, doth_card, doth_controller_id)
							generated_events.append({"event_type": EVENT_CARD_DRAWN, "player_id": doth_controller_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "source_controller_player_id": doth_controller_id, "drawn_instance_id": str(doth_card.get("instance_id", "")), "source_zone": ZONE_DECK, "target_zone": ZONE_HAND, "reason": "treasure_map"})
					else:
						# No active hunts or no matching card — draw from top
						var doth_draw = _MT().draw_cards(match_state, doth_controller_id, 1, {"reason": "treasure_map", "source_instance_id": str(trigger.get("source_instance_id", ""))})
						generated_events.append_array(doth_draw.get("events", []))
		"draw_if_top_deck_subtype":
			var ditds_controller_id := str(trigger.get("controller_player_id", ""))
			var ditds_player := MatchTimingHelpers._get_player_state(match_state, ditds_controller_id)
			if not ditds_player.is_empty():
				var ditds_deck: Array = ditds_player.get(ZONE_DECK, [])
				if not ditds_deck.is_empty():
					var ditds_top: Dictionary = ditds_deck.back()
					var ditds_filter_subtype := str(effect.get("subtype", effect.get("filter_subtype", "")))
					var ditds_subtypes = ditds_top.get("subtypes", [])
					if typeof(ditds_subtypes) == TYPE_ARRAY and ditds_subtypes.has(ditds_filter_subtype):
						var ditds_draw = _MT().draw_cards(match_state, ditds_controller_id, 1, {"reason": reason, "source_instance_id": str(trigger.get("source_instance_id", ""))})
						generated_events.append_array(ditds_draw.get("events", []))
					elif bool(effect.get("else_bottom", false)) and ditds_deck.size() > 1:
						var ditds_moved: Dictionary = ditds_deck.pop_back()
						ditds_deck.push_front(ditds_moved)
		"draw_if_wielder_has_items":
			var diwhi_source_id := str(trigger.get("source_instance_id", ""))
			var diwhi_source := MatchTimingHelpers._find_card_anywhere(match_state, diwhi_source_id)
			if not diwhi_source.is_empty():
				var diwhi_host_id := str(diwhi_source.get("attached_to_instance_id", ""))
				if not diwhi_host_id.is_empty():
					var diwhi_host := MatchTimingHelpers._find_card_anywhere(match_state, diwhi_host_id)
					var diwhi_items: Array = diwhi_host.get("attached_items", [])
					if diwhi_items.size() >= int(effect.get("min_items", 2)):
						var diwhi_controller := str(trigger.get("controller_player_id", ""))
						var diwhi_draw = _MT().draw_cards(match_state, diwhi_controller, 1, {"reason": reason, "source_instance_id": diwhi_source_id})
						generated_events.append_array(diwhi_draw.get("events", []))
		"copy_drawn_card_to_hand":
			var cdcth_controller_id := str(trigger.get("controller_player_id", ""))
			var cdcth_drawn_id := str(event.get("source_instance_id", event.get("drawn_instance_id", "")))
			var cdcth_drawn := MatchTimingHelpers._find_card_anywhere(match_state, cdcth_drawn_id)
			if not cdcth_drawn.is_empty():
				var cdcth_copy := MatchMutations.build_generated_card(match_state, cdcth_controller_id, cdcth_drawn)
				cdcth_copy["zone"] = ZONE_HAND
				var cdcth_player := MatchTimingHelpers._get_player_state(match_state, cdcth_controller_id)
				if not cdcth_player.is_empty():
					cdcth_player.get(ZONE_HAND, []).append(cdcth_copy)
					generated_events.append({"event_type": EVENT_CARD_DRAWN, "player_id": cdcth_controller_id, "source_instance_id": str(cdcth_copy.get("instance_id", ""))})
		"generate_card_to_hand":
			var gen_template: Dictionary = effect.get("card_template", {})
			if gen_template.is_empty():
				# Fall back to resolved target card as template (e.g. treasure_card_copy)
				var gen_target_cards := MatchTargeting._resolve_card_targets(match_state, trigger, event, effect)
				if not gen_target_cards.is_empty():
					gen_template = gen_target_cards[0].duplicate(true)
					# Clear instance_id so build_generated_card assigns a fresh one
					gen_template.erase("instance_id")
			if gen_template.is_empty():
				return
			var gen_count := int(effect.get("count", 1))
			var gen_force_play := bool(effect.get("force_play", false))
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var gen_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if gen_player.is_empty():
					return
				var hand: Array = gen_player.get(ZONE_HAND, [])
				var gen_scale_counter := str(effect.get("scale_to_counter", ""))
				for _i in range(gen_count):
					var generated_card := MatchMutations.build_generated_card(match_state, player_id, gen_template)
					if not gen_scale_counter.is_empty():
						var gen_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
						var gen_counter_val := int(gen_source.get("_counter_" + gen_scale_counter, 0))
						generated_card["_counter_" + gen_scale_counter] = gen_counter_val
					if _MT()._overflow_card_to_discard(gen_player, generated_card, player_id, ZONE_GENERATED, generated_events):
						return
					generated_card["zone"] = ZONE_HAND
					hand.append(generated_card)
					MatchMutations.apply_first_turn_hand_cost(match_state, generated_card, player_id)
					generated_events.append({"event_type": "card_drawn", "player_id": player_id, "source_instance_id": str(generated_card.get("instance_id", "")), "reason": reason})
					if gen_force_play:
						var gen_pending: Array = match_state.get("pending_forced_plays", [])
						gen_pending.append({"player_id": player_id, "instance_id": str(generated_card.get("instance_id", ""))})
		"generate_card_to_deck":
			var gen_template: Dictionary = effect.get("card_template", {})
			if not gen_template.is_empty():
				for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
					var gen_card := MatchMutations.build_generated_card(match_state, player_id, gen_template)
					var player := MatchTimingHelpers._get_player_state(match_state, player_id)
					if player.is_empty():
						return
					var deck: Array = player.get(ZONE_DECK, [])
					gen_card["zone"] = ZONE_DECK
					var insert_pos := MatchEffectParams._deterministic_index(match_state, str(gen_card.get("instance_id", "")), deck.size() + 1)
					deck.insert(insert_pos, gen_card)
					generated_events.append({"event_type": "card_shuffled_to_deck", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "inserted_instance_id": str(gen_card.get("instance_id", "")), "reason": reason})
		"copy_card_to_hand":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var copy_template: Dictionary = card.duplicate(true)
				copy_template.erase("instance_id")
				copy_template.erase("zone")
				copy_template.erase("damage_marked")
				copy_template.erase("power_bonus")
				copy_template.erase("health_bonus")
				copy_template.erase("granted_keywords")
				copy_template.erase("status_markers")
				for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
					var gen_card := MatchMutations.build_generated_card(match_state, player_id, copy_template)
					var ccth_player := MatchTimingHelpers._get_player_state(match_state, player_id)
					if ccth_player.is_empty():
						return
					if _MT()._overflow_card_to_discard(ccth_player, gen_card, player_id, ZONE_GENERATED, generated_events):
						return
					gen_card["zone"] = ZONE_HAND
					var ccth_hand: Array = ccth_player.get(ZONE_HAND, [])
					ccth_hand.append(gen_card)
					generated_events.append({"event_type": "card_drawn", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "drawn_instance_id": str(gen_card.get("instance_id", "")), "reason": reason})
		"copy_rallied_creature_to_hand":
			var crch_target_id := str(event.get("target_instance_id", ""))
			var crch_target := MatchTimingHelpers._find_card_anywhere(match_state, crch_target_id)
			if not crch_target.is_empty():
				var crch_controller := str(trigger.get("controller_player_id", ""))
				var crch_template: Dictionary = crch_target.duplicate(true)
				crch_template.erase("instance_id")
				crch_template.erase("status_markers")
				var crch_bonus_power := int(effect.get("bonus_power", 0))
				var crch_bonus_health := int(effect.get("bonus_health", 0))
				var crch_copy := MatchMutations.build_generated_card(match_state, crch_controller, crch_template)
				EvergreenRules.apply_stat_bonus(crch_copy, crch_bonus_power, crch_bonus_health, reason)
				crch_copy["zone"] = ZONE_HAND
				var crch_player := MatchTimingHelpers._get_player_state(match_state, crch_controller)
				if not crch_player.is_empty():
					var crch_hand: Array = crch_player.get(ZONE_HAND, [])
					crch_hand.append(crch_copy)
					generated_events.append({"event_type": "card_generated_to_hand", "player_id": crch_controller, "instance_id": str(crch_copy.get("instance_id", "")), "reason": reason})
		"copy_from_opponent_deck":
			var cfod_controller_id := str(trigger.get("controller_player_id", ""))
			var cfod_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), cfod_controller_id)
			var cfod_opponent := MatchTimingHelpers._get_player_state(match_state, cfod_opponent_id)
			var cfod_controller := MatchTimingHelpers._get_player_state(match_state, cfod_controller_id)
			var cfod_count := int(effect.get("count", 3))
			if not cfod_opponent.is_empty() and not cfod_controller.is_empty():
				var cfod_deck: Array = cfod_opponent.get(ZONE_DECK, [])
				var cfod_hand: Array = cfod_controller.get(ZONE_HAND, [])
				for _i in range(mini(cfod_count, cfod_deck.size())):
					var cfod_top: Dictionary = cfod_deck.back()
					var cfod_copy := MatchMutations.build_generated_card(match_state, cfod_controller_id, cfod_top)
					cfod_copy["zone"] = ZONE_HAND
					cfod_hand.append(cfod_copy)
					generated_events.append({"event_type": EVENT_CARD_DRAWN, "player_id": cfod_controller_id, "source_instance_id": str(cfod_copy.get("instance_id", "")), "reason": reason})
		"copy_creature_from_deck_to_discard":
			var ccfdtd_controller_id := str(trigger.get("controller_player_id", ""))
			var ccfdtd_player := MatchTimingHelpers._get_player_state(match_state, ccfdtd_controller_id)
			if not ccfdtd_player.is_empty():
				var ccfdtd_deck: Array = ccfdtd_player.get(ZONE_DECK, [])
				var ccfdtd_discard: Array = ccfdtd_player.get(ZONE_DISCARD, [])
				var ccfdtd_creatures: Array = []
				for ccfdtd_card in ccfdtd_deck:
					if str(ccfdtd_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						ccfdtd_creatures.append(ccfdtd_card)
				if not ccfdtd_creatures.is_empty():
					var ccfdtd_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_copy_to_discard", ccfdtd_creatures.size())
					var ccfdtd_source: Dictionary = ccfdtd_creatures[ccfdtd_idx]
					var ccfdtd_copy := MatchMutations.build_generated_card(match_state, ccfdtd_controller_id, ccfdtd_source)
					ccfdtd_copy["zone"] = ZONE_DISCARD
					var ccfdtd_mod_power := int(effect.get("modify_power", 0))
					var ccfdtd_mod_health := int(effect.get("modify_health", 0))
					if ccfdtd_mod_power != 0 or ccfdtd_mod_health != 0:
						EvergreenRules.apply_stat_bonus(ccfdtd_copy, ccfdtd_mod_power, ccfdtd_mod_health, reason)
					ccfdtd_discard.push_front(ccfdtd_copy)
					generated_events.append({"event_type": "card_milled", "source_instance_id": str(trigger.get("source_instance_id", "")), "player_id": ccfdtd_controller_id, "milled_instance_id": str(ccfdtd_copy.get("instance_id", ""))})
		"play_random_from_deck":
			var prfd_controller_id := str(trigger.get("controller_player_id", ""))
			var prfd_player := MatchTimingHelpers._get_player_state(match_state, prfd_controller_id)
			if not prfd_player.is_empty():
				var prfd_deck: Array = prfd_player.get(ZONE_DECK, [])
				if not prfd_deck.is_empty():
					var prfd_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_play_random", prfd_deck.size())
					var prfd_card: Dictionary = prfd_deck[prfd_idx]
					prfd_deck.remove_at(prfd_idx)
					prfd_card.erase("zone")
					var prfd_type := str(prfd_card.get("card_type", ""))
					if prfd_type == CARD_TYPE_CREATURE:
						var prfd_lane := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, prfd_controller_id)
						if not prfd_lane.is_empty():
							var prfd_result := MatchMutations.summon_card_to_lane(match_state, prfd_controller_id, prfd_card, prfd_lane, {"source_zone": ZONE_DECK})
							if bool(prfd_result.get("is_valid", false)):
								generated_events.append_array(prfd_result.get("events", []))
								generated_events.append(MatchSummonTiming._build_summon_event(prfd_result["card"], prfd_controller_id, prfd_lane, int(prfd_result.get("slot_index", -1)), reason))
								_MT()._check_summon_abilities(match_state, prfd_result["card"])
		"play_top_of_deck":
			var ptod_controller_id := str(trigger.get("controller_player_id", ""))
			var ptod_player := MatchTimingHelpers._get_player_state(match_state, ptod_controller_id)
			if not ptod_player.is_empty():
				var ptod_deck: Array = ptod_player.get(ZONE_DECK, [])
				if not ptod_deck.is_empty():
					var ptod_card: Dictionary = ptod_deck.pop_back()
					ptod_card.erase("zone")
					var ptod_type := str(ptod_card.get("card_type", ""))
					if ptod_type == CARD_TYPE_CREATURE:
						var ptod_lane := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, ptod_controller_id)
						if not ptod_lane.is_empty():
							var ptod_result := MatchMutations.summon_card_to_lane(match_state, ptod_controller_id, ptod_card, ptod_lane, {"source_zone": ZONE_DECK})
							if bool(ptod_result.get("is_valid", false)):
								generated_events.append_array(ptod_result.get("events", []))
								generated_events.append(MatchSummonTiming._build_summon_event(ptod_result["card"], ptod_controller_id, ptod_lane, int(ptod_result.get("slot_index", -1)), reason))
								_MT()._check_summon_abilities(match_state, ptod_result["card"])
		"play_prophecy_from_hand":
			# Mark that the player should play a prophecy from hand — this needs a pending choice
			var ppfh_controller_id := str(trigger.get("controller_player_id", ""))
			var ppfh_player := MatchTimingHelpers._get_player_state(match_state, ppfh_controller_id)
			if not ppfh_player.is_empty():
				var ppfh_hand: Array = ppfh_player.get(ZONE_HAND, [])
				var ppfh_prophecies: Array = []
				for ppfh_card in ppfh_hand:
					var ppfh_tags = ppfh_card.get("rules_tags", [])
					if typeof(ppfh_tags) == TYPE_ARRAY and ppfh_tags.has(RULE_TAG_PROPHECY):
						ppfh_prophecies.append(str(ppfh_card.get("instance_id", "")))
				if not ppfh_prophecies.is_empty():
					match_state["pending_hand_selections"].append({
						"player_id": ppfh_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"candidate_instance_ids": ppfh_prophecies,
						"then_op": "play_card_from_hand_free",
						"then_context": {},
						"prompt": "Choose a Prophecy to play from your hand.",
					})
