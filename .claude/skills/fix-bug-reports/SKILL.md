---
name: fix-bug-reports
description: Process all error reports from res://reports/bug-reports/ — analyze each bug, fix it, run tests, commit, and delete the report file. Ask for guidance on unclear reports.
---

# Fix Bug Reports

Process all in-game error reports that were submitted via the error reporting popover.

## Report Directory

- **Path:** `res://reports/bug-reports/` (Godot virtual path — use the actual filesystem path `reports/bug-reports/` relative to the project root when reading with tools)
- **Format:** Each report is a separate `.json` file with a random 8-character filename (e.g., `a3f9k2m1.json`)
- Each report contains:
  - `screen` — which screen the report was filed from (match, arena_draft, deck_editor)
  - `element_type` — the type of UI element reported on (card, lane, avatar, magicka, etc.)
  - `element_context` — human-readable description of the element
  - `comment` — the user's description of the issue
  - `snapshot` — full game state at time of submission (nested structure with board, players, match history, etc.)

## Workflow

1. **List report files** — glob for `reports/bug-reports/*.json` to find all pending reports. If none exist, report that there are no bug reports to process and stop.
2. **Read all reports** — read each JSON file and parse the contents.
3. **Create tasks** — use TaskCreate to create one task per report, with the comment as the subject.
   - **Group related reports**: Before diving in, scan all reports for shared themes (e.g., multiple slay-related bugs). Grouping lets you explore the relevant code once and fix related issues more efficiently. You can still create individual tasks, but investigate related reports together.
   - **Parallelize investigation**: When reports cluster around the same subsystem (e.g., 6 dragon card bugs), launch parallel Explore agents to investigate each bug's code path simultaneously. Apply fixes sequentially after investigation completes — the parallelism is for research, not editing.
4. **Process each report sequentially:**
   a. Mark the task as `in_progress`
   b. Analyse the report: read the `comment`, `element_context`, and `snapshot` to understand the bug
   c. Explore the codebase to locate the relevant code and read the card definition in `card_catalog.gd`
   d. **Check if already fixed**: If a recent commit appears to address the issue, verify the fix covers the reported scenario. If so, mark the task as completed, delete the report file, and move on — no new commit needed.
   e. If the report is unclear or requires a design decision, **ask the user for guidance** before proceeding
   f. Implement the fix
   g. Run relevant test runners based on the fix area. Test runners live in `tests/` and are run with: `/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/godot.log --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script res://tests/<runner_name>.gd`
      **Important:** Godot test runners require `dangerouslyDisableSandbox: true` because Godot writes to `~/Library/Application Support/Godot/` for logging, and the sandbox blocks this — causing a segfault in `RotatedFileLogger::rotate_file()` that looks like an engine crash.
      - For match/UI fixes: `match_ui_runner.gd`, `all_rules_runner.gd`
      - For arena fixes: `arena_draft_engine_runner.gd`
      - For deck fixes: `deck_persistence_runner.gd`, `deck_validation_runner.gd`
      - For combat/card fixes: `combat_runner.gd`, `keyword_matrix_runner.gd`
      - For triggered abilities/shout/extended mechanics: `extended_mechanics_runner.gd`, `timing_runner.gd`
   h. If tests fail due to issues introduced by the fix, fix them before proceeding
   i. Commit the fix with a descriptive message
   j. **Delete the report file** — remove the `.json` file from `reports/bug-reports/` using a bash `rm` command
   k. Mark the task as `completed`
5. **Continue** until all reports are processed
6. **Summary** — after all reports are processed, present a final overview listing each report that was fixed (with a brief description of the bug and the fix applied), any reports that were skipped or deferred, and any remaining issues. **Make sure it is concise, sacrifice grammar for concision**
7. **Pattern scan** — run the `bug-pattern-scan` skill to generalize the fixes into abstract pattern classes and scan for unresolved siblings across the codebase

## Deleting Reports

After each fix is committed, delete the report file immediately with `rm reports/bug-reports/<filename>.json`. This is simple and atomic — no need to rewrite a shared file.

If new reports appear during the run (new files detected when re-listing the directory), create tasks for them and process them after the original batch.
