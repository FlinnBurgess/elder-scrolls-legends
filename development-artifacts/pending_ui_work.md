# Pending UI Work for New Ops

Ops implemented in the engine but needing UI integration for player interaction.
AI heuristics are in place as fallbacks for all of these.

## 1. Choice Modal (NEW UI COMPONENT)

A single reusable `_show_choice_overlay()` component would unblock all 5 cards.
Should display 2-3 options (buttons or card previews) and resolve the player's pick
back into the trigger via `_chosen_option_index` or similar.

| Op | Cards | Player Sees |
|----|-------|-------------|
| `choose_one` | Barbas, Aspect of Hircine, Archcanon Saryoni | 2-3 labeled buttons (e.g. "Strength" / "Speed") |
| `waves_of_the_fallen_choice` | Waves of the Fallen | Binary: "Debuff enemies to 2/2" / "Buff friendlies to 5/5" |
| `merchant_offer` | Mudcrab Merchant | 2 card previews, pick one (other goes to opponent) |
| `vision_and_transform` | Bringer of Nightmares | 2 creature previews, pick one to transform target into |
| `guess_opponent_card` | Thief of Dreams, Caius Cosades | 2 card previews, guess which opponent has |

**AI fallback**: `choose_one` picks first option. Others use deterministic random.

## 2. Wire Existing Hand Selection UI

The `_enter_hand_selection_mode()` / `_resolve_hand_selection()` system already
exists in match_screen.gd. Just needs to be triggered by this op.

| Op | Card | What's Needed |
|----|------|---------------|
| `trade_hand_card_for_opponent_deck` | Barter | Trigger hand selection, then swap chosen card for random from opponent deck |

**AI fallback**: Discards cheapest card.

## 3. Wire Existing Discard Selection UI

The `_show_discard_choice_overlay()` / `_on_discard_choice_selected()` system
already exists. Needs wiring to populate candidates from discard and resolve
the summon.

| Op | Card | What's Needed |
|----|------|---------------|
| `summon_from_discard` | Odirniran Necromancer | Show discard pile creatures with less power than source, player picks one to summon |

**AI fallback**: Picks via `_chosen_target_id` on trigger.

## 4. Secondary Targeting

After the primary action resolves (move a creature), the player needs to pick
a second target (creature or player) for 1 damage. Could follow the betray
mechanic's two-step targeting pattern in match_screen.gd.

| Op | Card | What's Needed |
|----|------|---------------|
| `deal_damage_from_creature` | Archer's Gambit | After move resolves, enter targeting mode for the moved creature to deal 1 damage |

**AI fallback**: Deals damage to a random enemy creature.

## 5. Opponent-Side Interaction (Low Priority)

These only matter in human-vs-human multiplayer. AI fallbacks handle them fine.

| Op | Card | What's Needed |
|----|------|---------------|
| `opponent_gives_card_from_hand` | Gentleman Jim Stacey | Opponent-side hand selection UI (opponent chooses which card to give) |

**AI fallback**: Opponent gives cheapest card.
