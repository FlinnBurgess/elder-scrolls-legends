extends SceneTree

const PuzzleConfigScript := preload("res://src/puzzle/puzzle_config.gd")
const PuzzleCodecScript := preload("res://src/puzzle/puzzle_codec.gd")
const PuzzlePersistenceScript := preload("res://src/puzzle/puzzle_persistence.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	# Use res:// path for persistence tests (user:// not available headless)
	PuzzlePersistenceScript.set_save_path("res://data/test_puzzle_data.json")

	# Config validation tests
	_test_validate_valid_config()
	_test_validate_missing_name()
	_test_validate_name_too_long()
	_test_validate_bad_type()
	_test_validate_bad_lane_widths()
	_test_validate_single_lane()
	_test_validate_negative_magicka()

	# Match state building tests
	_test_build_basic_kill_puzzle()
	_test_build_survive_puzzle()
	_test_runes_for_health()
	_test_build_with_creatures()
	_test_build_with_ring()
	_test_build_with_supports()
	_test_build_with_hand_and_deck()

	# Codec tests
	_test_codec_round_trip()
	_test_codec_raw_prefix()
	_test_codec_decode_invalid_prefix()
	_test_codec_decode_bad_json()

	# Persistence tests
	_test_persistence_add_and_list()
	_test_persistence_delete()
	_test_persistence_mark_solved()

	# Cleanup test persistence file
	DirAccess.remove_absolute("res://data/test_puzzle_data.json")

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PUZZLE_CONFIG_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# -- Config Validation Tests --

func _test_validate_valid_config() -> void:
	var config := _minimal_config()
	var result: Dictionary = PuzzleConfigScript.validate_config(config)
	_assert(result.get("valid") == true, "valid config should pass validation, errors: %s" % str(result.get("errors", [])))


func _test_validate_missing_name() -> void:
	var config := _minimal_config()
	config.erase("name")
	var result: Dictionary = PuzzleConfigScript.validate_config(config)
	_assert(result.get("valid") == false, "missing name should fail validation")


func _test_validate_name_too_long() -> void:
	var config := _minimal_config()
	config["name"] = "A".repeat(41)
	var result: Dictionary = PuzzleConfigScript.validate_config(config)
	_assert(result.get("valid") == false, "name > 40 chars should fail validation")


func _test_validate_bad_type() -> void:
	var config := _minimal_config()
	config["type"] = "invalid"
	var result: Dictionary = PuzzleConfigScript.validate_config(config)
	_assert(result.get("valid") == false, "bad type should fail validation")


func _test_validate_bad_lane_widths() -> void:
	var config := _minimal_config()
	config["lanes"] = [{"lane_type": "field", "width": 3}, {"lane_type": "shadow", "width": 3}]
	var result: Dictionary = PuzzleConfigScript.validate_config(config)
	_assert(result.get("valid") == false, "lane widths summing to 6 should fail, errors: %s" % str(result.get("errors", [])))


func _test_validate_single_lane() -> void:
	var config := _minimal_config()
	config["lanes"] = [{"lane_type": "field", "width": 8}]
	var result: Dictionary = PuzzleConfigScript.validate_config(config)
	_assert(result.get("valid") == false, "single lane should fail validation")


func _test_validate_negative_magicka() -> void:
	var config := _minimal_config()
	config["player"]["max_magicka"] = -1
	var result: Dictionary = PuzzleConfigScript.validate_config(config)
	_assert(result.get("valid") == false, "negative magicka should fail validation")


# -- Match State Building Tests --

func _test_build_basic_kill_puzzle() -> void:
	var config := _minimal_config()
	var state: Dictionary = PuzzleConfigScript.build_puzzle_match_state(config)
	_assert(state.get("puzzle_mode") == true, "should have puzzle_mode flag")
	_assert(state.get("puzzle_type") == "kill", "should be kill type")
	_assert(state.get("puzzle_suppress_draw") == true, "should suppress draw")
	_assert(state.get("puzzle_suppress_magicka_gain") == true, "should suppress magicka gain")
	_assert(state.get("phase") == "action", "should start in action phase")
	_assert(state.get("turn_number") == 1, "should be turn 1")
	_assert(state.get("active_player_id") == "player_1", "player should go first")
	var mulligan: Dictionary = state.get("mulligan", {})
	_assert(mulligan.get("pending_player_ids", [1]).size() == 0, "mulligan should be skipped")


func _test_build_survive_puzzle() -> void:
	var config := _minimal_config()
	config["type"] = "survive"
	var state: Dictionary = PuzzleConfigScript.build_puzzle_match_state(config)
	_assert(state.get("puzzle_type") == "survive", "should be survive type")


func _test_runes_for_health() -> void:
	var runes_30: Array = PuzzleConfigScript._runes_for_health(30)
	_assert(runes_30.size() == 5, "30 hp should have 5 runes, got %d" % runes_30.size())

	var runes_20: Array = PuzzleConfigScript._runes_for_health(20)
	_assert(runes_20.size() == 4, "20 hp should have 4 runes (20,15,10,5), got %d" % runes_20.size())
	_assert(runes_20[0] == 20, "first rune at 20 hp should be 20, got %d" % runes_20[0])

	var runes_4: Array = PuzzleConfigScript._runes_for_health(4)
	_assert(runes_4.size() == 0, "4 hp should have 0 runes, got %d" % runes_4.size())

	var runes_5: Array = PuzzleConfigScript._runes_for_health(5)
	_assert(runes_5.size() == 1, "5 hp should have 1 rune, got %d" % runes_5.size())


func _test_build_with_creatures() -> void:
	var config := _minimal_config()
	config["player"]["field_creatures"] = [
		"afflicted_alit",
		{"definition_id": "fifth_legion_trainer", "power_bonus": 2, "can_attack": false},
	]
	config["enemy"]["shadow_creatures"] = ["mudcrab_anklesnapper"]
	var state: Dictionary = PuzzleConfigScript.build_puzzle_match_state(config)
	var lanes: Array = state.get("lanes", [])
	_assert(lanes.size() == 2, "should have 2 lanes")

	var field_p1: Array = lanes[0].get("player_slots", {}).get("player_1", [])
	_assert(field_p1.size() == 2, "player should have 2 field creatures, got %d" % field_p1.size())
	_assert(field_p1[0].get("definition_id") == "afflicted_alit", "first creature should be afflicted_alit")
	_assert(field_p1[1].get("power_bonus") == 2, "second creature should have power_bonus 2")
	_assert(field_p1[1].get("can_attack") == false, "second creature should not be able to attack")

	var shadow_p2: Array = lanes[1].get("player_slots", {}).get("player_2", [])
	_assert(shadow_p2.size() == 1, "enemy should have 1 shadow creature, got %d" % shadow_p2.size())


func _test_build_with_ring() -> void:
	var config := _minimal_config()
	config["player"]["has_ring"] = true
	var state: Dictionary = PuzzleConfigScript.build_puzzle_match_state(config)
	var players: Array = state.get("players", [])
	var p1: Dictionary = players[0]
	_assert(p1.get("has_ring_of_magicka") == true, "player should have ring")
	_assert(p1.get("ring_of_magicka_charges") == 3, "player should have 3 ring charges")
	var p2: Dictionary = players[1]
	_assert(p2.get("has_ring_of_magicka") == false, "enemy should not have ring")


func _test_build_with_supports() -> void:
	var config := _minimal_config()
	config["player"]["supports"] = ["divine_fervor"]
	config["enemy"]["supports"] = ["mundus_stone"]
	var state: Dictionary = PuzzleConfigScript.build_puzzle_match_state(config)
	var players: Array = state.get("players", [])
	_assert(players[0].get("support", []).size() == 1, "player should have 1 support")
	_assert(players[0]["support"][0].get("definition_id") == "divine_fervor", "player support should be divine_fervor")
	_assert(players[1].get("support", []).size() == 1, "enemy should have 1 support")


func _test_build_with_hand_and_deck() -> void:
	var config := _minimal_config()
	config["player"]["hand"] = ["firebolt", "lightning_bolt"]
	config["player"]["deck"] = ["execute", "javelin"]
	config["player"]["discard"] = ["healing_potion"]
	var state: Dictionary = PuzzleConfigScript.build_puzzle_match_state(config)
	var p1: Dictionary = state.get("players", [])[0]
	_assert(p1.get("hand", []).size() == 2, "player hand should have 2 cards")
	_assert(p1.get("deck", []).size() == 2, "player deck should have 2 cards")
	_assert(p1.get("discard", []).size() == 1, "player discard should have 1 card")
	# Deck order: index 0 in config drawn first = last in internal array (pop_back)
	_assert(p1["deck"][1].get("definition_id") == "execute", "deck bottom (last pop) = first in config")
	_assert(p1["deck"][0].get("definition_id") == "javelin", "deck top (first pop) = last in config")


# -- Codec Tests --

func _test_codec_round_trip() -> void:
	var config := _minimal_config()
	var encoded: String = PuzzleCodecScript.encode(config)
	_assert(not encoded.is_empty(), "encoded string should not be empty")
	var decoded: Dictionary = PuzzleCodecScript.decode(encoded)
	_assert(decoded.get("error") == "", "decode should not error, got: '%s'" % decoded.get("error", ""))
	var rt_config: Dictionary = decoded.get("config", {})
	_assert(str(rt_config.get("name")) == str(config.get("name")), "round-trip name should match")
	_assert(str(rt_config.get("type")) == str(config.get("type")), "round-trip type should match")


func _test_codec_raw_prefix() -> void:
	# Small configs should use raw JSON (shorter than base64)
	var config := {"name": "X", "type": "kill"}
	var encoded: String = PuzzleCodecScript.encode(config)
	_assert(encoded.begins_with("PZ:"), "small config should use raw prefix, got: '%s'" % encoded.substr(0, 4))


func _test_codec_decode_invalid_prefix() -> void:
	var result: Dictionary = PuzzleCodecScript.decode("INVALID_CODE")
	_assert(result.get("error") != "", "invalid prefix should return error")


func _test_codec_decode_bad_json() -> void:
	var result: Dictionary = PuzzleCodecScript.decode("PZ:{not valid json")
	_assert(result.get("error") != "", "bad json should return error")


# -- Persistence Tests --

func _test_persistence_add_and_list() -> void:
	# Clear any existing data first
	var empty_data := {"puzzles": []}
	PuzzlePersistenceScript.save_data(empty_data)

	var id: String = PuzzlePersistenceScript.add_puzzle("Test Puzzle", "PZ:{}")
	_assert(not id.is_empty(), "add_puzzle should return an id")

	var puzzles: Array = PuzzlePersistenceScript.list_puzzles()
	_assert(puzzles.size() == 1, "should have 1 puzzle after add, got %d" % puzzles.size())
	_assert(str(puzzles[0].get("name")) == "Test Puzzle", "puzzle name should match")
	_assert(puzzles[0].get("solved") == false, "new puzzle should not be solved")

	# Cleanup
	PuzzlePersistenceScript.save_data(empty_data)


func _test_persistence_delete() -> void:
	var empty_data := {"puzzles": []}
	PuzzlePersistenceScript.save_data(empty_data)

	var id: String = PuzzlePersistenceScript.add_puzzle("To Delete", "PZ:{}")
	PuzzlePersistenceScript.delete_puzzle(id)
	var puzzles: Array = PuzzlePersistenceScript.list_puzzles()
	_assert(puzzles.size() == 0, "should have 0 puzzles after delete, got %d" % puzzles.size())


func _test_persistence_mark_solved() -> void:
	var empty_data := {"puzzles": []}
	PuzzlePersistenceScript.save_data(empty_data)

	var id: String = PuzzlePersistenceScript.add_puzzle("Solve Me", "PZ:{}")
	_assert(PuzzlePersistenceScript.is_solved(id) == false, "should not be solved initially")
	PuzzlePersistenceScript.mark_solved(id)
	_assert(PuzzlePersistenceScript.is_solved(id) == true, "should be solved after mark_solved")

	# Cleanup
	PuzzlePersistenceScript.save_data(empty_data)


# -- Helpers --

func _minimal_config() -> Dictionary:
	return {
		"name": "Test Puzzle",
		"type": "kill",
		"lanes": [
			{"lane_type": "field", "width": 4},
			{"lane_type": "shadow", "width": 4},
		],
		"player": {
			"health": 30,
			"max_magicka": 12,
			"current_magicka": 12,
			"has_ring": false,
			"hand": [],
			"deck": [],
			"discard": [],
			"supports": [],
			"field_creatures": [],
			"shadow_creatures": [],
		},
		"enemy": {
			"health": 30,
			"max_magicka": 3,
			"current_magicka": 3,
			"hand": [],
			"deck": [],
			"discard": [],
			"supports": [],
			"field_creatures": [],
			"shadow_creatures": [],
		},
	}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
