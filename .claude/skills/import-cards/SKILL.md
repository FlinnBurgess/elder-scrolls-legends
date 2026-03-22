# Import Card Data

Import card data into the Elder Scrolls Legends card catalog.

## Invocation

The user provides card data (from a wiki page, JSON, or other source) and asks to import it into the game.

**Preferred source:** `data/wiki_scrape/cards.json` contains pre-scraped wiki data for all cards across all expansions. Search by card name or filter by `card_set`/`card_set_source`. Beast form / multi-form cards have multiple entries with `is_alternate_form: true` — use the base form for the `_seed()` and the transformed form for the inline `card_template`.

## Card Catalog Location

Cards are defined as `_seed()` calls inside `_card_seeds()` in `src/deck/card_catalog.gd`.

## _seed() Signature

```gdscript
_seed(card_id: String, name: String, attributes: Array, card_type: String, cost: int, base_power: int, base_health: int, extra: Dictionary = {})
```

## Card ID Convention

Format: `{attribute_prefix}_{snake_case_name}`

Attribute prefixes:
- `str_` = Strength
- `int_` = Intelligence
- `wil_` = Willpower
- `agi_` = Agility
- `end_` = Endurance
- `neu_` = Neutral
- `dual_` = Dual-attribute (2+ attributes)

Examples: `str_nord_firebrand`, `int_firebolt`, `dual_tyr`, `neu_maple_shield`

## Attribute IDs

Use lowercase: `"strength"`, `"intelligence"`, `"willpower"`, `"agility"`, `"endurance"`, `"neutral"`

Neutral cards use an empty attributes array `[]`.

## Card Types

`"creature"`, `"action"`, `"item"`, `"support"`

## Rarity Values

`"common"` (default), `"rare"`, `"epic"`, `"legendary"`

## Extra Dictionary Fields

All fields in `extra` are optional. Only include fields that apply:

| Field | Type | When to use |
|---|---|---|
| `rarity` | String | If not common |
| `is_unique` | bool | True for legendary unique cards |
| `keywords` | Array[String] | Display keywords on the card |
| `effect_ids` | Array[String] | Effect system hooks (see below) |
| `rules_text` | String | Card text as displayed |
| `rules_tags` | Array[String] | Special tags like `"prophecy"` |
| `subtypes` | Array[String] | Creature subtypes like `"Nord"`, `"Dragon"` |
| `support_uses` | int | For support cards with limited uses |
| `collectible` | bool | Set to `false` for tokens/generated cards |
| `equip_power_bonus` | int | **Items only**: power granted to wielder |
| `equip_health_bonus` | int | **Items only**: health granted to wielder |
| `equip_keywords` | Array[String] | **Items only**: keywords granted to wielder |

## CRITICAL: Item Cards Have Two Separate Systems

Item cards require BOTH display fields AND equip fields:

1. **Display fields** (`keywords`, `rules_text`, `effect_ids`) - shown on the card UI but NOT used by the game engine for equip effects
2. **Equip fields** (`equip_power_bonus`, `equip_health_bonus`, `equip_keywords`) - used by the game engine to actually apply stat bonuses and keywords when the item is equipped

### How to parse item rules_text into equip fields

Given rules_text like `"+3/+1\nLethal\nSummon: Draw a card."`:

- **`+X/+Y` pattern**: Extract X → `equip_power_bonus`, Y → `equip_health_bonus`
- **Standalone keywords** (not after "Summon:", "Slay:", etc.): Add to both `keywords` AND `equip_keywords`
- **Triggered abilities** ("Summon:", "Last Gasp:", etc.): Only go in `rules_text` and `effect_ids`, NOT in `equip_keywords`

### Example item seed

```gdscript
_seed("end_daedric_dagger", "Daedric Dagger", ["endurance"], "item", 2, 0, 0, {
    "keywords": ["lethal"],
    "effect_ids": ["modify_stats"],
    "rules_text": "Lethal\n+1/+1",
    "equip_power_bonus": 1,
    "equip_health_bonus": 1,
    "equip_keywords": ["lethal"]
}),
```

### Example item with triggered ability

```gdscript
_seed("str_assassins_bow", "Assassin's Bow", ["strength"], "item", 3, 0, 0, {
    "rarity": "rare",
    "effect_ids": ["equip", "modify_stats", "summon"],
    "rules_text": "+3/+0\nSummon: Give the wielder Cover at the end of turn.",
    "equip_power_bonus": 3
}),
```

Note: The Summon ability is NOT an equip keyword - it's a triggered effect, so it only appears in `effect_ids` and `rules_text`.

## Available Keywords

`breakthrough`, `charge`, `drain`, `guard`, `lethal`, `mobilize`, `rally`, `regenerate`, `ward`

## Common effect_ids

- `summon` - Summon trigger
- `last_gasp` - Last Gasp trigger
- `slay` - Slay trigger
- `damage` - Deals damage
- `destroy` - Destroys creatures/supports
- `modify_stats` - Modifies power/health
- `draw` - Card draw
- `heal` - Healing
- `silence` - Silences creatures
- `unsummon` - Returns to hand
- `equip` - Equip-related effect
- `create` - Creates cards/tokens
- `transform` - Transforms creatures
- `shackle` - Shackles creatures
- `move` - Moves creatures between lanes
- `steal` - Steals cards/stats
- `copy` - Copies creatures
- `discard` - Discards cards
- `support` - Support-related
- `rune` - Rune-related

## rules_text Formatting

- Separate keywords from ability text with newlines: `"Guard\nSummon: Draw a card."`
- Multiple keywords on separate lines: `"Breakthrough\nGuard"`
- Stat bonuses for items: `"+2/+2"` or `"+3/+0"`

## Token/Created Cards

Cards that are created by other cards (not collectible):
- Set `"collectible": false` in extra
- Still need a full `_seed()` entry

## Tracking File

After importing, update `development-artifacts/core_set_cards.json` with the new card data. Each card entry should include all fields plus a `status` field (set to `"created"`).

## Hydration

If `src/ui/match_screen.gd` `_hydrate_card()` does not already handle any new fields being added, update it to pass them through from the card definition to the match card instance.

## Steps

1. Parse the source data into card records
2. Generate `_seed()` calls with correct card_id, attributes, types, and extra fields
3. For item cards, parse rules_text to extract equip fields
4. Add seeds to `_card_seeds()` in `src/deck/card_catalog.gd`, grouped by attribute with comments
5. Update `development-artifacts/core_set_cards.json` tracking file
6. Run relevant tests to verify no regressions
