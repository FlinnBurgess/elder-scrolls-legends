class_name AdventureCardPool
extends RefCounted

const CardCatalogScript = preload("res://src/deck/card_catalog.gd")

const SHOP_PRICES := {
	"common": 20,
	"rare": 40,
	"epic": 70,
	"legendary": 120,
}

static var _cached_catalog: Dictionary = {}


static func get_random_cards(attribute_ids: Array, count: int) -> Array:
	var pool := _get_attribute_pool(attribute_ids)
	if pool.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var result: Array = []
	var available := pool.duplicate()
	for _i in range(mini(count, available.size())):
		var idx := rng.randi_range(0, available.size() - 1)
		result.append(available[idx])
		available.remove_at(idx)
	return result


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
