# Pending UI Work for New Ops — ALL COMPLETE

All ops now have both engine implementation and UI integration.

## 1. Choice Modal — DONE

Built `_show_player_choice_overlay()` in match_screen.gd with text and card modes.

| Op | Cards | Status |
|----|-------|--------|
| `choose_one` | Barbas, Aspect of Hircine, Archcanon Saryoni | DONE |
| `waves_of_the_fallen_choice` | Waves of the Fallen | DONE |
| `merchant_offer` | Mudcrab Merchant | DONE |
| `vision_and_transform` | Bringer of Nightmares | DONE |
| `guess_opponent_card` | Thief of Dreams, Caius Cosades | DONE |

## 2. Hand Selection Wiring — DONE

| Op | Card | Status |
|----|------|--------|
| `trade_hand_card_for_opponent_deck` | Barter | DONE — wired to existing `_enter_hand_selection_mode()` |

## 3. Discard Selection Wiring — DONE

| Op | Card | Status |
|----|------|--------|
| `summon_from_discard` | Odirniran Necromancer | DONE — wired to existing `_show_discard_choice_overlay()` |

## 4. Secondary Targeting — DONE

| Op | Card | Status |
|----|------|--------|
| `deal_damage_from_creature` | Archer's Gambit | DONE — pending_secondary_targets system with AI enumeration |

## 5. Opponent-Side Interaction — LOW PRIORITY (AI fallback sufficient)

| Op | Card | Status |
|----|------|--------|
| `opponent_gives_card_from_hand` | Gentleman Jim Stacey | AI gives cheapest card. Human-vs-human would need opponent hand selection. |
