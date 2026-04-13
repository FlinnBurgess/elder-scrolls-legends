## Deck-to-Hand Free Play with Auto-Detach

**Pattern ID:** `deck-to-hand-free-play`

**Summary:** Move a card from the deck into the player's hand as a free play, then immediately auto-detach it so it follows the cursor for normal lane-drop placement.

**Use when:** A card effect pulls a creature (or other card) from the deck and the player must choose where to place it — e.g. choosing a lane for a summoned creature, choosing a target for an item. The card should behave exactly as if the player grabbed it from hand: full drag-drop, insertion preview, betray/sacrifice for full lanes, lane validation.

### How it works

1. **Engine effect** sets `needs_lane_choice: true` in the `then_context` of the pending deck selection.
2. **`resolve_pending_deck_selection`** detects `needs_lane_choice` and instead of auto-summoning:
   - Removes the card from the deck
   - Sets `zone = "hand"` and `_play_for_free = true` on the card
   - Appends the card to the player's hand array
   - Creates a `pending_free_plays` entry (player_id, instance_id, source_instance_id)
   - Emits a `free_play_granted` event
   - **Returns early** — does NOT fall through to the auto-lane-pick code
3. **UI overlay callback** (`_on_deck_selection_chosen`) detects `needs_lane_choice` in the result and calls `_enter_deck_summon_placement(card_data)`.
4. **`_enter_deck_summon_placement`** sets `_pending_free_play_detach_id` to the card's instance_id and calls `_refresh_ui()`.
5. **`_refresh_ui`** sees `_pending_free_play_detach_id` is set and calls `_hand._detach_hand_card.call_deferred(id, true)` — the card is immediately detached from the hand row and follows the cursor.
6. **Player drops the card** on a lane. The existing hand-play mechanics handle everything: `play_selected_to_lane` -> `LaneRules.summon_from_hand` (which checks `_play_for_free` and skips magicka). Betray/sacrifice for full lanes also works because `summon_with_sacrifice` checks `_play_for_free`.
7. **Right-click** declines the free play — the card stays in hand as a normal (non-free) card.

### Key implementation details

- **Early return is critical.** The `needs_lane_choice` block in `resolve_pending_deck_selection` MUST return before the fallthrough auto-lane-pick code. Forgetting this causes a double-summon bug (card appears in hand AND in a lane).
- **`_play_for_free` flag** is the standard mechanism. Do NOT invent custom flags — the existing free play system handles magicka bypass, pending state, and cleanup.
- **`pending_free_plays` entry is required.** Without it, `consume_pending_free_play` has nothing to clean up, leaving stale state that blocks the UI.
- **`summon_with_sacrifice` must also check `_play_for_free`.** Both `validate_summon_with_sacrifice` and `summon_with_sacrifice` need to check `card.get("_play_for_free")` and set `options["played_for_free"] = true`, then consume the pending free play after summoning. Without this, sacrifice in a full lane silently fails or leaves stale state.
- **Auto-detach timing:** `_pending_free_play_detach_id` is consumed during `_refresh_ui` → `_refresh._refresh_ui()`, which calls `_detach_hand_card.call_deferred`. The card never visually appears in the hand row because the detach fires in the same frame.

### Files involved

| File | What it does |
|------|-------------|
| `effect_summon.gd` | Sets `needs_lane_choice: true` in `then_context` for creature deck selections |
| `match_timing.gd` | `resolve_pending_deck_selection` → `summon_creature_from_deck` handles the `needs_lane_choice` branch: card to hand, free play entry, early return |
| `lane_rules.gd` | `summon_from_hand` checks `_play_for_free` to skip magicka; `summon_with_sacrifice` also checks it (both validate and execute) |
| `match_screen_overlays.gd` | `_on_deck_selection_chosen` detects `needs_lane_choice` in result, calls `_enter_deck_summon_placement` |
| `match_screen.gd` | `_enter_deck_summon_placement` sets `_pending_free_play_detach_id` and refreshes |
| `match_screen_refresh.gd` | Consumes `_pending_free_play_detach_id` and calls `_detach_hand_card.call_deferred` |
| `match_screen_hand.gd` | `_detach_hand_card` creates the floating card preview that follows the cursor |

### Adding to a new card

1. In the **effect handler** (e.g. `effect_summon.gd`, `effect_draw.gd`), when creating the `pending_deck_selections` entry, set `then_context["needs_lane_choice"] = true` for the `then_op` that needs player placement.
2. In **`resolve_pending_deck_selection`** (`match_timing.gd`), add a `needs_lane_choice` check inside the relevant `then_op` branch — copy the pattern from `summon_creature_from_deck`: card to hand, `_play_for_free`, `pending_free_plays` entry, event, **early return**.
3. The UI side (`_on_deck_selection_chosen` → `_enter_deck_summon_placement`) is already generic — it checks `result.get("needs_lane_choice")` regardless of which card triggered it.

### Example: Halls of Colossus

Halls of Colossus uses `summon_from_deck_filtered` with a Dragon subtype filter. The effect creates a deck selection with `then_op: "summon_creature_from_deck"` and `then_context: {needs_lane_choice: true}`. When the player picks a Dragon, the engine moves it to hand as a free play. The UI auto-detaches it so it follows the cursor. The player drops it on a lane (or sacrifices a creature in a full lane) using the same mechanics as playing any hand card.
