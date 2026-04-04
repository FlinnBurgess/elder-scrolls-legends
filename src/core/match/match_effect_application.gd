class_name MatchEffectApplication
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
const LaneEffectRules = preload("res://src/core/match/lane_effect_rules.gd")

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

const FAMILY_SUMMON := "summon"
const FAMILY_LAST_GASP := "last_gasp"
const FAMILY_SLAY := "slay"
const FAMILY_PILFER := "pilfer"
const FAMILY_EXPERTISE := "expertise"
const FAMILY_ON_PLAY := "on_play"
const FAMILY_EXALT := "exalt"
const FAMILY_TREASURE_HUNT := "treasure_hunt"
const FAMILY_WAX := "wax"
const FAMILY_WANE := "wane"
const FAMILY_ON_EQUIP := "on_equip"
const FAMILY_ACTIVATE := "activate"

const WINDOW_AFTER := "after"
const WINDOW_IMMEDIATE := "immediate"

const EVENT_CARD_OVERDRAW := "card_overdraw"
const RULE_TAG_PROPHECY := "prophecy"
const FAMILY_VETERAN := "veteran"

const MAX_HAND_SIZE := 10
const RANDOM_KEYWORD_POOL := ["breakthrough", "charge", "drain", "guard", "lethal", "regenerate", "ward"]

static func _MT():
	return load("res://src/core/match/match_timing.gd")


const EffectStats = preload("res://src/core/match/effects/effect_stats.gd")
const EffectDamage = preload("res://src/core/match/effects/effect_damage.gd")
const EffectSummon = preload("res://src/core/match/effects/effect_summon.gd")
const EffectDraw = preload("res://src/core/match/effects/effect_draw.gd")
const EffectMovement = preload("res://src/core/match/effects/effect_movement.gd")
const EffectKeywords = preload("res://src/core/match/effects/effect_keywords.gd")
const EffectTriggers = preload("res://src/core/match/effects/effect_triggers.gd")
const EffectHealing = preload("res://src/core/match/effects/effect_healing.gd")
const EffectTransform = preload("res://src/core/match/effects/effect_transform.gd")
const EffectSacrifice = preload("res://src/core/match/effects/effect_sacrifice.gd")
const EffectItems = preload("res://src/core/match/effects/effect_items.gd")
const EffectChoice = preload("res://src/core/match/effects/effect_choice.gd")
const EffectMisc = preload("res://src/core/match/effects/effect_misc.gd")
static func _apply_effects(match_state: Dictionary, trigger: Dictionary, event: Dictionary, resolution: Dictionary) -> Array:
	var generated_events: Array = []
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var reason := str(descriptor.get("family", "trigger"))
	# Consume-gated abilities (pilfer, etc.) — defer effects until player picks a consume target
	if bool(descriptor.get("consume", false)) and not trigger.has("_consumed_card_info"):
		var consume_controller_id := str(trigger.get("controller_player_id", ""))
		var consume_source_id := str(trigger.get("source_instance_id", ""))
		var consume_candidates = _MT().get_consume_candidates(match_state, consume_controller_id)
		if consume_candidates.is_empty():
			return generated_events  # No discard creatures — consume fails, effects don't fire
		var consume_candidate_ids: Array = []
		for cc in consume_candidates:
			consume_candidate_ids.append(str(cc.get("instance_id", "")))
		var consume_pending: Array = match_state.get("pending_consume_selections", [])
		consume_pending.append({
			"player_id": consume_controller_id,
			"source_instance_id": consume_source_id,
			"candidate_instance_ids": consume_candidate_ids,
			"has_target_mode": false,
			"trigger_index": int(trigger.get("trigger_index", 0)),
		})
		return generated_events  # Defer — effects will fire after consume resolves
	# Special handling for treasure_hunt family — check drawn card against hunt requirements
	if reason == FAMILY_TREASURE_HUNT:
		var th_result := MatchSummonTiming._process_treasure_hunt(match_state, trigger, event, descriptor)
		generated_events.append_array(th_result.get("events", []))
		if not bool(th_result.get("hunt_complete", false)):
			return generated_events  # Hunt not complete yet, don't fire effects
	# Deferred targeting: if no _chosen_target_id is set but effects reference chosen_* targets,
	# split into immediate effects (apply now) and deferred effects (queue target selection).
	var _ae_chosen_id := str(trigger.get("_chosen_target_id", ""))
	if _ae_chosen_id.is_empty():
		var _ae_all_effects: Array = descriptor.get("effects", [])
		var _ae_deferred: Array = []
		var _ae_immediate: Array = []
		var _ae_deferred_tm := ""
		for _ae_eff in _ae_all_effects:
			if typeof(_ae_eff) != TYPE_DICTIONARY:
				_ae_immediate.append(_ae_eff)
				continue
			var _ae_target := str(_ae_eff.get("target", ""))
			var _ae_tm: String = str(_MT()._choice_target_to_target_mode(_ae_target))
			if not _ae_tm.is_empty():
				_ae_deferred.append(_ae_eff)
				if _ae_deferred_tm.is_empty():
					_ae_deferred_tm = _ae_tm
			else:
				_ae_immediate.append(_ae_eff)
		if not _ae_deferred.is_empty():
			# Replace the descriptor effects with only immediate effects
			descriptor = descriptor.duplicate(true)
			descriptor["effects"] = _ae_immediate
			trigger = trigger.duplicate(true)
			trigger["descriptor"] = descriptor
			# Queue deferred effects for target selection
			var _ae_source_id := str(trigger.get("source_instance_id", ""))
			var _ae_controller_id := str(trigger.get("controller_player_id", ""))
			var _ae_valid := MatchTargeting.get_valid_targets_for_mode(match_state, _ae_source_id, _ae_deferred_tm, {})
			if not _ae_valid.is_empty():
				var _ae_pending: Array = match_state.get("pending_summon_effect_targets", [])
				_ae_pending.append({
					"player_id": _ae_controller_id,
					"source_instance_id": _ae_source_id,
					"mandatory": true,
					"_choice_deferred_effects": _ae_deferred,
					"_choice_trigger": trigger.duplicate(true),
					"_choice_event": event.duplicate(true),
					"_choice_target_mode": _ae_deferred_tm,
				})
	for raw_effect in descriptor.get("effects", []):
		if typeof(raw_effect) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = raw_effect
		if not ExtendedMechanicPacks.effect_is_enabled(match_state, trigger, effect):
			continue
		if bool(effect.get("require_event_target_alive", false)):
			var alive_check_id := MatchTimingHelpers._event_target_instance_id(event)
			if alive_check_id.is_empty():
				continue
			var alive_check_card := MatchTimingHelpers._find_card_anywhere(match_state, alive_check_id)
			if alive_check_card.is_empty() or str(alive_check_card.get("zone", "")) != ZONE_LANE:
				continue
		var op := str(effect.get("op", ""))
		var ctx := {
			"descriptor": descriptor,
			"reason": reason,
		}
		match op:
			# Stats
			"conditional_double_stat", "double_health", "double_stats", "modify_cost", "modify_stats", "modify_stats_per_keyword", "reduce_cost_in_hand", "reduce_cost_top_of_deck", "set_all_friendly_power_to_max", "set_health", "set_power", "set_power_equal_to_health", "set_power_to_health", "set_stats", "spend_all_magicka_for_stats", "swap_stats":
				EffectStats.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Damage
			"battle_creature", "battle_random_enemy", "battle_strongest_enemy", "deal_damage", "deal_damage_and_heal", "deal_damage_from_creature", "deal_damage_to_lane", "delayed_destroy", "destroy_all_except_random", "destroy_all_except_strongest_in_lane", "destroy_creature", "destroy_creature_end_of_turn", "destroy_front_rune_and_steal_draw", "destroy_item", "player_battle_creature":
				EffectDamage.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Summon
			"fill_lane_with", "summon_all_from_discard_by_name", "summon_copies_to_lane", "summon_copy", "summon_copy_of_self", "summon_copy_to_other_lane", "summon_each_unique_from_deck", "summon_from_deck_by_cost", "summon_from_deck_filtered", "summon_from_discard", "summon_from_discard_highest_cost", "summon_from_effect", "summon_from_hand_to_full_lane", "summon_from_opponent_discard", "summon_or_buff", "summon_random_by_cost", "summon_random_creature", "summon_random_daedra_by_gate_level", "summon_random_daedra_total_cost", "summon_random_from_collection", "summon_random_from_discard", "summon_top_creature_from_deck":
				EffectSummon.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Draw
			"copy_card_to_hand", "copy_creature_from_deck_to_discard", "copy_drawn_card_to_hand", "copy_from_opponent_deck", "copy_rallied_creature_to_hand", "draw_all_creatures_from_discard", "draw_cards", "draw_cards_per_runes", "draw_copy_of_consumed", "draw_filtered", "draw_from_deck_filtered", "draw_from_discard_filtered", "draw_if_top_deck_subtype", "draw_if_wielder_has_items", "draw_or_treasure_hunt", "draw_specific_from_deck", "generate_card_to_deck", "generate_card_to_hand", "play_prophecy_from_hand", "play_random_from_deck", "play_top_of_deck":
				EffectDraw.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Movement
			"banish", "banish_and_return_end_of_turn", "banish_by_name_from_opponent", "banish_discard_pile", "banish_from_opponent_deck", "discard", "discard_from_hand", "discard_hand", "discard_hand_end_of_turn", "discard_matching_from_opponent_deck", "discard_random", "discard_top_of_deck", "draw_from_opponent_discard", "may_move_between_lanes", "mill", "move_back_end_of_turn", "move_between_lanes", "return_equipped_items_to_hand", "return_stolen", "return_to_deck_and_draw_later", "return_to_hand", "shuffle_all_creatures_into_deck", "shuffle_copies_into_deck", "shuffle_copies_to_deck", "shuffle_discard_creatures_to_deck_with_buff", "shuffle_hand_to_deck_and_draw", "shuffle_into_deck", "shuffle_self_into_deck", "steal", "steal_from_discard", "unsummon", "unsummon_end_of_turn":
				EffectMovement.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Keywords
			"copy_all_friendly_keywords", "copy_keywords_to_friendly", "destroy_and_transfer_keywords", "gain_keywords_from_top_deck", "grant_extra_attack", "grant_immunity", "grant_keyword", "grant_keyword_to_all_copies", "grant_pilfer_draw", "grant_random_keyword", "grant_slay_ability", "grant_slay_draw", "grant_status", "grant_temporary_immunity", "modify_stats_if_shares_subtype_with_top_deck", "remove_keyword", "remove_status", "sacrifice_if_no_ward", "shackle", "silence", "steal_keywords", "steal_status":
				EffectKeywords.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Triggers
			"copy_summon_ability", "enable_dual_wax_wane", "grant_double_activate", "grant_double_summon_this_turn", "grant_effect_this_turn", "grant_triggered_ability", "repeat_slay_reward", "trigger_all_friendly_summons", "trigger_exalt_all_friendly", "trigger_friendly_last_gasps", "trigger_summon_ability", "trigger_wane", "trigger_wax":
				EffectTriggers.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Healing
			"add_support_uses", "cost_increase_next_turn", "double_max_magicka_gain", "gain_max_magicka", "gain_unspent_magicka_from_last_turn", "heal", "increase_opponent_action_cost", "prevent_rune_draw", "restore_creature_health", "restore_magicka", "restore_rune", "set_power_cap_in_lane":
				EffectHealing.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Transform
			"change", "change_attribute", "change_lane_type", "change_lane_types", "conditional_transform", "copy", "randomize_attribute", "transform", "transform_deck", "transform_hand", "transform_in_hand", "transform_in_hand_to_random":
				EffectTransform.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Sacrifice
			"consume", "consume_all_creatures_in_discard_this_turn", "consume_and_copy_veteran", "consume_and_reduce_matching_subtype_cost", "consume_card", "consume_or_sacrifice", "optional_consume_for_keyword", "recall_and_resummon", "sacrifice", "sacrifice_and_absorb_stats", "sacrifice_and_equip_from_deck", "sacrifice_and_resummon", "sacrifice_and_summon_from_deck":
				EffectSacrifice.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Items
			"buff_creatures_in_deck", "buff_creatures_in_discard", "buff_items_in_deck", "equip_copies_from_discard", "equip_copy_of_item", "equip_generated_item", "equip_item", "equip_items_from_discard", "modify_item_in_hand", "modify_random_item_in_hand", "reequip_all_items_to", "steal_item_from_opponent_discard", "steal_items":
				EffectItems.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Choice
			"build_custom_fabricant", "choose_card_in_hand_and_shuffle_copies", "choose_cost_lock", "choose_cost_trigger", "choose_one", "choose_two", "conditional_drawn_card_bonus", "conditional_lane_bonus", "learn_action", "look_draw_discard", "look_give_draw", "optional_discard_and_summon", "play_learned_actions", "secretly_choose_creature", "select_card_from_hand", "stitch_creatures_from_decks":
				EffectChoice.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			# Misc
			"add_counter", "aim_at", "buff_random_hand_card", "grant_aura_by_chosen_subtype", "log", "mark_for_resummon", "mark_target", "redirect_damage_to_self", "reveal_opponent_hand_card", "reveal_opponent_top_deck", "swap_creatures", "top_deck_attribute_bonus":
				EffectMisc.apply(op, match_state, trigger, event, effect, generated_events, ctx)
			_:
				var resolved_effect := effect
				if effect.has("amount_source") and not str(effect.get("amount_source", "")).is_empty():
					resolved_effect = effect.duplicate(true)
					resolved_effect["amount"] = MatchEffectParams._resolve_amount(trigger, effect, match_state, event)
				var custom_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, resolved_effect)
				if bool(custom_result.get("handled", false)):
					generated_events.append_array(custom_result.get("events", []))
				else:
					var lane_result := LaneEffectRules.apply_lane_effect(match_state, trigger, event, resolved_effect)
					if bool(lane_result.get("handled", false)):
						generated_events.append_array(lane_result.get("events", []))
	return generated_events
