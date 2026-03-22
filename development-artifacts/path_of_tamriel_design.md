# Path of Tamriel — PvE Adventure Mode Design Document

A design reference and implementation plan for a roguelike PvE adventure mode inspired by *Legends of Runeterra: Path of Champions*, adapted to Elder Scrolls Legends gameplay.

---

## Part 1: Path of Champions — Feature Breakdown

Understanding the full scope of PoC is the foundation for making smart adaptation decisions.

### 1.1 Core Loop

Each run follows this structure:

1. **Choose a Champion** — every champion has a unique starting deck tuned to their playstyle
2. **Traverse a node map** — a semi-linear graph of nodes leading to a final boss
3. **Fight enemies and visit encounters** — battles grow your deck and power level
4. **Win or revive** — health persists between battles; reaching 0 costs a Revive token
5. **Collect post-run rewards** — XP, gold, fragments, and relics that persist across runs

The loop is explicitly roguelike: each run feels fresh due to random card and power offerings, but permanent progression ensures the player always grows stronger over time.

### 1.2 The Node Map

Each adventure is a graph of nodes. Key properties:

- **Branching paths** — the player usually chooses between two routes at forks, each with different risk/reward. All branches always converge before mini-boss and final boss nodes — these cannot be skipped
- **Hidden nodes** — most nodes are unknown until reached, except guaranteed boss nodes and Power nodes
- **Health carries over** — the player's Nexus HP persists through the entire adventure
- **Mini-boss at the midpoint** — defeating the mini-boss grants a full heal, making it a critical checkpoint

#### Node Types

| Node | Description |
|------|-------------|
| **Combat (Foe)** | Standard battle vs. an AI enemy with a thematic deck |
| **Mini-boss** | Tougher mid-adventure fight; victory grants a full heal |
| **Final Boss** | The hardest fight; completing it ends the adventure and grants rewards |
| **Power Node** | Choose one of three passive powers to add to your run |
| **Reinforcement Node** | Add a card (unit or action) to your deck from a random selection |
| **Champion Node** | Add a secondary champion to your deck |
| **Item Chest** | Choose an item to attach to a card in your deck, buffing it |
| **Shop** | Spend gold to buy cards, items, or powers; costs a reroll token to refresh |
| **Healer** | Restore Nexus HP; guaranteed before boss fights |
| **Event Node (!)** | Narrative encounter offering unique choices — optional combat for a power, a card sacrifice for a reward, etc. |

### 1.3 In-Run Resources

| Resource | Purpose |
|----------|---------|
| **Health (Nexus HP)** | Carries over between battles; losing it all requires a Revive or ends the run |
| **Gold** | Earned from winning battles; spent in shops |
| **Reroll Tokens** | Refresh the offerings at any node once; essential for steering a run's direction |
| **Revives** | Allow a retry after a loss, restoring HP to 100%; limited per run |
| **Regen** | Passive HP regeneration after battles, granted by some relics/powers |

### 1.4 Powers

Powers are passive run-wide buffs chosen from a random selection of three, usually at dedicated Power nodes or as event rewards. They persist only for the current run.

Examples:
- *Spell Slinger*: The first spell you play each turn costs 0
- *Lifesteal Aura*: All your units gain Lifesteal
- *Double Trouble*: Whenever you summon a 1-cost unit, summon a copy of it

The quality and interaction of powers is the primary driver of "broken" run synergies — a major source of fun.

> **ESL Adaptation Note:** In Path of Tamriel, Powers are called **Boons** — passive blessings granted by the Divines or Daedric Princes as you journey across Tamriel. This fits the lore of shrine blessings and divine favour, and avoids any confusion with Shouts, which are an existing mechanic in ESL.

### 1.5 Items

Items are equipment attached to individual cards in your deck, permanently modifying them for the run. For example, attaching an item to a creature might give it +2/+2 and a new keyword. Items come in tiers (common → epic), and discovering the right item for your key card is a pivotal moment in any run.

### 1.6 Relics (Persistent Cross-Run Upgrades)

Relics are permanent items equipped before a run begins. They provide passive bonuses that persist across every run for that deck. Relic slots unlock through deck levelling, and you can equip up to three at max progression.

### 1.7 Champion Progression (Persistent)

Each champion has two levelling tracks:

- **Champion Level**: Earned by completing adventures. Unlocks deck upgrades (better starting cards), more relic slots, and bonus starting resources
- **Star Power / Constellation**: Unlocked with Champion Fragments. Grants passive hero powers that apply every run. A 1-star champion might have "deal 1 to the enemy Nexus when you play a spell"; at 2 stars they also start with 1 bonus mana every turn

### 1.8 Account-Level Progression (Legend Level)

Separate from individual champions, your Legend Level is a global account progression track. Higher legend levels grant:
- More starting gold per run
- Extra reroll tokens
- Vision (seeing more hidden nodes ahead)
- Bonus starting Revives

### 1.9 Adventure Structure

Adventures are divided into:

- **Champion Campaigns**: Narrative adventures unique to each champion, unlocked as that champion levels up
- **World Adventures**: Replayable adventures that any champion can tackle, with region-specific enemies and flavour

### 1.10 Enemy Modifiers

Each adventure has a **global mutator** (a rule applied to all enemies), and individual enemies have their own **enemy powers** — passive effects that modify how their deck plays. For example, an enemy might have "whenever your units die, they deal 1 damage to your Nexus" or "the enemy starts with a 3/3 unit in play."

---

## Part 2: Adapting PoC to Elder Scrolls Legends

### 2.1 The Core Design Problem

PoC is built around champions as identity anchors. Jinx IS the deck. Her star powers, relic synergies, and level-up ability are all baked into a single cohesive fantasy. ESL doesn't have that, and we shouldn't try to bolt it on — ESL legendaries are powerful, flavourful cards but they're one piece of a strategy, not a standalone identity. Rather than fight the grain of ESL's design, the adaptation leans into what ESL does naturally.

The adaptation question is: **what is the ESL equivalent of a champion identity?**

The answer proposed here: **Faction/Theme Archetypes anchored by a group of Legendary cards**.

Rather than one heroic champion, each starting deck is built around a thematic faction or crossover. The deck IS the identity. You might run **The Dragons of Skyrim** — a Strength/Willpower deck where Alduin, Odahviing, Paarthurnax, and Mulaamnir form the core engine. Or you might run **The Thieves Guild** — an Agility/Intelligence deck that leans on Pilfer, Drain, and Shadow, anchored by Brynjolf and Ahnassi.

### 2.2 Deck Attributes

Each starting deck is assigned either two or three attributes, following ESL's standard class system. Two-attribute decks use the existing named classes (e.g. Scout, Assassin, Battlemage); three-attribute decks follow the Great Houses / Alliance War faction model and have larger minimum deck sizes. All card pool offerings during a run should be restricted to cards within the deck's assigned attributes, to preserve thematic coherence.

### 2.3 Thematic Deck Archetypes

Below are proposed starting archetypes, each centred on a group of related legendaries and supported by a thematic card pool. Each deck has one designated **starting adventure** unique to it; all other adventures in the mode are playable by any deck.

#### 🐉 The Dragons of Skyrim
**Attributes:** Strength / Willpower (Crusader)
**Identity:** High-cost dominance. Slow start, unstoppable late game. Synergies around summoning and sacrificing dragons.
**Anchor Legendaries:** Alduin, Odahviing, Paarthurnax, Miraak, Mulaamnir, Nahagliiv, Nahkriin
**Starting Adventure:** *The Dragon Crisis* — the Dragonborn's desperate stand against Alduin's return
**Boss:** Alduin

---

#### 🗡️ The Dark Brotherhood
**Attributes:** Agility / Endurance (Scout)
**Identity:** Lethal, Last Gasp, and sacrifice. Kill your own units for value. Drain synergies.
**Anchor Legendaries:** Astrid, Lucien Lachance, Cicero the Betrayer, The Night Mother, Emperor Titus Mede II
**Starting Adventure:** *The Five Tenets* — a contract gone wrong inside the Falkreath Sanctuary
**Boss:** Emperor Titus Mede II

---

#### 🧙 The College of Winterhold
**Attributes:** Intelligence / Willpower (Mage)
**Identity:** Actions, Prophecy, and card draw. Cycle aggressively to trigger cascading effects.
**Anchor Legendaries:** Ancano, College of Winterhold (Support), Divayth Fyr, Mannimarco
**Starting Adventure:** *Eye of Magnus* — the Thalmor's play to seize the Eye of Magnus
**Boss:** Ancano

---

#### 🐺 The Companions
**Attributes:** Strength / Agility (Archer)
**Identity:** Aggressive creatures, Beast Form, and rune-breaking payoffs.
**Anchor Legendaries:** Aela the Huntress, Aspect of Hircine, Kodlak Whitemane
**Starting Adventure:** *Blood of Sovngarde* — the Companions' hunt for a cure to Hircine's curse
**Boss:** Night Talon Lord *(a vampire lord preying on Whiterun's hold)*

---

#### 🐱 The Thieves Guild
**Attributes:** Agility / Intelligence (Assassin)
**Identity:** Pilfer, Shadow, and gold accumulation. Hit hard and fast with unblockable units.
**Anchor Legendaries:** Brynjolf, Ahnassi, Cyriel, Naryu Virian
**Starting Adventure:** *The Heist of the Century* — stealing the Crown Jewels from the White-Gold Tower
**Boss:** Mannimarco *(leading the Worm Cult's takeover of the Guild's operations)*

---

#### ⚔️ House Dagoth
**Attributes:** Strength / Intelligence / Endurance (House Dagoth — three-attribute)
**Identity:** Ash creatures, Ward-stripping actions, and attrition. Corrupt the board over time.
**Anchor Legendaries:** Dagoth Ur, Mehrunes' Razor, Orb of Vaermina
**Starting Adventure:** *Heart of Lorkhan* — the trek into Red Mountain to confront the Sharmat
**Boss:** Dagoth Ur

---

#### 🌑 The Daedric Invasion
**Attributes:** Intelligence / Agility / Endurance (three-attribute)
**Identity:** Oblivion Gates as an ongoing Support threat; invade and overwhelm.
**Anchor Legendaries:** Mankar Camoran, Mehrunes' Razor, Dremora Markynaz
**Starting Adventure:** *The Gates of Oblivion* — closing Oblivion Gates across Cyrodiil before Camoran reopens them
**Boss:** Mankar Camoran

---

#### 🧛 The Vampire Lords
**Attributes:** Endurance / Agility (Scout)
**Identity:** Drain, regeneration, and self-harm for power. Let your Nexus take hits to fuel escalating threats.
**Anchor Legendaries:** Lord Harkon, Doomcrag Vampire, Night Talon Lord, Aundae Clan Sorcerer
**Starting Adventure:** *Castle Volkihar* — infiltrate Harkon's court and survive the night
**Boss:** Lord Harkon

---

### 2.4 Non-Boss Encounter Identity

Every non-boss combat encounter should be presented through the lens of a specific thematic creature card — the visual and mechanical anchor for that fight. The encounter screen should display the featured card's artwork and name prominently, and the enemy deck should be built around it or heavily feature it.

For example, in a Dark Brotherhood adventure:
- A mid-path encounter is titled *"Ald Velothi Assassin"* and shows that card's art — the enemy plays a Shadow/Lethal Assassin build that uses it as a key threat
- Another node is titled *"Doomcrag Vampire"* — an anomalous vampiric contractor the Brotherhood has dealings with — and the AI plays a Drain/Endurance deck around that card

This makes every battle feel narratively grounded and gives players immediate mechanical information about what they're walking into. It also naturally guides enemy deck construction: each enemy archetype is defined by its headline card.

### 2.5 ESL-Specific Mechanic Adaptations

| PoC Concept | ESL Equivalent |
|-------------|---------------|
| Champion Level-Up (mid-match) | *Not adapted* — ESL legendaries do not level up mid-match in the PoC sense; the deck evolves between battles through card additions and item attachments instead |
| Star Powers | Deck Star Powers — permanent passive bonuses unlocked through run completions, tiered 1–3 per starting deck |
| Powers (run-wide passives) | **Boons** — passive blessings granted by the Divines or Daedric Princes encountered along the journey |
| Items (card buffs) | Item cards — attach an ESL Item card to a creature in your deck, modifying it for the run |
| Global Adventure Mutator | Daedric Influence — a Daedric Prince's power reshapes the rules of the entire adventure |
| Enemy Powers | Enemy Passives — each encounter's headline creature grants a passive rule modifier to the AI |
| Healer Node | Shrine of Arkay / Temple — restore Nexus HP |
| Shop Node | Merchants Guild / Thieves Bazaar — spend gold on cards |
| Event Node | Lore Encounter — text-based choices with thematic consequences |
| Reinforcement Node | Recruit — add a creature or action to your deck |
| Champion Node | Companion — a second legendary joins your party mid-run |

### 2.6 The Two-Lane System and Boons

ESL's two lanes — the **Field Lane** and the **Shadow Lane** — are a core mechanical differentiator that PoC has no equivalent for. Boons are an ideal place to make lane mechanics feel special and variable, since each run can fundamentally change how lanes behave. Some ideas:

- *No Man's Land*: The Shadow Lane is disabled for this run. All creatures must be played into the Field Lane, dramatically changing Guard and Cover interactions
- *Battleground*: Creatures played into the Field Lane have Cover until they attack
- *Divided Kingdom*: At the start of each of your turns, the active lane alternates. You can only play and attack with creatures in the active lane that turn
- *Cursed Ground*: Creatures in the Shadow Lane take 1 damage at the end of each turn
- *Holy Ground*: Creatures in the Field Lane gain +0/+1 at the start of each of your turns
- *Shattered Fate*: Prophecy cards triggered by a rune break cost 0 magicka this turn, and can be played into either lane
- *Ward of the Divines*: At the start of combat, the creature with the highest power in the Field Lane gains Ward

Some of these are significant enough to be rare Boons available only from high-difficulty adventures or as Daedric Influence rewards.

### 2.7 Daedric Influence Mutators

Each adventure has a global mutator themed around a Daedric Prince whose influence pervades the region. This is applied for the entire run and changes the texture of every battle:

- *Sheogorath's Whimsy*: At the start of each player's turn, all creatures in one random lane swap their power and health values
- *Mehrunes Dagon's Flame*: At the end of each enemy turn, a random friendly creature takes 1 damage
- *Molag Bal's Dominion*: Enemy creatures with Drain restore double health when dealing damage
- *Sanguine's Gift*: Both players draw an extra card each turn
- *Vaermina's Torment*: The enemy's Prophecy cards trigger at the start of their turn regardless of rune breaks
- *Namira's Hunger*: Whenever a creature is destroyed, its owner gains 1 magicka next turn

### 2.8 Rune System Integration

The rune mechanic — drawing a card and potentially triggering Prophecy when your Nexus takes damage — is rich territory for Boons and Star Powers:

- *Prophet's Sight*: Whenever a rune breaks, look at the top 3 cards of your deck and rearrange them in any order
- *Runic Ward*: When your first rune breaks each adventure, summon a 2/4 Guard creature
- *Shattered Fate*: Prophecy cards cost 0 magicka when triggered by a rune break
- *Fortified Spirit*: Your runes have +1 health — enemies must deal one extra damage to break each one

---

## Part 3: Implementation Plan

This is structured as a series of milestones, each playable and self-contained. Build the mode incrementally without needing to implement everything before it's fun.

---

### Milestone 1 — The Skeleton (MVP)

**Goal:** A playable, end-to-end run against AI opponents with a simple map.

**What to build:**
- A small selection of **3–4 starting decks** — recommended first four: Dragons, Dark Brotherhood, College of Winterhold, Companions
- A **linear node map UI** — a simple vertical list or tree of buttons, each representing a node; no branching yet
- Node types for this milestone:
  - **Combat** — triggers a standard game against an AI deck
  - **Mini-boss Combat** — same as combat but a harder AI deck
  - **Final Boss** — hardest AI deck; completing it ends the run and shows a Victory screen
- **Persistent Nexus HP** — track health between battles; if it hits 0, the run ends
- **Post-run screen** — show final result, deck used, nodes cleared
- No rewards or persistent progression yet — pure gameplay loop first

**AI enemy decks needed:** 2–3 per adventure. Each enemy deck should be built around and named after a thematic headline creature card. Start with one adventure per starting deck.

**Deliverable:** You can pick a deck, fight through a series of 6–8 battles with persistent health, and either win the adventure or lose mid-way.

---

### Milestone 2 — Non-Combat Nodes & Branching

**Goal:** The map becomes interesting between battles and path choices matter.

**What to add:**
- **Branching map** — at 2–3 points in each adventure, the player sees two paths with different node compositions visible. All branches must converge before the mini-boss and final boss — these nodes can never be skipped
- **Healer Node** — restore a fixed amount of Nexus HP (e.g. heal 10, or restore to 75%)
- **Reinforcement Node** — present 3 cards; pick 1 to add to your deck for this run, drawn from a pool appropriate to the deck's attributes
- **Shop Node** — present 6 cards; pay gold to add them to your deck. Gold earned from winning battles (e.g. 30 gold per win)
- **Gold** resource tracked during a run, spent at shops
- **Map visibility** — show node type icons but keep non-adjacent nodes greyed out

**Deliverable:** Runs feel varied. Players make meaningful path choices, and their deck grows during the run.

---

### Milestone 3 — Boons

**Goal:** Each run develops a unique identity through passive boon selection.

**What to add:**
- **Boon Node** — present 3 randomly chosen Boons; pick 1 to apply for the rest of the run
- Boons are passive effects that hook into the battle system — modifying rules, granting persistent keywords to your creatures, or triggering on game events such as rune breaks or creature deaths
- Start with **12–15 Boons** to give meaningful variety. Examples using ESL mechanics:
  - *Marked for Death*: Whenever an enemy creature is destroyed, deal 1 damage to the enemy Nexus
  - *Soul Tear*: When one of your creatures is destroyed, add a random creature of the same magicka cost to your hand
  - *First Lesson*: The first action you play each turn costs 1 less magicka
  - *Battleground*: Creatures you play into the Field Lane have Cover until they attack
  - *Shattered Fate*: Prophecy cards triggered by a rune break cost 0 magicka this turn
  - *Harbinger's Call*: At the start of each of your turns, if you have no creatures in play, summon a random 1-cost creature from your deck's attribute pool
- Boons are framed as blessings received at a roadside Divine shrine or Daedric altar encountered between battles
- Active Boons should be visible in the HUD during battle

**Deliverable:** Every run feels mechanically distinct. Players start to plan around discovered synergies.

---

### Milestone 4 — Deck Drafting & Items

**Goal:** Deeper deck customisation during a run.

**What to add:**
- **Richer card pool for Reinforcement nodes** — cards tiered by rarity; higher-rarity cards appear deeper in the adventure
- **Item attachment system** — some nodes or post-battle rewards offer an Item card that can be attached to a creature in your deck, permanently modifying it for the run. Uses ESL's existing Item card concept as the framing — equip a weapon, armour, or accessory to buff a creature's stats or add a keyword. After winning a reward battle, the player selects which creature in their current deck receives the item
  - Start with 8–10 items: stat boosts, Guard, Drain, Charge, Ward, magicka cost reduction, "deal 1 damage when this attacks," etc.
- **Event Nodes (!)** — text encounter nodes offering a binary choice, e.g.:
  - *"A wounded mercenary offers to join you in exchange for healing"* — lose 10 Nexus HP, add a rare creature to your deck
  - *"An assassin demands a toll"* — pay 40 gold to pass, or fight them for a Boon
  - *"A merchant fence offers suspicious goods"* — spend 30 gold for 2 random cards
- **Reroll Tokens** — players start with 1–2 per run; spending one reshuffles the offerings at any node

**Deliverable:** Deckbuilding during a run feels meaningful. A well-placed item on a key legendary is a pivotal moment.

---

### Milestone 5 — Persistent Progression

**Goal:** Playing runs makes you permanently stronger — the core retention hook.

**What to add:**
- **Deck Level** — tracks XP earned from completed runs; each level unlocks:
  - Better starting cards (weaker base deck cards swapped for stronger ones)
  - Additional starting gold
  - A starting reroll token
- **Star Powers** (1–3 stars per starting deck) — permanent passive bonuses active at the start of every run with that deck:
  - Star 1: A thematic passive (e.g. for Dragons: *"At the start of each adventure, add one Dragon creature to your hand"*)
  - Star 2: A more impactful bonus (e.g. *"Your highest-cost creature in your starting deck begins each run with +1/+1"*)
  - Star 3: A strong run-modifier (e.g. *"The first Boon you discover is always drawn from the Rare tier or above"*)
  - Stars unlocked by completing adventures at increasing difficulty ratings
- **Relics** — permanent items equippable to a starting deck before a run begins (up to 2 slots initially), earned by completing adventures or hitting deck level milestones. Examples:
  - *Skeleton Key*: Start each run with 50 bonus gold
  - *Amulet of Kings*: Your Nexus has 5 bonus HP at the start of each run
  - *Thief's Cache*: Shops always offer one extra card
- A **Deck Selection screen** showing level, equipped relics, and star powers before beginning a run

**Deliverable:** The game now has a sense of permanence. A well-levelled deck feels meaningfully different from a fresh one.

---

### Milestone 6 — Multiple Adventures & World Map

**Goal:** The mode has breadth — different stories and challenges across Tamriel.

**What to add:**
- Each starting deck gets **2–3 adventures** of increasing difficulty, with one being their unique starting adventure; the remaining adventures are playable by any deck
- A **World Map screen** — a Tamriel-inspired map showing available adventures grouped by region:
  - Skyrim → Dragons, Companions, Civil War
  - Cyrodiil → Dark Brotherhood, Daedric Invasion
  - Morrowind → House Dagoth, Tribunal
  - Elsweyr → Khajiit Rogues
  - High Rock → Daggerfall Covenant, Vampire Lords
- Adventures have **difficulty ratings** and **first-clear rewards**

**Enemy deck variety:** Each region should have 4–6 distinct enemy decks each defined by their headline creature card, including signature boss encounters.

**Deliverable:** The mode has legs. Players have reasons to return with different decks and try new adventures.

---

### Milestone 7 — Polish & Depth

**Goal:** The mode feels like a complete feature.

**What to add:**
- **Daedric Influence Mutators** — fully implement adventure-wide rule modifiers as described in Part 2; each adventure draws one mutator from a thematically appropriate pool
- **Companion Node** — add a second legendary to your deck mid-run
- **Narrative flavour text** — every node, encounter, and event has 1–3 lines of descriptive text or dialogue grounding the run in TES lore
- **Run history screen** — shows past run results, decks used, bosses defeated, Boons collected
- **Difficulty scaling** — an optional "Legendary" modifier for completed adventures that increases enemy Nexus HP and adds an extra enemy passive, with improved rewards

---

## Part 4: Content Rollout Priority

For the initial playable build, implement these decks and adventures first. All bosses listed are confirmed unique legendary cards in the ESL card pool across all expansions.

| Priority | Deck | Starting Adventure | Boss Card |
|----------|------|--------------------|-----------|
| 1 | Dragons of Skyrim | The Dragon Crisis | Alduin *(Heroes of Skyrim)* |
| 2 | Dark Brotherhood | The Five Tenets | Emperor Titus Mede II *(Core Set)* |
| 3 | College of Winterhold | Eye of Magnus | Ancano *(Heroes of Skyrim)* |
| 4 | The Companions | Blood of Sovngarde | Night Talon Lord *(Core Set)* |
| 5 | The Thieves Guild | The Heist of the Century | Mannimarco *(Core Set)* |
| 6 | House Dagoth | Heart of Lorkhan | Dagoth Ur *(Houses of Morrowind)* |
| 7 | The Daedric Invasion | The Gates of Oblivion | Mankar Camoran *(Jaws of Oblivion)* |
| 8 | Vampire Lords | Castle Volkihar | Lord Harkon *(Heroes of Skyrim)* |

Each pairing has strong lore justification, a clear narrative arc, a mechanically distinct starting deck, and a boss that exists as a named legendary in the game.

---

*This document is a living design reference. Update it as systems are prototyped and designs are validated through playtesting.*
