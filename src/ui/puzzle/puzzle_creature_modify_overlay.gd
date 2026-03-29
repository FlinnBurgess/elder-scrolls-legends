class_name PuzzleCreatureModifyOverlay
extends PanelContainer

## Overlay for modifying a creature's stat overrides in the puzzle builder.
## Shows spinners for power/health bonus, damage marked, can_attack toggle,
## and keyword multi-select.

signal confirmed(overrides: Dictionary)
signal cancelled

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")

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
	bg_style.bg_color = Color(0.04, 0.05, 0.07, 0.90)
	add_theme_stylebox_override("panel", bg_style)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.11, 0.16, 0.98)
	card_style.border_color = Color(0.5, 0.5, 0.55, 0.96)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Modify Creature"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Power bonus
	var power_row := HBoxContainer.new()
	power_row.add_theme_constant_override("separation", 8)
	vbox.add_child(power_row)
	var power_label := Label.new()
	power_label.text = "Power Bonus:"
	power_label.custom_minimum_size = Vector2(140, 0)
	power_row.add_child(power_label)
	_power_bonus_spin = SpinBox.new()
	_power_bonus_spin.min_value = -99
	_power_bonus_spin.max_value = 99
	_power_bonus_spin.value = 0
	power_row.add_child(_power_bonus_spin)

	# Health bonus
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 8)
	vbox.add_child(health_row)
	var health_label := Label.new()
	health_label.text = "Health Bonus:"
	health_label.custom_minimum_size = Vector2(140, 0)
	health_row.add_child(health_label)
	_health_bonus_spin = SpinBox.new()
	_health_bonus_spin.min_value = -99
	_health_bonus_spin.max_value = 99
	_health_bonus_spin.value = 0
	health_row.add_child(_health_bonus_spin)

	# Damage marked
	var damage_row := HBoxContainer.new()
	damage_row.add_theme_constant_override("separation", 8)
	vbox.add_child(damage_row)
	var damage_label := Label.new()
	damage_label.text = "Damage Marked:"
	damage_label.custom_minimum_size = Vector2(140, 0)
	damage_row.add_child(damage_label)
	_damage_spin = SpinBox.new()
	_damage_spin.min_value = 0
	_damage_spin.max_value = 99
	_damage_spin.value = 0
	damage_row.add_child(_damage_spin)

	# Can attack
	_can_attack_check = CheckBox.new()
	_can_attack_check.text = "Can Attack"
	_can_attack_check.button_pressed = true
	vbox.add_child(_can_attack_check)

	# Shackled
	_shackled_check = CheckBox.new()
	_shackled_check.text = "Shackled"
	_shackled_check.button_pressed = false
	vbox.add_child(_shackled_check)

	# Keywords section
	var kw_title := Label.new()
	kw_title.text = "Keywords:"
	kw_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(kw_title)

	var kw_grid := GridContainer.new()
	kw_grid.columns = 3
	kw_grid.add_theme_constant_override("h_separation", 8)
	kw_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(kw_grid)

	var keywords := EvergreenRules.get_supported_keywords()
	for kw in keywords:
		var check := CheckBox.new()
		check.text = str(kw)
		_keyword_checks[str(kw)] = check
		kw_grid.add_child(check)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.pressed.connect(func(): cancelled.emit())
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Apply"
	confirm_btn.custom_minimum_size = Vector2(100, 36)
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)


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
