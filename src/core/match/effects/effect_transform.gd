class_name EffectTransform
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
		"transform":
			var transform_template := MatchSummonTiming._resolve_effect_template(match_state, trigger, event, effect)
			if transform_template.is_empty():
				return
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var transform_result := MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), transform_template, {"reason": reason})
				generated_events.append_array(transform_result.get("events", []))
		"conditional_transform":
			var ct_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not ct_source.is_empty():
				var ct_template: Dictionary = effect.get("card_template", {})
				if not ct_template.is_empty():
					var ct_result := MatchMutations.transform_card(match_state, str(ct_source.get("instance_id", "")), ct_template, {"reason": reason})
					generated_events.append_array(ct_result.get("events", []))
		"transform_in_hand":
			var tih_controller_id := str(trigger.get("controller_player_id", ""))
			var tih_template: Dictionary = effect.get("card_template", {})
			var tih_random_subtype := str(effect.get("random_subtype", ""))
			if not tih_random_subtype.is_empty():
				var tih_group: Array = ExtendedMechanicPacks.SUBTYPE_GROUPS.get(tih_random_subtype, [])
				var tih_seeds: Array = ExtendedMechanicPacks.get_catalog_seeds()
				var tih_rand_candidates: Array = []
				for tih_seed in tih_seeds:
					if not bool(tih_seed.get("collectible", true)):
						return
					if str(tih_seed.get("card_type", "")) != CARD_TYPE_CREATURE:
						return
					var tih_st = tih_seed.get("subtypes", [])
					if typeof(tih_st) != TYPE_ARRAY:
						return
					if not tih_group.is_empty():
						var tih_match := false
						for tih_s in tih_st:
							if tih_group.has(tih_s):
								tih_match = true
								break
						if not tih_match:
							return
					elif not tih_st.has(tih_random_subtype):
						return
					tih_rand_candidates.append(tih_seed)
				if not tih_rand_candidates.is_empty():
					for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
						if str(card.get("zone", "")) == ZONE_HAND:
							var tih_idx := MatchEffectParams._deterministic_index(match_state, str(card.get("instance_id", "")) + "_transform_random_subtype", tih_rand_candidates.size())
							var tih_result := MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), tih_rand_candidates[tih_idx], {"reason": reason})
							generated_events.append_array(tih_result.get("events", []))
			elif not tih_template.is_empty():
				for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
					if str(card.get("zone", "")) == ZONE_HAND:
						var tih_result := MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), tih_template, {"reason": reason})
						generated_events.append_array(tih_result.get("events", []))
		"transform_in_hand_to_random":
			var tihr_controller_id := str(trigger.get("controller_player_id", ""))
			var tihr_filter_dict: Dictionary = effect.get("filter", {}) if typeof(effect.get("filter", null)) == TYPE_DICTIONARY else {}
			var tihr_filter_type := str(effect.get("filter_card_type", tihr_filter_dict.get("card_type", "")))
			var tihr_seeds: Array = ExtendedMechanicPacks.get_catalog_seeds()
			var tihr_candidates: Array = []
			for tihr_seed in tihr_seeds:
				if not bool(tihr_seed.get("collectible", true)):
					return
				if not tihr_filter_type.is_empty() and str(tihr_seed.get("card_type", "")) != tihr_filter_type:
					return
				tihr_candidates.append(tihr_seed)
			var tihr_keep_ability := bool(effect.get("keep_ability", false))
			var tihr_source_abilities: Array = []
			if tihr_keep_ability:
				var tihr_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not tihr_source.is_empty():
					tihr_source_abilities = tihr_source.get("triggered_abilities", []).duplicate(true)
			if not tihr_candidates.is_empty():
				for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
					if str(card.get("zone", "")) == ZONE_HAND:
						var tihr_idx := MatchEffectParams._deterministic_index(match_state, str(card.get("instance_id", "")) + "_transform_random", tihr_candidates.size())
						var tihr_template: Dictionary = tihr_candidates[tihr_idx]
						var tihr_result := MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), tihr_template, {"reason": reason})
						generated_events.append_array(tihr_result.get("events", []))
						if tihr_keep_ability and not tihr_source_abilities.is_empty():
							var tihr_card := MatchTimingHelpers._find_card_anywhere(match_state, str(card.get("instance_id", "")))
							if not tihr_card.is_empty():
								var tihr_existing: Array = tihr_card.get("triggered_abilities", [])
								for tihr_ab in tihr_source_abilities:
									tihr_existing.append(tihr_ab)
								tihr_card["triggered_abilities"] = tihr_existing
		"transform_hand":
			var th_controller_id := str(trigger.get("controller_player_id", ""))
			var th_player := MatchTimingHelpers._get_player_state(match_state, th_controller_id)
			if not th_player.is_empty():
				var th_hand: Array = th_player.get(ZONE_HAND, [])
				var th_seeds: Array = ExtendedMechanicPacks.get_catalog_seeds()
				var th_collectible: Array = []
				for th_seed in th_seeds:
					if bool(th_seed.get("collectible", true)):
						th_collectible.append(th_seed)
				if not th_collectible.is_empty():
					for i in range(th_hand.size()):
						var th_card: Dictionary = th_hand[i]
						var th_idx := MatchEffectParams._deterministic_index(match_state, str(th_card.get("instance_id", "")) + "_transform_hand", th_collectible.size())
						var th_result := MatchMutations.transform_card(match_state, str(th_card.get("instance_id", "")), th_collectible[th_idx], {"reason": reason})
						generated_events.append_array(th_result.get("events", []))
		"transform_deck":
			var td_controller_id := str(trigger.get("controller_player_id", ""))
			var td_player := MatchTimingHelpers._get_player_state(match_state, td_controller_id)
			if not td_player.is_empty():
				var td_deck: Array = td_player.get(ZONE_DECK, [])
				var td_seeds: Array = ExtendedMechanicPacks.get_catalog_seeds()
				var td_collectible: Array = []
				for td_seed in td_seeds:
					if bool(td_seed.get("collectible", true)):
						td_collectible.append(td_seed)
				if not td_collectible.is_empty():
					for i in range(td_deck.size()):
						var td_card: Dictionary = td_deck[i]
						var td_idx := MatchEffectParams._deterministic_index(match_state, str(td_card.get("instance_id", "")) + "_transform_deck", td_collectible.size())
						MatchMutations.change_card(td_card, td_collectible[td_idx])
					generated_events.append({"event_type": "deck_transformed", "source_instance_id": str(trigger.get("source_instance_id", "")), "player_id": td_controller_id, "count": td_deck.size()})
		"change":
			var change_template := MatchSummonTiming._resolve_effect_template(match_state, trigger, event, effect)
			if change_template.is_empty():
				return
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var change_result := MatchMutations.change_card(card, change_template, {"reason": reason})
				generated_events.append_array(change_result.get("events", []))
		"copy":
			var source_cards := MatchTargeting._resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source")))
			if source_cards.is_empty():
				return
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var copy_result := MatchMutations.copy_card(card, source_cards[0], {
					"preserve_modifiers": bool(effect.get("preserve_modifiers", false)),
					"preserve_damage": bool(effect.get("preserve_damage", false)),
					"preserve_statuses": bool(effect.get("preserve_statuses", false)),
				})
				generated_events.append_array(copy_result.get("events", []))
		"change_attribute":
			var ca_new_attr := str(effect.get("attribute", "neutral"))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				card["attributes"] = [ca_new_attr]
				generated_events.append({"event_type": "attribute_changed", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "attribute": ca_new_attr})
		"randomize_attribute":
			var ra_attrs := ["strength", "intelligence", "willpower", "agility", "endurance", "neutral"]
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var ra_idx := MatchEffectParams._deterministic_index(match_state, str(card.get("instance_id", "")) + "_random_attr", ra_attrs.size())
				card["attributes"] = [ra_attrs[ra_idx]]
				generated_events.append({"event_type": "attribute_changed", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "attribute": ra_attrs[ra_idx]})
		"change_lane_types":
			var new_lane_type := str(effect.get("lane_type", "shadow"))
			var clts_type_lookup := MatchBootstrap._load_lane_type_lookup()
			var clts_new_record: Dictionary = clts_type_lookup.get(new_lane_type, {})
			for lane in match_state.get("lanes", []):
				lane["lane_type"] = new_lane_type
				if not clts_new_record.is_empty():
					lane["lane_rule_payload"] = MatchBootstrap._build_lane_rule_payload(clts_new_record)
				generated_events.append({"event_type": "lane_type_changed", "lane_id": str(lane.get("lane_id", "")), "new_lane_type": new_lane_type, "source_instance_id": str(trigger.get("source_instance_id", ""))})
		"change_lane_type":
			var clt_lane_type := str(effect.get("lane_type", "shadow"))
			var clt_source_loc := MatchMutations.find_card_location(match_state, str(trigger.get("source_instance_id", "")))
			var clt_lane_id := str(clt_source_loc.get("lane_id", ""))
			var clt_type_lookup := MatchBootstrap._load_lane_type_lookup()
			var clt_new_record: Dictionary = clt_type_lookup.get(clt_lane_type, {})
			for lane in match_state.get("lanes", []):
				if str(lane.get("lane_id", "")) == clt_lane_id:
					lane["lane_type"] = clt_lane_type
					if not clt_new_record.is_empty():
						lane["lane_rule_payload"] = MatchBootstrap._build_lane_rule_payload(clt_new_record)
					generated_events.append({"event_type": "lane_type_changed", "lane_id": clt_lane_id, "new_type": clt_lane_type, "source_instance_id": str(trigger.get("source_instance_id", ""))})
