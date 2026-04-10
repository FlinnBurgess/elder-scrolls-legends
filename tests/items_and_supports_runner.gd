extends SceneTree

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return
	print("ITEMS_AND_SUPPORTS_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_invalid_item_target_does_not_spend_magicka() and
		_test_items_attach_and_route_to_owner_discard() and
		_test_supports_persist_and_trigger_from_support_zone() and
		_test_support_activations_are_once_per_turn_and_use_limited() and
		_test_mobilize_items_create_recruits_and_attach_equipment() and
		_test_plot_item_reduces_random_hand_card_cost() and
		_test_on_support_count_reached_waits_for_threshold() and
		_test_item_on_play_target_no_valid_targets_allows_decline() and
		_test_horse_armor_sets_premium_on_wielder() and
		_test_fifth_support_rejected_when_zone_full() and
		_test_play_support_with_sacrifice() and
		_test_play_support_sacrifice_rejects_when_not_full() and
		_test_support_on_play_target_mode_queues_pending_target() and
		_test_support_on_play_target_grants_crowned_status() and
		_test_crowned_creatures_receive_end_of_turn_buff() and
		_test_auto_crown_skips_when_crowned_creature_exists() and
		_test_altar_of_despair_escalating_cost() and
		_test_altar_of_despair_sweet_roll_fallback() and
		_test_orsinium_forge_escalates_plate_stats_per_use() and
		_test_skyshard_on_card_drawn_buffs_creature()
	)


func _test_invalid_item_target_does_not_spend_magicka() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var item := _add_hand_card(player, "invalid_target_item", {
		"card_type": "item",
		"cost": 3,
		"equip_power_bonus": 2,
	})
	var magicka_before: int = player["current_magicka"]
	var result := PersistentCardRules.play_item_from_hand(match_state, player["player_id"], item["instance_id"], {"target_instance_id": "missing_target"})
	return (
		_assert(not result["is_valid"], "Playing an item at a missing target should fail.") and
		_assert(player["current_magicka"] == magicka_before, "Invalid item play should not spend magicka before target validation.") and
		_assert(_contains_instance(player["hand"], item["instance_id"]), "Invalid item play should leave the item in hand.")
	)


func _test_items_attach_and_route_to_owner_discard() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var host := _summon_creature(player, match_state, "host", "field", 2, 3, 0)
	var item := _add_hand_card(player, "steel_sword", {
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 2,
		"equip_health_bonus": 1,
		"equip_keywords": ["guard"],
	})
	var play_result := PersistentCardRules.play_item_from_hand(match_state, player["player_id"], item["instance_id"], {"target_instance_id": host["instance_id"]})
	var attached_location := MatchMutations.find_card_location(match_state, item["instance_id"])
	if not (
		_assert(play_result["is_valid"], "Expected item play onto an existing creature to succeed.") and
		_assert(host.get("attached_items", []).size() == 1, "Host creature should retain the equipped item as attached state.") and
		_assert(attached_location["is_valid"] and str(attached_location.get("zone", "")) == MatchMutations.ZONE_ATTACHED_ITEM, "Shared mutation lookup should find attached items by instance id.") and
		_assert(EvergreenRules.get_power(host) == 4 and EvergreenRules.get_health(host) == 4, "Attached item should contribute equipment stat bonuses through EvergreenRules.") and
		_assert(EvergreenRules.has_keyword(host, "guard"), "Attached item should contribute equipment keywords through EvergreenRules.")
	):
		return false

	var silence_result := MatchMutations.silence_card(host, {"reason": "test_silence"}, match_state)
	if not (
		_assert(silence_result["is_valid"], "Silence should succeed on an equipped creature.") and
		_assert(host.get("attached_items", []).is_empty(), "Silence should remove attached items from the host.") and
		_assert(EvergreenRules.get_power(host) == 2 and EvergreenRules.get_health(host) == 3, "Silence should leave the host at its base stats once equipment is removed.") and
		_assert(_contains_instance(player["discard"], item["instance_id"]), "Silence should route attached items to the owner's discard pile.")
	):
		return false

	var second_host := _summon_creature(player, match_state, "second_host", "shadow", 3, 3, 0)
	var second_item := _add_hand_card(player, "battle_axe", {
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 3,
	})
	var second_play := PersistentCardRules.play_item_from_hand(match_state, player["player_id"], second_item["instance_id"], {"target_instance_id": second_host["instance_id"]})
	var discard_host := MatchMutations.discard_card(match_state, second_host["instance_id"], {"reason": "host_destroyed"})
	return (
		_assert(second_play["is_valid"], "Second item attachment fixture should succeed.") and
		_assert(discard_host["is_valid"], "Discarding an equipped host should succeed.") and
		_assert(_contains_instance(player["discard"], second_item["instance_id"]), "Leaving play should also route attached items to the owner's discard pile.")
	)


func _test_supports_persist_and_trigger_from_support_zone() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var hand_before: int = player["hand"].size()
	var support := _add_hand_card(player, "war_banner", {
		"card_type": "support",
		"cost": 2,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_START_OF_TURN,
			"required_zone": "support",
			"effects": [{"op": "draw_cards", "target_player": "controller", "count": 1}],
		}],
	})
	var play_result := PersistentCardRules.play_support_from_hand(match_state, player["player_id"], support["instance_id"])
	if not (
		_assert(play_result["is_valid"], "Support play should move the card into the support zone.") and
		_assert(_contains_instance(player["support"], support["instance_id"]), "Played supports should remain in the dedicated support zone.") and
		_assert(player["hand"].size() == hand_before, "Playing the added support should consume the injected hand card and return the hand to baseline size.")
	):
		return false

	MatchTurnLoop.end_turn(match_state, player["player_id"])
	MatchTurnLoop.end_turn(match_state, match_state["active_player_id"])
	return (
		_assert(_contains_instance(player["support"], support["instance_id"]), "Support should persist on board across turn changes.") and
		_assert(player["hand"].size() == hand_before + 2, "Persistent support should trigger from the support zone on its controller's next turn in addition to the normal draw.")
	)


func _test_support_activations_are_once_per_turn_and_use_limited() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var target := _summon_creature(player, match_state, "target", "field", 2, 2, 0)
	var support := _add_hand_card(player, "arsenal", {
		"card_type": "support",
		"cost": 1,
		"activation_cost": 1,
		"support_uses": 2,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [{"op": "grant_keyword", "target": "event_target", "keyword_id": "guard"}],
		}],
	})
	var play_result := PersistentCardRules.play_support_from_hand(match_state, player["player_id"], support["instance_id"])
	var first_activation := PersistentCardRules.activate_support(match_state, player["player_id"], support["instance_id"], {"target_instance_id": target["instance_id"]})
	var second_activation_same_turn := PersistentCardRules.activate_support(match_state, player["player_id"], support["instance_id"], {"target_instance_id": target["instance_id"]})
	if not (
		_assert(play_result["is_valid"], "Support activation fixture should enter the support zone successfully.") and
		_assert(first_activation["is_valid"], "First support activation should succeed.") and
		_assert(EvergreenRules.has_keyword(target, "guard"), "Activate triggers should resolve through the shared timing engine onto the event target.") and
		_assert(not second_activation_same_turn["is_valid"], "Support should reject a second activation in the same turn.") and
		_assert(int(support.get("remaining_support_uses", -1)) == 1, "First activation should decrement remaining support uses.")
	):
		return false

	MatchTurnLoop.end_turn(match_state, player["player_id"])
	MatchTurnLoop.end_turn(match_state, match_state["active_player_id"])
	var second_activation := PersistentCardRules.activate_support(match_state, player["player_id"], support["instance_id"], {"target_instance_id": target["instance_id"]})
	return (
		_assert(second_activation["is_valid"], "Support should refresh and become activatable on its controller's next turn.") and
		_assert(_contains_instance(player["discard"], support["instance_id"]), "Limited-use support should discard itself when its final use is spent.") and
		_assert(not _contains_instance(player["support"], support["instance_id"]), "Exhausted limited-use support should no longer remain in the support zone.")
	)


func _test_mobilize_items_create_recruits_and_attach_equipment() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var mobilize_item := _add_hand_card(player, "training_gear", {
		"card_type": "item",
		"cost": 2,
		"keywords": [EvergreenRules.KEYWORD_MOBILIZE],
		"equip_power_bonus": 1,
		"equip_health_bonus": 2,
		"equip_keywords": ["ward"],
	})
	var play_result := PersistentCardRules.play_item_from_hand(match_state, player["player_id"], mobilize_item["instance_id"], {"lane_id": "shadow"})
	var recruit := _find_lane_card(match_state, "shadow", player["player_id"], "generated_recruit")
	return (
		_assert(play_result["is_valid"], "Mobilize item should succeed without an explicit target when an empty lane is provided.") and
		_assert(not recruit.is_empty(), "Mobilize should create a Recruit in the requested empty lane.") and
		_assert(recruit.get("attached_items", []).size() == 1 and _contains_instance(recruit.get("attached_items", []), mobilize_item["instance_id"]), "Mobilize Recruit should receive the item as attached equipment.") and
		_assert(EvergreenRules.get_power(recruit) == 2 and EvergreenRules.get_health(recruit) == 3, "Mobilize handoff should preserve equipment bonuses on the created Recruit.") and
		_assert(EvergreenRules.has_keyword(recruit, "ward"), "Mobilize handoff should preserve equipment keyword bonuses on the created Recruit.")
	)


func _test_plot_item_reduces_random_hand_card_cost() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	# Creature already in lane to equip onto
	var host := _summon_creature(player, match_state, "target_creature", "field", 2, 4, 0)
	# Filler creature to play first (activates Plot)
	var filler := _add_hand_card(player, "filler_creature", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
	})
	# Glass Greaves: item with Plot cost reduction
	var greaves := _add_hand_card(player, "glass_greaves", {
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 1,
		"equip_health_bonus": 1,
		"triggered_abilities": [{"family": "on_play", "plot_bonus": true, "effects": [{"op": "reduce_random_hand_card_cost", "amount": 1}]}],
	})
	# 0-cost card that should be skipped by the cost reduction
	var _zero_cost := _add_hand_card(player, "zero_cost_card", {
		"card_type": "creature",
		"cost": 0,
		"power": 1,
		"health": 1,
	})
	# Card in hand whose cost should be reduced (only non-zero candidate)
	var expensive_card := _add_hand_card(player, "expensive_card", {
		"card_type": "action",
		"cost": 5,
	})
	var cost_before := int(expensive_card.get("cost", 0))
	# Play filler first to activate Plot
	var filler_result := LaneRules.summon_from_hand(match_state, player["player_id"], filler["instance_id"], "field")
	if not _assert(filler_result["is_valid"], "Filler creature should play successfully."):
		return false
	# Play Glass Greaves onto the host creature
	var play_result := PersistentCardRules.play_item_from_hand(match_state, player["player_id"], greaves["instance_id"], {"target_instance_id": host["instance_id"]})
	if not _assert(play_result["is_valid"], "Glass Greaves should equip successfully."):
		return false
	# Check that the expensive card's cost was reduced (0-cost cards should be skipped)
	var cost_after := int(expensive_card.get("cost", 0))
	var zero_cost_after := int(_zero_cost.get("cost", 0))
	return (
		_assert(cost_after == cost_before - 1, "Plot should reduce the non-zero-cost card by 1. Expected: %d, Got: %d" % [cost_before - 1, cost_after]) and
		_assert(zero_cost_after == 0, "Zero-cost cards should be skipped by cost reduction.")
	)


func _test_on_support_count_reached_waits_for_threshold() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	# Forward Camp: on_support_count_reached with count 4 should destroy self and summon creatures
	var forward_camp := _add_hand_card(player, "forward_camp", {
		"card_type": "support",
		"cost": 3,
		"support_uses": 0,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ON_SUPPORT_COUNT_REACHED,
			"required_zone": "support",
			"count": 4,
			"effects": [
				{"op": "destroy_creature", "target": "self"},
				{"op": "summon_from_effect", "lane": "field", "card_template": {
					"definition_id": "eastmarch_crusader", "name": "Eastmarch Crusader",
					"card_type": "creature", "subtypes": ["Nord"], "attributes": ["willpower"],
					"cost": 2, "power": 2, "health": 2, "base_power": 2, "base_health": 2,
				}},
			],
		}],
	})
	PersistentCardRules.play_support_from_hand(match_state, player["player_id"], forward_camp["instance_id"])
	# After playing Forward Camp (1 support), it should NOT have triggered
	if not (
		_assert(_contains_instance(player["support"], forward_camp["instance_id"]), "Forward Camp should remain in support zone with only 1 support.") and
		_assert(_find_lane_card(match_state, "field", player["player_id"], "eastmarch_crusader").is_empty(), "No Eastmarch Crusader should be summoned with only 1 support.")
	):
		return false
	# Play 2 more supports (reaching 3 total) — still should not trigger
	for i in range(2):
		var filler := _add_hand_card(player, "filler_support_%d" % i, {"card_type": "support", "cost": 0, "support_uses": 3})
		PersistentCardRules.play_support_from_hand(match_state, player["player_id"], filler["instance_id"])
	if not _assert(_contains_instance(player["support"], forward_camp["instance_id"]), "Forward Camp should remain with only 3 supports."):
		return false
	# Play the 4th support — this should trigger Forward Camp
	var fourth := _add_hand_card(player, "fourth_support", {"card_type": "support", "cost": 0, "support_uses": 3})
	PersistentCardRules.play_support_from_hand(match_state, player["player_id"], fourth["instance_id"])
	var crusader := _find_lane_card(match_state, "field", player["player_id"], "eastmarch_crusader")
	return (
		_assert(not _contains_instance(player["support"], forward_camp["instance_id"]), "Forward Camp should be destroyed after reaching 4 supports.") and
		_assert(not crusader.is_empty(), "Eastmarch Crusader should be summoned in field lane after 4-support trigger.")
	)


func _test_item_on_play_target_no_valid_targets_allows_decline() -> bool:
	# Bone Bow has on_play target_mode "another_creature" (Silence another creature).
	# When there are no other creatures on the board, the AI must have a decline
	# action so the game doesn't get stuck in a mandatory targeting phase.
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	# Summon a single creature to equip
	var host := _summon_creature(player, match_state, "host_creature", "field", 4, 4, 0)
	# Add Bone Bow to hand
	var bone_bow := _add_hand_card(player, "bone_bow", {
		"card_type": "item",
		"cost": 2,
		"equip_power_bonus": 1,
		"triggered_abilities": [{"family": "on_play", "target_mode": "another_creature", "effects": [{"op": "silence", "target": "chosen_target"}]}],
	})
	# Play Bone Bow on the host creature
	var result := PersistentCardRules.play_item_from_hand(match_state, pid, bone_bow["instance_id"], {"target_instance_id": host["instance_id"]})
	if not _assert(result["is_valid"], "Playing Bone Bow on own creature should succeed."):
		return false
	# The on_play creates a mandatory pending_summon_effect_target.
	# With only the host creature on board, "another_creature" includes it (since
	# the source is the item, not the host). But the enumeration must always
	# provide at least one action to prevent the game from getting stuck.
	var surface := MatchActionEnumerator.enumerate_legal_actions(match_state, pid)
	var actions: Array = surface.get("actions", [])
	return (
		_assert(not actions.is_empty(), "Must have at least one action when item on_play targeting is pending.") and
		_assert(actions.any(func(a): return str(a.get("kind", "")) == MatchActionEnumerator.KIND_DECLINE_SUMMON_EFFECT_TARGET or str(a.get("kind", "")) == MatchActionEnumerator.KIND_CHOOSE_SUMMON_EFFECT_TARGET), "Actions should include either a target choice or a decline option.")
	)


func _test_horse_armor_sets_premium_on_wielder() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	var host := _summon_creature(player, match_state, "host_creature", "field", 3, 3, 0)
	var horse_armor := _add_hand_card(player, "horse_armor", {
		"card_type": "item",
		"cost": 0,
		"equip_health_bonus": 1,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "set_premium", "target": "event_target"}]}],
	})
	if not _assert(not bool(host.get("_premium", false)), "Host should not be premium before equip."):
		return false
	var result := PersistentCardRules.play_item_from_hand(match_state, pid, horse_armor["instance_id"], {"target_instance_id": host["instance_id"]})
	if not _assert(result["is_valid"], "Horse Armor equip should succeed."):
		return false
	return (
		_assert(bool(host.get("_premium", false)), "Host creature should be premium after Horse Armor equip.") and
		_assert(EvergreenRules.get_health(host) == 4, "Host health should include +1 from Horse Armor equip bonus.")
	)


func _test_fifth_support_rejected_when_zone_full() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	# Fill the support zone to 4
	for i in range(4):
		var s := _add_hand_card(player, "fill_support_%d" % i, {"card_type": "support", "cost": 0, "support_uses": 3})
		var r := PersistentCardRules.play_support_from_hand(match_state, pid, s["instance_id"])
		if not _assert(r["is_valid"], "Support %d should play successfully." % i):
			return false
	if not _assert(player["support"].size() == 4, "Support zone should have 4 supports."):
		return false
	# Attempt to play a 5th support — should be rejected
	var fifth := _add_hand_card(player, "fifth_support", {"card_type": "support", "cost": 0, "support_uses": 3})
	var result := PersistentCardRules.play_support_from_hand(match_state, pid, fifth["instance_id"])
	return (
		_assert(not result["is_valid"], "Playing a 5th support should fail.") and
		_assert(player["support"].size() == 4, "Support zone should still have 4 supports.") and
		_assert(_contains_instance(player["hand"], fifth["instance_id"]), "5th support should remain in hand.")
	)


func _test_play_support_with_sacrifice() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	# Fill the support zone to 4
	for i in range(4):
		var s := _add_hand_card(player, "sac_fill_%d" % i, {"card_type": "support", "cost": 0, "support_uses": 3})
		PersistentCardRules.play_support_from_hand(match_state, pid, s["instance_id"])
	var sacrifice_id: String = str(player["support"][0].get("instance_id", ""))
	# Play a new support by sacrificing the first one
	var new_support := _add_hand_card(player, "new_support", {"card_type": "support", "cost": 0, "support_uses": 5})
	var result := PersistentCardRules.play_support_with_sacrifice(match_state, pid, new_support["instance_id"], sacrifice_id)
	return (
		_assert(result["is_valid"], "Support sacrifice play should succeed.") and
		_assert(player["support"].size() == 4, "Support zone should still have 4 supports after sacrifice play.") and
		_assert(not _contains_instance(player["support"], sacrifice_id), "Sacrificed support should be removed from support zone.") and
		_assert(_contains_instance(player["support"], new_support["instance_id"]), "New support should be in the support zone.") and
		_assert(_contains_instance(player["discard"], sacrifice_id), "Sacrificed support should be in the discard pile.")
	)


func _test_play_support_sacrifice_rejects_when_not_full() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	# Play only 2 supports (not full)
	for i in range(2):
		var s := _add_hand_card(player, "partial_fill_%d" % i, {"card_type": "support", "cost": 0, "support_uses": 3})
		PersistentCardRules.play_support_from_hand(match_state, pid, s["instance_id"])
	var sacrifice_id: String = str(player["support"][0].get("instance_id", ""))
	var new_support := _add_hand_card(player, "extra_support", {"card_type": "support", "cost": 0, "support_uses": 3})
	var result := PersistentCardRules.play_support_with_sacrifice(match_state, pid, new_support["instance_id"], sacrifice_id)
	return _assert(not result["is_valid"], "Sacrifice play should fail when support zone is not full.")


func _build_started_match() -> Dictionary:
	var match_state := MatchBootstrap.create_standard_match([_build_deck("alpha", 20), _build_deck("beta", 20)], {"seed": 53, "first_player_index": 0})
	for player in match_state["players"]:
		MatchBootstrap.apply_mulligan(match_state, player["player_id"], [])
	MatchTurnLoop.begin_first_turn(match_state)
	for player in match_state["players"]:
		player["max_magicka"] = 10
		player["current_magicka"] = 10
		player["temporary_magicka"] = 0
	return match_state


func _summon_creature(player: Dictionary, match_state: Dictionary, definition_id: String, lane_id: String, power: int, health: int, slot_index: int, overrides: Dictionary = {}) -> Dictionary:
	var card := {
		"instance_id": "%s_%s" % [player["player_id"], definition_id],
		"definition_id": definition_id,
		"name": definition_id,
		"card_type": "creature",
		"cost": 0,
		"power": power,
		"health": health,
		"keywords": [],
		"triggered_abilities": [],
		"owner_player_id": player["player_id"],
		"controller_player_id": player["player_id"],
		"zone": MatchMutations.ZONE_GENERATED,
	}
	for key in overrides.keys():
		card[key] = overrides[key]
	var result := MatchMutations.summon_card_to_lane(match_state, player["player_id"], card, lane_id, {"slot_index": slot_index, "source_zone": MatchMutations.ZONE_GENERATED})
	return result.get("card", {})


func _add_hand_card(player: Dictionary, definition_id: String, overrides: Dictionary = {}) -> Dictionary:
	var card := {
		"instance_id": "%s_%s" % [player["player_id"], definition_id],
		"definition_id": definition_id,
		"name": definition_id,
		"card_type": "action",
		"cost": 0,
		"owner_player_id": player["player_id"],
		"controller_player_id": player["player_id"],
		"zone": MatchMutations.ZONE_HAND,
		"keywords": [],
		"triggered_abilities": [],
	}
	for key in overrides.keys():
		card[key] = overrides[key]
	player["hand"].append(card)
	return card


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


func _build_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for index in range(size):
		deck.append("%s_card_%02d" % [prefix, index + 1])
	return deck


func _test_support_on_play_target_mode_queues_pending_target() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Place a creature on board to be a valid target
	var creature := _summon_creature(player, match_state, "crown_target", "field", 3, 3, 0)
	# Add a support with on_play target_mode to hand
	var support := _add_hand_card(player, "ruby_throne_test", {
		"card_type": "support",
		"cost": 3,
		"support_uses": 0,
		"triggered_abilities": [{"family": "on_play", "target_mode": "any_creature", "effects": [{"op": "grant_status", "target": "chosen_target", "status_id": "crowned"}]}],
	})
	var support_id := str(support["instance_id"])
	var result := PersistentCardRules.play_support_from_hand(match_state, pid, support_id)
	if not _assert(bool(result.get("is_valid", false)), "Support on_play target: play should be valid."):
		return false
	return _assert(MatchTiming.has_pending_summon_effect_target(match_state, pid), "Support on_play target: should queue a pending summon effect target.")


func _test_support_on_play_target_grants_crowned_status() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	var creature := _summon_creature(player, match_state, "crown_me", "field", 2, 4, 0)
	var creature_id := str(creature["instance_id"])
	var support := _add_hand_card(player, "ruby_throne_grant", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "on_play", "target_mode": "any_creature", "effects": [{"op": "grant_status", "target": "chosen_target", "status_id": "crowned"}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(support["instance_id"]))
	# Resolve the pending target
	var resolve := MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": creature_id})
	if not _assert(bool(resolve.get("is_valid", false)), "Crown grant: resolve should be valid."):
		return false
	var lane_card := _find_lane_card(match_state, "field", pid, "crown_me")
	var markers = lane_card.get("status_markers", [])
	return _assert(typeof(markers) == TYPE_ARRAY and markers.has("crowned"), "Crown grant: creature should have 'crowned' status marker.")


func _test_crowned_creatures_receive_end_of_turn_buff() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Place a creature and manually grant crowned status
	var creature := _summon_creature(player, match_state, "crowned_buff", "field", 2, 3, 0)
	var creature_id := str(creature["instance_id"])
	EvergreenRules.add_status(creature, "crowned")
	# Add a support with end_of_turn that buffs crowned creatures
	var support := _add_hand_card(player, "throne_buff", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "end_of_turn", "required_zone": "support", "effects": [{"op": "modify_stats", "target": "crowned_creatures", "power": 1, "health": 1}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(support["instance_id"]))
	var power_before := EvergreenRules.get_power(creature)
	var health_before := EvergreenRules.get_remaining_health(creature)
	# Fire end of turn
	MatchTurnLoop.end_turn(match_state, pid)
	var lane_card := _find_lane_card(match_state, "field", pid, "crowned_buff")
	if lane_card.is_empty():
		return _assert(false, "Crown buff: creature should still be in lane.")
	var power_after := EvergreenRules.get_power(lane_card)
	var health_after := EvergreenRules.get_remaining_health(lane_card)
	return (
		_assert(power_after == power_before + 1, "Crown buff: power should increase by 1, got %d -> %d." % [power_before, power_after]) and
		_assert(health_after == health_before + 1, "Crown buff: health should increase by 1, got %d -> %d." % [health_before, health_after])
	)


func _test_auto_crown_skips_when_crowned_creature_exists() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Place a creature and manually crown it
	var already_crowned := _summon_creature(player, match_state, "already_crowned", "field", 3, 3, 0, {"is_unique": true})
	EvergreenRules.add_status(already_crowned, "crowned")
	# Add a support with the auto-crown-on-unique trigger
	var support := _add_hand_card(player, "auto_crown_support", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "on_friendly_summon", "required_zone": "support", "required_no_crowned_creature": true, "required_summon_unique": true, "effects": [{"op": "grant_status", "target": "event_summoned_creature", "status_id": "crowned"}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(support["instance_id"]))
	# Summon a second unique creature — should NOT get crowned because one already exists
	var second_unique := _summon_creature(player, match_state, "second_unique", "field", 2, 2, 1, {"is_unique": true})
	# Fire the summon event so triggers run
	MatchTiming.publish_events(match_state, [{"event_type": "creature_summoned", "player_id": pid, "source_instance_id": str(second_unique["instance_id"]), "source_controller_player_id": pid, "lane_id": "field"}])
	var second_card := _find_lane_card(match_state, "field", pid, "second_unique")
	var markers = second_card.get("status_markers", [])
	return _assert(typeof(markers) != TYPE_ARRAY or not markers.has("crowned"), "Auto-crown: second unique should NOT get crowned when a crowned creature already exists.")


func _test_altar_of_despair_escalating_cost() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Add creatures to deck at costs 1, 2, 3
	var deck: Array = player["deck"]
	deck.clear()
	for cost_val in [1, 2, 3]:
		deck.append({
			"instance_id": "%s_deck_c%d" % [pid, cost_val],
			"definition_id": "test_creature_%d" % cost_val,
			"name": "Test Creature %d" % cost_val,
			"card_type": "creature",
			"cost": cost_val,
			"power": cost_val,
			"health": cost_val,
			"base_power": cost_val,
			"base_health": cost_val,
			"keywords": [],
			"triggered_abilities": [],
			"owner_player_id": pid,
			"controller_player_id": pid,
			"zone": "deck",
		})
	# Add the altar as a support
	var altar := _add_hand_card(player, "altar_of_despair_test", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 12,
		"effect_ids": ["activate"],
		"triggered_abilities": [{"family": "activate", "target_mode": "friendly_creature", "effects": [{"op": "sacrifice_and_summon_from_deck", "target": "chosen_target", "filter": {"card_type": "creature"}, "escalating_filter_key": "altar_cost", "escalating_filter_field": "cost", "escalating_increment": 1, "escalating_start": 1, "rules_text_template": "Uses: 12\nActivate: Sacrifice a creature to summon a creature from your deck that costs {cost}, then increase the cost of creatures this summons by 1."}]}],
	})
	var altar_id := str(altar["instance_id"])
	PersistentCardRules.play_support_from_hand(match_state, pid, altar_id)
	# Place 3 sacrifice fodder creatures in the field lane
	var fodder_ids: Array = []
	for i in range(3):
		var fodder := _summon_creature(player, match_state, "fodder_%d" % i, "field", 1, 1, i)
		fodder_ids.append(str(fodder["instance_id"]))
	# Activate altar 3 times, each time selecting a fodder creature
	var summoned_costs: Array = []
	for i in range(3):
		var result := PersistentCardRules.activate_support(match_state, pid, altar_id, {"target_instance_id": fodder_ids[i]})
		if not _assert(bool(result.get("is_valid", false)), "Altar activation %d should be valid." % (i + 1)):
			return false
		# Reset activation count for next use in same turn
		var altar_card := _find_support(player, altar_id)
		altar_card["activations_this_turn"] = 0
	# Check that the summoned creatures match escalating costs
	var field_lane: Dictionary = {}
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == "field":
			field_lane = lane
			break
	var player_slots: Array = field_lane.get("player_slots", {}).get(pid, [])
	for slot_card in player_slots:
		if typeof(slot_card) == TYPE_DICTIONARY and str(slot_card.get("definition_id", "")).begins_with("test_creature_"):
			summoned_costs.append(int(slot_card.get("cost", 0)))
	summoned_costs.sort()
	return (
		_assert(summoned_costs.size() == 3, "Altar: should summon 3 creatures, got %d." % summoned_costs.size()) and
		_assert(summoned_costs == [1, 2, 3], "Altar: escalating costs should be [1, 2, 3], got %s." % str(summoned_costs))
	)


func _test_altar_of_despair_sweet_roll_fallback() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Empty deck — no creatures to summon
	player["deck"].clear()
	# Add the altar as a support
	var altar := _add_hand_card(player, "altar_sweet_roll_test", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 12,
		"effect_ids": ["activate"],
		"triggered_abilities": [{"family": "activate", "target_mode": "friendly_creature", "effects": [{"op": "sacrifice_and_summon_from_deck", "target": "chosen_target", "filter": {"card_type": "creature"}, "escalating_filter_key": "altar_cost", "escalating_filter_field": "cost", "escalating_increment": 1, "escalating_start": 1}]}],
	})
	var altar_id := str(altar["instance_id"])
	PersistentCardRules.play_support_from_hand(match_state, pid, altar_id)
	# Place a single fodder creature
	var fodder := _summon_creature(player, match_state, "sweet_roll_fodder", "field", 1, 1, 0)
	var fodder_id := str(fodder["instance_id"])
	# Activate altar — should sacrifice and summon a Sweet Roll
	var result := PersistentCardRules.activate_support(match_state, pid, altar_id, {"target_instance_id": fodder_id})
	if not _assert(bool(result.get("is_valid", false)), "Altar sweet roll: activation should be valid."):
		return false
	# Check that a Sweet Roll was summoned in the field lane
	var found_sweet_roll := false
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == "field":
			for slot_card in lane.get("player_slots", {}).get(pid, []):
				if typeof(slot_card) == TYPE_DICTIONARY and str(slot_card.get("definition_id", "")) == "neu_sweet_roll":
					found_sweet_roll = true
					break
	return _assert(found_sweet_roll, "Altar: should summon a Sweet Roll when no matching creature in deck.")


func _find_support(player: Dictionary, instance_id: String) -> Dictionary:
	for card in player.get("support", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == instance_id:
			return card
	return {}


func _test_orsinium_forge_escalates_plate_stats_per_use() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	var target_a := _summon_creature(player, match_state, "forge_target_a", "field", 2, 2, 0)
	var target_b := _summon_creature(player, match_state, "forge_target_b", "field", 3, 3, 1)
	var target_c := _summon_creature(player, match_state, "forge_target_c", "field", 1, 1, 2)
	var plate_template := {
		"definition_id": "orsinium_plate", "name": "Orsinium Plate", "card_type": "item",
		"attributes": ["strength"], "cost": 1, "power": 0, "health": 0,
		"base_power": 0, "base_health": 0, "equip_power_bonus": 1, "equip_health_bonus": 1,
		"rules_text": "+1/+1",
	}
	var forge := _add_hand_card(player, "orsinium_forge", {
		"card_type": "support", "cost": 0, "support_uses": 3,
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ACTIVATE, "target_mode": "friendly_creature", "effects": [{
			"op": "equip_generated_item", "target": "chosen_target",
			"escalate_per_use": {"equip_power_bonus": 1, "equip_health_bonus": 1},
			"card_template": plate_template,
		}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, forge["instance_id"])

	# 1st activation: plate should be +1/+1
	PersistentCardRules.activate_support(match_state, pid, forge["instance_id"], {"target_instance_id": target_a["instance_id"]})
	if not (
		_assert(EvergreenRules.get_power(target_a) == 3, "1st plate should give +1 power.") and
		_assert(EvergreenRules.get_health(target_a) == 3, "1st plate should give +1 health.")
	):
		return false

	# Advance turn so we can activate again
	MatchTurnLoop.end_turn(match_state, pid)
	MatchTurnLoop.end_turn(match_state, match_state["active_player_id"])

	# 2nd activation: plate should be +2/+2
	PersistentCardRules.activate_support(match_state, pid, forge["instance_id"], {"target_instance_id": target_b["instance_id"]})
	if not (
		_assert(EvergreenRules.get_power(target_b) == 5, "2nd plate should give +2 power (3+2).") and
		_assert(EvergreenRules.get_health(target_b) == 5, "2nd plate should give +2 health (3+2).")
	):
		return false

	# Advance turn
	MatchTurnLoop.end_turn(match_state, pid)
	MatchTurnLoop.end_turn(match_state, match_state["active_player_id"])

	# 3rd activation: plate should be +3/+3
	PersistentCardRules.activate_support(match_state, pid, forge["instance_id"], {"target_instance_id": target_c["instance_id"]})
	return (
		_assert(EvergreenRules.get_power(target_c) == 4, "3rd plate should give +3 power (1+3).") and
		_assert(EvergreenRules.get_health(target_c) == 4, "3rd plate should give +3 health (1+3).")
	)


func _test_skyshard_on_card_drawn_buffs_creature() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Place Skyshard support in the support zone
	var skyshard := {
		"instance_id": pid + "_skyshard",
		"definition_id": "mc_end_skyshard",
		"name": "Skyshard",
		"card_type": "support",
		"cost": 3,
		"support_uses": 0,
		"owner_player_id": pid,
		"controller_player_id": pid,
		"zone": "support",
		"keywords": [],
		"triggered_abilities": [{
			"family": "on_card_drawn",
			"required_zone": "support",
			"required_controller_turn": true,
			"required_drawn_card_type": "creature",
			"effects": [
				{"op": "modify_cost", "target": "event_drawn_card", "amount": 2},
				{"op": "modify_stats", "target": "event_drawn_card", "power": 2, "health": 2},
			],
		}],
	}
	player["support"].append(skyshard)
	# Clear deck and add a creature with known stats at the top (pop_back draws last)
	player["deck"].clear()
	var creature_card := {
		"instance_id": pid + "_test_creature",
		"definition_id": "test_creature",
		"name": "Test Creature",
		"card_type": "creature",
		"cost": 3,
		"power": 2,
		"health": 2,
		"base_power": 2,
		"base_health": 2,
		"keywords": [],
		"triggered_abilities": [],
		"owner_player_id": pid,
		"controller_player_id": pid,
		"zone": "deck",
	}
	player["deck"].append(creature_card)
	# End two turns so player 1's turn restarts and draws the creature
	MatchTurnLoop.end_turn(match_state, pid)
	MatchTurnLoop.end_turn(match_state, match_state["active_player_id"])
	# Find the drawn creature in hand
	var drawn: Dictionary = {}
	for card in player["hand"]:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "test_creature":
			drawn = card
			break
	if not _assert(not drawn.is_empty(), "Skyshard: creature should be drawn into hand."):
		return false
	var actual_cost := int(drawn.get("cost", -1))
	var actual_power := EvergreenRules.get_power(drawn)
	var actual_health := EvergreenRules.get_health(drawn)
	return (
		_assert(actual_cost == 5, "Skyshard: drawn creature cost should be 3+2=5, got %d." % actual_cost) and
		_assert(actual_power == 4, "Skyshard: drawn creature power should be 2+2=4, got %d." % actual_power) and
		_assert(actual_health == 4, "Skyshard: drawn creature health should be 2+2=4, got %d." % actual_health)
	)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false