class_name DeckStrategy
extends RefCounted

## Per-deck AI strategy guide. Pure data + static helpers.
##
## A strategy is a Dictionary {"rules": [...]} embedded in the deck definition
## JSON. Rules express soft preferences that bias the policy's action scoring;
## a per-rule "strict" flag makes the bias near-absolute (only lethal-detected
## actions can override).
##
## See memory/project_per_deck_ai_strategy.md for the agreed design.

const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")

# ── Rule types ──
const RULE_PLAY_WHEN := "play_when"
const RULE_COMBO := "combo"
const RULE_MULLIGAN := "mulligan"
const RULE_ATTACK_TARGET := "attack_target_priority"

const RULE_TYPES := [
	RULE_PLAY_WHEN,
	RULE_COMBO,
	RULE_MULLIGAN,
	RULE_ATTACK_TARGET,
]

# ── Mulligan directions ──
const MULL_KEEP := "keep"
const MULL_TOSS := "toss"

# ── Attack target priorities ──
const ATTACK_FACE := "face"
const ATTACK_WEAKEST := "weakest"
const ATTACK_HIGHEST_POWER := "highest_power"
const ATTACK_AVOID_GUARDS := "avoid_guards"

const ATTACK_TARGET_VALUES := [
	ATTACK_FACE,
	ATTACK_WEAKEST,
	ATTACK_HIGHEST_POWER,
	ATTACK_AVOID_GUARDS,
]

# ── Condition predicates (Tier 2 vocabulary) ──
const PRED_MAX_MAGICKA := "max_magicka"
const PRED_CURRENT_MAGICKA := "current_magicka"
const PRED_RUNES_REMAINING := "runes_remaining"
const PRED_LIFE := "life"
const PRED_HAND_SIZE := "hand_size"
const PRED_ENEMY_LIFE := "enemy_life"
const PRED_ENEMY_RUNES := "enemy_runes_remaining"
const PRED_ENEMY_HAS_CREATURE_WITH_POWER := "enemy_has_creature_with_power"
const PRED_ENEMY_CREATURE_COUNT := "enemy_creature_count"
const PRED_ENEMY_HAS_KEYWORD := "enemy_has_keyword"

const NUMERIC_PREDICATES := [
	PRED_MAX_MAGICKA,
	PRED_CURRENT_MAGICKA,
	PRED_RUNES_REMAINING,
	PRED_LIFE,
	PRED_HAND_SIZE,
	PRED_ENEMY_LIFE,
	PRED_ENEMY_RUNES,
	PRED_ENEMY_HAS_CREATURE_WITH_POWER,
	PRED_ENEMY_CREATURE_COUNT,
]

const KEYWORD_PREDICATES := [PRED_ENEMY_HAS_KEYWORD]

const OP_GTE := ">="
const OP_LTE := "<="

# ── Bonus magnitudes ──
# Soft bonus is meaningful but routinely overridable by clearly-better actions.
# Strict bonus is large enough that only lethal-detected actions (LETHAL_BONUS
# = 500000 in HeuristicMatchPolicy) can override it.
const BONUS_SOFT := 8.0
const BONUS_STRICT := 1000.0


# ─────────────────────────── Construction ───────────────────────────

static func empty_strategy() -> Dictionary:
	return {"rules": []}


static func is_empty(strategy: Dictionary) -> bool:
	if strategy.is_empty():
		return true
	var rules: Array = strategy.get("rules", [])
	return rules.is_empty()


# ─────────────────────────── Validation ───────────────────────────

## Validate a strategy against a deck's card list.
## Returns {"warnings": [{"rule_index": int, "rule_type": String, "dangling_card_ids": Array}],
##          "rules": Array (the original rules unchanged — soft validation)}.
static func validate(strategy: Dictionary, deck_card_ids: Array) -> Dictionary:
	var warnings: Array = []
	var deck_set := {}
	for cid in deck_card_ids:
		deck_set[str(cid)] = true
	var rules: Array = strategy.get("rules", [])
	for index in rules.size():
		var rule: Dictionary = rules[index]
		var refs: Array = _rule_card_refs(rule)
		var dangling: Array = []
		for cid in refs:
			if not deck_set.has(str(cid)):
				dangling.append(str(cid))
		if not dangling.is_empty():
			warnings.append({
				"rule_index": index,
				"rule_type": str(rule.get("type", "")),
				"dangling_card_ids": dangling,
			})
	return {"warnings": warnings, "rules": rules}


static func _rule_card_refs(rule: Dictionary) -> Array:
	var t := str(rule.get("type", ""))
	match t:
		RULE_PLAY_WHEN, RULE_COMBO:
			return rule.get("card_ids", [])
		RULE_MULLIGAN:
			var ids: Array = []
			for entry in rule.get("entries", []):
				ids.append(str(entry.get("card_id", "")))
			return ids
		_:
			return []


# ─────────────────────────── Condition evaluator ───────────────────────────

## Evaluate a Tier-2 condition against the current match state from player_id's
## perspective. Empty/missing conditions evaluate true (rule always fires).
static func evaluate_condition(condition: Dictionary, match_state: Dictionary, player_id: String) -> bool:
	if condition == null or condition.is_empty():
		return true
	var pred := str(condition.get("predicate", ""))
	if pred.is_empty():
		return true
	var op := str(condition.get("op", OP_GTE))
	var threshold: int = int(condition.get("value", 0))
	# Boolean-style predicates
	if pred == PRED_ENEMY_HAS_KEYWORD:
		var kw := str(condition.get("keyword", condition.get("value", "")))
		return _enemy_has_keyword(match_state, player_id, kw)
	if pred == PRED_ENEMY_HAS_CREATURE_WITH_POWER:
		return _enemy_has_creature_with_power_at_least(match_state, player_id, threshold)
	# Numeric predicates
	var actual := _predicate_value(pred, match_state, player_id)
	match op:
		OP_GTE:
			return actual >= threshold
		OP_LTE:
			return actual <= threshold
		_:
			return false


static func _predicate_value(pred: String, ms: Dictionary, player_id: String) -> int:
	var player := _find_player(ms, player_id)
	var opponent := _find_opponent(ms, player_id)
	match pred:
		PRED_MAX_MAGICKA:
			return int(player.get("max_magicka", 0))
		PRED_CURRENT_MAGICKA:
			return int(player.get("current_magicka", 0)) + int(player.get("temporary_magicka", 0))
		PRED_RUNES_REMAINING:
			return _rune_count(player)
		PRED_LIFE:
			return int(player.get("health", 0))
		PRED_HAND_SIZE:
			var hand: Array = player.get("hand", [])
			return hand.size()
		PRED_ENEMY_LIFE:
			return int(opponent.get("health", 0))
		PRED_ENEMY_RUNES:
			return _rune_count(opponent)
		PRED_ENEMY_CREATURE_COUNT:
			return _creature_count(ms, str(opponent.get("player_id", "")))
		_:
			return 0


# ─────────────────────────── Score adjustment (per action) ───────────────────────────

## Compute the strategy-derived score adjustment for a single candidate action.
## Returns {"adjustment": float, "attribution": Array of {"rule_type", "delta", "note"}}.
##
## `after_state` is currently unused by all v1 rules (kept for API forward
## compatibility — pass an empty dict if you don't have it).
static func compute_score_adjustment(strategy: Dictionary,
		before_state: Dictionary,
		after_state: Dictionary,
		action: Dictionary,
		player_id: String) -> Dictionary:
	if is_empty(strategy):
		return {"adjustment": 0.0, "attribution": []}
	var rules: Array = strategy.get("rules", [])
	var played_def_id := _action_played_definition_id(action, before_state, player_id)
	var kind := str(action.get("kind", ""))
	var adjustment := 0.0
	var attribution: Array = []
	for rule in rules:
		if typeof(rule) != TYPE_DICTIONARY:
			continue
		var rule_type := str(rule.get("type", ""))
		var strict := bool(rule.get("strict", false))
		var bonus := BONUS_STRICT if strict else BONUS_SOFT
		var contribution := 0.0
		var note := ""
		match rule_type:
			RULE_PLAY_WHEN:
				contribution = _adjust_play_when(rule, played_def_id, kind, before_state, player_id, bonus)
				note = "play-when"
			RULE_COMBO:
				contribution = _adjust_combo(rule, played_def_id, kind, before_state, after_state, player_id, bonus)
				note = "combo"
			RULE_ATTACK_TARGET:
				# Attack target priority is intentionally a softer bias — it's a
				# tiebreaker between attack targets, not a "must do" commitment.
				contribution = _adjust_attack_target(rule, kind, action, before_state, player_id, BONUS_SOFT)
				note = "attack-priority"
		if contribution != 0.0:
			adjustment += contribution
			attribution.append({"rule_type": rule_type, "delta": contribution, "note": note})
	return {"adjustment": adjustment, "attribution": attribution}


# ── Play-when: condition false ⇒ penalize playing the listed card now. ──
static func _adjust_play_when(rule: Dictionary, played_def_id: String, kind: String,
		state: Dictionary, player_id: String, bonus: float) -> float:
	if not _is_play_action(kind):
		return 0.0
	if played_def_id.is_empty():
		return 0.0
	var card_ids: Array = rule.get("card_ids", [])
	if not _array_has(card_ids, played_def_id):
		return 0.0
	var condition: Dictionary = rule.get("condition", {})
	if evaluate_condition(condition, state, player_id):
		return 0.0
	return -bonus


# ── Combo: encourage in-order plays, penalize out-of-order plays ──
static func _adjust_combo(rule: Dictionary, played_def_id: String, kind: String,
		before_state: Dictionary, after_state: Dictionary, player_id: String, bonus: float) -> float:
	if played_def_id.is_empty():
		return 0.0
	var sequence: Array = rule.get("card_ids", [])
	if sequence.is_empty():
		return 0.0
	var index := -1
	for i in sequence.size():
		if str(sequence[i]) == played_def_id:
			index = i
			break
	if index < 0:
		return 0.0  # Played card isn't part of this combo.
	# Steps 0..k are "complete" if their card_id appears anywhere in the player's
	# board or graveyard before this action.
	var played_set := _completed_combo_steps(sequence, before_state, player_id)
	# "Next due" step = lowest unplayed step.
	var next_due := -1
	for i in sequence.size():
		if not played_set.has(str(sequence[i])):
			next_due = i
			break
	if next_due < 0:
		# All combo steps already complete — don't bias further.
		return 0.0
	if index == next_due:
		# Playing the next due step → reward.
		return bonus
	if index > next_due:
		# Playing a later step before the earlier one is on board → penalize.
		return -bonus
	# index < next_due means we're re-playing a step that was already complete
	# (e.g. a creature that died and came back). Treat as neutral.
	return 0.0


static func _completed_combo_steps(sequence: Array, state: Dictionary, player_id: String) -> Dictionary:
	var seen := {}
	# Cards on the player's side of any lane.
	for lane in state.get("lanes", []):
		var slots: Dictionary = lane.get("player_slots", {})
		for card in slots.get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				seen[str(card.get("definition_id", ""))] = true
	# Cards in the player's graveyard (action cards go here after play).
	var player := _find_player(state, player_id)
	for card in player.get("graveyard", []):
		if typeof(card) == TYPE_DICTIONARY:
			seen[str(card.get("definition_id", ""))] = true
	# Limit to the combo sequence — we only care about combo cards.
	var result := {}
	for cid in sequence:
		if seen.has(str(cid)):
			result[str(cid)] = true
	return result


# ── Attack target priority ──
static func _adjust_attack_target(rule: Dictionary, kind: String, action: Dictionary,
		state: Dictionary, player_id: String, bonus: float) -> float:
	if kind != MatchActionEnumerator.KIND_ATTACK:
		return 0.0
	var priority := str(rule.get("value", ""))
	var target: Dictionary = action.get("target", {})
	var target_kind := str(target.get("kind", ""))
	match priority:
		ATTACK_FACE:
			if target_kind == "player":
				return bonus
			return -bonus * 0.5
		ATTACK_WEAKEST:
			if target_kind != "creature":
				return 0.0
			return _attack_extreme_bonus(target, state, player_id, bonus, true)
		ATTACK_HIGHEST_POWER:
			if target_kind != "creature":
				return 0.0
			return _attack_extreme_bonus(target, state, player_id, bonus, false)
		ATTACK_AVOID_GUARDS:
			if target_kind != "creature":
				return 0.0
			var card := _find_creature_card(state, str(target.get("instance_id", "")))
			if card.is_empty():
				return 0.0
			if EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_GUARD):
				return -bonus
			return 0.0
		_:
			return 0.0


static func _attack_extreme_bonus(target: Dictionary, state: Dictionary, player_id: String,
		bonus: float, want_lowest: bool) -> float:
	var target_id := str(target.get("instance_id", ""))
	var opponent_id := _opponent_id(state, player_id)
	if opponent_id.is_empty():
		return 0.0
	# Find target power and the extreme power among enemy creatures.
	var target_power := -1
	var extreme_power := -1 if want_lowest else -1
	var any_creature := false
	for lane in state.get("lanes", []):
		for c in lane.get("player_slots", {}).get(opponent_id, []):
			if typeof(c) != TYPE_DICTIONARY:
				continue
			if str(c.get("card_type", "")) != "creature":
				continue
			var p := EvergreenRules.get_power(c)
			if str(c.get("instance_id", "")) == target_id:
				target_power = p
			if not any_creature:
				extreme_power = p
				any_creature = true
			else:
				if want_lowest:
					extreme_power = mini(extreme_power, p)
				else:
					extreme_power = maxi(extreme_power, p)
	if not any_creature or target_power < 0:
		return 0.0
	if target_power == extreme_power:
		return bonus
	return -bonus * 0.25


# ─────────────────────────── ISMCTS bias helper ───────────────────────────

## Compute a strategy-only score for use as a softmax weight in ISMCTS rollouts
## and expansion. Cheaper than compute_score_adjustment because it doesn't
## return attribution.
static func bias_score(strategy: Dictionary, state: Dictionary, action: Dictionary, player_id: String) -> float:
	if is_empty(strategy):
		return 0.0
	var result := compute_score_adjustment(strategy, state, {}, action, player_id)
	return float(result.get("adjustment", 0.0))


# ─────────────────────────── Mulligan integration ───────────────────────────

## Apply mulligan rules to a base discard list. Returns the adjusted discard
## list. "Keep" overrides cost-based discard; "toss" overrides keep.
static func apply_mulligan_rules(strategy: Dictionary, hand: Array, base_discards: Array) -> Array:
	var rules: Array = strategy.get("rules", []) if not is_empty(strategy) else []
	var directives := {}  # card_id → "keep" / "toss"
	for rule in rules:
		if str(rule.get("type", "")) != RULE_MULLIGAN:
			continue
		for entry in rule.get("entries", []):
			var cid := str(entry.get("card_id", ""))
			var dir := str(entry.get("direction", ""))
			if cid.is_empty() or dir.is_empty():
				continue
			directives[cid] = dir
	if directives.is_empty():
		return base_discards
	var discards := base_discards.duplicate()
	for card in hand:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var def_id := str(card.get("definition_id", ""))
		var inst_id := str(card.get("instance_id", ""))
		var directive := str(directives.get(def_id, ""))
		if directive == MULL_KEEP:
			discards.erase(inst_id)
		elif directive == MULL_TOSS:
			if not discards.has(inst_id):
				discards.append(inst_id)
	return discards


# ─────────────────────────── Helpers ───────────────────────────

## Look up the definition_id of the card a play-action would put into play.
## Returns "" for non-play actions or unknown source instances.
static func _action_played_definition_id(action: Dictionary, state: Dictionary, player_id: String) -> String:
	var kind := str(action.get("kind", ""))
	if not _is_play_action(kind):
		return ""
	var inst_id := str(action.get("source_instance_id", ""))
	if inst_id.is_empty():
		return ""
	var player := _find_player(state, player_id)
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == inst_id:
			return str(card.get("definition_id", ""))
	return ""


static func _is_play_action(kind: String) -> bool:
	match kind:
		MatchActionEnumerator.KIND_SUMMON_CREATURE, \
		MatchActionEnumerator.KIND_PLAY_ACTION, \
		MatchActionEnumerator.KIND_PLAY_SUPPORT, \
		MatchActionEnumerator.KIND_PLAY_SUPPORT_SACRIFICE, \
		MatchActionEnumerator.KIND_PLAY_ITEM:
			return true
		_:
			return false


static func _find_player(state: Dictionary, player_id: String) -> Dictionary:
	for player in state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) == player_id:
			return player
	return {}


static func _find_opponent(state: Dictionary, player_id: String) -> Dictionary:
	for player in state.get("players", []):
		if typeof(player) == TYPE_DICTIONARY and str(player.get("player_id", "")) != player_id:
			return player
	return {}


static func _opponent_id(state: Dictionary, player_id: String) -> String:
	var opp := _find_opponent(state, player_id)
	return str(opp.get("player_id", ""))


static func _rune_count(player: Dictionary) -> int:
	if player.has("rune_count"):
		return int(player.get("rune_count", 0))
	if player.has("runes"):
		return int(player.get("runes", 0))
	var thresholds: Array = player.get("rune_thresholds", [])
	return thresholds.size()


static func _creature_count(state: Dictionary, owner_player_id: String) -> int:
	var count := 0
	for lane in state.get("lanes", []):
		for c in lane.get("player_slots", {}).get(owner_player_id, []):
			if typeof(c) == TYPE_DICTIONARY and str(c.get("card_type", "")) == "creature":
				count += 1
	return count


static func _enemy_has_creature_with_power_at_least(state: Dictionary, viewer_player_id: String, threshold: int) -> bool:
	var opp_id := _opponent_id(state, viewer_player_id)
	if opp_id.is_empty():
		return false
	for lane in state.get("lanes", []):
		for c in lane.get("player_slots", {}).get(opp_id, []):
			if typeof(c) == TYPE_DICTIONARY and str(c.get("card_type", "")) == "creature":
				if EvergreenRules.get_power(c) >= threshold:
					return true
	return false


static func _enemy_has_keyword(state: Dictionary, viewer_player_id: String, keyword: String) -> bool:
	if keyword.is_empty():
		return false
	var opp_id := _opponent_id(state, viewer_player_id)
	if opp_id.is_empty():
		return false
	for lane in state.get("lanes", []):
		for c in lane.get("player_slots", {}).get(opp_id, []):
			if typeof(c) == TYPE_DICTIONARY and EvergreenRules.has_keyword(c, keyword):
				return true
	return false


static func _find_creature_card(state: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for lane in state.get("lanes", []):
		for slots in lane.get("player_slots", {}).values():
			for c in slots:
				if typeof(c) == TYPE_DICTIONARY and str(c.get("instance_id", "")) == instance_id:
					return c
	return {}


static func _array_has(arr: Array, value: String) -> bool:
	for v in arr:
		if str(v) == value:
			return true
	return false
