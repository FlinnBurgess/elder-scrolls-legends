class_name AdventureWorldMapScreen
extends Control

signal region_selected(region_id: String)
signal deck_pressed
signal back_pressed

const AdventureCatalogScript = preload("res://src/adventure/adventure_catalog.gd")

var _regions: Array = []
var _world_config: Dictionary = {}
var _clickmap_image: Image = null
var _clickmap_texture: Texture2D = null
var _map_texture_rect: TextureRect = null
var _map_shader_material: ShaderMaterial = null
var _region_color_map: Dictionary = {}  # Color -> region_id
var _hover_label: Label = null
var _is_fallback := false
var _map_container: CenterContainer = null
var _map_texture: Texture2D = null


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _map_container != null:
		_resize_map()


func _resize_map() -> void:
	if _map_texture == null or _map_texture_rect == null:
		return
	var tex_size := _map_texture.get_size()
	var available := size
	var scale_factor := minf(available.x / tex_size.x, available.y / tex_size.y)
	var fitted := tex_size * scale_factor
	_map_texture_rect.custom_minimum_size = fitted
	_map_texture_rect.size = fitted


func _build_map_ui(map_texture: Texture2D) -> void:
	# Background color matching the map edges for seamless blending
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.773, 0.820, 0.820, 1.0)  # #C5D1D1
	bg_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg_rect)

	# Use a container to center the TextureRect at correct aspect ratio
	# so the shader UV maps 1:1 to the texture pixels
	var map_container := CenterContainer.new()
	map_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	map_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_container)

	_map_texture_rect = TextureRect.new()
	_map_texture_rect.texture = map_texture
	_map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_map_texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_texture_rect.gui_input.connect(_on_map_input)
	map_container.add_child(_map_texture_rect)

	# Size the TextureRect to fit within the screen while preserving aspect ratio
	# This is done in _notification(NOTIFICATION_RESIZED) but we need an initial call
	_map_container = map_container
	_map_texture = map_texture
	call_deferred("_resize_map")

	# Load clickmap for hit detection and hover shader
	var clickmap_path: String = str(_world_config.get("clickmap_image", ""))
	print("[WorldMap] clickmap_path: ", clickmap_path, " exists: ", ResourceLoader.exists(clickmap_path))
	if not clickmap_path.is_empty() and ResourceLoader.exists(clickmap_path):
		_clickmap_texture = load(clickmap_path)
		print("[WorldMap] clickmap_texture loaded: ", _clickmap_texture != null)
		if _clickmap_texture != null:
			_clickmap_image = _clickmap_texture.get_image()
			print("[WorldMap] clickmap_image size: ", _clickmap_image.get_width(), "x", _clickmap_image.get_height())
			_setup_hover_shader()
			print("[WorldMap] shader material assigned: ", _map_texture_rect.material != null)

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


func _setup_hover_shader() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D clickmap : filter_nearest;
uniform vec3 hover_color;
uniform float hover_active;
uniform float saturate_strength : hint_range(0.0, 3.0) = 1.5;
uniform float color_tolerance : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec4 map_color = texture(TEXTURE, UV);
	vec3 final_rgb = map_color.rgb;
	if (hover_active >= 0.5) {
		vec3 click_sample = texture(clickmap, UV).rgb;
		float dist = distance(click_sample, hover_color);
		if (dist < color_tolerance) {
			float grey = dot(map_color.rgb, vec3(0.299, 0.587, 0.114));
			final_rgb = map_color.rgb + (map_color.rgb - vec3(grey)) * saturate_strength;
			final_rgb = clamp(final_rgb, 0.0, 1.0);
		}
	}
	COLOR = vec4(final_rgb, map_color.a);
}
"""
	_map_shader_material = ShaderMaterial.new()
	_map_shader_material.shader = shader
	_map_shader_material.set_shader_parameter("clickmap", _clickmap_texture)
	_map_shader_material.set_shader_parameter("hover_color", Vector3(0, 0, 0))
	_map_shader_material.set_shader_parameter("hover_active", 0.0)
	_map_texture_rect.material = _map_shader_material


func _set_hover_region(region_id: String) -> void:
	if _map_shader_material == null:
		print("[WorldMap] _set_hover_region: shader material is null!")
		return
	if region_id.is_empty():
		_map_shader_material.set_shader_parameter("hover_active", 0.0)
	else:
		# Find the clickmap color for this region
		# Convert sRGB -> linear to match source_color sampler conversion
		for color in _region_color_map:
			if _region_color_map[color] == region_id:
				_map_shader_material.set_shader_parameter("hover_color", Vector3(color.r, color.g, color.b))
				_map_shader_material.set_shader_parameter("hover_active", 1.0)
				break


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
			_set_hover_region(region_id)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else:
			_hover_label.visible = false
			_set_hover_region("")
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _get_region_at_position(local_pos: Vector2) -> String:
	if _clickmap_image == null or _map_texture_rect == null:
		return ""

	var rect_size := _map_texture_rect.size
	if rect_size.x <= 0 or rect_size.y <= 0:
		return ""

	# TextureRect is sized to fit, so local_pos maps directly via UV
	var uv_x := local_pos.x / rect_size.x
	var uv_y := local_pos.y / rect_size.y
	if uv_x < 0.0 or uv_y < 0.0 or uv_x > 1.0 or uv_y > 1.0:
		return ""

	var image_x := int(uv_x * _clickmap_image.get_width())
	var image_y := int(uv_y * _clickmap_image.get_height())

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
