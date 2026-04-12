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
