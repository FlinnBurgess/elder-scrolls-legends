extends SceneTree

## Card tests: Turn-based triggers (start/end of turn effects)
## Tests real catalog card definitions against their rules text.

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const LaneRules = preload("res://src/core/match/lane_rules.gd")
const MatchCombat = preload("res://src/core/match/match_combat.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTiming = preload("res://src/core/match/match_timing.gd")
const MatchTurnLoop = preload("res://src/core/match/match_turn_loop.gd")
const PersistentCardRules = preload("res://src/core/match/persistent_card_rules.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")
const CatalogTestHelper = preload("res://tests/support/catalog_test_helper.gd")


var _catalog_helper: RefCounted


func _initialize() -> void:
	_catalog_helper = CatalogTestHelper.new()
	if not _catalog_helper.load_catalog():
		push_error("Failed to load card catalog")
		quit(1)
		return
	if not _run_all_tests():
		quit(1)
		return
	print("CARD_TESTS_TURN_TRIGGERS_OK")
	quit(0)


func _run_all_tests() -> bool:
	return (
		# Dragonfire Wizard (188)
		_test_dragonfire_wizard_gains_flame_each_turn() and
		_test_dragonfire_wizard_last_gasp_flame_lash_scales() and
		_test_dragonfire_wizard_no_flames_if_not_in_lane() and
		# Apex Predator (170)
		_test_apex_predator_moves_when_no_enemies() and
		_test_apex_predator_stays_when_enemies_present() and
		_test_apex_predator_move_deals_damage_and_heals() and
		# Gravesinger (161)
		_test_gravesinger_summons_highest_cost_from_discard() and
		_test_gravesinger_summoned_creature_has_charge() and
		_test_gravesinger_summoned_creature_returns_to_deck() and
		_test_gravesinger_no_creatures_in_discard() and
		# Flamespear Dragon (160)
		_test_flamespear_dragon_aims_at_enemy_summon() and
		_test_flamespear_dragon_deals_damage_to_aimed_creature() and
		_test_flamespear_dragon_retargets_on_new_summon() and
		# Alduin (161) — start of turn portion
		_test_alduin_summon_destroys_all_other_creatures() and
		_test_alduin_start_of_turn_summons_dragon_from_discard() and
		_test_alduin_cost_reduction_per_dragon_in_discard() and
		# The End of Vampires — per_opponent_undead cost reduction
		_test_end_of_vampires_counts_opponent_discard_undead() and
		# Disciple of Namira (518)
		_test_disciple_of_namira_draws_per_friendly_death() and
		_test_disciple_of_namira_no_draw_for_enemy_death() and
		# Tenarr Zalviit Nightstalker — consume_or_sacrifice
		_test_tenarr_sacrifices_with_empty_discard() and
		_test_tenarr_consumes_with_creature_in_discard() and
		_test_tenarr_survives_after_consuming() and
		# Studious Greybeard — deferred draw
		_test_studious_greybeard_defers_draw_until_choice_resolved() and
		_test_studious_greybeard_discard_draws_next_card() and
		# Scout's Report — on_play choice + follow-up draw
		_test_scouts_report_creates_choice_and_draws_on_keep() and
		_test_scouts_report_discard_then_draws_next_card() and
		# Giant Slaughterfish — all_friendly_animals includes Fish subtype
		_test_giant_slaughterfish_buffs_itself() and
		true
	)


# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────

func _build_started_match() -> Dictionary:
	return ScenarioFixtures.create_started_match({"set_all_magicka": 20, "first_player_index": 0})


func _assert(condition: bool, message: String) -> bool:
	if not condition:
		push_error("ASSERTION FAILED: %s" % message)
	return condition


func _find_lane_card(match_state: Dictionary, lane_id: String, player_id: String, definition_id: String) -> Dictionary:
	return ScenarioFixtures.find_lane_card(match_state, lane_id, player_id, definition_id)


func _lane_creatures(match_state: Dictionary, lane_id: String, player_id: String) -> Array:
	var result: Array = []
	for lane in match_state.get("lanes", []):
		if str(lane.get("lane_id", "")) != lane_id:
			continue
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				result.append(card)
	return result


func _all_lane_creatures(match_state: Dictionary, player_id: String) -> Array:
	var result: Array = []
	for lane in match_state.get("lanes", []):
		for card in lane.get("player_slots", {}).get(player_id, []):
			if typeof(card) == TYPE_DICTIONARY:
				result.append(card)
	return result


func _end_turn_and_start_next(match_state: Dictionary) -> void:
	var active_pid := str(match_state.get("active_player_id", ""))
	MatchTurnLoop.end_turn(match_state, active_pid)


func _get_counter(card: Dictionary, counter_name: String) -> int:
	return int(card.get("_counter_" + counter_name, 0))


# ──────────────────────────────────────────────────────────────────────
# Dragonfire Wizard — "At the end of your turn, add a flame to
# Dragonfire Wizard. Last Gasp: Put a Flame Lash into your hand that
# deals damage and gains health equal to the number of flames."
# ──────────────────────────────────────────────────────────────────────

func _test_dragonfire_wizard_gains_flame_each_turn() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var wizard: Dictionary = _catalog_helper.summon(player, match_state, "mc_dual_dragonfire_wizard", "field")
	if wizard.is_empty():
		return _assert(false, "Failed to summon Dragonfire Wizard")
	# End turn — should gain 1 flame
	_end_turn_and_start_next(match_state)
	var flames: int = _get_counter(wizard, "flame")
	if not _assert(flames == 1, "Dragonfire Wizard should have 1 flame after first end of turn, got %d" % flames):
		return false
	# End opponent turn, then our turn starts and ends
	_end_turn_and_start_next(match_state)  # opponent's turn ends, our turn starts
	_end_turn_and_start_next(match_state)  # our turn ends
	flames = _get_counter(wizard, "flame")
	return _assert(flames == 2, "Dragonfire Wizard should have 2 flames after second end of turn, got %d" % flames)


func _test_dragonfire_wizard_last_gasp_flame_lash_scales() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var opid := str(opponent.get("player_id", ""))
	var wizard: Dictionary = _catalog_helper.summon(player, match_state, "mc_dual_dragonfire_wizard", "field")
	if wizard.is_empty():
		return _assert(false, "Failed to summon Dragonfire Wizard")
	# Accumulate 3 flames by cycling through 3 of our end-of-turns
	for i in range(3):
		_end_turn_and_start_next(match_state)  # our turn ends
		_end_turn_and_start_next(match_state)  # opponent turn ends, our turn starts
	# Should have 3 flames now
	var flames := _get_counter(wizard, "flame")
	if not _assert(flames == 3, "Expected 3 flames, got %d" % flames):
		return false
	# Kill wizard via combat: summon a big enemy on opponent's turn and attack
	_end_turn_and_start_next(match_state)  # our turn ends, opponent's turn starts
	var killer := ScenarioFixtures.summon_creature(opponent, match_state, "killer", "field", 20, 20, [], -1, {"cost": 0})
	if killer.is_empty():
		return _assert(false, "Failed to summon killer creature")
	ScenarioFixtures.ready_for_attack(killer, match_state)
	var hand_before: int = player.get("hand", []).size()
	MatchCombat.resolve_attack(match_state, opid, str(killer.get("instance_id", "")), {
		"type": "creature", "instance_id": str(wizard.get("instance_id", "")),
	})
	var hand_after: int = player.get("hand", []).size()
	if not _assert(hand_after > hand_before, "Last Gasp should put Flame Lash into hand"):
		return false
	# Find the Flame Lash in hand
	var flame_lash: Dictionary = {}
	for card in player.get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("name", "")).find("Flame Lash") >= 0:
			flame_lash = card
			break
	if not _assert(not flame_lash.is_empty(), "Should find Flame Lash in hand"):
		return false
	# The Flame Lash should have the flame counter copied from the wizard
	# (3 from our turns + 1 from the extra end-of-turn before combat = 4)
	var lash_flame_count: int = int(flame_lash.get("_counter_flame", 0))
	if not _assert(lash_flame_count >= 3, "Flame Lash should carry flame counter >= 3, got %d" % lash_flame_count):
		return false
	# Verify the effect uses amount_source referencing the counter (not a static amount)
	var lash_abilities: Array = flame_lash.get("triggered_abilities", [])
	var uses_counter_source := false
	for ability in lash_abilities:
		for eff in ability.get("effects", []):
			if str(eff.get("amount_source", "")).find("flame") >= 0:
				uses_counter_source = true
	if not _assert(uses_counter_source, "Flame Lash effect should reference flame counter as amount_source"):
		return false
	# Verify rules_text was updated to reflect the actual counter value
	var lash_rules := str(flame_lash.get("rules_text", ""))
	var expected_dmg_str := "%d damage" % lash_flame_count
	return _assert(lash_rules.find(expected_dmg_str) >= 0, "Flame Lash rules_text should contain '%s', got '%s'" % [expected_dmg_str, lash_rules])


func _test_dragonfire_wizard_no_flames_if_not_in_lane() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	# Add to hand but don't play
	var wizard: Dictionary = _catalog_helper.add_to_hand(player, "mc_dual_dragonfire_wizard")
	if wizard.is_empty():
		return _assert(false, "Failed to add Dragonfire Wizard to hand")
	_end_turn_and_start_next(match_state)
	var flames := _get_counter(wizard, "flame")
	return _assert(flames == 0, "Dragonfire Wizard in hand should not gain flames, got %d" % flames)


# ──────────────────────────────────────────────────────────────────────
# Apex Predator — "When Apex Predator moves, deal 2 damage to your
# opponent and you gain 2 health. At the end of your turn, if there
# are no enemy creatures in this lane, move Apex Predator."
# ──────────────────────────────────────────────────────────────────────

func _test_apex_predator_moves_when_no_enemies() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var predator: Dictionary = _catalog_helper.summon(player, match_state, "moe_agi_apex_predator", "field")
	if predator.is_empty():
		return _assert(false, "Failed to summon Apex Predator")
	# No enemies in field lane — end turn should move to shadow
	_end_turn_and_start_next(match_state)
	var in_shadow := not _find_lane_card(match_state, "shadow", pid, "moe_agi_apex_predator").is_empty()
	var in_field := not _find_lane_card(match_state, "field", pid, "moe_agi_apex_predator").is_empty()
	return (
		_assert(in_shadow, "Apex Predator should have moved to shadow lane") and
		_assert(not in_field, "Apex Predator should no longer be in field lane")
	)


func _test_apex_predator_stays_when_enemies_present() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var predator: Dictionary = _catalog_helper.summon(player, match_state, "moe_agi_apex_predator", "field")
	if predator.is_empty():
		return _assert(false, "Failed to summon Apex Predator")
	# Place enemy creature in field lane
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "blocker", "field", 2, 2)
	if enemy.is_empty():
		return _assert(false, "Failed to summon enemy blocker")
	_end_turn_and_start_next(match_state)
	var still_in_field := not _find_lane_card(match_state, "field", pid, "moe_agi_apex_predator").is_empty()
	return _assert(still_in_field, "Apex Predator should stay in field lane when enemies are present")


func _test_apex_predator_move_deals_damage_and_heals() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	player["health"] = 25
	opponent["health"] = 30
	var predator: Dictionary = _catalog_helper.summon(player, match_state, "moe_agi_apex_predator", "field")
	if predator.is_empty():
		return _assert(false, "Failed to summon Apex Predator")
	# End turn — should move (no enemies) and trigger on_move
	_end_turn_and_start_next(match_state)
	return (
		_assert(int(opponent.get("health", 0)) == 28, "Opponent should take 2 damage from move, got %d" % int(opponent.get("health", 0))) and
		_assert(int(player.get("health", 0)) == 27, "Player should gain 2 health from move, got %d" % int(player.get("health", 0)))
	)


# ──────────────────────────────────────────────────────────────────────
# Gravesinger — "At the start of your turn, summon the highest cost
# creature from your discard pile and give it Charge. At the end of
# the turn, put it on the bottom of your deck."
# ──────────────────────────────────────────────────────────────────────

func _test_gravesinger_summons_highest_cost_from_discard() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var gravesinger: Dictionary = _catalog_helper.summon(player, match_state, "db_end_gravesinger", "field")
	if gravesinger.is_empty():
		return _assert(false, "Failed to summon Gravesinger")
	# Put creatures in discard — a 3-cost and a 7-cost
	var cheap := ScenarioFixtures.make_card(pid, "cheap_creature", {
		"definition_id": "test_cheap", "card_type": "creature", "cost": 3,
		"power": 2, "health": 2, "name": "Cheap Creature",
	})
	cheap["zone"] = "discard"
	player["discard"].append(cheap)
	var expensive := ScenarioFixtures.make_card(pid, "expensive_creature", {
		"definition_id": "test_expensive", "card_type": "creature", "cost": 7,
		"power": 5, "health": 5, "name": "Expensive Creature",
	})
	expensive["zone"] = "discard"
	player["discard"].append(expensive)
	# End turn, opponent turn, then start of our turn triggers Gravesinger
	_end_turn_and_start_next(match_state)  # our turn ends
	_end_turn_and_start_next(match_state)  # opponent turn ends, our turn starts
	# The expensive creature should be summoned in the same lane
	var summoned := _find_lane_card(match_state, "field", pid, "test_expensive")
	return _assert(not summoned.is_empty(), "Gravesinger should summon the highest-cost creature (7-cost) from discard")


func _test_gravesinger_summoned_creature_has_charge() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var gravesinger: Dictionary = _catalog_helper.summon(player, match_state, "db_end_gravesinger", "field")
	if gravesinger.is_empty():
		return _assert(false, "Failed to summon Gravesinger")
	var target := ScenarioFixtures.make_card(pid, "reanimate_target", {
		"definition_id": "test_reanimate", "card_type": "creature", "cost": 5,
		"power": 4, "health": 4, "name": "Reanimate Target",
	})
	target["zone"] = "discard"
	player["discard"].append(target)
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	var summoned := _find_lane_card(match_state, "field", pid, "test_reanimate")
	if summoned.is_empty():
		return _assert(false, "Target should be summoned")
	var keywords: Array = summoned.get("keywords", [])
	var granted: Array = summoned.get("granted_keywords", [])
	var has_charge := keywords.has("charge") or granted.has("charge")
	return _assert(has_charge, "Gravesinger's summoned creature should have Charge")


func _test_gravesinger_summoned_creature_returns_to_deck() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var gravesinger: Dictionary = _catalog_helper.summon(player, match_state, "db_end_gravesinger", "field")
	if gravesinger.is_empty():
		return _assert(false, "Failed to summon Gravesinger")
	var target := ScenarioFixtures.make_card(pid, "return_target", {
		"definition_id": "test_return_target", "card_type": "creature", "cost": 5,
		"power": 4, "health": 4, "name": "Return Target",
	})
	target["zone"] = "discard"
	player["discard"].append(target)
	# Cycle: our turn ends → opponent starts/ends → our turn starts (Gravesinger triggers)
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	# Creature should be on board now
	var summoned := _find_lane_card(match_state, "field", pid, "test_return_target")
	if summoned.is_empty():
		return _assert(false, "Target should be summoned at start of turn")
	# Now end our turn — creature should return to bottom of deck
	_end_turn_and_start_next(match_state)
	var still_in_field := not _find_lane_card(match_state, "field", pid, "test_return_target").is_empty()
	var still_in_shadow := not _find_lane_card(match_state, "shadow", pid, "test_return_target").is_empty()
	var in_deck := false
	for card in player.get("deck", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("definition_id", "")) == "test_return_target":
			in_deck = true
			break
	return (
		_assert(not still_in_field and not still_in_shadow, "Summoned creature should leave the lane at end of turn (field=%s,shadow=%s)" % [str(still_in_field), str(still_in_shadow)]) and
		_assert(in_deck, "Summoned creature should be put on the bottom of the deck")
	)


func _test_gravesinger_no_creatures_in_discard() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var gravesinger: Dictionary = _catalog_helper.summon(player, match_state, "db_end_gravesinger", "field")
	if gravesinger.is_empty():
		return _assert(false, "Failed to summon Gravesinger")
	# Empty discard — no creatures
	player["discard"] = []
	var creatures_before := _all_lane_creatures(match_state, pid).size()
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	var creatures_after := _all_lane_creatures(match_state, pid).size()
	return _assert(creatures_after == creatures_before, "No creatures should be summoned when discard is empty, before=%d after=%d" % [creatures_before, creatures_after])


# ──────────────────────────────────────────────────────────────────────
# Flamespear Dragon — "When your opponent summons a creature, Flamespear
# Dragon aims at it. At the start of your turn, Flamespear Dragon deals
# 1 damage to the creature it's aiming at."
# ──────────────────────────────────────────────────────────────────────

func _test_flamespear_dragon_aims_at_enemy_summon() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var opid := str(opponent.get("player_id", ""))
	var dragon: Dictionary = _catalog_helper.summon(player, match_state, "moe_str_flamespear_dragon", "field")
	if dragon.is_empty():
		return _assert(false, "Failed to summon Flamespear Dragon")
	# Switch to opponent's turn
	_end_turn_and_start_next(match_state)
	# Opponent summons a creature
	var target := ScenarioFixtures.summon_creature(opponent, match_state, "opp_creature", "field", 3, 3)
	if target.is_empty():
		return _assert(false, "Failed to summon opponent creature")
	var aimed_at := str(dragon.get("_aimed_at_instance_id", ""))
	var target_id := str(target.get("instance_id", ""))
	return _assert(aimed_at == target_id, "Flamespear Dragon should aim at the opponent's summoned creature")


func _test_flamespear_dragon_deals_damage_to_aimed_creature() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var dragon: Dictionary = _catalog_helper.summon(player, match_state, "moe_str_flamespear_dragon", "field")
	if dragon.is_empty():
		return _assert(false, "Failed to summon Flamespear Dragon")
	# End our turn → opponent's turn
	_end_turn_and_start_next(match_state)
	# Opponent summons creature
	var target := ScenarioFixtures.summon_creature(opponent, match_state, "aim_target", "field", 3, 5)
	if target.is_empty():
		return _assert(false, "Failed to summon opponent creature")
	# End opponent's turn → our turn starts → start_of_turn fires
	_end_turn_and_start_next(match_state)
	var damage := int(target.get("damage_marked", 0))
	return _assert(damage >= 1, "Flamespear Dragon should deal 1 damage to aimed creature at start of turn, got %d" % damage)


func _test_flamespear_dragon_retargets_on_new_summon() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var dragon: Dictionary = _catalog_helper.summon(player, match_state, "moe_str_flamespear_dragon", "field")
	if dragon.is_empty():
		return _assert(false, "Failed to summon Flamespear Dragon")
	_end_turn_and_start_next(match_state)  # opponent's turn
	# First summon
	var first := ScenarioFixtures.summon_creature(opponent, match_state, "first_target", "field", 2, 2)
	# Second summon — should retarget
	var second := ScenarioFixtures.summon_creature(opponent, match_state, "second_target", "shadow", 3, 3)
	if second.is_empty():
		return _assert(false, "Failed to summon second creature")
	var aimed_at := str(dragon.get("_aimed_at_instance_id", ""))
	var second_id := str(second.get("instance_id", ""))
	return _assert(aimed_at == second_id, "Flamespear Dragon should retarget to most recently summoned enemy creature")


# ──────────────────────────────────────────────────────────────────────
# Alduin — "Costs 2 less for each Dragon in your discard pile. Summon:
# Destroy all other creatures. At the start of your turn, summon a
# random Dragon from your discard pile."
# ──────────────────────────────────────────────────────────────────────

func _test_alduin_summon_destroys_all_other_creatures() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var opid := str(opponent.get("player_id", ""))
	# Place creatures for both players
	var friendly := ScenarioFixtures.summon_creature(player, match_state, "friendly", "field", 3, 3)
	var enemy := ScenarioFixtures.summon_creature(opponent, match_state, "enemy", "shadow", 4, 4)
	if friendly.is_empty() or enemy.is_empty():
		return _assert(false, "Failed to set up board")
	# Summon Alduin
	var alduin: Dictionary = _catalog_helper.summon(player, match_state, "hos_neu_alduin", "field", {"cost": 0})
	if alduin.is_empty():
		return _assert(false, "Failed to summon Alduin")
	# All other creatures should be destroyed
	var friendly_in_lane := _find_lane_card(match_state, "field", pid, "test_friendly")
	var enemy_in_lane := _find_lane_card(match_state, "shadow", opid, "test_enemy")
	return (
		_assert(friendly_in_lane.is_empty(), "Alduin should destroy friendly creatures") and
		_assert(enemy_in_lane.is_empty(), "Alduin should destroy enemy creatures") and
		_assert(not _find_lane_card(match_state, "field", pid, "hos_neu_alduin").is_empty(), "Alduin should survive its own summon effect")
	)


func _test_alduin_start_of_turn_summons_dragon_from_discard() -> bool:
	var match_state := _build_started_match()
	ScenarioFixtures.set_rng_seed(match_state, 42)
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var alduin: Dictionary = _catalog_helper.summon(player, match_state, "hos_neu_alduin", "field", {"cost": 0})
	if alduin.is_empty():
		return _assert(false, "Failed to summon Alduin")
	# Put a Dragon and a non-Dragon in discard
	var dragon_card := ScenarioFixtures.make_card(pid, "discard_dragon", {
		"definition_id": "test_dragon", "card_type": "creature", "cost": 5,
		"power": 5, "health": 5, "subtypes": ["Dragon"], "name": "Test Dragon",
	})
	dragon_card["zone"] = "discard"
	player["discard"].append(dragon_card)
	var non_dragon := ScenarioFixtures.make_card(pid, "discard_non_dragon", {
		"definition_id": "test_goblin", "card_type": "creature", "cost": 3,
		"power": 2, "health": 2, "subtypes": ["Goblin"], "name": "Test Goblin",
	})
	non_dragon["zone"] = "discard"
	player["discard"].append(non_dragon)
	# Cycle turns to get to our start of turn
	_end_turn_and_start_next(match_state)  # our turn ends
	_end_turn_and_start_next(match_state)  # opponent turn ends, our turn starts
	# Should summon the Dragon, not the Goblin
	var dragon_in_lane := _find_lane_card(match_state, "field", pid, "test_dragon")
	var goblin_in_lane := _find_lane_card(match_state, "field", pid, "test_goblin")
	return (
		_assert(not dragon_in_lane.is_empty(), "Alduin should summon a Dragon from discard at start of turn") and
		_assert(goblin_in_lane.is_empty(), "Alduin should NOT summon non-Dragon creatures from discard")
	)


func _test_alduin_cost_reduction_per_dragon_in_discard() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	# Add Alduin to hand (don't summon — check cost)
	var alduin: Dictionary = _catalog_helper.add_to_hand(player, "hos_neu_alduin")
	if alduin.is_empty():
		return _assert(false, "Failed to add Alduin to hand")
	var base_cost: int = int(alduin.get("cost", 0))
	if not _assert(base_cost == 20, "Alduin base cost should be 20, got %d" % base_cost):
		return false
	# Put 3 Dragons in discard
	for i in range(3):
		var dragon := ScenarioFixtures.make_card(pid, "dragon_%d" % i, {
			"definition_id": "test_dragon_%d" % i, "card_type": "creature",
			"cost": 5, "power": 3, "health": 3, "subtypes": ["Dragon"],
		})
		dragon["zone"] = "discard"
		player["discard"].append(dragon)
	# Check effective cost — should be 20 - (3 * 2) = 14
	var effective_cost: int = PersistentCardRules.get_effective_play_cost(match_state, pid, alduin)
	return _assert(effective_cost == 14, "Alduin with 3 Dragons in discard should cost 14, got %d" % effective_cost)


# ──────────────────────────────────────────────────────────────────────
# The End of Vampires — "Cost 1 less for each undead creature in your
# opponent's lanes and discard pile. Banish a creature."
# ──────────────────────────────────────────────────────────────────────

func _test_end_of_vampires_counts_opponent_discard_undead() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var opponent := ScenarioFixtures.player(match_state, 1)
	var pid := str(player.get("player_id", ""))
	var oid := str(opponent.get("player_id", ""))
	# Add The End of Vampires to hand
	var eov: Dictionary = _catalog_helper.add_to_hand(player, "dg_wil_the_end_of_vampires")
	if eov.is_empty():
		return _assert(false, "Failed to add The End of Vampires to hand")
	var base_cost: int = int(eov.get("cost", 0))
	if not _assert(base_cost == 7, "Base cost should be 7, got %d" % base_cost):
		return false
	# Put a Vampire in opponent's lane
	ScenarioFixtures.summon_creature(opponent, match_state, "opp_vamp", "field", 3, 3, [], -1, {
		"cost": 3, "subtypes": ["Vampire"],
	})
	# Put a Skeleton in opponent's discard
	var skeleton := ScenarioFixtures.make_card(oid, "opp_skel", {
		"definition_id": "test_skeleton", "card_type": "creature",
		"cost": 1, "power": 1, "health": 1, "subtypes": ["Skeleton"],
	})
	skeleton["zone"] = "discard"
	opponent["discard"].append(skeleton)
	# Effective cost should be 7 - 2 = 5 (1 in lane + 1 in discard)
	var effective_cost: int = PersistentCardRules.get_effective_play_cost(match_state, pid, eov)
	return _assert(effective_cost == 5, "End of Vampires with 1 Vampire in lane + 1 Skeleton in discard should cost 5, got %d" % effective_cost)


# ──────────────────────────────────────────────────────────────────────
# Disciple of Namira — "At the end of each turn, draw a card for each
# friendly creature that died in Disciple of Namira's lane."
# ──────────────────────────────────────────────────────────────────────

func _test_disciple_of_namira_draws_per_friendly_death() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var opponent := ScenarioFixtures.player(match_state, 1)
	var opid := str(opponent.get("player_id", ""))
	# Summon Disciple of Namira in field lane
	var disciple: Dictionary = _catalog_helper.summon(player, match_state, "end_disciple_of_namira", "field")
	if disciple.is_empty():
		return _assert(false, "Failed to summon Disciple of Namira")
	# Summon 3 weak friendly creatures in the same lane
	var weak1: Dictionary = ScenarioFixtures.summon_creature(player, match_state, "weak1", "field", 1, 1, [], -1, {"cost": 0})
	var weak2: Dictionary = ScenarioFixtures.summon_creature(player, match_state, "weak2", "field", 1, 1, [], -1, {"cost": 0})
	var weak3: Dictionary = ScenarioFixtures.summon_creature(player, match_state, "weak3", "field", 1, 1, [], -1, {"cost": 0})
	# Summon a big enemy in the same lane
	var big_enemy: Dictionary = ScenarioFixtures.summon_creature(opponent, match_state, "big_enemy", "field", 20, 20, [], -1, {"cost": 0})
	# Make friendly creatures attack-ready
	ScenarioFixtures.ready_for_attack(weak1, match_state)
	ScenarioFixtures.ready_for_attack(weak2, match_state)
	ScenarioFixtures.ready_for_attack(weak3, match_state)
	# Ensure deck has enough cards to draw
	for i in range(5):
		var filler := ScenarioFixtures.make_card(pid, "filler_%d" % i, {
			"definition_id": "test_filler_%d" % i, "card_type": "creature",
			"cost": 1, "power": 1, "health": 1, "name": "Filler %d" % i,
		})
		filler["zone"] = "deck"
		player["deck"].append(filler)
	# Attack with each weak creature into the big enemy — all 3 die
	MatchCombat.resolve_attack(match_state, pid, str(weak1.get("instance_id", "")), {
		"type": "creature", "instance_id": str(big_enemy.get("instance_id", "")),
	})
	MatchCombat.resolve_attack(match_state, pid, str(weak2.get("instance_id", "")), {
		"type": "creature", "instance_id": str(big_enemy.get("instance_id", "")),
	})
	MatchCombat.resolve_attack(match_state, pid, str(weak3.get("instance_id", "")), {
		"type": "creature", "instance_id": str(big_enemy.get("instance_id", "")),
	})
	# Record hand size before end of turn
	var hand_before: int = player.get("hand", []).size()
	# End turn — Disciple should draw 3 cards (one per friendly death in lane)
	_end_turn_and_start_next(match_state)
	var hand_after: int = player.get("hand", []).size()
	var drawn: int = hand_after - hand_before
	return _assert(drawn == 3, "Disciple of Namira should draw 3 cards for 3 friendly deaths, drew %d" % drawn)


func _test_disciple_of_namira_no_draw_for_enemy_death() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var opponent := ScenarioFixtures.player(match_state, 1)
	var opid := str(opponent.get("player_id", ""))
	# Summon Disciple of Namira in field lane
	var disciple: Dictionary = _catalog_helper.summon(player, match_state, "end_disciple_of_namira", "field")
	if disciple.is_empty():
		return _assert(false, "Failed to summon Disciple of Namira")
	# Summon a strong friendly creature to kill enemy with
	var attacker: Dictionary = ScenarioFixtures.summon_creature(player, match_state, "attacker", "field", 20, 20, [], -1, {"cost": 0})
	# Summon 2 weak enemies in the same lane
	var enemy1: Dictionary = ScenarioFixtures.summon_creature(opponent, match_state, "enemy1", "field", 1, 1, [], -1, {"cost": 0})
	var enemy2: Dictionary = ScenarioFixtures.summon_creature(opponent, match_state, "enemy2", "field", 1, 1, [], -1, {"cost": 0})
	# Make attacker ready
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	# Kill both enemies
	MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {
		"type": "creature", "instance_id": str(enemy1.get("instance_id", "")),
	})
	ScenarioFixtures.ready_for_attack(attacker, match_state)
	MatchCombat.resolve_attack(match_state, pid, str(attacker.get("instance_id", "")), {
		"type": "creature", "instance_id": str(enemy2.get("instance_id", "")),
	})
	# Record hand size before end of turn
	var hand_before: int = player.get("hand", []).size()
	# End turn — should NOT draw (only enemy creatures died)
	_end_turn_and_start_next(match_state)
	var hand_after: int = player.get("hand", []).size()
	var drawn: int = hand_after - hand_before
	return _assert(drawn == 0, "Disciple of Namira should not draw for enemy deaths, drew %d" % drawn)


# ──────────────────────────────────────────────────���───────────────────
# Tenarr Zalviit Nightstalker — "At the start of your turn, Consume
# a creature. If you can't, sacrifice Tenarr Zalviit Nightstalker."
# ──────────────────────────────────────────────────────────────────────

func _test_tenarr_sacrifices_with_empty_discard() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var tenarr: Dictionary = _catalog_helper.summon(player, match_state, "moe_agi_tenarr_zalviit_nightstalker", "field")
	if tenarr.is_empty():
		return _assert(false, "Failed to summon Tenarr Zalviit Nightstalker")
	var instance_id := str(tenarr.get("instance_id", ""))
	# Discard is empty — next turn should sacrifice Tenarr
	_end_turn_and_start_next(match_state)  # our turn ends
	_end_turn_and_start_next(match_state)  # opponent turn ends, our turn starts
	var still_in_lane := _find_lane_card(match_state, "field", pid, "moe_agi_tenarr_zalviit_nightstalker")
	return _assert(still_in_lane.is_empty(), "Tenarr should be sacrificed when discard is empty")


func _test_tenarr_consumes_with_creature_in_discard() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var tenarr: Dictionary = _catalog_helper.summon(player, match_state, "moe_agi_tenarr_zalviit_nightstalker", "field")
	if tenarr.is_empty():
		return _assert(false, "Failed to summon Tenarr Zalviit Nightstalker")
	# Put a creature in discard
	var fodder := ScenarioFixtures.make_card(pid, "fodder_creature", {
		"definition_id": "test_fodder", "card_type": "creature", "cost": 1,
		"power": 1, "health": 1, "name": "Fodder Creature",
	})
	fodder["zone"] = "discard"
	player["discard"].append(fodder)
	# Advance to our next turn — triggers consume_or_sacrifice
	_end_turn_and_start_next(match_state)  # our turn ends
	_end_turn_and_start_next(match_state)  # opponent turn ends, our turn starts
	# Pending consume selection should exist
	var has_pending := MatchTiming.has_pending_consume_selection(match_state, pid)
	if not has_pending:
		return _assert(false, "Should have pending consume selection when creature is in discard")
	# Resolve the consume
	var consume_result := MatchTiming.resolve_consume_selection(match_state, pid, str(fodder.get("instance_id", "")))
	if not bool(consume_result.get("is_valid", false)):
		return _assert(false, "Consume selection should be valid")
	# Fodder should be banished from discard
	var discard: Array = player.get("discard", [])
	var fodder_still_in_discard := false
	for card in discard:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) == str(fodder.get("instance_id", "")):
			fodder_still_in_discard = true
	return _assert(not fodder_still_in_discard, "Consumed creature should be banished from discard")


func _test_tenarr_survives_after_consuming() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var tenarr: Dictionary = _catalog_helper.summon(player, match_state, "moe_agi_tenarr_zalviit_nightstalker", "field")
	if tenarr.is_empty():
		return _assert(false, "Failed to summon Tenarr Zalviit Nightstalker")
	# Put a creature in discard
	var fodder := ScenarioFixtures.make_card(pid, "fodder_creature2", {
		"definition_id": "test_fodder2", "card_type": "creature", "cost": 1,
		"power": 1, "health": 1, "name": "Fodder Creature 2",
	})
	fodder["zone"] = "discard"
	player["discard"].append(fodder)
	# Advance to our next turn
	_end_turn_and_start_next(match_state)
	_end_turn_and_start_next(match_state)
	# Resolve consume
	MatchTiming.resolve_consume_selection(match_state, pid, str(fodder.get("instance_id", "")))
	# Tenarr should still be alive in lane
	var still_in_lane := _find_lane_card(match_state, "field", pid, "moe_agi_tenarr_zalviit_nightstalker")
	return _assert(not still_in_lane.is_empty(), "Tenarr should survive after successfully consuming a creature")


# ──────────────────────────────────────────────────────────────────────────────
# Studious Greybeard — look_at_top_deck_may_discard defers turn draw
# ──────────────────────────────────────────────────────────────────────────────

func _test_studious_greybeard_defers_draw_until_choice_resolved() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var greybeard: Dictionary = _catalog_helper.summon(player, match_state, "hos_int_studious_greybeard", "field")
	if greybeard.is_empty():
		return _assert(false, "Failed to summon Studious Greybeard")
	# Record hand size before turn cycle
	_end_turn_and_start_next(match_state)  # end our turn, opponent's turn starts
	var hand_before: int = player.get("hand", []).size()
	_end_turn_and_start_next(match_state)  # end opponent turn, our turn starts
	# Greybeard should have created a pending choice, draw should be deferred
	if not _assert(MatchTiming.has_pending_top_deck_choice(match_state, pid),
			"Studious Greybeard should create pending top deck choice at start of turn"):
		return false
	if not _assert(player.get("hand", []).size() == hand_before,
			"Hand size should not increase before resolving top deck choice (got %d, expected %d)" % [player.get("hand", []).size(), hand_before]):
		return false
	# Resolve the choice (keep) — now the draw should happen
	MatchTiming.resolve_pending_top_deck_choice(match_state, pid, false)
	return _assert(player.get("hand", []).size() == hand_before + 1,
		"Hand size should increase by 1 after resolving top deck choice (got %d, expected %d)" % [player.get("hand", []).size(), hand_before + 1])


func _test_studious_greybeard_discard_draws_next_card() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var greybeard: Dictionary = _catalog_helper.summon(player, match_state, "hos_int_studious_greybeard", "field")
	if greybeard.is_empty():
		return _assert(false, "Failed to summon Studious Greybeard")
	_end_turn_and_start_next(match_state)  # end our turn, opponent's turn starts
	_end_turn_and_start_next(match_state)  # end opponent turn, our turn starts
	# Deck should have the card that will be discarded on top, then the card we'll draw
	var deck: Array = player.get("deck", [])
	if deck.size() < 2:
		return _assert(false, "Need at least 2 cards in deck for this test")
	var top_card_id := str(deck.back().get("instance_id", ""))
	var second_card_id := str(deck[deck.size() - 2].get("instance_id", ""))
	# Discard the top card
	var result := MatchTiming.resolve_pending_top_deck_choice(match_state, pid, true)
	# The top card should now be in discard
	var found_in_discard := false
	for card in player.get("discard", []):
		if str(card.get("instance_id", "")) == top_card_id:
			found_in_discard = true
			break
	if not _assert(found_in_discard, "Discarded top card should be in discard pile"):
		return false
	# The second card should now be in hand (drawn after discard)
	var found_in_hand := false
	for card in player.get("hand", []):
		if str(card.get("instance_id", "")) == second_card_id:
			found_in_hand = true
			break
	return _assert(found_in_hand, "After discarding top card, the next card should be drawn into hand")


# ──────────────────────────────────────────────────────────────────────────────
# Scout's Report — on_play presents top deck choice, then draws after resolution
# ──────────────────────────────────────────────────────────────────────────────

func _test_scouts_report_creates_choice_and_draws_on_keep() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var scout: Dictionary = _catalog_helper.add_to_hand(player, "hos_dual_scouts_report")
	if scout.is_empty():
		return _assert(false, "Failed to add Scout's Report to hand")
	var hand_size_before_play: int = player.get("hand", []).size()
	var deck: Array = player.get("deck", [])
	if deck.size() < 1:
		return _assert(false, "Need at least 1 card in deck for this test")
	var top_card_id := str(deck.back().get("instance_id", ""))
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(scout.get("instance_id", "")))
	if not _assert(bool(play_result.get("is_valid", false)), "Scout's Report should play successfully"):
		return false
	# Scout's Report should have created a pending top deck choice (hand went down by 1 from play)
	if not _assert(MatchTiming.has_pending_top_deck_choice(match_state, pid),
			"Scout's Report should create pending top deck choice on play"):
		return false
	# Hand size dropped by 1 (scout moved out), no draw yet
	if not _assert(player.get("hand", []).size() == hand_size_before_play - 1,
			"Before resolving choice, hand size should be -1 (got %d, expected %d)" % [player.get("hand", []).size(), hand_size_before_play - 1]):
		return false
	# Resolve the choice (keep) — the follow-up draw should fire
	MatchTiming.resolve_pending_top_deck_choice(match_state, pid, false)
	if not _assert(player.get("hand", []).size() == hand_size_before_play,
			"After resolving keep, hand size should be back to original (got %d, expected %d)" % [player.get("hand", []).size(), hand_size_before_play]):
		return false
	# The drawn card should be the original top of deck (keep path: not discarded)
	var found_in_hand := false
	for card in player.get("hand", []):
		if str(card.get("instance_id", "")) == top_card_id:
			found_in_hand = true
			break
	return _assert(found_in_hand, "After resolving keep, the original top deck card should be in hand")


func _test_scouts_report_discard_then_draws_next_card() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var pid := str(player.get("player_id", ""))
	var scout: Dictionary = _catalog_helper.add_to_hand(player, "hos_dual_scouts_report")
	if scout.is_empty():
		return _assert(false, "Failed to add Scout's Report to hand")
	var deck: Array = player.get("deck", [])
	if deck.size() < 2:
		return _assert(false, "Need at least 2 cards in deck for this test")
	var top_card_id := str(deck.back().get("instance_id", ""))
	var second_card_id := str(deck[deck.size() - 2].get("instance_id", ""))
	var play_result := MatchTiming.play_action_from_hand(match_state, pid, str(scout.get("instance_id", "")))
	if not _assert(bool(play_result.get("is_valid", false)), "Scout's Report should play successfully"):
		return false
	# Resolve with discard — top card goes to discard, then the next card is drawn
	MatchTiming.resolve_pending_top_deck_choice(match_state, pid, true)
	var found_in_discard := false
	for card in player.get("discard", []):
		if str(card.get("instance_id", "")) == top_card_id:
			found_in_discard = true
			break
	if not _assert(found_in_discard, "Discarded top card should be in discard pile"):
		return false
	var found_in_hand := false
	for card in player.get("hand", []):
		if str(card.get("instance_id", "")) == second_card_id:
			found_in_hand = true
			break
	return _assert(found_in_hand, "After discard, the next deck card should be drawn into hand")


# ──────────────────────────────────────────────────────────────────────────────
# Giant Slaughterfish — "Give friendly Animals +2/+0 at the start of your turn."
# Fish is an animal subtype, so Slaughterfish should buff itself too.
# ──────────────────────────────────────────────────────────────────────────────

func _test_giant_slaughterfish_buffs_itself() -> bool:
	var match_state := _build_started_match()
	var player := ScenarioFixtures.player(match_state, 0)
	var fish: Dictionary = _catalog_helper.summon(player, match_state, "joo_neu_giant_slaughterfish", "field")
	if fish.is_empty():
		return _assert(false, "Failed to summon Giant Slaughterfish")
	var base_power: int = EvergreenRules.get_power(fish)
	# End our turn, opponent turn passes, our next turn starts — trigger fires
	_end_turn_and_start_next(match_state)  # end our turn
	_end_turn_and_start_next(match_state)  # end opponent turn -> our turn starts
	var new_power: int = EvergreenRules.get_power(fish)
	return _assert(new_power == base_power + 2,
		"Giant Slaughterfish should buff itself +2 power (expected %d, got %d)" % [base_power + 2, new_power])
