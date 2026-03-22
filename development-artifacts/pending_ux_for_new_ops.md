# Pending UX Work for New Engine Ops

New ops and target modes implemented in match_timing.gd/extended_mechanic_packs.gd that need UX work in the match screen to be fully polished during play. Grouped by priority.

## Blocking — Player Cannot Understand What Happened

### 1. `destroy_creature_end_of_turn` — No "doomed" visual indicator
- Event: `marked_for_destruction`
- The card gets `_destroy_at_end_of_turn` set but nothing visual changes. Player cannot see which creature will die at end of turn.
- **Need:** A persistent visual indicator on the card (skull icon, red border, "DOOMED" banner) that shows until the creature is destroyed.
- Cards: Blood Pact Messenger

### 2. Optional targeting — No visible Skip button
- Target modes: `enemy_creature_optional`, `another_friendly_creature_optional`
- Escape key cancels, but there's no visible Skip button like Betray has (`_betray_skip_button`).
- **Need:** A "Skip" button in the targeting UI when `_is_pending_summon_mandatory()` returns false.
- Cards: Spear of Embers, Xavara Atronach

## High — Effects Fire But No Visual Feedback

These all work mechanically (state updates, `_refresh_ui` shows new values) but produce no animated feedback. The player sees the result but not the cause.

### 3. `stats_modified` events from `set_health`, `set_power_to_health`, `double_health`
- These stat-change events aren't in `_record_feedback_from_events`.
- **Need:** Floating stat-change popup on affected creature (green "+N/+N" or "SET 6/6").
- Cards: Xivkyn Banelord, Three Feather Warchief, The Mechanical Heart, Steel-Eyed Visionary, Ring of Imaginary Might, Ring of the Beast

### 4. `status_removed` from `remove_status`
- Not in feedback pump.
- **Need:** Floating text on creature ("COVER REMOVED", "SHACKLE REMOVED").
- Cards: Sound the Alarm, Underworld Vigilante, Grappling Hook, Shining Saint, Vale Sabre Cat

### 5. `card_stolen_from_discard` from `steal_from_discard` / `draw_from_opponent_discard`
- Card silently appears in hand.
- **Need:** Draw-style feedback toast ("Stole [card] from opponent's discard").
- Cards: Mausoleum Delver, The Gray Fox

### 6. `cost_modified` from `modify_cost` / `reduce_cost_top_of_deck`
- Cost changes silently in hand or deck.
- **Need:** Brief highlight/popup on the affected hand card. For top-of-deck, a toast near the deck.
- Cards: Karthspire Scout, Skyshard, Cyriel

### 7. `item_in_hand_modified` from `modify_item_in_hand` / `modify_random_item_in_hand`
- Item stats change silently in hand.
- **Need:** Highlight flash on the buffed hand card with "+X/+Y" popup.
- Cards: Covenant Oathman, Seasoned Captain

### 8. `attached_item_detached` from `destroy_item`
- Item silently disappears from host creature.
- **Need:** "ITEM DESTROYED" feedback banner on the host creature.
- Cards: Fork of Horripilation

## Medium — Toast/Log Feedback Missing

These are zone-change operations where cards move between zones silently. The state is correct but there's no announcement.

### 9. `card_milled` from `mill`
- Deck silently shrinks, cards go to discard with no toast.
- **Need:** "Milled X card(s)" toast near the affected player's deck.
- Cards: Ruin Shambler, Seeker of the Black Arts

### 10. `magicka_restored` from `restore_magicka`
- Magicka bar updates silently.
- **Need:** Brief flash/highlight on magicka orbs or "+N magicka" popup.
- Cards: Invoker of the Hist

### 11. `card_shuffled_to_deck` from `shuffle_into_deck` / `shuffle_copies_into_deck` / `shuffle_self_into_deck`
- Cards silently enter deck; creature silently leaves lane for shuffle_self.
- **Need:** Toast ("Shuffled [card] into deck"). For shuffle_self, a removal animation.
- Cards: Baandari Opportunist, Skeever Infestation, Shadowmere, Conjuration Tutor

### 12. `card_banished` from `banish_discard_pile` / `banish_from_opponent_deck` / `banish_by_name_from_opponent`
- Discard/deck silently shrinks.
- **Need:** Toast ("Banished N card(s)").
- Cards: Memory Wraith, Soul Shred, Piercing Twilight

### 13. `discard_from_hand` / `discard_random`
- Card leaves hand with no notification.
- **Need:** Toast ("Discarded [card name]") or hand-card removal animation.
- Cards: Palace Conspirator, Grummite Magus, Discerning Thief

## Low — Polish/Cosmetic

### 14. `deal_damage_to_lane` — No lane-wide AOE flash
- Individual damage popups DO fire (damage_resolved is handled). But no visual to communicate it's an AOE effect hitting the whole lane simultaneously.
- **Nice to have:** Lane flash/pulse effect before individual damage popups.
- Cards: Unstoppable Rage

---

## Tier 2 Additions (2026-03-22)

### Mostly Covered by Existing Feedback

The following Tier 2 ops produce events that are already handled:
- **Summon ops** (summon_from_discard_highest_cost, summon_from_opponent_discard, summon_top_creature_from_deck, summon_from_deck_by_cost, summon_from_deck_filtered, sacrifice_and_summon_from_deck) — produce `creature_summoned` events, already animated
- **deal_damage_and_heal** — produces `damage_resolved`, `creature_destroyed`, `player_healed` — all handled
- **trigger_all_friendly_summons** — re-emits `creature_summoned` events, existing animations fire

### New UX Gaps from Tier 2

#### 15. `steal_status` / `keyword_stolen` / `status_stolen`
- New event types not in feedback pump.
- **Need:** "STOLE [keyword]" floating text on both source and target creatures.
- Cards: Back-Alley Rogue

#### 16. `destroy_and_transfer_keywords`
- Destruction feedback fires, but keyword grants are silent.
- **Need:** Keyword grant feedback after destruction animation.
- Cards: Feed

#### 17. `shuffle_all_creatures_into_deck`
- All creatures silently leave lanes. No `creature_destroyed` events (they're moved, not destroyed).
- **Need:** Lane-clearing animation and "All creatures shuffled into decks" toast.
- Cards: A New Era

#### 18. `trigger_all_friendly_summons` — re-trigger feedback
- Summon events fire individually but no "Re-triggering all summon abilities" announcement.
- **Nice to have:** Toast before the individual summons fire.
- Cards: Ulfric's Uprising

#### 19. Summon-from-deck/discard ops — no source indication
- Creatures appear in lane from deck/discard but there's no "from deck" / "from discard" indicator.
- **Nice to have:** Deck/discard glow when a card is pulled from it.
- Cards: Gravesinger, Mannimarco, Sails-Through-Storms, Chanter of Akatosh, Halls of Colossus, Altar of Despair

### New Trigger Families — No UX Impact
The 10 new trigger families (on_card_drawn, on_enemy_summon, etc.) don't need UX work — they reuse existing event infrastructure. When they fire effects, those effects produce their own events which are handled by existing feedback.

---

## Tier 3+ Additions (2026-03-22)

### Functionally Broken — Needs Fix Before Cards Are Playable

#### 20. `look_draw_discard` / `look_give_draw` — Multi-card choice panel missing
- Cards: Merchant's Camel, Shadowmarking
- Both ops push to `pending_top_deck_choices` with a `cards` array (multiple cards) and a `mode` field. But the existing UI in `_enter_top_deck_choice_mode` reads only `choice.get("revealed_card", {})` — a single card — so it gets an empty dict and shows nothing. `resolve_pending_top_deck_choice` only handles `discard: bool` (binary choice) and ignores the `mode` field.
- **Need:** New multi-card selection panel that shows all revealed cards, lets the player pick one, and resolves with the chosen index. Modes: `keep_one_discard_rest` (draw selected, discard rest) and `give_one_draw_rest` (give selected to opponent, draw rest).

#### 21. `_on_player_choice_selected` drops events from resolved choices
- Cards: All cards using `pending_player_choices` — Assembled Titan (choose_two), Fabricate, Haskill, Seducer Darkfire, Forsaken Champion, Fortress Guard, etc.
- `_on_player_choice_selected` calls `resolve_pending_player_choice` but does NOT call `_record_feedback_from_events` on the result. Any events from the chosen effects (keyword_granted, stats_modified, creature_summoned, etc.) are silently dropped.
- **Need:** Add `_record_feedback_from_events(result.get("events", []))` after `resolve_pending_player_choice` in `_on_player_choice_selected`.

#### 22. `choose_two` — No second-choice re-prompt
- Cards: Assembled Titan
- After the first choice resolves via `pending_player_choices`, the code sets `_choose_two_remaining: 1` but `resolve_pending_player_choice` doesn't re-queue a second choice. The second ability is never selected.
- **Need:** `resolve_pending_player_choice` must detect `_choose_two_remaining > 0` and re-queue a new pending choice (minus the already-chosen option) with decremented count.

### Critical — Core Mechanic Has No Feedback

#### 23. `treasure_hunt_revealed` / `treasure_found` — Treasure Hunt invisible
- Cards: All 9 Treasure Hunt creatures, Treasure Map
- Every turn the top card is revealed and checked. `treasure_hunt_revealed` carries the card and match/miss result, `treasure_found` fires on success. Neither produces any visual.
- **Need:** Card-flip reveal animation over the deck area (similar to `_animate_deck_card_reveal` used for `opponent_top_deck_revealed`), with green/red match indicator. On `treasure_found`, toast: "Treasure Found! (N/N)".

#### 24. `card_transformed` — Transform is invisible
- Cards: All cards using transform_in_hand, transform_in_hand_to_random, transform_hand, conditional_transform
- Hand cards silently replace themselves. Enemy transforms completely invisible.
- **Need:** Toast or ripple animation on the transformed card position. For transform_hand, a hand-level toast: "Hand transformed!"

### High — Significant State Changes With No Feedback

#### 25. `rune_restored` — Rune silently reappears
- Cards: The Mechanical Heart, Morokei the Deathless
- **Need:** Rune row toast mirroring the existing `rune_broken` feedback.

#### 26. `lane_type_changed` — Lane switches silently between Field/Shadow
- Cards: Syl Duchess of Dementia, Thadon Duke of Mania
- Shadow lane grants Cover — major gameplay impact with zero visual.
- **Need:** Lane panel overlay toast: "Shadow Lane!" or "Field Lane!"

#### 27. `temporary_immunity_granted` — Immunity invisible
- Cards: Penitus Oculatus Envoy
- **Need:** "IMMUNE" banner on creature (similar to WARD styling).

#### 28. `damage_redirect_set` — Redirect active but invisible
- Cards: Jauffre
- A creature shields another from damage. Nothing visually indicates the redirect.
- **Need:** Persistent aura indicator on both the protected and protecting creatures.

#### 29. `rune_draw_prevented` — Rune suppression invisible
- Cards: Varen Aquilarios
- Next rune break won't draw. Player may be confused when a rune breaks without the usual card draw.
- **Need:** Toast on opponent's avatar area + persistent indicator on rune bar.

#### 30. `creature_marked` / `creature_aimed_at` — Mark/aim invisible
- Cards: Miscarcand Lich, Preying Elytra (mark_target); Flamespear Dragon (aim_at)
- Creature is marked for a delayed effect with no visual indicator.
- **Need:** Card overlay badge (crosshair for aim, skull for mark) until the effect resolves.

#### 31. `marked_for_resummon` — Resummon on death invisible
- Cards: Zumog Phoom
- Creature will return on death but nothing indicates this.
- **Need:** Persistent badge on creature: "RESUMMON" (bronze/gold).

#### 32. `swap_creatures` — Creatures trade sides silently
- Cards: Guildsworn Honeytongue
- Two creatures swap controllers. Board redraws but no announcement.
- **Need:** Toast on both creatures: "Swapped!"

### Medium — Feedback Would Help But Not Critical

#### 33. `keyword_granted` from bulk/chain effects
- Many cards grant keywords silently during trigger chains.
- **Need:** "+[Keyword]" banner flash on target card.

#### 34. `action_learned` — Learn is invisible
- Cards: Hannibal Traven
- **Need:** Toast: "Learned [Card Name]!"

#### 35. `double_summon_granted` — Player unaware of opportunity
- Cards: Yagrum's Workshop
- **Need:** Toast: "Double Summon this turn!"

#### 36. Wax/Wane phase — No indicator anywhere in UI
- Cards: All Wax/Wane creatures, Moon Gate, Rebellion General
- The current wax_wane_state is never displayed. Player can't tell which phase they're in.
- **Need:** Player avatar badge showing current moon phase (waxing/waning icon).

#### 37. `add_counter` progress invisible
- Cards: Cog Collector, Dragonfire Wizard
- Counter increments silently. No badge or progress indicator.
- **Need:** Counter badge on card showing current count / threshold.

### Low — Silent But Self-Evident on Refresh

#### 38. `attribute_changed` — Attribute silently changes
- Cards: Clockwork Apostle, Painted Troll
- **Need:** Card banner: "→ [New Attribute]"

#### 39. `transform_deck` — Entire deck silently replaced
- Cards: Gates of Madness
- **Need:** Toast: "Deck transformed!"

#### 40. `consume_all_creatures_in_discard_this_turn` — Silent consume
- Cards: Ruin Shambler
- **Need:** Toast: "Consumed N creatures from discard!"

### Already Covered by Existing Feedback
These Tier 3+ ops produce events already handled by `_record_feedback_from_events`:
- **summon_each_unique_from_deck, summon_all_from_discard_by_name, summon_random_from_collection** → `creature_summoned`
- **deal_damage_and_heal, player_battle_creature** → `damage_resolved` + `creature_destroyed`
- **trigger_all_friendly_summons, copy_summon_ability** → `creature_summoned`
- **copy_drawn_card_to_hand** → `card_drawn`
- **stitch_creatures_from_decks** → `creature_summoned`
