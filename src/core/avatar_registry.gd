class_name AvatarRegistry
extends RefCounted

const AVATAR_DIR := "res://assets/images/avatars/"
const USER_AVATAR_DIR := "user://avatars/"
const FILE_PREFIX := "LG-avatar-"
const FILE_SUFFIX := ".png"
const DEFAULT_AVATAR_ID := "Nord_Male_1"
const TARGET_SIZE := Vector2i(286, 512)

static var _cached_ids: Array = []
static var _id_to_path: Dictionary = {}


static func list_avatar_ids() -> Array:
	if not _cached_ids.is_empty():
		return _cached_ids.duplicate()
	var ids: Array = []
	var seen: Dictionary = {}
	_scan_dir(AVATAR_DIR, ids, seen, false)
	_scan_dir(USER_AVATAR_DIR, ids, seen, true)
	ids.sort()
	_cached_ids = ids
	return ids.duplicate()


# Exported builds strip source PNGs from the PCK and only ship the .import
# redirector, so accept either the raw .png (editor) or .png.import (export).
# user:// paths never go through the import pipeline so only .png appears there.
static func _scan_dir(dir_path: String, ids: Array, seen: Dictionary, is_user_dir: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		if is_user_dir:
			return
		push_error("AvatarRegistry: cannot open %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with(FILE_PREFIX):
			var stripped := ""
			if file_name.ends_with(FILE_SUFFIX):
				stripped = file_name.trim_prefix(FILE_PREFIX).trim_suffix(FILE_SUFFIX)
			elif file_name.ends_with(FILE_SUFFIX + ".import"):
				stripped = file_name.trim_prefix(FILE_PREFIX).trim_suffix(FILE_SUFFIX + ".import")
			if stripped != "" and not seen.has(stripped):
				seen[stripped] = true
				ids.append(stripped)
				_id_to_path[stripped] = dir_path + FILE_PREFIX + stripped + FILE_SUFFIX
		file_name = dir.get_next()
	dir.list_dir_end()


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
	list_avatar_ids()
	if _id_to_path.has(avatar_id):
		return _id_to_path[avatar_id]
	return AVATAR_DIR + FILE_PREFIX + avatar_id + FILE_SUFFIX


static func is_user_avatar(avatar_id: String) -> bool:
	list_avatar_ids()
	var path: String = _id_to_path.get(avatar_id, "")
	return path.begins_with("user://")


static func load_full_texture(avatar_id: String) -> Texture2D:
	var resolved := resolve_avatar_id(avatar_id)
	if resolved == "":
		return null
	var path := texture_path(resolved)
	if path.begins_with("user://"):
		var img := Image.new()
		if img.load(path) != OK:
			return null
		return ImageTexture.create_from_image(img)
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


# === User avatar import / delete ===

static func import_user_avatar(source_path: String, target_id: String = "") -> String:
	var img := Image.new()
	var err := img.load(source_path)
	if err != OK:
		push_error("AvatarRegistry.import_user_avatar: cannot load %s (err %d)" % [source_path, err])
		return ""
	var padded := _pad_to_target(img)
	if padded == null:
		push_error("AvatarRegistry.import_user_avatar: padding failed for %s" % source_path)
		return ""
	if not DirAccess.dir_exists_absolute(USER_AVATAR_DIR):
		DirAccess.make_dir_recursive_absolute(USER_AVATAR_DIR)
	var id := target_id if target_id != "" else source_path.get_file().get_basename()
	id = _sanitize_id(id)
	id = _make_unique_id(id)
	var out_path := USER_AVATAR_DIR + FILE_PREFIX + id + FILE_SUFFIX
	if padded.save_png(out_path) != OK:
		push_error("AvatarRegistry.import_user_avatar: save_png failed for %s" % out_path)
		return ""
	_invalidate_cache()
	return id


static func delete_user_avatar(avatar_id: String) -> bool:
	if not is_user_avatar(avatar_id):
		return false
	var dir := DirAccess.open(USER_AVATAR_DIR)
	if dir == null:
		return false
	if dir.remove(FILE_PREFIX + avatar_id + FILE_SUFFIX) != OK:
		return false
	_invalidate_cache()
	return true


# Scales the source image to fit TARGET_SIZE while preserving aspect ratio.
# Vertical leftover is padded at the bottom (top is reserved for in-game avatar);
# horizontal leftover is split equally between left and right. Padding is
# transparent so the existing card frames render cleanly behind it.
static func _pad_to_target(src: Image) -> Image:
	var target_w: int = TARGET_SIZE.x
	var target_h: int = TARGET_SIZE.y
	var src_size := src.get_size()
	if src_size.x <= 0 or src_size.y <= 0:
		return null
	var src_aspect := float(src_size.x) / float(src_size.y)
	var target_aspect := float(target_w) / float(target_h)
	var scaled_w: int
	var scaled_h: int
	var x_off: int
	var y_off: int
	if src_aspect > target_aspect:
		scaled_w = target_w
		scaled_h = int(round(float(src_size.y) * float(target_w) / float(src_size.x)))
		scaled_h = clamp(scaled_h, 1, target_h)
		x_off = 0
		y_off = 0
	else:
		scaled_h = target_h
		scaled_w = int(round(float(src_size.x) * float(target_h) / float(src_size.y)))
		scaled_w = clamp(scaled_w, 1, target_w)
		x_off = (target_w - scaled_w) / 2
		y_off = 0
	var resized := Image.new()
	resized.copy_from(src)
	resized.convert(Image.FORMAT_RGBA8)
	resized.resize(scaled_w, scaled_h, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create_empty(target_w, target_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(resized, Rect2i(0, 0, scaled_w, scaled_h), Vector2i(x_off, y_off))
	return canvas


static func _sanitize_id(id: String) -> String:
	var out := ""
	for c in id:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_":
			out += c
		elif c == " " or c == "-":
			out += "_"
	if out == "":
		out = "Custom"
	return out


static func _make_unique_id(base: String) -> String:
	list_avatar_ids()
	if not _cached_ids.has(base):
		return base
	var i := 2
	while _cached_ids.has("%s_%d" % [base, i]):
		i += 1
	return "%s_%d" % [base, i]


static func _invalidate_cache() -> void:
	_cached_ids = []
	_id_to_path.clear()
	_top_half_cache.clear()
