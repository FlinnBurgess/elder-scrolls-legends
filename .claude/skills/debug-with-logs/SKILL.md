---
name: debug-with-logs
description: Debug a bug using the user's description and the match log file from the most recent game.
---

# Debug With Logs

Takes a bug description from the user, reads the match log file, and uses it to diagnose and fix the issue.

## Arguments

`$ARGUMENTS` — A description of the bug (e.g., "Guard creature was ignored during attack", "Summon effect didn't trigger for Morkul Gatekeeper", "creature stats are wrong after equipping an item").

## Step 1: Read Match Trace

Read `game_trace.txt` from the project root. It contains a verbose trace of the most recent match (wiped clean at each match start), including both human-readable game events and `[TRC]` engine trace lines. It may be large — read it in chunks using offset/limit (500 lines at a time). Read the **entire** file; do not skip sections.

If the file is empty or missing, tell the user and ask them to play a match first, then re-run this skill.

## Step 2: Search for Evidence

Based on the user's bug description, search the fetched output for relevant evidence. Use these log line types to guide your search:

### Log Line Types
- `[TRC]` — Engine trace lines showing function calls and internal state (`[TRC]|frame|Node|method|vars`). Use these for deep debugging of engine logic.
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

## Step 5: Add Regression Test

After implementing a fix, add a regression test that exercises the fixed behavior. This prevents the bug from recurring silently.

1. **Choose the right test runner** — pick the runner that best matches the fix area (e.g., `timing_runner.gd` for trigger fixes, `extended_mechanics_runner.gd` for custom effects, `items_and_supports_runner.gd` for item equip fixes, `combat_runner.gd` for combat bugs, `golden_match_runner.gd` for complex multi-step scenarios).
2. **Write a focused test function** — use `ScenarioFixtures` to set up a minimal match state that reproduces the scenario, invoke the relevant engine function (e.g., `MatchTiming.process_triggers`, `MatchCombat.resolve_attack`), and assert the correct outcome using `VerificationAsserts`.
3. **Name the test clearly** — use the pattern `_test_{description_of_what_was_fixed}` (e.g., `_test_guard_not_bypassed_with_cover`, `_test_drain_heals_on_lethal_kill`).
4. **Register the test** — add the test function call to the runner's `_run_all_tests()` method.

## Step 6: Verify

Run the relevant test runners to confirm the fix and new test pass. If the game is still running, suggest the user reproduce the scenario to verify the fix (they may need to restart the scene).
