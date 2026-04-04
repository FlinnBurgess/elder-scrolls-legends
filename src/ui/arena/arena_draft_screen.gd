class_name ArenaDraftScreen
extends Control

signal draft_complete(deck: Array)
signal draft_state_changed(progress: Dictionary)

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")
const MagickaCurveChartClass = preload("res://src/ui/components/magicka_curve_chart.gd")
const ArenaDraftEngineClass = preload("res://src/arena/arena_draft_engine.gd")
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

# Draft config
var _attribute_ids: Array = []
var _card_database: Dictionary = {}
var _card_pool: Array = []
var _total_picks := 30
var _current_pick := 0
var _is_bonus_pick := false

# Deck state: Array of {card_id, quantity}
var _deck: Array = []

# Current pick options (full card dicts)
var _pick_options: Array = []

# UI references
var _is_built := false
var _root_split: HSplitContainer
var _left_column: VBoxContainer
var _right_column: VBoxContainer
var _pick_counter_label: Label
var _options_container: HBoxContainer
var _option_displays: Array = []
var _deck_card_list_scroll: ScrollContainer
var _deck_card_list: DeckCardList
var _magicka_curve_chart: Control
var _card_count_label: Label
var _card_hover_preview_layer: Control
var _hovered_option_index := -1
var _error_report_hovered_type := ""
var _error_report_hovered_context := ""
var _error_report_popover: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


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
		var pick_index := -1
		match event.keycode:
			KEY_1: pick_index = 0
			KEY_2: pick_index = 1
			KEY_3: pick_index = 2
		if pick_index >= 0 and pick_index < _pick_options.size():
			_on_option_selected(_pick_options[pick_index])
			get_viewport().set_input_as_handled()
			return
		if (event.keycode == KEY_UP or event.keycode == KEY_DOWN) and _hovered_option_index >= 0 and _hovered_option_index < _option_displays.size():
			var card_display = _option_displays[_hovered_option_index]
			if card_display != null and is_instance_valid(card_display) and card_display.has_method("cycle_relationship"):
				var direction := 1 if event.keycode == KEY_DOWN else -1
				card_display.cycle_relationship(direction)
				get_viewport().set_input_as_handled()


func start_draft(attribute_ids: Array, card_database: Dictionary, total_picks: int = 30) -> void:
	_attribute_ids = attribute_ids
	_card_database = card_database
	_card_pool = ArenaDraftEngineClass.get_card_pool(attribute_ids, card_database)
	_total_picks = total_picks
	_current_pick = 0
	_is_bonus_pick = false
	_deck = []
	_show_next_pick()


func start_bonus_pick(existing_deck: Array, attribute_ids: Array, card_database: Dictionary) -> void:
	_attribute_ids = attribute_ids
	_card_database = card_database
	_card_pool = ArenaDraftEngineClass.get_card_pool(attribute_ids, card_database)
	_total_picks = 1
	_current_pick = 0
	_is_bonus_pick = true
	_deck = existing_deck.duplicate(true)
	_refresh_deck_card_list()
	_refresh_magicka_curve()
	_refresh_card_count()
	_show_next_pick()


func resume_draft(progress: Dictionary, attribute_ids: Array, card_database: Dictionary) -> void:
	_attribute_ids = attribute_ids
	_card_database = card_database
	_card_pool = ArenaDraftEngineClass.get_card_pool(attribute_ids, card_database)
	_current_pick = int(progress.get("current_pick", 0))
	_total_picks = int(progress.get("total_picks", 30))
	_is_bonus_pick = bool(progress.get("is_bonus_pick", false))
	_deck = Array(progress.get("deck", []))
	# Restore pick options from saved card IDs
	_pick_options = []
	var saved_option_ids: Array = Array(progress.get("pick_options", []))
	for card_id in saved_option_ids:
		var card: Dictionary = _card_database.get(str(card_id), {})
		if not card.is_empty():
			_pick_options.append(card)
	_refresh_pick_counter()
	_refresh_options()
	_refresh_deck_card_list()
	_refresh_magicka_curve()
	_refresh_card_count()


func _show_next_pick() -> void:
	if _current_pick >= _total_picks:
		draft_complete.emit(_deck)
		return
	var rarity: String = ArenaDraftEngineClass.roll_rarity()
	_pick_options = ArenaDraftEngineClass.get_pick_options(rarity, _card_pool, _deck, 3)
	_current_pick += 1
	_refresh_pick_counter()
	_refresh_options()
	# Save draft state for resume
	var option_ids: Array = []
	for card in _pick_options:
		option_ids.append(str(card.get("card_id", "")))
	draft_state_changed.emit({
		"current_pick": _current_pick,
		"deck": _deck.duplicate(true),
		"pick_options": option_ids,
		"is_bonus_pick": _is_bonus_pick,
		"total_picks": _total_picks,
	})


func _on_option_selected(card: Dictionary) -> void:
	var card_id: String = str(card.get("card_id", ""))
	if card_id.is_empty():
		return
	# Add to deck
	var found := false
	for entry in _deck:
		if str(entry.get("card_id", "")) == card_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + 1
			found = true
			break
	if not found:
		_deck.append({"card_id": card_id, "quantity": 1})
	_refresh_deck_card_list()
	_refresh_magicka_curve()
	_refresh_card_count()
	_show_next_pick()


# --- UI Construction ---

func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

	UITheme.add_background(self)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_top", 12)
	outer_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(outer_margin)

	_root_split = HSplitContainer.new()
	_root_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_root_split.size_flags_vertical = SIZE_EXPAND_FILL
	_root_split.add_theme_constant_override("separation", 16)
	_root_split.resized.connect(_on_root_split_resized)
	outer_margin.add_child(_root_split)

	# Left column — pick counter + card options (vertically centered together)
	_left_column = VBoxContainer.new()
	_left_column.size_flags_horizontal = SIZE_EXPAND_FILL
	_left_column.size_flags_vertical = SIZE_EXPAND_FILL
	_root_split.add_child(_left_column)

	var options_center := CenterContainer.new()
	options_center.size_flags_horizontal = SIZE_EXPAND_FILL
	options_center.size_flags_vertical = SIZE_EXPAND_FILL
	_left_column.add_child(options_center)

	var pick_group := VBoxContainer.new()
	pick_group.add_theme_constant_override("separation", 16)
	options_center.add_child(pick_group)

	_pick_counter_label = Label.new()
	_pick_counter_label.text = "Pick 0 of 30"
	UITheme.style_title(_pick_counter_label, 32)
	pick_group.add_child(_pick_counter_label)

	# Card options displayed in a centered horizontal row
	_options_container = HBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 16)
	_options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pick_group.add_child(_options_container)

	# Right column — deck list + magicka curve + card count
	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = SIZE_EXPAND_FILL
	_right_column.size_flags_vertical = SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", 12)
	_root_split.add_child(_right_column)

	# Card hover preview layer (overlay on top of everything)
	_card_hover_preview_layer = Control.new()
	_card_hover_preview_layer.name = "CardHoverPreviewLayer"
	_card_hover_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_hover_preview_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_card_hover_preview_layer)

	# Deck header
	var deck_header := Label.new()
	deck_header.text = "Deck"
	UITheme.style_title(deck_header, 24)
	_right_column.add_child(deck_header)

	_right_column.add_child(UITheme.make_separator(0.0))

	# Deck card list
	_deck_card_list = DeckCardListClass.new()
	_deck_card_list.row_mouse_entered.connect(_on_deck_row_mouse_entered)
	_deck_card_list.row_mouse_exited.connect(_on_deck_row_mouse_exited)
	_deck_card_list_scroll = _deck_card_list.create_scroll_container()
	_right_column.add_child(_deck_card_list_scroll)

	# Magicka curve chart
	_magicka_curve_chart = MagickaCurveChartClass.new()
	_magicka_curve_chart.size_flags_horizontal = SIZE_EXPAND_FILL
	_magicka_curve_chart.mouse_filter = Control.MOUSE_FILTER_STOP
	_magicka_curve_chart.mouse_entered.connect(_on_magicka_curve_mouse_entered)
	_magicka_curve_chart.mouse_exited.connect(_on_magicka_curve_mouse_exited)
	_right_column.add_child(_magicka_curve_chart)

	# Card count label
	_card_count_label = Label.new()
	_card_count_label.add_theme_font_size_override("font_size", 18)
	_card_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_count_label.add_theme_color_override("font_color", UITheme.TEXT_SECTION)
	_right_column.add_child(_card_count_label)
	_refresh_card_count()

	_on_root_split_resized.call_deferred()


# --- Refresh Methods ---

func _refresh_pick_counter() -> void:
	if _pick_counter_label == null:
		return
	if _is_bonus_pick:
		_pick_counter_label.text = "Bonus Pick"
	else:
		_pick_counter_label.text = "Pick %d of %d" % [_current_pick, _total_picks]


func _refresh_options() -> void:
	if _options_container == null:
		return
	_clear_children(_options_container)
	_option_displays.clear()

	var card_height := _compute_option_card_height()
	var card_width := card_height / CARD_ASPECT_RATIO

	for card in _pick_options:
		var option_column := VBoxContainer.new()
		option_column.add_theme_constant_override("separation", 6)
		option_column.alignment = BoxContainer.ALIGNMENT_CENTER
		_options_container.add_child(option_column)

		var option_index := _option_displays.size()
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(card_width, card_height)
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		wrapper.gui_input.connect(_on_option_input.bind(card))
		wrapper.mouse_entered.connect(_on_option_mouse_entered.bind(option_index))
		wrapper.mouse_exited.connect(_on_option_mouse_exited.bind(option_index))
		option_column.add_child(wrapper)

		var card_display := CardDisplayComponentClass.new()
		card_display.apply_card(card, CardDisplayComponentClass.PRESENTATION_FULL)
		if card_display.has_method("set_relationship_context"):
			card_display.set_relationship_context(_build_draft_relationship_context())
		card_display.custom_minimum_size = Vector2(card_width, card_height)
		card_display.size = Vector2(card_width, card_height)
		card_display.set_interactive(false)
		wrapper.add_child(card_display)
		card_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_option_displays.append(card_display)

		var in_deck_count := _get_card_count_in_deck(str(card.get("card_id", "")))
		var in_deck_label := Label.new()
		in_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if in_deck_count > 0:
			in_deck_label.text = "%d in deck" % in_deck_count
			in_deck_label.add_theme_color_override("font_color", UITheme.GOLD_DIM)
		else:
			in_deck_label.text = ""
		in_deck_label.add_theme_font_size_override("font_size", 16)
		option_column.add_child(in_deck_label)


func _refresh_deck_card_list() -> void:
	if _deck_card_list == null:
		return
	if _card_hover_preview_layer != null and not _card_database.is_empty():
		_deck_card_list.enable_hover_preview(_card_hover_preview_layer, _card_database)
		_deck_card_list.set_relationship_context_callback(_build_draft_relationship_context)
	_deck_card_list.set_deck(_deck, _card_database)


func _refresh_magicka_curve() -> void:
	if _magicka_curve_chart == null:
		return
	_magicka_curve_chart.set_deck(_get_deck_definition(), _card_database)


func _refresh_card_count() -> void:
	if _card_count_label == null:
		return
	var count := _get_deck_count()
	_card_count_label.text = "%d cards" % count


func _get_deck_count() -> int:
	var total := 0
	for entry in _deck:
		total += int(entry.get("quantity", 0))
	return total


func _get_deck_definition() -> Dictionary:
	return {"cards": _deck.duplicate(true)}


func _compute_option_card_height() -> float:
	var available_height := 900.0
	if _left_column != null and _left_column.size.y > 0:
		available_height = maxf(400.0, _left_column.size.y - 60.0)
	return minf(available_height, 900.0)


# --- Signal Handlers ---

func _on_option_mouse_entered(option_index: int) -> void:
	_hovered_option_index = option_index
	if option_index >= 0 and option_index < _pick_options.size():
		var card: Dictionary = _pick_options[option_index]
		_error_report_hovered_type = "card"
		_error_report_hovered_context = "%s (pick option %d)" % [str(card.get("name", "")), option_index + 1]


func _on_option_mouse_exited(option_index: int) -> void:
	if _hovered_option_index == option_index:
		_hovered_option_index = -1
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""
	if option_index >= 0 and option_index < _option_displays.size():
		var card_display = _option_displays[option_index]
		if card_display != null and is_instance_valid(card_display) and card_display.has_method("reset_relationship_view"):
			card_display.reset_relationship_view()


func _on_option_input(event: InputEvent, card: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_option_selected(card)


func _on_root_split_resized() -> void:
	if _root_split == null or _root_split.size.x <= 0:
		return
	# Right column takes ~20% of width (positive offset pushes divider right)
	var target := int(_root_split.size.x * 0.3)
	if _root_split.split_offset == target:
		return
	_root_split.resized.disconnect(_on_root_split_resized)
	_root_split.split_offset = target
	_root_split.resized.connect(_on_root_split_resized)


# --- Deck Row Hover (error report context only, preview handled by DeckCardList) ---

func _on_deck_row_mouse_entered(_row: Control, entry: Dictionary) -> void:
	var card_id: String = str(entry.get("card_id", ""))
	if card_id.is_empty():
		return
	_error_report_hovered_type = "card"
	_error_report_hovered_context = "%s (in deck list)" % str(entry.get("name", card_id))


func _on_deck_row_mouse_exited(_entry: Dictionary) -> void:
	if _error_report_hovered_type == "card":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


func _build_draft_relationship_context() -> Dictionary:
	var deck_cards: Array = []
	for entry in _deck:
		var card: Dictionary = _card_database.get(str(entry.get("card_id", "")), {})
		var qty: int = int(entry.get("quantity", 1))
		for i in range(qty):
			deck_cards.append(card)
	return {"zone": "arena_draft", "deck_cards": deck_cards}


# --- Helpers ---

func _get_card_count_in_deck(card_id: String) -> int:
	for entry in _deck:
		if str(entry.get("card_id", "")) == card_id:
			return int(entry.get("quantity", 0))
	return 0


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


# --- Error Report Hover Handlers ---

func _on_magicka_curve_mouse_entered() -> void:
	_error_report_hovered_type = "magicka_curve"
	_error_report_hovered_context = "Magicka Curve Chart"


func _on_magicka_curve_mouse_exited() -> void:
	if _error_report_hovered_type == "magicka_curve":
		_error_report_hovered_type = ""
		_error_report_hovered_context = ""


# --- Error Report Popover ---

func _open_error_report_popover() -> void:
	if _error_report_popover != null:
		return
	var context_label := _error_report_hovered_context if not _error_report_hovered_type.is_empty() else "Arena Draft (general)"
	var element_type := _error_report_hovered_type if not _error_report_hovered_type.is_empty() else "general"
	var element_context := _error_report_hovered_context if not _error_report_hovered_type.is_empty() else "arena_draft"

	_error_report_popover = ErrorReportPopoverClass.new()
	_error_report_popover.report_submitted.connect(_on_error_report_submitted.bind(element_type, element_context))
	_error_report_popover.dismissed.connect(_on_error_report_dismissed)
	add_child(_error_report_popover)
	_error_report_popover.show_report(context_label)


func _on_error_report_submitted(comment: String, element_type: String, element_context: String) -> void:
	var report := {
		"screen": "arena_draft",
		"element_type": element_type,
		"element_context": element_context,
		"comment": comment,
		"snapshot": ErrorReportWriterClass.build_arena_draft_snapshot(_pick_options, _deck, _current_pick, _total_picks, _card_database),
	}
	ErrorReportWriterClass.write_report(report)
	_error_report_popover = null


func _on_error_report_dismissed() -> void:
	_error_report_popover = null
