class_name ArenaRunManager
extends RefCounted

enum State {
	CLASS_SELECT,
	DRAFTING,
	READY_FOR_MATCH,
	IN_MATCH,
	POST_MATCH_PICK,
	RUN_COMPLETE,
}

var state: State = State.CLASS_SELECT
var class_attributes: Array = []
var deck: Array = []  # Array of {card_id, quantity}
var wins: int = 0
var losses: int = 0
var current_match: int = 1
var boss_relic = null  # Will be set by BossRelicSystem later
var _used_opponent_attributes: Array = []  # Track used opponent classes to avoid repeats

# All 10 dual-attribute classes
const DUAL_CLASSES: Array = [
	["strength", "agility"],       # Archer
	["intelligence", "agility"],   # Assassin
	["strength", "intelligence"],  # Battlemage
	["strength", "willpower"],     # Crusader
	["intelligence", "willpower"], # Mage
	["willpower", "agility"],      # Monk
	["agility", "endurance"],      # Scout
	["intelligence", "endurance"], # Sorcerer
	["willpower", "endurance"],    # Spellsword
	["strength", "endurance"],     # Warrior
]


func start_run(p_class_attributes: Array) -> void:
	class_attributes = p_class_attributes.duplicate()
	state = State.DRAFTING
	deck = []
	wins = 0
	losses = 0
	current_match = 1
	boss_relic = null
	_used_opponent_attributes = []


func complete_draft(p_deck: Array) -> void:
	deck = p_deck.duplicate(true)
	state = State.READY_FOR_MATCH


func start_match() -> Dictionary:
	state = State.IN_MATCH
	var opponent_attrs := _pick_opponent_attributes()
	_used_opponent_attributes.append(opponent_attrs)
	var deck_size := 29 + current_match
	var config := {
		"attribute_ids": opponent_attrs,
		"deck_size": deck_size,
		"quality": 0.5,  # Default; ArenaEloManager will set this later
	}
	return config


func record_win() -> void:
	wins += 1
	if current_match >= 9:
		state = State.RUN_COMPLETE
	else:
		state = State.POST_MATCH_PICK
	current_match += 1


func record_loss() -> void:
	losses += 1
	current_match += 1
	if losses >= 3:
		state = State.RUN_COMPLETE
	else:
		state = State.READY_FOR_MATCH


func complete_post_match_pick(card: Dictionary) -> void:
	# Add card to deck - find existing entry or add new one
	var found := false
	for i in range(deck.size()):
		if deck[i]["card_id"] == card["card_id"]:
			deck[i]["quantity"] += 1
			found = true
			break
	if not found:
		deck.append({"card_id": card["card_id"], "quantity": 1})
	state = State.READY_FOR_MATCH


func abandon_run() -> void:
	state = State.RUN_COMPLETE


func _pick_opponent_attributes() -> Array:
	# Build list of available classes, excluding player's class and previously used ones
	var available: Array = []
	for dual_class in DUAL_CLASSES:
		if _arrays_equal(dual_class, class_attributes):
			continue
		var already_used := false
		for used in _used_opponent_attributes:
			if _arrays_equal(dual_class, used):
				already_used = true
				break
		if not already_used:
			available.append(dual_class)

	# If all classes have been used, allow repeats (excluding player's class)
	if available.is_empty():
		for dual_class in DUAL_CLASSES:
			if not _arrays_equal(dual_class, class_attributes):
				available.append(dual_class)

	return available[randi() % available.size()]


static func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var sorted_a := a.duplicate()
	sorted_a.sort()
	var sorted_b := b.duplicate()
	sorted_b.sort()
	for i in range(sorted_a.size()):
		if sorted_a[i] != sorted_b[i]:
			return false
	return true
