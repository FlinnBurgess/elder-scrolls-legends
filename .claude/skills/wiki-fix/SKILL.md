---
name: wiki-fix
description: Fix a card by comparing its local data and effects against the UESP wiki. Takes a card name, fetches wiki details, audits data fields and gameplay functionality, and fixes any discrepancies.
---

# Fix Card from Wiki

Look up a card on the UESP wiki, compare it against the local implementation, and fix any discrepancies in data or gameplay functionality.

## Arguments

`$ARGUMENTS` — The card name (e.g., "Nahagliiv", "Blackreach Rebuilder", "Tazkad the Packmaster").

## Step 1: Find the Card Locally

1. Search `src/deck/card_catalog.gd` for the card name (case-insensitive) to find its `_seed()` call.
2. Read the full seed including all extra dictionary fields.
3. If the card is not found, tell the user and stop.

## Step 2: Fetch Wiki Data

1. Fetch the card's UESP wiki page:
   ```
   https://en.uesp.net/wiki/Legends:{Card_Name_With_Underscores}
   ```
   Replace spaces with underscores in the card name (e.g., "Alik'r Survivalist" → `Legends:Alik%27r_Survivalist`).

2. Extract the following from the wiki page:
   - **Name** — exact card name
   - **Card type** — Creature, Action, Item, or Support
   - **Attributes** — Strength, Intelligence, Willpower, Agility, Endurance, Neutral
   - **Cost** (magicka)
   - **Power / Health** (for creatures)
   - **Rarity** — Common, Rare, Epic, Legendary
   - **Is Unique** — whether the card is unique (legendary unique cards)
   - **Race/subtypes** — Nord, Dragon, Imperial, etc.
   - **Keywords** — Guard, Charge, Breakthrough, Ward, Lethal, Drain, Regenerate, Rally, Mobilize
   - **Rules text** — the full card text describing abilities
   - **Set/expansion** — which set the card belongs to

3. If the wiki page cannot be found or parsed, tell the user and stop.

## Step 3: Compare and Audit

Compare every field between the local seed and the wiki data. Check for discrepancies in:

### 3a. Data Fields
- `name` — exact match
- `card_type` — creature/action/item/support
- `attributes` — correct attribute(s)
- `cost` — magicka cost
- `base_power` / `base_health` — for creatures
- `rarity` — common/rare/epic/legendary
- `is_unique` — should be true for unique legendaries
- `subtypes` — race/creature type
- `keywords` — static keywords displayed on the card
- `rules_text` — should match wiki card text (minor formatting differences are OK)
- `rules_tags` — e.g., "prophecy" if the card has Prophecy

### 3b. Item Equip Fields (items only)
If the card is an item, verify:
- `equip_power_bonus` / `equip_health_bonus` match the `+X/+Y` in rules text
- `equip_keywords` includes all static keywords (not triggered abilities)

### 3c. Gameplay Functionality (Triggered Abilities)
This is the most critical check. Parse the wiki rules text and verify that every ability described is implemented in `triggered_abilities`. Check:

1. **Every ability in the rules text has a corresponding trigger**:
   - "Summon:" → `family: "summon"`
   - "Last Gasp:" → `family: "last_gasp"`
   - "Slay:" → `family: "slay"`
   - "Pilfer:" → `family: "pilfer"`
   - "At the start of your turn" → `family: "start_of_turn"`
   - "At the end of your turn" → `family: "end_of_turn"`
   - "When ... attacks" → `family: "on_attack"`
   - "When ... takes damage" → `family: "on_damage"`
   - "When a friendly creature dies" → `family: "on_friendly_death"`
   - "When a rune is destroyed" → `family: "rune_break"` or `"on_enemy_rune_destroyed"`
   - "When you play an action" → `family: "after_action_played"`
   - "When ... is equipped" → `family: "on_equip"`
   - "Veteran" → `family: "veteran"`
   - "Expertise" → `family: "expertise"`
   - "Plot:" → `family: "plot"`
   - "Activate:" → `family: "activate"`

2. **Each trigger's effects match the described behaviour**:
   - Damage amounts are correct
   - Stat modifications (+X/+Y) are correct
   - Draw counts are correct
   - Target scope is correct (self, all creatures, friendly creatures, enemy creatures, etc.)
   - Conditions/filters are correct (e.g., "creatures with 2 power or less", "Dragon", etc.)

3. **Choice/modal abilities are all present**:
   - "X or Y" should have separate triggered_abilities for each option, or use `choose_one`
   - All options described on the wiki are available

4. **Aura effects are implemented** (ongoing passive effects):
   - "Other friendly creatures get +1/+1" → needs `aura` field
   - Verify `scope`, `target`, stat bonuses, and filters

5. **Prophecy tag** is present if the card has Prophecy

### 3d. Generated Cards / Tokens
If the wiki describes the card creating tokens or other cards:
- Check that `generate_card_to_hand` or `summon_from_effect` templates exist
- Verify the generated card's stats/keywords/text match the wiki
- If the token needs a separate `_seed()` entry (non-collectible), verify it exists

## Step 4: Report Findings

Present a clear comparison table of all fields, marking each as matching or mismatched:

```
## Audit: {Card Name}

### Data Fields
| Field | Wiki | Local | Status |
|-------|------|-------|--------|
| Cost  | 5    | 5     | OK     |
| Power | 4    | 3     | MISMATCH |
| ...   | ...  | ...   | ...    |

### Abilities
| Ability | Wiki Description | Local Implementation | Status |
|---------|-----------------|---------------------|--------|
| Summon  | Deal 3 damage   | deal_damage amount:3 | OK    |
| Slay    | Draw a card     | (missing)           | MISSING |

### Discrepancies Found: X
```

If there are no discrepancies, report the card as fully correct and stop.

## Step 5: Fix Discrepancies

For each discrepancy found:

### Data field fixes
Update the `_seed()` call in `card_catalog.gd` with the correct values.

### Missing or incorrect triggered abilities
1. If the ability just needs a trigger descriptor wired up, add it to the card's `triggered_abilities` array.
2. If the required effect operation doesn't exist yet, check `match_timing.gd` `_apply_effects()` and `extended_mechanic_packs.gd` for existing ops that could accomplish the behaviour.
3. If a genuinely new effect op is needed, implement it in `_apply_effects()` following the pattern of existing ops. Make it generic and reusable.
4. If new fields are needed, ensure they flow through:
   - `_seed()` in `card_catalog.gd`
   - `_build_card()` in `card_catalog.gd`
   - `_hydrate_card()` in `match_screen.gd`

### Missing tokens/generated cards
If the card generates tokens that don't exist:
- Add inline `card_template` objects for cards generated to hand or summoned from effects
- For tokens that need their own catalog entry (referenced by `definition_id`), add a non-collectible `_seed()` call

### Key files for implementing fixes
- `src/deck/card_catalog.gd` — card definitions
- `src/core/match/match_timing.gd` — trigger matching and effect resolution
- `src/core/match/match_mutations.gd` — state mutation helpers
- `src/core/match/evergreen_rules.gd` — keyword/stat/status helpers
- `src/core/match/extended_mechanic_packs.gd` — custom effects and conditions
- `src/core/match/lane_rules.gd` — lane entry and summon validation
- `src/core/match/persistent_card_rules.gd` — play-from-hand flows
- `src/ui/match_screen.gd` — card hydration (`_hydrate_card`)

## Step 6: Scan for Related Cards

After fixing, search `card_catalog.gd` for other cards that might have the same class of discrepancy. For example:
- If you fixed a missing trigger family, search for other cards with similar `rules_text` patterns that might also be missing it
- If you fixed missing equip fields on an item, check other items for the same issue
- If you implemented a new effect op, look for other cards whose `rules_text` suggests they need it

Report any related cards found and fix them too.

If any identified cards cannot be fixed right now, add them to `development-artifacts/unfixed_card_effects.md`.

## Step 7: Update Tracking

1. Update the card's entry in `development-artifacts/core_set_cards.json` if relevant fields changed.
2. If a new bug class was identified, document it in `development-artifacts/bug_classes.md` (see fix-card-effect skill for format).

## Step 8: Test

Run the relevant test runners to verify no regressions:
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/<runner>.gd
```

Key runners to check:
- `items_and_supports_runner.gd` — if item equip fields changed
- `timing_runner.gd` — if trigger timing changed
- `extended_mechanics_runner.gd` — if custom effects changed
- `keyword_matrix_runner.gd` — if keywords changed
- `golden_match_runner.gd` — general regression check
