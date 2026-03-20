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
- `on_ward_broken` — when the creature's ward is removed
- `on_friendly_slay` — when another friendly creature slays
- `on_attack` — when the creature deals combat damage
- `after_action_played` — when the controller plays an action

**Trigger Conditions** (checked in `extended_mechanic_packs.matches_additional_conditions()`):
These are optional fields on the trigger descriptor that gate whether the trigger fires:
- `required_more_health: true` — controller health strictly > opponent health
- `required_less_health: true` — controller health strictly < opponent health
- `required_not_less_health: true` — controller health >= opponent health (use for "Otherwise" branches paired with `required_less_health`)
- `required_subtype_on_board` — friendly creature with this subtype must be in a lane (excluding self)
- `required_keyword_on_board` — friendly creature with this keyword must be in a lane (excluding self)
- `required_event_source_subtype` — the event source card must have this subtype
- `required_summon_subtype` — the summoned creature must have this subtype
- `required_summon_keyword` — the summoned creature must have this keyword
- `required_played_rules_tag` — the played card must have this rules_tag
- `excluded_rule_tag` — the source card must NOT have this rules_tag

**Effect Operations** (defined in `match_timing._apply_effects()`):
- `modify_stats` — `{op, target, power, health, duration?}` — use `"duration": "end_of_turn"` for "this turn" effects
- `grant_keyword` — `{op, target, keyword_id, duration?}` — use `"duration": "end_of_turn"` for "this turn" effects
- `grant_status` — `{op, target, status_id}`
- `draw_cards` — `{op, target_player, count}`
- `damage` — handled via `ExtendedMechanicPacks.apply_custom_effect()`
- `heal` — handled via `ExtendedMechanicPacks.apply_custom_effect()`
- `gain_magicka` — `{op, amount}` — adds to `temporary_magicka`; handled via `ExtendedMechanicPacks.apply_custom_effect()`
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
- `double_stats` — `{op, target, stat?}` — doubles current power and/or health; `stat` can be `"power"`, `"health"`, or `"both"` (default `"both"`)
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

### Card Relationship / Alt-View System
Cards that care about subtypes, attributes, or other synergies can show contextual info (e.g. "You have 3 Orcs in your deck") when the player cycles through alt-views with UP/DOWN. This is driven by `card_relationship_resolver.gd`, which inspects the card's `triggered_abilities` and `aura` fields to find synergy signals:
- `required_subtype_on_board` — "Summon: +X/+Y if you have another [subtype]"
- `required_event_source_subtype` — "When you summon another [subtype]..."
- `required_summon_subtype` — "When you summon a [subtype]..."
- `aura.filter_subtype` — Aura scaling with subtype count
- `aura.filter_attribute` — Aura scaling with attribute count
- `cost_reduction_aura.filter_subtype` — Cost reduction for a subtype

Cards whose effects create other cards (via `card_template` in their effects) can also show those cards as alt-views. This is controlled by `RELATED_CARD_OPS` at the top of `card_relationship_resolver.gd` — any effect op in that list that has a `card_template` field will have it shown as a card alt-view. If a new op uses `card_template` but isn't in the list, add it.

If the user reports a missing or broken alt-view, check three things:
1. **Resolver coverage (text)** — Is the card's trigger condition field handled in `_resolve_contextual_text()` in `card_relationship_resolver.gd`? If not, add a resolver function that extracts the subtype/attribute and calls `_subtype_count_text()`.
1b. **Resolver coverage (card)** — Does the card's effect op appear in `RELATED_CARD_OPS`? If not, add it so the `card_template` shows as an alt-view card.
2. **Context not passed** — The resolver needs a context dict (`zone`, `deck_cards`, `board_cards`, `hand_cards`) to show counts. If it shows "Synergy: X" instead of "You have N Xs...", the `CardDisplayComponent` isn't receiving context via `set_relationship_context()`. Check where the hover preview is created:
   - `match_screen.gd` — `_add_hover_preview_to_layer()` / `_build_match_relationship_context()`
   - `arena_draft_screen.gd` — `_show_deck_hover_preview()` / `_build_draft_relationship_context()`
   - `deck_editor_screen.gd` — `_build_relationship_context()` (already wired up)

### Common Root Causes

1. **Missing `triggered_abilities`** — Card has `effect_ids` and `rules_text` but no `triggered_abilities` array, so the effect never fires.
2. **Missing equip fields on items** — Item has `keywords`/`rules_text` but lacks `equip_power_bonus`/`equip_health_bonus`/`equip_keywords`.
3. **Effect op not implemented** — The required behaviour needs a new op in `match_timing._apply_effects()`.
4. **Wrong trigger family** — e.g., using `summon` instead of `on_play` for an action card.
5. **Hydration not passing field** — New fields added to the catalog but not copied in `match_screen._hydrate_card()`.
6. **Missing `duration` on "this turn" effects** — `modify_stats` and `grant_keyword` ops are permanent by default. Cards with "this turn" in `rules_text` need `"duration": "end_of_turn"` on the effect descriptor.
7. **Effect op writes to wrong state field** — The op handler exists and fires, but mutates a non-existent or wrong field on the player/card state dictionary. GDScript silently creates new dict keys on assignment, so the value is stored but never read by the rest of the engine. The effect appears to do nothing.
8. **Strict comparison condition excludes boundary case** — A trigger condition uses a strict comparison (e.g., `required_more_health` = strictly >) when the card text implies an inclusive one (e.g., "Otherwise" = not less = >=). At the boundary (equal values), neither branch fires. Fix by using the appropriate inclusive condition (e.g., `required_not_less_health`).

### Key Files to Investigate

- `src/deck/card_catalog.gd` — card definitions
- `src/core/match/match_timing.gd` — trigger matching and effect resolution
- `src/core/match/match_mutations.gd` — state mutation helpers
- `src/core/match/evergreen_rules.gd` — keyword/stat/status helpers
- `src/core/match/extended_mechanic_packs.gd` — custom effects and conditions
- `src/core/match/lane_rules.gd` — lane entry and summon validation
- `src/core/match/persistent_card_rules.gd` — play-from-hand flows (actions, items, supports)
- `src/ui/match_screen.gd` — card hydration (`_hydrate_card`)
- `src/ui/components/card_relationship_resolver.gd` — alt-view synergy text (subtype/attribute counts)

## Step 3: Implement the Fix

1. If a new effect op is needed, add it to `_apply_effects()` in `match_timing.gd`, following the pattern of existing ops. Make it generic/reusable rather than card-specific.
2. If an existing op needs a new optional parameter (e.g., adding `duration` support to `grant_keyword`), extend the op handler in `_apply_effects()` rather than creating a new op. Follow the pattern of similar parameters on other ops (e.g., `modify_stats` already supports `duration`).
3. If the card just needs `triggered_abilities` wired up, update its `_seed()` call in `card_catalog.gd`.
4. If new fields are introduced, ensure they flow through:
   - `_seed()` in `card_catalog.gd`
   - `_build_card()` in `card_catalog.gd`
   - `_hydrate_card()` in `match_screen.gd`
5. If an item needs equip fields, parse the `rules_text` to extract `equip_power_bonus`, `equip_health_bonus`, and `equip_keywords`.
6. If new per-card state is added (e.g., `temporary_keywords`), ensure it is cleared in all cleanup paths:
   - `match_mutations.silence_card()` — silence wipes all granted state
   - `match_mutations.reset_transient_state()` — used when cards change zones
   - `match_turn_loop._clear_temporary_stat_bonuses()` — end-of-turn cleanup (if the state is turn-scoped)

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

Update the card's entry in `development-artifacts/core_set_cards.json` if relevant fields changed. Note: this file tracks card metadata (name, cost, power, health, rarity, rules_text, keywords, effect_ids, equip bonuses, etc.) but does **not** store `triggered_abilities`. So only update it if you changed fields like `rules_text`, `keywords`, `equip_power_bonus`, `equip_health_bonus`, `equip_keywords`, `effect_ids`, etc. If the fix was purely to `triggered_abilities` descriptors (adding `duration`, fixing `target`, etc.), no update is needed here.

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
