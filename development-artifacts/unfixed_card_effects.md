# Unfixed Card Effects

Cards whose effects have been identified as not yet wired up with `triggered_abilities`.

## Remaining

### Needs ongoing aura mechanic

- **Thieves' Den** — WIRED (see Previously Fixed).

### Needs "on damage taken" / reactive trigger families

(Shornhelm Champion and Auroran Sentry have been wired — see Previously Fixed.)

### Needs "on creature summoned" trigger family

- **Fifth Legion Trainer** is wired but others need the trigger family:
- **Haafingar Marauder** — WIRED (see Previously Fixed).

### Needs "on attack" trigger family

- **Reive, Blademaster** — WIRED (see Previously Fixed).

### Needs "at end of turn" condition-checked trigger

(Disciple of Namira has been wired — see Previously Fixed.)

### Needs "at start of turn" trigger (non-active player too)

(Gladiator Arena and Blackrose Herbalist have been wired — see Previously Fixed.)

### Needs pilfer trigger family

- **Tenmar Swiftclaw** — WIRED (see Previously Fixed).

### Needs slay trigger family

- **Child of Hircine** — WIRED (see Previously Fixed).
- **Blood Magic Lord** — WIRED (see Previously Fixed).
- **Dawnbreaker** — WIRED (see Previously Fixed).
- **Lucien Lachance** — WIRED (see Previously Fixed).

### Needs last_gasp trigger family

- **Balmora Spymaster** — WIRED (see Previously Fixed).
- **Telvanni Arcanist** — WIRED (see Previously Fixed).
- **Heirloom Greatsword** — WIRED (see Previously Fixed).
- **Elusive Schemer** — WIRED (see Previously Fixed).
- **Spider Daedra** — WIRED (see Previously Fixed).

### Needs "put card into hand" mechanic

- **High Rock Summoner** — WIRED (see Previously Fixed).
- **Stronghold Incubator** — WIRED (see Previously Fixed).

### Needs health comparison condition

- **Black Worm Necromancer** — WIRED (see Previously Fixed).
- **Soulrest Marshal** — WIRED (see Previously Fixed).

### Needs conditional summon buffs

(Feasting Vulture has been wired — see Previously Fixed.)

### Needs "deal damage to all enemies" target type

- **Fire Storm** — WIRED (see Previously Fixed).
- **Arrow Storm** — WIRED (see Previously Fixed).
- **Dawn's Wrath** — WIRED (see Previously Fixed).
- **Immolating Blast** — WIRED (see Previously Fixed).

### Needs "destroy" action mechanic

- **Stone Throw** — WIRED (see Previously Fixed).
- **Imprison** — WIRED (see Previously Fixed).

### Needs "move" mechanic

- **Dune Smuggler** — WIRED (see Previously Fixed).

### Needs "draw with special conditions" mechanic

- **Rapid Shot** — WIRED (see Previously Fixed).
- **Brilliant Experiment** — WIRED (see Previously Fixed).
- **Nahkriin, Dragon Priest** — WIRED (see Previously Fixed).
- **Blackmail** — WIRED (see Previously Fixed).
- **Summerset Orrery** — WIRED (see Previously Fixed).
- **Orb of Vaermina** — WIRED (see Previously Fixed).
- **Leafwater Blessing** — WIRED (see Previously Fixed).
- **Militant Chieftain** — WIRED (see Previously Fixed).

### Needs support "activate" trigger

- **Skirmisher's Elixir** — WIRED (see Previously Fixed).
- **Volendrung** — WIRED (see Previously Fixed).
- **Dark Rift** — WIRED (see Previously Fixed).
- **Goldbrand** — WIRED (see Previously Fixed).
- **Elixir of Vigor** — WIRED (see Previously Fixed).
- **Elixir of Conflict** — WIRED (see Previously Fixed).

### Needs "summon random creature by cost" mechanic

- **Desperate Conjuring** — WIRED (see Previously Fixed).

### Needs "summon random from deck" mechanic

- **Gortwog gro-Nagorm** — WIRED (see Previously Fixed).

### Needs "once per turn" trigger tracking

- **Wrothgar Forge** — WIRED (see Previously Fixed).

### Needs "Moment of Clarity" card-selection UI

- **Moment of Clarity** — WIRED (see Previously Fixed; simplified to generate 1 random card since card-choice UI doesn't exist yet).

### Needs complex / unique mechanics

- **Thieves Guild Recruit** — WIRED (see Previously Fixed).
- **Dremora Markynaz** — WIRED (see Previously Fixed).
- **Burn and Pillage** — WIRED (see Previously Fixed).
- **Riften Pillager** — WIRED (see Previously Fixed; already uses destroyed_enemy_runes count_source).
- **Divayth Fyr** — WIRED (see Previously Fixed).
- **Cruel Firebloom** — WIRED (see Previously Fixed).
- **Mentor's Ring** — WIRED (see Previously Fixed).
- **Master of Arms** — WIRED (see Previously Fixed).
- **Farsight Nereid** — WIRED (see Previously Fixed; reveal is cosmetic, wired as log event).
- **Arenthia Swindler** — WIRED (see Previously Fixed).
- **Camoran Scout Leader** — WIRED (see Previously Fixed).
- **Necrom Mastermind** — WIRED (see Previously Fixed).
- **Renowned Legate** — WIRED (see Previously Fixed).
- **Miraak, Dragonborn** — WIRED (see Previously Fixed).
- **Wild Beastcaller** — WIRED (see Previously Fixed).
- **Ungolim the Listener** — WIRED (see Previously Fixed).
- **Ahnassi** — WIRED (see Previously Fixed).
- **Ayrenn** — WIRED (see Previously Fixed).
- **Merric-at-Aswala** — WIRED (see Previously Fixed).
- **High King Emeric** — WIRED (see Previously Fixed).
- **Thorn Histmage** — WIRED (see Previously Fixed).
- **Hidden Trail** — WIRED (see Previously Fixed).
- **Halls of the Dwemer** — WIRED (see Previously Fixed).
- **Dres Renegade** — WIRED (see Previously Fixed).
- **Keeper of Whispers** — WIRED (see Previously Fixed).
- **Dres Tormentor** — WIRED (see Previously Fixed).
- **Healing Hands** — WIRED (see Previously Fixed).
- **Plea to Kynareth** — WIRED (see Previously Fixed).
- **Green-Touched Spriggan** — WIRED (see Previously Fixed).
- **War Cry** — WIRED (see Previously Fixed).

### Token / created cards with missing effects

- **Sweet Roll** — WIRED (see Previously Fixed).
- **Ancient Giant** — WIRED (see Previously Fixed).

## Previously Fixed

Cards that have been successfully wired with triggered_abilities:
- Chaurus Reaper, Thieves Guild Recruit (summon → draw + post_draw_cost_reduce if 7+; fully fixed), Northpoint Captain, Tree Minder, Stalwart Ally, Resolute Ally, Tome of Alteration, Assassin's Bow, Grahtwood Ambusher, Fifth Legion Trainer, Imperial Siege Engine, Riften Pillager (summon/modify_stats), Bruma Armorer, Dragontail Savior, Flesh Atronach, Gloom Wraith, Wrothgar Kingpin, Murkwater Savage, Supreme Atromancer, Bruma Profiteer, Imperial Reinforcements, Scouting Patrol, Midnight Sweep, Slaughterfish Spawning
- Afflicted Alit, Blighted Alit, Mighty Ally, Vigilant Giant, Camlorn Hero, Fate Weaver (summon draw only; prophecy play-for-free not implemented), Indoril Archmage, Studium Headmaster, Elusive Schemer (summon draw + last_gasp generate 0-cost copy to deck), Descendant of Alkosh, Priest of the Moons, Rajhini Highwayman, Riverhold Escort, Baandari Bruiser, Daring Cutpurse, Deshaan Avenger, House Kinsman, Mournhold Traitor, Nimble Ally, Pahmar-raht Renegade, Quin'rawl Burglar, Tazkad the Packmaster, Tenmar Swiftclaw (pilfer +1/+1 + grant_extra_attack; fully fixed), Varanis Courier, Snake Tooth Necklace, Archein Venomtongue, Deathless Draugr, Restless Templar, Enchanted Plate, Dark Harvester, Spider Worker, Slaughterfish, Sadras Agent, Thorn Histmage (summon +1 max magicka + on_max_magicka_gained → +1/+0), Brotherhood Assassin
- Bangkorai Butcher (summon conditional +2/+2 if another Orc), Silvenar Tracker (summon conditional Charge if wounded enemy in lane), Triumphant Jarl (summon conditional draw 2 if more health), Wood Orc Headhunter (summon conditional Charge if another Orc), Golden Saint (summon conditional summon Golden Saint in other lane if more health), Ravenous Hunger (summon conditional Drain if enemy in lane), Pack Wolf (summon Young Wolf in other lane), Green Pact Stalker (summon conditional +2/+2 if wounded enemy in lane), Rift Thane (summon conditional buffs based on health comparison)
- Relentless Raider (rune_break → damage opponent 1), Morthal Executioner (rune_break → +2/+0), Dawnstar Healer (rune_break → heal 3), Ice Spike (on_play → damage opponent 2 + draw 1), Healing Potion (on_play → heal 5), Ransack (on_play → damage opponent 3 + heal 3), Thievery (on_play → damage opponent 3 + heal 3), Drain Life (token; on_play → damage opponent 5 + heal 5), Bone Colossus (summon fill lane with Skeletons + ongoing aura +1/+1 to other friendly Skeletons), Renowned Legate (summon Imperial Grunt + heal per friendly creature), Queen Barenziah (summon → grant Guard to all friendly in lane), Stronghold Eradicator (summon → grant Guard to all enemies in lane)
- Odahviing (summon → deal 4 damage to all enemies both lanes), Skaven Pyromancer (summon → deal 1 damage to all other creatures in lane), Giant Snake (summon → shackle all enemies in lane), Red Bramman (summon → silence + shackle all enemies in lane), Legion Praefect (summon → +1/+1 to all friendly both lanes), Yew Shield (on_play → +1/+1 per enemy in lane on wielder), Corpse Curse (token; on_play → shackle all enemies in lane)
- Trebuchet (start_of_turn → deal 4 damage to random enemy), Reachman Shaman (start_of_turn → +1/+1 to random friendly), Brutal Ashlander (last_gasp → deal 3 damage to random enemy), Haunting Spirit (last_gasp → +3/+3 to random friendly), Alfe Fyr (summon → deal 6 damage to random enemy), Beyte Fyr (summon → deal 6 damage to random enemy), Delte Fyr (summon → deal 6 damage to random enemy), Uupse Fyr (summon → deal 6 damage to random enemy), Cavern Spinner (summon → shackle random enemy), Crown Quartermaster (summon → generate Steel Dagger to hand), Dunmer Nightblade (last_gasp → generate Iron Sword to hand), Divayth Fyr (summon deal 6 damage to random enemy + start_of_turn summon Daughter of Fyr)
- Murkwater Skirmisher (summon → +2/+2 to all friendly Goblins, filtered by subtype), Watch Commander (summon → +1/+2 to all friendly Guards, filtered by keyword), Baron of Tear (summon → +1/+0 and Guard to all friendly Intelligence creatures, filtered by attribute), Eastmarch Crusader (summon → draw if enemy rune destroyed, conditional), Shimmerene Peddler (end_of_turn → draw if played 2 actions), Fireball (on_play → deal 1 damage to all enemies + opponent), Aldmeri Patriot (summon → +1/+1 if action in hand, conditional), Militant Chieftain (ongoing aura +1/+1 to other friendly Orcs + summon draw_from_discard_filtered Orc)
- Fiery Imp (on_attack → damage opponent 2), Staff of Sparks (on_attack → deal 1 damage to all enemies in lane, item), Crystal Tower Crafter (after_action_played → +1/+1), Lillandril Hexmage (after_action_played → damage opponent 1), Artaeum Savant (after_action_played → +1/+1 to random friendly), Grim Champion (on_friendly_death + opponent death → +1/+1 both sides), Necromancer's Amulet (on_friendly_death → heal 1), Alik'r Survivalist (fully fixed: on_equip +1/+1 + summon generate dagger to hand), Dragonstar Rider (on_equip → draw), Whirling Duelist (on_equip → deal 1 damage to all enemies in lane), Craglorn Scavenger (on_play support + activate → +1/+1), General Tullius (on_friendly_death → +1/+1; summon was already wired, now fully fixed)
- Sharpshooter Scout (summon → target choice creature_or_player → deal_damage 1), Valenwood Huntsman (summon → target choice creature_or_player → deal_damage 1), Morkul Gatekeeper (summon → target choice any_creature → modify_stats +2/+0), Savage Ogre (summon → target choice any_creature → modify_stats +5/+0), Earthbone Spinner (summon → target choice another_creature → silence + deal_damage 1), Ash Servant (summon → target choice enemy_creature → deal_damage 2), Shocking Wamasu (summon → target choice enemy_creature → deal_damage 4), Shrieking Harpy (summon → target choice enemy_creature → shackle), Wardcrafter (summon → target choice any_creature → grant_keyword ward), Sunhold Medic (summon → target choice any_creature → modify_stats +0/+2), Loyal Housecarl (summon → target choice any_creature → modify_stats +2/+2 + grant_keyword guard), Cloudrest Illusionist (summon → target choice any_creature → modify_stats -4/0), Mantikora (summon → target choice enemy_creature_in_lane → destroy_creature), Spiteful Dremora (summon → target choice any_creature filtered max_power 2 → destroy_creature), Pillaging Tribune (summon → target choice friendly_creature → grant_keyword drain), Skooma Racketeer (summon → target choice any_creature → grant_keyword lethal), Murkwater Witch (summon → target choice any_creature → modify_stats -1/-1), Leaflurker (summon → target choice any_creature filtered wounded → destroy_creature), Cursed Spectre (summon → target choice another_creature → silence), Shadowfen Priest (summon → multi target choice: another_creature → silence, enemy_support → destroy), Wrothgar Artisan (summon → target choice any_creature → modify_stats +1/+1), Barded Guar (summon → target choice any_creature → grant_keyword guard), Frenzied Witchman (summon → target choice any_creature → modify_stats +2/+1), Dwarven Sphere (summon → target choice enemy_creature → shackle), Vicious Dreugh (summon → target choice enemy_support → destroy_creature), Ravenous Crocodile (summon → target choice friendly_creature → deal_damage 2), Allena Benoch (summon → target choice creature_or_player → deal_damage 1)
- Crushing Blow (on_play → deal_damage 3), Firebolt (on_play → deal_damage 2), Piercing Javelin (on_play → destroy_creature), Suppress (on_play → silence), Cast Out (on_play → unsummon), Arrow in the Knee (on_play → shackle + deal_damage 1), Lightning Bolt (on_play → deal_damage 4), Finish Off (on_play → destroy_creature wounded), Winter's Grasp (on_play → shackle all_enemies), Ice Storm (on_play → deal_damage 3 to all creatures), Belligerent Giant (summon → multi: unsummon creature OR destroy support), Forsworn Guide (summon → unsummon friendly + self +2/+2), Skywatch Vindicator (summon → multi: damage enemy creature OR buff friendly creature), Edict of Azura (on_play → destroy creature/support), Cunning Ally (summon → generate Firebolt to hand conditional), Alik'r Survivalist (fully fixed: on_equip +1/+1 + summon generate dagger to hand)
- Execute (on_play → target choice destroy_creature filtered max_power 2), Imprisoned Deathlord (on_opponent_summon → shackle self), Fearless Northlander (on_damage_taken → self +2/+0), Royal Sage (summon conditional more health → grant_random_keyword all_friendly), Falinesti Reaver (summon → destroy all wounded enemies in lane), Dune Stalker (summon → target choice move friendly creature), Spider Daedra (summon fill lane with Spiderlings + last_gasp destroy all friendly Spiderlings)
- Helgen Squad Leader (on_attack controller → self +1/+0), Abecean Navigator (summon conditional top deck is action → draw), Angry Grahl (summon conditional opponent more cards → +2/+2), Shadow Shift (on_play → move event_target + draw), Dune Smuggler (summon → target choice move friendly creature + on_move → +1/+1 to moved creature), Night Talon Lord (slay → summon the slain creature)
- Orc Clan Captain (ongoing aura +1/+0 to other friendly in lane), Summerset Shieldmage (ongoing aura +0/+1 to other friendly in lane), Divine Fervor (ongoing support aura +1/+1 all friendly), Chieftain's Banner (ongoing support aura +0/+2 to friendly Orcs), Northwind Outpost (ongoing support aura +1/+0 to friendly Strength), Alpha Wolf (ongoing aura +2/+0 to other friendly Wolves), Stormhold Henchman (self aura +2/+2 if 7+ max magicka), Preserver of the Root (self aura +2/+2 + Guard if 7+ max magicka), Rihad Battlemage (self aura +0/+3 + Guard if equipped), Rihad Horseman (self aura +3/+0 + Breakthrough if equipped), Covenant Marauder (self aura +2/+0 if empty hand), Snow Wolf (self aura +2/+0 if most creatures in lane), Niben Bay Cutthroat (self aura +2/+0 if no enemies in lane), Murkwater Goblin (self aura +2/+0 on your turn), Stampeding Mammoth (self aura +2/+0 per other friendly with Breakthrough)
- Gladiator Arena (start_of_turn both players → damage 2), Dread Clannfear (summon → remove_keyword guard from all_enemies), Torval Crook (pilfer → gain_magicka 2), Blackrose Herbalist (start_of_turn → restore_creature_health random_friendly), Goblin Skulk (pilfer → draw_filtered 0-cost), Dagi-raht Mystic (pilfer → draw_filtered support), Auroran Sentry (on_damage target → heal controller by event amount), Feasting Vulture (summon conditional creature_died_this_turn → +2/+2), Shornhelm Champion (on_ward_broken → +3/+3)
- Skirmisher's Elixir (activate → +2/+0 + breakthrough on event_target), Volendrung (activate → +4/+4 + breakthrough on event_target), Elixir of Vigor (activate → +0/+1 on event_target), Elixir of Conflict (activate → +1/+1 on event_target), Healing Hands (on_play → restore_creature_health + modify_stats on event_target), Plea to Kynareth (on_play → restore + modify all_friendly_in_event_lane), War Cry (on_play → modify_stats all_friendly_in_event_lane +2/+0), Disciple of Namira (end_of_turn any_player → draw per friendly_deaths_in_lane_this_turn), Heirloom Greatsword (item_detached → return_to_hand), Elusive Schemer (last_gasp → generate 0-cost copy to deck)
- Blackmail (on_play → copy_from_opponent_deck creature), Orb of Vaermina (activate → copy_from_opponent_deck any), Camoran Scout Leader (summon → summon Scouts in lanes with wounded enemies)
- Dremora Markynaz (summon target choice → double_stats), Cruel Firebloom (on_play target choice → sacrifice friendly + deal_damage 5 random enemy), Brilliant Experiment (on_play target choice → copy_card_to_hand friendly creature), Rapid Shot (on_play → deal_damage 1 + conditional draw if target survives), Ayrenn (summon → draw_from_discard_filtered action; cost reduction not implemented)
- Tenmar Swiftclaw (pilfer +1/+1 + grant_extra_attack), Child of Hircine (slay → grant_extra_attack), Thieves Guild Recruit (summon → draw + post_draw_cost_reduce if 7+), Nahkriin Dragon Priest (summon → draw + post_draw_cost_set 0), Reive Blademaster (on_attack → escalating_damage opponent), Goldbrand (activate → escalating_damage creature), Dres Renegade (grants_immunity shackle), Keeper of Whispers (grants_immunity silence), Stone Throw (on_play target choice → conditional destroy_creature), Imprison (on_play target choice → shackle or destroy based on Willpower creature count), Ahnassi (summon → steal_keywords all_enemies), Mentor's Ring (on_play → copy_keywords_to_friendly), Arenthia Swindler (summon target choice → steal_items)
- Dres Tormentor (on_enemy_shackled → deal_damage 3 to event_target), Green-Touched Spriggan (on_player_healed → modify_stats self power_from_event_amount), Thorn Histmage (on_max_magicka_gained → +1/+0 self)
- Fire Storm (on_play → deal_damage 2 to all_creatures_in_event_lane), Dawn's Wrath (on_play → destroy all_creatures_in_event_lane), Arrow Storm (on_play → destroy all_enemies_in_event_lane filtered max_power 2), Burn and Pillage (on_play → deal_damage 1 * destroyed_enemy_runes to all_enemies_in_event_lane), Dawnbreaker (slay → banish event_subject filtered Undead), Blood Magic Lord (summon + slay → generate Blood Magic Spell to hand), Telvanni Arcanist (last_gasp → generate_random_to_hand action), High Rock Summoner (summon → generate_random_to_hand Atronach), Stronghold Incubator (last_gasp → 2x generate_random_to_hand Dwemer), Ungolim the Listener (summon → 3x generate Brotherhood Assassin to deck), Halls of the Dwemer (on_play → generate Dwarven Spider to hand + aura Dwemer +3/+0), Divayth Fyr (start_of_turn → summon Daughter of Fyr), Militant Chieftain (summon → draw_from_discard_filtered Orc), High King Emeric (summon target choice → deal_damage 2 * friendly_creatures_with_keyword ward), Lucien Lachance (on_friendly_slay → +2/+2 to event_killer), Renowned Legate (summon → summon Grunt + heal per friendly), Miraak Dragonborn (summon target choice → steal enemy creature), Bone Bow (on_play target choice → silence another creature), Mace of Encumbrance (on_play target choice → shackle enemy creature)
- Black Worm Necromancer (summon conditional more_health → summon_random_from_discard), Immolating Blast (on_play → destroy_all_except_random), Farsight Nereid (summon → log reveal), Soulrest Marshal (summon conditional more_health → reduce_next_card_cost 6), Dark Rift (activate → damage opponent 1 + conditional summon Storm Atronach on uses exhausted), Balmora Spymaster (last_gasp → summon_random_from_catalog creature), Wild Beastcaller (summon → summon_random_from_catalog Animal), Merric-at-Aswala (summon → equip_random_item_from_catalog all_friendly_in_lane), Haafingar Marauder (on_enemy_rune_destroyed → equip_random_item_from_catalog event_source), Leafwater Blessing (on_play target choice → +1/+1 + on_player_healed from discard → return_to_hand), Necrom Mastermind (summon → trigger_friendly_last_gasps), Hidden Trail (on_play → change_lane_types shadow + aura +1/+0 all friendly), Master of Arms (summon → equip_items_from_discard 2), Summerset Orrery (activate → shuffle_hand_to_deck_and_draw prophecy)
- Thieves' Den (grants_trigger pilfer +1/+1 to all friendly via synthetic trigger injection), Ayrenn (summon → draw_from_discard_filtered action + cost_reduction_aura actions -1), Sweet Roll (last_gasp → restore_creature_health event_killer), Ancient Giant (stats_from_max_magicka at generation time)
- Two-Moons Contemplation (end_of_turn opponent → conditional no_player_damage_this_turn → sacrifice self + summon Priest of the Moons in each lane)
- Desperate Conjuring (on_play → sacrifice friendly creature + summon_random_by_target_cost +2), Gortwog gro-Nagorm (start_of_turn → summon_random_from_deck creature to random lane), Wrothgar Forge (on_creature_summon once_per_turn → equip_random_item_from_catalog), Moment of Clarity (on_play → generate_random_to_hand; simplified)
- Lesser Ward (on_play → grant_keyword ward), Calm (on_play → modify_stats -4/0), Curse (on_play → modify_stats -1/-1), Malefic Wreath (on_play → modify_stats -2/-2), Swift Strike (on_play → grant_extra_attack), Wisdom of Ancients (on_play → grant_random_keyword all_friendly), Raiding Party (on_play → generate Nord Firebrand x2 to hand), Nest of Vipers (on_play → fill lane with Territorial Vipers), Mummify (on_play → transform into Shriveled Mummy), Intimidate (on_play → remove_keyword guard all_enemies)
- Elixir of Deflection (activate → grant_keyword ward), Elixir of the Defender (activate → grant_keyword guard), Elixir of Light Feet (activate → grant_status cover), Wabbajack (activate → transform_random_from_catalog creature), Imperial Might (end_of_turn → summon Imperial Grunt)
- Markarth Bannerman (on_attack → generate Nord Firebrand x2 to hand), Ice Wraith (start_of_turn → generate Ice Spike to hand), Breton Conjurer (on_ward_broken → summon Frost Atronach), Daggerfall Mage (on_ward_broken → generate Tome of Alteration to hand), Dwarven Centurion (on_damage → generate Dwarven Spider to hand), Murkwater Shaman (start_of_turn → generate Curse to hand), Ageless Automaton (on_attack guard target → +3/+0 + breakthrough), Mages Guild Retreat (end_of_turn 2+ actions → summon random Atronach), Spider Lair (start_of_turn → summon random Spider), Black Marsh Warden (end_of_turn → conditional summon Argonian Recruit or Veteran), Auridon Paladin (after_action_played → grant_keyword drain), Blood Magic Spell (on_play → deal_damage 2 + heal 2)
