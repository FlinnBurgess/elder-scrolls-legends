# Pending UX Work for New Engine Ops

New ops and target modes implemented in match_timing.gd/extended_mechanic_packs.gd that need UX work in the match screen to be fully polished during play. Grouped by priority.

## Functionally Broken — FIXED

#### ~~20. `look_draw_discard` / `look_give_draw` — Multi-card choice panel missing~~ FIXED
- **Fixed in commit 89fe0de.** Added `resolve_pending_top_deck_multi_choice()` engine resolver and multi-card overlay panel.

#### ~~21. `_on_player_choice_selected` drops events from resolved choices~~ FIXED
- **Fixed in commit 2989817.** Added `_record_feedback_from_events` call after `resolve_pending_player_choice`.

#### ~~22. `choose_two` — No second-choice re-prompt~~ FIXED
- **Fixed in commit c41e0c8.** `resolve_pending_player_choice` now re-queues with chosen option removed.

## Feedback Handlers Added — Event Types Now in `_record_feedback_from_events`

The following items now have toast/popup/animation feedback via the feedback pump:

| # | Event | Feedback | Cards |
|---|-------|----------|-------|
| ~~1~~ | `marked_for_destruction` | "DOOMED" creature popup (red) | Blood Pact Messenger |
| ~~4~~ | `status_removed` | "[STATUS] REMOVED" creature popup | Sound the Alarm, Underworld Vigilante, etc. |
| ~~5~~ | `card_stolen_from_discard` | "Stole a card from opponent's discard!" toast | Mausoleum Delver, The Gray Fox |
| ~~6~~ | `cost_modified` | "+N/-N Cost" creature popup (purple) | Karthspire Scout, Skyshard, Cyriel |
| ~~7~~ | `item_in_hand_modified` | "Item buffed +X/+Y" toast | Covenant Oathman, Seasoned Captain |
| ~~9~~ | `card_milled` | "Card milled" toast | Ruin Shambler, Seeker of the Black Arts |
| ~~10~~ | `magicka_restored` | "Magicka restored!" toast (blue) | Invoker of the Hist |
| ~~11~~ | `card_shuffled_to_deck` | "Card shuffled into deck" toast | Baandari Opportunist, Shadowmere, etc. |
| ~~15~~ | `keyword_stolen` / `status_stolen` | "-[KEYWORD]" creature popup (red) | Back-Alley Rogue |
| ~~23~~ | `treasure_hunt_revealed` | Card-flip reveal animation with MATCH!/MISS banner | All 9 Treasure Hunt cards |
| ~~23~~ | `treasure_found` | "Treasure Found! (N)" toast (gold) | All 9 Treasure Hunt cards |
| ~~24~~ | `card_transformed` | "Card transformed!" toast (purple) | All transform ops |
| ~~25~~ | `rune_restored` | "Rune restored!" toast (cyan) | The Mechanical Heart, Morokei |
| ~~26~~ | `lane_type_changed` | "[Type] Lane!" toast (purple) | Syl, Thadon |
| ~~27~~ | `temporary_immunity_granted` | "IMMUNE" creature popup (gold) | Penitus Oculatus Envoy |
| ~~28~~ | `damage_redirect_set` | "PROTECTED" creature popup (blue) | Jauffre |
| ~~29~~ | `rune_draw_prevented` | "Opponent's next rune draw prevented!" toast | Varen Aquilarios |
| ~~30~~ | `creature_marked` / `creature_aimed_at` | "MARKED"/"AIMED" creature popup | Miscarcand Lich, Flamespear Dragon |
| ~~31~~ | `marked_for_resummon` | "RESUMMON" creature popup (gold) | Zumog Phoom |
| ~~34~~ | `action_learned` | "Learned [Name]!" toast (blue) | Hannibal Traven |
| ~~35~~ | `double_summon_granted` | "Double Summon this turn!" toast (gold) | Yagrum's Workshop |
| ~~38~~ | `attribute_changed` | "→ [Attribute]" creature popup | Clockwork Apostle, Painted Troll |

## Still Outstanding

### Needs Skip Button UI (Blocking)

#### 2. Optional targeting — No visible Skip button
- Target modes: `enemy_creature_optional`, `another_friendly_creature_optional`
- Escape key cancels, but there's no visible Skip button like Betray has.
- **Need:** A "Skip" button in the targeting UI when `_is_pending_summon_mandatory()` returns false.
- Cards: Spear of Embers, Xavara Atronach

### Needs Stat Popup on Creature (High)

#### 3. `stats_modified` events from `set_health`, `set_power_to_health`, `double_health`
- These stat-change events aren't routed to creature-level popups yet. The `_record_feedback_from_events` damage path handles `damage_resolved` but `stats_modified` from these ops has no popup.
- **Need:** Floating stat-change popup on affected creature (green "+N/+N" or "SET 6/6").
- Cards: Xivkyn Banelord, Three Feather Warchief, The Mechanical Heart, Steel-Eyed Visionary, Ring of Imaginary Might, Ring of the Beast

### Needs Item Detach Feedback (High)

#### 8. `attached_item_detached` from `destroy_item`
- Item silently disappears from host creature.
- **Need:** "ITEM DESTROYED" feedback banner on the host creature.
- Cards: Fork of Horripilation

### Needs Banish Toast (Medium)

#### 12. `card_banished` from `banish_discard_pile` / `banish_from_opponent_deck`
- Discard/deck silently shrinks.
- **Need:** Toast ("Banished N card(s)").
- Cards: Memory Wraith, Soul Shred, Piercing Twilight

### Needs Discard Toast (Medium)

#### 13. `discard_from_hand` / `discard_random`
- Card leaves hand with no notification.
- **Need:** Toast ("Discarded [card name]").
- Cards: Palace Conspirator, Grummite Magus, Discerning Thief

### Needs Lane AOE Flash (Low — Polish)

#### 14. `deal_damage_to_lane` — No lane-wide AOE flash
- Individual damage popups DO fire. No visual for the AOE nature.
- **Nice to have:** Lane flash/pulse effect before individual damage popups.
- Cards: Unstoppable Rage

### Needs Keyword Grant Banner (Medium)

#### 16. `destroy_and_transfer_keywords` / `keyword_granted` from chains
- Destruction feedback fires, but keyword grants during trigger chains are silent.
- **Need:** "+[Keyword]" banner flash on target card.
- Cards: Feed, and many cards via trigger chains

### Needs Lane-Clear Animation (Medium)

#### 17. `shuffle_all_creatures_into_deck`
- All creatures silently leave lanes (moved, not destroyed — no `creature_destroyed` events).
- **Need:** Lane-clearing animation and toast.
- Cards: A New Era

### Needs Swap Toast (Medium)

#### 32. `swap_creatures` — Creatures trade sides silently
- Two creatures swap controllers. Board redraws but no announcement.
- **Need:** Toast on both creatures: "Swapped!"
- Cards: Guildsworn Honeytongue

### Needs Wax/Wane Phase Indicator (Medium)

#### 36. Wax/Wane phase — No indicator anywhere in UI
- The current wax_wane_state is never displayed. Player can't tell which phase they're in.
- **Need:** Player avatar badge showing current moon phase.
- Cards: All Wax/Wane creatures, Moon Gate, Rebellion General

### Needs Counter Badge (Low)

#### 37. `add_counter` progress invisible
- Counter increments silently. No badge or progress indicator on the card.
- **Need:** Counter badge on card showing current count / threshold.
- Cards: Cog Collector, Dragonfire Wizard

### Needs Deck Transform Toast (Low)

#### 39. `transform_deck` — Entire deck silently replaced
- **Need:** Toast: "Deck transformed!"
- Cards: Gates of Madness

### Needs Consume Toast (Low)

#### 40. `consume_all_creatures_in_discard_this_turn` — Silent consume
- **Need:** Toast: "Consumed N creatures from discard!"
- Cards: Ruin Shambler

### Nice-to-Have (Low)

#### 18. `trigger_all_friendly_summons` — re-trigger announcement
- **Nice to have:** Toast before individual summons fire.
- Cards: Ulfric's Uprising

#### 19. Summon-from-deck/discard — no source indication
- **Nice to have:** Deck/discard glow when a card is pulled from it.
- Cards: Gravesinger, Mannimarco, Sails-Through-Storms, etc.
