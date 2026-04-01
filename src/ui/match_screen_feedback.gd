class_name MatchScreenFeedback
extends RefCounted

var _screen  # MatchScreen reference
var _overdraw_queue: Array = []


const PRESET_FULL_RECT = Control.PRESET_FULL_RECT
const PRESET_TOP_LEFT = Control.PRESET_TOP_LEFT
const PRESET_TOP_RIGHT = Control.PRESET_TOP_RIGHT
const PRESET_BOTTOM_LEFT = Control.PRESET_BOTTOM_LEFT
const PRESET_BOTTOM_RIGHT = Control.PRESET_BOTTOM_RIGHT
const PRESET_CENTER_TOP = Control.PRESET_CENTER_TOP
const PRESET_CENTER_BOTTOM = Control.PRESET_CENTER_BOTTOM
const PRESET_CENTER = Control.PRESET_CENTER
const SIZE_EXPAND_FILL = Control.SIZE_EXPAND_FILL
const SIZE_SHRINK_CENTER = Control.SIZE_SHRINK_CENTER
const SIZE_SHRINK_END = Control.SIZE_SHRINK_END
const SIZE_FILL = Control.SIZE_FILL

func _init(screen) -> void:
	_screen = screen


func _apply_presentation_feedback() -> void:
	_clear_feedback_overlays()
	for feedback in _screen._attack_feedbacks:
		_apply_attack_feedback(feedback)
	for feedback in _screen._damage_feedbacks:
		_apply_damage_feedback(feedback)
	# Removal feedbacks (red lane flash) intentionally skipped
	for feedback in _screen._draw_feedbacks:
		_apply_draw_feedback(feedback)
	for feedback in _screen._rune_feedbacks:
		_apply_rune_feedback(feedback)


func _clear_feedback_overlays() -> void:
	for section in _screen._player_sections.values():
		_clear_feedback_children(section.get("avatar_component"))
		_clear_feedback_children(section.get("hand_row"))
	for row_panel in _screen._lane_row_panels.values():
		_clear_feedback_children(row_panel)


func _clear_feedback_children(node) -> void:
	if not (node is Node):
		return
	for child in (node as Node).get_children():
		if str(child.name).begins_with("feedback_"):
			child.queue_free()
		else:
			_clear_feedback_children(child)


func _apply_attack_feedback(feedback: Dictionary) -> void:
	var attacker_button: Button = _screen._card_buttons.get(str(feedback.get("attacker_instance_id", "")))
	if attacker_button != null:
		_animate_card_motion(attacker_button, _attack_offset_for_player(str(feedback.get("attacker_player_id", ""))), 1.04)
		_screen._animations._add_feedback_banner(attacker_button, "feedback_attack_%s" % str(feedback.get("feedback_id", "0")), "ATTACK", Color(0.36, 0.2, 0.09, 0.98), Color(0.98, 0.78, 0.42, 1.0), Color(1.0, 0.96, 0.87, 1.0), 8.0)
	if str(feedback.get("target_type", "")) == _screen.MatchCombat.TARGET_TYPE_CREATURE:
		var defender_button: Button = _screen._card_buttons.get(str(feedback.get("target_instance_id", "")))
		if defender_button != null:
			_animate_card_motion(defender_button, _attack_offset_for_player(str(feedback.get("attacker_player_id", ""))) * -0.38, 1.02)
			_screen._animations._add_feedback_banner(defender_button, "feedback_block_%s" % str(feedback.get("feedback_id", "0")), "BLOCK", Color(0.18, 0.18, 0.24, 0.98), Color(0.76, 0.82, 0.96, 0.96), Color(0.96, 0.98, 1.0, 1.0), 8.0)


func _apply_damage_feedback(feedback: Dictionary) -> void:
	var target_kind := str(feedback.get("target_kind", ""))
	if target_kind == _screen.MatchCombat.TARGET_TYPE_CREATURE:
		var target_button: Button = _screen._card_buttons.get(str(feedback.get("target_instance_id", "")))
		if target_button != null:
			_screen._animations._add_feedback_popup(target_button, "feedback_damage_%s" % str(feedback.get("feedback_id", "0")), str(feedback.get("text", "-0")), feedback.get("color", Color(1, 1, 1, 1)), 10.0 + float(feedback.get("stack_index", 0)) * 18.0)
	elif target_kind == _screen.MatchCombat.TARGET_TYPE_PLAYER:
		var section: Dictionary = _screen._player_sections.get(str(feedback.get("target_player_id", "")), {})
		var avatar: Control = section.get("avatar_component")
		if avatar != null:
			_screen._animations._add_feedback_popup(avatar, "feedback_damage_%s" % str(feedback.get("feedback_id", "0")), str(feedback.get("text", "-0")), feedback.get("color", Color(1, 1, 1, 1)), 12.0 + float(feedback.get("stack_index", 0)) * 18.0)


func _apply_removal_feedback(feedback: Dictionary) -> void:
	var row_key = _screen._lane_row_key(str(feedback.get("lane_id", "")), str(feedback.get("player_id", "")))
	var row_panel: PanelContainer = _screen._lane_row_panels.get(row_key)
	if row_panel == null:
		return
	var toast := PanelContainer.new()
	toast.name = "feedback_removal_%s" % str(feedback.get("feedback_id", "0"))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_right = 1.0
	toast.offset_left = 14
	toast.offset_right = -14
	toast.offset_top = 42.0 + float(feedback.get("stack_index", 0)) * 24.0
	toast.offset_bottom = toast.offset_top + 24.0
	toast.z_index = 20
	_screen._apply_panel_style(toast, Color(0.32, 0.12, 0.12, 0.96), Color(0.96, 0.55, 0.46, 0.98), 1, 6)
	row_panel.add_child(toast)
	var toast_box = _screen._build_panel_box(toast, 0, 4)
	var toast_label := Label.new()
	toast_label.name = "%s_label" % toast.name
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 11)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.92, 1.0))
	toast_label.text = str(feedback.get("text", "Creature removed"))
	toast_box.add_child(toast_label)
	var tween = _screen.create_tween()
	tween.tween_property(toast, "position", Vector2(0, -14), 0.2)
	tween.parallel().tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.8)
	tween.finished.connect(_screen._queue_free_weak.bind(weakref(toast)))


func _apply_draw_feedback(feedback: Dictionary) -> void:
	var player_id := str(feedback.get("player_id", ""))
	var section: Dictionary = _screen._player_sections.get(player_id, {})
	var avatar: Control = section.get("avatar_component")
	if avatar != null:
		_screen._animations._add_feedback_popup(avatar, "feedback_draw_popup_%s" % str(feedback.get("feedback_id", "0")), _draw_feedback_popup_text(feedback), _draw_feedback_popup_color(feedback), 14.0 + float(feedback.get("stack_index", 0)) * 18.0)
	var hand_row: Control = section.get("hand_row")
	if hand_row != null:
		_add_feedback_toast(hand_row, "feedback_draw_toast_%s" % str(feedback.get("feedback_id", "0")), _draw_feedback_toast_text(feedback), _draw_feedback_toast_fill(feedback), _draw_feedback_toast_border(feedback), Color(1.0, 0.97, 0.93, 1.0), 10.0 + float(feedback.get("stack_index", 0)) * 24.0)
	var drawn_instance_id := str(feedback.get("drawn_instance_id", ""))
	var card_button: Button = _screen._card_buttons.get(drawn_instance_id)
	if card_button != null:
		_screen._animations._add_feedback_banner(card_button, "feedback_draw_banner_%s" % str(feedback.get("feedback_id", "0")), _screen._draw_feedback_badge_text(feedback), _draw_feedback_toast_fill(feedback), _draw_feedback_toast_border(feedback), Color(1.0, 0.97, 0.92, 1.0), 8.0)


func _apply_rune_feedback(feedback: Dictionary) -> void:
	var player_id := str(feedback.get("player_id", ""))
	var section: Dictionary = _screen._player_sections.get(player_id, {})
	var avatar_component = section.get("avatar_component")
	if avatar_component != null:
		_add_feedback_toast(avatar_component, "feedback_rune_toast_%s" % str(feedback.get("feedback_id", "0")), _rune_feedback_toast_text(feedback), Color(0.31, 0.13, 0.11, 0.98), Color(1.0, 0.73, 0.42, 1.0), Color(1.0, 0.95, 0.89, 1.0), 8.0 + float(feedback.get("stack_index", 0)) * 22.0)
		var token_panel = avatar_component.get_rune_anchor(int(feedback.get("threshold", -1)))
		if token_panel is Control:
			_screen._animations._add_feedback_banner_over_target(avatar_component as Control, token_panel as Control, "feedback_rune_banner_%s" % str(feedback.get("feedback_id", "0")), "SHATTER", Color(0.39, 0.14, 0.09, 0.99), Color(1.0, 0.78, 0.48, 1.0), Color(1.0, 0.96, 0.9, 1.0), 4.0)


func _process_overdraw_queue() -> void:
	if _overdraw_queue.is_empty():
		return
	var entry: Dictionary = _overdraw_queue.pop_front()
	_animate_overdraw_card(entry.get("card", {}), str(entry.get("player_id", "")))


func _animate_overdraw_card(card: Dictionary, player_id: String) -> void:
	if card.is_empty() or _screen._prophecy_card_overlay == null:
		if not _overdraw_queue.is_empty():
			_process_overdraw_queue()
		return

	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size
	var is_local: bool = player_id == _screen.PLAYER_ORDER[1]

	# Build a card display container
	var card_panel := PanelContainer.new()
	card_panel.name = "overdraw_card"
	card_panel.custom_minimum_size = card_size
	card_panel.size = card_size
	_screen._apply_panel_style(card_panel, Color(0.12, 0.10, 0.10, 0.98), Color(0.55, 0.18, 0.18, 0.92), 2, 0)

	var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	card_panel.add_child(component)

	# Position just above the player's hand area (bottom-center)
	var pos_x: float = (viewport_size.x - card_size.x) * 0.5
	var base_y: float
	if is_local:
		base_y = viewport_size.y - card_size.y - card_size.y * 0.35
	else:
		base_y = card_size.y * 0.10
	card_panel.position = Vector2(pos_x, base_y)
	card_panel.pivot_offset = Vector2(card_size.x * 0.5, card_size.y * 0.5)
	card_panel.scale = Vector2(0.7, 0.7)
	card_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card_panel.z_index = 500
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_screen._prophecy_card_overlay.add_child(card_panel)

	# Animate: fade in + scale up, hold, then fall off-screen with rotation
	var tween = _screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_panel, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_panel, "modulate:a", 1.0, 0.3)
	tween.set_parallel(false)
	tween.tween_interval(1.2)
	# Fall off bottom with rotation
	var fall_target_y: float = viewport_size.y + card_size.y
	var rotation_dir := 1.0 if fmod(abs(card_panel.position.x), 2.0) > 1.0 else -1.0
	tween.set_parallel(true)
	tween.tween_property(card_panel, "position:y", fall_target_y, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_panel, "rotation_degrees", rotation_dir * 25.0, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_panel, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(func():
		card_panel.queue_free()
		# Process next queued overdraw if any
		if not _overdraw_queue.is_empty():
			_process_overdraw_queue()
	)


func _apply_card_feedback_decoration(button: Button, card: Dictionary, surface: String) -> void:
	var instance_id := str(card.get("instance_id", ""))
	var modulate_color := Color(1, 1, 1, 1)
	var applied_damage := false
	if surface == "lane" and str(card.get("card_type", "")) == "creature":
		for feedback in _screen._damage_feedbacks:
			if str(feedback.get("target_kind", "")) == _screen.MatchCombat.TARGET_TYPE_CREATURE and str(feedback.get("target_instance_id", "")) == instance_id:
				modulate_color = Color(1.0, 0.92, 0.92, 1.0)
				applied_damage = true
				break
	if surface == "hand":
		pass
	button.modulate = modulate_color


func _refresh_avatar_target_glow(avatar: Control, player_id: String) -> void:
	var existing := avatar.find_child("avatar_target_glow", false, false)
	if existing != null:
		avatar.remove_child(existing)
		existing.queue_free()
	var valid_ids = _screen._valid_player_target_ids()
	if not valid_ids.has(player_id):
		return
	var glow_shader := load("res://assets/shaders/avatar_target_glow.gdshader") as Shader
	if glow_shader == null:
		return
	var glow_pad := 20.0
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_shader
	var glow := ColorRect.new()
	glow.name = "avatar_target_glow"
	glow.material = glow_mat
	glow.color = Color.WHITE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -glow_pad
	glow.offset_top = -glow_pad
	glow.offset_right = glow_pad
	glow.offset_bottom = glow_pad
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.clip_contents = false
	avatar.add_child(glow)
	avatar.move_child(glow, 0)


func _apply_valid_target_glow(button: Button, surface: String) -> void:
	var glow_shader := load("res://assets/shaders/valid_target_glow.gdshader") as Shader
	if glow_shader == null:
		return
	var card_size = _screen._surface_button_minimum_size(surface)
	var glow_pad := 16.0
	var total_size: Vector2 = card_size + Vector2(glow_pad * 2.0, glow_pad * 2.0)
	var padding_uv := Vector2(glow_pad / total_size.x, glow_pad / total_size.y)
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_shader
	glow_mat.set_shader_parameter("glow_color", Color(0.9, 0.92, 0.95, 1.0))
	glow_mat.set_shader_parameter("pulse_speed", 1.8)
	glow_mat.set_shader_parameter("glow_intensity", 0.28)
	glow_mat.set_shader_parameter("corner_radius", 0.04)
	glow_mat.set_shader_parameter("padding_uv", padding_uv)
	var glow := ColorRect.new()
	glow.name = "valid_target_glow"
	glow.material = glow_mat
	glow.color = Color.WHITE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -glow_pad
	glow.offset_top = -glow_pad
	glow.offset_right = glow_pad
	glow.offset_bottom = glow_pad
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.clip_contents = false
	button.add_child(glow)
	button.move_child(glow, 0)


func _apply_betray_target_glow(button: Button, surface: String) -> void:
	var glow_shader := load("res://assets/shaders/valid_target_glow.gdshader") as Shader
	if glow_shader == null:
		return
	var card_size = _screen._surface_button_minimum_size(surface)
	var glow_pad := 16.0
	var total_size: Vector2 = card_size + Vector2(glow_pad * 2.0, glow_pad * 2.0)
	var padding_uv := Vector2(glow_pad / total_size.x, glow_pad / total_size.y)
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_shader
	glow_mat.set_shader_parameter("glow_color", Color(0.95, 0.2, 0.15, 1.0))
	glow_mat.set_shader_parameter("pulse_speed", 1.8)
	glow_mat.set_shader_parameter("glow_intensity", 0.35)
	glow_mat.set_shader_parameter("corner_radius", 0.04)
	glow_mat.set_shader_parameter("padding_uv", padding_uv)
	var glow := ColorRect.new()
	glow.name = "valid_target_glow"
	glow.material = glow_mat
	glow.color = Color.WHITE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -glow_pad
	glow.offset_top = -glow_pad
	glow.offset_right = glow_pad
	glow.offset_bottom = glow_pad
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.clip_contents = false
	button.add_child(glow)
	button.move_child(glow, 0)


func _apply_lane_card_float_effect(button: Button, card: Dictionary) -> void:
	var readiness = _screen._creature_readiness_state(card)
	var instance_id := str(card.get("instance_id", ""))
	if str(readiness.get("id", "")) != "ready":
		_screen._animations._floating_card_ids.erase(instance_id)
		return
	var content_root: Control = button.get_meta("content_root", null)
	if content_root == null:
		return
	button.clip_contents = false
	# Hide the button's own background so its border doesn't outline the shadow
	_screen._apply_button_style(button, Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	# Shader-based soft shadow to simulate an overhead light source
	var shadow_shader := load("res://assets/shaders/soft_shadow.gdshader") as Shader
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = shadow_shader
	shadow_mat.set_shader_parameter("blur_radius", 0.14)
	shadow_mat.set_shader_parameter("shadow_alpha", 0.82)
	var shadow := ColorRect.new()
	shadow.name = "float_shadow"
	shadow.material = shadow_mat
	shadow.color = Color.WHITE
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Pad the shadow rect so the blur has room to feather out beyond the card edges
	var shadow_pad := 10.0
	shadow.offset_left = _screen.LANE_CARD_FLOAT_SHADOW_OFFSET.x - shadow_pad
	shadow.offset_top = _screen.LANE_CARD_FLOAT_SHADOW_OFFSET.y - shadow_pad
	shadow.offset_right = _screen.LANE_CARD_FLOAT_SHADOW_OFFSET.x + shadow_pad
	shadow.offset_bottom = _screen.LANE_CARD_FLOAT_SHADOW_OFFSET.y + shadow_pad
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shadow)
	button.move_child(shadow, 0)
	# Float content up and to the left
	var already_floating = _screen._animations._floating_card_ids.has(instance_id)
	_screen._animations._floating_card_ids[instance_id] = true
	if already_floating:
		# Already floated on a prior refresh – snap to offset immediately
		content_root.offset_left = _screen.LANE_CARD_FLOAT_OFFSET.x
		content_root.offset_top = _screen.LANE_CARD_FLOAT_OFFSET.y
		content_root.offset_right = _screen.LANE_CARD_FLOAT_OFFSET.x
		content_root.offset_bottom = _screen.LANE_CARD_FLOAT_OFFSET.y
		shadow.modulate.a = 1.0
		_screen._card_display._start_lane_card_bob(button, content_root, shadow)
	else:
		# First time floating – animate the rise and shadow fade-in
		shadow.modulate.a = 0.0
		var tween: Tween = _screen.create_tween()
		tween.set_parallel(true)
		tween.tween_property(content_root, "offset_left", _screen.LANE_CARD_FLOAT_OFFSET.x, _screen.LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(content_root, "offset_top", _screen.LANE_CARD_FLOAT_OFFSET.y, _screen.LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(content_root, "offset_right", _screen.LANE_CARD_FLOAT_OFFSET.x, _screen.LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(content_root, "offset_bottom", _screen.LANE_CARD_FLOAT_OFFSET.y, _screen.LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(shadow, "modulate:a", 1.0, _screen.LANE_CARD_FLOAT_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.finished.connect(_screen._start_lane_card_bob.bind(button, content_root, shadow))


func _add_feedback_toast(container: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	var toast := PanelContainer.new()
	toast.name = name
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_right = 1.0
	toast.offset_left = 12
	toast.offset_right = -12
	toast.offset_top = top_offset
	toast.offset_bottom = top_offset + 24.0
	toast.z_index = 18
	_screen._apply_panel_style(toast, fill, border, 1, 7)
	container.add_child(toast)
	var box = _screen._build_panel_box(toast, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween = _screen.create_tween()
	tween.tween_interval(0.5)
	tween.parallel().tween_property(toast, "position", Vector2(0, -10), 0.26)
	tween.tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.75)
	tween.finished.connect(_screen._queue_free_weak.bind(weakref(toast)))


func _queue_status_toast(text: String, color: Color) -> void:
	var viewport_size = _screen.get_viewport_rect().size
	var label := Label.new()
	label.name = "feedback_status_toast"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 500
	label.set_anchors_preset(PRESET_CENTER_TOP)
	label.offset_top = viewport_size.y * 0.42
	label.offset_left = -200
	label.offset_right = 200
	_screen.add_child(label)
	var tween = _screen.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.3)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(_screen._queue_free_weak.bind(weakref(label)))


func _queue_creature_toast(instance_id: String, text: String, color: Color) -> void:
	var button: Button = _screen._card_buttons.get(instance_id)
	if button == null or not is_instance_valid(button):
		return
	_screen._animations._add_feedback_popup(button, "feedback_toast_%s" % instance_id, text, color, 10.0)


func _animate_treasure_hunt_reveal(revealed_card: Dictionary, matches: bool) -> void:
	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "treasure_hunt_reveal"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	var back_color := Color(0.35, 0.22, 0.12, 0.98)
	_screen._apply_panel_style(card_back, back_color, Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x: float = (viewport_size.x - card_size.x) * 0.5
	var pos_y: float = viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)
	card_back.z_index = 600

	_screen._prophecy_card_overlay.add_child(card_back)

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween = _screen.create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(revealed_card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_back.add_child(component)
		# Add match/miss banner
		var banner := Label.new()
		banner.name = "treasure_hunt_banner"
		banner.text = "MATCH!" if matches else "MISS"
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_theme_font_size_override("font_size", 20)
		banner.add_theme_color_override("font_color", Color(0.1, 1.0, 0.3) if matches else Color(0.9, 0.3, 0.2))
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.z_index = 10
		banner.anchor_right = 1.0
		banner.offset_top = card_size.y - 36.0
		banner.offset_bottom = card_size.y - 10.0
		card_back.add_child(banner)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(card_back, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func():
		if is_instance_valid(card_back):
			card_back.queue_free()
		_screen._refresh_ui()
	)


func _should_reveal_drawn_card(player_id: String, card: Dictionary) -> bool:
	if card.is_empty():
		return false
	if _screen._is_hand_public(player_id):
		return true
	return _screen._overlays._is_pending_prophecy_card(card)


func _active_draw_feedback_for_instance(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for feedback in _screen._draw_feedbacks:
		if str(feedback.get("drawn_instance_id", "")) == instance_id:
			return feedback
	return {}


func _draw_feedback_popup_text(feedback: Dictionary) -> String:
	if bool(feedback.get("show_card_name", false)):
		return "+ %s" % str(feedback.get("card_name", "Card"))
	return "+1 CARD"


func _draw_feedback_popup_color(feedback: Dictionary) -> Color:
	return Color(1.0, 0.81, 0.48, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.72, 0.91, 1.0, 1.0)


func _draw_feedback_toast_text(feedback: Dictionary) -> String:
	var prefix := "RUNE DRAW" if bool(feedback.get("from_rune_break", false)) else "DRAW"
	if bool(feedback.get("show_card_name", false)):
		return "%s • %s" % [prefix, str(feedback.get("card_name", "Card"))]
	return "%s • card added to hand" % prefix


func _draw_feedback_toast_fill(feedback: Dictionary) -> Color:
	return Color(0.32, 0.16, 0.09, 0.98) if bool(feedback.get("from_rune_break", false)) else Color(0.14, 0.22, 0.31, 0.98)


func _draw_feedback_toast_border(feedback: Dictionary) -> Color:
	return Color(1.0, 0.79, 0.46, 1.0) if bool(feedback.get("from_rune_break", false)) else Color(0.66, 0.9, 1.0, 1.0)


func _rune_feedback_toast_text(feedback: Dictionary) -> String:
	var threshold := int(feedback.get("threshold", -1))
	var draw_suffix := " • draw triggered" if bool(feedback.get("draw_card", false)) else ""
	if threshold > 0:
		return "RUNE %d SHATTERED%s" % [threshold, draw_suffix]
	return "RUNE BREAK%s" % draw_suffix


func _animate_card_motion(button: Button, offset: Vector2, end_scale: float) -> void:
	var content_variant = button.get_meta("content_root", null)
	if not (content_variant is Control):
		return
	var content := content_variant as Control
	content.pivot_offset = Vector2(button.custom_minimum_size.x * 0.5, button.custom_minimum_size.y * 0.5)
	content.position = Vector2.ZERO
	content.scale = Vector2.ONE
	var tween = _screen.create_tween()
	tween.tween_property(content, "position", offset, 0.11)
	tween.parallel().tween_property(content, "scale", Vector2(end_scale, end_scale), 0.11)
	tween.tween_property(content, "position", Vector2.ZERO, 0.16)
	tween.parallel().tween_property(content, "scale", Vector2.ONE, 0.16)


func _attack_offset_for_player(player_id: String) -> Vector2:
	return Vector2(0, 16) if player_id == _screen.PLAYER_ORDER[0] else Vector2(0, -16)


func _damage_target_key(event: Dictionary) -> String:
	var target_type := str(event.get("target_type", ""))
	if target_type == _screen.MatchCombat.TARGET_TYPE_PLAYER:
		return "player:%s" % str(event.get("target_player_id", ""))
	return "creature:%s" % str(event.get("target_instance_id", ""))


func _prune_feedback_state() -> void:
	var now := _feedback_now_ms()
	_screen._attack_feedbacks = _feedbacks_after(_screen._attack_feedbacks, now)
	_screen._damage_feedbacks = _feedbacks_after(_screen._damage_feedbacks, now)
	_screen._removal_feedbacks = _feedbacks_after(_screen._removal_feedbacks, now)
	_screen._draw_feedbacks = _feedbacks_after(_screen._draw_feedbacks, now)
	_screen._rune_feedbacks = _feedbacks_after(_screen._rune_feedbacks, now)


func _feedbacks_after(entries: Array, now: int) -> Array:
	var remaining: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if int(entry.get("expires_at_ms", 0)) > now:
			remaining.append(entry)
	return remaining


func _feedback_now_ms() -> int:
	return Time.get_ticks_msec()


func _next_feedback_id() -> int:
	_screen._animations._feedback_sequence += 1
	return _screen._animations._feedback_sequence


func _animate_enemy_prophecy_resolution(action: Dictionary, _result: Dictionary) -> void:
	var card_back: PanelContainer = _screen._overlays._prophecy_overlay_state.get("card_back")
	if card_back == null or not is_instance_valid(card_back):
		_screen._overlays._dismiss_prophecy_overlay()
		_screen._refresh_ui()
		return
	var action_kind := str(action.get("kind", ""))
	var is_play: bool = action_kind == _screen.MatchActionEnumerator.KIND_SUMMON_CREATURE or action_kind == _screen.MatchActionEnumerator.KIND_PLAY_ACTION or action_kind == _screen.MatchActionEnumerator.KIND_PLAY_ITEM
	_screen._overlays._prophecy_overlay_state["phase"] = "animating"
	if is_play:
		# Flip animation: scale X to 0, swap to card face, scale back
		var instance_id := str(_screen._overlays._prophecy_overlay_state.get("instance_id", ""))
		var card = _screen._card_from_instance_id(instance_id)
		card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
		var tween = _screen.create_tween()
		tween.tween_property(card_back, "scale:x", 0.0, 0.2)
		tween.tween_callback(func():
			# Replace card back content with card face
			for child in card_back.get_children():
				child.queue_free()
			if not card.is_empty():
				var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
				component.mouse_filter = Control.MOUSE_FILTER_IGNORE
				component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
				component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
				card_back.add_child(component)
		)
		tween.tween_property(card_back, "scale:x", 1.0, 0.2)
		tween.tween_interval(0.4)
		tween.tween_callback(func():
			_screen._overlays._dismiss_prophecy_overlay()
			_screen._refresh_ui()
		)
	else:
		# Decline: slide up into opponent hand area
		card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
		var tween = _screen.create_tween()
		tween.set_parallel(true)
		tween.tween_property(card_back, "position:y", -card_back.size.y, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(card_back, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(func():
			_screen._overlays._dismiss_prophecy_overlay()
			_screen._refresh_ui()
		)


func _dismiss_spell_reveal() -> void:
	var card_back: Control = _screen._overlays._spell_reveal_state.get("card_back")
	if card_back != null and is_instance_valid(card_back):
		card_back.queue_free()
	var arrow: Line2D = _screen._overlays._spell_reveal_state.get("arrow")
	if arrow != null and is_instance_valid(arrow):
		arrow.queue_free()
	_screen._overlays._spell_reveal_state = {}


func _dismiss_attack_arrow() -> void:
	var arrow: Line2D = _screen._targeting._attack_arrow_state.get("arrow")
	if arrow != null and is_instance_valid(arrow):
		arrow.queue_free()
	_screen._targeting._attack_arrow_state = {}


func _animate_enemy_attack_arrow(action: Dictionary, _result: Dictionary) -> void:
	var attacker_id := str(action.get("source_instance_id", ""))
	var params: Dictionary = action.get("parameters", {})
	var target: Dictionary = params.get("target", {})
	var target_type := str(target.get("type", ""))

	var attacker_button: Button = _screen._card_buttons.get(attacker_id)
	if attacker_button == null or not is_instance_valid(attacker_button):
		_screen._refresh_ui()
		return

	var attacker_card_size: Vector2 = attacker_button.get_meta("card_size", attacker_button.size)
	var arrow_start := attacker_button.global_position + Vector2(attacker_card_size.x * 0.5, 0.0)

	var arrow_end := Vector2.ZERO
	if target_type == _screen.MatchCombat.TARGET_TYPE_CREATURE:
		var target_id := str(target.get("instance_id", ""))
		var target_button: Button = _screen._card_buttons.get(target_id)
		if target_button == null or not is_instance_valid(target_button):
			_screen._refresh_ui()
			return
		var target_card_size: Vector2 = target_button.get_meta("card_size", target_button.size)
		arrow_end = target_button.global_position + Vector2(target_card_size.x * 0.5, 0.0)
	elif target_type == _screen.MatchCombat.TARGET_TYPE_PLAYER:
		var target_player_id := str(target.get("player_id", ""))
		var section: Dictionary = _screen._player_sections.get(target_player_id, {})
		var avatar: Control = section.get("avatar_component")
		if avatar != null and is_instance_valid(avatar):
			arrow_end = avatar.global_position + Vector2(avatar.size.x * 0.5, avatar.size.y * 0.5)
		else:
			_screen._refresh_ui()
			return
	else:
		_screen._refresh_ui()
		return

	var arrow := Line2D.new()
	arrow.width = 4.0
	arrow.default_color = Color(0.95, 0.25, 0.2, 0.92)
	arrow.z_index = 500
	arrow.antialiased = true
	_screen._prophecy_card_overlay.add_child(arrow)
	_screen._targeting._attack_arrow_state = {"arrow": arrow}

	var tween = _screen.create_tween()
	tween.tween_method(func(progress: float):
		_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
	, 0.0, 1.0, 0.3)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		_dismiss_attack_arrow()
		_screen._refresh_ui()
	)


static func _has_support_activation_target(action: Dictionary) -> bool:
	var params: Dictionary = action.get("parameters", {})
	return not str(params.get("target_instance_id", "")).is_empty() or not str(params.get("target_player_id", "")).is_empty()


func _dismiss_support_arrow() -> void:
	var arrow: Line2D = _screen._targeting._support_arrow_state.get("arrow")
	if arrow != null and is_instance_valid(arrow):
		arrow.queue_free()
	_screen._targeting._support_arrow_state = {}


func _animate_enemy_support_activation_arrow(action: Dictionary, _result: Dictionary) -> void:
	var support_id := str(action.get("source_instance_id", ""))
	var params: Dictionary = action.get("parameters", {})
	var target_instance_id := str(params.get("target_instance_id", ""))
	var target_player_id := str(params.get("target_player_id", ""))

	var support_button: Button = _screen._card_buttons.get(support_id)
	if support_button == null or not is_instance_valid(support_button):
		_screen._refresh_ui()
		return

	var support_size: Vector2 = support_button.get_meta("card_size", support_button.size)
	var arrow_start := support_button.global_position + Vector2(support_size.x * 0.5, support_size.y * 0.5)

	var arrow_end := Vector2.ZERO
	if not target_instance_id.is_empty():
		var target_button: Button = _screen._card_buttons.get(target_instance_id)
		if target_button == null or not is_instance_valid(target_button):
			_screen._refresh_ui()
			return
		var target_size: Vector2 = target_button.get_meta("card_size", target_button.size)
		arrow_end = target_button.global_position + Vector2(target_size.x * 0.5, target_size.y * 0.5)
	elif not target_player_id.is_empty():
		var section: Dictionary = _screen._player_sections.get(target_player_id, {})
		var avatar: Control = section.get("avatar_component")
		if avatar != null and is_instance_valid(avatar):
			arrow_end = avatar.global_position + Vector2(avatar.size.x * 0.5, avatar.size.y * 0.5)
		else:
			_screen._refresh_ui()
			return
	else:
		_screen._refresh_ui()
		return

	var arrow := Line2D.new()
	arrow.width = 4.0
	arrow.default_color = Color(1.0, 0.85, 0.3, 0.95)
	arrow.z_index = 500
	arrow.antialiased = true
	_screen._prophecy_card_overlay.add_child(arrow)
	_screen._targeting._support_arrow_state = {"arrow": arrow}

	var tween = _screen.create_tween()
	tween.tween_method(func(progress: float):
		_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
	, 0.0, 1.0, 0.3)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		_dismiss_support_arrow()
		_screen._refresh_ui()
	)


func _dismiss_deck_reveal() -> void:
	var panel: Control = _screen._overlays._deck_reveal_state.get("panel")
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	_screen._overlays._deck_reveal_state = {}


func _animate_deck_card_reveal(revealed_card: Dictionary) -> void:
	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "deck_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_screen._apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x: float = (viewport_size.x - card_size.x) * 0.5
	var pos_y: float = viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_screen._prophecy_card_overlay.add_child(card_back)
	_screen._overlays._deck_reveal_state = {
		"panel": card_back,
		"phase": "animating",
	}

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween = _screen.create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(revealed_card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_callback(func():
		_dismiss_deck_reveal()
		_screen._refresh_ui()
	)


func _animate_enemy_spell_reveal(action: Dictionary, _result: Dictionary) -> void:
	var source_card: Dictionary = action.get("source_card", {})
	if source_card.is_empty():
		_screen._refresh_ui()
		return

	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "spell_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_screen._apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x: float = (viewport_size.x - card_size.x) * 0.5
	var pos_y: float = viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_screen._prophecy_card_overlay.add_child(card_back)
	_screen._overlays._spell_reveal_state = {
		"card_back": card_back,
		"phase": "animating",
	}

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween = _screen.create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		if not source_card.is_empty():
			var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
			component.mouse_filter = Control.MOUSE_FILTER_IGNORE
			component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			component.apply_card(source_card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
			card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		var target: Dictionary = action.get("target", {})
		var target_kind := str(target.get("kind", ""))
		if target_kind == "card":
			var target_id := str(target.get("instance_id", ""))
			var button: Button = _screen._card_buttons.get(target_id)
			if button != null and is_instance_valid(button):
				var arrow := Line2D.new()
				arrow.width = 3.0
				arrow.default_color = Color(1.0, 0.85, 0.3, 0.95)
				arrow.z_index = 500
				_screen._prophecy_card_overlay.add_child(arrow)
				_screen._overlays._spell_reveal_state["arrow"] = arrow
				var arrow_start := card_back.global_position + Vector2(card_size.x * 0.5, card_size.y)
				var target_card_size: Vector2 = button.get_meta("card_size", button.size)
				var arrow_end := button.global_position + Vector2(target_card_size.x * 0.5, 0.0)
				var arrow_tween = _screen.create_tween()
				arrow_tween.tween_method(func(progress: float):
					_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
				, 0.0, 1.0, 0.3)
				arrow_tween.tween_interval(0.3)
				arrow_tween.tween_callback(func():
					_dismiss_spell_reveal()
					_screen._refresh_ui()
				)
				return
		_dismiss_spell_reveal()
		_screen._refresh_ui()
	)


func _animate_enemy_item_reveal(action: Dictionary, _result: Dictionary) -> void:
	var source_card: Dictionary = action.get("source_card", {})
	if source_card.is_empty():
		_screen._refresh_ui()
		return

	var params: Dictionary = action.get("parameters", {})
	var target_instance_id := str(params.get("target_instance_id", ""))

	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "item_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_screen._apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x: float = (viewport_size.x - card_size.x) * 0.5
	var pos_y: float = viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_screen._prophecy_card_overlay.add_child(card_back)
	_screen._overlays._spell_reveal_state = {
		"card_back": card_back,
		"phase": "animating",
	}

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween = _screen.create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		if not source_card.is_empty():
			var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
			component.mouse_filter = Control.MOUSE_FILTER_IGNORE
			component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			component.apply_card(source_card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
			card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		if not target_instance_id.is_empty():
			var button: Button = _screen._card_buttons.get(target_instance_id)
			if button != null and is_instance_valid(button):
				var arrow := Line2D.new()
				arrow.width = 3.0
				arrow.default_color = Color(1.0, 0.85, 0.3, 0.95)
				arrow.z_index = 500
				_screen._prophecy_card_overlay.add_child(arrow)
				_screen._overlays._spell_reveal_state["arrow"] = arrow
				var arrow_start := card_back.global_position + Vector2(card_size.x * 0.5, card_size.y)
				var target_card_size: Vector2 = button.get_meta("card_size", button.size)
				var arrow_end := button.global_position + Vector2(target_card_size.x * 0.5, 0.0)
				var arrow_tween = _screen.create_tween()
				arrow_tween.tween_method(func(progress: float):
					_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
				, 0.0, 1.0, 0.3)
				arrow_tween.tween_interval(0.3)
				arrow_tween.tween_callback(func():
					_dismiss_spell_reveal()
					_screen._refresh_ui()
				)
				return
		_dismiss_spell_reveal()
		_screen._refresh_ui()
	)


static func _has_summon_target(action: Dictionary) -> bool:
	var params: Dictionary = action.get("parameters", {})
	return not str(params.get("summon_target_instance_id", "")).is_empty() or not str(params.get("summon_target_player_id", "")).is_empty()


func _animate_enemy_creature_summon_reveal(action: Dictionary, _result: Dictionary) -> void:
	var source_card: Dictionary = action.get("source_card", {})
	if source_card.is_empty():
		_screen._refresh_ui()
		return

	var params: Dictionary = action.get("parameters", {})
	var summon_target_id := str(params.get("summon_target_instance_id", ""))

	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "summon_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_screen._apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	var pos_x: float = (viewport_size.x - card_size.x) * 0.5
	var pos_y: float = viewport_size.y * 0.10 + 12.0
	card_back.position = Vector2(pos_x, pos_y)

	_screen._prophecy_card_overlay.add_child(card_back)
	_screen._overlays._spell_reveal_state = {
		"card_back": card_back,
		"phase": "animating",
	}

	card_back.pivot_offset = Vector2(card_back.size.x * 0.5, card_back.size.y * 0.5)
	var tween = _screen.create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	tween.tween_callback(func():
		for child in card_back.get_children():
			child.queue_free()
		if not source_card.is_empty():
			var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
			component.mouse_filter = Control.MOUSE_FILTER_IGNORE
			component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			component.apply_card(source_card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
			card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		if not summon_target_id.is_empty():
			var button: Button = _screen._card_buttons.get(summon_target_id)
			if button != null and is_instance_valid(button):
				var arrow := Line2D.new()
				arrow.width = 3.0
				arrow.default_color = Color(1.0, 0.85, 0.3, 0.95)
				arrow.z_index = 500
				_screen._prophecy_card_overlay.add_child(arrow)
				_screen._overlays._spell_reveal_state["arrow"] = arrow
				var arrow_start := card_back.global_position + Vector2(card_size.x * 0.5, card_size.y)
				var target_card_size: Vector2 = button.get_meta("card_size", button.size)
				var arrow_end := button.global_position + Vector2(target_card_size.x * 0.5, 0.0)
				var arrow_tween = _screen.create_tween()
				arrow_tween.tween_method(func(progress: float):
					_draw_spell_reveal_arrow_partial(progress, arrow, arrow_start, arrow_end)
				, 0.0, 1.0, 0.3)
				arrow_tween.tween_interval(0.3)
				arrow_tween.tween_callback(func():
					_dismiss_spell_reveal()
					_screen._refresh_ui()
				)
				return
		_dismiss_spell_reveal()
		_screen._refresh_ui()
	)


func _animate_enemy_creature_play(action: Dictionary, _result: Dictionary) -> void:
	var source_card: Dictionary = action.get("source_card", {})
	var params: Dictionary = action.get("parameters", {})
	var lane_id := str(params.get("lane_id", ""))
	if source_card.is_empty() or lane_id.is_empty():
		_screen._refresh_ui()
		return

	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "creature_play_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_screen._apply_panel_style(card_back, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)

	# Start from the top center (enemy hand area)
	var start_x: float = (viewport_size.x - card_size.x) * 0.5
	var start_y: float = -(card_size.y * 0.5)
	card_back.position = Vector2(start_x, start_y)

	_screen._prophecy_card_overlay.add_child(card_back)
	_screen._overlays._spell_reveal_state = {
		"card_back": card_back,
		"phase": "animating",
	}

	# Find the target lane row panel to get the destination position
	var enemy_player_id := str(action.get("player_id", ""))
	var row_key = _screen._lane_row_key(lane_id, enemy_player_id)
	var row_panel: PanelContainer = _screen._lane_row_panels.get(row_key)
	var end_pos: Vector2
	if row_panel != null and is_instance_valid(row_panel):
		var row_center := row_panel.global_position + row_panel.size * 0.5
		end_pos = Vector2(row_center.x - card_size.x * 0.5, row_center.y - card_size.y * 0.5)
	else:
		end_pos = Vector2(start_x, viewport_size.y * 0.25)

	card_back.pivot_offset = Vector2(card_size.x * 0.5, card_size.y * 0.5)
	var tween = _screen.create_tween()
	# Animate card moving down to the lane
	tween.tween_property(card_back, "position", end_pos, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Scale down as it approaches the lane
	tween.parallel().tween_property(card_back, "scale", Vector2(0.5, 0.5), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Brief pause at destination
	tween.tween_interval(0.15)
	# Fade out
	tween.tween_property(card_back, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		_dismiss_spell_reveal()
		_screen._refresh_ui()
	)


func _draw_spell_reveal_arrow_partial(progress: float, arrow: Line2D, start: Vector2, end_point: Vector2) -> void:
	if arrow == null or not is_instance_valid(arrow):
		return
	var current_end := start.lerp(end_point, progress)
	var mid := (start + current_end) * 0.5
	var diff := current_end - start
	var perp := Vector2(-diff.y, diff.x).normalized()
	var control := mid + perp * diff.length() * 0.25
	var points := PackedVector2Array()
	var segments := 20
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := (1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * control + t * t * current_end
		points.append(p)
	if progress > 0.05:
		var tip := points[points.size() - 1]
		var prev := points[points.size() - 2]
		var arrow_dir := (tip - prev).normalized()
		var arrow_perp := Vector2(-arrow_dir.y, arrow_dir.x)
		var arrow_size := 14.0
		points.append(tip - arrow_dir * arrow_size + arrow_perp * arrow_size * 0.5)
		points.append(tip)
		points.append(tip - arrow_dir * arrow_size - arrow_perp * arrow_size * 0.5)
		points.append(tip)
	arrow.points = points
