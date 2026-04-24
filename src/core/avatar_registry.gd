class_name AvatarRegistry
extends RefCounted

const AVATAR_DIR := "res://assets/images/avatars/"
const FILE_PREFIX := "LG-avatar-"
const FILE_SUFFIX := ".png"
const DEFAULT_AVATAR_ID := "Nord_Male_1"

static var _cached_ids: Array = []


static func list_avatar_ids() -> Array:
	if not _cached_ids.is_empty():
		return _cached_ids.duplicate()
	var ids: Array = []
	var dir := DirAccess.open(AVATAR_DIR)
	if dir == null:
		push_error("AvatarRegistry: cannot open %s" % AVATAR_DIR)
		return ids
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with(FILE_PREFIX) and file_name.ends_with(FILE_SUFFIX):
			ids.append(file_name.trim_prefix(FILE_PREFIX).trim_suffix(FILE_SUFFIX))
		file_name = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	_cached_ids = ids
	return ids.duplicate()


static func has_avatar(avatar_id: String) -> bool:
	return list_avatar_ids().has(avatar_id)


static func resolve_avatar_id(avatar_id: String) -> String:
	if has_avatar(avatar_id):
		return avatar_id
	var ids := list_avatar_ids()
	if ids.has(DEFAULT_AVATAR_ID):
		return DEFAULT_AVATAR_ID
	if ids.is_empty():
		return ""
	return ids[0]


static func texture_path(avatar_id: String) -> String:
	return "%s%s%s%s" % [AVATAR_DIR, FILE_PREFIX, avatar_id, FILE_SUFFIX]


static func load_full_texture(avatar_id: String) -> Texture2D:
	var resolved := resolve_avatar_id(avatar_id)
	if resolved == "":
		return null
	var path := texture_path(resolved)
	if not ResourceLoader.exists(path):
		return null
	var tex = load(path)
	return tex if tex is Texture2D else null


static var _top_half_cache: Dictionary = {}

static func load_top_half_texture(avatar_id: String) -> Texture2D:
	var resolved := resolve_avatar_id(avatar_id)
	if resolved == "":
		return null
	if _top_half_cache.has(resolved):
		var cached = _top_half_cache[resolved]
		if cached is Texture2D:
			return cached
	var source := load_full_texture(resolved)
	if source == null:
		return null
	var src_img := source.get_image()
	if src_img == null:
		return null
	var size := src_img.get_size()
	var half_height: int = max(1, int(size.y) / 2)
	var cropped := Image.create_empty(int(size.x), half_height, false, src_img.get_format())
	cropped.blit_rect(src_img, Rect2i(0, 0, int(size.x), half_height), Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(cropped)
	_top_half_cache[resolved] = tex
	return tex


static func display_name(avatar_id: String) -> String:
	return avatar_id.replace("_", " ")


static func random_avatar_id(rng: RandomNumberGenerator = null) -> String:
	var ids := list_avatar_ids()
	if ids.is_empty():
		return ""
	var index := 0
	if rng != null:
		index = rng.randi_range(0, ids.size() - 1)
	else:
		index = randi() % ids.size()
	return ids[index]


static func pick_random_avatar_ids(count: int, rng: RandomNumberGenerator = null) -> Array:
	var ids := list_avatar_ids()
	if ids.is_empty() or count <= 0:
		return []
	var pool := ids.duplicate()
	if rng != null:
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
	else:
		pool.shuffle()
	if count > pool.size():
		# Not enough unique avatars; allow repeats by cycling.
		var result: Array = []
		for i in range(count):
			result.append(pool[i % pool.size()])
		return result
	return pool.slice(0, count)
