extends SceneTree

## Card Definition Auditor
##
## Validates every card in the catalog against the engine's recognized schemas.
## Flags structural errors (unknown ops, unknown keys), semantic mismatches
## (rules text vs implementation), and missing required parameters.
##
## Run: Godot --log-file $TMPDIR/godot.log --headless --path <project> --script tests/card_definition_auditor.gd

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")

# ── Schema: recognized values ──────────────────────────────────────────

# Trigger descriptor keys consumed by _append_card_triggers (registration)
const REGISTRATION_KEYS := [
	"family", "effects", "enabled", "expires_on_turn", "_expires_on_turn",
	"target_mode", "secondary_target_mode", "consume", "id",
]

# Trigger descriptor condition keys consumed by _matches_conditions / matches_additional_conditions
const CONDITION_KEYS := [
	"required_zone", "required_zones", "match_role", "window", "once_per_instance",
	"once_per_turn", "required_keyword", "event_type",
	# _matches_conditions
	"target_type", "min_amount", "min_played_cost", "required_reason",
	"required_drawn_prophecy", "require_survived", "required_controller_min_health",
	"required_controller_turn", "required_creature_in_each_lane",
	"required_friendly_attribute_count", "required_drawn_card_type",
	"required_item_in_play", "required_min_max_magicka", "required_lane_full",
	"required_no_enemies_in_lane", "no_enemies_in_lane",
	"required_opponent_full_lane", "required_action_played_this_turn",
	"required_cards_played_this_turn", "required_played_max_cost",
	"required_damage_amount", "required_deaths_this_turn_gte",
	"required_gained_health_this_turn", "required_card_types_in_discard_or_play",
	"required_card_types_played_this_turn", "required_exalted_creature_in_play",
	"required_no_crowned_creature", "required_summon_unique",
	"required_host_min_power", "required_equipper_subtype", "required_equipper_name",
	"damage_kind", "exclude_retaliation", "exclude_battle", "require_retaliation",
	"required_played_card_type", "required_played_rules_tag", "exclude_self",
	"require_same_lane", "max_event_source_cost", "required_event_source_zone",
	"required_event_target_zone", "required_event_status_id",
	"required_target_keyword", "required_summon_subtype", "required_summon_keyword",
	"required_summon_min_power", "required_summon_min_health", "required_summon_min_cost",
	"required_slay_subtype", "require_positive_power_bonus", "require_negative_stat_bonus",
	"required_wax_wane_phase", "threshold", "required_source_subtype",
	# matches_additional_conditions
	"type", "min_cards_played_this_turn", "min_noncreature_plays_this_turn",
	"exalt_cost", "skip_if_exalted", "plot_bonus", "required_summon_index_this_turn",
	"invaded_this_turn", "require_attacker_survived",
	"required_top_deck_attribute", "required_event_source_subtype",
	"required_event_source_attribute", "excluded_event_source_rule_tag",
	"required_more_health", "required_less_health", "required_not_less_health",
	"required_subtype_on_board", "required_keyword_on_board",
	"required_wounded_enemy_in_lane", "required_enemy_in_lane",
	"required_top_deck_card_type", "required_opponent_more_cards",
	"required_card_type_in_hand", "required_attribute_in_hand",
	"creature_died_this_turn", "required_friendly_higher_power",
	"require_no_player_damage_this_turn", "if_marked_target_alive",
	"required_target", "required_max_magicka_gte", "required_max_magicka_lt",
	"required_friendly_creature_min_power", "min_destroyed_enemy_runes",
	"count", "required_event_lane_id", "excluded_event_lane_id",
	"required_equipped_item_definition", "required_no_equipped_item_definition",
	"required_detach_reason",
	# Treasure hunt system keys
	"hunt_types", "hunt_count", "hunt_keyword",
	# Other alternative-system keys
	"mandatory", "plot_effects", "source_type",
	"required_singleton_deck", "target_filter_max_power",
	"target_filter_wounded",
]

# Effect-level condition keys (used by effect_is_enabled gate)
const EFFECT_CONDITION_KEYS := [
	"required_source_status", "required_wax_wane_phase",
	"required_min_friendly_with_attribute", "required_friendly_attribute",
	"require_source_uses_exhausted", "unless_min_friendly_with_attribute",
	"unless_min_friendly_with_attribute_data", "require_event_target_alive",
]

# All recognized descriptor keys (union)
var _all_descriptor_keys: Dictionary = {}

const RECOGNIZED_FAMILIES := [
	"start_of_turn", "end_of_turn", "on_play", "activate", "summon",
	"on_damage", "on_death", "last_gasp", "slay", "pilfer", "veteran",
	"expertise", "plot", "rune_break", "on_friendly_death", "on_attack",
	"on_equip", "after_action_played", "on_ward_broken", "on_friendly_slay",
	"on_move", "on_friendly_summon", "on_enemy_summon", "on_steal",
	"on_card_drawn", "on_opponent_card_drawn", "wax", "wane",
	"on_max_magicka_gained", "on_discard_leave", "on_magicka_threshold",
	"on_opponent_turn", "item_detached", "on_item_equipped",
	"on_keyword_gained", "on_status_granted", "on_consumed",
	# Families handled by alternative systems (treasure hunt, exalt, etc.)
	"treasure_hunt", "exalt",
	# Families with FAMILY_SPECS entries and event publishing
	"on_enemy_rune_destroyed", "on_player_healed", "on_creature_healed",
	"on_friendly_pilfer_or_drain", "on_deal_damage_to_creature",
	"on_cover_gained", "on_enemy_stat_reduction", "on_friendly_card_played",
	"after_card_played", "on_friendly_equip",
	"on_support_count_reached", "on_invade", "on_friendly_power_gain",
	"on_friendly_wax", "on_friendly_wane", "on_friendly_dragon_damage",
	"on_friendly_support_played", "on_enemy_prophecy_drawn",
	"on_friendly_creature_death_count", "on_friendly_treasure_found",
	"on_friendly_sacrifice", "on_player_health_zero",
	"on_gain_max_magicka", "on_enemy_shackled", "on_opponent_damaged",
	"after_friendly_action_damages_enemy", "on_enemy_damaged",
	"on_max_magicka_gain_2", "on_rally", "on_rally_empty_hand",
	"on_targeted_by_action",
]

# Families with FAMILY_SPECS entries but whose events are never published by the engine.
# These are flagged as "unimplemented_family" (warning) instead of "unknown_family" (error).
const UNIMPLEMENTED_FAMILIES := [
]

const RECOGNIZED_OPS := [
	# Stats
	"conditional_double_stat", "double_health", "double_stats", "modify_cost",
	"modify_stats", "modify_stats_per_keyword", "reduce_cost_in_hand",
	"reduce_cost_top_of_deck", "set_all_friendly_power_to_max", "set_health",
	"set_power", "set_power_equal_to_health", "set_power_to_health", "set_stats",
	"spend_all_magicka_for_stats", "swap_stats",
	# Damage
	"battle_creature", "battle_random_enemy", "battle_strongest_enemy",
	"deal_damage", "deal_damage_and_heal", "deal_damage_from_creature",
	"deal_damage_to_lane", "delayed_destroy", "destroy_all_except_random",
	"destroy_all_except_strongest_in_lane", "destroy_creature",
	"destroy_creature_end_of_turn", "destroy_front_rune_and_steal_draw",
	"destroy_item", "player_battle_creature",
	# Summon
	"fill_lane_with", "summon_all_from_discard_by_name", "summon_copies_to_lane",
	"summon_copy", "summon_copy_of_self", "summon_copy_to_other_lane",
	"summon_each_unique_from_deck", "summon_from_deck_by_cost",
	"summon_from_deck_filtered", "summon_from_discard",
	"summon_from_discard_highest_cost", "summon_from_effect",
	"summon_from_hand_to_full_lane", "summon_from_opponent_discard",
	"summon_or_buff", "summon_random_by_cost", "summon_random_creature",
	"summon_random_daedra_by_gate_level", "summon_random_daedra_total_cost",
	"summon_random_from_collection", "summon_random_from_discard",
	"summon_top_creature_from_deck",
	# Draw
	"copy_card_to_hand", "copy_creature_from_deck_to_discard",
	"copy_drawn_card_to_hand", "copy_from_opponent_deck",
	"copy_rallied_creature_to_hand", "draw_all_creatures_from_discard",
	"draw_cards", "draw_random_creature_from_discard", "draw_cards_per_runes",
	"draw_copy_of_consumed", "draw_filtered", "draw_from_deck_filtered",
	"draw_from_discard_filtered", "draw_if_top_deck_subtype",
	"draw_if_wielder_has_items", "draw_or_treasure_hunt",
	"draw_specific_from_deck", "generate_card_to_deck", "generate_card_to_hand",
	"play_prophecy_from_hand", "play_random_from_deck", "play_top_of_deck",
	# Movement
	"banish", "banish_and_return_end_of_turn", "banish_by_name_from_opponent",
	"banish_discard_pile", "banish_from_opponent_deck", "discard",
	"discard_from_hand", "discard_hand", "discard_hand_end_of_turn",
	"discard_matching_from_opponent_deck", "discard_random",
	"discard_top_of_deck", "draw_from_opponent_discard",
	"may_move_between_lanes", "mill", "move_back_end_of_turn",
	"move_between_lanes", "return_equipped_items_to_hand", "return_stolen",
	"return_to_deck_and_draw_later", "return_to_hand",
	"schedule_return_from_discard", "shuffle_all_creatures_into_deck",
	"shuffle_copies_into_deck", "shuffle_copies_to_deck",
	"shuffle_discard_creatures_to_deck_with_buff",
	"shuffle_hand_to_deck_and_draw", "shuffle_into_deck",
	"shuffle_self_into_deck", "steal", "steal_from_discard",
	"unsummon", "unsummon_end_of_turn",
	# Keywords
	"copy_all_friendly_keywords", "copy_keywords_to_friendly",
	"copy_keywords_to_random_hand_card", "destroy_and_transfer_keywords",
	"gain_keywords_from_top_deck", "grant_extra_attack", "grant_immunity",
	"grant_keyword", "grant_keyword_to_all_copies", "grant_pilfer_draw",
	"grant_random_keyword", "grant_slay_ability", "grant_slay_draw",
	"grant_status", "grant_temporary_immunity",
	"modify_stats_if_shares_subtype_with_top_deck", "remove_keyword",
	"remove_status", "sacrifice_if_no_ward", "set_subtype", "shackle",
	"silence", "steal_keywords", "steal_status",
	# Triggers
	"copy_summon_ability", "enable_dual_wax_wane", "grant_double_activate",
	"grant_double_summon_this_turn", "grant_effect_this_turn",
	"grant_triggered_ability", "repeat_slay_reward",
	"trigger_all_friendly_summons", "trigger_exalt_all_friendly",
	"trigger_friendly_last_gasps", "trigger_summon_ability",
	"trigger_wane", "trigger_wax",
	# Healing / Magicka
	"add_support_uses", "cost_increase_next_turn", "double_max_magicka_gain",
	"gain_max_magicka", "gain_unspent_magicka_from_last_turn", "heal",
	"increase_opponent_action_cost", "prevent_rune_draw",
	"restore_creature_health", "restore_magicka", "restore_rune",
	"set_power_cap_in_lane",
	# Transform
	"change", "change_attribute", "change_lane_type", "change_lane_types",
	"conditional_change", "copy", "randomize_attribute", "transform",
	"transform_deck", "transform_hand", "transform_in_hand",
	"transform_in_hand_to_random",
	# Sacrifice / Consume
	"consume", "consume_all_creatures_in_discard_this_turn",
	"consume_and_copy_veteran", "consume_and_reduce_matching_subtype_cost",
	"consume_card", "consume_or_sacrifice", "optional_consume_for_keyword",
	"recall_and_resummon", "sacrifice", "sacrifice_and_absorb_stats",
	"sacrifice_and_equip_from_deck", "sacrifice_and_resummon",
	"sacrifice_and_summon_from_deck",
	# Items
	"buff_creatures_in_deck", "buff_creatures_in_discard", "buff_items_in_deck",
	"equip_copies_from_discard", "equip_copy_of_item", "equip_generated_item",
	"equip_item", "equip_items_from_discard", "modify_item_in_hand",
	"modify_random_item_in_hand", "reequip_all_items_to",
	"steal_item_from_opponent_discard", "steal_items",
	# Choice
	"build_custom_fabricant", "fabricate_choose_ability",
	"choose_card_in_hand_and_shuffle_copies", "choose_cost_lock",
	"choose_one", "choose_two",
	"conditional_drawn_card_bonus", "conditional_lane_bonus", "learn_action",
	"look_draw_discard", "look_give_draw", "optional_discard_and_summon",
	"play_learned_actions", "random_sub_effect", "secretly_choose_creature",
	"select_card_from_hand", "stitch_creatures_from_decks",
	# Misc
	"add_counter", "aim_at", "buff_random_hand_card",
	"grant_aura_by_chosen_subtype", "log", "mark_for_resummon",
	"mark_target", "redirect_damage_to_self", "reveal_opponent_hand_card",
	"reveal_opponent_top_deck", "swap_creatures", "top_deck_attribute_bonus",
	# Custom ops (extended_mechanic_packs)
	"assemble", "upgrade_shout", "invade", "buff_oblivion_gate_summon",
	"track_treasure_hunt", "damage", "empower_damage", "gain_magicka",
	"summon_random_from_catalog", "generate_random_to_hand",
	"discover_from_catalog", "equip_random_item_from_catalog",
	"reduce_random_hand_card_cost", "conditional_equip_bonus",
	"grant_player_ward", "reduce_next_card_cost", "escalating_damage",
	"summon_random_from_deck", "summon_random_by_target_cost",
	"look_at_top_deck_may_discard", "transform_random_by_cost",
	"transform_random_from_catalog", "draw_filtered_or_move_to_bottom",
	"vision_and_transform", "guess_opponent_card",
	"reveal_and_copy_from_opponent_deck", "opponent_gives_card_from_hand",
	"trade_hand_card_for_opponent_hand", "waves_of_the_fallen_choice",
	"merchant_offer", "transform_deck_to_dragons",
	"apply_cost_reduction_aura", "look_at_top_deck_may_discard_then_draw",
	"steal_top_deck_card", "generate_random_shouts_to_hand",
	"win_game_if_all_attributes", "check_win_condition",
	"summon_conditional_atronach", "summon_imposter", "lockpick_gamble",
	"boon_marked_for_death", "boon_soul_tear", "boon_first_lesson",
	"boon_battleground", "boon_shattered_fate", "boon_harbingers_call",
	"boon_holy_ground", "boon_runic_ward", "madness_beckons",
	"random_cost_trigger", "check_cost_trigger_match",
]

const RECOGNIZED_COST_REDUCTION_SOURCES := [
	"creature_summons_this_turn", "creatures_died_this_turn", "empower",
	"per_action_played_this_turn", "per_friendly_wounded",
	"per_friendly_creature_min_health_5", "per_pilfer_or_drain_this_turn",
	"per_creature_in_discard", "per_attribute_in_play", "if_neutral_in_play",
	"per_opponent_undead", "per_dragon_in_discard", "unique_creatures_in_discard",
]

# Ops that offer PLAYER CHOICE (not random selection)
const CHOICE_PROVIDING_OPS := [
	"choose_one", "choose_two", "look_draw_discard", "look_give_draw",
	"choose_card_in_hand_and_shuffle_copies",
	"choose_cost_lock", "select_card_from_hand", "optional_discard_and_summon",
	"build_custom_fabricant", "fabricate_choose_ability",
	"stitch_creatures_from_decks", "guess_opponent_card",
	"reveal_and_copy_from_opponent_deck", "waves_of_the_fallen_choice",
	"merchant_offer", "trade_hand_card_for_opponent_hand",
	"vision_and_transform", "discover_from_catalog",
	"look_at_top_deck_may_discard", "look_at_top_deck_may_discard_then_draw",
	"sacrifice_and_equip_from_deck",
]

# Ops that NEED specific parameters to not silently no-op
const REQUIRED_PARAMS := {
	"move_between_lanes": [["lane_id", "target_lane_id"]],
	"grant_keyword": [["keyword_id"]],
	"grant_status": [["status_id"]],
	"summon_from_effect": [["card_template", "source_target", "upgrade_chain", "copy_of"]],
	"generate_card_to_hand": [["card_template", "target"]],
	"generate_card_to_deck": [["card_template"]],
	"fill_lane_with": [["card_template"]],
	"equip_generated_item": [["card_template"]],
	"add_counter": [["counter", "counter_name"]],
}


func _initialize() -> void:
	_build_all_descriptor_keys()
	var catalog := CardCatalog.load_default()
	var error := str(catalog.get("error", ""))
	if not error.is_empty():
		push_error("Auditor: Failed to load catalog: %s" % error)
		quit(1)
		return
	var cards: Array = catalog.get("cards", [])
	var findings: Array = []
	var cards_with_issues := 0
	for card in cards:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var card_findings := _validate_card(card)
		if not card_findings.is_empty():
			cards_with_issues += 1
			findings.append_array(card_findings)
	# Output
	var error_count := 0
	var warning_count := 0
	for f in findings:
		if str(f.get("severity", "")) == "error":
			error_count += 1
		else:
			warning_count += 1
	var report := {
		"summary": {
			"total_cards": cards.size(),
			"cards_with_issues": cards_with_issues,
			"errors": error_count,
			"warnings": warning_count,
		},
		"findings": findings,
	}
	var json_string := JSON.stringify(report, "  ")
	var out_path := "res://development-artifacts/card_audit_report.json"
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	# Print summary
	print("=== CARD DEFINITION AUDIT ===")
	print("Total cards: %d" % cards.size())
	print("Cards with issues: %d" % cards_with_issues)
	print("Errors: %d | Warnings: %d" % [error_count, warning_count])
	if not findings.is_empty():
		print("")
		for f in findings:
			var sev := str(f.get("severity", ""))
			var card_name := str(f.get("card_name", ""))
			var check := str(f.get("check", ""))
			var detail := str(f.get("detail", ""))
			var prefix := "ERR " if sev == "error" else "WARN"
			print("[%s] %s | %s: %s" % [prefix, card_name, check, detail])
	print("")
	print("Report written to: %s" % out_path)
	if error_count > 0:
		print("AUDIT_FOUND_ERRORS")
	else:
		print("AUDIT_CLEAN")
	quit(0)


func _build_all_descriptor_keys() -> void:
	for key in REGISTRATION_KEYS:
		_all_descriptor_keys[key] = true
	for key in CONDITION_KEYS:
		_all_descriptor_keys[key] = true


func _validate_card(card: Dictionary) -> Array:
	var findings: Array = []
	var card_id := str(card.get("card_id", ""))
	var card_name := str(card.get("name", ""))
	var rules_text := str(card.get("rules_text", ""))
	var card_type := str(card.get("card_type", ""))
	var triggers: Array = card.get("triggered_abilities", [])
	if typeof(triggers) != TYPE_ARRAY:
		triggers = []
	# 1. Check trigger families & descriptor keys
	for ti in range(triggers.size()):
		var trigger: Dictionary = triggers[ti]
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		findings.append_array(_check_trigger(card_id, card_name, trigger, ti))
	# 2. Check self_cost_reduction
	findings.append_array(_check_cost_reduction(card_id, card_name, card))
	# 3. Semantic: rules text vs implementation
	findings.append_array(_check_semantic(card_id, card_name, card_type, rules_text, triggers, card))
	return findings


func _check_trigger(card_id: String, card_name: String, trigger: Dictionary, trigger_index: int) -> Array:
	var findings: Array = []
	var family := str(trigger.get("family", ""))
	# Check family
	if not family.is_empty() and family not in RECOGNIZED_FAMILIES:
		if family in UNIMPLEMENTED_FAMILIES:
			findings.append(_finding(card_id, card_name, "warning", "unimplemented_family",
				"Trigger #%d uses unimplemented family '%s' — effect will never fire" % [trigger_index, family],
				{"trigger_index": trigger_index, "family": family}))
		else:
			findings.append(_finding(card_id, card_name, "error", "unknown_family",
				"Trigger #%d has unrecognized family '%s'" % [trigger_index, family],
				{"trigger_index": trigger_index, "family": family}))
	# Check descriptor keys
	for key in trigger.keys():
		if key == "effects":
			continue
		if key not in _all_descriptor_keys:
			var suggestion := _suggest_key(key)
			var detail := "Trigger #%d has unrecognized key '%s'" % [trigger_index, key]
			if not suggestion.is_empty():
				detail += " — did you mean '%s'?" % suggestion
			findings.append(_finding(card_id, card_name, "warning", "unknown_descriptor_key",
				detail, {"trigger_index": trigger_index, "key": key, "suggestion": suggestion}))
	# Check effects
	var effects: Array = trigger.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		effects = []
	for ei in range(effects.size()):
		var effect: Dictionary = effects[ei] if typeof(effects[ei]) == TYPE_DICTIONARY else {}
		if effect.is_empty():
			continue
		findings.append_array(_check_effect(card_id, card_name, effect, trigger_index, ei, trigger))
	return findings


func _check_effect(card_id: String, card_name: String, effect: Dictionary, trigger_index: int, effect_index: int, trigger: Dictionary) -> Array:
	var findings: Array = []
	var op := str(effect.get("op", ""))
	# Check op name
	if not op.is_empty() and op not in RECOGNIZED_OPS:
		findings.append(_finding(card_id, card_name, "error", "unknown_op",
			"Trigger #%d effect #%d has unrecognized op '%s'" % [trigger_index, effect_index, op],
			{"trigger_index": trigger_index, "effect_index": effect_index, "op": op}))
	# Check required params
	if REQUIRED_PARAMS.has(op):
		for param_group in REQUIRED_PARAMS[op]:
			var found := false
			for param in param_group:
				if effect.has(param):
					found = true
					break
			if not found:
				findings.append(_finding(card_id, card_name, "warning", "missing_required_param",
					"Trigger #%d effect #%d op '%s' missing required param (one of: %s)" % [trigger_index, effect_index, op, ", ".join(param_group)],
					{"trigger_index": trigger_index, "effect_index": effect_index, "op": op, "missing": param_group}))
	# Check target references chosen_target without target_mode
	var target := str(effect.get("target", ""))
	if target.begins_with("chosen_target") or target == "primary_target" or target == "secondary_target":
		var trigger_target_mode := str(trigger.get("target_mode", ""))
		var trigger_secondary := str(trigger.get("secondary_target_mode", ""))
		if trigger_target_mode.is_empty() and trigger_secondary.is_empty():
			# Check if a prior effect in this trigger is a choice-providing op
			var has_prior_choice := false
			var effects_arr: Array = trigger.get("effects", [])
			for pi in range(effect_index):
				var prior = effects_arr[pi]
				if typeof(prior) == TYPE_DICTIONARY:
					if str(prior.get("op", "")) in CHOICE_PROVIDING_OPS:
						has_prior_choice = true
						break
			if not has_prior_choice:
				findings.append(_finding(card_id, card_name, "warning", "chosen_target_without_mode",
					"Trigger #%d effect #%d uses target '%s' but trigger has no target_mode" % [trigger_index, effect_index, target],
					{"trigger_index": trigger_index, "effect_index": effect_index, "target": target}))
	# Check effect-level condition keys
	for key in EFFECT_CONDITION_KEYS:
		pass  # These are valid — no need to flag
	return findings


func _check_cost_reduction(card_id: String, card_name: String, card: Dictionary) -> Array:
	var findings: Array = []
	var reduction = card.get("self_cost_reduction", {})
	if typeof(reduction) != TYPE_DICTIONARY or reduction.is_empty():
		return findings
	# Determine the source type
	var per_source := str(reduction.get("per", reduction.get("type", reduction.get("source", ""))))
	if per_source.is_empty():
		# Single-key format: {"per_friendly_wounded": 3}
		for key in reduction.keys():
			if key != "amount" and key != "amount_per" and key != "per" and key != "type" and key != "source":
				per_source = key
				break
	if not per_source.is_empty() and per_source not in RECOGNIZED_COST_REDUCTION_SOURCES:
		findings.append(_finding(card_id, card_name, "error", "unknown_cost_reduction_source",
			"self_cost_reduction uses unrecognized source '%s'" % per_source,
			{"source": per_source}))
	return findings


func _check_semantic(card_id: String, card_name: String, card_type: String, rules_text: String, triggers: Array, card: Dictionary) -> Array:
	var findings: Array = []
	var text_lower := rules_text.to_lower()
	var families: Array = []
	for t in triggers:
		if typeof(t) == TYPE_DICTIONARY:
			families.append(str(t.get("family", "")))
	var has_target_mode := false
	var has_choice_op := false
	# action_target_mode on the card itself counts as a choice mechanism
	if not str(card.get("action_target_mode", "")).is_empty():
		has_target_mode = true
	for t in triggers:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if not str(t.get("target_mode", "")).is_empty():
			has_target_mode = true
		for eff in t.get("effects", []):
			if typeof(eff) != TYPE_DICTIONARY:
				continue
			var eff_op := str(eff.get("op", ""))
			if eff_op in CHOICE_PROVIDING_OPS:
				has_choice_op = true
			# target_mode on effects (e.g. banish_by_name_from_opponent)
			if not str(eff.get("target_mode", "")).is_empty():
				has_target_mode = true
			# Ops that always present player choice via pending_deck_selections
			if eff_op == "summon_from_deck_filtered":
				has_choice_op = true
			# draw_from_discard_filtered with player_choice: true counts as choice
			if eff_op == "draw_from_discard_filtered" and bool(eff.get("player_choice", false)):
				has_choice_op = true
			# draw_from_deck_filtered with player_choice: true
			if eff_op == "draw_from_deck_filtered" and bool(eff.get("player_choice", false)):
				has_choice_op = true
			# copy_creature_from_deck_to_discard with player_choice: true
			if eff_op == "copy_creature_from_deck_to_discard" and bool(eff.get("player_choice", false)):
				has_choice_op = true
			# draw_specific_from_deck is player choice
			if eff_op == "draw_specific_from_deck":
				has_choice_op = true
			# force_play on generate_card_to_hand lets player choose lane
			if eff_op == "generate_card_to_hand" and bool(eff.get("force_play", false)):
				has_choice_op = true

	# ── Family consistency ──

	if _text_has(rules_text, "Summon:") and "summon" not in families:
		# Items use the equip system for their "Summon:" effects, not summon triggers
		# Supports use on_play family for their "Summon:" effects
		if card_type != "item" and card_type != "support":
			# Don't match "Summon:" if it's inside a quoted ability description
			# e.g. "Shuffle a card with \"Summon: Draw a card\" into your deck"
			if _text_starts_line(rules_text, "Summon:"):
				findings.append(_finding(card_id, card_name, "error", "missing_summon_trigger",
					"Rules text contains 'Summon:' but no summon-family trigger found",
					{"families": families}))

	if _text_has(rules_text, "Last Gasp:") and "last_gasp" not in families:
		# Items use item_detached family for Last Gasp (fires when creature dies or item silenced off)
		if card_type != "item" or "item_detached" not in families:
			findings.append(_finding(card_id, card_name, "error", "missing_last_gasp_trigger",
				"Rules text contains 'Last Gasp:' but no last_gasp-family trigger found",
				{"families": families}))

	if _text_has(rules_text, "Slay:") and "slay" not in families:
		# Check grants_trigger for slay, or grant ops that add slay dynamically
		if not _has_grants_trigger_family(card, "slay") and not _has_grant_op(triggers, ["grant_slay_draw", "grant_slay_ability"]):
			findings.append(_finding(card_id, card_name, "error", "missing_slay_trigger",
				"Rules text contains 'Slay:' but no slay-family trigger found",
				{"families": families}))

	if _text_has(rules_text, "Pilfer:") and "pilfer" not in families:
		# Check grants_trigger for pilfer, or grant ops that add pilfer dynamically
		if not _has_grants_trigger_family(card, "pilfer") and not _has_grant_op(triggers, ["grant_pilfer_draw"]):
			findings.append(_finding(card_id, card_name, "error", "missing_pilfer_trigger",
				"Rules text contains 'Pilfer:' but no pilfer-family trigger found",
				{"families": families}))

	if _text_has(rules_text, "Wax:") and "wax" not in families:
		# Actions may use effect-level required_wax_wane_phase instead of wax family
		if not _has_effect_wax_wane_phase(triggers, "wax"):
			findings.append(_finding(card_id, card_name, "error", "missing_wax_trigger",
				"Rules text contains 'Wax:' but no wax-family trigger found",
				{"families": families}))

	if _text_has(rules_text, "Wane:") and "wane" not in families:
		if not _has_effect_wax_wane_phase(triggers, "wane"):
			findings.append(_finding(card_id, card_name, "error", "missing_wane_trigger",
				"Rules text contains 'Wane:' but no wane-family trigger found",
				{"families": families}))

	if _text_has(rules_text, "Veteran:") and "veteran" not in families:
		findings.append(_finding(card_id, card_name, "error", "missing_veteran_trigger",
			"Rules text contains 'Veteran:' but no veteran-family trigger found",
			{"families": families}))

	if _text_has_phrase(rules_text, "At the start of your turn") and "start_of_turn" not in families:
		# Check for scheduling ops (delayed_destroy with trigger_at: start_of_turn)
		# and summoned tokens that have their own start_of_turn triggers
		if not _has_scheduling_op(triggers, "start_of_turn") and not _has_token_trigger(triggers, "start_of_turn"):
			findings.append(_finding(card_id, card_name, "error", "missing_start_of_turn_trigger",
				"Rules text says 'At the start of your turn' but no start_of_turn trigger found",
				{"families": families}))

	if _text_has_phrase(rules_text, "At the end of your turn") and "end_of_turn" not in families:
		# Could also be expertise/plot which fire at end of turn
		if "expertise" not in families and "plot" not in families:
			# Check for scheduling ops (unsummon_end_of_turn, destroy_creature_end_of_turn, etc.)
			if not _has_scheduling_op(triggers, "end_of_turn") and not _has_token_trigger(triggers, "end_of_turn"):
				findings.append(_finding(card_id, card_name, "error", "missing_end_of_turn_trigger",
					"Rules text says 'At the end of your turn' but no end_of_turn trigger found",
					{"families": families}))

	# ── Choose vs Random ──

	var choose_patterns := ["choose a ", "choose an ", "of your choice", "you may choose",
		"choose one", "choose two", "choose a card", "choose a creature",
		"choose an enemy", "choose a friendly"]
	var has_choose_text := false
	for pattern in choose_patterns:
		if text_lower.find(pattern) >= 0:
			has_choose_text = true
			break

	if has_choose_text and not has_target_mode and not has_choice_op:
		# Exclude cards where "choose" is part of a choose_one/choose_two label
		# by checking if the entire rules text is about a choose_one pattern
		if not _text_has(rules_text, "Choose one"):
			findings.append(_finding(card_id, card_name, "error", "choose_without_mechanism",
				"Rules text says 'choose' but no target_mode or choice-providing op found — player may not get to choose",
				{"rules_text": rules_text}))

	# ── Keyword consistency ──

	var keyword_map := {
		"Guard": "guard", "Ward": "ward", "Charge": "charge",
		"Drain": "drain", "Lethal": "lethal", "Breakthrough": "breakthrough",
		"Regenerate": "regenerate",
	}
	var card_keywords: Array = card.get("keywords", [])
	if typeof(card_keywords) != TYPE_ARRAY:
		card_keywords = []
	for kw_text in keyword_map:
		var kw_id: String = keyword_map[kw_text]
		# Check if keyword is mentioned as a standalone keyword in rules text
		# (not as part of "give X Guard" or "gains Guard")
		if _is_innate_keyword_in_text(rules_text, kw_text) and kw_id not in card_keywords:
			# Items grant keywords to the wielder, not to the item itself
			if card_type == "item":
				continue
			# Skip conditional keywords (e.g. "Lethal on your opponent's turn")
			if _is_conditional_keyword(rules_text, kw_text):
				continue
			findings.append(_finding(card_id, card_name, "warning", "keyword_not_in_array",
				"Rules text lists '%s' as innate keyword but it's not in keywords array" % kw_text,
				{"keyword": kw_id}))

	# ── Prophecy consistency ──

	var rules_tags: Array = card.get("rules_tags", [])
	if typeof(rules_tags) != TYPE_ARRAY:
		rules_tags = []
	if _text_starts_line(rules_text, "Prophecy") and "prophecy" not in rules_tags:
		findings.append(_finding(card_id, card_name, "warning", "prophecy_not_in_rules_tags",
			"Rules text starts with 'Prophecy' but 'prophecy' not in rules_tags",
			{}))

	# ── Support uses consistency ──

	var support_uses := int(card.get("support_uses", 0))
	if card_type == "support":
		var uses_regex := RegEx.new()
		uses_regex.compile("Uses:\\s*(\\d+)")
		var uses_match := uses_regex.search(rules_text)
		if uses_match:
			var expected_uses := int(uses_match.get_string(1))
			if expected_uses != support_uses:
				findings.append(_finding(card_id, card_name, "error", "support_uses_mismatch",
					"Rules text says 'Uses: %d' but support_uses is %d" % [expected_uses, support_uses],
					{"expected": expected_uses, "actual": support_uses}))
		elif _text_has(rules_text, "Ongoing") and support_uses != 0:
			findings.append(_finding(card_id, card_name, "warning", "ongoing_with_uses",
				"Rules text says 'Ongoing' but support_uses is %d (expected 0)" % support_uses,
				{"support_uses": support_uses}))

	# ── Activate trigger for supports with uses ──

	if card_type == "support" and support_uses > 0 and "activate" not in families:
		findings.append(_finding(card_id, card_name, "warning", "uses_without_activate",
			"Support has %d uses but no activate-family trigger" % support_uses,
			{"support_uses": support_uses}))

	return findings


# ── Helpers ──────────────────────────────────────────────────────────

func _suggest_key(unknown_key: String) -> String:
	# Check if adding/removing "required_" prefix gives a known key
	if unknown_key.begins_with("required_"):
		var stripped := unknown_key.substr(9)
		if stripped in _all_descriptor_keys:
			return stripped
	else:
		var prefixed := "required_" + unknown_key
		if prefixed in _all_descriptor_keys:
			return prefixed
	# Levenshtein distance for close matches
	var best_match := ""
	var best_dist := 4  # max edit distance threshold
	for key in _all_descriptor_keys:
		var dist := _levenshtein(unknown_key, key)
		if dist < best_dist:
			best_dist = dist
			best_match = key
	return best_match


func _levenshtein(s1: String, s2: String) -> int:
	var len1 := s1.length()
	var len2 := s2.length()
	if len1 == 0: return len2
	if len2 == 0: return len1
	var prev: Array = []
	for j in range(len2 + 1):
		prev.append(j)
	for i in range(1, len1 + 1):
		var curr: Array = [i]
		for j in range(1, len2 + 1):
			var cost := 0 if s1[i - 1] == s2[j - 1] else 1
			curr.append(mini(mini(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost))
		prev = curr
	return prev[len2]


func _has_grants_trigger_family(card: Dictionary, family: String) -> bool:
	var grants: Array = card.get("grants_trigger", [])
	if typeof(grants) != TYPE_ARRAY:
		return false
	for g in grants:
		if typeof(g) == TYPE_DICTIONARY and str(g.get("family", "")) == family:
			return true
	return false


func _has_grant_op(triggers: Array, op_names: Array) -> bool:
	for t in triggers:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		for eff in t.get("effects", []):
			if typeof(eff) == TYPE_DICTIONARY and str(eff.get("op", "")) in op_names:
				return true
	return false


func _has_scheduling_op(triggers: Array, timing: String) -> bool:
	for t in triggers:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		for eff in t.get("effects", []):
			if typeof(eff) != TYPE_DICTIONARY:
				continue
			var op := str(eff.get("op", ""))
			if timing == "start_of_turn":
				if op == "delayed_destroy" and str(eff.get("trigger_at", "")) == "start_of_turn":
					return true
			if timing == "end_of_turn":
				if op in ["unsummon_end_of_turn", "destroy_creature_end_of_turn",
					"move_back_end_of_turn", "banish_and_return_end_of_turn",
					"discard_hand_end_of_turn"]:
					return true
	return false


func _has_token_trigger(triggers: Array, family: String) -> bool:
	# Check if any summoned token (card_template) has the specified trigger family
	for t in triggers:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		for eff in t.get("effects", []):
			if typeof(eff) != TYPE_DICTIONARY:
				continue
			var template = eff.get("card_template", {})
			if typeof(template) != TYPE_DICTIONARY:
				continue
			var template_triggers: Array = template.get("triggered_abilities", [])
			if typeof(template_triggers) != TYPE_ARRAY:
				continue
			for tt in template_triggers:
				if typeof(tt) == TYPE_DICTIONARY and str(tt.get("family", "")) == family:
					return true
	return false


func _has_effect_wax_wane_phase(triggers: Array, phase: String) -> bool:
	for t in triggers:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		for eff in t.get("effects", []):
			if typeof(eff) == TYPE_DICTIONARY and str(eff.get("required_wax_wane_phase", "")) == phase:
				return true
	return false


func _is_conditional_keyword(rules_text: String, keyword: String) -> bool:
	# Detects keywords that are conditional (e.g. "Lethal on your opponent's turn")
	var lines := rules_text.split("\n")
	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.begins_with(keyword) and trimmed.length() > keyword.length():
			var rest := trimmed.substr(keyword.length()).strip_edges()
			# "on your", "while", "when", "if", "during" indicate conditional
			if rest.begins_with("on ") or rest.begins_with("while ") or rest.begins_with("when ") or rest.begins_with("if ") or rest.begins_with("during "):
				return true
	return false


func _text_has(text: String, substring: String) -> bool:
	return text.find(substring) >= 0


func _text_has_phrase(text: String, phrase: String) -> bool:
	return text.to_lower().find(phrase.to_lower()) >= 0


func _text_starts_line(text: String, prefix: String) -> bool:
	if text.begins_with(prefix):
		return true
	return text.find("\n" + prefix) >= 0


func _is_innate_keyword_in_text(rules_text: String, keyword: String) -> bool:
	# A keyword is "innate" if it appears at the start of a line as a standalone word.
	# Not "give X Guard" or "gains Guard" — those are granted by effects.
	var lines := rules_text.split("\n")
	for line in lines:
		var trimmed := line.strip_edges()
		# Check if line starts with the keyword (e.g. "Guard" or "Guard, Ward")
		if trimmed.begins_with(keyword):
			if trimmed.length() == keyword.length():
				return true
			var next_char: String = trimmed[keyword.length()]
			if next_char == "," or next_char == "\n" or next_char == " ":
				# "Guard, Ward" or "Guard " at start of line — innate
				# But not "Guardian" — check it's not mid-word
				return true
	return false


func _finding(card_id: String, card_name: String, severity: String, check: String, detail: String, context: Dictionary) -> Dictionary:
	return {
		"card_id": card_id,
		"card_name": card_name,
		"severity": severity,
		"check": check,
		"detail": detail,
		"context": context,
	}
