# Solo Arena Mode — Game Design Analysis

## Overview

Solo Arena is a single-player PvE mode where the player drafts a deck and battles through a series of AI opponents. A run ends when the player either defeats the final boss (9th opponent) or accumulates 3 losses. The mode features a hidden Elo-based difficulty system, special lane mechanics, themed AI opponents, and a ranking system independent from other game modes.

---

## Complete Flow

1. **Entry**: Player pays 150 gold to start a run
2. **Class Selection**: Player is offered 3 randomly selected classes and picks one
3. **Card Draft**: Player drafts 30 cards (one at a time, choosing 1 from 3 options of matching rarity)
4. **Matches**: Player fights up to 8 regular AI opponents, then a final boss (9th opponent)
5. **Post-Win Picks**: After each win, the player picks 1 card from 3 options to add to their deck (deck grows beyond 30)
6. **Run End**: Run ends on 3 losses OR after beating/losing to the boss
7. **Rewards**: Rewards are granted based on total wins and current rank

---

## Class Selection

- Player is offered **3 randomly selected classes** from the available pool
- Each class is a combination of **2 of 5 attributes**: Agility, Endurance, Intelligence, Strength, Willpower
- The 10 possible dual-attribute classes are the same as constructed play
- The selected class determines the card pool available during the draft (only cards from those two attributes, plus Neutral cards)

---

## Card Draft Phase

### Mechanics
- 30 picks total
- Each pick offers **3 cards of the same rarity**
- Player selects 1 card per pick

### Rarity Distribution (approximate probabilities per pick)
| Rarity | Probability |
|--------|------------|
| Common | ~60% (3 in 5) |
| Rare | ~25% (1 in 4) |
| Epic | ~10% (1 in 10) |
| Legendary | ~2.2% (1 in 45) |

### Card Pool Restrictions
- Cards must belong to one of the class's two attributes, or be Neutral
- Unique cards: max 1 copy per deck
- Regular cards: max 3 copies per deck

---

## Post-Win Card Picks

- After **each win** (including the boss), the player is offered 1 pick of 3 cards
- The selected card is **added** to the deck (deck grows beyond 30 cards)
- Cards are not swapped out — picks are cumulative
- This allows the player to shore up weaknesses or double down on strengths as the run progresses
- A full 9-win run results in a final deck of up to 39 cards (30 drafted + 9 picks)

---

## Match Structure

### Regular Matches (Opponents 1–8)
- 8 AI opponents with varying difficulty based on hidden Elo
- Each match may feature **special lanes** that modify gameplay
- ~50% chance per run of encountering a **Feature Match** (unique named opponent with personality and themed deck)

### Boss Match (Opponent 9)
- Final encounter after defeating 8 opponents
- Boss is equipped with one of **6 relics** that grant a special advantage:

| Relic | Effect |
|-------|--------|
| Iron | Boss starts with increased health |
| Corundum | Boss has stronger creatures |
| Moonstone | Boss gains benefits when your runes break |
| Quicksilver | Boss deals extra damage over time |
| Ebony | City Gates lane receives a barrier requirement |
| Malachite | Boss has pre-placed defenders in play |

### Run Termination
- **3 losses** at any point ends the run
- **Defeating the boss** ends the run (win)
- **Losing to the boss** counts as a loss (may end the run if it's the 3rd loss)

---

## Opponent System

### Regular Opponents (~200+)
- Organized by themes: creature types (Animals, Dragons, Undead, Dwemer), mechanics (Aggro, Tempo, Control), factions/races
- Use single-attribute, dual-attribute, or Neutral decks
- Difficulty matched via hidden Elo system

### Feature Match Opponents (16 unique characters)
Feature matches are special named opponents with unique personalities, introductions, and themed decks. Each can only be defeated once before being removed from the pool.

| Name | Title | Deck Theme | Attributes |
|------|-------|-----------|------------|
| Captain Mera | The Undefeated | Imperial Tokens | Willpower/Endurance |
| Chaos Magician | The Mad | Random | Strength/Intelligence |
| Cheydinhal Sergeant | The Victorious | Imperials | Willpower/Endurance |
| Cursed Skull | The Immortal | Undead | Intelligence/Endurance |
| Forgotten Machines | The Victorious | Dwemer | Neutral |
| Frostbringer | The Miraculous | Ice Spike | Intelligence |
| Gatecrasher | The Untouchable | Aggro | Strength/Endurance |
| Iron Atronach | The Immortal | Atronachs | Intelligence/Endurance |
| Master of Sorcery | The Cunning | Actions | Intelligence/Willpower |
| Scarza | The Victorious | Mudcrabs | Strength |
| Spider Queen | The Deadly | Spiders | Agility |
| Mad Conjurer | The Victorious | Desperate Conjuring | Strength/Intelligence |
| Wild Beastcaller | The Victorious | Animals | Strength/Agility |
| Wispmother | The Clonemaster | 3-cost cards | Intelligence/Willpower |

Note: Feature matches do NOT use special lanes — they use standard lanes with unique introductions and announcer dialogue.

---

## Elo System (Hidden Difficulty Matching)

### Core Mechanics
- **Starting Elo**: 1200
- **Range**: 800 (minimum) to 2000 (maximum)
- Elo adjusts **only after a run is completed**, not during
- Opponent selection within a run is based on current Elo

### Opponent Distribution at Elo 1200 (starting)
- 2 weak opponents (Elo 700–900)
- 5 average opponents
- 2 strong opponents (Elo 1100–1300)

### Difficulty Modifiers
Special scenarios and lanes can adjust effective difficulty:
- **ProPlayer**: Advantage for the player (lowers effective opponent Elo)
- **ProBoth**: Neutral or advantage for both
- **ProAiMinor**: Small advantage for the opponent
- **ProAiMajor**: Large advantage for the opponent

Example: A 1300 Elo opponent with an Ambush scenario effectively plays at 1400 Elo.

---

## Lane Types

Solo Arena uses special lanes beyond the standard Field and Shadow lanes. There are **44 distinct lane types** in the game. Key examples:

### Standard Lanes
| Lane | Effect |
|------|--------|
| Field | No special effects |
| Shadow | Creatures gain Cover for one turn when played |

### Combat Enhancement Lanes
| Lane | Effect |
|------|--------|
| Venom | Grants creatures Lethal |
| Siege | Grants Breakthrough |
| Renewal | Provides Regenerate |
| Graveyard | Summon 1/1 Skeleton when non-Skeleton creatures are destroyed |

### Summoning Effect Lanes
| Lane | Effect |
|------|--------|
| Plunder | Equips creatures with random items when summoned |
| Hall of Mirrors | Creates copy of next creature when lane is empty |
| Zoo | Transforms summoned creatures into random animals |
| Campfire | Friendly creatures gain the summoned creature's keywords |
| Fountain | Creatures with 2 power or less gain Ward |

### Resource Lanes
| Lane | Effect |
|------|--------|
| Surplus | Reduces random hand card costs after creature summoning |
| Temple | Gain 1 health when you summon a creature |
| Library | Friendly creatures here reduce action costs by 1 |
| Barracks | Card draw reward for summoning powerful creatures |

### Control Lanes
| Lane | Effect |
|------|--------|
| King of the Hill | Creatures with cost 5+ gain Guard when summoned |
| Dementia | At start of turn, if you have highest power creature here, deal 3 damage to opponent |
| Mania | Draw cards if you control highest health creature |

### Transformation Lanes
| Lane | Effect |
|------|--------|
| Madness | Pilfer effects transform creatures into higher-cost variants |

Note: Versus Arena uses only standard Field/Shadow lanes. Special lanes are exclusive to Solo Arena and Chaos Arena.

---

## Ranking System

### Ranks (9 tiers, independent from other modes)
| Rank | Name |
|------|------|
| 9 | Pit Dog |
| 8 | Brawler |
| 7 | Bloodletter |
| 6 | Myrmidon |
| 5 | Warrior |
| 4 | Gladiator |
| 3 | Hero |
| 2 | Champion |
| 1 | Grand Champion |

### Promotion Requirements
- **Ranks 9–3**: 7 wins in a single run to promote
- **Rank 2 (Champion) to Rank 1 (Grand Champion)**: 9 wins required
- Each promotion awards **50 gold**

### Rank & Elo Interaction
- Rank is a visible progression system
- Elo is the hidden matchmaking system
- They operate independently — high Elo doesn't guarantee high rank and vice versa
- Elo determines opponent difficulty; rank determines reward tiers

---

## Rewards

### Entry Cost
- **150 gold** per run

### Break-Even Point
- Approximately **5 wins** for Solo Arena

### Reward Scaling
- Rewards scale with both **win count** and **current rank**
- Higher ranks yield better rewards for the same number of wins
- At Rank 4+, every 9-win run guarantees at least 2 packs with a chance of a third

### Reward Types
- Gold
- Card packs
- Soul gems
- Individual cards (varying rarity)

### Approximate Reward Tiers
| Wins | Approximate Rewards |
|------|-------------------|
| 0 | ~1 pack + ~30 gold |
| 1–4 | Scaling gold + pack(s) |
| 5 | ~Break-even (~150 gold equivalent) |
| 6–8 | Gold + multiple packs + soul gems |
| 9 | 70–80 gold + 1–3 packs + soul gems + rare/epic/legendary cards |

Note: Exact rewards have randomization within tiers and vary by rank.

### Special First-Time Rewards
- **First boss defeat**: Adoring Fan legendary card
- **Reaching Grand Champion**: Premium Adoring Fan card

### The Adoring Fan
- Unique legendary Neutral creature
- Special mechanic: After being destroyed, returns to a random lane from the discard pile
- Awarded as milestone reward across multiple Arena modes

---

## Mulligan Rules

- At the start of each match, the player views the top 3 cards of their deck
- Any cards can be selected to be redrawn
- Discarded cards cannot be redrawn in the same mulligan step (though duplicate copies may still appear)
- After mulligan, the deck is reshuffled

---

## Chaos Arena (Related Mode — For Reference)

Chaos Arena was a limited-time PvP event variant featuring Sheogorath as announcer. Key differences from Versus Arena:
- Every match featured 1–2 special scenarios or lanes
- Players could use **Wabbajack** up to 5 times during draft to transform card picks into random alternatives (maintaining rarity but removing class restrictions)
- Shared ranking with Versus Arena
- Ran monthly from December 2016 until discontinuation during the Sparkypants client migration

---

## V1 Design Specification

The following decisions were made for the first implementation pass of Solo Arena.

### V1 Scope

**In scope:**
- Core flow (class select → draft → matches → run end)
- Post-win card picks (deck grows after each win)
- Boss relics (all 6)
- Elo system (hidden, persists across runs)
- Run persistence (save/resume across game sessions)

**Out of scope (future iterations):**
- Costs and rewards (no in-game economy yet)
- Special lanes (Field/Shadow only for v1)
- Ranking system (9 tiers — cosmetic only without rewards)
- Feature matches (named opponents with dialogue)
- Chaos Arena / Versus Arena

### Complete Game Flow

1. Main menu → "Arena" button (placed between "Match" and "Deck Builder", same visual style)
2. If active run exists → straight to **Run Status** screen
3. If no active run → **Class Selection** screen
4. Class Selection → **Draft** screen (30 picks)
5. Draft complete → **Run Status** screen
6. "Fight" button → **Match**
7. Match ends → **Victory/Defeat** message with "Continue" button
8. After win (not boss) → **Draft** screen for 1 post-win pick → **Run Status**
9. After boss win → No card pick → **Run Summary** screen → Main menu
10. After loss (not 3rd) → **Run Status** screen
11. After 3rd loss → **Run Summary** screen → Main menu
12. "Abandon" button on Run Status → Run over → Main menu

### UI Screens

#### Class Selection
- 3 buttons/cards showing class name + two attribute icons
- Simple, functional, clean — no animations
- Player clicks one to select

#### Draft Screen (reused for post-win picks)
- **Center/top**: 3 full card renders (the pick options)
- **Right sidebar**: Always-visible compact card list of deck-in-progress; hovering a card shows full card view
- **Below deck list**: Magicka curve chart
- For post-win picks: same screen, just 1 pick instead of 30
- Cannot skip — must pick a card

#### Run Status Screen
- Win/loss record displayed as text/numbers
- Current match number (e.g. "Match 5 of 9")
- "Fight" button to start next match
- "Abandon Run" button
- Compact deck list with hover preview (same component as draft sidebar)

#### Match Result
- Victory/Defeat message overlay after match ends
- "Continue" button to proceed to next screen

#### Run Summary Screen
- Final win/loss record
- Button to return to main menu

### Card Draft Details

- 30 picks total, each offering 3 cards of the same rarity
- Player selects 1 card per pick
- Rarity per pick determined by probability roll: ~60% Common, ~25% Rare, ~10% Epic, ~2.2% Legendary
- Card pool: all **collectible** cards from the selected class's two attributes + Neutral cards
- Copy limits enforced during draft: unique cards max 1 copy, regular cards max 3 copies
- Include all collectible cards even if effects are potentially buggy (helps identify and fix issues)
- Exclude non-collectible cards (cards that can only be generated by other cards)

### Post-Win Card Picks

- After each win (except boss win) → player gets 1 pick of 3 cards
- Selected card is added to the deck (cumulative — deck grows beyond 30)
- Mandatory — player cannot skip the pick
- Same rarity probability distribution as the initial draft

### AI Opponent Decks

- **AI-drafted decks**: Each opponent's deck is built by simulating a draft process
- **Draft quality scales with difficulty**: Three levers determine draft quality:
  1. **Card evaluation**: Bad drafter picks more randomly; good drafter evaluates card quality (stats-for-cost, keywords)
  2. **Curve awareness**: Bad drafter ignores magicka curve; good drafter balances distribution
  3. **Synergy awareness**: Bad drafter picks in isolation; good drafter considers tribal/keyword synergies with already-picked cards
- **Deck size**: Opponent N has 29+N cards (matches the player's deck size at that point in the run)
- **Attribute selection**: Mix of random and weighted to avoid repeating the same matchup too often within a run
- **Difficulty ordering**: Ascending — easiest opponents early, hardest last, boss is always the hardest
- **No opponent identity for v1** — displayed as "Opponent X of 9"

### Boss Match (Match 9)

One of 6 relics is randomly selected for the boss:

| Relic | Exact Effect |
|-------|-------------|
| Iron | Boss starts with +50 health (80 total) |
| Corundum | All boss creatures get +1 attack |
| Moonstone | When boss's rune breaks, boss gets a random 0-cost card in hand |
| Quicksilver | At start of player's turn, deal 1 damage to player |
| Ebony | Boss starts with City Gates in one lane (0/6 creature: "Your opponent can't summon creatures to the other lane") |
| Malachite | Boss starts with a 0/4 Guard creature in each lane |

### Match Configuration

- Health: 30 for both players (except boss with Iron Relic → 80)
- Rune thresholds: [25, 20, 15, 10, 5] (standard)
- Lanes: Field + Shadow only (standard_versus board profile)
- First player: Random each match; second player receives Ring of Magicka (3 charges)
- Mulligan: Standard rules (view top 3, select any to redraw, reshuffle)

### Elo System

- Persists in a separate file (e.g. `user://arena/elo.dat`), independent of run state
- Starting Elo: 1200
- Range: 800 (minimum) to 2000 (maximum)
- Adjusts only after a run completes (simple formula based on total wins)
- Determines opponent difficulty distribution within a run:
  - At Elo 1200: 2 weak, 5 average, 2 strong opponents
  - Arranged in ascending difficulty order across matches 1–8
- No manual reset — Elo drops naturally when the player loses runs

### Run Persistence

- One active run at a time
- Run state saved to disk after each match (e.g. `user://arena/run.json`)
- Saved state includes: selected class/attributes, current deck (with post-win additions), win/loss count, current match number
- Entering Arena with an active run → goes straight to Run Status screen
- Abandoning a run clears the saved state

---

## Sources

- [UESP — Solo Arena](https://en.uesp.net/wiki/Legends:Solo_Arena)
- [UESP — Solo Arena Opponents](https://en.uesp.net/wiki/Legends:Solo_Arena/Opponents)
- [UESP — Versus Arena](https://en.uesp.net/wiki/Legends:Versus_Arena)
- [UESP — Chaos Arena](https://en.uesp.net/wiki/Legends:Chaos_Arena)
- [UESP — Lanes](https://en.uesp.net/wiki/Legends:Lanes)
- [UESP — Adoring Fan](https://en.uesp.net/wiki/Legends:Adoring_Fan)
- [Bethesda Support — What is the Arena?](https://help.bethesda.net/app/answers/detail/a_id/45020)
- [Bethesda Support — Game Modes](https://help.bethesda.net/app/answers/detail/a_id/37888)
- [Between the Lanes — CVH's Guide to Mastering Arena](https://betweenthelanes.net/2016/11/26/cvhs-guide-to-mastering-arena-the-draft/)
- [Between the Lanes — Tenz's Complete Solo Arena Guide](https://betweenthelanes.net/2017/02/10/tenzs-complete-solo-arena-guide/)
- [Altar of Gaming — Arena Rewards](https://altarofgaming.com/elder-scrolls-legends-solo-pvp-arena-rewards/)
- [GameSkinny — Solo Arena Strategy Guide](https://www.gameskinny.com/tips/elder-scrolls-legends-solo-arena-winning-strategy-guide/)
