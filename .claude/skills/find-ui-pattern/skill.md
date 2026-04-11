---
name: find-ui-pattern
description: Find a reusable UI pattern from the catalog given a description of what you need. Use when implementing a new card or mechanic and you want to check if an existing UI pattern applies — e.g. "I need an arrow from one creature to another", "show damage after an animation", "defer an effect until a visual plays".
---

# Find UI Pattern

Search the reusable UI patterns catalog for patterns that match a described need.

## Arguments

A description of the UI behavior needed (e.g., "animate a line between two creatures then deal damage", "show a card flying from one zone to another", "delay an effect until after a visual").

## Workflow

### Step 1 — Read the catalog

Read `development-artifacts/reusable_ui_patterns.md` in full.

### Step 2 — Match patterns

For each pattern in the catalog, evaluate whether it matches the user's described need. Consider:
- Does the visual behavior match? (arrows, animations, floating numbers, overlays)
- Does the timing/flow match? (deferred effects, immediate feedback, multi-phase)
- Could the pattern be adapted even if it's not an exact match?

### Step 3 — Report findings

For each matching pattern, report:

1. **Pattern name and ID** — so the user can reference it
2. **Why it matches** — 1-2 sentences connecting the user's need to the pattern
3. **How to apply it** — specific guidance for the user's case, referencing the "Adding to a new..." section of the pattern
4. **Adaptations needed** — if the pattern isn't an exact match, what would need to change

If no patterns match, say so and briefly suggest how the needed pattern might be built (referencing existing patterns as starting points if applicable).
