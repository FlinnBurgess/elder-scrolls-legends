class_name ISMCTSMatchPolicy
extends RefCounted

## Information Set Monte Carlo Tree Search policy.
##
## Same `choose_action(match_state, player_id, options)` contract as
## HeuristicMatchPolicy so the UI dispatcher can swap engines without caring
## which one ran. Mulligan delegates to the heuristic for v1.
##
## Algorithm:
## 1. Observe — scan publicly revealed opponent cards (zones outside hand+deck).
## 2. Determinize — clone match_state and replace opponent's hidden hand+deck
##    with a sampled plausible set (resampled every K iterations).
## 3. Search — UCB1 selection / random expansion / random rollout / negamax-
##    style backprop, gated by a wall-clock budget.
## 4. Return the most-visited root child's action, wrapped in the dict shape
##    the UI expects.
##
## Tree nodes are dicts (no helper class) keyed within the parent by
## `action.id` so the same action across re-determinizations binds to the same
## node. Actions illegal in the current determinization are skipped during
## selection.

const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const MatchStateEvaluator = preload("res://src/ai/match_state_evaluator.gd")
const ISMCTSDeterminizer = preload("res://src/ai/ismcts_determinizer.gd")
const AIObservationTracker = preload("res://src/ai/ai_observation_tracker.gd")
const HeuristicMatchPolicy = preload("res://src/ai/heuristic_match_policy.gd")
const AIDeckMemory = preload("res://src/ai/ai_deck_memory.gd")
const AIDeckFingerprinter = preload("res://src/ai/ai_deck_fingerprinter.gd")
const DeckPersistence = preload("res://src/deck/deck_persistence.gd")

const DEFAULT_BUDGET_MS := 800
const DEFAULT_MAX_ITERATIONS := 2000
const DEFAULT_RESAMPLE_EVERY := 16
const DEFAULT_ROLLOUT_PLIES := 12
const UCB_C := 1.4
const TERMINAL_REWARD := 1.0


static func choose_mulligan(match_state: Dictionary, player_id: String) -> Array:
	return HeuristicMatchPolicy.choose_mulligan(match_state, player_id)


# Build a Bayesian belief over the player's saved decks. Returns an empty dict
# (skip-fingerprinting marker) when human_deck_name is empty (random-deck
# bypass) or when there's no usable memory to start a posterior from.
static func _build_belief(options: Dictionary, observed: Dictionary) -> Dictionary:
	var human_deck_name := str(options.get("human_deck_name", ""))
	if human_deck_name.is_empty():
		return {}
	# Pull a remembered set per known deck, filtered against each deck's
	# current contents so post-edit memory stays consistent.
	var memory_by_deck: Dictionary = {}
	for deck_name in AIDeckMemory.list_known_decks():
		var current := _deck_contents_counts(deck_name)
		if current.is_empty():
			continue
		var filtered := AIDeckMemory.get_remembered_filtered(deck_name, current)
		if not filtered.is_empty():
			memory_by_deck[deck_name] = filtered
	if memory_by_deck.is_empty():
		return {}
	var belief := AIDeckFingerprinter.init(memory_by_deck)
	# Fold this match's observations into the posterior.
	var def_counts: Dictionary = observed.get("def_counts", {})
	for def_id in def_counts.keys():
		var copies := int(def_counts[def_id])
		for _i in range(copies):
			belief = AIDeckFingerprinter.update(belief, str(def_id))
	return belief


static func _deck_contents_counts(deck_name: String) -> Dictionary:
	var definition := DeckPersistence.load_deck(deck_name)
	if typeof(definition) != TYPE_DICTIONARY or definition.is_empty():
		return {}
	var cards: Array = definition.get("cards", [])
	if typeof(cards) != TYPE_ARRAY:
		return {}
	var counts: Dictionary = {}
	for entry in cards:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var def_id := str(entry.get("card_id", ""))
		if def_id.is_empty():
			continue
		counts[def_id] = int(counts.get(def_id, 0)) + int(entry.get("quantity", 1))
	return counts


static func choose_action(match_state: Dictionary, player_id: String = "", options: Dictionary = {}) -> Dictionary:
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, player_id)
	var ai_pid := str(surface.get("decision_player_id", ""))
	if ai_pid.is_empty() or not str(surface.get("blocked_reason", "")).is_empty():
		return _invalid(surface, str(surface.get("blocked_reason", "No legal actor could be determined.")))
	var actions: Array = surface.get("actions", [])
	if actions.is_empty():
		return _invalid(surface, "No legal actions were available.")
	if actions.size() == 1:
		return _wrap_single(surface, actions[0], ai_pid)

	# Observe BEFORE search so the determinizer can constrain pools.
	AIObservationTracker.observe(match_state, ai_pid)
	var observed := AIObservationTracker.get_observed(match_state, ai_pid)
	# Build the deck-identity belief. Random-deck bypass: empty
	# `human_deck_name` ⇒ skip fingerprinting entirely (empty belief), so the
	# determinizer falls back to v1 generic-pool sampling.
	var belief := _build_belief(options, observed)

	var budget_ms := int(options.get("ismcts_budget_ms", DEFAULT_BUDGET_MS))
	var max_iters := int(options.get("ismcts_max_iters", DEFAULT_MAX_ITERATIONS))
	var resample_every := int(options.get("ismcts_resample_every", DEFAULT_RESAMPLE_EVERY))
	var rollout_plies := int(options.get("ismcts_rollout_plies", DEFAULT_ROLLOUT_PLIES))

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var root := _new_node(ai_pid)
	var deadline := Time.get_ticks_msec() + budget_ms
	var iter := 0
	var world: Dictionary = {}

	while iter < max_iters:
		if Time.get_ticks_msec() >= deadline:
			break
		if iter % resample_every == 0:
			world = ISMCTSDeterminizer.determinize(match_state, ai_pid, observed, rng, belief)
		var sim := MatchActionEnumerator._lightweight_clone(world)
		_run_iteration(root, sim, ai_pid, rng, rollout_plies)
		iter += 1

	var best_child_key := _select_most_visited(root)
	if best_child_key.is_empty():
		# Tree barely explored; fall back to first legal action.
		return _wrap_single(surface, actions[0], ai_pid)
	var best_child: Dictionary = root["children"][best_child_key]
	return _wrap_choice(surface, best_child, root, ai_pid, iter)


# ── Iteration: select → expand → rollout → backprop ──

static func _run_iteration(root: Dictionary, sim: Dictionary, ai_pid: String, rng: RandomNumberGenerator, rollout_plies: int) -> void:
	var path: Array = [root]
	var node: Dictionary = root
	# 1. Selection: walk down through fully-expanded nodes legal in this world.
	while not _is_terminal(sim):
		var legal_for_world: Array = _legal_actions_for(sim)
		if legal_for_world.is_empty():
			break
		var untried_in_world := _untried_in_world(node, legal_for_world)
		if not untried_in_world.is_empty():
			# Expand
			var picked: Dictionary = untried_in_world[rng.randi_range(0, untried_in_world.size() - 1)]
			var exec_result := MatchActionExecutor.clone_and_execute(sim, picked)
			if not bool(exec_result.get("is_valid", false)):
				# Mark this action illegal here; treat as a tried child with bad value.
				_record_illegal_child(node, picked)
				continue
			sim = exec_result.get("match_state", sim)
			var decided_by := _node_player(node)
			var expanded := _new_child(node, picked, decided_by, _current_pid(sim))
			path.append(expanded)
			node = expanded
			break
		# Fully expanded — UCB select among children legal in this world.
		var selected_key := _ucb_select(node, legal_for_world)
		if selected_key.is_empty():
			break
		var selected: Dictionary = node["children"][selected_key]
		var step := MatchActionExecutor.clone_and_execute(sim, selected["action"])
		if not bool(step.get("is_valid", false)):
			_mark_illegal(selected)
			break
		sim = step.get("match_state", sim)
		path.append(selected)
		node = selected

	# 2. Rollout — random play to terminal or ply cap.
	var reward := _rollout(sim, ai_pid, rng, rollout_plies)

	# 3. Backprop: skip root (no incoming decision).
	for i in range(1, path.size()):
		var n: Dictionary = path[i]
		n["visits"] = int(n.get("visits", 0)) + 1
		var reward_sign := 1.0 if str(n.get("decided_by", "")) == ai_pid else -1.0
		n["value"] = float(n.get("value", 0.0)) + reward * reward_sign
	root["visits"] = int(root.get("visits", 0)) + 1


static func _rollout(sim: Dictionary, ai_pid: String, rng: RandomNumberGenerator, max_plies: int) -> float:
	var plies := 0
	while plies < max_plies and not _is_terminal(sim):
		var legal := _legal_actions_for(sim)
		if legal.is_empty():
			break
		var pick: Dictionary = legal[rng.randi_range(0, legal.size() - 1)]
		var result := MatchActionExecutor.clone_and_execute(sim, pick)
		if not bool(result.get("is_valid", false)):
			break
		sim = result.get("match_state", sim)
		plies += 1
	return _reward(sim, ai_pid)


static func _reward(sim: Dictionary, ai_pid: String) -> float:
	var winner := str(sim.get("winner_player_id", ""))
	if not winner.is_empty():
		return TERMINAL_REWARD if winner == ai_pid else -TERMINAL_REWARD
	# Heuristic eval squashed into [-1, 1]. evaluate_state returns differences in
	# ~tens, so divide by a soft scale before tanh.
	var eval := MatchStateEvaluator.evaluate_state(sim, ai_pid, {})
	return _tanh(eval / 25.0)


static func _tanh(x: float) -> float:
	if x > 20.0:
		return 1.0
	if x < -20.0:
		return -1.0
	var e2x := exp(2.0 * x)
	return (e2x - 1.0) / (e2x + 1.0)


# ── Tree-node helpers ──

static func _new_node(player_to_move: String) -> Dictionary:
	return {
		"action": {},
		"action_key": "",
		"decided_by": "",
		"player_to_move": player_to_move,
		"visits": 0,
		"value": 0.0,
		"children": {},  # key (action.id) → child node
		"illegal_in_worlds": 0,
	}


static func _new_child(parent: Dictionary, action: Dictionary, decided_by: String, next_player: String) -> Dictionary:
	var key := _action_key(action)
	var child := {
		"action": action.duplicate(true),
		"action_key": key,
		"decided_by": decided_by,
		"player_to_move": next_player,
		"visits": 0,
		"value": 0.0,
		"children": {},
		"illegal_in_worlds": 0,
	}
	var children: Dictionary = parent.get("children", {})
	children[key] = child
	parent["children"] = children
	return child


static func _action_key(action: Dictionary) -> String:
	var id_field := str(action.get("id", ""))
	if not id_field.is_empty():
		return id_field
	# Fallback: synthesise a stable key from kind + source + parameters.
	var kind := str(action.get("kind", ""))
	var src := str(action.get("source_instance_id", ""))
	var params: Dictionary = action.get("parameters", {})
	var param_keys := params.keys()
	param_keys.sort()
	var parts: Array = [kind, src]
	for k in param_keys:
		parts.append("%s=%s" % [str(k), str(params[k])])
	return "|".join(parts)


static func _untried_in_world(node: Dictionary, legal_actions: Array) -> Array:
	var children: Dictionary = node.get("children", {})
	var untried: Array = []
	for action in legal_actions:
		var key := _action_key(action)
		if not children.has(key):
			untried.append(action)
	return untried


static func _ucb_select(node: Dictionary, legal_actions: Array) -> String:
	var children: Dictionary = node.get("children", {})
	var parent_visits := int(node.get("visits", 0))
	if parent_visits < 1:
		parent_visits = 1
	var ln_n := log(float(parent_visits))
	var best_key := ""
	var best_score := -INF
	for action in legal_actions:
		var key := _action_key(action)
		if not children.has(key):
			continue
		var child: Dictionary = children[key]
		var visits := int(child.get("visits", 0))
		if visits == 0:
			# Should not happen — untried path picks these — but be safe.
			return key
		var mean := float(child.get("value", 0.0)) / float(visits)
		var explore := UCB_C * sqrt(ln_n / float(visits))
		var score := mean + explore
		if score > best_score:
			best_score = score
			best_key = key
	return best_key


static func _record_illegal_child(node: Dictionary, action: Dictionary) -> void:
	# Cache an "illegal in some worlds" placeholder so we don't keep re-trying
	# the same action that the executor rejects.
	var key := _action_key(action)
	var children: Dictionary = node.get("children", {})
	if children.has(key):
		_mark_illegal(children[key])
		return
	var stub := {
		"action": action.duplicate(true),
		"action_key": key,
		"decided_by": _node_player(node),
		"player_to_move": _node_player(node),
		"visits": 1,
		"value": -TERMINAL_REWARD,
		"children": {},
		"illegal_in_worlds": 1,
	}
	children[key] = stub
	node["children"] = children


static func _mark_illegal(child: Dictionary) -> void:
	child["illegal_in_worlds"] = int(child.get("illegal_in_worlds", 0)) + 1


static func _node_player(node: Dictionary) -> String:
	return str(node.get("player_to_move", ""))


static func _select_most_visited(root: Dictionary) -> String:
	var children: Dictionary = root.get("children", {})
	var best_key := ""
	var best_visits := -1
	for key in children.keys():
		var child: Dictionary = children[key]
		var visits := int(child.get("visits", 0))
		if visits > best_visits:
			best_visits = visits
			best_key = key
	return best_key


# ── State helpers ──

static func _is_terminal(state: Dictionary) -> bool:
	return not str(state.get("winner_player_id", "")).is_empty()


static func _legal_actions_for(state: Dictionary) -> Array:
	var surface := MatchActionEnumerator.enumerate_legal_actions(state, "")
	if not str(surface.get("blocked_reason", "")).is_empty():
		return []
	return surface.get("actions", [])


static func _current_pid(state: Dictionary) -> String:
	var surface := MatchActionEnumerator.enumerate_legal_actions(state, "")
	return str(surface.get("decision_player_id", state.get("active_player_id", "")))


# ── Result wrapping (mirror HeuristicMatchPolicy.choose_action shape) ──

static func _invalid(surface: Dictionary, reason: String) -> Dictionary:
	return {
		"is_valid": false,
		"surface": surface,
		"reason": reason,
		"chosen_action": {},
	}


static func _wrap_single(surface: Dictionary, action: Dictionary, ai_pid: String) -> Dictionary:
	return {
		"is_valid": true,
		"surface": surface,
		"decision_player_id": ai_pid,
		"chosen_action": action.duplicate(true),
		"chosen_score": 0.0,
		"projected_gain": 0.0,
		"reason": "only_legal_action",
		"behavior_label": "only_legal_action",
		"decision_reason": "ismcts:only_legal_action",
		"action_summary": _action_summary(action),
		"decision_summary": "ismcts only_legal_action",
		"considered_actions": [{"summary": _action_summary(action), "id": _action_key(action), "visits": 1}],
	}


static func _wrap_choice(surface: Dictionary, best_child: Dictionary, root: Dictionary, ai_pid: String, iters: int) -> Dictionary:
	var action: Dictionary = best_child.get("action", {})
	var visits := int(best_child.get("visits", 0))
	var mean_value := 0.0
	if visits > 0:
		mean_value = float(best_child.get("value", 0.0)) / float(visits)
	var considered := _summarise_children(root)
	var summary := "ismcts iters=%d picked=%s visits=%d mean=%.3f" % [iters, _action_summary(action), visits, mean_value]
	return {
		"is_valid": true,
		"surface": surface,
		"decision_player_id": ai_pid,
		"chosen_action": action.duplicate(true),
		"chosen_score": mean_value,
		"projected_gain": mean_value,
		"reason": "ismcts_most_visited",
		"behavior_label": "ismcts_most_visited",
		"decision_reason": summary,
		"action_summary": _action_summary(action),
		"decision_summary": summary,
		"considered_actions": considered,
		"ismcts_iterations": iters,
	}


static func _summarise_children(root: Dictionary) -> Array:
	var rows: Array = []
	for key in root.get("children", {}).keys():
		var child: Dictionary = root["children"][key]
		var visits := int(child.get("visits", 0))
		var mean := 0.0
		if visits > 0:
			mean = float(child.get("value", 0.0)) / float(visits)
		rows.append({
			"id": key,
			"summary": _action_summary(child.get("action", {})),
			"visits": visits,
			"mean_value": mean,
		})
	rows.sort_custom(func(a, b): return int(a.get("visits", 0)) > int(b.get("visits", 0)))
	return rows


static func _action_summary(action: Dictionary) -> String:
	if action.is_empty():
		return "<empty>"
	var kind := str(action.get("kind", ""))
	var src := str(action.get("source_instance_id", ""))
	if src.is_empty():
		return kind
	return "%s:%s" % [kind, src]
