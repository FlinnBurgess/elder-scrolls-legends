class_name LethalGuard
extends RefCounted

## Pre-MCTS short-circuit for lethal scenarios.
##
## Two checks, both fully fair-play (no peeking at opponent's hand or deck):
##
## 1. **Offensive lethal**: bounded DFS over the AI's action sequences this
##    turn. If any sequence reduces opponent's `winner_player_id` to the AI,
##    we return the first action of that sequence and skip MCTS entirely.
##
## 2. **Defensive lethal**: arithmetic on the visible board only. We compute
##    how much face damage the opponent can deal next turn given creatures
##    that are already in lanes (their power, AI's guards' effective health),
##    and check whether that exceeds the AI's current health. If yes, we
##    restrict MCTS to actions that meaningfully reduce the threat.
##
## The defensive check is deliberately conservative — it ignores opponent's
## hidden hand entirely. That means the AI may *underestimate* incoming
## damage (and miss a defense it could have made) but never *overestimates*
## by reading hidden info. That's the right asymmetry for a fair AI.

const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")

const OFFENSIVE_DEPTH := 3
const OFFENSIVE_BRANCH_LIMIT := 12
const MIN_THREAT_REDUCTION := 1


## Result shape:
##   {"forced_action": Dictionary}                — take this action immediately, skip MCTS
##   {"restricted_actions": Array[Dictionary]}    — MCTS may only choose among these
##   {}                                            — no guard fired; MCTS runs normally
static func evaluate(match_state: Dictionary, ai_pid: String, surface: Dictionary) -> Dictionary:
	# 1. Offensive: try to find a sequence that kills the opponent.
	var lethal_first := find_offensive_lethal(match_state, ai_pid, OFFENSIVE_DEPTH)
	if not lethal_first.is_empty():
		return {"forced_action": lethal_first, "reason": "offensive_lethal"}
	# 2. Defensive: is the AI in danger from visible incoming damage?
	var ai_player := _find_player(match_state, ai_pid)
	if ai_player.is_empty():
		return {}
	var ai_health := int(ai_player.get("health", 0))
	var threat := compute_visible_threat(match_state, ai_pid)
	if threat < ai_health:
		return {}  # No visible lethal threat — let MCTS run normally.
	var actions: Array = surface.get("actions", [])
	var defensive := find_threat_reducing_actions(match_state, ai_pid, threat, actions)
	if defensive.is_empty():
		return {}  # Nothing helps — let MCTS run rather than force a bad move.
	return {"restricted_actions": defensive, "reason": "defensive_lethal", "threat": threat, "ai_health": ai_health}


# ── Offensive lethal: bounded DFS over AI action sequences ──

static func find_offensive_lethal(match_state: Dictionary, ai_pid: String, depth_remaining: int) -> Dictionary:
	if depth_remaining <= 0:
		return {}
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, ai_pid)
	if str(surface.get("decision_player_id", "")) != ai_pid:
		return {}
	var actions: Array = surface.get("actions", [])
	# Order: damage-dealing actions first; skip end_turn (never lethal).
	var ordered := _order_for_lethal_search(actions)
	var examined := 0
	for action in ordered:
		if examined >= OFFENSIVE_BRANCH_LIMIT:
			break
		examined += 1
		var exec_result := MatchActionExecutor.clone_and_execute(match_state, action)
		if not bool(exec_result.get("is_valid", false)):
			continue
		var next_state: Dictionary = exec_result.get("match_state", {})
		if str(next_state.get("winner_player_id", "")) == ai_pid:
			return action
		# Recurse only if we still have decision priority in the resulting state.
		var sub := find_offensive_lethal(next_state, ai_pid, depth_remaining - 1)
		if not sub.is_empty():
			return action
	return {}


static func _order_for_lethal_search(actions: Array) -> Array:
	var damage_first: Array = []
	var rest: Array = []
	for action in actions:
		var kind := str(action.get("kind", ""))
		if kind == MatchActionEnumerator.KIND_END_TURN:
			continue  # Ending turn never wins on the AI's own turn.
		if kind == MatchActionEnumerator.KIND_ATTACK:
			var target: Dictionary = action.get("parameters", {}).get("target", {})
			if str(target.get("kind", "")) == "player":
				damage_first.append(action)
				continue
		if kind == MatchActionEnumerator.KIND_PLAY_ACTION or kind == MatchActionEnumerator.KIND_PLAY_ITEM:
			damage_first.append(action)
			continue
		rest.append(action)
	return damage_first + rest


# ── Defensive: visible-board threat estimation ──

## Sum of face damage the opponent can deal next turn assuming AI passes,
## counting only what's already visible on the board (creatures in lanes).
## Hidden info is intentionally ignored.
static func compute_visible_threat(match_state: Dictionary, ai_pid: String) -> int:
	var opp_pid := _opponent_pid(match_state, ai_pid)
	if opp_pid.is_empty():
		return 0
	var total_face_damage := 0
	for lane in match_state.get("lanes", []):
		var lane_threat := _lane_face_damage(lane, ai_pid, opp_pid)
		total_face_damage += lane_threat
	return total_face_damage


static func _lane_face_damage(lane: Dictionary, ai_pid: String, opp_pid: String) -> int:
	var opp_slots: Array = lane.get("player_slots", {}).get(opp_pid, [])
	var ai_slots: Array = lane.get("player_slots", {}).get(ai_pid, [])
	# Sum opponent's incoming attack power (any creature with power > 0 can
	# attack next turn — being conservative; shackled creatures may still
	# unshackle by then).
	var attack_power := 0
	for card in opp_slots:
		if typeof(card) != TYPE_DICTIONARY or card.is_empty():
			continue
		var power := EvergreenRules.get_power(card)
		if power <= 0:
			continue
		attack_power += power
	if attack_power <= 0:
		return 0
	# Subtract AI's guards' absorbing capacity (sum of effective health of
	# guard creatures in this lane). Guards force attackers to target them
	# first; once their HP is exceeded, overflow goes to face.
	var guard_buffer := 0
	for card in ai_slots:
		if typeof(card) != TYPE_DICTIONARY or card.is_empty():
			continue
		if not _is_guard(card):
			continue
		var hp := EvergreenRules.get_health(card) - int(card.get("damage_marked", 0))
		if hp > 0:
			guard_buffer += hp
	var face_damage := attack_power - guard_buffer
	return face_damage if face_damage > 0 else 0


static func _is_guard(card: Dictionary) -> bool:
	for source_key in ["keywords", "granted_keywords"]:
		var ks: Array = card.get(source_key, [])
		if typeof(ks) == TYPE_ARRAY and ks.has("guard"):
			return true
	# Cover acts as a one-shot guard.
	var statuses: Array = card.get("status_markers", [])
	if typeof(statuses) == TYPE_ARRAY and statuses.has("cover"):
		return true
	return false


# ── Defensive candidate selection ──

## Returns the subset of `actions` that reduce visible threat by at least
## MIN_THREAT_REDUCTION (or that are end_turn — included so MCTS can still
## decide to bail if no defense actually helps).
static func find_threat_reducing_actions(match_state: Dictionary, ai_pid: String, baseline_threat: int, actions: Array) -> Array:
	var reducers: Array = []
	var has_end_turn := false
	for action in actions:
		if str(action.get("kind", "")) == MatchActionEnumerator.KIND_END_TURN:
			has_end_turn = true
			continue
		var exec_result := MatchActionExecutor.clone_and_execute(match_state, action)
		if not bool(exec_result.get("is_valid", false)):
			continue
		var next_state: Dictionary = exec_result.get("match_state", {})
		# If the action wins the match (corner case — offensive lethal already
		# handled but be safe), include it.
		if str(next_state.get("winner_player_id", "")) == ai_pid:
			reducers.append(action)
			continue
		var new_threat := compute_visible_threat(next_state, ai_pid)
		if baseline_threat - new_threat >= MIN_THREAT_REDUCTION:
			reducers.append(action)
			continue
		# Healing also "reduces threat" — compare AI's health change.
		var ai_player_after := _find_player(next_state, ai_pid)
		var ai_player_before := _find_player(match_state, ai_pid)
		if int(ai_player_after.get("health", 0)) > int(ai_player_before.get("health", 0)):
			reducers.append(action)
	# Always allow ending turn — sometimes there's literally no defense and the
	# AI shouldn't be forced into a useless action.
	if has_end_turn:
		for raw_action in actions:
			if str(raw_action.get("kind", "")) == MatchActionEnumerator.KIND_END_TURN:
				reducers.append(raw_action)
				break
	return reducers


# ── Helpers ──

static func _find_player(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _opponent_pid(match_state: Dictionary, ai_pid: String) -> String:
	for player in match_state.get("players", []):
		var pid := str(player.get("player_id", ""))
		if pid != ai_pid and not pid.is_empty():
			return pid
	return ""
