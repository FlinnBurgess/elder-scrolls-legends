class_name MatchTiming
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")

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
	FAMILY_ON_DAMAGE: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "either"},
	FAMILY_ON_DEATH: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "subject"},
	FAMILY_LAST_GASP: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "subject"},
	FAMILY_SLAY: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "killer"},
	FAMILY_PILFER: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "source", "target_type": "player", "min_amount": 1},
	FAMILY_VETERAN: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "target", "damage_kind": "combat", "require_retaliation": true, "require_survived": true},
	FAMILY_EXPERTISE: {"event_type": EVENT_TURN_ENDING, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_PLOT: {"event_type": EVENT_TURN_ENDING, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_RUNE_BREAK: {"event_type": EVENT_RUNE_BROKEN, "window": WINDOW_INTERRUPT, "match_role": "controller"},
	FAMILY_ON_FRIENDLY_DEATH: {"event_type": EVENT_CREATURE_DESTROYED, "window": WINDOW_AFTER, "match_role": "controller"},
	FAMILY_ON_ATTACK: {"event_type": EVENT_DAMAGE_RESOLVED, "window": WINDOW_AFTER, "match_role": "source", "damage_kind": "combat", "exclude_retaliation": true},
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
	FAMILY_ON_KEYWORD_GAINED: {"event_type": "keyword_granted", "window": WINDOW_AFTER, "match_role": "any_player"},
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


static func get_target_mode_abilities(card: Dictionary) -> Array:
	var abilities: Array = []
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY:
		return abilities
	for trigger in raw_triggers:
		if typeof(trigger) == TYPE_DICTIONARY and not str(trigger.get("target_mode", "")).is_empty():
			abilities.append(trigger)
	return abilities


static func get_valid_targets_for_mode(match_state: Dictionary, source_instance_id: String, target_mode: String, trigger: Dictionary = {}) -> Array:
	var source_card := _find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return []
	var controller_id := str(source_card.get("controller_player_id", ""))
	var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
	var source_lane_index := _get_card_lane_index(match_state, source_instance_id)
	var targets: Array = []
	match target_mode:
		"any_creature":
			targets = _all_lane_creatures(match_state)
		"another_creature":
			targets = _all_lane_creatures(match_state)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"enemy_creature":
			targets = _player_lane_creatures(match_state, opponent_id)
		"friendly_creature":
			targets = _player_lane_creatures(match_state, controller_id)
		"another_friendly_creature":
			targets = _player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"another_friendly_creature_in_lane":
			if source_lane_index >= 0:
				targets = _lane_creatures_for_player(match_state, source_lane_index, controller_id)
				targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"creature_or_player":
			targets = _all_lane_creatures(match_state)
			targets.append({"player_id": opponent_id})
		"enemy_creature_in_lane":
			if source_lane_index >= 0:
				targets = _lane_creatures_for_player(match_state, source_lane_index, opponent_id)
		"any_creature_in_lane":
			if source_lane_index >= 0:
				targets = _lane_creatures_at(match_state, source_lane_index)
				targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"creature_less_power_than_self":
			var self_power := EvergreenRules.get_power(source_card)
			targets = _all_lane_creatures(match_state)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id and EvergreenRules.get_power(c) < self_power)
		"creature_in_lane_less_power":
			var self_power_cilp := EvergreenRules.get_power(source_card)
			if source_lane_index >= 0:
				targets = _lane_creatures_at(match_state, source_lane_index)
				targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id and EvergreenRules.get_power(c) < self_power_cilp)
		"another_neutral_creature":
			targets = _all_lane_creatures(match_state)
			targets = targets.filter(func(c):
				if str(c.get("instance_id", "")) == source_instance_id:
					return false
				var attrs = c.get("attributes", [])
				return typeof(attrs) == TYPE_ARRAY and attrs.has("neutral"))
		"enemy_creature_2_power_or_less":
			targets = _player_lane_creatures(match_state, opponent_id)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) <= 2)
		"friendly_creature_5_power":
			targets = _player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id and EvergreenRules.get_power(c) >= 5)
		"friendly_discard_creature_less_power":
			var self_power_fdclp := EvergreenRules.get_power(source_card)
			for player in match_state.get("players", []):
				if str(player.get("player_id", "")) != controller_id:
					continue
				for card in player.get("discard", []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature" and EvergreenRules.get_power(card) < self_power_fdclp:
						targets.append(card)
		"wounded_enemy_creature":
			targets = _player_lane_creatures(match_state, opponent_id)
			targets = targets.filter(func(c): return EvergreenRules.has_status(c, EvergreenRules.STATUS_WOUNDED))
		"enemy_support":
			for player in match_state.get("players", []):
				if typeof(player) != TYPE_DICTIONARY or str(player.get("player_id", "")) != opponent_id:
					continue
				for card in player.get("support", []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"enemy_creature_or_support":
			targets = _player_lane_creatures(match_state, opponent_id)
			for player in match_state.get("players", []):
				if typeof(player) != TYPE_DICTIONARY or str(player.get("player_id", "")) != opponent_id:
					continue
				for card in player.get("support", []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"creature_1_power_or_less":
			var c1pol_max := 1
			var c1pol_empower := int(source_card.get("_empower_target_bonus", 0))
			if c1pol_empower > 0:
				c1pol_max += c1pol_empower * _get_empower_amount(match_state, controller_id)
			targets = _all_lane_creatures(match_state)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) <= c1pol_max)
		"creature_4_power_or_less":
			targets = _all_lane_creatures(match_state)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) <= 4)
		"creature_4_power_or_more":
			targets = _all_lane_creatures(match_state)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) >= 4)
		"creature_with_0_power":
			targets = _all_lane_creatures(match_state)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) == 0)
		"enemy_creature_3_power_or_less":
			targets = _player_lane_creatures(match_state, opponent_id)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) <= 3)
		"creature_in_other_lane":
			var other_lane_index := -1
			for li in range(match_state.get("lanes", []).size()):
				if li != source_lane_index:
					other_lane_index = li
					break
			if other_lane_index >= 0:
				targets = _lane_creatures_at(match_state, other_lane_index)
		"friendly_creature_without_guard":
			targets = _player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return not EvergreenRules.has_keyword(c, EvergreenRules.KEYWORD_GUARD))
		"enemy_creature_optional":
			targets = _player_lane_creatures(match_state, opponent_id)
		"another_friendly_creature_optional":
			targets = _player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c): return str(c.get("instance_id", "")) != source_instance_id)
		"any_creature_or_player":
			targets = _all_lane_creatures(match_state)
			targets.append({"player_id": controller_id})
			targets.append({"player_id": opponent_id})
		"enemy_creature_less_power_than_self_health":
			var self_health_eclptsh := int(source_card.get("health", 0))
			targets = _player_lane_creatures(match_state, opponent_id)
			targets = targets.filter(func(c): return EvergreenRules.get_power(c) < self_health_eclptsh)
		"two_creatures", "three_creatures":
			targets = _all_lane_creatures(match_state)
		"creature_in_hand":
			var cih_player := _get_player_state(match_state, controller_id)
			if not cih_player.is_empty():
				for card in cih_player.get(ZONE_HAND, []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						targets.append(card)
		"opponent_discard_card":
			var odc_opponent := _get_player_state(match_state, opponent_id)
			if not odc_opponent.is_empty():
				for card in odc_opponent.get(ZONE_DISCARD, []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"choose_lane_and_owner":
			# Return both player IDs as targets — UI will present lane selection
			targets.append({"player_id": controller_id})
			targets.append({"player_id": opponent_id})
		"friendly_creature_with_3_items":
			targets = _player_lane_creatures(match_state, controller_id)
			targets = targets.filter(func(c):
				var items = c.get("attached_items", [])
				return typeof(items) == TYPE_ARRAY and items.size() >= 3)
		"enemy_creature_and_friendly_creature":
			# Return all creatures — UI handles the two-step pick
			targets = _all_lane_creatures(match_state)
	# Apply additional filters from trigger descriptor
	var max_power := int(trigger.get("target_filter_max_power", -1))
	if max_power >= 0:
		targets = targets.filter(func(c): return c.has("instance_id") and EvergreenRules.get_power(c) <= max_power)
	if bool(trigger.get("target_filter_wounded", false)):
		targets = targets.filter(func(c): return c.has("instance_id") and EvergreenRules.has_status(c, EvergreenRules.STATUS_WOUNDED))
	if bool(trigger.get("required_friendly_higher_power", false)):
		var max_friendly_power := 0
		for lane in match_state.get("lanes", []):
			for card in lane.get("player_slots", {}).get(controller_id, []):
				if typeof(card) == TYPE_DICTIONARY:
					var p := EvergreenRules.get_power(card)
					if p > max_friendly_power:
						max_friendly_power = p
		targets = targets.filter(func(c): return c.has("instance_id") and EvergreenRules.get_power(c) < max_friendly_power)
	# Filter out creatures immune to action targeting (e.g. Iron Atronach, Nahagliiv)
	if str(source_card.get("card_type", "")) == "action":
		targets = targets.filter(func(c):
			if not c.has("instance_id"):
				return true
			var immunities = c.get("self_immunity", [])
			if typeof(immunities) != TYPE_ARRAY or not immunities.has("action_targeting"):
				return true
			return str(c.get("controller_player_id", "")) == controller_id
		)
		# protect_friendly_from_actions: if opponent has a creature with this passive,
		# we can't target their other creatures with actions
		var protectors: Dictionary = {}
		for lane in match_state.get("lanes", []):
			for pid in lane.get("player_slots", {}).keys():
				if pid == controller_id:
					continue
				for card in lane.get("player_slots", {}).get(pid, []):
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "protect_friendly_from_actions"):
						protectors[pid] = str(card.get("instance_id", ""))
		if not protectors.is_empty():
			targets = targets.filter(func(c):
				if not c.has("instance_id"):
					return true
				var c_controller := str(c.get("controller_player_id", ""))
				if not protectors.has(c_controller):
					return true
				return str(c.get("instance_id", "")) == protectors[c_controller]
			)
		# action_immune_conditional: creature immune to opponent actions when condition met
		targets = targets.filter(func(c):
			if not c.has("instance_id"):
				return true
			if str(c.get("controller_player_id", "")) == controller_id:
				return true  # Own creatures are always targetable
			if not EvergreenRules._has_passive(c, "action_immune_conditional"):
				return true
			var aic_passives = c.get("passive_abilities", [])
			if typeof(aic_passives) != TYPE_ARRAY:
				return true
			for p in aic_passives:
				if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "action_immune_conditional":
					continue
				var aic_cond := str(p.get("condition", ""))
				if aic_cond == "creature_in_each_lane":
					var aic_controller := str(c.get("controller_player_id", ""))
					var aic_has_in_each := true
					for aic_lane in match_state.get("lanes", []):
						var aic_slots: Array = aic_lane.get("player_slots", {}).get(aic_controller, [])
						if aic_slots.is_empty():
							aic_has_in_each = false
							break
					if aic_has_in_each:
						return false  # Condition met, immune
			return true
		)
		# action_immune status: opponent's actions cannot target this creature
		targets = targets.filter(func(c):
			if not c.has("instance_id"):
				return true
			if str(c.get("controller_player_id", "")) == controller_id:
				return true
			return not EvergreenRules.has_raw_status(c, "action_immune")
		)
	# Convert to target info format
	var result: Array = []
	for t in targets:
		if t.has("player_id"):
			result.append({"player_id": str(t.get("player_id", ""))})
		elif t.has("instance_id"):
			result.append({"instance_id": str(t.get("instance_id", ""))})
	return result


static func get_all_valid_targets(match_state: Dictionary, source_instance_id: String) -> Array:
	var source_card := _find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return []
	var all_targets: Array = []
	var seen_ids: Dictionary = {}
	for ability in get_target_mode_abilities(source_card):
		var mode := str(ability.get("target_mode", ""))
		for target_info in get_valid_targets_for_mode(match_state, source_instance_id, mode, ability):
			var key := str(target_info.get("instance_id", target_info.get("player_id", "")))
			if not seen_ids.has(key):
				seen_ids[key] = true
				all_targets.append(target_info)
	return all_targets


static func resolve_targeted_effect(match_state: Dictionary, source_instance_id: String, target_info: Dictionary) -> Dictionary:
	ensure_match_state(match_state)
	var source_card := _find_card_anywhere(match_state, source_instance_id)
	if source_card.is_empty():
		return {"is_valid": false, "errors": ["Source card not found."], "events": [], "trigger_resolutions": []}
	var abilities := get_target_mode_abilities(source_card)
	if abilities.is_empty():
		return {"is_valid": false, "errors": ["No target_mode abilities on card."], "events": [], "trigger_resolutions": []}
	# Determine which ability matches the chosen target
	var chosen_instance_id := str(target_info.get("target_instance_id", ""))
	var chosen_player_id := str(target_info.get("target_player_id", ""))
	var matching_ability: Dictionary = {}
	if not chosen_instance_id.is_empty():
		for ability in abilities:
			var valid := get_valid_targets_for_mode(match_state, source_instance_id, str(ability.get("target_mode", "")), ability)
			for v in valid:
				if str(v.get("instance_id", "")) == chosen_instance_id:
					matching_ability = ability
					break
			if not matching_ability.is_empty():
				break
	elif not chosen_player_id.is_empty():
		for ability in abilities:
			var valid := get_valid_targets_for_mode(match_state, source_instance_id, str(ability.get("target_mode", "")), ability)
			for v in valid:
				if str(v.get("player_id", "")) == chosen_player_id:
					matching_ability = ability
					break
			if not matching_ability.is_empty():
				break
	if matching_ability.is_empty():
		return {"is_valid": false, "errors": ["No matching ability for chosen target."], "events": [], "trigger_resolutions": []}
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
	var resolution := _build_trigger_resolution(match_state, trigger, event)
	GameLogger.log_trigger_resolution(match_state, resolution, trigger)
	# Apply effects
	var generated_events := _apply_effects(match_state, trigger, event, resolution)
	# Publish any generated events (cascading effects)
	var timing_result := publish_events(match_state, generated_events, {
		"parent_event_id": "targeted_effect_%s" % source_instance_id,
	})
	var all_events: Array = generated_events + timing_result.get("processed_events", [])
	var all_resolutions: Array = [resolution] + timing_result.get("trigger_resolutions", [])
	return {"is_valid": true, "events": all_events, "trigger_resolutions": all_resolutions}


# --- Target choice helpers ---


static func _get_card_lane_index(match_state: Dictionary, instance_id: String) -> int:
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
		for pid in player_slots.keys():
			for card in player_slots[pid]:
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return lane_index
	return -1


static func _all_lane_creatures(match_state: Dictionary) -> Array:
	var creatures: Array = []
	for lane in match_state.get("lanes", []):
		var player_slots: Dictionary = lane.get("player_slots", {})
		for pid in player_slots.keys():
			for card in player_slots[pid]:
				if typeof(card) == TYPE_DICTIONARY:
					creatures.append(card)
	return creatures


static func _player_lane_creatures(match_state: Dictionary, player_id: String) -> Array:
	var creatures: Array = []
	for lane in match_state.get("lanes", []):
		var slots = lane.get("player_slots", {}).get(player_id, [])
		for card in slots:
			if typeof(card) == TYPE_DICTIONARY:
				creatures.append(card)
	return creatures


static func _lane_creatures_for_player(match_state: Dictionary, lane_index: int, player_id: String) -> Array:
	var creatures: Array = []
	var lanes: Array = match_state.get("lanes", [])
	if lane_index >= 0 and lane_index < lanes.size():
		var slots = lanes[lane_index].get("player_slots", {}).get(player_id, [])
		for card in slots:
			if typeof(card) == TYPE_DICTIONARY:
				creatures.append(card)
	return creatures


static func _lane_creatures_at(match_state: Dictionary, lane_index: int) -> Array:
	var creatures: Array = []
	var lanes: Array = match_state.get("lanes", [])
	if lane_index >= 0 and lane_index < lanes.size():
		var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
		for pid in player_slots.keys():
			for card in player_slots[pid]:
				if typeof(card) == TYPE_DICTIONARY:
					creatures.append(card)
	return creatures


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
	var discard_player := _get_player_state(match_state, player_id)
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
	var hand_player := _get_player_state(match_state, player_id)
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
		var top_deck_player := _get_player_state(match_state, player_id)
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
	var player := _get_player_state(match_state, player_id)
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
		var opponent_id := _get_opposing_player_id(match_state.get("players", []), player_id)
		var opponent := _get_player_state(match_state, opponent_id)
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
	events.append_array(_apply_effects(match_state, patched_trigger, event, {}))
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
	var source := _find_card_anywhere(match_state, source_id)
	var events: Array = []
	var defender := _find_card_anywhere(match_state, target_instance_id)
	if not defender.is_empty():
		var result := EvergreenRules.apply_damage_to_creature(defender, damage_amount)
		events.append({"event_type": "damage_resolved", "source_instance_id": source_id, "source_controller_player_id": str(source.get("controller_player_id", "")), "target_instance_id": target_instance_id, "target_type": "creature", "amount": int(result.get("applied", 0)), "damage_kind": "ability"})
		if EvergreenRules.is_creature_destroyed(defender, false):
			var moved := MatchMutations.discard_card(match_state, target_instance_id)
			if bool(moved.get("is_valid", false)):
				events.append({"event_type": "creature_destroyed", "instance_id": target_instance_id, "reason": "deal_damage_from_creature"})
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
	return resolve_targeted_effect(match_state, source_id, target_info)


static func decline_pending_summon_effect_target(match_state: Dictionary, player_id: String) -> Dictionary:
	ensure_match_state(match_state)
	var pending: Array = match_state.get("pending_summon_effect_targets", [])
	var idx := -1
	for i in range(pending.size()):
		if typeof(pending[i]) == TYPE_DICTIONARY and str(pending[i].get("player_id", "")) == player_id:
			idx = i
			break
	if idx == -1:
		return {"is_valid": false, "errors": ["No pending summon effect target for %s." % player_id]}
	pending.remove_at(idx)
	return {"is_valid": true, "events": [], "trigger_resolutions": []}


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


## Pending turn trigger target system — for wax/wane triggers with target_mode.
## These triggers fire at turn start but need the player to pick a target.

static func queue_turn_trigger_targets(match_state: Dictionary, player_id: String) -> void:
	ensure_match_state(match_state)
	var ww_families := [FAMILY_WAX, FAMILY_WANE]
	var player := _get_player_state(match_state, player_id)
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
				var valid := get_valid_targets_for_mode(match_state, instance_id, str(descriptor.get("target_mode", "")), descriptor)
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
					var valid := get_valid_targets_for_mode(match_state, instance_id, str(descriptor.get("target_mode", "")), descriptor)
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
	var source_card := _find_card_anywhere(match_state, source_id)
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
	var lane_index := _get_card_lane_index(match_state, source_id)
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
	var resolution := _build_trigger_resolution(match_state, synthetic_trigger, synthetic_event)
	var generated := _apply_effects(match_state, synthetic_trigger, synthetic_event, resolution)
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
	var player := _get_player_state(match_state, controller_id)
	if not player.is_empty():
		wax_wane_state = str(player.get("wax_wane_state", "wax"))
		dual_wax_wane = bool(player.get("_dual_wax_wane", false))
	for ab in get_target_mode_abilities(summoned_card):
		var family := str(ab.get("family", ""))
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
	var valid := get_all_valid_targets(match_state, instance_id)
	if valid.is_empty():
		return
	var is_mandatory := false
	for ab in summon_abilities:
		if bool(ab.get("mandatory", false)):
			is_mandatory = true
			break
	var pending_arr: Array = match_state.get("pending_summon_effect_targets", [])
	pending_arr.append({
		"player_id": controller_id,
		"source_instance_id": instance_id,
		"mandatory": is_mandatory,
	})


## Check if a played/summoned card has consume: true abilities and create pending selections.
## For abilities with target_mode, the consume selection is created instead of the target selection.
## After consume resolves, the target selection is created.
static func _check_consume_abilities(match_state: Dictionary, card: Dictionary) -> void:
	var instance_id := str(card.get("instance_id", ""))
	var controller_id := str(card.get("controller_player_id", ""))
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY:
		return
	var player := _get_player_state(match_state, controller_id)
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
	var consumed_card := _find_card_anywhere(match_state, chosen_instance_id)
	if consumed_card.is_empty():
		return {"is_valid": false, "errors": ["Consumed card not found."], "events": [], "trigger_resolutions": []}
	var consumed_info := {
		"instance_id": chosen_instance_id,
		"definition_id": str(consumed_card.get("definition_id", "")),
		"name": str(consumed_card.get("name", "")),
		"power": EvergreenRules.get_power(consumed_card),
		"health": EvergreenRules.get_health(consumed_card),
		"subtypes": consumed_card.get("subtypes", []),
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
	var source_card := _find_card_anywhere(match_state, source_id)
	if not source_card.is_empty():
		source_card["_consumed_card_info"] = consumed_info
	if has_target_mode:
		# Chain into target selection — create pending_summon_effect_target
		if not source_card.is_empty():
			var valid := get_all_valid_targets(match_state, source_id)
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
	var resolution := _build_trigger_resolution(match_state, trigger, event)
	GameLogger.log_trigger_resolution(match_state, resolution, trigger)
	var generated_events := _apply_effects(match_state, trigger, event, resolution)
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
	var player := _get_player_state(match_state, player_id)
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
	var player := _get_player_state(match_state, player_id)
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
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return result
	# Face ward: absorb the entire damage instance and remove the ward
	if bool(player.get("has_ward", false)):
		player["has_ward"] = false
		result["events"] = [{"event_type": "player_ward_removed", "player_id": player_id, "absorbed_damage": amount, "source_instance_id": str(context.get("source_instance_id", ""))}]
		return result
	var previous_health := int(player.get("health", 0))
	var new_health := previous_health - amount
	player["health"] = new_health
	result["applied_damage"] = amount
	if new_health <= 0:
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
	var player := _get_player_state(match_state, player_id)
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
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return result
	result["is_valid"] = true

	var thresholds: Array = player.get("rune_thresholds", [])
	if thresholds.is_empty():
		player["health"] = 0
		append_match_win_if_needed(match_state, player_id, _get_opposing_player_id(match_state.get("players", []), player_id), result["events"])
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
		return _invalid_result("No pending Prophecy window exists for %s." % instance_id)
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
	var player := _get_player_state(match_state, player_id)
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
		"card": _find_card_anywhere(match_state, instance_id),
	}


static func play_pending_prophecy(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	if str(match_state.get("active_player_id", "")) == player_id:
		return _invalid_result("Prophecy free play is only available during the opponent's turn.")
	var window_index := _find_pending_prophecy_window_index(match_state, player_id, instance_id)
	if window_index == -1:
		return _invalid_result("No pending Prophecy window exists for %s." % instance_id)
	var card: Dictionary = _find_card_anywhere(match_state, instance_id)
	if card.is_empty() or str(card.get("zone", "")) != ZONE_HAND:
		return _invalid_result("Pending Prophecy card %s must still be in hand to be played." % instance_id)

	var card_type := str(card.get("card_type", ""))
	if card_type == CARD_TYPE_CREATURE:
		var lane_id := str(options.get("lane_id", ""))
		if lane_id.is_empty():
			return _invalid_result("Creature Prophecy play requires a lane_id.")
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
		var player := _get_player_state(match_state, player_id)
		var hand_index := _find_card_index(player.get(ZONE_HAND, []), instance_id)
		if hand_index == -1:
			return _invalid_result("Pending Prophecy card %s is no longer in hand." % instance_id)
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

	return _invalid_result("Prophecy free play is not implemented for card type `%s`." % card_type)


static func play_action_from_hand(match_state: Dictionary, player_id: String, instance_id: String, options: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var action_owner_validation := _validate_action_owner(match_state, player_id, "Action play")
	if not bool(action_owner_validation.get("is_valid", false)):
		return action_owner_validation
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return _invalid_result("Unknown player_id: %s" % player_id)
	var hand_index := _find_card_index(player.get(ZONE_HAND, []), instance_id)
	if hand_index == -1:
		return _invalid_result("Card %s is not in %s's hand." % [instance_id, player_id])
	var played_card: Dictionary = player[ZONE_HAND][hand_index]
	if str(played_card.get("card_type", "")) != CARD_TYPE_ACTION:
		return _invalid_result("Card %s is not an action." % instance_id)
	ExtendedMechanicPacks.apply_pre_play_options(played_card, options)
	if str(played_card.get("card_type", "")) != CARD_TYPE_ACTION:
		return _invalid_result("Selected mode for %s is not playable as an action." % instance_id)
	var played_for_free := bool(options.get("played_for_free", false))
	if not played_for_free:
		var play_limit := PersistentCardRules.get_play_limit_per_turn(match_state, player_id)
		if play_limit >= 0 and int(player.get("cards_played_this_turn", 0)) >= play_limit:
			return _invalid_result("You may only play %d card(s) per turn." % play_limit)
	var base_action_cost := int(played_card.get("cost", 0)) + (1 if bool(options.get("exalt", false)) else 0)
	var action_cost_reduction := int(player.get("next_card_cost_reduction", 0))
	action_cost_reduction += _get_aura_cost_reduction(match_state, player_id, played_card)
	var self_reduction = played_card.get("self_cost_reduction", {})
	if typeof(self_reduction) == TYPE_DICTIONARY and not self_reduction.is_empty():
		var sr_source := str(self_reduction.get("per", self_reduction.get("type", "")))
		var sr_amount := int(self_reduction.get("amount", 1))
		if sr_source == "empower":
			action_cost_reduction += _get_empower_amount(match_state, player_id) * sr_amount
		elif sr_source == "creature_summons_this_turn":
			action_cost_reduction += int(player.get("creature_summons_this_turn", 0)) * sr_amount
		elif sr_source == "creatures_died_this_turn":
			action_cost_reduction += int(player.get("creatures_died_this_turn", 0)) * sr_amount
		elif sr_source == "per_action_played_this_turn":
			action_cost_reduction += int(player.get("noncreature_plays_this_turn", 0)) * sr_amount
	var play_cost := 0 if played_for_free else maxi(0, base_action_cost - action_cost_reduction)
	if play_cost > _get_available_magicka(player):
		return _invalid_result("Player does not have enough magicka to play %s." % instance_id)
	if play_cost > 0:
		_spend_magicka(match_state, player_id, play_cost)
	if action_cost_reduction > 0:
		player["next_card_cost_reduction"] = 0
	player[ZONE_HAND].remove_at(hand_index)
	played_card["zone"] = ZONE_DISCARD
	player[ZONE_DISCARD].append(played_card)
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
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return {"is_valid": false, "errors": ["Unknown player_id: %s" % player_id], "events": [], "trigger_resolutions": []}
	for card in player.get(ZONE_DISCARD, []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == action_instance_id:
			action_card = card
			break
	if action_card.is_empty():
		return {"is_valid": false, "errors": ["Action card %s not found in discard." % action_instance_id], "events": [], "trigger_resolutions": []}
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
	var losing_player := _get_player_state(match_state, loser_player_id)
	if losing_player.is_empty() or int(losing_player.get("health", 0)) > 0:
		return
	if not str(match_state.get("winner_player_id", "")).is_empty():
		return
	match_state["winner_player_id"] = winner_player_id
	events.append({
		"event_type": "match_won",
		"winner_player_id": winner_player_id,
		"loser_player_id": loser_player_id,
	})


static func publish_events(match_state: Dictionary, events: Array, context: Dictionary = {}) -> Dictionary:
	ensure_match_state(match_state)
	var queue: Array = match_state["pending_event_queue"]
	for raw_event in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		queue.append(_normalize_event(match_state, raw_event, context))
	var processed_events: Array = []
	var trigger_resolutions: Array = []
	while not queue.is_empty():
		var event: Dictionary = queue.pop_front()
		processed_events.append(event)
		_append_event_log(match_state, event)
		GameLogger.log_event(match_state, event)
		ExtendedMechanicPacks.observe_event(match_state, event)
		_append_replay_entry(match_state, {
			"entry_type": "event_processed",
			"event_id": str(event.get("event_id", "")),
			"event_type": str(event.get("event_type", "")),
			"timing_window": str(event.get("timing_window", WINDOW_AFTER)),
		})
		for trigger in _find_matching_triggers(match_state, event):
			var resolution := _build_trigger_resolution(match_state, trigger, event)
			trigger_resolutions.append(resolution)
			GameLogger.log_trigger_resolution(match_state, resolution, trigger)
			_mark_once_trigger_if_needed(match_state, trigger)
			_append_replay_entry(match_state, resolution)
			for generated_event in _apply_effects(match_state, trigger, event, resolution):
				queue.append(_normalize_event(match_state, generated_event, {
					"parent_event_id": str(event.get("event_id", "")),
					"produced_by_resolution_id": str(resolution.get("resolution_id", "")),
				}))
	recalculate_auras(match_state)
	# After auras recalculate, check for creatures that should die due to lost aura health
	var aura_death_events: Array = []
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size() - 1, -1, -1):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
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
			queue.append(_normalize_event(match_state, raw_event, {}))
		while not queue.is_empty():
			var event: Dictionary = queue.pop_front()
			processed_events.append(event)
			_append_event_log(match_state, event)
			GameLogger.log_event(match_state, event)
			ExtendedMechanicPacks.observe_event(match_state, event)
			_append_replay_entry(match_state, {
				"entry_type": "event_processed",
				"event_id": str(event.get("event_id", "")),
				"event_type": str(event.get("event_type", "")),
				"timing_window": str(event.get("timing_window", WINDOW_AFTER)),
			})
			for trigger in _find_matching_triggers(match_state, event):
				var resolution := _build_trigger_resolution(match_state, trigger, event)
				trigger_resolutions.append(resolution)
				GameLogger.log_trigger_resolution(match_state, resolution, trigger)
				_mark_once_trigger_if_needed(match_state, trigger)
				_append_replay_entry(match_state, resolution)
				for generated_event in _apply_effects(match_state, trigger, event, resolution):
					queue.append(_normalize_event(match_state, generated_event, {
						"parent_event_id": str(event.get("event_id", "")),
						"produced_by_resolution_id": str(resolution.get("resolution_id", "")),
					}))
		recalculate_auras(match_state)
	var result := {
		"processed_events": processed_events,
		"trigger_resolutions": trigger_resolutions,
	}
	match_state["last_timing_result"] = result
	return result


static func recalculate_auras(match_state: Dictionary) -> void:
	# Step 1: Clear all aura bonuses on lane creatures
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				card["aura_power_bonus"] = 0
				card["aura_health_bonus"] = 0
				card["aura_keywords"] = []

	# Step 2: Collect aura sources (lane creatures + support cards), skip silenced
	var aura_sources: Array = []
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not card.has("aura"):
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				aura_sources.append({
					"card": card,
					"aura": card["aura"],
					"player_id": str(card.get("controller_player_id", player_id)),
					"lane_index": lane_index,
					"zone": "lane",
				})
	for player in match_state.get("players", []):
		var player_id := str(player.get("player_id", ""))
		for support_card in player.get("support", []):
			if typeof(support_card) != TYPE_DICTIONARY:
				continue
			if not support_card.has("aura"):
				continue
			aura_sources.append({
				"card": support_card,
				"aura": support_card["aura"],
				"player_id": player_id,
				"lane_index": -1,
				"zone": "support",
			})

	# Step 3: Apply each aura
	for source in aura_sources:
		var aura: Dictionary = source["aura"]
		var source_player_id: String = source["player_id"]
		var source_lane_index: int = source["lane_index"]
		var source_card: Dictionary = source["card"]

		# Evaluate condition
		if aura.has("condition") and not _evaluate_aura_condition(match_state, source_card, source_player_id, source_lane_index, aura["condition"]):
			continue

		var power_bonus := int(aura.get("power", 0))
		var health_bonus := int(aura.get("health", 0))
		var aura_kws: Array = aura.get("keywords", [])

		# Handle per_count multiplier
		if bool(aura.get("per_count", false)) and aura.has("condition"):
			var count := _get_aura_condition_count(match_state, source_card, source_player_id, source_lane_index, aura["condition"])
			power_bonus *= count
			health_bonus *= count

		# Find targets
		var targets := _get_aura_targets(match_state, source_card, source_player_id, source_lane_index, aura)
		for target in targets:
			target["aura_power_bonus"] = int(target.get("aura_power_bonus", 0)) + power_bonus
			target["aura_health_bonus"] = int(target.get("aura_health_bonus", 0)) + health_bonus
			for kw in aura_kws:
				var existing: Array = target.get("aura_keywords", [])
				if not existing.has(kw):
					existing.append(kw)
				target["aura_keywords"] = existing

	# Step 3b: Scan for permanent_empower and copy_expertise_abilities passives
	for player in match_state.get("players", []):
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var pid := str(player.get("player_id", ""))
		var has_perm_empower := false
		for lane in lanes:
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "permanent_empower"):
					has_perm_empower = true
					break
			if has_perm_empower:
				break
		player["_permanent_empower_active"] = has_perm_empower

	# Step 3c: Apply grant_keyword_to_keyword passives
	for lane in lanes:
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var passives = card.get("passive_abilities", [])
				if typeof(passives) != TYPE_ARRAY:
					continue
				for p in passives:
					if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "grant_keyword_to_keyword":
						continue
					var gktk_req_kw := str(p.get("required_keyword", ""))
					var gktk_grant_kw := str(p.get("granted_keyword", ""))
					if gktk_req_kw.is_empty() or gktk_grant_kw.is_empty():
						continue
					var gktk_controller := str(card.get("controller_player_id", ""))
					for gktk_lane in lanes:
						for gktk_target in gktk_lane.get("player_slots", {}).get(gktk_controller, []):
							if typeof(gktk_target) != TYPE_DICTIONARY:
								continue
							if EvergreenRules.has_keyword(gktk_target, gktk_req_kw):
								var gktk_existing: Array = gktk_target.get("aura_keywords", [])
								if not gktk_existing.has(gktk_grant_kw):
									gktk_existing.append(gktk_grant_kw)
									gktk_target["aura_keywords"] = gktk_existing

	# Step 4: Recalculate player magicka auras from lane creatures
	for player in match_state.get("players", []):
		var pid := str(player.get("player_id", ""))
		var old_bonus := int(player.get("aura_max_magicka_bonus", 0))
		var new_bonus := 0
		for lane in lanes:
			var player_slots: Dictionary = lane.get("player_slots", {})
			for card in player_slots.get(pid, []):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not card.has("magicka_aura"):
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				new_bonus += int(card["magicka_aura"])
		var delta := new_bonus - old_bonus
		if delta != 0:
			player["max_magicka"] = maxi(0, int(player.get("max_magicka", 0)) + delta)
			player["current_magicka"] = mini(int(player.get("current_magicka", 0)), int(player["max_magicka"]))
			player["aura_max_magicka_bonus"] = new_bonus


static func _evaluate_aura_condition(match_state: Dictionary, source_card: Dictionary, player_id: String, lane_index: int, condition) -> bool:
	var condition_type := ""
	if typeof(condition) == TYPE_DICTIONARY:
		condition_type = str(condition.get("type", ""))
	elif typeof(condition) == TYPE_STRING:
		condition_type = condition
	match condition_type:
		"magicka_gte_7":
			var player := _find_player_by_id(match_state, player_id)
			return int(player.get("max_magicka", 0)) >= 7
		"has_item":
			var items: Array = source_card.get("attached_items", [])
			return not items.is_empty()
		"empty_hand":
			var player := _find_player_by_id(match_state, player_id)
			var hand: Array = player.get("hand", [])
			return hand.is_empty()
		"most_creatures_in_lane":
			if lane_index < 0:
				return false
			var lanes_arr: Array = match_state.get("lanes", [])
			if lane_index >= lanes_arr.size():
				return false
			var lane: Dictionary = lanes_arr[lane_index]
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			var my_count := 0
			var max_opponent_count := 0
			for pid in player_slots_by_id.keys():
				var count: int = player_slots_by_id[pid].size()
				if str(pid) == player_id:
					my_count = count
				else:
					max_opponent_count = maxi(max_opponent_count, count)
			return my_count > max_opponent_count
		"no_enemies_in_lane":
			if lane_index < 0:
				return false
			var lanes_arr: Array = match_state.get("lanes", [])
			if lane_index >= lanes_arr.size():
				return false
			var lane: Dictionary = lanes_arr[lane_index]
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			for pid in player_slots_by_id.keys():
				if str(pid) != player_id and player_slots_by_id[pid].size() > 0:
					return false
			return true
		"your_turn":
			return str(match_state.get("active_player_id", "")) == player_id
		"count_friendly_with_keyword":
			# Always true — the count is used as a multiplier via per_count
			return true
	return false


static func _get_aura_condition_count(match_state: Dictionary, source_card: Dictionary, player_id: String, _lane_index: int, condition) -> int:
	var condition_type := ""
	var keyword_id := ""
	if typeof(condition) == TYPE_DICTIONARY:
		condition_type = str(condition.get("type", ""))
		keyword_id = str(condition.get("keyword", ""))
	elif typeof(condition) == TYPE_STRING:
		condition_type = condition
	if condition_type == "count_friendly_with_keyword" and not keyword_id.is_empty():
		var source_instance_id := str(source_card.get("instance_id", ""))
		var count := 0
		for lane in match_state.get("lanes", []):
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			if not player_slots_by_id.has(player_id):
				continue
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == source_instance_id:
					continue
				if EvergreenRules.has_keyword(card, keyword_id):
					count += 1
		return count
	return 1


static func _get_aura_targets(match_state: Dictionary, source_card: Dictionary, player_id: String, source_lane_index: int, aura: Dictionary) -> Array:
	var scope: String = str(aura.get("scope", ""))
	var target_filter: String = str(aura.get("target", ""))
	var filter_subtype: String = str(aura.get("filter_subtype", ""))
	var filter_attribute: String = str(aura.get("filter_attribute", ""))
	var source_instance_id := str(source_card.get("instance_id", ""))
	var targets: Array = []

	if scope == "self":
		# Self-aura — only the source card itself (must be in lane)
		if str(source_card.get("zone", source_card.get("card_type", ""))) != "support":
			targets.append(source_card)
		return targets

	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		if scope == "same_lane" and lane_index != source_lane_index:
			continue
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		if not player_slots_by_id.has(player_id):
			continue
		for card in player_slots_by_id[player_id]:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			# "other_friendly" excludes self, "all_friendly" includes self
			if target_filter == "other_friendly" and str(card.get("instance_id", "")) == source_instance_id:
				continue
			if not filter_subtype.is_empty():
				var subtypes: Array = card.get("subtypes", [])
				if not subtypes.has(filter_subtype):
					continue
			if not filter_attribute.is_empty():
				var attributes: Array = card.get("attributes", [])
				if not attributes.has(filter_attribute):
					continue
			targets.append(card)
	return targets


static func _find_player_by_id(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func rebuild_trigger_registry(match_state: Dictionary) -> Array:
	ensure_match_state(match_state)
	var registry: Array = []
	var current_turn := int(match_state.get("turn_number", -1))
	var players: Array = match_state.get("players", [])
	for player in players:
		var player_id := str(player.get("player_id", ""))
		for zone_name in PLAYER_ZONE_ORDER:
			var cards = player.get(zone_name, [])
			if typeof(cards) != TYPE_ARRAY:
				continue
			for card in cards:
				_append_card_triggers(registry, card, zone_name, player_id, -1, -1, current_turn)
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots = player_slots_by_id[player_id]
			if typeof(slots) != TYPE_ARRAY:
				continue
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				_append_card_triggers(registry, card, ZONE_LANE, str(player_id), lane_index, slot_index, current_turn)
				if typeof(card) == TYPE_DICTIONARY:
					for attached_item in card.get("attached_items", []):
						_append_card_triggers(registry, attached_item, ZONE_LANE, str(player_id), lane_index, slot_index, current_turn)
	_inject_granted_triggers(match_state, registry, lanes)
	# copy_expertise_abilities: Master of Incunabula copies all friendly expertise triggers
	_inject_copied_expertise_triggers(registry, lanes)
	match_state["trigger_registry"] = registry.duplicate(true)
	return registry


static func _inject_copied_expertise_triggers(registry: Array, lanes: Array) -> void:
	# Find creatures with copy_expertise_abilities passive
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		for player_id in lane.get("player_slots", {}).keys():
			var slots: Array = lane.get("player_slots", {}).get(player_id, [])
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not EvergreenRules._has_passive(card, "copy_expertise_abilities"):
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				var copier_id := str(card.get("instance_id", ""))
				var copier_controller := str(card.get("controller_player_id", player_id))
				# Collect expertise triggers from all other friendly creatures
				for ce_lane_index in range(lanes.size()):
					for ce_card in lanes[ce_lane_index].get("player_slots", {}).get(copier_controller, []):
						if typeof(ce_card) != TYPE_DICTIONARY:
							continue
						if str(ce_card.get("instance_id", "")) == copier_id:
							continue
						var ce_triggers = ce_card.get("triggered_abilities", [])
						if typeof(ce_triggers) != TYPE_ARRAY:
							continue
						for ce_idx in range(ce_triggers.size()):
							var ce_trigger = ce_triggers[ce_idx]
							if typeof(ce_trigger) != TYPE_DICTIONARY:
								continue
							if str(ce_trigger.get("family", "")) != FAMILY_EXPERTISE:
								continue
							registry.append({
								"trigger_id": "%s_copied_expertise_%s_%d" % [copier_id, str(ce_card.get("instance_id", "")), ce_idx],
								"trigger_index": -1,
								"source_instance_id": copier_id,
								"owner_player_id": copier_controller,
								"controller_player_id": copier_controller,
								"source_zone": ZONE_LANE,
								"lane_index": lane_index,
								"slot_index": slot_index,
								"descriptor": ce_trigger.duplicate(true),
							})


static func _inject_granted_triggers(match_state: Dictionary, registry: Array, lanes: Array) -> void:
	for player in match_state.get("players", []):
		var player_id := str(player.get("player_id", ""))
		var granted_triggers: Array = []
		for support_card in player.get(ZONE_SUPPORT, []):
			if typeof(support_card) != TYPE_DICTIONARY:
				continue
			if EvergreenRules.has_raw_status(support_card, EvergreenRules.STATUS_SILENCED):
				continue
			var grants = support_card.get("grants_trigger", [])
			if typeof(grants) != TYPE_ARRAY:
				continue
			for grant in grants:
				if typeof(grant) == TYPE_DICTIONARY:
					granted_triggers.append(grant)
		for lane in lanes:
			for lane_card in lane.get("player_slots", {}).get(player_id, []):
				if typeof(lane_card) != TYPE_DICTIONARY:
					continue
				if EvergreenRules.has_raw_status(lane_card, EvergreenRules.STATUS_SILENCED):
					continue
				var grants = lane_card.get("grants_trigger", [])
				if typeof(grants) != TYPE_ARRAY:
					continue
				for grant in grants:
					if typeof(grant) == TYPE_DICTIONARY:
						granted_triggers.append(grant)
		if granted_triggers.is_empty():
			continue
		for lane_index in range(lanes.size()):
			var lane: Dictionary = lanes[lane_index]
			var slots = lane.get("player_slots", {}).get(player_id, [])
			if typeof(slots) != TYPE_ARRAY:
				continue
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var instance_id := str(card.get("instance_id", ""))
				for g_index in range(granted_triggers.size()):
					var descriptor: Dictionary = granted_triggers[g_index].duplicate(true)
					if not str(descriptor.get("target_mode", "")).is_empty():
						continue
					var required_keyword := str(descriptor.get("required_keyword", ""))
					if not required_keyword.is_empty() and not EvergreenRules.has_keyword(card, required_keyword):
						continue
					registry.append({
						"trigger_id": "%s_granted_%d" % [instance_id, g_index],
						"trigger_index": -1,
						"source_instance_id": instance_id,
						"owner_player_id": str(card.get("owner_player_id", player_id)),
						"controller_player_id": str(card.get("controller_player_id", player_id)),
						"source_zone": ZONE_LANE,
						"lane_index": lane_index,
						"slot_index": slot_index,
						"descriptor": descriptor,
					})


static func _append_card_triggers(registry: Array, card, zone_name: String, controller_player_id: String, lane_index := -1, slot_index := -1, current_turn := -1) -> void:
	if typeof(card) != TYPE_DICTIONARY:
		return
	var raw_triggers = card.get("triggered_abilities", [])
	if typeof(raw_triggers) != TYPE_ARRAY or raw_triggers.is_empty():
		return
	for trigger_index in range(raw_triggers.size()):
		var raw_trigger = raw_triggers[trigger_index]
		if typeof(raw_trigger) != TYPE_DICTIONARY:
			continue
		var descriptor: Dictionary = raw_trigger
		if not bool(descriptor.get("enabled", true)):
			continue
		if current_turn >= 0 and descriptor.has("expires_on_turn") and int(descriptor.get("expires_on_turn", -1)) < current_turn:
			continue
		if current_turn >= 0 and descriptor.has("_expires_on_turn") and int(descriptor.get("_expires_on_turn", -1)) < current_turn:
			continue
		if not str(descriptor.get("target_mode", "")).is_empty():
			continue  # Target-choice triggers resolved manually via resolve_targeted_effect
		if bool(descriptor.get("consume", false)):
			var consume_family := str(descriptor.get("family", ""))
			if consume_family == FAMILY_SUMMON or consume_family == "on_play":
				continue  # Consume triggers resolved via pending_consume_selections
		var instance_id := str(card.get("instance_id", ""))
		var trigger_id := str(descriptor.get("id", "%s_trigger_%d" % [instance_id, trigger_index]))
		registry.append({
			"trigger_id": trigger_id,
			"trigger_index": trigger_index,
			"source_instance_id": instance_id,
			"owner_player_id": str(card.get("owner_player_id", controller_player_id)),
			"controller_player_id": str(card.get("controller_player_id", controller_player_id)),
			"source_zone": zone_name,
			"lane_index": lane_index,
			"slot_index": slot_index,
			"descriptor": descriptor.duplicate(true),
		})


static func _find_matching_triggers(match_state: Dictionary, event: Dictionary) -> Array:
	var matches: Array = []
	for trigger in rebuild_trigger_registry(match_state):
		if not _trigger_matches_event(match_state, trigger, event):
			continue
		trigger["sort_key"] = _build_trigger_sort_key(match_state, trigger)
		_insert_sorted_trigger(matches, trigger)
	return matches


static func _trigger_matches_event(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> bool:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	if descriptor.is_empty():
		return false
	if _is_once_trigger_consumed(match_state, trigger):
		return false
	if not _matches_required_zone(trigger, descriptor):
		return false
	# Triggers with target_mode require manual resolution via resolve_targeted_effect;
	# skip them during automatic event processing so they don't fire with no chosen target.
	if not str(descriptor.get("target_mode", "")).is_empty() and str(trigger.get("_chosen_target_id", "")).is_empty() and str(trigger.get("_chosen_target_player_id", "")).is_empty():
		return false
	var event_type := str(event.get("event_type", ""))
	var family := str(descriptor.get("family", ""))
	var family_spec: Dictionary = FAMILY_SPECS.get(family, {})
	var expected_event_type := str(descriptor.get("event_type", family_spec.get("event_type", "")))
	if event_type != expected_event_type:
		# pilfer_is_slay: slay triggers also fire on pilfer events
		if family == FAMILY_SLAY and event_type == EVENT_DAMAGE_RESOLVED and str(event.get("target_type", "")) == "player" and int(event.get("amount", 0)) > 0:
			var pis_source_id := str(trigger.get("source_instance_id", ""))
			if str(event.get("source_instance_id", "")) == pis_source_id:
				var pis_controller := str(trigger.get("controller_player_id", ""))
				if _has_pilfer_is_slay_active(match_state, pis_controller):
					return _matches_conditions(match_state, trigger, descriptor, family_spec, event)
		return false
	if not _matches_trigger_role(match_state, trigger, descriptor, family_spec, event):
		return false
	return _matches_conditions(match_state, trigger, descriptor, family_spec, event)


static func _has_pilfer_is_slay_active(match_state: Dictionary, controller_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(controller_id, []):
			if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "pilfer_is_slay"):
				return true
	for support in _get_player_state(match_state, controller_id).get("support", []):
		if typeof(support) == TYPE_DICTIONARY and EvergreenRules._has_passive(support, "pilfer_is_slay"):
			return true
	return false


static func _matches_required_zone(trigger: Dictionary, descriptor: Dictionary) -> bool:
	if descriptor.has("required_zone"):
		var required := str(descriptor.get("required_zone", ""))
		var actual := str(trigger.get("source_zone", ""))
		if required == actual:
			return true
		# Slay triggers fire even if the creature just died (moved from lane to discard in same combat)
		if required == ZONE_LANE and actual == ZONE_DISCARD and str(descriptor.get("family", "")) == FAMILY_SLAY:
			return true
		return false
	var required_zones = descriptor.get("required_zones", [])
	if typeof(required_zones) == TYPE_ARRAY and not required_zones.is_empty():
		return required_zones.has(str(trigger.get("source_zone", "")))
	return true


static func _matches_trigger_role(match_state: Dictionary, trigger: Dictionary, descriptor: Dictionary, family_spec: Dictionary, event: Dictionary) -> bool:
	var source_instance_id := str(trigger.get("source_instance_id", ""))
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var role := str(descriptor.get("match_role", family_spec.get("match_role", "source")))
	match role:
		"controller":
			return str(event.get("player_id", event.get("playing_player_id", event.get("controller_player_id", event.get("source_controller_player_id", ""))))) == controller_player_id
		"opponent_player":
			var event_player_id := str(event.get("player_id", event.get("playing_player_id", event.get("controller_player_id", event.get("source_controller_player_id", "")))))
			return not event_player_id.is_empty() and event_player_id != controller_player_id
		"source":
			return str(event.get("source_instance_id", event.get("attacker_instance_id", ""))) == source_instance_id
		"target":
			return _event_target_instance_id(event) == source_instance_id
		"subject":
			return _event_subject_instance_id(event) == source_instance_id
		"killer":
			return str(event.get("destroyed_by_instance_id", "")) == source_instance_id
		"either":
			return str(event.get("source_instance_id", "")) == source_instance_id or _event_target_instance_id(event) == source_instance_id or _event_subject_instance_id(event) == source_instance_id
		"any_player":
			return true
		"friendly_killer":
			var killer_id := str(event.get("destroyed_by_instance_id", ""))
			if killer_id.is_empty() or killer_id == source_instance_id:
				return false
			var killer_card := _find_card_anywhere(match_state, killer_id)
			return str(killer_card.get("controller_player_id", "")) == controller_player_id
		"target_player_is_controller":
			return str(event.get("target_player_id", "")) == controller_player_id
		"target_player_is_opponent":
			var tp_id := str(event.get("target_player_id", ""))
			return not tp_id.is_empty() and tp_id != controller_player_id
		"opponent_target":
			var target_id := _event_target_instance_id(event)
			if target_id.is_empty():
				return false
			var target_card := _find_card_anywhere(match_state, target_id)
			return not target_card.is_empty() and str(target_card.get("controller_player_id", "")) != controller_player_id
	return false


static func _matches_conditions(match_state: Dictionary, trigger: Dictionary, descriptor: Dictionary, family_spec: Dictionary, event: Dictionary) -> bool:
	var target_type := str(descriptor.get("target_type", family_spec.get("target_type", "")))
	if not target_type.is_empty() and str(event.get("target_type", "")) != target_type:
		return false
	var min_amount := int(descriptor.get("min_amount", family_spec.get("min_amount", 0)))
	if min_amount > 0 and int(event.get("amount", 0)) < min_amount:
		return false
	var min_played_cost := int(descriptor.get("min_played_cost", family_spec.get("min_played_cost", 0)))
	if min_played_cost > 0 and int(event.get("played_cost", 0)) < min_played_cost:
		return false
	var require_survived := bool(descriptor.get("require_survived", family_spec.get("require_survived", false)))
	if require_survived:
		# Check that the trigger's source creature is still alive in a lane
		var survive_check_id := str(trigger.get("source_instance_id", ""))
		var survive_card := _find_card_anywhere(match_state, survive_check_id)
		if survive_card.is_empty() or str(survive_card.get("zone", "")) != ZONE_LANE:
			return false
		if int(survive_card.get("health", 0)) <= 0:
			return false
	var required_damage_kind := str(descriptor.get("damage_kind", family_spec.get("damage_kind", "")))
	if not required_damage_kind.is_empty() and str(event.get("damage_kind", "")) != required_damage_kind:
		return false
	if bool(descriptor.get("exclude_retaliation", family_spec.get("exclude_retaliation", false))):
		if bool(event.get("is_retaliation", false)):
			return false
	if bool(descriptor.get("require_retaliation", family_spec.get("require_retaliation", false))):
		if not bool(event.get("is_retaliation", false)):
			return false
	var required_played_card_type := str(descriptor.get("required_played_card_type", family_spec.get("required_played_card_type", "")))
	if not required_played_card_type.is_empty() and str(event.get("card_type", "")) != required_played_card_type:
		return false
	var required_played_rules_tag := str(descriptor.get("required_played_rules_tag", ""))
	if not required_played_rules_tag.is_empty():
		var event_rules_tags = event.get("rules_tags", [])
		if typeof(event_rules_tags) != TYPE_ARRAY or not event_rules_tags.has(required_played_rules_tag):
			return false
	if bool(descriptor.get("exclude_self", family_spec.get("exclude_self", false))):
		var event_source_id := str(event.get("source_instance_id", event.get("subject_instance_id", "")))
		if event_source_id == str(trigger.get("source_instance_id", "")):
			return false
	if bool(descriptor.get("require_same_lane", false)):
		var trigger_lane_index := int(trigger.get("lane_index", -1))
		var event_lane_id := str(event.get("lane_id", ""))
		var lanes: Array = match_state.get("lanes", [])
		if trigger_lane_index < 0 or trigger_lane_index >= lanes.size():
			return false
		if str(lanes[trigger_lane_index].get("lane_id", "")) != event_lane_id:
			return false
	var max_source_cost := int(descriptor.get("max_event_source_cost", -1))
	if max_source_cost >= 0:
		var cost_check_card := _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
		if cost_check_card.is_empty() or int(cost_check_card.get("cost", 999)) > max_source_cost:
			return false
	var required_event_source_zone := str(descriptor.get("required_event_source_zone", ""))
	if not required_event_source_zone.is_empty() and str(event.get("source_zone", "")) != required_event_source_zone:
		return false
	var required_event_target_zone := str(descriptor.get("required_event_target_zone", ""))
	if not required_event_target_zone.is_empty() and str(event.get("target_zone", "")) != required_event_target_zone:
		return false
	var required_event_status_id := str(descriptor.get("required_event_status_id", family_spec.get("required_event_status_id", "")))
	if not required_event_status_id.is_empty() and str(event.get("status_id", "")) != required_event_status_id:
		return false
	var required_target_keyword := str(descriptor.get("required_target_keyword", ""))
	if not required_target_keyword.is_empty():
		var rtk_target_id := str(event.get("target_instance_id", ""))
		var rtk_target := _find_card_anywhere(match_state, rtk_target_id)
		if rtk_target.is_empty() or not EvergreenRules.has_keyword(rtk_target, required_target_keyword):
			return false
	# Summon-filtering conditions — gate triggers based on properties of the summoned creature
	var _summon_card_needed := false
	var _summon_card: Dictionary = {}
	var required_summon_subtype := str(descriptor.get("required_summon_subtype", ""))
	var required_summon_keyword := str(descriptor.get("required_summon_keyword", ""))
	var required_summon_min_power := int(descriptor.get("required_summon_min_power", 0))
	var required_summon_min_health := int(descriptor.get("required_summon_min_health", 0))
	var required_summon_min_cost := int(descriptor.get("required_summon_min_cost", 0))
	if not required_summon_subtype.is_empty() or not required_summon_keyword.is_empty() or required_summon_min_power > 0 or required_summon_min_health > 0 or required_summon_min_cost > 0:
		_summon_card = _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
		if _summon_card.is_empty():
			return false
	if not required_summon_subtype.is_empty():
		var summon_subtypes = _summon_card.get("subtypes", [])
		if typeof(summon_subtypes) != TYPE_ARRAY or not summon_subtypes.has(required_summon_subtype):
			return false
	if not required_summon_keyword.is_empty():
		if not EvergreenRules.has_keyword(_summon_card, required_summon_keyword):
			return false
	if required_summon_min_power > 0:
		if EvergreenRules.get_power(_summon_card) < required_summon_min_power:
			return false
	if required_summon_min_health > 0:
		if EvergreenRules.get_health(_summon_card) < required_summon_min_health:
			return false
	if required_summon_min_cost > 0:
		if int(_summon_card.get("cost", 0)) < required_summon_min_cost:
			return false
	# Slay-filtering: gate slay triggers based on properties of the destroyed creature
	var required_slay_subtype := str(descriptor.get("required_slay_subtype", ""))
	if not required_slay_subtype.is_empty():
		var slay_victim := _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
		if slay_victim.is_empty():
			return false
		var slay_subtypes = slay_victim.get("subtypes", [])
		if typeof(slay_subtypes) != TYPE_ARRAY or not slay_subtypes.has(required_slay_subtype):
			return false
	if bool(descriptor.get("require_positive_power_bonus", family_spec.get("require_positive_power_bonus", false))):
		if int(event.get("power_bonus", 0)) <= 0:
			return false
	# Expertise: only fires at end of turn if controller played an action/item/support
	if str(descriptor.get("family", "")) == FAMILY_EXPERTISE:
		var expertise_controller := str(trigger.get("controller_player_id", ""))
		var expertise_player := _get_player_state(match_state, expertise_controller)
		if int(expertise_player.get("noncreature_plays_this_turn", 0)) <= 0:
			return false
	var required_wax_wane := str(descriptor.get("required_wax_wane_phase", family_spec.get("required_wax_wane_phase", "")))
	if not required_wax_wane.is_empty():
		var controller_player_id := str(trigger.get("controller_player_id", ""))
		var ww_player := _get_player_state(match_state, controller_player_id)
		if str(ww_player.get("wax_wane_state", "wax")) != required_wax_wane and not bool(ww_player.get("_dual_wax_wane", false)):
			return false
	return ExtendedMechanicPacks.matches_additional_conditions(match_state, trigger, descriptor, event)


static func _build_trigger_sort_key(match_state: Dictionary, trigger: Dictionary) -> String:
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var priority_player_id := str(match_state.get("priority_player_id", match_state.get("active_player_id", "")))
	var controller_rank := 0 if controller_player_id == priority_player_id else 1
	var zone_name := str(trigger.get("source_zone", ""))
	var zone_rank := int(ZONE_PRIORITY.get(zone_name, 9))
	var lane_index := maxi(-1, int(trigger.get("lane_index", -1))) + 1
	var slot_index := maxi(-1, int(trigger.get("slot_index", -1))) + 1
	var trigger_index := int(trigger.get("trigger_index", 0))
	return "%02d|%02d|%02d|%02d|%s|%02d" % [controller_rank, zone_rank, lane_index, slot_index, str(trigger.get("source_instance_id", "")), trigger_index]


static func _insert_sorted_trigger(matches: Array, trigger: Dictionary) -> void:
	var sort_key := str(trigger.get("sort_key", ""))
	for index in range(matches.size()):
		if sort_key < str(matches[index].get("sort_key", "")):
			matches.insert(index, trigger)
			return
	matches.append(trigger)


static func _build_trigger_resolution(match_state: Dictionary, trigger: Dictionary, event: Dictionary) -> Dictionary:
	match_state["next_trigger_resolution_sequence"] = int(match_state.get("next_trigger_resolution_sequence", 0)) + 1
	var resolution_id := "trigger_%04d" % int(match_state["next_trigger_resolution_sequence"])
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var family := str(descriptor.get("family", descriptor.get("event_type", "")))
	return {
		"entry_type": "trigger_resolved",
		"resolution_id": resolution_id,
		"trigger_id": str(trigger.get("trigger_id", "")),
		"source_instance_id": str(trigger.get("source_instance_id", "")),
		"controller_player_id": str(trigger.get("controller_player_id", "")),
		"family": family,
		"event_id": str(event.get("event_id", "")),
		"event_type": str(event.get("event_type", "")),
		"timing_window": str(descriptor.get("window", FAMILY_SPECS.get(family, {}).get("window", WINDOW_AFTER))),
	}


static func _mark_once_trigger_if_needed(match_state: Dictionary, trigger: Dictionary) -> void:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var is_once_per_instance := bool(descriptor.get("once_per_instance", false)) or str(descriptor.get("family", "")) == FAMILY_VETERAN
	if is_once_per_instance:
		var resolved_once_triggers: Dictionary = match_state.get("resolved_once_triggers", {})
		resolved_once_triggers[str(trigger.get("trigger_id", ""))] = true
		match_state["resolved_once_triggers"] = resolved_once_triggers
	if bool(descriptor.get("once_per_turn", false)):
		var resolved_turn_triggers: Dictionary = match_state.get("resolved_turn_triggers", {})
		resolved_turn_triggers[str(trigger.get("trigger_id", ""))] = true
		match_state["resolved_turn_triggers"] = resolved_turn_triggers


static func _is_once_trigger_consumed(match_state: Dictionary, trigger: Dictionary) -> bool:
	var descriptor: Dictionary = trigger.get("descriptor", {})
	# Veteran is inherently once-per-instance (first attack only)
	var is_once_per_instance := bool(descriptor.get("once_per_instance", false)) or str(descriptor.get("family", "")) == FAMILY_VETERAN
	if is_once_per_instance:
		var resolved_once_triggers: Dictionary = match_state.get("resolved_once_triggers", {})
		if bool(resolved_once_triggers.get(str(trigger.get("trigger_id", "")), false)):
			return true
	if bool(descriptor.get("once_per_turn", false)):
		var resolved_turn_triggers: Dictionary = match_state.get("resolved_turn_triggers", {})
		if bool(resolved_turn_triggers.get(str(trigger.get("trigger_id", "")), false)):
			return true
	return false


static func _apply_effects(match_state: Dictionary, trigger: Dictionary, event: Dictionary, resolution: Dictionary) -> Array:
	var generated_events: Array = []
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var reason := str(descriptor.get("family", "trigger"))
	# Consume-gated abilities (pilfer, etc.) — defer effects until player picks a consume target
	if bool(descriptor.get("consume", false)) and not trigger.has("_consumed_card_info"):
		var consume_controller_id := str(trigger.get("controller_player_id", ""))
		var consume_source_id := str(trigger.get("source_instance_id", ""))
		var consume_candidates := get_consume_candidates(match_state, consume_controller_id)
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
		var th_result := _process_treasure_hunt(match_state, trigger, event, descriptor)
		generated_events.append_array(th_result.get("events", []))
		if not bool(th_result.get("hunt_complete", false)):
			return generated_events  # Hunt not complete yet, don't fire effects
	for raw_effect in descriptor.get("effects", []):
		if typeof(raw_effect) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = raw_effect
		if not ExtendedMechanicPacks.effect_is_enabled(match_state, trigger, effect):
			continue
		if bool(effect.get("require_event_target_alive", false)):
			var alive_check_id := _event_target_instance_id(event)
			if alive_check_id.is_empty():
				continue
			var alive_check_card := _find_card_anywhere(match_state, alive_check_id)
			if alive_check_card.is_empty() or str(alive_check_card.get("zone", "")) != ZONE_LANE:
				continue
		var op := str(effect.get("op", ""))
		match op:
			"log":
				generated_events.append({
					"event_type": "timing_effect_logged",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"message": str(effect.get("message", str(descriptor.get("family", "trigger")))),
				})
			"reveal_opponent_top_deck":
				var controller_id := str(trigger.get("controller_player_id", ""))
				var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
				var opponent := _get_player_state(match_state, opponent_id)
				if not opponent.is_empty():
					var deck: Array = opponent.get(ZONE_DECK, [])
					if not deck.is_empty():
						generated_events.append({
							"event_type": "opponent_top_deck_revealed",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"controller_player_id": controller_id,
							"revealed_card": deck.back().duplicate(true),
						})
			"modify_stats":
				var stat_multiplier := _resolve_count_multiplier(match_state, trigger, event, effect)
				var consumed_info: Dictionary = trigger.get("_consumed_card_info", {})
				if consumed_info.is_empty():
					var source_card_for_info := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
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
					var ms_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if not ms_source.is_empty():
						base_power = EvergreenRules.get_power(ms_source)
				elif ms_power_source == "self_health":
					var ms_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if not ms_source.is_empty():
						base_power = int(ms_source.get("health", 0)) - int(ms_source.get("damage_marked", 0))
				elif ms_power_source == "event_power_gained":
					base_power = int(event.get("power_bonus", event.get("amount", 0)))
				var ms_health_source := str(effect.get("health_source", ""))
				if ms_health_source == "self_power" or bool(effect.get("health_from_self_power", false)):
					var ms_source_h := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if not ms_source_h.is_empty():
						base_health = EvergreenRules.get_power(ms_source_h)
				var total_power := base_power * stat_multiplier
				var total_health := base_health * stat_multiplier
				var is_temp := str(effect.get("duration", "")) == "end_of_turn"
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.apply_stat_bonus(card, total_power, total_health, reason)
					if is_temp:
						EvergreenRules.add_temporary_stat_bonus(card, total_power, total_health, int(match_state.get("turn_number", 0)))
					generated_events.append({
						"event_type": "stats_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"power_bonus": total_power,
						"health_bonus": total_health,
						"reason": reason,
					})
			"grant_status":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var status_id := str(effect.get("status_id", ""))
					var target_self_immunities = card.get("self_immunity", [])
					if typeof(target_self_immunities) == TYPE_ARRAY and target_self_immunities.has(status_id):
						continue
					if status_id == EvergreenRules.STATUS_COVER:
						var offset := int(effect.get("expires_on_turn_offset", 1))
						EvergreenRules.grant_cover(card, int(match_state.get("turn_number", 0)) + offset, reason)
					else:
						EvergreenRules.add_status(card, status_id)
						if bool(effect.get("expires_end_of_turn", false)):
							var temp_statuses: Array = card.get("_temp_statuses", [])
							if not temp_statuses.has(status_id):
								temp_statuses.append(status_id)
							card["_temp_statuses"] = temp_statuses
					generated_events.append({
						"event_type": "status_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"status_id": status_id,
					})
			"grant_keyword":
				var kw_is_temp := str(effect.get("duration", "")) == "end_of_turn"
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.ensure_card_state(card)
					var keyword_id := str(effect.get("keyword_id", ""))
					var granted_keywords: Array = card.get("granted_keywords", [])
					if not granted_keywords.has(keyword_id):
						granted_keywords.append(keyword_id)
						card["granted_keywords"] = granted_keywords
					if kw_is_temp:
						EvergreenRules.add_temporary_keyword(card, keyword_id, int(match_state.get("turn_number", 0)))
					if keyword_id == EvergreenRules.KEYWORD_GUARD and EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER):
						EvergreenRules.remove_status(card, EvergreenRules.STATUS_COVER)
						card.erase("cover_expires_on_turn")
						card.erase("cover_granted_by")
					generated_events.append({
						"event_type": "keyword_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"keyword_id": keyword_id,
					})
			"grant_triggered_ability":
				var gta_ability: Dictionary = effect.get("ability", {})
				var gta_label := str(effect.get("assemble_label", ""))
				var gta_text_template := str(effect.get("text_template", ""))
				if not gta_ability.is_empty():
					for card in _resolve_card_targets(match_state, trigger, event, effect):
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
							_update_assemble_rules_text(card, gta_label, gta_text_template)
						generated_events.append({
							"event_type": "triggered_ability_granted",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"target_instance_id": str(card.get("instance_id", "")),
							"ability_family": str(gta_ability.get("family", "")),
						})
			"grant_random_keyword":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.ensure_card_state(card)
					var candidates: Array = []
					for kw in RANDOM_KEYWORD_POOL:
						if not EvergreenRules.has_keyword(card, kw):
							candidates.append(kw)
					if candidates.is_empty():
						continue
					var pick: String = str(candidates[_deterministic_index(match_state, str(card.get("instance_id", "")), candidates.size())])
					var granted_keywords: Array = card.get("granted_keywords", [])
					if not granted_keywords.has(pick):
						granted_keywords.append(pick)
						card["granted_keywords"] = granted_keywords
					if pick == EvergreenRules.KEYWORD_GUARD and EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER):
						EvergreenRules.remove_status(card, EvergreenRules.STATUS_COVER)
						card.erase("cover_expires_on_turn")
						card.erase("cover_granted_by")
					generated_events.append({
						"event_type": "keyword_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"keyword_id": pick,
					})
			"remove_keyword":
				var keyword_to_remove := str(effect.get("keyword_id", ""))
				if not keyword_to_remove.is_empty():
					for card in _resolve_card_targets(match_state, trigger, event, effect):
						if EvergreenRules.remove_keyword(card, keyword_to_remove):
							generated_events.append({
								"event_type": "keyword_removed",
								"source_instance_id": str(trigger.get("source_instance_id", "")),
								"target_instance_id": str(card.get("instance_id", "")),
								"keyword_id": keyword_to_remove,
								"reason": reason,
							})
			"restore_creature_health":
				var restore_amount := int(effect.get("amount", -1))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var healed := EvergreenRules.restore_health(card, restore_amount)
					if healed > 0:
						generated_events.append({
							"event_type": "creature_healed",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"target_instance_id": str(card.get("instance_id", "")),
							"amount": healed,
							"reason": reason,
						})
			"heal":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var heal_player := _get_player_state(match_state, player_id)
					if heal_player.is_empty():
						continue
					var heal_amount := _resolve_amount(trigger, effect, match_state, event) * _resolve_count_multiplier(match_state, trigger, event, effect)
					if bool(effect.get("amount_from_event", false)):
						heal_amount = int(event.get("amount", 0))
					if heal_amount <= 0:
						continue
					heal_amount *= _get_heal_multiplier(match_state, player_id)
					heal_player["health"] = int(heal_player.get("health", 0)) + heal_amount
					generated_events.append({
						"event_type": "player_healed",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_player_id": player_id,
						"amount": heal_amount,
					})
			"gain_max_magicka":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var magicka_player := _get_player_state(match_state, player_id)
					if magicka_player.is_empty():
						continue
					var gain := _resolve_amount(trigger, effect, match_state, event)
					if gain == 0:
						gain = int(effect.get("amount", 1))
					magicka_player["max_magicka"] = int(magicka_player.get("max_magicka", 0)) + gain
					magicka_player["current_magicka"] = int(magicka_player.get("current_magicka", 0)) + gain
					# Apply max_magicka_cap passive from any creature in play
					var gmm_cap := _get_max_magicka_cap(match_state)
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
			"spend_all_magicka_for_stats":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var ctrl_id := str(card.get("controller_player_id", ""))
					var p := _get_player_state(match_state, ctrl_id)
					if p.is_empty():
						continue
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
			"deal_damage":
				var damage_amount := _resolve_amount(trigger, effect, match_state, event) * _resolve_count_multiplier(match_state, trigger, event, effect)
				var dd_empower_bonus := int(effect.get("empower_bonus", 0))
				if dd_empower_bonus > 0:
					damage_amount += dd_empower_bonus * _get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
				var damage_source_id := str(trigger.get("source_instance_id", ""))
				var deal_damage_targets := _resolve_card_targets(match_state, trigger, event, effect)
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
				var is_action_damage := str(event.get("card_type", "")) == "action"
				for card in deal_damage_targets:
					if damage_amount <= 0:
						continue
					if is_action_damage and _is_immune_to_effect(match_state, card, "action_damage"):
						continue
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
					if EvergreenRules.is_creature_destroyed(card, false):
						var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
						if bool(card_location.get("is_valid", false)):
							var controller_pid := str(card.get("controller_player_id", ""))
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
			"draw_cards":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var draw_count := int(effect.get("count", 1)) * _resolve_count_multiplier(match_state, trigger, event, effect)
						var draw_result := draw_cards(match_state, player_id, draw_count, {
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
			"draw_filtered":
				var filter_max_cost := int(effect.get("max_cost", -1))
				var filter_card_type := str(effect.get("required_card_type", ""))
				var filter_subtype := str(effect.get("required_subtype", ""))
				var filter_rules_tag := str(effect.get("required_rules_tag", ""))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var draw_player := _get_player_state(match_state, player_id)
					if draw_player.is_empty():
						continue
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
						candidates.append(deck_index)
					if candidates.is_empty():
						continue
					var pick_index: int = candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_draw_filtered", candidates.size())]
					var picked_card: Dictionary = deck[pick_index]
					deck.remove_at(pick_index)
					if _overflow_card_to_discard(draw_player, picked_card, player_id, ZONE_DECK, generated_events):
						continue
					picked_card["zone"] = ZONE_HAND
					draw_player[ZONE_HAND].append(picked_card)
					generated_events.append({
						"event_type": "card_drawn",
						"player_id": player_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"drawn_instance_id": str(picked_card.get("instance_id", "")),
						"source_zone": ZONE_DECK,
						"target_zone": ZONE_HAND,
						"reason": reason,
					})
			"discard":
				var discard_targets := [] if effect.has("target_player") and not effect.has("target") else _resolve_card_targets(match_state, trigger, event, effect)
				if discard_targets.is_empty() and effect.has("target_player"):
					for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var discard_result := MatchMutations.discard_from_hand(match_state, player_id, int(effect.get("count", 1)), {
							"selection": str(effect.get("selection", "front")),
						})
						generated_events.append_array(discard_result.get("events", []))
				else:
					for card in discard_targets:
						var discard_result := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
						generated_events.append_array(discard_result.get("events", []))
			"banish":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var banish_result := MatchMutations.banish_card(match_state, str(card.get("instance_id", "")))
					generated_events.append_array(banish_result.get("events", []))
			"banish_and_return_end_of_turn":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var bar_controller_id := str(card.get("controller_player_id", card.get("owner_player_id", "")))
					var bar_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					var bar_lane_id := str(bar_location.get("lane_id", ""))
					var bar_snapshot: Dictionary = card.duplicate(true)
					var bar_result := MatchMutations.banish_card(match_state, str(card.get("instance_id", "")))
					generated_events.append_array(bar_result.get("events", []))
					if bool(bar_result.get("is_valid", false)):
						var pending: Array = match_state.get("pending_eot_returns", [])
						pending.append({
							"card_snapshot": bar_snapshot,
							"controller_player_id": bar_controller_id,
							"lane_id": bar_lane_id,
							"turn_number": int(match_state.get("turn_number", 0)),
						})
						match_state["pending_eot_returns"] = pending
			"unsummon":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var unsummon_result := MatchMutations.unsummon_card(match_state, str(card.get("instance_id", "")))
					generated_events.append_array(unsummon_result.get("events", []))
			"sacrifice":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var sacrifice_result := MatchMutations.sacrifice_card(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")))
					generated_events.append_array(sacrifice_result.get("events", []))
			"silence":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					if _is_immune_to_effect(match_state, card, "silence"):
						continue
					var silence_result := MatchMutations.silence_card(card, {"reason": reason})
					generated_events.append_array(silence_result.get("events", []))
			"shackle":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					if _is_immune_to_effect(match_state, card, "shackle"):
						continue
					EvergreenRules.add_status(card, EvergreenRules.STATUS_SHACKLED)
					card["shackle_expires_on_turn"] = int(match_state.get("turn_number", 0)) + 1
					generated_events.append({"event_type": "status_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "status_id": "shackled", "reason": reason})
			"battle_creature":
				var battle_source_id := str(trigger.get("source_instance_id", ""))
				var battle_source := _find_card_anywhere(match_state, battle_source_id)
				for defender in _resolve_card_targets(match_state, trigger, event, effect):
					if battle_source.is_empty():
						break
					var attacker_power := maxi(0, EvergreenRules.get_power(battle_source))
					var defender_power := maxi(0, EvergreenRules.get_power(defender))
					var defender_remaining_before := EvergreenRules.get_remaining_health(defender)
					var attacker_remaining_before := EvergreenRules.get_remaining_health(battle_source)
					var defender_damage_result := EvergreenRules.apply_damage_to_creature(defender, attacker_power)
					var attacker_damage_result := EvergreenRules.apply_damage_to_creature(battle_source, defender_power)
					if bool(defender_damage_result.get("ward_removed", false)):
						generated_events.append({"event_type": "ward_removed", "source_instance_id": battle_source_id, "target_instance_id": str(defender.get("instance_id", ""))})
					if bool(attacker_damage_result.get("ward_removed", false)):
						generated_events.append({"event_type": "ward_removed", "source_instance_id": str(defender.get("instance_id", "")), "target_instance_id": battle_source_id})
					var applied_to_defender := int(defender_damage_result.get("applied", 0))
					var applied_to_attacker := int(attacker_damage_result.get("applied", 0))
					if applied_to_defender > 0:
						generated_events.append({"event_type": "damage_resolved", "source_instance_id": battle_source_id, "source_controller_player_id": str(battle_source.get("controller_player_id", "")), "target_instance_id": str(defender.get("instance_id", "")), "target_type": "creature", "amount": applied_to_defender, "damage_kind": "combat", "reason": reason})
					if applied_to_attacker > 0:
						generated_events.append({"event_type": "damage_resolved", "source_instance_id": str(defender.get("instance_id", "")), "source_controller_player_id": str(defender.get("controller_player_id", "")), "target_instance_id": battle_source_id, "target_type": "creature", "amount": applied_to_attacker, "damage_kind": "combat", "reason": reason})
					var defender_has_lethal := EvergreenRules.has_keyword(defender, EvergreenRules.KEYWORD_LETHAL)
					var attacker_has_lethal := EvergreenRules.has_keyword(battle_source, EvergreenRules.KEYWORD_LETHAL)
					var defender_destroyed := EvergreenRules.is_creature_destroyed(defender, applied_to_defender > 0 and attacker_has_lethal)
					var attacker_destroyed := EvergreenRules.is_creature_destroyed(battle_source, applied_to_attacker > 0 and defender_has_lethal)
					# Handle breakthrough on attacker
					if defender_destroyed and EvergreenRules.has_keyword(battle_source, EvergreenRules.KEYWORD_BREAKTHROUGH):
						var bt_damage := maxi(0, attacker_power - defender_remaining_before)
						if bt_damage > 0:
							var defending_player_id := str(defender.get("controller_player_id", ""))
							var bt_result := apply_player_damage(match_state, defending_player_id, bt_damage, {"reason": "breakthrough", "source_instance_id": battle_source_id, "source_controller_player_id": str(battle_source.get("controller_player_id", ""))})
							var applied_bt := int(bt_result.get("applied_damage", 0))
							if applied_bt > 0:
								generated_events.append({"event_type": "damage_resolved", "source_instance_id": battle_source_id, "source_controller_player_id": str(battle_source.get("controller_player_id", "")), "target_type": "player", "target_player_id": defending_player_id, "amount": applied_bt, "damage_kind": "breakthrough"})
								generated_events.append_array(bt_result.get("events", []))
								append_match_win_if_needed(match_state, defending_player_id, str(battle_source.get("controller_player_id", "")), generated_events)
					if defender_destroyed:
						var def_loc := MatchMutations.find_card_location(match_state, str(defender.get("instance_id", "")))
						if bool(def_loc.get("is_valid", false)):
							var def_controller := str(defender.get("controller_player_id", ""))
							var def_moved := MatchMutations.discard_card(match_state, str(defender.get("instance_id", "")))
							if bool(def_moved.get("is_valid", false)):
								generated_events.append({"event_type": "creature_destroyed", "instance_id": str(defender.get("instance_id", "")), "source_instance_id": str(defender.get("instance_id", "")), "owner_player_id": str(defender.get("owner_player_id", "")), "controller_player_id": def_controller, "destroyed_by_instance_id": battle_source_id, "lane_id": str(def_loc.get("lane_id", "")), "source_zone": ZONE_LANE})
					if attacker_destroyed:
						var atk_loc := MatchMutations.find_card_location(match_state, battle_source_id)
						if bool(atk_loc.get("is_valid", false)):
							var atk_controller := str(battle_source.get("controller_player_id", ""))
							var atk_moved := MatchMutations.discard_card(match_state, battle_source_id)
							if bool(atk_moved.get("is_valid", false)):
								generated_events.append({"event_type": "creature_destroyed", "instance_id": battle_source_id, "source_instance_id": battle_source_id, "owner_player_id": str(battle_source.get("owner_player_id", "")), "controller_player_id": atk_controller, "destroyed_by_instance_id": str(defender.get("instance_id", "")), "lane_id": str(atk_loc.get("lane_id", "")), "source_zone": ZONE_LANE})
			"destroy_creature":
				var destroy_source_id := str(trigger.get("source_instance_id", ""))
				var dc_max_power := int(effect.get("max_power", -1))
				if dc_max_power >= 0:
					var dc_empower_bonus := int(effect.get("empower_bonus", 0))
					if dc_empower_bonus > 0:
						dc_max_power += dc_empower_bonus * _get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					if dc_max_power >= 0 and EvergreenRules.get_power(card) > dc_max_power:
						continue
					var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					if not bool(card_location.get("is_valid", false)):
						continue
					var controller_pid := str(card.get("controller_player_id", ""))
					var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
					if bool(moved.get("is_valid", false)):
						generated_events.append({
							"event_type": "creature_destroyed",
							"instance_id": str(card.get("instance_id", "")),
							"source_instance_id": str(card.get("instance_id", "")),
							"owner_player_id": str(card.get("owner_player_id", "")),
							"controller_player_id": controller_pid,
							"destroyed_by_instance_id": destroy_source_id,
							"lane_id": str(card_location.get("lane_id", "")),
							"source_zone": ZONE_LANE,
						})
			"generate_card_to_hand":
				var gen_template: Dictionary = effect.get("card_template", {})
				if gen_template.is_empty():
					# Fall back to resolved target card as template (e.g. treasure_card_copy)
					var gen_target_cards := _resolve_card_targets(match_state, trigger, event, effect)
					if not gen_target_cards.is_empty():
						gen_template = gen_target_cards[0].duplicate(true)
						# Clear instance_id so build_generated_card assigns a fresh one
						gen_template.erase("instance_id")
				if gen_template.is_empty():
					continue
				var gen_count := int(effect.get("count", 1))
				var gen_force_play := bool(effect.get("force_play", false))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var gen_player := _get_player_state(match_state, player_id)
					if gen_player.is_empty():
						continue
					var hand: Array = gen_player.get(ZONE_HAND, [])
					for _i in range(gen_count):
						var generated_card := MatchMutations.build_generated_card(match_state, player_id, gen_template)
						if _overflow_card_to_discard(gen_player, generated_card, player_id, ZONE_GENERATED, generated_events):
							continue
						generated_card["zone"] = ZONE_HAND
						hand.append(generated_card)
						MatchMutations.apply_first_turn_hand_cost(match_state, generated_card, player_id)
						generated_events.append({"event_type": "card_drawn", "player_id": player_id, "source_instance_id": str(generated_card.get("instance_id", "")), "reason": reason})
						if gen_force_play:
							var gen_pending: Array = match_state.get("pending_forced_plays", [])
							gen_pending.append({"player_id": player_id, "instance_id": str(generated_card.get("instance_id", ""))})
			"change":
				var change_template := _resolve_effect_template(match_state, trigger, event, effect)
				if change_template.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var change_result := MatchMutations.change_card(card, change_template, {"reason": reason})
					generated_events.append_array(change_result.get("events", []))
			"copy":
				var source_cards := _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source")))
				if source_cards.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var copy_result := MatchMutations.copy_card(card, source_cards[0], {
						"preserve_modifiers": bool(effect.get("preserve_modifiers", false)),
						"preserve_damage": bool(effect.get("preserve_damage", false)),
						"preserve_statuses": bool(effect.get("preserve_statuses", false)),
					})
					generated_events.append_array(copy_result.get("events", []))
			"transform":
				var transform_template := _resolve_effect_template(match_state, trigger, event, effect)
				if transform_template.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var transform_result := MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), transform_template, {"reason": reason})
					generated_events.append_array(transform_result.get("events", []))
			"steal":
				var stealing_players := _resolve_player_targets(match_state, trigger, event, effect)
				if stealing_players.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var steal_result := MatchMutations.steal_card(match_state, stealing_players[0], str(card.get("instance_id", "")), {
						"slot_index": int(effect.get("slot_index", -1)),
					})
					generated_events.append_array(steal_result.get("events", []))
			"consume":
				var consumers := _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("consumer_target", "self")))
				if consumers.is_empty():
					continue
				var consumer: Dictionary = consumers[0]
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var consume_result := MatchMutations.consume_card(match_state, str(consumer.get("controller_player_id", "")), str(consumer.get("instance_id", "")), str(card.get("instance_id", "")), {
						"reason": reason,
						"destination_zone": str(effect.get("destination_zone", MatchMutations.ZONE_DISCARD)),
					})
					generated_events.append_array(consume_result.get("events", []))
			"move_between_lanes":
				var raw_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", event.get("lane_id", ""))))
				if raw_lane_id != "other_lane" and raw_lane_id.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var dest_lane_id := raw_lane_id
					if dest_lane_id == "other_lane":
						var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
						var current_lane_id := str(card_location.get("lane_id", ""))
						dest_lane_id = ""
						for lane in match_state.get("lanes", []):
							var lid := str(lane.get("lane_id", ""))
							if lid != current_lane_id and not lid.is_empty():
								dest_lane_id = lid
								break
					if dest_lane_id.is_empty():
						continue
					var move_result := MatchMutations.move_card_between_lanes(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")), dest_lane_id, {
						"slot_index": int(effect.get("slot_index", -1)),
						"preserve_entered_lane_on_turn": true,
					})
					generated_events.append_array(move_result.get("events", []))
					if bool(move_result.get("granted_cover", false)):
						generated_events.append({
							"event_type": "status_granted",
							"source_instance_id": str(card.get("instance_id", "")),
							"target_instance_id": str(card.get("instance_id", "")),
							"status_id": "cover",
						})
			"summon_from_effect":
				var summon_players := _resolve_player_targets(match_state, trigger, event, effect)
				if summon_players.is_empty():
					continue
				var summon_lane_ids: Array = []
				if bool(effect.get("all_lanes", false)):
					for lane in match_state.get("lanes", []):
						summon_lane_ids.append(str(lane.get("lane_id", "")))
				else:
					var single_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", effect.get("lane", event.get("lane_id", "")))))
					if single_lane_id == "same":
						single_lane_id = str(event.get("lane_id", ""))
					if single_lane_id == "other_lane" or single_lane_id == "other":
						var source_lane_id := str(event.get("lane_id", ""))
						if source_lane_id.is_empty():
							var tli := int(trigger.get("lane_index", -1))
							var all_lanes: Array = match_state.get("lanes", [])
							if tli >= 0 and tli < all_lanes.size():
								source_lane_id = str(all_lanes[tli].get("lane_id", ""))
						for lane in match_state.get("lanes", []):
							var lid := str(lane.get("lane_id", ""))
							if lid != source_lane_id and not lid.is_empty():
								single_lane_id = lid
								break
					if single_lane_id.is_empty() or single_lane_id == "other_lane" or single_lane_id == "other":
						var trigger_lane_index := int(trigger.get("lane_index", -1))
						var lanes: Array = match_state.get("lanes", [])
						if trigger_lane_index >= 0 and trigger_lane_index < lanes.size():
							single_lane_id = str(lanes[trigger_lane_index].get("lane_id", ""))
					if single_lane_id.is_empty() or single_lane_id == "other_lane" or single_lane_id == "other":
						continue
					summon_lane_ids.append(single_lane_id)
				if bool(effect.get("require_wounded_enemy_in_lane", false)):
					var controller_id := str(trigger.get("controller_player_id", ""))
					var opp_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
					var filtered_lane_ids: Array = []
					for check_lane in match_state.get("lanes", []):
						var check_lid := str(check_lane.get("lane_id", ""))
						if not summon_lane_ids.has(check_lid):
							continue
						var has_wounded := false
						for card in check_lane.get("player_slots", {}).get(opp_id, []):
							if typeof(card) == TYPE_DICTIONARY and int(card.get("damage_marked", 0)) > 0:
								has_wounded = true
								break
						if has_wounded:
							filtered_lane_ids.append(check_lid)
					summon_lane_ids = filtered_lane_ids
				var summon_template: Dictionary = effect.get("card_template", {})
				if summon_template.is_empty():
					for source_card in _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source"))):
						for s_lane_id in summon_lane_ids:
							var summon_existing := MatchMutations.summon_card_to_lane(match_state, summon_players[0], str(source_card.get("instance_id", "")), s_lane_id, {
								"slot_index": int(effect.get("slot_index", -1)),
							})
							if not bool(summon_existing.get("is_valid", false)):
								continue
							generated_events.append_array(summon_existing.get("events", []))
							generated_events.append(_build_summon_event(summon_existing["card"], summon_players[0], s_lane_id, int(summon_existing.get("slot_index", -1)), reason))
							if bool(summon_existing.get("granted_cover", false)):
								generated_events.append({"event_type": "status_granted", "source_instance_id": str(summon_existing["card"].get("instance_id", "")), "target_instance_id": str(summon_existing["card"].get("instance_id", "")), "status_id": "cover"})
							_check_summon_abilities(match_state, summon_existing["card"])
				else:
					var sfe_empower_stat := int(effect.get("empower_stat_bonus", 0))
					var sfe_stat_bonus := 0
					if sfe_empower_stat > 0:
						sfe_stat_bonus = sfe_empower_stat * _get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
					var sfe_template := summon_template
					if sfe_stat_bonus > 0:
						sfe_template = summon_template.duplicate(true)
						sfe_template["power"] = int(sfe_template.get("power", 0)) + sfe_stat_bonus
						sfe_template["health"] = int(sfe_template.get("health", 0)) + sfe_stat_bonus
						sfe_template["base_power"] = int(sfe_template.get("base_power", 0)) + sfe_stat_bonus
						sfe_template["base_health"] = int(sfe_template.get("base_health", 0)) + sfe_stat_bonus
					for player_id in summon_players:
						for s_lane_id in summon_lane_ids:
							var generated_card := MatchMutations.build_generated_card(match_state, player_id, sfe_template)
							var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, generated_card, s_lane_id, {
								"slot_index": int(effect.get("slot_index", -1)),
								"source_zone": MatchMutations.ZONE_GENERATED,
							})
							if not bool(summon_result.get("is_valid", false)):
								continue
							generated_events.append_array(summon_result.get("events", []))
							generated_events.append(_build_summon_event(summon_result["card"], player_id, s_lane_id, int(summon_result.get("slot_index", -1)), reason))
							if bool(summon_result.get("granted_cover", false)):
								generated_events.append({"event_type": "status_granted", "source_instance_id": str(summon_result["card"].get("instance_id", "")), "target_instance_id": str(summon_result["card"].get("instance_id", "")), "status_id": "cover"})
							_check_summon_abilities(match_state, summon_result["card"])
			"fill_lane_with":
				var fill_controller_id := str(trigger.get("controller_player_id", ""))
				var fill_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", event.get("lane_id", ""))))
				var fill_template: Dictionary = effect.get("card_template", {})
				if fill_lane_id.is_empty() or fill_controller_id.is_empty() or fill_template.is_empty():
					continue
				var fill_open := _get_lane_open_slots(match_state, fill_lane_id, fill_controller_id)
				var fill_count := int(fill_open.get("open_slots", 0))
				for _i in range(fill_count):
					var fill_card := MatchMutations.build_generated_card(match_state, fill_controller_id, fill_template)
					var fill_result := MatchMutations.summon_card_to_lane(match_state, fill_controller_id, fill_card, fill_lane_id, {
						"source_zone": MatchMutations.ZONE_GENERATED,
					})
					if not bool(fill_result.get("is_valid", false)):
						break
					generated_events.append_array(fill_result.get("events", []))
					generated_events.append(_build_summon_event(fill_result["card"], fill_controller_id, fill_lane_id, int(fill_result.get("slot_index", -1)), reason))
					if bool(fill_result.get("granted_cover", false)):
						generated_events.append({"event_type": "status_granted", "source_instance_id": str(fill_result["card"].get("instance_id", "")), "target_instance_id": str(fill_result["card"].get("instance_id", "")), "status_id": "cover"})
			"summon_copies_to_lane":
				var copies_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", event.get("lane_id", ""))))
				var copies_players := _resolve_player_targets(match_state, trigger, event, effect)
				var copies_template: Dictionary = effect.get("card_template", {})
				if copies_lane_id.is_empty() or copies_players.is_empty() or copies_template.is_empty():
					continue
				var copies_count := int(effect.get("count", 0))
				var fill_lane := bool(effect.get("fill_lane", false))
				for player_id in copies_players:
					var remaining := copies_count
					if fill_lane:
						var lane_data := _get_lane_open_slots(match_state, copies_lane_id, player_id)
						remaining = int(lane_data.get("open_slots", 0))
					for _i in range(remaining):
						var gen_card := MatchMutations.build_generated_card(match_state, player_id, copies_template)
						var summon_res := MatchMutations.summon_card_to_lane(match_state, player_id, gen_card, copies_lane_id, {
							"source_zone": MatchMutations.ZONE_GENERATED,
						})
						if not bool(summon_res.get("is_valid", false)):
							break
						generated_events.append_array(summon_res.get("events", []))
						generated_events.append(_build_summon_event(summon_res["card"], player_id, copies_lane_id, int(summon_res.get("slot_index", -1)), reason))
			"summon_copy_to_other_lane":
				var copy_sources := _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source")))
				if copy_sources.is_empty():
					continue
				var copy_source: Dictionary = copy_sources[0]
				var source_lane_id := str(event.get("lane_id", ""))
				var other_lane_id := ""
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) != source_lane_id:
						other_lane_id = str(lane.get("lane_id", ""))
						break
				if other_lane_id.is_empty():
					continue
				var copy_template := copy_source.duplicate(true)
				copy_template.erase("instance_id")
				copy_template.erase("zone")
				copy_template.erase("damage_marked")
				copy_template.erase("power_bonus")
				copy_template.erase("health_bonus")
				copy_template.erase("granted_keywords")
				copy_template.erase("status_markers")
				var copy_player_id := str(trigger.get("controller_player_id", ""))
				var gen_card := MatchMutations.build_generated_card(match_state, copy_player_id, copy_template)
				var summon_res := MatchMutations.summon_card_to_lane(match_state, copy_player_id, gen_card, other_lane_id, {
					"source_zone": MatchMutations.ZONE_GENERATED,
				})
				if bool(summon_res.get("is_valid", false)):
					generated_events.append_array(summon_res.get("events", []))
					generated_events.append(_build_summon_event(summon_res["card"], copy_player_id, other_lane_id, int(summon_res.get("slot_index", -1)), reason))
			"draw_from_discard_filtered":
				var discard_filter_card_type := str(effect.get("required_card_type", ""))
				var discard_filter_subtype := str(effect.get("required_subtype", ""))
				var discard_filter_match := str(effect.get("filter_match", ""))
				var is_player_choice := bool(effect.get("player_choice", false))
				# Resolve consumed creature name for filter matching
				var discard_filter_name := ""
				if discard_filter_match == "consumed_creature_name":
					var dfm_consumed := _get_consumed_card_info(trigger)
					if dfm_consumed.is_empty():
						var dfm_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
						if not dfm_source.is_empty():
							dfm_consumed = dfm_source.get("_consumed_card_info", {})
					discard_filter_name = str(dfm_consumed.get("definition_id", ""))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var discard_player := _get_player_state(match_state, player_id)
					if discard_player.is_empty():
						continue
					var discard_pile: Array = discard_player.get(ZONE_DISCARD, [])
					var discard_candidates: Array = []
					var candidate_instance_ids: Array = []
					for d_index in range(discard_pile.size()):
						var d_card = discard_pile[d_index]
						if typeof(d_card) != TYPE_DICTIONARY:
							continue
						if not discard_filter_card_type.is_empty() and str(d_card.get("card_type", "")) != discard_filter_card_type:
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
						continue
					if is_player_choice:
						match_state["pending_discard_choices"].append({
							"player_id": player_id,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"candidate_instance_ids": candidate_instance_ids,
							"buff_power": int(effect.get("buff_power", 0)),
							"buff_health": int(effect.get("buff_health", 0)),
							"reason": reason,
						})
					else:
						var pick_idx: int = discard_candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_draw_discard", discard_candidates.size())]
						var picked_discard_card: Dictionary = discard_pile[pick_idx]
						discard_pile.remove_at(pick_idx)
						if _overflow_card_to_discard(discard_player, picked_discard_card, player_id, ZONE_DISCARD, generated_events):
							continue
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
			"equip_items_from_discard":
				var equip_self := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if equip_self.is_empty():
					continue
				var equip_count := int(effect.get("count", 2))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var equip_player := _get_player_state(match_state, player_id)
					if equip_player.is_empty():
						continue
					var equip_discard: Array = equip_player.get(ZONE_DISCARD, [])
					var item_candidates: Array = []
					for edi in range(equip_discard.size()):
						var ed_card = equip_discard[edi]
						if typeof(ed_card) == TYPE_DICTIONARY and str(ed_card.get("card_type", "")) == CARD_TYPE_ITEM:
							item_candidates.append({"index": edi, "cost": int(ed_card.get("cost", 0))})
					item_candidates.sort_custom(func(a, b): return int(a.get("cost", 0)) > int(b.get("cost", 0)))
					var equipped := 0
					for candidate in item_candidates:
						if equipped >= equip_count:
							break
						var pick_idx: int = int(candidate.get("index", 0))
						for already_equipped in range(equipped):
							if pick_idx > 0:
								pick_idx -= 1
						var actual_item: Dictionary = equip_discard[pick_idx]
						equip_discard.remove_at(pick_idx)
						var attach_result := MatchMutations.attach_item_to_creature(match_state, player_id, actual_item, str(equip_self.get("instance_id", "")), {"source_zone": ZONE_DISCARD})
						if bool(attach_result.get("is_valid", false)):
							generated_events.append_array(attach_result.get("events", []))
							equipped += 1
			"shuffle_hand_to_deck_and_draw":
				var shuffle_filter_tag := str(effect.get("required_rules_tag", ""))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var shuffle_player := _get_player_state(match_state, player_id)
					if shuffle_player.is_empty():
						continue
					var hand: Array = shuffle_player.get(ZONE_HAND, [])
					var deck: Array = shuffle_player.get(ZONE_DECK, [])
					var to_shuffle: Array = []
					for hi in range(hand.size() - 1, -1, -1):
						var h_card = hand[hi]
						if typeof(h_card) != TYPE_DICTIONARY:
							continue
						if not shuffle_filter_tag.is_empty():
							var tags = h_card.get("rules_tags", [])
							if typeof(tags) != TYPE_ARRAY or not tags.has(shuffle_filter_tag):
								continue
						to_shuffle.append(h_card)
						hand.remove_at(hi)
					var draw_count := to_shuffle.size()
					for shuffled_card in to_shuffle:
						shuffled_card["zone"] = ZONE_DECK
						var ins_pos := _deterministic_index(match_state, str(shuffled_card.get("instance_id", "")) + "_shuffle_back", deck.size() + 1)
						deck.insert(ins_pos, shuffled_card)
					if draw_count > 0:
						var redraw_result := draw_cards(match_state, player_id, draw_count, {"reason": reason, "source_instance_id": str(trigger.get("source_instance_id", ""))})
						generated_events.append_array(redraw_result.get("events", []))
			"change_lane_types":
				var new_lane_type := str(effect.get("lane_type", "shadow"))
				for lane in match_state.get("lanes", []):
					lane["lane_type"] = new_lane_type
					generated_events.append({"event_type": "lane_type_changed", "lane_id": str(lane.get("lane_id", "")), "new_lane_type": new_lane_type, "source_instance_id": str(trigger.get("source_instance_id", ""))})
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
							var fake_event := {"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "source_instance_id": str(card.get("instance_id", "")), "controller_player_id": tflg_controller_id}
							var fake_resolution := _build_trigger_resolution(match_state, fake_trigger, fake_event)
							generated_events.append_array(_apply_effects(match_state, fake_trigger, fake_event, fake_resolution))
			"summon_random_from_discard":
				var srd_filter_card_type := str(effect.get("required_card_type", "creature"))
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var srd_player := _get_player_state(match_state, player_id)
					if srd_player.is_empty():
						continue
					var srd_discard: Array = srd_player.get(ZONE_DISCARD, [])
					var srd_candidates: Array = []
					for srd_i in range(srd_discard.size()):
						var srd_card = srd_discard[srd_i]
						if typeof(srd_card) != TYPE_DICTIONARY:
							continue
						if not srd_filter_card_type.is_empty() and str(srd_card.get("card_type", "")) != srd_filter_card_type:
							continue
						srd_candidates.append(srd_i)
					if srd_candidates.is_empty():
						continue
					var srd_pick: int = srd_candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_srd", srd_candidates.size())]
					var srd_picked: Dictionary = srd_discard[srd_pick]
					srd_discard.remove_at(srd_pick)
					MatchMutations.reset_transient_state(srd_picked)
					var srd_lane_id := ""
					var srd_lane_index := int(trigger.get("lane_index", -1))
					var srd_lanes: Array = match_state.get("lanes", [])
					if srd_lane_index >= 0 and srd_lane_index < srd_lanes.size():
						srd_lane_id = str(srd_lanes[srd_lane_index].get("lane_id", ""))
					if srd_lane_id.is_empty():
						srd_lane_id = str(event.get("lane_id", ""))
					if srd_lane_id.is_empty() and not srd_lanes.is_empty():
						srd_lane_id = str(srd_lanes[0].get("lane_id", ""))
					if srd_lane_id.is_empty():
						continue
					var srd_result := MatchMutations.summon_card_to_lane(match_state, player_id, srd_picked, srd_lane_id, {})
					if bool(srd_result.get("is_valid", false)):
						generated_events.append_array(srd_result.get("events", []))
						generated_events.append(_build_summon_event(srd_result["card"], player_id, srd_lane_id, int(srd_result.get("slot_index", -1)), reason))
			"destroy_all_except_random":
				var controller_id := str(trigger.get("controller_player_id", ""))
				var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
				var destroy_source_id := str(trigger.get("source_instance_id", ""))
				for lane in match_state.get("lanes", []):
					var lane_id := str(lane.get("lane_id", ""))
					var player_slots: Dictionary = lane.get("player_slots", {})
					for pid in player_slots.keys():
						var slots: Array = player_slots[pid]
						if slots.size() <= 1:
							continue
						var survivor_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_survivor_" + str(pid) + "_" + lane_id, slots.size())
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
			"steal_items":
				var steal_items_receiver := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if steal_items_receiver.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var items_to_steal: Array = card.get("attached_items", []).duplicate()
					for item in items_to_steal:
						if typeof(item) != TYPE_DICTIONARY:
							continue
						var host_items: Array = card.get("attached_items", [])
						var idx := -1
						for i in range(host_items.size()):
							if typeof(host_items[i]) == TYPE_DICTIONARY and str(host_items[i].get("instance_id", "")) == str(item.get("instance_id", "")):
								idx = i
								break
						if idx >= 0:
							host_items.remove_at(idx)
							card["attached_items"] = host_items
						item["controller_player_id"] = str(trigger.get("controller_player_id", ""))
						var receiver_items: Array = steal_items_receiver.get("attached_items", [])
						receiver_items.append(item)
						steal_items_receiver["attached_items"] = receiver_items
						generated_events.append({"event_type": "item_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "item_instance_id": str(item.get("instance_id", ""))})
			"steal_keywords":
				var steal_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if steal_source.is_empty():
					continue
				EvergreenRules.ensure_card_state(steal_source)
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					for kw in RANDOM_KEYWORD_POOL:
						if EvergreenRules.has_keyword(card, kw):
							EvergreenRules.remove_keyword(card, kw)
							var granted: Array = steal_source.get("granted_keywords", [])
							if not granted.has(kw):
								granted.append(kw)
								steal_source["granted_keywords"] = granted
							generated_events.append({"event_type": "keyword_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": kw})
			"copy_keywords_to_friendly":
				var kw_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if kw_source.is_empty():
					continue
				var source_keywords: Array = []
				for kw in RANDOM_KEYWORD_POOL:
					if EvergreenRules.has_keyword(kw_source, kw):
						source_keywords.append(kw)
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					EvergreenRules.ensure_card_state(card)
					var granted: Array = card.get("granted_keywords", [])
					for kw in source_keywords:
						if not granted.has(kw):
							granted.append(kw)
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": kw})
					card["granted_keywords"] = granted
			"grant_extra_attack":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["has_attacked_this_turn"] = false
					generated_events.append({
						"event_type": "extra_attack_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
					})
			"copy_from_opponent_deck":
				var copy_filter_card_type := str(effect.get("required_card_type", ""))
				var controller_id := str(trigger.get("controller_player_id", ""))
				var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
				var opponent := _get_player_state(match_state, opponent_id)
				if opponent.is_empty():
					continue
				var opp_deck: Array = opponent.get(ZONE_DECK, [])
				var copy_candidates: Array = []
				for d_idx in range(opp_deck.size()):
					var d_card = opp_deck[d_idx]
					if typeof(d_card) != TYPE_DICTIONARY:
						continue
					if not copy_filter_card_type.is_empty() and str(d_card.get("card_type", "")) != copy_filter_card_type:
						continue
					copy_candidates.append(d_idx)
				if copy_candidates.is_empty():
					continue
				var pick: int = copy_candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_copy_opp", copy_candidates.size())]
				var source_card_for_copy: Dictionary = opp_deck[pick]
				var copy_tmpl: Dictionary = source_card_for_copy.duplicate(true)
				copy_tmpl.erase("instance_id")
				copy_tmpl.erase("zone")
				copy_tmpl.erase("damage_marked")
				copy_tmpl.erase("power_bonus")
				copy_tmpl.erase("health_bonus")
				copy_tmpl.erase("granted_keywords")
				copy_tmpl.erase("status_markers")
				var gen_copy := MatchMutations.build_generated_card(match_state, controller_id, copy_tmpl)
				var cth_player := _get_player_state(match_state, controller_id)
				if not cth_player.is_empty():
					if _overflow_card_to_discard(cth_player, gen_copy, controller_id, ZONE_GENERATED, generated_events):
						continue
					gen_copy["zone"] = ZONE_HAND
					var cth_hand: Array = cth_player.get(ZONE_HAND, [])
					cth_hand.append(gen_copy)
					generated_events.append({"event_type": "card_drawn", "player_id": controller_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "drawn_instance_id": str(gen_copy.get("instance_id", "")), "reason": reason})
			"double_stats":
				var ds_stat := str(effect.get("stat", "both"))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var current_power := EvergreenRules.get_power(card)
					var current_health := EvergreenRules.get_health(card)
					var power_bonus := current_power if ds_stat in ["both", "power"] else 0
					var health_bonus := current_health if ds_stat in ["both", "health"] else 0
					EvergreenRules.apply_stat_bonus(card, power_bonus, health_bonus, reason)
					generated_events.append({
						"event_type": "stats_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"power_bonus": power_bonus,
						"health_bonus": health_bonus,
						"reason": reason,
					})
			"set_stats":
				var set_power_val: Variant = effect.get("power", null)
				var set_health_val: Variant = effect.get("health", null)
				for card in _resolve_card_targets(match_state, trigger, event, effect):
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
				var sp_value := int(effect.get("value", 1))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var power_diff := sp_value - EvergreenRules.get_power(card)
					EvergreenRules.apply_stat_bonus(card, power_diff, 0, reason)
					generated_events.append({
						"event_type": "stats_set",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"new_power": EvergreenRules.get_power(card),
						"reason": reason,
					})
			"summon_copy":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var sc_controller := str(card.get("controller_player_id", trigger.get("controller_player_id", "")))
					var sc_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					var sc_lane_id := str(sc_loc.get("lane_id", event.get("lane_id", "field")))
					var sc_template: Dictionary = card.duplicate(true)
					sc_template.erase("instance_id")
					sc_template.erase("status_markers")
					sc_template.erase("has_attacked_this_turn")
					sc_template.erase("entered_lane_on_turn")
					var sc_copy := MatchMutations.build_generated_card(match_state, sc_controller, sc_template)
					var sc_summon := MatchMutations.summon_card_to_lane(match_state, sc_controller, sc_copy, sc_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
					if bool(sc_summon.get("is_valid", false)):
						generated_events.append_array(sc_summon.get("events", []))
						generated_events.append(_build_summon_event(sc_summon["card"], sc_controller, sc_lane_id, int(sc_summon.get("slot_index", -1)), "summon_copy"))
			"summon_copy_of_self":
				var scos_source_id := str(trigger.get("source_instance_id", ""))
				var scos_source := _find_card_anywhere(match_state, scos_source_id)
				if not scos_source.is_empty():
					var scos_controller := str(scos_source.get("controller_player_id", ""))
					var scos_loc := MatchMutations.find_card_location(match_state, scos_source_id)
					var scos_lane_id := str(scos_loc.get("lane_id", event.get("lane_id", "field")))
					var scos_template: Dictionary = scos_source.duplicate(true)
					scos_template.erase("instance_id")
					scos_template.erase("status_markers")
					scos_template.erase("has_attacked_this_turn")
					var scos_copy := MatchMutations.build_generated_card(match_state, scos_controller, scos_template)
					var scos_summon := MatchMutations.summon_card_to_lane(match_state, scos_controller, scos_copy, scos_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
					if bool(scos_summon.get("is_valid", false)):
						generated_events.append_array(scos_summon.get("events", []))
						generated_events.append(_build_summon_event(scos_summon["card"], scos_controller, scos_lane_id, int(scos_summon.get("slot_index", -1)), "summon_copy_of_self"))
			"deal_damage_from_creature":
				var ddfc_amount := int(effect.get("amount", 1))
				var ddfc_source_target := str(effect.get("source", "event_target"))
				var ddfc_source_id := ""
				if ddfc_source_target == "event_target":
					ddfc_source_id = _event_target_instance_id(event)
				else:
					ddfc_source_id = str(trigger.get("source_instance_id", ""))
				var ddfc_source := _find_card_anywhere(match_state, ddfc_source_id)
				if ddfc_source.is_empty():
					continue
				var ddfc_secondary_id := str(trigger.get("_secondary_target_id", ""))
				if not ddfc_secondary_id.is_empty():
					var ddfc_defender := _find_card_anywhere(match_state, ddfc_secondary_id)
					if not ddfc_defender.is_empty():
						var ddfc_result := EvergreenRules.apply_damage_to_creature(ddfc_defender, ddfc_amount)
						generated_events.append({"event_type": "damage_resolved", "source_instance_id": ddfc_source_id, "source_controller_player_id": str(ddfc_source.get("controller_player_id", "")), "target_instance_id": ddfc_secondary_id, "target_type": "creature", "amount": int(ddfc_result.get("applied", 0)), "damage_kind": "ability", "reason": reason})
						if EvergreenRules.is_creature_destroyed(ddfc_defender, false):
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
			"shuffle_copies_to_deck":
				var sctd_count := int(effect.get("count", 1))
				var sctd_cost_override: Variant = effect.get("cost_override", null)
				var sctd_controller := str(trigger.get("controller_player_id", ""))
				var sctd_player := _get_player_state(match_state, sctd_controller)
				var sctd_source_id := str(event.get("source_instance_id", trigger.get("source_instance_id", "")))
				var sctd_source := _find_card_anywhere(match_state, sctd_source_id)
				if not sctd_player.is_empty() and not sctd_source.is_empty():
					var sctd_deck: Array = sctd_player.get(ZONE_DECK, [])
					for ci in range(sctd_count):
						var copy_template: Dictionary = sctd_source.duplicate(true)
						copy_template.erase("instance_id")
						copy_template.erase("status_markers")
						if sctd_cost_override != null:
							copy_template["cost"] = int(sctd_cost_override)
						var sctd_copy := MatchMutations.build_generated_card(match_state, sctd_controller, copy_template)
						sctd_copy["zone"] = ZONE_DECK
						var insert_pos := _deterministic_index(match_state, str(sctd_copy.get("instance_id", "")) + "_sctd", sctd_deck.size() + 1)
						sctd_deck.insert(insert_pos, sctd_copy)
					generated_events.append({"event_type": "copies_shuffled_to_deck", "player_id": sctd_controller, "count": sctd_count, "reason": reason})
			"shuffle_discard_creatures_to_deck_with_buff":
				var sdctd_power := int(effect.get("power", 0))
				var sdctd_health := int(effect.get("health", 0))
				var sdctd_controller := str(trigger.get("controller_player_id", ""))
				var sdctd_player := _get_player_state(match_state, sdctd_controller)
				if not sdctd_player.is_empty():
					var sdctd_discard: Array = sdctd_player.get(ZONE_DISCARD, [])
					var sdctd_deck: Array = sdctd_player.get(ZONE_DECK, [])
					var sdctd_to_move: Array = []
					for card in sdctd_discard:
						if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature":
							sdctd_to_move.append(card)
					for card in sdctd_to_move:
						sdctd_discard.erase(card)
						EvergreenRules.apply_stat_bonus(card, sdctd_power, sdctd_health, reason)
						card["zone"] = ZONE_DECK
						var insert_pos := _deterministic_index(match_state, str(card.get("instance_id", "")) + "_sdctd", sdctd_deck.size() + 1)
						sdctd_deck.insert(insert_pos, card)
					generated_events.append({"event_type": "discard_shuffled_to_deck", "player_id": sdctd_controller, "count": sdctd_to_move.size(), "power_buff": sdctd_power, "health_buff": sdctd_health, "reason": reason})
			"summon_from_discard":
				var sfd_controller := str(trigger.get("controller_player_id", ""))
				var sfd_player := _get_player_state(match_state, sfd_controller)
				if sfd_player.is_empty():
					continue
				var sfd_discard: Array = sfd_player.get(ZONE_DISCARD, [])
				var sfd_source_id := str(trigger.get("source_instance_id", ""))
				var sfd_source := _find_card_anywhere(match_state, sfd_source_id)
				var sfd_source_power := EvergreenRules.get_power(sfd_source) if not sfd_source.is_empty() else 999
				# Build candidate list from discard
				var sfd_candidates: Array = []
				var sfd_candidate_ids: Array = []
				for di in range(sfd_discard.size()):
					var d_card: Variant = sfd_discard[di]
					if typeof(d_card) == TYPE_DICTIONARY and str(d_card.get("card_type", "")) == "creature":
						if EvergreenRules.get_power(d_card) < sfd_source_power:
							sfd_candidates.append(di)
							sfd_candidate_ids.append(str(d_card.get("instance_id", "")))
				if sfd_candidates.is_empty():
					continue
				var sfd_chosen_id := str(trigger.get("_chosen_target_id", ""))
				if sfd_chosen_id.is_empty():
					# Push pending discard choice for UI
					match_state["pending_discard_choices"].append({
						"player_id": sfd_controller,
						"source_instance_id": sfd_source_id,
						"candidate_instance_ids": sfd_candidate_ids,
						"then_op": "summon_from_discard",
						"reason": "summon_from_discard",
					})
					generated_events.append({"event_type": "discard_choice_pending", "player_id": sfd_controller})
					continue
				# Resolve with chosen target
				var sfd_card: Dictionary = {}
				var sfd_idx := -1
				for di in range(sfd_discard.size()):
					if typeof(sfd_discard[di]) == TYPE_DICTIONARY and str(sfd_discard[di].get("instance_id", "")) == sfd_chosen_id:
						sfd_card = sfd_discard[di]
						sfd_idx = di
						break
				if sfd_card.is_empty() or sfd_idx < 0:
					continue
				sfd_discard.remove_at(sfd_idx)
				var sfd_source_loc := MatchMutations.find_card_location(match_state, sfd_source_id)
				var sfd_lane_id := str(sfd_source_loc.get("lane_id", ""))
				if sfd_lane_id.is_empty():
					sfd_lane_id = str(event.get("lane_id", "field"))
				var sfd_summon := MatchMutations.summon_card_to_lane(match_state, sfd_controller, sfd_card, sfd_lane_id, {"source_zone": ZONE_DISCARD})
				if bool(sfd_summon.get("is_valid", false)):
					generated_events.append_array(sfd_summon.get("events", []))
					generated_events.append(_build_summon_event(sfd_summon["card"], sfd_controller, sfd_lane_id, int(sfd_summon.get("slot_index", -1)), "summon_from_discard"))
			"delayed_destroy":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var dd_pending: Array = match_state.get("pending_delayed_destroys", [])
					dd_pending.append({
						"target_instance_id": str(card.get("instance_id", "")),
						"controller_player_id": str(trigger.get("controller_player_id", "")),
						"on_destroy_effects": effect.get("on_destroy_effects", []),
						"source_instance_id": str(trigger.get("source_instance_id", "")),
					})
					match_state["pending_delayed_destroys"] = dd_pending
					generated_events.append({"event_type": "delayed_destroy_scheduled", "target_instance_id": str(card.get("instance_id", "")), "reason": reason})
			"sacrifice_and_resummon":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var sar_def_id := str(card.get("definition_id", ""))
					var sar_controller := str(card.get("controller_player_id", ""))
					var sar_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					var sar_lane_id := str(sar_loc.get("lane_id", ""))
					var sar_lane_index := int(sar_loc.get("lane_index", -1))
					var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
					if bool(moved.get("is_valid", false)):
						generated_events.append({"event_type": "creature_destroyed", "instance_id": str(card.get("instance_id", "")), "reason": "sacrifice_and_resummon"})
						var sar_template := {"definition_id": sar_def_id}
						var sar_copy := MatchMutations.build_generated_card(match_state, sar_controller, sar_template)
						if sar_lane_index >= 0:
							var sar_summon := MatchMutations.summon_card_to_lane(match_state, sar_controller, sar_copy, sar_lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
							if bool(sar_summon.get("is_valid", false)):
								generated_events.append_array(sar_summon.get("events", []))
								generated_events.append(_build_summon_event(sar_summon["card"], sar_controller, sar_lane_id, int(sar_summon.get("slot_index", -1)), "sacrifice_and_resummon"))
			"equip_item", "equip_generated_item":
				var ei_template_raw = effect.get("card_template", {})
				var ei_template: Dictionary = ei_template_raw if typeof(ei_template_raw) == TYPE_DICTIONARY else {}
				if ei_template.is_empty():
					continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var ei_controller := str(card.get("controller_player_id", trigger.get("controller_player_id", "")))
					var ei_item := MatchMutations.build_generated_card(match_state, ei_controller, ei_template)
					var ei_result := MatchMutations.attach_item_to_creature(match_state, ei_controller, ei_item, str(card.get("instance_id", "")), {"source_zone": MatchMutations.ZONE_GENERATED})
					if bool(ei_result.get("is_valid", false)):
						generated_events.append_array(ei_result.get("events", []))
						generated_events.append({"event_type": "item_equipped", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "item_instance_id": str(ei_item.get("instance_id", "")), "reason": reason})
			"reduce_cost_in_hand":
				var rcih_amount := int(effect.get("amount", 1))
				var rcih_controller := str(trigger.get("controller_player_id", ""))
				var rcih_player := _get_player_state(match_state, rcih_controller)
				if not rcih_player.is_empty():
					var rcih_hand: Array = rcih_player.get(ZONE_HAND, [])
					var rcih_target := str(effect.get("target", ""))
					for card in rcih_hand:
						if typeof(card) != TYPE_DICTIONARY:
							continue
						if rcih_target == "all_creatures_in_hand" and str(card.get("card_type", "")) != "creature":
							continue
						var current_cost := int(card.get("cost", 0))
						card["cost"] = maxi(0, current_cost - rcih_amount)
					generated_events.append({"event_type": "hand_costs_reduced", "player_id": rcih_controller, "amount": rcih_amount, "reason": reason})
			"battle_strongest_enemy":
				for attacker in _resolve_card_targets(match_state, trigger, event, effect):
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
						continue
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
						generated_events.append_array(_apply_effects(match_state, patched, event, {"effects": [{"op": "battle_creature", "target": "chosen_target"}]}))
			"battle_random_enemy":
				for attacker in _resolve_card_targets(match_state, trigger, event, effect):
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
						var pick: Dictionary = enemies[_deterministic_index(match_state, str(attacker.get("instance_id", "")) + "_bre", enemies.size())]
						var patched := trigger.duplicate(true)
						patched["source_instance_id"] = str(attacker.get("instance_id", ""))
						patched["_chosen_target_id"] = str(pick.get("instance_id", ""))
						generated_events.append_array(_apply_effects(match_state, patched, event, {"effects": [{"op": "battle_creature", "target": "chosen_target"}]}))
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
						continue
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var current_power := EvergreenRules.get_power(card)
					var current_health := EvergreenRules.get_health(card)
					var power_bonus := current_power if cds_stat in ["both", "power"] else 0
					var health_bonus := current_health if cds_stat in ["both", "health"] else 0
					EvergreenRules.apply_stat_bonus(card, power_bonus, health_bonus, reason)
					generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "power_bonus": power_bonus, "health_bonus": health_bonus, "reason": reason})
			"secretly_choose_creature":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var scc_source_id := str(trigger.get("source_instance_id", ""))
					var scc_source := _find_card_anywhere(match_state, scc_source_id)
					if not scc_source.is_empty():
						scc_source["_secretly_chosen_target_id"] = str(card.get("instance_id", ""))
						generated_events.append({"event_type": "creature_secretly_chosen", "source_instance_id": scc_source_id, "target_instance_id": str(card.get("instance_id", "")), "reason": reason})
			"choose_one":
				var co_choices_raw = effect.get("choices", [])
				var co_choices: Array = co_choices_raw if typeof(co_choices_raw) == TYPE_ARRAY else []
				if co_choices.is_empty():
					continue
				var co_options: Array = []
				var co_effects_per_option: Array = []
				for co_choice in co_choices:
					if typeof(co_choice) != TYPE_DICTIONARY:
						continue
					co_options.append({"label": str(co_choice.get("label", "")), "description": str(co_choice.get("description", ""))})
					co_effects_per_option.append(co_choice.get("effects", []))
				var co_pending: Array = match_state.get("pending_player_choices", [])
				co_pending.append({
					"player_id": str(trigger.get("controller_player_id", "")),
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"prompt": "Choose one:",
					"mode": "text",
					"options": co_options,
					"effects_per_option": co_effects_per_option,
					"trigger": trigger.duplicate(true),
					"event": event.duplicate(true),
				})
				generated_events.append({"event_type": "player_choice_pending", "player_id": str(trigger.get("controller_player_id", "")), "source_instance_id": str(trigger.get("source_instance_id", "")), "reason": reason})
			"copy_rallied_creature_to_hand":
				var crch_target_id := str(event.get("target_instance_id", ""))
				var crch_target := _find_card_anywhere(match_state, crch_target_id)
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
					var crch_player := _get_player_state(match_state, crch_controller)
					if not crch_player.is_empty():
						var crch_hand: Array = crch_player.get(ZONE_HAND, [])
						crch_hand.append(crch_copy)
						generated_events.append({"event_type": "card_generated_to_hand", "player_id": crch_controller, "instance_id": str(crch_copy.get("instance_id", "")), "reason": reason})
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
							var teaf_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
							var teaf_trigger: Dictionary = ability.duplicate(true)
							teaf_trigger["source_instance_id"] = str(card.get("instance_id", ""))
							teaf_trigger["controller_player_id"] = teaf_controller
							teaf_trigger["lane_index"] = int(teaf_loc.get("lane_index", -1))
							generated_events.append_array(_apply_effects(match_state, teaf_trigger, event, {"effects": teaf_trigger.get("effects", [])}))
							generated_events.append({"event_type": "exalt_triggered", "instance_id": str(card.get("instance_id", "")), "reason": reason})
							break
			"unsummon_end_of_turn":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var ueot_pending: Array = match_state.get("pending_end_of_turn_unsummons", [])
					ueot_pending.append(str(card.get("instance_id", "")))
					match_state["pending_end_of_turn_unsummons"] = ueot_pending
					generated_events.append({"event_type": "unsummon_scheduled", "instance_id": str(card.get("instance_id", "")), "reason": reason})
			"may_move_between_lanes":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var mml_controller := str(card.get("controller_player_id", ""))
					var mml_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					if bool(mml_loc.get("is_valid", false)):
						var mml_current_lane := str(mml_loc.get("lane_id", ""))
						var mml_target_lane := "shadow" if mml_current_lane == "field" else "field"
						var mml_result := MatchMutations.move_card_between_lanes(match_state, mml_controller, str(card.get("instance_id", "")), mml_target_lane)
						if bool(mml_result.get("is_valid", false)):
							generated_events.append_array(mml_result.get("events", []))
			"move_back_end_of_turn":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var mbeot_pending: Array = match_state.get("pending_move_backs", [])
					mbeot_pending.append(str(card.get("instance_id", "")))
					match_state["pending_move_backs"] = mbeot_pending
					generated_events.append({"event_type": "move_back_scheduled", "instance_id": str(card.get("instance_id", "")), "reason": reason})
			"add_support_uses":
				var asu_amount := int(effect.get("amount", 1))
				var asu_empower_bonus := int(effect.get("empower_bonus", 0))
				if asu_empower_bonus > 0:
					asu_amount += asu_empower_bonus * _get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
				var asu_controller := str(trigger.get("controller_player_id", ""))
				var asu_player := _get_player_state(match_state, asu_controller)
				if not asu_player.is_empty():
					for card in asu_player.get(ZONE_SUPPORT, []):
						if typeof(card) == TYPE_DICTIONARY:
							var current_uses := int(card.get("remaining_support_uses", card.get("support_uses", 0)))
							card["remaining_support_uses"] = current_uses + asu_amount
					generated_events.append({"event_type": "support_uses_added", "player_id": asu_controller, "amount": asu_amount, "reason": reason})
			"grant_double_activate":
				var gda_controller := str(trigger.get("controller_player_id", ""))
				match_state["double_activate_" + gda_controller] = true
				generated_events.append({"event_type": "double_activate_granted", "player_id": gda_controller, "reason": reason})
			"trigger_summon_ability":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var tsa_abilities: Array = card.get("triggered_abilities", [])
					for ability in tsa_abilities:
						if typeof(ability) != TYPE_DICTIONARY:
							continue
						if str(ability.get("family", "")) == FAMILY_SUMMON:
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
							var tsa_resolution := {"effects": tsa_trigger.get("effects", [])}
							generated_events.append_array(_apply_effects(match_state, tsa_trigger, tsa_fake_event, tsa_resolution))
							break
			"grant_immunity":
				var gi_type := str(effect.get("immunity_type", ""))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var gi_immunities: Array = card.get("self_immunity", [])
					if typeof(gi_immunities) != TYPE_ARRAY:
						gi_immunities = []
					if not gi_immunities.has(gi_type):
						gi_immunities.append(gi_type)
					card["self_immunity"] = gi_immunities
					generated_events.append({"event_type": "immunity_granted", "target_instance_id": str(card.get("instance_id", "")), "immunity_type": gi_type, "reason": reason})
			"grant_pilfer_draw", "grant_slay_draw":
				var gpd_family := "pilfer" if op == "grant_pilfer_draw" else "slay"
				var gpd_is_temp := str(effect.get("duration", "")) == "end_of_turn"
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var gpd_abilities: Array = card.get("triggered_abilities", [])
					var gpd_new_trigger := {
						"family": gpd_family,
						"required_zone": "lane",
						"effects": [{"op": "draw_cards", "target_player": "controller", "count": 1}],
					}
					if gpd_is_temp:
						gpd_new_trigger["expires_on_turn"] = int(match_state.get("turn_number", 0))
					gpd_abilities.append(gpd_new_trigger)
					card["triggered_abilities"] = gpd_abilities
					generated_events.append({"event_type": "ability_granted", "target_instance_id": str(card.get("instance_id", "")), "family": gpd_family, "reason": reason})
			"draw_from_deck_filtered":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var dfdf_player := _get_player_state(match_state, player_id)
					if dfdf_player.is_empty():
						continue
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
						if dfdf_match:
							dfdf_candidates.append(di)
					if not dfdf_candidates.is_empty():
						var pick_idx: int = dfdf_candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_dfdf", dfdf_candidates.size())]
						var drawn: Dictionary = dfdf_deck[pick_idx]
						dfdf_deck.remove_at(pick_idx)
						drawn["zone"] = ZONE_HAND
						var dfdf_hand: Array = dfdf_player.get(ZONE_HAND, [])
						dfdf_hand.append(drawn)
						generated_events.append({"event_type": "card_drawn", "player_id": player_id, "instance_id": str(drawn.get("instance_id", "")), "source": "draw_from_deck_filtered", "reason": reason})
			"draw_specific_from_deck":
				var dsfd_source_id := str(trigger.get("source_instance_id", ""))
				var dsfd_controller := str(trigger.get("controller_player_id", ""))
				var dsfd_player := _get_player_state(match_state, dsfd_controller)
				if not dsfd_player.is_empty():
					var dsfd_deck: Array = dsfd_player.get(ZONE_DECK, [])
					for di in range(dsfd_deck.size()):
						if typeof(dsfd_deck[di]) == TYPE_DICTIONARY and str(dsfd_deck[di].get("definition_id", "")) == str(_find_card_anywhere(match_state, dsfd_source_id).get("definition_id", "")):
							var drawn: Dictionary = dsfd_deck[di]
							dsfd_deck.remove_at(di)
							drawn["zone"] = ZONE_HAND
							var dsfd_hand: Array = dsfd_player.get(ZONE_HAND, [])
							dsfd_hand.append(drawn)
							generated_events.append({"event_type": "card_drawn", "player_id": dsfd_controller, "instance_id": str(drawn.get("instance_id", "")), "source": "draw_specific_from_deck", "reason": reason})
							break
			"draw_all_creatures_from_discard":
				var dacfd_controller := str(trigger.get("controller_player_id", ""))
				var dacfd_player := _get_player_state(match_state, dacfd_controller)
				if not dacfd_player.is_empty():
					var dacfd_discard: Array = dacfd_player.get(ZONE_DISCARD, [])
					var dacfd_hand: Array = dacfd_player.get(ZONE_HAND, [])
					var dacfd_to_draw: Array = []
					for card in dacfd_discard:
						if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature":
							dacfd_to_draw.append(card)
					for card in dacfd_to_draw:
						dacfd_discard.erase(card)
						card["zone"] = ZONE_HAND
						dacfd_hand.append(card)
						generated_events.append({"event_type": "card_drawn", "player_id": dacfd_controller, "instance_id": str(card.get("instance_id", "")), "source": "draw_all_creatures_from_discard", "reason": reason})
			"buff_random_hand_card":
				var brhc_power := int(effect.get("power", 0))
				var brhc_health := int(effect.get("health", 0))
				var brhc_controller := str(trigger.get("controller_player_id", ""))
				var brhc_player := _get_player_state(match_state, brhc_controller)
				if not brhc_player.is_empty():
					var brhc_hand: Array = brhc_player.get(ZONE_HAND, [])
					var brhc_filter_raw = effect.get("filter", {})
					var brhc_filter: Dictionary = brhc_filter_raw if typeof(brhc_filter_raw) == TYPE_DICTIONARY else {}
					var brhc_filter_type := str(brhc_filter.get("card_type", ""))
					var brhc_candidates: Array = []
					for card in brhc_hand:
						if typeof(card) != TYPE_DICTIONARY:
							continue
						if not brhc_filter_type.is_empty() and str(card.get("card_type", "")) != brhc_filter_type:
							continue
						brhc_candidates.append(card)
					if not brhc_candidates.is_empty():
						var pick: Dictionary = brhc_candidates[_deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_brhc", brhc_candidates.size())]
						EvergreenRules.apply_stat_bonus(pick, brhc_power, brhc_health, reason)
						generated_events.append({"event_type": "hand_card_buffed", "player_id": brhc_controller, "instance_id": str(pick.get("instance_id", "")), "power": brhc_power, "health": brhc_health, "reason": reason})
			"buff_creatures_in_deck", "buff_creatures_in_discard", "buff_items_in_deck":
				var bcid_power := int(effect.get("power", 0))
				var bcid_health := int(effect.get("health", 0))
				var bcid_controller := str(trigger.get("controller_player_id", ""))
				var bcid_player := _get_player_state(match_state, bcid_controller)
				if not bcid_player.is_empty():
					var bcid_zone_name := ZONE_DISCARD if op == "buff_creatures_in_discard" else ZONE_DECK
					var bcid_zone: Array = bcid_player.get(bcid_zone_name, [])
					var bcid_filter_type := "item" if op == "buff_items_in_deck" else "creature"
					var bcid_filter_subtype := str(effect.get("filter_subtype", ""))
					for card in bcid_zone:
						if typeof(card) != TYPE_DICTIONARY:
							continue
						if str(card.get("card_type", "")) != bcid_filter_type:
							continue
						if not bcid_filter_subtype.is_empty():
							var subtypes: Array = card.get("subtypes", [])
							if typeof(subtypes) != TYPE_ARRAY or not subtypes.has(bcid_filter_subtype):
								continue
						EvergreenRules.apply_stat_bonus(card, bcid_power, bcid_health, reason)
					generated_events.append({"event_type": "zone_buffed", "player_id": bcid_controller, "zone": bcid_zone_name, "power": bcid_power, "health": bcid_health, "reason": reason})
			"discard_hand":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var player := _get_player_state(match_state, player_id)
					if player.is_empty():
						continue
					var hand: Array = player.get(ZONE_HAND, [])
					var discard: Array = player.get(ZONE_DISCARD, [])
					for card in hand:
						if typeof(card) == TYPE_DICTIONARY:
							card["zone"] = ZONE_DISCARD
							discard.append(card)
							generated_events.append({"event_type": "card_discarded", "player_id": player_id, "instance_id": str(card.get("instance_id", "")), "source": "discard_hand", "reason": reason})
					hand.clear()
			"discard_hand_end_of_turn":
				var dheoet_player_id := str(trigger.get("controller_player_id", ""))
				var dheoet_pending: Array = match_state.get("pending_end_of_turn_discards", [])
				dheoet_pending.append(dheoet_player_id)
				match_state["pending_end_of_turn_discards"] = dheoet_pending
				generated_events.append({"event_type": "discard_hand_scheduled", "player_id": dheoet_player_id, "reason": reason})
			"discard_top_of_deck":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var player := _get_player_state(match_state, player_id)
					if player.is_empty():
						continue
					var deck: Array = player.get(ZONE_DECK, [])
					if deck.is_empty():
						continue
					var top_card: Dictionary = deck.pop_back()
					top_card["zone"] = ZONE_DISCARD
					var discard: Array = player.get(ZONE_DISCARD, [])
					discard.append(top_card)
					generated_events.append({
						"event_type": "card_discarded",
						"player_id": player_id,
						"instance_id": str(top_card.get("instance_id", "")),
						"source": "discard_top_of_deck",
						"reason": reason,
					})
			"sacrifice_if_no_ward":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					if not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_WARD):
						var loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
						if bool(loc.get("is_valid", false)):
							var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
							if bool(moved.get("is_valid", false)):
								generated_events.append({
									"event_type": "creature_destroyed",
									"instance_id": str(card.get("instance_id", "")),
									"reason": "sacrifice_if_no_ward",
								})
			"swap_stats":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
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
			"set_power_equal_to_health":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
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
			"copy_card_to_hand":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var copy_template: Dictionary = card.duplicate(true)
					copy_template.erase("instance_id")
					copy_template.erase("zone")
					copy_template.erase("damage_marked")
					copy_template.erase("power_bonus")
					copy_template.erase("health_bonus")
					copy_template.erase("granted_keywords")
					copy_template.erase("status_markers")
					for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var gen_card := MatchMutations.build_generated_card(match_state, player_id, copy_template)
						var ccth_player := _get_player_state(match_state, player_id)
						if ccth_player.is_empty():
							continue
						if _overflow_card_to_discard(ccth_player, gen_card, player_id, ZONE_GENERATED, generated_events):
							continue
						gen_card["zone"] = ZONE_HAND
						var ccth_hand: Array = ccth_player.get(ZONE_HAND, [])
						ccth_hand.append(gen_card)
						generated_events.append({"event_type": "card_drawn", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "drawn_instance_id": str(gen_card.get("instance_id", "")), "reason": reason})
			"return_to_hand":
				var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not source_card.is_empty():
					var rth_owner_id := str(source_card.get("owner_player_id", ""))
					var rth_player := _get_player_state(match_state, rth_owner_id)
					if not rth_player.is_empty() and rth_player.get(ZONE_HAND, []).size() >= MAX_HAND_SIZE:
						var move_result := MatchMutations.move_card_to_zone(match_state, str(source_card.get("instance_id", "")), ZONE_DISCARD, {"reason": reason})
						generated_events.append_array(move_result.get("events", []))
						generated_events.append({
							"event_type": EVENT_CARD_OVERDRAW,
							"player_id": rth_owner_id,
							"instance_id": str(source_card.get("instance_id", "")),
							"card_name": str(source_card.get("name", "")),
							"source_zone": str(source_card.get("zone", "")),
						})
					else:
						var move_result := MatchMutations.move_card_to_zone(match_state, str(source_card.get("instance_id", "")), ZONE_HAND, {"reason": reason})
						generated_events.append_array(move_result.get("events", []))
			"generate_card_to_deck":
				var gen_template: Dictionary = effect.get("card_template", {})
				if not gen_template.is_empty():
					for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var gen_card := MatchMutations.build_generated_card(match_state, player_id, gen_template)
						var player := _get_player_state(match_state, player_id)
						if player.is_empty():
							continue
						var deck: Array = player.get(ZONE_DECK, [])
						gen_card["zone"] = ZONE_DECK
						var insert_pos := _deterministic_index(match_state, str(gen_card.get("instance_id", "")), deck.size() + 1)
						deck.insert(insert_pos, gen_card)
						generated_events.append({"event_type": "card_shuffled_to_deck", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "inserted_instance_id": str(gen_card.get("instance_id", "")), "reason": reason})
			"select_card_from_hand":
				var sch_controller_id := str(trigger.get("controller_player_id", ""))
				var sch_player := _get_player_state(match_state, sch_controller_id)
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
						})
			"remove_status":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var status_id := str(effect.get("status_id", ""))
					if status_id == EvergreenRules.STATUS_COVER:
						EvergreenRules.remove_status(card, EvergreenRules.STATUS_COVER)
						card.erase("cover_expires_on_turn")
						card.erase("cover_granted_by")
					else:
						EvergreenRules.remove_status(card, status_id)
					generated_events.append({
						"event_type": "status_removed",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"status_id": status_id,
					})
			"restore_magicka":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var rm_player := _get_player_state(match_state, player_id)
					if rm_player.is_empty():
						continue
					var restored := int(rm_player.get("max_magicka", 0)) - int(rm_player.get("current_magicka", 0))
					rm_player["current_magicka"] = int(rm_player.get("max_magicka", 0))
					generated_events.append({
						"event_type": "magicka_restored",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_player_id": player_id,
						"amount": restored,
					})
			"mill":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var mill_player := _get_player_state(match_state, player_id)
					if mill_player.is_empty():
						continue
					var mill_deck: Array = mill_player.get(ZONE_DECK, [])
					var mill_discard: Array = mill_player.get(ZONE_DISCARD, [])
					var mill_count := int(effect.get("count", 1))
					for _i in range(mill_count):
						if mill_deck.is_empty():
							break
						var milled_card: Dictionary = mill_deck.pop_back()
						milled_card["zone"] = ZONE_DISCARD
						mill_discard.push_front(milled_card)
						generated_events.append({
							"event_type": "card_milled",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"player_id": player_id,
							"milled_instance_id": str(milled_card.get("instance_id", "")),
						})
			"discard_from_hand":
				var dfh_controller_id := str(trigger.get("controller_player_id", ""))
				var dfh_target_player := str(effect.get("target_player", "controller"))
				var dfh_player_id := dfh_controller_id if dfh_target_player == "controller" else _get_opposing_player_id(match_state.get("players", []), dfh_controller_id)
				var dfh_count := int(effect.get("count", 1))
				var dfh_result := MatchMutations.discard_from_hand(match_state, dfh_player_id, dfh_count, {"reason": reason})
				generated_events.append_array(dfh_result.get("events", []))
			"discard_random":
				var dr_controller_id := str(trigger.get("controller_player_id", ""))
				var dr_target_player := str(effect.get("target_player", "opponent"))
				var dr_player_id := dr_controller_id if dr_target_player == "controller" else _get_opposing_player_id(match_state.get("players", []), dr_controller_id)
				var dr_player := _get_player_state(match_state, dr_player_id)
				if not dr_player.is_empty():
					var dr_hand: Array = dr_player.get(ZONE_HAND, [])
					if not dr_hand.is_empty():
						var dr_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_discard_random", dr_hand.size())
						var dr_card: Dictionary = dr_hand[dr_idx]
						var dr_discard_result := MatchMutations.discard_card(match_state, str(dr_card.get("instance_id", "")), {"reason": reason})
						generated_events.append_array(dr_discard_result.get("events", []))
			"shuffle_into_deck":
				var sid_template: Dictionary = effect.get("card_template", {})
				if not sid_template.is_empty():
					for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var sid_card := MatchMutations.build_generated_card(match_state, player_id, sid_template)
						var sid_player := _get_player_state(match_state, player_id)
						if sid_player.is_empty():
							continue
						var sid_deck: Array = sid_player.get(ZONE_DECK, [])
						sid_card["zone"] = ZONE_DECK
						var sid_pos := _deterministic_index(match_state, str(sid_card.get("instance_id", "")), sid_deck.size() + 1)
						sid_deck.insert(sid_pos, sid_card)
						generated_events.append({"event_type": "card_shuffled_to_deck", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "inserted_instance_id": str(sid_card.get("instance_id", "")), "reason": reason})
			"shuffle_copies_into_deck":
				var scid_template: Dictionary = effect.get("card_template", {})
				var scid_count := int(effect.get("count", 2))
				if not scid_template.is_empty():
					for player_id in _resolve_player_targets(match_state, trigger, event, effect):
						var scid_player := _get_player_state(match_state, player_id)
						if scid_player.is_empty():
							continue
						var scid_deck: Array = scid_player.get(ZONE_DECK, [])
						for _i in range(scid_count):
							var scid_card := MatchMutations.build_generated_card(match_state, player_id, scid_template)
							scid_card["zone"] = ZONE_DECK
							var scid_pos := _deterministic_index(match_state, str(scid_card.get("instance_id", "")), scid_deck.size() + 1)
							scid_deck.insert(scid_pos, scid_card)
							generated_events.append({"event_type": "card_shuffled_to_deck", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "inserted_instance_id": str(scid_card.get("instance_id", "")), "reason": reason})
			"shuffle_self_into_deck":
				var ssid_source_id := str(trigger.get("source_instance_id", ""))
				var ssid_source := _find_card_anywhere(match_state, ssid_source_id)
				if not ssid_source.is_empty():
					var ssid_controller := str(ssid_source.get("controller_player_id", ""))
					var ssid_template: Dictionary = effect.get("card_template", {})
					if not ssid_template.is_empty():
						MatchMutations.change_card(ssid_source, ssid_template)
					var ssid_move := MatchMutations.move_card_to_zone(match_state, ssid_source_id, ZONE_DECK, {"reason": reason})
					generated_events.append_array(ssid_move.get("events", []))
					var ssid_player := _get_player_state(match_state, ssid_controller)
					if not ssid_player.is_empty():
						var ssid_deck: Array = ssid_player.get(ZONE_DECK, [])
						var ssid_idx := ssid_deck.find(ssid_source)
						if ssid_idx >= 0:
							ssid_deck.remove_at(ssid_idx)
							var new_pos := _deterministic_index(match_state, ssid_source_id + "_shuffle", ssid_deck.size() + 1)
							ssid_deck.insert(new_pos, ssid_source)
			"banish_discard_pile":
				var bdp_controller_id := str(trigger.get("controller_player_id", ""))
				var bdp_target := str(effect.get("target_player", "opponent"))
				var bdp_player_id := bdp_controller_id if bdp_target == "controller" else _get_opposing_player_id(match_state.get("players", []), bdp_controller_id)
				var bdp_player := _get_player_state(match_state, bdp_player_id)
				if not bdp_player.is_empty():
					var bdp_discard: Array = bdp_player.get(ZONE_DISCARD, [])
					var bdp_ids: Array = []
					for bdp_card in bdp_discard:
						bdp_ids.append(str(bdp_card.get("instance_id", "")))
					for bdp_id in bdp_ids:
						var bdp_result := MatchMutations.banish_card(match_state, bdp_id, {"reason": reason})
						generated_events.append_array(bdp_result.get("events", []))
			"set_health":
				var sh_amount := int(effect.get("amount", 0))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["health"] = sh_amount
					card["base_health"] = sh_amount
					EvergreenRules.ensure_card_state(card)
					generated_events.append({
						"event_type": "stats_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"reason": reason,
					})
			"set_power_to_health":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var sph_health := int(card.get("health", 0))
					card["power"] = sph_health
					card["base_power"] = sph_health
					EvergreenRules.ensure_card_state(card)
					generated_events.append({
						"event_type": "stats_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"reason": reason,
					})
			"double_health":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var dh_current := int(card.get("health", 0))
					card["health"] = dh_current * 2
					card["base_health"] = int(card.get("base_health", 0)) * 2
					EvergreenRules.ensure_card_state(card)
					generated_events.append({
						"event_type": "stats_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"health_bonus": dh_current,
						"reason": reason,
					})
			"destroy_creature_end_of_turn":
				var dceot_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not dceot_source.is_empty():
					dceot_source["_destroy_at_end_of_turn"] = int(match_state.get("turn_number", 0))
					generated_events.append({
						"event_type": "marked_for_destruction",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(dceot_source.get("instance_id", "")),
					})
			"deal_damage_to_lane":
				var ddtl_source_id := str(trigger.get("source_instance_id", ""))
				var ddtl_source := _find_card_anywhere(match_state, ddtl_source_id)
				if not ddtl_source.is_empty() and str(ddtl_source.get("zone", "")) == ZONE_LANE:
					var ddtl_power := int(ddtl_source.get("power", 0))
					if ddtl_power <= 0:
						continue
					var ddtl_location := MatchMutations.find_card_location(match_state, ddtl_source_id)
					var ddtl_lane_id := str(ddtl_location.get("lane_id", ""))
					if ddtl_lane_id.is_empty():
						continue
					generated_events.append({"event_type": "lane_aoe_damage", "source_instance_id": ddtl_source_id, "lane_id": ddtl_lane_id, "amount": ddtl_power})
					for ddtl_lane in match_state.get("lanes", []):
						if str(ddtl_lane.get("lane_id", "")) != ddtl_lane_id:
							continue
						for ddtl_player_slots in ddtl_lane.get("player_slots", []):
							for ddtl_card in ddtl_player_slots.get("cards", []):
								if typeof(ddtl_card) != TYPE_DICTIONARY:
									continue
								if str(ddtl_card.get("instance_id", "")) == ddtl_source_id:
									continue
								var ddtl_dmg_result := EvergreenRules.apply_damage_to_creature(ddtl_card, ddtl_power)
								generated_events.append({
									"event_type": EVENT_DAMAGE_RESOLVED,
									"source_instance_id": ddtl_source_id,
									"target_instance_id": str(ddtl_card.get("instance_id", "")),
									"amount": ddtl_power,
									"damage_kind": "ability",
									"ward_removed": bool(ddtl_dmg_result.get("ward_removed", false)),
								})
								if int(ddtl_card.get("health", 0)) <= 0:
									var ddtl_destroy := MatchMutations.discard_card(match_state, str(ddtl_card.get("instance_id", "")), {"reason": "deal_damage_to_lane"})
									generated_events.append({
										"event_type": EVENT_CREATURE_DESTROYED,
										"instance_id": str(ddtl_card.get("instance_id", "")),
										"controller_player_id": str(ddtl_card.get("controller_player_id", "")),
										"killer_instance_id": ddtl_source_id,
										"lane_id": ddtl_lane_id,
									})
									generated_events.append_array(ddtl_destroy.get("events", []))
			"steal_from_discard", "draw_from_opponent_discard":
				var sfd_controller_id := str(trigger.get("controller_player_id", ""))
				var sfd_opponent_id := _get_opposing_player_id(match_state.get("players", []), sfd_controller_id)
				var sfd_opponent := _get_player_state(match_state, sfd_opponent_id)
				var sfd_controller := _get_player_state(match_state, sfd_controller_id)
				if not sfd_opponent.is_empty() and not sfd_controller.is_empty():
					var sfd_discard: Array = sfd_opponent.get(ZONE_DISCARD, [])
					if not sfd_discard.is_empty():
						var sfd_filter := str(effect.get("filter_card_type", ""))
						var sfd_candidates: Array = []
						for sfd_card in sfd_discard:
							if sfd_filter.is_empty() or str(sfd_card.get("card_type", "")) == sfd_filter:
								sfd_candidates.append(sfd_card)
						if not sfd_candidates.is_empty():
							var sfd_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_steal_discard", sfd_candidates.size())
							var sfd_stolen: Dictionary = sfd_candidates[sfd_idx]
							sfd_discard.erase(sfd_stolen)
							sfd_stolen["zone"] = ZONE_HAND
							sfd_stolen["controller_player_id"] = sfd_controller_id
							sfd_stolen["owner_player_id"] = sfd_controller_id
							var sfd_hand: Array = sfd_controller.get(ZONE_HAND, [])
							sfd_hand.append(sfd_stolen)
							generated_events.append({
								"event_type": "card_stolen_from_discard",
								"source_instance_id": str(trigger.get("source_instance_id", "")),
								"stolen_instance_id": str(sfd_stolen.get("instance_id", "")),
								"from_player_id": sfd_opponent_id,
								"to_player_id": sfd_controller_id,
							})
			"banish_from_opponent_deck", "banish_by_name_from_opponent":
				var bfod_controller_id := str(trigger.get("controller_player_id", ""))
				var bfod_opponent_id := _get_opposing_player_id(match_state.get("players", []), bfod_controller_id)
				var bfod_count := int(effect.get("count", 2))
				var bfod_count_per_attr := int(effect.get("count_per_attribute", 0))
				if bfod_count_per_attr > 0:
					var bfod_opp_attrs := _count_player_attributes(match_state, bfod_opponent_id)
					var bfod_empower_bonus := int(effect.get("empower_bonus", 0))
					var bfod_per_attr := bfod_count_per_attr
					if bfod_empower_bonus > 0:
						bfod_per_attr += bfod_empower_bonus * _get_empower_amount(match_state, bfod_controller_id)
					bfod_count = bfod_per_attr * bfod_opp_attrs
				else:
					var bfod_empower_bonus := int(effect.get("empower_bonus", 0))
					if bfod_empower_bonus > 0:
						bfod_count += bfod_empower_bonus * _get_empower_amount(match_state, bfod_controller_id)
				var bfod_opponent := _get_player_state(match_state, bfod_opponent_id)
				if not bfod_opponent.is_empty():
					var bfod_deck: Array = bfod_opponent.get(ZONE_DECK, [])
					var banished_count := 0
					var bfod_ids: Array = []
					for bfod_card in bfod_deck:
						bfod_ids.append(str(bfod_card.get("instance_id", "")))
					for bfod_id in bfod_ids:
						if banished_count >= bfod_count:
							break
						var bfod_result := MatchMutations.banish_card(match_state, bfod_id, {"reason": reason})
						generated_events.append_array(bfod_result.get("events", []))
						banished_count += 1
			"discard_matching_from_opponent_deck":
				var dmfod_controller_id := str(trigger.get("controller_player_id", ""))
				var dmfod_opponent_id := _get_opposing_player_id(match_state.get("players", []), dmfod_controller_id)
				var dmfod_opponent := _get_player_state(match_state, dmfod_opponent_id)
				var dmfod_target_name := ""
				for dmfod_card in _resolve_card_targets(match_state, trigger, event, effect):
					dmfod_target_name = str(dmfod_card.get("name", ""))
					break
				if not dmfod_opponent.is_empty() and not dmfod_target_name.is_empty():
					var dmfod_deck: Array = dmfod_opponent.get(ZONE_DECK, [])
					var dmfod_ids: Array = []
					for dmfod_card in dmfod_deck:
						if str(dmfod_card.get("name", "")) == dmfod_target_name:
							dmfod_ids.append(str(dmfod_card.get("instance_id", "")))
					for dmfod_id in dmfod_ids:
						var dmfod_result := MatchMutations.discard_card(match_state, dmfod_id, {"reason": reason})
						generated_events.append_array(dmfod_result.get("events", []))
			"draw_cards_per_runes":
				var dcpr_controller_id := str(trigger.get("controller_player_id", ""))
				var dcpr_opponent_id := _get_opposing_player_id(match_state.get("players", []), dcpr_controller_id)
				var dcpr_opponent := _get_player_state(match_state, dcpr_opponent_id)
				if not dcpr_opponent.is_empty():
					var dcpr_runes_remaining: Array = dcpr_opponent.get("rune_thresholds", [25, 20, 15, 10, 5])
					var dcpr_destroyed := 5 - dcpr_runes_remaining.size()
					if dcpr_destroyed > 0:
						var dcpr_draw_result := draw_cards(match_state, dcpr_controller_id, dcpr_destroyed, {"reason": reason, "source_instance_id": str(trigger.get("source_instance_id", ""))})
						generated_events.append_array(dcpr_draw_result.get("events", []))
			"modify_cost":
				var mc_amount := int(effect.get("amount", -1))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["cost"] = maxi(0, int(card.get("cost", 0)) + mc_amount)
					generated_events.append({
						"event_type": "cost_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"amount": mc_amount,
					})
			"reduce_cost_top_of_deck":
				var rctd_controller_id := str(trigger.get("controller_player_id", ""))
				var rctd_player := _get_player_state(match_state, rctd_controller_id)
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
			"destroy_item":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
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
			"modify_item_in_hand", "modify_random_item_in_hand":
				var mih_controller_id := str(trigger.get("controller_player_id", ""))
				var mih_player := _get_player_state(match_state, mih_controller_id)
				if not mih_player.is_empty():
					var mih_hand: Array = mih_player.get(ZONE_HAND, [])
					var mih_items: Array = []
					for mih_card in mih_hand:
						if str(mih_card.get("card_type", "")) == CARD_TYPE_ITEM:
							mih_items.append(mih_card)
					if not mih_items.is_empty():
						var mih_target: Dictionary
						if op == "modify_random_item_in_hand":
							var mih_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_mod_item", mih_items.size())
							mih_target = mih_items[mih_idx]
						else:
							mih_target = mih_items[0]
						var mih_power := int(effect.get("power", 0))
						var mih_health := int(effect.get("health", 0))
						mih_target["equip_power_bonus"] = int(mih_target.get("equip_power_bonus", 0)) + mih_power
						mih_target["equip_health_bonus"] = int(mih_target.get("equip_health_bonus", 0)) + mih_health
						generated_events.append({
							"event_type": "item_in_hand_modified",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"target_instance_id": str(mih_target.get("instance_id", "")),
							"power": mih_power,
							"health": mih_health,
						})
			"summon_from_discard_highest_cost":
				var sfdh_controller_id := str(trigger.get("controller_player_id", ""))
				var sfdh_player := _get_player_state(match_state, sfdh_controller_id)
				if not sfdh_player.is_empty():
					var sfdh_discard: Array = sfdh_player.get(ZONE_DISCARD, [])
					var sfdh_best: Dictionary = {}
					var sfdh_best_cost := -1
					for sfdh_card in sfdh_discard:
						if typeof(sfdh_card) == TYPE_DICTIONARY and str(sfdh_card.get("card_type", "")) == CARD_TYPE_CREATURE:
							var c := int(sfdh_card.get("cost", 0))
							if c > sfdh_best_cost:
								sfdh_best_cost = c
								sfdh_best = sfdh_card
					if not sfdh_best.is_empty():
						var sfdh_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, sfdh_controller_id)
						if not sfdh_lane_id.is_empty():
							sfdh_discard.erase(sfdh_best)
							sfdh_best.erase("zone")
							var sfdh_result := MatchMutations.summon_card_to_lane(match_state, sfdh_controller_id, sfdh_best, sfdh_lane_id, {"source_zone": ZONE_DISCARD})
							if bool(sfdh_result.get("is_valid", false)):
								generated_events.append_array(sfdh_result.get("events", []))
								generated_events.append(_build_summon_event(sfdh_result["card"], sfdh_controller_id, sfdh_lane_id, int(sfdh_result.get("slot_index", -1)), reason))
								_check_summon_abilities(match_state, sfdh_result["card"])
			"summon_from_opponent_discard":
				var sfod_controller_id := str(trigger.get("controller_player_id", ""))
				var sfod_opponent_id := _get_opposing_player_id(match_state.get("players", []), sfod_controller_id)
				var sfod_opponent := _get_player_state(match_state, sfod_opponent_id)
				if not sfod_opponent.is_empty():
					var sfod_discard: Array = sfod_opponent.get(ZONE_DISCARD, [])
					var sfod_candidates: Array = []
					for sfod_card in sfod_discard:
						if typeof(sfod_card) == TYPE_DICTIONARY and str(sfod_card.get("card_type", "")) == CARD_TYPE_CREATURE:
							sfod_candidates.append(sfod_card)
					if not sfod_candidates.is_empty():
						var sfod_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_summon_opp_discard", sfod_candidates.size())
						var sfod_target: Dictionary = sfod_candidates[sfod_idx]
						sfod_discard.erase(sfod_target)
						sfod_target.erase("zone")
						sfod_target["controller_player_id"] = sfod_controller_id
						sfod_target["owner_player_id"] = sfod_controller_id
						var sfod_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, sfod_controller_id)
						if not sfod_lane_id.is_empty():
							var sfod_result := MatchMutations.summon_card_to_lane(match_state, sfod_controller_id, sfod_target, sfod_lane_id, {"source_zone": ZONE_DISCARD})
							if bool(sfod_result.get("is_valid", false)):
								generated_events.append_array(sfod_result.get("events", []))
								generated_events.append(_build_summon_event(sfod_result["card"], sfod_controller_id, sfod_lane_id, int(sfod_result.get("slot_index", -1)), reason))
								_check_summon_abilities(match_state, sfod_result["card"])
			"summon_top_creature_from_deck":
				var stcfd_controller_id := str(trigger.get("controller_player_id", ""))
				var stcfd_player := _get_player_state(match_state, stcfd_controller_id)
				if not stcfd_player.is_empty():
					var stcfd_deck: Array = stcfd_player.get(ZONE_DECK, [])
					var stcfd_found: Dictionary = {}
					var stcfd_found_idx := -1
					for i in range(stcfd_deck.size() - 1, -1, -1):
						var stcfd_card: Dictionary = stcfd_deck[i]
						if str(stcfd_card.get("card_type", "")) == CARD_TYPE_CREATURE:
							stcfd_found = stcfd_card
							stcfd_found_idx = i
							break
					if not stcfd_found.is_empty():
						stcfd_deck.remove_at(stcfd_found_idx)
						stcfd_found.erase("zone")
						var stcfd_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, stcfd_controller_id)
						if not stcfd_lane_id.is_empty():
							var stcfd_result := MatchMutations.summon_card_to_lane(match_state, stcfd_controller_id, stcfd_found, stcfd_lane_id, {"source_zone": ZONE_DECK})
							if bool(stcfd_result.get("is_valid", false)):
								generated_events.append_array(stcfd_result.get("events", []))
								generated_events.append(_build_summon_event(stcfd_result["card"], stcfd_controller_id, stcfd_lane_id, int(stcfd_result.get("slot_index", -1)), reason))
								_check_summon_abilities(match_state, stcfd_result["card"])
			"summon_from_deck_by_cost":
				var sfdc_controller_id := str(trigger.get("controller_player_id", ""))
				var sfdc_player := _get_player_state(match_state, sfdc_controller_id)
				if not sfdc_player.is_empty():
					var sfdc_deck: Array = sfdc_player.get(ZONE_DECK, [])
					var sfdc_max_cost := int(effect.get("max_cost", 999))
					var sfdc_min_cost := int(effect.get("min_cost", 0))
					var sfdc_exact_cost := int(effect.get("exact_cost", -1))
					var sfdc_filter_type := str(effect.get("filter_card_type", CARD_TYPE_CREATURE))
					var sfdc_candidates: Array = []
					for sfdc_card in sfdc_deck:
						if str(sfdc_card.get("card_type", "")) != sfdc_filter_type:
							continue
						var sfdc_cost := int(sfdc_card.get("cost", 0))
						if sfdc_exact_cost >= 0 and sfdc_cost != sfdc_exact_cost:
							continue
						if sfdc_cost < sfdc_min_cost or sfdc_cost > sfdc_max_cost:
							continue
						sfdc_candidates.append(sfdc_card)
					if not sfdc_candidates.is_empty():
						var sfdc_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_deck_summon", sfdc_candidates.size())
						var sfdc_target: Dictionary = sfdc_candidates[sfdc_idx]
						sfdc_deck.erase(sfdc_target)
						sfdc_target.erase("zone")
						var sfdc_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, sfdc_controller_id)
						if not sfdc_lane_id.is_empty():
							var sfdc_result := MatchMutations.summon_card_to_lane(match_state, sfdc_controller_id, sfdc_target, sfdc_lane_id, {"source_zone": ZONE_DECK})
							if bool(sfdc_result.get("is_valid", false)):
								generated_events.append_array(sfdc_result.get("events", []))
								generated_events.append(_build_summon_event(sfdc_result["card"], sfdc_controller_id, sfdc_lane_id, int(sfdc_result.get("slot_index", -1)), reason))
								_check_summon_abilities(match_state, sfdc_result["card"])
			"summon_from_deck_filtered":
				var sfdf_controller_id := str(trigger.get("controller_player_id", ""))
				var sfdf_player := _get_player_state(match_state, sfdf_controller_id)
				if not sfdf_player.is_empty():
					var sfdf_deck: Array = sfdf_player.get(ZONE_DECK, [])
					# Read filter from nested "filter" dict or top-level effect fields
					var sfdf_filter: Dictionary = effect.get("filter", {})
					if typeof(sfdf_filter) != TYPE_DICTIONARY:
						sfdf_filter = {}
					var sfdf_filter_subtype := str(sfdf_filter.get("subtype", effect.get("filter_subtype", "")))
					var sfdf_filter_attribute := str(sfdf_filter.get("attribute", effect.get("filter_attribute", "")))
					var sfdf_filter_type := str(sfdf_filter.get("card_type", effect.get("filter_card_type", CARD_TYPE_CREATURE)))
					# Cost filtering
					var sfdf_max_cost := int(sfdf_filter.get("max_cost", effect.get("max_cost", -1)))
					var sfdf_max_cost_source := str(sfdf_filter.get("max_cost_source", ""))
					if sfdf_max_cost_source == "self_power":
						var sfdf_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
						if not sfdf_source.is_empty():
							sfdf_max_cost = EvergreenRules.get_power(sfdf_source)
					var sfdf_candidates: Array = []
					for sfdf_card in sfdf_deck:
						if str(sfdf_card.get("card_type", "")) != sfdf_filter_type:
							continue
						if sfdf_max_cost >= 0 and int(sfdf_card.get("cost", 0)) >= sfdf_max_cost:
							continue
						if not sfdf_filter_subtype.is_empty():
							var sfdf_subtypes = sfdf_card.get("subtypes", [])
							if typeof(sfdf_subtypes) != TYPE_ARRAY or not sfdf_subtypes.has(sfdf_filter_subtype):
								continue
						if not sfdf_filter_attribute.is_empty():
							var sfdf_attrs = sfdf_card.get("attributes", [])
							if typeof(sfdf_attrs) != TYPE_ARRAY or not sfdf_attrs.has(sfdf_filter_attribute):
								continue
						sfdf_candidates.append(sfdf_card)
					if not sfdf_candidates.is_empty():
						var sfdf_candidate_ids: Array = []
						for sfdf_c in sfdf_candidates:
							sfdf_candidate_ids.append(str(sfdf_c.get("instance_id", "")))
						var sfdf_then_op := "summon_support_from_deck" if sfdf_filter_type == "support" else "summon_creature_from_deck"
						var sfdf_then_context := {"reason": reason}
						if sfdf_filter_type != "support":
							sfdf_then_context["lane_id"] = _resolve_summon_lane_id(match_state, trigger, event, effect, sfdf_controller_id)
						var sfdf_pending: Array = match_state.get("pending_deck_selections", [])
						sfdf_pending.append({
							"player_id": sfdf_controller_id,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"candidate_instance_ids": sfdf_candidate_ids,
							"then_op": sfdf_then_op,
							"then_context": sfdf_then_context,
							"prompt": "Choose a card from your deck.",
						})
			"summon_random_creature", "summon_random_by_cost":
				# Delegate to summon_random_from_catalog with appropriate filters
				var src_filter: Dictionary = {"card_type": "creature"}
				if op == "summon_random_by_cost":
					var src_exact_cost := int(effect.get("cost", effect.get("exact_cost", -1)))
					if src_exact_cost >= 0:
						src_filter["max_cost"] = src_exact_cost
						src_filter["min_cost"] = src_exact_cost
				var src_max_cost := int(effect.get("max_cost", -1))
				if src_max_cost >= 0:
					var src_empower_cost := int(effect.get("empower_bonus_cost", 0))
					if src_empower_cost > 0:
						src_max_cost += src_empower_cost * _get_empower_amount(match_state, str(trigger.get("controller_player_id", "")))
					src_filter["max_cost"] = src_max_cost
				var src_delegated := {"op": "summon_random_from_catalog", "filter": src_filter}
				for src_key in ["lane_id", "target_lane_id"]:
					if effect.has(src_key):
						src_delegated[src_key] = effect[src_key]
				var src_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, src_delegated)
				if bool(src_result.get("handled", false)):
					generated_events.append_array(src_result.get("events", []))
			"deal_damage_and_heal":
				var ddah_amount := int(effect.get("amount", 0))
				var ddah_source_id := str(trigger.get("source_instance_id", ""))
				var ddah_controller_id := str(trigger.get("controller_player_id", ""))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
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
					if int(card.get("health", 0)) <= 0:
						var ddah_destroy := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")), {"reason": reason})
						generated_events.append({
							"event_type": EVENT_CREATURE_DESTROYED,
							"instance_id": str(card.get("instance_id", "")),
							"controller_player_id": str(card.get("controller_player_id", "")),
							"killer_instance_id": ddah_source_id,
						})
						generated_events.append_array(ddah_destroy.get("events", []))
						# Heal player for the damage amount
						var ddah_player := _get_player_state(match_state, ddah_controller_id)
						if not ddah_player.is_empty():
							var ddah_heal := ddah_amount * _get_heal_multiplier(match_state, ddah_controller_id)
							ddah_player["health"] = int(ddah_player.get("health", 0)) + ddah_heal
							generated_events.append({"event_type": "player_healed", "source_instance_id": ddah_source_id, "target_player_id": ddah_controller_id, "amount": ddah_heal})
			"steal_status":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var ss_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if ss_source.is_empty():
						continue
					var ss_statuses: Array = card.get("status_markers", [])
					if typeof(ss_statuses) != TYPE_ARRAY or ss_statuses.is_empty():
						var ss_keywords: Array = card.get("granted_keywords", [])
						if typeof(ss_keywords) == TYPE_ARRAY and not ss_keywords.is_empty():
							var ss_kw: String = ss_keywords[0]
							ss_keywords.erase(ss_kw)
							EvergreenRules.ensure_card_state(ss_source)
							var ss_granted: Array = ss_source.get("granted_keywords", [])
							if not ss_granted.has(ss_kw):
								ss_granted.append(ss_kw)
								ss_source["granted_keywords"] = ss_granted
							generated_events.append({"event_type": "keyword_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": ss_kw})
					else:
						var ss_status: String = ss_statuses[0]
						EvergreenRules.remove_status(card, ss_status)
						EvergreenRules.add_status(ss_source, ss_status)
						generated_events.append({"event_type": "status_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "status_id": ss_status})
			"destroy_and_transfer_keywords":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var datk_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if datk_source.is_empty():
						continue
					var datk_keywords: Array = []
					for kw in card.get("keywords", []):
						datk_keywords.append(str(kw))
					for kw in card.get("granted_keywords", []):
						if not datk_keywords.has(str(kw)):
							datk_keywords.append(str(kw))
					var datk_destroy := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")), {"reason": reason})
					generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": str(card.get("controller_player_id", "")), "killer_instance_id": str(trigger.get("source_instance_id", ""))})
					generated_events.append_array(datk_destroy.get("events", []))
					EvergreenRules.ensure_card_state(datk_source)
					var datk_granted: Array = datk_source.get("granted_keywords", [])
					for kw in datk_keywords:
						if not datk_granted.has(kw):
							datk_granted.append(kw)
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(datk_source.get("instance_id", "")), "keyword_id": kw})
					datk_source["granted_keywords"] = datk_granted
			"set_all_friendly_power_to_max":
				var safptm_controller_id := str(trigger.get("controller_player_id", ""))
				var safptm_max_power := 0
				var safptm_friendlies := _player_lane_creatures(match_state, safptm_controller_id)
				for card in safptm_friendlies:
					var p := EvergreenRules.get_power(card)
					if p > safptm_max_power:
						safptm_max_power = p
				for card in safptm_friendlies:
					if EvergreenRules.get_power(card) < safptm_max_power:
						card["power"] = safptm_max_power
						card["base_power"] = safptm_max_power
						EvergreenRules.ensure_card_state(card)
						generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "reason": reason})
			"modify_stats_per_keyword":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var mspk_count := 0
					for kw in card.get("keywords", []):
						mspk_count += 1
					for kw in card.get("granted_keywords", []):
						mspk_count += 1
					var mspk_power := int(effect.get("power_per_keyword", 0)) * mspk_count
					var mspk_health := int(effect.get("health_per_keyword", 0)) * mspk_count
					EvergreenRules.apply_stat_bonus(card, mspk_power, mspk_health, reason)
					generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "power_bonus": mspk_power, "health_bonus": mspk_health, "reason": reason})
			"copy_all_friendly_keywords":
				var cafk_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not cafk_source.is_empty():
					var cafk_controller_id := str(cafk_source.get("controller_player_id", ""))
					EvergreenRules.ensure_card_state(cafk_source)
					var cafk_granted: Array = cafk_source.get("granted_keywords", [])
					for card in _player_lane_creatures(match_state, cafk_controller_id):
						if str(card.get("instance_id", "")) == str(cafk_source.get("instance_id", "")):
							continue
						for kw in card.get("keywords", []):
							if not cafk_granted.has(str(kw)):
								cafk_granted.append(str(kw))
								generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(cafk_source.get("instance_id", "")), "keyword_id": str(kw)})
						for kw in card.get("granted_keywords", []):
							if not cafk_granted.has(str(kw)):
								cafk_granted.append(str(kw))
								generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(cafk_source.get("instance_id", "")), "keyword_id": str(kw)})
					cafk_source["granted_keywords"] = cafk_granted
			"return_equipped_items_to_hand":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var reith_items: Array = card.get("attached_items", [])
					var reith_ids: Array = []
					for reith_item in reith_items:
						reith_ids.append(str(reith_item.get("instance_id", "")))
					for reith_id in reith_ids:
						var reith_move := MatchMutations.move_card_to_zone(match_state, reith_id, ZONE_HAND, {"reason": reason})
						generated_events.append({"event_type": "attached_item_detached", "source_instance_id": str(trigger.get("source_instance_id", "")), "host_instance_id": str(card.get("instance_id", "")), "item_instance_id": reith_id})
						generated_events.append_array(reith_move.get("events", []))
			"reequip_all_items_to":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var rait_controller_id := str(card.get("controller_player_id", ""))
					var rait_all_items: Array = []
					for rait_friendly in _player_lane_creatures(match_state, rait_controller_id):
						if str(rait_friendly.get("instance_id", "")) == str(card.get("instance_id", "")):
							continue
						for rait_item in rait_friendly.get("attached_items", []):
							rait_all_items.append({"item": rait_item, "host": rait_friendly})
					for rait_entry in rait_all_items:
						var rait_item_id := str(rait_entry["item"].get("instance_id", ""))
						var rait_result := MatchMutations.attach_item_to_creature(match_state, rait_controller_id, rait_item_id, str(card.get("instance_id", "")), {"reason": reason})
						generated_events.append_array(rait_result.get("events", []))
			"shuffle_all_creatures_into_deck":
				var sacid_all := _all_lane_creatures(match_state)
				generated_events.append({"event_type": "all_creatures_shuffled", "source_instance_id": str(trigger.get("source_instance_id", "")), "count": sacid_all.size()})
				var sacid_ids: Array = []
				for card in sacid_all:
					sacid_ids.append({"id": str(card.get("instance_id", "")), "controller": str(card.get("controller_player_id", ""))})
				for entry in sacid_ids:
					var sacid_move := MatchMutations.move_card_to_zone(match_state, entry["id"], ZONE_DECK, {"reason": reason})
					generated_events.append_array(sacid_move.get("events", []))
					var sacid_player := _get_player_state(match_state, entry["controller"])
					if not sacid_player.is_empty():
						var sacid_deck: Array = sacid_player.get(ZONE_DECK, [])
						var sacid_card_idx := -1
						for i in range(sacid_deck.size()):
							if str(sacid_deck[i].get("instance_id", "")) == entry["id"]:
								sacid_card_idx = i
								break
						if sacid_card_idx >= 0:
							var sacid_card: Dictionary = sacid_deck[sacid_card_idx]
							sacid_deck.remove_at(sacid_card_idx)
							var sacid_new_pos := _deterministic_index(match_state, entry["id"] + "_shuffle_all", sacid_deck.size() + 1)
							sacid_deck.insert(sacid_new_pos, sacid_card)
			"draw_if_top_deck_subtype":
				var ditds_controller_id := str(trigger.get("controller_player_id", ""))
				var ditds_player := _get_player_state(match_state, ditds_controller_id)
				if not ditds_player.is_empty():
					var ditds_deck: Array = ditds_player.get(ZONE_DECK, [])
					if not ditds_deck.is_empty():
						var ditds_top: Dictionary = ditds_deck.back()
						var ditds_filter_subtype := str(effect.get("filter_subtype", ""))
						var ditds_subtypes = ditds_top.get("subtypes", [])
						if typeof(ditds_subtypes) == TYPE_ARRAY and ditds_subtypes.has(ditds_filter_subtype):
							var ditds_draw := draw_cards(match_state, ditds_controller_id, 1, {"reason": reason, "source_instance_id": str(trigger.get("source_instance_id", ""))})
							generated_events.append_array(ditds_draw.get("events", []))
			"gain_keywords_from_top_deck":
				var gkftd_controller_id := str(trigger.get("controller_player_id", ""))
				var gkftd_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				var gkftd_player := _get_player_state(match_state, gkftd_controller_id)
				if not gkftd_source.is_empty() and not gkftd_player.is_empty():
					var gkftd_deck: Array = gkftd_player.get(ZONE_DECK, [])
					var gkftd_count := int(effect.get("count", 3))
					EvergreenRules.ensure_card_state(gkftd_source)
					var gkftd_granted: Array = gkftd_source.get("granted_keywords", [])
					for i in range(mini(gkftd_count, gkftd_deck.size())):
						var gkftd_card: Dictionary = gkftd_deck[gkftd_deck.size() - 1 - i]
						for kw in gkftd_card.get("keywords", []):
							if not gkftd_granted.has(str(kw)):
								gkftd_granted.append(str(kw))
								generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(gkftd_source.get("instance_id", "")), "keyword_id": str(kw)})
					gkftd_source["granted_keywords"] = gkftd_granted
			"repeat_slay_reward":
				# This is handled as a support passive — mark the support as active
				# The actual repeat logic needs to hook into slay resolution
				var rsr_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not rsr_source.is_empty():
					rsr_source["_repeat_slay_active"] = true
			"trigger_all_friendly_summons":
				var tafs_controller_id := str(trigger.get("controller_player_id", ""))
				var tafs_creatures := _player_lane_creatures(match_state, tafs_controller_id)
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
			"sacrifice_and_summon_from_deck":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var sasd_controller_id := str(card.get("controller_player_id", ""))
					var sasd_cost := int(card.get("cost", 0))
					var sasd_target_cost := sasd_cost + int(effect.get("cost_offset", 1))
					var sasd_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					var sasd_lane_id := str(sasd_location.get("lane_id", ""))
					var sasd_sac := MatchMutations.sacrifice_card(match_state, sasd_controller_id, str(card.get("instance_id", "")), {"reason": reason})
					generated_events.append_array(sasd_sac.get("events", []))
					generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": sasd_controller_id, "lane_id": sasd_lane_id})
					var sasd_player := _get_player_state(match_state, sasd_controller_id)
					if not sasd_player.is_empty():
						var sasd_deck: Array = sasd_player.get(ZONE_DECK, [])
						var sasd_candidates: Array = []
						for sasd_card in sasd_deck:
							if str(sasd_card.get("card_type", "")) == CARD_TYPE_CREATURE and int(sasd_card.get("cost", 0)) == sasd_target_cost:
								sasd_candidates.append(sasd_card)
						if not sasd_candidates.is_empty():
							var sasd_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_sac_summon", sasd_candidates.size())
							var sasd_summon_target: Dictionary = sasd_candidates[sasd_idx]
							sasd_deck.erase(sasd_summon_target)
							sasd_summon_target.erase("zone")
							if not sasd_lane_id.is_empty():
								var sasd_result := MatchMutations.summon_card_to_lane(match_state, sasd_controller_id, sasd_summon_target, sasd_lane_id, {"source_zone": ZONE_DECK})
								if bool(sasd_result.get("is_valid", false)):
									generated_events.append_array(sasd_result.get("events", []))
									generated_events.append(_build_summon_event(sasd_result["card"], sasd_controller_id, sasd_lane_id, int(sasd_result.get("slot_index", -1)), reason))
									_check_summon_abilities(match_state, sasd_result["card"])
			"transform_in_hand":
				var tih_controller_id := str(trigger.get("controller_player_id", ""))
				var tih_template: Dictionary = effect.get("card_template", {})
				if not tih_template.is_empty():
					for card in _resolve_card_targets(match_state, trigger, event, effect):
						if str(card.get("zone", "")) == ZONE_HAND:
							var tih_result := MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), tih_template, {"reason": reason})
							generated_events.append_array(tih_result.get("events", []))
			"transform_in_hand_to_random":
				var tihr_controller_id := str(trigger.get("controller_player_id", ""))
				var tihr_filter_type := str(effect.get("filter_card_type", ""))
				var tihr_seeds: Array = ExtendedMechanicPacks.get_catalog_seeds()
				var tihr_candidates: Array = []
				for tihr_seed in tihr_seeds:
					if not bool(tihr_seed.get("collectible", true)):
						continue
					if not tihr_filter_type.is_empty() and str(tihr_seed.get("card_type", "")) != tihr_filter_type:
						continue
					tihr_candidates.append(tihr_seed)
				if not tihr_candidates.is_empty():
					for card in _resolve_card_targets(match_state, trigger, event, effect):
						if str(card.get("zone", "")) == ZONE_HAND:
							var tihr_idx := _deterministic_index(match_state, str(card.get("instance_id", "")) + "_transform_random", tihr_candidates.size())
							var tihr_template: Dictionary = tihr_candidates[tihr_idx]
							var tihr_result := MatchMutations.transform_card(match_state, str(card.get("instance_id", "")), tihr_template, {"reason": reason})
							generated_events.append_array(tihr_result.get("events", []))
			"transform_hand":
				var th_controller_id := str(trigger.get("controller_player_id", ""))
				var th_player := _get_player_state(match_state, th_controller_id)
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
							var th_idx := _deterministic_index(match_state, str(th_card.get("instance_id", "")) + "_transform_hand", th_collectible.size())
							var th_result := MatchMutations.transform_card(match_state, str(th_card.get("instance_id", "")), th_collectible[th_idx], {"reason": reason})
							generated_events.append_array(th_result.get("events", []))
			"restore_rune":
				for player_id in _resolve_player_targets(match_state, trigger, event, effect):
					var rr_player := _get_player_state(match_state, player_id)
					if rr_player.is_empty():
						continue
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
			"change_attribute":
				var ca_new_attr := str(effect.get("attribute", "neutral"))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["attributes"] = [ca_new_attr]
					generated_events.append({"event_type": "attribute_changed", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "attribute": ca_new_attr})
			"conditional_lane_bonus":
				var clb_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not clb_source.is_empty():
					var clb_location := MatchMutations.find_card_location(match_state, str(clb_source.get("instance_id", "")))
					var clb_lane_id := str(clb_location.get("lane_id", ""))
					var clb_bonuses: Dictionary = effect.get("lane_bonuses", {})
					var clb_lane_type := ""
					for lane in match_state.get("lanes", []):
						if str(lane.get("lane_id", "")) == clb_lane_id:
							clb_lane_type = str(lane.get("lane_type", "field"))
							break
					var clb_bonus: Dictionary = clb_bonuses.get(clb_lane_type, {})
					if not clb_bonus.is_empty():
						var clb_power := int(clb_bonus.get("power", 0))
						var clb_health := int(clb_bonus.get("health", 0))
						EvergreenRules.apply_stat_bonus(clb_source, clb_power, clb_health, reason)
						generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(clb_source.get("instance_id", "")), "power_bonus": clb_power, "health_bonus": clb_health, "reason": reason})
						for kw in clb_bonus.get("keywords", []):
							EvergreenRules.ensure_card_state(clb_source)
							var clb_granted: Array = clb_source.get("granted_keywords", [])
							if not clb_granted.has(str(kw)):
								clb_granted.append(str(kw))
								clb_source["granted_keywords"] = clb_granted
								generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(clb_source.get("instance_id", "")), "keyword_id": str(kw)})
			"grant_temporary_immunity":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["_immune_until_turn"] = int(match_state.get("turn_number", 0)) + 1
					generated_events.append({"event_type": "temporary_immunity_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", ""))})
			"steal_item_from_opponent_discard":
				var sifod_controller_id := str(trigger.get("controller_player_id", ""))
				var sifod_opponent_id := _get_opposing_player_id(match_state.get("players", []), sifod_controller_id)
				var sifod_opponent := _get_player_state(match_state, sifod_opponent_id)
				if not sifod_opponent.is_empty():
					var sifod_discard: Array = sifod_opponent.get(ZONE_DISCARD, [])
					var sifod_items: Array = []
					for sifod_card in sifod_discard:
						if typeof(sifod_card) == TYPE_DICTIONARY and str(sifod_card.get("card_type", "")) == CARD_TYPE_ITEM:
							sifod_items.append(sifod_card)
					if not sifod_items.is_empty():
						var sifod_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_steal_item", sifod_items.size())
						var sifod_stolen: Dictionary = sifod_items[sifod_idx]
						sifod_discard.erase(sifod_stolen)
						# Equip to the source creature
						var sifod_source_id := str(trigger.get("source_instance_id", ""))
						sifod_stolen["controller_player_id"] = sifod_controller_id
						sifod_stolen["owner_player_id"] = sifod_controller_id
						var sifod_equip := MatchMutations.attach_item_to_creature(match_state, sifod_controller_id, sifod_stolen, sifod_source_id, {"reason": reason})
						generated_events.append_array(sifod_equip.get("events", []))
			"summon_all_from_discard_by_name":
				var safdbn_controller_id := str(trigger.get("controller_player_id", ""))
				var safdbn_name := str(effect.get("card_name", ""))
				if safdbn_name.is_empty():
					var safdbn_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					safdbn_name = str(safdbn_source.get("name", ""))
				var safdbn_player := _get_player_state(match_state, safdbn_controller_id)
				if not safdbn_player.is_empty() and not safdbn_name.is_empty():
					var safdbn_discard: Array = safdbn_player.get(ZONE_DISCARD, [])
					var safdbn_matches: Array = []
					for safdbn_card in safdbn_discard:
						if str(safdbn_card.get("name", "")) == safdbn_name:
							safdbn_matches.append(safdbn_card)
					for safdbn_card in safdbn_matches:
						safdbn_discard.erase(safdbn_card)
						safdbn_card.erase("zone")
						var safdbn_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, safdbn_controller_id)
						if not safdbn_lane_id.is_empty():
							var safdbn_result := MatchMutations.summon_card_to_lane(match_state, safdbn_controller_id, safdbn_card, safdbn_lane_id, {"source_zone": ZONE_DISCARD})
							if bool(safdbn_result.get("is_valid", false)):
								generated_events.append_array(safdbn_result.get("events", []))
								generated_events.append(_build_summon_event(safdbn_result["card"], safdbn_controller_id, safdbn_lane_id, int(safdbn_result.get("slot_index", -1)), reason))
			"play_prophecy_from_hand":
				# Mark that the player should play a prophecy from hand — this needs a pending choice
				var ppfh_controller_id := str(trigger.get("controller_player_id", ""))
				var ppfh_player := _get_player_state(match_state, ppfh_controller_id)
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
			"cost_increase_next_turn":
				var cint_controller_id := str(trigger.get("controller_player_id", ""))
				var cint_opponent_id := _get_opposing_player_id(match_state.get("players", []), cint_controller_id)
				var cint_opponent := _get_player_state(match_state, cint_opponent_id)
				if not cint_opponent.is_empty():
					var cint_hand: Array = cint_opponent.get(ZONE_HAND, [])
					if not cint_hand.is_empty():
						var cint_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_cost_increase", cint_hand.size())
						var cint_card: Dictionary = cint_hand[cint_idx]
						var cint_amount := int(effect.get("amount", 3))
						cint_card["cost"] = int(cint_card.get("cost", 0)) + cint_amount
						generated_events.append({"event_type": "cost_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(cint_card.get("instance_id", "")), "amount": cint_amount})
			"prevent_rune_draw":
				var prd_opponent_id := _get_opposing_player_id(match_state.get("players", []), str(trigger.get("controller_player_id", "")))
				var prd_opponent := _get_player_state(match_state, prd_opponent_id)
				if not prd_opponent.is_empty():
					prd_opponent["_rune_draw_prevented_until_turn"] = int(match_state.get("turn_number", 0)) + 1
					generated_events.append({"event_type": "rune_draw_prevented", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_player_id": prd_opponent_id})
			"grant_keyword_to_all_copies":
				var gktac_keyword := str(effect.get("keyword_id", ""))
				var gktac_name := ""
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					gktac_name = str(card.get("name", ""))
					break
				if not gktac_name.is_empty() and not gktac_keyword.is_empty():
					var gktac_controller_id := str(trigger.get("controller_player_id", ""))
					var gktac_player := _get_player_state(match_state, gktac_controller_id)
					if not gktac_player.is_empty():
						var gktac_zones := [gktac_player.get(ZONE_HAND, []), gktac_player.get(ZONE_DECK, [])]
						for gktac_zone in gktac_zones:
							for gktac_card in gktac_zone:
								if str(gktac_card.get("name", "")) == gktac_name:
									EvergreenRules.ensure_card_state(gktac_card)
									var gktac_granted: Array = gktac_card.get("granted_keywords", [])
									if not gktac_granted.has(gktac_keyword):
										gktac_granted.append(gktac_keyword)
										gktac_card["granted_keywords"] = gktac_granted
						# Also grant to lane creatures
						for gktac_creature in _player_lane_creatures(match_state, gktac_controller_id):
							if str(gktac_creature.get("name", "")) == gktac_name:
								EvergreenRules.ensure_card_state(gktac_creature)
								var gktac_granted2: Array = gktac_creature.get("granted_keywords", [])
								if not gktac_granted2.has(gktac_keyword):
									gktac_granted2.append(gktac_keyword)
									gktac_creature["granted_keywords"] = gktac_granted2
									generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(gktac_creature.get("instance_id", "")), "keyword_id": gktac_keyword})
			"choose_card_in_hand_and_shuffle_copies":
				var ccihsc_controller_id := str(trigger.get("controller_player_id", ""))
				var ccihsc_player := _get_player_state(match_state, ccihsc_controller_id)
				if not ccihsc_player.is_empty():
					var ccihsc_hand: Array = ccihsc_player.get(ZONE_HAND, [])
					var ccihsc_creature_ids: Array = []
					for ccihsc_card in ccihsc_hand:
						if str(ccihsc_card.get("card_type", "")) == CARD_TYPE_CREATURE:
							ccihsc_creature_ids.append(str(ccihsc_card.get("instance_id", "")))
					if not ccihsc_creature_ids.is_empty():
						var ccihsc_power := int(effect.get("power_bonus", 3))
						var ccihsc_health := int(effect.get("health_bonus", 3))
						var ccihsc_copies := int(effect.get("copy_count", 3))
						match_state["pending_hand_selections"].append({
							"player_id": ccihsc_controller_id,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"candidate_instance_ids": ccihsc_creature_ids,
							"then_op": "shuffle_buffed_copies",
							"then_context": {"power_bonus": ccihsc_power, "health_bonus": ccihsc_health, "copy_count": ccihsc_copies},
							"prompt": "Choose a creature to shuffle copies of into your deck.",
						})
			"optional_consume_for_keyword":
				# Handled via pending consume selection
				var ocfk_controller_id := str(trigger.get("controller_player_id", ""))
				var ocfk_candidates := get_consume_candidates(match_state, ocfk_controller_id)
				if not ocfk_candidates.is_empty():
					var ocfk_candidate_ids: Array = []
					for ocfk_c in ocfk_candidates:
						ocfk_candidate_ids.append(str(ocfk_c.get("instance_id", "")))
					var ocfk_pending: Array = match_state.get("pending_consume_selections", [])
					ocfk_pending.append({
						"player_id": ocfk_controller_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"candidate_instance_ids": ocfk_candidate_ids,
						"has_target_mode": false,
						"trigger_index": int(trigger.get("trigger_index", 0)),
					})
			"summon_each_unique_from_deck":
				var seufd_controller_id := str(trigger.get("controller_player_id", ""))
				var seufd_player := _get_player_state(match_state, seufd_controller_id)
				if not seufd_player.is_empty():
					var seufd_deck: Array = seufd_player.get(ZONE_DECK, [])
					var seufd_costs_seen: Dictionary = {}
					var seufd_to_summon: Array = []
					# Scan from top of deck
					for i in range(seufd_deck.size() - 1, -1, -1):
						var seufd_card: Dictionary = seufd_deck[i]
						if str(seufd_card.get("card_type", "")) != CARD_TYPE_CREATURE:
							continue
						var seufd_cost := int(seufd_card.get("cost", 0))
						if seufd_costs_seen.has(seufd_cost):
							continue
						seufd_costs_seen[seufd_cost] = true
						seufd_to_summon.append(seufd_card)
					for seufd_card in seufd_to_summon:
						seufd_deck.erase(seufd_card)
						seufd_card.erase("zone")
						var seufd_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, seufd_controller_id)
						if not seufd_lane_id.is_empty():
							var seufd_result := MatchMutations.summon_card_to_lane(match_state, seufd_controller_id, seufd_card, seufd_lane_id, {"source_zone": ZONE_DECK})
							if bool(seufd_result.get("is_valid", false)):
								generated_events.append_array(seufd_result.get("events", []))
								generated_events.append(_build_summon_event(seufd_result["card"], seufd_controller_id, seufd_lane_id, int(seufd_result.get("slot_index", -1)), reason))
			"copy_summon_ability":
				# Copy a friendly creature's summon triggers and re-fire them
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var csa_triggers = card.get("triggered_abilities", [])
					if typeof(csa_triggers) != TYPE_ARRAY:
						continue
					for csa_trigger in csa_triggers:
						if typeof(csa_trigger) != TYPE_DICTIONARY:
							continue
						if str(csa_trigger.get("family", "")) == FAMILY_SUMMON:
							var csa_location := MatchMutations.find_card_location(match_state, str(trigger.get("source_instance_id", "")))
							generated_events.append({
								"event_type": EVENT_CREATURE_SUMMONED,
								"player_id": str(trigger.get("controller_player_id", "")),
								"playing_player_id": str(trigger.get("controller_player_id", "")),
								"source_instance_id": str(trigger.get("source_instance_id", "")),
								"source_controller_player_id": str(trigger.get("controller_player_id", "")),
								"lane_id": str(csa_location.get("lane_id", "")),
								"reason": "copy_summon_ability",
								"_copied_summon_descriptor": csa_trigger,
							})
							break
			"swap_creatures":
				var sc_source_id := str(trigger.get("source_instance_id", ""))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var sc_target_id := str(card.get("instance_id", ""))
					if sc_target_id == sc_source_id:
						continue
					var sc_source := _find_card_anywhere(match_state, sc_source_id)
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
			"increase_opponent_action_cost":
				var ioac_controller_id := str(trigger.get("controller_player_id", ""))
				var ioac_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not ioac_source.is_empty():
					ioac_source["_increase_opponent_action_cost"] = int(effect.get("amount", 1))
			"set_power_cap_in_lane":
				var spcil_controller_id := str(trigger.get("controller_player_id", ""))
				var spcil_opponent_id := _get_opposing_player_id(match_state.get("players", []), spcil_controller_id)
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
			"destroy_all_except_strongest_in_lane":
				var daesl_controller_id := str(trigger.get("controller_player_id", ""))
				var daesl_lane_id := str(effect.get("lane_id", ""))
				if daesl_lane_id.is_empty():
					var daesl_loc := MatchMutations.find_card_location(match_state, str(trigger.get("source_instance_id", "")))
					daesl_lane_id = str(daesl_loc.get("lane_id", ""))
				var daesl_all: Array = []
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) != daesl_lane_id:
						continue
					for daesl_ps in lane.get("player_slots", []):
						for daesl_card in daesl_ps.get("cards", []):
							if typeof(daesl_card) == TYPE_DICTIONARY:
								daesl_all.append(daesl_card)
				if daesl_all.size() > 1:
					var daesl_max_power := -1
					for daesl_card in daesl_all:
						var p := EvergreenRules.get_power(daesl_card)
						if p > daesl_max_power:
							daesl_max_power = p
					for daesl_card in daesl_all:
						if EvergreenRules.get_power(daesl_card) < daesl_max_power:
							var daesl_destroy := MatchMutations.discard_card(match_state, str(daesl_card.get("instance_id", "")), {"reason": reason})
							generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(daesl_card.get("instance_id", "")), "controller_player_id": str(daesl_card.get("controller_player_id", "")), "lane_id": daesl_lane_id})
							generated_events.append_array(daesl_destroy.get("events", []))
			"copy_from_opponent_deck":
				var cfod_controller_id := str(trigger.get("controller_player_id", ""))
				var cfod_opponent_id := _get_opposing_player_id(match_state.get("players", []), cfod_controller_id)
				var cfod_opponent := _get_player_state(match_state, cfod_opponent_id)
				var cfod_controller := _get_player_state(match_state, cfod_controller_id)
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
			"play_random_from_deck":
				var prfd_controller_id := str(trigger.get("controller_player_id", ""))
				var prfd_player := _get_player_state(match_state, prfd_controller_id)
				if not prfd_player.is_empty():
					var prfd_deck: Array = prfd_player.get(ZONE_DECK, [])
					if not prfd_deck.is_empty():
						var prfd_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_play_random", prfd_deck.size())
						var prfd_card: Dictionary = prfd_deck[prfd_idx]
						prfd_deck.remove_at(prfd_idx)
						prfd_card.erase("zone")
						var prfd_type := str(prfd_card.get("card_type", ""))
						if prfd_type == CARD_TYPE_CREATURE:
							var prfd_lane := _resolve_summon_lane_id(match_state, trigger, event, effect, prfd_controller_id)
							if not prfd_lane.is_empty():
								var prfd_result := MatchMutations.summon_card_to_lane(match_state, prfd_controller_id, prfd_card, prfd_lane, {"source_zone": ZONE_DECK})
								if bool(prfd_result.get("is_valid", false)):
									generated_events.append_array(prfd_result.get("events", []))
									generated_events.append(_build_summon_event(prfd_result["card"], prfd_controller_id, prfd_lane, int(prfd_result.get("slot_index", -1)), reason))
									_check_summon_abilities(match_state, prfd_result["card"])
			"play_top_of_deck":
				var ptod_controller_id := str(trigger.get("controller_player_id", ""))
				var ptod_player := _get_player_state(match_state, ptod_controller_id)
				if not ptod_player.is_empty():
					var ptod_deck: Array = ptod_player.get(ZONE_DECK, [])
					if not ptod_deck.is_empty():
						var ptod_card: Dictionary = ptod_deck.pop_back()
						ptod_card.erase("zone")
						var ptod_type := str(ptod_card.get("card_type", ""))
						if ptod_type == CARD_TYPE_CREATURE:
							var ptod_lane := _resolve_summon_lane_id(match_state, trigger, event, effect, ptod_controller_id)
							if not ptod_lane.is_empty():
								var ptod_result := MatchMutations.summon_card_to_lane(match_state, ptod_controller_id, ptod_card, ptod_lane, {"source_zone": ZONE_DECK})
								if bool(ptod_result.get("is_valid", false)):
									generated_events.append_array(ptod_result.get("events", []))
									generated_events.append(_build_summon_event(ptod_result["card"], ptod_controller_id, ptod_lane, int(ptod_result.get("slot_index", -1)), reason))
									_check_summon_abilities(match_state, ptod_result["card"])
			"copy_creature_from_deck_to_discard":
				var ccfdtd_controller_id := str(trigger.get("controller_player_id", ""))
				var ccfdtd_player := _get_player_state(match_state, ccfdtd_controller_id)
				if not ccfdtd_player.is_empty():
					var ccfdtd_deck: Array = ccfdtd_player.get(ZONE_DECK, [])
					var ccfdtd_discard: Array = ccfdtd_player.get(ZONE_DISCARD, [])
					var ccfdtd_creatures: Array = []
					for ccfdtd_card in ccfdtd_deck:
						if str(ccfdtd_card.get("card_type", "")) == CARD_TYPE_CREATURE:
							ccfdtd_creatures.append(ccfdtd_card)
					if not ccfdtd_creatures.is_empty():
						var ccfdtd_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_copy_to_discard", ccfdtd_creatures.size())
						var ccfdtd_source: Dictionary = ccfdtd_creatures[ccfdtd_idx]
						var ccfdtd_copy := MatchMutations.build_generated_card(match_state, ccfdtd_controller_id, ccfdtd_source)
						ccfdtd_copy["zone"] = ZONE_DISCARD
						ccfdtd_discard.push_front(ccfdtd_copy)
						generated_events.append({"event_type": "card_milled", "source_instance_id": str(trigger.get("source_instance_id", "")), "player_id": ccfdtd_controller_id, "milled_instance_id": str(ccfdtd_copy.get("instance_id", ""))})
			"randomize_attribute":
				var ra_attrs := ["strength", "intelligence", "willpower", "agility", "endurance", "neutral"]
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var ra_idx := _deterministic_index(match_state, str(card.get("instance_id", "")) + "_random_attr", ra_attrs.size())
					card["attributes"] = [ra_attrs[ra_idx]]
					generated_events.append({"event_type": "attribute_changed", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "attribute": ra_attrs[ra_idx]})
			"reveal_opponent_hand_card":
				var rohc_controller_id := str(trigger.get("controller_player_id", ""))
				var rohc_opponent_id := _get_opposing_player_id(match_state.get("players", []), rohc_controller_id)
				var rohc_opponent := _get_player_state(match_state, rohc_opponent_id)
				if not rohc_opponent.is_empty():
					var rohc_hand: Array = rohc_opponent.get(ZONE_HAND, [])
					if not rohc_hand.is_empty():
						var rohc_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_reveal_hand", rohc_hand.size())
						generated_events.append({"event_type": "opponent_hand_card_revealed", "source_instance_id": str(trigger.get("source_instance_id", "")), "controller_player_id": rohc_controller_id, "revealed_card": rohc_hand[rohc_idx].duplicate(true)})
			"top_deck_attribute_bonus":
				var tdab_controller_id := str(trigger.get("controller_player_id", ""))
				var tdab_player := _get_player_state(match_state, tdab_controller_id)
				var tdab_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
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
								for kw in tdab_bonus.get("keywords", []):
									EvergreenRules.ensure_card_state(tdab_source)
									var tdab_granted: Array = tdab_source.get("granted_keywords", [])
									if not tdab_granted.has(str(kw)):
										tdab_granted.append(str(kw))
										tdab_source["granted_keywords"] = tdab_granted
										generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(tdab_source.get("instance_id", "")), "keyword_id": str(kw)})
			"conditional_transform":
				var ct_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not ct_source.is_empty():
					var ct_template: Dictionary = effect.get("card_template", {})
					if not ct_template.is_empty():
						var ct_result := MatchMutations.transform_card(match_state, str(ct_source.get("instance_id", "")), ct_template, {"reason": reason})
						generated_events.append_array(ct_result.get("events", []))
			"sacrifice_and_absorb_stats":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var saas_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if saas_source.is_empty():
						continue
					var saas_power := EvergreenRules.get_power(card)
					var saas_health := int(card.get("health", 0))
					var saas_sac := MatchMutations.sacrifice_card(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")), {"reason": reason})
					generated_events.append_array(saas_sac.get("events", []))
					generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": str(card.get("controller_player_id", ""))})
					EvergreenRules.apply_stat_bonus(saas_source, saas_power, saas_health, reason)
					generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(saas_source.get("instance_id", "")), "power_bonus": saas_power, "health_bonus": saas_health, "reason": reason})
			"optional_discard_and_summon":
				var odas_controller_id := str(trigger.get("controller_player_id", ""))
				var odas_player := _get_player_state(match_state, odas_controller_id)
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
			"consume_card":
				var cc_controller_id := str(trigger.get("controller_player_id", ""))
				var cc_source_id := str(trigger.get("source_instance_id", ""))
				var cc_candidates := get_consume_candidates(match_state, cc_controller_id)
				if not cc_candidates.is_empty():
					var cc_candidate_ids: Array = []
					for cc_card in cc_candidates:
						cc_candidate_ids.append(str(cc_card.get("instance_id", "")))
					var cc_pending: Array = match_state.get("pending_consume_selections", [])
					cc_pending.append({
						"player_id": cc_controller_id,
						"source_instance_id": cc_source_id,
						"candidate_instance_ids": cc_candidate_ids,
						"has_target_mode": false,
						"trigger_index": int(trigger.get("trigger_index", 0)),
					})
			"draw_copy_of_consumed":
				# Draw a copy of the last consumed card — check event for consumed card info
				var dcoc_controller_id := str(trigger.get("controller_player_id", ""))
				var dcoc_target_id := str(event.get("target_instance_id", ""))
				var dcoc_target := _find_card_anywhere(match_state, dcoc_target_id)
				if not dcoc_target.is_empty():
					var dcoc_copy := MatchMutations.build_generated_card(match_state, dcoc_controller_id, dcoc_target)
					var dcoc_player := _get_player_state(match_state, dcoc_controller_id)
					if not dcoc_player.is_empty():
						dcoc_copy["zone"] = ZONE_HAND
						var dcoc_hand: Array = dcoc_player.get(ZONE_HAND, [])
						dcoc_hand.append(dcoc_copy)
						generated_events.append({"event_type": EVENT_CARD_DRAWN, "player_id": dcoc_controller_id, "source_instance_id": str(dcoc_copy.get("instance_id", ""))})
			"consume_and_copy_veteran":
				var cacv_controller_id := str(trigger.get("controller_player_id", ""))
				var cacv_source_id := str(trigger.get("source_instance_id", ""))
				var cacv_player := _get_player_state(match_state, cacv_controller_id)
				if not cacv_player.is_empty():
					var cacv_discard: Array = cacv_player.get(ZONE_DISCARD, [])
					var cacv_candidates: Array = []
					for cacv_card in cacv_discard:
						if typeof(cacv_card) != TYPE_DICTIONARY or str(cacv_card.get("card_type", "")) != CARD_TYPE_CREATURE:
							continue
						var cacv_triggers = cacv_card.get("triggered_abilities", [])
						if typeof(cacv_triggers) == TYPE_ARRAY:
							for cacv_t in cacv_triggers:
								if typeof(cacv_t) == TYPE_DICTIONARY and str(cacv_t.get("family", "")) == FAMILY_VETERAN:
									cacv_candidates.append(cacv_card)
									break
					if not cacv_candidates.is_empty():
						var cacv_candidate_ids: Array = []
						for cacv_c in cacv_candidates:
							cacv_candidate_ids.append(str(cacv_c.get("instance_id", "")))
						var cacv_pending: Array = match_state.get("pending_consume_selections", [])
						cacv_pending.append({
							"player_id": cacv_controller_id,
							"source_instance_id": cacv_source_id,
							"candidate_instance_ids": cacv_candidate_ids,
							"has_target_mode": false,
							"trigger_index": int(trigger.get("trigger_index", 0)),
						})
			"consume_and_reduce_matching_subtype_cost":
				var carmsc_controller_id := str(trigger.get("controller_player_id", ""))
				var carmsc_source_id := str(trigger.get("source_instance_id", ""))
				var carmsc_candidates := get_consume_candidates(match_state, carmsc_controller_id)
				if not carmsc_candidates.is_empty():
					var carmsc_candidate_ids: Array = []
					for carmsc_c in carmsc_candidates:
						carmsc_candidate_ids.append(str(carmsc_c.get("instance_id", "")))
					var carmsc_pending: Array = match_state.get("pending_consume_selections", [])
					carmsc_pending.append({
						"player_id": carmsc_controller_id,
						"source_instance_id": carmsc_source_id,
						"candidate_instance_ids": carmsc_candidate_ids,
						"has_target_mode": false,
						"trigger_index": int(trigger.get("trigger_index", 0)),
					})
			"modify_stats_if_shares_subtype_with_top_deck":
				var msisswtd_controller_id := str(trigger.get("controller_player_id", ""))
				var msisswtd_player := _get_player_state(match_state, msisswtd_controller_id)
				if not msisswtd_player.is_empty():
					var msisswtd_deck: Array = msisswtd_player.get(ZONE_DECK, [])
					if not msisswtd_deck.is_empty():
						var msisswtd_top: Dictionary = msisswtd_deck.back()
						var msisswtd_top_subtypes = msisswtd_top.get("subtypes", [])
						if typeof(msisswtd_top_subtypes) == TYPE_ARRAY:
							for card in _resolve_card_targets(match_state, trigger, event, effect):
								var msisswtd_card_subtypes = card.get("subtypes", [])
								if typeof(msisswtd_card_subtypes) == TYPE_ARRAY:
									var msisswtd_shares := false
									for st in msisswtd_card_subtypes:
										if msisswtd_top_subtypes.has(st):
											msisswtd_shares = true
											break
									if msisswtd_shares:
										var msisswtd_power := int(effect.get("power", 0))
										var msisswtd_health := int(effect.get("health", 0))
										EvergreenRules.apply_stat_bonus(card, msisswtd_power, msisswtd_health, reason)
										generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "power_bonus": msisswtd_power, "health_bonus": msisswtd_health, "reason": reason})
			"draw_if_wielder_has_items":
				var diwhi_source_id := str(trigger.get("source_instance_id", ""))
				var diwhi_source := _find_card_anywhere(match_state, diwhi_source_id)
				if not diwhi_source.is_empty():
					var diwhi_host_id := str(diwhi_source.get("attached_to_instance_id", ""))
					if not diwhi_host_id.is_empty():
						var diwhi_host := _find_card_anywhere(match_state, diwhi_host_id)
						var diwhi_items: Array = diwhi_host.get("attached_items", [])
						if diwhi_items.size() > 1:  # This item + at least one other
							var diwhi_controller := str(trigger.get("controller_player_id", ""))
							var diwhi_draw := draw_cards(match_state, diwhi_controller, 1, {"reason": reason, "source_instance_id": diwhi_source_id})
							generated_events.append_array(diwhi_draw.get("events", []))
			"equip_copies_from_discard":
				var ecfd_controller_id := str(trigger.get("controller_player_id", ""))
				var ecfd_player := _get_player_state(match_state, ecfd_controller_id)
				var ecfd_host_id := ""
				var ecfd_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not ecfd_source.is_empty():
					ecfd_host_id = str(ecfd_source.get("attached_to_instance_id", ""))
				if not ecfd_player.is_empty() and not ecfd_host_id.is_empty():
					var ecfd_discard: Array = ecfd_player.get(ZONE_DISCARD, [])
					var ecfd_items: Array = []
					for ecfd_card in ecfd_discard:
						if typeof(ecfd_card) == TYPE_DICTIONARY and str(ecfd_card.get("card_type", "")) == CARD_TYPE_ITEM:
							ecfd_items.append(ecfd_card)
					for ecfd_item in ecfd_items:
						ecfd_discard.erase(ecfd_item)
						ecfd_item.erase("zone")
						var ecfd_equip := MatchMutations.attach_item_to_creature(match_state, ecfd_controller_id, ecfd_item, ecfd_host_id, {"reason": reason})
						generated_events.append_array(ecfd_equip.get("events", []))
			"grant_slay_ability":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var gsa_effects: Array = effect.get("slay_effects", [])
					if not gsa_effects.is_empty():
						var gsa_triggers = card.get("triggered_abilities", [])
						if typeof(gsa_triggers) != TYPE_ARRAY:
							gsa_triggers = []
						gsa_triggers.append({"family": FAMILY_SLAY, "required_zone": ZONE_LANE, "effects": gsa_effects})
						card["triggered_abilities"] = gsa_triggers
						generated_events.append({"event_type": "ability_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "ability": "slay"})
			"return_stolen":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var rs_original_owner := str(card.get("original_owner_player_id", card.get("owner_player_id", "")))
					var rs_controller := str(card.get("controller_player_id", ""))
					if rs_original_owner != rs_controller and not rs_original_owner.is_empty():
						var rs_steal := MatchMutations.steal_card(match_state, rs_original_owner, str(card.get("instance_id", "")), {})
						generated_events.append_array(rs_steal.get("events", []))
			"double_max_magicka_gain":
				# This is tracked as a flag on the source creature — actual doubling checked in gain_max_magicka
				var dmmg_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not dmmg_source.is_empty():
					dmmg_source["_double_max_magicka_gain"] = true
			"mark_for_resummon":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["_resummon_on_death"] = true
					card["_resummon_controller"] = str(trigger.get("controller_player_id", ""))
					generated_events.append({"event_type": "marked_for_resummon", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", ""))})
			"grant_effect_this_turn":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var gettt_ability: Dictionary = effect.get("granted_ability", {})
					if not gettt_ability.is_empty():
						var gettt_triggers = card.get("triggered_abilities", [])
						if typeof(gettt_triggers) != TYPE_ARRAY:
							gettt_triggers = []
						var gettt_copy: Dictionary = gettt_ability.duplicate(true)
						gettt_copy["_expires_on_turn"] = int(match_state.get("turn_number", 0))
						gettt_triggers.append(gettt_copy)
						card["triggered_abilities"] = gettt_triggers
			"return_to_deck_and_draw_later":
				var rtdadl_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not rtdadl_source.is_empty():
					var rtdadl_controller := str(rtdadl_source.get("controller_player_id", ""))
					var rtdadl_template: Dictionary = effect.get("card_template", {})
					if rtdadl_template.is_empty():
						rtdadl_template = rtdadl_source.duplicate(true)
					var rtdadl_move := MatchMutations.move_card_to_zone(match_state, str(rtdadl_source.get("instance_id", "")), ZONE_DECK, {"reason": reason})
					generated_events.append_array(rtdadl_move.get("events", []))
			"grant_double_summon_this_turn":
				var gdst_controller_id := str(trigger.get("controller_player_id", ""))
				var gdst_player := _get_player_state(match_state, gdst_controller_id)
				if not gdst_player.is_empty():
					gdst_player["_double_summon_this_turn"] = true
					generated_events.append({"event_type": "double_summon_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "player_id": gdst_controller_id})
			"equip_copy_of_item":
				var ecoi_controller_id := str(trigger.get("controller_player_id", ""))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					if str(card.get("card_type", "")) == CARD_TYPE_ITEM:
						var ecoi_copy := MatchMutations.build_generated_card(match_state, ecoi_controller_id, card)
						for ecoi_target in _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("equip_target", "chosen_target"))):
							var ecoi_equip := MatchMutations.attach_item_to_creature(match_state, ecoi_controller_id, ecoi_copy, str(ecoi_target.get("instance_id", "")), {"reason": reason})
							generated_events.append_array(ecoi_equip.get("events", []))
							break
			"summon_from_hand_to_full_lane":
				# Allow summoning into a full lane by not checking capacity
				var sfhtfl_controller_id := str(trigger.get("controller_player_id", ""))
				var sfhtfl_player := _get_player_state(match_state, sfhtfl_controller_id)
				if not sfhtfl_player.is_empty():
					var sfhtfl_hand: Array = sfhtfl_player.get(ZONE_HAND, [])
					var sfhtfl_creatures: Array = []
					for sfhtfl_card in sfhtfl_hand:
						if str(sfhtfl_card.get("card_type", "")) == CARD_TYPE_CREATURE:
							sfhtfl_creatures.append(str(sfhtfl_card.get("instance_id", "")))
					if not sfhtfl_creatures.is_empty():
						match_state["pending_hand_selections"].append({
							"player_id": sfhtfl_controller_id,
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"candidate_instance_ids": sfhtfl_creatures,
							"then_op": "summon_from_hand_ignore_capacity",
							"then_context": {},
							"prompt": "Choose a creature from your hand to summon.",
						})
			"destroy_front_rune_and_steal_draw":
				var dfrsd_controller_id := str(trigger.get("controller_player_id", ""))
				var dfrsd_opponent_id := _get_opposing_player_id(match_state.get("players", []), dfrsd_controller_id)
				var dfrsd_opponent := _get_player_state(match_state, dfrsd_opponent_id)
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
						var dfrsd_controller := _get_player_state(match_state, dfrsd_controller_id)
						if not dfrsd_controller.is_empty():
							dfrsd_controller.get(ZONE_HAND, []).append(dfrsd_stolen)
							generated_events.append({"event_type": "card_stolen_from_discard", "source_instance_id": str(trigger.get("source_instance_id", "")), "stolen_instance_id": str(dfrsd_stolen.get("instance_id", "")), "from_player_id": dfrsd_opponent_id, "to_player_id": dfrsd_controller_id})
			"gain_unspent_magicka_from_last_turn":
				var gumflt_controller_id := str(trigger.get("controller_player_id", ""))
				var gumflt_player := _get_player_state(match_state, gumflt_controller_id)
				if not gumflt_player.is_empty():
					var gumflt_unspent := int(gumflt_player.get("_unspent_magicka_last_turn", 0))
					if gumflt_unspent > 0:
						gumflt_player["current_magicka"] = int(gumflt_player.get("current_magicka", 0)) + gumflt_unspent
						generated_events.append({"event_type": "magicka_restored", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_player_id": gumflt_controller_id, "amount": gumflt_unspent})
			"draw_or_treasure_hunt":
				# Treasure Map: draw a card matching the wielder's unfound treasure hunt types,
				# or draw from the top if no active hunts or no matching card in deck.
				var doth_controller_id := str(trigger.get("controller_player_id", ""))
				var doth_player := _get_player_state(match_state, doth_controller_id)
				if not doth_player.is_empty():
					var doth_deck: Array = doth_player.get(ZONE_DECK, [])
					if not doth_deck.is_empty():
						# Collect unfound hunt types from the wielder's active treasure hunts
						var doth_unfound_types: Array = []
						for doth_target in _resolve_card_targets(match_state, trigger, event, effect):
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
								if _card_matches_treasure_hunt(doth_deck[doth_i], doth_unfound_types):
									doth_matching_indices.append(doth_i)
						if not doth_matching_indices.is_empty():
							# Pick a random matching card from the deck
							var doth_rand := _deterministic_index(match_state, "treasure_map_%s" % str(trigger.get("source_instance_id", "")), doth_matching_indices.size())
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
							var doth_draw := draw_cards(match_state, doth_controller_id, 1, {"reason": "treasure_map", "source_instance_id": str(trigger.get("source_instance_id", ""))})
							generated_events.append_array(doth_draw.get("events", []))
			"summon_or_buff":
				# Aldora the Daring — summon token or buff existing token
				var sob_controller_id := str(trigger.get("controller_player_id", ""))
				var sob_template: Dictionary = effect.get("card_template", {})
				var sob_target_def_id := str(sob_template.get("definition_id", ""))
				# Look for an existing friendly creature matching the template's definition_id
				var sob_existing: Dictionary = {}
				if not sob_target_def_id.is_empty():
					for sob_lane in match_state.get("lanes", []):
						for sob_card in sob_lane.get("player_slots", {}).get(sob_controller_id, []):
							if typeof(sob_card) == TYPE_DICTIONARY and str(sob_card.get("definition_id", "")) == sob_target_def_id:
								sob_existing = sob_card
								break
						if not sob_existing.is_empty():
							break
				if sob_existing.is_empty() and not sob_template.is_empty():
					# No existing token — summon one
					var sob_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, sob_controller_id)
					if not sob_lane_id.is_empty():
						var sob_card := MatchMutations.build_generated_card(match_state, sob_controller_id, sob_template)
						var sob_result := MatchMutations.summon_card_to_lane(match_state, sob_controller_id, sob_card, sob_lane_id, {"source_zone": ZONE_GENERATED})
						if bool(sob_result.get("is_valid", false)):
							generated_events.append_array(sob_result.get("events", []))
							generated_events.append(_build_summon_event(sob_result["card"], sob_controller_id, sob_lane_id, int(sob_result.get("slot_index", -1)), reason))
				elif not sob_existing.is_empty():
					# Token exists — buff it
					var sob_power := int(effect.get("buff_power", 1))
					var sob_health := int(effect.get("buff_health", 1))
					EvergreenRules.apply_stat_bonus(sob_existing, sob_power, sob_health, reason)
					generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(sob_existing.get("instance_id", "")), "power_bonus": sob_power, "health_bonus": sob_health, "reason": reason})
			"summon_random_daedra_total_cost", "summon_random_daedra_by_gate_level":
				# Delegate to summon_random_from_catalog with Daedra filter
				var srd_filter: Dictionary = {"card_type": "creature", "required_subtype": "Daedra"}
				var srd_delegated := {"op": "summon_random_from_catalog", "filter": srd_filter}
				var srd_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, srd_delegated)
				if bool(srd_result.get("handled", false)):
					generated_events.append_array(srd_result.get("events", []))
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
			"sacrifice_and_equip_from_deck":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					var saed_controller_id := str(card.get("controller_player_id", ""))
					var saed_items: Array = card.get("attached_items", [])
					var saed_item_templates: Array = []
					for saed_item in saed_items:
						saed_item_templates.append(saed_item.duplicate(true))
					var saed_sac := MatchMutations.sacrifice_card(match_state, saed_controller_id, str(card.get("instance_id", "")), {"reason": reason})
					generated_events.append_array(saed_sac.get("events", []))
					# Summon a creature from deck and equip the items
					var saed_player := _get_player_state(match_state, saed_controller_id)
					if not saed_player.is_empty():
						var saed_deck: Array = saed_player.get(ZONE_DECK, [])
						var saed_candidates: Array = []
						for saed_dc in saed_deck:
							if str(saed_dc.get("card_type", "")) == CARD_TYPE_CREATURE:
								saed_candidates.append(saed_dc)
						if not saed_candidates.is_empty():
							var saed_idx := _deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_sac_equip", saed_candidates.size())
							var saed_target: Dictionary = saed_candidates[saed_idx]
							saed_deck.erase(saed_target)
							saed_target.erase("zone")
							var saed_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, saed_controller_id)
							if not saed_lane_id.is_empty():
								var saed_result := MatchMutations.summon_card_to_lane(match_state, saed_controller_id, saed_target, saed_lane_id, {"source_zone": ZONE_DECK})
								if bool(saed_result.get("is_valid", false)):
									generated_events.append_array(saed_result.get("events", []))
									generated_events.append(_build_summon_event(saed_result["card"], saed_controller_id, saed_lane_id, int(saed_result.get("slot_index", -1)), reason))
									for saed_item_t in saed_item_templates:
										var saed_new_item := MatchMutations.build_generated_card(match_state, saed_controller_id, saed_item_t)
										var saed_equip := MatchMutations.attach_item_to_creature(match_state, saed_controller_id, saed_new_item, str(saed_result["card"].get("instance_id", "")), {"reason": reason})
										generated_events.append_array(saed_equip.get("events", []))
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
			"aim_at":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["_aimed_by"] = str(trigger.get("source_instance_id", ""))
					var aim_amount := int(effect.get("amount", 0))
					card["_aim_damage"] = aim_amount
					generated_events.append({"event_type": "creature_aimed_at", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "amount": aim_amount})
			"conditional_drawn_card_bonus":
				# Gates of Madness: when you draw a card, check condition and apply bonus
				var cdcb_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not cdcb_source.is_empty():
					cdcb_source["_drawn_card_bonus"] = effect.get("bonus", {})
			"trigger_wax":
				var tw_source_id := str(trigger.get("source_instance_id", ""))
				var tw_controller_id := str(trigger.get("controller_player_id", ""))
				generated_events.append_array(_fire_wax_wane_on_other_friendly(match_state, tw_controller_id, tw_source_id, FAMILY_WAX))
			"trigger_wane":
				var twn_source_id := str(trigger.get("source_instance_id", ""))
				var twn_controller_id := str(trigger.get("controller_player_id", ""))
				generated_events.append_array(_fire_wax_wane_on_other_friendly(match_state, twn_controller_id, twn_source_id, FAMILY_WANE))
			"enable_dual_wax_wane":
				var edww_controller_id := str(trigger.get("controller_player_id", ""))
				var edww_player := _get_player_state(match_state, edww_controller_id)
				if not edww_player.is_empty():
					edww_player["_dual_wax_wane"] = true
			"consume_or_sacrifice":
				# Player chooses to consume from discard
				var cos_controller_id := str(trigger.get("controller_player_id", ""))
				var cos_source_id := str(trigger.get("source_instance_id", ""))
				var cos_candidates := get_consume_candidates(match_state, cos_controller_id)
				if not cos_candidates.is_empty():
					var cos_candidate_ids: Array = []
					for cos_c in cos_candidates:
						cos_candidate_ids.append(str(cos_c.get("instance_id", "")))
					var cos_pending: Array = match_state.get("pending_consume_selections", [])
					cos_pending.append({
						"player_id": cos_controller_id,
						"source_instance_id": cos_source_id,
						"candidate_instance_ids": cos_candidate_ids,
						"has_target_mode": false,
						"trigger_index": int(trigger.get("trigger_index", 0)),
					})
			"consume_all_creatures_in_discard_this_turn":
				var cacidt_controller_id := str(trigger.get("controller_player_id", ""))
				var cacidt_source_id := str(trigger.get("source_instance_id", ""))
				var cacidt_player := _get_player_state(match_state, cacidt_controller_id)
				if not cacidt_player.is_empty():
					var cacidt_discard: Array = cacidt_player.get(ZONE_DISCARD, [])
					var cacidt_targets: Array = []
					for cacidt_card in cacidt_discard:
						if typeof(cacidt_card) == TYPE_DICTIONARY and str(cacidt_card.get("card_type", "")) == CARD_TYPE_CREATURE:
							cacidt_targets.append(cacidt_card)
					if not cacidt_targets.is_empty():
						generated_events.append({"event_type": "mass_consume", "source_instance_id": cacidt_source_id, "player_id": cacidt_controller_id, "count": cacidt_targets.size()})
					for cacidt_target in cacidt_targets:
						var cacidt_result := MatchMutations.consume_card(match_state, cacidt_controller_id, cacidt_source_id, str(cacidt_target.get("instance_id", "")), {"reason": reason})
						generated_events.append_array(cacidt_result.get("events", []))
			"redirect_damage_to_self":
				var rdts_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not rdts_source.is_empty():
					rdts_source["_redirect_damage_to"] = str(trigger.get("source_instance_id", ""))
					for card in _resolve_card_targets(match_state, trigger, event, effect):
						card["_protected_by"] = str(trigger.get("source_instance_id", ""))
						generated_events.append({"event_type": "damage_redirect_set", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", ""))})
			"change_lane_type":
				var clt_lane_type := str(effect.get("lane_type", "shadow"))
				var clt_source_loc := MatchMutations.find_card_location(match_state, str(trigger.get("source_instance_id", "")))
				var clt_lane_id := str(clt_source_loc.get("lane_id", ""))
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) == clt_lane_id:
						lane["lane_type"] = clt_lane_type
						generated_events.append({"event_type": "lane_type_changed", "lane_id": clt_lane_id, "new_type": clt_lane_type, "source_instance_id": str(trigger.get("source_instance_id", ""))})
			"add_counter":
				var ac_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not ac_source.is_empty():
					var ac_counter_name := str(effect.get("counter_name", "counter"))
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
			"mark_target":
				for card in _resolve_card_targets(match_state, trigger, event, effect):
					card["_marked_by"] = str(trigger.get("source_instance_id", ""))
					card["_mark_effect"] = effect.get("mark_effect", {})
					generated_events.append({"event_type": "creature_marked", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", ""))})
			"copy_drawn_card_to_hand":
				var cdcth_controller_id := str(trigger.get("controller_player_id", ""))
				var cdcth_drawn_id := str(event.get("source_instance_id", event.get("drawn_instance_id", "")))
				var cdcth_drawn := _find_card_anywhere(match_state, cdcth_drawn_id)
				if not cdcth_drawn.is_empty():
					var cdcth_copy := MatchMutations.build_generated_card(match_state, cdcth_controller_id, cdcth_drawn)
					cdcth_copy["zone"] = ZONE_HAND
					var cdcth_player := _get_player_state(match_state, cdcth_controller_id)
					if not cdcth_player.is_empty():
						cdcth_player.get(ZONE_HAND, []).append(cdcth_copy)
						generated_events.append({"event_type": EVENT_CARD_DRAWN, "player_id": cdcth_controller_id, "source_instance_id": str(cdcth_copy.get("instance_id", ""))})
			"summon_random_from_collection":
				# Delegate to summon_random_from_catalog with collection filter
				var srfcoll_filter: Dictionary = {"card_type": "creature"}
				var srfcoll_subtype := str(effect.get("filter_subtype", ""))
				if not srfcoll_subtype.is_empty():
					srfcoll_filter["required_subtype"] = srfcoll_subtype
				var srfcoll_delegated := {"op": "summon_random_from_catalog", "filter": srfcoll_filter}
				var srfcoll_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, srfcoll_delegated)
				if bool(srfcoll_result.get("handled", false)):
					generated_events.append_array(srfcoll_result.get("events", []))
			"transform_deck":
				var td_controller_id := str(trigger.get("controller_player_id", ""))
				var td_player := _get_player_state(match_state, td_controller_id)
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
							var td_idx := _deterministic_index(match_state, str(td_card.get("instance_id", "")) + "_transform_deck", td_collectible.size())
							MatchMutations.change_card(td_card, td_collectible[td_idx])
						generated_events.append({"event_type": "deck_transformed", "source_instance_id": str(trigger.get("source_instance_id", "")), "player_id": td_controller_id, "count": td_deck.size()})
			"look_draw_discard":
				var ldd_controller_id := str(trigger.get("controller_player_id", ""))
				var ldd_player := _get_player_state(match_state, ldd_controller_id)
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
				var lgd_player := _get_player_state(match_state, lgd_controller_id)
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
				var scfd_opponent_id := _get_opposing_player_id(match_state.get("players", []), scfd_controller_id)
				var scfd_player := _get_player_state(match_state, scfd_controller_id)
				var scfd_opponent := _get_player_state(match_state, scfd_opponent_id)
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
					var scfd_lane_id := _resolve_summon_lane_id(match_state, trigger, event, effect, scfd_controller_id)
					if not scfd_lane_id.is_empty():
						var scfd_result := MatchMutations.summon_card_to_lane(match_state, scfd_controller_id, scfd_card, scfd_lane_id, {"source_zone": ZONE_GENERATED})
						if bool(scfd_result.get("is_valid", false)):
							generated_events.append_array(scfd_result.get("events", []))
							generated_events.append(_build_summon_event(scfd_result["card"], scfd_controller_id, scfd_lane_id, int(scfd_result.get("slot_index", -1)), reason))
			"player_battle_creature":
				# Dragon Aspect: player gains attack power and fights a creature
				var pbc_controller_id := str(trigger.get("controller_player_id", ""))
				var pbc_attack_power := int(effect.get("attack_power", 3))
				for card in _resolve_card_targets(match_state, trigger, event, effect):
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
						var pbc_player := _get_player_state(match_state, pbc_controller_id)
						if not pbc_player.is_empty():
							pbc_player["health"] = int(pbc_player.get("health", 0)) - pbc_creature_power
							generated_events.append({
								"event_type": EVENT_DAMAGE_RESOLVED,
								"target_player_id": pbc_controller_id,
								"target_type": "player",
								"amount": pbc_creature_power,
								"damage_kind": "combat",
							})
					if int(card.get("health", 0)) <= 0:
						var pbc_destroy := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")), {"reason": reason})
						generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": str(card.get("controller_player_id", ""))})
						generated_events.append_array(pbc_destroy.get("events", []))
			"learn_action":
				var la_controller_id := str(trigger.get("controller_player_id", ""))
				var la_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not la_source.is_empty():
					for card in _resolve_card_targets(match_state, trigger, event, effect):
						var la_learned: Array = la_source.get("_learned_actions", [])
						if typeof(la_learned) != TYPE_ARRAY:
							la_learned = []
						la_learned.append(card.duplicate(true))
						la_source["_learned_actions"] = la_learned
						generated_events.append({"event_type": "action_learned", "source_instance_id": str(trigger.get("source_instance_id", "")), "learned_card": str(card.get("name", ""))})
			"play_learned_actions":
				var pla_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not pla_source.is_empty():
					var pla_learned: Array = pla_source.get("_learned_actions", [])
					if typeof(pla_learned) == TYPE_ARRAY:
						var pla_controller := str(trigger.get("controller_player_id", ""))
						for pla_action in pla_learned:
							if typeof(pla_action) != TYPE_DICTIONARY:
								continue
							var pla_abilities = pla_action.get("triggered_abilities", [])
							if typeof(pla_abilities) != TYPE_ARRAY:
								continue
							for pla_ab in pla_abilities:
								if typeof(pla_ab) == TYPE_DICTIONARY and str(pla_ab.get("family", "")) == FAMILY_ON_PLAY:
									var pla_trigger := trigger.duplicate(true)
									pla_trigger["descriptor"] = pla_ab
									generated_events.append_array(_apply_effects(match_state, pla_trigger, event, {}))
			_:
				var resolved_effect := effect
				if effect.has("amount_source") and not str(effect.get("amount_source", "")).is_empty():
					resolved_effect = effect.duplicate(true)
					resolved_effect["amount"] = _resolve_amount(trigger, effect, match_state, event)
				var custom_result := ExtendedMechanicPacks.apply_custom_effect(match_state, trigger, event, resolved_effect)
				if bool(custom_result.get("handled", false)):
					generated_events.append_array(custom_result.get("events", []))
	return generated_events


static func _resolve_card_targets(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	var target := str(effect.get("target", "self"))
	# copies_in_hand_and_deck needs effect context, handled here instead of _resolve_card_targets_by_name
	if target == "copies_in_hand_and_deck":
		return _resolve_copies_in_hand_and_deck(match_state, trigger, effect)
	var targets := _resolve_card_targets_by_name(match_state, trigger, event, target)
	var filter_subtype := str(effect.get("target_filter_subtype", ""))
	if not filter_subtype.is_empty():
		var filtered: Array = []
		for card in targets:
			var subtypes: Array = card.get("subtypes", [])
			if typeof(subtypes) == TYPE_ARRAY and subtypes.has(filter_subtype):
				filtered.append(card)
		targets = filtered
	var filter_keyword := str(effect.get("target_filter_keyword", ""))
	if not filter_keyword.is_empty():
		var filtered: Array = []
		for card in targets:
			if EvergreenRules.has_keyword(card, filter_keyword):
				filtered.append(card)
		targets = filtered
	var filter_attribute := str(effect.get("target_filter_attribute", ""))
	if not filter_attribute.is_empty():
		var filtered: Array = []
		for card in targets:
			var attrs: Array = card.get("attributes", [])
			if typeof(attrs) == TYPE_ARRAY and attrs.has(filter_attribute):
				filtered.append(card)
		targets = filtered
	var filter_definition_id := str(effect.get("target_filter_definition_id", ""))
	if not filter_definition_id.is_empty():
		var filtered: Array = []
		for card in targets:
			if str(card.get("definition_id", "")) == filter_definition_id:
				filtered.append(card)
		targets = filtered
	var filter_max_power := int(effect.get("target_filter_max_power", -1))
	if filter_max_power >= 0:
		var filtered: Array = []
		for card in targets:
			if EvergreenRules.get_power(card) <= filter_max_power:
				filtered.append(card)
		targets = filtered
	if bool(effect.get("target_filter_wounded", false)):
		var filtered: Array = []
		for card in targets:
			if EvergreenRules.has_status(card, EvergreenRules.STATUS_WOUNDED):
				filtered.append(card)
		targets = filtered
	return targets


static func _resolve_card_targets_by_name(match_state: Dictionary, trigger: Dictionary, event: Dictionary, target: String) -> Array:
	var targets: Array = []
	match target:
		"self":
			var self_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not self_card.is_empty():
				targets.append(self_card)
		"assemble_targets":
			targets.append_array(ExtendedMechanicPacks._collect_factotums(match_state, str(trigger.get("controller_player_id", "")), str(trigger.get("source_instance_id", ""))))
		"assemble_targets_except_self":
			targets.append_array(ExtendedMechanicPacks._collect_factotums_except_self(match_state, str(trigger.get("controller_player_id", "")), str(trigger.get("source_instance_id", ""))))
		"host", "wielder":
			var host_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			var host_id := str(host_source.get("attached_to_instance_id", "")) if not host_source.is_empty() else ""
			if not host_id.is_empty():
				var host_card := _find_card_anywhere(match_state, host_id)
				if not host_card.is_empty():
					targets.append(host_card)
		"event_source":
			var source_card := _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
			if not source_card.is_empty():
				targets.append(source_card)
		"event_summoned_creature":
			var summoned_card := _find_card_anywhere(match_state, str(event.get("source_instance_id", "")))
			if not summoned_card.is_empty():
				targets.append(summoned_card)
		"event_target":
			var target_card := _find_card_anywhere(match_state, _event_target_instance_id(event))
			if not target_card.is_empty():
				targets.append(target_card)
		"event_subject", "event_drawn_card", "event_action":
			var subject_card := _find_card_anywhere(match_state, str(event.get("instance_id", event.get("drawn_instance_id", event.get("source_instance_id", "")))))
			if not subject_card.is_empty():
				targets.append(subject_card)
		"event_killer":
			var killer_card := _find_card_anywhere(match_state, str(event.get("destroyed_by_instance_id", "")))
			if not killer_card.is_empty():
				targets.append(killer_card)
		"event_damaged_creature", "damaged_creature":
			var dmc_id := _event_target_instance_id(event)
			if dmc_id.is_empty():
				dmc_id = str(event.get("instance_id", ""))
			if not dmc_id.is_empty():
				var dmc_card := _find_card_anywhere(match_state, dmc_id)
				if not dmc_card.is_empty():
					targets.append(dmc_card)
		"damage_source":
			var ds_id := str(event.get("source_instance_id", event.get("attacker_instance_id", "")))
			if not ds_id.is_empty():
				var ds_card := _find_card_anywhere(match_state, ds_id)
				if not ds_card.is_empty():
					targets.append(ds_card)
		"last_drawn_card":
			var ldc_id := str(event.get("drawn_instance_id", event.get("instance_id", "")))
			if not ldc_id.is_empty():
				var ldc_card := _find_card_anywhere(match_state, ldc_id)
				if not ldc_card.is_empty():
					targets.append(ldc_card)
		"last_summoned":
			var ls_id := str(event.get("source_instance_id", ""))
			if not ls_id.is_empty():
				var ls_card := _find_card_anywhere(match_state, ls_id)
				if not ls_card.is_empty():
					targets.append(ls_card)
		"last_stolen":
			var lst_id := str(event.get("target_instance_id", event.get("stolen_instance_id", "")))
			if not lst_id.is_empty():
				var lst_card := _find_card_anywhere(match_state, lst_id)
				if not lst_card.is_empty():
					targets.append(lst_card)
		"aimed_creature":
			var aim_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not aim_source.is_empty():
				var aim_target_id := str(aim_source.get("_aimed_at_instance_id", ""))
				if not aim_target_id.is_empty():
					var aim_card := _find_card_anywhere(match_state, aim_target_id)
					if not aim_card.is_empty():
						targets.append(aim_card)
		"moved_creatures":
			var mc_id := str(event.get("source_instance_id", event.get("moved_instance_id", "")))
			if not mc_id.is_empty():
				var mc_card := _find_card_anywhere(match_state, mc_id)
				if not mc_card.is_empty():
					targets.append(mc_card)
		"consuming_creature":
			var consumer_id := str(event.get("source_instance_id", ""))
			if not consumer_id.is_empty():
				var consumer_card := _find_card_anywhere(match_state, consumer_id)
				if not consumer_card.is_empty():
					targets.append(consumer_card)
		"copies_in_hand_and_deck":
			# Resolved in _resolve_card_targets where effect dict is available
			pass
		"all_enemies_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var controller_id := str(trigger.get("controller_player_id", ""))
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"all_friendly_in_lane", "other_friendly_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var controller_id := str(trigger.get("controller_player_id", ""))
			var self_id := str(trigger.get("source_instance_id", ""))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(controller_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != self_id:
						targets.append(card)
		"all_enemies", "all_other_enemies":
			var controller_id := str(trigger.get("controller_player_id", ""))
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_id)
			var ae_self_id := str(trigger.get("source_instance_id", "")) if target == "all_other_enemies" else ""
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						if not ae_self_id.is_empty() and str(card.get("instance_id", "")) == ae_self_id:
							continue
						targets.append(card)
		"all_friendly", "all_other_friendly", "all_friendly_creatures", "all_friendly_by_subtype", \
		"other_friendly_creatures", "other_friendly_by_subtype":
			var controller_id := str(trigger.get("controller_player_id", ""))
			var self_id := str(trigger.get("source_instance_id", ""))
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(controller_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != self_id:
						targets.append(card)
		"all_creatures", "all_other_creatures":
			var self_id := str(trigger.get("source_instance_id", ""))
			var exclude_self := target == "all_other_creatures"
			for lane in match_state.get("lanes", []):
				var player_slots: Dictionary = lane.get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY:
							if exclude_self and str(card.get("instance_id", "")) == self_id:
								continue
							targets.append(card)
		"all_other_creatures_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var self_id := str(trigger.get("source_instance_id", ""))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != self_id:
							targets.append(card)
		"all_creatures_in_lane":
			var lane_index := int(trigger.get("lane_index", -1))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var player_slots: Dictionary = lanes[lane_index].get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY:
							targets.append(card)
		"chosen_target", "chosen_friendly_creature", "chosen_friendly", "chosen_enemy", \
		"chosen_friendly_optional", "chosen_targets", "chosen_target_pair":
			var chosen_id := str(trigger.get("_chosen_target_id", ""))
			if not chosen_id.is_empty():
				var chosen_card := _find_card_anywhere(match_state, chosen_id)
				if not chosen_card.is_empty():
					targets.append(chosen_card)
		"secretly_chosen_target":
			var sct_source_id := str(trigger.get("source_instance_id", ""))
			var sct_source := _find_card_anywhere(match_state, sct_source_id)
			if not sct_source.is_empty():
				var sct_target_id := str(sct_source.get("_secretly_chosen_target_id", ""))
				if not sct_target_id.is_empty():
					var sct_target := _find_card_anywhere(match_state, sct_target_id)
					if not sct_target.is_empty():
						targets.append(sct_target)
		"random_enemy", "random_enemy_creature":
			var all_enemies := _resolve_card_targets_by_name(match_state, trigger, event, "all_enemies")
			if not all_enemies.is_empty():
				targets.append(all_enemies[randi() % all_enemies.size()])
		"random_friendly":
			var all_friendly := _resolve_card_targets_by_name(match_state, trigger, event, "all_friendly")
			if not all_friendly.is_empty():
				targets.append(all_friendly[randi() % all_friendly.size()])
		"random_enemy_in_lane":
			var all_enemies_lane := _resolve_card_targets_by_name(match_state, trigger, event, "all_enemies_in_lane")
			if not all_enemies_lane.is_empty():
				targets.append(all_enemies_lane[randi() % all_enemies_lane.size()])
		"random_friendly_in_lane":
			var all_friendly_lane := _resolve_card_targets_by_name(match_state, trigger, event, "all_friendly_in_lane")
			if not all_friendly_lane.is_empty():
				targets.append(all_friendly_lane[randi() % all_friendly_lane.size()])
		"random_creature":
			var all_creatures := _resolve_card_targets_by_name(match_state, trigger, event, "all_creatures")
			if not all_creatures.is_empty():
				targets.append(all_creatures[randi() % all_creatures.size()])
		"random_friendly_in_each_lane", "friendly_in_each_lane":
			var rfiel_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				var rfiel_slots = lane.get("player_slots", {}).get(rfiel_controller_id, [])
				var rfiel_candidates: Array = []
				for card in rfiel_slots:
					if typeof(card) == TYPE_DICTIONARY:
						rfiel_candidates.append(card)
				if not rfiel_candidates.is_empty():
					targets.append(rfiel_candidates[randi() % rfiel_candidates.size()])
		"random_enemy_in_each_lane":
			var reiel_controller_id := str(trigger.get("controller_player_id", ""))
			var reiel_opponent_id := _get_opposing_player_id(match_state.get("players", []), reiel_controller_id)
			for lane in match_state.get("lanes", []):
				var reiel_slots = lane.get("player_slots", {}).get(reiel_opponent_id, [])
				var reiel_candidates: Array = []
				for card in reiel_slots:
					if typeof(card) == TYPE_DICTIONARY:
						reiel_candidates.append(card)
				if not reiel_candidates.is_empty():
					targets.append(reiel_candidates[randi() % reiel_candidates.size()])
		"random_creature_in_hand":
			var rcih_controller_id := str(trigger.get("controller_player_id", ""))
			var rcih_player := _get_player_state(match_state, rcih_controller_id)
			if not rcih_player.is_empty():
				var rcih_candidates: Array = []
				for card in rcih_player.get(ZONE_HAND, []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						rcih_candidates.append(card)
				if not rcih_candidates.is_empty():
					targets.append(rcih_candidates[randi() % rcih_candidates.size()])
		"all_friendly_in_event_lane", "all_creatures_in_event_lane", "all_enemies_in_event_lane":
			var event_lane_id := str(event.get("lane_id", ""))
			if not event_lane_id.is_empty():
				var controller_id := str(trigger.get("controller_player_id", ""))
				var friendly_only := target == "all_friendly_in_event_lane"
				var enemies_only := target == "all_enemies_in_event_lane"
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) != event_lane_id:
						continue
					var player_slots: Dictionary = lane.get("player_slots", {})
					for pid in player_slots.keys():
						if friendly_only and str(pid) != controller_id:
							continue
						if enemies_only and str(pid) == controller_id:
							continue
						for card in player_slots[pid]:
							if typeof(card) == TYPE_DICTIONARY:
								targets.append(card)
		"top_friendly_creature_in_deck":
			var tfcid_controller_id := str(trigger.get("controller_player_id", ""))
			var tfcid_player := _get_player_state(match_state, tfcid_controller_id)
			if not tfcid_player.is_empty():
				var tfcid_deck: Array = tfcid_player.get(ZONE_DECK, [])
				for i in range(tfcid_deck.size() - 1, -1, -1):
					var tfcid_card = tfcid_deck[i]
					if typeof(tfcid_card) == TYPE_DICTIONARY and str(tfcid_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						targets.append(tfcid_card)
						break
		"top_creatures_in_deck", "creatures_in_deck":
			var tcid_controller_id := str(trigger.get("controller_player_id", ""))
			var tcid_player := _get_player_state(match_state, tcid_controller_id)
			if not tcid_player.is_empty():
				var tcid_deck: Array = tcid_player.get(ZONE_DECK, [])
				for i in range(tcid_deck.size() - 1, -1, -1):
					var tcid_card = tcid_deck[i]
					if typeof(tcid_card) == TYPE_DICTIONARY and str(tcid_card.get("card_type", "")) == CARD_TYPE_CREATURE:
						targets.append(tcid_card)
		"highest_cost_creature_in_opponent_hand":
			var hccioh_controller_id := str(trigger.get("controller_player_id", ""))
			var hccioh_opponent_id := _get_opposing_player_id(match_state.get("players", []), hccioh_controller_id)
			var hccioh_player := _get_player_state(match_state, hccioh_opponent_id)
			if not hccioh_player.is_empty():
				var hccioh_best: Dictionary = {}
				var hccioh_best_cost := -1
				for card in hccioh_player.get(ZONE_HAND, []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						var card_cost := int(card.get("cost", 0))
						if card_cost > hccioh_best_cost:
							hccioh_best = card
							hccioh_best_cost = card_cost
				if not hccioh_best.is_empty():
					targets.append(hccioh_best)
		"all_enemies_with_less_power":
			var aewlp_controller_id := str(trigger.get("controller_player_id", ""))
			var aewlp_opponent_id := _get_opposing_player_id(match_state.get("players", []), aewlp_controller_id)
			var aewlp_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			var aewlp_self_power := EvergreenRules.get_power(aewlp_source) if not aewlp_source.is_empty() else 0
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(aewlp_opponent_id, []):
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules.get_power(card) < aewlp_self_power:
						targets.append(card)
		"all_enemies_with_same_name":
			var aewsn_target_id := _event_target_instance_id(event)
			var aewsn_target := _find_card_anywhere(match_state, aewsn_target_id)
			var aewsn_def_id := str(aewsn_target.get("definition_id", "")) if not aewsn_target.is_empty() else ""
			if not aewsn_def_id.is_empty():
				var aewsn_controller_id := str(trigger.get("controller_player_id", ""))
				var aewsn_opponent_id := _get_opposing_player_id(match_state.get("players", []), aewsn_controller_id)
				for lane in match_state.get("lanes", []):
					for card in lane.get("player_slots", {}).get(aewsn_opponent_id, []):
						if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == aewsn_def_id:
							if str(card.get("instance_id", "")) != aewsn_target_id:
								targets.append(card)
		"all_enemies_in_chosen_lane":
			var aeicl_controller_id := str(trigger.get("controller_player_id", ""))
			var aeicl_opponent_id := _get_opposing_player_id(match_state.get("players", []), aeicl_controller_id)
			var aeicl_lane_id := str(trigger.get("_chosen_lane_id", event.get("lane_id", "")))
			for lane in match_state.get("lanes", []):
				if str(lane.get("lane_id", "")) == aeicl_lane_id:
					for card in lane.get("player_slots", {}).get(aeicl_opponent_id, []):
						if typeof(card) == TYPE_DICTIONARY:
							targets.append(card)
		"all_friendly_in_target_lane":
			var afitl_controller_id := str(trigger.get("controller_player_id", ""))
			var afitl_lane_id := str(event.get("lane_id", ""))
			if not afitl_lane_id.is_empty():
				for lane in match_state.get("lanes", []):
					if str(lane.get("lane_id", "")) == afitl_lane_id:
						for card in lane.get("player_slots", {}).get(afitl_controller_id, []):
							if typeof(card) == TYPE_DICTIONARY:
								targets.append(card)
		"all_friendly_with_keyword":
			var afwk_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(afwk_controller_id, []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"all_friendly_animals":
			var afa_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(afa_controller_id, []):
					if typeof(card) == TYPE_DICTIONARY:
						var afa_subtypes = card.get("subtypes", [])
						if typeof(afa_subtypes) == TYPE_ARRAY and (afa_subtypes.has("Beast") or afa_subtypes.has("Animal")):
							targets.append(card)
		"all_friendly_oblivion_gates":
			var afog_controller_id := str(trigger.get("controller_player_id", ""))
			var afog_player := _get_player_state(match_state, afog_controller_id)
			if not afog_player.is_empty():
				for card in afog_player.get(ZONE_SUPPORT, []):
					if typeof(card) == TYPE_DICTIONARY:
						var afog_subtypes = card.get("subtypes", [])
						if typeof(afog_subtypes) == TYPE_ARRAY and afog_subtypes.has("Oblivion Gate"):
							targets.append(card)
		"crowned_creatures":
			for lane in match_state.get("lanes", []):
				var player_slots: Dictionary = lane.get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY and EvergreenRules.has_raw_status(card, "crowned"):
							targets.append(card)
		"damaged_enemy":
			var de_controller_id := str(trigger.get("controller_player_id", ""))
			var de_opponent_id := _get_opposing_player_id(match_state.get("players", []), de_controller_id)
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(de_opponent_id, []):
					if typeof(card) == TYPE_DICTIONARY and int(card.get("damage_marked", 0)) > 0:
						targets.append(card)
		"treasure_card", "treasure_card_copy":
			var tc_source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not tc_source.is_empty():
				var tc_id := str(tc_source.get("_treasure_card_instance_id", ""))
				if not tc_id.is_empty():
					var tc_card := _find_card_anywhere(match_state, tc_id)
					if not tc_card.is_empty():
						targets.append(tc_card)
		"friendly_by_name":
			var fbn_controller_id := str(trigger.get("controller_player_id", ""))
			for lane in match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(fbn_controller_id, []):
					if typeof(card) == TYPE_DICTIONARY:
						targets.append(card)
		"all", "all_creatures_in_hand":
			# all_creatures_in_hand handled by custom ops; "all" is a fallback to all lane creatures
			for lane in match_state.get("lanes", []):
				var player_slots: Dictionary = lane.get("player_slots", {})
				for pid in player_slots.keys():
					for card in player_slots[pid]:
						if typeof(card) == TYPE_DICTIONARY:
							targets.append(card)
	return targets


static func _resolve_player_targets(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Array:
	var target_player := str(effect.get("target_player", "controller"))
	match target_player:
		"controller":
			return [str(trigger.get("controller_player_id", ""))]
		"opponent":
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), str(trigger.get("controller_player_id", "")))
			return [] if opponent_id.is_empty() else [opponent_id]
		"event_player":
			var player_id := str(event.get("player_id", event.get("playing_player_id", event.get("target_player_id", ""))))
			return [] if player_id.is_empty() else [player_id]
		"target_player":
			var event_target_player := str(event.get("target_player_id", ""))
			return [] if event_target_player.is_empty() else [event_target_player]
		"chosen_target_player":
			var chosen_pid := str(trigger.get("_chosen_target_player_id", ""))
			return [] if chosen_pid.is_empty() else [chosen_pid]
	return []


## Resolve copies_in_hand_and_deck target with consumed creature name matching.
static func _resolve_copies_in_hand_and_deck(match_state: Dictionary, trigger: Dictionary, effect: Dictionary) -> Array:
	var targets: Array = []
	var controller_id := str(trigger.get("controller_player_id", ""))
	var match_field := str(effect.get("match", ""))
	var definition_id := ""
	if match_field == "consumed_creature_name":
		var consumed := _get_consumed_card_info(trigger)
		if consumed.is_empty():
			var source := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not source.is_empty():
				consumed = source.get("_consumed_card_info", {})
		definition_id = str(consumed.get("definition_id", ""))
	if not definition_id.is_empty():
		var player := _get_player_state(match_state, controller_id)
		if not player.is_empty():
			for card in player.get(ZONE_HAND, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == definition_id:
					targets.append(card)
			for card in player.get(ZONE_DECK, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == definition_id:
					targets.append(card)
	return targets


## Resolve an effect amount, checking for consumed_creature_* source references.
static func _resolve_consumed_amount(trigger: Dictionary, effect: Dictionary) -> int:
	return _resolve_amount(trigger, effect, {}, {})


static func _resolve_amount(trigger: Dictionary, effect: Dictionary, match_state: Dictionary, event: Dictionary) -> int:
	var amount_source := str(effect.get("amount_source", ""))
	if amount_source.is_empty():
		return int(effect.get("amount", 0))
	if amount_source.begins_with("consumed_creature_"):
		var consumed_info: Dictionary = _get_consumed_card_info(trigger)
		if amount_source == "consumed_creature_power":
			return int(consumed_info.get("power", 0))
		elif amount_source == "consumed_creature_health":
			return int(consumed_info.get("health", 0))
	if amount_source == "self_power":
		var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
		if not source_card.is_empty():
			return EvergreenRules.get_power(source_card)
	if amount_source == "self_health":
		var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
		if not source_card.is_empty():
			return int(source_card.get("health", 0)) - int(source_card.get("damage_marked", 0))
	if amount_source == "self_power_plus_health":
		var source_card := _find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
		if not source_card.is_empty():
			return EvergreenRules.get_power(source_card) + int(source_card.get("health", 0)) - int(source_card.get("damage_marked", 0))
	if amount_source == "damage_taken":
		return int(event.get("damage_amount", event.get("amount", 0)))
	if amount_source == "heal_amount":
		return int(event.get("amount", 0))
	return int(effect.get("amount", 0))


## Get consumed card info from trigger context or from the source card.
static func _get_consumed_card_info(trigger: Dictionary) -> Dictionary:
	var info: Dictionary = trigger.get("_consumed_card_info", {})
	if not info.is_empty():
		return info
	# Fallback: check the source card for stored consumed info
	# This is used when effects fire via resolve_targeted_effect after consume
	return {}


static func _resolve_count_multiplier(match_state: Dictionary, trigger: Dictionary, _event: Dictionary, effect: Dictionary) -> int:
	var count_source := str(effect.get("count_source", ""))
	if count_source.is_empty():
		return 1
	var controller_player_id := str(trigger.get("controller_player_id", ""))
	var exclude_self := bool(effect.get("count_exclude_self", false))
	var self_instance_id := str(trigger.get("source_instance_id", ""))
	var count := 0
	match count_source:
		"friendly_creatures":
			var required_attr := str(effect.get("count_required_attribute", ""))
			for lane in match_state.get("lanes", []):
				var slots = lane.get("player_slots", {}).get(controller_player_id, [])
				for card in slots:
					if typeof(card) != TYPE_DICTIONARY:
						continue
					if exclude_self and str(card.get("instance_id", "")) == self_instance_id:
						continue
					if not required_attr.is_empty():
						var attrs = card.get("attributes", [])
						if typeof(attrs) != TYPE_ARRAY or not attrs.has(required_attr):
							continue
					count += 1
		"enemy_creatures_same_lane":
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var lane_index := int(trigger.get("lane_index", -1))
			var lanes: Array = match_state.get("lanes", [])
			if lane_index >= 0 and lane_index < lanes.size():
				var slots = lanes[lane_index].get("player_slots", {}).get(opponent_id, [])
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY:
						count += 1
		"friendly_discard_creatures":
			var player := _get_player_state(match_state, controller_player_id)
			if not player.is_empty():
				for card in player.get("discard", []):
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == CARD_TYPE_CREATURE:
						count += 1
		"destroyed_enemy_runes":
			var opponent_id := _get_opposing_player_id(match_state.get("players", []), controller_player_id)
			var opponent := _get_player_state(match_state, opponent_id)
			if not opponent.is_empty():
				var remaining: Variant = opponent.get("rune_thresholds", [])
				count = 5 - (remaining.size() if typeof(remaining) == TYPE_ARRAY else 0)
		"friendly_creatures_with_keyword":
			var required_kw := str(effect.get("count_required_keyword", ""))
			if not required_kw.is_empty():
				for lane in match_state.get("lanes", []):
					var slots = lane.get("player_slots", {}).get(controller_player_id, [])
					for card in slots:
						if typeof(card) != TYPE_DICTIONARY:
							continue
						if exclude_self and str(card.get("instance_id", "")) == self_instance_id:
							continue
						if EvergreenRules.has_keyword(card, required_kw):
							count += 1
		"friendly_deaths_in_lane_this_turn":
			var trigger_lane_index := int(trigger.get("lane_index", -1))
			if trigger_lane_index < 0:
				return 0
			var lanes: Array = match_state.get("lanes", [])
			if trigger_lane_index >= lanes.size():
				return 0
			var lane_id := str(lanes[trigger_lane_index].get("lane_id", ""))
			var event_log: Array = match_state.get("event_log", [])
			for i in range(event_log.size() - 1, -1, -1):
				var logged = event_log[i]
				if str(logged.get("event_type", "")) == "turn_started":
					break
				if str(logged.get("event_type", "")) == "creature_destroyed":
					if str(logged.get("lane_id", "")) == lane_id:
						if str(logged.get("controller_player_id", "")) == controller_player_id:
							count += 1
	return count


static func _deterministic_index(match_state: Dictionary, context_id: String, pool_size: int) -> int:
	if pool_size <= 0:
		return 0
	var fingerprint := "%s|%s|%s" % [str(match_state.get("rng_seed", 0)), str(match_state.get("turn_number", 0)), context_id]
	var seed_value: int = 1469598103934665603
	for byte in fingerprint.to_utf8_buffer():
		seed_value = int((seed_value * 1099511628211 + int(byte)) % 9223372036854775783)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randi_range(0, pool_size - 1)


static func _resolve_effect_template(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary) -> Dictionary:
	var template: Dictionary = effect.get("card_template", {})
	if not template.is_empty():
		return template
	var source_cards := _resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("source_target", "event_source")))
	return {} if source_cards.is_empty() else source_cards[0].duplicate(true)


static func _process_treasure_hunt(match_state: Dictionary, trigger: Dictionary, event: Dictionary, descriptor: Dictionary) -> Dictionary:
	var events: Array = []
	var source_id := str(trigger.get("source_instance_id", ""))
	var source := _find_card_anywhere(match_state, source_id)
	if source.is_empty():
		return {"events": events, "hunt_complete": false}
	var trigger_index := int(trigger.get("trigger_index", 0))
	var spent_key := "_th_%d_spent" % trigger_index
	if bool(source.get(spent_key, false)):
		return {"events": events, "hunt_complete": false}
	var hunt_types = descriptor.get("hunt_types", [])
	if typeof(hunt_types) != TYPE_ARRAY or hunt_types.is_empty():
		return {"events": events, "hunt_complete": false}
	# Get the drawn card from the event
	var drawn_id := str(event.get("drawn_instance_id", event.get("instance_id", "")))
	if drawn_id.is_empty():
		return {"events": events, "hunt_complete": false}
	var drawn_card := _find_card_anywhere(match_state, drawn_id)
	if drawn_card.is_empty():
		return {"events": events, "hunt_complete": false}
	var controller_id := str(trigger.get("controller_player_id", ""))
	var hunt_count := int(descriptor.get("hunt_count", 0))
	var is_multi_type: bool = hunt_types.size() > 1 and not hunt_types.has("any") and hunt_count == 0
	if is_multi_type:
		# Multi-type hunt (e.g. Aldora: Action, Creature, Item, Support) — need one of each type
		var found_key := "_th_%d_found" % trigger_index
		var found_types: Array = []
		var raw_found = source.get(found_key, [])
		if typeof(raw_found) == TYPE_ARRAY:
			found_types = raw_found.duplicate()
		# Find which unfound type this drawn card matches
		var matched_type := ""
		for ht in hunt_types:
			if found_types.has(str(ht)):
				continue
			if _card_matches_treasure_hunt(drawn_card, [ht]):
				matched_type = str(ht)
				break
		if matched_type.is_empty():
			return {"events": events, "hunt_complete": false}
		found_types.append(matched_type)
		source[found_key] = found_types
		source["_treasure_card_instance_id"] = drawn_id
		events.append({
			"event_type": "treasure_found",
			"source_instance_id": source_id,
			"controller_player_id": controller_id,
			"player_id": controller_id,
			"count": found_types.size(),
			"drawn_instance_id": drawn_id,
		})
		if found_types.size() >= hunt_types.size():
			source[spent_key] = true
			return {"events": events, "hunt_complete": true}
	else:
		# Single-type or "any" hunt — count matches until hunt_count reached
		if not _card_matches_treasure_hunt(drawn_card, hunt_types):
			return {"events": events, "hunt_complete": false}
		if hunt_count <= 0:
			hunt_count = 1
		var count_key := "_th_%d_count" % trigger_index
		var current_count := int(source.get(count_key, 0))
		current_count += 1
		source[count_key] = current_count
		source["_treasure_card_instance_id"] = drawn_id
		events.append({
			"event_type": "treasure_found",
			"source_instance_id": source_id,
			"controller_player_id": controller_id,
			"player_id": controller_id,
			"count": current_count,
			"drawn_instance_id": drawn_id,
		})
		if current_count >= hunt_count:
			source[spent_key] = true
			return {"events": events, "hunt_complete": true}
	return {"events": events, "hunt_complete": false}


static func _card_matches_treasure_hunt(card: Dictionary, hunt_types: Array) -> bool:
	if hunt_types.has("any"):
		return true
	var card_type := str(card.get("card_type", ""))
	for ht in hunt_types:
		var hunt_type := str(ht)
		match hunt_type:
			"creature", "action", "item", "support":
				if card_type == hunt_type:
					return true
			"zero_cost":
				if int(card.get("cost", 0)) == 0:
					return true
			"neutral":
				# Neutral cards have no primary attributes (attributes array is empty after normalization)
				var neutral_attrs = card.get("attributes", [])
				if typeof(neutral_attrs) != TYPE_ARRAY or neutral_attrs.is_empty():
					return true
			_:
				# Check as a keyword
				if EvergreenRules.has_keyword(card, hunt_type):
					return true
				# Check in base keywords array
				var keywords = card.get("keywords", [])
				if typeof(keywords) == TYPE_ARRAY and keywords.has(hunt_type):
					return true
				# Check as an attribute
				var attributes = card.get("attributes", [])
				if typeof(attributes) == TYPE_ARRAY and attributes.has(hunt_type):
					return true
	return false


static func _resolve_summon_lane_id(match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary, controller_id: String) -> String:
	var lane_id := str(effect.get("lane_id", effect.get("target_lane_id", "")))
	if lane_id == "same":
		lane_id = str(event.get("lane_id", ""))
	if lane_id == "other_lane":
		var source_lane := str(event.get("lane_id", ""))
		for lane in match_state.get("lanes", []):
			var lid := str(lane.get("lane_id", ""))
			if lid != source_lane and not lid.is_empty():
				lane_id = lid
				break
	if lane_id.is_empty() or lane_id == "other_lane":
		var trigger_lane_index := int(trigger.get("lane_index", -1))
		var lanes: Array = match_state.get("lanes", [])
		if trigger_lane_index >= 0 and trigger_lane_index < lanes.size():
			lane_id = str(lanes[trigger_lane_index].get("lane_id", ""))
	if lane_id.is_empty():
		# Fall back to lane with most open slots
		var best_lane := ""
		var best_open := -1
		for lane in match_state.get("lanes", []):
			var lid := str(lane.get("lane_id", ""))
			var open_info := _get_lane_open_slots(match_state, lid, controller_id)
			var open_count := int(open_info.get("open_slots", 0))
			if open_count > best_open:
				best_open = open_count
				best_lane = lid
		lane_id = best_lane
	return lane_id


static func _build_summon_event(card: Dictionary, player_id: String, lane_id: String, slot_index: int, reason: String) -> Dictionary:
	return {
		"event_type": EVENT_CREATURE_SUMMONED,
		"player_id": player_id,
		"playing_player_id": player_id,
		"source_instance_id": str(card.get("instance_id", "")),
		"source_controller_player_id": str(card.get("controller_player_id", player_id)),
		"lane_id": lane_id,
		"slot_index": slot_index,
		"reason": reason,
	}


static func _get_lane_open_slots(match_state: Dictionary, lane_id: String, player_id: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		var player_slots: Array = lane.get("player_slots", {}).get(player_id, [])
		var slot_capacity := int(lane.get("slot_capacity", 0))
		return {"open_slots": maxi(0, slot_capacity - player_slots.size())}
	return {"open_slots": 0}


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
		var player := _get_player_state(match_state, player_id)
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
	var player := _get_player_state(match_state, player_id)
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
		out_of_cards_event["resulting_health"] = int(_get_player_state(match_state, player_id).get("health", 0))
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
	return _is_prophecy_card(card)


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


static func _is_prophecy_card(card: Dictionary) -> bool:
	return _dictionary_has_string(card.get("rules_tags", []), RULE_TAG_PROPHECY) or _dictionary_has_string(card.get("keywords", []), RULE_TAG_PROPHECY)


static func _dictionary_has_string(values, expected: String) -> bool:
	if typeof(values) != TYPE_ARRAY:
		return false
	for value in values:
		if str(value) == expected:
			return true
	return false


static func _find_card_index(cards, instance_id: String) -> int:
	if typeof(cards) != TYPE_ARRAY:
		return -1
	for index in range(cards.size()):
		var card = cards[index]
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
			return index
	return -1


static func _get_opposing_player_id(players, player_id: String) -> String:
	if typeof(players) != TYPE_ARRAY:
		return ""
	for player in players:
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != player_id:
			return str(player.get("player_id", ""))
	return ""


static func _invalid_result(message: String) -> Dictionary:
	return {
		"is_valid": false,
		"errors": [message],
	}


static func _validate_action_owner(match_state: Dictionary, player_id: String, action_name: String) -> Dictionary:
	if match_state.get("phase", "") != "action":
		return _invalid_result("%s can only be used during the action phase." % action_name)
	if str(match_state.get("active_player_id", "")) != player_id:
		return _invalid_result("%s is only legal for the active player." % action_name)
	if _get_player_state(match_state, player_id).is_empty():
		return _invalid_result("Unknown player_id: %s" % player_id)
	return {"is_valid": true, "errors": []}


static func _get_available_magicka(player: Dictionary) -> int:
	return maxi(0, int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0)))


static func _spend_magicka(match_state: Dictionary, player_id: String, amount: int) -> void:
	var player := _get_player_state(match_state, player_id)
	var remaining := amount
	var temporary_magicka := int(player.get("temporary_magicka", 0))
	if temporary_magicka > 0:
		var temporary_spent := mini(temporary_magicka, remaining)
		player["temporary_magicka"] = temporary_magicka - temporary_spent
		remaining -= temporary_spent
	if remaining > 0:
		player["current_magicka"] = maxi(0, int(player.get("current_magicka", 0)) - remaining)


static func _get_aura_cost_reduction(match_state: Dictionary, player_id: String, card: Dictionary) -> int:
	var total := 0
	var card_type := str(card.get("card_type", ""))
	var all_aura_sources: Array = []
	for lane in match_state.get("lanes", []):
		for lane_card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(lane_card) != TYPE_DICTIONARY:
				continue
			var aura = lane_card.get("cost_reduction_aura", {})
			if typeof(aura) == TYPE_DICTIONARY and not aura.is_empty():
				all_aura_sources.append(aura)
	for support_card in _get_player_state(match_state, player_id).get("support", []):
		if typeof(support_card) != TYPE_DICTIONARY:
			continue
		var aura = support_card.get("cost_reduction_aura", {})
		if typeof(aura) == TYPE_DICTIONARY and not aura.is_empty():
			all_aura_sources.append(aura)
	for aura in all_aura_sources:
		var required_type := str(aura.get("card_type", ""))
		if not required_type.is_empty() and card_type != required_type:
			continue
		if not _cost_reduction_condition_met(match_state, player_id, card, aura):
			continue
		total += int(aura.get("amount", 0))
	total -= PersistentCardRules._get_global_cost_increase(match_state, card_type)
	return total


static func _cost_reduction_condition_met(match_state: Dictionary, player_id: String, card: Dictionary, aura: Dictionary) -> bool:
	var condition := str(aura.get("condition", ""))
	if condition.is_empty():
		return true
	match condition:
		"creature_in_each_lane":
			for lane in match_state.get("lanes", []):
				var slots: Array = lane.get("player_slots", {}).get(player_id, [])
				if slots.is_empty():
					return false
			return true
		"required_singleton_deck":
			return bool(_get_player_state(match_state, player_id).get("_singleton_deck", false))
		"filter_deals_damage":
			# Only reduce cost of actions that deal damage
			if str(card.get("card_type", "")) != "action":
				return false
			var effect_ids = card.get("effect_ids", [])
			return typeof(effect_ids) == TYPE_ARRAY and (effect_ids.has("damage") or effect_ids.has("deal_damage"))
		"filter_min_power":
			var min_power := int(aura.get("min_power", 5))
			return EvergreenRules.get_power(card) >= min_power
		"filter_not_in_starting_deck":
			return bool(card.get("_not_in_starting_deck", false))
	return true


static func _get_heal_multiplier(match_state: Dictionary, player_id: String) -> int:
	var multiplier := 1
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var passives = card.get("passive_abilities", [])
			if typeof(passives) == TYPE_ARRAY:
				for p in passives:
					if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "double_health_gain":
						multiplier *= 2
	return multiplier


static func _get_max_magicka_cap(match_state: Dictionary) -> int:
	var cap := 0
	for lane in match_state.get("lanes", []):
		for player_slots in lane.get("player_slots", []):
			if typeof(player_slots) == TYPE_ARRAY:
				for card in player_slots:
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "max_magicka_cap"):
						for p in card.get("passive_abilities", []):
							if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "max_magicka_cap":
								var p_cap := int(p.get("cap", 7))
								if cap == 0 or p_cap < cap:
									cap = p_cap
			elif typeof(player_slots) == TYPE_DICTIONARY:
				for pid in player_slots.keys():
					for card in player_slots.get(pid, []):
						if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "max_magicka_cap"):
							for p in card.get("passive_abilities", []):
								if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "max_magicka_cap":
									var p_cap := int(p.get("cap", 7))
									if cap == 0 or p_cap < cap:
										cap = p_cap
	return cap


static func _get_min_card_cost(match_state: Dictionary) -> int:
	var min_cost := 0
	for lane in match_state.get("lanes", []):
		for player_slots in lane.get("player_slots", []):
			if typeof(player_slots) == TYPE_ARRAY:
				for card in player_slots:
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "min_card_cost"):
						for p in card.get("passive_abilities", []):
							if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "min_card_cost":
								min_cost = maxi(min_cost, int(p.get("min_cost", 3)))
			elif typeof(player_slots) == TYPE_DICTIONARY:
				for pid in player_slots.keys():
					for card in player_slots.get(pid, []):
						if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "min_card_cost"):
							for p in card.get("passive_abilities", []):
								if typeof(p) == TYPE_DICTIONARY and str(p.get("type", "")) == "min_card_cost":
									min_cost = maxi(min_cost, int(p.get("min_cost", 3)))
	return min_cost


static func _is_immune_to_effect(match_state: Dictionary, target_card: Dictionary, effect_type: String) -> bool:
	var self_immunities = target_card.get("self_immunity", [])
	if typeof(self_immunities) == TYPE_ARRAY and self_immunities.has(effect_type):
		return true
	var controller_id := str(target_card.get("controller_player_id", ""))
	var target_id := str(target_card.get("instance_id", ""))
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(controller_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if str(card.get("instance_id", "")) == target_id:
				continue
			var immunities = card.get("grants_immunity", [])
			if typeof(immunities) == TYPE_ARRAY and immunities.has(effect_type):
				return true
	return false


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
				var resolution := _build_trigger_resolution(match_state, synthetic_trigger, synthetic_event)
				generated_events.append_array(_apply_effects(match_state, synthetic_trigger, synthetic_event, resolution))
	active_set.erase(exclude_instance_id)
	if active_set.is_empty():
		match_state.erase("_active_forced_wax_wane")
	return generated_events


static func _update_assemble_rules_text(card: Dictionary, label: String, text_template: String) -> void:
	if label.is_empty() or text_template.is_empty():
		return
	# Calculate current stacked amount from the triggered ability
	var total_amount := 0
	for ability in card.get("triggered_abilities", []):
		if typeof(ability) == TYPE_DICTIONARY and str(ability.get("_assemble_label", "")) == label:
			for eff in ability.get("effects", []):
				if typeof(eff) == TYPE_DICTIONARY and eff.has("amount"):
					total_amount = int(eff.get("amount", 0))
					break
			break
	var new_line := text_template.replace("{amount}", str(total_amount))
	# Build assemble text tracking dict
	var assemble_texts: Dictionary = card.get("_assemble_texts", {})
	assemble_texts[label] = new_line
	card["_assemble_texts"] = assemble_texts
	# Rebuild rules_text: original text + assembled lines
	var base_text := str(card.get("_base_rules_text", card.get("rules_text", "")))
	if not card.has("_base_rules_text"):
		card["_base_rules_text"] = base_text
	var parts: Array = [base_text] if not base_text.is_empty() else []
	for key in assemble_texts.keys():
		parts.append(str(assemble_texts[key]))
	card["rules_text"] = "\n".join(parts)


static func _find_card_anywhere(match_state: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for player in match_state.get("players", []):
		for zone_name in PLAYER_ZONE_ORDER:
			var cards = player.get(zone_name, [])
			if typeof(cards) != TYPE_ARRAY:
				continue
			for card in cards:
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return card
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots = player_slots_by_id[player_id]
			if typeof(slots) != TYPE_ARRAY:
				continue
			for card in slots:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == instance_id:
					return card
				for attached_item in card.get("attached_items", []):
					if typeof(attached_item) == TYPE_DICTIONARY and str(attached_item.get("instance_id", "")) == instance_id:
						return attached_item
	return {}


static func _count_player_attributes(match_state: Dictionary, player_id: String) -> int:
	var seen: Dictionary = {}
	var player := _get_player_state(match_state, player_id)
	if player.is_empty():
		return 0
	for zone_name in ["deck", "hand", "discard", "support"]:
		for card in player.get(zone_name, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var attrs = card.get("attributes", [])
			if typeof(attrs) == TYPE_ARRAY:
				for attr in attrs:
					if str(attr) != "neutral":
						seen[str(attr)] = true
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var attrs = card.get("attributes", [])
			if typeof(attrs) == TYPE_ARRAY:
				for attr in attrs:
					if str(attr) != "neutral":
						seen[str(attr)] = true
	return seen.size()


static func _get_empower_amount(match_state: Dictionary, controller_player_id: String) -> int:
	var player := _get_player_state(match_state, controller_player_id)
	if player.is_empty():
		return 0
	ExtendedMechanicPacks.ensure_player_state(player)
	return int(player.get("empower_count_this_turn", 0)) + int(player.get("_permanent_empower_accumulated", 0))


static func _get_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _normalize_event(match_state: Dictionary, raw_event: Dictionary, context: Dictionary) -> Dictionary:
	match_state["next_event_sequence"] = int(match_state.get("next_event_sequence", 0)) + 1
	var event := raw_event.duplicate(true)
	event["event_id"] = "event_%04d" % int(match_state["next_event_sequence"])
	if not event.has("timing_window"):
		event["timing_window"] = str(context.get("timing_window", WINDOW_AFTER))
	if context.has("parent_event_id"):
		event["parent_event_id"] = str(context.get("parent_event_id", ""))
	if context.has("produced_by_resolution_id"):
		event["produced_by_resolution_id"] = str(context.get("produced_by_resolution_id", ""))
	return event


static func _append_event_log(match_state: Dictionary, event: Dictionary) -> void:
	var event_log: Array = match_state.get("event_log", [])
	event_log.append(event.duplicate(true))
	match_state["event_log"] = event_log


static func _append_replay_entry(match_state: Dictionary, entry: Dictionary) -> void:
	var replay_log: Array = match_state.get("replay_log", [])
	replay_log.append(entry.duplicate(true))
	match_state["replay_log"] = replay_log


static func process_end_of_turn_returns(match_state: Dictionary, turn_number: int) -> void:
	var pending: Array = match_state.get("pending_eot_returns", [])
	if pending.is_empty():
		return
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
			events.append(_build_summon_event(summon_result["card"], controller_id, lane_id, int(summon_result.get("slot_index", -1)), "end_of_turn_return"))
	match_state["pending_eot_returns"] = remaining
	if not events.is_empty():
		publish_events(match_state, events)
	# Destroy creatures marked with _destroy_at_end_of_turn
	var destroy_events: Array = []
	for lane in match_state.get("lanes", []):
		for player_slots in lane.get("player_slots", []):
			var cards_to_destroy: Array = []
			for card in player_slots.get("cards", []):
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
			var mb_card := _find_card_anywhere(match_state, str(instance_id))
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
			var dh_player := _get_player_state(match_state, str(player_id))
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


static func _event_subject_instance_id(event: Dictionary) -> String:
	return str(event.get("instance_id", event.get("source_instance_id", "")))


static func _event_target_instance_id(event: Dictionary) -> String:
	if event.has("target_instance_id"):
		return str(event.get("target_instance_id", ""))
	if str(event.get("target_type", "")) == "creature":
		return str(event.get("instance_id", ""))
	return ""
