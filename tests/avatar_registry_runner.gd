extends SceneTree

const AvatarRegistry = preload("res://src/core/avatar_registry.gd")


func _init() -> void:
	var ids := AvatarRegistry.list_avatar_ids()
	if ids.is_empty():
		push_error("avatar_registry: no avatars found")
		quit(1)
		return
	if not ids.has("Nord_Male_1"):
		push_error("avatar_registry: expected Nord_Male_1 in list")
		quit(1)
		return
	var full := AvatarRegistry.load_full_texture("Nord_Male_1")
	if full == null:
		push_error("avatar_registry: full texture null")
		quit(1)
		return
	var top := AvatarRegistry.load_top_half_texture("Nord_Male_1")
	if top == null:
		push_error("avatar_registry: top-half texture null")
		quit(1)
		return
	var full_size := full.get_size()
	var top_size := top.get_size()
	if not (top_size.x == full_size.x and abs(top_size.y - full_size.y / 2) <= 1):
		push_error("avatar_registry: top-half size %s not half of full %s" % [top_size, full_size])
		quit(1)
		return
	if not (top is ImageTexture):
		push_error("avatar_registry: top-half should be ImageTexture, got %s" % top.get_class())
		quit(1)
		return
	print("AVATAR_REGISTRY_OK")
	quit(0)
