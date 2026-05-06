class_name GameLogger
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const DeckCodeClass = preload("res://src/deck/deck_code.gd")
const AIDecisionLogger = preload("res://src/ai/ai_decision_logger.gd")

static var LOG_PATH := "res://game_log.txt" if OS.has_feature("editor") else "user://game_log.txt"
static var TRACE_PATH := "res://game_trace.txt" if OS.has_feature("editor") else "user://game_trace.txt"

const KEYWORD_EFFECT_IDS := ["breakthrough", "charge", "drain", "guard", "lethal", "mobilize", "rally", "regenerate", "ward"]
const FAMILY_EFFECT_IDS := ["summon", "slay", "last_gasp", "pilfer", "veteran", "expertise", "plot", "activate"]
const OP_EFFECT_IDS := ["damage", "heal", "draw", "silence", "destroy", "unsummon", "steal", "transform", "banish", "discard", "sacrifice", "copy", "modify_stats", "shackle"]

static var _file: FileAccess = null
static var _trace_file: FileAccess = null
static var _trace_buffer: PackedStringArray = PackedStringArray()
static var _active_match_state: Dictionary = {}
static var _missing_effect_cards: Array = []
static var _suppress_count: int = 0


static func trc(node: String, method: String, vars_str: String) -> void:
	if _suppress_count > 0:
		return
	var line := "[TRC]|%s|%s|%s|%s" % [Engine.get_physics_frames(), node, method, vars_str]
	print(line)
	_trace_buffer.append(line)


static func suppress() -> void:
	_suppress_count += 1


static func unsuppress() -> void:
	_suppress_count = maxi(0, _suppress_count - 1)


static func start_match(match_state: Dictionary) -> void:
	_missing_effect_cards = []
	_active_match_state = match_state
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _file == null:
		push_error("GameLogger: Failed to open log file at %s" % LOG_PATH)
		return
	_trace_file = FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	# Open a fresh AI decision log alongside the main game log so each match
	# has matching telemetry files for inspection.
	AIDecisionLogger.start_match()
	_write("=== MATCH START ===")
	var rng_seed: int = int(match_state.get("rng_seed", 0))
	var catalog_result := CardCatalog.load_default()
	var card_id_to_deck_code: Dictionary = catalog_result.get("card_id_to_deck_code", {})
	var players: Array = match_state.get("players", [])
	var starting_player_id := str(match_state.get("starting_player_id", ""))
	var deck_codes: Array = []
	for player in players:
		var pid := str(player.get("player_id", ""))
		var is_first := pid == starting_player_id
		var ring_note := " (goes first)" if is_first else " (has ring)"
		_write("Player: %s%s" % [pid, ring_note])
		var all_cards: Array = player.get("hand", []) + player.get("deck", [])
		var id_counts := {}
		for card in all_cards:
			if typeof(card) == TYPE_DICTIONARY:
				var def_id := str(card.get("definition_id", ""))
				if not def_id.is_empty():
					id_counts[def_id] = id_counts.get(def_id, 0) + 1
		var deck_def_cards: Array = []
		for def_id in id_counts:
			deck_def_cards.append({"card_id": def_id, "quantity": id_counts[def_id]})
		var deck_code: String = DeckCodeClass.encode({"cards": deck_def_cards}, card_id_to_deck_code).get("code", "")
		deck_codes.append(deck_code)
		_write("  Deck code: %s" % deck_code)
	var match_summary := "Match started — seed:%d player:%s enemy:%s" % [rng_seed, deck_codes[1], deck_codes[0]]
	print(match_summary)
	_write(match_summary)
	_write("")


static func log_event(match_state: Dictionary, event: Dictionary) -> void:
	if _file == null or not is_same(match_state, _active_match_state):
		return
	var event_type := str(event.get("event_type", ""))
	match event_type:
		"turn_started":
			_log_turn_started(match_state, event)
		"turn_ending":
			_log_turn_ending(event)
		"card_played":
			_log_card_played(match_state, event)
		"creature_summoned":
			_log_creature_summoned(match_state, event)
		"damage_resolved":
			_log_damage_resolved(match_state, event)
		"creature_destroyed":
			_log_creature_destroyed(match_state, event)
		"card_drawn":
			_log_card_drawn(match_state, event)
		"rune_broken":
			_log_rune_broken(match_state, event)
		"prophecy_window_opened":
			_log_prophecy_window(match_state, event)
		"prophecy_declined":
			_log_prophecy_declined(match_state, event)
		"support_activated":
			_log_support_activated(match_state, event)
		"match_won":
			_log_match_won(match_state, event)
		"out_of_cards_played":
			_write("[FATIGUE] %s took fatigue damage" % str(event.get("player_id", "")))
		"max_magicka_gained":
			var player_id := str(event.get("target_player_id", ""))
			var amount := int(event.get("amount", 0))
			_write("[MAGICKA] %s gained +%d max magicka" % [player_id, amount])


static func log_trigger_resolution(match_state: Dictionary, resolution: Dictionary, trigger: Dictionary) -> void:
	if _file == null or not is_same(match_state, _active_match_state):
		return
	var source_id := str(resolution.get("source_instance_id", ""))
	var card := _find_card(match_state, source_id)
	var card_name := str(card.get("name", source_id))
	var family := str(resolution.get("family", ""))
	var descriptor: Dictionary = trigger.get("descriptor", {})
	var effects: Array = descriptor.get("effects", [])
	var effect_summaries: Array = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var op := str(effect.get("op", ""))
		var summary := op
		if effect.has("amount"):
			summary += " (%s)" % str(effect.get("amount"))
		if effect.has("target"):
			summary += " -> %s" % str(effect.get("target"))
		elif effect.has("target_player"):
			summary += " -> %s" % str(effect.get("target_player"))
		if effect.has("keyword_id"):
			summary += " [%s]" % str(effect.get("keyword_id"))
		if effect.has("status_id"):
			summary += " [%s]" % str(effect.get("status_id"))
		if effect.has("card_template"):
			var tmpl = effect.get("card_template", {})
			if typeof(tmpl) == TYPE_DICTIONARY:
				summary += " {%s}" % str(tmpl.get("name", tmpl.get("definition_id", "")))
		effect_summaries.append(summary)
	var effects_str := ", ".join(effect_summaries) if not effect_summaries.is_empty() else "(no effects)"
	_write("  [TRIGGER] \"%s\" (%s) -> %s" % [card_name, family, effects_str])


static func write_debug(line: String) -> void:
	print(line)
	if _trace_file != null:
		_flush_trace_buffer()
		_write_trace(line)


static func close() -> void:
	_active_match_state = {}
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
	if _trace_file != null:
		_flush_trace_buffer()
		_trace_file.flush()
		_trace_file.close()
		_trace_file = null


static func copy_trace_to_clipboard() -> bool:
	if _trace_file != null:
		_flush_trace_buffer()
		_trace_file.flush()
	if not FileAccess.file_exists(TRACE_PATH):
		return false
	var reader := FileAccess.open(TRACE_PATH, FileAccess.READ)
	if reader == null:
		return false
	var contents := reader.get_as_text()
	reader.close()
	DisplayServer.clipboard_set(contents)
	return true


# --- Private event handlers ---

static func _log_turn_started(match_state: Dictionary, event: Dictionary) -> void:
	var turn := int(match_state.get("turn_number", 0))
	var active_pid := str(match_state.get("active_player_id", ""))
	var player := _get_player(match_state, active_pid)
	var max_magicka := int(player.get("max_magicka", 0))
	var current_magicka := int(player.get("current_magicka", 0))
	_write("")
	_write("--- TURN %d (%s) | Magicka: %d/%d ---" % [turn, active_pid, current_magicka, max_magicka])
	_log_board_state(match_state)


static func _log_turn_ending(event: Dictionary) -> void:
	_write("--- END TURN ---")


static func _log_card_played(match_state: Dictionary, event: Dictionary) -> void:
	var source_id := str(event.get("source_instance_id", ""))
	var card := _find_card(match_state, source_id)
	var card_name := str(card.get("name", source_id))
	var card_type := str(card.get("card_type", ""))
	var base_cost := int(card.get("cost", 0))
	var played_cost := int(event.get("played_cost", base_cost))
	var player_id := str(event.get("player_id", ""))
	var lane_index: int = int(event.get("lane_index", -1))
	var lane_str := ""
	if lane_index >= 0:
		lane_str = " to %s" % _lane_name(match_state, lane_index)
	var cost_str := str(played_cost) if played_cost == base_cost else "%d (base %d)" % [played_cost, base_cost]
	_write("[PLAY] %s played \"%s\" (%s, cost %s)%s" % [player_id, card_name, card_type, cost_str, lane_str])
	_check_missing_effects(card)


static func _log_creature_summoned(match_state: Dictionary, event: Dictionary) -> void:
	var source_id := str(event.get("source_instance_id", ""))
	var card := _find_card(match_state, source_id)
	var card_name := str(card.get("name", source_id))
	var lane_index: int = int(event.get("lane_index", -1))
	var lane_str := ""
	if lane_index >= 0:
		lane_str = " in %s" % _lane_name(match_state, lane_index)
	var power := EvergreenRules.get_power(card)
	var health := EvergreenRules.get_remaining_health(card)
	_write("[SUMMON] \"%s\" (%d/%d) summoned%s" % [card_name, power, health, lane_str])
	# Also check for missing effects on summoned creatures (covers summon-from-effect cards)
	if not card.get("_effects_checked", false):
		_check_missing_effects(card)


static func _log_damage_resolved(match_state: Dictionary, event: Dictionary) -> void:
	var source_id := str(event.get("source_instance_id", ""))
	var target_id := str(event.get("target_instance_id", ""))
	var amount := int(event.get("amount", 0))
	var source_card := _find_card(match_state, source_id)
	var source_name := str(source_card.get("name", source_id)) if not source_card.is_empty() else source_id
	var target_player_id := str(event.get("target_player_id", ""))
	if not target_player_id.is_empty():
		var player := _get_player(match_state, target_player_id)
		var hp := int(player.get("health", 0))
		_write("[DAMAGE] \"%s\" dealt %d damage to %s (%s: %d HP)" % [source_name, amount, target_player_id, target_player_id, hp])
	else:
		var target_card := _find_card(match_state, target_id)
		var target_name := str(target_card.get("name", target_id)) if not target_card.is_empty() else target_id
		_write("[DAMAGE] \"%s\" dealt %d damage to \"%s\"" % [source_name, amount, target_name])


static func _log_creature_destroyed(match_state: Dictionary, event: Dictionary) -> void:
	var subject_id := str(event.get("subject_instance_id", event.get("source_instance_id", "")))
	var killer_id := str(event.get("killer_instance_id", ""))
	var subject_name := subject_id
	var subject_card := _find_card(match_state, subject_id)
	if not subject_card.is_empty():
		subject_name = str(subject_card.get("name", subject_id))
	var killer_str := ""
	if not killer_id.is_empty():
		var killer_card := _find_card(match_state, killer_id)
		if not killer_card.is_empty():
			killer_str = " by \"%s\"" % str(killer_card.get("name", killer_id))
	_write("[DEATH] \"%s\" destroyed%s" % [subject_name, killer_str])


static func _log_card_drawn(match_state: Dictionary, event: Dictionary) -> void:
	var player_id := str(event.get("player_id", ""))
	var drawn_id := str(event.get("drawn_instance_id", ""))
	var card := _find_card(match_state, drawn_id)
	var card_name := str(card.get("name", drawn_id)) if not card.is_empty() else drawn_id
	_write("[DRAW] %s drew \"%s\"" % [player_id, card_name])


static func _log_rune_broken(match_state: Dictionary, event: Dictionary) -> void:
	var player_id := str(event.get("player_id", ""))
	var threshold := int(event.get("threshold", 0))
	_write("[RUNE] %s rune broken at %d HP" % [player_id, threshold])


static func _log_prophecy_window(match_state: Dictionary, event: Dictionary) -> void:
	var player_id := str(event.get("player_id", ""))
	var source_id := str(event.get("source_instance_id", ""))
	var card := _find_card(match_state, source_id)
	var card_name := str(card.get("name", source_id)) if not card.is_empty() else source_id
	_write("[PROPHECY] %s has prophecy window for \"%s\"" % [player_id, card_name])


static func _log_prophecy_declined(match_state: Dictionary, event: Dictionary) -> void:
	var player_id := str(event.get("player_id", ""))
	_write("[PROPHECY] %s declined prophecy" % player_id)


static func _log_support_activated(match_state: Dictionary, event: Dictionary) -> void:
	var source_id := str(event.get("source_instance_id", ""))
	var card := _find_card(match_state, source_id)
	var card_name := str(card.get("name", source_id)) if not card.is_empty() else source_id
	var player_id := str(event.get("player_id", ""))
	_write("[ACTIVATE] %s activated \"%s\"" % [player_id, card_name])


static func _log_match_won(match_state: Dictionary, event: Dictionary) -> void:
	var winner := str(event.get("winner_player_id", ""))
	var loser := str(event.get("loser_player_id", ""))
	var winner_player := _get_player(match_state, winner)
	var loser_player := _get_player(match_state, loser)
	var turn := int(match_state.get("turn_number", 0))
	_write("")
	_write("=== MATCH END ===")
	_write("Winner: %s | %s: %d HP | %s: %d HP" % [
		winner,
		winner, int(winner_player.get("health", 0)),
		loser, int(loser_player.get("health", 0)),
	])
	_write("Total turns: %d" % turn)
	if not _missing_effect_cards.is_empty():
		_write("")
		_write("=== MISSING EFFECTS SUMMARY ===")
		_write("Cards played with missing/uncovered effect_ids:")
		for i in range(_missing_effect_cards.size()):
			var entry: Dictionary = _missing_effect_cards[i]
			_write("  %d. \"%s\" (%s) - uncovered: %s" % [
				i + 1,
				str(entry.get("name", "")),
				str(entry.get("definition_id", "")),
				str(entry.get("uncovered", [])),
			])
			var rules_text := str(entry.get("rules_text", ""))
			if not rules_text.is_empty():
				_write("     Rules text: \"%s\"" % rules_text)
	close()


# --- Missing effect detection ---

static func _check_missing_effects(card: Dictionary) -> void:
	if typeof(card) != TYPE_DICTIONARY or card.is_empty():
		return
	card["_effects_checked"] = true
	var effect_ids: Array = card.get("effect_ids", [])
	if typeof(effect_ids) != TYPE_ARRAY or effect_ids.is_empty():
		return

	var card_type := str(card.get("card_type", ""))
	var keywords: Array = card.get("keywords", [])
	if typeof(keywords) != TYPE_ARRAY:
		keywords = []
	var rules_tags: Array = card.get("rules_tags", [])
	if typeof(rules_tags) != TYPE_ARRAY:
		rules_tags = []
	var triggered_abilities: Array = card.get("triggered_abilities", [])
	if typeof(triggered_abilities) != TYPE_ARRAY:
		triggered_abilities = []

	# Collect all families and ops from triggered_abilities
	var configured_families: Array = []
	var configured_ops: Array = []
	for ability in triggered_abilities:
		if typeof(ability) != TYPE_DICTIONARY:
			continue
		var family := str(ability.get("family", ""))
		if not family.is_empty():
			configured_families.append(family)
		for _eff_key in ["effects", "plot_effects"]:
			var effects: Array = ability.get(_eff_key, [])
			if typeof(effects) != TYPE_ARRAY:
				continue
			for effect in effects:
				if typeof(effect) != TYPE_DICTIONARY:
					continue
				var op := str(effect.get("op", ""))
				if not op.is_empty():
					configured_ops.append(op)

	var is_item := card_type == "item"
	var has_equip_bonus := int(card.get("equip_power_bonus", 0)) != 0 or int(card.get("equip_health_bonus", 0)) != 0
	var equip_kw: Array = card.get("equip_keywords", [])
	var has_equip_keywords := not equip_kw.is_empty()

	var uncovered: Array = []
	for eid in effect_ids:
		var id := str(eid)
		# Covered by keywords
		if id in keywords:
			continue
		# Covered by rules_tags (e.g. prophecy)
		if id in rules_tags:
			continue
		# "equip" on items is inherent
		if id == "equip" and is_item:
			continue
		# "modify_stats" on items with equip bonuses
		if id == "modify_stats" and is_item and (has_equip_bonus or has_equip_keywords):
			continue
		# "modify_stats" covered by grant_aura_by_chosen_subtype op
		if id == "modify_stats" and "grant_aura_by_chosen_subtype" in configured_ops:
			continue
		# Covered by a trigger family
		if id in FAMILY_EFFECT_IDS and id in configured_families:
			continue
		# "last_gasp" maps to both "last_gasp" and "on_death" families
		if id == "last_gasp" and ("last_gasp" in configured_families or "on_death" in configured_families):
			continue
		# "summon" on non-creature cards maps to "on_play" family
		if id == "summon" and card_type != "creature" and "on_play" in configured_families:
			continue
		# "summon" covered by summon_from_effect or summon_copies_to_lane ops
		if id == "summon" and ("summon_from_effect" in configured_ops or "summon_copies_to_lane" in configured_ops):
			continue
		# "create" covered by summoning ops (creating tokens)
		if id == "create" and ("summon_from_effect" in configured_ops or "summon_copies_to_lane" in configured_ops):
			continue
		# Covered by an op in a triggered ability
		if id in OP_EFFECT_IDS and id in configured_ops:
			continue
		# "draw" maps to "draw_cards", "draw_cards_per_runes", or "draw_from_deck_filtered" op
		if id == "draw" and ("draw_cards" in configured_ops or "draw_cards_per_runes" in configured_ops or "draw_from_deck_filtered" in configured_ops):
			continue
		# "draw" also covered by any effect carrying a follow_up_draw parameter
		if id == "draw":
			var has_follow_up_draw := false
			for ability in card.get("triggered_abilities", []):
				if typeof(ability) != TYPE_DICTIONARY:
					continue
				for effect in ability.get("effects", []):
					if typeof(effect) == TYPE_DICTIONARY and int(effect.get("follow_up_draw", 0)) > 0:
						has_follow_up_draw = true
						break
				if has_follow_up_draw:
					break
			if has_follow_up_draw:
				continue
		# "damage" also maps to "deal_damage" op
		if id == "damage" and "deal_damage" in configured_ops:
			continue
		# "destroy" maps to "destroy" or "destroy_creature" op or "lethal" keyword
		if id == "destroy" and ("destroy" in configured_ops or "destroy_creature" in configured_ops or "lethal" in keywords):
			continue
		# "equip" maps to "equip_item" or "equip_generated_item" ops
		if id == "equip" and ("equip_item" in configured_ops or "equip_generated_item" in configured_ops):
			continue
		# "transform" maps to ops like "transform_in_hand_to_random", "transform_hand", etc.
		if id == "transform":
			var has_transform_op := false
			for op in configured_ops:
				if str(op).begins_with("transform"):
					has_transform_op = true
					break
			if has_transform_op:
				continue
		# "wax_wane" covered by having wax and/or wane families
		if id == "wax_wane" and ("wax" in configured_families or "wane" in configured_families):
			continue
		# "empower" is handled via empower_bonus/empower_stat_bonus/empower_bonus_cost params
		# on existing ops, or via self_cost_reduction with type "empower", or via permanent_empower passive
		if id == "empower":
			var has_empower_param := false
			for ability in card.get("triggered_abilities", []):
				if typeof(ability) != TYPE_DICTIONARY:
					continue
				for effect in ability.get("effects", []):
					if typeof(effect) != TYPE_DICTIONARY:
						continue
					if effect.has("empower_bonus") or effect.has("empower_stat_bonus") or effect.has("empower_bonus_cost"):
						has_empower_param = true
						break
				if has_empower_param:
					break
			var self_red = card.get("self_cost_reduction", {})
			if typeof(self_red) == TYPE_DICTIONARY and str(self_red.get("type", "")) == "empower":
				has_empower_param = true
			for passive in card.get("passive_abilities", []):
				if typeof(passive) == TYPE_DICTIONARY and str(passive.get("type", "")) == "permanent_empower":
					has_empower_param = true
					break
			if has_empower_param:
				continue
		uncovered.append(id)

	if not uncovered.is_empty():
		var card_name := str(card.get("name", ""))
		var def_id := str(card.get("definition_id", ""))
		var rules_text := str(card.get("rules_text", ""))
		_write("  >> WARNING: MISSING EFFECT - \"%s\" (%s) has uncovered effect_ids: %s" % [card_name, def_id, str(uncovered)])
		if not rules_text.is_empty():
			_write("  >> Rules text: \"%s\"" % rules_text)
		_missing_effect_cards.append({
			"name": card_name,
			"definition_id": def_id,
			"uncovered": uncovered,
			"rules_text": rules_text,
		})


# --- Board state ---

static func _log_board_state(match_state: Dictionary) -> void:
	var lanes: Array = match_state.get("lanes", [])
	var players: Array = match_state.get("players", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var lane_name := _lane_name(match_state, lane_index)
		var player_slots: Dictionary = lane.get("player_slots", {})
		var lane_parts: Array = []
		for player in players:
			var pid := str(player.get("player_id", ""))
			var slots: Array = player_slots.get(pid, [])
			var creatures: Array = []
			for card in slots:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var name := str(card.get("name", "?"))
				var power := EvergreenRules.get_power(card)
				var health := EvergreenRules.get_remaining_health(card)
				creatures.append("\"%s\" %d/%d" % [name, power, health])
			var slot_str := ", ".join(creatures) if not creatures.is_empty() else "(empty)"
			lane_parts.append("%s: %s" % [pid, slot_str])
		_write("[BOARD] %s | %s" % [lane_name, " | ".join(lane_parts)])
	# Supports
	for player in players:
		var pid := str(player.get("player_id", ""))
		var supports: Array = player.get("support", [])
		if supports.is_empty():
			continue
		var support_names: Array = []
		for card in supports:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			support_names.append("\"%s\"" % str(card.get("name", "?")))
		_write("[BOARD] Supports %s: %s" % [pid, ", ".join(support_names)])
	# Player health
	var hp_parts: Array = []
	for player in players:
		var pid := str(player.get("player_id", ""))
		var hp := int(player.get("health", 0))
		var runes := int(player.get("rune_count", player.get("runes", 0)))
		hp_parts.append("%s: %d HP" % [pid, hp])
	_write("[BOARD] %s" % " | ".join(hp_parts))


# --- Helpers ---

static func _write(line: String) -> void:
	if _file != null:
		_file.store_line(line)
		_file.flush()
	_flush_trace_buffer()
	_write_trace(line)


static func _write_trace(line: String) -> void:
	if _trace_file != null:
		_trace_file.store_line(line)
		_trace_file.flush()


static func _flush_trace_buffer() -> void:
	if _trace_file == null or _trace_buffer.is_empty():
		return
	for buffered_line in _trace_buffer:
		_trace_file.store_line(buffered_line)
	_trace_buffer.clear()
	_trace_file.flush()


static func _find_card(match_state: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for player in match_state.get("players", []):
		for zone_name in ["hand", "support", "discard", "banished", "deck"]:
			var cards = player.get(zone_name, [])
			if typeof(cards) != TYPE_ARRAY:
				continue
			for card in cards:
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return card
	for lane in match_state.get("lanes", []):
		var player_slots: Dictionary = lane.get("player_slots", {})
		for pid in player_slots.keys():
			var slots = player_slots[pid]
			if typeof(slots) != TYPE_ARRAY:
				continue
			for card in slots:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == instance_id:
					return card
				for item in card.get("attached_items", []):
					if typeof(item) == TYPE_DICTIONARY and str(item.get("instance_id", "")) == instance_id:
						return item
	return {}


static func _get_player(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _lane_name(match_state: Dictionary, lane_index: int) -> String:
	var lanes: Array = match_state.get("lanes", [])
	if lane_index >= 0 and lane_index < lanes.size():
		var lane: Dictionary = lanes[lane_index]
		return str(lane.get("lane_id", "Lane %d" % lane_index))
	return "Lane %d" % lane_index
