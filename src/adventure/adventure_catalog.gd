class_name AdventureCatalog
extends RefCounted

const ADVENTURES_DIR := "res://data/adventures/"


static func load_adventure(adventure_id: String) -> Dictionary:
	var path := ADVENTURES_DIR + adventure_id + ".json"
	return _load_json_file(path)


static func load_all_adventures() -> Array:
	var adventures: Array = []
	var dir := DirAccess.open(ADVENTURES_DIR)
	if dir == null:
		push_error("AdventureCatalog: cannot open directory '%s'" % ADVENTURES_DIR)
		return adventures
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			var data := _load_json_file(ADVENTURES_DIR + file_name)
			if not data.is_empty():
				adventures.append(data)
		file_name = dir.get_next()
	dir.list_dir_end()
	return adventures


static func get_adventures_for_deck(deck_id: String) -> Array:
	var all := load_all_adventures()
	var result: Array = []
	for adventure in all:
		var allowed_decks: Array = adventure.get("allowed_deck_ids", [])
		if allowed_decks.is_empty() or deck_id in allowed_decks:
			result.append(adventure)
	return result


static func get_node_by_id(adventure: Dictionary, node_id: String) -> Dictionary:
	var nodes: Dictionary = adventure.get("nodes", {})
	return nodes.get(node_id, {})


static func get_start_node(adventure: Dictionary) -> Dictionary:
	var start_id: String = adventure.get("start_node", "")
	if start_id.is_empty():
		return {}
	return get_node_by_id(adventure, start_id)


static func get_ordered_node_list(adventure: Dictionary) -> Array:
	# Returns a flat list for linear adventures. For branching, follows the first path.
	var ordered: Array = []
	var start_id: String = adventure.get("start_node", "")
	if start_id.is_empty():
		return ordered
	var nodes: Dictionary = adventure.get("nodes", {})
	var current_id := start_id
	while not current_id.is_empty():
		var node: Dictionary = nodes.get(current_id, {})
		if node.is_empty():
			break
		var entry := node.duplicate()
		entry["id"] = current_id
		ordered.append(entry)
		var next_nodes: Array = node.get("next", [])
		if next_nodes.size() >= 1:
			current_id = str(next_nodes[0])
		else:
			break
	return ordered


static func get_graph_layers(adventure: Dictionary) -> Array:
	# Returns an array of layers, where each layer is an array of node entries.
	# Each layer represents one row in the visual graph.
	# Layer structure: [{"id": "node_1", "type": "combat", ...}, ...]
	var layers: Array = []
	var start_id: String = adventure.get("start_node", "")
	if start_id.is_empty():
		return layers
	var nodes: Dictionary = adventure.get("nodes", {})
	var current_ids: Array = [start_id]
	var visited: Dictionary = {}

	while not current_ids.is_empty():
		var layer: Array = []
		var next_ids: Array = []
		for node_id in current_ids:
			var nid: String = str(node_id)
			if visited.has(nid):
				continue
			visited[nid] = true
			var node: Dictionary = nodes.get(nid, {})
			if node.is_empty():
				continue
			var entry := node.duplicate()
			entry["id"] = nid
			layer.append(entry)
			for next_id in node.get("next", []):
				var next_str: String = str(next_id)
				if not visited.has(next_str):
					next_ids.append(next_str)
		if not layer.is_empty():
			layers.append(layer)
		current_ids = next_ids

	return layers


static func validate_adventure(adventure: Dictionary) -> Dictionary:
	var errors: Array = []

	if not adventure.has("id") or str(adventure["id"]).is_empty():
		errors.append("Missing or empty 'id' field")
	if not adventure.has("name") or str(adventure["name"]).is_empty():
		errors.append("Missing or empty 'name' field")
	if not adventure.has("start_node") or str(adventure["start_node"]).is_empty():
		errors.append("Missing or empty 'start_node' field")
	if not adventure.has("nodes") or not adventure["nodes"] is Dictionary:
		errors.append("Missing or invalid 'nodes' field")
		return {"is_valid": false, "errors": errors}

	var nodes: Dictionary = adventure["nodes"]
	if nodes.is_empty():
		errors.append("Adventure has no nodes")

	var start_id: String = str(adventure.get("start_node", ""))
	if not start_id.is_empty() and not nodes.has(start_id):
		errors.append("start_node '%s' does not exist in nodes" % start_id)

	var valid_types := ["combat", "mini_boss", "final_boss", "healer", "reinforcement", "shop", "boon", "creature_augment", "action_augment", "event"]
	var combat_types := ["combat", "mini_boss", "final_boss"]
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		var node_type: String = str(node.get("type", ""))
		if node_type.is_empty():
			errors.append("Node '%s' has no type" % node_id)
		elif node_type not in valid_types:
			errors.append("Node '%s' has unknown type '%s'" % [node_id, node_type])

		if node_type in combat_types:
			if not node.has("enemy_deck") or str(node["enemy_deck"]).is_empty():
				errors.append("Combat node '%s' has no enemy_deck" % node_id)

		if node_type == "event":
			var event_data = node.get("event", null)
			if event_data == null or typeof(event_data) != TYPE_DICTIONARY:
				errors.append("Event node '%s' has no 'event' field" % node_id)
			elif not event_data.has("choices") or typeof(event_data.get("choices")) != TYPE_ARRAY or event_data.get("choices", []).is_empty():
				errors.append("Event node '%s' has no choices" % node_id)

		var next_nodes: Array = node.get("next", [])
		for next_id in next_nodes:
			if not nodes.has(str(next_id)):
				errors.append("Node '%s' references non-existent next node '%s'" % [node_id, str(next_id)])

	return {"is_valid": errors.is_empty(), "errors": errors}


static func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AdventureCatalog: failed to open '%s': %s" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("AdventureCatalog: failed to parse '%s': %s" % [path, json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
