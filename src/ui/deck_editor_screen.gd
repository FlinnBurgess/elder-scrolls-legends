class_name DeckEditorScreen
extends Control

const DeckPersistenceClass = preload("res://src/deck/deck_persistence.gd")
const DeckValidator = preload("res://src/deck/deck_validator.gd")
const DeckRulesRegistryClass = preload("res://src/deck/deck_rules_registry.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")
const DeckCodeClass = preload("res://src/deck/deck_code.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const DECK_REGISTRY_PATH := "res://data/legends/registries/attribute_class_registry.json"
const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")
const DeckCreationModalClass = preload("res://src/ui/deck_creation_modal.gd")
const MagickaCurveChartClass = preload("res://src/ui/components/magicka_curve_chart.gd")
const ErrorReportWriterClass = preload("res://src/core/error_report_writer.gd")
const ErrorReportPopoverClass = preload("res://src/ui/components/error_report_popover.gd")
const DeckCardListClass = preload("res://src/ui/components/deck_card_list.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")
const CARD_ASPECT_RATIO := 384.0 / 220.0
const ATTRIBUTE_TINTS := {
	"strength": Color(0.84, 0.39, 0.31, 1.0),
	"intelligence": Color(0.42, 0.62, 0.96, 1.0),
	"willpower": Color(0.92, 0.78, 0.38, 1.0),
	"agility": Color(0.4, 0.76, 0.52, 1.0),
	"endurance": Color(0.58, 0.46, 0.72, 1.0),
}
const NEUTRAL_COST_COLOR := Color(0.6, 0.6, 0.6, 1.0)
const GRID_COLUMNS := 4
const GRID_ROWS := 3
const CARDS_PER_PAGE := GRID_COLUMNS * GRID_ROWS
const GRID_H_SEPARATION := 12
const GRID_V_SEPARATION := 12

signal done_pressed
signal cancel_pressed

var _rules_registry
var _keyword_registry := {}
var _catalog_cards: Array = []
var _card_by_id := {}
var _attribute_display_names := {}
var _class_display_names := {}
var _class_records: Array = []
var _card_id_to_deck_code := {}

# Deck state
var _deck_name := ""
var _deck_attribute_ids: Array[String] = []
var _deck_quantities := {}
var _original_deck_definition := {}

# Pagination state
var _current_page := 0
var _filtered_cache: Array = []
var _total_pages := 1

# Filter state — attributes and costs support multi-select via toggle chips
var _active_attribute_filters: Array[String] = []
var _active_cost_filters: Array[int] = []
var _browser_class_filter := ""
var _browser_type_filter := ""
var _browser_keyword_filter := ""
var _search_query := ""

# UI references
var _search_input: LineEdit
var _attribute_chip_container: HBoxContainer
var _cost_chip_container: HBoxContainer
var _class_filter_button: OptionButton
var _type_filter_button: OptionButton
var _keyword_filter_button: OptionButton
var _browser_summary_label: Label
var _card_grid: GridContainer
var _browser_scroll: ScrollContainer
var _card_display_by_id: Dictionary = {}
var _left_column: VBoxContainer
var _right_column: VBoxContainer
var _deck_header_name_label: Label
var _deck_header_attr_container: HBoxContainer
var _deck_card_list: DeckCardList
var _deck_card_list_scroll: ScrollContainer
var _card_hover_preview_layer: Control
var _magicka_curve_chart: Control
var _card_count_label: Label
var _root_split: HSplitContainer
var _pagination_container: HBoxContainer
var _prev_page_button: Button
var _next_page_button: Button
var _page_label: Label
var _hovered_card_id := ""
var _error_report_hovered_type := ""
var _error_report_hovered_context := ""
var _error_report_popover: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_data()
	_build_ui()
	_disable_button_focus(self)
	_refresh_browser()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.unicode == 34 and _error_report_popover == null:
			_open_error_report_popover()
			get_viewport().set_input_as_handled()
			return
		if _error_report_popover != null:
			if event.keycode == KEY_ESCAPE:
				var popover := _error_report_popover
				_error_report_popover = null
				popover.dismissed.emit()
				popover.queue_free()
				get_viewport().set_input_as_handled()
			return
		if (event.keycode == KEY_UP or event.keycode == KEY_DOWN) and _hovered_card_id != "":
			var card_display = _card_display_by_id.get(_hovered_card_id, null)
			if card_display != null and is_instance_valid(card_display) and card_display.has_method("cycle_relationship"):
				var direction := 1 if event.keycode == KEY_DOWN else -1
				card_display.cycle_relationship(direction)
				get_viewport().set_input_as_handled()
				return
		if event.keycode == KEY_LEFT:
			_on_prev_page_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			_on_next_page_pressed()
			get_viewport().set_input_as_handled()


func load_deck(deck_name: String, definition: Dictionary) -> void:
	_original_deck_definition = definition.duplicate(true)
	_deck_name = deck_name
	_deck_attribute_ids.clear()
	for attr_id in definition.get("attribute_ids", []):
		_deck_attribute_ids.append(str(attr_id))
	_deck_quantities.clear()
	for entry in definition.get("cards", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var card_id := str(entry.get("card_id", ""))
		var quantity := int(entry.get("quantity", 0))
		if not card_id.is_empty() and quantity > 0:
			_deck_quantities[card_id] = quantity
	_refresh_deck_header()
	_refresh_attribute_chips()
	_refresh_deck_card_list()
	_refresh_magicka_curve()
	_refresh_card_count()
	_refresh_browser()


func get_filtered_cards() -> Array:
	return _filtered_cards()


func get_deck_definition() -> Dictionary:
	var entries: Array = []
	var ids: Array = _deck_quantities.keys()
	ids.sort()
	for card_id in ids:
		entries.append({
			"card_id": str(card_id),
			"quantity": int(_deck_quantities.get(card_id, 0)),
		})
	return {
		"name": _deck_name,
		"attribute_ids": _deck_attribute_ids.duplicate(),
		"cards": entries,
	}


func get_deck_card_quantity(card_id: String) -> int:
	return int(_deck_quantities.get(card_id, 0))


func get_deck_count() -> int:
	var total := 0
	for quantity in _deck_quantities.values():
		total += int(quantity)
	return total


func get_card_by_id() -> Dictionary:
	return _card_by_id


func get_rules_registry():
	return _rules_registry


func add_card_to_deck(card_id: String) -> void:
	if not _card_by_id.has(card_id):
		return
	var card: Dictionary = _card_by_id[card_id]
	var limit := _copy_limit(card)
	var current := get_deck_card_quantity(card_id)
	if current >= limit:
		return
	_deck_quantities[card_id] = current + 1
	_refresh_card_quantities()


func add_max_cards_to_deck(card_id: String) -> void:
	if not _card_by_id.has(card_id):
		return
	var card: Dictionary = _card_by_id[card_id]
	var limit := _copy_limit(card)
	var current := get_deck_card_quantity(card_id)
	if current >= limit:
		return
	_deck_quantities[card_id] = limit
	_refresh_card_quantities()


func remove_card_from_deck(card_id: String) -> void:
	if not _deck_quantities.has(card_id):
		return
	var next := int(_deck_quantities.get(card_id, 0)) - 1
	if next <= 0:
		_deck_quantities.erase(card_id)
	else:
		_deck_quantities[card_id] = next
	_refresh_card_quantities()


func _copy_limit(card: Dictionary) -> int:
	return _rules_registry.get_unique_copy_limit() if bool(card.get("is_unique", false)) else _rules_registry.get_default_copy_limit()


# --- Data Loading ---

func _load_data() -> void:
	_rules_registry = DeckRulesRegistryClass.load_default()
	var catalog_result := CardCatalog.load_default()
	_catalog_cards = catalog_result.get("cards", [])
	_card_by_id = catalog_result.get("card_by_id", {})
	_card_id_to_deck_code = catalog_result.get("card_id_to_deck_code", {})
	_keyword_registry = EvergreenRules.get_registry()
	_load_attribute_registry_labels()


func _load_attribute_registry_labels() -> void:
	var file := FileAccess.open(DECK_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for raw_attribute in parsed.get("attributes", []):
		if typeof(raw_attribute) != TYPE_DICTIONARY:
			continue
		var attribute: Dictionary = raw_attribute
		_attribute_display_names[str(attribute.get("id", ""))] = str(attribute.get("display_name", attribute.get("id", "")))
	for bucket in ["dual_classes", "triple_classes"]:
		for raw_class in parsed.get(bucket, []):
			if typeof(raw_class) != TYPE_DICTIONARY:
				continue
			var class_record: Dictionary = raw_class
			_class_records.append(class_record)
			_class_display_names[str(class_record.get("id", ""))] = str(class_record.get("display_name", class_record.get("id", "")))


# --- UI Construction ---

func _build_ui() -> void:
	UITheme.add_background(self)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 80)
	outer_margin.add_theme_constant_override("margin_right", 80)
	outer_margin.add_theme_constant_override("margin_top", 50)
	outer_margin.add_theme_constant_override("margin_bottom", 50)
	add_child(outer_margin)

	_root_split = HSplitContainer.new()
	_root_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_root_split.size_flags_vertical = SIZE_EXPAND_FILL
	_root_split.add_theme_constant_override("separation", 16)
	_root_split.resized.connect(_on_root_split_resized)
	outer_margin.add_child(_root_split)

	_left_column = VBoxContainer.new()
	_left_column.size_flags_horizontal = SIZE_EXPAND_FILL
	_left_column.size_flags_vertical = SIZE_EXPAND_FILL
	_left_column.add_theme_constant_override("separation", 12)
	_root_split.add_child(_left_column)

	_left_column.add_child(_build_filter_bar())

	_browser_summary_label = Label.new()
	_browser_summary_label.add_theme_font_size_override("font_size", 16)
	_browser_summary_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_left_column.add_child(_browser_summary_label)

	_browser_scroll = ScrollContainer.new()
	_browser_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_browser_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_browser_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_browser_scroll.resized.connect(_on_browser_scroll_resized)
	_left_column.add_child(_browser_scroll)
	_card_grid = GridContainer.new()
	_card_grid.columns = GRID_COLUMNS
	_card_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_card_grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	_card_grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	_browser_scroll.add_child(_card_grid)

	_left_column.add_child(_build_pagination_controls())

	# Right column — deck header, compact card list, magicka curve, actions
	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = SIZE_EXPAND_FILL
	_right_column.size_flags_vertical = SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", 12)
	_root_split.add_child(_right_column)

	_right_column.add_child(_build_deck_header())

	_deck_card_list = DeckCardListClass.new()
	_deck_card_list.set_show_remove_buttons(true)
	_deck_card_list.card_remove_pressed.connect(remove_card_from_deck)
	_deck_card_list.row_mouse_entered.connect(func(_row: Control, entry: Dictionary): _on_deck_row_mouse_entered(entry))
	_deck_card_list.row_mouse_exited.connect(func(_entry: Dictionary): _on_deck_row_mouse_exited())
	_deck_card_list_scroll = _deck_card_list.create_scroll_container()
	_right_column.add_child(_deck_card_list_scroll)

	# Magicka curve chart
	_magicka_curve_chart = MagickaCurveChartClass.new()
	_magicka_curve_chart.size_flags_horizontal = SIZE_EXPAND_FILL
	_right_column.add_child(_magicka_curve_chart)

	# Card count label
	_card_count_label = Label.new()
	_card_count_label.add_theme_font_size_override("font_size", 18)
	_card_count_label.add_theme_color_override("font_color", UITheme.TEXT_SECTION)
	_card_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_column.add_child(_card_count_label)
	_refresh_card_count()

	# Done / Cancel buttons
	_right_column.add_child(_build_action_buttons())

	# Card hover preview layer (overlay on top of everything)
	_card_hover_preview_layer = Control.new()
	_card_hover_preview_layer.name = "CardHoverPreviewLayer"
	_card_hover_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_hover_preview_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_card_hover_preview_layer)

	_on_root_split_resized.call_deferred()


func _build_pagination_controls() -> Control:
	_pagination_container = HBoxContainer.new()
	_pagination_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_pagination_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_pagination_container.add_theme_constant_override("separation", 12)

	_prev_page_button = Button.new()
	_prev_page_button.text = "Previous"
	_prev_page_button.custom_minimum_size = Vector2(120, 44)
	UITheme.style_button(_prev_page_button, 18)
	_prev_page_button.pressed.connect(_on_prev_page_pressed)
	_pagination_container.add_child(_prev_page_button)

	_page_label = Label.new()
	_page_label.text = "Page 1 of 1"
	_page_label.add_theme_font_size_override("font_size", 18)
	_page_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_pagination_container.add_child(_page_label)

	_next_page_button = Button.new()
	_next_page_button.text = "Next"
	_next_page_button.custom_minimum_size = Vector2(120, 44)
	UITheme.style_button(_next_page_button, 18)
	_next_page_button.pressed.connect(_on_next_page_pressed)
	_pagination_container.add_child(_next_page_button)

	return _pagination_container


func _build_deck_header() -> Control:
	var header_button := Button.new()
	header_button.size_flags_horizontal = SIZE_EXPAND_FILL
	header_button.custom_minimum_size = Vector2(0, 56)
	header_button.flat = true
	header_button.pressed.connect(_on_deck_header_pressed)
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 6)
	header_box.mouse_filter = MOUSE_FILTER_IGNORE
	header_button.add_child(header_box)

	_deck_header_name_label = Label.new()
	_deck_header_name_label.text = _deck_name if not _deck_name.is_empty() else "Untitled Deck"
	_deck_header_name_label.mouse_filter = MOUSE_FILTER_IGNORE
	UITheme.style_title(_deck_header_name_label, 24)
	_deck_header_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_box.add_child(_deck_header_name_label)

	_deck_header_attr_container = HBoxContainer.new()
	_deck_header_attr_container.add_theme_constant_override("separation", 8)
	_deck_header_attr_container.mouse_filter = MOUSE_FILTER_IGNORE
	header_box.add_child(_deck_header_attr_container)
	_refresh_deck_header_attributes()

	return header_button


func _refresh_deck_header_attributes() -> void:
	if _deck_header_attr_container == null:
		return
	_clear_children(_deck_header_attr_container)
	for attr_id in _deck_attribute_ids:
		var attr_label := Label.new()
		attr_label.text = _attribute_display_name(attr_id)
		attr_label.add_theme_font_size_override("font_size", 15)
		var tint: Color = ATTRIBUTE_TINTS.get(attr_id, NEUTRAL_COST_COLOR)
		attr_label.add_theme_color_override("font_color", tint)
		_deck_header_attr_container.add_child(attr_label)
	if _deck_attribute_ids.is_empty():
		var none_label := Label.new()
		none_label.text = "No attributes"
		none_label.add_theme_font_size_override("font_size", 15)
		none_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		_deck_header_attr_container.add_child(none_label)


func _refresh_deck_card_list() -> void:
	if _deck_card_list == null:
		return
	# Convert _deck_quantities dict to the array format DeckCardList expects
	var deck_array: Array = []
	for card_id in _deck_quantities:
		deck_array.append({"card_id": str(card_id), "quantity": int(_deck_quantities.get(card_id, 0))})
	if _card_hover_preview_layer != null and not _card_by_id.is_empty():
		_deck_card_list.enable_hover_preview(_card_hover_preview_layer, _card_by_id)
		_deck_card_list.set_relationship_context_callback(_build_relationship_context)
	_deck_card_list.set_deck(deck_array, _card_by_id)


func _build_action_buttons() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button(cancel_btn, 18, true)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	row.add_child(cancel_btn)

	var validate_btn := Button.new()
	validate_btn.text = "Validate"
	validate_btn.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button_accent(validate_btn, UITheme.GOLD, 18)
	validate_btn.pressed.connect(_on_validate_pressed)
	row.add_child(validate_btn)

	var export_btn := Button.new()
	export_btn.text = "Export Code"
	export_btn.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button_accent(export_btn, Color(0.42, 0.62, 0.96, 1.0), 18)
	export_btn.pressed.connect(_on_export_pressed.bind(export_btn))
	row.add_child(export_btn)

	var done_btn := Button.new()
	done_btn.text = "Done"
	done_btn.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button_accent(done_btn, Color(0.4, 0.76, 0.52, 1.0), 18)
	done_btn.pressed.connect(_on_done_pressed)
	row.add_child(done_btn)

	return row


func _build_filter_bar() -> Control:
	var panel := PanelContainer.new()
	UITheme.style_panel(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	# Row 1: Search | Attributes | Cost — all inline
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	box.add_child(top_row)

	# Search group
	var search_group := HBoxContainer.new()
	search_group.add_theme_constant_override("separation", 8)
	top_row.add_child(search_group)
	var search_label := Label.new()
	search_label.text = "Search"
	search_label.size_flags_vertical = SIZE_SHRINK_CENTER
	UITheme.style_section_label(search_label, 22)
	search_group.add_child(search_label)
	_search_input = LineEdit.new()
	_search_input.custom_minimum_size = Vector2(220, 44)
	_search_input.add_theme_font_size_override("font_size", 22)
	_search_input.placeholder_text = "Name, text, or id"
	_search_input.text_changed.connect(_on_search_changed)
	_search_input.gui_input.connect(_on_search_input_gui_input)
	search_group.add_child(_search_input)

	# Attribute chips group
	var attr_group := HBoxContainer.new()
	attr_group.add_theme_constant_override("separation", 8)
	top_row.add_child(attr_group)
	var attr_label := Label.new()
	attr_label.text = "Attr"
	attr_label.size_flags_vertical = SIZE_SHRINK_CENTER
	UITheme.style_section_label(attr_label, 22)
	attr_group.add_child(attr_label)
	_attribute_chip_container = HBoxContainer.new()
	_attribute_chip_container.add_theme_constant_override("separation", 4)
	_attribute_chip_container.size_flags_vertical = SIZE_SHRINK_CENTER
	attr_group.add_child(_attribute_chip_container)

	# Cost chips group
	var cost_group := HBoxContainer.new()
	cost_group.add_theme_constant_override("separation", 8)
	top_row.add_child(cost_group)
	var cost_label := Label.new()
	cost_label.text = "Cost"
	cost_label.size_flags_vertical = SIZE_SHRINK_CENTER
	UITheme.style_section_label(cost_label, 22)
	cost_group.add_child(cost_label)
	_cost_chip_container = HBoxContainer.new()
	_cost_chip_container.add_theme_constant_override("separation", 4)
	_cost_chip_container.size_flags_vertical = SIZE_SHRINK_CENTER
	cost_group.add_child(_cost_chip_container)
	for cost in [0, 1, 2, 3, 4, 5, 6]:
		var chip := Button.new()
		chip.toggle_mode = true
		chip.text = str(cost)
		chip.custom_minimum_size = Vector2(44, 42)
		chip.add_theme_font_size_override("font_size", 22)
		chip.toggled.connect(_on_cost_chip_toggled.bind(cost))
		_cost_chip_container.add_child(chip)
	var seven_plus := Button.new()
	seven_plus.toggle_mode = true
	seven_plus.text = "7+"
	seven_plus.custom_minimum_size = Vector2(50, 42)
	seven_plus.add_theme_font_size_override("font_size", 22)
	seven_plus.toggled.connect(_on_cost_chip_toggled.bind(7))
	_cost_chip_container.add_child(seven_plus)

	box.add_child(UITheme.make_separator(0.0))

	# Row 2: Class | Type | Keyword dropdowns
	var dropdown_row := HBoxContainer.new()
	dropdown_row.add_theme_constant_override("separation", 16)
	box.add_child(dropdown_row)
	_class_filter_button = _build_dropdown(dropdown_row, "Class", _class_filter_items())
	_type_filter_button = _build_dropdown(dropdown_row, "Type", _type_filter_items())
	_keyword_filter_button = _build_dropdown(dropdown_row, "Keyword", _keyword_filter_items())
	_class_filter_button.item_selected.connect(_on_class_filter_selected)
	_type_filter_button.item_selected.connect(_on_type_filter_selected)
	_keyword_filter_button.item_selected.connect(_on_keyword_filter_selected)

	return panel


func _build_dropdown(parent: HBoxContainer, label_text: String, items: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	UITheme.style_section_label(label, 22)
	parent.add_child(label)
	var button := OptionButton.new()
	button.custom_minimum_size = Vector2(160, 44)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", UITheme.GOLD)
	button.add_theme_color_override("font_pressed_color", UITheme.GOLD_BRIGHT)
	button.add_theme_color_override("font_focus_color", UITheme.TEXT_LIGHT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = UITheme.BTN_BG
	normal.border_color = UITheme.GOLD_DIM
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = UITheme.BTN_BG_HOVER
	hover.border_color = UITheme.GOLD
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(10)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = UITheme.BTN_BG_PRESSED
	pressed.border_color = UITheme.GOLD_BRIGHT
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(10)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover.duplicate())
	for item in items:
		button.add_item(str(item.get("label", "")))
		button.set_item_metadata(button.item_count - 1, item.get("value", ""))
	# Style the dropdown popup menu
	var popup := button.get_popup()
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	popup.add_theme_color_override("font_hover_color", UITheme.GOLD)
	popup.add_theme_color_override("font_separator_color", UITheme.GOLD_DIM)
	var popup_panel := StyleBoxFlat.new()
	popup_panel.bg_color = UITheme.PANEL_BG
	popup_panel.border_color = UITheme.PANEL_BORDER
	popup_panel.set_border_width_all(2)
	popup_panel.set_corner_radius_all(4)
	popup_panel.set_content_margin_all(6)
	popup.add_theme_stylebox_override("panel", popup_panel)
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = UITheme.BTN_BG_HOVER
	popup_hover.set_corner_radius_all(2)
	popup_hover.set_content_margin_all(6)
	popup.add_theme_stylebox_override("hover", popup_hover)
	parent.add_child(button)
	return button


# --- Filter Item Lists ---

func _class_filter_items() -> Array:
	var items: Array = [
		{"label": "Any", "value": ""},
		{"label": "No class restriction", "value": "none"},
	]
	for class_record in _class_records:
		items.append({"label": str(class_record.get("display_name", "")), "value": str(class_record.get("id", ""))})
	return items


func _type_filter_items() -> Array:
	return [
		{"label": "Any", "value": ""},
		{"label": "Creature", "value": "creature"},
		{"label": "Action", "value": "action"},
		{"label": "Item", "value": "item"},
		{"label": "Support", "value": "support"},
	]


func _keyword_filter_items() -> Array:
	var items: Array = [{"label": "Any", "value": ""}]
	for keyword in _keyword_registry.get("keywords", []):
		if typeof(keyword) != TYPE_DICTIONARY:
			continue
		items.append({"label": str(keyword.get("display_name", keyword.get("id", ""))), "value": str(keyword.get("id", ""))})
	items.append({"label": "Prophecy", "value": "prophecy"})
	return items


# --- Filter Logic ---

func _filtered_cards() -> Array:
	var filtered: Array = []
	var search_term := _search_query.to_lower()
	for raw_card in _catalog_cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = raw_card
		if not card.get("collectible", true):
			continue
		if not search_term.is_empty() and not _card_matches_search(card, search_term):
			continue
		if not _card_matches_deck_attributes(card):
			continue
		if not _active_attribute_filters.is_empty() and not _card_matches_attribute_chips(card):
			continue
		if not _browser_class_filter.is_empty() and not _card_matches_class_filter(card, _browser_class_filter):
			continue
		if not _browser_type_filter.is_empty() and str(card.get("card_type", "")) != _browser_type_filter:
			continue
		if not _active_cost_filters.is_empty() and not _card_matches_cost_chips(card):
			continue
		if not _browser_keyword_filter.is_empty() and not _card_matches_keyword_filter(card, _browser_keyword_filter):
			continue
		filtered.append(card)
	return filtered


func _card_matches_search(card: Dictionary, search_term: String) -> bool:
	var haystack := [
		str(card.get("card_id", "")).to_lower(),
		str(card.get("name", "")).to_lower(),
		str(card.get("rules_text", "")).to_lower(),
	]
	for value in haystack:
		if search_term in value:
			return true
	return false


func _card_matches_attribute_chips(card: Dictionary) -> bool:
	var attributes: Array = card.get("attributes", [])
	for filter_attr in _active_attribute_filters:
		if filter_attr == "neutral":
			if attributes.is_empty():
				return true
		else:
			if attributes.has(filter_attr):
				return true
	return false


func _card_matches_class_filter(card: Dictionary, class_id: String) -> bool:
	var card_class: Variant = card.get("class_id", null)
	var card_class_str := "" if card_class == null else str(card_class)
	if class_id == "none":
		return card_class_str.is_empty()
	return card_class_str == class_id


func _card_matches_cost_chips(card: Dictionary) -> bool:
	var card_cost := int(card.get("cost", 0))
	for filter_cost in _active_cost_filters:
		if filter_cost == 7:
			if card_cost >= 7:
				return true
		else:
			if card_cost == filter_cost:
				return true
	return false


func _card_matches_keyword_filter(card: Dictionary, term_id: String) -> bool:
	return card.get("keywords", []).has(term_id) or card.get("rules_tags", []).has(term_id)


# --- Refresh ---

func _refresh_browser() -> void:
	if _card_grid == null:
		return
	_filtered_cache = _filtered_cards()
	_current_page = 0
	_total_pages = maxi(1, ceili(float(_filtered_cache.size()) / float(CARDS_PER_PAGE)))
	_render_current_page()


func _render_current_page() -> void:
	_clear_children(_card_grid)
	_card_display_by_id.clear()
	var start := _current_page * CARDS_PER_PAGE
	var end := mini(start + CARDS_PER_PAGE, _filtered_cache.size())
	_browser_summary_label.text = "%d cards shown | %d in deck" % [_filtered_cache.size(), get_deck_count()]
	var cell_size := _compute_cell_size()
	for i in range(start, end):
		_card_grid.add_child(_build_card_cell(_filtered_cache[i], cell_size))
	if _card_grid.get_child_count() == 0:
		var placeholder := Label.new()
		placeholder.text = "No cards match the current filters."
		_card_grid.add_child(placeholder)
	_update_pagination_controls()


func _build_card_cell(card: Dictionary, cell_size: Vector2) -> Control:
	var card_id := str(card.get("card_id", ""))
	var wrapper := Control.new()
	wrapper.custom_minimum_size = cell_size
	wrapper.size_flags_horizontal = SIZE_EXPAND_FILL
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.gui_input.connect(_on_card_cell_input.bind(card_id))
	wrapper.mouse_entered.connect(_on_card_cell_mouse_entered.bind(card_id))
	wrapper.mouse_exited.connect(_on_card_cell_mouse_exited.bind(card_id))
	var card_display := CardDisplayComponentClass.new()
	card_display.apply_card(card, CardDisplayComponentClass.PRESENTATION_FULL)
	card_display.set_relationship_context(_build_relationship_context())
	card_display.custom_minimum_size = cell_size
	card_display.size = cell_size
	card_display.set_interactive(false)
	card_display.set_deck_quantity(get_deck_card_quantity(card_id), _copy_limit(card))
	wrapper.add_child(card_display)
	card_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_display_by_id[card_id] = card_display
	return wrapper


func _refresh_card_quantities() -> void:
	if _browser_summary_label != null:
		_browser_summary_label.text = "%d cards shown | %d in deck" % [_filtered_cache.size(), get_deck_count()]
	var context := _build_relationship_context()
	for card_id in _card_display_by_id:
		var card_display: Control = _card_display_by_id[card_id]
		if not is_instance_valid(card_display):
			continue
		var card: Dictionary = _card_by_id.get(card_id, {})
		if card.is_empty():
			continue
		card_display.set_deck_quantity(get_deck_card_quantity(card_id), _copy_limit(card))
		if card_display.has_method("set_relationship_context"):
			card_display.set_relationship_context(context)
	_refresh_deck_card_list()
	_refresh_magicka_curve()
	_refresh_card_count()


func _refresh_magicka_curve() -> void:
	if _magicka_curve_chart == null:
		return
	_magicka_curve_chart.set_deck(get_deck_definition(), _card_by_id)


func _refresh_card_count() -> void:
	if _card_count_label == null:
		return
	var count := get_deck_count()
	var size_rule: Dictionary = _rules_registry.get_deck_size_rule(_deck_attribute_ids.size())
	var min_cards := int(size_rule.get("min_cards", 50))
	var max_cards := int(size_rule.get("max_cards", 100))
	_card_count_label.text = "%d / %d-%d" % [count, min_cards, max_cards]
	if count < min_cards or count > max_cards:
		_card_count_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	else:
		_card_count_label.add_theme_color_override("font_color", UITheme.TEXT_SECTION)


func _compute_cell_size() -> Vector2:
	var scroll_width := 600.0
	if _browser_scroll != null and _browser_scroll.size.x > 0:
		scroll_width = _browser_scroll.size.x
	var cell_w := maxf(100.0, (scroll_width - float(GRID_H_SEPARATION * (GRID_COLUMNS - 1))) / float(GRID_COLUMNS))
	var cell_h := cell_w * CARD_ASPECT_RATIO
	return Vector2(cell_w, cell_h)


func _card_matches_deck_attributes(card: Dictionary) -> bool:
	if _deck_attribute_ids.is_empty():
		return true
	var attributes: Array = card.get("attributes", [])
	if attributes.is_empty():
		return true
	for attr in attributes:
		if not _deck_attribute_ids.has(str(attr)):
			return false
	return true


# --- Helpers ---

func _attribute_display_name(attribute_id: String) -> String:
	return str(_attribute_display_names.get(attribute_id, attribute_id.capitalize()))


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _refresh_attribute_chips() -> void:
	if _attribute_chip_container == null:
		return
	_active_attribute_filters.clear()
	_clear_children(_attribute_chip_container)
	# Only show "Neutral" plus the deck's selected attributes
	var chip_ids: Array[String] = []
	for attr_id in _deck_attribute_ids:
		chip_ids.append(attr_id)
	# Always include Neutral since neutral cards belong to any deck
	chip_ids.append("neutral")
	for attr_id in chip_ids:
		var chip := Button.new()
		chip.toggle_mode = true
		chip.text = _attribute_display_name(attr_id)
		chip.custom_minimum_size = Vector2(0, 42)
		chip.add_theme_font_size_override("font_size", 22)
		chip.toggled.connect(_on_attribute_chip_toggled.bind(attr_id))
		_attribute_chip_container.add_child(chip)


func _refresh_deck_header() -> void:
	if _deck_header_name_label != null:
		_deck_header_name_label.text = _deck_name if not _deck_name.is_empty() else "Untitled Deck"
	_refresh_deck_header_attributes()


func _find_illegal_cards(new_attribute_ids: Array) -> Array:
	var illegal: Array = []
	for card_id in _deck_quantities:
		var card: Dictionary = _card_by_id.get(card_id, {})
		if card.is_empty():
			continue
		var attributes: Array = card.get("attributes", [])
		if attributes.is_empty():
			continue
		for attr in attributes:
			if not new_attribute_ids.has(str(attr)):
				illegal.append(card_id)
				break
	return illegal


# --- Signal Handlers ---

func _on_search_changed(value: String) -> void:
	_search_query = value.strip_edges()
	_refresh_browser()


func _on_attribute_chip_toggled(pressed: bool, attribute_id: String) -> void:
	if pressed:
		if not _active_attribute_filters.has(attribute_id):
			_active_attribute_filters.append(attribute_id)
	else:
		_active_attribute_filters.erase(attribute_id)
	_refresh_browser()


func _on_cost_chip_toggled(pressed: bool, cost: int) -> void:
	if pressed:
		if not _active_cost_filters.has(cost):
			_active_cost_filters.append(cost)
	else:
		_active_cost_filters.erase(cost)
	_refresh_browser()


func _on_class_filter_selected(index: int) -> void:
	_browser_class_filter = str(_class_filter_button.get_item_metadata(index))
	_refresh_browser()


func _on_type_filter_selected(index: int) -> void:
	_browser_type_filter = str(_type_filter_button.get_item_metadata(index))
	_refresh_browser()


func _on_keyword_filter_selected(index: int) -> void:
	_browser_keyword_filter = str(_keyword_filter_button.get_item_metadata(index))
	_refresh_browser()


func _build_relationship_context() -> Dictionary:
	var deck_cards: Array = []
	for card_id in _deck_quantities:
		var card: Dictionary = _card_by_id.get(card_id, {})
		if card.is_empty():
			continue
		var qty: int = _deck_quantities[card_id]
		for i in range(qty):
			deck_cards.append(card)
	return {"zone": "deck_editor", "deck_cards": deck_cards}


func _on_card_cell_mouse_entered(card_id: String) -> void:
	_hovered_card_id = card_id
	var card: Dictionary = _card_by_id.get(card_id, {})
	_error_report_hovered_type = "card"
	_error_report_hovered_context = "%s (in browser)" % str(card.get("name", card_id))


func _on_card_cell_mouse_exited(card_id: String) -> void:
	if _hovered_card_id == card_id:
		_hovered_card_id = ""
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""
	var card_display = _card_display_by_id.get(card_id, null)
	if card_display != null and is_instance_valid(card_display) and card_display.has_method("reset_relationship_view"):
		card_display.reset_relationship_view()


func _on_card_cell_input(event: InputEvent, card_id: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			add_card_to_deck(card_id)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			add_max_cards_to_deck(card_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			remove_card_from_deck(card_id)


func _on_browser_scroll_resized() -> void:
	if _card_grid == null or _card_grid.get_child_count() == 0:
		return
	var cell_size := _compute_cell_size()
	for child in _card_grid.get_children():
		if child is Control:
			child.custom_minimum_size = cell_size


func _on_root_split_resized() -> void:
	if _root_split == null or _root_split.size.x <= 0:
		return
	var target := int(_root_split.size.x * 0.3)
	if _root_split.split_offset == target:
		return
	_root_split.resized.disconnect(_on_root_split_resized)
	_root_split.split_offset = target
	_root_split.resized.connect(_on_root_split_resized)


func _on_prev_page_pressed() -> void:
	if _current_page > 0:
		_current_page -= 1
		_render_current_page()
		_browser_scroll.scroll_vertical = 0


func _on_next_page_pressed() -> void:
	if _current_page < _total_pages - 1:
		_current_page += 1
		_render_current_page()
		_browser_scroll.scroll_vertical = 0


func _update_pagination_controls() -> void:
	if _page_label != null:
		_page_label.text = "Page %d of %d" % [_current_page + 1, _total_pages]
	if _prev_page_button != null:
		_prev_page_button.disabled = _current_page <= 0
	if _next_page_button != null:
		_next_page_button.disabled = _current_page >= _total_pages - 1


func _on_deck_header_pressed() -> void:
	var modal := DeckCreationModalClass.new()
	add_child(modal)
	modal.set_edit_mode(_deck_name, _deck_attribute_ids.duplicate())
	modal.confirmed.connect(_on_edit_modal_confirmed.bind(modal))
	modal.cancelled.connect(_on_edit_modal_cancelled.bind(modal))


func _on_edit_modal_confirmed(new_name: String, new_attribute_ids: Array, modal: Control) -> void:
	modal.queue_free()
	var illegal := _find_illegal_cards(new_attribute_ids)
	if illegal.is_empty():
		_apply_deck_edit(new_name, new_attribute_ids)
	else:
		_show_illegal_cards_confirmation(new_name, new_attribute_ids, illegal)


func _on_edit_modal_cancelled(modal: Control) -> void:
	modal.queue_free()


func _apply_deck_edit(new_name: String, new_attribute_ids: Array) -> void:
	_deck_name = new_name
	_deck_attribute_ids.clear()
	for attr_id in new_attribute_ids:
		_deck_attribute_ids.append(str(attr_id))
	_refresh_deck_header()
	_refresh_attribute_chips()
	_refresh_browser()
	_refresh_deck_card_list()
	_refresh_magicka_curve()
	_refresh_card_count()


func _show_illegal_cards_confirmation(new_name: String, new_attribute_ids: Array, illegal_card_ids: Array) -> void:
	# Build card names for display
	var card_names: Array = []
	for card_id in illegal_card_ids:
		var card: Dictionary = _card_by_id.get(card_id, {})
		card_names.append(str(card.get("name", card_id)))

	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Remove Illegal Cards?"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "Changing attributes will remove %d card(s) that are no longer legal:\n%s" % [illegal_card_ids.size(), ", ".join(card_names)]
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Remove & Apply"
	confirm_btn.custom_minimum_size = Vector2(120, 36)
	btn_row.add_child(confirm_btn)

	cancel_btn.pressed.connect(func():
		backdrop.queue_free()
		center.queue_free()
	)
	confirm_btn.pressed.connect(func():
		backdrop.queue_free()
		center.queue_free()
		for card_id in illegal_card_ids:
			_deck_quantities.erase(card_id)
		_apply_deck_edit(new_name, new_attribute_ids)
	)


func _on_export_pressed(btn: Button) -> void:
	var result: Dictionary = DeckCodeClass.encode(get_deck_definition(), _card_id_to_deck_code)
	if result.get("error", "") != "":
		btn.text = "Error!"
	else:
		DisplayServer.clipboard_set(result.get("code", ""))
		btn.text = "Copied!"
	btn.disabled = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		btn.text = "Export Code"
		btn.disabled = false
	)


func _on_done_pressed() -> void:
	DeckPersistenceClass.save_deck(_deck_name, get_deck_definition())
	done_pressed.emit()


func _on_cancel_pressed() -> void:
	cancel_pressed.emit()


func _on_search_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			_search_input.release_focus()


func _disable_button_focus(node: Node) -> void:
	if node is LineEdit:
		return
	if node is BaseButton or node is OptionButton:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_button_focus(child)


# --- Error Report Hover Handlers ---

func _on_deck_row_mouse_entered(entry: Dictionary) -> void:
	_error_report_hovered_type = "card"
	_error_report_hovered_context = "%s (in deck list)" % str(entry.get("name", entry.get("card_id", "")))


func _on_deck_row_mouse_exited() -> void:
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


# --- Error Report Popover ---

func _open_error_report_popover() -> void:
	if _error_report_popover != null:
		return
	var context_label := _error_report_hovered_context if not _error_report_hovered_type.is_empty() else "Deck Editor (general)"
	var element_type := _error_report_hovered_type if not _error_report_hovered_type.is_empty() else "general"
	var element_context := _error_report_hovered_context if not _error_report_hovered_type.is_empty() else "deck_editor"

	_error_report_popover = ErrorReportPopoverClass.new()
	_error_report_popover.report_submitted.connect(_on_error_report_submitted.bind(element_type, element_context))
	_error_report_popover.dismissed.connect(_on_error_report_dismissed)
	add_child(_error_report_popover)
	_error_report_popover.show_report(context_label)


func _on_error_report_submitted(comment: String, element_type: String, element_context: String) -> void:
	var report := {
		"screen": "deck_editor",
		"element_type": element_type,
		"element_context": element_context,
		"comment": comment,
		"snapshot": ErrorReportWriterClass.build_deck_editor_snapshot(_deck_name, _deck_attribute_ids, _deck_quantities, _card_by_id),
	}
	ErrorReportWriterClass.write_report(report)
	_error_report_popover = null


func _on_error_report_dismissed() -> void:
	_error_report_popover = null


func _on_validate_pressed() -> void:
	var definition := get_deck_definition()
	var validation := DeckValidator.validate_deck(definition, _card_by_id, _rules_registry)
	var errors: Array = validation.get("errors", [])
	if errors.is_empty():
		_show_validation_overlay("Deck Valid", ["No issues found."], Color(0.3, 0.6, 0.3, 1.0))
	else:
		_show_validation_overlay("Validation Errors", errors, Color(0.7, 0.3, 0.3, 1.0))


static func show_validation_errors_overlay(parent: Control, title_text: String, messages: Array, accent_color: Color) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.border_color = accent_color
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var UIThemeRef = preload("res://src/ui/ui_theme.gd")

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", accent_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 80)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	var msg_list := VBoxContainer.new()
	msg_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_list.add_theme_constant_override("separation", 8)
	scroll.add_child(msg_list)

	for msg_text in messages:
		var msg_label := Label.new()
		msg_label.text = str(msg_text)
		msg_label.add_theme_font_size_override("font_size", 22)
		msg_label.add_theme_color_override("font_color", UIThemeRef.TEXT_LIGHT)
		msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg_list.add_child(msg_label)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(140, 48)
	UIThemeRef.style_button(ok_btn, 22)
	ok_btn.pressed.connect(overlay.queue_free)
	vbox.add_child(ok_btn)

	parent.add_child(overlay)


func _show_validation_overlay(title_text: String, messages: Array, accent_color: Color) -> void:
	show_validation_errors_overlay(self, title_text, messages, accent_color)
