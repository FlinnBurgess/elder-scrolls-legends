---
name: test-match
description: Configure a test match scenario for manual gameplay testing. Use when user wants to test a card, mechanic, keyword, or interaction in-game — e.g. "test veteran", "set up a match with treasure hunt cards", "I want to try Consume". Creates a JSON config in data/test_match_configs/ so the user can press ? on the Match button to pick and launch it.
---

# Test Match Setup

Create a JSON config file in `data/test_match_configs/` to set up a targeted test scenario for a specific card, mechanic, or interaction.

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
| Invade | Cheap Invade triggers (0-3 cost) + payoffs (Keeper of the Gates, Mankar Camoran) + Great Sigil Stone support. For basic invade testing, don't pre-place gates — they spawn automatically. For **multi-gate or specific-level testing**, pre-place gates manually (see "Pre-placing Oblivion Gates" below). Include varied enemies (1/1s + a Guard with health) to test gate-level damage effects | Weak creatures in both lanes, no runes |
| Special lane types (Dementia, Mania, etc.) | Creatures in the shadow lane (which becomes the special lane) + creatures of varying power/health to test the lane effect trigger conditions. Pre-place creatures so the effect fires immediately. See "Testing Special Lane Types" below | A creature contesting the lane to test both-sides behavior + punching bags in field lane |
| Lane layout / slot capacity | Enough cheap creatures to fill both lanes — test that the capacity cap is enforced and the UI reflects the different sizes. See "Testing Lane Layout Variations" below | Weak creatures spread across both lanes as visual reference |

Set these parameters:
- **Player 1 magicka**: High enough to play the test cards (usually 12)
- **Player 2 magicka**: Low (1-3) so AI doesn't overwhelm the board
- **Player 2 runes**: Standard (`[25, 20, 15, 10, 5]`) unless testing prophecy/rune interactions where you want no runes (`[]`)
- **Player 2 creatures**: Weak (1/1 Fiery Imps or Nord Firebrands) as punching bags
- **Lane creatures**: Pre-place one key card in lane if it needs to attack or be attacked immediately

### Step 3 — Create the JSON Config

Create a JSON file in `data/test_match_configs/` with a descriptive snake_case filename (e.g. `veteran_test.json`, `consume_imbued.json`). The `"name"` and `"description"` fields are required — they appear in the picker UI.

**JSON schema:**
```json
{
  "name": "Human-readable name",
  "description": "Short description shown in the picker UI",
  "board_profile": "standard_versus",
  "turn_number": 1,
  "first_player": "player_1",
  "player_1": {
    "health": 30,
    "max_magicka": 12,
    "current_magicka": 12,
    "rune_thresholds": [25, 20, 15, 10, 5],
    "has_ring": false,
    "ring_charges": 0,
    "hand": ["card_id_1", "card_id_2"],
    "deck": ["card_id_3", "card_id_4"],
    "discard": [],
    "supports": [],
    "field_creatures": [],
    "shadow_creatures": []
  },
  "player_2": {
    "health": 30,
    "max_magicka": 2,
    "current_magicka": 2,
    "rune_thresholds": [25, 20, 15, 10, 5],
    "has_ring": false,
    "ring_charges": 0,
    "hand": ["card_id_1"],
    "deck": ["card_id_2"],
    "discard": [],
    "field_creatures": [],
    "shadow_creatures": []
  }
}
```

**Card IDs** are the first argument to `_seed()` in `card_catalog.gd` — e.g. `"aw_end_great_moot_squire"`.

**Discard pile** uses `discard` — an array of card IDs placed directly into the discard pile at match start. Essential for Consume testing.

**Lane creatures** can be either:
- A string (just the definition_id): `"str_fiery_imp"`
- A dict with overrides: `{ "definition_id": "str_fiery_imp", "can_attack": false, "damage_marked": 2 }`

Available overrides: `can_attack`, `turns_in_play`, `damage_marked`, `power_bonus`, `health_bonus`, `keywords`, `status_markers`.

For arbitrary extra properties (e.g. Oblivion Gates), use `"extras"`:
```json
{ "definition_id": "joo_neu_oblivion_gate", "can_attack": false, "extras": {
    "rules_tags": ["oblivion_gate"],
    "gate_level": 1,
    "cannot_attack": true,
    "status_markers": ["permanent_shackle"],
    "grants_immunity": ["silence"],
    "triggered_abilities": [...]
}}
```

### Testing Special Lane Types (Dementia, Mania, etc.)

Set `"board_profile"` to a test profile that uses the special lane type. The test profile must already exist in `data/legends/registries/lane_registry.json` under `board_profiles`. Example profile:

```json
{
  "id": "dementia_test",
  "display_name": "Dementia Test",
  "lanes": [
    {"lane_id": "field", "slot_capacity": 4},
    {"lane_id": "shadow", "lane_type": "dementia", "slot_capacity": 4}
  ],
  "source_ids": ["workspace_spec"]
}
```

Use `lane_id: "shadow"` so creatures route to `shadow_creatures` in the config. The `lane_type` override applies the special effect.

For **pilfer-based lane effects** (Heist, Madness), give the enemy **no runes** (`[]`) so the player can attack face freely without triggering prophecies. Pre-place friendly creatures in the shadow lane ready to attack.

### Testing Lane Layout Variations (Asymmetric Splits)

To test non-standard lane capacities (e.g. 2/6, 3/4), you may need to **create a new board profile** in `data/legends/registries/lane_registry.json` under `board_profiles`. Check `supported_lane_widths` in that file to confirm the desired capacities are valid. Example profile for a 2/6 split:

```json
{
  "id": "split_2_6",
  "display_name": "2/6 Lane Split",
  "lanes": [
    {"lane_id": "field", "slot_capacity": 2},
    {"lane_id": "shadow", "slot_capacity": 6}
  ],
  "source_ids": ["workspace_spec"]
}
```

Then set `"board_profile"` in the test config to the new profile's `id`. Provide enough cheap creatures in hand/deck to fill both lanes and verify the cap is enforced.

### Bulk Config Creation

When creating configs for many related mechanics (e.g. all lane types), define a **sensible default template** first — shared magicka, enemy setup, deck filler — then customize only the cards/board that each specific lane effect requires. This avoids redundant card research per config.

### Step 4 — Annotate the JSON

Use `"name"` and `"description"` fields to make the config self-documenting. The description appears in the picker UI alongside the name.

### Step 5 — Summarize for the User

Tell the user:
1. What's in their hand and why
2. What's already on the board
3. What's in the deck to draw into
4. What's in the discard pile (if populated)
5. What the enemy board looks like
6. Step-by-step instructions for testing (e.g. "Attack Squire into the Imp to trigger Veteran")
7. Remind them: **Launch the game, hover the Match button, press `?`, then select the config**

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
