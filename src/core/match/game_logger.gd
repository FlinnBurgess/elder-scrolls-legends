class_name GameLogger
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")

const LOG_PATH := "res://game_log.txt"

const KEYWORD_EFFECT_IDS := ["breakthrough", "charge", "drain", "guard", "lethal", "mobilize", "rally", "regenerate", "ward"]
const FAMILY_EFFECT_IDS := ["summon", "slay", "last_gasp", "pilfer", "veteran", "expertise", "plot", "activate"]
const OP_EFFECT_IDS := ["damage", "heal", "draw", "silence", "destroy", "unsummon", "steal", "transform", "banish", "discard", "sacrifice", "copy", "modify_stats", "shackle"]

static var _file: FileAccess = null
static var _active_match_state: Dictionary = {}
static var _missing_effect_cards: Array = []


static func start_match(match_state: Dictionary) -> void:
	_missing_effect_cards = []
	_active_match_state = match_state
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _file == null:
		push_error("GameLogger: Failed to open log file at %s" % LOG_PATH)
		return
	_write("=== MATCH START ===")
	var players: Array = match_state.get("players", [])
	var starting_player_id := str(match_state.get("starting_player_id", ""))
	for player in players:
		var pid := str(player.get("player_id", ""))
		var is_first := pid == starting_player_id
		var ring_note := " (goes first)" if is_first else " (has ring)"
		_write("Player: %s%s" % [pid, ring_note])
		var deck: Array = player.get("deck", [])
		var hand: Array = player.get("hand", [])
		var card_names: Array = []
		for card in hand + deck:
			if typeof(card) == TYPE_DICTIONARY:
				card_names.append(str(card.get("name", card.get("definition_id", "?"))))
		_write("  Deck (%d cards): %s" % [card_names.size(), ", ".join(card_names)])
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


static func close() -> void:
	_active_match_state = {}
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


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
	var cost := int(card.get("cost", 0))
	var player_id := str(event.get("player_id", ""))
	var lane_index: int = int(event.get("lane_index", -1))
	var lane_str := ""
	if lane_index >= 0:
		lane_str = " to %s" % _lane_name(match_state, lane_index)
	_write("[PLAY] %s played \"%s\" (%s, cost %d)%s" % [player_id, card_name, card_type, cost, lane_str])
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
	var source_id := str(event.get("source_instance_id", ""))
	var card := _find_card(match_state, source_id)
	var card_name := str(card.get("name", source_id)) if not card.is_empty() else source_id
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
		var effects: Array = ability.get("effects", [])
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
		# "draw" maps to "draw_cards" op
		if id == "draw" and "draw_cards" in configured_ops:
			continue
		# "damage" also maps to "deal_damage" op
		if id == "damage" and "deal_damage" in configured_ops:
			continue
		# "destroy" maps to "destroy" or "destroy_creature" op or "lethal" keyword
		if id == "destroy" and ("destroy" in configured_ops or "destroy_creature" in configured_ops or "lethal" in keywords):
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
