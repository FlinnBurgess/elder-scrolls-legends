---
name: fix-bug-reports
description: Process all error reports from res://reports/error_reports.jsonl — analyze each bug, fix it, run tests, commit, and remove the entry. Ask for guidance on unclear reports.
---

# Fix Bug Reports

Process all in-game error reports that were submitted via the error reporting popover.

## Report File

- **Path:** `res://reports/error_reports.jsonl`
- **Format:** JSONL — one JSON object per line
- Each report contains:
  - `screen` — which screen the report was filed from (match, arena_draft, deck_editor)
  - `element_type` — the type of UI element reported on (card, lane, avatar, magicka, etc.)
  - `element_context` — human-readable description of the element
  - `comment` — the user's description of the issue
  - `snapshot` — full game state at time of submission (nested structure with board, players, match history, etc.)

## Workflow

1. **Read the report file** — load `res://reports/error_reports.jsonl` and parse each line as JSON
2. **Create tasks** — use TaskCreate to create one task per report, with the comment as the subject
3. **Process each report sequentially:**
   a. Mark the task as `in_progress`
   b. Analyse the report: read the `comment`, `element_context`, and `snapshot` to understand the bug
   c. Explore the codebase to locate the relevant code
   d. If the report is unclear or requires a design decision, **ask the user for guidance** before proceeding
   e. Implement the fix
   f. Run relevant test runners based on the fix area. Test runners live in `tests/` and are run with: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script res://tests/<runner_name>.gd`
      - For match/UI fixes: `match_ui_runner.gd`, `all_rules_runner.gd`
      - For arena fixes: `arena_draft_engine_runner.gd`
      - For deck fixes: `deck_persistence_runner.gd`, `deck_validation_runner.gd`
      - For combat/card fixes: `combat_runner.gd`, `keyword_matrix_runner.gd`
      - For triggered abilities/shout/extended mechanics: `extended_mechanics_runner.gd`, `timing_runner.gd`
   g. If tests fail due to issues introduced by the fix, fix them before proceeding
   i. Commit the fix with a descriptive message
   j. Remove the processed report entry from the JSONL file (rewrite the file without that line)
   k. Mark the task as `completed`
4. **Continue** until all reports are processed
5. **Summary** — after all reports are processed, present a final overview listing each report that was fixed (with a brief description of the bug and the fix applied), any reports that were skipped or deferred, and any remaining issues

## Removing Entries

After each fix is committed, immediately remove the corresponding line from the JSONL file:
- Read the entire file
- Remove the line that matches the processed report
- Write the remaining lines back

This ensures that if the skill is interrupted mid-run, completed reports are already removed.

## Important Notes

- The snapshot provides rich context — use it to understand the exact game state when the bug was observed
- **Baseline test failures**: Before the first fix, run the relevant test runners once to identify any pre-existing failures. Do not spend time debugging failures that exist before your changes.
- **Web research**: If a report suggests the correct behavior is uncertain (e.g., "should it have?", "worth researching online"), use WebSearch/WebFetch to check the UESP wiki or community sources for the canonical game behavior before implementing.
- Do not skip reports — process all of them
- Always verify fixes with tests before committing
- Each fix gets its own commit — do not batch fixes
- If a report describes something that isn't actually a bug (e.g., intended behavior), ask the user to confirm before removing it
- **Test/junk reports**: If reports are clearly test data (e.g., comments like "test report", "delete me", "ignore this"), present them to the user and offer to batch-clear them rather than creating individual tasks. Skip the full workflow for these.
