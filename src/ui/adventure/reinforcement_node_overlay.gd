class_name ReinforcementNodeOverlay
extends Control

signal card_selected(card_id: String)
signal skipped

const CardDisplayComponentScript = preload("res://src/ui/components/CardDisplayComponent.gd")

const CARD_SIZE := Vector2(286, 499)  # 30% larger than original 220x384
const PREVIEW_SIZE := Vector2(429, 749)  # 50% larger than CARD_SIZE
const HOVER_DELAY := 0.5

var _cards: Array = []
var _hover_preview: Control = null
var _hover_timer: Timer = null
var _hover_card_data: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func set_cards(cards: Array) -> void:
	_cards = cards
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

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
	panel_style.bg_color = Color(0.08, 0.1, 0.18, 0.95)
	panel_style.border_color = Color(0.4, 0.5, 0.9, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Choose a Card"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Card display row
	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 20)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_hbox)

	for card in _cards:
		var card_container := _build_card_option(card)
		cards_hbox.add_child(card_container)

	# Skip button
	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(140, 44)
	skip_btn.pressed.connect(func() -> void: skipped.emit())

	var btn_center := HBoxContainer.new()
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_center.add_child(skip_btn)
	vbox.add_child(btn_center)

	# Hover timer (shared)
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY
	_hover_timer.timeout.connect(_show_hover_preview)
	add_child(_hover_timer)


func _build_card_option(card: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# Wrap card in a Control that receives mouse events (CardDisplayComponent has MOUSE_FILTER_IGNORE)
	var hover_area := Control.new()
	hover_area.custom_minimum_size = CARD_SIZE
	hover_area.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(hover_area)

	var display := CardDisplayComponentScript.new()
	display.custom_minimum_size = CARD_SIZE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hover_area.add_child(display)
	display.ready.connect(func() -> void: display.set_card(card))

	# Hover detection on the wrapper
	hover_area.mouse_entered.connect(func() -> void:
		_hover_card_data = card
		_hover_timer.start()
	)
	hover_area.mouse_exited.connect(func() -> void:
		_hover_timer.stop()
		_dismiss_hover_preview()
	)

	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.custom_minimum_size = Vector2(140, 40)
	var card_id: String = str(card.get("card_id", ""))
	select_btn.pressed.connect(func() -> void: card_selected.emit(card_id))
	container.add_child(select_btn)

	return container


func _show_hover_preview() -> void:
	if _hover_card_data.is_empty():
		return
	_dismiss_hover_preview()

	var preview_display := CardDisplayComponentScript.new()
	preview_display.custom_minimum_size = PREVIEW_SIZE
	preview_display.mouse_filter = MOUSE_FILTER_IGNORE

	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size

	var pos := mouse_pos + Vector2(20, -PREVIEW_SIZE.y * 0.5)
	pos.x = clampf(pos.x, 0, viewport_size.x - PREVIEW_SIZE.x)
	pos.y = clampf(pos.y, 0, viewport_size.y - PREVIEW_SIZE.y)

	if pos.x < mouse_pos.x + 20 and pos.x + PREVIEW_SIZE.x > mouse_pos.x:
		pos.x = mouse_pos.x - PREVIEW_SIZE.x - 20
		pos.x = maxf(pos.x, 0)

	preview_display.position = pos
	preview_display.size = PREVIEW_SIZE

	var card_data := _hover_card_data
	preview_display.ready.connect(func() -> void: preview_display.set_card(card_data))

	add_child(preview_display)
	_hover_preview = preview_display


func _dismiss_hover_preview() -> void:
	if _hover_preview != null:
		_hover_preview.queue_free()
		_hover_preview = null
