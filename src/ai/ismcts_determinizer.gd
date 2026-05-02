class_name ISMCTSDeterminizer
extends RefCounted

## Replaces the opponent's unrevealed hand and deck with a randomly sampled
## set of plausible cards. Used by ISMCTSMatchPolicy at the start of each
## search root (and periodically resampled within the iteration loop).
##
## Plausible pool:
## - All collectible cards from CardCatalog whose attribute set is a subset of
##   `observed_attributes ∪ {neutral}`. If `observed_attributes` is empty (no
##   plays yet), the pool spans every attribute.
## - Sampling respects a 3-of cap per definition_id, also accounting for
##   already-observed copies of that definition (e.g. opponent has played 2
##   copies of X already → only 1 more X allowed in the sample).
##
## Identity preservation: the opponent's card *instance_ids* stay stable. We
## overwrite each unrevealed instance's data fields with the sampled card's
## stats/effects/keywords, keeping `instance_id`, `owner_player_id`,
## `controller_player_id`, and `zone` intact so the engine's references still
## resolve.
##
## Observed cards in opponent's lanes/discard/etc are NOT touched — those are
## the cards the AI already knows about and they remain as-is.

const CardCatalog = preload("res://src/deck/card_catalog.gd")
const MatchActionEnumerator = preload("res://src/ai/match_action_enumerator.gd")
const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const AIDeckFingerprinter = preload("res://src/ai/ai_deck_fingerprinter.gd")

const COPY_CAP := 3
const STATE_CACHE_KEY := "_ismcts_pool_cache"


static func determinize(match_state: Dictionary, ai_player_id: String, observed: Dictionary, rng: RandomNumberGenerator = null, belief: Dictionary = {}) -> Dictionary:
	var clone := MatchActionEnumerator._lightweight_clone(match_state)
	var opp := _find_opponent(clone, ai_player_id)
	if opp.is_empty():
		return clone
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var observed_attrs: Array = observed.get("attributes", [])
	var observed_counts: Dictionary = observed.get("def_counts", {})
	var pool := _get_or_build_pool(match_state, observed_attrs)
	if pool.is_empty():
		return clone
	var unknown_cards: Array = []
	for card in opp.get("hand", []):
		unknown_cards.append(card)
	for card in opp.get("deck", []):
		unknown_cards.append(card)
	if unknown_cards.is_empty():
		return clone
	var sampled := _sample_definitions(pool, unknown_cards.size(), observed_counts, rng, belief)
	for index in range(unknown_cards.size()):
		if index >= sampled.size():
			break
		_overwrite_card(unknown_cards[index], sampled[index])
	return clone


static func _find_opponent(match_state: Dictionary, ai_player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) != ai_player_id:
			return player
	return {}


## Build (or return cached) plausible pool for a given observed-attribute set.
## Keyed off the sorted attribute tuple so resampling for the same observation
## set reuses the same pool. Cache lives on match_state so it persists across
## clones via deep-duplicate.
static func _get_or_build_pool(match_state: Dictionary, observed_attrs: Array) -> Array:
	var key_parts := observed_attrs.duplicate()
	key_parts.sort()
	var key := "|".join(key_parts) if not key_parts.is_empty() else "<all>"
	var cache: Dictionary = match_state.get(STATE_CACHE_KEY, {})
	if cache.has(key):
		return cache[key]
	var pool := _build_pool(observed_attrs)
	cache[key] = pool
	match_state[STATE_CACHE_KEY] = cache
	return pool


static func _build_pool(observed_attrs: Array) -> Array:
	var allowed := {}
	for attr in observed_attrs:
		var attr_str := str(attr)
		if not attr_str.is_empty():
			allowed[attr_str] = true
	allowed["neutral"] = true
	var allow_all := observed_attrs.is_empty()
	var catalog := CardCatalog.load_default()
	if str(catalog.get("error", "")).length() > 0:
		return []
	var pool: Array = []
	for raw_card in catalog.get("cards", []):
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = raw_card
		if not bool(card.get("collectible", true)):
			continue
		if not bool(card.get("random_generation_eligible", true)):
			continue
		var card_attrs: Array = card.get("attributes", [])
		if card_attrs.is_empty():
			continue
		if allow_all or _attrs_subset_of(card_attrs, allowed):
			pool.append(card)
	return pool


static func _attrs_subset_of(card_attrs: Array, allowed: Dictionary) -> bool:
	for attr in card_attrs:
		if not allowed.has(str(attr)):
			return false
	return true


static func _sample_definitions(pool: Array, count: int, observed_counts: Dictionary, rng: RandomNumberGenerator, belief: Dictionary = {}) -> Array:
	var picks: Array = []
	if pool.is_empty() or count <= 0:
		return picks
	# Track copies already drawn this sample, plus copies the opponent already
	# revealed (so total ≤ COPY_CAP).
	var per_def_used: Dictionary = {}
	for def_id in observed_counts.keys():
		per_def_used[str(def_id)] = int(observed_counts[def_id])
	# Per-call card_id → catalog entry index, built lazily.
	var pool_by_def_id: Dictionary = {}
	var posterior: Dictionary = belief.get("posterior", {}) if not belief.is_empty() else {}
	var has_belief: bool = not posterior.is_empty()
	var memory_by_deck: Dictionary = {}
	if has_belief:
		memory_by_deck = belief.get("memory_by_deck", {})
	while picks.size() < count:
		var picked: Dictionary = {}
		# Try a belief-biased draw first when one is available. Sample a deck
		# from the posterior; pick a remembered card from that deck (still in
		# the legal pool, still under the 3-of cap). On any failure, fall
		# through to the v1 generic draw.
		if has_belief:
			var deck_name := AIDeckFingerprinter.sample_deck(belief, rng)
			if not deck_name.is_empty():
				var remembered: Array = memory_by_deck.get(deck_name, [])
				picked = _draw_from_remembered(remembered, pool_by_def_id, pool, per_def_used, rng)
		if picked.is_empty():
			picked = _draw_from_pool(pool, per_def_used, rng)
		if picked.is_empty():
			break  # Cap exhaustion across the entire pool — bail.
		var def_id := str(picked.get("card_id", ""))
		per_def_used[def_id] = int(per_def_used.get(def_id, 0)) + 1
		picks.append(picked)
	# Fallback: if we couldn't reach `count` due to cap exhaustion, repeat last
	# picks (rare; only happens with very small attribute pools).
	while picks.size() < count and not picks.is_empty():
		picks.append(picks[picks.size() - 1])
	return picks


static func _draw_from_pool(pool: Array, per_def_used: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var attempts := 0
	var max_attempts := 24
	while attempts < max_attempts:
		attempts += 1
		var idx := rng.randi_range(0, pool.size() - 1)
		var card: Dictionary = pool[idx]
		var def_id := str(card.get("card_id", ""))
		if def_id.is_empty():
			continue
		if int(per_def_used.get(def_id, 0)) >= COPY_CAP:
			continue
		return card
	return {}


static func _draw_from_remembered(remembered: Array, pool_by_def_id: Dictionary, pool: Array, per_def_used: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if remembered.is_empty():
		return {}
	# Build the pool lookup lazily on first use of belief biasing.
	if pool_by_def_id.is_empty():
		for entry in pool:
			pool_by_def_id[str(entry.get("card_id", ""))] = entry
	var attempts := 0
	var max_attempts := mini(remembered.size() * 3, 24)
	while attempts < max_attempts:
		attempts += 1
		var def_id := str(remembered[rng.randi_range(0, remembered.size() - 1)])
		if def_id.is_empty():
			continue
		if int(per_def_used.get(def_id, 0)) >= COPY_CAP:
			continue
		var card: Dictionary = pool_by_def_id.get(def_id, {})
		if card.is_empty():
			# Remembered card is outside the attribute pool (unlikely — pool
			# starts with all collectibles when no observation, narrows as
			# observation_attributes grow). Skip and try another remembered
			# card or fall through to generic.
			continue
		return card
	return {}


## Overwrite a card *instance* in the cloned state with a sampled definition's
## data. Preserves instance_id, owner/controller, zone, damage_marked, etc.
static func _overwrite_card(instance: Dictionary, definition: Dictionary) -> void:
	if typeof(instance) != TYPE_DICTIONARY or typeof(definition) != TYPE_DICTIONARY:
		return
	var preserved := {
		"instance_id": instance.get("instance_id", ""),
		"owner_player_id": instance.get("owner_player_id", ""),
		"controller_player_id": instance.get("controller_player_id", ""),
		"zone": instance.get("zone", ""),
	}
	# Clear the existing instance data so we don't leak stale fields.
	instance.clear()
	# Project definition fields (catalog uses base_power/base_health while
	# instances use power/health).
	instance["definition_id"] = str(definition.get("card_id", ""))
	instance["name"] = str(definition.get("name", ""))
	instance["card_type"] = str(definition.get("card_type", "creature"))
	instance["cost"] = int(definition.get("cost", 0))
	instance["power"] = int(definition.get("base_power", 0))
	instance["health"] = int(definition.get("base_health", 0))
	instance["base_power"] = int(definition.get("base_power", 0))
	instance["base_health"] = int(definition.get("base_health", 0))
	instance["attributes"] = definition.get("attributes", []).duplicate(true)
	instance["subtypes"] = definition.get("subtypes", []).duplicate(true)
	instance["keywords"] = definition.get("keywords", []).duplicate(true)
	instance["effect_ids"] = definition.get("effect_ids", []).duplicate(true)
	instance["rules_tags"] = definition.get("rules_tags", []).duplicate(true)
	instance["rules_text"] = str(definition.get("rules_text", ""))
	instance["rarity"] = str(definition.get("rarity", "common"))
	instance["is_unique"] = bool(definition.get("is_unique", false))
	instance["support_uses"] = int(definition.get("support_uses", 0))
	# Forward any optional fields that the engine may reference.
	for key in ["triggered_abilities", "aura", "grants_immunity", "grants_trigger",
			"cost_reduction_aura", "cost_increase_aura", "play_limit_per_turn",
			"magicka_aura", "rally_amount", "rally_boost_aura", "shout_chain_id",
			"shout_level", "shout_levels", "innate_statuses", "self_immunity",
			"first_turn_hand_cost", "first_turn_hand_magicka", "self_cost_reduction",
			"play_condition", "passive_abilities", "attack_condition",
			"transform_on_exhausted", "grants_forced_attack_at_turn_start",
			"equip_power_bonus", "equip_health_bonus", "equip_keywords",
			"action_target_mode", "half_card_ids"]:
		if definition.has(key):
			var value = definition[key]
			if typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY:
				instance[key] = value.duplicate(true)
			else:
				instance[key] = value
	# Restore preserved identity fields.
	instance["instance_id"] = str(preserved["instance_id"])
	instance["owner_player_id"] = str(preserved["owner_player_id"])
	instance["controller_player_id"] = str(preserved["controller_player_id"])
	instance["zone"] = str(preserved["zone"])
	# Reset transient combat state.
	instance["damage_marked"] = 0
	instance["power_bonus"] = 0
	instance["health_bonus"] = 0
	instance["granted_keywords"] = []
	instance["status_markers"] = []
	EvergreenRules.sync_derived_state(instance)
