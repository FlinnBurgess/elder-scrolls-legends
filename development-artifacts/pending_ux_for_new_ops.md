# Pending UX Work for New Engine Ops

## All Functionally Broken Items — FIXED

- ~~#20~~ `look_draw_discard` / `look_give_draw` — Multi-card choice panel (commit 89fe0de)
- ~~#21~~ `_on_player_choice_selected` drops events (commit 2989817)
- ~~#22~~ `choose_two` second-choice re-prompt (commit c41e0c8)

## Feedback Handlers — All Event Types Now Covered

Added `_record_feedback_from_events` handlers for 35 event types including:

**Creature-level popups** (via `_queue_creature_toast`):
- `marked_for_destruction` → "DOOMED" (red)
- `status_removed` → "[STATUS] REMOVED" (orange)
- `cost_modified` → "+N/-N Cost" (purple)
- `temporary_immunity_granted` → "IMMUNE" (gold)
- `damage_redirect_set` → "PROTECTED" (blue)
- `creature_marked` / `creature_aimed_at` → "MARKED"/"AIMED"
- `marked_for_resummon` → "RESUMMON" (gold)
- `attribute_changed` → "→ [Attribute]"
- `stats_modified` → "+N/+N" (green) or "-N/-N" (red)
- `attached_item_detached` → "ITEM DESTROYED"
- `keyword_granted` → "+[KEYWORD]" (green)
- `keyword_stolen` / `status_stolen` → "-[KEYWORD]" (red)
- `ability_granted` → "+ABILITY"

**Status toasts** (via `_queue_status_toast`):
- `treasure_found` → "Treasure Found! (N)" (gold)
- `card_transformed` → "Card transformed!" (purple)
- `rune_restored` → "Rune restored!" (cyan)
- `lane_type_changed` → "[Type] Lane!" (purple)
- `magicka_restored` → "Magicka restored!" (blue)
- `card_milled` → "Card milled"
- `card_stolen_from_discard` → "Stole a card!" (gold)
- `item_in_hand_modified` → "Item buffed +X/+Y"
- `rune_draw_prevented` → "Next rune draw prevented!"
- `double_summon_granted` → "Double Summon this turn!"
- `action_learned` → "Learned [Name]!"
- `card_shuffled_to_deck` → "Card shuffled into deck"
- `card_banished` → "Card banished"
- `card_discarded` → "Card discarded"
- `card_stolen` → "Card stolen!"
- `card_consumed` → "Creature consumed"

**Animations:**
- `treasure_hunt_revealed` → Card-flip deck reveal with MATCH!/MISS banner (green/red)

**Skip button:**
- Optional summon targeting now shows a visible "Skip" button (same pattern as Betray skip)

## Still Outstanding — Polish/Nice-to-Have

These are minor polish items that don't block gameplay:

### Wax/Wane Phase Indicator
- The current wax_wane_state is never displayed. Player can't tell which phase they're in.
- **Need:** Player avatar badge showing current moon phase.
- Cards: All Wax/Wane creatures, Moon Gate, Rebellion General

### Counter Badge
- `add_counter` increments silently. No badge or progress indicator on the card.
- **Need:** Counter badge on card showing current count / threshold.
- Cards: Cog Collector, Dragonfire Wizard

### Lane AOE Flash
- `deal_damage_to_lane`: Individual damage popups fire but no lane-wide flash.
- **Nice to have:** Lane flash/pulse before individual damage popups.
- Cards: Unstoppable Rage

### Lane-Clear Animation
- `shuffle_all_creatures_into_deck`: Creatures leave lanes via move (not destroy), so no removal animation fires.
- **Nice to have:** Dedicated lane-clearing sweep animation.
- Cards: A New Era

### Swap Toast
- `swap_creatures`: Board redraws but no announcement that a swap happened.
- **Nice to have:** Toast on both swapped creatures.
- Cards: Guildsworn Honeytongue

### Deck Transform Toast
- `transform_deck`: Entire deck silently replaced.
- **Nice to have:** Toast: "Deck transformed!"
- Cards: Gates of Madness

### Consume Toast
- `consume_all_creatures_in_discard_this_turn`: Silent consume.
- **Nice to have:** Toast: "Consumed N creatures from discard!"
- Cards: Ruin Shambler

### Summon Source Indication
- Creatures summoned from deck/discard appear with no indication of where they came from.
- **Nice to have:** Deck/discard glow when a card is pulled from it.
- Cards: Gravesinger, Mannimarco, Sails-Through-Storms, etc.

### Re-trigger Announcement
- `trigger_all_friendly_summons`: Individual summon events fire but no announcement that it's a re-trigger.
- **Nice to have:** Toast before individual summons.
- Cards: Ulfric's Uprising
