---
name: region-research
description: Research Elder Scrolls lore for a region and propose adventure themes with matching card catalog decks. Use when planning new adventures for a region — e.g. "research Morrowind adventures", "what adventures could we do in Cyrodiil". Takes a region name as argument.
model: opus
effort: high
---

# Region Adventure Research

Research Elder Scrolls lore for a specific region and propose Path of Tamriel adventure themes, mapping lore to the existing card catalog to produce actionable adventure designs.

## Arguments

`$ARGUMENTS` — A region name (e.g., `Hammerfell`, `Morrowind`, `Cyrodiil`). May optionally include a wiki URL or specific sub-region focus.

## Phase 1: Gather Lore

### 1a. Check existing research

Look in `development-artifacts/` for any existing research files for this region (e.g., `{region}_adventure_research.md`). If one exists, read it — you may be updating rather than starting fresh.

### 1b. Check the region config

Read `data/regions/{region_id}.json` to see the current state — what adventures already exist, the region's display name, and map image path.

### 1c. Research lore from web sources

**WebSearch snippets are usually sufficient.** Multiple targeted web searches (one for geography, one for history, one for cultural traditions, one for ESO storylines, etc.) will typically surface enough lore from result summaries alone — often more efficiently than fetching full wiki pages. Launch 5-8 parallel web searches as the primary lore-gathering strategy.

Only use `WebFetch` if a specific page looks exceptionally promising from search results. Most wiki sites (UESP, Fandom, Imperial Library) frequently return 403 errors on direct fetch, so don't spend time on fetch-then-fallback chains. Web searches are the workhorse here.

**Parallelise aggressively** — launch all initial web searches concurrently, not sequentially.

Gather information across these categories:

**Geography & Settings**
- Major cities and their political/cultural significance
- Distinct sub-regions (deserts, forests, mountains, coasts, ruins)
- Notable landmarks, dungeons, ruins (especially Dwemer, Ayleid, Daedric)

**History & Storylines**
- Major wars, conflicts, and political events
- Storylines from TES games set in this region (main quests, guild questlines, DLC)
- Era-spanning narratives (which events span First through Fourth Era?)
- Faction conflicts and civil wars

**Prominent Figures**
- Legendary heroes, villains, kings, generals, mages
- Characters from TES game storylines set here
- Daedric Princes with strong regional ties
- Guild leaders, faction heads, historical warriors

**Races & Factions**
- Dominant race(s) and their culture
- Internal factions and political divisions
- Enemy factions (invaders, cults, undead, Daedra)
- Guilds and organizations based in the region

**Culture & Themes**
- Unique cultural practices (e.g., Sword-Singing for Hammerfell, Tribunal worship for Morrowind)
- Religious traditions and pantheon
- Architectural and aesthetic identity
- Signature combat styles or magic traditions

### 1d. Research sub-topics in depth

For the most promising storylines, do additional targeted searches. For example:
- If the region has a unique warrior tradition, research its history, notable practitioners, and ranks
- If there's a famous war, research key battles and commanders
- If there's a prominent game storyline, research its full plot arc and major characters
- **ESO zone storylines** — If the region has ESO zones (most do), search for each zone's main storyline. ESO zones often have self-contained narrative arcs with named villains, faction conflicts, and set-piece battles that translate directly into adventure proposals. Search for `"Elder Scrolls Online {zone_name} storyline"` for each zone in the region.

## Phase 2: Catalog Audit

### 2a. Find region-themed cards

Search `src/deck/card_catalog.gd` for cards connected to the region:

1. **By race subtype** — grep for the dominant race (e.g., `"Redguard"`, `"Dark Elf"`, `"Nord"`)
2. **By place names** — grep for city/region names that appear in card names (e.g., `Alik'r`, `Sentinel`, `Rihad`, `Craglorn`)
3. **By cultural keywords** — grep for faction/culture terms (e.g., `Yokud`, `Crown`, `Ansei`, `Sword`)
4. **By lore figure names** — grep for named characters discovered in Phase 1
5. **By regional creature types** — grep for creature subtypes native to the region (e.g., `"Reptile"`, `"Wamasu"`, `"Lurcher"` for Black Marsh; `"Dragon"`, `"Draugr"` for Skyrim). These are essential for building thematic enemy decks

**Note:** Grep results on `card_catalog.gd` often produce `[Omitted long matching line]` for seed entries. When this happens, use `Read` with the specific line offset to see the full card data. Also check `data/wiki_scrape/cards.json` — it contains pre-scraped card data that may be easier to search for lore cross-references.

### 2b. Identify legendary cards

From the matches, extract all **legendary, unique** cards with the region's dominant race subtype. These are potential deck anchors or boss candidates.

### 2c. Map card themes

Group the discovered cards into thematic clusters:
- Item/equipment synergy cards
- Rally/army-building cards
- Magic/spell synergy cards
- Tribal synergy cards (race-specific)
- Keyword-themed groups (Slay, Pilfer, Ward, etc.)

Note which clusters have enough depth (8+ cards) to support a full adventure deck. A viable deck needs ~30 cards with a coherent mechanical identity.

### 2d. Check for named lore cards

Look for cards that directly reference lore events or artifacts (e.g., "Siege of Stros M'Kai", "The Red Year"). These provide strong thematic anchors.

### 2e. Audit enemy card pools

Search the catalog for cards that could populate **enemy decks** — this is just as important as finding player cards. Common enemy pools:
- **Daedra** subtype (for Daedric invasion themes)
- **Skeleton/Spirit/Vampire** subtypes (for undead/necromancy themes)
- **Beast/Animal** subtypes native to the region
- **Ward/Mage** cards in Intelligence (for enemy mage decks)
- Any race subtype that could serve as an enemy faction

Note the card count per enemy theme. A viable enemy deck needs ~12-15 distinct cards (with quantity multipliers reaching ~30 total). If an enemy theme has fewer than 8 cards, flag it as insufficient.

**Tip**: Use a subagent (Agent tool with `subagent_type: Explore`) for the full catalog audit. Searching `card_catalog.gd` and `data/wiki_scrape/cards.json` across 10+ grep patterns is a perfect subagent task — it keeps the main context clean and runs faster via parallel searches.

### 2f. Review existing enemy decks

Read enemy deck files in `data/decks/adventure/enemies/` to understand:
- What enemy themes are already built (e.g., Thalmor, Necromancer, Draugr)
- Enemy deck structure: card count, quantity distribution, attribute spread
- Which cards are already "claimed" by existing enemy decks (avoid reusing the same deck wholesale)

This prevents proposing an adventure with enemy decks that duplicate what's already in the game.

## Phase 3: Cross-Reference

Run Phase 1 (lore) and Phase 2 (catalog) in parallel — catalog greps don't depend on lore research completing first. Start grepping for the region's dominant race and obvious place names while lore searches are still in flight. Phase 3 cross-referencing begins once both are done.

### 3a. Match figures to cards

For each prominent lore figure identified in Phase 1, check if they exist as a card in the catalog. Note:
- **Exists as legendary card** → natural boss or deck anchor
- **Exists as non-legendary card** → can still feature in the adventure narrative
- **Does not exist** → potential custom boss (enemy-only deck), note for future card imports

### 3b. Match storylines to card pools

For each promising storyline, assess whether the card catalog has enough thematically matching cards to build:
- A **player deck** (30 cards, coherent theme, 1-3 attributes — tri-color is valid if the region has a tri-color faction like the Aldmeri Dominion)
- **Enemy decks** for 3-5 combat encounters (can reuse cards across enemies)
- At least one **boss** with a signature card or mechanic

### 3c. Review existing adventures and decks for patterns

Read 1-2 existing adventure JSON files in `data/adventures/` to understand:
- Node count and type distribution (how many combats, events, shops, etc.)
- Enemy deck naming conventions
- XP reward ranges
- Boss health ranges and quality values

**Critical**: Read ALL existing player deck files in `data/decks/adventure/` (excluding `enemies/`) and note the `attribute_ids` of each. Map out which attribute pairs are already used. Every adventure proposal should target an **unused** attribute pair (or a tri-color combo) to ensure mechanical variety across the adventure catalog.

## Phase 4: Propose Adventures

For each proposed adventure, provide:

### Adventure Header
- **Name** — evocative title referencing the storyline
- **Setting** — specific locations within the region, sequenced as a journey
- **Storyline** — 2-3 sentence narrative arc

### Deck Design
- **Archetype** — attribute combination and mechanical identity (e.g., "STR/INT Battlemage — item synergy")
- **Core cards** — list 12-15 specific cards from the catalog by name, explaining why each fits
- **Legendary anchor** — which legendary card(s) define the deck
- **Mechanical coherence** — explain why these cards work together

### Boss & Enemies
- **Final boss** — name, lore justification, potential special mechanic
- **Mini-boss** — name, role in the storyline
- **Enemy deck themes** — what enemy decks represent (e.g., "Imperial soldiers", "Dwemer automatons")
- **Enemy races** — what subtypes enemies should use

### Adventure Nodes
- **Boons** — themed boon names with flavor
- **Events** — 1-2 narrative choice events with mechanical consequences
- **Shop/Reinforcement** — themed location names
- **Augment nodes** — what augment flavor fits (e.g., "Dwemer Forge", "Enchanter's Altar")

### Feasibility Rating
Rate each adventure on:
- **Card pool depth** (Excellent / Good / Moderate / Thin) — enough cards for a coherent deck?
- **Boss availability** (Ready / Needs import / Custom only) — is there a legendary card for the boss?
- **Lore richness** (Deep / Solid / Surface) — how much narrative material is there?
- **Mechanical uniqueness** (High / Moderate / Low) — does this play differently from existing adventures?
- **Suggested difficulty** (1-3) — matches the `difficulty` field in adventure JSON

## Phase 5: Write Report

### 5a. Write the research document

Save the complete findings to `development-artifacts/{region_id}_adventure_research.md` with these sections:
1. **Lore Overview** — geography, history, culture summary
2. **Key Regions & Cities** — table of locations with notes
3. **Races & Peoples** — who lives here
4. **Key Factions** — political and military groups
5. **Prominent Figures** — table with name, role, and boss potential
6. **Signature Cultural Elements** — what makes this region unique
7. **Cards in the Catalog** — organized by legendary cards, place-named cards, and thematic groups
8. **Existing Adventures & Attribute Usage** — table of all current adventure decks with their attribute pairs, plus list of unused pairs. This is critical context for ensuring proposals don't overlap.
9. **Adventure Proposals** — 3-5 proposals with full details from Phase 4
10. **Summary Table** — ranked comparison of all proposals

### 5b. Prioritize and recommend

End with a clear recommendation for which adventure to build first, based on:
1. Card catalog depth (can we build a deck today?)
2. Lore iconicness (will players recognize and enjoy this storyline?)
3. Boss quality (is there a satisfying climactic fight?)
4. Mechanical uniqueness (does this play differently from existing adventures?)

## Tips & Pitfalls

- **UESP may block requests** — always have fallback sources. Web searches often surface enough lore even when wikis are inaccessible.
- **Card catalog is the constraint** — exciting lore means nothing if the catalog can't support a deck. Always verify card pool depth before proposing an adventure.
- **Check existing adventures for overlap** — don't propose a theme too similar to an existing adventure in another region. Read `data/adventures/*.json` headlines. Also read existing player deck files in `data/decks/adventure/` to check attribute overlap — if an existing deck already uses INT/WIL, differentiate your proposal with different attributes, a tri-color build, or a distinctly different mechanical identity (e.g., token/buff vs action-spam).
- **Dual-attribute cards matter** — a STR/INT deck can use STR cards, INT cards, AND STR/INT dual cards. Don't miss the dual-attribute section of the catalog.
- **Race subtypes are key** — the dominant race's subtype (e.g., "Redguard", "Dark Elf") is the strongest filter for finding thematically appropriate cards.
- **Items, keywords, and effects cluster by attribute** — STR has items/weapons, INT has wards/spells, AGI has movement/pilfer, END has guards/last gasp, WIL has tokens/healing. Match the region's cultural flavor to the right attribute.
- **Boss fights need a hook** — the best bosses have a unique mechanic or gimmick that reflects their lore identity, not just high stats.
