class_name EffectMovement
extends RefCounted

const EvergreenRules = preload("res://src/core/match/evergreen_rules.gd")
const ExtendedMechanicPacks = preload("res://src/core/match/extended_mechanic_packs.gd")
const MatchMutations = preload("res://src/core/match/match_mutations.gd")
const MatchTimingHelpers = preload("res://src/core/match/match_timing_helpers.gd")
const MatchEffectParams = preload("res://src/core/match/match_effect_params.gd")
const MatchAuras = preload("res://src/core/match/match_auras.gd")
const MatchTriggers = preload("res://src/core/match/match_triggers.gd")
const MatchTargeting = preload("res://src/core/match/match_targeting.gd")
const MatchSummonTiming = preload("res://src/core/match/match_summon_timing.gd")
const GameLogger = preload("res://src/core/match/game_logger.gd")

const ZONE_HAND := "hand"
const ZONE_DECK := "deck"
const ZONE_LANE := "lane"
const ZONE_SUPPORT := "support"
const ZONE_DISCARD := "discard"
const ZONE_BANISHED := "banished"
const ZONE_GENERATED := "generated"
const CARD_TYPE_CREATURE := "creature"
const CARD_TYPE_ACTION := "action"
const CARD_TYPE_ITEM := "item"
const CARD_TYPE_SUPPORT := "support"
const EVENT_CREATURE_SUMMONED := "creature_summoned"
const EVENT_CARD_PLAYED := "card_played"
const EVENT_DAMAGE_RESOLVED := "damage_resolved"
const EVENT_CREATURE_DESTROYED := "creature_destroyed"
const EVENT_CARD_DRAWN := "card_drawn"
const EVENT_RUNE_BROKEN := "rune_broken"
const EVENT_CREATURE_CONSUMED := "card_consumed"
const EVENT_CREATURE_SACRIFICED := "card_sacrificed"
const EVENT_CARD_EQUIPPED := "card_equipped"
const EVENT_CARD_OVERDRAW := "card_overdraw"
const FAMILY_SUMMON := "summon"
const FAMILY_LAST_GASP := "last_gasp"
const FAMILY_SLAY := "slay"
const FAMILY_PILFER := "pilfer"
const FAMILY_EXPERTISE := "expertise"
const FAMILY_ON_PLAY := "on_play"
const FAMILY_EXALT := "exalt"
const FAMILY_WAX := "wax"
const FAMILY_WANE := "wane"
const FAMILY_ON_EQUIP := "on_equip"
const FAMILY_ACTIVATE := "activate"
const FAMILY_VETERAN := "veteran"
const RULE_TAG_PROPHECY := "prophecy"
const WINDOW_AFTER := "after"
const WINDOW_IMMEDIATE := "immediate"
const MAX_HAND_SIZE := 10
const RANDOM_KEYWORD_POOL := ["breakthrough", "charge", "drain", "guard", "lethal", "regenerate", "ward"]

static func _MT():
	return load("res://src/core/match/match_timing.gd")


static func apply(op: String, match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary, generated_events: Array, ctx: Dictionary) -> void:
	var descriptor: Dictionary = ctx.get("descriptor", {})
	var reason: String = ctx.get("reason", "trigger")
	match op:
		"move_between_lanes":
			var raw_lane_id := str(effect.get("lane_id", effect.get("target_lane_id", event.get("lane_id", ""))))
			if raw_lane_id == "self_lane":
				var _sl_idx := int(trigger.get("lane_index", -1))
				var _sl_lanes: Array = match_state.get("lanes", [])
				if _sl_idx >= 0 and _sl_idx < _sl_lanes.size():
					raw_lane_id = str(_sl_lanes[_sl_idx].get("lane_id", ""))
				else:
					raw_lane_id = ""
			if raw_lane_id != "other_lane" and raw_lane_id.is_empty():
				return
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var dest_lane_id := raw_lane_id
				if dest_lane_id == "other_lane":
					var card_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					var current_lane_id := str(card_location.get("lane_id", ""))
					dest_lane_id = ""
					for lane in match_state.get("lanes", []):
						var lid := str(lane.get("lane_id", ""))
						if lid != current_lane_id and not lid.is_empty():
							dest_lane_id = lid
							break
				if dest_lane_id.is_empty():
					return
				var move_opts := {
					"slot_index": int(effect.get("slot_index", -1)),
					"preserve_entered_lane_on_turn": true,
				}
				if bool(effect.get("ignore_capacity", false)):
					move_opts["ignore_capacity"] = true
				var move_result := MatchMutations.move_card_between_lanes(match_state, str(card.get("controller_player_id", "")), str(card.get("instance_id", "")), dest_lane_id, move_opts)
				if bool(move_result.get("is_valid", false)):
					var moved_ids: Array = trigger.get("_moved_creature_ids", [])
					moved_ids.append(str(card.get("instance_id", "")))
					trigger["_moved_creature_ids"] = moved_ids
				generated_events.append_array(move_result.get("events", []))
				if bool(move_result.get("granted_cover", false)):
					generated_events.append({
						"event_type": "status_granted",
						"source_instance_id": str(card.get("instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"status_id": "cover",
					})
		"may_move_between_lanes":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var mml_controller := str(card.get("controller_player_id", ""))
				var mml_loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				if bool(mml_loc.get("is_valid", false)):
					var mml_current_lane := str(mml_loc.get("lane_id", ""))
					var mml_target_lane := "shadow" if mml_current_lane == "field" else "field"
					var mml_result := MatchMutations.move_card_between_lanes(match_state, mml_controller, str(card.get("instance_id", "")), mml_target_lane)
					if bool(mml_result.get("is_valid", false)):
						generated_events.append_array(mml_result.get("events", []))
		"move_back_end_of_turn":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var mbeot_pending: Array = match_state.get("pending_move_backs", [])
				mbeot_pending.append(str(card.get("instance_id", "")))
				match_state["pending_move_backs"] = mbeot_pending
				generated_events.append({"event_type": "move_back_scheduled", "instance_id": str(card.get("instance_id", "")), "reason": reason})
		"unsummon":
			var unsummon_cost_reduction := int(effect.get("cost_reduction", 0))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var unsummon_result := MatchMutations.unsummon_card(match_state, str(card.get("instance_id", "")))
				generated_events.append_array(unsummon_result.get("events", []))
				if unsummon_cost_reduction > 0 and bool(unsummon_result.get("is_valid", false)):
					card["cost"] = maxi(0, int(card.get("cost", 0)) - unsummon_cost_reduction)
		"unsummon_end_of_turn":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var ueot_pending: Array = match_state.get("pending_end_of_turn_unsummons", [])
				ueot_pending.append(str(card.get("instance_id", "")))
				match_state["pending_end_of_turn_unsummons"] = ueot_pending
				generated_events.append({"event_type": "unsummon_scheduled", "instance_id": str(card.get("instance_id", "")), "reason": reason})
		"return_to_hand":
			var source_card := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not source_card.is_empty():
				var rth_owner_id := str(source_card.get("owner_player_id", ""))
				var rth_player := MatchTimingHelpers._get_player_state(match_state, rth_owner_id)
				if not rth_player.is_empty() and rth_player.get(ZONE_HAND, []).size() >= MAX_HAND_SIZE:
					var move_result := MatchMutations.move_card_to_zone(match_state, str(source_card.get("instance_id", "")), ZONE_DISCARD, {"reason": reason})
					generated_events.append_array(move_result.get("events", []))
					generated_events.append({
						"event_type": EVENT_CARD_OVERDRAW,
						"player_id": rth_owner_id,
						"instance_id": str(source_card.get("instance_id", "")),
						"card_name": str(source_card.get("name", "")),
						"source_zone": str(source_card.get("zone", "")),
					})
				else:
					var move_result := MatchMutations.move_card_to_zone(match_state, str(source_card.get("instance_id", "")), ZONE_HAND, {"reason": reason})
					generated_events.append_array(move_result.get("events", []))
					generated_events.append({
						"event_type": EVENT_CARD_DRAWN,
						"player_id": rth_owner_id,
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"drawn_instance_id": str(source_card.get("instance_id", "")),
						"reason": reason,
					})
		"return_to_deck_and_draw_later":
			var rtdadl_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not rtdadl_source.is_empty():
				var rtdadl_controller := str(rtdadl_source.get("controller_player_id", ""))
				var rtdadl_template: Dictionary = effect.get("card_template", {})
				if rtdadl_template.is_empty():
					rtdadl_template = rtdadl_source.duplicate(true)
				var rtdadl_move := MatchMutations.move_card_to_zone(match_state, str(rtdadl_source.get("instance_id", "")), ZONE_DECK, {"reason": reason})
				generated_events.append_array(rtdadl_move.get("events", []))
		"return_stolen":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var rs_original_owner := str(card.get("original_owner_player_id", card.get("owner_player_id", "")))
				var rs_controller := str(card.get("controller_player_id", ""))
				if rs_original_owner != rs_controller and not rs_original_owner.is_empty():
					var rs_steal := MatchMutations.steal_card(match_state, rs_original_owner, str(card.get("instance_id", "")), {})
					generated_events.append_array(rs_steal.get("events", []))
		"return_equipped_items_to_hand":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var reith_items: Array = card.get("attached_items", [])
				var reith_ids: Array = []
				for reith_item in reith_items:
					reith_ids.append(str(reith_item.get("instance_id", "")))
				for reith_id in reith_ids:
					var reith_move := MatchMutations.move_card_to_zone(match_state, reith_id, ZONE_HAND, {"reason": reason})
					generated_events.append({"event_type": "attached_item_detached", "source_instance_id": str(trigger.get("source_instance_id", "")), "host_instance_id": str(card.get("instance_id", "")), "item_instance_id": reith_id})
					generated_events.append_array(reith_move.get("events", []))
		"steal":
			var stealing_players := MatchTargeting._resolve_player_targets(match_state, trigger, event, effect)
			if stealing_players.is_empty():
				return
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var steal_result := MatchMutations.steal_card(match_state, stealing_players[0], str(card.get("instance_id", "")), {
					"slot_index": int(effect.get("slot_index", -1)),
				})
				generated_events.append_array(steal_result.get("events", []))
				if bool(steal_result.get("is_valid", false)):
					var steal_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
					if not steal_source.is_empty():
						steal_source["_stolen_instance_id"] = str(card.get("instance_id", ""))
					var steal_kw := str(effect.get("grant_keyword", ""))
					if not steal_kw.is_empty():
						EvergreenRules.ensure_card_state(card)
						var steal_granted: Array = card.get("granted_keywords", [])
						if not steal_granted.has(steal_kw):
							steal_granted.append(steal_kw)
							card["granted_keywords"] = steal_granted
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": steal_kw})
					if bool(effect.get("temporary", false)):
						card["_stolen_temporarily"] = true
						card["_stolen_return_to"] = str(card.get("owner_player_id", ""))
						card["_stolen_on_turn"] = int(match_state.get("turn_number", 0))
		"banish":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var banish_result := MatchMutations.banish_card(match_state, str(card.get("instance_id", "")))
				generated_events.append_array(banish_result.get("events", []))
		"banish_and_return_end_of_turn":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var bar_controller_id := str(card.get("controller_player_id", card.get("owner_player_id", "")))
				var bar_location := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
				var bar_lane_id := str(bar_location.get("lane_id", ""))
				var bar_snapshot: Dictionary = card.duplicate(true)
				var bar_result := MatchMutations.banish_card(match_state, str(card.get("instance_id", "")))
				generated_events.append_array(bar_result.get("events", []))
				if bool(bar_result.get("is_valid", false)):
					var pending: Array = match_state.get("pending_eot_returns", [])
					pending.append({
						"card_snapshot": bar_snapshot,
						"controller_player_id": bar_controller_id,
						"lane_id": bar_lane_id,
						"turn_number": int(match_state.get("turn_number", 0)),
					})
					match_state["pending_eot_returns"] = pending
		"banish_discard_pile":
			var bdp_controller_id := str(trigger.get("controller_player_id", ""))
			var bdp_target := str(effect.get("target_player", "opponent"))
			var bdp_player_id := bdp_controller_id if bdp_target == "controller" else MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), bdp_controller_id)
			var bdp_player := MatchTimingHelpers._get_player_state(match_state, bdp_player_id)
			if not bdp_player.is_empty():
				var bdp_discard: Array = bdp_player.get(ZONE_DISCARD, [])
				var bdp_ids: Array = []
				for bdp_card in bdp_discard:
					bdp_ids.append(str(bdp_card.get("instance_id", "")))
				for bdp_id in bdp_ids:
					var bdp_result := MatchMutations.banish_card(match_state, bdp_id, {"reason": reason})
					generated_events.append_array(bdp_result.get("events", []))
		"steal_from_discard", "draw_from_opponent_discard":
			var sfd_controller_id := str(trigger.get("controller_player_id", ""))
			var sfd_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), sfd_controller_id)
			var sfd_opponent := MatchTimingHelpers._get_player_state(match_state, sfd_opponent_id)
			var sfd_controller := MatchTimingHelpers._get_player_state(match_state, sfd_controller_id)
			if not sfd_opponent.is_empty() and not sfd_controller.is_empty():
				var sfd_discard: Array = sfd_opponent.get(ZONE_DISCARD, [])
				if not sfd_discard.is_empty():
					var sfd_filter := str(effect.get("filter_card_type", ""))
					var sfd_candidates: Array = []
					for sfd_card in sfd_discard:
						if sfd_filter.is_empty() or str(sfd_card.get("card_type", "")) == sfd_filter:
							sfd_candidates.append(sfd_card)
					if not sfd_candidates.is_empty():
						var sfd_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_steal_discard", sfd_candidates.size())
						var sfd_stolen: Dictionary = sfd_candidates[sfd_idx]
						sfd_discard.erase(sfd_stolen)
						MatchMutations.restore_definition_state(sfd_stolen)
						sfd_stolen["zone"] = ZONE_HAND
						sfd_stolen["controller_player_id"] = sfd_controller_id
						sfd_stolen["owner_player_id"] = sfd_controller_id
						var sfd_hand: Array = sfd_controller.get(ZONE_HAND, [])
						sfd_hand.append(sfd_stolen)
						generated_events.append({
							"event_type": "card_stolen_from_discard",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"stolen_instance_id": str(sfd_stolen.get("instance_id", "")),
							"from_player_id": sfd_opponent_id,
							"to_player_id": sfd_controller_id,
						})
		"banish_from_opponent_deck", "banish_by_name_from_opponent":
			var bfod_controller_id := str(trigger.get("controller_player_id", ""))
			var bfod_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), bfod_controller_id)
			var bfod_count := int(effect.get("count", 2))
			var bfod_count_per_attr := int(effect.get("count_per_attribute", 0))
			if bfod_count_per_attr > 0:
				var bfod_opp_attrs := MatchTimingHelpers._count_player_attributes(match_state, bfod_opponent_id)
				var bfod_empower_bonus := int(effect.get("empower_bonus", 0))
				var bfod_per_attr := bfod_count_per_attr
				if bfod_empower_bonus > 0:
					bfod_per_attr += bfod_empower_bonus * MatchTimingHelpers._get_empower_amount(match_state, bfod_controller_id)
				bfod_count = bfod_per_attr * bfod_opp_attrs
			else:
				var bfod_empower_bonus := int(effect.get("empower_bonus", 0))
				if bfod_empower_bonus > 0:
					bfod_count += bfod_empower_bonus * MatchTimingHelpers._get_empower_amount(match_state, bfod_controller_id)
			var bfod_opponent := MatchTimingHelpers._get_player_state(match_state, bfod_opponent_id)
			if not bfod_opponent.is_empty():
				var bfod_deck: Array = bfod_opponent.get(ZONE_DECK, [])
				var banished_count := 0
				var bfod_ids: Array = []
				for bfod_card in bfod_deck:
					bfod_ids.append(str(bfod_card.get("instance_id", "")))
				for bfod_id in bfod_ids:
					if banished_count >= bfod_count:
						break
					var bfod_result := MatchMutations.banish_card(match_state, bfod_id, {"reason": reason})
					generated_events.append_array(bfod_result.get("events", []))
					banished_count += 1
		"shuffle_into_deck":
			var sid_template: Dictionary = effect.get("card_template", {})
			if not sid_template.is_empty():
				for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
					var sid_card := MatchMutations.build_generated_card(match_state, player_id, sid_template)
					var sid_player := MatchTimingHelpers._get_player_state(match_state, player_id)
					if sid_player.is_empty():
						return
					var sid_deck: Array = sid_player.get(ZONE_DECK, [])
					sid_card["zone"] = ZONE_DECK
					var sid_pos := MatchEffectParams._deterministic_index(match_state, str(sid_card.get("instance_id", "")), sid_deck.size() + 1)
					sid_deck.insert(sid_pos, sid_card)
					generated_events.append({"event_type": "card_shuffled_to_deck", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "inserted_instance_id": str(sid_card.get("instance_id", "")), "reason": reason})
		"shuffle_copies_to_deck":
			var sctd_count := int(effect.get("count", 1))
			var sctd_cost_override: Variant = effect.get("cost_override", null)
			var sctd_controller := str(trigger.get("controller_player_id", ""))
			var sctd_player := MatchTimingHelpers._get_player_state(match_state, sctd_controller)
			var sctd_source_id := str(event.get("source_instance_id", trigger.get("source_instance_id", "")))
			var sctd_source := MatchTimingHelpers._find_card_anywhere(match_state, sctd_source_id)
			if not sctd_player.is_empty() and not sctd_source.is_empty():
				var sctd_deck: Array = sctd_player.get(ZONE_DECK, [])
				for ci in range(sctd_count):
					var copy_template: Dictionary = sctd_source.duplicate(true)
					copy_template.erase("instance_id")
					copy_template.erase("status_markers")
					if sctd_cost_override != null:
						copy_template["cost"] = int(sctd_cost_override)
					var sctd_copy := MatchMutations.build_generated_card(match_state, sctd_controller, copy_template)
					sctd_copy["zone"] = ZONE_DECK
					var insert_pos := MatchEffectParams._deterministic_index(match_state, str(sctd_copy.get("instance_id", "")) + "_sctd", sctd_deck.size() + 1)
					sctd_deck.insert(insert_pos, sctd_copy)
				generated_events.append({"event_type": "copies_shuffled_to_deck", "player_id": sctd_controller, "count": sctd_count, "reason": reason})
		"shuffle_copies_into_deck":
			var scid_template: Dictionary = effect.get("card_template", {})
			var scid_count := int(effect.get("count", 2))
			if not scid_template.is_empty():
				for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
					var scid_player := MatchTimingHelpers._get_player_state(match_state, player_id)
					if scid_player.is_empty():
						return
					var scid_deck: Array = scid_player.get(ZONE_DECK, [])
					for _i in range(scid_count):
						var scid_card := MatchMutations.build_generated_card(match_state, player_id, scid_template)
						scid_card["zone"] = ZONE_DECK
						var scid_pos := MatchEffectParams._deterministic_index(match_state, str(scid_card.get("instance_id", "")), scid_deck.size() + 1)
						scid_deck.insert(scid_pos, scid_card)
						generated_events.append({"event_type": "card_shuffled_to_deck", "player_id": player_id, "source_instance_id": str(trigger.get("source_instance_id", "")), "inserted_instance_id": str(scid_card.get("instance_id", "")), "reason": reason})
		"shuffle_self_into_deck":
			var ssid_source_id := str(trigger.get("source_instance_id", ""))
			var ssid_source := MatchTimingHelpers._find_card_anywhere(match_state, ssid_source_id)
			if not ssid_source.is_empty():
				var ssid_controller := str(ssid_source.get("controller_player_id", ""))
				var ssid_template: Dictionary = effect.get("card_template", {})
				if not ssid_template.is_empty():
					MatchMutations.change_card(ssid_source, ssid_template)
				var ssid_power_bonus := int(effect.get("stat_bonus_power", 0))
				var ssid_health_bonus := int(effect.get("stat_bonus_health", 0))
				var ssid_cost_increase := int(effect.get("cost_increase", 0))
				if ssid_power_bonus != 0:
					ssid_source["power_bonus"] = int(ssid_source.get("power_bonus", 0)) + ssid_power_bonus
				if ssid_health_bonus != 0:
					ssid_source["health_bonus"] = int(ssid_source.get("health_bonus", 0)) + ssid_health_bonus
				if ssid_cost_increase != 0:
					ssid_source["cost"] = int(ssid_source.get("cost", 0)) + ssid_cost_increase
				EvergreenRules.sync_derived_state(ssid_source)
				var ssid_move := MatchMutations.move_card_to_zone(match_state, ssid_source_id, ZONE_DECK, {"reason": reason})
				generated_events.append_array(ssid_move.get("events", []))
				var ssid_player := MatchTimingHelpers._get_player_state(match_state, ssid_controller)
				if not ssid_player.is_empty():
					var ssid_deck: Array = ssid_player.get(ZONE_DECK, [])
					var ssid_idx := ssid_deck.find(ssid_source)
					if ssid_idx >= 0:
						ssid_deck.remove_at(ssid_idx)
						var new_pos := MatchEffectParams._deterministic_index(match_state, ssid_source_id + "_shuffle", ssid_deck.size() + 1)
						ssid_deck.insert(new_pos, ssid_source)
		"shuffle_hand_to_deck_and_draw":
			var shuffle_filter_tag := str(effect.get("required_rules_tag", ""))
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var shuffle_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if shuffle_player.is_empty():
					return
				var hand: Array = shuffle_player.get(ZONE_HAND, [])
				var deck: Array = shuffle_player.get(ZONE_DECK, [])
				var to_shuffle: Array = []
				for hi in range(hand.size() - 1, -1, -1):
					var h_card = hand[hi]
					if typeof(h_card) != TYPE_DICTIONARY:
						return
					if not shuffle_filter_tag.is_empty():
						var tags = h_card.get("rules_tags", [])
						if typeof(tags) != TYPE_ARRAY or not tags.has(shuffle_filter_tag):
							return
					to_shuffle.append(h_card)
					hand.remove_at(hi)
				var draw_count := to_shuffle.size()
				for shuffled_card in to_shuffle:
					shuffled_card["zone"] = ZONE_DECK
					var ins_pos := MatchEffectParams._deterministic_index(match_state, str(shuffled_card.get("instance_id", "")) + "_shuffle_back", deck.size() + 1)
					deck.insert(ins_pos, shuffled_card)
				if draw_count > 0:
					var redraw_result = _MT().draw_cards(match_state, player_id, draw_count, {"reason": reason, "source_instance_id": str(trigger.get("source_instance_id", ""))})
					generated_events.append_array(redraw_result.get("events", []))
		"shuffle_all_creatures_into_deck":
			var sacid_all := MatchTimingHelpers._all_lane_creatures(match_state)
			generated_events.append({"event_type": "all_creatures_shuffled", "source_instance_id": str(trigger.get("source_instance_id", "")), "count": sacid_all.size()})
			var sacid_ids: Array = []
			for card in sacid_all:
				sacid_ids.append({"id": str(card.get("instance_id", "")), "controller": str(card.get("controller_player_id", ""))})
			for entry in sacid_ids:
				var sacid_move := MatchMutations.move_card_to_zone(match_state, entry["id"], ZONE_DECK, {"reason": reason})
				generated_events.append_array(sacid_move.get("events", []))
				var sacid_player := MatchTimingHelpers._get_player_state(match_state, entry["controller"])
				if not sacid_player.is_empty():
					var sacid_deck: Array = sacid_player.get(ZONE_DECK, [])
					var sacid_card_idx := -1
					for i in range(sacid_deck.size()):
						if str(sacid_deck[i].get("instance_id", "")) == entry["id"]:
							sacid_card_idx = i
							break
					if sacid_card_idx >= 0:
						var sacid_card: Dictionary = sacid_deck[sacid_card_idx]
						sacid_deck.remove_at(sacid_card_idx)
						var sacid_new_pos := MatchEffectParams._deterministic_index(match_state, entry["id"] + "_shuffle_all", sacid_deck.size() + 1)
						sacid_deck.insert(sacid_new_pos, sacid_card)
		"shuffle_discard_creatures_to_deck_with_buff":
			var sdctd_power := int(effect.get("power", 0))
			var sdctd_health := int(effect.get("health", 0))
			var sdctd_controller := str(trigger.get("controller_player_id", ""))
			var sdctd_player := MatchTimingHelpers._get_player_state(match_state, sdctd_controller)
			if not sdctd_player.is_empty():
				var sdctd_discard: Array = sdctd_player.get(ZONE_DISCARD, [])
				var sdctd_deck: Array = sdctd_player.get(ZONE_DECK, [])
				var sdctd_to_move: Array = []
				for card in sdctd_discard:
					if typeof(card) == TYPE_DICTIONARY and str(card.get("card_type", "")) == "creature":
						sdctd_to_move.append(card)
				for card in sdctd_to_move:
					sdctd_discard.erase(card)
					MatchMutations.restore_definition_state(card)
					EvergreenRules.apply_stat_bonus(card, sdctd_power, sdctd_health, reason)
					card["zone"] = ZONE_DECK
					var insert_pos := MatchEffectParams._deterministic_index(match_state, str(card.get("instance_id", "")) + "_sdctd", sdctd_deck.size() + 1)
					sdctd_deck.insert(insert_pos, card)
				generated_events.append({"event_type": "discard_shuffled_to_deck", "player_id": sdctd_controller, "count": sdctd_to_move.size(), "power_buff": sdctd_power, "health_buff": sdctd_health, "reason": reason})
		"discard":
			var discard_targets := [] if effect.has("target_player") and not effect.has("target") else MatchTargeting._resolve_card_targets(match_state, trigger, event, effect)
			if discard_targets.is_empty() and effect.has("target_player"):
				for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
					var discard_result := MatchMutations.discard_from_hand(match_state, player_id, int(effect.get("count", 1)), {
						"selection": str(effect.get("selection", "front")),
					})
					generated_events.append_array(discard_result.get("events", []))
			else:
				for card in discard_targets:
					var discard_result := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
					generated_events.append_array(discard_result.get("events", []))
		"discard_hand":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if player.is_empty():
					return
				var hand: Array = player.get(ZONE_HAND, [])
				var discard: Array = player.get(ZONE_DISCARD, [])
				for card in hand:
					if typeof(card) == TYPE_DICTIONARY:
						card["zone"] = ZONE_DISCARD
						discard.append(card)
						generated_events.append({"event_type": "card_discarded", "player_id": player_id, "instance_id": str(card.get("instance_id", "")), "source": "discard_hand", "reason": reason})
				hand.clear()
		"discard_hand_end_of_turn":
			var dheoet_player_id := str(trigger.get("controller_player_id", ""))
			var dheoet_pending: Array = match_state.get("pending_end_of_turn_discards", [])
			dheoet_pending.append(dheoet_player_id)
			match_state["pending_end_of_turn_discards"] = dheoet_pending
			generated_events.append({"event_type": "discard_hand_scheduled", "player_id": dheoet_player_id, "reason": reason})
		"discard_top_of_deck":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if player.is_empty():
					return
				var deck: Array = player.get(ZONE_DECK, [])
				if deck.is_empty():
					return
				var top_card: Dictionary = deck.pop_back()
				top_card["zone"] = ZONE_DISCARD
				var discard: Array = player.get(ZONE_DISCARD, [])
				discard.append(top_card)
				generated_events.append({
					"event_type": "card_discarded",
					"player_id": player_id,
					"instance_id": str(top_card.get("instance_id", "")),
					"source": "discard_top_of_deck",
					"reason": reason,
				})
		"discard_from_hand":
			var dfh_controller_id := str(trigger.get("controller_player_id", ""))
			var dfh_target_player := str(effect.get("target_player", "controller"))
			var dfh_player_id := dfh_controller_id if dfh_target_player == "controller" else MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), dfh_controller_id)
			var dfh_count := int(effect.get("count", 1))
			var dfh_result := MatchMutations.discard_from_hand(match_state, dfh_player_id, dfh_count, {"reason": reason})
			generated_events.append_array(dfh_result.get("events", []))
		"discard_random":
			var dr_controller_id := str(trigger.get("controller_player_id", ""))
			var dr_target_player := str(effect.get("target_player", "opponent"))
			var dr_player_id := dr_controller_id if dr_target_player == "controller" else MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), dr_controller_id)
			var dr_player := MatchTimingHelpers._get_player_state(match_state, dr_player_id)
			if not dr_player.is_empty():
				var dr_hand: Array = dr_player.get(ZONE_HAND, [])
				if not dr_hand.is_empty():
					var dr_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_discard_random", dr_hand.size())
					var dr_card: Dictionary = dr_hand[dr_idx]
					var dr_discard_result := MatchMutations.discard_card(match_state, str(dr_card.get("instance_id", "")), {"reason": reason})
					generated_events.append_array(dr_discard_result.get("events", []))
		"discard_matching_from_opponent_deck":
			var dmfod_controller_id := str(trigger.get("controller_player_id", ""))
			var dmfod_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), dmfod_controller_id)
			var dmfod_opponent := MatchTimingHelpers._get_player_state(match_state, dmfod_opponent_id)
			var dmfod_target_name := ""
			for dmfod_card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				dmfod_target_name = str(dmfod_card.get("name", ""))
				break
			if not dmfod_opponent.is_empty() and not dmfod_target_name.is_empty():
				var dmfod_deck: Array = dmfod_opponent.get(ZONE_DECK, [])
				var dmfod_ids: Array = []
				for dmfod_card in dmfod_deck:
					if str(dmfod_card.get("name", "")) == dmfod_target_name:
						dmfod_ids.append(str(dmfod_card.get("instance_id", "")))
				for dmfod_id in dmfod_ids:
					var dmfod_result := MatchMutations.discard_card(match_state, dmfod_id, {"reason": reason})
					generated_events.append_array(dmfod_result.get("events", []))
		"mill":
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var mill_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if mill_player.is_empty():
					return
				var mill_deck: Array = mill_player.get(ZONE_DECK, [])
				var mill_discard: Array = mill_player.get(ZONE_DISCARD, [])
				var mill_count := int(effect.get("count", 1))
				for _i in range(mill_count):
					if mill_deck.is_empty():
						break
					var milled_card: Dictionary = mill_deck.pop_back()
					milled_card["zone"] = ZONE_DISCARD
					mill_discard.push_front(milled_card)
					generated_events.append({
						"event_type": "card_milled",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"player_id": player_id,
						"milled_instance_id": str(milled_card.get("instance_id", "")),
					})
