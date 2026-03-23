class_name DeckCode
extends RefCounted

const PREFIX := "SP"


static func encode(deck_definition: Dictionary, card_id_to_deck_code: Dictionary) -> Dictionary:
	var cards: Array = deck_definition.get("cards", [])
	var groups: Array[Array] = [[], [], []]
	var skipped: Array[String] = []

	for entry in cards:
		var card_id: String = str(entry.get("card_id", ""))
		var quantity: int = int(entry.get("quantity", 0))
		if quantity < 1 or quantity > 3:
			continue
		var code: String = card_id_to_deck_code.get(card_id, "")
		if code.is_empty():
			skipped.append(card_id)
			continue
		groups[quantity - 1].append(code)

	for group in groups:
		group.sort()

	var result := PREFIX
	for group in groups:
		result += _encode_count(group.size())
		for code in group:
			result += code
	return {"code": result, "skipped": skipped, "error": ""}


static func decode(code: String, deck_code_to_card_id: Dictionary) -> Dictionary:
	if not code.begins_with(PREFIX):
		return {"cards": [], "unknown_codes": [], "error": "Invalid deck code: must start with 'SP'"}

	var pos := PREFIX.length()
	var cards: Array[Dictionary] = []
	var unknown_codes: Array[String] = []

	for quantity in range(1, 4):
		if pos + 2 > code.length():
			return {"cards": cards, "unknown_codes": unknown_codes, "error": "Deck code truncated: expected count at position %d" % pos}
		var count := _decode_count(code.substr(pos, 2))
		if count < 0:
			return {"cards": cards, "unknown_codes": unknown_codes, "error": "Invalid count encoding at position %d" % pos}
		pos += 2

		for i in range(count):
			if pos + 2 > code.length():
				return {"cards": cards, "unknown_codes": unknown_codes, "error": "Deck code truncated: expected card code at position %d" % pos}
			var card_code := code.substr(pos, 2)
			pos += 2
			var card_id: String = deck_code_to_card_id.get(card_code, "")
			if card_id.is_empty():
				unknown_codes.append(card_code)
			else:
				cards.append({"card_id": card_id, "quantity": quantity})

	return {"cards": cards, "unknown_codes": unknown_codes, "error": ""}


static func _encode_count(n: int) -> String:
	var high := n / 26
	var low := n % 26
	return char(65 + high) + char(65 + low)


static func _decode_count(s: String) -> int:
	if s.length() != 2:
		return -1
	var high := s.unicode_at(0) - 65
	var low := s.unicode_at(1) - 65
	if high < 0 or high > 25 or low < 0 or low > 25:
		return -1
	return high * 26 + low
