class_name AdventureController
extends Control

signal return_to_menu

const AdventureCatalogScript = preload("res://src/adventure/adventure_catalog.gd")
const AdventureRunManagerScript = preload("res://src/adventure/adventure_run_manager.gd")
const AdventureDeckLoaderScript = preload("res://src/adventure/adventure_deck_loader.gd")
const AdventureCardPoolScript = preload("res://src/adventure/adventure_card_pool.gd")
const AdventureDeckSelectScreenScript = preload("res://src/ui/adventure/adventure_deck_select_screen.gd")
const AdventureSelectScreenScript = preload("res://src/ui/adventure/adventure_select_screen.gd")
const AdventureNodeMapScreenScript = preload("res://src/ui/adventure/adventure_node_map_screen.gd")
const AdventureResultScreenScript = preload("res://src/ui/adventure/adventure_result_screen.gd")
const BoonCatalogScript = preload("res://src/adventure/boon_catalog.gd")
const BoonNodeOverlayScript = preload("res://src/ui/adventure/boon_node_overlay.gd")
const HealerNodeOverlayScript = preload("res://src/ui/adventure/healer_node_overlay.gd")
const ReinforcementNodeOverlayScript = preload("res://src/ui/adventure/reinforcement_node_overlay.gd")
const ShopNodeOverlayScript = preload("res://src/ui/adventure/shop_node_overlay.gd")
const AugmentCatalogScript = preload("res://src/adventure/augment_catalog.gd")
const AugmentRulesScript = preload("res://src/adventure/augment_rules.gd")
const CreatureAugmentNodeOverlayScript = preload("res://src/ui/adventure/creature_augment_node_overlay.gd")
const ActionAugmentNodeOverlayScript = preload("res://src/ui/adventure/action_augment_node_overlay.gd")
const EventNodeOverlayScript = preload("res://src/ui/adventure/event_node_overlay.gd")
const MatchScreenScript = preload("res://src/ui/match_screen.gd")

var _run_manager = null
var _current_adventure: Dictionary = {}
var _current_screen: Control = null
var _current_overlay: Control = null
var _selected_deck: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if AdventureRunManagerScript.has_active_run():
		_run_manager = AdventureRunManagerScript.load_run()
		_current_adventure = AdventureCatalogScript.load_adventure(_run_manager.adventure_id)
		match _run_manager.state:
			AdventureRunManagerScript.State.VIEWING_MAP:
				_show_node_map()
			AdventureRunManagerScript.State.IN_MATCH:
				_resume_match()
			_:
				_show_deck_select()
	else:
		_show_deck_select()


func _clear_screen() -> void:
	_dismiss_overlay()
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null


func _dismiss_overlay() -> void:
	if _current_overlay != null:
		_current_overlay.queue_free()
		_current_overlay = null


# --- Screen Navigation ---

func _show_deck_select() -> void:
	_clear_screen()
	var screen := AdventureDeckSelectScreenScript.new()
	screen.deck_selected.connect(_on_deck_selected)
	screen.back_pressed.connect(func() -> void: return_to_menu.emit())
	add_child(screen)
	_current_screen = screen


func _on_deck_selected(deck_data: Dictionary) -> void:
	_selected_deck = deck_data
	var deck_id: String = str(deck_data.get("deck_id", ""))
	var adventures := AdventureCatalogScript.get_adventures_for_deck(deck_id)
	if adventures.size() == 1:
		_on_adventure_selected(adventures[0])
	else:
		_show_adventure_select(adventures)


func _show_adventure_select(adventures: Array) -> void:
	_clear_screen()
	var screen := AdventureSelectScreenScript.new()
	screen.adventure_selected.connect(_on_adventure_selected)
	screen.back_pressed.connect(_show_deck_select)
	add_child(screen)
	_current_screen = screen
	screen.set_adventures(adventures)


func _on_adventure_selected(adventure: Dictionary) -> void:
	_current_adventure = adventure
	var adventure_id: String = str(adventure.get("id", ""))
	var deck_id: String = str(_selected_deck.get("deck_id", ""))
	var deck_cards: Array = _selected_deck.get("cards", [])
	var start_node_id: String = str(adventure.get("start_node", ""))

	_run_manager = AdventureRunManagerScript.new()
	_run_manager.start_run(adventure_id, deck_id, deck_cards, start_node_id)
	_show_node_map()


func _show_node_map() -> void:
	_clear_screen()
	var screen := AdventureNodeMapScreenScript.new()
	screen.node_selected.connect(_on_node_selected)
	screen.abandon_pressed.connect(_on_abandon_pressed)
	add_child(screen)
	_current_screen = screen
	screen.set_map_data(
		_current_adventure,
		_run_manager.current_node_id,
		_run_manager.completed_node_ids,
		_run_manager.revives_remaining,
		_run_manager.gold,
		_run_manager.max_health_bonus,
		_run_manager.reroll_tokens,
	)


# --- Node Interaction ---

func _on_node_selected(node_id: String) -> void:
	# If current_node_id is empty, this is a branch choice
	if _run_manager.current_node_id.is_empty():
		_run_manager.choose_next_node(node_id)

	var node: Dictionary = AdventureCatalogScript.get_node_by_id(_current_adventure, node_id)
	if node.is_empty():
		push_error("AdventureController: node '%s' not found" % node_id)
		return

	var node_type: String = str(node.get("type", ""))
	match node_type:
		"combat", "mini_boss", "final_boss":
			_start_combat(node_id, node)
		"healer":
			_show_healer_overlay(node_id, node)
		"reinforcement":
			_show_reinforcement_overlay(node_id)
		"shop":
			_show_shop_overlay(node_id)
		"boon":
			_show_boon_overlay(node_id)
		"creature_augment":
			_show_creature_augment_overlay(node_id)
		"action_augment":
			_show_action_augment_overlay(node_id)
		"event":
			_show_event_overlay(node_id, node)


# --- Combat ---

func _start_combat(node_id: String, node: Dictionary) -> void:
	_run_manager.start_match()

	var enemy_deck_id: String = str(node.get("enemy_deck", ""))
	var enemy_deck_data := AdventureDeckLoaderScript.load_enemy_deck(enemy_deck_id)
	if enemy_deck_data.is_empty():
		push_error("AdventureController: enemy deck '%s' not found" % enemy_deck_id)
		_run_manager.state = AdventureRunManagerScript.State.VIEWING_MAP
		_run_manager.save_run()
		return

	var quality: float = float(node.get("quality", 0.5))
	var enemy_health: int = int(node.get("enemy_health", 30))

	var player_deck_ids := AdventureDeckLoaderScript.deck_to_card_ids(_run_manager.get_full_deck_cards())
	var enemy_deck_ids := AdventureDeckLoaderScript.deck_to_card_ids(enemy_deck_data.get("cards", []))

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var match_seed: int = rng.randi()
	var first_player_index: int = rng.randi_range(0, 1)

	_run_manager.match_config = {
		"node_id": node_id,
		"enemy_deck_id": enemy_deck_id,
		"quality": quality,
		"enemy_health": enemy_health,
		"match_seed": match_seed,
		"first_player_index": first_player_index,
	}
	_run_manager.save_run()

	var augment_map := AugmentRulesScript.build_augment_map(_run_manager.augments)
	_launch_match(player_deck_ids, enemy_deck_ids, quality, enemy_health, match_seed, first_player_index, _run_manager.active_boons.duplicate(), augment_map)


func _launch_match(player_deck_ids: Array, enemy_deck_ids: Array, quality: float, enemy_health: int, match_seed: int, first_player_index: int, active_boons: Array = [], augment_map: Dictionary = {}) -> void:
	_clear_screen()
	var match_screen := MatchScreenScript.new()
	match_screen.name = "AdventureMatch"
	match_screen._arena_mode = true
	match_screen.return_to_main_menu_requested.connect(_on_match_ended.bind(match_screen))
	match_screen.forfeit_requested.connect(_on_match_forfeited)
	match_screen.match_state_changed.connect(_on_match_state_changed)
	add_child(match_screen)
	_current_screen = match_screen

	var ai_options := {"quality": quality, "ai_deck_ids": enemy_deck_ids}
	var boss_config := {}
	if enemy_health != 30:
		boss_config["boss_health"] = enemy_health
	var player_total_health: int = 30 + _run_manager.max_health_bonus
	if player_total_health != 30:
		boss_config["player_health"] = player_total_health

	match_screen._adventure_boons = active_boons
	match_screen._adventure_augments = augment_map

	if not boss_config.is_empty():
		match_screen.start_arena_boss_match(player_deck_ids, enemy_deck_ids, boss_config, match_seed, first_player_index, ai_options)
	else:
		match_screen.start_match_with_decks(player_deck_ids, enemy_deck_ids, match_seed, first_player_index, ai_options)


func _resume_match() -> void:
	if AdventureRunManagerScript.has_saved_match_state():
		var saved_state: Dictionary = AdventureRunManagerScript.load_match_state()
		if saved_state.is_empty():
			_run_manager.state = AdventureRunManagerScript.State.VIEWING_MAP
			_run_manager.match_config = null
			_run_manager.save_run()
			_show_node_map()
			return
		_clear_screen()
		var match_screen := MatchScreenScript.new()
		match_screen.name = "AdventureMatch"
		match_screen._arena_mode = true
		match_screen._adventure_boons = _run_manager.active_boons.duplicate()
		match_screen.return_to_main_menu_requested.connect(_on_match_ended.bind(match_screen))
		match_screen.forfeit_requested.connect(_on_match_forfeited)
		match_screen.match_state_changed.connect(_on_match_state_changed)
		add_child(match_screen)
		_current_screen = match_screen
		match_screen.resume_from_state(saved_state)
	else:
		_run_manager.state = AdventureRunManagerScript.State.VIEWING_MAP
		_run_manager.match_config = null
		_run_manager.save_run()
		_show_node_map()


func _on_match_state_changed(match_state: Dictionary) -> void:
	_run_manager.save_match_state(match_state)


func _on_match_forfeited() -> void:
	_run_manager.clear_match_state()
	_run_manager.match_config = null
	_run_manager.record_loss()
	_advance_after_match()


func _on_match_ended(match_screen: Control) -> void:
	_run_manager.clear_match_state()
	_run_manager.match_config = null
	var won: bool = match_screen.did_local_player_win()
	if won:
		# Apply event combat rewards if applicable.
		if not _pending_event_rewards.is_empty():
			_apply_event_reward_effects(_pending_event_rewards)
			_pending_event_rewards = []
			_pending_event_node_id = ""
		_run_manager.record_win(_current_adventure)
	else:
		_pending_event_rewards = []
		_pending_event_node_id = ""
		_run_manager.record_loss()
	_advance_after_match()


func _advance_after_match() -> void:
	if _run_manager.state == AdventureRunManagerScript.State.RUN_COMPLETE:
		_show_result()
	else:
		_show_node_map()


# --- Healer Node ---

func _show_healer_overlay(node_id: String, node: Dictionary) -> void:
	_dismiss_overlay()
	var overlay := HealerNodeOverlayScript.new()
	var headline: String = str(node.get("headline", "Shrine of Arkay"))
	overlay.set_data(headline, AdventureRunManagerScript.HEALER_HEALTH_BONUS)
	overlay.closed.connect(func() -> void:
		_run_manager.apply_healer_bonus()
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	add_child(overlay)
	_current_overlay = overlay


# --- Reinforcement Node ---

func _show_reinforcement_overlay(node_id: String) -> void:
	_dismiss_overlay()
	var cards := _get_or_generate_offerings(node_id, 3)

	var overlay := ReinforcementNodeOverlayScript.new()
	overlay.card_selected.connect(func(card_id: String) -> void:
		_run_manager.add_card(card_id)
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	overlay.skipped.connect(func() -> void:
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	overlay.reroll_requested.connect(func() -> void:
		_reroll_node(node_id, _show_reinforcement_overlay)
	)
	add_child(overlay)
	_current_overlay = overlay
	overlay.set_cards(cards, _run_manager.reroll_tokens)


# --- Shop Node ---

func _show_shop_overlay(node_id: String) -> void:
	_dismiss_overlay()
	var cards := _get_or_generate_offerings(node_id, 6)
	var offering: Dictionary = _run_manager.get_node_offering(node_id)
	var purchased_ids: Array = offering.get("purchased_ids", [])

	var overlay := ShopNodeOverlayScript.new()
	overlay.card_purchased.connect(func(card_id: String, cost: int) -> void:
		if _run_manager.spend_gold(cost):
			_run_manager.add_card(card_id)
			_run_manager.mark_card_purchased(node_id, card_id)
			overlay.update_gold(_run_manager.gold)
	)
	overlay.closed.connect(func() -> void:
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	overlay.reroll_requested.connect(func() -> void:
		_reroll_node(node_id, _show_shop_overlay)
	)
	add_child(overlay)
	_current_overlay = overlay
	overlay.set_shop_data(cards, _run_manager.gold, purchased_ids, _run_manager.reroll_tokens)


# --- Boon Node ---

func _show_boon_overlay(node_id: String) -> void:
	_dismiss_overlay()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var boons := BoonCatalogScript.get_random_boon_offerings(_run_manager.active_boons, 3, rng)

	var overlay := BoonNodeOverlayScript.new()
	overlay.boon_selected.connect(func(boon_id: String) -> void:
		_run_manager.add_boon(boon_id)
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	overlay.reroll_requested.connect(func() -> void:
		_reroll_node(node_id, _show_boon_overlay)
	)
	add_child(overlay)
	_current_overlay = overlay
	overlay.set_boons(boons, _run_manager.reroll_tokens)


# --- Result ---

func _show_result() -> void:
	_clear_screen()
	var screen := AdventureResultScreenScript.new()
	screen.return_pressed.connect(_on_result_return)
	add_child(screen)
	_current_screen = screen
	screen.set_result(_run_manager.run_won, str(_current_adventure.get("name", "Adventure")))


func _on_result_return() -> void:
	_run_manager = null
	return_to_menu.emit()


func _on_abandon_pressed() -> void:
	_run_manager.abandon_run()
	_run_manager = null
	return_to_menu.emit()


# --- Creature Augment Node ---

func _show_creature_augment_overlay(node_id: String) -> void:
	_dismiss_overlay()
	var creatures := _get_deck_creatures(3)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var augments := AugmentCatalogScript.get_creature_augments(3, rng)

	var overlay := CreatureAugmentNodeOverlayScript.new()
	overlay.augment_selected.connect(func(card_id: String, augment_id: String) -> void:
		_run_manager.add_augment(card_id, augment_id)
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	overlay.reroll_requested.connect(func() -> void:
		_reroll_node(node_id, _show_creature_augment_overlay)
	)
	add_child(overlay)
	_current_overlay = overlay
	overlay.set_data(creatures, augments, _run_manager.reroll_tokens)


# --- Action Augment Node ---

func _show_action_augment_overlay(node_id: String) -> void:
	_dismiss_overlay()
	var pairs := _get_action_augment_pairs(3)

	var overlay := ActionAugmentNodeOverlayScript.new()
	overlay.augment_selected.connect(func(card_id: String, augment_id: String) -> void:
		_run_manager.add_augment(card_id, augment_id)
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
	)
	overlay.reroll_requested.connect(func() -> void:
		_reroll_node(node_id, _show_action_augment_overlay)
	)
	add_child(overlay)
	_current_overlay = overlay
	overlay.set_data(pairs, _run_manager.reroll_tokens)


# --- Event Node ---

func _show_event_overlay(node_id: String, node: Dictionary) -> void:
	_dismiss_overlay()
	var event_data: Dictionary = node.get("event", {})
	event_data["headline"] = str(node.get("headline", "Event"))

	var overlay := EventNodeOverlayScript.new()
	overlay.choice_selected.connect(func(choice_index: int) -> void:
		_execute_event_choice(node_id, node, choice_index)
	)
	overlay.reroll_requested.connect(func() -> void:
		if _run_manager.use_reroll_token():
			_dismiss_overlay()
			_show_event_overlay(node_id, node)
	)
	add_child(overlay)
	_current_overlay = overlay
	overlay.set_data(event_data, _run_manager.reroll_tokens)


func _execute_event_choice(node_id: String, node: Dictionary, choice_index: int) -> void:
	var event_data: Dictionary = node.get("event", {})
	var choices: Array = event_data.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()
		return
	var choice: Dictionary = choices[choice_index]
	var effects: Array = choice.get("effects", [])

	var combat_effect: Dictionary = {}
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_type := str(effect.get("type", ""))
		match effect_type:
			"modify_health":
				_run_manager.max_health_bonus += int(effect.get("amount", 0))
			"modify_gold":
				_run_manager.gold = maxi(0, _run_manager.gold + int(effect.get("amount", 0)))
			"add_card":
				_run_manager.add_card(str(effect.get("card_id", "")))
			"add_random_card":
				var attribute_ids := _get_deck_attribute_ids()
				var cards := AdventureCardPoolScript.get_random_cards(attribute_ids, 1)
				if not cards.is_empty():
					_run_manager.add_card(str(cards[0].get("card_id", "")))
			"add_boon":
				_run_manager.add_boon(str(effect.get("boon_id", "")))
			"add_revive":
				_run_manager.revives_remaining += 1
			"start_combat":
				combat_effect = effect

	_run_manager.save_run()

	if not combat_effect.is_empty():
		# Launch combat for this event choice. Store reward effects for post-match.
		_run_manager.match_config = _run_manager.match_config if _run_manager.match_config != null else {}
		var event_combat_node := {
			"type": "combat",
			"enemy_deck": str(combat_effect.get("enemy_deck", "")),
			"quality": float(combat_effect.get("quality", 0.5)),
			"enemy_health": int(combat_effect.get("enemy_health", 30)),
		}
		_dismiss_overlay()
		_start_event_combat(node_id, event_combat_node, combat_effect.get("reward_effects", []))
	else:
		_run_manager.complete_non_combat_node(_current_adventure)
		_dismiss_overlay()
		_show_node_map()


var _pending_event_rewards: Array = []
var _pending_event_node_id: String = ""

func _start_event_combat(node_id: String, combat_node: Dictionary, reward_effects: Array) -> void:
	_pending_event_rewards = reward_effects
	_pending_event_node_id = node_id
	_start_combat(node_id, combat_node)


# --- Reroll ---

func _reroll_node(node_id: String, show_method: Callable) -> void:
	if not _run_manager.use_reroll_token():
		return
	_run_manager.clear_node_offering(node_id)
	show_method.call(node_id)


# --- Helpers ---

func _get_deck_attribute_ids() -> Array:
	var deck_data := AdventureDeckLoaderScript.load_player_deck(_run_manager.deck_id)
	return deck_data.get("attribute_ids", [])


func _get_deck_creatures(count: int) -> Array:
	var full_deck: Array = _run_manager.get_full_deck_cards()
	var catalog := AdventureCardPoolScript._load_catalog()
	var all_cards: Array = catalog.get("cards", [])
	var card_lookup: Dictionary = {}
	for card in all_cards:
		card_lookup[str(card.get("card_id", ""))] = card

	# Deduplicate by card_id and filter to creatures.
	var seen: Dictionary = {}
	var creatures: Array = []
	for entry in full_deck:
		var card_id := str(entry.get("card_id", ""))
		if seen.has(card_id):
			continue
		seen[card_id] = true
		var card: Dictionary = card_lookup.get(card_id, {})
		if str(card.get("card_type", "")) == "creature":
			creatures.append(card)
	# Shuffle and take N.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shuffled := creatures.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled.slice(0, mini(count, shuffled.size()))


func _get_action_augment_pairs(count: int) -> Array:
	var full_deck: Dictionary = _run_manager.get_full_deck_cards()
	var catalog := AdventureCardPoolScript._load_catalog()
	var all_cards: Array = catalog.get("cards", [])
	var card_lookup: Dictionary = {}
	for card in all_cards:
		card_lookup[str(card.get("card_id", ""))] = card

	# Find action cards with valid augments.
	var seen: Dictionary = {}
	var candidates: Array = []  # Array of {card: dict, augments: Array}
	for entry in full_deck:
		var card_id := str(entry.get("card_id", ""))
		if seen.has(card_id):
			continue
		seen[card_id] = true
		var card: Dictionary = card_lookup.get(card_id, {})
		if str(card.get("card_type", "")) != "action":
			continue
		var valid_augs := AugmentCatalogScript.get_valid_action_augments(card)
		if not valid_augs.is_empty():
			candidates.append({"card": card, "augments": valid_augs})

	# Shuffle and take N, assigning a random augment to each.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shuffled := candidates.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp

	var pairs: Array = []
	for i in range(mini(count, shuffled.size())):
		var entry: Dictionary = shuffled[i]
		var augs: Array = entry["augments"]
		var chosen_aug: Dictionary = augs[rng.randi_range(0, augs.size() - 1)]
		pairs.append({"card": entry["card"], "augment": chosen_aug})
	return pairs


func _apply_event_reward_effects(effects: Array) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_type := str(effect.get("type", ""))
		match effect_type:
			"modify_health":
				_run_manager.max_health_bonus += int(effect.get("amount", 0))
			"modify_gold":
				_run_manager.gold = maxi(0, _run_manager.gold + int(effect.get("amount", 0)))
			"add_card":
				_run_manager.add_card(str(effect.get("card_id", "")))
			"add_random_card":
				var attribute_ids := _get_deck_attribute_ids()
				var cards := AdventureCardPoolScript.get_random_cards(attribute_ids, 1)
				if not cards.is_empty():
					_run_manager.add_card(str(cards[0].get("card_id", "")))
			"add_boon":
				_run_manager.add_boon(str(effect.get("boon_id", "")))
			"add_revive":
				_run_manager.revives_remaining += 1
	_run_manager.save_run()


func _get_or_generate_offerings(node_id: String, count: int) -> Array:
	var existing: Dictionary = _run_manager.get_node_offering(node_id)
	if not existing.is_empty():
		return existing.get("cards", [])
	var attribute_ids: Array = _get_deck_attribute_ids()
	var cards := AdventureCardPoolScript.get_random_cards(attribute_ids, count)
	_run_manager.save_node_offering(node_id, cards)
	return cards
