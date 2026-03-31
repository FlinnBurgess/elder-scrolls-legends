---
name: fix-card-effect
description: Investigate and fix a card whose in-game effect is not working as described.
---

# Fix Card Effect

Investigate and fix a card whose in-game effect is not working as described.

## Arguments

`$ARGUMENTS` — The card name, and optionally a description of what is going wrong.

## Step 1: Gather Information

1. Find the card in `scripts/generated_seeds.gd` (or `src/deck/card_catalog.gd`) by searching for the card name.
2. Read the card's `rules_text` to understand what it should do.
3. If the user references recent gameplay or a game log, read `game_log.txt` in the project root. Look for the card's play event and whether the trigger fired, what op was invoked, and whether subsequent state changes (e.g., `[SUMMON]`, `[DAMAGE]`) actually occurred. A trigger that fires but produces no downstream log entry points to a silent failure in the op handler.
4. If the user has not described the problem, ask what is happening vs what they expected.
5. If anything else is unclear about the expected behaviour, ask for clarification before proceeding.

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
- `on_friendly_summon` — when the controller summons another creature (excludes self)
- `on_keyword_gained` — when the trigger's own card gains a new keyword (match_role: "target")
- `item_detached` — when an item is detached from its host creature (death, silence, transform). Use this instead of `last_gasp`/`on_death` for item "Last Gasp" effects, because `last_gasp` uses `match_role: "subject"` which matches the dying creature's instance_id, not the item's. Add `required_detach_reason: "host_left_play"` to fire only on creature death (not silence/transform).

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
- `required_card_types_in_discard_or_play` — array of card types (e.g., `["action", "item", "support"]`) that must each appear in the controller's discard pile, support zone, or as items attached to lane creatures
- `required_event_lane_id` — the event's `lane_id` must match this value (e.g., `"field"` for left lane)
- `excluded_event_lane_id` — the event's `lane_id` must NOT match this value (use for "Otherwise" branches)
- `required_equipped_item_definition` — the trigger's source card must have an attached item with this `definition_id`
- `required_no_equipped_item_definition` — the trigger's source card must NOT have an attached item with this `definition_id` (e.g., Sheepish Dunmer keeps cover while "pantsless")
- `required_detach_reason` — the event's `reason` field must match this value (e.g., `"host_left_play"` for item_detached triggers that should only fire on creature death)

**Effect Operations** (defined in `match_timing._apply_effects()`):
- `modify_stats` — `{op, target, power, health, duration?}` — use `"duration": "end_of_turn"` for "this turn" effects
- `grant_keyword` — `{op, target, keyword_id, duration?}` — use `"duration": "end_of_turn"` for "this turn" effects
- `grant_status` — `{op, target, status_id, expires_on_turn_offset?}` — for `"cover"` status, `expires_on_turn_offset` controls when cover expires (default 1 = next turn start). Use a large value (e.g., 9999) for effectively permanent cover.
- `draw_cards` — `{op, target_player, count}` — supports `post_draw_cost_set` and `post_draw_cost_reduce` for modifying drawn card costs
- `draw_filtered` — `{op, filter?, required_subtype?, required_card_type?, required_rules_tag?, max_cost?, post_draw_modify?}` — draws a random card from the controller's deck matching filters. Supports both flat keys (`required_subtype`, `required_card_type`, `required_rules_tag`, `max_cost`) and a nested `filter` dict (`filter.subtype`, `filter.card_type`, `filter.rules_tag`, `filter.max_cost`, `filter.name`, `filter.cost_equals_source_power`). `post_draw_modify` takes `{power, health}` to buff the drawn card
- `deal_damage` — `{op, target, amount}` or `{op, target, amount_source}` — deals damage to card targets; falls back to player damage via `event.target_player_id` or `trigger._chosen_target_player_id` when no card targets found. Use `amount_source` instead of `amount` for dynamic values resolved at runtime (e.g., `"oblivion_gate_level"`, `"self_power"`, `"damage_taken"`); see `_resolve_amount()` for all supported sources
- `damage` — handled via `ExtendedMechanicPacks.apply_custom_effect()`
- `heal` — handled via `ExtendedMechanicPacks.apply_custom_effect()`
- `gain_magicka` — `{op, amount}` — adds to `temporary_magicka`; handled via `ExtendedMechanicPacks.apply_custom_effect()`
- `summon_from_effect` — `{op, card_template, lane_id (optional)}`
- `fill_lane_with` — `{op, card_template, lane?, owner?}` — fills controller's side of a lane with copies of the template. `lane` supports sentinels: `"same"` (event lane), `"other"` (opposite lane), `"chosen"` (player-picked), `"both"` (all lanes). `owner: "both"` fills both sides.
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
- `select_card_from_hand` — `{op, filter, then_op, then_context?, prompt?}` — creates a pending hand selection; the player picks an eligible hand card, then `then_op` is applied to it. Filter supports: `rules_tag`, `card_type`, `subtype`, `keyword`, `attribute`, `definition_id`. If no eligible cards, the effect fizzles silently. This is a **pending state op** (see below).
- `add_counter` — `{op, counter, amount?, threshold?, then_effects?}` — increments a named counter (`_counter_<name>`) on the source card. If `threshold` is set and the counter reaches it, fires `then_effects` (via `ExtendedMechanicPacks.apply_custom_effect`) and resets counter to 0. Useful for cards that track cumulative events (e.g., "When 20 enemy creatures have died..."). Note: `then_effects` only go through `apply_custom_effect`, not the full `_apply_effects` — so only ops handled there (`damage`, `heal`, `draw_cards`, `gain_magicka`, `summon_random_from_catalog`, etc.) work in `then_effects`.
- `copy_keywords_to_friendly` — `{op, source?, target, target_filter_subtype?}` — copies all keywords from the source card to each target card. `source` defaults to `"self"` (the trigger's source card); for items, use `"source": "event_target"` to reference the equipped creature. Iterates `RANDOM_KEYWORD_POOL` and grants each keyword the source has via `granted_keywords`.
- `destroy_all_except_strongest_in_lane` — `{op}` — for each side of the chosen lane (resolved from `trigger._chosen_lane_id` or `event.lane_id`), finds the creature with the highest power and destroys all others. Used with `action_target_mode: "choose_lane"`. Iterates in reverse and collects IDs before destroying to avoid array mutation during iteration. Emits `creature_destroyed` events.
- `equip_item` / `equip_generated_item` — `{op, target, card_template}` — generates an item from template and equips it to each resolved target creature. Useful for effects that attach items (e.g., Stolen Pants' Last Gasp passes pants to a Sheepish Dunmer via `"target": "random_friendly"` + `"target_filter_definition_id"`).
- `remove_status` — `{op, target, status_id}` — removes a status (cover, shackle, etc.) from target. For cover, also clears `cover_expires_on_turn` and `cover_granted_by`.
- `log` — `{op, message}`

**Target Values** for card targets:
- `"self"` — the card that owns the trigger
- `"event_source"` — the card that caused the event
- `"event_target"` — the target of the event (resolved from the event's `target_instance_id`; used by supports without `target_mode`)
- `"chosen_target"` — the target chosen via `target_mode` (resolved from `trigger._chosen_target_id`; used by cards with `target_mode` on the trigger, including supports with `target_mode` on activate triggers)
- `"event_subject"` — the subject of the event
- `"event_summoned_creature"` — the creature that was just summoned (alias for event_source in summon events, used by `on_friendly_summon` triggers)

**Target Player Values**:
- `"controller"` — the card's controller
- `"event_player"` — the player who caused the event
- `"target_player"` — the target player of the event

### Card Relationship / Alt-View System
Cards that care about subtypes, attributes, or other synergies can show contextual info (e.g. "You have 3 Orcs in your deck") when the player cycles through alt-views with UP/DOWN. This is driven by `card_relationship_resolver.gd`, which inspects the card's `triggered_abilities` and `aura` fields to find synergy signals:
- `required_subtype_on_board` — "Summon: +X/+Y if you have another [subtype]"
- `required_event_source_subtype` — "When you summon another [subtype]..."
- `required_summon_subtype` — "When you summon a [subtype]..."
- Effect-level `filter.subtype` — Effects that target/filter by subtype (e.g. "Reduce the cost of a random Dragon", "Draw a random Nord", "Put a random Daedra into your hand"). Also checked inside `choose_one` choices.
- `aura.filter_subtype` — Aura scaling with subtype count
- `aura.filter_attribute` — Aura scaling with attribute count
- `cost_reduction_aura.filter_subtype` — Cost reduction for a subtype

Cards whose effects create other cards (via `card_template` in their effects) can also show those cards as alt-views. This is controlled by `RELATED_CARD_OPS` at the top of `card_relationship_resolver.gd` — any effect op in that list that has a `card_template` field will have it shown as a card alt-view. If a new op uses `card_template` but isn't in the list, add it.

If the user reports a missing or broken alt-view, check three things:
1. **Resolver coverage (text)** — Is the card's synergy signal handled in `_resolve_contextual_text()` in `card_relationship_resolver.gd`? Check both trigger-level condition fields (e.g. `required_subtype_on_board`) and effect-level `filter.subtype` fields. If not covered, add a resolver function that extracts the subtype/attribute and calls `_subtype_count_text()`.
1b. **Resolver coverage (card)** — Does the card's effect op appear in `RELATED_CARD_OPS`? If not, add it so the `card_template` shows as an alt-view card.
2. **Context not passed** — The resolver needs a context dict (`zone`, `deck_cards`, `board_cards`, `hand_cards`) to show counts. If it shows "Synergy: X" instead of "You have N Xs...", the `CardDisplayComponent` isn't receiving context via `set_relationship_context()`. Check these rendering paths:
   - `match_screen.gd` — `_build_card_display_component()` (main card rendering for hand/lane/support)
   - `match_screen.gd` — `_add_hover_preview_to_layer()` / `_build_match_relationship_context()` (hover previews)
   - `arena_draft_screen.gd` — `_show_deck_hover_preview()` / `_build_draft_relationship_context()`
   - `deck_editor_screen.gd` — `_build_relationship_context()` (already wired up)

### Passive Abilities System
Cards with ongoing board effects that modify other cards' keywords or behavior use `passive_abilities` — an array of passive descriptors stored on the card. Unlike triggered abilities (event-driven), passives are recalculated each aura refresh cycle. Types:
- `grant_keyword_to_type` — `{type, keyword, card_type}` — grants a keyword to all cards of a type in the controller's hand (e.g., Ancano: "Your actions have Breakthrough"). The keyword is applied via `aura_keywords` during `recalculate_auras()` Step 3d. The engine op that implements the keyword behavior must also check for the keyword on the source card (e.g., `deal_damage` checks for Breakthrough on action cards and applies overflow).
- `grant_keyword_to_keyword` — `{type, granted_keyword, required_keyword}` — grants a keyword to friendly creatures that already have a specific keyword (e.g., Mournhold Taskmaster: "Friendly creatures with Veteran have Charge"). Applied during `recalculate_auras()` Step 3c.

### Immunity System
Two immunity mechanisms exist, each with its own format and consumer:
- **`self_immunity`** (array) — immunities on the card itself (e.g., Lumbering Ogrim can't gain Cover, Mage Slayer immune to action damage). Checked by `_is_immune_to_effect()` via `target_card.get("self_immunity", [])`.
- **`grants_immunity`** — two formats:
  - **Array format** `["silence"]` — grants immunity to OTHER friendly lane creatures (excludes self). Checked by `_is_immune_to_effect()` which scans friendly board creatures for the array. Used by Dres Renegade, Keeper of Whispers, etc.
  - **Dict format** `{"scope": "all_friendly", "condition": "exalted", "immunity": "damage"}` — conditional aura-style immunity. Evaluated in `recalculate_auras()` Step 3f, which sets `aura_damage_immune` on qualifying targets. Checked in `apply_damage_to_creature()`. Used by Almalexia.

### Common Root Causes

1. **Missing `triggered_abilities`** — Card has `effect_ids` and `rules_text` but no `triggered_abilities` array, so the effect never fires.
2. **Missing equip fields on items** — Item has `keywords`/`rules_text` but lacks `equip_power_bonus`/`equip_health_bonus`/`equip_keywords`.
3. **Effect op not implemented** — The required behaviour needs a new op in `match_timing._apply_effects()`.
4. **Wrong trigger family** — e.g., using `summon` instead of `on_play` for an action card.
5. **Hydration not passing field** — New fields added to the catalog but not copied in `match_screen._hydrate_card()`.
6. **Missing `duration` on "this turn" effects** — `modify_stats` and `grant_keyword` ops are permanent by default. Cards with "this turn" in `rules_text` need `"duration": "end_of_turn"` on the effect descriptor.
7. **Effect op writes to wrong state field** — The op handler exists and fires, but mutates a non-existent or wrong field on the player/card state dictionary. GDScript silently creates new dict keys on assignment, so the value is stored but never read by the rest of the engine. The effect appears to do nothing.
8. **Strict comparison condition excludes boundary case** — A trigger condition uses a strict comparison (e.g., `required_more_health` = strictly >) when the card text implies an inclusive one (e.g., "Otherwise" = not less = >=). At the boundary (equal values), neither branch fires. Fix by using the appropriate inclusive condition (e.g., `required_not_less_health`).
9. **Inline `card_template` missing abilities** — Two sub-cases:
   - **Token missing abilities it should have**: Template references a token `definition_id` that has a separate `_seed` entry. If the template omits `triggered_abilities`, `build_generated_card` looks up the catalog by `definition_id` and copies them. But if the `definition_id` doesn't match any seed (typo, prefix mismatch like `"hom_int_x"` vs `"int_x"`), the lookup fails silently and the token has no abilities.
   - **Copy gaining abilities it shouldn't have (infinite chaining)**: Template uses the **same** `definition_id` as the parent card but omits `triggered_abilities`. `build_generated_card` finds the parent's seed and copies its `triggered_abilities` onto the copy — including the very trigger that created it. The copy then fires the same summon/last_gasp trigger, chaining infinitely. Fix by adding `"triggered_abilities": []` to the template to block the catalog lookup. Note: some copies *should* inherit abilities (e.g., Brassilisk copies should also trigger on damage) — only block when the inherited trigger would cause unwanted recursion.
   - `build_generated_card` catalog lookup copies: `triggered_abilities`, `aura`, `innate_statuses`, `first_turn_hand_cost`. It does **not** copy `grants_immunity`, `cannot_attack`, or other fields — these must be added to the template manually if needed.
10. **Unhandled `amount_source` value** — The effect uses `amount_source` to resolve a dynamic amount at runtime (e.g., gate level, creature power), but `_resolve_amount()` in `match_timing.gd` doesn't handle that particular value. It falls through to `int(effect.get("amount", 0))` which returns 0. The effect fires but applies zero damage/heal/stats.
11. **Action card player target not resolved by `deal_damage`** — The `deal_damage` op falls back to player damage when `_resolve_card_targets` returns empty, but only checks `trigger._chosen_target_player_id` (set by `resolve_targeted_effect` for creatures with `target_mode`). Action cards pass the player target via `event.target_player_id` instead, so face damage silently does nothing. Also check `match_action_enumerator._expand_target_parameter_sets()` — if `action_target_mode` is empty, the AI must enumerate player targets alongside card targets.
12. **Wrong `match_role` on family spec** — The `FAMILY_SPECS` entry for a trigger family uses `"any_player"` or `"controller"` when the card text says "When [this card] gains/does X" — meaning the trigger should only fire for events targeting the trigger's own card. With the wrong role, every copy of the card in play triggers for any matching event. Fix by using `match_role: "target"` (checks `event.target_instance_id == trigger.source_instance_id`). Check existing family spec defaults before adding per-card overrides — if all cards using the family need the same role, fix the spec.
13. **Event emitted without actual state change** — An effect op (e.g., `grant_keyword`) emits an event even when the operation was a no-op (e.g., keyword already present). Downstream triggers that react to the event fire spuriously. Fix by gating event emission on whether the state actually changed (e.g., check `has_keyword` before granting, only emit if the keyword was new).
14. **Activate/on_play trigger with `target_mode` blocked at four layers** — Support's activate (or action's on_play) trigger uses `target_mode` with `"target": "chosen_target"` in effects, but four systems block it: (1) `_append_card_triggers` unconditionally skips all triggers with `target_mode` from the registry — the trigger never even enters event processing, (2) UI's `_selected_support_uses_card_targets` / `_action_needs_explicit_target` — doesn't enter targeting mode, (3) engine's `_trigger_matches_event` — skips triggers with `target_mode` when `_chosen_target_id` is empty, (4) AI's `_collect_target_requirements` — doesn't expand card targets. Fix: exempt `activate` and `on_play` families from the registry skip in `_append_card_triggers`, inject `_chosen_target_id` from the event in `_trigger_matches_event`, and update UI/enumerator.
15. **Multi-summon op delegates to single-summon helper** — An op that should summon multiple creatures (e.g., "summon random Daedra with total cost 10") delegates to a single-summon helper like `summon_random_from_catalog` without looping. The effect fires once and stops. Fix by rewriting the op handler as a loop that tracks a budget, filters candidates within remaining budget, checks lane capacity across all lanes, and summons until budget is exhausted or all lanes are full. When only one slot remains, pick the highest-cost candidate within budget to maximize value.
16. **Unresolved sentinel parameter value** — An effect parameter uses a sentinel string (e.g., `"lane": "chosen"`, `"lane": "random"`, `"lane": "both"`) that should be resolved at runtime, but the op handler's resolution chain doesn't have a branch for that value. The literal string passes through silently — it doesn't match any real entity (lane, card, player) but produces no error. The effect appears to fire (trigger log shows it) but has no visible result. Fix by adding a resolution branch for the sentinel value alongside existing ones (e.g., `"same"`, `"other"`). Check all ops that resolve the same parameter type for consistency.
17. **Board passive marker family not implemented in keyword resolution** — Card uses a custom trigger family (e.g., `on_rally_empty_hand`, `on_rally`) as a marker that keyword resolution code should scan for on board creatures, but the keyword resolution code (e.g., `resolve_rally` in `evergreen_rules.gd`, combat flow in `match_combat.gd`) doesn't check for it. These are NOT standard event-driven triggers — they're passive markers read by keyword-specific code. Fix by adding a board scan to the relevant keyword resolution function that looks for creatures with the marker family and applies the modifier behavior.
18. **Missing `passive_abilities` for ongoing keyword grant to card type** — Card has rules text like "Your actions have Breakthrough" but no `passive_abilities` entry with `grant_keyword_to_type`. Additionally, the engine op that implements the keyword behavior (e.g., `deal_damage` for Breakthrough) may not check for the keyword on the source card. Fix requires both: (a) adding the passive to card data, and (b) ensuring the engine op applies the keyword's behavior when the source card has it via `aura_keywords`.
19. **Missing `source` on item effect op defaults to item card** — Effect ops that read from a `source` parameter (e.g., `copy_keywords_to_friendly`) default to `"self"`, which for items resolves to the item card, not the equipped creature. The effect silently operates on the wrong card (typically finding no keywords/stats). Fix by adding `"source": "event_target"` to the effect descriptor so it references the equipped creature.
20. **Stale per-turn state flag survives zone transitions** — A per-turn flag (e.g., `has_attacked_this_turn`) is set on a card dict during gameplay but only cleared at turn start via `refresh_for_controller_turn`. If the creature dies, is recycled back to deck/hand (e.g., Journey to Sovngarde, Soul Tear), and replayed in the same turn, the flag persists and incorrectly constrains the new activation. Fix by resetting the flag in `_apply_lane_entry` (guarded by `preserve_entered_lane_on_turn` so lane-to-lane moves don't reset it). This is an engine-level bug, not a card-data issue — no card catalog changes needed.
21. **Meta-trigger op bypasses target selection for replayed abilities**
22. **Lane-targeting `action_target_mode` enters creature targeting mode** — Card has `action_target_mode: "choose_lane"` but `_action_needs_explicit_target` returns `true` for any non-empty `action_target_mode`. This sends the card into creature targeting (arrow) mode, but the `_on_lane_pressed` handler blocks lane plays when `_action_needs_explicit_target` is true. Fix by excluding lane-based modes (e.g., `"choose_lane"`) from `_action_needs_explicit_target` so the card uses the detach-to-lane flow instead. The `lane_id` is then passed through `_play_action_to_lane` → `play_action_from_hand` options → event → trigger resolution.
23. **Dict-format `grants_immunity` not consumed by aura recalculation** — Card has `grants_immunity` as a dict (`{scope, condition, immunity}`) for conditional aura-style immunity (e.g., "Friendly Exalted creatures are immune to damage"), but the engine only consumed the array format via `_is_immune_to_effect()`. The dict data flows through build/hydrate correctly but is silently skipped by the `typeof == TYPE_ARRAY` check. Fix: `recalculate_auras()` Step 3f now scans for dict-format sources and sets `aura_damage_immune` on qualifying targets. — Effect ops that iterate other cards' `triggered_abilities` and directly call `_apply_effects` (e.g., `trigger_exalt_all_friendly`, `trigger_summon_ability`, `repeat_slay_reward`, `play_learned_actions`) work for self-targeting effects but silently fail for abilities with `target_mode` + `target: "chosen_target"`, because no `_chosen_target_id` is set on the synthetic trigger. Fix by checking `target_mode` on the replayed ability: if present, either queue a `pending_summon_effect_targets` entry (for interactive contexts like summon/slay replay) or auto-resolve a random valid target via `get_valid_targets_for_mode` + `_deterministic_index` (for non-interactive contexts like last gasp replays). Compare with `_force_wax_wane_triggers` which already handles this correctly by skipping `target_mode` triggers.

24. **Item "Last Gasp" uses wrong trigger family** — Item has "Last Gasp" in `rules_text` but uses `last_gasp` or `on_death` family. These families have `match_role: "subject"`, which matches the dying creature's `instance_id` — not the item's. Since items are separate entities attached to the creature, the match always fails silently. Fix by using `FAMILY_ITEM_DETACHED` (`"family": "item_detached"`) which fires on `attached_item_detached` events with `match_role: "source"` (the item's instance_id). Add `"required_detach_reason": "host_left_play"` to restrict to creature death only. The item will be in the discard zone when the trigger fires, but `PLAYER_ZONE_ORDER` includes discard so triggers are still registered. Existing correct example: Heirloom Greatsword uses `item_detached`.

### Pending State Pattern (Interactive Effects)

Some effects pause the game and wait for player input before resolving. These use a **pending state** stored on `match_state`. Existing pending state systems:
- `pending_prophecy_windows` — Prophecy interrupt
- `pending_discard_choices` — Choose a card from discard pile
- `pending_hand_selections` — Choose a card from hand (e.g., Word Wall's "Upgrade a Shout in your hand")

If a new effect requires player interaction (choosing a target from a zone, picking between options, etc.), follow this pattern across **all layers**:

1. **match_timing.gd**: Add the pending state array to `ensure_match_state()`. Add `has_pending_*()`, `get_pending_*()`, `resolve_pending_*()`, `decline_pending_*()` static functions. Add the effect op that creates the pending state.
2. **match_action_enumerator.gd**: Add new `KIND_*` constants. Add enumeration in `enumerate_legal_actions()` (check BEFORE existing pending checks if higher priority). Add `_enumerate_pending_*_actions()`. Add legality checks in `action_is_legal()`. **Critical**: Also update `_resolve_decision_player_id()` to handle the new pending state — this is easy to miss and will cause the AI to not see the pending actions.
3. **match_action_executor.gd**: Add execution cases for the new action kinds.
4. **match_screen.gd**: Add UI state variable. Add refresh/enter/exit/resolve/cancel functions. Update `_local_player_has_pending_interrupt()`, `_ai_controls_current_decision_window()`, right-click handler, and `_on_card_pressed()`. Add cleanup calls alongside existing `_dismiss_*` calls.

Also update `action_is_legal` for `KIND_END_TURN` to block ending turn while the new pending state is active.

### Key Files to Investigate

- `src/core/match/match_combat.gd` — combat resolution, Rally/Drain/Breakthrough flows, keyword resolution hooks
- `src/deck/card_catalog.gd` — card definitions
- `src/core/match/match_timing.gd` — trigger matching and effect resolution
- `src/core/match/match_mutations.gd` — state mutation helpers
- `src/core/match/evergreen_rules.gd` — keyword/stat/status helpers
- `src/core/match/extended_mechanic_packs.gd` — custom effects and conditions
- `src/core/match/lane_rules.gd` — lane entry and summon validation
- `src/core/match/persistent_card_rules.gd` — play-from-hand flows (actions, items, supports)
- `src/ai/match_action_enumerator.gd` — action enumeration and legality (update for new pending states)
- `src/ai/match_action_executor.gd` — action execution dispatch (update for new action kinds)
- `src/ui/match_screen.gd` — card hydration (`_hydrate_card`), hand selection UI, pending state refresh
- `src/ui/components/card_relationship_resolver.gd` — alt-view synergy text (subtype/attribute counts)

## Step 3: Implement the Fix

1. If a new effect op is needed, add it to `_apply_effects()` in `match_timing.gd`, following the pattern of existing ops. Make it generic/reusable rather than card-specific.
2. If an existing op needs a new optional parameter (e.g., adding `duration` support to `grant_keyword`), extend the op handler in `_apply_effects()` rather than creating a new op. Follow the pattern of similar parameters on other ops (e.g., `modify_stats` already supports `duration`).
3. If a new trigger condition is needed (the card's condition doesn't match any existing condition in the Trigger Conditions list), add it to `matches_additional_conditions()` in `extended_mechanic_packs.gd`. Follow the pattern of existing conditions: read the field from the descriptor, check it against match state, return false if not met. Make the condition generic/reusable.
4. **Before fixing card data, check scope.** If the same data-format mismatch affects multiple cards (scan Step 4 first), fix the engine handler to accept the existing data format rather than patching each card individually. This is especially relevant for `filter` dict mismatches — prefer updating the handler to fall back to `effect.get("filter", {})` over adding duplicate flat keys to every card.
5. If the card just needs `triggered_abilities` wired up, update its `_seed()` call in `scripts/generated_seeds.gd` (or `card_catalog.gd`).
5. If new fields are introduced, ensure they flow through:
   - `_seed()` in `card_catalog.gd`
   - `_build_card()` in `card_catalog.gd`
   - `_hydrate_card()` in `match_screen.gd`
6. If an item needs equip fields, parse the `rules_text` to extract `equip_power_bonus`, `equip_health_bonus`, and `equip_keywords`.
7. If new per-card state is added (e.g., `temporary_keywords`), ensure it is cleared in all cleanup paths:
   - `match_mutations.silence_card()` — silence wipes all granted state
   - `match_mutations.reset_transient_state()` — used when cards change zones
   - `match_turn_loop._clear_temporary_stat_bonuses()` — end-of-turn cleanup (if the state is turn-scoped)

## Step 3b: Post-fix Learnings Scan

Run `scan-learnings` again with a more specific description now that you understand the problem deeply (e.g., "random target selection in match_timing", "trigger registry filtering"). Your understanding of the problem has evolved since Step 1b — this second pass catches issues your fix may have introduced that weren't obvious before the implementation.

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
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file "$TMPDIR/godot.log" --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script tests/<runner>.gd
```

Key runners to check after effect changes:
- `items_and_supports_runner.gd`
- `timing_runner.gd`
- `extended_mechanics_runner.gd`
- `keyword_matrix_runner.gd`
- `golden_match_runner.gd`

## Step 8: Pattern Scan

After all fixes are committed and tests pass, run the `bug-pattern-scan` skill to generalize the fix into an abstract pattern class and scan for unresolved siblings across the codebase. This surfaces other cards or systems that may have the same class of bug.
