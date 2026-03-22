---
name: fix-bug-reports
description: Process all error reports from res://reports/error_reports.jsonl — analyze each bug, fix it, run tests, commit, and remove the entry. Ask for guidance on unclear reports.
---

# Fix Bug Reports

Process all in-game error reports that were submitted via the error reporting popover.

## Report File

- **Path:** `res://reports/error_reports.jsonl` (Godot virtual path — use the actual filesystem path `reports/error_reports.jsonl` relative to the project root when reading with tools)
- **Format:** JSONL — one JSON object per line
- Each report contains:
  - `screen` — which screen the report was filed from (match, arena_draft, deck_editor)
  - `element_type` — the type of UI element reported on (card, lane, avatar, magicka, etc.)
  - `element_context` — human-readable description of the element
  - `comment` — the user's description of the issue
  - `snapshot` — full game state at time of submission (nested structure with board, players, match history, etc.)

## Workflow

1. **Read the report file** — load `res://reports/error_reports.jsonl` and parse each line as JSON. The file may exceed token limits — run `wc -l` first to know the total line count, then read in chunks if needed. Filter out empty lines (the file often has blank first/last lines).
2. **Create tasks** — use TaskCreate to create one task per report, with the comment as the subject. Ensure you've read ALL lines before creating tasks — missing reports due to truncated reads leads to discovering them mid-run.
3. **Process each report sequentially:**
   a. Mark the task as `in_progress`
   b. Analyse the report: read the `comment`, `element_context`, and `snapshot` to understand the bug
   c. Explore the codebase to locate the relevant code
   d. **Check if already fixed**: If a recent commit appears to address the issue, verify the fix covers the reported scenario. If so, mark the task as completed, remove the report entry, and move on — no new commit needed.
   e. If the report is unclear or requires a design decision, **ask the user for guidance** before proceeding
   f. Implement the fix
   g. Run relevant test runners based on the fix area. Test runners live in `tests/` and are run with: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script res://tests/<runner_name>.gd`
      - For match/UI fixes: `match_ui_runner.gd`, `all_rules_runner.gd`
      - For arena fixes: `arena_draft_engine_runner.gd`
      - For deck fixes: `deck_persistence_runner.gd`, `deck_validation_runner.gd`
      - For combat/card fixes: `combat_runner.gd`, `keyword_matrix_runner.gd`
      - For triggered abilities/shout/extended mechanics: `extended_mechanics_runner.gd`, `timing_runner.gd`
   h. If tests fail due to issues introduced by the fix, fix them before proceeding
   i. Commit the fix with a descriptive message
   j. Remove the processed report entry from the JSONL file (rewrite the file without that line)
   k. Mark the task as `completed`
4. **Continue** until all reports are processed
5. **Summary** — after all reports are processed, present a final overview listing each report that was fixed (with a brief description of the bug and the fix applied), any reports that were skipped or deferred, and any remaining issues

## Removing Entries

After each fix is committed, immediately remove the corresponding line from the JSONL file:
- **Re-read the entire file first** — the user may have added new reports while you were working
- Identify the line to remove by **exact full-line match** against the original report JSON you processed — never use keyword substring matching, as it can accidentally delete unrelated reports that share words
- Write the remaining lines back

This ensures that if the skill is interrupted mid-run, completed reports are already removed, and new reports added concurrently are preserved.

If new reports appear during the run (detected when re-reading the file), create tasks for them and process them after the original batch.

## Important Notes

- The snapshot provides rich context — use it to understand the exact game state when the bug was observed
- **Baseline test failures**: Before the first fix, run the relevant test runners once to identify any pre-existing failures. Do not spend time debugging failures that exist before your changes.
- **Web research**: If a report suggests the correct behavior is uncertain (e.g., "should it have?", "worth researching online"), use WebSearch/WebFetch to check the UESP wiki or community sources for the canonical game behavior before implementing.
- Do not skip reports — process all of them
- Always verify fixes with tests before committing
- Each fix gets its own commit — do not batch fixes. Exceptions for combining into a single commit: (1) two reports share the exact same root cause (e.g., both are "unimplemented op X"), or (2) two fixes are deeply interleaved in the same files such that separating them without interactive staging would be error-prone (e.g., both add helper functions and call sites in the same module). In case (2), explain both fixes clearly in the commit message.
- If a report describes something that isn't actually a bug (e.g., intended behavior), ask the user to confirm before removing it. However, if the report is clearly just a question about whether a feature works (e.g., "is rally implemented?") and the feature IS implemented correctly, you can dismiss it without asking — just note it in the summary.
- **Test/junk reports**: If reports are clearly test data (e.g., comments like "test report", "delete me", "ignore this"), present them to the user and offer to batch-clear them rather than creating individual tasks. Skip the full workflow for these.
- **Regression reports**: If a report describes a bug you already fixed in this session ("still doesn't work", "this happened again"), the previous fix didn't fully work. Before attempting a new fix, trace the code path end-to-end to find why the fix was bypassed — common causes include: early returns in match blocks making later checks unreachable, the fix being in a validation path that doesn't cover all play paths (e.g., drag-drop vs click), or the fix checking the right condition but in the wrong function.
