extends SceneTree

const CardRelationshipResolver = preload("res://src/ui/components/card_relationship_resolver.gd")
const CardCatalog = preload("res://src/deck/card_catalog.gd")

var _pass_count := 0
var _fail_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_result: Dictionary = CardCatalog.load_default()
	var card_by_id: Dictionary = catalog_result.get("card_by_id", {})
	if card_by_id.is_empty():
		print("FAIL: Could not load card catalog")
		quit(1)
		return

	_test_attribute_synergy_count(card_by_id)
	_test_subtype_synergy_count(card_by_id)
	_test_empty_context_returns_negative()
	_test_deck_editor_context_with_no_cards()
	_test_context_survives_deep_duplicate(card_by_id)
	_test_match_context_with_hydrated_cards(card_by_id)
	_test_callback_reflects_deck_changes(card_by_id)
	_test_card_template_hydrated_from_catalog(card_by_id)

	if _fail_count > 0:
		print("CARD_RELATIONSHIP_RESOLVER_FAILED: %d passed, %d failed" % [_pass_count, _fail_count])
		quit(1)
	else:
		print("CARD_RELATIONSHIP_RESOLVER_OK: %d passed" % _pass_count)
		quit(0)


func _test_attribute_synergy_count(card_by_id: Dictionary) -> void:
	# Northwind Outpost has aura with filter_attribute: "strength"
	var northwind: Dictionary = card_by_id.get("str_northwind_outpost", {}) as Dictionary
	if northwind.is_empty():
		_assert(false, "attribute_synergy: Northwind Outpost not found in catalog")
		return

	# Build a deck context with some strength cards
	var deck_cards: Array = []
	var strength_count := 0
	for card_id: String in card_by_id:
		var card: Dictionary = card_by_id[card_id]
		var attributes: Array = card.get("attributes", [])
		for attr: String in attributes:
			if attr.to_lower() == "strength":
				deck_cards.append(card)
				strength_count += 1
				break
		if strength_count >= 5:
			break

	var context: Dictionary = {"zone": "deck_editor", "deck_cards": deck_cards}
	var relationships: Array = CardRelationshipResolver.resolve(northwind, context)

	# Find the text relationship that mentions "Strength"
	var found := false
	for rel: Dictionary in relationships:
		var rel_type: String = str(rel.get("type", ""))
		if rel_type != "text":
			continue
		var text: String = str(rel.get("text", ""))
		if "Strength" in text and "card" in text:
			found = true
			var expected_fragment: String = "have %d" % strength_count
			var has_count: bool = expected_fragment in text
			_assert(has_count, "attribute_synergy: Expected count %d in text '%s'" % [strength_count, text])
			break
	_assert(found, "attribute_synergy: Expected a Strength synergy text relationship")


func _test_subtype_synergy_count(card_by_id: Dictionary) -> void:
	var test_card: Dictionary = {}
	var test_subtype := ""
	for card_id: String in card_by_id:
		var card: Dictionary = card_by_id[card_id]
		var abilities: Array = card.get("triggered_abilities", [])
		for ability_raw: Variant in abilities:
			if typeof(ability_raw) != TYPE_DICTIONARY:
				continue
			var ability: Dictionary = ability_raw as Dictionary
			for key: String in ["required_subtype_on_board", "required_event_source_subtype", "required_summon_subtype"]:
				var st: String = str(ability.get(key, ""))
				if not st.is_empty():
					test_card = card
					test_subtype = st.to_lower()
					break
			if not test_card.is_empty():
				break
		if not test_card.is_empty():
			break

	if test_card.is_empty():
		print("  SKIP: subtype_synergy: no card with subtype synergy found in catalog")
		return

	# Build deck with matching subtypes
	var deck_cards: Array = []
	var subtype_count := 0
	for card_id: String in card_by_id:
		var card: Dictionary = card_by_id[card_id]
		var subtypes: Array = card.get("subtypes", [])
		for st_raw: Variant in subtypes:
			if str(st_raw).to_lower() == test_subtype:
				deck_cards.append(card)
				subtype_count += 1
				break
		if subtype_count >= 3:
			break

	var context: Dictionary = {"zone": "deck_editor", "deck_cards": deck_cards}
	var relationships: Array = CardRelationshipResolver.resolve(test_card, context)

	var found := false
	for rel: Dictionary in relationships:
		var rel_type: String = str(rel.get("type", ""))
		if rel_type != "text":
			continue
		var text: String = str(rel.get("text", ""))
		if test_subtype.to_lower() in text.to_lower() and "have" in text.to_lower():
			found = true
			var has_count: bool = str(subtype_count) in text
			_assert(has_count, "subtype_synergy: Expected count %d in text '%s'" % [subtype_count, text])
			break
	_assert(found, "subtype_synergy: Expected a %s synergy text relationship for card '%s'" % [test_subtype, test_card.get("name", "?")])


func _test_empty_context_returns_negative() -> void:
	var test_card: Dictionary = {"name": "Test", "aura": {"filter_attribute": "strength"}}
	var relationships: Array = CardRelationshipResolver.resolve(test_card, {})
	var found := false
	for rel: Dictionary in relationships:
		var rel_type: String = str(rel.get("type", ""))
		if rel_type == "text":
			var text: String = str(rel.get("text", ""))
			if "Synergy" in text and "Strength" in text:
				found = true
				_assert(not ("have 0" in text.to_lower()), "empty_context: Should show 'Synergy:' not 'have 0', got '%s'" % text)
	_assert(found, "empty_context: Expected a Synergy fallback text")


func _test_deck_editor_context_with_no_cards() -> void:
	var test_card: Dictionary = {"name": "Test", "aura": {"filter_attribute": "endurance"}}
	var context: Dictionary = {"zone": "deck_editor", "deck_cards": []}
	var relationships: Array = CardRelationshipResolver.resolve(test_card, context)
	var found := false
	for rel: Dictionary in relationships:
		var rel_type: String = str(rel.get("type", ""))
		if rel_type == "text":
			var text: String = str(rel.get("text", ""))
			if "Endurance" in text:
				found = true
				_assert("have 0" in text.to_lower(), "empty_deck_context: Expected 'have 0' for empty deck, got '%s'" % text)
	_assert(found, "empty_deck_context: Expected an Endurance text relationship")


func _test_callback_reflects_deck_changes(card_by_id: Dictionary) -> void:
	# Simulate the callback-based context: deck starts empty, then cards are added
	var northwind: Dictionary = card_by_id.get("str_northwind_outpost", {}) as Dictionary
	if northwind.is_empty():
		_assert(false, "callback: Northwind Outpost not found")
		return

	# Mutable deck state (simulates _deck_quantities + _card_by_id in deck editor)
	var deck_state: Array = []

	# Build context callback that reads from mutable deck_state
	var build_ctx: Callable = func() -> Dictionary:
		return {"zone": "deck_editor", "deck_cards": deck_state.duplicate()}

	# Initially empty deck -> count should be 0
	var ctx0: Dictionary = build_ctx.call()
	var rels0: Array = CardRelationshipResolver.resolve(northwind, ctx0)
	var found_zero := false
	for rel: Dictionary in rels0:
		if str(rel.get("type", "")) == "text":
			var text: String = str(rel.get("text", ""))
			if "Strength" in text and "have 0" in text.to_lower():
				found_zero = true
	_assert(found_zero, "callback: Empty deck should show count 0")

	# Add 3 strength cards to the deck
	var added := 0
	for cid: String in card_by_id:
		var c: Dictionary = card_by_id[cid]
		for attr: String in c.get("attributes", []):
			if attr == "strength":
				deck_state.append(c)
				added += 1
				break
		if added >= 3:
			break

	# Re-resolve with callback -> should now reflect 3 strength cards
	var ctx1: Dictionary = build_ctx.call()
	var rels1: Array = CardRelationshipResolver.resolve(northwind, ctx1)
	var found_three := false
	for rel: Dictionary in rels1:
		if str(rel.get("type", "")) == "text":
			var text: String = str(rel.get("text", ""))
			if "Strength" in text and "have 3" in text.to_lower():
				found_three = true
	_assert(found_three, "callback: After adding 3 strength cards, should show count 3")


func _test_context_survives_deep_duplicate(card_by_id: Dictionary) -> void:
	# Simulate what CardDisplayComponent.set_relationship_context does:
	# context.duplicate(true) and then resolve
	var northwind: Dictionary = card_by_id.get("str_northwind_outpost", {}) as Dictionary
	if northwind.is_empty():
		_assert(false, "deep_dup: Northwind Outpost not found")
		return

	var deck_cards: Array = []
	var strength_count := 0
	for card_id: String in card_by_id:
		var card: Dictionary = card_by_id[card_id]
		var attributes: Array = card.get("attributes", [])
		for attr: String in attributes:
			if attr.to_lower() == "strength":
				deck_cards.append(card)
				strength_count += 1
				break
		if strength_count >= 5:
			break

	var context: Dictionary = {"zone": "deck_editor", "deck_cards": deck_cards}
	# Deep duplicate like set_relationship_context does
	var duped_context: Dictionary = context.duplicate(true)
	var relationships: Array = CardRelationshipResolver.resolve(northwind, duped_context)

	var found := false
	for rel: Dictionary in relationships:
		if str(rel.get("type", "")) != "text":
			continue
		var text: String = str(rel.get("text", ""))
		if "Strength" in text and "card" in text:
			found = true
			var expected_fragment: String = "have %d" % strength_count
			_assert(expected_fragment in text, "deep_dup: Expected count %d in text '%s'" % [strength_count, text])
			break
	_assert(found, "deep_dup: Expected Strength synergy text after deep duplicate")


func _test_match_context_with_hydrated_cards(card_by_id: Dictionary) -> void:
	# Simulate match context: cards that have been hydrated with catalog data
	var northwind: Dictionary = card_by_id.get("str_northwind_outpost", {}) as Dictionary
	if northwind.is_empty():
		_assert(false, "match_ctx: Northwind Outpost not found")
		return

	# Build cards like match_bootstrap does (barebones), then hydrate like match_screen does
	var board_cards: Array = []
	var hand_cards: Array = []
	var hydrated_count := 0
	for card_id: String in card_by_id:
		var card: Dictionary = card_by_id[card_id]
		var attributes: Array = card.get("attributes", [])
		for attr: String in attributes:
			if attr.to_lower() == "strength":
				# Build a barebones match card
				var match_card: Dictionary = {
					"instance_id": "p1_card_%03d" % hydrated_count,
					"definition_id": card_id,
					"zone": "lane",
					"keywords": [],
					"granted_keywords": [],
					"status_markers": [],
					"triggered_abilities": [],
				}
				# Hydrate like _hydrate_card does
				match_card["attributes"] = attributes.duplicate(true)
				match_card["subtypes"] = card.get("subtypes", []).duplicate(true)
				board_cards.append(match_card)
				hydrated_count += 1
				break
		if hydrated_count >= 3:
			break

	var context: Dictionary = {"zone": "match", "board_cards": board_cards, "hand_cards": hand_cards}
	var relationships: Array = CardRelationshipResolver.resolve(northwind, context)

	var found := false
	for rel: Dictionary in relationships:
		if str(rel.get("type", "")) != "text":
			continue
		var text: String = str(rel.get("text", ""))
		if "Strength" in text and "card" in text:
			found = true
			var expected_fragment: String = "have %d" % hydrated_count
			_assert(expected_fragment in text, "match_ctx: Expected count %d in text '%s'" % [hydrated_count, text])
			break
	_assert(found, "match_ctx: Expected Strength synergy text in match context")

	# Now test with UN-hydrated match cards (no attributes field) - should show 0
	var unhydrated_cards: Array = []
	for i in range(3):
		unhydrated_cards.append({
			"instance_id": "p1_noattr_%03d" % i,
			"definition_id": "str_nord_firebrand",
			"zone": "lane",
			"keywords": [],
		})
	var unhyd_context: Dictionary = {"zone": "match", "board_cards": unhydrated_cards, "hand_cards": []}
	var unhyd_rels: Array = CardRelationshipResolver.resolve(northwind, unhyd_context)
	for rel: Dictionary in unhyd_rels:
		if str(rel.get("type", "")) != "text":
			continue
		var text: String = str(rel.get("text", ""))
		if "Strength" in text and "card" in text:
			_assert("have 0" in text.to_lower(), "match_ctx_unhydrated: Unhydrated cards should show 0 count, got '%s'" % text)
			break


func _test_card_template_hydrated_from_catalog(card_by_id: Dictionary) -> void:
	# Dwarven Colossus summons Power Sphere via card_template with only a definition_id.
	# The resolver must hydrate that template from the catalog so the alt-view shows
	# the real name and rules text — not a title-cased definition_id.
	var colossus: Dictionary = card_by_id.get("cwc_neu_dwarven_colossus", {}) as Dictionary
	if colossus.is_empty():
		_assert(false, "hydrate: Dwarven Colossus not found in catalog")
		return
	var relationships: Array = CardRelationshipResolver.resolve(colossus, {})
	var found := false
	for rel: Dictionary in relationships:
		if str(rel.get("type", "")) != "card":
			continue
		var cd: Dictionary = rel.get("card_data", {}) as Dictionary
		if str(cd.get("definition_id", "")) != "cwc_neu_power_sphere":
			continue
		found = true
		_assert(str(cd.get("name", "")) == "Power Sphere", "hydrate: expected name 'Power Sphere', got '%s'" % str(cd.get("name", "")))
		_assert(not str(cd.get("rules_text", "")).is_empty(), "hydrate: expected non-empty rules_text on hydrated Power Sphere")
		break
	_assert(found, "hydrate: expected Power Sphere alt-view relationship from Dwarven Colossus")


func _assert(condition: bool, message: String) -> bool:
	if condition:
		_pass_count += 1
		return true
	_fail_count += 1
	print("  FAIL: %s" % message)
	return false
