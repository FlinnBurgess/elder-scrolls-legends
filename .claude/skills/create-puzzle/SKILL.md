---
name: create-puzzle
description: Create a hardcoded puzzle for a puzzle pack. Gathers board state details through interview, writes a JSON puzzle file, and registers it in the pack index. Use when user wants to create a puzzle, add a puzzle to a pack, or set up a specific board state as a puzzle.
---

# Create Puzzle

Create a hardcoded puzzle JSON file in `data/puzzle_packs/` and register it in the pack's index.

## Input

A description of the puzzle to create, or just invoke the skill to start the interview.

## Workflow

### Step 1 — Determine the Pack

Check `data/puzzle_packs/` for existing pack directories. Each pack has an `index.json`:

```json
{
  "pack_id": "starter_puzzles",
  "display_name": "Starter Puzzles",
  "puzzles": [
    { "id": "starter_01", "name": "First Blood", "type": "kill", "file": "starter_01.json" },
    { "id": "starter_02", "name": "Hold the Line", "type": "survive", "file": "starter_02.json" }
  ]
}
```

Present existing packs to the user and ask which one this puzzle belongs to, or let them enter a new pack name. If creating a new pack, create the directory and `index.json`.

### Step 2 — Interview for Puzzle Details

Ask the user for the following. Accept card names (resolve to card_ids via `card_catalog.gd`) or card_ids directly. For creatures on board, also ask about stat overrides.

**Required:**
- Puzzle name
- Puzzle type: `kill` (win this turn) or `survive` (survive enemy turn)

**Player side:**
- Health (default: 30)
- Max magicka / current magicka (default: 12/12)
- Ring of Magicka (default: no)
- Hand cards
- Deck cards (top to bottom — index 0 is drawn first)
- Discard pile cards
- Support cards in play
- Lane 1 (field) creatures
- Lane 2 (shadow) creatures

**Enemy side:**
- Health (default: 30)
- Max magicka / current magicka (default: 3/3)
- Hand cards
- Deck cards (top to bottom)
- Discard pile cards
- Support cards in play
- Lane 1 (field) creatures
- Lane 2 (shadow) creatures

**For each creature on board**, ask if any overrides are needed:
- Power bonus / health bonus
- Damage marked
- Can attack (default: true for player creatures, false for enemy creatures that shouldn't attack)
- Extra keywords granted
- Status markers (e.g. `"shackled"`)
- Cover status

**Lane configuration:**
- Always use a 4/4 split with field/shadow lane types

For any field the user doesn't specify, use the defaults listed above. Empty arrays for unmentioned card lists.

### Step 3 — Resolve Card IDs

Look up card names in `src/deck/card_catalog.gd` using the `_seed()` calls. The first argument is the `card_id`. Match by name (2nd argument) case-insensitively. If ambiguous, ask the user to clarify.

### Step 4 — Write the Puzzle JSON

Create the puzzle file at `data/puzzle_packs/<pack_id>/<puzzle_id>.json`:

```json
{
  "name": "Puzzle Name",
  "type": "kill",
  "lanes": [
    { "lane_type": "field", "width": 4 },
    { "lane_type": "shadow", "width": 4 }
  ],
  "player": {
    "health": 30,
    "max_magicka": 12,
    "current_magicka": 12,
    "has_ring": false,
    "hand": ["card_id_1", "card_id_2"],
    "deck": ["card_id_3"],
    "discard": [],
    "supports": [],
    "field_creatures": ["card_id_4"],
    "shadow_creatures": []
  },
  "enemy": {
    "health": 30,
    "max_magicka": 3,
    "current_magicka": 3,
    "hand": [],
    "deck": [],
    "discard": [],
    "supports": [],
    "field_creatures": [],
    "shadow_creatures": []
  }
}
```

**Creature entries** can be:
- A string (just the card_id): `"str_fiery_imp"`
- A dict with overrides:
  ```json
  {
    "definition_id": "str_fiery_imp",
    "power_bonus": 2,
    "health_bonus": 1,
    "damage_marked": 0,
    "can_attack": true,
    "keywords": ["guard"],
    "status_markers": ["shackled"]
  }
  ```
  Only include override fields that differ from defaults.

### Step 5 — Register in Pack Index

Add the puzzle entry to the pack's `index.json` `puzzles` array:

```json
{ "id": "<puzzle_id>", "name": "<Puzzle Name>", "type": "<kill|survive>", "file": "<puzzle_id>.json" }
```

### Step 6 — Load the Pack in the Puzzle Select Screen

Check if `src/ui/puzzle/puzzle_select_screen.gd` already loads packs from `data/puzzle_packs/`. If not, add the loading logic:

1. In `_build_ui`, after building the custom puzzles section, scan `data/puzzle_packs/` for subdirectories
2. For each pack, read its `index.json` and build a collapsible section (like custom puzzles)
3. Each puzzle entry gets a Play button that decodes the JSON config and emits `puzzle_selected`

The pack loading code should:
- Read `data/puzzle_packs/<pack_id>/index.json` for the pack metadata
- For each puzzle in the index, read `data/puzzle_packs/<pack_id>/<file>` to get the config
- Encode the config using `PuzzleCodecScript.encode()` to create a puzzle entry compatible with the existing `puzzle_selected` signal
- Show a solved indicator if the puzzle has been completed

### Step 7 — Summarize

Tell the user:
1. The puzzle name and pack it belongs to
2. The board state summary (who has what)
3. The intended solution or goal
4. Remind them to restart the game to see the new pack in the puzzle list

## Notes

- Puzzle IDs should be `<pack_id>_<nn>` (e.g. `starter_01`, `starter_02`)
- Use the puzzle config format directly (same as puzzle builder), NOT the test match format
- The puzzle codec `PZ:` prefix is only for shareable codes — pack puzzles store raw JSON configs
- Deck order matters: index 0 is the top of the deck (drawn first)
- For survive puzzles, give the enemy enough cards/creatures to threaten the player
- For kill puzzles, give the player the tools to win in one turn with clever play
