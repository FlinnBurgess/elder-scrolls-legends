extends SceneTree

const CardCatalog = preload("res://src/deck/card_catalog.gd")


func _initialize() -> void:
	var seeds: Array = CardCatalog._card_seeds()

	# Build lookup: card_id → seed dict
	var seed_lookup := {}
	for seed in seeds:
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		var cid := str(seed.get("card_id", ""))
		if not cid.is_empty():
			seed_lookup[cid] = seed

	# Walk every seed and find card_template dicts whose definition_id matches a catalog entry
	var results: Array = []
	for seed in seeds:
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		var host_id := str(seed.get("card_id", ""))
		var host_name := str(seed.get("name", ""))
		_walk(seed, host_id, host_name, [], seed_lookup, results)

	# Report
	if results.is_empty():
		print("NO_REDUNDANT_TEMPLATES_FOUND")
		quit()
		return

	# Classify: "fully redundant" (every field matches catalog) vs "has overrides"
	var fully_redundant: Array = []
	var has_overrides: Array = []

	for r in results:
		if r["override_fields"].is_empty():
			fully_redundant.append(r)
		else:
			has_overrides.append(r)

	print("=== FULLY REDUNDANT (can simplify to just definition_id) ===")
	print("Count: %d" % fully_redundant.size())
	for r in fully_redundant:
		print("  %s (%s) -> refs %s at path %s" % [r["host_name"], r["host_id"], r["ref_id"], r["path"]])
		print("    redundant keys: %s" % str(r["redundant_fields"]))
	print("")

	print("=== HAS OVERRIDES (keep override fields, drop redundant) ===")
	print("Count: %d" % has_overrides.size())
	for r in has_overrides:
		print("  %s (%s) -> refs %s at path %s" % [r["host_name"], r["host_id"], r["ref_id"], r["path"]])
		print("    redundant keys: %s" % str(r["redundant_fields"]))
		print("    OVERRIDE keys:")
		for okey in r["override_fields"]:
			print("      %s: template=%s  catalog=%s" % [okey, str(r["override_fields"][okey]["template"]), str(r["override_fields"][okey]["catalog"])])
	print("")

	# Check whether ALL fully-redundant templates follow a standard inline pattern
	# (i.e. the template dict is a flat dict with only IDENTITY_FIELDS-style keys)
	print("=== AUTOMATION FEASIBILITY ===")
	var all_flat := true
	for r in fully_redundant:
		var tmpl: Dictionary = r["template"]
		for key in tmpl:
			var val = tmpl[key]
			# Arrays and sub-dicts with nesting make text-level replacement risky
			if typeof(val) == TYPE_DICTIONARY:
				print("  WARNING: %s (%s) has nested dict in key '%s'" % [r["host_name"], r["host_id"], key])
				all_flat = false
			if typeof(val) == TYPE_ARRAY:
				for item in val:
					if typeof(item) == TYPE_DICTIONARY:
						print("  WARNING: %s (%s) has array-of-dicts in key '%s'" % [r["host_name"], r["host_id"], key])
						all_flat = false
						break
	if all_flat:
		print("  All fully-redundant templates are flat dicts — safe for automated replacement.")
	else:
		print("  Some templates contain nested structures — review before automating.")

	# Summary of unique definition_ids referenced
	var unique_refs := {}
	for r in results:
		unique_refs[r["ref_id"]] = unique_refs.get(r["ref_id"], 0) + 1
	print("")
	print("=== UNIQUE CATALOG CARDS REFERENCED ===")
	for ref_id in unique_refs:
		var ref_seed: Dictionary = seed_lookup.get(ref_id, {})
		print("  %s (%s) — referenced %d time(s)" % [str(ref_seed.get("name", "?")), ref_id, unique_refs[ref_id]])

	quit()


func _walk(node, host_id: String, host_name: String, path: Array, seed_lookup: Dictionary, results: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		# Check if this dict is a card_template with a catalog-matching definition_id
		if node.has("definition_id"):
			var ref_id := str(node.get("definition_id", ""))
			if seed_lookup.has(ref_id):
				_compare_template(node, seed_lookup[ref_id], host_id, host_name, ref_id, path, results)
		# Recurse into values
		for key in node:
			if key == "definition_id":
				continue
			var child_path := path.duplicate()
			child_path.append(key)
			_walk(node[key], host_id, host_name, child_path, seed_lookup, results)
	elif typeof(node) == TYPE_ARRAY:
		for i in range(node.size()):
			var child_path := path.duplicate()
			child_path.append(str(i))
			_walk(node[i], host_id, host_name, child_path, seed_lookup, results)


func _compare_template(template: Dictionary, catalog_seed: Dictionary, host_id: String, host_name: String, ref_id: String, path: Array, results: Array) -> void:
	var redundant_fields: Array = []
	var override_fields := {}

	for key in template:
		if key == "definition_id":
			continue
		var tmpl_val = template[key]
		# Map template field names to catalog seed field names
		var catalog_key: String = key
		if key == "power":
			catalog_key = "base_power"
		elif key == "health":
			catalog_key = "base_health"

		if not catalog_seed.has(catalog_key):
			# Template has a field the catalog seed doesn't — it's an override
			override_fields[key] = {"template": tmpl_val, "catalog": "<missing>"}
			continue

		var cat_val = catalog_seed[catalog_key]

		if _values_equal(tmpl_val, cat_val):
			redundant_fields.append(key)
		else:
			# Also check if the template uses "power"/"health" matching base_power/base_health
			if key == "power" and _values_equal(tmpl_val, catalog_seed.get("base_power", null)):
				redundant_fields.append(key)
			elif key == "health" and _values_equal(tmpl_val, catalog_seed.get("base_health", null)):
				redundant_fields.append(key)
			else:
				override_fields[key] = {"template": tmpl_val, "catalog": cat_val}

	results.append({
		"host_id": host_id,
		"host_name": host_name,
		"ref_id": ref_id,
		"path": "/".join(path),
		"redundant_fields": redundant_fields,
		"override_fields": override_fields,
		"template": template,
	})


func _values_equal(a, b) -> bool:
	if typeof(a) != typeof(b):
		# int vs float comparison
		if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
			return int(a) == int(b)
		# String vs other
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
