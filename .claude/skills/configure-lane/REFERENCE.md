# Configure Lane — Reference

## Trigger Families (from MatchTiming.FAMILY_SPECS)

| Family | Event | Default match_role | Notes |
|--------|-------|--------------------|-------|
| `start_of_turn` | `turn_started` | `controller` | Fires at start of active player's turn |
| `end_of_turn` | `turn_ending` | `controller` | Fires at end of active player's turn |
| `on_friendly_summon` | `creature_summoned` | `controller` | Excludes self |
| `summon` | `creature_summoned` | `source` | The summoned creature itself |
| `on_enemy_summon` | `creature_summoned` | `opponent_player` | |
| `on_move` | `card_moved` | `controller` | |
| `on_damage` | `damage_resolved` | `either` | Source or target |
| `on_attack` | `damage_resolved` | `source` | Combat damage, excludes retaliation |
| `last_gasp` | `creature_destroyed` | `subject` | |
| `on_friendly_death` | `creature_destroyed` | `controller` | |
| `slay` | `creature_destroyed` | `killer` | |
| `pilfer` | `damage_resolved` | `source` | Player target, min 1 damage |
| `rune_break` | `rune_broken` | `controller` | Interrupt window |
| `on_enemy_rune_destroyed` | `rune_broken` | `opponent_player` | |
| `after_action_played` | `card_played` | `controller` | Action cards only |
| `on_equip` | `card_equipped` | `target` | |
| `on_ward_broken` | `ward_removed` | `target` | |
| `on_player_healed` | `player_healed` | `target_player_is_controller` | |
| `on_creature_healed` | `creature_healed` | `any_player` | |
| `on_card_drawn` | `card_drawn` | `controller` | |
| `on_cover_gained` | `status_granted` | `target` | cover status only |
| `on_max_magicka_gained` | `max_magicka_gained` | `target_player_is_controller` | |

## Match Roles

| Role | Matches when... |
|------|-----------------|
| `controller` | Event's player_id == trigger's controller_player_id |
| `opponent_player` | Event's player_id != trigger's controller_player_id |
| `source` | Event's source_instance_id == trigger's source_instance_id |
| `target` | Event's target matches trigger's source |
| `any_player` | Always matches |
| `either` | Source or target matches |
| `friendly_target` | Target is controlled by trigger's controller |
| `opponent_target` | Target is NOT controlled by trigger's controller |

**Lane trigger note:** Lane triggers have `controller_player_id: ""` and `owner_player_id: ""`. For families with default `match_role: "controller"`, this means the trigger won't match because `""` never equals any player id. Override with `"match_role": "any_player"` in the lane effect descriptor, then check the active player inside the op handler.

## Key Files

| File | Purpose |
|------|---------|
| `data/legends/registries/lane_registry.json` | Lane type definitions and board profiles |
| `src/core/match/lane_effect_rules.gd` | Lane effect op dispatch and handlers |
| `src/core/match/match_timing.gd` | Trigger matching, event publishing, `FAMILY_SPECS` |
| `src/core/match/match_bootstrap.gd` | `_build_lane_rule_payload()` propagates effects to match state |
| `src/core/match/evergreen_rules.gd` | `get_power()`, `get_remaining_health()`, keyword/status helpers |
| `src/core/match/extended_mechanic_packs.gd` | `apply_custom_effect()` for general-purpose ops |
| `src/core/match/match_mutations.gd` | State mutation helpers |
| `src/core/match/match_turn_loop.gd` | `_start_turn()`, `end_turn()` |
| `data/test_match_config.gd` | `_build_lane_rule_payload()` for test match configs |
| `tests/lane_rules_runner.gd` | Lane-specific tests |
| `assets/images/lanes/` | Lane icon PNGs |

## Existing Lane Ops

| Op | Lane | Behavior |
|----|------|----------|
| `lane_grant_cover` | Shadow | Grants Cover to creatures entering the lane (unless Guard) |
| `lane_dementia_damage` | Dementia | Start of turn: highest-power creature's owner deals 3 to opponent |

## Common Effect Ops (reusable from match_timing / extended_mechanic_packs)

| Op | What it does | Key params |
|----|-------------|------------|
| `modify_stats` | +power/+health | `target`, `power`, `health` |
| `deal_damage` | Damage creatures | `target`, `amount` |
| `damage` | Damage player | `target_player`, `amount` |
| `draw_cards` | Draw cards | `target_player`, `count` |
| `grant_keyword` | Add keyword | `target`, `keyword` |
| `grant_status` | Add status marker | `target`, `status` |
| `heal` | Heal player | `target_player`, `amount` |
| `shackle` | Shackle creature | `target` |
| `silence` | Silence creature | `target` |
| `summon_from_effect` | Summon a token | `card_template`, `lane_id` |
| `generate_card_to_hand` | Add card to hand | `card_template`, `target_player` |
