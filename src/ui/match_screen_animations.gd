class_name MatchScreenAnimations
extends RefCounted

var _screen  # MatchScreen reference
var _feedback_sequence := 0
var _floating_card_ids: Dictionary = {}
var _board_wipe_hidden_id := ""  # Instance ID to hide from board during Alduin animation
var _soulburst_pending: Dictionary = {}  # Pending Soulburst animation data
var _soulburst_target_id := ""  # Instance ID to suppress hover during Soulburst animation
var _soulburst_deferred_events: Array = []  # Rune/draw events deferred until after Soulburst animation
var _stitch_hidden_id := ""  # Instance ID to hide from board during Mecinar stitch animation


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


func _record_feedback_from_events(events: Array) -> void:
	if events.is_empty():
		return
	var damage_stacks := {}
	var removal_stacks := {}
	var draw_stacks := {}
	var rune_stacks := {}
	var milled_instance_ids: Array = []
	var alduin_source_id := ""
	var alduin_destroyed_ids: Array = []
	var soulburst_target_id := ""
	var stitch_instance_id := ""
	var stitch_source_creatures: Array = []
	var mankar_camoran_id := ""
	var gate_upgrade_id := ""
	var now = _screen._feedback_now_ms()
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("event_type", ""))
		match event_type:
			"attack_declared":
				_screen._attack_feedbacks.append({
					"feedback_id": _screen._next_feedback_id(),
					"attacker_instance_id": str(event.get("attacker_instance_id", "")),
					"attacker_player_id": str(event.get("attacking_player_id", "")),
					"target_type": str(event.get("target_type", "")),
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": str(event.get("target_player_id", "")),
					"expires_at_ms": now + _screen.ATTACK_FEEDBACK_DURATION_MS,
				})
			"damage_resolved":
				var damage_target_key = _screen._damage_target_key(event)
				var damage_stack := int(damage_stacks.get(damage_target_key, 0))
				damage_stacks[damage_target_key] = damage_stack + 1
				_screen._damage_feedbacks.append({
					"feedback_id": _screen._next_feedback_id(),
					"target_kind": str(event.get("target_type", "")),
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": str(event.get("target_player_id", "")),
					"text": "-%d" % int(event.get("amount", 0)),
					"color": Color(1.0, 0.56, 0.47, 1.0),
					"stack_index": damage_stack,
					"expires_at_ms": now + _screen.DAMAGE_FEEDBACK_DURATION_MS,
				})
			"ward_removed":
				var ward_target_key := "creature:%s" % str(event.get("target_instance_id", ""))
				var ward_stack := int(damage_stacks.get(ward_target_key, 0))
				damage_stacks[ward_target_key] = ward_stack + 1
				_screen._damage_feedbacks.append({
					"feedback_id": _screen._next_feedback_id(),
					"target_kind": _screen.MatchCombat.TARGET_TYPE_CREATURE,
					"target_instance_id": str(event.get("target_instance_id", "")),
					"target_player_id": "",
					"text": "WARD",
					"color": Color(0.74, 0.9, 1.0, 1.0),
					"stack_index": ward_stack,
					"expires_at_ms": now + _screen.DAMAGE_FEEDBACK_DURATION_MS,
				})
			"card_played":
				var cp_source_id := str(event.get("source_instance_id", ""))
				if not cp_source_id.is_empty():
					var cp_card: Dictionary = _screen._card_from_instance_id(cp_source_id)
					if str(cp_card.get("definition_id", "")) == "aw_neu_soulburst":
						soulburst_target_id = str(event.get("target_instance_id", ""))
			"creature_summoned":
				var cs_source_id := str(event.get("source_instance_id", ""))
				if not cs_source_id.is_empty():
					var cs_card: Dictionary = _screen._card_from_instance_id(cs_source_id)
					if str(cs_card.get("definition_id", "")) == "hos_neu_alduin":
						alduin_source_id = cs_source_id
				var cs_stitch_sources: Array = event.get("_stitch_source_creatures", [])
				if cs_stitch_sources.size() == 2:
					stitch_instance_id = cs_source_id
					stitch_source_creatures = cs_stitch_sources
			"creature_destroyed":
				var destroyed_instance_id := str(event.get("instance_id", ""))
				if not alduin_source_id.is_empty() and not destroyed_instance_id.is_empty():
					alduin_destroyed_ids.append(destroyed_instance_id)
				var row_key := "%s:%s" % [str(event.get("lane_id", "")), str(event.get("controller_player_id", ""))]
				var removal_stack := int(removal_stacks.get(row_key, 0))
				removal_stacks[row_key] = removal_stack + 1
				var destroyed_card = _screen._card_from_instance_id(str(event.get("instance_id", "")))
				_screen._removal_feedbacks.append({
					"feedback_id": _screen._next_feedback_id(),
					"lane_id": str(event.get("lane_id", "")),
					"player_id": str(event.get("controller_player_id", "")),
					"instance_id": str(event.get("instance_id", "")),
					"text": "%s falls" % _screen._card_name(destroyed_card),
					"stack_index": removal_stack,
					"expires_at_ms": now + _screen.REMOVAL_FEEDBACK_DURATION_MS,
				})
			"card_drawn":
				if not soulburst_target_id.is_empty():
					_soulburst_deferred_events.append(event)
					continue
				var draw_player_id := str(event.get("player_id", ""))
				var draw_stack := int(draw_stacks.get(draw_player_id, 0))
				draw_stacks[draw_player_id] = draw_stack + 1
				var drawn_instance_id := str(event.get("drawn_instance_id", ""))
				var drawn_card = _screen._card_from_instance_id(drawn_instance_id)
				var show_card_name = _screen._should_reveal_drawn_card(draw_player_id, drawn_card)
				_screen._draw_feedbacks.append({
					"feedback_id": _screen._next_feedback_id(),
					"player_id": draw_player_id,
					"drawn_instance_id": drawn_instance_id,
					"card_name": _screen._card_name(drawn_card) if show_card_name else "",
					"show_card_name": show_card_name,
					"from_rune_break": str(event.get("reason", "")) == _screen.MatchTiming.EVENT_RUNE_BROKEN,
					"stack_index": draw_stack,
					"expires_at_ms": now + _screen.DRAW_FEEDBACK_DURATION_MS,
				})
				if not drawn_instance_id.is_empty():
					_screen._draw_animating_ids.append(drawn_instance_id)
					_animate_card_draw(draw_player_id, drawn_instance_id, draw_stack)
			"rune_broken":
				if not soulburst_target_id.is_empty():
					_soulburst_deferred_events.append(event)
					continue
				var rune_player_id := str(event.get("player_id", ""))
				var rune_stack := int(rune_stacks.get(rune_player_id, 0))
				rune_stacks[rune_player_id] = rune_stack + 1
				_screen._rune_feedbacks.append({
					"feedback_id": _screen._next_feedback_id(),
					"player_id": rune_player_id,
					"threshold": int(event.get("threshold", -1)),
					"draw_card": bool(event.get("draw_card", false)),
					"stack_index": rune_stack,
					"expires_at_ms": now + _screen.RUNE_FEEDBACK_DURATION_MS,
				})
			"card_overdraw":
				if not soulburst_target_id.is_empty():
					_soulburst_deferred_events.append(event)
					continue
				var overdraw_instance_id := str(event.get("instance_id", ""))
				var overdraw_card = _screen._card_from_instance_id(overdraw_instance_id)
				if not overdraw_card.is_empty():
					_screen._feedback._overdraw_queue.append({
						"card": overdraw_card.duplicate(true),
						"player_id": str(event.get("player_id", "")),
					})
			"opponent_top_deck_revealed":
				if str(event.get("controller_player_id", "")) == _screen._local_player_id():
					var revealed_card: Dictionary = event.get("revealed_card", {})
					if not revealed_card.is_empty():
						_screen._animate_deck_card_reveal(revealed_card)
			"opponent_hand_card_revealed":
				if str(event.get("controller_player_id", "")) == _screen._local_player_id():
					var ohcr_card: Dictionary = event.get("revealed_card", {})
					if not ohcr_card.is_empty():
						_animate_opponent_hand_card_reveal(ohcr_card)
			"treasure_hunt_revealed":
				if str(event.get("controller_player_id", "")) == _screen._local_player_id():
					var th_card: Dictionary = event.get("revealed_card", {})
					var th_matches := bool(event.get("matches", false))
					if not th_card.is_empty():
						_screen._animate_treasure_hunt_reveal(th_card, th_matches)
			"treasure_found":
				if str(event.get("controller_player_id", "")) == _screen._local_player_id():
					var th_count := int(event.get("count", 1))
					_screen._queue_status_toast("Treasure Found! (%d)" % th_count, Color(1.0, 0.85, 0.3))
			"card_transformed":
				_screen._queue_status_toast("Card transformed!", Color(0.7, 0.5, 1.0))
			"card_changed":
				_screen._queue_status_toast("Card changed!", Color(0.7, 0.5, 1.0))
			"rune_restored":
				_screen._queue_status_toast("Rune restored!", Color(0.4, 0.8, 1.0))
			"lane_type_changed":
				var lt_type := str(event.get("new_type", ""))
				if not lt_type.is_empty():
					_screen._queue_status_toast("%s Lane!" % lt_type.capitalize(), Color(0.6, 0.5, 0.9))
			"status_removed":
				var sr_status := str(event.get("status_id", "")).to_upper().replace("_", " ")
				if not sr_status.is_empty():
					_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "%s REMOVED" % sr_status, Color(0.9, 0.6, 0.3))
			"magicka_restored":
				if str(event.get("target_player_id", "")) == _screen._local_player_id():
					_screen._queue_status_toast("Magicka restored!", Color(0.3, 0.6, 1.0))
			"card_milled":
				var cm_id := str(event.get("milled_instance_id", ""))
				if not cm_id.is_empty():
					milled_instance_ids.append(cm_id)
			"cost_modified":
				var cm_amount := int(event.get("amount", 0))
				var cm_text := "+%d Cost" % cm_amount if cm_amount > 0 else "%d Cost" % cm_amount
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), cm_text, Color(0.5, 0.4, 0.9))
			"card_stolen_from_discard":
				if str(event.get("to_player_id", "")) == _screen._local_player_id():
					_screen._queue_status_toast("Stole a card from opponent's discard!", Color(0.9, 0.7, 0.2))
			"item_in_hand_modified":
				if str(event.get("target_instance_id", "")) != "":
					var ihm_p := int(event.get("power", 0))
					var ihm_h := int(event.get("health", 0))
					_screen._queue_status_toast("Item buffed +%d/+%d" % [ihm_p, ihm_h], Color(0.8, 0.7, 0.3))
			"keyword_stolen", "status_stolen":
				var ks_id := str(event.get("keyword_id", event.get("status_id", "")))
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "-%s" % ks_id.to_upper(), Color(0.9, 0.3, 0.3))
			"marked_for_destruction":
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "DOOMED", Color(0.9, 0.2, 0.2))
			"temporary_immunity_granted":
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "IMMUNE", Color(1.0, 0.95, 0.6))
			"damage_redirect_set":
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "PROTECTED", Color(0.4, 0.7, 1.0))
			"rune_draw_prevented":
				_screen._queue_status_toast("Opponent's next rune draw prevented!", Color(0.8, 0.4, 0.4))
			"creature_marked":
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "MARKED", Color(0.9, 0.5, 0.2))
			"creature_healed":
				var ch_source_id := str(event.get("source_instance_id", ""))
				var ch_target_id := str(event.get("target_instance_id", ""))
				var ch_amount := int(event.get("amount", 0))
				if not ch_source_id.is_empty() and not ch_target_id.is_empty():
					_animate_heal_stream(ch_source_id, ch_target_id, ch_amount)
			"creature_aimed_at":
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "AIMED", Color(0.9, 0.3, 0.2))
			"marked_for_resummon":
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "RESUMMON", Color(0.8, 0.7, 0.3))
			"double_summon_granted":
				if str(event.get("player_id", "")) == _screen._local_player_id():
					_screen._queue_status_toast("Double Summon this turn!", Color(1.0, 0.85, 0.3))
			"action_learned":
				_screen._queue_status_toast("Learned %s!" % str(event.get("learned_card", "")), Color(0.6, 0.7, 1.0))
			"attribute_changed":
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "→ %s" % str(event.get("attribute", "")).capitalize(), Color(0.7, 0.6, 0.9))
			"card_shuffled_to_deck":
				_screen._queue_status_toast("Card shuffled into deck", Color(0.5, 0.5, 0.6))
			"card_banished":
				_screen._queue_status_toast("Card banished", Color(0.6, 0.3, 0.6))
			"stats_modified":
				var sm_target_id := str(event.get("target_instance_id", ""))
				var sm_power := int(event.get("power_bonus", 0))
				var sm_health := int(event.get("health_bonus", 0))
				if (sm_power != 0 or sm_health != 0) and not sm_target_id.is_empty():
					var sm_sign_p := "+" if sm_power >= 0 else ""
					var sm_sign_h := "+" if sm_health >= 0 else ""
					var sm_color := Color(0.3, 0.9, 0.4) if (sm_power >= 0 and sm_health >= 0) else Color(0.9, 0.3, 0.3)
					_screen._queue_creature_toast(sm_target_id, "%s%d/%s%d" % [sm_sign_p, sm_power, sm_sign_h, sm_health], sm_color)
			"attached_item_detached":
				_screen._queue_creature_toast(str(event.get("host_instance_id", "")), "ITEM DESTROYED", Color(0.9, 0.4, 0.2))
			"card_discarded":
				var cd_revealed: Dictionary = event.get("revealed_card", {})
				if not cd_revealed.is_empty():
					var cd_local: String = str(_screen._local_player_id())
					var cd_controller: String = str(event.get("controller_player_id", ""))
					if cd_controller == cd_local or (cd_controller.is_empty() and str(event.get("player_id", "")) == cd_local):
						_screen._animate_deck_card_reveal(cd_revealed)
				_screen._queue_status_toast("Card discarded", Color(0.6, 0.4, 0.4))
			"card_stolen":
				_screen._queue_status_toast("Card stolen!", Color(0.9, 0.6, 0.2))
			"card_consumed":
				_screen._queue_status_toast("Creature consumed", Color(0.5, 0.3, 0.6))
			"keyword_granted":
				var kg_kw := str(event.get("keyword_id", "")).to_upper()
				if not kg_kw.is_empty():
					_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "+%s" % kg_kw, Color(0.4, 0.8, 0.5))
			"ability_granted":
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "+ABILITY", Color(0.5, 0.7, 0.9))
			"creatures_swapped":
				_screen._queue_creature_toast(str(event.get("source_instance_id", "")), "SWAPPED", Color(0.8, 0.6, 0.3))
				_screen._queue_creature_toast(str(event.get("target_instance_id", "")), "SWAPPED", Color(0.8, 0.6, 0.3))
			"all_creatures_shuffled":
				_screen._queue_status_toast("All creatures shuffled into decks!", Color(0.7, 0.5, 0.9))
			"summons_retriggered":
				_screen._queue_status_toast("Re-triggering all summon abilities!", Color(0.9, 0.8, 0.3))
			"deck_transformed":
				_screen._queue_status_toast("Deck transformed!", Color(0.7, 0.4, 0.9))
			"mass_consume":
				var mc_count := int(event.get("count", 0))
				_screen._queue_status_toast("Consumed %d creature%s from discard!" % [mc_count, "s" if mc_count != 1 else ""], Color(0.5, 0.3, 0.6))
			"lane_aoe_damage":
				var lad_lane_id := str(event.get("lane_id", ""))
				var lad_amount := int(event.get("amount", 0))
				_screen._queue_status_toast("%d damage to all creatures in lane!" % lad_amount, Color(0.9, 0.3, 0.2))
			"random_sub_effect_chosen":
				var rse_source_id := str(event.get("source_instance_id", ""))
				var rse_card: Dictionary = _screen._card_from_instance_id(rse_source_id)
				if not rse_card.is_empty():
					_screen._feedback._animate_scroll_flip(rse_card, str(event.get("label", "")), str(event.get("description", "")))
			"counter_updated":
				var cu_value := int(event.get("value", 0))
				var cu_threshold := int(event.get("threshold", 0))
				_screen._queue_creature_toast(str(event.get("source_instance_id", "")), "%d/%d" % [cu_value, cu_threshold], Color.WHITE)
			"invade_triggered":
				var it_source_id := str(event.get("source_instance_id", ""))
				if mankar_camoran_id.is_empty() and not it_source_id.is_empty():
					var it_source_card: Dictionary = _screen._card_from_instance_id(it_source_id)
					if str(it_source_card.get("definition_id", "")) == "joo_dual_mankar_camoran":
						mankar_camoran_id = it_source_id
			"oblivion_gate_upgraded":
				var ogu_id := str(event.get("source_instance_id", ""))
				if not ogu_id.is_empty():
					gate_upgrade_id = ogu_id
				_screen._queue_creature_toast(ogu_id, "GATE LEVEL UP!", Color(0.9, 0.3, 0.1))
	if not milled_instance_ids.is_empty():
		var milled_cards: Array = []
		for mid in milled_instance_ids:
			var mcard: Dictionary = _screen._card_from_instance_id(mid)
			if not mcard.is_empty():
				milled_cards.append(mcard)
		if not milled_cards.is_empty():
			_screen._feedback._animate_mill_reveal(milled_cards)
	if not stitch_instance_id.is_empty() and stitch_source_creatures.size() == 2:
		_animate_abomination_stitch(stitch_instance_id, stitch_source_creatures)
	if not alduin_source_id.is_empty() and not alduin_destroyed_ids.is_empty():
		_animate_alduin_board_wipe(alduin_source_id, alduin_destroyed_ids)
	if not soulburst_target_id.is_empty():
		var sb_btn: Button = _screen._card_buttons.get(soulburst_target_id) as Button
		if sb_btn != null and is_instance_valid(sb_btn):
			var sb_size: Vector2 = sb_btn.get_meta("card_size", sb_btn.size)
			var sb_pos: Vector2 = sb_btn.global_position
			_soulburst_pending = {
				"target_instance_id": soulburst_target_id,
				"target_position": sb_pos,
				"target_size": sb_size,
			}
	if not mankar_camoran_id.is_empty():
		_animate_mankar_camoran_glow(mankar_camoran_id)
	if not gate_upgrade_id.is_empty():
		_animate_gate_upgrade_glow(gate_upgrade_id)


func _animate_card_draw(player_id: String, instance_id: String, stack_index: int) -> void:
	var is_local: bool = player_id == _screen.PLAYER_ORDER[1]
	var card_size: Vector2 = _screen._hand_card_display_size()
	var viewport_size: Vector2 = _screen.get_viewport_rect().size

	# Build a card-back panel
	var card_panel := PanelContainer.new()
	card_panel.name = "draw_anim_%s" % instance_id
	card_panel.custom_minimum_size = card_size
	card_panel.size = card_size
	_screen._apply_panel_style(card_panel, Color(0.35, 0.22, 0.12, 0.98), Color(0.57, 0.44, 0.27, 0.92), 2, 0)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.z_index = 480

	# Calculate the destination: right edge of the player's hand area
	var dest_y: float
	if is_local:
		dest_y = viewport_size.y - card_size.y * 0.35
	else:
		dest_y = -(card_size.y * 0.90)
	# Estimate hand position — rightmost card slot
	var player_state: Dictionary = {}
	for p in _screen._match_state.get("players", []):
		if str(p.get("player_id", "")) == player_id:
			player_state = p
			break
	var hand_count := int(player_state.get("hand", []).size())
	var overlap_step := card_size.x * 0.45
	var total_width := card_size.x + overlap_step * float(max(0, hand_count - 1))
	var start_x: float = (viewport_size.x - total_width) * 0.5
	var dest_x: float = start_x + overlap_step * float(max(0, hand_count - 1))

	# Start off-screen right
	var start_pos := Vector2(viewport_size.x + card_size.x * 0.1, dest_y)
	var end_pos := Vector2(dest_x, dest_y)
	# Stagger multiple draws slightly
	var delay := float(stack_index) * 0.12

	card_panel.position = start_pos
	card_panel.pivot_offset = card_size * 0.5

	_screen._prophecy_card_overlay.add_child(card_panel)

	var tween: Tween = _screen.create_tween()
	if delay > 0.0:
		card_panel.modulate = Color(1, 1, 1, 0)
		tween.tween_interval(delay)
		tween.tween_property(card_panel, "modulate:a", 1.0, 0.05)
	tween.tween_property(card_panel, "position", end_pos, _screen.DRAW_ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		card_panel.queue_free()
		if instance_id in _screen._draw_animating_ids:
			_screen._draw_animating_ids.erase(instance_id)
			_screen._refresh._refresh_ui()
	)


func _clear_feedback_state() -> void:
	_screen._feedback._kill_active_float_tweens()
	_screen._attack_feedbacks.clear()
	_screen._damage_feedbacks.clear()
	_screen._removal_feedbacks.clear()
	_screen._draw_feedbacks.clear()
	_screen._draw_animating_ids.clear()
	_screen._rune_feedbacks.clear()


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
	_screen._apply_panel_style(banner, fill, border, 1, 6)
	container.add_child(banner)
	var box = _screen._build_panel_box(banner, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween = _screen.create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(_screen._queue_free_weak.bind(weakref(banner)))


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
	_screen._apply_panel_style(banner, fill, border, 1, 6)
	container.add_child(banner)
	var box = _screen._build_panel_box(banner, 0, 4)
	var label := Label.new()
	label.name = "%s_label" % name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", font_color)
	label.text = text
	box.add_child(label)
	var tween = _screen.create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.finished.connect(_screen._queue_free_weak.bind(weakref(banner)))


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
	var tween = _screen.create_tween()
	tween.tween_property(label, "position", Vector2(0, -24), 0.22)
	tween.parallel().tween_property(label, "scale", Vector2(1.08, 1.08), 0.18)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.7)
	tween.finished.connect(_screen._queue_free_weak.bind(weakref(label)))


func _detach_prophecy_card(instance_id: String) -> void:
	_screen._cancel_detached_card_silent()
	_screen._selected_instance_id = instance_id
	var card = _screen._card_from_instance_id(instance_id)
	var preview_size = _screen._hand_card_display_size()
	var base_size = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var wrapper := Control.new()
	wrapper.name = "detached_prophecy_card_%s" % instance_id
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.z_index = 500
	wrapper.size = base_size
	wrapper.custom_minimum_size = base_size
	var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
	component.mouse_filter = Control.MOUSE_FILTER_IGNORE
	component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	component.apply_card(card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
	wrapper.add_child(component)
	_screen.add_child(wrapper)
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	var mouse_pos = _screen.get_viewport().get_mouse_position()
	wrapper.position = mouse_pos + Vector2(-preview_size.x * 0.5, -preview_size.y * 0.62)
	_screen._hand._detached_card_state = {
		"instance_id": instance_id,
		"preview": wrapper,
		"card_data": card.duplicate(true),
	}
	# Hide the prophecy overlay while dragging — it rebuilds on cancel via _refresh_ui
	var vbox: Control = _screen._overlays._prophecy_overlay_state.get("vbox")
	if vbox != null and is_instance_valid(vbox):
		vbox.visible = false
	_screen._status_message = "Click a friendly lane slot to summon %s." % _screen._card_name(card)
	_screen._refresh_ui()


func _animate_abomination_stitch(abomination_instance_id: String, source_creatures: Array) -> void:
	var viewport_size: Vector2 = _screen.get_viewport_rect().size
	var center: Vector2 = viewport_size * 0.5
	var card_size: Vector2 = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.CREATURE_BOARD_MINIMUM_SIZE
	var presentation_mode: String = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_CREATURE_BOARD_MINIMAL

	# Hide the Abomination from the board until the animation finishes
	_stitch_hidden_id = abomination_instance_id

	# Build animation container overlay
	var container := Control.new()
	container.name = "abomination_stitch"
	container.z_index = 490
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(container)

	# Dimmer — blocks board interaction during animation
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
	dimmer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.z_index = 494
	container.add_child(dimmer)

	# Build card wrappers for the two source creatures, side by side
	var gap := 40.0
	var card_scale := 1.0
	var left_pos := Vector2(center.x - card_size.x - gap * 0.5, center.y - card_size.y * 0.5)
	var right_pos := Vector2(center.x + gap * 0.5, center.y - card_size.y * 0.5)

	var left_wrapper := Control.new()
	left_wrapper.name = "stitch_card_left"
	left_wrapper.size = card_size
	left_wrapper.custom_minimum_size = card_size
	left_wrapper.position = left_pos
	left_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_wrapper.z_index = 500
	left_wrapper.pivot_offset = card_size * 0.5
	if source_creatures.size() > 0 and not source_creatures[0].is_empty():
		var left_component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		left_component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left_component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		left_component.apply_card(source_creatures[0], presentation_mode)
		left_wrapper.add_child(left_component)
	container.add_child(left_wrapper)

	var right_wrapper := Control.new()
	right_wrapper.name = "stitch_card_right"
	right_wrapper.size = card_size
	right_wrapper.custom_minimum_size = card_size
	right_wrapper.position = right_pos
	right_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_wrapper.z_index = 500
	right_wrapper.pivot_offset = card_size * 0.5
	if source_creatures.size() > 1 and not source_creatures[1].is_empty():
		var right_component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		right_component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		right_component.apply_card(source_creatures[1], presentation_mode)
		right_wrapper.add_child(right_component)
	container.add_child(right_wrapper)

	# White glow overlay — covers both cards during the merge flash
	var glow_rect := ColorRect.new()
	glow_rect.name = "stitch_glow"
	glow_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	glow_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_rect.z_index = 510
	container.add_child(glow_rect)

	# Abomination card wrapper — hidden initially, revealed after glow
	var abomination_card: Dictionary = _screen._card_from_instance_id(abomination_instance_id)
	var abom_wrapper := Control.new()
	abom_wrapper.name = "stitch_abomination"
	abom_wrapper.size = card_size
	abom_wrapper.custom_minimum_size = card_size
	abom_wrapper.position = center - card_size * 0.5
	abom_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	abom_wrapper.z_index = 505
	abom_wrapper.pivot_offset = card_size * 0.5
	abom_wrapper.modulate = Color(1, 1, 1, 0)
	if not abomination_card.is_empty():
		var abom_component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		abom_component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		abom_component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		abom_component.apply_card(abomination_card, presentation_mode)
		abom_wrapper.add_child(abom_component)
	container.add_child(abom_wrapper)

	# ── Animation timing ──
	var fade_in_duration := 0.3
	var hold_duration := 0.5
	var slide_duration := 0.5
	var glow_in_duration := 0.2
	var glow_hold_duration := 0.15
	var glow_out_duration := 0.3
	var abom_hold_duration := 0.6
	var move_duration := 0.5

	var slide_start: float = fade_in_duration + hold_duration
	var glow_start: float = slide_start + slide_duration
	var abom_reveal_start: float = glow_start + glow_in_duration + glow_hold_duration
	var abom_hold_start: float = abom_reveal_start + glow_out_duration
	var move_start: float = abom_hold_start + abom_hold_duration

	# Merged center position (both cards overlap at center)
	var merge_pos := center - card_size * 0.5

	# Phase 1: Fade in dimmer + both cards appear
	left_wrapper.modulate = Color(1, 1, 1, 0)
	right_wrapper.modulate = Color(1, 1, 1, 0)
	left_wrapper.scale = Vector2(0.9, 0.9)
	right_wrapper.scale = Vector2(0.9, 0.9)

	var dim_tween: Tween = _screen.create_tween()
	dim_tween.tween_property(dimmer, "color:a", 0.5, fade_in_duration)

	var left_enter: Tween = _screen.create_tween()
	left_enter.tween_property(left_wrapper, "modulate:a", 1.0, fade_in_duration).set_ease(Tween.EASE_OUT)
	left_enter.parallel().tween_property(left_wrapper, "scale", Vector2(card_scale, card_scale), fade_in_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var right_enter: Tween = _screen.create_tween()
	right_enter.tween_property(right_wrapper, "modulate:a", 1.0, fade_in_duration).set_ease(Tween.EASE_OUT)
	right_enter.parallel().tween_property(right_wrapper, "scale", Vector2(card_scale, card_scale), fade_in_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Phase 2: After hold, cards slide toward each other and overlap at center
	var left_slide: Tween = _screen.create_tween()
	left_slide.tween_interval(slide_start)
	left_slide.tween_property(left_wrapper, "position", merge_pos, slide_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	var right_slide: Tween = _screen.create_tween()
	right_slide.tween_interval(slide_start)
	right_slide.tween_property(right_wrapper, "position", merge_pos, slide_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	# Phase 3: White glow flash when they overlap
	var glow_tween: Tween = _screen.create_tween()
	glow_tween.tween_interval(glow_start)
	glow_tween.tween_property(glow_rect, "color:a", 0.85, glow_in_duration).set_ease(Tween.EASE_IN)
	glow_tween.tween_interval(glow_hold_duration)
	# During glow: hide source cards, reveal Abomination
	glow_tween.tween_callback(func():
		left_wrapper.visible = false
		right_wrapper.visible = false
		abom_wrapper.modulate = Color(1, 1, 1, 1)
		abom_wrapper.scale = Vector2(1.15, 1.15)
	)
	glow_tween.tween_property(glow_rect, "color:a", 0.0, glow_out_duration).set_ease(Tween.EASE_OUT)

	# Abomination settles to normal scale
	var abom_scale_tween: Tween = _screen.create_tween()
	abom_scale_tween.tween_interval(abom_reveal_start)
	abom_scale_tween.tween_property(abom_wrapper, "scale", Vector2(1.0, 1.0), glow_out_duration + 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Phase 4: After hold, Abomination flies to board position
	var dim_exit: Tween = _screen.create_tween()
	dim_exit.tween_interval(move_start)
	dim_exit.tween_property(dimmer, "color:a", 0.0, 0.4).set_ease(Tween.EASE_IN)

	var card_exit: Tween = _screen.create_tween()
	card_exit.tween_interval(move_start)
	card_exit.tween_callback(func():
		var board_btn: Button = _screen._card_buttons.get(abomination_instance_id) as Button
		if board_btn != null and is_instance_valid(board_btn):
			var board_size: Vector2 = board_btn.get_meta("card_size", board_btn.size)
			var board_pos: Vector2 = board_btn.global_position
			var board_center: Vector2 = board_pos + board_size * 0.5
			var target_pos: Vector2 = board_center - card_size * 0.5
			var target_scale_val: float = board_size.x / card_size.x
			var t: Tween = _screen.create_tween()
			t.set_parallel(true)
			t.tween_property(abom_wrapper, "position", target_pos, move_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
			t.tween_property(abom_wrapper, "scale", Vector2(target_scale_val, target_scale_val), move_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			var t: Tween = _screen.create_tween()
			t.tween_property(abom_wrapper, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	)

	# Phase 5: Cleanup — reveal the real board card
	var cleanup: Tween = _screen.create_tween()
	cleanup.tween_interval(move_start + move_duration)
	cleanup.tween_callback(func():
		_stitch_hidden_id = ""
		_screen._refresh._refresh_ui()
		if is_instance_valid(container):
			container.queue_free()
	)


func _animate_alduin_board_wipe(alduin_instance_id: String, destroyed_ids: Array) -> void:
	var viewport_size: Vector2 = _screen.get_viewport_rect().size
	var center: Vector2 = viewport_size * 0.5
	# Ring must expand far enough to clear all screen corners
	var max_radius: float = center.length() + 80.0

	# Hide Alduin from the board until the animation finishes
	_board_wipe_hidden_id = alduin_instance_id

	# Snapshot destroyed creature buttons before _refresh_ui() frees them
	var targets: Array = []
	for did in destroyed_ids:
		var btn: Button = _screen._card_buttons.get(did) as Button
		if btn != null and is_instance_valid(btn):
			var btn_size: Vector2 = btn.get_meta("card_size", btn.size)
			var btn_pos: Vector2 = btn.global_position
			var btn_center: Vector2 = btn_pos + btn_size * 0.5
			var dist: float = center.distance_to(btn_center)
			targets.append({"position": btn_pos, "size": btn_size, "distance": dist})

	# Build animation container overlay
	var container := Control.new()
	container.name = "alduin_board_wipe"
	container.z_index = 490
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(container)

	# Dimmer behind Alduin card — MOUSE_FILTER_STOP blocks all board interactions
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
	dimmer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.z_index = 494
	container.add_child(dimmer)

	# Display Alduin card in the center of the screen, scaled up for drama
	var alduin_card: Dictionary = _screen._card_from_instance_id(alduin_instance_id)
	var card_size: Vector2 = _screen.CARD_DISPLAY_COMPONENT_SCRIPT.FULL_MINIMUM_SIZE
	var card_scale := 1.5
	var card_wrapper := Control.new()
	card_wrapper.name = "alduin_center_card"
	card_wrapper.size = card_size
	card_wrapper.custom_minimum_size = card_size
	card_wrapper.position = center - card_size * 0.5
	card_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_wrapper.z_index = 500
	card_wrapper.pivot_offset = card_size * 0.5
	if not alduin_card.is_empty():
		var component = _screen.CARD_DISPLAY_COMPONENT_SCENE.instantiate()
		component.mouse_filter = Control.MOUSE_FILTER_IGNORE
		component.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		component.apply_card(alduin_card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_wrapper.add_child(component)
	container.add_child(card_wrapper)

	# Create card stand-in overlays that persist until the ring reaches them
	var card_overlays: Array = []
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var overlay := PanelContainer.new()
		overlay.name = "alduin_card_%d" % i
		overlay.position = t["position"]
		overlay.size = t["size"]
		overlay.custom_minimum_size = t["size"]
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 489
		_screen._apply_panel_style(overlay, Color(0.18, 0.14, 0.10, 0.95), Color(0.4, 0.3, 0.2, 0.8), 1, 4)
		container.add_child(overlay)
		card_overlays.append(overlay)

	# Build the expanding fire ring — Line2D circle centered on screen
	var ring := Line2D.new()
	ring.name = "alduin_ring"
	ring.width = 40.0
	ring.default_color = Color.WHITE
	ring.z_index = 495
	ring.texture_mode = Line2D.LINE_TEXTURE_TILE
	ring.position = center
	# Fire shader on the ring
	var fire_shader := Shader.new()
	fire_shader.code = _alduin_fire_shader_code()
	var fire_material := ShaderMaterial.new()
	fire_material.shader = fire_shader
	ring.material = fire_material
	container.add_child(ring)

	# Animation timing
	var ring_segments := 64
	var ring_duration := 2.0
	var hold_duration := 0.6

	# Phase 1: Fade in dimmer + Alduin card, hold briefly
	var dim_tween: Tween = _screen.create_tween()
	dim_tween.tween_property(dimmer, "color:a", 0.5, 0.3)

	var card_enter_tween: Tween = _screen.create_tween()
	card_wrapper.modulate = Color(1, 1, 1, 0)
	card_wrapper.scale = Vector2(card_scale * 0.85, card_scale * 0.85)
	card_enter_tween.tween_property(card_wrapper, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	card_enter_tween.parallel().tween_property(card_wrapper, "scale", Vector2(card_scale, card_scale), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Phase 2: After hold, expand the fire ring outward from center
	var ring_tween: Tween = _screen.create_tween()
	ring_tween.tween_interval(hold_duration)
	ring_tween.tween_method(_set_ring_radius.bind(ring, ring_segments), 0.0, max_radius, ring_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Fade dimmer as ring expands, then animate Alduin card to its board position
	var move_start: float = hold_duration + ring_duration + 0.4
	var move_duration := 0.5
	var dim_exit_tween: Tween = _screen.create_tween()
	dim_exit_tween.tween_interval(move_start)
	dim_exit_tween.tween_property(dimmer, "color:a", 0.0, 0.4).set_ease(Tween.EASE_IN)

	var card_exit_tween: Tween = _screen.create_tween()
	card_exit_tween.tween_interval(move_start)
	card_exit_tween.tween_callback(func():
		# Look up Alduin's board button position (hidden but exists after refresh)
		var board_btn: Button = _screen._card_buttons.get(alduin_instance_id) as Button
		if board_btn != null and is_instance_valid(board_btn):
			var board_size: Vector2 = board_btn.get_meta("card_size", board_btn.size)
			var board_pos: Vector2 = board_btn.global_position
			var board_center: Vector2 = board_pos + board_size * 0.5
			# Animate to board position — target position accounts for pivot_offset
			var target_pos: Vector2 = board_center - card_size * 0.5
			var target_scale_val: float = board_size.x / card_size.x
			var t: Tween = _screen.create_tween()
			t.set_parallel(true)
			t.tween_property(card_wrapper, "position", target_pos, move_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
			t.tween_property(card_wrapper, "scale", Vector2(target_scale_val, target_scale_val), move_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			# Fallback: just fade out if we can't find the board position
			var t: Tween = _screen.create_tween()
			t.tween_property(card_wrapper, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	)

	# For each card overlay, trigger glow + fade when the ring reaches its distance
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var overlay: PanelContainer = card_overlays[i]
		var dist: float = t["distance"]
		# Map distance to time within the ring expansion phase
		var progress: float = dist / max_radius
		var delay: float = hold_duration + clampf(progress * ring_duration, 0.05, ring_duration)
		var glow_tween: Tween = _screen.create_tween()
		glow_tween.tween_interval(delay)
		glow_tween.tween_property(overlay, "modulate", Color(3.0, 2.0, 1.0, 1.0), 0.12).set_ease(Tween.EASE_OUT)
		glow_tween.tween_property(overlay, "modulate", Color(1.5, 0.8, 0.4, 0.0), 0.5).set_ease(Tween.EASE_IN)
		glow_tween.parallel().tween_property(overlay, "scale", Vector2(0.7, 0.7), 0.5).set_ease(Tween.EASE_IN)

	# Clean up container after card reaches board position
	var cleanup_tween: Tween = _screen.create_tween()
	cleanup_tween.tween_interval(move_start + move_duration)
	cleanup_tween.tween_callback(func():
		_board_wipe_hidden_id = ""
		_screen._refresh._refresh_ui()
		if is_instance_valid(container):
			container.queue_free()
	)


func _animate_soulburst(data: Dictionary) -> void:
	var viewport_size: Vector2 = _screen.get_viewport_rect().size
	var target_pos: Vector2 = data.get("target_position", Vector2.ZERO)
	var target_size: Vector2 = data.get("target_size", Vector2(100, 140))
	var target_center: Vector2 = target_pos + target_size * 0.5
	var max_radius: float = viewport_size.length() + 80.0

	# Keep real card button visible — burn overlay renders on top during glow
	var target_id := str(data.get("target_instance_id", ""))
	_soulburst_target_id = target_id
	var real_btn: Button = _screen._card_buttons.get(target_id) as Button
	if real_btn != null and is_instance_valid(real_btn):
		real_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Build animation container overlay
	var container := Control.new()
	container.name = "soulburst_animation"
	container.z_index = 490
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(container)

	# Dimmer — blocks board interaction during animation
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
	dimmer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.z_index = 489
	container.add_child(dimmer)

	# Target creature stand-in — purple burning card
	var target_overlay := ColorRect.new()
	target_overlay.name = "soulburst_target"
	target_overlay.position = target_pos
	target_overlay.size = target_size
	target_overlay.custom_minimum_size = target_size
	target_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_overlay.z_index = 495
	target_overlay.pivot_offset = target_size * 0.5
	target_overlay.color = Color.WHITE
	var burn_shader := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = _soulburst_burn_shader_code()
	burn_shader.shader = shader
	burn_shader.set_shader_parameter("intensity", 0.0)
	target_overlay.material = burn_shader
	container.add_child(target_overlay)

	# Purple ring — Line2D circle centered on target creature
	var ring := Line2D.new()
	ring.name = "soulburst_ring"
	ring.width = 24.0
	ring.default_color = Color(0.6, 0.15, 0.85, 0.9)
	ring.z_index = 496
	ring.antialiased = true
	ring.position = target_center
	container.add_child(ring)

	# Animation timing
	var glow_duration := 1.2
	var ring_duration := 0.6

	# Phase 1: Fade in dimmer + target burns brighter over time
	var dim_tween: Tween = _screen.create_tween()
	dim_tween.tween_property(dimmer, "color:a", 0.35, 0.3)

	target_overlay.modulate = Color(1, 1, 1, 0)
	var glow_tween: Tween = _screen.create_tween()
	glow_tween.tween_property(target_overlay, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	# Ramp shader intensity from 0 to 1 over the glow phase
	glow_tween.parallel().tween_method(func(v: float): burn_shader.set_shader_parameter("intensity", v), 0.0, 1.0, glow_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Phase 2: Card vanishes instantly when ring fires — both real button and overlay
	var ring_segments := 48
	var ring_tween: Tween = _screen.create_tween()
	ring_tween.tween_interval(glow_duration)
	ring_tween.tween_callback(func():
		target_overlay.visible = false
		if real_btn != null and is_instance_valid(real_btn):
			real_btn.modulate.a = 0.0
	)
	ring_tween.tween_method(_set_ring_radius.bind(ring, ring_segments), 0.0, max_radius, ring_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Ring fades as it expands
	var ring_fade_tween: Tween = _screen.create_tween()
	ring_fade_tween.tween_interval(glow_duration)
	ring_fade_tween.tween_property(ring, "default_color:a", 0.0, ring_duration).set_ease(Tween.EASE_IN)

	# Phase 3: Cleanup — refresh UI to show aftermath (banished + damage)
	var total_duration: float = glow_duration + ring_duration + 0.15
	var cleanup_tween: Tween = _screen.create_tween()
	cleanup_tween.tween_interval(total_duration)
	cleanup_tween.tween_property(dimmer, "color:a", 0.0, 0.25)
	cleanup_tween.tween_callback(func():
		_soulburst_target_id = ""
		# Replay deferred rune/draw events that were suppressed during the animation
		var deferred := _soulburst_deferred_events.duplicate()
		_soulburst_deferred_events.clear()
		if not deferred.is_empty():
			_record_feedback_from_events(deferred)
		_screen._refresh._refresh_ui()
		var pending_visual: Array = _screen._match_state.get("pending_visual_effects", [])
		if not pending_visual.is_empty():
			_screen._feedback._start_deferred_visual_animation.call_deferred(pending_visual)
		else:
			_screen._targeting._check_pending_secondary_target()
			_screen._targeting._check_pending_summon_effect_target()
			_screen._selection._check_pending_forced_play()
		if is_instance_valid(container):
			container.queue_free()
	)


func _animate_opponent_hand_card_reveal(revealed_card: Dictionary) -> void:
	var card_size = _screen._hand_card_display_size()
	var viewport_size = _screen.get_viewport_rect().size

	var card_back := PanelContainer.new()
	card_back.name = "hand_reveal_card_back"
	card_back.custom_minimum_size = card_size
	card_back.size = card_size
	_screen._apply_panel_style(card_back, Color(0.18, 0.12, 0.30, 0.98), Color(0.55, 0.35, 0.65, 0.92), 2, 0)

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
		component.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		component.apply_card(revealed_card, _screen.CARD_DISPLAY_COMPONENT_SCRIPT.PRESENTATION_FULL)
		card_back.add_child(component)
	)
	tween.tween_property(card_back, "scale:x", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(card_back, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func():
		if is_instance_valid(card_back):
			card_back.queue_free()
		_screen._refresh_ui()
	)


func _set_ring_radius(radius: float, ring: Line2D, segments: int) -> void:
	ring.clear_points()
	for i in range(segments + 1):
		var angle: float = TAU * float(i) / float(segments)
		ring.add_point(Vector2(cos(angle) * radius, sin(angle) * radius))


func _alduin_fire_shader_code() -> String:
	return """
shader_type canvas_item;

// Procedural noise helpers
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		val += amp * noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 uv = UV;

	// Vertical distance from center (0 at center, 1 at edges)
	float edge_dist = abs(uv.y - 0.5) * 2.0;

	// Turbulent fire noise — scrolls upward and across
	vec2 noise_uv = vec2(uv.x * 6.0, uv.y * 3.0 - TIME * 4.0);
	float n = fbm(noise_uv);
	float n2 = fbm(noise_uv * 1.8 + vec2(5.3, -TIME * 2.0));

	// Shape: fade at edges with noisy boundary
	float shape = 1.0 - smoothstep(0.3 + n * 0.25, 0.9, edge_dist);

	// Color gradient: white core -> yellow -> orange -> red -> transparent
	vec3 col_core = vec3(1.0, 0.95, 0.8);
	vec3 col_mid = vec3(1.0, 0.6, 0.1);
	vec3 col_edge = vec3(0.8, 0.15, 0.02);
	float color_t = edge_dist + n2 * 0.3;
	vec3 col = mix(col_core, col_mid, smoothstep(0.0, 0.4, color_t));
	col = mix(col, col_edge, smoothstep(0.35, 0.8, color_t));

	// Flickering intensity
	float flicker = 0.85 + 0.15 * noise(vec2(uv.x * 3.0, TIME * 8.0));

	COLOR = vec4(col * flicker, shape * 0.95);
}
"""


func _soulburst_burn_shader_code() -> String:
	return """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p);
		p *= 2.2;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 uv = UV;

	// Turbulent fire noise — scrolls upward
	vec2 noise_uv = vec2(uv.x * 4.0, uv.y * 3.0 - TIME * 3.0);
	float n = fbm(noise_uv);
	float n2 = fbm(noise_uv * 1.5 + vec2(3.7, -TIME * 1.5));

	// Edge burn: fire creeps inward from edges as intensity rises
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_x, edge_y);
	float burn_edge = smoothstep(0.0, 0.25 + (1.0 - intensity) * 0.3, edge_dist + n * 0.15);

	// Color: dark purple core -> bright magenta/violet -> white-hot at peak
	vec3 col_dark = vec3(0.15, 0.02, 0.25);
	vec3 col_purple = vec3(0.55, 0.1, 0.75);
	vec3 col_bright = vec3(0.85, 0.4, 1.0);
	vec3 col_hot = vec3(1.0, 0.85, 1.0);

	float color_t = intensity * (0.7 + n2 * 0.3);
	vec3 col = mix(col_dark, col_purple, smoothstep(0.0, 0.3, color_t));
	col = mix(col, col_bright, smoothstep(0.25, 0.65, color_t));
	col = mix(col, col_hot, smoothstep(0.6, 1.0, color_t));

	// Flickering embers
	float flicker = 0.8 + 0.2 * noise(vec2(uv.x * 5.0, TIME * 10.0));

	// Overall alpha: visible card shape that brightens with intensity
	float alpha = burn_edge * (0.6 + intensity * 0.4);

	// Emission boost — gets overbright near the end
	float emission = 1.0 + intensity * intensity * 2.0;

	COLOR = vec4(col * flicker * emission, alpha);
}
"""


func _animate_mankar_camoran_glow(instance_id: String) -> void:
	var btn: Button = _screen._card_buttons.get(instance_id) as Button
	if btn == null or not is_instance_valid(btn):
		return
	var card_size: Vector2 = btn.get_meta("card_size", btn.size)
	var card_pos: Vector2 = btn.global_position
	if _floating_card_ids.has(instance_id):
		card_pos += _screen.LANE_CARD_FLOAT_OFFSET

	var padding := 14.0
	var overlay_size := card_size + Vector2(padding * 2, padding * 2)
	var overlay := ColorRect.new()
	overlay.name = "mankar_magic_glow"
	overlay.position = card_pos - Vector2(padding, padding)
	overlay.size = overlay_size
	overlay.custom_minimum_size = overlay_size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 480
	overlay.color = Color.WHITE

	var shader := Shader.new()
	shader.code = _mankar_magic_shader_code()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.0)
	# Tell the shader where the card face is so it stays transparent there
	mat.set_shader_parameter("padding_uv", Vector2(padding / overlay_size.x, padding / overlay_size.y))
	overlay.material = mat
	_screen.add_child(overlay)

	overlay.modulate = Color(1, 1, 1, 0)
	var tween: Tween = _screen.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 0.3)
	tween.tween_interval(0.7)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)


func _animate_gate_upgrade_glow(instance_id: String) -> void:
	var btn: Button = _screen._card_buttons.get(instance_id) as Button
	if btn == null or not is_instance_valid(btn):
		return
	var card_size: Vector2 = btn.get_meta("card_size", btn.size)
	var card_pos: Vector2 = btn.global_position

	var padding := 10.0
	var overlay := ColorRect.new()
	overlay.name = "gate_fire_glow"
	overlay.position = card_pos - Vector2(padding, padding)
	overlay.size = card_size + Vector2(padding * 2, padding * 2)
	overlay.custom_minimum_size = overlay.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 480
	overlay.color = Color.WHITE

	var shader := Shader.new()
	shader.code = _gate_fire_shader_code()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.0)
	overlay.material = mat
	_screen.add_child(overlay)

	var embers := GPUParticles2D.new()
	embers.name = "gate_embers"
	embers.amount = 40
	embers.lifetime = 1.3
	embers.preprocess = 0.25
	embers.randomness = 0.55
	embers.position = Vector2(overlay.size.x * 0.5, overlay.size.y * 0.55)
	embers.visibility_rect = Rect2(-overlay.size.x, -overlay.size.y * 1.2, overlay.size.x * 2, overlay.size.y * 2)
	var ember_mat := ParticleProcessMaterial.new()
	ember_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ember_mat.emission_box_extents = Vector3(overlay.size.x * 0.42, overlay.size.y * 0.3, 0.0)
	ember_mat.direction = Vector3(0, -1, 0)
	ember_mat.spread = 32.0
	ember_mat.initial_velocity_min = 35.0
	ember_mat.initial_velocity_max = 90.0
	ember_mat.gravity = Vector3(0, -45.0, 0)
	ember_mat.scale_min = 1.4
	ember_mat.scale_max = 3.2
	ember_mat.angular_velocity_min = -120.0
	ember_mat.angular_velocity_max = 120.0
	ember_mat.turbulence_enabled = true
	ember_mat.turbulence_noise_strength = 30.0
	ember_mat.turbulence_noise_scale = 2.0
	var ember_ramp := GradientTexture1D.new()
	var ember_gradient := Gradient.new()
	ember_gradient.set_color(0, Color(1.0, 0.75, 0.25, 1.0))
	ember_gradient.add_point(0.35, Color(1.0, 0.35, 0.08, 0.95))
	ember_gradient.set_color(2, Color(0.25, 0.02, 0.0, 0.0))
	ember_ramp.gradient = ember_gradient
	ember_mat.color_ramp = ember_ramp
	embers.process_material = ember_mat
	embers.emitting = true
	overlay.add_child(embers)

	overlay.modulate = Color(1, 1, 1, 0)
	var tween: Tween = _screen.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 0.4)
	tween.parallel().tween_callback(func():
		if is_instance_valid(embers):
			embers.emitting = false
	).set_delay(1.3)
	tween.tween_interval(0.8)
	tween.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 1.0, 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(overlay, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)


func _mankar_magic_shader_code() -> String:
	return """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 padding_uv = vec2(0.1, 0.08);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		val += amp * noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 uv = UV;

	// Edge mask — glow concentrated at card boundaries
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge = min(edge_x, edge_y);
	float edge_mask = 1.0 - smoothstep(0.0, 0.15, edge);

	// Swirling arcane noise
	float dist = distance(uv, vec2(0.5, 0.5));
	float angle = atan(uv.y - 0.5, uv.x - 0.5);
	vec2 swirl_uv = vec2(angle * 2.0 + TIME * 1.5, dist * 6.0 - TIME * 2.0);
	float n = fbm(swirl_uv);
	float n2 = fbm(swirl_uv * 1.3 + vec2(3.7, TIME * 0.8));

	// Arcane particle sparkles
	float particles = pow(noise(uv * 20.0 + vec2(TIME * 1.2, -TIME * 0.8)), 8.0);

	// Color: deep purple -> cyan -> white at peak
	vec3 col_deep = vec3(0.25, 0.05, 0.45);
	vec3 col_mid = vec3(0.3, 0.4, 0.9);
	vec3 col_bright = vec3(0.5, 0.85, 1.0);
	vec3 col_hot = vec3(0.9, 0.95, 1.0);

	float color_t = n * 0.6 + n2 * 0.4;
	vec3 col = mix(col_deep, col_mid, smoothstep(0.2, 0.5, color_t));
	col = mix(col, col_bright, smoothstep(0.45, 0.7, color_t));
	col = mix(col, col_hot, smoothstep(0.7, 0.95, color_t));

	// Add particle sparkle at edges
	col += vec3(0.8, 0.9, 1.0) * particles * 3.0 * edge_mask;

	// Rounded rectangle outer mask
	float cr = 0.07;
	vec2 q = abs(uv - 0.5) - (0.5 - cr);
	float rect_dist = length(max(q, 0.0)) - cr;
	float rect_mask = 1.0 - smoothstep(0.0, 0.01, rect_dist);

	// Inner card cutout — keep the card face area transparent
	float inner_x = smoothstep(padding_uv.x - 0.01, padding_uv.x, uv.x) * (1.0 - smoothstep(1.0 - padding_uv.x, 1.0 - padding_uv.x + 0.01, uv.x));
	float inner_y = smoothstep(padding_uv.y - 0.01, padding_uv.y, uv.y) * (1.0 - smoothstep(1.0 - padding_uv.y, 1.0 - padding_uv.y + 0.01, uv.y));
	float inner_mask = 1.0 - inner_x * inner_y;

	// Pulsing emission
	float pulse = 0.8 + 0.2 * sin(TIME * 4.0);
	float emission = 1.0 + intensity * 1.5;

	float alpha = edge_mask * (0.5 + n * 0.5) * intensity * pulse * rect_mask * inner_mask;

	COLOR = vec4(col * emission * pulse, alpha * 0.85);
}
"""


func _gate_fire_shader_code() -> String:
	return """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p);
		p *= 2.2;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 uv = UV;

	// Edge distance — fire at borders
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge = min(edge_x, edge_y);
	float edge_mask = 1.0 - smoothstep(0.0, 0.2 + (1.0 - intensity) * 0.15, edge);

	// Fire noise — scrolls upward
	vec2 noise_uv = vec2(uv.x * 5.0, uv.y * 4.0 - TIME * 4.5);
	float n = fbm(noise_uv);
	float n2 = fbm(noise_uv * 1.6 + vec2(4.2, -TIME * 2.5));

	// Bottom-heavy flame bias
	float bottom_bias = smoothstep(0.3, 1.0, uv.y);
	float flame_shape = edge_mask + bottom_bias * 0.3 * n;

	// Color: deep crimson -> blood red -> bright red-orange
	vec3 col_dark = vec3(0.3, 0.0, 0.0);
	vec3 col_red = vec3(0.75, 0.05, 0.0);
	vec3 col_bright = vec3(0.95, 0.2, 0.02);
	vec3 col_hot = vec3(1.0, 0.45, 0.1);

	float color_t = flame_shape * (0.6 + n2 * 0.4);
	vec3 col = mix(col_dark, col_red, smoothstep(0.0, 0.25, color_t));
	col = mix(col, col_bright, smoothstep(0.2, 0.5, color_t));
	col = mix(col, col_hot, smoothstep(0.5, 0.85, color_t));

	// Flickering
	float flicker = 0.85 + 0.15 * noise(vec2(uv.x * 4.0, TIME * 9.0));

	// Emission boost with intensity
	float emission = 1.0 + intensity * intensity * 2.5;

	float alpha = flame_shape * intensity;

	COLOR = vec4(col * flicker * emission, alpha * 0.9);
}
"""


func _animate_heal_stream(source_instance_id: String, target_instance_id: String, amount: int) -> void:
	var source_button: Button = _screen._card_buttons.get(source_instance_id)
	var target_button: Button = _screen._card_buttons.get(target_instance_id)
	if source_button == null or not is_instance_valid(source_button):
		return
	if target_button == null or not is_instance_valid(target_button):
		return

	var source_size: Vector2 = source_button.get_meta("card_size", source_button.size)
	var target_size: Vector2 = target_button.get_meta("card_size", target_button.size)

	# Account for float offset on cards in ready-to-attack state.
	# Check readiness from card data directly since _floating_card_ids may not
	# be populated yet (animation triggers before _refresh_ui).
	var source_card: Dictionary = _screen._card_from_instance_id(source_instance_id)
	var target_card: Dictionary = _screen._card_from_instance_id(target_instance_id)
	var source_ready: bool = str(_screen._creature_readiness_state(source_card).get("id", "")) == "ready"
	var target_ready: bool = str(_screen._creature_readiness_state(target_card).get("id", "")) == "ready"
	var source_float: Vector2 = _screen.LANE_CARD_FLOAT_OFFSET if source_ready else Vector2.ZERO
	var target_float: Vector2 = _screen.LANE_CARD_FLOAT_OFFSET if target_ready else Vector2.ZERO

	var source_center: Vector2 = source_button.global_position + source_size * 0.5 + source_float
	var target_center: Vector2 = target_button.global_position + target_size * 0.5 + target_float

	# Container for the entire animation
	var container := Control.new()
	container.name = "heal_stream_%s_%s" % [source_instance_id, target_instance_id]
	container.z_index = 495
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_screen.add_child(container)

	# --- Phase 1: Potion smoke/fumes billow above the source card ---
	var smoke_origin := source_center
	var particle_count := 22
	var smoke_nodes: Array = []
	for i in range(particle_count):
		var smoke := ColorRect.new()
		smoke.size = Vector2(10, 10)
		smoke.color = Color(0.18, 0.78, 0.3, 0.0)
		smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		smoke.position = smoke_origin - Vector2(5, 5)
		smoke.pivot_offset = Vector2(5, 5)
		container.add_child(smoke)
		smoke_nodes.append(smoke)

	# Grow smoke upward in a wide billowing cloud with stagger
	var grow_tween: Tween = _screen.create_tween()
	grow_tween.set_parallel(true)
	for i in range(particle_count):
		# Wider spread, biased upward for a potion-fume feel
		var angle := randf_range(-PI * 0.85, -PI * 0.15)
		var radius := randf_range(14.0, 48.0)
		var target_offset := Vector2(cos(angle), sin(angle)) * radius
		var particle_size := randf_range(10.0, 22.0)
		var delay := float(i) * 0.02
		var node: ColorRect = smoke_nodes[i]
		# Vary green hue — mix darker/lighter wisps
		var hue_shift := randf_range(-0.06, 0.06)
		var base_color := Color(0.18 + hue_shift, 0.78 + hue_shift * 0.5, 0.3 - hue_shift, 0.0)
		node.color = base_color
		grow_tween.tween_property(node, "color:a", randf_range(0.3, 0.6), 0.35).set_delay(delay)
		grow_tween.tween_property(node, "position", smoke_origin + target_offset - Vector2(particle_size * 0.5, particle_size * 0.5), 0.45).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		grow_tween.tween_property(node, "size", Vector2(particle_size, particle_size), 0.45).set_delay(delay)
		grow_tween.tween_property(node, "pivot_offset", Vector2(particle_size * 0.5, particle_size * 0.5), 0.45).set_delay(delay)
		# Slow secondary drift for lingering fume effect
		grow_tween.tween_property(node, "position:y", smoke_origin.y + target_offset.y - particle_size * 0.5 - randf_range(6.0, 14.0), 0.3).set_delay(delay + 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# --- Phase 2: Stream flows from source to target along a bezier curve ---
	var stream_delay := 0.5
	var stream_duration := 0.4

	# Compute bezier control point (arc perpendicular to the source→target line)
	var mid := (smoke_origin + target_center) * 0.5
	var diff := target_center - smoke_origin
	var perp := Vector2(-diff.y, diff.x).normalized()
	var control := mid + perp * diff.length() * 0.2

	# Create stream particles that will travel along the curve
	var stream_count := 12
	for s in range(stream_count):
		var stream_dot := ColorRect.new()
		var dot_size := randf_range(6.0, 14.0)
		stream_dot.size = Vector2(dot_size, dot_size)
		stream_dot.pivot_offset = Vector2(dot_size * 0.5, dot_size * 0.5)
		stream_dot.color = Color(0.22, 0.85, 0.38, 0.0)
		stream_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stream_dot.position = smoke_origin - Vector2(dot_size * 0.5, dot_size * 0.5)
		container.add_child(stream_dot)

		var particle_delay := stream_delay + float(s) * 0.035
		var particle_duration := stream_duration + randf_range(-0.05, 0.05)

		var st: Tween = _screen.create_tween()
		st.tween_interval(particle_delay)
		st.tween_property(stream_dot, "color:a", randf_range(0.5, 0.8), 0.08)
		st.tween_method(func(t: float, dot: ColorRect = stream_dot, ds: float = dot_size):
			if dot == null or not is_instance_valid(dot):
				return
			var p := (1.0 - t) * (1.0 - t) * smoke_origin + 2.0 * (1.0 - t) * t * control + t * t * target_center
			var wobble := Vector2(sin(t * 12.0 + float(s) * 2.0) * 4.0, cos(t * 10.0 + float(s) * 1.5) * 4.0)
			dot.position = p + wobble - Vector2(ds * 0.5, ds * 0.5)
		, 0.0, 1.0, particle_duration)
		st.tween_property(stream_dot, "color:a", 0.0, 0.15)

	# Fade out the source smoke as stream departs
	var fade_smoke_tween: Tween = _screen.create_tween()
	fade_smoke_tween.tween_interval(stream_delay + 0.15)
	fade_smoke_tween.set_parallel(true)
	for i in range(particle_count):
		var node: ColorRect = smoke_nodes[i]
		fade_smoke_tween.tween_property(node, "color:a", 0.0, 0.3)

	# --- Phase 3: Brief green glow on the healed target + heal popup ---
	var glow_delay := stream_delay + stream_duration - 0.05
	var target_glow_pos: Vector2 = target_button.global_position + target_float
	var glow_rect := ColorRect.new()
	glow_rect.size = target_size
	glow_rect.position = target_glow_pos
	glow_rect.color = Color(0.2, 0.9, 0.35, 0.0)
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(glow_rect)

	var glow_tween = _screen.create_tween()
	glow_tween.tween_interval(glow_delay)
	glow_tween.tween_property(glow_rect, "color:a", 0.25, 0.1)
	glow_tween.tween_property(glow_rect, "color:a", 0.0, 0.35)

	# Heal popup on target (only when health was actually restored)
	if amount > 0:
		var popup_tween = _screen.create_tween()
		popup_tween.tween_interval(glow_delay)
		popup_tween.tween_callback(func():
			var btn: Button = _screen._card_buttons.get(target_instance_id)
			if btn != null and is_instance_valid(btn):
				_add_feedback_popup(btn, "feedback_heal_%s" % target_instance_id, "+%d" % amount, Color(0.3, 0.9, 0.4, 1.0), 10.0)
		)

	# Cleanup container after everything finishes
	var cleanup_tween = _screen.create_tween()
	cleanup_tween.tween_interval(glow_delay + 0.5)
	cleanup_tween.tween_callback(func():
		if container != null and is_instance_valid(container):
			container.queue_free()
	)
