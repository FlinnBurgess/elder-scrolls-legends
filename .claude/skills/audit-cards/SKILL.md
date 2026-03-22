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
   - **Validate `effect_ids`**: cross-check that every tag in the `effect_ids` array corresponds to an actual effect the card performs. Tags that don't match any op or behaviour in `triggered_abilities` / `aura` / keywords are spurious and should be flagged (e.g. a `"heal"` tag on a card that only draws cards).
   - **Check `is_unique`**: if the wiki lists the card as "Unique", verify `"is_unique": true` is present in the seed. This applies to named legendary characters and artifacts.
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

### Step 1b — Programmatic Op/Family Sweep

Before any agent work, run a script to extract every `"op"` value from `card_catalog.gd` and verify each one has a handler in `match_timing.gd` `_apply_effects()` or `extended_mechanic_packs.gd` `apply_custom_effect()`. This catches unimplemented ops instantly with zero false positives — it's the highest-value check in the entire audit. Flag any card referencing an unimplemented op as NEEDS_FIX regardless of other audit results.

Similarly, verify all `"family"` values exist in `FAMILY_SPECS` and all `action_target_mode` values are handled.

### Step 1c — Unimplemented Effect Sweep

Scan every `_seed()` call for cards that have `rules_text` describing an active ability but **no implementation data** backing it — no `triggered_abilities`, no `aura`, no `innate_statuses`, no `self_immunity`, no `grants_trigger`, no `grants_immunity`, no `equip_power_bonus`/`equip_health_bonus`, and no `first_turn_hand_cost`.

Exclude cards where `rules_text`:
- Is empty or absent
- Contains only keywords (`Guard`, `Charge`, `Drain`, `Ward`, `Lethal`, `Breakthrough`, `Regenerate`, `Prophecy`, `Rally`, or combinations thereof)
- Is purely flavour text (e.g. the Chicken)

Any card that promises an effect in its rules_text but has zero implementation fields is flagged as NEEDS_FIX with reason "unimplemented effect". This catches the Murkwater Butcher pattern — cards where the rules text was written but the effect was never wired up.

This check is fast (single file scan, no wiki fetches) and catches a class of bug that the op/family sweep misses, since these cards have no ops to verify in the first place.

### Step 1d — Skip Simple Cards

Before processing, auto-pass cards that have no meaningful logic to audit:

- **No `rules_text`** — vanilla creatures with only stats and subtypes (e.g., Whiterun Trooper)
- **Keyword-only `rules_text`** — cards whose text is purely static keywords like "Guard", "Charge", "Prophecy, Guard", etc., with no `triggered_abilities` or `aura` fields

These cards have no effect logic, auras, or conditions to validate. Mark them as `"pass"` in the progress file and skip them. This dramatically reduces the number of cards that need wiki fetches and engine checks.

Cards with any of the following **must still be audited**: `triggered_abilities`, `aura`, `self_immunity`, `innate_statuses`, `grants_immunity`, `grants_trigger`, `equip_power_bonus`/`equip_health_bonus` (items with stats), or `rules_text` describing abilities beyond keywords.

### Step 2 — Process Cards in Parallel Batches

Take the next 20 cards with `"status": "pending"` as the current batch.

**Phase 1 — Parallel Audit (Haiku agents):** Launch 5 Agent subagents simultaneously using `model: "haiku"`, each auditing 10 cards. Each agent:
1. For each card: fetches the UESP wiki page, compares all data fields, and checks that all ops/families/conditions are valid.
2. **Only reports NEEDS_FIX cards** with specific details. Passing cards are listed by name only (e.g., "PASS: Card A, Card B, Card C").
3. **Does NOT make edits** — audit only.
4. Uses the **known-good ops/families list** (see below) to skip re-verifying common mechanics. Only grep the engine for ops/families/conditions NOT on the list.
5. **Must receive FULL card seed data** — do not truncate. Haiku generates false positives when it can't see the complete `_seed()` call (especially for cards with long triggered_abilities arrays). Use `grep` to get the full line or `Read` with specific line offsets.

**Phase 2 — Verify and Fix (Opus):** After all Haiku agents complete, the main conversation (Opus):
1. **Spot-checks Haiku findings** before applying fixes. Haiku has a significant false positive rate (~30-50% on complex cards) due to misreading truncated data or hallucinating wiki discrepancies. Always verify by reading the actual card seed and comparing against wiki before editing.
2. Applies confirmed fixes to `card_catalog.gd` and any engine files, one card at a time.
3. Runs tests after each fix to ensure no regressions.
4. If tests fail, debug and resolve before moving to the next fix.
5. Game logic reasoning, new op implementation, and architectural decisions stay in Opus.

**Phase 3 — Update Progress:** After both phases complete, update `card_audit_progress.json` for all cards in the batch:
- `"pass"` — no issues found
- `"fixed"` — issues were found and resolved

### Known-Good Ops and Families (skip re-verification)

These have been verified to exist in the engine across prior audit batches. Agents should NOT grep for them — assume they work. Only grep for ops/families/conditions NOT on this list.

**Verified ops (match_timing.gd `_apply_effects`):**
modify_stats, deal_damage, grant_keyword, grant_random_keyword, remove_keyword, grant_status, silence, shackle, destroy_creature, unsummon, summon_from_effect, generate_card_to_hand, generate_card_to_deck, draw_cards, draw_filtered, copy_card_to_hand, copy_keywords_to_friendly, grant_extra_attack, double_stats, equip_items_from_discard, return_to_hand, reveal_opponent_top_deck, copy_from_opponent_deck, shuffle_hand_to_deck_and_draw, heal

**Verified ops (extended_mechanic_packs.gd `apply_custom_effect`):**
damage, escalating_damage, summon_random_from_catalog, generate_random_to_hand, draw_filtered_or_move_to_bottom, summon_random_by_target_cost, look_at_top_deck_may_discard, equip_random_item_from_catalog

**Verified families (match_timing.gd FAMILY_SPECS):**
summon, on_play, last_gasp, slay, pilfer, start_of_turn, end_of_turn, on_attack, on_damage, on_equip, on_ward_broken, after_action_played, activate, on_enemy_rune_destroyed, on_enemy_shackled, item_detached, expertise

**Verified conditions:**
required_top_deck_attribute, required_top_deck_card_type, required_subtype_on_board, required_wounded_enemy_in_lane, required_more_health, required_card_type_in_hand, required_played_card_type, min_noncreature_plays_this_turn, max_event_source_cost, require_source_uses_exhausted, required_friendly_higher_power

**Verified target modes:**
any_creature, creature_or_player, friendly_creature, enemy_creature, another_creature, another_friendly_creature, enemy_creature_in_lane

**Verified aura conditions:**
has_item, empty_hand, no_enemies_in_lane

### Step 3 — Continue to Next Batch

After completing a batch of 50:

1. Report a brief summary: how many passed, how many fixed, how many remain.
2. Immediately start the next batch of 50 pending cards. Do not pause for user confirmation.
3. Repeat until no pending cards remain.

### Step 4 — Final Report

When all cards have been processed:

1. Read the final state of `card_audit_progress.json`.
2. Report a summary to the user:
   - Total cards audited
   - Cards that passed with no issues
   - Cards that required fixes (list each with a brief description of what was fixed)
3. **Keep `card_audit_progress.json`** — do NOT delete it. It serves as a permanent record of which cards have been audited, so future runs can skip already-audited cards and only process newly added ones.

## Step 6 — Scan for Related Cards (skip during batch audit)

When running as part of the batch audit, **skip wiki-fix Step 6 (Scan for Related Cards)**. The batch audit will reach every card individually, so scanning for related cards would be redundant and slow things down. Each card gets its own full audit when its turn comes.

## Notes

- The `wiki-fix` skill handles all analysis and fix logic. This skill is purely orchestration.
- `development-artifacts/card_audit_progress.json` is a permanent artifact. If the process is interrupted, re-running `/audit-cards` picks up where it left off. After completion, it serves as a record of audited cards so future runs only process new additions.
- Card images are excluded from this audit — this is purely data, configuration, rules, and behaviour.
- The batch size of 50 (5 Haiku agents × 10 cards each) balances throughput with token efficiency.
- Haiku agents handle mechanical audit work (wiki fetches, field comparison, op/family verification). Opus handles game logic fixes and verifies Haiku findings.
- Agents are audit-only in Phase 1 — they read and analyse but do not edit files. This is critical for safe parallel execution.
- Agents should be terse — only detail NEEDS_FIX cards. Passing cards get a one-line mention.
- **Haiku false positive rate**: Haiku generates ~30-50% false positives on complex cards, especially when seed data is truncated. Always verify findings in Opus before applying fixes. Common false positives: misreading wiki data, claiming ops are missing when they're inside truncated triggered_abilities, flagging cosmetic effect_ids issues as functional bugs.
