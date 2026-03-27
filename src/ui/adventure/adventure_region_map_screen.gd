class_name AdventureRegionMapScreen
extends Control

signal adventure_selected(adventure: Dictionary)
signal deck_pressed
signal back_pressed

const AdventureCatalogScript = preload("res://src/adventure/adventure_catalog.gd")

var _region_data: Dictionary = {}
var _deck_id: String = ""
var _is_fallback := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func set_region(region_data: Dictionary, deck_id: String) -> void:
	_region_data = region_data
	_deck_id = deck_id
	_build_ui()


func _build_ui() -> void:
	# Try to load background image
	var bg_path: String = str(_region_data.get("background_image", ""))
	var bg_texture: Texture2D = null
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		bg_texture = load(bg_path)

	if bg_texture != null:
		_build_map_ui(bg_texture)
	else:
		_build_fallback_ui()

	# Top-right deck button
	var deck_btn := Button.new()
	deck_btn.text = "Deck"
	deck_btn.add_theme_font_size_override("font_size", 22)
	deck_btn.custom_minimum_size = Vector2(100, 44)
	deck_btn.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	deck_btn.offset_left = -116
	deck_btn.offset_top = 16
	deck_btn.offset_right = -16
	deck_btn.offset_bottom = 60
	deck_btn.pressed.connect(func() -> void: deck_pressed.emit())
	add_child(deck_btn)


func _build_map_ui(bg_texture: Texture2D) -> void:
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.773, 0.820, 0.820, 1.0)  # #C5D1D1 — matches Tamriel map edges
	bg_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	var bg := TextureRect.new()
	bg.texture = bg_texture
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(bg)

	# Place adventure buttons at specified positions
	var adventures_data: Array = _region_data.get("adventures", [])
	for entry in adventures_data:
		var adventure_id: String = str(entry.get("adventure_id", ""))
		var adventure := AdventureCatalogScript.load_adventure(adventure_id)
		if adventure.is_empty():
			continue
		if not _is_adventure_available(adventure):
			continue

		var pos: Array = entry.get("position", [0, 0])
		var btn := Button.new()
		btn.text = str(adventure.get("name", adventure_id))
		btn.add_theme_font_size_override("font_size", 22)
		btn.custom_minimum_size = Vector2(200, 48)
		btn.position = Vector2(float(pos[0]), float(pos[1]))
		# Center the button on the position
		btn.position.x -= 100
		btn.position.y -= 24
		var adv := adventure
		btn.pressed.connect(func() -> void: adventure_selected.emit(adv))
		add_child(btn)

	# Back button bottom-left
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.custom_minimum_size = Vector2(100, 44)
	back_btn.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	back_btn.offset_left = 16
	back_btn.offset_bottom = -16
	back_btn.offset_top = -60
	back_btn.offset_right = 116
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back_btn)


func _build_fallback_ui() -> void:
	_is_fallback = true
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_CENTER)
	center.grow_horizontal = GROW_DIRECTION_BOTH
	center.grow_vertical = GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	var title := Label.new()
	title.text = str(_region_data.get("name", "Region"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose an Adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	var adventures_data: Array = _region_data.get("adventures", [])
	for entry in adventures_data:
		var adventure_id: String = str(entry.get("adventure_id", ""))
		var adventure := AdventureCatalogScript.load_adventure(adventure_id)
		if adventure.is_empty():
			continue
		if not _is_adventure_available(adventure):
			continue

		var btn := Button.new()
		btn.text = str(adventure.get("name", adventure_id))
		btn.custom_minimum_size = Vector2(300, 52)
		btn.add_theme_font_size_override("font_size", 24)
		var adv := adventure
		btn.pressed.connect(func() -> void: adventure_selected.emit(adv))
		center.add_child(btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(300, 44)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	center.add_child(back_btn)


func _is_adventure_available(adventure: Dictionary) -> bool:
	var allowed_decks: Array = adventure.get("allowed_deck_ids", [])
	return allowed_decks.is_empty() or _deck_id in allowed_decks
