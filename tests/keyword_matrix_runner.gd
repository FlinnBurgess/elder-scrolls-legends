extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")
const MatchScreen = preload("res://src/ui/match_screen.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("KEYWORD_MATRIX_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_registry_exposes_expected_evergreen_ids() and
		_test_ward_blocks_damage_once_and_prevents_lethal() and
		_test_regenerate_and_shackle_refresh_on_controller_turn() and
		_test_shackle_makes_creature_skip_next_attack_turn() and
		_test_opponent_shackle_clears_on_targets_turn_after_next() and
		_test_silenced_suppresses_guard_and_cover_behavior() and
		_test_rally_buffs_a_deterministic_hand_creature() and
		_test_rally_stacks_multiple_triggers() and
		_test_rally_amount_field_grants_intrinsic_extra_stacks() and
		_test_rally_boost_aura_grants_extra_stack_to_other_rallies() and
		_test_rally_boost_aura_does_not_buff_self() and
		_test_rally_boost_aura_silenced_source_does_not_grant() and
		_test_balmora_captain_catalog_and_hydration_preserve_rally_fields() and
		_test_rally_on_rally_trigger_buffs_item_in_hand() and
		_test_mobilize_exposes_empty_lane_options_and_recruit_template()
	)


func _test_registry_exposes_expected_evergreen_ids() -> bool:
	var keywords := EvergreenRules.get_supported_keywords()
	var statuses := EvergreenRules.get_supported_statuses()
	return (
		_assert(keywords.has("ward") and keywords.has("regenerate") and keywords.has("rally") and keywords.has("mobilize"), "Evergreen registry should expose the approved keyword set.") and
		_assert(statuses.has("cover") and statuses.has("shackled") and statuses.has("silenced") and statuses.has("wounded") and statuses.has("exalted"), "Evergreen registry should expose the shared status set.")
	)


func _test_ward_blocks_damage_once_and_prevents_lethal() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "lethal_attacker", "field", 4, 4, ["lethal"])
	var defender := _summon_creature(opponent, match_state, "warded_defender", "field", 2, 2, ["ward"])
	_target_ready_for_attack(attacker, match_state)
	_target_ready_for_attack(defender, match_state)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": defender["instance_id"],
	})
	if not (
		_assert(result["is_valid"], "Ward scenario should resolve successfully.") and
		_assert(not result["defender_destroyed"], "Ward should prevent the first incoming damage and lethal destruction.") and
		_assert(not EvergreenRules.has_keyword(defender, "ward"), "Ward should be removed after preventing damage.") and
		_assert(int(defender.get("damage_marked", 0)) == 0, "Ward should prevent combat damage entirely.") and
		_assert(int(attacker.get("damage_marked", 0)) == 2, "Defender should still strike back normally.") and
		_assert(EvergreenRules.has_status(attacker, "wounded"), "Damage-marked creatures should track the Wounded status.")
	):
		return false
	return _has_event(result["events"], "ward_removed")


func _test_regenerate_and_shackle_refresh_on_controller_turn() -> bool:
	var match_state := _build_started_match(18, 0)
	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]
	var creature := _summon_creature(first_player, match_state, "regen_target", "shadow", 3, 5, ["regenerate"])
	_target_ready_for_attack(creature, match_state)
	creature["damage_marked"] = 3
	EvergreenRules.add_status(creature, "wounded")
	EvergreenRules.add_status(creature, "shackled")
	creature["cover_expires_on_turn"] = int(match_state.get("turn_number", 0))

	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	MatchTurnLoop.end_turn(match_state, second_player["player_id"])

	return (
		_assert(int(creature.get("damage_marked", 0)) == 0, "Regenerate should fully heal the creature at the start of its controller turn.") and
		_assert(not EvergreenRules.has_status(creature, "wounded"), "Regenerate healing should clear the Wounded status.") and
		_assert(not EvergreenRules.has_status(creature, "shackled"), "Shackled should clear on the controller's next turn refresh.") and
		_assert(not EvergreenRules.has_status(creature, "cover"), "Temporary shadow-lane Cover should expire on the controller's next turn refresh.")
	)


func _test_shackle_makes_creature_skip_next_attack_turn() -> bool:
	# Regression: previously shackle was cleared at the start of the controller's
	# very next turn, so the shackled creature never actually skipped an attack
	# (Encumbered Explorer attacked every turn).
	var match_state := _build_started_match(18, 0)
	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(first_player, match_state, "shackled_attacker", "field", 3, 3)
	_target_ready_for_attack(attacker, match_state)
	# Apply shackle the same way the engine does (matches effect_keywords.gd).
	EvergreenRules.add_status(attacker, EvergreenRules.STATUS_SHACKLED)
	attacker["shackle_expires_on_turn"] = int(match_state.get("turn_number", 0)) + 2

	# Advance to the controller's next turn (their attack should be skipped).
	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	MatchTurnLoop.end_turn(match_state, second_player["player_id"])
	if not _assert(EvergreenRules.has_status(attacker, EvergreenRules.STATUS_SHACKLED), "Shackle should still be active on the controller's next turn so the creature skips its attack."):
		return false
	var blocked := MatchCombat.validate_attack(match_state, first_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": second_player["player_id"],
	})
	if not _assert(not bool(blocked.get("is_valid", false)), "Shackled creature must not be allowed to attack on its controller's next turn."):
		return false

	# Advance one more round; shackle should now clear and the creature can attack.
	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	MatchTurnLoop.end_turn(match_state, second_player["player_id"])
	return (
		_assert(not EvergreenRules.has_status(attacker, EvergreenRules.STATUS_SHACKLED), "Shackle should clear on the controller's turn after the skipped one.") and
		_assert(not attacker.has("shackle_expires_on_turn"), "shackle_expires_on_turn should be erased once the shackle expires.")
	)


func _test_opponent_shackle_clears_on_targets_turn_after_next() -> bool:
	# Regression: a creature shackled by the opponent (e.g., Shrieking Harpy targeting
	# Alduin) used to remain shackled for two of the controller's turns instead of one,
	# because _refresh_board_state_for_turn runs before turn_number is incremented and
	# the previous strict-< comparison against expires_on_turn (apply_turn + 2) was
	# off-by-one for the opponent-shackle case.
	var match_state := _build_started_match(18, 0)
	var first_player: Dictionary = match_state["players"][0]
	var second_player: Dictionary = match_state["players"][1]
	var target := _summon_creature(first_player, match_state, "shackled_target", "field", 5, 5)
	_target_ready_for_attack(target, match_state)
	# Hand turn over to the opponent so they're the one applying the shackle.
	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	# Apply shackle from the opponent's turn the same way the engine does.
	EvergreenRules.add_status(target, EvergreenRules.STATUS_SHACKLED)
	target["shackle_expires_on_turn"] = int(match_state.get("turn_number", 0)) + 2
	# Advance to the controller's next turn — they should still be shackled and unable to attack.
	MatchTurnLoop.end_turn(match_state, second_player["player_id"])
	if not _assert(EvergreenRules.has_status(target, EvergreenRules.STATUS_SHACKLED), "Opponent-applied shackle should persist through the target's next turn so they skip their attack."):
		return false
	var blocked := MatchCombat.validate_attack(match_state, first_player["player_id"], target["instance_id"], {
		"type": "player",
		"player_id": second_player["player_id"],
	})
	if not _assert(not bool(blocked.get("is_valid", false)), "Opponent-shackled creature must not be allowed to attack on its controller's next turn."):
		return false
	# Advance one more round; shackle should clear so the target can attack again.
	MatchTurnLoop.end_turn(match_state, first_player["player_id"])
	MatchTurnLoop.end_turn(match_state, second_player["player_id"])
	return (
		_assert(not EvergreenRules.has_status(target, EvergreenRules.STATUS_SHACKLED), "Opponent-applied shackle must clear on the controller's turn after the skipped one (not two turns later).") and
		_assert(not target.has("shackle_expires_on_turn"), "shackle_expires_on_turn should be erased once the shackle expires.")
	)


func _test_silenced_suppresses_guard_and_cover_behavior() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "attacker", "field", 3, 3)
	_target_ready_for_attack(attacker, match_state)
	var silenced_target := _summon_creature(opponent, match_state, "silenced_guard", "field", 2, 4, ["guard"], 0, {
		"status_markers": ["cover", "silenced"],
		"cover_expires_on_turn": int(match_state.get("turn_number", 0)),
	})

	var player_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	var target_validation := MatchCombat.validate_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "creature",
		"instance_id": silenced_target["instance_id"],
	})

	return (
		_assert(player_validation["is_valid"], "Silenced Guard should not keep intercepting direct attacks.") and
		_assert(target_validation["is_valid"], "Silenced Cover should not keep preventing creature attacks.")
	)


func _test_rally_buffs_a_deterministic_hand_creature() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "rally_attacker", "field", 3, 3, ["rally"])
	_target_ready_for_attack(attacker, match_state)
	var first_hand_creature := _append_hand_creature(active_player, "hand_one", 2, 2)
	var second_hand_creature := _append_hand_creature(active_player, "hand_two", 4, 4)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "Rally attack should resolve successfully."):
		return false
	var buffed_creatures := 0
	for card in [first_hand_creature, second_hand_creature]:
		if int(card.get("power_bonus", 0)) == 1 and int(card.get("health_bonus", 0)) == 1:
			buffed_creatures += 1
	if not _assert(buffed_creatures == 1, "Rally should buff exactly one creature in hand."):
		return false
	return _has_event(result["events"], "rally_resolved")


func _test_rally_stacks_multiple_triggers() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "double_rally", "field", 3, 3, ["rally", "rally"])
	_target_ready_for_attack(attacker, match_state)
	var hand_creature := _append_hand_creature(active_player, "hand_target", 2, 2)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "Double rally attack should resolve successfully."):
		return false
	if not _assert(int(hand_creature.get("power_bonus", 0)) == 2, "Double rally should grant +2 power total."):
		return false
	if not _assert(int(hand_creature.get("health_bonus", 0)) == 2, "Double rally should grant +2 health total."):
		return false
	var rally_event_count := 0
	for event in result.get("events", []):
		if str(event.get("event_type", "")) == "rally_resolved":
			rally_event_count += 1
	return _assert(rally_event_count == 2, "Double rally should emit two rally_resolved events.")


func _test_rally_amount_field_grants_intrinsic_extra_stacks() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "rally_amount_2", "field", 4, 4, ["rally"])
	attacker["rally_amount"] = 2
	_target_ready_for_attack(attacker, match_state)
	var hand_creature := _append_hand_creature(active_player, "ra_hand", 2, 2)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "rally_amount attack should resolve."):
		return false
	if not _assert(int(hand_creature.get("power_bonus", 0)) == 2, "rally_amount: 2 should grant +2 power total."):
		return false
	if not _assert(int(hand_creature.get("health_bonus", 0)) == 2, "rally_amount: 2 should grant +2 health total."):
		return false
	var rally_event_count := 0
	for event in result.get("events", []):
		if str(event.get("event_type", "")) == "rally_resolved":
			rally_event_count += 1
	return _assert(rally_event_count == 2, "rally_amount: 2 should emit two rally_resolved events.")


func _test_rally_boost_aura_grants_extra_stack_to_other_rallies() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "rally_attacker", "field", 3, 3, ["rally"])
	_target_ready_for_attack(attacker, match_state)
	var aura_source := _summon_creature(active_player, match_state, "balmora_captain", "shadow", 4, 4)
	aura_source["rally_boost_aura"] = true
	var hand_creature := _append_hand_creature(active_player, "boosted_hand", 2, 2)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "Rally with aura source should resolve."):
		return false
	if not _assert(int(hand_creature.get("power_bonus", 0)) == 2, "rally_boost_aura should add +1 stack: total +2 power. Got: %d" % int(hand_creature.get("power_bonus", 0))):
		return false
	if not _assert(int(hand_creature.get("health_bonus", 0)) == 2, "rally_boost_aura should add +1 stack: total +2 health."):
		return false
	var rally_event_count := 0
	for event in result.get("events", []):
		if str(event.get("event_type", "")) == "rally_resolved":
			rally_event_count += 1
	return _assert(rally_event_count == 2, "rally_boost_aura should produce one extra rally_resolved event (total 2).")


func _test_rally_boost_aura_does_not_buff_self() -> bool:
	# Balmora Captain has both rally_amount: 2 and rally_boost_aura.
	# His own attack should fire Rally 2 (intrinsic) — NOT Rally 3 ("your OTHER rallies").
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "balmora_solo", "field", 4, 4, ["rally"])
	attacker["rally_amount"] = 2
	attacker["rally_boost_aura"] = true
	_target_ready_for_attack(attacker, match_state)
	var hand_creature := _append_hand_creature(active_player, "self_aura_hand", 2, 2)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "Self-aura rally attack should resolve."):
		return false
	return _assert(int(hand_creature.get("power_bonus", 0)) == 2, "Aura source must not buff its own rally — expected +2, got: %d" % int(hand_creature.get("power_bonus", 0)))


func _test_rally_boost_aura_silenced_source_does_not_grant() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var attacker := _summon_creature(active_player, match_state, "silenced_aura_atk", "field", 3, 3, ["rally"])
	_target_ready_for_attack(attacker, match_state)
	var aura_source := _summon_creature(active_player, match_state, "silenced_balmora", "shadow", 4, 4)
	aura_source["rally_boost_aura"] = true
	EvergreenRules.add_status(aura_source, EvergreenRules.STATUS_SILENCED)
	var hand_creature := _append_hand_creature(active_player, "silenced_aura_hand", 2, 2)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "Rally with silenced aura source should resolve."):
		return false
	return _assert(int(hand_creature.get("power_bonus", 0)) == 1, "Silenced rally_boost_aura must not grant extra stack — expected +1, got: %d" % int(hand_creature.get("power_bonus", 0)))


func _test_balmora_captain_catalog_and_hydration_preserve_rally_fields() -> bool:
	# Regression: rally_amount and rally_boost_aura must survive both
	# the catalog seed pipeline AND the match_screen hydration pipeline,
	# since lane creatures in test/puzzle/saved matches are stub-built then hydrated.
	var catalog := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog.get("card_by_id", {})
	var balmora: Dictionary = card_by_id.get("hom_wil_balmora_captain", {})
	if not (
		_assert(not balmora.is_empty(), "Balmora Captain must exist in catalog.") and
		_assert(int(balmora.get("rally_amount", 0)) == 2, "Catalog Balmora Captain must carry rally_amount: 2.") and
		_assert(bool(balmora.get("rally_boost_aura", false)), "Catalog Balmora Captain must carry rally_boost_aura: true.")
	):
		return false
	var stub_card := {"definition_id": "hom_wil_balmora_captain", "instance_id": "test_balmora", "keywords": []}
	MatchScreen._hydrate_card(stub_card, card_by_id)
	return (
		_assert(int(stub_card.get("rally_amount", 0)) == 2, "Hydration must preserve rally_amount on lane stub cards.") and
		_assert(bool(stub_card.get("rally_boost_aura", false)), "Hydration must preserve rally_boost_aura on lane stub cards.")
	)


func _test_mobilize_exposes_empty_lane_options_and_recruit_template() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	_summon_creature(active_player, match_state, "occupied_lane", "field", 2, 2)
	var options := EvergreenRules.get_mobilize_lane_options(match_state, active_player["player_id"])
	var recruit := EvergreenRules.build_mobilize_recruit(active_player["player_id"], "mobilize_recruit")
	return (
		_assert(options.size() == 1 and str(options[0].get("lane_id", "")) == "shadow", "Mobilize should only offer empty friendly lanes for Recruit creation.") and
		_assert(recruit["card_type"] == "creature" and recruit["power"] == 1 and recruit["health"] == 1, "Mobilize Recruit template should be a 1/1 creature token.") and
		_assert(recruit["rules_tags"].has("mobilize"), "Mobilize Recruit template should carry the mobilize provenance tag.")
	)


func _build_started_match(deck_size: int, first_player_index: int) -> Dictionary:
	var match_state := MatchBootstrap.create_standard_match([
		_build_deck("alpha", deck_size),
		_build_deck("beta", deck_size)
	], {
		"seed": 37,
		"first_player_index": first_player_index,
	})
	if match_state.is_empty():
		return {}
	for player in match_state["players"]:
		MatchBootstrap.apply_mulligan(match_state, player["player_id"], [])
	MatchTurnLoop.begin_first_turn(match_state)
	return match_state


func _summon_creature(player: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int, keywords: Array = [], slot_index := -1, extra: Dictionary = {}) -> Dictionary:
	var card := {
		"instance_id": "%s_%s" % [player["player_id"], label],
		"definition_id": "test_%s" % label,
		"owner_player_id": player["player_id"],
		"controller_player_id": player["player_id"],
		"zone": "hand",
		"card_type": "creature",
		"power": power,
		"health": health,
		"keywords": keywords.duplicate(),
		"granted_keywords": [],
		"status_markers": extra.get("status_markers", []).duplicate(),
		"damage_marked": int(extra.get("damage_marked", 0)),
		"power_bonus": int(extra.get("power_bonus", 0)),
		"health_bonus": int(extra.get("health_bonus", 0)),
	}
	if extra.has("cover_expires_on_turn"):
		card["cover_expires_on_turn"] = int(extra.get("cover_expires_on_turn", -1))
	player["hand"].append(card)
	var summon_options := {}
	if slot_index >= 0:
		summon_options["slot_index"] = slot_index
	var result := LaneRules.summon_from_hand(match_state, player["player_id"], card["instance_id"], lane_id, summon_options)
	_assert(result["is_valid"], "Expected summon fixture for %s to succeed." % label)
	if bool(extra.get("cover", false)):
		EvergreenRules.grant_cover(card, int(match_state.get("turn_number", 0)))
	if int(card.get("damage_marked", 0)) > 0:
		EvergreenRules.add_status(card, "wounded")
	return card


func _append_hand_creature(player: Dictionary, label: String, power: int, health: int) -> Dictionary:
	var card := {
		"instance_id": "%s_%s" % [player["player_id"], label],
		"definition_id": "test_%s" % label,
		"owner_player_id": player["player_id"],
		"controller_player_id": player["player_id"],
		"zone": "hand",
		"card_type": "creature",
		"power": power,
		"health": health,
		"keywords": [],
		"granted_keywords": [],
		"status_markers": [],
		"damage_marked": 0,
		"power_bonus": 0,
		"health_bonus": 0,
	}
	player["hand"].append(card)
	return card


func _test_rally_on_rally_trigger_buffs_item_in_hand() -> bool:
	var match_state := _build_started_match(18, 0)
	var active_player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	# Seasoned Captain: rally + on_rally trigger that buffs a random item in hand
	var attacker := _summon_creature(active_player, match_state, "seasoned_captain", "field", 4, 4, ["rally"])
	attacker["triggered_abilities"] = [{"family": "on_rally", "required_zone": "lane", "effects": [{"op": "modify_random_item_in_hand", "power": 1, "health": 1}]}]
	_target_ready_for_attack(attacker, match_state)
	# Also put a creature in hand (rally should buff it)
	var hand_creature := _append_hand_creature(active_player, "hand_creature", 2, 2)
	# Put an item in hand
	var hand_item := {
		"instance_id": "%s_hand_item" % active_player["player_id"],
		"definition_id": "test_dagger",
		"owner_player_id": active_player["player_id"],
		"controller_player_id": active_player["player_id"],
		"zone": "hand",
		"card_type": "item",
		"name": "Test Dagger",
		"cost": 1,
		"power": 0,
		"health": 0,
		"keywords": [],
		"granted_keywords": [],
		"status_markers": [],
		"damage_marked": 0,
		"power_bonus": 0,
		"health_bonus": 0,
		"equip_power_bonus": 2,
		"equip_health_bonus": 0,
	}
	active_player["hand"].append(hand_item)

	var result := MatchCombat.resolve_attack(match_state, active_player["player_id"], attacker["instance_id"], {
		"type": "player",
		"player_id": opponent["player_id"],
	})
	if not _assert(result["is_valid"], "On_rally attack should resolve successfully."):
		return false
	# Rally should buff the creature in hand
	if not _assert(int(hand_creature.get("power_bonus", 0)) == 1, "Rally should buff hand creature power."):
		return false
	# On_rally trigger should buff the item's equip bonuses
	if not _assert(int(hand_item.get("equip_power_bonus", 0)) == 3, "On_rally should buff item equip_power_bonus from 2 to 3. Got: %d" % int(hand_item.get("equip_power_bonus", 0))):
		return false
	if not _assert(int(hand_item.get("equip_health_bonus", 0)) == 1, "On_rally should buff item equip_health_bonus from 0 to 1. Got: %d" % int(hand_item.get("equip_health_bonus", 0))):
		return false
	# apply_stat_bonus must also set power_bonus/health_bonus so the UI shows the buff
	if not _assert(int(hand_item.get("power_bonus", 0)) == 1, "On_rally should set item power_bonus for UI display. Got: %d" % int(hand_item.get("power_bonus", 0))):
		return false
	if not _assert(int(hand_item.get("health_bonus", 0)) == 1, "On_rally should set item health_bonus for UI display. Got: %d" % int(hand_item.get("health_bonus", 0))):
		return false
	return _has_event(result["events"], "item_in_hand_modified")


func _target_ready_for_attack(card: Dictionary, match_state: Dictionary) -> void:
	card["entered_lane_on_turn"] = int(match_state.get("turn_number", 0)) - 1
	card["has_attacked_this_turn"] = false
	EvergreenRules.remove_status(card, "shackled")


func _build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if str(event.get("event_type", "")) == event_type:
			return true
	return false


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false