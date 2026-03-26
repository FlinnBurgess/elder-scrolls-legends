---
name: wiki-fix
description: Fix a card by comparing its local data and effects against the UESP wiki. Takes a card name, fetches wiki details, audits data fields and gameplay functionality, and fixes any discrepancies.
model: opus
effort: high
---

# Fix Card from Wiki

Look up a card on the UESP wiki, compare it against the local implementation, and fix any discrepancies in data or gameplay functionality. Includes deep validation that all referenced ops, keywords, target modes, and synergies are actually implemented in the engine.

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

3. If the wiki page cannot be found or parsed, note the failure but **continue to Step 3** — code-level validation (Steps 3e-3i) can still run without wiki data.

## Step 3: Compare and Audit

Compare every field between the local seed and the wiki data (where available). Then perform deep code-level validation regardless of wiki availability.

### 3a. Data Fields (requires wiki data)
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

### 3e. Effect Ops Exist in Engine (code-level check)

For every effect in every `triggered_abilities` entry (including effects inside `choose_one` choices and effects on inline `card_template` objects), verify the `"op"` value is handled by the engine.

**How to check:** Search `match_timing.gd` `_apply_effects()` for the op string, then search `extended_mechanic_packs.gd` `apply_custom_effect()` for the op string. The op must appear as a handled case in one of these two functions.

**Valid ops in `_apply_effects()` (match_timing.gd):**
modify_stats, deal_damage, restore_creature_health, grant_keyword, grant_random_keyword, remove_keyword, grant_status, silence, shackle, battle_creature, destroy_creature, sacrifice, unsummon, banish, banish_and_return_end_of_turn, steal, consume, move_between_lanes, copy, change, transform, generate_card_to_hand, generate_card_to_deck, summon_from_effect, fill_lane_with, summon_copies_to_lane, summon_copy_to_other_lane, summon_random_from_discard, heal, gain_max_magicka, draw_cards, draw_filtered, discard, draw_from_discard_filtered, equip_items_from_discard, steal_items, steal_keywords, copy_keywords_to_friendly, copy_from_opponent_deck, copy_card_to_hand, return_to_hand, shuffle_hand_to_deck_and_draw, spend_all_magicka_for_stats, reveal_opponent_top_deck, log, grant_extra_attack, double_stats, trigger_friendly_last_gasps, change_lane_types, select_card_from_hand, destroy_all_except_random

**Valid ops in `apply_custom_effect()` (extended_mechanic_packs.gd):**
assemble, upgrade_shout, invade, buff_oblivion_gate_summon, track_treasure_hunt, damage, empower_damage, gain_magicka, summon_random_from_catalog, generate_random_to_hand, equip_random_item_from_catalog, reduce_random_hand_card_cost, conditional_equip_bonus, grant_player_ward, reduce_next_card_cost, escalating_damage, look_at_top_deck_may_discard, modify_card_cost, summon_random_from_deck, summon_random_by_target_cost, transform_random_from_catalog, transform_random_by_cost

**Important:** Do not rely solely on this list — always grep the actual source files to confirm, as new ops may have been added since this skill was last updated. If an op is not found in either function, flag it as **UNIMPLEMENTED OP** — this means the trigger will silently do nothing at runtime.

### 3f. Target Modes Are Handled (code-level check)

If the card has an `action_target_mode` field, verify it is handled by the targeting system.

**How to check:** Search `extended_mechanic_packs.gd` `_card_matches_target_mode()` for the target mode string.

**Known valid target modes:**
creature_or_player, any_creature, wounded_creature, friendly_creature, enemy_creature, enemy_creature_in_lane, another_friendly_creature, enemy_support_or_neutral_creature, neutral

**Important:** Always grep the source to confirm — if the mode is not handled, the player will be unable to play the card or it will target incorrectly. Flag as **UNHANDLED TARGET MODE**.

### 3g. Keywords Are Engine-Recognized (code-level check)

For every keyword in the card's `keywords` array, `equip_keywords` array, and any `grant_keyword` effects, verify the keyword is:

1. **Registered** in `data/legends/registries/keyword_effect_registry.json` (under `keywords` or `extended_pack_keywords`)
2. **Handled by the engine** — search `evergreen_rules.gd` for the keyword string to confirm it has gameplay impact (e.g., `has_keyword()` checks, combat modifiers, etc.)

**Known valid keywords:**
- Evergreen: breakthrough, charge, drain, guard, lethal, mobilize, rally, regenerate, ward
- Extended: assemble, beast_form, betray, consume, empower, exalt, expertise, invade, plot, shout, treasure_hunt, veteran, wax_and_wane

**Status markers** (applied via `grant_status`, not `grant_keyword`): cover, shackled, silenced, wounded, exalted

Flag any keyword not found in both the registry and engine code as **UNRECOGNIZED KEYWORD**.

### 3h. Trigger Conditions Reference Valid Values (code-level check)

For every trigger condition on each `triggered_abilities` entry, verify the referenced values exist:

1. **`required_subtype_on_board`** / **`required_event_source_subtype`** / **`required_summon_subtype`** — Search `card_catalog.gd` for the subtype string to confirm at least one card in the catalog has it in its `subtypes` array.
2. **`required_keyword_on_board`** / **`required_summon_keyword`** — Verify the keyword is in the valid keyword list (see 3g).
3. **`required_event_source_attribute`** / **`required_top_deck_attribute`** — Must be one of: strength, intelligence, willpower, agility, endurance, neutral.
4. **`required_top_deck_card_type`** — Must be one of: creature, action, item, support.
5. **`required_played_rules_tag`** / **`excluded_rule_tag`** — Search `card_catalog.gd` for the rules_tag string to confirm at least one card uses it.
6. **Trigger family** — Verify the `family` value exists in `FAMILY_SPECS` in `match_timing.gd`.

Flag any condition that references a non-existent value as **INVALID CONDITION VALUE**.

### 3i. Synergy and Alt-View Integrity (code-level check)

1. **Synergy extraction** — If the card has any of these fields, verify `card_synergy_extractor.gd` would pick them up:
   - `aura` with `filter_subtype` or `filter_attribute`
   - `cost_reduction_aura` with `filter_subtype`
   - Trigger conditions: `required_subtype_on_board`, `required_event_source_subtype`, `required_summon_subtype`
   - Effect filters with `required_subtype` or `required_rules_tag`

   Read `card_synergy_extractor.gd` and trace through the extraction logic to confirm the card's synergy fields would be found. If a synergy-relevant field exists but the extractor doesn't look for it in that location, flag as **MISSED SYNERGY**.

2. **Alt-view / related cards** — If the card has effects that generate or summon other cards (ops: `summon_from_effect`, `generate_card_to_hand`, `fill_lane_with`, `summon_copies_to_lane`, `equip_generated_item`, `transform`), verify:
   - The effect contains a `card_template` object
   - `card_relationship_resolver.gd` would find it by checking for these ops in the `RELATED_CARD_OPS` list

   Flag missing templates as **MISSING ALT-VIEW CARD**.

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

### Code-Level Validation
| Check | Details | Status |
|-------|---------|--------|
| Effect ops exist | All 3 ops found in engine | OK |
| Target mode handled | creature_or_player → OK | OK |
| Keywords recognized | guard, ward → both in registry + engine | OK |
| Conditions valid | required_subtype_on_board: "Dragon" → 5 cards have it | OK |
| Synergy extraction | filter_subtype: "Dragon" → extractor finds it | OK |
| Alt-view cards | summon_from_effect has card_template | OK |

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

### Unimplemented ops, unhandled target modes, unrecognized keywords
These are engine-level gaps. For each:
1. Check if an existing op/mode/keyword handler can be reused or extended.
2. If not, implement the handler following existing patterns in the relevant file.
3. After implementation, re-verify the card's trigger works end-to-end.

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
