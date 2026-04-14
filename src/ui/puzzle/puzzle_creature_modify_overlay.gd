class_name PuzzleCreatureModifyOverlay
extends PanelContainer

## Overlay for modifying a creature's stat overrides in the puzzle builder.
## Shows spinners for power/health bonus, damage marked, can_attack toggle,
## and keyword multi-select.

signal confirmed(overrides: Dictionary)
signal cancelled

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")

const LABEL_WIDTH := 260
const LABEL_FONT_SIZE := 24
const SPIN_MIN_SIZE := Vector2(180, 56)
const SPIN_FONT_SIZE := 26
const CHECKBOX_FONT_SIZE := 24
const BUTTON_MIN_SIZE := Vector2(180, 64)
const BUTTON_FONT_SIZE := 26

var _power_bonus_spin: SpinBox
var _health_bonus_spin: SpinBox
var _damage_spin: SpinBox
var _can_attack_check: CheckBox
var _shackled_check: CheckBox
var _keyword_checks: Dictionary = {}  # keyword_name -> CheckBox


func _ready() -> void:
	_build_ui()


func load_overrides(overrides: Dictionary) -> void:
	_power_bonus_spin.value = int(overrides.get("power_bonus", 0))
	_health_bonus_spin.value = int(overrides.get("health_bonus", 0))
	_damage_spin.value = int(overrides.get("damage_marked", 0))
	_can_attack_check.button_pressed = bool(overrides.get("can_attack", true))
	var status_markers: Array = overrides.get("status_markers", [])
	_shackled_check.button_pressed = status_markers.has("shackled")
	var keywords: Array = overrides.get("keywords", [])
	for kw_name in _keyword_checks:
		_keyword_checks[kw_name].button_pressed = keywords.has(kw_name)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 65
	mouse_filter = MOUSE_FILTER_STOP

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.PANEL_BG
	card_style.border_color = UITheme.GOLD_DIM
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Modify Creature"
	UITheme.style_title(title, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(title)

	vbox.add_child(UITheme.make_separator(680.0))

	# Stats section
	var stats_label := Label.new()
	stats_label.text = "Stats"
	UITheme.style_section_label(stats_label, 22)
	vbox.add_child(stats_label)

	_power_bonus_spin = _add_spin_row(vbox, "Power Bonus", -99, 99)
	_health_bonus_spin = _add_spin_row(vbox, "Health Bonus", -99, 99)
	_damage_spin = _add_spin_row(vbox, "Damage Marked", 0, 99)

	# Status section
	vbox.add_child(UITheme.make_separator(680.0))

	var status_label := Label.new()
	status_label.text = "Status"
	UITheme.style_section_label(status_label, 22)
	vbox.add_child(status_label)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 32)
	vbox.add_child(status_row)

	_can_attack_check = CheckBox.new()
	_can_attack_check.text = "Can Attack"
	_can_attack_check.button_pressed = true
	UITheme.style_checkbox(_can_attack_check, CHECKBOX_FONT_SIZE)
	status_row.add_child(_can_attack_check)

	_shackled_check = CheckBox.new()
	_shackled_check.text = "Shackled"
	_shackled_check.button_pressed = false
	UITheme.style_checkbox(_shackled_check, CHECKBOX_FONT_SIZE)
	status_row.add_child(_shackled_check)

	# Keywords section
	vbox.add_child(UITheme.make_separator(680.0))

	var kw_title := Label.new()
	kw_title.text = "Keywords"
	UITheme.style_section_label(kw_title, 22)
	vbox.add_child(kw_title)

	var kw_grid := GridContainer.new()
	kw_grid.columns = 3
	kw_grid.add_theme_constant_override("h_separation", 32)
	kw_grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(kw_grid)

	var keywords := EvergreenRules.get_supported_keywords()
	for kw in keywords:
		var check := CheckBox.new()
		check.text = str(kw)
		UITheme.style_checkbox(check, CHECKBOX_FONT_SIZE)
		_keyword_checks[str(kw)] = check
		kw_grid.add_child(check)

	# Buttons
	vbox.add_child(UITheme.make_separator(680.0))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = BUTTON_MIN_SIZE
	UITheme.style_button(cancel_btn, BUTTON_FONT_SIZE, true)
	cancel_btn.pressed.connect(func(): cancelled.emit())
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Apply"
	confirm_btn.custom_minimum_size = BUTTON_MIN_SIZE
	UITheme.style_button(confirm_btn, BUTTON_FONT_SIZE)
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)


func _add_spin_row(parent: VBoxContainer, label_text: String, min_value: int, max_value: int) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = 0
	spin.custom_minimum_size = SPIN_MIN_SIZE
	UITheme.style_spin_box(spin, SPIN_FONT_SIZE)
	row.add_child(spin)

	return spin


func _on_confirm() -> void:
	var overrides := {}
	var pwr := int(_power_bonus_spin.value)
	if pwr != 0:
		overrides["power_bonus"] = pwr
	var hp := int(_health_bonus_spin.value)
	if hp != 0:
		overrides["health_bonus"] = hp
	var dmg := int(_damage_spin.value)
	if dmg > 0:
		overrides["damage_marked"] = dmg
	overrides["can_attack"] = _can_attack_check.button_pressed
	if _shackled_check.button_pressed:
		overrides["status_markers"] = ["shackled"]
	var keywords: Array = []
	for kw_name in _keyword_checks:
		if _keyword_checks[kw_name].button_pressed:
			keywords.append(kw_name)
	if not keywords.is_empty():
		overrides["keywords"] = keywords
	confirmed.emit(overrides)
