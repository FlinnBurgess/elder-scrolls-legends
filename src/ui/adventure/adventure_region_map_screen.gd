class_name AdventureRegionMapScreen
extends Control

signal adventure_selected(adventure: Dictionary)
signal deck_pressed
signal back_pressed

const AdventureCatalogScript = preload("res://src/adventure/adventure_catalog.gd")

const PORTRAIT_SIZE := 140
const PORTRAIT_BORDER := 8

const CIRCLE_CLIP_SHADER_CODE := "
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	if (dist > 0.5) { discard; }
	COLOR = texture(TEXTURE, UV);
}
"
var _circle_shader: Shader = null

var _region_data: Dictionary = {}
var _deck_id: String = ""
var _is_fallback := false
var _bg_texture_rect: TextureRect = null
var _adventure_markers: Array[Dictionary] = []  # [{container: Control, pos: Vector2}]


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

	_bg_texture_rect = bg
	_adventure_markers.clear()

	# Place adventure markers at normalized positions (0.0–1.0 of image)
	var adventures_data: Array = _region_data.get("adventures", [])
	for entry in adventures_data:
		var adventure_id: String = str(entry.get("adventure_id", ""))
		var adventure := AdventureCatalogScript.load_adventure(adventure_id)
		if adventure.is_empty():
			continue
		if not _is_adventure_available(adventure):
			continue

		var pos: Array = entry.get("position", [0, 0])
		var container := _create_adventure_marker(adventure)
		add_child(container)
		_adventure_markers.append({container = container, pos = Vector2(float(pos[0]), float(pos[1]))})

	_reposition_adventure_markers()
	bg.resized.connect(_reposition_adventure_markers)

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


func _create_adventure_marker(adventure: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# --- Circular portrait ---
	var outer_size := PORTRAIT_SIZE + PORTRAIT_BORDER * 2
	var portrait_btn := Button.new()
	portrait_btn.custom_minimum_size = Vector2(outer_size, outer_size)
	portrait_btn.focus_mode = Control.FOCUS_NONE

	# Style: circular with black outline
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style_normal.border_color = Color(0.0, 0.0, 0.0, 1.0)
	style_normal.border_width_left = PORTRAIT_BORDER
	style_normal.border_width_right = PORTRAIT_BORDER
	style_normal.border_width_top = PORTRAIT_BORDER
	style_normal.border_width_bottom = PORTRAIT_BORDER
	var radius := outer_size / 2
	style_normal.corner_radius_top_left = radius
	style_normal.corner_radius_top_right = radius
	style_normal.corner_radius_bottom_left = radius
	style_normal.corner_radius_bottom_right = radius

	var style_hover := style_normal.duplicate()
	style_hover.border_color = Color(0.82, 0.72, 0.50, 1.0)

	var style_pressed := style_normal.duplicate()
	style_pressed.border_color = Color(1.0, 0.82, 0.45, 1.0)

	portrait_btn.add_theme_stylebox_override("normal", style_normal)
	portrait_btn.add_theme_stylebox_override("hover", style_hover)
	portrait_btn.add_theme_stylebox_override("pressed", style_pressed)
	portrait_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Load portrait image inside the button, clipped to a circle via shader
	var portrait_path: String = str(adventure.get("portrait_image", ""))
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		var portrait_tex: Texture2D = load(portrait_path)
		var tex_rect := TextureRect.new()
		tex_rect.texture = portrait_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		tex_rect.offset_left = PORTRAIT_BORDER
		tex_rect.offset_top = PORTRAIT_BORDER
		tex_rect.offset_right = -PORTRAIT_BORDER
		tex_rect.offset_bottom = -PORTRAIT_BORDER
		if _circle_shader == null:
			_circle_shader = Shader.new()
			_circle_shader.code = CIRCLE_CLIP_SHADER_CODE
		tex_rect.material = ShaderMaterial.new()
		tex_rect.material.shader = _circle_shader
		portrait_btn.add_child(tex_rect)

	var adv := adventure
	portrait_btn.pressed.connect(func() -> void: adventure_selected.emit(adv))

	# Center the portrait button within the VBox
	portrait_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(portrait_btn)

	# --- Label panel with black background ---
	var label_panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	label_panel.add_theme_stylebox_override("panel", panel_style)
	label_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var label_vbox := VBoxContainer.new()
	label_vbox.add_theme_constant_override("separation", 2)
	label_panel.add_child(label_vbox)

	var name_label := Label.new()
	name_label.text = str(adventure.get("name", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90, 1.0))
	label_vbox.add_child(name_label)

	var difficulty: int = int(adventure.get("difficulty", 1))
	var diff_label := Label.new()
	diff_label.text = "Difficulty: %d" % difficulty
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 14)
	diff_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62, 0.9))
	label_vbox.add_child(diff_label)

	container.add_child(label_panel)

	return container


func _reposition_adventure_markers() -> void:
	if _bg_texture_rect == null or _bg_texture_rect.texture == null:
		return
	var img_rect := _get_image_display_rect(_bg_texture_rect)
	for entry in _adventure_markers:
		var container: Control = entry.container
		var npos: Vector2 = entry.pos
		var screen_pos := img_rect.position + npos * img_rect.size
		# Center horizontally on the point, align top of portrait at the point
		container.position = Vector2(screen_pos.x - container.size.x / 2.0, screen_pos.y - container.size.y / 2.0)


func _get_image_display_rect(tex_rect: TextureRect) -> Rect2:
	var control_size := tex_rect.size
	var tex_size := Vector2(tex_rect.texture.get_size())
	var scale_factor := minf(control_size.x / tex_size.x, control_size.y / tex_size.y)
	var display_size := tex_size * scale_factor
	var offset := (control_size - display_size) / 2.0
	return Rect2(offset, display_size)
