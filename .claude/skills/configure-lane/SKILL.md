---
name: configure-lane
description: Configure a new special lane type for Elder Scrolls Legends. Implements the lane effect in the registry, engine, and tests. Use when user wants to add, set up, configure, or implement a lane — e.g. "configure the mania lane", "set up armory lane", "implement the water lane effect". Takes a lane name as argument.
model: opus
effort: high
---

# Configure Lane

Implement a special lane type end-to-end: registry entry, engine effect handler, icon, and tests.

## Arguments

`$ARGUMENTS` — The lane name (e.g., "mania", "armory", "water").

## Step 1: Read Existing Registry Entry

Read `data/legends/registries/lane_registry.json` and find the lane by id. It likely exists as `implementation_bucket: "deferred_variant"` with a `description` field explaining the effect.

If the lane doesn't exist in the registry, ask the user for the effect description before proceeding.

## Step 2: Analyze the Effect

From the description, determine:

1. **Trigger family** — when does the effect fire? (See [REFERENCE.md](REFERENCE.md) for full list)
2. **Match role** — who can trigger it? Lane triggers have empty `controller_player_id`/`owner_player_id`, so use `"any_player"` for effects that check both sides, or `"controller"` if only the active player triggers it.
3. **Effect logic** — can an existing op handle this, or does it need a custom lane op?

### Deciding between existing ops vs custom lane ops

Check `src/core/match/lane_effect_rules.gd` for existing lane ops and `src/core/match/extended_mechanic_packs.gd` `apply_custom_effect()` for general ops.

- **Use existing ops** when the effect is simple and stateless (e.g., grant a keyword, modify stats)
- **Use a new custom lane op** when the effect needs lane-specific context (checking creatures in the lane, comparing between players, conditional logic based on lane state)

**Reusable generic ops already in lane_effect_rules.gd:**
- `lane_grant_keyword` — grants `effect.keyword` to summoned creature (used by renewal/siege/venom)
- `lane_stat_bonus` — applies `effect.power`/`effect.health` bonus to summoned/moved creature (used by killing_field/masquerade_ball)

### Non-trigger lane effects

Some lanes don't map to a trigger family:
- **Summon restrictions** (e.g., Sewer): Integrated into `match_mutations.gd::validate_lane_entry()` by checking `lane_rule_payload.effects` for restriction ops. Use a dummy family like `on_friendly_summon` in the registry; the actual logic is in validation.
- **Continuous cost reduction** (e.g., Library): Integrated into `persistent_card_rules.gd::get_effective_play_cost()` by scanning lane payloads. Use a dummy family in the registry.

### Trigger family names

Family names in `effects[].family` **must exactly match** the FAMILY_SPECS keys in `src/core/match/match_timing.gd`. Common ones for lanes:
- `on_friendly_summon`, `on_move`, `start_of_turn`, `end_of_turn`, `on_attack`
- `pilfer` (not `on_pilfer`), `on_damage` (not `on_creature_damaged`), `on_friendly_death` (not `on_creature_destroyed`)
- `after_action_played` (not `on_action_played`), `on_player_healed` (not `on_health_gained`)

## Step 3: Update lane_registry.json

Update the lane entry:
- Change `implementation_bucket` from `"deferred_variant"` to `"mvp"`
- Add `"icon": "res://assets/images/lanes/{lane_id}.png"`
- Add `"effects"` array with the trigger descriptor(s)

Also add a board profile under `"board_profiles"` for testing:
```json
{
  "id": "{lane_id}_test",
  "display_name": "{Display Name} Test",
  "lanes": [
    {"lane_id": "field", "slot_capacity": 4},
    {"lane_id": "shadow", "lane_type": "{lane_id}", "slot_capacity": 4}
  ],
  "source_ids": ["workspace_spec"]
}
```

Example (shadow lane — uses existing op):
```json
"effects": [
  {"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_grant_cover"}]},
  {"family": "on_move", "match_role": "any_player", "effects": [{"op": "lane_grant_cover"}]}
]
```

Example (dementia lane — uses custom lane op):
```json
"effects": [
  {"family": "start_of_turn", "match_role": "any_player", "effects": [{"op": "lane_dementia_damage", "amount": 3}]}
]
```

## Step 4: Implement Effect Handler (if custom op needed)

Edit `src/core/match/lane_effect_rules.gd`:

1. Add a new case to `apply_lane_effect()`. Use a descriptive op name (e.g., `lane_dementia_damage`, `lane_mania_draw`), not just `lane_{id}_effect`:
```gdscript
"lane_{id}_{action}":
    return _resolve_lane_{id}_{action}(match_state, trigger, event, effect)
```

2. Implement `_resolve_lane_{id}_{action}()`. Key patterns:

```gdscript
# Get the lane this trigger belongs to
var lane_id := str(trigger.get("descriptor", {}).get("_lane_id", ""))

# Get the active player (for start_of_turn triggers)
var active_player_id := str(event.get("player_id", ""))

# Find the lane dict
var lane: Dictionary = {}
for l in match_state.get("lanes", []):
    if str(l.get("lane_id", "")) == lane_id:
        lane = l
        break

# Access creatures: lane.get("player_slots", {}) → pid → Array[card]
# Get power: EvergreenRules.get_power(card)
# Get health: EvergreenRules.get_remaining_health(card)

# Apply player damage (uses lazy loader to avoid circular dep):
var damage_result := _timing_rules().apply_player_damage(match_state, target_pid, amount, {
    "reason": "lane_effect_{id}",
    "source_instance_id": str(trigger.get("source_instance_id", "")),
    "source_controller_player_id": causing_pid,
})

# Draw cards (uses lazy loader to avoid circular dep):
var draw_result := _timing_rules().draw_cards(match_state, player_id, 1, {
    "reason": "lane_effect_{id}",
    "source_instance_id": str(trigger.get("source_instance_id", "")),
    "source_controller_player_id": player_id,
})

# Find opponent
var opponent_id := ""
for player in match_state.get("players", []):
    if str(player.get("player_id", "")) != active_player_id:
        opponent_id = str(player.get("player_id", ""))

# --- Pattern: summon-triggered creature modification ---
# Use the helper to get the summoned creature verified in this lane:
var card := _get_summoned_creature_in_lane(match_state, trigger, event)
if card.is_empty():
    return {"handled": true, "events": []}

# For effects that also work on moves (on_move family), use instead:
# var card := _get_creature_entering_lane(match_state, trigger, event)
# This handles both summon events (with event.lane_id) and move events
# (falls back to card.lane_id since card_moved events lack lane_id)

# Other helpers available:
# _get_lane(match_state, lane_id) -> Dictionary
# _get_opponent_id(match_state, player_id) -> String

# Modify stats (e.g., double health)
var current_health := EvergreenRules.get_health(card)
EvergreenRules.apply_stat_bonus(card, 0, current_health)

# --- Pattern: random creature selection ---
# For arrays of card Dictionaries:
var candidates: Array = [...]
var selected_idx := EvergreenRules._choose_deterministic_candidate_index(match_state, creature_id, candidates)
var target_card: Dictionary = candidates[selected_idx]

# For non-card arrays (strings, etc.), use timing_rules instead:
# var idx: int = _timing_rules()._deterministic_index(match_state, context_key, array_size)

# Always return this shape:
return {"handled": true, "events": events_array}
```

3. Lazy loaders at the bottom of the file (add if missing):
```gdscript
static func _timing_rules():
    return load("res://src/core/match/match_timing.gd")

static func _extended_packs():
    return load("res://src/core/match/extended_mechanic_packs.gd")
```
Use `_extended_packs().apply_custom_effect()` for catalog-dependent operations like `summon_random_from_catalog`.

## Step 5: Ensure Lane Icon Exists

Check `assets/images/lanes/{lane_id}.png`. If missing, note it for the user — art must be added manually or via the fetch-card-art skill pattern.

## Step 6: Write Tests

Add tests to `tests/lane_rules_runner.gd`:

1. Add test function names to `_run_all_tests()` return chain
2. Use the generic `_build_lane_match()` helper (preferred for simple lanes):
```gdscript
var match_state := _build_lane_match("lane_id", "Display Name", "Description.", ["arena"], [
    {"family": "on_friendly_summon", "match_role": "any_player", "effects": [{"op": "lane_grant_keyword", "keyword": "guard"}]}
])
```
For complex lanes needing custom setup, create a dedicated `_build_{lane_id}_match()` helper instead.

3. Write test cases covering:
   - The effect fires correctly in the normal case
   - The effect does NOT fire when conditions aren't met
   - Edge cases: empty lane, ties (if applicable), wrong player

Use existing helpers: `_summon_creature(player, match_state, label, lane_id, power, health)`, `_append_creature_to_hand`, `_assert`.

For turn-based effects, use `MatchTurnLoop.end_turn(match_state, player_id)` to advance turns.

**GDScript gotcha — Array.size():** Returns Variant, so `var x := arr.size()` fails. Wrap: `var x := int(arr.size())`.

**GDScript gotcha — lazy loaders:** Calls through `_timing_rules()` or `_extended_packs()` return Variant. Use explicit types:
```gdscript
# WRONG: var result := _timing_rules().draw_cards(...)
# RIGHT:
var result: Dictionary = _timing_rules().draw_cards(...)
var idx: int = _timing_rules()._deterministic_index(...)
```

**Turn-draw accounting:** Each `end_turn` starts the next player's turn, which includes a normal draw (+1 card). When testing lane effects that draw cards, capture hand sizes immediately before and after the `end_turn` call, and assert the expected total (e.g., `+2` for normal draw + lane bonus, `+1` for normal draw only).

## Step 7: Run Tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file $TMPDIR/godot.log --path {project_root} --script tests/lane_rules_runner.gd
```

Expect output containing `LANE_RULES_OK`. Fix any failures before proceeding.

Also run timing and combat runners to check for regressions:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file $TMPDIR/godot.log --path {project_root} --script tests/timing_runner.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file $TMPDIR/godot.log --path {project_root} --script tests/combat_runner.gd
```
