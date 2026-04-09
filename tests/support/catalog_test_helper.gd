class_name CatalogTestHelper
extends RefCounted

## Loads the real card catalog and provides helpers for creating
## test cards from actual catalog definitions.

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const ScenarioFixtures = preload("res://tests/support/scenario_fixtures.gd")

var _card_by_id: Dictionary = {}


func load_catalog() -> bool:
	var catalog := CardCatalog.load_default()
	var error := str(catalog.get("error", ""))
	if not error.is_empty():
		push_error("CatalogTestHelper: Failed to load catalog: %s" % error)
		return false
	_card_by_id = catalog.get("card_by_id", {})
	return true


func get_definition(card_id: String) -> Dictionary:
	return _card_by_id.get(card_id, {})


## Build an extra dict suitable for ScenarioFixtures.add_hand_card / make_card
## from a real catalog definition. Maps catalog field names to runtime names.
func card_extra(card_id: String, overrides: Dictionary = {}) -> Dictionary:
	var def := get_definition(card_id)
	if def.is_empty():
		push_error("CatalogTestHelper: Unknown card_id '%s'" % card_id)
		return {}
	var extra := {
		"definition_id": str(def.get("card_id", "")),
		"name": str(def.get("name", "")),
		"card_type": str(def.get("card_type", "creature")),
		"cost": int(def.get("cost", 0)),
		"power": int(def.get("base_power", 0)),
		"health": int(def.get("base_health", 0)),
		"keywords": def.get("keywords", []).duplicate(true),
		"subtypes": def.get("subtypes", []).duplicate(true),
		"rules_tags": def.get("rules_tags", []).duplicate(true),
		"attributes": def.get("attributes", []).duplicate(true),
		"is_unique": bool(def.get("is_unique", false)),
	}
	# Transfer optional complex fields
	for key in ["triggered_abilities", "self_cost_reduction", "aura",
			"action_target_mode", "support_uses", "grants_immunity",
			"grants_trigger", "cost_reduction_aura", "cost_increase_aura",
			"passive_abilities", "attack_condition", "play_condition",
			"innate_statuses", "self_immunity", "shout_chain_id",
			"shout_level", "shout_levels", "equip_power_bonus",
			"equip_health_bonus", "equip_keywords", "transform_on_exhausted",
			"magicka_aura"]:
		if def.has(key):
			var val = def[key]
			if val is Dictionary or val is Array:
				extra[key] = val.duplicate(true)
			else:
				extra[key] = val
	# Apply caller overrides last
	for key in overrides:
		extra[key] = overrides[key]
	return extra


## Shorthand: add a real catalog card to a player's hand.
func add_to_hand(player_state: Dictionary, card_id: String, overrides: Dictionary = {}) -> Dictionary:
	var extra := card_extra(card_id, overrides)
	if extra.is_empty():
		return {}
	return ScenarioFixtures.add_hand_card(player_state, card_id, extra)


## Shorthand: summon a real catalog creature onto the board.
func summon(player_state: Dictionary, match_state: Dictionary, card_id: String,
		lane_id: String, overrides: Dictionary = {}) -> Dictionary:
	var extra := card_extra(card_id, overrides)
	if extra.is_empty():
		return {}
	return ScenarioFixtures.summon_creature(
		player_state, match_state, card_id, lane_id,
		int(extra.get("power", 0)), int(extra.get("health", 0)),
		extra.get("keywords", []), -1, extra)


## Build a deck card dict for set_deck_cards.
func make_deck_card(player_id: String, card_id: String, overrides: Dictionary = {}) -> Dictionary:
	var extra := card_extra(card_id, overrides)
	if extra.is_empty():
		return {}
	return ScenarioFixtures.make_card(player_id, card_id, extra)
