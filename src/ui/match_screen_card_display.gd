class_name MatchScreenCardDisplay
extends RefCounted

var _screen  # MatchScreen reference

func _init(screen) -> void:
	_screen = screen


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


func _card_button_text(card: Dictionary, public_view: bool) -> String:
	if not public_view and not _overlays._is_pending_prophecy_card(card):
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
	if not public_view and not _overlays._is_pending_prophecy_card(card):
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


func _card_name(card: Dictionary) -> String:
	if card.is_empty():
		return "Unknown Card"
	var name := str(card.get("name", ""))
	if not name.is_empty():
		return name
	return _identifier_to_name(str(card.get("definition_id", card.get("instance_id", "card"))))


func _selection_prompt(card: Dictionary) -> String:
	var location := MatchMutations.find_card_location(_match_state, str(card.get("instance_id", "")))
	if _overlays._is_pending_prophecy_card(card):
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

