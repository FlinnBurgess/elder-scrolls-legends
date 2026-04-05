extends SceneTree

const CardCatalog = preload("res://src/deck/card_catalog.gd")

var _failures: Array[String] = []

# action_target_mode values from match_screen.gd:_action_target_mode_allows (UI node, not statically parseable)
const ACTION_TARGET_MODES: Array[String] = [
	"friendly_creature", "another_friendly_creature",
	"enemy_creature",
	"wounded_enemy_creature",
	"wounded_creature",
	"any_creature", "another_creature",
	"enemy_support_or_neutral_creature",
	"enemy_creature_or_support",
	"choose_lane",
	"creature_1_power_or_less",
	"creature_4_power_or_less",
	"creature_4_power_or_more",
	"creature_with_0_power",
	"enemy_creature_3_power_or_less",
	"enemy_creature_and_friendly_creature",
	"friendly_creature_then_enemy_creature",
	"any_creature_or_player",
	"creature_or_player",
]

# Targets handled outside _resolve_card_targets_by_name:
# - In _resolve_card_targets (special-cased before delegation)
# - By ops that handle their own target resolution internally
const SPECIAL_TARGETS: Array[String] = [
	"copies_in_hand_and_deck",
	"friendly_by_name",
	"all_friendly_supports",
	"all_friendly_activated_supports",
	"chosen_lane",
	"same_lane",
	"enemies_in_lane",
]


func _initialize() -> void:
	var seeds: Array = CardCatalog._card_seeds()
	if seeds.is_empty():
		_assert(false, "CardCatalog._card_seeds() returned empty — cannot validate.")
		_finish()
		return

	var timing_source := _read_source_file("res://src/core/match/match_timing.gd")
	var extended_source := _read_source_file("res://src/core/match/extended_mechanic_packs.gd")
	var effect_app_source := _read_source_file("res://src/core/match/match_effect_application.gd")
	if timing_source.is_empty() or extended_source.is_empty():
		_assert(false, "Failed to read engine source files for validation.")
		_finish()
		return

	# Extract handled values from engine source
	var timing_ops := _extract_match_cases(timing_source, "match op:", "\t\t\t")
	var extended_ops := _extract_match_cases(extended_source, "match str(effect.get(\"op\", \"\")):", "\t\t")
	var all_ops: Dictionary = {}
	for op in timing_ops:
		all_ops[op] = true
	for op in extended_ops:
		all_ops[op] = true
	if not effect_app_source.is_empty():
		var effect_app_ops := _extract_match_cases(effect_app_source, "match op:", "\t\t\t")
		for op in effect_app_ops:
			all_ops[op] = true

	var targets := _extract_match_cases(timing_source, "match target:", "\t\t")
	var all_targets: Dictionary = {}
	for t in targets:
		all_targets[t] = true
	for t in SPECIAL_TARGETS:
		all_targets[t] = true

	var trigger_target_modes := _extract_match_cases(timing_source, "match target_mode:", "\t\t")
	var all_trigger_modes: Dictionary = {}
	for m in trigger_target_modes:
		all_trigger_modes[m] = true

	var all_action_modes: Dictionary = {}
	for m in ACTION_TARGET_MODES:
		all_action_modes[m] = true

	# Validate card data against extracted handlers
	_test_op_coverage(seeds, all_ops)
	_test_target_coverage(seeds, all_targets)
	_test_trigger_target_mode_coverage(seeds, all_trigger_modes)
	_test_action_target_mode_coverage(seeds, all_action_modes)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_DATA_VALIDATION_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _assert(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition


# ── Source file parsing ──────────────────────────────────────────────

func _read_source_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _extract_match_cases(source: String, match_line_pattern: String, case_indent: String) -> Array[String]:
	var lines := source.split("\n")
	var results: Array[String] = []
	var in_match_block := false
	var continuation_line := ""

	for line in lines:
		if not in_match_block:
			if line.strip_edges().begins_with(match_line_pattern):
				in_match_block = true
			continue

		# Check for default case or end of match block (lower indentation)
		var stripped := line.strip_edges()
		if stripped == "_:":
			break

		# Handle backslash line continuations
		if not continuation_line.is_empty():
			if stripped.ends_with("\\"):
				continuation_line += " " + stripped.left(stripped.length() - 1).strip_edges()
			else:
				continuation_line += " " + stripped
				_parse_case_line(continuation_line, results)
				continuation_line = ""
			continue

		# Check if this line is a case at the expected indentation
		if not line.begins_with(case_indent + "\""):
			continue

		if stripped.ends_with("\\"):
			continuation_line = stripped.left(stripped.length() - 1).strip_edges()
			continue

		_parse_case_line(stripped, results)

	return results


func _parse_case_line(line: String, results: Array[String]) -> void:
	# Remove trailing colon and backslash
	var clean := line.rstrip("\\").strip_edges()
	if clean.ends_with(":"):
		clean = clean.left(clean.length() - 1)
	# Split on comma for multi-value cases: "a", "b", "c"
	for part in clean.split(","):
		var trimmed := part.strip_edges().trim_prefix("\"").trim_suffix("\"")
		if not trimmed.is_empty() and trimmed != "_":
			results.append(trimmed)


# ── Card data walking ────────────────────────────────────────────────

func _collect_ops_from_seeds(seeds: Array) -> Dictionary:
	# Returns {op_name: [card_id1, card_id2, ...]}
	var ops: Dictionary = {}
	for seed in seeds:
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		var card_id := str(seed.get("card_id", ""))
		for trigger in _ensure_array(seed.get("triggered_abilities", [])):
			_walk_effects_for_ops(trigger, card_id, ops)
		for trigger in _ensure_array(seed.get("grants_trigger", [])):
			_walk_effects_for_ops(trigger, card_id, ops)
	return ops


func _walk_effects_for_ops(trigger: Variant, card_id: String, ops: Dictionary) -> void:
	if typeof(trigger) != TYPE_DICTIONARY:
		return
	for effect in _ensure_array(trigger.get("effects", [])):
		_collect_op_from_effect(effect, card_id, ops)
	# Walk nested choice structures
	for choice in _ensure_array(trigger.get("choices", [])):
		if typeof(choice) == TYPE_DICTIONARY:
			for effect in _ensure_array(choice.get("effects", [])):
				_collect_op_from_effect(effect, card_id, ops)


func _collect_op_from_effect(effect: Variant, card_id: String, ops: Dictionary) -> void:
	if typeof(effect) != TYPE_DICTIONARY:
		return
	var op := str(effect.get("op", ""))
	if not op.is_empty():
		if not ops.has(op):
			ops[op] = []
		if not ops[op].has(card_id):
			ops[op].append(card_id)
	# Recurse into nested effect arrays
	for key in ["choices", "on_correct", "effects_per_option"]:
		var nested = effect.get(key)
		if typeof(nested) == TYPE_ARRAY:
			for item in nested:
				if typeof(item) == TYPE_ARRAY:
					for sub_effect in item:
						_collect_op_from_effect(sub_effect, card_id, ops)
				elif typeof(item) == TYPE_DICTIONARY:
					# Choice dicts may contain effects arrays
					for sub_effect in _ensure_array(item.get("effects", [])):
						_collect_op_from_effect(sub_effect, card_id, ops)
					# Or the item itself may be an effect
					if item.has("op"):
						_collect_op_from_effect(item, card_id, ops)


func _collect_targets_from_seeds(seeds: Array) -> Dictionary:
	var targets: Dictionary = {}
	for seed in seeds:
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		var card_id := str(seed.get("card_id", ""))
		for trigger in _ensure_array(seed.get("triggered_abilities", [])):
			_walk_effects_for_targets(trigger, card_id, targets)
		for trigger in _ensure_array(seed.get("grants_trigger", [])):
			_walk_effects_for_targets(trigger, card_id, targets)
	return targets


func _walk_effects_for_targets(trigger: Variant, card_id: String, targets: Dictionary) -> void:
	if typeof(trigger) != TYPE_DICTIONARY:
		return
	for effect in _ensure_array(trigger.get("effects", [])):
		_collect_target_from_effect(effect, card_id, targets)
	for choice in _ensure_array(trigger.get("choices", [])):
		if typeof(choice) == TYPE_DICTIONARY:
			for effect in _ensure_array(choice.get("effects", [])):
				_collect_target_from_effect(effect, card_id, targets)


func _collect_target_from_effect(effect: Variant, card_id: String, targets: Dictionary) -> void:
	if typeof(effect) != TYPE_DICTIONARY:
		return
	var target := str(effect.get("target", ""))
	if not target.is_empty():
		if not targets.has(target):
			targets[target] = []
		if not targets[target].has(card_id):
			targets[target].append(card_id)
	# Recurse into nested structures
	for key in ["choices", "on_correct", "effects_per_option"]:
		var nested = effect.get(key)
		if typeof(nested) == TYPE_ARRAY:
			for item in nested:
				if typeof(item) == TYPE_ARRAY:
					for sub_effect in item:
						_collect_target_from_effect(sub_effect, card_id, targets)
				elif typeof(item) == TYPE_DICTIONARY:
					for sub_effect in _ensure_array(item.get("effects", [])):
						_collect_target_from_effect(sub_effect, card_id, targets)
					if item.has("target"):
						_collect_target_from_effect(item, card_id, targets)


func _collect_trigger_target_modes(seeds: Array) -> Dictionary:
	var modes: Dictionary = {}
	for seed in seeds:
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		var card_id := str(seed.get("card_id", ""))
		for trigger in _ensure_array(seed.get("triggered_abilities", [])):
			if typeof(trigger) != TYPE_DICTIONARY:
				continue
			var tm := str(trigger.get("target_mode", ""))
			if not tm.is_empty():
				if not modes.has(tm):
					modes[tm] = []
				if not modes[tm].has(card_id):
					modes[tm].append(card_id)
		for trigger in _ensure_array(seed.get("grants_trigger", [])):
			if typeof(trigger) != TYPE_DICTIONARY:
				continue
			var tm := str(trigger.get("target_mode", ""))
			if not tm.is_empty():
				if not modes.has(tm):
					modes[tm] = []
				if not modes[tm].has(card_id):
					modes[tm].append(card_id)
	return modes


func _collect_action_target_modes(seeds: Array) -> Dictionary:
	var modes: Dictionary = {}
	for seed in seeds:
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		var card_id := str(seed.get("card_id", ""))
		var atm := str(seed.get("action_target_mode", ""))
		if not atm.is_empty():
			if not modes.has(atm):
				modes[atm] = []
			if not modes[atm].has(card_id):
				modes[atm].append(card_id)
	return modes


# ── Validation tests ─────────────────────────────────────────────────

func _test_op_coverage(seeds: Array, handled_ops: Dictionary) -> void:
	var card_ops := _collect_ops_from_seeds(seeds)
	for op in card_ops.keys():
		var cards: Array = card_ops[op]
		var examples := ", ".join(cards.slice(0, 3))
		if cards.size() > 3:
			examples += " (+%d more)" % (cards.size() - 3)
		_assert(handled_ops.has(op),
			"Unhandled op \"%s\" used by %d card(s): %s" % [op, cards.size(), examples])


func _test_target_coverage(seeds: Array, handled_targets: Dictionary) -> void:
	var card_targets := _collect_targets_from_seeds(seeds)
	for target in card_targets.keys():
		var cards: Array = card_targets[target]
		var examples := ", ".join(cards.slice(0, 3))
		if cards.size() > 3:
			examples += " (+%d more)" % (cards.size() - 3)
		_assert(handled_targets.has(target),
			"Unhandled target \"%s\" used by %d card(s): %s" % [target, cards.size(), examples])


func _test_trigger_target_mode_coverage(seeds: Array, handled_modes: Dictionary) -> void:
	var card_modes := _collect_trigger_target_modes(seeds)
	for mode in card_modes.keys():
		var cards: Array = card_modes[mode]
		var examples := ", ".join(cards.slice(0, 3))
		if cards.size() > 3:
			examples += " (+%d more)" % (cards.size() - 3)
		_assert(handled_modes.has(mode),
			"Unhandled trigger target_mode \"%s\" used by %d card(s): %s" % [mode, cards.size(), examples])


func _test_action_target_mode_coverage(seeds: Array, handled_modes: Dictionary) -> void:
	var card_modes := _collect_action_target_modes(seeds)
	for mode in card_modes.keys():
		var cards: Array = card_modes[mode]
		var examples := ", ".join(cards.slice(0, 3))
		if cards.size() > 3:
			examples += " (+%d more)" % (cards.size() - 3)
		_assert(handled_modes.has(mode),
			"Unhandled action_target_mode \"%s\" used by %d card(s): %s" % [mode, cards.size(), examples])


# ── Utilities ────────────────────────────────────────────────────────

func _ensure_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []
