class_name MatchScreenCardSurface
extends RefCounted

var _screen  # MatchScreen reference


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


func _build_card_button(card: Dictionary, public_view: bool, surface := "default") -> Button:
	var button := Button.new()
	var instance_id := str(card.get("instance_id", ""))
	var hidden = not public_view and not _screen._overlays._is_pending_prophecy_card(card)
	var selected = instance_id == _screen._selected_instance_id
	var muted := _should_mute_card(card, public_view, surface)
	var interaction_state = _screen._card_interaction_state(card, surface)
	var locked := _should_dim_card_for_turn(card, surface, interaction_state)
	button.name = "%s_%s_card" % [surface, instance_id]
	button.custom_minimum_size = _surface_button_minimum_size(surface)
	button.clip_contents = false
	button.text = ""
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	var no_action = surface == "lane" and _screen._selected_action_mode(card) == _screen.SELECTION_MODE_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if (locked and interaction_state == "default") or no_action else Control.CURSOR_POINTING_HAND
	button.set_meta("instance_id", instance_id)
	button.set_meta("surface", surface)
	button.set_meta("presentation_locked", locked)
	_screen._apply_surface_button_style(button, surface, hidden, selected, muted, interaction_state, card, locked)
	button.pressed.connect(_screen._on_card_pressed.bind(str(card.get("instance_id", ""))))
	button.tooltip_text = ""
	button.disabled = hidden
	button.set_meta("card_display_component", null)
	_populate_card_button_content(button, card, public_view, surface)
	_screen._apply_card_feedback_decoration(button, card, surface)
	if interaction_state == "valid":
		_screen._apply_valid_target_glow(button, surface)
	elif interaction_state == "valid_betray":
		_screen._apply_betray_target_glow(button, surface)
	if surface == "lane" and str(card.get("card_type", "")) == "creature":
		_screen._apply_lane_card_float_effect(button, card)
	_screen._card_buttons[instance_id] = button
	if surface == "hand" and public_view and str(card.get("controller_player_id", "")) == _screen.PLAYER_ORDER[1]:
		button.mouse_entered.connect(_screen._on_local_hand_card_mouse_entered.bind(button))
		button.mouse_exited.connect(_screen._on_local_hand_card_mouse_exited.bind(button))
	if surface == "lane" and str(card.get("card_type", "")) == "creature":
		button.mouse_entered.connect(_screen._on_lane_card_mouse_entered.bind(button, instance_id))
		button.mouse_exited.connect(_screen._on_lane_card_mouse_exited.bind(instance_id))
		button.gui_input.connect(_screen._on_lane_card_gui_input.bind(instance_id))
	if surface == "support":
		button.mouse_entered.connect(_screen._on_support_card_mouse_entered.bind(button, instance_id))
		button.mouse_exited.connect(_screen._on_support_card_mouse_exited.bind(instance_id))
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
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE
		"hand":
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
		"support":
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.SUPPORT_BOARD_MINIMUM_SIZE
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


func _layout_hand_cards(hand_surface: Control, player_id: String) -> void:
	var cards: Array[Button] = []
	for child in hand_surface.get_children():
		if child is Button:
			cards.append(child as Button)
	if cards.is_empty():
		return
	var card_size := _surface_button_minimum_size("hand")
	var count := cards.size()
	var is_local = player_id == _screen.PLAYER_ORDER[1]
	if is_local:
		_layout_local_hand_cards(hand_surface, cards, card_size, count)
	else:
		_layout_opponent_hand_cards(hand_surface, cards, card_size, count)


func _layout_local_hand_cards(hand_surface: Control, cards: Array[Button], card_size: Vector2, count: int) -> void:
	# Cards fan out at the bottom-center of the screen, mostly off the bottom edge.
	var overlay_size = _screen.get_viewport_rect().size
	card_size = _screen._hand_card_display_size()
	var overlap_step := card_size.x * 0.45
	var total_width := card_size.x + overlap_step * float(max(0, count - 1))
	var start_x: float = (overlay_size.x - total_width) * 0.5
	# Cards sit with the top ~35% peeking above the bottom edge
	var base_y: float = overlay_size.y - card_size.y * 0.35
	# Affordable cards peek a bit higher to signal they are playable
	var affordable_rise := card_size.y * 0.06
	var local_player = _screen._player_state(_screen.PLAYER_ORDER[1])
	var available_magicka := int(local_player.get("current_magicka", 0)) + int(local_player.get("temporary_magicka", 0))
	for index in range(count):
		var button := cards[index]
		var instance_id := str(button.get_meta("instance_id", ""))
		var card = _screen._find_card_in_player_hand(_screen.PLAYER_ORDER[1], instance_id)
		var affordable: bool = not card.is_empty() and int(card.get("cost", 0)) <= available_magicka
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
		_screen._hover._apply_local_hand_hover_state(button, false)


func _layout_opponent_hand_cards(hand_surface: Control, cards: Array[Button], card_size: Vector2, count: int) -> void:
	# Cards peek from the top edge of the screen, mirroring the local hand at the bottom.
	var overlay_size = _screen.get_viewport_rect().size
	var target_height: float = overlay_size.y * 0.30
	var aspect_ratio := card_size.x / card_size.y
	card_size = Vector2(target_height * aspect_ratio, target_height)
	var overlap_step := card_size.x * 0.45
	var total_width := card_size.x + overlap_step * float(max(0, count - 1))
	var start_x: float = (overlay_size.x - total_width) * 0.5
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


func _populate_card_button_content(button: Button, card: Dictionary, public_view: bool, surface: String) -> void:
	var hidden = not public_view and not _screen._overlays._is_pending_prophecy_card(card)
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
		_screen._apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)
		content_root.add_child(card_back)
		_screen._set_mouse_passthrough_recursive(content_root)
		return
	var component := _build_card_display_component(card, surface, instance_id)
	if component != null:
		content_root.add_child(component)
		button.set_meta("card_display_component", component)
	_screen._card_display._add_card_overlay_badges(content_root, card, public_view, surface, instance_id)
	_screen._set_mouse_passthrough_recursive(content_root)


func _build_card_display_component(card: Dictionary, surface: String, instance_id: String) -> Control:
	var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	if component == null:
		return null
	component.name = "%s_card_display" % instance_id
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var display_card := card.duplicate(true)
	if surface == "lane" and _screen.EvergreenRules.is_cover_active(_screen._match_state, card):
		display_card["_cover_active"] = true
	if surface == "hand" and str(card.get("controller_player_id", "")) == _screen._active_player_id():
		var effective_cost = _screen.PersistentCardRules.get_effective_play_cost(_screen._match_state, _screen._active_player_id(), card)
		var base_cost := int(card.get("_base_cost", card.get("cost", 0)))
		if effective_cost != base_cost:
			display_card["_effective_cost"] = effective_cost
		_apply_empower_text_updates(display_card, _screen._active_player_id())
	component.apply_card(display_card, _screen._card_display._card_presentation_mode(card, surface))
	if component.has_method("set_wax_wane_phases"):
		component.set_wax_wane_phases(_get_wax_wane_phases_for_card(card))
	if component.has_method("set_relationship_context"):
		component.set_relationship_context(_screen._build_match_relationship_context())
	if surface == "support" and not _screen.PersistentCardRules.can_activate_support(_screen._match_state, _screen._active_player_id(), str(card.get("instance_id", ""))) and int(card.get("activations_this_turn", 0)) > 0:
		component.modulate = Color(0.5, 0.5, 0.55, 0.8)
	return component


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
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE.x / 136.0
		"hand":
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE.x / 156.0
		"support":
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.SUPPORT_BOARD_MINIMUM_SIZE.x / 96.0
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
	return "%d / %d" % [_screen.EvergreenRules.get_power(card), _screen.EvergreenRules.get_remaining_health(card)]


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
	var current = _screen.EvergreenRules.get_power(card) if stat == "power" else _screen.EvergreenRules.get_remaining_health(card)
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
	if surface != "hand" or not public_view or _screen._overlays._is_pending_prophecy_card(card):
		return false
	if str(card.get("controller_player_id", "")) != _screen.PLAYER_ORDER[1]:
		return false
	var player = _screen._player_state(str(card.get("controller_player_id", "")))
	if player.is_empty():
		return false
	var available := int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
	return int(card.get("cost", 0)) > available


func _should_dim_card_for_turn(card: Dictionary, surface: String, interaction_state: String) -> bool:
	if surface != "hand" and surface != "support" and surface != "lane":
		return false
	if not _screen._should_dim_local_interaction_surfaces():
		return false
	if str(card.get("controller_player_id", "")) != _screen._local_player_id():
		return false
	if _screen._overlays._is_pending_prophecy_card(card):
		return false
	if interaction_state == "valid":
		return false
	if str(card.get("instance_id", "")) == _screen._selected_instance_id and _screen._selected_action_mode(card) != _screen.SELECTION_MODE_NONE:
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
	if bool(card.get("cannot_attack", false)) or _screen.EvergreenRules.has_status(card, _screen.EvergreenRules.STATUS_SHACKLED):
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
	if _screen._card_display._lane_attack_limit_reached_for(card):
		return {
			"id": "spent",
			"label": "SPENT",
			"fill": Color(0.18, 0.2, 0.26, 0.98),
			"border": Color(0.62, 0.68, 0.78, 0.94),
			"font": Color(0.89, 0.92, 0.98, 1.0),
		}
	if _screen._entered_lane_this_turn(card) and not _screen.EvergreenRules.has_keyword(card, _screen.EvergreenRules.KEYWORD_CHARGE):
		return {
			"id": "summoning_sick",
			"label": "SUMMONING SICK",
			"fill": Color(0.31, 0.18, 0.11, 0.99),
			"border": Color(0.96, 0.62, 0.32, 0.98),
			"font": Color(1.0, 0.95, 0.88, 1.0),
		}
	if str(card.get("controller_player_id", "")) == _screen._active_player_id():
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


func _get_wax_wane_phases_for_card(card: Dictionary) -> Array:
	var controller_id := str(card.get("controller_player_id", ""))
	if controller_id.is_empty():
		return []
	for player in _screen._match_state.get("players", []):
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
	var empower_amount = _screen.MatchTiming._get_empower_amount(_screen._match_state, player_id)
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
				var bonus: int = eb * empower_amount
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
				var bonus: int = ebc * empower_amount
				if effect.has("max_cost"):
					effect["max_cost"] = int(effect.get("max_cost", 0)) + bonus
			var ebs := int(effect.get("empower_stat_bonus", 0))
			if ebs > 0:
				var bonus: int = ebs * empower_amount
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
