---
name: audit-cards
description: Audit cards for data accuracy and engine correctness. Supports single-card audit (compare against UESP wiki, verify engine ops/targets/families, report PASS or NEEDS_FIX) or full-catalog batch audit with progress tracking.
---

# Audit All Cards

Systematically audit every card in the catalog by running the `wiki-fix` skill on each one in batches. Tracks progress in a JSON file so the process can be resumed if interrupted.

## Input

- **No arguments** — runs a full batch audit of the entire catalog.
- **Single card name** (e.g. `"Grahtwood Ambusher"`) — audits just that card. See "Single Card Mode" below.

## Single Card Mode

When the user asks to audit a specific card (optionally providing catalog data inline):

1. **Fetch the UESP wiki page** for the card and compare every field: name, attribute(s), type, cost, power, health, rarity, subtypes, keywords, and rules text.
2. **Verify engine integration** in `src/core/match/match_timing.gd` and `src/core/match/extended_mechanic_packs.gd` (ops may be handled in either file's `_apply_effects` / `apply_custom_effect`):
   - Each `op` in `effect_ids` / `triggered_abilities` is handled (e.g. `deal_damage`, `modify_stats`).
   - The `family` (e.g. `summon`, `last_gasp`) is a recognized trigger constant.
   - Each `target` value (e.g. `all_enemies_in_lane`) resolves correctly in `_resolve_card_targets`.
   - Each `target_mode` value (e.g. `creature_or_player`, `enemy_creature`) is handled in the targeting system — check both `match_timing.gd` (target list construction) and `extended_mechanic_packs.gd` (`_card_matches_target_mode`). Note: `target_mode` controls what the player can select as a target, while `target` in the effect dict controls what the effect actually hits.
   - **For item cards**: verify `equip_power_bonus`/`equip_health_bonus` values match the wiki's +X/+Y, confirm `equip_keywords` lists all granted keywords, and check that each keyword exists in `data/legends/registries/keyword_effect_registry.json`. Validate that `evergreen_rules.gd` reads these fields (`_sum_attached_item_bonus` for stats, `equip_keywords` array for keyword granting).
   - **For aura cards** (cards with an `aura` dict): verify each aura field is handled by `_get_aura_targets` in `match_timing.gd` — specifically that `scope` (e.g. `all_lanes`, `same_lane`, `self`), `target` (e.g. `all_friendly`, `other_friendly`), `filter_attribute`, `filter_subtype`, `power`, `health`, and `keywords` are all read and applied correctly. For support cards, confirm `recalculate_auras` collects aura sources from the support zone.
3. **Report** a field-by-field comparison table and a final verdict: **PASS** or **NEEDS_FIX** (with details).
4. If the user said "audit only" / "no edits", do not modify any files regardless of findings.

When finished, proceed to the full-catalog workflow below only if no single card was specified.

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

### Step 2 — Process Cards in Parallel Batches

Take the next 5 cards with `"status": "pending"` as the current batch.

**Phase 1 — Parallel Audit:** Launch 5 Agent subagents simultaneously (in a single message with multiple Agent tool calls), one per card. Each agent:
1. Runs the full `wiki-fix` analysis for its card (fetch wiki data, compare fields, code-level validation).
2. Reports back whether the card **passes** (no issues) or **needs fixes** (with details of what's wrong).
3. **Does NOT make edits** — audit only. This avoids conflicts from multiple agents editing `card_catalog.gd` concurrently.

**Phase 2 — Sequential Fixes:** After all 5 agents complete, for each card that needs fixes:
1. Apply the fixes to `card_catalog.gd` and any other files, one card at a time.
2. Run tests after each fix to ensure no regressions.
3. If tests fail, debug and resolve before moving to the next fix.

**Phase 3 — Update Progress:** After both phases complete, update `card_audit_progress.json` for all cards in the batch:
- `"pass"` — no issues found
- `"fixed"` — issues were found and resolved

### Step 3 — Continue to Next Batch

After completing a batch of 5:

1. Report a brief summary: how many passed, how many fixed, how many remain.
2. Immediately start the next batch of 5 pending cards. Do not pause for user confirmation.
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
- The batch size of 5 balances parallelism with agent overhead. Each batch launches 5 concurrent agents for audit, then applies any needed fixes sequentially to avoid file conflicts.
- Agents are audit-only in Phase 1 — they read and analyse but do not edit files. This is critical for safe parallel execution.
