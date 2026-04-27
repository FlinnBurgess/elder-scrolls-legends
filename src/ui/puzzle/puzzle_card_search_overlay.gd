class_name PuzzleCardSearchOverlay
extends PanelContainer

## Full-screen overlay for searching and selecting a card from the catalog.
## Emits card_selected (left-click) with the card_id when a card is chosen.
## When multi_add_mode is enabled, right-click emits card_add_requested
## without closing the overlay and displays a short "Added" toast.

signal card_selected(card_id: String)
signal card_add_requested(card_id: String)
signal cancelled

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const CardDisplayComponentScript = preload("res://src/ui/components/CardDisplayComponent.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")

const GRID_COLUMNS := 7
const GRID_ROWS := 2
const CARDS_PER_PAGE := GRID_COLUMNS * GRID_ROWS
const TOAST_DURATION := 1.1
const CARD_ASPECT_RATIO := 340.0 / 220.0
const COLUMN_SEPARATION := 8
const ROW_SEPARATION := 100
const GRID_TOP_MARGIN := 40

var multi_add_mode := false
# Set by the listener of card_add_requested (synchronously, during emit) to
# signal that the add was rejected — overlay then shows this as the toast
# instead of "Added: <card>".
var add_reject_reason := ""

var _all_cards: Array = []
var _filtered: Array = []
var _page := 0
var _search_input: LineEdit
var _type_filter: OptionButton
var _grid: VBoxContainer
var _page_label: Label
var _card_type_filter := ""
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _header_row: HBoxContainer
var _filter_row: HBoxContainer
var _page_row: HBoxContainer
const ROOT_SEPARATION := 12
const OVERLAY_MARGIN_X := 40
const OVERLAY_MARGIN_Y := 30


func _ready() -> void:
	_load_catalog()
	_build_ui()
	_apply_filter()
	_search_input.grab_focus.call_deferred()


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
	resized.connect(_update_row_heights)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	add_theme_stylebox_override("panel", bg_style)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", OVERLAY_MARGIN_X)
	margin.add_theme_constant_override("margin_right", OVERLAY_MARGIN_X)
	margin.add_theme_constant_override("margin_top", OVERLAY_MARGIN_Y)
	margin.add_theme_constant_override("margin_bottom", OVERLAY_MARGIN_Y)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", ROOT_SEPARATION)
	margin.add_child(root)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	_header_row = header

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
	_filter_row = filter_row

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search by name..."
	_search_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_input.custom_minimum_size = Vector2(400, 80)
	_search_input.add_theme_font_size_override("font_size", 32)
	_search_input.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	_search_input.add_theme_color_override("font_placeholder_color", UITheme.TEXT_MUTED)
	_search_input.add_theme_color_override("caret_color", UITheme.GOLD)
	var search_normal := StyleBoxFlat.new()
	search_normal.bg_color = UITheme.BTN_BG
	search_normal.border_color = UITheme.GOLD_DIM
	search_normal.set_border_width_all(1)
	search_normal.set_corner_radius_all(6)
	search_normal.set_content_margin_all(16)
	_search_input.add_theme_stylebox_override("normal", search_normal)
	var search_focus := StyleBoxFlat.new()
	search_focus.bg_color = UITheme.BTN_BG_HOVER
	search_focus.border_color = UITheme.GOLD
	search_focus.set_border_width_all(2)
	search_focus.set_corner_radius_all(6)
	search_focus.set_content_margin_all(16)
	_search_input.add_theme_stylebox_override("focus", search_focus)
	_search_input.text_changed.connect(func(_t): _page = 0; _apply_filter())
	filter_row.add_child(_search_input)

	_type_filter = OptionButton.new()
	_type_filter.custom_minimum_size = Vector2(200, 80)
	_type_filter.add_item("All Types", 0)
	_type_filter.add_item("Creature", 1)
	_type_filter.add_item("Action", 2)
	_type_filter.add_item("Item", 3)
	_type_filter.add_item("Support", 4)
	UITheme.style_option_button(_type_filter, 24)
	_type_filter.item_selected.connect(func(_idx): _page = 0; _apply_filter())
	filter_row.add_child(_type_filter)

	# Explicit top-margin spacer above the grid (more reliable than MarginContainer
	# wrapper, which can have its margin squeezed under min-size contention).
	var grid_top_spacer := Control.new()
	grid_top_spacer.custom_minimum_size = Vector2(0, GRID_TOP_MARGIN)
	grid_top_spacer.mouse_filter = MOUSE_FILTER_IGNORE
	root.add_child(grid_top_spacer)

	# Card grid area — VBox of HBox rows
	_grid = VBoxContainer.new()
	_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_grid.size_flags_vertical = SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("separation", ROW_SEPARATION)
	_grid.resized.connect(_update_row_heights)
	root.add_child(_grid)

	# Pagination
	var page_row := HBoxContainer.new()
	page_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page_row.add_theme_constant_override("separation", 24)
	root.add_child(page_row)
	_page_row = page_row

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(72, 64)
	prev_btn.add_theme_font_size_override("font_size", 28)
	prev_btn.pressed.connect(func(): _page = maxi(0, _page - 1); _render_page())
	page_row.add_child(prev_btn)

	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(220, 64)
	_page_label.add_theme_font_size_override("font_size", 24)
	page_row.add_child(_page_label)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(72, 64)
	next_btn.add_theme_font_size_override("font_size", 28)
	next_btn.pressed.connect(func():
		var max_page := maxi(0, ceili(float(_filtered.size()) / CARDS_PER_PAGE) - 1)
		_page = mini(_page + 1, max_page)
		_render_page()
	)
	page_row.add_child(next_btn)

	_build_toast()


func _build_toast() -> void:
	# The overlay itself is a PanelContainer which auto-sizes its children to
	# fill. Wrap the toast in a plain Control layer so anchors aren't overridden.
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 10
	add_child(layer)

	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_panel.modulate.a = 0.0
	_toast_panel.size_flags_horizontal = 0
	_toast_panel.size_flags_vertical = 0

	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	toast_style.border_color = UITheme.GOLD
	toast_style.set_border_width_all(2)
	toast_style.set_corner_radius_all(8)
	toast_style.set_content_margin_all(16)
	_toast_panel.add_theme_stylebox_override("panel", toast_style)

	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	_toast_panel.add_child(_toast_label)

	# Anchor toast to bottom-center of the layer; size from content minimum.
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 1.0
	_toast_panel.anchor_bottom = 1.0
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_panel.offset_left = 0
	_toast_panel.offset_right = 0
	_toast_panel.offset_top = 0
	_toast_panel.offset_bottom = -60
	layer.add_child(_toast_panel)


func _show_toast(message: String) -> void:
	if _toast_panel == null:
		return
	_toast_label.text = message
	_toast_panel.visible = true
	if _toast_tween != null and _toast_tween.is_running():
		_toast_tween.kill()
	_toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_DURATION)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)


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

	var current_row: HBoxContainer
	for i in range(start, end):
		# Start a new row every GRID_COLUMNS cards
		if (i - start) % GRID_COLUMNS == 0:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", COLUMN_SEPARATION)
			current_row.size_flags_horizontal = SIZE_EXPAND_FILL
			_grid.add_child(current_row)

		var card: Dictionary = _filtered[i]
		var card_id := str(card.get("_card_id", ""))

		# Card container — fixed size set by _update_row_heights, clickable
		var card_container := Control.new()
		card_container.mouse_filter = MOUSE_FILTER_STOP
		current_row.add_child(card_container)

		var display := CardDisplayComponentScript.new()
		display.custom_minimum_size = Vector2(1, 1)
		display.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		card_container.add_child(display)
		display.set_presentation_mode("full")
		display.custom_minimum_size = Vector2(1, 1)
		display.set_card(card)
		display.custom_minimum_size = Vector2(1, 1)

		var cid := card_id
		var card_name := str(card.get("name", cid))
		card_container.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					card_selected.emit(cid)
				elif event.button_index == MOUSE_BUTTON_RIGHT and multi_add_mode:
					add_reject_reason = ""
					card_add_requested.emit(cid)
					if add_reject_reason.is_empty():
						_show_toast("Added: %s" % card_name)
					else:
						_show_toast(add_reject_reason)
		)

	_update_row_heights()


func _update_row_heights() -> void:
	if _grid == null:
		return
	# Derive the available grid area from the overlay (window-anchored = stable)
	# and the chrome rows' content-derived minimum sizes. Doing it this way avoids
	# a feedback loop with our own row min-size assignments — using _grid.size for
	# the clamp lets the grid grow under our own pressure and the cards never shrink.
	var overlay_size := size
	if overlay_size.x <= 0.0 or overlay_size.y <= 0.0:
		return
	var root_h := overlay_size.y - float(2 * OVERLAY_MARGIN_Y)
	var root_w := overlay_size.x - float(2 * OVERLAY_MARGIN_X)
	var chrome_h := 0.0
	if _header_row != null:
		chrome_h += _header_row.get_combined_minimum_size().y
	if _filter_row != null:
		chrome_h += _filter_row.get_combined_minimum_size().y
	if _page_row != null:
		chrome_h += _page_row.get_combined_minimum_size().y
	chrome_h += float(GRID_TOP_MARGIN)
	# Root has 5 children (header, filter, spacer, grid, page) → 4 separations.
	chrome_h += float(ROOT_SEPARATION * 4)
	var avail_grid_h := root_h - chrome_h
	var avail_grid_w := root_w
	if avail_grid_h <= 0.0 or avail_grid_w <= 0.0:
		return
	var avail_w := avail_grid_w - float(COLUMN_SEPARATION * (GRID_COLUMNS - 1))
	var avail_h := avail_grid_h - float(ROW_SEPARATION * (GRID_ROWS - 1))
	if avail_w <= 0.0 or avail_h <= 0.0:
		return
	var max_cell_w := avail_w / float(GRID_COLUMNS)
	var max_cell_h := avail_h / float(GRID_ROWS)
	var cell_w := minf(max_cell_w, max_cell_h / CARD_ASPECT_RATIO)
	var cell_h := cell_w * CARD_ASPECT_RATIO
	for child in _grid.get_children():
		if child is HBoxContainer:
			var row := child as HBoxContainer
			row.custom_minimum_size = Vector2(0, cell_h)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			for card_container in row.get_children():
				if card_container is Control:
					card_container.custom_minimum_size = Vector2(cell_w, cell_h)
