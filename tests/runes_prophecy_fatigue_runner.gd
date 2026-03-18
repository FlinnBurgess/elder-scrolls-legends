extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("RUNES_PROPHECY_FATIGUE_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_rune_break_emits_events_and_enemy_triggers() and
		_test_prophecy_decline_discards_card_when_hand_full() and
		_test_prophecy_creature_can_be_played_for_free() and
		_test_prophecy_action_deals_damage_to_target() and
		_test_fatigue_uses_out_of_cards_and_eventual_loss()
	)


func _test_rune_break_emits_events_and_enemy_triggers() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var watcher := _summon_creature(active_player, match_state, "rune_watcher", "field", 2, 2, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_RUNE_BREAK,
			"match_role": "opponent_player",
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	var attacker := _summon_creature(active_player, match_state, "rune_breaker", "field", 6, 6, [], 1)
	_target_ready_for_attack(attacker, match_state)
	var hand_before: int = int(opponent["hand"].size())

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var rune_event := _first_event_of_type(result.get("events", []), MatchTiming.EVENT_RUNE_BROKEN)
	return (
		_assert(result["is_valid"], "Rune-break combat fixture should resolve.") and
		_assert(opponent["health"] == 24, "Rune-breaking attack should reduce the defending player to 24 health.") and
		_assert(opponent["rune_thresholds"] == [20, 15, 10, 5], "The 25-health rune should be removed after the first rune break.") and
		_assert(opponent["hand"].size() == hand_before + 1, "Breaking a rune should immediately draw one card.") and
		_assert(int(rune_event.get("threshold", -1)) == 25, "Rune-break event should record the destroyed threshold.") and
		_assert(_families_from_resolutions(result.get("trigger_resolutions", [])) == [MatchTiming.FAMILY_RUNE_BREAK], "Enemy rune-break triggers should resolve through MatchTiming.") and
		_assert(watcher["power_bonus"] == 1, "Rune-break trigger effects should apply to enemy watcher cards.")
	)


func _test_prophecy_decline_discards_card_when_hand_full() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var prophecy_card := _make_card(opponent["player_id"], "decline_prophecy", {
		"zone": "deck",
		"card_type": "action",
		"rules_tags": ["prophecy"],
	})
	_set_deck_cards(opponent, [prophecy_card])
	while opponent["hand"].size() < MatchTiming.MAX_HAND_SIZE:
		_add_hand_card(opponent, "fill_%02d" % opponent["hand"].size(), {"card_type": "action"})
	var attacker := _summon_creature(active_player, match_state, "prophecy_breaker", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(result["is_valid"], "Prophecy draw fixture should resolve.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Drawing a Prophecy from a rune should open a pending Prophecy window.") and
		_assert(opponent["hand"].size() == MatchTiming.MAX_HAND_SIZE + 1, "The drawn Prophecy should remain in hand temporarily while the Prophecy window is open.") and
		_assert(not _first_event_of_type(result.get("events", []), MatchTiming.EVENT_PROPHECY_WINDOW_OPENED).is_empty(), "Rune draw should emit an explicit Prophecy-window event.")
	):
		return false

	var decline_result := MatchTiming.decline_pending_prophecy(match_state, opponent["player_id"], prophecy_card["instance_id"])
	return (
		_assert(decline_result["is_valid"], "Declining a pending Prophecy should succeed.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Declining the Prophecy should clear the pending window.") and
		_assert(opponent["hand"].size() == MatchTiming.MAX_HAND_SIZE, "Declined Prophecy card should be discarded when hand was over the limit.") and
		_assert(str(prophecy_card.get("zone", "")) == "discard", "Declined Prophecy card should move to discard when hand is full.") and
		_assert(not _first_event_of_type(decline_result.get("events", []), MatchTiming.EVENT_PROPHECY_DECLINED).is_empty(), "Declining a Prophecy should emit a dedicated event.") and
		_assert(not _first_event_of_type(decline_result.get("events", []), MatchTiming.EVENT_CARD_OVERDRAW).is_empty(), "Declining a Prophecy at max hand size should emit an overdraw event.")
	)


func _test_prophecy_creature_can_be_played_for_free() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var prophecy_creature := _make_card(opponent["player_id"], "summoned_prophecy", {
		"zone": "deck",
		"card_type": "creature",
		"cost": 5,
		"power": 3,
		"health": 4,
		"rules_tags": ["prophecy"],
	})
	_set_deck_cards(opponent, [prophecy_creature])
	var attacker := _summon_creature(active_player, match_state, "free_play_breaker", "field", 6, 6, [], 0)
	_target_ready_for_attack(attacker, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(result["is_valid"], "Prophecy free-play setup should resolve.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Creature Prophecy draw should open a pending window.")
	):
		return false

	var play_result := MatchTiming.play_pending_prophecy(match_state, opponent["player_id"], prophecy_creature["instance_id"], {
		"lane_id": "field",
		"slot_index": 0,
	})
	var played_event := _first_event_of_type(play_result.get("events", []), MatchTiming.EVENT_CARD_PLAYED)
	var summoned_card: Variant = _lane_slot(match_state, "field", opponent["player_id"], 0)
	return (
		_assert(play_result["is_valid"], "Playing a pending creature Prophecy should succeed.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Prophecy play should consume the pending window.") and
		_assert(summoned_card == prophecy_creature, "A free-played Prophecy creature should be placed onto the board.") and
		_assert(bool(played_event.get("played_for_free", false)), "Prophecy play should mark the card-play event as free.") and
		_assert(str(played_event.get("timing_window", "")) == MatchTiming.WINDOW_INTERRUPT, "Prophecy play should run inside the interrupt timing window.")
	)


func _test_prophecy_action_deals_damage_to_target() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var target_creature := _summon_creature(active_player, match_state, "target_dummy", "field", 3, 6, [], 0)
	var prophecy_action := _make_card(opponent["player_id"], "prophecy_bolt", {
		"zone": "deck",
		"card_type": "action",
		"cost": 4,
		"rules_tags": ["prophecy"],
		"triggered_abilities": [{
			"family": "on_play",
			"effects": [{"op": "deal_damage", "target": "event_target", "amount": 4}],
		}],
	})
	_set_deck_cards(opponent, [prophecy_action])
	var attacker := _summon_creature(active_player, match_state, "rune_breaker_bolt", "field", 6, 6, [], 1)
	_target_ready_for_attack(attacker, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(result["is_valid"], "Prophecy action setup should resolve.") and
		_assert(MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Action Prophecy draw should open a pending window.")
	):
		return false

	var play_result := MatchTiming.play_pending_prophecy(match_state, opponent["player_id"], prophecy_action["instance_id"], {
		"target_instance_id": target_creature["instance_id"],
	})
	var damage_event := _first_event_of_type(play_result.get("events", []), MatchTiming.EVENT_DAMAGE_RESOLVED)
	var remaining_health := int(target_creature.get("health", 0)) - int(target_creature.get("damage", 0))
	return (
		_assert(play_result["is_valid"], "Playing a pending action Prophecy with a target should succeed.") and
		_assert(not MatchTiming.has_pending_prophecy(match_state, opponent["player_id"]), "Prophecy play should consume the pending window.") and
		_assert(not damage_event.is_empty(), "Prophecy action should emit a damage_resolved event.") and
		_assert(int(damage_event.get("amount", 0)) == 4, "Prophecy action should deal 4 damage.") and
		_assert(remaining_health == 2, "Target creature should have 2 health remaining after 4 damage to a 6-health creature.") and
		_assert(str(prophecy_action.get("zone", "")) == "discard", "Prophecy action should move to discard after being played.")
	)


func _test_fatigue_uses_out_of_cards_and_eventual_loss() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	active_player["deck"] = []
	active_player["hand"] = []

	var first_fatigue := MatchTiming.draw_cards(match_state, active_player["player_id"], 1, {"reason": "fatigue_test"})
	var out_of_cards_event := _first_event_of_type(first_fatigue.get("events", []), MatchTiming.EVENT_OUT_OF_CARDS_PLAYED)
	var fatigue_rune_event := _first_event_of_type(first_fatigue.get("events", []), MatchTiming.EVENT_RUNE_BROKEN)
	if not (
		_assert(not out_of_cards_event.is_empty(), "Fatigue should create an explicit Out of Cards event.") and
		_assert(int(fatigue_rune_event.get("threshold", -1)) == 25, "The first fatigue draw should destroy the 25-health rune.") and
		_assert(active_player["health"] == 25, "Out of Cards should reduce health to the destroyed rune's threshold.") and
		_assert(active_player["rune_thresholds"] == [20, 15, 10, 5], "Fatigue should remove the front rune without drawing a replacement card.") and
		_assert(_first_event_of_type(first_fatigue.get("events", []), MatchTiming.EVENT_CARD_DRAWN).is_empty(), "Fatigue should not emit a normal card-drawn event.")
	):
		return false

	var final_result := {}
	for _index in range(5):
		final_result = MatchTiming.draw_cards(match_state, active_player["player_id"], 1, {"reason": "fatigue_test"})
	return (
		_assert(bool(final_result.get("player_lost", false)), "Once all runes are gone, another empty-deck draw should lose the game.") and
		_assert(active_player["health"] == 0, "Final fatigue should reduce health to zero when no runes remain.") and
		_assert(str(match_state.get("winner_player_id", "")) == opponent["player_id"], "The opposing player should win when Out of Cards fires with no runes remaining.") and
		_assert(_count_out_of_cards(active_player) == 6, "Each empty-deck draw should create a distinct Out of Cards card in discard.")
	)


func _build_started_match(deck_size: int, first_player_index: int) -> Dictionary:
	return ScenarioFixtures.create_started_match({
		"deck_size": deck_size,
		"seed": 37,
		"first_player_index": first_player_index,
	})


func _summon_creature(player: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int, keywords: Array = [], slot_index := -1, extra: Dictionary = {}) -> Dictionary:
	var card := ScenarioFixtures.summon_creature(player, match_state, label, lane_id, power, health, keywords, slot_index, extra)
	_assert(not card.is_empty(), "Expected summon fixture for %s to succeed." % label)
	return card


func _add_hand_card(player: Dictionary, label: String, extra: Dictionary = {}) -> Dictionary:
	return ScenarioFixtures.add_hand_card(player, label, extra)


func _make_card(player_id: String, label: String, extra: Dictionary = {}) -> Dictionary:
	return ScenarioFixtures.make_card(player_id, label, extra)


func _set_deck_cards(player: Dictionary, cards: Array) -> void:
	ScenarioFixtures.set_deck_cards(player, cards)


func _target_ready_for_attack(card: Dictionary, match_state: Dictionary) -> void:
	ScenarioFixtures.ready_for_attack(card, match_state)


func _lane_slot(match_state: Dictionary, lane_id: String, player_id: String, slot_index: int):
	return ScenarioFixtures.lane_slot(match_state, lane_id, player_id, slot_index)


func _count_out_of_cards(player: Dictionary) -> int:
	var count := 0
	for card in player.get("discard", []):
		if str(card.get("definition_id", "")) == "out_of_cards":
			count += 1
	return count


func _first_event_of_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if str(event.get("event_type", "")) == event_type:
			return event
	return {}


func _families_from_resolutions(resolutions: Array) -> Array:
	var families: Array = []
	for resolution in resolutions:
		families.append(str(resolution.get("family", "")))
	return families


func _build_deck(prefix: String, size: int) -> Array:
	return ScenarioFixtures.build_deck(prefix, size)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false