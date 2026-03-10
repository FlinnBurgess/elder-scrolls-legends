extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("TURN_AND_MAGICKA_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_first_turn_start_draws_and_refreshes_resources() and
		_test_turn_progression_grows_magicka_per_player_up_to_cap() and
		_test_temporary_magicka_spends_first_and_expires() and
		_test_creature_summon_spends_temporary_magicka_first() and
		_test_unaffordable_creature_summon_fails_without_spending() and
		_test_ring_of_magicka_uses_one_charge_per_turn_and_is_destroyed()
	)


func _test_first_turn_start_draws_and_refreshes_resources() -> bool:
	var match_state := _prepare_ready_match(10, 0)
	if not _assert(not match_state.is_empty(), "Expected ready match fixture to initialize."):
		return false

	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]
	MatchTurnLoop.begin_first_turn(match_state)

	return (
		_assert(match_state["phase"] == "action", "First turn should enter the action phase.") and
		_assert(match_state["turn_number"] == 1, "First started turn should set turn_number to 1.") and
		_assert(match_state["active_player_id"] == first_player["player_id"], "Starting player should remain active on turn one.") and
		_assert(first_player["max_magicka"] == 1 and first_player["current_magicka"] == 1, "Starting player should refresh to 1/1 magicka on turn one.") and
		_assert(first_player["temporary_magicka"] == 0, "Starting player should begin the turn with no temporary magicka.") and
		_assert(first_player["hand"].size() == 4 and first_player["deck"].size() == 6, "Starting player should draw one card at the start of turn.") and
		_assert(second_player["hand"].size() == 3 and second_player["deck"].size() == 7, "Inactive player should not draw until their turn starts.")
	)


func _test_turn_progression_grows_magicka_per_player_up_to_cap() -> bool:
	var match_state := _prepare_ready_match(30, 0)
	if not _assert(not match_state.is_empty(), "Expected turn progression fixture to initialize."):
		return false

	MatchTurnLoop.begin_first_turn(match_state)
	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]

	if not _assert(first_player["max_magicka"] == 1 and second_player["max_magicka"] == 0, "Only the active player should gain magicka when the first turn starts."):
		return false

	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	if not _assert(second_player["max_magicka"] == 1 and second_player["current_magicka"] == 1, "Second player should start their first turn at 1/1 magicka."):
		return false

	MatchTurnLoop.end_turn(match_state, second_player["player_id"])
	if not _assert(first_player["max_magicka"] == 2 and first_player["current_magicka"] == 2, "A player's second turn should grow them to 2/2 magicka."):
		return false

	for _turn_index in range(21):
		var active_player_id := String(match_state.get("active_player_id", ""))
		MatchTurnLoop.end_turn(match_state, active_player_id)

	return (
		_assert(first_player["max_magicka"] == 12, "First player should cap at 12 max magicka.") and
		_assert(second_player["max_magicka"] == 12, "Second player should cap at 12 max magicka.") and
		_assert(first_player["turns_started"] == 12 and second_player["turns_started"] == 12, "Both players should have exactly 12 started turns at the magicka cap checkpoint.")
	)


func _test_temporary_magicka_spends_first_and_expires() -> bool:
	var match_state := _prepare_ready_match(12, 0)
	if not _assert(not match_state.is_empty(), "Expected temporary magicka fixture to initialize."):
		return false

	MatchTurnLoop.begin_first_turn(match_state)
	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]
	var first_player_id: String = first_player["player_id"]

	MatchTurnLoop.gain_temporary_magicka(match_state, first_player_id, 2)
	if not _assert(MatchTurnLoop.get_available_magicka(first_player) == 3, "Temporary magicka should add to total available magicka."):
		return false

	MatchTurnLoop.spend_magicka(match_state, first_player_id, 1)
	if not (
		_assert(first_player["temporary_magicka"] == 1, "Spending should consume temporary magicka first.") and
		_assert(first_player["current_magicka"] == 1, "Permanent magicka should remain until temporary magicka is exhausted.")
	):
		return false

	MatchTurnLoop.end_turn(match_state, first_player_id)
	if not (
		_assert(first_player["current_magicka"] == 0 and first_player["temporary_magicka"] == 0, "Unspent magicka should clear when the turn ends.") and
		_assert(second_player["current_magicka"] == 1 and second_player["temporary_magicka"] == 0, "Next player should start refreshed without inheriting temporary magicka.")
	):
		return false

	MatchTurnLoop.end_turn(match_state, second_player["player_id"])
	return _assert(first_player["current_magicka"] == 2 and first_player["temporary_magicka"] == 0, "Temporary magicka should not persist into the controller's next turn.")


func _test_creature_summon_spends_temporary_magicka_first() -> bool:
	var match_state := _prepare_ready_match(12, 0)
	if not _assert(not match_state.is_empty(), "Expected summon spend fixture to initialize."):
		return false

	MatchTurnLoop.begin_first_turn(match_state)
	var first_player: Dictionary = match_state["players"][0]
	first_player["max_magicka"] = 3
	first_player["current_magicka"] = 3
	first_player["temporary_magicka"] = 2
	var creature := _append_creature_to_hand(first_player, "temp_spend", 4)
	var summon_result := LaneRules.summon_from_hand(match_state, first_player["player_id"], creature["instance_id"], "field")
	return (
		_assert(bool(summon_result.get("is_valid", false)), "Creature summon should succeed when combined current and temporary magicka covers the cost.") and
		_assert(first_player["temporary_magicka"] == 0, "Creature summon should spend temporary magicka before permanent magicka.") and
		_assert(first_player["current_magicka"] == 1, "Creature summon should spend only the remaining cost from current magicka.") and
		_assert(first_player["hand"].find(creature) == -1, "Successful creature summons should remove the card from hand.") and
		_assert(_lane_contains(match_state, first_player["player_id"], creature["instance_id"]), "Successful creature summons should place the card onto the board.")
	)


func _test_unaffordable_creature_summon_fails_without_spending() -> bool:
	var match_state := _prepare_ready_match(12, 0)
	if not _assert(not match_state.is_empty(), "Expected unaffordable summon fixture to initialize."):
		return false

	MatchTurnLoop.begin_first_turn(match_state)
	var first_player: Dictionary = match_state["players"][0]
	first_player["max_magicka"] = 1
	first_player["current_magicka"] = 1
	first_player["temporary_magicka"] = 1
	var creature := _append_creature_to_hand(first_player, "too_expensive", 3)
	var validation := LaneRules.validate_summon_from_hand(match_state, first_player["player_id"], creature["instance_id"], "field")
	var summon_result := LaneRules.summon_from_hand(match_state, first_player["player_id"], creature["instance_id"], "field")
	return (
		_assert(not bool(validation.get("is_valid", true)), "Summon validation should reject unaffordable creature plays.") and
		_assert(not bool(summon_result.get("is_valid", true)), "Creature summon should fail when the player cannot afford the card.") and
		_assert(first_player["temporary_magicka"] == 1 and first_player["current_magicka"] == 1, "Failed creature summons should not spend any magicka.") and
		_assert(first_player["hand"].find(creature) != -1, "Unaffordable creature summons should leave the card in hand.") and
		_assert(not _lane_contains(match_state, first_player["player_id"], creature["instance_id"]), "Unaffordable creature summons should not place the card onto the board.")
	)


func _test_ring_of_magicka_uses_one_charge_per_turn_and_is_destroyed() -> bool:
	var match_state := _prepare_ready_match(14, 0)
	if not _assert(not match_state.is_empty(), "Expected Ring of Magicka fixture to initialize."):
		return false

	MatchTurnLoop.begin_first_turn(match_state)
	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]
	var second_player_id: String = second_player["player_id"]

	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	if not _assert(second_player["ring_of_magicka_charges"] == 3 and second_player["has_ring_of_magicka"], "Second player should begin with an intact Ring of Magicka."):
		return false

	MatchTurnLoop.activate_ring_of_magicka(match_state, second_player_id)
	if not (
		_assert(second_player["ring_of_magicka_charges"] == 2, "Ring activation should consume one charge.") and
		_assert(second_player["temporary_magicka"] == 1, "Ring activation should grant one temporary magicka.") and
		_assert(second_player["ring_of_magicka_used_this_turn"], "Ring should record that it has been used this turn.") and
		_assert(MatchTurnLoop.get_available_magicka(second_player) == 2, "Ring activation should increase total available magicka for the turn.") and
		_assert(not MatchTurnLoop.can_activate_ring_of_magicka(match_state, second_player_id), "Ring should become unavailable after being used once this turn.")
	):
		return false

	MatchTurnLoop.end_turn(match_state, second_player_id)
	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	MatchTurnLoop.activate_ring_of_magicka(match_state, second_player_id)

	if not _assert(second_player["ring_of_magicka_charges"] == 1 and second_player["has_ring_of_magicka"], "Second Ring activation should leave one charge remaining."):
		return false

	MatchTurnLoop.end_turn(match_state, second_player_id)
	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	MatchTurnLoop.activate_ring_of_magicka(match_state, second_player_id)

	if not (
		_assert(second_player["ring_of_magicka_charges"] == 0, "Third Ring activation should spend the final charge.") and
		_assert(not second_player["has_ring_of_magicka"], "Ring should be destroyed after the third activation.") and
		_assert(not MatchTurnLoop.can_activate_ring_of_magicka(match_state, second_player_id), "Destroyed Ring should no longer be activatable.")
	):
		return false

	return _assert(second_player["ring_of_magicka_charges"] == 0 and not second_player["has_ring_of_magicka"], "Destroyed Ring should stay unavailable after the final charge is spent.")


func _prepare_ready_match(deck_size: int, first_player_index: int) -> Dictionary:
	var match_state := MatchBootstrap.create_standard_match([
		_build_deck("alpha", deck_size),
		_build_deck("beta", deck_size)
	], {
		"seed": 17,
		"first_player_index": first_player_index
	})

	if match_state.is_empty():
		return {}

	for player in match_state["players"]:
		MatchBootstrap.apply_mulligan(match_state, player["player_id"], [])

	return match_state


func _build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


func _append_creature_to_hand(player: Dictionary, label: String, cost: int, power := 2, health := 2) -> Dictionary:
	var player_id: String = player["player_id"]
	var card := {
		"instance_id": "%s_%s" % [player_id, label],
		"definition_id": "test_%s" % label,
		"owner_player_id": player_id,
		"controller_player_id": player_id,
		"zone": "hand",
		"card_type": "creature",
		"cost": cost,
		"power": power,
		"health": health,
		"keywords": [],
		"granted_keywords": [],
		"status_markers": [],
	}
	player["hand"].append(card)
	return card


func _lane_contains(match_state: Dictionary, player_id: String, instance_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if card != null and str(card.get("instance_id", "")) == instance_id:
				return true
	return false


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true

	push_error(message)
	return false