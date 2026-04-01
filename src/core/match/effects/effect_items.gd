class_name EffectItems
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
		"equip_items_from_discard":
			var equip_self := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if equip_self.is_empty():
				return
			var equip_count := int(effect.get("count", 2))
			for player_id in MatchTargeting._resolve_player_targets(match_state, trigger, event, effect):
				var equip_player := MatchTimingHelpers._get_player_state(match_state, player_id)
				if equip_player.is_empty():
					return
				var equip_discard: Array = equip_player.get(ZONE_DISCARD, [])
				var item_candidates: Array = []
				for edi in range(equip_discard.size()):
					var ed_card = equip_discard[edi]
					if typeof(ed_card) == TYPE_DICTIONARY and str(ed_card.get("card_type", "")) == CARD_TYPE_ITEM:
						item_candidates.append({"index": edi, "cost": int(ed_card.get("cost", 0))})
				item_candidates.sort_custom(func(a, b): return int(a.get("cost", 0)) > int(b.get("cost", 0)))
				var equipped := 0
				for candidate in item_candidates:
					if equipped >= equip_count:
						break
					var pick_idx: int = int(candidate.get("index", 0))
					for already_equipped in range(equipped):
						if pick_idx > 0:
							pick_idx -= 1
					var actual_item: Dictionary = equip_discard[pick_idx]
					equip_discard.remove_at(pick_idx)
					MatchMutations.restore_definition_state(actual_item)
					var attach_result := MatchMutations.attach_item_to_creature(match_state, player_id, actual_item, str(equip_self.get("instance_id", "")), {"source_zone": ZONE_DISCARD})
					if bool(attach_result.get("is_valid", false)):
						generated_events.append({
							"event_type": EVENT_CARD_PLAYED,
							"playing_player_id": player_id,
							"player_id": player_id,
							"source_instance_id": str(actual_item.get("instance_id", "")),
							"source_controller_player_id": player_id,
							"source_zone": ZONE_DISCARD,
							"target_zone": "attached_item",
							"target_instance_id": str(equip_self.get("instance_id", "")),
							"card_type": CARD_TYPE_ITEM,
							"played_cost": int(actual_item.get("cost", 0)),
							"played_for_free": true,
							"reason": "equip_from_discard",
						})
						generated_events.append_array(attach_result.get("events", []))
						equipped += 1
		"equip_copy_of_item":
			var ecoi_controller_id := str(trigger.get("controller_player_id", ""))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				if str(card.get("card_type", "")) == CARD_TYPE_ITEM:
					var ecoi_copy := MatchMutations.build_generated_card(match_state, ecoi_controller_id, card)
					for ecoi_target in MatchTargeting._resolve_card_targets_by_name(match_state, trigger, event, str(effect.get("equip_target", "chosen_target"))):
						var ecoi_equip := MatchMutations.attach_item_to_creature(match_state, ecoi_controller_id, ecoi_copy, str(ecoi_target.get("instance_id", "")), {"reason": reason})
						generated_events.append_array(ecoi_equip.get("events", []))
						break
		"equip_copies_from_discard":
			var ecfd_controller_id := str(trigger.get("controller_player_id", ""))
			var ecfd_player := MatchTimingHelpers._get_player_state(match_state, ecfd_controller_id)
			var ecfd_host_id := ""
			var ecfd_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not ecfd_source.is_empty():
				ecfd_host_id = str(ecfd_source.get("attached_to_instance_id", ""))
			if not ecfd_player.is_empty() and not ecfd_host_id.is_empty():
				var ecfd_discard: Array = ecfd_player.get(ZONE_DISCARD, [])
				var ecfd_items: Array = []
				for ecfd_card in ecfd_discard:
					if typeof(ecfd_card) == TYPE_DICTIONARY and str(ecfd_card.get("card_type", "")) == CARD_TYPE_ITEM:
						ecfd_items.append(ecfd_card)
				for ecfd_item in ecfd_items:
					ecfd_discard.erase(ecfd_item)
					MatchMutations.restore_definition_state(ecfd_item)
					ecfd_item.erase("zone")
					var ecfd_equip := MatchMutations.attach_item_to_creature(match_state, ecfd_controller_id, ecfd_item, ecfd_host_id, {"reason": reason})
					generated_events.append_array(ecfd_equip.get("events", []))
		"steal_items":
			var steal_items_receiver := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if steal_items_receiver.is_empty():
				return
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var items_to_steal: Array = card.get("attached_items", []).duplicate()
				for item in items_to_steal:
					if typeof(item) != TYPE_DICTIONARY:
						return
					var host_items: Array = card.get("attached_items", [])
					var idx := -1
					for i in range(host_items.size()):
						if typeof(host_items[i]) == TYPE_DICTIONARY and str(host_items[i].get("instance_id", "")) == str(item.get("instance_id", "")):
							idx = i
							break
					if idx >= 0:
						host_items.remove_at(idx)
						card["attached_items"] = host_items
					item["controller_player_id"] = str(trigger.get("controller_player_id", ""))
					var receiver_items: Array = steal_items_receiver.get("attached_items", [])
					receiver_items.append(item)
					steal_items_receiver["attached_items"] = receiver_items
					generated_events.append({"event_type": "item_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "item_instance_id": str(item.get("instance_id", ""))})
		"steal_item_from_opponent_discard":
			var sifod_controller_id := str(trigger.get("controller_player_id", ""))
			var sifod_opponent_id := MatchTimingHelpers._get_opposing_player_id(match_state.get("players", []), sifod_controller_id)
			var sifod_opponent := MatchTimingHelpers._get_player_state(match_state, sifod_opponent_id)
			if not sifod_opponent.is_empty():
				var sifod_discard: Array = sifod_opponent.get(ZONE_DISCARD, [])
				var sifod_items: Array = []
				for sifod_card in sifod_discard:
					if typeof(sifod_card) == TYPE_DICTIONARY and str(sifod_card.get("card_type", "")) == CARD_TYPE_ITEM:
						sifod_items.append(sifod_card)
				if not sifod_items.is_empty():
					var sifod_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_steal_item", sifod_items.size())
					var sifod_stolen: Dictionary = sifod_items[sifod_idx]
					sifod_discard.erase(sifod_stolen)
					MatchMutations.restore_definition_state(sifod_stolen)
					# Equip to the source creature
					var sifod_source_id := str(trigger.get("source_instance_id", ""))
					sifod_stolen["controller_player_id"] = sifod_controller_id
					sifod_stolen["owner_player_id"] = sifod_controller_id
					var sifod_equip := MatchMutations.attach_item_to_creature(match_state, sifod_controller_id, sifod_stolen, sifod_source_id, {"reason": reason})
					generated_events.append_array(sifod_equip.get("events", []))
		"reequip_all_items_to":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var rait_controller_id := str(card.get("controller_player_id", ""))
				var rait_all_items: Array = []
				for rait_friendly in MatchTimingHelpers._player_lane_creatures(match_state, rait_controller_id):
					if str(rait_friendly.get("instance_id", "")) == str(card.get("instance_id", "")):
						continue
					for rait_item in rait_friendly.get("attached_items", []):
						rait_all_items.append({"item": rait_item, "host": rait_friendly})
				for rait_entry in rait_all_items:
					var rait_item_id := str(rait_entry["item"].get("instance_id", ""))
					var rait_result := MatchMutations.attach_item_to_creature(match_state, rait_controller_id, rait_item_id, str(card.get("instance_id", "")), {"reason": reason})
					generated_events.append_array(rait_result.get("events", []))
		"modify_item_in_hand", "modify_random_item_in_hand":
			var mih_controller_id := str(trigger.get("controller_player_id", ""))
			var mih_player := MatchTimingHelpers._get_player_state(match_state, mih_controller_id)
			if not mih_player.is_empty():
				var mih_hand: Array = mih_player.get(ZONE_HAND, [])
				var mih_items: Array = []
				for mih_card in mih_hand:
					if str(mih_card.get("card_type", "")) == CARD_TYPE_ITEM:
						mih_items.append(mih_card)
				if not mih_items.is_empty():
					var mih_target: Dictionary
					if op == "modify_random_item_in_hand":
						var mih_idx := MatchEffectParams._deterministic_index(match_state, str(trigger.get("source_instance_id", "")) + "_mod_item", mih_items.size())
						mih_target = mih_items[mih_idx]
					else:
						mih_target = mih_items[0]
					var mih_power := int(effect.get("power", 0))
					var mih_health := int(effect.get("health", 0))
					mih_target["equip_power_bonus"] = int(mih_target.get("equip_power_bonus", 0)) + mih_power
					mih_target["equip_health_bonus"] = int(mih_target.get("equip_health_bonus", 0)) + mih_health
					generated_events.append({
						"event_type": "item_in_hand_modified",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(mih_target.get("instance_id", "")),
						"power": mih_power,
						"health": mih_health,
					})
		"buff_creatures_in_deck", "buff_creatures_in_discard", "buff_items_in_deck":
			var bcid_power := int(effect.get("power", 0))
			var bcid_health := int(effect.get("health", 0))
			var bcid_controller := str(trigger.get("controller_player_id", ""))
			var bcid_player := MatchTimingHelpers._get_player_state(match_state, bcid_controller)
			if not bcid_player.is_empty():
				var bcid_zone_name := ZONE_DISCARD if op == "buff_creatures_in_discard" else ZONE_DECK
				var bcid_zone: Array = bcid_player.get(bcid_zone_name, [])
				var bcid_filter_type := "item" if op == "buff_items_in_deck" else "creature"
				var bcid_filter_subtype := str(effect.get("filter_subtype", ""))
				for card in bcid_zone:
					if typeof(card) != TYPE_DICTIONARY:
						return
					if str(card.get("card_type", "")) != bcid_filter_type:
						return
					if not bcid_filter_subtype.is_empty():
						var subtypes: Array = card.get("subtypes", [])
						if typeof(subtypes) != TYPE_ARRAY or not subtypes.has(bcid_filter_subtype):
							return
					EvergreenRules.apply_stat_bonus(card, bcid_power, bcid_health, reason)
				generated_events.append({"event_type": "zone_buffed", "player_id": bcid_controller, "zone": bcid_zone_name, "power": bcid_power, "health": bcid_health, "reason": reason})
		"equip_item", "equip_generated_item":
			var ei_template_raw = effect.get("card_template", {})
			var ei_template: Dictionary = ei_template_raw if typeof(ei_template_raw) == TYPE_DICTIONARY else {}
			if ei_template.is_empty():
				return
			var ei_targets := MatchTargeting._resolve_card_targets(match_state, trigger, event, effect)
			GameLogger.trc("Timing", "equip_gen_item", "targets:%d,filter_def:%s,target_type:%s" % [ei_targets.size(), str(effect.get("target_filter_definition_id", "")), str(effect.get("target", ""))])
			for card in ei_targets:
				var ei_controller := str(card.get("controller_player_id", trigger.get("controller_player_id", "")))
				var ei_item := MatchMutations.build_generated_card(match_state, ei_controller, ei_template)
				var ei_result := MatchMutations.attach_item_to_creature(match_state, ei_controller, ei_item, str(card.get("instance_id", "")), {"source_zone": MatchMutations.ZONE_GENERATED})
				if bool(ei_result.get("is_valid", false)):
					generated_events.append_array(ei_result.get("events", []))
					generated_events.append({"event_type": "item_equipped", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "item_instance_id": str(ei_item.get("instance_id", "")), "reason": reason})
