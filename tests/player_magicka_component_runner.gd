extends SceneTree

const PlayerMagickaComponent = preload("res://src/ui/components/PlayerMagickaComponent.gd")
const PLAYER_MAGICKA_SCENE := preload("res://scenes/ui/components/PlayerMagickaComponent.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var component := PLAYER_MAGICKA_SCENE.instantiate() as PlayerMagickaComponent
	if not _assert(component != null, "PlayerMagickaComponent scene should instantiate."):
		quit(1)
		return
	component.size = Vector2(176, 176)
	root.add_child(component)
	await process_frame

	var medallion_outer := component.find_child("MedallionOuter", true, false) as PanelContainer
	var medallion_inner := component.find_child("MedallionInner", true, false) as PanelContainer
	var magicka_label := component.find_child("MagickaLabel", true, false) as Label
	if not _assert(component.get_child_count() > 0, "Component root should own internal child nodes."):
		quit(1)
		return
	if not _assert(_style_fill(medallion_outer).is_equal_approx(PlayerMagickaComponent.COLOR_BORDER), "Center medallion should use a black outer border surface."):
		quit(1)
		return
	if not _assert(_style_fill(medallion_inner).is_equal_approx(PlayerMagickaComponent.COLOR_MEDALLION), "Center medallion should use the requested blue interior treatment."):
		quit(1)
		return
	if not _assert(magicka_label != null and magicka_label.get_theme_color("font_color").is_equal_approx(PlayerMagickaComponent.COLOR_BORDER), "Center text should render in black."):
		quit(1)
		return

	# Segment count is always at least DEFAULT_SEGMENTS (12), with locked filler segments
	# No bonus: turn 7 player with max 7 should show 12 segments (5 locked)
	component.set_magicka_values(1, 7, 0, 0)
	await process_frame
	if not _assert(component.get_segment_count() == 12, "Segment count should be DEFAULT_SEGMENTS (12), got %d." % component.get_segment_count()):
		quit(1)
		return
	if not _assert(component.get_display_text() == "1/7", "No-temp display should show spendable/max in current/max form."):
		quit(1)
		return
	if not _assert(component.get_segment_states() == _expected_states(1, 0, 6, 5), "State `1/7` should render 1 blue, 6 grey, and 5 locked segments."):
		quit(1)
		return

	var top_segment := component.get_segment_node(0) as Control
	if not _assert(top_segment != null, "First outer-ring segment should exist for geometry checks."):
		quit(1)
		return
	var top_gap := medallion_outer.position.y - (top_segment.position.y + top_segment.size.y)
	if not _assert(top_gap > 0.0 and top_gap <= 15.0, "Outer ring should sit closer to the medallion without overlapping it."):
		quit(1)
		return

	component.set_magicka_values(4, 6, 1, 0)
	await process_frame
	if not _assert(component.get_display_text() == "5/6", "Temporary magicka should increase spendable text without changing the max denominator."):
		quit(1)
		return
	if not _assert(component.get_segment_states() == _expected_states(4, 1, 1, 6), "Temporary magicka should render as a yellow slot before remaining spent slots, with locked filler."):
		quit(1)
		return
	if not _assert(component.get_segment_count() == 12, "Segment count should be DEFAULT_SEGMENTS (12) when no bonus, got %d." % component.get_segment_count()):
		quit(1)
		return

	# apply_player_state derives bonus from turns_started vs max_magicka
	component.apply_player_state({
		"current_magicka": 6,
		"max_magicka": 6,
		"temporary_magicka": 1,
		"turns_started": 6,
	})
	await process_frame
	if not _assert(component.get_display_text() == "7/6", "Temporary magicka should allow center text to show values like `7/6`."):
		quit(1)
		return
	if not _assert(component.get_segment_count() == 12, "Segment count should remain DEFAULT_SEGMENTS (12) when no bonus, got %d." % component.get_segment_count()):
		quit(1)
		return
	if not _assert(component.get_segment_states() == _expected_states(6, 1, 0, 5), "Overflow temp state should keep 6 blue, 1 yellow, and 5 locked slots."):
		quit(1)
		return
	if not _assert(magicka_label != null and magicka_label.text == component.get_display_text(), "Center label should stay synchronized with the root API display text."):
		quit(1)
		return

	# Tree Minder scenario on turn 3: gaining +1 max magicka adds a bonus segment (12 -> 13)
	# Before: turn 3, max 3, no bonus -> 12 segments
	component.apply_player_state({
		"current_magicka": 3,
		"max_magicka": 3,
		"temporary_magicka": 0,
		"turns_started": 3,
	})
	await process_frame
	if not _assert(component.get_segment_count() == 12, "Pre-gain segment count should be 12, got %d." % component.get_segment_count()):
		quit(1)
		return
	# After Tree Minder: max goes to 4 but turns_started is still 3 -> bonus 1 -> 13 segments
	component.apply_player_state({
		"current_magicka": 1,
		"max_magicka": 4,
		"temporary_magicka": 0,
		"turns_started": 3,
	})
	await process_frame
	if not _assert(component.get_segment_count() == 13, "Post-gain segment count should be 13 (12 + 1 bonus), got %d." % component.get_segment_count()):
		quit(1)
		return
	if not _assert(component.get_display_text() == "1/4", "Post-gain display should show 1/4."):
		quit(1)
		return
	if not _assert(component.get_segment_states() == _expected_states(1, 0, 3, 9), "Post-gain should show 1 remaining, 3 spent, 9 locked."):
		quit(1)
		return

	# Next turn: turns_started catches up, bonus stays -> still 13 segments
	component.apply_player_state({
		"current_magicka": 5,
		"max_magicka": 5,
		"temporary_magicka": 0,
		"turns_started": 4,
	})
	await process_frame
	if not _assert(component.get_segment_count() == 13, "Next turn should still be 13 segments (bonus persists), got %d." % component.get_segment_count()):
		quit(1)
		return

	# Beyond-12 with bonus: turn 12, max 14 (two Tree Minders over the game) -> 14 segments
	component.apply_player_state({
		"current_magicka": 9,
		"max_magicka": 14,
		"temporary_magicka": 0,
		"turns_started": 12,
	})
	await process_frame
	if not _assert(component.get_segment_count() == 14, "Segment count should grow to 14 when max is 14 (2 bonus), got %d." % component.get_segment_count()):
		quit(1)
		return
	if not _assert(component.get_display_text() == "9/14", "Display should show 9/14 when max is 14."):
		quit(1)
		return
	if not _assert(component.get_segment_states() == _expected_states(9, 0, 5, 0), "14-segment state should be 9 remaining, 5 spent, 0 locked."):
		quit(1)
		return

	print("PLAYER_MAGICKA_COMPONENT_OK")
	quit(0)


func _expected_states(remaining: int, temporary: int, spent: int, locked: int) -> Array:
	var states: Array = []
	for _index in range(remaining):
		states.append(PlayerMagickaComponent.STATE_REMAINING)
	for _index in range(temporary):
		states.append(PlayerMagickaComponent.STATE_TEMPORARY)
	for _index in range(spent):
		states.append(PlayerMagickaComponent.STATE_SPENT)
	for _index in range(locked):
		states.append(PlayerMagickaComponent.STATE_LOCKED)
	return states


func _style_fill(panel: PanelContainer) -> Color:
	if panel == null:
		return Color(0, 0, 0, 0)
	var style := panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		return (style as StyleBoxFlat).bg_color
	return Color(0, 0, 0, 0)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false
