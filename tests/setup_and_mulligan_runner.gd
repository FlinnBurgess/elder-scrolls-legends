extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("SETUP_AND_MULLIGAN_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_standard_match_bootstrap() and
		_test_bootstrap_is_deterministic() and
		_test_mulligan_replaces_cards_and_reshuffles() and
		_test_mulligan_resolution_order_does_not_change_final_state()
	)


func _test_standard_match_bootstrap() -> bool:
	var match_state := MatchBootstrap.create_standard_match([
		_build_deck("alpha", 10),
		_build_deck("beta", 10)
	], {
		"seed": 7,
		"first_player_index": 0
	})

	if not _assert(not match_state.is_empty(), "Expected standard match bootstrap to succeed."):
		return false

	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]

	return (
		_assert(match_state["phase"] == "mulligan", "Bootstrap should enter the mulligan phase.") and
		_assert(match_state["active_player_id"] == first_player["player_id"], "Chosen first player should be active.") and
		_assert(first_player["health"] == 30 and second_player["health"] == 30, "Both players should start at 30 health.") and
		_assert(first_player["rune_thresholds"] == [25, 20, 15, 10, 5], "Rune thresholds should match standard PvP.") and
		_assert(first_player["hand"].size() == 3 and second_player["hand"].size() == 3, "Both players should start with three cards in hand.") and
		_assert(first_player["deck"].size() == 7 and second_player["deck"].size() == 7, "Opening draws should leave seven cards in each ten-card test deck.") and
		_assert(not first_player["has_ring_of_magicka"], "First player should not receive the Ring of Magicka.") and
		_assert(second_player["has_ring_of_magicka"], "Second player should receive the Ring of Magicka.") and
		_assert(second_player["ring_of_magicka_charges"] == 3, "Ring of Magicka should start with three charges.") and
		_assert(match_state["lanes"].size() == 2, "Standard versus should create two lanes.") and
		_assert(match_state["lanes"][0]["lane_id"] == "field" and match_state["lanes"][1]["lane_id"] == "shadow", "Standard versus lanes should be field and shadow.") and
		_assert(match_state["lanes"][0]["player_slots"][first_player["player_id"]].size() == 4, "Each lane should have four slots per player.")
	)


func _test_bootstrap_is_deterministic() -> bool:
	var first_match := MatchBootstrap.create_standard_match([
		_build_deck("alpha", 12),
		_build_deck("beta", 12)
	], {
		"seed": 101
	})
	var second_match := MatchBootstrap.create_standard_match([
		_build_deck("alpha", 12),
		_build_deck("beta", 12)
	], {
		"seed": 101
	})

	if not _assert(not first_match.is_empty() and not second_match.is_empty(), "Deterministic bootstrap fixtures should initialize."):
		return false

	return (
		_assert(first_match["active_player_id"] == second_match["active_player_id"], "The same seed should pick the same starting player.") and
		_assert(_card_definition_order(first_match["players"][0]["hand"]) == _card_definition_order(second_match["players"][0]["hand"]), "Seeded bootstrap should reproduce player one's opening hand.") and
		_assert(_card_definition_order(first_match["players"][1]["deck"]) == _card_definition_order(second_match["players"][1]["deck"]), "Seeded bootstrap should reproduce player two's remaining deck order.")
	)


func _test_mulligan_replaces_cards_and_reshuffles() -> bool:
	var match_state := MatchBootstrap.create_standard_match([
		_build_deck("alpha", 10),
		_build_deck("beta", 10)
	], {
		"seed": 23,
		"first_player_index": 1
	})

	if not _assert(not match_state.is_empty(), "Expected mulligan fixture to initialize."):
		return false

	var player_id: String = match_state["players"][0]["player_id"]
	var original_hand: Array = match_state["players"][0]["hand"].duplicate(true)
	var discard_instance_ids: Array = [original_hand[0]["instance_id"], original_hand[1]["instance_id"]]
	var deck_size_before: int = match_state["players"][0]["deck"].size()

	MatchBootstrap.apply_mulligan(match_state, player_id, discard_instance_ids)

	var updated_player: Dictionary = match_state["players"][0]
	var updated_hand_instance_ids: Array = _card_instance_ids(updated_player["hand"])
	var updated_deck_instance_ids: Array = _card_instance_ids(updated_player["deck"])

	if not (
		_assert(updated_player["hand"].size() == 3, "Mulligan should preserve hand size.") and
		_assert(updated_player["deck"].size() == deck_size_before, "Discarded cards should return to deck after redraw.") and
		_assert(updated_player["mulligan_complete"], "Player should be marked as done after mulligan.") and
		_assert(match_state["phase"] == "mulligan", "Match should remain in mulligan until both players finish.")
	):
		return false

	for discarded_id in discard_instance_ids:
		if not _assert(not updated_hand_instance_ids.has(discarded_id), "Discarded instances must not be redrawn during mulligan."):
			return false
		if not _assert(updated_deck_instance_ids.has(discarded_id), "Discarded instances should be reshuffled back into the deck after redraw."):
			return false

	var second_player_id: String = match_state["players"][1]["player_id"]
	MatchBootstrap.apply_mulligan(match_state, second_player_id, [])

	return _assert(match_state["phase"] == "ready_for_first_turn", "Once both players finish mulligans, the match should be ready for the first turn.")


func _test_mulligan_resolution_order_does_not_change_final_state() -> bool:
	var first_match := MatchBootstrap.create_standard_match([
		_build_deck("alpha", 12),
		_build_deck("beta", 12)
	], {
		"seed": 59,
		"first_player_index": 0
	})
	var second_match := MatchBootstrap.create_standard_match([
		_build_deck("alpha", 12),
		_build_deck("beta", 12)
	], {
		"seed": 59,
		"first_player_index": 0
	})

	if not _assert(not first_match.is_empty() and not second_match.is_empty(), "Order-independence fixtures should initialize."):
		return false

	var player_one_discards: Array = _hand_instance_ids(first_match["players"][0]["hand"], 2)
	var player_two_discards: Array = _hand_instance_ids(first_match["players"][1]["hand"], 1)

	MatchBootstrap.apply_mulligan(first_match, first_match["players"][0]["player_id"], player_one_discards)
	MatchBootstrap.apply_mulligan(first_match, first_match["players"][1]["player_id"], player_two_discards)

	MatchBootstrap.apply_mulligan(second_match, second_match["players"][1]["player_id"], player_two_discards)
	MatchBootstrap.apply_mulligan(second_match, second_match["players"][0]["player_id"], player_one_discards)

	return _assert(_match_snapshot(first_match) == _match_snapshot(second_match), "Final post-mulligan state should not depend on the order players resolve mulligans.")


func _build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


func _card_definition_order(cards: Array) -> Array:
	var definitions: Array = []
	for card in cards:
		definitions.append(card["definition_id"])
	return definitions


func _card_instance_ids(cards: Array) -> Array:
	var instance_ids: Array = []
	for card in cards:
		instance_ids.append(card["instance_id"])
	return instance_ids


func _hand_instance_ids(cards: Array, count: int) -> Array:
	var instance_ids: Array = []
	for index in range(min(count, cards.size())):
		instance_ids.append(cards[index]["instance_id"])
	return instance_ids


func _match_snapshot(match_state: Dictionary) -> Dictionary:
	var players: Array = []
	for player in match_state["players"]:
		players.append({
			"player_id": player["player_id"],
			"hand": _card_instance_ids(player["hand"]),
			"deck": _card_instance_ids(player["deck"]),
			"mulligan_complete": player["mulligan_complete"]
		})

	return {
		"phase": match_state["phase"],
		"players": players
	}


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true

	push_error(message)
	return false