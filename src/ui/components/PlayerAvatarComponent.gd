class_name PlayerAvatarComponent
extends Control

const DEFAULT_RUNE_THRESHOLDS := [25, 20, 15, 10, 5]
const DEFAULT_PORTRAIT := preload("res://assets/images/portraits/placeholder.png")
const PRESENTATION_LOCAL_BOTTOM := 0
const PRESENTATION_OPPONENT_TOP := 1
const RECOMMENDED_MINIMUM_SIZE := Vector2(188, 176)
const MEDALLION_MAX_SIZE := 188.0
const BADGE_WIDTH_RATIO := 0.48
const BADGE_HEIGHT_RATIO := 0.34
const RUNE_SIZE_RATIO := 0.17
const RUNE_ORBIT_RATIO := 0.58
const PORTRAIT_MASK_SHADER_CODE := """
shader_type canvas_item;

uniform float feather = 0.02;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float distance_from_center = distance(UV, vec2(0.5));
	float alpha_mask = 1.0 - smoothstep(0.5 - feather, 0.5, distance_from_center);
	COLOR = vec4(tex.rgb, tex.a * alpha_mask);
}
"""

var _portrait_texture: Texture2D = DEFAULT_PORTRAIT
var _presentation_mode := PRESENTATION_LOCAL_BOTTOM
var _health := 30
var _active_rune_thresholds := PackedInt32Array(DEFAULT_RUNE_THRESHOLDS)
var _is_built := false

var _content_root: Control
var _medallion_outer: PanelContainer
var _medallion_inner: PanelContainer
var _portrait_backdrop: PanelContainer
var _portrait_rect: TextureRect
var _health_badge: PanelContainer
var _health_value_label: Label
var _health_caption_label: Label
var _rune_entries: Array = []
var _portrait_material: ShaderMaterial

@export var portrait_texture: Texture2D = DEFAULT_PORTRAIT:
	set(value):
		_portrait_texture = value if value != null else DEFAULT_PORTRAIT
		_refresh_portrait()
	get:
		return _portrait_texture

@export_enum("Local Bottom", "Opponent Top") var presentation_mode: int = PRESENTATION_LOCAL_BOTTOM:
	set(value):
		_presentation_mode = PRESENTATION_OPPONENT_TOP if value == PRESENTATION_OPPONENT_TOP else PRESENTATION_LOCAL_BOTTOM
		_refresh_presentation()
		_layout_internal_nodes()
	get:
		return _presentation_mode

@export var health: int = 30:
	set(value):
		_health = maxi(0, value)
		_refresh_health()
	get:
		return _health

@export var active_rune_thresholds: PackedInt32Array = PackedInt32Array(DEFAULT_RUNE_THRESHOLDS):
	set(value):
		_active_rune_thresholds = _normalize_rune_thresholds(value)
		_refresh_runes()
	get:
		return PackedInt32Array(_active_rune_thresholds)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = RECOMMENDED_MINIMUM_SIZE
	if size == Vector2.ZERO:
		size = custom_minimum_size
	if not _is_built:
		_build_internal_nodes()
	_refresh_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _is_built:
		_layout_internal_nodes()


func set_portrait(texture: Texture2D) -> void:
	portrait_texture = texture


func set_presentation(value: int) -> void:
	presentation_mode = value


func set_is_opponent(value: bool) -> void:
	presentation_mode = PRESENTATION_OPPONENT_TOP if value else PRESENTATION_LOCAL_BOTTOM


func is_opponent() -> bool:
	return presentation_mode == PRESENTATION_OPPONENT_TOP


func set_health_value(value: int) -> void:
	health = value


func set_rune_thresholds(thresholds) -> void:
	active_rune_thresholds = _normalize_rune_thresholds(thresholds)


func get_rune_states() -> Array:
	var states: Array = []
	for threshold in DEFAULT_RUNE_THRESHOLDS:
		states.append(_active_rune_thresholds.has(threshold))
	return states


func get_rune_anchor(threshold: int) -> Control:
	for rune_entry in _rune_entries:
		if int(rune_entry.get("threshold", -1)) == threshold:
			return rune_entry.get("panel") as Control
	return null


func apply_player_state(player: Dictionary, is_opponent_presentation := false, portrait: Texture2D = null) -> void:
	health = int(player.get("health", _health))
	active_rune_thresholds = _normalize_rune_thresholds(player.get("rune_thresholds", DEFAULT_RUNE_THRESHOLDS))
	set_is_opponent(is_opponent_presentation)
	if portrait != null:
		portrait_texture = portrait


func _build_internal_nodes() -> void:
	_content_root = Control.new()
	_content_root.name = "ContentRoot"
	_content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(_content_root)
	add_child(_content_root)

	_medallion_outer = PanelContainer.new()
	_medallion_outer.name = "MedallionOuter"
	_medallion_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_root.add_child(_medallion_outer)

	_medallion_inner = PanelContainer.new()
	_medallion_inner.name = "MedallionInner"
	_medallion_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(_medallion_inner, 10)
	_medallion_outer.add_child(_medallion_inner)

	_portrait_backdrop = PanelContainer.new()
	_portrait_backdrop.name = "PortraitBackdrop"
	_portrait_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(_portrait_backdrop, 10)
	_medallion_inner.add_child(_portrait_backdrop)

	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "PortraitTexture"
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_set_full_rect(_portrait_rect)
	_portrait_backdrop.add_child(_portrait_rect)

	var shader := Shader.new()
	shader.code = PORTRAIT_MASK_SHADER_CODE
	_portrait_material = ShaderMaterial.new()
	_portrait_material.shader = shader
	_portrait_rect.material = _portrait_material

	_health_badge = PanelContainer.new()
	_health_badge.name = "HealthBadge"
	_health_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_root.add_child(_health_badge)
	var badge_box := _build_panel_box(_health_badge, 2, 6)
	_health_value_label = Label.new()
	_health_value_label.name = "HealthValue"
	_health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_value_label.add_theme_font_size_override("font_size", 26)
	badge_box.add_child(_health_value_label)
	_health_caption_label = Label.new()
	_health_caption_label.name = "HealthCaption"
	_health_caption_label.text = "HEALTH"
	_health_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_caption_label.add_theme_font_size_override("font_size", 10)
	badge_box.add_child(_health_caption_label)

	_rune_entries.clear()
	for threshold in DEFAULT_RUNE_THRESHOLDS:
		var rune_panel := PanelContainer.new()
		rune_panel.name = "Rune_%d" % threshold
		rune_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_root.add_child(rune_panel)

		var rune_inner := PanelContainer.new()
		rune_inner.name = "Inner"
		rune_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_full_rect(rune_inner, 4)
		rune_panel.add_child(rune_inner)

		var crack := Label.new()
		crack.name = "Crack"
		crack.text = "×"
		crack.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		crack.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		crack.add_theme_font_size_override("font_size", 14)
		_set_full_rect(crack)
		rune_panel.add_child(crack)

		_rune_entries.append({
			"threshold": threshold,
			"panel": rune_panel,
			"inner": rune_inner,
			"crack": crack,
		})

	_is_built = true


func _refresh_all() -> void:
	_refresh_portrait()
	_refresh_presentation()
	_refresh_health()
	_refresh_runes()
	_layout_internal_nodes()


func _refresh_portrait() -> void:
	if _portrait_rect == null:
		return
	_portrait_rect.texture = _portrait_texture if _portrait_texture != null else DEFAULT_PORTRAIT


func _refresh_presentation() -> void:
	if _medallion_outer == null:
		return
	var opponent := is_opponent()
	_apply_panel_style(_medallion_outer, Color(0.09, 0.11, 0.14, 0.98) if not opponent else Color(0.15, 0.1, 0.11, 0.98), Color(0.52, 0.72, 0.95, 0.96) if not opponent else Color(0.88, 0.62, 0.42, 0.96), 3, _circular_panel_radius(_medallion_outer, 16))
	_apply_panel_style(_medallion_inner, Color(0.05, 0.06, 0.08, 0.98), Color(0.74, 0.84, 0.98, 0.88) if not opponent else Color(0.98, 0.82, 0.58, 0.88), 1, _circular_panel_radius(_medallion_inner, 14))
	_apply_panel_style(_portrait_backdrop, Color(0.14, 0.15, 0.19, 0.98) if not opponent else Color(0.18, 0.14, 0.14, 0.98), Color(0.32, 0.42, 0.56, 0.82) if not opponent else Color(0.54, 0.36, 0.3, 0.84), 1, _circular_panel_radius(_portrait_backdrop, 12))


func _refresh_health() -> void:
	if _health_value_label == null:
		return
	_health_value_label.text = str(_health)
	var low_health := _health <= 10
	_apply_panel_style(_health_badge, Color(0.34, 0.13, 0.13, 0.98) if low_health else Color(0.24, 0.1, 0.12, 0.98), Color(1.0, 0.59, 0.43, 1.0) if low_health else Color(0.86, 0.54, 0.37, 0.98), 2, _circular_panel_radius(_health_badge, 14))
	_health_value_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9, 1.0))
	_health_caption_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.72, 0.98))


func _refresh_runes() -> void:
	for rune_entry in _rune_entries:
		var threshold := int(rune_entry["threshold"])
		var rune_panel := rune_entry["panel"] as PanelContainer
		var rune_inner := rune_entry["inner"] as PanelContainer
		var crack := rune_entry["crack"] as Label
		var active := _active_rune_thresholds.has(threshold)
		_apply_panel_style(rune_panel, Color(0.39, 0.14, 0.13, 0.98) if active else Color(0.08, 0.08, 0.1, 0.96), Color(0.96, 0.74, 0.48, 0.98) if active else Color(0.26, 0.28, 0.32, 0.88), 1, _circular_panel_radius(rune_panel, 10))
		_apply_panel_style(rune_inner, Color(0.7, 0.22, 0.2, 0.98) if active else Color(0.16, 0.16, 0.19, 0.96), Color(1.0, 0.86, 0.62, 0.98) if active else Color(0.32, 0.33, 0.38, 0.88), 1, _circular_panel_radius(rune_inner, 8))
		crack.visible = not active
		crack.add_theme_color_override("font_color", Color(0.42, 0.44, 0.5, 0.98))
		rune_panel.tooltip_text = "Rune %d intact" % threshold if active else "Rune %d broken" % threshold


func _layout_internal_nodes() -> void:
	if not _is_built:
		return
	var width := size.x if size.x > 0.0 else custom_minimum_size.x
	var height := size.y if size.y > 0.0 else custom_minimum_size.y
	var content_padding := clampf(minf(width, height) * 0.06, 6.0, 16.0)
	var available_size := Vector2(maxf(width - content_padding * 2.0, 0.0), maxf(height - content_padding * 2.0, 0.0))
	var medallion_size := minf(MEDALLION_MAX_SIZE, minf(available_size.x, available_size.y))
	var badge_size := Vector2.ZERO
	var rune_size := 0.0
	var orbit_radius := 0.0
	var left_overhang := 0.0
	var right_overhang := 0.0
	var top_overhang := 0.0
	var bottom_overhang := 0.0
	for _pass in range(2):
		badge_size = _computed_badge_size(medallion_size)
		rune_size = _computed_rune_size(medallion_size)
		orbit_radius = medallion_size * RUNE_ORBIT_RATIO
		var rune_side_overhang := maxf(0.0, orbit_radius * 0.8660254 + rune_size * 0.5 - medallion_size * 0.5)
		top_overhang = maxf(0.0, orbit_radius + rune_size * 0.5 - medallion_size * 0.5)
		var badge_side_overhang := badge_size.x * 0.26
		bottom_overhang = badge_size.y * 0.28
		left_overhang = maxf(rune_side_overhang, badge_side_overhang)
		right_overhang = rune_side_overhang
		var content_size := Vector2(medallion_size + left_overhang + right_overhang, medallion_size + top_overhang + bottom_overhang)
		if content_size.x <= available_size.x and content_size.y <= available_size.y:
			break
		var fit_scale := minf(
			1.0,
			minf(
				available_size.x / maxf(content_size.x, 1.0),
				available_size.y / maxf(content_size.y, 1.0)
			)
		)
		medallion_size *= maxf(fit_scale, 0.0)
	badge_size = _computed_badge_size(medallion_size)
	rune_size = _computed_rune_size(medallion_size)
	orbit_radius = medallion_size * RUNE_ORBIT_RATIO
	var rune_side_overhang := maxf(0.0, orbit_radius * 0.8660254 + rune_size * 0.5 - medallion_size * 0.5)
	top_overhang = maxf(0.0, orbit_radius + rune_size * 0.5 - medallion_size * 0.5)
	var badge_side_overhang := badge_size.x * 0.26
	bottom_overhang = badge_size.y * 0.28
	left_overhang = maxf(rune_side_overhang, badge_side_overhang)
	right_overhang = rune_side_overhang
	var content_size := Vector2(medallion_size + left_overhang + right_overhang, medallion_size + top_overhang + bottom_overhang)
	var content_origin := Vector2((width - content_size.x) * 0.5, (height - content_size.y) * 0.5)
	var medallion_origin := content_origin + Vector2(left_overhang, top_overhang)
	_medallion_outer.position = medallion_origin
	_medallion_outer.size = Vector2.ONE * medallion_size

	_health_badge.size = badge_size
	var badge_x := medallion_origin.x - badge_size.x * 0.26
	_health_badge.position = Vector2(badge_x, medallion_origin.y + medallion_size - badge_size.y * 0.72)

	var center := medallion_origin + Vector2.ONE * medallion_size * 0.5
	var angles := [-30.0, -60.0, -90.0, -120.0, -150.0]
	for index in range(_rune_entries.size()):
		var rune_panel := _rune_entries[index]["panel"] as PanelContainer
		var point := center + Vector2(cos(deg_to_rad(angles[index])), sin(deg_to_rad(angles[index]))) * orbit_radius
		rune_panel.position = point - Vector2.ONE * rune_size * 0.5
		rune_panel.size = Vector2.ONE * rune_size
	_refresh_corner_radii()


func _set_full_rect(control: Control, inset := 0.0) -> void:
	control.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	control.offset_left = inset
	control.offset_top = inset
	control.offset_right = -inset
	control.offset_bottom = -inset


func _build_panel_box(panel: PanelContainer, separation := 8, padding := 10) -> VBoxContainer:
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
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color, border_width := 1, corner_radius := 12) -> void:
	panel.add_theme_stylebox_override("panel", _build_style_box(fill, border, border_width, corner_radius))


func _refresh_corner_radii() -> void:
	_set_panel_corner_radius(_medallion_outer, _circular_panel_radius(_medallion_outer, 16))
	_set_panel_corner_radius(_medallion_inner, _circular_panel_radius(_medallion_inner, 14))
	_set_panel_corner_radius(_portrait_backdrop, _circular_panel_radius(_portrait_backdrop, 12))
	_set_panel_corner_radius(_health_badge, _circular_panel_radius(_health_badge, 14))
	for rune_entry in _rune_entries:
		_set_panel_corner_radius(rune_entry.get("panel") as PanelContainer, _circular_panel_radius(rune_entry.get("panel") as Control, 10))
		_set_panel_corner_radius(rune_entry.get("inner") as PanelContainer, _circular_panel_radius(rune_entry.get("inner") as Control, 8))


func _set_panel_corner_radius(panel: PanelContainer, corner_radius: int) -> void:
	if panel == null:
		return
	var style := panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var flat := style as StyleBoxFlat
		flat.corner_radius_top_left = corner_radius
		flat.corner_radius_top_right = corner_radius
		flat.corner_radius_bottom_left = corner_radius
		flat.corner_radius_bottom_right = corner_radius


func _circular_panel_radius(control: Control, fallback: int) -> int:
	if control == null:
		return fallback
	var diameter := minf(control.size.x, control.size.y)
	if diameter <= 0.0:
		return fallback
	return maxi(1, int(round(diameter * 0.5)))


func _computed_badge_size(medallion_size: float) -> Vector2:
	var badge_minimum := _health_badge.get_combined_minimum_size() if _health_badge != null else Vector2.ZERO
	return Vector2(
		maxf(medallion_size * BADGE_WIDTH_RATIO, badge_minimum.x),
		maxf(medallion_size * BADGE_HEIGHT_RATIO, badge_minimum.y)
	)


func _computed_rune_size(medallion_size: float) -> float:
	var rune_minimum := 0.0
	for rune_entry in _rune_entries:
		var panel_minimum := _rune_layout_minimum_size(rune_entry)
		rune_minimum = maxf(rune_minimum, maxf(panel_minimum.x, panel_minimum.y))
	return maxf(minf(medallion_size * RUNE_SIZE_RATIO, 28.0), rune_minimum)


func _rune_layout_minimum_size(rune_entry: Dictionary) -> Vector2:
	var minimum := Vector2.ZERO
	var rune_panel := rune_entry.get("panel") as Control
	if rune_panel != null:
		minimum.x = maxf(minimum.x, rune_panel.custom_minimum_size.x)
		minimum.y = maxf(minimum.y, rune_panel.custom_minimum_size.y)
	for key in ["inner"]:
		var control := rune_entry.get(key) as Control
		if control == null:
			continue
		var control_minimum := control.get_combined_minimum_size()
		minimum.x = maxf(minimum.x, control_minimum.x)
		minimum.y = maxf(minimum.y, control_minimum.y)
	return minimum


func _build_style_box(fill: Color, border: Color, border_width := 1, corner_radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	return style


func _normalize_rune_thresholds(source) -> PackedInt32Array:
	var provided: Array = []
	if source is PackedInt32Array:
		for threshold in source:
			provided.append(int(threshold))
	elif source is Array:
		for threshold in source:
			provided.append(int(threshold))
	var normalized := PackedInt32Array()
	for threshold in DEFAULT_RUNE_THRESHOLDS:
		if provided.has(threshold):
			normalized.append(threshold)
	return normalized
