class_name MatchScreenUIBuilder
extends RefCounted

var _screen  # MatchScreen reference


# Control constants (not available on RefCounted)
const PRESET_FULL_RECT = Control.PRESET_FULL_RECT
const PRESET_TOP_LEFT = Control.PRESET_TOP_LEFT
const PRESET_TOP_RIGHT = Control.PRESET_TOP_RIGHT
const PRESET_BOTTOM_RIGHT = Control.PRESET_BOTTOM_RIGHT
const PRESET_CENTER_TOP = Control.PRESET_CENTER_TOP
const PRESET_CENTER_BOTTOM = Control.PRESET_CENTER_BOTTOM
const SIZE_EXPAND_FILL = Control.SIZE_EXPAND_FILL
const SIZE_SHRINK_CENTER = Control.SIZE_SHRINK_CENTER
const SIZE_SHRINK_END = Control.SIZE_SHRINK_END

func _init(screen) -> void:
	_screen = screen


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.name = "BoardBackground"
	bg.texture = preload("res://assets/images/board/default.png")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(bg)

	var root := MarginContainer.new()
	root.name = "MatchLayout"
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 22)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 22)
	_screen.add_child(root)
	var content := VBoxContainer.new()
	content.name = "MatchContent"
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	root.add_child(content)

	_screen._card_hover_preview_layer = Control.new()
	_screen._card_hover_preview_layer.name = "CardHoverPreviewLayer"
	_screen._card_hover_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._card_hover_preview_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(_screen._card_hover_preview_layer)

	_screen._opponent_avatar_overlay = Control.new()
	_screen._opponent_avatar_overlay.name = "OpponentAvatarOverlay"
	_screen._opponent_avatar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._opponent_avatar_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(_screen._opponent_avatar_overlay)

	_screen._player_avatar_overlay = Control.new()
	_screen._player_avatar_overlay.name = "PlayerAvatarOverlay"
	_screen._player_avatar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._player_avatar_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(_screen._player_avatar_overlay)

	_screen._opponent_hand_overlay = Control.new()
	_screen._opponent_hand_overlay.name = "OpponentHandOverlay"
	_screen._opponent_hand_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._opponent_hand_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(_screen._opponent_hand_overlay)

	_screen._local_hand_overlay = Control.new()
	_screen._local_hand_overlay.name = "LocalHandOverlay"
	_screen._local_hand_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._local_hand_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(_screen._local_hand_overlay)

	_screen._prophecy_card_overlay = Control.new()
	_screen._prophecy_card_overlay.name = "ProphecyCardOverlay"
	_screen._prophecy_card_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._prophecy_card_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen._prophecy_card_overlay.z_index = 450
	_screen.add_child(_screen._prophecy_card_overlay)

	_screen._history.container = HBoxContainer.new()
	_screen._history.container.name = "MatchHistoryRow"
	_screen._history.container.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	_screen._history.container.position = Vector2(32, 28)
	_screen._history.container.add_theme_constant_override("separation", 6)
	_screen._history.container.z_index = 100
	_screen._history.container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_screen._history.container)

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
	_screen._end_turn_button = Button.new()
	_screen._end_turn_button.text = "End Turn"
	_screen._end_turn_button.custom_minimum_size = Vector2(0, 54)
	_screen._end_turn_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_screen._end_turn_button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(_screen._end_turn_button, Color(0.25, 0.14, 0.13, 0.98), Color(0.69, 0.35, 0.27, 0.94), Color(0.98, 0.93, 0.9, 1.0))
	_screen._end_turn_button.pressed.connect(_screen._on_end_turn_pressed)

	for player_id in _screen.PLAYER_ORDER:
		var section := _build_player_section(player_id)
		_screen._player_sections[player_id] = section
		board_column.add_child(section["panel"])
		if player_id == _screen.PLAYER_ORDER[0]:
			var lanes_panel := _build_lanes_panel()
			board_column.add_child(lanes_panel)

	_screen._match_end_overlay = _build_match_end_overlay()
	root.add_child(_screen._match_end_overlay)

	_screen._pause_overlay = _build_pause_overlay()
	root.add_child(_screen._pause_overlay)

	_screen._lane_tooltip_panel = _screen._build_lane_tooltip_panel()
	_screen.add_child(_screen._lane_tooltip_panel)


func _build_player_section(player_id: String) -> Dictionary:
	var is_opponent: bool = player_id == _screen.PLAYER_ORDER[0]
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

	var avatar_component = _screen.PLAYER_AVATAR_SCENE.instantiate()
	avatar_component.name = "%s_avatar_component" % player_id
	avatar_component.custom_minimum_size = Vector2(282, 264)
	avatar_component.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar_component.gui_input.connect(_screen._on_avatar_gui_input.bind(player_id))
	avatar_component.mouse_entered.connect(_screen._on_avatar_mouse_entered.bind(player_id))
	avatar_component.mouse_exited.connect(_screen._on_avatar_mouse_exited)
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
	magicka_mount.mouse_entered.connect(_screen._on_magicka_mouse_entered.bind(player_id))
	magicka_mount.mouse_exited.connect(_screen._on_magicka_mouse_exited)
	var magicka_component = _screen.PLAYER_MAGICKA_SCENE.instantiate()
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
	ring_panel.mouse_entered.connect(_screen._on_ring_mouse_entered.bind(player_id))
	ring_panel.mouse_exited.connect(_screen._on_ring_mouse_exited)
	if not is_opponent:
		ring_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		ring_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ring_panel.gui_input.connect(_screen._on_ring_panel_input)
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
	deck_button.pressed.connect(_screen._on_pile_pressed.bind(player_id, _screen.MatchMutations.ZONE_DECK))
	deck_button.mouse_entered.connect(_screen._on_pile_mouse_entered.bind(player_id, _screen.MatchMutations.ZONE_DECK))
	deck_button.mouse_exited.connect(_screen._on_pile_mouse_exited.bind(player_id, _screen.MatchMutations.ZONE_DECK))
	pile_column.add_child(deck_button)

	var discard_button := Button.new()
	discard_button.name = "%s_discard_button" % player_id
	discard_button.custom_minimum_size = Vector2(0, 48)
	discard_button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(discard_button, Color(0.2, 0.12, 0.16, 0.98), Color(0.58, 0.32, 0.39, 0.94), Color(0.97, 0.92, 0.94, 1.0), 1, 10)
	discard_button.pressed.connect(_screen._on_pile_pressed.bind(player_id, _screen.MatchMutations.ZONE_DISCARD))
	discard_button.mouse_entered.connect(_screen._on_pile_mouse_entered.bind(player_id, _screen.MatchMutations.ZONE_DISCARD))
	discard_button.mouse_exited.connect(_screen._on_pile_mouse_exited.bind(player_id, _screen.MatchMutations.ZONE_DISCARD))
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
		_screen._end_turn_button.size_flags_horizontal = 0
		_screen._end_turn_button.custom_minimum_size = Vector2(140, 54)
		end_turn_row.add_child(_screen._end_turn_button)
		box.add_child(end_turn_row)

	var hand_row := Control.new()
	hand_row.name = "%s_hand_row" % player_id
	hand_row.clip_contents = false
	hand_row.set_meta("player_id", player_id)

	if not is_opponent and _screen._local_hand_overlay != null:
		# Local hand floats at the bottom of the screen, separate from the band layout
		hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_screen._local_hand_overlay.add_child(hand_row)
		# Re-layout hand cards when the viewport/overlay resizes
		_screen._local_hand_overlay.resized.connect(_screen._card_surface._on_hand_surface_resized.bind(hand_row))
	elif is_opponent and _screen._opponent_hand_overlay != null:
		# Opponent hand floats at the top of the screen, separate from the band layout
		hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_screen._opponent_hand_overlay.add_child(hand_row)

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
	var avatar_overlay: Control = _screen._opponent_avatar_overlay if is_opponent else _screen._player_avatar_overlay
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
	_screen._match_end_title_label = Label.new()
	_screen._match_end_title_label.name = "MatchEndTitle"
	_screen._match_end_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen._match_end_title_label.add_theme_font_size_override("font_size", 34)
	box.add_child(_screen._match_end_title_label)
	_screen._match_end_detail_label = Label.new()
	_screen._match_end_detail_label.name = "MatchEndDetailLabel"
	_screen._match_end_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen._match_end_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen._match_end_detail_label.add_theme_font_size_override("font_size", 17)
	_screen._match_end_detail_label.custom_minimum_size = Vector2(320, 0)
	box.add_child(_screen._match_end_detail_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	_screen._match_end_button = Button.new()
	_screen._match_end_button.name = "MatchEndMainMenuButton"
	_screen._match_end_button.text = "Return to Main Menu"
	_screen._match_end_button.custom_minimum_size = Vector2(280, 48)
	_screen._match_end_button.add_theme_font_size_override("font_size", 17)
	_screen._match_end_button.pressed.connect(func(): _screen.return_to_main_menu_requested.emit())
	box.add_child(_screen._match_end_button)
	_screen._match_end_box = box
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
	resume_button.pressed.connect(_screen._toggle_pause_menu)
	box.add_child(resume_button)
	if _screen._puzzle_mode:
		var retry_button := Button.new()
		retry_button.text = "Retry"
		retry_button.custom_minimum_size = Vector2(260, 48)
		retry_button.add_theme_font_size_override("font_size", 17)
		_apply_button_style(retry_button, Color(0.18, 0.18, 0.22, 0.98), Color(0.5, 0.5, 0.7, 0.94), Color(0.95, 0.95, 0.98, 1.0), 1, 12)
		retry_button.pressed.connect(func(): _screen._pause_overlay.visible = false; _screen.puzzle_retry_requested.emit())
		box.add_child(retry_button)
		var return_button := Button.new()
		return_button.text = "Return to Puzzles"
		return_button.custom_minimum_size = Vector2(260, 48)
		return_button.add_theme_font_size_override("font_size", 17)
		_apply_button_style(return_button, Color(0.22, 0.18, 0.18, 0.98), Color(0.7, 0.5, 0.5, 0.94), Color(0.98, 0.95, 0.95, 1.0), 1, 12)
		return_button.pressed.connect(func(): _screen._pause_overlay.visible = false; _screen.puzzle_return_to_select_requested.emit())
		box.add_child(return_button)
	elif _screen._arena_mode:
		var forfeit_button := Button.new()
		forfeit_button.text = "Forfeit"
		forfeit_button.custom_minimum_size = Vector2(260, 48)
		forfeit_button.add_theme_font_size_override("font_size", 17)
		_apply_button_style(forfeit_button, Color(0.6, 0.18, 0.14, 0.98), Color(0.9, 0.42, 0.42, 0.94), Color(1.0, 0.93, 0.9, 1.0), 1, 12)
		forfeit_button.pressed.connect(_screen._forfeit_match)
		box.add_child(forfeit_button)
	else:
		var menu_button := Button.new()
		menu_button.text = "Return to Menu"
		menu_button.custom_minimum_size = Vector2(260, 48)
		menu_button.add_theme_font_size_override("font_size", 17)
		_apply_button_style(menu_button, Color(0.22, 0.18, 0.18, 0.98), Color(0.7, 0.5, 0.5, 0.94), Color(0.98, 0.95, 0.95, 1.0), 1, 12)
		menu_button.pressed.connect(func(): _screen._pause_overlay.visible = false; _screen.return_to_main_menu_requested.emit())
		box.add_child(menu_button)
	return overlay


func _build_lanes_panel() -> Control:
	var lanes_row := HBoxContainer.new()
	lanes_row.name = "BattlefieldPanel"
	lanes_row.custom_minimum_size = Vector2(0, 740)
	lanes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes_row.size_flags_horizontal = SIZE_EXPAND_FILL
	lanes_row.size_flags_vertical = SIZE_EXPAND_FILL
	lanes_row.size_flags_stretch_ratio = 2.8
	lanes_row.add_theme_constant_override("separation", 18)

	var lane_list: Array = _screen._lane_entries()
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
		lane_panel.gui_input.connect(_screen._on_lane_panel_gui_input.bind(lane_id))
		lane_panel.mouse_entered.connect(_screen._on_lane_mouse_entered.bind(lane_id))
		lane_panel.mouse_exited.connect(_screen._on_lane_mouse_exited)
		lanes_row.add_child(lane_panel)
		_screen._lane_panels[lane_id] = lane_panel
		var lane_box := _build_panel_box(lane_panel, 8, 10)

		for player_id in _screen.PLAYER_ORDER:
			var row_panel := PanelContainer.new()
			row_panel.name = "%s_%s_lane_row_panel" % [lane_id, player_id]
			row_panel.custom_minimum_size = Vector2(0, 352)
			row_panel.size_flags_horizontal = SIZE_EXPAND_FILL
			row_panel.size_flags_vertical = SIZE_EXPAND_FILL
			_apply_panel_style(row_panel, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
			row_panel.gui_input.connect(_screen._on_lane_row_gui_input.bind(lane_id, player_id))
			lane_box.add_child(row_panel)
			_screen._lane_row_panels[_screen._lane_row_key(lane_id, player_id)] = row_panel
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
			_screen._lane_row_containers[_screen._lane_row_key(lane_id, player_id)] = row

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
		icon_button.mouse_entered.connect(_screen._on_lane_icon_mouse_entered.bind(lane_id, icon_button))
		icon_button.mouse_exited.connect(_screen._on_lane_icon_mouse_exited)
		icon_center.add_child(icon_button)
		_screen._lane_icon_textures[lane_id] = icon_button

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
	_screen.add_child(banner_overlay)
	var banner_center := CenterContainer.new()
	banner_center.size_flags_horizontal = SIZE_EXPAND_FILL
	banner_center.size_flags_vertical = SIZE_EXPAND_FILL
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_overlay.add_child(banner_center)
	_screen._turn_banner_panel = PanelContainer.new()
	_screen._turn_banner_panel.name = "TurnBannerPanel"
	_screen._turn_banner_panel.visible = false
	_screen._turn_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._turn_banner_panel.custom_minimum_size = Vector2(336, 72)
	banner_center.add_child(_screen._turn_banner_panel)
	var banner_box := _build_panel_box(_screen._turn_banner_panel, 10, 16)
	var banner_column := VBoxContainer.new()
	banner_column.add_theme_constant_override("separation", 3)
	banner_box.add_child(banner_column)
	_screen._turn_banner_label = Label.new()
	_screen._turn_banner_label.name = "TurnBannerLabel"
	_screen._turn_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen._turn_banner_label.add_theme_font_size_override("font_size", 28)
	banner_column.add_child(_screen._turn_banner_label)
	_screen._turn_banner_detail_label = Label.new()
	_screen._turn_banner_detail_label.name = "TurnBannerDetailLabel"
	_screen._turn_banner_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen._turn_banner_detail_label.add_theme_font_size_override("font_size", 13)
	banner_column.add_child(_screen._turn_banner_detail_label)
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
				if int(card.get("activations_this_turn", 0)) > 0 and not _screen.PersistentCardRules.can_activate_support(_screen._match_state, _screen._active_player_id(), str(card.get("instance_id", ""))):
					fill = fill.darkened(0.3)
					border = border.darkened(0.2)
		if surface == "hand" and _screen._overlays._is_pending_prophecy_card(card):
			fill = fill.lerp(Color(0.24, 0.12, 0.31, 0.99), 0.72)
			border = Color(0.93, 0.73, 0.98, 1.0)
			font_color = Color(1.0, 0.96, 1.0, 1.0)
		var draw_feedback: Dictionary = _screen._active_draw_feedback_for_instance(str(card.get("instance_id", "")))
		if surface == "hand" and not hidden and not draw_feedback.is_empty():
			if bool(draw_feedback.get("from_rune_break", false)):
				fill = fill.lerp(Color(0.33, 0.16, 0.1, 0.99), 0.56)
				border = Color(1.0, 0.78, 0.46, 1.0)
			else:
				fill = fill.lerp(Color(0.16, 0.24, 0.31, 0.99), 0.48)
				border = Color(0.66, 0.9, 1.0, 1.0)
		if surface == "lane" and str(card.get("card_type", "")) == "creature":
			if _screen.EvergreenRules.has_keyword(card, _screen.EvergreenRules.KEYWORD_GUARD):
				fill = fill.lerp(Color(0.31, 0.24, 0.14, 0.99), 0.46)
				border = border.lerp(Color(0.99, 0.85, 0.46, 1.0), 0.72)
			var readiness_state: Dictionary = _screen._creature_readiness_state(card)
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
	var interaction_state: String = _screen._lane_row_interaction_state(lane_id, player_id)
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
