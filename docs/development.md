# Development Notes

Loose collection of notes about the project's development-only tooling,
debug hotkeys, and how to iterate on specific subsystems. Add to this file
as new dev tools get built.

## Dev hotkeys

### Deck editor

| Shortcut | Action |
| --- | --- |
| `Ctrl+T` | Toggle the ESL PNG-template card rendering on/off for all cards currently visible in the browser grid. |
| `Ctrl+Shift+T` | Open the **ESL Template Adjuster** overlay (see below). |
| `"` (shift+`'`) | Open the error-report popover. |
| `←` / `→` | Previous / next browser page. |
| `↑` / `↓` | Cycle card-relationship alt-view on the hovered card. |

## ESL Template Adjuster

A dev screen for tuning the position/size of each in-card element on the
PNG frame overlay (Saiyan/tesl-card-generator style) across every card
rendering size used in-game.

### What it's for

The full-detail `CardDisplayComponent` can render cards with a layered PNG
frame template (enabled via `Ctrl+T` in the deck editor). The positions of
the cost orb, title banner, subtype, power/health gems, and rules text are
expressed as rectangles on the 440×680 reference PNG canvas and scaled
proportionally to the card's actual render size. Because the component
shows up at very different sizes (deck-list preview at 220×340, deck editor
cells around 290×449, in-hand hover at 400–600 px tall, etc.), it's useful
to tune those rectangles once and see them at every scale at the same time.

### Opening it

1. Start the game and navigate to the **Deck Editor** screen.
2. Press **`Ctrl+Shift+T`**.
3. The adjuster opens as a full-screen overlay. Press **`Esc`** or the
   *Close* button to return to the deck editor; when it closes the editor
   re-renders the browser grid so your changes are immediately visible.

### Using it

- **Left panel** — one group of four SpinBoxes (x / y / w / h) per rect:
  `art`, `cost`, `title`, `type`, `power`, `health`, `rules`. Values are in
  **PNG px** on the 440×680 reference canvas.
- **Right panel** — five sample cards rendered at the sizes the component
  actually appears at in-game:
    - Deck-list preview (220×340)
    - Deck-editor cell (290×449)
    - In-hand card (232×358)
    - Hover preview, 1080p viewport (294×454)
    - Hover preview, 1440p viewport (393×607)
- Every SpinBox change instantly re-lays out all five previews.
- **Save to JSON** writes `res://data/esl_template_adjustments.json`. On
  next game launch, `CardDisplayComponent.load_esl_overrides()` reads this
  file and replaces the in-code defaults, so the override applies
  everywhere (deck editor, match hover, match history, arena draft, etc.).
- **Reset to defaults** reverts the in-memory rects to the values hardcoded
  in `CardDisplayComponent.gd`. It does **not** delete the JSON file until
  you also hit Save.

### Promoting overrides into code

The override JSON is intended as a scratch pad. Once values look right:

1. Ask the developer assistant (or do it manually) to copy each rect's px
   values into the matching `static var ESL_*_RECT_N := Rect2(...)` lines
   near the top of `src/ui/components/CardDisplayComponent.gd`.
2. Delete `data/esl_template_adjustments.json` (the file is gitignored-by
   intent: defaults live in code, the JSON is just a temporary tuning
   output).

### Relevant files

- `src/ui/esl_template_adjuster_screen.gd` — the overlay UI.
- `src/ui/components/CardDisplayComponent.gd` — holds the `ESL_*_RECT_N`
  static vars, `load_esl_overrides()`, and the `_layout_full_esl()`
  implementation that consumes them.
- `assets/images/card_templates/` — the frame / rarity / power-health / art
  PNGs (from `Saiyan/tesl-card-generator`, mono / duo / trio variants).
- `data/esl_template_adjustments.json` — transient override file written by
  the adjuster's Save button. May not exist.
