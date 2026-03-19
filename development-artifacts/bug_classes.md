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

## Effect target filter not applied in _resolve_card_targets
Target filters like `target_filter_wounded` were defined on effect descriptors in card data but only handled in the player-chosen targeting path (the `_resolve_targets_for_trigger` function around line 233). The `_resolve_card_targets` function — used by effect ops like `destroy_creature`, `silence`, `shackle`, etc. — had its own set of supported filters (`target_filter_subtype`, `target_filter_keyword`, `target_filter_attribute`, `target_filter_definition_id`, `target_filter_max_power`) but was missing others. Because the filter key is simply absent from the resolution logic, the effect silently applies to all matching targets with no error.
Example: Falinesti Reaver (`target_filter_wounded: true` on `destroy_creature` op)
How to spot: User reports an effect hitting targets it shouldn't (e.g. destroying unwounded creatures, affecting wrong subtypes). Check if the `target_filter_*` key from the card's effect descriptor is actually handled in `_resolve_card_targets` in `match_timing.gd`.

## Unimplemented effect operation
Card has a `triggered_abilities` entry with an `op` value that doesn't exist in `match_timing._apply_effects()`. The effect silently does nothing because unknown ops fall through the match statement. This typically happens when new cards are batch-imported with placeholder ops that haven't been implemented in the engine yet.
Example: Winterhold Illusionist (`banish_and_return_end_of_turn`)
How to spot: User reports a card "doesn't do anything" despite having rules text and triggered abilities. Grep the op name from the card's triggered_abilities against `match_timing.gd` and `extended_mechanic_packs.gd` to see if it's handled.
