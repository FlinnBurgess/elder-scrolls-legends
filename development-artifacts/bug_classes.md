# Bug Classes

## Cross-lane attack status missing from AI enumeration
Cards with `attack_any_lane` or `move_to_attack_any_lane` status could pass validation in the UI but the AI could never enumerate cross-lane attack targets. Also, `move_to_attack_any_lane` cards (e.g., "May move to attack creatures in the other lane") need pre-attack lane movement so move triggers fire before combat. Guard checking must use the defender's lane, not the attacker's.
Example: Serpentine Stalker, Blood Dragon, Dead Drop, Bushwhack
How to spot: Card text mentions attacking creatures in other/any lane, but AI never uses cross-lane attacks; or card says "move to attack" but creature doesn't move before attacking.

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
Card's triggered_abilities use a `"filter": {"card_type": "creature"}` nested object for effect parameters, but the `draw_filtered` engine op originally read only flat keys like `required_card_type` and `required_subtype` directly from the effect dictionary. Fixed by updating `draw_filtered` in `_apply_effects` to fall back to the `filter` dict for `card_type`, `subtype`, `rules_tag`, `max_cost`, `name`, and `cost_equals_source_power`. Also added `post_draw_modify` support for stat buffs on drawn cards. The `filter` dict is also used by the synergy extractor for alt-views, so both formats now work.
Example: Daedric Incursion, Ulfric Stormcloak, Covenant Oathman, Forerunner of the Pact, Great Sigil Stone, Apex Wolf, Skyshard
How to spot: User reports a draw/filter effect applying to wrong card types or not working. Both `"filter": {"subtype": "X"}` and flat `"required_subtype": "X"` now work on `draw_filtered`.

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

## Wrong match_role on self-referencing trigger family
Card's trigger family uses `match_role: "any_player"` or `"controller"` when the card text says "When [this card] gains/does X" — meaning the trigger should only fire when the event targets the trigger's own card. With `"any_player"`, every copy of the card in play triggers whenever ANY creature has the event happen. Fix by using `match_role: "target"` so the trigger only fires when the event's target matches the trigger's source card. Additionally, the event emission should be gated on actual state change (e.g., only emit `keyword_granted` if the keyword was not already present).
Example: Dremora Adept, Manic Jack, Nereid Sister (`on_keyword_gained` family had `match_role: "any_player"` — all copies triggered on any keyword grant)
How to spot: User reports a self-referencing trigger ("When X gains/does...") firing for other cards or multiple times across copies. Check if the family spec's `match_role` is `"target"` and if the event is only emitted when the underlying state actually changes.

## Activate support with target_mode skipped — four-layer failure
Support cards with `target_mode` on their `activate` trigger use `"target": "chosen_target"` in effects, but four systems blocked them: (1) `_append_card_triggers` unconditionally skipped all triggers with `target_mode` from the registry — so the trigger was never even considered during event processing, (2) UI's `_selected_support_uses_card_targets` didn't enter targeting mode, (3) engine's `_trigger_matches_event` skipped triggers with `target_mode` when `_chosen_target_id` was empty, (4) AI's `_collect_target_requirements` didn't expand card targets. Fix: exempt `activate` and `on_play` families from the registry skip, inject `_chosen_target_id` from the event, and update UI/enumerator to recognize `target_mode`.
Example: Elixir of Potency, Skyforge, Orsinium Forge, Reconstruction Engine, Altar of Despair
How to spot: User reports clicking a support does nothing (charge spent but no effect). Check if the support's activate trigger has `target_mode` — if so, the card uses the `chosen_target` path, which requires all four layers to handle correctly.

## Multi-summon op delegated to single-summon helper
Card's effect requires summoning multiple creatures in a loop (e.g., "summon random Daedra with total cost 10") but the op handler delegates to `summon_random_from_catalog` which only summons one creature. The handler needs its own loop that tracks a budget, checks lane capacity, and picks creatures until the budget is exhausted or lanes are full.
Example: Forces of Destruction (`summon_random_daedra_total_cost` summoned only one Daedra instead of filling up to cost 10)
How to spot: User reports a "summon X with total cost Y" or "fill a lane with..." effect only producing one creature. Check if the op handler delegates to a single-summon helper without looping.

## Unhandled amount_source value in _resolve_amount
Card's effect uses `amount_source` with a value that `_resolve_amount()` in `match_timing.gd` doesn't handle. The function falls through to the default `int(effect.get("amount", 0))`, which returns 0 since no static `amount` field is set. The effect fires but deals/heals/modifies by 0.
Example: Blast from Oblivion (`amount_source: "oblivion_gate_level"` was not handled — always dealt 0 damage)
How to spot: User reports a damage/heal/stat effect "does nothing" or always applies 0. Check if the card's effect has `amount_source` and whether that value is handled in `_resolve_amount` in `match_timing.gd`.

## Self-referencing definition_id causes unwanted ability inheritance on copies
Card's `summon_from_effect` `card_template` uses the same `definition_id` as the original card but omits `triggered_abilities`. `build_generated_card` detects the missing field, looks up the catalog by `definition_id`, and copies the original card's `triggered_abilities` onto the generated copy. The copy then fires the same summon/last_gasp/etc. trigger, causing infinite chaining. Fix by adding `"triggered_abilities": []` to the `card_template` to prevent the catalog lookup.
Example: Ayleid Guardian (summon chained left-right-left-right filling all lanes), Golden Saint, Umaril the Unfeathered, Kagouti Fabricant
How to spot: User reports a "Summon: Summon a copy in the other lane" effect chaining infinitely or filling both lanes. Check if the card's `card_template` has the same `definition_id` as the parent card and lacks `"triggered_abilities": []`.

## Attack state persists through death and replay
`has_attacked_this_turn` was not reset when a creature entered a lane. If a Charge creature attacked, died, was shuffled back to deck (e.g., Journey to Sovngarde), drawn, and replayed in the same turn, the flag remained `true` and the attack validation blocked it. Fixed by resetting `has_attacked_this_turn = false` in `_apply_lane_entry` alongside `entered_lane_on_turn`, guarded by the same `preserve_entered_lane_on_turn` check so lane-to-lane moves don't reset it.
Example: Nord Firebrand, Rampaging Minotaur (any Charge creature replayed same turn)
How to spot: User reports a Charge creature unable to attack after being replayed in the same turn via graveyard recycling (Journey to Sovngarde, Soul Tear, etc.). The creature entered the lane correctly but shows as "WAITING" despite having Charge.

## Board passive modifying keyword resolution not implemented
Card has a `triggered_abilities` entry with a custom family name (e.g., `on_rally_empty_hand`, `on_rally`) that acts as a marker for keyword resolution code in the engine (e.g., `match_combat.gd` Rally flow), but the engine code that reads and acts on the marker was never written. The card data is correct but inert.
Example: Bolvyn Venim (`on_rally_empty_hand` — draw self from deck when Rally fires with empty hand)
How to spot: User reports a board creature's passive interaction with a keyword (Rally, Pilfer, etc.) not working. Check if the card's `triggered_abilities` family is a custom name not in `FAMILY_SPECS` — if it's meant to modify keyword resolution rather than fire as a standard trigger, the keyword resolution code must explicitly scan for it.

## Missing passive_abilities for ongoing keyword grant to card type
Card has rules text like "Your actions have Breakthrough" but no `passive_abilities` entry and no engine support. The `grant_keyword_to_type` passive grants `aura_keywords` to matching card types in hand, and the relevant engine op (e.g., `deal_damage`) must check for the keyword on the source card and apply the behavior (e.g., Breakthrough overflow damage to opponent).
Example: Ancano ("Your actions have Breakthrough")
How to spot: User reports an ongoing "Your [card_type] have [keyword]" effect not working. Check if the card has a `passive_abilities` entry with `type: "grant_keyword_to_type"`, and whether the engine op that handles the keyword actually checks for it on the source card.

## Unresolved "chosen" lane literal in summon ops
Effect uses `"lane": "chosen"` to indicate the player picks the lane, but the op handler (`summon_from_effect`, `fill_lane_with`, `summon_copies_to_lane`) treated `"chosen"` as a literal lane ID instead of resolving it to the actual lane from the event's `lane_id`. The lane resolution chain (`effect.lane_id` → `effect.target_lane_id` → `effect.lane` → `event.lane_id`) stops at `effect.lane` = `"chosen"` and never falls through to the event. The summon silently fails because no lane with ID `"chosen"` exists.
Example: Call of Valor, Wolf Cage, A Land Divided, Crassius' Favor, Rising of Bones, Strategist's Map, Corsair Ship, The Night Mother, Reconstruction Engine
How to spot: User reports a "Summon a creature in a lane" or "Fill a lane" effect doing nothing. Check if the card's effect uses `"lane": "chosen"` — this value must be resolved to `event.lane_id` or `trigger._chosen_lane_id` at runtime.

## Targeted exalt skipped by trigger_exalt_all_friendly
Temple Patriarch's `trigger_exalt_all_friendly` op directly calls `_apply_effects` for each friendly creature's exalt ability. For exalt abilities with `target_mode` (e.g., "Exalt: Deal 2 damage to a creature"), the effect uses `target: "chosen_target"` but no `_chosen_target_id` is set on the trigger, so target resolution returns empty and the effect silently does nothing. Fix by checking for `target_mode` and queuing a `pending_summon_effect_targets` entry instead of direct effect application.
Example: Ghostgate Defender (Exalt 3: Deal 2 damage to a creature — targeted exalt was skipped)
How to spot: User reports Temple Patriarch not triggering a creature's exalt effect. Check if the exalt ability has `target_mode` — if so, it needs the pending target selection path.

## Dict-format grants_immunity not consumed by aura recalculation
Card has `grants_immunity` as a dict (with `scope`, `condition`, `immunity` fields) to grant conditional immunity to other creatures, but the engine only consumed the array format (used by `_is_immune_to_effect` for silence/shackle immunity). The dict data flows through `_build_card`, `_hydrate_card`, and lands on the card state, but no code in `recalculate_auras` scanned for it. Fix by adding a Step 3f in `recalculate_auras` that scans for dict-format `grants_immunity` sources and sets `aura_damage_immune` on qualifying targets, checked in `apply_damage_to_creature`.
Example: Almalexia (`grants_immunity: {"scope": "all_friendly", "condition": "exalted", "immunity": "damage"}` — exalted friendlies should be immune to damage)
How to spot: User reports a card's "Friendly [condition] creatures are immune to [X]" not working. Check if `grants_immunity` is a dict and whether `recalculate_auras` handles that format.

## Missing effect source on item on_play trigger
Effect ops that read from a `source` field (e.g., `copy_keywords_to_friendly`) default to `"self"` when no source is specified. For items, `"self"` resolves to the item card, not the equipped creature. If the effect should read state from the equipped creature (e.g., copying its keywords), the effect must specify `"source": "event_target"` — otherwise the source card has no relevant state and the effect silently does nothing.
Example: Mentor's Ring
How to spot: User reports an item's on-play effect doing nothing despite the trigger firing. Check if the effect uses an op that reads from a source card (e.g., `copy_keywords_to_friendly`) and whether `"source"` is specified in the effect dict. If missing, it defaults to the item card instead of the equipped creature.

## Wrong damage trigger family — aura-like instead of source-specific
Card uses `on_enemy_damaged` (fires when ANY enemy creature takes damage from any source) when it should use `on_deal_damage_to_creature` (fires only when THIS card deals damage to a creature, via `match_role: "source"`). The effect triggers on all enemy damage events instead of only damage dealt by the card itself.
Example: Deepwood Trapper ("Shackle creatures damaged by Deepwood Trapper" was using `on_enemy_damaged` — shackled on any damage, not just its own)
How to spot: User reports a "Shackle/effect creatures damaged by [card name]" triggering from other damage sources. Check if the trigger family is `on_enemy_damaged` (any enemy damage) vs `on_deal_damage_to_creature` (only this card's damage). Also check the target: `on_deal_damage_to_creature` uses `"damaged_creature"`, not `"event_damaged_creature"`.

## Unresolved "same"/"other" lane sentinel in fill/copy summon ops
The `fill_lane_with` and `summon_copies_to_lane` ops resolve lanes via a fallback chain (`effect.lane_id` → `effect.target_lane_id` → `effect.lane` → `event.lane_id`) but only handled the `"chosen"` and `"both"` sentinel values. The `"same"` and `"other"`/`"other_lane"` sentinels (already handled by `summon_from_effect`) passed through as literal lane IDs and silently failed because no lane has those IDs. Fixed by adding resolution branches in both op handlers.
Example: Prized Chicken, Vastarie, Prophet of Bones (`"lane": "same"` on `fill_lane_with`)
How to spot: User reports a "Fill this lane" effect doing nothing. Check if the card's effect uses `"lane": "same"` or `"lane": "other"` with `fill_lane_with` or `summon_copies_to_lane`.

## Missing triggered_abilities with cross-zone card type condition
Card has rules text with a conditional summon effect that checks for card types across multiple zones (discard pile, supports in play, items equipped on creatures) but has no `triggered_abilities` array and may also have the conditional keyword incorrectly listed as a base keyword. The card sits inert because there is no trigger descriptor to fire the effect.
Example: Voice of Balance ("Summon: +4/+4 and Guard if you have an action, item, and support in your discard pile or in play" — had `keywords: ["guard"]` as base keyword and no `triggered_abilities`)
How to spot: User reports a conditional summon buff not triggering. Check if the card's `rules_text` mentions checking for card types "in your discard pile or in play" and whether it has `triggered_abilities` with the `required_card_types_in_discard_or_play` condition. Also check if conditional keywords are incorrectly listed in the base `keywords` array.

## Item missing last_gasp via item_detached trigger
Item has "Last Gasp" in its rules text but uses a `last_gasp` or `on_death` trigger family, which checks `match_role: "subject"` against the dying creature's instance_id — not the item's. Since items are a separate entity attached to the creature, their instance_id never matches the event subject. Fix by using `FAMILY_ITEM_DETACHED` (`"family": "item_detached"`) which fires on the `attached_item_detached` event with `match_role: "source"` (matching the item's instance_id). Add `"required_detach_reason": "host_left_play"` to only fire on creature death (not silence/transform). Existing example: Heirloom Greatsword correctly uses `item_detached`.
Example: Stolen Pants ("Last Gasp: Give Sheepish Dunmer his pants" — was missing the trigger entirely)
How to spot: User reports an item's Last Gasp effect never firing. Check if the item uses `last_gasp` family (won't match) or is missing the trigger altogether. Items should use `item_detached` family.

## Lane-targeting action_target_mode enters creature targeting mode
`_action_needs_explicit_target` returns `true` for any non-empty `action_target_mode`, including lane-based modes like `choose_lane`. This sends the card into creature targeting (arrow) mode, but the `_on_lane_pressed` handler blocks lane plays when `_action_needs_explicit_target` is true. The card gets stuck — can't target a creature (wrong mode) and can't target a lane (blocked). Fix by excluding `choose_lane` from `_action_needs_explicit_target` so the card uses the detach-to-lane flow.
Example: Trial of Flame (`action_target_mode: "choose_lane"`)
How to spot: User reports a "Choose a lane" action entering creature targeting mode or being unplayable. Check if the card's `action_target_mode` is a lane-based mode that `_action_needs_explicit_target` doesn't exclude.

## Steal fails silently when same lane is full
`steal_card` in `match_mutations.gd` only attempted to place the stolen creature in the same lane it was already in (under the new controller). If the stealer's side of that lane was full, `move_card_between_lanes` returned invalid and the steal silently did nothing — it never tried alternate lanes. Fix by falling back to other lanes when the same lane is full, and only failing if all lanes are full.
Example: Euraxia Tharn (steal with full same-lane)
How to spot: User reports stealing a creature "does nothing" when the stealer's side of that lane is full but the other lane has space. The steal op fires (log shows it) but the creature doesn't move.

## Innate status stored as bare field instead of innate_statuses array
Card has a status-like field (e.g., `"permanent_shackle": true`) as a bare key on the seed dictionary, but the engine reads `innate_statuses` (an array of status IDs) to apply statuses at lane entry via `_apply_innate_statuses`. The bare field is ignored and the status is never applied.
Example: Vigilant Ancestor (`"permanent_shackle": true` instead of `"innate_statuses": ["permanent_shackle"]`)
How to spot: User reports a creature missing an innate status (shackle, ignore guard, etc.). Check if the card uses a bare field instead of the `innate_statuses` array.

## Completely wrong effect implementation — card data doesn't match rules text
Card's `triggered_abilities` and `rules_text` describe a completely different effect than the actual card should have — not a missing field or wrong parameter, but a fundamentally different mechanic. This happens when card data is initially authored from an incorrect source or guess rather than verified against the wiki/reference.
Example: A Land Divided (was "Summon 4 specific creatures into a lane", should be "Fill left lane with Stormcloak Skirmishers or right lane with Colovian Troopers" — a lane-conditional fill effect)
How to spot: User reports the card does something entirely different from what it should. Compare the card's `rules_text` and `triggered_abilities` against the wiki/reference data. The fix involves rewriting both `rules_text` and `triggered_abilities` from scratch.

## "Another" random target includes self
Card rules text says "another random friendly creature" but the effect uses `target: "random_friendly"` which includes self. Should use `target: "random_other_friendly"` to exclude the source card.
Example: Reachman Shaman, Blackrose Herbalist
How to spot: User reports a creature buffing/healing itself when it's the only friendly creature on board, or the word "another" appears in `rules_text` but the target is `random_friendly` instead of `random_other_friendly`.

## Effect targets wrong zone — board creatures instead of hand cards
Card effect uses a board-targeting op (e.g., `copy_keywords_to_friendly` with `target: "all_friendly"`) when the rules text specifies a hand card target (e.g., "a random Dragon in your hand"). The effect fires but operates on the wrong zone, producing incorrect gameplay.
Example: Devour (was copying keywords to all friendly Dragons on board, should copy to a random Dragon in hand)
How to spot: Rules text mentions "in your hand" but the effect's `target` resolves to board creatures (`all_friendly`, `random_friendly`, etc.). Search for `in your hand` in `rules_text` and verify the effect targets hand cards.

## Action card with item data fields instead of triggered abilities
Card is typed as `"action"` but has item-specific fields (`equip_health_bonus`, `equip_power_bonus`, `equip_keywords`, `rules_text: "+X/+Y"`) and no `triggered_abilities`. The card was likely templated from an item definition. The equip fields do nothing on an action; the card has no gameplay effect when played.
Example: Counterfeit Trinket (had `equip_health_bonus: 1` and `rules_text: "+0/+1"` instead of draw + self-damage)
How to spot: Search for `"action".*equip_health_bonus` or `"action".*equip_power_bonus` in card_catalog.gd. Also check non-collectible action tokens with suspiciously item-like rules_text (e.g., "+X/+Y" with no other text).

## Effect op hardcoded to same-lane when card text implies all lanes
An effect op (e.g., `battle_strongest_enemy`) iterates only the attacker's lane to find targets, but the card text says "your opponent's most powerful creature" (no lane restriction). The effect fires but picks from a subset of candidates, missing stronger creatures in other lanes.
Example: Duel Atop the World (battled strongest enemy in same lane instead of across all lanes)
How to spot: Rules text references "opponent's most powerful creature" or similar board-wide superlative without mentioning "in its lane" or "in this lane". Check the op handler to see if it restricts iteration to a single lane index.

## Wrong token in card_template
A summon effect's `card_template` references the wrong token creature (wrong `definition_id`, name, and/or stats). The effect fires correctly but summons the wrong card. Often caused by using a similar-but-different token (e.g., Colovian Trooper instead of Kvatch Soldier).
Example: Jarl Balgruuf (summoned Colovian Trooper 2/2 Guard instead of Kvatch Soldier 2/3 Guard)
How to spot: Compare the card's `rules_text` token names against the `card_template` entries in `triggered_abilities`. Also compare token stats (power/health/keywords) against the actual token seed in the catalog.

## Win condition too lenient
A `check_win_condition` effect uses a condition that is easier to meet than what the card text describes (e.g., "any friendly creature in each lane" vs "lanes are full"). The win triggers prematurely.
Example: Jarl Balgruuf (triggered on "both lanes have a friendly creature" instead of "your lanes are full")
How to spot: Compare the card's `rules_text` win condition wording against the `condition` value in the `check_win_condition` effect and its engine handler logic.

## Missing art_path on inline card_template in summon effects
Card's `summon_from_effect` or `fill_lane_with` uses an inline `card_template` that omits `art_path`. `build_generated_card` falls back to `"res://assets/images/cards/" + definition_id + ".png"` which may not exist (e.g., `aw_neu_recruit.png` doesn't exist — the actual art files are race-specific like `recruit_high_elf.png`). The summoned token displays fallback/missing art.
Example: Ayrenn's Chosen (summoned Recruits with no `art_path`, fell back to non-existent `aw_neu_recruit.png`), Battle of Chalman Keep
How to spot: User reports summoned tokens showing placeholder/fallback art. Check if the inline `card_template` has an `art_path` field. Compare against other cards that summon the same token to see the correct art path.
