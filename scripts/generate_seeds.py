#!/usr/bin/env python3
"""
Generate _seed() calls for card_catalog.gd from scraped wiki data.

Produces data-only seeds (no triggered_abilities). Those get added later
via wiki-fix / audit-cards skills.

Usage:
    python3 scripts/generate_seeds.py
"""

import json
import re
from pathlib import Path
from collections import defaultdict

SCRAPED_DATA = Path(__file__).resolve().parent.parent / "data" / "wiki_scrape" / "cards.json"
OUTPUT_FILE = Path(__file__).resolve().parent.parent / "scripts" / "generated_seeds.gd"

# Sets to import (skip Core, Basic, HOS, HOM — already in catalog)
SKIP_SETS = {"Core Set", "Basic Cards", "Heroes of Skyrim", "Houses of Morrowind"}

# Set prefix mapping
SET_PREFIXES = {
    "Alliance War": "aw",
    "Moons of Elsweyr": "moe",
    "Jaws of Oblivion": "joo",
    "Dark Brotherhood": "db",
    "Clockwork City": "cws",
    "Isle of Madness": "iom",
    "Madhouse Collection": "mhc",
    "Forgotten Hero Collection": "fhc",
    "FrostSpark Collection": "fsc",
    "Tamriel Collection": "tc",
    "Monthly Cards": "mc",
    "Exclusive Cards": "exc",
    "Dawnguard": "dg",
}

SET_IDS = {
    "Alliance War": "alliance_war",
    "Moons of Elsweyr": "moons_of_elsweyr",
    "Jaws of Oblivion": "jaws_of_oblivion",
    "Dark Brotherhood": "dark_brotherhood",
    "Clockwork City": "clockwork_city",
    "Isle of Madness": "isle_of_madness",
    "Madhouse Collection": "madhouse_collection",
    "Forgotten Hero Collection": "forgotten_hero_collection",
    "FrostSpark Collection": "frostspark_collection",
    "Tamriel Collection": "tamriel_collection",
    "Monthly Cards": "monthly_cards",
    "Exclusive Cards": "exclusive_cards",
    "Dawnguard": "dawnguard",
}

ATTR_PREFIXES = {
    "Strength": "str",
    "Intelligence": "int",
    "Willpower": "wil",
    "Agility": "agi",
    "Endurance": "end",
    "Neutral": "neu",
}

KNOWN_KEYWORDS = {
    "breakthrough", "charge", "drain", "guard", "lethal",
    "mobilize", "rally", "regenerate", "ward",
}

# Extended keywords that go in keywords array
EXTENDED_KEYWORDS = {
    "assemble", "betray", "exalt", "plot", "treasure hunt",
    "veteran", "wax", "wane",
}

# Keywords/tags that go in rules_tags
RULES_TAGS = {"prophecy"}


def snake_case(name: str) -> str:
    """Convert card name to snake_case id component."""
    # Remove special characters, keep alphanumeric and spaces
    s = re.sub(r"[''']", "", name)
    s = re.sub(r"[^a-zA-Z0-9\s]", " ", s)
    s = re.sub(r"\s+", "_", s.strip())
    return s.lower()


def make_card_id(set_prefix: str, attributes: list[str], name: str, is_token: bool = False) -> str:
    """Generate a card_id following the project convention."""
    if len(attributes) >= 3:
        attr_prefix = "tri"
    elif len(attributes) >= 2:
        attr_prefix = "dual"
    elif attributes:
        attr_prefix = ATTR_PREFIXES.get(attributes[0], "neu")
    else:
        attr_prefix = "neu"

    return f"{set_prefix}_{attr_prefix}_{snake_case(name)}"


def parse_keywords_from_text(card_text: str) -> tuple[list[str], list[str], list[str]]:
    """Parse card text to extract keywords, rules_tags, and effect_ids."""
    keywords = []
    rules_tags = []
    effect_ids = []

    if not card_text:
        return keywords, rules_tags, effect_ids

    text_lower = card_text.lower()

    # Check for keywords
    for kw in KNOWN_KEYWORDS:
        if kw in text_lower:
            keywords.append(kw)

    # Check for Prophecy (goes in rules_tags)
    if "prophecy" in text_lower:
        rules_tags.append("prophecy")

    # Detect effect_ids from card text patterns
    patterns = {
        "summon": r"summon\s*:",
        "last_gasp": r"last gasp\s*:",
        "slay": r"slay\s*:",
        "pilfer": r"pilfer\s*:",
        "damage": r"deal \d+ damage",
        "destroy": r"destroy",
        "modify_stats": r"[+-]\d+/[+-]?\d+",
        "draw": r"draw",
        "heal": r"heal|restore",
        "silence": r"silence",
        "unsummon": r"return.*to.*hand|unsummon",
        "shackle": r"shackle",
        "move": r"move.*creature|move.*to.*lane",
        "steal": r"steal",
        "copy": r"copy|copies",
        "create": r"put.*into.*hand|summon.*from|create",
        "transform": r"transform",
        "equip": r"equip|\+\d+/\+\d+",
        "discard": r"discard",
        "support": r"uses\s*:",
        "beast_form": r"beast form",
        "betray": r"betray",
        "exalt": r"exalt",
        "plot": r"plot\s*:",
        "assemble": r"assemble",
        "invade": r"invade",
        "consume": r"consume",
        "empower": r"empower",
        "treasure_hunt": r"treasure hunt",
        "veteran": r"veteran",
        "expertise": r"expertise",
        "shout": r"shout",
    }

    for eid, pattern in patterns.items():
        if re.search(pattern, text_lower):
            effect_ids.append(eid)

    return keywords, rules_tags, effect_ids


def parse_item_equip(card_text: str) -> tuple[int, int, list[str]]:
    """Parse item rules_text for equip bonus fields."""
    equip_power = 0
    equip_health = 0
    equip_keywords = []

    if not card_text:
        return equip_power, equip_health, equip_keywords

    # Match +X/+Y pattern
    match = re.search(r"\+(\d+)/\+(\d+)", card_text)
    if match:
        equip_power = int(match.group(1))
        equip_health = int(match.group(2))

    # Match +X/+0 or +0/+X patterns
    if not match:
        match = re.search(r"\+(\d+)/\+(\d+)", card_text)

    # Standalone keywords on items are equip keywords (not after "Summon:", etc.)
    lines = card_text.split("\n")
    trigger_prefixes = ("summon", "last gasp", "slay", "pilfer", "activate", "uses")
    in_trigger = False
    for line in lines:
        line_stripped = line.strip().lower()
        if any(line_stripped.startswith(p) for p in trigger_prefixes):
            in_trigger = True
        if not in_trigger:
            for kw in KNOWN_KEYWORDS:
                if kw == line_stripped or kw in line_stripped.split(","):
                    equip_keywords.append(kw)

    return equip_power, equip_health, equip_keywords


def is_token(card: dict) -> bool:
    """Determine if a card is a token/non-collectible."""
    # Beast form transformed versions are always tokens
    if card.get("is_alternate_form"):
        return True
    # Cards from certain sets never have deck codes (Asia-exclusive)
    # so we can't use deck_code_id absence alone for those
    no_deck_code_sets = {"Dawnguard"}
    card_set = card.get("card_set_source", card.get("card_set", ""))
    if card_set in no_deck_code_sets:
        return False
    # For other sets, missing deck_code_id means token
    if not card.get("deck_code_id"):
        return True
    return False


def generate_seed(card: dict, set_prefix: str, set_const_prefix: str) -> str:
    """Generate a _seed() call for a card."""
    attrs = [a.lower() for a in card.get("attributes", ["Neutral"])]
    if attrs == ["neutral"]:
        attrs_arr = "[]"
    else:
        attrs_arr = "[" + ", ".join(f'"{a}"' for a in attrs) + "]"

    card_type = card.get("card_type", "creature").lower()
    cost = card.get("cost", 0)
    power = card.get("power", 0) or 0
    health = card.get("health", 0) or 0
    name = card.get("name", "")
    card_text = card.get("card_text", "")

    token = is_token(card)
    card_id = make_card_id(set_prefix, card.get("attributes", []), name, token)

    # Build extra dict
    extra = {}
    set_id_const = f"{set_const_prefix}_SET_ID"
    extra_parts = [f'"set_id": {set_id_const}']

    if not token:
        release_group_const = f"{set_const_prefix}_RELEASE_GROUP_ID"
        extra_parts.append(f'"release_group_id": {release_group_const}')

    rarity = card.get("rarity", "Common").lower()
    if rarity != "common":
        extra_parts.append(f'"rarity": "{rarity}"')

    if card.get("is_unique"):
        extra_parts.append('"is_unique": true')

    # Parse keywords and effects
    keywords, rules_tags, effect_ids = parse_keywords_from_text(card_text)

    if keywords:
        kw_str = "[" + ", ".join(f'"{k}"' for k in sorted(keywords)) + "]"
        extra_parts.append(f'"keywords": {kw_str}')

    if effect_ids:
        eid_str = "[" + ", ".join(f'"{e}"' for e in sorted(set(effect_ids))) + "]"
        extra_parts.append(f'"effect_ids": {eid_str}')

    subtypes = card.get("subtypes", [])
    if subtypes:
        st_str = "[" + ", ".join(f'"{s}"' for s in subtypes) + "]"
        extra_parts.append(f'"subtypes": {st_str}')

    # Clean up card_text for rules_text
    if card_text:
        # Normalize whitespace in card text
        rules_text = card_text.replace("\n", "\\n")
        # Remove excessive newlines from wiki parsing
        rules_text = re.sub(r"(\\n)+", "\\\\n", rules_text)
        extra_parts.append(f'"rules_text": "{rules_text}"')

    if rules_tags:
        rt_str = "[" + ", ".join(f'"{t}"' for t in rules_tags) + "]"
        extra_parts.append(f'"rules_tags": {rt_str}')

    # Item equip fields
    if card_type == "item":
        eq_power, eq_health, eq_keywords = parse_item_equip(card_text)
        if eq_power:
            extra_parts.append(f'"equip_power_bonus": {eq_power}')
        if eq_health:
            extra_parts.append(f'"equip_health_bonus": {eq_health}')
        if eq_keywords:
            ekw_str = "[" + ", ".join(f'"{k}"' for k in eq_keywords) + "]"
            extra_parts.append(f'"equip_keywords": {ekw_str}')

    # Support uses
    if card_type == "support" and card_text:
        uses_match = re.search(r"Uses\s*:\s*(\d+)", card_text, re.IGNORECASE)
        if uses_match:
            extra_parts.append(f'"support_uses": {uses_match.group(1)}')

    if token:
        extra_parts.append('"collectible": false')

    extra_str = "{" + ", ".join(extra_parts) + "}"

    return f'\t\t_seed("{card_id}", "{name}", {attrs_arr}, "{card_type}", {cost}, {power}, {health}, {extra_str}),'


def main():
    data = json.loads(SCRAPED_DATA.read_text())
    cards = data["cards"]

    # Group cards by set
    sets = defaultdict(list)
    for card in cards:
        set_name = card.get("card_set_source", card.get("card_set", ""))
        if set_name in SKIP_SETS:
            continue
        if set_name not in SET_PREFIXES:
            continue
        sets[set_name].append(card)

    # Generate constants and seeds
    lines = []
    const_lines = []

    # Generate set constants
    for set_name in SET_PREFIXES:
        if set_name in SKIP_SETS:
            continue
        prefix = SET_PREFIXES[set_name].upper()
        set_id = SET_IDS[set_name]
        const_lines.append(f'const {prefix}_SET_ID := "{set_id}"')
        const_lines.append(f'const {prefix}_RELEASE_GROUP_ID := "{SET_PREFIXES[set_name]}_pvp"')

    lines.append("# ═══ SET CONSTANTS (add to top of card_catalog.gd) ═══")
    lines.extend(const_lines)
    lines.append("")

    lines.append("# ═══ SEED CALLS (add inside _card_seeds() array) ═══")

    # Process each set
    set_order = [
        "Alliance War", "Moons of Elsweyr", "Jaws of Oblivion",
        "Dark Brotherhood", "Clockwork City", "Isle of Madness",
        "Madhouse Collection", "Forgotten Hero Collection",
        "FrostSpark Collection", "Tamriel Collection",
        "Monthly Cards", "Exclusive Cards", "Dawnguard",
    ]

    for set_name in set_order:
        if set_name not in sets:
            continue

        set_cards = sets[set_name]
        set_prefix = SET_PREFIXES[set_name]
        set_const_prefix = set_prefix.upper()

        # Separate collectible from tokens
        collectible = [c for c in set_cards if not is_token(c)]
        tokens = [c for c in set_cards if is_token(c)]

        # Group collectible by attribute
        by_attr = defaultdict(list)
        for card in collectible:
            attrs = card.get("attributes", ["Neutral"])
            if len(attrs) >= 3:
                key = "Triple-Attribute"
            elif len(attrs) >= 2:
                key = "Dual-Attribute"
            else:
                key = attrs[0]
            by_attr[key].append(card)

        attr_order = ["Strength", "Intelligence", "Willpower", "Agility",
                       "Endurance", "Neutral", "Dual-Attribute", "Triple-Attribute"]

        lines.append("")
        for attr in attr_order:
            if attr not in by_attr:
                continue
            attr_cards = sorted(by_attr[attr], key=lambda c: c["name"])
            lines.append(f"\t\t# ── {set_name.upper()} — {attr.upper()} ({len(attr_cards)} cards) ──")
            for card in attr_cards:
                lines.append(generate_seed(card, set_prefix, set_const_prefix))

        # Tokens
        if tokens:
            tokens_sorted = sorted(tokens, key=lambda c: c["name"])
            lines.append(f"\t\t# ── {set_name.upper()} — NON-COLLECTIBLE TOKENS ──")
            for card in tokens_sorted:
                lines.append(generate_seed(card, set_prefix, set_const_prefix))

    output = "\n".join(lines)
    OUTPUT_FILE.write_text(output)
    print(f"Generated seeds for {sum(len(v) for v in sets.values())} cards")
    print(f"Output: {OUTPUT_FILE}")

    # Summary
    for set_name in set_order:
        if set_name in sets:
            collectible = sum(1 for c in sets[set_name] if not is_token(c))
            tokens = sum(1 for c in sets[set_name] if is_token(c))
            print(f"  {set_name}: {collectible} collectible + {tokens} tokens")


if __name__ == "__main__":
    main()
