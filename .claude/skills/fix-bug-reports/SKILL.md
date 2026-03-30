---
name: fix-bug-reports
description: Process all error reports from res://reports/bug-reports/ — analyze each bug, fix it, run tests, commit, and delete the report file. Ask for guidance on unclear reports.
model: opus
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
   d. **Pre-fix learnings scan**: Run the `scan-learnings` skill with a description of the bug area (e.g., "triggered abilities with target_mode", "item equip bonuses"). This surfaces known pitfalls before you start writing code. When processing a batch of reports, a single upfront scan covering all bug areas is acceptable — you don't need to scan per-report.
   e. **Check if already fixed**: If a recent commit appears to address the issue, verify the fix covers the reported scenario. If so, mark the task as completed, delete the report file, and move on — no new commit needed.
   f. If the report is unclear or requires a design decision, **ask the user for guidance** before proceeding
   g. Implement the fix
   h. **Post-fix learnings scan**: Run `scan-learnings` again with a more specific description now that you understand the problem deeply (e.g., "random target selection in match_timing"). This catches issues your fix may have introduced that weren't obvious before (e.g., using `randi()` where `_deterministic_index` is required).
   i. Run relevant test runners based on the fix area. Test runners live in `tests/` and are run with: `/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/godot.log --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script res://tests/<runner_name>.gd`
      **Important:** Godot test runners require `dangerouslyDisableSandbox: true` because Godot writes to `~/Library/Application Support/Godot/` for logging, and the sandbox blocks this — causing a segfault in `RotatedFileLogger::rotate_file()` that looks like an engine crash.
      - For match/UI fixes: `match_ui_runner.gd`, `all_rules_runner.gd`
      - For arena fixes: `arena_draft_engine_runner.gd`
      - For deck fixes: `deck_persistence_runner.gd`, `deck_validation_runner.gd`
      - For combat/card fixes: `combat_runner.gd`, `keyword_matrix_runner.gd`
      - For triggered abilities/shout/extended mechanics: `extended_mechanics_runner.gd`, `timing_runner.gd`
   j. If tests fail due to issues introduced by the fix, fix them before proceeding
   k. Commit the fix with a descriptive message
   l. **Delete the report file** — remove the `.json` file from `reports/bug-reports/` using a bash `rm` command
   m. Mark the task as `completed`
5. **Continue** until all reports are processed
6. **Summary** — after all reports are processed, present a final overview listing each report that was fixed (with a brief description of the bug and the fix applied), any reports that were skipped or deferred, and any remaining issues
7. **Pattern scan** — run the `bug-pattern-scan` skill to generalize the fixes into abstract pattern classes and scan for unresolved siblings across the codebase

## Deleting Reports

After each fix is committed, delete the report file immediately with `rm reports/bug-reports/<filename>.json`. This is simple and atomic — no need to rewrite a shared file.

If new reports appear during the run (new files detected when re-listing the directory), create tasks for them and process them after the original batch.

## Important Notes

- The snapshot provides rich context — use it to understand the exact game state when the bug was observed. However, some snapshot fields are unreliable: `runes` uses a stale `rune_count` field rather than actual `rune_thresholds`, so it may show all 5 runes even when some have been broken. Cross-reference with player health to infer actual rune state.
- **Baseline test failures**: Before the first fix, run the relevant test runners once to identify any pre-existing failures. Do not spend time debugging failures that exist before your changes.
- **User's report is authoritative for intended behavior**: When the user's comment states how a mechanic *should* work, treat that as the design intent for this game — don't dispute it based on original ESL rules. This game intentionally diverges from ESL in some areas. Only use web research when the report itself expresses uncertainty (e.g., "should it have?", "worth researching online") or asks you to verify.
- **Unreproducible reports — test-first triage**: Before tracing full code paths, write a targeted test that reproduces the reported scenario (e.g., summon a creature with the trigger, fire the event, assert the effect applied). If the test passes, the engine behavior is correct and the bug is likely a one-time UI rendering issue — dismiss it and keep the test for coverage. This is much faster than exhaustive code tracing. Only trace code paths if the test FAILS. Don't spend more than ~15 minutes on a single report with no clear code defect — present your findings and let the user decide.
- **Ambiguous root cause reports**: Sometimes a report's symptom has multiple plausible causes (e.g., "can't target" could be a targeting bug OR insufficient magicka) and the snapshot doesn't conclusively identify one. In these cases, enhancing the error report snapshot with additional diagnostic fields is a valid resolution — fix the observability gap so the next occurrence will be diagnosable. Present your analysis to the user and let them decide whether to dismiss the report or keep investigating.
- Do not skip reports unless the user explicitly asks you to defer one (e.g., "skip that one", "no obvious cause"). If skipped, leave the report file in place and note it in the summary.
- Always verify fixes with tests before committing
- Each fix gets its own commit — do not batch fixes. Exceptions for combining into a single commit: (1) two reports share the exact same root cause (e.g., both are "unimplemented op X"), (2) two fixes are deeply interleaved in the same files such that separating them without interactive staging would be error-prone (e.g., both add helper functions and call sites in the same module), or (3) multiple reports share the same bug class (e.g., three slay-related bugs touching the same subsystem). In cases (2) and (3), explain all fixes clearly in the commit message. When batching commits, also batch the corresponding file deletions.
- If a report describes something that isn't actually a bug (e.g., intended behavior), ask the user to confirm before removing it. However, if the report is clearly just a question about whether a feature works (e.g., "is rally implemented?") and the feature IS implemented correctly, you can dismiss it without asking — just note it in the summary.
- **Test/junk reports**: If reports are clearly test data (e.g., comments like "test report", "delete me", "ignore this"), present them to the user and offer to batch-clear them rather than creating individual tasks. Skip the full workflow for these.
- **Generated/copied card pitfall**: When fixing effects that create cards via `build_generated_card` (e.g., `sacrifice_and_resummon`, `summon_from_effect`, token generation), verify the template dict includes at minimum `card_type`, `power`, `health`, `base_power`, `base_health`, `keywords`, and `subtypes`. `build_generated_card` only auto-fills `triggered_abilities` from the catalog seed — all other fields must be in the template. A missing `card_type: "creature"` causes `validate_lane_entry` to reject the summon silently; missing health causes the card to die immediately after entering play.
- **Regression reports**: If a report describes a bug you already fixed in this session ("still doesn't work", "this happened again"), the previous fix didn't fully work. Before attempting a new fix, trace the code path end-to-end to find why the fix was bypassed — common causes include: early returns in match blocks making later checks unreachable, the fix being in a validation path that doesn't cover all play paths (e.g., drag-drop vs click), the fix checking the right condition but in the wrong function, or the **UI/presentation layer** showing wrong labels/options that cause the user to make the wrong selection (engine logic is correct but the UI misrepresents it). When the engine test passes but the user reports a regression, check the UI rendering path.
