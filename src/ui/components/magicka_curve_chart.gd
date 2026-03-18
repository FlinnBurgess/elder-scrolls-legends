class_name MagickaCurveChart
extends Control

const BUCKET_COUNT := 8
const BUCKET_LABELS := ["0", "1", "2", "3", "4", "5", "6", "7+"]
const BAR_COLOR := Color(0.42, 0.62, 0.96)
const BAR_SPACING := 4.0
const LABEL_FONT_SIZE := 12
const COUNT_FONT_SIZE := 11
const COST_LABEL_HEIGHT := 18.0
const COUNT_LABEL_HEIGHT := 16.0
const MIN_BAR_HEIGHT := 2.0

var _buckets: Array[int] = []
var _is_built := false

var _bars_container: Control
var _bar_panels: Array[PanelContainer] = []
var _count_labels: Array[Label] = []
var _cost_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 100)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	_buckets.resize(BUCKET_COUNT)
	_buckets.fill(0)
	if not _is_built:
		_build_internal_nodes()
	_layout_internal_nodes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _is_built:
		_layout_internal_nodes()


func set_deck(definition: Dictionary, card_by_id: Dictionary) -> void:
	_buckets = compute_buckets(definition, card_by_id)
	_refresh_bars()


static func compute_buckets(definition: Dictionary, card_by_id: Dictionary) -> Array[int]:
	var buckets: Array[int] = []
	buckets.resize(BUCKET_COUNT)
	buckets.fill(0)

	var cards: Array = definition.get("cards", [])
	for entry in cards:
		var card_id: String = entry.get("card_id", "")
		var quantity: int = entry.get("quantity", 0)
		var card: Dictionary = card_by_id.get(card_id, {})
		if card.is_empty():
			continue
		var cost: int = card.get("cost", 0)
		var bucket_index: int = mini(cost, BUCKET_COUNT - 1)
		buckets[bucket_index] += quantity

	return buckets


func _build_internal_nodes() -> void:
	_bars_container = Control.new()
	_bars_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bars_container)

	_bar_panels.clear()
	_count_labels.clear()
	_cost_labels.clear()

	for i in BUCKET_COUNT:
		var bar := PanelContainer.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = BAR_COLOR
		bar_style.corner_radius_top_left = 2
		bar_style.corner_radius_top_right = 2
		bar.add_theme_stylebox_override("panel", bar_style)
		_bars_container.add_child(bar)
		_bar_panels.append(bar)

		var count_label := Label.new()
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", COUNT_FONT_SIZE)
		add_child(count_label)
		_count_labels.append(count_label)

		var cost_label := Label.new()
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.text = BUCKET_LABELS[i]
		cost_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		add_child(cost_label)
		_cost_labels.append(cost_label)

	_is_built = true


func _layout_internal_nodes() -> void:
	if not _is_built:
		return

	var total_width: float = size.x
	var total_height: float = size.y
	var bar_area_height: float = total_height - COST_LABEL_HEIGHT - COUNT_LABEL_HEIGHT
	var bar_width: float = (total_width - BAR_SPACING * (BUCKET_COUNT - 1)) / BUCKET_COUNT

	_bars_container.position = Vector2.ZERO
	_bars_container.size = size

	var max_count: int = 0
	for b in _buckets:
		max_count = maxi(max_count, b)

	for i in BUCKET_COUNT:
		var x_pos: float = i * (bar_width + BAR_SPACING)

		# Bar height
		var bar_height: float = MIN_BAR_HEIGHT
		if max_count > 0 and _buckets[i] > 0:
			bar_height = maxf(MIN_BAR_HEIGHT, (float(_buckets[i]) / float(max_count)) * bar_area_height)

		var bar_y: float = COUNT_LABEL_HEIGHT + (bar_area_height - bar_height)
		_bar_panels[i].position = Vector2(x_pos, bar_y)
		_bar_panels[i].size = Vector2(bar_width, bar_height)
		_bar_panels[i].visible = _buckets[i] > 0

		# Count label above bar
		_count_labels[i].position = Vector2(x_pos, bar_y - COUNT_LABEL_HEIGHT)
		_count_labels[i].size = Vector2(bar_width, COUNT_LABEL_HEIGHT)
		_count_labels[i].text = str(_buckets[i]) if _buckets[i] > 0 else ""

		# Cost label below bars
		_cost_labels[i].position = Vector2(x_pos, total_height - COST_LABEL_HEIGHT)
		_cost_labels[i].size = Vector2(bar_width, COST_LABEL_HEIGHT)


func _refresh_bars() -> void:
	if not _is_built:
		return
	_layout_internal_nodes()
