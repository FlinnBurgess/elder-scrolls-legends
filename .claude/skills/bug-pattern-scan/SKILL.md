---
name: bug-pattern-scan
description: After fixing bugs in a session, generalize the fixes into abstract pattern classes and scan the codebase for unresolved siblings. Use when you've made several fixes and want to find other instances of the same class of bug. Triggers on phrases like "scan for similar bugs", "find related issues", "pattern scan", "extrapolate fixes", "any other bugs like these".
---

# Bug Pattern Scan

After a session where bugs were fixed, generalize the fixes into abstract pattern classes and scan the entire codebase for unresolved instances of each class.

This skill is about **discovery, not specifics** — it surfaces issues the developer hasn't noticed yet by reasoning from concrete fixes to abstract patterns, then back to concrete candidates.

## Prerequisites

- This skill must be invoked **in the same conversation** where fixes were made. It relies on session context (the fixes you just made, the code you read, the reasoning behind each change) rather than git history.
- At least two fixes should have been made in the session to make pattern clustering meaningful. A single fix can still be scanned, but clustering won't apply.

## Workflow

### Phase 1 — Catalogue the session's fixes

Review all fixes made in the current conversation. For each fix, note:
- **What was broken** — the symptom (e.g., "effect did nothing")
- **Why it was broken** — the root cause (e.g., "handler didn't check this parameter value")
- **What was changed** — the structural fix (e.g., "added a branch to handle the new value")

### Phase 2 — Abstract and cluster

Group fixes by shared root cause into **abstract pattern classes**. A pattern class should be:
- **Generic** — described without referencing specific card names, function names, or variable names
- **Structural** — about a category of code defect, not a specific instance
- **Scannable** — it should be possible to search for other instances mechanically

Examples of good pattern classes:
- "Data definitions declare parameter values that the engine handler silently ignores"
- "Temporal metadata is written to objects but never checked or enforced"
- "Generated entities reference identifiers that don't correspond to existing resources"
- "Fallback/default paths mask missing implementations by returning zero/empty instead of erroring"

Aim to produce the fewest clusters that still capture distinct root causes. If two fixes share the exact same structural defect, they belong in one cluster. If the defects are structurally different even though the symptoms are similar, they are separate clusters.

### Phase 3 — Parallel scan

Launch one subagent per pattern class, **all in parallel**. Each subagent should:

1. Receive the abstract pattern description plus one or two concrete examples from the session (so it understands what to look for)
2. Determine the appropriate scan scope for the pattern — some patterns are localized to specific file pairs, others are codebase-wide
3. Choose the right scan approach:
   - **Grep-based** — when the pattern can be detected by searching for keywords or code shapes (e.g., missing art files)
   - **Structural cross-reference** — when the bug is the *absence* of code (e.g., parameter declared in data but not handled in engine). This requires reading both the data definitions and the handler code, then diffing what's declared vs. what's implemented.
   - **Hybrid** — grep to find candidates, then deep-read to confirm
4. For each candidate found, assess confidence:
   - **Confirmed** — traced the code path and verified the issue exists
   - **Likely** — strong structural match but didn't trace every code path; needs verification
5. For each candidate, draft a one-line suggested fix approach
6. Return all findings as a structured list

### Phase 4 — Report and create tasks

Present findings to the user as a structured report:

```
## Pattern Class: <abstract description>
Based on: <which session fixes this was derived from>
Findings: <count>

| # | Finding | Confidence | Suggested Fix |
|---|---------|------------|---------------|
| 1 | ...     | Confirmed  | ...           |
| 2 | ...     | Likely     | ...           |
```

After presenting the report, create one task per finding using TaskCreate. Each task should include:
- **Subject**: A concise description of the specific issue
- **Description**: The pattern class it belongs to, the specific finding, confidence level, and suggested fix approach

### Phase 5 — Offer to fix

After all tasks are created, offer to proceed with fixes:

> "I found N issues across M pattern classes. Want me to start fixing them? You can also tell me to skip specific findings or entire pattern classes."

If the user:
- **Accepts all** — proceed to fix, working through tasks sequentially
- **Accepts some** — delete tasks for declined findings, then proceed with the rest
- **Declines all** — delete all created tasks, summarize what was found for future reference

## Important Notes

- **Don't scan for things already fixed this session.** The whole point is to find *unresolved* siblings. If a fix in this session already addressed a class comprehensively (e.g., "I already handled all `*_source` values"), note it as covered and don't re-scan it.
- **False positives are worse than false negatives.** A scan that surfaces 50 "likely" issues wastes more time than one that surfaces 10 confirmed ones. Bias toward precision when assigning confidence.
- **The pattern should be the insight.** The most valuable output isn't the individual findings — it's the pattern class itself. A well-described pattern helps the developer think about their codebase differently.
- **Subagents should be thorough.** Instruct each subagent with `subagent_type: Explore` or `general-purpose` depending on the scan approach. For structural cross-reference scans, `general-purpose` is better since it may need to read many files and reason across them.
- **Don't duplicate work from the session.** If an agent already scanned for a pattern class during the session (before this skill was invoked), reference those findings rather than re-scanning. Only scan if the pattern class wasn't already explored.
