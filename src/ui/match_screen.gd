class_name MatchScreen
extends Control

signal return_to_main_menu_requested
signal forfeit_requested
signal match_state_changed(match_state: Dictionary)
signal puzzle_retry_requested
signal puzzle_return_to_select_requested

const HeuristicMatchPolicy = preload("res://src/ai/heuristic_match_policy.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchDebugScenarios = preload("res://src/ui/match_debug_scenarios.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const DeckArchetypeDetector = preload("res://src/ai/deck_archetype_detector.gd")
const AIPlayProfile = preload("res://src/ai/ai_play_profile.gd")
const CARD_DISPLAY_COMPONENT_SCRIPT := preload("res://src/ui/components/CardDisplayComponent.gd")
const CARD_DISPLAY_COMPONENT_SCENE := preload("res://scenes/ui/components/CardDisplayComponent.tscn")
const PLAYER_AVATAR_SCENE := preload("res://scenes/ui/components/PlayerAvatarComponent.tscn")
const PLAYER_MAGICKA_SCENE := preload("res://scenes/ui/components/PlayerMagickaComponent.tscn")
const ErrorReportWriterClass = preload("res://src/core/error_report_writer.gd")
const ErrorReportPopoverClass = preload("res://src/ui/components/error_report_popover.gd")
const BoonRules = preload("res://src/adventure/boon_rules.gd")
const ActiveBoonsOverlay = preload("res://src/ui/match/active_boons_overlay.gd")

const LANE_REGISTRY_PATH := "res://data/legends/registries/lane_registry.json"
const PLAYER_ORDER := ["player_2", "player_1"]
const DISPLAY_RUNE_THRESHOLDS := [25, 20, 15, 10, 5]
const ATTACK_FEEDBACK_DURATION_MS := 520
const DAMAGE_FEEDBACK_DURATION_MS := 1050
const REMOVAL_FEEDBACK_DURATION_MS := 1280
const DRAW_FEEDBACK_DURATION_MS := 1800
const RUNE_FEEDBACK_DURATION_MS := 2100
const TURN_BANNER_DURATION_MS := 1600
const CARD_HOVER_PREVIEW_DELAY_MS := 1000
const LOCAL_MATCH_AI_SCENARIO_ID := "local_match"
const LOCAL_MATCH_AI_ACTION_DELAY_MS := 320
const LOCAL_MATCH_AI_ATTACK_DELAY_MS := 900
const LANE_CARD_FLOAT_OFFSET := Vector2(-10, -18)
const LANE_CARD_FLOAT_SHADOW_OFFSET := Vector2(10, 14)
const LANE_CARD_FLOAT_ANIM_DURATION := 0.22
const LANE_CARD_BOB_AMPLITUDE := 4.0
const LANE_CARD_BOB_DURATION := 1.6
const HAND_CARD_BOB_AMPLITUDE := 3.0
const HAND_CARD_BOB_DURATION := 1.4
const SELECTION_MODE_NONE := "none"
const SELECTION_MODE_SUMMON := "summon"
const SELECTION_MODE_ITEM := "item"
const SELECTION_MODE_SUPPORT := "support"
const SELECTION_MODE_ATTACK := "attack"
const SELECTION_MODE_ACTION := "action"
const HELP_TEXT := {
	"guard": "Guard creatures must be attacked before other legal targets in the same lane.",
	"charge": "Charge creatures can attack immediately instead of waiting a turn cycle.",
	"cover": "Cover protects a creature from direct attacks until the granted turn window expires.",
	"ward": "Ward blocks the next source of damage that would hit this creature.",
	"drain": "Drain heals the controlling player for damage dealt to the opposing player.",
	"breakthrough": "Breakthrough deals excess combat damage to the defending player.",
	"lethal": "Any amount of combat damage from Lethal destroys the opposing creature.",
	"mobilize": "Mobilize can create and equip a Recruit if no target creature is chosen and a lane is provided.",
	"rally": "Rally buffs a creature in hand after this creature hits the enemy player.",
	"regenerate": "Regenerate clears damage at the start of its controller's next turn.",
	"shackled": "Shackled creatures skip attacking until the shackle clears on their controller's turn.",
	"silenced": "Silence strips keywords, statuses, triggers, and attached items from the card.",
	"wounded": "Wounded marks that the creature currently has damage on it.",
	"prophecy": "Prophecy cards can be played for free during the opponent's turn when drawn from a broken rune.",
	"ring_of_magicka": "The second player may spend one Ring charge per turn for +1 magicka that turn.",
}

var _match_state: Dictionary = {}
var _selected_instance_id := ""
var _selected_pile_player_id := ""
var _selected_pile_zone := ""
var _status_message := ""
var _scenario_id: String = MatchDebugScenarios.DEFAULT_SCENARIO_ID
var _keyword_registry := {}
var _lane_registry := {}
var _keyword_display_names := {}
var _status_display_names := {}

var _end_turn_button: Button
var _turn_banner_panel: PanelContainer
var _turn_banner_label: Label
var _turn_banner_detail_label: Label
var _match_end_overlay: PanelContainer
var _match_end_title_label: Label
var _match_end_detail_label: Label
var _player_sections := {}
var _lane_panels := {}
var _lane_row_panels := {}
var _lane_row_containers := {}
var _lane_header_buttons := {}
var _lane_icon_textures := {}
var _lane_tooltip_panel: PanelContainer
var _lane_tooltip_name_label: Label
var _lane_tooltip_desc_label: Label
var _card_buttons := {}
var _lane_slot_buttons := {}
var _invalid_feedback := {}
var _detached_card_state := {}
var _insertion_preview := {}
var _targeting_arrow_state := {}
var _targeting_arrow: Line2D
var _pending_summon_target := {}
var _pending_secondary_target_state := {}
var _pending_end_turn := false
var _pending_end_turn_player_id := ""
var _pending_betray := {}
var _betray_skip_button: Button = null
var _betray_prompt_label: Label = null
var _pending_sacrifice_summon := {}
var _sacrifice_hover_target_id: String = ""
var _sacrifice_hover_label: PanelContainer = null
var _pending_exalt := {}
var _exalt_button_container: Control = null
var _exalt_card_preview: Control = null
var _prophecy_overlay_state := {}
var _spell_reveal_state := {}
var _deck_reveal_state := {}
var _prophecy_card_overlay: Control
var _mulligan_overlay_state := {}
var _mulligan_marked_ids: Array = []
var _mulligan_card_by_id: Dictionary = {}
var _mulligan_instance_id_order: Array = []
var _discard_viewer_state := {}
var _discard_choice_overlay_state := {}
var _consume_selection_overlay_state := {}
var _hand_selection_state := {}
var _top_deck_choice_state := {}
var _top_deck_choice_panel: Control = null
var _attack_feedbacks: Array = []
var _damage_feedbacks: Array = []
var _removal_feedbacks: Array = []
var _draw_feedbacks: Array = []
var _rune_feedbacks: Array = []
var _feedback_sequence := 0
var _local_hand_overlay: Control
var _opponent_hand_overlay: Control
var _player_avatar_overlay: Control
var _opponent_avatar_overlay: Control
var _card_hover_preview_layer: Control
var _lane_hover_preview_pending := {}
var _lane_hover_preview_instance_id := ""
var _lane_hover_preview_button_ref: WeakRef
var _support_hover_preview_pending := {}
var _support_hover_preview_instance_id := ""
var _support_hover_preview_button_ref: WeakRef
var _last_turn_owner_id := ""
var _turn_banner_until_ms := 0
var _queued_ai_step_at_ms := -1
var _paused_ai_step_delay_ms := -1
var _ai_waiting_for_turn_banner := false
var _local_match_ai_action_count := 0
var _pending_layout_scale_frames := 0
var _floating_card_ids: Dictionary = {}
var _hovered_hand_instance_id := ""
var _hovered_pile_player_id := ""
var _hovered_pile_zone := ""
var _overdraw_queue: Array = []
var _match_end_button: Button
var _match_end_box: VBoxContainer
var _puzzle_end_retry_btn: Button
var _puzzle_end_return_btn: Button
var _arena_mode := false
var _puzzle_mode := false
var _puzzle_type := ""
var _puzzle_config: Dictionary = {}
var _puzzle_id := ""
var _adventure_boons: Array = []
var _adventure_augments: Dictionary = {}  # card_id -> Array of augment dicts
var _pause_overlay: PanelContainer
var _attack_arrow_state := {}
var _support_arrow_state := {}

# Error report hover tracking
var _error_report_hovered_type := ""
var _error_report_hovered_context := ""
var _error_report_popover: Control = null

# Match history state
const MATCH_HISTORY_MAX_ENTRIES := 5
const MATCH_HISTORY_ICON_SIZE := Vector2(64, 64)
const MATCH_HISTORY_ICON_BORDER_WIDTH := 3
const MATCH_HISTORY_PLAYER_BORDER_COLOR := Color(0.3, 0.5, 0.9)
const MATCH_HISTORY_OPPONENT_BORDER_COLOR := Color(0.85, 0.3, 0.25)
var _match_history_entries: Array = []
var _match_history_last_event_count: int = 0
var _match_history_card_snapshots: Dictionary = {}
var _match_history_container: HBoxContainer
var _match_history_popover_state := {}

var _ai_enabled := false
# AI play profile options built from deck archetype detection and quality scaling.
# Persisted in match_state["ai_options"] for resume support.
var _ai_options: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	set_process(true)
	_load_registries()
	_build_ui()
	resized.connect(_apply_match_layout_scale)
	load_scenario(_scenario_id)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _mulligan_overlay_state.is_empty():
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_on_mulligan_confirm_pressed()
		get_viewport().set_input_as_handled()
		return
	var key_index := -1
	match key_event.keycode:
		KEY_1: key_index = 0
		KEY_2: key_index = 1
		KEY_3: key_index = 2
	if key_index >= 0 and key_index < _mulligan_instance_id_order.size():
		_on_mulligan_card_toggled(_mulligan_instance_id_order[key_index])
		get_viewport().set_input_as_handled()


func start_match_with_decks(deck_one_ids: Array, deck_two_ids: Array, seed: int = -1, first_player_index: int = -1, ai_options: Dictionary = {}) -> bool:
	_cancel_detached_card_silent()
	_dismiss_mulligan_overlay()
	_dismiss_prophecy_overlay()
	_dismiss_discard_viewer()
	_dismiss_discard_choice_overlay()
	_dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_dismiss_player_choice_overlay()
	_exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_dismiss_spell_reveal()
	_reset_invalid_feedback()
	_clear_feedback_state()
	_reset_local_match_ai_queue()
	_reset_match_history()
	_local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	if card_by_id.is_empty():
		_status_message = "Failed to load card catalog."
		_refresh_ui()
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var match_seed: int = seed if seed >= 0 else rng.randi()
	var match_first_player: int = first_player_index if first_player_index >= 0 else rng.randi_range(0, 1)
	var match_state := MatchBootstrap.create_standard_match(
		[deck_one_ids, deck_two_ids],
		{"seed": match_seed, "first_player_index": match_first_player}
	)
	if match_state.is_empty():
		_status_message = "Failed to create match."
		_refresh_ui()
		return false
	if not _adventure_boons.is_empty():
		BoonRules.apply_boons_to_match_state(match_state, PLAYER_ORDER[1], _adventure_boons)
	_hydrate_match_cards(match_state, card_by_id)
	# Apply AI mulligan immediately (invisible to player)
	var ai_id := PLAYER_ORDER[0]
	var ai_discard_ids := HeuristicMatchPolicy.choose_mulligan(match_state, ai_id)
	MatchBootstrap.apply_mulligan(match_state, ai_id, ai_discard_ids)
	_hydrate_match_cards(match_state, card_by_id)
	# Apply augments after the final hydration so they aren't overwritten
	if not _adventure_augments.is_empty():
		_apply_adventure_augments(match_state, PLAYER_ORDER[1])
	GameLogger.start_match(match_state)
	# Store state but don't start the turn yet - wait for player mulligan
	_match_state = match_state
	# Build AI play profile from deck archetype and quality. The profile shapes
	# how aggressively/defensively the AI plays and how precise its decisions are.
	_ai_options = _build_ai_play_profile(ai_options, card_by_id)
	_match_state["ai_options"] = _ai_options
	_mulligan_card_by_id = card_by_id
	_ai_enabled = false
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	_status_message = "Choose cards to replace."
	_refresh_ui()
	_show_mulligan_overlay()
	return true


func start_arena_boss_match(deck_one_ids: Array, deck_two_ids: Array, boss_config: Dictionary, seed: int = -1, first_player_index: int = -1, ai_options: Dictionary = {}) -> bool:
	_cancel_detached_card_silent()
	_dismiss_mulligan_overlay()
	_dismiss_prophecy_overlay()
	_dismiss_discard_viewer()
	_dismiss_discard_choice_overlay()
	_dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_dismiss_player_choice_overlay()
	_exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_dismiss_spell_reveal()
	_reset_invalid_feedback()
	_clear_feedback_state()
	_reset_local_match_ai_queue()
	_reset_match_history()
	_local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	if card_by_id.is_empty():
		_status_message = "Failed to load card catalog."
		_refresh_ui()
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var match_seed: int = seed if seed >= 0 else rng.randi()
	var match_first_player: int = first_player_index if first_player_index >= 0 else rng.randi_range(0, 1)
	var options := {"seed": match_seed, "first_player_index": match_first_player}
	var match_state := MatchBootstrap.create_standard_match(
		[deck_one_ids, deck_two_ids], options
	)
	if match_state.is_empty():
		_status_message = "Failed to create match."
		_refresh_ui()
		return false
	# Apply health overrides first, then boons — fortified_spirit reads player health
	# to calculate rune thresholds, so health must be final before boons run.
	var boss_id := PLAYER_ORDER[0]
	var local_id := PLAYER_ORDER[1]
	var boss_health := int(boss_config.get("boss_health", 0))
	var player_health := int(boss_config.get("player_health", 0))
	if boss_health > 0 or player_health > 0:
		for player in match_state.get("players", []):
			var pid: String = str(player.get("player_id", ""))
			if pid == boss_id and boss_health > 0:
				player["health"] = boss_health
				player["rune_thresholds"] = _strip_rune_thresholds_above(player.get("rune_thresholds", []), boss_health)
			elif pid == local_id and player_health > 0:
				player["health"] = player_health
				player["rune_thresholds"] = _strip_rune_thresholds_above(player.get("rune_thresholds", []), player_health)
	if not _adventure_boons.is_empty():
		BoonRules.apply_boons_to_match_state(match_state, PLAYER_ORDER[1], _adventure_boons)
	_hydrate_match_cards(match_state, card_by_id)
	# Inject relic support card into boss's support zone
	var relic: Variant = boss_config.get("relic", null)
	if relic != null:
		var BossRelicSystem := preload("res://src/arena/boss_relic_system.gd")
		var relic_template := BossRelicSystem.get_relic_card_template(relic)
		var relic_card := MatchMutations.build_generated_card(match_state, boss_id, relic_template)
		relic_card["zone"] = "support"
		PersistentCardRules.refresh_support_for_controller_turn(relic_card)
		for player in match_state.get("players", []):
			if str(player.get("player_id", "")) == boss_id:
				player["support"].append(relic_card)
				break
	# Inject starting creatures (Ebony City Gates, Malachite Guards)
	var starting_creatures: Array = boss_config.get("starting_creatures", [])
	var lanes: Array = match_state.get("lanes", [])
	for creature_template in starting_creatures:
		var lane_index := int(creature_template.get("lane_index", 0))
		if lane_index < 0 or lane_index >= lanes.size():
			continue
		var template: Dictionary = creature_template.duplicate(true)
		template.erase("lane_index")
		var creature := MatchMutations.build_generated_card(match_state, boss_id, template)
		var lane_id := str(lanes[lane_index].get("lane_id", ""))
		MatchMutations.summon_card_to_lane(match_state, boss_id, creature, lane_id, {"apply_shadow_cover": false})
	# Apply AI mulligan immediately (invisible to player)
	var ai_discard_ids := HeuristicMatchPolicy.choose_mulligan(match_state, boss_id)
	MatchBootstrap.apply_mulligan(match_state, boss_id, ai_discard_ids)
	_hydrate_match_cards(match_state, card_by_id)
	# Apply augments after the final hydration so they aren't overwritten
	if not _adventure_augments.is_empty():
		_apply_adventure_augments(match_state, PLAYER_ORDER[1])
	GameLogger.start_match(match_state)
	_match_state = match_state
	_ai_options = _build_ai_play_profile(ai_options, card_by_id)
	_match_state["ai_options"] = _ai_options
	_mulligan_card_by_id = card_by_id
	_ai_enabled = false
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	_status_message = "Choose cards to replace."
	_refresh_ui()
	_show_mulligan_overlay()
	return true


## Build the AI play profile from the provided ai_options (quality + AI deck IDs).
## Detects the deck archetype and produces interpolated weight options that shape
## how the AI prioritises face damage, board control, and card advantage.
static func _build_ai_play_profile(ai_options: Dictionary, card_by_id: Dictionary) -> Dictionary:
	if ai_options.is_empty():
		return {}
	var quality := float(ai_options.get("quality", 1.0))
	var ai_deck_ids: Array = ai_options.get("ai_deck_ids", [])
	if ai_deck_ids.is_empty():
		return AIPlayProfile.build_options(0.0, quality)
	var archetype := DeckArchetypeDetector.detect(ai_deck_ids, card_by_id)
	var aggro_score := float(archetype.get("aggro_score", 0.0))
	return AIPlayProfile.build_options(aggro_score, quality)


func _apply_adventure_augments(match_state: Dictionary, player_id: String) -> void:
	if _adventure_augments.is_empty():
		return
	var AugmentRulesScript := preload("res://src/adventure/augment_rules.gd")
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) != player_id:
			continue
		for zone_key in ["deck", "hand"]:
			var zone: Array = player.get(zone_key, [])
			for card in zone:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var def_id := str(card.get("definition_id", ""))
				if _adventure_augments.has(def_id):
					AugmentRulesScript.apply_augments_to_card(card, _adventure_augments[def_id])


static func _strip_rune_thresholds_above(thresholds: Array, health: int) -> Array:
	var kept: Array = []
	for t in thresholds:
		if int(t) < health:
			kept.append(t)
	return kept


static func _hydrate_match_cards(match_state: Dictionary, card_by_id: Dictionary) -> void:
	for player in match_state.get("players", []):
		for zone_key in ["deck", "hand"]:
			var zone: Array = player.get(zone_key, [])
			for card in zone:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				_hydrate_card(card, card_by_id)


static func _hydrate_card(card: Dictionary, card_by_id: Dictionary) -> void:
	var definition_id := str(card.get("definition_id", ""))
	var definition: Dictionary = card_by_id.get(definition_id, {})
	if definition.is_empty():
		return
	card["name"] = str(definition.get("name", ""))
	card["card_type"] = str(definition.get("card_type", "creature"))
	card["cost"] = int(definition.get("cost", 0))
	card["power"] = int(definition.get("base_power", 0))
	card["health"] = int(definition.get("base_health", 0))
	card["rarity"] = str(definition.get("rarity", "common"))
	card["is_unique"] = bool(definition.get("is_unique", false))
	card["rules_text"] = str(definition.get("rules_text", ""))
	var existing_art_path := str(card.get("art_path", ""))
	if existing_art_path.is_empty() or not ResourceLoader.exists(existing_art_path):
		card["art_path"] = str(definition.get("art_path", ""))
	card["subtypes"] = definition.get("subtypes", []).duplicate(true)
	card["attributes"] = definition.get("attributes", []).duplicate(true)
	card["effect_ids"] = definition.get("effect_ids", []).duplicate(true)
	card["support_uses"] = int(definition.get("support_uses", 0))
	var def_keywords: Array = definition.get("keywords", [])
	if not def_keywords.is_empty():
		card["keywords"] = def_keywords.duplicate(true)
	var def_rules_tags: Array = definition.get("rules_tags", [])
	if not def_rules_tags.is_empty():
		card["rules_tags"] = def_rules_tags.duplicate(true)
	if str(definition.get("card_type", "")) == "item":
		card["equip_power_bonus"] = int(definition.get("equip_power_bonus", 0))
		card["equip_health_bonus"] = int(definition.get("equip_health_bonus", 0))
		card["equip_keywords"] = definition.get("equip_keywords", []).duplicate(true)
	if definition.has("shout_chain_id"):
		card["shout_chain_id"] = str(definition["shout_chain_id"])
	if definition.has("shout_level"):
		card["shout_level"] = int(definition["shout_level"])
	if definition.has("shout_levels"):
		card["shout_levels"] = definition["shout_levels"].duplicate(true)
	var action_target_mode := str(definition.get("action_target_mode", ""))
	if not action_target_mode.is_empty():
		card["action_target_mode"] = action_target_mode
	var triggered: Array = definition.get("triggered_abilities", [])
	if not triggered.is_empty():
		card["triggered_abilities"] = triggered.duplicate(true)
	if definition.has("aura"):
		card["aura"] = definition["aura"].duplicate(true)
	if definition.has("cost_reduction_aura"):
		card["cost_reduction_aura"] = definition["cost_reduction_aura"].duplicate(true)
	if definition.has("cost_increase_aura"):
		card["cost_increase_aura"] = definition["cost_increase_aura"].duplicate(true)
	if definition.has("grants_immunity"):
		card["grants_immunity"] = definition["grants_immunity"].duplicate(true)
	if definition.has("grants_trigger"):
		card["grants_trigger"] = definition["grants_trigger"].duplicate(true)
	if definition.has("magicka_aura"):
		card["magicka_aura"] = int(definition["magicka_aura"])
	if definition.has("self_immunity"):
		card["self_immunity"] = definition["self_immunity"].duplicate(true)
	if definition.has("first_turn_hand_cost"):
		card["first_turn_hand_cost"] = int(definition["first_turn_hand_cost"])
	if definition.has("self_cost_reduction"):
		card["self_cost_reduction"] = definition["self_cost_reduction"].duplicate(true)
	if definition.has("passive_abilities"):
		card["passive_abilities"] = definition["passive_abilities"].duplicate(true)
	if definition.has("attack_condition"):
		card["attack_condition"] = definition["attack_condition"].duplicate(true)
	if definition.has("cant_attack_player"):
		card["cant_attack_player"] = bool(definition["cant_attack_player"])
	if definition.has("_empower_target_bonus"):
		card["_empower_target_bonus"] = int(definition["_empower_target_bonus"])
	var innate_statuses: Array = definition.get("innate_statuses", [])
	if not innate_statuses.is_empty():
		card["innate_statuses"] = innate_statuses.duplicate(true)
		var markers: Array = card.get("status_markers", [])
		for status_id in innate_statuses:
			if not markers.has(status_id):
				markers.append(status_id)
		card["status_markers"] = markers


static func _hydrate_all_zones(match_state: Dictionary, card_by_id: Dictionary) -> void:
	for player in match_state.get("players", []):
		for zone_key in ["deck", "hand", "support", "discard", "banished"]:
			var zone: Array = player.get(zone_key, [])
			for card in zone:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				_hydrate_card(card, card_by_id)
	for lane in match_state.get("lanes", []):
		var player_slots: Dictionary = lane.get("player_slots", {})
		for pid in player_slots.keys():
			for card in player_slots[pid]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				_hydrate_card(card, card_by_id)
				for attached_item in card.get("attached_items", []):
					if typeof(attached_item) == TYPE_DICTIONARY:
						_hydrate_card(attached_item, card_by_id)


func start_test_match(test_state: Dictionary) -> void:
	_cancel_detached_card_silent()
	_dismiss_mulligan_overlay()
	_dismiss_prophecy_overlay()
	_dismiss_discard_viewer()
	_dismiss_discard_choice_overlay()
	_dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_dismiss_player_choice_overlay()
	_exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_dismiss_spell_reveal()
	_reset_invalid_feedback()
	_clear_feedback_state()
	_reset_local_match_ai_queue()
	_reset_match_history()
	_local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	_hydrate_all_zones(test_state, card_by_id)
	GameLogger.start_match(test_state)
	_match_state = test_state
	_ai_options = {}
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	_mulligan_card_by_id = {}
	_ai_enabled = true
	# Fire initial turn-start triggers for the active player (wax/wane, start_of_turn, etc.)
	var active_id := str(test_state.get("active_player_id", ""))
	for p in test_state.get("players", []):
		if typeof(p) == TYPE_DICTIONARY:
			ExtendedMechanicPacks.ensure_player_state(p)
	MatchTiming.publish_events(test_state, [{
		"event_type": MatchTiming.EVENT_TURN_STARTED,
		"player_id": active_id,
		"source_controller_player_id": active_id,
		"turn_number": int(test_state.get("turn_number", 1)),
	}])
	_status_message = "Test match started."
	_refresh_ui()


func start_puzzle_match(puzzle_state: Dictionary, puzzle_config: Dictionary = {},
		puzzle_id: String = "", ai_options: Dictionary = {}) -> void:
	_cancel_detached_card_silent()
	_dismiss_mulligan_overlay()
	_dismiss_prophecy_overlay()
	_dismiss_discard_viewer()
	_dismiss_discard_choice_overlay()
	_dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_dismiss_player_choice_overlay()
	_exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_dismiss_spell_reveal()
	_reset_invalid_feedback()
	_clear_feedback_state()
	_reset_local_match_ai_queue()
	_reset_match_history()
	_local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	_hydrate_all_zones(puzzle_state, card_by_id)
	GameLogger.start_match(puzzle_state)
	_match_state = puzzle_state
	_ai_options = ai_options
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	_mulligan_card_by_id = {}
	_ai_enabled = true
	_puzzle_mode = true
	_puzzle_type = str(puzzle_state.get("puzzle_type", "kill"))
	_puzzle_config = puzzle_config
	_puzzle_id = puzzle_id
	for p in puzzle_state.get("players", []):
		if typeof(p) == TYPE_DICTIONARY:
			ExtendedMechanicPacks.ensure_player_state(p)
	# Emit card_drawn events for each card in each player's starting hand so
	# draw-triggered abilities (e.g. Treasure Hunt) fire on the initial hand.
	for p in puzzle_state.get("players", []):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pid := str(p.get("player_id", ""))
		for hand_card in p.get("hand", []):
			if typeof(hand_card) != TYPE_DICTIONARY:
				continue
			MatchTiming.publish_events(puzzle_state, [{
				"event_type": MatchTiming.EVENT_CARD_DRAWN,
				"player_id": pid,
				"source_instance_id": "",
				"source_controller_player_id": pid,
				"drawn_instance_id": str(hand_card.get("instance_id", "")),
				"source_zone": "deck",
				"target_zone": "hand",
				"reason": "puzzle_starting_hand",
				"timing_window": "after",
			}])
	MatchTiming.publish_events(puzzle_state, [{
		"event_type": MatchTiming.EVENT_TURN_STARTED,
		"player_id": str(puzzle_state.get("active_player_id", "")),
		"source_controller_player_id": str(puzzle_state.get("active_player_id", "")),
		"turn_number": int(puzzle_state.get("turn_number", 1)),
	}])
	_status_message = ""
	_rebuild_pause_overlay()
	_refresh_ui()
	_show_puzzle_objective_popup()


func _rebuild_pause_overlay() -> void:
	if _pause_overlay != null:
		var parent := _pause_overlay.get_parent()
		_pause_overlay.queue_free()
		_pause_overlay = _build_pause_overlay()
		parent.add_child(_pause_overlay)


func _show_puzzle_objective_popup() -> void:
	var objective_text := "Survive for one turn to win." if _puzzle_type == "survive" else "Win this turn."

	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 80
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.11, 0.16, 0.98)
	card_style.border_color = Color(0.5, 0.5, 0.55, 0.96)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var msg := Label.new()
	msg.text = objective_text
	msg.add_theme_font_size_override("font_size", 26)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "Okay"
	ok_btn.custom_minimum_size = Vector2(140, 44)
	ok_btn.add_theme_font_size_override("font_size", 20)
	ok_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(ok_btn)


func resume_from_state(saved_state: Dictionary) -> void:
	_cancel_detached_card_silent()
	_dismiss_mulligan_overlay()
	_dismiss_prophecy_overlay()
	_dismiss_discard_viewer()
	_dismiss_discard_choice_overlay()
	_dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_dismiss_player_choice_overlay()
	_exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_dismiss_spell_reveal()
	_reset_invalid_feedback()
	_clear_feedback_state()
	_reset_local_match_ai_queue()
	_local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	_hydrate_all_zones(saved_state, card_by_id)
	GameLogger.start_match(saved_state)
	_match_state = saved_state
	# Restore AI play profile from saved state (persisted during match start).
	_ai_options = _match_state.get("ai_options", {})
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	var phase := str(_match_state.get("phase", ""))
	var winner := str(_match_state.get("winner_player_id", ""))
	if not winner.is_empty():
		# Match already ended — trigger result flow immediately
		_ai_enabled = false
		_status_message = "Match complete."
		_refresh_ui()
		return_to_main_menu_requested.emit()
		return
	if phase == "mulligan":
		_mulligan_card_by_id = card_by_id
		_ai_enabled = false
		_status_message = "Choose cards to replace."
		_refresh_ui()
		_show_mulligan_overlay()
	else:
		_mulligan_card_by_id = {}
		_ai_enabled = true
		_status_message = "Match resumed."
		_refresh_ui()


func _process(_delta: float) -> void:
	if _turn_banner_panel == null:
		return
	var should_show := _turn_banner_until_ms > Time.get_ticks_msec()
	if _turn_banner_panel.visible != should_show:
		_turn_banner_panel.visible = should_show
	_process_lane_card_hover_preview()
	_process_support_card_hover_preview()
	_process_local_match_ai_turn()
	_check_pending_forced_play()
	if _pending_layout_scale_frames > 0:
		_pending_layout_scale_frames -= 1
		_apply_match_layout_scale()


func get_available_scenarios() -> Array:
	return MatchDebugScenarios.list_scenarios()


func get_match_state() -> Dictionary:
	return _match_state


func get_status_message() -> String:
	return _status_message


func get_selected_instance_id() -> String:
	return _selected_instance_id


func get_pending_prophecy_ids() -> Array:
	var ids: Array = []
	for window in MatchTiming.get_pending_prophecies(_match_state):
		ids.append(str(window.get("instance_id", "")))
	return ids


func get_interaction_state() -> Dictionary:
	return {
		"selection_mode": _selected_action_mode(_selected_card()),
		"local_turn": _is_local_player_turn(),
		"local_controls_locked": _should_dim_local_interaction_surfaces(),
		"turn_banner_visible": _is_turn_banner_active(),
		"valid_lane_slot_keys": _valid_lane_slot_keys(),
		"valid_lane_ids": _valid_lane_ids(),
		"valid_target_instance_ids": _valid_card_target_ids(),
		"valid_target_player_ids": _valid_player_target_ids(),
		"invalid_lane_slot_keys": _copy_array(_invalid_feedback.get("lane_slot_keys", [])),
		"invalid_lane_ids": _copy_array(_invalid_feedback.get("lane_ids", [])),
		"invalid_target_instance_ids": _copy_array(_invalid_feedback.get("instance_ids", [])),
		"invalid_player_ids": _copy_array(_invalid_feedback.get("player_ids", [])),
		"detached_active": not _detached_card_state.is_empty(),
		"detached_instance_id": str(_detached_card_state.get("instance_id", "")),
	}


func get_local_match_ai_pacing_state() -> Dictionary:
	return {
		"banner_visible": _is_turn_banner_active(),
		"turn_banner_ms_remaining": _turn_banner_ms_remaining(),
		"waiting_for_turn_banner": _ai_waiting_for_turn_banner,
		"queued_delay_ms_remaining": _local_match_ai_delay_remaining_ms(),
		"paused_delay_ms_remaining": _paused_ai_step_delay_ms,
		"action_count": _local_match_ai_action_count,
	}


func get_feedback_state() -> Dictionary:
	_prune_feedback_state()
	return {
		"attacks": _attack_feedbacks.duplicate(true),
		"damage": _damage_feedbacks.duplicate(true),
		"removals": _removal_feedbacks.duplicate(true),
		"draws": _draw_feedbacks.duplicate(true),
		"runes": _rune_feedbacks.duplicate(true),
	}


func detach_hand_card(instance_id: String) -> bool:
	if not _is_local_hand_card(instance_id):
		return false
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return false
	var mode := _selected_action_mode(card)
	if mode == SELECTION_MODE_NONE:
		return false
	_detach_hand_card(instance_id)
	return true


func is_card_detached() -> bool:
	return not _detached_card_state.is_empty()


func load_scenario(scenario_id: String) -> bool:
	_cancel_detached_card_silent()
	_dismiss_mulligan_overlay()
	_dismiss_prophecy_overlay()
	_dismiss_discard_viewer()
	_dismiss_discard_choice_overlay()
	_dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_dismiss_player_choice_overlay()
	_exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_dismiss_spell_reveal()
	_reset_invalid_feedback()
	_clear_feedback_state()
	_reset_local_match_ai_queue()
	_local_match_ai_action_count = 0
	var next_state: Dictionary = MatchDebugScenarios.build_scenario(scenario_id)
	if next_state.is_empty():
		_status_message = "Failed to load scenario %s." % scenario_id
		_refresh_ui()
		return false
	_scenario_id = scenario_id
	_match_state = next_state
	GameLogger.start_match(next_state)
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	var scenario_timing_result: Dictionary = _match_state.get("last_timing_result", {})
	var scenario_events := _copy_array(scenario_timing_result.get("processed_events", []))
	if scenario_events.is_empty():
		scenario_events = _recent_presentation_events_from_history()
	_record_feedback_from_events(scenario_events)
	_status_message = "Loaded %s." % _scenario_label(scenario_id)
	_refresh_ui()
	return true


func _process_local_match_ai_turn() -> void:
	if not _mulligan_overlay_state.is_empty():
		return
	if not _spell_reveal_state.is_empty():
		return
	if not _deck_reveal_state.is_empty():
		return
	if not _is_local_match_ai_enabled() or _has_match_winner():
		_reset_local_match_ai_queue()
		return
	var ai_has_prophecy := _has_pending_prophecy_for_player(_ai_player_id())
	if _is_local_player_turn() and not ai_has_prophecy:
		_reset_local_match_ai_queue()
		return
	if ai_has_prophecy and _queued_ai_step_at_ms < 0 and _paused_ai_step_delay_ms < 0:
		_schedule_local_match_ai_step(LOCAL_MATCH_AI_ACTION_DELAY_MS * 3)
		return
	var now_ms := Time.get_ticks_msec()
	if _local_player_has_pending_interrupt():
		_pause_local_match_ai_queue(now_ms)
		return
	_resume_local_match_ai_queue(now_ms)
	if not _ai_controls_current_decision_window():
		_reset_local_match_ai_queue()
		return
	if _ai_waiting_for_turn_banner:
		if _is_turn_banner_active():
			return
		_ai_waiting_for_turn_banner = false
	if _queued_ai_step_at_ms > now_ms:
		return
	_queued_ai_step_at_ms = -1
	var step := _execute_local_match_ai_step()
	if not bool(step.get("did_execute", false)):
		if str(step.get("yield_reason", "")) != "waiting_on_local_prophecy":
			_reset_local_match_ai_queue()
		return
	_local_match_ai_action_count += 1
	var yield_reason := str(step.get("yield_reason", ""))
	if yield_reason == "continue" or yield_reason == "waiting_on_local_prophecy":
		var step_action: Dictionary = step.get("action", {})
		var step_delay := LOCAL_MATCH_AI_ACTION_DELAY_MS
		if str(step_action.get("kind", "")) == MatchActionEnumerator.KIND_ATTACK:
			step_delay = LOCAL_MATCH_AI_ATTACK_DELAY_MS
		_schedule_local_match_ai_step(step_delay)
		return
	_reset_local_match_ai_queue()


func _execute_local_match_ai_step() -> Dictionary:
	if not _is_local_match_ai_enabled():
		return {"did_execute": false, "yield_reason": "disabled"}
	if _has_match_winner():
		return {"did_execute": false, "yield_reason": "match_complete"}
	if _local_player_has_pending_interrupt():
		return {"did_execute": false, "yield_reason": "waiting_on_local_prophecy"}
	if not _ai_controls_current_decision_window():
		return {"did_execute": false, "yield_reason": "no_ai_window"}
	var ai_player_id := _ai_player_id()
	var choice := HeuristicMatchPolicy.choose_action(_match_state, ai_player_id, _ai_options)
	if not bool(choice.get("is_valid", false)):
		return {
			"did_execute": false,
			"yield_reason": str(choice.get("reason", "invalid_choice")),
			"choice": choice.duplicate(true),
		}
	var action: Dictionary = choice.get("chosen_action", {}).duplicate(true)
	if action.is_empty():
		return {
			"did_execute": false,
			"yield_reason": "missing_action",
			"choice": choice.duplicate(true),
		}
	var result := MatchActionExecutor.execute_action(_match_state, action)
	if not bool(result.get("is_valid", false)):
		_status_message = str(result.get("errors", ["AI action failed."])[0])
		_refresh_ui()
		return {
			"did_execute": false,
			"yield_reason": "action_failed",
			"choice": choice.duplicate(true),
			"action": action.duplicate(true),
			"result": result.duplicate(true),
		}
	_cancel_detached_card_silent()
	_reset_invalid_feedback()
	_selected_instance_id = ""
	_record_feedback_from_events(_ai_feedback_events(action, result))
	_status_message = _ai_action_status_message(action)
	# Survive puzzle: AI just ended its turn — check if player survived
	if _puzzle_mode and _puzzle_type == "survive" and str(action.get("kind", "")) == MatchActionEnumerator.KIND_END_TURN:
		if str(_match_state.get("winner_player_id", "")).is_empty():
			_match_state["winner_player_id"] = _local_player_id()
			_status_message = "Puzzle Complete!"
			_refresh_ui()
			return {"did_execute": true, "yield_reason": "match_complete", "action": action.duplicate(true), "result": result.duplicate(true)}
	if not _prophecy_overlay_state.is_empty() and not bool(_prophecy_overlay_state.get("is_local", true)):
		_animate_enemy_prophecy_resolution(action, result)
	else:
		var is_enemy := str(action.get("kind", "")) != "" and str(action.get("player_id", "")) != _local_player_id()
		if is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_PLAY_ACTION:
			_animate_enemy_spell_reveal(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_SUMMON_CREATURE and _has_summon_target(action):
			_animate_enemy_creature_summon_reveal(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_SUMMON_CREATURE:
			_animate_enemy_creature_play(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_PLAY_ITEM:
			_animate_enemy_item_reveal(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_ATTACK:
			_animate_enemy_attack_arrow(action, result)
		elif is_enemy and str(action.get("kind", "")) == MatchActionEnumerator.KIND_ACTIVATE_SUPPORT and _has_support_activation_target(action):
			_animate_enemy_support_activation_arrow(action, result)
		else:
			_refresh_ui()
	if _arena_mode:
		match_state_changed.emit(_match_state.duplicate(true))
	return {
		"did_execute": true,
		"yield_reason": _ai_post_action_state(),
		"choice": choice.duplicate(true),
		"action": action.duplicate(true),
		"result": result.duplicate(true),
	}


func _ai_feedback_events(action: Dictionary, result: Dictionary) -> Array:
	var events := _copy_array(result.get("events", []))
	if str(action.get("kind", "")) == MatchActionEnumerator.KIND_END_TURN:
		var timing_result: Dictionary = _match_state.get("last_timing_result", {})
		var processed_events := _copy_array(timing_result.get("processed_events", []))
		if not processed_events.is_empty():
			events = processed_events
	return events


func _ai_action_status_message(action: Dictionary) -> String:
	var player_name := _player_name(str(action.get("player_id", "")))
	var source_name := _ai_action_source_name(action)
	match str(action.get("kind", "")):
		MatchActionEnumerator.KIND_RING_USE:
			return "%s used the Ring of Magicka." % player_name
		MatchActionEnumerator.KIND_END_TURN:
			return "%s ended the turn." % player_name
		MatchActionEnumerator.KIND_SUMMON_CREATURE:
			return "%s played %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_ATTACK:
			return "%s attacked %s with %s." % [player_name, _ai_action_target_name(action), source_name]
		MatchActionEnumerator.KIND_PLAY_SUPPORT:
			return "%s played %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_PLAY_ITEM:
			return "%s used %s on %s." % [player_name, source_name, _ai_action_target_name(action)]
		MatchActionEnumerator.KIND_ACTIVATE_SUPPORT:
			return "%s activated %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_PLAY_ACTION:
			return "%s resolved %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_DECLINE_PROPHECY:
			return "%s declined %s." % [player_name, source_name]
		MatchActionEnumerator.KIND_CHOOSE_DISCARD:
			return "%s drew %s from the discard pile." % [player_name, source_name]
		MatchActionEnumerator.KIND_DECLINE_DISCARD:
			return "%s had no valid discard choices." % player_name
		_:
			return "%s acted." % player_name


func _ai_action_source_name(action: Dictionary) -> String:
	var source_card: Dictionary = action.get("source_card", {})
	if not source_card.is_empty():
		return _card_name(source_card)
	return "the current action"


func _ai_action_target_name(action: Dictionary) -> String:
	var target: Dictionary = action.get("target", {})
	match str(target.get("kind", "")):
		"player":
			return _player_name(str(target.get("player_id", "")))
		"card":
			return _card_name(target.get("card", {}))
		"lane_slot":
			return "%s lane" % _lane_name(str(target.get("lane_id", "")))
		"mobilize_recruit":
			return "%s lane recruit" % _lane_name(str(target.get("lane_id", "")))
		_:
			return "the target"


func _ai_post_action_state() -> String:
	if _has_match_winner():
		return "match_complete"
	if _local_player_has_pending_interrupt():
		return "waiting_on_local_prophecy"
	if _is_local_player_turn():
		return "returned_to_local_player"
	if _ai_controls_current_decision_window():
		return "continue"
	return "idle"


func _reset_local_match_ai_queue() -> void:
	_queued_ai_step_at_ms = -1
	_paused_ai_step_delay_ms = -1
	_ai_waiting_for_turn_banner = false


func _schedule_local_match_ai_step(delay_ms: int) -> void:
	_queued_ai_step_at_ms = Time.get_ticks_msec() + maxi(delay_ms, 0)
	_paused_ai_step_delay_ms = -1


func _pause_local_match_ai_queue(now_ms: int) -> void:
	if _queued_ai_step_at_ms < 0:
		return
	_paused_ai_step_delay_ms = maxi(_queued_ai_step_at_ms - now_ms, 0)
	_queued_ai_step_at_ms = -1


func _resume_local_match_ai_queue(now_ms: int) -> void:
	if _paused_ai_step_delay_ms < 0 or _queued_ai_step_at_ms >= 0:
		return
	_queued_ai_step_at_ms = now_ms + _paused_ai_step_delay_ms
	_paused_ai_step_delay_ms = -1


func _local_match_ai_delay_remaining_ms() -> int:
	if _queued_ai_step_at_ms < 0:
		return -1
	return maxi(_queued_ai_step_at_ms - Time.get_ticks_msec(), 0)


func _is_turn_banner_active() -> bool:
	return _turn_banner_ms_remaining() > 0


func _turn_banner_ms_remaining() -> int:
	return maxi(_turn_banner_until_ms - Time.get_ticks_msec(), 0)


func _arm_local_match_ai_turn_pacing() -> void:
	_reset_local_match_ai_queue()
	_local_match_ai_action_count = 0
	_ai_waiting_for_turn_banner = true


func select_card(instance_id: String) -> bool:
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		_status_message = "Card %s is not available to inspect." % instance_id
		_refresh_ui()
		return false
	_reset_invalid_feedback()
	_clear_pile_selection()
	_selected_instance_id = instance_id
	_status_message = _selection_prompt(card)
	_refresh_ui()
	return true


func clear_selection() -> void:
	_cancel_detached_card_silent()
	_reset_invalid_feedback()
	_selected_instance_id = ""
	_clear_pile_selection()
	_status_message = "Selection cleared."
	_refresh_ui()


func play_selected_to_lane(lane_id: String, slot_index := -1) -> Dictionary:
	var card := _selected_card()
	if card.is_empty():
		return _invalid_ui_result("Select a creature first.")
	if not _can_resolve_selected_action(card):
		return _invalid_ui_result(_status_message)
	if _selected_action_mode(card) == SELECTION_MODE_ACTION:
		_play_action_to_lane(lane_id)
		return {"is_valid": true}
	# Check for exalt prompt before committing the play
	if _check_exalt_creature(card, lane_id, slot_index, _is_pending_prophecy_card(card)):
		return {"is_valid": true}
	var saved_instance_id := _selected_instance_id
	var options := {}
	if slot_index >= 0:
		options["slot_index"] = slot_index
	var result := {}
	if _is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id, options.merged({"lane_id": lane_id}, true))
	else:
		result = LaneRules.summon_from_hand(_match_state, _active_player_id(), _selected_instance_id, lane_id, options)
	var finalized := _finalize_engine_result(result, "Played %s into %s." % [_card_name(card), _lane_name(lane_id)])
	if bool(finalized.get("is_valid", false)):
		_check_summon_target_mode(saved_instance_id)
	return finalized


func _try_play_hovered_hand_card_to_lane(lane_index: int) -> void:
	var instance_id := _hovered_hand_instance_id
	if instance_id.is_empty() or not _is_local_hand_card(instance_id):
		return
	# Don't interfere with other active interaction modes
	if not _pending_summon_target.is_empty() or not _targeting_arrow_state.is_empty() or not _detached_card_state.is_empty():
		return
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	var mode := _selected_action_mode(card)
	# Only creatures and non-targeted actions can be played directly to a lane
	if mode != SELECTION_MODE_SUMMON and not (mode == SELECTION_MODE_ACTION and not _action_needs_explicit_target(card)):
		return
	var lane_list := _lane_entries()
	if lane_index < 0 or lane_index >= lane_list.size():
		return
	var lane_id := str(lane_list[lane_index].get("id", ""))
	var player_id := _target_lane_player_id()
	var slot_index := _first_open_slot_index(lane_id, player_id)
	if slot_index < 0:
		return
	_selected_instance_id = instance_id
	var validation := _validate_selected_lane_play(lane_id, player_id, slot_index)
	if bool(validation.get("is_valid", false)):
		play_selected_to_lane(lane_id, slot_index)
	else:
		_selected_instance_id = ""


func play_or_activate_selected() -> Dictionary:
	var card := _selected_card()
	if card.is_empty():
		return _invalid_ui_result("Select a card first.")
	if not _can_resolve_selected_action(card):
		return _invalid_ui_result(_status_message)
	var saved_instance_id := _selected_instance_id
	var saved_card := card.duplicate(true)
	var is_action_play := false
	var location := MatchMutations.find_card_location(_match_state, _selected_instance_id)
	var result := {}
	if _is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id)
	elif bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_HAND:
		match str(card.get("card_type", "")):
			"support":
				result = PersistentCardRules.play_support_from_hand(_match_state, _active_player_id(), _selected_instance_id)
			"creature":
				return _invalid_ui_result("Select a lane to summon this creature.")
			"item":
				return _invalid_ui_result("Select a friendly creature to equip this item.")
			"action":
				if _action_needs_explicit_target(card):
					return _invalid_ui_result("Select a target for this action.")
				if _check_exalt_action(card, {}, _is_pending_prophecy_card(card)):
					return {"is_valid": true}
				result = MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id)
				is_action_play = true
			_:
				return _invalid_ui_result("Selected card cannot be played from the UI yet.")
	elif bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_SUPPORT:
		# Check for choose_lane_and_owner activate mode — show choice overlay
		if _support_has_choose_lane_and_owner(card):
			_show_lane_and_owner_choice(_selected_instance_id)
			return {"is_valid": true}
		result = PersistentCardRules.activate_support(_match_state, _active_player_id(), _selected_instance_id)
	else:
		return _invalid_ui_result("Selected card has no direct action. Choose a lane or target instead.")
	var finalized := _finalize_engine_result(result, "Resolved %s." % _card_name(card))
	if is_action_play and bool(finalized.get("is_valid", false)):
		_check_betray_mode(saved_instance_id, saved_card)
	return finalized


func target_selected_card(target_instance_id: String) -> Dictionary:
	var selected_card := _selected_card()
	if selected_card.is_empty():
		return _invalid_ui_result("Select a card first.")
	if not _can_resolve_selected_action(selected_card):
		return _invalid_ui_result(_status_message)
	var target_location := MatchMutations.find_card_location(_match_state, target_instance_id)
	if not bool(target_location.get("is_valid", false)):
		return _invalid_ui_result("Target %s is not on the board." % target_instance_id)
	var target_card: Dictionary = target_location.get("card", {})
	var selected_location := MatchMutations.find_card_location(_match_state, _selected_instance_id)
	var saved_item_id := ""
	var saved_action_id := ""
	var saved_action_card := {}
	var result := {}
	if bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_HAND and str(selected_card.get("card_type", "")) == "item":
		saved_item_id = _selected_instance_id
		if _is_pending_prophecy_card(selected_card):
			result = MatchTiming.play_pending_prophecy(_match_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"target_instance_id": target_instance_id})
		else:
			result = PersistentCardRules.play_item_from_hand(_match_state, _active_player_id(), _selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_HAND and str(selected_card.get("card_type", "")) == "action":
		saved_action_id = _selected_instance_id
		saved_action_card = selected_card.duplicate(true)
		if _check_exalt_action(selected_card, {"target_instance_id": target_instance_id}, _is_pending_prophecy_card(selected_card)):
			return {"is_valid": true}
		if _is_pending_prophecy_card(selected_card):
			result = MatchTiming.play_pending_prophecy(_match_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"target_instance_id": target_instance_id})
		else:
			result = MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_SUPPORT:
		result = PersistentCardRules.activate_support(_match_state, _active_player_id(), _selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_LANE:
		result = MatchCombat.resolve_attack(_match_state, _active_player_id(), _selected_instance_id, {"type": "creature", "instance_id": target_instance_id})
	else:
		return _invalid_ui_result("Current selection does not use card targets.")
	var finalized := _finalize_engine_result(result, "Resolved %s onto %s." % [_card_name(selected_card), _card_name(target_card)])
	if bool(finalized.get("is_valid", false)) and not saved_action_id.is_empty():
		_check_betray_mode(saved_action_id, saved_action_card)
	return finalized


func attack_selected_player(player_id: String) -> Dictionary:
	var selected_card := _selected_card()
	if selected_card.is_empty():
		return _invalid_ui_result("Select an attacking creature first.")
	if not _can_resolve_selected_action(selected_card):
		return _invalid_ui_result(_status_message)
	var result := MatchCombat.resolve_attack(_match_state, _active_player_id(), _selected_instance_id, {"type": "player", "player_id": player_id})
	return _finalize_engine_result(result, "%s attacked %s." % [_card_name(selected_card), _player_name(player_id)])


func decline_prophecy(instance_id: String) -> Dictionary:
	var player_id := _pending_prophecy_player_id(instance_id)
	if player_id.is_empty():
		return _invalid_ui_result("No pending Prophecy exists for %s." % instance_id)
	var card := _card_from_instance_id(instance_id)
	var result := MatchTiming.decline_pending_prophecy(_match_state, player_id, instance_id)
	return _finalize_engine_result(result, "Declined %s." % _card_name(card), false)


func use_ring() -> bool:
	if MatchTiming.has_pending_prophecy(_match_state):
		_status_message = "Resolve the open Prophecy window before taking further turn actions."
		_refresh_ui()
		return false
	var player_id := _active_player_id()
	if not MatchTurnLoop.can_activate_ring_of_magicka(_match_state, player_id):
		_status_message = "%s cannot use the Ring of Magicka right now." % _player_name(player_id)
		_refresh_ui()
		return false
	MatchTurnLoop.activate_ring_of_magicka(_match_state, player_id)
	_selected_instance_id = ""
	_status_message = "%s used the Ring of Magicka." % _player_name(player_id)
	_refresh_ui()
	if _arena_mode:
		match_state_changed.emit(_match_state.duplicate(true))
	return true


func end_turn_action() -> bool:
	if not _pending_exalt.is_empty():
		return false
	if MatchTiming.has_pending_prophecy(_match_state):
		_status_message = "Resolve the open Prophecy window before ending the turn."
		_refresh_ui()
		return false
	var player_id := _active_player_id()
	# Queue any targeted end_of_turn triggers before ending the turn
	MatchTiming.queue_turn_trigger_targets(_match_state, player_id)
	if MatchTiming.has_pending_turn_trigger_target(_match_state, _local_player_id()):
		_pending_end_turn = true
		_pending_end_turn_player_id = player_id
		_check_pending_turn_trigger_target()
		return true
	_complete_end_turn(player_id)
	return true


func _complete_end_turn(player_id: String) -> void:
	_pending_end_turn = false
	# Kill puzzle: if the player ends their turn without killing the enemy, they lose
	if _puzzle_mode and _puzzle_type == "kill" and player_id == _local_player_id():
		if str(_match_state.get("winner_player_id", "")).is_empty():
			_match_state["winner_player_id"] = _enemy_player_id()
			_status_message = "Puzzle Failed"
			_refresh_ui()
			return
	MatchTurnLoop.end_turn(_match_state, player_id)
	var timing_result: Dictionary = _match_state.get("last_timing_result", {})
	_record_feedback_from_events(_copy_array(timing_result.get("processed_events", [])))
	_selected_instance_id = ""
	_status_message = "Ended %s's turn." % _player_name(player_id)
	# Survive puzzle: if the enemy's turn just ended and it's now the player's turn,
	# and the player is still alive, they win
	if _puzzle_mode and _puzzle_type == "survive" and player_id == _enemy_player_id():
		if str(_match_state.get("winner_player_id", "")).is_empty():
			_match_state["winner_player_id"] = _local_player_id()
			_status_message = "Puzzle Complete!"
			_refresh_ui()
			return
	_refresh_ui()
	if _arena_mode:
		match_state_changed.emit(_match_state.duplicate(true))


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.name = "BoardBackground"
	bg.texture = preload("res://assets/images/board/default.png")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := MarginContainer.new()
	root.name = "MatchLayout"
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 22)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 22)
	add_child(root)
	var content := VBoxContainer.new()
	content.name = "MatchContent"
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	root.add_child(content)

	_card_hover_preview_layer = Control.new()
	_card_hover_preview_layer.name = "CardHoverPreviewLayer"
	_card_hover_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_hover_preview_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_card_hover_preview_layer)

	_opponent_avatar_overlay = Control.new()
	_opponent_avatar_overlay.name = "OpponentAvatarOverlay"
	_opponent_avatar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opponent_avatar_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_opponent_avatar_overlay)

	_player_avatar_overlay = Control.new()
	_player_avatar_overlay.name = "PlayerAvatarOverlay"
	_player_avatar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_avatar_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_player_avatar_overlay)

	_opponent_hand_overlay = Control.new()
	_opponent_hand_overlay.name = "OpponentHandOverlay"
	_opponent_hand_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opponent_hand_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_opponent_hand_overlay)

	_local_hand_overlay = Control.new()
	_local_hand_overlay.name = "LocalHandOverlay"
	_local_hand_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_local_hand_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_local_hand_overlay)

	_prophecy_card_overlay = Control.new()
	_prophecy_card_overlay.name = "ProphecyCardOverlay"
	_prophecy_card_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prophecy_card_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_prophecy_card_overlay.z_index = 450
	add_child(_prophecy_card_overlay)

	_match_history_container = HBoxContainer.new()
	_match_history_container.name = "MatchHistoryRow"
	_match_history_container.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	_match_history_container.position = Vector2(32, 28)
	_match_history_container.add_theme_constant_override("separation", 6)
	_match_history_container.z_index = 100
	_match_history_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_match_history_container)

	var main_row := HBoxContainer.new()
	main_row.name = "MainRow"
	main_row.size_flags_horizontal = SIZE_EXPAND_FILL
	main_row.size_flags_vertical = SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 28)
	content.add_child(main_row)

	var board_column := VBoxContainer.new()
	board_column.name = "BoardColumn"
	board_column.size_flags_horizontal = SIZE_EXPAND_FILL
	board_column.size_flags_vertical = SIZE_EXPAND_FILL
	board_column.add_theme_constant_override("separation", 22)
	main_row.add_child(board_column)

	# Create end turn button early so it can be placed in the player section
	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = Vector2(0, 54)
	_end_turn_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_end_turn_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(_end_turn_button, Color(0.25, 0.14, 0.13, 0.98), Color(0.69, 0.35, 0.27, 0.94), Color(0.98, 0.93, 0.9, 1.0))
	_end_turn_button.pressed.connect(_on_end_turn_pressed)

	for player_id in PLAYER_ORDER:
		var section := _build_player_section(player_id)
		_player_sections[player_id] = section
		board_column.add_child(section["panel"])
		if player_id == PLAYER_ORDER[0]:
			var lanes_panel := _build_lanes_panel()
			board_column.add_child(lanes_panel)

	_match_end_overlay = _build_match_end_overlay()
	root.add_child(_match_end_overlay)

	_pause_overlay = _build_pause_overlay()
	root.add_child(_pause_overlay)

	_lane_tooltip_panel = _build_lane_tooltip_panel()
	add_child(_lane_tooltip_panel)



func _build_player_section(player_id: String) -> Dictionary:
	var is_opponent := player_id == PLAYER_ORDER[0]
	var panel := PanelContainer.new()
	panel.name = "OpponentBand" if is_opponent else "PlayerBand"
	panel.custom_minimum_size = Vector2(0, 220)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_apply_panel_style(panel, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	var box := _build_panel_box(panel, 12, 14)

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 16)
	content_row.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_child(content_row)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero_row.size_flags_horizontal = SIZE_EXPAND_FILL
	content_row.add_child(hero_row)

	var avatar_component := PLAYER_AVATAR_SCENE.instantiate()
	avatar_component.name = "%s_avatar_component" % player_id
	avatar_component.custom_minimum_size = Vector2(282, 264)
	avatar_component.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar_component.gui_input.connect(_on_avatar_gui_input.bind(player_id))
	avatar_component.mouse_entered.connect(_on_avatar_mouse_entered.bind(player_id))
	avatar_component.mouse_exited.connect(_on_avatar_mouse_exited)
	hero_row.add_child(avatar_component)

	var identity_column := VBoxContainer.new()
	identity_column.size_flags_horizontal = SIZE_EXPAND_FILL
	identity_column.add_theme_constant_override("separation", 8)
	hero_row.add_child(identity_column)
	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 10)
	resource_row.size_flags_horizontal = SIZE_EXPAND_FILL
	identity_column.add_child(resource_row)

	var magicka_mount := CenterContainer.new()
	magicka_mount.name = "%s_magicka_mount" % player_id
	magicka_mount.custom_minimum_size = Vector2(180, 172)
	magicka_mount.size_flags_horizontal = SIZE_EXPAND_FILL
	magicka_mount.mouse_filter = Control.MOUSE_FILTER_STOP
	magicka_mount.mouse_entered.connect(_on_magicka_mouse_entered.bind(player_id))
	magicka_mount.mouse_exited.connect(_on_magicka_mouse_exited)
	var magicka_component := PLAYER_MAGICKA_SCENE.instantiate()
	magicka_component.name = "%s_magicka_component" % player_id
	magicka_component.custom_minimum_size = Vector2(172, 172)
	magicka_component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magicka_mount.add_child(magicka_component)

	resource_row.add_child(magicka_mount)

	# Overlay for repositioned magicka (populated after panel is built)
	var magicka_overlay := Control.new()
	magicka_overlay.name = "%s_magicka_overlay" % player_id
	magicka_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magicka_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var ring_panel := PanelContainer.new()
	ring_panel.name = "%s_ring_panel" % player_id
	ring_panel.custom_minimum_size = Vector2(0, 54)
	ring_panel.size_flags_horizontal = 0
	_apply_panel_style(ring_panel, Color(0.18, 0.14, 0.08, 0.96), Color(0.63, 0.53, 0.26, 0.94), 1, 10)
	ring_panel.mouse_entered.connect(_on_ring_mouse_entered.bind(player_id))
	ring_panel.mouse_exited.connect(_on_ring_mouse_exited)
	if not is_opponent:
		ring_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		ring_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ring_panel.gui_input.connect(_on_ring_panel_input)
	else:
		ring_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	resource_row.add_child(ring_panel)
	var ring_box := _build_panel_box(ring_panel, 4, 8)
	var ring_label := Label.new()
	ring_label.name = "%s_ring_label" % player_id
	ring_label.add_theme_font_size_override("font_size", 14)
	ring_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78, 1.0))
	ring_box.add_child(ring_label)
	var ring_row := HBoxContainer.new()
	ring_row.name = "%s_ring_row" % player_id
	ring_row.add_theme_constant_override("separation", 4)
	ring_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ring_box.add_child(ring_row)

	var pile_column := VBoxContainer.new()
	pile_column.custom_minimum_size = Vector2(108, 0)
	pile_column.add_theme_constant_override("separation", 8)
	hero_row.add_child(pile_column)

	var deck_button := Button.new()
	deck_button.name = "%s_deck_button" % player_id
	deck_button.custom_minimum_size = Vector2(0, 48)
	deck_button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(deck_button, Color(0.15, 0.16, 0.2, 0.98), Color(0.36, 0.39, 0.49, 0.92), Color(0.92, 0.94, 0.98, 1.0), 1, 10)
	deck_button.pressed.connect(_on_pile_pressed.bind(player_id, MatchMutations.ZONE_DECK))
	deck_button.mouse_entered.connect(_on_pile_mouse_entered.bind(player_id, MatchMutations.ZONE_DECK))
	deck_button.mouse_exited.connect(_on_pile_mouse_exited.bind(player_id, MatchMutations.ZONE_DECK))
	pile_column.add_child(deck_button)

	var discard_button := Button.new()
	discard_button.name = "%s_discard_button" % player_id
	discard_button.custom_minimum_size = Vector2(0, 48)
	discard_button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(discard_button, Color(0.2, 0.12, 0.16, 0.98), Color(0.58, 0.32, 0.39, 0.94), Color(0.97, 0.92, 0.94, 1.0), 1, 10)
	discard_button.pressed.connect(_on_pile_pressed.bind(player_id, MatchMutations.ZONE_DISCARD))
	discard_button.mouse_entered.connect(_on_pile_mouse_entered.bind(player_id, MatchMutations.ZONE_DISCARD))
	discard_button.mouse_exited.connect(_on_pile_mouse_exited.bind(player_id, MatchMutations.ZONE_DISCARD))
	pile_column.add_child(discard_button)

	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	rows.size_flags_vertical = SIZE_SHRINK_CENTER
	content_row.add_child(rows)

	var support_surface := Control.new()
	support_surface.name = "%s_support_surface" % player_id
	support_surface.focus_mode = Control.FOCUS_NONE
	support_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(support_surface)

	var support_row := HBoxContainer.new()
	support_row.name = "%s_support_row" % player_id
	support_row.add_theme_constant_override("separation", 16)
	support_row.alignment = BoxContainer.ALIGNMENT_END
	support_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	support_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_surface.add_child(support_row)

	# End turn button – bottom-right of local player section
	if not is_opponent:
		var end_turn_row := HBoxContainer.new()
		end_turn_row.size_flags_horizontal = SIZE_SHRINK_END
		_end_turn_button.size_flags_horizontal = 0
		_end_turn_button.custom_minimum_size = Vector2(140, 54)
		end_turn_row.add_child(_end_turn_button)
		box.add_child(end_turn_row)

	var hand_row := Control.new()
	hand_row.name = "%s_hand_row" % player_id
	hand_row.clip_contents = false
	hand_row.set_meta("player_id", player_id)

	if not is_opponent and _local_hand_overlay != null:
		# Local hand floats at the bottom of the screen, separate from the band layout
		hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_local_hand_overlay.add_child(hand_row)
		# Re-layout hand cards when the viewport/overlay resizes
		_local_hand_overlay.resized.connect(_on_hand_surface_resized.bind(hand_row))
	elif is_opponent and _opponent_hand_overlay != null:
		# Opponent hand floats at the top of the screen, separate from the band layout
		hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_opponent_hand_overlay.add_child(hand_row)

	# Reposition magicka and pile buttons into an absolute overlay on the panel
	# so they don't affect the flow layout that other tests depend on.
	panel.add_child(magicka_overlay)
	magicka_mount.reparent(magicka_overlay)
	magicka_mount.size_flags_horizontal = 0
	magicka_mount.size_flags_vertical = 0
	deck_button.reparent(magicka_overlay)
	discard_button.reparent(magicka_overlay)
	ring_panel.reparent(magicka_overlay)
	var pile_btn_width := 108.0
	var pile_btn_height := 48.0
	var pile_gap := 8.0
	var magicka_w := magicka_mount.custom_minimum_size.x
	var magicka_h := magicka_mount.custom_minimum_size.y
	if is_opponent:
		# Top-right of opponent section: magicka, then deck, then discard to the left
		var margin := 14.0
		magicka_mount.anchor_left = 1.0
		magicka_mount.anchor_right = 1.0
		magicka_mount.anchor_top = 0.0
		magicka_mount.anchor_bottom = 0.0
		magicka_mount.offset_left = -magicka_w - margin
		magicka_mount.offset_right = -margin
		magicka_mount.offset_top = margin
		magicka_mount.offset_bottom = magicka_h + margin
		# Deck button – left of magicka, vertically centered on magicka
		var deck_left := magicka_mount.offset_left - pile_gap - pile_btn_width
		var pile_center_y := margin + magicka_h * 0.5
		deck_button.set_anchors_preset(PRESET_TOP_RIGHT)
		deck_button.offset_left = deck_left
		deck_button.offset_right = deck_left + pile_btn_width
		deck_button.offset_top = pile_center_y - pile_btn_height - pile_gap * 0.5
		deck_button.offset_bottom = pile_center_y - pile_gap * 0.5
		# Discard button – left of deck
		discard_button.set_anchors_preset(PRESET_TOP_RIGHT)
		discard_button.offset_left = deck_left
		discard_button.offset_right = deck_left + pile_btn_width
		discard_button.offset_top = pile_center_y + pile_gap * 0.5
		discard_button.offset_bottom = pile_center_y + pile_gap * 0.5 + pile_btn_height
		# Ring panel – below magicka
		var ring_w := pile_btn_width
		ring_panel.set_anchors_preset(PRESET_TOP_RIGHT)
		ring_panel.offset_left = magicka_mount.offset_left
		ring_panel.offset_right = magicka_mount.offset_right
		ring_panel.offset_top = magicka_mount.offset_bottom + pile_gap
		ring_panel.offset_bottom = magicka_mount.offset_bottom + pile_gap + 54.0
	else:
		# Bottom-right, left of end turn button
		var margin := 14.0
		var end_turn_width := 140.0 + 12.0
		magicka_mount.anchor_left = 1.0
		magicka_mount.anchor_right = 1.0
		magicka_mount.anchor_top = 1.0
		magicka_mount.anchor_bottom = 1.0
		magicka_mount.offset_left = -magicka_w - margin - end_turn_width
		magicka_mount.offset_right = -margin - end_turn_width
		magicka_mount.offset_top = -magicka_h - margin
		magicka_mount.offset_bottom = -margin
		# Deck button – left of magicka, vertically centered on magicka
		var deck_left := magicka_mount.offset_left - pile_gap - pile_btn_width
		var pile_center_y := -margin - magicka_h * 0.5
		deck_button.set_anchors_preset(PRESET_BOTTOM_RIGHT)
		deck_button.offset_left = deck_left
		deck_button.offset_right = deck_left + pile_btn_width
		deck_button.offset_top = pile_center_y - pile_btn_height - pile_gap * 0.5
		deck_button.offset_bottom = pile_center_y - pile_gap * 0.5
		# Discard button – below deck
		discard_button.set_anchors_preset(PRESET_BOTTOM_RIGHT)
		discard_button.offset_left = deck_left
		discard_button.offset_right = deck_left + pile_btn_width
		discard_button.offset_top = pile_center_y + pile_gap * 0.5
		discard_button.offset_bottom = pile_center_y + pile_gap * 0.5 + pile_btn_height
		# Ring panel – left of deck/discard stack, vertically centered on magicka
		var ring_w := 130.0
		var ring_h := 54.0
		var ring_right := deck_left - pile_gap
		ring_panel.set_anchors_preset(PRESET_BOTTOM_RIGHT)
		ring_panel.offset_left = ring_right - ring_w
		ring_panel.offset_right = ring_right
		ring_panel.offset_top = pile_center_y - ring_h * 0.5
		ring_panel.offset_bottom = pile_center_y + ring_h * 0.5

	# Reparent avatar and support into their own screen-level overlay
	var avatar_overlay: Control = _opponent_avatar_overlay if is_opponent else _player_avatar_overlay
	if avatar_overlay != null:
		avatar_component.reparent(avatar_overlay)
		avatar_component.size_flags_horizontal = 0
		avatar_component.size_flags_vertical = 0
		avatar_component.clip_contents = true
		support_surface.reparent(avatar_overlay)
		support_surface.size_flags_horizontal = 0
		support_surface.size_flags_vertical = 0
		var avatar_w := 300.0
		var avatar_h := 282.0
		var avatar_gap := 12.0
		var support_h := 144.0
		# Force avatar to its intended size immediately so internal layout is stable
		avatar_component.size = Vector2(avatar_w, avatar_h)
		if is_opponent:
			# Opponent: centred horizontally, below the opponent hand area
			var top_y := 64.0
			avatar_component.set_anchors_preset(PRESET_CENTER_TOP)
			avatar_component.offset_left = -avatar_w * 0.5
			avatar_component.offset_right = avatar_w * 0.5
			avatar_component.offset_top = top_y
			avatar_component.offset_bottom = top_y + avatar_h
			# Supports row to the left of the avatar, right-aligned to grow leftward
			var support_right := -avatar_w * 0.5 - avatar_gap
			support_surface.set_anchors_preset(PRESET_CENTER_TOP)
			support_surface.offset_right = support_right
			support_surface.offset_left = support_right - 600.0
			support_surface.offset_top = top_y + (avatar_h - support_h) * 0.5
			support_surface.offset_bottom = top_y + (avatar_h + support_h) * 0.5
		else:
			# Player: centred horizontally, above the player hand area
			var bottom_margin := 180.0
			avatar_component.set_anchors_preset(PRESET_CENTER_BOTTOM)
			avatar_component.offset_left = -avatar_w * 0.5
			avatar_component.offset_right = avatar_w * 0.5
			avatar_component.offset_top = -avatar_h - bottom_margin
			avatar_component.offset_bottom = -bottom_margin
			# Supports row to the left of the avatar, right-aligned to grow leftward
			var support_right := -avatar_w * 0.5 - avatar_gap
			support_surface.set_anchors_preset(PRESET_CENTER_BOTTOM)
			support_surface.offset_right = support_right
			support_surface.offset_left = support_right - 600.0
			support_surface.offset_top = -avatar_h - bottom_margin + (avatar_h - support_h) * 0.5
			support_surface.offset_bottom = -avatar_h - bottom_margin + (avatar_h + support_h) * 0.5

	return {
		"player_id": player_id,
		"panel": panel,
		"avatar_component": avatar_component,
		"magicka_component": magicka_component,
		"ring_panel": ring_panel,
		"ring_label": ring_label,
		"ring_row": ring_row,
		"deck_button": deck_button,
		"discard_button": discard_button,
		"support_surface": support_surface,
		"support_row": support_row,
		"hand_row": hand_row,
	}


func _build_match_end_overlay() -> PanelContainer:
	var overlay := PanelContainer.new()
	overlay.name = "MatchEndOverlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 80
	_apply_panel_style(overlay, Color(0.04, 0.05, 0.07, 0.78), Color(0.84, 0.71, 0.42, 0.96), 2, 18)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.name = "MatchEndCard"
	card.custom_minimum_size = Vector2(360, 220)
	_apply_panel_style(card, Color(0.1, 0.11, 0.16, 0.98), Color(0.88, 0.74, 0.44, 0.98), 2, 16)
	center.add_child(card)
	var box := _build_panel_box(card, 18, 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_match_end_title_label = Label.new()
	_match_end_title_label.name = "MatchEndTitle"
	_match_end_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_end_title_label.add_theme_font_size_override("font_size", 34)
	box.add_child(_match_end_title_label)
	_match_end_detail_label = Label.new()
	_match_end_detail_label.name = "MatchEndDetailLabel"
	_match_end_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_end_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_match_end_detail_label.add_theme_font_size_override("font_size", 17)
	_match_end_detail_label.custom_minimum_size = Vector2(320, 0)
	box.add_child(_match_end_detail_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	_match_end_button = Button.new()
	_match_end_button.name = "MatchEndMainMenuButton"
	_match_end_button.text = "Return to Main Menu"
	_match_end_button.custom_minimum_size = Vector2(280, 48)
	_match_end_button.add_theme_font_size_override("font_size", 17)
	_match_end_button.pressed.connect(func(): return_to_main_menu_requested.emit())
	box.add_child(_match_end_button)
	_match_end_box = box
	return overlay


func _build_pause_overlay() -> PanelContainer:
	var overlay := PanelContainer.new()
	overlay.name = "PauseOverlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 90
	_apply_panel_style(overlay, Color(0.04, 0.05, 0.07, 0.78), Color(0.5, 0.5, 0.55, 0.6), 0, 0)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.name = "PauseCard"
	card.custom_minimum_size = Vector2(320, 0)
	_apply_panel_style(card, Color(0.1, 0.11, 0.16, 0.98), Color(0.5, 0.5, 0.55, 0.96), 2, 16)
	center.add_child(card)
	var box := _build_panel_box(card, 14, 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	box.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)
	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size = Vector2(260, 48)
	resume_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(resume_button, Color(0.18, 0.22, 0.18, 0.98), Color(0.5, 0.7, 0.5, 0.94), Color(0.95, 0.98, 0.95, 1.0), 1, 12)
	resume_button.pressed.connect(_toggle_pause_menu)
	box.add_child(resume_button)
	if _puzzle_mode:
		var retry_button := Button.new()
		retry_button.text = "Retry"
		retry_button.custom_minimum_size = Vector2(260, 48)
		retry_button.add_theme_font_size_override("font_size", 17)
		_apply_button_style(retry_button, Color(0.18, 0.18, 0.22, 0.98), Color(0.5, 0.5, 0.7, 0.94), Color(0.95, 0.95, 0.98, 1.0), 1, 12)
		retry_button.pressed.connect(func(): _pause_overlay.visible = false; puzzle_retry_requested.emit())
		box.add_child(retry_button)
		var return_button := Button.new()
		return_button.text = "Return to Puzzles"
		return_button.custom_minimum_size = Vector2(260, 48)
		return_button.add_theme_font_size_override("font_size", 17)
		_apply_button_style(return_button, Color(0.22, 0.18, 0.18, 0.98), Color(0.7, 0.5, 0.5, 0.94), Color(0.98, 0.95, 0.95, 1.0), 1, 12)
		return_button.pressed.connect(func(): _pause_overlay.visible = false; puzzle_return_to_select_requested.emit())
		box.add_child(return_button)
	elif _arena_mode:
		var forfeit_button := Button.new()
		forfeit_button.text = "Forfeit"
		forfeit_button.custom_minimum_size = Vector2(260, 48)
		forfeit_button.add_theme_font_size_override("font_size", 17)
		_apply_button_style(forfeit_button, Color(0.6, 0.18, 0.14, 0.98), Color(0.9, 0.42, 0.42, 0.94), Color(1.0, 0.93, 0.9, 1.0), 1, 12)
		forfeit_button.pressed.connect(_forfeit_match)
		box.add_child(forfeit_button)
	else:
		var menu_button := Button.new()
		menu_button.text = "Return to Menu"
		menu_button.custom_minimum_size = Vector2(260, 48)
		menu_button.add_theme_font_size_override("font_size", 17)
		_apply_button_style(menu_button, Color(0.22, 0.18, 0.18, 0.98), Color(0.7, 0.5, 0.5, 0.94), Color(0.98, 0.95, 0.95, 1.0), 1, 12)
		menu_button.pressed.connect(func(): _pause_overlay.visible = false; return_to_main_menu_requested.emit())
		box.add_child(menu_button)
	return overlay


func _toggle_pause_menu() -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.visible = not _pause_overlay.visible


func _forfeit_match() -> void:
	_pause_overlay.visible = false
	forfeit_requested.emit()


func _build_lanes_panel() -> Control:
	var lanes_row := HBoxContainer.new()
	lanes_row.name = "BattlefieldPanel"
	lanes_row.custom_minimum_size = Vector2(0, 740)
	lanes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes_row.size_flags_horizontal = SIZE_EXPAND_FILL
	lanes_row.size_flags_vertical = SIZE_EXPAND_FILL
	lanes_row.size_flags_stretch_ratio = 2.8
	lanes_row.add_theme_constant_override("separation", 18)

	var lane_list := _lane_entries()
	for i in lane_list.size():
		lanes_row.add_child(_build_lane_separator())
		var lane = lane_list[i]
		var lane_id := str(lane.get("id", ""))
		var lane_panel := PanelContainer.new()
		lane_panel.name = "%s_lane_panel" % lane_id
		lane_panel.custom_minimum_size = Vector2(0, 252)
		lane_panel.size_flags_horizontal = SIZE_EXPAND_FILL
		lane_panel.size_flags_vertical = SIZE_EXPAND_FILL
		lane_panel.size_flags_stretch_ratio = 1.0
		_apply_panel_style(lane_panel, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
		lane_panel.gui_input.connect(_on_lane_panel_gui_input.bind(lane_id))
		lane_panel.mouse_entered.connect(_on_lane_mouse_entered.bind(lane_id))
		lane_panel.mouse_exited.connect(_on_lane_mouse_exited)
		lanes_row.add_child(lane_panel)
		_lane_panels[lane_id] = lane_panel
		var lane_box := _build_panel_box(lane_panel, 8, 10)

		for player_id in PLAYER_ORDER:
			var row_panel := PanelContainer.new()
			row_panel.name = "%s_%s_lane_row_panel" % [lane_id, player_id]
			row_panel.custom_minimum_size = Vector2(0, 352)
			row_panel.size_flags_horizontal = SIZE_EXPAND_FILL
			row_panel.size_flags_vertical = SIZE_EXPAND_FILL
			_apply_panel_style(row_panel, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
			row_panel.gui_input.connect(_on_lane_row_gui_input.bind(lane_id, player_id))
			lane_box.add_child(row_panel)
			_lane_row_panels[_lane_row_key(lane_id, player_id)] = row_panel
			var row_box := _build_panel_box(row_panel, 4, 6)
			# Let clicks on non-button children fall through to the row panel
			row_panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var row := HBoxContainer.new()
			row.name = "%s_%s_lane_row" % [lane_id, player_id]
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.size_flags_horizontal = SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 34)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_box.add_child(row)
			_lane_row_containers[_lane_row_key(lane_id, player_id)] = row

		# Lane icon at bottom of lane panel, centered
		var icon_center := CenterContainer.new()
		icon_center.name = "%s_lane_icon_center" % lane_id
		icon_center.size_flags_horizontal = SIZE_EXPAND_FILL
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane_box.add_child(icon_center)
		var icon_button := TextureRect.new()
		icon_button.name = "%s_lane_icon" % lane_id
		icon_button.custom_minimum_size = Vector2(28, 28)
		icon_button.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_button.modulate = Color.WHITE
		icon_button.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var icon_path := str(lane.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon_button.texture = load(icon_path)
		icon_button.mouse_entered.connect(_on_lane_icon_mouse_entered.bind(lane_id, icon_button))
		icon_button.mouse_exited.connect(_on_lane_icon_mouse_exited)
		icon_center.add_child(icon_button)
		_lane_icon_textures[lane_id] = icon_button

	lanes_row.add_child(_build_lane_separator())

	var banner_overlay := MarginContainer.new()
	banner_overlay.name = "TurnBannerOverlay"
	banner_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	banner_overlay.add_theme_constant_override("margin_left", 48)
	banner_overlay.add_theme_constant_override("margin_top", 24)
	banner_overlay.add_theme_constant_override("margin_right", 48)
	banner_overlay.add_theme_constant_override("margin_bottom", 24)
	banner_overlay.z_index = 40
	add_child(banner_overlay)
	var banner_center := CenterContainer.new()
	banner_center.size_flags_horizontal = SIZE_EXPAND_FILL
	banner_center.size_flags_vertical = SIZE_EXPAND_FILL
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_overlay.add_child(banner_center)
	_turn_banner_panel = PanelContainer.new()
	_turn_banner_panel.name = "TurnBannerPanel"
	_turn_banner_panel.visible = false
	_turn_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_banner_panel.custom_minimum_size = Vector2(336, 72)
	banner_center.add_child(_turn_banner_panel)
	var banner_box := _build_panel_box(_turn_banner_panel, 10, 16)
	var banner_column := VBoxContainer.new()
	banner_column.add_theme_constant_override("separation", 3)
	banner_box.add_child(banner_column)
	_turn_banner_label = Label.new()
	_turn_banner_label.name = "TurnBannerLabel"
	_turn_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner_label.add_theme_font_size_override("font_size", 28)
	banner_column.add_child(_turn_banner_label)
	_turn_banner_detail_label = Label.new()
	_turn_banner_detail_label.name = "TurnBannerDetailLabel"
	_turn_banner_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner_detail_label.add_theme_font_size_override("font_size", 13)
	banner_column.add_child(_turn_banner_detail_label)
	return lanes_row


func _build_lane_separator() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.45, 0.75, 0.8)
	sep.custom_minimum_size = Vector2(2, 0)
	sep.size_flags_vertical = SIZE_EXPAND_FILL
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep


func _build_read_only_text(tab_name: String) -> TextEdit:
	var text := TextEdit.new()
	text.name = tab_name
	text.editable = false
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.size_flags_vertical = SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 13)
	text.custom_minimum_size = Vector2(0, 0)
	return text


func _build_panel_box(panel: PanelContainer, separation: int = 12, padding: int = 16) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_bottom", padding)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color, border_width := 1, corner_radius := 10) -> void:
	panel.add_theme_stylebox_override("panel", _build_style_box(fill, border, border_width, corner_radius))


func _apply_button_style(button: Button, fill: Color, border: Color, font_color: Color, border_width := 1, corner_radius := 9) -> void:
	button.add_theme_stylebox_override("normal", _build_style_box(fill, border, border_width, corner_radius))
	button.add_theme_stylebox_override("hover", _build_style_box(fill.lightened(0.08), border.lightened(0.08), border_width, corner_radius))
	button.add_theme_stylebox_override("pressed", _build_style_box(fill.darkened(0.1), border, border_width, corner_radius))
	button.add_theme_stylebox_override("disabled", _build_style_box(fill.darkened(0.18), border.darkened(0.22), border_width, corner_radius))
	button.add_theme_stylebox_override("focus", _build_style_box(fill.lightened(0.04), border.lightened(0.12), border_width, corner_radius))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color.darkened(0.4))


func _apply_surface_button_style(button: Button, surface: String, hidden := false, selected := false, muted := false, interaction_state := "default", card: Dictionary = {}, locked := false) -> void:
	var fill := Color(0.17, 0.18, 0.22, 0.96)
	var border := Color(0.42, 0.44, 0.53, 0.9)
	var font_color := Color(0.95, 0.96, 0.98, 1.0)
	if hidden:
		fill = Color(0.11, 0.11, 0.14, 0.98)
		border = Color(0.3, 0.28, 0.22, 0.9)
	else:
		match surface:
			"lane":
				fill = Color(0.19, 0.16, 0.12, 0.98)
				border = Color(0.66, 0.54, 0.29, 0.94)
			"hand":
				fill = Color(0.14, 0.15, 0.2, 0.99)
				border = Color(0.45, 0.51, 0.68, 0.94)
			"support":
				fill = Color(0.14, 0.18, 0.18, 0.98)
				border = Color(0.35, 0.58, 0.56, 0.92)
				if bool(card.get("activation_used_this_turn", false)):
					fill = fill.darkened(0.3)
					border = border.darkened(0.2)
		if surface == "hand" and _is_pending_prophecy_card(card):
			fill = fill.lerp(Color(0.24, 0.12, 0.31, 0.99), 0.72)
			border = Color(0.93, 0.73, 0.98, 1.0)
			font_color = Color(1.0, 0.96, 1.0, 1.0)
		var draw_feedback := _active_draw_feedback_for_instance(str(card.get("instance_id", "")))
		if surface == "hand" and not hidden and not draw_feedback.is_empty():
			if bool(draw_feedback.get("from_rune_break", false)):
				fill = fill.lerp(Color(0.33, 0.16, 0.1, 0.99), 0.56)
				border = Color(1.0, 0.78, 0.46, 1.0)
			else:
				fill = fill.lerp(Color(0.16, 0.24, 0.31, 0.99), 0.48)
				border = Color(0.66, 0.9, 1.0, 1.0)
		if surface == "lane" and str(card.get("card_type", "")) == "creature":
			if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
				fill = fill.lerp(Color(0.31, 0.24, 0.14, 0.99), 0.46)
				border = border.lerp(Color(0.99, 0.85, 0.46, 1.0), 0.72)
			var readiness_state := _creature_readiness_state(card)
			match str(readiness_state.get("id", "")):
				"ready":
					fill = fill.lerp(Color(0.15, 0.24, 0.18, 0.99), 0.34)
					border = border.lerp(Color(0.62, 0.95, 0.64, 1.0), 0.54)
				"summoning_sick":
					fill = fill.lerp(Color(0.29, 0.16, 0.11, 0.99), 0.42)
					border = border.lerp(Color(0.96, 0.63, 0.34, 1.0), 0.58)
				"spent":
					fill = fill.darkened(0.08)
					border = border.lerp(Color(0.62, 0.67, 0.76, 0.96), 0.42)
				"disabled":
					fill = fill.lerp(Color(0.23, 0.14, 0.24, 0.99), 0.4)
					border = border.lerp(Color(0.82, 0.58, 0.94, 1.0), 0.54)
	if muted:
		fill = fill.darkened(0.18)
		border = border.darkened(0.12)
		font_color = Color(0.84, 0.84, 0.88, 0.96)
	if locked and interaction_state == "default" and not selected:
		fill = fill.darkened(0.26)
		border = border.darkened(0.18)
		font_color = font_color.lerp(Color(0.72, 0.74, 0.8, 0.92), 0.5)
	if interaction_state == "valid":
		fill = fill.lerp(Color(0.2, 0.31, 0.23, 0.98), 0.48)
		border = Color(0.74, 0.94, 0.68, 1.0)
	elif interaction_state == "valid_betray":
		fill = fill.lerp(Color(0.35, 0.12, 0.1, 0.98), 0.48)
		border = Color(0.95, 0.35, 0.25, 1.0)
	elif interaction_state == "invalid":
		fill = fill.lerp(Color(0.31, 0.12, 0.13, 0.99), 0.72)
		border = Color(0.98, 0.48, 0.44, 1.0)
	if selected:
		border = Color(0.98, 0.88, 0.58, 1.0)
		fill = fill.lightened(0.04)
	_apply_button_style(button, fill, border, font_color, 2 if selected else 1, 10 if surface == "hand" else 8)
	button.self_modulate = _locked_surface_modulate(locked, muted)


func _apply_lane_panel_style(panel: PanelContainer, lane_id: String) -> void:
	if panel == null:
		return
	_apply_panel_style(panel, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 12)


func _apply_lane_header_style(button: Button, lane_id: String) -> void:
	if button == null:
		return
	var fill := _lane_header_fill(lane_id)
	var border := _lane_panel_border(lane_id)
	_apply_button_style(button, fill, border, Color(0.96, 0.95, 0.9, 1.0), 1, 10)


func _apply_lane_row_panel_style(panel: PanelContainer, lane_id: String, player_id: String) -> void:
	if panel == null:
		return
	var border := Color(0, 0, 0, 0)
	var border_width := 0
	var interaction_state := _lane_row_interaction_state(lane_id, player_id)
	if interaction_state == "valid":
		border = Color(0.74, 0.94, 0.68, 1.0)
		border_width = 2
	elif interaction_state == "invalid":
		border = Color(0.98, 0.48, 0.44, 1.0)
		border_width = 2
	_apply_panel_style(panel, Color(0, 0, 0, 0), border, border_width, 10)




func _locked_surface_modulate(locked: bool, muted: bool) -> Color:
	if locked:
		return Color(0.78, 0.8, 0.88, 0.64)
	if muted:
		return Color(0.74, 0.74, 0.78, 0.72)
	return Color(1, 1, 1, 1)


func _build_style_box(fill: Color, border: Color, border_width := 1, corner_radius := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	return style


func _lane_panel_fill(lane_id: String) -> Color:
	return Color(0.1, 0.1, 0.15, 0.98) if lane_id == "shadow" else Color(0.17, 0.17, 0.18, 0.97)


func _lane_panel_border(lane_id: String) -> Color:
	return Color(0.42, 0.41, 0.61, 0.94) if lane_id == "shadow" else Color(0.53, 0.54, 0.48, 0.9)


func _lane_row_fill(lane_id: String) -> Color:
	return Color(0.13, 0.13, 0.17, 0.94) if lane_id == "shadow" else Color(0.21, 0.21, 0.22, 0.92)


func _lane_row_border(lane_id: String) -> Color:
	return Color(0.29, 0.31, 0.45, 0.88) if lane_id == "shadow" else Color(0.34, 0.35, 0.34, 0.82)


func _lane_header_fill(lane_id: String) -> Color:
	return Color(0.16, 0.15, 0.23, 0.98) if lane_id == "shadow" else Color(0.23, 0.22, 0.18, 0.98)


func _lane_marker_text(lane_id: String) -> String:
	return "SHADOW • Cover on entry" if lane_id == "shadow" else "FIELD • Open battle"


func _lane_marker_color(lane_id: String) -> Color:
	return Color(0.82, 0.8, 0.98, 0.96) if lane_id == "shadow" else Color(0.9, 0.88, 0.74, 0.96)



func _refresh_ui() -> void:
	_prune_feedback_state()
	_clear_lane_card_hover_preview()
	_clear_support_card_hover_preview()
	_card_buttons = {}
	_lane_slot_buttons = {}
	_refresh_turn_presentation()
	_refresh_prophecy_overlay()
	_refresh_discard_choice_overlay()
	_refresh_consume_selection_overlay()
	_refresh_deck_selection_overlay()
	_refresh_player_choice_overlay()
	_refresh_hand_selection_state()
	_refresh_top_deck_choice_state()
	_refresh_player_sections()
	_refresh_lanes()
	_apply_match_layout_scale()
	_refresh_end_turn_button()
	_refresh_match_end_overlay()
	_scan_and_refresh_match_history()
	_apply_presentation_feedback()
	if not _detached_card_state.is_empty():
		var detached_id: String = str(_detached_card_state.get("instance_id", ""))
		var detached_button: Button = _card_buttons.get(detached_id)
		if detached_button != null:
			detached_button.visible = false
		elif not _has_active_prophecy_overlay(detached_id):
			_cancel_detached_card_silent()
	if not _targeting_arrow_state.is_empty():
		var arrow_id: String = str(_targeting_arrow_state.get("instance_id", ""))
		var arrow_button: Button = _card_buttons.get(arrow_id)
		var summon_source_id := str(_pending_summon_target.get("source_instance_id", ""))
		var is_pending_summon_source := arrow_id == summon_source_id and not summon_source_id.is_empty()
		if arrow_button != null:
			if not is_pending_summon_source:
				arrow_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif not is_pending_summon_source and not _has_active_prophecy_overlay(arrow_id):
			_cancel_targeting_mode_silent()
	_pending_layout_scale_frames = 2
	_process_overdraw_queue()


func _apply_match_layout_scale() -> void:
	var layout := find_child("MatchLayout", true, false) as Control
	var content := find_child("MatchContent", true, false) as Control
	if layout == null or content == null:
		return
	content.pivot_offset = Vector2.ZERO
	content.scale = Vector2.ONE
	var window = get_tree().root
	var layout_size := Vector2(window.size) if window != null else Vector2.ZERO
	if layout_size.x <= 0.0 or layout_size.y <= 0.0:
		layout_size = size if size.x > 0.0 and size.y > 0.0 else layout.size
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		layout_size = Vector2(minf(layout_size.x, viewport_size.x), minf(layout_size.y, viewport_size.y))
	var available: Vector2 = layout_size - Vector2(48, 44)
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var needed: Vector2 = content.get_combined_minimum_size()
	if needed.x <= 0.0 or needed.y <= 0.0:
		return
	var scale_factor: float = min(1.0, min(available.x / needed.x, available.y / needed.y))
	content.scale = Vector2(scale_factor, scale_factor)


func _refresh_player_sections() -> void:
	for player_id in PLAYER_ORDER:
		var section: Dictionary = _player_sections.get(player_id, {})
		var player := _player_state(player_id)
		if section.is_empty() or player.is_empty():
			continue
		var is_opponent: bool = player_id == PLAYER_ORDER[0]
		var panel: PanelContainer = section["panel"]
		panel.self_modulate = Color(0.82, 0.84, 0.9, 0.78) if _should_dim_local_surface(player_id) else Color(1, 1, 1, 1)
		var avatar_component = section.get("avatar_component")
		if avatar_component != null:
			avatar_component.apply_player_state(player, is_opponent)
			_refresh_avatar_target_glow(avatar_component, player_id)

		var magicka_component = section.get("magicka_component")
		if magicka_component != null:
			magicka_component.apply_player_state(player)

		var ring_panel: PanelContainer = section["ring_panel"]
		ring_panel.visible = bool(player.get("has_ring_of_magicka", false))
		var ring_label: Label = section["ring_label"]
		ring_label.text = _ring_panel_text(player)
		var ring_used_this_turn := bool(player.get("ring_of_magicka_used_this_turn", false))
		if ring_used_this_turn:
			_apply_panel_style(ring_panel, Color(0.14, 0.14, 0.14, 0.96), Color(0.35, 0.35, 0.35, 0.94), 1, 10)
			ring_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
		else:
			_apply_panel_style(ring_panel, Color(0.18, 0.14, 0.08, 0.96), Color(0.63, 0.53, 0.26, 0.94), 1, 10)
			ring_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78, 1.0))
		var ring_row: HBoxContainer = section["ring_row"]
		_refresh_ring_row(ring_row, player)

		var deck_button: Button = section["deck_button"]
		deck_button.text = _pile_button_text("Deck", player.get("deck", []).size())
		deck_button.tooltip_text = _pile_button_tooltip(player, MatchMutations.ZONE_DECK)

		var discard_button: Button = section["discard_button"]
		discard_button.text = _pile_button_text("Discard", player.get("discard", []).size())
		discard_button.tooltip_text = _pile_button_tooltip(player, MatchMutations.ZONE_DISCARD)

		var support_row: HBoxContainer = section["support_row"]
		_clear_children(support_row)
		for support in player.get("support", []):
			support_row.add_child(_build_card_button(support, true, "support"))

		var hand_row: Control = section["hand_row"]
		_clear_children(hand_row)
		var hand_public := _is_hand_public(player_id)
		for card in player.get("hand", []):
			if _has_active_prophecy_overlay(str(card.get("instance_id", ""))):
				continue
			hand_row.add_child(_build_card_button(card, hand_public, "hand"))
		if hand_row.get_child_count() == 0:
			var placeholder := _build_placeholder_label("Hand empty")
			hand_row.add_child(placeholder)
			_layout_hand_placeholder(hand_row, placeholder)
		else:
			_layout_hand_cards(hand_row, player_id)


func _refresh_lanes() -> void:
	_clear_insertion_preview(false)
	# Reset sacrifice hover since lane buttons are being rebuilt
	_sacrifice_hover_target_id = ""
	if _sacrifice_hover_label != null and is_instance_valid(_sacrifice_hover_label):
		_sacrifice_hover_label.queue_free()
	_sacrifice_hover_label = null
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var lane_panel: PanelContainer = _lane_panels.get(lane_id)
		_apply_lane_panel_style(lane_panel, lane_id)
		var capacity := _lane_slot_capacity(lane_id)
		if capacity > 0 and lane_panel != null:
			lane_panel.size_flags_stretch_ratio = float(capacity)
		var header: Button = _lane_header_buttons.get(lane_id)
		if header != null:
			header.text = _lane_header_text(lane_id)
			header.tooltip_text = _lane_description(lane_id)
			_apply_lane_header_style(header, lane_id)
		var icon_tex: TextureRect = _lane_icon_textures.get(lane_id)
		if icon_tex != null:
			var icon_path := str(lane.get("icon", ""))
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				icon_tex.texture = load(icon_path)
			else:
				icon_tex.texture = null
		for player_id in PLAYER_ORDER:
			var row_panel: PanelContainer = _lane_row_panels.get(_lane_row_key(lane_id, player_id))
			_apply_lane_row_panel_style(row_panel, lane_id, player_id)
			var row: HBoxContainer = _lane_row_containers.get(_lane_row_key(lane_id, player_id))
			if row == null:
				continue
			_clear_children(row)
			var slots := _lane_slots(lane_id, player_id)
			for card in slots:
				if typeof(card) == TYPE_DICTIONARY:
					row.add_child(_build_card_button(card, true, "lane"))


func _refresh_prophecy_overlay() -> void:
	var has_prophecy := MatchTiming.has_pending_prophecy(_match_state)
	var overlay_active := not _prophecy_overlay_state.is_empty()
	if has_prophecy and not overlay_active:
		var windows := MatchTiming.get_pending_prophecies(_match_state)
		if not windows.is_empty():
			var window: Dictionary = windows[0]
			var instance_id := str(window.get("instance_id", ""))
			var player_id := str(window.get("player_id", ""))
			if player_id == _local_player_id():
				_show_local_prophecy_overlay(instance_id)
			else:
				_show_enemy_prophecy_overlay(instance_id)
	elif not has_prophecy and overlay_active:
		var phase: String = str(_prophecy_overlay_state.get("phase", ""))
		if phase != "animating":
			_dismiss_prophecy_overlay()


func _show_local_prophecy_overlay(instance_id: String) -> void:
	_dismiss_prophecy_overlay()
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size
	var hand_top_y := viewport_size.y - card_size.y * 0.35

	var vbox := VBoxContainer.new()
	vbox.name = "prophecy_local_vbox"
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_END

	var card_wrapper := Control.new()
	card_wrapper.name = "prophecy_card_wrapper"
	card_wrapper.custom_minimum_size = card_size
	card_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	card_wrapper.add_child(component)
	vbox.add_child(card_wrapper)

	var button_row := HBoxContainer.new()
	button_row.name = "prophecy_button_row"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)

	var play_button := Button.new()
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(card_size.x * 0.45, 46)
	play_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(play_button, Color(0.21, 0.12, 0.29, 0.99), Color(0.92, 0.72, 0.98, 1.0), Color(0.99, 0.96, 1.0, 1.0), 2, 10)
	play_button.pressed.connect(_on_prophecy_play_pressed.bind(instance_id))
	button_row.add_child(play_button)

	var local_id := _local_player_id()
	var local_player := {}
	for p in _match_state.get("players", []):
		if str(p.get("player_id", "")) == local_id:
			local_player = p
			break
	var hand_full: bool = local_player.get("hand", []).size() > MatchTiming.MAX_HAND_SIZE

	var keep_button := Button.new()
	keep_button.text = "Discard" if hand_full else "Keep"
	keep_button.custom_minimum_size = Vector2(card_size.x * 0.45, 46)
	keep_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(keep_button, Color(0.22, 0.11, 0.14, 0.98), Color(0.78, 0.45, 0.47, 0.96), Color(0.99, 0.95, 0.95, 1.0), 1, 10)
	keep_button.pressed.connect(_on_prophecy_keep_pressed.bind(instance_id))
	button_row.add_child(keep_button)

	vbox.add_child(button_row)

	var total_height := card_size.y + 12.0 + 46.0
	var top_y := hand_top_y - total_height - 16.0
	vbox.position = Vector2((viewport_size.x - card_size.x) * 0.5, top_y)
	vbox.size = Vector2(card_size.x, total_height)

	_prophecy_card_overlay.add_child(vbox)
	_prophecy_overlay_state = {
		"instance_id": instance_id,
		"player_id": _local_player_id(),
		"is_local": true,
		"vbox": vbox,
		"card_wrapper": card_wrapper,
		"component": component,
		"phase": "active",
	}
	_selected_instance_id = instance_id


func _show_enemy_prophecy_overlay(instance_id: String) -> void:
	_dismiss_prophecy_overlay()
	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "prophecy_enemy_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x := (viewport_size.x - card_size.x) * 0.5
	var pos_y := viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_prophecy_card_overlay.add_child(card_back)
	_prophecy_overlay_state = {
		"instance_id": instance_id,
		"player_id": _pending_prophecy_player_id(instance_id),
		"is_local": false,
		"card_back": card_back,
		"phase": "active",
	}


func _dismiss_prophecy_overlay() -> void:
	if _prophecy_overlay_state.is_empty():
		return
	var vbox: Control = _prophecy_overlay_state.get("vbox")
	if vbox != null and is_instance_valid(vbox):
		vbox.queue_free()
	var card_back: Control = _prophecy_overlay_state.get("card_back")
	if card_back != null and is_instance_valid(card_back):
		card_back.queue_free()
	_prophecy_overlay_state = {}


func _has_active_prophecy_overlay(instance_id: String) -> bool:
	if _prophecy_overlay_state.is_empty():
		return false
	return str(_prophecy_overlay_state.get("instance_id", "")) == instance_id


func _show_mulligan_overlay() -> void:
	_dismiss_mulligan_overlay()
	_mulligan_marked_ids = []
	var local_id := _local_player_id()
	var player := {}
	for p in _match_state.get("players", []):
		if str(p.get("player_id", "")) == local_id:
			player = p
			break
	var hand: Array = player.get("hand", [])
	if hand.is_empty():
		_finalize_mulligan([])
		return

	var overlay := Control.new()
	overlay.name = "MulliganOverlay"
	overlay.z_index = 460
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.name = "MulliganBackground"
	bg.color = Color(0.04, 0.05, 0.07, 0.82)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.name = "MulliganCenter"
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "MulliganVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(vbox)

	var going_first := not bool(player.get("has_ring_of_magicka", false))
	var turn_order_label := Label.new()
	turn_order_label.text = "You are playing first" if going_first else "You are playing second"
	turn_order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_order_label.add_theme_font_size_override("font_size", 20)
	turn_order_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58, 0.9))
	vbox.add_child(turn_order_label)

	var title_label := Label.new()
	title_label.text = "Choose cards to replace"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1.0))
	vbox.add_child(title_label)

	var card_row := HBoxContainer.new()
	card_row.name = "MulliganCardRow"
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 16)
	card_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(card_row)

	var card_size := _hand_card_display_size()
	var card_buttons_map := {}
	var x_labels_map := {}
	_mulligan_instance_id_order = []

	for card in hand:
		var instance_id := str(card.get("instance_id", ""))
		var card_button := Button.new()
		card_button.name = "MulliganCard_%s" % instance_id
		card_button.custom_minimum_size = card_size
		card_button.mouse_filter = Control.MOUSE_FILTER_STOP
		var empty_style := StyleBoxEmpty.new()
		card_button.add_theme_stylebox_override("normal", empty_style)
		card_button.add_theme_stylebox_override("hover", empty_style)
		card_button.add_theme_stylebox_override("pressed", empty_style)
		card_button.add_theme_stylebox_override("focus", empty_style)

		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_button.add_child(component)

		var x_label := Label.new()
		x_label.name = "XMark"
		x_label.text = "X"
		x_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		x_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		x_label.add_theme_font_size_override("font_size", 48)
		x_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.2, 0.92))
		x_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x_label.visible = false
		card_button.add_child(x_label)

		card_button.pressed.connect(_on_mulligan_card_toggled.bind(instance_id))
		card_row.add_child(card_button)
		card_buttons_map[instance_id] = card_button
		x_labels_map[instance_id] = x_label
		_mulligan_instance_id_order.append(instance_id)

	var continue_button := Button.new()
	continue_button.name = "MulliganContinue"
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(180, 50)
	continue_button.add_theme_font_size_override("font_size", 20)
	_apply_button_style(continue_button, Color(0.28, 0.22, 0.08, 0.98), Color(0.78, 0.65, 0.22, 0.96), Color(0.98, 0.93, 0.82, 1.0), 2, 10)
	continue_button.pressed.connect(_on_mulligan_confirm_pressed)
	vbox.add_child(continue_button)

	add_child(overlay)
	_mulligan_overlay_state = {
		"overlay": overlay,
		"card_buttons": card_buttons_map,
		"x_labels": x_labels_map,
	}


func _on_mulligan_card_toggled(instance_id: String) -> void:
	if _mulligan_overlay_state.is_empty():
		return
	var idx := _mulligan_marked_ids.find(instance_id)
	if idx >= 0:
		_mulligan_marked_ids.remove_at(idx)
	else:
		_mulligan_marked_ids.append(instance_id)
	var x_labels: Dictionary = _mulligan_overlay_state.get("x_labels", {})
	var x_label: Label = x_labels.get(instance_id)
	if x_label != null:
		x_label.visible = _mulligan_marked_ids.has(instance_id)


func _on_mulligan_confirm_pressed() -> void:
	if _mulligan_overlay_state.is_empty():
		return
	var discard_ids := _mulligan_marked_ids.duplicate()
	_dismiss_mulligan_overlay()
	_finalize_mulligan(discard_ids)


func _dismiss_mulligan_overlay() -> void:
	if _mulligan_overlay_state.is_empty():
		return
	var overlay: Control = _mulligan_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_mulligan_overlay_state = {}
	_mulligan_marked_ids = []
	_mulligan_instance_id_order = []


func _finalize_mulligan(discard_instance_ids: Array) -> void:
	MatchBootstrap.apply_mulligan(_match_state, _local_player_id(), discard_instance_ids)
	_hydrate_match_cards(_match_state, _mulligan_card_by_id)
	# Re-apply augments after hydration so stat bonuses aren't overwritten
	if not _adventure_augments.is_empty():
		_apply_adventure_augments(_match_state, PLAYER_ORDER[1])
	GameLogger.start_match(_match_state)
	MatchTurnLoop.begin_first_turn(_match_state)
	_ai_enabled = true
	if not _is_local_player_turn():
		_schedule_local_match_ai_step(2000)
	_mulligan_card_by_id = {}
	var scenario_events := _recent_presentation_events_from_history()
	_record_feedback_from_events(scenario_events)
	_status_message = "Match started."
	_refresh_ui()
	if _arena_mode:
		match_state_changed.emit(_match_state.duplicate(true))


func _show_discard_viewer(player_id: String) -> void:
	_dismiss_discard_viewer()
	var player := _player_state(player_id)
	if player.is_empty():
		return
	var discard_pile: Array = player.get("discard", [])
	if discard_pile.is_empty():
		_status_message = "%s's discard pile is empty." % _player_name(player_id)
		_refresh_ui()
		return

	var overlay := Control.new()
	overlay.name = "DiscardViewerOverlay"
	overlay.z_index = 460
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 0.85)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 14)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "%s's Discard Pile (%d)" % [_player_name(player_id), discard_pile.size()]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1.0))
	vbox.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)

	var card_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(get_viewport_rect().size.x - 120) / int(card_size.x + 10))
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(grid)

	for card in discard_pile:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var card_wrapper := PanelContainer.new()
		card_wrapper.custom_minimum_size = card_size
		var wrapper_style := StyleBoxFlat.new()
		wrapper_style.bg_color = Color(0.12, 0.11, 0.14, 0.95)
		wrapper_style.corner_radius_top_left = 6
		wrapper_style.corner_radius_top_right = 6
		wrapper_style.corner_radius_bottom_left = 6
		wrapper_style.corner_radius_bottom_right = 6
		card_wrapper.add_theme_stylebox_override("panel", wrapper_style)

		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_wrapper.add_child(component)
		grid.add_child(card_wrapper)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(160, 44)
	close_button.add_theme_font_size_override("font_size", 18)
	_apply_button_style(close_button, Color(0.2, 0.12, 0.16, 0.98), Color(0.58, 0.32, 0.39, 0.94), Color(0.97, 0.92, 0.94, 1.0), 1, 10)
	close_button.pressed.connect(_dismiss_discard_viewer)
	close_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	vbox.add_child(close_button)

	add_child(overlay)
	_discard_viewer_state = {"overlay": overlay}
	_status_message = "Viewing %s's discard pile." % _player_name(player_id)


func _dismiss_discard_viewer() -> void:
	if _discard_viewer_state.is_empty():
		return
	var overlay: Control = _discard_viewer_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_discard_viewer_state = {}


func _has_local_pending_discard_choice() -> bool:
	return MatchTiming.has_pending_discard_choice(_match_state, _local_player_id())


func _refresh_discard_choice_overlay() -> void:
	var has_choice := _has_local_pending_discard_choice()
	var overlay_active := not _discard_choice_overlay_state.is_empty()
	if has_choice and not overlay_active:
		_show_discard_choice_overlay()
	elif not has_choice and overlay_active:
		_dismiss_discard_choice_overlay()


func _show_discard_choice_overlay() -> void:
	_dismiss_discard_choice_overlay()
	_dismiss_discard_viewer()
	var local_id := _local_player_id()
	var choice := MatchTiming.get_pending_discard_choice(_match_state, local_id)
	if choice.is_empty():
		return
	var candidate_ids: Array = choice.get("candidate_instance_ids", [])
	if candidate_ids.is_empty():
		MatchTiming.decline_pending_discard_choice(_match_state, local_id)
		_refresh_ui()
		return

	var player := _player_state(local_id)
	if player.is_empty():
		return
	var discard_pile: Array = player.get("discard", [])
	var candidate_cards: Array = []
	for card in discard_pile:
		if typeof(card) == TYPE_DICTIONARY and candidate_ids.has(str(card.get("instance_id", ""))):
			candidate_cards.append(card)

	var overlay := Control.new()
	overlay.name = "DiscardChoiceOverlay"
	overlay.z_index = 470
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 0.88)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 14)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	var buff_power := int(choice.get("buff_power", 0))
	var buff_health := int(choice.get("buff_health", 0))
	var title_text := "Choose a creature from your discard pile"
	if buff_power > 0 or buff_health > 0:
		title_text += " (+%d/+%d)" % [buff_power, buff_health]
	var title_label := Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1.0))
	vbox.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)

	var card_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(get_viewport_rect().size.x - 120) / int(card_size.x + 10))
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(grid)

	for card in candidate_cards:
		var instance_id := str(card.get("instance_id", ""))
		var card_button := Button.new()
		card_button.name = "DiscardChoice_%s" % instance_id
		card_button.custom_minimum_size = card_size
		var empty_style := StyleBoxEmpty.new()
		card_button.add_theme_stylebox_override("normal", empty_style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.3, 0.25, 0.1, 0.6)
		hover_style.corner_radius_top_left = 6
		hover_style.corner_radius_top_right = 6
		hover_style.corner_radius_bottom_left = 6
		hover_style.corner_radius_bottom_right = 6
		card_button.add_theme_stylebox_override("hover", hover_style)
		card_button.add_theme_stylebox_override("pressed", empty_style)
		card_button.add_theme_stylebox_override("focus", empty_style)

		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_button.add_child(component)

		card_button.pressed.connect(_on_discard_choice_selected.bind(instance_id))
		grid.add_child(card_button)

	add_child(overlay)
	_discard_choice_overlay_state = {"overlay": overlay}
	_status_message = title_text


func _on_discard_choice_selected(instance_id: String) -> void:
	if _discard_choice_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_pending_discard_choice(_match_state, local_id, instance_id)
	_dismiss_discard_choice_overlay()
	if bool(result.get("is_valid", false)):
		var card_name := str(result.get("card", {}).get("name", instance_id))
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = "Drew %s from discard pile." % card_name
	else:
		_status_message = str(result.get("errors", ["Failed to resolve discard choice."])[0])
	_refresh_ui()


func _dismiss_discard_choice_overlay() -> void:
	if _discard_choice_overlay_state.is_empty():
		return
	var overlay: Control = _discard_choice_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_discard_choice_overlay_state = {}


# --- Deck selection overlay ---


var _deck_selection_overlay_state := {}


func _has_local_pending_deck_selection() -> bool:
	return MatchTiming.has_pending_deck_selection(_match_state, _local_player_id())


func _refresh_deck_selection_overlay() -> void:
	var has_selection := _has_local_pending_deck_selection()
	var overlay_active := not _deck_selection_overlay_state.is_empty()
	if has_selection and not overlay_active:
		_show_deck_selection_overlay()
	elif not has_selection and overlay_active:
		_dismiss_deck_selection_overlay()


func _show_deck_selection_overlay() -> void:
	_dismiss_deck_selection_overlay()
	_dismiss_discard_viewer()
	var local_id := _local_player_id()
	var selection := MatchTiming.get_pending_deck_selection(_match_state, local_id)
	if selection.is_empty():
		return
	var candidate_ids: Array = selection.get("candidate_instance_ids", [])
	if candidate_ids.is_empty():
		MatchTiming.decline_pending_deck_selection(_match_state, local_id)
		_refresh_ui()
		return

	var player := _player_state(local_id)
	if player.is_empty():
		return
	var deck_pile: Array = player.get("deck", [])
	var candidate_cards: Array = []
	for card in deck_pile:
		if typeof(card) == TYPE_DICTIONARY and candidate_ids.has(str(card.get("instance_id", ""))):
			candidate_cards.append(card)

	var overlay := Control.new()
	overlay.name = "DeckSelectionOverlay"
	overlay.z_index = 470
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.1, 0.88)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 14)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	var prompt_text := str(selection.get("prompt", "Choose a card from your deck."))
	var title_label := Label.new()
	title_label.text = prompt_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1.0))
	vbox.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)

	var card_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(get_viewport_rect().size.x - 120) / int(card_size.x + 10))
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(grid)

	for card in candidate_cards:
		var instance_id := str(card.get("instance_id", ""))
		var card_button := Button.new()
		card_button.name = "DeckChoice_%s" % instance_id
		card_button.custom_minimum_size = card_size
		var empty_style := StyleBoxEmpty.new()
		card_button.add_theme_stylebox_override("normal", empty_style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.15, 0.3, 0.5, 0.6)
		hover_style.corner_radius_top_left = 6
		hover_style.corner_radius_top_right = 6
		hover_style.corner_radius_bottom_left = 6
		hover_style.corner_radius_bottom_right = 6
		card_button.add_theme_stylebox_override("hover", hover_style)
		card_button.add_theme_stylebox_override("pressed", empty_style)
		card_button.add_theme_stylebox_override("focus", empty_style)

		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_button.add_child(component)

		card_button.pressed.connect(_on_deck_selection_chosen.bind(instance_id))
		grid.add_child(card_button)

	# Add skip button
	var skip_button := Button.new()
	skip_button.text = "Skip (Escape)"
	skip_button.custom_minimum_size = Vector2(160, 40)
	skip_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	skip_button.pressed.connect(_on_deck_selection_declined)
	vbox.add_child(skip_button)

	add_child(overlay)
	_deck_selection_overlay_state = {"overlay": overlay}
	_status_message = prompt_text


func _on_deck_selection_chosen(instance_id: String) -> void:
	if _deck_selection_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_pending_deck_selection(_match_state, local_id, instance_id)
	_dismiss_deck_selection_overlay()
	if bool(result.get("is_valid", false)):
		var card_name := str(result.get("card", {}).get("name", instance_id))
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = "Selected %s from deck." % card_name
	else:
		_status_message = str(result.get("errors", ["Failed to resolve deck selection."])[0])
	_refresh_ui()


func _on_deck_selection_declined() -> void:
	if _deck_selection_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	MatchTiming.decline_pending_deck_selection(_match_state, local_id)
	_dismiss_deck_selection_overlay()
	_status_message = "Selection declined."
	_refresh_ui()


func _dismiss_deck_selection_overlay() -> void:
	if _deck_selection_overlay_state.is_empty():
		return
	var overlay: Control = _deck_selection_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_deck_selection_overlay_state = {}


# --- Consume selection overlay ---


func _has_local_pending_consume_selection() -> bool:
	return MatchTiming.has_pending_consume_selection(_match_state, _local_player_id())


func _refresh_consume_selection_overlay() -> void:
	var has_selection := _has_local_pending_consume_selection()
	var overlay_active := not _consume_selection_overlay_state.is_empty()
	if has_selection and not overlay_active:
		_show_consume_selection_overlay()
	elif not has_selection and overlay_active:
		_dismiss_consume_selection_overlay()


func _show_consume_selection_overlay() -> void:
	_dismiss_consume_selection_overlay()
	_dismiss_discard_viewer()
	var local_id := _local_player_id()
	var selection := MatchTiming.get_pending_consume_selection(_match_state, local_id)
	if selection.is_empty():
		return
	var candidate_ids: Array = selection.get("candidate_instance_ids", [])
	if candidate_ids.is_empty():
		MatchTiming.decline_consume_selection(_match_state, local_id)
		_refresh_ui()
		return

	var player := _player_state(local_id)
	if player.is_empty():
		return
	var discard_pile: Array = player.get("discard", [])
	var candidate_cards: Array = []
	for card in discard_pile:
		if typeof(card) == TYPE_DICTIONARY and candidate_ids.has(str(card.get("instance_id", ""))):
			candidate_cards.append(card)

	var overlay := Control.new()
	overlay.name = "ConsumeSelectionOverlay"
	overlay.z_index = 470
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.03, 0.1, 0.88)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 14)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Choose a creature to Consume"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.95, 1.0))
	vbox.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)

	var card_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(get_viewport_rect().size.x - 120) / int(card_size.x + 10))
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(grid)

	for card in candidate_cards:
		var instance_id := str(card.get("instance_id", ""))
		var card_button := Button.new()
		card_button.name = "ConsumeChoice_%s" % instance_id
		card_button.custom_minimum_size = card_size
		var empty_style := StyleBoxEmpty.new()
		card_button.add_theme_stylebox_override("normal", empty_style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.4, 0.2, 0.5, 0.6)
		hover_style.corner_radius_top_left = 6
		hover_style.corner_radius_top_right = 6
		hover_style.corner_radius_bottom_left = 6
		hover_style.corner_radius_bottom_right = 6
		card_button.add_theme_stylebox_override("hover", hover_style)
		card_button.add_theme_stylebox_override("pressed", empty_style)
		card_button.add_theme_stylebox_override("focus", empty_style)

		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_button.add_child(component)

		card_button.pressed.connect(_on_consume_selection_chosen.bind(instance_id))
		grid.add_child(card_button)

	# Add skip button
	var skip_button := Button.new()
	skip_button.text = "Skip (Escape)"
	skip_button.custom_minimum_size = Vector2(160, 40)
	skip_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	skip_button.pressed.connect(_on_consume_selection_declined)
	vbox.add_child(skip_button)

	add_child(overlay)
	_consume_selection_overlay_state = {"overlay": overlay}
	_status_message = "Choose a creature to Consume"


func _on_consume_selection_chosen(instance_id: String) -> void:
	if _consume_selection_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_consume_selection(_match_state, local_id, instance_id)
	_dismiss_consume_selection_overlay()
	if bool(result.get("is_valid", false)):
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = "Creature consumed."
		# Check if consume chained into target mode selection
		_check_pending_summon_effect_target()
		_check_pending_forced_play()
	else:
		_status_message = str(result.get("errors", ["Failed to resolve consume selection."])[0])
	_refresh_ui()


func _on_consume_selection_declined() -> void:
	if _consume_selection_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	MatchTiming.decline_consume_selection(_match_state, local_id)
	_dismiss_consume_selection_overlay()
	_status_message = "Consume declined."
	_refresh_ui()


func _dismiss_consume_selection_overlay() -> void:
	if _consume_selection_overlay_state.is_empty():
		return
	var overlay: Control = _consume_selection_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_consume_selection_overlay_state = {}


# --- Player choice overlay ---


var _player_choice_overlay_state := {}


func _has_local_pending_player_choice() -> bool:
	return MatchTiming.has_pending_player_choice(_match_state, _local_player_id())


func _refresh_player_choice_overlay() -> void:
	var has_choice := _has_local_pending_player_choice()
	var overlay_active := not _player_choice_overlay_state.is_empty()
	if has_choice and not overlay_active:
		_show_player_choice_overlay()
	elif not has_choice and overlay_active:
		_dismiss_player_choice_overlay()


func _show_player_choice_overlay() -> void:
	_dismiss_player_choice_overlay()
	var choice := MatchTiming.get_pending_player_choice(_match_state, _local_player_id())
	if choice.is_empty():
		return
	var prompt := str(choice.get("prompt", "Choose one:"))
	var mode := str(choice.get("mode", "text"))
	var options: Array = choice.get("options", [])
	if options.is_empty():
		return

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 480

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.07, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = prompt
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1.0))
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	for oi in range(options.size()):
		var raw_option = options[oi]
		var option: Dictionary = raw_option if typeof(raw_option) == TYPE_DICTIONARY else {}
		var label := str(raw_option) if typeof(raw_option) == TYPE_STRING else str(option.get("label", "Option %d" % (oi + 1)))
		var description := str(option.get("description", ""))

		if mode == "card" and option.has("card"):
			var card_button := Button.new()
			card_button.custom_minimum_size = CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
			var card_display = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
			card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_button.add_child(card_display)
			card_display.apply_card(option["card"], CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
			_apply_button_style(card_button, Color(0.12, 0.13, 0.17, 0.95), Color(0.4, 0.38, 0.5, 0.8), Color.WHITE)
			var idx := oi
			card_button.pressed.connect(func(): _on_player_choice_selected(idx))
			hbox.add_child(card_button)
		else:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(180, 80)
			var btn_vbox := VBoxContainer.new()
			btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var btn_label := Label.new()
			btn_label.text = label
			btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_label.add_theme_font_size_override("font_size", 18)
			btn_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82, 1.0))
			btn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_vbox.add_child(btn_label)
			if not description.is_empty():
				var desc_label := Label.new()
				desc_label.text = description
				desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				desc_label.add_theme_font_size_override("font_size", 13)
				desc_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65, 0.9))
				desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn_vbox.add_child(desc_label)
			btn.add_child(btn_vbox)
			_apply_button_style(btn, Color(0.15, 0.14, 0.2, 0.95), Color(0.5, 0.45, 0.55, 0.8), Color.WHITE)
			var idx := oi
			btn.pressed.connect(func(): _on_player_choice_selected(idx))
			hbox.add_child(btn)

	add_child(overlay)
	_player_choice_overlay_state = {"overlay": overlay}


func _on_player_choice_selected(index: int) -> void:
	if _player_choice_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	_dismiss_player_choice_overlay()
	var result := MatchTiming.resolve_pending_player_choice(_match_state, local_id, index)
	if bool(result.get("is_valid", false)):
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		_refresh_ui()


func _dismiss_player_choice_overlay() -> void:
	if _player_choice_overlay_state.is_empty():
		return
	var overlay: Control = _player_choice_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_player_choice_overlay_state = {}


# --- Hand selection mechanic ---


func _has_local_pending_hand_selection() -> bool:
	return MatchTiming.has_pending_hand_selection(_match_state, _local_player_id())


func _refresh_hand_selection_state() -> void:
	var has_selection := _has_local_pending_hand_selection()
	var state_active := not _hand_selection_state.is_empty()
	if has_selection and not state_active:
		_enter_hand_selection_mode()
	elif not has_selection and state_active:
		_exit_hand_selection_mode()


func _enter_hand_selection_mode() -> void:
	var local_id := _local_player_id()
	var selection := MatchTiming.get_pending_hand_selection(_match_state, local_id)
	if selection.is_empty():
		return
	var candidate_ids: Array = selection.get("candidate_instance_ids", [])
	if candidate_ids.is_empty():
		MatchTiming.decline_pending_hand_selection(_match_state, local_id)
		_refresh_ui()
		return
	_hand_selection_state = {
		"candidate_ids": candidate_ids,
		"source_instance_id": str(selection.get("source_instance_id", "")),
		"prompt": str(selection.get("prompt", "Choose a card from your hand.")),
	}
	_selected_instance_id = ""
	_status_message = str(_hand_selection_state.get("prompt", ""))


func _exit_hand_selection_mode() -> void:
	_hand_selection_state = {}


func _resolve_hand_selection(instance_id: String) -> void:
	if _hand_selection_state.is_empty():
		return
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_pending_hand_selection(_match_state, local_id, instance_id)
	_exit_hand_selection_mode()
	if bool(result.get("is_valid", false)):
		var card_name := str(result.get("card", {}).get("name", instance_id))
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = "Selected %s." % card_name
	else:
		_status_message = str(result.get("errors", ["Failed to resolve hand selection."])[0])
	_refresh_ui()


func _cancel_hand_selection() -> void:
	var local_id := _local_player_id()
	MatchTiming.decline_pending_hand_selection(_match_state, local_id)
	_exit_hand_selection_mode()
	_status_message = "Selection declined."
	_refresh_ui()


func _refresh_top_deck_choice_state() -> void:
	var has_choice := MatchTiming.has_pending_top_deck_choice(_match_state, _local_player_id())
	var state_active := not _top_deck_choice_state.is_empty()
	if has_choice and not state_active:
		_enter_top_deck_choice_mode()
	elif not has_choice and state_active:
		_exit_top_deck_choice_mode()


func _enter_top_deck_choice_mode() -> void:
	var local_id := _local_player_id()
	var choice := MatchTiming.get_pending_top_deck_choice(_match_state, local_id)
	if choice.is_empty():
		return
	var multi_cards: Array = choice.get("cards", [])
	if typeof(multi_cards) == TYPE_ARRAY and multi_cards.size() > 1:
		# Multi-card mode (look_draw_discard / look_give_draw)
		_top_deck_choice_state = {
			"multi_card": true,
			"cards": multi_cards,
			"mode": str(choice.get("mode", "")),
			"source_instance_id": str(choice.get("source_instance_id", "")),
		}
		_status_message = str(choice.get("prompt", "Choose a card."))
		_show_multi_card_choice_panel(multi_cards, str(choice.get("prompt", "Choose a card.")))
		return
	var revealed_card: Dictionary = choice.get("revealed_card", {})
	_top_deck_choice_state = {
		"revealed_card": revealed_card,
		"source_instance_id": str(choice.get("source_instance_id", "")),
	}
	_status_message = "Look at the top card of your deck. You may discard it."
	_show_top_deck_choice_panel(revealed_card)


func _exit_top_deck_choice_mode() -> void:
	_top_deck_choice_state = {}
	_dismiss_top_deck_choice_panel()


func _show_top_deck_choice_panel(revealed_card: Dictionary) -> void:
	_dismiss_top_deck_choice_panel()
	var viewport_size := get_viewport_rect().size
	var card_size := _hand_card_display_size()
	var panel := PanelContainer.new()
	panel.name = "top_deck_choice_panel"
	panel.z_index = 600
	var panel_width := card_size.x + 40.0
	var panel_height := card_size.y + 100.0
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size = Vector2(panel_width, panel_height)
	panel.position = Vector2((viewport_size.x - panel_width) * 0.5, (viewport_size.y - panel_height) * 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.45, 0.55, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var title_label := Label.new()
	title_label.text = "Top of your deck:"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.9))
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)
	var card_container := CenterContainer.new()
	card_container.custom_minimum_size = card_size
	vbox.add_child(card_container)
	var card_component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	card_component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_component.custom_minimum_size = card_size
	card_component.apply_card(revealed_card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	card_container.add_child(card_component)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	vbox.add_child(button_row)
	var discard_btn := Button.new()
	discard_btn.text = "Discard"
	discard_btn.custom_minimum_size = Vector2(120, 40)
	var discard_style := StyleBoxFlat.new()
	discard_style.bg_color = Color(0.4, 0.15, 0.12, 0.92)
	discard_style.border_color = Color(0.8, 0.35, 0.25, 0.8)
	discard_style.set_border_width_all(2)
	discard_style.set_corner_radius_all(6)
	discard_style.set_content_margin_all(8)
	discard_btn.add_theme_stylebox_override("normal", discard_style)
	discard_btn.add_theme_stylebox_override("hover", discard_style)
	discard_btn.add_theme_stylebox_override("pressed", discard_style)
	discard_btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.88))
	discard_btn.add_theme_font_size_override("font_size", 16)
	discard_btn.pressed.connect(_resolve_top_deck_choice.bind(true))
	button_row.add_child(discard_btn)
	var keep_btn := Button.new()
	keep_btn.text = "Keep"
	keep_btn.custom_minimum_size = Vector2(120, 40)
	var keep_style := StyleBoxFlat.new()
	keep_style.bg_color = Color(0.15, 0.3, 0.18, 0.92)
	keep_style.border_color = Color(0.4, 0.75, 0.45, 0.8)
	keep_style.set_border_width_all(2)
	keep_style.set_corner_radius_all(6)
	keep_style.set_content_margin_all(8)
	keep_btn.add_theme_stylebox_override("normal", keep_style)
	keep_btn.add_theme_stylebox_override("hover", keep_style)
	keep_btn.add_theme_stylebox_override("pressed", keep_style)
	keep_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	keep_btn.add_theme_font_size_override("font_size", 16)
	keep_btn.pressed.connect(_resolve_top_deck_choice.bind(false))
	button_row.add_child(keep_btn)
	_prophecy_card_overlay.add_child(panel)
	_top_deck_choice_panel = panel


func _dismiss_top_deck_choice_panel() -> void:
	if _top_deck_choice_panel != null and is_instance_valid(_top_deck_choice_panel):
		_top_deck_choice_panel.queue_free()
	_top_deck_choice_panel = null


func _resolve_top_deck_choice(discard: bool) -> void:
	if _top_deck_choice_state.is_empty():
		return
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_pending_top_deck_choice(_match_state, local_id, discard)
	_exit_top_deck_choice_mode()
	if bool(result.get("is_valid", false)):
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = "Discarded top card." if discard else "Kept top card."
	else:
		_status_message = str(result.get("errors", ["Failed to resolve top deck choice."])[0])
	_refresh_ui()


func _show_multi_card_choice_panel(cards: Array, prompt_text: String) -> void:
	_dismiss_top_deck_choice_panel()
	var overlay := Control.new()
	overlay.name = "MultiCardChoiceOverlay"
	overlay.z_index = 600
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 0.88)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	var title := Label.new()
	title.text = prompt_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1.0))
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(hbox)

	var card_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var card_button := Button.new()
		card_button.custom_minimum_size = card_size
		var empty_style := StyleBoxEmpty.new()
		card_button.add_theme_stylebox_override("normal", empty_style)
		card_button.add_theme_stylebox_override("pressed", empty_style)
		card_button.add_theme_stylebox_override("focus", empty_style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.3, 0.25, 0.1, 0.6)
		hover_style.set_corner_radius_all(6)
		card_button.add_theme_stylebox_override("hover", hover_style)

		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_button.add_child(component)

		var idx := i
		card_button.pressed.connect(func(): _on_multi_card_choice_selected(idx))
		hbox.add_child(card_button)

	add_child(overlay)
	_top_deck_choice_panel = overlay


func _on_multi_card_choice_selected(chosen_index: int) -> void:
	if _top_deck_choice_state.is_empty():
		return
	var mode := str(_top_deck_choice_state.get("mode", ""))
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_pending_top_deck_multi_choice(_match_state, local_id, chosen_index)
	_exit_top_deck_choice_mode()
	if bool(result.get("is_valid", false)):
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		var chosen_name := str(result.get("chosen_card", {}).get("name", ""))
		if mode == "give_one_draw_rest":
			_status_message = "Gave %s to opponent, drew the rest." % chosen_name
		elif mode == "draw_one_shuffle_rest":
			_status_message = "Drew %s, shuffled the others back." % chosen_name
		else:
			_status_message = "Kept %s, discarded the rest." % chosen_name
	else:
		_status_message = str(result.get("errors", ["Failed to resolve choice."])[0])
	_refresh_ui()


func _animate_enemy_prophecy_resolution(action: Dictionary, _result: Dictionary) -> void:
	var card_back: PanelContainer = _prophecy_overlay_state.get("card_back")
	if card_back == null or not is_instance_valid(card_back):
		_dismiss_prophecy_overlay()
		_refresh_ui()
		return
	var action_kind := str(action.get("kind", ""))
	var is_play := action_kind == MatchActionEnumerator.KIND_SUMMON_CREATURE or action_kind == MatchActionEnumerator.KIND_PLAY_ACTION or action_kind == MatchActionEnumerator.KIND_PLAY_ITEM
	_prophecy_overlay_state["phase"] = "animating"
	if is_play:
		# Flip animation: scale X to 0, swap to card face, scale back
		var instance_id := str(_prophecy_overlay_state.get("instance_id", ""))
		var card := _card_from_instance_id(instance_id)
		card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
		var tween := create_tween()
		tween.tween_property(card_back, "scale:x", 0.0, 0.2)
		tween.tween_callback(func():
			# Replace card back content with card face
			for child in card_back.get_children():
				child.queue_free()
			if not card.is_empty():
				var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
				component.mouse_filter = Control.MOUSE_FILTER_IGNORE
				component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
				component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
				card_back.add_child(component)
		)
		tween.tween_property(card_back, "scale:x", 1.0, 0.2)
		tween.tween_interval(0.4)
		tween.tween_callback(func():
			_dismiss_prophecy_overlay()
			_refresh_ui()
		)
	else:
		# Decline: slide up into opponent hand area
		card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card_back, "position:y", -card_back.size.y, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(card_back, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(func():
			_dismiss_prophecy_overlay()
			_refresh_ui()
		)


func _dismiss_spell_reveal() -> void:
	var card_back: Control = _spell_reveal_state.get("card_back")
	if card_back != null and is_instance_valid(card_back):
		card_back.queue_free()
	var arrow: Line2D = _spell_reveal_state.get("arrow")
	if arrow != null and is_instance_valid(arrow):
		arrow.queue_free()
	_spell_reveal_state = {}


func _dismiss_attack_arrow() -> void:
	var arrow: Line2D = _attack_arrow_state.get("arrow")
	if arrow != null and is_instance_valid(arrow):
		arrow.queue_free()
	_attack_arrow_state = {}


func _animate_enemy_attack_arrow(action: Dictionary, _result: Dictionary) -> void:
	var attacker_id := str(action.get("source_instance_id", ""))
	var params: Dictionary = action.get("parameters", {})
	var target: Dictionary = params.get("target", {})
	var target_type := str(target.get("type", ""))

	var attacker_button: Button = _card_buttons.get(attacker_id)
	if attacker_button == null or not is_instance_valid(attacker_button):
		_refresh_ui()
		return

	var attacker_card_size: Vector2 = attacker_button.get_meta("card_size", attacker_button.size)
	var arrow_start := attacker_button.global_position + Vector2(attacker_card_size.x * 0.5, 0.0)

	var arrow_end := Vector2.ZERO
	if target_type == MatchCombat.TARGET_TYPE_CREATURE:
		var target_id := str(target.get("instance_id", ""))
		var target_button: Button = _card_buttons.get(target_id)
		if target_button == null or not is_instance_valid(target_button):
			_refresh_ui()
			return
		var target_card_size: Vector2 = target_button.get_meta("card_size", target_button.size)
		arrow_end = target_button.global_position + Vector2(target_card_size.x * 0.5, 0.0)
	elif target_type == MatchCombat.TARGET_TYPE_PLAYER:
		var target_player_id := str(target.get("player_id", ""))
		var section: Dictionary = _player_sections.get(target_player_id, {})
		var avatar: Control = section.get("avatar_component")
		if avatar != null and is_instance_valid(avatar):
			arrow_end = avatar.global_position + Vector2(avatar.size.x * 0.5, avatar.size.y * 0.5)
		else:
			_refresh_ui()
			return
	else:
		_refresh_ui()
		return

	var arrow := Line2D.new()
	arrow.width = 4.0
	arrow.default_color = Color(0.95, 0.25, 0.2, 0.92)
	arrow.z_index = 500
	arrow.antialiased = true
	_prophecy_card_overlay.add_child(arrow)
	_attack_arrow_state = {"arrow": arrow}

	var tween := create_tween()
	tween.tween_method(func(progress: float):
		_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
	, 0.0, 1.0, 0.3)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		_dismiss_attack_arrow()
		_refresh_ui()
	)


static func _has_support_activation_target(action: Dictionary) -> bool:
	var params: Dictionary = action.get("parameters", {})
	return not str(params.get("target_instance_id", "")).is_empty() or not str(params.get("target_player_id", "")).is_empty()


func _dismiss_support_arrow() -> void:
	var arrow: Line2D = _support_arrow_state.get("arrow")
	if arrow != null and is_instance_valid(arrow):
		arrow.queue_free()
	_support_arrow_state = {}


func _animate_enemy_support_activation_arrow(action: Dictionary, _result: Dictionary) -> void:
	var support_id := str(action.get("source_instance_id", ""))
	var params: Dictionary = action.get("parameters", {})
	var target_instance_id := str(params.get("target_instance_id", ""))
	var target_player_id := str(params.get("target_player_id", ""))

	var support_button: Button = _card_buttons.get(support_id)
	if support_button == null or not is_instance_valid(support_button):
		_refresh_ui()
		return

	var support_size: Vector2 = support_button.get_meta("card_size", support_button.size)
	var arrow_start := support_button.global_position + Vector2(support_size.x * 0.5, support_size.y * 0.5)

	var arrow_end := Vector2.ZERO
	if not target_instance_id.is_empty():
		var target_button: Button = _card_buttons.get(target_instance_id)
		if target_button == null or not is_instance_valid(target_button):
			_refresh_ui()
			return
		var target_size: Vector2 = target_button.get_meta("card_size", target_button.size)
		arrow_end = target_button.global_position + Vector2(target_size.x * 0.5, target_size.y * 0.5)
	elif not target_player_id.is_empty():
		var section: Dictionary = _player_sections.get(target_player_id, {})
		var avatar: Control = section.get("avatar_component")
		if avatar != null and is_instance_valid(avatar):
			arrow_end = avatar.global_position + Vector2(avatar.size.x * 0.5, avatar.size.y * 0.5)
		else:
			_refresh_ui()
			return
	else:
		_refresh_ui()
		return

	var arrow := Line2D.new()
	arrow.width = 4.0
	arrow.default_color = Color(1.0, 0.85, 0.3, 0.95)
	arrow.z_index = 500
	arrow.antialiased = true
	_prophecy_card_overlay.add_child(arrow)
	_support_arrow_state = {"arrow": arrow}

	var tween := create_tween()
	tween.tween_method(func(progress: float):
		_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
	, 0.0, 1.0, 0.3)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		_dismiss_support_arrow()
		_refresh_ui()
	)


func _dismiss_deck_reveal() -> void:
	var panel: Control = _deck_reveal_state.get("panel")
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	_deck_reveal_state = {}


func _animate_deck_card_reveal(revealed_card: Dictionary) -> void:
	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "deck_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x := (viewport_size.x - card_size.x) * 0.5
	var pos_y := viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_prophecy_card_overlay.add_child(card_back)
	_deck_reveal_state = {
		"panel": card_back,
		"phase": "animating",
	}

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween := create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(revealed_card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_callback(func():
		_dismiss_deck_reveal()
		_refresh_ui()
	)


func _animate_enemy_spell_reveal(action: Dictionary, _result: Dictionary) -> void:
	var source_card: Dictionary = action.get("source_card", {})
	if source_card.is_empty():
		_refresh_ui()
		return

	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "spell_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x := (viewport_size.x - card_size.x) * 0.5
	var pos_y := viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_prophecy_card_overlay.add_child(card_back)
	_spell_reveal_state = {
		"card_back": card_back,
		"phase": "animating",
	}

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween := create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		if not source_card.is_empty():
			var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
			component.mouse_filter = Control.MOUSE_FILTER_IGNORE
			component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			component.apply_card(source_card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
			card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		var target: Dictionary = action.get("target", {})
		var target_kind := str(target.get("kind", ""))
		if target_kind == "card":
			var target_id := str(target.get("instance_id", ""))
			var button: Button = _card_buttons.get(target_id)
			if button != null and is_instance_valid(button):
				var arrow := Line2D.new()
				arrow.width = 3.0
				arrow.default_color = Color(1.0, 0.85, 0.3, 0.95)
				arrow.z_index = 500
				_prophecy_card_overlay.add_child(arrow)
				_spell_reveal_state["arrow"] = arrow
				var arrow_start := card_back.global_position + Vector2(card_size.x * 0.5, card_size.y)
				var target_card_size: Vector2 = button.get_meta("card_size", button.size)
				var arrow_end := button.global_position + Vector2(target_card_size.x * 0.5, 0.0)
				var arrow_tween := create_tween()
				arrow_tween.tween_method(func(progress: float):
					_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
				, 0.0, 1.0, 0.3)
				arrow_tween.tween_interval(0.3)
				arrow_tween.tween_callback(func():
					_dismiss_spell_reveal()
					_refresh_ui()
				)
				return
		_dismiss_spell_reveal()
		_refresh_ui()
	)


func _animate_enemy_item_reveal(action: Dictionary, _result: Dictionary) -> void:
	var source_card: Dictionary = action.get("source_card", {})
	if source_card.is_empty():
		_refresh_ui()
		return

	var params: Dictionary = action.get("parameters", {})
	var target_instance_id := str(params.get("target_instance_id", ""))

	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "item_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x := (viewport_size.x - card_size.x) * 0.5
	var pos_y := viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_prophecy_card_overlay.add_child(card_back)
	_spell_reveal_state = {
		"card_back": card_back,
		"phase": "animating",
	}

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween := create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		if not source_card.is_empty():
			var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
			component.mouse_filter = Control.MOUSE_FILTER_IGNORE
			component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			component.apply_card(source_card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
			card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		if not target_instance_id.is_empty():
			var button: Button = _card_buttons.get(target_instance_id)
			if button != null and is_instance_valid(button):
				var arrow := Line2D.new()
				arrow.width = 3.0
				arrow.default_color = Color(1.0, 0.85, 0.3, 0.95)
				arrow.z_index = 500
				_prophecy_card_overlay.add_child(arrow)
				_spell_reveal_state["arrow"] = arrow
				var arrow_start := card_back.global_position + Vector2(card_size.x * 0.5, card_size.y)
				var target_card_size: Vector2 = button.get_meta("card_size", button.size)
				var arrow_end := button.global_position + Vector2(target_card_size.x * 0.5, 0.0)
				var arrow_tween := create_tween()
				arrow_tween.tween_method(func(progress: float):
					_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
				, 0.0, 1.0, 0.3)
				arrow_tween.tween_interval(0.3)
				arrow_tween.tween_callback(func():
					_dismiss_spell_reveal()
					_refresh_ui()
				)
				return
		_dismiss_spell_reveal()
		_refresh_ui()
	)


static func _has_summon_target(action: Dictionary) -> bool:
	var params: Dictionary = action.get("parameters", {})
	return not str(params.get("summon_target_instance_id", "")).is_empty() or not str(params.get("summon_target_player_id", "")).is_empty()


func _animate_enemy_creature_summon_reveal(action: Dictionary, _result: Dictionary) -> void:
	var source_card: Dictionary = action.get("source_card", {})
	if source_card.is_empty():
		_refresh_ui()
		return

	var params: Dictionary = action.get("parameters", {})
	var summon_target_id := str(params.get("summon_target_instance_id", ""))

	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "summon_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x := (viewport_size.x - card_size.x) * 0.5
	var pos_y := viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_prophecy_card_overlay.add_child(card_back)
	_spell_reveal_state = {
		"card_back": card_back,
		"phase": "animating",
	}

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween := create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		if not source_card.is_empty():
			var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
			component.mouse_filter = Control.MOUSE_FILTER_IGNORE
			component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			component.apply_card(source_card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
			card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		if not summon_target_id.is_empty():
			var button: Button = _card_buttons.get(summon_target_id)
			if button != null and is_instance_valid(button):
				var arrow := Line2D.new()
				arrow.width = 3.0
				arrow.default_color = Color(1.0, 0.85, 0.3, 0.95)
				arrow.z_index = 500
				_prophecy_card_overlay.add_child(arrow)
				_spell_reveal_state["arrow"] = arrow
				var arrow_start := card_back.global_position + Vector2(card_size.x * 0.5, card_size.y)
				var target_card_size: Vector2 = button.get_meta("card_size", button.size)
				var arrow_end := button.global_position + Vector2(target_card_size.x * 0.5, 0.0)
				var arrow_tween := create_tween()
				arrow_tween.tween_method(func(progress: float):
					_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
				, 0.0, 1.0, 0.3)
				arrow_tween.tween_interval(0.3)
				arrow_tween.tween_callback(func():
					_dismiss_spell_reveal()
					_refresh_ui()
				)
				return
		_dismiss_spell_reveal()
		_refresh_ui()
	)


func _animate_enemy_creature_play(action: Dictionary, _result: Dictionary) -> void:
	var source_card: Dictionary = action.get("source_card", {})
	var params: Dictionary = action.get("parameters", {})
	var lane_id := str(params.get("lane_id", ""))
	if source_card.is_empty() or lane_id.is_empty():
		_refresh_ui()
		return

	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "creature_play_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	# Start from the top center (enemy hand area)
	var start_x := (viewport_size.x - card_size.x) * 0.5
	var start_y := -(card_size.y * 0.5)
	card_back.position = Vector2(start_x, start_y)

	_prophecy_card_overlay.add_child(card_back)
	_spell_reveal_state = {
		"card_back": card_back,
		"phase": "animating",
	}

	# Find the target lane row panel to get the destination position
	var enemy_player_id := str(action.get("player_id", ""))
	var row_key := _lane_row_key(lane_id, enemy_player_id)
	var row_panel: PanelContainer = _lane_row_panels.get(row_key)
	var end_pos: Vector2
	if row_panel != null and is_instance_valid(row_panel):
		var row_center := row_panel.global_position + row_panel.size * 0.5
		end_pos = Vector2(row_center.x - card_size.x * 0.5, row_center.y - card_size.y * 0.5)
	else:
		end_pos = Vector2(start_x, viewport_size.y * 0.25)

	card_back.pivot_offset = Vector2(card_size.x * 0.5, card_size.y * 0.5)
	var tween := create_tween()
	# Animate card moving down to the lane
	tween.tween_property(card_back, "position", end_pos, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Scale down as it approaches the lane
	tween.parallel().tween_property(card_back, "scale", Vector2(0.5, 0.5), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Brief pause at destination
	tween.tween_interval(0.15)
	# Fade out
	tween.tween_property(card_back, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		_dismiss_spell_reveal()
		_refresh_ui()
	)


func _draw_spell_reveal_arrow_partial(progress: float, arrow: Line2D, start: Vector2, end_point: Vector2) -> void:
	if arrow == null or not is_instance_valid(arrow):
		return
	var current_end := start.lerp(end_point, progress)
	var mid := (start + current_end) * 0.5
	var diff := current_end - start
	var perp := Vector2(-diff.y, diff.x).normalized()
	var control := mid + perp * diff.length() * 0.25
	var points := PackedVector2Array()
	var segments := 20
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := (1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * control + t * t * current_end
		points.append(p)
	if progress > 0.05:
		var tip := points[points.size() - 1]
		var prev := points[points.size() - 2]
		var arrow_dir := (tip - prev).normalized()
		var arrow_perp := Vector2(-arrow_dir.y, arrow_dir.x)
		var arrow_size := 14.0
		points.append(tip - arrow_dir * arrow_size + arrow_perp * arrow_size * 0.5)
		points.append(tip)
		points.append(tip - arrow_dir * arrow_size - arrow_perp * arrow_size * 0.5)
		points.append(tip)
	arrow.points = points


func _refresh_end_turn_button() -> void:
	var has_pending_prophecy := MatchTiming.has_pending_prophecy(_match_state)
	var local_turn := _is_local_player_turn()
	var match_complete := _has_match_winner()
	_end_turn_button.disabled = match_complete or not local_turn or has_pending_prophecy
	_refresh_end_turn_button_style(has_pending_prophecy)
	if match_complete:
		_end_turn_button.tooltip_text = "Match complete. No further turn actions are available."


func _build_card_button(card: Dictionary, public_view: bool, surface := "default") -> Button:
	var button := Button.new()
	var instance_id := str(card.get("instance_id", ""))
	var hidden := not public_view and not _is_pending_prophecy_card(card)
	var selected := instance_id == _selected_instance_id
	var muted := _should_mute_card(card, public_view, surface)
	var interaction_state := _card_interaction_state(card, surface)
	var locked := _should_dim_card_for_turn(card, surface, interaction_state)
	button.name = "%s_%s_card" % [surface, instance_id]
	button.custom_minimum_size = _surface_button_minimum_size(surface)
	button.clip_contents = surface == "lane"
	button.text = ""
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	var no_action := surface == "lane" and _selected_action_mode(card) == SELECTION_MODE_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if (locked and interaction_state == "default") or no_action else Control.CURSOR_POINTING_HAND
	button.set_meta("instance_id", instance_id)
	button.set_meta("surface", surface)
	button.set_meta("presentation_locked", locked)
	_apply_surface_button_style(button, surface, hidden, selected, muted, interaction_state, card, locked)
	button.pressed.connect(_on_card_pressed.bind(str(card.get("instance_id", ""))))
	button.tooltip_text = ""
	button.disabled = hidden
	button.set_meta("card_display_component", null)
	_populate_card_button_content(button, card, public_view, surface)
	_apply_card_feedback_decoration(button, card, surface)
	if interaction_state == "valid":
		_apply_valid_target_glow(button, surface)
	elif interaction_state == "valid_betray":
		_apply_betray_target_glow(button, surface)
	if surface == "lane" and str(card.get("card_type", "")) == "creature":
		_apply_lane_card_float_effect(button, card)
	_card_buttons[instance_id] = button
	if surface == "hand" and public_view and str(card.get("controller_player_id", "")) == PLAYER_ORDER[1]:
		button.mouse_entered.connect(_on_local_hand_card_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_local_hand_card_mouse_exited.bind(button))
	if surface == "lane" and str(card.get("card_type", "")) == "creature":
		button.mouse_entered.connect(_on_lane_card_mouse_entered.bind(button, instance_id))
		button.mouse_exited.connect(_on_lane_card_mouse_exited.bind(instance_id))
		button.gui_input.connect(_on_lane_card_gui_input.bind(instance_id))
	if surface == "support":
		button.mouse_entered.connect(_on_support_card_mouse_entered.bind(button, instance_id))
		button.mouse_exited.connect(_on_support_card_mouse_exited.bind(instance_id))
	return button


func _build_placeholder_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.83, 0.85, 0.89, 0.9))
	label.custom_minimum_size = Vector2(176, 44)
	return label


func _surface_button_minimum_size(surface: String) -> Vector2:
	match surface:
		"lane":
			return CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE
		"hand":
			return CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
		"support":
			return CARD_DISPLAY_COMPONENT_SCRIPT.SUPPORT_BOARD_MINIMUM_SIZE
		_:
			return Vector2(132, 80)


func _surface_font_size(surface: String) -> int:
	match surface:
		"lane":
			return 13
		"hand":
			return 15
		"support":
			return 14
		_:
			return 15


func _on_hand_surface_resized(hand_surface: Control) -> void:
	if hand_surface == null:
		return
	var player_id := str(hand_surface.get_meta("player_id", ""))
	var has_card := false
	for child in hand_surface.get_children():
		if child is Button:
			has_card = true
			break
	if has_card:
		_layout_hand_cards(hand_surface, player_id)
	elif hand_surface.get_child_count() > 0 and hand_surface.get_child(0) is Label:
		_layout_hand_placeholder(hand_surface, hand_surface.get_child(0) as Label)
	_apply_match_layout_scale()


func _layout_hand_cards(hand_surface: Control, player_id: String) -> void:
	var cards: Array[Button] = []
	for child in hand_surface.get_children():
		if child is Button:
			cards.append(child as Button)
	if cards.is_empty():
		return
	var card_size := _surface_button_minimum_size("hand")
	var count := cards.size()
	var is_local := player_id == PLAYER_ORDER[1]
	if is_local:
		_layout_local_hand_cards(hand_surface, cards, card_size, count)
	else:
		_layout_opponent_hand_cards(hand_surface, cards, card_size, count)


func _layout_local_hand_cards(hand_surface: Control, cards: Array[Button], card_size: Vector2, count: int) -> void:
	# Cards fan out at the bottom-center of the screen, mostly off the bottom edge.
	var overlay_size := get_viewport_rect().size
	card_size = _hand_card_display_size()
	var overlap_step := card_size.x * 0.45
	var total_width := card_size.x + overlap_step * float(max(0, count - 1))
	var start_x := (overlay_size.x - total_width) * 0.5
	# Cards sit with the top ~35% peeking above the bottom edge
	var base_y := overlay_size.y - card_size.y * 0.35
	# Affordable cards peek a bit higher to signal they are playable
	var affordable_rise := card_size.y * 0.06
	var local_player := _player_state(PLAYER_ORDER[1])
	var available_magicka := int(local_player.get("current_magicka", 0)) + int(local_player.get("temporary_magicka", 0))
	for index in range(count):
		var button := cards[index]
		var instance_id := str(button.get_meta("instance_id", ""))
		var card := _find_card_in_player_hand(PLAYER_ORDER[1], instance_id)
		var affordable := not card.is_empty() and int(card.get("cost", 0)) <= available_magicka
		var position := Vector2(start_x + overlap_step * index, base_y - (affordable_rise if affordable else 0.0))
		button.size = card_size
		button.position = position
		button.pivot_offset = card_size * 0.5
		button.rotation_degrees = 0.0
		button.scale = Vector2.ONE
		button.z_index = index
		button.set_meta("hand_index", index)
		button.set_meta("base_position", position)
		button.set_meta("card_size", card_size)
		button.set_meta("affordable", affordable)
		# Make button background transparent — the CardDisplayComponent provides
		# all visual framing, and the button may extend beyond the card as a hit zone
		var empty_style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, empty_style)
	for button in cards:
		_apply_local_hand_hover_state(button, false)


func _layout_opponent_hand_cards(hand_surface: Control, cards: Array[Button], card_size: Vector2, count: int) -> void:
	# Cards peek from the top edge of the screen, mirroring the local hand at the bottom.
	var overlay_size := get_viewport_rect().size
	var target_height := overlay_size.y * 0.30
	var aspect_ratio := card_size.x / card_size.y
	card_size = Vector2(target_height * aspect_ratio, target_height)
	var overlap_step := card_size.x * 0.45
	var total_width := card_size.x + overlap_step * float(max(0, count - 1))
	var start_x := (overlay_size.x - total_width) * 0.5
	# Cards sit with only a sliver (~10%) peeking below the top edge
	var base_y := -(card_size.y * 0.90)
	for index in range(count):
		var button := cards[index]
		var position := Vector2(start_x + overlap_step * index, base_y)
		button.size = card_size
		button.position = position
		# Pivot at bottom-center so the fan radiates toward us (opponent faces the player)
		button.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)
		var fan_offset := float(index) - float(count - 1) * 0.5
		button.rotation_degrees = fan_offset * -1.5
		button.scale = Vector2.ONE
		button.z_index = index
		button.set_meta("hand_index", index)
		button.set_meta("base_position", position)
		button.set_meta("card_size", card_size)
		var empty_style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, empty_style)


func _layout_hand_placeholder(hand_surface: Control, placeholder: Label) -> void:
	if hand_surface == null or placeholder == null:
		return
	placeholder.position = Vector2.ZERO
	placeholder.size = Vector2(max(hand_surface.size.x, 220.0), placeholder.custom_minimum_size.y)


func _on_local_hand_card_mouse_entered(button: Button) -> void:
	_hovered_hand_instance_id = str(button.get_meta("instance_id", ""))
	var card := _card_from_instance_id(_hovered_hand_instance_id)
	_error_report_hovered_type = "card"
	_error_report_hovered_context = "%s (in hand)" % str(card.get("name", _hovered_hand_instance_id))
	_apply_local_hand_hover_state(button, true)


func _on_local_hand_card_mouse_exited(button: Button) -> void:
	if _hovered_hand_instance_id == str(button.get_meta("instance_id", "")):
		_hovered_hand_instance_id = ""
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""
	var hand_component = button.get_meta("card_display_component", null)
	if hand_component != null and is_instance_valid(hand_component) and hand_component.has_method("reset_relationship_view"):
		hand_component.reset_relationship_view()
	_apply_local_hand_hover_state(button, false)


func _apply_local_hand_hover_state(button: Button, hovered: bool) -> void:
	if button == null:
		return
	var base_position: Vector2 = button.get_meta("base_position", button.position)
	var hand_index := int(button.get_meta("hand_index", button.z_index))
	var selected := str(button.get_meta("instance_id", "")) == _selected_instance_id
	var locked := bool(button.get_meta("presentation_locked", false))
	var card_size: Vector2 = button.get_meta("card_size", button.size)
	var affordable := bool(button.get_meta("affordable", false))
	var affordable_rise := card_size.y * 0.06 if affordable else 0.0
	# How far the card needs to rise to be fully visible, plus margin from screen bottom.
	# Subtract affordable_rise so all raised cards reach the same absolute Y regardless of
	# their resting offset.
	var bottom_margin := 24.0
	var rise_amount := card_size.y * 0.85 + bottom_margin - affordable_rise
	# Determine target state
	var any_selected := not _selected_instance_id.is_empty()
	var target_position := base_position
	var target_size := card_size
	var target_scale := Vector2.ONE
	var target_z := hand_index
	# Hand selection mode: eligible cards are raised and clickable, ineligible are dimmed
	var hand_selection_active := not _hand_selection_state.is_empty()
	var hand_selection_eligible := hand_selection_active and (_hand_selection_state.get("candidate_ids", []) as Array).has(str(button.get_meta("instance_id", "")))
	var hand_selection_ineligible := hand_selection_active and not hand_selection_eligible
	# When any card is selected (placement mode), non-selected hand cards ignore mouse
	# so they don't block clicks on the board/support surface beneath them
	var target_filter := Control.MOUSE_FILTER_IGNORE if (any_selected and not selected) else Control.MOUSE_FILTER_STOP
	if hand_selection_ineligible:
		target_filter = Control.MOUSE_FILTER_IGNORE
	var raised := false
	if hand_selection_eligible:
		target_filter = Control.MOUSE_FILTER_STOP
		target_scale = Vector2(1.05, 1.05)
		target_position = base_position + Vector2(0.0, -rise_amount)
		target_z = 110
		raised = true
	elif not locked and selected:
		target_filter = Control.MOUSE_FILTER_IGNORE
		target_scale = Vector2(1.05, 1.05)
		target_position = base_position + Vector2(0.0, -rise_amount)
		target_z = 110
		raised = true
	if hovered and not hand_selection_active:
		target_filter = Control.MOUSE_FILTER_STOP
		target_scale = Vector2(1.1, 1.1) if selected else Vector2(1.05, 1.05)
		target_position = base_position + Vector2(0.0, -rise_amount - (20.0 if selected else 0.0))
		target_z = 120 if selected else 100
		raised = true
	# When raised, extend button height downward to create an invisible hit zone
	# that prevents hover oscillation when the card moves away from the cursor
	if raised:
		var extend := base_position.y - target_position.y
		target_size = Vector2(card_size.x, card_size.y + extend)
	# Apply non-animated properties immediately
	button.z_index = target_z
	button.mouse_filter = target_filter
	button.scale = target_scale
	button.pivot_offset = card_size * 0.5
	button.size = target_size
	button.modulate = Color(0.4, 0.4, 0.4, 0.7) if hand_selection_ineligible else Color.WHITE
	# Pin content to original card dimensions at the top of the (possibly taller) button
	var content_root: Control = button.get_meta("content_root", null) if button.has_meta("content_root") else null
	if content_root != null:
		content_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		content_root.position = Vector2.ZERO
		content_root.size = card_size
	# Animate position (the rise/fall)
	var tween_key := "hand_hover_tween"
	var existing_tween: Tween = button.get_meta(tween_key, null) if button.has_meta(tween_key) else null
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	var tween := create_tween()
	tween.tween_property(button, "position", target_position, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	button.set_meta(tween_key, tween)
	# Bob animation for affordable cards at rest
	var bob_key := "hand_bob_tween"
	var existing_bob: Tween = button.get_meta(bob_key, null) if button.has_meta(bob_key) else null
	if existing_bob != null and existing_bob.is_valid():
		existing_bob.kill()
	if affordable and not raised:
		var bob_button := button
		var bob_pos := target_position
		var bob_k := bob_key
		tween.finished.connect(func(): _start_hand_card_bob(bob_button, bob_pos, bob_k))


func _start_hand_card_bob(button: Button, base_pos: Vector2, bob_key: String) -> void:
	if not is_instance_valid(button):
		return
	var bob_top := base_pos.y - HAND_CARD_BOB_AMPLITUDE
	var bob_bottom := base_pos.y
	var half := HAND_CARD_BOB_DURATION * 0.5
	var bob_tween := create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(button, "position:y", bob_top, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(button, "position:y", bob_bottom, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	button.set_meta(bob_key, bob_tween)


func _on_lane_card_mouse_entered(button: Button, instance_id: String) -> void:
	_clear_lane_card_hover_preview()
	_lane_hover_preview_pending = {
		"instance_id": instance_id,
		"button_ref": weakref(button),
		"entered_at_ms": Time.get_ticks_msec(),
	}
	var card := _card_from_instance_id(instance_id)
	var lane_id := _find_card_lane_id(instance_id)
	var side := "player" if str(card.get("controller_player_id", "")) == _local_player_id() else "opponent"
	_error_report_hovered_type = "card"
	_error_report_hovered_context = "%s (in %s, %s side)" % [str(card.get("name", instance_id)), _lane_name(lane_id), side]


func _on_lane_card_mouse_exited(instance_id: String) -> void:
	if str(_lane_hover_preview_pending.get("instance_id", "")) == instance_id:
		_lane_hover_preview_pending = {}
	if _lane_hover_preview_instance_id == instance_id:
		_clear_lane_card_hover_preview()
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


func _process_lane_card_hover_preview() -> void:
	if _lane_hover_preview_button_ref != null:
		var active_button = _lane_hover_preview_button_ref.get_ref() as Button
		if active_button == null or not is_instance_valid(active_button):
			_clear_lane_card_hover_preview()
		elif _lane_hover_preview_instance_id != "":
			_position_lane_card_hover_preview(active_button)
	if _lane_hover_preview_pending.is_empty():
		return
	if Time.get_ticks_msec() - int(_lane_hover_preview_pending.get("entered_at_ms", 0)) < CARD_HOVER_PREVIEW_DELAY_MS:
		return
	var button_ref := _lane_hover_preview_pending.get("button_ref") as WeakRef
	var button := button_ref.get_ref() as Button if button_ref != null else null
	var instance_id := str(_lane_hover_preview_pending.get("instance_id", ""))
	_lane_hover_preview_pending = {}
	if button == null or not is_instance_valid(button):
		return
	var card := _card_from_instance_id(instance_id)
	if card.is_empty() or str(card.get("card_type", "")) != "creature":
		return
	_show_lane_card_hover_preview(button, card, instance_id)


func _hand_card_display_size() -> Vector2:
	var base := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var target_height := get_viewport_rect().size.y * 0.30
	var aspect_ratio := base.x / base.y
	return Vector2(target_height * aspect_ratio, target_height)


## Build relationship context for alt-view synergy text during a match.
## Collects board creatures and hand cards so the resolver can display counts
## like "You have 3 Orcs in play and hand" instead of the generic fallback.
func _build_match_relationship_context() -> Dictionary:
	var board_cards: Array = []
	var hand_cards: Array = []
	var local_id := _local_player_id()
	for lane in _match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(local_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				board_cards.append(card)
	for player in _match_state.get("players", []):
		if str(player.get("player_id", "")) == local_id:
			for card in player.get("hand", []):
				if typeof(card) == TYPE_DICTIONARY:
					hand_cards.append(card)
			break
	return {"zone": "match", "board_cards": board_cards, "hand_cards": hand_cards}


func _add_hover_preview_to_layer(card: Dictionary, instance_id: String, name_prefix: String) -> Control:
	var preview_size := _hand_card_display_size()
	# Replicate how hand cards render: a CardDisplayComponent built at base
	# size (220x384) with PRESET_FULL_RECT inside a larger container. When
	# the component enters the tree, NOTIFICATION_RESIZED fires and updates
	# geometry to the container size, while fonts stay at the base scale —
	# exactly matching the hand card rendering path.
	var base_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "%s_%s" % [name_prefix, instance_id]
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 400
	# Start at base size so component._ready() sets fonts at scale 1.0
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	if component.has_method("set_wax_wane_phases"):
		component.set_wax_wane_phases(_get_wax_wane_phases_for_card(card))
	if component.has_method("set_relationship_context"):
		component.set_relationship_context(_build_match_relationship_context())
	wrapper.add_child(component)
	# Add to tree — _ready() fires with base size, fonts set at scale 1.0
	_card_hover_preview_layer.add_child(wrapper)
	# Now resize to preview size — NOTIFICATION_RESIZED updates geometry only,
	# fonts stay at scale 1.0, matching exactly how hand cards render
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	return wrapper


func _show_lane_card_hover_preview(button: Button, card: Dictionary, instance_id: String) -> void:
	_clear_lane_card_hover_preview()
	if _card_hover_preview_layer == null:
		return
	var preview := _add_hover_preview_to_layer(card, instance_id, "lane_hover_preview")
	_lane_hover_preview_instance_id = instance_id
	_lane_hover_preview_button_ref = weakref(button)
	_position_lane_card_hover_preview(button)


func _position_lane_card_hover_preview(button: Button) -> void:
	if button == null or _card_hover_preview_layer == null:
		return
	var preview := _card_hover_preview_layer.get_node_or_null("lane_hover_preview_%s" % _lane_hover_preview_instance_id) as Control
	if preview == null:
		return
	var preview_size := preview.size
	var layer_origin := _card_hover_preview_layer.get_global_rect().position
	var button_rect := button.get_global_rect()
	var target_position := Vector2(
		button_rect.get_center().x - preview_size.x * 0.5 - layer_origin.x,
		button_rect.get_center().y - preview_size.y * 0.5 - layer_origin.y
	)
	target_position.x = clampf(target_position.x, 0.0, maxf(_card_hover_preview_layer.size.x - preview_size.x, 0.0))
	target_position.y = clampf(target_position.y, 0.0, maxf(_card_hover_preview_layer.size.y - preview_size.y, 0.0))
	preview.position = target_position


func _clear_lane_card_hover_preview() -> void:
	_lane_hover_preview_pending = {}
	_lane_hover_preview_instance_id = ""
	_lane_hover_preview_button_ref = null
	if _card_hover_preview_layer == null:
		return
	for child in _card_hover_preview_layer.get_children():
		if str(child.name).begins_with("lane_hover_preview_"):
			child.queue_free()


func _on_support_card_mouse_entered(button: Button, instance_id: String) -> void:
	_clear_support_card_hover_preview()
	_support_hover_preview_pending = {
		"instance_id": instance_id,
		"button_ref": weakref(button),
		"entered_at_ms": Time.get_ticks_msec(),
	}
	var card := _card_from_instance_id(instance_id)
	var side := "player" if str(card.get("controller_player_id", "")) == _local_player_id() else "opponent"
	_error_report_hovered_type = "card"
	_error_report_hovered_context = "%s (support, %s side)" % [str(card.get("name", instance_id)), side]


func _on_support_card_mouse_exited(instance_id: String) -> void:
	if str(_support_hover_preview_pending.get("instance_id", "")) == instance_id:
		_support_hover_preview_pending = {}
	if _support_hover_preview_instance_id == instance_id:
		_clear_support_card_hover_preview()
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


func _process_support_card_hover_preview() -> void:
	if _support_hover_preview_button_ref != null:
		var active_button = _support_hover_preview_button_ref.get_ref() as Button
		if active_button == null or not is_instance_valid(active_button):
			_clear_support_card_hover_preview()
		elif _support_hover_preview_instance_id != "":
			_position_support_card_hover_preview(active_button)
	if _support_hover_preview_pending.is_empty():
		return
	if Time.get_ticks_msec() - int(_support_hover_preview_pending.get("entered_at_ms", 0)) < CARD_HOVER_PREVIEW_DELAY_MS:
		return
	var button_ref := _support_hover_preview_pending.get("button_ref") as WeakRef
	var button := button_ref.get_ref() as Button if button_ref != null else null
	var instance_id := str(_support_hover_preview_pending.get("instance_id", ""))
	_support_hover_preview_pending = {}
	if button == null or not is_instance_valid(button):
		return
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	_show_support_card_hover_preview(button, card, instance_id)


func _show_support_card_hover_preview(button: Button, card: Dictionary, instance_id: String) -> void:
	_clear_support_card_hover_preview()
	if _card_hover_preview_layer == null:
		return
	var preview := _add_hover_preview_to_layer(card, instance_id, "support_hover_preview")
	_support_hover_preview_instance_id = instance_id
	_support_hover_preview_button_ref = weakref(button)
	_position_support_card_hover_preview(button)


func _position_support_card_hover_preview(button: Button) -> void:
	if button == null or _card_hover_preview_layer == null:
		return
	var preview := _card_hover_preview_layer.get_node_or_null("support_hover_preview_%s" % _support_hover_preview_instance_id) as Control
	if preview == null:
		return
	var preview_size := preview.size
	var layer_origin := _card_hover_preview_layer.get_global_rect().position
	var button_rect := button.get_global_rect()
	var target_position := Vector2(
		button_rect.get_center().x - preview_size.x * 0.5 - layer_origin.x,
		button_rect.get_center().y - preview_size.y * 0.5 - layer_origin.y
	)
	target_position.x = clampf(target_position.x, 0.0, maxf(_card_hover_preview_layer.size.x - preview_size.x, 0.0))
	target_position.y = clampf(target_position.y, 0.0, maxf(_card_hover_preview_layer.size.y - preview_size.y, 0.0))
	preview.position = target_position


func _clear_support_card_hover_preview() -> void:
	_support_hover_preview_pending = {}
	_support_hover_preview_instance_id = ""
	_support_hover_preview_button_ref = null
	if _card_hover_preview_layer == null:
		return
	for child in _card_hover_preview_layer.get_children():
		if str(child.name).begins_with("support_hover_preview_"):
			child.queue_free()


func _populate_card_button_content(button: Button, card: Dictionary, public_view: bool, surface: String) -> void:
	var hidden := not public_view and not _is_pending_prophecy_card(card)
	var instance_id := str(card.get("instance_id", ""))
	var content_root := Control.new()
	content_root.name = "%s_content_root" % instance_id
	content_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	button.add_child(content_root)
	button.set_meta("content_root", content_root)
	if hidden:
		var card_back := PanelContainer.new()
		card_back.name = "%s_card_back" % instance_id
		card_back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)
		content_root.add_child(card_back)
		_set_mouse_passthrough_recursive(content_root)
		return
	var component := _build_card_display_component(card, surface, instance_id)
	if component != null:
		content_root.add_child(component)
		button.set_meta("card_display_component", component)
	_add_card_overlay_badges(content_root, card, public_view, surface, instance_id)
	_set_mouse_passthrough_recursive(content_root)


func _build_card_display_component(card: Dictionary, surface: String, instance_id: String) -> Control:
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	if component == null:
		return null
	component.name = "%s_card_display" % instance_id
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var display_card := card.duplicate(true)
	if surface == "lane" and EvergreenRules.is_cover_active(_match_state, card):
		display_card["_cover_active"] = true
	if surface == "hand" and str(card.get("controller_player_id", "")) == _active_player_id():
		var effective_cost := PersistentCardRules.get_effective_play_cost(_match_state, _active_player_id(), card)
		var base_cost := int(card.get("_base_cost", card.get("cost", 0)))
		if effective_cost != base_cost:
			display_card["_effective_cost"] = effective_cost
		_apply_empower_text_updates(display_card, _active_player_id())
	component.apply_card(display_card, _card_presentation_mode(card, surface))
	if component.has_method("set_wax_wane_phases"):
		component.set_wax_wane_phases(_get_wax_wane_phases_for_card(card))
	if component.has_method("set_relationship_context"):
		component.set_relationship_context(_build_match_relationship_context())
	if surface == "support" and bool(card.get("activation_used_this_turn", false)):
		component.modulate = Color(0.5, 0.5, 0.55, 0.8)
	return component


func _get_wax_wane_phases_for_card(card: Dictionary) -> Array:
	var controller_id := str(card.get("controller_player_id", ""))
	if controller_id.is_empty():
		return []
	for player in _match_state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) == controller_id:
			var phase := str(player.get("wax_wane_state", ""))
			if phase.is_empty():
				return []
			if bool(player.get("_dual_wax_wane", false)):
				return ["wax", "wane"]
			return [phase]
	return []


func _apply_empower_text_updates(display_card: Dictionary, player_id: String) -> void:
	var effect_ids = display_card.get("effect_ids", [])
	if typeof(effect_ids) != TYPE_ARRAY or not effect_ids.has("empower"):
		return
	var empower_amount := MatchTiming._get_empower_amount(_match_state, player_id)
	if empower_amount <= 0:
		return
	var abilities: Array = display_card.get("triggered_abilities", [])
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		for effect in ability.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var eb := int(effect.get("empower_bonus", 0))
			if eb > 0:
				var bonus := eb * empower_amount
				var op := str(effect.get("op", ""))
				if op == "deal_damage":
					var base_amount := int(effect.get("amount", 0))
					effect["amount"] = base_amount + bonus
				elif op == "destroy_creature":
					var base_max := int(effect.get("max_power", 0))
					effect["max_power"] = base_max + bonus
				elif op == "add_support_uses":
					var base_uses := int(effect.get("amount", 0))
					effect["amount"] = base_uses + bonus
				elif op == "banish_from_opponent_deck":
					var base_count := int(effect.get("count_per_attribute", effect.get("count", 0)))
					if effect.has("count_per_attribute"):
						effect["count_per_attribute"] = base_count + bonus
					else:
						effect["count"] = base_count + bonus
			var ebc := int(effect.get("empower_bonus_cost", 0))
			if ebc > 0:
				var bonus := ebc * empower_amount
				if effect.has("max_cost"):
					effect["max_cost"] = int(effect.get("max_cost", 0)) + bonus
			var ebs := int(effect.get("empower_stat_bonus", 0))
			if ebs > 0:
				var bonus := ebs * empower_amount
				var tmpl = effect.get("card_template", {})
				if typeof(tmpl) == TYPE_DICTIONARY and not tmpl.is_empty():
					tmpl["power"] = int(tmpl.get("power", 0)) + bonus
					tmpl["health"] = int(tmpl.get("health", 0)) + bonus
	# Rebuild rules_text from empowered effect values
	var rules_text := str(display_card.get("rules_text", ""))
	if rules_text.is_empty():
		return
	var new_lines: Array = []
	for line in rules_text.split("\n"):
		if line.begins_with("Empower:"):
			new_lines.append(line + " [+" + str(empower_amount) + "]")
		else:
			new_lines.append(_rewrite_empower_rules_line(line, abilities))
	display_card["rules_text"] = "\n".join(new_lines)


static func _rewrite_empower_rules_line(line: String, abilities: Array) -> String:
	for ability in abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		for effect in ability.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var op := str(effect.get("op", ""))
			if op == "deal_damage" and int(effect.get("empower_bonus", 0)) > 0:
				var amount := int(effect.get("amount", 0))
				# Match patterns like "Deal 3 damage" and replace the number
				var regex := RegEx.new()
				regex.compile("Deal \\d+ damage")
				var result := regex.sub(line, "Deal %d damage" % amount)
				if result != line:
					return result
			elif op == "destroy_creature" and int(effect.get("empower_bonus", 0)) > 0:
				var max_power := int(effect.get("max_power", 0))
				var regex := RegEx.new()
				regex.compile("\\d+ power or less")
				var result := regex.sub(line, "%d power or less" % max_power)
				if result != line:
					return result
			elif op == "banish_from_opponent_deck" and int(effect.get("empower_bonus", 0)) > 0:
				var count := int(effect.get("count_per_attribute", effect.get("count", 0)))
				var regex := RegEx.new()
				regex.compile("top \\d+ cards")
				var result := regex.sub(line, "top %d cards" % count)
				if result != line:
					return result
			elif op == "add_support_uses" and int(effect.get("empower_bonus", 0)) > 0:
				var amount := int(effect.get("amount", 0))
				var regex := RegEx.new()
				regex.compile("\\d+ extra use")
				var result := regex.sub(line, "%d extra use" % amount)
				if result != line:
					return result
			elif op == "summon_random_creature" and int(effect.get("empower_bonus_cost", 0)) > 0:
				var max_cost := int(effect.get("max_cost", 0))
				var regex := RegEx.new()
				regex.compile("\\d+-cost creature")
				var result := regex.sub(line, "%d-cost creature" % max_cost)
				if result != line:
					return result
			elif op == "summon_from_effect" and int(effect.get("empower_stat_bonus", 0)) > 0:
				var tmpl = effect.get("card_template", {})
				if typeof(tmpl) == TYPE_DICTIONARY:
					var p := int(tmpl.get("power", 0))
					var h := int(tmpl.get("health", 0))
					var regex := RegEx.new()
					regex.compile("\\d+/\\d+ Recruit")
					var result := regex.sub(line, "%d/%d Recruit" % [p, h])
					if result != line:
						return result
	return line


func _card_presentation_mode(card: Dictionary, surface: String) -> String:
	match surface:
		"lane":
			return CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_CREATURE_BOARD_MINIMAL if str(card.get("card_type", "")) == "creature" else CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL
		"support":
			return CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_SUPPORT_BOARD_MINIMAL if str(card.get("card_type", "")) == "support" else CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL
		_:
			return CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL


func _add_card_overlay_badges(content_root: Control, card: Dictionary, public_view: bool, surface: String, instance_id: String) -> void:
	if surface == "lane":
		var lane_badges := _build_lane_status_badges(card, instance_id)
		if lane_badges != null:
			content_root.add_child(lane_badges)
	if surface == "hand":
		var hand_badges := _build_hand_emphasis_badges(card, public_view, surface, instance_id)
		if hand_badges != null:
			content_root.add_child(hand_badges)


func _build_lane_status_badges(_card: Dictionary, _instance_id: String) -> HBoxContainer:
	return null


func _lane_readiness_badge_text(card: Dictionary) -> String:
	var cid := str(card.get("instance_id", "?"))
	if str(card.get("controller_player_id", "")) != _active_player_id():
		print("[READINESS] %s -> WAITING (not active player)" % cid)
		return "WAITING"
	if bool(card.get("cannot_attack", false)) or EvergreenRules.has_status(card, EvergreenRules.STATUS_SHACKLED):
		print("[READINESS] %s -> WAITING (cannot_attack=%s shackled=%s)" % [cid, card.get("cannot_attack", false), EvergreenRules.has_status(card, EvergreenRules.STATUS_SHACKLED)])
		return "WAITING"
	if bool(card.get("has_attacked_this_turn", false)):
		var extra := int(card.get("extra_attacks_remaining", 0))
		print("[READINESS] %s has_attacked=true extra_attacks_remaining=%d" % [cid, extra])
		if extra <= 0:
			return "WAITING"
	if _entered_lane_this_turn(card) and not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_CHARGE):
		print("[READINESS] %s -> WAITING (summoning sick: entered_lane_on_turn=%s turn_number=%s)" % [cid, card.get("entered_lane_on_turn", -1), _match_state.get("turn_number", 0)])
		return "WAITING"
	print("[READINESS] %s -> READY" % cid)
	return "READY"


func _build_hand_emphasis_badges(_card: Dictionary, _public_view: bool, _surface: String, _instance_id: String) -> HBoxContainer:
	return null


func _set_mouse_passthrough_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough_recursive(child)


func _build_value_badge(name_prefix: String, text: String, fill: Color, border: Color, font_color: Color, font_size: int, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "%s_badge" % name_prefix
	panel.custom_minimum_size = min_size
	_apply_panel_style(panel, fill, border, 1, 8)
	var box := _build_panel_box(panel, 0, 6)
	var label := Label.new()
	label.name = "%s_label" % name_prefix
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	box.add_child(label)
	return panel


func _build_text_badge(name_prefix: String, text: String, fill: Color, border: Color, font_color: Color, font_size: int, min_size: Vector2) -> PanelContainer:
	return _build_value_badge(name_prefix, text, fill, border, font_color, font_size, min_size)


func _draw_feedback_badge_text(feedback: Dictionary) -> String:
	return "RUNE DRAW" if bool(feedback.get("from_rune_break", false)) else "DRAWN"


func _draw_feedback_badge_fill(feedback: Dictionary) -> Color:
	return Color(0.32, 0.16, 0.09, 0.99) if bool(feedback.get("from_rune_break", false)) else Color(0.15, 0.22, 0.31, 0.99)


func _draw_feedback_badge_border(feedback: Dictionary) -> Color:
	return Color(1.0, 0.79, 0.46, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.66, 0.9, 1.0, 1.0)


func _surface_content_padding(surface: String) -> int:
	match surface:
		"lane":
			return int(round(4.0 * _surface_scale_factor(surface)))
		"hand":
			return int(round(8.0 * _surface_scale_factor(surface)))
		"support":
			return int(round(6.0 * _surface_scale_factor(surface)))
		_:
			return 6


func _surface_art_height(surface: String) -> float:
	match surface:
		"lane":
			return 18.0 * _surface_scale_factor(surface)
		"hand":
			return 64.0 * _surface_scale_factor(surface)
		"support":
			return 48.0 * _surface_scale_factor(surface)
		_:
			return 40.0


func _surface_scale_factor(surface: String) -> float:
	match surface:
		"lane":
			return CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE.x / 136.0
		"hand":
			return CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE.x / 156.0
		"support":
			return CARD_DISPLAY_COMPONENT_SCRIPT.SUPPORT_BOARD_MINIMUM_SIZE.x / 96.0
		_:
			return 1.0


func _surface_name_font_size(surface: String) -> int:
	match surface:
		"lane":
			return 11
		"hand":
			return 14
		"support":
			return 12
		_:
			return 13


func _surface_meta_font_size(surface: String) -> int:
	return 9 if surface == "lane" else 11


func _surface_rules_font_size(surface: String) -> int:
	match surface:
		"lane":
			return 9
		"hand":
			return 10
		"support":
			return 9
		_:
			return 10


func _surface_art_fill(surface: String) -> Color:
	match surface:
		"lane":
			return Color(0.24, 0.19, 0.14, 0.94)
		"support":
			return Color(0.14, 0.22, 0.22, 0.94)
		_:
			return Color(0.19, 0.16, 0.13, 0.94)


func _surface_art_border(surface: String) -> Color:
	match surface:
		"lane":
			return Color(0.62, 0.47, 0.28, 0.9)
		"support":
			return Color(0.42, 0.63, 0.61, 0.9)
		_:
			return Color(0.72, 0.58, 0.34, 0.9)


func _card_type_line(card: Dictionary, surface := "default") -> String:
	var card_type := str(card.get("card_type", "")).capitalize()
	if surface == "lane":
		return card_type
	return "%s • Cost %d" % [card_type, int(card.get("cost", 0))]


func _card_stat_line(card: Dictionary) -> String:
	if str(card.get("card_type", "")) != "creature":
		return ""
	return "%d / %d" % [EvergreenRules.get_power(card), EvergreenRules.get_remaining_health(card)]


func _card_rules_preview(card: Dictionary, surface := "default") -> String:
	var rules_text := str(card.get("rules_text", "")).strip_edges()
	rules_text = rules_text.replace("\n", " ")
	if not rules_text.is_empty():
		if surface == "lane" and rules_text.length() > 40:
			return "%s…" % rules_text.substr(0, 39).strip_edges()
		return rules_text
	if surface == "lane":
		return "Placeholder rules surface."
	return "No final rules text yet. Placeholder frame keeps the identity readable."


func _card_rarity_text(card: Dictionary) -> String:
	var rarity := str(card.get("rarity", "common")).strip_edges().to_lower()
	return "common" if rarity.is_empty() else rarity


func _rarity_color(card: Dictionary) -> Color:
	match _card_rarity_text(card):
		"legendary":
			return Color(0.98, 0.82, 0.42, 1.0)
		"epic":
			return Color(0.78, 0.62, 0.98, 1.0)
		"rare":
			return Color(0.54, 0.82, 0.99, 1.0)
		"uncommon":
			return Color(0.64, 0.9, 0.64, 1.0)
		_:
			return Color(0.86, 0.86, 0.86, 0.96)


func _stat_color(card: Dictionary, stat: String) -> Color:
	var current := EvergreenRules.get_power(card) if stat == "power" else EvergreenRules.get_remaining_health(card)
	var printed := _printed_power(card) if stat == "power" else _printed_health(card)
	if current > printed:
		return Color(0.56, 0.94, 0.56, 1.0)
	if current < printed:
		return Color(0.97, 0.48, 0.43, 1.0)
	return Color(0.98, 0.94, 0.86, 1.0)


func _printed_power(card: Dictionary) -> int:
	if card.has("power"):
		return int(card.get("power", 0))
	if card.has("current_power"):
		return int(card.get("current_power", 0))
	return int(card.get("base_power", 0))


func _printed_health(card: Dictionary) -> int:
	if card.has("health"):
		return int(card.get("health", 0))
	if card.has("current_health"):
		return int(card.get("current_health", 0))
	return int(card.get("base_health", 0))


func _should_mute_card(card: Dictionary, public_view: bool, surface: String) -> bool:
	if surface != "hand" or not public_view or _is_pending_prophecy_card(card):
		return false
	if str(card.get("controller_player_id", "")) != PLAYER_ORDER[1]:
		return false
	var player := _player_state(str(card.get("controller_player_id", "")))
	if player.is_empty():
		return false
	var available := int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
	return int(card.get("cost", 0)) > available


func _should_dim_card_for_turn(card: Dictionary, surface: String, interaction_state: String) -> bool:
	if surface != "hand" and surface != "support" and surface != "lane":
		return false
	if not _should_dim_local_interaction_surfaces():
		return false
	if str(card.get("controller_player_id", "")) != _local_player_id():
		return false
	if _is_pending_prophecy_card(card):
		return false
	if interaction_state == "valid":
		return false
	if str(card.get("instance_id", "")) == _selected_instance_id and _selected_action_mode(card) != SELECTION_MODE_NONE:
		return false
	return true


func _creature_readiness_state(card: Dictionary) -> Dictionary:
	if str(card.get("card_type", "")) != "creature":
		return {
			"id": "default",
			"label": "READY",
			"fill": Color(0.16, 0.28, 0.18, 0.98),
			"border": Color(0.58, 0.9, 0.62, 0.96),
			"font": Color(0.95, 0.99, 0.96, 1.0),
		}
	if bool(card.get("cannot_attack", false)) or EvergreenRules.has_status(card, EvergreenRules.STATUS_SHACKLED):
		return {
			"id": "disabled",
			"label": "DISABLED",
			"fill": Color(0.25, 0.14, 0.28, 0.99),
			"border": Color(0.8, 0.57, 0.93, 0.98),
			"font": Color(0.98, 0.94, 1.0, 1.0),
		}
	if bool(card.get("has_attacked_this_turn", false)):
		if int(card.get("extra_attacks_remaining", 0)) <= 0:
			return {
				"id": "spent",
				"label": "SPENT",
				"fill": Color(0.18, 0.2, 0.26, 0.98),
				"border": Color(0.62, 0.68, 0.78, 0.94),
				"font": Color(0.89, 0.92, 0.98, 1.0),
			}
	if _entered_lane_this_turn(card) and not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_CHARGE):
		return {
			"id": "summoning_sick",
			"label": "SUMMONING SICK",
			"fill": Color(0.31, 0.18, 0.11, 0.99),
			"border": Color(0.96, 0.62, 0.32, 0.98),
			"font": Color(1.0, 0.95, 0.88, 1.0),
		}
	if str(card.get("controller_player_id", "")) == _active_player_id():
		return {
			"id": "ready",
			"label": "READY",
			"fill": Color(0.16, 0.28, 0.18, 0.99),
			"border": Color(0.58, 0.92, 0.61, 0.98),
			"font": Color(0.95, 0.99, 0.96, 1.0),
		}
	return {
		"id": "waiting",
		"label": "WAITING",
		"fill": Color(0.17, 0.2, 0.27, 0.99),
		"border": Color(0.55, 0.67, 0.84, 0.94),
		"font": Color(0.9, 0.94, 0.99, 1.0),
	}


func _entered_lane_this_turn(card: Dictionary) -> bool:
	return int(card.get("entered_lane_on_turn", -1)) == int(_match_state.get("turn_number", 0))


func _clear_pile_selection() -> void:
	_selected_pile_player_id = ""
	_selected_pile_zone = ""



func _on_ring_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		use_ring()


func _on_end_turn_pressed() -> void:
	end_turn_action()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos := (event as InputEventMouseMotion).position
		if not _detached_card_state.is_empty() and _pending_exalt.is_empty():
			var preview: Control = _detached_card_state.get("preview")
			if preview != null and is_instance_valid(preview):
				preview.position = mouse_pos + Vector2(-preview.size.x * 0.5, -preview.size.y * 0.62)
			_update_insertion_preview_from_mouse(mouse_pos)
			_update_sacrifice_hover_from_mouse(mouse_pos)
			_update_sacrifice_hover_label_position()
		if not _targeting_arrow_state.is_empty():
			_update_targeting_arrow(mouse_pos)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.unicode == 34:
			if _error_report_popover == null:
				_open_error_report_popover()
				get_viewport().set_input_as_handled()
				return
		if _error_report_popover != null:
			if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
				var popover := _error_report_popover
				_error_report_popover = null
				popover.dismissed.emit()
				popover.queue_free()
				get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if not _pending_exalt.is_empty():
				_resolve_exalt(false)
				get_viewport().set_input_as_handled()
				return
			if not _pending_betray.is_empty():
				_cancel_betray_mode()
				get_viewport().set_input_as_handled()
				return
			if not _has_match_winner():
				_toggle_pause_menu()
				get_viewport().set_input_as_handled()
				return
		if not _pending_exalt.is_empty():
			get_viewport().set_input_as_handled()
			return
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_UP or key_event.keycode == KEY_DOWN:
				var direction := 1 if key_event.keycode == KEY_DOWN else -1
				if _try_cycle_active_card_relationship(direction):
					get_viewport().set_input_as_handled()
					return
			if key_event.keycode == KEY_E and _is_local_player_turn() and not _has_match_winner():
				if end_turn_action():
					get_viewport().set_input_as_handled()
					return
			if key_event.keycode == KEY_R and _is_local_player_turn() and not _has_match_winner():
				if use_ring():
					get_viewport().set_input_as_handled()
					return
		if key_event.pressed and not key_event.echo and _hovered_hand_instance_id != "" and _hand_selection_state.is_empty():
			var lane_index := -1
			if key_event.keycode == KEY_1:
				lane_index = 0
			elif key_event.keycode == KEY_2:
				lane_index = 1
			if lane_index >= 0:
				_try_play_hovered_hand_card_to_lane(lane_index)
				get_viewport().set_input_as_handled()
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_EQUAL:
			_debug_dump_hovered()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_RIGHT and button_event.pressed:
			if not _pending_exalt.is_empty():
				_resolve_exalt(false)
				get_viewport().set_input_as_handled()
			elif not _hand_selection_state.is_empty():
				_cancel_hand_selection()
				get_viewport().set_input_as_handled()
			elif not _pending_betray.is_empty():
				_cancel_betray_mode()
				get_viewport().set_input_as_handled()
			elif not _pending_secondary_target_state.is_empty():
				# Secondary targets (e.g. Archer's Gambit damage) are mandatory
				get_viewport().set_input_as_handled()
			elif not _pending_summon_target.is_empty():
				if not _is_pending_summon_mandatory():
					_cancel_summon_target_mode()
				get_viewport().set_input_as_handled()
			elif not _targeting_arrow_state.is_empty():
				_cancel_targeting_mode()
				get_viewport().set_input_as_handled()
			elif not _detached_card_state.is_empty():
				_cancel_detached_card()
				get_viewport().set_input_as_handled()
			elif not _selected_instance_id.is_empty():
				clear_selection()
				get_viewport().set_input_as_handled()


func _on_lane_card_gui_input(event: InputEvent, instance_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if button_event.button_index != MOUSE_BUTTON_MIDDLE or not button_event.pressed:
		return
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	if str(card.get("controller_player_id", "")) != PLAYER_ORDER[1]:
		return
	if _selected_action_mode(card) != SELECTION_MODE_ATTACK:
		return
	var enemy_player_id := PLAYER_ORDER[0]
	_selected_instance_id = instance_id
	if _is_player_target_valid_for_selected(enemy_player_id):
		_reset_invalid_feedback()
		attack_selected_player(enemy_player_id)
	else:
		_report_invalid_interaction("Cannot attack face right now.", {"player_ids": [enemy_player_id]})
	get_viewport().set_input_as_handled()


func _on_card_pressed(instance_id: String) -> void:
	if not _pending_exalt.is_empty():
		return
	if not _hand_selection_state.is_empty():
		var candidates: Array = _hand_selection_state.get("candidate_ids", [])
		if candidates.has(instance_id):
			_resolve_hand_selection(instance_id)
		else:
			_report_invalid_interaction("Not a valid selection.", {"instance_ids": [instance_id]})
		return
	if not _pending_betray.is_empty():
		if _pending_betray.has("sacrifice_instance_id"):
			# Betray replay targeting phase — resolve replay target card
			_resolve_betray_replay_target_card(instance_id)
			return
		else:
			# Betray sacrifice selection phase — resolve sacrifice
			_resolve_betray_sacrifice(instance_id)
			return
	if not _pending_secondary_target_state.is_empty():
		_resolve_secondary_target_card(instance_id)
		return
	if not _pending_summon_target.is_empty():
		_resolve_summon_target_card(instance_id)
		return
	if not _targeting_arrow_state.is_empty():
		if _try_resolve_selected_card_target(instance_id):
			return
		# Allow switching to another card that can target
		var switch_card := _card_from_instance_id(instance_id)
		var switch_mode := _selected_action_mode(switch_card)
		var switch_wants_targeting := switch_mode == SELECTION_MODE_ITEM or switch_mode == SELECTION_MODE_ATTACK or (switch_mode == SELECTION_MODE_SUPPORT and _selected_support_uses_card_targets(switch_card))
		if not switch_wants_targeting and switch_mode == SELECTION_MODE_ACTION and _action_needs_explicit_target(switch_card):
			switch_wants_targeting = true
		if switch_wants_targeting:
			_enter_targeting_mode(instance_id)
			return
		_report_invalid_interaction("Not a valid target.", {"instance_ids": [instance_id]})
		return
	if not _detached_card_state.is_empty():
		if _sacrifice_hover_target_id != "" and instance_id == _sacrifice_hover_target_id:
			_resolve_sacrifice_hover()
			return
		var target_card := _card_from_instance_id(instance_id)
		if _try_resolve_selected_support_row_card(target_card):
			return
		if _try_resolve_selected_card_target(instance_id):
			return
		_try_resolve_detached_card_via_lane(instance_id)
		return
	if _is_local_hand_card(instance_id):
		var card := _card_from_instance_id(instance_id)
		var mode := _selected_action_mode(card)
		if mode == SELECTION_MODE_ITEM:
			_enter_targeting_mode(instance_id)
			return
		elif mode == SELECTION_MODE_ACTION:
			if _action_needs_explicit_target(card):
				_enter_targeting_mode(instance_id)
			else:
				_detach_hand_card(instance_id)
			return
		elif mode != SELECTION_MODE_NONE:
			_detach_hand_card(instance_id)
			return
	var target_card := _card_from_instance_id(instance_id)
	if _try_resolve_selected_support_row_card(target_card):
		return
	if _try_resolve_selected_card_target(instance_id):
		return
	# Board cards that can target (attackers, supports with card targets) enter targeting mode
	var board_card := _card_from_instance_id(instance_id)
	var board_mode := _selected_action_mode(board_card)
	if board_mode == SELECTION_MODE_ATTACK or (board_mode == SELECTION_MODE_SUPPORT and _selected_support_uses_card_targets(board_card)):
		_enter_targeting_mode(instance_id)
		return
	# Supports without card targets activate immediately on click
	if board_mode == SELECTION_MODE_SUPPORT and not _selected_support_uses_card_targets(board_card):
		_selected_instance_id = instance_id
		var result := play_or_activate_selected()
		if not bool(result.get("is_valid", false)):
			_report_invalid_interaction(str(result.get("message", "Cannot activate support.")), {"instance_ids": [instance_id]})
		return
	# Ignore clicks on cards that cannot act (spent, shackled, enemy cards, etc.)
	if board_mode == SELECTION_MODE_NONE:
		return
	select_card(instance_id)



func _on_lane_row_gui_input(event: InputEvent, lane_id: String, player_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if not button_event.pressed:
		return
	if button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Betray lane selection: if waiting for a lane for betray replay, resolve it
	if not _pending_betray.is_empty() and bool(_pending_betray.get("is_lane_targeted", false)) and not str(_pending_betray.get("sacrifice_instance_id", "")).is_empty():
		_resolve_betray_replay_lane(lane_id)
		accept_event()
		return
	var card := _selected_card()
	if card.is_empty():
		return
	if not _targeting_arrow_state.is_empty() and _selected_action_mode(card) == SELECTION_MODE_ACTION:
		if _action_needs_explicit_target(card):
			_report_invalid_interaction("Choose a valid target for this action.", {})
			accept_event()
			return
		_play_action_to_lane(lane_id)
		accept_event()
		return
	# Mobilize: item in targeting mode can be played to a lane (summon Recruit + equip)
	if not _targeting_arrow_state.is_empty() and _selected_action_mode(card) == SELECTION_MODE_ITEM:
		if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_MOBILIZE):
			_play_mobilize_item_to_lane(lane_id)
			accept_event()
			return
	if not _selected_support_row_target_player_id(card).is_empty():
		_play_selected_to_support_row(_selected_support_row_target_player_id(card))
		accept_event()
		return
	if _selected_card_wants_lane(card, _target_lane_player_id()):
		if _selected_action_mode(card) == SELECTION_MODE_ACTION:
			_play_action_to_lane(lane_id)
			accept_event()
			return
		var slot_index := _get_insertion_index_or_default(lane_id, _target_lane_player_id())
		if slot_index >= 0:
			var validation := _validate_selected_lane_play(lane_id, _target_lane_player_id(), slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
				accept_event()
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})
				accept_event()


func _on_lane_panel_gui_input(event: InputEvent, lane_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if not button_event.pressed:
		return
	if button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var card := _selected_card()
	if card.is_empty():
		return
	if not _targeting_arrow_state.is_empty() and _selected_action_mode(card) == SELECTION_MODE_ACTION:
		if _action_needs_explicit_target(card):
			_report_invalid_interaction("Choose a valid target for this action.", {})
			accept_event()
			return
		_play_action_to_lane(lane_id)
		accept_event()
		return
	# Mobilize: item in targeting mode can be played to a lane (summon Recruit + equip)
	if not _targeting_arrow_state.is_empty() and _selected_action_mode(card) == SELECTION_MODE_ITEM:
		if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_MOBILIZE):
			_play_mobilize_item_to_lane(lane_id)
			accept_event()
			return
	if not _selected_support_row_target_player_id(card).is_empty():
		_play_selected_to_support_row(_selected_support_row_target_player_id(card))
		accept_event()
		return
	var target_player := _target_lane_player_id()
	if _selected_card_wants_lane(card, target_player):
		if _selected_action_mode(card) == SELECTION_MODE_ACTION:
			_play_action_to_lane(lane_id)
			accept_event()
			return
		var slot_index := _get_insertion_index_or_default(lane_id, target_player)
		if slot_index >= 0:
			var validation := _validate_selected_lane_play(lane_id, target_player, slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
				accept_event()
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})
				accept_event()
		elif _selected_action_mode(card) == SELECTION_MODE_SUMMON and _lane_is_full_with_friendly(lane_id, target_player):
			if not _detached_card_state.is_empty() and _sacrifice_hover_target_id != "":
				_resolve_sacrifice_hover()
			accept_event()


func _on_lane_pressed(lane_id: String) -> void:
	if not _pending_exalt.is_empty():
		return
	var card := _selected_card()
	if not _targeting_arrow_state.is_empty() and _selected_action_mode(card) == SELECTION_MODE_ACTION:
		_play_action_to_lane(lane_id)
		return
	var target_player := _target_lane_player_id()
	if not _selected_support_row_target_player_id(card).is_empty():
		_play_selected_to_support_row(_selected_support_row_target_player_id(card))
		return
	if _selected_card_wants_lane(card, target_player):
		if _selected_action_mode(card) == SELECTION_MODE_ACTION:
			_play_action_to_lane(lane_id)
			return
		var slot_index := _get_insertion_index_or_default(lane_id, target_player)
		if slot_index >= 0:
			var validation := _validate_selected_lane_play(lane_id, target_player, slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})
		return
	_status_message = "Lane details: %s." % _lane_name(lane_id)
	_refresh_ui()




func _on_avatar_gui_input(event: InputEvent, player_id: String) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var btn_idx := (event as InputEventMouseButton).button_index
	if btn_idx == MOUSE_BUTTON_LEFT:
		_on_player_pressed(player_id)
	elif btn_idx == MOUSE_BUTTON_MIDDLE:
		for p in _match_state.get("players", []):
			if str(p.get("player_id", "")) == player_id:
				p["health"] = int(p.get("health", 0)) + 30
				break
		_refresh_ui()
	elif btn_idx == MOUSE_BUTTON_RIGHT and player_id == _local_player_id() and not _adventure_boons.is_empty():
		var overlay := ActiveBoonsOverlay.new()
		add_child(overlay)
		overlay.set_boons(_adventure_boons)


func _on_player_pressed(player_id: String) -> void:
	if not _pending_exalt.is_empty():
		return
	if not _pending_betray.is_empty() and _pending_betray.has("sacrifice_instance_id"):
		_resolve_betray_replay_target_player(player_id)
		return
	if not _pending_secondary_target_state.is_empty():
		_resolve_secondary_target_player(player_id)
		return
	if not _pending_summon_target.is_empty():
		_resolve_summon_target_player(player_id)
		return
	if _try_resolve_selected_player_target(player_id):
		return
	_clear_pile_selection()
	_status_message = "%s selected." % _player_name(player_id)
	_refresh_ui()


func _on_pile_pressed(player_id: String, zone: String) -> void:
	_reset_invalid_feedback()
	_selected_instance_id = ""
	_selected_pile_player_id = player_id
	_selected_pile_zone = zone
	if zone == MatchMutations.ZONE_DISCARD:
		_show_discard_viewer(player_id)
	else:
		_status_message = "Inspecting %s's %s." % [_player_name(player_id), _identifier_to_name(zone)]
		_refresh_ui()


func _on_pile_mouse_entered(player_id: String, zone: String) -> void:
	_hovered_pile_player_id = player_id
	_hovered_pile_zone = zone


func _on_pile_mouse_exited(player_id: String, zone: String) -> void:
	if _hovered_pile_player_id == player_id and _hovered_pile_zone == zone:
		_hovered_pile_player_id = ""
		_hovered_pile_zone = ""


func _on_prophecy_play_pressed(instance_id: String) -> void:
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	_selected_instance_id = instance_id
	var mode := _selected_action_mode(card)
	match mode:
		SELECTION_MODE_SUMMON:
			_detach_prophecy_card(instance_id)
		SELECTION_MODE_ITEM:
			_enter_prophecy_targeting_mode(instance_id)
		SELECTION_MODE_ACTION:
			if _action_needs_explicit_target(card):
				_enter_prophecy_targeting_mode(instance_id)
			else:
				_detach_prophecy_card(instance_id)
				_status_message = "Drop %s onto a lane to play it." % _card_name(card)
				_refresh_ui()
		_:
			play_or_activate_selected()


func _on_prophecy_keep_pressed(instance_id: String) -> void:
	_dismiss_prophecy_overlay()
	decline_prophecy(instance_id)


func _load_registries() -> void:
	_keyword_registry = EvergreenRules.get_registry()
	for keyword in _keyword_registry.get("keywords", []):
		if typeof(keyword) == TYPE_DICTIONARY:
			_keyword_display_names[str(keyword.get("id", ""))] = str(keyword.get("display_name", keyword.get("id", "")))
	for status in _keyword_registry.get("status_markers", []):
		if typeof(status) == TYPE_DICTIONARY:
			_status_display_names[str(status.get("id", ""))] = str(status.get("display_name", status.get("id", "")))
	var file := FileAccess.open(LANE_REGISTRY_PATH, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_lane_registry = parsed



func _selected_card() -> Dictionary:
	return _card_from_instance_id(_selected_instance_id)


func _selected_action_mode(card: Dictionary) -> String:
	if card.is_empty():
		return SELECTION_MODE_NONE
	if MatchTiming.has_pending_prophecy(_match_state) and not _is_pending_prophecy_card(card):
		return SELECTION_MODE_NONE
	if _is_pending_prophecy_card(card):
		var prophecy_type := str(card.get("card_type", ""))
		if prophecy_type == "creature":
			return SELECTION_MODE_SUMMON
		if prophecy_type == "item":
			return SELECTION_MODE_ITEM
		if prophecy_type == "support":
			return SELECTION_MODE_SUPPORT
		if prophecy_type == "action":
			return SELECTION_MODE_ACTION
		return SELECTION_MODE_NONE
	if str(card.get("controller_player_id", "")) != _active_player_id():
		return SELECTION_MODE_NONE
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	if not bool(location.get("is_valid", false)):
		return SELECTION_MODE_NONE
	match str(location.get("zone", "")):
		MatchMutations.ZONE_HAND:
			match str(card.get("card_type", "")):
				"creature":
					return SELECTION_MODE_SUMMON
				"item":
					return SELECTION_MODE_ITEM
				"support":
					return SELECTION_MODE_SUPPORT
				"action":
					return SELECTION_MODE_ACTION
		MatchMutations.ZONE_SUPPORT:
			return SELECTION_MODE_SUPPORT
		MatchMutations.ZONE_LANE:
			if _lane_readiness_badge_text(card) == "READY":
				return SELECTION_MODE_ATTACK
	return SELECTION_MODE_NONE


func _try_resolve_selected_card_target(target_instance_id: String) -> bool:
	var selected_card := _selected_card()
	var target_card := _card_from_instance_id(target_instance_id)
	if selected_card.is_empty() or target_card.is_empty():
		return false
	if not _selected_action_consumes_card_click(target_card):
		return false
	if _is_card_target_valid_for_selected(target_instance_id):
		_reset_invalid_feedback()
		target_selected_card(target_instance_id)
	else:
		_report_invalid_interaction("%s can't target %s right now." % [_card_name(selected_card), _card_name(target_card)], {"instance_ids": [target_instance_id]})
	return true


func _try_resolve_selected_player_target(player_id: String) -> bool:
	var selected_card := _selected_card()
	if selected_card.is_empty():
		return false
	var mode := _selected_action_mode(selected_card)
	if mode == SELECTION_MODE_SUMMON:
		_report_invalid_interaction("Select a lane slot to summon this creature.", {"player_ids": [player_id]})
		return true
	if mode == SELECTION_MODE_ACTION and not _targeting_arrow_state.is_empty():
		var atm := str(selected_card.get("action_target_mode", ""))
		if not atm.is_empty() and atm.find("player") == -1:
			_report_invalid_interaction("%s can only target creatures." % _card_name(selected_card), {"player_ids": [player_id]})
			return true
		var saved_action_id := _selected_instance_id
		var saved_action_card := selected_card.duplicate(true)
		var action_state: Dictionary = _match_state.duplicate(true)
		var controller_id := str(selected_card.get("controller_player_id", ""))
		var validation: Dictionary
		if _is_pending_prophecy_card(selected_card):
			validation = MatchTiming.play_pending_prophecy(action_state, controller_id, _selected_instance_id, {"target_player_id": player_id})
		else:
			validation = MatchTiming.play_action_from_hand(action_state, controller_id, _selected_instance_id, {"target_player_id": player_id})
		if bool(validation.get("is_valid", false)):
			_reset_invalid_feedback()
			if _check_exalt_action(selected_card, {"target_player_id": player_id}, _is_pending_prophecy_card(selected_card)):
				return true
			var result: Dictionary
			if _is_pending_prophecy_card(selected_card):
				result = MatchTiming.play_pending_prophecy(_match_state, controller_id, _selected_instance_id, {"target_player_id": player_id})
			else:
				result = MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id, {"target_player_id": player_id})
			var finalized := _finalize_engine_result(result, "%s targeted %s." % [_card_name(selected_card), _player_name(player_id)])
			if bool(finalized.get("is_valid", false)):
				_check_betray_mode(saved_action_id, saved_action_card)
		else:
			_report_invalid_interaction("%s can't target %s right now." % [_card_name(selected_card), _player_name(player_id)], {"player_ids": [player_id]})
		return true
	if mode != SELECTION_MODE_ATTACK or player_id == _active_player_id():
		return false
	if _is_player_target_valid_for_selected(player_id):
		_reset_invalid_feedback()
		attack_selected_player(player_id)
	else:
		_report_invalid_interaction("%s can't attack %s right now." % [_card_name(selected_card), _player_name(player_id)], {"player_ids": [player_id]})
	return true


func _selected_action_consumes_card_click(target_card: Dictionary) -> bool:
	var selected_card := _selected_card()
	var mode := _selected_action_mode(selected_card)
	if mode == SELECTION_MODE_NONE:
		return false
	var target_location := MatchMutations.find_card_location(_match_state, str(target_card.get("instance_id", "")))
	if not bool(target_location.get("is_valid", false)):
		return false
	var target_zone := str(target_location.get("zone", ""))
	match mode:
		SELECTION_MODE_ITEM:
			return target_zone == MatchMutations.ZONE_LANE
		SELECTION_MODE_ACTION:
			return target_zone == MatchMutations.ZONE_LANE
		SELECTION_MODE_SUPPORT:
			return _selected_support_uses_card_targets(selected_card) and target_zone == MatchMutations.ZONE_LANE
		SELECTION_MODE_ATTACK:
			if target_zone != MatchMutations.ZONE_LANE:
				return false
			var is_enemy := str(target_card.get("controller_player_id", "")) != str(selected_card.get("controller_player_id", ""))
			if is_enemy:
				return true
			var atk_cond: Dictionary = selected_card.get("attack_condition", {})
			return bool(atk_cond.get("can_attack_friendly", false))
	return false


func _selected_card_wants_lane(card: Dictionary, player_id: String) -> bool:
	if card.is_empty() or player_id != _target_lane_player_id():
		return false
	var mode := _selected_action_mode(card)
	if mode == SELECTION_MODE_SUMMON:
		return true
	if mode == SELECTION_MODE_ACTION and not _detached_card_state.is_empty() and not _action_needs_explicit_target(card):
		return true
	return false


func _validate_selected_lane_play(lane_id: String, player_id: String, slot_index: int) -> Dictionary:
	var card := _selected_card()
	if not _selected_card_wants_lane(card, player_id):
		return {"is_valid": false, "message": "Select a creature that can be summoned into %s." % _lane_name(lane_id)}
	if _selected_action_mode(card) == SELECTION_MODE_ACTION:
		var action_state: Dictionary = _match_state.duplicate(true)
		return MatchTiming.play_action_from_hand(action_state, _active_player_id(), _selected_instance_id, {"lane_id": lane_id})
	if _is_pending_prophecy_card(card):
		var prophecy_state: Dictionary = _match_state.duplicate(true)
		return MatchTiming.play_pending_prophecy(prophecy_state, str(card.get("controller_player_id", "")), _selected_instance_id, {"lane_id": lane_id, "slot_index": slot_index})
	return LaneRules.validate_summon_from_hand(_match_state, _active_player_id(), _selected_instance_id, lane_id, {"slot_index": slot_index})


func _is_card_target_valid_for_selected(target_instance_id: String) -> bool:
	var selected_card := _selected_card()
	var mode := _selected_action_mode(selected_card)
	if mode == SELECTION_MODE_NONE:
		return false
	match mode:
		SELECTION_MODE_ITEM:
			var item_state: Dictionary = _match_state.duplicate(true)
			return bool(PersistentCardRules.play_item_from_hand(item_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"target_instance_id": target_instance_id}).get("is_valid", false))
		SELECTION_MODE_ACTION:
			if not _action_target_mode_allows(selected_card, target_instance_id):
				return false
			var action_state: Dictionary = _match_state.duplicate(true)
			if _is_pending_prophecy_card(selected_card):
				return bool(MatchTiming.play_pending_prophecy(action_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"target_instance_id": target_instance_id}).get("is_valid", false))
			return bool(MatchTiming.play_action_from_hand(action_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"target_instance_id": target_instance_id}).get("is_valid", false))
		SELECTION_MODE_SUPPORT:
			if not _selected_support_uses_card_targets(selected_card):
				return false
			var location := MatchMutations.find_card_location(_match_state, target_instance_id)
			if not (bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_LANE):
				return false
			# Validate against target_mode if present (e.g. friendly_creature)
			var support_tm := _get_activate_target_mode(selected_card)
			if not support_tm.is_empty():
				var valid_targets := MatchTiming.get_valid_targets_for_mode(_match_state, _selected_instance_id, support_tm)
				for vt in valid_targets:
					if str(vt.get("instance_id", "")) == target_instance_id:
						return true
				return false
			return true
		SELECTION_MODE_ATTACK:
			return bool(MatchCombat.validate_attack(_match_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"type": "creature", "instance_id": target_instance_id}).get("is_valid", false))
	return false


func _action_needs_explicit_target(card: Dictionary) -> bool:
	var atm := str(card.get("action_target_mode", ""))
	if not atm.is_empty() and atm != "choose_lane":
		return true
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		var tm := str(trigger.get("target_mode", ""))
		if not tm.is_empty() and tm != "creature_in_hand" and tm != "two_creatures" and tm != "three_creatures":
			if not str(trigger.get("secondary_target_mode", "")).is_empty():
				continue  # Dual-target actions go through pending system
			return true
		for effect in trigger.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var target := str(effect.get("target", ""))
			var source_target := str(effect.get("source_target", ""))
			var consumer_target := str(effect.get("consumer_target", ""))
			if target == "event_target" or source_target == "event_target" or consumer_target == "event_target":
				return true
			if str(effect.get("target_player", "")) == "target_player":
				return true
	return false


func _action_target_mode_allows(action_card: Dictionary, target_instance_id: String) -> bool:
	var atm := str(action_card.get("action_target_mode", ""))
	if atm.is_empty():
		return true  # No restriction
	var controller_id := str(action_card.get("controller_player_id", ""))
	var target_card := _card_from_instance_id(target_instance_id)
	if target_card.is_empty():
		return false
	# action_immune: opponent's actions cannot target this creature
	if str(target_card.get("controller_player_id", "")) != controller_id and EvergreenRules.has_raw_status(target_card, "action_immune"):
		return false
	var target_controller := str(target_card.get("controller_player_id", ""))
	var mode_allowed := true
	match atm:
		"friendly_creature", "another_friendly_creature":
			mode_allowed = target_controller == controller_id
		"enemy_creature":
			mode_allowed = target_controller != controller_id
		"wounded_enemy_creature":
			mode_allowed = target_controller != controller_id and EvergreenRules.has_status(target_card, EvergreenRules.STATUS_WOUNDED)
		"wounded_creature":
			mode_allowed = EvergreenRules.has_status(target_card, EvergreenRules.STATUS_WOUNDED)
		"any_creature", "another_creature":
			mode_allowed = true
		"enemy_support_or_neutral_creature":
			if target_controller == controller_id:
				mode_allowed = false
			else:
				var attrs: Array = target_card.get("attributes", [])
				mode_allowed = typeof(attrs) == TYPE_ARRAY and attrs.has("neutral")
		"enemy_creature_or_support":
			mode_allowed = target_controller != controller_id
		"choose_lane":
			mode_allowed = true  # Lane targeting handled by _on_lane_pressed
		"creature_1_power_or_less":
			mode_allowed = EvergreenRules.get_power(target_card) <= 1
		"creature_4_power_or_less":
			mode_allowed = EvergreenRules.get_power(target_card) <= 4
		"creature_4_power_or_more":
			mode_allowed = EvergreenRules.get_power(target_card) >= 4
		"creature_with_0_power":
			mode_allowed = EvergreenRules.get_power(target_card) == 0
		"enemy_creature_3_power_or_less":
			mode_allowed = target_controller != controller_id and EvergreenRules.get_power(target_card) <= 3
		"enemy_creature_and_friendly_creature":
			mode_allowed = true
		"friendly_creature_then_enemy_creature":
			mode_allowed = true
		"any_creature_or_player":
			mode_allowed = true
	if not mode_allowed:
		return false
	# Check triggered_abilities for additional conditions
	for trigger in action_card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		if bool(trigger.get("required_friendly_higher_power", false)):
			var target_power := EvergreenRules.get_power(target_card)
			var has_higher := false
			for lane in _match_state.get("lanes", []):
				for card in lane.get("player_slots", {}).get(controller_id, []):
					if typeof(card) == TYPE_DICTIONARY and EvergreenRules.get_power(card) > target_power:
						has_higher = true
						break
				if has_higher:
					break
			if not has_higher:
				return false
	return true


func _is_player_target_valid_for_selected(player_id: String) -> bool:
	var selected_card := _selected_card()
	if _selected_action_mode(selected_card) != SELECTION_MODE_ATTACK:
		return false
	return bool(MatchCombat.validate_attack(_match_state, str(selected_card.get("controller_player_id", "")), _selected_instance_id, {"type": "player", "player_id": player_id}).get("is_valid", false))


func _lane_cards() -> Array:
	var cards: Array = []
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		for player_id in PLAYER_ORDER:
			for card in _lane_slots(lane_id, player_id):
				if typeof(card) == TYPE_DICTIONARY and not card.is_empty():
					cards.append(card)
	return cards


func _valid_lane_slot_keys() -> Array:
	var keys: Array = []
	if _selected_action_mode(_selected_card()) != SELECTION_MODE_SUMMON:
		return keys
	var player_id := _target_lane_player_id()
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var slots := _lane_slots(lane_id, player_id)
		var slot_capacity := _lane_slot_capacity(lane_id)
		if slots.size() < slot_capacity:
			var append_index := slots.size()
			if bool(_validate_selected_lane_play(lane_id, player_id, append_index).get("is_valid", false)):
				keys.append(_lane_slot_key(lane_id, player_id, append_index))
		elif slots.size() >= slot_capacity and slots.size() > 0:
			# Full lane with friendly creatures — sacrifice-to-play is available
			keys.append(_lane_slot_key(lane_id, player_id, slots.size()))
	return keys


func _valid_lane_ids() -> Array:
	var ids: Array = []
	var card := _selected_card()
	if not _selected_support_row_target_player_id(card).is_empty():
		for lane in _lane_entries():
			ids.append(str(lane.get("id", "")))
		return ids
	if _selected_action_mode(card) == SELECTION_MODE_ACTION and not _detached_card_state.is_empty() and not _action_needs_explicit_target(card):
		for lane in _lane_entries():
			ids.append(str(lane.get("id", "")))
		return ids
	for slot_key in _valid_lane_slot_keys():
		var lane_id := str(slot_key).split(":")[0]
		if not ids.has(lane_id):
			ids.append(lane_id)
	return ids


func _valid_card_target_ids() -> Array:
	var ids: Array = []
	if not _pending_summon_target.is_empty():
		var source_id := str(_pending_summon_target.get("source_instance_id", ""))
		for target_info in MatchTiming.get_all_valid_targets(_match_state, source_id):
			var tid := str(target_info.get("instance_id", ""))
			if not tid.is_empty():
				ids.append(tid)
		return ids
	var mode := _selected_action_mode(_selected_card())
	if mode != SELECTION_MODE_ITEM and mode != SELECTION_MODE_SUPPORT and mode != SELECTION_MODE_ATTACK:
		return ids
	for card in _lane_cards():
		var instance_id := str(card.get("instance_id", ""))
		if _is_card_target_valid_for_selected(instance_id):
			ids.append(instance_id)
	return ids


func _valid_player_target_ids() -> Array:
	var ids: Array = []
	if not _pending_betray.is_empty() and _pending_betray.has("sacrifice_instance_id"):
		var action_card: Dictionary = _pending_betray.get("action_card", {})
		var atm := str(action_card.get("action_target_mode", ""))
		if atm == "creature_or_player" or atm.is_empty():
			for player in _match_state.get("players", []):
				if typeof(player) == TYPE_DICTIONARY:
					ids.append(str(player.get("player_id", "")))
		return ids
	if not _pending_summon_target.is_empty():
		var source_id := str(_pending_summon_target.get("source_instance_id", ""))
		for target_info in MatchTiming.get_all_valid_targets(_match_state, source_id):
			var pid := str(target_info.get("player_id", ""))
			if not pid.is_empty():
				ids.append(pid)
		return ids
	if _selected_action_mode(_selected_card()) != SELECTION_MODE_ATTACK:
		return ids
	for player_id in PLAYER_ORDER:
		if player_id != _active_player_id() and _is_player_target_valid_for_selected(player_id):
			ids.append(player_id)
	return ids




func _card_interaction_state(card: Dictionary, surface: String) -> String:
	var instance_id := str(card.get("instance_id", ""))
	if _copy_array(_invalid_feedback.get("instance_ids", [])).has(instance_id):
		return "invalid"
	if not _pending_betray.is_empty() and surface == "lane":
		if _pending_betray.has("sacrifice_instance_id"):
			# Replay targeting phase — highlight valid replay targets
			var action_card: Dictionary = _pending_betray.get("action_card", {})
			var sacrifice_id := str(_pending_betray.get("sacrifice_instance_id", ""))
			if instance_id != sacrifice_id and ExtendedMechanicPacks._card_matches_target_mode(str(action_card.get("action_target_mode", "")), card, _active_player_id(), _match_state, action_card):
				return "valid"
			return "invalid"
		else:
			# Sacrifice selection phase — highlight friendly creatures
			if str(card.get("controller_player_id", "")) == _active_player_id() and str(card.get("card_type", "")) == "creature":
				var is_targeted: bool = bool(_pending_betray.get("is_targeted", false))
				if is_targeted:
					var action_card: Dictionary = _pending_betray.get("action_card", {})
					if ExtendedMechanicPacks.betray_replay_has_valid_target(_match_state, _active_player_id(), action_card, instance_id):
						return "valid_betray"
				else:
					return "valid_betray"
			return "invalid"
	if not _pending_summon_target.is_empty() and surface == "lane":
		var source_id := str(_pending_summon_target.get("source_instance_id", ""))
		var valid_targets := MatchTiming.get_all_valid_targets(_match_state, source_id)
		for t in valid_targets:
			if str(t.get("instance_id", "")) == instance_id:
				return "valid"
		return "invalid"
	var mode := _selected_action_mode(_selected_card())
	if mode == SELECTION_MODE_ITEM and surface == "lane":
		return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	if mode == SELECTION_MODE_SUPPORT and surface == "lane" and _selected_support_uses_card_targets(_selected_card()):
		return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	if mode == SELECTION_MODE_ATTACK and surface == "lane":
		var selected_card := _selected_card()
		if not selected_card.is_empty() and str(card.get("controller_player_id", "")) != str(selected_card.get("controller_player_id", "")):
			return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	if mode == SELECTION_MODE_ACTION and surface == "lane" and not _targeting_arrow_state.is_empty():
		return "valid" if _is_card_target_valid_for_selected(instance_id) else "invalid"
	return "default"


func _lane_panel_interaction_state(lane_id: String) -> String:
	if _copy_array(_invalid_feedback.get("lane_ids", [])).has(lane_id):
		return "invalid"
	var card := _selected_card()
	var mode := _selected_action_mode(card)
	var wants_lane := mode == SELECTION_MODE_SUMMON or (mode == SELECTION_MODE_ACTION and not _detached_card_state.is_empty() and not _action_needs_explicit_target(card))
	if not wants_lane:
		return "default"
	return "valid" if _valid_lane_ids().has(lane_id) else "invalid"


func _lane_row_interaction_state(lane_id: String, player_id: String) -> String:
	var card := _selected_card()
	var mode := _selected_action_mode(card)
	var wants_lane := mode == SELECTION_MODE_SUMMON or (mode == SELECTION_MODE_ACTION and not _detached_card_state.is_empty() and not _action_needs_explicit_target(card))
	if not wants_lane:
		return "default"
	if player_id != _target_lane_player_id():
		return "default"
	return "valid" if _valid_lane_ids().has(lane_id) else "invalid"



func _can_resolve_selected_action(card: Dictionary) -> bool:
	if card.is_empty():
		_status_message = "Select a card first."
		return false
	if MatchTiming.has_pending_prophecy(_match_state) and not _is_pending_prophecy_card(card):
		_status_message = "Resolve the pending Prophecy before taking other actions."
		return false
	if _is_pending_prophecy_card(card):
		return true
	var controller_player_id := str(card.get("controller_player_id", ""))
	if controller_player_id != _active_player_id():
		_status_message = "Only the active player's public cards can act right now."
		return false
	return true


func _selected_support_row_target_player_id(card: Dictionary) -> String:
	if card.is_empty() or str(card.get("card_type", "")) != "support":
		return ""
	if _is_pending_prophecy_card(card):
		return str(card.get("controller_player_id", ""))
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	if not bool(location.get("is_valid", false)):
		return ""
	return str(card.get("controller_player_id", "")) if str(location.get("zone", "")) == MatchMutations.ZONE_HAND else ""


func _selected_card_wants_support_row(card: Dictionary, player_id: String) -> bool:
	return not player_id.is_empty() and _selected_support_row_target_player_id(card) == player_id


func _selected_support_uses_card_targets(card: Dictionary) -> bool:
	if card.is_empty() or _selected_action_mode(card) != SELECTION_MODE_SUPPORT or _is_pending_prophecy_card(card):
		return false
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	if not (bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_SUPPORT):
		return false
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY or str(trigger.get("family", "")) != "activate":
			continue
		var tm := str(trigger.get("target_mode", ""))
		if not tm.is_empty() and tm != "creature_in_hand" and tm != "choose_lane_and_owner":
			return true
		for effect in trigger.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var target := str(effect.get("target", ""))
			var source_target := str(effect.get("source_target", ""))
			var consumer_target := str(effect.get("consumer_target", ""))
			if target == "event_target" or source_target == "event_target" or consumer_target == "event_target":
				return true
	return false


func _get_activate_target_mode(card: Dictionary) -> String:
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY or str(trigger.get("family", "")) != "activate":
			continue
		var tm := str(trigger.get("target_mode", ""))
		if not tm.is_empty():
			return tm
	return ""


func _validate_selected_support_play(player_id: String) -> Dictionary:
	var card := _selected_card()
	var target_player_id := _selected_support_row_target_player_id(card)
	if target_player_id.is_empty():
		return {"is_valid": false, "message": "Select a support card from hand to place it here."}
	if not _selected_card_wants_support_row(card, player_id):
		return {"is_valid": false, "message": "%s can only be placed into %s's support row." % [_card_name(card), _player_name(target_player_id)]}
	if _is_pending_prophecy_card(card):
		var prophecy_state: Dictionary = _match_state.duplicate(true)
		return MatchTiming.play_pending_prophecy(prophecy_state, str(card.get("controller_player_id", "")), _selected_instance_id)
	var support_state: Dictionary = _match_state.duplicate(true)
	return PersistentCardRules.play_support_from_hand(support_state, str(card.get("controller_player_id", "")), _selected_instance_id)


func _finalize_engine_result(result: Dictionary, success_message: String, clear_selection_on_success := true) -> Dictionary:
	if bool(result.get("is_valid", false)):
		_cancel_detached_card_silent()
		_cancel_targeting_mode_silent()
		_dismiss_prophecy_overlay()
		_reset_invalid_feedback()
		if clear_selection_on_success:
			_selected_instance_id = ""
		_record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = success_message
		if _arena_mode:
			match_state_changed.emit(_match_state.duplicate(true))
	else:
		_status_message = str(result.get("errors", ["Action failed."])[0])
	_refresh_ui()
	if bool(result.get("is_valid", false)):
		_check_pending_secondary_target()
		_check_pending_summon_effect_target()
		_check_pending_forced_play()
	return result


func _invalid_ui_result(message: String) -> Dictionary:
	_status_message = message
	_refresh_ui()
	return {"is_valid": false, "errors": [message]}


func _report_invalid_interaction(message: String, feedback := {}) -> Dictionary:
	_invalid_feedback = {
		"lane_slot_keys": _copy_array(feedback.get("lane_slot_keys", [])),
		"lane_ids": _copy_array(feedback.get("lane_ids", [])),
		"instance_ids": _copy_array(feedback.get("instance_ids", [])),
		"player_ids": _copy_array(feedback.get("player_ids", [])),
	}
	_status_message = message
	_refresh_ui()
	return {"is_valid": false, "errors": [message]}


func _reset_invalid_feedback() -> void:
	_invalid_feedback = {
		"lane_slot_keys": [],
		"lane_ids": [],
		"instance_ids": [],
		"player_ids": [],
	}


func _recent_presentation_events_from_history() -> Array:
	var recent: Array = []
	var history: Array = _match_state.get("event_log", [])
	for index in range(history.size() - 1, -1, -1):
		var event = history[index]
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("event_type", ""))
		if event_type == "turn_started" and not recent.is_empty():
			break
		if event_type == MatchTiming.EVENT_RUNE_BROKEN or event_type == MatchTiming.EVENT_CARD_DRAWN or event_type == MatchTiming.EVENT_PROPHECY_WINDOW_OPENED or event_type == "match_won":
			recent.push_front(event)
			if recent.size() >= 8:
				break
	return recent


func _clear_feedback_state() -> void:
	_attack_feedbacks.clear()
	_damage_feedbacks.clear()
	_removal_feedbacks.clear()
	_draw_feedbacks.clear()
	_rune_feedbacks.clear()


func _record_feedback_from_events(events: Array) -> void:
	if events.is_empty():
		return
	var damage_stacks := {}
	var removal_stacks := {}
	var draw_stacks := {}
	var rune_stacks := {}
	var now := _feedback_now_ms()
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("event_type", ""))
		match event_type:
			"attack_declared":
				_attack_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"attacker_instance_id": str(event.get("attacker_instance_id", "")),
					"attacker_player_id": str(event.get("attacking_player_id", "")),
					"target_type": str(event.get("target_type", "")),
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": str(event.get("target_player_id", "")),
					"expires_at_ms": now + ATTACK_FEEDBACK_DURATION_MS,
				})
			"damage_resolved":
				var damage_target_key := _damage_target_key(event)
				var damage_stack := int(damage_stacks.get(damage_target_key, 0))
				damage_stacks[damage_target_key] = damage_stack + 1
				_damage_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"target_kind": str(event.get("target_type", "")),
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": str(event.get("target_player_id", "")),
					"text": "-%d" % int(event.get("amount", 0)),
					"color": Color(1.0, 0.56, 0.47, 1.0),
					"stack_index": damage_stack,
					"expires_at_ms": now + DAMAGE_FEEDBACK_DURATION_MS,
				})
			"ward_removed":
				var ward_target_key := "creature:%s" % str(event.get("target_instance_id", ""))
				var ward_stack := int(damage_stacks.get(ward_target_key, 0))
				damage_stacks[ward_target_key] = ward_stack + 1
				_damage_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"target_kind": MatchCombat.TARGET_TYPE_CREATURE,
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": "",
					"text": "WARD",
					"color": Color(0.74, 0.9, 1.0, 1.0),
					"stack_index": ward_stack,
					"expires_at_ms": now + DAMAGE_FEEDBACK_DURATION_MS,
				})
			"creature_destroyed":
				var row_key := "%s:%s" % [str(event.get("lane_id", "")), str(event.get("controller_player_id", ""))]
				var removal_stack := int(removal_stacks.get(row_key, 0))
				removal_stacks[row_key] = removal_stack + 1
				var destroyed_card := _card_from_instance_id(str(event.get("instance_id", "")))
				_removal_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"lane_id": str(event.get("lane_id", "")),
					"player_id": str(event.get("controller_player_id", "")),
					"instance_id": str(event.get("instance_id", "")),
					"text": "%s falls" % _card_name(destroyed_card),
					"stack_index": removal_stack,
					"expires_at_ms": now + REMOVAL_FEEDBACK_DURATION_MS,
				})
			"card_drawn":
				var draw_player_id := str(event.get("player_id", ""))
				var draw_stack := int(draw_stacks.get(draw_player_id, 0))
				draw_stacks[draw_player_id] = draw_stack + 1
				var drawn_instance_id := str(event.get("drawn_instance_id", ""))
				var drawn_card := _card_from_instance_id(drawn_instance_id)
				var show_card_name := _should_reveal_drawn_card(draw_player_id, drawn_card)
				_draw_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"player_id": draw_player_id,
					"drawn_instance_id": drawn_instance_id,
					"card_name": _card_name(drawn_card) if show_card_name else "",
					"show_card_name": show_card_name,
					"from_rune_break": str(event.get("reason", "")) == MatchTiming.EVENT_RUNE_BROKEN,
					"stack_index": draw_stack,
					"expires_at_ms": now + DRAW_FEEDBACK_DURATION_MS,
				})
			"rune_broken":
				var rune_player_id := str(event.get("player_id", ""))
				var rune_stack := int(rune_stacks.get(rune_player_id, 0))
				rune_stacks[rune_player_id] = rune_stack + 1
				_rune_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"player_id": rune_player_id,
					"threshold": int(event.get("threshold", -1)),
					"draw_card": bool(event.get("draw_card", false)),
					"stack_index": rune_stack,
					"expires_at_ms": now + RUNE_FEEDBACK_DURATION_MS,
				})
			"card_overdraw":
				var overdraw_instance_id := str(event.get("instance_id", ""))
				var overdraw_card := _card_from_instance_id(overdraw_instance_id)
				if not overdraw_card.is_empty():
					_overdraw_queue.append({
						"card": overdraw_card.duplicate(true),
						"player_id": str(event.get("player_id", "")),
					})
			"opponent_top_deck_revealed":
				if str(event.get("controller_player_id", "")) == _local_player_id():
					var revealed_card: Dictionary = event.get("revealed_card", {})
					if not revealed_card.is_empty():
						_animate_deck_card_reveal(revealed_card)
			"treasure_hunt_revealed":
				if str(event.get("controller_player_id", "")) == _local_player_id():
					var th_card: Dictionary = event.get("revealed_card", {})
					var th_matches := bool(event.get("matches", false))
					if not th_card.is_empty():
						_animate_treasure_hunt_reveal(th_card, th_matches)
			"treasure_found":
				if str(event.get("controller_player_id", "")) == _local_player_id():
					var th_count := int(event.get("count", 1))
					_queue_status_toast("Treasure Found! (%d)" % th_count, Color(1.0, 0.85, 0.3))
			"card_transformed":
				_queue_status_toast("Card transformed!", Color(0.7, 0.5, 1.0))
			"rune_restored":
				_queue_status_toast("Rune restored!", Color(0.4, 0.8, 1.0))
			"lane_type_changed":
				var lt_type := str(event.get("new_type", ""))
				if not lt_type.is_empty():
					_queue_status_toast("%s Lane!" % lt_type.capitalize(), Color(0.6, 0.5, 0.9))
			"status_removed":
				var sr_status := str(event.get("status_id", "")).to_upper().replace("_", " ")
				if not sr_status.is_empty():
					_queue_creature_toast(str(event.get("target_instance_id", "")), "%s REMOVED" % sr_status, Color(0.9, 0.6, 0.3))
			"magicka_restored":
				if str(event.get("target_player_id", "")) == _local_player_id():
					_queue_status_toast("Magicka restored!", Color(0.3, 0.6, 1.0))
			"card_milled":
				_queue_status_toast("Card milled", Color(0.6, 0.5, 0.4))
			"cost_modified":
				var cm_amount := int(event.get("amount", 0))
				var cm_text := "+%d Cost" % cm_amount if cm_amount > 0 else "%d Cost" % cm_amount
				_queue_creature_toast(str(event.get("target_instance_id", "")), cm_text, Color(0.5, 0.4, 0.9))
			"card_stolen_from_discard":
				if str(event.get("to_player_id", "")) == _local_player_id():
					_queue_status_toast("Stole a card from opponent's discard!", Color(0.9, 0.7, 0.2))
			"item_in_hand_modified":
				if str(event.get("target_instance_id", "")) != "":
					var ihm_p := int(event.get("power", 0))
					var ihm_h := int(event.get("health", 0))
					_queue_status_toast("Item buffed +%d/+%d" % [ihm_p, ihm_h], Color(0.8, 0.7, 0.3))
			"keyword_stolen", "status_stolen":
				var ks_id := str(event.get("keyword_id", event.get("status_id", "")))
				_queue_creature_toast(str(event.get("target_instance_id", "")), "-%s" % ks_id.to_upper(), Color(0.9, 0.3, 0.3))
			"marked_for_destruction":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "DOOMED", Color(0.9, 0.2, 0.2))
			"temporary_immunity_granted":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "IMMUNE", Color(1.0, 0.95, 0.6))
			"damage_redirect_set":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "PROTECTED", Color(0.4, 0.7, 1.0))
			"rune_draw_prevented":
				_queue_status_toast("Opponent's next rune draw prevented!", Color(0.8, 0.4, 0.4))
			"creature_marked":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "MARKED", Color(0.9, 0.5, 0.2))
			"creature_aimed_at":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "AIMED", Color(0.9, 0.3, 0.2))
			"marked_for_resummon":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "RESUMMON", Color(0.8, 0.7, 0.3))
			"double_summon_granted":
				if str(event.get("player_id", "")) == _local_player_id():
					_queue_status_toast("Double Summon this turn!", Color(1.0, 0.85, 0.3))
			"action_learned":
				_queue_status_toast("Learned %s!" % str(event.get("learned_card", "")), Color(0.6, 0.7, 1.0))
			"attribute_changed":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "→ %s" % str(event.get("attribute", "")).capitalize(), Color(0.7, 0.6, 0.9))
			"card_shuffled_to_deck":
				_queue_status_toast("Card shuffled into deck", Color(0.5, 0.5, 0.6))
			"card_banished":
				_queue_status_toast("Card banished", Color(0.6, 0.3, 0.6))
			"stats_modified":
				var sm_target_id := str(event.get("target_instance_id", ""))
				var sm_power := int(event.get("power_bonus", 0))
				var sm_health := int(event.get("health_bonus", 0))
				if (sm_power != 0 or sm_health != 0) and not sm_target_id.is_empty():
					var sm_sign_p := "+" if sm_power >= 0 else ""
					var sm_sign_h := "+" if sm_health >= 0 else ""
					var sm_color := Color(0.3, 0.9, 0.4) if (sm_power >= 0 and sm_health >= 0) else Color(0.9, 0.3, 0.3)
					_queue_creature_toast(sm_target_id, "%s%d/%s%d" % [sm_sign_p, sm_power, sm_sign_h, sm_health], sm_color)
			"attached_item_detached":
				_queue_creature_toast(str(event.get("host_instance_id", "")), "ITEM DESTROYED", Color(0.9, 0.4, 0.2))
			"card_discarded":
				_queue_status_toast("Card discarded", Color(0.6, 0.4, 0.4))
			"card_stolen":
				_queue_status_toast("Card stolen!", Color(0.9, 0.6, 0.2))
			"card_consumed":
				_queue_status_toast("Creature consumed", Color(0.5, 0.3, 0.6))
			"keyword_granted":
				var kg_kw := str(event.get("keyword_id", "")).to_upper()
				if not kg_kw.is_empty():
					_queue_creature_toast(str(event.get("target_instance_id", "")), "+%s" % kg_kw, Color(0.4, 0.8, 0.5))
			"ability_granted":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "+ABILITY", Color(0.5, 0.7, 0.9))
			"creatures_swapped":
				_queue_creature_toast(str(event.get("source_instance_id", "")), "SWAPPED", Color(0.8, 0.6, 0.3))
				_queue_creature_toast(str(event.get("target_instance_id", "")), "SWAPPED", Color(0.8, 0.6, 0.3))
			"all_creatures_shuffled":
				_queue_status_toast("All creatures shuffled into decks!", Color(0.7, 0.5, 0.9))
			"summons_retriggered":
				_queue_status_toast("Re-triggering all summon abilities!", Color(0.9, 0.8, 0.3))
			"deck_transformed":
				_queue_status_toast("Deck transformed!", Color(0.7, 0.4, 0.9))
			"mass_consume":
				var mc_count := int(event.get("count", 0))
				_queue_status_toast("Consumed %d creature%s from discard!" % [mc_count, "s" if mc_count != 1 else ""], Color(0.5, 0.3, 0.6))
			"lane_aoe_damage":
				var lad_lane_id := str(event.get("lane_id", ""))
				var lad_amount := int(event.get("amount", 0))
				_queue_status_toast("%d damage to all creatures in lane!" % lad_amount, Color(0.9, 0.3, 0.2))
			"counter_updated":
				var cu_value := int(event.get("value", 0))
				var cu_threshold := int(event.get("threshold", 0))
				_queue_creature_toast(str(event.get("source_instance_id", "")), "%d/%d" % [cu_value, cu_threshold], Color(0.7, 0.6, 0.3))


func _apply_presentation_feedback() -> void:
	_clear_feedback_overlays()
	for feedback in _attack_feedbacks:
		_apply_attack_feedback(feedback)
	for feedback in _damage_feedbacks:
		_apply_damage_feedback(feedback)
	# Removal feedbacks (red lane flash) intentionally skipped
	for feedback in _draw_feedbacks:
		_apply_draw_feedback(feedback)
	for feedback in _rune_feedbacks:
		_apply_rune_feedback(feedback)


func _clear_feedback_overlays() -> void:
	for section in _player_sections.values():
		_clear_feedback_children(section.get("avatar_component"))
		_clear_feedback_children(section.get("hand_row"))
	for row_panel in _lane_row_panels.values():
		_clear_feedback_children(row_panel)


func _clear_feedback_children(node) -> void:
	if not (node is Node):
		return
	for child in (node as Node).get_children():
		if str(child.name).begins_with("feedback_"):
			child.queue_free()
		else:
			_clear_feedback_children(child)


func _apply_attack_feedback(feedback: Dictionary) -> void:
	var attacker_button: Button = _card_buttons.get(str(feedback.get("attacker_instance_id", "")))
	if attacker_button != null:
		_animate_card_motion(attacker_button, _attack_offset_for_player(str(feedback.get("attacker_player_id", ""))), 1.04)
		_add_feedback_banner(attacker_button, "feedback_attack_%s" % str(feedback.get("feedback_id", "0")), "ATTACK", Color(0.36, 0.2, 0.09, 0.98), Color(0.98, 0.78, 0.42, 1.0), Color(1.0, 0.96, 0.87, 1.0), 8.0)
	if str(feedback.get("target_type", "")) == MatchCombat.TARGET_TYPE_CREATURE:
		var defender_button: Button = _card_buttons.get(str(feedback.get("target_instance_id", "")))
		if defender_button != null:
			_animate_card_motion(defender_button, _attack_offset_for_player(str(feedback.get("attacker_player_id", ""))) * -0.38, 1.02)
			_add_feedback_banner(defender_button, "feedback_block_%s" % str(feedback.get("feedback_id", "0")), "BLOCK", Color(0.18, 0.18, 0.24, 0.98), Color(0.76, 0.82, 0.96, 0.96), Color(0.96, 0.98, 1.0, 1.0), 8.0)


func _apply_damage_feedback(feedback: Dictionary) -> void:
	var target_kind := str(feedback.get("target_kind", ""))
	if target_kind == MatchCombat.TARGET_TYPE_CREATURE:
		var target_button: Button = _card_buttons.get(str(feedback.get("target_instance_id", "")))
		if target_button != null:
			_add_feedback_popup(target_button, "feedback_damage_%s" % str(feedback.get("feedback_id", "0")), str(feedback.get("text", "-0")), feedback.get("color", Color(1, 1, 1, 1)), 10.0 + float(feedback.get("stack_index", 0)) * 18.0)
	elif target_kind == MatchCombat.TARGET_TYPE_PLAYER:
		var section: Dictionary = _player_sections.get(str(feedback.get("target_player_id", "")), {})
		var avatar: Control = section.get("avatar_component")
		if avatar != null:
			_add_feedback_popup(avatar, "feedback_damage_%s" % str(feedback.get("feedback_id", "0")), str(feedback.get("text", "-0")), feedback.get("color", Color(1, 1, 1, 1)), 12.0 + float(feedback.get("stack_index", 0)) * 18.0)


func _apply_removal_feedback(feedback: Dictionary) -> void:
	var row_key := _lane_row_key(str(feedback.get("lane_id", "")), str(feedback.get("player_id", "")))
	var row_panel: PanelContainer = _lane_row_panels.get(row_key)
	if row_panel == null:
		return
	var toast := PanelContainer.new()
	toast.name = "feedback_removal_%s" % str(feedback.get("feedback_id", "0"))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_right = 1.0
	toast.offset_left = 14
	toast.offset_right = -14
	toast.offset_top = 42.0 + float(feedback.get("stack_index", 0)) * 24.0
	toast.offset_bottom = toast.offset_top + 24.0
	toast.z_index = 20
	_apply_panel_style(toast, Color(0.32, 0.12, 0.12, 0.96), Color(0.96, 0.55, 0.46, 0.98), 1, 6)
	row_panel.add_child(toast)
	var toast_box := _build_panel_box(toast, 0, 4)
	var toast_label := Label.new()
	toast_label.name = "%s_label" % toast.name
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 11)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.92, 1.0))
	toast_label.text = str(feedback.get("text", "Creature removed"))
	toast_box.add_child(toast_label)
	var tween := create_tween()
	tween.tween_property(toast, "position", Vector2(0, -14), 0.2)
	tween.parallel().tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.8)
	tween.finished.connect(_queue_free_weak.bind(weakref(toast)))


func _apply_draw_feedback(feedback: Dictionary) -> void:
	var player_id := str(feedback.get("player_id", ""))
	var section: Dictionary = _player_sections.get(player_id, {})
	var avatar: Control = section.get("avatar_component")
	if avatar != null:
		_add_feedback_popup(avatar, "feedback_draw_popup_%s" % str(feedback.get("feedback_id", "0")), _draw_feedback_popup_text(feedback), _draw_feedback_popup_color(feedback), 14.0 + float(feedback.get("stack_index", 0)) * 18.0)
	var hand_row: Control = section.get("hand_row")
	if hand_row != null:
		_add_feedback_toast(hand_row, "feedback_draw_toast_%s" % str(feedback.get("feedback_id", "0")), _draw_feedback_toast_text(feedback), _draw_feedback_toast_fill(feedback), _draw_feedback_toast_border(feedback), Color(1.0, 0.97, 0.93, 1.0), 10.0 + float(feedback.get("stack_index", 0)) * 24.0)
	var drawn_instance_id := str(feedback.get("drawn_instance_id", ""))
	var card_button: Button = _card_buttons.get(drawn_instance_id)
	if card_button != null:
		_add_feedback_banner(card_button, "feedback_draw_banner_%s" % str(feedback.get("feedback_id", "0")), _draw_feedback_badge_text(feedback), _draw_feedback_toast_fill(feedback), _draw_feedback_toast_border(feedback), Color(1.0, 0.97, 0.92, 1.0), 8.0)


func _apply_rune_feedback(feedback: Dictionary) -> void:
	var player_id := str(feedback.get("player_id", ""))
	var section: Dictionary = _player_sections.get(player_id, {})
	var avatar_component = section.get("avatar_component")
	if avatar_component != null:
		_add_feedback_toast(avatar_component, "feedback_rune_toast_%s" % str(feedback.get("feedback_id", "0")), _rune_feedback_toast_text(feedback), Color(0.31, 0.13, 0.11, 0.98), Color(1.0, 0.73, 0.42, 1.0), Color(1.0, 0.95, 0.89, 1.0), 8.0 + float(feedback.get("stack_index", 0)) * 22.0)
		var token_panel = avatar_component.get_rune_anchor(int(feedback.get("threshold", -1)))
		if token_panel is Control:
			_add_feedback_banner_over_target(avatar_component as Control, token_panel as Control, "feedback_rune_banner_%s" % str(feedback.get("feedback_id", "0")), "SHATTER", Color(0.39, 0.14, 0.09, 0.99), Color(1.0, 0.78, 0.48, 1.0), Color(1.0, 0.96, 0.9, 1.0), 4.0)


func _process_overdraw_queue() -> void:
	if _overdraw_queue.is_empty():
		return
	var entry: Dictionary = _overdraw_queue.pop_front()
	_animate_overdraw_card(entry.get("card", {}), str(entry.get("player_id", "")))


func _animate_overdraw_card(card: Dictionary, player_id: String) -> void:
	if card.is_empty() or _prophecy_card_overlay == null:
		if not _overdraw_queue.is_empty():
			_process_overdraw_queue()
		return

	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size
	var is_local := player_id == PLAYER_ORDER[1]

	# Build a card display container
	var card_panel := PanelContainer.new()
	card_panel.name = "overdraw_card"
	card_panel.custom_minimum_size = card_size
	card_panel.size = card_size
	_apply_panel_style(card_panel, Color(0.12, 0.10, 0.10, 0.98), Color(0.55, 0.18, 0.18, 0.92), 2, 0)

	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	card_panel.add_child(component)

	# Position just above the player's hand area (bottom-center)
	var pos_x := (viewport_size.x - card_size.x) * 0.5
	var base_y: float
	if is_local:
		base_y = viewport_size.y - card_size.y - card_size.y * 0.35
	else:
		base_y = card_size.y * 0.10
	card_panel.position = Vector2(pos_x, base_y)
	card_panel.pivot_offset = Vector2(card_size.x * 0.5, card_size.y * 0.5)
	card_panel.scale = Vector2(0.7, 0.7)
	card_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card_panel.z_index = 500
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prophecy_card_overlay.add_child(card_panel)

	# Animate: fade in + scale up, hold, then fall off-screen with rotation
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_panel, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_panel, "modulate:a", 1.0, 0.3)
	tween.set_parallel(false)
	tween.tween_interval(1.2)
	# Fall off bottom with rotation
	var fall_target_y := viewport_size.y + card_size.y
	var rotation_dir := 1.0 if fmod(abs(card_panel.position.x), 2.0) > 1.0 else -1.0
	tween.set_parallel(true)
	tween.tween_property(card_panel, "position:y", fall_target_y, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_panel, "rotation_degrees", rotation_dir * 25.0, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_panel, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(func():
		card_panel.queue_free()
		# Process next queued overdraw if any
		if not _overdraw_queue.is_empty():
			_process_overdraw_queue()
	)


func _apply_card_feedback_decoration(button: Button, card: Dictionary, surface: String) -> void:
	var instance_id := str(card.get("instance_id", ""))
	var modulate_color := Color(1, 1, 1, 1)
	var applied_damage := false
	if surface == "lane" and str(card.get("card_type", "")) == "creature":
		for feedback in _damage_feedbacks:
			if str(feedback.get("target_kind", "")) == MatchCombat.TARGET_TYPE_CREATURE and str(feedback.get("target_instance_id", "")) == instance_id:
				modulate_color = Color(1.0, 0.92, 0.92, 1.0)
				applied_damage = true
				break
	if surface == "hand":
		pass
	button.modulate = modulate_color


func _refresh_avatar_target_glow(avatar: Control, player_id: String) -> void:
	var existing := avatar.find_child("avatar_target_glow", false, false)
	if existing != null:
		avatar.remove_child(existing)
		existing.queue_free()
	var valid_ids := _valid_player_target_ids()
	if not valid_ids.has(player_id):
		return
	var glow_shader := load("res://assets/shaders/avatar_target_glow.gdshader") as Shader
	if glow_shader == null:
		return
	var glow_pad := 20.0
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_shader
	var glow := ColorRect.new()
	glow.name = "avatar_target_glow"
	glow.material = glow_mat
	glow.color = Color.WHITE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -glow_pad
	glow.offset_top = -glow_pad
	glow.offset_right = glow_pad
	glow.offset_bottom = glow_pad
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.clip_contents = false
	avatar.add_child(glow)
	avatar.move_child(glow, 0)


func _apply_valid_target_glow(button: Button, surface: String) -> void:
	var glow_shader := load("res://assets/shaders/valid_target_glow.gdshader") as Shader
	if glow_shader == null:
		return
	var card_size := _surface_button_minimum_size(surface)
	var glow_pad := 16.0
	var total_size := card_size + Vector2(glow_pad * 2.0, glow_pad * 2.0)
	var padding_uv := Vector2(glow_pad / total_size.x, glow_pad / total_size.y)
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_shader
	glow_mat.set_shader_parameter("glow_color", Color(0.9, 0.92, 0.95, 1.0))
	glow_mat.set_shader_parameter("pulse_speed", 1.8)
	glow_mat.set_shader_parameter("glow_intensity", 0.28)
	glow_mat.set_shader_parameter("corner_radius", 0.04)
	glow_mat.set_shader_parameter("padding_uv", padding_uv)
	var glow := ColorRect.new()
	glow.name = "valid_target_glow"
	glow.material = glow_mat
	glow.color = Color.WHITE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -glow_pad
	glow.offset_top = -glow_pad
	glow.offset_right = glow_pad
	glow.offset_bottom = glow_pad
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.clip_contents = false
	button.add_child(glow)
	button.move_child(glow, 0)


func _apply_betray_target_glow(button: Button, surface: String) -> void:
	var glow_shader := load("res://assets/shaders/valid_target_glow.gdshader") as Shader
	if glow_shader == null:
		return
	var card_size := _surface_button_minimum_size(surface)
	var glow_pad := 16.0
	var total_size := card_size + Vector2(glow_pad * 2.0, glow_pad * 2.0)
	var padding_uv := Vector2(glow_pad / total_size.x, glow_pad / total_size.y)
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_shader
	glow_mat.set_shader_parameter("glow_color", Color(0.95, 0.2, 0.15, 1.0))
	glow_mat.set_shader_parameter("pulse_speed", 1.8)
	glow_mat.set_shader_parameter("glow_intensity", 0.35)
	glow_mat.set_shader_parameter("corner_radius", 0.04)
	glow_mat.set_shader_parameter("padding_uv", padding_uv)
	var glow := ColorRect.new()
	glow.name = "valid_target_glow"
	glow.material = glow_mat
	glow.color = Color.WHITE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -glow_pad
	glow.offset_top = -glow_pad
	glow.offset_right = glow_pad
	glow.offset_bottom = glow_pad
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.clip_contents = false
	button.add_child(glow)
	button.move_child(glow, 0)


func _apply_lane_card_float_effect(button: Button, card: Dictionary) -> void:
	var readiness := _creature_readiness_state(card)
	var instance_id := str(card.get("instance_id", ""))
	if str(readiness.get("id", "")) != "ready":
		_floating_card_ids.erase(instance_id)
		return
	var content_root: Control = button.get_meta("content_root", null)
	if content_root == null:
		return
	button.clip_contents = false
	# Hide the button's own background so its border doesn't outline the shadow
	_apply_button_style(button, Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	# Shader-based soft shadow to simulate an overhead light source
	var shadow_shader := load("res://assets/shaders/soft_shadow.gdshader") as Shader
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = shadow_shader
	shadow_mat.set_shader_parameter("blur_radius", 0.14)
	shadow_mat.set_shader_parameter("shadow_alpha", 0.82)
	var shadow := ColorRect.new()
	shadow.name = "float_shadow"
	shadow.material = shadow_mat
	shadow.color = Color.WHITE
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Pad the shadow rect so the blur has room to feather out beyond the card edges
	var shadow_pad := 10.0
	shadow.offset_left = LANE_CARD_FLOAT_SHADOW_OFFSET.x - shadow_pad
	shadow.offset_top = LANE_CARD_FLOAT_SHADOW_OFFSET.y - shadow_pad
	shadow.offset_right = LANE_CARD_FLOAT_SHADOW_OFFSET.x + shadow_pad
	shadow.offset_bottom = LANE_CARD_FLOAT_SHADOW_OFFSET.y + shadow_pad
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shadow)
	button.move_child(shadow, 0)
	# Float content up and to the left
	var already_floating := _floating_card_ids.has(instance_id)
	_floating_card_ids[instance_id] = true
	if already_floating:
		# Already floated on a prior refresh – snap to offset immediately
		content_root.offset_left = LANE_CARD_FLOAT_OFFSET.x
		content_root.offset_top = LANE_CARD_FLOAT_OFFSET.y
		content_root.offset_right = LANE_CARD_FLOAT_OFFSET.x
		content_root.offset_bottom = LANE_CARD_FLOAT_OFFSET.y
		shadow.modulate.a = 1.0
		_start_lane_card_bob(button, content_root, shadow)
	else:
		# First time floating – animate the rise and shadow fade-in
		shadow.modulate.a = 0.0
		var tween := button.create_tween()
		tween.set_parallel(true)
		tween.tween_property(content_root, "offset_left", LANE_CARD_FLOAT_OFFSET.x, LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(content_root, "offset_top", LANE_CARD_FLOAT_OFFSET.y, LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(content_root, "offset_right", LANE_CARD_FLOAT_OFFSET.x, LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(content_root, "offset_bottom", LANE_CARD_FLOAT_OFFSET.y, LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(shadow, "modulate:a", 1.0, LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.finished.connect(_start_lane_card_bob.bind(button, content_root, shadow))


func _start_lane_card_bob(button: Button, content_root: Control, shadow: ColorRect) -> void:
	if not is_instance_valid(button) or not is_instance_valid(content_root):
		return
	var base_y := LANE_CARD_FLOAT_OFFSET.y
	var bob_top := base_y - LANE_CARD_BOB_AMPLITUDE
	var bob_bottom := base_y
	var half := LANE_CARD_BOB_DURATION * 0.5
	var bob_tween := button.create_tween()
	bob_tween.set_loops()
	# Bob up – both offsets move together
	bob_tween.tween_property(content_root, "offset_top", bob_top, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.parallel().tween_property(content_root, "offset_bottom", bob_top, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Bob down – runs after the up phase completes
	bob_tween.tween_property(content_root, "offset_top", bob_bottom, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.parallel().tween_property(content_root, "offset_bottom", bob_bottom, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _add_feedback_banner(container: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	var banner := PanelContainer.new()
	banner.name = name
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.anchor_right = 1.0
	banner.offset_left = 8
	banner.offset_right = -8
	banner.offset_top = top_offset
	banner.offset_bottom = top_offset + 20.0
	banner.z_index = 12
	_apply_panel_style(banner, fill, border, 1, 6)
	container.add_child(banner)
	var box := _build_panel_box(banner, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(_queue_free_weak.bind(weakref(banner)))


func _add_feedback_banner_over_target(container: Control, target: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	if container == null or target == null:
		return
	var target_origin := container.get_global_transform_with_canvas().affine_inverse() * target.get_global_transform_with_canvas().origin
	var banner_size := Vector2(maxf(target.size.x + 28.0, 54.0), 20.0)
	var banner_position := Vector2(target_origin.x + (target.size.x - banner_size.x) * 0.5, target_origin.y + top_offset)
	if container.size.x > 0.0:
		banner_position.x = clampf(banner_position.x, 0.0, maxf(container.size.x - banner_size.x, 0.0))
	if container.size.y > 0.0:
		banner_position.y = clampf(banner_position.y, 0.0, maxf(container.size.y - banner_size.y, 0.0))
	var banner := PanelContainer.new()
	banner.name = name
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.position = banner_position
	banner.size = banner_size
	banner.z_index = 12
	_apply_panel_style(banner, fill, border, 1, 6)
	container.add_child(banner)
	var box := _build_panel_box(banner, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(_queue_free_weak.bind(weakref(banner)))


func _add_feedback_popup(container: Control, name: String, text: String, font_color: Color, top_offset: float) -> void:
	var label := Label.new()
	label.name = name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_right = 1.0
	label.offset_left = 0
	label.offset_right = 0
	label.offset_top = top_offset
	label.offset_bottom = top_offset + 26.0
	label.z_index = 18
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	container.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", Vector2(0, -24), 0.22)
	tween.parallel().tween_property(label, "scale", Vector2(1.08, 1.08), 0.18)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.7)
	tween.finished.connect(_queue_free_weak.bind(weakref(label)))


func _add_feedback_toast(container: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	var toast := PanelContainer.new()
	toast.name = name
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_right = 1.0
	toast.offset_left = 12
	toast.offset_right = -12
	toast.offset_top = top_offset
	toast.offset_bottom = top_offset + 24.0
	toast.z_index = 18
	_apply_panel_style(toast, fill, border, 1, 7)
	container.add_child(toast)
	var box := _build_panel_box(toast, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.parallel().tween_property(toast, "position", Vector2(0, -10), 0.26)
	tween.tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.75)
	tween.finished.connect(_queue_free_weak.bind(weakref(toast)))


func _queue_status_toast(text: String, color: Color) -> void:
	var viewport_size := get_viewport_rect().size
	var label := Label.new()
	label.name = "feedback_status_toast"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 500
	label.set_anchors_preset(PRESET_CENTER_TOP)
	label.offset_top = viewport_size.y * 0.42
	label.offset_left = -200
	label.offset_right = 200
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.3)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(_queue_free_weak.bind(weakref(label)))


func _queue_creature_toast(instance_id: String, text: String, color: Color) -> void:
	var button: Button = _card_buttons.get(instance_id)
	if button == null or not is_instance_valid(button):
		return
	_add_feedback_popup(button, "feedback_toast_%s" % instance_id, text, color, 10.0)


func _animate_treasure_hunt_reveal(revealed_card: Dictionary, matches: bool) -> void:
	var card_size := _hand_card_display_size()
	var viewport_size := get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "treasure_hunt_reveal"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	var back_color := Color(0.35, 0.22, 0.12, 0.98)
	_apply_panel_style(card_back, back_color, Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x := (viewport_size.x - card_size.x) * 0.5
	var pos_y := viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)
	card_back.z_index = 600

	_prophecy_card_overlay.add_child(card_back)

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween := create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(revealed_card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_back.add_child(component)
		# Add match/miss banner
		var banner := Label.new()
		banner.name = "treasure_hunt_banner"
		banner.text = "MATCH!" if matches else "MISS"
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_theme_font_size_override("font_size", 20)
		banner.add_theme_color_override("font_color", Color(0.1, 1.0, 0.3) if matches else Color(0.9, 0.3, 0.2))
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.z_index = 10
		banner.anchor_right = 1.0
		banner.offset_top = card_size.y - 36.0
		banner.offset_bottom = card_size.y - 10.0
		card_back.add_child(banner)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(card_back, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func():
		if is_instance_valid(card_back):
			card_back.queue_free()
		_refresh_ui()
	)


func _should_reveal_drawn_card(player_id: String, card: Dictionary) -> bool:
	if card.is_empty():
		return false
	if _is_hand_public(player_id):
		return true
	return _is_pending_prophecy_card(card)


func _active_draw_feedback_for_instance(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for feedback in _draw_feedbacks:
		if str(feedback.get("drawn_instance_id", "")) == instance_id:
			return feedback
	return {}


func _draw_feedback_popup_text(feedback: Dictionary) -> String:
	if bool(feedback.get("show_card_name", false)):
		return "+ %s" % str(feedback.get("card_name", "Card"))
	return "+1 CARD"


func _draw_feedback_popup_color(feedback: Dictionary) -> Color:
	return Color(1.0, 0.81, 0.48, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.72, 0.91, 1.0, 1.0)


func _draw_feedback_toast_text(feedback: Dictionary) -> String:
	var prefix := "RUNE DRAW" if bool(feedback.get("from_rune_break", false)) else "DRAW"
	if bool(feedback.get("show_card_name", false)):
		return "%s • %s" % [prefix, str(feedback.get("card_name", "Card"))]
	return "%s • card added to hand" % prefix


func _draw_feedback_toast_fill(feedback: Dictionary) -> Color:
	return Color(0.32, 0.16, 0.09, 0.98) if bool(feedback.get("from_rune_break", false)) else Color(0.14, 0.22, 0.31, 0.98)


func _draw_feedback_toast_border(feedback: Dictionary) -> Color:
	return Color(1.0, 0.79, 0.46, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.66, 0.9, 1.0, 1.0)


func _rune_feedback_toast_text(feedback: Dictionary) -> String:
	var threshold := int(feedback.get("threshold", -1))
	var draw_suffix := " • draw triggered" if bool(feedback.get("draw_card", false)) else ""
	if threshold > 0:
		return "RUNE %d SHATTERED%s" % [threshold, draw_suffix]
	return "RUNE BREAK%s" % draw_suffix


func _animate_card_motion(button: Button, offset: Vector2, end_scale: float) -> void:
	var content_variant = button.get_meta("content_root", null)
	if not (content_variant is Control):
		return
	var content := content_variant as Control
	content.pivot_offset = Vector2(button.custom_minimum_size.x * 0.5, button.custom_minimum_size.y * 0.5)
	content.position = Vector2.ZERO
	content.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(content, "position", offset, 0.11)
	tween.parallel().tween_property(content, "scale", Vector2(end_scale, end_scale), 0.11)
	tween.tween_property(content, "position", Vector2.ZERO, 0.16)
	tween.parallel().tween_property(content, "scale", Vector2.ONE, 0.16)


func _attack_offset_for_player(player_id: String) -> Vector2:
	return Vector2(0, 16) if player_id == PLAYER_ORDER[0] else Vector2(0, -16)


func _damage_target_key(event: Dictionary) -> String:
	var target_type := str(event.get("target_type", ""))
	if target_type == MatchCombat.TARGET_TYPE_PLAYER:
		return "player:%s" % str(event.get("target_player_id", ""))
	return "creature:%s" % str(event.get("target_instance_id", ""))


func _prune_feedback_state() -> void:
	var now := _feedback_now_ms()
	_attack_feedbacks = _feedbacks_after(_attack_feedbacks, now)
	_damage_feedbacks = _feedbacks_after(_damage_feedbacks, now)
	_removal_feedbacks = _feedbacks_after(_removal_feedbacks, now)
	_draw_feedbacks = _feedbacks_after(_draw_feedbacks, now)
	_rune_feedbacks = _feedbacks_after(_rune_feedbacks, now)


func _feedbacks_after(entries: Array, now: int) -> Array:
	var remaining: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if int(entry.get("expires_at_ms", 0)) > now:
			remaining.append(entry)
	return remaining


func _feedback_now_ms() -> int:
	return Time.get_ticks_msec()


func _next_feedback_id() -> int:
	_feedback_sequence += 1
	return _feedback_sequence


func _copy_array(value) -> Array:
	return value.duplicate() if typeof(value) == TYPE_ARRAY else []


func _card_from_instance_id(instance_id: String) -> Dictionary:
	if instance_id.is_empty() or _match_state.is_empty():
		return {}
	var location := MatchMutations.find_card_location(_match_state, instance_id)
	if bool(location.get("is_valid", false)):
		return location.get("card", {})
	for window in MatchTiming.get_pending_prophecies(_match_state):
		if str(window.get("instance_id", "")) == instance_id:
			return _find_card_in_player_hand(str(window.get("player_id", "")), instance_id)
	return {}


func _find_card_in_player_hand(player_id: String, instance_id: String) -> Dictionary:
	var player := _player_state(player_id)
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
			return card
	return {}


func _player_state(player_id: String) -> Dictionary:
	for player in _match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


func _active_player_id() -> String:
	return str(_match_state.get("active_player_id", ""))


func _local_player_id() -> String:
	return PLAYER_ORDER[1]


func _enemy_player_id() -> String:
	return PLAYER_ORDER[0]


func _is_local_player_turn() -> bool:
	return _active_player_id() == _local_player_id()


func _should_dim_local_interaction_surfaces() -> bool:
	return not _is_local_player_turn() and not _local_player_has_pending_interrupt()


func _should_dim_local_surface(player_id: String) -> bool:
	return player_id == _local_player_id() and _should_dim_local_interaction_surfaces()


func _has_pending_prophecy_for_player(player_id: String) -> bool:
	return not MatchTiming.get_pending_prophecies(_match_state, player_id).is_empty()


func _is_local_prophecy_interrupt_open() -> bool:
	return _has_pending_prophecy_for_player(_local_player_id())


func _local_player_has_pending_interrupt() -> bool:
	return _is_local_prophecy_interrupt_open() or not _pending_summon_target.is_empty() or not _pending_secondary_target_state.is_empty() or _has_local_pending_discard_choice() or _has_local_pending_consume_selection() or _has_local_pending_deck_selection() or not _hand_selection_state.is_empty() or MatchTiming.has_pending_summon_effect_target(_match_state, _local_player_id()) or MatchTiming.has_pending_forced_play(_match_state, _local_player_id())


func _is_local_match_ai_enabled() -> bool:
	return _ai_enabled or _scenario_id == LOCAL_MATCH_AI_SCENARIO_ID


func _ai_player_id() -> String:
	return PLAYER_ORDER[0]


func _ai_controls_current_decision_window() -> bool:
	if not _is_local_match_ai_enabled() or _has_match_winner():
		return false
	if _local_player_has_pending_interrupt():
		return false
	var ai_player_id := _ai_player_id()
	if MatchTiming.has_pending_hand_selection(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_discard_choice(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_player_choice(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_secondary_target(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_consume_selection(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_deck_selection(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_summon_effect_target(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_turn_trigger_target(_match_state, ai_player_id):
		return true
	if MatchTiming.has_pending_prophecy(_match_state):
		return _has_pending_prophecy_for_player(ai_player_id)
	return _active_player_id() == ai_player_id


func _target_lane_player_id() -> String:
	if _is_pending_prophecy_card(_selected_card()):
		return str(_selected_card().get("controller_player_id", ""))
	return _active_player_id()


func _player_name(player_id: String) -> String:
	var player := _player_state(player_id)
	if player.is_empty():
		return player_id
	return str(player.get("display_name", player_id))


func _turn_state_text() -> String:
	return "Your Turn" if _is_local_player_turn() else "Opponent's Turn"



func _turn_state_fill() -> Color:
	return Color(0.34, 0.19, 0.09, 0.98) if _is_local_player_turn() else Color(0.12, 0.17, 0.28, 0.97)


func _turn_state_border() -> Color:
	return Color(0.99, 0.78, 0.44, 1.0) if _is_local_player_turn() else Color(0.62, 0.81, 0.99, 0.98)


func _turn_state_font_color() -> Color:
	return Color(1.0, 0.96, 0.9, 1.0) if _is_local_player_turn() else Color(0.92, 0.96, 1.0, 1.0)


func _refresh_turn_presentation() -> void:
	var active_player := _active_player_id()
	if active_player.is_empty():
		return
	if active_player != _last_turn_owner_id:
		_last_turn_owner_id = active_player
		_floating_card_ids.clear()
		_turn_banner_until_ms = Time.get_ticks_msec() + TURN_BANNER_DURATION_MS
		if active_player == _ai_player_id() and _is_local_match_ai_enabled():
			_arm_local_match_ai_turn_pacing()
		else:
			_reset_local_match_ai_queue()
	if _turn_banner_panel != null:
		_apply_panel_style(_turn_banner_panel, _turn_state_fill(), _turn_state_border(), 2, 14)
		_turn_banner_panel.visible = _turn_banner_until_ms > Time.get_ticks_msec()
	if _turn_banner_label != null:
		_turn_banner_label.text = _turn_state_text()
		_turn_banner_label.add_theme_color_override("font_color", _turn_state_font_color())
	if _turn_banner_detail_label != null:
		var detail_text := _player_name(active_player)
		var local_player := _player_state(_local_player_id())
		if local_player.has("wax_wane_state"):
			var ww_phase := str(local_player.get("wax_wane_state", "wax"))
			var ww_icon := "Waxing" if ww_phase == "wax" else "Waning"
			detail_text += "  |  Moon: %s" % ww_icon
		_turn_banner_detail_label.text = detail_text
		_turn_banner_detail_label.add_theme_color_override("font_color", _turn_state_font_color().lerp(Color(0.8, 0.84, 0.92, 0.96), 0.32))



func _refresh_match_end_overlay() -> void:
	if _match_end_overlay == null:
		return
	var winner_player_id := _match_winner_id()
	var visible := not winner_player_id.is_empty()
	_match_end_overlay.visible = visible
	if not visible:
		return
	var local_won := winner_player_id == _local_player_id()
	# Mark puzzle as solved on first win detection
	if _puzzle_mode and local_won and not _puzzle_id.is_empty():
		const PuzzlePersistence = preload("res://src/puzzle/puzzle_persistence.gd")
		if not PuzzlePersistence.is_solved(_puzzle_id):
			PuzzlePersistence.mark_solved(_puzzle_id)
		if not PuzzlePersistence.is_pack_solved(_puzzle_id):
			PuzzlePersistence.mark_pack_solved(_puzzle_id)
	_apply_panel_style(_match_end_overlay, Color(0.04, 0.05, 0.07, 0.78), Color(0.88, 0.74, 0.44, 0.96) if local_won else Color(0.9, 0.42, 0.42, 0.96), 2, 18)
	if _match_end_title_label != null:
		if _puzzle_mode:
			_match_end_title_label.text = "Puzzle Complete!" if local_won else "Puzzle Failed"
		else:
			_match_end_title_label.text = "Victory" if local_won else "Defeat"
		_match_end_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84, 1.0) if local_won else Color(1.0, 0.9, 0.9, 1.0))
	if _match_end_detail_label != null:
		if _puzzle_mode:
			_match_end_detail_label.text = _match_state.get("puzzle_name", "") if local_won else "Try again!"
		else:
			_match_end_detail_label.text = _match_end_detail_text(winner_player_id)
		_match_end_detail_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.99, 0.96))
	if _match_end_button != null:
		if _puzzle_mode:
			_match_end_button.visible = false
			_ensure_puzzle_end_buttons()
		else:
			_match_end_button.text = "Continue" if _arena_mode else "Return to Main Menu"


func _ensure_puzzle_end_buttons() -> void:
	if _puzzle_end_retry_btn != null:
		return
	if _match_end_box == null:
		return
	var is_builder_test := _puzzle_id.is_empty()
	_puzzle_end_retry_btn = Button.new()
	_puzzle_end_retry_btn.name = "PuzzleRetryButton"
	_puzzle_end_retry_btn.text = "Retry"
	_puzzle_end_retry_btn.custom_minimum_size = Vector2(280, 48)
	_puzzle_end_retry_btn.add_theme_font_size_override("font_size", 17)
	_puzzle_end_retry_btn.pressed.connect(func(): puzzle_retry_requested.emit())
	_match_end_box.add_child(_puzzle_end_retry_btn)

	_puzzle_end_return_btn = Button.new()
	_puzzle_end_return_btn.name = "PuzzleReturnButton"
	_puzzle_end_return_btn.text = "Return to Puzzle Editor" if is_builder_test else "Return to Puzzles"
	_puzzle_end_return_btn.custom_minimum_size = Vector2(280, 48)
	_puzzle_end_return_btn.add_theme_font_size_override("font_size", 17)
	_puzzle_end_return_btn.pressed.connect(func(): puzzle_return_to_select_requested.emit())
	_match_end_box.add_child(_puzzle_end_return_btn)


func _refresh_end_turn_button_style(has_pending_prophecy: bool) -> void:
	var fill := Color(0.18, 0.15, 0.16, 0.96)
	var border := Color(0.39, 0.36, 0.4, 0.88)
	var font_color := Color(0.82, 0.84, 0.88, 0.96)
	var border_width := 1
	var font_size := 17
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = Vector2(140, 54)
	_end_turn_button.self_modulate = Color(0.92, 0.92, 0.96, 0.95)
	if _has_match_winner():
		_end_turn_button.tooltip_text = "Match complete. No further turn actions are available."
	elif _is_local_player_turn() and not has_pending_prophecy:
		fill = Color(0.56, 0.2, 0.08, 0.99)
		border = Color(1.0, 0.76, 0.43, 1.0)
		font_color = Color(1.0, 0.97, 0.92, 1.0)
		border_width = 2
		font_size = 18
		_end_turn_button.custom_minimum_size = Vector2(140, 62)
		_end_turn_button.tooltip_text = "Your turn is live. End the turn when you are finished acting."
		_end_turn_button.self_modulate = Color(1, 1, 1, 1)
	elif has_pending_prophecy and _is_local_player_turn():
		_end_turn_button.tooltip_text = "Resolve the open Prophecy window before ending the turn."
	else:
		_end_turn_button.tooltip_text = "Unavailable while the opponent is taking their turn."
	_end_turn_button.add_theme_font_size_override("font_size", font_size)
	_apply_button_style(_end_turn_button, fill, border, font_color, border_width, 12)


func did_local_player_win() -> bool:
	return _match_winner_id() == _local_player_id()


func _has_match_winner() -> bool:
	return not _match_winner_id().is_empty()


func _match_winner_id() -> String:
	return str(_match_state.get("winner_player_id", ""))


func _match_end_detail_text(winner_player_id: String) -> String:
	if winner_player_id.is_empty():
		return ""
	var loser_player_id := PLAYER_ORDER[0] if winner_player_id == PLAYER_ORDER[1] else PLAYER_ORDER[1]
	if winner_player_id == _local_player_id():
		return "%s has fallen. %s wins the match." % [_player_name(loser_player_id), _player_name(winner_player_id)]
	return "%s wins the match. %s is out of actions." % [_player_name(winner_player_id), _player_name(_local_player_id())]



func _ring_summary(player: Dictionary) -> String:
	if not bool(player.get("has_ring_of_magicka", false)):
		return "None"
	return "%d charge(s)" % int(player.get("ring_of_magicka_charges", 0))


func _health_panel_fill(player: Dictionary, is_opponent: bool) -> Color:
	var health := int(player.get("health", 0))
	if health <= 10:
		return Color(0.36, 0.12, 0.12, 0.98)
	if is_opponent:
		return Color(0.31, 0.13, 0.12, 0.98)
	return Color(0.24, 0.12, 0.14, 0.98)


func _health_panel_border(player: Dictionary, is_opponent: bool) -> Color:
	var health := int(player.get("health", 0))
	if health <= 10:
		return Color(0.88, 0.4, 0.28, 0.98)
	return Color(0.74, 0.44, 0.28, 0.94) if is_opponent else Color(0.67, 0.46, 0.33, 0.94)


func _refresh_rune_row(rune_row: HBoxContainer, player: Dictionary, player_id: String, is_opponent: bool) -> void:
	_clear_children(rune_row)
	var remaining_runes: Array = player.get("rune_thresholds", [])
	var display_thresholds: Array = player.get("_initial_rune_thresholds", DISPLAY_RUNE_THRESHOLDS)
	for threshold in display_thresholds:
		rune_row.add_child(_build_rune_token(player_id, int(threshold), remaining_runes.has(threshold), is_opponent))


func _build_rune_token(player_id: String, threshold: int, active: bool, is_opponent: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "%s_rune_%d" % [player_id, threshold]
	panel.custom_minimum_size = Vector2(42, 28)
	var fill := Color(0.48, 0.18, 0.14, 0.98) if active else Color(0.12, 0.12, 0.14, 0.94)
	var border := Color(0.89, 0.69, 0.39, 0.96) if active else Color(0.31, 0.32, 0.37, 0.88)
	if is_opponent and active:
		fill = Color(0.45, 0.16, 0.13, 0.98)
	_apply_panel_style(panel, fill, border, 1, 8)
	var box := _build_panel_box(panel, 0, 4)
	var label := Label.new()
	label.text = str(threshold)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84, 0.98) if active else Color(0.62, 0.64, 0.7, 0.8))
	box.add_child(label)
	return panel


func _magicka_summary_text(player: Dictionary) -> String:
	var current := maxi(0, int(player.get("current_magicka", 0)))
	var max_magicka := maxi(0, int(player.get("max_magicka", 0)))
	var temporary := maxi(0, int(player.get("temporary_magicka", 0)))
	var text := "Magicka %d / %d" % [current, max_magicka]
	if temporary > 0:
		text += " • +%d temp" % temporary
	return text


func _ring_panel_text(_player: Dictionary) -> String:
	return "Ring of Magicka"


func _refresh_ring_row(ring_row: HBoxContainer, player: Dictionary) -> void:
	_clear_children(ring_row)
	var charges := maxi(0, mini(3, int(player.get("ring_of_magicka_charges", 0))))
	for index in range(3):
		ring_row.add_child(_build_ring_token(index, index < charges))


func _build_ring_token(index: int, active: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "ring_%d" % index
	panel.custom_minimum_size = Vector2(18, 18)
	_apply_panel_style(panel, Color(0.7, 0.57, 0.24, 0.98) if active else Color(0.12, 0.12, 0.14, 0.94), Color(0.96, 0.87, 0.58, 0.98) if active else Color(0.31, 0.3, 0.28, 0.86), 1, 9)
	return panel


func _pile_button_text(title: String, count: int) -> String:
	return "%s\n%d" % [title, count]


func _pile_button_tooltip(player: Dictionary, zone: String) -> String:
	var count: int = player.get(zone, []).size()
	if zone == MatchMutations.ZONE_DISCARD:
		return "%s's discard pile has %d card(s). Click to inspect public discard contents." % [_player_name(str(player.get("player_id", ""))), count]
	return "%s's deck has %d card(s) remaining. Click to inspect the count surface." % [_player_name(str(player.get("player_id", ""))), count]


func _lane_entries() -> Array:
	var lane_type_lookup := {}
	for raw_record in _lane_registry.get("lane_types", []):
		if typeof(raw_record) == TYPE_DICTIONARY:
			lane_type_lookup[str(raw_record.get("id", ""))] = raw_record
	# Prefer match state lanes when available — they carry the runtime lane_type
	# which may differ from the board profile (e.g. dementia_test, or after Syl
	# transforms a lane mid-match).
	var match_lanes: Array = _match_state.get("lanes", []) if not _match_state.is_empty() else []
	if not match_lanes.is_empty():
		var entries: Array = []
		for lane in match_lanes:
			var lane_id := str(lane.get("lane_id", ""))
			var lane_type_id := str(lane.get("lane_type", lane_id))
			var lane_type: Dictionary = lane_type_lookup.get(lane_type_id, {})
			entries.append({
				"id": lane_id,
				"display_name": str(lane_type.get("display_name", lane_id)),
				"description": str(lane_type.get("description", "")),
				"icon": str(lane_type.get("icon", "")),
			})
		if not entries.is_empty():
			return entries
	# Fallback: read from board profile (used during initial build before match state)
	var board_profile := {}
	for profile in _lane_registry.get("board_profiles", []):
		if str(profile.get("id", "")) == "standard_versus":
			board_profile = profile
			break
	var entries: Array = []
	for lane_entry in board_profile.get("lanes", []):
		var lane_id := str(lane_entry.get("lane_id", ""))
		var lane_type_id := str(lane_entry.get("lane_type", lane_id))
		var lane_type: Dictionary = lane_type_lookup.get(lane_type_id, {})
		entries.append({
			"id": lane_id,
			"display_name": str(lane_type.get("display_name", lane_id)),
			"description": str(lane_type.get("description", "")),
			"icon": str(lane_type.get("icon", "")),
		})
	if entries.is_empty():
		return [
			{"id": "field", "display_name": "Field Lane", "description": "Default combat lane.", "icon": ""},
			{"id": "shadow", "display_name": "Shadow Lane", "description": "New creatures gain Cover briefly here.", "icon": ""},
		]
	return entries


func _lane_name(lane_id: String) -> String:
	for lane in _lane_entries():
		if str(lane.get("id", "")) == lane_id:
			return str(lane.get("display_name", lane_id))
	return lane_id


func _lane_description(lane_id: String) -> String:
	for lane in _lane_entries():
		if str(lane.get("id", "")) == lane_id:
			return str(lane.get("description", lane_id))
	return lane_id


func _lane_icon_path(lane_id: String) -> String:
	for lane in _lane_entries():
		if str(lane.get("id", "")) == lane_id:
			return str(lane.get("icon", ""))
	return ""


func _lane_header_text(lane_id: String) -> String:
	var occupancy: Array = []
	for player_id in PLAYER_ORDER:
		occupancy.append("%s %d" % [_player_name(player_id), _occupied_slots(lane_id, player_id)])
	return "%s\n%s" % [_lane_name(lane_id), _join_parts(occupancy, " | ")]


func _lane_slots(lane_id: String, player_id: String) -> Array:
	for lane in _match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == lane_id:
			return lane.get("player_slots", {}).get(player_id, [])
	return []


func _lane_slot_capacity(lane_id: String) -> int:
	for lane in _match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == lane_id:
			return int(lane.get("slot_capacity", 0))
	return 0


func _occupied_slots(lane_id: String, player_id: String) -> int:
	return _lane_slots(lane_id, player_id).size()


func _first_open_slot_index(lane_id: String, player_id: String) -> int:
	var slots := _lane_slots(lane_id, player_id)
	var slot_capacity := _lane_slot_capacity(lane_id)
	if slots.size() < slot_capacity:
		return slots.size()
	return -1


func _is_hand_public(player_id: String) -> bool:
	return player_id == PLAYER_ORDER[1]


func _is_pending_prophecy_card(card: Dictionary) -> bool:
	if card.is_empty():
		return false
	for window in MatchTiming.get_pending_prophecies(_match_state, str(card.get("controller_player_id", ""))):
		if str(window.get("instance_id", "")) == str(card.get("instance_id", "")):
			return true
	return false


func _pending_prophecy_player_id(instance_id: String) -> String:
	for window in MatchTiming.get_pending_prophecies(_match_state):
		if str(window.get("instance_id", "")) == instance_id:
			return str(window.get("player_id", ""))
	return ""


func _selection_prompt(card: Dictionary) -> String:
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	if _is_pending_prophecy_card(card):
		var pid := str(card.get("controller_player_id", ""))
		var pl := {}
		for p in _match_state.get("players", []):
			if str(p.get("player_id", "")) == pid:
				pl = p
				break
		if pl.get("hand", []).size() > MatchTiming.MAX_HAND_SIZE:
			return "Selected %s. It is pending Prophecy; play it for free or discard it." % _card_name(card)
		return "Selected %s. It is pending Prophecy; play it for free or keep it in hand." % _card_name(card)
	if not bool(location.get("is_valid", false)):
		return "Inspecting %s." % _card_name(card)
	match str(location.get("zone", "")):
		MatchMutations.ZONE_HAND:
			match str(card.get("card_type", "")):
				"creature":
					return "Selected %s. Click a friendly lane slot to summon it." % _card_name(card)
				"item":
					return "Selected %s. Click a friendly creature to equip it." % _card_name(card)
				"support":
					return "Selected %s. Click your support row to place it." % _card_name(card)
				_:
					return "Selected %s." % _card_name(card)
		MatchMutations.ZONE_SUPPORT:
				return "Selected %s. Click a target to activate it." % _card_name(card)
		MatchMutations.ZONE_LANE:
			return "Selected %s. Click an opposing creature or player to attack if legal." % _card_name(card)
		_:
			return "Selected %s." % _card_name(card)


func _card_name(card: Dictionary) -> String:
	if card.is_empty():
		return "Unknown Card"
	var name := str(card.get("name", ""))
	if not name.is_empty():
		return name
	return _identifier_to_name(str(card.get("definition_id", card.get("instance_id", "card"))))


func _card_button_text(card: Dictionary, public_view: bool) -> String:
	if not public_view and not _is_pending_prophecy_card(card):
		return "Hidden Card"
	var lines: Array = []
	var prefix := "▶ " if str(card.get("instance_id", "")) == _selected_instance_id else ""
	lines.append("%s%s" % [prefix, _card_name(card)])
	lines.append("Cost %d | %s" % [int(card.get("cost", 0)), str(card.get("card_type", "")).capitalize()])
	if str(card.get("card_type", "")) == "creature":
		lines.append("%d / %d" % [EvergreenRules.get_power(card), EvergreenRules.get_remaining_health(card)])
	var tags := _card_tag_text(card)
	if not tags.is_empty():
		lines.append(tags)
	return _join_parts(lines, "\n")


func _card_tooltip(card: Dictionary, public_view: bool) -> String:
	if not public_view and not _is_pending_prophecy_card(card):
		return "Opponent hand card. Full details are hidden until it becomes public."
	return _card_inspector_text(card)


func _card_inspector_text(card: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s" % _card_name(card))
	lines.append("Type %s | Cost %d" % [str(card.get("card_type", "")).capitalize(), int(card.get("cost", 0))])
	if str(card.get("card_type", "")) == "creature":
		lines.append("Power %d | Health %d" % [EvergreenRules.get_power(card), EvergreenRules.get_remaining_health(card)])
	lines.append("Zone %s | Controller %s" % [str(card.get("zone", "unknown")), _player_name(str(card.get("controller_player_id", "")))])
	var tags := _card_tag_text(card)
	if not tags.is_empty():
		lines.append("Tags: %s" % tags)
	var attached_items: Array = card.get("attached_items", [])
	if attached_items.size() > 0:
		var names: Array = []
		for item in attached_items:
			if typeof(item) == TYPE_DICTIONARY:
				names.append(_card_name(item))
		lines.append("Attached: %s" % _join_parts(names, ", "))
	var rules_text := str(card.get("rules_text", ""))
	if not rules_text.is_empty():
		lines.append("Rules: %s" % rules_text)
	return _join_parts(lines, "\n")


func _card_tag_text(card: Dictionary) -> String:
	var terms: Array = []
	var keyword_counts := {}
	for keyword in card.get("keywords", []):
		var kw_id := str(keyword)
		keyword_counts[kw_id] = keyword_counts.get(kw_id, 0) + 1
	for keyword in card.get("granted_keywords", []):
		var kw_id := str(keyword)
		keyword_counts[kw_id] = keyword_counts.get(kw_id, 0) + 1
	for item in EvergreenRules.get_attached_items(card):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		for kw in item.get("equip_keywords", []):
			var kw_id := str(kw)
			keyword_counts[kw_id] = keyword_counts.get(kw_id, 0) + 1
	for kw_id in keyword_counts:
		var count: int = keyword_counts[kw_id]
		var label := _term_label(kw_id)
		if kw_id == "rally" and count > 1:
			label += " " + str(count)
		terms.append(label)
	for status in card.get("status_markers", []):
		var status_id := str(status)
		if status_id == EvergreenRules.STATUS_COVER and not EvergreenRules.is_cover_active(_match_state, card):
			continue
		terms.append(_term_label(status_id))
	for rule_tag in card.get("rules_tags", []):
		terms.append(_term_label(str(rule_tag)))
	return _join_parts(_unique_terms(terms), ", ")


func _term_label(term_id: String) -> String:
	if _keyword_display_names.has(term_id):
		return str(_keyword_display_names[term_id])
	if _status_display_names.has(term_id):
		return str(_status_display_names[term_id])
	if HELP_TEXT.has(term_id):
		return _identifier_to_name(term_id)
	return _identifier_to_name(term_id)




func _scenario_label(scenario_id: String) -> String:
	for scenario in MatchDebugScenarios.list_scenarios():
		if str(scenario.get("id", "")) == scenario_id:
			return str(scenario.get("label", scenario_id))
	return scenario_id


func _identifier_to_name(value: String) -> String:
	var parts := value.replace("_", " ").split(" ", false)
	var titled: Array = []
	for part in parts:
		if part.is_empty():
			continue
		titled.append(part.substr(0, 1).to_upper() + part.substr(1))
	return _join_parts(titled, " ")


func _is_local_hand_card(instance_id: String) -> bool:
	var location := MatchMutations.find_card_location(_match_state, instance_id)
	if not bool(location.get("is_valid", false)):
		return false
	return str(location.get("zone", "")) == MatchMutations.ZONE_HAND and str(location.get("player_id", "")) == PLAYER_ORDER[1]


func _detach_hand_card(instance_id: String) -> void:
	_cancel_detached_card_silent()
	select_card(instance_id)
	var button: Button = _card_buttons.get(instance_id)
	if button != null:
		button.visible = false
	var card := _card_from_instance_id(instance_id)
	var preview_size := _hand_card_display_size()
	var base_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "detached_hand_card_%s" % instance_id
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 500
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	wrapper.add_child(component)
	add_child(wrapper)
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	var mouse_pos := get_viewport().get_mouse_position()
	wrapper.position = mouse_pos + Vector2(-preview_size.x * 0.5, -preview_size.y * 0.62)
	_detached_card_state = {
		"instance_id": instance_id,
		"preview": wrapper,
		"card_data": card.duplicate(true),
	}


func _detach_prophecy_card(instance_id: String) -> void:
	_cancel_detached_card_silent()
	_selected_instance_id = instance_id
	var card := _card_from_instance_id(instance_id)
	var preview_size := _hand_card_display_size()
	var base_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "detached_prophecy_card_%s" % instance_id
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 500
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	wrapper.add_child(component)
	add_child(wrapper)
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	var mouse_pos := get_viewport().get_mouse_position()
	wrapper.position = mouse_pos + Vector2(-preview_size.x * 0.5, -preview_size.y * 0.62)
	_detached_card_state = {
		"instance_id": instance_id,
		"preview": wrapper,
		"card_data": card.duplicate(true),
	}
	# Hide the prophecy overlay while dragging — it rebuilds on cancel via _refresh_ui
	var vbox: Control = _prophecy_overlay_state.get("vbox")
	if vbox != null and is_instance_valid(vbox):
		vbox.visible = false
	_status_message = "Click a friendly lane slot to summon %s." % _card_name(card)
	_refresh_ui()


func _enter_prophecy_targeting_mode(instance_id: String) -> void:
	_cancel_targeting_mode_silent()
	_selected_instance_id = instance_id
	var card := _card_from_instance_id(instance_id)
	# Use the prophecy card wrapper position as arrow origin
	var card_wrapper: Control = _prophecy_overlay_state.get("card_wrapper")
	var arrow_origin := Vector2.ZERO
	if card_wrapper != null and is_instance_valid(card_wrapper):
		var card_size := card_wrapper.size
		arrow_origin = card_wrapper.global_position + Vector2(card_size.x * 0.5, 0.0)
	else:
		var viewport_size := get_viewport_rect().size
		arrow_origin = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5)
	_targeting_arrow = _create_targeting_arrow()
	_targeting_arrow_state = {
		"instance_id": instance_id,
		"origin": arrow_origin,
		"button": null,
	}
	_status_message = "Select a target for %s." % _card_name(card)
	_refresh_ui()


func _cancel_detached_card() -> void:
	_clear_insertion_preview()
	_clear_sacrifice_hover()
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}
	_selected_instance_id = ""
	_refresh_ui()


func _cancel_detached_card_silent() -> void:
	_clear_insertion_preview()
	_clear_sacrifice_hover()
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	_detached_card_state = {}


func _update_insertion_preview_from_mouse(mouse_pos: Vector2) -> void:
	var card := _selected_card()
	if card.is_empty() or _selected_action_mode(card) != SELECTION_MODE_SUMMON:
		_clear_insertion_preview()
		return
	var target_player := _target_lane_player_id()
	var found_lane := ""
	var found_row: HBoxContainer = null
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var row_key := _lane_row_key(lane_id, target_player)
		var row_panel: PanelContainer = _lane_row_panels.get(row_key)
		if row_panel == null or not is_instance_valid(row_panel):
			continue
		var panel_rect := Rect2(row_panel.global_position, row_panel.size)
		if panel_rect.has_point(mouse_pos):
			var slots := _lane_slots(lane_id, target_player)
			var slot_capacity := _lane_slot_capacity(lane_id)
			if slots.size() < slot_capacity:
				found_lane = lane_id
				found_row = _lane_row_containers.get(row_key)
			break
	if found_lane.is_empty() or found_row == null:
		_clear_insertion_preview()
		return
	var insertion_index := _compute_insertion_index(found_row, mouse_pos.x)
	_set_insertion_preview(found_lane, target_player, insertion_index, found_row)


func _compute_insertion_index(row: HBoxContainer, mouse_global_x: float) -> int:
	var card_children: Array = []
	for child in row.get_children():
		if child.has_meta("is_insertion_spacer"):
			continue
		card_children.append(child)
	for i in range(card_children.size()):
		var child: Control = card_children[i]
		var center_x := child.global_position.x + child.size.x * 0.5
		if mouse_global_x < center_x:
			return i
	return card_children.size()


func _set_insertion_preview(lane_id: String, player_id: String, index: int, row: HBoxContainer) -> void:
	if not _insertion_preview.is_empty():
		var same_lane := str(_insertion_preview.get("lane_id", "")) == lane_id and str(_insertion_preview.get("player_id", "")) == player_id
		if same_lane and int(_insertion_preview.get("index", -1)) == index:
			return
		if same_lane:
			var spacer: Control = _insertion_preview.get("spacer")
			if spacer != null and is_instance_valid(spacer) and spacer.get_parent() == row:
				row.move_child(spacer, index)
				_insertion_preview["index"] = index
				return
		_clear_insertion_preview(false)
	var spacer := Control.new()
	spacer.name = "insertion_spacer"
	spacer.set_meta("is_insertion_spacer", true)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 0)
	row.add_child(spacer)
	row.move_child(spacer, index)
	var target_width: float = CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE.x
	var tween := create_tween()
	tween.tween_property(spacer, "custom_minimum_size:x", target_width, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_insertion_preview = {
		"lane_id": lane_id,
		"player_id": player_id,
		"index": index,
		"spacer": spacer,
		"tween": tween,
	}


func _clear_insertion_preview(animate := true) -> void:
	if _insertion_preview.is_empty():
		return
	var spacer: Control = _insertion_preview.get("spacer")
	var tween: Tween = _insertion_preview.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	_insertion_preview = {}
	if spacer == null or not is_instance_valid(spacer):
		return
	if not animate or spacer.get_parent() == null:
		if spacer.get_parent() != null:
			spacer.get_parent().remove_child(spacer)
		spacer.queue_free()
		return
	var out_tween := create_tween()
	out_tween.tween_property(spacer, "custom_minimum_size:x", 0.0, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	var spacer_ref: WeakRef = weakref(spacer)
	out_tween.finished.connect(_queue_free_weak.bind(spacer_ref))


func _get_insertion_index_or_default(lane_id: String, player_id: String) -> int:
	if not _insertion_preview.is_empty() and str(_insertion_preview.get("lane_id", "")) == lane_id and str(_insertion_preview.get("player_id", "")) == player_id:
		return int(_insertion_preview.get("index", -1))
	return _first_open_slot_index(lane_id, player_id)


func _create_targeting_arrow() -> Line2D:
	var arrow := Line2D.new()
	arrow.width = 6.0
	arrow.default_color = Color(1.0, 0.85, 0.2, 0.9)
	arrow.z_index = 500
	arrow.antialiased = true
	add_child(arrow)
	return arrow


func _update_targeting_arrow(mouse_pos: Vector2) -> void:
	if _targeting_arrow == null or not is_instance_valid(_targeting_arrow):
		return
	# Dynamically compute origin from the card button's current position so the
	# arrow tracks the card through tween animations and layout changes.
	var origin: Vector2 = _targeting_arrow_state.get("origin", Vector2.ZERO)
	var arrow_instance_id: String = str(_targeting_arrow_state.get("instance_id", ""))
	var arrow_button: Button = _card_buttons.get(arrow_instance_id)
	if arrow_button != null and is_instance_valid(arrow_button):
		var card_size: Vector2 = arrow_button.get_meta("card_size", arrow_button.size)
		origin = arrow_button.global_position + Vector2(card_size.x * 0.5, 0.0)
	var start := origin
	var end_point := mouse_pos
	var mid := (start + end_point) * 0.5
	var diff := end_point - start
	var perp := Vector2(-diff.y, diff.x).normalized()
	var control := mid + perp * diff.length() * 0.25
	var points := PackedVector2Array()
	var segments := 20
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := (1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * control + t * t * end_point
		points.append(p)
	# Arrowhead
	var tip := points[points.size() - 1]
	var prev := points[points.size() - 2]
	var arrow_dir := (tip - prev).normalized()
	var arrow_perp := Vector2(-arrow_dir.y, arrow_dir.x)
	var arrow_size := 14.0
	points.append(tip - arrow_dir * arrow_size + arrow_perp * arrow_size * 0.5)
	points.append(tip)
	points.append(tip - arrow_dir * arrow_size - arrow_perp * arrow_size * 0.5)
	points.append(tip)
	_targeting_arrow.points = points


func _enter_targeting_mode(instance_id: String) -> void:
	_cancel_targeting_mode_silent()
	select_card(instance_id)
	var button: Button = _card_buttons.get(instance_id)
	var arrow_origin := Vector2.ZERO
	if button != null:
		# Card is now raised because select_card sets _selected_instance_id and _refresh_ui
		# applies the raised state. Set mouse_filter to ignore so the card doesn't intercept clicks.
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_pos := button.global_position
		var card_size: Vector2 = button.get_meta("card_size", button.size)
		arrow_origin = card_pos + Vector2(card_size.x * 0.5, 0.0)
	else:
		# Card has no visible button (e.g. an item just equipped to a creature).
		# Use the host creature's button position as the arrow origin.
		var location := MatchMutations.find_card_location(_match_state, instance_id)
		var host_button: Button = null
		if str(location.get("zone", "")) == MatchMutations.ZONE_ATTACHED_ITEM:
			var host_card: Dictionary = location.get("host_card", {})
			host_button = _card_buttons.get(str(host_card.get("instance_id", "")))
		if host_button != null:
			var host_pos := host_button.global_position
			var host_size: Vector2 = host_button.get_meta("card_size", host_button.size)
			arrow_origin = host_pos + Vector2(host_size.x * 0.5, 0.0)
		else:
			var viewport_size := get_viewport_rect().size
			arrow_origin = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5)
	_targeting_arrow = _create_targeting_arrow()
	_targeting_arrow_state = {
		"instance_id": instance_id,
		"origin": arrow_origin,
		"button": button,
	}


func _play_mobilize_item_to_lane(lane_id: String) -> void:
	var card := _selected_card()
	if card.is_empty():
		return
	var saved_instance_id := _selected_instance_id
	_cancel_targeting_mode()
	var result := PersistentCardRules.play_item_from_hand(_match_state, _active_player_id(), saved_instance_id, {"lane_id": lane_id})
	var finalized := _finalize_engine_result(result, "Mobilized %s." % _card_name(card))
	if not bool(finalized.get("is_valid", false)):
		_report_invalid_interaction(str(finalized.get("message", "Cannot Mobilize here.")), {"lane_ids": [lane_id]})


func _play_action_to_lane(lane_id: String) -> void:
	var card := _selected_card()
	if card.is_empty():
		return
	# Check for exalt prompt before committing the play
	if _check_exalt_action(card, {"lane_id": lane_id}, _is_pending_prophecy_card(card)):
		return
	var saved_instance_id := _selected_instance_id
	var saved_card := card.duplicate(true)
	var options := {"lane_id": lane_id}
	var result := {}
	if _is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id, options)
	else:
		result = MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id, options)
	var finalized := _finalize_engine_result(result, "Played %s." % _card_name(card))
	if bool(finalized.get("is_valid", false)):
		_check_betray_mode(saved_instance_id, saved_card)


func _cancel_targeting_mode() -> void:
	if _targeting_arrow != null and is_instance_valid(_targeting_arrow):
		_targeting_arrow.queue_free()
	_targeting_arrow = null
	_targeting_arrow_state = {}
	_selected_instance_id = ""
	_refresh_ui()


func _cancel_targeting_mode_silent() -> void:
	if _targeting_arrow != null and is_instance_valid(_targeting_arrow):
		_targeting_arrow.queue_free()
	_targeting_arrow = null
	_targeting_arrow_state = {}


# --- Summon target choice ---


func _check_summon_target_mode(source_instance_id: String) -> void:
	var card := _card_from_instance_id(source_instance_id)
	if card.is_empty():
		return
	var abilities := MatchTiming.get_target_mode_abilities(card)
	# Filter to summon/on_play families and wax/wane (phase-gated).
	# Exclude consume: true abilities — those are handled by pending_consume_selections.
	var active_phases := _get_wax_wane_phases_for_card(card)
	abilities = abilities.filter(func(ab):
		if bool(ab.get("consume", false)):
			return false
		if not MatchTiming._summon_ability_conditions_met(_match_state, card, ab):
			return false
		var family := str(ab.get("family", ""))
		if family == MatchTiming.FAMILY_SUMMON or family == MatchTiming.FAMILY_ON_PLAY:
			return true
		if family == MatchTiming.FAMILY_WAX:
			return active_phases.has("wax")
		if family == MatchTiming.FAMILY_WANE:
			return active_phases.has("wane")
		return false
	)
	if abilities.is_empty():
		return
	var valid_targets := MatchTiming.get_all_valid_targets(_match_state, source_instance_id)
	if valid_targets.is_empty():
		return  # Fizzle silently — no valid targets
	_pending_summon_target = {
		"source_instance_id": source_instance_id,
	}
	_selected_instance_id = source_instance_id
	_enter_targeting_mode(source_instance_id)
	_status_message = _summon_target_prompt(card, abilities)
	if not _is_pending_summon_mandatory():
		_show_summon_skip_button()
	_refresh_ui()


func _resolve_summon_target_card(target_instance_id: String) -> void:
	var source_id := str(_pending_summon_target.get("source_instance_id", ""))
	var valid_targets := MatchTiming.get_all_valid_targets(_match_state, source_id)
	var is_valid := false
	for t in valid_targets:
		if str(t.get("instance_id", "")) == target_instance_id:
			is_valid = true
			break
	if not is_valid:
		_report_invalid_interaction("Not a valid target.", {"instance_ids": [target_instance_id]})
		return
	var is_effect_summon := bool(_pending_summon_target.get("is_effect_summon", false))
	var is_turn_trigger := bool(_pending_summon_target.get("is_turn_trigger", false))
	_pending_summon_target = {}
	_dismiss_summon_skip_button()
	_cancel_targeting_mode_silent()
	if is_turn_trigger:
		var result := MatchTiming.resolve_pending_turn_trigger_target(_match_state, _local_player_id(), {"instance_id": target_instance_id})
		_finalize_engine_result(result, "Targeted %s." % _card_name(_card_from_instance_id(target_instance_id)))
		_check_pending_turn_trigger_target()
	elif is_effect_summon:
		var result := MatchTiming.resolve_pending_summon_effect_target(_match_state, _local_player_id(), {"target_instance_id": target_instance_id})
		_finalize_engine_result(result, "Targeted %s." % _card_name(_card_from_instance_id(target_instance_id)))
	else:
		var result := MatchTiming.resolve_targeted_effect(_match_state, source_id, {"target_instance_id": target_instance_id})
		_finalize_engine_result(result, "Targeted %s." % _card_name(_card_from_instance_id(target_instance_id)))


func _resolve_summon_target_player(player_id: String) -> void:
	var source_id := str(_pending_summon_target.get("source_instance_id", ""))
	var valid_targets := MatchTiming.get_all_valid_targets(_match_state, source_id)
	var is_valid := false
	for t in valid_targets:
		if str(t.get("player_id", "")) == player_id:
			is_valid = true
			break
	if not is_valid:
		_report_invalid_interaction("Not a valid target.", {"player_ids": [player_id]})
		return
	var is_effect_summon := bool(_pending_summon_target.get("is_effect_summon", false))
	var is_turn_trigger := bool(_pending_summon_target.get("is_turn_trigger", false))
	_pending_summon_target = {}
	_dismiss_summon_skip_button()
	_cancel_targeting_mode_silent()
	if is_turn_trigger:
		var result := MatchTiming.resolve_pending_turn_trigger_target(_match_state, _local_player_id(), {"player_id": player_id})
		_finalize_engine_result(result, "Targeted %s." % _player_name(player_id))
		_check_pending_turn_trigger_target()
	elif is_effect_summon:
		var result := MatchTiming.resolve_pending_summon_effect_target(_match_state, _local_player_id(), {"target_player_id": player_id})
		_finalize_engine_result(result, "Targeted %s." % _player_name(player_id))
	else:
		var result := MatchTiming.resolve_targeted_effect(_match_state, source_id, {"target_player_id": player_id})
		_finalize_engine_result(result, "Targeted %s." % _player_name(player_id))


func _is_pending_summon_mandatory() -> bool:
	var source_id := str(_pending_summon_target.get("source_instance_id", ""))
	if source_id.is_empty():
		return false
	if bool(_pending_summon_target.get("is_effect_summon", false)):
		var pending := MatchTiming.get_pending_summon_effect_target(_match_state, _local_player_id())
		return bool(pending.get("mandatory", false))
	var card := _card_from_instance_id(source_id)
	for ability in MatchTiming.get_target_mode_abilities(card):
		if bool(ability.get("mandatory", false)):
			return true
	return false


func _cancel_summon_target_mode() -> void:
	var is_turn_trigger := bool(_pending_summon_target.get("is_turn_trigger", false))
	if is_turn_trigger:
		MatchTiming.decline_pending_turn_trigger_target(_match_state, _local_player_id())
	elif bool(_pending_summon_target.get("is_effect_summon", false)):
		MatchTiming.decline_pending_summon_effect_target(_match_state, _local_player_id())
	_pending_summon_target = {}
	_dismiss_summon_skip_button()
	_cancel_targeting_mode()
	_status_message = "Effect declined."
	_refresh_ui()
	if is_turn_trigger:
		_check_pending_turn_trigger_target()


func _check_pending_secondary_target() -> void:
	var local_id := _local_player_id()
	if not MatchTiming.has_pending_secondary_target(_match_state, local_id):
		return
	if not _pending_secondary_target_state.is_empty():
		return
	if not _pending_summon_target.is_empty():
		return
	var pending := MatchTiming.get_pending_secondary_target(_match_state, local_id)
	var source_id := str(pending.get("source_instance_id", ""))
	_pending_secondary_target_state = pending.duplicate(true)
	_selected_instance_id = source_id
	_enter_targeting_mode(source_id)
	_status_message = "Choose a target for damage."
	_refresh_ui()


func _resolve_secondary_target_card(target_instance_id: String) -> void:
	_pending_secondary_target_state = {}
	_cancel_targeting_mode_silent()
	var result := MatchTiming.resolve_pending_secondary_target(_match_state, _local_player_id(), target_instance_id)
	_finalize_engine_result(result, "Dealt damage to %s." % _card_name(_card_from_instance_id(target_instance_id)))


func _resolve_secondary_target_player(player_id: String) -> void:
	_pending_secondary_target_state = {}
	_cancel_targeting_mode_silent()
	var result := MatchTiming.resolve_pending_secondary_target_player(_match_state, _local_player_id(), player_id)
	_finalize_engine_result(result, "Dealt damage to %s." % _player_name(player_id))


func _check_pending_summon_effect_target() -> void:
	var local_id := _local_player_id()
	if not MatchTiming.has_pending_summon_effect_target(_match_state, local_id):
		return
	if not _pending_summon_target.is_empty():
		return
	var pending := MatchTiming.get_pending_summon_effect_target(_match_state, local_id)
	var source_id := str(pending.get("source_instance_id", ""))
	var card := _card_from_instance_id(source_id)
	if card.is_empty():
		MatchTiming.decline_pending_summon_effect_target(_match_state, local_id)
		return
	var valid_targets := MatchTiming.get_all_valid_targets(_match_state, source_id)
	if valid_targets.is_empty():
		MatchTiming.decline_pending_summon_effect_target(_match_state, local_id)
		return
	_pending_summon_target = {
		"source_instance_id": source_id,
		"is_effect_summon": true,
	}
	_selected_instance_id = source_id
	_enter_targeting_mode(source_id)
	var abilities := MatchTiming.get_target_mode_abilities(card)
	_status_message = _summon_target_prompt(card, abilities)
	if not _is_pending_summon_mandatory():
		_show_summon_skip_button()
	_refresh_ui()


func _support_has_choose_lane_and_owner(card: Dictionary) -> bool:
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		if str(trigger.get("family", "")) == "activate" and str(trigger.get("target_mode", "")) == "choose_lane_and_owner":
			return true
	return false


func _show_lane_and_owner_choice(support_instance_id: String) -> void:
	var lanes: Array = _match_state.get("lanes", [])
	var options: Array = []
	for lane in lanes:
		var lane_id := str(lane.get("lane_id", ""))
		var lane_name := str(lane.get("display_name", lane_id)).capitalize()
		var _opp_id := PLAYER_ORDER[0] if _local_player_id() == PLAYER_ORDER[1] else PLAYER_ORDER[1]
		for pid_label in [{"pid": _local_player_id(), "label": "Your side"}, {"pid": _opp_id, "label": "Opponent's side"}]:
			var slots: Array = lane.get("player_slots", {}).get(str(pid_label["pid"]), [])
			if slots.size() < 4:  # Lane not full
				options.append({"label": "%s — %s" % [lane_name, str(pid_label["label"])], "lane_id": lane_id, "player_id": str(pid_label["pid"])})
	if options.is_empty():
		_report_invalid_interaction("No available lanes.")
		return
	# Build a simple choice overlay
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 480
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.07, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	overlay.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Choose where to summon Target:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1.0))
	vbox.add_child(title)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	for opt in options:
		var btn := Button.new()
		btn.text = str(opt["label"])
		btn.custom_minimum_size = Vector2(200, 50)
		_apply_button_style(btn, Color(0.15, 0.16, 0.2, 0.95), Color(0.4, 0.38, 0.5, 0.8), Color.WHITE)
		var captured_lane := str(opt["lane_id"])
		var captured_pid := str(opt["player_id"])
		var captured_sid := support_instance_id
		var captured_overlay := overlay
		btn.pressed.connect(func():
			captured_overlay.queue_free()
			var result := PersistentCardRules.activate_support(_match_state, _active_player_id(), captured_sid, {"lane_id": captured_lane, "target_player_id": captured_pid})
			_finalize_engine_result(result, "Activated support.")
		)
		hbox.add_child(btn)
	add_child(overlay)


func _check_pending_forced_play() -> void:
	var local_id := _local_player_id()
	if not MatchTiming.has_pending_forced_play(_match_state, local_id):
		return
	# Don't interrupt other active interactions
	if not _pending_summon_target.is_empty() or not _selected_instance_id.is_empty():
		return
	if not _detached_card_state.is_empty() or not _targeting_arrow_state.is_empty():
		return
	var pending := MatchTiming.get_pending_forced_play(_match_state, local_id)
	var instance_id := str(pending.get("instance_id", ""))
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		MatchTiming.consume_pending_forced_play(_match_state, local_id)
		return
	# Consume the pending entry and auto-select the card for play
	MatchTiming.consume_pending_forced_play(_match_state, local_id)
	_selected_instance_id = instance_id
	_status_message = "Choose a lane for %s." % _card_name(card)
	_refresh_ui()


func _check_pending_turn_trigger_target() -> void:
	var local_id := _local_player_id()
	if not MatchTiming.has_pending_turn_trigger_target(_match_state, local_id):
		if _pending_end_turn:
			_complete_end_turn(_pending_end_turn_player_id)
		return
	if not _pending_summon_target.is_empty():
		return
	var pending := MatchTiming.get_pending_turn_trigger_target(_match_state, local_id)
	var source_id := str(pending.get("source_instance_id", ""))
	var card := _card_from_instance_id(source_id)
	if card.is_empty():
		MatchTiming.decline_pending_turn_trigger_target(_match_state, local_id)
		_check_pending_turn_trigger_target()  # Check for more
		return
	var target_mode := str(pending.get("target_mode", ""))
	var valid_targets := MatchTiming.get_valid_targets_for_mode(_match_state, source_id, target_mode, {})
	if valid_targets.is_empty():
		MatchTiming.decline_pending_turn_trigger_target(_match_state, local_id)
		_check_pending_turn_trigger_target()  # Check for more
		return
	_pending_summon_target = {
		"source_instance_id": source_id,
		"is_turn_trigger": true,
	}
	_selected_instance_id = source_id
	_enter_targeting_mode(source_id)
	var family := str(pending.get("family", ""))
	if family == "end_of_turn":
		_status_message = "%s: Choose a target." % str(card.get("name", "Creature"))
	else:
		var phase_name := "Wax" if family == "wax" else "Wane"
		_status_message = "%s — %s: Choose a target." % [str(card.get("name", "Creature")), phase_name]
	_show_summon_skip_button()
	_refresh_ui()


# --- Betray choice ---


func _check_betray_mode(action_instance_id: String, action_card: Dictionary) -> void:
	if not ExtendedMechanicPacks.action_has_betray(_match_state, _active_player_id(), action_card):
		return
	var candidates := ExtendedMechanicPacks.get_betray_sacrifice_candidates(_match_state, _active_player_id())
	if candidates.is_empty():
		return
	var is_targeted := not str(action_card.get("action_target_mode", "")).is_empty()
	var is_lane_targeted := _action_has_event_lane_targets(action_card)
	if is_targeted:
		var any_valid := false
		for candidate in candidates:
			if ExtendedMechanicPacks.betray_replay_has_valid_target(_match_state, _active_player_id(), action_card, str(candidate.get("instance_id", ""))):
				any_valid = true
				break
		if not any_valid:
			return
	_pending_betray = {
		"action_instance_id": action_instance_id,
		"action_card": action_card,
		"is_targeted": is_targeted,
		"is_lane_targeted": is_lane_targeted,
	}
	_show_betray_skip_button()
	var card_name := str(action_card.get("name", ""))
	_status_message = "Sacrifice a creature to play %s again." % card_name
	_refresh_ui()


func _action_has_event_lane_targets(action_card: Dictionary) -> bool:
	for trigger in action_card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		if str(trigger.get("family", "")) != "on_play":
			continue
		for effect in trigger.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var target_str := str(effect.get("target", ""))
			if target_str.ends_with("_in_event_lane"):
				return true
			if str(effect.get("lane", "")) == "chosen":
				return true
	return false


var _summon_skip_button: Button = null


func _show_summon_skip_button() -> void:
	_dismiss_summon_skip_button()
	var viewport_size := get_viewport_rect().size
	_summon_skip_button = Button.new()
	_summon_skip_button.text = "Skip"
	_summon_skip_button.custom_minimum_size = Vector2(120, 44)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.22, 0.28, 0.92)
	style.border_color = Color(0.6, 0.55, 0.65, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	_summon_skip_button.add_theme_stylebox_override("normal", style)
	_summon_skip_button.add_theme_stylebox_override("hover", style)
	_summon_skip_button.add_theme_stylebox_override("pressed", style)
	_summon_skip_button.add_theme_color_override("font_color", Color(0.9, 0.88, 0.92, 1.0))
	_summon_skip_button.add_theme_font_size_override("font_size", 16)
	_summon_skip_button.pressed.connect(_cancel_summon_target_mode)
	_summon_skip_button.z_index = 600
	add_child(_summon_skip_button)
	_summon_skip_button.position = Vector2(viewport_size.x * 0.5 - 60, viewport_size.y * 0.5 + 40)


func _dismiss_summon_skip_button() -> void:
	if _summon_skip_button != null and is_instance_valid(_summon_skip_button):
		_summon_skip_button.queue_free()
	_summon_skip_button = null


func _show_betray_skip_button() -> void:
	_dismiss_betray_skip_button()
	var viewport_size := get_viewport_rect().size
	# Prompt label
	_betray_prompt_label = Label.new()
	_betray_prompt_label.text = "Choose a creature to betray"
	_betray_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_betray_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25, 1.0))
	_betray_prompt_label.add_theme_font_size_override("font_size", 20)
	_betray_prompt_label.z_index = 600
	_betray_prompt_label.size = Vector2(300, 30)
	_betray_prompt_label.position = Vector2(viewport_size.x * 0.5 - 150, viewport_size.y * 0.5 + 10)
	add_child(_betray_prompt_label)
	# Skip button
	_betray_skip_button = Button.new()
	_betray_skip_button.text = "Skip Betray"
	_betray_skip_button.custom_minimum_size = Vector2(160, 50)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.22, 0.28, 0.92)
	style.border_color = Color(0.6, 0.55, 0.65, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_betray_skip_button.add_theme_stylebox_override("normal", style)
	_betray_skip_button.add_theme_stylebox_override("hover", style)
	_betray_skip_button.add_theme_stylebox_override("pressed", style)
	_betray_skip_button.add_theme_color_override("font_color", Color(0.9, 0.88, 0.92, 1.0))
	_betray_skip_button.add_theme_font_size_override("font_size", 18)
	_betray_skip_button.pressed.connect(_cancel_betray_mode)
	_betray_skip_button.z_index = 600
	add_child(_betray_skip_button)
	_betray_skip_button.position = Vector2(viewport_size.x * 0.5 - 80, viewport_size.y * 0.5 + 50)


func _dismiss_betray_skip_button() -> void:
	if _betray_prompt_label != null and is_instance_valid(_betray_prompt_label):
		_betray_prompt_label.queue_free()
	_betray_prompt_label = null
	if _betray_skip_button != null and is_instance_valid(_betray_skip_button):
		_betray_skip_button.queue_free()
	_betray_skip_button = null


func _cancel_betray_mode() -> void:
	_pending_betray = {}
	_dismiss_betray_skip_button()
	_cancel_targeting_mode_silent()
	_status_message = "Betray declined."
	_refresh_ui()


# ── Exalt prompt ──────────────────────────────────────────────────────────────


static func _card_exalt_extra_cost(card: Dictionary) -> int:
	# Creatures: exalt_cost on triggered ability
	for trigger in card.get("triggered_abilities", []):
		if int(trigger.get("exalt_cost", 0)) > 0:
			return int(trigger.get("exalt_cost", 0))
	# Actions: fixed +1 if any effect has required_source_status == "exalted"
	for trigger in card.get("triggered_abilities", []):
		for effect in trigger.get("effects", []):
			if typeof(effect) == TYPE_DICTIONARY and str(effect.get("required_source_status", "")) == EvergreenRules.STATUS_EXALTED:
				return 1
	return 0


func _can_player_afford_exalt(card: Dictionary) -> bool:
	var extra := _card_exalt_extra_cost(card)
	if extra == 0:
		return false
	var player_id := _active_player_id()
	var player := _player_state(player_id)
	var available := maxi(0, int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0)))
	var base_cost := PersistentCardRules.get_effective_play_cost(_match_state, player_id, card)
	return available >= base_cost + extra


func _show_exalt_prompt(anchor_pos: Vector2, exalt_cost: int) -> void:
	_dismiss_exalt_prompt()
	var container := HBoxContainer.new()
	container.name = "ExaltPromptButtons"
	container.z_index = 700
	container.set("theme_override_constants/separation", 12)

	# Exalt button — gold/amber
	var exalt_btn := Button.new()
	exalt_btn.text = "Exalt (%d)" % exalt_cost
	exalt_btn.custom_minimum_size = Vector2(140, 44)
	var exalt_style := StyleBoxFlat.new()
	exalt_style.bg_color = Color(0.6, 0.45, 0.1, 0.95)
	exalt_style.border_color = Color(0.85, 0.7, 0.2, 0.9)
	exalt_style.set_border_width_all(2)
	exalt_style.set_corner_radius_all(6)
	exalt_style.set_content_margin_all(12)
	exalt_btn.add_theme_stylebox_override("normal", exalt_style)
	var exalt_hover := exalt_style.duplicate()
	exalt_hover.bg_color = Color(0.7, 0.55, 0.15, 0.95)
	exalt_btn.add_theme_stylebox_override("hover", exalt_hover)
	exalt_btn.add_theme_stylebox_override("pressed", exalt_style)
	exalt_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	exalt_btn.add_theme_font_size_override("font_size", 18)
	exalt_btn.pressed.connect(_resolve_exalt.bind(true))
	container.add_child(exalt_btn)

	# Skip button — muted
	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(100, 44)
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color(0.25, 0.22, 0.28, 0.92)
	skip_style.border_color = Color(0.6, 0.55, 0.65, 0.8)
	skip_style.set_border_width_all(2)
	skip_style.set_corner_radius_all(6)
	skip_style.set_content_margin_all(12)
	skip_btn.add_theme_stylebox_override("normal", skip_style)
	var skip_hover := skip_style.duplicate()
	skip_hover.bg_color = Color(0.35, 0.32, 0.38, 0.92)
	skip_btn.add_theme_stylebox_override("hover", skip_hover)
	skip_btn.add_theme_stylebox_override("pressed", skip_style)
	skip_btn.add_theme_color_override("font_color", Color(0.9, 0.88, 0.92, 1.0))
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_resolve_exalt.bind(false))
	container.add_child(skip_btn)

	add_child(container)
	# Position: centered above anchor point
	container.size = container.get_minimum_size()
	container.position = Vector2(anchor_pos.x - container.size.x * 0.5, anchor_pos.y - container.size.y - 8)
	_exalt_button_container = container


func _dismiss_exalt_prompt() -> void:
	if _exalt_button_container != null and is_instance_valid(_exalt_button_container):
		_exalt_button_container.queue_free()
	_exalt_button_container = null
	if _exalt_card_preview != null and is_instance_valid(_exalt_card_preview):
		_exalt_card_preview.queue_free()
	_exalt_card_preview = null


func _create_centered_exalt_card_preview(card: Dictionary) -> Vector2:
	"""Creates a card display centered on the board for action exalt prompts.
	Returns the top-center position for button anchoring."""
	var viewport_size := get_viewport_rect().size
	var base_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "ExaltCardPreview"
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 600
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.setup_card(card, "compact", true)
	wrapper.add_child(component)
	add_child(wrapper)
	wrapper.position = Vector2(viewport_size.x * 0.5 - base_size.x * 0.5, viewport_size.y * 0.5 - base_size.y * 0.5)
	_exalt_card_preview = wrapper
	return Vector2(viewport_size.x * 0.5, wrapper.position.y)


func _get_exalt_anchor_for_detached_card() -> Vector2:
	"""Returns the top-center of the detached card preview for button anchoring."""
	var preview: Control = _detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		return Vector2(preview.global_position.x + preview.size.x * 0.5, preview.global_position.y)
	# Fallback: center of screen
	var viewport_size := get_viewport_rect().size
	return Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5 - 80)


func _check_exalt_creature(card: Dictionary, lane_id: String, slot_index: int, is_prophecy: bool) -> bool:
	"""Checks if a creature has exalt and the player can afford it.
	If so, shows the exalt prompt and returns true (play deferred).
	Otherwise returns false (caller should proceed normally)."""
	if not _can_player_afford_exalt(card):
		return false
	var exalt_cost := _card_exalt_extra_cost(card)
	_pending_exalt = {
		"card_type": "creature",
		"instance_id": _selected_instance_id,
		"card": card.duplicate(true),
		"exalt_cost": exalt_cost,
		"lane_id": lane_id,
		"slot_index": slot_index,
		"is_prophecy": is_prophecy,
	}
	var anchor := _get_exalt_anchor_for_detached_card()
	_show_exalt_prompt(anchor, exalt_cost)
	_status_message = "Exalt %s?" % _card_name(card)
	_refresh_ui()
	return true


func _check_exalt_action(card: Dictionary, options: Dictionary, is_prophecy: bool) -> bool:
	"""Checks if an action has exalt and the player can afford it.
	If so, shows the exalt prompt and returns true (play deferred).
	Otherwise returns false (caller should proceed normally)."""
	if not _can_player_afford_exalt(card):
		return false
	var exalt_cost := _card_exalt_extra_cost(card)
	_pending_exalt = {
		"card_type": "action",
		"instance_id": _selected_instance_id,
		"card": card.duplicate(true),
		"exalt_cost": exalt_cost,
		"action_options": options.duplicate(true),
		"is_prophecy": is_prophecy,
	}
	# For actions: if detached card exists, anchor above it; otherwise create centered preview
	var anchor: Vector2
	if not _detached_card_state.is_empty():
		anchor = _get_exalt_anchor_for_detached_card()
	else:
		_cancel_targeting_mode_silent()
		anchor = _create_centered_exalt_card_preview(card)
	_show_exalt_prompt(anchor, exalt_cost)
	_status_message = "Exalt %s?" % _card_name(card)
	_refresh_ui()
	return true


func _resolve_exalt(exalted: bool) -> void:
	var pending := _pending_exalt
	_pending_exalt = {}
	_dismiss_exalt_prompt()
	_cancel_detached_card_silent()

	var instance_id := str(pending.get("instance_id", ""))
	var card: Dictionary = pending.get("card", {})
	var is_prophecy := bool(pending.get("is_prophecy", false))

	if str(pending.get("card_type", "")) == "creature":
		var options := {}
		var slot_index := int(pending.get("slot_index", -1))
		if slot_index >= 0:
			options["slot_index"] = slot_index
		if exalted:
			options["exalt"] = true
		var lane_id := str(pending.get("lane_id", ""))
		var result: Dictionary
		if is_prophecy:
			result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), instance_id, options.merged({"lane_id": lane_id}, true))
		else:
			result = LaneRules.summon_from_hand(_match_state, _active_player_id(), instance_id, lane_id, options)
		var finalized := _finalize_engine_result(result, "Played %s into %s." % [_card_name(card), _lane_name(lane_id)])
		if bool(finalized.get("is_valid", false)):
			_check_summon_target_mode(instance_id)
	elif str(pending.get("card_type", "")) == "action":
		var options: Dictionary = pending.get("action_options", {}).duplicate(true)
		if exalted:
			options["exalt"] = true
		var result: Dictionary
		if is_prophecy:
			result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), instance_id, options)
		else:
			result = MatchTiming.play_action_from_hand(_match_state, _active_player_id(), instance_id, options)
		var finalized := _finalize_engine_result(result, "Played %s." % _card_name(card))
		if bool(finalized.get("is_valid", false)):
			_check_betray_mode(instance_id, card)


func _resolve_betray_sacrifice(sacrifice_instance_id: String) -> void:
	var candidates := ExtendedMechanicPacks.get_betray_sacrifice_candidates(_match_state, _active_player_id())
	var is_valid_candidate := false
	for c in candidates:
		if str(c.get("instance_id", "")) == sacrifice_instance_id:
			is_valid_candidate = true
			break
	if not is_valid_candidate:
		_report_invalid_interaction("Not a valid sacrifice target.", {"instance_ids": [sacrifice_instance_id]})
		return
	var is_targeted: bool = bool(_pending_betray.get("is_targeted", false))
	if is_targeted:
		var action_card: Dictionary = _pending_betray.get("action_card", {})
		if not ExtendedMechanicPacks.betray_replay_has_valid_target(_match_state, _active_player_id(), action_card, sacrifice_instance_id):
			_report_invalid_interaction("No valid replay targets if this creature is sacrificed.", {"instance_ids": [sacrifice_instance_id]})
			return
	_dismiss_betray_skip_button()
	if is_targeted:
		_pending_betray["sacrifice_instance_id"] = sacrifice_instance_id
		# Enter targeting mode for replay, arrow from player avatar
		var avatar: Control = null
		var section: Dictionary = _player_sections.get(_active_player_id(), {})
		if section.has("avatar_component"):
			avatar = section.get("avatar_component") as Control
		_cancel_targeting_mode_silent()
		_targeting_arrow = _create_targeting_arrow()
		var arrow_origin := Vector2.ZERO
		if avatar != null:
			arrow_origin = avatar.global_position + Vector2(avatar.size.x * 0.5, avatar.size.y * 0.5)
		else:
			var viewport_size := get_viewport_rect().size
			arrow_origin = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.85)
		_targeting_arrow_state = {
			"instance_id": str(_pending_betray.get("action_instance_id", "")),
			"origin": arrow_origin,
			"button": null,
		}
		var card_name := str(_pending_betray.get("action_card", {}).get("name", ""))
		_status_message = "Choose a target for %s." % card_name
		_refresh_ui()
	elif bool(_pending_betray.get("is_lane_targeted", false)):
		_pending_betray["sacrifice_instance_id"] = sacrifice_instance_id
		var card_name := str(_pending_betray.get("action_card", {}).get("name", ""))
		_status_message = "Choose a lane for %s." % card_name
		_refresh_ui()
	else:
		var action_instance_id := str(_pending_betray.get("action_instance_id", ""))
		var result := MatchTiming.execute_betray_replay(_match_state, _active_player_id(), action_instance_id, sacrifice_instance_id, {})
		_pending_betray = {}
		_finalize_engine_result(result, "Betray replay resolved.")


func _resolve_betray_replay_target_card(target_instance_id: String) -> void:
	var action_instance_id := str(_pending_betray.get("action_instance_id", ""))
	var sacrifice_id := str(_pending_betray.get("sacrifice_instance_id", ""))
	var replay_options := {"target_instance_id": target_instance_id}
	var result := MatchTiming.execute_betray_replay(_match_state, _active_player_id(), action_instance_id, sacrifice_id, replay_options)
	_pending_betray = {}
	_cancel_targeting_mode_silent()
	_finalize_engine_result(result, "Betray replay resolved.")


func _resolve_betray_replay_target_player(player_id: String) -> void:
	var action_instance_id := str(_pending_betray.get("action_instance_id", ""))
	var sacrifice_id := str(_pending_betray.get("sacrifice_instance_id", ""))
	var replay_options := {"target_player_id": player_id}
	var result := MatchTiming.execute_betray_replay(_match_state, _active_player_id(), action_instance_id, sacrifice_id, replay_options)
	_pending_betray = {}
	_cancel_targeting_mode_silent()
	_finalize_engine_result(result, "Betray replay resolved.")


func _resolve_betray_replay_lane(lane_id: String) -> void:
	var action_instance_id := str(_pending_betray.get("action_instance_id", ""))
	var sacrifice_id := str(_pending_betray.get("sacrifice_instance_id", ""))
	var replay_options := {"lane_id": lane_id}
	var result := MatchTiming.execute_betray_replay(_match_state, _active_player_id(), action_instance_id, sacrifice_id, replay_options)
	_pending_betray = {}
	_finalize_engine_result(result, "Betray replay resolved.")


func _lane_is_full_with_friendly(lane_id: String, player_id: String) -> bool:
	var slots := _lane_slots(lane_id, player_id)
	var slot_capacity := _lane_slot_capacity(lane_id)
	return slots.size() >= slot_capacity and slots.size() > 0


func _update_sacrifice_hover_from_mouse(mouse_pos: Vector2) -> void:
	if _detached_card_state.is_empty():
		_clear_sacrifice_hover()
		return
	var card := _selected_card()
	if card.is_empty() or _selected_action_mode(card) != SELECTION_MODE_SUMMON:
		_clear_sacrifice_hover()
		return
	var target_player := _target_lane_player_id()
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var row_key := _lane_row_key(lane_id, target_player)
		var row_panel: PanelContainer = _lane_row_panels.get(row_key)
		if row_panel == null or not is_instance_valid(row_panel):
			continue
		if not Rect2(row_panel.global_position, row_panel.size).has_point(mouse_pos):
			continue
		if not _lane_is_full_with_friendly(lane_id, target_player):
			_clear_sacrifice_hover()
			return
		var nearest_id := _find_nearest_friendly_creature_in_lane(lane_id, target_player, mouse_pos)
		if nearest_id != "" and nearest_id != _sacrifice_hover_target_id:
			_clear_sacrifice_hover()
			_apply_sacrifice_hover(nearest_id)
		elif nearest_id == "":
			_clear_sacrifice_hover()
		return
	_clear_sacrifice_hover()


func _find_nearest_friendly_creature_in_lane(lane_id: String, player_id: String, mouse_pos: Vector2) -> String:
	var row_key := _lane_row_key(lane_id, player_id)
	var row: HBoxContainer = _lane_row_containers.get(row_key)
	if row == null or not is_instance_valid(row):
		return ""
	var best_id := ""
	var best_dist := INF
	for child in row.get_children():
		if not (child is Button):
			continue
		if child.has_meta("is_insertion_spacer"):
			continue
		var instance_id: String = child.get_meta("instance_id", "")
		if instance_id.is_empty():
			continue
		var c := _card_from_instance_id(instance_id)
		if c.is_empty():
			continue
		if str(c.get("controller_player_id", "")) != _active_player_id():
			continue
		if str(c.get("card_type", "")) != "creature":
			continue
		var ctrl := child as Control
		var center_x: float = ctrl.global_position.x + ctrl.size.x * 0.5
		var dist: float = absf(mouse_pos.x - center_x)
		if dist < best_dist:
			best_dist = dist
			best_id = instance_id
	return best_id


func _apply_sacrifice_hover(instance_id: String) -> void:
	_sacrifice_hover_target_id = instance_id
	var button: Button = _card_buttons.get(instance_id)
	if button != null and is_instance_valid(button):
		_apply_betray_target_glow(button, "lane")
	var target_card := _card_from_instance_id(instance_id)
	_sacrifice_hover_label = PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	bg_style.set_corner_radius_all(4)
	bg_style.set_content_margin_all(6)
	_sacrifice_hover_label.add_theme_stylebox_override("panel", bg_style)
	_sacrifice_hover_label.z_index = 501
	_sacrifice_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "Sacrifice %s" % _card_name(target_card)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sacrifice_hover_label.add_child(label)
	add_child(_sacrifice_hover_label)
	_update_sacrifice_hover_label_position()


func _update_sacrifice_hover_label_position() -> void:
	if _sacrifice_hover_label == null or not is_instance_valid(_sacrifice_hover_label):
		return
	var preview: Control = _detached_card_state.get("preview")
	if preview == null or not is_instance_valid(preview):
		return
	var label_size := _sacrifice_hover_label.size
	_sacrifice_hover_label.position = Vector2(
		preview.position.x + preview.size.x * 0.5 - label_size.x * 0.5,
		preview.position.y + preview.size.y + 4.0
	)


func _clear_sacrifice_hover() -> void:
	if _sacrifice_hover_target_id.is_empty():
		return
	var button: Button = _card_buttons.get(_sacrifice_hover_target_id)
	if button != null and is_instance_valid(button):
		var glow := button.find_child("valid_target_glow", false, false)
		if glow != null:
			glow.queue_free()
	_sacrifice_hover_target_id = ""
	if _sacrifice_hover_label != null and is_instance_valid(_sacrifice_hover_label):
		_sacrifice_hover_label.queue_free()
	_sacrifice_hover_label = null


func _resolve_sacrifice_hover() -> void:
	var sacrifice_id := _sacrifice_hover_target_id
	var detached_id := str(_detached_card_state.get("instance_id", ""))
	var location := MatchMutations.find_card_location(_match_state, sacrifice_id)
	var lane_id := str(location.get("lane_id", ""))
	_clear_sacrifice_hover()
	_cancel_detached_card_silent()
	_pending_sacrifice_summon = {"card_instance_id": detached_id, "lane_id": lane_id}
	_resolve_sacrifice_summon(sacrifice_id)


func _resolve_sacrifice_summon(sacrifice_instance_id: String) -> void:
	var lane_id := str(_pending_sacrifice_summon.get("lane_id", ""))
	var card_instance_id := str(_pending_sacrifice_summon.get("card_instance_id", ""))
	var sacrifice_location := MatchMutations.find_card_location(_match_state, sacrifice_instance_id)
	var sacrifice_card: Dictionary = sacrifice_location.get("card", {})
	if sacrifice_card.is_empty():
		_report_invalid_interaction("Not a valid sacrifice target.", {"instance_ids": [sacrifice_instance_id]})
		return
	if str(sacrifice_card.get("controller_player_id", "")) != _active_player_id():
		_report_invalid_interaction("Not a valid sacrifice target.", {"instance_ids": [sacrifice_instance_id]})
		return
	if str(sacrifice_location.get("lane_id", "")) != lane_id:
		_report_invalid_interaction("Sacrifice target must be in the same lane.", {"instance_ids": [sacrifice_instance_id]})
		return
	var saved_instance_id := card_instance_id
	var summoned_card := _card_from_instance_id(card_instance_id)
	var sacrifice_name := _card_name(sacrifice_card)
	var summoned_name := _card_name(summoned_card)
	var result := LaneRules.summon_with_sacrifice(_match_state, _active_player_id(), card_instance_id, lane_id, sacrifice_instance_id)
	_pending_sacrifice_summon = {}
	var finalized := _finalize_engine_result(result, "Sacrificed %s to play %s." % [sacrifice_name, summoned_name])
	if bool(finalized.get("is_valid", false)):
		_check_summon_target_mode(saved_instance_id)


func _summon_target_prompt(card: Dictionary, abilities: Array) -> String:
	var card_name := str(card.get("name", ""))
	var modes: Array = []
	for ability in abilities:
		modes.append(str(ability.get("target_mode", "")))
	if modes.has("creature_or_player"):
		return "%s: Choose a target." % card_name
	if modes.has("enemy_creature") or modes.has("enemy_creature_in_lane"):
		return "%s: Choose an enemy creature." % card_name
	if modes.has("friendly_creature") or modes.has("another_friendly_creature"):
		return "%s: Choose a friendly creature." % card_name
	if modes.has("enemy_support"):
		if modes.size() > 1:
			return "%s: Choose a creature or enemy support." % card_name
		return "%s: Choose an enemy support." % card_name
	return "%s: Choose a target." % card_name


func _queue_free_weak(node_ref: WeakRef) -> void:
	var node = node_ref.get_ref()
	if node != null and is_instance_valid(node):
		node.queue_free()


func _try_resolve_detached_card_via_lane(target_instance_id: String) -> void:
	var target_location := MatchMutations.find_card_location(_match_state, target_instance_id)
	if not bool(target_location.get("is_valid", false)) or str(target_location.get("zone", "")) != MatchMutations.ZONE_LANE:
		return
	var selected_card := _selected_card()
	if not _selected_support_row_target_player_id(selected_card).is_empty():
		_play_selected_to_support_row(_selected_support_row_target_player_id(selected_card))
		return
	var lane_id := str(target_location.get("lane_id", ""))
	var target_player := _target_lane_player_id()
	if _selected_card_wants_lane(selected_card, target_player):
		if _selected_action_mode(selected_card) == SELECTION_MODE_ACTION:
			_play_action_to_lane(lane_id)
			return
		var slot_index := _get_insertion_index_or_default(lane_id, target_player)
		if slot_index >= 0:
			var validation := _validate_selected_lane_play(lane_id, target_player, slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})



func _try_resolve_selected_support_row_card(target_card: Dictionary) -> bool:
	if _selected_support_row_target_player_id(_selected_card()).is_empty() or target_card.is_empty():
		return false
	var target_location := MatchMutations.find_card_location(_match_state, str(target_card.get("instance_id", "")))
	if not bool(target_location.get("is_valid", false)) or str(target_location.get("zone", "")) != MatchMutations.ZONE_SUPPORT:
		return false
	_play_selected_to_support_row(str(target_card.get("controller_player_id", "")))
	return true


func _play_selected_to_support_row(player_id: String) -> Dictionary:
	var card := _selected_card()
	var validation := _validate_selected_support_play(player_id)
	if not bool(validation.get("is_valid", false)):
		return _report_invalid_interaction(str(validation.get("errors", [validation.get("message", "Cannot place this support there.")])[0]))
	var result := {}
	if _is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id)
		return _finalize_engine_result(result, "Played %s into %s's support row." % [_card_name(card), _player_name(player_id)])
	result = PersistentCardRules.play_support_from_hand(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id)
	return _finalize_engine_result(result, "Placed %s into %s's support row." % [_card_name(card), _player_name(player_id)])




func _first_valid_lane_slot_index(lane_id: String, player_id: String) -> int:
	for slot_index in range(_lane_slots(lane_id, player_id).size()):
		if bool(_validate_selected_lane_play(lane_id, player_id, slot_index).get("is_valid", false)):
			return slot_index
	return -1


func _lane_slot_key(lane_id: String, player_id: String, slot_index: int) -> String:
	return "%s:%s:%d" % [lane_id, player_id, slot_index]


func _lane_row_key(lane_id: String, player_id: String) -> String:
	return "%s:%s" % [lane_id, player_id]


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _try_cycle_active_card_relationship(direction: int) -> bool:
	# Try hover preview first (lane or support)
	var component = _get_active_hover_preview_component()
	if component != null:
		component.cycle_relationship(direction)
		return true
	# Try hovered hand card
	if _hovered_hand_instance_id != "":
		var button: Button = _card_buttons.get(_hovered_hand_instance_id) as Button
		if button != null and is_instance_valid(button):
			var hand_component = button.get_meta("card_display_component", null)
			if hand_component != null and is_instance_valid(hand_component) and hand_component.has_method("cycle_relationship"):
				hand_component.cycle_relationship(direction)
				return true
	return false


func _get_active_hover_preview_component():
	if _card_hover_preview_layer == null:
		return null
	# Check lane hover preview
	if _lane_hover_preview_instance_id != "":
		var preview := _card_hover_preview_layer.get_node_or_null("lane_hover_preview_%s" % _lane_hover_preview_instance_id)
		if preview != null and preview.get_child_count() > 0:
			return preview.get_child(0)
	# Check support hover preview
	if _support_hover_preview_instance_id != "":
		var preview := _card_hover_preview_layer.get_node_or_null("support_hover_preview_%s" % _support_hover_preview_instance_id)
		if preview != null and preview.get_child_count() > 0:
			return preview.get_child(0)
	return null


func _unique_terms(values: Array) -> Array:
	var unique: Array = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique


func _join_parts(values: Array, separator: String) -> String:
	if values.is_empty():
		return ""
	var strings := PackedStringArray()
	for value in values:
		strings.append(str(value))
	return separator.join(strings)


# ── Match History ──────────────────────────────────────────────────────────────

func _reset_match_history() -> void:
	_match_history_entries.clear()
	_match_history_last_event_count = 0
	_match_history_card_snapshots.clear()
	_dismiss_match_history_popover()
	_refresh_match_history_row()


func _scan_and_refresh_match_history() -> void:
	# Defer scanning while the player is selecting a target for a summon effect,
	# action, or item so the history entry includes the resolved target(s).
	if not _pending_summon_target.is_empty() or not _targeting_arrow_state.is_empty():
		return
	var event_log: Array = _match_state.get("event_log", [])
	if event_log.size() <= _match_history_last_event_count:
		return
	_scan_event_log_for_history(event_log)
	_match_history_last_event_count = event_log.size()
	_refresh_match_history_row()


func _scan_event_log_for_history(event_log: Array) -> void:
	var start := _match_history_last_event_count
	var i := start
	while i < event_log.size():
		var event: Dictionary = event_log[i]
		var event_type := str(event.get("event_type", ""))
		var parent_id := str(event.get("parent_event_id", ""))

		if event_type == "card_played" and parent_id.is_empty():
			_process_card_played_history(event, event_log, i)
		elif event_type == "attack_declared" and parent_id.is_empty():
			_process_attack_history(event, event_log, i)
		elif event_type == "support_activated" and parent_id.is_empty():
			_process_support_activated_history(event, event_log, i)
		i += 1


func _process_card_played_history(play_event: Dictionary, event_log: Array, event_index: int) -> void:
	var player_id := str(play_event.get("player_id", ""))
	var source_id := str(play_event.get("source_instance_id", ""))
	var card_type := str(play_event.get("card_type", ""))
	var source_card := _snapshot_card_for_history(source_id)
	# Prefer the play-time snapshot from the event over the post-trigger state,
	# so shouts that upgrade themselves show the level that was actually played.
	var event_rules_text := str(play_event.get("source_rules_text", ""))
	if not event_rules_text.is_empty() and not source_card.is_empty():
		source_card["rules_text"] = event_rules_text
	var event_name := str(play_event.get("source_name", ""))
	if not event_name.is_empty() and not source_card.is_empty():
		source_card["name"] = event_name

	var entry := {
		"action_type": "play_card",
		"player_id": player_id,
		"source_card": source_card,
		"source_instance_id": source_id,
		"card_type": card_type,
		"targets": [] as Array,
		"chain": [] as Array,
	}

	# Collect targets from the play event itself
	var direct_target_id := str(play_event.get("target_instance_id", ""))
	var direct_target_player_id := str(play_event.get("target_player_id", ""))

	if card_type == "item":
		# Item: direct target is the creature it was equipped to
		if not direct_target_id.is_empty():
			var equipped_card := _snapshot_card_for_history(direct_target_id)
			entry["targets"].append({
				"kind": "creature",
				"card": equipped_card,
				"instance_id": direct_target_id,
				"destroyed": false,
			})
		# Look for subsequent summon-effect targets from this item
		var chain_targets := _collect_batch_targets(event_log, event_index, [source_id, direct_target_id])
		if not chain_targets.is_empty():
			entry["chain"].append({
				"source_card": _snapshot_card_for_history(direct_target_id) if not direct_target_id.is_empty() else {},
				"source_instance_id": direct_target_id,
				"targets": chain_targets,
			})
	elif card_type == "creature":
		# Creature with summon effect: look for damage/effect targets
		var summon_targets := _collect_batch_targets(event_log, event_index, [source_id])
		for t in summon_targets:
			entry["targets"].append(t)
	elif card_type == "action":
		# Action/spell: look for targets from effects
		if not direct_target_id.is_empty():
			var target_card := _snapshot_card_for_history(direct_target_id)
			var destroyed := _is_destroyed_in_batch(event_log, event_index, direct_target_id)
			entry["targets"].append({
				"kind": "creature",
				"card": target_card,
				"instance_id": direct_target_id,
				"destroyed": destroyed,
			})
		elif not direct_target_player_id.is_empty():
			entry["targets"].append({
				"kind": "player",
				"card": {},
				"instance_id": "",
				"player_id": direct_target_player_id,
				"destroyed": false,
			})
		# Also collect any additional targets from batch events
		var exclude_ids := [source_id]
		if not direct_target_id.is_empty():
			exclude_ids.append(direct_target_id)
		var extra_targets := _collect_batch_targets(event_log, event_index, exclude_ids)
		for t in extra_targets:
			entry["targets"].append(t)

	_add_history_entry(entry)


func _process_attack_history(attack_event: Dictionary, event_log: Array, event_index: int) -> void:
	var player_id := str(attack_event.get("attacking_player_id", ""))
	var attacker_id := str(attack_event.get("attacker_instance_id", ""))
	var target_type := str(attack_event.get("target_type", ""))
	var target_id := str(attack_event.get("target_instance_id", ""))
	var target_player_id := str(attack_event.get("target_player_id", ""))
	var attacker_card := _snapshot_card_for_history(attacker_id)

	var entry := {
		"action_type": "attack",
		"player_id": player_id,
		"source_card": attacker_card,
		"source_instance_id": attacker_id,
		"targets": [] as Array,
		"chain": [] as Array,
	}

	if target_type == "creature":
		var target_card := _snapshot_card_for_history(target_id)
		var target_destroyed := _is_destroyed_in_batch(event_log, event_index, target_id)
		var attacker_destroyed := _is_destroyed_in_batch(event_log, event_index, attacker_id)
		entry["targets"].append({
			"kind": "creature",
			"card": target_card,
			"instance_id": target_id,
			"destroyed": target_destroyed,
		})
		# Mark attacker as destroyed if it traded
		entry["attacker_destroyed"] = attacker_destroyed
	elif target_type == "player":
		var rune_breaks := _collect_rune_breaks(event_log, event_index, target_player_id)
		entry["targets"].append({
			"kind": "player",
			"card": {},
			"instance_id": "",
			"player_id": target_player_id,
			"destroyed": false,
			"rune_breaks": rune_breaks,
		})

	_add_history_entry(entry)


func _process_support_activated_history(support_event: Dictionary, event_log: Array, event_index: int) -> void:
	var player_id := str(support_event.get("player_id", ""))
	var source_id := str(support_event.get("source_instance_id", ""))
	var target_id := str(support_event.get("target_instance_id", ""))
	var source_card := _snapshot_card_for_history(source_id)

	# Only show targeted support activations
	if target_id.is_empty():
		return

	var entry := {
		"action_type": "activate_support",
		"player_id": player_id,
		"source_card": source_card,
		"source_instance_id": source_id,
		"targets": [] as Array,
		"chain": [] as Array,
	}

	var target_card := _snapshot_card_for_history(target_id)
	var destroyed := _is_destroyed_in_batch(event_log, event_index, target_id)
	entry["targets"].append({
		"kind": "creature",
		"card": target_card,
		"instance_id": target_id,
		"destroyed": destroyed,
	})

	_add_history_entry(entry)


func _find_batch_end(event_log: Array, start_index: int) -> int:
	# Find the end of the current action batch. A batch ends when we hit the
	# next top-level initiating event (card_played, attack_declared,
	# support_activated, turn_started) that has no parent_event_id.
	const INITIATING_TYPES := ["card_played", "attack_declared", "support_activated", "turn_started"]
	for i in range(start_index + 1, mini(event_log.size(), start_index + 80)):
		var evt: Dictionary = event_log[i]
		var evt_type := str(evt.get("event_type", ""))
		var parent_id := str(evt.get("parent_event_id", ""))
		if parent_id.is_empty() and INITIATING_TYPES.has(evt_type):
			return i
	return event_log.size()


func _collect_batch_targets(event_log: Array, start_index: int, exclude_ids: Array) -> Array:
	var targets: Array = []
	var seen_target_ids: Array = exclude_ids.duplicate()
	var batch_end := _find_batch_end(event_log, start_index)

	for i in range(start_index + 1, batch_end):
		var evt: Dictionary = event_log[i]
		var evt_type := str(evt.get("event_type", ""))

		if evt_type == "damage_resolved":
			var target_id := str(evt.get("target_instance_id", ""))
			var target_player_id := str(evt.get("target_player_id", ""))
			if not target_id.is_empty() and not seen_target_ids.has(target_id):
				seen_target_ids.append(target_id)
				var target_card := _snapshot_card_for_history(target_id)
				var destroyed := _is_destroyed_in_batch(event_log, start_index, target_id)
				targets.append({
					"kind": "creature",
					"card": target_card,
					"instance_id": target_id,
					"destroyed": destroyed,
				})
			elif not target_player_id.is_empty() and not seen_target_ids.has("player:" + target_player_id):
				seen_target_ids.append("player:" + target_player_id)
				targets.append({
					"kind": "player",
					"card": {},
					"instance_id": "",
					"player_id": target_player_id,
					"destroyed": false,
				})

	return targets


func _collect_rune_breaks(event_log: Array, start_index: int, target_player_id: String) -> Array:
	var runes: Array = []
	var batch_end := _find_batch_end(event_log, start_index)
	for i in range(start_index + 1, batch_end):
		var evt: Dictionary = event_log[i]
		if str(evt.get("event_type", "")) == "rune_broken":
			var rune_player := str(evt.get("player_id", ""))
			if rune_player == target_player_id:
				runes.append(int(evt.get("threshold", 0)))
	return runes


func _is_destroyed_in_batch(event_log: Array, start_index: int, instance_id: String) -> bool:
	var batch_end := _find_batch_end(event_log, start_index)
	for i in range(start_index + 1, batch_end):
		var evt: Dictionary = event_log[i]
		if str(evt.get("event_type", "")) == "creature_destroyed":
			var destroyed_id := str(evt.get("source_instance_id", ""))
			if destroyed_id == instance_id:
				return true
	return false


func _snapshot_card_for_history(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	# Try to find the card in current match state
	var location := MatchMutations.find_card_location(_match_state, instance_id)
	if bool(location.get("is_valid", false)):
		var card: Dictionary = location["card"]
		var snapshot := card.duplicate(true)
		_match_history_card_snapshots[instance_id] = snapshot
		return snapshot
	# Fall back to cached snapshot
	if _match_history_card_snapshots.has(instance_id):
		return _match_history_card_snapshots[instance_id]
	return {}


func _add_history_entry(entry: Dictionary) -> void:
	_match_history_entries.append(entry)
	if _match_history_entries.size() > MATCH_HISTORY_MAX_ENTRIES:
		_match_history_entries.pop_front()


func _refresh_match_history_row() -> void:
	if _match_history_container == null:
		return
	for child in _match_history_container.get_children():
		child.queue_free()
	for entry_index in range(_match_history_entries.size()):
		var entry: Dictionary = _match_history_entries[entry_index]
		var icon := _build_match_history_icon(entry, entry_index)
		_match_history_container.add_child(icon)


func _build_match_history_icon(entry: Dictionary, entry_index: int) -> Button:
	var is_local := str(entry.get("player_id", "")) == _local_player_id()
	var border_color := MATCH_HISTORY_PLAYER_BORDER_COLOR if is_local else MATCH_HISTORY_OPPONENT_BORDER_COLOR
	var fill := Color(0.1, 0.1, 0.12, 0.96)

	var button := Button.new()
	button.custom_minimum_size = MATCH_HISTORY_ICON_SIZE
	button.clip_contents = true
	_apply_button_style(button, fill, border_color, Color.WHITE, MATCH_HISTORY_ICON_BORDER_WIDTH, 6)
	button.pressed.connect(_on_match_history_icon_pressed.bind(entry_index))
	button.mouse_entered.connect(_on_match_history_mouse_entered.bind(entry, entry_index))
	button.mouse_exited.connect(_on_match_history_mouse_exited)

	var source_card: Dictionary = entry.get("source_card", {})
	if not source_card.is_empty():
		var tex_rect := TextureRect.new()
		tex_rect.texture = _resolve_history_art_texture(source_card)
		tex_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		tex_rect.offset_left = MATCH_HISTORY_ICON_BORDER_WIDTH
		tex_rect.offset_top = MATCH_HISTORY_ICON_BORDER_WIDTH
		tex_rect.offset_right = -MATCH_HISTORY_ICON_BORDER_WIDTH
		tex_rect.offset_bottom = -MATCH_HISTORY_ICON_BORDER_WIDTH
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(tex_rect)

	return button


func _resolve_history_art_texture(card: Dictionary) -> Texture2D:
	# Check for direct texture or path on the card
	for key in ["art_texture", "art"]:
		var direct = card.get(key, null)
		if direct is Texture2D:
			return direct as Texture2D
	for key in ["art_path", "art_resource_path", "art"]:
		var path := str(card.get(key, "")).strip_edges()
		if path.is_empty():
			continue
		if ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is Texture2D:
				return loaded as Texture2D
	# Fall back to catalog art_path via definition_id (covers generated cards)
	var def_id := str(card.get("definition_id", ""))
	if not def_id.is_empty():
		var catalog_path := "res://assets/images/cards/" + def_id + ".png"
		if ResourceLoader.exists(catalog_path):
			var loaded = load(catalog_path)
			if loaded is Texture2D:
				return loaded as Texture2D
	# Fall back to the default card placeholder
	var placeholder_path := "res://assets/images/cards/placeholder.png"
	if ResourceLoader.exists(placeholder_path):
		var loaded = load(placeholder_path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null


func _on_match_history_icon_pressed(entry_index: int) -> void:
	var current_index: int = _match_history_popover_state.get("entry_index", -1)
	if current_index == entry_index:
		_dismiss_match_history_popover()
		return
	_dismiss_match_history_popover()
	_show_match_history_popover(entry_index)


func _show_match_history_popover(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= _match_history_entries.size():
		return
	var entry: Dictionary = _match_history_entries[entry_index]

	# Full-screen overlay to capture dismiss clicks
	var overlay := Control.new()
	overlay.name = "MatchHistoryPopover"
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 460
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_match_history_popover_bg_input)
	overlay.add_child(bg)

	# Center container for content
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var content_panel := PanelContainer.new()
	content_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(content_panel, Color(0.08, 0.09, 0.11, 0.97), Color(0.35, 0.36, 0.42, 0.9), 2, 12)
	center.add_child(content_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	content_panel.add_child(margin)

	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content_hbox)

	var source_card: Dictionary = entry.get("source_card", {})
	var source_player_id := str(entry.get("player_id", ""))
	var action_type := str(entry.get("action_type", ""))
	var attacker_destroyed := bool(entry.get("attacker_destroyed", false))

	# Source card
	var source_section := _build_history_popover_card_section(source_card, source_player_id, attacker_destroyed)
	content_hbox.add_child(source_section)

	# Targets
	var targets: Array = entry.get("targets", [])
	var chain: Array = entry.get("chain", [])

	if not targets.is_empty() or not chain.is_empty():
		# Arrow
		var arrow_label := Label.new()
		arrow_label.text = "→"
		arrow_label.add_theme_font_size_override("font_size", 36)
		arrow_label.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78, 1.0))
		arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_hbox.add_child(arrow_label)

		# Targets
		var targets_hbox := HBoxContainer.new()
		targets_hbox.add_theme_constant_override("separation", 12)

		for target in targets:
			var target_section := _build_history_popover_target_section(target)
			targets_hbox.add_child(target_section)

		content_hbox.add_child(targets_hbox)

		# Chain (for item -> creature -> subsequent targets)
		for chain_entry in chain:
			var chain_targets: Array = chain_entry.get("targets", [])
			if chain_targets.is_empty():
				continue

			var chain_arrow := Label.new()
			chain_arrow.text = "→"
			chain_arrow.add_theme_font_size_override("font_size", 36)
			chain_arrow.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78, 1.0))
			chain_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			content_hbox.add_child(chain_arrow)

			var chain_hbox := HBoxContainer.new()
			chain_hbox.add_theme_constant_override("separation", 12)

			for chain_target in chain_targets:
				var ct_section := _build_history_popover_target_section(chain_target)
				chain_hbox.add_child(ct_section)

			content_hbox.add_child(chain_hbox)

	add_child(overlay)
	_match_history_popover_state = {"overlay": overlay, "entry_index": entry_index}
	var source_card_name := str(source_card.get("name", "unknown"))
	_error_report_hovered_type = "match_history"
	_error_report_hovered_context = "Match History Entry #%d (%s)" % [entry_index + 1, source_card_name]


func _build_history_popover_card_section(card: Dictionary, player_id: String, destroyed: bool) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.alignment = BoxContainer.ALIGNMENT_CENTER

	# Player label
	var label := Label.new()
	label.text = "You" if player_id == _local_player_id() else "Opponent"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(label)

	if card.is_empty():
		# Hidden info placeholder
		var placeholder := _build_hidden_card_placeholder()
		section.add_child(placeholder)
	else:
		var card_wrapper := PanelContainer.new()
		card_wrapper.custom_minimum_size = Vector2(180, 310)
		var wrapper_style := StyleBoxFlat.new()
		wrapper_style.bg_color = Color(0.12, 0.11, 0.14, 0.95)
		wrapper_style.corner_radius_top_left = 6
		wrapper_style.corner_radius_top_right = 6
		wrapper_style.corner_radius_bottom_left = 6
		wrapper_style.corner_radius_bottom_right = 6
		card_wrapper.add_theme_stylebox_override("panel", wrapper_style)

		var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_wrapper.add_child(component)

		if destroyed:
			# Grey out and add red X
			component.modulate = Color(0.4, 0.4, 0.4, 0.7)
			var x_label := Label.new()
			x_label.text = "✕"
			x_label.add_theme_font_size_override("font_size", 72)
			x_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.15, 0.85))
			x_label.set_anchors_and_offsets_preset(PRESET_CENTER)
			x_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			x_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card_wrapper.add_child(x_label)

		section.add_child(card_wrapper)

	return section


func _build_history_popover_target_section(target: Dictionary) -> VBoxContainer:
	var kind := str(target.get("kind", ""))
	var target_player_id := str(target.get("player_id", ""))
	var target_card: Dictionary = target.get("card", {})
	var destroyed := bool(target.get("destroyed", false))

	if kind == "player":
		# Player avatar target
		var player_id_for_label := target_player_id if not target_player_id.is_empty() else ""
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)
		section.alignment = BoxContainer.ALIGNMENT_CENTER

		var label := Label.new()
		label.text = "You" if player_id_for_label == _local_player_id() else "Opponent"
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_child(label)

		var avatar_panel := PanelContainer.new()
		avatar_panel.custom_minimum_size = Vector2(120, 120)
		var avatar_style := StyleBoxFlat.new()
		avatar_style.bg_color = Color(0.15, 0.14, 0.18, 0.95)
		avatar_style.corner_radius_top_left = 60
		avatar_style.corner_radius_top_right = 60
		avatar_style.corner_radius_bottom_left = 60
		avatar_style.corner_radius_bottom_right = 60
		avatar_style.border_color = Color(0.5, 0.48, 0.42, 0.8)
		avatar_style.border_width_left = 2
		avatar_style.border_width_top = 2
		avatar_style.border_width_right = 2
		avatar_style.border_width_bottom = 2
		avatar_panel.add_theme_stylebox_override("panel", avatar_style)

		var avatar_label := Label.new()
		avatar_label.text = "Face"
		avatar_label.add_theme_font_size_override("font_size", 20)
		avatar_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78, 1.0))
		avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar_label.set_anchors_and_offsets_preset(PRESET_CENTER)
		avatar_panel.add_child(avatar_label)
		section.add_child(avatar_panel)

		# Rune breaks
		var rune_breaks: Array = target.get("rune_breaks", [])
		if not rune_breaks.is_empty():
			var rune_row := HBoxContainer.new()
			rune_row.add_theme_constant_override("separation", 4)
			rune_row.alignment = BoxContainer.ALIGNMENT_CENTER
			for threshold in rune_breaks:
				var rune_panel := PanelContainer.new()
				rune_panel.custom_minimum_size = Vector2(32, 32)
				var rune_style := StyleBoxFlat.new()
				rune_style.bg_color = Color(0.12, 0.1, 0.2, 0.95)
				rune_style.corner_radius_top_left = 4
				rune_style.corner_radius_top_right = 4
				rune_style.corner_radius_bottom_left = 4
				rune_style.corner_radius_bottom_right = 4
				rune_style.border_color = Color(0.6, 0.25, 0.2, 0.9)
				rune_style.border_width_left = 1
				rune_style.border_width_top = 1
				rune_style.border_width_right = 1
				rune_style.border_width_bottom = 1
				rune_panel.add_theme_stylebox_override("panel", rune_style)

				var rune_label := Label.new()
				rune_label.text = "✕"
				rune_label.add_theme_font_size_override("font_size", 16)
				rune_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.15, 0.9))
				rune_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				rune_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				rune_label.set_anchors_and_offsets_preset(PRESET_CENTER)
				rune_panel.add_child(rune_label)
				rune_row.add_child(rune_panel)
			section.add_child(rune_row)

		return section
	else:
		# Creature/card target
		var controller_id := str(target_card.get("controller_player_id", target_card.get("owner_player_id", "")))
		return _build_history_popover_card_section(target_card, controller_id, destroyed)


func _build_hidden_card_placeholder() -> PanelContainer:
	var placeholder := PanelContainer.new()
	placeholder.custom_minimum_size = Vector2(180, 310)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.13, 0.17, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = Color(0.4, 0.38, 0.34, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	placeholder.add_theme_stylebox_override("panel", style)

	var mystery_label := Label.new()
	mystery_label.text = "???"
	mystery_label.add_theme_font_size_override("font_size", 36)
	mystery_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55, 0.8))
	mystery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mystery_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mystery_label.set_anchors_and_offsets_preset(PRESET_CENTER)
	placeholder.add_child(mystery_label)

	return placeholder


func _on_match_history_popover_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_match_history_popover()


func _dismiss_match_history_popover() -> void:
	if _match_history_popover_state.is_empty():
		return
	var overlay: Control = _match_history_popover_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_match_history_popover_state = {}
	if _error_report_hovered_type == "match_history":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


# --- Error Report Hover Handlers ---

func _on_avatar_mouse_entered(player_id: String) -> void:
	var label := "Player Avatar" if player_id == _local_player_id() else "Opponent Avatar"
	_error_report_hovered_type = "avatar"
	_error_report_hovered_context = label


func _on_avatar_mouse_exited() -> void:
	if _error_report_hovered_type == "avatar":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


func _on_magicka_mouse_entered(player_id: String) -> void:
	var label := "Player Magicka" if player_id == _local_player_id() else "Opponent Magicka"
	_error_report_hovered_type = "magicka"
	_error_report_hovered_context = label


func _on_magicka_mouse_exited() -> void:
	if _error_report_hovered_type == "magicka":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


func _on_ring_mouse_entered(player_id: String) -> void:
	var label := "Ring of Magicka (Player)" if player_id == _local_player_id() else "Ring of Magicka (Opponent)"
	_error_report_hovered_type = "ring_of_magicka"
	_error_report_hovered_context = label


func _on_ring_mouse_exited() -> void:
	if _error_report_hovered_type == "ring_of_magicka":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


func _on_lane_mouse_entered(lane_id: String) -> void:
	_error_report_hovered_type = "lane"
	_error_report_hovered_context = _lane_name(lane_id)


func _on_lane_mouse_exited() -> void:
	if _error_report_hovered_type == "lane":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


func _on_lane_icon_mouse_entered(lane_id: String, icon: Control) -> void:
	_lane_tooltip_name_label.text = _lane_name(lane_id)
	_lane_tooltip_desc_label.text = _lane_description(lane_id)
	_lane_tooltip_panel.reset_size()
	_lane_tooltip_panel.visible = true
	# Position tooltip above the icon, anchored to the icon's global position
	# Overlap the icon by a few pixels to prevent flicker when cursor moves between icon and tooltip
	await get_tree().process_frame
	var icon_rect := icon.get_global_rect()
	var tooltip_size := _lane_tooltip_panel.size
	_lane_tooltip_panel.position = Vector2(
		clampf(icon_rect.position.x + icon_rect.size.x * 0.5 - tooltip_size.x * 0.5, 8.0, size.x - tooltip_size.x - 8.0),
		icon_rect.position.y - tooltip_size.y + 4.0
	)


func _on_lane_icon_mouse_exited() -> void:
	# Delay hide so cursor can travel onto the tooltip without flicker
	await get_tree().create_timer(0.08).timeout
	if _lane_tooltip_panel == null:
		return
	var mouse_pos := get_global_mouse_position()
	var tooltip_rect := _lane_tooltip_panel.get_global_rect().grow(4.0)
	if not tooltip_rect.has_point(mouse_pos):
		_lane_tooltip_panel.visible = false


func _on_lane_tooltip_mouse_exited() -> void:
	_lane_tooltip_panel.visible = false


func _build_lane_tooltip_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "LaneTooltipPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.z_index = 500
	panel.custom_minimum_size = Vector2(220, 0)
	panel.mouse_exited.connect(_on_lane_tooltip_mouse_exited)
	_apply_panel_style(panel, Color(0.1, 0.08, 0.12, 0.95), Color(0.55, 0.45, 0.35, 0.8), 2, 8)
	var box := _build_panel_box(panel, 6, 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lane_tooltip_name_label = Label.new()
	_lane_tooltip_name_label.name = "LaneTooltipName"
	_lane_tooltip_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lane_tooltip_name_label.add_theme_font_size_override("font_size", 20)
	_lane_tooltip_name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	_lane_tooltip_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lane_tooltip_name_label)
	_lane_tooltip_desc_label = Label.new()
	_lane_tooltip_desc_label.name = "LaneTooltipDesc"
	_lane_tooltip_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lane_tooltip_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lane_tooltip_desc_label.custom_minimum_size = Vector2(192, 0)
	_lane_tooltip_desc_label.add_theme_font_size_override("font_size", 17)
	_lane_tooltip_desc_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72))
	_lane_tooltip_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lane_tooltip_desc_label)
	return panel


func _on_match_history_mouse_entered(entry: Dictionary, entry_index: int) -> void:
	var source_card: Dictionary = entry.get("source_card", {})
	var card_name := str(source_card.get("name", "unknown"))
	_error_report_hovered_type = "match_history"
	_error_report_hovered_context = "Match History Entry #%d (%s)" % [entry_index + 1, card_name]


func _on_match_history_mouse_exited() -> void:
	if _error_report_hovered_type == "match_history" and _match_history_popover_state.is_empty():
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


# --- Error Report Popover ---

func _open_error_report_popover() -> void:
	if _error_report_popover != null:
		return
	var context_label := _error_report_hovered_context if not _error_report_hovered_type.is_empty() else "Match (general)"
	var element_type := _error_report_hovered_type if not _error_report_hovered_type.is_empty() else "general"
	var element_context := _error_report_hovered_context if not _error_report_hovered_type.is_empty() else "match"

	_error_report_popover = ErrorReportPopoverClass.new()
	_error_report_popover.report_submitted.connect(_on_error_report_submitted.bind(element_type, element_context))
	_error_report_popover.dismissed.connect(_on_error_report_dismissed)
	add_child(_error_report_popover)
	_error_report_popover.show_report(context_label)


func _on_error_report_submitted(comment: String, element_type: String, element_context: String) -> void:
	var snapshot := ErrorReportWriterClass.build_match_snapshot(_match_state, _match_history_entries)
	# Attach adventure mode context if present
	if not _adventure_boons.is_empty():
		snapshot["adventure_boons"] = _adventure_boons.duplicate()
	if not _adventure_augments.is_empty():
		snapshot["adventure_augments"] = _adventure_augments.duplicate(true)
	var report := {
		"screen": "match",
		"element_type": element_type,
		"element_context": element_context,
		"comment": comment,
		"snapshot": snapshot,
	}
	ErrorReportWriterClass.write_report(report)
	_error_report_popover = null


func _on_error_report_dismissed() -> void:
	_error_report_popover = null


func _find_card_lane_id(instance_id: String) -> String:
	for lane in _match_state.get("lanes", []):
		var player_slots: Dictionary = lane.get("player_slots", {})
		for pid in player_slots.keys():
			for card in player_slots[pid]:
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return str(lane.get("lane_id", ""))
	return ""


func _debug_dump_hovered() -> void:
	var instance_id := ""
	if _hovered_hand_instance_id != "":
		instance_id = _hovered_hand_instance_id
	elif _lane_hover_preview_instance_id != "" or not _lane_hover_preview_pending.is_empty():
		instance_id = _lane_hover_preview_instance_id if _lane_hover_preview_instance_id != "" else str(_lane_hover_preview_pending.get("instance_id", ""))
	elif _support_hover_preview_instance_id != "" or not _support_hover_preview_pending.is_empty():
		instance_id = _support_hover_preview_instance_id if _support_hover_preview_instance_id != "" else str(_support_hover_preview_pending.get("instance_id", ""))
	if not instance_id.is_empty():
		_debug_dump_card(instance_id)
		return
	if not _hovered_pile_zone.is_empty():
		_debug_dump_pile(_hovered_pile_player_id, _hovered_pile_zone)
		return
	print("[DEBUG DUMP] No card or pile currently hovered.")


func _debug_dump_card(instance_id: String) -> void:
	var match_card := _card_from_instance_id(instance_id)
	var definition_id := str(match_card.get("definition_id", ""))
	var card_name := str(match_card.get("name", definition_id))
	print("=== DEBUG DUMP: %s (instance: %s) ===" % [card_name, instance_id])
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	var catalog_entry: Dictionary = card_by_id.get(definition_id, {})
	if catalog_entry.is_empty():
		print("  [Catalog] No catalog entry found for definition_id: %s" % definition_id)
	else:
		print("  [Catalog Definition]")
		for key in catalog_entry.keys():
			print("    %s: %s" % [key, str(catalog_entry[key])])
	print("  [Match State]")
	for key in match_card.keys():
		print("    %s: %s" % [key, str(match_card[key])])
	print("=== END DEBUG DUMP ===")


func _debug_dump_pile(player_id: String, zone: String) -> void:
	var player := _player_state(player_id)
	var pile: Array = player.get(zone, [])
	var zone_label := "Deck" if zone == MatchMutations.ZONE_DECK else "Discard"
	var owner_label := _player_name(player_id)
	print("=== DEBUG DUMP: %s's %s (%d cards) ===" % [owner_label, zone_label, pile.size()])
	for i in pile.size():
		var card: Dictionary = pile[i] if typeof(pile[i]) == TYPE_DICTIONARY else {}
		var card_name := str(card.get("name", "???"))
		var card_id := str(card.get("card_id", ""))
		var iid := str(card.get("instance_id", ""))
		var cost := str(card.get("cost", "?"))
		print("  [%d] %s (id: %s, instance: %s, cost: %s)" % [i, card_name, card_id, iid, cost])
	print("=== END DEBUG DUMP ===")
