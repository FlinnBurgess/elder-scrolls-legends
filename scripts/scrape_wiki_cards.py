#!/usr/bin/env python3
"""
Scrape all Elder Scrolls Legends card data from the UESP wiki.

Uses the MediaWiki API to bypass Cloudflare protection.
Outputs a JSON file with all card data, suitable for LLM consumption.

Usage:
    python3 scripts/scrape_wiki_cards.py [--resume] [--delay SECONDS]
    python3 scripts/scrape_wiki_cards.py --enrich-art [--delay SECONDS]

Options:
    --resume       Resume from the last saved progress (skips already-scraped cards)
    --enrich-art   Add art_url to cards in existing cards.json that are missing it
    --delay        Delay between API requests in seconds (default: 0.5)
"""

import argparse
import json
import re
import sys
import time
from pathlib import Path
from typing import Optional
from urllib.parse import quote, unquote

import requests
from bs4 import BeautifulSoup

API_URL = "https://en.uesp.net/w/api.php"
CARDS_PAGE = "Legends:Cards"
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data" / "wiki_scrape"
OUTPUT_FILE = OUTPUT_DIR / "cards.json"
PROGRESS_FILE = OUTPUT_DIR / ".scrape_progress.json"

# Card set pages listed on the main cards page
CARD_SET_PAGES = [
    ("Core Set", "Legends:Core_Set"),
    ("Basic Cards", "Legends:Basic_Cards"),
    ("Heroes of Skyrim", "Legends:Heroes_of_Skyrim"),
    ("Houses of Morrowind", "Legends:Houses_of_Morrowind"),
    ("Alliance War", "Legends:Alliance_War"),
    ("Moons of Elsweyr", "Legends:Moons_of_Elsweyr"),
    ("Jaws of Oblivion", "Legends:Jaws_of_Oblivion"),
    ("Dark Brotherhood", "Legends:Dark_Brotherhood"),
    ("Clockwork City", "Legends:Clockwork_City"),
    ("Isle of Madness", "Legends:Isle_of_Madness"),
    ("Madhouse Collection", "Legends:Madhouse_Collection"),
    ("Forgotten Hero Collection", "Legends:Forgotten_Hero_Collection"),
    ("FrostSpark Collection", "Legends:FrostSpark_Collection"),
    ("Tamriel Collection", "Legends:Tamriel_Collection"),
    ("Monthly Cards", "Legends:Monthly_Cards"),
    ("Exclusive Cards", "Legends:Exclusive_Cards"),
    ("Dawnguard", "Legends:Dawnguard"),
]

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "ESLCardScraper/1.0 (Educational project; card data collection)"
})


def api_parse(page_title: str, retries: int = 3) -> Optional[str]:
    """Fetch parsed HTML for a wiki page via the MediaWiki API."""
    for attempt in range(retries):
        try:
            resp = SESSION.get(API_URL, params={
                "action": "parse",
                "page": page_title,
                "prop": "text",
                "format": "json",
            })
            resp.raise_for_status()
            data = resp.json()
            if "parse" in data:
                return data["parse"]["text"]["*"]
            return None
        except requests.exceptions.RequestException as e:
            if attempt < retries - 1:
                wait = 2 ** (attempt + 1)
                print(f" (retry {attempt + 1} after {wait}s: {e})", end="", flush=True)
                time.sleep(wait)
            else:
                print(f" (failed after {retries} attempts: {e})", end="", flush=True)
                return None


def extract_card_links_from_set_page(page_title: str) -> list[dict]:
    """Extract card entries from a card set page's sortable tables.

    Returns a list of dicts with basic card data from the table, plus the wiki
    page name for fetching the full card page later.
    """
    html = api_parse(page_title)
    if not html:
        print(f"  WARNING: Could not fetch {page_title}")
        return []

    soup = BeautifulSoup(html, "html.parser")
    tables = soup.find_all("table", class_="sortable")
    cards = []

    for table in tables:
        rows = table.find_all("tr")
        if not rows:
            continue

        # Build column index from headers
        header_cells = rows[0].find_all("th")
        headers = [th.get_text(strip=True) for th in header_cells]
        if "Name" not in headers:
            continue

        name_idx = headers.index("Name")
        type_idx = headers.index("Type (Subtype)") if "Type (Subtype)" in headers else name_idx + 1
        attr_idx = headers.index("Attribute/Class") if "Attribute/Class" in headers else type_idx + 1
        # The 4 unlabeled columns after Attribute/Class are: Cost, Power, Health, Rarity
        cost_idx = attr_idx + 1
        power_idx = attr_idx + 2
        health_idx = attr_idx + 3
        rarity_idx = attr_idx + 4
        text_idx = headers.index("Text") if "Text" in headers else rarity_idx + 1

        for row in rows[1:]:
            cells = row.find_all("td")
            if len(cells) <= rarity_idx:
                continue

            # Extract name and wiki page link
            name_cell = cells[name_idx]
            name = name_cell.get_text(strip=True)
            # Find the card page link (not an image file link)
            link = None
            for a in name_cell.find_all("a"):
                href = a.get("href", "")
                if href.startswith("/wiki/Legends:") and "File:" not in href:
                    link = a
                    break
            if not link:
                continue
            wiki_page = link.get("href", "").replace("/wiki/", "")

            # Extract type and subtype
            type_text = cells[type_idx].get_text(strip=True).replace("\xa0", " ")
            card_type = type_text
            subtypes = []
            type_match = re.match(r"(\w+)\s*\((.+)\)", type_text)
            if type_match:
                card_type = type_match.group(1)
                subtypes = [s.strip() for s in type_match.group(2).split(",")]

            # Extract attribute(s)
            attr_cell = cells[attr_idx]
            attribute = attr_cell.get_text(strip=True)
            # For dual-attribute cards, there may be multiple attribute images
            attr_imgs = attr_cell.find_all("img")
            if len(attr_imgs) > 1:
                attributes = [img.get("alt", "") for img in attr_imgs
                              if img.get("alt", "") not in ("", attribute)]
                if not attributes:
                    attributes = [attribute]
            else:
                attributes = [attribute]

            # Extract cost, power, health
            cost_text = cells[cost_idx].get_text(strip=True)
            power_text = cells[power_idx].get_text(strip=True)
            health_text = cells[health_idx].get_text(strip=True)

            cost = int(cost_text) if cost_text.isdigit() else 0
            power = int(power_text) if power_text.lstrip("-").isdigit() else None
            health = int(health_text) if health_text.lstrip("-").isdigit() else None

            # Extract rarity from image alt text
            rarity_cell = cells[rarity_idx]
            rarity_img = rarity_cell.find("img")
            rarity = rarity_img.get("alt", "Common") if rarity_img else "Common"

            # Extract card text
            card_text = cells[text_idx].get_text(strip=True) if len(cells) > text_idx else ""

            cards.append({
                "name": name,
                "wiki_page": wiki_page,
                "card_type": card_type,
                "subtypes": subtypes,
                "attributes": attributes,
                "cost": cost,
                "power": power,
                "health": health,
                "rarity": rarity,
                "card_text_from_table": card_text,
            })

    return cards


def is_disambiguation_page(soup: BeautifulSoup) -> bool:
    """Check if a page is a disambiguation page."""
    # Disambiguation pages typically have the dmbox class or specific text
    if soup.find(class_="dmbox"):
        return True
    text = soup.get_text()
    return "may refer to one of" in text or "disambiguation" in text.lower()


def extract_card_links_from_disambiguation(soup: BeautifulSoup) -> list[str]:
    """Extract card page links from a disambiguation page."""
    links = []
    for a in soup.find_all("a"):
        href = a.get("href", "")
        if href.startswith("/wiki/Legends:") and "File:" not in href:
            page = href.replace("/wiki/", "")
            # Skip non-card links
            if any(skip in page for skip in ["Special:", "Category:", "Card_Sets"]):
                continue
            links.append(page)
    return links


def parse_infobox(soup: BeautifulSoup) -> Optional[dict]:
    """Parse the infobox table from a card page."""
    infobox = soup.find("table", class_="infobox")
    if not infobox:
        return None

    data = {}
    rows = infobox.find_all("tr")

    for row in rows:
        ths = row.find_all("th")
        tds = row.find_all("td")

        if not tds:
            # Header row - extract card name and type
            if ths:
                th = ths[0]

                # Skip "Unique" badge rows (no <font>/<br>, just a styled label)
                th_text_raw = th.get_text(strip=True)
                if th_text_raw == "Unique":
                    data["is_unique"] = True
                    continue

                # Name is the text before the <br>/<font> tag
                # Walk direct children to get just the name portion
                name_parts = []
                for child in th.children:
                    if child.name in ("br", "font"):
                        break
                    text = child.string if child.string else ""
                    text = text.strip()
                    if text:
                        name_parts.append(text)
                if name_parts:
                    data["name"] = " ".join(name_parts)

                # Type info is in the <font> tag
                font = th.find("font")
                if font:
                    type_line = font.get_text(strip=True).replace("\xa0", " ")
                    type_match = re.match(r"(\w+)\s*\((.+)\)", type_line)
                    if type_match:
                        data["card_type"] = type_match.group(1)
                        data["subtypes"] = [s.strip() for s in type_match.group(2).split(",")]
                    else:
                        data["card_type"] = type_line
            continue

        th_text = " ".join(th.get_text(strip=True) for th in ths)
        td_text = " ".join(td.get_text(strip=True) for td in tds)

        if "Deck code" in th_text and "Alternate" not in th_text:
            data["deck_code_id"] = td_text.strip()
        elif "Alternate" in th_text and "Deck code" in th_text:
            data["alt_deck_code_id"] = td_text.strip()
        elif "Card Set" in th_text:
            data["card_set"] = td_text.strip()
        elif "Magicka Cost" in th_text:
            cost = re.search(r"\d+", td_text)
            data["cost"] = int(cost.group()) if cost else 0
        elif "Attribute" in th_text:
            # Extract attributes from text, ignoring icon text duplication
            attr_text = td_text.strip()
            # Handle dual attributes like "StrengthIntelligence"
            known_attrs = ["Strength", "Intelligence", "Willpower", "Agility", "Endurance", "Neutral"]
            found_attrs = []
            for attr in known_attrs:
                if attr in attr_text:
                    found_attrs.append(attr)
            data["attributes"] = found_attrs if found_attrs else [attr_text]
        elif th_text == "Power Health":
            # Power and Health are in separate tds
            if len(tds) >= 2:
                p = tds[0].get_text(strip=True)
                h = tds[1].get_text(strip=True)
                data["power"] = int(p) if p.lstrip("-").isdigit() else None
                data["health"] = int(h) if h.lstrip("-").isdigit() else None
        elif "Rarity" in th_text:
            rarity_img = tds[0].find("img") if tds else None
            if rarity_img:
                data["rarity"] = rarity_img.get("alt", td_text.strip())
            else:
                data["rarity"] = td_text.strip()
        elif not th_text and tds:
            # The last row with no header is typically the card text
            # Get text with newlines preserved
            card_text = tds[0].get_text(separator="\n", strip=True)
            if card_text and "card_text" not in data:
                data["card_text"] = card_text

    return data if data else None


def extract_art_url(soup: BeautifulSoup) -> Optional[str]:
    """Extract the full-resolution card art URL from a card page.

    Finds the "Card art" gallery item, gets the thumbnail src, and converts
    it to the full-resolution URL by stripping /thumb and the size prefix.
    """
    # Find gallery items with "Card art" text
    for gallery_text in soup.find_all(class_="gallerytext"):
        if "Card art" in gallery_text.get_text():
            # The image is in the sibling .thumb div
            parent = gallery_text.parent
            thumb_div = parent.find(class_="thumb")
            if not thumb_div:
                continue
            img = thumb_div.find("img")
            if not img:
                continue
            src = img.get("src", "")
            if "LG-cardart-" not in src:
                continue
            # Convert thumbnail URL to full resolution
            # Thumb: //images.uesp.net/thumb/b/bb/Filename.jpg/199px-Filename.jpg
            # Full:  //images.uesp.net/b/bb/Filename.jpg
            if "/thumb/" in src:
                full_url = src.replace("/thumb/", "/")
                # Remove the last path segment (the sized thumbnail)
                full_url = full_url.rsplit("/", 1)[0]
                return "https:" + full_url
            else:
                return "https:" + src
    return None


def scrape_card_page(wiki_page: str, delay: float) -> list[dict]:
    """Scrape a single card page. Returns a list (may be multiple for disambiguation)."""
    time.sleep(delay)
    page_title = unquote(wiki_page)
    html = api_parse(page_title)
    if not html:
        return []

    soup = BeautifulSoup(html, "html.parser")

    # Check for disambiguation page
    if is_disambiguation_page(soup):
        sub_pages = extract_card_links_from_disambiguation(soup)
        results = []
        for sub_page in sub_pages:
            time.sleep(delay)
            sub_html = api_parse(unquote(sub_page))
            if not sub_html:
                continue
            sub_soup = BeautifulSoup(sub_html, "html.parser")
            card_data = parse_infobox(sub_soup)
            if card_data:
                card_data["wiki_page"] = sub_page
                card_data["is_alternate_form"] = True
                results.append(card_data)
        return results

    # Normal card page
    card_data = parse_infobox(soup)
    if card_data:
        card_data["wiki_page"] = wiki_page
        return [card_data]

    return []


def load_progress() -> dict:
    """Load scraping progress from file."""
    if PROGRESS_FILE.exists():
        return json.loads(PROGRESS_FILE.read_text())
    return {"scraped_pages": {}, "card_set_index": 0}


def save_progress(progress: dict):
    """Save scraping progress."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PROGRESS_FILE.write_text(json.dumps(progress, indent=2))


def merge_card_data(table_data: dict, page_data: dict) -> dict:
    """Merge data from set page table and individual card page.

    Card page data is preferred when available, table data fills gaps.
    """
    merged = {**table_data}

    # Card page fields take priority
    for key in ["deck_code_id", "alt_deck_code_id", "card_set", "card_text",
                "is_alternate_form"]:
        if key in page_data:
            merged[key] = page_data[key]

    # Use card page data for core fields if available
    for key in ["name", "card_type", "subtypes", "attributes", "cost",
                "power", "health", "rarity"]:
        if key in page_data and page_data[key] is not None:
            merged[key] = page_data[key]

    # Remove the table-only text field
    merged.pop("card_text_from_table", None)

    # Ensure card_text exists
    if "card_text" not in merged and "card_text_from_table" in table_data:
        merged["card_text"] = table_data["card_text_from_table"]

    return merged


def build_output(all_cards: list[dict]) -> dict:
    """Build the final output structure."""
    return {
        "_meta": {
            "source": "https://en.uesp.net/wiki/Legends:Cards",
            "description": "Elder Scrolls Legends card data scraped from UESP wiki",
            "scraped_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "total_cards": len(all_cards),
            "notes": (
                "Cards with is_alternate_form=true are beast form / transformed versions "
                "that share a name with another card. The wiki_page field disambiguates them."
            ),
        },
        "cards": all_cards,
    }


def enrich_art_urls(delay: float):
    """Add art_url to cards in existing cards.json that are missing it."""
    if not OUTPUT_FILE.exists():
        print(f"ERROR: {OUTPUT_FILE} does not exist. Run a full scrape first.")
        sys.exit(1)

    data = json.loads(OUTPUT_FILE.read_text())
    cards = data["cards"]

    missing = [c for c in cards if "art_url" not in c]
    print(f"Found {len(missing)} cards missing art_url (out of {len(cards)} total)")

    for i, card in enumerate(missing):
        wiki_page = card.get("wiki_page", "")
        if not wiki_page:
            continue

        print(f"  [{i + 1}/{len(missing)}] {card['name']}", end="", flush=True)
        time.sleep(delay)

        html = api_parse(unquote(wiki_page))
        if not html:
            print(" (fetch failed)")
            continue

        soup = BeautifulSoup(html, "html.parser")
        art_url = extract_art_url(soup)

        if art_url:
            card["art_url"] = art_url
            print(" ✓")
        else:
            print(" (no art found)")

        # Save periodically
        if (i + 1) % 20 == 0:
            OUTPUT_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False))

    # Final save
    data["_meta"]["scraped_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    OUTPUT_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    enriched = sum(1 for c in cards if "art_url" in c)
    print(f"\nDone! {enriched}/{len(cards)} cards now have art_url")


def main():
    parser = argparse.ArgumentParser(description="Scrape ESL card data from UESP wiki")
    parser.add_argument("--resume", action="store_true",
                        help="Resume from last saved progress")
    parser.add_argument("--enrich-art", action="store_true",
                        help="Add art_url to cards in existing cards.json missing it")
    parser.add_argument("--delay", type=float, default=0.5,
                        help="Delay between requests in seconds (default: 0.5)")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if args.enrich_art:
        enrich_art_urls(args.delay)
        return

    # Load or initialize progress
    if args.resume:
        progress = load_progress()
        print(f"Resuming: {len(progress['scraped_pages'])} pages already scraped")
    else:
        progress = {"scraped_pages": {}, "card_set_index": 0}

    all_cards = []
    total_sets = len(CARD_SET_PAGES)

    for set_idx, (set_name, set_page) in enumerate(CARD_SET_PAGES):
        if args.resume and set_idx < progress.get("card_set_index", 0):
            # Reconstruct already-scraped cards from progress
            for page_key, card_list in progress["scraped_pages"].items():
                if any(c.get("card_set_source") == set_name for c in card_list):
                    all_cards.extend(card_list)
            continue

        print(f"\n[{set_idx + 1}/{total_sets}] Scraping card set: {set_name}")
        time.sleep(args.delay)

        # Get card list from set page tables
        table_cards = extract_card_links_from_set_page(set_page)
        print(f"  Found {len(table_cards)} cards in tables")

        for card_idx, table_card in enumerate(table_cards):
            wiki_page = table_card["wiki_page"]

            # Skip if already scraped
            if wiki_page in progress["scraped_pages"]:
                cached = progress["scraped_pages"][wiki_page]
                all_cards.extend(cached)
                continue

            print(f"  [{card_idx + 1}/{len(table_cards)}] {table_card['name']}",
                  end="", flush=True)

            # Fetch full card page
            page_cards = scrape_card_page(wiki_page, args.delay)

            if page_cards:
                # Disambiguation page returns multiple cards
                if len(page_cards) > 1:
                    print(f" (disambiguation: {len(page_cards)} forms)", end="")
                    merged_cards = []
                    for pc in page_cards:
                        merged = {**table_card, **pc}
                        merged.pop("card_text_from_table", None)
                        merged["card_set_source"] = set_name
                        merged_cards.append(merged)
                else:
                    merged = merge_card_data(table_card, page_cards[0])
                    merged["card_set_source"] = set_name
                    merged_cards = [merged]

                all_cards.extend(merged_cards)
                progress["scraped_pages"][wiki_page] = merged_cards
                print(" ✓")
            else:
                # Fall back to table data only
                table_card["card_set_source"] = set_name
                table_card["card_text"] = table_card.pop("card_text_from_table", "")
                all_cards.append(table_card)
                progress["scraped_pages"][wiki_page] = [table_card]
                print(" (table data only)")

            # Save progress periodically (every 20 cards)
            if card_idx % 20 == 0:
                progress["card_set_index"] = set_idx
                save_progress(progress)

        progress["card_set_index"] = set_idx + 1
        save_progress(progress)

    # Deduplicate cards that appear in multiple sets
    # Use (wiki_page, name) as key, prefer the entry with more data
    seen = {}
    deduped = []
    for card in all_cards:
        key = card.get("wiki_page", "") + "|" + card.get("name", "")
        if key in seen:
            existing = seen[key]
            # Keep the one with a deck_code_id, or more fields
            if "deck_code_id" not in existing and "deck_code_id" in card:
                seen[key] = card
                deduped = [c for c in deduped if (c.get("wiki_page", "") + "|" + c.get("name", "")) != key]
                deduped.append(card)
        else:
            seen[key] = card
            deduped.append(card)

    # Clean up output fields
    for card in deduped:
        # Remove internal-only fields
        card.pop("card_text_from_table", None)
        # Ensure consistent field ordering
        if "power" in card and card["power"] is None:
            card.pop("power")
        if "health" in card and card["health"] is None:
            card.pop("health")

    output = build_output(deduped)
    OUTPUT_FILE.write_text(json.dumps(output, indent=2, ensure_ascii=False))
    print(f"\n{'='*60}")
    print(f"Done! Scraped {len(deduped)} unique cards")
    print(f"Output saved to: {OUTPUT_FILE}")

    # Clean up progress file on successful completion
    if PROGRESS_FILE.exists():
        PROGRESS_FILE.unlink()
        print("Progress file cleaned up")


if __name__ == "__main__":
    main()
