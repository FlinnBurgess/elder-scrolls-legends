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
const DeckStrategy = preload("res://src/ai/deck_strategy.gd")
const LethalGuard = preload("res://src/ai/lethal_guard.gd")
const AIDecisionLogger = preload("res://src/ai/ai_decision_logger.gd")

const DEFAULT_BUDGET_MS := 800
const DEFAULT_MAX_ITERATIONS := 2000
const DEFAULT_RESAMPLE_EVERY := 16
const DEFAULT_ROLLOUT_PLIES := 12
const UCB_C := 1.4
const TERMINAL_REWARD := 1.0
# Convergence short-circuit: every CONVERGENCE_CHECK_EVERY iterations, if the
# most-visited root child has at least CONVERGENCE_DOMINANCE_RATIO times the
# visits of the runner-up AND has been visited at least CONVERGENCE_MIN_VISITS
# times, exit early. Saves budget on obvious decisions where one move clearly
# dominates after a small fraction of the budget.
const CONVERGENCE_CHECK_EVERY := 64
const CONVERGENCE_DOMINANCE_RATIO := 5.0
const CONVERGENCE_MIN_VISITS := 50
# Surfaces with this few actions or fewer skip MCTS entirely and use the
# heuristic policy. Tuned empirically from live-match telemetry: at typical
# per-iteration cost (~1-2s due to full deck hydration), MCTS gets 1 visit
# per child below ~8 actions and adds no value over the heuristic.
const SMALL_SURFACE_THRESHOLD := 8
# Minimum useful iteration count per legal action before MCTS adds value.
# After the first MCTS iteration we extrapolate the per-iter cost; if the
# remaining budget can't afford this many visits per child on average, we
# bail and let the heuristic decide. Catches "slow live state" cases that
# the static threshold misses (e.g. surface=12 with 1.5s/iter).
const MIN_USEFUL_ITERS_PER_ACTION := 5
# Softmax temperature for strategy-biased action sampling. With BONUS_SOFT=8
# this gives ~e^1=2.7x weighting on soft-favored actions; with BONUS_STRICT=1000
# (clamped to ±50) it gives ~e^6.25=520x — strict-favored actions dominate.
const STRATEGY_BIAS_TEMPERATURE := 8.0
const STRATEGY_BIAS_CLAMP := 50.0


static func choose_mulligan(match_state: Dictionary, player_id: String, options: Dictionary = {}) -> Array:
	return HeuristicMatchPolicy.choose_mulligan(match_state, player_id, options)


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
	# Telemetry: every return path stamps fields into `trace` and logs once
	# via `_log_decision_and_return` so the user can inspect ai_decisions.log
	# to see where time goes.
	var t_total := Time.get_ticks_msec()
	var trace: Dictionary = {
		"turn": int(match_state.get("turn_number", 0)),
		"surface": 0,
		"path": "",
		"lethal_ms": 0,
		"heuristic_ms": 0,
		"mcts_ms": 0,
		"iters": 0,
	}
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, player_id)
	var ai_pid := str(surface.get("decision_player_id", ""))
	trace["player"] = ai_pid
	if ai_pid.is_empty() or not str(surface.get("blocked_reason", "")).is_empty():
		trace["path"] = "invalid"
		return _log_decision_and_return(_invalid(surface, str(surface.get("blocked_reason", "No legal actor could be determined."))), trace, t_total)
	var actions: Array = surface.get("actions", [])
	trace["surface"] = actions.size()
	if actions.is_empty():
		trace["path"] = "no_legal_actions"
		return _log_decision_and_return(_invalid(surface, "No legal actions were available."), trace, t_total)
	if actions.size() == 1:
		trace["path"] = "only_legal_action"
		return _log_decision_and_return(_wrap_single(surface, actions[0], ai_pid), trace, t_total)

	# Observe BEFORE search so the determinizer can constrain pools.
	AIObservationTracker.observe(match_state, ai_pid)
	var observed := AIObservationTracker.get_observed(match_state, ai_pid)
	# Build the deck-identity belief. Random-deck bypass: empty
	# `human_deck_name` ⇒ skip fingerprinting entirely (empty belief), so the
	# determinizer falls back to v1 generic-pool sampling.
	var belief := _build_belief(options, observed)
	trace["fingerprinting"] = not belief.is_empty()

	# Lethal guard: if the AI has lethal this turn, take it; if the opponent
	# has visible lethal next turn, restrict MCTS to defensive candidates.
	# Both checks read only public board state — fully fair-play.
	var restricted_root_keys: Dictionary = {}
	if not bool(options.get("disable_lethal_guard", false)):
		var t_lethal := Time.get_ticks_msec()
		var guard := LethalGuard.evaluate(match_state, ai_pid, surface)
		trace["lethal_ms"] = Time.get_ticks_msec() - t_lethal
		if guard.has("forced_action"):
			trace["path"] = "lethal_offensive"
			return _log_decision_and_return(_wrap_single(surface, guard["forced_action"], ai_pid, str(guard.get("reason", "lethal_guard"))), trace, t_total)
		if guard.has("restricted_actions"):
			actions = guard["restricted_actions"]
			trace["restricted_to"] = actions.size()
			if actions.size() == 1:
				trace["path"] = "lethal_defensive_single"
				return _log_decision_and_return(_wrap_single(surface, actions[0], ai_pid, str(guard.get("reason", "lethal_guard"))), trace, t_total)
			for restricted_action in actions:
				restricted_root_keys[_action_key(restricted_action)] = true

	# Small-surface short-circuit: with very few legal actions (e.g. "attack
	# face vs attack creature vs end turn"), MCTS has no branching to exploit
	# and runs out the full budget producing essentially heuristic-quality
	# answers anyway. Skip directly to the heuristic for an instant decision.
	if actions.size() <= SMALL_SURFACE_THRESHOLD:
		trace["path"] = "small_surface_delegate"
		var t_h := Time.get_ticks_msec()
		var delegated := _delegate_to_heuristic(match_state, ai_pid, options, "ismcts_small_surface_delegate")
		trace["heuristic_ms"] = Time.get_ticks_msec() - t_h
		return _log_decision_and_return(delegated, trace, t_total)

	var budget_ms := int(options.get("ismcts_budget_ms", DEFAULT_BUDGET_MS))
	var max_iters := int(options.get("ismcts_max_iters", DEFAULT_MAX_ITERATIONS))
	var resample_every := int(options.get("ismcts_resample_every", DEFAULT_RESAMPLE_EVERY))
	var rollout_plies := int(options.get("ismcts_rollout_plies", DEFAULT_ROLLOUT_PLIES))
	trace["budget_ms"] = budget_ms

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var strategy: Dictionary = options.get("strategy", {})
	var root := _new_node(ai_pid)
	var deadline := Time.get_ticks_msec() + budget_ms
	var iter := 0
	var world: Dictionary = {}
	var t_mcts := Time.get_ticks_msec()
	var converged_early := false

	# `ismcts_interrupt` is an optional Dictionary the caller can poke from
	# another thread (set "cancelled" = true) to short-circuit a long search,
	# e.g. when the player exits the screen during a 10s think.
	var interrupt: Dictionary = options.get("ismcts_interrupt", {})

	# Probe-and-bail: after the very first iteration, estimate whether the
	# remaining budget can afford enough iterations for MCTS to add value
	# (≥ MIN_USEFUL_ITERS_PER_ACTION visits per root child). If not, abort
	# and let the post-search heuristic fallback handle it. Live matches
	# with hydrated 50-card decks can hit ~1-2s per iteration, which makes
	# MCTS useless even at surface=6.
	var probe_bailed := false

	while iter < max_iters:
		if Time.get_ticks_msec() >= deadline:
			break
		if not interrupt.is_empty() and bool(interrupt.get("cancelled", false)):
			trace["interrupted"] = true
			break
		if iter % resample_every == 0:
			world = ISMCTSDeterminizer.determinize(match_state, ai_pid, observed, rng, belief)
		var sim := MatchActionEnumerator._lightweight_clone(world)
		_run_iteration(root, sim, ai_pid, rng, rollout_plies, strategy, restricted_root_keys)
		iter += 1
		if iter == 1:
			var probe_ms := Time.get_ticks_msec() - t_mcts
			trace["probe_ms"] = probe_ms
			var remaining_ms := deadline - Time.get_ticks_msec()
			var projected_iters := int(remaining_ms / maxi(probe_ms, 1)) + 1
			var needed_iters := MIN_USEFUL_ITERS_PER_ACTION * actions.size()
			if projected_iters < needed_iters:
				probe_bailed = true
				trace["probe_bailed"] = true
				trace["projected_iters"] = projected_iters
				break
		# Early exit when the search has obviously converged on one root move.
		if iter > 0 and iter % CONVERGENCE_CHECK_EVERY == 0 and _has_converged(root):
			converged_early = true
			break
	trace["iters"] = iter
	trace["mcts_ms"] = Time.get_ticks_msec() - t_mcts
	trace["converged_early"] = converged_early

	var best_child_key := _select_most_visited(root)
	if best_child_key.is_empty():
		trace["path"] = "mcts_no_children"
		return _log_decision_and_return(_wrap_single(surface, actions[0], ai_pid), trace, t_total)
	# Visit-count snapshot for diagnostics.
	var visit_summary := _root_visit_summary(root)
	if visit_summary.has("best_visits"):
		trace["best_visits"] = visit_summary["best_visits"]
		trace["second_visits"] = visit_summary["second_visits"]
	# If MCTS didn't converge cleanly (no child dominates by visits), the
	# rollout signal is too noisy to trust over the heuristic — fall back to
	# the heuristic's pick for the final answer. This catches the "all
	# children have similar visit counts" case where the chosen action would
	# otherwise be effectively random.
	# probe_bailed always forces the heuristic fallback — convergence on a
	# single-visit single child is technically "converged" by the dominance
	# rule, but the value is too noisy to trust over the heuristic.
	if probe_bailed or not _has_converged(root):
		trace["path"] = "mcts_probe_bail" if probe_bailed else "mcts_unconverged_fallback"
		var fallback_reason := "ismcts_probe_bail_heuristic_fallback" if probe_bailed else "ismcts_unconverged_heuristic_fallback"
		var t_h2 := Time.get_ticks_msec()
		var fallback := _delegate_to_heuristic(match_state, ai_pid, options, fallback_reason)
		trace["heuristic_ms"] = Time.get_ticks_msec() - t_h2
		if bool(fallback.get("is_valid", false)):
			fallback["decision_reason"] = "%s | iters=%d" % [str(fallback.get("decision_reason", "")), iter]
			return _log_decision_and_return(fallback, trace, t_total)
	trace["path"] = "mcts_converged"
	var best_child: Dictionary = root["children"][best_child_key]
	return _log_decision_and_return(_wrap_choice(surface, best_child, root, ai_pid, iter), trace, t_total)


# Emit a final telemetry line and return the choice. Centralised here so
# every return path is logged consistently.
static func _log_decision_and_return(choice: Dictionary, trace: Dictionary, t_total: int) -> Dictionary:
	trace["elapsed_ms"] = Time.get_ticks_msec() - t_total
	trace["chose_kind"] = str(choice.get("chosen_action", {}).get("kind", ""))
	trace["chose"] = str(choice.get("action_summary", ""))
	trace["reason"] = str(choice.get("reason", ""))
	AIDecisionLogger.log_decision(trace)
	return choice


# Snapshot the top two root children's visit counts for diagnostics.
static func _root_visit_summary(root: Dictionary) -> Dictionary:
	var first := -1
	var second := -1
	for key in root.get("children", {}).keys():
		var v := int(root["children"][key].get("visits", 0))
		if v > first:
			second = first
			first = v
		elif v > second:
			second = v
	if first < 0:
		return {}
	return {"best_visits": first, "second_visits": maxi(second, 0)}


# Delegate a decision to the heuristic policy and tag the result so the UI /
# logs can identify which short-circuit path was taken (small surface, post-
# search fallback, etc).
static func _delegate_to_heuristic(match_state: Dictionary, ai_pid: String, options: Dictionary, reason: String) -> Dictionary:
	var heuristic_choice = HeuristicMatchPolicy.choose_action(match_state, ai_pid, options)
	if not bool(heuristic_choice.get("is_valid", false)):
		return heuristic_choice
	heuristic_choice["reason"] = reason
	heuristic_choice["behavior_label"] = reason
	heuristic_choice["decision_reason"] = "ismcts:%s | %s" % [reason, str(heuristic_choice.get("decision_reason", ""))]
	return heuristic_choice


# ── Iteration: select → expand → rollout → backprop ──

static func _run_iteration(root: Dictionary, sim: Dictionary, ai_pid: String, rng: RandomNumberGenerator, rollout_plies: int, strategy: Dictionary = {}, restricted_root_keys: Dictionary = {}) -> void:
	var path: Array = [root]
	var node: Dictionary = root
	# 1. Selection: walk down through fully-expanded nodes legal in this world.
	while not _is_terminal(sim):
		var legal_for_world: Array = _legal_actions_for(sim)
		# At the root, when the lethal guard restricted the search to defensive
		# candidates, filter to that subset so MCTS doesn't waste iterations on
		# moves that don't address the visible threat.
		if node == root and not restricted_root_keys.is_empty():
			var filtered_root_actions: Array = []
			for action in legal_for_world:
				if restricted_root_keys.has(_action_key(action)):
					filtered_root_actions.append(action)
			if not filtered_root_actions.is_empty():
				legal_for_world = filtered_root_actions
		if legal_for_world.is_empty():
			break
		var untried_in_world := _untried_in_world(node, legal_for_world)
		if not untried_in_world.is_empty():
			# Expand: bias pick toward strategy-favored actions (only when this
			# node's decision belongs to the AI we're optimising for).
			var picked: Dictionary = _strategy_biased_pick(untried_in_world, sim, ai_pid, strategy, rng) if _node_player(node) == ai_pid else untried_in_world[rng.randi_range(0, untried_in_world.size() - 1)]
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

	# 2. Rollout — random play (biased by strategy on AI plies) to terminal or ply cap.
	var reward := _rollout(sim, ai_pid, rng, rollout_plies, strategy)

	# 3. Backprop: skip root (no incoming decision).
	for i in range(1, path.size()):
		var n: Dictionary = path[i]
		n["visits"] = int(n.get("visits", 0)) + 1
		var reward_sign := 1.0 if str(n.get("decided_by", "")) == ai_pid else -1.0
		n["value"] = float(n.get("value", 0.0)) + reward * reward_sign
	root["visits"] = int(root.get("visits", 0)) + 1


## Rollout policy: biased random that deprioritises `end_turn` while other
## actions remain. Pure-random rollouts drown small "+health delta" signals
## in noise (e.g. free face attacks look indistinguishable from passing).
## A full heuristic policy gives clean signal but costs ~50ms per ply —
## with a 12-ply rollout that's only 1-3 rollouts per second, far too few
## for MCTS to explore meaningfully.
##
## The biased-random compromise: most plies pick uniformly from non-end-turn
## actions if any exist, only falling back to end_turn when it's the only
## option (or with small probability `END_TURN_RANDOM_PROB` so the rollout
## eventually terminates rather than looping forever on long turns).
##
## In-place execution: `sim` enters this function as a private clone owned
## by the iteration. We mutate it directly via `execute_silent` rather than
## cloning at every ply — saves 11+ deep duplicates per rollout. Selection
## still uses `clone_and_execute` because its retry-on-illegal logic needs
## the clone's safety; rollout breaks on partial-fail and accepts whatever
## state results, so in-place is safe here.
static func _rollout(sim: Dictionary, ai_pid: String, rng: RandomNumberGenerator, max_plies: int, strategy: Dictionary = {}) -> float:
	var plies := 0
	while plies < max_plies and not _is_terminal(sim):
		var legal := _legal_actions_for(sim)
		if legal.is_empty():
			break
		var pick: Dictionary
		if not strategy.is_empty() and _current_pid(sim) == ai_pid:
			pick = _strategy_biased_pick(legal, sim, ai_pid, strategy, rng)
		else:
			pick = _biased_random_pick(legal, rng)
		var result := MatchActionExecutor.execute_silent(sim, pick)
		if not bool(result.get("is_valid", false)):
			break
		plies += 1
	return _reward(sim, ai_pid)


# Probability the rollout takes end_turn even when other actions exist.
# Without this, rollouts could loop forever on long action surfaces.
const END_TURN_RANDOM_PROB := 0.15


## Pick uniformly from non-end-turn actions when any exist; otherwise fall
## back to whatever's available (typically end_turn). With small probability
## still take end_turn even when other moves exist, so the rollout makes
## forward progress on turns with many marginally-useful actions.
static func _biased_random_pick(legal: Array, rng: RandomNumberGenerator) -> Dictionary:
	if legal.size() == 1:
		return legal[0]
	var non_end: Array = []
	var end_turn: Dictionary = {}
	for action in legal:
		if str(action.get("kind", "")) == MatchActionEnumerator.KIND_END_TURN:
			end_turn = action
		else:
			non_end.append(action)
	if non_end.is_empty():
		return end_turn if not end_turn.is_empty() else legal[0]
	if not end_turn.is_empty() and rng.randf() < END_TURN_RANDOM_PROB:
		return end_turn
	return non_end[rng.randi_range(0, non_end.size() - 1)]


## Sample one action from `actions` weighted by exp(strategy_score / TEMP). When
## strategy is empty or all scores are zero this falls back to uniform random.
static func _strategy_biased_pick(actions: Array, state: Dictionary, ai_pid: String, strategy: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if strategy.is_empty() or actions.size() <= 1:
		return actions[rng.randi_range(0, actions.size() - 1)]
	var weights: Array = []
	var max_score := -INF
	var raw_scores: Array = []
	for action in actions:
		var s := DeckStrategy.bias_score(strategy, state, action, ai_pid)
		# Clamp to keep exp() safe.
		if s > STRATEGY_BIAS_CLAMP:
			s = STRATEGY_BIAS_CLAMP
		elif s < -STRATEGY_BIAS_CLAMP:
			s = -STRATEGY_BIAS_CLAMP
		raw_scores.append(s)
		if s > max_score:
			max_score = s
	# Subtract max for numerical stability.
	var total := 0.0
	for s in raw_scores:
		var w := exp((float(s) - max_score) / STRATEGY_BIAS_TEMPERATURE)
		weights.append(w)
		total += w
	if total <= 0.0:
		return actions[rng.randi_range(0, actions.size() - 1)]
	var r := rng.randf() * total
	var acc := 0.0
	for i in actions.size():
		acc += float(weights[i])
		if r <= acc:
			return actions[i]
	return actions[actions.size() - 1]


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


## True when one root child has dominantly more visits than any other —
## additional iterations are unlikely to change the chosen action.
static func _has_converged(root: Dictionary) -> bool:
	var children: Dictionary = root.get("children", {})
	if children.size() < 2:
		# 0 children → nothing to do; 1 child → already trivially converged.
		return children.size() == 1
	var first := -1
	var second := -1
	for key in children.keys():
		var child: Dictionary = children[key]
		var visits := int(child.get("visits", 0))
		if visits > first:
			second = first
			first = visits
		elif visits > second:
			second = visits
	if first < CONVERGENCE_MIN_VISITS:
		return false
	if second <= 0:
		return true
	return float(first) >= CONVERGENCE_DOMINANCE_RATIO * float(second)


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


static func _wrap_single(surface: Dictionary, action: Dictionary, ai_pid: String, reason: String = "only_legal_action") -> Dictionary:
	return {
		"is_valid": true,
		"surface": surface,
		"decision_player_id": ai_pid,
		"chosen_action": action.duplicate(true),
		"chosen_score": 0.0,
		"projected_gain": 0.0,
		"reason": reason,
		"behavior_label": reason,
		"decision_reason": "ismcts:%s" % reason,
		"action_summary": _action_summary(action),
		"decision_summary": "ismcts %s" % reason,
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
