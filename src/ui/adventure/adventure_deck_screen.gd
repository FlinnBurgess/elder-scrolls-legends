class_name AdventureDeckScreen
extends Control

signal begin_adventure_pressed
signal switch_deck_pressed
signal back_pressed
signal relic_equipped(relic_id: String)
signal relic_unequipped(relic_id: String)
signal view_progression_pressed

const RelicCatalogScript = preload("res://src/adventure/relic_catalog.gd")
const AdventureCardPoolScript = preload("res://src/adventure/adventure_card_pool.gd")
const AugmentRulesScript = preload("res://src/adventure/augment_rules.gd")
const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")
const DeckCardListClass = preload("res://src/ui/components/deck_card_list.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")

var _deck_data: Dictionary = {}
var _level: int = 0
var _xp_info: Dictionary = {}
var _star_powers: Array = []
var _relic_slot_count: int = 0
var _equipped_relics: Array = []
var _unlocked_relics: Array = []
var _effective_cards: Array = []
var _permanent_augments: Array = []

var _is_built := false
var _title_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_text_label: Label
var _star_container: HBoxContainer
var _relic_container: HBoxContainer
var _deck_card_list: DeckCardList
var _card_hover_preview_layer: Control
var _card_lookup: Dictionary = {}
var _augment_map: Dictionary = {}
var _view_only := false
var _begin_row: HBoxContainer = null
var _root_split: HSplitContainer


func set_view_only(enabled: bool) -> void:
	_view_only = enabled
	if _begin_row != null:
		_begin_row.visible = not _view_only


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_card_catalog()
	_build_ui()


func set_deck_data(
	deck_data: Dictionary,
	level: int,
	xp_info: Dictionary,
	star_powers: Array,
	relic_slot_count: int,
	equipped_relics: Array,
	unlocked_relics: Array,
	effective_cards: Array,
	permanent_augments: Array,
) -> void:
	_deck_data = deck_data
	_level = level
	_xp_info = xp_info
	_star_powers = star_powers
	_relic_slot_count = relic_slot_count
	_equipped_relics = equipped_relics
	_unlocked_relics = unlocked_relics
	_effective_cards = effective_cards
	_permanent_augments = permanent_augments
	_refresh()


func _refresh() -> void:
	if not _is_built:
		return
	_title_label.text = str(_deck_data.get("name", "Unknown Deck"))
	_level_label.text = "Level %d" % _level
	_refresh_xp_bar()
	_refresh_stars()
	_refresh_relics()
	_refresh_card_list()


func _build_ui() -> void:
	_is_built = true

	UITheme.add_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# --- Header ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 56)
	UITheme.style_button(back_btn, 22, true)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	_title_label = Label.new()
	_title_label.text = "Deck Name"
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	UITheme.style_title(_title_label, 40)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(_title_label)

	root.add_child(UITheme.make_separator(0.0))

	# --- Content: HSplitContainer ---
	_root_split = HSplitContainer.new()
	_root_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_root_split.size_flags_vertical = SIZE_EXPAND_FILL
	_root_split.add_theme_constant_override("separation", 24)
	_root_split.resized.connect(_on_root_split_resized)
	root.add_child(_root_split)

	# --- Left column: deck info, stars, relics, buttons ---
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = SIZE_EXPAND_FILL
	left_col.size_flags_vertical = SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 12)
	_root_split.add_child(left_col)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	left_col.add_child(left_scroll)

	var left_content := VBoxContainer.new()
	left_content.size_flags_horizontal = SIZE_EXPAND_FILL
	left_content.add_theme_constant_override("separation", 12)
	left_scroll.add_child(left_content)

	# Level + XP
	_level_label = Label.new()
	_level_label.text = "Level 0"
	UITheme.style_section_label(_level_label, 28)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left_content.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 28)
	_xp_bar.show_percentage = false
	left_content.add_child(_xp_bar)

	_xp_text_label = Label.new()
	_xp_text_label.text = ""
	_xp_text_label.add_theme_font_size_override("font_size", 20)
	_xp_text_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	left_content.add_child(_xp_text_label)

	var progression_btn := Button.new()
	progression_btn.text = "View Progression"
	progression_btn.custom_minimum_size = Vector2(220, 52)
	UITheme.style_button(progression_btn, 20)
	progression_btn.pressed.connect(func() -> void: view_progression_pressed.emit())
	left_content.add_child(progression_btn)

	left_content.add_child(UITheme.make_separator(0.0))

	# Star powers section
	var star_header := Label.new()
	star_header.text = "Star Powers"
	UITheme.style_title(star_header, 24)
	left_content.add_child(star_header)

	_star_container = HBoxContainer.new()
	_star_container.add_theme_constant_override("separation", 12)
	_star_container.alignment = BoxContainer.ALIGNMENT_CENTER
	left_content.add_child(_star_container)

	left_content.add_child(UITheme.make_separator(0.0))

	# Relics section
	var relic_header := Label.new()
	relic_header.text = "Relics"
	UITheme.style_title(relic_header, 24)
	left_content.add_child(relic_header)

	_relic_container = HBoxContainer.new()
	_relic_container.add_theme_constant_override("separation", 12)
	_relic_container.alignment = BoxContainer.ALIGNMENT_CENTER
	left_content.add_child(_relic_container)

	# Buttons at bottom of left column (outside scroll)
	left_col.add_child(UITheme.make_separator(0.0))

	var btn_container := VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 12)
	left_col.add_child(btn_container)

	_begin_row = HBoxContainer.new()
	_begin_row.visible = not _view_only
	btn_container.add_child(_begin_row)
	var begin_btn := Button.new()
	begin_btn.text = "Begin Adventure"
	begin_btn.custom_minimum_size = Vector2(280, 56)
	UITheme.style_button(begin_btn, 22)
	begin_btn.pressed.connect(func() -> void: begin_adventure_pressed.emit())
	_begin_row.add_child(begin_btn)

	# --- Right column: card list ---
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = SIZE_EXPAND_FILL
	right_col.size_flags_vertical = SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	_root_split.add_child(right_col)

	var card_header := Label.new()
	card_header.text = "Deck Cards"
	UITheme.style_title(card_header, 24)
	right_col.add_child(card_header)

	right_col.add_child(UITheme.make_separator(0.0))

	_deck_card_list = DeckCardListClass.new()
	var deck_scroll := _deck_card_list.create_scroll_container()
	right_col.add_child(deck_scroll)

	var switch_btn := Button.new()
	switch_btn.text = "Switch Deck"
	switch_btn.custom_minimum_size = Vector2(240, 52)
	UITheme.style_button(switch_btn, 20)
	switch_btn.pressed.connect(func() -> void: switch_deck_pressed.emit())
	right_col.add_child(switch_btn)

	# Card hover preview layer
	_card_hover_preview_layer = Control.new()
	_card_hover_preview_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_card_hover_preview_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_card_hover_preview_layer)
	_deck_card_list.enable_hover_preview(_card_hover_preview_layer, _card_lookup)
	_deck_card_list.set_relationship_context_callback(_build_relationship_context)

	_on_root_split_resized.call_deferred()
	_refresh()


func _on_root_split_resized() -> void:
	if _root_split == null or _root_split.size.x <= 0:
		return
	var target := int(_root_split.size.x * 0.20)
	if _root_split.split_offset == target:
		return
	_root_split.resized.disconnect(_on_root_split_resized)
	_root_split.split_offset = target
	_root_split.resized.connect(_on_root_split_resized)


# --- XP Bar ---

func _refresh_xp_bar() -> void:
	if _xp_info.get("is_max", false):
		_xp_bar.value = 100
		_xp_bar.max_value = 100
		_xp_text_label.text = "MAX LEVEL"
	else:
		_xp_bar.max_value = int(_xp_info.get("xp_needed", 1))
		_xp_bar.value = int(_xp_info.get("xp_into_level", 0))
		_xp_text_label.text = "%d / %d XP" % [
			int(_xp_info.get("xp_into_level", 0)),
			int(_xp_info.get("xp_needed", 1)),
		]


# --- Star Powers ---

func _refresh_stars() -> void:
	_clear_children(_star_container)
	for i in range(3):
		var star_panel := PanelContainer.new()
		star_panel.custom_minimum_size = Vector2(210, 120)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(16)
		style.set_border_width_all(2)
		if i < _star_powers.size():
			style.bg_color = Color(0.14, 0.13, 0.1, 1.0)
			style.border_color = UITheme.GOLD
		else:
			style.bg_color = UITheme.PANEL_BG
			style.border_color = Color(0.3, 0.3, 0.35, 0.5)
		star_panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		star_panel.add_child(vbox)

		var star_label := Label.new()
		star_label.add_theme_font_size_override("font_size", 20)
		if i < _star_powers.size():
			star_label.text = str(_star_powers[i].get("name", "Star %d" % (i + 1)))
			star_label.add_theme_color_override("font_color", UITheme.GOLD)
		else:
			star_label.text = "Locked"
			star_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(star_label)

		if i < _star_powers.size():
			var desc_label := Label.new()
			desc_label.text = str(_star_powers[i].get("description", ""))
			desc_label.add_theme_font_size_override("font_size", 18)
			desc_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(desc_label)

		_star_container.add_child(star_panel)


# --- Relics ---

func _refresh_relics() -> void:
	_clear_children(_relic_container)
	for i in range(3):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(210, 120)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(16)
		style.set_border_width_all(2)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		if i >= _relic_slot_count:
			# Locked slot
			style.bg_color = UITheme.PANEL_BG
			style.border_color = Color(0.3, 0.3, 0.35, 0.5)
			var slot_label := Label.new()
			slot_label.text = "Locked"
			slot_label.add_theme_font_size_override("font_size", 22)
			slot_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(slot_label)
		elif i < _equipped_relics.size():
			# Equipped relic
			style.bg_color = Color(0.12, 0.14, 0.2, 1.0)
			style.border_color = Color(0.5, 0.65, 0.9, 1.0)
			var relic_id: String = str(_equipped_relics[i])
			var relic := RelicCatalogScript.get_relic(relic_id)

			var name_label := Label.new()
			name_label.text = str(relic.get("name", relic_id))
			name_label.add_theme_font_size_override("font_size", 22)
			name_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(name_label)

			var desc := Label.new()
			desc.text = str(relic.get("description", ""))
			desc.add_theme_font_size_override("font_size", 18)
			desc.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(desc)

			var unequip_btn := Button.new()
			unequip_btn.text = "Remove"
			unequip_btn.custom_minimum_size = Vector2(110, 40)
			UITheme.style_button_accent(unequip_btn, Color(0.84, 0.39, 0.31, 1.0), 18)
			unequip_btn.pressed.connect(func() -> void: relic_unequipped.emit(relic_id))
			vbox.add_child(unequip_btn)
		else:
			# Empty unlocked slot
			style.bg_color = UITheme.PANEL_BG
			style.border_color = UITheme.PANEL_BORDER
			var slot_label := Label.new()
			slot_label.text = "Empty"
			slot_label.add_theme_font_size_override("font_size", 22)
			slot_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(slot_label)

			# Show equippable relics not already equipped
			for relic_id in _unlocked_relics:
				if relic_id in _equipped_relics:
					continue
				var relic := RelicCatalogScript.get_relic(str(relic_id))
				var equip_btn := Button.new()
				equip_btn.text = str(relic.get("name", relic_id))
				equip_btn.custom_minimum_size = Vector2(120, 36)
				UITheme.style_button(equip_btn, 18)
				var rid := str(relic_id)
				equip_btn.pressed.connect(func() -> void: relic_equipped.emit(rid))
				vbox.add_child(equip_btn)

		slot_panel.add_theme_stylebox_override("panel", style)
		slot_panel.add_child(vbox)
		_relic_container.add_child(slot_panel)


# --- Card List ---

func _refresh_card_list() -> void:
	_augment_map = AugmentRulesScript.build_augment_map(_permanent_augments)
	_deck_card_list.set_deck(_effective_cards, _card_lookup)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
		pass


# --- Helpers ---

func _load_card_catalog() -> void:
	var catalog := AdventureCardPoolScript._load_catalog()
	var all_cards: Array = catalog.get("cards", [])
	for card in all_cards:
		_card_lookup[str(card.get("card_id", ""))] = card


func _build_relationship_context() -> Dictionary:
	var deck_cards: Array = []
	for card_entry in _effective_cards:
		var card_id := str(card_entry.get("card_id", ""))
		var card: Dictionary = _card_lookup.get(card_id, {})
		if card.is_empty():
			continue
		var qty := int(card_entry.get("quantity", 1))
		for i in range(qty):
			deck_cards.append(card)
	return {"zone": "deck_editor", "deck_cards": deck_cards}


func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()
