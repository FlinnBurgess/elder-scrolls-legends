extends SceneTree

const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchScreen = preload("res://src/ui/match_screen.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")


func _initialize() -> void:
	if not _run_all_tests():
		quit(1)
		return

	print("DOUBLE_CARDS_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		_test_catalog_has_combined_entries_and_halves_non_collectible() and
		_test_draw_double_splits_into_two_halves_in_hand() and
		_test_draw_double_archives_combined_instance() and
		_test_draw_double_emits_single_card_drawn_event() and
		_test_draw_double_with_nine_in_hand_results_in_eleven() and
		_test_drawing_only_double_in_deck_does_not_trigger_fatigue() and
		_test_buff_propagation_cost_delta_to_halves() and
		_test_halves_have_distinct_instance_ids_and_split_origin_pointer() and
		_test_milling_a_double_splits_both_halves_into_discard() and
		_test_tutor_either_mode_matches_double_when_half_matches() and
		_test_tutor_picking_double_splits_into_hand()
	)


# ---------- catalog tests ----------

func _test_catalog_has_combined_entries_and_halves_non_collectible() -> bool:
	var catalog := CardCatalog.load_default()
	var by_id: Dictionary = catalog.get("card_by_id", {})
	var combined_ids := [
		"iom_double_cloak_and_dagger",
		"iom_double_manic_jack_and_mutation",
		"iom_double_spawn_mother_and_baliwog",
		"iom_double_felldew_and_elytra_noble",
		"iom_double_baliwog_tidecrawlers_and_smoked_baliwog_leg",
		"iom_double_manic_and_demented_grummite",
		"iom_double_tavyar_and_rayvat",
		"moe_double_cadwell_soul_shriven_and_betrayer",
	]
	for cid in combined_ids:
		if not _assert(by_id.has(cid), "Catalog missing combined card: %s" % cid):
			return false
		var entry: Dictionary = by_id[cid]
		if not _assert(str(entry.get("card_type", "")) == "double", "Combined %s should have card_type=double" % cid):
			return false
		var halves: Array = entry.get("half_card_ids", [])
		if not _assert(halves.size() == 2, "Combined %s should have 2 half_card_ids" % cid):
			return false
		for hid in halves:
			if not _assert(by_id.has(hid), "Half %s missing from catalog" % hid):
				return false
			var half: Dictionary = by_id[hid]
			if not _assert(not bool(half.get("collectible", true)), "Half %s should be non-collectible" % hid):
				return false
			if not _assert(not bool(half.get("random_generation_eligible", true)), "Half %s should be random-ineligible" % hid):
				return false
		if not _assert(not bool(entry.get("random_generation_eligible", true)), "Combined %s should be random-ineligible" % cid):
			return false
	return true


# ---------- draw / split tests ----------

func _make_started_match() -> Dictionary:
	# Bootstrap a normal-sized match, hydrate cards from catalog (so card_type
	# is populated). Use a fresh seed/turn-1 setup.
	var match_state := MatchBootstrap.create_standard_match([
		_build_filler_deck("alpha", 20),
		_build_filler_deck("beta", 20),
	], {"seed": 17, "first_player_index": 0})
	if match_state.is_empty():
		return {}
	var catalog := CardCatalog.load_default()
	var card_by_id: Dictionary = catalog.get("card_by_id", {})
	MatchScreen._hydrate_match_cards(match_state, card_by_id)
	return match_state


func _build_filler_deck(prefix: String, size: int) -> Array:
	var deck: Array = []
	for i in range(size):
		deck.append("neu_steel_dagger")
	return deck


func _force_top_of_deck(match_state: Dictionary, player_index: int, definition_id: String) -> Dictionary:
	# Replaces the top card of the player's deck (last element of the deck array,
	# since pop_back draws from the end) with a freshly-built and hydrated
	# instance of the requested definition_id.
	var player: Dictionary = match_state["players"][player_index]
	var deck: Array = player["deck"]
	if deck.is_empty():
		return {}
	var top_card: Dictionary = deck[deck.size() - 1]
	top_card["definition_id"] = definition_id
	# Reset some carryover state from the filler card so the hydrate cleanly
	# overlays the new identity.
	for key in ["name", "card_type", "cost", "_base_cost", "power", "health", "rules_text", "subtypes", "attributes", "keywords", "rules_tags", "triggered_abilities", "half_card_ids", "random_generation_eligible"]:
		if top_card.has(key):
			top_card.erase(key)
	var catalog := CardCatalog.load_default()
	MatchScreen._hydrate_card(top_card, catalog.get("card_by_id", {}))
	return top_card


func _test_draw_double_splits_into_two_halves_in_hand() -> bool:
	var match_state := _make_started_match()
	if not _assert(not match_state.is_empty(), "Match should bootstrap successfully"):
		return false
	_force_top_of_deck(match_state, 0, "iom_double_cloak_and_dagger")
	var pid := str(match_state["players"][0].get("player_id", ""))
	var hand_size_before := int(match_state["players"][0]["hand"].size())
	var deck_size_before := int(match_state["players"][0]["deck"].size())

	var result := MatchTiming.draw_cards(match_state, pid, 1, {})
	var player: Dictionary = match_state["players"][0]

	if not _assert(player["hand"].size() == hand_size_before + 2, "Hand should grow by 2 after splitting double card. before=%d, after=%d" % [hand_size_before, player["hand"].size()]):
		return false
	if not _assert(player["deck"].size() == deck_size_before - 1, "Deck should shrink by 1 (combined card removed)"):
		return false
	# Verify the two added cards are Cloak and Dagger
	var added_names: Array = []
	for i in range(hand_size_before, player["hand"].size()):
		added_names.append(str(player["hand"][i].get("name", "")))
	added_names.sort()
	if not _assert(added_names == ["Cloak", "Dagger"], "Hand should now contain Cloak and Dagger; got %s" % str(added_names)):
		return false
	# Verify the two halves' card_types match catalog (both items here)
	for i in range(hand_size_before, player["hand"].size()):
		var c: Dictionary = player["hand"][i]
		if not _assert(str(c.get("card_type", "")) == "item", "Half %s should be an item" % str(c.get("name", ""))):
			return false
	return true


func _test_draw_double_archives_combined_instance() -> bool:
	var match_state := _make_started_match()
	_force_top_of_deck(match_state, 0, "iom_double_manic_jack_and_mutation")
	var pid := str(match_state["players"][0].get("player_id", ""))
	MatchTiming.draw_cards(match_state, pid, 1, {})
	var player: Dictionary = match_state["players"][0]
	var archive: Array = player.get("double_archive", [])
	if not _assert(archive.size() == 1, "Archive should have 1 entry; got %d" % archive.size()):
		return false
	var archived: Dictionary = archive[0]
	if not _assert(str(archived.get("card_type", "")) == "double", "Archived card should be card_type=double"):
		return false
	if not _assert(str(archived.get("zone", "")) == "double_archive", "Archived card should report zone=double_archive"):
		return false
	if not _assert(str(archived.get("name", "")) == "Manic Jack / Manic Mutation", "Archived card name mismatch: %s" % str(archived.get("name", ""))):
		return false
	return true


func _test_draw_double_emits_single_card_drawn_event() -> bool:
	var match_state := _make_started_match()
	var combined := _force_top_of_deck(match_state, 0, "iom_double_spawn_mother_and_baliwog")
	var combined_iid := str(combined.get("instance_id", ""))
	var pid := str(match_state["players"][0].get("player_id", ""))
	var result := MatchTiming.draw_cards(match_state, pid, 1, {})
	var events: Array = result.get("events", [])
	var draw_events: Array = []
	for ev in events:
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("event_type", "")) == MatchTiming.EVENT_CARD_DRAWN:
			draw_events.append(ev)
	if not _assert(draw_events.size() == 1, "Drawing a double should emit exactly one EVENT_CARD_DRAWN; got %d" % draw_events.size()):
		return false
	var ev: Dictionary = draw_events[0]
	if not _assert(bool(ev.get("is_double_card", false)), "Draw event should be flagged as double card"):
		return false
	if not _assert(str(ev.get("drawn_instance_id", "")) == combined_iid, "Draw event should reference the combined instance_id"):
		return false
	var split_ids: Array = ev.get("split_half_instance_ids", [])
	if not _assert(split_ids.size() == 2 and not str(split_ids[0]).is_empty() and not str(split_ids[1]).is_empty(), "Draw event should list both half instance ids"):
		return false
	return true


func _test_draw_double_with_nine_in_hand_results_in_eleven() -> bool:
	# Setup: hand=9, deck top=double, after draw expect hand=11
	var match_state := _make_started_match()
	var player: Dictionary = match_state["players"][0]
	# Move 6 cards from deck → hand to bring hand from 3 to 9
	while player["hand"].size() < 9 and not player["deck"].is_empty():
		var c: Dictionary = player["deck"].pop_back()
		c["zone"] = "hand"
		player["hand"].append(c)
	if not _assert(player["hand"].size() == 9, "Setup: hand should be 9; got %d" % player["hand"].size()):
		return false
	_force_top_of_deck(match_state, 0, "iom_double_felldew_and_elytra_noble")
	var pid := str(player.get("player_id", ""))
	MatchTiming.draw_cards(match_state, pid, 1, {})
	if not _assert(player["hand"].size() == 11, "Hand should be 11 after drawing double at 9; got %d" % player["hand"].size()):
		return false
	return true


func _test_drawing_only_double_in_deck_does_not_trigger_fatigue() -> bool:
	# Setup: clear deck except for one double card on top. Drawing should split
	# without triggering out-of-cards.
	var match_state := _make_started_match()
	var player: Dictionary = match_state["players"][0]
	player["deck"] = []
	# Append a placeholder filler then overwrite to a double via _force_top_of_deck.
	player["deck"].append({
		"instance_id": "%s_solo_double" % str(player.get("player_id", "")),
		"definition_id": "neu_steel_dagger",
		"owner_player_id": str(player.get("player_id", "")),
		"controller_player_id": str(player.get("player_id", "")),
		"zone": "deck",
		"keywords": [],
		"granted_keywords": [],
		"status_markers": [],
		"triggered_abilities": [],
		"damage_marked": 0,
		"power_bonus": 0,
		"health_bonus": 0,
	})
	_force_top_of_deck(match_state, 0, "iom_double_baliwog_tidecrawlers_and_smoked_baliwog_leg")
	var pid := str(player.get("player_id", ""))
	var hand_before := int(player["hand"].size())
	var result := MatchTiming.draw_cards(match_state, pid, 1, {})
	if not _assert(player["deck"].size() == 0, "Deck should be empty after drawing the only card"):
		return false
	if not _assert(player["hand"].size() == hand_before + 2, "Hand should gain 2 halves; got %d -> %d" % [hand_before, player["hand"].size()]):
		return false
	if not _assert(not bool(result.get("player_lost", false)), "Drawing a double from deck of 1 should not trigger loss"):
		return false
	# Also: no out-of-cards events
	for ev in result.get("events", []):
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("event_type", "")).find("out_of_cards") != -1:
			return _assert(false, "Drawing the last (double) card should not trigger out_of_cards events")
	return true


func _test_buff_propagation_cost_delta_to_halves() -> bool:
	# Apply a -2 cost buff to the combined card and verify both halves enter
	# hand at -2 cost relative to their base.
	var match_state := _make_started_match()
	var combined := _force_top_of_deck(match_state, 0, "iom_double_manic_and_demented_grummite")
	# Force a -2 cost delta. _base_cost=6, simulate Eclipse-Baroness style buff.
	combined["cost"] = int(combined.get("_base_cost", 6)) - 2
	var pid := str(match_state["players"][0].get("player_id", ""))
	var hand_size_before := int(match_state["players"][0]["hand"].size())
	MatchTiming.draw_cards(match_state, pid, 1, {})
	var hand: Array = match_state["players"][0]["hand"]
	var manic_cost := -1
	var demented_cost := -1
	for i in range(hand_size_before, hand.size()):
		var c: Dictionary = hand[i]
		if str(c.get("name", "")) == "Manic Grummite":
			manic_cost = int(c.get("cost", 999))
		elif str(c.get("name", "")) == "Demented Grummite":
			demented_cost = int(c.get("cost", 999))
	if not _assert(manic_cost == 1, "Manic Grummite should cost 1 (3 - 2 buff); got %d" % manic_cost):
		return false
	if not _assert(demented_cost == 1, "Demented Grummite should cost 1 (3 - 2 buff); got %d" % demented_cost):
		return false
	return true


func _test_halves_have_distinct_instance_ids_and_split_origin_pointer() -> bool:
	var match_state := _make_started_match()
	var combined := _force_top_of_deck(match_state, 0, "iom_double_cloak_and_dagger")
	var combined_iid := str(combined.get("instance_id", ""))
	var pid := str(match_state["players"][0].get("player_id", ""))
	var hand_size_before := int(match_state["players"][0]["hand"].size())
	MatchTiming.draw_cards(match_state, pid, 1, {})
	var hand: Array = match_state["players"][0]["hand"]
	var halves: Array = []
	for i in range(hand_size_before, hand.size()):
		halves.append(hand[i])
	if not _assert(halves.size() == 2, "Should have 2 halves"):
		return false
	if not _assert(str(halves[0].get("instance_id", "")) != str(halves[1].get("instance_id", "")), "Halves must have distinct instance_ids"):
		return false
	for half in halves:
		if not _assert(str(half.get("spawned_from_double", "")) == combined_iid, "Half should reference combined instance via spawned_from_double"):
			return false
	return true


func _test_milling_a_double_splits_both_halves_into_discard() -> bool:
	# Place a double card on top of deck, run the mill effect with count=1, expect
	# both halves to land in the discard pile (and the combined to be archived).
	var match_state := _make_started_match()
	_force_top_of_deck(match_state, 0, "iom_double_cloak_and_dagger")
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	var deck_size_before := int(player["deck"].size())
	var discard_size_before := int(player["discard"].size())

	# Use the EffectMovement.mill operation directly via match_effect_application.
	# Easiest path: emulate via direct helper call. Bypass the trigger system.
	var EffectMovement = preload("res://src/core/match/effects/effect_movement.gd")
	var trigger := {"controller_player_id": pid, "source_instance_id": "test_mill_source"}
	var effect := {"op": "mill", "target_player": "controller", "count": 1}
	var event := {}
	var generated_events: Array = []
	EffectMovement.apply("mill", match_state, trigger, event, effect, generated_events, {"reason": "test_mill", "descriptor": {}})

	if not _assert(player["deck"].size() == deck_size_before - 1, "Deck should shrink by 1 after milling"):
		return false
	if not _assert(player["discard"].size() == discard_size_before + 2, "Discard should grow by 2 (both halves)"):
		return false
	var added_names: Array = []
	for i in range(discard_size_before, player["discard"].size()):
		added_names.append(str(player["discard"][i].get("name", "")))
	added_names.sort()
	if not _assert(added_names == ["Cloak", "Dagger"], "Discard should contain both halves; got %s" % str(added_names)):
		return false
	if not _assert(player.get("double_archive", []).size() == 1, "Combined should be archived"):
		return false
	# Check that the milled event is flagged
	var has_double_event := false
	for ev in generated_events:
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("event_type", "")) == "card_milled" and bool(ev.get("is_double_card", false)):
			has_double_event = true
			break
	if not _assert(has_double_event, "card_milled event should be flagged is_double_card=true"):
		return false
	return true


func _test_tutor_either_mode_matches_double_when_half_matches() -> bool:
	# Place a creature/action double (Manic Jack/Mutation) in deck and run a
	# draw_from_deck_filtered with card_type=action. The combined should be
	# matched because Manic Mutation is an action.
	var match_state := _make_started_match()
	_force_top_of_deck(match_state, 0, "iom_double_manic_jack_and_mutation")
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	var hand_size_before := int(player["hand"].size())

	var EffectDraw = preload("res://src/core/match/effects/effect_draw.gd")
	var trigger := {"controller_player_id": pid, "source_instance_id": "test_tutor_src"}
	var effect := {"op": "draw_from_deck_filtered", "target_player": "controller", "filter": {"card_type": "action"}, "count": 1}
	var generated_events: Array = []
	EffectDraw.apply("draw_from_deck_filtered", match_state, trigger, {}, effect, generated_events, {"reason": "test_tutor", "descriptor": {}})

	# Expect 2 halves added to hand (Manic Jack + Manic Mutation), combined removed from deck
	if not _assert(player["hand"].size() == hand_size_before + 2, "Hand should grow by 2 (split) after either-mode tutor; got %d" % (player["hand"].size() - hand_size_before)):
		return false
	var added_names: Array = []
	for i in range(hand_size_before, player["hand"].size()):
		added_names.append(str(player["hand"][i].get("name", "")))
	added_names.sort()
	if not _assert(added_names == ["Manic Jack", "Manic Mutation"], "Halves should be Manic Jack and Manic Mutation; got %s" % str(added_names)):
		return false
	return true


func _test_tutor_picking_double_splits_into_hand() -> bool:
	# Use player_choice tutor: place double in deck, run draw_from_deck_filtered
	# with player_choice=true, then resolve the pending selection picking the
	# combined card. Expect split.
	var match_state := _make_started_match()
	_force_top_of_deck(match_state, 0, "iom_double_spawn_mother_and_baliwog")
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	var hand_size_before := int(player["hand"].size())
	var combined_iid := str(player["deck"][player["deck"].size() - 1].get("instance_id", ""))

	MatchTiming.ensure_match_state(match_state)
	var EffectDraw = preload("res://src/core/match/effects/effect_draw.gd")
	var trigger := {"controller_player_id": pid, "source_instance_id": "test_tutor_choice_src"}
	var effect := {"op": "draw_from_deck_filtered", "target_player": "controller", "filter": {"card_type": "creature"}, "player_choice": true}
	var generated_events: Array = []
	EffectDraw.apply("draw_from_deck_filtered", match_state, trigger, {}, effect, generated_events, {"reason": "test_tutor_choice", "descriptor": {}})

	if not _assert(MatchTiming.has_pending_deck_selection(match_state, pid), "Should have a pending deck selection"):
		return false
	# Resolve picking the combined card
	MatchTiming.resolve_pending_deck_selection(match_state, pid, combined_iid)
	if not _assert(player["hand"].size() == hand_size_before + 2, "Hand should grow by 2 after split; got %d" % (player["hand"].size() - hand_size_before)):
		return false
	return true


func _assert(condition: bool, message: String) -> bool:
	if not condition:
		push_error("ASSERT FAILED: %s" % message)
		print("ASSERT FAILED: %s" % message)
	return condition
