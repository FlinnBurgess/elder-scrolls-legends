class_name EffectKeywords
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
const RANDOM_KEYWORD_POOL := ["breakthrough", "charge", "drain", "guard", "lethal", "regenerate", "ward", "rally"]

static func _MT():
	return load("res://src/core/match/match_timing.gd")


static func apply(op: String, match_state: Dictionary, trigger: Dictionary, event: Dictionary, effect: Dictionary, generated_events: Array, ctx: Dictionary) -> void:
	var descriptor: Dictionary = ctx.get("descriptor", {})
	var reason: String = ctx.get("reason", "trigger")
	match op:
		"grant_keyword":
			var kw_is_temp := str(effect.get("duration", "")) == "end_of_turn" or bool(effect.get("temporary", false)) or bool(effect.get("expires_end_of_turn", false))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				EvergreenRules.ensure_card_state(card)
				var keyword_id := str(effect.get("keyword_id", ""))
				var kw_already_had := EvergreenRules.has_keyword(card, keyword_id)
				var granted_keywords: Array = card.get("granted_keywords", [])
				if not granted_keywords.has(keyword_id):
					granted_keywords.append(keyword_id)
					card["granted_keywords"] = granted_keywords
				if kw_is_temp:
					EvergreenRules.add_temporary_keyword(card, keyword_id, int(match_state.get("turn_number", 0)))
				if keyword_id == EvergreenRules.KEYWORD_GUARD and EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER):
					EvergreenRules.remove_status(card, EvergreenRules.STATUS_COVER)
					card.erase("cover_expires_on_turn")
					card.erase("cover_granted_by")
				if not kw_already_had:
					generated_events.append({
						"event_type": "keyword_granted",
						"source_instance_id": str(trigger.get("source_instance_id", "")),
						"target_instance_id": str(card.get("instance_id", "")),
						"keyword_id": keyword_id,
					})
		"grant_random_keyword":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				EvergreenRules.ensure_card_state(card)
				var candidates: Array = []
				for kw in RANDOM_KEYWORD_POOL:
					if not EvergreenRules.has_keyword(card, kw):
						candidates.append(kw)
				if candidates.is_empty():
					continue
				var pick: String = str(candidates[MatchEffectParams._deterministic_index(match_state, str(card.get("instance_id", "")), candidates.size())])
				var granted_keywords: Array = card.get("granted_keywords", [])
				if not granted_keywords.has(pick):
					granted_keywords.append(pick)
					card["granted_keywords"] = granted_keywords
				if pick == EvergreenRules.KEYWORD_GUARD and EvergreenRules.has_raw_status(card, EvergreenRules.STATUS_COVER):
					EvergreenRules.remove_status(card, EvergreenRules.STATUS_COVER)
					card.erase("cover_expires_on_turn")
					card.erase("cover_granted_by")
				generated_events.append({
					"event_type": "keyword_granted",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"keyword_id": pick,
				})
		"grant_keyword_to_all_copies":
			var gktac_keyword := str(effect.get("keyword_id", ""))
			var gktac_name := ""
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				gktac_name = str(card.get("name", ""))
				break
			if not gktac_name.is_empty() and not gktac_keyword.is_empty():
				var gktac_controller_id := str(trigger.get("controller_player_id", ""))
				var gktac_player := MatchTimingHelpers._get_player_state(match_state, gktac_controller_id)
				if not gktac_player.is_empty():
					var gktac_zones := [gktac_player.get(ZONE_HAND, []), gktac_player.get(ZONE_DECK, [])]
					for gktac_zone in gktac_zones:
						for gktac_card in gktac_zone:
							if str(gktac_card.get("name", "")) == gktac_name:
								EvergreenRules.ensure_card_state(gktac_card)
								var gktac_granted: Array = gktac_card.get("granted_keywords", [])
								if not gktac_granted.has(gktac_keyword):
									gktac_granted.append(gktac_keyword)
									gktac_card["granted_keywords"] = gktac_granted
					# Also grant to lane creatures
					for gktac_creature in MatchTimingHelpers._player_lane_creatures(match_state, gktac_controller_id):
						if str(gktac_creature.get("name", "")) == gktac_name:
							EvergreenRules.ensure_card_state(gktac_creature)
							var gktac_granted2: Array = gktac_creature.get("granted_keywords", [])
							if not gktac_granted2.has(gktac_keyword):
								gktac_granted2.append(gktac_keyword)
								gktac_creature["granted_keywords"] = gktac_granted2
								generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(gktac_creature.get("instance_id", "")), "keyword_id": gktac_keyword})
		"remove_keyword":
			var keyword_to_remove := str(effect.get("keyword_id", ""))
			if not keyword_to_remove.is_empty():
				for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
					if EvergreenRules.remove_keyword(card, keyword_to_remove):
						generated_events.append({
							"event_type": "keyword_removed",
							"source_instance_id": str(trigger.get("source_instance_id", "")),
							"target_instance_id": str(card.get("instance_id", "")),
							"keyword_id": keyword_to_remove,
							"reason": reason,
						})
		"copy_keywords_to_friendly":
			var kw_source_target := str(effect.get("source", "self"))
			var kw_source_id := ""
			if kw_source_target == "event_target":
				kw_source_id = str(event.get("target_instance_id", trigger.get("target_instance_id", "")))
			else:
				kw_source_id = str(trigger.get("source_instance_id", ""))
			var kw_source := MatchTimingHelpers._find_card_anywhere(match_state, kw_source_id)
			if kw_source.is_empty():
				return
			var source_keywords: Array = []
			for kw in RANDOM_KEYWORD_POOL:
				if EvergreenRules.has_keyword(kw_source, kw):
					source_keywords.append(kw)
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				EvergreenRules.ensure_card_state(card)
				var granted: Array = card.get("granted_keywords", [])
				for kw in source_keywords:
					if not granted.has(kw):
						granted.append(kw)
						generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": kw})
				card["granted_keywords"] = granted
		"steal_keywords":
			var steal_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if steal_source.is_empty():
				return
			EvergreenRules.ensure_card_state(steal_source)
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				for kw in RANDOM_KEYWORD_POOL:
					if EvergreenRules.has_keyword(card, kw):
						EvergreenRules.remove_keyword(card, kw)
						var granted: Array = steal_source.get("granted_keywords", [])
						if not granted.has(kw):
							granted.append(kw)
							steal_source["granted_keywords"] = granted
						generated_events.append({"event_type": "keyword_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": kw})
		"gain_keywords_from_top_deck":
			var gkftd_controller_id := str(trigger.get("controller_player_id", ""))
			var gkftd_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			var gkftd_player := MatchTimingHelpers._get_player_state(match_state, gkftd_controller_id)
			if not gkftd_source.is_empty() and not gkftd_player.is_empty():
				var gkftd_deck: Array = gkftd_player.get(ZONE_DECK, [])
				var gkftd_count := int(effect.get("count", 3))
				EvergreenRules.ensure_card_state(gkftd_source)
				var gkftd_granted: Array = gkftd_source.get("granted_keywords", [])
				for i in range(mini(gkftd_count, gkftd_deck.size())):
					var gkftd_card: Dictionary = gkftd_deck[gkftd_deck.size() - 1 - i]
					for kw in gkftd_card.get("keywords", []):
						if not gkftd_granted.has(str(kw)):
							gkftd_granted.append(str(kw))
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(gkftd_source.get("instance_id", "")), "keyword_id": str(kw)})
				gkftd_source["granted_keywords"] = gkftd_granted
		"copy_all_friendly_keywords":
			var cafk_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
			if not cafk_source.is_empty():
				var cafk_controller_id := str(cafk_source.get("controller_player_id", ""))
				EvergreenRules.ensure_card_state(cafk_source)
				var cafk_granted: Array = cafk_source.get("granted_keywords", [])
				for card in MatchTimingHelpers._player_lane_creatures(match_state, cafk_controller_id):
					if str(card.get("instance_id", "")) == str(cafk_source.get("instance_id", "")):
						continue
					for kw in card.get("keywords", []):
						if not cafk_granted.has(str(kw)):
							cafk_granted.append(str(kw))
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(cafk_source.get("instance_id", "")), "keyword_id": str(kw)})
					for kw in card.get("granted_keywords", []):
						if not cafk_granted.has(str(kw)):
							cafk_granted.append(str(kw))
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(cafk_source.get("instance_id", "")), "keyword_id": str(kw)})
				cafk_source["granted_keywords"] = cafk_granted
		"grant_status":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var status_id := str(effect.get("status_id", ""))
				var target_self_immunities = card.get("self_immunity", [])
				if typeof(target_self_immunities) == TYPE_ARRAY and target_self_immunities.has(status_id):
					continue
				if status_id == EvergreenRules.STATUS_COVER:
					var offset := int(effect.get("expires_on_turn_offset", 1))
					EvergreenRules.grant_cover(card, int(match_state.get("turn_number", 0)) + offset, reason)
				elif status_id == "shackle" or status_id == EvergreenRules.STATUS_SHACKLED:
					EvergreenRules.add_status(card, EvergreenRules.STATUS_SHACKLED)
					if bool(effect.get("permanent", false)):
						card["shackle_expires_on_turn"] = 999999
					else:
						card["shackle_expires_on_turn"] = int(match_state.get("turn_number", 0)) + 1
				else:
					EvergreenRules.add_status(card, status_id)
					var gs_duration := str(effect.get("duration", ""))
					if bool(effect.get("expires_end_of_turn", false)) or gs_duration == "end_of_turn":
						var temp_statuses: Array = card.get("_temp_statuses", [])
						if not temp_statuses.has(status_id):
							temp_statuses.append(status_id)
						card["_temp_statuses"] = temp_statuses
					elif gs_duration == "until_start_of_next_turn":
						# Expires at end of next turn (survives one extra turn-end cycle)
						var next_turn_temps: Array = card.get("_next_turn_temp_statuses", [])
						if not next_turn_temps.has(status_id):
							next_turn_temps.append(status_id)
						card["_next_turn_temp_statuses"] = next_turn_temps
				generated_events.append({
					"event_type": "status_granted",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"status_id": status_id,
				})
		"remove_status":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var status_id := str(effect.get("status_id", ""))
				if status_id == EvergreenRules.STATUS_COVER:
					EvergreenRules.remove_status(card, EvergreenRules.STATUS_COVER)
					card.erase("cover_expires_on_turn")
					card.erase("cover_granted_by")
				else:
					EvergreenRules.remove_status(card, status_id)
				generated_events.append({
					"event_type": "status_removed",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
					"status_id": status_id,
				})
		"steal_status":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var ss_source := MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if ss_source.is_empty():
					return
				var ss_statuses: Array = card.get("status_markers", [])
				if typeof(ss_statuses) != TYPE_ARRAY or ss_statuses.is_empty():
					var ss_keywords: Array = card.get("granted_keywords", [])
					if typeof(ss_keywords) == TYPE_ARRAY and not ss_keywords.is_empty():
						var ss_kw: String = ss_keywords[0]
						ss_keywords.erase(ss_kw)
						EvergreenRules.ensure_card_state(ss_source)
						var ss_granted: Array = ss_source.get("granted_keywords", [])
						if not ss_granted.has(ss_kw):
							ss_granted.append(ss_kw)
							ss_source["granted_keywords"] = ss_granted
						generated_events.append({"event_type": "keyword_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "keyword_id": ss_kw})
				else:
					var ss_status: String = ss_statuses[0]
					EvergreenRules.remove_status(card, ss_status)
					EvergreenRules.add_status(ss_source, ss_status)
					generated_events.append({"event_type": "status_stolen", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "status_id": ss_status})
		"grant_immunity":
			var gi_type := str(effect.get("immunity_type", ""))
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var gi_immunities: Array = card.get("self_immunity", [])
				if typeof(gi_immunities) != TYPE_ARRAY:
					gi_immunities = []
				if not gi_immunities.has(gi_type):
					gi_immunities.append(gi_type)
				card["self_immunity"] = gi_immunities
				generated_events.append({"event_type": "immunity_granted", "target_instance_id": str(card.get("instance_id", "")), "immunity_type": gi_type, "reason": reason})
		"grant_temporary_immunity":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				card["_immune_until_turn"] = int(match_state.get("turn_number", 0)) + 1
				card["_immunity_type"] = str(effect.get("immunity", ""))
				generated_events.append({"event_type": "temporary_immunity_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "immunity_type": str(effect.get("immunity", ""))})
		"silence":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				if MatchTimingHelpers._is_immune_to_effect(match_state, card, "silence"):
					continue
				var silence_result := MatchMutations.silence_card(card, {"reason": reason}, match_state)
				generated_events.append_array(silence_result.get("events", []))
		"shackle":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				if MatchTimingHelpers._is_immune_to_effect(match_state, card, "shackle") or EvergreenRules.has_raw_status(card, "shackle_immune"):
					continue
				EvergreenRules.add_status(card, EvergreenRules.STATUS_SHACKLED)
				if bool(effect.get("persistent_while_source_alive", false)):
					card["shackle_expires_on_turn"] = 999999
					card["_shackle_persistent_source_id"] = str(trigger.get("source_instance_id", ""))
				else:
					card["shackle_expires_on_turn"] = int(match_state.get("turn_number", 0)) + 1
				generated_events.append({"event_type": "status_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "status_id": "shackled", "reason": reason})
		"sacrifice_if_no_ward":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				if not EvergreenRules.has_keyword(card, EvergreenRules.KEYWORD_WARD):
					var loc := MatchMutations.find_card_location(match_state, str(card.get("instance_id", "")))
					if bool(loc.get("is_valid", false)):
						var moved := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")))
						if bool(moved.get("is_valid", false)):
							generated_events.append({
								"event_type": "creature_destroyed",
								"instance_id": str(card.get("instance_id", "")),
								"reason": "sacrifice_if_no_ward",
							})
		"grant_slay_ability":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var gsa_raw = effect.get("slay_effects", effect.get("slay_effect", []))
				var gsa_effects: Array = [gsa_raw] if typeof(gsa_raw) == TYPE_DICTIONARY else (gsa_raw if typeof(gsa_raw) == TYPE_ARRAY else [])
				if not gsa_effects.is_empty():
					var gsa_triggers = card.get("triggered_abilities", [])
					if typeof(gsa_triggers) != TYPE_ARRAY:
						gsa_triggers = []
					gsa_triggers.append({"family": FAMILY_SLAY, "required_zone": ZONE_LANE, "effects": gsa_effects})
					card["triggered_abilities"] = gsa_triggers
					generated_events.append({"event_type": "ability_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "ability": "slay"})
		"destroy_and_transfer_keywords":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var datk_keywords: Array = []
				for kw in card.get("keywords", []):
					datk_keywords.append(str(kw))
				for kw in card.get("granted_keywords", []):
					if not datk_keywords.has(str(kw)):
						datk_keywords.append(str(kw))
				var datk_destroy := MatchMutations.discard_card(match_state, str(card.get("instance_id", "")), {"reason": reason})
				generated_events.append({"event_type": EVENT_CREATURE_DESTROYED, "instance_id": str(card.get("instance_id", "")), "controller_player_id": str(card.get("controller_player_id", "")), "killer_instance_id": str(trigger.get("source_instance_id", ""))})
				generated_events.append_array(datk_destroy.get("events", []))
				# Determine the keyword transfer target
				var datk_transfer_mode := str(effect.get("transfer_to_mode", ""))
				var datk_recipient: Dictionary = {}
				if datk_transfer_mode == "friendly_creature":
					var datk_controller_id := str(trigger.get("controller_player_id", ""))
					var datk_friendlies := MatchTimingHelpers._player_lane_creatures(match_state, datk_controller_id)
					if not datk_friendlies.is_empty():
						# Auto-pick first friendly creature (targeting would require pending system)
						datk_recipient = datk_friendlies[0]
				if datk_recipient.is_empty():
					datk_recipient = MatchTimingHelpers._find_card_anywhere(match_state, str(trigger.get("source_instance_id", "")))
				if not datk_recipient.is_empty():
					EvergreenRules.ensure_card_state(datk_recipient)
					var datk_granted: Array = datk_recipient.get("granted_keywords", [])
					for kw in datk_keywords:
						if not datk_granted.has(kw):
							datk_granted.append(kw)
							generated_events.append({"event_type": "keyword_granted", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(datk_recipient.get("instance_id", "")), "keyword_id": kw})
					datk_recipient["granted_keywords"] = datk_granted
		"grant_extra_attack":
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				card["has_attacked_this_turn"] = false
				generated_events.append({
					"event_type": "extra_attack_granted",
					"source_instance_id": str(trigger.get("source_instance_id", "")),
					"target_instance_id": str(card.get("instance_id", "")),
				})
		"modify_stats_if_shares_subtype_with_top_deck":
			var msisswtd_controller_id := str(trigger.get("controller_player_id", ""))
			var msisswtd_player := MatchTimingHelpers._get_player_state(match_state, msisswtd_controller_id)
			if not msisswtd_player.is_empty():
				var msisswtd_deck: Array = msisswtd_player.get(ZONE_DECK, [])
				if not msisswtd_deck.is_empty():
					var msisswtd_top: Dictionary = msisswtd_deck.back()
					var msisswtd_top_subtypes = msisswtd_top.get("subtypes", [])
					if typeof(msisswtd_top_subtypes) == TYPE_ARRAY:
						for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
							var msisswtd_card_subtypes = card.get("subtypes", [])
							if typeof(msisswtd_card_subtypes) == TYPE_ARRAY:
								var msisswtd_shares := false
								for st in msisswtd_card_subtypes:
									if msisswtd_top_subtypes.has(st):
										msisswtd_shares = true
										break
								if msisswtd_shares:
									var msisswtd_power := int(effect.get("power", 0))
									var msisswtd_health := int(effect.get("health", 0))
									EvergreenRules.apply_stat_bonus(card, msisswtd_power, msisswtd_health, reason)
									generated_events.append({"event_type": "stats_modified", "source_instance_id": str(trigger.get("source_instance_id", "")), "target_instance_id": str(card.get("instance_id", "")), "power_bonus": msisswtd_power, "health_bonus": msisswtd_health, "reason": reason})
		"grant_pilfer_draw", "grant_slay_draw":
			var gpd_family := "pilfer" if op == "grant_pilfer_draw" else "slay"
			var gpd_is_temp := str(effect.get("duration", "")) == "end_of_turn"
			for card in MatchTargeting._resolve_card_targets(match_state, trigger, event, effect):
				var gpd_abilities: Array = card.get("triggered_abilities", [])
				var gpd_new_trigger := {
					"family": gpd_family,
					"required_zone": "lane",
					"effects": [{"op": "draw_cards", "target_player": "controller", "count": 1}],
				}
				if gpd_is_temp:
					gpd_new_trigger["expires_on_turn"] = int(match_state.get("turn_number", 0))
				gpd_abilities.append(gpd_new_trigger)
				card["triggered_abilities"] = gpd_abilities
				generated_events.append({"event_type": "ability_granted", "target_instance_id": str(card.get("instance_id", "")), "family": gpd_family, "reason": reason})
