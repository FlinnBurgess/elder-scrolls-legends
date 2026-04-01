class_name MatchScreenHistory
extends RefCounted

const CardDisplayComponent = preload("res://src/ui/components/CardDisplayComponent.gd")

var _screen  # MatchScreen reference
var entries: Array = []
var last_event_count: int = 0
var card_snapshots: Dictionary = {}
var container: HBoxContainer
var popover_state := {}


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


func _reset_match_history() -> void:
	entries.clear()
	last_event_count = 0
	card_snapshots.clear()
	_dismiss_match_history_popover()
	_refresh_match_history_row()


func _scan_and_refresh_match_history() -> void:
	# Defer scanning while the player is selecting a target for a summon effect,
	# action, or item so the history entry includes the resolved target(s).
	if not _screen._targeting._pending_summon_target.is_empty() or not _screen._targeting._targeting_arrow_state.is_empty():
		return
	var event_log: Array = _screen._match_state.get("event_log", [])
	if event_log.size() <= last_event_count:
		return
	_scan_event_log_for_history(event_log)
	last_event_count = event_log.size()
	_refresh_match_history_row()


func _scan_event_log_for_history(event_log: Array) -> void:
	var start := last_event_count
	var i := start
	while i < event_log.size():
		var event: Dictionary = event_log[i]
		var event_type := str(event.get("event_type", ""))
		var parent_id := str(event.get("parent_event_id", ""))

		if event_type == "card_played" and parent_id.is_empty():
			_process_card_played_history(event, event_log, i)
		elif event_type == "attack_declared" and parent_id.is_empty():
			_process_attack_history(event, event_log, i)
		elif event_type == "support_activated" and parent_id.is_empty():
			_process_support_activated_history(event, event_log, i)
		i += 1


func _process_card_played_history(play_event: Dictionary, event_log: Array, event_index: int) -> void:
	var player_id := str(play_event.get("player_id", ""))
	var source_id := str(play_event.get("source_instance_id", ""))
	var card_type := str(play_event.get("card_type", ""))
	var source_card := _snapshot_card_for_history(source_id)
	# Prefer the play-time snapshot from the event over the post-trigger state,
	# so shouts that upgrade themselves show the level that was actually played.
	var event_rules_text := str(play_event.get("source_rules_text", ""))
	if not event_rules_text.is_empty() and not source_card.is_empty():
		source_card["rules_text"] = event_rules_text
	var event_name := str(play_event.get("source_name", ""))
	if not event_name.is_empty() and not source_card.is_empty():
		source_card["name"] = event_name

	var entry := {
		"action_type": "play_card",
		"player_id": player_id,
		"source_card": source_card,
		"source_instance_id": source_id,
		"card_type": card_type,
		"targets": [] as Array,
		"chain": [] as Array,
	}

	# Collect targets from the play event itself
	var direct_target_id := str(play_event.get("target_instance_id", ""))
	var direct_target_player_id := str(play_event.get("target_player_id", ""))

	if card_type == "item":
		# Item: direct target is the creature it was equipped to
		if not direct_target_id.is_empty():
			var equipped_card := _snapshot_card_for_history(direct_target_id)
			entry["targets"].append({
				"kind": "creature",
				"card": equipped_card,
				"instance_id": direct_target_id,
				"destroyed": false,
			})
		# Look for subsequent summon-effect targets from this item
		var chain_targets := _collect_batch_targets(event_log, event_index, [source_id, direct_target_id])
		if not chain_targets.is_empty():
			entry["chain"].append({
				"source_card": _snapshot_card_for_history(direct_target_id) if not direct_target_id.is_empty() else {},
				"source_instance_id": direct_target_id,
				"targets": chain_targets,
			})
	elif card_type == "creature":
		# Creature with summon effect: look for damage/effect targets
		var summon_targets := _collect_batch_targets(event_log, event_index, [source_id])
		for t in summon_targets:
			entry["targets"].append(t)
	elif card_type == "action":
		# Action/spell: look for targets from effects
		if not direct_target_id.is_empty():
			var target_card := _snapshot_card_for_history(direct_target_id)
			var destroyed := _is_destroyed_in_batch(event_log, event_index, direct_target_id)
			entry["targets"].append({
				"kind": "creature",
				"card": target_card,
				"instance_id": direct_target_id,
				"destroyed": destroyed,
			})
		elif not direct_target_player_id.is_empty():
			entry["targets"].append({
				"kind": "player",
				"card": {},
				"instance_id": "",
				"player_id": direct_target_player_id,
				"destroyed": false,
			})
		# Also collect any additional targets from batch events
		var exclude_ids := [source_id]
		if not direct_target_id.is_empty():
			exclude_ids.append(direct_target_id)
		var extra_targets := _collect_batch_targets(event_log, event_index, exclude_ids)
		for t in extra_targets:
			entry["targets"].append(t)

	_add_history_entry(entry)


func _process_attack_history(attack_event: Dictionary, event_log: Array, event_index: int) -> void:
	var player_id := str(attack_event.get("attacking_player_id", ""))
	var attacker_id := str(attack_event.get("attacker_instance_id", ""))
	var target_type := str(attack_event.get("target_type", ""))
	var target_id := str(attack_event.get("target_instance_id", ""))
	var target_player_id := str(attack_event.get("target_player_id", ""))
	var attacker_card := _snapshot_card_for_history(attacker_id)

	var entry := {
		"action_type": "attack",
		"player_id": player_id,
		"source_card": attacker_card,
		"source_instance_id": attacker_id,
		"targets": [] as Array,
		"chain": [] as Array,
	}

	if target_type == "creature":
		var target_card := _snapshot_card_for_history(target_id)
		var target_destroyed := _is_destroyed_in_batch(event_log, event_index, target_id)
		var attacker_destroyed := _is_destroyed_in_batch(event_log, event_index, attacker_id)
		entry["targets"].append({
			"kind": "creature",
			"card": target_card,
			"instance_id": target_id,
			"destroyed": target_destroyed,
		})
		# Mark attacker as destroyed if it traded
		entry["attacker_destroyed"] = attacker_destroyed
	elif target_type == "player":
		var rune_breaks := _collect_rune_breaks(event_log, event_index, target_player_id)
		entry["targets"].append({
			"kind": "player",
			"card": {},
			"instance_id": "",
			"player_id": target_player_id,
			"destroyed": false,
			"rune_breaks": rune_breaks,
		})

	_add_history_entry(entry)


func _process_support_activated_history(support_event: Dictionary, event_log: Array, event_index: int) -> void:
	var player_id := str(support_event.get("player_id", ""))
	var source_id := str(support_event.get("source_instance_id", ""))
	var target_id := str(support_event.get("target_instance_id", ""))
	var source_card := _snapshot_card_for_history(source_id)

	# Only show targeted support activations
	if target_id.is_empty():
		return

	var entry := {
		"action_type": "activate_support",
		"player_id": player_id,
		"source_card": source_card,
		"source_instance_id": source_id,
		"targets": [] as Array,
		"chain": [] as Array,
	}

	var target_card := _snapshot_card_for_history(target_id)
	var destroyed := _is_destroyed_in_batch(event_log, event_index, target_id)
	entry["targets"].append({
		"kind": "creature",
		"card": target_card,
		"instance_id": target_id,
		"destroyed": destroyed,
	})

	_add_history_entry(entry)


func _find_batch_end(event_log: Array, start_index: int) -> int:
	# Find the end of the current action batch. A batch ends when we hit the
	# next top-level initiating event (card_played, attack_declared,
	# support_activated, turn_started) that has no parent_event_id.
	const INITIATING_TYPES := ["card_played", "attack_declared", "support_activated", "turn_started"]
	for i in range(start_index + 1, mini(event_log.size(), start_index + 80)):
		var evt: Dictionary = event_log[i]
		var evt_type := str(evt.get("event_type", ""))
		var parent_id := str(evt.get("parent_event_id", ""))
		if parent_id.is_empty() and INITIATING_TYPES.has(evt_type):
			return i
	return event_log.size()


func _collect_batch_targets(event_log: Array, start_index: int, exclude_ids: Array) -> Array:
	var targets: Array = []
	var seen_target_ids: Array = exclude_ids.duplicate()
	var batch_end := _find_batch_end(event_log, start_index)

	for i in range(start_index + 1, batch_end):
		var evt: Dictionary = event_log[i]
		var evt_type := str(evt.get("event_type", ""))

		if evt_type == "damage_resolved":
			var target_id := str(evt.get("target_instance_id", ""))
			var target_player_id := str(evt.get("target_player_id", ""))
			if not target_id.is_empty() and not seen_target_ids.has(target_id):
				seen_target_ids.append(target_id)
				var target_card := _snapshot_card_for_history(target_id)
				var destroyed := _is_destroyed_in_batch(event_log, start_index, target_id)
				targets.append({
					"kind": "creature",
					"card": target_card,
					"instance_id": target_id,
					"destroyed": destroyed,
				})
			elif not target_player_id.is_empty() and not seen_target_ids.has("player:" + target_player_id):
				seen_target_ids.append("player:" + target_player_id)
				targets.append({
					"kind": "player",
					"card": {},
					"instance_id": "",
					"player_id": target_player_id,
					"destroyed": false,
				})

	return targets


func _collect_rune_breaks(event_log: Array, start_index: int, target_player_id: String) -> Array:
	var runes: Array = []
	var batch_end := _find_batch_end(event_log, start_index)
	for i in range(start_index + 1, batch_end):
		var evt: Dictionary = event_log[i]
		if str(evt.get("event_type", "")) == "rune_broken":
			var rune_player := str(evt.get("player_id", ""))
			if rune_player == target_player_id:
				runes.append(int(evt.get("threshold", 0)))
	return runes


func _is_destroyed_in_batch(event_log: Array, start_index: int, instance_id: String) -> bool:
	var batch_end := _find_batch_end(event_log, start_index)
	for i in range(start_index + 1, batch_end):
		var evt: Dictionary = event_log[i]
		if str(evt.get("event_type", "")) == "creature_destroyed":
			var destroyed_id := str(evt.get("source_instance_id", ""))
			if destroyed_id == instance_id:
				return true
	return false


func _snapshot_card_for_history(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	# Try to find the card in current match state
	var location = _screen.MatchMutations.find_card_location(_screen._match_state, instance_id)
	if bool(location.get("is_valid", false)):
		var card: Dictionary = location["card"]
		var snapshot := card.duplicate(true)
		card_snapshots[instance_id] = snapshot
		return snapshot
	# Fall back to cached snapshot
	if card_snapshots.has(instance_id):
		return card_snapshots[instance_id]
	return {}


func _add_history_entry(entry: Dictionary) -> void:
	entries.append(entry)
	if entries.size() > _screen.MATCH_HISTORY_MAX_ENTRIES:
		entries.pop_front()


func _refresh_match_history_row() -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var icon := _build_match_history_icon(entry, entry_index)
		container.add_child(icon)


func _build_match_history_icon(entry: Dictionary, entry_index: int) -> Button:
	var is_local: bool = str(entry.get("player_id", "")) == _screen._local_player_id()
	var border_color = _screen.MATCH_HISTORY_PLAYER_BORDER_COLOR if is_local else _screen.MATCH_HISTORY_OPPONENT_BORDER_COLOR
	var fill := Color(0.1, 0.1, 0.12, 0.96)

	var button := Button.new()
	button.custom_minimum_size = _screen.MATCH_HISTORY_ICON_SIZE
	button.clip_contents = true
	_screen._apply_button_style(button, fill, border_color, Color.WHITE, _screen.MATCH_HISTORY_ICON_BORDER_WIDTH, 6)
	button.pressed.connect(_on_match_history_icon_pressed.bind(entry_index))
	button.mouse_entered.connect(_on_match_history_mouse_entered.bind(entry, entry_index))
	button.mouse_exited.connect(_on_match_history_mouse_exited)

	var source_card: Dictionary = entry.get("source_card", {})
	if not source_card.is_empty():
		var tex_rect := TextureRect.new()
		tex_rect.texture = _resolve_history_art_texture(source_card)
		tex_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		tex_rect.offset_left = _screen.MATCH_HISTORY_ICON_BORDER_WIDTH
		tex_rect.offset_top = _screen.MATCH_HISTORY_ICON_BORDER_WIDTH
		tex_rect.offset_right = -_screen.MATCH_HISTORY_ICON_BORDER_WIDTH
		tex_rect.offset_bottom = -_screen.MATCH_HISTORY_ICON_BORDER_WIDTH
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(tex_rect)

	return button


func _resolve_history_art_texture(card: Dictionary) -> Texture2D:
	# Check for direct texture or path on the card
	for key in ["art_texture", "art"]:
		var direct = card.get(key, null)
		if direct is Texture2D:
			return direct as Texture2D
	for key in ["art_path", "art_resource_path", "art"]:
		var path := str(card.get(key, "")).strip_edges()
		if path.is_empty():
			continue
		if ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is Texture2D:
				return loaded as Texture2D
	# Fall back to catalog art_path via definition_id (covers generated cards)
	var def_id := str(card.get("definition_id", ""))
	if not def_id.is_empty():
		var catalog_path := "res://assets/images/cards/" + def_id + ".png"
		if ResourceLoader.exists(catalog_path):
			var loaded = load(catalog_path)
			if loaded is Texture2D:
				return loaded as Texture2D
	# Fall back to the default card placeholder
	var placeholder_path := "res://assets/images/cards/placeholder.png"
	if ResourceLoader.exists(placeholder_path):
		var loaded = load(placeholder_path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null


func _on_match_history_icon_pressed(entry_index: int) -> void:
	var current_index: int = popover_state.get("entry_index", -1)
	if current_index == entry_index:
		_dismiss_match_history_popover()
		return
	_dismiss_match_history_popover()
	_show_match_history_popover(entry_index)


func _show_match_history_popover(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= entries.size():
		return
	var entry: Dictionary = entries[entry_index]

	# Full-screen overlay to capture dismiss clicks
	var overlay := Control.new()
	overlay.name = "MatchHistoryPopover"
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.z_index = 460
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_match_history_popover_bg_input)
	overlay.add_child(bg)

	# Center container for content
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var content_panel := PanelContainer.new()
	content_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen._apply_panel_style(content_panel, Color(0.08, 0.09, 0.11, 0.97), Color(0.35, 0.36, 0.42, 0.9), 2, 12)
	center.add_child(content_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	content_panel.add_child(margin)

	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content_hbox)

	var source_card: Dictionary = entry.get("source_card", {})
	var source_player_id := str(entry.get("player_id", ""))
	var action_type := str(entry.get("action_type", ""))
	var attacker_destroyed := bool(entry.get("attacker_destroyed", false))

	# Source card
	var source_section := _build_history_popover_card_section(source_card, source_player_id, attacker_destroyed)
	content_hbox.add_child(source_section)

	# Targets
	var targets: Array = entry.get("targets", [])
	var chain: Array = entry.get("chain", [])

	if not targets.is_empty() or not chain.is_empty():
		# Arrow
		var arrow_label := Label.new()
		arrow_label.text = "→"
		arrow_label.add_theme_font_size_override("font_size", 36)
		arrow_label.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78, 1.0))
		arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_hbox.add_child(arrow_label)

		# Targets
		var targets_hbox := HBoxContainer.new()
		targets_hbox.add_theme_constant_override("separation", 12)

		for target in targets:
			var target_section := _build_history_popover_target_section(target)
			targets_hbox.add_child(target_section)

		content_hbox.add_child(targets_hbox)

		# Chain (for item -> creature -> subsequent targets)
		for chain_entry in chain:
			var chain_targets: Array = chain_entry.get("targets", [])
			if chain_targets.is_empty():
				continue

			var chain_arrow := Label.new()
			chain_arrow.text = "→"
			chain_arrow.add_theme_font_size_override("font_size", 36)
			chain_arrow.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78, 1.0))
			chain_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			content_hbox.add_child(chain_arrow)

			var chain_hbox := HBoxContainer.new()
			chain_hbox.add_theme_constant_override("separation", 12)

			for chain_target in chain_targets:
				var ct_section := _build_history_popover_target_section(chain_target)
				chain_hbox.add_child(ct_section)

			content_hbox.add_child(chain_hbox)

	_screen.add_child(overlay)
	popover_state = {"overlay": overlay, "entry_index": entry_index}
	var source_card_name := str(source_card.get("name", "unknown"))
	_screen._error_report_hovered_type = "match_history"
	_screen._error_report_hovered_context = "Match History Entry #%d (%s)" % [entry_index + 1, source_card_name]


func _build_history_popover_card_section(card: Dictionary, player_id: String, destroyed: bool) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.alignment = BoxContainer.ALIGNMENT_CENTER

	# Player label
	var label := Label.new()
	label.text = "You" if player_id == _screen._local_player_id() else "Opponent"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(label)

	if card.is_empty():
		# Hidden info placeholder
		var placeholder := _build_hidden_card_placeholder()
		section.add_child(placeholder)
	else:
		var card_wrapper := PanelContainer.new()
		card_wrapper.custom_minimum_size = Vector2(180, 310)
		var wrapper_style := StyleBoxFlat.new()
		wrapper_style.bg_color = Color(0.12, 0.11, 0.14, 0.95)
		wrapper_style.corner_radius_top_left = 6
		wrapper_style.corner_radius_top_right = 6
		wrapper_style.corner_radius_bottom_left = 6
		wrapper_style.corner_radius_bottom_right = 6
		card_wrapper.add_theme_stylebox_override("panel", wrapper_style)

		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_wrapper.add_child(component)

		if destroyed:
			# Grey out and add red X
			component.modulate = Color(0.4, 0.4, 0.4, 0.7)
			var x_label := Label.new()
			x_label.text = "✕"
			x_label.add_theme_font_size_override("font_size", 72)
			x_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.15, 0.85))
			x_label.set_anchors_and_offsets_preset(PRESET_CENTER)
			x_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			x_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card_wrapper.add_child(x_label)

		section.add_child(card_wrapper)

	return section


func _build_history_popover_target_section(target: Dictionary) -> VBoxContainer:
	var kind := str(target.get("kind", ""))
	var target_player_id := str(target.get("player_id", ""))
	var target_card: Dictionary = target.get("card", {})
	var destroyed := bool(target.get("destroyed", false))

	if kind == "player":
		# Player avatar target
		var player_id_for_label := target_player_id if not target_player_id.is_empty() else ""
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)
		section.alignment = BoxContainer.ALIGNMENT_CENTER

		var label := Label.new()
		label.text = "You" if player_id_for_label == _screen._local_player_id() else "Opponent"
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_child(label)

		var avatar_panel := PanelContainer.new()
		avatar_panel.custom_minimum_size = Vector2(120, 120)
		var avatar_style := StyleBoxFlat.new()
		avatar_style.bg_color = Color(0.15, 0.14, 0.18, 0.95)
		avatar_style.corner_radius_top_left = 60
		avatar_style.corner_radius_top_right = 60
		avatar_style.corner_radius_bottom_left = 60
		avatar_style.corner_radius_bottom_right = 60
		avatar_style.border_color = Color(0.5, 0.48, 0.42, 0.8)
		avatar_style.border_width_left = 2
		avatar_style.border_width_top = 2
		avatar_style.border_width_right = 2
		avatar_style.border_width_bottom = 2
		avatar_panel.add_theme_stylebox_override("panel", avatar_style)

		var avatar_label := Label.new()
		avatar_label.text = "Face"
		avatar_label.add_theme_font_size_override("font_size", 20)
		avatar_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78, 1.0))
		avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar_label.set_anchors_and_offsets_preset(PRESET_CENTER)
		avatar_panel.add_child(avatar_label)
		section.add_child(avatar_panel)

		# Rune breaks
		var rune_breaks: Array = target.get("rune_breaks", [])
		if not rune_breaks.is_empty():
			var rune_row := HBoxContainer.new()
			rune_row.add_theme_constant_override("separation", 4)
			rune_row.alignment = BoxContainer.ALIGNMENT_CENTER
			for threshold in rune_breaks:
				var rune_panel := PanelContainer.new()
				rune_panel.custom_minimum_size = Vector2(32, 32)
				var rune_style := StyleBoxFlat.new()
				rune_style.bg_color = Color(0.12, 0.1, 0.2, 0.95)
				rune_style.corner_radius_top_left = 4
				rune_style.corner_radius_top_right = 4
				rune_style.corner_radius_bottom_left = 4
				rune_style.corner_radius_bottom_right = 4
				rune_style.border_color = Color(0.6, 0.25, 0.2, 0.9)
				rune_style.border_width_left = 1
				rune_style.border_width_top = 1
				rune_style.border_width_right = 1
				rune_style.border_width_bottom = 1
				rune_panel.add_theme_stylebox_override("panel", rune_style)

				var rune_label := Label.new()
				rune_label.text = "✕"
				rune_label.add_theme_font_size_override("font_size", 16)
				rune_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.15, 0.9))
				rune_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				rune_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				rune_label.set_anchors_and_offsets_preset(PRESET_CENTER)
				rune_panel.add_child(rune_label)
				rune_row.add_child(rune_panel)
			section.add_child(rune_row)

		return section
	else:
		# Creature/card target
		var controller_id := str(target_card.get("controller_player_id", target_card.get("owner_player_id", "")))
		return _build_history_popover_card_section(target_card, controller_id, destroyed)


func _build_hidden_card_placeholder() -> PanelContainer:
	var placeholder := PanelContainer.new()
	placeholder.custom_minimum_size = Vector2(180, 310)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.13, 0.17, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = Color(0.4, 0.38, 0.34, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	placeholder.add_theme_stylebox_override("panel", style)

	var mystery_label := Label.new()
	mystery_label.text = "???"
	mystery_label.add_theme_font_size_override("font_size", 36)
	mystery_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55, 0.8))
	mystery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mystery_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mystery_label.set_anchors_and_offsets_preset(PRESET_CENTER)
	placeholder.add_child(mystery_label)

	return placeholder


func _on_match_history_popover_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_match_history_popover()


func _dismiss_match_history_popover() -> void:
	if popover_state.is_empty():
		return
	var overlay: Control = popover_state.get("overlay")
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	popover_state = {}
	if _screen._error_report_hovered_type == "match_history":
		_screen._error_report_hovered_type = ""
		_screen._error_report_hovered_context = ""


# --- Error Report Hover Handlers ---


func _on_match_history_mouse_entered(entry: Dictionary, entry_index: int) -> void:
	var source_card: Dictionary = entry.get("source_card", {})
	var card_name := str(source_card.get("name", "unknown"))
	_screen._error_report_hovered_type = "match_history"
	_screen._error_report_hovered_context = "Match History Entry #%d (%s)" % [entry_index + 1, card_name]


func _on_match_history_mouse_exited() -> void:
	if _screen._error_report_hovered_type == "match_history" and popover_state.is_empty():
		_screen._error_report_hovered_type = ""
		_screen._error_report_hovered_context = ""


# --- Error Report Popover ---


func _recent_presentation_events_from_history() -> Array:
	var recent: Array = []
	var history: Array = _screen._match_state.get("event_log", [])
	for index in range(history.size() - 1, -1, -1):
		var event = history[index]
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("event_type", ""))
		if event_type == "turn_started" and not recent.is_empty():
			break
		if event_type == _screen.MatchTiming.EVENT_RUNE_BROKEN or event_type == _screen.MatchTiming.EVENT_CARD_DRAWN or event_type == _screen.MatchTiming.EVENT_PROPHECY_WINDOW_OPENED or event_type == "match_won":
			recent.push_front(event)
			if recent.size() >= 8:
				break
	return recent
