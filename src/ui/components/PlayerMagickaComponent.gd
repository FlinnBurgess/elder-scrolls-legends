class_name PlayerMagickaComponent
extends Control

const DEFAULT_SEGMENTS := 12
const RECOMMENDED_MINIMUM_SIZE := Vector2(172, 172)
const MAX_COMPONENT_DIAMETER := 172.0
const CENTER_DIAMETER_RATIO := 0.56
const SEGMENT_LENGTH_RATIO := 0.18
const SEGMENT_THICKNESS_RATIO := 0.075
const SEGMENT_ORBIT_INSET_MULTIPLIER := 1.15

const STATE_REMAINING := "remaining"
const STATE_SPENT := "spent"
const STATE_LOCKED := "locked"
const STATE_TEMPORARY := "temporary"

const COLOR_BORDER := Color(0.02, 0.02, 0.03, 1.0)
const COLOR_MEDALLION := Color(0.22, 0.56, 0.88, 0.98)
const COLOR_REMAINING := Color(0.18, 0.56, 0.88, 0.98)
const COLOR_SPENT := Color(0.47, 0.5, 0.56, 0.96)
const COLOR_LOCKED := Color(0.05, 0.05, 0.06, 0.98)
const COLOR_TEMPORARY := Color(0.95, 0.77, 0.18, 0.98)

var _current_magicka := 0
var _max_magicka := 0
var _temporary_magicka := 0
var _is_built := false

var _content_root: Control
var _center_outer: PanelContainer
var _center_inner: PanelContainer
var _center_label: Label
var _segment_entries: Array = []

@export var current_magicka: int = 0:
	set(value):
		_current_magicka = maxi(0, value)
		_refresh_magicka()
	get:
		return _current_magicka

@export var max_magicka: int = 0:
	set(value):
		_max_magicka = maxi(0, value)
		_refresh_magicka()
	get:
		return _max_magicka

@export var temporary_magicka: int = 0:
	set(value):
		_temporary_magicka = maxi(0, value)
		_refresh_magicka()
	get:
		return _temporary_magicka


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
		_refresh_magicka()


func set_magicka_values(current: int, maximum: int, temporary := 0) -> void:
	_current_magicka = maxi(0, current)
	_max_magicka = maxi(0, maximum)
	_temporary_magicka = maxi(0, temporary)
	_refresh_magicka()


func apply_player_state(player: Dictionary) -> void:
	set_magicka_values(
		int(player.get("current_magicka", _current_magicka)),
		int(player.get("max_magicka", _max_magicka)),
		int(player.get("temporary_magicka", _temporary_magicka))
	)


func get_display_text() -> String:
	return "%d/%d" % [maxi(0, _current_magicka + _temporary_magicka), maxi(0, _max_magicka)]


func get_segment_states() -> Array:
	var states: Array = []
	var segment_count := _segment_entries.size()
	var current := maxi(0, mini(segment_count, _current_magicka))
	var maximum := maxi(0, mini(segment_count, _max_magicka))
	var temporary := maxi(0, mini(segment_count - current, _temporary_magicka))
	for slot_index in range(segment_count):
		var state := STATE_LOCKED
		if slot_index < current:
			state = STATE_REMAINING
		elif slot_index < current + temporary:
			state = STATE_TEMPORARY
		elif slot_index < maximum:
			state = STATE_SPENT
		states.append(state)
	return states


func get_segment_node(slot_index: int) -> Control:
	if slot_index < 0 or slot_index >= _segment_entries.size():
		return null
	return _segment_entries[slot_index].get("panel") as Control


func get_segment_count() -> int:
	return _segment_entries.size()


func _build_internal_nodes() -> void:
	_content_root = Control.new()
	_content_root.name = "ContentRoot"
	_content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(_content_root)
	add_child(_content_root)

	_center_outer = PanelContainer.new()
	_center_outer.name = "MedallionOuter"
	_center_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_root.add_child(_center_outer)

	_center_inner = PanelContainer.new()
	_center_inner.name = "MedallionInner"
	_center_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_outer.add_child(_center_inner)

	_center_label = Label.new()
	_center_label.name = "MagickaLabel"
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(_center_label)
	_center_inner.add_child(_center_label)

	_segment_entries.clear()
	for slot_index in range(DEFAULT_SEGMENTS):
		_add_segment(slot_index)

	_is_built = true


func _add_segment(slot_index: int) -> void:
	var panel := PanelContainer.new()
	panel.name = "Segment_%02d" % (slot_index + 1)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_root.add_child(panel)

	var inner := PanelContainer.new()
	inner.name = "Inner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)

	_segment_entries.append({
		"panel": panel,
		"inner": inner,
	})


func _ensure_segment_count(count: int) -> void:
	if count == _segment_entries.size():
		return
	while _segment_entries.size() < count:
		_add_segment(_segment_entries.size())
	while _segment_entries.size() > count:
		var entry: Dictionary = _segment_entries.pop_back()
		var panel = entry.get("panel")
		if panel != null:
			panel.queue_free()
	_layout_internal_nodes()


func _refresh_all() -> void:
	_layout_internal_nodes()
	_refresh_magicka()


func _refresh_magicka() -> void:
	if _center_label == null:
		return
	var required_segments := maxi(1, maxi(_max_magicka, _current_magicka + _temporary_magicka))
	_ensure_segment_count(required_segments)
	_center_label.text = get_display_text()
	_center_label.add_theme_color_override("font_color", COLOR_BORDER)
	var states: Array = get_segment_states()
	for index in range(_segment_entries.size()):
		var entry: Dictionary = _segment_entries[index]
		var panel := entry.get("panel") as PanelContainer
		var inner := entry.get("inner") as PanelContainer
		var state: String = states[index] if index < states.size() else STATE_LOCKED
		_apply_panel_style(panel, COLOR_BORDER, COLOR_BORDER, 1, _circular_panel_radius(panel, 6))
		_apply_panel_style(inner, _segment_fill(state), COLOR_BORDER, 1, _circular_panel_radius(inner, 6))
		panel.tooltip_text = "Magicka slot %d • %s" % [index + 1, _segment_state_label(state)]
	_apply_panel_style(_center_outer, COLOR_BORDER, COLOR_BORDER, 1, _circular_panel_radius(_center_outer, 12))
	_apply_panel_style(_center_inner, COLOR_MEDALLION, COLOR_BORDER, 2, _circular_panel_radius(_center_inner, 10))
	_refresh_corner_radii()


func _layout_internal_nodes() -> void:
	if not _is_built:
		return
	var width := size.x if size.x > 0.0 else custom_minimum_size.x
	var height := size.y if size.y > 0.0 else custom_minimum_size.y
	var component_diameter := minf(MAX_COMPONENT_DIAMETER, minf(width, height))
	var padding := clampf(component_diameter * 0.08, 8.0, 14.0)
	var outer_diameter := maxf(component_diameter - padding * 2.0, 0.0)
	var content_origin := Vector2((width - outer_diameter) * 0.5, (height - outer_diameter) * 0.5)
	var center := content_origin + Vector2.ONE * outer_diameter * 0.5

	var center_diameter := outer_diameter * CENTER_DIAMETER_RATIO
	_center_outer.position = center - Vector2.ONE * center_diameter * 0.5
	_center_outer.size = Vector2.ONE * center_diameter

	var center_inset := clampf(center_diameter * 0.08, 5.0, 10.0)
	_center_inner.position = Vector2.ONE * center_inset
	_center_inner.size = Vector2.ONE * maxf(center_diameter - center_inset * 2.0, 0.0)
	_center_label.add_theme_font_size_override("font_size", maxi(18, int(round(center_diameter * 0.22))))

	var segment_length := clampf(outer_diameter * SEGMENT_LENGTH_RATIO, 18.0, 28.0)
	var segment_thickness := clampf(outer_diameter * SEGMENT_THICKNESS_RATIO, 10.0, 14.0)
	var segment_inset := clampf(segment_thickness * 0.18, 1.0, 2.0)
	var orbit_radius := outer_diameter * 0.5 - segment_thickness * SEGMENT_ORBIT_INSET_MULTIPLIER
	for index in range(_segment_entries.size()):
		var panel := _segment_entries[index].get("panel") as PanelContainer
		var inner := _segment_entries[index].get("inner") as PanelContainer
		if panel == null or inner == null:
			continue
		panel.size = Vector2(segment_length, segment_thickness)
		panel.pivot_offset = panel.size * 0.5
		var angle := deg_to_rad(-90.0 + float(index) * (360.0 / float(_segment_entries.size())))
		var point := center + Vector2(cos(angle), sin(angle)) * orbit_radius
		panel.position = point - panel.size * 0.5
		panel.rotation = angle + PI * 0.5
		inner.position = Vector2.ONE * segment_inset
		inner.size = Vector2(maxf(panel.size.x - segment_inset * 2.0, 0.0), maxf(panel.size.y - segment_inset * 2.0, 0.0))
	_refresh_corner_radii()


func _refresh_corner_radii() -> void:
	_set_panel_corner_radius(_center_outer, _circular_panel_radius(_center_outer, 12))
	_set_panel_corner_radius(_center_inner, _circular_panel_radius(_center_inner, 10))
	for entry in _segment_entries:
		_set_panel_corner_radius(entry.get("panel") as PanelContainer, _circular_panel_radius(entry.get("panel") as Control, 6))
		_set_panel_corner_radius(entry.get("inner") as PanelContainer, _circular_panel_radius(entry.get("inner") as Control, 6))


func _segment_fill(state: String) -> Color:
	match state:
		STATE_REMAINING:
			return COLOR_REMAINING
		STATE_SPENT:
			return COLOR_SPENT
		STATE_TEMPORARY:
			return COLOR_TEMPORARY
		_:
			return COLOR_LOCKED


func _segment_state_label(state: String) -> String:
	match state:
		STATE_REMAINING:
			return "remaining unlocked"
		STATE_SPENT:
			return "spent unlocked"
		STATE_TEMPORARY:
			return "temporary"
		_:
			return "locked"


func _set_full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color, border_width := 1, corner_radius := 12) -> void:
	panel.add_theme_stylebox_override("panel", _build_style_box(fill, border, border_width, corner_radius))


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