---
name: debug-with-logs
description: Debug a bug using the user's description and live game logs fetched from the running Godot instance via MCP.
---

# Debug With Logs

Takes a bug description from the user, fetches the current game output from the running Godot instance, and uses the logs to diagnose and fix the issue.

## Arguments

`$ARGUMENTS` — A description of the bug (e.g., "Guard creature was ignored during attack", "Summon effect didn't trigger for Morkul Gatekeeper", "creature stats are wrong after equipping an item").

## Step 1: Fetch Game Logs

Use the `mcp__godot-peek__get_output` MCP tool to fetch the current game output from the running Godot instance. This retrieves the live engine output including game log lines, warnings, and errors.

If the output is empty or the game doesn't appear to be running, tell the user and ask them to reproduce the bug in-game first, then re-run this skill.

## Step 2: Search for Evidence

Based on the user's bug description, search the fetched output for relevant evidence. Use these log line types to guide your search:

### Log Line Types
- `[BOARD]` — Board state snapshots at the start of each turn, showing creature stats and HP
- `[PLAY]` — A card was played from hand
- `[SUMMON]` — A creature entered a lane
- `[TRIGGER]` — An effect fired (shows family, effect op, and target)
- `[DAMAGE]` — Damage was dealt (shows source, target, amount)
- `[DEATH]` — A creature was destroyed
- `[DRAW]` — A card was drawn
- `[RUNE]` — A rune was broken
- `[PROPHECY]` — A prophecy window opened
- `[MAGICKA]` — A player gained or spent magicka
- `>> WARNING: MISSING EFFECT` — A card's effect_ids are not covered by triggered_abilities

### What to Look For
- **Missing triggers**: A card was played/summoned but no `[TRIGGER]` line followed for an expected effect
- **Wrong targets**: A `[TRIGGER]` fired but targeted the wrong thing
- **Wrong values**: Damage amounts, stat modifications, or HP changes that don't match expectations
- **Missing events**: Expected events (damage, death, draw, etc.) that never appear
- **Wrong ordering**: Events appearing in an unexpected sequence
- **Board state inconsistencies**: Stats in `[BOARD]` snapshots that don't add up given prior events
- **Errors / stack traces**: Any GDScript errors, assertion failures, or null reference warnings

Also check for Godot-level errors (e.g., `ERROR:`, `SCRIPT ERROR:`, `Null instance`, `Invalid call`) that may point to crashes or unhandled edge cases.

## Step 3: Report Findings

Present your findings concisely:

1. **Relevant log lines** — Quote the specific lines that show the issue (or the absence of expected lines). Include surrounding context so the user can understand the sequence of events.

2. **Analysis** — Explain what the log shows happened vs what should have happened, based on the user's description.

3. **Verdict** — State clearly whether the log confirms the reported issue or not. If the evidence is ambiguous, say so and explain why.

## Step 4: Fix the Bug

If the log confirms a bug:

- **Card-specific effect bug** (wrong trigger, wrong target, wrong values, missing effect): invoke the `/fix-card-effect` skill with the card name and a summary of what went wrong.

- **System-level bug** (engine logic, turn sequencing, rune logic, UI glitch, null reference): investigate and fix the relevant engine code directly. Use jCodemunch tools to locate the relevant source files, understand the code, and implement the fix.

- **Data bug** (wrong stats, wrong keywords, wrong cost in card definition): fix the card data in the catalog/seeds directly.

After fixing, if the game is still running, suggest the user reproduce the scenario to verify the fix (they may need to restart the scene).
