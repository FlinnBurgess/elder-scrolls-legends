class_name MatchAuras
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")


static func recalculate_auras(match_state: Dictionary) -> Array:
	# Step 1: Clear all aura bonuses on lane creatures, snapshot previous aura keywords
	var _prev_aura_keywords: Dictionary = {}  # instance_id -> Array of keywords
	for lane in match_state.get("lanes", []):
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var iid := str(card.get("instance_id", ""))
				_prev_aura_keywords[iid] = card.get("aura_keywords", []).duplicate()
				card["aura_power_bonus"] = 0
				card["aura_health_bonus"] = 0
				card["aura_keywords"] = []
				card["aura_damage_immune"] = false

	# Step 2: Collect aura sources (lane creatures + support cards), skip silenced
	var aura_sources: Array = []
	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			var slots: Array = player_slots_by_id[player_id]
			for slot_index in range(slots.size()):
				var card = slots[slot_index]
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not card.has("aura"):
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				aura_sources.append({
					"card": card,
					"aura": card["aura"],
					"player_id": str(card.get("controller_player_id", player_id)),
					"lane_index": lane_index,
					"zone": "lane",
				})
	for player in match_state.get("players", []):
		var player_id := str(player.get("player_id", ""))
		for support_card in player.get("support", []):
			if typeof(support_card) != TYPE_DICTIONARY:
				continue
			if not support_card.has("aura"):
				continue
			aura_sources.append({
				"card": support_card,
				"aura": support_card["aura"],
				"player_id": player_id,
				"lane_index": -1,
				"zone": "support",
			})

	# Step 3: Apply each aura
	for source in aura_sources:
		var aura: Dictionary = source["aura"]
		var source_player_id: String = source["player_id"]
		var source_lane_index: int = source["lane_index"]
		var source_card: Dictionary = source["card"]

		# Evaluate condition
		if aura.has("condition") and not _evaluate_aura_condition(match_state, source_card, source_player_id, source_lane_index, aura["condition"]):
			continue

		var power_bonus := int(aura.get("power", 0))
		var health_bonus := int(aura.get("health", 0))
		var aura_kws: Array = aura.get("keywords", [])

		# Handle per_count multiplier
		if bool(aura.get("per_count", false)) and aura.has("condition"):
			var count := _get_aura_condition_count(match_state, source_card, source_player_id, source_lane_index, aura["condition"])
			power_bonus *= count
			health_bonus *= count

		# Find targets
		var targets := _get_aura_targets(match_state, source_card, source_player_id, source_lane_index, aura)
		for target in targets:
			target["aura_power_bonus"] = int(target.get("aura_power_bonus", 0)) + power_bonus
			target["aura_health_bonus"] = int(target.get("aura_health_bonus", 0)) + health_bonus
			for kw in aura_kws:
				var existing: Array = target.get("aura_keywords", [])
				if not existing.has(kw):
					existing.append(kw)
				target["aura_keywords"] = existing

	# Step 3b: Scan for permanent_empower and copy_expertise_abilities passives
	for player in match_state.get("players", []):
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var pid := str(player.get("player_id", ""))
		var has_perm_empower := false
		for lane in lanes:
			for card in lane.get("player_slots", {}).get(pid, []):
				if typeof(card) == TYPE_DICTIONARY and EvergreenRules._has_passive(card, "permanent_empower"):
					has_perm_empower = true
					break
			if has_perm_empower:
				break
		player["_permanent_empower_active"] = has_perm_empower

	# Step 3c: Apply grant_keyword_to_keyword passives
	for lane in lanes:
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var passives = card.get("passive_abilities", [])
				if typeof(passives) != TYPE_ARRAY:
					continue
				for p in passives:
					if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "grant_keyword_to_keyword":
						continue
					var gktk_req_kw := str(p.get("required_keyword", ""))
					var gktk_grant_kw := str(p.get("granted_keyword", ""))
					if gktk_req_kw.is_empty() or gktk_grant_kw.is_empty():
						continue
					var gktk_controller := str(card.get("controller_player_id", ""))
					for gktk_lane in lanes:
						for gktk_target in gktk_lane.get("player_slots", {}).get(gktk_controller, []):
							if typeof(gktk_target) != TYPE_DICTIONARY:
								continue
							if EvergreenRules.has_keyword(gktk_target, gktk_req_kw):
								var gktk_existing: Array = gktk_target.get("aura_keywords", [])
								if not gktk_existing.has(gktk_grant_kw):
									gktk_existing.append(gktk_grant_kw)
									gktk_target["aura_keywords"] = gktk_existing

	# Step 3d: Apply grant_keyword_to_type passives (e.g., items get Mobilize)
	for lane in lanes:
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var passives = card.get("passive_abilities", [])
				if typeof(passives) != TYPE_ARRAY:
					continue
				for p in passives:
					if typeof(p) != TYPE_DICTIONARY or str(p.get("type", "")) != "grant_keyword_to_type":
						continue
					var gktt_kw := str(p.get("keyword", ""))
					var gktt_card_type := str(p.get("card_type", ""))
					if gktt_kw.is_empty() or gktt_card_type.is_empty():
						continue
					var gktt_controller := str(card.get("controller_player_id", ""))
					var gktt_player := MatchTimingHelpers._find_player_by_id(match_state, gktt_controller)
					for gktt_target in gktt_player.get("hand", []):
						if typeof(gktt_target) == TYPE_DICTIONARY and str(gktt_target.get("card_type", "")) == gktt_card_type:
							var gktt_existing: Array = gktt_target.get("aura_keywords", [])
							if not gktt_existing.has(gktt_kw):
								gktt_existing.append(gktt_kw)
								gktt_target["aura_keywords"] = gktt_existing

	# Step 3e: Apply shackled_unless_exalted_ally passives
	for lane in lanes:
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not EvergreenRules._has_passive(card, "shackled_unless_exalted_ally"):
					continue
				var suea_controller := str(card.get("controller_player_id", ""))
				var has_exalted := false
				for check_lane in lanes:
					for check_card in check_lane.get("player_slots", {}).get(suea_controller, []):
						if typeof(check_card) == TYPE_DICTIONARY and EvergreenRules.has_status(check_card, EvergreenRules.STATUS_EXALTED):
							has_exalted = true
							break
					if has_exalted:
						break
				if not has_exalted:
					EvergreenRules.add_status(card, EvergreenRules.STATUS_SHACKLED)
					card["shackle_expires_on_turn"] = -1  # permanent until condition met
				elif EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SHACKLED) and int(card.get("shackle_expires_on_turn", 0)) == -1:
					EvergreenRules.remove_status(card, EvergreenRules.STATUS_SHACKLED)
					card.erase("shackle_expires_on_turn")

	# Step 3f: Apply dict-format grants_immunity aura effects (e.g., Almalexia: exalted creatures immune to damage)
	for lane in lanes:
		var gi_player_slots: Dictionary = lane.get("player_slots", {})
		for player_id in gi_player_slots.keys():
			for card in gi_player_slots[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var gi = card.get("grants_immunity", {})
				if typeof(gi) != TYPE_DICTIONARY:
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				var gi_scope := str(gi.get("scope", ""))
				var gi_condition := str(gi.get("condition", ""))
				var gi_immunity := str(gi.get("immunity", ""))
				if gi_scope != "all_friendly" or gi_immunity != "damage":
					continue
				var gi_controller := str(card.get("controller_player_id", ""))
				for gi_lane in lanes:
					for gi_target in gi_lane.get("player_slots", {}).get(gi_controller, []):
						if typeof(gi_target) != TYPE_DICTIONARY:
							continue
						if gi_condition == "exalted" and not EvergreenRules.has_status(gi_target, EvergreenRules.STATUS_EXALTED):
							continue
						gi_target["aura_damage_immune"] = true

	# Step 4: Recalculate player magicka auras from lane creatures
	for player in match_state.get("players", []):
		var pid := str(player.get("player_id", ""))
		var old_bonus := int(player.get("aura_max_magicka_bonus", 0))
		var new_bonus := 0
		for lane in lanes:
			var player_slots: Dictionary = lane.get("player_slots", {})
			for card in player_slots.get(pid, []):
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if not card.has("magicka_aura"):
					continue
				if EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_SILENCED):
					continue
				new_bonus += int(card["magicka_aura"])
		var delta := new_bonus - old_bonus
		if delta != 0:
			player["max_magicka"] = maxi(0, int(player.get("max_magicka", 0)) + delta)
			player["current_magicka"] = mini(int(player.get("current_magicka", 0)), int(player["max_magicka"]))
			player["aura_max_magicka_bonus"] = new_bonus

	# Step 5: Emit keyword_granted events for newly gained aura keywords
	var aura_keyword_events: Array = []
	for lane in lanes:
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		for player_id in player_slots_by_id.keys():
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				var iid := str(card.get("instance_id", ""))
				var prev: Array = _prev_aura_keywords.get(iid, [])
				for kw in card.get("aura_keywords", []):
					if not prev.has(kw):
						aura_keyword_events.append({
							"event_type": "keyword_granted",
							"source_instance_id": iid,
							"target_instance_id": iid,
							"keyword_id": str(kw),
							"reason": "aura",
						})
	return aura_keyword_events


static func _evaluate_aura_condition(match_state: Dictionary, source_card: Dictionary, player_id: String, lane_index: int, condition) -> bool:
	var condition_type := ""
	if typeof(condition) == TYPE_DICTIONARY:
		condition_type = str(condition.get("type", ""))
	elif typeof(condition) == TYPE_STRING:
		condition_type = condition
	match condition_type:
		"magicka_gte_7":
			var player := MatchTimingHelpers._find_player_by_id(match_state, player_id)
			return int(player.get("max_magicka", 0)) >= 7
		"has_item":
			var items: Array = source_card.get("attached_items", [])
			return not items.is_empty()
		"empty_hand":
			var player := MatchTimingHelpers._find_player_by_id(match_state, player_id)
			var hand: Array = player.get("hand", [])
			return hand.is_empty()
		"most_creatures_in_lane":
			if lane_index < 0:
				return false
			var lanes_arr: Array = match_state.get("lanes", [])
			if lane_index >= lanes_arr.size():
				return false
			var lane: Dictionary = lanes_arr[lane_index]
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			var my_count := 0
			var max_opponent_count := 0
			for pid in player_slots_by_id.keys():
				var count: int = player_slots_by_id[pid].size()
				if str(pid) == player_id:
					my_count = count
				else:
					max_opponent_count = maxi(max_opponent_count, count)
			return my_count > max_opponent_count
		"no_enemies_in_lane":
			if lane_index < 0:
				return false
			var lanes_arr: Array = match_state.get("lanes", [])
			if lane_index >= lanes_arr.size():
				return false
			var lane: Dictionary = lanes_arr[lane_index]
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			for pid in player_slots_by_id.keys():
				if str(pid) != player_id and player_slots_by_id[pid].size() > 0:
					return false
			return true
		"your_turn":
			return str(match_state.get("active_player_id", "")) == player_id
		"count_friendly_with_keyword":
			# Always true — the count is used as a multiplier via per_count
			return true
		"count_hand_cards_by_cost":
			# Always true — the count is used as a multiplier via per_count
			var cost_value := 0
			if typeof(condition) == TYPE_DICTIONARY:
				cost_value = int(condition.get("cost_value", 0))
			var player := MatchTimingHelpers._find_player_by_id(match_state, player_id)
			for card in player.get("hand", []):
				if typeof(card) == TYPE_DICTIONARY and int(card.get("cost", -1)) == cost_value:
					return true
			return false
		"creature_in_each_lane":
			for lane in match_state.get("lanes", []):
				var slots: Array = lane.get("player_slots", {}).get(player_id, [])
				var has_other := false
				var source_instance_id := str(source_card.get("instance_id", ""))
				for card in slots:
					if typeof(card) == TYPE_DICTIONARY and str(card.get("instance_id", "")) != source_instance_id:
						has_other = true
						break
				if not has_other:
					return false
			return true
		"min_max_magicka_18":
			var player := MatchTimingHelpers._find_player_by_id(match_state, player_id)
			return int(player.get("max_magicka", 0)) >= 18
		"has_ward":
			return EvergreenRules.has_keyword(source_card, "ward")
	return false


static func _get_aura_condition_count(match_state: Dictionary, source_card: Dictionary, player_id: String, _lane_index: int, condition) -> int:
	var condition_type := ""
	var keyword_id := ""
	if typeof(condition) == TYPE_DICTIONARY:
		condition_type = str(condition.get("type", ""))
		keyword_id = str(condition.get("keyword", ""))
	elif typeof(condition) == TYPE_STRING:
		condition_type = condition
	if condition_type == "count_friendly_with_keyword" and not keyword_id.is_empty():
		var source_instance_id := str(source_card.get("instance_id", ""))
		var count := 0
		for lane in match_state.get("lanes", []):
			var player_slots_by_id: Dictionary = lane.get("player_slots", {})
			if not player_slots_by_id.has(player_id):
				continue
			for card in player_slots_by_id[player_id]:
				if typeof(card) != TYPE_DICTIONARY:
					continue
				if str(card.get("instance_id", "")) == source_instance_id:
					continue
				if EvergreenRules.has_keyword(card, keyword_id):
					count += 1
		return count
	if condition_type == "count_hand_cards_by_cost":
		var cost_value := 0
		if typeof(condition) == TYPE_DICTIONARY:
			cost_value = int(condition.get("cost_value", 0))
		var player := MatchTimingHelpers._find_player_by_id(match_state, source_card.get("controller_player_id", player_id) as String)
		var count := 0
		for card in player.get("hand", []):
			if typeof(card) == TYPE_DICTIONARY and int(card.get("cost", -1)) == cost_value:
				count += 1
		return count
	return 1


static func _get_aura_targets(match_state: Dictionary, source_card: Dictionary, player_id: String, source_lane_index: int, aura: Dictionary) -> Array:
	var scope: String = str(aura.get("scope", ""))
	var target_filter: String = str(aura.get("target", ""))
	var filter_subtype: String = str(aura.get("filter_subtype", ""))
	var filter_attribute: String = str(aura.get("filter_attribute", ""))
	var source_instance_id := str(source_card.get("instance_id", ""))
	var targets: Array = []

	if scope == "self":
		# Self-aura — only the source card itself (must be in lane)
		if str(source_card.get("zone", source_card.get("card_type", ""))) != "support":
			targets.append(source_card)
		return targets

	var lanes: Array = match_state.get("lanes", [])
	for lane_index in range(lanes.size()):
		if scope == "same_lane" and lane_index != source_lane_index:
			continue
		var lane: Dictionary = lanes[lane_index]
		var player_slots_by_id: Dictionary = lane.get("player_slots", {})
		if not player_slots_by_id.has(player_id):
			continue
		for card in player_slots_by_id[player_id]:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			# "other_friendly" excludes self, "all_friendly" includes self
			if target_filter == "other_friendly" and str(card.get("instance_id", "")) == source_instance_id:
				continue
			if not filter_subtype.is_empty():
				var subtypes: Array = card.get("subtypes", [])
				if not subtypes.has(filter_subtype):
					continue
			if not filter_attribute.is_empty():
				var attributes: Array = card.get("attributes", [])
				if not attributes.has(filter_attribute):
					continue
			var filter_kw: String = str(aura.get("filter_keyword", ""))
			if not filter_kw.is_empty():
				if not EvergreenRules.has_keyword(card, filter_kw):
					continue
			targets.append(card)
	return targets

