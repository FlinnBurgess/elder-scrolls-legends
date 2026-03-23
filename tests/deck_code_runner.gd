extends SceneTree

const DeckCodeScript := preload("res://src/deck/deck_code.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_encode_count()
	_test_decode_count()
	_test_encode_basic()
	_test_decode_basic()
	_test_wiki_example()
	_test_round_trip()
	_test_empty_deck()
	_test_all_quantity_groups()
	_test_decode_invalid_prefix()
	_test_decode_truncated()
	_test_decode_unknown_card()
	_test_encode_skips_unknown_cards()
	_test_encode_sorts_deterministically()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("DECK_CODE_OK")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_encode_count() -> void:
	_assert(DeckCodeScript._encode_count(0) == "AA", "encode_count(0) should be AA, got '%s'" % DeckCodeScript._encode_count(0))
	_assert(DeckCodeScript._encode_count(1) == "AB", "encode_count(1) should be AB, got '%s'" % DeckCodeScript._encode_count(1))
	_assert(DeckCodeScript._encode_count(26) == "BA", "encode_count(26) should be BA, got '%s'" % DeckCodeScript._encode_count(26))
	_assert(DeckCodeScript._encode_count(54) == "CC", "encode_count(54) should be CC, got '%s'" % DeckCodeScript._encode_count(54))
	_assert(DeckCodeScript._encode_count(675) == "ZZ", "encode_count(675) should be ZZ, got '%s'" % DeckCodeScript._encode_count(675))


func _test_decode_count() -> void:
	_assert(DeckCodeScript._decode_count("AA") == 0, "decode_count(AA) should be 0")
	_assert(DeckCodeScript._decode_count("AB") == 1, "decode_count(AB) should be 1")
	_assert(DeckCodeScript._decode_count("BA") == 26, "decode_count(BA) should be 26")
	_assert(DeckCodeScript._decode_count("CC") == 54, "decode_count(CC) should be 54")
	_assert(DeckCodeScript._decode_count("ZZ") == 675, "decode_count(ZZ) should be 675")
	_assert(DeckCodeScript._decode_count("a") == -1, "decode_count(a) should be -1 (invalid)")


func _test_encode_basic() -> void:
	var id_to_code := {"card_a": "aA", "card_b": "bB"}
	var deck := {"cards": [{"card_id": "card_a", "quantity": 3}, {"card_id": "card_b", "quantity": 3}]}
	var result: Dictionary = DeckCodeScript.encode(deck, id_to_code)
	_assert(result.get("error") == "", "encode basic: no error expected, got '%s'" % result.get("error", ""))
	var code: String = result.get("code", "")
	_assert(code.begins_with("SP"), "encode basic: should start with SP")
	# 0 one-ofs, 0 two-ofs, 2 three-ofs
	_assert(code == "SPAAAAACaAbB", "encode basic: expected SPAAAAACaAbB, got '%s'" % code)


func _test_decode_basic() -> void:
	var code_to_id := {"aA": "card_a", "bB": "card_b"}
	var result: Dictionary = DeckCodeScript.decode("SPAAAAACaAbB", code_to_id)
	_assert(result.get("error") == "", "decode basic: no error expected, got '%s'" % result.get("error", ""))
	var cards: Array = result.get("cards", [])
	_assert(cards.size() == 2, "decode basic: expected 2 cards, got %d" % cards.size())
	_assert(cards[0].get("card_id") == "card_a", "decode basic: first card should be card_a")
	_assert(cards[0].get("quantity") == 3, "decode basic: first card quantity should be 3")
	_assert(cards[1].get("card_id") == "card_b", "decode basic: second card should be card_b")
	_assert(cards[1].get("quantity") == 3, "decode basic: second card quantity should be 3")


func _test_wiki_example() -> void:
	# Wiki example: 1 Bushwhack (cC), 1 Cauterize (sG), 3 Improvised Weapon (iP) -> SPACcCsGAAABiP
	var code_to_id := {"cC": "hom_str_bushwhack", "sG": "aw_str_cauterize", "iP": "str_improvised_weapon"}
	var id_to_code := {"hom_str_bushwhack": "cC", "aw_str_cauterize": "sG", "str_improvised_weapon": "iP"}

	# Test decode
	var decoded: Dictionary = DeckCodeScript.decode("SPACcCsGAAABiP", code_to_id)
	_assert(decoded.get("error") == "", "wiki example decode: no error expected, got '%s'" % decoded.get("error", ""))
	var cards: Array = decoded.get("cards", [])
	_assert(cards.size() == 3, "wiki example decode: expected 3 cards, got %d" % cards.size())

	# 1-ofs: Bushwhack and Cauterize
	var one_ofs: Array = cards.filter(func(c): return c.get("quantity") == 1)
	_assert(one_ofs.size() == 2, "wiki example: expected 2 one-ofs, got %d" % one_ofs.size())

	# 3-ofs: Improvised Weapon
	var three_ofs: Array = cards.filter(func(c): return c.get("quantity") == 3)
	_assert(three_ofs.size() == 1, "wiki example: expected 1 three-of, got %d" % three_ofs.size())
	_assert(three_ofs[0].get("card_id") == "str_improvised_weapon", "wiki example: three-of should be improvised weapon")

	# Test encode produces same code
	var deck := {"cards": [
		{"card_id": "hom_str_bushwhack", "quantity": 1},
		{"card_id": "aw_str_cauterize", "quantity": 1},
		{"card_id": "str_improvised_weapon", "quantity": 3},
	]}
	var encoded: Dictionary = DeckCodeScript.encode(deck, id_to_code)
	_assert(encoded.get("code") == "SPACcCsGAAABiP", "wiki example encode: expected SPACcCsGAAABiP, got '%s'" % encoded.get("code", ""))


func _test_round_trip() -> void:
	var id_to_code := {"card_a": "aA", "card_b": "bB", "card_c": "cC", "card_d": "dD"}
	var code_to_id := {"aA": "card_a", "bB": "card_b", "cC": "card_c", "dD": "card_d"}
	var deck := {"cards": [
		{"card_id": "card_a", "quantity": 1},
		{"card_id": "card_b", "quantity": 2},
		{"card_id": "card_c", "quantity": 3},
		{"card_id": "card_d", "quantity": 2},
	]}
	var encoded: Dictionary = DeckCodeScript.encode(deck, id_to_code)
	_assert(encoded.get("error") == "", "round trip: encode error: '%s'" % encoded.get("error", ""))

	var decoded: Dictionary = DeckCodeScript.decode(encoded.get("code", ""), code_to_id)
	_assert(decoded.get("error") == "", "round trip: decode error: '%s'" % decoded.get("error", ""))

	var original_cards: Array = deck.get("cards", [])
	var decoded_cards: Array = decoded.get("cards", [])
	_assert(decoded_cards.size() == original_cards.size(), "round trip: card count mismatch: expected %d, got %d" % [original_cards.size(), decoded_cards.size()])

	# Build quantity maps for comparison
	var original_map := {}
	for card in original_cards:
		original_map[card.get("card_id")] = card.get("quantity")
	for card in decoded_cards:
		var cid: String = card.get("card_id", "")
		_assert(original_map.has(cid), "round trip: unexpected card_id '%s' in decoded" % cid)
		_assert(card.get("quantity") == original_map.get(cid, 0), "round trip: quantity mismatch for '%s': expected %d, got %d" % [cid, original_map.get(cid, 0), card.get("quantity", 0)])


func _test_empty_deck() -> void:
	var deck := {"cards": []}
	var encoded: Dictionary = DeckCodeScript.encode(deck, {})
	_assert(encoded.get("error") == "", "empty deck encode: no error expected")
	_assert(encoded.get("code") == "SPAAAAAA", "empty deck: expected SPAAAAAA, got '%s'" % encoded.get("code", ""))

	var decoded: Dictionary = DeckCodeScript.decode("SPAAAAAA", {})
	_assert(decoded.get("error") == "", "empty deck decode: no error expected")
	_assert(decoded.get("cards", []).size() == 0, "empty deck decode: should have 0 cards")


func _test_all_quantity_groups() -> void:
	var id_to_code := {"c1": "aA", "c2": "bB", "c3": "cC"}
	var code_to_id := {"aA": "c1", "bB": "c2", "cC": "c3"}
	var deck := {"cards": [
		{"card_id": "c1", "quantity": 1},
		{"card_id": "c2", "quantity": 2},
		{"card_id": "c3", "quantity": 3},
	]}
	var encoded: Dictionary = DeckCodeScript.encode(deck, id_to_code)
	var code: String = encoded.get("code", "")
	# AB (1 one-of) + aA + AB (1 two-of) + bB + AB (1 three-of) + cC
	_assert(code == "SPABaAABbBABcC", "all groups: expected SPABaAABbBABcC, got '%s'" % code)

	var decoded: Dictionary = DeckCodeScript.decode(code, code_to_id)
	_assert(decoded.get("error") == "", "all groups decode: no error expected")
	var cards: Array = decoded.get("cards", [])
	_assert(cards.size() == 3, "all groups: expected 3 cards, got %d" % cards.size())


func _test_decode_invalid_prefix() -> void:
	var result: Dictionary = DeckCodeScript.decode("XXABaA", {})
	_assert(result.get("error") != "", "invalid prefix: should return error")


func _test_decode_truncated() -> void:
	# Valid start but truncated before card codes
	var result: Dictionary = DeckCodeScript.decode("SPAB", {})
	_assert(result.get("error") != "", "truncated: should return error")

	# Truncated in middle of card code
	var result2: Dictionary = DeckCodeScript.decode("SPABa", {})
	_assert(result2.get("error") != "", "truncated mid-card: should return error")


func _test_decode_unknown_card() -> void:
	var result: Dictionary = DeckCodeScript.decode("SPABzZAAAA", {})
	_assert(result.get("error") == "", "unknown card: should not error (just report unknown)")
	var unknown: Array = result.get("unknown_codes", [])
	_assert(unknown.size() == 1, "unknown card: expected 1 unknown code, got %d" % unknown.size())
	_assert(unknown[0] == "zZ", "unknown card: expected 'zZ', got '%s'" % unknown[0])


func _test_encode_skips_unknown_cards() -> void:
	var deck := {"cards": [
		{"card_id": "known_card", "quantity": 1},
		{"card_id": "unknown_card", "quantity": 2},
	]}
	var id_to_code := {"known_card": "aA"}
	var result: Dictionary = DeckCodeScript.encode(deck, id_to_code)
	_assert(result.get("error") == "", "skip unknown: no error expected")
	var skipped: Array = result.get("skipped", [])
	_assert(skipped.size() == 1, "skip unknown: expected 1 skipped, got %d" % skipped.size())
	_assert(skipped[0] == "unknown_card", "skip unknown: expected 'unknown_card' skipped")
	_assert(result.get("code") == "SPABaAAAAA", "skip unknown: expected SPABaAAAAA, got '%s'" % result.get("code", ""))


func _test_encode_sorts_deterministically() -> void:
	var id_to_code := {"card_z": "zZ", "card_a": "aA", "card_m": "mM"}
	var deck := {"cards": [
		{"card_id": "card_z", "quantity": 1},
		{"card_id": "card_a", "quantity": 1},
		{"card_id": "card_m", "quantity": 1},
	]}
	var result: Dictionary = DeckCodeScript.encode(deck, id_to_code)
	var code: String = result.get("code", "")
	# Should be sorted: aA, mM, zZ
	_assert(code == "SPADaAmMzZAAAA", "sort: expected SPADaAmMzZAAAA, got '%s'" % code)

	# Encode again with different input order should produce same result
	var deck2 := {"cards": [
		{"card_id": "card_m", "quantity": 1},
		{"card_id": "card_z", "quantity": 1},
		{"card_id": "card_a", "quantity": 1},
	]}
	var result2: Dictionary = DeckCodeScript.encode(deck2, id_to_code)
	_assert(result2.get("code") == code, "sort: different input order should produce same code")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
