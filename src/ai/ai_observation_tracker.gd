class_name AIObservationTracker
extends RefCounted

## Tracks which opponent cards the AI has *publicly observed* during a match.
##
## Used by ISMCTSDeterminizer to avoid sampling cards the AI already knows the
## opponent has (and to constrain the plausible attribute pool to attributes
## the opponent has demonstrably played).
##
## Storage: a dict on match_state under `_ai_observed_by_pid`, keyed by the AI
## player_id; each value is `{def_id: count}` — counts observed copies of each
## definition. Survives `_lightweight_clone` because it deep-duplicates.
##
## Scan-on-demand: each call to `observe()` walks the opponent's public zones
## (lanes, supports, discard, banished) and re-derives the observation set.
## Cards in the opponent's hand or unrevealed deck do NOT count as observed.

const STATE_KEY := "_ai_observed_by_pid"


static func observe(match_state: Dictionary, ai_player_id: String) -> Dictionary:
	var observed := _empty_observation()
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == ai_player_id:
			continue
		# Lanes (creatures + supports on the field)
		for lane in match_state.get("lanes", []):
			var slots: Array = lane.get("player_slots", {}).get(str(player.get("player_id", "")), [])
			for card in slots:
				_observe_card(observed, card)
		# Supports zone (some games store supports separately from lanes)
		for card in player.get("support", []):
			_observe_card(observed, card)
		# Discard pile (publicly visible)
		for card in player.get("discard", []):
			_observe_card(observed, card)
		# Banished zone
		for card in player.get("banished", []):
			_observe_card(observed, card)
		# Double archive (resolved doubles)
		for card in player.get("double_archive", []):
			_observe_card(observed, card)
	_store(match_state, ai_player_id, observed)
	return observed


static func get_observed(match_state: Dictionary, ai_player_id: String) -> Dictionary:
	var by_pid: Dictionary = match_state.get(STATE_KEY, {})
	var entry: Dictionary = by_pid.get(ai_player_id, {})
	if entry.is_empty():
		return _empty_observation()
	return entry.duplicate(true)


static func observed_def_counts(match_state: Dictionary, ai_player_id: String) -> Dictionary:
	return get_observed(match_state, ai_player_id).get("def_counts", {})


static func observed_attributes(match_state: Dictionary, ai_player_id: String) -> Array:
	var attrs: Array = get_observed(match_state, ai_player_id).get("attributes", [])
	return attrs.duplicate()


static func _empty_observation() -> Dictionary:
	return {
		"def_counts": {},
		"attributes": [],
	}


static func _observe_card(observed: Dictionary, card: Dictionary) -> void:
	if typeof(card) != TYPE_DICTIONARY or card.is_empty():
		return
	var def_id := str(card.get("definition_id", ""))
	if def_id.is_empty():
		return
	var counts: Dictionary = observed.get("def_counts", {})
	counts[def_id] = int(counts.get(def_id, 0)) + 1
	observed["def_counts"] = counts
	var card_attrs: Array = card.get("attributes", [])
	var attrs: Array = observed.get("attributes", [])
	for attr in card_attrs:
		var attr_str := str(attr)
		if attr_str.is_empty() or attr_str == "neutral":
			continue
		if not attrs.has(attr_str):
			attrs.append(attr_str)
	observed["attributes"] = attrs


static func _store(match_state: Dictionary, ai_player_id: String, observed: Dictionary) -> void:
	var by_pid: Dictionary = match_state.get(STATE_KEY, {})
	by_pid[ai_player_id] = observed
	match_state[STATE_KEY] = by_pid
