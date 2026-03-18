class_name ArenaDraftEngine
extends RefCounted


const RARITY_WEIGHTS := {
	"common": 60.0,
	"rare": 25.0,
	"epic": 10.0,
	"legendary": 2.2,
}

const RARITY_FALLBACK_ORDER := ["legendary", "epic", "rare", "common"]


static func roll_rarity() -> String:
	var total := 0.0
	for w in RARITY_WEIGHTS.values():
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	for rarity in RARITY_WEIGHTS:
		cumulative += RARITY_WEIGHTS[rarity]
		if roll < cumulative:
			return rarity
	return "common"


static func get_card_pool(attribute_ids: Array, card_database: Dictionary) -> Array:
	var pool: Array = []
	for card in card_database.values():
		if not card.get("collectible", false):
			continue
		var card_attrs: Array = card.get("attributes", [])
		if card_attrs.is_empty():
			pool.append(card)
			continue
		var matches := false
		for attr in card_attrs:
			if attr in attribute_ids:
				matches = true
				break
		if matches:
			pool.append(card)
	return pool


static func get_pick_options(rarity: String, card_pool: Array, current_deck: Array, count: int) -> Array:
	var deck_counts := _count_deck_cards(current_deck)
	var rarity_index := RARITY_FALLBACK_ORDER.find(rarity)
	if rarity_index == -1:
		rarity_index = RARITY_FALLBACK_ORDER.size() - 1

	var options: Array = []
	var used_ids := {}

	for r_idx in range(rarity_index, RARITY_FALLBACK_ORDER.size()):
		if options.size() >= count:
			break
		var target_rarity: String = RARITY_FALLBACK_ORDER[r_idx]
		var candidates: Array = _get_available_candidates(target_rarity, card_pool, deck_counts, used_ids)
		candidates.shuffle()
		for card in candidates:
			if options.size() >= count:
				break
			options.append(card)
			used_ids[card.get("card_id", "")] = true

	return options


static func _count_deck_cards(current_deck: Array) -> Dictionary:
	var counts := {}
	for entry in current_deck:
		var cid: String = ""
		if entry is Dictionary:
			cid = entry.get("card_id", "")
		else:
			cid = str(entry)
		counts[cid] = counts.get(cid, 0) + entry.get("quantity", 1)
	return counts


static func _get_available_candidates(rarity: String, card_pool: Array, deck_counts: Dictionary, used_ids: Dictionary) -> Array:
	var candidates: Array = []
	for card in card_pool:
		var card_id: String = card.get("card_id", "")
		if card_id in used_ids:
			continue
		if card.get("rarity", "") != rarity:
			continue
		var is_unique: bool = card.get("is_unique", false)
		var max_copies := 1 if is_unique else 3
		var current_copies: int = deck_counts.get(card_id, 0)
		if current_copies >= max_copies:
			continue
		candidates.append(card)
	return candidates
