extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("TIMING_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_end_of_turn_lane_and_hand_windows_are_deterministic() and
		_test_start_of_turn_triggers_resolve_in_slot_order() and
		_test_on_play_summon_and_expertise_share_deterministic_order() and
		_test_pilfer_and_veteran_trigger_from_damage_windows() and
		_test_slay_on_death_and_last_gasp_follow_death_window_order()
	)


func _test_end_of_turn_lane_and_hand_windows_are_deterministic() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	_summon_creature(active_player, match_state, "end_lane", "field", 2, 2, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_END_OF_TURN,
			"required_zone": "lane",
			"effects": [{"op": "log", "message": "lane_end"}],
		}]
	})
	_add_hand_card(active_player, "plot_card", {
		"card_type": "action",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_PLOT,
			"required_zone": "hand",
			"effects": [{"op": "log", "message": "plot"}],
		}]
	})
	_reset_timing_logs(match_state)

	MatchTurnLoop.end_turn(match_state, active_player["player_id"])
	var families := _replay_families_for_event(match_state, MatchTiming.EVENT_TURN_ENDING)
	return _assert(families == [MatchTiming.FAMILY_END_OF_TURN, MatchTiming.FAMILY_PLOT], "End-turn lane triggers should resolve before plot triggers from hand.")


func _test_start_of_turn_triggers_resolve_in_slot_order() -> bool:
	var match_state := _build_started_match(20, 0)
	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]
	var first := _summon_creature(first_player, match_state, "start_a", "field", 2, 2, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_START_OF_TURN,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	var second := _summon_creature(first_player, match_state, "start_b", "field", 2, 2, [], 1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_START_OF_TURN,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	_reset_timing_logs(match_state)

	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	MatchTurnLoop.end_turn(match_state, second_player["player_id"])
	var sources := _replay_sources_for_family(match_state, MatchTiming.FAMILY_START_OF_TURN, first_player["player_id"])
	return (
		_assert(sources == [first["instance_id"], second["instance_id"]], "Start-of-turn triggers should resolve in slot order for the active player.") and
		_assert(first["power_bonus"] == 1 and second["power_bonus"] == 1, "Start-of-turn effects should apply to both lane creatures.")
	)


func _test_on_play_summon_and_expertise_share_deterministic_order() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var mentor := _summon_creature(active_player, match_state, "mentor", "field", 2, 2, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_EXPERTISE,
			"required_zone": "lane",
			"min_played_cost": 5,
			"effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 1}],
		}]
	})
	var played_card := _add_hand_card(active_player, "expensive_play", {
		"card_type": "creature",
		"cost": 6,
		"power": 3,
		"health": 3,
		"triggered_abilities": [
			{
				"family": MatchTiming.FAMILY_ON_PLAY,
				"required_zone": "lane",
				"effects": [
					{"op": "log", "message": "played"},
					{"op": "modify_stats", "target": "self", "power": 1, "health": 0},
				],
			},
			{
				"family": MatchTiming.FAMILY_SUMMON,
				"required_zone": "lane",
				"effects": [{"op": "grant_keyword", "target": "self", "keyword_id": "guard"}],
			}
		]
	})

	var result := LaneRules.summon_from_hand(match_state, active_player["player_id"], played_card["instance_id"], "field", {"slot_index": 1})
	var families := _families_from_resolutions(result.get("trigger_resolutions", []))
	var log_event := _first_event_of_type(result.get("events", []), "timing_effect_logged")
	return (
		_assert(result["is_valid"], "Expensive summon fixture should succeed.") and
		_assert(families == [MatchTiming.FAMILY_EXPERTISE, MatchTiming.FAMILY_ON_PLAY, MatchTiming.FAMILY_SUMMON], "Expertise, on-play, and summon should resolve in deterministic order.") and
		_assert(mentor["health_bonus"] == 1, "Expertise should apply when a five-cost-or-more card is played.") and
		_assert(played_card["power_bonus"] == 1 and played_card.get("granted_keywords", []).has("guard"), "On-play and summon effects should modify the played creature.") and
		_assert(str(log_event.get("parent_event_id", "")) != "" and str(log_event.get("produced_by_resolution_id", "")) != "", "Generated timing events should keep replay linkage metadata.")
	)


func _test_pilfer_and_veteran_trigger_from_damage_windows() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pilferer := _summon_creature(active_player, match_state, "pilferer", "field", 3, 3, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_PILFER,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	_target_ready_for_attack(pilferer, match_state)
	var pilfer_result := MatchCombat.resolve_attack(match_state, active_player["player_id"], pilferer["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not (
		_assert(pilfer_result["is_valid"], "Pilfer combat fixture should resolve.") and
		_assert(_families_from_resolutions(pilfer_result.get("trigger_resolutions", [])) == [MatchTiming.FAMILY_PILFER], "Pilfer should trigger from damage dealt to the opposing player.") and
		_assert(pilferer["power_bonus"] == 1, "Pilfer effect should apply to the attacker.")
	):
		return false

	var veteran := _summon_creature(opponent, match_state, "veteran", "field", 1, 5, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_VETERAN,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 1}],
		}]
	})
	var attacker := _summon_creature(active_player, match_state, "poker", "field", 2, 2, [], 1)
	_target_ready_for_attack(veteran, match_state)
	_target_ready_for_attack(attacker, match_state)
	var veteran_result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": veteran["instance_id"],
	})
	return (
		_assert(veteran_result["is_valid"], "Veteran combat fixture should resolve.") and
		_assert(_families_from_resolutions(veteran_result.get("trigger_resolutions", [])) == [MatchTiming.FAMILY_VETERAN], "Veteran should trigger when the creature survives damage.") and
		_assert(veteran["health_bonus"] == 1, "Veteran effect should apply to the damaged creature that survived.")
	)


func _test_slay_on_death_and_last_gasp_follow_death_window_order() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var slayer := _summon_creature(active_player, match_state, "slayer", "field", 5, 5, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_SLAY,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	var victim := _summon_creature(opponent, match_state, "victim", "field", 2, 2, [], 0, {
		"triggered_abilities": [
			{
				"family": MatchTiming.FAMILY_ON_DEATH,
				"required_zone": "discard",
				"effects": [{"op": "log", "message": "death"}],
			},
			{
				"family": MatchTiming.FAMILY_LAST_GASP,
				"required_zone": "discard",
				"effects": [{"op": "log", "message": "last_gasp"}],
			}
		]
	})
	_target_ready_for_attack(slayer, match_state)
	_target_ready_for_attack(victim, match_state)
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], slayer["instance_id"], {
		"type": "creature",
		"instance_id": victim["instance_id"],
	})
	var log_events := _events_of_type(result.get("events", []), "timing_effect_logged")
	return (
		_assert(result["is_valid"], "Death-window combat fixture should resolve.") and
		_assert(_families_from_resolutions(result.get("trigger_resolutions", [])) == [MatchTiming.FAMILY_SLAY, MatchTiming.FAMILY_ON_DEATH, MatchTiming.FAMILY_LAST_GASP], "Slay should resolve before the defender's death triggers, which should keep trigger declaration order.") and
		_assert(slayer["power_bonus"] == 1, "Slay effect should apply to the surviving attacker.") and
		_assert(log_events.size() == 2, "Death-trigger log effects should emit replay-visible events.")
	)


func _build_started_match(deck_size: int, first_player_index: int) -> Dictionary:
	var match_state := MatchBootstrap.create_standard_match([
		_build_deck("alpha", deck_size),
		_build_deck("beta", deck_size)
	], {
		"seed": 31,
		"first_player_index": first_player_index,
	})
	if match_state.is_empty():
		return {}
	for player in match_state["players"]:
		MatchBootstrap.apply_mulligan(match_state, player["player_id"], [])
	MatchTurnLoop.begin_first_turn(match_state)
	return match_state


func _summon_creature(player: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int, keywords: Array = [], slot_index := -1, extra: Dictionary = {}) -> Dictionary:
	var card := _add_hand_card(player, label, {
		"card_type": "creature",
		"cost": int(extra.get("cost", 1)),
		"power": power,
		"health": health,
		"keywords": keywords.duplicate(),
		"triggered_abilities": extra.get("triggered_abilities", []).duplicate(true),
	})
	var summon_options := {}
	if slot_index >= 0:
		summon_options["slot_index"] = slot_index
	var result := LaneRules.summon_from_hand(match_state, player["player_id"], card["instance_id"], lane_id, summon_options)
	_assert(result["is_valid"], "Expected summon fixture for %s to succeed." % label)
	return card


func _add_hand_card(player: Dictionary, label: String, extra: Dictionary = {}) -> Dictionary:
	var card := {
		"instance_id": "%s_%s" % [player["player_id"], label],
		"definition_id": "test_%s" % label,
		"owner_player_id": player["player_id"],
		"controller_player_id": player["player_id"],
		"zone": "hand",
		"card_type": str(extra.get("card_type", "creature")),
		"cost": int(extra.get("cost", 1)),
		"power": int(extra.get("power", 0)),
		"health": int(extra.get("health", 0)),
		"damage_marked": int(extra.get("damage_marked", 0)),
		"keywords": extra.get("keywords", []).duplicate(),
		"granted_keywords": extra.get("granted_keywords", []).duplicate(),
		"status_markers": extra.get("status_markers", []).duplicate(),
		"triggered_abilities": extra.get("triggered_abilities", []).duplicate(true),
		"power_bonus": int(extra.get("power_bonus", 0)),
		"health_bonus": int(extra.get("health_bonus", 0)),
	}
	player["hand"].append(card)
	return card


func _target_ready_for_attack(card: Dictionary, match_state: Dictionary) -> void:
	card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	card["has_attacked_this_turn"] = false


func _reset_timing_logs(match_state: Dictionary) -> void:
	match_state["event_log"] = []
	match_state["replay_log"] = []
	match_state["last_timing_result"] = {"processed_events": [], "trigger_resolutions": []}


func _families_from_resolutions(resolutions: Array) -> Array:
	var families: Array = []
	for resolution in resolutions:
		families.append(str(resolution.get("family", "")))
	return families


func _replay_families_for_event(match_state: Dictionary, event_type: String) -> Array:
	var families: Array = []
	for entry in match_state.get("replay_log", []):
		if str(entry.get("entry_type", "")) == "trigger_resolved" and str(entry.get("event_type", "")) == event_type:
			families.append(str(entry.get("family", "")))
	return families


func _replay_sources_for_family(match_state: Dictionary, family: String, controller_player_id: String) -> Array:
	var sources: Array = []
	for entry in match_state.get("replay_log", []):
		if str(entry.get("entry_type", "")) != "trigger_resolved":
			continue
		if str(entry.get("family", "")) != family:
			continue
		if str(entry.get("controller_player_id", "")) != controller_player_id:
			continue
		sources.append(str(entry.get("source_instance_id", "")))
	return sources


func _first_event_of_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if str(event.get("event_type", "")) == event_type:
			return event
	return {}


func _events_of_type(events: Array, event_type: String) -> Array:
	var matches: Array = []
	for event in events:
		if str(event.get("event_type", "")) == event_type:
			matches.append(event)
	return matches


func _build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false