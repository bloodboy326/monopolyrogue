extends RefCounted

const MAP_CONFIG_PATH = "res://data/map_config.json"

static func load_config() -> Dictionary:
	if not FileAccess.file_exists(MAP_CONFIG_PATH):
		return {}
	var file = FileAccess.open(MAP_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func generate_act_map(config: Dictionary, act_id: int, rng: RandomNumberGenerator) -> Dictionary:
	var act = act_for(config, act_id)
	var rows: Array = []
	var nodes: Array = []
	for row_def in act.get("layout", []):
		if typeof(row_def) != TYPE_DICTIONARY:
			continue
		var floor = int(row_def.get("floor", rows.size() + 1))
		var slots: Array = row_def.get("slots", [0.5])
		var row_nodes: Array = []
		for slot_index in range(slots.size()):
			var phase = phase_for_floor(config, act_id, floor)
			var room_type = str(row_def.get("room_type", ""))
			if room_type.is_empty():
				room_type = pick_room_type(config, act_id, floor, rng)
			var node = {
				"id": "a%d_f%02d_n%d" % [act_id, floor, slot_index],
				"act_id": act_id,
				"floor": floor,
				"column": float(slots[slot_index]),
				"room_type": room_type,
				"phase": str(phase.get("phase", "")),
				"normal_pool": str(phase.get("normal_pool", "")),
				"elite_pool": str(phase.get("elite_pool", "")),
				"event_pool": str(phase.get("event_pool", "")),
				"rolls": int(row_def.get("rolls", 3))
			}
			nodes.append(node)
			row_nodes.append(node)
		rows.append(row_nodes)
	return {
		"act_id": act_id,
		"name": str(act.get("name", "第一层")),
		"boss_pool": str(act.get("boss_pool", "")),
		"nodes": nodes,
		"edges": _generate_edges(rows, rng)
	}

static func act_for(config: Dictionary, act_id: int) -> Dictionary:
	for act in config.get("acts", []):
		if typeof(act) == TYPE_DICTIONARY and int(act.get("act_id", 0)) == act_id:
			return act
	return {}

static func phase_for_floor(config: Dictionary, act_id: int, floor: int) -> Dictionary:
	for phase in config.get("floor_phases", []):
		if typeof(phase) != TYPE_DICTIONARY:
			continue
		if int(phase.get("act_id", 0)) != act_id:
			continue
		if floor >= int(phase.get("floor_min", 0)) and floor <= int(phase.get("floor_max", 999)):
			return phase
	return {}

static func pick_room_type(config: Dictionary, act_id: int, floor: int, rng: RandomNumberGenerator) -> String:
	for rule in config.get("fixed_floor_rules", []):
		if typeof(rule) == TYPE_DICTIONARY and int(rule.get("act_id", 0)) == act_id and int(rule.get("floor", 0)) == floor:
			return str(rule.get("room_type", "MONSTER"))
	var phase = phase_for_floor(config, act_id, floor)
	var weight_set = str(phase.get("room_weight_set", ""))
	var entries: Array = []
	for entry in config.get("room_type_weights", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("weight_set", "")) != weight_set:
			continue
		if floor < int(entry.get("min_floor", 1)) or floor > int(entry.get("max_floor", 999)):
			continue
		if int(entry.get("weight", 0)) > 0:
			entries.append(entry)
	var picked = _weighted_pick(entries, rng)
	return str(picked.get("room_type", "MONSTER")) if not picked.is_empty() else "MONSTER"

static func available_node_ids(map_data: Dictionary, current_node_id: String) -> Array[String]:
	var ids: Array[String] = []
	if current_node_id.is_empty():
		var first_floor = _first_floor(map_data)
		for node in map_data.get("nodes", []):
			if typeof(node) == TYPE_DICTIONARY and int(node.get("floor", 0)) == first_floor:
				ids.append(str(node.get("id", "")))
		return ids
	for edge in map_data.get("edges", []):
		if typeof(edge) == TYPE_DICTIONARY and str(edge.get("from", "")) == current_node_id:
			ids.append(str(edge.get("to", "")))
	return ids

static func is_node_available(map_data: Dictionary, current_node_id: String, node_id: String) -> bool:
	return available_node_ids(map_data, current_node_id).has(node_id)

static func node_for(map_data: Dictionary, node_id: String) -> Dictionary:
	for node in map_data.get("nodes", []):
		if typeof(node) == TYPE_DICTIONARY and str(node.get("id", "")) == node_id:
			return node
	return {}

static func pick_monster_for_node(config: Dictionary, node: Dictionary, rng: RandomNumberGenerator) -> String:
	var room_type = str(node.get("room_type", "MONSTER"))
	if room_type == "REST":
		return ""
	var pool_id = str(node.get("normal_pool", ""))
	if room_type == "ELITE":
		pool_id = str(node.get("elite_pool", pool_id))
	elif room_type == "BOSS":
		pool_id = str(act_for(config, int(node.get("act_id", 1))).get("boss_pool", pool_id))
	# EVENT is a placeholder in this version: it uses the normal monster pool.
	var entries: Array = []
	for entry in config.get("monster_pool_entries", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("pool_id", "")) == pool_id and int(entry.get("weight", 0)) > 0:
			entries.append(entry)
	var picked = _weighted_pick(entries, rng)
	return str(picked.get("monster_id", "slime_boss")) if not picked.is_empty() else "slime_boss"

static func _generate_edges(rows: Array, rng: RandomNumberGenerator) -> Array:
	var edges: Array = []
	for row_index in range(rows.size() - 1):
		var current_row: Array = rows[row_index]
		var next_row: Array = rows[row_index + 1]
		var incoming: Dictionary = {}
		for node in current_row:
			var sorted_next = next_row.duplicate()
			var source_col = float(node.get("column", 0.5))
			sorted_next.sort_custom(func(a, b): return abs(float(a.get("column", 0.5)) - source_col) < abs(float(b.get("column", 0.5)) - source_col))
			var connection_count = 1
			if sorted_next.size() > 1 and rng.randf() < 0.42:
				connection_count = 2
			for i in range(min(connection_count, sorted_next.size())):
				_add_edge(edges, str(node.get("id", "")), str(sorted_next[i].get("id", "")))
				incoming[str(sorted_next[i].get("id", ""))] = true
		for next_node in next_row:
			var next_id = str(next_node.get("id", ""))
			if incoming.has(next_id):
				continue
			var sorted_current = current_row.duplicate()
			var target_col = float(next_node.get("column", 0.5))
			sorted_current.sort_custom(func(a, b): return abs(float(a.get("column", 0.5)) - target_col) < abs(float(b.get("column", 0.5)) - target_col))
			if not sorted_current.is_empty():
				_add_edge(edges, str(sorted_current[0].get("id", "")), next_id)
	return edges

static func _add_edge(edges: Array, from_id: String, to_id: String) -> void:
	if from_id.is_empty() or to_id.is_empty():
		return
	for edge in edges:
		if str(edge.get("from", "")) == from_id and str(edge.get("to", "")) == to_id:
			return
	edges.append({"from": from_id, "to": to_id})

static func _first_floor(map_data: Dictionary) -> int:
	var first_floor = 999
	for node in map_data.get("nodes", []):
		if typeof(node) == TYPE_DICTIONARY:
			first_floor = min(first_floor, int(node.get("floor", 999)))
	return 1 if first_floor == 999 else first_floor

static func _weighted_pick(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total = 0
	for entry in entries:
		total += max(0, int(entry.get("weight", 0)))
	if total <= 0:
		return {}
	var roll = rng.randi_range(1, total)
	var cursor = 0
	for entry in entries:
		cursor += max(0, int(entry.get("weight", 0)))
		if roll <= cursor:
			return entry
	return entries.back() if not entries.is_empty() else {}
