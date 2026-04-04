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
const MatchScreenUIBuilderClass = preload("res://src/ui/match_screen_ui_builder.gd")
const MatchScreenCardSurfaceClass = preload("res://src/ui/match_screen_card_surface.gd")
const MatchScreenFeedbackClass = preload("res://src/ui/match_screen_feedback.gd")
const MatchScreenRefreshClass = preload("res://src/ui/match_screen_refresh.gd")
const MatchScreenSelectionClass = preload("res://src/ui/match_screen_selection.gd")
const MatchScreenAnimationsClass = preload("res://src/ui/match_screen_animations.gd")
const MatchScreenCardDisplayClass = preload("res://src/ui/match_screen_card_display.gd")
const MatchScreenAIClass = preload("res://src/ui/match_screen_ai.gd")
const MatchScreenHandClass = preload("res://src/ui/match_screen_hand.gd")
const MatchScreenHoverClass = preload("res://src/ui/match_screen_hover.gd")
const MatchScreenOverlaysClass = preload("res://src/ui/match_screen_overlays.gd")
const MatchScreenBetrayClass = preload("res://src/ui/match_screen_betray.gd")
const MatchScreenTargetingClass = preload("res://src/ui/match_screen_targeting.gd")
const ActiveBoonsOverlay = preload("res://src/ui/match/active_boons_overlay.gd")
const MatchScreenHistoryClass = preload("res://src/ui/match_screen_history.gd")

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

var _ui_builder: RefCounted  # MatchScreenUIBuilder
var _card_surface: RefCounted  # MatchScreenCardSurface
var _feedback: RefCounted  # MatchScreenFeedback
var _refresh: RefCounted  # MatchScreenRefresh
var _selection: RefCounted  # MatchScreenSelection
var _animations: RefCounted  # MatchScreenAnimations
var _card_display: RefCounted  # MatchScreenCardDisplay
var _ai_system: RefCounted  # MatchScreenAI
var _hand: RefCounted  # MatchScreenHand
var _hover: RefCounted  # MatchScreenHover
var _overlays: RefCounted  # MatchScreenOverlays
var _betray: RefCounted  # MatchScreenBetray
var _targeting: RefCounted  # MatchScreenTargeting
var _history: RefCounted  # MatchScreenHistory
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
var _targeting_arrow: Line2D
var _host_arrow_instance_id := ""
var _pending_end_turn := false
var _pending_end_turn_player_id := ""
var _betray_skip_button: Button = null
var _betray_prompt_label: Label = null
var _exalt_button_container: Control = null
var _exalt_card_preview: Control = null
var _prophecy_card_overlay: Control
var _mulligan_instance_id_order: Array = []
var _top_deck_choice_panel: Control = null
var _attack_feedbacks: Array = []
var _damage_feedbacks: Array = []
var _removal_feedbacks: Array = []
var _draw_feedbacks: Array = []
var _rune_feedbacks: Array = []
var _local_hand_overlay: Control
var _opponent_hand_overlay: Control
var _player_avatar_overlay: Control
var _opponent_avatar_overlay: Control
var _card_hover_preview_layer: Control
var _lane_hover_preview_instance_id := ""
var _lane_hover_preview_button_ref: WeakRef
var _support_hover_preview_instance_id := ""
var _support_hover_preview_button_ref: WeakRef
var _last_turn_owner_id := ""
var _turn_banner_until_ms := 0
var _queued_ai_step_at_ms := -1
var _paused_ai_step_delay_ms := -1
var _hovered_hand_instance_id := ""
var _hovered_pile_player_id := ""
var _hovered_pile_zone := ""
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

# AI play profile options built from deck archetype detection and quality scaling.
# Persisted in match_state["ai_options"] for resume support.


func _ready() -> void:
	_ui_builder = MatchScreenUIBuilderClass.new(self)
	_card_surface = MatchScreenCardSurfaceClass.new(self)
	_feedback = MatchScreenFeedbackClass.new(self)
	_refresh = MatchScreenRefreshClass.new(self)
	_selection = MatchScreenSelectionClass.new(self)
	_animations = MatchScreenAnimationsClass.new(self)
	_card_display = MatchScreenCardDisplayClass.new(self)
	_ai_system = MatchScreenAIClass.new(self)
	_hand = MatchScreenHandClass.new(self)
	_hover = MatchScreenHoverClass.new(self)
	_overlays = MatchScreenOverlaysClass.new(self)
	_betray = MatchScreenBetrayClass.new(self)
	_targeting = MatchScreenTargetingClass.new(self)
	_history = MatchScreenHistoryClass.new(self)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	set_process(true)
	_load_registries()
	_ui_builder._build_ui()
	load_scenario(_scenario_id)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _overlays._mulligan_overlay_state.is_empty():
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_overlays._on_mulligan_confirm_pressed()
		get_viewport().set_input_as_handled()
		return
	var key_index := -1
	match key_event.keycode:
		KEY_1: key_index = 0
		KEY_2: key_index = 1
		KEY_3: key_index = 2
	if key_index >= 0 and key_index < _mulligan_instance_id_order.size():
		_overlays._on_mulligan_card_toggled(_mulligan_instance_id_order[key_index])
		get_viewport().set_input_as_handled()


func start_match_with_decks(deck_one_ids: Array, deck_two_ids: Array, seed: int = -1, first_player_index: int = -1, ai_options: Dictionary = {}) -> bool:
	_hand._cancel_detached_card_silent()
	_overlays._dismiss_mulligan_overlay()
	_overlays._dismiss_prophecy_overlay()
	_overlays._dismiss_discard_viewer()
	_overlays._dismiss_discard_choice_overlay()
	_overlays._dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_overlays._dismiss_player_choice_overlay()
	_overlays._exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_feedback._dismiss_spell_reveal()
	_reset_invalid_feedback()
	_animations._clear_feedback_state()
	_ai_system._reset_local_match_ai_queue()
	_history._reset_match_history()
	_ai_system._local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	if card_by_id.is_empty():
		_status_message = "Failed to load card catalog."
		_refresh._refresh_ui()
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
		_refresh._refresh_ui()
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
	_ai_system._ai_options = MatchScreenAIClass._build_ai_play_profile(ai_options, card_by_id)
	_match_state["ai_options"] = _ai_system._ai_options
	_overlays._mulligan_card_by_id = card_by_id
	_ai_system._ai_enabled = false
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_animations._floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	_status_message = "Choose cards to replace."
	_refresh._refresh_ui()
	_overlays._show_mulligan_overlay()
	return true


func start_arena_boss_match(deck_one_ids: Array, deck_two_ids: Array, boss_config: Dictionary, seed: int = -1, first_player_index: int = -1, ai_options: Dictionary = {}) -> bool:
	_hand._cancel_detached_card_silent()
	_overlays._dismiss_mulligan_overlay()
	_overlays._dismiss_prophecy_overlay()
	_overlays._dismiss_discard_viewer()
	_overlays._dismiss_discard_choice_overlay()
	_overlays._dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_overlays._dismiss_player_choice_overlay()
	_overlays._exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_feedback._dismiss_spell_reveal()
	_reset_invalid_feedback()
	_animations._clear_feedback_state()
	_ai_system._reset_local_match_ai_queue()
	_history._reset_match_history()
	_ai_system._local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	if card_by_id.is_empty():
		_status_message = "Failed to load card catalog."
		_refresh._refresh_ui()
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
		_refresh._refresh_ui()
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
	_ai_system._ai_options = MatchScreenAIClass._build_ai_play_profile(ai_options, card_by_id)
	_match_state["ai_options"] = _ai_system._ai_options
	_overlays._mulligan_card_by_id = card_by_id
	_ai_system._ai_enabled = false
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_animations._floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	_status_message = "Choose cards to replace."
	_refresh._refresh_ui()
	_overlays._show_mulligan_overlay()
	return true


## Build the AI play profile from the provided ai_options (quality + AI deck IDs).
## Detects the deck archetype and produces interpolated weight options that shape
## how the AI prioritises face damage, board control, and card advantage.
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
	_hand._cancel_detached_card_silent()
	_overlays._dismiss_mulligan_overlay()
	_overlays._dismiss_prophecy_overlay()
	_overlays._dismiss_discard_viewer()
	_overlays._dismiss_discard_choice_overlay()
	_overlays._dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_overlays._dismiss_player_choice_overlay()
	_overlays._exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_feedback._dismiss_spell_reveal()
	_reset_invalid_feedback()
	_animations._clear_feedback_state()
	_ai_system._reset_local_match_ai_queue()
	_history._reset_match_history()
	_ai_system._local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	_hydrate_all_zones(test_state, card_by_id)
	GameLogger.start_match(test_state)
	_match_state = test_state
	_ai_system._ai_options = {}
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_animations._floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	_overlays._mulligan_card_by_id = {}
	_ai_system._ai_enabled = true
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
	_refresh._refresh_ui()


func start_puzzle_match(puzzle_state: Dictionary, puzzle_config: Dictionary = {},
		puzzle_id: String = "", ai_options: Dictionary = {}) -> void:
	_hand._cancel_detached_card_silent()
	_overlays._dismiss_mulligan_overlay()
	_overlays._dismiss_prophecy_overlay()
	_overlays._dismiss_discard_viewer()
	_overlays._dismiss_discard_choice_overlay()
	_overlays._dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_overlays._dismiss_player_choice_overlay()
	_overlays._exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_feedback._dismiss_spell_reveal()
	_reset_invalid_feedback()
	_animations._clear_feedback_state()
	_ai_system._reset_local_match_ai_queue()
	_history._reset_match_history()
	_ai_system._local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	_hydrate_all_zones(puzzle_state, card_by_id)
	GameLogger.start_match(puzzle_state)
	_match_state = puzzle_state
	_ai_system._ai_options = ai_options
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_animations._floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	_overlays._mulligan_card_by_id = {}
	_ai_system._ai_enabled = true
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
	# Emit creature_summoned events for all pre-placed lane creatures so that
	# summon effects fire and lane effects (e.g. shadow lane cover) are applied.
	for lane in puzzle_state.get("lanes", []):
		var lane_id := str(lane.get("lane_id", ""))
		var player_slots: Dictionary = lane.get("player_slots", {})
		for pid in player_slots:
			var slots: Array = player_slots[pid]
			for slot_idx in range(slots.size()):
				var creature = slots[slot_idx]
				if typeof(creature) != TYPE_DICTIONARY:
					continue
				MatchTiming.publish_events(puzzle_state, [{
					"event_type": MatchTiming.EVENT_CREATURE_SUMMONED,
					"playing_player_id": str(pid),
					"player_id": str(pid),
					"source_instance_id": str(creature.get("instance_id", "")),
					"source_controller_player_id": str(pid),
					"lane_id": lane_id,
					"slot_index": slot_idx,
					"reason": "puzzle_starting_board",
				}])
	MatchTiming.publish_events(puzzle_state, [{
		"event_type": MatchTiming.EVENT_TURN_STARTED,
		"player_id": str(puzzle_state.get("active_player_id", "")),
		"source_controller_player_id": str(puzzle_state.get("active_player_id", "")),
		"turn_number": int(puzzle_state.get("turn_number", 1)),
	}])
	_status_message = ""
	_rebuild_pause_overlay()
	_refresh._refresh_ui()
	_show_puzzle_objective_popup()


func _rebuild_pause_overlay() -> void:
	if _pause_overlay != null:
		var parent := _pause_overlay.get_parent()
		_pause_overlay.queue_free()
		_pause_overlay = _ui_builder._build_pause_overlay()
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
	_hand._cancel_detached_card_silent()
	_overlays._dismiss_mulligan_overlay()
	_overlays._dismiss_prophecy_overlay()
	_overlays._dismiss_discard_viewer()
	_overlays._dismiss_discard_choice_overlay()
	_overlays._dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_overlays._dismiss_player_choice_overlay()
	_overlays._exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_feedback._dismiss_spell_reveal()
	_reset_invalid_feedback()
	_animations._clear_feedback_state()
	_ai_system._reset_local_match_ai_queue()
	_ai_system._local_match_ai_action_count = 0
	var catalog_result := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	_hydrate_all_zones(saved_state, card_by_id)
	GameLogger.start_match(saved_state)
	_match_state = saved_state
	# Restore AI play profile from saved state (persisted during match start).
	_ai_system._ai_options = _match_state.get("ai_options", {})
	_scenario_id = LOCAL_MATCH_AI_SCENARIO_ID
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_animations._floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	var phase := str(_match_state.get("phase", ""))
	var winner := str(_match_state.get("winner_player_id", ""))
	if not winner.is_empty():
		# Match already ended — trigger result flow immediately
		_ai_system._ai_enabled = false
		_status_message = "Match complete."
		_refresh._refresh_ui()
		return_to_main_menu_requested.emit()
		return
	if phase == "mulligan":
		_overlays._mulligan_card_by_id = card_by_id
		_ai_system._ai_enabled = false
		_status_message = "Choose cards to replace."
		_refresh._refresh_ui()
		_overlays._show_mulligan_overlay()
	else:
		_overlays._mulligan_card_by_id = {}
		_ai_system._ai_enabled = true
		_status_message = "Match resumed."
		_refresh._refresh_ui()


func _process(_delta: float) -> void:
	if _turn_banner_panel == null:
		return
	var should_show := _turn_banner_until_ms > Time.get_ticks_msec()
	if _turn_banner_panel.visible != should_show:
		_turn_banner_panel.visible = should_show
	_hover._process_lane_card_hover_preview()
	_process_support_card_hover_preview()
	_ai_system._process_local_match_ai_turn()
	_selection._check_pending_forced_play()


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
		"selection_mode": _selection._selected_action_mode(_selection._selected_card()),
		"local_turn": _is_local_player_turn(),
		"local_controls_locked": _should_dim_local_interaction_surfaces(),
		"turn_banner_visible": _ai_system._is_turn_banner_active(),
		"valid_lane_slot_keys": _selection._valid_lane_slot_keys(),
		"valid_lane_ids": _selection._valid_lane_ids(),
		"valid_target_instance_ids": _selection._valid_card_target_ids(),
		"valid_target_player_ids": _selection._valid_player_target_ids(),
		"invalid_lane_slot_keys": _copy_array(_invalid_feedback.get("lane_slot_keys", [])),
		"invalid_lane_ids": _copy_array(_invalid_feedback.get("lane_ids", [])),
		"invalid_target_instance_ids": _copy_array(_invalid_feedback.get("instance_ids", [])),
		"invalid_player_ids": _copy_array(_invalid_feedback.get("player_ids", [])),
		"detached_active": not _hand._detached_card_state.is_empty(),
		"detached_instance_id": str(_hand._detached_card_state.get("instance_id", "")),
	}


func get_feedback_state() -> Dictionary:
	_feedback._prune_feedback_state()
	return {
		"attacks": _attack_feedbacks.duplicate(true),
		"damage": _damage_feedbacks.duplicate(true),
		"removals": _removal_feedbacks.duplicate(true),
		"draws": _draw_feedbacks.duplicate(true),
		"runes": _rune_feedbacks.duplicate(true),
	}


func detach_hand_card(instance_id: String) -> bool:
	if not _hand._is_local_hand_card(instance_id):
		return false
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return false
	var mode = _selection._selected_action_mode(card)
	if mode == SELECTION_MODE_NONE:
		return false
	_hand._detach_hand_card(instance_id)
	return true


func is_card_detached() -> bool:
	return not _hand._detached_card_state.is_empty()


func load_scenario(scenario_id: String) -> bool:
	_hand._cancel_detached_card_silent()
	_overlays._dismiss_mulligan_overlay()
	_overlays._dismiss_prophecy_overlay()
	_overlays._dismiss_discard_viewer()
	_overlays._dismiss_discard_choice_overlay()
	_overlays._dismiss_consume_selection_overlay()
	_dismiss_deck_selection_overlay()
	_overlays._dismiss_player_choice_overlay()
	_overlays._exit_hand_selection_mode()
	_exit_top_deck_choice_mode()
	_feedback._dismiss_spell_reveal()
	_reset_invalid_feedback()
	_animations._clear_feedback_state()
	_ai_system._reset_local_match_ai_queue()
	_ai_system._local_match_ai_action_count = 0
	var next_state: Dictionary = MatchDebugScenarios.build_scenario(scenario_id)
	if next_state.is_empty():
		_status_message = "Failed to load scenario %s." % scenario_id
		_refresh._refresh_ui()
		return false
	_scenario_id = scenario_id
	_match_state = next_state
	GameLogger.start_match(next_state)
	_selected_instance_id = ""
	_last_turn_owner_id = ""
	_animations._floating_card_ids.clear()
	_turn_banner_until_ms = 0
	_clear_pile_selection()
	var scenario_timing_result: Dictionary = _match_state.get("last_timing_result", {})
	var scenario_events := _copy_array(scenario_timing_result.get("processed_events", []))
	if scenario_events.is_empty():
		scenario_events = _history._recent_presentation_events_from_history()
	_animations._record_feedback_from_events(scenario_events)
	_status_message = "Loaded %s." % _scenario_label(scenario_id)
	_refresh._refresh_ui()
	return true


func select_card(instance_id: String) -> bool:
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		_status_message = "Card %s is not available to inspect." % instance_id
		_refresh._refresh_ui()
		return false
	_reset_invalid_feedback()
	_clear_pile_selection()
	_selected_instance_id = instance_id
	_status_message = _card_display._selection_prompt(card)
	_refresh._refresh_ui()
	return true


func clear_selection() -> void:
	_hand._cancel_detached_card_silent()
	_reset_invalid_feedback()
	_selected_instance_id = ""
	_clear_pile_selection()
	_status_message = "Selection cleared."
	_refresh._refresh_ui()


func play_selected_to_lane(lane_id: String, slot_index := -1) -> Dictionary:
	var card = _selection._selected_card()
	if card.is_empty():
		return _invalid_ui_result("Select a creature first.")
	if not _selection._can_resolve_selected_action(card):
		return _invalid_ui_result(_status_message)
	if _selection._selected_action_mode(card) == SELECTION_MODE_ACTION:
		_targeting._play_action_to_lane(lane_id)
		return {"is_valid": true}
	# Check for exalt prompt before committing the play
	if _overlays._check_exalt_creature(card, lane_id, slot_index, _overlays._is_pending_prophecy_card(card)):
		return {"is_valid": true}
	var saved_instance_id := _selected_instance_id
	var options := {}
	if slot_index >= 0:
		options["slot_index"] = slot_index
	var result := {}
	if _overlays._is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id, options.merged({"lane_id": lane_id}, true))
	else:
		result = LaneRules.summon_from_hand(_match_state, _active_player_id(), _selected_instance_id, lane_id, options)
	var finalized := _finalize_engine_result(result, "Played %s into %s." % [_card_display._card_name(card), _lane_name(lane_id)])
	if bool(finalized.get("is_valid", false)):
		_targeting._check_summon_target_mode(saved_instance_id)
	return finalized


func _try_play_hovered_hand_card_to_lane(lane_index: int) -> void:
	var instance_id := _hovered_hand_instance_id
	if instance_id.is_empty() or not _hand._is_local_hand_card(instance_id):
		return
	# Don't interfere with other active interaction modes
	if not _targeting._pending_summon_target.is_empty() or not _targeting._targeting_arrow_state.is_empty() or not _hand._detached_card_state.is_empty():
		return
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		return
	var mode = _selection._selected_action_mode(card)
	# Only creatures and non-targeted actions can be played directly to a lane
	if mode != SELECTION_MODE_SUMMON and not (mode == SELECTION_MODE_ACTION and not _targeting._action_needs_explicit_target(card)):
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
	var validation = _selection._validate_selected_lane_play(lane_id, player_id, slot_index)
	if bool(validation.get("is_valid", false)):
		play_selected_to_lane(lane_id, slot_index)
	else:
		_selected_instance_id = ""


func play_or_activate_selected() -> Dictionary:
	var card = _selection._selected_card()
	if card.is_empty():
		return _invalid_ui_result("Select a card first.")
	if not _selection._can_resolve_selected_action(card):
		return _invalid_ui_result(_status_message)
	var saved_instance_id := _selected_instance_id
	var saved_card: Dictionary = card.duplicate(true)
	var is_action_play := false
	var location := MatchMutations.find_card_location(_match_state, _selected_instance_id)
	var result := {}
	if _overlays._is_pending_prophecy_card(card):
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
				if _targeting._action_needs_explicit_target(card):
					return _invalid_ui_result("Select a target for this action.")
				if _overlays._check_exalt_action(card, {}, _overlays._is_pending_prophecy_card(card)):
					return {"is_valid": true}
				result = MatchTiming.play_action_from_hand(_match_state, _active_player_id(), _selected_instance_id)
				is_action_play = true
			_:
				return _invalid_ui_result("Selected card cannot be played from the UI yet.")
	elif bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_SUPPORT:
		# Check for choose_lane_and_owner activate mode — show choice overlay
		if _selection._support_has_choose_lane_and_owner(card):
			_selection._show_lane_and_owner_choice(_selected_instance_id)
			return {"is_valid": true}
		result = PersistentCardRules.activate_support(_match_state, _active_player_id(), _selected_instance_id)
	else:
		return _invalid_ui_result("Selected card has no direct action. Choose a lane or target instead.")
	var finalized := _finalize_engine_result(result, "Resolved %s." % _card_display._card_name(card))
	if is_action_play and bool(finalized.get("is_valid", false)):
		_betray._check_betray_mode(saved_instance_id, saved_card)
	return finalized


func use_ring() -> bool:
	if MatchTiming.has_pending_prophecy(_match_state):
		_status_message = "Resolve the open Prophecy window before taking further turn actions."
		_refresh._refresh_ui()
		return false
	var player_id := _active_player_id()
	if not MatchTurnLoop.can_activate_ring_of_magicka(_match_state, player_id):
		_status_message = "%s cannot use the Ring of Magicka right now." % _player_name(player_id)
		_refresh._refresh_ui()
		return false
	MatchTurnLoop.activate_ring_of_magicka(_match_state, player_id)
	_selected_instance_id = ""
	_status_message = "%s used the Ring of Magicka." % _player_name(player_id)
	_refresh._refresh_ui()
	if _arena_mode:
		match_state_changed.emit(_match_state.duplicate(true))
	return true


func end_turn_action() -> bool:
	if not _overlays._pending_exalt.is_empty():
		return false
	if MatchTiming.has_pending_prophecy(_match_state):
		_status_message = "Resolve the open Prophecy window before ending the turn."
		_refresh._refresh_ui()
		return false
	var player_id := _active_player_id()
	# Queue any targeted end_of_turn triggers before ending the turn
	MatchTiming.queue_turn_trigger_targets(_match_state, player_id)
	if MatchTiming.has_pending_turn_trigger_target(_match_state, _local_player_id()):
		_pending_end_turn = true
		_pending_end_turn_player_id = player_id
		_selection._check_pending_turn_trigger_target()
		return true
	_complete_end_turn(player_id)
	return true


func _complete_end_turn(player_id: String) -> void:
	_pending_end_turn = false
	MatchTurnLoop.end_turn(_match_state, player_id)
	var timing_result: Dictionary = _match_state.get("last_timing_result", {})
	_animations._record_feedback_from_events(_copy_array(timing_result.get("processed_events", [])))
	_selected_instance_id = ""
	# Kill puzzle: check after end_turn so end-of-turn effects (e.g. expertise)
	# resolve before the puzzle win/loss assessment
	if _puzzle_mode and _puzzle_type == "kill" and player_id == _local_player_id():
		if str(_match_state.get("winner_player_id", "")).is_empty():
			_match_state["winner_player_id"] = _enemy_player_id()
			_status_message = "Puzzle Failed"
			_refresh._refresh_ui()
			return
	_status_message = "Ended %s's turn." % _player_name(player_id)
	# Survive puzzle: if the enemy's turn just ended and it's now the player's turn,
	# and the player is still alive, they win
	if _puzzle_mode and _puzzle_type == "survive" and player_id == _enemy_player_id():
		if str(_match_state.get("winner_player_id", "")).is_empty():
			_match_state["winner_player_id"] = _local_player_id()
			_status_message = "Puzzle Complete!"
			_refresh._refresh_ui()
			return
	_refresh._refresh_ui()
	if _arena_mode:
		match_state_changed.emit(_match_state.duplicate(true))


func _toggle_pause_menu() -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.visible = not _pause_overlay.visible


func _forfeit_match() -> void:
	_pause_overlay.visible = false
	forfeit_requested.emit()


func _dismiss_deck_selection_overlay() -> void:
	if _overlays._deck_selection_overlay_state.is_empty():
		return
	var overlay: Control = _overlays._deck_selection_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_overlays._deck_selection_overlay_state = {}


# --- Consume selection overlay ---


func _has_local_pending_consume_selection() -> bool:
	return MatchTiming.has_pending_consume_selection(_match_state, _local_player_id())


func _on_consume_selection_chosen(instance_id: String) -> void:
	if _overlays._consume_selection_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_consume_selection(_match_state, local_id, instance_id)
	_overlays._dismiss_consume_selection_overlay()
	if bool(result.get("is_valid", false)):
		_animations._record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = "Creature consumed."
		# Check if consume chained into target mode selection
		_targeting._check_pending_summon_effect_target()
		_selection._check_pending_forced_play()
	else:
		_status_message = str(result.get("errors", ["Failed to resolve consume selection."])[0])
	_refresh._refresh_ui()


func _on_consume_selection_declined() -> void:
	if _overlays._consume_selection_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	MatchTiming.decline_consume_selection(_match_state, local_id)
	_overlays._dismiss_consume_selection_overlay()
	_status_message = "Consume declined."
	_refresh._refresh_ui()


func _has_local_pending_player_choice() -> bool:
	return MatchTiming.has_pending_player_choice(_match_state, _local_player_id())


func _on_player_choice_selected(index: int) -> void:
	if _overlays._player_choice_overlay_state.is_empty():
		return
	var local_id := _local_player_id()
	_overlays._dismiss_player_choice_overlay()
	var result := MatchTiming.resolve_pending_player_choice(_match_state, local_id, index)
	if bool(result.get("is_valid", false)):
		_animations._record_feedback_from_events(_copy_array(result.get("events", [])))
		_targeting._check_pending_summon_effect_target()
		_refresh._refresh_ui()


func _has_local_pending_hand_selection() -> bool:
	return MatchTiming.has_pending_hand_selection(_match_state, _local_player_id())


func _refresh_hand_selection_state() -> void:
	var has_selection := _has_local_pending_hand_selection()
	var state_active: bool = not _overlays._hand_selection_state.is_empty()
	if has_selection and not state_active:
		_overlays._enter_hand_selection_mode()
	elif not has_selection and state_active:
		_overlays._exit_hand_selection_mode()


func _enter_top_deck_choice_mode() -> void:
	var local_id := _local_player_id()
	var choice := MatchTiming.get_pending_top_deck_choice(_match_state, local_id)
	if choice.is_empty():
		return
	var multi_cards: Array = choice.get("cards", [])
	if typeof(multi_cards) == TYPE_ARRAY and multi_cards.size() > 1:
		# Multi-card mode (look_draw_discard / look_give_draw)
		_overlays._top_deck_choice_state = {
			"multi_card": true,
			"cards": multi_cards,
			"mode": str(choice.get("mode", "")),
			"source_instance_id": str(choice.get("source_instance_id", "")),
		}
		_status_message = str(choice.get("prompt", "Choose a card."))
		_show_multi_card_choice_panel(multi_cards, str(choice.get("prompt", "Choose a card.")))
		return
	var revealed_card: Dictionary = choice.get("revealed_card", {})
	_overlays._top_deck_choice_state = {
		"revealed_card": revealed_card,
		"source_instance_id": str(choice.get("source_instance_id", "")),
	}
	_status_message = "Look at the top card of your deck. You may discard it."
	_show_top_deck_choice_panel(revealed_card)


func _exit_top_deck_choice_mode() -> void:
	_overlays._top_deck_choice_state = {}
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
	if _overlays._top_deck_choice_state.is_empty():
		return
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_pending_top_deck_choice(_match_state, local_id, discard)
	_exit_top_deck_choice_mode()
	if bool(result.get("is_valid", false)):
		_animations._record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = "Discarded top card." if discard else "Kept top card."
	else:
		_status_message = str(result.get("errors", ["Failed to resolve top deck choice."])[0])
	_refresh._refresh_ui()


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
	if _overlays._top_deck_choice_state.is_empty():
		return
	var mode := str(_overlays._top_deck_choice_state.get("mode", ""))
	var local_id := _local_player_id()
	var result := MatchTiming.resolve_pending_top_deck_multi_choice(_match_state, local_id, chosen_index)
	_exit_top_deck_choice_mode()
	if bool(result.get("is_valid", false)):
		_animations._record_feedback_from_events(_copy_array(result.get("events", [])))
		var chosen_name := str(result.get("chosen_card", {}).get("name", ""))
		if mode == "give_one_draw_rest":
			_status_message = "Gave %s to opponent, drew the rest." % chosen_name
		elif mode == "draw_one_shuffle_rest":
			_status_message = "Drew %s, shuffled the others back." % chosen_name
		else:
			_status_message = "Kept %s, discarded the rest." % chosen_name
	else:
		_status_message = str(result.get("errors", ["Failed to resolve choice."])[0])
	_refresh._refresh_ui()


func _on_lane_card_mouse_entered(button: Button, instance_id: String) -> void:
	_hover._clear_lane_card_hover_preview()
	_hover._lane_hover_preview_pending = {
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
	if str(_hover._lane_hover_preview_pending.get("instance_id", "")) == instance_id:
		_hover._lane_hover_preview_pending = {}
	if _lane_hover_preview_instance_id == instance_id:
		_hover._clear_lane_card_hover_preview()
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


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
		component.set_wax_wane_phases(_card_surface._get_wax_wane_phases_for_card(card))
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
	_hover._clear_lane_card_hover_preview()
	if _card_hover_preview_layer == null:
		return
	var preview := _add_hover_preview_to_layer(card, instance_id, "lane_hover_preview")
	_lane_hover_preview_instance_id = instance_id
	_lane_hover_preview_button_ref = weakref(button)
	_hover._position_lane_card_hover_preview(button)


func _process_support_card_hover_preview() -> void:
	if _support_hover_preview_button_ref != null:
		var active_button = _support_hover_preview_button_ref.get_ref() as Button
		if active_button == null or not is_instance_valid(active_button):
			_clear_support_card_hover_preview()
		elif _support_hover_preview_instance_id != "":
			_position_support_card_hover_preview(active_button)
	if _hover._support_hover_preview_pending.is_empty():
		return
	if Time.get_ticks_msec() - int(_hover._support_hover_preview_pending.get("entered_at_ms", 0)) < CARD_HOVER_PREVIEW_DELAY_MS:
		return
	var button_ref = _hover._support_hover_preview_pending.get("button_ref") as WeakRef
	var button := button_ref.get_ref() as Button if button_ref != null else null
	var instance_id := str(_hover._support_hover_preview_pending.get("instance_id", ""))
	_hover._support_hover_preview_pending = {}
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
	_hover._support_hover_preview_pending = {}
	_support_hover_preview_instance_id = ""
	_support_hover_preview_button_ref = null
	if _card_hover_preview_layer == null:
		return
	for child in _card_hover_preview_layer.get_children():
		if str(child.name).begins_with("support_hover_preview_"):
			child.queue_free()


func _set_mouse_passthrough_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough_recursive(child)


func _build_text_badge(name_prefix: String, text: String, fill: Color, border: Color, font_color: Color, font_size: int, min_size: Vector2) -> PanelContainer:
	return _card_display._build_value_badge(name_prefix, text, fill, border, font_color, font_size, min_size)


func _draw_feedback_badge_text(feedback: Dictionary) -> String:
	return "RUNE DRAW" if bool(feedback.get("from_rune_break", false)) else "DRAWN"


func _draw_feedback_badge_fill(feedback: Dictionary) -> Color:
	return Color(0.32, 0.16, 0.09, 0.99) if bool(feedback.get("from_rune_break", false)) else Color(0.15, 0.22, 0.31, 0.99)


func _draw_feedback_badge_border(feedback: Dictionary) -> Color:
	return Color(1.0, 0.79, 0.46, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.66, 0.9, 1.0, 1.0)


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
		if not _hand._detached_card_state.is_empty() and _overlays._pending_exalt.is_empty():
			var preview: Control = _hand._detached_card_state.get("preview")
			if preview != null and is_instance_valid(preview):
				preview.position = mouse_pos + Vector2(-preview.size.x * 0.5, -preview.size.y * 0.62)
			_selection._update_hand_insertion_preview_from_mouse(mouse_pos)
			_betray._update_sacrifice_hover_from_mouse(mouse_pos)
			_betray._update_sacrifice_hover_label_position()
		if not _targeting._targeting_arrow_state.is_empty():
			_targeting._update_targeting_arrow(mouse_pos)
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
			if not _overlays._pending_exalt.is_empty():
				_overlays._resolve_exalt(false)
				get_viewport().set_input_as_handled()
				return
			if not _betray._pending_betray.is_empty():
				_selection._cancel_betray_mode()
				get_viewport().set_input_as_handled()
				return
			if not _has_match_winner():
				_toggle_pause_menu()
				get_viewport().set_input_as_handled()
				return
		if not _overlays._pending_exalt.is_empty():
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
		if key_event.pressed and not key_event.echo and _hovered_hand_instance_id != "" and _overlays._hand_selection_state.is_empty():
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
			if not _overlays._pending_exalt.is_empty():
				_overlays._resolve_exalt(false)
				get_viewport().set_input_as_handled()
			elif not _overlays._hand_selection_state.is_empty():
				_overlays._cancel_hand_selection()
				get_viewport().set_input_as_handled()
			elif not _betray._pending_betray.is_empty():
				_selection._cancel_betray_mode()
				get_viewport().set_input_as_handled()
			elif not _targeting._pending_secondary_target_state.is_empty():
				# Secondary targets (e.g. Archer's Gambit damage) are mandatory
				get_viewport().set_input_as_handled()
			elif not _targeting._pending_summon_target.is_empty():
				if not _targeting._is_pending_summon_mandatory():
					_targeting._cancel_summon_target_mode()
				get_viewport().set_input_as_handled()
			elif not _targeting._targeting_arrow_state.is_empty():
				_selection._cancel_targeting_mode()
				get_viewport().set_input_as_handled()
			elif not _hand._detached_card_state.is_empty():
				_hand._cancel_detached_card()
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
	if _selection._selected_action_mode(card) != SELECTION_MODE_ATTACK:
		return
	var enemy_player_id := PLAYER_ORDER[0]
	_selected_instance_id = instance_id
	if _selection._is_player_target_valid_for_selected(enemy_player_id):
		_reset_invalid_feedback()
		_targeting.attack_selected_player(enemy_player_id)
	else:
		_report_invalid_interaction("Cannot attack face right now.", {"player_ids": [enemy_player_id]})
	get_viewport().set_input_as_handled()


func _on_card_pressed(instance_id: String) -> void:
	if not _overlays._pending_exalt.is_empty():
		return
	if not _overlays._hand_selection_state.is_empty():
		var candidates: Array = _overlays._hand_selection_state.get("candidate_ids", [])
		if candidates.has(instance_id):
			_overlays._resolve_hand_selection(instance_id)
		else:
			_report_invalid_interaction("Not a valid selection.", {"instance_ids": [instance_id]})
		return
	if not _betray._pending_betray.is_empty():
		if _betray._pending_betray.has("sacrifice_instance_id"):
			# Betray replay targeting phase — resolve replay target card
			_betray._resolve_betray_replay_target_card(instance_id)
			return
		else:
			# Betray sacrifice selection phase — resolve sacrifice
			_betray._resolve_betray_sacrifice(instance_id)
			return
	if not _targeting._pending_secondary_target_state.is_empty():
		_targeting._resolve_secondary_target_card(instance_id)
		return
	if not _targeting._pending_summon_target.is_empty():
		_targeting._resolve_summon_target_card(instance_id)
		return
	if not _targeting._targeting_arrow_state.is_empty():
		if _selection._try_resolve_selected_card_target(instance_id):
			return
		# Allow switching to another card that can target
		var switch_card := _card_from_instance_id(instance_id)
		var switch_mode = _selection._selected_action_mode(switch_card)
		var switch_wants_targeting: bool = switch_mode == SELECTION_MODE_ITEM or switch_mode == SELECTION_MODE_ATTACK or (switch_mode == SELECTION_MODE_SUPPORT and _targeting._selected_support_uses_card_targets(switch_card))
		if not switch_wants_targeting and switch_mode == SELECTION_MODE_ACTION and _targeting._action_needs_explicit_target(switch_card):
			switch_wants_targeting = true
		if switch_wants_targeting:
			_selection._enter_targeting_mode(instance_id)
			return
		_report_invalid_interaction("Not a valid target.", {"instance_ids": [instance_id]})
		return
	if not _hand._detached_card_state.is_empty():
		if _betray._sacrifice_hover_target_id != "" and instance_id == _betray._sacrifice_hover_target_id:
			_betray._resolve_sacrifice_hover()
			return
		var target_card := _card_from_instance_id(instance_id)
		if _hand._try_resolve_selected_support_row_card(target_card):
			return
		if _selection._try_resolve_selected_card_target(instance_id):
			return
		_hand._try_resolve_detached_card_via_lane(instance_id)
		return
	if _hand._is_local_hand_card(instance_id):
		var card := _card_from_instance_id(instance_id)
		var mode = _selection._selected_action_mode(card)
		if mode == SELECTION_MODE_ITEM:
			_selection._enter_targeting_mode(instance_id)
			return
		elif mode == SELECTION_MODE_ACTION:
			if _targeting._action_needs_explicit_target(card):
				_selection._enter_targeting_mode(instance_id)
			else:
				_hand._detach_hand_card(instance_id)
			return
		elif mode != SELECTION_MODE_NONE:
			_hand._detach_hand_card(instance_id)
			return
	var target_card := _card_from_instance_id(instance_id)
	if _hand._try_resolve_selected_support_row_card(target_card):
		return
	if _selection._try_resolve_selected_card_target(instance_id):
		return
	# Board cards that can target (attackers, supports with card targets) enter targeting mode
	var board_card := _card_from_instance_id(instance_id)
	var board_mode = _selection._selected_action_mode(board_card)
	if board_mode == SELECTION_MODE_ATTACK or (board_mode == SELECTION_MODE_SUPPORT and _targeting._selected_support_uses_card_targets(board_card)):
		_selection._enter_targeting_mode(instance_id)
		return
	# Supports without card targets activate immediately on click
	if board_mode == SELECTION_MODE_SUPPORT and not _targeting._selected_support_uses_card_targets(board_card):
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
	if not _betray._pending_betray.is_empty() and bool(_betray._pending_betray.get("is_lane_targeted", false)) and not str(_betray._pending_betray.get("sacrifice_instance_id", "")).is_empty():
		_betray._resolve_betray_replay_lane(lane_id)
		accept_event()
		return
	var card = _selection._selected_card()
	if card.is_empty():
		return
	if not _targeting._targeting_arrow_state.is_empty() and _selection._selected_action_mode(card) == SELECTION_MODE_ACTION:
		if _targeting._action_needs_explicit_target(card):
			_report_invalid_interaction("Choose a valid target for this action.", {})
			accept_event()
			return
		_targeting._play_action_to_lane(lane_id)
		accept_event()
		return
	# Mobilize: item in targeting mode can be played to a lane (summon Recruit + equip)
	if not _targeting._targeting_arrow_state.is_empty() and _selection._selected_action_mode(card) == SELECTION_MODE_ITEM:
		if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_MOBILIZE):
			_targeting._play_mobilize_item_to_lane(lane_id)
			accept_event()
			return
	if not _selection._selected_support_row_target_player_id(card).is_empty():
		_hand._play_selected_to_support_row(_selection._selected_support_row_target_player_id(card))
		accept_event()
		return
	if _selection._selected_card_wants_lane(card, _target_lane_player_id()):
		if _selection._selected_action_mode(card) == SELECTION_MODE_ACTION:
			_targeting._play_action_to_lane(lane_id)
			accept_event()
			return
		var slot_index = _hand._get_insertion_index_or_default(lane_id, _target_lane_player_id())
		if slot_index >= 0:
			var validation = _selection._validate_selected_lane_play(lane_id, _target_lane_player_id(), slot_index)
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
	var card = _selection._selected_card()
	if card.is_empty():
		return
	if not _targeting._targeting_arrow_state.is_empty() and _selection._selected_action_mode(card) == SELECTION_MODE_ACTION:
		if _targeting._action_needs_explicit_target(card):
			_report_invalid_interaction("Choose a valid target for this action.", {})
			accept_event()
			return
		_targeting._play_action_to_lane(lane_id)
		accept_event()
		return
	# Mobilize: item in targeting mode can be played to a lane (summon Recruit + equip)
	if not _targeting._targeting_arrow_state.is_empty() and _selection._selected_action_mode(card) == SELECTION_MODE_ITEM:
		if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_MOBILIZE):
			_targeting._play_mobilize_item_to_lane(lane_id)
			accept_event()
			return
	if not _selection._selected_support_row_target_player_id(card).is_empty():
		_hand._play_selected_to_support_row(_selection._selected_support_row_target_player_id(card))
		accept_event()
		return
	var target_player := _target_lane_player_id()
	if _selection._selected_card_wants_lane(card, target_player):
		if _selection._selected_action_mode(card) == SELECTION_MODE_ACTION:
			_targeting._play_action_to_lane(lane_id)
			accept_event()
			return
		var slot_index = _hand._get_insertion_index_or_default(lane_id, target_player)
		if slot_index >= 0:
			var validation = _selection._validate_selected_lane_play(lane_id, target_player, slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
				accept_event()
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})
				accept_event()
		elif _selection._selected_action_mode(card) == SELECTION_MODE_SUMMON and _betray._lane_is_full_with_friendly(lane_id, target_player):
			if not _hand._detached_card_state.is_empty() and _betray._sacrifice_hover_target_id != "":
				_betray._resolve_sacrifice_hover()
			accept_event()


func _on_lane_pressed(lane_id: String) -> void:
	if not _overlays._pending_exalt.is_empty():
		return
	var card = _selection._selected_card()
	if not _targeting._targeting_arrow_state.is_empty() and _selection._selected_action_mode(card) == SELECTION_MODE_ACTION:
		_targeting._play_action_to_lane(lane_id)
		return
	var target_player := _target_lane_player_id()
	if not _selection._selected_support_row_target_player_id(card).is_empty():
		_hand._play_selected_to_support_row(_selection._selected_support_row_target_player_id(card))
		return
	if _selection._selected_card_wants_lane(card, target_player):
		if _selection._selected_action_mode(card) == SELECTION_MODE_ACTION:
			_targeting._play_action_to_lane(lane_id)
			return
		var slot_index = _hand._get_insertion_index_or_default(lane_id, target_player)
		if slot_index >= 0:
			var validation = _selection._validate_selected_lane_play(lane_id, target_player, slot_index)
			if bool(validation.get("is_valid", false)):
				play_selected_to_lane(lane_id, slot_index)
			else:
				_report_invalid_interaction(validation.get("message", "Cannot play into %s." % _lane_name(lane_id)), {
					"lane_ids": [lane_id],
				})
		return
	_status_message = "Lane details: %s." % _lane_name(lane_id)
	_refresh._refresh_ui()


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
		_refresh._refresh_ui()
	elif btn_idx == MOUSE_BUTTON_RIGHT and player_id == _local_player_id() and not _adventure_boons.is_empty():
		var overlay := ActiveBoonsOverlay.new()
		add_child(overlay)
		overlay.set_boons(_adventure_boons)


func _on_player_pressed(player_id: String) -> void:
	if not _overlays._pending_exalt.is_empty():
		return
	if not _betray._pending_betray.is_empty() and _betray._pending_betray.has("sacrifice_instance_id"):
		_betray._resolve_betray_replay_target_player(player_id)
		return
	if not _targeting._pending_secondary_target_state.is_empty():
		_targeting._resolve_secondary_target_player(player_id)
		return
	if not _targeting._pending_summon_target.is_empty():
		_targeting._resolve_summon_target_player(player_id)
		return
	if _selection._try_resolve_selected_player_target(player_id):
		return
	_clear_pile_selection()
	_status_message = "%s selected." % _player_name(player_id)
	_refresh._refresh_ui()


func _on_pile_pressed(player_id: String, zone: String) -> void:
	_reset_invalid_feedback()
	_selected_instance_id = ""
	_selected_pile_player_id = player_id
	_selected_pile_zone = zone
	if zone == MatchMutations.ZONE_DISCARD:
		_overlays._show_discard_viewer(player_id)
	else:
		_status_message = "Inspecting %s's %s." % [_player_name(player_id), _identifier_to_name(zone)]
		_refresh._refresh_ui()


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
	var mode = _selection._selected_action_mode(card)
	match mode:
		SELECTION_MODE_SUMMON:
			_animations._detach_prophecy_card(instance_id)
		SELECTION_MODE_ITEM:
			_selection._enter_prophecy_targeting_mode(instance_id)
		SELECTION_MODE_ACTION:
			if _targeting._action_needs_explicit_target(card):
				_selection._enter_prophecy_targeting_mode(instance_id)
			else:
				_animations._detach_prophecy_card(instance_id)
				_status_message = "Drop %s onto a lane to play it." % _card_display._card_name(card)
				_refresh._refresh_ui()
		_:
			play_or_activate_selected()


func _on_prophecy_keep_pressed(instance_id: String) -> void:
	_overlays._dismiss_prophecy_overlay()
	_overlays.decline_prophecy(instance_id)


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


func _finalize_engine_result(result: Dictionary, success_message: String, clear_selection_on_success := true) -> Dictionary:
	if bool(result.get("is_valid", false)):
		_hand._cancel_detached_card_silent()
		_targeting._cancel_targeting_mode_silent()
		_overlays._dismiss_prophecy_overlay()
		_reset_invalid_feedback()
		if clear_selection_on_success:
			_selected_instance_id = ""
		_animations._record_feedback_from_events(_copy_array(result.get("events", [])))
		_status_message = success_message
		if _arena_mode:
			match_state_changed.emit(_match_state.duplicate(true))
	else:
		_status_message = str(result.get("errors", ["Action failed."])[0])
	_refresh._refresh_ui()
	if bool(result.get("is_valid", false)):
		_targeting._check_pending_secondary_target()
		_targeting._check_pending_summon_effect_target()
		_selection._check_pending_forced_play()
	return result


func _invalid_ui_result(message: String) -> Dictionary:
	_status_message = message
	_refresh._refresh_ui()
	return {"is_valid": false, "errors": [message]}


func _report_invalid_interaction(message: String, feedback := {}) -> Dictionary:
	_invalid_feedback = {
		"lane_slot_keys": _copy_array(feedback.get("lane_slot_keys", [])),
		"lane_ids": _copy_array(feedback.get("lane_ids", [])),
		"instance_ids": _copy_array(feedback.get("instance_ids", [])),
		"player_ids": _copy_array(feedback.get("player_ids", [])),
	}
	_status_message = message
	_refresh._refresh_ui()
	return {"is_valid": false, "errors": [message]}


func _reset_invalid_feedback() -> void:
	_invalid_feedback = {
		"lane_slot_keys": [],
		"lane_ids": [],
		"instance_ids": [],
		"player_ids": [],
	}


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
	return _is_local_prophecy_interrupt_open() or not _targeting._pending_summon_target.is_empty() or not _targeting._pending_secondary_target_state.is_empty() or _overlays._has_local_pending_discard_choice() or _has_local_pending_consume_selection() or _overlays._has_local_pending_deck_selection() or not _overlays._hand_selection_state.is_empty() or MatchTiming.has_pending_summon_effect_target(_match_state, _local_player_id()) or MatchTiming.has_pending_forced_play(_match_state, _local_player_id())


func _target_lane_player_id() -> String:
	if _overlays._is_pending_prophecy_card(_selection._selected_card()):
		return str(_selection._selected_card().get("controller_player_id", ""))
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


func _queue_free_weak(node_ref: WeakRef) -> void:
	var node = node_ref.get_ref()
	if node != null and is_instance_valid(node):
		node.queue_free()


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
	var component = _hover._get_active_hover_preview_component()
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
	_ui_builder._apply_panel_style(panel, Color(0.1, 0.08, 0.12, 0.95), Color(0.55, 0.45, 0.35, 0.8), 2, 8)
	var box = _ui_builder._build_panel_box(panel, 6, 14)
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
	var snapshot := ErrorReportWriterClass.build_match_snapshot(_match_state, _history.entries)
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
	elif _lane_hover_preview_instance_id != "" or not _hover._lane_hover_preview_pending.is_empty():
		instance_id = _lane_hover_preview_instance_id if _lane_hover_preview_instance_id != "" else str(_hover._lane_hover_preview_pending.get("instance_id", ""))
	elif _support_hover_preview_instance_id != "" or not _hover._support_hover_preview_pending.is_empty():
		instance_id = _support_hover_preview_instance_id if _support_hover_preview_instance_id != "" else str(_hover._support_hover_preview_pending.get("instance_id", ""))
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


func _refresh_top_deck_choice_state() -> void:
	_overlays._refresh_top_deck_choice_state()


# --- Delegation stubs for cross-module calls ---

func _active_draw_feedback_for_instance(instance_id: String):
	return _feedback._active_draw_feedback_for_instance(instance_id)

func _animate_deck_card_reveal(revealed_card: Dictionary):
	_feedback._animate_deck_card_reveal(revealed_card)

func _animate_enemy_attack_arrow(action: Dictionary, _result: Dictionary):
	_feedback._animate_enemy_attack_arrow(action, _result)

func _animate_enemy_creature_play(action: Dictionary, _result: Dictionary):
	_feedback._animate_enemy_creature_play(action, _result)

func _animate_enemy_creature_summon_reveal(action: Dictionary, _result: Dictionary):
	_feedback._animate_enemy_creature_summon_reveal(action, _result)

func _animate_enemy_item_reveal(action: Dictionary, _result: Dictionary):
	_feedback._animate_enemy_item_reveal(action, _result)

func _animate_enemy_prophecy_resolution(action: Dictionary, _result: Dictionary):
	_feedback._animate_enemy_prophecy_resolution(action, _result)

func _animate_enemy_spell_reveal(action: Dictionary, _result: Dictionary):
	_feedback._animate_enemy_spell_reveal(action, _result)

func _animate_enemy_support_activation_arrow(action: Dictionary, _result: Dictionary):
	_feedback._animate_enemy_support_activation_arrow(action, _result)

func _animate_treasure_hunt_reveal(revealed_card: Dictionary, matches: bool):
	_feedback._animate_treasure_hunt_reveal(revealed_card, matches)

func _apply_betray_target_glow(button: Button, surface: String):
	_feedback._apply_betray_target_glow(button, surface)

func _apply_button_style(button: Button, fill: Color, border: Color, font_color: Color, border_width := 1, corner_radius := 9):
	_ui_builder._apply_button_style(button, fill, border, font_color, border_width, corner_radius)

func _apply_card_feedback_decoration(button: Button, card: Dictionary, surface: String):
	_feedback._apply_card_feedback_decoration(button, card, surface)

func _apply_lane_card_float_effect(button: Button, card: Dictionary):
	_feedback._apply_lane_card_float_effect(button, card)

func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color, border_width := 1, corner_radius := 10):
	_ui_builder._apply_panel_style(panel, fill, border, border_width, corner_radius)

func _apply_surface_button_style(button: Button, surface: String, hidden := false, selected := false, muted := false, interaction_state := "default", card: Dictionary = {}, locked := false):
	_ui_builder._apply_surface_button_style(button, surface, hidden, selected, muted, interaction_state, card, locked)

func _apply_valid_target_glow(button: Button, surface: String):
	_feedback._apply_valid_target_glow(button, surface)

func _build_panel_box(panel: PanelContainer, separation: int = 12, padding: int = 16):
	return _ui_builder._build_panel_box(panel, separation, padding)

func _can_resolve_selected_action(card: Dictionary):
	return _selection._can_resolve_selected_action(card)

func _cancel_detached_card_silent():
	_hand._cancel_detached_card_silent()

func _cancel_targeting_mode():
	_selection._cancel_targeting_mode()

func _cancel_targeting_mode_silent():
	_targeting._cancel_targeting_mode_silent()

func _card_interaction_state(card: Dictionary, surface: String):
	return _selection._card_interaction_state(card, surface)

func _card_name(card: Dictionary):
	return _card_display._card_name(card)

func _check_betray_mode(action_instance_id: String, action_card: Dictionary):
	_betray._check_betray_mode(action_instance_id, action_card)

func _check_deferred_betray():
	_betray._check_deferred_betray()

func _check_exalt_action(card: Dictionary, options: Dictionary, is_prophecy: bool):
	_overlays._check_exalt_action(card, options, is_prophecy)

func _check_pending_turn_trigger_target():
	_selection._check_pending_turn_trigger_target()

func _check_summon_target_mode(source_instance_id: String):
	_targeting._check_summon_target_mode(source_instance_id)

func _create_targeting_arrow():
	return _selection._create_targeting_arrow()

func _creature_readiness_state(card: Dictionary):
	return _card_surface._creature_readiness_state(card)

func _damage_target_key(event: Dictionary):
	return _feedback._damage_target_key(event)

func _enter_targeting_mode(instance_id: String):
	_selection._enter_targeting_mode(instance_id)

func _feedback_now_ms():
	return _feedback._feedback_now_ms()

func _get_wax_wane_phases_for_card(card: Dictionary):
	return _card_surface._get_wax_wane_phases_for_card(card)

func _is_pending_prophecy_card(card: Dictionary):
	return _overlays._is_pending_prophecy_card(card)

func _lane_row_interaction_state(lane_id: String, player_id: String):
	return _selection._lane_row_interaction_state(lane_id, player_id)

func _next_feedback_id():
	return _feedback._next_feedback_id()

func _queue_creature_toast(instance_id: String, text: String, color: Color):
	_feedback._queue_creature_toast(instance_id, text, color)

func _queue_status_toast(text: String, color: Color):
	_feedback._queue_status_toast(text, color)

func _record_feedback_from_events(events: Array):
	_animations._record_feedback_from_events(events)

func _refresh_ui():
	_refresh._refresh_ui()

func _schedule_local_match_ai_step(delay_ms: int):
	_ai_system._schedule_local_match_ai_step(delay_ms)

func _selected_action_mode(card: Dictionary):
	return _selection._selected_action_mode(card)

func _selected_card():
	return _selection._selected_card()

func _selected_card_wants_lane(card: Dictionary, player_id: String):
	return _selection._selected_card_wants_lane(card, player_id)

func _selected_support_row_target_player_id(card: Dictionary):
	return _selection._selected_support_row_target_player_id(card)

func _should_reveal_drawn_card(player_id: String, card: Dictionary):
	return _feedback._should_reveal_drawn_card(player_id, card)

func _start_hand_card_bob(button: Button, base_pos: Vector2, bob_key: String):
	_card_display._start_hand_card_bob(button, base_pos, bob_key)

func _surface_button_minimum_size(surface: String):
	return _card_surface._surface_button_minimum_size(surface)

func _valid_player_target_ids():
	return _selection._valid_player_target_ids()

func _validate_selected_lane_play(lane_id: String, player_id: String, slot_index: int):
	return _selection._validate_selected_lane_play(lane_id, player_id, slot_index)

func _validate_selected_support_play(player_id: String):
	return _selection._validate_selected_support_play(player_id)

func _on_local_hand_card_mouse_entered(button: Button):
	_hover._on_local_hand_card_mouse_entered(button)

func _on_local_hand_card_mouse_exited(button: Button):
	_hover._on_local_hand_card_mouse_exited(button)

func _on_support_card_mouse_entered(button: Button, instance_id: String):
	_hover._on_support_card_mouse_entered(button, instance_id)

func _on_support_card_mouse_exited(instance_id: String):
	_hover._on_support_card_mouse_exited(instance_id)

func _start_lane_card_bob(button: Button, content_root: Control, shadow: ColorRect):
	_card_display._start_lane_card_bob(button, content_root, shadow)
