extends SceneTree

const PlayerAvatarComponent = preload("res://src/ui/components/PlayerAvatarComponent.gd")
const PLAYER_AVATAR_SCENE := preload("res://scenes/ui/components/PlayerAvatarComponent.tscn")
const COMPACT_COMPONENT_SIZE := Vector2(188, 176)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var component := PLAYER_AVATAR_SCENE.instantiate() as PlayerAvatarComponent
	if not _assert(component != null, "PlayerAvatarComponent scene should instantiate."):
		quit(1)
		return
	component.size = Vector2(236, 228)
	root.add_child(component)
	await process_frame

	component.set_health_value(18)
	component.set_rune_thresholds([25, 20, 10])
	component.set_is_opponent(true)
	component.apply_player_state({
		"health": 12,
		"rune_thresholds": [25, 20, 15, 10],
	}, false)
	var portrait_rect := component.find_child("PortraitTexture", true, false) as TextureRect

	if not _assert(component.portrait_texture != null, "PlayerAvatarComponent should default to the placeholder portrait texture."):
		quit(1)
		return
	if not _assert(component.health == 12, "apply_player_state should update health through the root API."):
		quit(1)
		return
	if not _assert(component.get_rune_states() == [true, true, true, true, false], "Rune-state API should preserve five slots and darken missing runes instead of removing them."):
		quit(1)
		return
	if not _assert(component.presentation_mode == PlayerAvatarComponent.PRESENTATION_LOCAL_BOTTOM, "apply_player_state should support local/bottom presentation."):
		quit(1)
		return
	if not _assert(component.get_child_count() > 0, "Component root should build and own internal child nodes."):
		quit(1)
		return
	if not _assert(portrait_rect != null and portrait_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Portrait rendering should preserve covered aspect instead of stretching."):
		quit(1)
		return
	if not _assert(portrait_rect != null and portrait_rect.material != null, "Portrait rendering should keep the circular mask material attached."):
		quit(1)
		return
	component.set_is_opponent(false)
	await process_frame
	var local_signature := _avatar_orientation_signature(component)
	if not _assert(_badge_is_on_left(component), "Local presentation should keep the health badge on the left-hand side."):
		quit(1)
		return
	if not _assert(_runes_deplete_right_to_left(component), "Local presentation should place runes so depletion progresses from right to left."):
		quit(1)
		return
	component.set_is_opponent(true)
	await process_frame
	var opponent_signature := _avatar_orientation_signature(component)
	if not _assert(_badge_is_on_left(component), "Opponent presentation should keep the health badge on the left-hand side."):
		quit(1)
		return
	if not _assert(_runes_deplete_right_to_left(component), "Opponent presentation should place runes so depletion progresses from right to left."):
		quit(1)
		return
	if not _assert(_float_arrays_match(local_signature, opponent_signature), "Top-vs-bottom presentation should not horizontally mirror badge or rune ordering."):
		quit(1)
		return

	component.size = COMPACT_COMPONENT_SIZE
	await process_frame
	if not _assert(_controls_fit_inside(component, _avatar_layout_controls(component)), "Avatar medallion, badge, and runes should stay inside the component when rendered smaller than the default size."):
		quit(1)
		return

	print("PLAYER_AVATAR_COMPONENT_OK")
	quit(0)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false


func _avatar_layout_controls(component: PlayerAvatarComponent) -> Array:
	var controls: Array = [
		component.find_child("MedallionOuter", true, false) as Control,
		component.find_child("HealthBadge", true, false) as Control,
	]
	for threshold in PlayerAvatarComponent.DEFAULT_RUNE_THRESHOLDS:
		controls.append(component.get_rune_anchor(threshold))
	return controls


func _avatar_orientation_signature(component: PlayerAvatarComponent) -> Array:
	var medallion := component.find_child("MedallionOuter", true, false) as Control
	var badge := component.find_child("HealthBadge", true, false) as Control
	if medallion == null or badge == null:
		return []
	var signature: Array = [badge.position.x - medallion.position.x]
	for threshold in PlayerAvatarComponent.DEFAULT_RUNE_THRESHOLDS:
		var rune := component.get_rune_anchor(threshold)
		if rune == null:
			return []
		signature.append((rune as Control).position.x - medallion.position.x)
	return signature


func _badge_is_on_left(component: PlayerAvatarComponent) -> bool:
	var medallion := component.find_child("MedallionOuter", true, false) as Control
	var badge := component.find_child("HealthBadge", true, false) as Control
	if medallion == null or badge == null:
		return false
	return badge.get_global_rect().get_center().x < medallion.get_global_rect().get_center().x


func _runes_deplete_right_to_left(component: PlayerAvatarComponent) -> bool:
	var previous_center_x := INF
	for threshold in PlayerAvatarComponent.DEFAULT_RUNE_THRESHOLDS:
		var rune := component.get_rune_anchor(threshold)
		if rune == null:
			return false
		var center_x := (rune as Control).get_global_rect().get_center().x
		if center_x >= previous_center_x:
			return false
		previous_center_x = center_x
	return true


func _float_arrays_match(left: Array, right: Array, tolerance := 0.5) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if absf(float(left[index]) - float(right[index])) > tolerance:
			return false
	return true


func _controls_fit_inside(container: Control, controls: Array) -> bool:
	if container == null:
		return false
	var container_rect := container.get_global_rect().grow(0.5)
	for control in controls:
		if not (control is Control):
			return false
		var target := control as Control
		if not container_rect.encloses(target.get_global_rect()):
			return false
	return true