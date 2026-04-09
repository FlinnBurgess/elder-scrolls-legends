extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
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
		_test_slay_on_death_and_last_gasp_follow_death_window_order() and
		_test_slay_fires_when_both_creatures_die() and
		_test_pilfer_does_not_fire_on_summon() and
		_test_end_of_turn_target_mode_does_not_fire_on_summon() and
		_test_on_keyword_gained_fires_from_hand() and
		_test_summon_deal_damage_chosen_target_player() and
		_test_item_slay_trigger_fires_and_destroys_item() and
		_test_slay_draw_from_discard_player_choice() and
		_test_on_move_only_fires_for_moved_creature()
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
	# Expertise creature in lane — triggers at end of turn if an action/item/support was played
	var mentor := _summon_creature(active_player, match_state, "mentor", "field", 2, 2, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_EXPERTISE,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 1}],
		}]
	})
	# Play an action (non-creature) to satisfy the Expertise condition
	var action_card := _add_hand_card(active_player, "test_action", {
		"card_type": "action",
		"cost": 1,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [{"op": "log", "message": "played"}],
		}]
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, active_player["player_id"], action_card["instance_id"], {})
	var log_event := _first_event_of_type(play_result.get("events", []), "timing_effect_logged")
	# End the turn — Expertise should fire now
	MatchTurnLoop.end_turn(match_state, active_player["player_id"])
	return (
		_assert(play_result["is_valid"], "Action play should succeed.") and
		_assert(mentor["health_bonus"] == 1, "Expertise should trigger at end of turn after playing an action.") and
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

	# Veteran: triggers on the creature's first attack if it survives
	var veteran := _summon_creature(active_player, match_state, "veteran", "field", 2, 5, [], 1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_VETERAN,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 1}],
		}]
	})
	var blocker := _summon_creature(opponent, match_state, "blocker", "field", 1, 1, [], 0)
	_target_ready_for_attack(veteran, match_state)
	var veteran_result := MatchCombat.resolve_attack(match_state, active_player["player_id"], veteran["instance_id"], {
		"type": "creature",
		"instance_id": blocker["instance_id"],
	})
	return (
		_assert(veteran_result["is_valid"], "Veteran combat fixture should resolve.") and
		_assert(_families_from_resolutions(veteran_result.get("trigger_resolutions", [])) == [MatchTiming.FAMILY_VETERAN], "Veteran should trigger when the creature attacks and survives.") and
		_assert(veteran["health_bonus"] == 1, "Veteran effect should apply to the attacking creature that survived.")
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


func _test_slay_fires_when_both_creatures_die() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var slayer := _summon_creature(active_player, match_state, "slayer", "field", 3, 3, [], 0, {
		"triggered_abilities": [
			{
				"family": MatchTiming.FAMILY_SLAY,
				"required_zone": "lane",
				"effects": [{"op": "damage", "target_player": "opponent", "amount": 1}],
			},
			{
				"family": MatchTiming.FAMILY_LAST_GASP,
				"effects": [{"op": "damage", "target_player": "opponent", "amount": 1}],
			}
		]
	})
	var victim := _summon_creature(opponent, match_state, "victim", "field", 3, 3, [], 0)
	_target_ready_for_attack(slayer, match_state)
	_target_ready_for_attack(victim, match_state)
	var hp_before := int(opponent.get("health", 20))
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], slayer["instance_id"], {
		"type": "creature",
		"instance_id": victim["instance_id"],
	})
	var hp_after := int(opponent.get("health", 20))
	var families := _families_from_resolutions(result.get("trigger_resolutions", []))
	return (
		_assert(result["is_valid"], "Mutual-kill combat should resolve.") and
		_assert(families.has(MatchTiming.FAMILY_SLAY), "Slay should trigger even when the attacker also dies.") and
		_assert(families.has(MatchTiming.FAMILY_LAST_GASP), "Last gasp should trigger when the attacker dies.") and
		_assert(hp_before - hp_after == 2, "Opponent should take 2 damage: 1 from slay + 1 from last gasp (got %d)." % [hp_before - hp_after])
	)


func _test_pilfer_does_not_fire_on_summon() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Summon a target creature first so equip has a valid target
	var target := _summon_creature(active_player, match_state, "equip_target", "field", 2, 2, [], 0)
	# Summon a creature with pilfer target_mode (like Prowl Smuggler)
	var pilferer := _summon_creature(active_player, match_state, "prowl", "shadow", 3, 2, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_PILFER,
			"required_zone": "lane",
			"target_mode": "friendly_creature",
			"effects": [{"op": "modify_stats", "target": "chosen_target", "power": 5, "health": 0}],
		}]
	})
	# Pilfer should NOT have fired on summon — no pending targets should exist
	var pending: Array = match_state.get("pending_summon_effect_targets", [])
	return (
		_assert(pending.is_empty(), "Pilfer with target_mode should NOT create pending summon targets on summon.") and
		_assert(target["power_bonus"] == 0, "No pilfer buff should be applied on summon.")
	)


func _test_end_of_turn_target_mode_does_not_fire_on_summon() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Summon a creature with end_of_turn target_mode (like Mythic Dawn Acolyte)
	var eot := _summon_creature(active_player, match_state, "eot_creature", "field", 5, 4, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_END_OF_TURN,
			"required_zone": "lane",
			"target_mode": "creature_or_player",
			"effects": [{"op": "deal_damage", "target": "chosen_target", "amount": 2}],
		}]
	})
	# End-of-turn triggers should NOT create pending summon targets
	var pending_summon: Array = match_state.get("pending_summon_effect_targets", [])
	var pending_turn: Array = match_state.get("pending_turn_trigger_targets", [])
	return (
		_assert(pending_summon.is_empty(), "End-of-turn target_mode should NOT create pending summon targets.") and
		_assert(pending_turn.is_empty(), "End-of-turn target_mode should NOT create pending turn targets until turn ends.") and
		_assert(opponent["health"] == 30, "No damage should be dealt on summon by end-of-turn effect.")
	)


func _test_on_keyword_gained_fires_from_hand() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var hand_card := _add_hand_card(active_player, "manic_jack", {
		"card_type": "creature",
		"power": 3,
		"health": 3,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_KEYWORD_GAINED,
			"required_zones": ["lane", "hand"],
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}],
		}]
	})
	_reset_timing_logs(match_state)

	# Grant a keyword to the hand card — the on_keyword_gained trigger should fire
	MatchTiming.publish_events(match_state, [{
		"event_type": "keyword_granted",
		"source_instance_id": "external_source",
		"target_instance_id": hand_card["instance_id"],
		"keyword_id": "drain",
	}])
	var power_after := int(hand_card.get("power", 0)) + int(hand_card.get("power_bonus", 0))
	var health_after := int(hand_card.get("health", 0)) + int(hand_card.get("health_bonus", 0))
	return (
		_assert(power_after == 4, "on_keyword_gained in hand should buff power: expected 4, got %d" % power_after) and
		_assert(health_after == 4, "on_keyword_gained in hand should buff health: expected 4, got %d" % health_after)
	)


func _test_summon_deal_damage_chosen_target_player() -> bool:
	# Regression: summon abilities with target_mode "creature_or_player" that deal_damage
	# to "chosen_target" must apply damage when the player selects face (a player target).
	# Previously, the deferred-targeting check only looked at _chosen_target_id (card) and
	# missed _chosen_target_player_id, so face-targeting silently failed.
	var match_state := _build_started_match(20, 0)
	var active: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var opponent_id := str(opponent["player_id"])
	var hp_before := int(opponent.get("health", 30))
	var card := _summon_creature(active, match_state, "face_pinger", "field", 1, 1, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_SUMMON,
			"target_mode": "creature_or_player",
			"effects": [{"op": "deal_damage", "target": "chosen_target", "amount": 1}],
		}],
	})
	# Resolve the summon target as the opponent's face
	var result := MatchTiming.resolve_targeted_effect(match_state, str(card["instance_id"]), {"target_player_id": opponent_id})
	if not _assert(bool(result.get("is_valid", false)), "resolve_targeted_effect should succeed for face target"):
		return false
	var hp_after := int(opponent.get("health", 30))
	return _assert(hp_after == hp_before - 1, "Summon deal_damage to face should reduce opponent HP by 1: expected %d, got %d" % [hp_before - 1, hp_after])


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
	for player in match_state["players"]:
		player["max_magicka"] = 12
		player["current_magicka"] = 12
		player["temporary_magicka"] = 0
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


func _test_item_slay_trigger_fires_and_destroys_item() -> bool:
	# Fork of Horripilation: an item with a slay trigger that destroys itself and draws 3 cards
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var wielder := _summon_creature(active_player, match_state, "wielder", "field", 5, 5, [], 0)
	var fork := _add_hand_card(active_player, "fork", {
		"card_type": "item",
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_SLAY,
			"required_zone": "lane",
			"effects": [
				{"op": "destroy_item", "target": "self"},
				{"op": "draw_cards", "target_player": "controller", "count": 3},
			],
		}],
	})
	MatchMutations.attach_item_to_creature(match_state, active_player["player_id"], fork["instance_id"], wielder["instance_id"])
	var victim := _summon_creature(opponent, match_state, "victim", "field", 2, 2)
	_target_ready_for_attack(wielder, match_state)
	var hand_before: int = active_player["hand"].size()
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], wielder["instance_id"], {
		"type": "creature",
		"instance_id": victim["instance_id"],
	})
	var slay_resolutions := _families_from_resolutions(result.get("trigger_resolutions", [])).filter(func(f): return f == MatchTiming.FAMILY_SLAY)
	var detach_events := _events_of_type(result.get("events", []), "attached_item_detached")
	var hand_after: int = active_player["hand"].size()
	return (
		_assert(result["is_valid"], "Item slay combat should resolve.") and
		_assert(slay_resolutions.size() == 1, "Item slay trigger should fire once. Got %d." % slay_resolutions.size()) and
		_assert(detach_events.size() == 1, "Fork should be detached. Got %d detach events." % detach_events.size()) and
		_assert(wielder.get("attached_items", []).is_empty(), "Wielder should have no items after slay.") and
		_assert(hand_after == hand_before + 3, "Controller should draw 3 cards. Hand went from %d to %d." % [hand_before, hand_after])
	)


func _test_slay_draw_from_discard_player_choice() -> bool:
	# Falkreath Defiler: Slay should create a pending discard choice (player picks), not auto-draw
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Put a creature in the controller's discard pile
	var discarded := {
		"instance_id": "%s_discarded" % active_player["player_id"],
		"definition_id": "test_discarded_creature",
		"owner_player_id": active_player["player_id"],
		"controller_player_id": active_player["player_id"],
		"zone": "discard",
		"card_type": "creature",
		"cost": 3, "power": 2, "health": 2, "base_power": 2, "base_health": 2,
		"damage_marked": 0, "keywords": [], "granted_keywords": [], "status_markers": [],
		"triggered_abilities": [], "power_bonus": 0, "health_bonus": 0,
	}
	active_player["discard"].append(discarded)
	var hand_before: int = active_player["hand"].size()
	var defiler := _summon_creature(active_player, match_state, "defiler", "field", 5, 5, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_SLAY,
			"required_zone": "lane",
			"effects": [{"op": "draw_from_discard_filtered", "target_player": "controller", "filter": {"card_type": "creature"}, "player_choice": true}],
		}]
	})
	var victim := _summon_creature(opponent, match_state, "victim", "field", 1, 1, [], 0)
	_target_ready_for_attack(defiler, match_state)
	_target_ready_for_attack(victim, match_state)
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], defiler["instance_id"], {
		"type": "creature",
		"instance_id": victim["instance_id"],
	})
	var hand_after: int = active_player["hand"].size()
	var pending: Array = match_state.get("pending_discard_choices", [])
	return (
		_assert(result["is_valid"], "Slay combat should resolve.") and
		_assert(hand_after == hand_before, "Hand size should NOT change — card should not be auto-drawn. Was %d, now %d." % [hand_before, hand_after]) and
		_assert(not pending.is_empty(), "Should create a pending_discard_choices entry for player to pick from.") and
		_assert(pending[0].get("candidate_instance_ids", []).has(str(discarded.get("instance_id", ""))), "Discarded creature should be in choice candidates.")
	)


func _test_on_move_only_fires_for_moved_creature() -> bool:
	# Two creatures with on_move self-triggers in the same lane.
	# Moving only one should fire on_move once — not for the other.
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var on_move_ability := {
		"family": MatchTiming.FAMILY_ON_MOVE,
		"required_zone": "lane",
		"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
	}
	var stayer := _summon_creature(active_player, match_state, "stayer", "field", 3, 3, [], -1, {
		"triggered_abilities": [on_move_ability],
	})
	var mover := _summon_creature(active_player, match_state, "mover", "field", 3, 3, [], -1, {
		"triggered_abilities": [on_move_ability],
	})
	_reset_timing_logs(match_state)

	var result := MatchMutations.move_card_between_lanes(match_state, active_player["player_id"], mover["instance_id"], "shadow")
	_assert(bool(result.get("is_valid", false)), "Move should succeed.")
	MatchTiming.publish_events(match_state, result.get("events", []))

	var sources := _replay_sources_for_family(match_state, MatchTiming.FAMILY_ON_MOVE, active_player["player_id"])
	return (
		_assert(sources == [mover["instance_id"]], "Only the moved creature should fire on_move, got: %s" % str(sources)) and
		_assert(int(mover.get("power_bonus", 0)) == 1, "Moved creature should get +1 power from on_move.") and
		_assert(int(stayer.get("power_bonus", 0)) == 0, "Non-moved creature should NOT get +1 power from on_move.")
	)


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