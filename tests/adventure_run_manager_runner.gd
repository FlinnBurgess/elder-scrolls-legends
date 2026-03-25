extends SceneTree

const AdventureRunManagerScript := preload("res://src/adventure/adventure_run_manager.gd")
const AdventureCatalogScript := preload("res://src/adventure/adventure_catalog.gd")

var _failures: Array[String] = []


const _TEST_DIR := "res://tests/tmp_adventure/"


func _initialize() -> void:
	AdventureRunManagerScript.set_storage_dir_override(_TEST_DIR)
	_cleanup_test_files()

	_test_start_run()
	_test_start_run_initializes_new_fields()
	_test_full_winning_run_branching()
	_test_loss_with_revive()
	_test_loss_without_revive()
	_test_save_load_round_trip()
	_test_save_load_new_fields()
	_test_has_active_run()
	_test_abandon_run()
	_test_match_state_save_load_clear()
	_test_clear_run_also_clears_match_state()
	_test_gold_award_combat()
	_test_gold_award_mini_boss()
	_test_healer_bonus()
	_test_add_card()
	_test_spend_gold()
	_test_get_full_deck_cards()
	_test_complete_non_combat_node()
	_test_choose_next_node()
	_test_node_offerings_persist()

	_cleanup_test_files()
	_remove_test_dir()
	AdventureRunManagerScript.set_storage_dir_override("")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ADVENTURE_RUN_MANAGER_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_start_run() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")
	_assert(manager.state == AdventureRunManagerScript.State.VIEWING_MAP, "start_run: state should be VIEWING_MAP")
	_assert(manager.adventure_id == "the_dragon_crisis", "start_run: adventure_id should match")
	_assert(manager.deck_id == "dragons_of_skyrim", "start_run: deck_id should match")
	_assert(manager.current_node_id == "node_a", "start_run: current_node_id should be node_a")
	_assert(manager.revives_remaining == 1, "start_run: should have 1 revive")
	_assert(manager.completed_node_ids.is_empty(), "start_run: no completed nodes")
	_cleanup_test_files()


func _test_start_run_initializes_new_fields() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")
	_assert(manager.gold == 0, "new_fields: gold should start at 0")
	_assert(manager.max_health_bonus == 0, "new_fields: max_health_bonus should start at 0")
	_assert(manager.added_cards.is_empty(), "new_fields: added_cards should be empty")
	_cleanup_test_files()


func _test_full_winning_run_branching() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	_assert(not adventure.is_empty(), "full_win_branch: should load adventure")

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")

	# Win node_a (combat) — branches to node_b or node_c
	_assert(manager.current_node_id == "node_a", "full_win_branch: should start on node_a")
	manager.start_match()
	manager.record_win(adventure)
	# After winning a branching node, current_node_id should be empty (player picks)
	_assert(manager.current_node_id.is_empty(), "full_win_branch: should have empty current after branch, got '%s'" % manager.current_node_id)
	_assert(manager.gold == 30, "full_win_branch: should have 30 gold after combat win")

	# Player chooses node_b (reinforcement — non-combat)
	manager.choose_next_node("node_b")
	_assert(manager.current_node_id == "node_b", "full_win_branch: should be on node_b")

	# Complete non-combat node
	manager.complete_non_combat_node(adventure)
	_assert(manager.current_node_id == "node_mini", "full_win_branch: should advance to node_mini")

	# Win mini-boss
	manager.start_match()
	manager.record_win(adventure)
	_assert(manager.gold == 90, "full_win_branch: should have 90 gold after mini-boss (30+60)")
	_assert(manager.current_node_id == "node_aug_creature", "full_win_branch: should advance to node_aug_creature")

	# Complete creature augment node (non-combat)
	manager.complete_non_combat_node(adventure)
	_assert(manager.current_node_id == "node_boon", "full_win_branch: should advance to node_boon")

	# Complete boon node (non-combat)
	manager.complete_non_combat_node(adventure)
	_assert(manager.current_node_id == "node_d", "full_win_branch: should advance to node_d")

	# Win node_d (combat) — branches
	manager.start_match()
	manager.record_win(adventure)
	_assert(manager.gold == 120, "full_win_branch: should have 120 gold")
	_assert(manager.current_node_id.is_empty(), "full_win_branch: should be at branch point")

	# Choose node_e (event — non-combat)
	manager.choose_next_node("node_e")
	manager.complete_non_combat_node(adventure)
	_assert(manager.current_node_id == "node_boss", "full_win_branch: should advance to node_boss")

	# Win final boss
	manager.start_match()
	manager.record_win(adventure)
	_assert(manager.state == AdventureRunManagerScript.State.RUN_COMPLETE, "full_win_branch: should be RUN_COMPLETE")
	_assert(manager.run_won == true, "full_win_branch: run_won should be true")
	_cleanup_test_files()


func _test_loss_with_revive() -> void:
	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")

	# Lose node_a (should use revive)
	manager.start_match()
	manager.record_loss()
	_assert(manager.state == AdventureRunManagerScript.State.VIEWING_MAP, "revive: should be back on map")
	_assert(manager.revives_remaining == 0, "revive: should have 0 revives")
	_assert(manager.current_node_id == "node_a", "revive: should still be on node_a")

	# Win node_a after retry
	manager.start_match()
	manager.record_win(adventure)
	_assert(manager.gold == 30, "revive: should have 30 gold after win")
	_cleanup_test_files()


func _test_loss_without_revive() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")

	# Use up revive
	manager.start_match()
	manager.record_loss()
	_assert(manager.revives_remaining == 0, "no_revive: should have 0 revives after first loss")

	# Lose again — run should end
	manager.start_match()
	manager.record_loss()
	_assert(manager.state == AdventureRunManagerScript.State.RUN_COMPLETE, "no_revive: should be RUN_COMPLETE")
	_assert(manager.run_won == false, "no_revive: run_won should be false")
	_cleanup_test_files()


func _test_save_load_round_trip() -> void:
	_cleanup_test_files()

	var adventure := AdventureCatalogScript.load_adventure("the_dragon_crisis")
	var manager = AdventureRunManagerScript.new()
	var deck := [{"card_id": "c1", "quantity": 2}, {"card_id": "c2", "quantity": 1}]
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", deck, "node_a")

	# Win first node
	manager.start_match()
	manager.record_win(adventure)

	# Load and verify
	var loaded = AdventureRunManagerScript.load_run()
	_assert(loaded != null, "save_load: loaded should not be null")
	if loaded == null:
		return
	_assert(loaded.state == AdventureRunManagerScript.State.VIEWING_MAP, "save_load: state should be VIEWING_MAP, got %d" % loaded.state)
	_assert(loaded.adventure_id == "the_dragon_crisis", "save_load: adventure_id should match")
	_assert(loaded.deck_id == "dragons_of_skyrim", "save_load: deck_id should match")
	_assert(loaded.revives_remaining == 1, "save_load: should have 1 revive")
	_assert(loaded.deck_cards.size() == 2, "save_load: should have 2 deck entries")
	_cleanup_test_files()


func _test_save_load_new_fields() -> void:
	_cleanup_test_files()

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")
	manager.gold = 75
	manager.max_health_bonus = 10
	manager.added_cards = ["card_x", "card_y"]
	manager.save_run()

	var loaded = AdventureRunManagerScript.load_run()
	_assert(loaded != null, "save_load_new: loaded should not be null")
	if loaded == null:
		return
	_assert(loaded.gold == 75, "save_load_new: gold should be 75, got %d" % loaded.gold)
	_assert(loaded.max_health_bonus == 10, "save_load_new: max_health_bonus should be 10, got %d" % loaded.max_health_bonus)
	_assert(loaded.added_cards.size() == 2, "save_load_new: added_cards should have 2 entries, got %d" % loaded.added_cards.size())
	_cleanup_test_files()


func _test_has_active_run() -> void:
	_cleanup_test_files()

	_assert(AdventureRunManagerScript.has_active_run() == false, "has_active: should be false initially")

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")
	_assert(AdventureRunManagerScript.has_active_run() == true, "has_active: should be true after start")

	manager.clear_run()
	_assert(AdventureRunManagerScript.has_active_run() == false, "has_active: should be false after clear")
	_cleanup_test_files()


func _test_abandon_run() -> void:
	_cleanup_test_files()

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")
	_assert(AdventureRunManagerScript.has_active_run() == true, "abandon: should have active run")

	manager.abandon_run()
	_assert(manager.state == AdventureRunManagerScript.State.RUN_COMPLETE, "abandon: state should be RUN_COMPLETE")
	_assert(manager.run_won == false, "abandon: run_won should be false")
	_assert(AdventureRunManagerScript.has_active_run() == false, "abandon: should not have active run")
	_cleanup_test_files()


func _test_match_state_save_load_clear() -> void:
	_cleanup_test_files()

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")

	var test_state := {"phase": "action", "turn_number": 5}
	manager.save_match_state(test_state)
	_assert(AdventureRunManagerScript.has_saved_match_state() == true, "match_state: should have saved state")

	var loaded := AdventureRunManagerScript.load_match_state()
	_assert(not loaded.is_empty(), "match_state: loaded should not be empty")
	_assert(str(loaded.get("phase", "")) == "action", "match_state: phase should be action")
	_assert(int(loaded.get("turn_number", 0)) == 5, "match_state: turn should be 5")

	manager.clear_match_state()
	_assert(AdventureRunManagerScript.has_saved_match_state() == false, "match_state: should be cleared")
	_cleanup_test_files()


func _test_clear_run_also_clears_match_state() -> void:
	_cleanup_test_files()

	var manager = AdventureRunManagerScript.new()
	manager.start_run("the_dragon_crisis", "dragons_of_skyrim", [{"card_id": "c1", "quantity": 1}], "node_a")
	manager.save_match_state({"phase": "action"})
	_assert(AdventureRunManagerScript.has_saved_match_state() == true, "clear_run_ms: should have match state")

	manager.clear_run()
	_assert(AdventureRunManagerScript.has_active_run() == false, "clear_run_ms: no active run")
	_assert(AdventureRunManagerScript.has_saved_match_state() == false, "clear_run_ms: no match state")
	_cleanup_test_files()


func _test_gold_award_combat() -> void:
	var adventure := _make_linear_adventure("combat")
	var manager = AdventureRunManagerScript.new()
	manager.start_run("test", "test_deck", [], "n1")
	manager.start_match()
	manager.record_win(adventure)
	_assert(manager.gold == 30, "gold_combat: should award 30 gold, got %d" % manager.gold)
	_cleanup_test_files()


func _test_gold_award_mini_boss() -> void:
	var adventure := _make_linear_adventure("mini_boss")
	var manager = AdventureRunManagerScript.new()
	manager.start_run("test", "test_deck", [], "n1")
	manager.start_match()
	manager.record_win(adventure)
	_assert(manager.gold == 60, "gold_mini_boss: should award 60 gold, got %d" % manager.gold)
	_cleanup_test_files()


func _test_healer_bonus() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("test", "test_deck", [], "n1")
	_assert(manager.max_health_bonus == 0, "healer: should start at 0")
	manager.apply_healer_bonus()
	_assert(manager.max_health_bonus == 5, "healer: should be 5 after one bonus, got %d" % manager.max_health_bonus)
	manager.apply_healer_bonus()
	_assert(manager.max_health_bonus == 10, "healer: should stack to 10, got %d" % manager.max_health_bonus)
	_cleanup_test_files()


func _test_add_card() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("test", "test_deck", [], "n1")
	manager.add_card("new_card_1")
	manager.add_card("new_card_2")
	_assert(manager.added_cards.size() == 2, "add_card: should have 2 added cards")
	_assert(str(manager.added_cards[0]) == "new_card_1", "add_card: first card should be new_card_1")
	_cleanup_test_files()


func _test_spend_gold() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("test", "test_deck", [], "n1")
	manager.gold = 50
	manager.save_run()

	_assert(manager.spend_gold(30) == true, "spend_gold: should succeed with enough gold")
	_assert(manager.gold == 20, "spend_gold: should have 20 remaining")
	_assert(manager.spend_gold(30) == false, "spend_gold: should fail with insufficient gold")
	_assert(manager.gold == 20, "spend_gold: gold should be unchanged after failed spend")
	_cleanup_test_files()


func _test_get_full_deck_cards() -> void:
	var manager = AdventureRunManagerScript.new()
	var base_deck := [{"card_id": "c1", "quantity": 2}, {"card_id": "c2", "quantity": 1}]
	manager.start_run("test", "test_deck", base_deck, "n1")
	manager.add_card("c3")
	manager.add_card("c4")

	var full := manager.get_full_deck_cards()
	_assert(full.size() == 4, "full_deck: should have 4 entries (2 base + 2 added), got %d" % full.size())
	# Base cards preserved
	_assert(str(full[0].get("card_id", "")) == "c1", "full_deck: first should be c1")
	_assert(int(full[0].get("quantity", 0)) == 2, "full_deck: c1 should have quantity 2")
	# Added cards appended with quantity 1
	_assert(str(full[2].get("card_id", "")) == "c3", "full_deck: third should be c3")
	_assert(int(full[2].get("quantity", 0)) == 1, "full_deck: added card should have quantity 1")
	_cleanup_test_files()


func _test_complete_non_combat_node() -> void:
	# Linear non-combat node
	var adventure := {
		"nodes": {
			"n1": {"type": "healer", "next": ["n2"]},
			"n2": {"type": "shop", "next": []},
		}
	}
	var manager = AdventureRunManagerScript.new()
	manager.start_run("test", "test_deck", [], "n1")
	manager.complete_non_combat_node(adventure)
	_assert(manager.current_node_id == "n2", "non_combat: should advance to n2, got '%s'" % manager.current_node_id)
	_assert("n1" in manager.completed_node_ids, "non_combat: n1 should be completed")
	_cleanup_test_files()


func _test_choose_next_node() -> void:
	var manager = AdventureRunManagerScript.new()
	manager.start_run("test", "test_deck", [], "n1")
	manager.current_node_id = ""  # Simulate branch point
	manager.choose_next_node("n_branch_a")
	_assert(manager.current_node_id == "n_branch_a", "choose_next: should set current to n_branch_a")
	_cleanup_test_files()


func _test_node_offerings_persist() -> void:
	_cleanup_test_files()

	var manager = AdventureRunManagerScript.new()
	manager.start_run("test", "test_deck", [], "n1")

	# Save offerings for a node
	var test_cards := [{"card_id": "c1", "name": "Card One"}, {"card_id": "c2", "name": "Card Two"}]
	manager.save_node_offering("shop_1", test_cards)

	# Mark a card purchased
	manager.mark_card_purchased("shop_1", "c1")

	# Reload and verify
	var loaded = AdventureRunManagerScript.load_run()
	_assert(loaded != null, "offerings: loaded should not be null")
	if loaded == null:
		return
	var offering := loaded.get_node_offering("shop_1")
	_assert(not offering.is_empty(), "offerings: should have offering for shop_1")
	var cards: Array = offering.get("cards", [])
	_assert(cards.size() == 2, "offerings: should have 2 cards, got %d" % cards.size())
	var purchased: Array = offering.get("purchased_ids", [])
	_assert(purchased.size() == 1, "offerings: should have 1 purchased, got %d" % purchased.size())
	_assert(str(purchased[0]) == "c1", "offerings: purchased card should be c1")

	# Non-existent offering returns empty
	var empty_offering := loaded.get_node_offering("nonexistent")
	_assert(empty_offering.is_empty(), "offerings: nonexistent node should return empty")
	_cleanup_test_files()


func _make_linear_adventure(node_type: String) -> Dictionary:
	return {
		"nodes": {
			"n1": {"type": node_type, "enemy_deck": "e1", "next": ["n2"]},
			"n2": {"type": "final_boss", "enemy_deck": "e2", "next": []},
		}
	}


func _cleanup_test_files() -> void:
	var dir := DirAccess.open(_TEST_DIR)
	if dir != null:
		if FileAccess.file_exists(_TEST_DIR + "run.json"):
			dir.remove("run.json")
		if FileAccess.file_exists(_TEST_DIR + "match_state.json"):
			dir.remove("match_state.json")


func _remove_test_dir() -> void:
	var dir := DirAccess.open("res://tests/")
	if dir != null:
		dir.remove("tmp_adventure")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
