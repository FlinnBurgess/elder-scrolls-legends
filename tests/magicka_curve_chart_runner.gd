extends SceneTree

const MagickaCurveChartScript := preload("res://src/ui/components/magicka_curve_chart.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_empty_deck()
	_test_single_card_cost_3()
	_test_high_costs_bucket_into_7_plus()
	_test_multiple_cards_with_quantities()
	_test_realistic_deck()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("MAGICKA_CURVE_CHART_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_empty_deck() -> void:
	var definition := {"cards": []}
	var card_by_id := {}
	var buckets: Array[int] = MagickaCurveChartScript.compute_buckets(definition, card_by_id)

	_assert(buckets.size() == 8, "Empty: expected 8 buckets, got %d" % buckets.size())
	for i in 8:
		_assert(buckets[i] == 0, "Empty: bucket %d should be 0, got %d" % [i, buckets[i]])


func _test_single_card_cost_3() -> void:
	var definition := {"cards": [{"card_id": "card_a", "quantity": 1}]}
	var card_by_id := {"card_a": {"cost": 3}}
	var buckets: Array[int] = MagickaCurveChartScript.compute_buckets(definition, card_by_id)

	_assert(buckets[3] == 1, "SingleCost3: bucket 3 should be 1, got %d" % buckets[3])
	for i in 8:
		if i != 3:
			_assert(buckets[i] == 0, "SingleCost3: bucket %d should be 0, got %d" % [i, buckets[i]])


func _test_high_costs_bucket_into_7_plus() -> void:
	var definition := {"cards": [
		{"card_id": "c7", "quantity": 1},
		{"card_id": "c8", "quantity": 1},
		{"card_id": "c9", "quantity": 1},
		{"card_id": "c10", "quantity": 1},
	]}
	var card_by_id := {
		"c7": {"cost": 7},
		"c8": {"cost": 8},
		"c9": {"cost": 9},
		"c10": {"cost": 10},
	}
	var buckets: Array[int] = MagickaCurveChartScript.compute_buckets(definition, card_by_id)

	_assert(buckets[7] == 4, "HighCost: bucket 7+ should be 4, got %d" % buckets[7])
	for i in 7:
		_assert(buckets[i] == 0, "HighCost: bucket %d should be 0, got %d" % [i, buckets[i]])


func _test_multiple_cards_with_quantities() -> void:
	var definition := {"cards": [
		{"card_id": "card_a", "quantity": 3},
		{"card_id": "card_b", "quantity": 2},
		{"card_id": "card_c", "quantity": 1},
	]}
	var card_by_id := {
		"card_a": {"cost": 2},
		"card_b": {"cost": 2},
		"card_c": {"cost": 5},
	}
	var buckets: Array[int] = MagickaCurveChartScript.compute_buckets(definition, card_by_id)

	_assert(buckets[2] == 5, "Quantities: bucket 2 should be 5 (3+2), got %d" % buckets[2])
	_assert(buckets[5] == 1, "Quantities: bucket 5 should be 1, got %d" % buckets[5])
	for i in 8:
		if i != 2 and i != 5:
			_assert(buckets[i] == 0, "Quantities: bucket %d should be 0, got %d" % [i, buckets[i]])


func _test_realistic_deck() -> void:
	# A small deck with mixed costs
	var definition := {"cards": [
		{"card_id": "c0", "quantity": 2},
		{"card_id": "c1a", "quantity": 3},
		{"card_id": "c1b", "quantity": 2},
		{"card_id": "c2", "quantity": 3},
		{"card_id": "c3", "quantity": 3},
		{"card_id": "c4", "quantity": 2},
		{"card_id": "c5", "quantity": 2},
		{"card_id": "c6", "quantity": 1},
		{"card_id": "c7", "quantity": 1},
		{"card_id": "c12", "quantity": 1},
	]}
	var card_by_id := {
		"c0": {"cost": 0},
		"c1a": {"cost": 1},
		"c1b": {"cost": 1},
		"c2": {"cost": 2},
		"c3": {"cost": 3},
		"c4": {"cost": 4},
		"c5": {"cost": 5},
		"c6": {"cost": 6},
		"c7": {"cost": 7},
		"c12": {"cost": 12},
	}
	var buckets: Array[int] = MagickaCurveChartScript.compute_buckets(definition, card_by_id)

	_assert(buckets[0] == 2, "Realistic: bucket 0 should be 2, got %d" % buckets[0])
	_assert(buckets[1] == 5, "Realistic: bucket 1 should be 5 (3+2), got %d" % buckets[1])
	_assert(buckets[2] == 3, "Realistic: bucket 2 should be 3, got %d" % buckets[2])
	_assert(buckets[3] == 3, "Realistic: bucket 3 should be 3, got %d" % buckets[3])
	_assert(buckets[4] == 2, "Realistic: bucket 4 should be 2, got %d" % buckets[4])
	_assert(buckets[5] == 2, "Realistic: bucket 5 should be 2, got %d" % buckets[5])
	_assert(buckets[6] == 1, "Realistic: bucket 6 should be 1, got %d" % buckets[6])
	_assert(buckets[7] == 2, "Realistic: bucket 7+ should be 2 (1+1), got %d" % buckets[7])


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
