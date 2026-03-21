---
name: fetch-card-art
description: Fetch a card's artwork from the UESP wiki and save it to the codebase. Use when user wants to download, fetch, or add card art/image for a specific card. Takes a card name as argument.
---

# Fetch Card Art

Download a card's artwork illustration from the UESP wiki and wire it up in the codebase.

## Input

A card name (e.g., "Lurking Crocodile"). Passed as the skill argument.

## Workflow

### Step 1 — Find the card_id

Search `src/deck/card_catalog.gd` for a `_seed()` call containing the card name (the second argument to `_seed`). Match case-insensitively. Extract the `card_id` (the first argument).

If the card name is not found in the catalog, report the error and stop.

If multiple cards match (e.g., "Slaughterfish" matches both "Slaughterfish" and "Slaughterfish Spawning"), prefer the exact match. If there is no exact match, list the candidates and ask the user to clarify.

### Step 2 — Find the wiki image URL

If the user provided a direct wiki URL (e.g., `https://en.uesp.net/wiki/File:LG-cardart-...`), fetch that page directly and extract the full-resolution image URL from it. Skip to the thumbnail-to-full conversion step below.

Otherwise, discover the image URL from the card's wiki page:

1. Construct the wiki page URL: `https://en.uesp.net/wiki/Legends:<Card_Name>` (spaces replaced with underscores)
2. Fetch the page and look for an image URL containing `LG-cardart-` (or its URL-encoded form `LG-cardart-` with `%28`/`%29` for parentheses, `%27` for apostrophes, etc.) in the filename. Card names with special characters like parentheses will be URL-encoded in the HTML. If multiple matches exist (card art + alternate art variants), use the first one — it is the primary card art.

**Thumbnail-to-full conversion:** If the URL contains `/thumb/` and a size prefix like `132px-`, convert to the full-resolution URL by:
- Removing `/thumb` from the path
- Removing the size-prefixed filename at the end (e.g., `/132px-LG-cardart-Name.png`)
- The result should be: `https://images.uesp.net/<hash_path>/LG-cardart-<Name>.<ext>`

**Fallback for disambiguation / Beast Form cards:** If the card page has no `LG-cardart-` image (common for Beast Form cards whose wiki pages are disambiguation redirects), try the `File:` page directly with subtype suffixes:
- `https://en.uesp.net/wiki/File:LG-cardart-<Card_Name>_(<Subtype>).png` (e.g., `Circle_Initiate_(Nord).png`)
- Also try `.jpg` if `.png` returns nothing
- The subtype to use (e.g., "Nord", "Werewolf") can be found in the card's `subtypes` field in the catalog `_seed()` call

If none of these attempts find card art, report the error and stop.

### Step 3 — Download and save the image

1. Download the full-resolution image using `curl` with a browser User-Agent header (Cloudflare blocks bare curl):
   ```
   curl -sL -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" "<url>" -o assets/images/cards/<card_id>.png
   ```
2. Verify the downloaded file is actually a PNG (not an HTML error page) using `file`. If it's HTML, the download was blocked — report the error.
3. If the image is not PNG, convert it to PNG using `sips -s format png` (macOS)
4. Save to: `assets/images/cards/<card_id>.png`

### Step 4 — Verify

Confirm the file was saved successfully by checking it exists and has a non-zero size.

Report success with the card name, card_id, and file path.

## Notes

- The `art_path` field is automatically set by `_build_card()` in `card_catalog.gd` using the convention `res://assets/images/cards/<card_id>.png`, so no catalog changes are needed per card.
- `CardDisplayComponent._resolve_art_texture()` will automatically pick up the new image on next load.
- If the image already exists at the target path, overwrite it with the fresh download.
- **Dual-form / transform cards** (e.g., Beast Form creatures): The base form uses the seeded `card_id` for its art path. Transform targets are inline `card_template`s with a `definition_id` — `card_relationship_resolver.gd` resolves their art to `res://assets/images/cards/<definition_id>.png`. To fetch art for both forms, download each separately using the appropriate ID. The wiki typically has separate pages for each form with disambiguators in parentheses, e.g., `Legends:Grim_Shield-Brother_(Nord)` and `Legends:Grim_Shield-Brother_(Werewolf)`.
