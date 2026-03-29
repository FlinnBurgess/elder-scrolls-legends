class_name PuzzleCardSearchOverlay
extends PanelContainer

## Full-screen overlay for searching and selecting a card from the catalog.
## Emits card_selected with the card_id when a card is chosen.

signal card_selected(card_id: String)
signal cancelled

const CardCatalog = preload("res://src/deck/card_catalog.gd")

const GRID_COLUMNS := 4
const GRID_ROWS := 4
const CARDS_PER_PAGE := GRID_COLUMNS * GRID_ROWS

var _all_cards: Array = []
var _filtered: Array = []
var _page := 0
var _search_input: LineEdit
var _type_filter: OptionButton
var _grid: GridContainer
var _page_label: Label
var _card_type_filter := ""


func _ready() -> void:
	_load_catalog()
	_build_ui()
	_apply_filter()


func set_type_filter(card_type: String) -> void:
	var idx := 0
	match card_type.to_lower():
		"creature": idx = 1
		"action": idx = 2
		"item": idx = 3
		"support": idx = 4
	if _type_filter != null:
		_type_filter.select(idx)
		_page = 0
		_apply_filter()


func _load_catalog() -> void:
	var result := CardCatalog.load_default()
	var card_by_id: Dictionary = result.get("card_by_id", {})
	for card_id in card_by_id:
		var card: Dictionary = card_by_id[card_id]
		card["_card_id"] = card_id
		_all_cards.append(card)
	_all_cards.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 60
	mouse_filter = MOUSE_FILTER_STOP

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	add_theme_stylebox_override("panel", bg_style)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 36)
	cancel_btn.pressed.connect(func(): cancelled.emit())
	header.add_child(cancel_btn)

	var title := Label.new()
	title.text = "Select Card"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	# Filter row
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 12)
	root.add_child(filter_row)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search by name..."
	_search_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_input.custom_minimum_size = Vector2(200, 36)
	_search_input.text_changed.connect(func(_t): _page = 0; _apply_filter())
	filter_row.add_child(_search_input)

	_type_filter = OptionButton.new()
	_type_filter.custom_minimum_size = Vector2(120, 36)
	_type_filter.add_item("All Types", 0)
	_type_filter.add_item("Creature", 1)
	_type_filter.add_item("Action", 2)
	_type_filter.add_item("Item", 3)
	_type_filter.add_item("Support", 4)
	_type_filter.item_selected.connect(func(_idx): _page = 0; _apply_filter())
	filter_row.add_child(_type_filter)

	# Grid
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_grid.size_flags_vertical = SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(_grid)

	# Pagination
	var page_row := HBoxContainer.new()
	page_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page_row.add_theme_constant_override("separation", 16)
	root.add_child(page_row)

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 36)
	prev_btn.pressed.connect(func(): _page = maxi(0, _page - 1); _render_page())
	page_row.add_child(prev_btn)

	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(120, 0)
	page_row.add_child(_page_label)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(40, 36)
	next_btn.pressed.connect(func():
		var max_page := maxi(0, ceili(float(_filtered.size()) / CARDS_PER_PAGE) - 1)
		_page = mini(_page + 1, max_page)
		_render_page()
	)
	page_row.add_child(next_btn)


func _apply_filter() -> void:
	var search := _search_input.text.strip_edges().to_lower()
	var type_idx := _type_filter.get_selected_id()
	var type_name := ""
	match type_idx:
		1: type_name = "creature"
		2: type_name = "action"
		3: type_name = "item"
		4: type_name = "support"

	_filtered.clear()
	for card in _all_cards:
		if not search.is_empty():
			var name_lower := str(card.get("name", "")).to_lower()
			var text_lower := str(card.get("rules_text", "")).to_lower()
			if name_lower.find(search) == -1 and text_lower.find(search) == -1:
				continue
		if not type_name.is_empty():
			if str(card.get("card_type", "")).to_lower() != type_name:
				continue
		_filtered.append(card)
	_render_page()


func _render_page() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var total_pages := maxi(1, ceili(float(_filtered.size()) / CARDS_PER_PAGE))
	_page = clampi(_page, 0, total_pages - 1)
	_page_label.text = "Page %d / %d" % [_page + 1, total_pages]

	var start := _page * CARDS_PER_PAGE
	var end := mini(start + CARDS_PER_PAGE, _filtered.size())

	for i in range(start, end):
		var card: Dictionary = _filtered[i]
		var btn := Button.new()
		var card_name := str(card.get("name", "???"))
		var cost := str(card.get("cost", "?"))
		var card_type := str(card.get("card_type", ""))
		var stats := ""
		if card_type.to_lower() == "creature":
			stats = " %s/%s" % [str(card.get("base_power", "?")), str(card.get("base_health", "?"))]
		btn.text = "[%s] %s%s" % [cost, card_name, stats]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		var card_id := str(card.get("_card_id", ""))
		btn.pressed.connect(func(): card_selected.emit(card_id))
		_grid.add_child(btn)
