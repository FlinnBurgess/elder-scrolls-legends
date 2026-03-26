class_name AdventureProgressionPathOverlay
extends Control

## Full-screen overlay showing a horizontal 30-node progression path for a deck.
## Nodes are connected by lines with XP progress fill between current and next level.

signal closed

const AdventureCardPoolScript = preload("res://src/adventure/adventure_card_pool.gd")
const AugmentCatalogScript = preload("res://src/adventure/augment_catalog.gd")

const MAX_LEVEL := 30

# Layout constants
const NODE_SIZE := 100.0
const NODE_SPACING := 140.0  # gap between node centers
const LINE_HEIGHT := 6.0
const TRACK_PADDING_Y := 40.0  # padding above and below the node row

# Colors
const COLOR_COMPLETED_BG := Color(0.2, 0.35, 0.2, 1.0)
const COLOR_COMPLETED_BORDER := Color(0.4, 0.75, 0.4, 1.0)
const COLOR_CURRENT_BG := Color(0.25, 0.3, 0.45, 1.0)
const COLOR_CURRENT_BORDER := Color(0.5, 0.7, 1.0, 1.0)
const COLOR_LOCKED_BG := Color(0.15, 0.15, 0.18, 1.0)
const COLOR_LOCKED_BORDER := Color(0.3, 0.3, 0.35, 1.0)
const COLOR_LINE_FILLED := Color(0.4, 0.75, 0.4, 1.0)
const COLOR_LINE_EMPTY := Color(0.25, 0.25, 0.3, 1.0)
const COLOR_LINE_PARTIAL := Color(0.35, 0.55, 0.7, 1.0)

# Reward type icons (unicode approximations)
const REWARD_ICONS := {
	"starting_gold": "G",  # gold
	"max_health": "+",      # health
	"reroll_tokens": "R",   # reroll
	"revives": "V",         # revive
	"card_swap": "S",       # swap
	"permanent_augment": "A", # augment
	"star_power": "*",       # star
	"relic_slot": "O",       # relic
}

const REWARD_ICON_COLORS := {
	"starting_gold": Color(0.92, 0.78, 0.2, 1.0),
	"max_health": Color(0.9, 0.3, 0.3, 1.0),
	"reroll_tokens": Color(0.3, 0.7, 0.9, 1.0),
	"revives": Color(0.5, 0.9, 0.5, 1.0),
	"card_swap": Color(0.8, 0.6, 0.2, 1.0),
	"permanent_augment": Color(0.4, 0.8, 0.4, 1.0),
	"star_power": Color(0.92, 0.78, 0.38, 1.0),
	"relic_slot": Color(0.5, 0.65, 0.9, 1.0),
}

var _deck_name: String = ""
var _current_level: int = 0
var _xp_progress: float = 0.0  # 0.0 - 1.0, progress into current level
var _reward_track: Array = []  # from deck progression JSON
var _star_powers: Array = []
var _star_power_levels: Array = [5, 15, 25]
var _relic_slot_levels: Array = [10, 20, 30]
var _card_lookup: Dictionary = {}

var _scroll_container: ScrollContainer
var _track_container: Control
var _tooltip: PanelContainer = null
var _bg_dimmer: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_card_catalog()
	_build_ui()


func set_progression_data(
	deck_name: String,
	current_level: int,
	xp_progress: float,
	reward_track: Array,
	star_powers: Array,
	star_power_levels: Array,
	relic_slot_levels: Array,
) -> void:
	_deck_name = deck_name
	_current_level = current_level
	_xp_progress = xp_progress
	_reward_track = reward_track
	_star_powers = star_powers
	_star_power_levels = star_power_levels
	_relic_slot_levels = relic_slot_levels
	_rebuild_track()
	_scroll_to_current_level()


func _build_ui() -> void:
	# Background dimmer - clicking it closes the overlay
	_bg_dimmer = ColorRect.new()
	_bg_dimmer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_bg_dimmer.color = Color(0.0, 0.0, 0.0, 0.7)
	_bg_dimmer.gui_input.connect(_on_bg_input)
	add_child(_bg_dimmer)

	# Main panel — 60% width, vertically centered
	var panel := PanelContainer.new()
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 0
	panel.offset_right = 0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Progression Path"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Scroll container for the horizontal track
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var track_height := NODE_SIZE + TRACK_PADDING_Y * 2.0
	_scroll_container.custom_minimum_size = Vector2(0, track_height)
	vbox.add_child(_scroll_container)
	# Hide the horizontal scrollbar (scrolling still works via mouse wheel/trackpad)
	var h_scrollbar := _scroll_container.get_h_scroll_bar()
	h_scrollbar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	h_scrollbar.add_theme_stylebox_override("scroll_focus", StyleBoxEmpty.new())
	h_scrollbar.add_theme_stylebox_override("grabber", StyleBoxEmpty.new())
	h_scrollbar.add_theme_stylebox_override("grabber_highlight", StyleBoxEmpty.new())
	h_scrollbar.add_theme_stylebox_override("grabber_pressed", StyleBoxEmpty.new())
	h_scrollbar.custom_minimum_size = Vector2(0, 0)

	_track_container = Control.new()
	_scroll_container.add_child(_track_container)


func _rebuild_track() -> void:
	# Clear existing nodes
	for child in _track_container.get_children():
		child.queue_free()

	# Build merged reward map: level -> reward info
	var reward_map := _build_reward_map()

	# Calculate track dimensions
	var track_width := NODE_SPACING * (MAX_LEVEL + 1)
	var track_height := NODE_SIZE + TRACK_PADDING_Y * 2.0
	_track_container.custom_minimum_size = Vector2(track_width, track_height)

	var center_y := track_height / 2.0

	# Draw connecting lines first (behind nodes)
	for i in range(MAX_LEVEL - 1):
		var level := i + 1
		var next_level := i + 2
		var x1 := NODE_SPACING * (level) + NODE_SIZE / 2.0
		var x2 := NODE_SPACING * (next_level) - NODE_SIZE / 2.0

		var line := ColorRect.new()
		line.position = Vector2(x1, center_y - LINE_HEIGHT / 2.0)
		line.size = Vector2(x2 - x1, LINE_HEIGHT)

		if level < _current_level:
			# Both ends completed
			line.color = COLOR_LINE_FILLED
		elif level == _current_level:
			# Partial fill - this is the line between current and next
			line.color = COLOR_LINE_EMPTY
			_track_container.add_child(line)
			# Add partial fill overlay
			var fill := ColorRect.new()
			fill.position = Vector2(x1, center_y - LINE_HEIGHT / 2.0)
			fill.size = Vector2((x2 - x1) * _xp_progress, LINE_HEIGHT)
			fill.color = COLOR_LINE_PARTIAL
			_track_container.add_child(fill)
			continue
		else:
			line.color = COLOR_LINE_EMPTY

		_track_container.add_child(line)

	# Draw nodes
	for i in range(MAX_LEVEL):
		var level := i + 1
		var x := NODE_SPACING * level - NODE_SIZE / 2.0
		var y := center_y - NODE_SIZE / 2.0

		var node_panel := PanelContainer.new()
		node_panel.position = Vector2(x, y)
		node_panel.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		node_panel.size = Vector2(NODE_SIZE, NODE_SIZE)

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(12)
		style.set_content_margin_all(8)
		style.set_border_width_all(3)

		if level == _current_level:
			style.bg_color = COLOR_CURRENT_BG
			style.border_color = COLOR_CURRENT_BORDER
		elif level < _current_level:
			style.bg_color = COLOR_COMPLETED_BG
			style.border_color = COLOR_COMPLETED_BORDER
		else:
			style.bg_color = COLOR_LOCKED_BG
			style.border_color = COLOR_LOCKED_BORDER

		node_panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 0)
		node_panel.add_child(vbox)

		# Level number
		var level_label := Label.new()
		level_label.text = str(level)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 18)
		if level == _current_level:
			level_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1.0))
		elif level < _current_level:
			level_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8, 1.0))
		else:
			level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		vbox.add_child(level_label)

		# Reward icon
		var reward_info: Dictionary = reward_map.get(level, {})
		if not reward_info.is_empty():
			var icon_label := Label.new()
			var reward_type: String = str(reward_info.get("type", ""))
			icon_label.text = REWARD_ICONS.get(reward_type, "?")
			icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_label.add_theme_font_size_override("font_size", 28)
			var icon_color: Color = REWARD_ICON_COLORS.get(reward_type, Color(0.6, 0.6, 0.6, 1.0))
			if level > _current_level:
				icon_color = icon_color.darkened(0.5)
			icon_label.add_theme_color_override("font_color", icon_color)
			vbox.add_child(icon_label)

		# Hover detection
		node_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		node_panel.mouse_entered.connect(_on_node_hover.bind(level, reward_info, node_panel))
		node_panel.mouse_exited.connect(_dismiss_tooltip)

		_track_container.add_child(node_panel)


func _build_reward_map() -> Dictionary:
	## Merges reward track, star powers, and relic slots into a single map: level -> info dict
	var reward_map := {}

	# Reward track entries
	for reward in _reward_track:
		var level := int(reward.get("level", 0))
		if level >= 1 and level <= MAX_LEVEL:
			reward_map[level] = reward.duplicate()

	# Star power levels (overlay on top — these take priority for the icon if they share a level)
	for i in range(_star_power_levels.size()):
		var level := int(_star_power_levels[i])
		var star_data: Dictionary = _star_powers[i] if i < _star_powers.size() else {}
		if reward_map.has(level):
			# Level has both a reward track entry and a star power — store both
			reward_map[level]["star_power"] = star_data
		else:
			reward_map[level] = {"type": "star_power", "star_power": star_data}

	# Relic slot levels
	for level_val in _relic_slot_levels:
		var level := int(level_val)
		if reward_map.has(level):
			reward_map[level]["relic_slot"] = true
		else:
			reward_map[level] = {"type": "relic_slot", "relic_slot": true}

	return reward_map


func _on_node_hover(level: int, reward_info: Dictionary, node_panel: PanelContainer) -> void:
	_dismiss_tooltip()

	var lines: Array = []
	lines.append("Level %d" % level)

	if level == _current_level:
		lines.append("[Current Level]")
	elif level < _current_level:
		lines.append("[Completed]")

	# Reward track description
	var reward_type := str(reward_info.get("type", ""))
	match reward_type:
		"starting_gold":
			lines.append("+%d Starting Gold" % int(reward_info.get("value", 0)))
		"max_health":
			lines.append("+%d Max Health" % int(reward_info.get("value", 0)))
		"reroll_tokens":
			lines.append("+%d Reroll Token(s)" % int(reward_info.get("value", 0)))
		"revives":
			lines.append("+%d Revive(s)" % int(reward_info.get("value", 0)))
		"card_swap":
			var remove_name := _get_card_name(str(reward_info.get("remove", "")))
			var add_name := _get_card_name(str(reward_info.get("add", "")))
			lines.append("Card Swap: %s -> %s" % [remove_name, add_name])
		"permanent_augment":
			var card_name := _get_card_name(str(reward_info.get("card_id", "")))
			var augment := AugmentCatalogScript.get_augment(str(reward_info.get("augment_id", "")))
			var aug_name := str(augment.get("name", str(reward_info.get("augment_id", ""))))
			lines.append("Augment: %s gets %s" % [card_name, aug_name])
		"star_power":
			pass  # handled below
		"relic_slot":
			pass  # handled below

	# Star power info
	if reward_info.has("star_power"):
		var sp: Dictionary = reward_info.get("star_power", {})
		if not sp.is_empty():
			lines.append("Star Power: %s" % str(sp.get("name", "Unknown")))
			lines.append(str(sp.get("description", "")))

	# Relic slot info
	if reward_info.get("relic_slot", false):
		lines.append("Relic Slot Unlocked!")

	if reward_info.is_empty():
		lines.append("No reward at this level")

	_show_tooltip(lines, node_panel)


func _show_tooltip(lines: Array, anchor: Control) -> void:
	_tooltip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	_tooltip.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_tooltip.add_child(vbox)

	for i in range(lines.size()):
		var label := Label.new()
		label.text = lines[i]
		if i == 0:
			label.add_theme_font_size_override("font_size", 16)
		else:
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(200, 0)
		vbox.add_child(label)

	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position tooltip above the node
	add_child(_tooltip)
	# We need to wait a frame for the tooltip to calculate its size
	await get_tree().process_frame
	if _tooltip == null:
		return
	var node_global_pos := anchor.global_position
	var tooltip_size := _tooltip.size
	var x_pos := node_global_pos.x + anchor.size.x / 2.0 - tooltip_size.x / 2.0
	var y_pos := node_global_pos.y - tooltip_size.y - 8.0
	# Clamp to screen
	x_pos = clampf(x_pos, 8.0, get_viewport_rect().size.x - tooltip_size.x - 8.0)
	if y_pos < 8.0:
		y_pos = node_global_pos.y + anchor.size.y + 8.0
	_tooltip.global_position = Vector2(x_pos, y_pos)


func _dismiss_tooltip() -> void:
	if _tooltip != null:
		_tooltip.queue_free()
		_tooltip = null


func _scroll_to_current_level() -> void:
	# Wait for layout to settle
	await get_tree().process_frame
	await get_tree().process_frame
	var target_level := mini(_current_level + 1, MAX_LEVEL)
	var target_x := NODE_SPACING * target_level
	var visible_width := _scroll_container.size.x
	var scroll_x := target_x - visible_width / 2.0
	_scroll_container.scroll_horizontal = int(maxf(0.0, scroll_x))


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()


func _get_card_name(card_id: String) -> String:
	var card: Dictionary = _card_lookup.get(card_id, {})
	if not card.is_empty():
		return str(card.get("name", card_id))
	return card_id


func _load_card_catalog() -> void:
	var catalog := AdventureCardPoolScript._load_catalog()
	var all_cards: Array = catalog.get("cards", [])
	for card in all_cards:
		_card_lookup[str(card.get("card_id", ""))] = card
