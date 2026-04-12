---
name: add-ui-pattern
description: Add a reusable UI pattern to the catalog. Use when a new UI feature has been built and should be documented for future reuse — e.g. "add this animation pattern", "catalog this UI flow". Takes a description of the pattern and the relevant files.
---

# Add UI Pattern

Document a newly built UI pattern so it can be found and reused for future cards and mechanics.

Patterns are stored as individual files in `development-artifacts/ui_patterns/`, with an index in `development-artifacts/reusable_ui_patterns.md`.

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

### Step 2 — Check for duplicates

Read `development-artifacts/reusable_ui_patterns.md` to check if the pattern already exists. If it does, update the existing pattern file instead of creating a new one.

### Step 3 — Write the pattern file

Create a new file in `development-artifacts/ui_patterns/<pattern-id>.md` using this structure:

```markdown
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

### Step 4 — Update the index

Add an entry to `development-artifacts/reusable_ui_patterns.md` with this structure:

```markdown
---

### [Pattern Name](ui_patterns/<pattern-id>.md)

**ID:** `pattern-id`

One-sentence summary of what the pattern does.

**Use when:** Brief description of when to reach for this pattern.

**Key files:** The main files involved (short list)
```

The index entry should have enough context that someone scanning it can tell whether the pattern is relevant to their need — but all implementation details belong in the individual file.

### Step 5 — Confirm

Tell the user the pattern has been added and summarize what was documented.
