# Card Data Format Reference

## _seed() Signature

```gdscript
_seed(card_id: String, name: String, attributes: Array, card_type: String, cost: int, base_power: int, base_health: int, extra: Dictionary = {})
```

## Attribute IDs

Lowercase strings: `"strength"`, `"intelligence"`, `"willpower"`, `"agility"`, `"endurance"`, `"neutral"`

Neutral cards use `["neutral"]` in the attributes array.

## Card Types

`"creature"`, `"action"`, `"item"`, `"support"`

## Rarity Values

`"common"` (default), `"rare"`, `"epic"`, `"legendary"`

## Extra Dictionary Fields

| Field | Type | When to use |
|---|---|---|
| `set_id` | String | **Always** — use the expansion constant |
| `release_group_id` | String | **Always** — use the expansion constant |
| `rarity` | String | If not common |
| `is_unique` | bool | True for legendary unique cards |
| `keywords` | Array[String] | Static keywords on the card |
| `effect_ids` | Array[String] | Effect system hooks |
| `rules_text` | String | Card text as displayed |
| `rules_tags` | Array[String] | Special tags: `"prophecy"`, `"shout"` |
| `subtypes` | Array[String] | Creature subtypes: `"Nord"`, `"Dragon"`, etc. |
| `support_uses` | int | For support cards with limited uses (0 = ongoing) |
| `collectible` | bool | `false` for tokens/generated cards |
| `triggered_abilities` | Array[Dict] | Ability definitions (see below) |
| `aura` | Dict | Persistent stat/keyword buffs |
| `grants_immunity` | Array[String] | Immunity to effects |
| `cost_reduction_aura` | Dict | Dynamic cost reduction |
| `magicka_aura` | int | Magicka generation bonus |
| `action_target_mode` | String | Targeting for actions |

### Item-specific fields

| Field | Type | Purpose |
|---|---|---|
| `equip_power_bonus` | int | Power granted when equipped |
| `equip_health_bonus` | int | Health granted when equipped |
| `equip_keywords` | Array[String] | Keywords granted when equipped |

**Critical**: Items need BOTH display fields (`keywords`, `rules_text`) AND equip fields (`equip_power_bonus`, etc.). The display fields show on the card; the equip fields are used by the engine.

### Shout-specific fields

| Field | Type | Purpose |
|---|---|---|
| `shout_chain_id` | String | Shared ID across all levels of the same shout |
| `shout_level` | int | Current level (1, 2, or 3) |
| `shout_levels` | Array[Dict] | Full template for each level |

## Triggered Abilities Format

```gdscript
{
    "family": "summon",           # Trigger type
    "target_mode": "any_creature", # Optional: targeting
    "required_zone": "lane",       # Optional: zone requirement
    "effects": [
        {"op": "deal_damage", "target": "chosen_target", "amount": 3}
    ]
}
```

### Common trigger families

| Family | When it fires |
|---|---|
| `summon` | Creature enters play |
| `on_play` | Card played from hand |
| `last_gasp` | Creature destroyed |
| `slay` | Creature kills enemy creature |
| `pilfer` | Creature damages opponent directly |
| `activate` | Support activated |
| `start_of_turn` | Owner's turn begins |
| `end_of_turn` | Owner's turn ends |
| `on_attack` | Creature attacks |
| `on_damage` | Creature takes damage |
| `on_friendly_summon` | Another friendly creature summoned |
| `on_friendly_death` | Friendly creature dies |
| `on_enemy_rune_destroyed` | Enemy rune breaks |
| `after_action_played` | After an action resolves |
| `on_card_drawn` | Card drawn |
| `on_player_healed` | Player heals |
| `on_move` | Creature moves lanes |
| `rune_break` | Rune break interrupt window (used for Beast Form) |

### Common effect operations

| Op | Purpose |
|---|---|
| `deal_damage` | Deal damage to target |
| `damage` | Deal damage to player |
| `modify_stats` | Change power/health |
| `double_stats` | Double power and health |
| `grant_keyword` | Give keyword to creature |
| `grant_random_keyword` | Give random keyword |
| `grant_status` | Apply status (cover, shackle) |
| `draw_cards` | Draw cards |
| `draw_filtered` | Draw card matching filter |
| `draw_from_discard_filtered` | Draw from discard pile |
| `generate_card_to_hand` | Put specific card in hand |
| `generate_random_to_hand` | Put random matching card in hand |
| `summon_from_effect` | Summon a token creature |
| `fill_lane_with` | Fill a lane with token copies |
| `destroy_creature` | Destroy a creature |
| `unsummon` | Return creature to hand |
| `silence` | Silence a creature |
| `shackle` | Shackle a creature |
| `heal` | Heal player |
| `restore_creature_health` | Heal creature to full |
| `transform` | Transform creature into template |
| `move_between_lanes` | Move creature to other lane |
| `gain_magicka` | Gain temporary magicka |
| `gain_max_magicka` | Gain permanent max magicka |
| `copy_from_opponent_deck` | Copy top of opponent's deck |
| `upgrade_shout` | Upgrade other copies of this shout |
| `choose_one` | Present player with choices |
| `battle_creature` | Force creature to battle |
| `steal` | Steal enemy creature |
| `sacrifice_and_resummon` | Destroy then resummon a copy |

### Common conditions/filters on triggers

| Field | Purpose |
|---|---|
| `required_zone` | Card must be in this zone (`"lane"`, `"support"`, `"discard"`) |
| `match_role` | `"opponent_player"` for opponent events |
| `required_summon_subtype` | Summoned creature must be subtype |
| `required_summon_keyword` | Summoned creature must have keyword |
| `required_summon_min_power` | Summoned creature must have min power |
| `required_summon_min_health` | Summoned creature must have min health |
| `required_summon_min_cost` | Summoned creature must have min cost |
| `required_friendly_attribute_count` | `{"attribute": "strength", "min": 2}` |
| `required_played_rules_tag` | Played action must have tag (e.g., `"shout"`) |
| `required_subtype_on_board` | Must have another creature of subtype |
| `required_wounded_enemy_in_lane` | Wounded enemy in same lane |
| `required_controller_turn` | Must be controller's turn |
| `once_per_instance` | Only fires once per card instance |

## Shout Card Template

```gdscript
_seed("hos_str_unrelenting_force", "Unrelenting Force", ["strength"], "action", 3, 0, 0, {
    "set_id": HOS_SET_ID,
    "release_group_id": HOS_RELEASE_GROUP_ID,
    "rules_tags": ["shout"],
    "effect_ids": ["unsummon", "shout"],
    "rules_text": "Shout\nLevel 1: ...\nLevel 2: ...\nLevel 3: ...",
    "action_target_mode": "enemy_creature_3_power_or_less",
    "shout_chain_id": "unrelenting_force",
    "shout_level": 1,
    "shout_levels": [
        {
            "definition_id": "hos_str_unrelenting_force",
            "name": "Unrelenting Force",
            "card_type": "action",
            "attributes": ["strength"],
            "cost": 3,
            "rules_tags": ["shout"],
            "shout_chain_id": "unrelenting_force",
            "shout_level": 1,
            "triggered_abilities": [
                {"family": "on_play", "effects": [{"op": "unsummon", "target": "event_target"}]},
                {"family": "on_play", "required_zone": "discard", "effects": [{"op": "upgrade_shout"}]}
            ]
        },
        // ... level 2 and 3 templates
    ],
    "triggered_abilities": [
        {"family": "on_play", "effects": [{"op": "unsummon", "target": "event_target"}]},
        {"family": "on_play", "required_zone": "discard", "effects": [{"op": "upgrade_shout"}]}
    ]
})
```

Key: The top-level `triggered_abilities` match level 1. Each entry in `shout_levels` is a full card template that replaces the card when upgraded.

## Beast Form Card Template

```gdscript
_seed("hos_str_circle_initiate", "Circle Initiate", ["strength"], "creature", 2, 2, 2, {
    "set_id": HOS_SET_ID,
    "rules_tags": ["prophecy"],
    "effect_ids": ["beast_form"],
    "subtypes": ["Nord"],
    "rules_text": "Prophecy\nBeast Form: +2/+1.",
    "triggered_abilities": [{
        "family": "rune_break",
        "match_role": "opponent_player",
        "required_zone": "lane",
        "effects": [{
            "op": "transform",
            "target": "self",
            "card_template": {
                "definition_id": "hos_str_circle_initiate_werewolf",
                "name": "Circle Initiate",
                "card_type": "creature",
                "subtypes": ["Werewolf"],
                "attributes": ["strength"],
                "power": 4,  // base + beast form bonus
                "health": 3,
                "keywords": [],
                "rules_text": ""
            }
        }]
    }]
})
```

Key: Uses `rune_break` family with `match_role: "opponent_player"`. The werewolf template stats are the TOTAL after transformation (base + bonus). Werewolf forms do NOT need separate non-collectible _seed entries — they exist only as inline templates.

## Aura Format

```gdscript
"aura": {
    "scope": "same_lane",        // "self", "same_lane", "all_lanes"
    "target": "other_friendly",  // "all_friendly", "other_friendly"
    "power": 1,                  // Optional stat bonus
    "health": 0,                 // Optional stat bonus
    "keywords": ["breakthrough"],// Optional keyword grants
    "filter_attribute": "strength", // Optional: only affect this attribute
    "filter_subtype": "Orc",       // Optional: only affect this subtype
    "filter_keyword": "guard",     // Optional: only affect creatures with keyword
    "condition": "has_item",       // Optional: self-aura condition
}
```

## Available Keywords

`breakthrough`, `charge`, `drain`, `guard`, `lethal`, `mobilize`, `rally`, `regenerate`, `ward`

Extended (check engine support): `beast_form`, `shout`, `assemble`, `betray`, `exalt`, `plot`, `veteran`

## 47 Known Subtypes

Aldus, Argonian, Ash Creature, Beast, Breton, Centaur, Chaurus, Daedra, Dark Elf, Defense, Dragon, Dreugh, Dwemer, Falmer, Fish, Gargoyle, Giant, Goblin, Harpy, High Elf, Imp, Imperial, Khajiit, Kwama, Lurcher, Mammoth, Mantikora, Minotaur, Mudcrab, Mummy, Nereid, Nord, Ogre, Orc, Pastry, Reachman, Redguard, Reptile, Skeleton, Spider, Spirit, Spriggan, Troll, Vampire, Wamasu, Werewolf, Wolf, Wood Elf, Wraith
