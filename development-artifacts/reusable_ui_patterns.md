# Reusable UI Patterns

Catalog of established UI patterns in the match screen that can be reused for future cards and mechanics.

---

## Deferred Visual Effect with Arrow Animation

**Pattern ID:** `deferred-visual-arrow`

**Summary:** Defer a triggered effect's damage (or other side-effect) until after an arrow animation plays from a source creature to each target. The creature is genuinely still alive during the animation — no match state hacking.

**Use when:** A card's triggered ability should visually show "this creature is responsible for the follow-up effect" before the effect resolves. Examples: damage doublers, retaliatory damage triggers, reflected damage.

### How it works

1. **Engine side — family spec flag:** Add `"deferred_visual": true` to the trigger family's spec in `FAMILY_SPECS` (in `match_timing.gd`). This tells `publish_events` to skip applying the trigger's effects when the UI has opted into deferral.

2. **Engine side — `publish_events` deferral:** When `match_state["_defer_visual_effects"]` is `true` (set by the UI at match init), `publish_events` stores matching triggers in `match_state["pending_visual_effects"]` instead of calling `_apply_effects`. The trigger is still logged and marked as resolved — only the effect application is deferred.

3. **Engine side — `resolve_pending_visual_effects`:** A static function on `MatchTiming` that drains `pending_visual_effects`, calls `_apply_effects` for each, and publishes any generated events (damage, deaths, etc.) through the normal pipeline.

4. **UI side — detection:** In `_finalize_engine_result` (match_screen.gd), after `_refresh_ui()`, check `_match_state.get("pending_visual_effects", [])`. If non-empty, call the animation function via `call_deferred` (so Godot's layout pass computes button positions first).

5. **UI side — animation:** `_start_deferred_visual_animation` (match_screen_feedback.gd) reads the pending entries to get source/target instance IDs, looks up their card buttons for screen positions, and creates `Line2D` arrows animated via tweens (curved bezier, 0.25s draw, 0.55s total before cleanup).

6. **UI side — resolution callback:** After the arrow animation completes (tween callback), call `_resolve_deferred_visual_effects` which invokes the engine's `resolve_pending_visual_effects`, records feedback from the resulting events, and refreshes the UI. Post-action checks (pending targets, forced plays) also run here since they were deferred.

### Key implementation details

- **`_defer_visual_effects` flag:** Set on `_match_state` at every match init path in match_screen.gd. Tests don't set it, so engine behavior is unchanged for tests.
- **`call_deferred`:** The animation start MUST be deferred (`call_deferred`) because `_refresh_ui` creates new card buttons whose `global_position` isn't computed until Godot's next layout pass.
- **Arrow grouping:** Pending entries are grouped by `trigger.source_instance_id` so multiple targets from the same source creature (e.g., AoE) get simultaneous arrows from one origin.
- **Arrow style:** `Line2D`, width 5.0, color `Color(1.0, 0.85, 0.3, 0.95)` (yellow), drawn as a bezier curve via `_draw_spell_reveal_arrow_partial`.
- **Post-animation refresh:** `_resolve_deferred_visual_effects` calls `_record_feedback_from_events` with the new damage events, then `_refresh_ui`, producing standard red floating damage numbers.

### Files involved

| File | What it does |
|------|-------------|
| `src/core/match/match_timing.gd` | `FAMILY_SPECS` entry with `deferred_visual: true`; `publish_events` deferral logic; `resolve_pending_visual_effects()` |
| `src/ui/match_screen.gd` | Sets `_defer_visual_effects` flag; checks `pending_visual_effects` in `_finalize_engine_result` |
| `src/ui/match_screen_feedback.gd` | `_start_deferred_visual_animation()`, `_resolve_deferred_visual_effects()` |

### Adding to a new trigger family

To reuse this pattern for a new trigger family:

1. Define the family constant and spec in `match_timing.gd`, including `"deferred_visual": true`
2. Add the family to `get_supported_trigger_families()`
3. Add any needed condition checks in `match_triggers.gd` `_matches_conditions`
4. No UI changes needed — the existing `_finalize_engine_result` and animation code handle it generically

### Example: Renegade Magister

Card ability: "After a friendly action damages an enemy creature, deal that much damage to it again."

- Family: `after_friendly_action_damages_enemy`
- Spec: `{event_type: damage_resolved, match_role: controller, damage_kind: ability, target_type: creature, required_source_card_type: action, required_target_is_enemy: true, deferred_visual: true}`
- Effect: `{op: deal_damage, target: event_damaged_creature, amount_source: event_damage_amount}`
- Condition guards prevent infinite loops: Magister's own damage comes from a creature (not an action), so it doesn't re-trigger.

---

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
