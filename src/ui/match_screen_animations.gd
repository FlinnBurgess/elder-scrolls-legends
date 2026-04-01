class_name MatchScreenAnimations
extends RefCounted

var _screen  # MatchScreen reference
var _feedback_sequence := 0
var _floating_card_ids: Dictionary = {}

func _init(screen) -> void:
	_screen = screen


func _record_feedback_from_events(events: Array) -> void:
	if events.is_empty():
		return
	var damage_stacks := {}
	var removal_stacks := {}
	var draw_stacks := {}
	var rune_stacks := {}
	var now := _feedback_now_ms()
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("event_type", ""))
		match event_type:
			"attack_declared":
				_attack_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"attacker_instance_id": str(event.get("attacker_instance_id", "")),
					"attacker_player_id": str(event.get("attacking_player_id", "")),
					"target_type": str(event.get("target_type", "")),
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": str(event.get("target_player_id", "")),
					"expires_at_ms": now + ATTACK_FEEDBACK_DURATION_MS,
				})
			"damage_resolved":
				var damage_target_key := _damage_target_key(event)
				var damage_stack := int(damage_stacks.get(damage_target_key, 0))
				damage_stacks[damage_target_key] = damage_stack + 1
				_damage_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"target_kind": str(event.get("target_type", "")),
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": str(event.get("target_player_id", "")),
					"text": "-%d" % int(event.get("amount", 0)),
					"color": Color(1.0, 0.56, 0.47, 1.0),
					"stack_index": damage_stack,
					"expires_at_ms": now + DAMAGE_FEEDBACK_DURATION_MS,
				})
			"ward_removed":
				var ward_target_key := "creature:%s" % str(event.get("target_instance_id", ""))
				var ward_stack := int(damage_stacks.get(ward_target_key, 0))
				damage_stacks[ward_target_key] = ward_stack + 1
				_damage_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"target_kind": MatchCombat.TARGET_TYPE_CREATURE,
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": "",
					"text": "WARD",
					"color": Color(0.74, 0.9, 1.0, 1.0),
					"stack_index": ward_stack,
					"expires_at_ms": now + DAMAGE_FEEDBACK_DURATION_MS,
				})
			"creature_destroyed":
				var row_key := "%s:%s" % [str(event.get("lane_id", "")), str(event.get("controller_player_id", ""))]
				var removal_stack := int(removal_stacks.get(row_key, 0))
				removal_stacks[row_key] = removal_stack + 1
				var destroyed_card := _card_from_instance_id(str(event.get("instance_id", "")))
				_removal_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"lane_id": str(event.get("lane_id", "")),
					"player_id": str(event.get("controller_player_id", "")),
					"instance_id": str(event.get("instance_id", "")),
					"text": "%s falls" % _card_name(destroyed_card),
					"stack_index": removal_stack,
					"expires_at_ms": now + REMOVAL_FEEDBACK_DURATION_MS,
				})
			"card_drawn":
				var draw_player_id := str(event.get("player_id", ""))
				var draw_stack := int(draw_stacks.get(draw_player_id, 0))
				draw_stacks[draw_player_id] = draw_stack + 1
				var drawn_instance_id := str(event.get("drawn_instance_id", ""))
				var drawn_card := _card_from_instance_id(drawn_instance_id)
				var show_card_name := _should_reveal_drawn_card(draw_player_id, drawn_card)
				_draw_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"player_id": draw_player_id,
					"drawn_instance_id": drawn_instance_id,
					"card_name": _card_name(drawn_card) if show_card_name else "",
					"show_card_name": show_card_name,
					"from_rune_break": str(event.get("reason", "")) == MatchTiming.EVENT_RUNE_BROKEN,
					"stack_index": draw_stack,
					"expires_at_ms": now + DRAW_FEEDBACK_DURATION_MS,
				})
			"rune_broken":
				var rune_player_id := str(event.get("player_id", ""))
				var rune_stack := int(rune_stacks.get(rune_player_id, 0))
				rune_stacks[rune_player_id] = rune_stack + 1
				_rune_feedbacks.append({
					"feedback_id": _next_feedback_id(),
					"player_id": rune_player_id,
					"threshold": int(event.get("threshold", -1)),
					"draw_card": bool(event.get("draw_card", false)),
					"stack_index": rune_stack,
					"expires_at_ms": now + RUNE_FEEDBACK_DURATION_MS,
				})
			"card_overdraw":
				var overdraw_instance_id := str(event.get("instance_id", ""))
				var overdraw_card := _card_from_instance_id(overdraw_instance_id)
				if not overdraw_card.is_empty():
					_overdraw_queue.append({
						"card": overdraw_card.duplicate(true),
						"player_id": str(event.get("player_id", "")),
					})
			"opponent_top_deck_revealed":
				if str(event.get("controller_player_id", "")) == _local_player_id():
					var revealed_card: Dictionary = event.get("revealed_card", {})
					if not revealed_card.is_empty():
						_animate_deck_card_reveal(revealed_card)
			"treasure_hunt_revealed":
				if str(event.get("controller_player_id", "")) == _local_player_id():
					var th_card: Dictionary = event.get("revealed_card", {})
					var th_matches := bool(event.get("matches", false))
					if not th_card.is_empty():
						_animate_treasure_hunt_reveal(th_card, th_matches)
			"treasure_found":
				if str(event.get("controller_player_id", "")) == _local_player_id():
					var th_count := int(event.get("count", 1))
					_queue_status_toast("Treasure Found! (%d)" % th_count, Color(1.0, 0.85, 0.3))
			"card_transformed":
				_queue_status_toast("Card transformed!", Color(0.7, 0.5, 1.0))
			"rune_restored":
				_queue_status_toast("Rune restored!", Color(0.4, 0.8, 1.0))
			"lane_type_changed":
				var lt_type := str(event.get("new_type", ""))
				if not lt_type.is_empty():
					_queue_status_toast("%s Lane!" % lt_type.capitalize(), Color(0.6, 0.5, 0.9))
			"status_removed":
				var sr_status := str(event.get("status_id", "")).to_upper().replace("_", " ")
				if not sr_status.is_empty():
					_queue_creature_toast(str(event.get("target_instance_id", "")), "%s REMOVED" % sr_status, Color(0.9, 0.6, 0.3))
			"magicka_restored":
				if str(event.get("target_player_id", "")) == _local_player_id():
					_queue_status_toast("Magicka restored!", Color(0.3, 0.6, 1.0))
			"card_milled":
				_queue_status_toast("Card milled", Color(0.6, 0.5, 0.4))
			"cost_modified":
				var cm_amount := int(event.get("amount", 0))
				var cm_text := "+%d Cost" % cm_amount if cm_amount > 0 else "%d Cost" % cm_amount
				_queue_creature_toast(str(event.get("target_instance_id", "")), cm_text, Color(0.5, 0.4, 0.9))
			"card_stolen_from_discard":
				if str(event.get("to_player_id", "")) == _local_player_id():
					_queue_status_toast("Stole a card from opponent's discard!", Color(0.9, 0.7, 0.2))
			"item_in_hand_modified":
				if str(event.get("target_instance_id", "")) != "":
					var ihm_p := int(event.get("power", 0))
					var ihm_h := int(event.get("health", 0))
					_queue_status_toast("Item buffed +%d/+%d" % [ihm_p, ihm_h], Color(0.8, 0.7, 0.3))
			"keyword_stolen", "status_stolen":
				var ks_id := str(event.get("keyword_id", event.get("status_id", "")))
				_queue_creature_toast(str(event.get("target_instance_id", "")), "-%s" % ks_id.to_upper(), Color(0.9, 0.3, 0.3))
			"marked_for_destruction":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "DOOMED", Color(0.9, 0.2, 0.2))
			"temporary_immunity_granted":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "IMMUNE", Color(1.0, 0.95, 0.6))
			"damage_redirect_set":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "PROTECTED", Color(0.4, 0.7, 1.0))
			"rune_draw_prevented":
				_queue_status_toast("Opponent's next rune draw prevented!", Color(0.8, 0.4, 0.4))
			"creature_marked":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "MARKED", Color(0.9, 0.5, 0.2))
			"creature_aimed_at":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "AIMED", Color(0.9, 0.3, 0.2))
			"marked_for_resummon":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "RESUMMON", Color(0.8, 0.7, 0.3))
			"double_summon_granted":
				if str(event.get("player_id", "")) == _local_player_id():
					_queue_status_toast("Double Summon this turn!", Color(1.0, 0.85, 0.3))
			"action_learned":
				_queue_status_toast("Learned %s!" % str(event.get("learned_card", "")), Color(0.6, 0.7, 1.0))
			"attribute_changed":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "→ %s" % str(event.get("attribute", "")).capitalize(), Color(0.7, 0.6, 0.9))
			"card_shuffled_to_deck":
				_queue_status_toast("Card shuffled into deck", Color(0.5, 0.5, 0.6))
			"card_banished":
				_queue_status_toast("Card banished", Color(0.6, 0.3, 0.6))
			"stats_modified":
				var sm_target_id := str(event.get("target_instance_id", ""))
				var sm_power := int(event.get("power_bonus", 0))
				var sm_health := int(event.get("health_bonus", 0))
				if (sm_power != 0 or sm_health != 0) and not sm_target_id.is_empty():
					var sm_sign_p := "+" if sm_power >= 0 else ""
					var sm_sign_h := "+" if sm_health >= 0 else ""
					var sm_color := Color(0.3, 0.9, 0.4) if (sm_power >= 0 and sm_health >= 0) else Color(0.9, 0.3, 0.3)
					_queue_creature_toast(sm_target_id, "%s%d/%s%d" % [sm_sign_p, sm_power, sm_sign_h, sm_health], sm_color)
			"attached_item_detached":
				_queue_creature_toast(str(event.get("host_instance_id", "")), "ITEM DESTROYED", Color(0.9, 0.4, 0.2))
			"card_discarded":
				_queue_status_toast("Card discarded", Color(0.6, 0.4, 0.4))
			"card_stolen":
				_queue_status_toast("Card stolen!", Color(0.9, 0.6, 0.2))
			"card_consumed":
				_queue_status_toast("Creature consumed", Color(0.5, 0.3, 0.6))
			"keyword_granted":
				var kg_kw := str(event.get("keyword_id", "")).to_upper()
				if not kg_kw.is_empty():
					_queue_creature_toast(str(event.get("target_instance_id", "")), "+%s" % kg_kw, Color(0.4, 0.8, 0.5))
			"ability_granted":
				_queue_creature_toast(str(event.get("target_instance_id", "")), "+ABILITY", Color(0.5, 0.7, 0.9))
			"creatures_swapped":
				_queue_creature_toast(str(event.get("source_instance_id", "")), "SWAPPED", Color(0.8, 0.6, 0.3))
				_queue_creature_toast(str(event.get("target_instance_id", "")), "SWAPPED", Color(0.8, 0.6, 0.3))
			"all_creatures_shuffled":
				_queue_status_toast("All creatures shuffled into decks!", Color(0.7, 0.5, 0.9))
			"summons_retriggered":
				_queue_status_toast("Re-triggering all summon abilities!", Color(0.9, 0.8, 0.3))
			"deck_transformed":
				_queue_status_toast("Deck transformed!", Color(0.7, 0.4, 0.9))
			"mass_consume":
				var mc_count := int(event.get("count", 0))
				_queue_status_toast("Consumed %d creature%s from discard!" % [mc_count, "s" if mc_count != 1 else ""], Color(0.5, 0.3, 0.6))
			"lane_aoe_damage":
				var lad_lane_id := str(event.get("lane_id", ""))
				var lad_amount := int(event.get("amount", 0))
				_queue_status_toast("%d damage to all creatures in lane!" % lad_amount, Color(0.9, 0.3, 0.2))
			"counter_updated":
				var cu_value := int(event.get("value", 0))
				var cu_threshold := int(event.get("threshold", 0))
				_queue_creature_toast(str(event.get("source_instance_id", "")), "%d/%d" % [cu_value, cu_threshold], Color(0.7, 0.6, 0.3))


func _clear_feedback_state() -> void:
	_attack_feedbacks.clear()
	_damage_feedbacks.clear()
	_removal_feedbacks.clear()
	_draw_feedbacks.clear()
	_rune_feedbacks.clear()


func _add_feedback_banner(container: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	var banner := PanelContainer.new()
	banner.name = name
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.anchor_right = 1.0
	banner.offset_left = 8
	banner.offset_right = -8
	banner.offset_top = top_offset
	banner.offset_bottom = top_offset + 20.0
	banner.z_index = 12
	_apply_panel_style(banner, fill, border, 1, 6)
	container.add_child(banner)
	var box := _build_panel_box(banner, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(_queue_free_weak.bind(weakref(banner)))


func _add_feedback_banner_over_target(container: Control, target: Control, name: String, text: String, fill: Color, border: Color, font_color: Color, top_offset: float) -> void:
	if container == null or target == null:
		return
	var target_origin := container.get_global_transform_with_canvas().affine_inverse() * target.get_global_transform_with_canvas().origin
	var banner_size := Vector2(maxf(target.size.x + 28.0, 54.0), 20.0)
	var banner_position := Vector2(target_origin.x + (target.size.x - banner_size.x) * 0.5, target_origin.y + top_offset)
	if container.size.x > 0.0:
		banner_position.x = clampf(banner_position.x, 0.0, maxf(container.size.x - banner_size.x, 0.0))
	if container.size.y > 0.0:
		banner_position.y = clampf(banner_position.y, 0.0, maxf(container.size.y - banner_size.y, 0.0))
	var banner := PanelContainer.new()
	banner.name = name
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.position = banner_position
	banner.size = banner_size
	banner.z_index = 12
	_apply_panel_style(banner, fill, border, 1, 6)
	container.add_child(banner)
	var box := _build_panel_box(banner, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(_queue_free_weak.bind(weakref(banner)))


func _add_feedback_popup(container: Control, name: String, text: String, font_color: Color, top_offset: float) -> void:
	var label := Label.new()
	label.name = name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_right = 1.0
	label.offset_left = 0
	label.offset_right = 0
	label.offset_top = top_offset
	label.offset_bottom = top_offset + 26.0
	label.z_index = 18
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	container.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", Vector2(0, -24), 0.22)
	tween.parallel().tween_property(label, "scale", Vector2(1.08, 1.08), 0.18)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.7)
	tween.finished.connect(_queue_free_weak.bind(weakref(label)))


func _detach_prophecy_card(instance_id: String) -> void:
	_cancel_detached_card_silent()
	_selected_instance_id = instance_id
	var card := _card_from_instance_id(instance_id)
	var preview_size := _hand_card_display_size()
	var base_size := CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "detached_prophecy_card_%s" % instance_id
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 500
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	wrapper.add_child(component)
	add_child(wrapper)
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	var mouse_pos := get_viewport().get_mouse_position()
	wrapper.position = mouse_pos + Vector2(-preview_size.x * 0.5, -preview_size.y * 0.62)
	_detached_card_state = {
		"instance_id": instance_id,
		"preview": wrapper,
		"card_data": card.duplicate(true),
	}
	# Hide the prophecy overlay while dragging — it rebuilds on cancel via _refresh_ui
	var vbox: Control = _overlays._prophecy_overlay_state.get("vbox")
	if vbox != null and is_instance_valid(vbox):
		vbox.visible = false
	_status_message = "Click a friendly lane slot to summon %s." % _card_name(card)
	_refresh_ui()

