# Claude Learnings

## Tags
`ai` `anchors` `assemble` `attributes` `augments` `auras` `boons` `boss-config` `card-catalog` `card-hydration` `card-state` `case-sensitivity` `cost-reduction` `death-checks` `delegation` `end-of-turn` `events` `generated-cards` `identity` `invade` `lane-effects` `lane-resolution` `match-engine` `match-screen` `multi-target` `neutral` `passives` `player-state` `prophecy` `randomness` `registry` `runes` `shouts` `stat-helpers` `summon-path` `supports` `target-resolution` `test-match-config` `testing` `triggers` `ui`

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

- **Re-hydration erases augment stat bonuses — keywords survive but power/health don't** `[card-hydration, augments, match-screen]`
  `_hydrate_card` unconditionally overwrites `card["power"]` and `card["health"]` from the definition's base values. Augment power/health bonuses applied before hydration are lost. Keywords survive because hydration only sets them from the definition if present, rather than clearing the array. Any code path that re-hydrates cards (e.g., `_finalize_mulligan`, AI mulligan) must re-apply augments afterward.
  _Refs: `src/ui/match_screen.gd:447-448`, `src/ui/match_screen.gd:2520-2523`_

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

## Boons & Adventure Mode

- **Rune-break boon choice must explicitly open prophecy window** `[boons, prophecy, match-engine]`
  The `draw_one_shuffle_rest` handler in `resolve_pending_top_deck_multi_choice` moves the chosen card to hand and emits an `EVENT_CARD_DRAWN` event with `allow_prophecy_interrupt: true`, but this flag is just event metadata — nothing consumes it. The handler must explicitly call `_can_open_prophecy_window()` and `_open_prophecy_window()` after drawing, the same pattern used in `draw_cards()`.
  _Refs: `src/core/match/match_timing.gd:1085-1087`_

- **Boons must be applied AFTER health overrides in boss match setup** `[boons, boss-config, runes]`
  `fortified_spirit` boon recalculates rune thresholds based on `player["health"]`. In `start_arena_boss_match`, if boons are applied before boss/player health overrides, `fortified_spirit` reads the default health (30) instead of the overridden value, producing wrong thresholds. Always apply health overrides first, then boons.
  _Refs: `src/ui/match_screen.gd:323-339`_

- **Adventure boons must be restored on match resume** `[boons, match-screen, ui]`
  `_launch_match()` sets `match_screen._adventure_boons` before starting, but `_resume_match()` creates a new MatchScreen without setting this field. Boons are correctly persisted in `run.json` via `save_run()`/`load_run()`, but the resume path must also pass `_run_manager.active_boons.duplicate()` to the recreated match screen.
  _Refs: `src/ui/adventure/adventure_controller.gd:219`_

- **`set_anchors_preset(PRESET_CENTER)` does NOT center a Control** `[anchors, ui]`
  `PRESET_CENTER` sets all four anchors to 0.5 with zero offsets, placing the Control's top-left corner at the parent's center. The Control then grows rightward/downward from that point. For true centering, set anchors to 0.5 AND set `grow_horizontal = GROW_DIRECTION_BOTH` and `grow_vertical = GROW_DIRECTION_BOTH` so the Control expands symmetrically from the center point. Manual repositioning via `resized` callbacks is fragile and may not fire.
  _Refs: `src/ui/match/active_boons_overlay.gd`, `src/ui/adventure/boon_node_overlay.gd`_

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

- **Effect-summon paths must call `_check_summon_abilities` on the summoned creature** `[triggers, match-engine, registry]`
  When creatures are summoned by effects (not played from hand), `_check_summon_abilities` must be called to queue targeting summon abilities as `pending_summon_effect_targets`. Without this, abilities like "Summon: Battle an enemy creature" silently don't fire. The `summon_from_effect` op and `_run_budget_summon_loop` already do this; other summon paths (`summon_copy`, `summon_random_from_catalog`, `sacrifice_and_resummon`, `fill_lane_with`, etc.) needed it added.
  _Refs: `src/core/match/match_timing.gd:1593-1636`, `src/core/match/extended_mechanic_packs.gd:507`_

- **Effect handler key names must match card catalog key names — mismatches silently use defaults** `[match-engine, card-catalog, delegation]`
  Effect handlers read parameters via `effect.get("key", default)`. If the card catalog uses a different key name (e.g., `"power"` vs `"attack_power"`, `"left_lane"` vs `"lane_bonuses"`, `"subtype"` vs `"filter_subtype"`), the handler silently uses its default value. This is a systemic pattern — always cross-reference effect keys in catalog data against the handler's `effect.get()` calls when adding new ops or cards.
  _Refs: `src/core/match/match_timing.gd`, `src/deck/card_catalog.gd`_

- **`get_health()` returns max health, `get_remaining_health()` returns current health after damage** `[stat-helpers, match-engine, target-resolution]`
  Target modes that compare against "self health" (e.g., `enemy_creature_less_power_than_self_health`) must use `get_remaining_health()` to account for damage taken. Using `get_health()` (which ignores `damage_marked`) makes the comparison too generous — the pool of valid targets doesn't shrink as the creature takes damage. This caused Mulaamnir's slay chain to kill all enemies instead of narrowing.
  _Refs: `src/core/match/match_timing.gd:454-457`, `src/core/match/evergreen_rules.gd:432-457`_

## Delegation & Filter Forwarding

- **Delegation ops often drop nested `filter` dict parameters** `[delegation, match-engine, card-catalog]`
  A recurring pattern: an op like `summon_random_from_collection` delegates to `summon_random_from_catalog` but only forwards top-level keys (e.g., `filter_subtype`) while ignoring the nested `filter` dict that card data actually provides (with `subtype`, `min_cost`, `max_cost`). Always check that delegation layers forward ALL keys from the source filter dict, not just a hardcoded subset.
  _Refs: `src/core/match/match_timing.gd:7102-7117`, `src/core/match/extended_mechanic_packs.gd:428-470`_

- **Effect handlers must read `effect.get("source")` for the keyword/damage source** `[delegation, target-resolution, match-engine]`
  Multiple handlers hardcode `trigger.get("source_instance_id")` as the source card, which is always the card that owns the triggered ability (e.g., the action card). When the effect dict specifies `"source": "event_target"` or `"damage_source": "wielder"`, the handler must resolve the actual source from the effect dict. The trigger source and the effect source are often different cards (action vs. destroyed creature, item vs. wielding creature).
  _Refs: `src/core/match/match_timing.gd:3612`, `src/core/match/match_timing.gd:4487`_

## Identity & Card Mutations

- **`change_card` overwrites cost — preserve it when the identity change shouldn't affect cost** `[identity, cost-reduction, match-engine]`
  `change_card` → `_apply_identity` overwrites ALL `IDENTITY_FIELDS` including `cost`. If a card's cost was overridden (e.g., set to 0 by Paarthurnax), the override is lost after `change_card`. For shout upgrades and similar identity changes that shouldn't affect cost, save and restore cost around the `change_card` call.
  _Refs: `src/core/match/match_mutations.gd:499-512`, `src/core/match/extended_mechanic_packs.gd:1295-1300`_

- **`art_path` is NOT in `IDENTITY_FIELDS` — must be copied manually after identity changes** `[identity, generated-cards, ui]`
  `_apply_identity` only copies fields in `IDENTITY_FIELDS`. `art_path` is not one of them, so it's neither copied from the template nor preserved on the card. When a shout upgrades and gets a new `definition_id` (e.g., `fire_breath_2`), the UI fallback looks for a non-existent art file. The template's `art_path` must be explicitly copied to the card after `change_card`.
  _Refs: `src/core/match/match_mutations.gd:19-25`, `src/core/match/match_mutations.gd:641-647`_

- **`build_generated_card` should set `art_path` from `definition_id` as fallback** `[generated-cards, ui, match-engine]`
  Generated cards built from catalog seed templates lack `art_path` because seeds don't include it. Without an explicit `art_path`, the UI falls back to `definition_id`-based path resolution, which works only if `definition_id` is set. Adding `art_path = "res://assets/images/cards/" + definition_id + ".png"` in `build_generated_card` when absent prevents placeholder art.
  _Refs: `src/core/match/match_mutations.gd:449-450`_

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

- **`summon_from_effect` lane resolution supports sentinel values that must be resolved at runtime** `[lane-resolution, match-engine, card-catalog]`
  The lane parameter in summon ops (`summon_from_effect`, `fill_lane_with`, `summon_copies_to_lane`) uses sentinel strings that the handler must resolve: `"chosen"` → `event.lane_id` (player selected), `"same"` → event lane, `"other"`/`"other_lane"` → opposite lane, `"same_as_target"` → target creature's lane, `"same_as_marked_target"` → marked creature's lane, `"random"` → random lane with open slots via `_deterministic_index`, `"support"` → place in support zone instead of a lane, `"both"` → all lanes. The fallback chain is `effect.lane_id` → `effect.target_lane_id` → `effect.lane` → `event.lane_id`. Unrecognized sentinels pass through as literal lane IDs and silently fail.
  _Refs: `src/core/match/match_timing.gd:3938-3962`_

- **`summon_from_effect` supports `count_source` for multi-summon** `[match-engine, lane-resolution]`
  The `count_source` field on `summon_from_effect` effects multiplies the summon count via `_resolve_count_multiplier`. Without this, the op summons exactly one creature per lane per player. Cards like Grave Grasp ("summon a 1/1 Skeleton for each enemy in the lane") need `count_source: "enemies_in_target_lane"` to summon the correct number.
  _Refs: `src/core/match/match_timing.gd:4116-4129`_

- **`"damage"` op in extended_mechanic_packs doesn't use `_resolve_count_multiplier`** `[match-engine, supports, card-catalog]`
  The `"damage"` (player damage) op handler in `extended_mechanic_packs.gd` only reads the base `amount` from the effect dict. Unlike `"deal_damage"` in `match_timing.gd` which multiplies by `_resolve_count_multiplier`, the `"damage"` handler needs its own count multiplier. Cards like Rimmen Siege Weapons ("each friendly creature deals 1 damage") use `count_source: "friendly_creatures"` which is ignored without this.
  _Refs: `src/core/match/extended_mechanic_packs.gd:398-410`_

- **Unimplemented `match_role` values in trigger descriptors silently prevent matching** `[triggers, match-engine, card-catalog]`
  `_matches_trigger_role` uses a match statement that returns `false` at the end for any unrecognized role string. A new match_role value in card data (like `"friendly_target"`) will silently prevent the trigger from ever firing. When adding a new match_role to card data, a corresponding case must be added to `_matches_trigger_role`. This is analogous to the aura condition and passive ability silent-ignore patterns.
  _Refs: `src/core/match/match_timing.gd:3332-3375`_

- **Trigger condition key mismatches silently use defaults — same pattern as effect handler keys** `[triggers, card-catalog, match-engine]`
  Trigger condition specs (like `required_friendly_attribute_count`) are read via `spec.get("key", default)`. If the card data uses a different key than the engine expects (e.g., `"min"` vs `"min_count"`), the default is used silently. This caused Pact Oathman's Agility check to always pass (min defaulted to 0). Always cross-reference condition spec keys in card data against the engine's `.get()` calls.
  _Refs: `src/core/match/match_timing.gd:3429-3432`, `src/deck/card_catalog.gd:1049`_

- **`_summon_ability_conditions_met` must delegate to full condition checkers** `[triggers, summon-path, match-engine]`
  Targeted summon abilities (those with `target_mode`) go through `_check_summon_abilities` → `_summon_ability_conditions_met`, not through the normal trigger registry. This function must delegate to `_matches_conditions` + `ExtendedMechanicPacks.matches_additional_conditions` via a synthetic trigger/event dict, otherwise any condition only handled in those functions is silently bypassed for summon abilities. Previously caused plot_bonus, exalt_cost, required_friendly_creature_min_power, and required_creature_in_each_lane to be ignored.
  _Refs: `src/core/match/match_timing.gd:1722-1753`_

- **Hand-played creatures use UI-side targeting, effect-summoned creatures use engine-side targeting** `[summon-path, match-screen, triggers]`
  Two separate code paths handle summon target_mode abilities: (1) `_check_summon_target_mode` in match_screen.gd for hand-played creatures — called after `LaneRules.summon_from_hand`, (2) `_check_summon_abilities` in match_timing.gd for effect-summoned creatures. Both must check conditions before opening targeting mode. The UI path calls `MatchTiming._summon_ability_conditions_met` to filter abilities.
  _Refs: `src/ui/match_screen.gd:7910-7943`, `src/core/match/match_timing.gd:1667-1720`_

- **"Enters a lane" needs both summon and on_move triggers; "when X moves" needs only on_move** `[triggers, card-catalog, events]`
  The `on_move` trigger family fires on `"card_moved"` events (lane-to-lane moves only), not on `EVENT_CREATURE_SUMMONED`. Cards with "enters a lane" phrasing need BOTH a `summon` trigger (fires on initial play) and an `on_move` trigger (fires on lane switches). Cards with "when X moves" phrasing correctly need only `on_move`.
  _Refs: `src/core/match/match_timing.gd:152`, `src/deck/card_catalog.gd:1671`_

## Multi-Target & Dual-Target Actions

- **Multi-target actions use sequential `pending_summon_effect_targets` collection with `_multi_target_ids`** `[multi-target, match-engine, target-resolution]`
  Actions needing 2-3 targets (Mute, Fingers of the Mountain) use `target_mode: "two_creatures"/"three_creatures"` on their on_play trigger. These are skipped from the trigger registry. `_check_action_multi_target_abilities` queues pending entries, `_resolve_multi_target_selection` collects targets one at a time into `card._multi_target_ids`, and fires effects when all are collected. Effects use `chosen_target_1`/`chosen_target_2`/`chosen_target_3` which resolve from `trigger._chosen_target_ids[N-1]`.
  _Refs: `src/core/match/match_timing.gd:1577-1620`, `src/core/match/match_timing.gd:1226-1272`_

- **Dual-target actions use `secondary_target_mode` with `primary_target`/`secondary_target` resolution** `[multi-target, target-resolution, match-engine]`
  Actions that need two different target types (e.g., Whispering Claw Strike: enemy + friendly) use `target_mode` for the first pick and `secondary_target_mode` for the second. `resolve_targeted_effect` stores the first pick as `_primary_target_id` on the card and queues a secondary pending entry. Effects reference `primary_target` (resolves from `trigger._primary_target_id`) and `secondary_target` (resolves from `trigger._chosen_target_id`). On_play triggers with `secondary_target_mode` must also be skipped from the registry.
  _Refs: `src/core/match/match_timing.gd:632-647`, `src/core/match/match_timing.gd:7699-7710`_

- **`_action_needs_explicit_target` controls whether the UI requires an upfront target before playing an action** `[multi-target, ui, match-screen]`
  Actions with `target_mode` on their triggers normally require explicit target selection before play. Multi-target modes (`two_creatures`, `three_creatures`) and dual-target modes (`secondary_target_mode` present) must be excluded from this check, since they collect targets via the pending system after the action is played without a target.
  _Refs: `src/ui/match_screen.gd:5644-5663`_

- **AI enumerator builds action combos from `requirements` flags — `choose_lane_and_owner` needs lane+player but NOT card target** `[ai, target-resolution, match-engine]`
  `_expand_target_parameter_sets` multiplies parameter sets by `needs_player_target`, `needs_card_target`, and `needs_lane_id`. The `choose_lane_and_owner` target mode should set `needs_lane_id` but NOT `needs_card_target`, since the action targets a lane+owner pair, not a creature on board. Setting both incorrectly causes the AI to enumerate every creature × lane × player combination.
  _Refs: `src/ai/match_action_enumerator.gd:790-870`_

- **AI enumerator `_expand_target_parameter_sets` silently passes all targets for unhandled target modes** `[ai, target-resolution, match-engine]`
  The if/elif chain in `_expand_target_parameter_sets` handles specific `action_target_mode` values (e.g., `enemy_creature`, `wounded_enemy_creature`). Any mode not explicitly listed falls through with zero filtering, causing the AI to consider ALL lane creatures as valid targets. When adding a new `action_target_mode` to a card, a corresponding filter case must also be added to the AI enumerator.
  _Refs: `src/ai/match_action_enumerator.gd:826-870`_

## Match Screen & Modes

- **`_arena_mode` flag on MatchScreen suppresses normal return behavior** `[match-screen, ui]`
  Setting `match_screen._arena_mode = true` prevents the match screen from emitting `return_to_main_menu_requested` on its own after match end. Instead, the controller (arena or adventure) handles the signal and routes to the appropriate post-match screen. This flag is reusable for any game mode that needs custom post-match flow.
  _Refs: `src/ui/match_screen.gd:108`_

- **`boss_health` is the key for AI health override in `start_arena_boss_match`** `[boss-config, match-screen, match-engine]`
  The `boss_config` dict passed to `start_arena_boss_match` uses `"boss_health"` (not `"starting_health"` or `"enemy_health"`) to override AI player HP. The boss is always `PLAYER_ORDER[0]` which is `"player_2"` (the AI). The health override is applied after `MatchBootstrap.create_standard_match` and before hydration.
  _Refs: `src/ui/match_screen.gd:314-319`_

## Relationship & Alt-View System

- **`RELATED_CARD_OPS` only works for ops that embed a `card_template`** `[ui, card-catalog]`
  The `CardRelationshipResolver` scans effect dicts for ops in `RELATED_CARD_OPS` and extracts `card_template` to show as alt-views. Ops that use random selection (`generate_random_to_hand`, `summon_random_from_catalog`) don't embed a `card_template` — they only have `filter` dicts. Adding them to the list has no effect. Only ops with a concrete, predetermined card definition benefit from inclusion.
  _Refs: `src/ui/components/card_relationship_resolver.gd:10`, `src/ui/components/card_relationship_resolver.gd:46-48`_

## Self Cost Reduction

- **`self_cost_reduction` has two data formats — both must be handled** `[cost-reduction, card-catalog, match-engine]`
  Card data uses two formats for `self_cost_reduction`: (1) canonical `{"per": "source_name", "amount": N}` / `{"type": "source_name", "amount": N}`, and (2) single-key `{"per_friendly_wounded": 3}` where the key is the source and the value is the per-unit reduction. Both `persistent_card_rules.gd:get_effective_play_cost` and `match_timing.gd:play_action_from_hand` must handle both formats. The single-key format is detected by iterating keys and finding one that isn't `amount`/`per`/`type`/`source`.
  _Refs: `src/core/match/persistent_card_rules.gd:297-310`, `src/core/match/match_timing.gd:2162-2173`_

- **New `self_cost_reduction` sources need handlers in TWO places** `[cost-reduction, match-engine]`
  `persistent_card_rules.gd:get_effective_play_cost` handles cost for creatures/items/supports, while `match_timing.gd:play_action_from_hand` handles cost for actions. Both have independent `self_cost_reduction` parsing — adding a new source to one without the other means the reduction only works for half the card types.
  _Refs: `src/core/match/persistent_card_rules.gd:297-310`, `src/core/match/match_timing.gd:2162-2173`_

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

## Shout Mechanic

- **Shout upgrades use `change_card` with level templates — cost and art_path need manual preservation** `[shouts, identity, cost-reduction]`
  `_resolve_shout_upgrade` and `_resolve_shout_upgrade_for_card` both call `MatchMutations.change_card` with the next level's template. This overwrites `cost` (losing Paarthurnax's cost=0 override) and doesn't copy `art_path` (not in IDENTITY_FIELDS). Both functions must save/restore cost and copy `art_path` from the enriched template after `change_card`.
  _Refs: `src/core/match/extended_mechanic_packs.gd:1268-1330`, `src/core/match/extended_mechanic_packs.gd:1925-1950`_

- **Only Call Dragon upgrades ALL shouts — other shouts upgrade same-chain only** `[shouts, card-catalog, match-engine]`
  The `upgrade_shout` op accepts a `scope` field. When `scope: "all"`, it upgrades every shout the player owns (excluding the source card to prevent self-double-upgrade). Without `scope: "all"`, it only upgrades copies of the same `shout_chain_id`. Call Dragon is currently the only card that uses `scope: "all"`.
  _Refs: `src/core/match/extended_mechanic_packs.gd:389-391`, `src/deck/card_catalog.gd:1627`_

- **`summon_random_from_catalog` now supports `min_cost` filter** `[match-engine, card-catalog]`
  In addition to `max_cost` and `exact_cost`, the filter dict supports `min_cost` for minimum cost filtering. Used by Call Dragon's shout levels to summon Dragons within specific cost ranges (e.g., 6-8, 8-10, exactly 12).
  _Refs: `src/core/match/extended_mechanic_packs.gd:437-452`_

## Supports

- **Support Last Gasp doesn't fire via normal event path** `[supports, triggers, events]`
  When a support runs out of uses, `activate_support` discards it via `MatchMutations.discard_card`, which emits `card_moved` (support → discard). But `FAMILY_LAST_GASP` listens for `EVENT_CREATURE_DESTROYED`, which is never emitted for supports. Last Gasp triggers on supports must be manually resolved in the exhaustion path using the fake trigger pattern (build a trigger dict + fake creature_destroyed event, then call `_build_trigger_resolution` and `_apply_effects`).
  _Refs: `src/core/match/persistent_card_rules.gd:194-215`, `src/core/match/match_timing.gd:4180-4195`_

## AI Turn Processing

- **Rune breaks during AI turn can stall the AI indefinitely via pending prophecy** `[ai, runes, match-screen, testing]`
  When the AI attacks and breaks a player rune, a prophecy window opens for the local player. `_local_player_has_pending_interrupt()` returns true, which causes `_process_local_match_ai_turn` to pause the AI queue. If nothing resolves the prophecy (e.g., in a headless test), the AI turn never ends and `active_player_id` never returns to the human. Test scenarios that don't specifically test prophecy should clear `rune_thresholds` for the local player to prevent unintended prophecy windows.
  _Refs: `src/ui/match_screen.gd:747-749`, `src/ui/match_screen.gd:7012-7013`_

- **`_spell_reveal_state` blocks AI turn processing until tween callback clears it** `[ai, match-screen, ui]`
  `_process_local_match_ai_turn` returns early whenever `_spell_reveal_state` is non-empty. This dict is set by animation functions (`_animate_enemy_creature_play`, `_animate_enemy_spell_reveal`, etc.) and cleared by `_dismiss_spell_reveal()` in a tween callback ~700ms later. If the tween callback never fires (e.g., node invalidation), the AI turn stalls permanently. Debugging AI stalls should check whether `_spell_reveal_state` is being cleared.
  _Refs: `src/ui/match_screen.gd:732-733`, `src/ui/match_screen.gd:3963-3992`, `src/ui/match_screen.gd:3538-3545`_

- **`_apply_lane_card_float_effect` overrides `clip_contents = false` on ready creatures** `[ui, match-screen, testing]`
  `_build_card_button` sets `clip_contents = surface == "lane"` for lane cards, but `_apply_lane_card_float_effect` later sets `clip_contents = false` on creatures with "ready" readiness state to allow the floating shadow effect to extend outside the button. Valid target glow effects similarly override clip_contents. Tests checking `clip_contents` must use non-ready creatures to get reliable results.
  _Refs: `src/ui/match_screen.gd:4042`, `src/ui/match_screen.gd:6595`_

## Debug Scenarios

- **`_set_player_health` in match_debug_scenarios adjusts rune thresholds to match health** `[runes, player-state, testing]`
  `_set_player_health` doesn't just set health — it also rebuilds `rune_thresholds` to only include thresholds at or below the new health value. A player at 12 health gets `rune_thresholds = [10, 5]`, not the full `[25, 20, 15, 10, 5]`. This means AI attacks on a player with reduced health may break runes at thresholds you don't expect.
  _Refs: `src/ui/match_debug_scenarios.gd:401-407`_

## Lane Effects & Test Match Config

- **Pre-placed creatures in test match configs lack `lane_id` and `slot_index`** `[test-match-config, lane-effects, testing]`
  `_build_lanes_with_creatures` in `test_match_config.gd` places creatures directly into `player_slots` without setting `lane_id` or `slot_index` on the card dicts. In contrast, `lane_rules.gd:summon_from_hand` sets both fields on summon. Lane effect handlers that check `card.get("lane_id", "")` (like heist, liquid courage, etc.) silently fail for pre-placed creatures because `lane_id` is empty string. The fix: iterate all pre-placed creatures in `_build_lanes_with_creatures` and set `lane_id` and `slot_index` after building `player_slots`.
  _Refs: `data/test_match_config.gd:346-358`, `src/core/match/lane_rules.gd:319-320`_
