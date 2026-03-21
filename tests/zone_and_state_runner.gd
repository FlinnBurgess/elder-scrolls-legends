extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return
	print("ZONE_AND_STATE_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_zone_routes_and_ownership_controller_rules() and
		_test_hidden_zone_steal_discards_to_owner_pile() and
		_test_state_mutations_cover_silence_change_copy_transform_and_consume() and
		_test_timing_effect_ops_use_shared_mutations()
	)


func _test_zone_routes_and_ownership_controller_rules() -> bool:
	var match_state := _build_started_match()
	var player_one: Dictionary = match_state["players"][0]
	var player_two: Dictionary = match_state["players"][1]
	var victim := _summon_creature(player_two, match_state, "victim", "field", 3, 3)
	_target_ready_for_attack(victim, match_state)
	var mover := _summon_creature(player_one, match_state, "mover", "field", 2, 2)

	var steal_result := MatchMutations.steal_card(match_state, player_one["player_id"], victim["instance_id"])
	if not (
		_assert(steal_result["is_valid"], "Expected steal to transfer controller across the lane.") and
		_assert(str(victim.get("owner_player_id", "")) == player_two["player_id"], "Steal should preserve owner_player_id.") and
		_assert(str(victim.get("controller_player_id", "")) == player_one["player_id"], "Steal should update controller_player_id.") and
		_assert(_contains_lane_instance(match_state, "field", player_one["player_id"], victim["instance_id"]), "Stolen creature should appear on the stealer's side of the lane.")
	):
		return false

	var unsummon_result := MatchMutations.unsummon_card(match_state, victim["instance_id"])
	if not (
		_assert(unsummon_result["is_valid"], "Unsummon should move an in-play creature to hand.") and
		_assert(_contains_instance(player_two["hand"], victim["instance_id"]), "Unsummon should route the card back to its owner's hand.") and
		_assert(str(victim.get("controller_player_id", "")) == player_two["player_id"], "Hidden-zone cards should reset control to the destination player.")
	):
		return false

	var discard_result := MatchMutations.discard_card(match_state, victim["instance_id"])
	if not _assert(discard_result["is_valid"] and _contains_instance(player_two["discard"], victim["instance_id"]), "Discard should send the card to its owner's discard pile."):
		return false
	var banish_result := MatchMutations.banish_card(match_state, victim["instance_id"])
	if not _assert(banish_result["is_valid"] and _contains_instance(player_two["banished"], victim["instance_id"]), "Banish should send the card to its owner's banished zone."):
		return false
	var move_result := MatchMutations.move_card_between_lanes(match_state, player_one["player_id"], mover["instance_id"], "shadow")
	if not _assert(move_result["is_valid"] and _contains_lane_instance(match_state, "shadow", player_one["player_id"], mover["instance_id"]), "move_between_lanes should relocate the creature onto the requested lane."):
		return false
	var sacrifice_result := MatchMutations.sacrifice_card(match_state, player_one["player_id"], mover["instance_id"])
	var owner_result := MatchMutations.update_card_owner(match_state, victim["instance_id"], player_one["player_id"])
	return (
		_assert(sacrifice_result["is_valid"] and _contains_instance(player_one["discard"], mover["instance_id"]), "Sacrifice should route the controller's creature to discard.") and
		_assert(owner_result["is_valid"] and str(victim.get("owner_player_id", "")) == player_one["player_id"], "Owner updates should be tracked explicitly on the card instance.")
	)


func _test_hidden_zone_steal_discards_to_owner_pile() -> bool:
	var match_state := _build_started_match()
	var player_one: Dictionary = match_state["players"][0]
	var player_two: Dictionary = match_state["players"][1]
	player_one["hand"] = []
	player_two["hand"] = []
	var stolen_card := _add_hand_card(player_two, "stolen_hidden", {"card_type": "action"})
	var steal_result := MatchMutations.steal_card(match_state, player_one["player_id"], stolen_card["instance_id"])
	if not (
		_assert(steal_result["is_valid"], "Hidden-zone steal fixture should succeed.") and
		_assert(_contains_instance(player_one["hand"], stolen_card["instance_id"]), "Stolen hidden-zone card should move into the stealer's hand.") and
		_assert(str(stolen_card.get("owner_player_id", "")) == player_two["player_id"], "Hidden-zone steal should preserve owner_player_id.") and
		_assert(str(stolen_card.get("controller_player_id", "")) == player_one["player_id"], "Hidden-zone steal should update controller_player_id.")
	):
		return false
	var discard_result := MatchMutations.discard_from_hand(match_state, player_one["player_id"], 1, {"selection": "front"})
	return (
		_assert(discard_result["is_valid"], "Discarding from the stealer's hand should succeed.") and
		_assert(not _contains_instance(player_one["discard"], stolen_card["instance_id"]), "Owner-routed hidden-zone discard should not land in the stealer's discard pile.") and
		_assert(_contains_instance(player_two["discard"], stolen_card["instance_id"]), "Owner-routed hidden-zone discard should land in the owner's discard pile.") and
		_assert(str(stolen_card.get("controller_player_id", "")) == player_two["player_id"], "Hidden-zone discard should reset controller_player_id to the owner/destination player.")
	)


func _test_state_mutations_cover_silence_change_copy_transform_and_consume() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var mutable := _summon_creature(player, match_state, "mutable", "shadow", 2, 4, ["guard"], -1, {
		"triggered_abilities": [{"family": MatchTiming.FAMILY_SUMMON, "required_zone": "lane", "effects": [{"op": "log", "message": "mutable"}]}],
	})
	mutable["damage_marked"] = 1
	mutable["power_bonus"] = 2
	mutable["health_bonus"] = 1
	mutable["granted_keywords"] = ["ward"]
	mutable["status_markers"] = ["cover", "shackled"]
	var silence_result := MatchMutations.silence_card(mutable)
	if not (
		_assert(silence_result["is_valid"], "Silence should succeed on creature instances.") and
		_assert(mutable.get("keywords", []).is_empty() and mutable.get("granted_keywords", []).is_empty(), "Silence should remove printed and granted keywords.") and
		_assert(mutable.get("triggered_abilities", []).is_empty(), "Silence should strip triggered abilities.") and
		_assert(mutable.get("power_bonus", 0) == 0 and mutable.get("health_bonus", 0) == 0, "Silence should clear stat modifiers.") and
		_assert(mutable.get("status_markers", []) == ["silenced", "wounded"], "Silence should leave only Silenced plus derived Wounded.")
	):
		return false

	var changer := _summon_creature(player, match_state, "changer", "field", 2, 2)
	changer["damage_marked"] = 1
	changer["power_bonus"] = 3
	changer["health_bonus"] = 2
	changer["status_markers"] = ["cover"]
	var change_result := MatchMutations.change_card(changer, {
		"definition_id": "changed_form",
		"name": "Changed Form",
		"card_type": "creature",
		"power": 5,
		"health": 6,
		"keywords": ["drain"],
		"triggered_abilities": [],
	})
	if not (
		_assert(change_result["is_valid"], "Change should apply a new base identity.") and
		_assert(str(changer.get("definition_id", "")) == "changed_form" and changer.get("keywords", []) == ["drain"], "Change should replace the printed identity.") and
		_assert(changer.get("damage_marked", 0) == 1 and changer.get("power_bonus", 0) == 3 and changer.get("health_bonus", 0) == 2, "Change should preserve damage and stat modifications.")
	):
		return false

	var source := _summon_creature(player, match_state, "copy_source", "field", 7, 8, ["ward"])
	var copy_result := MatchMutations.copy_card(changer, source)
	if not (
		_assert(copy_result["is_valid"], "Copy should apply another card's printed identity.") and
		_assert(str(changer.get("definition_id", "")) == str(source.get("definition_id", "")) and changer.get("keywords", []) == ["ward"], "Copy should mirror the source identity.") and
		_assert(changer.get("damage_marked", 0) == 0 and changer.get("power_bonus", 0) == 0 and changer.get("health_bonus", 0) == 0, "Copy should reset transient modifiers by default.")
	):
		return false

	var transformer := _summon_creature(player, match_state, "transformer", "field", 4, 4)
	transformer["damage_marked"] = 2
	transformer["power_bonus"] = 1
	transformer["status_markers"] = ["cover"]
	var transform_result := MatchMutations.transform_card(match_state, transformer["instance_id"], {
		"definition_id": "transformed_form",
		"name": "Transformed Form",
		"card_type": "creature",
		"power": 1,
		"health": 1,
		"keywords": ["guard"],
		"triggered_abilities": [],
	}, {"reason": "test_transform"})
	var transform_event_types := _event_types(transform_result.get("events", []))
	if not (
		_assert(transform_result["is_valid"], "Transform should succeed on in-play creatures.") and
		_assert(str(transformer.get("definition_id", "")) == "transformed_form" and transformer.get("damage_marked", 0) == 0, "Transform should replace the creature and reset prior damage.") and
		_assert(transformer.get("power_bonus", 0) == 0 and transformer.get("status_markers", []).is_empty(), "Transform should reset temporary stats and statuses.") and
		_assert(transform_event_types.has("card_transformed") and transform_event_types.has(MatchTiming.EVENT_CREATURE_SUMMONED), "Transform should emit both transformed and summon-facing events.")
	):
		return false

	var consumer := _summon_creature(player, match_state, "consumer", "shadow", 2, 2)
	var prey := _summon_creature(player, match_state, "prey", "shadow", 3, 4)
	var consume_result := MatchMutations.consume_card(match_state, player["player_id"], consumer["instance_id"], prey["instance_id"], {"destination_zone": MatchMutations.ZONE_BANISHED})
	return (
		_assert(consume_result["is_valid"], "Consume should resolve through the shared mutation API.") and
		_assert(consumer.get("power_bonus", 0) == 3 and consumer.get("health_bonus", 0) == 4, "Consume should grant the consumed creature's stats to the consumer.") and
		_assert(_contains_instance(player["banished"], prey["instance_id"]), "Consume should move the consumed card into the requested destination zone.")
	)


func _test_timing_effect_ops_use_shared_mutations() -> bool:
	var match_state := _build_started_match()
	var active_player: Dictionary = match_state["players"][0]
	_add_hand_card(active_player, "discard_me", {"card_type": "action", "insert_index": 0})
	var engine := _add_hand_card(active_player, "engine", {
		"card_type": "creature",
		"power": 2,
		"health": 2,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_SUMMON,
			"required_zone": "lane",
			"effects": [
				{"op": "draw_cards", "target_player": "controller", "count": 1},
				{"op": "discard", "target_player": "controller", "count": 1, "selection": "front"},
				{"op": "summon_from_effect", "target_player": "controller", "lane_id": "field", "slot_index": 1, "card_template": {
					"definition_id": "generated_token",
					"name": "Generated Token",
					"card_type": "creature",
					"power": 1,
					"health": 1,
					"keywords": [],
					"triggered_abilities": [],
				}},
				{"op": "move_between_lanes", "target": "self", "lane_id": "shadow", "slot_index": 0},
			],
		}],
	})
	var summon_result := LaneRules.summon_from_hand(match_state, active_player["player_id"], engine["instance_id"], "field", {"slot_index": 0})
	var event_types := _event_types(summon_result.get("events", []))
	return (
		_assert(summon_result["is_valid"], "Summon fixture for shared timing ops should succeed.") and
		_assert(_contains_lane_instance(match_state, "shadow", active_player["player_id"], engine["instance_id"]), "Timed move_between_lanes should reuse the shared board-movement path.") and
		_assert(_contains_definition(match_state, "generated_token"), "summon_from_effect should place a generated creature into the requested lane.") and
		_assert(event_types.has(MatchTiming.EVENT_CARD_DRAWN), "draw_cards timing effects should still emit card-drawn events.") and
		_assert(_contains_instance(active_player["discard"], "%s_discard_me" % active_player["player_id"]), "discard timing effects should route hidden-zone cards through shared discard handling.")
	)


func _build_started_match() -> Dictionary:
	var match_state := ScenarioFixtures.create_standard_match({"deck_size": 12, "seed": 31, "first_player_index": 0})
	ScenarioFixtures.set_all_magicka(match_state, 10)
	match_state["phase"] = "action"
	return match_state


func _build_deck(prefix: String, size: int) -> Array:
	return ScenarioFixtures.build_deck(prefix, size)


func _summon_creature(player: Dictionary, match_state: Dictionary, label: String, lane_id: String, power: int, health: int, keywords: Array = [], slot_index := -1, extra: Dictionary = {}) -> Dictionary:
	var card := ScenarioFixtures.summon_creature(player, match_state, label, lane_id, power, health, keywords, slot_index, extra)
	_assert(not card.is_empty(), "Expected summon fixture for %s to succeed." % label)
	return card


func _add_hand_card(player: Dictionary, label: String, extra: Dictionary = {}) -> Dictionary:
	return ScenarioFixtures.add_hand_card(player, label, extra)


func _target_ready_for_attack(card: Dictionary, match_state: Dictionary) -> void:
	ScenarioFixtures.ready_for_attack(card, match_state)


func _contains_instance(cards: Array, instance_id: String) -> bool:
	for card in cards:
		if card != null and str(card.get("instance_id", "")) == instance_id:
			return true
	return false


func _contains_lane_instance(match_state: Dictionary, lane_id: String, player_id: String, instance_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if card != null and str(card.get("instance_id", "")) == instance_id:
				return true
	return false


func _contains_definition(match_state: Dictionary, definition_id: String) -> bool:
	for lane in match_state.get("lanes", []):
		for player_id in lane.get("player_slots", {}).keys():
			for card in lane["player_slots"][player_id]:
				if card != null and str(card.get("definition_id", "")) == definition_id:
					return true
	return false


func _event_types(events: Array) -> Array:
	var types: Array = []
	for event in events:
		types.append(str(event.get("event_type", "")))
	return types


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false