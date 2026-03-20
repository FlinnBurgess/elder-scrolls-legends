# AI Difficulty Scaling and Deck Archetype System

## Problem

The AI used a single set of hardcoded weights for all gameplay decisions regardless of difficulty or deck composition. Quality (0.0-1.0) only affected deck drafting, not play. All opponents played identically — favouring shadow lane, undervaluing face damage, and ignoring their deck's natural strengths.

## Solution

Three interconnected systems that make AI behaviour more varied and skill-appropriate:

### 1. Deck Archetype Detection (`deck_archetype_detector.gd`)

Classifies each AI deck on a continuous aggro-control spectrum (-1.0 to +1.0) by analysing six signals from the deck's card composition:

| Signal | What it measures | Weight |
|---|---|---|
| Average mana cost | Curve height | 0.25 |
| Creature ratio | Board vs spell focus | 0.20 |
| Charge density | Burst potential | 0.15 |
| Guard density | Defensive posture | 0.15 |
| Spell/support ratio | Removal/utility density | 0.10 |
| Low-cost card ratio | Early game presence | 0.15 |

The continuous score enables smooth weight interpolation rather than three rigid modes.

### 2. Play Profile System (`ai_play_profile.gd`)

Three base weight profiles define distinct playstyles:

**Aggro** (score < -0.33): Prioritises face damage (0.80 vs midrange 0.25), shadow lane pressure (0.85), and is willing to sacrifice creatures. Lower min action gain means it takes marginal tempo plays rather than passing.

**Midrange** (score -0.33 to +0.33): The original hardcoded weights, preserved exactly. Balanced between board control and face damage.

**Control** (score > +0.33): Prioritises board control (creature killed bonus 2.8), card advantage (hand weight 1.1), and health preservation (3.0). Very selective about actions (min gain 0.75).

Profiles are interpolated linearly based on aggro_score, so a deck at -0.5 gets a 50/50 blend of aggro and midrange weights.

### 3. Quality-Scaled Play Decisions

Quality now affects gameplay, not just drafting:

| Quality | Score Noise | Lookahead | Candidates | Action Selectivity |
|---|---|---|---|---|
| 0.0 | +/-4.0 | none (depth 0) | 1 | very low |
| 0.5 | +/-2.0 | 1-ply | 2 | moderate |
| 1.0 | none | 1-ply | 3 | full |

- **Score noise**: Random perturbation added to candidate scores. At low quality, the AI frequently picks suboptimal plays. Lethal actions are never perturbed.
- **Lookahead**: Below quality 0.3, the AI has no lookahead at all — it only sees the immediate effect of each action.
- **Candidates**: Higher quality considers more follow-up actions during lookahead.
- **Action selectivity**: min_action_gain threshold scales with quality, so low-quality AI takes bad plays while high-quality AI is more selective.

### 4. Win Streak Scaling

Within an arena run, each win adds +0.04 quality (capped at +0.20 from 5 wins). This stacks with the ELO-based difficulty, creating a natural difficulty curve where successful runs face progressively smarter opponents.

## Architecture

### Data Flow

```
ArenaController._on_fight_pressed()
  |-- quality = elo_quality + win_streak_bonus
  |-- ai_deck = draft_ai_deck(..., quality)     // deck quality (existing)
  |-- ai_options = {quality, ai_deck_ids}
  |
  v
MatchScreen.start_match_with_decks(..., ai_options)
  |-- DeckArchetypeDetector.detect(ai_deck_ids, card_db) -> aggro_score
  |-- AIPlayProfile.build_options(aggro_score, quality) -> weight dict
  |-- stored in _ai_options and _match_state["ai_options"] for resume
  |
  v
Each AI turn: HeuristicMatchPolicy.choose_action(state, id, _ai_options)
  |-- _tactical_bonus() reads weights from options
  |-- MatchStateEvaluator.evaluate_state() reads weights from options
  |-- _apply_score_noise() perturbs scores for low quality
```

### Backward Compatibility

All weight keys have midrange defaults matching the original hardcoded constants. Callers that pass no options (tests, non-arena matches) get identical behaviour to before.

### Resume Support

`_ai_options` is stored in `_match_state["ai_options"]` and serialised to JSON automatically via the existing match state save/load system. On resume, the profile is read back without recomputation.

## Files

| File | Role |
|---|---|
| `src/ai/deck_archetype_detector.gd` | NEW - Deck classification |
| `src/ai/ai_play_profile.gd` | NEW - Weight profile interpolation |
| `src/ai/match_state_evaluator.gd` | MODIFIED - Parameterised weights via options dict |
| `src/ai/heuristic_match_policy.gd` | MODIFIED - Reads weights from options, adds score noise |
| `src/ui/arena/arena_controller.gd` | MODIFIED - Win streak bonus, passes ai_options to match screen |
| `src/ui/match_screen.gd` | MODIFIED - Builds profile at match start, passes to AI, persists for resume |

## Design Decisions

### Why a continuous spectrum instead of discrete archetypes?
A deck at the boundary between aggro and midrange should play with a blend of both styles, not snap between two completely different behaviour modes. The continuous aggro_score (-1 to +1) enables smooth interpolation.

### Why seed noise from turn number?
Using `hash(turn * 7919 + ranked.size())` as the RNG seed means the AI is consistently "sloppy" or "sharp" within a single match, but different matches produce different noise patterns. This avoids the AI flip-flopping between good and bad play within turns.

### Why not scale lookahead depth beyond 1?
Lookahead is expensive — each additional ply multiplies the work by the number of legal actions. Depth 2+ would create noticeable delays. Instead, quality varies whether lookahead happens at all (depth 0 vs 1) and how many candidates get the lookahead treatment.

### Why store ai_options in match_state instead of recomputing on resume?
The deck card IDs are available in the match state, so recomputation is possible. However, storing the computed profile avoids needing to re-run archetype detection and profile interpolation, and ensures the resumed AI plays identically to how it played before the interrupt.

### Why +0.04 per win for streak bonus?
At the default 1200 ELO, average opponents start at quality ~0.4-0.6. Five wins at +0.04 each adds +0.20, pushing a mid-range opponent to 0.6-0.8 — noticeable but not overwhelming. The cap at +0.20 prevents a lucky streak from making late matches impossibly hard.
