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
	var top_segment := component.get_segment_node(0) as Control
	if not _assert(component.get_segment_count() == PlayerMagickaComponent.DEFAULT_SEGMENTS, "PlayerMagickaComponent should build exactly 12 outer-ring segments."):
		quit(1)
		return
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
	if not _assert(top_segment != null, "First outer-ring segment should exist for geometry checks."):
		quit(1)
		return
	var top_gap := medallion_outer.position.y - (top_segment.position.y + top_segment.size.y)
	if not _assert(top_gap > 0.0 and top_gap <= 15.0, "Outer ring should sit closer to the medallion without overlapping it."):
		quit(1)
		return

	component.set_magicka_values(1, 7, 0)
	await process_frame
	if not _assert(component.get_display_text() == "1/7", "No-temp display should show spendable/max in current/max form."):
		quit(1)
		return
	if not _assert(component.get_segment_states() == _expected_states(1, 0, 6, 5), "No-temp state `1/7` should render 1 blue, 6 grey, and 5 black segments."):
		quit(1)
		return

	component.set_magicka_values(4, 6, 1)
	await process_frame
	if not _assert(component.get_display_text() == "5/6", "Temporary magicka should increase spendable text without changing the max denominator."):
		quit(1)
		return
	if not _assert(component.get_segment_states() == _expected_states(4, 1, 1, 6), "Temporary magicka should render as a yellow slot before remaining spent/locked slots."):
		quit(1)
		return

	component.apply_player_state({
		"current_magicka": 6,
		"max_magicka": 6,
		"temporary_magicka": 1,
	})
	await process_frame
	if not _assert(component.get_display_text() == "7/6", "Temporary magicka should allow center text to show values like `7/6`."):
		quit(1)
		return
	if not _assert(component.get_segment_states() == _expected_states(6, 1, 0, 5), "Overflow temp state should keep 6 blue, 1 yellow, and 5 locked slots."):
		quit(1)
		return
	if not _assert(magicka_label != null and magicka_label.text == component.get_display_text(), "Center label should stay synchronized with the root API display text."):
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