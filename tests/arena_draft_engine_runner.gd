extends SceneTree

const ArenaDraftEngineScript := preload("res://src/arena/arena_draft_engine.gd")
const CardCatalogScript := preload("res://src/deck/card_catalog.gd")

var _failures: Array[String] = []
var _card_database: Dictionary = {}
var _all_cards: Array = []


func _initialize() -> void:
	var catalog: Dictionary = CardCatalogScript.load_default()
	_card_database = catalog.get("card_by_id", {})
	_all_cards = catalog.get("cards", [])

	_test_roll_rarity_produces_valid_strings()
	_test_get_card_pool_matches_attributes_plus_neutral()
	_test_get_card_pool_excludes_non_collectible()
	_test_get_pick_options_returns_correct_count()
	_test_get_pick_options_respects_copy_limits()
	_test_draft_ai_deck_returns_requested_size()
	_test_draft_ai_deck_quality_1_has_reasonable_curve()

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ARENA_DRAFT_ENGINE_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_roll_rarity_produces_valid_strings() -> void:
	var valid_rarities := ["common", "rare", "epic", "legendary"]
	for i in range(200):
		var rarity: String = ArenaDraftEngineScript.roll_rarity()
		_assert(rarity in valid_rarities, "roll_rarity: got invalid rarity '%s'" % rarity)


func _test_get_card_pool_matches_attributes_plus_neutral() -> void:
	var attribute_ids := ["strength", "intelligence"]
	var pool: Array = ArenaDraftEngineScript.get_card_pool(attribute_ids, _card_database)

	_assert(pool.size() > 0, "get_card_pool: pool should not be empty for strength+intelligence")

	for card in pool:
		var card_attrs: Array = card.get("attributes", [])
		if card_attrs.is_empty():
			# Neutral card — always allowed
			continue
		var has_match := false
		for attr in card_attrs:
			if attr in attribute_ids:
				has_match = true
				break
		_assert(has_match, "get_card_pool: card '%s' has attrs %s which don't match %s" % [card.get("card_id", ""), str(card_attrs), str(attribute_ids)])

	# Verify neutral cards are present
	var has_neutral := false
	for card in pool:
		if card.get("attributes", []).is_empty():
			has_neutral = true
			break
	_assert(has_neutral, "get_card_pool: pool should contain neutral cards")


func _test_get_card_pool_excludes_non_collectible() -> void:
	# Build a small database with a non-collectible card
	var test_db := {
		"c1": {"card_id": "c1", "attributes": ["strength"], "collectible": true, "rarity": "common"},
		"c2": {"card_id": "c2", "attributes": ["strength"], "collectible": false, "rarity": "common"},
		"c3": {"card_id": "c3", "attributes": [], "collectible": true, "rarity": "common"},
	}
	var pool: Array = ArenaDraftEngineScript.get_card_pool(["strength"], test_db)

	var pool_ids: Array = []
	for card in pool:
		pool_ids.append(card.get("card_id", ""))

	_assert("c1" in pool_ids, "get_card_pool: collectible strength card should be in pool")
	_assert("c2" not in pool_ids, "get_card_pool: non-collectible card should be excluded")
	_assert("c3" in pool_ids, "get_card_pool: collectible neutral card should be in pool")


func _test_get_pick_options_returns_correct_count() -> void:
	var pool: Array = ArenaDraftEngineScript.get_card_pool(["strength", "intelligence"], _card_database)
	var options: Array = ArenaDraftEngineScript.get_pick_options("common", pool, [], 3)
	_assert(options.size() == 3, "get_pick_options: expected 3 options, got %d" % options.size())

	# Verify they are distinct cards
	var ids := {}
	for card in options:
		var cid: String = card.get("card_id", "")
		_assert(cid not in ids, "get_pick_options: duplicate card '%s' in options" % cid)
		ids[cid] = true


func _test_get_pick_options_respects_copy_limits() -> void:
	# Create a pool with one unique and one regular card, both common
	var test_pool := [
		{"card_id": "unique_card", "rarity": "common", "is_unique": true, "attributes": ["strength"], "collectible": true},
		{"card_id": "regular_card", "rarity": "common", "is_unique": false, "attributes": ["strength"], "collectible": true},
		{"card_id": "filler_a", "rarity": "common", "is_unique": false, "attributes": ["strength"], "collectible": true},
		{"card_id": "filler_b", "rarity": "common", "is_unique": false, "attributes": ["strength"], "collectible": true},
	]

	# Unique card already at 1 copy — should be excluded
	var deck_with_unique := [{"card_id": "unique_card", "quantity": 1}]
	var options: Array = ArenaDraftEngineScript.get_pick_options("common", test_pool, deck_with_unique, 3)
	var option_ids: Array = []
	for card in options:
		option_ids.append(card.get("card_id", ""))
	_assert("unique_card" not in option_ids, "get_pick_options: unique card at max copies should be excluded")

	# Regular card at 3 copies — should be excluded
	var deck_with_regular := [{"card_id": "regular_card", "quantity": 3}]
	options = ArenaDraftEngineScript.get_pick_options("common", test_pool, deck_with_regular, 3)
	option_ids = []
	for card in options:
		option_ids.append(card.get("card_id", ""))
	_assert("regular_card" not in option_ids, "get_pick_options: regular card at 3 copies should be excluded")

	# Regular card at 2 copies — should still be available
	var deck_with_two := [{"card_id": "regular_card", "quantity": 2}]
	options = ArenaDraftEngineScript.get_pick_options("common", test_pool, deck_with_two, 3)
	option_ids = []
	for card in options:
		option_ids.append(card.get("card_id", ""))
	_assert("regular_card" in option_ids, "get_pick_options: regular card at 2 copies should still be available")


func _test_draft_ai_deck_returns_requested_size() -> void:
	var deck_size := 30
	var deck: Array = ArenaDraftEngineScript.draft_ai_deck(["strength", "intelligence"], _card_database, deck_size, 0.5)

	var total_cards := 0
	for entry in deck:
		total_cards += entry.get("quantity", 1)

	_assert(total_cards == deck_size, "draft_ai_deck: expected %d total cards, got %d" % [deck_size, total_cards])

	# Verify deck structure
	for entry in deck:
		_assert(entry.has("card_id"), "draft_ai_deck: entry missing 'card_id'")
		_assert(entry.has("quantity"), "draft_ai_deck: entry missing 'quantity'")
		var qty: int = entry.get("quantity", 0)
		_assert(qty >= 1 and qty <= 3, "draft_ai_deck: invalid quantity %d for card '%s'" % [qty, entry.get("card_id", "")])


func _test_draft_ai_deck_quality_1_has_reasonable_curve() -> void:
	var deck: Array = ArenaDraftEngineScript.draft_ai_deck(["strength", "intelligence"], _card_database, 30, 1.0)

	# Count cards at each cost bucket
	var cost_buckets := {}
	for entry in deck:
		var cid: String = entry.get("card_id", "")
		var card: Dictionary = _card_database.get(cid, {})
		var cost: int = card.get("cost", 0)
		var bucket: int = mini(cost, 7)
		var qty: int = entry.get("quantity", 1)
		cost_buckets[bucket] = cost_buckets.get(bucket, 0) + qty

	# At quality 1.0 with curve awareness, no single cost bucket should have more
	# than 60% of the deck (i.e., cards should be somewhat spread out)
	var max_at_any_cost := 0
	for bucket in cost_buckets:
		var count: int = cost_buckets[bucket]
		if count > max_at_any_cost:
			max_at_any_cost = count

	_assert(max_at_any_cost < 18, "draft_ai_deck quality=1.0: worst cost bucket has %d/30 cards, expected < 18 for reasonable curve" % max_at_any_cost)

	# Should use at least 3 different cost buckets
	_assert(cost_buckets.size() >= 3, "draft_ai_deck quality=1.0: only %d cost buckets used, expected >= 3" % cost_buckets.size())


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
