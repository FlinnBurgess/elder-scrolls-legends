# Reusable UI Patterns

Catalog of established UI patterns in the match screen. Each pattern has a dedicated file in `development-artifacts/ui_patterns/` with full implementation details.

---

### [Deferred Visual Effect with Arrow Animation](ui_patterns/deferred-visual-arrow.md)

**ID:** `deferred-visual-arrow`

Defer a triggered ability's effect resolution until after an arrow animation plays from the source creature to each target. The engine holds back `_apply_effects` — the animation plays while the creature is genuinely still alive, then the engine resolves.

**Use when:** A reactive trigger should visually show "this creature caused the effect" before the effect resolves — damage doublers, retaliatory damage, reflected damage.

**Key files:** `match_timing.gd` (deferred_visual flag), `match_screen.gd` (detection), `match_screen_feedback.gd` (arrow animation + resolution)

---

### [Card-Specific Animation with Deferred UI Refresh](ui_patterns/deferred-refresh-animation.md)

**ID:** `deferred-refresh-animation`

Play a dramatic card-specific animation before the board updates. All engine effects are already applied — the animation is purely visual over the stale UI, then `_refresh_ui()` runs in the cleanup callback to reveal the aftermath.

**Use when:** A specific card needs a dramatic visual (explosion, board wipe, transformation) that should play BEFORE the board updates to show results. Unlike `deferred-visual-arrow`, this does not defer engine resolution.

**Key files:** `match_screen_animations.gd` (pending state, detection, animation), `match_screen.gd` (intercept in `_finalize_engine_result`)
