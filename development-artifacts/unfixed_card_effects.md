# Unfixed Card Effects

Cards whose effects have been identified as not yet wired up with `triggered_abilities`.

## Remaining

### Needs target choice mechanic (player picks a target)

- **Valenwood Huntsman** (`str_valenwood_huntsman`) — "Summon: Deal 1 damage." Needs player to choose a creature or player target. No target selection system exists yet.
- **Skooma Racketeer** (`agi_skooma_racketeer`) — "Summon: Give a creature Lethal." Needs player to choose a creature target.
- **Crushing Blow** (`neu_crushing_blow`) — "Deal 3 damage." Action card that needs player to choose a creature or player target.
- **Loyal Housecarl** (`wil_loyal_housecarl`) — "Prophecy. Summon: Give a creature +2/+2 and Guard." Needs player to choose a creature target.
- **Sunhold Medic** (`wil_sunhold_medic`) — "Summon: Give a creature +0/+2." Needs player to choose a creature target.
- **Ash Servant** (`int_ash_servant`) — "Summon: Deal 2 damage to a creature." Needs player to choose a creature target.
- **Piercing Javelin** (`wil_piercing_javelin`) — "Prophecy. Destroy a creature." Action that needs player to choose a creature target.
- **Vicious Dreugh** (`neu_vicious_dreugh`) — "Summon: Destroy an enemy support." Needs player to choose a support target.

### Needs ongoing aura mechanic

- **Orc Clan Captain** (`str_orc_clan_captain`) — "Other friendly creatures in this lane have +1/+0." Ongoing passive aura that continuously buffs lane-mates. Not trigger-based; needs a new aura system.
- **Stormhold Henchman** (`end_stormhold_henchman`) — "+2/+2 while you have 7 or more max magicka." Ongoing conditional self-buff. Needs aura or continuous-check system.
- **Rihad Battlemage** (`str_rihad_battlemage`) — "+0/+3 and Guard while equipped with an item." Ongoing conditional buff. Needs aura system that checks for attached items.

### Needs complex mechanics

- **Black Worm Necromancer** (`end_black_worm_necromancer`) — "Summon: If you have more health than your opponent, summon a random creature from your discard pile." Needs health comparison condition + summon-from-discard op.
- **Thieves Guild Recruit** (`agi_thieves_guild_recruit`) — Draw is wired, but cost reduction ("If it costs 7 or more, reduce its cost by 1") is not implemented. Needs drawn-card cost modification.
- **Royal Sage** (`int_royal_sage`) — "Summon: If you have more health than your opponent, give each friendly creature a random Keyword." Needs health comparison condition + multi-target grant_random_keyword.
- **Golden Saint** (`wil_golden_saint`) — "Guard. Summon: If you have more health than your opponent, summon a Golden Saint in the other lane." Needs health comparison condition + summon_copy_to_other_lane.

### Needs "put card into hand" mechanic

- **Dunmer Nightblade** (`int_dunmer_nightblade`) — "Last Gasp: Put an Iron Sword into your hand." Needs a "generate card to hand" op.
- **High Rock Summoner** (`int_high_rock_summoner`) — "Summon: Put a random Atronach into your hand." Needs a "generate random card to hand" op.
- **Crown Quartermaster** (`int_crown_quartermaster`) — "Summon: Put a Steel Dagger into your hand." Needs a "generate card to hand" op.
- **Stronghold Incubator** (`neu_stronghold_incubator`) — "Last Gasp: Put two random Dwemer into your hand." Needs a "generate random cards to hand" op.

### Needs "on attack" trigger family

- **Fiery Imp** (`str_fiery_imp`) — "When Fiery Imp attacks, deal 2 damage to your opponent." Needs an `on_attack` trigger family that fires when the creature attacks.

### Needs "all creatures in lane" target (both sides)

- **Skaven Pyromancer** (`str_skaven_pyromancer`) — "Summon: Deal 1 damage to all other creatures in this lane." Needs a target type that includes all creatures in the lane from both players, excluding self.

### Needs item equip lane context

- **Yew Shield** (`end_yew_shield`) — "Summon: +1/+1 for each enemy creature in this lane." Item cards don't have lane context in their triggers, so `enemy_creatures_same_lane` count can't resolve. Needs item equip flow to provide lane context on the trigger.
