#!/usr/bin/env python3
"""
Discover complex cards in the card catalog that may have unimplemented behaviour.

Parses card_catalog.gd, strips trivial rules text (keywords, stat bonuses, "Ongoing"),
removes simple cards, filters out cards mentioned in recent git history, and outputs
a sorted JSON list of complex cards for test-match generation.
"""

import json
import os
import re
import subprocess
import sys

CATALOG_PATH = os.path.join(os.path.dirname(__file__), "..", "src", "deck", "card_catalog.gd")
COMMIT_DEPTH = 200
MIN_REMAINING_LENGTH = 5  # after stripping, cards with fewer chars are considered trivial

KEYWORDS = [
    "Breakthrough", "Charge", "Cover", "Drain", "Guard", "Lethal",
    "Pilfer", "Prophecy", "Regenerate", "Ward", "Rally", "Slay",
    "Assemble", "Betray", "Exalt", "Invade", "Plot", "Treasure Hunt",
    "Veteran", "Wax", "Wane", "Last Gasp", "Shackle",
]

# Pattern: line that is only comma-separated keywords (with optional trailing whitespace)
KEYWORD_PATTERN = re.compile(
    r"^(" + "|".join(re.escape(k) for k in KEYWORDS) + r")"
    r"(,\s*(" + "|".join(re.escape(k) for k in KEYWORDS) + r"))*$",
    re.IGNORECASE,
)

# Stat bonus patterns: +N/+N, +N/+0, +0/+N, -N/-N variants
STAT_PATTERN = re.compile(r"^[+-]\d+/[+-]\d+$")

# "Ongoing" standalone line
ONGOING_PATTERN = re.compile(r"^Ongoing$", re.IGNORECASE)


def parse_catalog(path: str) -> list[dict]:
    """Extract card data from _seed() calls in card_catalog.gd."""
    with open(path, "r") as f:
        content = f.read()

    # Find the _card_seeds function region
    seeds_match = re.search(r"static func _card_seeds\(\)[^:]*:\s*\n\s*return \[", content)
    if not seeds_match:
        print("ERROR: Could not find _card_seeds() in catalog", file=sys.stderr)
        sys.exit(1)

    # Extract all _seed() calls - they span a single line each
    seed_pattern = re.compile(
        r'_seed\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*\[([^\]]*)\]\s*,\s*"([^"]+)"\s*,\s*'
        r'(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\{.*?\}))?\s*\)',
    )

    cards = []
    # Process line by line to handle the inline dicts properly
    for line in content.split("\n"):
        line = line.strip()
        if not line.startswith("_seed("):
            continue

        # Extract card_id and name with simple regex
        id_match = re.match(r'_seed\("([^"]+)",\s*"([^"]+)"', line)
        if not id_match:
            continue

        card_id = id_match.group(1)
        name = id_match.group(2)

        # Extract rules_text
        rt_match = re.search(r'"rules_text":\s*"((?:[^"\\]|\\.)*)"', line)
        rules_text = rt_match.group(1).replace("\\n", "\n") if rt_match else ""

        # Extract keywords array
        kw_match = re.search(r'"keywords":\s*\[([^\]]*)\]', line)
        keywords = re.findall(r'"([^"]+)"', kw_match.group(1)) if kw_match else []

        # Extract rules_tags array
        rt_tags_match = re.search(r'"rules_tags":\s*\[([^\]]*)\]', line)
        rules_tags = re.findall(r'"([^"]+)"', rt_tags_match.group(1)) if rt_tags_match else []

        # Extract card_type from positional args
        ct_match = re.search(
            r'_seed\("[^"]+",\s*"[^"]+",\s*\[[^\]]*\],\s*"([^"]+)"', line
        )
        card_type = ct_match.group(1) if ct_match else "creature"

        # Extract cost
        cost_match = re.search(
            r'_seed\("[^"]+",\s*"[^"]+",\s*\[[^\]]*\],\s*"[^"]+",\s*(\d+)', line
        )
        cost = int(cost_match.group(1)) if cost_match else 0

        # Extract attributes
        attr_match = re.search(r'_seed\("[^"]+",\s*"[^"]+",\s*\[([^\]]*)\]', line)
        attributes = re.findall(r'"([^"]+)"', attr_match.group(1)) if attr_match else []

        cards.append({
            "card_id": card_id,
            "name": name,
            "rules_text": rules_text,
            "keywords": keywords,
            "rules_tags": rules_tags,
            "card_type": card_type,
            "cost": cost,
            "attributes": attributes,
        })

    return cards


def strip_trivial_text(rules_text: str) -> str:
    """Remove keyword lines, stat bonuses, and 'Ongoing' from rules text."""
    lines = rules_text.split("\n")
    remaining = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if KEYWORD_PATTERN.match(stripped):
            continue
        if STAT_PATTERN.match(stripped):
            continue
        if ONGOING_PATTERN.match(stripped):
            continue
        remaining.append(stripped)
    return "\n".join(remaining)


def get_recently_fixed_cards(card_ids: list[str], card_names: list[str]) -> set[str]:
    """Check last N commit messages for card_id or name mentions.

    Only searches commit messages (not diffs) because diffs contain bulk card-id
    lists from test configs and registries that produce massive false positives.
    Commit messages are the high-signal source — developers mention cards by name
    or id when fixing them.
    """
    recently_fixed = set()

    repo_dir = os.path.dirname(os.path.abspath(CATALOG_PATH))

    # Get all commit messages at once
    result = subprocess.run(
        ["git", "log", f"-{COMMIT_DEPTH}", "--format=%s"],
        capture_output=True, text=True, cwd=repo_dir,
    )
    if result.returncode != 0:
        print(f"WARNING: git log failed: {result.stderr}", file=sys.stderr)
        return recently_fixed

    search_text = result.stdout

    for i, cid in enumerate(card_ids):
        name = card_names[i]
        # card_id substring match (namespaced, so safe)
        if cid.lower() in search_text.lower():
            recently_fixed.add(cid)
            continue
        # card name word-boundary match (skip short names to avoid false positives)
        if len(name) >= 4 and re.search(r"\b" + re.escape(name) + r"\b", search_text, re.IGNORECASE):
            recently_fixed.add(cid)

    return recently_fixed


def main():
    catalog_path = os.path.abspath(CATALOG_PATH)
    if not os.path.exists(catalog_path):
        print(f"ERROR: Catalog not found at {catalog_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Parsing catalog: {catalog_path}", file=sys.stderr)
    cards = parse_catalog(catalog_path)
    print(f"Found {len(cards)} cards", file=sys.stderr)

    # Strip trivial text and compute complexity
    for card in cards:
        card["stripped_text"] = strip_trivial_text(card["rules_text"])
        card["complexity"] = len(card["stripped_text"])

    # Filter out trivial cards
    complex_cards = [c for c in cards if c["complexity"] >= MIN_REMAINING_LENGTH]
    print(f"{len(complex_cards)} cards with non-trivial rules text", file=sys.stderr)

    # Filter out recently fixed cards
    card_ids = [c["card_id"] for c in complex_cards]
    card_names = [c["name"] for c in complex_cards]

    print(f"Checking last {COMMIT_DEPTH} commits for recently touched cards...", file=sys.stderr)
    recently_fixed = get_recently_fixed_cards(card_ids, card_names)
    print(f"{len(recently_fixed)} cards found in recent commit history", file=sys.stderr)

    filtered = [c for c in complex_cards if c["card_id"] not in recently_fixed]
    print(f"{len(filtered)} cards remaining after filtering", file=sys.stderr)

    # Sort by complexity descending
    filtered.sort(key=lambda c: c["complexity"], reverse=True)

    # Build output
    output = []
    for card in filtered:
        output.append({
            "card_id": card["card_id"],
            "name": card["name"],
            "card_type": card["card_type"],
            "cost": card["cost"],
            "attributes": card["attributes"],
            "rules_text": card["rules_text"],
            "stripped_text": card["stripped_text"],
            "complexity": card["complexity"],
        })

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
