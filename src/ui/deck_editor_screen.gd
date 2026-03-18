class_name DeckEditorScreen
extends Control

const DeckValidator = preload("res://src/deck/deck_validator.gd")
const DeckRulesRegistryClass = preload("res://src/deck/deck_rules_registry.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const DECK_REGISTRY_PATH := "res://data/legends/registries/attribute_class_registry.json"

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
var _browser_rows: VBoxContainer
var _left_column: VBoxContainer


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
	_refresh_browser()


func remove_card_from_deck(card_id: String) -> void:
	if not _deck_quantities.has(card_id):
		return
	var next := int(_deck_quantities.get(card_id, 0)) - 1
	if next <= 0:
		_deck_quantities.erase(card_id)
	else:
		_deck_quantities[card_id] = next
	_refresh_browser()


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

	var browser_scroll := ScrollContainer.new()
	browser_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	browser_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_left_column.add_child(browser_scroll)
	_browser_rows = VBoxContainer.new()
	_browser_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_browser_rows.add_theme_constant_override("separation", 6)
	browser_scroll.add_child(_browser_rows)

	# Right column placeholder — populated by later stories (US-010, US-011, US-012)
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = SIZE_EXPAND_FILL
	right_column.size_flags_vertical = SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 8)
	root.add_child(right_column)

	var right_placeholder := Label.new()
	right_placeholder.text = "Deck panel (coming soon)"
	right_column.add_child(right_placeholder)


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
	if _browser_rows == null:
		return
	_clear_children(_browser_rows)
	var filtered := _filtered_cards()
	_browser_summary_label.text = "%d cards shown | %d in deck" % [filtered.size(), get_deck_count()]
	for card in filtered:
		_browser_rows.add_child(_build_browser_row(card))
	if _browser_rows.get_child_count() == 0:
		var placeholder := Label.new()
		placeholder.text = "No cards match the current filters."
		_browser_rows.add_child(placeholder)


func _build_browser_row(card: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var card_id := str(card.get("card_id", ""))
	var label_btn := Button.new()
	label_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	label_btn.text = "%s | %s | Cost %d | %d/%d" % [
		str(card.get("name", card_id)),
		str(card.get("card_type", "")).capitalize(),
		int(card.get("cost", 0)),
		get_deck_card_quantity(card_id),
		_copy_limit(card),
	]
	label_btn.pressed.connect(_on_card_clicked.bind(card_id))
	row.add_child(label_btn)
	return row


# --- Helpers ---

func _attribute_display_name(attribute_id: String) -> String:
	return str(_attribute_display_names.get(attribute_id, attribute_id.capitalize()))


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


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


func _on_card_clicked(card_id: String) -> void:
	add_card_to_deck(card_id)
