# Fix Card Effect

Investigate and fix a card whose in-game effect is not working as described.

## Arguments

`$ARGUMENTS` — The card name, and optionally a description of what is going wrong.

## Step 1: Gather Information

1. Find the card in `src/deck/card_catalog.gd` by searching for the card name.
2. Read the card's `rules_text` to understand what it should do.
3. If the user has not described the problem, ask what is happening vs what they expected.
4. If anything else is unclear about the expected behaviour, ask for clarification before proceeding.

## Step 2: Diagnose the Issue

Understand the two effect systems:

### Declarative System (Items only)
Item stat bonuses and keywords are applied via fields read by the engine at runtime:
- `equip_power_bonus` / `equip_health_bonus` — stat bonuses applied by `EvergreenRules.get_power()` / `get_health()`
- `equip_keywords` — keywords applied by `EvergreenRules.has_keyword()`
- These are separate from the display-only `keywords`, `rules_text`, and `effect_ids` fields

### Triggered Ability System
Cards with active effects (Summon, Last Gasp, Slay, start/end of turn, on play, etc.) use `triggered_abilities` — an array of trigger descriptors stored on the card. Each descriptor has:
- `id` — unique identifier
- `family` — trigger family (see below)
- `effects` — array of effect operations to execute

**Trigger Families** (defined in `match_timing.gd` `FAMILY_SPECS`):
- `on_play` — when the card is played (actions)
- `summon` — when the creature enters a lane
- `last_gasp` / `on_death` — when the creature is destroyed
- `slay` — when the creature kills another
- `pilfer` — when the creature deals damage to the opponent player
- `start_of_turn` / `end_of_turn` — at turn boundaries
- `activate` — when a support is activated
- `veteran` — when the creature survives damage
- `expertise` — when controller plays a 5+ cost card
- `rune_break` — when a rune is broken

**Effect Operations** (defined in `match_timing._apply_effects()`):
- `modify_stats` — `{op, target, power, health}`
- `grant_keyword` — `{op, target, keyword_id}`
- `grant_status` — `{op, target, status_id}`
- `draw_cards` — `{op, target_player, count}`
- `damage` — handled via `ExtendedMechanicPacks.apply_custom_effect()`
- `heal` — handled via `ExtendedMechanicPacks.apply_custom_effect()`
- `summon_from_effect` — `{op, card_template, lane_id (optional)}`
- `summon_copies_to_lane` — `{op, card_template, count OR fill_lane: true}`
- `silence` — `{op, target}`
- `unsummon` — `{op, target}`
- `destroy` — use `discard` or `banish` ops
- `discard` — `{op, target}` or `{op, target_player, count}`
- `banish` — `{op, target}`
- `steal` — `{op, target}`
- `transform` — `{op, target, card_template}`
- `change` — `{op, target, card_template}`
- `copy` — `{op, target, source_target}`
- `move_between_lanes` — `{op, target, lane_id}`
- `consume` — `{op, target, consumer_target}`
- `sacrifice` — `{op, target}`
- `log` — `{op, message}`

**Target Values** for card targets:
- `"self"` — the card that owns the trigger
- `"event_source"` — the card that caused the event
- `"event_target"` — the target of the event
- `"event_subject"` — the subject of the event

**Target Player Values**:
- `"controller"` — the card's controller
- `"event_player"` — the player who caused the event
- `"target_player"` — the target player of the event

### Common Root Causes

1. **Missing `triggered_abilities`** — Card has `effect_ids` and `rules_text` but no `triggered_abilities` array, so the effect never fires.
2. **Missing equip fields on items** — Item has `keywords`/`rules_text` but lacks `equip_power_bonus`/`equip_health_bonus`/`equip_keywords`.
3. **Effect op not implemented** — The required behaviour needs a new op in `match_timing._apply_effects()`.
4. **Wrong trigger family** — e.g., using `summon` instead of `on_play` for an action card.
5. **Hydration not passing field** — New fields added to the catalog but not copied in `match_screen._hydrate_card()`.

### Key Files to Investigate

- `src/deck/card_catalog.gd` — card definitions
- `src/core/match/match_timing.gd` — trigger matching and effect resolution
- `src/core/match/match_mutations.gd` — state mutation helpers
- `src/core/match/evergreen_rules.gd` — keyword/stat/status helpers
- `src/core/match/extended_mechanic_packs.gd` — custom effects and conditions
- `src/core/match/lane_rules.gd` — lane entry and summon validation
- `src/core/match/persistent_card_rules.gd` — play-from-hand flows (actions, items, supports)
- `src/ui/match_screen.gd` — card hydration (`_hydrate_card`)

## Step 3: Implement the Fix

1. If a new effect op is needed, add it to `_apply_effects()` in `match_timing.gd`, following the pattern of existing ops. Make it generic/reusable rather than card-specific.
2. If the card just needs `triggered_abilities` wired up, update its `_seed()` call in `card_catalog.gd`.
3. If new fields are introduced, ensure they flow through:
   - `_seed()` in `card_catalog.gd`
   - `_build_card()` in `card_catalog.gd`
   - `_hydrate_card()` in `match_screen.gd`
4. If an item needs equip fields, parse the `rules_text` to extract `equip_power_bonus`, `equip_health_bonus`, and `equip_keywords`.

## Step 4: Scan for Other Cards

After implementing the fix, search `card_catalog.gd` for other cards that should use the same effect. Look for:
- Cards with similar `rules_text` patterns (e.g., other "Fill a lane" cards, other "Summon a X" cards)
- Cards with matching `effect_ids` that also lack `triggered_abilities`
- Items with `keywords` or stat text in `rules_text` but missing `equip_*` fields

Report any cards found that could benefit from the same fix, and apply the fix to them as well.

If any identified cards cannot be fixed right now (e.g., they need an engine feature that doesn't exist yet or would be too invasive to add), add them to `development-artifacts/unfixed_card_effects.md` with a short description of what's blocking the fix. If that file doesn't exist, create it with the heading `# Unfixed Card Effects`. Remove entries from the file when they are fixed.

## Step 5: Record Bug Class

After fixing the card, identify the class of bug that caused the issue (e.g., "Missing triggered_abilities on action card", "Item missing equip_keywords field", "Wrong trigger family used"). Then check `development-artifacts/bug_classes.md` — if the file exists, read it and see if this class of bug is already documented. If it is, skip this step. If not (or if the file doesn't exist), append the new bug class with a one-line description and an example card. If creating the file, start it with the heading `# Bug Classes`.

Format each entry as:
```
## <Bug Class Name>
<One-line description of what goes wrong and why>
Example: <card name that exhibited this bug>
How to spot: <describe symptoms a user might report and/or patterns to search for in the catalog to find other affected cards>
```

## Step 6: Update Tracking

Update the card's entry in `development-artifacts/core_set_cards.json` if relevant fields changed.

## Step 7: Test

IMPORTANT: Tests must be run after all changes are complete. Run the relevant test runners to verify no regressions:
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/<runner>.gd
```

Key runners to check after effect changes:
- `items_and_supports_runner.gd`
- `timing_runner.gd`
- `extended_mechanics_runner.gd`
- `keyword_matrix_runner.gd`
- `golden_match_runner.gd`
