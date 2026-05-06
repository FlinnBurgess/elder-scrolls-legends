extends Control

## Per-deck AI strategy editor. Programmatic UI, full-screen overlay added as a
## child of DeckEditorScreen. Edits a working copy of the strategy and emits
## `strategy_saved(strategy)` when the user confirms.

const DeckStrategy = preload("res://src/ai/deck_strategy.gd")
const DeckStrategyCode = preload("res://src/ai/deck_strategy_code.gd")
const UITheme = preload("res://src/ui/ui_theme.gd")

signal strategy_saved(strategy: Dictionary)
signal closed

# ── State ──
var _deck_name := ""
var _deck_card_quantities: Dictionary = {}  # card_id → quantity
var _deck_card_ids: Array = []
var _card_by_id: Dictionary = {}
var _strategy: Dictionary = {"rules": []}
var _baseline_signature := ""

# ── UI refs ──
var _rules_container: VBoxContainer
var _warning_banner: Label
var _add_rule_button: OptionButton
var _import_input: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	UITheme.add_background(self)
	_build_ui()
	_render_rules()
	_refresh_warning_banner()


func load_state(deck_name: String, deck_quantities: Dictionary, card_by_id: Dictionary, strategy: Dictionary) -> void:
	_deck_name = deck_name
	_deck_card_quantities = deck_quantities.duplicate()
	_deck_card_ids = deck_quantities.keys()
	_deck_card_ids.sort_custom(func(a, b):
		var name_a := str(_card_label(str(a))).to_lower()
		var name_b := str(_card_label(str(b))).to_lower()
		return name_a < name_b)
	_card_by_id = card_by_id
	if typeof(strategy) == TYPE_DICTIONARY and not strategy.is_empty():
		_strategy = strategy.duplicate(true)
	if not _strategy.has("rules"):
		_strategy["rules"] = []
	_baseline_signature = _strategy_signature(_strategy)


# ─────────────────────────── UI construction ───────────────────────────

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	root.offset_left = 32
	root.offset_top = 32
	root.offset_right = -32
	root.offset_bottom = -32
	add_child(root)

	# Header row: title + Back button on the left, Export/Import on the right
	var header := HBoxContainer.new()
	header.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(160, 64)
	UITheme.style_button(back_btn, 22)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	var title := Label.new()
	title.text = "AI Strategy — %s" % _deck_name
	UITheme.style_title(title, 40)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	var export_btn := Button.new()
	export_btn.text = "Export Strategy"
	export_btn.custom_minimum_size = Vector2(240, 64)
	UITheme.style_button_accent(export_btn, Color(0.42, 0.62, 0.96, 1.0), 22)
	export_btn.pressed.connect(_on_export_pressed.bind(export_btn))
	header.add_child(export_btn)

	var import_btn := Button.new()
	import_btn.text = "Import Strategy"
	import_btn.custom_minimum_size = Vector2(240, 64)
	UITheme.style_button_accent(import_btn, Color(0.86, 0.62, 0.32, 1.0), 22)
	import_btn.pressed.connect(_on_import_pressed)
	header.add_child(import_btn)

	# Warning banner
	_warning_banner = Label.new()
	_warning_banner.add_theme_font_size_override("font_size", 22)
	_warning_banner.add_theme_color_override("font_color", Color(0.95, 0.7, 0.4, 1.0))
	_warning_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_warning_banner)

	# Body: scrollable rule list
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	_rules_container = VBoxContainer.new()
	_rules_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_rules_container.add_theme_constant_override("separation", 16)
	scroll.add_child(_rules_container)

	# Footer: Add-rule dropdown + Save button
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	root.add_child(footer)

	_add_rule_button = OptionButton.new()
	_add_rule_button.add_item("+ Add rule…", -1)
	_add_rule_button.add_item("Play-when", 0)
	_add_rule_button.add_item("Combo", 1)
	_add_rule_button.add_item("Mulligan", 2)
	_add_rule_button.add_item("Attack target priority", 3)
	_add_rule_button.custom_minimum_size = Vector2(300, 64)
	UITheme.style_option_button(_add_rule_button, 22)
	_add_rule_button.item_selected.connect(_on_add_rule_selected)
	footer.add_child(_add_rule_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var save_btn := Button.new()
	save_btn.text = "Save Strategy"
	save_btn.custom_minimum_size = Vector2(280, 72)
	UITheme.style_button_accent(save_btn, Color(0.4, 0.76, 0.52, 1.0), 22)
	save_btn.pressed.connect(_on_save_pressed)
	footer.add_child(save_btn)


# ─────────────────────────── Rendering ───────────────────────────

func _render_rules() -> void:
	for child in _rules_container.get_children():
		child.queue_free()
	var rules: Array = _strategy.get("rules", [])
	for index in rules.size():
		var rule: Dictionary = rules[index]
		_rules_container.add_child(_build_rule_row(rule, index))


func _build_rule_row(rule: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	UITheme.style_panel(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)

	var type_label := Label.new()
	type_label.text = _rule_display_name(str(rule.get("type", "")))
	UITheme.style_section_label(type_label, 26)
	top.add_child(type_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(spacer)

	# Reorder buttons (simpler than drag-and-drop).
	var up_btn := Button.new()
	up_btn.text = "▲"
	up_btn.custom_minimum_size = Vector2(48, 48)
	UITheme.style_button(up_btn, 18, true)
	up_btn.disabled = (index == 0)
	up_btn.pressed.connect(_on_move_rule.bind(index, -1))
	top.add_child(up_btn)

	var down_btn := Button.new()
	down_btn.text = "▼"
	down_btn.custom_minimum_size = Vector2(48, 48)
	UITheme.style_button(down_btn, 18, true)
	down_btn.disabled = (index >= int(_strategy.get("rules", []).size()) - 1)
	down_btn.pressed.connect(_on_move_rule.bind(index, 1))
	top.add_child(down_btn)

	var rule_type := str(rule.get("type", ""))
	if rule_type != DeckStrategy.RULE_MULLIGAN and rule_type != DeckStrategy.RULE_ATTACK_TARGET:
		var strict_cb := CheckBox.new()
		strict_cb.text = "Strict"
		strict_cb.button_pressed = bool(rule.get("strict", false))
		UITheme.style_checkbox(strict_cb, 20, 30, UITheme.GOLD_DIM)
		strict_cb.toggled.connect(_on_strict_toggled.bind(index))
		top.add_child(strict_cb)

	var delete_btn := Button.new()
	delete_btn.text = "✕"
	delete_btn.custom_minimum_size = Vector2(48, 48)
	UITheme.style_button_accent(delete_btn, Color(0.85, 0.4, 0.4, 1.0), 18)
	delete_btn.pressed.connect(_on_delete_rule.bind(index))
	top.add_child(delete_btn)

	# Type-specific payload
	var payload := _build_rule_payload(rule, index)
	if payload != null:
		box.add_child(payload)

	return panel


func _build_rule_payload(rule: Dictionary, index: int) -> Control:
	match str(rule.get("type", "")):
		DeckStrategy.RULE_PLAY_WHEN:
			return _build_gate_payload(rule, index)
		DeckStrategy.RULE_COMBO:
			return _build_combo_payload(rule, index)
		DeckStrategy.RULE_MULLIGAN:
			return _build_mulligan_payload(rule, index)
		DeckStrategy.RULE_ATTACK_TARGET:
			return _build_attack_target_payload(rule, index)
	return null


# ── Magicka-gate / Hold-for-trigger payload ──

func _build_gate_payload(rule: Dictionary, index: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	# Card chips row
	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 10)
	box.add_child(chips_row)

	var label := Label.new()
	label.text = "Cards:"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	chips_row.add_child(label)

	var card_ids: Array = rule.get("card_ids", [])
	for cid in card_ids:
		chips_row.add_child(_build_card_chip(str(cid), index))

	var add_card_btn := OptionButton.new()
	add_card_btn.add_item("+ card…", -1)
	for cid in _deck_card_ids:
		if not card_ids.has(str(cid)):
			add_card_btn.add_item(_card_label(str(cid)))
			add_card_btn.set_item_metadata(add_card_btn.item_count - 1, str(cid))
	UITheme.style_option_button(add_card_btn, 20)
	add_card_btn.custom_minimum_size = Vector2(200, 52)
	add_card_btn.item_selected.connect(_on_add_gate_card.bind(index, add_card_btn))
	chips_row.add_child(add_card_btn)

	# Condition row
	var cond_row := HBoxContainer.new()
	cond_row.add_theme_constant_override("separation", 12)
	box.add_child(cond_row)

	var when_label := Label.new()
	when_label.text = "when"
	when_label.add_theme_font_size_override("font_size", 22)
	when_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	cond_row.add_child(when_label)

	var pred_button := OptionButton.new()
	UITheme.style_option_button(pred_button, 20)
	pred_button.custom_minimum_size = Vector2(380, 52)
	var current_pred := str(rule.get("condition", {}).get("predicate", DeckStrategy.PRED_MAX_MAGICKA))
	var preds := DeckStrategy.NUMERIC_PREDICATES + DeckStrategy.KEYWORD_PREDICATES
	var current_pred_idx := 0
	for i in preds.size():
		pred_button.add_item(_predicate_display_name(str(preds[i])))
		pred_button.set_item_metadata(i, str(preds[i]))
		if str(preds[i]) == current_pred:
			current_pred_idx = i
	pred_button.select(current_pred_idx)
	pred_button.item_selected.connect(_on_predicate_changed.bind(index, pred_button))
	cond_row.add_child(pred_button)

	if current_pred == DeckStrategy.PRED_ENEMY_HAS_KEYWORD:
		# Keyword text input.
		var kw_input := LineEdit.new()
		kw_input.placeholder_text = "keyword (e.g. guard)"
		kw_input.text = str(rule.get("condition", {}).get("keyword", ""))
		kw_input.custom_minimum_size = Vector2(220, 52)
		kw_input.add_theme_font_size_override("font_size", 20)
		kw_input.text_changed.connect(_on_keyword_input_changed.bind(index))
		cond_row.add_child(kw_input)
	else:
		# Op + numeric value.
		var op_button := OptionButton.new()
		UITheme.style_option_button(op_button, 22)
		op_button.custom_minimum_size = Vector2(110, 52)
		op_button.add_item("≥", 0)
		op_button.set_item_metadata(0, DeckStrategy.OP_GTE)
		op_button.add_item("≤", 1)
		op_button.set_item_metadata(1, DeckStrategy.OP_LTE)
		var current_op := str(rule.get("condition", {}).get("op", DeckStrategy.OP_GTE))
		op_button.select(0 if current_op == DeckStrategy.OP_GTE else 1)
		op_button.item_selected.connect(_on_op_changed.bind(index, op_button))
		cond_row.add_child(op_button)

		var value_spin := SpinBox.new()
		value_spin.min_value = 0
		value_spin.max_value = 30
		value_spin.value = float(int(rule.get("condition", {}).get("value", 0)))
		value_spin.custom_minimum_size = Vector2(110, 52)
		UITheme.style_spin_box(value_spin, 20)
		value_spin.value_changed.connect(_on_value_changed.bind(index))
		cond_row.add_child(value_spin)

	return box


func _build_card_chip(card_id: String, rule_index: int) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = _card_label(card_id)
	label.add_theme_font_size_override("font_size", 20)
	if not _deck_card_quantities.has(card_id):
		label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35, 1.0))
	else:
		label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	chip.add_child(label)
	var remove := Button.new()
	remove.text = "×"
	remove.custom_minimum_size = Vector2(36, 36)
	UITheme.style_button(remove, 18, true)
	remove.pressed.connect(_on_remove_card_chip.bind(rule_index, card_id))
	chip.add_child(remove)
	return chip


# ── Combo payload ──

func _build_combo_payload(rule: Dictionary, index: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	var hint := Label.new()
	hint.text = "Combo plays in order. Use ◀ ▶ to reorder."
	hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	hint.add_theme_font_size_override("font_size", 18)
	box.add_child(hint)

	var sequence_row := HBoxContainer.new()
	sequence_row.add_theme_constant_override("separation", 12)
	box.add_child(sequence_row)

	var card_ids: Array = rule.get("card_ids", [])
	for i in card_ids.size():
		sequence_row.add_child(_build_combo_step(str(card_ids[i]), index, i, card_ids.size()))

	var add_btn := OptionButton.new()
	add_btn.add_item("+ step…", -1)
	for cid in _deck_card_ids:
		add_btn.add_item(_card_label(str(cid)))
		add_btn.set_item_metadata(add_btn.item_count - 1, str(cid))
	UITheme.style_option_button(add_btn, 20)
	add_btn.custom_minimum_size = Vector2(200, 52)
	add_btn.item_selected.connect(_on_add_combo_step.bind(index, add_btn))
	sequence_row.add_child(add_btn)

	return box


func _build_combo_step(card_id: String, rule_index: int, step_index: int, total: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = "%d. %s" % [step_index + 1, _card_label(card_id)]
	label.add_theme_font_size_override("font_size", 20)
	if not _deck_card_quantities.has(card_id):
		label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35, 1.0))
	else:
		label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	col.add_child(label)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	col.add_child(btn_row)
	var left := Button.new()
	left.text = "◀"
	left.custom_minimum_size = Vector2(44, 40)
	UITheme.style_button(left, 18, true)
	left.disabled = (step_index == 0)
	left.pressed.connect(_on_move_combo_step.bind(rule_index, step_index, -1))
	btn_row.add_child(left)
	var right := Button.new()
	right.text = "▶"
	right.custom_minimum_size = Vector2(44, 40)
	UITheme.style_button(right, 18, true)
	right.disabled = (step_index >= total - 1)
	right.pressed.connect(_on_move_combo_step.bind(rule_index, step_index, 1))
	btn_row.add_child(right)
	var remove := Button.new()
	remove.text = "×"
	remove.custom_minimum_size = Vector2(44, 40)
	UITheme.style_button(remove, 18, true)
	remove.pressed.connect(_on_remove_combo_step.bind(rule_index, step_index))
	btn_row.add_child(remove)
	return col


# ── Mulligan payload ──

func _build_mulligan_payload(rule: Dictionary, index: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var entries: Array = rule.get("entries", [])
	for i in entries.size():
		var entry: Dictionary = entries[i]
		box.add_child(_build_mulligan_entry(entry, index, i))
	# "+ entry" row
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 12)
	var add_btn := OptionButton.new()
	add_btn.add_item("+ card…", -1)
	var existing := {}
	for entry in entries:
		existing[str((entry as Dictionary).get("card_id", ""))] = true
	for cid in _deck_card_ids:
		if not existing.has(str(cid)):
			add_btn.add_item(_card_label(str(cid)))
			add_btn.set_item_metadata(add_btn.item_count - 1, str(cid))
	UITheme.style_option_button(add_btn, 20)
	add_btn.custom_minimum_size = Vector2(240, 52)
	add_btn.item_selected.connect(_on_add_mulligan_entry.bind(index, add_btn))
	add_row.add_child(add_btn)
	box.add_child(add_row)
	return box


func _build_mulligan_entry(entry: Dictionary, rule_index: int, entry_index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	var card_id := str(entry.get("card_id", ""))
	label.text = _card_label(card_id)
	label.add_theme_font_size_override("font_size", 20)
	label.custom_minimum_size = Vector2(300, 0)
	if not _deck_card_quantities.has(card_id):
		label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35, 1.0))
	else:
		label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	row.add_child(label)

	var dir_button := OptionButton.new()
	UITheme.style_option_button(dir_button, 20)
	dir_button.custom_minimum_size = Vector2(200, 52)
	dir_button.add_item("Always keep", 0)
	dir_button.set_item_metadata(0, DeckStrategy.MULL_KEEP)
	dir_button.add_item("Always toss", 1)
	dir_button.set_item_metadata(1, DeckStrategy.MULL_TOSS)
	var current_dir := str(entry.get("direction", DeckStrategy.MULL_KEEP))
	dir_button.select(0 if current_dir == DeckStrategy.MULL_KEEP else 1)
	dir_button.item_selected.connect(_on_mulligan_direction_changed.bind(rule_index, entry_index, dir_button))
	row.add_child(dir_button)

	var remove := Button.new()
	remove.text = "✕"
	remove.custom_minimum_size = Vector2(44, 44)
	UITheme.style_button(remove, 18, true)
	remove.pressed.connect(_on_remove_mulligan_entry.bind(rule_index, entry_index))
	row.add_child(remove)
	return row


# ── Attack target payload ──

func _build_attack_target_payload(rule: Dictionary, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = "Default attack target:"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	row.add_child(label)
	var dropdown := OptionButton.new()
	UITheme.style_option_button(dropdown, 20)
	dropdown.custom_minimum_size = Vector2(300, 52)
	var current := str(rule.get("value", DeckStrategy.ATTACK_FACE))
	for i in DeckStrategy.ATTACK_TARGET_VALUES.size():
		var v := str(DeckStrategy.ATTACK_TARGET_VALUES[i])
		dropdown.add_item(_attack_target_display(v))
		dropdown.set_item_metadata(i, v)
		if v == current:
			dropdown.select(i)
	dropdown.item_selected.connect(_on_attack_target_changed.bind(index, dropdown))
	row.add_child(dropdown)
	return row


# ─────────────────────────── Event handlers ───────────────────────────

func _on_back_pressed() -> void:
	if _is_dirty():
		_show_unsaved_changes_modal()
		return
	closed.emit()


func _on_save_pressed() -> void:
	_save_strategy()
	closed.emit()


func _save_strategy() -> void:
	# Strip empty rules.
	var rules: Array = _strategy.get("rules", [])
	var cleaned: Array = []
	for rule in rules:
		if _is_rule_meaningful(rule):
			cleaned.append(rule)
	_strategy["rules"] = cleaned
	_baseline_signature = _strategy_signature(_strategy)
	strategy_saved.emit(_strategy.duplicate(true))


func _is_dirty() -> bool:
	return _strategy_signature(_strategy) != _baseline_signature


static func _strategy_signature(strategy: Dictionary) -> String:
	# Stable signature for dirty-checking. sort_keys=true protects against
	# field-order shifts inside rule dicts; arrays preserve order, which is
	# what we want (rule order is user-meaningful).
	return JSON.stringify(strategy, "", true)


func _show_unsaved_changes_modal() -> void:
	var modal := PanelContainer.new()
	UITheme.style_panel(modal)
	modal.set_anchors_and_offsets_preset(PRESET_CENTER)
	modal.custom_minimum_size = Vector2(720, 240)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.offset_left = 28
	box.offset_top = 28
	box.offset_right = -28
	box.offset_bottom = -28
	modal.add_child(box)

	var title := Label.new()
	title.text = "Unsaved changes"
	UITheme.style_section_label(title, 28)
	box.add_child(title)

	var msg := Label.new()
	msg.text = "Save your changes before going back?"
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(160, 56)
	UITheme.style_button(cancel, 20)
	cancel.pressed.connect(func(): modal.queue_free())
	row.add_child(cancel)

	var discard := Button.new()
	discard.text = "Discard"
	discard.custom_minimum_size = Vector2(160, 56)
	UITheme.style_button_accent(discard, Color(0.85, 0.4, 0.4, 1.0), 20)
	discard.pressed.connect(func():
		modal.queue_free()
		closed.emit())
	row.add_child(discard)

	var save := Button.new()
	save.text = "Save"
	save.custom_minimum_size = Vector2(160, 56)
	UITheme.style_button_accent(save, Color(0.4, 0.76, 0.52, 1.0), 20)
	save.pressed.connect(func():
		modal.queue_free()
		_save_strategy()
		closed.emit())
	row.add_child(save)

	add_child(modal)


func _on_add_rule_selected(idx: int) -> void:
	if idx <= 0:
		return
	var rule_id: int = int(_add_rule_button.get_item_id(idx))
	var rule: Dictionary
	match rule_id:
		0:  # Play-when
			rule = {"type": DeckStrategy.RULE_PLAY_WHEN, "card_ids": [], "condition": {"predicate": DeckStrategy.PRED_MAX_MAGICKA, "op": DeckStrategy.OP_GTE, "value": 7}, "strict": false}
		1:  # Combo
			rule = {"type": DeckStrategy.RULE_COMBO, "card_ids": [], "strict": true}
		2:  # Mulligan
			rule = {"type": DeckStrategy.RULE_MULLIGAN, "entries": []}
		3:  # Attack target priority
			rule = {"type": DeckStrategy.RULE_ATTACK_TARGET, "value": DeckStrategy.ATTACK_FACE}
		_:
			return
	(_strategy["rules"] as Array).append(rule)
	_add_rule_button.select(0)
	_render_rules()
	_refresh_warning_banner()


func _on_delete_rule(index: int) -> void:
	var rules: Array = _strategy["rules"]
	if index >= 0 and index < rules.size():
		rules.remove_at(index)
	_render_rules()
	_refresh_warning_banner()


func _on_move_rule(index: int, direction: int) -> void:
	var rules: Array = _strategy["rules"]
	var new_index := index + direction
	if new_index < 0 or new_index >= rules.size():
		return
	var item = rules[index]
	rules.remove_at(index)
	rules.insert(new_index, item)
	_render_rules()


func _on_strict_toggled(pressed: bool, index: int) -> void:
	var rule: Dictionary = _strategy["rules"][index]
	rule["strict"] = pressed


func _on_add_gate_card(idx: int, rule_index: int, btn: OptionButton) -> void:
	if idx <= 0:
		return
	var card_id := str(btn.get_item_metadata(idx))
	if card_id.is_empty():
		return
	var rule: Dictionary = _strategy["rules"][rule_index]
	var card_ids: Array = rule.get("card_ids", [])
	if not card_ids.has(card_id):
		card_ids.append(card_id)
	rule["card_ids"] = card_ids
	btn.select(0)
	_render_rules()
	_refresh_warning_banner()


func _on_remove_card_chip(rule_index: int, card_id: String) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	var card_ids: Array = rule.get("card_ids", [])
	card_ids.erase(card_id)
	rule["card_ids"] = card_ids
	_render_rules()
	_refresh_warning_banner()


func _on_predicate_changed(idx: int, rule_index: int, btn: OptionButton) -> void:
	var pred := str(btn.get_item_metadata(idx))
	var rule: Dictionary = _strategy["rules"][rule_index]
	var cond: Dictionary = rule.get("condition", {})
	cond["predicate"] = pred
	if pred == DeckStrategy.PRED_ENEMY_HAS_KEYWORD:
		cond.erase("op")
		cond.erase("value")
		cond["keyword"] = str(cond.get("keyword", "guard"))
	else:
		cond.erase("keyword")
		cond["op"] = str(cond.get("op", DeckStrategy.OP_GTE))
		cond["value"] = int(cond.get("value", 0))
	rule["condition"] = cond
	_render_rules()


func _on_op_changed(idx: int, rule_index: int, btn: OptionButton) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	var cond: Dictionary = rule.get("condition", {})
	cond["op"] = str(btn.get_item_metadata(idx))
	rule["condition"] = cond


func _on_value_changed(value: float, rule_index: int) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	var cond: Dictionary = rule.get("condition", {})
	cond["value"] = int(value)
	rule["condition"] = cond


func _on_keyword_input_changed(text: String, rule_index: int) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	var cond: Dictionary = rule.get("condition", {})
	cond["keyword"] = text
	rule["condition"] = cond


func _on_add_combo_step(idx: int, rule_index: int, btn: OptionButton) -> void:
	if idx <= 0:
		return
	var card_id := str(btn.get_item_metadata(idx))
	if card_id.is_empty():
		return
	var rule: Dictionary = _strategy["rules"][rule_index]
	var card_ids: Array = rule.get("card_ids", [])
	card_ids.append(card_id)
	rule["card_ids"] = card_ids
	btn.select(0)
	_render_rules()
	_refresh_warning_banner()


func _on_move_combo_step(rule_index: int, step_index: int, direction: int) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	var card_ids: Array = rule.get("card_ids", [])
	var new_index := step_index + direction
	if new_index < 0 or new_index >= card_ids.size():
		return
	var item = card_ids[step_index]
	card_ids.remove_at(step_index)
	card_ids.insert(new_index, item)
	rule["card_ids"] = card_ids
	_render_rules()


func _on_remove_combo_step(rule_index: int, step_index: int) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	var card_ids: Array = rule.get("card_ids", [])
	card_ids.remove_at(step_index)
	rule["card_ids"] = card_ids
	_render_rules()
	_refresh_warning_banner()


func _on_add_mulligan_entry(idx: int, rule_index: int, btn: OptionButton) -> void:
	if idx <= 0:
		return
	var card_id := str(btn.get_item_metadata(idx))
	if card_id.is_empty():
		return
	var rule: Dictionary = _strategy["rules"][rule_index]
	var entries: Array = rule.get("entries", [])
	entries.append({"card_id": card_id, "direction": DeckStrategy.MULL_KEEP})
	rule["entries"] = entries
	btn.select(0)
	_render_rules()
	_refresh_warning_banner()


func _on_remove_mulligan_entry(rule_index: int, entry_index: int) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	var entries: Array = rule.get("entries", [])
	entries.remove_at(entry_index)
	rule["entries"] = entries
	_render_rules()
	_refresh_warning_banner()


func _on_mulligan_direction_changed(idx: int, rule_index: int, entry_index: int, btn: OptionButton) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	var entries: Array = rule.get("entries", [])
	var entry: Dictionary = entries[entry_index]
	entry["direction"] = str(btn.get_item_metadata(idx))


func _on_attack_target_changed(idx: int, rule_index: int, btn: OptionButton) -> void:
	var rule: Dictionary = _strategy["rules"][rule_index]
	rule["value"] = str(btn.get_item_metadata(idx))


# ── Export / import ──

func _on_export_pressed(btn: Button) -> void:
	var result: Dictionary = DeckStrategyCode.encode(_strategy)
	if not str(result.get("error", "")).is_empty():
		btn.text = "Error!"
	else:
		DisplayServer.clipboard_set(str(result.get("code", "")))
		btn.text = "Copied!"
	btn.disabled = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		btn.text = "Export Strategy"
		btn.disabled = false
	)


func _on_import_pressed() -> void:
	# Inline modal: text field for paste + Apply / Cancel.
	var modal := PanelContainer.new()
	UITheme.style_panel(modal)
	modal.set_anchors_and_offsets_preset(PRESET_CENTER)
	modal.custom_minimum_size = Vector2(800, 280)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.offset_left = 24
	box.offset_top = 24
	box.offset_right = -24
	box.offset_bottom = -24
	modal.add_child(box)
	var title := Label.new()
	title.text = "Paste strategy code"
	UITheme.style_section_label(title, 24)
	box.add_child(title)
	_import_input = LineEdit.new()
	_import_input.placeholder_text = "SS1:..."
	_import_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_import_input.add_theme_font_size_override("font_size", 22)
	_import_input.custom_minimum_size = Vector2(0, 56)
	box.add_child(_import_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(160, 56)
	UITheme.style_button(cancel, 20)
	cancel.pressed.connect(func(): modal.queue_free())
	row.add_child(cancel)
	var apply := Button.new()
	apply.text = "Apply"
	apply.custom_minimum_size = Vector2(160, 56)
	UITheme.style_button_accent(apply, Color(0.4, 0.76, 0.52, 1.0), 20)
	apply.pressed.connect(_on_import_apply.bind(modal))
	row.add_child(apply)
	add_child(modal)


func _on_import_apply(modal: Control) -> void:
	var code := _import_input.text.strip_edges()
	var decoded := DeckStrategyCode.decode(code)
	if not str(decoded.get("error", "")).is_empty():
		_import_input.placeholder_text = str(decoded.get("error", ""))
		_import_input.text = ""
		return
	var imported: Dictionary = decoded.get("strategy", {})
	if typeof(imported) == TYPE_DICTIONARY and imported.has("rules"):
		_strategy = imported
	modal.queue_free()
	_render_rules()
	_refresh_warning_banner()


# ─────────────────────────── Validation banner ───────────────────────────

func _refresh_warning_banner() -> void:
	if _warning_banner == null:
		return
	var validation := DeckStrategy.validate(_strategy, _deck_card_ids)
	var warnings: Array = validation.get("warnings", [])
	if warnings.is_empty():
		_warning_banner.text = ""
		_warning_banner.visible = false
		return
	var lines: Array = []
	for w in warnings:
		var ids: Array = w.get("dangling_card_ids", [])
		var labels: Array = []
		for cid in ids:
			labels.append(_card_label(str(cid)))
		lines.append("⚠ %s rule references missing cards: %s" % [_rule_display_name(str(w.get("rule_type", ""))), ", ".join(labels)])
	_warning_banner.text = "\n".join(lines)
	_warning_banner.visible = true


# ─────────────────────────── Helpers ───────────────────────────

func _card_label(card_id: String) -> String:
	var card: Dictionary = _card_by_id.get(card_id, {})
	if card.is_empty():
		return card_id
	return str(card.get("name", card_id))


func _rule_display_name(rule_type: String) -> String:
	match rule_type:
		DeckStrategy.RULE_PLAY_WHEN: return "Play-when"
		DeckStrategy.RULE_COMBO: return "Combo"
		DeckStrategy.RULE_MULLIGAN: return "Mulligan"
		DeckStrategy.RULE_ATTACK_TARGET: return "Attack target priority"
	return rule_type


func _predicate_display_name(pred: String) -> String:
	match pred:
		DeckStrategy.PRED_MAX_MAGICKA: return "max magicka"
		DeckStrategy.PRED_CURRENT_MAGICKA: return "current magicka"
		DeckStrategy.PRED_RUNES_REMAINING: return "my runes remaining"
		DeckStrategy.PRED_LIFE: return "my life"
		DeckStrategy.PRED_HAND_SIZE: return "my hand size"
		DeckStrategy.PRED_ENEMY_LIFE: return "enemy life"
		DeckStrategy.PRED_ENEMY_RUNES: return "enemy runes remaining"
		DeckStrategy.PRED_ENEMY_HAS_CREATURE_WITH_POWER: return "enemy has creature with power"
		DeckStrategy.PRED_ENEMY_CREATURE_COUNT: return "enemy creature count"
		DeckStrategy.PRED_ENEMY_HAS_KEYWORD: return "enemy has keyword"
	return pred


func _attack_target_display(value: String) -> String:
	match value:
		DeckStrategy.ATTACK_FACE: return "Face"
		DeckStrategy.ATTACK_WEAKEST: return "Weakest enemy"
		DeckStrategy.ATTACK_HIGHEST_POWER: return "Highest-power enemy"
		DeckStrategy.ATTACK_AVOID_GUARDS: return "Avoid guards"
	return value


func _is_rule_meaningful(rule: Dictionary) -> bool:
	match str(rule.get("type", "")):
		DeckStrategy.RULE_PLAY_WHEN, DeckStrategy.RULE_COMBO:
			return not (rule.get("card_ids", []) as Array).is_empty()
		DeckStrategy.RULE_MULLIGAN:
			return not (rule.get("entries", []) as Array).is_empty()
		DeckStrategy.RULE_ATTACK_TARGET:
			return not str(rule.get("value", "")).is_empty()
	return false
