class_name DoubleCardTemplateBuilderScreen
extends Control

const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")
const CARD_DISPLAY_SCENE = preload("res://scenes/ui/components/CardDisplayComponent.tscn")
const DraggableFrameClass = preload("res://src/ui/components/draggable_frame.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")

const OVERRIDES_PATH := "res://data/double_template_adjustments.json"
# Scale at which the work-area card is rendered. 1.5x the 440x680 reference
# gives a workable size for hand-tuning rect positions without overwhelming the
# screen. The rendered card stays a 440:680 aspect ratio.
const PREVIEW_SCALE := 1.5
const PREVIEW_BASE := Vector2(440.0, 680.0)
const RECT_KEYS := [
	"double_a_cost",
	"double_a_title",
	"double_a_type",
	"double_a_art",
	"double_a_power",
	"double_a_health",
	"double_b_cost",
	"double_b_title",
	"double_b_type",
	"double_b_art",
	"double_b_power",
	"double_b_health",
]
const DEFAULT_DOUBLE_CARD_ID := "iom_double_baliwog_tidecrawlers_and_smoked_baliwog_leg"

signal dismissed

var _frames: Dictionary = {}  # rect_key -> DraggableFrame
var _preview_card: Node = null
var _work_area: Control = null
var _status_label: Label
var _sample_picker: OptionButton
var _label_visibility_toggle: CheckBox
var _card_by_id: Dictionary = {}
var _double_cards: Array = []
var _current_card_id: String = DEFAULT_DOUBLE_CARD_ID


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	CardDisplayComponentClass.USE_ESL_TEMPLATE = true
	if not CardDisplayComponentClass._esl_overrides_loaded:
		CardDisplayComponentClass.load_esl_overrides()
	if not CardDisplayComponentClass._double_overrides_loaded:
		CardDisplayComponentClass.load_double_template_overrides()
	_load_card_catalog()
	_build_ui()
	_load_sample_card(_current_card_id)
	_sync_frames_from_constants()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		dismissed.emit()
		get_viewport().set_input_as_handled()


func _load_card_catalog() -> void:
	var catalog := CardCatalog.load_default()
	_card_by_id = catalog.get("card_by_id", {})
	for cid in _card_by_id.keys():
		var entry: Dictionary = _card_by_id[cid]
		if str(entry.get("card_type", "")) == "double":
			_double_cards.append(entry)
	_double_cards.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))


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

	_build_left_rail(main_box)
	_build_work_area(main_box)
	_build_right_rail(main_box)


func _build_left_rail(parent: Container) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	box.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)

	var header := Label.new()
	header.text = "Double-Card Template Builder"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 16)
	box.add_child(header)

	var hint := Label.new()
	hint.text = "Drag frames to move; drag corners to resize. Save to apply across all double cards. Esc to close."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	box.add_child(hint)

	var picker_label := Label.new()
	picker_label.text = "Sample card"
	picker_label.add_theme_font_size_override("font_size", 12)
	box.add_child(picker_label)

	_sample_picker = OptionButton.new()
	for entry in _double_cards:
		_sample_picker.add_item(str(entry.get("name", "?")))
		var idx := _sample_picker.item_count - 1
		_sample_picker.set_item_metadata(idx, str(entry.get("card_id", "")))
		if str(entry.get("card_id", "")) == _current_card_id:
			_sample_picker.select(idx)
	_sample_picker.item_selected.connect(_on_sample_selected)
	box.add_child(_sample_picker)

	_label_visibility_toggle = CheckBox.new()
	_label_visibility_toggle.text = "Show element labels"
	_label_visibility_toggle.button_pressed = true
	_label_visibility_toggle.toggled.connect(_on_labels_toggled)
	box.add_child(_label_visibility_toggle)


func _build_work_area(parent: Container) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	center.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(center)

	var preview_size := PREVIEW_BASE * PREVIEW_SCALE
	_work_area = Control.new()
	_work_area.custom_minimum_size = preview_size
	_work_area.size = preview_size
	_work_area.clip_contents = true
	center.add_child(_work_area)

	# Card preview rendered behind the draggable frames.
	_preview_card = CARD_DISPLAY_SCENE.instantiate()
	_preview_card.custom_minimum_size = preview_size
	_preview_card.size = preview_size
	_preview_card.set_use_esl_template(true)
	_work_area.add_child(_preview_card)

	# One DraggableFrame per rect, layered on top of the preview card.
	for rect_key in RECT_KEYS:
		var frame := DraggableFrameClass.new()
		frame.label_text = _label_for_key(rect_key)
		frame.rect_changed.connect(func(new_rect): _on_frame_rect_changed(rect_key, new_rect))
		_work_area.add_child(frame)
		_frames[rect_key] = frame


func _build_right_rail(parent: Container) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(180, 0)
	box.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)

	var save_btn := Button.new()
	save_btn.text = "Save to JSON"
	save_btn.pressed.connect(_on_save_pressed)
	box.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to defaults"
	reset_btn.pressed.connect(_on_reset_pressed)
	box.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Close (Esc)"
	close_btn.pressed.connect(func(): dismissed.emit())
	box.add_child(close_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1.0))
	box.add_child(_status_label)


func _load_sample_card(card_id: String) -> void:
	_current_card_id = card_id
	var entry: Dictionary = _card_by_id.get(card_id, {})
	if entry.is_empty():
		return
	_preview_card.apply_card(entry.duplicate(true), CardDisplayComponentClass.PRESENTATION_FULL)


func _on_sample_selected(index: int) -> void:
	var cid := str(_sample_picker.get_item_metadata(index))
	_load_sample_card(cid)


func _on_labels_toggled(pressed: bool) -> void:
	for frame in _frames.values():
		frame.label_text = _label_for_key_internal(frame, pressed)


func _label_for_key_internal(frame: Node, show: bool) -> String:
	if not show:
		return ""
	for key in _frames:
		if _frames[key] == frame:
			return _label_for_key(key)
	return ""


func _label_for_key(rect_key: String) -> String:
	# "double_a_cost" -> "COST A"
	var parts := rect_key.split("_")
	if parts.size() < 3:
		return rect_key
	var half := parts[1].to_upper()
	var elem := parts[2].to_upper()
	return "%s %s" % [elem, half]


func _on_frame_rect_changed(rect_key: String, new_rect: Rect2) -> void:
	# Convert work-area pixels to normalised 440x680 coords, write back to the
	# matching constant on CardDisplayComponent, refresh the preview card.
	var rn := _rect_to_normalised(new_rect)
	_set_rect_n(rect_key, rn)
	_refresh_preview()


func _refresh_preview() -> void:
	if _preview_card == null:
		return
	var data: Dictionary = _preview_card.get_card_data() if _preview_card.has_method("get_card_data") else {}
	if data.is_empty():
		data = _card_by_id.get(_current_card_id, {})
	_preview_card.apply_card(data, CardDisplayComponentClass.PRESENTATION_FULL)


func _sync_frames_from_constants() -> void:
	# Position each DraggableFrame to mirror the corresponding rect constant
	# (converted from normalised → work-area pixels).
	for rect_key in RECT_KEYS:
		var rn: Rect2 = _get_rect_n(rect_key)
		var frame: DraggableFrameClass = _frames[rect_key]
		frame.set_rect(_normalised_to_rect(rn))


func _rect_to_normalised(r: Rect2) -> Rect2:
	var preview_size := PREVIEW_BASE * PREVIEW_SCALE
	return Rect2(
		r.position.x / preview_size.x,
		r.position.y / preview_size.y,
		r.size.x / preview_size.x,
		r.size.y / preview_size.y,
	)


func _normalised_to_rect(rn: Rect2) -> Rect2:
	var preview_size := PREVIEW_BASE * PREVIEW_SCALE
	return Rect2(
		rn.position.x * preview_size.x,
		rn.position.y * preview_size.y,
		rn.size.x * preview_size.x,
		rn.size.y * preview_size.y,
	)


func _get_rect_n(rect_key: String) -> Rect2:
	match rect_key:
		"double_a_cost": return CardDisplayComponentClass.DOUBLE_A_COST_RECT_N
		"double_a_title": return CardDisplayComponentClass.DOUBLE_A_TITLE_RECT_N
		"double_a_type": return CardDisplayComponentClass.DOUBLE_A_TYPE_RECT_N
		"double_a_art": return CardDisplayComponentClass.DOUBLE_A_ART_RECT_N
		"double_a_power": return CardDisplayComponentClass.DOUBLE_A_POWER_RECT_N
		"double_a_health": return CardDisplayComponentClass.DOUBLE_A_HEALTH_RECT_N
		"double_b_cost": return CardDisplayComponentClass.DOUBLE_B_COST_RECT_N
		"double_b_title": return CardDisplayComponentClass.DOUBLE_B_TITLE_RECT_N
		"double_b_type": return CardDisplayComponentClass.DOUBLE_B_TYPE_RECT_N
		"double_b_art": return CardDisplayComponentClass.DOUBLE_B_ART_RECT_N
		"double_b_power": return CardDisplayComponentClass.DOUBLE_B_POWER_RECT_N
		"double_b_health": return CardDisplayComponentClass.DOUBLE_B_HEALTH_RECT_N
	return Rect2()


func _set_rect_n(rect_key: String, rn: Rect2) -> void:
	match rect_key:
		"double_a_cost": CardDisplayComponentClass.DOUBLE_A_COST_RECT_N = rn
		"double_a_title": CardDisplayComponentClass.DOUBLE_A_TITLE_RECT_N = rn
		"double_a_type": CardDisplayComponentClass.DOUBLE_A_TYPE_RECT_N = rn
		"double_a_art": CardDisplayComponentClass.DOUBLE_A_ART_RECT_N = rn
		"double_a_power": CardDisplayComponentClass.DOUBLE_A_POWER_RECT_N = rn
		"double_a_health": CardDisplayComponentClass.DOUBLE_A_HEALTH_RECT_N = rn
		"double_b_cost": CardDisplayComponentClass.DOUBLE_B_COST_RECT_N = rn
		"double_b_title": CardDisplayComponentClass.DOUBLE_B_TITLE_RECT_N = rn
		"double_b_type": CardDisplayComponentClass.DOUBLE_B_TYPE_RECT_N = rn
		"double_b_art": CardDisplayComponentClass.DOUBLE_B_ART_RECT_N = rn
		"double_b_power": CardDisplayComponentClass.DOUBLE_B_POWER_RECT_N = rn
		"double_b_health": CardDisplayComponentClass.DOUBLE_B_HEALTH_RECT_N = rn


func _on_save_pressed() -> void:
	var data := {}
	for rect_key in RECT_KEYS:
		var rn: Rect2 = _get_rect_n(rect_key)
		# Persist in pixel space against the 440x680 reference for human readability.
		data[rect_key] = {
			"x": rn.position.x * 440.0,
			"y": rn.position.y * 680.0,
			"w": rn.size.x * 440.0,
			"h": rn.size.y * 680.0,
		}
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
	# Restore the constants to their declared defaults and resync the frames.
	CardDisplayComponentClass.DOUBLE_A_COST_RECT_N = Rect2(14.0 / 440.0, 40.0 / 680.0, 80.0 / 440.0, 80.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_A_TITLE_RECT_N = Rect2(110.0 / 440.0, 80.0 / 680.0, 230.0 / 440.0, 30.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_A_TYPE_RECT_N = Rect2(150.0 / 440.0, 110.0 / 680.0, 150.0 / 440.0, 20.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_A_ART_RECT_N = Rect2(68.0 / 440.0, 110.0 / 680.0, 310.0 / 440.0, 210.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_A_POWER_RECT_N = Rect2(80.0 / 440.0, 245.0 / 680.0, 70.0 / 440.0, 50.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_A_HEALTH_RECT_N = Rect2(305.0 / 440.0, 245.0 / 680.0, 70.0 / 440.0, 50.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_B_COST_RECT_N = Rect2(14.0 / 440.0, 320.0 / 680.0, 80.0 / 440.0, 80.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_B_TITLE_RECT_N = Rect2(110.0 / 440.0, 360.0 / 680.0, 230.0 / 440.0, 30.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_B_TYPE_RECT_N = Rect2(150.0 / 440.0, 390.0 / 680.0, 150.0 / 440.0, 20.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_B_ART_RECT_N = Rect2(68.0 / 440.0, 390.0 / 680.0, 310.0 / 440.0, 210.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_B_POWER_RECT_N = Rect2(80.0 / 440.0, 525.0 / 680.0, 70.0 / 440.0, 50.0 / 680.0)
	CardDisplayComponentClass.DOUBLE_B_HEALTH_RECT_N = Rect2(305.0 / 440.0, 525.0 / 680.0, 70.0 / 440.0, 50.0 / 680.0)
	_sync_frames_from_constants()
	_refresh_preview()
	_status_label.text = "Reset (not yet saved)"
