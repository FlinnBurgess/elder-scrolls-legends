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

### Step 2 — Construct the wiki image URL

The UESP wiki stores card art images with this pattern:

```
https://images.uesp.net/<hash_path>/LG-cardart-<Wiki_Card_Name>.png
```

Since we don't know the hash path, fetch the card's wiki page to find the image:

1. Construct the wiki page URL: `https://en.uesp.net/wiki/Legends:<Card_Name>` (spaces replaced with underscores)
2. Fetch the page and look for an image URL containing `LG-cardart-` in the filename. If multiple matches exist (card art + alternate art variants), use the first one — it is the primary card art.
3. If found as a thumbnail URL (containing `/thumb/` and a size prefix like `132px-`), convert to the full-resolution URL by:
   - Removing `/thumb` from the path
   - Removing the size-prefixed filename at the end (e.g., `/132px-LG-cardart-Name.png`)
   - The result should be: `https://images.uesp.net/<hash_path>/LG-cardart-<Name>.png`

If the wiki page doesn't exist or has no card art image, report the error and stop.

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
