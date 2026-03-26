extends SceneTree

const AdventureProgressionManagerScript := preload("res://src/adventure/adventure_progression_manager.gd")
const RelicCatalogScript := preload("res://src/adventure/relic_catalog.gd")

var _failures: Array[String] = []
const _TEST_DIR := "res://tests/tmp_progression/"


func _initialize() -> void:
	AdventureProgressionManagerScript.set_save_dir_override(_TEST_DIR)
	_cleanup()

	_test_new_manager_defaults()
	_test_xp_and_level()
	_test_level_caps_at_30()
	_test_award_xp_with_level_up()
	_test_reward_track_starting_gold()
	_test_reward_track_card_swap()
	_test_reward_track_permanent_augment()
	_test_reward_track_max_health()
	_test_reward_track_reroll_tokens()
	_test_reward_track_revives()
	_test_star_powers_unlock()
	_test_relic_slots_unlock()
	_test_relic_equip_unequip()
	_test_relic_equip_requires_unlock()
	_test_relic_equip_respects_slot_limit()
	_test_relic_no_duplicate_equip()
	_test_effective_deck_cards_swap()
	_test_effective_deck_cards_no_swaps()
	_test_adventure_completion_first_clear()
	_test_adventure_completion_repeat()
	_test_save_load_round_trip()
	_test_last_selected_deck()
	_test_xp_for_next_level()
	_test_multi_level_up()

	_cleanup()
	_remove_test_dir()
	AdventureProgressionManagerScript.set_save_dir_override("")
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ADVENTURE_PROGRESSION_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# --- Tests ---

func _test_new_manager_defaults() -> void:
	var m := AdventureProgressionManagerScript.new()
	_assert(m.get_deck_level("test") == 0, "defaults: level should be 0")
	_assert(m.get_deck_xp("test") == 0, "defaults: xp should be 0")
	_assert(m.get_equipped_relics("test").is_empty(), "defaults: no equipped relics")
	_assert(m.unlocked_relics.is_empty(), "defaults: no unlocked relics")
	_assert(m.last_selected_deck_id == "", "defaults: no last deck")
	_cleanup()


func _test_xp_and_level() -> void:
	var m := AdventureProgressionManagerScript.new()
	# Level 1 threshold is 50 XP
	m.award_xp("test", 49)
	_assert(m.get_deck_level("test") == 0, "xp_level: 49 xp should be level 0")
	m.award_xp("test", 1)
	_assert(m.get_deck_level("test") == 1, "xp_level: 50 xp should be level 1")
	# Level 2 threshold is 75 (total 125)
	m.award_xp("test", 75)
	_assert(m.get_deck_level("test") == 2, "xp_level: 125 xp should be level 2")
	_cleanup()


func _test_level_caps_at_30() -> void:
	var m := AdventureProgressionManagerScript.new()
	# Give massive XP
	m.award_xp("test", 999999)
	_assert(m.get_deck_level("test") == 30, "level_cap: should cap at 30, got %d" % m.get_deck_level("test"))
	_cleanup()


func _test_award_xp_with_level_up() -> void:
	var m := AdventureProgressionManagerScript.new()
	# Use a real deck so reward track is available
	var result := m.award_xp("dragons_of_skyrim", 50)  # Exactly level 1
	_assert(result["old_level"] == 0, "award_xp: old_level should be 0")
	_assert(result["new_level"] == 1, "award_xp: new_level should be 1")
	_assert(result["rewards"].size() > 0, "award_xp: should have rewards for level 1")
	_cleanup()


func _test_reward_track_starting_gold() -> void:
	# Dragons level 1 reward is starting_gold +10
	var m := AdventureProgressionManagerScript.new()
	m.award_xp("dragons_of_skyrim", 50)
	_assert(m.get_starting_gold("dragons_of_skyrim") == 10, "reward_gold: should have 10 starting gold, got %d" % m.get_starting_gold("dragons_of_skyrim"))
	_cleanup()


func _test_reward_track_card_swap() -> void:
	# Dragons level 4 is a card_swap
	var m := AdventureProgressionManagerScript.new()
	# XP for levels 1-4: 50+75+100+125 = 350
	m.award_xp("dragons_of_skyrim", 350)
	var swaps := m.get_card_swaps("dragons_of_skyrim")
	_assert(swaps.size() == 1, "reward_swap: should have 1 swap, got %d" % swaps.size())
	if swaps.size() > 0:
		_assert(str(swaps[0].get("remove", "")) == "str_morkul_gatekeeper", "reward_swap: remove should be str_morkul_gatekeeper")
		_assert(str(swaps[0].get("add", "")) == "hos_str_skyborn_dragon", "reward_swap: add should be hos_str_skyborn_dragon")
	_cleanup()


func _test_reward_track_permanent_augment() -> void:
	# Dragons level 13 is a permanent_augment
	var m := AdventureProgressionManagerScript.new()
	# XP for levels 1-13: 50+75+100+125+150+200+250+300+350+400+475+550+625 = 3650
	m.award_xp("dragons_of_skyrim", 3650)
	var augments := m.get_permanent_augments("dragons_of_skyrim")
	_assert(augments.size() == 1, "reward_augment: should have 1 augment, got %d" % augments.size())
	if augments.size() > 0:
		_assert(str(augments[0].get("card_id", "")) == "hos_neu_alduin", "reward_augment: card should be alduin")
		_assert(str(augments[0].get("augment_id", "")) == "stats_2_2", "reward_augment: augment should be stats_2_2")
	_cleanup()


func _test_reward_track_max_health() -> void:
	# Dragons level 2 is max_health +2
	var m := AdventureProgressionManagerScript.new()
	m.award_xp("dragons_of_skyrim", 125)  # 50+75 = levels 1-2
	_assert(m.get_max_health_bonus("dragons_of_skyrim") == 2, "reward_hp: should be 2, got %d" % m.get_max_health_bonus("dragons_of_skyrim"))
	_cleanup()


func _test_reward_track_reroll_tokens() -> void:
	# Dragons level 7 is reroll_tokens +1
	var m := AdventureProgressionManagerScript.new()
	# XP for levels 1-7: 50+75+100+125+150+200+250 = 950
	m.award_xp("dragons_of_skyrim", 950)
	_assert(m.get_bonus_reroll_tokens("dragons_of_skyrim") == 1, "reward_reroll: should be 1, got %d" % m.get_bonus_reroll_tokens("dragons_of_skyrim"))
	_cleanup()


func _test_reward_track_revives() -> void:
	# Dragons level 10 is revives +1
	var m := AdventureProgressionManagerScript.new()
	# XP for levels 1-10: 50+75+100+125+150+200+250+300+350+400 = 2000
	m.award_xp("dragons_of_skyrim", 2000)
	_assert(m.get_bonus_revives("dragons_of_skyrim") == 1, "reward_revive: should be 1, got %d" % m.get_bonus_revives("dragons_of_skyrim"))
	_cleanup()


func _test_star_powers_unlock() -> void:
	var m := AdventureProgressionManagerScript.new()
	# Level 0: no stars
	_assert(m.get_unlocked_star_count("dragons_of_skyrim") == 0, "stars: level 0 should have 0 stars")
	# Level 5: 1 star (50+75+100+125+150 = 500)
	m.award_xp("dragons_of_skyrim", 500)
	_assert(m.get_unlocked_star_count("dragons_of_skyrim") == 1, "stars: level 5 should have 1 star, got %d" % m.get_unlocked_star_count("dragons_of_skyrim"))
	var stars := m.get_active_star_powers("dragons_of_skyrim")
	_assert(stars.size() == 1, "stars: should have 1 active star power")
	if stars.size() > 0:
		_assert(str(stars[0].get("id", "")) == "sp_dragons_1", "stars: first star should be sp_dragons_1")
	_cleanup()


func _test_relic_slots_unlock() -> void:
	var m := AdventureProgressionManagerScript.new()
	_assert(m.get_unlocked_relic_slot_count("test") == 0, "relic_slots: level 0 should have 0 slots")
	# Level 10 unlocks first slot (XP: 2000)
	m.award_xp("dragons_of_skyrim", 2000)
	_assert(m.get_unlocked_relic_slot_count("dragons_of_skyrim") == 1, "relic_slots: level 10 should have 1 slot, got %d" % m.get_unlocked_relic_slot_count("dragons_of_skyrim"))
	_cleanup()


func _test_relic_equip_unequip() -> void:
	var m := AdventureProgressionManagerScript.new()
	m.award_xp("dragons_of_skyrim", 2000)  # Unlock slot 1
	m.unlocked_relics = ["skeleton_key"]
	var ok := m.equip_relic("dragons_of_skyrim", "skeleton_key")
	_assert(ok == true, "equip: should succeed")
	var equipped := m.get_equipped_relics("dragons_of_skyrim")
	_assert(equipped.size() == 1, "equip: should have 1 equipped, got %d" % equipped.size())
	_assert(str(equipped[0]) == "skeleton_key", "equip: should be skeleton_key")
	m.unequip_relic("dragons_of_skyrim", "skeleton_key")
	_assert(m.get_equipped_relics("dragons_of_skyrim").is_empty(), "unequip: should have 0 equipped")
	_cleanup()


func _test_relic_equip_requires_unlock() -> void:
	var m := AdventureProgressionManagerScript.new()
	m.award_xp("dragons_of_skyrim", 2000)
	# Not in unlocked_relics
	var ok := m.equip_relic("dragons_of_skyrim", "skeleton_key")
	_assert(ok == false, "equip_unlock: should fail if relic not unlocked")
	_cleanup()


func _test_relic_equip_respects_slot_limit() -> void:
	var m := AdventureProgressionManagerScript.new()
	m.award_xp("dragons_of_skyrim", 2000)  # 1 slot
	m.unlocked_relics = ["skeleton_key", "amulet_of_kings"]
	m.equip_relic("dragons_of_skyrim", "skeleton_key")
	var ok := m.equip_relic("dragons_of_skyrim", "amulet_of_kings")
	_assert(ok == false, "equip_limit: should fail when slot full")
	_cleanup()


func _test_relic_no_duplicate_equip() -> void:
	var m := AdventureProgressionManagerScript.new()
	m.award_xp("dragons_of_skyrim", 2000)  # 1 slot
	m.unlocked_relics = ["skeleton_key"]
	m.equip_relic("dragons_of_skyrim", "skeleton_key")
	var ok := m.equip_relic("dragons_of_skyrim", "skeleton_key")
	_assert(ok == false, "equip_dup: should fail on duplicate")
	_cleanup()


func _test_effective_deck_cards_swap() -> void:
	var m := AdventureProgressionManagerScript.new()
	# Manually add a swap
	var entry := m._get_deck_entry("test")
	entry["card_swaps"] = [{"remove": "card_a", "add": "card_x"}]
	m.deck_data["test"] = entry

	var base := [{"card_id": "card_a", "quantity": 2}, {"card_id": "card_b", "quantity": 1}]
	var effective := m.get_effective_deck_cards("test", base)

	# card_a should go from qty 2 to qty 1, card_x added with qty 1
	var a_found := false
	var x_found := false
	for c in effective:
		if str(c.get("card_id", "")) == "card_a":
			_assert(int(c.get("quantity", 0)) == 1, "effective_swap: card_a should have qty 1, got %d" % int(c.get("quantity", 0)))
			a_found = true
		if str(c.get("card_id", "")) == "card_x":
			_assert(int(c.get("quantity", 0)) == 1, "effective_swap: card_x should have qty 1")
			x_found = true
	_assert(a_found, "effective_swap: card_a should still exist")
	_assert(x_found, "effective_swap: card_x should be added")
	_cleanup()


func _test_effective_deck_cards_no_swaps() -> void:
	var m := AdventureProgressionManagerScript.new()
	var base := [{"card_id": "c1", "quantity": 3}]
	var effective := m.get_effective_deck_cards("test", base)
	_assert(effective.size() == 1, "effective_no_swap: should have 1 entry")
	_assert(int(effective[0].get("quantity", 0)) == 3, "effective_no_swap: qty should be 3")
	_cleanup()


func _test_adventure_completion_first_clear() -> void:
	var m := AdventureProgressionManagerScript.new()
	var adventure := {
		"first_completion_reward": {"type": "relic", "relic_id": "skeleton_key"},
		"completion_reward_pool": [],
	}
	_assert(m.is_adventure_completed("adv_1") == false, "completion: should not be completed initially")
	var result := m.record_adventure_completion("adv_1", adventure)
	_assert(m.is_adventure_completed("adv_1") == true, "completion: should be completed after recording")
	_assert(result["first_clear_reward"] != null, "completion: should have first clear reward")
	_assert("skeleton_key" in m.unlocked_relics, "completion: skeleton_key should be unlocked")
	# Second completion should NOT give first clear reward
	var result2 := m.record_adventure_completion("adv_1", adventure)
	_assert(result2["first_clear_reward"] == null, "completion: repeat should not give first clear")
	_cleanup()


func _test_adventure_completion_repeat() -> void:
	var m := AdventureProgressionManagerScript.new()
	var adventure := {
		"first_completion_reward": {},
		"completion_reward_pool": [],
	}
	m.record_adventure_completion("adv_1", adventure)
	m.record_adventure_completion("adv_1", adventure)
	var entry: Dictionary = m.adventure_completions.get("adv_1", {})
	_assert(int(entry.get("completion_count", 0)) == 2, "repeat: count should be 2, got %d" % int(entry.get("completion_count", 0)))
	_cleanup()


func _test_save_load_round_trip() -> void:
	_cleanup()
	var m := AdventureProgressionManagerScript.new()
	m.award_xp("dragons_of_skyrim", 200)
	m.unlocked_relics = ["skeleton_key", "amulet_of_kings"]
	m.last_selected_deck_id = "dragons_of_skyrim"
	m.adventure_completions["adv_1"] = {"completed": true, "completion_count": 3}

	var entry := m._get_deck_entry("dragons_of_skyrim")
	entry["equipped_relics"] = ["skeleton_key"]
	m.deck_data["dragons_of_skyrim"] = entry
	m.save()

	var loaded := AdventureProgressionManagerScript.load_progression()
	_assert(loaded.get_deck_xp("dragons_of_skyrim") == 200, "save_load: xp should be 200, got %d" % loaded.get_deck_xp("dragons_of_skyrim"))
	_assert(loaded.unlocked_relics.size() == 2, "save_load: should have 2 unlocked relics")
	_assert(loaded.last_selected_deck_id == "dragons_of_skyrim", "save_load: last deck should match")
	_assert(loaded.is_adventure_completed("adv_1") == true, "save_load: adv_1 should be completed")
	var equipped := loaded.get_equipped_relics("dragons_of_skyrim")
	_assert(equipped.size() == 1, "save_load: should have 1 equipped relic")
	_cleanup()


func _test_last_selected_deck() -> void:
	_cleanup()
	var m := AdventureProgressionManagerScript.new()
	m.last_selected_deck_id = "the_companions"
	m.save()
	var loaded := AdventureProgressionManagerScript.load_progression()
	_assert(loaded.last_selected_deck_id == "the_companions", "last_deck: should persist")
	_cleanup()


func _test_xp_for_next_level() -> void:
	var m := AdventureProgressionManagerScript.new()
	var info := m.get_xp_for_next_level("test")
	_assert(info["is_max"] == false, "xp_next: should not be max at level 0")
	_assert(int(info["xp_needed"]) == 50, "xp_next: first level needs 50 xp, got %d" % int(info["xp_needed"]))
	_assert(int(info["xp_into_level"]) == 0, "xp_next: should have 0 xp into level")

	m.award_xp("test", 30)
	info = m.get_xp_for_next_level("test")
	_assert(int(info["xp_into_level"]) == 30, "xp_next: should have 30 xp into level, got %d" % int(info["xp_into_level"]))
	_cleanup()


func _test_multi_level_up() -> void:
	var m := AdventureProgressionManagerScript.new()
	# Award enough XP to go from 0 to level 3 in one shot (50+75+100 = 225)
	var result := m.award_xp("dragons_of_skyrim", 225)
	_assert(result["old_level"] == 0, "multi_level: old_level should be 0")
	_assert(result["new_level"] == 3, "multi_level: new_level should be 3, got %d" % int(result["new_level"]))
	_assert(result["rewards"].size() == 3, "multi_level: should have 3 rewards (one per level), got %d" % result["rewards"].size())
	_cleanup()


# --- Helpers ---

func _cleanup() -> void:
	var dir := DirAccess.open(_TEST_DIR)
	if dir != null:
		if FileAccess.file_exists(_TEST_DIR + "progression.json"):
			dir.remove("progression.json")


func _remove_test_dir() -> void:
	var dir := DirAccess.open("res://tests/")
	if dir != null:
		dir.remove("tmp_progression")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
