# Unfixed Card Effects

Cards whose effects have been identified as not yet wired up with `triggered_abilities`.

## Remaining

### Needs target choice mechanic (player picks a target)

- **Valenwood Huntsman** (`str_valenwood_huntsman`) — "Summon: Deal 1 damage." Needs player to choose a creature or player target.
- **Sharpshooter Scout** (`str_sharpshooter_scout`) — "Prophecy. Summon: Deal 1 damage." Needs player to choose a target.
- **Morkul Gatekeeper** (`str_morkul_gatekeeper`) — "Prophecy, Guard. Summon: Give a creature +2/+0." Needs player to choose a creature target.
- **Savage Ogre** (`str_savage_ogre`) — "Summon: Give a creature +5/+0 this turn." Needs player to choose a creature target.
- **Earthbone Spinner** (`str_earthbone_spinner`) — "Summon: Silence another creature, then deal 1 damage to it." Needs target choice + silence + damage combo.
- **Bone Bow** (`str_bone_bow`) — "+1/+0. Summon: Silence another creature." Item, needs target choice for silence on equip.
- **Skooma Racketeer** (`agi_skooma_racketeer`) — "Summon: Give a creature Lethal." Needs player to choose a creature target.
- **Murkwater Witch** (`agi_murkwater_witch`) — "Summon: Give a creature -1/-1." Needs player to choose a creature target.
- **Murkwater Skirmisher** (`agi_murkwater_skirmisher`) — "Summon: Give all other friendly Goblins +2/+2." Needs subtype-based targeting.
- **Crushing Blow** (`neu_crushing_blow`) — "Deal 3 damage." Action card needs player to choose a creature or player target.
- **Loyal Housecarl** (`wil_loyal_housecarl`) — "Prophecy. Summon: Give a creature +2/+2 and Guard." Needs player to choose a creature target.
- **Sunhold Medic** (`wil_sunhold_medic`) — "Summon: Give a creature +0/+2." Needs player to choose a creature target.
- **Cloudrest Illusionist** (`wil_cloudrest_illusionist`) — "Prophecy. Summon: Give a creature -4/-0 this turn." Needs player to choose a creature target.
- **Legion Praefect** (`wil_legion_praefect`) — "Summon: Give other friendly creatures +1/+1." Needs `all_friendly` target type.
- **Pillaging Tribune** (`wil_pillaging_tribune`) — "Summon: Give a friendly creature Drain this turn." Needs player to choose a friendly creature target.
- **Ash Servant** (`int_ash_servant`) — "Summon: Deal 2 damage to a creature." Needs player to choose a creature target.
- **Shocking Wamasu** (`int_shocking_wamasu`) — "Summon: Deal 4 damage to a creature." Needs player to choose a creature target.
- **Firebolt** (`int_firebolt`) — "Deal 2 damage to a creature." Action needs player to choose a creature target.
- **Wardcrafter** (`int_wardcrafter`) — "Summon: Give a creature a Ward." Needs player to choose a creature target.
- **Shrieking Harpy** (`int_shrieking_harpy`) — "Prophecy. Summon: Shackle an enemy creature." Needs player to choose an enemy creature target.
- **Mace of Encumbrance** (`int_mace_of_encumbrance`) — "+2/+1. Summon: Shackle an enemy creature." Item, needs target choice for shackle on equip.
- **Piercing Javelin** (`wil_piercing_javelin`) — "Prophecy. Destroy a creature." Action needs player to choose a creature target.
- **Execute** (`wil_execute`) — "Destroy a creature with 2 power or less." Action needs player to choose + conditional target.
- **Spiteful Dremora** (`wil_spiteful_dremora`) — "Summon: Destroy a creature with 2 power or less." Needs target choice + conditional.
- **Mantikora** (`wil_mantikora`) — "Guard. Summon: Destroy an enemy creature in this lane." Needs target choice (enemy in lane).
- **Vicious Dreugh** (`neu_vicious_dreugh`) — "Summon: Destroy an enemy support." Needs player to choose a support target.
- **Cursed Spectre** (`end_cursed_spectre`) — "Prophecy. Summon: Silence another creature." Needs player to choose a creature target.
- **Shadowfen Priest** (`end_shadowfen_priest`) — "Summon: Silence another creature, or destroy an enemy support." Needs target choice with modal selection.
- **Watch Commander** (`end_watch_commander`) — "Summon: Give all friendly Guards +1/+2." Needs keyword-based targeting.
- **Wrothgar Artisan** (`end_wrothgar_artisan`) — "Summon: Give a creature +1/+1." Needs player to choose a creature target.
- **Ravenous Crocodile** (`neu_ravenous_crocodile`) — "Summon: Deal 2 damage to a friendly creature." Needs player to choose a friendly creature target.
- **Barded Guar** (`neu_barded_guar`) — "Summon: Give a creature Guard." Needs player to choose a creature target.
- **Frenzied Witchman** (`neu_frenzied_witchman`) — "Summon: Give a creature +2/+1." Needs player to choose a creature target.
- **Allena Benoch** (`dual_allena_benoch`) — "Lethal. Summon: Deal 1 damage." Needs player to choose a target.
- **Skywatch Vindicator** (`dual_skywatch_vindicator`) — "Summon: Deal 2 damage to a creature, or give a creature +2/+2." Needs target choice + modal selection.
- **Rift Thane** (`dual_rift_thane`) — "Summon: If more health +0/+2 Guard, else +2/+0 Breakthrough." Needs health comparison + conditional.
- **Queen Barenziah** (`dual_queen_barenziah`) — "Drain. Summon: Give other creatures in this lane Guard." Needs lane-mate targeting.

### Needs ongoing aura mechanic

- **Orc Clan Captain** (`str_orc_clan_captain`) — "Other friendly creatures in this lane have +1/+0." Ongoing passive aura.
- **Northwind Outpost** (`str_northwind_outpost`) — "Ongoing. Friendly Strength creatures have +1/+0." Support ongoing aura.
- **Alpha Wolf** (`wil_alpha_wolf`) — "Other friendly Wolves have +2/+0." Ongoing subtype aura.
- **Summerset Shieldmage** (`wil_summerset_shieldmage`) — "Other friendly creatures in this lane have +0/+1." Ongoing lane aura.
- **Divine Fervor** (`wil_divine_fervor`) — "Ongoing. Friendly creatures have +1/+1." Support ongoing aura.
- **Stormhold Henchman** (`end_stormhold_henchman`) — "+2/+2 while you have 7 or more max magicka." Ongoing conditional self-buff.
- **Stampeding Mammoth** (`end_stampeding_mammoth`) — "+2/+0 per other friendly with Breakthrough." Ongoing conditional.
- **Chieftain's Banner** (`end_chieftains_banner`) — "Ongoing. Friendly Orcs have +0/+2." Support ongoing subtype aura.
- **Rihad Battlemage** (`str_rihad_battlemage`) — "+0/+3 and Guard while equipped with an item." Ongoing conditional buff.
- **Rihad Horseman** (`str_rihad_horseman`) — "+3/+0 and Breakthrough while equipped with item." Ongoing conditional buff.
- **Covenant Marauder** (`str_covenant_marauder`) — "+2/+0 while you have no cards in hand." Ongoing conditional.
- **Snow Wolf** (`wil_snow_wolf`) — "+2/+0 while you have the most creatures in this lane." Ongoing conditional.
- **Niben Bay Cutthroat** (`int_niben_bay_cutthroat`) — "+2/+0 while there are no enemy creatures in this lane." Ongoing conditional.
- **Murkwater Goblin** (`agi_murkwater_goblin`) — "Has +2/+0 on your turn." Ongoing turn-phase conditional.
- **Preserver of the Root** (`end_preserver_of_the_root`) — "+2/+2 and Guard while 7+ max magicka." Ongoing conditional.
- **Thieves' Den** (`agi_thieves_den`) — "Ongoing. Friendly creatures have Pilfer: +1/+1." Support ongoing pilfer aura.
- **Bone Colossus** (`end_bone_colossus`) — "Other friendly Skeletons have +1/+1." Ongoing subtype aura (also needs summon fill lane).

### Needs "on damage taken" / reactive trigger families

- **Fearless Northlander** (`str_fearless_northlander`) — "When takes damage, gains +2/+0." Needs `on_damage_taken` trigger.
- **Shornhelm Champion** (`dual_shornhelm_champion`) — "When Ward broken, gains +3/+3." Needs `on_ward_broken` trigger.
- **Auroran Sentry** (`wil_auroran_sentry`) — "Guard. When dealt damage, you gain that much health." Needs `on_damage_taken` trigger + heal equal to damage.
- **Imprisoned Deathlord** (`end_imprisoned_deathlord`) — "When enemy summoned, Shackle self." Needs `on_enemy_summon` trigger + shackle op.

### Needs "after action played" trigger family

- **Crystal Tower Crafter** (`int_crystal_tower_crafter`) — "After you play an action, gains +1/+1." Needs `after_action_played` trigger.
- **Lillandril Hexmage** (`int_lillandril_hexmage`) — "After you play an action, deal 1 damage to opponent." Needs `after_action_played` trigger.
- **Artaeum Savant** (`wil_artaeum_savant`) — "After you play an action, give random friendly +1/+1." Needs `after_action_played` trigger.

### Needs "on creature summoned" trigger family

- **Fifth Legion Trainer** is wired but others need the trigger family:
- **Helgen Squad Leader** (`wil_helgen_squad_leader`) — "When another friendly creature attacks, gains +1/+0." Actually needs `on_friendly_attack` trigger.
- **Dawnstar Healer** (`wil_dawnstar_healer`) — "After enemy rune destroyed, gain 3 health." Needs `on_enemy_rune_destroyed` trigger.
- **Morthal Executioner** (`wil_morthal_executioner`) — "When enemy rune destroyed, gains +2/+0." Needs `on_enemy_rune_destroyed` trigger.
- **Relentless Raider** (`str_relentless_raider`) — "When enemy rune destroyed, deal 1 damage." Needs `on_enemy_rune_destroyed` trigger.
- **Haafingar Marauder** (`wil_haafingar_marauder`) — "When friendly destroys enemy rune, equip random item." Needs `on_enemy_rune_destroyed` trigger + equip-from-catalog op.

### Needs "on attack" trigger family

- **Fiery Imp** (`str_fiery_imp`) — "When Fiery Imp attacks, deal 2 damage to your opponent." Needs `on_attack` trigger.
- **Reive, Blademaster** (`str_reive_blademaster`) — "When attacks, deal 2 damage to opponent (escalating)." Needs `on_attack` trigger + escalating counter.
- **Staff of Sparks** (`int_staff_of_sparks`) — "+3/+0. When wielder attacks, deals 1 damage to all enemies in lane." Item needs `on_attack` trigger.

### Needs "on equip" trigger family

- **Alik'r Survivalist** (`str_alikr_survivalist`) — "When equipped, +1/+1." Needs `on_equip` trigger.
- **Whirling Duelist** (`str_whirling_duelist`) — "When equips item, deal 1 damage to all enemies in lane." Needs `on_equip` trigger.
- **Dragonstar Rider** (`int_dragonstar_rider`) — "When equips item, draw a card." Needs `on_equip` trigger.

### Needs "on support played/activated" trigger

- **Craglorn Scavenger** (`int_craglorn_scavenger`) — "When you play or activate a support, gains +1/+1." Needs `on_support_played` trigger.

### Needs "at end of turn" condition-checked trigger

- **Shimmerene Peddler** (`int_shimmerene_peddler`) — "At end of turn, if you played two actions, draw a card." Needs `end_of_turn` trigger + action counter condition.
- **Disciple of Namira** (`end_disciple_of_namira`) — "At end of turn, draw per friendly creature that died." Needs `end_of_turn` trigger + death counter.

### Needs "at start of turn" trigger (non-active player too)

- **Blighted Alit** (`str_blighted_alit`) — "At start of your turn, deals 2 damage to you." Needs `start_of_turn` trigger + self-damage.
- **Trebuchet** (`str_trebuchet`) — "At start of your turn, deal 4 damage to random enemy." Needs `start_of_turn` trigger + random enemy target.
- **Gladiator Arena** (`str_gladiator_arena`) — "Ongoing. At start of each turn, deal 2 damage to that player." Support start_of_turn + each player.
- **Blackrose Herbalist** (`end_blackrose_herbalist`) — "At start of turn, heal another random friendly." Needs `start_of_turn` + random friendly target.
- **Reachman Shaman** (`neu_reachman_shaman`) — "At start of turn, give random friendly +1/+1." Needs `start_of_turn` + random friendly target.

### Needs "on creature death" trigger (not Last Gasp)

- **Grim Champion** (`end_grim_champion`) — "When creature in lane dies, gains +1/+1." Needs `on_creature_death_in_lane` trigger.
- **Necromancer's Amulet** (`end_necromancers_amulet`) — "Ongoing. When friendly creature dies, gain 1 health." Support, needs `on_friendly_death` trigger.

### Needs pilfer trigger family

- **Daring Cutpurse** (`agi_daring_cutpurse`) — "Prophecy. Pilfer: +1/+1." Needs `pilfer` family wired.
- **Baandari Bruiser** (`agi_baandari_bruiser`) — "Pilfer: +3/+0." Needs `pilfer` family.
- **Goblin Skulk** (`agi_goblin_skulk`) — "Pilfer: Draw a random 0-cost card." Needs `pilfer` + filtered draw.
- **Quin'rawl Burglar** (`agi_quinrawl_burglar`) — "Drain. Pilfer: +4/+4." Needs `pilfer` family.
- **Tenmar Swiftclaw** (`agi_tenmar_swiftclaw`) — "Pilfer: +1/+1. May attack extra time." Needs `pilfer` + extra attack.
- **Torval Crook** (`agi_torval_crook`) — "Charge. Pilfer: Gain 2 magicka." Needs `pilfer` + gain_magicka op.
- **Rajhini Highwayman** (`wil_rajhini_highwayman`) — "Pilfer: Draw a card." Needs `pilfer` family.
- **Dagi-raht Mystic** (`wil_dagiraht_mystic`) — "Pilfer: Draw a random support from deck." Needs `pilfer` + filtered draw.
- **Descendant of Alkosh** (`wil_descendant_of_alkosh`) — "Pilfer: +1/+1 and random Keyword." Needs `pilfer` + grant_random_keyword.
- **Riverhold Escort** (`wil_riverhold_escort`) — "Guard. Pilfer: Move." Needs `pilfer` + move op.

### Needs slay trigger family

- **Child of Hircine** (`str_child_of_hircine`) — "Slay: May attack again this turn." Needs `slay` + extra attack.
- **Pahmar-raht Renegade** (`agi_pahmarraht_renegade`) — "Slay: Draw a card." Needs `slay` family.
- **Archein Venomtongue** (`end_archein_venomtongue`) — "Lethal. Slay: Gain +1 max magicka." Needs `slay` family.
- **Blood Magic Lord** (`end_blood_magic_lord`) — "Summon and Slay: Put Blood Magic Spell into hand." Needs `slay` + generate card.
- **Night Talon Lord** (`end_night_talon_lord`) — "Drain. Slay: Summon the slain creature." Needs `slay` + summon-from-event op.
- **Dawnbreaker** (`wil_dawnbreaker`) — "+4/+4. Slay: Banish if Undead." Item needs `slay` + conditional banish.
- **Lucien Lachance** (`end_lucien_lachance`) — "Lethal. When another friendly Slays, give it +2/+2." Needs `on_friendly_slay` trigger.

### Needs last_gasp trigger family

- **Balmora Spymaster** (`int_balmora_spymaster`) — "Last Gasp: Summon random creature." Needs `last_gasp` + summon random.
- **Brutal Ashlander** (`int_brutal_ashlander`) — "Last Gasp: Deal 3 damage to random enemy." Needs `last_gasp` + random target.
- **Telvanni Arcanist** (`int_telvanni_arcanist`) — "Last Gasp: Put random action into hand." Needs `last_gasp` + generate card.
- **Elusive Schemer** (`int_elusive_schemer`) — "Summon: Draw. Last Gasp: Shuffle 0-cost copy." Needs `last_gasp` + shuffle-copy op (summon/draw also missing).
- **Heirloom Greatsword** (`int_heirloom_greatsword`) — "Last Gasp: Returns to hand." Item needs `last_gasp` + return-to-hand op.
- **Indoril Archmage** (`int_indoril_archmage`) — "Guard. Last Gasp: Deal 6 damage to all enemies in lane." Needs `last_gasp` + AoE damage.
- **Deshaan Avenger** (`agi_deshaan_avenger`) — "Last Gasp: Summon 3/3 Deshaan Sneak." Needs `last_gasp` + summon_from_effect.
- **House Kinsman** (`agi_house_kinsman`) — "Last Gasp: Deal 3 to opponent, gain 3 health." Needs `last_gasp` + damage + heal.
- **Mournhold Traitor** (`agi_mournhold_traitor`) — "Last Gasp: Opponent summons 2/1 Guardian with Guard." Needs `last_gasp` + summon for opponent.
- **Tazkad the Packmaster** (`agi_tazkad_the_packmaster`) — "Last Gasp: Summon 4/4 Durzog." Needs `last_gasp` + summon_from_effect.
- **Varanis Courier** (`agi_varanis_courier`) — "Guard. Last Gasp: Draw a card." Needs `last_gasp` + draw.
- **Spider Daedra** (`agi_spider_daedra`) — "Summon: Fill with Spiderlings. Last Gasp: Destroy Spiderlings." Needs `last_gasp` + destroy-by-subtype + summon fill lane.
- **Deathless Draugr** (`end_deathless_draugr`) — "Last Gasp: Summon 1/1 Skeleton." Needs `last_gasp` + summon_from_effect.
- **Haunting Spirit** (`end_haunting_spirit`) — "Last Gasp: Give random friendly +3/+3." Needs `last_gasp` + random friendly target.
- **Restless Templar** (`end_restless_templar`) — "Last Gasp: Gain 5 health." Needs `last_gasp` + heal.
- **Sadras Agent** (`dual_sadras_agent`) — "Guard. Last Gasp: Summon 2/1 Mournhold Guardian." Needs `last_gasp` + summon_from_effect.

### Needs "all creatures in lane" target (both sides)

- **Skaven Pyromancer** (`str_skaven_pyromancer`) — "Summon: Deal 1 damage to all other creatures in this lane." Needs all-creatures-in-lane target excluding self.

### Needs item equip lane context

- **Yew Shield** (`end_yew_shield`) — "Summon: +1/+1 for each enemy creature in this lane." Item cards don't have lane context in triggers.
- **Snake Tooth Necklace** (`agi_snake_tooth_necklace`) — "+1/+1. Summon: Give wielder Drain this turn." Item needs on_play to grant status.
- **Enchanted Plate** (`end_enchanted_plate`) — "+0/+3. Summon: Draw a card." Item needs on_play to draw.

### Needs "put card into hand" mechanic

- **Dunmer Nightblade** (`int_dunmer_nightblade`) — "Last Gasp: Put an Iron Sword into your hand." Needs generate-card-to-hand op.
- **High Rock Summoner** (`int_high_rock_summoner`) — "Summon: Put a random Atronach into your hand." Needs generate-random-card-to-hand op.
- **Crown Quartermaster** (`int_crown_quartermaster`) — "Summon: Put a Steel Dagger into your hand." Needs generate-card-to-hand op.
- **Stronghold Incubator** (`neu_stronghold_incubator`) — "Last Gasp: Put two random Dwemer into your hand." Needs generate-random-cards-to-hand op.
- **Cunning Ally** (`int_cunning_ally`) — "Summon: Put a Firebolt into your hand if top deck is Int." Needs generate-card-to-hand + top-deck condition.

### Needs health comparison condition

- **Black Worm Necromancer** (`end_black_worm_necromancer`) — "Summon: If more health, summon random from discard." Needs health comparison + summon-from-discard.
- **Royal Sage** (`int_royal_sage`) — "Summon: If more health, give each friendly a random Keyword." Needs health comparison + grant_random_keyword.
- **Golden Saint** (`wil_golden_saint`) — "Guard. Summon: If more health, summon Golden Saint in other lane." Needs health comparison + summon_copy_to_other_lane.
- **Triumphant Jarl** (`str_triumphant_jarl`) — "Summon: If more health, draw two cards." Needs health comparison condition.
- **Soulrest Marshal** (`agi_soulrest_marshal`) — "Summon: If more health, next card costs 6 less." Needs health comparison + cost reduction.

### Needs conditional summon buffs

- **Bangkorai Butcher** (`str_bangkorai_butcher`) — "Summon: +2/+2 if you have another Orc." Needs subtype-check condition.
- **Silvenar Tracker** (`str_silvenar_tracker`) — "Summon: Gains Charge if Wounded enemy in lane." Needs wounded-enemy-in-lane condition.
- **Mighty Ally** (`str_mighty_ally`) — "Summon: +3/+0 and Breakthrough if top deck is Strength." Needs `required_top_deck_attribute` (exists) + multi-effect.
- **Nimble Ally** (`agi_nimble_ally`) — "Summon: +1/+1 and Lethal if top deck is Agility." Same as above.
- **Aldmeri Patriot** (`wil_aldmeri_patriot`) — "Summon: +1/+1 if you have an action in hand." Needs hand-contents condition.
- **Feasting Vulture** (`agi_feasting_vulture`) — "Summon: +2/+2 if a creature died this turn." Needs creature-died-this-turn condition.
- **Angry Grahl** (`end_angry_grahl`) — "Summon: +2/+2 if opponent has more cards." Needs hand-size comparison condition.
- **Green Pact Stalker** (`agi_green_pact_stalker`) — "Guard. Summon: +2/+2 if Wounded enemy in lane." Needs wounded-enemy condition.
- **Ravenous Hunger** (`wil_ravenous_hunger`) — "Summon: Gains Drain if enemy in lane." Needs enemy-in-lane condition.
- **Wood Orc Headhunter** (`str_wood_orc_headhunter`) — "Summon: Gains Charge if you have another Orc." Needs subtype-check condition.

### Needs "deal damage to all enemies" target type

- **Fireball** (`str_fireball`) — "Deal 1 damage to all enemies." Action needs all-enemies target.
- **Fire Storm** (`int_fire_storm`) — "Prophecy. Deal 2 damage to all creatures in a lane." Needs all-creatures-in-lane target.
- **Ice Storm** (`int_ice_storm`) — "Deal 3 damage to all creatures." Needs all-creatures target.
- **Lightning Bolt** (`int_lightning_bolt`) — "Prophecy. Deal 4 damage." Action needs target choice.
- **Odahviing** (`neu_odahviing`) — "Summon: Deal 4 damage to all enemy creatures." Needs all-enemies target.
- **Giant Snake** (`agi_giant_snake`) — "Summon: Shackle all enemies in lane." Needs all-enemies-in-lane + shackle.
- **Winter's Grasp** (`int_winters_grasp`) — "Shackle all enemy creatures." Action needs all-enemies + shackle.
- **Arrow in the Knee** (`agi_arrow_in_the_knee`) — "Shackle a creature and deal 1 damage." Action needs target choice + shackle + damage.
- **Dread Clannfear** (`str_dread_clannfear`) — "Summon: All enemy creatures lose Guard." Needs all-enemies + remove_keyword op.
- **Red Bramman** (`dual_red_bramman`) — "Summon: Silence and Shackle all enemies in lane." Needs all-enemies-in-lane + silence + shackle.
- **Arrow Storm** (`wil_arrow_storm`) — "Destroy all enemies with 2 power or less in a lane." Needs conditional mass destroy.
- **Dawn's Wrath** (`wil_dawns_wrath`) — "Destroy all creatures in a lane." Needs all-creatures-in-lane + destroy.
- **Immolating Blast** (`wil_immolating_blast`) — "Destroy all except one random on each side." Needs complex mass destroy.

### Needs "destroy" action mechanic

- **Stone Throw** (`str_stone_throw`) — "Destroy enemy creature if you have higher power creature." Needs target + power comparison.
- **Finish Off** (`agi_finish_off`) — "Destroy a Wounded enemy creature." Needs target choice + wounded condition.
- **Leaflurker** (`agi_leaflurker`) — "Summon: Destroy a Wounded creature." Needs target choice + wounded condition.
- **Imprison** (`wil_imprison`) — "Shackle a creature; destroy if 4+ Willpower creatures." Needs target + attribute count condition.
- **Edict of Azura** (`dual_edict_of_azura`) — "Destroy enemy creature or support." Needs target choice + modal.
- **Falinesti Reaver** (`dual_falinesti_reaver`) — "Summon: Destroy all Wounded enemies in lane." Needs conditional mass destroy in lane.

### Needs "move" mechanic

- **Dune Stalker** (`agi_dune_stalker`) — "Prophecy. Summon: Move another friendly creature in this lane." Needs move op + target choice.
- **Dune Smuggler** (`agi_dune_smuggler`) — "Summon: Move friendly creature. When moves, +1/+1." Needs move op + on_move trigger.
- **Shadow Shift** (`agi_shadow_shift`) — "Move a friendly creature. Draw a card." Action needs move + draw.

### Needs "draw with special conditions" mechanic

- **Rapid Shot** (`str_rapid_shot`) — "Deal 1 damage to a creature. If it survives, draw a card." Needs conditional draw.
- **Brilliant Experiment** (`int_brilliant_experiment`) — "Draw a copy of a friendly creature." Needs copy-to-hand op.
- **Ice Spike** (`int_ice_spike`) — "Deal 2 damage to opponent. Draw a card." Action needs damage + draw combo.
- **Abecean Navigator** (`int_abecean_navigator`) — "Summon: If top card is action, draw it." Needs top-deck condition + draw.
- **Fate Weaver** (`int_fate_weaver`) — "Prophecy. Summon: Draw a card." Needs basic summon draw.
- **Nahkriin, Dragon Priest** (`int_nahkriin_dragon_priest`) — "Summon: Draw a card and reduce cost to 0." Needs draw + cost modification.
- **Studium Headmaster** (`int_studium_headmaster`) — "Summon: Each player draws two cards." Needs multi-player draw.
- **Blackmail** (`wil_blackmail`) — "Draw a copy from opponent's deck." Action needs copy-from-opponent.
- **Eastmarch Crusader** (`wil_eastmarch_crusader`) — "Summon: Draw card if enemy rune destroyed." Needs rune-destroyed condition.
- **Summerset Orrery** (`int_summerset_orrery`) — "Activate: Shuffle Prophecy cards, draw that many." Support needs complex draw.
- **Orb of Vaermina** (`neu_orb_of_vaermina`) — "Activate: Draw copy from opponent's deck." Support needs copy-from-opponent.
- **Vigilant Giant** (`str_vigilant_giant`) — "Summon: Draw a card." Needs basic summon draw.
- **Spider Worker** (`neu_spider_worker`) — "Prophecy. Summon: Draw a card." Needs basic summon draw.
- **Leafwater Blessing** (`agi_leafwater_blessing`) — "Give +1/+1. When gain health, draw from discard." Action needs complex effect.
- **Militant Chieftain** (`dual_militant_chieftain`) — "Summon: Draw random Orc from discard. Other Orcs +1/+1." Needs filtered draw + subtype aura.

### Needs "unsummon" mechanic

- **Cast Out** (`str_cast_out`) — "Prophecy. Unsummon a creature." Action needs unsummon + target choice.
- **Belligerent Giant** (`str_belligerent_giant`) — "Summon: Unsummon a creature or destroy an enemy support." Needs unsummon + modal.
- **Forsworn Guide** (`neu_forsworn_guide`) — "Summon: Unsummon friendly to give self +2/+2." Needs unsummon + self-buff.

### Needs support "activate" trigger

- **Skirmisher's Elixir** (`str_skirmishers_elixir`) — "Uses: 3. Activate: Give +2/+0 and Breakthrough." Support needs activate trigger + target.
- **Volendrung** (`str_volendrung`) — "Uses: 2. Activate: Give +4/+4 and Breakthrough." Support needs activate trigger + target.
- **Dark Rift** (`int_dark_rift`) — "Uses: 5. Activate: Deal 1 damage. If dealt 5, sacrifice to summon." Complex support.
- **Goldbrand** (`neu_goldbrand`) — "Uses: 3. Activate: Deal 2 damage (escalating)." Support needs activate + escalating.
- **Elixir of Vigor** (`end_elixir_of_vigor`) — "Uses: 3. Activate: Give +0/+1." Support needs activate + target.
- **Elixir of Conflict** (`neu_elixir_of_conflict`) — "Uses: 3. Activate: Give +1/+1." Support needs activate + target.

### Needs complex / unique mechanics

- **Thieves Guild Recruit** (`agi_thieves_guild_recruit`) — Draw is wired, but cost reduction ("If costs 7+, reduce by 1") not implemented.
- **Dremora Markynaz** (`str_dremora_markynaz`) — "Summon: Double a creature's power and health." Needs double-stats op.
- **Baron of Tear** (`int_baron_of_tear`) — "Summon: Give friendly Int creatures +1/+0 and Guard." Needs attribute-filtered targeting.
- **Burn and Pillage** (`str_burn_and_pillage`) — "Deal 1 damage per destroyed rune." Needs rune-count-based scaling.
- **Riften Pillager** (`str_riften_pillager`) — "Summon: +1/+1 per destroyed enemy rune." Summon/modify_stats wired; `destroy` uncovered (rune count reference).
- **Camlorn Hero** (`int_camlorn_hero`) — "Summon: Deal 2 damage to opponent." Needs player-target damage.
- **Divayth Fyr** (`int_divayth_fyr`) — "Summon: Deal 6 damage to random enemy. Start of turn: summon Daughter." Multi-trigger.
- **Afflicted Alit** (`str_afflicted_alit`) — "Summon: Deal 2 damage to each player." Needs each_player target (partially exists).
- **Cruel Firebloom** (`int_cruel_firebloom`) — "Sacrifice a creature to deal 5 damage to random enemy." Needs sacrifice + random target.
- **Mentor's Ring** (`int_mentors_ring`) — "Summon: Give Keywords to each other friendly creature." Item needs keyword-copy op.
- **Master of Arms** (`int_master_of_arms`) — "Summon: Equip two highest cost items from discard." Needs equip-from-discard.
- **Farsight Nereid** (`int_farsight_nereid`) — "Summon: Reveal top of opponent's deck." Needs reveal op.
- **Arenthia Swindler** (`agi_arenthia_swindler`) — "Summon: Steal all items from enemy creature." Needs steal-items op.
- **Camoran Scout Leader** (`agi_camoran_scout_leader`) — "Summon: Summon 2/2 Scouts per Wounded enemy lane." Conditional multi-summon.
- **Necrom Mastermind** (`agi_necrom_mastermind`) — "Summon: Trigger Last Gasp of each friendly creature." Needs re-trigger op.
- **Pack Wolf** (`wil_pack_wolf`) — "Summon: Summon 1/1 Young Wolf in other lane." Needs summon-to-other-lane op.
- **Renowned Legate** (`wil_renowned_legate`) — "Summon: Summon 1/1 Grunt, gain health per friendly." Multi-op summon.
- **Miraak, Dragonborn** (`wil_miraak_dragonborn`) — "Summon: Steal an enemy creature." Needs steal op.
- **Wild Beastcaller** (`agi_wild_beastcaller`) — "Summon: Summon a random Animal." Needs summon-random-by-subtype.
- **Ungolim the Listener** (`agi_ungolim_the_listener`) — "Summon: Shuffle three Brotherhood Assassins into deck." Needs shuffle-into-deck op.
- **Dark Harvester** (`neu_dark_harvester`) — "Prophecy, Guard. Summon: Gain 4 health." Needs summon heal.
- **Priest of the Moons** (`wil_priest_of_the_moons`) — "Prophecy. Summon: Gain 2 health." Needs summon heal.
- **Stronghold Eradicator** (`neu_stronghold_eradicator`) — "Summon: Give all enemy creatures in lane Guard." Needs all-enemies-in-lane + grant_keyword.
- **Ahnassi** (`dual_ahnassi`) — "Summon: Steal all Keywords from enemy creatures." Needs steal-keywords op.
- **Ayrenn** (`dual_ayrenn`) — "Summon: Draw random action from discard. Actions cost 1 less." Multi-mechanic.
- **Merric-at-Aswala** (`dual_merricataswala`) — "Summon: Equip each friendly in lane with random item." Needs equip-from-catalog.
- **High King Emeric** (`dual_high_king_emeric`) — "Ward. Summon: Deal 2 damage per friendly with Ward." Needs ward-count scaling.
- **Thorn Histmage** (`dual_thorn_histmage`) — "Guard. Summon: Gain +1 max magicka. +1/+0 on max magicka increase." Multi-trigger.
- **General Tullius** (`dual_general_tullius`) — "Summon: Summon Troopers. When friendly dies, +1/+1." Summon wired; modify_stats uncovered (needs on_friendly_death trigger).
- **Hidden Trail** (`agi_hidden_trail`) — "Ongoing. Summon: All Field Lanes become Shadow. +1/+0." Lane modification + aura.
- **Halls of the Dwemer** (`neu_halls_of_the_dwemer`) — "Ongoing. Summon: Put Dwarven Spider into hand. Dwemer +3/+0." Multi-mechanic support.
- **Dres Renegade** (`int_dres_renegade`) — "Guard. Other friendly creatures immune to Shackle." Needs immunity mechanic.
- **Keeper of Whispers** (`int_keeper_of_whispers`) — "Other friendly creatures immune to Silence." Needs immunity mechanic.
- **Dres Tormentor** (`int_dres_tormentor`) — "When enemy Shackled, deal 3 damage." Needs `on_enemy_shackled` trigger.
- **Healing Hands** (`end_healing_hands`) — "Heal a creature, then give +1/+1." Action needs target + heal + modify_stats.
- **Plea to Kynareth** (`end_plea_to_kynareth`) — "Heal all friendly in lane, then give +1/+1." Needs all-friendly-in-lane + heal + modify_stats.
- **Green-Touched Spriggan** (`agi_greentouched_spriggan`) — "When you gain health, gains that much power." Needs `on_health_gained` trigger.
- **Ransack** (`agi_ransack`) — "Prophecy. Deal 3 damage and gain 3 health." Action needs target + damage + heal.
- **Thievery** (`agi_thievery`) — "Deal 3 damage to opponent and gain 3 health." Action needs player damage + heal.
- **Healing Potion** (`wil_healing_potion`) — "Prophecy. Gain 5 health." Action needs heal op.
- **War Cry** (`wil_war_cry`) — "Give friendly creatures in lane +2/+0 this turn." Action needs all-friendly-in-lane + modify_stats.
- **Suppress** (`end_suppress`) — "Silence a creature." Action needs target + silence op.
- **Dwarven Sphere** (`neu_dwarven_sphere`) — "Summon: Shackle an enemy creature." Needs target choice + shackle.

### Token / created cards with missing effects

- **Alfe Fyr / Beyte Fyr / Delte Fyr / Uupse Fyr** (`int_alfe_fyr`, `int_beyte_fyr`, `int_delte_fyr`, `int_uupse_fyr`) — "Summon: Deal 6 damage to random enemy." Need summon + random target damage.
- **Brotherhood Assassin** (`agi_brotherhood_assassin`) — "Lethal. Summon: Draw a card." Needs summon draw.
- **Cavern Spinner** (`agi_cavern_spinner`) — "Summon: Shackle random enemy." Needs summon + random target + shackle.
- **Corpse Curse** (`end_corpse_curse`) — "Shackle all enemies in one lane." Action needs all-enemies-in-lane + shackle.
- **Drain Life** (`end_drain_life`) — "Deal 5 damage to opponent, gain 5 health." Action needs player damage + heal.
- **Slaughterfish** (`neu_slaughterfish`) — "Gains +2/+0 at start of your turn." Needs start_of_turn trigger.
- **Sweet Roll** (`neu_sweet_roll`) — "If creature eats Sweet Roll, heal them." Needs heal-on-eat mechanic.
- **Ancient Giant** (`neu_ancient_giant`) — Passive cost/stats equal max magicka. Needs dynamic stat calculation.

## Previously Fixed

Cards that have been successfully wired with triggered_abilities:
- Chaurus Reaper, Thieves Guild Recruit (draw only), Northpoint Captain, Tree Minder, Stalwart Ally, Resolute Ally, Tome of Alteration, Assassin's Bow, Grahtwood Ambusher, Fifth Legion Trainer, Imperial Siege Engine, Riften Pillager (summon/modify_stats), Bruma Armorer, Dragontail Savior, Flesh Atronach, Gloom Wraith, Wrothgar Kingpin, Murkwater Savage, Supreme Atromancer, Bruma Profiteer, Imperial Reinforcements, Scouting Patrol, Midnight Sweep, Slaughterfish Spawning
