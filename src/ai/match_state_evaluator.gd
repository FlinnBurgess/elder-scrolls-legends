class_name MatchStateEvaluator
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")

const HEALTH_WEIGHT := 2.5
const RUNE_WEIGHT := 1.25
const HAND_WEIGHT := 0.8
const OPPONENT_HAND_WEIGHT := 0.45
const UNUSED_MAGICKA_WEIGHT := 0.18
const RING_CHARGE_WEIGHT := 0.45
const SUPPORT_BASE_VALUE := 1.1
const INCOMING_THREAT_WEIGHT := 3.5


static func evaluate_state(match_state: Dictionary, perspective_player_id: String) -> float:
	var me := _find_player_state(match_state, perspective_player_id)
	var opponent_id := _opposing_player_id(match_state, perspective_player_id)
	var opponent := _find_player_state(match_state, opponent_id)
	if me.is_empty() or opponent.is_empty():
		return -1000000.0
	var winner_player_id := str(match_state.get("winner_player_id", ""))
	if winner_player_id == perspective_player_id:
		return 1000000.0
	if winner_player_id == opponent_id:
		return -1000000.0
	var score := 0.0
	score += (int(me.get("health", 0)) - int(opponent.get("health", 0))) * HEALTH_WEIGHT
	score += (int(me.get("rune_thresholds", []).size()) - int(opponent.get("rune_thresholds", []).size())) * RUNE_WEIGHT
	score += _board_value(match_state, perspective_player_id)
	score += _support_zone_value(me) - _support_zone_value(opponent)
	score += _hand_value(me) * HAND_WEIGHT
	score -= _hand_value(opponent) * OPPONENT_HAND_WEIGHT
	score += float(MatchTurnLoop.get_available_magicka(me)) * UNUSED_MAGICKA_WEIGHT if str(match_state.get("active_player_id", "")) == perspective_player_id else 0.0
	score += float(int(me.get("ring_of_magicka_charges", 0))) * RING_CHARGE_WEIGHT
	score -= float(int(opponent.get("ring_of_magicka_charges", 0))) * RING_CHARGE_WEIGHT
	score -= float(_incoming_face_threat(match_state, perspective_player_id)) * INCOMING_THREAT_WEIGHT
	score += float(_incoming_face_threat(match_state, opponent_id)) * (INCOMING_THREAT_WEIGHT * 0.55)
	return score


static func _board_value(match_state: Dictionary, perspective_player_id: String) -> float:
	var total := 0.0
	for lane in match_state.get("lanes", []):
		for raw_player_id in _player_ids(match_state):
			for card in lane.get("player_slots", {}).get(raw_player_id, []):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var value := _creature_value(match_state, card)
				if raw_player_id == perspective_player_id:
					total += value
				else:
					total -= value * 1.25
	return total


static func _creature_value(match_state: Dictionary, card: Dictionary) -> float:
	var value := float(EvergreenRules.get_power(card)) * 2.2
	value += float(EvergreenRules.get_remaining_health(card)) * 1.7
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
		value += 1.8
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_WARD):
		value += 1.2
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_LETHAL):
		value += 1.1
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_DRAIN):
		value += 0.8
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_BREAKTHROUGH):
		value += 0.4
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_REGENERATE):
		value += 0.6
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_RALLY):
		value += 0.4
	if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_CHARGE):
		value += 0.3
	if EvergreenRules.is_cover_active(match_state, card):
		value += 0.9
	if _can_attack_now(match_state, card):
		value += 1.2 + float(EvergreenRules.get_power(card)) * 0.35
	return value


static func _support_zone_value(player_state: Dictionary) -> float:
	var total := 0.0
	for card in player_state.get("support", []):
		if typeof(card) != TYPE_DICTIONARY:
			continue
		total += SUPPORT_BASE_VALUE
		total += float(int(card.get("cost", 0))) * 0.2
		total += float(int(card.get("remaining_support_uses", card.get("support_uses", 0)))) * 0.2
		total += 0.6 if int(card.get("activation_cost", -1)) >= 0 else 0.0
	return total


static func _hand_value(player_state: Dictionary) -> float:
	var total := 0.0
	for card in player_state.get("hand", []):
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var card_value := 0.35 + float(mini(int(card.get("cost", 0)), 6)) * 0.18
		match str(card.get("card_type", "")):
			"creature":
				card_value += float(EvergreenRules.get_power(card)) * 0.22 + float(EvergreenRules.get_health(card)) * 0.16
			"support":
				card_value += 0.9
			"item":
				card_value += 0.85
			"action":
				card_value += 0.8
		if _array_has_string(card.get("rules_tags", []), "prophecy"):
			card_value += 0.25
		total += card_value
	return total


static func _incoming_face_threat(match_state: Dictionary, defending_player_id: String) -> int:
	var attacker_player_id := _opposing_player_id(match_state, defending_player_id)
	var total := 0
	for lane in match_state.get("lanes", []):
		var friendly_guards := _lane_guards(lane, defending_player_id)
		if not friendly_guards.is_empty():
			continue
		for card in lane.get("player_slots", {}).get(attacker_player_id, []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			if _can_threaten_face_next_turn(card):
				total += EvergreenRules.get_power(card)
	return total


static func _can_attack_now(match_state: Dictionary, card: Dictionary) -> bool:
	if bool(card.get("cannot_attack", false)):
		return false
	if str(card.get("controller_player_id", "")) != str(match_state.get("active_player_id", "")):
		return false
	if EvergreenRules.has_status(card, EvergreenRules.STATUS_SHACKLED):
		return false
	if bool(card.get("has_attacked_this_turn", false)):
		return false
	if int(card.get("entered_lane_on_turn", -1)) == int(match_state.get("turn_number", 0)) and not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_CHARGE):
		return false
	return true


static func _can_threaten_face_next_turn(card: Dictionary) -> bool:
	if bool(card.get("cannot_attack", false)):
		return false
	return true


static func _lane_guards(lane: Dictionary, player_id: String) -> Array:
	var guards: Array = []
	for card in lane.get("player_slots", {}).get(player_id, []):
		if typeof(card) == TYPE_DICTIONARY and EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
			guards.append(card)
	return guards


static func _find_player_state(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _player_ids(match_state: Dictionary) -> Array:
	var ids: Array = []
	for player in match_state.get("players", []):
		ids.append(str(player.get("player_id", "")))
	return ids


static func _opposing_player_id(match_state: Dictionary, player_id: String) -> String:
	for candidate in _player_ids(match_state):
		if candidate != player_id:
			return candidate
	return ""


static func _array_has_string(values, expected: String) -> bool:
	if typeof(values) != TYPE_ARRAY:
		return false
	for value in values:
		if str(value) == expected:
			return true
	return false