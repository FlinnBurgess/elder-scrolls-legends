class_name MatchScreen
extends Control

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchDebugScenarios = preload("res://src/ui/match_debug_scenarios.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")

const LANE_REGISTRY_PATH := "res://data/legends/registries/lane_registry.json"
const PLAYER_ORDER := ["player_2", "player_1"]
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
var _status_message := ""
var _scenario_id := MatchDebugScenarios.DEFAULT_SCENARIO_ID
var _keyword_registry := {}
var _lane_registry := {}
var _keyword_display_names := {}
var _status_display_names := {}

var _scenario_picker: OptionButton
var _play_selected_button: Button
var _reload_button: Button
var _ring_button: Button
var _end_turn_button: Button
var _clear_button: Button
var _status_label: Label
var _prompt_label: Label
var _prompt_button_row: HBoxContainer
var _player_sections := {}
var _lane_row_containers := {}
var _lane_header_buttons := {}
var _inspector_label: Label
var _keyword_button_row: HBoxContainer
var _help_label: Label
var _history_text: TextEdit
var _replay_text: TextEdit
var _state_text: TextEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_registries()
	_build_ui()
	load_scenario(_scenario_id)


func get_available_scenarios() -> Array:
	return MatchDebugScenarios.list_scenarios()


func get_match_state() -> Dictionary:
	return _match_state


func get_status_message() -> String:
	return _status_message


func get_selected_instance_id() -> String:
	return _selected_instance_id


func get_inspector_text() -> String:
	return _inspector_label.text if _inspector_label != null else ""


func get_help_text(term_id: String) -> String:
	return _build_help_text(term_id)


func get_pending_prophecy_ids() -> Array:
	var ids: Array = []
	for window in MatchTiming.get_pending_prophecies(_match_state):
		ids.append(str(window.get("instance_id", "")))
	return ids


func load_scenario(scenario_id: String) -> bool:
	var next_state := MatchDebugScenarios.build_scenario(scenario_id)
	if next_state.is_empty():
		_status_message = "Failed to load scenario %s." % scenario_id
		_refresh_ui()
		return false
	_scenario_id = scenario_id
	_match_state = next_state
	_selected_instance_id = ""
	_status_message = "Loaded %s." % _scenario_label(scenario_id)
	_refresh_ui()
	return true


func select_card(instance_id: String) -> bool:
	var card := _card_from_instance_id(instance_id)
	if card.is_empty():
		_status_message = "Card %s is not available to inspect." % instance_id
		_refresh_ui()
		return false
	_selected_instance_id = instance_id
	_status_message = _selection_prompt(card)
	_refresh_ui()
	return true


func clear_selection() -> void:
	_selected_instance_id = ""
	_status_message = "Selection cleared."
	_refresh_ui()


func play_selected_to_lane(lane_id: String, slot_index := -1) -> Dictionary:
	var card := _selected_card()
	if card.is_empty():
		return _invalid_ui_result("Select a creature first.")
	if not _can_resolve_selected_action(card):
		return _invalid_ui_result(_status_message)
	var options := {}
	if slot_index >= 0:
		options["slot_index"] = slot_index
	var result := {}
	if _is_pending_prophecy_card(card):
		result = MatchTiming.play_pending_prophecy(_match_state, str(card.get("controller_player_id", "")), _selected_instance_id, options.merged({"lane_id": lane_id}, true))
	else:
		result = LaneRules.summon_from_hand(_match_state, _active_player_id(), _selected_instance_id, lane_id, options)
	return _finalize_engine_result(result, "Played %s into %s." % [_card_name(card), _lane_name(lane_id)])


func play_or_activate_selected() -> Dictionary:
	var card := _selected_card()
	if card.is_empty():
		return _invalid_ui_result("Select a card first.")
	if not _can_resolve_selected_action(card):
		return _invalid_ui_result(_status_message)
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
			_:
				return _invalid_ui_result("Selected card cannot be played from the UI yet.")
	elif bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_SUPPORT:
		result = PersistentCardRules.activate_support(_match_state, _active_player_id(), _selected_instance_id)
	else:
		return _invalid_ui_result("Selected card has no direct action. Choose a lane or target instead.")
	return _finalize_engine_result(result, "Resolved %s." % _card_name(card))


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
	var result := {}
	if bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_HAND and str(selected_card.get("card_type", "")) == "item":
		result = PersistentCardRules.play_item_from_hand(_match_state, _active_player_id(), _selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_SUPPORT:
		result = PersistentCardRules.activate_support(_match_state, _active_player_id(), _selected_instance_id, {"target_instance_id": target_instance_id})
	elif bool(selected_location.get("is_valid", false)) and str(selected_location.get("zone", "")) == MatchMutations.ZONE_LANE:
		result = MatchCombat.resolve_attack(_match_state, _active_player_id(), _selected_instance_id, {"type": "creature", "instance_id": target_instance_id})
	else:
		return _invalid_ui_result("Current selection does not use card targets.")
	return _finalize_engine_result(result, "Resolved %s onto %s." % [_card_name(selected_card), _card_name(target_card)])


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
	return true


func end_turn_action() -> bool:
	if MatchTiming.has_pending_prophecy(_match_state):
		_status_message = "Resolve the open Prophecy window before ending the turn."
		_refresh_ui()
		return false
	var player_id := _active_player_id()
	MatchTurnLoop.end_turn(_match_state, player_id)
	_selected_instance_id = ""
	_status_message = "Ended %s's turn." % _player_name(player_id)
	_refresh_ui()
	return true


func _build_ui() -> void:
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

	var top_shell := PanelContainer.new()
	top_shell.name = "ScenarioBar"
	top_shell.custom_minimum_size = Vector2(0, 72)
	content.add_child(top_shell)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	top_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	var top_bar_padding := MarginContainer.new()
	top_bar_padding.add_theme_constant_override("margin_left", 16)
	top_bar_padding.add_theme_constant_override("margin_top", 14)
	top_bar_padding.add_theme_constant_override("margin_right", 16)
	top_bar_padding.add_theme_constant_override("margin_bottom", 14)
	top_bar_padding.size_flags_horizontal = SIZE_EXPAND_FILL
	top_bar_padding.size_flags_vertical = SIZE_EXPAND_FILL
	top_shell.add_child(top_bar_padding)
	top_bar_padding.add_child(top_bar)

	var scenario_label := Label.new()
	scenario_label.text = "Scenario"
	scenario_label.add_theme_font_size_override("font_size", 17)
	top_bar.add_child(scenario_label)

	_scenario_picker = OptionButton.new()
	_scenario_picker.size_flags_horizontal = SIZE_EXPAND_FILL
	_scenario_picker.custom_minimum_size = Vector2(0, 44)
	_scenario_picker.add_theme_font_size_override("font_size", 16)
	_scenario_picker.item_selected.connect(_on_scenario_selected)
	top_bar.add_child(_scenario_picker)
	_populate_scenario_picker()

	_reload_button = Button.new()
	_reload_button.text = "Reload"
	_reload_button.custom_minimum_size = Vector2(132, 44)
	_reload_button.add_theme_font_size_override("font_size", 16)
	_reload_button.pressed.connect(_on_reload_pressed)
	top_bar.add_child(_reload_button)

	var main_row := HBoxContainer.new()
	main_row.name = "MainRow"
	main_row.size_flags_horizontal = SIZE_EXPAND_FILL
	main_row.size_flags_vertical = SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 24)
	content.add_child(main_row)

	var board_column := VBoxContainer.new()
	board_column.name = "BoardColumn"
	board_column.size_flags_horizontal = SIZE_EXPAND_FILL
	board_column.size_flags_vertical = SIZE_EXPAND_FILL
	board_column.size_flags_stretch_ratio = 3.8
	board_column.add_theme_constant_override("separation", 20)
	main_row.add_child(board_column)

	for player_id in PLAYER_ORDER:
		var section := _build_player_section(player_id)
		_player_sections[player_id] = section
		board_column.add_child(section["panel"])
		if player_id == PLAYER_ORDER[0]:
			var lanes_panel := _build_lanes_panel()
			board_column.add_child(lanes_panel)

	var utility_column := VBoxContainer.new()
	utility_column.name = "UtilityColumn"
	utility_column.custom_minimum_size = Vector2(336, 0)
	utility_column.size_flags_horizontal = SIZE_FILL
	utility_column.size_flags_vertical = SIZE_EXPAND_FILL
	utility_column.add_theme_constant_override("separation", 18)
	main_row.add_child(utility_column)

	_play_selected_button = Button.new()
	_play_selected_button.text = "Play / Act"
	_play_selected_button.custom_minimum_size = Vector2(0, 54)
	_play_selected_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_play_selected_button.add_theme_font_size_override("font_size", 17)
	_play_selected_button.pressed.connect(_on_play_selected_pressed)

	_ring_button = Button.new()
	_ring_button.text = "Use Ring"
	_ring_button.custom_minimum_size = Vector2(0, 54)
	_ring_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_ring_button.add_theme_font_size_override("font_size", 17)
	_ring_button.pressed.connect(_on_ring_pressed)

	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = Vector2(0, 54)
	_end_turn_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_end_turn_button.add_theme_font_size_override("font_size", 17)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)

	_clear_button = Button.new()
	_clear_button.text = "Clear Selection"
	_clear_button.custom_minimum_size = Vector2(0, 54)
	_clear_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_clear_button.add_theme_font_size_override("font_size", 17)
	_clear_button.pressed.connect(_on_clear_pressed)

	var prompt_panel := PanelContainer.new()
	prompt_panel.name = "PromptPanel"
	prompt_panel.custom_minimum_size = Vector2(0, 126)
	utility_column.add_child(prompt_panel)
	var prompt_box := _build_panel_box(prompt_panel, 12, 16)
	var prompt_title := Label.new()
	prompt_title.text = "Interrupts / Prophecy"
	prompt_title.add_theme_font_size_override("font_size", 20)
	prompt_box.add_child(prompt_title)
	_prompt_label = Label.new()
	_prompt_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", 16)
	_prompt_label.custom_minimum_size = Vector2(0, 52)
	prompt_box.add_child(_prompt_label)
	_prompt_button_row = HBoxContainer.new()
	_prompt_button_row.add_theme_constant_override("separation", 10)
	_prompt_button_row.size_flags_horizontal = SIZE_EXPAND_FILL
	prompt_box.add_child(_prompt_button_row)

	var actions_panel := PanelContainer.new()
	actions_panel.name = "ActionPanel"
	actions_panel.custom_minimum_size = Vector2(0, 188)
	utility_column.add_child(actions_panel)
	var actions_box := _build_panel_box(actions_panel, 12, 16)
	var actions_title := Label.new()
	actions_title.text = "Turn Actions"
	actions_title.add_theme_font_size_override("font_size", 20)
	actions_box.add_child(actions_title)
	var primary_action_row := HBoxContainer.new()
	primary_action_row.add_theme_constant_override("separation", 10)
	actions_box.add_child(primary_action_row)
	primary_action_row.add_child(_play_selected_button)
	primary_action_row.add_child(_end_turn_button)
	var utility_action_row := HBoxContainer.new()
	utility_action_row.add_theme_constant_override("separation", 10)
	actions_box.add_child(utility_action_row)
	utility_action_row.add_child(_ring_button)
	utility_action_row.add_child(_clear_button)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.custom_minimum_size = Vector2(0, 76)
	actions_box.add_child(_status_label)

	var inspector_panel := PanelContainer.new()
	inspector_panel.name = "InspectorRailPanel"
	inspector_panel.custom_minimum_size = Vector2(0, 236)
	utility_column.add_child(inspector_panel)
	var inspector_box := _build_panel_box(inspector_panel, 12, 16)
	var inspector_title := Label.new()
	inspector_title.text = "Selection / Help"
	inspector_title.add_theme_font_size_override("font_size", 20)
	inspector_box.add_child(inspector_title)
	_inspector_label = Label.new()
	_inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_label.add_theme_font_size_override("font_size", 16)
	_inspector_label.custom_minimum_size = Vector2(0, 100)
	inspector_box.add_child(_inspector_label)
	_keyword_button_row = HBoxContainer.new()
	_keyword_button_row.add_theme_constant_override("separation", 10)
	inspector_box.add_child(_keyword_button_row)
	_help_label = Label.new()
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.add_theme_font_size_override("font_size", 16)
	_help_label.custom_minimum_size = Vector2(0, 88)
	inspector_box.add_child(_help_label)

	var debug_panel := PanelContainer.new()
	debug_panel.name = "DebugRailPanel"
	debug_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	debug_panel.size_flags_vertical = SIZE_EXPAND_FILL
	utility_column.add_child(debug_panel)
	var debug_box := _build_panel_box(debug_panel, 12, 16)
	var debug_title := Label.new()
	debug_title.text = "History / Replay / State"
	debug_title.add_theme_font_size_override("font_size", 19)
	debug_box.add_child(debug_title)

	var tabs := TabContainer.new()
	tabs.name = "DebugTabs"
	tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(0, 210)
	debug_box.add_child(tabs)

	_history_text = _build_read_only_text("History")
	tabs.add_child(_history_text)
	_replay_text = _build_read_only_text("Replay")
	tabs.add_child(_replay_text)
	_state_text = _build_read_only_text("State")
	tabs.add_child(_state_text)


func _build_player_section(player_id: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "OpponentBand" if player_id == PLAYER_ORDER[0] else "PlayerBand"
	panel.custom_minimum_size = Vector2(0, 208)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var box := _build_panel_box(panel, 14, 16)

	var title := Label.new()
	title.text = "Opponent" if player_id == PLAYER_ORDER[0] else "Local Player"
	title.add_theme_font_size_override("font_size", 21)
	box.add_child(title)

	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 78)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_on_player_pressed.bind(player_id))
	box.add_child(button)

	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_child(rows)

	var support_box := VBoxContainer.new()
	support_box.custom_minimum_size = Vector2(224, 0)
	support_box.add_theme_constant_override("separation", 10)
	rows.add_child(support_box)

	var support_label := Label.new()
	support_label.text = "Supports"
	support_label.add_theme_font_size_override("font_size", 17)
	support_box.add_child(support_label)

	var support_row := HBoxContainer.new()
	support_row.add_theme_constant_override("separation", 10)
	support_row.size_flags_horizontal = SIZE_EXPAND_FILL
	support_box.add_child(support_row)

	var hand_box := VBoxContainer.new()
	hand_box.size_flags_horizontal = SIZE_EXPAND_FILL
	hand_box.add_theme_constant_override("separation", 10)
	rows.add_child(hand_box)

	var hand_label := Label.new()
	hand_label.text = "Hand"
	hand_label.add_theme_font_size_override("font_size", 17)
	hand_box.add_child(hand_label)

	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	hand_row.size_flags_horizontal = SIZE_EXPAND_FILL
	hand_box.add_child(hand_row)

	return {
		"panel": panel,
		"summary_button": button,
		"support_row": support_row,
		"hand_row": hand_row,
	}


func _build_lanes_panel() -> Control:
	var lanes_panel := PanelContainer.new()
	lanes_panel.name = "BattlefieldPanel"
	lanes_panel.custom_minimum_size = Vector2(0, 432)
	lanes_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	lanes_panel.size_flags_vertical = SIZE_EXPAND_FILL
	lanes_panel.size_flags_stretch_ratio = 2.3
	var lanes_box := _build_panel_box(lanes_panel, 18, 18)

	var battlefield_title := Label.new()
	battlefield_title.text = "Battlefield"
	battlefield_title.add_theme_font_size_override("font_size", 24)
	lanes_box.add_child(battlefield_title)

	var lanes_row := HBoxContainer.new()
	lanes_row.size_flags_horizontal = SIZE_EXPAND_FILL
	lanes_row.size_flags_vertical = SIZE_EXPAND_FILL
	lanes_row.add_theme_constant_override("separation", 20)
	lanes_box.add_child(lanes_row)

	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var lane_panel := PanelContainer.new()
		lane_panel.name = "%s_lane_panel" % lane_id
		lane_panel.custom_minimum_size = Vector2(0, 304)
		lane_panel.size_flags_horizontal = SIZE_EXPAND_FILL
		lane_panel.size_flags_vertical = SIZE_EXPAND_FILL
		lane_panel.size_flags_stretch_ratio = 1.0
		lanes_row.add_child(lane_panel)
		var lane_box := _build_panel_box(lane_panel, 14, 14)

		var header := Button.new()
		header.name = "%s_lane_header" % lane_id
		header.alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.custom_minimum_size = Vector2(0, 72)
		header.add_theme_font_size_override("font_size", 18)
		header.pressed.connect(_on_lane_pressed.bind(lane_id))
		lane_box.add_child(header)
		_lane_header_buttons[lane_id] = header

		for player_id in PLAYER_ORDER:
			var row_panel := PanelContainer.new()
			row_panel.name = "%s_%s_lane_row_panel" % [lane_id, player_id]
			row_panel.custom_minimum_size = Vector2(0, 132)
			row_panel.size_flags_horizontal = SIZE_EXPAND_FILL
			row_panel.size_flags_vertical = SIZE_EXPAND_FILL
			lane_box.add_child(row_panel)
			var row_box := _build_panel_box(row_panel, 10, 12)
			var row_label := Label.new()
			row_label.text = "%s lane" % _player_name(player_id)
			row_label.add_theme_font_size_override("font_size", 16)
			row_box.add_child(row_label)

			var row := HBoxContainer.new()
			row.name = "%s_%s_lane_row" % [lane_id, player_id]
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.size_flags_horizontal = SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 14)
			row_box.add_child(row)
			_lane_row_containers[_lane_row_key(lane_id, player_id)] = row
	return lanes_panel


func _build_read_only_text(tab_name: String) -> TextEdit:
	var text := TextEdit.new()
	text.name = tab_name
	text.editable = false
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.size_flags_vertical = SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 15)
	text.custom_minimum_size = Vector2(0, 180)
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


func _populate_scenario_picker() -> void:
	_scenario_picker.clear()
	var index := 0
	for scenario in MatchDebugScenarios.list_scenarios():
		_scenario_picker.add_item(str(scenario.get("label", scenario.get("id", ""))))
		_scenario_picker.set_item_metadata(index, str(scenario.get("id", "")))
		index += 1


func _refresh_ui() -> void:
	_sync_scenario_picker()
	_status_label.text = _status_message
	_prompt_label.text = _prompt_text()
	_refresh_prompt_buttons()
	_refresh_player_sections()
	_refresh_lanes()
	_refresh_inspector()
	_refresh_debug_tabs()
	_refresh_action_buttons()


func _refresh_player_sections() -> void:
	for player_id in PLAYER_ORDER:
		var section: Dictionary = _player_sections.get(player_id, {})
		var player := _player_state(player_id)
		if section.is_empty() or player.is_empty():
			continue
		var summary_button: Button = section["summary_button"]
		summary_button.text = _player_summary_text(player)
		summary_button.tooltip_text = _player_summary_tooltip(player)

		var support_row: HBoxContainer = section["support_row"]
		_clear_children(support_row)
		for support in player.get("support", []):
			support_row.add_child(_build_card_button(support, true, "support"))
		if support_row.get_child_count() == 0:
			support_row.add_child(_build_placeholder_label("No supports"))

		var hand_row: HBoxContainer = section["hand_row"]
		_clear_children(hand_row)
		var hand_public := _is_hand_public(player_id)
		for card in player.get("hand", []):
			hand_row.add_child(_build_card_button(card, hand_public, "hand"))
		if hand_row.get_child_count() == 0:
			hand_row.add_child(_build_placeholder_label("Hand empty"))


func _refresh_lanes() -> void:
	for lane in _lane_entries():
		var lane_id := str(lane.get("id", ""))
		var header: Button = _lane_header_buttons.get(lane_id)
		if header != null:
			header.text = _lane_header_text(lane_id)
			header.tooltip_text = _lane_description(lane_id)
		for player_id in PLAYER_ORDER:
			var row: HBoxContainer = _lane_row_containers.get(_lane_row_key(lane_id, player_id))
			if row == null:
				continue
			_clear_children(row)
			var slots := _lane_slots(lane_id, player_id)
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) == TYPE_DICTIONARY:
					row.add_child(_build_card_button(card, true, "lane"))
				else:
					row.add_child(_build_empty_slot_button(lane_id, player_id, slot_index))


func _refresh_inspector() -> void:
	var card := _selected_card()
	_clear_children(_keyword_button_row)
	if card.is_empty():
		_inspector_label.text = "Select a visible card or Prophecy prompt to inspect details and available actions."
		_help_label.text = _default_help_text()
		return
	_inspector_label.text = _card_inspector_text(card)
	for term_id in _card_terms(card):
		var button := Button.new()
		button.text = _term_label(term_id)
		button.custom_minimum_size = Vector2(0, 38)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_help_term_pressed.bind(term_id))
		_keyword_button_row.add_child(button)
	_help_label.text = _default_help_text() if _keyword_button_row.get_child_count() == 0 else _build_help_text(_card_terms(card)[0])


func _refresh_debug_tabs() -> void:
	_history_text.text = _history_text_value()
	_replay_text.text = _replay_text_value()
	_state_text.text = JSON.stringify(_match_state, "  ")


func _refresh_prompt_buttons() -> void:
	_clear_children(_prompt_button_row)
	for window in MatchTiming.get_pending_prophecies(_match_state):
		var instance_id := str(window.get("instance_id", ""))
		var player_id := str(window.get("player_id", ""))
		var card := _card_from_instance_id(instance_id)
		var select_button := Button.new()
		select_button.text = "Select %s" % _card_name(card)
		select_button.custom_minimum_size = Vector2(0, 42)
		select_button.add_theme_font_size_override("font_size", 15)
		select_button.pressed.connect(_on_select_prophecy_pressed.bind(instance_id))
		_prompt_button_row.add_child(select_button)

		var decline_button := Button.new()
		decline_button.text = "Decline (%s)" % _player_name(player_id)
		decline_button.custom_minimum_size = Vector2(0, 42)
		decline_button.add_theme_font_size_override("font_size", 15)
		decline_button.pressed.connect(_on_decline_prophecy_pressed.bind(instance_id))
		_prompt_button_row.add_child(decline_button)
	if _prompt_button_row.get_child_count() == 0:
		_prompt_button_row.add_child(_build_placeholder_label("No pending Prophecy windows."))


func _refresh_action_buttons() -> void:
	var active_player := _active_player_id()
	_play_selected_button.disabled = _selected_card().is_empty()
	_ring_button.disabled = not MatchTurnLoop.can_activate_ring_of_magicka(_match_state, active_player) or MatchTiming.has_pending_prophecy(_match_state)
	_end_turn_button.disabled = MatchTiming.has_pending_prophecy(_match_state)


func _build_card_button(card: Dictionary, public_view: bool, surface := "default") -> Button:
	var button := Button.new()
	button.custom_minimum_size = _surface_button_minimum_size(surface)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", _surface_font_size(surface))
	button.pressed.connect(_on_card_pressed.bind(str(card.get("instance_id", ""))))
	button.text = _card_button_text(card, public_view)
	button.tooltip_text = _card_tooltip(card, public_view)
	button.disabled = not public_view and not _is_pending_prophecy_card(card)
	return button


func _build_empty_slot_button(lane_id: String, player_id: String, slot_index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(132, 88)
	button.add_theme_font_size_override("font_size", 15)
	button.text = "Open %d" % (slot_index + 1)
	button.pressed.connect(_on_lane_slot_pressed.bind(lane_id, player_id, slot_index))
	return button


func _build_placeholder_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.custom_minimum_size = Vector2(176, 44)
	return label


func _surface_button_minimum_size(surface: String) -> Vector2:
	match surface:
		"lane":
			return Vector2(168, 104)
		"hand":
			return Vector2(148, 92)
		"support":
			return Vector2(124, 68)
		_:
			return Vector2(132, 80)


func _surface_font_size(surface: String) -> int:
	match surface:
		"lane":
			return 16
		"hand":
			return 15
		"support":
			return 15
		_:
			return 15


func _on_scenario_selected(index: int) -> void:
	var scenario_id := str(_scenario_picker.get_item_metadata(index))
	load_scenario(scenario_id)


func _on_reload_pressed() -> void:
	load_scenario(_scenario_id)


func _on_play_selected_pressed() -> void:
	play_or_activate_selected()


func _on_ring_pressed() -> void:
	use_ring()


func _on_end_turn_pressed() -> void:
	end_turn_action()


func _on_clear_pressed() -> void:
	clear_selection()


func _on_card_pressed(instance_id: String) -> void:
	if _selected_instance_id == instance_id:
		clear_selection()
		return
	if _selected_card_uses_card_target(instance_id):
		return
	select_card(instance_id)


func _on_lane_pressed(lane_id: String) -> void:
	var slot_index := _first_open_slot_index(lane_id, _target_lane_player_id())
	if slot_index >= 0 and _selected_card_wants_lane(_selected_card(), _target_lane_player_id()):
		play_selected_to_lane(lane_id, slot_index)
		return
	_help_label.text = _lane_description(lane_id)
	_status_message = "Lane details: %s." % _lane_name(lane_id)
	_refresh_ui()


func _on_lane_slot_pressed(lane_id: String, player_id: String, slot_index: int) -> void:
	if _selected_card_wants_lane(_selected_card(), player_id):
		play_selected_to_lane(lane_id, slot_index)
		return
	_status_message = "Select a creature that can be summoned into %s." % _lane_name(lane_id)
	_refresh_ui()


func _on_player_pressed(player_id: String) -> void:
	if not _selected_card().is_empty() and player_id != _active_player_id():
		attack_selected_player(player_id)
		return
	_status_message = "%s selected. Click an enemy player with an attacker to strike face." % _player_name(player_id)
	_refresh_ui()


func _on_select_prophecy_pressed(instance_id: String) -> void:
	select_card(instance_id)


func _on_decline_prophecy_pressed(instance_id: String) -> void:
	decline_prophecy(instance_id)


func _on_help_term_pressed(term_id: String) -> void:
	_help_label.text = _build_help_text(term_id)


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


func _sync_scenario_picker() -> void:
	for index in range(_scenario_picker.item_count):
		if str(_scenario_picker.get_item_metadata(index)) == _scenario_id:
			_scenario_picker.select(index)
			return


func _selected_card() -> Dictionary:
	return _card_from_instance_id(_selected_instance_id)


func _selected_card_uses_card_target(fallback_instance_id: String) -> bool:
	var card := _selected_card()
	if card.is_empty() or fallback_instance_id.is_empty():
		return false
	var target_card := _card_from_instance_id(fallback_instance_id)
	if target_card.is_empty():
		return false
	var location := MatchMutations.find_card_location(_match_state, _selected_instance_id)
	if not bool(location.get("is_valid", false)):
		return false
	var zone := str(location.get("zone", ""))
	if zone == MatchMutations.ZONE_HAND and str(card.get("card_type", "")) == "item":
		target_selected_card(fallback_instance_id)
		return true
	if zone == MatchMutations.ZONE_SUPPORT:
		target_selected_card(fallback_instance_id)
		return true
	if zone == MatchMutations.ZONE_LANE and str(target_card.get("controller_player_id", "")) != str(card.get("controller_player_id", "")):
		target_selected_card(fallback_instance_id)
		return true
	return false


func _selected_card_wants_lane(card: Dictionary, player_id: String) -> bool:
	if card.is_empty() or player_id != _target_lane_player_id():
		return false
	if _is_pending_prophecy_card(card):
		return str(card.get("card_type", "")) == "creature"
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	return bool(location.get("is_valid", false)) and str(location.get("zone", "")) == MatchMutations.ZONE_HAND and str(card.get("card_type", "")) == "creature"


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


func _finalize_engine_result(result: Dictionary, success_message: String, clear_selection_on_success := true) -> Dictionary:
	if bool(result.get("is_valid", false)):
		if clear_selection_on_success:
			_selected_instance_id = ""
		_status_message = success_message
	else:
		_status_message = str(result.get("errors", ["Action failed."])[0])
	_refresh_ui()
	return result


func _invalid_ui_result(message: String) -> Dictionary:
	_status_message = message
	_refresh_ui()
	return {"is_valid": false, "errors": [message]}


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


func _target_lane_player_id() -> String:
	if _is_pending_prophecy_card(_selected_card()):
		return str(_selected_card().get("controller_player_id", ""))
	return _active_player_id()


func _player_name(player_id: String) -> String:
	var player := _player_state(player_id)
	if player.is_empty():
		return player_id
	return str(player.get("display_name", player_id))


func _player_summary_text(player: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s%s" % [_player_name(str(player.get("player_id", ""))), " (Active)" if str(player.get("player_id", "")) == _active_player_id() else ""])
	lines.append("Health %d | Runes %d | Magicka %d/%d" % [int(player.get("health", 0)), player.get("rune_thresholds", []).size(), int(player.get("current_magicka", 0)), int(player.get("max_magicka", 0))])
	lines.append("Deck %d | Discard %d | Ring %s" % [player.get("deck", []).size(), player.get("discard", []).size(), _ring_summary(player)])
	return _join_parts(lines, "\n")


func _player_summary_tooltip(player: Dictionary) -> String:
	var runes: Array = player.get("rune_thresholds", [])
	return "Remaining rune thresholds: %s" % [runes]


func _ring_summary(player: Dictionary) -> String:
	if not bool(player.get("has_ring_of_magicka", false)):
		return "None"
	return "%d charge(s)" % int(player.get("ring_of_magicka_charges", 0))


func _lane_entries() -> Array:
	return _lane_registry.get("lanes", [
		{"id": "field", "display_name": "Field Lane", "description": "Default combat lane."},
		{"id": "shadow", "display_name": "Shadow Lane", "description": "New creatures gain Cover briefly here."},
	])


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


func _occupied_slots(lane_id: String, player_id: String) -> int:
	var total := 0
	for card in _lane_slots(lane_id, player_id):
		if typeof(card) == TYPE_DICTIONARY:
			total += 1
	return total


func _first_open_slot_index(lane_id: String, player_id: String) -> int:
	var slots := _lane_slots(lane_id, player_id)
	for slot_index in range(slots.size()):
		if typeof(slots[slot_index]) != TYPE_DICTIONARY:
			return slot_index
	return -1


func _is_hand_public(player_id: String) -> bool:
	return player_id == _active_player_id()


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
		return "Selected %s. It is pending Prophecy; play it for free or decline it from the prompt." % _card_name(card)
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
					return "Selected %s. Use Play / Act to place it into your support row." % _card_name(card)
				_:
					return "Selected %s." % _card_name(card)
		MatchMutations.ZONE_SUPPORT:
			return "Selected %s. Click a target or use Play / Act if the support has no target." % _card_name(card)
		MatchMutations.ZONE_LANE:
			return "Selected %s. Click an opposing creature or player to attack if legal." % _card_name(card)
		_:
			return "Selected %s." % _card_name(card)


func _prompt_text() -> String:
	var windows := MatchTiming.get_pending_prophecies(_match_state)
	if windows.is_empty():
		return "No open interrupt windows. Use the scenario picker, battlefield, and right-rail tools to exercise the match engine."
	var parts: Array = []
	for window in windows:
		var card := _card_from_instance_id(str(window.get("instance_id", "")))
		parts.append("%s may respond with %s." % [_player_name(str(window.get("player_id", ""))), _card_name(card)])
	return "Pending Prophecy: %s" % _join_parts(parts, " ")


func _default_help_text() -> String:
	return "Keyword and lane help appears here. Select a card or click a keyword chip to inspect its rules meaning."


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
	for keyword in card.get("keywords", []):
		terms.append(_term_label(str(keyword)))
	for keyword in card.get("granted_keywords", []):
		terms.append(_term_label(str(keyword)))
	for status in card.get("status_markers", []):
		var status_id := str(status)
		if status_id == EvergreenRules.STATUS_COVER and not EvergreenRules.is_cover_active(_match_state, card):
			continue
		terms.append(_term_label(status_id))
	for rule_tag in card.get("rules_tags", []):
		terms.append(_term_label(str(rule_tag)))
	return _join_parts(_unique_terms(terms), ", ")


func _card_terms(card: Dictionary) -> Array:
	var terms: Array = []
	for keyword in card.get("keywords", []):
		terms.append(str(keyword))
	for keyword in card.get("granted_keywords", []):
		terms.append(str(keyword))
	for status in card.get("status_markers", []):
		var status_id := str(status)
		if status_id == EvergreenRules.STATUS_COVER and not EvergreenRules.is_cover_active(_match_state, card):
			continue
		terms.append(status_id)
	for rule_tag in card.get("rules_tags", []):
		terms.append(str(rule_tag))
	return _unique_terms(terms)


func _term_label(term_id: String) -> String:
	if _keyword_display_names.has(term_id):
		return str(_keyword_display_names[term_id])
	if _status_display_names.has(term_id):
		return str(_status_display_names[term_id])
	if HELP_TEXT.has(term_id):
		return _identifier_to_name(term_id)
	return _identifier_to_name(term_id)


func _build_help_text(term_id: String) -> String:
	var title := _term_label(term_id)
	var body := str(HELP_TEXT.get(term_id, "No extra glossary entry is available for this term yet."))
	if _status_display_names.has(term_id):
		body = "%s\nStatus marker from the evergreen rules registry." % body
	elif _keyword_display_names.has(term_id):
		body = "%s\nKeyword from the evergreen rules registry." % body
	return "%s\n%s" % [title, body]


func _history_text_value() -> String:
	var lines: Array = []
	for event in _match_state.get("event_log", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		lines.append(_format_event_line(event))
	if lines.is_empty():
		return "No processed events yet."
	return _join_parts(lines, "\n")


func _replay_text_value() -> String:
	var lines: Array = []
	for entry in _match_state.get("replay_log", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_type := str(entry.get("entry_type", "entry"))
		var summary := [entry_type]
		if entry.has("family"):
			summary.append(str(entry.get("family", "")))
		if entry.has("event_type"):
			summary.append(str(entry.get("event_type", "")))
		if entry.has("source_instance_id"):
			summary.append(str(entry.get("source_instance_id", "")))
		lines.append("- %s" % _join_parts(summary, " | "))
	if lines.is_empty():
		return "No replay entries yet."
	return _join_parts(lines, "\n")


func _format_event_line(event: Dictionary) -> String:
	var parts: Array = [str(event.get("event_type", "event"))]
	for field in ["source_instance_id", "target_instance_id", "player_id", "lane_id", "reason"]:
		var value := str(event.get(field, ""))
		if not value.is_empty():
			parts.append("%s=%s" % [field, value])
	return "- %s" % _join_parts(parts, " | ")


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


func _lane_row_key(lane_id: String, player_id: String) -> String:
	return "%s:%s" % [lane_id, player_id]


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


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
