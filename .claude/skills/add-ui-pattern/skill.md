---
name: add-ui-pattern
description: Add a reusable UI pattern to the catalog. Use when a new UI feature has been built and should be documented for future reuse — e.g. "add this animation pattern", "catalog this UI flow". Takes a description of the pattern and the relevant files.
---

# Add UI Pattern

Document a newly built UI pattern in `development-artifacts/reusable_ui_patterns.md` so it can be found and reused for future cards and mechanics.

## Arguments

A description of the pattern to document (e.g., "the floating damage number system", "the card hover preview pattern").

## Workflow

### Step 1 — Understand the pattern

Read the relevant source files to understand:
- What the pattern does (user-visible behavior)
- When to use it (what kinds of cards/mechanics benefit)
- How it works (engine side, UI side, the flow between them)
- What files are involved
- How to reuse it for a new card/mechanic (step-by-step)

### Step 2 — Read existing catalog

Read `development-artifacts/reusable_ui_patterns.md` to understand the format and check for duplicates. If the pattern already exists, update it instead of adding a duplicate.

### Step 3 — Write the entry

Append a new section to the catalog using this structure:

```markdown
---

## [Pattern Name]

**Pattern ID:** `kebab-case-id`

**Summary:** One-sentence description.

**Use when:** When this pattern applies.

### How it works

Numbered steps explaining the flow from engine to UI.

### Key implementation details

Bullet points covering gotchas, timing, style, etc.

### Files involved

| File | What it does |
|------|-------------|

### Adding to a new [card/mechanic/etc.]

Step-by-step reuse instructions.

### Example: [Card Name]

Concrete example showing the pattern in use.
```

### Step 4 — Confirm

Tell the user the pattern has been added and summarize what was documented.
