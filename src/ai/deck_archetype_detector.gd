class_name DeckArchetypeDetector
extends RefCounted

## Classifies a deck on the aggro-control spectrum based on card composition.
##
## The detector analyses six signals from the deck's cards — mana curve, creature
## density, keyword distribution, and spell ratio — to produce a score from -1.0
## (pure aggro) to +1.0 (pure control). This score drives weight interpolation in
## AIPlayProfile so the AI's playstyle matches the deck it was dealt.
##
## Design rationale:
## - A continuous score (rather than just a label) lets weight interpolation produce
##   smooth behaviour variation rather than three discrete modes.
## - Thresholds are calibrated against the Elder Scrolls Legends card pool where
##   average creature cost sits around 3.0–3.5 and typical arena decks are 60–75%
##   creatures.
## - Each signal is normalised to roughly [-1, +1] and weighted so no single signal
##   dominates. The weights below were tuned for the current card pool; they can be
##   adjusted as more sets are added.

# ── Thresholds and weights for each classification signal ──

# Average mana cost: aggro decks cluster around 2.5, control around 4.0+.
const AVG_COST_AGGRO := 2.8
const AVG_COST_CONTROL := 3.8
const AVG_COST_WEIGHT := 0.25

# Creature ratio: aggro runs many cheap creatures, control leans on spells/supports.
const CREATURE_RATIO_AGGRO := 0.72
const CREATURE_RATIO_CONTROL := 0.55
const CREATURE_RATIO_WEIGHT := 0.20

# Charge density: the hallmark aggro keyword — immediate face pressure.
const CHARGE_HIGH := 4
const CHARGE_LOW := 1
const CHARGE_WEIGHT := 0.15

# Guard density: the hallmark defensive keyword — stalls aggro.
const GUARD_HIGH := 5
const GUARD_LOW := 2
const GUARD_WEIGHT := 0.15

# Non-creature ratio (actions + supports): control decks run more removal/draw.
const SPELL_RATIO_AGGRO := 0.15
const SPELL_RATIO_CONTROL := 0.35
const SPELL_RATIO_WEIGHT := 0.10

# Low-cost card ratio (0-2 mana): aggro floods the board early.
const LOW_COST_RATIO_AGGRO := 0.40
const LOW_COST_RATIO_CONTROL := 0.25
const LOW_COST_RATIO_WEIGHT := 0.15

# Labels derived from the final score.
const LABEL_AGGRO := "aggro"
const LABEL_MIDRANGE := "midrange"
const LABEL_CONTROL := "control"
const AGGRO_THRESHOLD := -0.33
const CONTROL_THRESHOLD := 0.33


## Analyse a deck and return its archetype classification.
##
## Returns { "archetype": "aggro"|"midrange"|"control", "aggro_score": float }
## where aggro_score ranges from -1.0 (pure aggro) to +1.0 (pure control).
## The flat card ID array is the same format used by start_match_with_decks.
static func detect(deck_card_ids: Array, card_database: Dictionary) -> Dictionary:
	var stats := _gather_deck_stats(deck_card_ids, card_database)
	if stats.total_cards == 0:
		return {"archetype": LABEL_MIDRANGE, "aggro_score": 0.0}

	var score := 0.0

	# Signal 1: Average mana cost — higher cost → more control-oriented.
	var avg_cost: float = stats.total_cost / float(stats.total_cards)
	score += _score_signal(avg_cost, AVG_COST_AGGRO, AVG_COST_CONTROL) * AVG_COST_WEIGHT

	# Signal 2: Creature ratio — more creatures → more aggro-oriented.
	# Note: inverted because high creature ratio = aggro (negative score).
	var creature_ratio: float = float(stats.creature_count) / float(stats.total_cards)
	score -= _score_signal(creature_ratio, CREATURE_RATIO_CONTROL, CREATURE_RATIO_AGGRO) * CREATURE_RATIO_WEIGHT

	# Signal 3: Charge keyword density — more charge → more aggro.
	var charge_signal := _score_signal(float(stats.charge_count), float(CHARGE_LOW), float(CHARGE_HIGH))
	score -= charge_signal * CHARGE_WEIGHT

	# Signal 4: Guard keyword density — more guards → more control.
	var guard_signal := _score_signal(float(stats.guard_count), float(GUARD_LOW), float(GUARD_HIGH))
	score += guard_signal * GUARD_WEIGHT

	# Signal 5: Non-creature (spell/support) ratio — more spells → more control.
	var spell_ratio: float = float(stats.action_count + stats.support_count) / float(stats.total_cards)
	score += _score_signal(spell_ratio, SPELL_RATIO_AGGRO, SPELL_RATIO_CONTROL) * SPELL_RATIO_WEIGHT

	# Signal 6: Low-cost cards (0-2 mana) ratio — more cheap cards → more aggro.
	var low_cost_ratio: float = float(stats.low_cost_count) / float(stats.total_cards)
	score -= _score_signal(low_cost_ratio, LOW_COST_RATIO_CONTROL, LOW_COST_RATIO_AGGRO) * LOW_COST_RATIO_WEIGHT

	score = clampf(score, -1.0, 1.0)
	var label := LABEL_MIDRANGE
	if score < AGGRO_THRESHOLD:
		label = LABEL_AGGRO
	elif score > CONTROL_THRESHOLD:
		label = LABEL_CONTROL

	return {"archetype": label, "aggro_score": score}


## Normalise a raw value to [-1, +1] between a low and high threshold.
## Returns -1 at or below low, +1 at or above high, linear between.
static func _score_signal(value: float, low: float, high: float) -> float:
	if absf(high - low) < 0.001:
		return 0.0
	return clampf((value - low) / (high - low) * 2.0 - 1.0, -1.0, 1.0)


## Collect aggregate statistics from the deck for classification.
static func _gather_deck_stats(deck_card_ids: Array, card_database: Dictionary) -> Dictionary:
	var stats := {
		"total_cards": 0,
		"total_cost": 0.0,
		"creature_count": 0,
		"action_count": 0,
		"support_count": 0,
		"item_count": 0,
		"charge_count": 0,
		"guard_count": 0,
		"low_cost_count": 0,  # cards costing 0-2
	}

	for card_id in deck_card_ids:
		var card: Dictionary = card_database.get(str(card_id), {})
		if card.is_empty():
			continue
		stats.total_cards += 1
		var cost: int = int(card.get("cost", 0))
		stats.total_cost += float(cost)
		if cost <= 2:
			stats.low_cost_count += 1

		match str(card.get("card_type", "")):
			"creature":
				stats.creature_count += 1
			"action":
				stats.action_count += 1
			"support":
				stats.support_count += 1
			"item":
				stats.item_count += 1

		var keywords: Array = card.get("keywords", [])
		for kw in keywords:
			match str(kw):
				"charge":
					stats.charge_count += 1
				"guard":
					stats.guard_count += 1

	return stats
