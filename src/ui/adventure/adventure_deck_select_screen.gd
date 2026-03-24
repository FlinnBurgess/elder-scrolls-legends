class_name AdventureDeckSelectScreen
extends Control

signal deck_selected(deck_data: Dictionary)
signal back_pressed

const AdventureDeckLoaderScript = preload("res://src/adventure/adventure_deck_loader.gd")

var _deck_buttons: Array = []
var _decks: Array = []
var _selected_index := -1
var _select_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_decks = AdventureDeckLoaderScript.list_player_decks()
	_build_ui()


func _build_ui() -> void:
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(400, 0)
	center.set_anchors_and_offsets_preset(PRESET_CENTER)
	center.grow_horizontal = GROW_DIRECTION_BOTH
	center.grow_vertical = GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 12)
	add_child(center)

	var title := Label.new()
	title.text = "Choose Your Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	center.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	for i in range(_decks.size()):
		var deck: Dictionary = _decks[i]
		var btn := Button.new()
		var attrs_text := ", ".join(deck.get("attribute_ids", []))
		var card_count := 0
		for entry in deck.get("cards", []):
			card_count += int(entry.get("quantity", 0))
		btn.text = "%s  (%s | %d cards)" % [str(deck.get("name", "Unknown")), attrs_text, card_count]
		btn.custom_minimum_size = Vector2(400, 48)
		btn.pressed.connect(_on_deck_clicked.bind(i))
		center.add_child(btn)
		_deck_buttons.append(btn)

	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(0, 12)
	center.add_child(btn_spacer)

	_select_button = Button.new()
	_select_button.text = "Select Deck"
	_select_button.custom_minimum_size = Vector2(400, 52)
	_select_button.disabled = true
	_select_button.pressed.connect(_on_select_pressed)
	center.add_child(_select_button)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(400, 44)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	center.add_child(back_btn)


func _on_deck_clicked(index: int) -> void:
	_selected_index = index
	_select_button.disabled = false
	for i in range(_deck_buttons.size()):
		var btn: Button = _deck_buttons[i]
		if i == index:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.65, 1.0)
			style.border_color = Color(0.4, 0.65, 0.9, 1.0)
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", style)
		else:
			btn.remove_theme_stylebox_override("normal")


func _on_select_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _decks.size():
		return
	deck_selected.emit(_decks[_selected_index])
