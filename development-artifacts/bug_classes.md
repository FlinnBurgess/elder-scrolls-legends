# Bug Classes

## Card with spurious keywords field
Cards that grant keywords to other cards (via `grant_keyword` triggered abilities or by summoning creatures with keywords) should not have those keywords in their own `keywords` array, as this causes the keyword to display as a bold header on the card. Applies to both support cards and creatures.
Example: Elixir of Deflection, Wardcrafter, Baron of Tear, General Tullius
How to spot: User reports a keyword showing as a bold header on a card that shouldn't have it. Search for cards with a `keywords` array where the keyword doesn't appear at the start of `rules_text` (e.g. "Guard\n...") but instead appears in a "Give ... Guard/Ward" or "Summon a ... with Guard" phrase.

## Non-targeting support enters card targeting mode
`_selected_support_uses_card_targets` returned true for all supports in the support zone, regardless of whether their activate effects actually reference `event_target`. Supports that damage/heal players directly, draw cards, or shuffle decks would incorrectly enter targeting mode requiring the player to select a creature.
Example: Dark Rift
How to spot: User reports that clicking a support on the board enters targeting mode (showing targeting arrows) when the card text doesn't mention choosing a creature. Check if the support's activate trigger effects use `target_player` or other non-card targets instead of `event_target`.

## Condition checks referencing non-existent player state fields
Extended condition checks in `extended_mechanic_packs.matches_additional_conditions()` referenced `rune_count` and `max_rune_count` fields that don't exist on the player state dictionary. The actual rune state is tracked via `rune_thresholds` (an array that shrinks as runes break). Because the missing fields defaulted silently, the condition always evaluated as "0 runes destroyed", causing conditional effects to never trigger.
Example: Eastmarch Crusader
How to spot: User reports a conditional summon/trigger effect never fires despite the condition being met. Check if the condition in `extended_mechanic_packs.gd` reads from the correct player state fields by cross-referencing with `match_bootstrap.gd` (player state initialization) and `match_timing.gd` (state mutations).
