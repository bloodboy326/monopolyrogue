extends Control

signal node_selected(node_id: String)

const MapConfig = preload("res://scripts/data/MapConfig.gd")
const MapNodeIcon = preload("res://scripts/components/MapNodeIcon.gd")

const INK = Color(0.02, 0.02, 0.025, 1.0)
const GOLD = Color(1.0, 0.82, 0.22, 1.0)

var map_data: Dictionary = {}
var current_node_id := ""
var node_positions: Dictionary = {}
var available_ids: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_refresh_nodes)

func setup(new_map_data: Dictionary, new_current_node_id: String) -> void:
	map_data = new_map_data
	current_node_id = new_current_node_id
	available_ids = MapConfig.available_node_ids(map_data, current_node_id)
	_refresh_nodes()

func _refresh_nodes() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	node_positions = _calculate_node_positions()
	for node in map_data.get("nodes", []):
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var node_id = str(node.get("id", ""))
		var icon = MapNodeIcon.new()
		var icon_size = Vector2(66, 66) if str(node.get("room_type", "")) == "BOSS" else Vector2(56, 56)
		icon.size = icon_size
		icon.position = node_positions.get(node_id, Vector2.ZERO) - icon_size * 0.5
		icon.setup(node, available_ids.has(node_id), node_id == current_node_id)
		icon.picked.connect(func(picked_id: String) -> void:
			node_selected.emit(picked_id)
		)
		add_child(icon)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.018, 0.035, 0.88), true)
	var map_rect = _map_rect()
	draw_rect(map_rect.grow(18), Color(0.02, 0.02, 0.025, 0.32), true)
	draw_rect(map_rect.grow(18), Color(0.80, 0.65, 0.25, 0.35), false, 2.0)
	_draw_edges(false)
	_draw_edges(true)
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(size.x * 0.5 - 170, 48), "选择路线", HORIZONTAL_ALIGNMENT_CENTER, 340, 34, Color.WHITE)

func _draw_edges(available_only: bool) -> void:
	for edge in map_data.get("edges", []):
		if typeof(edge) != TYPE_DICTIONARY:
			continue
		var from_id = str(edge.get("from", ""))
		var to_id = str(edge.get("to", ""))
		if not node_positions.has(from_id) or not node_positions.has(to_id):
			continue
		var is_available_edge = current_node_id == from_id or (current_node_id.is_empty() and available_ids.has(from_id))
		if available_only != is_available_edge:
			continue
		var from_pos: Vector2 = node_positions[from_id]
		var to_pos: Vector2 = node_positions[to_id]
		var color = GOLD if is_available_edge else Color(0.28, 0.31, 0.42, 0.72)
		var width = 6.0 if is_available_edge else 3.0
		draw_line(from_pos + Vector2(4, 5), to_pos + Vector2(4, 5), Color(0, 0, 0, 0.45), width + 5.0, true)
		draw_line(from_pos, to_pos, color, width, true)

func _calculate_node_positions() -> Dictionary:
	var positions: Dictionary = {}
	var floors = _floor_range()
	var min_floor = int(floors["min"])
	var max_floor = int(floors["max"])
	var floor_span = max(1, max_floor - min_floor)
	var map_rect = _map_rect()
	for node in map_data.get("nodes", []):
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var floor = int(node.get("floor", min_floor))
		var column = float(node.get("column", 0.5))
		var x = map_rect.position.x + map_rect.size.x * column
		var y_t = float(floor - min_floor) / float(floor_span)
		var y = map_rect.position.y + map_rect.size.y * (1.0 - y_t)
		positions[str(node.get("id", ""))] = Vector2(x, y)
	return positions

func _floor_range() -> Dictionary:
	var min_floor = 999
	var max_floor = 1
	for node in map_data.get("nodes", []):
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var floor = int(node.get("floor", 1))
		min_floor = min(min_floor, floor)
		max_floor = max(max_floor, floor)
	if min_floor == 999:
		min_floor = 1
	return {"min": min_floor, "max": max_floor}

func _map_rect() -> Rect2:
	var width = min(size.x - 160.0, 760.0)
	var height = max(520.0, size.y - 160.0)
	return Rect2(Vector2((size.x - width) * 0.5, 82.0), Vector2(width, height))
