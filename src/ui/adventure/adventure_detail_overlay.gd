class_name AdventureDetailOverlay
extends Control

signal start_pressed
signal closed

const RelicCatalogScript = preload("res://src/adventure/relic_catalog.gd")

const BG_COLOR := Color(0.0, 0.0, 0.0, 0.75)
const PANEL_BG := Color(0.08, 0.08, 0.12, 0.95)
const PANEL_BORDER := Color(0.72, 0.60, 0.30, 1.0)
const TITLE_COLOR := Color(1.0, 0.97, 0.90, 1.0)
const SUBTITLE_COLOR := Color(0.85, 0.78, 0.62, 1.0)
const TEXT_COLOR := Color(0.82, 0.82, 0.82, 1.0)
const MUTED_COLOR := Color(0.55, 0.55, 0.55, 1.0)
const REWARD_COLOR := Color(0.9, 0.75, 0.3, 1.0)
const COMPLETED_COLOR := Color(0.4, 0.75, 0.4, 1.0)
const SPECIAL_RULE_COLOR := Color(0.7, 0.5, 0.9, 1.0)

const FADE_SHADER_CODE := "
shader_type canvas_item;
uniform float fade_start : hint_range(0.0, 1.0) = 0.3;
uniform float fade_end : hint_range(0.0, 1.0) = 0.7;
void fragment() {
	COLOR = texture(TEXTURE, UV);
	float fade = smoothstep(fade_start, fade_end, 1.0 - UV.x);
	COLOR.a *= fade;
}
"

var _adventure: Dictionary = {}
var _first_clear: bool = false  # true if this deck has NOT yet completed this adventure
var _first_completion_reward: Dictionary = {}
var _completion_reward_pool: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_data(adventure: Dictionary, already_completed_with_deck: bool) -> void:
	_adventure = adventure
	_first_clear = not already_completed_with_deck
	_first_completion_reward = adventure.get("first_completion_reward", {}) if typeof(adventure.get("first_completion_reward")) == TYPE_DICTIONARY else {}
	_completion_reward_pool = adventure.get("completion_reward_pool", []) if typeof(adventure.get("completion_reward_pool")) == TYPE_ARRAY else []
	_build_ui()


func _build_ui() -> void:
	# Full-screen semi-transparent background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			closed.emit()
	)
	add_child(bg)

	# Main container filling the screen
	var main := Control.new()
	main.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	main.offset_left = 40
	main.offset_top = 40
	main.offset_right = -40
	main.offset_bottom = -40
	add_child(main)

	# Panel background
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	main.add_child(panel)

	# Inner HBoxContainer: left content + right boss art
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	main.add_child(hbox)

	# --- Left side: text content ---
	var left := _build_left_content()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	hbox.add_child(left)

	# --- Right side: boss art with left fade ---
	var right := _build_right_art()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	hbox.add_child(right)


func _build_left_content() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = str(_adventure.get("name", "Unknown Adventure"))
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(title)

	# Difficulty
	var difficulty: int = int(_adventure.get("difficulty", 1))
	var diff_label := Label.new()
	diff_label.text = "Difficulty: " + _get_difficulty_stars(difficulty)
	diff_label.add_theme_font_size_override("font_size", 20)
	diff_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	vbox.add_child(diff_label)

	# Description blurb
	var description: String = str(_adventure.get("description", ""))
	if not description.is_empty():
		var desc_label := Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.add_theme_color_override("font_color", TEXT_COLOR)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(300, 0)
		vbox.add_child(desc_label)

	# Special rules
	var special_rules: Array = _adventure.get("special_rules", []) if typeof(_adventure.get("special_rules")) == TYPE_ARRAY else []
	if not special_rules.is_empty():
		var rules_spacer := Control.new()
		rules_spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(rules_spacer)

		var rules_header := Label.new()
		rules_header.text = "Special Rules"
		rules_header.add_theme_font_size_override("font_size", 22)
		rules_header.add_theme_color_override("font_color", SPECIAL_RULE_COLOR)
		vbox.add_child(rules_header)

		for rule in special_rules:
			var rule_label := Label.new()
			rule_label.text = "  - " + str(rule)
			rule_label.add_theme_font_size_override("font_size", 17)
			rule_label.add_theme_color_override("font_color", TEXT_COLOR)
			rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rule_label.custom_minimum_size = Vector2(280, 0)
			vbox.add_child(rule_label)

	# Spacer to push reward + button down
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Reward section
	var reward_header := Label.new()
	reward_header.text = "Reward"
	reward_header.add_theme_font_size_override("font_size", 22)
	reward_header.add_theme_color_override("font_color", SUBTITLE_COLOR)
	vbox.add_child(reward_header)

	var reward_text := _get_reward_text()
	var reward_label := Label.new()
	reward_label.text = reward_text
	reward_label.add_theme_font_size_override("font_size", 18)
	reward_label.add_theme_color_override("font_color", REWARD_COLOR if _first_clear else COMPLETED_COLOR)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(reward_label)

	# Button row
	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(btn_spacer)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var start_btn := Button.new()
	start_btn.text = "Begin Adventure"
	start_btn.custom_minimum_size = Vector2(200, 52)
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.pressed.connect(func() -> void: start_pressed.emit())
	btn_row.add_child(start_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 52)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(func() -> void: closed.emit())
	btn_row.add_child(back_btn)

	return margin


func _build_right_art() -> Control:
	var container := Control.new()

	var portrait_path: String = str(_adventure.get("portrait_image", ""))
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		return container

	var tex: Texture2D = load(portrait_path)
	if tex == null:
		return container

	var tex_rect := TextureRect.new()
	tex_rect.texture = tex
	tex_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# Apply left-fade shader
	var shader := Shader.new()
	shader.code = FADE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fade_start", 0.0)
	mat.set_shader_parameter("fade_end", 0.35)
	tex_rect.material = mat

	container.add_child(tex_rect)

	# Clip content to container bounds
	container.clip_contents = true

	return container


func _get_difficulty_stars(level: int) -> String:
	var stars := ""
	for i in range(5):
		if i < level:
			stars += "★"
		else:
			stars += "☆"
	return stars


func _get_reward_text() -> String:
	if _first_clear:
		# Show first completion reward
		if _first_completion_reward.is_empty():
			return "Complete to earn a reward"
		return _format_reward(_first_completion_reward) + "  (First Clear)"
	else:
		# Already completed - show that random rewards are available
		if _completion_reward_pool.is_empty():
			return "Already completed — no additional rewards"
		return "Already cleared — chance for bonus rewards"


func _format_reward(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", ""))
	match reward_type:
		"relic":
			var relic_id := str(reward.get("relic_id", ""))
			var relic := RelicCatalogScript.get_relic(relic_id)
			var relic_name := str(relic.get("name", relic_id))
			return "Relic: " + relic_name
		"gold_bonus":
			return "Gold: +" + str(int(reward.get("amount", 0)))
		_:
			return str(reward_type).capitalize()
