class_name CardDisplayComponent
extends Control

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")

const PRESENTATION_FULL := "full"
const PRESENTATION_CREATURE_BOARD_MINIMAL := "creature_board_minimal"
const PRESENTATION_SUPPORT_BOARD_MINIMAL := "support_board_minimal"

const FULL_LAYOUT_BASE_SIZE := Vector2(220, 384)
const CREATURE_BOARD_LAYOUT_BASE_SIZE := Vector2(193, 336)
const SUPPORT_BOARD_LAYOUT_BASE_SIZE := Vector2(144, 144)
const PRESENTATION_SCALE := 1.0

const FULL_MINIMUM_SIZE := FULL_LAYOUT_BASE_SIZE * PRESENTATION_SCALE
const CREATURE_BOARD_MINIMUM_SIZE := CREATURE_BOARD_LAYOUT_BASE_SIZE * PRESENTATION_SCALE
const SUPPORT_BOARD_MINIMUM_SIZE := SUPPORT_BOARD_LAYOUT_BASE_SIZE * PRESENTATION_SCALE

const DEFAULT_ART_PATH := "res://assets/images/cards/placeholder.png"

const KEYWORD_NAMES := [
	"breakthrough", "charge", "drain", "guard",
	"lethal", "mobilize", "rally", "regenerate", "ward",
]

const COLOR_FRAME_DARK := Color(0.07, 0.08, 0.1, 0.98)
const COLOR_FRAME_INNER := Color(0.15, 0.13, 0.11, 0.98)
const COLOR_TEXT := Color(0.97, 0.95, 0.9, 1.0)
const COLOR_TEXT_MUTED := Color(0.85, 0.82, 0.76, 0.96)
const COLOR_RULES_TEXT := Color(0.9, 0.9, 0.94, 0.96)
const COLOR_STAT_BASE := Color(0.98, 0.94, 0.86, 1.0)
const COLOR_STAT_BUFF := Color(0.56, 0.94, 0.56, 1.0)
const COLOR_STAT_REDUCED := Color(0.97, 0.48, 0.43, 1.0)

const ATTRIBUTE_TINTS := {
	"strength": Color(0.84, 0.39, 0.31, 1.0),
	"intelligence": Color(0.42, 0.62, 0.96, 1.0),
	"willpower": Color(0.92, 0.78, 0.38, 1.0),
	"agility": Color(0.4, 0.76, 0.52, 1.0),
	"endurance": Color(0.58, 0.46, 0.72, 1.0),
}

var _card_data: Dictionary = {}
var _presentation_mode := PRESENTATION_FULL
var _is_built := false
var _default_art_texture: Texture2D

var _content_root: Control
var _outer_frame: PanelContainer
var _inner_frame: PanelContainer
var _name_banner: PanelContainer
var _name_label: Label
var _subtype_banner: PanelContainer
var _subtype_label: Label
var _art_frame: PanelContainer
var _art_texture: TextureRect
var _rules_panel: PanelContainer
var _rules_label: RichTextLabel
var _rarity_marker: PanelContainer
var _rarity_label: Label
var _cost_badge: PanelContainer
var _cost_label: Label
var _attack_badge: PanelContainer
var _attack_label: Label
var _health_badge: PanelContainer
var _health_label: Label
var _ward_overlay: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = _recommended_minimum_size(_presentation_mode)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	if not _is_built:
		_build_internal_nodes()
	_refresh_all()


func _process(_delta: float) -> void:
	if _ward_overlay != null and _ward_overlay.visible:
		_ward_overlay.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _is_built:
		_layout_internal_nodes()


func set_card(card: Dictionary) -> void:
	_card_data = card.duplicate(true)
	_refresh_all()


func get_card_data() -> Dictionary:
	return _card_data.duplicate(true)


func set_presentation_mode(mode: String) -> void:
	_presentation_mode = _normalize_mode(mode)
	custom_minimum_size = _recommended_minimum_size(_presentation_mode)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	_refresh_all()


func get_presentation_mode() -> String:
	return _presentation_mode


func apply_card(card: Dictionary, presentation_mode := "") -> void:
	if not str(presentation_mode).is_empty():
		_presentation_mode = _normalize_mode(str(presentation_mode))
		custom_minimum_size = _recommended_minimum_size(_presentation_mode)
		if size == Vector2.ZERO:
			size = custom_minimum_size
	_card_data = card.duplicate(true)
	_refresh_all()


func get_art_texture() -> Texture2D:
	if _art_texture != null and _art_texture.texture != null:
		return _art_texture.texture
	return _get_default_art_texture()


func _build_internal_nodes() -> void:
	_content_root = Control.new()
	_content_root.name = "ContentRoot"
	_set_full_rect(_content_root)
	add_child(_content_root)

	_outer_frame = PanelContainer.new()
	_outer_frame.name = "OuterFrame"
	_outer_frame.clip_contents = true
	_content_root.add_child(_outer_frame)

	_inner_frame = PanelContainer.new()
	_inner_frame.name = "InnerFrame"
	_inner_frame.clip_contents = true
	_content_root.add_child(_inner_frame)

	_art_frame = PanelContainer.new()
	_art_frame.name = "ArtFrame"
	_art_frame.clip_contents = true
	_content_root.add_child(_art_frame)

	# Ward overlay sits above artwork but below banners and badges
	_ward_overlay = ColorRect.new()
	_ward_overlay.name = "WardOverlay"
	_ward_overlay.color = Color.TRANSPARENT
	_ward_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ward_overlay.visible = false
	var ward_shader := load("res://assets/shaders/ward_mist.gdshader") as Shader
	if ward_shader:
		var ward_mat := ShaderMaterial.new()
		ward_mat.shader = ward_shader
		_ward_overlay.material = ward_mat
	_content_root.add_child(_ward_overlay)

	# Name banner added AFTER art so it renders on top as an overlay
	_name_banner = PanelContainer.new()
	_name_banner.name = "NameBanner"
	_name_banner.clip_contents = true
	_content_root.add_child(_name_banner)
	var name_box := _build_panel_box(_name_banner, 0, 4, BoxContainer.ALIGNMENT_CENTER)
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 1
	_name_label.add_theme_font_size_override("font_size", 13)
	name_box.add_child(_name_label)
	# Subtype banner – separate box overlaying the bottom of the name banner
	_subtype_banner = PanelContainer.new()
	_subtype_banner.name = "SubtypeBanner"
	_subtype_banner.clip_contents = true
	_content_root.add_child(_subtype_banner)
	var subtype_box := _build_panel_box(_subtype_banner, 0, 4, BoxContainer.ALIGNMENT_CENTER)
	_subtype_label = Label.new()
	_subtype_label.name = "SubtypeLabel"
	_subtype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtype_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtype_label.max_lines_visible = 1
	_subtype_label.add_theme_font_size_override("font_size", 9)
	subtype_box.add_child(_subtype_label)
	_art_texture = TextureRect.new()
	_art_texture.name = "ArtTexture"
	_art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(_art_texture)
	_art_frame.add_child(_art_texture)

	_rules_panel = PanelContainer.new()
	_rules_panel.name = "RulesPanel"
	_rules_panel.clip_contents = true
	_content_root.add_child(_rules_panel)
	var rules_box := _build_panel_box(_rules_panel, 2, 6, BoxContainer.ALIGNMENT_CENTER)
	_rules_label = RichTextLabel.new()
	_rules_label.name = "RulesLabel"
	_rules_label.bbcode_enabled = true
	_rules_label.fit_content = false
	_rules_label.scroll_active = false
	_rules_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_rules_label.size_flags_vertical = SIZE_EXPAND_FILL
	_rules_label.add_theme_font_size_override("normal_font_size", 18)
	_rules_label.add_theme_font_size_override("bold_font_size", 18)
	rules_box.add_child(_rules_label)

	_rarity_marker = PanelContainer.new()
	_rarity_marker.name = "RarityMarker"
	_content_root.add_child(_rarity_marker)
	_rarity_label = _build_centered_label("RarityLabel", 9)
	_rarity_marker.add_child(_rarity_label)

	_cost_badge = PanelContainer.new()
	_cost_badge.name = "CostBadge"
	_content_root.add_child(_cost_badge)
	_cost_label = _build_centered_label("CostLabel", 16)
	_cost_badge.add_child(_cost_label)

	_attack_badge = PanelContainer.new()
	_attack_badge.name = "AttackBadge"
	_content_root.add_child(_attack_badge)
	_attack_label = _build_centered_label("AttackLabel", 18)
	var bold_font := SystemFont.new()
	bold_font.font_weight = 700
	_attack_label.add_theme_font_override("font", bold_font)
	_content_root.add_child(_attack_label)

	_health_badge = PanelContainer.new()
	_health_badge.name = "HealthBadge"
	_content_root.add_child(_health_badge)
	_health_label = _build_centered_label("HealthLabel", 18)
	var bold_font_h := SystemFont.new()
	bold_font_h.font_weight = 700
	_health_label.add_theme_font_override("font", bold_font_h)
	_health_badge.add_child(_health_label)

	_set_mouse_passthrough_recursive(_content_root)
	_is_built = true


func _refresh_all() -> void:
	if not _is_built:
		return
	_refresh_content()
	_refresh_styles()
	_refresh_visibility()
	_layout_internal_nodes()


func _refresh_content() -> void:
	if not _is_built:
		return
	_art_texture.texture = _resolve_art_texture(_card_data)
	_cost_label.text = str(int(_card_data.get("cost", 0)))
	_name_label.text = _card_name(_card_data)
	_subtype_label.text = _subtype_line(_card_data)
	_rules_label.text = _rules_bbcode(_card_data)
	_rarity_label.text = ""
	_rarity_label.visible = false
	if _is_creature(_card_data):
		_attack_label.text = str(EvergreenRules.get_power(_card_data))
		_health_label.text = str(EvergreenRules.get_remaining_health(_card_data))
	else:
		_attack_label.text = ""
		_health_label.text = ""


func _refresh_styles() -> void:
	if not _is_built:
		return
	var scale := _layout_scale()
	_apply_font_sizes(scale)
	var accent := _attribute_tint(_card_data)
	var muted_accent := accent.darkened(0.28)
	# Outer frame – dark with accent border (ESL-style card edge)
	_apply_panel_style(_outer_frame, COLOR_FRAME_DARK, accent, _scaled_border_width(3, scale), 0)
	# Inner frame – slightly lighter
	_apply_panel_style(_inner_frame, COLOR_FRAME_INNER, muted_accent, _scaled_border_width(1, scale), 0)
	# Name banner – opaque dark overlay on top of art, thin bottom border matching art frame
	var art_border_color := accent.lerp(Color(0.78, 0.64, 0.4, 1.0), 0.42)
	_apply_panel_style(_name_banner, Color(0.0, 0.0, 0.0, 0.95), art_border_color, 0, 0)
	var name_style := _name_banner.get_theme_stylebox("panel") as StyleBoxFlat
	if name_style:
		name_style.border_width_bottom = _scaled_border_width(2, scale)
	# Subtype banner – dark opaque, no rounding, 1px border
	_apply_panel_style(_subtype_banner, Color(0.0, 0.0, 0.0, 0.95), art_border_color, 1, 0)
	# Art frame – the main card image area
	_apply_panel_style(_art_frame, _art_fill(_presentation_mode), accent.lerp(Color(0.78, 0.64, 0.4, 1.0), 0.42), _scaled_border_width(2 if _presentation_mode == PRESENTATION_FULL else 1, scale), 0)
	# Rules panel – transparent so text renders over the inner frame background
	_apply_panel_style(_rules_panel, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	# Rarity gem – small diamond, filled with rarity color
	_apply_panel_style(_rarity_marker, _rarity_color(_card_data).darkened(0.3), Color.BLACK, _scaled_border_width(2, scale), _scaled_int(2, scale))
	# Cost badge – dark circle
	_apply_panel_style(_cost_badge, Color(0.12, 0.14, 0.18, 0.99), Color(0.72, 0.84, 0.98, 1.0), _scaled_border_width(2, scale), _scaled_int(17, scale))
	# Attack badge – diamond shape (square corners)
	_apply_panel_style(_attack_badge, Color(0.08, 0.06, 0.04, 0.98), Color(0.72, 0.62, 0.42, 0.96), _scaled_border_width(2, scale), 0)
	# Health badge – circular (corner radius = half the badge side)
	_apply_panel_style(_health_badge, Color(0.08, 0.06, 0.04, 0.98), Color(0.72, 0.62, 0.42, 0.96), _scaled_border_width(2, scale), _scaled_int(15, scale))
	# Guard: thick dark brown top border on outer frame
	if EvergreenRules.has_keyword(_card_data, EvergreenRules.KEYWORD_GUARD):
		var outer_style := _outer_frame.get_theme_stylebox("panel") as StyleBoxFlat
		if outer_style:
			outer_style.border_width_top = _scaled_border_width(8, scale)
			outer_style.border_color = Color(0.36, 0.22, 0.08, 1.0)
	# Cover: dark purplish hue on card art
	if bool(_card_data.get("_cover_active", false)):
		_art_texture.modulate = Color(0.6, 0.4, 0.7, 1.0)
	else:
		_art_texture.modulate = Color.WHITE
	_name_label.add_theme_color_override("font_color", COLOR_TEXT)
	_subtype_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_rules_label.add_theme_color_override("default_color", COLOR_RULES_TEXT)
	_rarity_label.add_theme_color_override("font_color", _rarity_color(_card_data))
	_cost_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	_attack_label.add_theme_color_override("font_color", _stat_color(_card_data, "power"))
	_health_label.add_theme_color_override("font_color", _stat_color(_card_data, "health"))


func _refresh_visibility() -> void:
	if not _is_built:
		return
	var full := _presentation_mode == PRESENTATION_FULL
	var creature_minimal := _presentation_mode == PRESENTATION_CREATURE_BOARD_MINIMAL
	var is_creature := _is_creature(_card_data)
	_name_banner.visible = full
	_subtype_banner.visible = full
	_rules_panel.visible = full
	_rarity_marker.visible = full
	_cost_badge.visible = full
	_attack_badge.visible = is_creature and (full or creature_minimal)
	_health_badge.visible = is_creature and (full or creature_minimal)
	_ward_overlay.visible = is_creature and EvergreenRules.has_keyword(_card_data, EvergreenRules.KEYWORD_WARD)


func _layout_internal_nodes() -> void:
	if not _is_built:
		return
	var width := size.x if size.x > 0.0 else custom_minimum_size.x
	var height := size.y if size.y > 0.0 else custom_minimum_size.y
	var frame_rect := _frame_rect(width, height)
	_outer_frame.position = frame_rect.position
	_outer_frame.size = frame_rect.size
	_inner_frame.position = frame_rect.position + Vector2.ONE * 4.0
	_inner_frame.size = Vector2(maxf(frame_rect.size.x - 8.0, 0.0), maxf(frame_rect.size.y - 8.0, 0.0))
	var inner_rect := Rect2(_inner_frame.position, _inner_frame.size)
	match _presentation_mode:
		PRESENTATION_CREATURE_BOARD_MINIMAL:
			_layout_creature_board_minimal(inner_rect)
		PRESENTATION_SUPPORT_BOARD_MINIMAL:
			_layout_support_board_minimal(inner_rect)
		_:
			_layout_full(inner_rect)
	_refresh_corner_radii()


func _layout_full(inner_rect: Rect2) -> void:
	var scale := _layout_scale(PRESENTATION_FULL)
	var content_padding := 6.0 * scale
	var content_width := maxf(inner_rect.size.x - content_padding * 2.0, 0.0)

	# Cost badge – circular, top-left overlapping the frame
	var cost_size := Vector2.ONE * (34.0 * scale)
	_cost_badge.size = cost_size
	_cost_badge.position = _outer_frame.position + Vector2(-4.0 * scale, -4.0 * scale)

	# Art frame – dominates the card (~58% of inner height)
	var art_top := inner_rect.position.y + content_padding
	var art_height := inner_rect.size.y * 0.70
	_art_frame.position = Vector2(inner_rect.position.x + content_padding, art_top)
	_art_frame.size = Vector2(content_width, art_height)

	# Name banner – opaque, inset within the art frame border
	var art_border_w := float(_scaled_border_width(2, scale))
	var banner_height := 28.0 * scale
	_name_banner.position = _art_frame.position + Vector2(art_border_w, art_border_w)
	_name_banner.size = Vector2(_art_frame.size.x - art_border_w * 2.0, banner_height)
	# Subtype banner – centered horizontally, overlapping bottom of name banner
	var subtype_height := 12.0 * scale
	var subtype_width := _art_frame.size.x * 0.45
	_subtype_banner.position = Vector2(
		_art_frame.position.x + (_art_frame.size.x - subtype_width) * 0.5,
		_name_banner.position.y + banner_height - subtype_height * 0.5
	)
	_subtype_banner.size = Vector2(subtype_width, subtype_height)

	# Stat badges – attack diamond + health circle, straddling art bottom edge
	_layout_stat_badges(inner_rect, Rect2(_art_frame.position, _art_frame.size), scale, true)

	_layout_ward_overlay()

	# Rules panel – bottom portion of card below art, with gap for stat badges
	var rules_y := _art_frame.position.y + _art_frame.size.y + 4.0 * scale
	var rules_bottom := inner_rect.position.y + inner_rect.size.y - content_padding
	var rules_size := Vector2(content_width, maxf(rules_bottom - rules_y, 40.0 * scale))
	_rules_panel.custom_minimum_size = Vector2.ZERO
	_rules_panel.position = Vector2(inner_rect.position.x + content_padding, rules_y)
	_rules_panel.size = rules_size

	# Rarity gem – small diamond centered at the bottom edge of the card
	var gem_side := 12.0 * scale
	var gem_size := Vector2(gem_side, gem_side)
	_rarity_marker.size = gem_size
	_rarity_marker.pivot_offset = gem_size * 0.5
	_rarity_marker.rotation_degrees = 45.0
	_rarity_marker.position = Vector2(
		inner_rect.position.x + (inner_rect.size.x - gem_size.x) * 0.5,
		inner_rect.position.y + inner_rect.size.y - gem_size.y * 0.5
	)


func _layout_creature_board_minimal(inner_rect: Rect2) -> void:
	var scale := _layout_scale(PRESENTATION_CREATURE_BOARD_MINIMAL)
	var art_padding := 6.0 * scale
	_art_frame.position = inner_rect.position + Vector2.ONE * art_padding
	_art_frame.size = Vector2(maxf(inner_rect.size.x - art_padding * 2.0, 0.0), maxf(inner_rect.size.y - art_padding * 2.0, 0.0))
	_layout_stat_badges(inner_rect, Rect2(_art_frame.position, _art_frame.size), scale)
	_layout_ward_overlay()
	_name_banner.position = Vector2.ZERO
	_name_banner.size = Vector2.ZERO
	_subtype_banner.position = Vector2.ZERO
	_subtype_banner.size = Vector2.ZERO
	_rules_panel.position = Vector2.ZERO
	_rules_panel.size = Vector2.ZERO
	_rarity_marker.position = Vector2.ZERO
	_rarity_marker.size = Vector2.ZERO
	_cost_badge.position = Vector2.ZERO
	_cost_badge.size = Vector2.ZERO


func _layout_support_board_minimal(inner_rect: Rect2) -> void:
	var scale := _layout_scale(PRESENTATION_SUPPORT_BOARD_MINIMAL)
	var square_size := minf(inner_rect.size.x, inner_rect.size.y)
	var square_origin := inner_rect.position + Vector2((inner_rect.size.x - square_size) * 0.5, (inner_rect.size.y - square_size) * 0.5)
	_art_frame.position = square_origin + Vector2.ONE * (6.0 * scale)
	_art_frame.size = Vector2.ONE * maxf(square_size - 12.0 * scale, 0.0)
	_name_banner.position = Vector2.ZERO
	_name_banner.size = Vector2.ZERO
	_subtype_banner.position = Vector2.ZERO
	_subtype_banner.size = Vector2.ZERO
	_rules_panel.position = Vector2.ZERO
	_rules_panel.size = Vector2.ZERO
	_rarity_marker.position = Vector2.ZERO
	_rarity_marker.size = Vector2.ZERO
	_cost_badge.position = Vector2.ZERO
	_cost_badge.size = Vector2.ZERO
	_attack_badge.position = Vector2.ZERO
	_attack_badge.size = Vector2.ZERO
	_health_badge.position = Vector2.ZERO
	_health_badge.size = Vector2.ZERO


func _frame_rect(width: float, height: float) -> Rect2:
	if _presentation_mode == PRESENTATION_SUPPORT_BOARD_MINIMAL:
		var square := minf(width, height)
		return Rect2(Vector2((width - square) * 0.5, (height - square) * 0.5), Vector2.ONE * square)
	if _presentation_mode == PRESENTATION_FULL:
		var full_inset := Vector2(8, 8)
		return Rect2(full_inset, Vector2(maxf(width - full_inset.x * 2.0, 0.0), maxf(height - full_inset.y * 2.0, 0.0)))
	return Rect2(Vector2.ZERO, Vector2(width, height))


func _resolve_art_texture(card: Dictionary) -> Texture2D:
	for key in ["art_texture", "art"]:
		var direct = card.get(key, null)
		if direct is Texture2D:
			return direct as Texture2D
	for key in ["art_path", "art_resource_path", "art"]:
		var path := str(card.get(key, "")).strip_edges()
		if path.is_empty():
			continue
		var loaded := _load_texture_from_path(path)
		if loaded != null:
			return loaded
	return _get_default_art_texture()


func _layout_stat_badges(inner_rect: Rect2, art_rect: Rect2, scale: float, esl_style := false) -> void:
	var badge_side := maxf(40.0 * scale, 40.0)
	var health_side := maxf(54.0 * scale, 54.0)
	var badge_size := Vector2(badge_side, badge_side)
	var health_size := Vector2(health_side, health_side)
	var badge_margin := 6.0 * scale
	_attack_badge.size = badge_size
	_health_badge.size = health_size
	_attack_badge.pivot_offset = badge_size * 0.5
	_health_badge.pivot_offset = health_size * 0.5
	if esl_style:
		# Attack: diamond (rotated 45°), Health: circle (no rotation, high corner radius)
		var badge_center_y := art_rect.position.y + art_rect.size.y
		var badge_inset := -6.0 * scale
		# Attack diamond
		_attack_badge.rotation_degrees = 45.0
		_attack_badge.position = Vector2(
			art_rect.position.x + badge_inset,
			badge_center_y - badge_side
		)
		# Health circle — no rotation, shifted down slightly
		_health_badge.rotation_degrees = 0.0
		_health_badge.position = Vector2(
			art_rect.position.x + art_rect.size.x + 14.0 * scale - health_side,
			badge_center_y - health_side * 0.9
		)
		# Attack label positioned over the badge center (not a child, so no inherited rotation)
		var attack_center := _attack_badge.position + _attack_badge.pivot_offset
		_attack_label.size = badge_size
		_attack_label.position = attack_center - badge_size * 0.5
		_attack_label.rotation_degrees = 0.0
		# Health label stays upright
		_health_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_health_label.pivot_offset = health_size * 0.5
		_health_label.rotation_degrees = 0.0
	else:
		# Flat rectangular badges inset on art
		_attack_badge.rotation_degrees = 0.0
		_health_badge.rotation_degrees = 0.0
		var rect_size := Vector2(maxf(28.0 * scale, 28.0), maxf(24.0 * scale, 24.0))
		_attack_badge.size = rect_size
		_health_badge.size = rect_size
		_attack_badge.pivot_offset = rect_size * 0.5
		_health_badge.pivot_offset = rect_size * 0.5
		var badge_top := art_rect.position.y + art_rect.size.y - rect_size.y - badge_margin
		badge_top = clampf(badge_top, art_rect.position.y, maxf(art_rect.position.y + art_rect.size.y - rect_size.y, art_rect.position.y))
		_attack_badge.position = Vector2(art_rect.position.x + badge_margin, badge_top)
		_health_badge.position = Vector2(art_rect.position.x + art_rect.size.x - rect_size.x - badge_margin, badge_top)
		_attack_label.size = rect_size
		_attack_label.position = _attack_badge.position
		_attack_label.rotation_degrees = 0.0
		_health_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_health_label.pivot_offset = rect_size * 0.5
		_health_label.rotation_degrees = 0.0


func _layout_ward_overlay() -> void:
	if _ward_overlay == null:
		return
	# Cover the full art frame area; the shader's vertical fade handles the falloff
	_ward_overlay.position = _art_frame.position
	_ward_overlay.size = _art_frame.size


func _get_default_art_texture() -> Texture2D:
	if _default_art_texture != null:
		return _default_art_texture
	_default_art_texture = _load_texture_from_path(DEFAULT_ART_PATH)
	if _default_art_texture != null:
		return _default_art_texture
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.26, 0.24, 0.22, 1.0))
	_default_art_texture = ImageTexture.create_from_image(image)
	return _default_art_texture


func _load_texture_from_path(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource as Texture2D
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	var image := Image.new()
	if image.load(global_path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _recommended_minimum_size(mode: String) -> Vector2:
	match _normalize_mode(mode):
		PRESENTATION_CREATURE_BOARD_MINIMAL:
			return CREATURE_BOARD_MINIMUM_SIZE
		PRESENTATION_SUPPORT_BOARD_MINIMAL:
			return SUPPORT_BOARD_MINIMUM_SIZE
		_:
			return FULL_MINIMUM_SIZE


func _layout_scale(mode := _presentation_mode) -> float:
	var base_size := _layout_base_size(mode)
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		return 1.0
	var effective_size := size if size != Vector2.ZERO else custom_minimum_size
	if effective_size == Vector2.ZERO:
		effective_size = _recommended_minimum_size(_presentation_mode)
	return maxf(1.0, minf(effective_size.x / base_size.x, effective_size.y / base_size.y))


func _layout_base_size(mode: String) -> Vector2:
	match _normalize_mode(mode):
		PRESENTATION_CREATURE_BOARD_MINIMAL:
			return CREATURE_BOARD_LAYOUT_BASE_SIZE
		PRESENTATION_SUPPORT_BOARD_MINIMAL:
			return SUPPORT_BOARD_LAYOUT_BASE_SIZE
		_:
			return FULL_LAYOUT_BASE_SIZE


func _normalize_mode(mode: String) -> String:
	match str(mode).strip_edges().to_lower():
		PRESENTATION_CREATURE_BOARD_MINIMAL:
			return PRESENTATION_CREATURE_BOARD_MINIMAL
		PRESENTATION_SUPPORT_BOARD_MINIMAL:
			return PRESENTATION_SUPPORT_BOARD_MINIMAL
		_:
			return PRESENTATION_FULL


func _card_name(card: Dictionary) -> String:
	var name := str(card.get("name", "")).strip_edges()
	if not name.is_empty():
		return name
	return _identifier_to_name(str(card.get("definition_id", "Card")))


func _subtype_line(card: Dictionary) -> String:
	var subtypes: Array = card.get("subtypes", [])
	if subtypes.is_empty():
		return _identifier_to_name(str(card.get("card_type", "card")))
	var subtype_names: Array = []
	for subtype in subtypes:
		subtype_names.append(_identifier_to_name(str(subtype)))
	return " • ".join(subtype_names)


func _rules_preview(card: Dictionary) -> String:
	var rules_text := str(card.get("rules_text", "")).strip_edges().replace("\n", " ")
	if rules_text.is_empty():
		return ""
	# Only extract keywords that appear as standalone entries at the start of the
	# rules text (e.g. "Guard." or "Guard, Charge. Deal 2 damage."). Keywords
	# embedded in sentences ("Give a creature Guard") must not be extracted.
	var keywords: Array[String] = []
	var remaining := rules_text
	while not remaining.is_empty():
		var matched := false
		for kw in KEYWORD_NAMES:
			var pattern := RegEx.new()
			pattern.compile("(?i)^" + kw + "(?=[.,;\\s]|$)")
			var m := pattern.search(remaining)
			if m:
				keywords.append(kw.substr(0, 1).to_upper() + kw.substr(1))
				remaining = remaining.substr(m.get_end()).strip_edges()
				# Strip leading punctuation/separators after the keyword
				while not remaining.is_empty() and remaining[0] in [",", ".", ";", " "]:
					remaining = remaining.substr(1)
				remaining = remaining.strip_edges()
				matched = true
				break
		if not matched:
			break
	if keywords.is_empty():
		return rules_text
	var keyword_line := ", ".join(keywords)
	if remaining.is_empty():
		return keyword_line
	return keyword_line + "\n" + remaining


func _rules_bbcode(card: Dictionary) -> String:
	var plain := _rules_preview(card)
	var newline_pos := plain.find("\n")
	if newline_pos < 0:
		# No newline means either no keywords or keywords-only
		var has_keywords := _has_extracted_keywords(card)
		if has_keywords:
			return "[center][b]" + plain + "[/b][/center]"
		return "[center]" + plain + "[/center]"
	var keyword_line := plain.substr(0, newline_pos)
	var rest := plain.substr(newline_pos + 1)
	return "[center][b]" + keyword_line + "[/b]\n" + rest + "[/center]"


func _has_extracted_keywords(card: Dictionary) -> bool:
	var rules_text := str(card.get("rules_text", "")).strip_edges().replace("\n", " ")
	if rules_text.is_empty():
		return false
	for kw in KEYWORD_NAMES:
		var pattern := RegEx.new()
		pattern.compile("(?i)^" + kw + "(?=[.,;\\s]|$)")
		if pattern.search(rules_text):
			return true
	return false


func _card_rarity_text(card: Dictionary) -> String:
	var rarity := str(card.get("rarity", "common")).strip_edges().to_lower()
	return "common" if rarity.is_empty() else rarity


func _rarity_color(card: Dictionary) -> Color:
	match _card_rarity_text(card):
		"legendary":
			return Color(0.98, 0.82, 0.42, 1.0)
		"epic":
			return Color(0.78, 0.62, 0.98, 1.0)
		"rare":
			return Color(0.54, 0.82, 0.99, 1.0)
		"uncommon":
			return Color(0.64, 0.9, 0.64, 1.0)
		_:
			return Color(0.86, 0.86, 0.86, 0.96)


func _attribute_tint(card: Dictionary) -> Color:
	var attributes: Array = card.get("attributes", [])
	if attributes.is_empty():
		return Color(0.7, 0.58, 0.36, 1.0)
	var tint := Color(0, 0, 0, 1)
	var count := 0
	for attribute in attributes:
		var key := str(attribute)
		if not ATTRIBUTE_TINTS.has(key):
			continue
		tint += ATTRIBUTE_TINTS[key]
		count += 1
	if count <= 0:
		return Color(0.7, 0.58, 0.36, 1.0)
	return Color(tint.r / count, tint.g / count, tint.b / count, 1.0)


func _art_fill(mode: String) -> Color:
	match mode:
		PRESENTATION_SUPPORT_BOARD_MINIMAL:
			return Color(0.14, 0.19, 0.18, 0.98)
		PRESENTATION_CREATURE_BOARD_MINIMAL:
			return Color(0.2, 0.17, 0.13, 0.98)
		_:
			return Color(0.19, 0.16, 0.13, 0.96)


func _stat_color(card: Dictionary, stat: String) -> Color:
	if not _is_creature(card):
		return COLOR_STAT_BASE
	var current := EvergreenRules.get_power(card) if stat == "power" else EvergreenRules.get_remaining_health(card)
	var printed := _printed_power(card) if stat == "power" else _printed_health(card)
	if current > printed:
		return COLOR_STAT_BUFF
	if current < printed:
		return COLOR_STAT_REDUCED
	return COLOR_STAT_BASE


func _printed_power(card: Dictionary) -> int:
	if card.has("power"):
		return int(card.get("power", 0))
	if card.has("current_power"):
		return int(card.get("current_power", 0))
	return int(card.get("base_power", 0))


func _printed_health(card: Dictionary) -> int:
	if card.has("health"):
		return int(card.get("health", 0))
	if card.has("current_health"):
		return int(card.get("current_health", 0))
	return int(card.get("base_health", 0))


func _is_creature(card: Dictionary) -> bool:
	return str(card.get("card_type", "")) == "creature"


func _identifier_to_name(value: String) -> String:
	var words: Array = []
	for piece in value.replace("-", "_").split("_", false):
		if piece.is_empty():
			continue
		words.append(piece.substr(0, 1).to_upper() + piece.substr(1))
	return " ".join(words) if not words.is_empty() else "Card"


func _build_centered_label(name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	_set_full_rect(label)
	return label


func _apply_font_sizes(scale: float) -> void:
	_name_label.add_theme_font_size_override("font_size", _scaled_int(14, scale))
	_subtype_label.add_theme_font_size_override("font_size", _scaled_int(10, scale))
	_rules_label.add_theme_font_size_override("normal_font_size", _scaled_int(18, scale))
	_rules_label.add_theme_font_size_override("bold_font_size", _scaled_int(18, scale))
	_rarity_label.add_theme_font_size_override("font_size", _scaled_int(9, scale))
	_cost_label.add_theme_font_size_override("font_size", _scaled_int(16, scale))
	_attack_label.add_theme_font_size_override("font_size", _scaled_int(22, scale))
	_health_label.add_theme_font_size_override("font_size", _scaled_int(22, scale))


func _set_full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _build_panel_box(panel: PanelContainer, separation := 4, padding := 6, alignment := BoxContainer.ALIGNMENT_BEGIN) -> VBoxContainer:
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
	box.alignment = alignment
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color, border_width := 1, corner_radius := 8) -> void:
	panel.add_theme_stylebox_override("panel", _build_style_box(fill, border, border_width, corner_radius))


func _refresh_corner_radii() -> void:
	_set_panel_corner_radius(_outer_frame, 0)
	_set_panel_corner_radius(_inner_frame, 0)
	for panel in [_rules_panel, _rarity_marker, _cost_badge]:
		_set_panel_corner_radius(panel, _panel_radius(panel, 8))
	_set_panel_corner_radius(_attack_badge, 0)
	# Health badge: keep circular — use half the badge dimension as radius
	var health_radius := maxi(2, int(round(minf(_health_badge.size.x, _health_badge.size.y) * 0.5)))
	_set_panel_corner_radius(_health_badge, health_radius)


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


func _panel_radius(control: Control, fallback: int) -> int:
	if control == null:
		return fallback
	var diameter := minf(control.size.x, control.size.y)
	if diameter <= 0.0:
		return fallback
	return maxi(2, int(round(diameter * 0.12)))


func _scaled_int(base: int, scale: float) -> int:
	return maxi(1, int(round(float(base) * scale)))


func _scaled_border_width(base: int, scale: float) -> int:
	return maxi(1, int(round(float(base) * maxf(scale * 0.6, 1.0))))


func _build_style_box(fill: Color, border: Color, border_width := 1, corner_radius := 8) -> StyleBoxFlat:
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


func _set_mouse_passthrough_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough_recursive(child)
