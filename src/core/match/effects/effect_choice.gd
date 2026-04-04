class_name EffectChoice
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
		"choose_one":
			var co_choices_raw = effect.get("choices", [])
			var co_choices: Array = co_choices_raw if typeof(co_choices_raw) == TYPE_ARRAY else []
			if co_choices.is_empty():
				return
			var co_options: Array = []
			var co_effects_per_option: Array = []
			var co_has_card_data := false
			for co_choice in co_choices:
				if typeof(co_choice) != TYPE_DICTIONARY:
					continue
				var co_opt := {"label": str(co_choice.get("label", "")), "description": str(co_choice.get("description", ""))}
				var co_card_data = co_choice.get("card", null)
				if typeof(co_card_data) == TYPE_DICTIONARY and not co_card_data.is_empty():
					co_opt["card"] = co_card_data
					co_has_card_data = true
				co_options.append(co_opt)
				co_effects_per_option.append(co_choice.get("effects", []))
			var co_repeat := maxi(1, int(effect.get("repeat", 1)))
			var co_pending: Array = match_state.get("pending_player_choices", [])
			for co_i in range(co_repeat):
				co_pending.append({
					"player_id": str(trigger.get("controller_player_id", "")),
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"prompt": "Choose one:" if co_repeat == 1 else "Choose one (%d of %d):" % [co_i + 1, co_repeat],
					"mode": "card" if co_has_card_data else "text",
					"options": co_options.duplicate(true),
					"effects_per_option": co_effects_per_option.duplicate(true),
					"trigger": trigger.duplicate(true),
					"event": event.duplicate(true),
				})
			generated_events.append({"event_type": "player_choice_pending", "player_id": str(trigger.get("controller_player_id", "")), "source_instance_id": str(trigger.get("source_instance_id", "")), "reason": reason})
		"choose_two":
			# Assembled Titan: player picks 2 abilities from a list
			var ct_controller_id := str(trigger.get("controller_player_id", ""))
			var ct_ability_options: Array = effect.get("choices", effect.get("ability_options", []))
			if ct_ability_options.size() >= 2:
				var ct_display_options: Array = []
				var ct_effects_per: Array = []
				for ct_opt in ct_ability_options:
					if typeof(ct_opt) != TYPE_DICTIONARY:
						continue
					ct_display_options.append({"label": str(ct_opt.get("label", "Ability")), "description": str(ct_opt.get("description", ""))})
					ct_effects_per.append(ct_opt.get("effects", []))
				match_state["pending_player_choices"].append({
					"player_id": ct_controller_id,
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"prompt": "Choose the first ability.",
					"options": ct_display_options,
					"effects_per_option": ct_effects_per,
					"trigger": trigger.duplicate(true),
					"event": event.duplicate(true),
					"_choose_two_remaining": 1,
					"_all_options": ct_ability_options,
				})
		"secretly_choose_creature":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var scc_source_id := str(trigger.get("source_instance_id", ""))
				var scc_source := MatchTimingHelpers._find_card_anywhere(match_state, scc_source_id)
				if not scc_source.is_empty():
					scc_source["_secretly_chosen_target_id"] = str(card.get("instance_id", ""))
					generated_events.append({"event_type": "creature_secretly_chosen", "source_instance_id": scc_source_id, "target_instance_id": str(card.get("instance_id", "")), "reason": reason})
		"conditional_lane_bonus":
			var clb_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not clb_source.is_empty():
				var clb_location := MatchMutations.find_card_location(match_state, str(clb_source.get("instance_id", "")))
				var clb_lane_id := str(clb_location.get("lane_id", ""))
				var clb_bonuses: Dictionary = effect.get("lane_bonuses", {})
				var clb_lane_type := ""
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) == clb_lane_id:
						clb_lane_type = str(lane.get("lane_type", "field"))
						break
				# Support left_lane/right_lane keys from card data: map lane_type to left/right
				if clb_bonuses.is_empty():
					var clb_is_left := (clb_lane_type == "field")
					clb_bonuses = {"left": effect.get("left_lane", {}), "right": effect.get("right_lane", {})}
					clb_lane_type = "left" if clb_is_left else "right"
				var clb_bonus: Dictionary = clb_bonuses.get(clb_lane_type, {})
				if not clb_bonus.is_empty():
					var clb_power := int(clb_bonus.get("power", 0))
					var clb_health := int(clb_bonus.get("health", 0))
					EvergreenRules.apply_stat_bonus(clb_source, clb_power, clb_health, reason)
					generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(clb_source.get("instance_id", "")), "power_bonus": clb_power, "health_bonus": clb_health, "reason": reason})
					var clb_kw_list: Array = clb_bonus.get("keywords", [])
					if clb_kw_list.is_empty() and clb_bonus.has("keyword"):
						clb_kw_list = [str(clb_bonus["keyword"])]
					for kw in clb_kw_list:
						EvergreenRules.ensure_card_state(clb_source)
						var clb_granted: Array = clb_source.get("granted_keywords", [])
						if not clb_granted.has(str(kw)):
							clb_granted.append(str(kw))
							clb_source["granted_keywords"] = clb_granted
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(clb_source.get("instance_id", "")), "keyword_id": str(kw)})
		"conditional_drawn_card_bonus":
			# Gates of Madness: when you draw a card, apply bonus based on card type
			var cdcb_drawn_id := str(event.get("drawn_instance_id", event.get("instance_id", "")))
			var cdcb_drawn := MatchTimingHelpers._find_card_anywhere(match_state, cdcb_drawn_id)
			if not cdcb_drawn.is_empty():
				var cdcb_type := str(cdcb_drawn.get("card_type", ""))
				if (cdcb_type == "creature" or cdcb_type == "item") and effect.has("creature_item"):
					var cdcb_ci: Dictionary = effect["creature_item"]
					EvergreenRules.apply_stat_bonus(cdcb_drawn, int(cdcb_ci.get("power", 0)), int(cdcb_ci.get("health", 0)), reason)
					generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": cdcb_drawn_id, "power_bonus": int(cdcb_ci.get("power", 0)), "health_bonus": int(cdcb_ci.get("health", 0)), "reason": reason})
				elif (cdcb_type == "action" or cdcb_type == "support") and effect.has("action_support"):
					var cdcb_as: Dictionary = effect["action_support"]
					var cdcb_reduction := int(cdcb_as.get("cost_reduction", 0))
					if cdcb_reduction > 0:
						cdcb_drawn["cost"] = maxi(0, int(cdcb_drawn.get("cost", 0)) - cdcb_reduction)
						generated_events.append({"event_type": "cost_reduced", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": cdcb_drawn_id, "reduction": cdcb_reduction, "reason": reason})
		"look_draw_discard":
			var ldd_controller_id := str(trigger.get("controller_player_id", ""))
			var ldd_player := MatchTimingHelpers._get_player_state(match_state, ldd_controller_id)
			if not ldd_player.is_empty():
				var ldd_deck: Array = ldd_player.get(ZONE_DECK, [])
				var ldd_count := int(effect.get("count", 3))
				var ldd_revealed: Array = []
				for _i in range(mini(ldd_count, ldd_deck.size())):
					ldd_revealed.append(ldd_deck.pop_back())
				if not ldd_revealed.is_empty():
					match_state["pending_top_deck_choices"].append({
						"player_id": ldd_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"cards": ldd_revealed,
						"mode": "keep_one_discard_rest",
						"prompt": "Choose a card to keep.",
					})
		"look_give_draw":
			var lgd_controller_id := str(trigger.get("controller_player_id", ""))
			var lgd_player := MatchTimingHelpers._get_player_state(match_state, lgd_controller_id)
			if not lgd_player.is_empty():
				var lgd_deck: Array = lgd_player.get(ZONE_DECK, [])
				var lgd_count := int(effect.get("count", 3))
				var lgd_revealed: Array = []
				for _i in range(mini(lgd_count, lgd_deck.size())):
					lgd_revealed.append(lgd_deck.pop_back())
				if not lgd_revealed.is_empty():
					match_state["pending_top_deck_choices"].append({
						"player_id": lgd_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"cards": lgd_revealed,
						"mode": "give_one_draw_rest",
						"prompt": "Choose a card to give to your opponent.",
					})
		"choose_card_in_hand_and_shuffle_copies":
			var ccihsc_controller_id := str(trigger.get("controller_player_id", ""))
			var ccihsc_player := MatchTimingHelpers._get_player_state(match_state, ccihsc_controller_id)
			if not ccihsc_player.is_empty():
				var ccihsc_hand: Array = ccihsc_player.get(ZONE_HAND, [])
				var ccihsc_filter: Dictionary = effect.get("filter", {})
				var ccihsc_allowed_types: Array = ccihsc_filter.get("card_type_in", ["creature"])
				var ccihsc_candidate_ids: Array = []
				for ccihsc_card in ccihsc_hand:
					if ccihsc_allowed_types.has(str(ccihsc_card.get("card_type", ""))):
						ccihsc_candidate_ids.append(str(ccihsc_card.get("instance_id", "")))
				if not ccihsc_candidate_ids.is_empty():
					var ccihsc_power := int(effect.get("stat_bonus_power", effect.get("power_bonus", 3)))
					var ccihsc_health := int(effect.get("stat_bonus_health", effect.get("health_bonus", 3)))
					var ccihsc_copies := int(effect.get("copy_count", 3))
					match_state["pending_hand_selections"].append({
						"player_id": ccihsc_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"candidate_instance_ids": ccihsc_candidate_ids,
						"then_op": "shuffle_buffed_copies",
						"then_context": {"power_bonus": ccihsc_power, "health_bonus": ccihsc_health, "copy_count": ccihsc_copies},
						"prompt": "Choose a creature or item to shuffle copies of into your deck.",
					})
		"choose_cost_trigger":
			var cct_controller_id := str(trigger.get("controller_player_id", ""))
			var cct_options: Array = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
			match_state["pending_player_choices"].append({
				"player_id": cct_controller_id,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"options": cct_options,
				"then_op": "set_cost_trigger",
				"then_context": effect.get("trigger_effects", {}),
				"prompt": "Choose a cost.",
			})
		"choose_cost_lock":
			var ccl_controller_id := str(trigger.get("controller_player_id", ""))
			var ccl_options: Array = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
			match_state["pending_player_choices"].append({
				"player_id": ccl_controller_id,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"options": ccl_options,
				"then_op": "set_cost_lock",
				"then_context": {},
				"prompt": "Choose a cost to lock.",
			})
		"select_card_from_hand":
			var sch_controller_id := str(trigger.get("controller_player_id", ""))
			var sch_player := MatchTimingHelpers._get_player_state(match_state, sch_controller_id)
			if not sch_player.is_empty():
				var sch_filter: Dictionary = effect.get("filter", {}) if typeof(effect.get("filter", {})) == TYPE_DICTIONARY else {}
				var sch_candidates: Array = []
				for sch_card in sch_player.get(ZONE_HAND, []):
					if typeof(sch_card) != TYPE_DICTIONARY:
						continue
					if ExtendedMechanicPacks.card_matches_hand_selection_filter(sch_card, sch_filter):
						sch_candidates.append(str(sch_card.get("instance_id", "")))
				if not sch_candidates.is_empty():
					match_state["pending_hand_selections"].append({
						"player_id": sch_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"candidate_instance_ids": sch_candidates,
						"then_op": str(effect.get("then_op", "")),
						"then_context": effect.get("then_context", {}).duplicate(true) if typeof(effect.get("then_context", {})) == TYPE_DICTIONARY else {},
						"prompt": str(effect.get("prompt", "Choose a card from your hand.")),
						"mandatory": bool(effect.get("mandatory", false)),
					})
		"optional_discard_and_summon":
			var odas_controller_id := str(trigger.get("controller_player_id", ""))
			var odas_player := MatchTimingHelpers._get_player_state(match_state, odas_controller_id)
			if not odas_player.is_empty():
				var odas_hand: Array = odas_player.get(ZONE_HAND, [])
				var odas_card_ids: Array = []
				for odas_card in odas_hand:
					odas_card_ids.append(str(odas_card.get("instance_id", "")))
				if not odas_card_ids.is_empty():
					match_state["pending_hand_selections"].append({
						"player_id": odas_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"candidate_instance_ids": odas_card_ids,
						"then_op": "discard_and_summon_from_discard",
						"then_context": effect.get("summon_context", {}),
						"prompt": "Choose a card to discard, or press Escape to skip.",
					})
		"build_custom_fabricant":
			# Fabricate: choose attack, health, keywords to build a creature
			var bcf_controller_id := str(trigger.get("controller_player_id", ""))
			var bcf_options: Array = effect.get("options", [
				{"label": "+3/+3", "description": "3 power, 3 health", "effects": [{"op": "summon_from_effect", "card_template": {"definition_id": "cwc_neu_custom_fabricant", "name": "Custom Fabricant", "card_type": "creature", "subtypes": ["Fabricant"], "attributes": ["neutral"], "cost": 0, "power": 3, "health": 3, "base_power": 3, "base_health": 3}}]},
				{"label": "+5/+5", "description": "5 power, 5 health", "effects": [{"op": "summon_from_effect", "card_template": {"definition_id": "cwc_neu_custom_fabricant", "name": "Custom Fabricant", "card_type": "creature", "subtypes": ["Fabricant"], "attributes": ["neutral"], "cost": 0, "power": 5, "health": 5, "base_power": 5, "base_health": 5}}]},
			])
			var bcf_display: Array = []
			var bcf_effects: Array = []
			for bcf_opt in bcf_options:
				if typeof(bcf_opt) == TYPE_DICTIONARY:
					bcf_display.append({"label": str(bcf_opt.get("label", "")), "description": str(bcf_opt.get("description", ""))})
					bcf_effects.append(bcf_opt.get("effects", []))
			match_state["pending_player_choices"].append({
				"player_id": bcf_controller_id,
				"source_instance_id": str(trigger.get("source_instance_id", "")),
				"prompt": "Choose your Fabricant's design.",
				"options": bcf_display,
				"effects_per_option": bcf_effects,
				"trigger": trigger.duplicate(true),
				"event": event.duplicate(true),
			})
		"stitch_creatures_from_decks":
			# Mecinar: combine top creature of each deck into an Abomination
			var scfd_controller_id := str(trigger.get("controller_player_id", ""))
			var scfd_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), scfd_controller_id)
			var scfd_player := MatchTimingHelpers._get_player_state(match_state, scfd_controller_id)
			var scfd_opponent := MatchTimingHelpers._get_player_state(match_state, scfd_opponent_id)
			if not scfd_player.is_empty() and not scfd_opponent.is_empty():
				var scfd_p_deck: Array = scfd_player.get(ZONE_DECK, [])
				var scfd_o_deck: Array = scfd_opponent.get(ZONE_DECK, [])
				var scfd_p_creature: Dictionary = {}
				var scfd_o_creature: Dictionary = {}
				for i in range(scfd_p_deck.size() - 1, -1, -1):
					if str(scfd_p_deck[i].get("card_type", "")) == CARD_TYPE_CREATURE:
						scfd_p_creature = scfd_p_deck[i]
						scfd_p_deck.remove_at(i)
						break
				for i in range(scfd_o_deck.size() - 1, -1, -1):
					if str(scfd_o_deck[i].get("card_type", "")) == CARD_TYPE_CREATURE:
						scfd_o_creature = scfd_o_deck[i]
						scfd_o_deck.remove_at(i)
						break
				var scfd_power := int(scfd_p_creature.get("power", scfd_p_creature.get("base_power", 0))) + int(scfd_o_creature.get("power", scfd_o_creature.get("base_power", 0)))
				var scfd_health := int(scfd_p_creature.get("health", scfd_p_creature.get("base_health", 0))) + int(scfd_o_creature.get("health", scfd_o_creature.get("base_health", 0)))
				var scfd_keywords: Array = []
				for kw in scfd_p_creature.get("keywords", []):
					if not scfd_keywords.has(str(kw)):
						scfd_keywords.append(str(kw))
				for kw in scfd_o_creature.get("keywords", []):
					if not scfd_keywords.has(str(kw)):
						scfd_keywords.append(str(kw))
				var scfd_template: Dictionary = {
					"definition_id": "cwc_neu_abomination",
					"name": "Abomination",
					"card_type": "creature",
					"subtypes": ["Fabricant"],
					"attributes": ["neutral"],
					"cost": 0,
					"power": scfd_power,
					"health": scfd_health,
					"base_power": scfd_power,
					"base_health": scfd_health,
					"keywords": scfd_keywords,
				}
				var scfd_card := MatchMutations.build_generated_card(match_state, scfd_controller_id, scfd_template)
				var scfd_lane_id := MatchSummonTiming._resolve_summon_lane_id(match_state, trigger, event, effect, scfd_controller_id)
				if not scfd_lane_id.is_empty():
					var scfd_result := MatchMutations.summon_card_to_lane(match_state, scfd_controller_id, scfd_card, scfd_lane_id, {"source_zone": ZONE_GENERATED})
					if bool(scfd_result.get("is_valid", false)):
						generated_events.append_array(scfd_result.get("events", []))
						generated_events.append(MatchSummonTiming._build_summon_event(scfd_result["card"], scfd_controller_id, scfd_lane_id, int(scfd_result.get("slot_index", -1)), reason))
						_MT()._check_summon_abilities(match_state, scfd_result["card"])
		"learn_action":
			var la_controller_id := str(trigger.get("controller_player_id", ""))
			var la_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not la_source.is_empty():
				for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
					var la_learned: Array = la_source.get("_learned_actions", [])
					if typeof(la_learned) != TYPE_ARRAY:
						la_learned = []
					la_learned.append(card.duplicate(true))
					la_source["_learned_actions"] = la_learned
					generated_events.append({"event_type": "action_learned", "source_instance_id": str(trigger.get("source_instance_id", "")), "learned_card": str(card.get("name", ""))})
		"play_learned_actions":
			var pla_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not pla_source.is_empty():
				var pla_learned: Array = pla_source.get("_learned_actions", [])
				if typeof(pla_learned) == TYPE_ARRAY:
					var pla_controller := str(trigger.get("controller_player_id", ""))
					var pla_source_id := str(trigger.get("source_instance_id", ""))
					for pla_action in pla_learned:
						if typeof(pla_action) != TYPE_DICTIONARY:
							continue
						var pla_abilities = pla_action.get("triggered_abilities", [])
						if typeof(pla_abilities) != TYPE_ARRAY:
							continue
						for pla_ab in pla_abilities:
							if typeof(pla_ab) == TYPE_DICTIONARY and str(pla_ab.get("family", "")) == FAMILY_ON_PLAY:
								var pla_tm := str(pla_ab.get("target_mode", ""))
								var pla_trigger := trigger.duplicate(true)
								pla_trigger["descriptor"] = pla_ab
								if not pla_tm.is_empty():
									# Auto-resolve random valid target for learned actions
									var pla_valid := MatchTargeting.get_valid_targets_for_mode(match_state, pla_source_id, pla_tm, pla_ab)
									if not pla_valid.is_empty():
										var pla_pick_idx := MatchEffectParams._deterministic_index(match_state, pla_source_id + "_learned_" + str(pla_action.get("name", "")), pla_valid.size())
										var pla_pick: Dictionary = pla_valid[pla_pick_idx]
										if pla_pick.has("instance_id"):
											pla_trigger["_chosen_target_id"] = str(pla_pick.get("instance_id", ""))
										elif pla_pick.has("player_id"):
											pla_trigger["_chosen_target_player_id"] = str(pla_pick.get("player_id", ""))
										generated_events.append_array(_MT()._apply_effects(match_state, pla_trigger, event, {}))
								else:
									generated_events.append_array(_MT()._apply_effects(match_state, pla_trigger, event, {}))
