class_name HealerNodeOverlay
extends Control

signal closed

var _headline: String = ""
var _health_bonus: int = 5


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


func set_data(headline: String, health_bonus: int) -> void:
	_headline = headline
	_health_bonus = health_bonus


func _build_ui() -> void:
	# Semi-transparent background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.15, 0.1, 0.95)
	panel_style.border_color = Color(0.3, 0.8, 0.4, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _headline if not _headline.is_empty() else "Shrine of Arkay"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "+%d Max Health" % _health_bonus
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4, 1.0))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(160, 44)
	btn.pressed.connect(func() -> void: closed.emit())
	vbox.add_child(btn)
