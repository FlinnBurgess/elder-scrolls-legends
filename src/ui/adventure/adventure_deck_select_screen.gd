class_name AdventureDeckSelectScreen
extends Control

signal deck_selected(deck_data: Dictionary)
signal back_pressed

const AdventureDeckLoaderScript = preload("res://src/adventure/adventure_deck_loader.gd")
const AdventureCardPoolScript = preload("res://src/adventure/adventure_card_pool.gd")
const DeckCardListClass = preload("res://src/ui/components/deck_card_list.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")

var _deck_buttons: Array = []
var _decks: Array = []
var _selected_index := -1
var _select_button: Button
var _deck_card_list: DeckCardList
var _deck_card_list_scroll: ScrollContainer
var _card_lookup: Dictionary = {}
var _card_hover_preview_layer: Control
var _root_split: HSplitContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_card_catalog()
	_decks = AdventureDeckLoaderScript.list_player_decks()
	_build_ui()


func _build_ui() -> void:
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

	var title := Label.new()
	title.text = "Choose Your Deck"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	UITheme.style_title(title, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	root.add_child(UITheme.make_separator(0.0))

	# --- Content: deck list (left) + card preview (right) via HSplitContainer ---
	_root_split = HSplitContainer.new()
	_root_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_root_split.size_flags_vertical = SIZE_EXPAND_FILL
	_root_split.add_theme_constant_override("separation", 24)
	_root_split.resized.connect(_on_root_split_resized)
	root.add_child(_root_split)

	# Left column: deck buttons
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = SIZE_EXPAND_FILL
	left_col.size_flags_vertical = SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	_root_split.add_child(left_col)

	var deck_scroll := ScrollContainer.new()
	deck_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	deck_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	deck_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	left_col.add_child(deck_scroll)

	var deck_list := VBoxContainer.new()
	deck_list.size_flags_horizontal = SIZE_EXPAND_FILL
	deck_list.add_theme_constant_override("separation", 8)
	deck_scroll.add_child(deck_list)

	for i in range(_decks.size()):
		var deck: Dictionary = _decks[i]
		var btn := _build_deck_button(deck, i)
		deck_list.add_child(btn)
		_deck_buttons.append(btn)

	# Select button below the scroll
	_select_button = Button.new()
	_select_button.text = "Select Deck"
	_select_button.custom_minimum_size = Vector2(0, 56)
	_select_button.size_flags_horizontal = SIZE_EXPAND_FILL
	_select_button.disabled = true
	UITheme.style_button(_select_button, 22)
	_select_button.pressed.connect(_on_select_pressed)
	left_col.add_child(_select_button)

	# Right column: card list preview
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = SIZE_EXPAND_FILL
	right_col.size_flags_vertical = SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	_root_split.add_child(right_col)

	var cards_title := Label.new()
	cards_title.text = "Deck Contents"
	UITheme.style_section_label(cards_title, 20)
	right_col.add_child(cards_title)

	right_col.add_child(UITheme.make_separator(0.0))

	_deck_card_list = DeckCardListClass.new()
	_deck_card_list_scroll = _deck_card_list.create_scroll_container()
	right_col.add_child(_deck_card_list_scroll)

	# Hover preview layer (above everything)
	_card_hover_preview_layer = Control.new()
	_card_hover_preview_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_card_hover_preview_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_card_hover_preview_layer)
	_deck_card_list.enable_hover_preview(_card_hover_preview_layer, _card_lookup)

	_on_root_split_resized.call_deferred()


func _on_root_split_resized() -> void:
	if _root_split == null or _root_split.size.x <= 0:
		return
	# Positive offset pushes divider right → left bigger, right (card list) narrower
	var target := int(_root_split.size.x * 0.20)
	if _root_split.split_offset == target:
		return
	_root_split.resized.disconnect(_on_root_split_resized)
	_root_split.split_offset = target
	_root_split.resized.connect(_on_root_split_resized)


func _build_deck_button(deck: Dictionary, index: int) -> Button:
	var btn := Button.new()
	var attrs: Array = deck.get("attribute_ids", [])
	var card_count := 0
	for entry in deck.get("cards", []):
		card_count += int(entry.get("quantity", 0))
	btn.text = "%s  (%s | %d cards)" % [str(deck.get("name", "Unknown")), ", ".join(attrs), card_count]
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	UITheme.style_button(btn, 20)
	btn.pressed.connect(_on_deck_clicked.bind(index))
	return btn


func _on_deck_clicked(index: int) -> void:
	_selected_index = index
	_select_button.disabled = false
	for i in range(_deck_buttons.size()):
		var btn: Button = _deck_buttons[i]
		if i == index:
			UITheme.style_button_selected(btn)
		else:
			UITheme.style_button(btn, 20)

	# Update card list preview
	var deck: Dictionary = _decks[index]
	_deck_card_list.set_deck(deck.get("cards", []), _card_lookup)


func _on_select_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _decks.size():
		return
	deck_selected.emit(_decks[_selected_index])


func _load_card_catalog() -> void:
	var catalog := AdventureCardPoolScript._load_catalog()
	var all_cards: Array = catalog.get("cards", [])
	for card in all_cards:
		_card_lookup[str(card.get("card_id", ""))] = card
