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

**Check scraped data first:** Read `data/wiki_scrape/cards.json` and filter by `card_set` or `card_set_source` matching the expansion name. This contains pre-scraped data for all cards across all expansions, including beast form / multi-form cards (entries with `is_alternate_form: true`).

**If the expansion is not in scraped data**, fetch the wiki page at `$ARGUMENTS` to identify:
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

### 1d. Cross-reference card lists

The main expansion page and the category page may not match perfectly. Cross-reference both lists to ensure no cards are missed. Sort alphabetically and diff if needed.

### 1e. Get card details

**When using scraped data (`data/wiki_scrape/cards.json`):** Each card entry already contains all needed fields: `name`, `card_type`, `subtypes`, `attributes`, `cost`, `power`, `health`, `rarity`, `deck_code_id`, `card_set`, `card_text`, `art_url`, `is_unique`, and `wiki_page`. For beast form cards, both the base form and transformed form are separate entries with `is_alternate_form: true`. This is sufficient for generating `_seed()` calls — no additional wiki fetching should be needed for data fields.

**When scraped data is unavailable:** For large expansions (100+ cards), fetching every individual wiki page is impractical. Instead:
1. Use the main expansion page for bulk stats (name, type, cost, power/health, rarity, subtypes)
2. Fetch individual pages only for complex cards (legendaries, cards with new mechanics, cards with ambiguous abilities)
3. **Parallelize research** by launching multiple agents, each handling one attribute section

The wiki sometimes omits details on the main page. For complex cards, fetch individual card pages:
```
https://en.uesp.net/wiki/Legends:{Card_Name_With_Underscores}
```

### 1f. Parallelize card writing

For large expansions, split the card writing work across parallel agents (one per attribute section or group of sections). Each agent should be given the full REFERENCE.md format and the card data for its section, then produce the `_seed()` entries.

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

Order: Strength, Intelligence, Willpower, Agility, Endurance, Neutral, Dual-Attribute (2 attributes), Triple-Attribute (3 attributes / house cards), then Non-Collectible Tokens.

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

### Triple-attribute cards (house cards)

Use `{prefix}_tri_{snake_case_name}` and pass all three attributes:
```gdscript
_seed("hom_tri_dagoth_ur", "Dagoth Ur", ["strength", "intelligence", "agility"], "creature", ...)
```

Group by house with a comment for clarity:
```gdscript
# House Redoran (Strength/Willpower/Endurance)
# House Telvanni (Intelligence/Agility/Endurance)
# House Hlaalu (Strength/Willpower/Agility)
# House Dagoth (Strength/Intelligence/Agility)
# House Tribunal (Intelligence/Willpower/Endurance)
```

### Token cards

Non-collectible tokens go in a separate section at the end:
```gdscript
# -- {EXPANSION_NAME} -- NON-COLLECTIBLE TOKENS --
_seed("hos_str_rallying_stormcloak", ..., {"collectible": false, ...})
```

## Phase 5: Verify

1. **Run a baseline test** early (Phase 2) before adding any cards, so you have output to compare against
2. Count `_seed("prefix_` entries to confirm collectible count matches expected
3. Count `"collectible": false` entries for token count
4. Run the test suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/all_rules_runner.gd`
5. Compare test output against the baseline run to confirm no regressions were introduced

## Phase 6: Report

Present a summary table:

| Section | Collectible | Tokens |
|---------|-------------|--------|
| Strength | X | Y |
| ... | ... | ... |
| **Total** | **N** | **M** |

List any new mechanics added and any complex cards that may need additional engine work.

## Phase 7: Fetch Card Art

After all cards are added and verified, download artwork for the newly imported cards. The scraped data in `data/wiki_scrape/cards.json` includes `art_url` for each card — use these URLs directly with `curl` to download art to `assets/images/cards/<card_id>.png` rather than re-scraping the wiki. Fall back to the `/download-missing-art` skill for any cards missing `art_url` in the scraped data.
