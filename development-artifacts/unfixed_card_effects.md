# Unfixed Card Effects

Cards whose effects have been identified as not yet wired up with `triggered_abilities`.

## Remaining

### Needs target choice mechanic (player picks a target)

- **Bone Bow** (`str_bone_bow`) — "+1/+0. Summon: Silence another creature." Item, needs target choice for silence on equip.
- **Crushing Blow** (`neu_crushing_blow`) — "Deal 3 damage." Action card needs player to choose a creature or player target.
- **Firebolt** (`int_firebolt`) — "Deal 2 damage to a creature." Action needs player to choose a creature target.
- **Mace of Encumbrance** (`int_mace_of_encumbrance`) — "+2/+1. Summon: Shackle an enemy creature." Item, needs target choice for shackle on equip.
- **Piercing Javelin** (`wil_piercing_javelin`) — "Prophecy. Destroy a creature." Action needs player to choose a creature target.
- **Execute** (`wil_execute`) — "Destroy a creature with 2 power or less." Action needs player to choose + conditional target.
- **Skywatch Vindicator** (`dual_skywatch_vindicator`) — "Summon: Deal 2 damage to a creature, or give a creature +2/+2." Needs target choice + modal selection.

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
- **Bone Colossus** (`end_bone_colossus`) — "Other friendly Skeletons have +1/+1." Ongoing subtype aura (summon fill lane NOW WIRED; aura part still unfixed).

### Needs "on damage taken" / reactive trigger families

- **Fearless Northlander** (`str_fearless_northlander`) — "When takes damage, gains +2/+0." Needs `on_damage_taken` trigger.
- **Shornhelm Champion** (`dual_shornhelm_champion`) — "When Ward broken, gains +3/+3." Needs `on_ward_broken` trigger.
- **Auroran Sentry** (`wil_auroran_sentry`) — "Guard. When dealt damage, you gain that much health." Needs `on_damage_taken` trigger + heal equal to damage.
- **Imprisoned Deathlord** (`end_imprisoned_deathlord`) — "When enemy summoned, Shackle self." Needs `on_enemy_summon` trigger + shackle op.

### Needs "on creature summoned" trigger family

- **Fifth Legion Trainer** is wired but others need the trigger family:
- **Helgen Squad Leader** (`wil_helgen_squad_leader`) — "When another friendly creature attacks, gains +1/+0." Actually needs `on_friendly_attack` trigger.
- **Haafingar Marauder** (`wil_haafingar_marauder`) — "When friendly destroys enemy rune, equip random item." Needs `on_enemy_rune_destroyed` trigger + equip-from-catalog op.

### Needs "on attack" trigger family

- **Reive, Blademaster** (`str_reive_blademaster`) — "When attacks, deal 2 damage to opponent (escalating)." Needs `on_attack` trigger + escalating counter.

### Needs "on equip" trigger family

- **Alik'r Survivalist** (`str_alikr_survivalist`) — on_equip → +1/+1 is NOW WIRED. Summon: put Steel Dagger into hand is NOT wired (needs put-card-into-hand mechanic).

### Needs "at end of turn" condition-checked trigger

- **Disciple of Namira** (`end_disciple_of_namira`) — "At end of turn, draw per friendly creature that died." Needs `end_of_turn` trigger + death counter.

### Needs "at start of turn" trigger (non-active player too)

- **Gladiator Arena** (`str_gladiator_arena`) — "Ongoing. At start of each turn, deal 2 damage to that player." Support start_of_turn + each player.
- **Blackrose Herbalist** (`end_blackrose_herbalist`) — "At start of turn, heal another random friendly." Needs `start_of_turn` + random friendly target.

### Needs pilfer trigger family

- **Goblin Skulk** (`agi_goblin_skulk`) — "Pilfer: Draw a random 0-cost card." Needs `pilfer` + filtered draw.
- **Tenmar Swiftclaw** (`agi_tenmar_swiftclaw`) — "Pilfer: +1/+1. May attack extra time." Pilfer +1/+1 wired; extra attack NOT implemented.
- **Torval Crook** (`agi_torval_crook`) — "Charge. Pilfer: Gain 2 magicka." Needs `pilfer` + gain_magicka op.
- **Dagi-raht Mystic** (`wil_dagiraht_mystic`) — "Pilfer: Draw a random support from deck." Needs `pilfer` + filtered draw.

### Needs slay trigger family

- **Child of Hircine** (`str_child_of_hircine`) — "Slay: May attack again this turn." Needs `slay` + extra attack.
- **Blood Magic Lord** (`end_blood_magic_lord`) — "Summon and Slay: Put Blood Magic Spell into hand." Needs `slay` + generate card.
- **Night Talon Lord** (`end_night_talon_lord`) — "Drain. Slay: Summon the slain creature." Needs `slay` + summon-from-event op.
- **Dawnbreaker** (`wil_dawnbreaker`) — "+4/+4. Slay: Banish if Undead." Item needs `slay` + conditional banish.
- **Lucien Lachance** (`end_lucien_lachance`) — "Lethal. When another friendly Slays, give it +2/+2." Needs `on_friendly_slay` trigger.

### Needs last_gasp trigger family

- **Balmora Spymaster** (`int_balmora_spymaster`) — "Last Gasp: Summon random creature." Needs `last_gasp` + summon random.
- **Telvanni Arcanist** (`int_telvanni_arcanist`) — "Last Gasp: Put random action into hand." Needs `last_gasp` + generate card.
- **Elusive Schemer** (`int_elusive_schemer`) — "Summon: Draw. Last Gasp: Shuffle 0-cost copy." Summon draw wired; last_gasp shuffle-copy NOT implemented.
- **Heirloom Greatsword** (`int_heirloom_greatsword`) — "Last Gasp: Returns to hand." Item needs `last_gasp` + return-to-hand op.
- **Spider Daedra** (`agi_spider_daedra`) — "Summon: Fill with Spiderlings. Last Gasp: Destroy Spiderlings." Needs `last_gasp` + destroy-by-subtype + summon fill lane.

### Needs "put card into hand" mechanic

- **High Rock Summoner** (`int_high_rock_summoner`) — "Summon: Put a random Atronach into your hand." Needs generate-random-card-to-hand op.
- **Stronghold Incubator** (`neu_stronghold_incubator`) — "Last Gasp: Put two random Dwemer into your hand." Needs generate-random-cards-to-hand op.
- **Cunning Ally** (`int_cunning_ally`) — "Summon: Put a Firebolt into your hand if top deck is Int." Needs generate-card-to-hand + top-deck condition.

### Needs health comparison condition

- **Black Worm Necromancer** (`end_black_worm_necromancer`) — "Summon: If more health, summon random from discard." Needs health comparison + summon-from-discard.
- **Royal Sage** (`int_royal_sage`) — "Summon: If more health, give each friendly a random Keyword." Needs health comparison + grant_random_keyword.
- **Soulrest Marshal** (`agi_soulrest_marshal`) — "Summon: If more health, next card costs 6 less." Needs health comparison + cost reduction.

### Needs conditional summon buffs

- **Feasting Vulture** (`agi_feasting_vulture`) — "Summon: +2/+2 if a creature died this turn." Needs creature-died-this-turn condition.
- **Angry Grahl** (`end_angry_grahl`) — "Summon: +2/+2 if opponent has more cards." Needs hand-size comparison condition.

### Needs "deal damage to all enemies" target type

- **Fire Storm** (`int_fire_storm`) — "Prophecy. Deal 2 damage to all creatures in a lane." Needs all-creatures-in-lane target.
- **Ice Storm** (`int_ice_storm`) — "Deal 3 damage to all creatures." Needs all-creatures target.
- **Lightning Bolt** (`int_lightning_bolt`) — "Prophecy. Deal 4 damage." Action needs target choice.
- **Winter's Grasp** (`int_winters_grasp`) — "Shackle all enemy creatures." Action needs all-enemies + shackle.
- **Arrow in the Knee** (`agi_arrow_in_the_knee`) — "Shackle a creature and deal 1 damage." Action needs target choice + shackle + damage.
- **Dread Clannfear** (`str_dread_clannfear`) — "Summon: All enemy creatures lose Guard." Needs all-enemies + remove_keyword op.
- **Arrow Storm** (`wil_arrow_storm`) — "Destroy all enemies with 2 power or less in a lane." Needs conditional mass destroy.
- **Dawn's Wrath** (`wil_dawns_wrath`) — "Destroy all creatures in a lane." Needs all-creatures-in-lane + destroy.
- **Immolating Blast** (`wil_immolating_blast`) — "Destroy all except one random on each side." Needs complex mass destroy.

### Needs "destroy" action mechanic

- **Stone Throw** (`str_stone_throw`) — "Destroy enemy creature if you have higher power creature." Needs target + power comparison.
- **Finish Off** (`agi_finish_off`) — "Destroy a Wounded enemy creature." Needs target choice + wounded condition.
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
- **Abecean Navigator** (`int_abecean_navigator`) — "Summon: If top card is action, draw it." Needs top-deck condition + draw.
- **Nahkriin, Dragon Priest** (`int_nahkriin_dragon_priest`) — "Summon: Draw a card and reduce cost to 0." Needs draw + cost modification.
- **Blackmail** (`wil_blackmail`) — "Draw a copy from opponent's deck." Action needs copy-from-opponent.
- **Summerset Orrery** (`int_summerset_orrery`) — "Activate: Shuffle Prophecy cards, draw that many." Support needs complex draw.
- **Orb of Vaermina** (`neu_orb_of_vaermina`) — "Activate: Draw copy from opponent's deck." Support needs copy-from-opponent.
- **Leafwater Blessing** (`agi_leafwater_blessing`) — "Give +1/+1. When gain health, draw from discard." Action needs complex effect.
- **Militant Chieftain** (`dual_militant_chieftain`) — "Summon: Draw random Orc from discard. Other Orcs +1/+1." Summon +1/+1 to all friendly Orcs wired; draw Orc from discard NOT implemented.

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
- **Burn and Pillage** (`str_burn_and_pillage`) — "Deal 1 damage per destroyed rune." Needs rune-count-based scaling.
- **Riften Pillager** (`str_riften_pillager`) — "Summon: +1/+1 per destroyed enemy rune." Summon/modify_stats wired; `destroy` uncovered (rune count reference).
- **Divayth Fyr** (`int_divayth_fyr`) — "Summon: Deal 6 damage to random enemy. Start of turn: summon Daughter." Summon deal 6 damage wired; start_of_turn summon Daughter NOT implemented.
- **Cruel Firebloom** (`int_cruel_firebloom`) — "Sacrifice a creature to deal 5 damage to random enemy." Needs sacrifice + random target.
- **Mentor's Ring** (`int_mentors_ring`) — "Summon: Give Keywords to each other friendly creature." Item needs keyword-copy op.
- **Master of Arms** (`int_master_of_arms`) — "Summon: Equip two highest cost items from discard." Needs equip-from-discard.
- **Farsight Nereid** (`int_farsight_nereid`) — "Summon: Reveal top of opponent's deck." Needs reveal op.
- **Arenthia Swindler** (`agi_arenthia_swindler`) — "Summon: Steal all items from enemy creature." Needs steal-items op.
- **Camoran Scout Leader** (`agi_camoran_scout_leader`) — "Summon: Summon 2/2 Scouts per Wounded enemy lane." Conditional multi-summon.
- **Necrom Mastermind** (`agi_necrom_mastermind`) — "Summon: Trigger Last Gasp of each friendly creature." Needs re-trigger op.
- **Renowned Legate** (`wil_renowned_legate`) — "Summon: Summon 1/1 Grunt, gain health per friendly." Multi-op summon (summon Imperial Grunt NOW WIRED; heal-per-friendly part still unfixed).
- **Miraak, Dragonborn** (`wil_miraak_dragonborn`) — "Summon: Steal an enemy creature." Needs steal op.
- **Wild Beastcaller** (`agi_wild_beastcaller`) — "Summon: Summon a random Animal." Needs summon-random-by-subtype.
- **Ungolim the Listener** (`agi_ungolim_the_listener`) — "Summon: Shuffle three Brotherhood Assassins into deck." Needs shuffle-into-deck op.
- **Ahnassi** (`dual_ahnassi`) — "Summon: Steal all Keywords from enemy creatures." Needs steal-keywords op.
- **Ayrenn** (`dual_ayrenn`) — "Summon: Draw random action from discard. Actions cost 1 less." Multi-mechanic.
- **Merric-at-Aswala** (`dual_merricataswala`) — "Summon: Equip each friendly in lane with random item." Needs equip-from-catalog.
- **High King Emeric** (`dual_high_king_emeric`) — "Ward. Summon: Deal 2 damage per friendly with Ward." Needs ward-count scaling.
- **Thorn Histmage** (`dual_thorn_histmage`) — "Guard. Summon: Gain +1 max magicka. +1/+0 on max magicka increase." Summon +1 max magicka wired; modify_stats on magicka increase NOT implemented.
- **Hidden Trail** (`agi_hidden_trail`) — "Ongoing. Summon: All Field Lanes become Shadow. +1/+0." Lane modification + aura.
- **Halls of the Dwemer** (`neu_halls_of_the_dwemer`) — "Ongoing. Summon: Put Dwarven Spider into hand. Dwemer +3/+0." Multi-mechanic support.
- **Dres Renegade** (`int_dres_renegade`) — "Guard. Other friendly creatures immune to Shackle." Needs immunity mechanic.
- **Keeper of Whispers** (`int_keeper_of_whispers`) — "Other friendly creatures immune to Silence." Needs immunity mechanic.
- **Dres Tormentor** (`int_dres_tormentor`) — "When enemy Shackled, deal 3 damage." Needs `on_enemy_shackled` trigger.
- **Healing Hands** (`end_healing_hands`) — "Heal a creature, then give +1/+1." Action needs target + heal + modify_stats.
- **Plea to Kynareth** (`end_plea_to_kynareth`) — "Heal all friendly in lane, then give +1/+1." Needs all-friendly-in-lane + heal + modify_stats.
- **Green-Touched Spriggan** (`agi_greentouched_spriggan`) — "When you gain health, gains that much power." Needs `on_health_gained` trigger.
- **War Cry** (`wil_war_cry`) — "Give friendly creatures in lane +2/+0 this turn." Action needs all-friendly-in-lane + modify_stats.
- **Suppress** (`end_suppress`) — "Silence a creature." Action needs target + silence op.

### Token / created cards with missing effects

- **Sweet Roll** (`neu_sweet_roll`) — "If creature eats Sweet Roll, heal them." Needs heal-on-eat mechanic.
- **Ancient Giant** (`neu_ancient_giant`) — Passive cost/stats equal max magicka. Needs dynamic stat calculation.

## Previously Fixed

Cards that have been successfully wired with triggered_abilities:
- Chaurus Reaper, Thieves Guild Recruit (draw only), Northpoint Captain, Tree Minder, Stalwart Ally, Resolute Ally, Tome of Alteration, Assassin's Bow, Grahtwood Ambusher, Fifth Legion Trainer, Imperial Siege Engine, Riften Pillager (summon/modify_stats), Bruma Armorer, Dragontail Savior, Flesh Atronach, Gloom Wraith, Wrothgar Kingpin, Murkwater Savage, Supreme Atromancer, Bruma Profiteer, Imperial Reinforcements, Scouting Patrol, Midnight Sweep, Slaughterfish Spawning
- Afflicted Alit, Blighted Alit, Mighty Ally, Vigilant Giant, Camlorn Hero, Fate Weaver (summon draw only; prophecy play-for-free not implemented), Indoril Archmage, Studium Headmaster, Elusive Schemer (summon draw only; last_gasp shuffle-copy not implemented), Descendant of Alkosh, Priest of the Moons, Rajhini Highwayman, Riverhold Escort, Baandari Bruiser, Daring Cutpurse, Deshaan Avenger, House Kinsman, Mournhold Traitor, Nimble Ally, Pahmar-raht Renegade, Quin'rawl Burglar, Tazkad the Packmaster, Tenmar Swiftclaw (pilfer +1/+1 only; extra attack not implemented), Varanis Courier, Snake Tooth Necklace, Archein Venomtongue, Deathless Draugr, Restless Templar, Enchanted Plate, Dark Harvester, Spider Worker, Slaughterfish, Sadras Agent, Thorn Histmage (summon +1 max magicka only; modify_stats on magicka increase not implemented), Brotherhood Assassin
- Bangkorai Butcher (summon conditional +2/+2 if another Orc), Silvenar Tracker (summon conditional Charge if wounded enemy in lane), Triumphant Jarl (summon conditional draw 2 if more health), Wood Orc Headhunter (summon conditional Charge if another Orc), Golden Saint (summon conditional summon Golden Saint in other lane if more health), Ravenous Hunger (summon conditional Drain if enemy in lane), Pack Wolf (summon Young Wolf in other lane), Green Pact Stalker (summon conditional +2/+2 if wounded enemy in lane), Rift Thane (summon conditional buffs based on health comparison)
- Relentless Raider (rune_break → damage opponent 1), Morthal Executioner (rune_break → +2/+0), Dawnstar Healer (rune_break → heal 3), Ice Spike (on_play → damage opponent 2 + draw 1), Healing Potion (on_play → heal 5), Ransack (on_play → damage opponent 3 + heal 3), Thievery (on_play → damage opponent 3 + heal 3), Drain Life (token; on_play → damage opponent 5 + heal 5), Bone Colossus (summon fill lane with Skeletons only; aura still unfixed), Renowned Legate (summon Imperial Grunt only; heal-per-friendly still unfixed), Queen Barenziah (summon → grant Guard to all friendly in lane), Stronghold Eradicator (summon → grant Guard to all enemies in lane)
- Odahviing (summon → deal 4 damage to all enemies both lanes), Skaven Pyromancer (summon → deal 1 damage to all other creatures in lane), Giant Snake (summon → shackle all enemies in lane), Red Bramman (summon → silence + shackle all enemies in lane), Legion Praefect (summon → +1/+1 to all friendly both lanes), Yew Shield (on_play → +1/+1 per enemy in lane on wielder), Corpse Curse (token; on_play → shackle all enemies in lane)
- Trebuchet (start_of_turn → deal 4 damage to random enemy), Reachman Shaman (start_of_turn → +1/+1 to random friendly), Brutal Ashlander (last_gasp → deal 3 damage to random enemy), Haunting Spirit (last_gasp → +3/+3 to random friendly), Alfe Fyr (summon → deal 6 damage to random enemy), Beyte Fyr (summon → deal 6 damage to random enemy), Delte Fyr (summon → deal 6 damage to random enemy), Uupse Fyr (summon → deal 6 damage to random enemy), Cavern Spinner (summon → shackle random enemy), Crown Quartermaster (summon → generate Steel Dagger to hand), Dunmer Nightblade (last_gasp → generate Iron Sword to hand), Divayth Fyr (summon deal 6 damage to random enemy only; start_of_turn summon Daughter not implemented)
- Murkwater Skirmisher (summon → +2/+2 to all friendly Goblins, filtered by subtype), Watch Commander (summon → +1/+2 to all friendly Guards, filtered by keyword), Baron of Tear (summon → +1/+0 and Guard to all friendly Intelligence creatures, filtered by attribute), Eastmarch Crusader (summon → draw if enemy rune destroyed, conditional), Shimmerene Peddler (end_of_turn → draw if played 2 actions), Fireball (on_play → deal 1 damage to all enemies + opponent), Aldmeri Patriot (summon → +1/+1 if action in hand, conditional), Militant Chieftain (summon +1/+1 to all friendly Orcs only; draw Orc from discard not implemented)
- Fiery Imp (on_attack → damage opponent 2), Staff of Sparks (on_attack → deal 1 damage to all enemies in lane, item), Crystal Tower Crafter (after_action_played → +1/+1), Lillandril Hexmage (after_action_played → damage opponent 1), Artaeum Savant (after_action_played → +1/+1 to random friendly), Grim Champion (on_friendly_death + opponent death → +1/+1 both sides), Necromancer's Amulet (on_friendly_death → heal 1), Alik'r Survivalist (on_equip → +1/+1 only; summon put-dagger-in-hand not implemented), Dragonstar Rider (on_equip → draw), Whirling Duelist (on_equip → deal 1 damage to all enemies in lane), Craglorn Scavenger (on_play support + activate → +1/+1), General Tullius (on_friendly_death → +1/+1; summon was already wired, now fully fixed)
- Sharpshooter Scout (summon → target choice creature_or_player → deal_damage 1), Valenwood Huntsman (summon → target choice creature_or_player → deal_damage 1), Morkul Gatekeeper (summon → target choice any_creature → modify_stats +2/+0), Savage Ogre (summon → target choice any_creature → modify_stats +5/+0), Earthbone Spinner (summon → target choice another_creature → silence + deal_damage 1), Ash Servant (summon → target choice enemy_creature → deal_damage 2), Shocking Wamasu (summon → target choice enemy_creature → deal_damage 4), Shrieking Harpy (summon → target choice enemy_creature → shackle), Wardcrafter (summon → target choice any_creature → grant_keyword ward), Sunhold Medic (summon → target choice any_creature → modify_stats +0/+2), Loyal Housecarl (summon → target choice any_creature → modify_stats +2/+2 + grant_keyword guard), Cloudrest Illusionist (summon → target choice any_creature → modify_stats -4/0), Mantikora (summon → target choice enemy_creature_in_lane → destroy_creature), Spiteful Dremora (summon → target choice any_creature filtered max_power 2 → destroy_creature), Pillaging Tribune (summon → target choice friendly_creature → grant_keyword drain), Skooma Racketeer (summon → target choice any_creature → grant_keyword lethal), Murkwater Witch (summon → target choice any_creature → modify_stats -1/-1), Leaflurker (summon → target choice any_creature filtered wounded → destroy_creature), Cursed Spectre (summon → target choice another_creature → silence), Shadowfen Priest (summon → multi target choice: another_creature → silence, enemy_support → destroy), Wrothgar Artisan (summon → target choice any_creature → modify_stats +1/+1), Barded Guar (summon → target choice any_creature → grant_keyword guard), Frenzied Witchman (summon → target choice any_creature → modify_stats +2/+1), Dwarven Sphere (summon → target choice enemy_creature → shackle), Vicious Dreugh (summon → target choice enemy_support → destroy_creature), Ravenous Crocodile (summon → target choice friendly_creature → deal_damage 2), Allena Benoch (summon → target choice creature_or_player → deal_damage 1)
