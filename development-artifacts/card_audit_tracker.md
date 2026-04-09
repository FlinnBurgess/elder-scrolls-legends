# Card Audit Tracker

Generated from `tests/card_definition_auditor.gd` run on 2026-04-09.
Re-run auditor: `Godot --log-file $TMPDIR/godot.log --headless --path . --script tests/card_definition_auditor.gd`

**Summary**: 1323 cards scanned, **0 errors, 0 warnings** (clean audit)

---

## Resolved — Card Definition Fixes

### W2.1. `move_between_lanes` missing `lane_id` (9 cards) — FIXED

Added `"lane_id": "other_lane"` to each effect.

| Card | ID | Status |
|------|-------|--------|
| Monk's Strike | `hos_dual_monks_strike` | FIXED |
| Cliff Strider | `hom_agi_cliff_strider` | FIXED |
| Shadowscale Hunter | `aw_agi_shadowscale_hunter` | FIXED |
| Wild Boar | `joo_agi_wild_boar` | FIXED |
| Grand Ball | `db_agi_grand_ball` | FIXED |
| Grappling Hook | `cwc_str_grappling_hook` | FIXED |
| Mad Dash | `iom_agi_mad_dash` | FIXED |
| Duneripper | `mc_dual_duneripper` | FIXED |
| Dark Mane | `mc_dual_dark_mane` | FIXED |

### E1.7. Midnight Burial — FIXED

Added `player_choice: true` to `copy_creature_from_deck_to_discard` effect.
Added `copy_creature_to_discard` then_op to `resolve_pending_deck_selection` in match_timing.gd.
Engine change: `copy_creature_from_deck_to_discard` now supports `player_choice: true` for deck selection UI.

---

## Resolved — Engine Fixes

### Rally event publishing — FIXED

Added `rally_triggered` event to `match_combat.gd` after rally resolution.
Fixes: Skar Drillmaster, Seasoned Captain, Bolvyn Venim (3 cards).

### Action targeted event publishing — FIXED

Added `action_targeted` event to `play_action_from_hand` in `match_timing.gd`.
Fixes: Gnarl Rootbender (1 card).

---

## Resolved — Auditor False Positives (no card/engine changes needed)

### E1. Choose Without Mechanism (6 of 7 were false positives)

Auditor wasn't checking `action_target_mode` on card, `target_mode` on effects, `summon_from_deck_filtered` (always uses pending_deck_selections), or `force_play: true`.

| Card | ID | Reason |
|------|-------|--------|
| Writ of Execution | `hom_wil_writ_of_execution` | Has `action_target_mode` + `delayed_destroy` |
| Halls of Colossus | `moe_wil_halls_of_colossus` | `summon_from_deck_filtered` uses pending_deck_selections |
| Worldly Wanderer | `joo_wil_worldly_wanderer` | Same as above |
| Trial of Flame | `cwc_str_trial_of_flame` | Has `action_target_mode: "choose_lane"` |
| Abandoned Imperfect | `cwc_neu_abandoned_imperfect` | `force_play: true` → player picks lane |
| Piercing Twilight | `fsc_int_piercing_twilight` | Has `target_mode` on effect op |

### E2-E3. Missing Slay/Pilfer (6 cards — all false positives)

Auditor wasn't checking `grants_trigger` arrays or grant ops (`grant_slay_draw`, `grant_pilfer_draw`, `grant_slay_ability`).

| Card | ID | Mechanism |
|------|-------|-----------|
| Crusader's Assault | `hos_dual_crusaders_assault` | `grant_slay_draw` op |
| Naryu Virian | `hom_agi_naryu_virian` | `grants_trigger` with slay |
| Dead Drop | `joo_agi_dead_drop` | `grant_slay_ability` op |
| Astrid | `db_agi_astrid` | `grants_trigger` with slay |
| Thieves' Den | `agi_thieves_den` | `grants_trigger` with pilfer |
| Bandit Ringleader | `hos_wil_bandit_ringleader` | `grant_pilfer_draw` op |

### E4. Missing Last Gasp (2 items — false positives)

Items use `item_detached` family for Last Gasp (fires on creature death).

| Card | ID |
|------|-------|
| Heirloom Greatsword | `int_heirloom_greatsword` |
| Stolen Pants | `hom_neu_stolen_pants` |

### E5. Missing Turn Triggers (3 cards — false positives)

| Card | ID | Mechanism |
|------|-------|-----------|
| Illusory Defenses | `hom_wil_illusory_defenses` | Token has own `start_of_turn` trigger |
| Writ of Execution | `hom_wil_writ_of_execution` | `delayed_destroy` with `trigger_at: start_of_turn` |
| Fleeting Apparition | `hom_agi_fleeting_apparition` | `unsummon_end_of_turn` scheduling op |

### E6. Missing Wax/Wane (1 card — false positive)

| Card | ID | Mechanism |
|------|-------|-----------|
| Lunar Sway | `moe_neu_lunar_sway` | Effect-level `required_wax_wane_phase` |

### E7. Missing Summon (1 card — false positive)

| Card | ID | Reason |
|------|-------|--------|
| Baandari Opportunist | `aw_agi_baandari_opportunist` | "Summon:" in text refers to shuffled copy's ability |

### W1. Unimplemented Families (33 cards — all now recognized)

All 28 families had FAMILY_SPECS entries and event publishing. Moved to RECOGNIZED_FAMILIES.

### W2.2-W2.3. Missing card_template (4 cards — false positives)

Cards use context-based sources instead of static `card_template`.

| Card | ID | Source |
|------|-------|--------|
| Night Talon Lord | `end_night_talon_lord` | `source_target: "event_subject"` |
| Mages Guild Conjurer | `aw_int_mages_guild_conjurer` | `upgrade_chain` |
| Conjuration Tutor | `mc_int_conjuration_tutor` | `copy_of: "event_summoned_creature"` |
| Murkwater Guide | `cwc_agi_murkwater_guide` | `target: "treasure_card_copy"` |

### W3. Keyword Not in Array (2 cards — false positives)

| Card | ID | Reason |
|------|-------|--------|
| Arenthia Guerrilla | `joo_agi_arenthia_guerrilla` | Conditional Lethal ("on opponent's turn") |
| Throne Aligned | `cwc_int_throne_aligned` | Item grants Guard to wielder, not innate |

---

## Auditor Improvements Made

1. Moved 29 families from `UNIMPLEMENTED_FAMILIES` to `RECOGNIZED_FAMILIES` (all had FAMILY_SPECS + events)
2. `choose_without_mechanism` now checks `action_target_mode`, effect-level `target_mode`, `summon_from_deck_filtered`, `force_play`, and `player_choice` on ops
3. `missing_slay/pilfer_trigger` now checks `grants_trigger` and grant ops
4. `missing_last_gasp_trigger` now excludes items with `item_detached` family
5. `missing_start/end_of_turn_trigger` now checks scheduling ops and token-level triggers
6. `missing_wax/wane_trigger` now checks effect-level `required_wax_wane_phase`
7. `missing_summon_trigger` only flags line-starting "Summon:" (not quoted references)
8. `REQUIRED_PARAMS` for `summon_from_effect` now accepts `source_target`, `upgrade_chain`, `copy_of`
9. `REQUIRED_PARAMS` for `generate_card_to_hand` now accepts `target` fallback
10. `keyword_not_in_array` excludes items and conditional keywords
