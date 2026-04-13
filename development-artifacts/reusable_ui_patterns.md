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

---

### [Turn-Start Forced Attack Arrow](ui_patterns/turn-start-forced-attack-arrow.md)

**ID:** `turn-start-forced-attack-arrow`

Animate a red arrow from attacker to target for attacks that resolve automatically at the start of a turn. The arrow plays on the pre-damage board state, then refreshes to show the result. Engine resolves immediately and stores `_last_forced_attack` metadata for the UI.

**Use when:** A card forces a creature to automatically attack an enemy creature at the start of the controller's turn (e.g. Umbra's "the wielder attacks a random enemy creature").

**Key files:** `match_turn_loop.gd` (resolve + metadata), `match_screen.gd` / `match_screen_ai.gd` (detection + skip refresh), `match_screen_feedback.gd` (arrow animation + deferred refresh)

---

### [Deck-to-Hand Free Play with Auto-Detach](ui_patterns/deck-to-hand-free-play.md)

**ID:** `deck-to-hand-free-play`

Move a card from the deck into the player's hand as a free play, then immediately auto-detach it so it follows the cursor for normal lane-drop placement. All hand-play mechanics (lane validation, insertion preview, betray/sacrifice) work automatically.

**Use when:** A card effect pulls a creature from the deck and the player must choose where to place it — lane choice for summoned creatures, target choice for items pulled from deck.

**Key files:** `match_timing.gd` (deck-to-hand + free play entry + early return), `lane_rules.gd` (`_play_for_free` checks in summon and sacrifice), `match_screen_overlays.gd` (detect `needs_lane_choice`), `match_screen.gd` (`_pending_free_play_detach_id`), `match_screen_refresh.gd` (auto-detach)
