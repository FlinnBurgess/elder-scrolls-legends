class_name ArenaRunStatusScreen
extends Control

signal fight_pressed
signal abandon_pressed

const BossRelicSystemClass = preload("res://src/arena/boss_relic_system.gd")

const ATTRIBUTE_TINTS := {
	"strength": Color(0.84, 0.39, 0.31, 1.0),
	"intelligence": Color(0.42, 0.62, 0.96, 1.0),
	"willpower": Color(0.92, 0.78, 0.38, 1.0),
	"agility": Color(0.4, 0.76, 0.52, 1.0),
	"endurance": Color(0.58, 0.46, 0.72, 1.0),
}
const NEUTRAL_COST_COLOR := Color(0.6, 0.6, 0.6, 1.0)

# Run data
var _wins: int = 0
var _losses: int = 0
var _current_match: int = 1
var _boss_relic = null  # BossRelic enum value or null
var _deck: Array = []  # Array of {card_id, quantity}
var _card_database: Dictionary = {}

# UI references
var _is_built := false
var _wins_label: Label
var _losses_label: Label
var _match_label: Label
var _boss_indicator: VBoxContainer
var _relic_name_label: Label
var _relic_desc_label: Label
var _deck_card_list_container: VBoxContainer
var _confirm_overlay: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


func set_run_data(wins: int, losses: int, current_match: int, boss_relic, deck: Array, card_database: Dictionary) -> void:
	_wins = wins
	_losses = losses
	_current_match = current_match
	_boss_relic = boss_relic
	_deck = deck.duplicate(true)
	_card_database = card_database
	_refresh()


func _refresh() -> void:
	if not _is_built:
		return
	_wins_label.text = "Wins: %d" % _wins
	_losses_label.text = "Losses: %d" % _losses
	if _current_match >= 9:
		_match_label.text = "Next Match: Boss Match"
	else:
		_match_label.text = "Next Match: %d of 9" % _current_match

	# Boss relic info
	var is_boss := _current_match >= 9
	_boss_indicator.visible = is_boss and _boss_relic != null
	if is_boss and _boss_relic != null:
		_relic_name_label.text = BossRelicSystemClass.get_relic_name(_boss_relic)
		_relic_desc_label.text = BossRelicSystemClass.get_relic_description(_boss_relic)

	_refresh_deck_card_list()


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

	var root_split := HSplitContainer.new()
	root_split.size_flags_horizontal = SIZE_EXPAND_FILL
	root_split.size_flags_vertical = SIZE_EXPAND_FILL
	root_split.add_theme_constant_override("separation", 16)
	outer_margin.add_child(root_split)

	# Left column — run status + buttons
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = SIZE_EXPAND_FILL
	left_col.size_flags_vertical = SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 16)
	root_split.add_child(left_col)

	var left_center := CenterContainer.new()
	left_center.size_flags_horizontal = SIZE_EXPAND_FILL
	left_center.size_flags_vertical = SIZE_EXPAND_FILL
	left_col.add_child(left_center)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(400, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	status_panel.add_theme_stylebox_override("panel", panel_style)
	left_center.add_child(status_panel)

	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 16)
	status_panel.add_child(status_vbox)

	# Title
	var title := Label.new()
	title.text = "Arena Run"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	status_vbox.add_child(title)

	# Win/Loss record
	var record_row := HBoxContainer.new()
	record_row.alignment = BoxContainer.ALIGNMENT_CENTER
	record_row.add_theme_constant_override("separation", 32)
	status_vbox.add_child(record_row)

	_wins_label = Label.new()
	_wins_label.text = "Wins: 0"
	_wins_label.add_theme_font_size_override("font_size", 22)
	_wins_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
	record_row.add_child(_wins_label)

	_losses_label = Label.new()
	_losses_label.text = "Losses: 0"
	_losses_label.add_theme_font_size_override("font_size", 22)
	_losses_label.add_theme_color_override("font_color", Color(0.84, 0.39, 0.31, 1.0))
	record_row.add_child(_losses_label)

	# Match number
	_match_label = Label.new()
	_match_label.text = "Next Match: 1 of 9"
	_match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_label.add_theme_font_size_override("font_size", 20)
	status_vbox.add_child(_match_label)

	# Boss relic indicator (hidden by default)
	_boss_indicator = VBoxContainer.new()
	_boss_indicator.add_theme_constant_override("separation", 8)
	_boss_indicator.visible = false
	status_vbox.add_child(_boss_indicator)

	var relic_divider := HSeparator.new()
	_boss_indicator.add_child(relic_divider)

	_relic_name_label = Label.new()
	_relic_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_name_label.add_theme_font_size_override("font_size", 20)
	_relic_name_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38, 1.0))
	_boss_indicator.add_child(_relic_name_label)

	_relic_desc_label = Label.new()
	_relic_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_desc_label.add_theme_font_size_override("font_size", 16)
	_relic_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	_relic_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_indicator.add_child(_relic_desc_label)

	# Buttons
	var button_spacer := Control.new()
	button_spacer.custom_minimum_size = Vector2(0, 8)
	status_vbox.add_child(button_spacer)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	status_vbox.add_child(button_row)

	var fight_button := Button.new()
	fight_button.text = "Fight"
	fight_button.custom_minimum_size = Vector2(160, 48)
	fight_button.pressed.connect(func() -> void: fight_pressed.emit())
	button_row.add_child(fight_button)

	var abandon_button := Button.new()
	abandon_button.text = "Abandon Run"
	abandon_button.custom_minimum_size = Vector2(160, 48)
	abandon_button.pressed.connect(_show_abandon_confirm)
	button_row.add_child(abandon_button)

	# Right column — compact deck list
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = SIZE_EXPAND_FILL
	right_col.size_flags_vertical = SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 12)
	right_col.custom_minimum_size = Vector2(250, 0)
	root_split.add_child(right_col)

	var deck_header := Label.new()
	deck_header.text = "Deck"
	deck_header.add_theme_font_size_override("font_size", 20)
	deck_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(deck_header)

	var deck_scroll := ScrollContainer.new()
	deck_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	deck_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right_col.add_child(deck_scroll)

	_deck_card_list_container = VBoxContainer.new()
	_deck_card_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_deck_card_list_container.add_theme_constant_override("separation", 4)
	deck_scroll.add_child(_deck_card_list_container)


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
	row.custom_minimum_size = Vector2(0, 32)
	row.add_theme_constant_override("separation", 8)

	# Cost badge
	var cost_badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.set_corner_radius_all(14)
	badge_style.set_content_margin_all(0)
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	var cost_color := _get_card_cost_badge_color(entry.get("attributes", []))
	badge_style.bg_color = cost_color
	cost_badge.add_theme_stylebox_override("panel", badge_style)
	cost_badge.custom_minimum_size = Vector2(32, 28)
	var cost_label := Label.new()
	cost_label.text = str(entry["cost"])
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_label)
	row.add_child(cost_badge)

	# Card name
	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	# Quantity indicator
	var qty_label := Label.new()
	qty_label.text = "x%d" % entry["quantity"]
	qty_label.add_theme_font_size_override("font_size", 14)
	qty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	row.add_child(qty_label)

	return row


func _get_card_cost_badge_color(attributes: Array) -> Color:
	if attributes.size() == 1:
		return ATTRIBUTE_TINTS.get(str(attributes[0]), NEUTRAL_COST_COLOR)
	return NEUTRAL_COST_COLOR


# --- Abandon Confirmation Dialog ---

func _show_abandon_confirm() -> void:
	if _confirm_overlay != null:
		return

	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_confirm_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	_confirm_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 180)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	p_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(12)
	p_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var dialog_title := Label.new()
	dialog_title.text = "Abandon Run?"
	dialog_title.add_theme_font_size_override("font_size", 22)
	dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(dialog_title)

	var dialog_msg := Label.new()
	dialog_msg.text = "Your current run progress will be lost. This cannot be undone."
	dialog_msg.add_theme_font_size_override("font_size", 16)
	dialog_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(dialog_msg)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.pressed.connect(_dismiss_abandon_confirm)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Abandon"
	confirm_btn.custom_minimum_size = Vector2(120, 40)
	confirm_btn.pressed.connect(func() -> void:
		_dismiss_abandon_confirm()
		abandon_pressed.emit()
	)
	btn_row.add_child(confirm_btn)


func _dismiss_abandon_confirm() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
		_confirm_overlay = null


# --- Helpers ---

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
