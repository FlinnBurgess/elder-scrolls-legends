extends SceneTree
## Headless Match Auditor — PoC
##
## Runs N AI-vs-AI matches and audits every trigger resolution and event
## against card definitions, surfacing gameplay rule violations.
##
## Usage:
##   Godot --headless --log-file /tmp/godot.log --path <project> \
##         --script res://tests/headless_match_auditor.gd

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const HeuristicMatchPolicy = preload("res://src/ai/heuristic_match_policy.gd")
const MatchScreen = preload("res://src/ui/match_screen.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ErrorReportWriter = preload("res://src/core/error_report_writer.gd")

const NUM_MATCHES := 50
const MAX_ACTIONS_PER_MATCH := 400
const DECK_SIZE := 30

var _catalog: Dictionary = {}
var _card_by_id: Dictionary = {}
var _creature_ids: Array = []
var _violations: Array = []
var _matches_played := 0
var _total_actions := 0


func _initialize() -> void:
	_catalog = CardCatalog.load_default()
	_card_by_id = _catalog.get("card_by_id", {})
	if _card_by_id.is_empty():
		push_error("Failed to load card catalog.")
		quit(1)
		return

	# Collect all creature definition_ids for deck building
	for card_id in _card_by_id.keys():
		var card: Dictionary = _card_by_id[card_id]
		# Only use cards that are reasonable for random decks
		if str(card.get("card_type", "")) in ["creature", "action", "item", "support"]:
			if not bool(card.get("is_unique", false)):
				_creature_ids.append(card_id)

	print("=== HEADLESS MATCH AUDITOR ===")
	print("Catalog loaded: %d playable cards" % _creature_ids.size())
	print("Running %d matches...\n" % NUM_MATCHES)

	for match_index in range(NUM_MATCHES):
		_run_single_match(match_index)

	print("\n=== AUDIT COMPLETE ===")
	print("Matches played: %d" % _matches_played)
	print("Total actions: %d" % _total_actions)
	print("Violations found: %d" % _violations.size())

	if not _violations.is_empty():
		print("\n--- VIOLATIONS ---")
		for i in range(_violations.size()):
			var v: Dictionary = _violations[i]
			print("[%d] Match %d, Turn %d, Action %d" % [i + 1, int(v.get("match", 0)), int(v.get("turn", 0)), int(v.get("action", 0))])
			print("    Check: %s" % str(v.get("check", "")))
			print("    Detail: %s" % str(v.get("detail", "")))
		print("\nWriting %d bug report(s)..." % _violations.size())
		_write_bug_reports()

	if _violations.is_empty():
		print("\nHEADLESS_AUDITOR_OK")
		quit(0)
	else:
		print("\nHEADLESS_AUDITOR_FOUND_%d_ISSUES" % _violations.size())
		quit(1)


func _run_single_match(match_index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + match_index * 37

	var deck_1 := _build_random_deck(rng)
	var deck_2 := _build_random_deck(rng)

	var match_state := MatchBootstrap.create_standard_match([deck_1, deck_2], {
		"seed": rng.randi(),
		"first_player_index": match_index % 2,
	})
	if match_state.is_empty():
		push_error("Failed to create match %d" % match_index)
		return

	# Hydrate cards so the AI and engine have full card data
	MatchScreen._hydrate_all_zones(match_state, _card_by_id)

	# Apply mulligan (keep all — simplicity for PoC)
	for player in match_state["players"]:
		MatchBootstrap.apply_mulligan(match_state, player["player_id"], [])

	# Re-hydrate after mulligan (mulligan can re-shuffle)
	MatchScreen._hydrate_all_zones(match_state, _card_by_id)

	MatchTurnLoop.begin_first_turn(match_state)

	var action_count := 0
	var consecutive_invalid := 0

	while action_count < MAX_ACTIONS_PER_MATCH:
		if not str(match_state.get("winner_player_id", "")).is_empty():
			break

		var active_id := str(match_state.get("active_player_id", ""))
		if active_id.is_empty():
			break

		var choice := HeuristicMatchPolicy.choose_action(match_state, active_id, {
			"quality": 0.5,
			"lookahead": 0,
		})
		var action: Dictionary = choice.get("chosen_action", {})
		if action.is_empty():
			# No legal actions — try end turn
			if not bool(match_state.get("_end_of_turn_targets_queued", false)):
				MatchTiming.queue_turn_trigger_targets(match_state, active_id)
				match_state["_end_of_turn_targets_queued"] = true
			if MatchTiming.has_pending_turn_trigger_target(match_state, active_id):
				# AI needs to resolve pending turn triggers
				action = HeuristicMatchPolicy.choose_action(match_state, active_id, {"quality": 0.5, "lookahead": 0})
				if action.is_empty():
					MatchTiming.decline_pending_turn_trigger_target(match_state, active_id)
					continue
			else:
				match_state.erase("_end_of_turn_targets_queued")
				MatchTurnLoop.end_turn(match_state, active_id)
				MatchScreen._hydrate_all_zones(match_state, _card_by_id)
				consecutive_invalid = 0
				continue

		# Snapshot state before action for auditing
		var turn_number := int(match_state.get("turn_number", 0))
		var cost_locks_before := _get_cost_locks(match_state)

		var result := MatchActionExecutor.execute_action(match_state, action)
		action_count += 1

		if not bool(result.get("is_valid", false)):
			consecutive_invalid += 1
			if consecutive_invalid > 10:
				break
			continue
		consecutive_invalid = 0

		# Hydrate after end_turn too (new cards drawn at turn start)
		var kind := str(action.get("kind", ""))
		if kind == MatchActionEnumerator.KIND_END_TURN:
			_hydrate_unhydrated_cards(match_state)

		# Hydrate only unhydrated cards (newly drawn/generated) — avoid overwriting
		# runtime state like consumed keywords or stat bonuses on lane creatures
		_hydrate_unhydrated_cards(match_state)

		# --- AUDIT CHECKS ---
		var events: Array = result.get("events", [])
		var resolutions: Array = result.get("trigger_resolutions", [])

		var audit_ctx := {"match": match_index, "turn": turn_number, "action": action_count, "match_state": match_state}
		_audit_subtype_filter(audit_ctx, resolutions)
		_audit_cost_lock_enforcement(audit_ctx, events, cost_locks_before)
		_audit_trigger_family_event_match(audit_ctx, resolutions)
		_audit_ward_consumption(audit_ctx, events)

	_matches_played += 1
	_total_actions += action_count
	var winner := str(match_state.get("winner_player_id", "none"))
	var turn := int(match_state.get("turn_number", 0))
	print("  Match %d: %d actions, %d turns, winner=%s" % [match_index + 1, action_count, turn, winner])


# ── DECK BUILDING ──────────────────────────────────────────────────────────

func _build_random_deck(rng: RandomNumberGenerator) -> Array:
	var deck: Array = []
	for _i in range(DECK_SIZE):
		deck.append(_creature_ids[rng.randi_range(0, _creature_ids.size() - 1)])
	return deck


# ── AUDIT: SUBTYPE FILTER ──────────────────────────────────────────────────
# After each trigger resolution with target_filter_subtype, verify all
# affected cards actually have the required subtype.

func _audit_subtype_filter(ctx: Dictionary, resolutions: Array) -> void:
	var match_state: Dictionary = ctx["match_state"]
	for resolution in resolutions:
		if typeof(resolution) != TYPE_DICTIONARY:
			continue
		var effects: Array = resolution.get("effects", [])
		var descriptor: Dictionary = resolution.get("descriptor", {})
		if effects.is_empty():
			effects = descriptor.get("effects", [])
		for effect in effects:
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			var filter_st := str(effect.get("target_filter_subtype", ""))
			if filter_st.is_empty():
				continue
			var target_ids: Array = resolution.get("affected_instance_ids", [])
			for tid in target_ids:
				var card := _find_card(match_state, str(tid))
				if card.is_empty():
					continue
				var subtypes: Array = card.get("subtypes", [])
				if typeof(subtypes) != TYPE_ARRAY or not subtypes.has(filter_st):
					var source_card := _find_card(match_state, str(resolution.get("source_instance_id", "")))
					_record_violation(ctx, "subtype_filter",
						"Card %s (subtypes=%s) was affected by effect with target_filter_subtype=%s" % [str(card.get("name", tid)), str(subtypes), filter_st],
						str(source_card.get("name", resolution.get("source_instance_id", ""))),
						str(source_card.get("definition_id", "")))


# ── AUDIT: COST LOCK ENFORCEMENT ───────────────────────────────────────────
# After each card_played event, verify the card's cost isn't locked.

func _audit_cost_lock_enforcement(ctx: Dictionary, events: Array, cost_locks_before: Dictionary) -> void:
	var match_state: Dictionary = ctx["match_state"]
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("event_type", "")) != "card_played":
			continue
		if bool(event.get("played_for_free", false)):
			continue
		var playing_player := str(event.get("playing_player_id", ""))
		var played_cost := int(event.get("played_cost", -1))
		var locks: Array = cost_locks_before.get(playing_player, [])
		for lock in locks:
			if int(lock.get("cost", -1)) == played_cost:
				var source_id := str(event.get("source_instance_id", ""))
				var card := _find_card(match_state, source_id)
				var card_name := str(card.get("name", source_id))
				_record_violation(ctx, "cost_lock_enforcement",
					"Player %s played %s (cost %d) but cost %d is locked" % [playing_player, card_name, played_cost, played_cost],
					card_name, str(card.get("definition_id", "")))


# ── AUDIT: TRIGGER FAMILY vs EVENT TYPE ────────────────────────────────────
# Verify trigger resolutions match the expected event type for their family.

func _audit_trigger_family_event_match(ctx: Dictionary, resolutions: Array) -> void:
	var match_state: Dictionary = ctx["match_state"]
	for resolution in resolutions:
		if typeof(resolution) != TYPE_DICTIONARY:
			continue
		var family := str(resolution.get("family", ""))
		var event_type := str(resolution.get("event_type", ""))
		if family.is_empty() or event_type.is_empty():
			continue
		var family_spec: Dictionary = MatchTiming.FAMILY_SPECS.get(family, {})
		if family_spec.is_empty():
			continue
		var expected_event := str(family_spec.get("event_type", ""))
		if expected_event.is_empty():
			continue
		# Slay can fire on pilfer events via pilfer_is_slay — skip that case
		if family == MatchTiming.FAMILY_SLAY and event_type == MatchTiming.EVENT_DAMAGE_RESOLVED:
			continue
		if event_type != expected_event:
			var source_id := str(resolution.get("source_instance_id", ""))
			var card := _find_card(match_state, source_id)
			_record_violation(ctx, "trigger_family_event_mismatch",
				"Trigger family '%s' expects event '%s' but fired on '%s'" % [family, expected_event, event_type],
				str(card.get("name", source_id)), str(card.get("definition_id", "")))


# ── AUDIT: WARD CONSUMPTION ────────────────────────────────────────────────
# After ward_removed events, verify the creature no longer has ward.

func _audit_ward_consumption(ctx: Dictionary, events: Array) -> void:
	var match_state: Dictionary = ctx["match_state"]
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("event_type", "")) != "ward_removed":
			continue
		var target_id := str(event.get("target_instance_id", ""))
		if target_id.is_empty():
			continue
		var card := _find_card(match_state, target_id)
		if card.is_empty():
			continue
		if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_WARD):
			_record_violation(ctx, "ward_not_consumed",
				"Card %s still has ward after ward_removed event" % str(card.get("name", target_id)),
				str(card.get("name", target_id)), str(card.get("definition_id", "")))


# ── HELPERS ────────────────────────────────────────────────────────────────

func _find_card(match_state: Dictionary, instance_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		for zone_name in ["hand", "deck", "support", "discard"]:
			for card in player.get(zone_name, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return card
	for lane in match_state.get("lanes", []):
		for pid in lane.get("player_slots", {}).keys():
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
					return card
	return {}


func _hydrate_unhydrated_cards(match_state: Dictionary) -> void:
	# Only hydrate cards that lack a "name" field (bootstrap cards haven't been hydrated yet)
	for player in match_state.get("players", []):
		for zone_key in ["deck", "hand", "support", "discard"]:
			var zone: Array = player.get(zone_key, [])
			for card in zone:
				if typeof(card) == TYPE_DICTIONARY and not card.has("name"):
					MatchScreen._hydrate_card(card, _card_by_id)
	for lane in match_state.get("lanes", []):
		for pid in lane.get("player_slots", {}).keys():
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) == TYPE_DICTIONARY and not card.has("name"):
					MatchScreen._hydrate_card(card, _card_by_id)


func _record_violation(ctx: Dictionary, check: String, detail: String, card_name: String, definition_id: String) -> void:
	var match_state: Dictionary = ctx["match_state"]
	var history: Array = match_state.get("event_log", [])
	# Take the last 5 events as match_history for the snapshot
	var recent_history: Array = []
	for i in range(maxi(0, history.size() - 5), history.size()):
		if i < history.size() and typeof(history[i]) == TYPE_DICTIONARY:
			recent_history.append(history[i])
	_violations.append({
		"match": int(ctx.get("match", 0)),
		"turn": int(ctx.get("turn", 0)),
		"action": int(ctx.get("action", 0)),
		"check": check,
		"detail": detail,
		"card_name": card_name,
		"definition_id": definition_id,
		"snapshot": ErrorReportWriter.build_match_snapshot(match_state, recent_history),
	})


func _write_bug_reports() -> void:
	# Ensure report directory exists
	var dir := DirAccess.open("res://")
	if dir != null and not dir.dir_exists("reports"):
		dir.make_dir("reports")
	dir = DirAccess.open("res://reports")
	if dir != null and not dir.dir_exists("bug-reports"):
		dir.make_dir("bug-reports")

	for violation in _violations:
		var check := str(violation.get("check", ""))
		var detail := str(violation.get("detail", ""))
		var card_name := str(violation.get("card_name", "unknown"))
		var definition_id := str(violation.get("definition_id", ""))
		var match_idx := int(violation.get("match", 0))
		var turn := int(violation.get("turn", 0))

		var report := {
			"screen": "match",
			"element_type": "card",
			"element_context": "%s (auditor match %d, turn %d)" % [card_name, match_idx + 1, turn],
			"comment": "[AUDITOR:%s] %s" % [check, detail],
			"snapshot": violation.get("snapshot", {}),
		}

		ErrorReportWriter.write_report(report)
		print("  Written report for: %s" % detail)


func _get_cost_locks(match_state: Dictionary) -> Dictionary:
	var locks := {}
	for player in match_state.get("players", []):
		var pid := str(player.get("player_id", ""))
		locks[pid] = player.get("cost_locks", []).duplicate(true)
	return locks
