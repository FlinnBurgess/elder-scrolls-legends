class_name RegressionCatalog
extends RefCounted


static func core_suites() -> Array:
	return [
		{"id": "bootstrap", "label": "Bootstrap smoke", "script": "res://tests/bootstrap_runner.gd", "success_token": "BOOTSTRAP_SMOKE_OK"},
		{"id": "deck_legality", "label": "Deck legality", "script": "res://tests/deck_validation_runner.gd", "success_token": "DECK_VALIDATION_OK"},
		{"id": "setup", "label": "Setup and mulligan", "script": "res://tests/setup_and_mulligan_runner.gd", "success_token": "SETUP_AND_MULLIGAN_OK"},
		{"id": "lanes", "label": "Lane rules", "script": "res://tests/lane_rules_runner.gd", "success_token": "LANE_RULES_OK"},
		{"id": "turn_magicka", "label": "Turn and magicka", "script": "res://tests/turn_and_magicka_runner.gd", "success_token": "TURN_AND_MAGICKA_OK"},
		{"id": "combat", "label": "Combat", "script": "res://tests/combat_runner.gd", "success_token": "COMBAT_OK"},
		{"id": "evergreen", "label": "Evergreen rules", "script": "res://tests/keyword_matrix_runner.gd", "success_token": "KEYWORD_MATRIX_OK"},
		{"id": "timing", "label": "Timing windows", "script": "res://tests/timing_runner.gd", "success_token": "TIMING_OK"},
		{"id": "runes_prophecy_fatigue", "label": "Runes, Prophecy, fatigue", "script": "res://tests/runes_prophecy_fatigue_runner.gd", "success_token": "RUNES_PROPHECY_FATIGUE_OK"},
		{"id": "mutations", "label": "Zone and state mutations", "script": "res://tests/zone_and_state_runner.gd", "success_token": "ZONE_AND_STATE_OK"},
		{"id": "persistent_cards", "label": "Items and supports", "script": "res://tests/items_and_supports_runner.gd", "success_token": "ITEMS_AND_SUPPORTS_OK"},
		{"id": "extended_mechanics", "label": "Extended mechanic packs", "script": "res://tests/extended_mechanics_runner.gd", "success_token": "EXTENDED_MECHANICS_OK"},
		{"id": "ai_action_enumerator", "label": "AI action enumeration", "script": "res://tests/ai_action_enumerator_runner.gd", "success_token": "AI_ACTION_ENUMERATOR_OK"},
		{"id": "deck_code", "label": "Deck code encode/decode", "script": "res://tests/deck_code_runner.gd", "success_token": "DECK_CODE_OK"},
		{"id": "deckbuilder_ui", "label": "Deckbuilder UI", "script": "res://tests/deckbuilder_ui_runner.gd", "success_token": "DECKBUILDER_UI_OK"},
		{"id": "golden_match", "label": "Golden scenarios and focused regressions", "script": "res://tests/golden_match_runner.gd", "success_token": "GOLDEN_MATCH_OK"},
	]