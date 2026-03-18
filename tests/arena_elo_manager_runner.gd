extends SceneTree

const ArenaEloManagerScript := preload("res://src/arena/arena_elo_manager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_cleanup_test_files()

	_test_default_elo()
	_test_save_load_round_trip()
	_test_update_elo_increases_for_high_wins()
	_test_update_elo_decreases_for_low_wins()
	_test_elo_clamped_at_bounds()
	_test_get_opponent_difficulties_returns_8_ascending()
	_test_difficulties_at_1200_distribution()
	_test_higher_elo_produces_higher_difficulty()

	_cleanup_test_files()

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ARENA_ELO_MANAGER_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_default_elo() -> void:
	_cleanup_test_files()
	var elo: int = ArenaEloManagerScript.get_elo()
	_assert(elo == 1200, "default_elo: should be 1200 when no file exists, got %d" % elo)


func _test_save_load_round_trip() -> void:
	_cleanup_test_files()
	ArenaEloManagerScript.save_elo(1500)
	var loaded: int = ArenaEloManagerScript.get_elo()
	_assert(loaded == 1500, "save_load: should be 1500, got %d" % loaded)
	_cleanup_test_files()


func _test_update_elo_increases_for_high_wins() -> void:
	# 7+ wins should increase Elo
	var new_elo: int = ArenaEloManagerScript.update_elo_after_run(1200, 7)
	_assert(new_elo > 1200, "high_wins: 7 wins from 1200 should increase Elo, got %d" % new_elo)

	var new_elo_9: int = ArenaEloManagerScript.update_elo_after_run(1200, 9)
	_assert(new_elo_9 > new_elo, "high_wins: 9 wins should increase more than 7 wins, got %d vs %d" % [new_elo_9, new_elo])


func _test_update_elo_decreases_for_low_wins() -> void:
	# 0-2 wins should decrease Elo
	var new_elo_0: int = ArenaEloManagerScript.update_elo_after_run(1200, 0)
	_assert(new_elo_0 < 1200, "low_wins: 0 wins from 1200 should decrease Elo, got %d" % new_elo_0)

	var new_elo_2: int = ArenaEloManagerScript.update_elo_after_run(1200, 2)
	_assert(new_elo_2 < 1200, "low_wins: 2 wins from 1200 should decrease Elo, got %d" % new_elo_2)


func _test_elo_clamped_at_bounds() -> void:
	# Clamp at minimum 800
	var min_elo: int = ArenaEloManagerScript.update_elo_after_run(810, 0)
	_assert(min_elo >= 800, "clamp_min: Elo should not go below 800, got %d" % min_elo)

	# Clamp at maximum 2000
	var max_elo: int = ArenaEloManagerScript.update_elo_after_run(1990, 9)
	_assert(max_elo <= 2000, "clamp_max: Elo should not go above 2000, got %d" % max_elo)

	# save_elo also clamps
	ArenaEloManagerScript.save_elo(5000)
	var saved_max: int = ArenaEloManagerScript.get_elo()
	_assert(saved_max == 2000, "clamp_save: saving 5000 should be clamped to 2000, got %d" % saved_max)

	ArenaEloManagerScript.save_elo(100)
	var saved_min: int = ArenaEloManagerScript.get_elo()
	_assert(saved_min == 800, "clamp_save: saving 100 should be clamped to 800, got %d" % saved_min)

	_cleanup_test_files()


func _test_get_opponent_difficulties_returns_8_ascending() -> void:
	var difficulties: Array = ArenaEloManagerScript.get_opponent_difficulties(1200)
	_assert(difficulties.size() == 8, "ascending: should return 8 values, got %d" % difficulties.size())

	# Check ascending order
	for i in range(1, difficulties.size()):
		_assert(difficulties[i] >= difficulties[i - 1], "ascending: value at index %d (%.2f) should be >= index %d (%.2f)" % [i, difficulties[i], i - 1, difficulties[i - 1]])

	# All values in 0.0-1.0 range
	for i in range(difficulties.size()):
		var val: float = difficulties[i]
		_assert(val >= 0.0 and val <= 1.0, "ascending: value at index %d should be 0.0-1.0, got %.2f" % [i, val])


func _test_difficulties_at_1200_distribution() -> void:
	# Run multiple times to check distribution
	var total_weak := 0
	var total_avg := 0
	var total_strong := 0
	var runs := 50

	for _r in range(runs):
		var difficulties: Array = ArenaEloManagerScript.get_opponent_difficulties(1200)
		for val in difficulties:
			var fval: float = val
			if fval < 0.35:
				total_weak += 1
			elif fval < 0.65:
				total_avg += 1
			else:
				total_strong += 1

	# At Elo 1200, expect roughly: 1 weak, 5 average, 2 strong per run (out of 8)
	# Over 50 runs: ~50 weak, ~250 average, ~100 strong (total 400)
	var avg_weak: float = float(total_weak) / runs
	var avg_avg: float = float(total_avg) / runs
	var avg_strong: float = float(total_strong) / runs

	# Generous bounds to avoid flakiness
	_assert(avg_weak >= 0.5 and avg_weak <= 4.0, "dist_1200: expected ~1 weak per run, got avg %.1f" % avg_weak)
	_assert(avg_avg >= 2.0 and avg_avg <= 7.0, "dist_1200: expected ~5 avg per run, got avg %.1f" % avg_avg)
	_assert(avg_strong >= 0.5 and avg_strong <= 5.0, "dist_1200: expected ~2 strong per run, got avg %.1f" % avg_strong)


func _test_higher_elo_produces_higher_difficulty() -> void:
	# Compare average difficulty at low vs high Elo
	var low_total := 0.0
	var high_total := 0.0
	var runs := 50

	for _r in range(runs):
		var low_diffs: Array = ArenaEloManagerScript.get_opponent_difficulties(900)
		var high_diffs: Array = ArenaEloManagerScript.get_opponent_difficulties(1800)
		for val in low_diffs:
			low_total += val
		for val in high_diffs:
			high_total += val

	var low_avg: float = low_total / (runs * 8)
	var high_avg: float = high_total / (runs * 8)

	_assert(high_avg > low_avg, "higher_elo: Elo 1800 avg difficulty (%.3f) should be higher than Elo 900 (%.3f)" % [high_avg, low_avg])


func _cleanup_test_files() -> void:
	if FileAccess.file_exists("user://arena/elo.dat"):
		var dir := DirAccess.open("user://arena/")
		if dir != null:
			dir.remove("elo.dat")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
