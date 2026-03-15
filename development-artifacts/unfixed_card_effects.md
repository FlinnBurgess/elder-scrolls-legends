# Unfixed Card Effects

Cards whose effects have been identified as not yet wired up with `triggered_abilities`.

## Remaining

### Needs target choice mechanic (player picks a target)

- **Valenwood Huntsman** (`str_valenwood_huntsman`) — "Summon: Deal 1 damage." Needs player to choose a creature or player target. No target selection system exists yet.
- **Skooma Racketeer** (`agi_skooma_racketeer`) — "Summon: Give a creature Lethal." Needs player to choose a creature target.
- **Crushing Blow** (`neu_crushing_blow`) — "Deal 3 damage." Action card that needs player to choose a creature or player target.
- **Loyal Housecarl** (`wil_loyal_housecarl`) — "Prophecy. Summon: Give a creature +2/+2 and Guard." Needs player to choose a creature target.

### Needs ongoing aura mechanic

- **Orc Clan Captain** (`str_orc_clan_captain`) — "Other friendly creatures in this lane have +1/+0." Ongoing passive aura that continuously buffs lane-mates. Not trigger-based; needs a new aura system.
- **Stormhold Henchman** (`end_stormhold_henchman`) — "+2/+2 while you have 7 or more max magicka." Ongoing conditional self-buff. Needs aura or continuous-check system.

### Needs complex mechanics

- **Black Worm Necromancer** (`end_black_worm_necromancer`) — "Summon: If you have more health than your opponent, summon a random creature from your discard pile." Needs health comparison condition + summon-from-discard op.
- **Thieves Guild Recruit** (`agi_thieves_guild_recruit`) — Draw is wired, but cost reduction ("If it costs 7 or more, reduce its cost by 1") is not implemented. Needs drawn-card cost modification.

### Needs item equip lane context

- **Yew Shield** (`end_yew_shield`) — "Summon: +1/+1 for each enemy creature in this lane." Item cards don't have lane context in their triggers, so `enemy_creatures_same_lane` count can't resolve. Needs item equip flow to provide lane context on the trigger.
