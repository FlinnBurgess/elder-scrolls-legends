---
name: import-expansion
description: Import an entire Elder Scrolls Legends card expansion from a UESP wiki page. Use when user wants to add an expansion, card set, or batch of cards by providing a wiki URL.
---

# Import Expansion

Import all cards from an Elder Scrolls Legends expansion into the game's card catalog.

## Arguments

`$ARGUMENTS` — A UESP wiki URL for the expansion (e.g., `https://en.uesp.net/wiki/Legends:Heroes_of_Skyrim`)

## Phase 1: Research the Expansion

### 1a. Get the card list

Fetch the wiki page at `$ARGUMENTS` to identify:
- Total number of collectible cards
- Card sections (by attribute + neutral + dual-attribute)
- Any new keywords or mechanics introduced

The main expansion page usually truncates. To get the **complete** card list, fetch the wiki category page:
```
https://en.uesp.net/wiki/Category:Legends-Cards-{Expansion_Name_Hyphenated}
```
For example: `Category:Legends-Cards-Heroes_of_Skyrim`

This category lists ALL cards including tokens and transformed forms.

### 1b. Separate collectible cards from tokens

From the category page, identify:
- **Collectible cards**: The main cards players can own
- **Tokens/transforms**: Created by other cards (e.g., werewolf forms, summoned creatures)
  - Transformed versions of Beast Form creatures
  - Summoned tokens (villagers, soldiers, etc.)
  - Generated items (trinkets, scrolls, etc.)

### 1c. Identify new keywords and mechanics

Fetch individual card pages to understand any new mechanics. Common expansion mechanics include:
- **Shout** (3-level action cards that upgrade when played)
- **Beast Form** (creatures transform on enemy rune break)
- **Assemble** (choose one of two bonuses)
- **Betray** (sacrifice friendly creature to replay)
- **Exalt** (pay extra magicka for bonus effect)
- **Plot** (bonus if you played another card this turn)
- **Veteran** (triggers after first attack)

For each new mechanic, check if the engine already supports it by searching `src/core/match/extended_mechanic_packs.gd` and `data/legends/registries/keyword_effect_registry.json`.

### 1d. Get card details

For each attribute section, fetch enough card pages to get full details:
- Name, type, attributes, cost, power/health, rarity, subtypes
- Keywords, abilities, rules text
- Token cards they generate

The wiki sometimes omits details on the main page. For complex cards (legendaries, cards with new mechanics), fetch individual card pages:
```
https://en.uesp.net/wiki/Legends:{Card_Name_With_Underscores}
```

## Phase 2: Check Existing State

Before adding cards, verify what already exists:

1. **Check for existing cards** — Search `src/deck/card_catalog.gd` for any cards from this expansion that may already be present
2. **Check for existing set constants** — Look for set ID constants matching the expansion
3. **Check mechanic support** — For each new keyword/mechanic, grep the codebase to see if the engine already handles it

## Phase 3: Engine Updates (if needed)

If the expansion introduces mechanics not yet supported:

1. **Add keyword to registry** — Update `data/legends/registries/keyword_effect_registry.json`
2. **Add passthrough in card catalog** — Update `_build_card()` and `_seed()` in `card_catalog.gd` to forward new fields (like `shout_chain_id`, `shout_level`, `shout_levels`)
3. **Do NOT implement engine logic** — Just add the data format support. Flag any unimplemented mechanics to the user.

## Phase 4: Add Cards

See [REFERENCE.md](REFERENCE.md) for the detailed card data format.

### Organization

Add cards to `_card_seeds()` in `src/deck/card_catalog.gd`, organized as:

```gdscript
# -- {EXPANSION_NAME} -- {ATTRIBUTE} ({count} cards) --
```

Order: Strength, Intelligence, Willpower, Agility, Endurance, Neutral, Dual-Attribute, then Non-Collectible Tokens.

### Set ID constants

Add constants at the top of `card_catalog.gd`:
```gdscript
const {PREFIX}_SET_ID := "{expansion_snake_case}"
const {PREFIX}_RELEASE_GROUP_ID := "{prefix}_pvp"
```

Every card in the expansion must include `"set_id": {PREFIX}_SET_ID` and `"release_group_id": {PREFIX}_RELEASE_GROUP_ID` in its extra dict.

### Card ID convention for expansion cards

Use prefix `{expansion_prefix}_{attribute_prefix}_{snake_case_name}`:
- `hos_str_aela_the_huntress` (Heroes of Skyrim, Strength)
- `cws_int_laaneth` (Clockwork City, Intelligence)

### Dual-attribute cards

Use `{prefix}_dual_{snake_case_name}` and pass both attributes:
```gdscript
_seed("hos_dual_archers_gambit", "Archer's Gambit", ["strength", "agility"], "action", ...)
```

### Token cards

Non-collectible tokens go in a separate section at the end:
```gdscript
# -- {EXPANSION_NAME} -- NON-COLLECTIBLE TOKENS --
_seed("hos_str_rallying_stormcloak", ..., {"collectible": false, ...})
```

## Phase 5: Verify

1. Count `_seed("prefix_` entries to confirm collectible count matches expected
2. Count `"collectible": false` entries for token count
3. Run the test suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/all_rules_runner.gd`
4. Compare test output against a baseline run to confirm no regressions were introduced

## Phase 6: Report

Present a summary table:

| Section | Collectible | Tokens |
|---------|-------------|--------|
| Strength | X | Y |
| ... | ... | ... |
| **Total** | **N** | **M** |

List any new mechanics added and any complex cards that may need additional engine work.
