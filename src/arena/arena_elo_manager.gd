class_name ArenaEloManager
extends RefCounted


const ELO_DIR := "user://arena/"
const ELO_PATH := "user://arena/elo.dat"
const DEFAULT_ELO := 1200
const MIN_ELO := 800
const MAX_ELO := 2000


static func get_elo() -> int:
	if not FileAccess.file_exists(ELO_PATH):
		return DEFAULT_ELO
	var file := FileAccess.open(ELO_PATH, FileAccess.READ)
	if file == null:
		push_error("ArenaEloManager: failed to open '%s' for reading: %s" % [ELO_PATH, FileAccess.get_open_error()])
		return DEFAULT_ELO
	var text := file.get_as_text().strip_edges()
	if not text.is_valid_int():
		return DEFAULT_ELO
	return clampi(int(text), MIN_ELO, MAX_ELO)


static func save_elo(elo: int) -> void:
	_ensure_directory()
	var clamped := clampi(elo, MIN_ELO, MAX_ELO)
	var file := FileAccess.open(ELO_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ArenaEloManager: failed to open '%s' for writing: %s" % [ELO_PATH, FileAccess.get_open_error()])
		return
	file.store_string(str(clamped))


static func update_elo_after_run(current_elo: int, total_wins: int) -> int:
	# Expected wins at current skill level is ~4.5 (middle of 0-9 range)
	# Gain Elo for above-average runs, lose for below-average
	var expected_wins := 4.5
	var win_diff: float = total_wins - expected_wins
	# K-factor of 32 is standard for newer players; scale by win difference
	var k_factor := 32.0
	var delta := int(round(k_factor * win_diff / expected_wins))
	var new_elo := clampi(current_elo + delta, MIN_ELO, MAX_ELO)
	return new_elo


static func get_opponent_difficulties(elo: int) -> Array:
	# Base distribution at Elo 1200: 2 weak, 4 average, 2 strong
	# 8 opponents for matches 1-8 (match 9 is boss with fixed quality 1.0)
	var elo_factor: float = clampf(float(elo - MIN_ELO) / float(MAX_ELO - MIN_ELO), 0.0, 1.0)

	# Base quality ranges shift upward with Elo
	# At Elo 800: weak=0.1-0.2, avg=0.3-0.4, strong=0.5-0.6
	# At Elo 1200: weak=0.2-0.3, avg=0.4-0.6, strong=0.7-0.8
	# At Elo 2000: weak=0.4-0.5, avg=0.6-0.8, strong=0.85-0.95
	var base_shift: float = elo_factor * 0.25  # 0.0 at 800, ~0.08 at 1200, 0.25 at 2000

	var difficulties: Array = []

	# 1 weak opponent
	for i in range(1):
		var base_q: float = 0.1 + base_shift + randf() * 0.1
		difficulties.append(clampf(base_q, 0.0, 1.0))

	# 5 average opponents
	for i in range(5):
		var base_q: float = 0.3 + base_shift + randf() * 0.2
		difficulties.append(clampf(base_q, 0.0, 1.0))

	# 2 strong opponents
	for i in range(2):
		var base_q: float = 0.6 + base_shift + randf() * 0.1
		difficulties.append(clampf(base_q, 0.0, 1.0))

	# Sort ascending (easiest first, hardest last)
	difficulties.sort()

	return difficulties


static func _ensure_directory() -> void:
	if not DirAccess.dir_exists_absolute(ELO_DIR):
		DirAccess.make_dir_recursive_absolute(ELO_DIR)
