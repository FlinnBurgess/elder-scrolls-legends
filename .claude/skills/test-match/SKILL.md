---
name: test-match
description: Configure a test match scenario for manual gameplay testing. Use when user wants to test a card, mechanic, keyword, or interaction in-game — e.g. "test veteran", "set up a match with treasure hunt cards", "I want to try Consume". Edits data/test_match_config.gd so the user can press ? on the Match button to launch.
---

# Test Match Setup

Configure `data/test_match_config.gd` to create a targeted test scenario for a specific card, mechanic, or interaction.

## Input

A description of what to test. Examples:
- `"Veteran"` — set up Veteran creatures with weak enemies to attack into
- `"Skooma Underboss"` — test the pilfer_is_slay passive
- `"Treasure Hunt with Aldora the Daring"` — test the full treasure hunt flow
- `"Consume interaction with Imbued creatures"` — test consume + on_consumed triggers

## Workflow

### Step 1 — Identify Cards

Search `src/deck/card_catalog.gd` for cards relevant to the requested mechanic. For each card, extract:
- `card_id` (1st arg to `_seed()`)
- Card name, cost, power, health
- Keywords, rules_text, triggered_abilities families

Pick 5-8 cards for the player's hand covering the mechanic well, plus 3-5 for the deck. Include variety: different costs, different effects, at least one that's ready to test immediately.

### Step 2 — Design the Scenario

Consider what the player needs to test the mechanic:

| Mechanic | Player 1 needs | Player 2 needs |
|----------|----------------|----------------|
| Combat triggers (Veteran, Slay, Pilfer) | Creatures with the keyword + enough magicka | Weak enemies to attack into, no runes |
| Summon effects | Cards in hand + magicka to play them | Targets if the summon needs them |
| Support/Ongoing effects | The support card + creatures to benefit | Normal board state |
| Passive abilities | The passive card in lane + cards it affects | Creatures/actions to test against |
| Cost reduction / Empower | The card + actions or creatures that trigger reduction | Enough health to survive multiple turns |
| Treasure Hunt | Treasure Hunt creature in lane + matching cards in deck | Doesn't matter |
| Consume | Consumer + creatures in discard pile | Normal board |
| Assemble (Factotum) | Factotums already in lane as buff targets + more Factotums in hand to play | Weak enemies, low magicka |

Set these parameters:
- **Player 1 magicka**: High enough to play the test cards (usually 12)
- **Player 2 magicka**: Low (1-3) so AI doesn't overwhelm the board
- **Player 2 runes**: Empty (`[]`) unless testing prophecy/rune interactions
- **Player 2 creatures**: Weak (1/1 Fiery Imps or Nord Firebrands) as punching bags
- **Lane creatures**: Pre-place one key card in lane if it needs to attack or be attacked immediately

### Step 3 — Edit the Config

Edit **only the CONFIGURATION section** of `data/test_match_config.gd` (between the `── CONFIGURATION ──` and `── END CONFIGURATION ──` markers). Do not modify the helper functions below.

The configurable variables are:
```
turn_number, first_player
p1_health, p1_max_magicka, p1_current_magicka, p1_rune_thresholds, p1_has_ring, p1_ring_charges
p1_hand_ids, p1_deck_ids, p1_discard_ids, p1_support_ids, p1_field_creatures, p1_shadow_creatures
p2_health, p2_max_magicka, p2_current_magicka, p2_rune_thresholds, p2_has_ring, p2_ring_charges
p2_hand_ids, p2_deck_ids, p2_discard_ids, p2_field_creatures, p2_shadow_creatures
```

**Card IDs** are the first argument to `_seed()` in `card_catalog.gd` — e.g. `"aw_end_great_moot_squire"`.

**Discard pile** uses `p1_discard_ids` / `p2_discard_ids` — an array of card IDs placed directly into the discard pile at match start. Essential for Consume testing.

**Lane creatures** use `_make_lane_creature(player_id, definition_id, index, overrides)`:
- `index`: unique number (start at 100 to avoid collisions with hand/deck)
- `overrides`: optional dict with `can_attack`, `turns_in_play`, `damage_marked`, `power_bonus`, `health_bonus`, `keywords`, `status_markers`

### Step 4 — Annotate with Comments

Add a comment next to each card ID explaining what it does and why it's in the scenario:
```gdscript
"aw_end_great_moot_squire",  # Cost 1, 1/2, Veteran: +1/+1
```

### Step 5 — Summarize for the User

Tell the user:
1. What's in their hand and why
2. What's already on the board
3. What's in the deck to draw into
4. What's in the discard pile (if populated)
5. What the enemy board looks like
6. Step-by-step instructions for testing (e.g. "Attack Squire into the Imp to trigger Veteran")
7. Remind them: **Launch the game, hover the Match button, press `?`**

## Common Card IDs for Testing

Weak enemies (punching bags):
- `str_fiery_imp` — 1/1 creature, cost 1
- `str_nord_firebrand` — 1/1 Charge, cost 0
- `end_deathless_draugr` — 1/1 Last Gasp: resummon, cost 1

Vanilla bodies:
- `str_whiterun_trooper` — 2/4, cost 2
- `end_fharun_defender` — 1/4 Guard, cost 2
- `end_young_mammoth` — 4/4, cost 4

Card draw:
- `int_elusive_schemer` — 3/1, Summon: Draw a card, cost 4
