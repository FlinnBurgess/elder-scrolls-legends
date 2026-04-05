class_name MatchScreenCardDisplay
extends RefCounted

var _screen  # MatchScreen reference

func _init(screen) -> void:
	_screen = screen


func _card_presentation_mode(card: Dictionary, surface: String) -> String:
	match surface:
		"lane":
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_CREATURE_BOARD_MINIMAL if str(card.get("card_type", "")) == "creature" else _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL
		"support":
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_SUPPORT_BOARD_MINIMAL if str(card.get("card_type", "")) == "support" else _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL
		_:
			return _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL


func _add_card_overlay_badges(content_root: Control, card: Dictionary, public_view: bool, surface: String, instance_id: String) -> void:
	if surface == "lane":
		var lane_badges := _build_lane_status_badges(card, instance_id)
		if lane_badges != null:
			content_root.add_child(lane_badges)
	if surface == "support":
		var counter_badge := _build_support_counter_badge(card)
		if counter_badge != null:
			content_root.add_child(counter_badge)
	if surface == "hand":
		var hand_badges := _build_hand_emphasis_badges(card, public_view, surface, instance_id)
		if hand_badges != null:
			content_root.add_child(hand_badges)


func _build_support_counter_badge(card: Dictionary) -> Label:
	var threshold := 0
	var counter_name := ""
	for trigger in card.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		for effect in trigger.get("effects", []):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			if str(effect.get("op", "")) == "add_counter" and int(effect.get("threshold", 0)) > 0:
				counter_name = str(effect.get("counter", effect.get("counter_name", "counter")))
				threshold = int(effect.get("threshold", 0))
				break
		if threshold > 0:
			break
	if threshold == 0:
		return null
	var current := int(card.get("_counter_" + counter_name, 0))
	var label := Label.new()
	label.text = "%d/%d" % [current, threshold]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	return label


func _build_lane_status_badges(_card: Dictionary, _instance_id: String) -> HBoxContainer:
	return null


func _lane_readiness_badge_text(card: Dictionary) -> String:
	var cid := str(card.get("instance_id", "?"))
	if str(card.get("controller_player_id", "")) != _screen._active_player_id():
		print("[READINESS] %s -> WAITING (not active player)" % cid)
		return "WAITING"
	if bool(card.get("cannot_attack", false)) or _screen.EvergreenRules.has_status(card, _screen.EvergreenRules.STATUS_SHACKLED):
		print("[READINESS] %s -> WAITING (cannot_attack=%s shackled=%s)" % [cid, card.get("cannot_attack", false), _screen.EvergreenRules.has_status(card, _screen.EvergreenRules.STATUS_SHACKLED)])
		return "WAITING"
	if bool(card.get("has_attacked_this_turn", false)):
		var extra := int(card.get("extra_attacks_remaining", 0))
		print("[READINESS] %s has_attacked=true extra_attacks_remaining=%d" % [cid, extra])
		if extra <= 0:
			return "WAITING"
	if _lane_attack_limit_reached_for(card):
		print("[READINESS] %s -> WAITING (lane_attack_limit reached)" % cid)
		return "WAITING"
	if _screen._entered_lane_this_turn(card) and not _screen.EvergreenRules.has_keyword(card, _screen.EvergreenRules.KEYWORD_CHARGE):
		print("[READINESS] %s -> WAITING (summoning sick: entered_lane_on_turn=%s turn_number=%s)" % [cid, card.get("entered_lane_on_turn", -1), _screen._match_state.get("turn_number", 0)])
		return "WAITING"
	print("[READINESS] %s -> READY" % cid)
	return "READY"


func _lane_attack_limit_reached_for(card: Dictionary) -> bool:
	var lane_id := str(card.get("lane_id", ""))
	if lane_id.is_empty():
		return false
	var has_limit := false
	for lane in _screen._match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for pid in lane.get("player_slots", {}).keys():
			for c in lane.get("player_slots", {}).get(pid, []):
				if typeof(c) == TYPE_DICTIONARY and _screen.EvergreenRules._has_passive(c, "lane_attack_limit"):
					has_limit = true
					break
			if has_limit:
				break
		if has_limit:
			break
	if not has_limit:
		return false
	for lane in _screen._match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		if int(lane.get("_attacks_this_turn", 0)) > 0:
			return true
	return false


func _build_hand_emphasis_badges(_card: Dictionary, _public_view: bool, _surface: String, _instance_id: String) -> HBoxContainer:
	return null


func _build_value_badge(name_prefix: String, text: String, fill: Color, border: Color, font_color: Color, font_size: int, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "%s_badge" % name_prefix
	panel.custom_minimum_size = min_size
	_screen._apply_panel_style(panel, fill, border, 1, 8)
	var box = _screen._build_panel_box(panel, 0, 6)
	var label := Label.new()
	label.name = "%s_label" % name_prefix
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	box.add_child(label)
	return panel


func _card_button_text(card: Dictionary, public_view: bool) -> String:
	if not public_view and not _screen._overlays._is_pending_prophecy_card(card):
		return "Hidden Card"
	var lines: Array = []
	var prefix := "▶ " if str(card.get("instance_id", "")) == _screen._selected_instance_id else ""
	lines.append("%s%s" % [prefix, _card_name(card)])
	lines.append("Cost %d | %s" % [int(card.get("cost", 0)), str(card.get("card_type", "")).capitalize()])
	if str(card.get("card_type", "")) == "creature":
		lines.append("%d / %d" % [_screen.EvergreenRules.get_power(card), _screen.EvergreenRules.get_remaining_health(card)])
	var tags := _card_tag_text(card)
	if not tags.is_empty():
		lines.append(tags)
	return _screen._join_parts(lines, "\n")


func _card_tooltip(card: Dictionary, public_view: bool) -> String:
	if not public_view and not _screen._overlays._is_pending_prophecy_card(card):
		return "Opponent hand card. Full details are hidden until it becomes public."
	return _card_inspector_text(card)


func _card_inspector_text(card: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s" % _card_name(card))
	lines.append("Type %s | Cost %d" % [str(card.get("card_type", "")).capitalize(), int(card.get("cost", 0))])
	if str(card.get("card_type", "")) == "creature":
		lines.append("Power %d | Health %d" % [_screen.EvergreenRules.get_power(card), _screen.EvergreenRules.get_remaining_health(card)])
	lines.append("Zone %s | Controller %s" % [str(card.get("zone", "unknown")), _screen._player_name(str(card.get("controller_player_id", "")))])
	var tags := _card_tag_text(card)
	if not tags.is_empty():
		lines.append("Tags: %s" % tags)
	var attached_items: Array = card.get("attached_items", [])
	if attached_items.size() > 0:
		var names: Array = []
		for item in attached_items:
			if typeof(item) == TYPE_DICTIONARY:
				names.append(_card_name(item))
		lines.append("Attached: %s" % _screen._join_parts(names, ", "))
	var rules_text := str(card.get("rules_text", ""))
	if not rules_text.is_empty():
		lines.append("Rules: %s" % rules_text)
	return _screen._join_parts(lines, "\n")


func _card_tag_text(card: Dictionary) -> String:
	var terms: Array = []
	var keyword_counts := {}
	for keyword in card.get("keywords", []):
		var kw_id := str(keyword)
		keyword_counts[kw_id] = keyword_counts.get(kw_id, 0) + 1
	for keyword in card.get("granted_keywords", []):
		var kw_id := str(keyword)
		keyword_counts[kw_id] = keyword_counts.get(kw_id, 0) + 1
	for item in _screen.EvergreenRules.get_attached_items(card):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		for kw in item.get("equip_keywords", []):
			var kw_id := str(kw)
			keyword_counts[kw_id] = keyword_counts.get(kw_id, 0) + 1
	for kw_id in keyword_counts:
		var count: int = keyword_counts[kw_id]
		var label = _screen._term_label(kw_id)
		if kw_id == "rally" and count > 1:
			label += " " + str(count)
		terms.append(label)
	for status in card.get("status_markers", []):
		var status_id := str(status)
		if status_id == _screen.EvergreenRules.STATUS_COVER and not _screen.EvergreenRules.is_cover_active(_screen._match_state, card):
			continue
		terms.append(_screen._term_label(status_id))
	for rule_tag in card.get("rules_tags", []):
		terms.append(_screen._term_label(str(rule_tag)))
	return _screen._join_parts(_screen._unique_terms(terms), ", ")


func _card_name(card: Dictionary) -> String:
	if card.is_empty():
		return "Unknown Card"
	var name := str(card.get("name", ""))
	if not name.is_empty():
		return name
	return _screen._identifier_to_name(str(card.get("definition_id", card.get("instance_id", "card"))))


func _selection_prompt(card: Dictionary) -> String:
	var location = _screen.MatchMutations.find_card_location(_screen._match_state, str(card.get("instance_id", "")))
	if _screen._overlays._is_pending_prophecy_card(card):
		var pid := str(card.get("controller_player_id", ""))
		var pl := {}
		for p in _screen._match_state.get("players", []):
			if str(p.get("player_id", "")) == pid:
				pl = p
				break
		if pl.get("hand", []).size() > _screen.MatchTiming.MAX_HAND_SIZE:
			return "Selected %s. It is pending Prophecy; play it for free or discard it." % _card_name(card)
		return "Selected %s. It is pending Prophecy; play it for free or keep it in hand." % _card_name(card)
	if not bool(location.get("is_valid", false)):
		return "Inspecting %s." % _card_name(card)
	match str(location.get("zone", "")):
		_screen.MatchMutations.ZONE_HAND:
			match str(card.get("card_type", "")):
				"creature":
					return "Selected %s. Click a friendly lane slot to summon it." % _card_name(card)
				"item":
					return "Selected %s. Click a friendly creature to equip it." % _card_name(card)
				"support":
					return "Selected %s. Click your support row to place it." % _card_name(card)
				_:
					return "Selected %s." % _card_name(card)
		_screen.MatchMutations.ZONE_SUPPORT:
				return "Selected %s. Click a target to activate it." % _card_name(card)
		_screen.MatchMutations.ZONE_LANE:
			return "Selected %s. Click an opposing creature or player to attack if legal." % _card_name(card)
		_:
			return "Selected %s." % _card_name(card)


func _start_lane_card_bob(button: Button, content_root: Control, shadow: ColorRect) -> void:
	if not is_instance_valid(button) or not is_instance_valid(content_root):
		return
	var base_y = _screen.LANE_CARD_FLOAT_OFFSET.y
	var bob_top: float = base_y - _screen.LANE_CARD_BOB_AMPLITUDE
	var bob_bottom: float = base_y
	var half = _screen.LANE_CARD_BOB_DURATION * 0.5
	var bob_tween := button.create_tween()
	bob_tween.set_loops()
	# Bob up – both offsets move together
	bob_tween.tween_property(content_root, "offset_top", bob_top, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.parallel().tween_property(content_root, "offset_bottom", bob_top, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Bob down – runs after the up phase completes
	bob_tween.tween_property(content_root, "offset_top", bob_bottom, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.parallel().tween_property(content_root, "offset_bottom", bob_bottom, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _start_hand_card_bob(button: Button, base_pos: Vector2, bob_key: String) -> void:
	if not is_instance_valid(button):
		return
	var bob_top: float = base_pos.y - _screen.HAND_CARD_BOB_AMPLITUDE
	var bob_bottom: float = base_pos.y
	var half = _screen.HAND_CARD_BOB_DURATION * 0.5
	var bob_tween = _screen.create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(button, "position:y", bob_top, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(button, "position:y", bob_bottom, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	button.set_meta(bob_key, bob_tween)
