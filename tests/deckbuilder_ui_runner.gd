extends SceneTree

const DeckbuilderScreen = preload("res://src/ui/deckbuilder_screen.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := DeckbuilderScreen.new()
	root.add_child(screen)
	await process_frame
	if not _run_all_tests(screen):
		quit(1)
		return
	print("DECKBUILDER_UI_OK")
	quit(0)


func _run_all_tests(screen: DeckbuilderScreen) -> bool:
	return (
		_test_browser_filters(screen) and
		_test_legality_and_curve_feedback(screen) and
		_test_import_export_round_trip(screen)
	)


func _test_browser_filters(screen: DeckbuilderScreen) -> bool:
	screen.set_search_query("dragon")
	var dragon_ids := screen.get_filtered_card_ids()
	if not _assert(dragon_ids.size() >= 3, "Expected Dragon search to surface multiple cards."):
		return false
	screen.set_search_query("")
	screen.set_keyword_filter("guard")
	var guard_ids := screen.get_filtered_card_ids()
	screen.set_keyword_filter("")
	return (
		_assert(guard_ids.has("neu_barded_guar"), "Guard filter should include Guard cards.") and
		_assert(not guard_ids.has("neu_crushing_blow"), "Guard filter should exclude non-Guard cards.") and
		_assert(screen.select_card("neu_mundus_stone"), "Selecting a browser card should succeed.") and
		_assert(screen.get_selected_card_text().contains("Mundus Stone"), "Inspector should reflect the selected card.")
	)


func _test_legality_and_curve_feedback(screen: DeckbuilderScreen) -> bool:
	screen.clear_deck()
	if not _assert(screen.set_deck_attributes(["strength", "intelligence"]), "Battlemage attributes should be selectable." ):
		return false
	if not _assert(screen.add_card_to_deck("dual_tyr"), "Adding an off-class card should still be allowed for warning coverage." ):
		return false
	if not _assert(screen.get_legality_text().contains("requires"), "Off-class card should produce immediate legality feedback."):
		return false
	screen.remove_card_from_deck("dual_tyr")
	_fill_legal_deck(screen, ["strength", "intelligence"])
	var card_count := screen.get_deck_count()
	return (
		_assert(card_count == 50, "Filled Battlemage deck should contain 50 cards; got %d." % card_count) and
		_assert(screen.get_legality_text().contains("Legal deck."), "A 50-card legal Battlemage list should validate.") and
		_assert(screen.get_banner_text().contains("Battlemage"), "Banner should show the derived Battlemage identity.") and
		_assert(screen.get_curve_summary_text().contains("Curve |"), "Curve summary should be populated for the current deck.")
	)


func _test_import_export_round_trip(screen: DeckbuilderScreen) -> bool:
	var exported := screen.export_deck_json()
	if not _assert(exported.contains("strength"), "Export should include attribute ids in JSON." ):
		return false
	screen.clear_deck()
	if not _assert(screen.get_deck_count() == 0, "Clearing the deck should empty all card entries." ):
		return false
	var import_result := screen.import_deck_json(exported)
	return (
		_assert(bool(import_result.get("is_valid", false)), "Exported deck JSON should round-trip through import.") and
		_assert(screen.get_deck_count() == 50, "Imported deck should restore the original card count.") and
		_assert(screen.get_export_text().contains("dual_sentinel_battlemace"), "Import/export text box should retain the serialized deck payload.")
	)


func _fill_legal_deck(screen: DeckbuilderScreen, deck_attributes: Array) -> void:
	var legal_ids := [
		# Battlemage dual cards (listed first to ensure inclusion)
		"dual_sentinel_battlemace",
		# Neutral cards
		"neu_barded_guar",
		"neu_lurking_crocodile",
		"neu_enraged_mudcrab",
		"neu_crushing_blow",
		"neu_maple_shield",
		"neu_spider_worker",
		"neu_dwarven_sphere",
		"neu_ferocious_dreugh",
		# Strength cards
		"str_battlerage_orc",
		"str_graystone_ravager",
		"str_steel_scimitar",
		"str_rapid_shot",
		"str_sharpshooter_scout",
		"str_fortress_watchman",
		# Intelligence cards
		"int_firebolt",
		"int_camlorn_hero",
		"int_camlorn_sentinel",
		"int_redoran_enforcer",
		"int_ice_spike",
	]
	for card_id in legal_ids:
		var card := screen.get_card_record(str(card_id))
		if not _card_is_legal_for_attributes(card, deck_attributes):
			continue
		var copy_limit := 1 if bool(card.get("is_unique", false)) else 3
		for _copy_index in range(copy_limit):
			if screen.get_deck_count() >= 50:
				return
			screen.add_card_to_deck(str(card_id))


func _card_is_legal_for_attributes(card: Dictionary, deck_attributes: Array) -> bool:
	var attributes: Array = card.get("attributes", [])
	if attributes.is_empty():
		return true
	for attribute_id in attributes:
		if not deck_attributes.has(attribute_id):
			return false
	var class_value: Variant = card.get("class_id", null)
	var card_class_id := "" if class_value == null else str(class_value)
	if card_class_id.is_empty():
		return true
	return card_class_id == "battlemage"


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false
