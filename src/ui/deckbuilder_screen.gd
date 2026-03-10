class_name DeckbuilderScreen
extends Control

const DeckValidator = preload("res://src/deck/deck_validator.gd")
const DeckRulesRegistryClass = preload("res://src/deck/deck_rules_registry.gd")
const DemoCardCatalog = preload("res://src/deck/demo_card_catalog.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const DECK_REGISTRY_PATH := "res://data/legends/registries/attribute_class_registry.json"

var _rules_registry
var _keyword_registry := {}
var _catalog_cards: Array = []
var _card_by_id := {}
var _attribute_display_names := {}
var _class_display_names := {}
var _class_records: Array = []
var _browser_attribute_filter := ""
var _browser_class_filter := ""
var _browser_type_filter := ""
var _browser_cost_filter := -1
var _browser_keyword_filter := ""
var _search_query := ""
var _deck_attribute_ids: Array[String] = []
var _deck_quantities := {}
var _selected_card_id := ""
var _status_message := ""
var _attribute_button_by_id := {}

var _status_label: Label
var _search_input: LineEdit
var _attribute_filter_button: OptionButton
var _class_filter_button: OptionButton
var _type_filter_button: OptionButton
var _cost_filter_button: OptionButton
var _keyword_filter_button: OptionButton
var _browser_summary_label: Label
var _browser_rows: VBoxContainer
var _deck_banner_label: Label
var _deck_summary_label: Label
var _curve_label: Label
var _legality_label: Label
var _deck_rows: VBoxContainer
var _selected_card_label: Label
var _import_export_text: TextEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_data()
	_build_ui()
	_refresh_ui()


func get_status_message() -> String:
	return _status_message


func get_filtered_card_ids() -> Array:
	var ids: Array = []
	for card in _filtered_cards():
		ids.append(str(card.get("card_id", "")))
	return ids


func get_card_record(card_id: String) -> Dictionary:
	var card: Variant = _card_by_id.get(card_id, {})
	return card.duplicate(true) if typeof(card) == TYPE_DICTIONARY else {}


func get_deck_definition() -> Dictionary:
	return _current_deck_definition().duplicate(true)


func get_deck_count() -> int:
	var total := 0
	for quantity in _deck_quantities.values():
		total += int(quantity)
	return total


func get_banner_text() -> String:
	return _deck_banner_label.text if _deck_banner_label != null else ""


func get_curve_summary_text() -> String:
	return _curve_label.text if _curve_label != null else ""


func get_legality_text() -> String:
	return _legality_label.text if _legality_label != null else ""


func get_selected_card_text() -> String:
	return _selected_card_label.text if _selected_card_label != null else ""


func get_export_text() -> String:
	return _import_export_text.text if _import_export_text != null else ""


func get_deck_card_quantity(card_id: String) -> int:
	return int(_deck_quantities.get(card_id, 0))


func set_search_query(value: String) -> void:
	_search_query = value.strip_edges()
	if _search_input != null and _search_input.text != value:
		_search_input.text = value
	_refresh_ui()


func set_attribute_filter(attribute_id: String) -> void:
	_browser_attribute_filter = attribute_id
	_sync_option_selection(_attribute_filter_button, attribute_id)
	_refresh_ui()


func set_class_filter(class_id: String) -> void:
	_browser_class_filter = class_id
	_sync_option_selection(_class_filter_button, class_id)
	_refresh_ui()


func set_type_filter(card_type: String) -> void:
	_browser_type_filter = card_type
	_sync_option_selection(_type_filter_button, card_type)
	_refresh_ui()


func set_cost_filter(cost: int) -> void:
	_browser_cost_filter = cost
	_sync_option_selection(_cost_filter_button, cost)
	_refresh_ui()


func set_keyword_filter(term_id: String) -> void:
	_browser_keyword_filter = term_id
	_sync_option_selection(_keyword_filter_button, term_id)
	_refresh_ui()


func set_deck_attributes(attribute_ids: Array) -> bool:
	if _rules_registry == null:
		return false
	var normalized: Array[String] = _rules_registry.normalize_attribute_ids(attribute_ids)
	if normalized.size() > _rules_registry.get_max_attributes_per_deck():
		_status_message = "Decks may use at most %d attributes." % _rules_registry.get_max_attributes_per_deck()
		_refresh_ui()
		return false
	_deck_attribute_ids = normalized
	_status_message = "Deck attributes set to %s." % _attribute_summary(_deck_attribute_ids)
	_refresh_ui()
	return true


func select_card(card_id: String) -> bool:
	if not _card_by_id.has(card_id):
		_status_message = "Card `%s` is not present in the local catalog." % card_id
		_refresh_ui()
		return false
	_selected_card_id = card_id
	_status_message = "Selected %s." % _card_name(_card_by_id[card_id])
	_refresh_ui()
	return true


func add_card_to_deck(card_id: String, quantity: int = 1) -> bool:
	if not _card_by_id.has(card_id):
		_status_message = "Card `%s` is not present in the local catalog." % card_id
		_refresh_ui()
		return false
	if quantity <= 0:
		return false
	_deck_quantities[card_id] = int(_deck_quantities.get(card_id, 0)) + quantity
	_selected_card_id = card_id
	_status_message = "Added %s." % _card_name(_card_by_id[card_id])
	_refresh_ui()
	return true


func remove_card_from_deck(card_id: String, quantity: int = 1) -> bool:
	if not _deck_quantities.has(card_id) or quantity <= 0:
		return false
	var next_quantity := int(_deck_quantities.get(card_id, 0)) - quantity
	if next_quantity <= 0:
		_deck_quantities.erase(card_id)
	else:
		_deck_quantities[card_id] = next_quantity
	_status_message = "Removed %s." % _card_name(_card_by_id.get(card_id, {"name": card_id}))
	_refresh_ui()
	return true


func clear_deck() -> void:
	_deck_quantities.clear()
	_deck_attribute_ids.clear()
	_selected_card_id = ""
	_status_message = "Cleared local deckbuilder state."
	_refresh_ui()


func export_deck_json() -> String:
	var serialized := JSON.stringify(_current_deck_definition(), "  ")
	if _import_export_text != null:
		_import_export_text.text = serialized
	_status_message = "Exported deck definition JSON."
	_refresh_ui()
	return serialized


func import_deck_json(text: String) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		_status_message = "Import failed: expected deck-definition JSON."
		_refresh_ui()
		return {"is_valid": false}
	var parsed: Dictionary = json.data
	if typeof(parsed.get("attribute_ids", [])) != TYPE_ARRAY or typeof(parsed.get("cards", [])) != TYPE_ARRAY:
		_status_message = "Import failed: expected `attribute_ids` and `cards` arrays."
		_refresh_ui()
		return {"is_valid": false}
	_deck_attribute_ids = _rules_registry.normalize_attribute_ids(parsed.get("attribute_ids", []))
	_deck_quantities.clear()
	var skipped := 0
	for raw_entry in parsed.get("cards", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			skipped += 1
			continue
		var entry: Dictionary = raw_entry
		var card_id := str(entry.get("card_id", ""))
		var quantity := int(entry.get("quantity", 0))
		if card_id.is_empty() or quantity <= 0 or not _card_by_id.has(card_id):
			skipped += 1
			continue
		_deck_quantities[card_id] = quantity
	_status_message = "Imported deck JSON%s." % (" with %d skipped entries" % skipped if skipped > 0 else "")
	if _import_export_text != null:
		_import_export_text.text = text
	_refresh_ui()
	return {"is_valid": true, "skipped": skipped}


func _load_data() -> void:
	_rules_registry = DeckRulesRegistryClass.load_default()
	if _rules_registry == null or not _rules_registry.is_ready():
		_status_message = "Deckbuilder failed to load registry data."
		return
	var catalog_result := DemoCardCatalog.load_default()
	_catalog_cards = catalog_result.get("cards", [])
	_card_by_id = catalog_result.get("card_by_id", {})
	_keyword_registry = EvergreenRules.get_registry()
	_load_attribute_registry_labels()
	_status_message = "Loaded %d local demo cards for deckbuilding." % _catalog_cards.size()


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


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "Deckbuilder / Card Browser"
	root.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	var body := HSplitContainer.new()
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	body.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(body)

	var browser_column := VBoxContainer.new()
	browser_column.size_flags_horizontal = SIZE_EXPAND_FILL
	browser_column.size_flags_vertical = SIZE_EXPAND_FILL
	browser_column.add_theme_constant_override("separation", 8)
	body.add_child(browser_column)

	browser_column.add_child(_build_browser_filters())
	_browser_summary_label = Label.new()
	browser_column.add_child(_browser_summary_label)
	var browser_scroll := ScrollContainer.new()
	browser_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	browser_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	browser_column.add_child(browser_scroll)
	_browser_rows = VBoxContainer.new()
	_browser_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_browser_rows.add_theme_constant_override("separation", 6)
	browser_scroll.add_child(_browser_rows)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = SIZE_EXPAND_FILL
	right_column.size_flags_vertical = SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 8)
	body.add_child(right_column)

	right_column.add_child(_build_deck_identity_panel())
	_deck_summary_label = Label.new()
	_deck_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_column.add_child(_deck_summary_label)
	_curve_label = Label.new()
	_curve_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_column.add_child(_curve_label)
	_legality_label = Label.new()
	_legality_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_column.add_child(_legality_label)

	var deck_scroll := ScrollContainer.new()
	deck_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	deck_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right_column.add_child(deck_scroll)
	_deck_rows = VBoxContainer.new()
	_deck_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_deck_rows.add_theme_constant_override("separation", 6)
	deck_scroll.add_child(_deck_rows)

	var inspector_panel := PanelContainer.new()
	right_column.add_child(inspector_panel)
	_selected_card_label = Label.new()
	_selected_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_panel.add_child(_selected_card_label)

	var import_panel := PanelContainer.new()
	right_column.add_child(import_panel)
	var import_box := VBoxContainer.new()
	import_box.add_theme_constant_override("separation", 6)
	import_panel.add_child(import_box)
	var import_title := Label.new()
	import_title.text = "Import / Export Hooks (local JSON only)"
	import_box.add_child(import_title)
	var import_actions := HBoxContainer.new()
	import_actions.add_theme_constant_override("separation", 6)
	import_box.add_child(import_actions)
	var export_button := Button.new()
	export_button.text = "Export JSON"
	export_button.pressed.connect(_on_export_pressed)
	import_actions.add_child(export_button)
	var import_button := Button.new()
	import_button.text = "Import JSON"
	import_button.pressed.connect(_on_import_pressed)
	import_actions.add_child(import_button)
	var clear_button := Button.new()
	clear_button.text = "Clear Deck"
	clear_button.pressed.connect(_on_clear_pressed)
	import_actions.add_child(clear_button)
	_import_export_text = TextEdit.new()
	_import_export_text.custom_minimum_size = Vector2(0, 120)
	import_box.add_child(_import_export_text)


func _build_browser_filters() -> Control:
	var filter_panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	filter_panel.add_child(box)
	var row_one := HBoxContainer.new()
	row_one.add_theme_constant_override("separation", 6)
	box.add_child(row_one)
	var search_label := Label.new()
	search_label.text = "Search"
	row_one.add_child(search_label)
	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_search_input.placeholder_text = "Name, text, or id"
	_search_input.text_changed.connect(_on_search_changed)
	row_one.add_child(_search_input)

	var row_two := HBoxContainer.new()
	row_two.add_theme_constant_override("separation", 6)
	box.add_child(row_two)
	_attribute_filter_button = _build_filter_button(row_two, "Attribute", _attribute_filter_items())
	_class_filter_button = _build_filter_button(row_two, "Class", _class_filter_items())
	_type_filter_button = _build_filter_button(row_two, "Type", _type_filter_items())
	_cost_filter_button = _build_filter_button(row_two, "Cost", _cost_filter_items())
	_keyword_filter_button = _build_filter_button(row_two, "Keyword / Tag", _keyword_filter_items())
	_attribute_filter_button.item_selected.connect(_on_attribute_filter_selected)
	_class_filter_button.item_selected.connect(_on_class_filter_selected)
	_type_filter_button.item_selected.connect(_on_type_filter_selected)
	_cost_filter_button.item_selected.connect(_on_cost_filter_selected)
	_keyword_filter_button.item_selected.connect(_on_keyword_filter_selected)
	return filter_panel


func _build_deck_identity_panel() -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_deck_banner_label = Label.new()
	_deck_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_deck_banner_label)
	var subtitle := Label.new()
	subtitle.text = "Deck Attributes"
	box.add_child(subtitle)
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	box.add_child(button_row)
	for attribute_id in ["strength", "intelligence", "willpower", "agility", "endurance"]:
		var button := Button.new()
		button.toggle_mode = true
		button.text = _attribute_display_name(attribute_id)
		button.pressed.connect(_on_attribute_toggle_pressed.bind(attribute_id))
		button_row.add_child(button)
		_attribute_button_by_id[attribute_id] = button
	return panel


func _build_filter_button(parent: HBoxContainer, label_text: String, items: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var button := OptionButton.new()
	for item in items:
		button.add_item(str(item.get("label", "")))
		button.set_item_metadata(button.item_count - 1, item.get("value", ""))
	parent.add_child(button)
	return button


func _refresh_ui() -> void:
	_status_label.text = _status_message
	_refresh_attribute_buttons()
	_refresh_browser()
	_refresh_deck_summary()
	_refresh_deck_rows()
	_refresh_selected_card()


func _refresh_attribute_buttons() -> void:
	for attribute_id in _attribute_button_by_id.keys():
		var button: Button = _attribute_button_by_id[attribute_id]
		button.button_pressed = _deck_attribute_ids.has(attribute_id)


func _refresh_browser() -> void:
	_clear_children(_browser_rows)
	var filtered := _filtered_cards()
	_browser_summary_label.text = "%d visible cards | %d cards in deck" % [filtered.size(), get_deck_count()]
	for card in filtered:
		_browser_rows.add_child(_build_browser_row(card))
	if _browser_rows.get_child_count() == 0:
		_browser_rows.add_child(_placeholder_label("No cards match the current filters."))


func _refresh_deck_summary() -> void:
	var deck_definition := _current_deck_definition()
	var validation := DeckValidator.validate_deck(deck_definition, _card_by_id, _rules_registry)
	var identity: Dictionary = validation.get("identity", {})
	_deck_banner_label.text = "Identity: %s" % _identity_label(identity)
	_deck_summary_label.text = "Attributes: %s\nCards: %d / %d-%d" % [
		_attribute_summary(_deck_attribute_ids),
		int(validation.get("card_count", 0)),
		int(identity.get("min_cards", 0)),
		int(identity.get("max_cards", 0)),
	]
	_curve_label.text = _curve_text(deck_definition)
	_legality_label.text = "Legal deck." if bool(validation.get("is_valid", false)) else "Illegal deck:\n- %s" % "\n- ".join(validation.get("errors", []))


func _refresh_deck_rows() -> void:
	_clear_children(_deck_rows)
	var ids: Array = _deck_quantities.keys()
	ids.sort()
	for card_id in ids:
		var card: Dictionary = _card_by_id.get(str(card_id), {})
		if card.is_empty():
			continue
		_deck_rows.add_child(_build_deck_row(str(card_id), card, int(_deck_quantities.get(card_id, 0))))
	if _deck_rows.get_child_count() == 0:
		_deck_rows.add_child(_placeholder_label("Deck is empty."))


func _refresh_selected_card() -> void:
	var card: Dictionary = _card_by_id.get(_selected_card_id, {})
	_selected_card_label.text = _card_detail_text(card) if not card.is_empty() else "Select a card to inspect rules text, attributes, and copy pressure."


func _build_browser_row(card: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var select_button := Button.new()
	select_button.size_flags_horizontal = SIZE_EXPAND_FILL
	select_button.text = "%s | %s | %s | Cost %d | Copies %d/%d%s" % [
		_card_name(card),
		_card_type_label(str(card.get("card_type", ""))),
		_card_affiliation_label(card),
		int(card.get("cost", 0)),
		get_deck_card_quantity(str(card.get("card_id", ""))),
		_copy_limit(card),
		_keyword_badge(card),
	]
	select_button.tooltip_text = _card_detail_text(card)
	select_button.pressed.connect(_on_card_select_pressed.bind(str(card.get("card_id", ""))))
	row.add_child(select_button)
	var add_button := Button.new()
	add_button.text = "+"
	add_button.tooltip_text = "Add one copy"
	add_button.pressed.connect(_on_card_add_pressed.bind(str(card.get("card_id", ""))))
	row.add_child(add_button)
	return row


func _build_deck_row(card_id: String, card: Dictionary, quantity: int) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var remove_button := Button.new()
	remove_button.text = "-"
	remove_button.pressed.connect(_on_card_remove_pressed.bind(card_id))
	row.add_child(remove_button)
	var select_button := Button.new()
	select_button.size_flags_horizontal = SIZE_EXPAND_FILL
	select_button.text = "%dx %s | Cost %d" % [quantity, _card_name(card), int(card.get("cost", 0))]
	select_button.tooltip_text = _card_detail_text(card)
	select_button.pressed.connect(_on_card_select_pressed.bind(card_id))
	row.add_child(select_button)
	var add_button := Button.new()
	add_button.text = "+"
	add_button.pressed.connect(_on_card_add_pressed.bind(card_id))
	row.add_child(add_button)
	return row


func _filtered_cards() -> Array:
	var filtered: Array = []
	var search_term := _search_query.to_lower()
	for raw_card in _catalog_cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = raw_card
		if not search_term.is_empty() and not _card_matches_search(card, search_term):
			continue
		if not _browser_attribute_filter.is_empty() and not _card_matches_attribute_filter(card, _browser_attribute_filter):
			continue
		if not _browser_class_filter.is_empty() and not _card_matches_class_filter(card, _browser_class_filter):
			continue
		if not _browser_type_filter.is_empty() and str(card.get("card_type", "")) != _browser_type_filter:
			continue
		if _browser_cost_filter >= 0 and not _card_matches_cost_filter(card, _browser_cost_filter):
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


func _card_matches_attribute_filter(card: Dictionary, attribute_id: String) -> bool:
	var attributes: Array = card.get("attributes", [])
	return attributes.is_empty() if attribute_id == "neutral" else attributes.has(attribute_id)


func _card_matches_class_filter(card: Dictionary, class_id: String) -> bool:
	if class_id == "none":
		return _card_class_id(card).is_empty()
	return _card_class_id(card) == class_id


func _card_matches_cost_filter(card: Dictionary, cost: int) -> bool:
	var card_cost := int(card.get("cost", 0))
	return card_cost >= 7 if cost == 7 else card_cost == cost


func _card_matches_keyword_filter(card: Dictionary, term_id: String) -> bool:
	return card.get("keywords", []).has(term_id) or card.get("rules_tags", []).has(term_id)


func _current_deck_definition() -> Dictionary:
	return {
		"attribute_ids": _deck_attribute_ids.duplicate(),
		"cards": _deck_entries(),
	}


func _deck_entries() -> Array:
	var ids: Array = _deck_quantities.keys()
	ids.sort()
	var entries: Array = []
	for card_id in ids:
		entries.append({
			"card_id": str(card_id),
			"quantity": int(_deck_quantities.get(card_id, 0)),
		})
	return entries


func _curve_text(deck_definition: Dictionary) -> String:
	var buckets := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0}
	for raw_entry in deck_definition.get("cards", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var card: Dictionary = _card_by_id.get(str(entry.get("card_id", "")), {})
		if card.is_empty():
			continue
		var cost: int = min(int(card.get("cost", 0)), 7)
		buckets[cost] = int(buckets.get(cost, 0)) + int(entry.get("quantity", 0))
	var parts := PackedStringArray()
	for bucket in [0, 1, 2, 3, 4, 5, 6]:
		parts.append("%d:%d" % [bucket, int(buckets.get(bucket, 0))])
	parts.append("7+:%d" % int(buckets.get(7, 0)))
	return "Curve | %s" % " | ".join(parts)


func _card_detail_text(card: Dictionary) -> String:
	if card.is_empty():
		return ""
	var lines := PackedStringArray()
	lines.append(_card_name(card))
	lines.append("Type: %s | Cost: %d" % [_card_type_label(str(card.get("card_type", ""))), int(card.get("cost", 0))])
	if str(card.get("card_type", "")) == "creature":
		lines.append("Stats: %d/%d" % [int(card.get("base_power", 0)), int(card.get("base_health", 0))])
	lines.append("Attributes: %s" % _card_affiliation_label(card))
	if not _card_class_id(card).is_empty():
		lines.append("Class: %s" % _class_display_name(_card_class_id(card)))
	if not card.get("keywords", []).is_empty():
		lines.append("Keywords: %s" % ", ".join(card.get("keywords", [])))
	if not card.get("rules_tags", []).is_empty():
		lines.append("Tags: %s" % ", ".join(card.get("rules_tags", [])))
	lines.append("Text: %s" % str(card.get("rules_text", "No rules text.")))
	lines.append("In deck: %d / %d" % [get_deck_card_quantity(str(card.get("card_id", ""))), _copy_limit(card)])
	return "\n".join(lines)


func _copy_limit(card: Dictionary) -> int:
	return _rules_registry.get_unique_copy_limit() if bool(card.get("is_unique", false)) else _rules_registry.get_default_copy_limit()


func _keyword_badge(card: Dictionary) -> String:
	var badges := PackedStringArray()
	for keyword in card.get("keywords", []):
		badges.append(str(keyword).capitalize())
	for tag in card.get("rules_tags", []):
		badges.append(str(tag).capitalize())
	return " | %s" % ", ".join(badges) if not badges.is_empty() else ""


func _identity_label(identity: Dictionary) -> String:
	var class_display_name: Variant = identity.get("class_display_name", null)
	if class_display_name != null:
		return str(class_display_name)
	var attributes: Array = identity.get("attribute_ids", [])
	if attributes.is_empty():
		return "Neutral"
	if attributes.size() == 1:
		return "%s deck" % _attribute_display_name(str(attributes[0]))
	return "%s deck" % String(identity.get("deck_type", "Attribute")).capitalize()


func _attribute_summary(attribute_ids: Array) -> String:
	if attribute_ids.is_empty():
		return "Neutral"
	var labels := PackedStringArray()
	for attribute_id in attribute_ids:
		labels.append(_attribute_display_name(str(attribute_id)))
	return " / ".join(labels)


func _card_affiliation_label(card: Dictionary) -> String:
	var attributes: Array = card.get("attributes", [])
	if attributes.is_empty():
		return "Neutral"
	var labels := PackedStringArray()
	for attribute_id in attributes:
		labels.append(_attribute_display_name(str(attribute_id)))
	return " / ".join(labels)


func _card_name(card: Dictionary) -> String:
	return str(card.get("name", card.get("card_id", "Unknown Card")))


func _card_class_id(card: Dictionary) -> String:
	var class_id: Variant = card.get("class_id", null)
	return "" if class_id == null else str(class_id)


func _card_type_label(card_type: String) -> String:
	return card_type.capitalize()


func _attribute_display_name(attribute_id: String) -> String:
	return str(_attribute_display_names.get(attribute_id, attribute_id.capitalize()))


func _class_display_name(class_id: String) -> String:
	return str(_class_display_names.get(class_id, class_id.capitalize()))


func _attribute_filter_items() -> Array:
	return [
		{"label": "Any", "value": ""},
		{"label": "Neutral", "value": "neutral"},
		{"label": "Strength", "value": "strength"},
		{"label": "Intelligence", "value": "intelligence"},
		{"label": "Willpower", "value": "willpower"},
		{"label": "Agility", "value": "agility"},
		{"label": "Endurance", "value": "endurance"},
	]


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


func _cost_filter_items() -> Array:
	var items: Array = [{"label": "Any", "value": -1}]
	for cost in [0, 1, 2, 3, 4, 5, 6]:
		items.append({"label": str(cost), "value": cost})
	items.append({"label": "7+", "value": 7})
	return items


func _keyword_filter_items() -> Array:
	var items: Array = [{"label": "Any", "value": ""}]
	for keyword in _keyword_registry.get("keywords", []):
		if typeof(keyword) != TYPE_DICTIONARY:
			continue
		items.append({"label": str(keyword.get("display_name", keyword.get("id", ""))), "value": str(keyword.get("id", ""))})
	items.append({"label": "Prophecy", "value": "prophecy"})
	return items


func _sync_option_selection(button: OptionButton, value) -> void:
	if button == null:
		return
	for index in range(button.item_count):
		if button.get_item_metadata(index) == value:
			button.select(index)
			return


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _placeholder_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_search_changed(value: String) -> void:
	_search_query = value.strip_edges()
	_refresh_ui()


func _on_attribute_filter_selected(index: int) -> void:
	_browser_attribute_filter = str(_attribute_filter_button.get_item_metadata(index))
	_refresh_ui()


func _on_class_filter_selected(index: int) -> void:
	_browser_class_filter = str(_class_filter_button.get_item_metadata(index))
	_refresh_ui()


func _on_type_filter_selected(index: int) -> void:
	_browser_type_filter = str(_type_filter_button.get_item_metadata(index))
	_refresh_ui()


func _on_cost_filter_selected(index: int) -> void:
	_browser_cost_filter = int(_cost_filter_button.get_item_metadata(index))
	_refresh_ui()


func _on_keyword_filter_selected(index: int) -> void:
	_browser_keyword_filter = str(_keyword_filter_button.get_item_metadata(index))
	_refresh_ui()


func _on_attribute_toggle_pressed(attribute_id: String) -> void:
	var next_attributes: Array = _deck_attribute_ids.duplicate()
	if next_attributes.has(attribute_id):
		next_attributes.erase(attribute_id)
		set_deck_attributes(next_attributes)
		return
	next_attributes.append(attribute_id)
	if not set_deck_attributes(next_attributes):
		_refresh_ui()


func _on_card_select_pressed(card_id: String) -> void:
	select_card(card_id)


func _on_card_add_pressed(card_id: String) -> void:
	add_card_to_deck(card_id)


func _on_card_remove_pressed(card_id: String) -> void:
	remove_card_from_deck(card_id)


func _on_export_pressed() -> void:
	export_deck_json()


func _on_import_pressed() -> void:
	import_deck_json(_import_export_text.text)


func _on_clear_pressed() -> void:
	clear_deck()