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

## Missing duration on "this turn" grant_keyword effects
The `grant_keyword` effect op grants keywords permanently by default. Cards with "this turn" in their rules text need `"duration": "end_of_turn"` on their effect descriptor to make the keyword temporary, otherwise it persists indefinitely. The engine tracks temporary keywords via `temporary_keywords` on the card and clears them at end of turn.
Example: Snake Tooth Necklace, Pillaging Tribune, Auridon Paladin, Ageless Automaton, Crusader's Assault, Monk's Strike
How to spot: User reports a keyword not wearing off at end of turn. Search for cards whose `rules_text` contains "this turn" alongside a `grant_keyword` op that lacks a `"duration"` field.

## Unimplemented effect operation
Card has a `triggered_abilities` entry with an `op` value that doesn't exist in `match_timing._apply_effects()`. The effect silently does nothing because unknown ops fall through the match statement. This typically happens when new cards are batch-imported with placeholder ops that haven't been implemented in the engine yet.
Example: Winterhold Illusionist (`banish_and_return_end_of_turn`), Dres Spy (`look_at_top_deck_may_discard`), Barilzar's Tinkering (`transform_random_by_cost`), Mages Guild Recruit (`modify_card_cost` via unimplemented `action_in_hand` target_mode)
How to spot: User reports a card "doesn't do anything" despite having rules text and triggered abilities. Grep the op name from the card's triggered_abilities against `match_timing.gd` and `extended_mechanic_packs.gd` to see if it's handled. Also check if the card uses a `target_mode` that isn't recognized by `get_valid_targets_for_mode` — unrecognized modes cause the trigger to be skipped silently.

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

## Effect writes to non-existent player state field
An effect operation writes to a player state field name that doesn't exist (e.g., `"magicka"` instead of `"temporary_magicka"`). Because GDScript dictionaries silently create new keys on assignment, the value is stored but never read by the rest of the engine, so the effect appears to do nothing.
Example: Palace Prowler, Torval Crook, Brynjolf (`gain_magicka` op wrote to `player["magicka"]` instead of `player["temporary_magicka"]`)
How to spot: User reports a resource-gain effect (magicka, health, etc.) not working. Check if the field name written in the effect handler matches the field name read by the engine's getter/spending functions (e.g., `get_available_magicka` reads `current_magicka` + `temporary_magicka`).

## Missing triggered_abilities on creature with rules_text effect
Card has `rules_text` describing an active effect (e.g., ward-break, summon, slay) but no `triggered_abilities` array, so the effect never fires. The card may have `effect_ids` and `keywords` but these are display-only and don't cause effects to execute.
Example: Iliac Sorcerer (ward-break double power)
How to spot: User reports a card's special ability doesn't trigger. Check if the card in `card_catalog.gd` has `rules_text` describing an effect but lacks `triggered_abilities`.

## Strict health comparison excludes equal health on "Otherwise" branch
Card uses `required_more_health` for an "Otherwise" (not-less) branch, but that condition is strictly greater-than. When both players have equal health, neither the "less" nor "more" condition fires, so the card does nothing. Fix by using a `required_not_less_health` condition (>=) instead.
Example: Rift Thane
How to spot: User reports a card with "If you have less health... Otherwise..." doing nothing when health is equal. Check if the "Otherwise" branch uses `required_more_health` (strict) instead of `required_not_less_health` (inclusive).

## Missing trigger family in FAMILY_SPECS (on_friendly_summon)
Card references `on_friendly_summon` family but it didn't exist in `FAMILY_SPECS`, so the trigger silently never fires. Additionally, condition fields like `required_summon_subtype`, `required_summon_keyword`, `required_summon_min_power`, `required_summon_min_health`, `required_summon_min_cost` were not checked in `_matches_conditions`.
Example: Ancient Lookout, Blades Lookout, Ghost Sea Lookout, Cliffside Lookout, Woodland Lookout
How to spot: User reports a "When you summon a [subtype/keyword/stat condition]" trigger not firing. Check if the card's `family` value exists in FAMILY_SPECS and if condition fields like `required_summon_*` are handled in `_matches_conditions`.

## Missing relationship context on in-match card displays
Card display components for hand/lane/support cards in `_build_card_display_component` were not receiving relationship context, so alt-view synergy text showed "Synergy: X" instead of counts like "You have N Xs in play and hand." Only hover previews received context.
Example: Ancient Lookout (Dragon synergy count)
How to spot: User reports alt-view showing "Synergy: [subtype]" instead of a count. Check if `set_relationship_context` is called on the card display component.

## Inline card_template missing abilities from catalog token definition
When a card uses `summon_from_effect` or `summon_copies_to_lane` with an inline `card_template`, the generated card is built solely from that template — `build_generated_card` does not look up the catalog. If the inline template omits `triggered_abilities`, `rules_text`, or `effect_ids` that the corresponding non-collectible `_seed` entry has, the summoned token will be a plain stat-stick with no abilities.
Example: Slaughterfish Spawning (inline template for Slaughterfish token was missing `triggered_abilities` for +2/+0 per turn)
How to spot: User reports a summoned token having no special effects. Compare the inline `card_template` in the summoning card's effects against the standalone `_seed` entry for that `definition_id`.

## deal_damage player fallback missing event target_player_id
The `deal_damage` op in `_apply_effects()` falls back to player damage when no card targets are found, but only checks `trigger._chosen_target_player_id` (set by `resolve_targeted_effect` for creatures with `target_mode`). Action cards pass the player target via the event's `target_player_id` field instead, so the fallback silently does nothing. Fixed by also checking `event.target_player_id` when the trigger field is empty.
Example: Crushing Blow, Lightning Bolt, Ransack
How to spot: User reports an action card with "Deal X damage." (no creature restriction) does nothing when targeting face. Check if the card's `deal_damage` op uses `"target": "event_target"` without `action_target_mode` — these cards rely on the event fallback path.

## Missing alt-view for effect-level subtype filter
Card has a synergy with a subtype encoded in an effect-level `filter` (e.g. `{"op": "reduce_random_hand_card_cost", "filter": {"subtype": "Dragon"}}`), but `card_relationship_resolver.gd` only checked trigger-level condition fields (`required_subtype_on_board`, `required_event_source_subtype`, `required_summon_subtype`). The resolver didn't inspect `filter.subtype` inside the `effects` array, so no alt-view with subtype counts was generated.
Example: Midnight Snack (Dragon count), Barbas (Daedra count via choose_one), Ulfric Stormcloak (Nord count)
How to spot: User reports no alt-view showing subtype count. Check if the card's synergy is encoded in an effect's `filter` sub-object rather than a trigger-level condition field.

## Trigger role mismatch on event field names
The `_matches_trigger_role` function checks `event.get("player_id")` / `event.get("playing_player_id")` for the "controller" and "opponent_player" roles, but some event types use different field names: `creature_destroyed` uses `controller_player_id`, and `damage_resolved` uses `source_controller_player_id`. This causes triggers with those match roles to silently never fire for those event types.
Example: Stormcloak Camp, Necromancer's Amulet, Grim Champion, General Tullius (all `on_friendly_death` family); Helgen Squad Leader (`on_attack` family with `match_role: "controller"`)
How to spot: User reports an ongoing/reactive trigger "doesn't do anything." Check if the event emitted for that trigger family includes `player_id` — if it only has `controller_player_id` or `source_controller_player_id`, the role match will fail silently.

## Unimplemented action_target_mode
Card has an `action_target_mode` value that isn't handled in the UI's `_action_target_mode_allows`, the engine's `ExtendedMechanicPacks._card_matches_target_mode`, or the AI's target expansion in `match_action_enumerator.gd`. Unknown modes fall through to `return true`, allowing any target to be selected. The card appears to work but doesn't enforce its targeting restriction.
Example: Dismantle (`enemy_support_or_neutral_creature` was not handled — allowed targeting any enemy creature)
How to spot: User reports being able to target something the card text shouldn't allow. Check if the card's `action_target_mode` value appears in all three target validation match statements (UI, engine, AI enumerator).

## Missing mandatory flag on summon target_mode
Card has a `target_mode` on its summon trigger but lacks `"mandatory": true`. In TES:L, most "Summon: [verb] a creature" effects require a target when one exists. Without the flag, the AI enumerator generates a no-target "fizzle" variant alongside targeted variants, and the AI may choose the fizzle even when valid targets exist.
Example: Arenthia Swindler (`target_mode: "enemy_creature"` without `mandatory: true` — AI skipped stealing items)
How to spot: User reports an AI-played creature's summon effect "didn't work" despite valid targets on board. Check if the card's summon trigger has `"mandatory": true` — if not, the AI may have chosen the fizzle path.

## Missing relationship op for card alt-views
Card has an effect op (e.g., `transform`) that embeds a `card_template` for an alternate form, but the op name isn't in `RELATED_CARD_OPS` in `card_relationship_resolver.gd`. The alt-view cycling (UP/DOWN arrows) won't show the alternate form because the resolver doesn't recognize the op as relationship-producing.
Example: Whiterun Protector and all Beast Form cards (`transform` op with `card_template` wasn't in `RELATED_CARD_OPS`)
How to spot: User reports no alt-view for a card that clearly has an alternate form (Beast Form, transform effects). Check if the op name in the card's `triggered_abilities` effects is listed in `RELATED_CARD_OPS`.

## Wrong trigger family — per-event instead of end-of-turn conditional
Card uses a reactive trigger family (e.g., `on_friendly_death`) that fires on every matching event, when the correct behavior is an end-of-turn check that fires once if the condition was met during the turn. The card deals damage/effects multiple times per turn instead of once.
Example: Stormcloak Camp (was `on_friendly_death` — fired per death; should be `end_of_turn` with `creature_died_this_turn: true`)
How to spot: User reports a card triggering multiple times per turn when the text says "at the end of your turn, if..." or similar conditional phrasing. Check if the trigger family should be `end_of_turn` with a condition instead of a reactive family.

## Unhandled amount_source value in _resolve_amount
Card's effect uses `amount_source` with a value that `_resolve_amount()` in `match_timing.gd` doesn't handle. The function falls through to the default `int(effect.get("amount", 0))`, which returns 0 since no static `amount` field is set. The effect fires but deals/heals/modifies by 0.
Example: Blast from Oblivion (`amount_source: "oblivion_gate_level"` was not handled — always dealt 0 damage)
How to spot: User reports a damage/heal/stat effect "does nothing" or always applies 0. Check if the card's effect has `amount_source` and whether that value is handled in `_resolve_amount` in `match_timing.gd`.
