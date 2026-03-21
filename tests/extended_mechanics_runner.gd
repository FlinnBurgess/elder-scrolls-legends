extends SceneTree

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return
	print("EXTENDED_MECHANICS_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_assemble_pack() and
		_test_beast_form_pack() and
		_test_veteran_hook() and
		_test_action_pack_matrix() and
		_test_empower_and_expertise_hooks() and
		_test_invade_and_shout_pack() and
		_test_treasure_hunt_and_consume_pack() and
		_test_wax_and_wane_pack()
	)


func _test_assemble_pack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var assemble_creature := ScenarioFixtures.add_hand_card(player, "assemble_leader", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["factotum"],
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "lane",
			"effects": [{"op": "assemble", "choices": [{"power": 1, "health": 1}]}],
		}],
	})
	var hand_factotum := ScenarioFixtures.add_hand_card(player, "hand_factotum", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["factotum"],
	})
	var deck_factotum := ScenarioFixtures.make_card(str(player.get("player_id", "")), "deck_factotum", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
		"subtypes": ["factotum"],
	})
	player["deck"].append(deck_factotum)
	var summon_result := LaneRules.summon_from_hand(match_state, str(player.get("player_id", "")), str(assemble_creature.get("instance_id", "")), "field", {"assemble_choice": 0})
	return (
		_assert(bool(summon_result.get("is_valid", false)), "Assemble creature should be playable through the normal summon path.") and
		_assert(EvergreenRules.get_power(assemble_creature) == 2 and EvergreenRules.get_health(assemble_creature) == 2, "Assemble should buff the played Factotum.") and
		_assert(EvergreenRules.get_power(hand_factotum) == 2 and EvergreenRules.get_health(hand_factotum) == 2, "Assemble should buff Factotums in hand.") and
		_assert(EvergreenRules.get_power(deck_factotum) == 2 and EvergreenRules.get_health(deck_factotum) == 2, "Assemble should buff Factotums in deck.")
	)


func _test_beast_form_pack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var beast := ScenarioFixtures.summon_creature(player, match_state, "beast_former", "field", 2, 2, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"match_role": "opponent_player",
			"required_zone": "lane",
			"effects": [{
				"op": "transform",
				"target": "self",
				"card_template": {"definition_id": "werewolf_form", "name": "Werewolf Form", "card_type": "creature", "power": 4, "health": 4},
			}],
		}],
	})
	var damage_result := MatchTiming.apply_player_damage(match_state, str(opponent.get("player_id", "")), 6, {
		"source_instance_id": str(beast.get("instance_id", "")),
		"source_controller_player_id": str(player.get("player_id", "")),
	})
	MatchTiming.publish_events(match_state, damage_result.get("events", []))
	return (
		_assert(str(beast.get("definition_id", "")) == "werewolf_form", "Breaking an enemy rune should transform Beast Form creatures.") and
		_assert(EvergreenRules.get_power(beast) == 4 and EvergreenRules.get_health(beast) == 4, "Transformed Beast Form creature should take on the werewolf template stats.")
	)


func _test_veteran_hook() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var veteran := ScenarioFixtures.summon_creature(player, match_state, "veteran_scout", "field", 3, 4, [EvergreenRules.KEYWORD_CHARGE], -1, {
		"triggered_abilities": [{
			"event_type": "attack_resolved",
			"match_role": "source",
			"required_zone": "lane",
			"require_attacker_survived": true,
			"once_per_instance": true,
			"effects": [{"op": "modify_stats", "target": "self", "power": 2, "health": 0}],
		}],
	})
	var first_target := _summon_generated_creature(match_state, str(opponent.get("player_id", "")), "first_dummy", "field", 1, 1)
	var first_attack := MatchCombat.resolve_attack(match_state, str(player.get("player_id", "")), str(veteran.get("instance_id", "")), {"type": "creature", "instance_id": str(first_target.get("instance_id", ""))})
	if not (
		_assert(bool(first_attack.get("is_valid", false)), "Veteran fixture attack should resolve: %s" % [str(first_attack.get("errors", []))]) and
		_assert(EvergreenRules.get_power(veteran) == 5, "Veteran hook should fire after the creature survives its first attack.")
	):
		return false
	MatchTurnLoop.end_turn(match_state, str(player.get("player_id", "")))
	MatchTurnLoop.end_turn(match_state, str(opponent.get("player_id", "")))
	var second_target := _summon_generated_creature(match_state, str(opponent.get("player_id", "")), "second_dummy", "field", 1, 1)
	var second_attack := MatchCombat.resolve_attack(match_state, str(player.get("player_id", "")), str(veteran.get("instance_id", "")), {"type": "creature", "instance_id": str(second_target.get("instance_id", ""))})
	return (
		_assert(bool(second_attack.get("is_valid", false)), "Veteran should still be able to attack on later turns.") and
		_assert(EvergreenRules.get_power(veteran) == 5, "Veteran hook should remain once-per-instance after the first successful attack.")
	)


func _test_action_pack_matrix() -> bool:
	return (
		_test_double_card_choice() and
		_test_plot_hook() and
		_test_exalt_action_bonus() and
		_test_betray_replay() and
		_test_mushroom_tower_grants_betray() and
		_test_betray_no_creatures_skips() and
		_test_betray_targeted_skip_no_replay_target()
	)


func _test_double_card_choice() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var double_card := ScenarioFixtures.add_hand_card(player, "double_spell", {
		"card_type": "action",
		"cost": 0,
		"double_card_options": [
			{"id": "spark_half", "card_template": {"definition_id": "spark_half", "name": "Spark", "card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}]}},
			{"id": "blast_half", "card_template": {"definition_id": "blast_half", "name": "Blast", "card_type": "action", "cost": 0, "triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 3}]}]}},
		],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(double_card.get("instance_id", "")), {"double_card_choice": "blast_half", "target_player_id": str(opponent.get("player_id", ""))})
	return (
		_assert(bool(play_result.get("is_valid", false)), "Double card should resolve through the generic action play path.") and
		_assert(str(double_card.get("definition_id", "")) == "blast_half", "Double card should adopt the chosen half before resolving.") and
		_assert(int(opponent.get("health", 0)) == 27, "Chosen double-card half should drive the resolved effect payload (health=%d)." % int(opponent.get("health", 0)))
	)


func _test_plot_hook() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var filler := ScenarioFixtures.add_hand_card(player, "filler_action", {"card_type": "action", "cost": 0})
	var plot_card := ScenarioFixtures.add_hand_card(player, "plot_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"event_type": MatchTiming.EVENT_CARD_PLAYED,
			"match_role": "source",
			"required_zone": "discard",
			"min_cards_played_this_turn": 2,
			"effects": [{"op": "damage", "target_player": "target_player", "amount": 2}],
		}],
	})
	var filler_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(filler.get("instance_id", "")))
	var plot_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(plot_card.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	return (
		_assert(bool(filler_play.get("is_valid", false)) and bool(plot_play.get("is_valid", false)), "Plot fixture actions should be playable.") and
		_assert(int(opponent.get("health", 0)) == 28, "Plot should trigger only when the card is the second play of the turn.")
	)


func _test_exalt_action_bonus() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var exalt_card := ScenarioFixtures.add_hand_card(player, "exalt_action", {
		"card_type": "action",
		"cost": 2,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "damage", "target_player": "target_player", "amount": 2, "required_source_status": EvergreenRules.STATUS_EXALTED}],
		}],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(exalt_card.get("instance_id", "")), {"exalt": true, "target_player_id": str(opponent.get("player_id", ""))})
	return (
		_assert(bool(play_result.get("is_valid", false)), "Exalt action should be playable through the generic action path.") and
		_assert(int(player.get("current_magicka", 0)) == 7, "Exalt should charge one extra magicka on top of the base action cost.") and
		_assert(int(opponent.get("health", 0)) == 28, "Exalted action should unlock its exalt-gated bonus effect.")
	)


func _test_betray_replay() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var fodder := ScenarioFixtures.summon_creature(player, match_state, "betray_fodder", "field", 1, 1)
	var betray_card := ScenarioFixtures.add_hand_card(player, "betray_action", {
		"card_type": "action",
		"cost": 0,
		"keywords": ["betray"],
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [
				{"op": "damage", "target_player": "target_player", "amount": 1},
			],
		}],
	})
	var player_id := str(player.get("player_id", ""))
	var opponent_id := str(opponent.get("player_id", ""))
	# Play the action normally (first resolution)
	var play_result := MatchTiming.play_action_from_hand(match_state, player_id, str(betray_card.get("instance_id", "")), {
		"target_player_id": opponent_id,
	})
	if not _assert(bool(play_result.get("is_valid", false)), "Betray action should be playable."):
		return false
	if not _assert(int(opponent.get("health", 0)) == 29, "First betray play should deal 1 damage (health=%d)." % int(opponent.get("health", 0))):
		return false
	# Verify betray eligibility
	if not _assert(ExtendedMechanicPacks.action_has_betray(match_state, player_id, betray_card), "Card with betray keyword should be detected as betray."):
		return false
	# Execute the betray replay as a separate step
	var replay_result := MatchTiming.execute_betray_replay(match_state, player_id, str(betray_card.get("instance_id", "")), str(fodder.get("instance_id", "")), {
		"target_player_id": opponent_id,
	})
	return (
		_assert(bool(replay_result.get("is_valid", false)), "Betray replay should succeed.") and
		_assert(int(opponent.get("health", 0)) == 28, "Betray replay should deal 1 more damage (health=%d)." % int(opponent.get("health", 0))) and
		_assert(_contains_instance(player.get("discard", []), str(fodder.get("instance_id", ""))), "Betray should sacrifice the chosen creature to discard.")
	)


func _test_mushroom_tower_grants_betray() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Create a non-betray action
	var action_card := ScenarioFixtures.make_card(player_id, "plain_action", {
		"card_type": "action",
		"cost": 0,
	})
	# Without Mushroom Tower — should not have betray
	if not _assert(not ExtendedMechanicPacks.action_has_betray(match_state, player_id, action_card), "Action without betray keyword should not have betray."):
		return false
	# Place Mushroom Tower in support zone
	var tower := ScenarioFixtures.make_card(player_id, "mushroom_tower", {
		"card_type": "support",
		"definition_id": "hom_end_mushroom_tower",
		"support_uses": 0,
	})
	tower["zone"] = "support"
	player["support"].append(tower)
	# With Mushroom Tower — should have betray
	return _assert(ExtendedMechanicPacks.action_has_betray(match_state, player_id, action_card), "Mushroom Tower should grant betray to all actions.")


func _test_betray_no_creatures_skips() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	var candidates := ExtendedMechanicPacks.get_betray_sacrifice_candidates(match_state, player_id)
	return _assert(candidates.is_empty(), "Should have no sacrifice candidates when no friendly creatures in lanes.")


func _test_betray_targeted_skip_no_replay_target() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_id := str(player.get("player_id", ""))
	# Summon a single friendly creature
	var lone_creature := ScenarioFixtures.summon_creature(player, match_state, "lone_creature", "field", 2, 2)
	# Create a targeted action that targets friendly creatures
	var targeted_action := ScenarioFixtures.make_card(player_id, "friendly_target_action", {
		"card_type": "action",
		"cost": 0,
		"keywords": ["betray"],
		"action_target_mode": "friendly_creature",
	})
	# Sacrificing the only creature leaves no valid replay target
	var has_target := ExtendedMechanicPacks.betray_replay_has_valid_target(match_state, player_id, targeted_action, str(lone_creature.get("instance_id", "")))
	return _assert(not has_target, "Should have no valid replay target when sacrificing the only friendly creature for a friendly_creature targeted action.")


func _test_empower_and_expertise_hooks() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var expert := ScenarioFixtures.summon_creature(player, match_state, "expert", "field", 2, 2, [], -1, {
		"triggered_abilities": [{
			"event_type": MatchTiming.EVENT_TURN_ENDING,
			"match_role": "controller",
			"required_zone": "lane",
			"min_noncreature_plays_this_turn": 1,
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}],
		}],
	})
	var ping := ScenarioFixtures.add_hand_card(player, "ping_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 1}]}],
	})
	var empower := ScenarioFixtures.add_hand_card(player, "empower_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "empower_damage", "target_player": "target_player", "amount": 1, "amount_per_damage": 1}]}],
	})
	var ping_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(ping.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	var empower_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(empower.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	MatchTurnLoop.end_turn(match_state, str(player.get("player_id", "")))
	return (
		_assert(bool(ping_play.get("is_valid", false)) and bool(empower_play.get("is_valid", false)), "Empower fixture actions should both be playable.") and
		_assert(int(opponent.get("health", 0)) == 27, "Empower should scale from damage already dealt to the opponent this turn.") and
		_assert(EvergreenRules.get_power(expert) == 3 and EvergreenRules.get_health(expert) == 3, "Expertise hook should trigger at end of turn after a non-creature play.")
	)


func _test_invade_and_shout_pack() -> bool:
	return _test_invade_gate_progression() and _test_shout_upgrades()


func _test_invade_gate_progression() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var invade_one := ScenarioFixtures.add_hand_card(player, "invade_one", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
	})
	var invade_two := ScenarioFixtures.add_hand_card(player, "invade_two", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "invade"}]}],
	})
	var first_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(invade_one.get("instance_id", "")))
	var gate := _find_lane_card(match_state, "shadow", str(player.get("player_id", "")), "generated_oblivion_gate")
	var first_daedra := ScenarioFixtures.summon_creature(player, match_state, "first_daedra", "field", 1, 1, [], -1, {"subtypes": ["daedra"]})
	var second_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(invade_two.get("instance_id", "")))
	var second_daedra := ScenarioFixtures.summon_creature(player, match_state, "second_daedra", "field", 1, 1, [], -1, {"subtypes": ["daedra"]})
	return (
		_assert(bool(first_play.get("is_valid", false)) and bool(second_play.get("is_valid", false)), "Invade actions should be playable.") and
		_assert(not gate.is_empty() and int(gate.get("gate_level", 0)) == 2 and int(gate.get("health", 0)) == 6, "Repeated Invade plays should create and then upgrade the Oblivion Gate (gate=%s)." % [str(gate)]) and
		_assert(int(EvergreenRules.get_health(first_daedra)) == 2, "Level 1 Oblivion Gate should grant +0/+1 to summoned Daedra.") and
		_assert(int(EvergreenRules.get_power(second_daedra)) == 2 and int(EvergreenRules.get_health(second_daedra)) == 2, "Higher-level Oblivion Gates should increase summoned Daedra buffs.") and
		_assert(bool(gate.get("cannot_attack", false)), "Generated Oblivion Gates should be unable to attack.")
	)


func _test_shout_upgrades() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var shout_levels := [
		{"definition_id": "voice_level_1", "name": "Word I", "card_type": "action", "cost": 0, "shout_chain_id": "voice", "shout_level": 1},
		{"definition_id": "voice_level_2", "name": "Word II", "card_type": "action", "cost": 0, "shout_chain_id": "voice", "shout_level": 2},
		{"definition_id": "voice_level_3", "name": "Word III", "card_type": "action", "cost": 0, "shout_chain_id": "voice", "shout_level": 3},
	]
	var first_shout := ScenarioFixtures.add_hand_card(player, "shout_a", {
		"card_type": "action",
		"cost": 0,
		"definition_id": "voice_level_1",
		"shout_chain_id": "voice",
		"shout_level": 1,
		"shout_levels": shout_levels,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "upgrade_shout"}]}],
	})
	var second_shout := ScenarioFixtures.add_hand_card(player, "shout_b", {
		"card_type": "action",
		"cost": 0,
		"definition_id": "voice_level_1",
		"shout_chain_id": "voice",
		"shout_level": 1,
		"shout_levels": shout_levels,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "upgrade_shout"}]}],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(first_shout.get("instance_id", "")))
	return (
		_assert(bool(play_result.get("is_valid", false)), "Shout card should be playable.") and
		_assert(str(second_shout.get("definition_id", "")) == "voice_level_2", "Playing a Shout should upgrade the remaining copies in hand, deck, and discard.")
	)


func _test_treasure_hunt_and_consume_pack() -> bool:
	return _test_treasure_hunt_completion() and _test_consume_reuse()


func _test_treasure_hunt_completion() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var treasure_hunter := ScenarioFixtures.summon_creature(player, match_state, "treasure_hunter", "field", 2, 2, [], -1, {
		"triggered_abilities": [
			{"event_type": MatchTiming.EVENT_CARD_DRAWN, "match_role": "controller", "required_zone": "lane", "effects": [{"op": "track_treasure_hunt", "requirements": [{"card_type": "item"}, {"card_type": "action"}]}]},
			{"event_type": "treasure_hunt_completed", "match_role": "source", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 2, "health": 2}]},
		],
	})
	player["deck"] = [
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "filler", {"zone": "deck", "card_type": "creature"}),
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "draw_action", {"zone": "deck", "card_type": "action"}),
		ScenarioFixtures.make_card(str(player.get("player_id", "")), "draw_item", {"zone": "deck", "card_type": "item"}),
	]
	var draw_result := MatchTiming.draw_cards(match_state, str(player.get("player_id", "")), 2, {"reason": "treasure_test", "source_controller_player_id": str(player.get("player_id", ""))})
	MatchTiming.publish_events(match_state, draw_result.get("events", []))
	return _assert(EvergreenRules.get_power(treasure_hunter) == 4 and EvergreenRules.get_health(treasure_hunter) == 4, "Treasure Hunt should track matching draws and fire its completion trigger once all requirements are found.")


func _test_consume_reuse() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var consumer := ScenarioFixtures.summon_creature(player, match_state, "consumer", "field", 2, 2, [], -1, {
		"triggered_abilities": [{"event_type": "test_consume", "match_role": "source", "required_zone": "lane", "effects": [{"op": "consume", "consumer_target": "self", "target": "event_target"}]}],
	})
	var meal := ScenarioFixtures.summon_creature(player, match_state, "meal", "field", 1, 3)
	MatchMutations.discard_card(match_state, str(meal.get("instance_id", "")), {"reason": "test_consume_setup"})
	MatchTiming.publish_events(match_state, [{"event_type": "test_consume", "player_id": str(player.get("player_id", "")), "source_instance_id": str(consumer.get("instance_id", "")), "target_instance_id": str(meal.get("instance_id", ""))}])
	return (
		_assert(EvergreenRules.get_power(consumer) == 3 and EvergreenRules.get_health(consumer) == 5, "Extended mechanic packs should continue to reuse the shared Consume mutation pipeline.") and
		_assert(_contains_instance(player.get("discard", []), str(meal.get("instance_id", ""))), "Consume should continue routing eaten cards through the shared destination-zone handling.")
	)


func _test_wax_and_wane_pack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	var wax_card := ScenarioFixtures.add_hand_card(player, "wax_spell", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [
				{"op": "damage", "target_player": "target_player", "amount": 1, "required_wax_wane_phase": "wax"},
				{"op": "damage", "target_player": "target_player", "amount": 2, "required_wax_wane_phase": "wane"},
			],
		}],
	})
	var wane_card := ScenarioFixtures.add_hand_card(player, "wane_spell", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [
				{"op": "damage", "target_player": "target_player", "amount": 1, "required_wax_wane_phase": "wax"},
				{"op": "damage", "target_player": "target_player", "amount": 2, "required_wax_wane_phase": "wane"},
			],
		}],
	})
	var wax_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(wax_card.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	MatchTurnLoop.end_turn(match_state, str(player.get("player_id", "")))
	MatchTurnLoop.end_turn(match_state, str(opponent.get("player_id", "")))
	var wane_play := MatchTiming.play_action_from_hand(match_state, str(player.get("player_id", "")), str(wane_card.get("instance_id", "")), {"target_player_id": str(opponent.get("player_id", ""))})
	return (
		_assert(bool(wax_play.get("is_valid", false)) and bool(wane_play.get("is_valid", false)), "Wax/Wane fixture actions should be playable across turns.") and
		_assert(int(opponent.get("health", 0)) == 27, "Wax/Wane should swap between its two effect packages at the end of the controller's turn.")
	)


func _build_started_match() -> Dictionary:
	return ScenarioFixtures.create_started_match({"set_all_magicka": 10, "first_player_index": 0})


func _summon_generated_creature(match_state: Dictionary, player_id: String, label: String, lane_id: String, power: int, health: int) -> Dictionary:
	var card := ScenarioFixtures.make_card(player_id, label, {"zone": MatchMutations.ZONE_GENERATED, "card_type": "creature", "cost": 0, "power": power, "health": health})
	var summon_result := MatchMutations.summon_card_to_lane(match_state, player_id, card, lane_id, {"source_zone": MatchMutations.ZONE_GENERATED})
	return summon_result.get("card", {})


func _find_lane_card(match_state: Dictionary, lane_id: String, player_id: String, definition_id: String) -> Dictionary:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == definition_id:
				return card
	return {}


func _contains_instance(cards: Array, instance_id: String) -> bool:
	for card in cards:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
			return true
	return false


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false