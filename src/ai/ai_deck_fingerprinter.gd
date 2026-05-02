class_name AIDeckFingerprinter
extends RefCounted

## Bayesian posterior over the player's saved decks. Updated as the AI
## observes cards being played.
##
## Belief shape: {posterior: Dictionary[deck_name → float]}. Posterior values
## sum to ~1.0; an empty posterior means "no registered decks" (random-deck
## bypass or first-ever match) and the policy falls back to v1 sampling.
##
## P(observed_card | deck D) is approximated using D's *remembered set* with
## Laplace smoothing — we cannot read the deck's actual contents (would
## reintroduce cheating), so we use the AI's own memory as a proxy for what's
## plausible in D. This means a brand-new card the AI has never seen will get
## the small smoothing prior across all decks: small but non-zero, so the
## posterior never collapses to NaN.
##
## Universe is the catalog size, used by smoothing to keep
## P(unseen_card | D) sensibly tiny rather than zero.

const CardCatalog = preload("res://src/deck/card_catalog.gd")

const LAPLACE_ALPHA := 0.5
const MIN_POSTERIOR_FLOOR := 1e-12


static func init(memory_by_deck: Dictionary) -> Dictionary:
	# memory_by_deck: {deck_name → Array[def_id]} (already filtered against
	# current contents by the caller).
	var posterior: Dictionary = {}
	for deck_name in memory_by_deck.keys():
		var name_str := str(deck_name)
		if name_str.is_empty():
			continue
		var remembered: Array = memory_by_deck[deck_name]
		if typeof(remembered) != TYPE_ARRAY or remembered.is_empty():
			continue
		posterior[name_str] = 1.0
	if posterior.is_empty():
		return {"posterior": {}, "memory_by_deck": memory_by_deck.duplicate(true), "universe_size": _universe_size()}
	# Normalize uniform prior.
	var n := float(posterior.size())
	for key in posterior.keys():
		posterior[key] = 1.0 / n
	return {
		"posterior": posterior,
		"memory_by_deck": memory_by_deck.duplicate(true),
		"universe_size": _universe_size(),
	}


static func update(belief: Dictionary, observed_def_id: String) -> Dictionary:
	var posterior: Dictionary = belief.get("posterior", {})
	if posterior.is_empty():
		return belief
	var memory_by_deck: Dictionary = belief.get("memory_by_deck", {})
	var universe_size := int(belief.get("universe_size", 1))
	if universe_size <= 0:
		universe_size = 1
	var def_id := str(observed_def_id)
	if def_id.is_empty():
		return belief
	var updated: Dictionary = {}
	var total := 0.0
	for deck_name in posterior.keys():
		var remembered: Array = memory_by_deck.get(deck_name, [])
		var has_card := remembered.has(def_id)
		# P(card | D) ≈ (count_in_remembered + α) / (|remembered| + α * |universe|)
		# count_in_remembered is 0 or 1 here since remembered is a set (no
		# duplicates) — we don't track copy counts in memory.
		var num := (1.0 if has_card else 0.0) + LAPLACE_ALPHA
		var den := float(remembered.size()) + LAPLACE_ALPHA * float(universe_size)
		var likelihood := num / den
		var new_p := float(posterior[deck_name]) * likelihood
		if new_p < MIN_POSTERIOR_FLOOR:
			new_p = MIN_POSTERIOR_FLOOR
		updated[deck_name] = new_p
		total += new_p
	if total <= 0.0:
		return belief
	for key in updated.keys():
		updated[key] = float(updated[key]) / total
	belief["posterior"] = updated
	return belief


static func sample_deck(belief: Dictionary, rng: RandomNumberGenerator) -> String:
	var posterior: Dictionary = belief.get("posterior", {})
	if posterior.is_empty():
		return ""
	var total := 0.0
	for key in posterior.keys():
		total += float(posterior[key])
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	var cumulative := 0.0
	for key in posterior.keys():
		cumulative += float(posterior[key])
		if roll <= cumulative:
			return str(key)
	return str(posterior.keys()[posterior.size() - 1])


static func top_belief(belief: Dictionary) -> Dictionary:
	var posterior: Dictionary = belief.get("posterior", {})
	var best_name := ""
	var best_p := -1.0
	for key in posterior.keys():
		var p := float(posterior[key])
		if p > best_p:
			best_p = p
			best_name = str(key)
	return {"deck_name": best_name, "p": maxf(best_p, 0.0)}


static func _universe_size() -> int:
	var catalog := CardCatalog.load_default()
	var cards: Array = catalog.get("cards", [])
	if cards.is_empty():
		return 1
	return cards.size()
