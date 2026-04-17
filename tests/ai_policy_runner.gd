extends SceneTree

const HeuristicMatchPolicy = preload("res://src/ai/heuristic_match_policy.gd")
const MatchActionExecutor = preload("res://src/ai/match_action_executor.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")
const VerificationAssertions = preload("res://tests/support/verification_assertions.gd")


func _initialize() -> void:
	var failures: Array = []
	_test_takes_legal_lethal(failures)
	_test_clears_guard_when_required(failures)
	_test_prefers_favorable_trade_over_face(failures)
	_test_develops_curve_in_shadow_lane(failures)
	_test_uses_ring_when_it_unblocks_curve(failures)
	_test_uses_item_to_set_up_lethal(failures)
	_test_plays_support_when_it_is_the_only_profitable_development(failures)
	_test_uses_support_activation_to_remove_a_threat(failures)
	_test_plays_strong_prophecy(failures)
	_test_declines_bad_prophecy(failures)
	_test_ends_turn_when_only_bad_ring_remains(failures)
	_test_prioritizes_ongoing_effect_creature(failures)
	_test_grants_lethal_to_low_power_attacker(failures)
	_test_plays_lethal_granter_before_trading_expensive_creature(failures)
	_test_attacks_face_with_risk_free_low_power_creatures(failures)
	_test_saves_expensive_removal_against_weak_threat_at_full_hp(failures)
	_test_uses_expensive_removal_when_near_lethal(failures)
	_test_ai_silences_rally_threat_when_no_removal(failures)
	_test_ai_silences_ongoing_heal_over_passing(failures)
	_test_ai_prefers_clean_attack_over_silence(failures)
	_test_ai_skips_silence_on_self_harming_creature(failures)
	_test_ai_skips_silence_on_vanilla_creature_with_spent_summon_trigger(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("AI_POLICY_OK")
	quit(0)


func _test_takes_legal_lethal(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["health"] = 4
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "lethal_attacker", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	_assert_policy_pick(match_state, "attack:player_1:player_1_lethal_attacker:target_type=player:player=player_2", failures, "Policy should take lethal when a direct lethal attack is available.")


func _test_clears_guard_when_required(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["health"] = 2
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "guard_breaker", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.summon_creature(opponent, match_state, "guard_wall", "field", 1, 1, ["guard"], 0, {"cost": 0})
	_assert_policy_pick(match_state, "attack:player_1:player_1_guard_breaker:target_type=creature:target=player_2_guard_wall", failures, "Policy should clear required Guard instead of trying to race through it.")


func _test_prefers_favorable_trade_over_face(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "trader", "field", 4, 5, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.summon_creature(opponent, match_state, "face_bait", "field", 4, 4, [], 0, {"cost": 0})
	_assert_policy_pick(match_state, "attack:player_1:player_1_trader:target_type=creature:target=player_2_face_bait", failures, "Policy should prefer a favorable trade over a low-value face attack.")


func _test_develops_curve_in_shadow_lane(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 2, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "curve_two_drop", {"card_type": "creature", "cost": 2, "power": 3, "health": 2})
	ScenarioFixtures.add_hand_card(player, "late_drop", {"card_type": "creature", "cost": 6, "power": 6, "health": 6})
	_assert_policy_pick(match_state, "summon_creature:player_1:player_1_curve_two_drop:lane=shadow:slot=-1", failures, "Policy should spend mana on a curve-appropriate creature and favor protective shadow-lane development.")


func _test_uses_ring_when_it_unblocks_curve(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 1, "first_player_index": 0})
	var first_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	MatchTurnLoop.end_turn(match_state, str(first_player.get("player_id", "")))
	var player: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "ring_curve", {"card_type": "creature", "cost": 3, "power": 4, "health": 4})
	_assert_policy_pick(match_state, "use_ring:player_2:", failures, "Policy should use the Ring when it unlocks a strong immediate follow-up on curve.")


func _test_uses_item_to_set_up_lethal(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["health"] = 3
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "equipped_attacker", "field", 2, 2, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.add_hand_card(player, "power_dagger", {"card_type": "item", "cost": 0, "equip_power_bonus": 1})
	_assert_policy_pick(match_state, "play_item:player_1:player_1_power_dagger:target=player_1_equipped_attacker", failures, "Policy should use an item when shallow lookahead reveals immediate lethal on the next action.")


func _test_plays_support_when_it_is_the_only_profitable_development(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 2, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "totem", {
		"card_type": "support",
		"cost": 2,
		"support_uses": 2,
		"activation_cost": 1,
	})
	_assert_policy_pick(match_state, "play_support:player_1:player_1_totem", failures, "Policy should play a support when it is the only meaningful development available.")


func _test_uses_support_activation_to_remove_a_threat(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	player["health"] = 5
	var guard_target := ScenarioFixtures.summon_creature(player, match_state, "guard_target", "field", 2, 2, [], 0, {"cost": 0})
	player["support"] = [ScenarioFixtures.make_card(str(player.get("player_id", "")), "ballista", {
		"zone": "support",
		"card_type": "support",
		"cost": 0,
		"activation_cost": 1,
		"support_uses": 1,
		"remaining_support_uses": 1,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [{"op": "grant_keyword", "target": "event_target", "keyword_id": "guard"}],
		}],
	})]
	ScenarioFixtures.summon_creature(opponent, match_state, "activation_target", "field", 6, 6, [], 0, {"cost": 0})
	_assert_policy_pick(match_state, "activate_support:player_1:player_1_ballista:target=player_1_guard_target", failures, "Policy should use a support activation when it creates the Guard needed to prevent an immediate loss.")


func _test_plays_strong_prophecy(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var active_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var responding_player: Dictionary = ScenarioFixtures.player(match_state, 1)
	active_player["hand"] = []
	responding_player["hand"] = []
	responding_player["health"] = 8
	ScenarioFixtures.summon_creature(active_player, match_state, "enemy_target", "field", 5, 5, [], 0, {"cost": 0})
	var prophecy := ScenarioFixtures.make_card(str(responding_player.get("player_id", "")), "guard_prophecy", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 4,
		"power": 3,
		"health": 5,
		"keywords": ["guard"],
		"rules_tags": [MatchTiming.RULE_TAG_PROPHECY],
	})
	ScenarioFixtures.set_deck_cards(responding_player, [prophecy])
	MatchTiming.apply_player_damage(match_state, str(responding_player.get("player_id", "")), 6, {"reason": "test_rune_break", "source_controller_player_id": str(active_player.get("player_id", ""))})
	_assert_policy_pick(match_state, "summon_creature:player_2:player_2_guard_prophecy", failures, "Policy should play a strong Prophecy creature when the free Guard body meaningfully stabilizes the board.")


func _test_declines_bad_prophecy(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var active_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var responding_player: Dictionary = ScenarioFixtures.player(match_state, 1)
	active_player["hand"] = []
	responding_player["hand"] = []
	ScenarioFixtures.summon_creature(responding_player, match_state, "fragile_friend", "field", 1, 1, [], 0, {"cost": 0})
	var prophecy := ScenarioFixtures.make_card(str(responding_player.get("player_id", "")), "awkward_prophecy", {
		"zone": "deck",
		"card_type": "action",
		"cost": 4,
		"rules_tags": [MatchTiming.RULE_TAG_PROPHECY],
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"required_zone": "discard",
			"effects": [{"op": "damage", "target": "event_target", "amount": 2}],
		}],
	})
	ScenarioFixtures.set_deck_cards(responding_player, [prophecy])
	MatchTiming.apply_player_damage(match_state, str(responding_player.get("player_id", "")), 6, {"reason": "test_rune_break", "source_controller_player_id": str(active_player.get("player_id", ""))})
	_assert_policy_pick(match_state, "decline_prophecy:player_2:player_2_awkward_prophecy:response=prophecy", failures, "Policy should decline a Prophecy that only produces a bad self-damaging board tradeoff.")


func _test_ends_turn_when_only_bad_ring_remains(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 1, "first_player_index": 0})
	var first_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	MatchTurnLoop.end_turn(match_state, str(first_player.get("player_id", "")))
	var player: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	ScenarioFixtures.add_hand_card(player, "too_expensive", {"card_type": "creature", "cost": 7, "power": 7, "health": 7})
	_assert_policy_pick(match_state, "end_turn:player_2:", failures, "Policy should end the turn when Ring usage does not unlock a worthwhile follow-up.")


func _test_prioritizes_ongoing_effect_creature(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	# A 4/5 attacker that can kill either target.
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "threat_hunter", "field", 4, 5, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	# Vanilla 3/3 — decent stats but no ongoing threat.
	ScenarioFixtures.summon_creature(opponent, match_state, "vanilla_brute", "field", 3, 3, [], 0, {"cost": 0})
	# 0/4 with start_of_turn deal 4 damage — a Trebuchet-style ongoing threat.
	ScenarioFixtures.summon_creature(opponent, match_state, "siege_engine", "field", 0, 4, [], 1, {
		"cost": 4,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_START_OF_TURN,
			"required_zone": "lane",
			"effects": [{"op": "deal_damage", "target": "random_enemy", "amount": 4}],
		}],
	})
	_assert_policy_pick(match_state, "attack:player_1:player_1_threat_hunter:target_type=creature:target=player_2_siege_engine", failures, "Policy should prioritize a 0-power creature with a dangerous ongoing effect over a vanilla creature with higher stats.")


func _test_grants_lethal_to_low_power_attacker(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	# Low-power creature that can attack this turn — ideal Lethal recipient.
	var small_attacker := ScenarioFixtures.summon_creature(player, match_state, "small_attacker", "field", 1, 3, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(small_attacker, match_state)
	# High-power creature that just entered lane — already kills most things, can't attack yet.
	ScenarioFixtures.summon_creature(player, match_state, "big_creature", "field", 6, 6, [], 0, {"cost": 0})
	# Support that grants Lethal to a friendly creature.
	player["support"] = [ScenarioFixtures.make_card(str(player.get("player_id", "")), "lethal_totem", {
		"zone": "support",
		"card_type": "support",
		"cost": 0,
		"activation_cost": 1,
		"support_uses": 1,
		"remaining_support_uses": 1,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [{"op": "grant_keyword", "target": "event_target", "keyword_id": "lethal"}],
		}],
	})]
	_assert_policy_pick(match_state, "activate_support:player_1:player_1_lethal_totem:target=player_1_small_attacker", failures, "Policy should grant Lethal to a low-power creature that can attack rather than a high-power creature that cannot.")


func _test_plays_lethal_granter_before_trading_expensive_creature(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	# Low-power attacker ready to attack — becomes deadly with Lethal.
	var small_attacker := ScenarioFixtures.summon_creature(player, match_state, "small_attacker", "field", 1, 3, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(small_attacker, match_state)
	# Expensive 4/4 also ready — can trade into the Guard but wastefully.
	var big_creature := ScenarioFixtures.summon_creature(player, match_state, "big_creature", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(big_creature, match_state)
	# Enemy Guard with high health — neither creature kills it efficiently without Lethal.
	ScenarioFixtures.summon_creature(opponent, match_state, "enemy_guard", "field", 5, 5, ["guard"], 0, {"cost": 0})
	# Support that grants Lethal — costs 1 magicka to activate.
	player["support"] = [ScenarioFixtures.make_card(str(player.get("player_id", "")), "lethal_totem", {
		"zone": "support",
		"card_type": "support",
		"cost": 0,
		"activation_cost": 1,
		"support_uses": 1,
		"remaining_support_uses": 1,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [{"op": "grant_keyword", "target": "event_target", "keyword_id": "lethal"}],
		}],
	})]
	# The AI should activate the support (granting Lethal to the small attacker)
	# rather than trading the 4/4 into the Guard. The interrupt-aware lookahead
	# sees through "activate → grant Lethal → attack with Lethal creature".
	_assert_policy_pick(match_state, "activate_support:player_1:player_1_lethal_totem:target=player_1_small_attacker", failures, "Policy should use a Lethal-granting support on a cheap attacker rather than trading an expensive creature into a Guard.")


func _test_attacks_face_with_risk_free_low_power_creatures(failures: Array) -> void:
	# AI has two 1-power creatures in field lane, opponent at 30 HP with no guards.
	# The AI should attack face for risk-free damage rather than end turn.
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 12, "first_player_index": 0})
	var player_1: Dictionary = ScenarioFixtures.player(match_state, 0)
	var player_2: Dictionary = ScenarioFixtures.player(match_state, 1)
	player_1["hand"] = []
	player_2["hand"] = []
	player_1["health"] = 30
	player_2["health"] = 30
	ScenarioFixtures.summon_creature(player_1, match_state, "big_creature", "field", 6, 3, [], 0, {"cost": 0})
	var attacker_a := ScenarioFixtures.summon_creature(player_2, match_state, "small_a", "field", 1, 2, [], 0, {"cost": 0})
	var attacker_b := ScenarioFixtures.summon_creature(player_2, match_state, "small_b", "field", 1, 4, [], 0, {"cost": 0})
	MatchTurnLoop.end_turn(match_state, str(player_1.get("player_id", "")))
	ScenarioFixtures.ready_for_attack(attacker_a, match_state)
	ScenarioFixtures.ready_for_attack(attacker_b, match_state)
	_assert_policy_pick(match_state, "attack:", failures, "AI should attack face with risk-free 1-power creatures, not end turn.")


# Regression: AI used a 5-cost Piercing Javelin to destroy a 1/1 Abomination
# while at full (30) HP. Burning expensive removal on a near-worthless threat
# when safe is a classic beginner misplay — the efficiency adjustment in
# _tactical_bonus should overwhelm the flat kill/threat-reduction bonuses.
func _test_saves_expensive_removal_against_weak_threat_at_full_hp(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["hand"] = []
	player["health"] = 30
	ScenarioFixtures.add_hand_card(player, "piercing_javelin", {
		"card_type": "action",
		"cost": 5,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [{"op": "destroy_creature", "target": "event_target"}],
		}],
	})
	# Give the AI an on-curve creature to play instead.
	ScenarioFixtures.add_hand_card(player, "curve_body", {"card_type": "creature", "cost": 5, "power": 5, "health": 5})
	# Opponent: one feeble 1/1 — destroying it with a 5-cost spell is terrible value.
	ScenarioFixtures.summon_creature(opponent, match_state, "weakling", "field", 1, 1, [], 0, {"cost": 0})
	var choice := HeuristicMatchPolicy.choose_action(match_state)
	var action: Dictionary = choice.get("chosen_action", {})
	var action_id := str(action.get("id", ""))
	var probe := HeuristicMatchPolicy.describe_choice(choice)
	VerificationAssertions.assert_true(
		not action_id.begins_with("play_action:player_1:player_1_piercing_javelin"),
		"AI at full HP should not spend a 5-cost Piercing Javelin on a 1/1.\nAction: %s\n%s" % [action_id, probe],
		failures
	)


# Counterpart: at very low HP, a 1/1 still represents lethal threat, so the
# efficiency penalty should collapse to ~0 and the AI should still be willing
# to remove it when it has no better defensive play.
func _test_uses_expensive_removal_when_near_lethal(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 5, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["hand"] = []
	player["health"] = 1
	ScenarioFixtures.add_hand_card(player, "piercing_javelin", {
		"card_type": "action",
		"cost": 5,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [{"op": "destroy_creature", "target": "event_target"}],
		}],
	})
	# Opponent has a ready attacker that will kill us next turn.
	var attacker := ScenarioFixtures.summon_creature(opponent, match_state, "lethal_threat", "field", 1, 1, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	_assert_policy_pick(match_state, "play_action:player_1:player_1_piercing_javelin", failures, "AI at 1 HP should remove the 1/1 lethal threat even with overkill removal.")


# Regression: AI held silences but no other playable cards, and declined to silence
# any of three Rally creatures that were continuously buffing the enemy board.
# The compounding value of a Rally threat should make silence beat passing.
func _test_ai_silences_rally_threat_when_no_removal(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var first_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	MatchTurnLoop.end_turn(match_state, str(first_player.get("player_id", "")))
	var player: Dictionary = ScenarioFixtures.player(match_state, 1)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	opponent["hand"] = []
	# Three enemy Rally creatures — their compounding buffs are the main threat.
	ScenarioFixtures.summon_creature(opponent, match_state, "rally_a", "field", 2, 2, ["rally"], 0, {"cost": 0})
	ScenarioFixtures.summon_creature(opponent, match_state, "rally_b", "field", 2, 2, ["rally"], 1, {"cost": 0})
	ScenarioFixtures.summon_creature(opponent, match_state, "rally_c", "shadow", 2, 2, ["rally"], 0, {"cost": 0})
	# AI has only a cheap silence — nothing else to do with its turn.
	ScenarioFixtures.add_hand_card(player, "suppress", {
		"card_type": "action",
		"cost": 0,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [{"op": "silence", "target": "event_target"}],
		}],
	})
	_assert_policy_pick(match_state, "play_action:player_2:player_2_suppress", failures, "AI should silence a Rally threat rather than pass when it has no other playable actions.")


# Regression: 10/10 with a start_of_turn heal ongoing effect was ignored by the
# AI despite having silence available. The per-turn heal value, multiplied by
# the creature's durability, should tip silence above passing.
func _test_ai_silences_ongoing_heal_over_passing(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var first_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	MatchTurnLoop.end_turn(match_state, str(first_player.get("player_id", "")))
	var player: Dictionary = ScenarioFixtures.player(match_state, 1)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	opponent["hand"] = []
	opponent["health"] = 15
	# 10/10 Regenerate with a powerful start-of-turn heal — silencing it removes
	# both the ongoing and the Regenerate shield. Cost 0 so the test doesn't
	# depend on opponent magicka state after a turn swap.
	ScenarioFixtures.summon_creature(opponent, match_state, "healing_titan", "field", 10, 10, ["regenerate"], 0, {
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_START_OF_TURN,
			"required_zone": "lane",
			"effects": [{"op": "heal", "target_player": "controller", "amount": 4}],
		}],
	})
	ScenarioFixtures.add_hand_card(player, "suppress", {
		"card_type": "action",
		"cost": 0,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [{"op": "silence", "target": "event_target"}],
		}],
	})
	_assert_policy_pick(match_state, "play_action:player_2:player_2_suppress", failures, "AI should silence a durable ongoing-heal threat rather than pass when it has no better option.")


# Regression: a silence in hand should not preempt a clean kill. If the AI can
# attack the threat and destroy it cleanly, removal outscores silence because
# attack strips full creature value (stats + keywords + ongoing).
func _test_ai_prefers_clean_attack_over_silence(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["hand"] = []
	# Friendly 5/5 ready to attack — can cleanly kill a 2/2 rally threat without dying.
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "clean_killer", "field", 5, 5, [], 0, {"cost": 0})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	ScenarioFixtures.summon_creature(opponent, match_state, "rally_threat", "field", 2, 2, ["rally"], 0, {"cost": 0})
	# Silence also available — should be passed over in favour of the clean kill.
	ScenarioFixtures.add_hand_card(player, "suppress", {
		"card_type": "action",
		"cost": 0,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [{"op": "silence", "target": "event_target"}],
		}],
	})
	_assert_policy_pick(match_state, "attack:player_1:player_1_clean_killer:target_type=creature:target=player_2_rally_threat", failures, "AI should attack for a clean kill instead of silencing when both options exist.")


# Regression: AI silenced Encumbered Explorer (Shackle self after attack) while
# it was shackled, removing both the shackle status and the self-harm trigger.
# Silence should not look like a gain when the only enemy trigger harms its own
# controller — silencing the creature makes it strictly better for the enemy.
func _test_ai_skips_silence_on_self_harming_creature(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var player: Dictionary = ScenarioFixtures.player(match_state, 0)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 1)
	player["hand"] = []
	opponent["hand"] = []
	# Enemy 2/3 whose only triggered ability shackles itself after attacking —
	# silencing would free it from that self-imposed downside.
	ScenarioFixtures.summon_creature(opponent, match_state, "self_shackler", "field", 2, 3, [], 0, {
		"cost": 0,
		"triggered_abilities": [{
			"family": "on_attack",
			"effects": [{"op": "shackle", "target": "self"}],
		}],
	})
	ScenarioFixtures.add_hand_card(player, "suppress", {
		"card_type": "action",
		"cost": 0,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [{"op": "silence", "target": "event_target"}],
		}],
	})
	var choice := HeuristicMatchPolicy.choose_action(match_state)
	var action: Dictionary = choice.get("chosen_action", {})
	var action_id := str(action.get("id", ""))
	var probe := HeuristicMatchPolicy.describe_choice(choice)
	VerificationAssertions.assert_true(
		not action_id.begins_with("play_action:player_1:player_1_suppress"),
		"AI should not silence a creature whose only trigger harms its own controller.\nAction: %s\n%s" % [action_id, probe],
		failures
	)


# Regression: the AI silenced Soulrest Marshal on the following turn even
# though its only effect was a summon-only cost reduction that had already
# fired and been cleared at end of turn. Silencing a vanilla 4/4 whose sole
# triggered ability has already resolved wastes a card for near-zero benefit.
func _test_ai_skips_silence_on_vanilla_creature_with_spent_summon_trigger(failures: Array) -> void:
	var match_state := ScenarioFixtures.create_started_match({"set_all_magicka": 3, "first_player_index": 0})
	var first_player: Dictionary = ScenarioFixtures.player(match_state, 0)
	MatchTurnLoop.end_turn(match_state, str(first_player.get("player_id", "")))
	var player: Dictionary = ScenarioFixtures.player(match_state, 1)
	var opponent: Dictionary = ScenarioFixtures.player(match_state, 0)
	player["hand"] = []
	opponent["hand"] = []
	# Vanilla 4/4 — summon trigger already resolved on a prior turn, so only
	# its base stats remain. Nothing meaningful for silence to strip.
	ScenarioFixtures.summon_creature(opponent, match_state, "marshal", "field", 4, 4, [], 0, {"cost": 0})
	ScenarioFixtures.add_hand_card(player, "suppress", {
		"card_type": "action",
		"cost": 1,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [{"op": "silence", "target": "event_target"}],
		}],
	})
	var choice := HeuristicMatchPolicy.choose_action(match_state)
	var action: Dictionary = choice.get("chosen_action", {})
	var action_id := str(action.get("id", ""))
	var probe := HeuristicMatchPolicy.describe_choice(choice)
	VerificationAssertions.assert_true(
		not action_id.begins_with("play_action:player_2:player_2_suppress"),
		"AI should not waste a silence on a vanilla creature with no ongoing value.\nAction: %s\n%s" % [action_id, probe],
		failures
	)


func _assert_policy_pick(match_state: Dictionary, expected_prefix: String, failures: Array, message: String) -> void:
	var choice := HeuristicMatchPolicy.choose_action(match_state)
	var probe := HeuristicMatchPolicy.describe_choice(choice)
	VerificationAssertions.assert_true(bool(choice.get("is_valid", false)), "%s\nPolicy returned an invalid choice.\n%s" % [message, probe], failures)
	var action: Dictionary = choice.get("chosen_action", {})
	var action_id := str(action.get("id", ""))
	VerificationAssertions.assert_true(action_id.begins_with(expected_prefix), "%s\nExpected prefix: %s\nActual: %s\n%s" % [message, expected_prefix, action_id, probe], failures)
	var execution := MatchActionExecutor.clone_and_execute(match_state, action)
	VerificationAssertions.assert_true(bool(execution.get("is_valid", false)), "%s\nChosen action should remain executable after selection: %s\n%s" % [message, action_id, probe], failures)
