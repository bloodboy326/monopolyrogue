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
	if act.has("generator"):
		return _generate_path_act_map(config, act_id, act, rng)
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

static func _generate_path_act_map(config: Dictionary, act_id: int, act: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var generator: Dictionary = act.get("generator", {})
	var path_floors = max(2, int(generator.get("path_floors", generator.get("floors", 13))))
	var boss_floor = int(generator.get("boss_floor", path_floors + 1))
	if boss_floor <= path_floors:
		boss_floor = path_floors + 1
	var columns = max(3, int(generator.get("columns", 7)))
	var path_count = max(1, int(generator.get("path_count", 6)))
	var rolls = int(generator.get("rolls", 3))
	var boss_column = int((columns - 1) / 2)
	var node_grid: Dictionary = {}
	var edges: Array = []
	var start_columns = _pick_start_columns(columns, path_count, rng)
	var floor_two_targets: Array[int] = []
	for path_index in range(path_count):
		var column = int(start_columns[path_index % start_columns.size()])
		for floor in range(1, path_floors + 1):
			_add_generated_node(node_grid, act_id, floor, column, columns, config, rolls)
			if floor < path_floors:
				var blocked_targets: Array = floor_two_targets if floor == 1 else []
				var next_column = _pick_next_column(column, columns, floor, edges, rng, blocked_targets)
				if floor == 1 and not floor_two_targets.has(next_column):
					floor_two_targets.append(next_column)
				var from_id = _generated_node_id(act_id, floor, column)
				var to_id = _generated_node_id(act_id, floor + 1, next_column)
				_add_generated_node(node_grid, act_id, floor + 1, next_column, columns, config, rolls)
				_add_edge(edges, from_id, to_id)
				column = next_column
	var boss_id = _generated_node_id(act_id, boss_floor, boss_column)
	_add_generated_node(node_grid, act_id, boss_floor, boss_column, columns, config, rolls)
	for key in node_grid.keys():
		var node: Dictionary = node_grid[key]
		if int(node.get("floor", 0)) == path_floors:
			_add_edge(edges, str(node.get("id", "")), boss_id)
	edges = _dedupe_edges(edges)
	var connected_ids = _connected_node_ids(edges)
	var nodes: Array = []
	var keys = node_grid.keys()
	keys = keys.filter(func(key): return connected_ids.has(str(key)))
	keys.sort_custom(func(a, b):
		var na: Dictionary = node_grid[a]
		var nb: Dictionary = node_grid[b]
		if int(na.get("floor", 0)) == int(nb.get("floor", 0)):
			return int(na.get("column_index", 0)) < int(nb.get("column_index", 0))
		return int(na.get("floor", 0)) < int(nb.get("floor", 0))
	)
	for key in keys:
		nodes.append(node_grid[key])
	_assign_generated_room_types(config, act_id, nodes, edges, rng, path_floors, boss_floor, generator)
	return {
		"act_id": act_id,
		"name": str(act.get("name", "第一层")),
		"boss_pool": str(act.get("boss_pool", "")),
		"nodes": nodes,
		"edges": edges
	}

static func _pick_start_columns(columns: int, path_count: int, rng: RandomNumberGenerator) -> Array[int]:
	var starts: Array[int] = []
	while starts.size() < path_count:
		var column = rng.randi_range(0, columns - 1)
		if starts.size() < min(2, columns) and starts.has(column):
			continue
		starts.append(column)
	return starts

static func _add_generated_node(node_grid: Dictionary, act_id: int, floor: int, column_index: int, columns: int, config: Dictionary, rolls: int) -> void:
	var node_id = _generated_node_id(act_id, floor, column_index)
	if node_grid.has(node_id):
		return
	var phase = phase_for_floor(config, act_id, floor)
	node_grid[node_id] = {
		"id": node_id,
		"act_id": act_id,
		"floor": floor,
		"column_index": column_index,
		"column": float(column_index + 1) / float(columns + 1),
		"room_type": "",
		"phase": str(phase.get("phase", "")),
		"normal_pool": str(phase.get("normal_pool", "")),
		"elite_pool": str(phase.get("elite_pool", "")),
		"event_pool": str(phase.get("event_pool", "")),
		"rolls": rolls
	}

static func _generated_node_id(act_id: int, floor: int, column_index: int) -> String:
	return "a%d_f%02d_c%d" % [act_id, floor, column_index]

static func _pick_next_column(column: int, columns: int, floor: int, edges: Array, rng: RandomNumberGenerator, blocked_targets: Array = []) -> int:
	var directions = [-1, 0, 1]
	for i in range(directions.size()):
		var swap = rng.randi_range(i, directions.size() - 1)
		var temp = directions[i]
		directions[i] = directions[swap]
		directions[swap] = temp
	var fallback = clamp(column + int(directions[0]), 0, columns - 1)
	for direction in directions:
		var next_column = clamp(column + int(direction), 0, columns - 1)
		if not blocked_targets.has(next_column) and not _would_cross_edge(column, next_column, floor, edges):
			return next_column
	for direction in directions:
		var next_column = clamp(column + int(direction), 0, columns - 1)
		if not _would_cross_edge(column, next_column, floor, edges):
			return next_column
	return fallback

static func _would_cross_edge(from_col: int, to_col: int, floor: int, edges: Array) -> bool:
	for edge in edges:
		var from_id = str(edge.get("from", ""))
		var to_id = str(edge.get("to", ""))
		var from_parts = _parse_generated_node_id(from_id)
		var to_parts = _parse_generated_node_id(to_id)
		if int(from_parts.get("floor", -1)) != floor or int(to_parts.get("floor", -1)) != floor + 1:
			continue
		var other_from = int(from_parts.get("column", from_col))
		var other_to = int(to_parts.get("column", to_col))
		if from_col < other_from and to_col > other_to:
			return true
		if from_col > other_from and to_col < other_to:
			return true
	return false

static func _parse_generated_node_id(node_id: String) -> Dictionary:
	var result = {"floor": -1, "column": -1}
	var parts = node_id.split("_")
	for part in parts:
		if part.begins_with("f"):
			result["floor"] = int(part.substr(1))
		elif part.begins_with("c"):
			result["column"] = int(part.substr(1))
	return result

static func _assign_generated_room_types(config: Dictionary, act_id: int, nodes: Array, edges: Array, rng: RandomNumberGenerator, path_floors: int, boss_floor: int, generator: Dictionary) -> void:
	var assigned: Dictionary = {}
	var open_nodes: Array = []
	for node in nodes:
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var fixed = _fixed_room_type_for_floor(config, act_id, int(node.get("floor", 1)))
		if not fixed.is_empty():
			node["room_type"] = fixed
			assigned[str(node.get("id", ""))] = fixed
		else:
			open_nodes.append(node)
	var pool = _room_type_pool(generator, open_nodes.size(), rng)
	for node in open_nodes:
		var chosen = ""
		for i in range(pool.size()):
			var candidate = str(pool[i])
			if _room_type_allowed(candidate, node, assigned, edges, path_floors, boss_floor):
				chosen = candidate
				pool.remove_at(i)
				break
		if chosen.is_empty():
			chosen = "MONSTER"
			if not pool.is_empty():
				pool.remove_at(0)
		node["room_type"] = chosen
		assigned[str(node.get("id", ""))] = chosen

static func _fixed_room_type_for_floor(config: Dictionary, act_id: int, floor: int) -> String:
	for rule in config.get("fixed_floor_rules", []):
		if typeof(rule) == TYPE_DICTIONARY and int(rule.get("act_id", 0)) == act_id and int(rule.get("floor", 0)) == floor:
			return str(rule.get("room_type", "MONSTER"))
	return ""

static func _room_type_pool(generator: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var ratios: Dictionary = generator.get("room_type_ratios", {
		"SHOP": 0.05,
		"REST": 0.12,
		"EVENT": 0.22,
		"ELITE": 0.08
	})
	var pool: Array = []
	for room_type in ratios.keys():
		var amount = int(round(float(count) * float(ratios[room_type])))
		for _i in range(amount):
			pool.append(str(room_type))
	while pool.size() < count:
		pool.append("MONSTER")
	_shuffle_array(pool, rng)
	return pool

static func _room_type_allowed(room_type: String, node: Dictionary, assigned: Dictionary, edges: Array, path_floors: int, boss_floor: int) -> bool:
	var floor = int(node.get("floor", 1))
	if room_type == "ELITE" and floor < 5:
		return false
	if room_type == "REST" and (floor < 5 or floor >= path_floors - 1):
		return false
	if room_type == "BOSS" and floor != boss_floor:
		return false
	var node_id = str(node.get("id", ""))
	var parents: Array[String] = []
	for edge in edges:
		if typeof(edge) != TYPE_DICTIONARY:
			continue
		if str(edge.get("to", "")) == node_id:
			parents.append(str(edge.get("from", "")))
	if ["ELITE", "REST", "SHOP", "CHEST"].has(room_type):
		for parent_id in parents:
			if str(assigned.get(parent_id, "")) == room_type:
				return false
	if room_type != "MONSTER":
		for parent_id in parents:
			for edge in edges:
				if typeof(edge) != TYPE_DICTIONARY or str(edge.get("from", "")) != parent_id:
					continue
				var sibling_id = str(edge.get("to", ""))
				if sibling_id != node_id and str(assigned.get(sibling_id, "")) == room_type:
					return false
	return true

static func _connected_node_ids(edges: Array) -> Dictionary:
	var result: Dictionary = {}
	for edge in edges:
		if typeof(edge) != TYPE_DICTIONARY:
			continue
		result[str(edge.get("from", ""))] = true
		result[str(edge.get("to", ""))] = true
	return result

static func _dedupe_edges(edges: Array) -> Array:
	var result: Array = []
	for edge in edges:
		if typeof(edge) != TYPE_DICTIONARY:
			continue
		_add_edge(result, str(edge.get("from", "")), str(edge.get("to", "")))
	return result

static func _shuffle_array(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size()):
		var swap = rng.randi_range(i, items.size() - 1)
		var temp = items[i]
		items[i] = items[swap]
		items[swap] = temp

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
			var target_id = str(edge.get("to", ""))
			if not node_for(map_data, target_id).is_empty():
				ids.append(target_id)
	return ids

static func is_node_available(map_data: Dictionary, current_node_id: String, node_id: String) -> bool:
	return available_node_ids(map_data, current_node_id).has(node_id)

static func node_for(map_data: Dictionary, node_id: String) -> Dictionary:
	for node in map_data.get("nodes", []):
		if typeof(node) == TYPE_DICTIONARY and str(node.get("id", "")) == node_id:
			return node
	return {}

static func pick_monster_for_node(config: Dictionary, node: Dictionary, rng: RandomNumberGenerator, avoid_monster_ids: Array = []) -> String:
	var room_type = str(node.get("room_type", "MONSTER"))
	if ["REST", "SHOP", "CHEST", "EVENT"].has(room_type):
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
	var filtered: Array = []
	for entry in entries:
		if not avoid_monster_ids.has(str(entry.get("monster_id", ""))):
			filtered.append(entry)
	if not filtered.is_empty():
		entries = filtered
	var picked = _weighted_pick(entries, rng)
	return str(picked.get("monster_id", "slime")) if not picked.is_empty() else "slime"

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
