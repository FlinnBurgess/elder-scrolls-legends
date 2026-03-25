class_name BoonRules
extends RefCounted


static func apply_boons_to_match_state(match_state: Dictionary, player_id: String, active_boons: Array) -> void:
	match_state["_adventure_boons"] = active_boons.duplicate()
	match_state["_boon_player_id"] = player_id

	# Fortified Spirit: reduce each rune threshold by 1 (non-stackable)
	if "fortified_spirit" in active_boons:
		var player := _get_player(match_state, player_id)
		if not player.is_empty():
			var thresholds: Array = player.get("rune_thresholds", []).duplicate()
			for i in range(thresholds.size()):
				thresholds[i] = maxi(1, int(thresholds[i]) - 1)
			player["rune_thresholds"] = thresholds

	# Runic Ward: store charges so each rune break can consume one
	var rw_stacks := _count_stacks(active_boons, "runic_ward")
	if rw_stacks > 0:
		var player := _get_player(match_state, player_id)
		if not player.is_empty():
			player["_runic_ward_charges"] = rw_stacks


static func inject_boon_triggers(match_state: Dictionary, registry: Array) -> void:
	var active_boons = match_state.get("_adventure_boons", [])
	if typeof(active_boons) != TYPE_ARRAY or active_boons.is_empty():
		return
	var player_id: String = str(match_state.get("_boon_player_id", ""))
	if player_id.is_empty():
		return

	# Marked for Death: when enemy creature dies, deal 1 damage per stack to enemy nexus
	var mfd_stacks := _count_stacks(active_boons, "marked_for_death")
	if mfd_stacks > 0:
		registry.append(_make_trigger("boon_marked_for_death", player_id, {
			"family": "on_friendly_creature_death_count",
			"effects": [{"op": "boon_marked_for_death", "stacks": mfd_stacks}]
		}))

	# Soul Tear: when friendly creature dies, generate a random creature of same cost to hand
	if "soul_tear" in active_boons:
		registry.append(_make_trigger("boon_soul_tear", player_id, {
			"family": "on_friendly_death",
			"effects": [{"op": "boon_soul_tear"}]
		}))

	# First Lesson: first action each turn costs N less (1 per stack)
	var fl_stacks := _count_stacks(active_boons, "first_lesson")
	if fl_stacks > 0:
		registry.append(_make_trigger("boon_first_lesson", player_id, {
			"family": "start_of_turn",
			"effects": [{"op": "boon_first_lesson", "stacks": fl_stacks}]
		}))

	# Battleground: creatures played into the field lane get Cover
	if "battleground" in active_boons:
		registry.append(_make_trigger("boon_battleground", player_id, {
			"family": "on_friendly_summon",
			"effects": [{"op": "boon_battleground"}]
		}))

	# Shattered Fate: creatures summoned during prophecy gain +stacks/+stacks
	var sf_stacks := _count_stacks(active_boons, "shattered_fate")
	if sf_stacks > 0:
		registry.append(_make_trigger("boon_shattered_fate", player_id, {
			"family": "on_friendly_summon",
			"effects": [{"op": "boon_shattered_fate", "stacks": sf_stacks}]
		}))

	# Harbinger's Call: start of turn, if no friendly creatures, summon a creature of cost = stacks
	var hc_stacks := _count_stacks(active_boons, "harbingers_call")
	if hc_stacks > 0:
		registry.append(_make_trigger("boon_harbingers_call", player_id, {
			"family": "start_of_turn",
			"effects": [{"op": "boon_harbingers_call", "stacks": hc_stacks}]
		}))

	# Holy Ground: start of turn, buff all friendly field lane creatures +0/+stacks
	var hg_stacks := _count_stacks(active_boons, "holy_ground")
	if hg_stacks > 0:
		registry.append(_make_trigger("boon_holy_ground", player_id, {
			"family": "start_of_turn",
			"effects": [{"op": "boon_holy_ground", "stacks": hg_stacks}]
		}))

	# Runic Ward: on rune break, if charges remain, summon a 2/4 Guard
	if int((_get_player(match_state, player_id)).get("_runic_ward_charges", 0)) > 0:
		registry.append(_make_trigger("boon_runic_ward", player_id, {
			"family": "rune_break",
			"effects": [{"op": "boon_runic_ward"}]
		}))

	# Prophet's Sight is handled directly in _resume_pending_rune_breaks (not via trigger)


static func _make_trigger(boon_id: String, player_id: String, descriptor: Dictionary) -> Dictionary:
	return {
		"trigger_id": boon_id,
		"trigger_index": -1,
		"source_instance_id": boon_id,
		"owner_player_id": player_id,
		"controller_player_id": player_id,
		"source_zone": "generated",
		"lane_index": -1,
		"slot_index": -1,
		"descriptor": descriptor,
	}


static func _count_stacks(active_boons: Array, boon_id: String) -> int:
	var count := 0
	for b in active_boons:
		if str(b) == boon_id:
			count += 1
	return count


static func _get_player(match_state: Dictionary, player_id: String) -> Dictionary:
	for player in match_state.get("players", []):
		if str(player.get("player_id", "")) == player_id:
			return player
	return {}
