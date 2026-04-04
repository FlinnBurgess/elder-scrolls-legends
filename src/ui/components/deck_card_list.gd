class_name DeckCardList
extends VBoxContainer

## Reusable styled deck card list — shows cards sorted by cost with art-filled rows,
## attribute-colored side borders, magicka gem, card name, and quantity.
## Optionally supports hover-to-preview full card display.

signal row_mouse_entered(row: Control, entry: Dictionary)
signal row_mouse_exited(entry: Dictionary)

const UITheme = preload("res://src/ui/ui_theme.gd")
const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")

const ATTRIBUTE_TINTS := {
	"strength": Color(0.84, 0.39, 0.31, 1.0),
	"intelligence": Color(0.42, 0.62, 0.96, 1.0),
	"willpower": Color(0.92, 0.78, 0.38, 1.0),
	"agility": Color(0.4, 0.76, 0.52, 1.0),
	"endurance": Color(0.58, 0.46, 0.72, 1.0),
}
const NEUTRAL_COST_COLOR := Color(0.6, 0.6, 0.6, 1.0)
const ROW_HEIGHT := 52
const ROW_BORDER := 4
const ART_VSHIFT := -0.35
const CARD_ASPECT_RATIO := 384.0 / 220.0
const PREVIEW_HEIGHT := 384.0
const HOVER_DELAY := 0.35
const FADE_SHADER_CODE := "
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float fade = smoothstep(0.25, 0.7, UV.x);
	COLOR = mix(tex, vec4(0.0, 0.0, 0.0, 1.0), fade);
}
"

var _fade_shader: Shader
var _placeholder_art: Texture2D
var _card_database: Dictionary = {}

# Hover preview state
var _preview_enabled := false
var _preview_layer: Control
var _hover_delay_timer: Timer
var _hover_pending_card_id := ""
var _hover_pending_row: Control
var _hover_preview_node: Control
var _relationship_context_callback: Callable


func _init() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)


## Call to enable hover-to-preview. preview_layer should be a full-rect Control
## added to the screen root (above scroll containers) so the preview isn't clipped.
func enable_hover_preview(preview_layer: Control, card_database: Dictionary) -> void:
	_preview_enabled = true
	_preview_layer = preview_layer
	_card_database = card_database
	if _hover_delay_timer == null:
		_hover_delay_timer = Timer.new()
		_hover_delay_timer.one_shot = true
		_hover_delay_timer.wait_time = HOVER_DELAY
		_hover_delay_timer.timeout.connect(_on_hover_delay_timeout)
		add_child(_hover_delay_timer)


## Optional: set a callback that returns a Dictionary for card relationship context.
func set_relationship_context_callback(cb: Callable) -> void:
	_relationship_context_callback = cb


func set_deck(deck: Array, card_database: Dictionary) -> void:
	_card_database = card_database
	_clear_hover_preview()
	_clear_children()

	var deck_entries: Array = []
	for entry in deck:
		var card_id: String = str(entry.get("card_id", ""))
		var card: Dictionary = card_database.get(card_id, {})
		if card.is_empty():
			continue
		deck_entries.append({
			"card_id": card_id,
			"name": str(card.get("name", card_id)),
			"cost": int(card.get("cost", 0)),
			"quantity": int(entry.get("quantity", 0)),
			"attributes": card.get("attributes", []),
		})
	deck_entries.sort_custom(func(a, b):
		if a["cost"] != b["cost"]:
			return a["cost"] < b["cost"]
		return a["name"].to_lower() < b["name"].to_lower()
	)

	for entry in deck_entries:
		add_child(_build_row(entry))

	if deck_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards in deck"
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		add_child(empty_label)


func _build_row(entry: Dictionary) -> Control:
	var row_h := ROW_HEIGHT
	var border := ROW_BORDER
	var attributes: Array = entry.get("attributes", [])

	var row := Control.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, row_h)
	row.clip_contents = true
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_entered.connect(_on_row_mouse_entered.bind(row, entry))
	row.mouse_exited.connect(_on_row_mouse_exited.bind(entry))

	# --- Attribute-colored side borders ---
	_add_attribute_border(row, attributes, row_h, border)

	# --- Black background ---
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = border
	bg.offset_right = -border
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)

	# --- Card art ---
	var art_clip := Control.new()
	art_clip.clip_contents = true
	art_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_clip.offset_left = border
	art_clip.offset_right = -border
	art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art_clip)
	var art_tex := _resolve_art(entry.get("card_id", ""))
	var art_rect := TextureRect.new()
	art_rect.texture = art_tex
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_height := row_h * 3.0
	var shift := ART_VSHIFT * art_height
	art_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_rect.offset_top = shift
	art_rect.offset_bottom = shift + art_height - row_h
	if _fade_shader == null:
		_fade_shader = Shader.new()
		_fade_shader.code = FADE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _fade_shader
	art_rect.material = mat
	art_clip.add_child(art_rect)

	# --- Magicka gem ---
	var gem_size := 36
	var gem := PanelContainer.new()
	var gem_style := StyleBoxFlat.new()
	gem_style.bg_color = Color(0.12, 0.14, 0.18, 0.99)
	gem_style.border_color = Color(0.72, 0.84, 0.98, 1.0)
	gem_style.set_border_width_all(2)
	gem_style.set_corner_radius_all(gem_size / 2)
	gem_style.set_content_margin_all(0)
	gem.add_theme_stylebox_override("panel", gem_style)
	gem.custom_minimum_size = Vector2(gem_size, gem_size)
	gem.size = Vector2(gem_size, gem_size)
	gem.position = Vector2(border + 5, (row_h - gem_size) / 2.0)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_label := Label.new()
	cost_label.text = str(entry["cost"])
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color.WHITE)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.size_flags_horizontal = SIZE_EXPAND_FILL
	cost_label.size_flags_vertical = SIZE_EXPAND_FILL
	gem.add_child(cost_label)
	row.add_child(gem)

	# --- Card name + quantity (right-aligned) ---
	var right_info := HBoxContainer.new()
	right_info.anchor_left = 0.0
	right_info.anchor_right = 1.0
	right_info.anchor_top = 0.0
	right_info.anchor_bottom = 1.0
	right_info.offset_left = border + gem_size + 12
	right_info.offset_right = -border - 10
	right_info.offset_top = 0
	right_info.offset_bottom = 0
	right_info.add_theme_constant_override("separation", 8)
	right_info.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.size_flags_vertical = SIZE_SHRINK_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_info.add_child(name_label)

	var qty_label := Label.new()
	qty_label.text = "x%d" % entry["quantity"]
	qty_label.size_flags_vertical = SIZE_SHRINK_CENTER
	qty_label.add_theme_font_size_override("font_size", 18)
	qty_label.add_theme_color_override("font_color", UITheme.GOLD_DIM)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_info.add_child(qty_label)

	row.add_child(right_info)
	return row


# --- Hover Preview ---

func _on_row_mouse_entered(row: Control, entry: Dictionary) -> void:
	row_mouse_entered.emit(row, entry)
	if not _preview_enabled:
		return
	var card_id: String = str(entry.get("card_id", ""))
	if card_id.is_empty():
		return
	_clear_hover_preview()
	_hover_pending_card_id = card_id
	_hover_pending_row = row
	_hover_delay_timer.start()


func _on_row_mouse_exited(entry: Dictionary) -> void:
	row_mouse_exited.emit(entry)
	if not _preview_enabled:
		return
	_hover_pending_card_id = ""
	_hover_pending_row = null
	_hover_delay_timer.stop()
	_clear_hover_preview()


func _on_hover_delay_timeout() -> void:
	if _hover_pending_card_id.is_empty() or _hover_pending_row == null:
		return
	_show_hover_preview(_hover_pending_row, _hover_pending_card_id)


func _show_hover_preview(row: Control, card_id: String) -> void:
	_clear_hover_preview()
	var card: Dictionary = _card_database.get(card_id, {})
	if card.is_empty():
		return
	var preview_width := PREVIEW_HEIGHT / CARD_ASPECT_RATIO
	var preview_size := Vector2(preview_width, PREVIEW_HEIGHT)
	var wrapper := Control.new()
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var component := CardDisplayComponentClass.new()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_interactive(false)
	component.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	component.apply_card(card, CardDisplayComponentClass.PRESENTATION_FULL)
	if _relationship_context_callback.is_valid() and component.has_method("set_relationship_context"):
		component.set_relationship_context(_relationship_context_callback.call())
	wrapper.add_child(component)
	_preview_layer.add_child(wrapper)
	_hover_preview_node = wrapper
	# Position to the left of the row
	var row_rect := row.get_global_rect()
	var layer_origin := _preview_layer.get_global_rect().position
	var target_x := row_rect.position.x - preview_size.x - 12.0 - layer_origin.x
	var target_y := row_rect.get_center().y - preview_size.y * 0.5 - layer_origin.y
	target_y = clampf(target_y, 0.0, maxf(_preview_layer.size.y - preview_size.y, 0.0))
	target_x = maxf(target_x, 0.0)
	wrapper.position = Vector2(target_x, target_y)


func _clear_hover_preview() -> void:
	if _hover_preview_node != null and is_instance_valid(_hover_preview_node):
		_hover_preview_node.get_parent().remove_child(_hover_preview_node)
		_hover_preview_node.queue_free()
	_hover_preview_node = null


# --- Border Rendering ---

func _add_attribute_border(row: Control, attributes: Array, row_h: int, border: int) -> void:
	var colors: Array = []
	for attr in attributes:
		colors.append(ATTRIBUTE_TINTS.get(str(attr), NEUTRAL_COST_COLOR))
	if colors.is_empty():
		colors.append(NEUTRAL_COST_COLOR)

	if colors.size() == 1:
		var left_bg := ColorRect.new()
		left_bg.color = colors[0]
		left_bg.anchor_bottom = 1.0
		left_bg.offset_right = border
		left_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(left_bg)
		var right_bg := ColorRect.new()
		right_bg.color = colors[0]
		right_bg.anchor_left = 1.0
		right_bg.anchor_right = 1.0
		right_bg.anchor_bottom = 1.0
		right_bg.offset_left = -border
		right_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(right_bg)
	else:
		var n := colors.size()
		for i in range(n):
			var seg := ColorRect.new()
			seg.color = colors[i]
			seg.position = Vector2(0, roundi(float(i) / n * row_h))
			seg.size = Vector2(border, roundi(float(i + 1) / n * row_h) - roundi(float(i) / n * row_h))
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(seg)
		for i in range(n):
			var seg := ColorRect.new()
			seg.color = colors[i]
			var seg_top := roundi(float(i) / n * row_h)
			var seg_bottom := roundi(float(i + 1) / n * row_h)
			seg.anchor_left = 1.0
			seg.anchor_top = 0.0
			seg.anchor_right = 1.0
			seg.anchor_bottom = 0.0
			seg.offset_left = -border
			seg.offset_right = 0
			seg.offset_top = seg_top
			seg.offset_bottom = seg_bottom
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(seg)


# --- Art Loading ---

func _resolve_art(card_id: String) -> Texture2D:
	if card_id.is_empty():
		return _get_placeholder_art()
	var path := "res://assets/images/cards/" + card_id + ".png"
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource as Texture2D
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var image := Image.new()
		if image.load(global_path) == OK:
			return ImageTexture.create_from_image(image)
	return _get_placeholder_art()


func _get_placeholder_art() -> Texture2D:
	if _placeholder_art != null:
		return _placeholder_art
	var path := "res://assets/images/cards/placeholder.png"
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			_placeholder_art = resource as Texture2D
			return _placeholder_art
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.26, 0.24, 0.22, 1.0))
	_placeholder_art = ImageTexture.create_from_image(image)
	return _placeholder_art


func _clear_children() -> void:
	for child in get_children():
		if child == _hover_delay_timer:
			continue
		remove_child(child)
		child.queue_free()
