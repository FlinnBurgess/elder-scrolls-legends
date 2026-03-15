# Unfixed Card Effects

Cards whose effects have been identified as not yet wired up with `triggered_abilities`.

## Remaining

- **Yew Shield** (`end_yew_shield`) — "Summon: +1/+1 for each enemy creature in this lane." Item cards don't have lane context in their triggers, so `enemy_creatures_same_lane` count can't resolve. Needs item equip flow to provide lane context on the trigger.
