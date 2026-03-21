---
name: audit-cards
description: Systematically audit every card in the catalog for data accuracy and functional correctness. Compares against UESP wiki, validates engine integration, and fixes issues. Processes in batches of 10 with progress tracking.
---

# Audit All Cards

Systematically audit every card in the catalog by running the `wiki-fix` skill on each one in batches. Tracks progress in a JSON file so the process can be resumed if interrupted.

## Input

No arguments required. Operates on the full card catalog.

## Workflow

### Step 1 — Initialize or Resume Tracking

Check if `development-artifacts/card_audit_progress.json` exists.

**If it does not exist (first run):**

1. Read `src/deck/card_catalog.gd` and extract every top-level `_seed()` call. For each, capture:
   - `card_id` (1st argument)
   - `card_name` (2nd argument)
2. **Exclude non-collectible tokens** — only include cards defined as top-level `_seed()` calls. Inline `card_template` objects inside triggered_abilities are validated as part of their parent card's audit.
3. Create `development-artifacts/card_audit_progress.json` with this format:
   ```json
   {
     "started": "2026-03-21",
     "total": 400,
     "cards": [
       {"card_id": "str_afflicted_alit", "card_name": "Afflicted Alit", "status": "pending"},
       {"card_id": "str_nord_firebrand", "card_name": "Nord Firebrand", "status": "pending"}
     ]
   }
   ```

**If it already exists (resuming):**

1. Read the file and find the first card with `"status": "pending"`.
2. Report how many cards remain vs. how many have been processed.

### Step 2 — Process Cards in Batches

Take the next 10 cards with `"status": "pending"` as the current batch.

For each card in the batch:

1. **Invoke the `wiki-fix` skill** with the card's name as the argument.
   - wiki-fix will fetch wiki data, compare all fields, run code-level validation (effect ops exist, target modes handled, keywords recognized, conditions valid, synergy/alt-view integrity), fix any issues, and run tests.
   - If the wiki page cannot be fetched, wiki-fix will still run code-level checks (Steps 3e-3i in wiki-fix).

2. **After wiki-fix completes**, update the card's status in `card_audit_progress.json`:
   - `"pass"` — no issues found
   - `"fixed"` — issues were found and resolved

3. **If tests fail** after a fix, debug and resolve the test failures before moving to the next card. Never leave tests broken.

4. Move to the next card in the batch.

### Step 3 — Continue to Next Batch

After completing a batch of 10:

1. Report a brief summary: how many passed, how many fixed, how many remain.
2. Immediately start the next batch of 10 pending cards. Do not pause for user confirmation.
3. Repeat until no pending cards remain.

### Step 4 — Final Report and Cleanup

When all cards have been processed:

1. Read the final state of `card_audit_progress.json`.
2. Report a summary to the user:
   - Total cards audited
   - Cards that passed with no issues
   - Cards that required fixes (list each with a brief description of what was fixed)
3. Delete `development-artifacts/card_audit_progress.json`.

## Step 6 — Scan for Related Cards (skip during batch audit)

When running as part of the batch audit, **skip wiki-fix Step 6 (Scan for Related Cards)**. The batch audit will reach every card individually, so scanning for related cards would be redundant and slow things down. Each card gets its own full audit when its turn comes.

## Notes

- The `wiki-fix` skill handles all analysis and fix logic. This skill is purely orchestration.
- If the process is interrupted, `development-artifacts/card_audit_progress.json` persists on disk. Re-running `/audit-cards` picks up where it left off.
- Card images are excluded from this audit — this is purely data, configuration, rules, and behaviour.
- The batch size of 10 balances throughput with manageability. If a card requires complex engine-level fixes, the batch will take longer but progress is saved after each card.
