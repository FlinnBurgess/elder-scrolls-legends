class_name AdventureCardPool
extends RefCounted

const CardCatalogScript = preload("res://src/deck/card_catalog.gd")

const SHOP_PRICES := {
	"common": 20,
	"rare": 40,
	"epic": 70,
	"legendary": 120,
}

const RARITY_WEIGHTS := {
	"common": 0.50,
	"rare": 0.30,
	"epic": 0.15,
	"legendary": 0.05,
}

static var _cached_catalog: Dictionary = {}


static func get_random_cards(attribute_ids: Array, count: int) -> Array:
	var pool := _get_attribute_pool(attribute_ids)
	if pool.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Group cards by rarity for weighted selection.
	var by_rarity: Dictionary = {}
	for card in pool:
		var rarity: String = str(card.get("rarity", "common"))
		if not by_rarity.has(rarity):
			by_rarity[rarity] = []
		by_rarity[rarity].append(card)

	var result: Array = []
	var used_ids: Dictionary = {}
	for _i in range(count):
		var card := _pick_weighted_card(by_rarity, rng, used_ids)
		if card.is_empty():
			break
		result.append(card)
		used_ids[str(card.get("card_id", ""))] = true
	return result


static func _pick_weighted_card(by_rarity: Dictionary, rng: RandomNumberGenerator, used_ids: Dictionary) -> Dictionary:
	# Roll rarity tier, then pick a random card from that tier.
	# Retry up to 10 times if the tier is empty or all cards used.
	for _attempt in range(10):
		var roll := rng.randf()
		var cumulative := 0.0
		var chosen_rarity := "common"
		for rarity in ["legendary", "epic", "rare", "common"]:
			cumulative += RARITY_WEIGHTS.get(rarity, 0.0)
			if roll < cumulative:
				chosen_rarity = rarity
				break
		var tier_cards: Array = by_rarity.get(chosen_rarity, [])
		if tier_cards.is_empty():
			continue
		# Filter out already-selected cards.
		var available: Array = []
		for card in tier_cards:
			if not used_ids.has(str(card.get("card_id", ""))):
				available.append(card)
		if available.is_empty():
			continue
		return available[rng.randi_range(0, available.size() - 1)]
	# Fallback: pick any unused card from any rarity.
	for rarity in by_rarity:
		for card in by_rarity[rarity]:
			if not used_ids.has(str(card.get("card_id", ""))):
				return card
	return {}


static func get_price_for_card(card: Dictionary) -> int:
	var rarity: String = str(card.get("rarity", "common"))
	return SHOP_PRICES.get(rarity, 20)


static func _get_attribute_pool(attribute_ids: Array) -> Array:
	var catalog := _load_catalog()
	var all_cards: Array = catalog.get("cards", [])
	var pool: Array = []
	for card in all_cards:
		if not card.get("collectible", false):
			continue
		var card_attrs: Array = card.get("attributes", [])
		if card_attrs.is_empty():
			# Neutral cards are always available
			pool.append(card)
			continue
		for attr in card_attrs:
			if str(attr) in attribute_ids:
				pool.append(card)
				break
	return pool


static func _load_catalog() -> Dictionary:
	if not _cached_catalog.is_empty():
		return _cached_catalog
	_cached_catalog = CardCatalogScript.load_default()
	return _cached_catalog
