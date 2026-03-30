# Unfixed Card Effects

## Mushroom Tower
**Effect:** "Ongoing\nYour actions have Betray."
**Blocker:** Betray is granted to all actions while Mushroom Tower is in the support zone. Unlike Breakthrough (which just needed overflow logic in `deal_damage`), Betray requires the engine to check for board passives after action resolution and offer the sacrifice-and-replay flow. Needs a `grant_keyword_to_type` passive plus engine support in `play_action_from_hand` to detect Betray from board passives.

## Skar Drillmaster
**Effect:** "When Skar Drillmaster Rallies a creature, put a copy of the rallied creature into your hand with +1/+1."
**Blocker:** Uses `on_rally` family with `copy_rallied_creature_to_hand` op — neither is implemented in the engine. Needs Rally resolution to emit per-target events that a board passive can react to, plus a new op to copy a card to hand with stat bonuses. Same bug class as Bolvyn Venim (`on_rally_empty_hand`).
