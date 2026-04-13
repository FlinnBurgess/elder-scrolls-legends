extends SceneTree

## Reads card_catalog.gd as text, finds every "card_template": {...} whose
## definition_id matches a catalog seed AND whose fields are all identical to
## that seed, then replaces the full inline dict with {"definition_id": "..."}.
##
## Templates with intentional overrides are left untouched.

const CardCatalog = preload("res://src/deck/card_catalog.gd")

var _seed_lookup := {}


func _initialize() -> void:
	# Build seed lookup
	for seed in CardCatalog._card_seeds():
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		var cid := str(seed.get("card_id", ""))
		if not cid.is_empty():
			_seed_lookup[cid] = seed

	# Read file
	var path := "res://src/deck/card_catalog.gd"
	var abs_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		printerr("Cannot open %s" % abs_path)
		quit()
		return
	var text := file.get_as_text()
	file.close()

	var lines := text.split("\n", false)
	var total_replaced := 0
	var replaced_cards: Array = []
	var new_lines: Array = []

	for line_idx in range(lines.size()):
		var line: String = lines[line_idx]
		# Find all "card_template": { occurrences, process right-to-left
		var positions: Array = _find_template_positions(line)
		if positions.is_empty():
			new_lines.append(line)
			continue

		# Process right-to-left so earlier positions stay valid
		positions.reverse()
		for pos_info in positions:
			var key_start: int = pos_info["key_start"]
			var brace_start: int = pos_info["brace_start"]
			var brace_end: int = _find_matching_brace(line, brace_start)
			if brace_end < 0:
				continue

			var template_text := line.substr(brace_start, brace_end - brace_start + 1)
			var def_id := _extract_definition_id(template_text)
			if def_id.is_empty():
				continue
			if not _seed_lookup.has(def_id):
				continue

			# Parse the template fields and compare against catalog seed
			if not _is_fully_redundant(template_text, _seed_lookup[def_id]):
				continue

			# Replace
			var replacement := '{"definition_id": "%s"}' % def_id
			line = line.substr(0, brace_start) + replacement + line.substr(brace_end + 1)
			total_replaced += 1

			# Try to identify the host card name for reporting
			var host_name := _extract_host_name(lines[line_idx])
			replaced_cards.append("%s -> %s (line %d)" % [host_name, def_id, line_idx + 1])

		new_lines.append(line)

	if total_replaced == 0:
		print("No fully redundant templates found to replace.")
		quit()
		return

	# Write back
	var out := FileAccess.open(abs_path, FileAccess.WRITE)
	if out == null:
		printerr("Cannot write %s" % abs_path)
		quit()
		return
	out.store_string("\n".join(new_lines))
	out.close()

	print("Replaced %d fully redundant templates:" % total_replaced)
	for entry in replaced_cards:
		print("  %s" % entry)

	quit()


## Find all positions of '"card_template": {' in a line.
## Returns array of {key_start, brace_start}.
func _find_template_positions(line: String) -> Array:
	var results: Array = []
	var search_from := 0
	var marker := '"card_template": {'
	while true:
		var idx := line.find(marker, search_from)
		if idx < 0:
			break
		var brace_start := idx + marker.length() - 1  # position of the '{'
		results.append({"key_start": idx, "brace_start": brace_start})
		search_from = brace_start + 1
	return results


## Find the matching closing brace for an opening brace at pos.
func _find_matching_brace(line: String, pos: int) -> int:
	if pos >= line.length() or line[pos] != "{":
		return -1
	var depth := 0
	var in_string := false
	var escape := false
	var i := pos
	while i < line.length():
		var ch: String = line[i]
		if escape:
			escape = false
			i += 1
			continue
		if ch == "\\":
			if in_string:
				escape = true
			i += 1
			continue
		if ch == '"':
			in_string = not in_string
			i += 1
			continue
		if in_string:
			i += 1
			continue
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return i
		i += 1
	return -1


## Extract definition_id from template text like '{"definition_id": "foo", ...}'
func _extract_definition_id(template_text: String) -> String:
	var marker := '"definition_id": "'
	var idx := template_text.find(marker)
	if idx < 0:
		return ""
	var start := idx + marker.length()
	var end := template_text.find('"', start)
	if end < 0:
		return ""
	return template_text.substr(start, end - start)


## Check if every field in the template matches the catalog seed.
## Returns true only if the template is fully redundant (can be replaced
## with just definition_id).
func _is_fully_redundant(template_text: String, catalog_seed: Dictionary) -> bool:
	# Parse template fields by extracting key-value pairs
	# We need to compare every field in the template against the catalog seed.
	# Instead of writing a full JSON parser, we'll use GDScript's JSON class.
	var json := JSON.new()
	var err := json.parse(template_text)
	if err != OK:
		return false
	var template: Dictionary = json.data
	if typeof(template) != TYPE_DICTIONARY:
		return false

	for key in template:
		if key == "definition_id":
			continue

		var tmpl_val = template[key]
		# Map power/health to base_power/base_health for comparison
		var catalog_key: String = key
		if key == "power":
			catalog_key = "base_power"
		elif key == "health":
			catalog_key = "base_health"

		if not catalog_seed.has(catalog_key):
			return false

		var cat_val = catalog_seed[catalog_key]
		if not _values_equal(tmpl_val, cat_val):
			# Also try direct key match (some templates use base_power directly)
			if catalog_seed.has(key) and _values_equal(tmpl_val, catalog_seed[key]):
				continue
			return false

	return true


func _values_equal(a, b) -> bool:
	if typeof(a) != typeof(b):
		if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
			return int(a) == int(b)
		return str(a) == str(b)
	if typeof(a) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key):
				return false
			if not _values_equal(a[key], b[key]):
				return false
		return true
	if typeof(a) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _values_equal(a[i], b[i]):
				return false
		return true
	return a == b


func _extract_host_name(line: String) -> String:
	# Extract the card name from a _seed("id", "Name", ...) call
	var marker := '_seed("'
	var idx := line.find(marker)
	if idx < 0:
		return "?"
	var after_first := idx + marker.length()
	var comma := line.find('", "', after_first)
	if comma < 0:
		return "?"
	var name_start := comma + 4
	var name_end := line.find('"', name_start)
	if name_end < 0:
		return "?"
	return line.substr(name_start, name_end - name_start)
