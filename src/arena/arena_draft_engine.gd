class_name ArenaDraftEngine
extends RefCounted

const CardSynergyExtractor = preload("res://src/deck/card_synergy_extractor.gd")

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


static func draft_ai_deck(attribute_ids: Array, card_database: Dictionary, deck_size: int, quality: float) -> Array:
	var pool: Array = get_card_pool(attribute_ids, card_database)
	var current_deck: Array = []

	for pick_num in range(deck_size):
		var rarity: String = roll_rarity()
		var options: Array = get_pick_options(rarity, pool, current_deck, 3)
		if options.is_empty():
			break

		var chosen: Dictionary
		if quality <= 0.0:
			chosen = options[randi() % options.size()]
		else:
			chosen = _ai_pick_best(options, current_deck, quality, pool)

		var found := false
		for entry in current_deck:
			if entry["card_id"] == chosen["card_id"]:
				entry["quantity"] += 1
				found = true
				break
		if not found:
			current_deck.append({"card_id": chosen["card_id"], "quantity": 1})

	return current_deck


static func _ai_pick_best(options: Array, current_deck: Array, quality: float, card_pool: Array) -> Dictionary:
	var best_card: Dictionary = options[0]
	var best_score := -999.0

	var deck_cost_counts := _count_deck_by_cost(current_deck, card_pool)
	var deck_keywords := _collect_deck_keywords(current_deck, card_pool)
	var deck_subtypes := _collect_deck_subtypes(current_deck, card_pool)
	var deck_synergy_subtypes := _collect_deck_synergy_subtypes(current_deck, card_pool)

	for card in options:
		var random_score: float = randf()
		var eval_score: float = _evaluate_card(card, deck_cost_counts, deck_keywords, deck_subtypes, deck_synergy_subtypes)
		var score: float = lerpf(random_score, eval_score, quality)
		if score > best_score:
			best_score = score
			best_card = card

	return best_card


static func _evaluate_card(card: Dictionary, deck_cost_counts: Dictionary, deck_keywords: Dictionary, deck_subtypes: Dictionary, deck_synergy_subtypes: Dictionary) -> float:
	var score := 0.0
	var card_type: String = card.get("card_type", "")
	var cost: int = card.get("cost", 0)

	# Stats-for-cost ratio (creatures and items)
	if card_type == "creature":
		var power: int = card.get("base_power", 0)
		var health: int = card.get("base_health", 0)
		var total_stats: float = float(power + health)
		var expected_stats: float = float(cost) * 2.0 + 1.0
		if expected_stats > 0.0:
			score += (total_stats / expected_stats) * 0.4
		else:
			score += total_stats * 0.2

	# Keyword value
	var keywords: Array = card.get("keywords", [])
	for kw in keywords:
		match kw:
			"guard":
				score += 0.15
			"ward":
				score += 0.12
			"drain":
				score += 0.10
			"breakthrough":
				score += 0.06
			"lethal":
				score += 0.10
			"charge":
				score += 0.08
			"regenerate":
				score += 0.07
			_:
				score += 0.03

	# Curve awareness - penalise cost slots that are over-represented
	var cost_key := mini(cost, 7)
	var count_at_cost: int = deck_cost_counts.get(cost_key, 0)
	if count_at_cost > 5:
		score -= float(count_at_cost - 5) * 0.08

	# Synergy - shared subtypes
	var subtypes: Array = card.get("subtypes", [])
	for st in subtypes:
		var st_lower := str(st).to_lower()
		if st_lower in deck_subtypes:
			score += 0.05 * minf(float(deck_subtypes[st_lower]), 3.0)

	# Synergy - shared keywords
	for kw in keywords:
		if kw in deck_keywords:
			score += 0.03 * minf(float(deck_keywords[kw]), 3.0)

	# Deep synergy - card's subtypes enable synergy cards already in deck
	# e.g. picking a Dragon when deck has Midnight Snack (cares about Dragons)
	for st in subtypes:
		var st_lower := str(st).to_lower()
		if st_lower in deck_synergy_subtypes:
			score += 0.12 * minf(float(deck_synergy_subtypes[st_lower]), 3.0)

	# Deep synergy - card's synergy signals match subtypes already in deck
	# e.g. picking Midnight Snack when deck has 3 Dragons
	var card_synergy_subs: Array = CardSynergyExtractor.extract_synergy_subtypes(card)
	for syn_st in card_synergy_subs:
		if syn_st in deck_subtypes:
			score += 0.10 * minf(float(deck_subtypes[syn_st]), 2.0)

	# Slight preference for creatures (they form the deck backbone)
	if card_type == "creature":
		score += 0.05

	return score


static func _count_deck_by_cost(current_deck: Array, all_cards_context: Array) -> Dictionary:
	var counts := {}
	for entry in current_deck:
		var cost_key := 0
		# We need to find the card cost - check the first option as a reference database
		for opt in all_cards_context:
			if opt.get("card_id", "") == entry.get("card_id", ""):
				cost_key = mini(opt.get("cost", 0), 7)
				break
		var qty: int = entry.get("quantity", 1)
		counts[cost_key] = counts.get(cost_key, 0) + qty
	return counts


static func _collect_deck_keywords(current_deck: Array, all_cards_context: Array) -> Dictionary:
	var kw_counts := {}
	for entry in current_deck:
		for opt in all_cards_context:
			if opt.get("card_id", "") == entry.get("card_id", ""):
				for kw in opt.get("keywords", []):
					var qty: int = entry.get("quantity", 1)
					kw_counts[kw] = kw_counts.get(kw, 0) + qty
				break
	return kw_counts


static func _collect_deck_subtypes(current_deck: Array, all_cards_context: Array) -> Dictionary:
	var st_counts := {}
	for entry in current_deck:
		for opt in all_cards_context:
			if opt.get("card_id", "") == entry.get("card_id", ""):
				for st in opt.get("subtypes", []):
					var st_lower := str(st).to_lower()
					var qty: int = entry.get("quantity", 1)
					st_counts[st_lower] = st_counts.get(st_lower, 0) + qty
				break
	return st_counts


static func _collect_deck_synergy_subtypes(current_deck: Array, all_cards_context: Array) -> Dictionary:
	var syn_counts := {}
	for entry in current_deck:
		for opt in all_cards_context:
			if opt.get("card_id", "") == entry.get("card_id", ""):
				var synergy_subs: Array = CardSynergyExtractor.extract_synergy_subtypes(opt)
				var qty: int = entry.get("quantity", 1)
				for syn_st in synergy_subs:
					syn_counts[syn_st] = syn_counts.get(syn_st, 0) + qty
				break
	return syn_counts


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
