class_name MatchTiming
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const BoonRules = preload("res://src/adventure/boon_rules.gd")
const LaneEffectRules = preload("res://src/core/match/lane_effect_rules.gd")
const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")
const MatchEffectParams = preload("res://src/core/match/match_effect_params.gd")
const MatchAuras = preload("res://src/core/match/match_auras.gd")
const MatchTriggers = preload("res://src/core/match/match_triggers.gd")
const MatchTargeting = preload("res://src/core/match/match_targeting.gd")
const MatchSummonTiming = preload("res://src/core/match/match_summon_timing.gd")
const MatchEffectApplication = preload("res://src/core/match/match_effect_application.gd")

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

const RULE_TAG_PROPHECY := "prophecy"
const RULE_TAG_OUT_OF_CARDS := "out_of_cards"

const WINDOW_INTERRUPT := "interrupt"
const WINDOW_IMMEDIATE := "immediate"
const WINDOW_AFTER := "after"

const EVENT_TURN_STARTED := "turn_started"
const EVENT_TURN_ENDING := "turn_ending"
const EVENT_CARD_PLAYED := "card_played"
const EVENT_SUPPORT_ACTIVATED := "support_activated"
const EVENT_CREATURE_SUMMONED := "creature_summoned"
const EVENT_DAMAGE_RESOLVED := "damage_resolved"
const EVENT_CREATURE_DESTROYED := "creature_destroyed"
const EVENT_CARD_DRAWN := "card_drawn"
const EVENT_RUNE_BROKEN := "rune_broken"
const EVENT_PROPHECY_WINDOW_OPENED := "prophecy_window_opened"
const EVENT_PROPHECY_DECLINED := "prophecy_declined"
const EVENT_OUT_OF_CARDS_PLAYED := "out_of_cards_played"
const EVENT_CARD_OVERDRAW := "card_overdraw"

const MAX_HAND_SIZE := 10

const FAMILY_START_OF_TURN := "start_of_turn"
const FAMILY_END_OF_TURN := "end_of_turn"
const FAMILY_ON_PLAY := "on_play"
const FAMILY_ACTIVATE := "activate"
const FAMILY_SUMMON := "summon"
const FAMILY_ON_DAMAGE := "on_damage"
const FAMILY_ON_DEATH := "on_death"
const FAMILY_LAST_GASP := "last_gasp"
const FAMILY_SLAY := "slay"
const FAMILY_PILFER := "pilfer"
const FAMILY_VETERAN := "veteran"
const FAMILY_EXPERTISE := "expertise"
const FAMILY_PLOT := "plot"
const FAMILY_RUNE_BREAK := "rune_break"
const FAMILY_ON_FRIENDLY_DEATH := "on_friendly_death"
const FAMILY_ON_ATTACK := "on_attack"
const FAMILY_ON_EQUIP := "on_equip"
const FAMILY_AFTER_ACTION_PLAYED := "after_action_played"
const FAMILY_ON_WARD_BROKEN := "on_ward_broken"
const FAMILY_ON_FRIENDLY_SLAY := "on_friendly_slay"
const FAMILY_ON_MOVE := "on_move"
const FAMILY_ITEM_DETACHED := "item_detached"
const FAMILY_ON_ENEMY_RUNE_DESTROYED := "on_enemy_rune_destroyed"
const FAMILY_ON_ENEMY_SHACKLED := "on_enemy_shackled"
const FAMILY_ON_PLAYER_HEALED := "on_player_healed"
const FAMILY_ON_MAX_MAGICKA_GAINED := "on_max_magicka_gained"
const FAMILY_ON_CREATURE_HEALED := "on_creature_healed"
const FAMILY_ON_FRIENDLY_SUMMON := "on_friendly_summon"
const FAMILY_ON_COVER_GAINED := "on_cover_gained"
const FAMILY_ON_CARD_DRAWN := "on_card_drawn"
const FAMILY_ON_ENEMY_SUMMON := "on_enemy_summon"
const FAMILY_ON_FRIENDLY_EQUIP := "on_friendly_equip"
const FAMILY_ON_FRIENDLY_CARD_PLAYED := "on_friendly_card_played"
const FAMILY_ON_FRIENDLY_SUPPORT_PLAYED := "on_friendly_support_played"
const FAMILY_ON_OPPONENT_TURN := "on_opponent_turn"
const FAMILY_AFTER_CARD_PLAYED := "after_card_played"
const FAMILY_ON_OPPONENT_DAMAGED := "on_opponent_damaged"
const FAMILY_ON_KEYWORD_GAINED := "on_keyword_gained"
const FAMILY_ON_FRIENDLY_POWER_GAIN := "on_friendly_power_gain"
const FAMILY_ON_CONSUMED := "on_consumed"
const FAMILY_ON_ENEMY_PROPHECY_DRAWN := "on_enemy_prophecy_drawn"
const FAMILY_ON_FRIENDLY_SACRIFICE := "on_friendly_sacrifice"
const FAMILY_ON_DEAL_DAMAGE_TO_CREATURE := "on_deal_damage_to_creature"
const FAMILY_ON_ENEMY_DAMAGED := "on_enemy_damaged"
const FAMILY_ON_TARGETED_BY_ACTION := "on_targeted_by_action"
const FAMILY_ON_RALLY := "on_rally"
const FAMILY_ON_SUPPORT_COUNT_REACHED := "on_support_count_reached"
const FAMILY_ON_OPPONENT_CARD_DRAWN := "on_opponent_card_drawn"
const FAMILY_AFTER_FRIENDLY_ACTION_DAMAGES_ENEMY := "after_friendly_action_damages_enemy"
const FAMILY_ON_FRIENDLY_PILFER_OR_DRAIN := "on_friendly_pilfer_or_drain"
const FAMILY_ON_FRIENDLY_CREATURE_DEATH_COUNT := "on_friendly_creature_death_count"
const FAMILY_ON_ENEMY_STAT_REDUCTION := "on_enemy_stat_reduction"
const FAMILY_ON_FRIENDLY_DRAGON_DAMAGE := "on_friendly_dragon_damage"
const FAMILY_ON_PLAYER_HEALTH_ZERO := "on_player_health_zero"
const FAMILY_WAX := "wax"
const FAMILY_WANE := "wane"
const FAMILY_ON_FRIENDLY_WAX := "on_friendly_wax"
const FAMILY_ON_FRIENDLY_WANE := "on_friendly_wane"
const FAMILY_EXALT := "exalt"
const FAMILY_ON_RALLY_EMPTY_HAND := "on_rally_empty_hand"
const FAMILY_ON_GAIN_MAX_MAGICKA := "on_gain_max_magicka"
const FAMILY_TREASURE_HUNT := "treasure_hunt"
const FAMILY_ON_FRIENDLY_TREASURE_FOUND := "on_friendly_treasure_found"
const FAMILY_ON_INVADE := "on_invade"
const FAMILY_ON_MAX_MAGICKA_GAIN_2 := "on_max_magicka_gain"
const FAMILY_ON_DISCARD_LEAVE := "on_discard_leave"
const FAMILY_ON_MAGICKA_THRESHOLD := "on_magicka_threshold"

const EVENT_CARD_EQUIPPED := "card_equipped"
const EVENT_CREATURE_CONSUMED := "card_consumed"
const EVENT_CREATURE_SACRIFICED := "card_sacrificed"

const PLAYER_ZONE_ORDER := [ZONE_HAND, ZONE_SUPPORT, ZONE_DISCARD, ZONE_BANISHED, ZONE_DECK]
const RANDOM_KEYWORD_POOL := ["breakthrough", "charge", "drain", "guard", "lethal", "regenerate", "ward"]
const ZONE_PRIORITY := {
	ZONE_LANE: 0,
	"support": 1,
	ZONE_HAND: 2,
	ZONE_DISCARD: 3,
	ZONE_BANISHED: 4,
	ZONE_DECK: 5,
	ZONE_GENERATED: 6,
	"": 9,
}
const FAMILY_SPECS := {
	FAMILY_START_OF_TURN: {"event_type": EVENT_TURN_STARTED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_END_OF_TURN: {"event_type": EVENT_TURN_ENDING, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_PLAY: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_ACTIVATE: {"event_type": EVENT_SUPPORT_ACTIVATED, "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_SUMMON: {"event_type": EVENT_CREATURE_SUMMONED, "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_ON_DAMAGE: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "target"},
	FAMILY_ON_DEATH: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "subject"},
	FAMILY_LAST_GASP: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "subject"},
	FAMILY_SLAY: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "killer"},
	FAMILY_PILFER: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "source", "target_type": "player", "min_amount": 1},
	FAMILY_VETERAN: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "target", "damage_kind": "combat", "require_retaliation": true, "require_survived": true},
	FAMILY_EXPERTISE: {"event_type": EVENT_TURN_ENDING, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_PLOT: {"event_type": EVENT_TURN_ENDING, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_RUNE_BREAK: {"event_type": EVENT_RUNE_BROKEN, "window": WINDOW_INTERRUPT, "match_role": "controller"},
	FAMILY_ON_FRIENDLY_DEATH: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_ATTACK: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "source", "damage_kind": "combat", "exclude_retaliation": true, "exclude_battle": true},
	FAMILY_ON_EQUIP: {"event_type": EVENT_CARD_EQUIPPED, "window": WINDOW_AFTER, "match_role": "target"},
	FAMILY_AFTER_ACTION_PLAYED: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "controller", "required_played_card_type": "action"},
	FAMILY_ON_WARD_BROKEN: {"event_type": "ward_removed", "window": WINDOW_AFTER, "match_role": "target"},
	FAMILY_ON_FRIENDLY_SLAY: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "friendly_killer"},
	FAMILY_ON_MOVE: {"event_type": "card_moved", "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ITEM_DETACHED: {"event_type": "attached_item_detached", "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_ON_ENEMY_RUNE_DESTROYED: {"event_type": EVENT_RUNE_BROKEN, "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_ON_ENEMY_SHACKLED: {"event_type": "status_granted", "window": WINDOW_AFTER, "match_role": "opponent_target", "required_event_status_id": "shackled"},
	FAMILY_ON_PLAYER_HEALED: {"event_type": "player_healed", "window": WINDOW_AFTER, "match_role": "target_player_is_controller"},
	FAMILY_ON_MAX_MAGICKA_GAINED: {"event_type": "max_magicka_gained", "window": WINDOW_AFTER, "match_role": "target_player_is_controller"},
	FAMILY_ON_CREATURE_HEALED: {"event_type": "creature_healed", "window": WINDOW_AFTER, "match_role": "any_player"},
	FAMILY_ON_FRIENDLY_SUMMON: {"event_type": EVENT_CREATURE_SUMMONED, "window": WINDOW_AFTER, "match_role": "controller", "exclude_self": true},
	FAMILY_ON_COVER_GAINED: {"event_type": "status_granted", "window": WINDOW_AFTER, "match_role": "target", "required_event_status_id": "cover"},
	FAMILY_ON_CARD_DRAWN: {"event_type": EVENT_CARD_DRAWN, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_ENEMY_SUMMON: {"event_type": EVENT_CREATURE_SUMMONED, "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_ON_FRIENDLY_EQUIP: {"event_type": EVENT_CARD_EQUIPPED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_FRIENDLY_CARD_PLAYED: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_FRIENDLY_SUPPORT_PLAYED: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "controller", "required_played_card_type": "support"},
	FAMILY_ON_OPPONENT_TURN: {"event_type": EVENT_TURN_STARTED, "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_AFTER_CARD_PLAYED: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "any_player"},
	FAMILY_ON_OPPONENT_DAMAGED: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "target_player_is_opponent", "target_type": "player"},
	FAMILY_ON_KEYWORD_GAINED: {"event_type": "keyword_granted", "window": WINDOW_AFTER, "match_role": "target"},
	FAMILY_ON_FRIENDLY_POWER_GAIN: {"event_type": "stats_modified", "window": WINDOW_AFTER, "match_role": "controller", "require_positive_power_bonus": true},
	FAMILY_ON_CONSUMED: {"event_type": EVENT_CREATURE_CONSUMED, "window": WINDOW_AFTER, "match_role": "target"},
	FAMILY_ON_ENEMY_PROPHECY_DRAWN: {"event_type": EVENT_CARD_DRAWN, "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_ON_FRIENDLY_SACRIFICE: {"event_type": EVENT_CREATURE_SACRIFICED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_DEAL_DAMAGE_TO_CREATURE: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "source", "target_type": "creature"},
	FAMILY_ON_ENEMY_DAMAGED: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_ON_TARGETED_BY_ACTION: {"event_type": "action_targeted", "window": WINDOW_AFTER, "match_role": "target"},
	FAMILY_ON_RALLY: {"event_type": "rally_triggered", "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_SUPPORT_COUNT_REACHED: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "controller", "required_played_card_type": "support"},
	FAMILY_ON_OPPONENT_CARD_DRAWN: {"event_type": EVENT_CARD_DRAWN, "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_AFTER_FRIENDLY_ACTION_DAMAGES_ENEMY: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "controller", "damage_kind": "ability"},
	FAMILY_ON_FRIENDLY_PILFER_OR_DRAIN: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "controller", "target_type": "player", "min_amount": 1},
	FAMILY_ON_FRIENDLY_CREATURE_DEATH_COUNT: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_ON_ENEMY_STAT_REDUCTION: {"event_type": "stats_modified", "window": WINDOW_AFTER, "match_role": "opponent_player"},
	FAMILY_ON_FRIENDLY_DRAGON_DAMAGE: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_PLAYER_HEALTH_ZERO: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "target_player_is_controller", "target_type": "player"},
	FAMILY_WAX: {"event_type": EVENT_CREATURE_SUMMONED, "window": WINDOW_AFTER, "match_role": "source", "required_wax_wane_phase": "wax"},
	FAMILY_WANE: {"event_type": EVENT_CREATURE_SUMMONED, "window": WINDOW_AFTER, "match_role": "source", "required_wax_wane_phase": "wane"},
	FAMILY_ON_FRIENDLY_WAX: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "controller", "required_wax_wane_phase": "wax", "exclude_self": true},
	FAMILY_ON_FRIENDLY_WANE: {"event_type": EVENT_CARD_PLAYED, "window": WINDOW_AFTER, "match_role": "controller", "required_wax_wane_phase": "wane", "exclude_self": true},
	FAMILY_EXALT: {"event_type": EVENT_CREATURE_SUMMONED, "window": WINDOW_AFTER, "match_role": "source"},
	FAMILY_ON_RALLY_EMPTY_HAND: {"event_type": "rally_triggered", "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_GAIN_MAX_MAGICKA: {"event_type": "max_magicka_gained", "window": WINDOW_AFTER, "match_role": "target_player_is_controller"},
	FAMILY_TREASURE_HUNT: {"event_type": EVENT_CARD_DRAWN, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_FRIENDLY_TREASURE_FOUND: {"event_type": "treasure_found", "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_INVADE: {"event_type": "invade_triggered", "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_MAX_MAGICKA_GAIN_2: {"event_type": "max_magicka_gained", "window": WINDOW_AFTER, "match_role": "target_player_is_controller"},
	FAMILY_ON_DISCARD_LEAVE: {"event_type": "card_moved", "window": WINDOW_AFTER, "match_role": "subject"},
	FAMILY_ON_MAGICKA_THRESHOLD: {"event_type": "max_magicka_gained", "window": WINDOW_AFTER, "match_role": "target_player_is_controller"},
}


static func ensure_match_state(match_state: Dictionary) -> void:
	ExtendedMechanicPacks.ensure_match_state(match_state)
	if not match_state.has("pending_event_queue") or typeof(match_state["pending_event_queue"]) != TYPE_ARRAY:
		match_state["pending_event_queue"] = []
	if not match_state.has("replay_log") or typeof(match_state["replay_log"]) != TYPE_ARRAY:
		match_state["replay_log"] = []
	if not match_state.has("event_log") or typeof(match_state["event_log"]) != TYPE_ARRAY:
		match_state["event_log"] = []
	if not match_state.has("trigger_registry") or typeof(match_state["trigger_registry"]) != TYPE_ARRAY:
		match_state["trigger_registry"] = []
	if not match_state.has("last_timing_result") or typeof(match_state["last_timing_result"]) != TYPE_DICTIONARY:
		match_state["last_timing_result"] = {"processed_events": [], "trigger_resolutions": []}
	if not match_state.has("resolved_once_triggers") or typeof(match_state["resolved_once_triggers"]) != TYPE_DICTIONARY:
		match_state["resolved_once_triggers"] = {}
	if not match_state.has("next_event_sequence"):
		match_state["next_event_sequence"] = 0
	if not match_state.has("next_trigger_resolution_sequence"):
		match_state["next_trigger_resolution_sequence"] = 0
	if not match_state.has("pending_prophecy_windows") or typeof(match_state["pending_prophecy_windows"]) != TYPE_ARRAY:
		match_state["pending_prophecy_windows"] = []
	if not match_state.has("pending_discard_choices") or typeof(match_state["pending_discard_choices"]) != TYPE_ARRAY:
		match_state["pending_discard_choices"] = []
	if not match_state.has("pending_hand_selections") or typeof(match_state["pending_hand_selections"]) != TYPE_ARRAY:
		match_state["pending_hand_selections"] = []
	if not match_state.has("pending_top_deck_choices") or typeof(match_state["pending_top_deck_choices"]) != TYPE_ARRAY:
		match_state["pending_top_deck_choices"] = []
	if not match_state.has("pending_player_choices") or typeof(match_state["pending_player_choices"]) != TYPE_ARRAY:
		match_state["pending_player_choices"] = []
	if not match_state.has("pending_rune_break_queue") or typeof(match_state["pending_rune_break_queue"]) != TYPE_ARRAY:
		match_state["pending_rune_break_queue"] = []
	if not match_state.has("pending_summon_effect_targets") or typeof(match_state["pending_summon_effect_targets"]) != TYPE_ARRAY:
		match_state["pending_summon_effect_targets"] = []
	if not match_state.has("pending_turn_trigger_targets") or typeof(match_state["pending_turn_trigger_targets"]) != TYPE_ARRAY:
		match_state["pending_turn_trigger_targets"] = []
	if not match_state.has("pending_consume_selections") or typeof(match_state["pending_consume_selections"]) != TYPE_ARRAY:
		match_state["pending_consume_selections"] = []
	if not match_state.has("pending_deck_selections") or typeof(match_state["pending_deck_selections"]) != TYPE_ARRAY:
		match_state["pending_deck_selections"] = []
	if not match_state.has("pending_forced_plays") or typeof(match_state["pending_forced_plays"]) != TYPE_ARRAY:
		match_state["pending_forced_plays"] = []
	if not match_state.has("pending_budget_summons") or typeof(match_state["pending_budget_summons"]) != TYPE_ARRAY:
		match_state["pending_budget_summons"] = []
	if not match_state.has("out_of_cards_sequence"):
		match_state["out_of_cards_sequence"] = 0


static func get_supported_trigger_families() -> Array:
	return [
		FAMILY_START_OF_TURN,
		FAMILY_END_OF_TURN,
		FAMILY_ON_PLAY,
		FAMILY_ACTIVATE,
		FAMILY_SUMMON,
		FAMILY_ON_DAMAGE,
		FAMILY_ON_DEATH,
		FAMILY_LAST_GASP,
		FAMILY_SLAY,
		FAMILY_PILFER,
		FAMILY_VETERAN,
		FAMILY_EXPERTISE,
		FAMILY_PLOT,
		FAMILY_RUNE_BREAK,
		FAMILY_ON_FRIENDLY_DEATH,
		FAMILY_ON_ATTACK,
		FAMILY_ON_EQUIP,
		FAMILY_AFTER_ACTION_PLAYED,
		FAMILY_ON_WARD_BROKEN,
		FAMILY_ON_FRIENDLY_SLAY,
		FAMILY_ON_MOVE,
		FAMILY_ITEM_DETACHED,
		FAMILY_ON_ENEMY_RUNE_DESTROYED,
		FAMILY_ON_ENEMY_SHACKLED,
		FAMILY_ON_PLAYER_HEALED,
		FAMILY_ON_MAX_MAGICKA_GAINED,
		FAMILY_ON_FRIENDLY_SUMMON,
		FAMILY_ON_CARD_DRAWN,
		FAMILY_ON_ENEMY_SUMMON,
		FAMILY_ON_FRIENDLY_EQUIP,
		FAMILY_ON_FRIENDLY_CARD_PLAYED,
		FAMILY_ON_FRIENDLY_SUPPORT_PLAYED,
		FAMILY_ON_OPPONENT_TURN,
		FAMILY_AFTER_CARD_PLAYED,
		FAMILY_ON_OPPONENT_DAMAGED,
		FAMILY_ON_KEYWORD_GAINED,
		FAMILY_ON_FRIENDLY_POWER_GAIN,
		FAMILY_ON_CONSUMED,
		FAMILY_ON_ENEMY_PROPHECY_DRAWN,
		FAMILY_ON_FRIENDLY_SACRIFICE,
		FAMILY_ON_DEAL_DAMAGE_TO_CREATURE,
		FAMILY_ON_ENEMY_DAMAGED,
		FAMILY_ON_TARGETED_BY_ACTION,
		FAMILY_ON_RALLY,
		FAMILY_ON_SUPPORT_COUNT_REACHED,
		FAMILY_ON_OPPONENT_CARD_DRAWN,
		FAMILY_AFTER_FRIENDLY_ACTION_DAMAGES_ENEMY,
		FAMILY_ON_FRIENDLY_PILFER_OR_DRAIN,
		FAMILY_ON_FRIENDLY_CREATURE_DEATH_COUNT,
		FAMILY_ON_ENEMY_STAT_REDUCTION,
		FAMILY_ON_FRIENDLY_DRAGON_DAMAGE,
		FAMILY_ON_PLAYER_HEALTH_ZERO,
		FAMILY_WAX,
		FAMILY_WANE,
		FAMILY_ON_FRIENDLY_WAX,
		FAMILY_ON_FRIENDLY_WANE,
		FAMILY_EXALT,
		FAMILY_ON_RALLY_EMPTY_HAND,
		FAMILY_ON_GAIN_MAX_MAGICKA,
		FAMILY_TREASURE_HUNT,
		FAMILY_ON_FRIENDLY_TREASURE_FOUND,
		FAMILY_ON_INVADE,
		FAMILY_ON_MAX_MAGICKA_GAIN_2,
		FAMILY_ON_DISCARD_LEAVE,
		FAMILY_ON_MAGICKA_THRESHOLD,
	]


# --- Target choice mechanic ---


static func resolve_targeted_effect(match_state: Dictionary, source_instance_id: String, target_info: Dictionary, options: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var source_card := MatchTimingHelpers._find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return {"is_valid": false, "errors": ["Source card not found."], "events": [], "trigger_resolutions": []}
	# Multi-target collection: if the card is collecting targets for a multi-target ability
	if source_card.has("_multi_target_count"):
		return _resolve_multi_target_selection(match_state, source_card, target_info)
	var abilities := MatchTargeting.get_target_mode_abilities(source_card)
	# Filter by allowed families if specified (prevents matching pilfer/expertise
	# abilities when resolving summon targets on cards with multiple target_mode abilities)
	var allowed_families: Array = options.get("allowed_families", [])
	if typeof(allowed_families) == TYPE_ARRAY and not allowed_families.is_empty():
		var filtered_abilities: Array = []
		for ab in abilities:
			if allowed_families.has(str(ab.get("family", ""))):
				filtered_abilities.append(ab)
		abilities = filtered_abilities
	if abilities.is_empty():
		return {"is_valid": false, "errors": ["No target_mode abilities on card."], "events": [], "trigger_resolutions": []}
	# Determine which ability matches the chosen target
	var chosen_instance_id := str(target_info.get("target_instance_id", ""))
	var chosen_player_id := str(target_info.get("target_player_id", ""))
	var is_secondary := source_card.has("_primary_target_id")
	var matching_ability: Dictionary = {}
	if not chosen_instance_id.is_empty():
		for ability in abilities:
			var mode := str(ability.get("secondary_target_mode", "")) if is_secondary else str(ability.get("target_mode", ""))
			if mode.is_empty():
				continue
			var valid := MatchTargeting.get_valid_targets_for_mode(match_state, source_instance_id, mode, ability)
			for v in valid:
				if str(v.get("instance_id", "")) == chosen_instance_id:
					matching_ability = ability
					break
			if not matching_ability.is_empty():
				break
	elif not chosen_player_id.is_empty():
		for ability in abilities:
			var mode := str(ability.get("secondary_target_mode", "")) if is_secondary else str(ability.get("target_mode", ""))
			if mode.is_empty():
				continue
			var valid := MatchTargeting.get_valid_targets_for_mode(match_state, source_instance_id, mode, ability)
			for v in valid:
				if str(v.get("player_id", "")) == chosen_player_id:
					matching_ability = ability
					break
			if not matching_ability.is_empty():
				break
	if matching_ability.is_empty():
		return {"is_valid": false, "errors": ["No matching ability for chosen target."], "events": [], "trigger_resolutions": []}
	# Secondary target mode: if the ability has a secondary_target_mode and we haven't
	# selected the secondary yet, save the primary target, fire the primary effect
	# immediately, and create a pending secondary selection.
	var secondary_tm := str(matching_ability.get("secondary_target_mode", ""))
	if not secondary_tm.is_empty() and not source_card.has("_primary_target_id"):
		source_card["_primary_target_id"] = chosen_instance_id
		var sec_controller := str(source_card.get("controller_player_id", ""))
		# Fire the primary effect immediately
		var primary_events: Array = []
		var primary_resolutions: Array = []
		var effects: Array = matching_ability.get("effects", [])
		if effects.size() > 1:
			var primary_effect: Dictionary = effects[0].duplicate(true) if typeof(effects[0]) == TYPE_DICTIONARY else {}
			var src_loc := MatchMutations.find_card_location(match_state, source_instance_id)
			var primary_trigger := {
				"trigger_id": "%s_primary_target" % source_instance_id,
				"trigger_index": 0,
				"source_instance_id": source_instance_id,
				"owner_player_id": str(source_card.get("owner_player_id", sec_controller)),
				"controller_player_id": sec_controller,
				"source_zone": str(src_loc.get("zone", ZONE_DISCARD)),
				"descriptor": {"family": str(matching_ability.get("family", "on_play")), "effects": [primary_effect]},
				"_primary_target_id": chosen_instance_id,
				"_chosen_target_id": chosen_instance_id,
			}
			var primary_event := {
				"event_type": EVENT_CARD_PLAYED,
				"source_instance_id": source_instance_id,
				"player_id": sec_controller,
				"target_instance_id": chosen_instance_id,
			}
			var resolution := MatchTriggers._build_trigger_resolution(match_state, primary_trigger, primary_event)
			primary_events = MatchEffectApplication._apply_effects(match_state, primary_trigger, primary_event, resolution)
			primary_resolutions.append(resolution)
		var sec_valid := MatchTargeting.get_valid_targets_for_mode(match_state, source_instance_id, secondary_tm, matching_ability)
		if sec_valid.is_empty():
			source_card.erase("_primary_target_id")
			return {"is_valid": true, "events": primary_events, "trigger_resolutions": primary_resolutions}
		var pending_arr: Array = match_state.get("pending_summon_effect_targets", [])
		pending_arr.append({
			"player_id": sec_controller,
			"source_instance_id": source_instance_id,
			"mandatory": false,
			"secondary_target_mode": secondary_tm,
		})
		return {"is_valid": true, "events": primary_events, "trigger_resolutions": primary_resolutions}
	# Build trigger entry with chosen target injected
	var source_location := MatchMutations.find_card_location(match_state, source_instance_id)
	var lane_index := int(source_location.get("lane_index", -1))
	var slot_index := int(source_location.get("slot_index", -1))
	var controller_id := str(source_card.get("controller_player_id", ""))
	var trigger := {
		"trigger_id": "%s_target_choice" % source_instance_id,
		"trigger_index": 0,
		"source_instance_id": source_instance_id,
		"owner_player_id": str(source_card.get("owner_player_id", controller_id)),
		"controller_player_id": controller_id,
		"source_zone": ZONE_LANE,
		"lane_index": lane_index,
		"slot_index": slot_index,
		"descriptor": matching_ability.duplicate(true),
		"_chosen_target_id": chosen_instance_id if not chosen_instance_id.is_empty() else "",
		"_chosen_target_player_id": chosen_player_id if not chosen_player_id.is_empty() else "",
	}
	# Inject primary target if this is a secondary target resolution —
	# for multi-effect abilities, trim to secondary effects only (primary was fired on first pick);
	# for single-effect abilities, keep all effects (primary was skipped on first pick)
	var primary_id = source_card.get("_primary_target_id", "")
	if typeof(primary_id) == TYPE_STRING and not primary_id.is_empty():
		trigger["_primary_target_id"] = primary_id
		source_card.erase("_primary_target_id")
		var all_effects: Array = matching_ability.get("effects", [])
		if all_effects.size() > 1:
			var secondary_effects: Array = []
			for ei in range(1, all_effects.size()):
				secondary_effects.append(all_effects[ei])
			var trimmed_descriptor: Dictionary = matching_ability.duplicate(true)
			trimmed_descriptor["effects"] = secondary_effects
			trigger["descriptor"] = trimmed_descriptor
	# Inject consumed card info if available (from prior consume selection)
	var consumed_info = source_card.get("_consumed_card_info", {})
	if typeof(consumed_info) == TYPE_DICTIONARY and not consumed_info.is_empty():
		trigger["_consumed_card_info"] = consumed_info
	# Build synthetic event
	var lanes: Array = match_state.get("lanes", [])
	var lane_id := ""
	if lane_index >= 0 and lane_index < lanes.size():
		lane_id = str(lanes[lane_index].get("lane_id", ""))
	var event := {
		"event_type": EVENT_CREATURE_SUMMONED,
		"source_instance_id": source_instance_id,
		"player_id": controller_id,
		"lane_id": lane_id,
		"lane_index": lane_index,
		"target_instance_id": chosen_instance_id,
		"target_player_id": chosen_player_id,
	}
	# Build resolution record
	var resolution := MatchTriggers._build_trigger_resolution(match_state, trigger, event)
	GameLogger.log_trigger_resolution(match_state, resolution, trigger)
	# Apply effects
	var generated_events := MatchEffectApplication._apply_effects(match_state, trigger, event, resolution)
	# Publish any generated events (cascading effects)
	var timing_result := publish_events(match_state, generated_events, {
		"parent_event_id": "targeted_effect_%s" % source_instance_id,
	})
	var all_events: Array = generated_events + timing_result.get("processed_events", [])
	var all_resolutions: Array = [resolution] + timing_result.get("trigger_resolutions", [])
	return {"is_valid": true, "events": all_events, "trigger_resolutions": all_resolutions}


# --- Target choice helpers ---


static func has_pending_prophecy(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_prophecies(match_state, player_id).is_empty()


static func get_pending_prophecies(match_state: Dictionary, player_id: String = "") -> Array:
	ensure_match_state(match_state)
	var matches: Array = []
	for raw_window in match_state.get("pending_prophecy_windows", []):
		if typeof(raw_window) != TYPE_DICTIONARY:
			continue
		var window: Dictionary = raw_window
		if not player_id.is_empty() and str(window.get("player_id", "")) != player_id:
			continue
		matches.append(window.duplicate(true))
	return matches


static func has_pending_discard_choice(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_discard_choice(match_state, player_id).is_empty()


static func get_pending_discard_choice(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw_choice in match_state.get("pending_discard_choices", []):
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw_choice.get("player_id", "")) != player_id:
			continue
		return raw_choice.duplicate(true)
	return {}


static func resolve_pending_discard_choice(match_state: Dictionary, player_id: String, chosen_instance_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var choices: Array = match_state.get("pending_discard_choices", [])
	var choice_index := -1
	var choice := {}
	for i in range(choices.size()):
		if typeof(choices[i]) == TYPE_DICTIONARY and str(choices[i].get("player_id", "")) == player_id:
			choice_index = i
			choice = choices[i]
			break
	if choice_index == -1:
		return {"is_valid": false, "errors": ["No pending discard choice for player %s." % player_id]}
	var candidate_ids: Array = choice.get("candidate_instance_ids", [])
	if not candidate_ids.has(chosen_instance_id):
		return {"is_valid": false, "errors": ["Card %s is not a valid candidate." % chosen_instance_id]}
	var discard_player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if discard_player.is_empty():
		choices.remove_at(choice_index)
		return {"is_valid": false, "errors": ["Unknown player_id: %s" % player_id]}
	var discard_pile: Array = discard_player.get(ZONE_DISCARD, [])
	var pick_index := -1
	for d_index in range(discard_pile.size()):
		var d_card = discard_pile[d_index]
		if typeof(d_card) == TYPE_DICTIONARY and str(d_card.get("instance_id", "")) == chosen_instance_id:
			pick_index = d_index
			break
	if pick_index == -1:
		choices.remove_at(choice_index)
		return {"is_valid": false, "errors": ["Card %s not found in discard pile." % chosen_instance_id]}
	var picked_card: Dictionary = discard_pile[pick_index]
	discard_pile.remove_at(pick_index)
	var generated_events: Array = []
	if _overflow_card_to_discard(discard_player, picked_card, player_id, ZONE_DISCARD, generated_events):
		choices.remove_at(choice_index)
		return {"is_valid": true, "errors": [], "events": generated_events}
	MatchMutations.restore_definition_state(picked_card)
	var then_op := str(choice.get("then_op", ""))
	if then_op == "summon_from_discard" or then_op == "discard_and_summon_from_discard":
		# Summon to source's lane, falling back to other lanes if full
		var sfd_source_id := str(choice.get("source_instance_id", ""))
		var sfd_source_loc := MatchMutations.find_card_location(match_state, sfd_source_id)
		var sfd_lane_id := str(sfd_source_loc.get("lane_id", ""))
		if sfd_lane_id.is_empty():
			sfd_lane_id = "field"
		var sfd_summon := MatchMutations.summon_card_to_lane(match_state, player_id, picked_card, sfd_lane_id, {"source_zone": ZONE_DISCARD})
		if not bool(sfd_summon.get("is_valid", false)):
			for sfd_lane in match_state.get("lanes", []):
				var sfd_alt := str(sfd_lane.get("lane_id", ""))
				if sfd_alt != sfd_lane_id and not sfd_alt.is_empty():
					sfd_summon = MatchMutations.summon_card_to_lane(match_state, player_id, picked_card, sfd_alt, {"source_zone": ZONE_DISCARD})
					if bool(sfd_summon.get("is_valid", false)):
						sfd_lane_id = sfd_alt
						break
		if bool(sfd_summon.get("is_valid", false)):
			generated_events.append_array(sfd_summon.get("events", []))
			generated_events.append(MatchSummonTiming._build_summon_event(sfd_summon["card"], player_id, sfd_lane_id, int(sfd_summon.get("slot_index", -1)), "summon_from_discard"))
			_check_summon_abilities(match_state, sfd_summon["card"])
		choices.remove_at(choice_index)
		var timing_result := publish_events(match_state, generated_events)
		return {
			"is_valid": true,
			"errors": [],
			"card": picked_card,
			"events": timing_result.get("processed_events", []),
			"trigger_resolutions": timing_result.get("trigger_resolutions", []),
		}
	picked_card["zone"] = ZONE_HAND
	discard_player[ZONE_HAND].append(picked_card)
	var buff_power := int(choice.get("buff_power", 0))
	var buff_health := int(choice.get("buff_health", 0))
	if buff_power != 0 or buff_health != 0:
		picked_card["power_bonus"] = int(picked_card.get("power_bonus", 0)) + buff_power
		picked_card["health_bonus"] = int(picked_card.get("health_bonus", 0)) + buff_health
	generated_events.append({
		"event_type": "card_drawn",
		"player_id": player_id,
		"source_instance_id": str(choice.get("source_instance_id", "")),
		"drawn_instance_id": chosen_instance_id,
		"source_zone": ZONE_DISCARD,
		"target_zone": ZONE_HAND,
		"reason": str(choice.get("reason", "discard_choice")),
	})
	if bool(choice.get("draw_all_matching_name", false)):
		var damn_name := str(picked_card.get("name", ""))
		var damn_matches: Array = []
		for damn_i in range(discard_pile.size() - 1, -1, -1):
			var damn_card = discard_pile[damn_i]
			if typeof(damn_card) == TYPE_DICTIONARY and str(damn_card.get("name", "")) == damn_name:
				damn_matches.append(damn_i)
		for damn_idx in damn_matches:
			var damn_extra: Dictionary = discard_pile[damn_idx]
			discard_pile.remove_at(damn_idx)
			MatchMutations.restore_definition_state(damn_extra)
			damn_extra["zone"] = ZONE_HAND
			discard_player[ZONE_HAND].append(damn_extra)
			generated_events.append({
				"event_type": "card_drawn",
				"player_id": player_id,
				"source_instance_id": str(choice.get("source_instance_id", "")),
				"drawn_instance_id": str(damn_extra.get("instance_id", "")),
				"source_zone": ZONE_DISCARD,
				"target_zone": ZONE_HAND,
				"reason": str(choice.get("reason", "discard_choice")),
			})
	choices.remove_at(choice_index)
	var timing_result := publish_events(match_state, generated_events)
	return {
		"is_valid": true,
		"errors": [],
		"card": picked_card,
		"events": timing_result.get("processed_events", []),
		"trigger_resolutions": timing_result.get("trigger_resolutions", []),
	}


static func decline_pending_discard_choice(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var choices: Array = match_state.get("pending_discard_choices", [])
	for i in range(choices.size()):
		if typeof(choices[i]) == TYPE_DICTIONARY and str(choices[i].get("player_id", "")) == player_id:
			choices.remove_at(i)
			return {"is_valid": true, "errors": []}
	return {"is_valid": false, "errors": ["No pending discard choice for player %s." % player_id]}


# --- Pending hand selection mechanic ---


static func has_pending_hand_selection(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_hand_selection(match_state, player_id).is_empty()


static func get_pending_hand_selection(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw_selection in match_state.get("pending_hand_selections", []):
		if typeof(raw_selection) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw_selection.get("player_id", "")) != player_id:
			continue
		return raw_selection.duplicate(true)
	return {}


static func resolve_pending_hand_selection(match_state: Dictionary, player_id: String, chosen_instance_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var selections: Array = match_state.get("pending_hand_selections", [])
	var selection_index := -1
	var selection := {}
	for i in range(selections.size()):
		if typeof(selections[i]) == TYPE_DICTIONARY and str(selections[i].get("player_id", "")) == player_id:
			selection_index = i
			selection = selections[i]
			break
	if selection_index == -1:
		return {"is_valid": false, "errors": ["No pending hand selection for player %s." % player_id]}
	var candidate_ids: Array = selection.get("candidate_instance_ids", [])
	if not candidate_ids.has(chosen_instance_id):
		return {"is_valid": false, "errors": ["Card %s is not a valid candidate." % chosen_instance_id]}
	var hand_player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if hand_player.is_empty():
		selections.remove_at(selection_index)
		return {"is_valid": false, "errors": ["Unknown player_id: %s" % player_id]}
	var chosen_card := {}
	for card in hand_player.get(ZONE_HAND, []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == chosen_instance_id:
			chosen_card = card
			break
	if chosen_card.is_empty():
		selections.remove_at(selection_index)
		return {"is_valid": false, "errors": ["Card %s not found in hand." % chosen_instance_id]}
	var then_op := str(selection.get("then_op", ""))
	var then_context: Dictionary = selection.get("then_context", {})
	var source_instance_id := str(selection.get("source_instance_id", ""))
	selections.remove_at(selection_index)
	var generated_events: Array = ExtendedMechanicPacks.apply_hand_selection_effect(match_state, player_id, source_instance_id, chosen_card, then_op, then_context)
	var timing_result := publish_events(match_state, generated_events)
	return {
		"is_valid": true,
		"errors": [],
		"card": chosen_card,
		"events": timing_result.get("processed_events", []),
		"trigger_resolutions": timing_result.get("trigger_resolutions", []),
	}


static func decline_pending_hand_selection(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var selections: Array = match_state.get("pending_hand_selections", [])
	for i in range(selections.size()):
		if typeof(selections[i]) == TYPE_DICTIONARY and str(selections[i].get("player_id", "")) == player_id:
			selections.remove_at(i)
			return {"is_valid": true, "errors": []}
	return {"is_valid": false, "errors": ["No pending hand selection for player %s." % player_id]}


static func has_pending_top_deck_choice(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_top_deck_choice(match_state, player_id).is_empty()


static func get_pending_top_deck_choice(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw_choice in match_state.get("pending_top_deck_choices", []):
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw_choice.get("player_id", "")) != player_id:
			continue
		return raw_choice.duplicate(true)
	return {}


static func resolve_pending_top_deck_choice(match_state: Dictionary, player_id: String, discard: bool) -> Dictionary:
	ensure_match_state(match_state)
	var choices: Array = match_state.get("pending_top_deck_choices", [])
	var choice_index := -1
	for i in range(choices.size()):
		if typeof(choices[i]) == TYPE_DICTIONARY and str(choices[i].get("player_id", "")) == player_id:
			choice_index = i
			break
	if choice_index == -1:
		return {"is_valid": false, "errors": ["No pending top deck choice for player %s." % player_id]}
	var choice: Dictionary = choices[choice_index]
	choices.remove_at(choice_index)
	var events: Array = []
	if discard:
		var top_deck_player := MatchTimingHelpers._get_player_state(match_state, player_id)
		if not top_deck_player.is_empty():
			var deck: Array = top_deck_player.get(ZONE_DECK, [])
			if not deck.is_empty():
				var top_card: Dictionary = deck.pop_back()
				top_card["zone"] = ZONE_DISCARD
				var discard_pile: Array = top_deck_player.get(ZONE_DISCARD, [])
				discard_pile.append(top_card)
				events.append({
					"event_type": "card_discarded",
					"player_id": player_id,
					"source_instance_id": str(choice.get("source_instance_id", "")),
					"discarded_instance_id": str(top_card.get("instance_id", "")),
					"source_zone": ZONE_DECK,
					"reason": "top_deck_choice",
				})
	var timing_result := publish_events(match_state, events)
	return {
		"is_valid": true,
		"errors": [],
		"discarded": discard,
		"events": timing_result.get("processed_events", []),
	}


static func resolve_pending_top_deck_multi_choice(match_state: Dictionary, player_id: String, chosen_index: int) -> Dictionary:
	ensure_match_state(match_state)
	var choices: Array = match_state.get("pending_top_deck_choices", [])
	var choice_idx := -1
	var choice := {}
	for i in range(choices.size()):
		if typeof(choices[i]) == TYPE_DICTIONARY and str(choices[i].get("player_id", "")) == player_id:
			choice_idx = i
			choice = choices[i]
			break
	if choice_idx == -1:
		return {"is_valid": false, "errors": ["No pending top deck choice for player %s." % player_id]}
	var cards: Array = choice.get("cards", [])
	if chosen_index < 0 or chosen_index >= cards.size():
		return {"is_valid": false, "errors": ["Invalid choice index: %d" % chosen_index]}
	choices.remove_at(choice_idx)
	var mode := str(choice.get("mode", ""))
	var events: Array = []
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return {"is_valid": false, "errors": ["Player not found."]}
	var chosen_card: Dictionary = cards[chosen_index]
	if mode == "keep_one_discard_rest":
		# Chosen card goes to hand, rest go to discard
		chosen_card["zone"] = ZONE_HAND
		player.get(ZONE_HAND, []).append(chosen_card)
		events.append({"event_type": EVENT_CARD_DRAWN, "player_id": player_id, "source_instance_id": str(chosen_card.get("instance_id", ""))})
		for i in range(cards.size()):
			if i == chosen_index:
				continue
			var discard_card: Dictionary = cards[i]
			discard_card["zone"] = ZONE_DISCARD
			player.get(ZONE_DISCARD, []).push_front(discard_card)
			events.append({"event_type": "card_discarded", "player_id": player_id, "discarded_instance_id": str(discard_card.get("instance_id", "")), "reason": "top_deck_multi_choice"})
	elif mode == "give_one_draw_rest":
		# Chosen card goes to opponent's hand, rest go to controller's hand
		var opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), player_id)
		var opponent := MatchTimingHelpers._get_player_state(match_state, opponent_id)
		if not opponent.is_empty():
			chosen_card["zone"] = ZONE_HAND
			chosen_card["controller_player_id"] = opponent_id
			chosen_card["owner_player_id"] = opponent_id
			opponent.get(ZONE_HAND, []).append(chosen_card)
			events.append({"event_type": "card_given_to_opponent", "player_id": player_id, "target_player_id": opponent_id, "card_instance_id": str(chosen_card.get("instance_id", ""))})
		for i in range(cards.size()):
			if i == chosen_index:
				continue
			var draw_card: Dictionary = cards[i]
			draw_card["zone"] = ZONE_HAND
			player.get(ZONE_HAND, []).append(draw_card)
			events.append({"event_type": EVENT_CARD_DRAWN, "player_id": player_id, "source_instance_id": str(draw_card.get("instance_id", ""))})
	elif mode == "draw_one_shuffle_rest":
		# Prophet's Sight: chosen card goes to hand, others shuffle back into deck
		chosen_card["zone"] = ZONE_HAND
		player.get(ZONE_HAND, []).append(chosen_card)
		events.append({"event_type": EVENT_CARD_DRAWN, "player_id": player_id, "source_instance_id": str(chosen_card.get("instance_id", "")), "reason": "prophets_sight", "allow_prophecy_interrupt": true})
		if _can_open_prophecy_window(match_state, player_id, chosen_card):
			events.append(_open_prophecy_window(match_state, player_id, chosen_card, {"source_instance_id": "boon_prophets_sight"}))
		var dors_deck: Array = player.get(ZONE_DECK, [])
		for i in range(cards.size()):
			if i == chosen_index:
				continue
			var back_card: Dictionary = cards[i]
			back_card["zone"] = ZONE_DECK
			var insert_ctx := "dors_shuffle_" + str(i) + "_" + str(chosen_card.get("instance_id", ""))
			var insert_pos := MatchEffectParams._deterministic_index(match_state, insert_ctx, dors_deck.size() + 1)
			dors_deck.insert(insert_pos, back_card)
		# Resume any remaining rune breaks in the queue
		var dors_resume := _resume_pending_rune_breaks(match_state)
		events.append_array(dors_resume.get("events", []))
	var timing_result := publish_events(match_state, events)
	return {"is_valid": true, "errors": [], "events": timing_result.get("processed_events", []), "chosen_card": chosen_card}


static func has_pending_player_choice(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_player_choice(match_state, player_id).is_empty()


static func get_pending_player_choice(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw_choice in match_state.get("pending_player_choices", []):
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw_choice.get("player_id", "")) != player_id:
			continue
		return raw_choice.duplicate(true)
	return {}


static func resolve_pending_player_choice(match_state: Dictionary, player_id: String, chosen_index: int) -> Dictionary:
	ensure_match_state(match_state)
	var choices: Array = match_state.get("pending_player_choices", [])
	var choice_idx := -1
	var choice := {}
	for i in range(choices.size()):
		if typeof(choices[i]) == TYPE_DICTIONARY and str(choices[i].get("player_id", "")) == player_id:
			choice_idx = i
			choice = choices[i]
			break
	if choice_idx == -1:
		return {"is_valid": false, "errors": ["No pending player choice for %s." % player_id]}
	# then_op path: choices that store an operation to execute with the chosen option value
	var then_op := str(choice.get("then_op", ""))
	if not then_op.is_empty():
		var options: Array = choice.get("options", [])
		if chosen_index < 0 or chosen_index >= options.size():
			return {"is_valid": false, "errors": ["Invalid choice index: %d" % chosen_index]}
		choices.remove_at(choice_idx)
		var chosen_value: String = str(options[chosen_index])
		var then_context: Dictionary = choice.get("then_context", {})
		var source_instance_id := str(choice.get("source_instance_id", ""))
		var events: Array = _resolve_then_op(match_state, player_id, source_instance_id, then_op, chosen_value, then_context)
		var timing_result := publish_events(match_state, events)
		return {
			"is_valid": true,
			"errors": [],
			"chosen_index": chosen_index,
			"events": timing_result.get("processed_events", []),
		}
	# effects_per_option path: choices with pre-built effect arrays per option
	var effects_per_option: Array = choice.get("effects_per_option", [])
	if chosen_index < 0 or chosen_index >= effects_per_option.size():
		return {"is_valid": false, "errors": ["Invalid choice index: %d" % chosen_index]}
	choices.remove_at(choice_idx)
	var trigger: Dictionary = choice.get("trigger", {})
	var event: Dictionary = choice.get("event", {})
	var chosen_effects: Array = effects_per_option[chosen_index]
	trigger["_chosen_option_index"] = chosen_index
	var events: Array = []
	# Inject chosen effects into the trigger descriptor so _apply_effects can find them
	var patched_trigger := trigger.duplicate(true)
	var patched_descriptor: Dictionary = patched_trigger.get("descriptor", {})
	patched_descriptor["effects"] = chosen_effects
	patched_trigger["descriptor"] = patched_descriptor
	events.append_array(MatchEffectApplication._apply_effects(match_state, patched_trigger, event, {}))
	# choose_two: re-queue a second choice with the chosen option removed
	var remaining := int(choice.get("_choose_two_remaining", 0))
	if remaining > 0:
		var new_options: Array = choice.get("options", []).duplicate(true)
		var new_effects: Array = effects_per_option.duplicate(true)
		if chosen_index < new_options.size():
			new_options.remove_at(chosen_index)
		if chosen_index < new_effects.size():
			new_effects.remove_at(chosen_index)
		if new_options.size() > 0 and new_effects.size() > 0:
			choices.append({
				"player_id": player_id,
				"source_instance_id": str(choice.get("source_instance_id", "")),
				"prompt": "Choose the second ability.",
				"options": new_options,
				"effects_per_option": new_effects,
				"trigger": trigger.duplicate(true),
				"event": event.duplicate(true),
				"_choose_two_remaining": remaining - 1,
			})
	var timing_result := publish_events(match_state, events)
	return {
		"is_valid": true,
		"errors": [],
		"chosen_index": chosen_index,
		"events": timing_result.get("processed_events", []),
	}


static func _resolve_then_op(match_state: Dictionary, player_id: String, source_instance_id: String, then_op: String, chosen_value: String, then_context: Dictionary) -> Array:
	var events: Array = []
	match then_op:
		"set_cost_lock":
			# Store the locked cost on the opponent's player state
			var opponent := {}
			for p in match_state.get("players", []):
				if typeof(p) == TYPE_DICTIONARY and str(p.get("player_id", "")) != player_id:
					opponent = p
					break
			if not opponent.is_empty():
				var locks: Array = opponent.get("cost_locks", [])
				locks.append({"cost": int(chosen_value), "source_instance_id": source_instance_id})
				opponent["cost_locks"] = locks
				events.append({"event_type": "cost_lock_applied", "player_id": player_id, "target_player_id": str(opponent.get("player_id", "")), "locked_cost": int(chosen_value), "source_instance_id": source_instance_id})
		"set_cost_trigger":
			# Store a cost-triggered effect on the source card
			var source_card := MatchTimingHelpers._find_card_anywhere(match_state, source_instance_id)
			if not source_card.is_empty():
				var cost_triggers: Array = source_card.get("cost_triggers", [])
				cost_triggers.append({"cost": int(chosen_value), "effects": then_context})
				source_card["cost_triggers"] = cost_triggers
				events.append({"event_type": "cost_trigger_set", "source_instance_id": source_instance_id, "chosen_cost": int(chosen_value)})
		"apply_subtype_aura":
			# Apply the subtype aura to the source card with the chosen subtype as filter
			var source_card := MatchTimingHelpers._find_card_anywhere(match_state, source_instance_id)
			if not source_card.is_empty():
				var aura_template: Dictionary = then_context.duplicate(true)
				aura_template["filter_subtype"] = chosen_value
				var existing_auras = source_card.get("aura", {})
				if typeof(existing_auras) == TYPE_DICTIONARY:
					# Merge subtype filter into existing aura
					existing_auras["filter_subtype"] = chosen_value
				else:
					source_card["aura"] = aura_template
				events.append({"event_type": "subtype_aura_applied", "source_instance_id": source_instance_id, "chosen_subtype": chosen_value})
	return events


static func has_pending_secondary_target(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_secondary_target(match_state, player_id).is_empty()


static func get_pending_secondary_target(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw in match_state.get("pending_secondary_targets", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw.get("player_id", "")) != player_id:
			continue
		return raw.duplicate(true)
	return {}


static func resolve_pending_secondary_target(match_state: Dictionary, player_id: String, target_instance_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_secondary_targets", [])
	var idx := -1
	var entry := {}
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			entry = pending[i]
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending secondary target for %s." % player_id]}
	pending.remove_at(idx)
	var source_id := str(entry.get("source_instance_id", ""))
	var damage_amount := int(entry.get("damage_amount", 1))
	var source := MatchTimingHelpers._find_card_anywhere(match_state, source_id)
	var events: Array = []
	var defender := MatchTimingHelpers._find_card_anywhere(match_state, target_instance_id)
	if not defender.is_empty():
		var result := EvergreenRules.apply_damage_to_creature(defender, damage_amount)
		var source_has_lethal := not source.is_empty() and EvergreenRules.has_keyword(source, EvergreenRules.KEYWORD_LETHAL)
		var dealt := int(result.get("applied", 0))
		events.append({"event_type": "damage_resolved", "source_instance_id": source_id, "source_controller_player_id": str(source.get("controller_player_id", "")), "target_instance_id": target_instance_id, "target_type": "creature", "amount": dealt, "damage_kind": "ability"})
		if EvergreenRules.is_creature_destroyed(defender, source_has_lethal and dealt > 0):
			var def_loc := MatchMutations.find_card_location(match_state, target_instance_id)
			var moved := MatchMutations.discard_card(match_state, target_instance_id)
			if bool(moved.get("is_valid", false)):
				events.append({"event_type": "creature_destroyed", "instance_id": target_instance_id, "source_instance_id": target_instance_id, "owner_player_id": str(defender.get("owner_player_id", "")), "controller_player_id": str(defender.get("controller_player_id", "")), "destroyed_by_instance_id": source_id, "lane_id": str(def_loc.get("lane_id", "")), "source_zone": ZONE_LANE})
	var timing_result := publish_events(match_state, events)
	return {"is_valid": true, "errors": [], "events": timing_result.get("processed_events", [])}


static func resolve_pending_secondary_target_player(match_state: Dictionary, player_id: String, target_player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_secondary_targets", [])
	var idx := -1
	var entry := {}
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			entry = pending[i]
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending secondary target for %s." % player_id]}
	pending.remove_at(idx)
	var source_id := str(entry.get("source_instance_id", ""))
	var damage_amount := int(entry.get("damage_amount", 1))
	var source := MatchTimingHelpers._find_card_anywhere(match_state, source_id)
	var events: Array = []
	var damage_result := apply_player_damage(match_state, target_player_id, damage_amount, {"source_instance_id": source_id})
	events.append({"event_type": "damage_resolved", "source_instance_id": source_id, "source_controller_player_id": str(source.get("controller_player_id", "")), "target_player_id": target_player_id, "target_type": "player", "amount": damage_amount, "damage_kind": "ability"})
	events.append_array(damage_result.get("events", []))
	var timing_result := publish_events(match_state, events)
	return {"is_valid": true, "errors": [], "events": timing_result.get("processed_events", [])}


static func has_pending_summon_effect_target(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_summon_effect_target(match_state, player_id).is_empty()


static func get_pending_summon_effect_target(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw in match_state.get("pending_summon_effect_targets", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw.get("player_id", "")) != player_id:
			continue
		return raw.duplicate(true)
	return {}


static func resolve_pending_summon_effect_target(match_state: Dictionary, player_id: String, target_info: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_summon_effect_targets", [])
	var idx := -1
	var entry := {}
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			entry = pending[i]
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending summon effect target for %s." % player_id]}
	pending.remove_at(idx)
	var source_id := str(entry.get("source_instance_id", ""))
	var resolve_options := {}
	var entry_families: Array = entry.get("allowed_families", [])
	if typeof(entry_families) == TYPE_ARRAY and not entry_families.is_empty():
		resolve_options["allowed_families"] = entry_families
	var resolve_result := resolve_targeted_effect(match_state, source_id, target_info, resolve_options)
	# Resume any paused budget summon loops
	var budget_resume := _resume_budget_summons_if_needed(match_state)
	var combined_events: Array = resolve_result.get("events", []) + budget_resume.get("events", [])
	var combined_resolutions: Array = resolve_result.get("trigger_resolutions", []) + budget_resume.get("trigger_resolutions", [])
	return {"is_valid": resolve_result.get("is_valid", false), "events": combined_events, "trigger_resolutions": combined_resolutions}


static func decline_pending_summon_effect_target(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_summon_effect_targets", [])
	var idx := -1
	var entry := {}
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			entry = pending[i]
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending summon effect target for %s." % player_id]}
	pending.remove_at(idx)
	# Clean up _primary_target_id if this was a secondary target decline
	var source_id := str(entry.get("source_instance_id", ""))
	if not source_id.is_empty():
		var source_card := MatchTimingHelpers._find_card_anywhere(match_state, source_id)
		if not source_card.is_empty():
			source_card.erase("_primary_target_id")
	# Resume any paused budget summon loops
	var budget_resume := _resume_budget_summons_if_needed(match_state)
	var combined_events: Array = budget_resume.get("events", [])
	var combined_resolutions: Array = budget_resume.get("trigger_resolutions", [])
	return {"is_valid": true, "events": combined_events, "trigger_resolutions": combined_resolutions}


## Multi-target resolution: fires each effect immediately as its target is selected.
## E.g. Fingers of the Mountain deals 1 dmg on first pick, 2 dmg on second, 3 dmg on third.
static func _resolve_multi_target_selection(match_state: Dictionary, source_card: Dictionary, target_info: Dictionary) -> Dictionary:
	var current_index: int = int(source_card.get("_multi_target_index", 0))
	var needed: int = int(source_card.get("_multi_target_count", 0))
	var descriptor: Dictionary = source_card.get("_multi_target_descriptor", {})
	var chosen_id := str(target_info.get("target_instance_id", ""))
	if chosen_id.is_empty():
		return {"is_valid": false, "errors": ["No target selected."], "events": [], "trigger_resolutions": []}
	# Fire the effect for this target immediately
	var instance_id := str(source_card.get("instance_id", ""))
	var controller_id := str(source_card.get("controller_player_id", ""))
	var effects: Array = descriptor.get("effects", [])
	var events: Array = []
	var resolutions: Array = []
	if current_index < effects.size():
		var single_effect: Dictionary = effects[current_index].duplicate(true) if typeof(effects[current_index]) == TYPE_DICTIONARY else {}
		var trigger := {
			"trigger_id": "%s_multi_target_%d" % [instance_id, current_index],
			"trigger_index": 0,
			"source_instance_id": instance_id,
			"owner_player_id": str(source_card.get("owner_player_id", controller_id)),
			"controller_player_id": controller_id,
			"source_zone": ZONE_DISCARD,
			"descriptor": {"family": str(descriptor.get("family", "on_play")), "effects": [single_effect]},
			"_chosen_target_id": chosen_id,
		}
		var event := {
			"event_type": EVENT_CARD_PLAYED,
			"source_instance_id": instance_id,
			"player_id": controller_id,
			"target_instance_id": chosen_id,
		}
		var resolution := MatchTriggers._build_trigger_resolution(match_state, trigger, event)
		events = MatchEffectApplication._apply_effects(match_state, trigger, event, resolution)
		resolutions.append(resolution)
		var timing_result := publish_events(match_state, events, {
			"parent_event_id": "multi_target_%s_%d" % [instance_id, current_index],
		})
		events = events + timing_result.get("processed_events", [])
		resolutions = resolutions + timing_result.get("trigger_resolutions", [])
	current_index += 1
	source_card["_multi_target_index"] = current_index
	if current_index < needed:
		# Queue another pending selection for the next target
		var pending_arr: Array = match_state.get("pending_summon_effect_targets", [])
		pending_arr.append({
			"player_id": controller_id,
			"source_instance_id": instance_id,
			"mandatory": true,
			"multi_target": true,
		})
	else:
		# All done — clean up multi-target state
		source_card.erase("_multi_target_ids")
		source_card.erase("_multi_target_count")
		source_card.erase("_multi_target_index")
		source_card.erase("_multi_target_descriptor")
	return {"is_valid": true, "events": events, "trigger_resolutions": resolutions}


## Pending forced play system — for effects that generate a card to hand and require immediate play.
## The UI auto-selects the card and the player drops it on a lane using the normal play flow.


static func has_pending_forced_play(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_forced_play(match_state, player_id).is_empty()


static func get_pending_forced_play(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw in match_state.get("pending_forced_plays", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw.get("player_id", "")) != player_id:
			continue
		return raw.duplicate(true)
	return {}


static func consume_pending_forced_play(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_forced_plays", [])
	var idx := -1
	var entry := {}
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			entry = pending[i]
			break
	if idx == -1:
		return {}
	pending.remove_at(idx)
	return entry


## Pending turn trigger target system — for wax/wane and end_of_turn triggers with target_mode.
## These triggers need the player to pick a target before the effect fires.

static func queue_turn_trigger_targets(match_state: Dictionary, player_id: String) -> void:
	ensure_match_state(match_state)
	var ww_families := [FAMILY_WAX, FAMILY_WANE]
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return
	var wax_wane_state := str(player.get("wax_wane_state", "wax"))
	var matching_family := FAMILY_WAX if wax_wane_state == "wax" else FAMILY_WANE
	for lane in match_state.get("lanes", []):
		var lane_index := int(lane.get("lane_index", 0))
		var slots: Array = lane.get("player_slots", {}).get(player_id, [])
		for slot_index in range(slots.size()):
			var card = slots[slot_index]
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var abilities = card.get("triggered_abilities", [])
			if typeof(abilities) != TYPE_ARRAY:
				continue
			for trigger_index in range(abilities.size()):
				var descriptor = abilities[trigger_index]
				if typeof(descriptor) != TYPE_DICTIONARY:
					continue
				var family := str(descriptor.get("family", ""))
				if family != matching_family:
					continue
				if str(descriptor.get("target_mode", "")).is_empty():
					continue  # No target needed, fires automatically
				if not bool(descriptor.get("enabled", true)):
					continue
				if descriptor.has("required_zone") and str(descriptor.get("required_zone", "")) != ZONE_LANE:
					continue
				# Check for dual wax/wane: also queue the opposite family's target triggers
				var instance_id := str(card.get("instance_id", ""))
				var valid := MatchTargeting.get_valid_targets_for_mode(match_state, instance_id, str(descriptor.get("target_mode", "")), descriptor)
				if valid.is_empty():
					continue  # No valid targets, fizzle silently
				var pending_arr: Array = match_state.get("pending_turn_trigger_targets", [])
				pending_arr.append({
					"player_id": player_id,
					"source_instance_id": instance_id,
					"trigger_index": trigger_index,
					"target_mode": str(descriptor.get("target_mode", "")),
					"family": family,
				})
	# Also queue opposite-phase target triggers if dual wax/wane is active
	if bool(player.get("_dual_wax_wane", false)):
		var dual_family := FAMILY_WANE if wax_wane_state == "wax" else FAMILY_WAX
		for lane in match_state.get("lanes", []):
			var lane_index := int(lane.get("lane_index", 0))
			var slots: Array = lane.get("player_slots", {}).get(player_id, [])
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var abilities = card.get("triggered_abilities", [])
				if typeof(abilities) != TYPE_ARRAY:
					continue
				for trigger_index in range(abilities.size()):
					var descriptor = abilities[trigger_index]
					if typeof(descriptor) != TYPE_DICTIONARY:
						continue
					if str(descriptor.get("family", "")) != dual_family:
						continue
					if str(descriptor.get("target_mode", "")).is_empty():
						continue
					if not bool(descriptor.get("enabled", true)):
						continue
					if descriptor.has("required_zone") and str(descriptor.get("required_zone", "")) != ZONE_LANE:
						continue
					var instance_id := str(card.get("instance_id", ""))
					var valid := MatchTargeting.get_valid_targets_for_mode(match_state, instance_id, str(descriptor.get("target_mode", "")), descriptor)
					if valid.is_empty():
						continue
					var pending_arr: Array = match_state.get("pending_turn_trigger_targets", [])
					pending_arr.append({
						"player_id": player_id,
						"source_instance_id": instance_id,
						"trigger_index": trigger_index,
						"target_mode": str(descriptor.get("target_mode", "")),
						"family": dual_family,
					})
	# Also queue end_of_turn and expertise triggers with target_mode
	_queue_end_of_turn_trigger_targets(match_state, player_id)
	_queue_expertise_trigger_targets(match_state, player_id)


static func _queue_end_of_turn_trigger_targets(match_state: Dictionary, player_id: String) -> void:
	for lane in match_state.get("lanes", []):
		var slots: Array = lane.get("player_slots", {}).get(player_id, [])
		for slot_index in range(slots.size()):
			var card = slots[slot_index]
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var abilities = card.get("triggered_abilities", [])
			if typeof(abilities) != TYPE_ARRAY:
				continue
			for trigger_index in range(abilities.size()):
				var descriptor = abilities[trigger_index]
				if typeof(descriptor) != TYPE_DICTIONARY:
					continue
				var family := str(descriptor.get("family", ""))
				if family != FAMILY_END_OF_TURN:
					continue
				if str(descriptor.get("target_mode", "")).is_empty():
					continue
				if not bool(descriptor.get("enabled", true)):
					continue
				if descriptor.has("required_zone") and str(descriptor.get("required_zone", "")) != ZONE_LANE:
					continue
				# Check match_role: default for end_of_turn is "controller"
				var match_role := str(descriptor.get("match_role", "controller"))
				if match_role == "opponent_player":
					continue  # opponent_player triggers are queued separately on their turn
				# Check additional conditions (e.g. invaded_this_turn)
				var instance_id := str(card.get("instance_id", ""))
				var controller_id := str(card.get("controller_player_id", player_id))
				var synthetic_trigger := {"controller_player_id": controller_id, "source_instance_id": instance_id}
				var synthetic_event := {"player_id": player_id, "source_controller_player_id": player_id}
				if not ExtendedMechanicPacks.matches_additional_conditions(match_state, synthetic_trigger, descriptor, synthetic_event):
					continue
				var valid := MatchTargeting.get_valid_targets_for_mode(match_state, instance_id, str(descriptor.get("target_mode", "")), descriptor)
				if valid.is_empty():
					continue
				var pending_arr: Array = match_state.get("pending_turn_trigger_targets", [])
				pending_arr.append({
					"player_id": controller_id,
					"source_instance_id": instance_id,
					"trigger_index": trigger_index,
					"target_mode": str(descriptor.get("target_mode", "")),
					"family": family,
				})


static func _queue_expertise_trigger_targets(match_state: Dictionary, player_id: String) -> void:
	# Expertise requires noncreature_plays_this_turn > 0
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return
	if int(player.get("noncreature_plays_this_turn", 0)) <= 0:
		return
	for lane in match_state.get("lanes", []):
		var slots: Array = lane.get("player_slots", {}).get(player_id, [])
		for slot_index in range(slots.size()):
			var card = slots[slot_index]
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var abilities = card.get("triggered_abilities", [])
			if typeof(abilities) != TYPE_ARRAY:
				continue
			for trigger_index in range(abilities.size()):
				var descriptor = abilities[trigger_index]
				if typeof(descriptor) != TYPE_DICTIONARY:
					continue
				if str(descriptor.get("family", "")) != FAMILY_EXPERTISE:
					continue
				if str(descriptor.get("target_mode", "")).is_empty():
					continue
				if not bool(descriptor.get("enabled", true)):
					continue
				if descriptor.has("required_zone") and str(descriptor.get("required_zone", "")) != ZONE_LANE:
					continue
				var instance_id := str(card.get("instance_id", ""))
				var controller_id := str(card.get("controller_player_id", player_id))
				var synthetic_trigger := {"controller_player_id": controller_id, "source_instance_id": instance_id}
				var synthetic_event := {"player_id": player_id, "source_controller_player_id": player_id}
				if not ExtendedMechanicPacks.matches_additional_conditions(match_state, synthetic_trigger, descriptor, synthetic_event):
					continue
				var valid := MatchTargeting.get_valid_targets_for_mode(match_state, instance_id, str(descriptor.get("target_mode", "")), descriptor)
				if valid.is_empty():
					continue
				var pending_arr: Array = match_state.get("pending_turn_trigger_targets", [])
				pending_arr.append({
					"player_id": controller_id,
					"source_instance_id": instance_id,
					"trigger_index": trigger_index,
					"target_mode": str(descriptor.get("target_mode", "")),
					"family": FAMILY_EXPERTISE,
				})


static func has_pending_turn_trigger_target(match_state: Dictionary, player_id: String) -> bool:
	for entry in match_state.get("pending_turn_trigger_targets", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("player_id", "")) == player_id:
			return true
	return false


static func get_pending_turn_trigger_target(match_state: Dictionary, player_id: String) -> Dictionary:
	for entry in match_state.get("pending_turn_trigger_targets", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("player_id", "")) == player_id:
			return entry.duplicate(true)
	return {}


static func resolve_pending_turn_trigger_target(match_state: Dictionary, player_id: String, target_info: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_turn_trigger_targets", [])
	var idx := -1
	var entry := {}
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			entry = pending[i]
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending turn trigger target for %s." % player_id]}
	pending.remove_at(idx)
	var source_id := str(entry.get("source_instance_id", ""))
	var trigger_index := int(entry.get("trigger_index", 0))
	var source_card := MatchTimingHelpers._find_card_anywhere(match_state, source_id)
	if source_card.is_empty():
		return {"is_valid": true, "events": [], "trigger_resolutions": []}
	var abilities = source_card.get("triggered_abilities", [])
	if typeof(abilities) != TYPE_ARRAY or trigger_index >= abilities.size():
		return {"is_valid": true, "events": [], "trigger_resolutions": []}
	var descriptor: Dictionary = abilities[trigger_index]
	var controller_id := str(source_card.get("controller_player_id", player_id))
	var target_instance_id := str(target_info.get("instance_id", ""))
	var target_player_id := str(target_info.get("player_id", ""))
	# Build a synthetic trigger with the chosen target
	var lane_index := MatchTimingHelpers._get_card_lane_index(match_state, source_id)
	var synthetic_trigger := {
		"trigger_id": "%s_turn_target_%d" % [source_id, trigger_index],
		"trigger_index": trigger_index,
		"source_instance_id": source_id,
		"owner_player_id": str(source_card.get("owner_player_id", controller_id)),
		"controller_player_id": controller_id,
		"source_zone": ZONE_LANE,
		"lane_index": lane_index,
		"slot_index": -1,
		"descriptor": descriptor.duplicate(true),
		"_chosen_target_id": target_instance_id,
		"_chosen_target_player_id": target_player_id,
	}
	var synthetic_event := {
		"event_type": EVENT_CREATURE_SUMMONED,
		"player_id": controller_id,
		"source_controller_player_id": controller_id,
	}
	var resolution := MatchTriggers._build_trigger_resolution(match_state, synthetic_trigger, synthetic_event)
	var generated := MatchEffectApplication._apply_effects(match_state, synthetic_trigger, synthetic_event, resolution)
	# Process any generated events
	if not generated.is_empty():
		var timing_result := publish_events(match_state, generated)
		var all_events: Array = timing_result.get("processed_events", [])
		return {"is_valid": true, "events": all_events, "trigger_resolutions": timing_result.get("trigger_resolutions", [])}
	return {"is_valid": true, "events": [], "trigger_resolutions": [resolution]}


static func decline_pending_turn_trigger_target(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_turn_trigger_targets", [])
	var idx := -1
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending turn trigger target for %s." % player_id]}
	pending.remove_at(idx)
	return {"is_valid": true, "events": [], "trigger_resolutions": []}


## Combined check for summon abilities that require player interaction.
## Checks consume abilities first (consume must resolve before target selection).
static func _check_summon_abilities(match_state: Dictionary, summoned_card: Dictionary) -> void:
	_check_consume_abilities(match_state, summoned_card)
	_check_summon_effect_target_mode(match_state, summoned_card)


static func _check_summon_effect_target_mode(match_state: Dictionary, summoned_card: Dictionary) -> void:
	var summon_abilities: Array = []
	var controller_id := str(summoned_card.get("controller_player_id", ""))
	var wax_wane_state := ""
	var dual_wax_wane := false
	var player := MatchTimingHelpers._get_player_state(match_state, controller_id)
	if not player.is_empty():
		wax_wane_state = str(player.get("wax_wane_state", "wax"))
		dual_wax_wane = bool(player.get("_dual_wax_wane", false))
	for ab in MatchTargeting.get_target_mode_abilities(summoned_card):
		var family := str(ab.get("family", ""))
		# Check conditions before adding — abilities with unmet conditions should be skipped
		if not _summon_ability_conditions_met(match_state, summoned_card, ab):
			continue
		if family == FAMILY_SUMMON:
			# Skip abilities with consume: true — handled by _check_consume_abilities
			if bool(ab.get("consume", false)):
				continue
			summon_abilities.append(ab)
		elif family == FAMILY_WAX:
			if wax_wane_state == "wax" or dual_wax_wane:
				summon_abilities.append(ab)
		elif family == FAMILY_WANE:
			if wax_wane_state == "wane" or dual_wax_wane:
				summon_abilities.append(ab)
	if summon_abilities.is_empty():
		return
	var instance_id := str(summoned_card.get("instance_id", ""))
	var valid := MatchTargeting.get_all_valid_targets(match_state, instance_id)
	if valid.is_empty():
		return
	var is_mandatory := false
	for ab in summon_abilities:
		if bool(ab.get("mandatory", false)):
			is_mandatory = true
			break
	var allowed_families: Array = []
	for ab in summon_abilities:
		var fam := str(ab.get("family", ""))
		if not fam.is_empty() and not allowed_families.has(fam):
			allowed_families.append(fam)
	var pending_arr: Array = match_state.get("pending_summon_effect_targets", [])
	pending_arr.append({
		"player_id": controller_id,
		"source_instance_id": instance_id,
		"mandatory": is_mandatory,
		"allowed_families": allowed_families,
	})


static func _summon_ability_conditions_met(match_state: Dictionary, card: Dictionary, descriptor: Dictionary) -> bool:
	# Build a synthetic trigger + event so we can delegate to the full condition
	# checkers (_matches_conditions + matches_additional_conditions) rather than
	# duplicating every condition here.
	var controller_id := str(card.get("controller_player_id", ""))
	var instance_id := str(card.get("instance_id", ""))
	var synthetic_trigger := {
		"controller_player_id": controller_id,
		"source_instance_id": instance_id,
		"source_zone": str(card.get("zone", ZONE_LANE)),
	}
	var synthetic_event := {
		"event_type": EVENT_CREATURE_SUMMONED,
		"source_instance_id": instance_id,
		"player_id": controller_id,
		"playing_player_id": controller_id,
		"controller_player_id": controller_id,
		"source_controller_player_id": controller_id,
	}
	var family := str(descriptor.get("family", FAMILY_SUMMON))
	var family_spec: Dictionary = FAMILY_SPECS.get(family, {})
	if not MatchTriggers._matches_conditions(match_state, synthetic_trigger, descriptor, family_spec, synthetic_event):
		return false
	if not ExtendedMechanicPacks.matches_additional_conditions(match_state, synthetic_trigger, descriptor, synthetic_event):
		return false
	return true


## Check if a creature that just killed something has slay triggers with target_mode.
## If so, queue a pending_summon_effect_targets entry so the player can pick the target.
static func _check_slay_target_mode(match_state: Dictionary, event: Dictionary) -> void:
	if str(event.get("event_type", "")) != EVENT_CREATURE_DESTROYED:
		return
	var killer_id := str(event.get("destroyed_by_instance_id", ""))
	if killer_id.is_empty():
		return
	var killer := MatchTimingHelpers._find_card_anywhere(match_state, killer_id)
	if killer.is_empty():
		return
	# Only fire if the killer is still alive (in a lane)
	var killer_zone := str(killer.get("zone", ""))
	# Allow slay even if killer just moved to discard in same combat (same as _matches_required_zone)
	if killer_zone != ZONE_LANE and killer_zone != ZONE_DISCARD:
		return
	if killer_zone == ZONE_DISCARD:
		# Killer died in same combat — slay doesn't trigger
		return
	if EvergreenRules.has_raw_status(killer, EvergreenRules.STATUS_SILENCED):
		return
	var abilities = killer.get("triggered_abilities", [])
	if typeof(abilities) != TYPE_ARRAY:
		return
	var controller_id := str(killer.get("controller_player_id", ""))
	for descriptor in abilities:
		if typeof(descriptor) != TYPE_DICTIONARY:
			continue
		if str(descriptor.get("family", "")) != FAMILY_SLAY:
			continue
		if str(descriptor.get("target_mode", "")).is_empty():
			continue
		if not bool(descriptor.get("enabled", true)):
			continue
		# Check valid targets exist
		var tm := str(descriptor.get("target_mode", ""))
		var valid_targets := MatchTargeting.get_valid_targets_for_mode(match_state, killer_id, tm)
		if valid_targets.is_empty():
			continue
		var pending_arr: Array = match_state.get("pending_summon_effect_targets", [])
		pending_arr.append({
			"player_id": controller_id,
			"source_instance_id": killer_id,
			"mandatory": false,
		})
		break  # Only queue once per slay event


## Check if a played action card has multi-target on_play triggers (two_creatures, three_creatures)
## and queue pending target selections for each target needed.
static func _check_action_multi_target_abilities(match_state: Dictionary, card: Dictionary) -> void:
	var instance_id := str(card.get("instance_id", ""))
	var controller_id := str(card.get("controller_player_id", ""))
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY:
		return
	for ab in raw_triggers:
		if typeof(ab) != TYPE_DICTIONARY:
			continue
		if str(ab.get("family", "")) != FAMILY_ON_PLAY:
			continue
		var tm := str(ab.get("target_mode", ""))
		var has_secondary := not str(ab.get("secondary_target_mode", "")).is_empty()
		var target_count := 0
		if tm == "two_creatures":
			target_count = 2
		elif tm == "three_creatures":
			target_count = 3
		if target_count > 0:
			# Multi-target: collect N targets sequentially
			card["_multi_target_ids"] = []
			card["_multi_target_count"] = target_count
			card["_multi_target_descriptor"] = ab.duplicate(true)
			var pending_arr: Array = match_state.get("pending_summon_effect_targets", [])
			pending_arr.append({
				"player_id": controller_id,
				"source_instance_id": instance_id,
				"mandatory": true,
				"multi_target": true,
			})
			break
		elif has_secondary and not tm.is_empty():
			# Dual-target (e.g. enemy + friendly): use existing secondary_target_mode system
			var valid := MatchTargeting.get_all_valid_targets(match_state, instance_id)
			if valid.is_empty():
				continue
			var pending_arr: Array = match_state.get("pending_summon_effect_targets", [])
			pending_arr.append({
				"player_id": controller_id,
				"source_instance_id": instance_id,
				"mandatory": true,
			})
			break


## Check if a played/summoned card has consume: true abilities and create pending selections.
## For abilities with target_mode, the consume selection is created instead of the target selection.
## After consume resolves, the target selection is created.
static func _check_consume_abilities(match_state: Dictionary, card: Dictionary) -> void:
	var instance_id := str(card.get("instance_id", ""))
	var controller_id := str(card.get("controller_player_id", ""))
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY:
		return
	var player := MatchTimingHelpers._get_player_state(match_state, controller_id)
	if player.is_empty():
		return
	var discard: Array = player.get(ZONE_DISCARD, [])
	var candidate_ids: Array = []
	for discard_card in discard:
		if typeof(discard_card) == TYPE_DICTIONARY and str(discard_card.get("card_type", "")) == CARD_TYPE_CREATURE:
			candidate_ids.append(str(discard_card.get("instance_id", "")))
	if candidate_ids.is_empty():
		return
	for trigger_index in range(raw_triggers.size()):
		var ability = raw_triggers[trigger_index]
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		if not bool(ability.get("consume", false)):
			continue
		var family := str(ability.get("family", ""))
		# Only create pending for summon/on_play families here — pilfer is handled in _apply_effects
		if family != FAMILY_SUMMON and family != "on_play":
			continue
		var pending_arr: Array = match_state.get("pending_consume_selections", [])
		pending_arr.append({
			"player_id": controller_id,
			"source_instance_id": instance_id,
			"candidate_instance_ids": candidate_ids.duplicate(),
			"has_target_mode": not str(ability.get("target_mode", "")).is_empty(),
			"trigger_index": trigger_index,
		})


static func has_pending_consume_selection(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_consume_selection(match_state, player_id).is_empty()


static func get_pending_consume_selection(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw in match_state.get("pending_consume_selections", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw.get("player_id", "")) != player_id:
			continue
		return raw.duplicate(true)
	return {}


static func resolve_consume_selection(match_state: Dictionary, player_id: String, chosen_instance_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_consume_selections", [])
	var idx := -1
	var entry := {}
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			entry = pending[i]
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending consume selection for %s." % player_id], "events": [], "trigger_resolutions": []}
	pending.remove_at(idx)
	var source_id := str(entry.get("source_instance_id", ""))
	var trigger_index := int(entry.get("trigger_index", 0))
	var has_target_mode := bool(entry.get("has_target_mode", false))
	# Find the consumed card to capture its info before banishing
	var consumed_card := MatchTimingHelpers._find_card_anywhere(match_state, chosen_instance_id)
	if consumed_card.is_empty():
		return {"is_valid": false, "errors": ["Consumed card not found."], "events": [], "trigger_resolutions": []}
	var consumed_info := {
		"instance_id": chosen_instance_id,
		"definition_id": str(consumed_card.get("definition_id", "")),
		"name": str(consumed_card.get("name", "")),
		"power": EvergreenRules.get_power(consumed_card),
		"health": EvergreenRules.get_health(consumed_card),
		"subtypes": consumed_card.get("subtypes", []),
		"keywords": consumed_card.get("keywords", []).duplicate(),
	}
	# Consume (banish) the selected card — power_gain/health_gain = 0 since effects handle bonuses
	var consume_result := MatchMutations.consume_card(match_state, player_id, source_id, chosen_instance_id, {
		"power_gain": 0,
		"health_gain": 0,
	})
	if not bool(consume_result.get("is_valid", false)):
		return {"is_valid": false, "errors": consume_result.get("errors", []), "events": [], "trigger_resolutions": []}
	# Publish card_consumed event so on_consumed triggers fire
	var consume_events: Array = consume_result.get("events", [])
	var publish_result := publish_events(match_state, consume_events)
	var all_events: Array = publish_result.get("processed_events", [])
	var all_resolutions: Array = publish_result.get("trigger_resolutions", [])
	# Store consumed card info on the source card for effect resolution
	var source_card := MatchTimingHelpers._find_card_anywhere(match_state, source_id)
	if not source_card.is_empty():
		source_card["_consumed_card_info"] = consumed_info
	if has_target_mode:
		# Chain into target selection — create pending_summon_effect_target
		if not source_card.is_empty():
			var valid := MatchTargeting.get_all_valid_targets(match_state, source_id)
			if not valid.is_empty():
				var pending_targets: Array = match_state.get("pending_summon_effect_targets", [])
				pending_targets.append({
					"player_id": player_id,
					"source_instance_id": source_id,
					"mandatory": false,
				})
		return {"is_valid": true, "events": all_events, "trigger_resolutions": all_resolutions}
	# No target_mode — apply effects directly
	var source_location := MatchMutations.find_card_location(match_state, source_id)
	var lane_index := int(source_location.get("lane_index", -1))
	var slot_index := int(source_location.get("slot_index", -1))
	var controller_id := str(source_card.get("controller_player_id", player_id))
	var ability: Dictionary = {}
	var raw_triggers = source_card.get("triggered_abilities", [])
	if typeof(raw_triggers) == TYPE_ARRAY and trigger_index < raw_triggers.size():
		ability = raw_triggers[trigger_index]
	if ability.is_empty():
		return {"is_valid": true, "events": all_events, "trigger_resolutions": all_resolutions}
	var trigger := {
		"trigger_id": "%s_consume_resolved" % source_id,
		"trigger_index": trigger_index,
		"source_instance_id": source_id,
		"owner_player_id": str(source_card.get("owner_player_id", controller_id)),
		"controller_player_id": controller_id,
		"source_zone": ZONE_LANE,
		"lane_index": lane_index,
		"slot_index": slot_index,
		"descriptor": ability.duplicate(true),
		"_consumed_card_info": consumed_info,
	}
	var lanes: Array = match_state.get("lanes", [])
	var lane_id := ""
	if lane_index >= 0 and lane_index < lanes.size():
		lane_id = str(lanes[lane_index].get("lane_id", ""))
	var event := {
		"event_type": EVENT_CREATURE_SUMMONED,
		"source_instance_id": source_id,
		"player_id": controller_id,
		"lane_id": lane_id,
		"lane_index": lane_index,
	}
	var resolution := MatchTriggers._build_trigger_resolution(match_state, trigger, event)
	GameLogger.log_trigger_resolution(match_state, resolution, trigger)
	var generated_events := MatchEffectApplication._apply_effects(match_state, trigger, event, resolution)
	if not generated_events.is_empty():
		var effect_publish := publish_events(match_state, generated_events)
		all_events.append_array(effect_publish.get("processed_events", []))
		all_resolutions.append_array(effect_publish.get("trigger_resolutions", []))
	return {"is_valid": true, "events": all_events, "trigger_resolutions": all_resolutions}


static func decline_consume_selection(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_consume_selections", [])
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			pending.remove_at(i)
			return {"is_valid": true, "events": [], "trigger_resolutions": []}
	return {"is_valid": false, "errors": ["No pending consume selection for %s." % player_id]}


## Get discard pile creatures available for consume for a given player.
static func get_consume_candidates(match_state: Dictionary, player_id: String) -> Array:
	ensure_match_state(match_state)
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return []
	var candidates: Array = []
	for card in player.get(ZONE_DISCARD, []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
			candidates.append(card)
	return candidates


# --- Pending deck selections (player chooses a card from their deck) ---


static func has_pending_deck_selection(match_state: Dictionary, player_id: String = "") -> bool:
	return not get_pending_deck_selection(match_state, player_id).is_empty()


static func get_pending_deck_selection(match_state: Dictionary, player_id: String = "") -> Dictionary:
	ensure_match_state(match_state)
	for raw in match_state.get("pending_deck_selections", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if not player_id.is_empty() and str(raw.get("player_id", "")) != player_id:
			continue
		return raw.duplicate(true)
	return {}


static func resolve_pending_deck_selection(match_state: Dictionary, player_id: String, chosen_instance_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_deck_selections", [])
	var idx := -1
	var entry := {}
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			entry = pending[i]
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending deck selection for %s." % player_id], "events": [], "trigger_resolutions": []}
	pending.remove_at(idx)
	var source_id := str(entry.get("source_instance_id", ""))
	var then_op := str(entry.get("then_op", ""))
	var then_context: Dictionary = entry.get("then_context", {})
	# Find the chosen card in the deck
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return {"is_valid": false, "errors": ["Player not found."], "events": [], "trigger_resolutions": []}
	var deck: Array = player.get(ZONE_DECK, [])
	var chosen_card: Dictionary = {}
	var chosen_idx := -1
	for i in range(deck.size()):
		if typeof(deck[i]) == TYPE_DICTIONARY and str(deck[i].get("instance_id", "")) == chosen_instance_id:
			chosen_card = deck[i]
			chosen_idx = i
			break
	if chosen_card.is_empty():
		return {"is_valid": false, "errors": ["Card not found in deck."], "events": [], "trigger_resolutions": []}
	var generated_events: Array = []
	match then_op:
		"summon_support_from_deck":
			deck.remove_at(chosen_idx)
			chosen_card["zone"] = MatchMutations.ZONE_SUPPORT
			chosen_card["controller_player_id"] = player_id
			if not chosen_card.has("owner_player_id"):
				chosen_card["owner_player_id"] = player_id
			var supports: Array = player.get(MatchMutations.ZONE_SUPPORT, [])
			supports.append(chosen_card)
			generated_events.append({
				"event_type": EVENT_CARD_PLAYED,
				"playing_player_id": player_id,
				"player_id": player_id,
				"source_instance_id": str(chosen_card.get("instance_id", "")),
				"source_zone": "deck",
				"target_zone": MatchMutations.ZONE_SUPPORT,
				"card_type": "support",
				"reason": str(then_context.get("reason", "deck_selection")),
			})
		"draw_card_to_hand":
			deck.remove_at(chosen_idx)
			chosen_card["zone"] = ZONE_HAND
			var dch_hand: Array = player.get(ZONE_HAND, [])
			dch_hand.append(chosen_card)
			generated_events.append({"event_type": "card_drawn", "player_id": player_id, "instance_id": str(chosen_card.get("instance_id", "")), "source": "draw_from_deck_filtered", "reason": str(then_context.get("reason", "deck_selection"))})
		"summon_creature_from_deck":
			deck.remove_at(chosen_idx)
			chosen_card.erase("zone")
			var lane_id := str(then_context.get("lane_id", ""))
			if lane_id.is_empty():
				# Default to first lane with space
				for lane in match_state.get("lanes", []):
					var lid := str(lane.get("lane_id", ""))
					var slots: Array = lane.get("player_slots", {}).get(player_id, [])
					if slots.size() < int(lane.get("slot_capacity", 4)):
						lane_id = lid
						break
			if not lane_id.is_empty():
				var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, chosen_card, lane_id, {"source_zone": ZONE_DECK})
				if bool(summon_result.get("is_valid", false)):
					generated_events.append_array(summon_result.get("events", []))
					generated_events.append({
						"event_type": EVENT_CREATURE_SUMMONED,
						"playing_player_id": player_id,
						"player_id": player_id,
						"source_instance_id": str(chosen_card.get("instance_id", "")),
						"source_controller_player_id": player_id,
						"lane_id": lane_id,
						"slot_index": int(summon_result.get("slot_index", -1)),
						"reason": str(then_context.get("reason", "deck_selection")),
					})
					_check_summon_abilities(match_state, summon_result["card"])
	# Publish events
	var all_events: Array = []
	var all_resolutions: Array = []
	if not generated_events.is_empty():
		var publish_result := publish_events(match_state, generated_events)
		all_events = publish_result.get("processed_events", [])
		all_resolutions = publish_result.get("trigger_resolutions", [])
	return {"is_valid": true, "events": all_events, "trigger_resolutions": all_resolutions, "card": chosen_card}


static func decline_pending_deck_selection(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_deck_selections", [])
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			pending.remove_at(i)
			return {"is_valid": true, "events": [], "trigger_resolutions": []}
	return {"is_valid": false, "errors": ["No pending deck selection for %s." % player_id]}


static func apply_player_damage(match_state: Dictionary, player_id: String, amount: int, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var result := {
		"applied_damage": 0,
		"events": [],
		"broken_runes": [],
		"player_lost": false,
		"pending_prophecy_opened": false,
	}
	if amount <= 0:
		return result
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return result
	# Face ward: absorb the entire damage instance and remove the ward
	if bool(player.get("has_ward", false)):
		player["has_ward"] = false
		result["events"] = [{"event_type": "player_ward_removed", "player_id": player_id, "absorbed_damage": amount, "source_instance_id": str(context.get("source_instance_id", ""))}]
		return result
	# Grants-immunity: action_damage / support_damage — check if a friendly creature shields the player
	var apd_source_id := str(context.get("source_instance_id", ""))
	if not apd_source_id.is_empty():
		var apd_source := MatchTimingHelpers._find_card_anywhere(match_state, apd_source_id)
		var apd_source_type := str(apd_source.get("card_type", ""))
		var apd_immunity_key := ""
		if apd_source_type == "action":
			apd_immunity_key = "action_damage"
		elif apd_source_type == "support":
			apd_immunity_key = "support_damage"
		if not apd_immunity_key.is_empty() and MatchTimingHelpers._player_has_grants_immunity(match_state, player_id, apd_immunity_key):
			return result
	var previous_health := int(player.get("health", 0))
	var new_health := previous_health - amount
	player["health"] = new_health
	result["applied_damage"] = amount
	if new_health <= 0:
		if not MatchTimingHelpers._has_cannot_lose(match_state, player_id):
			result["player_lost"] = true
			return result

	var crossed_thresholds: Array = []
	for raw_threshold in player.get("rune_thresholds", []):
		var threshold := int(raw_threshold)
		if previous_health > threshold and new_health <= threshold:
			crossed_thresholds.append(threshold)
	if crossed_thresholds.is_empty():
		return result

	var queue: Array = match_state.get("pending_rune_break_queue", [])
	for threshold in crossed_thresholds:
		queue.append({
			"player_id": player_id,
			"threshold": threshold,
			"reason": str(context.get("reason", "damage")),
			"source_instance_id": str(context.get("source_instance_id", "")),
			"source_controller_player_id": str(context.get("source_controller_player_id", "")),
			"causing_player_id": str(context.get("causing_player_id", context.get("source_controller_player_id", ""))),
			"timing_window": str(context.get("timing_window", WINDOW_INTERRUPT)),
		})
	match_state["pending_rune_break_queue"] = queue

	var rune_result := _resume_pending_rune_breaks(match_state)
	result["events"] = rune_result.get("events", [])
	result["broken_runes"] = rune_result.get("broken_runes", [])
	result["pending_prophecy_opened"] = bool(rune_result.get("pending_prophecy_opened", false))
	result["player_lost"] = bool(rune_result.get("player_lost", false))
	return result


static func draw_cards(match_state: Dictionary, player_id: String, count: int, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var result := {
		"cards": [],
		"events": [],
		"player_lost": false,
		"pending_prophecy_opened": false,
	}
	if count <= 0:
		return result
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return result

	for _index in range(count):
		var deck: Array = player.get(ZONE_DECK, [])
		if deck.is_empty():
			var fatigue_result := _resolve_out_of_cards(match_state, player_id, context)
			result["events"].append_array(fatigue_result.get("events", []))
			result["player_lost"] = bool(fatigue_result.get("player_lost", false))
			break

		var drawn_card: Dictionary = deck.pop_back()
		var hand: Array = player.get(ZONE_HAND, [])
		var allow_prophecy := bool(context.get("allow_prophecy_interrupt", false))
		var is_prophecy := allow_prophecy and _can_open_prophecy_window(match_state, player_id, drawn_card)
		if hand.size() >= MAX_HAND_SIZE and not is_prophecy:
			drawn_card["zone"] = ZONE_DISCARD
			player[ZONE_DISCARD].append(drawn_card)
			result["events"].append({
				"event_type": EVENT_CARD_OVERDRAW,
				"player_id": player_id,
				"instance_id": str(drawn_card.get("instance_id", "")),
				"card_name": str(drawn_card.get("name", "")),
				"source_zone": ZONE_DECK,
			})
			continue
		drawn_card["zone"] = ZONE_HAND
		hand.append(drawn_card)
		MatchMutations.apply_first_turn_hand_cost(match_state, drawn_card, player_id)
		result["cards"].append(drawn_card)
		var draw_event := {
			"event_type": EVENT_CARD_DRAWN,
			"player_id": player_id,
			"source_instance_id": str(context.get("source_instance_id", "")),
			"source_controller_player_id": str(context.get("source_controller_player_id", "")),
			"drawn_instance_id": str(drawn_card.get("instance_id", "")),
			"source_zone": ZONE_DECK,
			"target_zone": ZONE_HAND,
			"reason": str(context.get("reason", "draw")),
			"timing_window": str(context.get("timing_window", WINDOW_AFTER)),
		}
		if context.has("rune_threshold"):
			draw_event["rune_threshold"] = int(context.get("rune_threshold", -1))
		result["events"].append(draw_event)

		if bool(context.get("allow_prophecy_interrupt", false)) and _can_open_prophecy_window(match_state, player_id, drawn_card):
			result["pending_prophecy_opened"] = true
			result["events"].append(_open_prophecy_window(match_state, player_id, drawn_card, context))
			break
	return result


static func _overflow_card_to_discard(player: Dictionary, card: Dictionary, player_id: String, source_zone: String, events: Array) -> bool:
	var hand: Array = player.get(ZONE_HAND, [])
	if hand.size() < MAX_HAND_SIZE:
		return false
	card["zone"] = ZONE_DISCARD
	player[ZONE_DISCARD].append(card)
	events.append({
		"event_type": EVENT_CARD_OVERDRAW,
		"player_id": player_id,
		"instance_id": str(card.get("instance_id", "")),
		"card_name": str(card.get("name", "")),
		"source_zone": source_zone,
	})
	return true


static func destroy_front_rune(match_state: Dictionary, player_id: String, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var result := {
		"is_valid": false,
		"events": [],
		"destroyed_threshold": -1,
		"player_lost": false,
	}
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return result
	result["is_valid"] = true

	var thresholds: Array = player.get("rune_thresholds", [])
	if thresholds.is_empty():
		player["health"] = 0
		append_match_win_if_needed(match_state, player_id, MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), player_id), result["events"])
		result["player_lost"] = true
		return result

	var destroyed_threshold := int(thresholds[0])
	thresholds.remove_at(0)
	player["rune_thresholds"] = thresholds
	player["health"] = destroyed_threshold
	result["destroyed_threshold"] = destroyed_threshold
	result["events"].append({
		"event_type": EVENT_RUNE_BROKEN,
		"player_id": player_id,
		"threshold": destroyed_threshold,
		"source_instance_id": str(context.get("source_instance_id", "")),
		"source_controller_player_id": str(context.get("source_controller_player_id", "")),
		"causing_player_id": str(context.get("causing_player_id", context.get("source_controller_player_id", ""))),
		"reason": str(context.get("reason", "forced_rune_break")),
		"draw_card": false,
		"timing_window": str(context.get("timing_window", WINDOW_IMMEDIATE)),
	})
	return result


static func decline_pending_prophecy(match_state: Dictionary, player_id: String, instance_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var window_index := _find_pending_prophecy_window_index(match_state, player_id, instance_id)
	if window_index == -1:
		return MatchTimingHelpers._invalid_result("No pending Prophecy window exists for %s." % instance_id)
	var window := _consume_pending_prophecy_window(match_state, window_index)
	var events: Array = [{
		"event_type": EVENT_PROPHECY_DECLINED,
		"player_id": player_id,
		"drawn_instance_id": instance_id,
		"source_instance_id": str(window.get("source_instance_id", "")),
		"reason": RULE_TAG_PROPHECY,
		"timing_window": WINDOW_INTERRUPT,
	}]
	# If hand is at or over max size, discard the card instead of keeping it
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	var hand: Array = player.get(ZONE_HAND, [])
	if hand.size() > MAX_HAND_SIZE:
		var card_index := -1
		for i in range(hand.size()):
			if str(hand[i].get("instance_id", "")) == instance_id:
				card_index = i
				break
		if card_index != -1:
			var card: Dictionary = hand[card_index]
			hand.remove_at(card_index)
			card["zone"] = ZONE_DISCARD
			player[ZONE_DISCARD].append(card)
			events.append({
				"event_type": EVENT_CARD_OVERDRAW,
				"player_id": player_id,
				"instance_id": instance_id,
				"card_name": str(card.get("name", "")),
				"source_zone": ZONE_HAND,
			})
	var resume_result := _resume_pending_rune_breaks(match_state)
	events.append_array(resume_result.get("events", []))
	var timing_result := publish_events(match_state, events)
	return {
		"is_valid": true,
		"errors": [],
		"events": timing_result.get("processed_events", []),
		"trigger_resolutions": timing_result.get("trigger_resolutions", []),
		"card": MatchTimingHelpers._find_card_anywhere(match_state, instance_id),
	}


static func play_pending_prophecy(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	if str(match_state.get("active_player_id", "")) == player_id:
		return MatchTimingHelpers._invalid_result("Prophecy free play is only available during the opponent's turn.")
	var window_index := _find_pending_prophecy_window_index(match_state, player_id, instance_id)
	if window_index == -1:
		return MatchTimingHelpers._invalid_result("No pending Prophecy window exists for %s." % instance_id)
	var card: Dictionary = MatchTimingHelpers._find_card_anywhere(match_state, instance_id)
	if card.is_empty() or str(card.get("zone", "")) != ZONE_HAND:
		return MatchTimingHelpers._invalid_result("Pending Prophecy card %s must still be in hand to be played." % instance_id)

	var card_type := str(card.get("card_type", ""))
	if card_type == CARD_TYPE_CREATURE:
		var lane_id := str(options.get("lane_id", ""))
		if lane_id.is_empty():
			return MatchTimingHelpers._invalid_result("Creature Prophecy play requires a lane_id.")
		var lane_rules: Variant = load("res://src/core/match/lane_rules.gd")
		var validation_options := options.duplicate(true)
		validation_options["played_for_free"] = true
		var validation: Dictionary = lane_rules.validate_summon_from_hand(match_state, player_id, instance_id, lane_id, validation_options)
		if not bool(validation.get("is_valid", false)):
			return validation
		_consume_pending_prophecy_window(match_state, window_index)
		var summon_options := options.duplicate(true)
		summon_options["event_context"] = {"timing_window": WINDOW_INTERRUPT}
		summon_options["played_for_free"] = true
		summon_options["play_event_overrides"] = {
			"played_for_free": true,
			"reason": RULE_TAG_PROPHECY,
		}
		summon_options["summon_event_overrides"] = {
			"played_for_free": true,
			"reason": RULE_TAG_PROPHECY,
		}
		var original_priority := str(match_state.get("priority_player_id", ""))
		match_state["priority_player_id"] = player_id
		var summon_result: Dictionary = lane_rules.summon_from_hand(match_state, player_id, instance_id, lane_id, summon_options)
		var processed_events: Array = summon_result.get("events", []).duplicate(true)
		var trigger_resolutions: Array = summon_result.get("trigger_resolutions", []).duplicate(true)
		var resume_result := _resume_pending_rune_breaks(match_state)
		if not resume_result.get("events", []).is_empty():
			var resumed_timing := publish_events(match_state, resume_result.get("events", []))
			processed_events.append_array(resumed_timing.get("processed_events", []))
			trigger_resolutions.append_array(resumed_timing.get("trigger_resolutions", []))
		match_state["priority_player_id"] = original_priority
		summon_result["events"] = processed_events
		summon_result["trigger_resolutions"] = trigger_resolutions
		return summon_result

	if card_type == CARD_TYPE_ACTION:
		var player := MatchTimingHelpers._get_player_state(match_state, player_id)
		var hand_index := MatchTimingHelpers._find_card_index(player.get(ZONE_HAND, []), instance_id)
		if hand_index == -1:
			return MatchTimingHelpers._invalid_result("Pending Prophecy card %s is no longer in hand." % instance_id)
		_consume_pending_prophecy_window(match_state, window_index)
		var played_card: Dictionary = player[ZONE_HAND][hand_index]
		player[ZONE_HAND].remove_at(hand_index)
		played_card["zone"] = ZONE_DISCARD
		player[ZONE_DISCARD].append(played_card)
		var original_priority := str(match_state.get("priority_player_id", ""))
		match_state["priority_player_id"] = player_id
		var timing_result := publish_events(match_state, [{
			"event_type": EVENT_CARD_PLAYED,
			"playing_player_id": player_id,
			"player_id": player_id,
			"source_instance_id": instance_id,
			"source_controller_player_id": player_id,
			"source_zone": ZONE_HAND,
			"target_zone": ZONE_DISCARD,
			"card_type": card_type,
			"played_cost": int(played_card.get("cost", 0)),
			"played_for_free": true,
			"reason": RULE_TAG_PROPHECY,
			"timing_window": WINDOW_INTERRUPT,
			"target_instance_id": str(options.get("target_instance_id", "")),
			"target_player_id": str(options.get("target_player_id", "")),
			"lane_id": str(options.get("lane_id", "")),
			"source_rules_text": str(played_card.get("rules_text", "")),
			"source_name": str(played_card.get("name", "")),
			"rules_tags": played_card.get("rules_tags", []).duplicate() if typeof(played_card.get("rules_tags", [])) == TYPE_ARRAY else [],
		}])
		var processed_events: Array = timing_result.get("processed_events", []).duplicate(true)
		var trigger_resolutions: Array = timing_result.get("trigger_resolutions", []).duplicate(true)
		var resume_result := _resume_pending_rune_breaks(match_state)
		if not resume_result.get("events", []).is_empty():
			var resumed_timing := publish_events(match_state, resume_result.get("events", []))
			processed_events.append_array(resumed_timing.get("processed_events", []))
			trigger_resolutions.append_array(resumed_timing.get("trigger_resolutions", []))
		match_state["priority_player_id"] = original_priority
		return {
			"is_valid": true,
			"errors": [],
			"card": played_card,
			"events": processed_events,
			"trigger_resolutions": trigger_resolutions,
		}

	if card_type == CARD_TYPE_ITEM:
		var target_instance_id := str(options.get("target_instance_id", ""))
		if target_instance_id.is_empty():
			return MatchTimingHelpers._invalid_result("Item Prophecy play requires a target_instance_id.")
		var target_lookup := MatchMutations.find_card_location(match_state, target_instance_id)
		if not bool(target_lookup.get("is_valid", false)):
			return MatchTimingHelpers._invalid_result("Target %s is not on the board." % target_instance_id)
		var target_card: Dictionary = target_lookup["card"]
		if str(target_lookup.get("zone", "")) != ZONE_LANE or str(target_card.get("card_type", "")) != CARD_TYPE_CREATURE:
			return MatchTimingHelpers._invalid_result("Items can only target creatures in a lane.")
		_consume_pending_prophecy_window(match_state, window_index)
		var player := MatchTimingHelpers._get_player_state(match_state, player_id)
		var hand: Array = player.get(ZONE_HAND, [])
		var hand_index := MatchTimingHelpers._find_card_index(hand, instance_id)
		if hand_index == -1:
			return MatchTimingHelpers._invalid_result("Pending Prophecy card %s is no longer in hand." % instance_id)
		var item_card: Dictionary = hand[hand_index]
		var original_priority := str(match_state.get("priority_player_id", ""))
		match_state["priority_player_id"] = player_id
		# Check for throw-mode: item with on_play enemy damage ability targeting an enemy creature
		var is_throw := false
		var throw_ability := {}
		if str(target_card.get("controller_player_id", "")) != player_id:
			for ta in item_card.get("triggered_abilities", []):
				if typeof(ta) == TYPE_DICTIONARY and str(ta.get("family", "")) == "on_play":
					var tm := str(ta.get("target_mode", ""))
					if tm == "enemy_creature_optional" or tm == "enemy_creature":
						is_throw = true
						throw_ability = ta
						break
		var generated_events: Array = []
		if is_throw:
			hand.remove_at(hand_index)
			item_card["zone"] = ZONE_DISCARD
			player.get(ZONE_DISCARD, []).append(item_card)
			generated_events.append({
				"event_type": EVENT_CARD_PLAYED,
				"playing_player_id": player_id,
				"player_id": player_id,
				"source_instance_id": instance_id,
				"source_controller_player_id": player_id,
				"source_zone": ZONE_HAND,
				"target_zone": ZONE_DISCARD,
				"target_instance_id": target_instance_id,
				"card_type": CARD_TYPE_ITEM,
				"played_cost": int(item_card.get("cost", 0)),
				"played_for_free": true,
				"reason": RULE_TAG_PROPHECY,
				"timing_window": WINDOW_INTERRUPT,
			})
			# Apply throw effects directly (item on_play triggers are excluded from the registry)
			for throw_effect in throw_ability.get("effects", []):
				if typeof(throw_effect) != TYPE_DICTIONARY:
					continue
				var throw_op := str(throw_effect.get("op", ""))
				if throw_op == "deal_damage":
					var throw_amount := int(throw_effect.get("amount", 0))
					var throw_dmg_result := EvergreenRules.apply_damage_to_creature(target_card, throw_amount)
					generated_events.append({
						"event_type": EVENT_DAMAGE_RESOLVED,
						"source_instance_id": instance_id,
						"target_instance_id": target_instance_id,
						"target_type": "creature",
						"amount": int(throw_dmg_result.get("applied", 0)),
						"damage_kind": "ability",
					})
					if EvergreenRules.is_creature_destroyed(target_card, false):
						var throw_loc := MatchMutations.find_card_location(match_state, target_instance_id)
						var throw_moved := MatchMutations.discard_card(match_state, target_instance_id)
						if bool(throw_moved.get("is_valid", false)):
							generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": target_instance_id, "source_instance_id": target_instance_id, "owner_player_id": str(target_card.get("owner_player_id", "")), "controller_player_id": str(target_card.get("controller_player_id", "")), "destroyed_by_instance_id": instance_id, "lane_id": str(throw_loc.get("lane_id", "")), "source_zone": ZONE_LANE})
				elif throw_op == "shackle":
					EvergreenRules.add_status(target_card, EvergreenRules.STATUS_SHACKLED)
		else:
			var attach_result := MatchMutations.attach_item_to_creature(match_state, player_id, instance_id, target_instance_id, {"source_zone": ZONE_HAND})
			if not bool(attach_result.get("is_valid", false)):
				match_state["priority_player_id"] = original_priority
				return attach_result
			generated_events.append({
				"event_type": EVENT_CARD_PLAYED,
				"playing_player_id": player_id,
				"player_id": player_id,
				"source_instance_id": instance_id,
				"source_controller_player_id": player_id,
				"source_zone": ZONE_HAND,
				"target_zone": "attached_item",
				"target_instance_id": target_instance_id,
				"card_type": CARD_TYPE_ITEM,
				"played_cost": int(item_card.get("cost", 0)),
				"played_for_free": true,
				"reason": RULE_TAG_PROPHECY,
				"timing_window": WINDOW_INTERRUPT,
			})
			generated_events.append({
				"event_type": "card_equipped",
				"player_id": player_id,
				"source_instance_id": instance_id,
				"source_controller_player_id": str(attach_result["card"].get("controller_player_id", player_id)),
				"target_instance_id": target_instance_id,
			})
		var timing_result := publish_events(match_state, generated_events)
		var processed_events: Array = timing_result.get("processed_events", []).duplicate(true)
		var trigger_resolutions: Array = timing_result.get("trigger_resolutions", []).duplicate(true)
		var resume_result := _resume_pending_rune_breaks(match_state)
		if not resume_result.get("events", []).is_empty():
			var resumed_timing := publish_events(match_state, resume_result.get("events", []))
			processed_events.append_array(resumed_timing.get("processed_events", []))
			trigger_resolutions.append_array(resumed_timing.get("trigger_resolutions", []))
		match_state["priority_player_id"] = original_priority
		return {
			"is_valid": true,
			"errors": [],
			"card": item_card,
			"events": processed_events,
			"trigger_resolutions": trigger_resolutions,
		}

	return MatchTimingHelpers._invalid_result("Prophecy free play is not implemented for card type `%s`." % card_type)


static func play_action_from_hand(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var action_owner_validation := MatchTimingHelpers._validate_action_owner(match_state, player_id, "Action play")
	if not bool(action_owner_validation.get("is_valid", false)):
		return action_owner_validation
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return MatchTimingHelpers._invalid_result("Unknown player_id: %s" % player_id)
	var hand_index := MatchTimingHelpers._find_card_index(player.get(ZONE_HAND, []), instance_id)
	if hand_index == -1:
		return MatchTimingHelpers._invalid_result("Card %s is not in %s's hand." % [instance_id, player_id])
	var played_card: Dictionary = player[ZONE_HAND][hand_index]
	if str(played_card.get("card_type", "")) != CARD_TYPE_ACTION:
		return MatchTimingHelpers._invalid_result("Card %s is not an action." % instance_id)
	ExtendedMechanicPacks.apply_pre_play_options(played_card, options)
	if str(played_card.get("card_type", "")) != CARD_TYPE_ACTION:
		return MatchTimingHelpers._invalid_result("Selected mode for %s is not playable as an action." % instance_id)
	var played_for_free := bool(options.get("played_for_free", false))
	if not played_for_free:
		var play_limit := PersistentCardRules.get_play_limit_per_turn(match_state, player_id)
		if play_limit >= 0 and int(player.get("cards_played_this_turn", 0)) >= play_limit:
			return MatchTimingHelpers._invalid_result("You may only play %d card(s) per turn." % play_limit)
	var base_action_cost := int(played_card.get("cost", 0)) + (1 if bool(options.get("exalt", false)) else 0)
	var action_cost_reduction := int(player.get("next_card_cost_reduction", 0))
	action_cost_reduction += MatchTimingHelpers._get_aura_cost_reduction(match_state, player_id, played_card)
	var self_reduction = played_card.get("self_cost_reduction", {})
	if typeof(self_reduction) == TYPE_DICTIONARY and not self_reduction.is_empty():
		var sr_source := str(self_reduction.get("per", self_reduction.get("type", self_reduction.get("source", ""))))
		var sr_amount := int(self_reduction.get("amount", self_reduction.get("amount_per", 1)))
		# Handle single-key format: {"per_friendly_wounded": 3} → source="per_friendly_wounded", amount=3
		if sr_source.is_empty():
			for key in self_reduction.keys():
				if key != "amount" and key != "amount_per" and key != "per" and key != "type" and key != "source":
					sr_source = key
					sr_amount = int(self_reduction.get(key, 1))
					break
		if sr_source == "empower":
			action_cost_reduction += MatchTimingHelpers._get_empower_amount(match_state, player_id) * sr_amount
		elif sr_source == "creature_summons_this_turn":
			action_cost_reduction += int(player.get("creature_summons_this_turn", 0)) * sr_amount
		elif sr_source == "creatures_died_this_turn":
			action_cost_reduction += int(player.get("creatures_died_this_turn", 0)) * sr_amount
		elif sr_source == "per_action_played_this_turn":
			action_cost_reduction += int(player.get("noncreature_plays_this_turn", 0)) * sr_amount
		elif sr_source == "per_friendly_wounded":
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(player_id, []):
					if typeof(c) == TYPE_DICTIONARY and int(c.get("damage_marked", 0)) > 0:
						action_cost_reduction += sr_amount
		elif sr_source == "per_friendly_creature_min_health_5":
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(player_id, []):
					if typeof(c) == TYPE_DICTIONARY and EvergreenRules.get_remaining_health(c) >= 5:
						action_cost_reduction += sr_amount
		elif sr_source == "per_pilfer_or_drain_this_turn":
			action_cost_reduction += int(player.get("pilfer_or_drain_count_this_turn", 0)) * sr_amount
		elif sr_source == "per_creature_in_discard":
			for c in player.get("discard", []):
				if typeof(c) == TYPE_DICTIONARY and str(c.get("card_type", "")) == "creature":
					action_cost_reduction += sr_amount
		elif sr_source == "per_attribute_in_play":
			var seen_attrs: Dictionary = {}
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(player_id, []):
					if typeof(c) != TYPE_DICTIONARY:
						continue
					for attr in c.get("attributes", []):
						if not seen_attrs.has(str(attr)):
							seen_attrs[str(attr)] = true
			action_cost_reduction += seen_attrs.size() * sr_amount
		elif sr_source == "if_neutral_in_play":
			var has_neutral := false
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(player_id, []):
					if typeof(c) == TYPE_DICTIONARY:
						for attr in c.get("attributes", []):
							if str(attr) == "neutral":
								has_neutral = true
			if has_neutral:
				action_cost_reduction += sr_amount
		elif sr_source == "per_opponent_undead":
			var opp_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), player_id)
			for lane in match_state.get("lanes", []):
				for c in lane.get("player_slots", {}).get(opp_id, []):
					if typeof(c) == TYPE_DICTIONARY:
						var subtypes = c.get("subtypes", [])
						if typeof(subtypes) == TYPE_ARRAY:
							for st in subtypes:
								if str(st) == "Skeleton" or str(st) == "Vampire" or str(st) == "Spirit" or str(st) == "Mummy":
									action_cost_reduction += sr_amount
									break
		elif sr_source == "per_dragon_in_discard":
			for c in player.get("discard", []):
				if typeof(c) == TYPE_DICTIONARY and str(c.get("card_type", "")) == "creature":
					var subtypes = c.get("subtypes", [])
					if typeof(subtypes) == TYPE_ARRAY:
						for st in subtypes:
							if str(st) == "Dragon":
								action_cost_reduction += sr_amount
								break
		elif sr_source == "unique_creatures_in_discard":
			var seen_defs: Dictionary = {}
			for c in player.get("discard", []):
				if typeof(c) == TYPE_DICTIONARY and str(c.get("card_type", "")) == "creature":
					var def_id := str(c.get("definition_id", ""))
					if not seen_defs.has(def_id):
						seen_defs[def_id] = true
			action_cost_reduction += seen_defs.size() * sr_amount
	# First Lesson boon: first action each turn costs N less (discount cleared after first use)
	var first_lesson_discount := int(player.get("_first_lesson_discount", 0))
	if first_lesson_discount > 0:
		action_cost_reduction += first_lesson_discount
		player["_first_lesson_discount"] = 0
	var play_cost := 0 if played_for_free else maxi(0, base_action_cost - action_cost_reduction)
	if play_cost > MatchTimingHelpers._get_available_magicka(player):
		return MatchTimingHelpers._invalid_result("Player does not have enough magicka to play %s." % instance_id)
	if not played_for_free:
		for cl in player.get("cost_locks", []):
			if typeof(cl) == TYPE_DICTIONARY and int(cl.get("cost", -1)) == play_cost:
				return MatchTimingHelpers._invalid_result("Cannot play cards with cost %d." % play_cost)
	if play_cost > 0:
		MatchTimingHelpers._spend_magicka(match_state, player_id, play_cost)
	if action_cost_reduction > 0:
		player["next_card_cost_reduction"] = 0
	player[ZONE_HAND].remove_at(hand_index)
	played_card["zone"] = ZONE_DISCARD
	player[ZONE_DISCARD].append(played_card)
	_check_action_multi_target_abilities(match_state, played_card)
	var timing_result := publish_events(match_state, [{
		"event_type": EVENT_CARD_PLAYED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": instance_id,
		"source_controller_player_id": player_id,
		"source_zone": ZONE_HAND,
		"target_zone": ZONE_DISCARD,
		"card_type": CARD_TYPE_ACTION,
		"played_cost": play_cost,
		"played_for_free": played_for_free,
		"reason": str(options.get("reason", "play_action")),
		"timing_window": str(options.get("timing_window", WINDOW_AFTER)),
		"target_instance_id": str(options.get("target_instance_id", "")),
		"target_player_id": str(options.get("target_player_id", "")),
		"lane_id": str(options.get("lane_id", "")),
		"source_rules_text": str(played_card.get("rules_text", "")),
		"source_name": str(played_card.get("name", "")),
		"rules_tags": played_card.get("rules_tags", []).duplicate() if typeof(played_card.get("rules_tags", [])) == TYPE_ARRAY else [],
	}])
	return {
		"is_valid": true,
		"errors": [],
		"card": played_card,
		"events": timing_result.get("processed_events", []),
		"trigger_resolutions": timing_result.get("trigger_resolutions", []),
	}


static func execute_betray_replay(match_state: Dictionary, player_id: String, action_instance_id: String, sacrifice_instance_id: String, replay_options: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	# Sacrifice the chosen creature
	var sacrifice_result := MatchMutations.sacrifice_card(match_state, player_id, sacrifice_instance_id, {"reason": "betray"})
	if not bool(sacrifice_result.get("is_valid", false)):
		return sacrifice_result
	var all_events: Array = []
	# Publish sacrifice events first so triggers (last gasp, etc.) fire
	var sacrifice_timing := publish_events(match_state, sacrifice_result.get("events", []))
	all_events.append_array(sacrifice_timing.get("processed_events", []))
	# Find the action card in discard
	var action_card := {}
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return {"is_valid": false, "errors": ["Unknown player_id: %s" % player_id], "events": [], "trigger_resolutions": []}
	for card in player.get(ZONE_DISCARD, []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == action_instance_id:
			action_card = card
			break
	if action_card.is_empty():
		return {"is_valid": false, "errors": ["Action card %s not found in discard." % action_instance_id], "events": [], "trigger_resolutions": []}
	# Queue multi-target / dual-target abilities before replaying
	_check_action_multi_target_abilities(match_state, action_card)
	# Replay the action for free from discard
	var replay_timing := publish_events(match_state, [{
		"event_type": EVENT_CARD_PLAYED,
		"playing_player_id": player_id,
		"player_id": player_id,
		"source_instance_id": action_instance_id,
		"source_controller_player_id": player_id,
		"source_zone": ZONE_DISCARD,
		"target_zone": ZONE_DISCARD,
		"card_type": CARD_TYPE_ACTION,
		"played_cost": 0,
		"played_for_free": true,
		"reason": "betray_replay",
		"target_instance_id": str(replay_options.get("target_instance_id", "")),
		"target_player_id": str(replay_options.get("target_player_id", "")),
		"lane_id": str(replay_options.get("lane_id", "")),
		"source_rules_text": str(action_card.get("rules_text", "")),
		"source_name": str(action_card.get("name", "")),
		"rules_tags": action_card.get("rules_tags", []).duplicate() if typeof(action_card.get("rules_tags", [])) == TYPE_ARRAY else [],
	}])
	all_events.append_array(replay_timing.get("processed_events", []))
	return {
		"is_valid": true,
		"errors": [],
		"events": all_events,
		"trigger_resolutions": sacrifice_timing.get("trigger_resolutions", []) + replay_timing.get("trigger_resolutions", []),
	}


static func append_match_win_if_needed(match_state: Dictionary, loser_player_id: String, winner_player_id: String, events: Array) -> void:
	var losing_player := MatchTimingHelpers._get_player_state(match_state, loser_player_id)
	if losing_player.is_empty() or int(losing_player.get("health", 0)) > 0:
		return
	if not str(match_state.get("winner_player_id", "")).is_empty():
		return
	# Check for on_player_health_zero triggers on support cards before declaring a winner
	_resolve_health_zero_triggers(match_state, loser_player_id, events)
	if int(losing_player.get("health", 0)) > 0:
		return
	# Check for "cannot_lose" passive (e.g. Vivec) — skip win declaration if condition is met
	if _has_cannot_lose_passive(match_state, loser_player_id):
		return
	match_state["winner_player_id"] = winner_player_id
	events.append({
		"event_type": "match_won",
		"winner_player_id": winner_player_id,
		"loser_player_id": loser_player_id,
	})


static func _resolve_health_zero_triggers(match_state: Dictionary, player_id: String, events: Array) -> void:
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return
	var supports: Array = player.get("support", [])
	for i in range(supports.size() - 1, -1, -1):
		var card = supports[i]
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var triggers = card.get("triggered_abilities", [])
		if typeof(triggers) != TYPE_ARRAY:
			continue
		for trigger in triggers:
			if typeof(trigger) != TYPE_DICTIONARY:
				continue
			if str(trigger.get("family", "")) != FAMILY_ON_PLAYER_HEALTH_ZERO:
				continue
			var instance_id := str(card.get("instance_id", ""))
			var source_controller := str(card.get("controller_player_id", player_id))
			for effect in trigger.get("effects", []):
				if typeof(effect) != TYPE_DICTIONARY:
					continue
				var op := str(effect.get("op", ""))
				match op:
					"destroy_creature":
						if str(effect.get("target", "")) == "self":
							MatchMutations.discard_card(match_state, instance_id)
							events.append({
								"event_type": EVENT_CREATURE_DESTROYED,
								"instance_id": instance_id,
								"source_instance_id": instance_id,
								"controller_player_id": source_controller,
								"reason": "sacrifice",
								"source_zone": "support",
							})
					"set_health":
						if str(effect.get("target_player", "")) == "controller":
							var amount := int(effect.get("amount", 0))
							var old_health := int(player.get("health", 0))
							player["health"] = amount
							events.append({
								"event_type": "stats_modified",
								"source_instance_id": instance_id,
								"reason": FAMILY_ON_PLAYER_HEALTH_ZERO,
							})
							if amount > old_health:
								events.append({
									"event_type": "player_healed",
									"source_instance_id": instance_id,
									"target_player_id": str(player.get("player_id", "")),
									"amount": amount - old_health,
								})
					"restore_rune":
						if str(effect.get("target_player", "")) == "controller":
							var rr_thresholds: Array = player.get("rune_thresholds", [])
							var rr_default := [25, 20, 15, 10, 5]
							var rr_count := int(effect.get("count", 1))
							for _ri in range(rr_count):
								if rr_thresholds.size() >= 5:
									break
								for rr_val in rr_default:
									if not rr_thresholds.has(rr_val):
										rr_thresholds.append(rr_val)
										rr_thresholds.sort()
										rr_thresholds.reverse()
										events.append({"event_type": "rune_restored", "source_instance_id": instance_id, "player_id": player_id, "threshold": rr_val})
										break
			# Only one on_player_health_zero trigger should fire per check
			if int(player.get("health", 0)) > 0:
				return


static func _has_cannot_lose_passive(match_state: Dictionary, player_id: String) -> bool:
	# Scan all friendly lane creatures and supports for a "cannot_lose" passive whose condition is met.
	for lane in match_state.get("lanes", []):
		var slots = lane.get("player_slots", {}).get(player_id, [])
		for card in slots:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var passives = card.get("passive_abilities", [])
			if typeof(passives) != TYPE_ARRAY:
				continue
			for p in passives:
				if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "cannot_lose":
					continue
				var condition := str(p.get("condition", ""))
				if condition == "has_exalted_creature":
					if _has_friendly_exalted_creature(match_state, player_id):
						return true
				elif condition.is_empty():
					return true
	return false


static func _has_friendly_exalted_creature(match_state: Dictionary, player_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		var slots = lane.get("player_slots", {}).get(player_id, [])
		for card in slots:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if EvergreenRules.has_status(card, EvergreenRules.STATUS_EXALTED):
				return true
	return false


static func _recheck_cannot_lose(match_state: Dictionary, player_id: String, events: Array) -> void:
	if player_id.is_empty() or not str(match_state.get("winner_player_id", "")).is_empty():
		return
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty() or int(player.get("health", 0)) > 0:
		return
	if not _has_cannot_lose_passive(match_state, player_id):
		var winner := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), player_id)
		append_match_win_if_needed(match_state, player_id, winner, events)


static func publish_events(match_state: Dictionary, events: Array, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var queue: Array = match_state["pending_event_queue"]
	for raw_event in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		queue.append(MatchTimingHelpers._normalize_event(match_state, raw_event, context))
	var processed_events: Array = []
	var trigger_resolutions: Array = []
	var _loop_guard := 0
	while not queue.is_empty():
		_loop_guard += 1
		if _loop_guard > 200:
			print("[LOOP_GUARD] publish_events iteration %d. Queue size: %d" % [_loop_guard, queue.size()])
			for _dbg_i in range(mini(5, queue.size())):
				var _dbg_evt: Dictionary = queue[_dbg_i]
				print("[LOOP_GUARD]   queued[%d]: type=%s src=%s" % [_dbg_i, str(_dbg_evt.get("event_type", "")), str(_dbg_evt.get("source_instance_id", ""))])
			if _loop_guard > 250:
				print("[LOOP_GUARD] BREAKING OUT at %d iterations." % _loop_guard)
				break
		var event: Dictionary = queue.pop_front()
		processed_events.append(event)
		MatchTimingHelpers._append_event_log(match_state, event)
		GameLogger.log_event(match_state, event)
		ExtendedMechanicPacks.observe_event(match_state, event)
		# Resummon: when a marked creature dies, queue a resummon event
		if str(event.get("event_type", "")) == EVENT_CREATURE_DESTROYED:
			var rs_instance_id := str(event.get("instance_id", ""))
			var rs_card := MatchTimingHelpers._find_card_anywhere(match_state, rs_instance_id)
			if not rs_card.is_empty() and bool(rs_card.get("_resummon_on_death", false)):
				var rs_controller := str(rs_card.get("_resummon_controller", rs_card.get("controller_player_id", "")))
				var rs_lane_id := str(event.get("lane_id", ""))
				queue.append(MatchTimingHelpers._normalize_event(match_state, {"event_type": "resummon_pending", "definition_id": str(rs_card.get("definition_id", "")), "name": str(rs_card.get("name", "")), "controller_player_id": rs_controller, "lane_id": rs_lane_id, "cost": int(rs_card.get("cost", 0)), "rules_text": str(rs_card.get("rules_text", ""))}, {}))
			# Re-check loss condition: if an exalted creature dies, a "cannot_lose" passive
			# may no longer be satisfied, so the controller at 0 HP should now lose.
			_recheck_cannot_lose(match_state, str(event.get("controller_player_id", "")), processed_events)
		# Silence can suppress exalted status, invalidating "cannot_lose" condition
		if str(event.get("event_type", "")) == "card_silenced":
			var cs_card := MatchTimingHelpers._find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
			if not cs_card.is_empty():
				_recheck_cannot_lose(match_state, str(cs_card.get("controller_player_id", "")), processed_events)
		# Process pending resummons
		if str(event.get("event_type", "")) == "resummon_pending":
			var rs_template := {"definition_id": str(event.get("definition_id", "")), "name": str(event.get("name", "")), "card_type": "creature", "power": 1, "health": 1, "base_power": 1, "base_health": 1, "cost": int(event.get("cost", 0)), "rules_text": str(event.get("rules_text", ""))}
			var rs_gen := MatchMutations.build_generated_card(match_state, str(event.get("controller_player_id", "")), rs_template)
			if not rs_gen.is_empty():
				var rs_summon := MatchMutations.summon_card_to_lane(match_state, str(event.get("controller_player_id", "")), rs_gen, str(event.get("lane_id", "")))
				if bool(rs_summon.get("is_valid", false)):
					queue.append(MatchTimingHelpers._normalize_event(match_state, {"event_type": EVENT_CREATURE_SUMMONED, "player_id": str(event.get("controller_player_id", "")), "source_instance_id": str(rs_gen.get("instance_id", "")), "source_controller_player_id": str(event.get("controller_player_id", "")), "lane_id": str(event.get("lane_id", "")), "reason": "resummon"}, {}))
		MatchTimingHelpers._append_replay_entry(match_state, {
			"entry_type": "event_processed",
			"event_id": str(event.get("event_id", "")),
			"event_type": str(event.get("event_type", "")),
			"timing_window": str(event.get("timing_window", WINDOW_AFTER)),
		})
		for trigger in MatchTriggers._find_matching_triggers(match_state, event):
			var resolution := MatchTriggers._build_trigger_resolution(match_state, trigger, event)
			trigger_resolutions.append(resolution)
			GameLogger.log_trigger_resolution(match_state, resolution, trigger)
			MatchTriggers._mark_once_trigger_if_needed(match_state, trigger)
			MatchTimingHelpers._append_replay_entry(match_state, resolution)
			for generated_event in MatchEffectApplication._apply_effects(match_state, trigger, event, resolution):
				queue.append(MatchTimingHelpers._normalize_event(match_state, generated_event, {
					"parent_event_id": str(event.get("event_id", "")),
					"produced_by_resolution_id": str(resolution.get("resolution_id", "")),
				}))
			# Yagrum's Workshop: double summon/assemble triggers for neutral cards
			if MatchTimingHelpers._should_double_summon_trigger(match_state, trigger, event):
				for generated_event in MatchEffectApplication._apply_effects(match_state, trigger, event, resolution):
					queue.append(MatchTimingHelpers._normalize_event(match_state, generated_event, {
						"parent_event_id": str(event.get("event_id", "")),
						"produced_by_resolution_id": str(resolution.get("resolution_id", "")),
					}))
		# Queue player-targeted slay triggers (e.g. Mulaamnir) after the event's
		# non-targeted slay triggers have already resolved.
		_check_slay_target_mode(match_state, event)
	MatchAuras.recalculate_auras(match_state)
	# After auras recalculate, check for creatures that should die due to lost aura health
	var combat_pending: Array = match_state.get("_combat_pending_deaths", [])
	var aura_death_events: Array = []
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size() - 1, -1, -1):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if combat_pending.has(str(card.get("instance_id", ""))):
					continue
				if EvergreenRules.get_remaining_health(card) <= 0:
					var instance_id := str(card.get("instance_id", ""))
					var destroy_result := MatchMutations.move_card_to_zone(match_state, instance_id, "discard")
					if bool(destroy_result.get("is_valid", false)):
						aura_death_events.append({
							"event_type": "creature_destroyed",
							"source_instance_id": instance_id,
							"controller_player_id": str(card.get("controller_player_id", "")),
							"reason": "aura_health_loss",
						})
	if not aura_death_events.is_empty():
		for raw_event in aura_death_events:
			queue.append(MatchTimingHelpers._normalize_event(match_state, raw_event, {}))
		while not queue.is_empty():
			var event: Dictionary = queue.pop_front()
			processed_events.append(event)
			MatchTimingHelpers._append_event_log(match_state, event)
			GameLogger.log_event(match_state, event)
			ExtendedMechanicPacks.observe_event(match_state, event)
			MatchTimingHelpers._append_replay_entry(match_state, {
				"entry_type": "event_processed",
				"event_id": str(event.get("event_id", "")),
				"event_type": str(event.get("event_type", "")),
				"timing_window": str(event.get("timing_window", WINDOW_AFTER)),
			})
			for trigger in MatchTriggers._find_matching_triggers(match_state, event):
				var resolution := MatchTriggers._build_trigger_resolution(match_state, trigger, event)
				trigger_resolutions.append(resolution)
				GameLogger.log_trigger_resolution(match_state, resolution, trigger)
				MatchTriggers._mark_once_trigger_if_needed(match_state, trigger)
				MatchTimingHelpers._append_replay_entry(match_state, resolution)
				for generated_event in MatchEffectApplication._apply_effects(match_state, trigger, event, resolution):
					queue.append(MatchTimingHelpers._normalize_event(match_state, generated_event, {
						"parent_event_id": str(event.get("event_id", "")),
						"produced_by_resolution_id": str(resolution.get("resolution_id", "")),
					}))
			_check_slay_target_mode(match_state, event)
		MatchAuras.recalculate_auras(match_state)
	var result := {
		"processed_events": processed_events,
		"trigger_resolutions": trigger_resolutions,
	}
	match_state["last_timing_result"] = result
	return result


static func _run_budget_summon_loop(match_state: Dictionary, trigger: Dictionary, controller_id: String, budget: int, summon_count: int) -> Array:
	ensure_match_state(match_state)
	var all_events: Array = []
	# Build Daedra creature candidate list from catalog
	var all_daedra: Array = []
	for seed in CardCatalog._card_seeds():
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		if not bool(seed.get("collectible", true)):
			continue
		if str(seed.get("card_type", "")) != "creature":
			continue
		var subtypes = seed.get("subtypes", [])
		if typeof(subtypes) != TYPE_ARRAY or not subtypes.has("Daedra"):
			continue
		all_daedra.append(seed)
	var source_id := str(trigger.get("source_instance_id", ""))
	while budget > 0:
		# Collect lanes with open slots
		var open_lanes: Array = []
		for lane in match_state.get("lanes", []):
			var lid := str(lane.get("lane_id", ""))
			var open_info := MatchTimingHelpers._get_lane_open_slots(match_state, lid, controller_id)
			if int(open_info.get("open_slots", 0)) > 0:
				open_lanes.append(lid)
		if open_lanes.is_empty():
			break
		# Filter candidates within budget
		var candidates: Array = []
		for d in all_daedra:
			if int(d.get("cost", 0)) <= budget:
				candidates.append(d)
		if candidates.is_empty():
			break
		# If only 1 slot left across all lanes, pick highest cost within budget; otherwise random
		var pick: Dictionary
		if open_lanes.size() == 1 and int(MatchTimingHelpers._get_lane_open_slots(match_state, open_lanes[0], controller_id).get("open_slots", 0)) == 1:
			var highest_cost := -1
			var top: Array = []
			for c in candidates:
				var c_cost := int(c.get("cost", 0))
				if c_cost > highest_cost:
					highest_cost = c_cost
					top = [c]
				elif c_cost == highest_cost:
					top.append(c)
			pick = top[MatchEffectParams._deterministic_index(match_state, source_id + "_srd_" + str(summon_count), top.size())]
		else:
			pick = candidates[MatchEffectParams._deterministic_index(match_state, source_id + "_srd_" + str(summon_count), candidates.size())]
		# Build and summon
		var template: Dictionary = pick.duplicate(true)
		template["definition_id"] = str(template.get("card_id", ""))
		var gen := MatchMutations.build_generated_card(match_state, controller_id, template)
		var summon_lane: String = str(open_lanes[MatchEffectParams._deterministic_index(match_state, source_id + "_srd_lane_" + str(summon_count), open_lanes.size())])
		var result := MatchMutations.summon_card_to_lane(match_state, controller_id, gen, summon_lane, {"source_zone": MatchMutations.ZONE_GENERATED})
		if not bool(result.get("is_valid", false)):
			break
		all_events.append_array(result.get("events", []))
		all_events.append(MatchSummonTiming._build_summon_event(result["card"], controller_id, summon_lane, int(result.get("slot_index", -1)), "summon_random_daedra_total_cost"))
		budget -= int(pick.get("cost", 0))
		summon_count += 1
		# Check for targeting summon abilities on the newly summoned creature
		var pending_before: int = match_state.get("pending_summon_effect_targets", []).size()
		_check_summon_abilities(match_state, result["card"])
		var pending_after: int = match_state.get("pending_summon_effect_targets", []).size()
		if pending_after > pending_before and budget > 0:
			# A targeting phase is needed — save remaining budget and pause the loop
			var pending_budget: Array = match_state.get("pending_budget_summons", [])
			pending_budget.append({
				"controller_id": controller_id,
				"budget": budget,
				"summon_count": summon_count,
				"source_instance_id": source_id,
			})
			break
	return all_events


## Resume any paused budget summon loops after a pending summon target is resolved/declined.
static func _resume_budget_summons_if_needed(match_state: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_budget_summons", [])
	if pending.is_empty():
		return {"events": [], "trigger_resolutions": []}
	var entry: Dictionary = pending.pop_front()
	var controller_id := str(entry.get("controller_id", ""))
	var budget := int(entry.get("budget", 0))
	var summon_count := int(entry.get("summon_count", 0))
	var source_id := str(entry.get("source_instance_id", ""))
	var synthetic_trigger := {"source_instance_id": source_id, "controller_player_id": controller_id}
	var events := _run_budget_summon_loop(match_state, synthetic_trigger, controller_id, budget, summon_count)
	if events.is_empty():
		return {"events": [], "trigger_resolutions": []}
	var timing_result := publish_events(match_state, events)
	return {"events": timing_result.get("processed_events", []), "trigger_resolutions": timing_result.get("trigger_resolutions", [])}


static func _resume_pending_rune_breaks(match_state: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var result := {
		"events": [],
		"broken_runes": [],
		"player_lost": false,
		"pending_prophecy_opened": false,
	}
	var queue: Array = match_state.get("pending_rune_break_queue", [])
	while not queue.is_empty() and not has_pending_prophecy(match_state):
		var entry: Dictionary = queue[0]
		queue.remove_at(0)
		var player_id := str(entry.get("player_id", ""))
		var player := MatchTimingHelpers._get_player_state(match_state, player_id)
		if player.is_empty():
			continue
		var threshold := int(entry.get("threshold", -1))
		var thresholds: Array = player.get("rune_thresholds", [])
		var threshold_index := -1
		for i in range(thresholds.size()):
			if int(thresholds[i]) == threshold:
				threshold_index = i
				break
		if threshold_index == -1:
			continue
		thresholds.remove_at(threshold_index)
		player["rune_thresholds"] = thresholds
		result["broken_runes"].append(threshold)
		result["events"].append({
			"event_type": EVENT_RUNE_BROKEN,
			"player_id": player_id,
			"threshold": threshold,
			"source_instance_id": str(entry.get("source_instance_id", "")),
			"source_controller_player_id": str(entry.get("source_controller_player_id", "")),
			"causing_player_id": str(entry.get("causing_player_id", entry.get("source_controller_player_id", ""))),
			"reason": str(entry.get("reason", "damage")),
			"draw_card": true,
			"timing_window": str(entry.get("timing_window", WINDOW_INTERRUPT)),
		})
		# Prophet's Sight boon: intercept rune break draw with a 3-card choice
		var ps_boon_pid := str(match_state.get("_boon_player_id", ""))
		if ps_boon_pid == player_id:
			var ps_active_boons = match_state.get("_adventure_boons", [])
			if typeof(ps_active_boons) == TYPE_ARRAY and "prophets_sight" in ps_active_boons:
				var ps_deck: Array = player.get(ZONE_DECK, [])
				var ps_count := mini(3, ps_deck.size())
				if ps_count > 0:
					var ps_cards: Array = []
					for _ps_i in range(ps_count):
						ps_cards.append(ps_deck.pop_back())
					match_state["pending_top_deck_choices"].append({
						"player_id": player_id,
						"source_instance_id": "boon_prophets_sight",
						"cards": ps_cards,
						"mode": "draw_one_shuffle_rest",
						"prompt": "Prophet's Sight: Choose a card to draw.",
						"context": "prophets_sight",
					})
					result["pending_prophecy_opened"] = true
					break
		var draw_result := draw_cards(match_state, player_id, 1, {
			"reason": EVENT_RUNE_BROKEN,
			"source_instance_id": str(entry.get("source_instance_id", "")),
			"source_controller_player_id": str(entry.get("source_controller_player_id", "")),
			"allow_prophecy_interrupt": true,
			"timing_window": str(entry.get("timing_window", WINDOW_INTERRUPT)),
			"rune_threshold": threshold,
		})
		result["events"].append_array(draw_result.get("events", []))
		if bool(draw_result.get("player_lost", false)):
			result["player_lost"] = true
			break
		if bool(draw_result.get("pending_prophecy_opened", false)):
			result["pending_prophecy_opened"] = true
			break
	match_state["pending_rune_break_queue"] = queue
	return result


static func _resolve_out_of_cards(match_state: Dictionary, player_id: String, context: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var player := MatchTimingHelpers._get_player_state(match_state, player_id)
	if player.is_empty():
		return {"events": [], "player_lost": false}
	var out_of_cards_card := _build_out_of_cards_card(match_state, player_id)
	player[ZONE_DISCARD].append(out_of_cards_card)
	var out_of_cards_event := {
		"event_type": EVENT_OUT_OF_CARDS_PLAYED,
		"player_id": player_id,
		"source_instance_id": str(out_of_cards_card.get("instance_id", "")),
		"source_zone": ZONE_GENERATED,
		"target_zone": ZONE_DISCARD,
		"reason": RULE_TAG_OUT_OF_CARDS,
		"timing_window": str(context.get("timing_window", WINDOW_IMMEDIATE)),
	}
	var rune_result := destroy_front_rune(match_state, player_id, {
		"reason": RULE_TAG_OUT_OF_CARDS,
		"source_instance_id": str(out_of_cards_card.get("instance_id", "")),
		"source_controller_player_id": player_id,
		"causing_player_id": player_id,
		"timing_window": str(context.get("timing_window", WINDOW_IMMEDIATE)),
	})
	if int(rune_result.get("destroyed_threshold", -1)) > 0:
		out_of_cards_event["destroyed_threshold"] = int(rune_result.get("destroyed_threshold", -1))
		out_of_cards_event["resulting_health"] = int(MatchTimingHelpers._get_player_state(match_state, player_id).get("health", 0))
	var events: Array = [out_of_cards_event]
	events.append_array(rune_result.get("events", []))
	return {
		"events": events,
		"player_lost": bool(rune_result.get("player_lost", false)),
		"card": out_of_cards_card,
	}


static func _can_open_prophecy_window(match_state: Dictionary, player_id: String, card: Dictionary) -> bool:
	if str(match_state.get("active_player_id", "")) == player_id:
		return false
	return MatchTimingHelpers._is_prophecy_card(card)


static func _open_prophecy_window(match_state: Dictionary, player_id: String, card: Dictionary, context: Dictionary) -> Dictionary:
	var windows: Array = match_state.get("pending_prophecy_windows", [])
	windows.append({
		"player_id": player_id,
		"instance_id": str(card.get("instance_id", "")),
		"source_instance_id": str(context.get("source_instance_id", "")),
		"rune_threshold": int(context.get("rune_threshold", -1)),
		"opened_during_player_id": str(match_state.get("active_player_id", "")),
		"card_type": str(card.get("card_type", "")),
	})
	match_state["pending_prophecy_windows"] = windows
	return {
		"event_type": EVENT_PROPHECY_WINDOW_OPENED,
		"player_id": player_id,
		"source_instance_id": str(context.get("source_instance_id", "")),
		"drawn_instance_id": str(card.get("instance_id", "")),
		"card_type": str(card.get("card_type", "")),
		"reason": RULE_TAG_PROPHECY,
		"free_play": true,
		"rune_threshold": int(context.get("rune_threshold", -1)),
		"timing_window": str(context.get("timing_window", WINDOW_INTERRUPT)),
	}


static func _find_pending_prophecy_window_index(match_state: Dictionary, player_id: String, instance_id: String) -> int:
	var windows: Array = match_state.get("pending_prophecy_windows", [])
	for index in range(windows.size()):
		var window = windows[index]
		if typeof(window) != TYPE_DICTIONARY:
			continue
		if str(window.get("player_id", "")) == player_id and str(window.get("instance_id", "")) == instance_id:
			return index
	return -1


static func _consume_pending_prophecy_window(match_state: Dictionary, index: int) -> Dictionary:
	var windows: Array = match_state.get("pending_prophecy_windows", [])
	if index < 0 or index >= windows.size():
		return {}
	var window = windows[index]
	windows.remove_at(index)
	match_state["pending_prophecy_windows"] = windows
	return window if typeof(window) == TYPE_DICTIONARY else {}


static func _build_out_of_cards_card(match_state: Dictionary, player_id: String) -> Dictionary:
	match_state["out_of_cards_sequence"] = int(match_state.get("out_of_cards_sequence", 0)) + 1
	return {
		"instance_id": "%s_out_of_cards_%03d" % [player_id, int(match_state.get("out_of_cards_sequence", 0))],
		"definition_id": "out_of_cards",
		"name": "Out of Cards",
		"controller_player_id": player_id,
		"owner_player_id": player_id,
		"card_type": "special",
		"cost": 0,
		"zone": ZONE_DISCARD,
		"rules_tags": [RULE_TAG_OUT_OF_CARDS],
		"generated_by_rules": true,
	}


static func _fire_wax_wane_on_other_friendly(match_state: Dictionary, controller_id: String, exclude_instance_id: String, family: String) -> Array:
	# Prevent re-entrant trigger_wax/trigger_wane from causing infinite loops
	# (e.g. two Rebellion Generals triggering each other)
	var active_set: Array = match_state.get("_active_forced_wax_wane", [])
	if active_set.has(exclude_instance_id):
		return []
	active_set.append(exclude_instance_id)
	match_state["_active_forced_wax_wane"] = active_set
	var generated_events: Array = []
	var synthetic_event := {
		"event_type": EVENT_CREATURE_SUMMONED,
		"player_id": controller_id,
		"source_controller_player_id": controller_id,
		"reason": "trigger_%s" % family,
	}
	for lane in match_state.get("lanes", []):
		var lane_index := int(lane.get("lane_index", 0))
		var slots: Array = lane.get("player_slots", {}).get(controller_id, [])
		for slot_index in range(slots.size()):
			var card = slots[slot_index]
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var card_id := str(card.get("instance_id", ""))
			if card_id == exclude_instance_id or active_set.has(card_id):
				continue
			var abilities = card.get("triggered_abilities", [])
			if typeof(abilities) != TYPE_ARRAY:
				continue
			for trigger_index in range(abilities.size()):
				var descriptor = abilities[trigger_index]
				if typeof(descriptor) != TYPE_DICTIONARY:
					continue
				if str(descriptor.get("family", "")) != family:
					continue
				if not bool(descriptor.get("enabled", true)):
					continue
				if descriptor.has("required_zone") and str(descriptor.get("required_zone", "")) != ZONE_LANE:
					continue
				if not str(descriptor.get("target_mode", "")).is_empty():
					continue  # Target-mode triggers need pending selection; skip here
				var instance_id := str(card.get("instance_id", ""))
				var synthetic_trigger := {
					"trigger_id": "%s_forced_%s_%d" % [instance_id, family, trigger_index],
					"trigger_index": trigger_index,
					"source_instance_id": instance_id,
					"owner_player_id": str(card.get("owner_player_id", controller_id)),
					"controller_player_id": str(card.get("controller_player_id", controller_id)),
					"source_zone": ZONE_LANE,
					"lane_index": lane_index,
					"slot_index": slot_index,
					"descriptor": descriptor.duplicate(true),
				}
				var resolution := MatchTriggers._build_trigger_resolution(match_state, synthetic_trigger, synthetic_event)
				generated_events.append_array(MatchEffectApplication._apply_effects(match_state, synthetic_trigger, synthetic_event, resolution))
	active_set.erase(exclude_instance_id)
	if active_set.is_empty():
		match_state.erase("_active_forced_wax_wane")
	return generated_events


static func process_end_of_turn_returns(match_state: Dictionary, turn_number: int) -> void:
	var pending: Array = match_state.get("pending_eot_returns", [])
	var remaining: Array = []
	var events: Array = []
	for entry in pending:
		if int(entry.get("turn_number", -1)) != turn_number:
			remaining.append(entry)
			continue
		var snapshot: Dictionary = entry.get("card_snapshot", {})
		var controller_id := str(entry.get("controller_player_id", ""))
		var lane_id := str(entry.get("lane_id", ""))
		if snapshot.is_empty() or controller_id.is_empty() or lane_id.is_empty():
			continue
		var template := {
			"definition_id": str(snapshot.get("definition_id", "")),
			"name": str(snapshot.get("name", "")),
			"card_type": str(snapshot.get("card_type", "creature")),
			"subtypes": snapshot.get("subtypes", []),
			"attributes": snapshot.get("attributes", []),
			"cost": int(snapshot.get("cost", 0)),
			"power": int(snapshot.get("base_power", snapshot.get("power", 0))),
			"health": int(snapshot.get("base_health", snapshot.get("health", 0))),
			"base_power": int(snapshot.get("base_power", 0)),
			"base_health": int(snapshot.get("base_health", 0)),
			"keywords": snapshot.get("keywords", []),
			"rules_text": str(snapshot.get("rules_text", "")),
		}
		if snapshot.has("triggered_abilities"):
			template["triggered_abilities"] = snapshot["triggered_abilities"]
		if snapshot.has("aura"):
			template["aura"] = snapshot["aura"]
		var generated_card := MatchMutations.build_generated_card(match_state, controller_id, template)
		var summon_result := MatchMutations.summon_card_to_lane(match_state, controller_id, generated_card, lane_id, {
			"source_zone": MatchMutations.ZONE_GENERATED,
		})
		if bool(summon_result.get("is_valid", false)):
			events.append_array(summon_result.get("events", []))
			events.append(MatchSummonTiming._build_summon_event(summon_result["card"], controller_id, lane_id, int(summon_result.get("slot_index", -1)), "end_of_turn_return"))
	match_state["pending_eot_returns"] = remaining
	if not events.is_empty():
		publish_events(match_state, events)
	# Destroy creatures marked with _destroy_at_end_of_turn
	var destroy_events: Array = []
	for lane in match_state.get("lanes", []):
		for player_slots in lane.get("player_slots", {}).values():
			var cards_to_destroy: Array = []
			for card in player_slots:
				if typeof(card) == TYPE_DICTIONARY and card.has("_destroy_at_end_of_turn") and int(card.get("_destroy_at_end_of_turn", -1)) == turn_number:
					cards_to_destroy.append(card)
			for card in cards_to_destroy:
				var d_lane_id := str(lane.get("lane_id", ""))
				var d_result := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")), {"reason": "end_of_turn_destruction"})
				destroy_events.append({
					"event_type": EVENT_CREATURE_DESTROYED,
					"instance_id": str(card.get("instance_id", "")),
					"controller_player_id": str(card.get("controller_player_id", "")),
					"lane_id": d_lane_id,
				})
				destroy_events.append_array(d_result.get("events", []))
	if not destroy_events.is_empty():
		publish_events(match_state, destroy_events)
	# Unsummon creatures scheduled via unsummon_end_of_turn
	var unsummon_pending: Array = match_state.get("pending_end_of_turn_unsummons", [])
	if not unsummon_pending.is_empty():
		var unsummon_events: Array = []
		for instance_id in unsummon_pending:
			var u_result := MatchMutations.unsummon_card(match_state, str(instance_id))
			unsummon_events.append_array(u_result.get("events", []))
		match_state["pending_end_of_turn_unsummons"] = []
		if not unsummon_events.is_empty():
			publish_events(match_state, unsummon_events)
	# Move back creatures scheduled via move_back_end_of_turn
	var move_back_pending: Array = match_state.get("pending_move_backs", [])
	if not move_back_pending.is_empty():
		var move_back_events: Array = []
		for instance_id in move_back_pending:
			var mb_card := MatchTimingHelpers._find_card_anywhere(match_state, str(instance_id))
			if mb_card.is_empty():
				continue
			var mb_controller := str(mb_card.get("controller_player_id", ""))
			var mb_loc := MatchMutations.find_card_location(match_state, str(instance_id))
			var mb_current_lane := str(mb_loc.get("lane_id", ""))
			var mb_target_lane := "shadow" if mb_current_lane == "field" else "field"
			var mb_result := MatchMutations.move_card_between_lanes(match_state, mb_controller, str(instance_id), mb_target_lane)
			if bool(mb_result.get("is_valid", false)):
				move_back_events.append_array(mb_result.get("events", []))
		match_state["pending_move_backs"] = []
		if not move_back_events.is_empty():
			publish_events(match_state, move_back_events)
	# Discard hands scheduled via discard_hand_end_of_turn
	var discard_pending: Array = match_state.get("pending_end_of_turn_discards", [])
	if not discard_pending.is_empty():
		var discard_events: Array = []
		for player_id in discard_pending:
			var dh_player := MatchTimingHelpers._get_player_state(match_state, str(player_id))
			if dh_player.is_empty():
				continue
			var dh_hand: Array = dh_player.get(ZONE_HAND, [])
			var dh_discard: Array = dh_player.get(ZONE_DISCARD, [])
			for card in dh_hand:
				if typeof(card) == TYPE_DICTIONARY:
					card["zone"] = ZONE_DISCARD
					dh_discard.append(card)
					discard_events.append({"event_type": "card_discarded", "player_id": str(player_id), "instance_id": str(card.get("instance_id", "")), "source": "discard_hand_end_of_turn", "reason": "end_of_turn"})
			dh_hand.clear()
		match_state["pending_end_of_turn_discards"] = []
		if not discard_events.is_empty():
			publish_events(match_state, discard_events)
	# Return-to-deck creatures scheduled via _return_to_deck_end_of_turn flag
	var rtd_cards_to_return: Array = []
	for rtd_lane in match_state.get("lanes", []):
		for rtd_pid in rtd_lane.get("player_slots", {}).keys():
			for rtd_card in rtd_lane.get("player_slots", {}).get(rtd_pid, []):
				if typeof(rtd_card) == TYPE_DICTIONARY and bool(rtd_card.get("_return_to_deck_end_of_turn", false)):
					rtd_cards_to_return.append({"instance_id": str(rtd_card.get("instance_id", "")), "player_id": rtd_pid})
	if not rtd_cards_to_return.is_empty():
		var rtd_events: Array = []
		for rtd_entry in rtd_cards_to_return:
			var rtd_loc := MatchMutations.find_card_location(match_state, rtd_entry["instance_id"])
			if not bool(rtd_loc.get("is_valid", false)):
				continue
			var rtd_card: Dictionary = rtd_loc["card"]
			var rtd_lane_slots: Array = rtd_loc.get("player_slots", [])
			rtd_lane_slots.erase(rtd_card)
			rtd_card.erase("_return_to_deck_end_of_turn")
			rtd_card["zone"] = ZONE_DECK
			MatchMutations.restore_definition_state(rtd_card)
			var rtd_player := MatchTimingHelpers._get_player_state(match_state, rtd_entry["player_id"])
			if not rtd_player.is_empty():
				rtd_player.get(ZONE_DECK, []).append(rtd_card)
				rtd_events.append({"event_type": "card_moved", "instance_id": rtd_entry["instance_id"], "source_zone": "lane", "target_zone": ZONE_DECK, "reason": "return_to_deck_end_of_turn"})
		if not rtd_events.is_empty():
			publish_events(match_state, rtd_events)


# --- Facade delegations for functions called externally by class_name ---

static func _deterministic_index(match_state: Dictionary, context_id: String, pool_size: int) -> int:
	return MatchEffectParams._deterministic_index(match_state, context_id, pool_size)

static func _get_empower_amount(match_state: Dictionary, controller_player_id: String) -> int:
	return MatchTimingHelpers._get_empower_amount(match_state, controller_player_id)

static func _get_heal_multiplier(match_state: Dictionary, player_id: String) -> int:
	return MatchTimingHelpers._get_heal_multiplier(match_state, player_id)

static func get_target_mode_abilities(card: Dictionary) -> Array:
	return MatchTargeting.get_target_mode_abilities(card)

static func get_valid_targets_for_mode(match_state: Dictionary, source_instance_id: String, target_mode: String, trigger: Dictionary = {}) -> Array:
	return MatchTargeting.get_valid_targets_for_mode(match_state, source_instance_id, target_mode, trigger)

static func get_all_valid_targets(match_state: Dictionary, source_instance_id: String) -> Array:
	return MatchTargeting.get_all_valid_targets(match_state, source_instance_id)

static func _apply_effects(match_state: Dictionary, trigger: Dictionary, event: Dictionary, resolution: Dictionary) -> Array:
	return MatchEffectApplication._apply_effects(match_state, trigger, event, resolution)

static func _build_summon_event(card: Dictionary, player_id: String, lane_id: String, slot_index: int, reason: String) -> Dictionary:
	return MatchSummonTiming._build_summon_event(card, player_id, lane_id, slot_index, reason)

static func _resolve_card_targets(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	return MatchTargeting._resolve_card_targets(match_state, trigger, event, effect)

static func _resolve_card_targets_by_name(match_state: Dictionary, trigger: Dictionary, event: Dictionary, target: String) -> Array:
	return MatchTargeting._resolve_card_targets_by_name(match_state, trigger, event, target)

static func _build_trigger_resolution(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Dictionary:
	return MatchTriggers._build_trigger_resolution(match_state, trigger, event)
