extends SceneTree

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")


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
		_test_mobilize_items_create_recruits_and_attach_equipment()
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


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false