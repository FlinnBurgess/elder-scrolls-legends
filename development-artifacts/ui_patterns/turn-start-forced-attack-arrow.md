## Turn-Start Forced Attack Arrow

**Pattern ID:** `turn-start-forced-attack-arrow`

**Summary:** Animate an arrow from attacker to target for attacks that resolve automatically at the start of a turn (e.g. Umbra), showing the arrow on the pre-damage board before refreshing to reveal the result.

**Use when:** A card or mechanic causes a creature to automatically attack an enemy at the start of the controller's turn. The arrow provides visual clarity about what happened and who was targeted.

### How it works

1. **Engine side — resolve immediately, store metadata:** In `_resolve_forced_attacks` (match_turn_loop.gd), the attack resolves via `MatchCombat.resolve_attack` during `_start_turn`. Before resolving, the engine stores `match_state["_last_forced_attack"]` with `attacker_instance_id` and `target_instance_id`. This metadata is consumed by the UI.

2. **UI side — skip refresh, animate, then refresh:** Both turn-transition code paths (`_complete_end_turn` in match_screen.gd and the AI's `_execute_local_match_ai_step` else branch in match_screen_ai.gd) check for `_last_forced_attack`. If present, they **skip** `_refresh_ui()` and instead call `_animate_forced_attack_arrow.call_deferred(info)`. This is critical: the board must stay in its pre-damage state so the target creature's card button still exists for the arrow endpoint.

3. **UI side — arrow animation:** `_animate_forced_attack_arrow` (match_screen_feedback.gd) looks up card buttons by instance ID, draws a red bezier `Line2D` arrow from attacker to target (0.3s draw, 0.35s hold), then in the tween callback calls `_refresh_ui()` to reveal the damage/death result. If either button is missing (edge case), it falls back to an immediate `_refresh_ui()`.

### Key implementation details

- **The refresh must be skipped, not deferred.** If `_refresh_ui()` runs before the arrow, dead creatures lose their card buttons and the arrow has no endpoint. The animation runs on the stale board, then the callback refreshes to reveal the aftermath.
- **`call_deferred` is required** because the animation needs Godot's layout pass to compute `global_position` on card buttons. Without it, positions may be zero.
- **Two code paths:** The turn transition can come from the local player ending their turn (`_complete_end_turn`) or the AI ending its turn (`_execute_local_match_ai_step` else branch). Both must check for and consume `_last_forced_attack`.
- **Arrow style:** Red (`Color(0.95, 0.25, 0.2, 0.92)`), width 5.0, same bezier curve as enemy attack arrows via `_draw_spell_reveal_arrow_partial`.
- **Engine flag for detection:** The card property `grants_forced_attack_at_turn_start: true` on an attached item triggers the forced attack. This property must be propagated through `_seed()`, `_build_card()`, and `_hydrate_card()`.
- **Post-arrow checks:** After `_refresh_ui()` in the arrow callback, also check for `pending_visual_effects` (deferred trigger arrows) since those may have been generated during the forced attack's combat resolution.

### Files involved

| File | What it does |
|------|-------------|
| `src/core/match/match_turn_loop.gd` | `_resolve_forced_attacks` resolves the attack and stores `_last_forced_attack`; `_has_forced_attack_item` and `_pick_forced_attack_target` helpers |
| `src/ui/match_screen.gd` | `_complete_end_turn` checks for `_last_forced_attack` and skips refresh when present |
| `src/ui/match_screen_ai.gd` | AI end-turn else branch checks for `_last_forced_attack` and skips refresh when present |
| `src/ui/match_screen_feedback.gd` | `_animate_forced_attack_arrow` draws the arrow and calls `_refresh_ui()` in the cleanup callback |
| `src/deck/card_catalog.gd` | `grants_forced_attack_at_turn_start` in `_seed()` and `_build_card()` |
| `src/ui/match_screen.gd` | `_hydrate_card()` propagates `grants_forced_attack_at_turn_start` |

### Adding to a new card

To make another card force an automatic attack at the start of the controller's turn:

1. Add `"grants_forced_attack_at_turn_start": true` to the item's seed data in `card_catalog.gd`
2. No other changes needed — the turn loop, target selection, arrow animation, and UI integration are all generic

If the new card is a **creature** (not an item), you would need to modify `_has_forced_attack_item` to also check the creature's own properties, not just attached items.

### Example: Umbra

Card: "+3/+5. At the start of your turn, the wielder attacks a random enemy creature."

- Seed: `"grants_forced_attack_at_turn_start": true` (no `triggered_abilities` needed)
- Engine: `_resolve_forced_attacks` finds the wielder via `_has_forced_attack_item`, picks a same-lane enemy respecting guards via `_pick_forced_attack_target`, resolves via `MatchCombat.resolve_attack`
- UI: Red arrow animates from Chanter of Akatosh to the target creature, then board refreshes showing the damage/kill
