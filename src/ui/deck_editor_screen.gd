class_name DeckEditorScreen
extends Control

const DeckValidator = preload("res://src/deck/deck_validator.gd")
const DeckRulesRegistryClass = preload("res://src/deck/deck_rules_registry.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const DECK_REGISTRY_PATH := "res://data/legends/registries/attribute_class_registry.json"
const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")
const DeckCreationModalClass = preload("res://src/ui/deck_creation_modal.gd")
const CARD_ASPECT_RATIO := 384.0 / 220.0
const ATTRIBUTE_TINTS := {
	"strength": Color(0.84, 0.39, 0.31, 1.0),
	"intelligence": Color(0.42, 0.62, 0.96, 1.0),
	"willpower": Color(0.92, 0.78, 0.38, 1.0),
	"agility": Color(0.4, 0.76, 0.52, 1.0),
	"endurance": Color(0.58, 0.46, 0.72, 1.0),
}
const NEUTRAL_COST_COLOR := Color(0.6, 0.6, 0.6, 1.0)
const GRID_COLUMNS := 3
const GRID_H_SEPARATION := 8
const GRID_V_SEPARATION := 8

signal done_pressed
signal cancel_pressed

var _rules_registry
var _keyword_registry := {}
var _catalog_cards: Array = []
var _card_by_id := {}
var _attribute_display_names := {}
var _class_display_names := {}
var _class_records: Array = []

# Deck state
var _deck_name := ""
var _deck_attribute_ids: Array[String] = []
var _deck_quantities := {}

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
var _deck_card_list_container: VBoxContainer
var _deck_card_list_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_data()
	_build_ui()
	_refresh_browser()


func load_deck(deck_name: String, definition: Dictionary) -> void:
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
	_refresh_deck_card_list()
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
	var root := HSplitContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)

	_left_column = VBoxContainer.new()
	_left_column.size_flags_horizontal = SIZE_EXPAND_FILL
	_left_column.size_flags_vertical = SIZE_EXPAND_FILL
	_left_column.add_theme_constant_override("separation", 8)
	root.add_child(_left_column)

	_left_column.add_child(_build_filter_bar())

	_browser_summary_label = Label.new()
	_left_column.add_child(_browser_summary_label)

	_browser_scroll = ScrollContainer.new()
	_browser_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_browser_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_browser_scroll.resized.connect(_on_browser_scroll_resized)
	_left_column.add_child(_browser_scroll)
	_card_grid = GridContainer.new()
	_card_grid.columns = GRID_COLUMNS
	_card_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_card_grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	_card_grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	_browser_scroll.add_child(_card_grid)

	# Right column — deck header, compact card list, and later US-011/US-012 additions
	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = SIZE_EXPAND_FILL
	_right_column.size_flags_vertical = SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", 8)
	root.add_child(_right_column)

	_right_column.add_child(_build_deck_header())

	_deck_card_list_scroll = ScrollContainer.new()
	_deck_card_list_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_deck_card_list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_right_column.add_child(_deck_card_list_scroll)
	_deck_card_list_container = VBoxContainer.new()
	_deck_card_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_deck_card_list_container.add_theme_constant_override("separation", 2)
	_deck_card_list_scroll.add_child(_deck_card_list_container)


func _build_deck_header() -> Control:
	var header_button := Button.new()
	header_button.size_flags_horizontal = SIZE_EXPAND_FILL
	header_button.flat = true
	header_button.pressed.connect(_on_deck_header_pressed)
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 4)
	header_box.mouse_filter = MOUSE_FILTER_IGNORE
	header_button.add_child(header_box)

	_deck_header_name_label = Label.new()
	_deck_header_name_label.add_theme_font_size_override("font_size", 20)
	_deck_header_name_label.text = _deck_name if not _deck_name.is_empty() else "Untitled Deck"
	_deck_header_name_label.mouse_filter = MOUSE_FILTER_IGNORE
	header_box.add_child(_deck_header_name_label)

	_deck_header_attr_container = HBoxContainer.new()
	_deck_header_attr_container.add_theme_constant_override("separation", 6)
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
		attr_label.add_theme_font_size_override("font_size", 14)
		var tint: Color = ATTRIBUTE_TINTS.get(attr_id, NEUTRAL_COST_COLOR)
		attr_label.add_theme_color_override("font_color", tint)
		_deck_header_attr_container.add_child(attr_label)
	if _deck_attribute_ids.is_empty():
		var none_label := Label.new()
		none_label.text = "No attributes"
		none_label.add_theme_font_size_override("font_size", 14)
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_deck_header_attr_container.add_child(none_label)


func _refresh_deck_card_list() -> void:
	if _deck_card_list_container == null:
		return
	_clear_children(_deck_card_list_container)

	# Collect deck cards with their data, sorted by cost then name
	var deck_entries: Array = []
	for card_id in _deck_quantities:
		var card: Dictionary = _card_by_id.get(card_id, {})
		if card.is_empty():
			continue
		deck_entries.append({
			"card_id": str(card_id),
			"name": str(card.get("name", card_id)),
			"cost": int(card.get("cost", 0)),
			"quantity": int(_deck_quantities.get(card_id, 0)),
			"attributes": card.get("attributes", []),
		})
	deck_entries.sort_custom(func(a, b):
		if a["cost"] != b["cost"]:
			return a["cost"] < b["cost"]
		return a["name"].to_lower() < b["name"].to_lower()
	)

	for entry in deck_entries:
		_deck_card_list_container.add_child(_build_deck_card_row(entry))

	if deck_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards in deck"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_deck_card_list_container.add_child(empty_label)


func _build_deck_card_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	# Cost badge — small colored circle with cost number
	var cost_badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.set_corner_radius_all(12)
	badge_style.set_content_margin_all(0)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	var cost_color := _get_card_cost_badge_color(entry.get("attributes", []))
	badge_style.bg_color = cost_color
	cost_badge.add_theme_stylebox_override("panel", badge_style)
	cost_badge.custom_minimum_size = Vector2(28, 24)
	var cost_label := Label.new()
	cost_label.text = str(entry["cost"])
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_label)
	row.add_child(cost_badge)

	# Card name
	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	# Quantity indicator
	var qty_label := Label.new()
	qty_label.text = "x%d" % entry["quantity"]
	qty_label.add_theme_font_size_override("font_size", 13)
	qty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	row.add_child(qty_label)

	# Minus button
	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(28, 24)
	minus_btn.pressed.connect(remove_card_from_deck.bind(str(entry["card_id"])))
	row.add_child(minus_btn)

	return row


func _get_card_cost_badge_color(attributes: Array) -> Color:
	if attributes.size() == 1:
		return ATTRIBUTE_TINTS.get(str(attributes[0]), NEUTRAL_COST_COLOR)
	return NEUTRAL_COST_COLOR


func _build_filter_bar() -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	# Search bar
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	box.add_child(search_row)
	var search_label := Label.new()
	search_label.text = "Search"
	search_row.add_child(search_label)
	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_input.placeholder_text = "Name, text, or id"
	_search_input.text_changed.connect(_on_search_changed)
	search_row.add_child(_search_input)

	# Attribute toggle chips
	var attr_label := Label.new()
	attr_label.text = "Attributes"
	box.add_child(attr_label)
	_attribute_chip_container = HBoxContainer.new()
	_attribute_chip_container.add_theme_constant_override("separation", 4)
	box.add_child(_attribute_chip_container)
	for attr_id in ["strength", "intelligence", "willpower", "agility", "endurance", "neutral"]:
		var chip := Button.new()
		chip.toggle_mode = true
		chip.text = _attribute_display_name(attr_id)
		chip.toggled.connect(_on_attribute_chip_toggled.bind(attr_id))
		_attribute_chip_container.add_child(chip)

	# Separator
	box.add_child(HSeparator.new())

	# Dropdown filters row
	var dropdown_row := HBoxContainer.new()
	dropdown_row.add_theme_constant_override("separation", 6)
	box.add_child(dropdown_row)
	_class_filter_button = _build_dropdown(dropdown_row, "Class", _class_filter_items())
	_type_filter_button = _build_dropdown(dropdown_row, "Type", _type_filter_items())
	_keyword_filter_button = _build_dropdown(dropdown_row, "Keyword", _keyword_filter_items())
	_class_filter_button.item_selected.connect(_on_class_filter_selected)
	_type_filter_button.item_selected.connect(_on_type_filter_selected)
	_keyword_filter_button.item_selected.connect(_on_keyword_filter_selected)

	# Separator
	box.add_child(HSeparator.new())

	# Cost toggle chips
	var cost_label := Label.new()
	cost_label.text = "Cost"
	box.add_child(cost_label)
	_cost_chip_container = HBoxContainer.new()
	_cost_chip_container.add_theme_constant_override("separation", 4)
	box.add_child(_cost_chip_container)
	for cost in [0, 1, 2, 3, 4, 5, 6]:
		var chip := Button.new()
		chip.toggle_mode = true
		chip.text = str(cost)
		chip.toggled.connect(_on_cost_chip_toggled.bind(cost))
		_cost_chip_container.add_child(chip)
	var seven_plus := Button.new()
	seven_plus.toggle_mode = true
	seven_plus.text = "7+"
	seven_plus.toggled.connect(_on_cost_chip_toggled.bind(7))
	_cost_chip_container.add_child(seven_plus)

	return panel


func _build_dropdown(parent: HBoxContainer, label_text: String, items: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var button := OptionButton.new()
	for item in items:
		button.add_item(str(item.get("label", "")))
		button.set_item_metadata(button.item_count - 1, item.get("value", ""))
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
	_clear_children(_card_grid)
	_card_display_by_id.clear()
	var filtered := _filtered_cards()
	_browser_summary_label.text = "%d cards shown | %d in deck" % [filtered.size(), get_deck_count()]
	var cell_size := _compute_cell_size()
	for card in filtered:
		_card_grid.add_child(_build_card_cell(card, cell_size))
	if _card_grid.get_child_count() == 0:
		var placeholder := Label.new()
		placeholder.text = "No cards match the current filters."
		_card_grid.add_child(placeholder)


func _build_card_cell(card: Dictionary, cell_size: Vector2) -> Control:
	var card_id := str(card.get("card_id", ""))
	var wrapper := Control.new()
	wrapper.custom_minimum_size = cell_size
	wrapper.size_flags_horizontal = SIZE_EXPAND_FILL
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.gui_input.connect(_on_card_cell_input.bind(card_id))
	var card_display := CardDisplayComponentClass.new()
	card_display.apply_card(card, CardDisplayComponentClass.PRESENTATION_FULL)
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
		_browser_summary_label.text = "%d cards shown | %d in deck" % [_card_display_by_id.size(), get_deck_count()]
	for card_id in _card_display_by_id:
		var card_display: Control = _card_display_by_id[card_id]
		if not is_instance_valid(card_display):
			continue
		var card: Dictionary = _card_by_id.get(card_id, {})
		if card.is_empty():
			continue
		card_display.set_deck_quantity(get_deck_card_quantity(card_id), _copy_limit(card))
	_refresh_deck_card_list()


func _compute_cell_size() -> Vector2:
	var scroll_width := 600.0
	if _browser_scroll != null and _browser_scroll.size.x > 0:
		scroll_width = _browser_scroll.size.x - 14.0
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


func _on_card_cell_input(event: InputEvent, card_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		add_card_to_deck(card_id)


func _on_browser_scroll_resized() -> void:
	if _card_grid == null or _card_grid.get_child_count() == 0:
		return
	var cell_size := _compute_cell_size()
	for child in _card_grid.get_children():
		if child is Control:
			child.custom_minimum_size = cell_size


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
	_refresh_browser()
	_refresh_deck_card_list()


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
