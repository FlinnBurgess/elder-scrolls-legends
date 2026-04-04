class_name ArenaRunStatusScreen
extends Control

signal fight_pressed
signal abandon_pressed

const BossRelicSystemClass = preload("res://src/arena/boss_relic_system.gd")
const DeckCardListClass = preload("res://src/ui/components/deck_card_list.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")

# Run data
var _wins: int = 0
var _losses: int = 0
var _current_match: int = 1
var _boss_relic = null  # BossRelic enum value or null
var _deck: Array = []  # Array of {card_id, quantity}
var _card_database: Dictionary = {}

# UI references
var _is_built := false
var _root_split: HSplitContainer
var _wins_label: Label
var _losses_label: Label
var _match_label: Label
var _boss_indicator: VBoxContainer
var _relic_name_label: Label
var _relic_desc_label: Label
var _deck_card_list: DeckCardList
var _card_hover_preview_layer: Control
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
	_root_split.add_theme_constant_override("separation", 24)
	_root_split.resized.connect(_on_root_split_resized)
	outer_margin.add_child(_root_split)

	# Left column — run status + buttons
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = SIZE_EXPAND_FILL
	left_col.size_flags_vertical = SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 16)
	_root_split.add_child(left_col)

	var left_center := CenterContainer.new()
	left_center.size_flags_horizontal = SIZE_EXPAND_FILL
	left_center.size_flags_vertical = SIZE_EXPAND_FILL
	left_col.add_child(left_center)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(420, 0)
	UITheme.style_panel(status_panel)
	left_center.add_child(status_panel)

	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 20)
	status_panel.add_child(status_vbox)

	# Title
	var title := Label.new()
	title.text = "Arena Run"
	UITheme.style_title(title, 32)
	status_vbox.add_child(title)

	status_vbox.add_child(UITheme.make_separator(0.0))

	# Win/Loss record
	var record_row := HBoxContainer.new()
	record_row.alignment = BoxContainer.ALIGNMENT_CENTER
	record_row.add_theme_constant_override("separation", 40)
	status_vbox.add_child(record_row)

	_wins_label = Label.new()
	_wins_label.text = "Wins: 0"
	_wins_label.add_theme_font_size_override("font_size", 24)
	_wins_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
	record_row.add_child(_wins_label)

	_losses_label = Label.new()
	_losses_label.text = "Losses: 0"
	_losses_label.add_theme_font_size_override("font_size", 24)
	_losses_label.add_theme_color_override("font_color", Color(0.84, 0.39, 0.31, 1.0))
	record_row.add_child(_losses_label)

	# Match number
	_match_label = Label.new()
	_match_label.text = "Next Match: 1 of 9"
	_match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_label.add_theme_font_size_override("font_size", 22)
	_match_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	status_vbox.add_child(_match_label)

	# Boss relic indicator (hidden by default)
	_boss_indicator = VBoxContainer.new()
	_boss_indicator.add_theme_constant_override("separation", 8)
	_boss_indicator.visible = false
	status_vbox.add_child(_boss_indicator)

	_boss_indicator.add_child(UITheme.make_separator(0.0))

	_relic_name_label = Label.new()
	_relic_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_name_label.add_theme_font_size_override("font_size", 22)
	_relic_name_label.add_theme_color_override("font_color", UITheme.GOLD)
	_boss_indicator.add_child(_relic_name_label)

	_relic_desc_label = Label.new()
	_relic_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_desc_label.add_theme_font_size_override("font_size", 18)
	_relic_desc_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_relic_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_indicator.add_child(_relic_desc_label)

	# Buttons
	var button_spacer := Control.new()
	button_spacer.custom_minimum_size = Vector2(0, 4)
	status_vbox.add_child(button_spacer)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	status_vbox.add_child(button_row)

	var fight_button := Button.new()
	fight_button.text = "Fight"
	fight_button.custom_minimum_size = Vector2(180, 56)
	UITheme.style_button(fight_button, 22)
	fight_button.pressed.connect(func() -> void: fight_pressed.emit())
	button_row.add_child(fight_button)

	var abandon_button := Button.new()
	abandon_button.text = "Abandon Run"
	abandon_button.custom_minimum_size = Vector2(180, 56)
	UITheme.style_button_accent(abandon_button, Color(0.84, 0.39, 0.31, 1.0), 22)
	abandon_button.pressed.connect(_show_abandon_confirm)
	button_row.add_child(abandon_button)

	# Right column — deck list (narrower, matching draft screen proportions)
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = SIZE_EXPAND_FILL
	right_col.size_flags_vertical = SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 12)
	_root_split.add_child(right_col)

	var deck_header := Label.new()
	deck_header.text = "Deck"
	UITheme.style_title(deck_header, 24)
	right_col.add_child(deck_header)

	right_col.add_child(UITheme.make_separator(0.0))

	_deck_card_list = DeckCardListClass.new()
	var deck_scroll := _deck_card_list.create_scroll_container()
	right_col.add_child(deck_scroll)

	# Card hover preview layer (overlay on top of everything)
	_card_hover_preview_layer = Control.new()
	_card_hover_preview_layer.name = "CardHoverPreviewLayer"
	_card_hover_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_hover_preview_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_card_hover_preview_layer)

	_on_root_split_resized.call_deferred()


func _on_root_split_resized() -> void:
	if _root_split == null or _root_split.size.x <= 0:
		return
	var target := int(_root_split.size.x * 0.3)
	if _root_split.split_offset == target:
		return
	_root_split.resized.disconnect(_on_root_split_resized)
	_root_split.split_offset = target
	_root_split.resized.connect(_on_root_split_resized)


func _refresh_deck_card_list() -> void:
	if _deck_card_list == null:
		return
	if _card_hover_preview_layer != null and not _card_database.is_empty():
		_deck_card_list.enable_hover_preview(_card_hover_preview_layer, _card_database)
	_deck_card_list.set_deck(_deck, _card_database)


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
	panel.custom_minimum_size = Vector2(440, 200)
	UITheme.style_panel(panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var dialog_title := Label.new()
	dialog_title.text = "Abandon Run?"
	UITheme.style_title(dialog_title, 24)
	vbox.add_child(dialog_title)

	var dialog_msg := Label.new()
	dialog_msg.text = "Your current run progress will be lost. This cannot be undone."
	dialog_msg.add_theme_font_size_override("font_size", 18)
	dialog_msg.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
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
	cancel_btn.custom_minimum_size = Vector2(140, 48)
	UITheme.style_button(cancel_btn, 20, true)
	cancel_btn.pressed.connect(_dismiss_abandon_confirm)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Abandon"
	confirm_btn.custom_minimum_size = Vector2(140, 48)
	UITheme.style_button_accent(confirm_btn, Color(0.84, 0.39, 0.31, 1.0), 20)
	confirm_btn.pressed.connect(func() -> void:
		_dismiss_abandon_confirm()
		abandon_pressed.emit()
	)
	btn_row.add_child(confirm_btn)


func _dismiss_abandon_confirm() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
