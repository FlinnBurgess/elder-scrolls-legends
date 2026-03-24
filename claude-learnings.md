# Claude Learnings

## Tags
`assemble` `attributes` `auras` `card-catalog` `card-hydration` `card-state` `case-sensitivity` `cost-reduction` `death-checks` `end-of-turn` `events` `generated-cards` `invade` `match-engine` `neutral` `passives` `player-state` `randomness` `registry` `stat-helpers` `supports` `target-resolution` `triggers` `ui`

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

## Auras & Passives

- **Unknown aura conditions silently return false** `[auras, card-catalog, match-engine]`
  `_evaluate_aura_condition` uses a match statement and returns `false` at the end for any unrecognized condition string. This means a typo or new condition value in card data will silently disable the aura with no error. Always cross-reference condition strings in card data against the match cases in `_evaluate_aura_condition`.
  _Refs: `src/core/match/match_timing.gd:2469-2547`_

- **Count-based auras use `per_count: true` with a count condition** `[auras, match-engine]`
  Auras like Swims-at-Night's "+1/+1 for each 0-cost card in hand" use `power`/`health` fields (the per-unit bonus) with `per_count: true`. The condition is passed as a dict with `type` for the evaluator. `_evaluate_aura_condition` returns true/false, then `_get_aura_condition_count` returns the multiplier count. Both functions must handle the same condition type.
  _Refs: `src/core/match/match_timing.gd:2387-2391`, `src/core/match/match_timing.gd:2550-2585`_

- **Unhandled passive ability types are silently ignored** `[passives, card-catalog, match-engine]`
  Passive abilities declared in card data (`passive_abilities` array) are only effective if engine code explicitly checks for them. There's no centralized dispatcher — each passive type has bespoke handling scattered across match_timing.gd, persistent_card_rules.gd, match_combat.gd, and evergreen_rules.gd. A new passive type with no handler does nothing.

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

- **`_card_has_string` is case-sensitive — subtypes must match catalog casing** `[invade, case-sensitivity, triggers]`
  `_card_has_string` uses exact `str(value) == expected` comparison. The catalog stores subtypes capitalized (e.g. `"Daedra"`). Trigger filters like `required_event_source_subtype` must use the same casing. Test fixtures should also use capitalized subtypes to match real card data.
  _Refs: `src/core/match/extended_mechanic_packs.gd:1601-1607`_

- **Match-state cost reduction auras must be read by `_get_aura_cost_reduction`** `[invade, cost-reduction, match-engine]`
  `_get_aura_cost_reduction` (in both `persistent_card_rules.gd` and `match_timing.gd`) only checked per-card `cost_reduction_aura` dicts on lane/support cards. Match-state-level auras stored in `match_state["card_cost_reduction_auras"]` (used by invade gate and `apply_cost_reduction_aura` op) were never read. Both implementations must also iterate the match-state array and check `filter_subtype` against card subtypes.
  _Refs: `src/core/match/persistent_card_rules.gd:309-336`, `src/core/match/match_timing.gd:7908-7933`_

- **Gate level must be capped at 5** `[invade, match-engine]`
  The wiki defines 5 gate levels. Without a cap, repeated invades increment `gate_level` past 5, causing `keyword_count = gate_level - 3` to grant more than 2 keywords. Cap in `_resolve_invade` (level increment), `_build_gate_template` (template generation), and `_resolve_gate_buff` (keyword count clamped to 0-2).
  _Refs: `src/core/match/extended_mechanic_packs.gd:1267`, `src/core/match/extended_mechanic_packs.gd:1408`, `src/core/match/extended_mechanic_packs.gd:1308`_

- **Trigger descriptor conditions require explicit engine handling** `[invade, triggers, player-state]`
  Catalog trigger descriptors can declare conditions like `invaded_this_turn: true`, but these are inert unless `matches_additional_conditions` (or `_matches_conditions`) explicitly checks for them. The engine has no generic condition dispatch — each new condition key needs a bespoke check added. The `invaded_this_turn` condition requires tracking `invades_this_turn` on the player state (incremented in `observe_event` on `invade_triggered` events, reset in `reset_turn_state`).
  _Refs: `src/core/match/extended_mechanic_packs.gd:128-131`, `src/core/match/extended_mechanic_packs.gd:60-61`, `src/core/match/extended_mechanic_packs.gd:76`_

- **`on_invade` triggers must be guarded against infinite recursion** `[invade, triggers, match-engine]`
  Keeper of the Gates' `on_invade` family trigger invokes another invade, which emits another `invade_triggered` event into the timing queue, causing an infinite loop. The fix: `_resolve_invade` tags events with `from_on_invade: true` when the invoking trigger's family is `on_invade`, and `matches_additional_conditions` blocks `on_invade` triggers from matching events with that flag. This allows one "invade again" but prevents the chain from continuing.
  _Refs: `src/core/match/extended_mechanic_packs.gd:1253-1262`, `src/core/match/extended_mechanic_packs.gd:151-153`_

- **Generated cards need `art_path` for correct card art** `[invade, generated-cards, ui]`
  The UI resolves card art by checking `art_path`/`art_resource_path` keys first, then falling back to `"res://assets/images/cards/" + definition_id + ".png"`. Generated cards with a `definition_id` that differs from the catalog card's ID (e.g. `"generated_oblivion_gate"` vs `"joo_neu_oblivion_gate"`) must include an explicit `art_path` in their template, or they'll show the placeholder.
  _Refs: `src/ui/components/CardDisplayComponent.gd:715-732`_

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

- **`choose_one` op supports `repeat` for multiple sequential choices** `[match-engine, triggers]`
  Cards like Invasion Party ("Choose three times: X or Y") use `{"op": "choose_one", "choices": [...], "repeat": 3}`. The handler must create `repeat` number of pending player choices in `pending_player_choices`. Each is resolved one at a time via `resolve_pending_player_choice`.
  _Refs: `src/core/match/match_timing.gd:4481-4504`_

- **`all_friendly_oblivion_gates` target must search lanes by rules_tag** `[target-resolution, invade]`
  Oblivion Gates are creatures in lanes (specifically the shadow lane), not supports. The target resolution must search lane slots for cards with `rules_tags` containing `"oblivion_gate"`, not the support zone with a subtype check.
  _Refs: `src/core/match/match_timing.gd:7284-7292`_

- **`summon_random_from_catalog` supports `exact_cost` filter** `[match-engine, card-catalog]`
  In addition to `max_cost`, the filter dict can include `exact_cost` to match cards with a specific cost. Used by `summon_random_daedra_by_gate_level` to summon a Daedra whose cost equals the gate's current level.
  _Refs: `src/core/match/extended_mechanic_packs.gd:393-407`_

- **Use `_deterministic_index` for all random selections** `[match-engine, randomness]`
  The engine uses `_deterministic_index(match_state, context_id, pool_size)` for seeded randomness based on `rng_seed`, `turn_number`, and a unique context string. Fixed-order iteration of pools (like keyword assignment) produces the same result every time. Any "random" selection must go through `_deterministic_index` with a unique per-card context ID.
  _Refs: `src/core/match/match_timing.gd:7504-7513`, `src/core/match/extended_mechanic_packs.gd:1464-1473`_

- **`all_friendly` vs `all_other_friendly` — self-inclusion depends on the variant** `[target-resolution, match-engine]`
  In `_resolve_card_targets_by_name`, `all_friendly` includes the source card while `all_other_friendly` excludes it. The same pattern applies to `all_friendly_in_lane` / `other_friendly_in_lane` and `all_creatures` / `all_other_creatures`. Card data must use the correct variant matching its rules text — cards saying "other" need the `other_` prefix. The aura resolution path (line ~2663) already handles this correctly with a separate `target_filter` check.
  _Refs: `src/core/match/match_timing.gd:7311-7323`, `src/core/match/match_timing.gd:7290-7302`_

- **Triggers with `target_mode` are silently skipped unless their family is handled** `[triggers, registry, match-engine]`
  Two chokepoints gate triggers with `target_mode`: (1) `_append_card_triggers` excludes them from the registry unless family is activate, on_play, or a non-summon/wax/wane family, (2) `_trigger_matches_event` must inject a target — activate/on_play get it from the event, all other families auto-pick a random valid target via `get_valid_targets_for_mode`. Summon/wax/wane are excluded because they have a dedicated `pending_summon_effect_targets` resolution path. If a new family needs `target_mode`, it works automatically through the auto-resolve path.
  _Refs: `src/core/match/match_timing.gd:2840-2846`, `src/core/match/match_timing.gd:2886-2912`_

- **`end_of_turn` triggers with `target_mode` need the pending turn trigger target system** `[end-of-turn, triggers, target-resolution, match-engine]`
  The auto-resolve path for `target_mode` picks a random valid target, which is wrong for player-facing "deal X damage" effects that should prompt an aiming phase. `end_of_turn` must be added to the registry skip list (alongside summon/wax/wane) in `_append_card_triggers`, and targeted end_of_turn triggers must be queued via `queue_turn_trigger_targets` → `_queue_end_of_turn_trigger_targets` before the turn actually ends. The UI defers `MatchTurnLoop.end_turn` until all pending targets are resolved; the AI uses `_end_of_turn_targets_queued` flag to prevent re-queuing.
  _Refs: `src/core/match/match_timing.gd:2894`, `src/core/match/match_timing.gd:1343-1391`, `src/ui/match_screen.gd:1150-1178`, `src/ai/match_action_executor.gd:23-37`_

- **`deal_damage` op handles creature-or-player duality automatically** `[match-engine, target-resolution]`
  When `target: "chosen_target"` resolves to no card targets (because the player chose a player target), `deal_damage` falls back to player damage using `_chosen_target_player_id` from the trigger dict. This makes it the correct op for "Deal X damage" effects where the player picks any target — use `target_mode: "creature_or_player"` with `op: "deal_damage"` and `target: "chosen_target"`.
  _Refs: `src/core/match/match_timing.gd:3487-3503`_

## Stat Helpers & Death Checks

- **Always use EvergreenRules helpers for gameplay stat calculations** `[stat-helpers, match-engine]`
  `get_power()`, `get_health()`, and `get_remaining_health()` include all bonuses (power_bonus, health_bonus, aura bonuses, equip bonuses) and damage. Raw `card.get("power")` / `card.get("health")` only return the base value. Use raw access only for initialization, serialization, or template construction — never for damage amounts, heal calculations, stat comparisons, or filter checks.
  _Refs: `src/core/match/evergreen_rules.gd:432-457`_

- **Death checks must use `get_remaining_health()`, not raw health** `[death-checks, stat-helpers, match-engine]`
  Damage is tracked in `damage_marked`, not subtracted from `health`. Checking `int(card.get("health", 0)) <= 0` for creature death is always wrong — it checks base health which is rarely 0. Use `EvergreenRules.get_remaining_health(card) <= 0` which computes `get_health() - damage_marked`.
  _Refs: `src/core/match/evergreen_rules.gd:432-433`_

- **UI cost display must handle both increases and decreases** `[ui, cost-reduction, match-engine]`
  The `_effective_cost` display field must be set whenever effective cost differs from base cost (`!=`), not just when reduced (`<`). Cost floors like Bedeviling Scamp's `min_card_cost` passive increase effective cost for cheap cards, and this must be visible in hand.
  _Refs: `src/ui/match_screen.gd:4549-4553`_

## Supports

- **Support Last Gasp doesn't fire via normal event path** `[supports, triggers, events]`
  When a support runs out of uses, `activate_support` discards it via `MatchMutations.discard_card`, which emits `card_moved` (support → discard). But `FAMILY_LAST_GASP` listens for `EVENT_CREATURE_DESTROYED`, which is never emitted for supports. Last Gasp triggers on supports must be manually resolved in the exhaustion path using the fake trigger pattern (build a trigger dict + fake creature_destroyed event, then call `_build_trigger_resolution` and `_apply_effects`).
  _Refs: `src/core/match/persistent_card_rules.gd:194-215`, `src/core/match/match_timing.gd:4180-4195`_
