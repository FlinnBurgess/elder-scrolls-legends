class_name AdventureResultScreen
extends Control

signal return_pressed

var _is_built := false
var _won := false
var _adventure_name := ""
var _result_data: Dictionary = {}
var _title_label: Label
var _subtitle_label: Label
var _xp_label: Label
var _level_label: Label
var _rewards_container: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


func set_result(won: bool, adventure_name: String, result_data: Dictionary = {}) -> void:
	_won = won
	_adventure_name = adventure_name
	_result_data = result_data
	_refresh()


func _refresh() -> void:
	if not _is_built:
		return
	if _won:
		_title_label.text = "Victory!"
		_title_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38, 1.0))
	else:
		_title_label.text = "Defeat"
		_title_label.add_theme_color_override("font_color", Color(0.84, 0.39, 0.31, 1.0))
	_subtitle_label.text = _adventure_name

	# XP info
	var xp := int(_result_data.get("xp_earned", 0))
	_xp_label.text = "+%d XP" % xp if xp > 0 else "No XP earned"
	_xp_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0, 1.0) if xp > 0 else Color(0.5, 0.5, 0.5, 1.0))

	# Level info
	var level_result: Dictionary = _result_data.get("level_result", {})
	var old_level := int(level_result.get("old_level", 0))
	var new_level := int(level_result.get("new_level", 0))
	if new_level > old_level:
		_level_label.text = "Level Up! %d -> %d" % [old_level, new_level]
		_level_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38, 1.0))
		_level_label.visible = true
	else:
		_level_label.visible = false

	# Rewards
	_clear_children(_rewards_container)
	var rewards: Array = level_result.get("rewards", [])
	for reward in rewards:
		_rewards_container.add_child(_build_reward_line(reward))

	var new_stars: Array = level_result.get("new_star_powers", [])
	for sp in new_stars:
		var line := Label.new()
		line.text = "Star Power: %s" % str(sp.get("name", ""))
		line.add_theme_font_size_override("font_size", 14)
		line.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38, 1.0))
		_rewards_container.add_child(line)

	var new_slots := int(level_result.get("new_relic_slots", 0))
	if new_slots > 0:
		var line := Label.new()
		line.text = "Relic Slot Unlocked!"
		line.add_theme_font_size_override("font_size", 14)
		line.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
		_rewards_container.add_child(line)

	# Completion rewards
	var completion: Dictionary = _result_data.get("completion_rewards", {})
	var first_reward = completion.get("first_clear_reward")
	if first_reward != null and typeof(first_reward) == TYPE_DICTIONARY:
		var line := Label.new()
		line.text = "First Clear: %s" % _describe_completion_reward(first_reward)
		line.add_theme_font_size_override("font_size", 14)
		line.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1.0))
		_rewards_container.add_child(line)
	var bonus_reward = completion.get("bonus_reward")
	if bonus_reward != null and typeof(bonus_reward) == TYPE_DICTIONARY:
		var line := Label.new()
		line.text = "Bonus: %s" % _describe_completion_reward(bonus_reward)
		line.add_theme_font_size_override("font_size", 14)
		line.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1.0))
		_rewards_container.add_child(line)


func _build_reward_line(reward: Dictionary) -> Label:
	var line := Label.new()
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	var reward_type := str(reward.get("type", ""))
	match reward_type:
		"starting_gold":
			line.text = "+%d starting gold" % int(reward.get("value", 0))
		"max_health":
			line.text = "+%d max health" % int(reward.get("value", 0))
		"reroll_tokens":
			line.text = "+%d reroll token(s)" % int(reward.get("value", 0))
		"revives":
			line.text = "+%d revive(s)" % int(reward.get("value", 0))
		"card_swap":
			line.text = "Card upgraded"
		"permanent_augment":
			line.text = "Card augmented"
		_:
			line.text = "Reward: %s" % reward_type
	return line


func _describe_completion_reward(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", ""))
	match reward_type:
		"relic":
			return "Relic unlocked!"
		"gold_bonus":
			return "+%d gold" % int(reward.get("amount", 0))
		_:
			return reward_type


func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 350)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Victory!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = ""
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	vbox.add_child(_subtitle_label)

	# XP earned
	_xp_label = Label.new()
	_xp_label.text = ""
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_xp_label)

	# Level up
	_level_label = Label.new()
	_level_label.text = ""
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.visible = false
	vbox.add_child(_level_label)

	# Rewards list
	var rewards_scroll := ScrollContainer.new()
	rewards_scroll.custom_minimum_size = Vector2(0, 100)
	rewards_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	rewards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(rewards_scroll)

	_rewards_container = VBoxContainer.new()
	_rewards_container.add_theme_constant_override("separation", 4)
	_rewards_container.size_flags_horizontal = SIZE_EXPAND_FILL
	rewards_scroll.add_child(_rewards_container)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var return_btn := Button.new()
	return_btn.text = "Continue"
	return_btn.custom_minimum_size = Vector2(240, 48)
	return_btn.pressed.connect(func() -> void: return_pressed.emit())
	btn_row.add_child(return_btn)


func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()
