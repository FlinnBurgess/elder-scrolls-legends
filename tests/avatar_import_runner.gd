extends SceneTree

const AvatarRegistry = preload("res://src/core/avatar_registry.gd")


func _init() -> void:
	var ok := true
	ok = _test_pad_wide() and ok
	ok = _test_pad_tall() and ok
	ok = _test_pad_target_aspect() and ok
	ok = _test_import_and_delete() and ok
	if ok:
		print("AVATAR_IMPORT_OK")
		quit(0)
	else:
		push_error("avatar_import: failures")
		quit(1)


func _make_solid_image(w: int, h: int, color: Color) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img


# 100×40 source (aspect 2.5, wider than 286/512≈0.559). Scaled to 286×114,
# blitted at (0,0); rows 114..511 must be transparent (bottom padding).
func _test_pad_wide() -> bool:
	var src := _make_solid_image(100, 40, Color(1, 0, 0, 1))
	var padded := AvatarRegistry._pad_to_target(src)
	if padded == null:
		push_error("pad_wide: null"); return false
	if padded.get_size() != Vector2i(286, 512):
		push_error("pad_wide: size %s" % padded.get_size()); return false
	var top_px := padded.get_pixel(50, 30)
	if top_px.r < 0.9 or top_px.a < 0.9:
		push_error("pad_wide: expected red at (50,30), got %s" % top_px); return false
	var bottom_px := padded.get_pixel(143, 500)
	if bottom_px.a > 0.05:
		push_error("pad_wide: expected transparent at (143,500), alpha=%s" % bottom_px.a); return false
	return true


# 40×200 source (aspect 0.2, narrower than target). Scaled to 102×512,
# blitted at x_off=92; columns 0..91 and 194..285 must be transparent.
func _test_pad_tall() -> bool:
	var src := _make_solid_image(40, 200, Color(0, 1, 0, 1))
	var padded := AvatarRegistry._pad_to_target(src)
	if padded == null:
		push_error("pad_tall: null"); return false
	if padded.get_size() != Vector2i(286, 512):
		push_error("pad_tall: size %s" % padded.get_size()); return false
	var left_px := padded.get_pixel(10, 250)
	if left_px.a > 0.05:
		push_error("pad_tall: expected transparent at (10,250), alpha=%s" % left_px.a); return false
	var right_px := padded.get_pixel(280, 250)
	if right_px.a > 0.05:
		push_error("pad_tall: expected transparent at (280,250), alpha=%s" % right_px.a); return false
	var center_px := padded.get_pixel(143, 250)
	if center_px.g < 0.9 or center_px.a < 0.9:
		push_error("pad_tall: expected green at (143,250), got %s" % center_px); return false
	return true


func _test_pad_target_aspect() -> bool:
	var src := _make_solid_image(286, 512, Color(0, 0, 1, 1))
	var padded := AvatarRegistry._pad_to_target(src)
	if padded == null:
		push_error("pad_target: null"); return false
	if padded.get_size() != Vector2i(286, 512):
		push_error("pad_target: size %s" % padded.get_size()); return false
	for c in [Vector2i(0, 0), Vector2i(285, 0), Vector2i(0, 511), Vector2i(285, 511)]:
		var px := padded.get_pixel(c.x, c.y)
		if px.a < 0.9 or px.b < 0.9:
			push_error("pad_target: expected opaque blue at %s, got %s" % [c, px]); return false
	return true


func _test_import_and_delete() -> bool:
	var temp_path := "user://test_import_source.png"
	var src := _make_solid_image(120, 80, Color(1, 1, 0, 1))
	if src.save_png(temp_path) != OK:
		push_error("import: save source failed"); return false
	var initial_count := AvatarRegistry.list_avatar_ids().size()
	var new_id := AvatarRegistry.import_user_avatar(temp_path, "TestImport")
	if new_id == "":
		push_error("import: empty id"); return false
	var ids := AvatarRegistry.list_avatar_ids()
	if not ids.has(new_id):
		push_error("import: id %s missing from list" % new_id); return false
	if ids.size() != initial_count + 1:
		push_error("import: count %d expected %d" % [ids.size(), initial_count + 1]); return false
	if not AvatarRegistry.is_user_avatar(new_id):
		push_error("import: not flagged as user avatar"); return false
	var tex := AvatarRegistry.load_full_texture(new_id)
	if tex == null:
		push_error("import: texture null"); return false
	if Vector2i(tex.get_size()) != Vector2i(286, 512):
		push_error("import: texture size %s" % tex.get_size()); return false
	# Collision handling: importing again with same desired id should disambiguate
	var second_id := AvatarRegistry.import_user_avatar(temp_path, "TestImport")
	if second_id == "" or second_id == new_id:
		push_error("import: collision id not unique (%s vs %s)" % [new_id, second_id]); return false
	if not AvatarRegistry.delete_user_avatar(new_id):
		push_error("import: delete first failed"); return false
	if not AvatarRegistry.delete_user_avatar(second_id):
		push_error("import: delete second failed"); return false
	var post := AvatarRegistry.list_avatar_ids()
	if post.has(new_id) or post.has(second_id):
		push_error("import: id still listed after delete"); return false
	# Built-in avatars must still be present.
	if not post.has(AvatarRegistry.DEFAULT_AVATAR_ID):
		push_error("import: default avatar missing after cycle"); return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	return true
