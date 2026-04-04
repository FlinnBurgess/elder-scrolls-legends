class_name CardDisplayComponent
extends Control

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const CardRelationshipResolverClass = preload("res://src/ui/components/card_relationship_resolver.gd")

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
const KEYWORD_ICON_SIZE := 36
const KEYWORD_ICON_PATHS := {
	"breakthrough": "res://assets/images/keywords/breakthrough.png",
	"charge": "res://assets/images/keywords/charge.png",
	"drain": "res://assets/images/keywords/drain.png",
	"guard": "res://assets/images/keywords/guard.png",
	"last_gasp": "res://assets/images/keywords/last-gasp.png",
	"pilfer": "res://assets/images/keywords/pilfer.png",
	"regenerate": "res://assets/images/keywords/regenerate.png",
	"slay": "res://assets/images/keywords/slay.png",
	"rally": "res://assets/images/keywords/rally.png",
}

const KEYWORD_NAMES := [
	"breakthrough", "charge", "drain", "guard",
	"lethal", "mobilize", "prophecy", "rally", "regenerate", "ward",
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

const ATTRIBUTE_ICON_PATHS := {
	"strength": "res://assets/images/attributes/strength-small.png",
	"intelligence": "res://assets/images/attributes/intelligence-small.png",
	"willpower": "res://assets/images/attributes/willpower-small.png",
	"agility": "res://assets/images/attributes/agility-small.png",
	"endurance": "res://assets/images/attributes/endurance-small.png",
	"neutral": "res://assets/images/attributes/neutral-small.png",
}
const ATTRIBUTE_ICON_SIZE := 22

const PIP_SIZE := 8.0
const PIP_SPACING := 6.0
const PIP_COLOR_ACTIVE := Color(0.95, 0.88, 0.6, 1.0)
const PIP_COLOR_INACTIVE := Color(0.5, 0.48, 0.42, 0.7)

var _card_data: Dictionary = {}
var _presentation_mode := PRESENTATION_FULL
var _is_built := false
var _default_art_texture: Texture2D
var _interactive := true
var _deck_quantity_current := -1
var _deck_quantity_max := -1

var _original_card_data: Dictionary = {}
var _active_wax_wane_phases: Array = []  # e.g. ["wax"], ["wane"], or ["wax", "wane"]
var _relationships: Array = []
var _relationship_index := 0
var _relationship_context: Dictionary = {}

var _content_root: Control
var _outer_frame: PanelContainer
var _inner_frame: PanelContainer
var _name_banner: PanelContainer
var _name_label: Label
var _subtype_banner: PanelContainer
var _subtype_label: Label
var _art_frame: PanelContainer
var _art_clip: Control
var _art_texture: TextureRect
var _rules_panel: PanelContainer
var _rules_label: RichTextLabel
var _rarity_marker: PanelContainer
var _rarity_label: Label
var _cost_badge: TextureRect
var _cost_label: Label
var _attack_badge: TextureRect
var _attack_label: Label
var _health_badge: TextureRect
var _health_label: Label
var _ward_overlay: ColorRect
var _shackle_overlay: TextureRect
var _lethal_particles: GPUParticles2D
var _attribute_icons_container: VBoxContainer
var _keyword_icons_container: HBoxContainer
var _augment_badge_container: VBoxContainer
var _quantity_badge: Label
var _charges_badge: Label
var _pips_container: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = _recommended_minimum_size(_presentation_mode)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	if not _is_built:
		_build_internal_nodes()
	_refresh_all()
	_refresh_all.call_deferred()


func _process(_delta: float) -> void:
	if _ward_overlay != null and _ward_overlay.visible:
		_ward_overlay.queue_redraw()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _is_built:
		_refresh_all()


func set_card(card: Dictionary) -> void:
	_card_data = card.duplicate(true)
	_original_card_data = card.duplicate(true)
	_relationship_index = 0
	_rebuild_relationships()
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
	_original_card_data = card.duplicate(true)
	_relationship_index = 0
	_rebuild_relationships()
	_refresh_all()


func set_wax_wane_phases(phases: Array) -> void:
	_active_wax_wane_phases = phases
	if _is_built and not _card_data.is_empty():
		_rules_label.text = _rules_bbcode(_card_data)


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	if _is_built:
		_refresh_visibility()


func set_deck_quantity(current: int, max_copies: int) -> void:
	_deck_quantity_current = current
	_deck_quantity_max = max_copies
	if _is_built:
		_refresh_quantity_badge()
		_refresh_deck_grey_out()


func get_art_texture() -> Texture2D:
	if _art_texture != null and _art_texture.texture != null:
		return _art_texture.texture
	return _get_default_art_texture()


func set_relationship_context(context: Dictionary) -> void:
	_relationship_context = context.duplicate(true)
	_rebuild_relationships()


func cycle_relationship(direction: int) -> void:
	if _relationships.is_empty():
		return
	# Total entries = original card (index 0) + relationships
	var total := _relationships.size() + 1
	_relationship_index = (_relationship_index + direction) % total
	if _relationship_index < 0:
		_relationship_index += total
	_apply_relationship_view()


func reset_relationship_view() -> void:
	if _relationship_index == 0:
		return
	_relationship_index = 0
	if not _original_card_data.is_empty():
		_card_data = _original_card_data.duplicate(true)
	_refresh_all()


func has_relationships() -> bool:
	return not _relationships.is_empty()


func get_relationship_count() -> int:
	return _relationships.size()


func _rebuild_relationships() -> void:
	var was_cycling := _relationship_index != 0
	_relationships = CardRelationshipResolverClass.resolve(_card_data if _original_card_data.is_empty() else _original_card_data, _relationship_context)
	_relationship_index = 0
	if was_cycling and not _original_card_data.is_empty():
		_card_data = _original_card_data.duplicate(true)
	_refresh_all()


func _apply_relationship_view() -> void:
	if _relationship_index == 0:
		# Show original card
		if not _original_card_data.is_empty():
			_card_data = _original_card_data.duplicate(true)
			_refresh_all()
	else:
		var rel: Dictionary = _relationships[_relationship_index - 1]
		if rel.get("type", "") == "card":
			_card_data = rel.get("card_data", {}).duplicate(true)
			_refresh_all()
		elif rel.get("type", "") == "text":
			# Restore original card visuals but replace rules text
			if not _original_card_data.is_empty():
				_card_data = _original_card_data.duplicate(true)
			_card_data["rules_text"] = str(rel.get("text", ""))
			# Clear triggered_abilities so _rules_preview doesn't extract keywords from them
			_refresh_all()


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

	_art_clip = Control.new()
	_art_clip.name = "ArtClip"
	_art_clip.clip_contents = true
	_art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_root.add_child(_art_clip)

	_art_texture = TextureRect.new()
	_art_texture.name = "ArtTexture"
	_art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_clip.add_child(_art_texture)

	# Ward overlay sits above artwork but below banners and badges
	_ward_overlay = ColorRect.new()
	_ward_overlay.name = "WardOverlay"
	_ward_overlay.color = Color.WHITE
	_ward_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ward_overlay.visible = false
	var ward_shader := load("res://assets/shaders/ward_mist.gdshader") as Shader
	if ward_shader:
		var ward_mat := ShaderMaterial.new()
		ward_mat.shader = ward_shader
		_ward_overlay.material = ward_mat
	_art_clip.add_child(_ward_overlay)

	# Shackle overlay sits above artwork but below banners and badges
	_shackle_overlay = TextureRect.new()
	_shackle_overlay.name = "ShackleOverlay"
	_shackle_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shackle_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_shackle_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shackle_overlay.visible = false
	var shackle_tex := _load_texture_from_path("res://assets/images/keywords/shackle.png")
	if shackle_tex:
		_shackle_overlay.texture = shackle_tex
	_shackle_overlay.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_art_clip.add_child(_shackle_overlay)

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

	_cost_badge = TextureRect.new()
	_cost_badge.name = "CostBadge"
	_cost_badge.texture = preload("res://assets/images/cards/magicka-icon.png")
	_cost_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cost_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_content_root.add_child(_cost_badge)
	_cost_label = _build_centered_label("CostLabel", 16)
	_cost_label.add_theme_constant_override("outline_size", 3)
	_cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_content_root.add_child(_cost_label)

	_attribute_icons_container = VBoxContainer.new()
	_attribute_icons_container.name = "AttributeIcons"
	_attribute_icons_container.add_theme_constant_override("separation", 2)
	_attribute_icons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attribute_icons_container.visible = false
	_content_root.add_child(_attribute_icons_container)

	_attack_badge = TextureRect.new()
	_attack_badge.name = "AttackBadge"
	_attack_badge.texture = preload("res://assets/images/cards/attack-icon.png")
	_attack_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attack_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_content_root.add_child(_attack_badge)
	_attack_label = _build_centered_label("AttackLabel", 18)
	var bold_font := SystemFont.new()
	bold_font.font_weight = 700
	_attack_label.add_theme_font_override("font", bold_font)
	_content_root.add_child(_attack_label)

	_lethal_particles = GPUParticles2D.new()
	_lethal_particles.name = "LethalParticles"
	_lethal_particles.emitting = false
	_lethal_particles.amount = 16
	_lethal_particles.lifetime = 1.4
	_lethal_particles.visibility_rect = Rect2(-30, -50, 60, 60)
	var lethal_mat := ParticleProcessMaterial.new()
	lethal_mat.direction = Vector3(0, -1, 0)
	lethal_mat.spread = 25.0
	lethal_mat.initial_velocity_min = 8.0
	lethal_mat.initial_velocity_max = 18.0
	lethal_mat.gravity = Vector3(0, -2, 0)
	lethal_mat.scale_min = 2.5
	lethal_mat.scale_max = 4.5
	lethal_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	lethal_mat.emission_box_extents = Vector3(12, 6, 0)
	lethal_mat.color = Color(0.2, 0.9, 0.3, 1.0)
	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 1.0, 0.4, 1.0))
	gradient.add_point(0.5, Color(0.15, 0.8, 0.3, 0.7))
	gradient.set_color(2, Color(0.1, 0.6, 0.2, 0.0))
	color_ramp.gradient = gradient
	lethal_mat.color_ramp = color_ramp
	_lethal_particles.process_material = lethal_mat
	_content_root.add_child(_lethal_particles)

	_health_badge = TextureRect.new()
	_health_badge.name = "HealthBadge"
	_health_badge.texture = preload("res://assets/images/cards/defense-icon.png")
	_health_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_health_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_content_root.add_child(_health_badge)
	_health_label = _build_centered_label("HealthLabel", 18)
	var bold_font_h := SystemFont.new()
	bold_font_h.font_weight = 700
	_health_label.add_theme_font_override("font", bold_font_h)
	_content_root.add_child(_health_label)

	_keyword_icons_container = HBoxContainer.new()
	_keyword_icons_container.name = "KeywordIcons"
	_keyword_icons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_keyword_icons_container.add_theme_constant_override("separation", 2)
	_keyword_icons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keyword_icons_container.visible = false
	_content_root.add_child(_keyword_icons_container)

	_augment_badge_container = VBoxContainer.new()
	_augment_badge_container.name = "AugmentBadges"
	_augment_badge_container.add_theme_constant_override("separation", 2)
	_augment_badge_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_augment_badge_container.visible = false
	_content_root.add_child(_augment_badge_container)

	_quantity_badge = Label.new()
	_quantity_badge.name = "QuantityBadge"
	_quantity_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quantity_badge.add_theme_font_size_override("font_size", 14)
	_quantity_badge.add_theme_color_override("font_color", Color.WHITE)
	_quantity_badge.visible = false
	_content_root.add_child(_quantity_badge)

	_charges_badge = Label.new()
	_charges_badge.name = "ChargesBadge"
	_charges_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charges_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_charges_badge.add_theme_font_size_override("font_size", 14)
	_charges_badge.add_theme_color_override("font_color", Color.WHITE)
	_charges_badge.visible = false
	_content_root.add_child(_charges_badge)

	_pips_container = HBoxContainer.new()
	_pips_container.name = "PipsContainer"
	_pips_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips_container.add_theme_constant_override("separation", int(PIP_SPACING))
	_pips_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips_container.visible = false
	_content_root.add_child(_pips_container)

	_set_mouse_passthrough_recursive(_content_root)
	_is_built = true


func _refresh_all() -> void:
	if not _is_built:
		return
	_refresh_content()
	_refresh_styles()
	_refresh_visibility()
	_refresh_pips()
	_layout_internal_nodes()
	_fit_rules_font_size()
	_refresh_quantity_badge()
	_refresh_charges_badge()
	_refresh_deck_grey_out()


func _refresh_content() -> void:
	if not _is_built:
		return
	_art_texture.texture = _resolve_art_texture(_card_data)
	if _card_data.has("_effective_cost"):
		_cost_label.text = str(int(_card_data.get("_effective_cost", 0)))
	else:
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
	_refresh_keyword_icons()
	_refresh_augment_badges()
	_refresh_attribute_icons()


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
	# Cost badge – magicka icon texture
	_cost_badge.modulate = Color.WHITE
	# Attack badge – texture icon; green tint for lethal
	var has_lethal := _is_creature(_card_data) and EvergreenRules.has_keyword(_card_data, EvergreenRules.KEYWORD_LETHAL)
	_attack_badge.modulate = Color(0.4, 1.0, 0.5, 1.0) if has_lethal else Color.WHITE
	# Health badge – texture icon
	_health_badge.modulate = Color.WHITE
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
	if _card_data.has("_effective_cost"):
		_cost_label.add_theme_color_override("font_color", COLOR_STAT_BUFF)
	else:
		_cost_label.add_theme_color_override("font_color", Color.BLACK)
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
	_cost_label.visible = full
	# Attribute icons visibility is managed by _refresh_attribute_icons based on card data
	_attack_badge.visible = is_creature and (full or creature_minimal)
	_health_badge.visible = is_creature and (full or creature_minimal)
	_ward_overlay.visible = _interactive and is_creature and EvergreenRules.has_keyword(_card_data, EvergreenRules.KEYWORD_WARD)
	_shackle_overlay.visible = _interactive and is_creature and (creature_minimal) and EvergreenRules.has_raw_status(_card_data, EvergreenRules.STATUS_SHACKLED)
	var show_lethal := _interactive and is_creature and (full or creature_minimal) and EvergreenRules.has_keyword(_card_data, EvergreenRules.KEYWORD_LETHAL)
	_lethal_particles.emitting = show_lethal
	_lethal_particles.visible = show_lethal


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

	# Cost badge – magicka icon, top-left overlapping the frame
	var cost_side := 42.0 * scale
	var cost_size := Vector2(cost_side, cost_side)
	_cost_badge.size = cost_size
	_cost_badge.position = _outer_frame.position + Vector2(-8.0 * scale, -8.0 * scale)
	_cost_label.size = cost_size
	_cost_label.position = _cost_badge.position

	# Art frame – dominates the card (~58% of inner height)
	var art_top := inner_rect.position.y + content_padding
	var art_height := inner_rect.size.y * 0.70
	_art_frame.position = Vector2(inner_rect.position.x + content_padding, art_top)
	_art_frame.size = Vector2(content_width, art_height)

	# Name banner and art clip share the border inset
	var art_border_w := float(_scaled_border_width(2, scale))

	var banner_height := 28.0 * scale
	_name_banner.position = _art_frame.position + Vector2(art_border_w, art_border_w)
	_name_banner.size = Vector2(_art_frame.size.x - art_border_w * 2.0, banner_height)
	# Subtype banner – centered horizontally, overlapping bottom of name banner
	var subtype_height := 12.0 * scale
	var subtype_width := _art_frame.size.x * 0.45
	var subtype_bottom_y := _name_banner.position.y + banner_height - subtype_height * 0.5 + subtype_height
	_subtype_banner.position = Vector2(
		_art_frame.position.x + (_art_frame.size.x - subtype_width) * 0.5,
		subtype_bottom_y - subtype_height
	)
	_subtype_banner.size = Vector2(subtype_width, subtype_height)

	# Art clip fills the art frame (inset by border), with the texture shifted
	# down slightly so the name/subtype banners don't obscure key artwork.
	_art_clip.position = _art_frame.position + Vector2.ONE * art_border_w
	_art_clip.size = _art_frame.size - Vector2.ONE * art_border_w * 2.0
	var art_shift := art_height * 0.08
	_art_texture.position = Vector2(0, art_shift)
	_art_texture.size = Vector2(_art_clip.size.x, _art_clip.size.y + art_shift)

	# Stat badges – attack diamond + health circle, straddling art bottom edge
	_layout_stat_badges(inner_rect, Rect2(_art_frame.position, _art_frame.size), scale, true)

	_layout_ward_overlay()
	_keyword_icons_container.visible = false
	_layout_augment_badges()
	_layout_attribute_icons()

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

	# Relationship pips
	_layout_pips()


func _layout_creature_board_minimal(inner_rect: Rect2) -> void:
	var scale := _layout_scale(PRESENTATION_CREATURE_BOARD_MINIMAL)
	var art_padding := 6.0 * scale
	_art_frame.position = inner_rect.position + Vector2.ONE * art_padding
	_art_frame.size = Vector2(maxf(inner_rect.size.x - art_padding * 2.0, 0.0), maxf(inner_rect.size.y - art_padding * 2.0, 0.0))
	_art_clip.position = _art_frame.position
	_art_clip.size = _art_frame.size
	_art_texture.position = Vector2.ZERO
	_art_texture.size = _art_frame.size
	_layout_stat_badges(inner_rect, Rect2(_art_frame.position, _art_frame.size), scale, true)
	_layout_ward_overlay()
	_layout_shackle_overlay()
	_layout_keyword_icons()
	_layout_augment_badges()
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
	_cost_label.position = Vector2.ZERO
	_cost_label.size = Vector2.ZERO
	_attribute_icons_container.visible = false


func _layout_support_board_minimal(inner_rect: Rect2) -> void:
	var scale := _layout_scale(PRESENTATION_SUPPORT_BOARD_MINIMAL)
	var square_size := minf(inner_rect.size.x, inner_rect.size.y)
	var square_origin := inner_rect.position + Vector2((inner_rect.size.x - square_size) * 0.5, (inner_rect.size.y - square_size) * 0.5)
	_art_frame.position = square_origin + Vector2.ONE * (6.0 * scale)
	_art_frame.size = Vector2.ONE * maxf(square_size - 12.0 * scale, 0.0)
	_art_clip.position = _art_frame.position
	_art_clip.size = _art_frame.size
	_art_texture.position = Vector2.ZERO
	_art_texture.size = _art_frame.size
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
	_cost_label.position = Vector2.ZERO
	_cost_label.size = Vector2.ZERO
	_attribute_icons_container.visible = false
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
	var def_id := str(card.get("definition_id", "")).strip_edges()
	if not def_id.is_empty():
		var inferred := _load_texture_from_path("res://assets/images/cards/" + def_id + ".png")
		if inferred != null:
			return inferred
	return _get_default_art_texture()


func _layout_stat_badges(inner_rect: Rect2, art_rect: Rect2, scale: float, esl_style := false) -> void:
	var badge_side := maxf(40.0 * scale, 40.0) * 1.95
	var health_side := maxf(54.0 * scale, 54.0) * 1.265
	var attack_size := Vector2(badge_side, badge_side * 1.6)
	var health_size := Vector2(health_side, health_side * 1.2)
	var badge_margin := 6.0 * scale
	_attack_badge.size = attack_size
	_health_badge.size = health_size
	_attack_badge.pivot_offset = attack_size * 0.5
	_health_badge.pivot_offset = health_size * 0.5
	if esl_style:
		# Attack: icon texture, Health: circle (no rotation, high corner radius)
		var badge_center_y := art_rect.position.y + art_rect.size.y * 0.75
		var badge_inset := -6.0 * scale
		# Attack icon — overlaps left card edge
		_attack_badge.rotation_degrees = 0.0
		_attack_badge.position = Vector2(
			inner_rect.position.x - attack_size.x * 0.35,
			badge_center_y - attack_size.y * 0.5
		)
		# Health icon — overlaps right card edge
		_health_badge.rotation_degrees = 0.0
		_health_badge.position = Vector2(
			inner_rect.position.x + inner_rect.size.x - health_size.x * 0.65,
			badge_center_y - health_size.y * 0.5
		)
		# Attack label centered over icon
		_attack_label.size = attack_size
		_attack_label.position = _attack_badge.position + Vector2(0.0, 1.0 * scale)
		_attack_label.rotation_degrees = 0.0
		# Health label centered over icon, nudged up-right to sit in shield center
		_health_label.size = health_size
		_health_label.position = _health_badge.position + Vector2(2.0 * scale, -2.0 * scale)
		_health_label.rotation_degrees = 0.0
	else:
		# Board-minimal: icons sized to fit compactly
		_attack_badge.rotation_degrees = 0.0
		_health_badge.rotation_degrees = 0.0
		var rect_w := maxf(28.0 * scale, 28.0) * 1.95
		var attack_rect_size := Vector2(rect_w, rect_w * 1.6)
		var health_rect_size := Vector2(rect_w * 0.6, rect_w * 0.6 * 1.2)
		_attack_badge.size = attack_rect_size
		_health_badge.size = health_rect_size
		_attack_badge.pivot_offset = attack_rect_size * 0.5
		_health_badge.pivot_offset = health_rect_size * 0.5
		var badge_top := art_rect.position.y + art_rect.size.y - attack_rect_size.y - badge_margin
		badge_top = clampf(badge_top, art_rect.position.y, maxf(art_rect.position.y + art_rect.size.y - attack_rect_size.y, art_rect.position.y))
		_attack_badge.position = Vector2(inner_rect.position.x - attack_rect_size.x * 0.35, badge_top)
		var health_top := art_rect.position.y + art_rect.size.y - health_rect_size.y - badge_margin
		health_top = clampf(health_top, art_rect.position.y, maxf(art_rect.position.y + art_rect.size.y - health_rect_size.y, art_rect.position.y))
		_health_badge.position = Vector2(inner_rect.position.x + inner_rect.size.x - health_rect_size.x * 0.65, health_top)
		_attack_label.size = attack_rect_size
		_attack_label.position = _attack_badge.position + Vector2(0.0, 1.0 * scale)
		_attack_label.rotation_degrees = 0.0
		_health_label.size = health_rect_size
		_health_label.position = _health_badge.position + Vector2(2.0 * scale, -2.0 * scale)
		_health_label.rotation_degrees = 0.0
	# Position lethal particles at the attack badge center
	if _lethal_particles != null:
		var attack_center := _attack_badge.position + _attack_badge.pivot_offset
		_lethal_particles.position = attack_center


func _refresh_keyword_icons() -> void:
	if _keyword_icons_container == null:
		return
	for child in _keyword_icons_container.get_children():
		_keyword_icons_container.remove_child(child)
		child.free()
	if not _is_creature(_card_data):
		return
	for kw in KEYWORD_ICON_PATHS:
		if not _card_has_keyword_or_ability(kw):
			continue
		var icon_texture := _load_texture_from_path(KEYWORD_ICON_PATHS[kw])
		if icon_texture == null:
			continue
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(KEYWORD_ICON_SIZE, KEYWORD_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_keyword_icons_container.add_child(icon)


func _card_has_keyword_or_ability(kw: String) -> bool:
	if EvergreenRules.has_keyword(_card_data, kw):
		return true
	for trigger in _card_data.get("triggered_abilities", []):
		if typeof(trigger) == TYPE_DICTIONARY and str(trigger.get("family", "")) == kw:
			return true
	return false


func _layout_keyword_icons() -> void:
	if _keyword_icons_container == null:
		return
	var icon_count := _keyword_icons_container.get_child_count()
	if icon_count == 0:
		_keyword_icons_container.visible = false
		return
	_keyword_icons_container.visible = true
	var total_width := float(icon_count * KEYWORD_ICON_SIZE + (icon_count - 1) * 2)
	var container_x := _art_frame.position.x + (_art_frame.size.x - total_width) * 0.5
	var container_y := _art_frame.position.y + _art_frame.size.y - KEYWORD_ICON_SIZE - 4.0
	_keyword_icons_container.position = Vector2(container_x, container_y)
	_keyword_icons_container.size = Vector2(total_width, KEYWORD_ICON_SIZE)


func _refresh_augment_badges() -> void:
	if _augment_badge_container == null:
		return
	for child in _augment_badge_container.get_children():
		_augment_badge_container.remove_child(child)
		child.free()
	if _presentation_mode != PRESENTATION_FULL:
		_augment_badge_container.visible = false
		return
	var augments = _card_data.get("_augments", [])
	if typeof(augments) != TYPE_ARRAY or augments.is_empty():
		_augment_badge_container.visible = false
		return
	_augment_badge_container.visible = true
	for aug in augments:
		if typeof(aug) != TYPE_DICTIONARY:
			continue
		var badge := Label.new()
		badge.text = str(aug.get("name", ""))
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(0.26, 0.8, 0.4, 1.0))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_augment_badge_container.add_child(badge)


func _layout_augment_badges() -> void:
	if _augment_badge_container == null or not _augment_badge_container.visible:
		return
	# Position on the right side of the art frame.
	var badge_x := _art_frame.position.x + _art_frame.size.x - 4.0
	var badge_y := _art_frame.position.y + 4.0
	var badge_width := _art_frame.size.x * 0.45
	_augment_badge_container.position = Vector2(badge_x - badge_width, badge_y)
	_augment_badge_container.size = Vector2(badge_width, _art_frame.size.y * 0.5)


func _refresh_attribute_icons() -> void:
	if _attribute_icons_container == null:
		return
	for child in _attribute_icons_container.get_children():
		_attribute_icons_container.remove_child(child)
		child.free()
	if _presentation_mode != PRESENTATION_FULL:
		_attribute_icons_container.visible = false
		return
	var attributes: Array = _card_data.get("attributes", [])
	if attributes.is_empty():
		attributes = ["neutral"]
	_attribute_icons_container.visible = true
	for attribute in attributes:
		var key := str(attribute)
		var path: String = ATTRIBUTE_ICON_PATHS.get(key, "")
		if path.is_empty():
			continue
		var tex := _load_texture_from_path(path)
		if tex == null:
			continue
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ATTRIBUTE_ICON_SIZE, ATTRIBUTE_ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_attribute_icons_container.add_child(icon)


func _layout_attribute_icons() -> void:
	if _attribute_icons_container == null or not _attribute_icons_container.visible:
		return
	var scale := _layout_scale(PRESENTATION_FULL)
	var icon_side := ATTRIBUTE_ICON_SIZE * scale
	var icon_count := _attribute_icons_container.get_child_count()
	for child in _attribute_icons_container.get_children():
		child.custom_minimum_size = Vector2(icon_side, icon_side)
	var total_height := icon_side * icon_count + 2.0 * maxf(icon_count - 1, 0)
	_attribute_icons_container.size = Vector2(icon_side, total_height)
	# Center horizontally under the cost badge
	var center_x := _cost_badge.position.x + _cost_badge.size.x * 0.5
	_attribute_icons_container.position = Vector2(center_x - icon_side * 0.5 - 10.0, _cost_badge.position.y + _cost_badge.size.y + 2.0 * scale)


func _layout_ward_overlay() -> void:
	if _ward_overlay == null:
		return
	# Extend past clip bounds so the shader's edge fade happens outside the visible art
	var h_pad := _art_clip.size.x * 0.12
	var v_pad := _art_clip.size.y * 0.08
	_ward_overlay.position = Vector2(-h_pad, -v_pad)
	_ward_overlay.size = _art_clip.size + Vector2(h_pad * 2, v_pad * 2)


func _layout_shackle_overlay() -> void:
	if _shackle_overlay == null:
		return
	var scale_factor := 1.5
	var scaled_size := _art_clip.size * scale_factor
	var offset := (_art_clip.size - scaled_size) * 0.5
	_shackle_overlay.position = offset
	_shackle_overlay.size = scaled_size


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
	# Append dynamically-granted keywords not already in the list
	for kw in KEYWORD_NAMES:
		var display_name: String = kw.substr(0, 1).to_upper() + kw.substr(1)
		if keywords.has(display_name):
			continue
		if EvergreenRules.has_keyword(card, kw):
			keywords.append(display_name)
	if keywords.is_empty():
		return rules_text
	# Show stacked keyword counts (e.g. "Rally 2") for stackable keywords
	var display_keywords: Array[String] = []
	for kw_display in keywords:
		var kw_id := kw_display.to_lower()
		if kw_id == "rally":
			var count := EvergreenRules.count_keyword(card, kw_id)
			if count > 1:
				display_keywords.append(kw_display + " " + str(count))
			else:
				display_keywords.append(kw_display)
		else:
			display_keywords.append(kw_display)
	var keyword_line := ", ".join(display_keywords)
	if remaining.is_empty() and rules_text.is_empty():
		return keyword_line
	if remaining.is_empty():
		return keyword_line
	return keyword_line + "\n" + remaining


func _rules_bbcode(card: Dictionary) -> String:
	var plain := _rules_preview(card)
	plain = _apply_wax_wane_colors(plain)
	plain = _apply_item_buff_colors(card, plain)
	# Append augment descriptions in green (only on main card view, not alt-views).
	if _relationship_index == 0:
		var augment_text := _augment_bbcode(card)
		if not augment_text.is_empty():
			if not plain.is_empty():
				plain += "\n"
			plain += augment_text
	var newline_pos := plain.find("\n")
	if newline_pos < 0:
		var has_keywords := _has_extracted_keywords(card)
		if has_keywords:
			return "[center][b]" + plain + "[/b][/center]"
		return "[center]" + plain + "[/center]"
	var keyword_line := plain.substr(0, newline_pos)
	var rest := plain.substr(newline_pos + 1)
	return "[center][b]" + keyword_line + "[/b]\n" + rest + "[/center]"


func _augment_bbcode(card: Dictionary) -> String:
	var augments = card.get("_augments", [])
	if typeof(augments) != TYPE_ARRAY or augments.is_empty():
		return ""
	var parts: Array = []
	for aug in augments:
		if typeof(aug) != TYPE_DICTIONARY:
			continue
		var desc := str(aug.get("description", ""))
		if not desc.is_empty():
			parts.append("[color=#44cc66]%s[/color]" % desc)
	return "\n".join(parts)


func _apply_wax_wane_colors(text: String) -> String:
	if _active_wax_wane_phases.is_empty():
		return text
	var active_color := "#66cc66"
	if _active_wax_wane_phases.has("wax"):
		text = text.replace("Wax:", "[color=%s]Wax:[/color]" % active_color)
	if _active_wax_wane_phases.has("wane"):
		text = text.replace("Wane:", "[color=%s]Wane:[/color]" % active_color)
	return text


func _apply_item_buff_colors(card: Dictionary, text: String) -> String:
	if str(card.get("card_type", "")) != "item":
		return text
	var p_bonus := int(card.get("power_bonus", 0))
	var h_bonus := int(card.get("health_bonus", 0))
	if p_bonus == 0 and h_bonus == 0:
		return text
	# Replace +X/+Y stat grant pattern with buffed values in green
	var pattern := RegEx.new()
	pattern.compile("\\+\\d+/\\+\\d+")
	var m := pattern.search(text)
	if not m:
		return text
	var equip_power := int(card.get("equip_power_bonus", 0))
	var equip_health := int(card.get("equip_health_bonus", 0))
	var buffed_text := "[color=#66cc66]+%d/+%d[/color]" % [equip_power, equip_health]
	return text.substr(0, m.get_start()) + buffed_text + text.substr(m.get_end())


func _has_extracted_keywords(card: Dictionary) -> bool:
	for kw in KEYWORD_NAMES:
		if EvergreenRules.has_keyword(card, kw):
			return true
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
	if card.has("_printed_power"):
		return int(card.get("_printed_power", 0))
	if card.has("power"):
		return int(card.get("power", 0))
	if card.has("current_power"):
		return int(card.get("current_power", 0))
	return int(card.get("base_power", 0))


func _printed_health(card: Dictionary) -> int:
	if card.has("_printed_health"):
		return int(card.get("_printed_health", 0))
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
	_cost_label.add_theme_font_size_override("font_size", _scaled_int(20, scale))
	_attack_label.add_theme_font_size_override("font_size", _scaled_int(22, scale))
	_health_label.add_theme_font_size_override("font_size", _scaled_int(22, scale))


func _fit_rules_font_size() -> void:
	if _presentation_mode != PRESENTATION_FULL:
		return
	if _rules_label.text.is_empty():
		return
	# Defer to next frame so the label has valid layout measurements
	_fit_rules_font_size_deferred.call_deferred()


func _fit_rules_font_size_deferred() -> void:
	var scale := _layout_scale()
	var available_height := _rules_panel.size.y - 12.0
	if available_height <= 0.0:
		return
	var max_size := _scaled_int(15, scale)
	var min_size := _scaled_int(8, scale)
	var font_size := max_size
	while font_size > min_size:
		_rules_label.add_theme_font_size_override("normal_font_size", font_size)
		_rules_label.add_theme_font_size_override("bold_font_size", font_size)
		if _rules_label.get_content_height() <= int(available_height):
			break
		font_size -= 1


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
	for panel in [_rules_panel, _rarity_marker]:
		_set_panel_corner_radius(panel, _panel_radius(panel, 8))


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


func _refresh_quantity_badge() -> void:
	if _quantity_badge == null:
		return
	if _deck_quantity_current < 0:
		_quantity_badge.visible = false
		return
	_quantity_badge.text = str(_deck_quantity_current) + "/" + str(_deck_quantity_max)
	_quantity_badge.visible = true
	# Position at top-right corner of the outer frame
	var scale := _layout_scale()
	var badge_w := 36.0 * scale
	var badge_h := 22.0 * scale
	_quantity_badge.add_theme_font_size_override("font_size", _scaled_int(14, scale))
	_quantity_badge.size = Vector2(badge_w, badge_h)
	_quantity_badge.position = Vector2(
		_outer_frame.position.x + _outer_frame.size.x - badge_w - 2.0 * scale,
		_outer_frame.position.y + 2.0 * scale
	)
	# Background style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	style.corner_radius_top_left = _scaled_int(4, scale)
	style.corner_radius_top_right = _scaled_int(4, scale)
	style.corner_radius_bottom_left = _scaled_int(4, scale)
	style.corner_radius_bottom_right = _scaled_int(4, scale)
	_quantity_badge.add_theme_stylebox_override("normal", style)


func _refresh_deck_grey_out() -> void:
	if _deck_quantity_current < 0:
		return
	if _deck_quantity_current >= _deck_quantity_max:
		_content_root.modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		_content_root.modulate = Color.WHITE


func _refresh_pips() -> void:
	if _pips_container == null:
		return
	for child in _pips_container.get_children():
		child.free()
	if _relationships.is_empty():
		_pips_container.visible = false
		return
	_pips_container.visible = _presentation_mode == PRESENTATION_FULL
	var total := _relationships.size() + 1
	for i in range(total):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
		pip.size = Vector2(PIP_SIZE, PIP_SIZE)
		pip.color = PIP_COLOR_ACTIVE if i == _relationship_index else PIP_COLOR_INACTIVE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips_container.add_child(pip)


func _layout_pips() -> void:
	if _pips_container == null or not _pips_container.visible or _outer_frame == null:
		return
	var pip_count := _pips_container.get_child_count()
	if pip_count == 0:
		return
	var total_width := PIP_SIZE * pip_count + PIP_SPACING * (pip_count - 1)
	var pip_x := _outer_frame.position.x + _outer_frame.size.x - total_width - 12.0
	var pip_y := _outer_frame.position.y + _outer_frame.size.y - PIP_SIZE - 10.0
	_pips_container.position = Vector2(pip_x, pip_y)
	_pips_container.size = Vector2(total_width, PIP_SIZE)


func _refresh_charges_badge() -> void:
	if _charges_badge == null:
		return
	if _presentation_mode != PRESENTATION_SUPPORT_BOARD_MINIMAL:
		_charges_badge.visible = false
		return
	var remaining = _card_data.get("remaining_support_uses", null)
	if remaining == null:
		_charges_badge.visible = false
		return
	var uses_left := int(remaining)
	_charges_badge.text = str(uses_left)
	_charges_badge.visible = true
	# Position at bottom-right corner of the art frame
	var badge_w := 24.0
	var badge_h := 20.0
	_charges_badge.add_theme_font_size_override("font_size", 13)
	_charges_badge.size = Vector2(badge_w, badge_h)
	_charges_badge.position = Vector2(
		_art_frame.position.x + _art_frame.size.x - badge_w - 2.0,
		_art_frame.position.y + _art_frame.size.y - badge_h - 2.0
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.78)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_charges_badge.add_theme_stylebox_override("normal", style)


func _set_mouse_passthrough_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough_recursive(child)
