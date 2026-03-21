---
name: download-missing-art
description: Download missing card art for all cards in the catalog. Finds cards without art, creates a tracking document, then fetches art for each one using the fetch-card-art skill.
---

# Download Missing Card Art

Batch-download artwork for all cards in the catalog that don't already have art files.

## Input

No arguments required. Operates on the full card catalog.

## Workflow

### Step 1 — Build the missing art list

1. Read `src/deck/card_catalog.gd` and extract every `_seed()` call. For each, capture:
   - `card_id` (1st argument, e.g. `"str_afflicted_alit"`)
   - `card_name` (2nd argument, e.g. `"Afflicted Alit"`)

   Use a regex like `_seed\(\s*"([^"]+)"\s*,\s*"([^"]+)"` to reliably extract both values.
2. Check `assets/images/cards/` for existing art files. A card has art if `assets/images/cards/<card_id>.png` exists.
3. Build a list of cards that are missing art (no matching PNG file).
4. If no cards are missing art, report "All cards have art" and stop.

### Step 2 — Create a tracking document

Create a temporary tracking file at `development-artifacts/missing_art_progress.md` with this format:

```markdown
# Missing Card Art Download Progress

Started: <current datetime>
Total missing: <count>
Completed: 0
Failed: 0

## Remaining
- [ ] Card Name (`card_id`)
- [ ] Card Name (`card_id`)
...

## Completed
(none yet)

## Failed
(none yet)
```

List all missing cards under **Remaining**.

### Step 3 — Download art for each card

Walk through every card in the **Remaining** list, one at a time:

1. Invoke the `fetch-card-art` skill with the card's name as the argument.
2. After each attempt, update `development-artifacts/missing_art_progress.md`:
   - If successful: move the card from **Remaining** to **Completed**, mark it `[x]`, and increment the Completed count.
   - If failed (wiki page not found, download blocked, no card art image on page, etc.): move the card from **Remaining** to **Failed** with a brief reason, and increment the Failed count.
3. Continue to the next card. Do not stop on failure — keep going until every card has been attempted.

### Step 4 — Final report and cleanup

1. Read the final state of `development-artifacts/missing_art_progress.md`.
2. Delete `development-artifacts/missing_art_progress.md`.
3. Report a summary to the user:
   - Total attempted
   - Successfully downloaded
   - Failed (list each failed card with the reason)

## Notes

- The `fetch-card-art` skill handles all the complexity of wiki URL construction, downloading, and verification. This skill is purely orchestration.
- If the process is interrupted, `development-artifacts/missing_art_progress.md` will remain on disk showing progress so far. The user can re-run the skill and it will pick up only cards still missing art (since Step 1 re-scans for missing files).
- Expect this to be a long-running operation for large catalogs. Progress is persisted after every card.