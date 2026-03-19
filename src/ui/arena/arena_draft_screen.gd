class_name ArenaDraftScreen
extends Control

signal draft_complete(deck: Array)

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const CardDisplayComponentClass = preload("res://src/ui/components/CardDisplayComponent.gd")
const MagickaCurveChartClass = preload("res://src/ui/components/magicka_curve_chart.gd")
const ArenaDraftEngineClass = preload("res://src/arena/arena_draft_engine.gd")

const CARD_ASPECT_RATIO := 384.0 / 220.0
const ATTRIBUTE_TINTS := {
	"strength": Color(0.84, 0.39, 0.31, 1.0),
	"intelligence": Color(0.42, 0.62, 0.96, 1.0),
	"willpower": Color(0.92, 0.78, 0.38, 1.0),
	"agility": Color(0.4, 0.76, 0.52, 1.0),
	"endurance": Color(0.58, 0.46, 0.72, 1.0),
}
const NEUTRAL_COST_COLOR := Color(0.6, 0.6, 0.6, 1.0)

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
var _deck_card_list_container: VBoxContainer
var _magicka_curve_chart: Control
var _card_count_label: Label
var _card_hover_preview_layer: Control
var _hover_preview_card_id := ""
var _hover_preview_node: Control
var _hover_pending_card_id := ""
var _hover_pending_row: Control
var _hover_pending_entry: Dictionary
var _hover_delay_timer: Timer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


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


func _show_next_pick() -> void:
	if _current_pick >= _total_picks:
		draft_complete.emit(_deck)
		return
	var rarity: String = ArenaDraftEngineClass.roll_rarity()
	_pick_options = ArenaDraftEngineClass.get_pick_options(rarity, _card_pool, _deck, 3)
	_current_pick += 1
	_refresh_pick_counter()
	_refresh_options()


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

	# Left column — pick counter + card options
	_left_column = VBoxContainer.new()
	_left_column.size_flags_horizontal = SIZE_EXPAND_FILL
	_left_column.size_flags_vertical = SIZE_EXPAND_FILL
	_left_column.add_theme_constant_override("separation", 16)
	_root_split.add_child(_left_column)

	_pick_counter_label = Label.new()
	_pick_counter_label.text = "Pick 0 of 30"
	_pick_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_counter_label.add_theme_font_size_override("font_size", 22)
	_left_column.add_child(_pick_counter_label)

	# Card options displayed in a centered horizontal row
	var options_center := CenterContainer.new()
	options_center.size_flags_horizontal = SIZE_EXPAND_FILL
	options_center.size_flags_vertical = SIZE_EXPAND_FILL
	_left_column.add_child(options_center)

	_options_container = HBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 16)
	_options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_center.add_child(_options_container)

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

	_hover_delay_timer = Timer.new()
	_hover_delay_timer.one_shot = true
	_hover_delay_timer.wait_time = 0.35
	_hover_delay_timer.timeout.connect(_on_hover_delay_timeout)
	add_child(_hover_delay_timer)

	# Deck header
	var deck_header := Label.new()
	deck_header.text = "Deck"
	deck_header.add_theme_font_size_override("font_size", 20)
	deck_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_column.add_child(deck_header)

	# Deck card list
	_deck_card_list_scroll = ScrollContainer.new()
	_deck_card_list_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_deck_card_list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_right_column.add_child(_deck_card_list_scroll)
	_deck_card_list_container = VBoxContainer.new()
	_deck_card_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_deck_card_list_container.add_theme_constant_override("separation", 4)
	_deck_card_list_scroll.add_child(_deck_card_list_container)

	# Magicka curve chart
	_magicka_curve_chart = MagickaCurveChartClass.new()
	_magicka_curve_chart.size_flags_horizontal = SIZE_EXPAND_FILL
	_right_column.add_child(_magicka_curve_chart)

	# Card count label
	_card_count_label = Label.new()
	_card_count_label.add_theme_font_size_override("font_size", 16)
	_card_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(card_width, card_height)
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		wrapper.gui_input.connect(_on_option_input.bind(card))
		_options_container.add_child(wrapper)

		var card_display := CardDisplayComponentClass.new()
		card_display.apply_card(card, CardDisplayComponentClass.PRESENTATION_FULL)
		card_display.custom_minimum_size = Vector2(card_width, card_height)
		card_display.size = Vector2(card_width, card_height)
		card_display.set_interactive(false)
		wrapper.add_child(card_display)
		card_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_option_displays.append(card_display)


func _refresh_deck_card_list() -> void:
	if _deck_card_list_container == null:
		return
	_clear_children(_deck_card_list_container)

	var deck_entries: Array = []
	for entry in _deck:
		var card_id: String = str(entry.get("card_id", ""))
		var card: Dictionary = _card_database.get(card_id, {})
		if card.is_empty():
			continue
		deck_entries.append({
			"card_id": card_id,
			"name": str(card.get("name", card_id)),
			"cost": int(card.get("cost", 0)),
			"quantity": int(entry.get("quantity", 0)),
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
	row.custom_minimum_size = Vector2(0, 40)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_entered.connect(_on_deck_row_mouse_entered.bind(row, entry))
	row.mouse_exited.connect(_on_deck_row_mouse_exited.bind(entry))

	# Cost badge
	var cost_badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.set_corner_radius_all(16)
	badge_style.set_content_margin_all(0)
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 5
	badge_style.content_margin_bottom = 5
	var cost_color := _get_card_cost_badge_color(entry.get("attributes", []))
	badge_style.bg_color = cost_color
	cost_badge.add_theme_stylebox_override("panel", badge_style)
	cost_badge.custom_minimum_size = Vector2(36, 32)
	var cost_label := Label.new()
	cost_label.text = str(entry["cost"])
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_label)
	row.add_child(cost_badge)

	# Card name
	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	# Quantity indicator
	var qty_label := Label.new()
	qty_label.text = "x%d" % entry["quantity"]
	qty_label.add_theme_font_size_override("font_size", 16)
	qty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	row.add_child(qty_label)

	return row


func _get_card_cost_badge_color(attributes: Array) -> Color:
	if attributes.size() == 1:
		return ATTRIBUTE_TINTS.get(str(attributes[0]), NEUTRAL_COST_COLOR)
	return NEUTRAL_COST_COLOR


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
	var available_height := 500.0
	if _left_column != null and _left_column.size.y > 0:
		# Leave room for pick counter and spacing
		available_height = maxf(300.0, _left_column.size.y - 80.0)
	return minf(available_height, 500.0)


# --- Signal Handlers ---

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


# --- Deck Row Hover Preview ---

func _on_deck_row_mouse_entered(row: Control, entry: Dictionary) -> void:
	var card_id: String = str(entry.get("card_id", ""))
	if card_id.is_empty():
		return
	_clear_deck_hover_preview()
	_hover_pending_card_id = card_id
	_hover_pending_row = row
	_hover_pending_entry = entry
	_hover_delay_timer.start()


func _on_deck_row_mouse_exited(_entry: Dictionary) -> void:
	_hover_pending_card_id = ""
	_hover_pending_row = null
	_hover_pending_entry = {}
	_hover_delay_timer.stop()
	_clear_deck_hover_preview()


func _on_hover_delay_timeout() -> void:
	if _hover_pending_card_id.is_empty() or _hover_pending_row == null:
		return
	_show_deck_hover_preview(_hover_pending_row, _hover_pending_card_id)


func _show_deck_hover_preview(row: Control, card_id: String) -> void:
	_clear_deck_hover_preview()
	var card: Dictionary = _card_database.get(card_id, {})
	if card.is_empty():
		return
	_hover_preview_card_id = card_id
	var preview_height := 384.0
	var preview_width := preview_height / CARD_ASPECT_RATIO
	var preview_size := Vector2(preview_width, preview_height)
	var wrapper := Control.new()
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var component := CardDisplayComponentClass.new()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_interactive(false)
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CardDisplayComponentClass.PRESENTATION_FULL)
	wrapper.add_child(component)
	_card_hover_preview_layer.add_child(wrapper)
	_hover_preview_node = wrapper
	# Position to the left of the right column
	var row_rect := row.get_global_rect()
	var layer_origin := _card_hover_preview_layer.get_global_rect().position
	var target_x := row_rect.position.x - preview_size.x - 12.0 - layer_origin.x
	var target_y := row_rect.get_center().y - preview_size.y * 0.5 - layer_origin.y
	target_y = clampf(target_y, 0.0, maxf(_card_hover_preview_layer.size.y - preview_size.y, 0.0))
	target_x = maxf(target_x, 0.0)
	wrapper.position = Vector2(target_x, target_y)


func _clear_deck_hover_preview() -> void:
	_hover_preview_card_id = ""
	if _hover_preview_node != null and is_instance_valid(_hover_preview_node):
		_hover_preview_node.get_parent().remove_child(_hover_preview_node)
		_hover_preview_node.queue_free()
	_hover_preview_node = null


# --- Helpers ---

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
