---
name: run-match-audit
description: Run the headless AI-vs-AI match auditor to find gameplay bugs. Use when user wants to stress-test the engine, find card bugs automatically, run the auditor, or simulate matches — e.g. "run the auditor", "simulate some matches", "stress test the engine", "find bugs automatically".
---

# Run Match Audit

Run the headless AI-vs-AI match auditor, which plays full matches between two AI players using random decks from the entire card catalog and audits every trigger resolution and event for rule violations.

## Arguments

`$ARGUMENTS` — Optional. Can specify:
- A number of matches (e.g., "20 matches", "50") — updates `NUM_MATCHES` in the script before running
- A specific focus (e.g., "focus on invade cards", "test ward interactions") — noted for analysis but the auditor runs all checks regardless

If no arguments, run with the current default (10 matches).

## Step 1: Adjust Match Count (if requested)

If the user specified a match count, edit `tests/headless_match_auditor.gd` and change the `NUM_MATCHES` constant.

## Step 2: Run the Auditor

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/godot.log --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script res://tests/headless_match_auditor.gd
```

**Important:** This requires `dangerouslyDisableSandbox: true` because Godot writes to `~/Library/Application Support/Godot/` for logging.

Filter the output to show match results and violations:
```bash
... 2>&1 | grep -E "^(=|  Match|Matches|Total|Violations|HEADLESS|Writ|\[|    Check|    Detail)"
```

## Step 3: Report Results

Present a summary:
- How many matches ran, total actions, win distribution
- Number of violations found (0 = clean run)
- For each violation: the check type, the card involved, and what went wrong

## Step 4: Handle Violations

If violations were found:
1. The auditor automatically wrote bug report files to `reports/bug-reports/`
2. Note that these can be processed by the `fix-bug-reports` skill
3. Offer to investigate and fix the violations now, or let the user run `/fix-bug-reports` later
4. If fixing now, read the generated report files and follow the same investigation workflow as fix-bug-reports

If zero violations:
- Report a clean run
- No further action needed

## Current Audit Checks

The auditor validates:

| Check | What it catches |
|-------|----------------|
| `subtype_filter` | Effects with `target_filter_subtype` affecting cards without that subtype |
| `cost_lock_enforcement` | Cards played at a cost that was locked (e.g., by Seducer Darkfire) |
| `trigger_family_event_mismatch` | Triggers firing on the wrong event type (e.g., pilfer on summon) |
| `ward_not_consumed` | Ward still present after a `ward_removed` event |

## Notes

- Matches use random 30-card decks from all 1100+ cards in the catalog — good for broad coverage but not targeted testing
- Each match typically runs 15-23 turns with 50-90 actions
- The auditor re-uses deterministic seeds per match index, so the same match index always produces the same game (useful for reproducing issues)
- Bug reports are prefixed with `[AUDITOR:check_type]` in the comment field so fix-bug-reports can distinguish them from player-reported bugs
- If the auditor crashes mid-run (e.g., unhandled engine error), the matches before the crash still produce valid results
