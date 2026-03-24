# Claude Learnings

## Tags
`assemble` `attributes` `card-catalog` `card-hydration` `card-state` `cost-reduction` `events` `invade` `match-engine` `neutral` `registry` `target-resolution` `triggers`

## Card Hydration & Attributes

- **Neutral cards have empty `attributes` array after hydration** `[neutral, attributes, registry, card-hydration]`
  The attribute registry marks "neutral" with `kind: "neutral"` (not `"primary"`), so `normalize_attribute_ids` in `deck_rules_registry.gd` filters it out. All neutral cards end up with `attributes: []` in the built card data and after hydration. To detect neutral cards at runtime, check `attributes.is_empty()` rather than `attributes.has("neutral")`.
  _Refs: `data/legends/registries/attribute_class_registry.json:37`, `src/deck/deck_rules_registry.gd:72-82`, `src/deck/card_catalog.gd:73`_

- **Card data flows through three layers: seed → build → hydrate** `[card-catalog, card-hydration, card-state]`
  `_seed()` creates raw dicts. `_build_card()` normalizes them (including filtering attributes via the registry). `_hydrate_card()` in MatchScreen copies built card fields onto lightweight match-state card dicts. The match engine reads fields directly from card dicts — there is no lazy catalog lookup. If a field isn't set during hydration, the engine won't see it.
  _Refs: `src/deck/card_catalog.gd:151`, `src/deck/card_catalog.gd:72`, `src/ui/match_screen.gd:390`_

- **Bootstrap cards are lightweight — most fields come from hydration** `[card-state, card-hydration, match-engine]`
  `match_bootstrap.gd:_build_shuffled_deck` creates cards with only `definition_id`, `instance_id`, zone, and state fields (keywords, damage_marked, etc). Fields like `subtypes`, `attributes`, `triggered_abilities`, `cost`, `power`, `health` are all added by `_hydrate_card`/`_hydrate_all_zones` before the match engine processes them.
  _Refs: `src/core/match/match_bootstrap.gd:162-180`, `src/ui/match_screen.gd:462-479`_

## Assemble Mechanic

- **Assemble distributes ALL chosen effects to Factotums in hand/deck** `[assemble, card-state]`
  Stat buffs and keywords are applied directly to the card dicts. Non-card-targeting effects (damage/heal) must be granted as summon triggered abilities via `grant_triggered_ability` so they fire when those Factotums are later played. The played card itself executes the effect immediately.
  _Refs: `src/core/match/match_timing.gd:3162`_

- **Assemble must NOT buff Factotums already in lane** `[assemble, target-resolution]`
  `_collect_factotums` returns self + hand/deck Factotums. `_collect_factotums_except_self` returns only hand/deck Factotums (excluding the source card), used for `grant_triggered_ability` to avoid infinite summon loops.
  _Refs: `src/core/match/extended_mechanic_packs.gd:1432-1451`_

- **Factotum subtype check is case-sensitive** `[assemble, card-catalog, card-hydration]`
  The catalog stores `"Factotum"` (capitalized) in subtypes. `_card_has_string` does exact string matching. `_collect_factotums` must check both `"Factotum"` and `"factotum"` to handle both hydrated cards (capitalized) and test fixtures (lowercase).
  _Refs: `src/core/match/extended_mechanic_packs.gd:1438`_

## Invade Mechanic

- **Generated gate template must include ALL identity fields** `[invade, card-state, match-engine]`
  `_build_gate_template` feeds into `change_card` → `_apply_identity`, which erases any `IDENTITY_FIELD` not on the template. The original template was missing `cost`, `subtypes`, `attributes`, `grants_immunity`, `innate_statuses`, and `rules_text` — so on each upgrade these fields were silently stripped from the gate card. Any generated card template must be complete.
  _Refs: `src/core/match/extended_mechanic_packs.gd:1389`, `src/core/match/match_mutations.gd:641-647`_

- **`invade_triggered` event must be explicitly emitted** `[invade, events, triggers]`
  The `FAMILY_ON_INVADE` trigger family listens for `"invade_triggered"` events, but `_resolve_invade` was not emitting them. Cards like Keeper of the Gates (`on_invade` family) silently failed to trigger. Event families don't auto-emit — the resolving function must append the event to its returned array.
  _Refs: `src/core/match/extended_mechanic_packs.gd:1241-1265`, `src/core/match/match_timing.gd:194`_

- **Daedra cost reduction uses the `card_cost_reduction_auras` system** `[invade, cost-reduction, match-engine]`
  The level 3+ gate cost reduction for Daedra is implemented by appending an aura entry to `match_state["card_cost_reduction_auras"]` with `filter_subtype: "Daedra"`. The aura should only be added once (at the exact transition to level 3), not on every subsequent upgrade.
  _Refs: `src/core/match/extended_mechanic_packs.gd:1277-1282`_

## Match Engine Ops & Targets

- **`choose_two` reads from `choices` key, not `ability_options`** `[match-engine, card-catalog]`
  The card catalog stores options under `"choices"` in the effect dict. The `choose_two` op was originally reading from `"ability_options"`, causing Assembled Titan to silently do nothing when played.
  _Refs: `src/core/match/match_timing.gd:6724`_

- **`grant_triggered_ability` supports stacking via `assemble_label`** `[match-engine, assemble, triggers]`
  When the same `assemble_label` is granted twice (e.g. via Yagrum's Workshop doubling), the amount in the existing trigger is incremented rather than adding a duplicate trigger. The `text_template` with `{amount}` placeholder updates `rules_text` dynamically.
  _Refs: `src/core/match/match_timing.gd:3162-3195`_

- **`_apply_identity` erases fields not present in the template** `[card-state, match-engine]`
  `IDENTITY_FIELDS` includes `attributes`, `subtypes`, etc. When `_apply_identity` is called (for generated/transformed cards), any IDENTITY_FIELD not on the template dict gets erased from the card. This is intentional but can be surprising if a template is incomplete.
  _Refs: `src/core/match/match_mutations.gd:641-647`_
