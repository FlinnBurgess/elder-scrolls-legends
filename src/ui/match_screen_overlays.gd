class_name MatchScreenOverlays
extends RefCounted

var _screen  # MatchScreen reference
var _prophecy_overlay_state := {}
var _spell_reveal_state := {}
var _deck_reveal_state := {}
var _mulligan_overlay_state := {}
var _mulligan_marked_ids: Array = []
var _mulligan_card_by_id: Dictionary = {}
var _discard_viewer_state := {}
var _discard_choice_overlay_state := {}
var _consume_selection_overlay_state := {}
var _hand_selection_state := {}
var _top_deck_choice_state := {}
var _player_choice_overlay_state := {}
var _deck_selection_overlay_state := {}
var _pending_exalt := {}


const PRESET_FULL_RECT = Control.PRESET_FULL_RECT
const PRESET_TOP_LEFT = Control.PRESET_TOP_LEFT
const PRESET_TOP_RIGHT = Control.PRESET_TOP_RIGHT
const PRESET_BOTTOM_LEFT = Control.PRESET_BOTTOM_LEFT
const PRESET_BOTTOM_RIGHT = Control.PRESET_BOTTOM_RIGHT
const PRESET_CENTER_TOP = Control.PRESET_CENTER_TOP
const PRESET_CENTER_BOTTOM = Control.PRESET_CENTER_BOTTOM
const PRESET_CENTER = Control.PRESET_CENTER
const SIZE_EXPAND_FILL = Control.SIZE_EXPAND_FILL
const SIZE_SHRINK_CENTER = Control.SIZE_SHRINK_CENTER
const SIZE_SHRINK_END = Control.SIZE_SHRINK_END
const SIZE_FILL = Control.SIZE_FILL

func _init(screen) -> void:
	_screen = screen


func _refresh_prophecy_overlay() -> void:
	var has_prophecy = _screen.MatchTiming.has_pending_prophecy(_screen._match_state)
	var overlay_active := not _prophecy_overlay_state.is_empty()
	if has_prophecy and not overlay_active:
		var windows = _screen.MatchTiming.get_pending_prophecies(_screen._match_state)
		if not windows.is_empty():
			var window: Dictionary = windows[0]
			var instance_id := str(window.get("instance_id", ""))
			var player_id := str(window.get("player_id", ""))
			if player_id == _screen._local_player_id():
				_show_local_prophecy_overlay(instance_id)
			else:
				_show_enemy_prophecy_overlay(instance_id)
	elif not has_prophecy and overlay_active:
		var phase: String = str(_prophecy_overlay_state.get("phase", ""))
		if phase != "animating":
			_dismiss_prophecy_overlay()


func _show_local_prophecy_overlay(instance_id: String) -> void:
	_dismiss_prophecy_overlay()
	var card = _screen._card_from_instance_id(instance_id)
	if card.is_empty():
		return
	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size
	var hand_top_y: float = viewport_size.y - card_size.y * 0.35

	var vbox := VBoxContainer.new()
	vbox.name = "prophecy_local_vbox"
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_END

	var card_wrapper := Control.new()
	card_wrapper.name = "prophecy_card_wrapper"
	card_wrapper.custom_minimum_size = card_size
	card_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
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
	_screen._apply_button_style(play_button, Color(0.21, 0.12, 0.29, 0.99), Color(0.92, 0.72, 0.98, 1.0), Color(0.99, 0.96, 1.0, 1.0), 2, 10)
	play_button.pressed.connect(_screen._on_prophecy_play_pressed.bind(instance_id))
	button_row.add_child(play_button)

	var local_id = _screen._local_player_id()
	var local_player := {}
	for p in _screen._match_state.get("players", []):
		if str(p.get("player_id", "")) == local_id:
			local_player = p
			break
	var hand_full: bool = local_player.get("hand", []).size() > _screen.MatchTiming.MAX_HAND_SIZE

	var keep_button := Button.new()
	keep_button.text = "Discard" if hand_full else "Keep"
	keep_button.custom_minimum_size = Vector2(card_size.x * 0.45, 46)
	keep_button.add_theme_font_size_override("font_size", 17)
	_screen._apply_button_style(keep_button, Color(0.22, 0.11, 0.14, 0.98), Color(0.78, 0.45, 0.47, 0.96), Color(0.99, 0.95, 0.95, 1.0), 1, 10)
	keep_button.pressed.connect(_screen._on_prophecy_keep_pressed.bind(instance_id))
	button_row.add_child(keep_button)

	vbox.add_child(button_row)

	var total_height: float = card_size.y + 12.0 + 46.0
	var top_y: float = hand_top_y - total_height - 16.0
	vbox.position = Vector2((viewport_size.x - card_size.x) * 0.5, top_y)
	vbox.size = Vector2(card_size.x, total_height)

	_screen._prophecy_card_overlay.add_child(vbox)
	_prophecy_overlay_state = {
		"instance_id": instance_id,
		"player_id": _screen._local_player_id(),
		"is_local": true,
		"vbox": vbox,
		"card_wrapper": card_wrapper,
		"component": component,
		"phase": "active",
	}
	_screen._selected_instance_id = instance_id


func _show_enemy_prophecy_overlay(instance_id: String) -> void:
	_dismiss_prophecy_overlay()
	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "prophecy_enemy_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_screen._apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x: float = (viewport_size.x - card_size.x) * 0.5
	var pos_y: float = viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_screen._prophecy_card_overlay.add_child(card_back)
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


func decline_prophecy(instance_id: String) -> Dictionary:
	var player_id := _pending_prophecy_player_id(instance_id)
	if player_id.is_empty():
		return _screen._invalid_ui_result("No pending Prophecy exists for %s." % instance_id)
	var card = _screen._card_from_instance_id(instance_id)
	var result = _screen.MatchTiming.decline_pending_prophecy(_screen._match_state, player_id, instance_id)
	return _screen._finalize_engine_result(result, "Declined %s." % _screen._card_name(card), false)


func _is_pending_prophecy_card(card: Dictionary) -> bool:
	if card.is_empty():
		return false
	for window in _screen.MatchTiming.get_pending_prophecies(_screen._match_state, str(card.get("controller_player_id", ""))):
		if str(window.get("instance_id", "")) == str(card.get("instance_id", "")):
			return true
	return false


func _pending_prophecy_player_id(instance_id: String) -> String:
	for window in _screen.MatchTiming.get_pending_prophecies(_screen._match_state):
		if str(window.get("instance_id", "")) == instance_id:
			return str(window.get("player_id", ""))
	return ""


func _show_mulligan_overlay() -> void:
	_dismiss_mulligan_overlay()
	_mulligan_marked_ids = []
	var local_id = _screen._local_player_id()
	var player := {}
	for p in _screen._match_state.get("players", []):
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
	turn_order_label.add_theme_font_size_override("font_size", 28)
	turn_order_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58, 0.9))
	vbox.add_child(turn_order_label)

	var title_label := Label.new()
	title_label.text = "Choose cards to replace"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1.0))
	vbox.add_child(title_label)

	var card_row := HBoxContainer.new()
	card_row.name = "MulliganCardRow"
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 16)
	card_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(card_row)

	var base: Vector2 = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var mulligan_height: float = _screen.get_viewport_rect().size.y * 0.45
	var aspect_ratio: float = base.x / base.y
	var card_size := Vector2(mulligan_height * aspect_ratio, mulligan_height)
	var card_buttons_map := {}
	var x_labels_map := {}
	_screen._mulligan_instance_id_order = []

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

		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_button.add_child(component)

		var x_label := Label.new()
		x_label.name = "XMark"
		x_label.text = "✕"
		x_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		x_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		x_label.add_theme_font_size_override("font_size", 120)
		x_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.2, 0.95))
		x_label.add_theme_constant_override("outline_size", 15)
		x_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		x_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x_label.visible = false
		card_button.add_child(x_label)

		card_button.pressed.connect(_on_mulligan_card_toggled.bind(instance_id))
		card_row.add_child(card_button)
		card_buttons_map[instance_id] = card_button
		x_labels_map[instance_id] = x_label
		_screen._mulligan_instance_id_order.append(instance_id)

	var continue_button := Button.new()
	continue_button.name = "MulliganContinue"
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(180, 50)
	continue_button.add_theme_font_size_override("font_size", 20)
	_screen._apply_button_style(continue_button, Color(0.28, 0.22, 0.08, 0.98), Color(0.78, 0.65, 0.22, 0.96), Color(0.98, 0.93, 0.82, 1.0), 2, 10)
	continue_button.pressed.connect(_on_mulligan_confirm_pressed)
	vbox.add_child(continue_button)

	_screen.add_child(overlay)
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
	_screen._mulligan_instance_id_order = []


func _finalize_mulligan(discard_instance_ids: Array) -> void:
	_screen.MatchBootstrap.apply_mulligan(_screen._match_state, _screen._local_player_id(), discard_instance_ids)
	_screen._hydrate_match_cards(_screen._match_state, _mulligan_card_by_id)
	# Re-apply augments after hydration so stat bonuses aren't overwritten
	if not _screen._adventure_augments.is_empty():
		_screen._apply_adventure_augments(_screen._match_state, _screen.PLAYER_ORDER[1])
	_screen.GameLogger.start_match(_screen._match_state)
	_screen.MatchTurnLoop.begin_first_turn(_screen._match_state)
	_screen._ai_system._ai_enabled = true
	if not _screen._is_local_player_turn():
		_screen._schedule_local_match_ai_step(2000)
	_mulligan_card_by_id = {}
	var scenario_events = _screen._history._recent_presentation_events_from_history()
	_screen._record_feedback_from_events(scenario_events)
	_screen._status_message = "Match started."
	_screen._refresh_ui()
	if _screen._arena_mode:
		_screen.match_state_changed.emit(_screen._match_state.duplicate(true))


func _show_discard_viewer(player_id: String) -> void:
	_dismiss_discard_viewer()
	var player = _screen._player_state(player_id)
	if player.is_empty():
		return
	var discard_pile: Array = player.get("discard", [])
	if discard_pile.is_empty():
		_screen._status_message = "%s's discard pile is empty." % _screen._player_name(player_id)
		_screen._refresh_ui()
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
	title_label.text = "%s's Discard Pile (%d)" % [_screen._player_name(player_id), discard_pile.size()]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1.0))
	vbox.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)

	var card_size = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(_screen.get_viewport_rect().size.x - 120) / int(card_size.x + 10))
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

		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_wrapper.add_child(component)
		grid.add_child(card_wrapper)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(160, 44)
	close_button.add_theme_font_size_override("font_size", 18)
	_screen._apply_button_style(close_button, Color(0.2, 0.12, 0.16, 0.98), Color(0.58, 0.32, 0.39, 0.94), Color(0.97, 0.92, 0.94, 1.0), 1, 10)
	close_button.pressed.connect(_dismiss_discard_viewer)
	close_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	vbox.add_child(close_button)

	_screen.add_child(overlay)
	_discard_viewer_state = {"overlay": overlay}
	_screen._status_message = "Viewing %s's discard pile." % _screen._player_name(player_id)


func _dismiss_discard_viewer() -> void:
	if _discard_viewer_state.is_empty():
		return
	var overlay: Control = _discard_viewer_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_discard_viewer_state = {}


func _has_local_pending_discard_choice() -> bool:
	return _screen.MatchTiming.has_pending_discard_choice(_screen._match_state, _screen._local_player_id())


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
	var local_id = _screen._local_player_id()
	var choice = _screen.MatchTiming.get_pending_discard_choice(_screen._match_state, local_id)
	if choice.is_empty():
		return
	var candidate_ids: Array = choice.get("candidate_instance_ids", [])
	if candidate_ids.is_empty():
		_screen.MatchTiming.decline_pending_discard_choice(_screen._match_state, local_id)
		_screen._refresh_ui()
		return

	var player = _screen._player_state(local_id)
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

	var card_size = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(_screen.get_viewport_rect().size.x - 120) / int(card_size.x + 10))
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

		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_button.add_child(component)

		card_button.pressed.connect(_on_discard_choice_selected.bind(instance_id))
		grid.add_child(card_button)

	_screen.add_child(overlay)
	_discard_choice_overlay_state = {"overlay": overlay}
	_screen._status_message = title_text


func _on_discard_choice_selected(instance_id: String) -> void:
	if _discard_choice_overlay_state.is_empty():
		return
	var local_id = _screen._local_player_id()
	var result = _screen.MatchTiming.resolve_pending_discard_choice(_screen._match_state, local_id, instance_id)
	_dismiss_discard_choice_overlay()
	if bool(result.get("is_valid", false)):
		var card_name := str(result.get("card", {}).get("name", instance_id))
		_screen._record_feedback_from_events(_screen._copy_array(result.get("events", [])))
		_screen._status_message = "Drew %s from discard pile." % card_name
		_screen._targeting._check_pending_summon_effect_target()
	else:
		_screen._status_message = str(result.get("errors", ["Failed to resolve discard choice."])[0])
	_screen._refresh_ui()


func _dismiss_discard_choice_overlay() -> void:
	if _discard_choice_overlay_state.is_empty():
		return
	var overlay: Control = _discard_choice_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_discard_choice_overlay_state = {}


# --- Deck selection overlay ---




func _has_local_pending_deck_selection() -> bool:
	return _screen.MatchTiming.has_pending_deck_selection(_screen._match_state, _screen._local_player_id())


func _refresh_deck_selection_overlay() -> void:
	var has_selection := _has_local_pending_deck_selection()
	var overlay_active := not _deck_selection_overlay_state.is_empty()
	if has_selection and not overlay_active:
		_show_deck_selection_overlay()
	elif not has_selection and overlay_active:
		_screen._dismiss_deck_selection_overlay()


func _show_deck_selection_overlay() -> void:
	_screen._dismiss_deck_selection_overlay()
	_dismiss_discard_viewer()
	var local_id = _screen._local_player_id()
	var selection = _screen.MatchTiming.get_pending_deck_selection(_screen._match_state, local_id)
	if selection.is_empty():
		return
	var candidate_ids: Array = selection.get("candidate_instance_ids", [])
	if candidate_ids.is_empty():
		_screen.MatchTiming.decline_pending_deck_selection(_screen._match_state, local_id)
		_screen._refresh_ui()
		return

	var player = _screen._player_state(local_id)
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

	var card_size = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(_screen.get_viewport_rect().size.x - 120) / int(card_size.x + 10))
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

		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
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

	_screen.add_child(overlay)
	_deck_selection_overlay_state = {"overlay": overlay}
	_screen._status_message = prompt_text


func _on_deck_selection_chosen(instance_id: String) -> void:
	if _deck_selection_overlay_state.is_empty():
		return
	var local_id = _screen._local_player_id()
	var result = _screen.MatchTiming.resolve_pending_deck_selection(_screen._match_state, local_id, instance_id)
	_screen._dismiss_deck_selection_overlay()
	if bool(result.get("is_valid", false)):
		var card_name := str(result.get("card", {}).get("name", instance_id))
		_screen._record_feedback_from_events(_screen._copy_array(result.get("events", [])))
		_screen._status_message = "Selected %s from deck." % card_name
	else:
		_screen._status_message = str(result.get("errors", ["Failed to resolve deck selection."])[0])
	_screen._refresh_ui()


func _on_deck_selection_declined() -> void:
	if _deck_selection_overlay_state.is_empty():
		return
	var local_id = _screen._local_player_id()
	_screen.MatchTiming.decline_pending_deck_selection(_screen._match_state, local_id)
	_screen._dismiss_deck_selection_overlay()
	_screen._status_message = "Selection declined."
	_screen._refresh_ui()


func _refresh_consume_selection_overlay() -> void:
	var has_selection = _screen._has_local_pending_consume_selection()
	var overlay_active := not _consume_selection_overlay_state.is_empty()
	if has_selection and not overlay_active:
		_show_consume_selection_overlay()
	elif not has_selection and overlay_active:
		_dismiss_consume_selection_overlay()


func _show_consume_selection_overlay() -> void:
	_dismiss_consume_selection_overlay()
	_dismiss_discard_viewer()
	var local_id = _screen._local_player_id()
	var selection = _screen.MatchTiming.get_pending_consume_selection(_screen._match_state, local_id)
	if selection.is_empty():
		return
	var candidate_ids: Array = selection.get("candidate_instance_ids", [])
	if candidate_ids.is_empty():
		_screen.MatchTiming.decline_consume_selection(_screen._match_state, local_id)
		_screen._refresh_ui()
		return

	var player = _screen._player_state(local_id)
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

	var card_size = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(_screen.get_viewport_rect().size.x - 120) / int(card_size.x + 10))
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

		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_button.add_child(component)

		card_button.pressed.connect(_screen._on_consume_selection_chosen.bind(instance_id))
		grid.add_child(card_button)

	# Add skip button
	var skip_button := Button.new()
	skip_button.text = "Skip (Escape)"
	skip_button.custom_minimum_size = Vector2(160, 40)
	skip_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	skip_button.pressed.connect(_screen._on_consume_selection_declined)
	vbox.add_child(skip_button)

	_screen.add_child(overlay)
	_consume_selection_overlay_state = {"overlay": overlay}
	_screen._status_message = "Choose a creature to Consume"


func _dismiss_consume_selection_overlay() -> void:
	if _consume_selection_overlay_state.is_empty():
		return
	var overlay: Control = _consume_selection_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_consume_selection_overlay_state = {}


# --- Player choice overlay ---




func _refresh_player_choice_overlay() -> void:
	var has_choice = _screen._has_local_pending_player_choice()
	var overlay_active := not _player_choice_overlay_state.is_empty()
	if has_choice and not overlay_active:
		_show_player_choice_overlay()
	elif not has_choice and overlay_active:
		_dismiss_player_choice_overlay()


func _show_player_choice_overlay() -> void:
	_dismiss_player_choice_overlay()
	var choice = _screen.MatchTiming.get_pending_player_choice(_screen._match_state, _screen._local_player_id())
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
			var base_size: Vector2 = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
			var card_scale := 1.5
			card_button.custom_minimum_size = base_size * card_scale
			var card_display = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
			card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_display.scale = Vector2(card_scale, card_scale)
			card_button.add_child(card_display)
			card_display.apply_card(option["card"], _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
			_screen._apply_button_style(card_button, Color(0.12, 0.13, 0.17, 0.95), Color(0.4, 0.38, 0.5, 0.8), Color.WHITE)
			var idx := oi
			card_button.pressed.connect(func(): _screen._on_player_choice_selected(idx))
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
			_screen._apply_button_style(btn, Color(0.15, 0.14, 0.2, 0.95), Color(0.5, 0.45, 0.55, 0.8), Color.WHITE)
			var idx := oi
			btn.pressed.connect(func(): _screen._on_player_choice_selected(idx))
			hbox.add_child(btn)

	_screen.add_child(overlay)
	_player_choice_overlay_state = {"overlay": overlay}


func _dismiss_player_choice_overlay() -> void:
	if _player_choice_overlay_state.is_empty():
		return
	var overlay: Control = _player_choice_overlay_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	_player_choice_overlay_state = {}


# --- Hand selection mechanic ---


func _enter_hand_selection_mode() -> void:
	var local_id = _screen._local_player_id()
	var selection = _screen.MatchTiming.get_pending_hand_selection(_screen._match_state, local_id)
	if selection.is_empty():
		return
	var candidate_ids: Array = selection.get("candidate_instance_ids", [])
	if candidate_ids.is_empty():
		_screen.MatchTiming.decline_pending_hand_selection(_screen._match_state, local_id)
		_screen._refresh_ui()
		return
	_hand_selection_state = {
		"candidate_ids": candidate_ids,
		"source_instance_id": str(selection.get("source_instance_id", "")),
		"prompt": str(selection.get("prompt", "Choose a card from your hand.")),
		"mandatory": bool(selection.get("mandatory", false)),
	}
	_screen._selected_instance_id = ""
	_screen._status_message = str(_hand_selection_state.get("prompt", ""))


func _exit_hand_selection_mode() -> void:
	_hand_selection_state = {}


func _resolve_hand_selection(instance_id: String) -> void:
	if _hand_selection_state.is_empty():
		return
	var local_id = _screen._local_player_id()
	var result = _screen.MatchTiming.resolve_pending_hand_selection(_screen._match_state, local_id, instance_id)
	_exit_hand_selection_mode()
	if bool(result.get("is_valid", false)):
		var card_name := str(result.get("card", {}).get("name", instance_id))
		_screen._record_feedback_from_events(_screen._copy_array(result.get("events", [])))
		_screen._status_message = "Selected %s." % card_name
	else:
		_screen._status_message = str(result.get("errors", ["Failed to resolve hand selection."])[0])
	_screen._refresh_ui()


func _cancel_hand_selection() -> void:
	if bool(_hand_selection_state.get("mandatory", false)):
		return
	var local_id = _screen._local_player_id()
	_screen.MatchTiming.decline_pending_hand_selection(_screen._match_state, local_id)
	_exit_hand_selection_mode()
	_screen._status_message = "Selection declined."
	_screen._refresh_ui()


func _refresh_top_deck_choice_state() -> void:
	var has_choice = _screen.MatchTiming.has_pending_top_deck_choice(_screen._match_state, _screen._local_player_id())
	var state_active := not _top_deck_choice_state.is_empty()
	if has_choice and not state_active:
		_screen._enter_top_deck_choice_mode()
	elif not has_choice and state_active:
		_screen._exit_top_deck_choice_mode()


func _can_player_afford_exalt(card: Dictionary) -> bool:
	var extra = _screen._card_exalt_extra_cost(card)
	if extra == 0:
		return false
	var player_id = _screen._active_player_id()
	var player = _screen._player_state(player_id)
	var available := maxi(0, int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0)))
	var base_cost = _screen.PersistentCardRules.get_effective_play_cost(_screen._match_state, player_id, card)
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

	_screen.add_child(container)
	# Position: centered above anchor point
	container.size = container.get_minimum_size()
	container.position = Vector2(anchor_pos.x - container.size.x * 0.5, anchor_pos.y - container.size.y - 8)
	_screen._exalt_button_container = container


func _dismiss_exalt_prompt() -> void:
	if _screen._exalt_button_container != null and is_instance_valid(_screen._exalt_button_container):
		_screen._exalt_button_container.queue_free()
	_screen._exalt_button_container = null
	if _screen._exalt_card_preview != null and is_instance_valid(_screen._exalt_card_preview):
		_screen._exalt_card_preview.queue_free()
	_screen._exalt_card_preview = null


func _check_exalt_creature(card: Dictionary, lane_id: String, slot_index: int, is_prophecy: bool) -> bool:
	"""Checks if a creature has exalt and the player can afford it.
	If so, shows the exalt prompt and returns true (play deferred).
	Otherwise returns false (caller should proceed normally)."""
	if not _can_player_afford_exalt(card):
		return false
	var exalt_cost = _screen._card_exalt_extra_cost(card)
	_pending_exalt = {
		"card_type": "creature",
		"instance_id": _screen._selected_instance_id,
		"card": card.duplicate(true),
		"exalt_cost": exalt_cost,
		"lane_id": lane_id,
		"slot_index": slot_index,
		"is_prophecy": is_prophecy,
	}
	var anchor := _get_exalt_anchor_for_detached_card()
	_show_exalt_prompt(anchor, exalt_cost)
	_screen._status_message = "Exalt %s?" % _screen._card_name(card)
	_screen._refresh_ui()
	return true


func _check_exalt_action(card: Dictionary, options: Dictionary, is_prophecy: bool) -> bool:
	"""Checks if an action has exalt and the player can afford it.
	If so, shows the exalt prompt and returns true (play deferred).
	Otherwise returns false (caller should proceed normally)."""
	if not _can_player_afford_exalt(card):
		return false
	var exalt_cost = _screen._card_exalt_extra_cost(card)
	_pending_exalt = {
		"card_type": "action",
		"instance_id": _screen._selected_instance_id,
		"card": card.duplicate(true),
		"exalt_cost": exalt_cost,
		"action_options": options.duplicate(true),
		"is_prophecy": is_prophecy,
	}
	# For actions: if detached card exists, anchor above it; otherwise create centered preview
	var anchor: Vector2
	if not _screen._hand._detached_card_state.is_empty():
		anchor = _get_exalt_anchor_for_detached_card()
	else:
		_screen._cancel_targeting_mode_silent()
		anchor = _create_centered_exalt_card_preview(card)
	_show_exalt_prompt(anchor, exalt_cost)
	_screen._status_message = "Exalt %s?" % _screen._card_name(card)
	_screen._refresh_ui()
	return true


func _resolve_exalt(exalted: bool) -> void:
	var pending := _pending_exalt
	_pending_exalt = {}
	_dismiss_exalt_prompt()
	_screen._cancel_detached_card_silent()

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
			result = _screen.MatchTiming.play_pending_prophecy(_screen._match_state, str(card.get("controller_player_id", "")), instance_id, options.merged({"lane_id": lane_id}, true))
		else:
			result = _screen.LaneRules.summon_from_hand(_screen._match_state, _screen._active_player_id(), instance_id, lane_id, options)
		var finalized = _screen._finalize_engine_result(result, "Played %s into %s." % [_screen._card_name(card), _screen._lane_name(lane_id)])
		if bool(finalized.get("is_valid", false)):
			_screen._check_summon_target_mode(instance_id)
	elif str(pending.get("card_type", "")) == "action":
		var options: Dictionary = pending.get("action_options", {}).duplicate(true)
		if exalted:
			options["exalt"] = true
		var result: Dictionary
		if is_prophecy:
			result = _screen.MatchTiming.play_pending_prophecy(_screen._match_state, str(card.get("controller_player_id", "")), instance_id, options)
		else:
			result = _screen.MatchTiming.play_action_from_hand(_screen._match_state, _screen._active_player_id(), instance_id, options)
		var finalized = _screen._finalize_engine_result(result, "Played %s." % _screen._card_name(card))
		if bool(finalized.get("is_valid", false)):
			_screen._check_betray_mode(instance_id, card)


func _create_centered_exalt_card_preview(card: Dictionary) -> Vector2:
	"""Creates a card display centered on the board for action exalt prompts.
	Returns the top-center position for button anchoring."""
	var viewport_size = _screen.get_viewport_rect().size
	var base_size = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "ExaltCardPreview"
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 600
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.setup_card(card, "compact", true)
	wrapper.add_child(component)
	_screen.add_child(wrapper)
	wrapper.position = Vector2(viewport_size.x * 0.5 - base_size.x * 0.5, viewport_size.y * 0.5 - base_size.y * 0.5)
	_screen._exalt_card_preview = wrapper
	return Vector2(viewport_size.x * 0.5, wrapper.position.y)


func _get_exalt_anchor_for_detached_card() -> Vector2:
	"""Returns the top-center of the detached card preview for button anchoring."""
	var preview: Control = _screen._hand._detached_card_state.get("preview")
	if preview != null and is_instance_valid(preview):
		return Vector2(preview.global_position.x + preview.size.x * 0.5, preview.global_position.y)
	# Fallback: center of screen
	var viewport_size = _screen.get_viewport_rect().size
	return Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5 - 80)
