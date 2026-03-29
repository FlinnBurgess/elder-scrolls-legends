class_name AIPlayProfile
extends RefCounted

## Builds a weight-options dictionary that shapes AI decision-making based on
## deck archetype and opponent quality.
##
## Design rationale:
## - Three base profiles (aggro, midrange, control) define how the AI values
##   face damage vs board control vs card advantage. The midrange profile matches
##   the original hardcoded constants, so passing no options preserves legacy
##   behaviour exactly.
## - aggro_score (from DeckArchetypeDetector) interpolates smoothly between
##   profiles rather than snapping between three discrete modes. A score of -0.7
##   produces a playstyle 70% aggro / 30% midrange.
## - Quality (0.0–1.0) controls decision precision: lookahead depth, score noise,
##   and action selectivity. Low quality AI plays faster and sloppier; high quality
##   AI plans ahead and makes tight decisions.
## - All keys in the returned dictionary have matching defaults in
##   HeuristicMatchPolicy._merged_options, so the system is fully backward
##   compatible — omitting any key falls back to the midrange constant.

# ── Base profiles ──
# Each profile is a dictionary of weight keys used by HeuristicMatchPolicy and
# MatchStateEvaluator. The midrange values match the original hardcoded constants
# exactly, ensuring backward compatibility when no profile is applied.

# Aggro: prioritises face damage and tempo over board control. Willing to trade
# creatures for damage and values charge/shadow lane pressure. Less concerned
# about own health or card advantage.
const AGGRO := {
	"face_damage_bonus": 0.80,
	"shadow_lane_bonus": 0.85,
	"creature_killed_bonus": 1.8,
	"own_creature_lost_penalty": 1.5,
	"guard_removed_bonus": 2.2,
	"incoming_threat_weight": 2.5,
	"health_weight": 2.0,
	"min_action_gain": 0.4,
	"hand_weight": 0.6,
	"opponent_hand_weight": 0.3,
	"summon_power_weight": 0.55,
	"summon_health_weight": 0.20,
	"support_base_value": 0.8,
	"rune_weight": 0.8,
	"threat_reduction_weight": 1.5,
}

# Midrange: the balanced baseline. These values are identical to the original
# hardcoded constants in heuristic_match_policy.gd and match_state_evaluator.gd,
# so the AI behaves exactly as before when no archetype is detected.
const MIDRANGE := {
	"face_damage_bonus": 0.25,
	"shadow_lane_bonus": 0.55,
	"creature_killed_bonus": 2.3,
	"own_creature_lost_penalty": 1.9,
	"guard_removed_bonus": 1.7,
	"incoming_threat_weight": 3.5,
	"health_weight": 2.5,
	"min_action_gain": 0.6,
	"hand_weight": 0.8,
	"opponent_hand_weight": 0.45,
	"summon_power_weight": 0.4,
	"summon_health_weight": 0.25,
	"support_base_value": 1.1,
	"rune_weight": 1.25,
	"threat_reduction_weight": 2.2,
}

# Control: prioritises board control, card advantage, and health preservation.
# Trades aggressively to clear threats, values guards and supports, and is
# very selective about which actions to take.
const CONTROL := {
	"face_damage_bonus": 0.15,
	"shadow_lane_bonus": 0.30,
	"creature_killed_bonus": 2.8,
	"own_creature_lost_penalty": 2.3,
	"guard_removed_bonus": 1.4,
	"incoming_threat_weight": 4.0,
	"health_weight": 3.0,
	"min_action_gain": 0.75,
	"hand_weight": 1.1,
	"opponent_hand_weight": 0.6,
	"summon_power_weight": 0.3,
	"summon_health_weight": 0.35,
	"support_base_value": 1.5,
	"rune_weight": 1.6,
	"threat_reduction_weight": 2.8,
}


# Survive puzzle AI: hyper-aggressive, zero noise, focused on clearing guards
# and dealing maximum face damage. Willing to trade creatures freely.
const SURVIVE_PUZZLE := {
	"face_damage_bonus": 1.2,
	"shadow_lane_bonus": 0.85,
	"creature_killed_bonus": 2.5,
	"own_creature_lost_penalty": 0.8,
	"guard_removed_bonus": 3.5,
	"incoming_threat_weight": 1.0,
	"health_weight": 1.0,
	"min_action_gain": 0.3,
	"hand_weight": 0.3,
	"opponent_hand_weight": 0.1,
	"summon_power_weight": 0.55,
	"summon_health_weight": 0.15,
	"support_base_value": 0.5,
	"rune_weight": 0.4,
	"threat_reduction_weight": 1.0,
	"score_noise": 0.0,
	"lookahead_depth": 1,
	"top_candidate_lookahead": 3,
	"lookahead_discount": 0.85,
}


static func build_survive_puzzle_options() -> Dictionary:
	return SURVIVE_PUZZLE.duplicate()


## Build the full options dictionary for HeuristicMatchPolicy.choose_action().
##
## aggro_score: -1.0 (pure aggro) to +1.0 (pure control), from DeckArchetypeDetector.
## quality: 0.0 (weakest play) to 1.0 (optimal play), from ArenaEloManager + win streak.
static func build_options(aggro_score: float, quality: float) -> Dictionary:
	var profile := _interpolate_profile(aggro_score)

	# Quality scaling: affects how precisely the AI executes its playstyle.
	# Low quality = noisy decisions with shallow lookahead.
	# High quality = clean decisions with deep lookahead.

	# Score noise: at quality 0.0, up to +/-4.0 random noise on each candidate's
	# score makes the AI frequently pick suboptimal plays. At quality 1.0, no noise.
	profile["score_noise"] = (1.0 - quality) * 4.0

	# Lookahead depth: low quality AI doesn't look ahead at all (depth 0).
	# At quality 0.3+ it starts considering follow-up plays.
	if quality < 0.3:
		profile["lookahead_depth"] = 0
	else:
		profile["lookahead_depth"] = 1

	# Top candidates to evaluate with lookahead: more at higher quality.
	profile["top_candidate_lookahead"] = 1 + int(quality * 2.0)

	# Lookahead discount: how much future value is weighted relative to immediate.
	profile["lookahead_discount"] = 0.5 + quality * 0.35

	# Selectivity: min_action_gain threshold is scaled by quality so low-quality
	# AI takes marginal plays while high-quality AI is more selective.
	profile["min_action_gain"] = profile["min_action_gain"] * (0.5 + quality * 0.5)

	return profile


## Interpolate between the three base profiles based on aggro_score.
##
## For aggro_score < 0: blend between AGGRO and MIDRANGE.
## For aggro_score > 0: blend between MIDRANGE and CONTROL.
## At aggro_score = 0: pure MIDRANGE (original behaviour).
static func _interpolate_profile(aggro_score: float) -> Dictionary:
	var result := {}
	if aggro_score < 0.0:
		# Negative score → blend aggro ↔ midrange.
		# At -1.0: 100% aggro. At 0.0: 100% midrange.
		var t := absf(aggro_score)
		for key in MIDRANGE:
			result[key] = lerpf(float(MIDRANGE[key]), float(AGGRO[key]), t)
	else:
		# Positive score → blend midrange ↔ control.
		# At 0.0: 100% midrange. At +1.0: 100% control.
		var t := aggro_score
		for key in MIDRANGE:
			result[key] = lerpf(float(MIDRANGE[key]), float(CONTROL[key]), t)
	return result
