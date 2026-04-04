extends RefCounted

# Background
const BG_COLOR := Color(0.08, 0.08, 0.12, 1.0)

# Gold palette
const GOLD := Color(0.85, 0.72, 0.4, 1.0)
const GOLD_DIM := Color(0.72, 0.58, 0.3, 0.7)
const GOLD_BRIGHT := Color(1.0, 0.9, 0.6, 1.0)

# Text colors
const TEXT_LIGHT := Color(0.9, 0.85, 0.7, 1.0)
const TEXT_MUTED := Color(0.6, 0.55, 0.45, 0.8)
const TEXT_SECTION := Color(0.72, 0.58, 0.3, 0.8)

# Button background colors
const BTN_BG := Color(0.12, 0.11, 0.15, 0.9)
const BTN_BG_HOVER := Color(0.18, 0.16, 0.2, 0.95)
const BTN_BG_PRESSED := Color(0.22, 0.19, 0.12, 1.0)

# Panel colors
const PANEL_BG := Color(0.1, 0.1, 0.14, 0.98)
const PANEL_BORDER := Color(0.72, 0.58, 0.3, 0.5)


static func add_background(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg


static func style_title(label: Label, font_size: int = 40) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func style_section_label(label: Label, font_size: int = 20) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_SECTION)


static func style_button(btn: Button, font_size: int = 22, subdued := false) -> void:
	btn.add_theme_font_size_override("font_size", font_size)

	if subdued:
		btn.add_theme_color_override("font_color", TEXT_MUTED)
		btn.add_theme_color_override("font_hover_color", Color(0.75, 0.65, 0.5, 1.0))
	else:
		btn.add_theme_color_override("font_color", TEXT_LIGHT)
		btn.add_theme_color_override("font_hover_color", GOLD)

	btn.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_focus_color", TEXT_LIGHT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_BG
	normal.border_color = GOLD_DIM
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = BTN_BG_HOVER
	hover.border_color = GOLD
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(12)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = BTN_BG_PRESSED
	pressed.border_color = GOLD_BRIGHT
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(12)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", hover.duplicate())


static func style_button_accent(btn: Button, accent_color: Color, font_size: int = 22) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", TEXT_LIGHT)
	btn.add_theme_color_override("font_hover_color", accent_color.lightened(0.3))
	btn.add_theme_color_override("font_pressed_color", accent_color.lightened(0.5))
	btn.add_theme_color_override("font_focus_color", TEXT_LIGHT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_BG
	normal.border_color = accent_color.darkened(0.3)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = BTN_BG_HOVER
	hover.border_color = accent_color
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(12)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = BTN_BG_PRESSED
	pressed.border_color = accent_color.lightened(0.3)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(12)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", hover.duplicate())


static func style_button_selected(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.08, 1.0)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)


static func style_panel(panel: PanelContainer, border_color := PANEL_BORDER) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)


static func style_option_button(btn: OptionButton, font_size: int = 22) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", TEXT_LIGHT)
	btn.add_theme_color_override("font_hover_color", GOLD)
	btn.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_focus_color", TEXT_LIGHT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_BG
	normal.border_color = GOLD_DIM
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = BTN_BG_HOVER
	hover.border_color = GOLD
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = BTN_BG_PRESSED
	pressed.border_color = GOLD_BRIGHT
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(10)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", hover.duplicate())


static func style_spin_box(spin: SpinBox, font_size: int = 22) -> void:
	var line_edit := spin.get_line_edit()
	line_edit.add_theme_font_size_override("font_size", font_size)
	line_edit.add_theme_color_override("font_color", TEXT_LIGHT)
	line_edit.add_theme_color_override("caret_color", GOLD)

	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_BG
	normal.border_color = GOLD_DIM
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	line_edit.add_theme_stylebox_override("normal", normal)

	var focus := StyleBoxFlat.new()
	focus.bg_color = BTN_BG_HOVER
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	focus.set_content_margin_all(8)
	line_edit.add_theme_stylebox_override("focus", focus)


static func make_separator(width: float = 480.0) -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(width, 2)
	line.color = GOLD_DIM
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return line
