class_name ShopNodeOverlay
extends Control

signal card_purchased(card_id: String, cost: int)
signal closed
signal reroll_requested

const CardDisplayComponentScript = preload("res://src/ui/components/CardDisplayComponent.gd")
const AdventureCardPoolScript = preload("res://src/adventure/adventure_card_pool.gd")

const CARD_SIZE := Vector2(234, 411)  # 30% larger than original 180x316
const PREVIEW_SIZE := Vector2(351, 616)  # 50% larger than CARD_SIZE
const HOVER_DELAY := 0.5

var _cards: Array = []
var _gold: int = 0
var _purchased_ids: Array = []
var _reroll_tokens: int = 0
var _gold_label: Label
var _buy_buttons: Array = []  # Array of {button: Button, cost: int, card_id: String}
var _hover_preview: Control = null
var _hover_timer: Timer = null
var _hover_card_data: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func set_shop_data(cards: Array, gold: int, purchased_ids: Array = [], reroll_tokens: int = 0) -> void:
	_cards = cards
	_gold = gold
	_purchased_ids = purchased_ids
	_reroll_tokens = reroll_tokens
	_build_ui()


func update_gold(new_gold: int) -> void:
	_gold = new_gold
	if _gold_label != null:
		_gold_label.text = "Gold: %d" % _gold
	_refresh_buy_buttons()


func _refresh_buy_buttons() -> void:
	for entry in _buy_buttons:
		var btn: Button = entry["button"]
		var cost: int = entry["cost"]
		if not btn.disabled:
			btn.disabled = _gold < cost
			if btn.disabled:
				btn.text = "%d gold" % cost


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_buy_buttons.clear()

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
	panel_style.bg_color = Color(0.12, 0.1, 0.06, 0.95)
	panel_style.border_color = Color(0.9, 0.75, 0.3, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Header with title and gold
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Shop"
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)

	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % _gold
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
	header.add_child(_gold_label)

	# Cards — two rows of 3
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(top_row)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 20)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom_row)

	for i in range(_cards.size()):
		var card: Dictionary = _cards[i]
		var card_option := _build_shop_card(card)
		if i < 3:
			top_row.add_child(card_option)
		else:
			bottom_row.add_child(card_option)

	# Bottom buttons
	var btn_center := HBoxContainer.new()
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_center.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_center)

	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll (%d)" % _reroll_tokens
	reroll_btn.custom_minimum_size = Vector2(140, 44)
	reroll_btn.disabled = _reroll_tokens <= 0
	reroll_btn.pressed.connect(func() -> void: reroll_requested.emit())
	btn_center.add_child(reroll_btn)

	var done_btn := Button.new()
	done_btn.text = "Done"
	done_btn.custom_minimum_size = Vector2(140, 44)
	done_btn.pressed.connect(func() -> void: closed.emit())
	btn_center.add_child(done_btn)

	# Hover timer (shared)
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY
	_hover_timer.timeout.connect(_show_hover_preview)
	add_child(_hover_timer)


func _build_shop_card(card: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)

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

	var cost: int = AdventureCardPoolScript.get_price_for_card(card)
	var card_id: String = str(card.get("card_id", ""))

	var already_purchased := card_id in _purchased_ids

	var buy_btn := Button.new()
	if already_purchased:
		buy_btn.text = "Sold"
		buy_btn.disabled = true
	else:
		buy_btn.text = "Buy — %d gold" % cost
		buy_btn.disabled = _gold < cost

	buy_btn.custom_minimum_size = Vector2(200, 40)

	if not already_purchased:
		buy_btn.pressed.connect(func() -> void:
			buy_btn.disabled = true
			buy_btn.text = "Sold"
			card_purchased.emit(card_id, cost)
		)

	_buy_buttons.append({"button": buy_btn, "cost": cost, "card_id": card_id})
	container.add_child(buy_btn)

	return container


func _show_hover_preview() -> void:
	if _hover_card_data.is_empty():
		return
	_dismiss_hover_preview()

	var preview_display := CardDisplayComponentScript.new()
	preview_display.custom_minimum_size = PREVIEW_SIZE
	preview_display.mouse_filter = MOUSE_FILTER_IGNORE

	# Position near mouse, clamped to screen
	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size

	var pos := mouse_pos + Vector2(20, -PREVIEW_SIZE.y * 0.5)
	# Clamp to keep on screen
	pos.x = clampf(pos.x, 0, viewport_size.x - PREVIEW_SIZE.x)
	pos.y = clampf(pos.y, 0, viewport_size.y - PREVIEW_SIZE.y)

	# If preview would overlap the mouse horizontally, shift to the left side
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
