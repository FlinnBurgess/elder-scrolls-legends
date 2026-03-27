class_name AdventureWorldMapScreen
extends Control

signal region_selected(region_id: String)
signal deck_pressed
signal back_pressed

const AdventureCatalogScript = preload("res://src/adventure/adventure_catalog.gd")

var _regions: Array = []
var _world_config: Dictionary = {}
var _clickmap_image: Image = null
var _map_texture_rect: TextureRect = null
var _region_color_map: Dictionary = {}  # Color -> region_id
var _hover_label: Label = null
var _is_fallback := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_world_config = AdventureCatalogScript.load_world_map_config()
	_regions = AdventureCatalogScript.load_all_regions()
	_build_region_color_map()
	_build_ui()


func _build_region_color_map() -> void:
	for region in _regions:
		var color_hex: String = str(region.get("clickmap_color", ""))
		if color_hex.is_empty():
			continue
		var color := Color.from_string(color_hex, Color.TRANSPARENT)
		_region_color_map[color] = str(region.get("id", ""))


func _build_ui() -> void:
	# Try to load map image
	var map_image_path: String = str(_world_config.get("map_image", ""))
	var map_texture: Texture2D = null
	if not map_image_path.is_empty() and ResourceLoader.exists(map_image_path):
		map_texture = load(map_image_path)

	if map_texture != null:
		_build_map_ui(map_texture)
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


func _build_map_ui(map_texture: Texture2D) -> void:
	# Background color matching the map edges for seamless blending
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.773, 0.820, 0.820, 1.0)  # #C5D1D1
	bg_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	_map_texture_rect = TextureRect.new()
	_map_texture_rect.texture = map_texture
	_map_texture_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_texture_rect.gui_input.connect(_on_map_input)
	add_child(_map_texture_rect)

	# Load clickmap for hit detection
	var clickmap_path: String = str(_world_config.get("clickmap_image", ""))
	if not clickmap_path.is_empty() and ResourceLoader.exists(clickmap_path):
		var clickmap_tex: Texture2D = load(clickmap_path)
		if clickmap_tex != null:
			_clickmap_image = clickmap_tex.get_image()

	# Hover label for region name
	_hover_label = Label.new()
	_hover_label.add_theme_font_size_override("font_size", 28)
	_hover_label.add_theme_color_override("font_color", Color.WHITE)
	_hover_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	_hover_label.offset_left = 20
	_hover_label.offset_bottom = -20
	_hover_label.offset_top = -60
	_hover_label.visible = false
	add_child(_hover_label)

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
	title.text = "World Map"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a Region"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	for region in _regions:
		var region_id: String = str(region.get("id", ""))
		var region_name: String = str(region.get("name", region_id))
		var btn := Button.new()
		btn.text = region_name
		btn.custom_minimum_size = Vector2(300, 52)
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(func() -> void: region_selected.emit(region_id))
		center.add_child(btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(300, 44)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	center.add_child(back_btn)


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var region_id := _get_region_at_position(event.position)
		if not region_id.is_empty():
			region_selected.emit(region_id)
	elif event is InputEventMouseMotion:
		var region_id := _get_region_at_position(event.position)
		if not region_id.is_empty():
			var region_name := _get_region_name(region_id)
			_hover_label.text = region_name
			_hover_label.visible = true
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else:
			_hover_label.visible = false
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _get_region_at_position(local_pos: Vector2) -> String:
	if _clickmap_image == null or _map_texture_rect == null:
		return ""

	var tex_size := _map_texture_rect.texture.get_size()
	var rect_size := _map_texture_rect.size

	# Calculate the actual drawn area for STRETCH_KEEP_ASPECT_CENTERED
	var scale_factor := minf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var drawn_size := tex_size * scale_factor
	var offset := (rect_size - drawn_size) / 2.0

	var relative_pos := local_pos - offset
	if relative_pos.x < 0 or relative_pos.y < 0 or relative_pos.x >= drawn_size.x or relative_pos.y >= drawn_size.y:
		return ""

	var image_x := int(relative_pos.x / scale_factor)
	var image_y := int(relative_pos.y / scale_factor)

	if image_x < 0 or image_y < 0 or image_x >= _clickmap_image.get_width() or image_y >= _clickmap_image.get_height():
		return ""

	var pixel_color := _clickmap_image.get_pixel(image_x, image_y)

	# Find the closest region color within a maximum distance threshold
	var best_id := ""
	var best_dist := 0.15  # Max distance threshold
	for color in _region_color_map:
		var dist := _color_distance(pixel_color, color)
		if dist < best_dist:
			best_dist = dist
			best_id = _region_color_map[color]
	return best_id


func _color_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)


func _get_region_name(region_id: String) -> String:
	for region in _regions:
		if str(region.get("id", "")) == region_id:
			return str(region.get("name", region_id))
	return region_id


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
