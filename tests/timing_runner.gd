extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")


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
		_test_last_gasp_modify_stats_targets_all_instances_by_definition_id() and
		_test_slay_fires_when_both_creatures_die() and
		_test_pilfer_does_not_fire_on_summon() and
		_test_end_of_turn_target_mode_does_not_fire_on_summon() and
		_test_on_keyword_gained_fires_from_hand() and
		_test_summon_deal_damage_chosen_target_player() and
		_test_item_slay_trigger_fires_and_destroys_item() and
		_test_slay_draw_from_discard_player_choice() and
		_test_on_move_only_fires_for_moved_creature() and
		_test_wax_wane_target_mode_not_queued_at_end_of_turn() and
		_test_trigger_wane_queues_targeted_wax_wane_for_other_friendly() and
		_test_slay_does_not_fire_on_stat_reduction_kill() and
		_test_play_random_from_deck_creates_free_plays() and
		_test_decline_pending_free_play_keeps_card_in_hand() and
		_test_copy_pilfer_abilities_fires_all_friendly_pilfer_triggers() and
		_test_item_on_attack_trigger_fires_for_host_creature() and
		_test_slay_discard_matching_from_opponent_deck() and
		_test_skar_drillmaster_copies_rallied_creature_to_hand() and
		_test_plot_effects_append_when_plot_active() and
		_test_baandari_opportunist_copy_has_pilfer() and
		_test_draw_from_deck_filtered_then_modify_stats_last_drawn() and
		_test_end_of_turn_invaded_condition_resets_across_opponent_turn() and
		_test_draw_from_deck_filtered_count_and_unique() and
		_test_expertise_target_mode_swap_completes_at_turn_end() and
		_test_swap_creatures_preserves_lane_when_full() and
		_test_expertise_deal_damage_chosen_target_heals_and_draws() and
		_test_on_friendly_pilfer_or_drain_requires_pilfer_or_drain() and
		_test_filter_keyword_matches_triggered_ability_families() and
		_test_pilfer_steal_from_discard_creates_choice_and_moves_to_discard()
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


func _test_last_gasp_modify_stats_targets_all_instances_by_definition_id() -> bool:
	# Regression: Blackwood Hoodlum's last_gasp should buff every instance of Modryn Oreyn on the
	# board (by definition_id), not just itself. The catalog originally used an unsupported
	# "target_card_id" key which silently defaulted to target:"self".
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Two Modryn Oreyn instances — one on each side — share a definition_id.
	var modryn_one := _summon_creature(active_player, match_state, "modryn_one", "field", 4, 4)
	modryn_one["definition_id"] = "joo_str_modryn_oreyn"
	var modryn_two := _summon_creature(opponent, match_state, "modryn_two", "shadow", 4, 4)
	modryn_two["definition_id"] = "joo_str_modryn_oreyn"
	# Attacker on active side will kill the Hoodlum next.
	var attacker := _summon_creature(active_player, match_state, "attacker", "field", 5, 5)
	# Hoodlum on opponent side with the real catalog trigger shape.
	var hoodlum := _summon_creature(opponent, match_state, "hoodlum", "field", 1, 1, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_LAST_GASP,
			"effects": [{
				"op": "modify_stats",
				"target": "all_creatures",
				"target_filter_definition_id": "joo_str_modryn_oreyn",
				"power": 2,
				"health": 2,
			}],
		}]
	})
	_target_ready_for_attack(attacker, match_state)
	_target_ready_for_attack(hoodlum, match_state)
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": hoodlum["instance_id"],
	})
	return (
		_assert(result["is_valid"], "Attack on Hoodlum should resolve.") and
		_assert(int(modryn_one.get("power_bonus", 0)) == 2, "Friendly Modryn should gain +2 power (got %d)." % int(modryn_one.get("power_bonus", 0))) and
		_assert(int(modryn_one.get("health_bonus", 0)) == 2, "Friendly Modryn should gain +2 health (got %d)." % int(modryn_one.get("health_bonus", 0))) and
		_assert(int(modryn_two.get("power_bonus", 0)) == 2, "Enemy Modryn should also gain +2 power (got %d)." % int(modryn_two.get("power_bonus", 0))) and
		_assert(int(modryn_two.get("health_bonus", 0)) == 2, "Enemy Modryn should also gain +2 health (got %d)." % int(modryn_two.get("health_bonus", 0)))
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
		"passive_abilities": extra.get("passive_abilities", []).duplicate(true),
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
		"passive_abilities": extra.get("passive_abilities", []).duplicate(true),
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


func _test_wax_wane_target_mode_not_queued_at_end_of_turn() -> bool:
	# Wax/wane abilities with target_mode (e.g. Servant of Ja-Kha'jay's Wane: Silence)
	# should only fire on summon, NOT be queued as pending turn triggers at end of turn.
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var player_id := str(active_player.get("player_id", ""))
	var opponent_id := str(opponent.get("player_id", ""))
	# Place a creature with wane: silence (target_mode) in lane
	var servant := _summon_creature(active_player, match_state, "servant", "field", 2, 2, [], -1, {
		"triggered_abilities": [
			{"family": MatchTiming.FAMILY_WAX, "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 2, "health": 2}]},
			{"family": MatchTiming.FAMILY_WANE, "required_zone": "lane", "target_mode": "any_creature", "effects": [{"op": "silence", "target": "chosen_target"}]},
		],
	})
	# End turn to toggle to wane phase
	MatchTurnLoop.end_turn(match_state, player_id)
	MatchTurnLoop.end_turn(match_state, opponent_id)
	# Now player is in wane phase. Queue turn trigger targets (as happens when clicking End Turn)
	MatchTiming.queue_turn_trigger_targets(match_state, player_id)
	var pending_turn: Array = match_state.get("pending_turn_trigger_targets", [])
	return (
		_assert(not servant.is_empty(), "Servant should be in lane.") and
		_assert(pending_turn.is_empty(), "Wax/wane target_mode abilities should NOT be queued as turn triggers at end of turn.")
	)


func _build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


func _test_trigger_wane_queues_targeted_wax_wane_for_other_friendly() -> bool:
	# Rebellion General's trigger_wane should queue targeted wane abilities
	# (like Servant of Ja-Kha'jay's silence) as pending_turn_trigger_targets
	# instead of skipping them.
	var match_state := _build_started_match(20, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var player_id := str(player["player_id"])
	# Put player in wane phase so wane triggers fire on summon
	player["wax_wane_state"] = "wane"
	# Summon an enemy creature (silence target)
	var enemy := _summon_creature(opponent, match_state, "enemy_target", "field", 3, 3)
	# Summon a creature with non-targeted wane (stat buff, should fire immediately)
	var stat_creature := _summon_creature(player, match_state, "stat_wane", "field", 2, 2, [], -1, {
		"triggered_abilities": [
			{"family": "wane", "required_zone": "lane", "effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 1}]},
		],
	})
	# Summon a creature with targeted wane (silence, needs player selection)
	var targeted_creature := _summon_creature(player, match_state, "targeted_wane", "field", 2, 2, [], -1, {
		"triggered_abilities": [
			{"family": "wane", "required_zone": "lane", "target_mode": "any_creature", "effects": [{"op": "silence", "target": "chosen_target"}]},
		],
	})
	# Summon the "rebellion general" — has trigger_wane on all_other_friendly
	var general := _summon_creature(player, match_state, "rebellion_general", "field", 4, 4, [], -1, {
		"triggered_abilities": [
			{"family": "wane", "required_zone": "lane", "effects": [
				{"op": "modify_stats", "target": "self", "power": 0, "health": 1},
				{"op": "trigger_wane", "target": "all_other_friendly"},
			]},
		],
	})
	# The non-targeted wane on stat_creature should have fired (bonus applied)
	var stat_health := int(stat_creature.get("health", 0)) + int(stat_creature.get("health_bonus", 0)) - int(stat_creature.get("damage_marked", 0))
	# The targeted wane on targeted_creature should be queued as a pending target
	var pending: Array = match_state.get("pending_turn_trigger_targets", [])
	var has_targeted_pending := false
	for entry in pending:
		if str(entry.get("source_instance_id", "")) == str(targeted_creature.get("instance_id", "")):
			has_targeted_pending = true
			break
	return (
		_assert(stat_health > 2, "Non-targeted wane should fire immediately via trigger_wane: health should be > 2, got %d." % stat_health) and
		_assert(has_targeted_pending, "Targeted wane should be queued as pending_turn_trigger_target, not skipped.")
	)


func _test_slay_does_not_fire_on_stat_reduction_kill() -> bool:
	# A creature with slay in lane should NOT get slay credit when an enemy
	# dies from a stat debuff (e.g. Drain Vitality -1/-1 on a 1/1).
	var match_state := _build_started_match(20, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var slayer := _summon_creature(player, match_state, "slayer", "field", 3, 3, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_SLAY,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}],
		}]
	})
	var victim := _summon_creature(opponent, match_state, "victim", "field", 1, 1, [], 0)
	_reset_timing_logs(match_state)
	# Apply -1/-1 stat debuff to reduce the victim to 0 health
	EvergreenRules.apply_stat_bonus(victim, -1, -1, "action")
	# Publish a stats_modified event so publish_events runs and the aura death
	# check detects the 0-health creature
	var timing_result := MatchTiming.publish_events(match_state, [{
		"event_type": "stats_modified",
		"source_instance_id": "external_action",
		"target_instance_id": str(victim.get("instance_id", "")),
		"power_bonus": -1,
		"health_bonus": -1,
	}])
	var families := _families_from_resolutions(timing_result.get("trigger_resolutions", []))
	var has_death := false
	for evt in timing_result.get("processed_events", []):
		if str(evt.get("event_type", "")) == "creature_destroyed":
			has_death = true
			break
	return (
		_assert(has_death, "Victim should die from 0 health after stat reduction.") and
		_assert(not families.has(MatchTiming.FAMILY_SLAY), "Slay should NOT trigger from stat-reduction kill (no combat killer).")
	)


func _add_deck_card(player: Dictionary, label: String, extra: Dictionary = {}) -> Dictionary:
	var card := {
		"instance_id": "%s_%s" % [player["player_id"], label],
		"definition_id": "test_%s" % label,
		"owner_player_id": player["player_id"],
		"controller_player_id": player["player_id"],
		"zone": "deck",
		"card_type": str(extra.get("card_type", "creature")),
		"cost": int(extra.get("cost", 1)),
		"power": int(extra.get("power", 0)),
		"health": int(extra.get("health", 0)),
		"keywords": extra.get("keywords", []).duplicate(),
		"triggered_abilities": extra.get("triggered_abilities", []).duplicate(true),
	}
	player["deck"].append(card)
	return card


func _test_play_random_from_deck_creates_free_plays() -> bool:
	var match_state := _build_started_match(10, 0)
	var player: Dictionary = match_state["players"][0]
	var player_id := str(player["player_id"])
	# Clear deck and seed with one of each type
	player["deck"].clear()
	var deck_creature := _add_deck_card(player, "deck_creature", {"card_type": "creature", "power": 3, "health": 3})
	var deck_item := _add_deck_card(player, "deck_item", {"card_type": "item"})
	var deck_support := _add_deck_card(player, "deck_support", {"card_type": "support"})
	var deck_action := _add_deck_card(player, "deck_action", {"card_type": "action"})
	# Create the Siege-like action card with 4x play_random_from_deck
	var siege := _add_hand_card(player, "siege", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [
			{"op": "play_random_from_deck", "filter": {"card_type": "creature"}},
			{"op": "play_random_from_deck", "filter": {"card_type": "item"}},
			{"op": "play_random_from_deck", "filter": {"card_type": "support"}},
			{"op": "play_random_from_deck", "filter": {"card_type": "action"}},
		]}],
	})
	MatchTiming.play_action_from_hand(match_state, player_id, str(siege["instance_id"]), {})
	# Deck should be empty — all 4 cards pulled
	if not _assert(player["deck"].size() == 0, "play_random_from_deck: deck should be empty after pulling one of each type."):
		return false
	# Hand should have the 4 cards
	var hand_ids: Array = []
	for card in player["hand"]:
		hand_ids.append(str(card.get("instance_id", "")))
	if not _assert(hand_ids.has(str(deck_creature["instance_id"])), "play_random_from_deck: creature should be in hand."):
		return false
	if not _assert(hand_ids.has(str(deck_item["instance_id"])), "play_random_from_deck: item should be in hand."):
		return false
	if not _assert(hand_ids.has(str(deck_support["instance_id"])), "play_random_from_deck: support should be in hand."):
		return false
	if not _assert(hand_ids.has(str(deck_action["instance_id"])), "play_random_from_deck: action should be in hand."):
		return false
	# All 4 should be pending free plays
	var fp_arr: Array = match_state.get("pending_free_plays", [])
	if not _assert(fp_arr.size() == 4, "play_random_from_deck: should create 4 pending free plays, got %d." % fp_arr.size()):
		return false
	# Each should have _play_for_free flag
	for card in player["hand"]:
		if str(card.get("instance_id", "")) in [str(deck_creature["instance_id"]), str(deck_item["instance_id"]), str(deck_support["instance_id"]), str(deck_action["instance_id"])]:
			if not _assert(bool(card.get("_play_for_free", false)), "play_random_from_deck: card %s should have _play_for_free flag." % str(card.get("instance_id", ""))):
				return false
	return true


func _test_decline_pending_free_play_keeps_card_in_hand() -> bool:
	var match_state := _build_started_match(10, 0)
	var player: Dictionary = match_state["players"][0]
	var player_id := str(player["player_id"])
	# Clear deck and seed with a creature
	player["deck"].clear()
	var deck_creature := _add_deck_card(player, "deck_creature", {"card_type": "creature", "power": 2, "health": 2})
	# Create action that plays random creature from deck
	var action_card := _add_hand_card(player, "pull_action", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [
			{"op": "play_random_from_deck", "filter": {"card_type": "creature"}},
		]}],
	})
	MatchTiming.play_action_from_hand(match_state, player_id, str(action_card["instance_id"]), {})
	# Verify card is in hand with free play
	if not _assert(MatchTiming.has_pending_free_play(match_state, player_id), "decline test: should have pending free play."):
		return false
	# Decline it
	var result := MatchTiming.decline_pending_free_play(match_state, player_id)
	if not _assert(bool(result.get("is_valid", false)), "decline test: decline should succeed."):
		return false
	# Card should still be in hand
	var found := false
	var still_free := false
	for card in player["hand"]:
		if str(card.get("instance_id", "")) == str(deck_creature["instance_id"]):
			found = true
			still_free = bool(card.get("_play_for_free", false))
			break
	if not _assert(found, "decline test: card should remain in hand after decline."):
		return false
	if not _assert(not still_free, "decline test: _play_for_free flag should be removed after decline."):
		return false
	return _assert(not MatchTiming.has_pending_free_play(match_state, player_id), "decline test: no pending free play should remain.")


func _test_copy_pilfer_abilities_fires_all_friendly_pilfer_triggers() -> bool:
	# Devious Bandit: copy_pilfer_abilities passive should copy pilfer triggers from all friendly creatures
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Summon two creatures with different pilfer abilities
	var pilferer_a := _summon_creature(active_player, match_state, "pilferer_a", "field", 2, 2, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_PILFER,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	var pilferer_b := _summon_creature(active_player, match_state, "pilferer_b", "field", 1, 1, [], 1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_PILFER,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 1}],
		}]
	})
	# Summon the copier with copy_pilfer_abilities passive
	var copier := _summon_creature(active_player, match_state, "copier", "field", 3, 3, [], 2, {
		"passive_abilities": [{"type": "copy_pilfer_abilities"}],
	})
	_target_ready_for_attack(copier, match_state)
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], copier["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "copy_pilfer: combat should resolve."):
		return false
	var pilfer_resolutions := []
	for r in result.get("trigger_resolutions", []):
		if str(r.get("family", "")) == MatchTiming.FAMILY_PILFER:
			pilfer_resolutions.append(r)
	if not _assert(pilfer_resolutions.size() == 2, "copy_pilfer: copier should fire 2 copied pilfer triggers. Got %d." % pilfer_resolutions.size()):
		return false
	# The copied effects target self (the copier), so copier should get +1/+1
	return (
		_assert(copier["power_bonus"] == 1, "copy_pilfer: copier should gain +1 power from copied pilfer A. Got %d." % copier["power_bonus"]) and
		_assert(copier["health_bonus"] == 1, "copy_pilfer: copier should gain +1 health from copied pilfer B. Got %d." % copier["health_bonus"])
	)


func _test_item_on_attack_trigger_fires_for_host_creature() -> bool:
	# Staff of Sparks: on_attack should deal 1 damage to all enemies in lane when host attacks
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var wielder := _summon_creature(active_player, match_state, "sparks_wielder", "field", 3, 3, [], 0)
	var item := _add_hand_card(active_player, "staff_of_sparks", {
		"card_type": "item",
		"equip_power_bonus": 3,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_ATTACK,
			"required_zone": "lane",
			"effects": [{"op": "deal_damage", "target": "all_enemies_in_lane", "amount": 1}],
		}],
	})
	MatchMutations.attach_item_to_creature(match_state, active_player["player_id"], item["instance_id"], wielder["instance_id"])
	var enemy_a := _summon_creature(opponent, match_state, "enemy_a", "field", 1, 3, [], 0)
	var enemy_b := _summon_creature(opponent, match_state, "enemy_b", "field", 1, 3, [], 1)
	_target_ready_for_attack(wielder, match_state)
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], wielder["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var on_attack_resolutions := _families_from_resolutions(result.get("trigger_resolutions", [])).filter(func(f): return f == MatchTiming.FAMILY_ON_ATTACK)
	var enemy_a_dmg := int(enemy_a.get("damage_marked", 0))
	var enemy_b_dmg := int(enemy_b.get("damage_marked", 0))
	return (
		_assert(result["is_valid"], "Attack with Staff of Sparks should resolve.") and
		_assert(on_attack_resolutions.size() == 1, "Item on_attack should fire once. Got %d." % on_attack_resolutions.size()) and
		_assert(enemy_a_dmg >= 1, "Enemy A should take 1 damage from Staff of Sparks. Got %d." % enemy_a_dmg) and
		_assert(enemy_b_dmg >= 1, "Enemy B should take 1 damage from Staff of Sparks. Got %d." % enemy_b_dmg)
	)


func _test_slay_discard_matching_from_opponent_deck() -> bool:
	var match_state := _build_started_match(10, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Slayer with discard_matching_from_opponent_deck slay effect
	var slayer := _summon_creature(active_player, match_state, "black_dragon", "field", 5, 5, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_SLAY,
			"required_zone": "lane",
			"effects": [{"op": "discard_matching_from_opponent_deck", "match": "slain_creature_name"}],
		}]
	})
	# Victim in lane — use a shared definition_id so deck copies match
	var victim := _summon_creature(opponent, match_state, "imp", "field", 1, 1, [], 0)
	# Add 3 deck cards with the same definition_id as the victim
	for i in range(3):
		var deck_card := _add_deck_card(opponent, "deck_imp_%d" % i)
		deck_card["definition_id"] = victim["definition_id"]
	# Add 1 deck card with a different definition_id (should not be discarded)
	_add_deck_card(opponent, "other_creature")
	_target_ready_for_attack(slayer, match_state)
	_target_ready_for_attack(victim, match_state)
	var deck_before: int = opponent["deck"].size()
	var discard_before: int = opponent["discard"].size()
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], slayer["instance_id"], {
		"type": "creature",
		"instance_id": victim["instance_id"],
	})
	var deck_after: int = opponent["deck"].size()
	var discard_after: int = opponent["discard"].size()
	var deck_removed := deck_before - deck_after
	var discard_added := discard_after - discard_before
	return (
		_assert(result["is_valid"], "Attack should resolve.") and
		_assert(deck_removed == 3, "3 matching cards should be removed from opponent deck. Got %d." % deck_removed) and
		_assert(discard_added >= 4, "Victim + 3 matching deck cards should enter discard. Got %d." % discard_added)
	)


func _test_skar_drillmaster_copies_rallied_creature_to_hand() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Summon Skar Drillmaster with rally + on_rally copy effect
	var drillmaster := _summon_creature(active_player, match_state, "drillmaster", "field", 5, 5, ["rally"], 0, {
		"triggered_abilities": [{"family": "on_rally", "required_zone": "lane", "effects": [{"op": "copy_rallied_creature_to_hand", "bonus_power": 1, "bonus_health": 1}]}],
	})
	# Add a creature to hand that rally can buff
	var hand_creature := _add_hand_card(active_player, "hand_target", {"card_type": "creature", "power": 3, "health": 3, "power_bonus": 2, "health_bonus": 2})
	var hand_size_before: int = active_player["hand"].size()
	_target_ready_for_attack(drillmaster, match_state)
	_reset_timing_logs(match_state)
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], drillmaster["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var hand_size_after: int = active_player["hand"].size()
	# Find the generated copy (not the original hand_target)
	var copy_found := false
	var copy_power_bonus := 0
	var copy_health_bonus := 0
	for card in active_player["hand"]:
		if str(card.get("instance_id", "")).begins_with(active_player["player_id"] + "_generated"):
			copy_found = true
			copy_power_bonus = int(card.get("power_bonus", 0))
			copy_health_bonus = int(card.get("health_bonus", 0))
			break
	return (
		_assert(result["is_valid"], "Attack should resolve.") and
		_assert(hand_size_after == hand_size_before + 1, "A copy should be added to hand. Before: %d, After: %d." % [hand_size_before, hand_size_after]) and
		_assert(copy_found, "A generated copy card should exist in hand.") and
		_assert(copy_power_bonus == 1, "Copy should have base stats with only +1 from effect, not inherited bonuses. Got: %d." % copy_power_bonus) and
		_assert(copy_health_bonus == 1, "Copy should have base stats with only +1 from effect, not inherited bonuses. Got: %d." % copy_health_bonus)
	)


func _test_plot_effects_append_when_plot_active() -> bool:
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	# Summon a creature in field lane so there's at least 1 friendly creature
	_summon_creature(active_player, match_state, "grunt", "field", 1, 1)
	# Play a filler action to satisfy plot (cards_played_this_turn >= 2 on the second play)
	var filler := _add_hand_card(active_player, "filler", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "log", "message": "filler"}]}],
	})
	MatchTiming.play_action_from_hand(match_state, active_player["player_id"], filler["instance_id"], {})
	# Play the action with plot_effects — simulates Crassius' Favor pattern:
	# base effects summon a token, plot_effects heal per friendly creature in lane
	var health_before := int(active_player.get("health", 30))
	var plot_action := _add_hand_card(active_player, "plot_heal", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": "on_play",
			"effects": [
				{"op": "summon_from_effect", "lane": "chosen", "card_template": {
					"definition_id": "test_token", "name": "Token", "card_type": "creature",
					"attributes": [], "cost": 0, "power": 1, "health": 1,
					"base_power": 1, "base_health": 1, "rules_text": "",
				}},
			],
			"plot_effects": [
				{"op": "heal", "target_player": "controller", "amount": 1, "count_source": "friendly_creatures_chosen_lane"},
			],
		}],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, active_player["player_id"], plot_action["instance_id"], {"lane_id": "field"})
	var health_after := int(active_player.get("health", 0))
	# Count friendly creatures in field lane (grunt + summoned token = 2)
	var field_creature_count := 0
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == "field":
			var slots = lane.get("player_slots", {}).get(active_player["player_id"], [])
			for card in slots:
				if typeof(card) == TYPE_DICTIONARY:
					field_creature_count += 1
	return (
		_assert(bool(play_result.get("is_valid", false)), "Plot action should be playable.") and
		_assert(field_creature_count >= 2, "Token should have been summoned to field lane. Count: %d." % field_creature_count) and
		_assert(health_after > health_before, "Plot heal effect should have healed controller. Before: %d, After: %d." % [health_before, health_after])
	)


func _test_baandari_opportunist_copy_has_pilfer() -> bool:
	# Upgraded Baandari Opportunist copies should have both summon:draw AND pilfer:shuffle
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Use the real card template from the original Baandari's pilfer effect
	var upgraded_template := {
		"definition_id": "aw_agi_baandari_opportunist_upgraded",
		"art_path": "res://assets/images/cards/aw_agi_baandari_opportunist.png",
		"name": "Baandari Opportunist",
		"card_type": "creature",
		"subtypes": ["Khajiit"],
		"attributes": ["agility"],
		"cost": 1, "power": 1, "health": 1,
		"base_power": 1, "base_health": 1,
		"keywords": ["charge"],
		"rules_text": "Charge\nSummon: Draw a card.\nPilfer: Shuffle a Baandari Opportunist with \"Summon: Draw a card\" into your deck.",
	}
	var baandari := _summon_creature(active_player, match_state, "baandari", "field", 1, 1, ["charge"], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_PILFER,
			"required_zone": "lane",
			"effects": [{"op": "shuffle_into_deck", "card_template": upgraded_template}],
		}],
	})
	_target_ready_for_attack(baandari, match_state)
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], baandari["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "baandari_copy: attack should resolve."):
		return false
	# Find the generated card in the deck
	var deck: Array = active_player.get("deck", [])
	var copy: Dictionary = {}
	for card in deck:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "aw_agi_baandari_opportunist_upgraded":
			copy = card
			break
	if not _assert(not copy.is_empty(), "baandari_copy: upgraded copy should be in deck."):
		return false
	var abilities: Array = copy.get("triggered_abilities", [])
	var has_summon := false
	var has_pilfer := false
	for ability in abilities:
		if typeof(ability) == TYPE_DICTIONARY:
			match str(ability.get("family", "")):
				"summon":
					has_summon = true
				"pilfer":
					has_pilfer = true
	if not (
		_assert(has_summon, "baandari_copy: upgraded copy should have summon ability.") and
		_assert(has_pilfer, "baandari_copy: upgraded copy should have pilfer ability.")
	):
		return false
	# Verify second-generation copy also gets both abilities (not double summon)
	# Simulate the upgraded copy pilfer by generating another card from its pilfer template
	var pilfer_ability: Dictionary = {}
	for ability in abilities:
		if typeof(ability) == TYPE_DICTIONARY and str(ability.get("family", "")) == "pilfer":
			pilfer_ability = ability
	var pilfer_effects: Array = pilfer_ability.get("effects", [])
	if not _assert(not pilfer_effects.is_empty(), "baandari_copy: pilfer should have effects."):
		return false
	var second_template: Dictionary = pilfer_effects[0].get("card_template", {})
	var second_copy := MatchMutations.build_generated_card(match_state, active_player["player_id"], second_template)
	var second_abilities: Array = second_copy.get("triggered_abilities", [])
	var second_summon_count := 0
	var second_has_pilfer := false
	for ability in second_abilities:
		if typeof(ability) == TYPE_DICTIONARY:
			if str(ability.get("family", "")) == "summon":
				second_summon_count += 1
			elif str(ability.get("family", "")) == "pilfer":
				second_has_pilfer = true
	return (
		_assert(second_summon_count == 1, "baandari_copy: second-gen copy should have exactly 1 summon ability, got %d." % second_summon_count) and
		_assert(second_has_pilfer, "baandari_copy: second-gen copy should have pilfer ability.")
	)


func _test_draw_from_deck_filtered_then_modify_stats_last_drawn() -> bool:
	# Wake the Dead: draw a Skeleton from deck (player choice) then give it +0/+1
	var match_state := _build_started_match(10, 0)
	var active_player: Dictionary = match_state["players"][0]
	var player_id := str(active_player["player_id"])
	# Seed a Skeleton creature into the deck
	var skeleton := _add_deck_card(active_player, "skeleton", {"card_type": "creature", "power": 2, "health": 2})
	skeleton["subtypes"] = ["Skeleton"]
	# Create the action with draw_from_deck_filtered + modify_stats targeting last_drawn_card
	var action := _add_hand_card(active_player, "wake_the_dead", {
		"card_type": "action",
		"cost": 2,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [
				{"op": "draw_from_deck_filtered", "target_player": "controller", "filter": {"subtype_in": ["Skeleton"]}, "player_choice": true},
				{"op": "modify_stats", "target": "last_drawn_card", "power": 0, "health": 1},
			],
		}],
	})
	MatchTiming.play_action_from_hand(match_state, player_id, action["instance_id"], {})
	# A pending deck selection should exist
	var pending: Array = match_state.get("pending_deck_selections", [])
	if not _assert(pending.size() > 0, "wake_the_dead: should have pending deck selection."):
		return false
	# Resolve the pending selection by picking the skeleton
	var resolve_result := MatchTiming.resolve_pending_deck_selection(match_state, player_id, skeleton["instance_id"])
	if not _assert(resolve_result["is_valid"], "wake_the_dead: deck selection should resolve."):
		return false
	# The skeleton should now be in hand with +0/+1
	return (
		_assert(str(skeleton.get("zone", "")) == "hand", "wake_the_dead: skeleton should be in hand.") and
		_assert(int(skeleton.get("health_bonus", 0)) == 1, "wake_the_dead: skeleton should have +1 health bonus, got %d." % int(skeleton.get("health_bonus", 0))) and
		_assert(int(skeleton.get("power_bonus", 0)) == 0, "wake_the_dead: skeleton should have +0 power bonus.")
	)


func _test_end_of_turn_invaded_condition_resets_across_opponent_turn() -> bool:
	# Agent of Mehrunes Dagon-style: end_of_turn with invaded_this_turn condition
	# should NOT fire on the opponent's turn even though it fired on the controller's turn.
	var match_state := _build_started_match(20, 0)
	var p1: Dictionary = match_state["players"][0]
	var p2: Dictionary = match_state["players"][1]
	var agent := _summon_creature(p1, match_state, "agent", "field", 3, 2, [], 0, {
		"triggered_abilities": [
			{
				"family": MatchTiming.FAMILY_END_OF_TURN,
				"required_zone": "lane",
				"invaded_this_turn": true,
				"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}],
			},
			{
				"family": MatchTiming.FAMILY_END_OF_TURN,
				"match_role": "opponent_player",
				"required_zone": "lane",
				"invaded_this_turn": true,
				"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 1}],
			},
		]
	})
	# Simulate an invade on p1's turn
	ExtendedMechanicPacks.ensure_player_state(p1)
	p1["invades_this_turn"] = 1

	# End p1's turn — the controller ability should fire (+1/+1)
	MatchTurnLoop.end_turn(match_state, p1["player_id"])
	var after_p1_turn_power := int(agent.get("power_bonus", 0))
	var after_p1_turn_health := int(agent.get("health_bonus", 0))

	# End p2's turn — the opponent_player ability should NOT fire (invade was last turn)
	MatchTurnLoop.end_turn(match_state, p2["player_id"])
	var after_p2_turn_power := int(agent.get("power_bonus", 0))
	var after_p2_turn_health := int(agent.get("health_bonus", 0))

	return (
		_assert(after_p1_turn_power == 1 and after_p1_turn_health == 1,
			"Agent should get +1/+1 at end of controller's turn when invaded. Got +%d/+%d." % [after_p1_turn_power, after_p1_turn_health]) and
		_assert(after_p2_turn_power == 1 and after_p2_turn_health == 1,
			"Agent should NOT get another +1/+1 at end of opponent's turn. Got +%d/+%d." % [after_p2_turn_power, after_p2_turn_health])
	)


func _test_pilfer_steal_from_discard_creates_choice_and_moves_to_discard() -> bool:
	# Mausoleum Delver: Pilfer should let player choose from opponent's discard,
	# then move the chosen card to the controller's discard (not hand).
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var active_pid := str(active_player["player_id"])
	var opponent_pid := str(opponent["player_id"])
	# Put a creature in the opponent's discard pile
	var opp_discarded := {
		"instance_id": "%s_discarded_creature" % opponent_pid,
		"definition_id": "test_opp_discarded",
		"owner_player_id": opponent_pid,
		"controller_player_id": opponent_pid,
		"zone": "discard",
		"card_type": "creature",
		"cost": 3, "power": 3, "health": 3, "base_power": 3, "base_health": 3,
		"damage_marked": 0, "keywords": [], "granted_keywords": [], "status_markers": [],
		"triggered_abilities": [], "power_bonus": 0, "health_bonus": 0,
	}
	opponent["discard"].append(opp_discarded)
	var opp_discarded_id := str(opp_discarded["instance_id"])
	var hand_before: int = active_player["hand"].size()
	var discard_before: int = active_player["discard"].size()
	# Summon a creature with pilfer: steal_from_discard
	var delver := _summon_creature(active_player, match_state, "delver", "field", 2, 5, [], 0, {
		"triggered_abilities": [{
			"family": "pilfer",
			"required_zone": "lane",
			"effects": [{"op": "steal_from_discard", "target_player": "opponent"}],
		}]
	})
	_target_ready_for_attack(delver, match_state)
	var result := MatchCombat.resolve_attack(match_state, active_pid, delver["instance_id"], {
		"type": "player",
		"player_id": opponent_pid,
	})
	# Pilfer should create a pending discard choice, NOT auto-steal
	var pending: Array = match_state.get("pending_discard_choices", [])
	if not (
		_assert(result["is_valid"], "Attack should resolve.") and
		_assert(active_player["hand"].size() == hand_before, "Hand should NOT grow — card should not go to hand. Was %d, now %d." % [hand_before, active_player["hand"].size()]) and
		_assert(not pending.is_empty(), "Should create a pending_discard_choices entry.") and
		_assert(pending[0].get("candidate_instance_ids", []).has(opp_discarded_id), "Opponent's discarded creature should be in candidates.") and
		_assert(str(pending[0].get("source_player_id", "")) == opponent_pid, "source_player_id should be the opponent.") and
		_assert(str(pending[0].get("then_op", "")) == "steal_to_discard", "then_op should be steal_to_discard.")
	):
		return false
	# Resolve the choice — card should move to controller's discard
	var resolve_result := MatchTiming.resolve_pending_discard_choice(match_state, active_pid, opp_discarded_id)
	var hand_after: int = active_player["hand"].size()
	var discard_after: int = active_player["discard"].size()
	var opp_discard_after: int = opponent["discard"].size()
	return (
		_assert(bool(resolve_result.get("is_valid", false)), "Resolve should succeed.") and
		_assert(hand_after == hand_before, "Hand should still be unchanged — card goes to discard, not hand. Was %d, now %d." % [hand_before, hand_after]) and
		_assert(discard_after == discard_before + 1, "Controller's discard should grow by 1. Was %d, now %d." % [discard_before, discard_after]) and
		_assert(opp_discard_after == 0, "Opponent's discard should be empty after steal. Got %d." % opp_discard_after)
	)


func _test_draw_from_deck_filtered_count_and_unique() -> bool:
	var match_state := _build_started_match(10, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Seed 4 distinct 1-cost creatures into opponent's deck (arquebus owner)
	_add_deck_card(opponent, "critter_a", {"card_type": "creature", "cost": 1, "power": 1, "health": 1})
	_add_deck_card(opponent, "critter_b", {"card_type": "creature", "cost": 1, "power": 1, "health": 1})
	_add_deck_card(opponent, "critter_c", {"card_type": "creature", "cost": 1, "power": 1, "health": 1})
	_add_deck_card(opponent, "critter_d", {"card_type": "creature", "cost": 1, "power": 1, "health": 1})
	# A 2-cost creature and an action that should NOT pass the filter
	_add_deck_card(opponent, "expensive", {"card_type": "creature", "cost": 2, "power": 2, "health": 2})
	_add_deck_card(opponent, "spell", {"card_type": "action", "cost": 1})
	# Opponent's creature with last_gasp: draw 3 unique 1-cost creatures
	var arquebus := _summon_creature(opponent, match_state, "arquebus", "field", 3, 3, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_LAST_GASP,
			"required_zone": "discard",
			"effects": [{"op": "draw_from_deck_filtered", "target_player": "controller", "filter": {"card_type": "creature", "max_cost": 1}, "count": 3, "unique": true}],
		}]
	})
	# Active player's creature kills it
	var attacker := _summon_creature(active_player, match_state, "attacker", "field", 5, 5, [], 0)
	_target_ready_for_attack(attacker, match_state)
	_target_ready_for_attack(arquebus, match_state)
	var hand_before: int = opponent.get("hand", []).size()
	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": arquebus["instance_id"],
	})
	var hand_after: int = opponent.get("hand", []).size()
	var drawn_count: int = hand_after - hand_before
	var hand: Array = opponent.get("hand", [])
	var unique_def_ids := {}
	for i in range(hand_before, hand_after):
		unique_def_ids[str(hand[i].get("definition_id", ""))] = true
	return (
		_assert(result["is_valid"], "Combat should resolve.") and
		_assert(drawn_count == 3, "Should draw 3 creatures from last_gasp. Got %d." % drawn_count) and
		_assert(unique_def_ids.size() == 3, "All 3 drawn cards should have different definition_ids. Got %d unique." % unique_def_ids.size())
	)


func _test_expertise_target_mode_swap_completes_at_turn_end() -> bool:
	# Regression: Guildsworn Honeytongue's expertise swap (target_mode: enemy_creature)
	# should queue as a pending turn trigger target, resolve the swap, then allow the
	# turn to complete. Previously the AI could sneak in extra actions after resolving
	# the swap because nothing forced the turn to end.
	var match_state := _build_started_match(20, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player["player_id"])
	var oid := str(opponent["player_id"])
	# Expertise creature with swap target_mode
	var honeytongue := _summon_creature(player, match_state, "honeytongue", "field", 0, 5, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_EXPERTISE,
			"required_zone": "lane",
			"target_mode": "enemy_creature",
			"effects": [{"op": "swap_creatures", "target": "chosen_target", "source": "self"}],
		}],
	})
	var enemy := _summon_creature(opponent, match_state, "enemy_target", "field", 3, 3)
	# Play a non-creature card to satisfy expertise condition
	var action_card := _add_hand_card(player, "expertise_ping", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 0}]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(action_card["instance_id"]), {"target_player_id": pid})
	# Queue expertise targets (simulates pressing End Turn)
	MatchTiming.queue_turn_trigger_targets(match_state, pid)
	if not _assert(MatchTiming.has_pending_turn_trigger_target(match_state, pid),
		"Expertise with target_mode should create a pending turn trigger target."):
		return false
	# Resolve the pending target — choose the enemy creature
	var resolve_result := MatchTiming.resolve_pending_turn_trigger_target(match_state, pid, {"instance_id": str(enemy["instance_id"])})
	if not _assert(bool(resolve_result.get("is_valid", false)), "Resolving expertise swap target should succeed."):
		return false
	# Verify swap: honeytongue now controlled by opponent, enemy by player
	if not _assert(str(honeytongue.get("controller_player_id", "")) == oid and str(enemy.get("controller_player_id", "")) == pid,
		"Swap should transfer control: honeytongue→opponent, enemy→player."):
		return false
	# No more pending targets
	if not _assert(not MatchTiming.has_pending_turn_trigger_target(match_state, pid),
		"No pending targets should remain after resolving the expertise swap."):
		return false
	# Complete the turn — must succeed
	var active_before := str(match_state.get("active_player_id", ""))
	MatchTurnLoop.end_turn(match_state, pid)
	return _assert(str(match_state.get("active_player_id", "")) != active_before,
		"Turn should advance after expertise swap resolves and end_turn is called.")


func _test_expertise_deal_damage_chosen_target_heals_and_draws() -> bool:
	# Regression: Vanus Galerion's expertise ("Deal 3 damage, you gain 3 health, draw 3 cards")
	# must prompt for a target for the damage op — hitting only the chosen creature (or player),
	# not auto-dealing to the opponent face. Heal and draw_cards should still fire on resolve.
	var match_state := _build_started_match(20, 0)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player["player_id"])
	var oid := str(opponent["player_id"])
	# Leave headroom for heal to be observable
	player["health"] = 20
	opponent["health"] = 20
	# Vanus-style expertise: deal_damage to chosen_target + heal controller + draw 3
	_summon_creature(player, match_state, "vanus", "field", 3, 3, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_EXPERTISE,
			"required_zone": "lane",
			"target_mode": "creature_or_player",
			"effects": [
				{"op": "deal_damage", "target": "chosen_target", "amount": 3},
				{"op": "heal", "target_player": "controller", "amount": 3},
				{"op": "draw_cards", "target_player": "controller", "count": 3},
			],
		}],
	})
	var enemy := _summon_creature(opponent, match_state, "enemy_target", "field", 3, 5)
	var hand_size_before := int(player["hand"].size())
	# Play a non-creature card to satisfy expertise condition
	var action_card := _add_hand_card(player, "expertise_ping", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 0}]}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(action_card["instance_id"]), {"target_player_id": pid})
	# hand_size_before was measured before adding/playing the ping; playing it removed 1 card, so
	# expected post-resolve hand size is hand_size_before + 3 (drew 3 from expertise)
	MatchTiming.queue_turn_trigger_targets(match_state, pid)
	if not _assert(MatchTiming.has_pending_turn_trigger_target(match_state, pid),
		"Expertise with target_mode should create a pending turn trigger target (did not fire auto-targeted)."):
		return false
	var resolve_result := MatchTiming.resolve_pending_turn_trigger_target(match_state, pid, {"instance_id": str(enemy["instance_id"])})
	if not _assert(bool(resolve_result.get("is_valid", false)), "Resolving expertise damage target should succeed."):
		return false
	var enemy_damage := int(enemy.get("damage_marked", 0))
	var player_hp := int(player.get("health", 0))
	var opponent_hp := int(opponent.get("health", 0))
	var hand_size_after := int(player["hand"].size())
	return (
		_assert(enemy_damage == 3, "Chosen creature should take 3 damage. Got damage_marked=%d." % enemy_damage) and
		_assert(opponent_hp == 20, "Opponent face should NOT be damaged when a creature was chosen. Got hp=%d." % opponent_hp) and
		_assert(player_hp == 23, "Controller should gain 3 health (20→23). Got hp=%d." % player_hp) and
		_assert(hand_size_after == hand_size_before + 3, "Controller should draw 3 cards. Hand before=%d after=%d." % [hand_size_before, hand_size_after])
	)


func _test_swap_creatures_preserves_lane_when_full() -> bool:
	# Regression: when swap_creatures fires and the target's controller already
	# has a full lane (4/4 slots), the swapped creature should still go into that
	# lane (taking the source's vacated slot), not overflow to another lane.
	var match_state := _build_started_match(20, 1)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player["player_id"])
	var oid := str(opponent["player_id"])
	# Fill opponent's field lane to capacity (4 creatures)
	var opp_filler_1 := _summon_creature(opponent, match_state, "opp_filler_1", "field", 1, 1)
	var opp_filler_2 := _summon_creature(opponent, match_state, "opp_filler_2", "field", 1, 1)
	var opp_filler_3 := _summon_creature(opponent, match_state, "opp_filler_3", "field", 1, 1)
	# Honeytongue-like creature for opponent in field (4th slot)
	var honeytongue := _summon_creature(opponent, match_state, "honeytongue", "field", 0, 5, [], -1, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_EXPERTISE,
			"required_zone": "lane",
			"target_mode": "enemy_creature",
			"effects": [{"op": "swap_creatures", "target": "chosen_target", "source": "self"}],
		}],
	})
	# Player has 1 creature in field lane
	var player_target := _summon_creature(player, match_state, "player_target", "field", 3, 3)
	# Play an action to satisfy expertise (opponent is active player)
	var action_card := _add_hand_card(opponent, "expertise_ping", {
		"card_type": "action", "cost": 0,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "required_zone": "discard", "effects": [{"op": "damage", "target_player": "target_player", "amount": 0}]}],
	})
	MatchTiming.play_action_from_hand(match_state, oid, str(action_card["instance_id"]), {"target_player_id": oid})
	MatchTiming.queue_turn_trigger_targets(match_state, oid)
	if not _assert(MatchTiming.has_pending_turn_trigger_target(match_state, oid),
		"[swap_full] Expertise should queue a pending turn trigger target."):
		return false
	# Resolve the swap targeting player's creature
	var resolve_result := MatchTiming.resolve_pending_turn_trigger_target(match_state, oid, {"instance_id": str(player_target["instance_id"])})
	if not _assert(bool(resolve_result.get("is_valid", false)), "[swap_full] Resolving swap should succeed."):
		return false
	# Verify control swapped
	if not _assert(str(honeytongue.get("controller_player_id", "")) == pid,
		"[swap_full] Honeytongue should now be controlled by player."):
		return false
	if not _assert(str(player_target.get("controller_player_id", "")) == oid,
		"[swap_full] Player target should now be controlled by opponent."):
		return false
	# Critical: both creatures should still be in the field lane
	if not _assert(str(honeytongue.get("lane_id", "")) == "field",
		"[swap_full] Honeytongue should remain in field lane, got: %s" % str(honeytongue.get("lane_id", ""))):
		return false
	return _assert(str(player_target.get("lane_id", "")) == "field",
		"[swap_full] Player target should remain in field lane (not overflow), got: %s" % str(player_target.get("lane_id", "")))


func _test_on_friendly_pilfer_or_drain_requires_pilfer_or_drain() -> bool:
	# Regression: Brynjolf's on_friendly_pilfer_or_drain fired for any friendly
	# creature dealing damage to the enemy player, even without pilfer or drain.
	var match_state := _build_started_match(20, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(active_player["player_id"])
	# Observer with on_friendly_pilfer_or_drain — gains +0/+1 when triggered
	var observer := _summon_creature(active_player, match_state, "observer", "field", 4, 5, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_FRIENDLY_PILFER_OR_DRAIN,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 1}],
		}]
	})
	# Creature with NO pilfer or drain — should NOT trigger observer
	var plain := _summon_creature(active_player, match_state, "plain", "field", 2, 2, [], 0)
	_target_ready_for_attack(plain, match_state)
	var plain_result := MatchCombat.resolve_attack(match_state, pid, plain["instance_id"], {
		"type": "player", "player_id": opponent["player_id"],
	})
	if not (
		_assert(plain_result["is_valid"], "Plain attack should resolve.") and
		_assert(int(observer.get("health_bonus", 0)) == 0,
			"Observer should NOT fire for creature without pilfer/drain. health_bonus: %d." % int(observer.get("health_bonus", 0)))
	):
		return false
	# Creature with pilfer — SHOULD trigger observer
	var pilferer := _summon_creature(active_player, match_state, "pilferer", "field", 1, 1, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_PILFER,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	_target_ready_for_attack(pilferer, match_state)
	var pilfer_result := MatchCombat.resolve_attack(match_state, pid, pilferer["instance_id"], {
		"type": "player", "player_id": opponent["player_id"],
	})
	if not (
		_assert(pilfer_result["is_valid"], "Pilfer attack should resolve.") and
		_assert(int(observer.get("health_bonus", 0)) == 1,
			"Observer SHOULD fire for creature with pilfer. health_bonus: %d." % int(observer.get("health_bonus", 0)))
	):
		return false
	# Creature with drain — SHOULD trigger observer
	var drainer := _summon_creature(active_player, match_state, "drainer", "field", 1, 1, ["drain"], 0)
	_target_ready_for_attack(drainer, match_state)
	var drain_result := MatchCombat.resolve_attack(match_state, pid, drainer["instance_id"], {
		"type": "player", "player_id": opponent["player_id"],
	})
	return (
		_assert(drain_result["is_valid"], "Drain attack should resolve.") and
		_assert(int(observer.get("health_bonus", 0)) == 2,
			"Observer SHOULD fire for creature with drain. health_bonus: %d." % int(observer.get("health_bonus", 0)))
	)


func _test_filter_keyword_matches_triggered_ability_families() -> bool:
	# Regression: Smash and Grab (target: all_friendly_with_keyword, filter_keyword: pilfer)
	# failed to buff pilfer creatures because filter_keyword used has_keyword() which only
	# checks the keywords array, not triggered_abilities families.
	var match_state := _build_started_match(20, 0)
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Creature with pilfer as a triggered ability family (not a keyword)
	var pilferer := _summon_creature(player, match_state, "pilferer", "field", 1, 1, [], 0, {
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_PILFER,
			"required_zone": "lane",
			"effects": [{"op": "modify_stats", "target": "self", "power": 1, "health": 0}],
		}]
	})
	# Creature without pilfer — should NOT be buffed
	var plain := _summon_creature(player, match_state, "plain", "field", 2, 2)
	# Smash and Grab: on_play, modify_stats targeting all_friendly_with_keyword filtered by pilfer
	var smash := _add_hand_card(player, "smash_and_grab", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_PLAY,
			"effects": [
				{"op": "modify_stats", "target": "all_friendly_with_keyword", "filter_keyword": "pilfer", "power": 2, "health": 0, "expires_end_of_turn": true},
				{"op": "grant_keyword", "target": "all_friendly_with_keyword", "filter_keyword": "pilfer", "keyword_id": "breakthrough", "expires_end_of_turn": true},
			],
		}],
	})
	MatchTiming.play_action_from_hand(match_state, pid, str(smash["instance_id"]), {})
	return (
		_assert(int(pilferer.get("power_bonus", 0)) == 2,
			"Pilferer should get +2 power from Smash and Grab. Got: +%d." % int(pilferer.get("power_bonus", 0))) and
		_assert(int(plain.get("power_bonus", 0)) == 0,
			"Plain creature should NOT be buffed. Got: +%d." % int(plain.get("power_bonus", 0)))
	)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false