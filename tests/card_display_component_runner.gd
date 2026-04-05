extends SceneTree

const CardDisplayComponent = preload("res://src/ui/components/CardDisplayComponent.gd")
const CARD_DISPLAY_SCENE := preload("res://scenes/ui/components/CardDisplayComponent.tscn")
const PRESENTATION_FULL := "full"
const PRESENTATION_CREATURE_BOARD_MINIMAL := "creature_board_minimal"
const PRESENTATION_SUPPORT_BOARD_MINIMAL := "support_board_minimal"
const FULL_MINIMUM_SIZE := Vector2(220, 384)
const CREATURE_BOARD_MINIMUM_SIZE := Vector2(251, 437)
const SUPPORT_BOARD_MINIMUM_SIZE := Vector2(144, 144)
const COLOR_STAT_BASE := Color(0.98, 0.94, 0.86, 1.0)
const COLOR_STAT_BUFF := Color(0.56, 0.94, 0.56, 1.0)
const COLOR_STAT_REDUCED := Color(0.97, 0.48, 0.43, 1.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var component := CARD_DISPLAY_SCENE.instantiate() as CardDisplayComponent
	if not _assert(component != null, "CardDisplayComponent scene should instantiate."):
		quit(1)
		return
	component.size = FULL_MINIMUM_SIZE
	root.add_child(component)
	await process_frame

	var full_card := {
		"instance_id": "field_guardian",
		"name": "Field Guardian",
		"card_type": "creature",
		"cost": 2,
		"power": 3,
		"health": 4,
		"power_bonus": 1,
		"health_bonus": -1,
		"rarity": "uncommon",
		"subtypes": ["soldier"],
		"attributes": ["strength", "willpower"],
		"rules_text": "Guard. Placeholder boosted creature for component verification.",
	}
	component.apply_card(full_card, PRESENTATION_FULL)
	await process_frame

	var art_texture := component.find_child("ArtTexture", true, false) as TextureRect
	var placeholder_image := Image.new()
	var placeholder_load_ok := placeholder_image.load(ProjectSettings.globalize_path(CardDisplayComponent.DEFAULT_ART_PATH)) == OK
	var name_label := component.find_child("NameLabel", true, false) as Label
	var subtype_label := component.find_child("SubtypeLabel", true, false) as Label
	var rules_label := component.find_child("RulesLabel", true, false) as RichTextLabel
	var rarity_marker := component.find_child("RarityMarker", true, false) as Control
	var rarity_label := component.find_child("RarityLabel", true, false) as Label
	var cost_badge := component.find_child("CostBadge", true, false) as Control
	var art_frame := component.find_child("ArtFrame", true, false) as Control
	var outer_frame := component.find_child("OuterFrame", true, false) as Control
	var cost_label := component.find_child("CostLabel", true, false) as Label
	var attack_badge := component.find_child("AttackBadge", true, false) as Control
	var health_badge := component.find_child("HealthBadge", true, false) as Control
	var attack_label := component.find_child("AttackLabel", true, false) as Label
	var health_label := component.find_child("HealthLabel", true, false) as Label
	if not _assert(component.get_child_count() > 0, "CardDisplayComponent root should own internal child nodes."):
		quit(1)
		return
	if not _assert(component.custom_minimum_size == FULL_MINIMUM_SIZE, "Full mode should expose the shared full-card footprint."):
		quit(1)
		return
	if not _assert(component.get_art_texture() != null, "Cards without explicit art should resolve to a fallback texture."):
		quit(1)
		return
	var resolved_art_image := component.get_art_texture().get_image() if component.get_art_texture() != null else null
	if not _assert(component.get_art_texture() != null and placeholder_load_ok and resolved_art_image != null and resolved_art_image.get_size() == placeholder_image.get_size() and _color_matches(resolved_art_image.get_pixel(0, 0), placeholder_image.get_pixel(0, 0), 0.01), "Cards without explicit art should resolve to the shared placeholder art texture."):
		quit(1)
		return
	if not _assert(art_texture != null and art_texture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Artwork should use covered aspect rendering."):
		quit(1)
		return
	if not _assert(name_label != null and name_label.text == "Field Guardian", "Full mode should surface the card name in the header banner."):
		quit(1)
		return
	if not _assert(subtype_label != null and subtype_label.text.contains("Soldier"), "Full mode should surface the subtype beneath the name."):
		quit(1)
		return
	if not _assert(rules_label != null and rules_label.text.contains("Guard") and rules_label.text.contains("Placeholder boosted creature") and rules_label.text.find("Guard") < rules_label.text.find("Placeholder"), "Full mode should render keywords above the remaining rules text."):
		quit(1)
		return
	if not _assert(cost_badge != null and cost_badge.visible and cost_label != null and cost_label.text == "2", "Full mode should render the overlapping cost badge."):
		quit(1)
		return
	if not _assert(outer_frame != null and cost_badge.get_global_rect().position.x < outer_frame.get_global_rect().position.x and cost_badge.get_global_rect().position.y < outer_frame.get_global_rect().position.y and cost_badge.get_global_rect().end.x > outer_frame.get_global_rect().position.x and cost_badge.get_global_rect().end.y > outer_frame.get_global_rect().position.y, "Full mode cost badge should overlap the top-left card frame instead of sitting fully inset inside it."):
		quit(1)
		return
	if not _assert(rarity_label != null, "Full mode should have a rarity label node."):
		quit(1)
		return
	if not _assert(rarity_marker != null and absf(rarity_marker.get_global_rect().get_center().x - component.get_global_rect().get_center().x) <= 8.0 and rarity_marker.position.y + rarity_marker.size.y * 0.5 >= component.size.y * 0.85, "Rarity marker should be horizontally centered at the bottom edge of the full card."):
		quit(1)
		return
	if not _assert(attack_badge != null and attack_badge is TextureRect and attack_badge.texture != null, "Full mode attack badge should be a TextureRect with the attack icon."):
		quit(1)
		return
	if not _assert(health_badge != null and health_badge is TextureRect and health_badge.texture != null, "Full mode health badge should be a TextureRect with the defense icon."):
		quit(1)
		return
	if not _assert(attack_label != null and attack_label.text == "4" and _color_matches(attack_label.get_theme_color("font_color"), COLOR_STAT_BUFF), "Buffed attack values should render in green."):
		quit(1)
		return
	if not _assert(health_label != null and health_label.text == "3" and _color_matches(health_label.get_theme_color("font_color"), COLOR_STAT_REDUCED), "Reduced health values should render in red."):
		quit(1)
		return

	var base_card := full_card.duplicate(true)
	base_card["power_bonus"] = 0
	base_card["health_bonus"] = 0
	component.apply_card(base_card, PRESENTATION_FULL)
	await process_frame
	if not _assert(_color_matches(attack_label.get_theme_color("font_color"), COLOR_STAT_BASE) and _color_matches(health_label.get_theme_color("font_color"), COLOR_STAT_BASE), "Base creature stat values should render in white."):
		quit(1)
		return

	var inverse_delta_card := full_card.duplicate(true)
	inverse_delta_card["power_bonus"] = -2
	inverse_delta_card["health_bonus"] = 2
	component.apply_card(inverse_delta_card, PRESENTATION_FULL)
	await process_frame
	if not _assert(attack_label != null and attack_label.text == "1" and _color_matches(attack_label.get_theme_color("font_color"), COLOR_STAT_REDUCED) and health_label != null and health_label.text == "6" and _color_matches(health_label.get_theme_color("font_color"), COLOR_STAT_BUFF), "Stat color semantics should stay red for reduced values and green for buffed values on both badges."):
		quit(1)
		return

	component.size = CREATURE_BOARD_MINIMUM_SIZE
	component.apply_card(full_card, PRESENTATION_CREATURE_BOARD_MINIMAL)
	await process_frame
	var name_banner := component.find_child("NameBanner", true, false) as Control
	var rules_panel := component.find_child("RulesPanel", true, false) as Control
	if not _assert(component.get_presentation_mode() == PRESENTATION_CREATURE_BOARD_MINIMAL, "Root API should switch into creature board-minimal presentation."):
		quit(1)
		return
	if not _assert(component.custom_minimum_size == CREATURE_BOARD_MINIMUM_SIZE, "Creature board-minimal mode should expose the board footprint."):
		quit(1)
		return
	if not _assert(name_banner != null and not name_banner.visible and rules_panel != null and not rules_panel.visible and cost_badge != null and not cost_badge.visible and rarity_marker != null and not rarity_marker.visible, "Creature board-minimal mode should keep only bordered art plus stat badges."):
		quit(1)
		return
	if not _assert(art_frame != null and art_frame.size.y >= component.size.y * 0.78, "Creature board-minimal mode should dedicate most of the frame to art."):
		quit(1)
		return
	if not _assert(outer_frame != null and art_frame != null and art_frame.position.x > outer_frame.position.x and art_frame.position.y > outer_frame.position.y and art_frame.size.x < outer_frame.size.x and art_frame.size.y < outer_frame.size.y, "Creature board-minimal mode should keep visible colored border framing around the art."):
		quit(1)
		return
	if not _assert(component.find_child("AttackBadge", true, false).visible and component.find_child("HealthBadge", true, false).visible, "Creature board-minimal mode should retain the creature stat badges."):
		quit(1)
		return
	if not _assert(attack_badge != null and health_badge != null and attack_badge is TextureRect and health_badge is TextureRect, "Creature board-minimal stat badges should use attack and defense icon textures."):
		quit(1)
		return

	var support_card := {
		"instance_id": "battle_drum",
		"name": "Battle Drum",
		"card_type": "support",
		"cost": 2,
		"rarity": "rare",
		"attributes": ["strength"],
		"rules_text": "Activate: Give a friendly creature Guard.",
	}
	component.size = SUPPORT_BOARD_MINIMUM_SIZE
	component.apply_card(support_card, PRESENTATION_SUPPORT_BOARD_MINIMAL)
	await process_frame
	if not _assert(component.get_presentation_mode() == PRESENTATION_SUPPORT_BOARD_MINIMAL, "Root API should switch into support board-minimal presentation."):
		quit(1)
		return
	if not _assert(component.custom_minimum_size == SUPPORT_BOARD_MINIMUM_SIZE, "Support board-minimal mode should expose the smaller square footprint."):
		quit(1)
		return
	if not _assert(not component.find_child("AttackBadge", true, false).visible and not component.find_child("HealthBadge", true, false).visible, "Support board-minimal mode should omit creature stat badges."):
		quit(1)
		return
	if not _assert(name_banner != null and not name_banner.visible and rules_panel != null and not rules_panel.visible and cost_badge != null and not cost_badge.visible and rarity_marker != null and not rarity_marker.visible, "Support board-minimal mode should be artwork-only."):
		quit(1)
		return
	if not _assert(outer_frame != null and absf(outer_frame.size.x - outer_frame.size.y) <= 0.5, "Support board-minimal mode should collapse into a square frame."):
		quit(1)
		return
	if not _assert(art_frame != null and absf(art_frame.size.x - art_frame.size.y) <= 0.5, "Support board-minimal mode should keep the artwork region square."):
		quit(1)
		return

	# Ongoing support badge tests
	var ongoing_support := {
		"instance_id": "divine_fervor",
		"name": "Divine Fervor",
		"card_type": "support",
		"cost": 5,
		"rarity": "epic",
		"attributes": ["willpower"],
		"rules_text": "Ongoing\nFriendly creatures have +1/+1.",
	}
	component.size = FULL_MINIMUM_SIZE
	component.apply_card(ongoing_support, PRESENTATION_FULL)
	await process_frame
	var ongoing_badge := component.find_child("OngoingBadge", true, false) as Label
	if not _assert(ongoing_badge != null and ongoing_badge.visible, "Full mode ongoing support should show the Ongoing badge."):
		quit(1)
		return
	if not _assert(ongoing_badge.position.y + ongoing_badge.size.y >= art_frame.position.y + art_frame.size.y * 0.85, "Ongoing badge should be positioned at the bottom of the art area."):
		quit(1)
		return
	if not _assert(rules_label != null and not rules_label.text.contains("Ongoing"), "Ongoing support rules text should not contain the word Ongoing."):
		quit(1)
		return
	if not _assert(rules_label.text.contains("+1/+1"), "Ongoing support rules text should still contain the effect description."):
		quit(1)
		return

	# Non-ongoing support should NOT show the badge
	component.apply_card(support_card, PRESENTATION_FULL)
	await process_frame
	if not _assert(ongoing_badge != null and not ongoing_badge.visible, "Non-ongoing support should not show the Ongoing badge."):
		quit(1)
		return

	print("CARD_DISPLAY_COMPONENT_OK")
	quit(0)


func _color_matches(left: Color, right: Color, tolerance := 0.02) -> bool:
	return absf(left.r - right.r) <= tolerance and absf(left.g - right.g) <= tolerance and absf(left.b - right.b) <= tolerance and absf(left.a - right.a) <= tolerance


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false