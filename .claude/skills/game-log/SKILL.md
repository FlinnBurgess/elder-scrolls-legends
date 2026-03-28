---
name: game-log
description: Check the latest game log for evidence of a specific issue described by the user.
---

# Game Log

Check the latest game log for evidence of a specific issue described by the user.

## Arguments

`$ARGUMENTS` — Either a specific issue to investigate (e.g., "Morkul Gatekeeper didn't use its summon effect", "Guard was ignored", "creature had wrong stats after buff") or a general request like "summarise the last game".

**If the request is a general summary** (no specific bug), skip Steps 2-4 and instead provide: match duration (turns), key plays per player, board swings, final state, and any warnings logged. Keep it concise.

## Step 1: Read the Game Log

Read `game_log.txt` from the project root. It may be large — read it in chunks using offset/limit (500 lines at a time). Read the **entire** file; do not skip sections.

## Step 2: Search for Evidence

Based on the user's description, search the log for relevant evidence. Use the log format to guide your search:

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

## Step 3: Report

Present your findings concisely:

1. **Relevant log lines** — Quote the specific lines that show the issue (or the absence of expected lines). Include surrounding context so the user can understand the sequence of events.

2. **Analysis** — Explain what the log shows happened vs what should have happened, based on the user's description.

3. **Verdict** — State clearly whether the log confirms the reported issue or not. If the evidence is ambiguous, say so and explain why.

## Step 4: Fix the Bug (if confirmed)

If the log confirms a bug with a specific card's effect (wrong trigger, wrong target, wrong values), invoke the `/fix-card-effect` skill with the card name and a summary of what went wrong (derived from your analysis above).

If the bug is a system-level issue (e.g., missing win condition check, incorrect turn sequencing, broken rune logic) rather than a card-specific effect, investigate and fix the relevant engine code directly instead of using `/fix-card-effect`.
