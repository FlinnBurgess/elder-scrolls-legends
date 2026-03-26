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
var _card_list_container: VBoxContainer
var _card_preview_container: CenterContainer
var _card_preview: Control = null  # CardDisplayComponent
var _card_lookup: Dictionary = {}
var _augment_map: Dictionary = {}  # card_id -> [augment dicts], cached for hover


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

	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	main_hbox.set_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 16)
	main_hbox.add_theme_constant_override("separation", 16)
	add_child(main_hbox)

	# --- Left panel: Deck info, stars, relics, buttons ---
	# Use an outer HBox with spacers to center content at ~60% width
	var left_outer := HBoxContainer.new()
	left_outer.size_flags_horizontal = SIZE_EXPAND_FILL
	left_outer.size_flags_vertical = SIZE_EXPAND_FILL
	main_hbox.add_child(left_outer)

	var left_spacer_l := Control.new()
	left_spacer_l.size_flags_horizontal = SIZE_EXPAND_FILL
	left_spacer_l.size_flags_stretch_ratio = 0.2
	left_outer.add_child(left_spacer_l)

	var left_margin := MarginContainer.new()
	left_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	left_margin.size_flags_vertical = SIZE_EXPAND_FILL
	left_margin.size_flags_stretch_ratio = 0.6
	left_margin.add_theme_constant_override("margin_top", 32)
	left_margin.add_theme_constant_override("margin_bottom", 32)
	left_outer.add_child(left_margin)

	var left_spacer_r := Control.new()
	left_spacer_r.size_flags_horizontal = SIZE_EXPAND_FILL
	left_spacer_r.size_flags_stretch_ratio = 0.2
	left_outer.add_child(left_spacer_r)

	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	left_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	left_panel.add_theme_constant_override("separation", 12)
	left_margin.add_child(left_panel)

	_title_label = Label.new()
	_title_label.text = "Deck Name"
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(_title_label)

	# Level + XP bar
	_level_label = Label.new()
	_level_label.text = "Level 0"
	_level_label.add_theme_font_size_override("font_size", 34)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 36)
	_xp_bar.show_percentage = false
	left_panel.add_child(_xp_bar)

	_xp_text_label = Label.new()
	_xp_text_label.text = ""
	_xp_text_label.add_theme_font_size_override("font_size", 24)
	_xp_text_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	_xp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(_xp_text_label)

	var progression_btn_row := HBoxContainer.new()
	progression_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left_panel.add_child(progression_btn_row)
	var progression_btn := Button.new()
	progression_btn.text = "View Progression"
	progression_btn.add_theme_font_size_override("font_size", 22)
	progression_btn.custom_minimum_size = Vector2(0, 44)
	progression_btn.pressed.connect(func() -> void: view_progression_pressed.emit())
	progression_btn_row.add_child(progression_btn)

	# Section spacer before star powers
	var sp_spacer := Control.new()
	sp_spacer.custom_minimum_size = Vector2(0, 28)
	left_panel.add_child(sp_spacer)

	# Star powers section
	var star_header := Label.new()
	star_header.text = "Star Powers"
	star_header.add_theme_font_size_override("font_size", 32)
	star_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(star_header)

	_star_container = HBoxContainer.new()
	_star_container.add_theme_constant_override("separation", 16)
	_star_container.alignment = BoxContainer.ALIGNMENT_CENTER
	left_panel.add_child(_star_container)

	# Section spacer before relics
	var relic_spacer := Control.new()
	relic_spacer.custom_minimum_size = Vector2(0, 28)
	left_panel.add_child(relic_spacer)

	# Relics section
	var relic_header := Label.new()
	relic_header.text = "Relics"
	relic_header.add_theme_font_size_override("font_size", 32)
	relic_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(relic_header)

	_relic_container = HBoxContainer.new()
	_relic_container.add_theme_constant_override("separation", 20)
	_relic_container.alignment = BoxContainer.ALIGNMENT_CENTER
	left_panel.add_child(_relic_container)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	left_panel.add_child(spacer)

	# Buttons — centered, not full width
	var btn_container := VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 12)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	left_panel.add_child(btn_container)

	var begin_row := HBoxContainer.new()
	begin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(begin_row)
	var begin_btn := Button.new()
	begin_btn.text = "Begin Adventure"
	begin_btn.add_theme_font_size_override("font_size", 26)
	begin_btn.custom_minimum_size = Vector2(280, 60)
	begin_btn.pressed.connect(func() -> void: begin_adventure_pressed.emit())
	begin_row.add_child(begin_btn)

	var switch_row := HBoxContainer.new()
	switch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(switch_row)
	var switch_btn := Button.new()
	switch_btn.text = "Switch Deck"
	switch_btn.add_theme_font_size_override("font_size", 24)
	switch_btn.custom_minimum_size = Vector2(240, 52)
	switch_btn.pressed.connect(func() -> void: switch_deck_pressed.emit())
	switch_row.add_child(switch_btn)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(back_row)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.custom_minimum_size = Vector2(200, 48)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	back_row.add_child(back_btn)

	# --- Right panel: Card list ---
	var right_panel := VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(350, 0)
	right_panel.size_flags_horizontal = SIZE_FILL
	right_panel.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right_panel)

	var card_header := Label.new()
	card_header.text = "Deck Cards"
	card_header.add_theme_font_size_override("font_size", 28)
	right_panel.add_child(card_header)

	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(card_scroll)

	_card_list_container = VBoxContainer.new()
	_card_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_card_list_container.add_theme_constant_override("separation", 2)
	card_scroll.add_child(_card_list_container)

	# --- Floating card preview (overlay, doesn't take layout space) ---
	_card_preview_container = CenterContainer.new()
	_card_preview_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_card_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_preview_container.visible = false
	add_child(_card_preview_container)

	_refresh()


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
		star_panel.custom_minimum_size = Vector2(200, 100)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(16)
		if i < _star_powers.size():
			style.bg_color = Color(0.3, 0.25, 0.1, 1.0)
			style.border_color = Color(0.85, 0.7, 0.3, 1.0)
		else:
			style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
			style.border_color = Color(0.3, 0.3, 0.35, 1.0)
		style.set_border_width_all(2)
		star_panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		star_panel.add_child(vbox)

		var star_label := Label.new()
		star_label.add_theme_font_size_override("font_size", 22)
		if i < _star_powers.size():
			star_label.text = str(_star_powers[i].get("name", "Star %d" % (i + 1)))
			star_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38, 1.0))
		else:
			star_label.text = "Locked"
			star_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1.0))
		vbox.add_child(star_label)

		if i < _star_powers.size():
			var desc_label := Label.new()
			desc_label.text = str(_star_powers[i].get("description", ""))
			desc_label.add_theme_font_size_override("font_size", 18)
			desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
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
			style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
			style.border_color = Color(0.25, 0.25, 0.3, 1.0)
			var slot_label := Label.new()
			slot_label.text = "Locked"
			slot_label.add_theme_font_size_override("font_size", 24)
			slot_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1.0))
			slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(slot_label)
		elif i < _equipped_relics.size():
			# Equipped relic
			style.bg_color = Color(0.15, 0.2, 0.3, 1.0)
			style.border_color = Color(0.5, 0.65, 0.9, 1.0)
			var relic_id: String = str(_equipped_relics[i])
			var relic := RelicCatalogScript.get_relic(relic_id)

			var name_label := Label.new()
			name_label.text = str(relic.get("name", relic_id))
			name_label.add_theme_font_size_override("font_size", 24)
			name_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(name_label)

			var desc := Label.new()
			desc.text = str(relic.get("description", ""))
			desc.add_theme_font_size_override("font_size", 18)
			desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
			desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(desc)

			var unequip_btn := Button.new()
			unequip_btn.text = "Remove"
			unequip_btn.add_theme_font_size_override("font_size", 18)
			unequip_btn.custom_minimum_size = Vector2(110, 0)
			unequip_btn.pressed.connect(func() -> void: relic_unequipped.emit(relic_id))
			vbox.add_child(unequip_btn)
		else:
			# Empty unlocked slot
			style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
			style.border_color = Color(0.3, 0.3, 0.35, 1.0)
			var slot_label := Label.new()
			slot_label.text = "Empty"
			slot_label.add_theme_font_size_override("font_size", 24)
			slot_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
			slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(slot_label)

			# Show equippable relics not already equipped
			for relic_id in _unlocked_relics:
				if relic_id in _equipped_relics:
					continue
				var relic := RelicCatalogScript.get_relic(str(relic_id))
				var equip_btn := Button.new()
				equip_btn.text = str(relic.get("name", relic_id))
				equip_btn.add_theme_font_size_override("font_size", 18)
				equip_btn.custom_minimum_size = Vector2(120, 0)
				var rid := str(relic_id)
				equip_btn.pressed.connect(func() -> void: relic_equipped.emit(rid))
				vbox.add_child(equip_btn)

		slot_panel.add_theme_stylebox_override("panel", style)
		slot_panel.add_child(vbox)
		_relic_container.add_child(slot_panel)


# --- Card List ---

func _refresh_card_list() -> void:
	_clear_children(_card_list_container)

	# Build augment lookup for display and hover preview
	_augment_map = AugmentRulesScript.build_augment_map(_permanent_augments)
	var augment_map := _augment_map

	# Collect and sort cards
	var entries: Array = []
	for card_entry in _effective_cards:
		var card_id := str(card_entry.get("card_id", ""))
		var card: Dictionary = _card_lookup.get(card_id, {})
		if card.is_empty():
			continue
		entries.append({
			"card_id": card_id,
			"name": str(card.get("name", card_id)),
			"cost": int(card.get("cost", 0)),
			"quantity": int(card_entry.get("quantity", 1)),
			"attributes": card.get("attributes", []),
			"has_augment": augment_map.has(card_id),
		})
	entries.sort_custom(func(a, b):
		if a["cost"] != b["cost"]:
			return a["cost"] < b["cost"]
		return a["name"].to_lower() < b["name"].to_lower()
	)

	for entry in entries:
		_card_list_container.add_child(_build_card_row(entry))

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards in deck"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_card_list_container.add_child(empty_label)


func _build_card_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 48)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_id_for_hover: String = str(entry.get("card_id", ""))
	row.mouse_entered.connect(_on_card_row_hover.bind(card_id_for_hover))
	row.mouse_exited.connect(_on_card_row_hover_exit)

	# Cost badge
	var cost_badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.set_corner_radius_all(12)
	badge_style.set_content_margin_all(0)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	badge_style.bg_color = _get_cost_badge_color(entry.get("attributes", []))
	cost_badge.add_theme_stylebox_override("panel", badge_style)
	cost_badge.custom_minimum_size = Vector2(42, 36)
	var cost_label := Label.new()
	cost_label.text = str(entry["cost"])
	cost_label.add_theme_font_size_override("font_size", 22)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_label)
	row.add_child(cost_badge)

	# Card name
	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	# Augment indicator
	if entry.get("has_augment", false):
		var aug_label := Label.new()
		aug_label.text = "[A]"
		aug_label.add_theme_font_size_override("font_size", 22)
		aug_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
		row.add_child(aug_label)

	# Quantity
	var qty_label := Label.new()
	qty_label.text = "x%d" % entry["quantity"]
	qty_label.add_theme_font_size_override("font_size", 22)
	qty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	row.add_child(qty_label)

	return row


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if (event.keycode == KEY_UP or event.keycode == KEY_DOWN) and _card_preview != null and is_instance_valid(_card_preview):
		if _card_preview.has_method("cycle_relationship"):
			var direction := 1 if event.keycode == KEY_DOWN else -1
			_card_preview.cycle_relationship(direction)
			get_viewport().set_input_as_handled()


# --- Card Hover Preview ---

func _on_card_row_hover(card_id: String) -> void:
	var card: Dictionary = _card_lookup.get(card_id, {})
	if card.is_empty():
		return
	# Deep copy so augment application doesn't modify the cached catalog entry
	var display_card := card.duplicate(true)
	# Apply permanent augments if any
	if _augment_map.has(card_id):
		AugmentRulesScript.apply_augments_to_card(display_card, _augment_map[card_id])
	_show_card_preview(display_card)


func _on_card_row_hover_exit() -> void:
	_hide_card_preview()


func _show_card_preview(card: Dictionary) -> void:
	_hide_card_preview()
	var preview := CardDisplayComponentClass.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_preview_container.add_child(preview)
	preview.apply_card(card, CardDisplayComponentClass.PRESENTATION_FULL)
	preview.set_relationship_context(_build_relationship_context())
	preview.set_interactive(false)
	var card_height := 760.0
	var card_width := card_height / (384.0 / 220.0)
	preview.custom_minimum_size = Vector2(card_width, card_height)
	preview.size = Vector2(card_width, card_height)
	_card_preview = preview
	_card_preview_container.visible = true


func _hide_card_preview() -> void:
	if _card_preview != null:
		_card_preview.queue_free()
		_card_preview = null
	_card_preview_container.visible = false


# --- Helpers ---

const _ATTRIBUTE_COLORS := {
	"strength": Color(0.75, 0.22, 0.17, 1.0),
	"intelligence": Color(0.2, 0.35, 0.7, 1.0),
	"willpower": Color(0.78, 0.68, 0.22, 1.0),
	"agility": Color(0.2, 0.55, 0.25, 1.0),
	"endurance": Color(0.45, 0.25, 0.6, 1.0),
	"neutral": Color(0.4, 0.4, 0.4, 1.0),
}


func _get_cost_badge_color(attributes: Array) -> Color:
	if attributes.is_empty():
		return Color(0.3, 0.3, 0.3, 1.0)
	var attr := str(attributes[0]).to_lower()
	return _ATTRIBUTE_COLORS.get(attr, Color(0.3, 0.3, 0.3, 1.0))


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
