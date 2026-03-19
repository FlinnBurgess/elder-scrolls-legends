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

## Missing duration on "this turn" modify_stats effects
The `modify_stats` effect op applies permanent stat bonuses by default. Cards with "this turn" in their rules text need `"duration": "end_of_turn"` on their effect descriptor to make the bonus temporary, otherwise it persists indefinitely.
Example: Cloudrest Illusionist, Calm, Savage Ogre, War Cry
How to spot: User reports a stat buff/debuff not wearing off. Search for cards whose `rules_text` contains "this turn" alongside a `modify_stats` op that lacks a `"duration"` field.

## Unimplemented effect operation
Card has a `triggered_abilities` entry with an `op` value that doesn't exist in `match_timing._apply_effects()`. The effect silently does nothing because unknown ops fall through the match statement. This typically happens when new cards are batch-imported with placeholder ops that haven't been implemented in the engine yet.
Example: Winterhold Illusionist (`banish_and_return_end_of_turn`)
How to spot: User reports a card "doesn't do anything" despite having rules text and triggered abilities. Grep the op name from the card's triggered_abilities against `match_timing.gd` and `extended_mechanic_packs.gd` to see if it's handled.

## Subtype group used as literal subtype in filter
Card filter uses a hidden supertype (e.g., "Animal") as a `required_subtype` value, but no card in the catalog has that literal subtype — they use specific subtypes (Wolf, Beast, Spider, etc.) instead. The filter finds zero candidates and the effect silently does nothing. Fixed by adding `SUBTYPE_GROUPS` mapping in `extended_mechanic_packs.gd` that expands group names to their constituent subtypes.
Example: Wild Beastcaller (`required_subtype: "Animal"`), Eldergleam Matron (`required_subtype: "Beast"` — too narrow, should be "Animal")
How to spot: User reports a "summon/generate random X" effect doing nothing. Check if the subtype in the filter is a group name (Animal, Undead, etc.) rather than a specific subtype that cards actually have. Cross-reference against `SUBTYPE_GROUPS` in `extended_mechanic_packs.gd`.

## Wrong trigger family — ongoing trigger instead of conditional summon
Card has a `triggered_abilities` entry with an ongoing family (e.g., `on_friendly_summon`) when the correct effect is a one-time conditional summon. The card fires repeatedly on every matching summon instead of once on entry with a board-state check.
Example: Shadowscale Partisan (was `on_friendly_summon` + `required_summon_keyword`, should be `summon` + `required_keyword_on_board`)
How to spot: User reports a card gaining stats every time they play a creature with a keyword, when the card text says "Summon: +X/+Y if you have another creature with [keyword]". Check if the trigger family is `summon` (one-time) vs `on_friendly_summon` (ongoing).

## Missing trigger family in FAMILY_SPECS
Card references a trigger family name in `triggered_abilities` that doesn't exist in `match_timing.gd` `FAMILY_SPECS`, so the trigger silently never fires because no events match the family.
Example: Frost Giant (`on_creature_healed` family was used before it was added to FAMILY_SPECS)
How to spot: User reports a reactive/ongoing trigger "doesn't do anything." Search for the card's `family` value in FAMILY_SPECS — if it's not there, the trigger can never match.

## Wrong effect target — creature stat buff instead of player heal
Card's triggered ability uses `modify_stats` on `"self"` when the rules text says "you gain" (player health), or vice versa. The effect fires but applies to the wrong entity.
Example: Frost Giant (was `modify_stats` on self, should be `heal` on controller player)
How to spot: User reports the card text doesn't match what happens in game. Compare the `op` and `target`/`target_player` in `triggered_abilities` against the `rules_text` to see if "you" vs creature name is matched correctly.

## Effect filter format mismatch — nested filter object vs flat keys
Card's triggered_abilities use a `"filter": {"card_type": "creature"}` nested object for effect parameters, but the engine (`_apply_effects` in `match_timing.gd`) reads flat keys like `required_card_type` and `required_subtype` directly from the effect dictionary. The nested format silently produces no filter, causing the effect to either apply unfiltered or find no candidates.
Example: Soul Tear (used `"filter": {"card_type": "creature"}` instead of `"required_card_type": "creature"`)
How to spot: User reports a draw/filter effect applying to wrong card types or not working. Check if the card's effect uses a `"filter"` sub-object vs the flat `"required_card_type"` / `"required_subtype"` keys that the engine actually reads.

## Unimplemented trigger condition — field on descriptor but not checked in engine
A trigger descriptor includes a condition field (e.g. `required_played_rules_tag`) that is never checked in `_matches_trigger_role` or `_matches_conditions`, so the trigger fires unconditionally regardless of the filter. The event also lacked the data needed to perform the check (`rules_tags` was not included in `EVENT_CARD_PLAYED` events).
Example: Innkeeper Delphine, Ulfric Stormcloak, Young Dragonborn (`required_played_rules_tag: "shout"` was ignored — all actions triggered the effect)
How to spot: User reports a reactive trigger firing in response to the wrong event (e.g., any action instead of only Shouts). Check if the condition key from the descriptor is actually evaluated in `_matches_trigger_role` in `match_timing.gd`, and if the event contains the data needed for the check.

## Trigger role mismatch on event field names
The `_matches_trigger_role` function checks `event.get("player_id")` / `event.get("playing_player_id")` for the "controller" and "opponent_player" roles, but some event types (e.g. `creature_destroyed`) use `controller_player_id` instead. This causes triggers with those match roles to silently never fire for those event types.
Example: Stormcloak Camp, Necromancer's Amulet, Grim Champion, General Tullius (all `on_friendly_death` family)
How to spot: User reports an ongoing/reactive trigger "doesn't do anything." Check if the event emitted for that trigger family includes `player_id` — if it only has `controller_player_id`, the role match will fail silently.
