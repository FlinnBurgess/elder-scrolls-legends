# Pending UX Work for New Engine Ops — ALL RESOLVED

All UX items from the engine feature implementation have been addressed.

## Functionally Broken — FIXED

- ~~#20~~ `look_draw_discard` / `look_give_draw` — Multi-card choice panel (commit 89fe0de)
- ~~#21~~ `_on_player_choice_selected` drops events (commit 2989817)
- ~~#22~~ `choose_two` second-choice re-prompt (commit c41e0c8)

## Feedback Handlers — All 42 Event Types Now Covered

**Creature-level popups** (`_queue_creature_toast`):
- `marked_for_destruction` → "DOOMED" | `status_removed` → "[STATUS] REMOVED"
- `cost_modified` → "+N/-N Cost" | `temporary_immunity_granted` → "IMMUNE"
- `damage_redirect_set` → "PROTECTED" | `creature_marked`/`creature_aimed_at` → "MARKED"/"AIMED"
- `marked_for_resummon` → "RESUMMON" | `attribute_changed` → "→ [Attribute]"
- `stats_modified` → "+N/+N" or "-N/-N" | `attached_item_detached` → "ITEM DESTROYED"
- `keyword_granted` → "+[KEYWORD]" | `keyword_stolen`/`status_stolen` → "-[KEYWORD]"
- `ability_granted` → "+ABILITY" | `creatures_swapped` → "SWAPPED"
- `counter_updated` → "N/N" (progress toward threshold)

**Status toasts** (`_queue_status_toast`):
- `treasure_found` | `card_transformed` | `rune_restored` | `lane_type_changed`
- `magicka_restored` | `card_milled` | `card_stolen_from_discard` | `item_in_hand_modified`
- `rune_draw_prevented` | `double_summon_granted` | `action_learned`
- `card_shuffled_to_deck` | `card_banished` | `card_discarded` | `card_stolen`
- `card_consumed` | `all_creatures_shuffled` | `summons_retriggered`
- `deck_transformed` | `mass_consume` | `lane_aoe_damage`

**Animations:**
- `treasure_hunt_revealed` → Card-flip deck reveal with MATCH!/MISS banner

**UI Features:**
- Optional targeting Skip button (matching Betray skip pattern)
- Wax/Wane phase indicator in turn banner ("Moon: Waxing/Waning")
- Counter progress popup on card (N/threshold)

## No Remaining Items

All items from the original 40-item list have been addressed. The only remaining polish opportunities are visual refinements (e.g., richer animations, persistent card overlays for marked/aimed/immune states), which can be done as part of general UI polish work.
