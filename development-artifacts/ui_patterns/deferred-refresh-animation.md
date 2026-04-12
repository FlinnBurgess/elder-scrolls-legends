## Card-Specific Animation with Deferred UI Refresh

**Pattern ID:** `deferred-refresh-animation`

**Summary:** Play a card-specific animation by intercepting `_finalize_engine_result` before `_refresh_ui()` runs. The engine state is already fully resolved — the animation is purely visual, and the UI refresh is deferred to the cleanup callback so the old board state remains visible during the animation.

**Use when:** A specific card needs a dramatic visual (explosion, board wipe, transformation) that should play BEFORE the board updates to show the aftermath. Unlike `deferred-visual-arrow`, this does not defer engine-level effect resolution — all effects have already been applied.

### How it works

1. **Detection — `_record_feedback_from_events`:** Check events for the card's `definition_id` (via `_card_from_instance_id` on the event's `source_instance_id`). Capture relevant instance IDs and snapshot any target button positions/sizes from `_screen._card_buttons` (buttons still exist since `_refresh_ui` hasn't run yet). Store the data in a pending dictionary on `_animations` (e.g., `_soulburst_pending`).

2. **Intercept — `_finalize_engine_result`:** After `_record_feedback_from_events` but before `_refresh_ui()`, check if the pending dict is populated. If so, clear it, call the animation function via `call_deferred`, and `return result` early — skipping both `_refresh_ui()` and the post-action checks (`_check_pending_secondary_target`, etc.).

3. **Animation function:** Uses `call_deferred` so Godot's layout pass has run and button positions are final. Creates an overlay container (z_index 490+) with a dimmer (MOUSE_FILTER_STOP to block interaction). Builds visual stand-ins at the snapshotted positions. To suppress hover on real buttons during the animation, set `button.mouse_filter = MOUSE_FILTER_IGNORE` and/or guard `_on_lane_card_mouse_entered` with an active-animation instance ID check.

4. **Cleanup callback:** At animation end, call `_refresh_ui()` (board updates to post-effect state), run deferred visual checks and post-action checks, then `queue_free()` the container.

### Key implementation details

- **Real buttons stay visible:** Don't hide real card buttons at animation start — overlay on top of them. Hide them at the precise dramatic moment (e.g., when an explosion fires) so there's no flash of empty space.
- **`call_deferred` is required:** The animation function must be deferred so button `global_position` values are computed after the last layout pass.
- **Post-action checks in cleanup:** The cleanup callback must replicate the checks that `_finalize_engine_result` skipped: `pending_visual_effects`, `_check_pending_secondary_target`, `_check_pending_summon_effect_target`, `_check_pending_forced_play`.
- **Hover suppression:** Set `mouse_filter = MOUSE_FILTER_IGNORE` on targeted real buttons at animation start. Guard `_on_lane_card_mouse_entered` with an active-animation ID check. Both are naturally cleared when `_refresh_ui()` rebuilds buttons.

### Files involved

| File | What it does |
|------|-------------|
| `src/ui/match_screen_animations.gd` | Pending state variable, detection in `_record_feedback_from_events`, animation function, cleanup |
| `src/ui/match_screen.gd` | Intercept in `_finalize_engine_result` to skip refresh; hover guard in `_on_lane_card_mouse_entered` |

### Adding a new card-specific animation

1. Add a pending state variable on `MatchScreenAnimations` (e.g., `var _my_card_pending: Dictionary = {}`)
2. In `_record_feedback_from_events`, detect the card's event by `definition_id`, snapshot button positions, populate the pending dict
3. In `_finalize_engine_result`, check the pending dict before `_refresh_ui()` — if populated, clear it, `call_deferred` the animation, return early
4. Write the animation function: create container + dimmer, build visuals, tween, cleanup callback with `_refresh_ui()` + post-action checks
5. If the animation targets a board creature, suppress hover by setting `mouse_filter` and guarding `_on_lane_card_mouse_entered`
6. Clear the pending dict in the `else` branch of the intercept (for invalid results)

### Example: Soulburst

Card ability: "Banish a creature. Deal 3 damage to all enemies."

- Detection: `card_played` event where source `definition_id == "aw_neu_soulburst"`, captures `target_instance_id` and button position
- Animation: Purple burn shader overlay intensifies over 1.2s on the target creature, then card vanishes instantly as a purple ring pulse expands outward from the target off-screen (0.6s). Cleanup refreshes UI showing banished creature gone + AoE damage numbers.
- Hover suppressed on target button via `mouse_filter = MOUSE_FILTER_IGNORE` + `_soulburst_target_id` guard

### Relationship to `deferred-visual-arrow`

These patterns solve different problems:
- **`deferred-visual-arrow`**: Defers *engine-level* triggered ability resolution. The trigger's effects haven't been applied yet — the animation plays, then the engine resolves them. Used for reactive triggers (e.g., damage doublers).
- **`deferred-refresh-animation`**: Defers *UI refresh* only. All engine effects are already applied — the animation plays over the stale UI, then refresh reveals the aftermath. Used for dramatic card-specific visuals.
