extends SceneTree

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const MatchBootstrap = preload("res://src/core/match/match_bootstrap.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchTargeting = preload("res://src/core/match/match_targeting.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")


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
		_test_last_gasp_self_power_reads_buffed_power_including_items() and
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
		_test_skyshard_on_card_drawn_buffs_creature() and
		_test_dark_rift_summons_atronach_after_five_activations() and
		_test_transform_card_updates_definition_id_from_raw_seed() and
		_test_transform_card_updates_base_cost() and
		_test_altar_of_spellmaking_plays_top_of_deck() and
		_test_priest_of_mara_equips_amulets_via_dual_target() and
		_test_support_last_gasp_draw_filtered_applies_post_draw_buff() and
		_test_support_on_play_summon_from_effect_with_chosen_lane() and
		_test_support_activate_summon_from_effect_chosen_lane() and
		_test_strategists_map_summons_target_for_chosen_owner() and
		# Umbra forced attack
		_test_umbra_forced_attack_hits_enemy_creature() and
		_test_umbra_forced_attack_skips_when_no_enemies() and
		_test_umbra_forced_attack_respects_guards() and
		# Singleton deck cost reduction
		_test_sehts_masterwork_reduces_cost_for_singleton_deck() and
		_test_sehts_masterwork_no_discount_for_duplicate_deck() and
		# Transitus Shrine type filter
		_test_transitus_shrine_only_discounts_creatures_and_actions() and
		# Ring of Lordship wielder-subtype filter
		_test_ring_of_lordship_discounts_creatures_matching_wielder_subtype() and
		_test_ring_of_lordship_requires_wielder_in_lane() and
		# Daggerfall Phantom last gasp
		_test_last_gasp_returns_equipped_items_to_hand() and
		# Conjurer's Spirit health-gained condition
		_test_end_of_turn_support_fires_when_health_gained() and
		# Unrelenting Siege grant_extra_attack passive
		_test_unrelenting_siege_allows_1_power_creature_to_attack_twice() and
		_test_unrelenting_siege_blocks_2_power_creature_from_second_attack() and
		_test_unrelenting_siege_allows_debuffed_creature_to_attack_twice() and
		_test_unrelenting_siege_passive_refreshes_each_turn() and
		# Zephyr item grant_extra_attack passive
		_test_zephyr_grants_wielder_extra_attack_each_turn() and
		# Play limit per turn (Lich's Ascension)
		_test_support_play_limit_blocks_second_card() and
		_test_support_play_limit_from_hand_without_hydration() and
		_test_support_play_limit_resets_on_placement() and
		# Skooma Cat's Whimsy not-in-starting-deck discount
		_test_skooma_cats_whimsy_discounts_generated_cards() and
		# Imperial Might end-of-turn summon
		_test_imperial_might_summons_grunt_at_end_of_turn() and
		# Spider Lair restricted card_ids pool
		_test_spider_lair_only_summons_configured_spider_ids() and
		# Yokudan Nightblade silence_on_equipped aura
		_test_yokudan_nightblade_grants_silence_immunity_to_equipped_friendlies() and
		# Lute silence immunity via attached item grants_immunity
		_test_lute_attached_item_grants_silence_immunity()
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


func _test_last_gasp_self_power_reads_buffed_power_including_items() -> bool:
	# Regression: Determined Supplier's last_gasp gain_max_magicka should count
	# attached item power bonuses even though items detach before the trigger
	# resolves. Snapshot captured in move_card_to_zone covers this.
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	player["max_magicka"] = 5
	player["current_magicka"] = 5
	# Determined Supplier analog: 1 power, last_gasp self_power gain_max_magicka.
	var supplier := _summon_creature(player, match_state, "determined_supplier_analog", "field", 1, 4, 0, {
		"triggered_abilities": [{"family": "last_gasp", "effects": [{"op": "gain_max_magicka", "amount_source": "self_power"}]}],
	})
	# Dagger analog: +1 power on equip.
	var dagger := _add_hand_card(player, "dagger_analog", {
		"card_type": "item",
		"cost": 0,
		"equip_power_bonus": 1,
	})
	var equip_result := PersistentCardRules.play_item_from_hand(match_state, pid, dagger["instance_id"], {"target_instance_id": supplier["instance_id"]})
	if not _assert(equip_result["is_valid"], "Dagger analog should equip successfully."):
		return false
	if not _assert(EvergreenRules.get_power(supplier) == 2, "Supplier should be 2 power after Dagger (1 base + 1 equip)."):
		return false
	# Destroy via action so the full trigger pipeline resolves the last_gasp.
	var destroy_action := _add_hand_card(player, "destroy_action", {
		"card_type": "action",
		"cost": 0,
		"action_target_mode": "any_creature",
		"triggered_abilities": [{"family": MatchTiming.FAMILY_ON_PLAY, "effects": [{"op": "destroy_creature", "target": "event_target"}]}],
	})
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(destroy_action.get("instance_id", "")), {"target_instance_id": str(supplier.get("instance_id", ""))})
	if not _assert(bool(play_result.get("is_valid", false)), "Destroy action should play successfully."):
		return false
	# Base power 1 + item bonus 1 = 2 magicka gained; without fix this would be 1.
	return _assert(int(player.get("max_magicka", 0)) == 7, "Max magicka should be 5 + buffed_power 2 = 7, got %d." % int(player.get("max_magicka", 0)))


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


func _test_lute_attached_item_grants_silence_immunity() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	var host := _summon_creature(player, match_state, "lute_host", "field", 2, 3, 0)
	var bare := _summon_creature(player, match_state, "bare_creature", "field", 2, 3, 1)
	var lute := _add_hand_card(player, "lute", {
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 1,
		"equip_health_bonus": 2,
		"grants_immunity": ["silence"],
	})
	var play_result := PersistentCardRules.play_item_from_hand(match_state, pid, lute["instance_id"], {"target_instance_id": host["instance_id"]})
	if not _assert(play_result["is_valid"], "Fixture: Lute should attach to host."):
		return false
	return (
		_assert(MatchTimingHelpers._is_immune_to_effect(match_state, host, "silence"), "Lute: wielder should be immune to silence.") and
		_assert(not MatchTimingHelpers._is_immune_to_effect(match_state, bare, "silence"), "Lute: unequipped friendly creature should NOT be immune.")
	)


func _test_yokudan_nightblade_grants_silence_immunity_to_equipped_friendlies() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	var yokudan := _summon_creature(player, match_state, "yokudan_analog", "shadow", 1, 4, 0, {
		"grants_immunity": ["silence_on_equipped"],
	})
	var bare := _summon_creature(player, match_state, "bare_friendly", "field", 2, 3, 0)
	var host := _summon_creature(player, match_state, "equipped_friendly", "field", 2, 3, 1)
	var item := _add_hand_card(player, "test_dagger", {
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 1,
	})
	var play_result := PersistentCardRules.play_item_from_hand(match_state, pid, item["instance_id"], {"target_instance_id": host["instance_id"]})
	if not _assert(play_result["is_valid"], "Fixture: item should attach to host."):
		return false
	var yokudan_item := _add_hand_card(player, "yokudan_dagger", {"card_type": "item", "cost": 1, "equip_power_bonus": 1})
	PersistentCardRules.play_item_from_hand(match_state, pid, yokudan_item["instance_id"], {"target_instance_id": yokudan["instance_id"]})
	var enemy: Dictionary = match_state["players"][1]
	var enemy_equipped := _summon_creature(enemy, match_state, "enemy_equipped", "field", 2, 3, 0)
	var enemy_item := _add_hand_card(enemy, "enemy_dagger", {"card_type": "item", "cost": 1, "equip_power_bonus": 1})
	PersistentCardRules.play_item_from_hand(match_state, str(enemy["player_id"]), enemy_item["instance_id"], {"target_instance_id": enemy_equipped["instance_id"]})
	return (
		_assert(MatchTimingHelpers._is_immune_to_effect(match_state, host, "silence"), "Yokudan: equipped friendly creature should be immune to silence.") and
		_assert(not MatchTimingHelpers._is_immune_to_effect(match_state, bare, "silence"), "Yokudan: unequipped friendly creature should NOT be immune to silence.") and
		_assert(MatchTimingHelpers._is_immune_to_effect(match_state, yokudan, "silence"), "Yokudan: Yokudan itself should be immune when equipped (rules text includes self).") and
		_assert(not MatchTimingHelpers._is_immune_to_effect(match_state, enemy_equipped, "silence"), "Yokudan: enemy equipped creature should NOT be immune (aura is friendly-only).")
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


func _test_dark_rift_summons_atronach_after_five_activations() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	var support := _add_hand_card(player, "int_dark_rift", {
		"card_type": "support",
		"cost": 3,
		"support_uses": 5,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"required_zone": "support",
			"effects": [
				{"op": "damage", "target_player": "opponent", "amount": 1},
				{"op": "summon_from_effect", "require_source_uses_exhausted": true, "lane_id": "random", "card_template": {
					"definition_id": "int_storm_atronach", "name": "Storm Atronach",
					"card_type": "creature", "subtypes": ["Daedra", "Atronach"],
					"attributes": ["intelligence"], "cost": 6,
					"power": 7, "health": 5, "base_power": 7, "base_health": 5,
					"keywords": ["ward"], "rules_text": "Ward",
				}},
			],
		}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, support["instance_id"])
	# Activate 5 times (once per turn)
	for i in range(5):
		PersistentCardRules.activate_support(match_state, pid, support["instance_id"])
		if i < 4:
			MatchTurnLoop.end_turn(match_state, pid)
			MatchTurnLoop.end_turn(match_state, match_state["active_player_id"])
	# After 5 activations, support should be discarded and a Storm Atronach summoned
	var atronach := _find_lane_card(match_state, "field", pid, "int_storm_atronach")
	if atronach.is_empty():
		atronach = _find_lane_card(match_state, "shadow", pid, "int_storm_atronach")
	return (
		_assert(not atronach.is_empty(), "Dark Rift: Storm Atronach should be summoned after 5 activations.") and
		_assert(EvergreenRules.get_power(atronach) == 7, "Dark Rift: Storm Atronach should have 7 power.") and
		_assert(EvergreenRules.get_health(atronach) == 5, "Dark Rift: Storm Atronach should have 5 health.") and
		_assert(EvergreenRules.has_keyword(atronach, "ward"), "Dark Rift: Storm Atronach should have Ward.") and
		_assert(_contains_instance(player["discard"], support["instance_id"]), "Dark Rift: support should be in discard after exhaustion.")
	)


func _test_transform_card_updates_definition_id_from_raw_seed() -> bool:
	# When transform_card receives a raw catalog seed (card_id, not definition_id),
	# it should normalize card_id → definition_id so art_path and identity resolve correctly.
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var card := _add_hand_card(player, "harvest", {
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 1,
		"equip_health_bonus": 1,
		"_base_cost": 1,
	})
	# Simulate a raw catalog seed template (uses "card_id" instead of "definition_id")
	var raw_seed := {
		"card_id": "str_heavy_battleaxe",
		"name": "Heavy Battleaxe",
		"card_type": "item",
		"cost": 4,
		"base_power": 0,
		"base_health": 0,
		"keywords": [],
		"rules_text": "+4/+1",
		"equip_power_bonus": 4,
		"equip_health_bonus": 1,
		"equip_keywords": [],
		"triggered_abilities": [],
		"rarity": "common",
		"collectible": true,
	}
	var result: Dictionary = MatchMutations.transform_card(match_state, card["instance_id"], raw_seed, {})
	var transformed: Dictionary = result.get("card", {})
	return (
		_assert(result["is_valid"], "Transform with raw seed should succeed.") and
		_assert(str(transformed.get("definition_id", "")) == "str_heavy_battleaxe", "Transform should set definition_id from card_id. Got '%s'." % str(transformed.get("definition_id", ""))) and
		_assert(str(transformed.get("art_path", "")).find("str_heavy_battleaxe") >= 0, "Transform should derive art_path from new definition_id. Got '%s'." % str(transformed.get("art_path", ""))) and
		_assert(int(transformed.get("equip_power_bonus", 0)) == 4, "Transform should update equip_power_bonus. Got %d." % int(transformed.get("equip_power_bonus", 0))) and
		_assert(int(transformed.get("equip_health_bonus", 0)) == 1, "Transform should update equip_health_bonus. Got %d." % int(transformed.get("equip_health_bonus", 0)))
	)


func _test_transform_card_updates_base_cost() -> bool:
	# After transform, _base_cost should match the new card's cost so the UI
	# doesn't show a stale red/green cost color.
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var card := _add_hand_card(player, "cheap_item", {
		"card_type": "item",
		"cost": 1,
		"_base_cost": 1,
	})
	var template := {
		"definition_id": "expensive_item",
		"name": "Expensive Item",
		"card_type": "item",
		"cost": 6,
		"base_power": 0,
		"base_health": 0,
		"keywords": [],
		"rules_text": "+5/+5",
		"equip_power_bonus": 5,
		"equip_health_bonus": 5,
		"equip_keywords": [],
		"triggered_abilities": [],
	}
	var result: Dictionary = MatchMutations.transform_card(match_state, card["instance_id"], template, {})
	var transformed: Dictionary = result.get("card", {})
	return (
		_assert(result["is_valid"], "Transform should succeed.") and
		_assert(int(transformed.get("cost", 0)) == 6, "Transform should update cost to 6. Got %d." % int(transformed.get("cost", 0))) and
		_assert(int(transformed.get("_base_cost", 0)) == 6, "Transform should update _base_cost to match new cost. Got %d." % int(transformed.get("_base_cost", 0)))
	)


func _test_altar_of_spellmaking_plays_top_of_deck() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Place a creature in the deck (at the end = top of deck since pop_back is used)
	var deck_creature := {
		"instance_id": pid + "_deck_mammoth",
		"definition_id": "deck_mammoth",
		"name": "Young Mammoth",
		"card_type": "creature",
		"cost": 4,
		"power": 4,
		"health": 4,
		"keywords": [],
		"triggered_abilities": [],
		"owner_player_id": pid,
		"controller_player_id": pid,
		"zone": "deck",
	}
	player["deck"].append(deck_creature)
	# Add the Altar of Spellmaking support with end_of_turn trigger
	var altar := _add_hand_card(player, "altar_of_spellmaking", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "end_of_turn", "required_zone": "support", "required_card_types_played_this_turn": {"types": ["creature", "action", "item", "support"]}, "effects": [{"op": "play_top_of_deck"}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(altar["instance_id"]))
	# Summon a creature from hand (registers "creature" type)
	var creature := _add_hand_card(player, "test_creature", {"card_type": "creature", "cost": 0, "power": 1, "health": 1})
	LaneRules.summon_from_hand(match_state, pid, str(creature["instance_id"]), "field")
	# Play an item on it (registers "item" type)
	var item := _add_hand_card(player, "test_item", {"card_type": "item", "cost": 0, "equip_power_bonus": 1})
	PersistentCardRules.play_item_from_hand(match_state, pid, str(item["instance_id"]), {"target_instance_id": str(creature["instance_id"])})
	# Manually add "action" to card_types_played_this_turn (avoids action targeting complexity)
	var types_arr: Array = player.get("card_types_played_this_turn", [])
	if not types_arr.has("action"):
		types_arr.append("action")
		player["card_types_played_this_turn"] = types_arr
	# End turn — the Altar's end_of_turn trigger should fire and move the top card to hand as a free play
	var hand_before: int = player["hand"].size()
	MatchTurnLoop.end_turn(match_state, pid)
	# The deck creature should now be in hand marked as a free play
	var found_in_hand := false
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == pid + "_deck_mammoth":
			found_in_hand = true
			break
	var pending: Array = match_state.get("pending_free_plays", [])
	var found_pending := false
	for entry in pending:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("instance_id", "")) == pid + "_deck_mammoth":
			found_pending = true
			break
	return (
		_assert(found_in_hand, "Altar of Spellmaking: top card should be moved to hand.") and
		_assert(found_pending, "Altar of Spellmaking: top card should be registered as a pending free play.")
	)


func _test_priest_of_mara_equips_amulets_via_dual_target() -> bool:
	# Priest of Mara: Summon with target_mode enemy_creature + secondary_target_mode friendly_creature_without_guard.
	# Primary pick equips Amulet of Mara to the chosen enemy, secondary pick equips to chosen friendly (no Guard).
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Pre-place a friendly creature (no Guard) and a Guard creature in field lane
	var friendly := _summon_creature(player, match_state, "friendly_soldier", "field", 2, 4, -1)
	var friendly_id := str(friendly.get("instance_id", ""))
	var guard := _summon_creature(player, match_state, "friendly_guard", "field", 1, 4, -1, {"keywords": ["guard"]})
	var guard_id := str(guard.get("instance_id", ""))
	# Pre-place an enemy creature
	var enemy := _summon_creature(opponent, match_state, "enemy_target", "field", 1, 3, -1)
	var enemy_id := str(enemy.get("instance_id", ""))
	# Add Priest of Mara to hand
	var amulet_template := {
		"definition_id": "mc_wil_amulet_of_mara", "name": "Amulet of Mara",
		"card_type": "item", "attributes": ["willpower"], "cost": 0,
		"power": 0, "health": 0, "base_power": 0, "base_health": 0,
		"equip_health_bonus": 1,
		"rules_text": "+0/+1\nThe wielder can't attack other creatures equipped with an Amulet of Mara.",
	}
	var priest := _add_hand_card(player, "priest_of_mara", {
		"card_type": "creature", "cost": 3, "power": 2, "health": 5,
		"triggered_abilities": [{
			"family": "summon", "target_mode": "enemy_creature",
			"secondary_target_mode": "friendly_creature_without_guard",
			"effects": [
				{"op": "equip_generated_item", "target": "chosen_target", "card_template": amulet_template},
				{"op": "equip_generated_item", "target": "chosen_target", "card_template": amulet_template},
			],
		}],
	})
	var priest_id := str(priest.get("instance_id", ""))
	# Play Priest — trigger system skips summon+target_mode; UI detects target_mode abilities
	LaneRules.summon_from_hand(match_state, pid, priest_id, "field", {})
	var abilities := MatchTargeting.get_target_mode_abilities(_find_lane_card(match_state, "field", pid, "priest_of_mara"))
	if not _assert(not abilities.is_empty(), "Priest of Mara should have target_mode abilities detected."):
		return false
	# Enemy health before amulet
	var enemy_health_before := EvergreenRules.get_remaining_health(enemy)
	# Resolve primary target via resolve_targeted_effect — pick the enemy creature
	var resolve1 := MatchTiming.resolve_targeted_effect(match_state, priest_id, {"target_instance_id": enemy_id})
	if not _assert(bool(resolve1.get("is_valid", false)), "Primary target resolution (enemy) should succeed."):
		return false
	# Enemy should now have the amulet equipped (+0/+1)
	var enemy_health_after := EvergreenRules.get_remaining_health(enemy)
	if not _assert(enemy_health_after == enemy_health_before + 1, "Enemy should gain +1 health from Amulet of Mara, got %d -> %d." % [enemy_health_before, enemy_health_after]):
		return false
	# Should have queued a pending_summon_effect_targets entry for the secondary target
	if not _assert(MatchTiming.has_pending_summon_effect_target(match_state, pid), "Priest of Mara should queue secondary pending target for friendly creature without Guard."):
		return false
	# Resolve secondary target — pick the friendly soldier (no Guard)
	var friendly_health_before := EvergreenRules.get_remaining_health(friendly)
	var resolve2 := MatchTiming.resolve_pending_summon_effect_target(match_state, pid, {"target_instance_id": friendly_id})
	if not _assert(bool(resolve2.get("is_valid", false)), "Secondary target resolution (friendly) should succeed."):
		return false
	var friendly_health_after := EvergreenRules.get_remaining_health(friendly)
	if not _assert(friendly_health_after == friendly_health_before + 1, "Friendly should gain +1 health from Amulet of Mara, got %d -> %d." % [friendly_health_before, friendly_health_after]):
		return false
	# No more pending targets
	if not _assert(not MatchTiming.has_pending_summon_effect_target(match_state, pid), "No more pending targets after both amulets equipped."):
		return false
	# Guard creature should NOT be a valid secondary target — verify by checking it has no amulet
	var guard_health := EvergreenRules.get_remaining_health(guard)
	return _assert(guard_health == 4, "Guard creature should NOT have received an amulet, health should still be 4, got %d." % guard_health)


func _test_support_last_gasp_draw_filtered_applies_post_draw_buff() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	# Place a Daedra creature in the deck for draw_filtered to find
	var daedra_card := {
		"instance_id": "player_1_deck_daedra",
		"definition_id": "test_daedra",
		"name": "Test Daedra",
		"card_type": "creature",
		"subtypes": ["Daedra"],
		"cost": 3,
		"power": 2,
		"health": 3,
		"base_power": 2,
		"base_health": 3,
		"keywords": [],
		"triggered_abilities": [],
		"owner_player_id": player["player_id"],
		"controller_player_id": player["player_id"],
		"zone": "deck",
	}
	player["deck"] = [daedra_card]
	# Create a support with 1 use, activate trigger, and last_gasp draw_filtered + buff
	var support := _add_hand_card(player, "sigil_stone", {
		"card_type": "support",
		"cost": 1,
		"activation_cost": 0,
		"support_uses": 1,
		"triggered_abilities": [
			{
				"family": MatchTiming.FAMILY_ACTIVATE,
				"required_zone": "support",
				"effects": [{"op": "modify_stats", "target": "self", "power": 0, "health": 0}],
			},
			{
				"family": "last_gasp",
				"effects": [{"op": "draw_filtered", "filter": {"subtype": "Daedra"}, "post_draw_modify": {"power": 2, "health": 2}}],
			},
		],
	})
	PersistentCardRules.play_support_from_hand(match_state, player["player_id"], support["instance_id"])
	# Activate — uses the last charge, triggering exhaustion and last_gasp
	PersistentCardRules.activate_support(match_state, player["player_id"], support["instance_id"], {})
	# The Daedra should have been drawn into hand with +2/+2 buff
	var drawn := {}
	for hand_card in player["hand"]:
		if typeof(hand_card) == TYPE_DICTIONARY and str(hand_card.get("instance_id", "")) == "player_1_deck_daedra":
			drawn = hand_card
			break
	if not _assert(not drawn.is_empty(), "Last gasp draw_filtered should draw the Daedra into hand."):
		return false
	var effective_power := EvergreenRules.get_power(drawn)
	var effective_health := EvergreenRules.get_remaining_health(drawn)
	return (
		_assert(effective_power == 4, "Drawn Daedra should have 2 base + 2 buff = 4 power, got %d." % effective_power) and
		_assert(effective_health == 5, "Drawn Daedra should have 3 base + 2 buff = 5 health, got %d." % effective_health)
	)


func _test_support_on_play_summon_from_effect_with_chosen_lane() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	var support := _add_hand_card(player, "corsair_ship", {
		"card_type": "support", "cost": 0, "support_uses": 0,
		"triggered_abilities": [{
			"family": "on_play",
			"effects": [{"op": "summon_from_effect", "lane": "chosen", "card_template": {
				"definition_id": "corsair_token", "name": "Corsair", "card_type": "creature",
				"attributes": ["intelligence"], "cost": 1, "power": 1, "health": 1,
				"base_power": 1, "base_health": 1, "subtypes": ["Breton"], "rules_text": "",
			}}],
		}],
	})
	var result := PersistentCardRules.play_support_from_hand(match_state, pid, support["instance_id"], {"lane_id": "field"})
	if not _assert(bool(result.get("is_valid", false)), "Support play should succeed."):
		return false
	var found := false
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == "field":
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "corsair_token":
					found = true
	if not _assert(found, "Corsair token should be summoned in the field lane."):
		return false
	# Test pending lane selection path (no lane_id → creates pending → resolve with lane)
	var match_state3 := _build_started_match()
	var player3: Dictionary = match_state3["players"][0]
	var pid3: String = player3["player_id"]
	var ship3 := _add_hand_card(player3, "corsair_ship3", {
		"card_type": "support", "cost": 0, "support_uses": 0,
		"triggered_abilities": [
			{"family": "on_play", "effects": [{"op": "summon_from_effect", "lane": "chosen", "card_template": {
				"definition_id": "corsair_token3", "name": "Corsair", "card_type": "creature",
				"attributes": ["intelligence"], "cost": 1, "power": 1, "health": 1,
				"base_power": 1, "base_health": 1, "subtypes": ["Breton"], "rules_text": "",
			}}]},
			{"family": "on_friendly_summon", "required_zone": "support", "effects": [{"op": "equip_generated_item", "target": "event_summoned_creature", "card_template": {
				"definition_id": "steel_dagger", "name": "Steel Dagger", "card_type": "item",
				"attributes": ["neutral"], "cost": 1, "power": 0, "health": 0,
				"base_power": 0, "base_health": 0, "equip_power_bonus": 1, "rules_text": "+1/+0",
			}}]},
		],
	})
	var result3 := PersistentCardRules.play_support_from_hand(match_state3, pid3, ship3["instance_id"])
	if not _assert(bool(result3.get("is_valid", false)), "Pending lane: support play should succeed."):
		return false
	if not _assert(MatchTiming.has_pending_support_lane_selection(match_state3, pid3), "Pending lane selection should exist after playing support without lane_id."):
		return false
	var resolve3 := MatchTiming.resolve_pending_support_lane_selection(match_state3, pid3, "field")
	if not _assert(bool(resolve3.get("is_valid", false)), "Pending lane resolution should succeed."):
		return false
	var corsair3 := {}
	for lane in match_state3.get("lanes", []):
		if str(lane.get("lane_id", "")) == "field":
			for card in lane.get("player_slots", {}).get(pid3, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "corsair_token3":
					corsair3 = card
	if not _assert(not corsair3.is_empty(), "Pending lane: Corsair should be in field lane."):
		return false
	var dagger_equipped: bool = not corsair3.get("attached_items", []).is_empty()
	if not _assert(dagger_equipped, "Pending lane: on_friendly_summon should equip Steel Dagger to Corsair. Items: %s" % str(corsair3.get("attached_items", []))):
		return false
	# Also verify action enumerator generates lane variants for such supports
	var match_state2 := _build_started_match()
	var player2: Dictionary = match_state2["players"][0]
	var pid2: String = player2["player_id"]
	_add_hand_card(player2, "corsair_ship2", {
		"card_type": "support", "cost": 0, "support_uses": 0,
		"triggered_abilities": [{
			"family": "on_play",
			"effects": [{"op": "summon_from_effect", "lane": "chosen", "card_template": {
				"definition_id": "corsair_token2", "name": "Corsair", "card_type": "creature",
				"attributes": ["intelligence"], "cost": 1, "power": 1, "health": 1,
				"base_power": 1, "base_health": 1, "subtypes": ["Breton"], "rules_text": "",
			}}],
		}],
	})
	var actions := MatchActionEnumerator.enumerate_legal_actions(match_state2, pid2)
	var support_actions: Array = []
	for action in actions.get("actions", []):
		if str(action.get("kind", "")) == "play_support" and str(action.get("source_card", {}).get("definition_id", "")) == "corsair_ship2":
			support_actions.append(action)
	return _assert(support_actions.size() >= 2, "Support with lane-chosen summon should enumerate at least 2 lane variants, got %d." % support_actions.size())


func _test_support_activate_summon_from_effect_chosen_lane() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid: String = player["player_id"]
	# Summon a creature in the shadow lane to target
	var target := _summon_creature(player, match_state, "dwemer_target", "shadow", 3, 3, 0)
	# Create a support that on activate gives -1/-1 and summons a token in the chosen target's lane
	var support := _add_hand_card(player, "recon_engine", {
		"card_type": "support", "cost": 0, "support_uses": 5,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"target_mode": "friendly_creature",
			"effects": [
				{"op": "modify_stats", "target": "chosen_target", "power": -1, "health": -1},
				{"op": "summon_from_effect", "lane": "chosen", "card_template": {
					"definition_id": "recon_spider", "name": "Reconstructed Spider", "card_type": "creature",
					"attributes": ["neutral"], "cost": 1, "power": 1, "health": 1,
					"base_power": 1, "base_health": 1, "subtypes": ["Dwemer"], "rules_text": "",
				}},
			],
		}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, support["instance_id"])
	var result := PersistentCardRules.activate_support(match_state, pid, support["instance_id"], {"target_instance_id": target["instance_id"]})
	if not _assert(bool(result.get("is_valid", false)), "Reconstruction Engine activate should succeed."):
		return false
	# Verify the spider was summoned in the shadow lane (same lane as the target)
	var spider_found := false
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) == "shadow":
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "recon_spider":
					spider_found = true
	return _assert(spider_found, "Reconstructed Spider should be summoned in shadow lane (chosen target's lane).")


func _test_strategists_map_summons_target_for_chosen_owner() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var opp_id := str(opponent.get("player_id", ""))
	# Place Strategist's Map in support zone
	var map := _add_hand_card(player, "strategists_map", {
		"card_type": "support", "cost": 0, "support_uses": 3,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_ACTIVATE,
			"target_mode": "choose_lane_and_owner",
			"effects": [{"op": "summon_from_effect", "lane": "chosen", "target_player": "target_player", "card_template": {
				"definition_id": "hom_neu_target", "name": "Target", "card_type": "creature",
				"attributes": ["neutral"], "cost": 0, "power": 0, "health": 1,
				"base_power": 0, "base_health": 1, "keywords": ["guard"], "subtypes": ["Defense"],
				"rules_text": "Guard",
			}}],
		}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, map["instance_id"])
	# Activate: summon Target on opponent's side of field lane
	var result := PersistentCardRules.activate_support(match_state, pid, map["instance_id"], {"lane_id": "field", "target_player_id": opp_id})
	if not _assert(bool(result.get("is_valid", false)), "Strategist's Map activate should succeed."):
		return false
	var target_found := false
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != "field":
			continue
		for card in lane.get("player_slots", {}).get(opp_id, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "hom_neu_target":
				target_found = true
				if not _assert(EvergreenRules.has_keyword(card, "guard"), "Summoned Target should have Guard."):
					return false
	return _assert(target_found, "Strategist's Map should summon a Target on opponent's side of field lane.")


func _make_umbra_item(player_id: String) -> Dictionary:
	return {
		"instance_id": player_id + "_umbra",
		"definition_id": "hom_wil_umbra",
		"name": "Umbra",
		"card_type": "item",
		"cost": 6,
		"equip_power_bonus": 3,
		"equip_health_bonus": 5,
		"grants_forced_attack_at_turn_start": true,
		"owner_player_id": player_id,
		"controller_player_id": player_id,
		"zone": "attached_item",
	}


func _attach_umbra(creature: Dictionary, player_id: String) -> void:
	EvergreenRules.ensure_card_state(creature)
	creature["attached_items"].append(_make_umbra_item(player_id))


func _end_turn_and_start_next(match_state: Dictionary) -> void:
	var active_pid := str(match_state.get("active_player_id", ""))
	MatchTurnLoop.end_turn(match_state, active_pid)


func _test_umbra_forced_attack_hits_enemy_creature() -> bool:
	var match_state := _build_started_match()
	ScenarioFixtures.set_rng_seed(match_state, 42)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	# Summon a wielder for player 0 in field lane
	var wielder := ScenarioFixtures.summon_creature(player, match_state, "umbra_wielder", "field", 2, 5)
	_attach_umbra(wielder, pid)
	ScenarioFixtures.ready_for_attack(wielder, match_state)
	# Summon an enemy creature in the same lane
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_target", "field", 1, 6)
	# End player 0's turn, then end player 1's turn → starts player 0's turn → Umbra fires
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	# Wielder has 2+3=5 power from Umbra, enemy had 6 health → should have 5 damage
	var enemy_damage := int(enemy.get("damage_marked", 0))
	var wielder_attacked := bool(wielder.get("has_attacked_this_turn", false))
	return (
		_assert(enemy_damage == 5, "Umbra forced attack: enemy should take 5 damage (2 base + 3 Umbra), got %d." % enemy_damage) and
		_assert(wielder_attacked, "Umbra forced attack: wielder should be marked as having attacked this turn.")
	)


func _test_umbra_forced_attack_skips_when_no_enemies() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	# Summon wielder in field lane with Umbra, no enemies
	var wielder := ScenarioFixtures.summon_creature(player, match_state, "umbra_wielder", "field", 2, 5)
	_attach_umbra(wielder, pid)
	ScenarioFixtures.ready_for_attack(wielder, match_state)
	# End player 0's turn, then end player 1's turn → starts player 0's turn
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	var wielder_attacked := bool(wielder.get("has_attacked_this_turn", false))
	return _assert(not wielder_attacked, "Umbra forced attack: wielder should NOT have attacked when no enemy creatures exist.")


func _test_umbra_forced_attack_respects_guards() -> bool:
	var match_state := _build_started_match()
	ScenarioFixtures.set_rng_seed(match_state, 99)
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	# Summon wielder in field lane with Umbra
	var wielder := ScenarioFixtures.summon_creature(player, match_state, "umbra_wielder", "field", 2, 5)
	_attach_umbra(wielder, pid)
	ScenarioFixtures.ready_for_attack(wielder, match_state)
	# Summon non-guard and guard enemy in the same lane
	var non_guard := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_no_guard", "field", 1, 6)
	var guard := ScenarioFixtures.summon_creature(opponent, match_state, "enemy_guard", "field", 1, 6, ["guard"])
	# Cycle turns so Umbra fires on player 0's next turn start
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	var guard_damage := int(guard.get("damage_marked", 0))
	var non_guard_damage := int(non_guard.get("damage_marked", 0))
	return (
		_assert(guard_damage == 5, "Umbra forced attack: guard should take 5 damage, got %d." % guard_damage) and
		_assert(non_guard_damage == 0, "Umbra forced attack: non-guard should take 0 damage when guard exists, got %d." % non_guard_damage)
	)


func _test_sehts_masterwork_reduces_cost_for_singleton_deck() -> bool:
	# Default _build_started_match uses unique definition IDs so _singleton_deck should be true
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	# Verify the singleton flag was set
	if not _assert(bool(player.get("_singleton_deck", false)), "Player with unique deck IDs should have _singleton_deck=true."):
		return false
	# Place Seht's Masterwork support with the singleton cost reduction aura
	var masterwork := ScenarioFixtures.make_card(pid, "sehts_masterwork", {
		"card_type": "support",
		"cost": 3,
		"support_uses": 0,
		"cost_reduction_aura": {"scope": "hand", "target": "all_friendly", "amount": 1, "required_singleton_deck": true},
	})
	masterwork["zone"] = "support"
	player["support"].append(masterwork)
	# Add a creature to hand with cost 5
	var hand_card := _add_hand_card(player, "test_cost_card", {"card_type": "creature", "cost": 5, "power": 3, "health": 3})
	var effective := PersistentCardRules.get_effective_play_cost(match_state, pid, hand_card)
	return _assert(effective == 4, "Seht's Masterwork should reduce cost by 1 for singleton deck, expected 4 got %d." % effective)


func _test_sehts_masterwork_no_discount_for_duplicate_deck() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	# Force the singleton flag to false (simulating a deck with duplicates)
	player["_singleton_deck"] = false
	# Place Seht's Masterwork support
	var masterwork := ScenarioFixtures.make_card(pid, "sehts_masterwork2", {
		"card_type": "support",
		"cost": 3,
		"support_uses": 0,
		"cost_reduction_aura": {"scope": "hand", "target": "all_friendly", "amount": 1, "required_singleton_deck": true},
	})
	masterwork["zone"] = "support"
	player["support"].append(masterwork)
	# Add a creature to hand with cost 5
	var hand_card := _add_hand_card(player, "test_cost_card2", {"card_type": "creature", "cost": 5, "power": 3, "health": 3})
	var effective := PersistentCardRules.get_effective_play_cost(match_state, pid, hand_card)
	return _assert(effective == 5, "Seht's Masterwork should NOT reduce cost for non-singleton deck, expected 5 got %d." % effective)


func _test_transitus_shrine_only_discounts_creatures_and_actions() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	# Place a creature in each lane so the condition is met
	ScenarioFixtures.summon_creature(player, match_state, "field_filler", "field", 1, 1)
	ScenarioFixtures.summon_creature(player, match_state, "shadow_filler", "shadow", 1, 1)
	# Place Transitus Shrine support
	var shrine := ScenarioFixtures.make_card(pid, "transitus_shrine", {
		"card_type": "support",
		"cost": 3,
		"support_uses": 0,
		"cost_reduction_aura": {"target": "friendly_creatures_and_actions", "amount": 1, "condition": "creature_in_each_lane", "filter_card_types": ["creature", "action"]},
	})
	shrine["zone"] = "support"
	player["support"].append(shrine)
	# Creature in hand: should be discounted
	var hand_creature := _add_hand_card(player, "ts_creature", {"card_type": "creature", "cost": 5, "power": 3, "health": 3})
	var creature_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, hand_creature)
	# Action in hand: should be discounted
	var hand_action := _add_hand_card(player, "ts_action", {"card_type": "action", "cost": 4})
	var action_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, hand_action)
	# Support in hand: should NOT be discounted
	var hand_support := _add_hand_card(player, "ts_support", {"card_type": "support", "cost": 5, "support_uses": 3})
	var support_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, hand_support)
	# Item in hand: should NOT be discounted
	var hand_item := _add_hand_card(player, "ts_item", {"card_type": "item", "cost": 3})
	var item_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, hand_item)
	return (
		_assert(creature_cost == 4, "Transitus Shrine should discount creature from 5 to 4, got %d." % creature_cost) and
		_assert(action_cost == 3, "Transitus Shrine should discount action from 4 to 3, got %d." % action_cost) and
		_assert(support_cost == 5, "Transitus Shrine should NOT discount support, expected 5 got %d." % support_cost) and
		_assert(item_cost == 3, "Transitus Shrine should NOT discount item, expected 3 got %d." % item_cost)
	)


func _test_ring_of_lordship_discounts_creatures_matching_wielder_subtype() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	# Summon an Orc wielder in the field lane
	var wielder := ScenarioFixtures.summon_creature(player, match_state, "orc_wielder", "field", 2, 2, [], -1, {"subtypes": ["Orc"]})
	# Attach Ring of Lordship to the wielder
	var ring := {
		"instance_id": pid + "_ring_of_lordship",
		"definition_id": "iom_neu_ring_of_lordship",
		"name": "Ring of Lordship",
		"card_type": "item",
		"cost": 1,
		"equip_power_bonus": 0,
		"equip_health_bonus": 2,
		"cost_reduction_aura": {"scope": "hand", "target": "friendly", "amount": 1, "filter_subtype_matches_wielder": true},
		"owner_player_id": pid,
		"controller_player_id": pid,
		"zone": "attached_item",
	}
	EvergreenRules.ensure_card_state(wielder)
	wielder["attached_items"].append(ring)
	# Orc creature in hand: should be discounted
	var orc_hand := _add_hand_card(player, "orc_hand", {"card_type": "creature", "cost": 6, "power": 4, "health": 6, "subtypes": ["Orc"]})
	var orc_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, orc_hand)
	# Non-Orc (Nord) creature in hand: should NOT be discounted
	var nord_hand := _add_hand_card(player, "nord_hand", {"card_type": "creature", "cost": 5, "power": 3, "health": 3, "subtypes": ["Nord"]})
	var nord_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, nord_hand)
	return (
		_assert(orc_cost == 5, "Ring of Lordship should discount Orc from 6 to 5, got %d." % orc_cost) and
		_assert(nord_cost == 5, "Ring of Lordship should NOT discount Nord (non-matching subtype), expected 5 got %d." % nord_cost)
	)


func _test_ring_of_lordship_requires_wielder_in_lane() -> bool:
	# The ring's aura should only apply when equipped to a lane creature — unequipped item in hand grants no discount
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	# Place the ring in hand (unequipped) with its full aura payload
	_add_hand_card(player, "unequipped_ring", {
		"card_type": "item",
		"cost": 1,
		"cost_reduction_aura": {"scope": "hand", "target": "friendly", "amount": 1, "filter_subtype_matches_wielder": true},
	})
	# Add an Orc creature in hand
	var orc_hand := _add_hand_card(player, "orc_hand_unequipped", {"card_type": "creature", "cost": 6, "power": 4, "health": 6, "subtypes": ["Orc"]})
	var orc_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, orc_hand)
	return _assert(orc_cost == 6, "Ring of Lordship in hand (unequipped) should NOT discount, expected 6 got %d." % orc_cost)


func _test_last_gasp_returns_equipped_items_to_hand() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var opid := str(opponent.get("player_id", ""))
	# Summon creature with last_gasp: return_equipped_items_to_hand
	var phantom := _summon_creature(player, match_state, "daggerfall_phantom", "field", 2, 2, 0, {
		"effect_ids": ["last_gasp"],
		"triggered_abilities": [{"family": "last_gasp", "effects": [{"op": "return_equipped_items_to_hand", "target": "self"}]}],
	})
	# Equip two items
	var dagger := _add_hand_card(player, "dagger_a", {
		"card_type": "item", "cost": 1, "equip_power_bonus": 1,
	})
	var sword := _add_hand_card(player, "sword_a", {
		"card_type": "item", "cost": 2, "equip_power_bonus": 2,
	})
	PersistentCardRules.play_item_from_hand(match_state, pid, dagger["instance_id"], {"target_instance_id": phantom["instance_id"]})
	PersistentCardRules.play_item_from_hand(match_state, pid, sword["instance_id"], {"target_instance_id": phantom["instance_id"]})
	if not _assert(phantom.get("attached_items", []).size() == 2, "Phantom should have 2 items equipped."):
		return false
	# Summon a big enemy to kill phantom via combat
	_end_turn_and_start_next(match_state)  # end player_1 turn, start player_2 turn
	var killer := _summon_creature(opponent, match_state, "killer", "field", 20, 20, 0)
	ScenarioFixtures.ready_for_attack(killer, match_state)
	MatchCombat.resolve_attack(match_state, opid, str(killer.get("instance_id", "")), {
		"type": "creature", "instance_id": str(phantom.get("instance_id", "")),
	})
	var dagger_in_hand := _contains_instance(player["hand"], dagger["instance_id"])
	var sword_in_hand := _contains_instance(player["hand"], sword["instance_id"])
	var dagger_in_discard := _contains_instance(player["discard"], dagger["instance_id"])
	var sword_in_discard := _contains_instance(player["discard"], sword["instance_id"])
	return (
		_assert(dagger_in_hand, "Dagger should be returned to hand by last gasp, not discard.") and
		_assert(sword_in_hand, "Sword should be returned to hand by last gasp, not discard.") and
		_assert(not dagger_in_discard, "Dagger should not remain in discard after last gasp.") and
		_assert(not sword_in_discard, "Sword should not remain in discard after last gasp.")
	)


func _test_end_of_turn_support_fires_when_health_gained() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Add a support with end_of_turn trigger conditioned on health gained
	var support := _add_hand_card(player, "conjurers_spirit", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "end_of_turn", "required_zone": "support", "required_gained_health_this_turn": true, "effects": [{"op": "summon_from_effect", "lane": "random", "card_template": {"definition_id": "familiar_token", "name": "Familiar", "card_type": "creature", "attributes": ["willpower"], "cost": 2, "power": 2, "health": 2, "base_power": 2, "base_health": 2, "subtypes": [], "rules_text": ""}}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(support["instance_id"]))
	# Simulate player gaining health via a player_healed event
	MatchTiming.publish_events(match_state, [{"event_type": "player_healed", "target_player_id": pid, "source_instance_id": "heal_source", "amount": 5}])
	# End turn — should trigger the support's end_of_turn ability
	MatchTurnLoop.end_turn(match_state, pid)
	# Check that a Familiar was summoned in some lane
	var familiar_found := false
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(pid, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "familiar_token":
				familiar_found = true
	if not _assert(familiar_found, "Conjurer's Spirit: should summon a Familiar when health was gained this turn."):
		return false
	# Verify it does NOT fire when no health was gained
	var match_state2 := _build_started_match()
	var player2: Dictionary = match_state2["players"][0]
	var pid2 := str(player2["player_id"])
	var support2 := _add_hand_card(player2, "conjurers_spirit2", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "end_of_turn", "required_zone": "support", "required_gained_health_this_turn": true, "effects": [{"op": "summon_from_effect", "lane": "random", "card_template": {"definition_id": "familiar_token2", "name": "Familiar", "card_type": "creature", "attributes": ["willpower"], "cost": 2, "power": 2, "health": 2, "base_power": 2, "base_health": 2, "subtypes": [], "rules_text": ""}}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state2, pid2, str(support2["instance_id"]))
	# End turn WITHOUT healing — should not summon
	MatchTurnLoop.end_turn(match_state2, pid2)
	var familiar_found2 := false
	for lane in match_state2.get("lanes", []):
		for card in lane.get("player_slots", {}).get(pid2, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "familiar_token2":
				familiar_found2 = true
	return _assert(not familiar_found2, "Conjurer's Spirit: should NOT summon a Familiar when no health was gained.")


func _unrelenting_siege_support(pid: String) -> Dictionary:
	return ScenarioFixtures.make_card(pid, "aw_agi_unrelenting_siege", {
		"card_type": "support",
		"cost": 4,
		"support_uses": 0,
		"passive_abilities": [{"type": "grant_extra_attack", "condition": {"max_power": 1}}],
	})


func _test_unrelenting_siege_allows_1_power_creature_to_attack_twice() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var opp_id := str(opponent.get("player_id", ""))
	var siege := _unrelenting_siege_support(pid)
	siege["zone"] = "support"
	player["support"].append(siege)
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "tiny_fighter", "field", 1, 2)
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var first := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(first.get("is_valid", false)), "Unrelenting Siege: first attack should succeed."):
		return false
	var second := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(second.get("is_valid", false)), "Unrelenting Siege: 1-power creature should be allowed a second attack."):
		return false
	var third := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	return _assert(not bool(third.get("is_valid", false)), "Unrelenting Siege: 1-power creature should NOT be allowed a third attack (passive grants only one extra per turn).")


func _test_unrelenting_siege_blocks_2_power_creature_from_second_attack() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var opp_id := str(opponent.get("player_id", ""))
	var siege := _unrelenting_siege_support(pid)
	siege["zone"] = "support"
	player["support"].append(siege)
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "big_fighter", "field", 2, 4)
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var first := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(first.get("is_valid", false)), "Unrelenting Siege (2-power): first attack should succeed."):
		return false
	var second := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	return _assert(not bool(second.get("is_valid", false)), "Unrelenting Siege: 2-power creature should NOT be allowed a second attack.")


func _test_unrelenting_siege_allows_debuffed_creature_to_attack_twice() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var opp_id := str(opponent.get("player_id", ""))
	var siege := _unrelenting_siege_support(pid)
	siege["zone"] = "support"
	player["support"].append(siege)
	# 3-power creature debuffed down to 1 power
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "debuffed_fighter", "field", 3, 4)
	EvergreenRules.apply_stat_bonus(attacker, -2, 0)
	if not _assert(EvergreenRules.get_power(attacker) == 1, "Debuff should leave effective power at 1, got %d." % EvergreenRules.get_power(attacker)):
		return false
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	var first := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(first.get("is_valid", false)), "Unrelenting Siege (debuffed): first attack should succeed."):
		return false
	var second := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(second.get("is_valid", false)), "Unrelenting Siege: debuffed-to-1-power creature should be allowed a second attack."):
		return false
	var third := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	return _assert(not bool(third.get("is_valid", false)), "Unrelenting Siege: debuffed-to-1-power creature should NOT be allowed a third attack.")


func _test_zephyr_grants_wielder_extra_attack_each_turn() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var opp_id := str(opponent.get("player_id", ""))
	var wielder := ScenarioFixtures.summon_creature(player, match_state, "zephyr_wielder", "field", 3, 8)
	EvergreenRules.ensure_card_state(wielder)
	var zephyr := {
		"instance_id": "%s_zephyr" % pid,
		"definition_id": "dg_agi_zephyr",
		"name": "Zephyr",
		"card_type": "item",
		"owner_player_id": pid,
		"controller_player_id": pid,
		"zone": MatchMutations.ZONE_ATTACHED_ITEM,
		"attached_to_instance_id": str(wielder["instance_id"]),
		"equip_power_bonus": -1,
		"passive_abilities": [{"type": "grant_extra_attack", "target": "host"}],
	}
	wielder["attached_items"].append(zephyr)
	ScenarioFixtures.ready_for_attack(wielder, match_state)
	# Turn 1: wielder should be able to attack twice (base + Zephyr passive) but not three times
	var first := MatchCombat.resolve_attack(match_state, pid, str(wielder.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(first.get("is_valid", false)), "Zephyr: first attack should succeed."):
		return false
	var second := MatchCombat.resolve_attack(match_state, pid, str(wielder.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(second.get("is_valid", false)), "Zephyr: wielder should be allowed a second attack via item passive."):
		return false
	var third := MatchCombat.resolve_attack(match_state, pid, str(wielder.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(not bool(third.get("is_valid", false)), "Zephyr: wielder should NOT be allowed a third attack (passive grants only one extra per turn)."):
		return false
	# Advance two turns back to player 0; Zephyr's passive should refresh
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	var next_first := MatchCombat.resolve_attack(match_state, pid, str(wielder.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(next_first.get("is_valid", false)), "Zephyr: wielder should be able to attack on the next turn."):
		return false
	var next_second := MatchCombat.resolve_attack(match_state, pid, str(wielder.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	return _assert(bool(next_second.get("is_valid", false)), "Zephyr: passive should refresh each turn, allowing a second attack next turn.")


func _test_unrelenting_siege_passive_refreshes_each_turn() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var opponent: Dictionary = match_state["players"][1]
	var pid := str(player.get("player_id", ""))
	var opp_id := str(opponent.get("player_id", ""))
	var siege := _unrelenting_siege_support(pid)
	siege["zone"] = "support"
	player["support"].append(siege)
	var attacker := ScenarioFixtures.summon_creature(player, match_state, "tiny_fighter", "field", 1, 8)
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	# Turn 1: attack twice, third should fail
	MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	# End player 0's turn, then end player 1's turn → back to player 0
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	# Turn 2: should be able to attack twice again
	var first := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(first.get("is_valid", false)), "Unrelenting Siege: creature should be able to attack on next turn."):
		return false
	var second := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	if not _assert(bool(second.get("is_valid", false)), "Unrelenting Siege: passive should refresh next turn and allow a second attack."):
		return false
	var third := MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {"type": "player", "player_id": opp_id})
	return _assert(not bool(third.get("is_valid", false)), "Unrelenting Siege: third attack on refreshed turn should still be blocked.")


func _test_support_play_limit_blocks_second_card() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Place a support with play_limit_per_turn in the support zone
	player["support"].append({
		"instance_id": "p1_lichs_ascension",
		"definition_id": "hom_end_lichs_ascension",
		"name": "Lich's Ascension",
		"card_type": "support",
		"support_uses": 0,
		"play_limit_per_turn": 1,
		"owner_player_id": pid,
		"controller_player_id": pid,
		"zone": "support",
	})
	# Add two action cards to hand
	var action1 := _add_hand_card(player, "play_limit_action_1", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 0}]}],
	})
	var action2 := _add_hand_card(player, "play_limit_action_2", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 0}]}],
	})
	# First play should succeed
	var result1 := MatchTiming.play_action_from_hand(match_state, pid, str(action1["instance_id"]))
	if not _assert(bool(result1.get("is_valid", false)), "Play limit: first card should be playable."):
		return false
	# Second play should be blocked
	var result2 := MatchTiming.play_action_from_hand(match_state, pid, str(action2["instance_id"]))
	return _assert(not bool(result2.get("is_valid", false)), "Play limit: second card should be blocked by play_limit_per_turn=1.")


func _test_support_play_limit_from_hand_without_hydration() -> bool:
	# Regression: Lich's Ascension in support zone may lack play_limit_per_turn
	# if the card instance wasn't hydrated. The catalog fallback should still enforce it.
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Place Lich's Ascension directly in support WITHOUT play_limit_per_turn
	# (simulates missing hydration — only definition_id is set)
	player["support"].append({
		"instance_id": "p1_lichs_no_hydrate",
		"definition_id": "hom_end_lichs_ascension",
		"name": "Lich's Ascension",
		"card_type": "support",
		"support_uses": 0,
		"owner_player_id": pid,
		"controller_player_id": pid,
		"zone": "support",
	})
	var action1 := _add_hand_card(player, "play_limit_action_a", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 0}]}],
	})
	var action2 := _add_hand_card(player, "play_limit_action_b", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 0}]}],
	})
	# First action should succeed (catalog fallback finds play_limit_per_turn=1)
	var result1 := MatchTiming.play_action_from_hand(match_state, pid, str(action1["instance_id"]))
	if not _assert(bool(result1.get("is_valid", false)), "Catalog fallback: first card should be playable."):
		return false
	# Second action should be blocked by catalog fallback
	var result2 := MatchTiming.play_action_from_hand(match_state, pid, str(action2["instance_id"]))
	return _assert(not bool(result2.get("is_valid", false)), "Catalog fallback: second card should be blocked by play_limit_per_turn=1.")


func _test_support_play_limit_resets_on_placement() -> bool:
	# Playing a support with play_limit_per_turn resets the counter so the
	# limit only applies to cards played AFTER the support enters the board.
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	player["max_magicka"] = 50
	player["current_magicka"] = 50
	# Add Lich's Ascension + two actions to hand
	var support := _add_hand_card(player, "hom_end_lichs_ascension", {
		"card_type": "support",
		"cost": 7,
		"support_uses": 0,
		"play_limit_per_turn": 1,
	})
	var action1 := _add_hand_card(player, "post_lich_action_1", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 0}]}],
	})
	var action2 := _add_hand_card(player, "post_lich_action_2", {
		"card_type": "action",
		"cost": 0,
		"triggered_abilities": [{"family": "on_play", "effects": [{"op": "draw_cards", "target_player": "controller", "count": 0}]}],
	})
	# Play Lich's Ascension from hand
	var sr := PersistentCardRules.play_support_from_hand(match_state, pid, str(support["instance_id"]))
	if not _assert(bool(sr.get("is_valid", false)), "Lich placement: support should be playable."):
		return false
	# Counter should be reset — one more card is allowed this turn
	var r1 := MatchTiming.play_action_from_hand(match_state, pid, str(action1["instance_id"]))
	if not _assert(bool(r1.get("is_valid", false)), "Lich placement: first action AFTER support should succeed."):
		return false
	# Second action should be blocked
	var r2 := MatchTiming.play_action_from_hand(match_state, pid, str(action2["instance_id"]))
	return _assert(not bool(r2.get("is_valid", false)), "Lich placement: second action should be blocked.")


func _test_skooma_cats_whimsy_discounts_generated_cards() -> bool:
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var pid := str(player.get("player_id", ""))
	# Place Skooma Cat's Whimsy as a support
	var whimsy := ScenarioFixtures.make_card(pid, "skooma_cats_whimsy", {
		"card_type": "support",
		"cost": 1,
		"support_uses": 0,
		"cost_reduction_aura": {"scope": "hand", "target": "all_friendly", "amount": 1, "filter_not_in_starting_deck": true},
	})
	whimsy["zone"] = "support"
	player["support"].append(whimsy)
	# Generate a card to hand via build_generated_card (simulates generate_random_to_hand)
	var template := {"definition_id": "gen_action", "name": "Generated Action", "card_type": "action", "cost": 5}
	var generated := MatchMutations.build_generated_card(match_state, pid, template)
	generated["zone"] = MatchMutations.ZONE_HAND
	player["hand"].append(generated)
	var gen_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, generated)
	# A normal hand card that was in the starting deck should NOT be discounted
	var normal := _add_hand_card(player, "normal_card", {"card_type": "action", "cost": 5})
	var normal_cost := PersistentCardRules.get_effective_play_cost(match_state, pid, normal)
	return (
		_assert(gen_cost == 4, "Skooma Cat's Whimsy should discount generated card from 5 to 4, got %d." % gen_cost) and
		_assert(normal_cost == 5, "Skooma Cat's Whimsy should NOT discount starting-deck card, expected 5 got %d." % normal_cost)
	)


func _test_imperial_might_summons_grunt_at_end_of_turn() -> bool:
	var match_state := _build_started_match()
	ScenarioFixtures.set_rng_seed(match_state, 99)
	var player: Dictionary = match_state["players"][0]
	var pid := str(player["player_id"])
	# Place Imperial Might in the support zone using its real catalog definition
	var support := _add_hand_card(player, "wil_imperial_might", {
		"card_type": "support",
		"cost": 0,
		"support_uses": 0,
		"triggered_abilities": [{"family": "end_of_turn", "required_zone": "support", "effects": [{"op": "summon_from_effect", "lane_id": "random", "card_template": {"definition_id": "wil_imperial_grunt", "name": "Imperial Grunt", "card_type": "creature", "attributes": ["willpower"], "cost": 0, "power": 1, "health": 1, "base_power": 1, "base_health": 1, "subtypes": ["Imperial"], "rules_text": ""}}]}],
	})
	PersistentCardRules.play_support_from_hand(match_state, pid, str(support["instance_id"]))
	# End the turn — should trigger end_of_turn and summon a grunt
	_end_turn_and_start_next(match_state)
	var grunt_found := false
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(pid, []):
			if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "wil_imperial_grunt":
				grunt_found = true
	return _assert(grunt_found, "Imperial Might should summon an Imperial Grunt at the end of the controller's turn.")


func _test_spider_lair_only_summons_configured_spider_ids() -> bool:
	var allowed_ids := ["agi_poisonous_spider", "agi_protective_spider", "agi_cavern_spinner"]
	var match_state := _build_started_match()
	var player: Dictionary = match_state["players"][0]
	var support := _add_hand_card(player, "agi_spider_lair", {
		"card_type": "support",
		"cost": 7,
		"triggered_abilities": [{
			"family": MatchTiming.FAMILY_START_OF_TURN,
			"required_zone": "support",
			"effects": [{"op": "summon_random_from_catalog", "target_lane": "random", "filter": {"card_ids": allowed_ids}}],
		}],
	})
	var play_result := PersistentCardRules.play_support_from_hand(match_state, player["player_id"], support["instance_id"])
	if not _assert(play_result["is_valid"], "Spider Lair should enter support zone."):
		return false
	MatchTurnLoop.end_turn(match_state, player["player_id"])
	MatchTurnLoop.end_turn(match_state, match_state["active_player_id"])
	var found_ids: Array = []
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player["player_id"], []):
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var def_id := str(card.get("definition_id", ""))
			if allowed_ids.has(def_id) or def_id.ends_with("_spider") or str(card.get("name", "")).find("Spider") != -1 or str(card.get("name", "")).find("Spinner") != -1:
				found_ids.append(def_id)
	if not _assert(found_ids.size() >= 1, "Spider Lair should summon at least one spider after a full round. Found none."):
		return false
	for def_id in found_ids:
		if not _assert(allowed_ids.has(def_id), "Spider Lair summoned '%s' — only %s allowed." % [def_id, str(allowed_ids)]):
			return false
	return true


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false