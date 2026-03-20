extends SceneTree

const DeckArchetypeDetector = preload("res://src/ai/deck_archetype_detector.gd")
const AIPlayProfile = preload("res://src/ai/ai_play_profile.gd")


func _initialize() -> void:
	var failures: Array = []
	_test_detects_aggro_deck(failures)
	_test_detects_control_deck(failures)
	_test_detects_midrange_deck(failures)
	_test_empty_deck_is_midrange(failures)
	_test_profile_midrange_matches_defaults(failures)
	_test_profile_aggro_has_higher_face_damage(failures)
	_test_profile_control_has_higher_board_control(failures)
	_test_quality_zero_has_high_noise(failures)
	_test_quality_one_has_no_noise(failures)
	_test_low_quality_disables_lookahead(failures)
	_test_win_streak_quality_formula(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("AI_PLAY_PROFILE_OK")
	quit(0)


func _test_detects_aggro_deck(failures: Array) -> void:
	# Deck full of cheap charge creatures should be classified as aggro.
	var card_db := {}
	var deck_ids: Array = []
	for i in range(20):
		var cid := "aggro_creature_%d" % i
		card_db[cid] = {"card_type": "creature", "cost": 1 + (i % 2), "base_power": 2 + (i % 3), "base_health": 1, "keywords": ["charge"], "subtypes": [], "attributes": []}
		deck_ids.append(cid)
	for i in range(5):
		var cid := "aggro_action_%d" % i
		card_db[cid] = {"card_type": "action", "cost": 1, "keywords": [], "subtypes": [], "attributes": []}
		deck_ids.append(cid)
	var result := DeckArchetypeDetector.detect(deck_ids, card_db)
	_assert(result.get("archetype") == "aggro", "aggro_deck: expected archetype 'aggro', got '%s' (score: %s)" % [result.get("archetype"), result.get("aggro_score")], failures)
	_assert(float(result.get("aggro_score", 0.0)) < -0.33, "aggro_deck: expected aggro_score < -0.33, got %s" % result.get("aggro_score"), failures)


func _test_detects_control_deck(failures: Array) -> void:
	# Deck with expensive guards, actions, and supports should be classified as control.
	var card_db := {}
	var deck_ids: Array = []
	for i in range(12):
		var cid := "ctrl_creature_%d" % i
		card_db[cid] = {"card_type": "creature", "cost": 5 + (i % 3), "base_power": 3, "base_health": 6, "keywords": ["guard"], "subtypes": [], "attributes": []}
		deck_ids.append(cid)
	for i in range(10):
		var cid := "ctrl_action_%d" % i
		card_db[cid] = {"card_type": "action", "cost": 4 + (i % 3), "keywords": [], "subtypes": [], "attributes": []}
		deck_ids.append(cid)
	for i in range(3):
		var cid := "ctrl_support_%d" % i
		card_db[cid] = {"card_type": "support", "cost": 5, "keywords": [], "subtypes": [], "attributes": []}
		deck_ids.append(cid)
	var result := DeckArchetypeDetector.detect(deck_ids, card_db)
	_assert(result.get("archetype") == "control", "control_deck: expected archetype 'control', got '%s' (score: %s)" % [result.get("archetype"), result.get("aggro_score")], failures)
	_assert(float(result.get("aggro_score", 0.0)) > 0.33, "control_deck: expected aggro_score > 0.33, got %s" % result.get("aggro_score"), failures)


func _test_detects_midrange_deck(failures: Array) -> void:
	# Balanced deck should be classified as midrange.
	var card_db := {}
	var deck_ids: Array = []
	for i in range(18):
		var cost := 1 + (i % 6)  # costs 1-6, roughly balanced curve
		var cid := "mid_creature_%d" % i
		card_db[cid] = {"card_type": "creature", "cost": cost, "base_power": cost, "base_health": cost, "keywords": [], "subtypes": [], "attributes": []}
		deck_ids.append(cid)
	for i in range(6):
		var cid := "mid_action_%d" % i
		card_db[cid] = {"card_type": "action", "cost": 2 + (i % 3), "keywords": [], "subtypes": [], "attributes": []}
		deck_ids.append(cid)
	for i in range(2):
		var cid := "mid_guard_%d" % i
		card_db[cid] = {"card_type": "creature", "cost": 4, "base_power": 3, "base_health": 5, "keywords": ["guard"], "subtypes": [], "attributes": []}
		deck_ids.append(cid)
	var result := DeckArchetypeDetector.detect(deck_ids, card_db)
	_assert(result.get("archetype") == "midrange", "midrange_deck: expected archetype 'midrange', got '%s' (score: %s)" % [result.get("archetype"), result.get("aggro_score")], failures)


func _test_empty_deck_is_midrange(failures: Array) -> void:
	var result := DeckArchetypeDetector.detect([], {})
	_assert(result.get("archetype") == "midrange", "empty_deck: expected 'midrange', got '%s'" % result.get("archetype"), failures)
	_assert(is_equal_approx(float(result.get("aggro_score", 1.0)), 0.0), "empty_deck: expected aggro_score 0.0, got %s" % result.get("aggro_score"), failures)


func _test_profile_midrange_matches_defaults(failures: Array) -> void:
	# At aggro_score=0, quality=1.0, the profile should match the midrange constants.
	var profile := AIPlayProfile.build_options(0.0, 1.0)
	_assert(is_equal_approx(float(profile.get("face_damage_bonus", 0.0)), 0.25), "midrange_profile: face_damage_bonus should be 0.25, got %s" % profile.get("face_damage_bonus"), failures)
	_assert(is_equal_approx(float(profile.get("shadow_lane_bonus", 0.0)), 0.55), "midrange_profile: shadow_lane_bonus should be 0.55, got %s" % profile.get("shadow_lane_bonus"), failures)
	_assert(is_equal_approx(float(profile.get("creature_killed_bonus", 0.0)), 2.3), "midrange_profile: creature_killed_bonus should be 2.3, got %s" % profile.get("creature_killed_bonus"), failures)
	_assert(is_equal_approx(float(profile.get("health_weight", 0.0)), 2.5), "midrange_profile: health_weight should be 2.5, got %s" % profile.get("health_weight"), failures)
	_assert(is_equal_approx(float(profile.get("score_noise", -1.0)), 0.0), "midrange_profile: score_noise at q=1 should be 0.0, got %s" % profile.get("score_noise"), failures)


func _test_profile_aggro_has_higher_face_damage(failures: Array) -> void:
	var aggro_profile := AIPlayProfile.build_options(-1.0, 1.0)
	var midrange_profile := AIPlayProfile.build_options(0.0, 1.0)
	_assert(float(aggro_profile.get("face_damage_bonus", 0.0)) > float(midrange_profile.get("face_damage_bonus", 0.0)), "aggro_profile: face_damage_bonus should exceed midrange", failures)
	_assert(float(aggro_profile.get("shadow_lane_bonus", 0.0)) > float(midrange_profile.get("shadow_lane_bonus", 0.0)), "aggro_profile: shadow_lane_bonus should exceed midrange", failures)
	_assert(float(aggro_profile.get("incoming_threat_weight", 0.0)) < float(midrange_profile.get("incoming_threat_weight", 0.0)), "aggro_profile: incoming_threat_weight should be lower than midrange", failures)


func _test_profile_control_has_higher_board_control(failures: Array) -> void:
	var control_profile := AIPlayProfile.build_options(1.0, 1.0)
	var midrange_profile := AIPlayProfile.build_options(0.0, 1.0)
	_assert(float(control_profile.get("creature_killed_bonus", 0.0)) > float(midrange_profile.get("creature_killed_bonus", 0.0)), "control_profile: creature_killed_bonus should exceed midrange", failures)
	_assert(float(control_profile.get("health_weight", 0.0)) > float(midrange_profile.get("health_weight", 0.0)), "control_profile: health_weight should exceed midrange", failures)
	_assert(float(control_profile.get("hand_weight", 0.0)) > float(midrange_profile.get("hand_weight", 0.0)), "control_profile: hand_weight should exceed midrange", failures)
	_assert(float(control_profile.get("face_damage_bonus", 0.0)) < float(midrange_profile.get("face_damage_bonus", 0.0)), "control_profile: face_damage_bonus should be lower than midrange", failures)


func _test_quality_zero_has_high_noise(failures: Array) -> void:
	var profile := AIPlayProfile.build_options(0.0, 0.0)
	_assert(float(profile.get("score_noise", 0.0)) > 3.0, "quality_0: score_noise should be > 3.0, got %s" % profile.get("score_noise"), failures)
	_assert(int(profile.get("lookahead_depth", 1)) == 0, "quality_0: lookahead_depth should be 0, got %s" % profile.get("lookahead_depth"), failures)


func _test_quality_one_has_no_noise(failures: Array) -> void:
	var profile := AIPlayProfile.build_options(0.0, 1.0)
	_assert(is_equal_approx(float(profile.get("score_noise", 1.0)), 0.0), "quality_1: score_noise should be 0.0, got %s" % profile.get("score_noise"), failures)
	_assert(int(profile.get("lookahead_depth", 0)) == 1, "quality_1: lookahead_depth should be 1, got %s" % profile.get("lookahead_depth"), failures)
	_assert(int(profile.get("top_candidate_lookahead", 0)) == 3, "quality_1: top_candidate_lookahead should be 3, got %s" % profile.get("top_candidate_lookahead"), failures)


func _test_low_quality_disables_lookahead(failures: Array) -> void:
	var profile := AIPlayProfile.build_options(0.0, 0.2)
	_assert(int(profile.get("lookahead_depth", 1)) == 0, "quality_0.2: lookahead_depth should be 0, got %s" % profile.get("lookahead_depth"), failures)
	var profile_mid := AIPlayProfile.build_options(0.0, 0.5)
	_assert(int(profile_mid.get("lookahead_depth", 0)) == 1, "quality_0.5: lookahead_depth should be 1, got %s" % profile_mid.get("lookahead_depth"), failures)


func _test_win_streak_quality_formula(failures: Array) -> void:
	# Verify the formula: win_bonus = clamp(wins * 0.04, 0.0, 0.20)
	_assert(is_equal_approx(clampf(0.0 * 0.04, 0.0, 0.20), 0.0), "win_streak: 0 wins should give 0.0 bonus", failures)
	_assert(is_equal_approx(clampf(3.0 * 0.04, 0.0, 0.20), 0.12), "win_streak: 3 wins should give 0.12 bonus", failures)
	_assert(is_equal_approx(clampf(5.0 * 0.04, 0.0, 0.20), 0.20), "win_streak: 5 wins should give 0.20 bonus", failures)
	_assert(is_equal_approx(clampf(8.0 * 0.04, 0.0, 0.20), 0.20), "win_streak: 8 wins should still cap at 0.20 bonus", failures)


func _assert(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		push_error(message)
		failures.append(message)
