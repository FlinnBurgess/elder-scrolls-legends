class_name CardDisplayComponent
extends Control

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const CardRelationshipResolverClass = preload("res://src/ui/components/card_relationship_resolver.gd")
const WARD_SHADER = preload("res://assets/shaders/ward_mist.gdshader")
const PREMIUM_GOLD_SHADER = preload("res://assets/shaders/premium_gold.gdshader")
const PROPHECY_GLOW_SHADER = preload("res://assets/shaders/prophecy_glow.gdshader")

const PRESENTATION_FULL := "full"
const PRESENTATION_CREATURE_BOARD_MINIMAL := "creature_board_minimal"
const PRESENTATION_SUPPORT_BOARD_MINIMAL := "support_board_minimal"

const FULL_LAYOUT_BASE_SIZE := Vector2(220, 340)
const CREATURE_BOARD_LAYOUT_BASE_SIZE := Vector2(251, 437)
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
	"veteran": "res://assets/images/keywords/veteran.png",
}
const AURA_ICON_PATH := "res://assets/images/keywords/aura.png"

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
# Inline attribute icons in rules text scale with the rules font size.
# Slightly larger than cap height so icons read as embedded glyphs rather than dominating the text.
const ATTRIBUTE_INLINE_ICON_SCALE := 1.3
const ATTRIBUTE_INLINE_ICON_DEFAULT_FONT_SIZE := 18

const PIP_SIZE := 8.0
const PIP_SPACING := 6.0
const PIP_COLOR_ACTIVE := Color(0.95, 0.88, 0.6, 1.0)
const PIP_COLOR_INACTIVE := Color(0.5, 0.48, 0.42, 0.7)

# ESL template overlay assets (Saiyan/tesl-card-generator). Attribute sets map
# to frame keys via a sorted, comma-joined attribute tuple.
const ESL_TEMPLATE_DIR := "res://assets/images/card_templates/"
const ESL_FRAME_BY_ATTRIBUTES := {
	# Mono
	"neutral": "mono_neutral",
	"strength": "mono_strength",
	"intelligence": "mono_intelligence",
	"willpower": "mono_willpower",
	"agility": "mono_agility",
	"endurance": "mono_endurance",
	# Duo (alphabetical attribute order → class frame)
	"agility,strength": "duo_archer",
	"agility,intelligence": "duo_assassin",
	"intelligence,strength": "duo_battlemage",
	"strength,willpower": "duo_crusader",
	"intelligence,willpower": "duo_mage",
	"agility,willpower": "duo_monk",
	"agility,endurance": "duo_scout",
	"endurance,intelligence": "duo_sorcerer",
	"endurance,willpower": "duo_spellsword",
	"endurance,strength": "duo_warrior",
	# Trio (base five + Houses of Morrowind)
	"agility,intelligence,willpower": "trio_blue_yellow_green",      # Aldmeri Dominion
	"endurance,intelligence,strength": "trio_red_blue_purple",       # Daggerfall Covenant
	"agility,endurance,strength": "trio_red_green_purple",           # Ebonheart Pact
	"agility,endurance,willpower": "trio_yellow_green_purple",       # Empire of Cyrodiil
	"intelligence,strength,willpower": "trio_red_blue_yellow",       # Guildsworn
	"endurance,strength,willpower": "trio_redoran",                  # House Redoran
	"agility,endurance,intelligence": "trio_telvanni",               # House Telvanni
	"agility,strength,willpower": "trio_hlaalu",                     # House Hlaalu
	"endurance,intelligence,willpower": "trio_tribunal",             # Tribunal Temple
	"agility,intelligence,strength": "trio_dagoth",                  # House Dagoth
}
const ESL_TEMPLATE_RARITY_PATHS := {
	"common": "res://assets/images/card_templates/rarity_common.png",
	"rare": "res://assets/images/card_templates/rarity_rare.png",
	"epic": "res://assets/images/card_templates/rarity_epic.png",
	"legendary": "res://assets/images/card_templates/rarity_legendary.png",
	"legendary_duo": "res://assets/images/card_templates/rarity_legendary_duo.png",
	"legendary_trio": "res://assets/images/card_templates/rarity_legendary_trio.png",
}
const ESL_TEMPLATE_PH_PATH := "res://assets/images/card_templates/power_health_bg.png"
const ESL_TEMPLATE_SUPPORT_PATH := "res://assets/images/card_templates/support_bg.png"

# Normalised coordinates on the 440x680 reference canvas.
static var ESL_ART_RECT_N := Rect2(60.0 / 440.0, 120.0 / 680.0, 320.0 / 440.0, 420.0 / 680.0)
static var ESL_COST_RECT_N := Rect2(25.0 / 440.0, 51.0 / 680.0, 80.0 / 440.0, 80.0 / 680.0)
static var ESL_TITLE_RECT_N := Rect2(100.0 / 440.0, 78.0 / 680.0, 252.0 / 440.0, 30.0 / 680.0)
static var ESL_TYPE_RECT_N := Rect2(95.0 / 440.0, 111.0 / 680.0, 250.0 / 440.0, 22.0 / 680.0)
static var ESL_POWER_RECT_N := Rect2(15.0 / 440.0, 359.0 / 680.0, 100.0 / 440.0, 60.0 / 680.0)
static var ESL_HEALTH_RECT_N := Rect2(325.0 / 440.0, 362.0 / 680.0, 100.0 / 440.0, 60.0 / 680.0)
static var ESL_RULES_RECT_N := Rect2(70.0 / 440.0, 493.0 / 680.0, 310.0 / 440.0, 120.0 / 680.0)
static var ESL_ONGOING_RECT_N := Rect2(95.0 / 440.0, 468.0 / 680.0, 250.0 / 440.0, 22.0 / 680.0)

# Double-card layout: 12 normalised rects describing each half's elements,
# tuned to align with the slots baked into the frame_double_*.png templates.
# Override via res://data/double_template_adjustments.json or fine-tune
# visually with the in-game template builder (Ctrl+Shift+D in deck editor).
# Defaults below are starting estimates — drag the frames in the builder to
# match the frame PNG's exact slot positions then Save.
static var DOUBLE_A_COST_RECT_N := Rect2(14.0 / 440.0, 40.0 / 680.0, 80.0 / 440.0, 80.0 / 680.0)
static var DOUBLE_A_TITLE_RECT_N := Rect2(110.0 / 440.0, 80.0 / 680.0, 230.0 / 440.0, 30.0 / 680.0)
static var DOUBLE_A_TYPE_RECT_N := Rect2(150.0 / 440.0, 110.0 / 680.0, 150.0 / 440.0, 20.0 / 680.0)
static var DOUBLE_A_ART_RECT_N := Rect2(68.0 / 440.0, 110.0 / 680.0, 310.0 / 440.0, 210.0 / 680.0)
static var DOUBLE_A_POWER_RECT_N := Rect2(80.0 / 440.0, 245.0 / 680.0, 70.0 / 440.0, 50.0 / 680.0)
static var DOUBLE_A_HEALTH_RECT_N := Rect2(305.0 / 440.0, 245.0 / 680.0, 70.0 / 440.0, 50.0 / 680.0)
static var DOUBLE_B_COST_RECT_N := Rect2(14.0 / 440.0, 320.0 / 680.0, 80.0 / 440.0, 80.0 / 680.0)
static var DOUBLE_B_TITLE_RECT_N := Rect2(110.0 / 440.0, 360.0 / 680.0, 230.0 / 440.0, 30.0 / 680.0)
static var DOUBLE_B_TYPE_RECT_N := Rect2(150.0 / 440.0, 390.0 / 680.0, 150.0 / 440.0, 20.0 / 680.0)
static var DOUBLE_B_ART_RECT_N := Rect2(68.0 / 440.0, 390.0 / 680.0, 310.0 / 440.0, 210.0 / 680.0)
static var DOUBLE_B_POWER_RECT_N := Rect2(80.0 / 440.0, 525.0 / 680.0, 70.0 / 440.0, 50.0 / 680.0)
static var DOUBLE_B_HEALTH_RECT_N := Rect2(305.0 / 440.0, 525.0 / 680.0, 70.0 / 440.0, 50.0 / 680.0)

const ESL_OVERRIDES_PATH := "res://data/esl_template_adjustments.json"
const DOUBLE_OVERRIDES_PATH := "res://data/double_template_adjustments.json"
static var _esl_overrides_loaded := false
static var _double_overrides_loaded := false


static func _rect_from_px_dict(d: Dictionary) -> Rect2:
	return Rect2(
		float(d.get("x", 0.0)) / 440.0,
		float(d.get("y", 0.0)) / 680.0,
		float(d.get("w", 0.0)) / 440.0,
		float(d.get("h", 0.0)) / 680.0,
	)


static func load_esl_overrides() -> void:
	_esl_overrides_loaded = true
	if not FileAccess.file_exists(ESL_OVERRIDES_PATH):
		return
	var file := FileAccess.open(ESL_OVERRIDES_PATH, FileAccess.READ)
	if file == null:
		return
	var txt := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.has("art"):
		ESL_ART_RECT_N = _rect_from_px_dict(data["art"])
	if data.has("cost"):
		ESL_COST_RECT_N = _rect_from_px_dict(data["cost"])
	if data.has("title"):
		ESL_TITLE_RECT_N = _rect_from_px_dict(data["title"])
	if data.has("type"):
		ESL_TYPE_RECT_N = _rect_from_px_dict(data["type"])
	if data.has("power"):
		ESL_POWER_RECT_N = _rect_from_px_dict(data["power"])
	if data.has("health"):
		ESL_HEALTH_RECT_N = _rect_from_px_dict(data["health"])
	if data.has("rules"):
		ESL_RULES_RECT_N = _rect_from_px_dict(data["rules"])
	if data.has("ongoing"):
		ESL_ONGOING_RECT_N = _rect_from_px_dict(data["ongoing"])


static func load_double_template_overrides() -> void:
	_double_overrides_loaded = true
	if not FileAccess.file_exists(DOUBLE_OVERRIDES_PATH):
		return
	var file := FileAccess.open(DOUBLE_OVERRIDES_PATH, FileAccess.READ)
	if file == null:
		return
	var txt := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.has("double_a_cost"):
		DOUBLE_A_COST_RECT_N = _rect_from_px_dict(data["double_a_cost"])
	if data.has("double_a_title"):
		DOUBLE_A_TITLE_RECT_N = _rect_from_px_dict(data["double_a_title"])
	if data.has("double_a_type"):
		DOUBLE_A_TYPE_RECT_N = _rect_from_px_dict(data["double_a_type"])
	if data.has("double_a_art"):
		DOUBLE_A_ART_RECT_N = _rect_from_px_dict(data["double_a_art"])
	if data.has("double_a_power"):
		DOUBLE_A_POWER_RECT_N = _rect_from_px_dict(data["double_a_power"])
	if data.has("double_a_health"):
		DOUBLE_A_HEALTH_RECT_N = _rect_from_px_dict(data["double_a_health"])
	if data.has("double_b_cost"):
		DOUBLE_B_COST_RECT_N = _rect_from_px_dict(data["double_b_cost"])
	if data.has("double_b_title"):
		DOUBLE_B_TITLE_RECT_N = _rect_from_px_dict(data["double_b_title"])
	if data.has("double_b_type"):
		DOUBLE_B_TYPE_RECT_N = _rect_from_px_dict(data["double_b_type"])
	if data.has("double_b_art"):
		DOUBLE_B_ART_RECT_N = _rect_from_px_dict(data["double_b_art"])
	if data.has("double_b_power"):
		DOUBLE_B_POWER_RECT_N = _rect_from_px_dict(data["double_b_power"])
	if data.has("double_b_health"):
		DOUBLE_B_HEALTH_RECT_N = _rect_from_px_dict(data["double_b_health"])

# The frame PNG has transparent padding around the visible card. These normalised
# coords describe the visible card region inside the 440x680 canvas; the template
# layers are oversized and offset so this region fills the component rect.
const ESL_PNG_VISIBLE_N := Rect2(28.0 / 440.0, 55.0 / 680.0, 355.0 / 440.0, 568.0 / 680.0)

static var USE_ESL_TEMPLATE := true

var _card_data: Dictionary = {}
var _presentation_mode := PRESENTATION_FULL
var _is_built := false
var _default_art_texture: Texture2D
var _interactive := true
var _deck_quantity_current := -1
var _deck_quantity_max := -1
var _rules_font_size := ATTRIBUTE_INLINE_ICON_DEFAULT_FONT_SIZE

var _original_card_data: Dictionary = {}
var _active_wax_wane_phases: Array = []  # e.g. ["wax"], ["wane"], or ["wax", "wane"]
var _relationships: Array = []
var _relationship_index := 0
var _relationship_context: Dictionary = {}
var _relationship_context_callback: Callable

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
# Double-card half-B overlays — only populated/visible when rendering a double card.
var _double_b_cost_badge: TextureRect
var _double_b_cost_label: Label
var _double_b_name_banner: PanelContainer
var _double_b_name_label: Label
var _double_b_subtype_banner: PanelContainer
var _double_b_subtype_label: Label
var _double_b_attack_badge: TextureRect
var _double_b_attack_label: Label
var _double_b_health_badge: TextureRect
var _double_b_health_label: Label
var _double_b_art_frame: PanelContainer
var _double_b_art_clip: Control
var _double_b_art_texture: TextureRect
var _double_divider: ColorRect
var _attack_badge: TextureRect
var _attack_label: Label
var _health_badge: TextureRect
var _health_label: Label
var _ward_overlay: ColorRect
var _premium_overlay: ColorRect
var _shackle_overlay: TextureRect
var _prophecy_glow_overlay: ColorRect
var _lethal_particles: GPUParticles2D
var _attribute_icons_container: VBoxContainer
var _keyword_icons_container: HBoxContainer
var _augment_badge_container: VBoxContainer
var _gate_level_badge: Label
var _quantity_badge: Label
var _charges_badge: Label
var _ongoing_badge: Label
var _cost_trigger_badge: Label
var _crowned_badge: Label
var _marked_badge: Label
var _pips_container: HBoxContainer

var _use_esl_template: bool = USE_ESL_TEMPLATE
var _tpl_frame: TextureRect
var _tpl_rarity: TextureRect
var _tpl_ph: TextureRect
var _tpl_label_strip: TextureRect


func _ready() -> void:
	if not _esl_overrides_loaded:
		load_esl_overrides()
	if not _double_overrides_loaded:
		load_double_template_overrides()
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
	if _premium_overlay != null and _premium_overlay.visible:
		_premium_overlay.queue_redraw()
		queue_redraw()
	if _prophecy_glow_overlay != null and _prophecy_glow_overlay.visible:
		_prophecy_glow_overlay.queue_redraw()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _is_built:
		_refresh_all()


func set_use_esl_template(enabled: bool) -> void:
	if _use_esl_template == enabled:
		return
	_use_esl_template = enabled
	_refresh_all()


func _esl_attribute_tuple_key(card: Dictionary) -> String:
	var attributes: Array = card.get("attributes", [])
	if attributes.is_empty():
		return "neutral"
	var keys: Array = []
	for a in attributes:
		var s := str(a).strip_edges().to_lower()
		if s.is_empty() or s == "neutral":
			continue
		if not keys.has(s):
			keys.append(s)
	if keys.is_empty():
		return "neutral"
	keys.sort()
	return ",".join(keys)


func _esl_frame_key_for_card(card: Dictionary) -> String:
	if str(card.get("card_type", "")) == "double":
		var dk := _esl_double_frame_key_for_card(card)
		if not dk.is_empty():
			return dk
	var tuple_key := _esl_attribute_tuple_key(card)
	return ESL_FRAME_BY_ATTRIBUTES.get(tuple_key, "")


# Returns the frame_double_<a>_<b> key for a double card, looking up each
# half's primary attribute. If a corresponding asset exists, that key is used;
# otherwise returns "" so the caller falls back to the standard ESL lookup.
func _esl_double_frame_key_for_card(card: Dictionary) -> String:
	var halves: Array = card.get("half_card_ids", [])
	if halves.size() < 2:
		return ""
	var seed_a := _resolve_double_half_seed(str(halves[0]))
	var seed_b := _resolve_double_half_seed(str(halves[1]))
	var attr_a := _primary_attribute_for_seed(seed_a)
	var attr_b := _primary_attribute_for_seed(seed_b)
	if attr_a.is_empty() or attr_b.is_empty():
		return ""
	var candidate := "double_%s_%s" % [attr_a, attr_b]
	# Only return the key if the matching frame PNG actually exists, so cards
	# without a hand-painted double frame keep working via the duo/mono path.
	if ResourceLoader.exists(ESL_TEMPLATE_DIR + "frame_" + candidate + ".png"):
		return candidate
	return ""


func _primary_attribute_for_seed(seed: Dictionary) -> String:
	var attrs = seed.get("attributes", [])
	if typeof(attrs) != TYPE_ARRAY or attrs.is_empty():
		return "neutral"
	for a in attrs:
		var s := str(a).strip_edges().to_lower()
		if not s.is_empty():
			return s
	return "neutral"


func _esl_template_supported(card: Dictionary) -> bool:
	if not _use_esl_template:
		return false
	return _esl_frame_key_for_card(card) != ""


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
	_relationship_context_callback = Callable()
	_rebuild_relationships()


func set_relationship_context_callback(cb: Callable) -> void:
	_relationship_context_callback = cb
	_rebuild_relationships()


func cycle_relationship(direction: int) -> void:
	# Re-resolve from callback to ensure counts reflect current state
	if _relationship_context_callback.is_valid():
		var ctx: Dictionary = _relationship_context_callback.call()
		_relationship_context = ctx
		var card_for_resolve: Dictionary = _card_data if _original_card_data.is_empty() else _original_card_data
		_relationships = CardRelationshipResolverClass.resolve(card_for_resolve, ctx)
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
	var ctx: Dictionary = _relationship_context
	if _relationship_context_callback.is_valid():
		ctx = _relationship_context_callback.call()
		_relationship_context = ctx
	_relationships = CardRelationshipResolverClass.resolve(_card_data if _original_card_data.is_empty() else _original_card_data, ctx)
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
			if rel.has("shout_level"):
				_card_data["shout_level"] = int(rel["shout_level"])
			# Clear triggered_abilities so _rules_preview doesn't extract keywords from them
			_refresh_all()


func _build_internal_nodes() -> void:
	_content_root = Control.new()
	_content_root.name = "ContentRoot"
	_set_full_rect(_content_root)
	add_child(_content_root)

	# Prophecy glow sits behind the entire card frame
	_prophecy_glow_overlay = ColorRect.new()
	_prophecy_glow_overlay.name = "ProphecyGlowOverlay"
	_prophecy_glow_overlay.color = Color.WHITE
	_prophecy_glow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prophecy_glow_overlay.visible = false
	if PROPHECY_GLOW_SHADER:
		var prophecy_mat := ShaderMaterial.new()
		prophecy_mat.shader = PROPHECY_GLOW_SHADER
		_prophecy_glow_overlay.material = prophecy_mat
	_content_root.add_child(_prophecy_glow_overlay)

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

	# Second art frame for double-card half-B (only positioned/visible when
	# rendering a double; default hidden). Mirrors _art_frame / _art_clip / _art_texture.
	_double_b_art_frame = PanelContainer.new()
	_double_b_art_frame.name = "DoubleBArtFrame"
	_double_b_art_frame.clip_contents = true
	_double_b_art_frame.visible = false
	_content_root.add_child(_double_b_art_frame)
	_double_b_art_clip = Control.new()
	_double_b_art_clip.name = "DoubleBArtClip"
	_double_b_art_clip.clip_contents = true
	_double_b_art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_double_b_art_clip.visible = false
	_content_root.add_child(_double_b_art_clip)
	_double_b_art_texture = TextureRect.new()
	_double_b_art_texture.name = "DoubleBArtTexture"
	_double_b_art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_double_b_art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_double_b_art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_double_b_art_clip.add_child(_double_b_art_texture)

	# Ward overlay sits above artwork but below banners and badges
	_ward_overlay = ColorRect.new()
	_ward_overlay.name = "WardOverlay"
	_ward_overlay.color = Color.WHITE
	_ward_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ward_overlay.visible = false
	if WARD_SHADER:
		var ward_mat := ShaderMaterial.new()
		ward_mat.shader = WARD_SHADER
		_ward_overlay.material = ward_mat
	_art_clip.add_child(_ward_overlay)

	# Premium gold overlay sits above artwork, covers the full card frame
	_premium_overlay = ColorRect.new()
	_premium_overlay.name = "PremiumOverlay"
	_premium_overlay.color = Color.WHITE
	_premium_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_premium_overlay.visible = false
	if PREMIUM_GOLD_SHADER:
		var premium_mat := ShaderMaterial.new()
		premium_mat.shader = PREMIUM_GOLD_SHADER
		_premium_overlay.material = premium_mat
	_content_root.add_child(_premium_overlay)

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

	# ESL template overlay layers (frame → rarity → ph/support) sit above art but below banners.
	_tpl_frame = TextureRect.new()
	_tpl_frame.name = "EslTplFrame"
	_tpl_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tpl_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_tpl_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tpl_frame.visible = false
	_content_root.add_child(_tpl_frame)
	_tpl_rarity = TextureRect.new()
	_tpl_rarity.name = "EslTplRarity"
	_tpl_rarity.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tpl_rarity.stretch_mode = TextureRect.STRETCH_SCALE
	_tpl_rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tpl_rarity.visible = false
	_content_root.add_child(_tpl_rarity)
	_tpl_ph = TextureRect.new()
	_tpl_ph.name = "EslTplPh"
	_tpl_ph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tpl_ph.stretch_mode = TextureRect.STRETCH_SCALE
	_tpl_ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tpl_ph.visible = false
	_content_root.add_child(_tpl_ph)
	_tpl_label_strip = TextureRect.new()
	_tpl_label_strip.name = "EslTplLabelStrip"
	_tpl_label_strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tpl_label_strip.stretch_mode = TextureRect.STRETCH_SCALE
	_tpl_label_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tpl_label_strip.visible = false
	_content_root.add_child(_tpl_label_strip)

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

	# Double-card overlays: a second cost badge + label, a half-B name banner,
	# and a thin horizontal divider rendered at the vertical art midpoint.
	# All are hidden by default and only positioned/shown when rendering doubles.
	_double_b_cost_badge = TextureRect.new()
	_double_b_cost_badge.name = "DoubleBCostBadge"
	_double_b_cost_badge.texture = preload("res://assets/images/cards/magicka-icon.png")
	_double_b_cost_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_double_b_cost_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_double_b_cost_badge.visible = false
	_content_root.add_child(_double_b_cost_badge)
	_double_b_cost_label = _build_centered_label("DoubleBCostLabel", 16)
	_double_b_cost_label.add_theme_constant_override("outline_size", 3)
	_double_b_cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_double_b_cost_label.visible = false
	_content_root.add_child(_double_b_cost_label)
	_double_b_name_banner = PanelContainer.new()
	_double_b_name_banner.name = "DoubleBNameBanner"
	_double_b_name_banner.clip_contents = true
	_double_b_name_banner.visible = false
	_content_root.add_child(_double_b_name_banner)
	var double_b_box := _build_panel_box(_double_b_name_banner, 0, 4, BoxContainer.ALIGNMENT_CENTER)
	_double_b_name_label = Label.new()
	_double_b_name_label.name = "DoubleBNameLabel"
	_double_b_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_double_b_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_double_b_name_label.max_lines_visible = 1
	_double_b_name_label.add_theme_font_size_override("font_size", 13)
	double_b_box.add_child(_double_b_name_label)
	_double_b_subtype_banner = PanelContainer.new()
	_double_b_subtype_banner.name = "DoubleBSubtypeBanner"
	_double_b_subtype_banner.clip_contents = true
	_double_b_subtype_banner.visible = false
	_content_root.add_child(_double_b_subtype_banner)
	var double_b_subtype_box := _build_panel_box(_double_b_subtype_banner, 0, 4, BoxContainer.ALIGNMENT_CENTER)
	_double_b_subtype_label = Label.new()
	_double_b_subtype_label.name = "DoubleBSubtypeLabel"
	_double_b_subtype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_double_b_subtype_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_double_b_subtype_label.max_lines_visible = 1
	_double_b_subtype_label.add_theme_font_size_override("font_size", 9)
	double_b_subtype_box.add_child(_double_b_subtype_label)
	_double_b_attack_badge = TextureRect.new()
	_double_b_attack_badge.name = "DoubleBAttackBadge"
	_double_b_attack_badge.texture = preload("res://assets/images/cards/attack-icon.png")
	_double_b_attack_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_double_b_attack_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_double_b_attack_badge.visible = false
	_content_root.add_child(_double_b_attack_badge)
	_double_b_attack_label = _build_centered_label("DoubleBAttackLabel", 18)
	_double_b_attack_label.add_theme_constant_override("outline_size", 3)
	_double_b_attack_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_double_b_attack_label.visible = false
	_content_root.add_child(_double_b_attack_label)
	_double_b_health_badge = TextureRect.new()
	_double_b_health_badge.name = "DoubleBHealthBadge"
	_double_b_health_badge.texture = preload("res://assets/images/cards/defense-icon.png")
	_double_b_health_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_double_b_health_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_double_b_health_badge.visible = false
	_content_root.add_child(_double_b_health_badge)
	_double_b_health_label = _build_centered_label("DoubleBHealthLabel", 18)
	_double_b_health_label.add_theme_constant_override("outline_size", 3)
	_double_b_health_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_double_b_health_label.visible = false
	_content_root.add_child(_double_b_health_label)
	_double_divider = ColorRect.new()
	_double_divider.name = "DoubleDivider"
	_double_divider.color = Color(0.95, 0.88, 0.6, 0.85)
	_double_divider.visible = false
	_double_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_root.add_child(_double_divider)

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

	_gate_level_badge = Label.new()
	_gate_level_badge.name = "GateLevelBadge"
	_gate_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gate_level_badge.add_theme_font_size_override("font_size", 11)
	_gate_level_badge.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6, 1.0))
	_gate_level_badge.visible = false
	_content_root.add_child(_gate_level_badge)

	_ongoing_badge = Label.new()
	_ongoing_badge.name = "OngoingBadge"
	_ongoing_badge.text = "Ongoing"
	_ongoing_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ongoing_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ongoing_badge.add_theme_font_size_override("font_size", 11)
	_ongoing_badge.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6, 1.0))
	var bold_font_ongoing := SystemFont.new()
	bold_font_ongoing.font_weight = 700
	_ongoing_badge.add_theme_font_override("font", bold_font_ongoing)
	_ongoing_badge.visible = false
	_content_root.add_child(_ongoing_badge)

	_cost_trigger_badge = Label.new()
	_cost_trigger_badge.name = "CostTriggerBadge"
	_cost_trigger_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_trigger_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_trigger_badge.add_theme_font_size_override("font_size", 22)
	_cost_trigger_badge.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6, 1.0))
	var bold_font_ct := SystemFont.new()
	bold_font_ct.font_weight = 700
	_cost_trigger_badge.add_theme_font_override("font", bold_font_ct)
	_cost_trigger_badge.visible = false
	_content_root.add_child(_cost_trigger_badge)

	_crowned_badge = Label.new()
	_crowned_badge.name = "CrownedBadge"
	_crowned_badge.text = "Crowned"
	_crowned_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crowned_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crowned_badge.add_theme_font_size_override("font_size", 11)
	_crowned_badge.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6, 1.0))
	_crowned_badge.visible = false
	_content_root.add_child(_crowned_badge)

	_marked_badge = Label.new()
	_marked_badge.name = "MarkedBadge"
	_marked_badge.text = "Marked"
	_marked_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marked_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_marked_badge.add_theme_font_size_override("font_size", 16)
	_marked_badge.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6, 1.0))
	var bold_font_marked := SystemFont.new()
	bold_font_marked.font_weight = 700
	_marked_badge.add_theme_font_override("font", bold_font_marked)
	_marked_badge.visible = false
	_content_root.add_child(_marked_badge)

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
	_refresh_ongoing_badge()
	_refresh_cost_trigger_badge()
	_refresh_crowned_badge()
	_refresh_marked_badge()
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
	_refresh_gate_level_badge()
	_refresh_esl_template_textures()
	_refresh_double_card_overlays()


func _refresh_esl_template_textures() -> void:
	if _tpl_frame == null:
		return
	if not _esl_template_supported(_card_data):
		_tpl_frame.visible = false
		_tpl_rarity.visible = false
		_tpl_ph.visible = false
		if _tpl_label_strip != null:
			_tpl_label_strip.visible = false
		return
	var frame_key: String = _esl_frame_key_for_card(_card_data)
	var frame_path: String = ESL_TEMPLATE_DIR + "frame_" + frame_key + ".png"
	_tpl_frame.texture = _load_texture_from_path(frame_path)
	_tpl_frame.visible = _tpl_frame.texture != null
	var rarity_key := _card_rarity_text(_card_data)
	# Legendary has distinct overlays for duo/trio attribute counts.
	if rarity_key == "legendary":
		if frame_key.begins_with("duo_") or frame_key == "double_endurance_intelligence":
			rarity_key = "legendary_duo"
		elif frame_key.begins_with("trio_"):
			rarity_key = "legendary_trio"
	var rarity_path: String = ESL_TEMPLATE_RARITY_PATHS.get(rarity_key, ESL_TEMPLATE_RARITY_PATHS["common"])
	_tpl_rarity.texture = _load_texture_from_path(rarity_path)
	_tpl_rarity.visible = _tpl_rarity.texture != null
	var ph_path := ESL_TEMPLATE_PH_PATH if _is_creature(_card_data) else ESL_TEMPLATE_SUPPORT_PATH
	_tpl_ph.texture = _load_texture_from_path(ph_path)
	# Only show the ph/support overlay for cards that actually use it.
	var show_ph := _is_creature(_card_data) or _is_ongoing_support(_card_data)
	_tpl_ph.visible = show_ph and _tpl_ph.texture != null
	# Creatures (oblivion gates) and actions (shouts) don't use the support_bg
	# layer; overlay a dedicated label-strip copy so the bottom-of-art badge has
	# its gold strip to sit on.
	if _tpl_label_strip != null:
		var needs_strip := not _label_strip_text(_card_data).is_empty() and not _is_ongoing_support(_card_data)
		if needs_strip:
			_tpl_label_strip.texture = _load_texture_from_path(ESL_TEMPLATE_SUPPORT_PATH)
			_tpl_label_strip.visible = _tpl_label_strip.texture != null
		else:
			_tpl_label_strip.visible = false


func _refresh_styles() -> void:
	if not _is_built:
		return
	var scale := _layout_scale()
	_apply_font_sizes(scale)
	var accent := _attribute_tint(_card_data)
	var muted_accent := accent.darkened(0.28)
	# Outer frame – dark with accent border (ESL-style card edge); gold for premium
	var is_premium := bool(_card_data.get("_premium", false))
	var outer_border := Color(0.85, 0.65, 0.15, 1.0) if is_premium else accent
	var outer_border_w := _scaled_border_width(4, scale) if is_premium else _scaled_border_width(3, scale)
	_apply_panel_style(_outer_frame, COLOR_FRAME_DARK, outer_border, outer_border_w, 0)
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
	# Mirror styling for double-card half-B nodes
	if _double_b_name_banner != null:
		_apply_panel_style(_double_b_name_banner, Color(0.0, 0.0, 0.0, 0.95), art_border_color, 0, 0)
		var dnb_style := _double_b_name_banner.get_theme_stylebox("panel") as StyleBoxFlat
		if dnb_style:
			dnb_style.border_width_bottom = _scaled_border_width(2, scale)
	if _double_b_subtype_banner != null:
		_apply_panel_style(_double_b_subtype_banner, Color(0.0, 0.0, 0.0, 0.95), art_border_color, 1, 0)
	if _double_b_art_frame != null:
		_apply_panel_style(_double_b_art_frame, _art_fill(_presentation_mode), accent.lerp(Color(0.78, 0.64, 0.4, 1.0), 0.42), _scaled_border_width(2 if _presentation_mode == PRESENTATION_FULL else 1, scale), 0)
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
	var _cost_color := _cost_display_color()
	if _cost_color != Color.BLACK:
		_cost_label.add_theme_color_override("font_color", _cost_color)
		_cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_cost_label.add_theme_constant_override("outline_size", 8)
	else:
		_cost_label.add_theme_color_override("font_color", Color.BLACK)
		_cost_label.add_theme_constant_override("outline_size", 0)
	_attack_label.add_theme_color_override("font_color", _stat_color(_card_data, "power"))
	_health_label.add_theme_color_override("font_color", _stat_color(_card_data, "health"))

	if _esl_template_supported(_card_data) and _presentation_mode == PRESENTATION_FULL:
		# Procedural frame, banners, and icons are replaced by the PNG template layers.
		_apply_panel_style(_outer_frame, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
		_apply_panel_style(_inner_frame, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
		_apply_panel_style(_art_frame, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
		_apply_panel_style(_name_banner, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
		_apply_panel_style(_subtype_banner, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
		_cost_badge.visible = false
		_attack_badge.visible = false
		_health_badge.visible = false
		# ESL labels: cream title on dark banner, black magicka, cream P/H, dark type text.
		_name_label.add_theme_color_override("font_color", Color(0.99, 0.96, 0.87, 1.0))
		_subtype_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.73, 1.0))
		if not _card_data.has("_effective_cost"):
			_cost_label.add_theme_color_override("font_color", Color.BLACK)
			_cost_label.add_theme_constant_override("outline_size", 0)
		var esl_stat_base := Color(0.99, 0.96, 0.87, 1.0)
		_attack_label.add_theme_color_override("font_color", _stat_color(_card_data, "power", esl_stat_base))
		_attack_label.add_theme_constant_override("outline_size", 3)
		_attack_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_health_label.add_theme_color_override("font_color", _stat_color(_card_data, "health", esl_stat_base))
		_health_label.add_theme_constant_override("outline_size", 3)
		_health_label.add_theme_color_override("font_outline_color", Color.BLACK)


func _refresh_visibility() -> void:
	if not _is_built:
		return
	var full := _presentation_mode == PRESENTATION_FULL
	var creature_minimal := _presentation_mode == PRESENTATION_CREATURE_BOARD_MINIMAL
	var is_creature := _is_creature(_card_data)
	_name_banner.visible = full
	_subtype_banner.visible = full
	_rules_panel.visible = full
	_rarity_marker.visible = full and not _esl_template_supported(_card_data)
	_cost_badge.visible = full and not _esl_template_supported(_card_data)
	_cost_label.visible = full
	# Attribute icons visibility is managed by _refresh_attribute_icons based on card data
	var hide_stat_badges := _esl_template_supported(_card_data) and full
	_attack_badge.visible = is_creature and (full or creature_minimal) and not hide_stat_badges
	_health_badge.visible = is_creature and (full or creature_minimal) and not hide_stat_badges
	_ward_overlay.visible = _interactive and is_creature and (EvergreenRules.has_keyword(_card_data, EvergreenRules.KEYWORD_WARD) or EvergreenRules.has_status(_card_data, EvergreenRules.STATUS_DAMAGE_IMMUNE) or bool(_card_data.get("aura_damage_immune", false)))
	_premium_overlay.visible = bool(_card_data.get("_premium", false))
	var _innate_s: Array = _card_data.get("innate_statuses", []) if typeof(_card_data.get("innate_statuses")) == TYPE_ARRAY else []
	var _shackle_perm_unless_equipped := _innate_s.has("shackle_permanent_unless_equipped") and EvergreenRules.get_attached_items(_card_data).is_empty()
	_shackle_overlay.visible = _interactive and is_creature and (creature_minimal) and (EvergreenRules.has_raw_status(_card_data, EvergreenRules.STATUS_SHACKLED) or bool(_card_data.get("cannot_attack", false)) or _shackle_perm_unless_equipped)
	_prophecy_glow_overlay.visible = _interactive and is_creature and (full or creature_minimal) and bool(_card_data.get("_blind_moth_active", false))
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
	if _esl_template_supported(_card_data):
		_layout_full_esl(inner_rect)
		return
	var scale := _layout_scale(PRESENTATION_FULL)
	var content_padding := 6.0 * scale
	var content_width := maxf(inner_rect.size.x - content_padding * 2.0, 0.0)
	var is_double_card := str(_card_data.get("card_type", "")) == "double"

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
	_layout_premium_overlay()
	_layout_prophecy_glow_overlay()
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

	# Double-card overlays: position cost-B badge at the vertical midpoint of
	# the art region, the half-B name banner just above the divider line, and
	# the divider itself across the art's vertical midpoint.
	if is_double_card:
		var divider_y := _art_frame.position.y + _art_frame.size.y * 0.5
		_double_divider.size = Vector2(_art_frame.size.x, maxf(2.0 * scale, 2.0))
		_double_divider.position = Vector2(_art_frame.position.x, divider_y - _double_divider.size.y * 0.5)
		_double_divider.visible = true
		# Half-B cost badge: same dimensions as primary cost badge but anchored
		# at the divider's left edge, vertically centered on the divider line.
		_double_b_cost_badge.size = cost_size
		_double_b_cost_badge.position = Vector2(_outer_frame.position.x - 8.0 * scale, divider_y - cost_size.y * 0.5)
		_double_b_cost_label.size = cost_size
		_double_b_cost_label.position = _double_b_cost_badge.position
		_double_b_cost_badge.visible = true
		_double_b_cost_label.visible = true
		# Half-B name banner: positioned just below the divider, mirroring how
		# the primary name banner sits at the top of the art region.
		var dnb_height := 28.0 * scale
		var border_w_d := float(_scaled_border_width(2, scale))
		_double_b_name_banner.position = Vector2(_art_frame.position.x + border_w_d, divider_y + border_w_d)
		_double_b_name_banner.size = Vector2(_art_frame.size.x - border_w_d * 2.0, dnb_height)
		_double_b_name_banner.visible = true
	else:
		_double_divider.visible = false
		_double_b_cost_badge.visible = false
		_double_b_cost_label.visible = false
		_double_b_name_banner.visible = false


func _layout_full_esl(inner_rect: Rect2) -> void:
	var _unused := inner_rect
	var card_size := size if size != Vector2.ZERO else custom_minimum_size
	var cw := card_size.x
	var ch := card_size.y
	var card_rect := Rect2(Vector2.ZERO, card_size)

	# The template PNGs have transparent padding; oversize and offset them so the
	# frame's visible region aligns with the component rect.
	var vn := ESL_PNG_VISIBLE_N
	var tpl_size := Vector2(cw / vn.size.x, ch / vn.size.y)
	var tpl_pos := Vector2(-vn.position.x * tpl_size.x, -vn.position.y * tpl_size.y)
	for tr in [_tpl_frame, _tpl_rarity, _tpl_ph, _tpl_label_strip]:
		if tr != null:
			tr.position = tpl_pos
			tr.size = tpl_size

	# Map PNG-space normalised rects into component-space rects via the template rect.
	var map_rect := func(n: Rect2) -> Rect2:
		return Rect2(
			tpl_pos + Vector2(n.position.x * tpl_size.x, n.position.y * tpl_size.y),
			Vector2(n.size.x * tpl_size.x, n.size.y * tpl_size.y)
		)

	var art_rect: Rect2 = map_rect.call(ESL_ART_RECT_N)
	_art_frame.position = art_rect.position
	_art_frame.size = art_rect.size
	_art_clip.position = art_rect.position
	_art_clip.size = art_rect.size
	_art_texture.position = Vector2.ZERO
	_art_texture.size = art_rect.size

	_outer_frame.position = card_rect.position
	_outer_frame.size = card_rect.size
	_inner_frame.position = card_rect.position
	_inner_frame.size = card_rect.size

	var cost_rect: Rect2 = map_rect.call(ESL_COST_RECT_N)
	_cost_label.position = cost_rect.position
	_cost_label.size = cost_rect.size

	var title_rect: Rect2 = map_rect.call(ESL_TITLE_RECT_N)
	_name_banner.position = title_rect.position
	_name_banner.size = title_rect.size
	var type_rect: Rect2 = map_rect.call(ESL_TYPE_RECT_N)
	_subtype_banner.position = type_rect.position
	_subtype_banner.size = type_rect.size

	var power_rect: Rect2 = map_rect.call(ESL_POWER_RECT_N)
	_attack_label.size = power_rect.size
	_attack_label.position = power_rect.position
	_attack_label.rotation_degrees = 0.0
	var health_rect: Rect2 = map_rect.call(ESL_HEALTH_RECT_N)
	_health_label.size = health_rect.size
	_health_label.position = health_rect.position
	_health_label.rotation_degrees = 0.0

	var rules_rect: Rect2 = map_rect.call(ESL_RULES_RECT_N)
	_rules_panel.position = rules_rect.position
	_rules_panel.size = rules_rect.size
	_rules_panel.custom_minimum_size = Vector2.ZERO

	# Move the rarity gem off-screen; rarity is now shown via the rarity PNG layer.
	_rarity_marker.position = Vector2(-1000.0, -1000.0)
	_rarity_marker.size = Vector2.ZERO

	_layout_ward_overlay()
	_layout_premium_overlay()
	_layout_prophecy_glow_overlay()
	_layout_attribute_icons()
	_layout_augment_badges()
	_keyword_icons_container.visible = false
	_layout_pips()

	if _lethal_particles != null:
		_lethal_particles.position = _attack_label.position + power_rect.size * 0.5

	_layout_full_esl_double_overlays(map_rect)


# Position double-card overlays inside the ESL template card. Hide them when the
# current card isn't a double. Layout strategy: render TWO mini full-card
# layouts stacked vertically. Half-A uses the existing nodes (cost circle baked
# into frame PNG aligns with cost-A); half-B uses the _double_b_* nodes. The
# rules panel is hidden — doubles have no rules text, the space is used for
# half-B's content. Card art comes from each half's own image (top half cropped
# via AtlasTexture), not the composite.
func _layout_full_esl_double_overlays(map_rect: Callable) -> void:
	var is_double_card := str(_card_data.get("card_type", "")) == "double"
	if not is_double_card:
		_double_divider.visible = false
		_double_b_cost_badge.visible = false
		_double_b_cost_label.visible = false
		_double_b_name_banner.visible = false
		_double_b_subtype_banner.visible = false
		_double_b_attack_badge.visible = false
		_double_b_attack_label.visible = false
		_double_b_health_badge.visible = false
		_double_b_health_label.visible = false
		_double_b_art_frame.visible = false
		_double_b_art_clip.visible = false
		_double_b_art_texture.visible = false
		_cost_badge.visible = true
		return

	# Hide the rules panel and the ESL template's power/health backing overlay
	# (which is sized for a single full-card stat region, not per-half stats).
	_rules_panel.position = Vector2(-1000.0, -1000.0)
	_rules_panel.size = Vector2.ZERO
	if _tpl_ph != null:
		_tpl_ph.visible = false
	if _tpl_label_strip != null:
		_tpl_label_strip.visible = false

	# The new frame_double_*.png templates already include the magicka circles,
	# title strips, and subtype badge backgrounds for both halves. Hide all the
	# extra chrome so only the labels (cost number, name, subtype) sit inside
	# the frame's painted slots.
	_cost_badge.visible = false
	_double_b_cost_badge.visible = false
	_apply_panel_style(_name_banner, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	_apply_panel_style(_subtype_banner, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	_apply_panel_style(_double_b_name_banner, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	_apply_panel_style(_double_b_subtype_banner, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	# The cost-A label was given a black font in _refresh_styles for ESL mode
	# (since the frame's blue magicka circle has light fill). Apply the same
	# override to cost-B so it isn't left as the default white.
	_double_b_cost_label.add_theme_color_override("font_color", Color.BLACK)
	_double_b_cost_label.add_theme_constant_override("outline_size", 0)
	# Stat-badge textures are very tall (attack-icon.png is 93x207); fitting
	# them with STRETCH_KEEP_ASPECT_CENTERED into the user's drag rect makes
	# them tiny. STRETCH_SCALE fills the rect directly so the badge size in
	# the editor matches what's rendered.
	_attack_badge.stretch_mode = TextureRect.STRETCH_SCALE
	_health_badge.stretch_mode = TextureRect.STRETCH_SCALE
	_double_b_attack_badge.stretch_mode = TextureRect.STRETCH_SCALE
	_double_b_health_badge.stretch_mode = TextureRect.STRETCH_SCALE

	var halves: Array = _card_data.get("half_card_ids", [])
	if halves.size() < 2:
		return
	var seed_a := _resolve_double_half_seed(str(halves[0]))
	var seed_b := _resolve_double_half_seed(str(halves[1]))

	# Resolve every per-half rect from the static normalised constants. Each
	# rect is overridable via res://data/double_template_adjustments.json and
	# editable in-game via the double-card template builder (Ctrl+Shift+D).
	var cost_a: Rect2 = map_rect.call(DOUBLE_A_COST_RECT_N)
	var title_a: Rect2 = map_rect.call(DOUBLE_A_TITLE_RECT_N)
	var type_a: Rect2 = map_rect.call(DOUBLE_A_TYPE_RECT_N)
	var art_a: Rect2 = map_rect.call(DOUBLE_A_ART_RECT_N)
	var power_a: Rect2 = map_rect.call(DOUBLE_A_POWER_RECT_N)
	var health_a: Rect2 = map_rect.call(DOUBLE_A_HEALTH_RECT_N)
	var cost_b: Rect2 = map_rect.call(DOUBLE_B_COST_RECT_N)
	var title_b: Rect2 = map_rect.call(DOUBLE_B_TITLE_RECT_N)
	var type_b: Rect2 = map_rect.call(DOUBLE_B_TYPE_RECT_N)
	var art_b: Rect2 = map_rect.call(DOUBLE_B_ART_RECT_N)
	var power_b: Rect2 = map_rect.call(DOUBLE_B_POWER_RECT_N)
	var health_b: Rect2 = map_rect.call(DOUBLE_B_HEALTH_RECT_N)

	# Half-A: override the ESL primary cost/name/subtype positions with the
	# per-half rects so half-A is symmetric with half-B (no longer using the
	# standard ESL_*_RECT_N positions in double mode).
	_cost_label.position = cost_a.position
	_cost_label.size = cost_a.size
	_name_banner.position = title_a.position
	_name_banner.size = title_a.size
	_subtype_banner.position = type_a.position
	_subtype_banner.size = type_a.size
	_art_frame.position = art_a.position
	_art_frame.size = art_a.size
	_art_clip.position = art_a.position
	_art_clip.size = art_a.size
	_art_texture.position = Vector2.ZERO
	_art_texture.size = art_a.size

	# Half-B art frame.
	_double_b_art_frame.position = art_b.position
	_double_b_art_frame.size = art_b.size
	_double_b_art_frame.visible = true
	_double_b_art_clip.position = art_b.position
	_double_b_art_clip.size = art_b.size
	_double_b_art_clip.visible = true
	_double_b_art_texture.position = Vector2.ZERO
	_double_b_art_texture.size = art_b.size
	_double_b_art_texture.visible = true

	# Half-B cost label (the magicka circle behind it is part of the frame PNG;
	# we only render the number on top of it).
	_double_b_cost_label.size = cost_b.size
	_double_b_cost_label.position = cost_b.position
	_double_b_cost_label.add_theme_font_size_override("font_size", _cost_label.get_theme_font_size("font_size"))
	_double_b_cost_label.visible = true

	# Half-B title and subtype banners.
	_double_b_name_banner.position = title_b.position
	_double_b_name_banner.size = title_b.size
	_double_b_name_banner.visible = true
	_double_b_name_label.add_theme_font_size_override("font_size", _name_label.get_theme_font_size("font_size"))
	_double_b_subtype_banner.position = type_b.position
	_double_b_subtype_banner.size = type_b.size
	_double_b_subtype_banner.visible = true
	_double_b_subtype_label.add_theme_font_size_override("font_size", _subtype_label.get_theme_font_size("font_size"))

	var seed_a_is_creature := str(seed_a.get("card_type", "")) == "creature"
	var seed_b_is_creature := str(seed_b.get("card_type", "")) == "creature"

	if seed_a_is_creature:
		_attack_label.position = power_a.position
		_attack_label.size = power_a.size
		_health_label.position = health_a.position
		_health_label.size = health_a.size
		_attack_badge.position = power_a.position
		_attack_badge.size = power_a.size
		_health_badge.position = health_a.position
		_health_badge.size = health_a.size
		_attack_badge.visible = true
		_health_badge.visible = true
	else:
		_attack_label.position = Vector2(-1000.0, -1000.0)
		_attack_label.size = Vector2.ZERO
		_health_label.position = Vector2(-1000.0, -1000.0)
		_health_label.size = Vector2.ZERO
		_attack_badge.size = Vector2.ZERO
		_attack_badge.position = Vector2(-1000.0, -1000.0)
		_health_badge.size = Vector2.ZERO
		_health_badge.position = Vector2(-1000.0, -1000.0)
		_attack_badge.visible = false
		_health_badge.visible = false

	if seed_b_is_creature:
		_double_b_attack_label.position = power_b.position
		_double_b_attack_label.size = power_b.size
		_double_b_health_label.position = health_b.position
		_double_b_health_label.size = health_b.size
		_double_b_attack_label.visible = true
		_double_b_health_label.visible = true
		_double_b_attack_label.add_theme_font_size_override("font_size", _attack_label.get_theme_font_size("font_size"))
		_double_b_health_label.add_theme_font_size_override("font_size", _health_label.get_theme_font_size("font_size"))
		_double_b_attack_badge.position = power_b.position
		_double_b_attack_badge.size = power_b.size
		_double_b_health_badge.position = health_b.position
		_double_b_health_badge.size = health_b.size
		_double_b_attack_badge.visible = true
		_double_b_health_badge.visible = true
	else:
		_double_b_attack_label.visible = false
		_double_b_health_label.visible = false
		_double_b_attack_badge.visible = false
		_double_b_health_badge.visible = false

	_double_divider.visible = false


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
	_layout_premium_overlay()
	_layout_prophecy_glow_overlay()
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
	_layout_premium_overlay()


func _frame_rect(width: float, height: float) -> Rect2:
	if _presentation_mode == PRESENTATION_SUPPORT_BOARD_MINIMAL:
		var square := minf(width, height)
		return Rect2(Vector2((width - square) * 0.5, (height - square) * 0.5), Vector2.ONE * square)
	if _presentation_mode == PRESENTATION_FULL:
		var full_inset := Vector2(8, 8)
		return Rect2(full_inset, Vector2(maxf(width - full_inset.x * 2.0, 0.0), maxf(height - full_inset.y * 2.0, 0.0)))
	return Rect2(Vector2.ZERO, Vector2(width, height))


func _refresh_double_card_overlays() -> void:
	if _double_b_cost_label == null:
		return
	if str(_card_data.get("card_type", "")) != "double":
		_double_b_cost_label.text = ""
		_double_b_name_label.text = ""
		_double_b_subtype_label.text = ""
		_double_b_attack_label.text = ""
		_double_b_health_label.text = ""
		return
	var halves: Array = _card_data.get("half_card_ids", [])
	if halves.size() < 2:
		return
	var seed_a := _resolve_double_half_seed(str(halves[0]))
	var seed_b := _resolve_double_half_seed(str(halves[1]))
	if seed_a.is_empty() or seed_b.is_empty():
		return
	# Override the primary cost/name/subtype labels to reflect HALF A (top half),
	# and populate half-B labels with HALF B (bottom half). Also override stat
	# labels with each half's values (only meaningful for creature halves).
	_cost_label.text = str(int(seed_a.get("cost", 0)))
	_name_label.text = str(seed_a.get("name", ""))
	_subtype_label.text = _double_subtype_line(seed_a)
	_double_b_cost_label.text = str(int(seed_b.get("cost", 0)))
	_double_b_name_label.text = str(seed_b.get("name", ""))
	_double_b_subtype_label.text = _double_subtype_line(seed_b)
	if str(seed_a.get("card_type", "")) == "creature":
		_attack_label.text = str(int(seed_a.get("base_power", 0)))
		_health_label.text = str(int(seed_a.get("base_health", 0)))
	else:
		_attack_label.text = ""
		_health_label.text = ""
	if str(seed_b.get("card_type", "")) == "creature":
		_double_b_attack_label.text = str(int(seed_b.get("base_power", 0)))
		_double_b_health_label.text = str(int(seed_b.get("base_health", 0)))
	else:
		_double_b_attack_label.text = ""
		_double_b_health_label.text = ""
	# Suppress rules text on the combined card — the bottom half is rendered
	# in the rules-panel area instead.
	_rules_label.text = ""
	# Override art textures: each half gets the top half of its own source art
	# rather than the runtime-composited stacked texture (which is intended
	# for the non-ESL fallback layout).
	_art_texture.texture = _double_top_half_atlas(str(_card_data.get("half_card_ids", [])[0]))
	if _double_b_art_texture != null:
		_double_b_art_texture.texture = _double_top_half_atlas(str(_card_data.get("half_card_ids", [])[1]))


func _double_subtype_line(seed: Dictionary) -> String:
	# Compose a "Subtype" or "Type" line for one half of a double card. Falls
	# back to the type ("Creature", "Action", "Item") if no subtype is set.
	var subtypes_raw = seed.get("subtypes", [])
	if typeof(subtypes_raw) == TYPE_ARRAY and subtypes_raw.size() > 0:
		return ", ".join(subtypes_raw)
	var ct := str(seed.get("card_type", "")).capitalize()
	return ct


static var _double_half_seed_cache: Dictionary = {}

func _resolve_double_half_seed(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	if _double_half_seed_cache.has(card_id):
		return _double_half_seed_cache[card_id]
	var CardCatalog2 = preload("res://src/deck/card_catalog.gd")
	for seed in CardCatalog2._card_seeds():
		if typeof(seed) == TYPE_DICTIONARY and str(seed.get("card_id", "")) == card_id:
			_double_half_seed_cache[card_id] = seed
			return seed
	_double_half_seed_cache[card_id] = {}
	return {}


func _resolve_art_texture(card: Dictionary) -> Texture2D:
	if str(card.get("card_type", "")) == "double":
		var composite := _compose_double_art_texture(card)
		if composite != null:
			return composite
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


# For double cards, compose a vertical-split art texture: top half of card A
# above top half of card B. The result is cached on the card data dictionary
# so subsequent _refresh_content calls reuse it.
static var _double_art_cache: Dictionary = {}

func _compose_double_art_texture(card: Dictionary) -> Texture2D:
	var halves: Array = card.get("half_card_ids", [])
	if halves.size() < 2:
		return null
	var cache_key := str(halves[0]) + "::" + str(halves[1])
	if _double_art_cache.has(cache_key):
		var cached = _double_art_cache[cache_key]
		if cached is Texture2D:
			return cached as Texture2D
	var path_a := "res://assets/images/cards/" + str(halves[0]) + ".png"
	var path_b := "res://assets/images/cards/" + str(halves[1]) + ".png"
	var img_a := _load_image_from_path(path_a)
	var img_b := _load_image_from_path(path_b)
	if img_a == null or img_b == null:
		return null
	# Normalise both halves to a common RGBA8 format and shared canvas size so
	# blit_rect doesn't choke on format/size mismatches (e.g. one half being a
	# 2048x2048 RGB PNG while the other is a 1024x1024 RGBA PNG).
	var canvas_w: int = max(img_a.get_width(), img_b.get_width())
	var canvas_h: int = max(img_a.get_height(), img_b.get_height())
	if img_a.get_format() != Image.FORMAT_RGBA8:
		img_a.convert(Image.FORMAT_RGBA8)
	if img_b.get_format() != Image.FORMAT_RGBA8:
		img_b.convert(Image.FORMAT_RGBA8)
	if img_a.get_width() != canvas_w or img_a.get_height() != canvas_h:
		img_a.resize(canvas_w, canvas_h, Image.INTERPOLATE_BILINEAR)
	if img_b.get_width() != canvas_w or img_b.get_height() != canvas_h:
		img_b.resize(canvas_w, canvas_h, Image.INTERPOLATE_BILINEAR)
	var composite := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	composite.blit_rect(img_a, Rect2i(0, 0, canvas_w, canvas_h / 2), Vector2i(0, 0))
	composite.blit_rect(img_b, Rect2i(0, 0, canvas_w, canvas_h / 2), Vector2i(0, canvas_h / 2))
	var tex := ImageTexture.create_from_image(composite)
	_double_art_cache[cache_key] = tex
	return tex


func _load_image_from_path(path: String) -> Image:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded := ResourceLoader.load(path)
	if loaded is Texture2D:
		return (loaded as Texture2D).get_image()
	return null


# Returns an AtlasTexture referencing the top half of a card's full art image.
# Used for double cards in ESL mode where each half occupies its own art frame
# and we want to show the upper portion of each half's source art (matching
# UESP's split visual where the bottom rules-text region of each half is
# replaced by the next half's content).
static var _double_top_half_atlas_cache: Dictionary = {}

func _double_top_half_atlas(card_id: String) -> AtlasTexture:
	if card_id.is_empty():
		return null
	if _double_top_half_atlas_cache.has(card_id):
		return _double_top_half_atlas_cache[card_id]
	var path := "res://assets/images/cards/" + card_id + ".png"
	var base := _load_texture_from_path(path)
	if base == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	var tex_size: Vector2 = base.get_size()
	atlas.region = Rect2(0, 0, tex_size.x, tex_size.y * 0.5)
	_double_top_half_atlas_cache[card_id] = atlas
	return atlas


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
	if _has_ongoing_effect():
		var aura_texture := _load_texture_from_path(AURA_ICON_PATH)
		if aura_texture != null:
			var aura_icon := TextureRect.new()
			aura_icon.texture = aura_texture
			aura_icon.custom_minimum_size = Vector2(KEYWORD_ICON_SIZE, KEYWORD_ICON_SIZE)
			aura_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			aura_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			aura_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_keyword_icons_container.add_child(aura_icon)


func _card_has_keyword_or_ability(kw: String) -> bool:
	if EvergreenRules.has_keyword(_card_data, kw):
		return true
	for trigger in _card_data.get("triggered_abilities", []):
		if typeof(trigger) == TYPE_DICTIONARY and str(trigger.get("family", "")) == kw:
			return true
	return false


const _ONE_OFF_FAMILIES := ["summon", "on_play", "wax", "wane"]
# Effect ops that replace the card's identity — if every effect in a trigger is
# one of these, the trigger fires once and then the card becomes something else,
# so it's effectively a one-off for aura-icon purposes (e.g. beast form).
const _CARD_REPLACING_OPS := ["change", "transform"]

func _has_ongoing_effect() -> bool:
	if _card_data.get("aura") != null:
		return true
	if bool(_card_data.get("rally_boost_aura", false)):
		return true
	var grants_immunity = _card_data.get("grants_immunity", [])
	if typeof(grants_immunity) == TYPE_ARRAY and not grants_immunity.is_empty():
		return true
	if typeof(grants_immunity) == TYPE_DICTIONARY and not grants_immunity.is_empty():
		return true
	var passives = _card_data.get("passive_abilities", [])
	if typeof(passives) == TYPE_ARRAY and not passives.is_empty():
		return true
	for trigger in _card_data.get("triggered_abilities", []):
		if typeof(trigger) != TYPE_DICTIONARY:
			continue
		var family: String = str(trigger.get("family", ""))
		if family in _ONE_OFF_FAMILIES:
			continue
		if family in KEYWORD_ICON_PATHS:
			continue
		if _trigger_only_replaces_self(trigger):
			continue
		return true
	return false


func _trigger_only_replaces_self(trigger: Dictionary) -> bool:
	var effects = trigger.get("effects", [])
	if typeof(effects) != TYPE_ARRAY or effects.is_empty():
		return false
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			return false
		if not (str(effect.get("op", "")) in _CARD_REPLACING_OPS):
			return false
		if str(effect.get("target", "")) != "self":
			return false
	return true


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
	if _presentation_mode != PRESENTATION_FULL or _esl_template_supported(_card_data):
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


func _layout_premium_overlay() -> void:
	if _premium_overlay == null:
		return
	# Cover the full outer frame so the shader's border mask aligns with card edges
	_premium_overlay.position = _outer_frame.position
	_premium_overlay.size = _outer_frame.size


func _layout_prophecy_glow_overlay() -> void:
	if _prophecy_glow_overlay == null:
		return
	# Extend beyond the outer frame to create a glow halo beneath the card
	var pad := 20.0
	_prophecy_glow_overlay.position = _outer_frame.position - Vector2(pad, pad)
	_prophecy_glow_overlay.size = _outer_frame.size + Vector2(pad * 2, pad * 2)
	# Set shader padding_uv to match the actual pixel padding ratio
	var mat := _prophecy_glow_overlay.material as ShaderMaterial
	if mat != null and _prophecy_glow_overlay.size.x > 0 and _prophecy_glow_overlay.size.y > 0:
		mat.set_shader_parameter("padding_uv", Vector2(pad / _prophecy_glow_overlay.size.x, pad / _prophecy_glow_overlay.size.y))


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


static var _texture_cache: Dictionary = {}

func _load_texture_from_path(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var _load_start := Time.get_ticks_msec()
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			result = resource as Texture2D
	if result == null:
		var global_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_path):
			var image := Image.new()
			if image.load(global_path) == OK:
				result = ImageTexture.create_from_image(image)
	var _load_elapsed := Time.get_ticks_msec() - _load_start
	if _load_elapsed > 100:
		print("[TEXTURE] Slow load %dms: %s" % [_load_elapsed, path])
	if result != null:
		_texture_cache[path] = result
	return result


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


func _is_ongoing_support(card: Dictionary) -> bool:
	var rt := str(card.get("rules_text", ""))
	return card.get("card_type", "") == "support" and rt.begins_with("Ongoing\n")


func _rules_preview(card: Dictionary) -> String:
	var rules_text := str(card.get("rules_text", "")).strip_edges()
	if _is_ongoing_support(card) and rules_text.begins_with("Ongoing\n"):
		rules_text = rules_text.substr("Ongoing\n".length()).strip_edges()
	if str(card.get("card_type", "")) == "support" and int(card.get("support_uses", 0)) > 0:
		var uses_re := RegEx.new()
		uses_re.compile("^Uses: \\d+\\s*\\n?")
		rules_text = uses_re.sub(rules_text, "", false).strip_edges()
	if int(card.get("shout_level", 0)) > 0:
		var level_re := RegEx.new()
		level_re.compile("Level \\d+:\\s*")
		rules_text = level_re.sub(rules_text, "", true)
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
	plain = _replace_attribute_names_with_icons(plain)
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


func _replace_attribute_names_with_icons(text: String) -> String:
	var s: int = max(1, int(round(float(_rules_font_size) * ATTRIBUTE_INLINE_ICON_SCALE)))
	for attr_name in ATTRIBUTE_ICON_PATHS:
		var icon_path: String = ATTRIBUTE_ICON_PATHS[attr_name]
		var img_tag := "[img=" + str(s) + "x" + str(s) + "]" + icon_path + "[/img]"
		# Replace [AttributeName] (bracketed form, case-insensitive)
		var bracket_regex := RegEx.new()
		bracket_regex.compile("(?i)\\[" + attr_name + "\\]")
		text = bracket_regex.sub(text, img_tag, true)
		# Replace bare attribute name (case-insensitive, word boundaries)
		var bare_regex := RegEx.new()
		bare_regex.compile("(?i)\\b" + attr_name + "\\b")
		text = bare_regex.sub(text, img_tag, true)
	return text


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
	var rules_text := str(card.get("rules_text", "")).strip_edges()
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


func _cost_display_color() -> Color:
	if not _card_data.has("_effective_cost"):
		return Color.BLACK
	var effective := int(_card_data.get("_effective_cost", 0))
	var base := int(_card_data.get("_base_cost", _card_data.get("cost", 0)))
	if effective < base:
		return COLOR_STAT_BUFF
	if effective > base:
		return COLOR_STAT_REDUCED
	return Color.BLACK


func _stat_color(card: Dictionary, stat: String, base_color: Color = COLOR_STAT_BASE) -> Color:
	if not _is_creature(card):
		return base_color
	var current := EvergreenRules.get_power(card) if stat == "power" else EvergreenRules.get_remaining_health(card)
	var printed := _printed_power(card) if stat == "power" else _printed_health(card)
	if current > printed:
		return COLOR_STAT_BUFF
	if current < printed:
		return COLOR_STAT_REDUCED
	return base_color


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
	if _esl_template_supported(_card_data) and _presentation_mode == PRESENTATION_FULL:
		var card_h := (size.y if size.y > 0.0 else custom_minimum_size.y)
		# Visible card is 568px of the 680px PNG canvas; scale from that baseline so
		# font sizes stay in proportion to the rendered (not padded) card height.
		var s := maxf(card_h / 568.0, 0.4)
		# Name font shrinks with title length so long titles don't intrude on the cost orb.
		var name_len := _name_label.text.length()
		var name_base := 22.0
		if name_len >= 28:
			name_base = 13.0
		elif name_len >= 20:
			name_base = 17.0
		_name_label.add_theme_font_size_override("font_size", maxi(1, int(round(name_base * s))))
		_subtype_label.add_theme_font_size_override("font_size", maxi(1, int(round(14.0 * s))))
		_apply_rules_font_size(maxi(1, int(round(20.0 * s))))
		_rarity_label.add_theme_font_size_override("font_size", maxi(1, int(round(9.0 * s))))
		_cost_label.add_theme_font_size_override("font_size", maxi(1, int(round(52.0 * s))))
		_attack_label.add_theme_font_size_override("font_size", maxi(1, int(round(48.0 * s))))
		_health_label.add_theme_font_size_override("font_size", maxi(1, int(round(48.0 * s))))
		return
	_name_label.add_theme_font_size_override("font_size", _scaled_int(14, scale))
	_subtype_label.add_theme_font_size_override("font_size", _scaled_int(10, scale))
	_apply_rules_font_size(_scaled_int(18, scale))
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
		_apply_rules_font_size(font_size)
		if _rules_label.get_content_height() <= int(available_height):
			break
		font_size -= 1


func _apply_rules_font_size(size: int) -> void:
	_rules_font_size = size
	_rules_label.add_theme_font_size_override("normal_font_size", size)
	_rules_label.add_theme_font_size_override("bold_font_size", size)
	# Regenerate bbcode so inline attribute icons scale with the new font size.
	if not _card_data.is_empty():
		_rules_label.text = _rules_bbcode(_card_data)


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


func _refresh_gate_level_badge() -> void:
	if _gate_level_badge == null:
		return
	var gate_level: int = int(_card_data.get("gate_level", 0))
	if gate_level <= 0 or _presentation_mode != PRESENTATION_FULL:
		_gate_level_badge.visible = false
		return
	if _esl_template_supported(_card_data):
		# Template mode renders gate level via the unified label-strip badge.
		_gate_level_badge.visible = false
		return
	_gate_level_badge.text = "Level: %d" % gate_level
	_gate_level_badge.visible = true
	var scale := _layout_scale(PRESENTATION_FULL)
	var badge_w := _art_frame.size.x * 0.5
	var badge_h := 18.0 * scale
	_gate_level_badge.add_theme_font_size_override("font_size", _scaled_int(11, scale))
	_gate_level_badge.size = Vector2(badge_w, badge_h)
	_gate_level_badge.position = Vector2(
		_art_frame.position.x + (_art_frame.size.x - badge_w) * 0.5,
		_art_frame.position.y + _art_frame.size.y - badge_h - float(_scaled_border_width(2, scale))
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	style.border_color = Color(0.95, 0.88, 0.6, 0.5)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	_gate_level_badge.add_theme_stylebox_override("normal", style)


func _label_strip_text(card: Dictionary) -> String:
	var gate_level := int(card.get("gate_level", 0))
	if gate_level > 0:
		return "Level %d" % gate_level
	var shout_level := int(card.get("shout_level", 0))
	if shout_level > 0:
		return "Level %d" % shout_level
	if str(card.get("card_type", "")) == "support":
		var remaining = card.get("remaining_support_uses", null)
		if remaining != null:
			return "Uses: %d" % int(remaining)
		var uses_total := int(card.get("support_uses", 0))
		if uses_total > 0:
			return "Uses: %d" % uses_total
	if _is_ongoing_support(card):
		return "Ongoing"
	return ""


func _refresh_ongoing_badge() -> void:
	if _ongoing_badge == null:
		return
	var badge_text := _label_strip_text(_card_data)
	if _presentation_mode != PRESENTATION_FULL or badge_text.is_empty():
		_ongoing_badge.visible = false
		return
	_ongoing_badge.text = badge_text
	_ongoing_badge.visible = true
	if _esl_template_supported(_card_data):
		# Template frame has a built-in label strip at the bottom of the art; just
		# place the text over it without our own pill stylebox.
		_ongoing_badge.remove_theme_stylebox_override("normal")
		_ongoing_badge.add_theme_color_override("font_color", Color.BLACK)
		var card_size := size if size != Vector2.ZERO else custom_minimum_size
		var cw := card_size.x
		var ch := card_size.y
		var vn := ESL_PNG_VISIBLE_N
		var tpl_size := Vector2(cw / vn.size.x, ch / vn.size.y)
		var tpl_pos := Vector2(-vn.position.x * tpl_size.x, -vn.position.y * tpl_size.y)
		_ongoing_badge.position = tpl_pos + Vector2(
			ESL_ONGOING_RECT_N.position.x * tpl_size.x,
			ESL_ONGOING_RECT_N.position.y * tpl_size.y,
		)
		_ongoing_badge.size = Vector2(
			ESL_ONGOING_RECT_N.size.x * tpl_size.x,
			ESL_ONGOING_RECT_N.size.y * tpl_size.y,
		)
		var s := maxf(ch / 568.0, 0.4)
		_ongoing_badge.add_theme_font_size_override("font_size", maxi(1, int(round(18.0 * s))))
		return
	var scale := _layout_scale(PRESENTATION_FULL)
	var badge_w := _art_frame.size.x * 0.5
	var badge_h := 18.0 * scale
	_ongoing_badge.add_theme_font_size_override("font_size", _scaled_int(11, scale))
	_ongoing_badge.size = Vector2(badge_w, badge_h)
	_ongoing_badge.position = Vector2(
		_art_frame.position.x + (_art_frame.size.x - badge_w) * 0.5,
		_art_frame.position.y + _art_frame.size.y - badge_h - float(_scaled_border_width(2, scale))
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	style.border_color = Color(0.95, 0.88, 0.6, 0.5)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	_ongoing_badge.add_theme_stylebox_override("normal", style)


func _refresh_cost_trigger_badge() -> void:
	if _cost_trigger_badge == null:
		return
	if _presentation_mode != PRESENTATION_CREATURE_BOARD_MINIMAL:
		_cost_trigger_badge.visible = false
		return
	var active_cost = _card_data.get("active_cost_trigger", null)
	if active_cost == null:
		_cost_trigger_badge.visible = false
		return
	_cost_trigger_badge.text = str(int(active_cost))
	_cost_trigger_badge.visible = true
	var scale := _layout_scale(PRESENTATION_CREATURE_BOARD_MINIMAL)
	var badge_size := 28.0 * scale
	var badge_w := badge_size
	var badge_h := badge_size
	_cost_trigger_badge.add_theme_font_size_override("font_size", _scaled_int(22, scale))
	_cost_trigger_badge.size = Vector2(badge_w, badge_h)
	_cost_trigger_badge.position = Vector2(
		_art_frame.position.x + (_art_frame.size.x - badge_w) * 0.5,
		_art_frame.position.y + float(_scaled_border_width(2, scale))
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	style.border_color = Color(0.95, 0.88, 0.6, 0.5)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_cost_trigger_badge.add_theme_stylebox_override("normal", style)


func _refresh_crowned_badge() -> void:
	if _crowned_badge == null:
		return
	if _presentation_mode != PRESENTATION_CREATURE_BOARD_MINIMAL:
		_crowned_badge.visible = false
		return
	var markers = _card_data.get("status_markers", [])
	if typeof(markers) != TYPE_ARRAY or not markers.has("crowned"):
		_crowned_badge.visible = false
		return
	_crowned_badge.visible = true
	var scale := _layout_scale(PRESENTATION_CREATURE_BOARD_MINIMAL)
	var badge_w := _art_frame.size.x * 0.5
	var badge_h := 18.0 * scale
	_crowned_badge.add_theme_font_size_override("font_size", _scaled_int(11, scale))
	_crowned_badge.size = Vector2(badge_w, badge_h)
	_crowned_badge.position = Vector2(
		_art_frame.position.x + (_art_frame.size.x - badge_w) * 0.5,
		_art_frame.position.y + float(_scaled_border_width(2, scale))
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	style.border_color = Color(0.95, 0.88, 0.6, 0.5)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	_crowned_badge.add_theme_stylebox_override("normal", style)


func _refresh_marked_badge() -> void:
	if _marked_badge == null:
		return
	if _presentation_mode != PRESENTATION_CREATURE_BOARD_MINIMAL:
		_marked_badge.visible = false
		return
	var markers = _card_data.get("status_markers", [])
	if typeof(markers) != TYPE_ARRAY or not markers.has("marked_for_death"):
		_marked_badge.visible = false
		return
	_marked_badge.visible = true
	var scale := _layout_scale(PRESENTATION_CREATURE_BOARD_MINIMAL)
	var badge_w := _art_frame.size.x * 0.7
	var badge_h := 24.0 * scale
	_marked_badge.add_theme_font_size_override("font_size", _scaled_int(16, scale))
	_marked_badge.size = Vector2(badge_w, badge_h)
	_marked_badge.position = Vector2(
		_art_frame.position.x + (_art_frame.size.x - badge_w) * 0.5,
		_art_frame.position.y + float(_scaled_border_width(2, scale))
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	style.border_color = Color(0.95, 0.88, 0.6, 0.5)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	_marked_badge.add_theme_stylebox_override("normal", style)


func _set_mouse_passthrough_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough_recursive(child)
