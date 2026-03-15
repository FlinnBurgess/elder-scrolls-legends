# Scan Match

Analyze the most recent game log to identify card effect issues, gameplay bugs, and missing implementations.

## Step 1: Read the Game Log

Read `game_log.txt` from the project root. It may be large — read it in chunks using offset/limit (500 lines at a time). Read the **entire** file; do not skip sections.

## Step 2: Identify Issues

Scan for the following categories of issues:

### Missing Effects
- Lines containing `>> WARNING: MISSING EFFECT` indicate cards played whose `effect_ids` are not covered by `triggered_abilities`, keywords, or equip fields.
- For each warning, note the card name, definition_id, uncovered effect_ids, and rules text.
- Deduplicate — report each unique card only once, regardless of how many times it appeared.

### Broken Triggers
- `[TRIGGER]` lines show effects that fired. Check whether they make sense:
  - Did a trigger fire for a card that shouldn't have had one?
  - Did a trigger produce unexpected results (e.g., wrong damage amount, wrong target)?
  - Did a summon-from-effect create the wrong creature?

### Combat Anomalies
- `[DAMAGE]` and `[DEATH]` lines show combat results. Check for:
  - Damage amounts that don't match the attacker's power shown in `[BOARD]` snapshots
  - Creatures dying when they should have survived (or vice versa)
  - Keywords not applying (e.g., Lethal not killing, Guard not being respected)

### Board State Issues
- `[BOARD]` snapshots show creature stats. Check for:
  - Stats that don't match what buffs/debuffs were applied
  - Creatures appearing in unexpected lanes
  - Creatures persisting after they should have been destroyed

### Event Ordering Issues
- Events should follow logical ordering (play -> summon -> triggers -> effects)
- Look for events that appear out of order or missing expected follow-up events

## Step 3: Cross-Reference Unfixed Cards

Read `development-artifacts/unfixed_card_effects.md` and check:
- Are any of the MISSING EFFECT warnings for cards already tracked there? If so, note them as "known — tracked in unfixed_card_effects.md" rather than new issues.
- Are there any NEW missing effect cards not yet tracked? These are the most important findings.

## Step 4: Report

Present findings organized as:

1. **New Missing Effects** — Cards with missing effects NOT already tracked in unfixed_card_effects.md. For each, include the card name, definition_id, uncovered effect_ids, and rules_text. These are actionable — suggest using `/fix-card-effect <card_name>` for each.

2. **Known Missing Effects** — Cards with missing effects that ARE already tracked. Just list the names briefly so the user knows they appeared in the match.

3. **Gameplay Bugs** — Any combat, trigger, board state, or event ordering issues found. Include the relevant log lines and explain what looks wrong.

4. **Summary** — A brief overall assessment: how many turns played, who won, how many unique issues found.
