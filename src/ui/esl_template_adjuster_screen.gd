class_name ESLTemplateAdjusterScreen
extends Control

const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")
const CARD_DISPLAY_SCENE = preload("res://scenes/ui/components/CardDisplayComponent.tscn")
const OVERRIDES_PATH := "res://data/esl_template_adjustments.json"

signal dismissed

const RECT_NAMES := ["art", "cost", "title", "type", "power", "health", "rules", "ongoing"]

# Representative render sizes encountered in-game.
# Name, size, description.
const PREVIEW_SIZES := [
	{"label": "Deck list preview", "size": Vector2(220, 340)},
	{"label": "Deck editor cell (~4-col)", "size": Vector2(290, 449)},
	{"label": "In-hand card (typical)", "size": Vector2(232, 358)},
	{"label": "Hover preview (1080p)", "size": Vector2(294, 454)},
	{"label": "Hover preview (1440p)", "size": Vector2(393, 607)},
]

var _rect_fields: Dictionary = {}  # rect_name -> {x: SpinBox, y: SpinBox, w: SpinBox, h: SpinBox}
var _preview_cards: Array = []
var _status_label: Label
var _sample_card: Dictionary = {
	"card_id": "adjuster_sample",
	"definition_id": "adjuster_sample",
	"name": "Sample Creature With A Moderately Long Title",
	"card_type": "creature",
	"cost": 5,
	"power": 3,
	"health": 4,
	"rarity": "epic",
	"subtypes": ["nord"],
	"attributes": ["neutral"],
	"rules_text": "Summon: Draw a card.\nLast Gasp: Deal 1 damage to your opponent.",
}
var _sample_ongoing_support: Dictionary = {
	"card_id": "adjuster_sample_ongoing",
	"definition_id": "adjuster_sample_ongoing",
	"name": "Sample Ongoing Support",
	"card_type": "support",
	"cost": 4,
	"rarity": "rare",
	"attributes": ["neutral"],
	"rules_text": "Ongoing\nFriendly creatures have +1/+1.",
}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	CardDisplayComponentClass.USE_ESL_TEMPLATE = true
	if not CardDisplayComponentClass._esl_overrides_loaded:
		CardDisplayComponentClass.load_esl_overrides()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		dismissed.emit()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11, 1.0)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var main_box := HBoxContainer.new()
	main_box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	main_box.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_child(main_box)
	add_child(margin)

	# --- Controls panel ---
	var controls_scroll := ScrollContainer.new()
	controls_scroll.custom_minimum_size = Vector2(360, 0)
	controls_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	main_box.add_child(controls_scroll)

	var controls_vbox := VBoxContainer.new()
	controls_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	controls_vbox.add_theme_constant_override("separation", 10)
	controls_scroll.add_child(controls_vbox)

	var header := Label.new()
	header.text = "ESL Template Adjuster"
	header.add_theme_font_size_override("font_size", 20)
	controls_vbox.add_child(header)

	var hint := Label.new()
	hint.text = "Values are in the 440x680 PNG canvas. Press Esc to close."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_vbox.add_child(hint)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	controls_vbox.add_child(button_row)

	var save_btn := Button.new()
	save_btn.text = "Save to JSON"
	save_btn.pressed.connect(_on_save_pressed)
	button_row.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to defaults"
	reset_btn.pressed.connect(_on_reset_pressed)
	button_row.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Close (Esc)"
	close_btn.pressed.connect(func(): dismissed.emit())
	button_row.add_child(close_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1.0))
	controls_vbox.add_child(_status_label)

	for rect_name in RECT_NAMES:
		controls_vbox.add_child(_build_rect_controls(rect_name))

	# --- Preview panel ---
	var previews_scroll := ScrollContainer.new()
	previews_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	previews_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	main_box.add_child(previews_scroll)

	var previews_flow := HFlowContainer.new()
	previews_flow.size_flags_horizontal = SIZE_EXPAND_FILL
	previews_flow.add_theme_constant_override("h_separation", 20)
	previews_flow.add_theme_constant_override("v_separation", 20)
	previews_scroll.add_child(previews_flow)

	for entry in PREVIEW_SIZES:
		previews_flow.add_child(_build_preview_cell(entry["label"], entry["size"]))


func _build_rect_controls(rect_name: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var header := Label.new()
	header.text = "[ %s ]" % rect_name.capitalize()
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6, 1.0))
	box.add_child(header)

	var current_rect := _get_current_rect_px(rect_name)

	var fields := {}
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)

	for field_name in ["x", "y", "w", "h"]:
		var lbl := Label.new()
		lbl.text = field_name
		lbl.add_theme_font_size_override("font_size", 11)
		grid.add_child(lbl)

	for field_name in ["x", "y", "w", "h"]:
		var spin := SpinBox.new()
		spin.min_value = -200.0
		spin.max_value = 900.0
		spin.step = 1.0
		spin.allow_greater = true
		spin.allow_lesser = true
		var val := 0.0
		match field_name:
			"x": val = current_rect.position.x
			"y": val = current_rect.position.y
			"w": val = current_rect.size.x
			"h": val = current_rect.size.y
		spin.value = val
		spin.custom_minimum_size = Vector2(70, 0)
		spin.value_changed.connect(func(_new_value): _on_field_changed(rect_name))
		grid.add_child(spin)
		fields[field_name] = spin

	_rect_fields[rect_name] = fields
	return box


func _build_preview_cell(label_text: String, preview_size: Vector2) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	cell.size_flags_horizontal = SIZE_SHRINK_CENTER

	var lbl := Label.new()
	lbl.text = "%s  (%dx%d)" % [label_text, int(preview_size.x), int(preview_size.y)]
	lbl.add_theme_font_size_override("font_size", 11)
	cell.add_child(lbl)

	# Two samples side-by-side: creature (shows power/health) and ongoing support
	# (shows the ongoing label strip).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	cell.add_child(row)

	for data in [_sample_card, _sample_ongoing_support]:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = preview_size
		row.add_child(wrapper)
		var card := CARD_DISPLAY_SCENE.instantiate() as CardDisplayComponentClass
		card.custom_minimum_size = preview_size
		card.size = preview_size
		card.set_use_esl_template(true)
		card.apply_card(data.duplicate(true), CardDisplayComponentClass.PRESENTATION_FULL)
		wrapper.add_child(card)
		_preview_cards.append(card)
	return cell


func _get_current_rect_px(rect_name: String) -> Rect2:
	var rn := _get_current_rect_n(rect_name)
	return Rect2(rn.position.x * 440.0, rn.position.y * 680.0, rn.size.x * 440.0, rn.size.y * 680.0)


func _get_current_rect_n(rect_name: String) -> Rect2:
	match rect_name:
		"art": return CardDisplayComponentClass.ESL_ART_RECT_N
		"cost": return CardDisplayComponentClass.ESL_COST_RECT_N
		"title": return CardDisplayComponentClass.ESL_TITLE_RECT_N
		"type": return CardDisplayComponentClass.ESL_TYPE_RECT_N
		"power": return CardDisplayComponentClass.ESL_POWER_RECT_N
		"health": return CardDisplayComponentClass.ESL_HEALTH_RECT_N
		"rules": return CardDisplayComponentClass.ESL_RULES_RECT_N
		"ongoing": return CardDisplayComponentClass.ESL_ONGOING_RECT_N
	return Rect2()


func _set_rect_n(rect_name: String, rn: Rect2) -> void:
	match rect_name:
		"art": CardDisplayComponentClass.ESL_ART_RECT_N = rn
		"cost": CardDisplayComponentClass.ESL_COST_RECT_N = rn
		"title": CardDisplayComponentClass.ESL_TITLE_RECT_N = rn
		"type": CardDisplayComponentClass.ESL_TYPE_RECT_N = rn
		"power": CardDisplayComponentClass.ESL_POWER_RECT_N = rn
		"health": CardDisplayComponentClass.ESL_HEALTH_RECT_N = rn
		"rules": CardDisplayComponentClass.ESL_RULES_RECT_N = rn
		"ongoing": CardDisplayComponentClass.ESL_ONGOING_RECT_N = rn


func _on_field_changed(rect_name: String) -> void:
	var fields: Dictionary = _rect_fields[rect_name]
	var rect_px := Rect2(
		fields["x"].value,
		fields["y"].value,
		fields["w"].value,
		fields["h"].value,
	)
	var rn := Rect2(rect_px.position.x / 440.0, rect_px.position.y / 680.0, rect_px.size.x / 440.0, rect_px.size.y / 680.0)
	_set_rect_n(rect_name, rn)
	_refresh_all_previews()


func _refresh_all_previews() -> void:
	for card in _preview_cards:
		if is_instance_valid(card):
			# Re-apply each card's existing card_data so layout recomputes with new rects.
			var data: Dictionary = card.get_card_data() if card.has_method("get_card_data") else {}
			if data.is_empty():
				data = _sample_card
			card.apply_card(data, CardDisplayComponentClass.PRESENTATION_FULL)


func _on_save_pressed() -> void:
	var data := {}
	for rect_name in RECT_NAMES:
		var r := _get_current_rect_px(rect_name)
		data[rect_name] = {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}
	var file := FileAccess.open(OVERRIDES_PATH, FileAccess.WRITE)
	if file == null:
		_status_label.text = "ERROR: could not open %s for writing" % OVERRIDES_PATH
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1.0))
	_status_label.text = "Saved to %s" % OVERRIDES_PATH


func _on_reset_pressed() -> void:
	# Reset in-memory static vars to their declared defaults by clearing the flag
	# and re-loading (empty file → defaults preserved in constants).
	CardDisplayComponentClass.ESL_ART_RECT_N = Rect2(60.0 / 440.0, 120.0 / 680.0, 320.0 / 440.0, 420.0 / 680.0)
	CardDisplayComponentClass.ESL_COST_RECT_N = Rect2(25.0 / 440.0, 51.0 / 680.0, 80.0 / 440.0, 80.0 / 680.0)
	CardDisplayComponentClass.ESL_TITLE_RECT_N = Rect2(100.0 / 440.0, 78.0 / 680.0, 252.0 / 440.0, 30.0 / 680.0)
	CardDisplayComponentClass.ESL_TYPE_RECT_N = Rect2(95.0 / 440.0, 111.0 / 680.0, 250.0 / 440.0, 22.0 / 680.0)
	CardDisplayComponentClass.ESL_POWER_RECT_N = Rect2(15.0 / 440.0, 359.0 / 680.0, 100.0 / 440.0, 60.0 / 680.0)
	CardDisplayComponentClass.ESL_HEALTH_RECT_N = Rect2(325.0 / 440.0, 362.0 / 680.0, 100.0 / 440.0, 60.0 / 680.0)
	CardDisplayComponentClass.ESL_RULES_RECT_N = Rect2(70.0 / 440.0, 493.0 / 680.0, 310.0 / 440.0, 120.0 / 680.0)
	CardDisplayComponentClass.ESL_ONGOING_RECT_N = Rect2(95.0 / 440.0, 470.0 / 680.0, 250.0 / 440.0, 22.0 / 680.0)
	# Sync SpinBoxes to new values
	for rect_name in RECT_NAMES:
		var fields: Dictionary = _rect_fields[rect_name]
		var r := _get_current_rect_px(rect_name)
		fields["x"].set_value_no_signal(r.position.x)
		fields["y"].set_value_no_signal(r.position.y)
		fields["w"].set_value_no_signal(r.size.x)
		fields["h"].set_value_no_signal(r.size.y)
	_status_label.text = "Reset (not yet saved)"
	_refresh_all_previews()
