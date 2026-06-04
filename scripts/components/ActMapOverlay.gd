extends Control

signal node_selected(node_id: String)

const MapConfig = preload("res://scripts/data/MapConfig.gd")
const MapNodeIcon = preload("res://scripts/components/MapNodeIcon.gd")

const INK = Color(0.08, 0.11, 0.13, 0.92)
const FADED_INK = Color(0.18, 0.21, 0.22, 0.45)
const GOLD = Color(0.94, 0.68, 0.18, 1.0)
const CLOTH = Color(0.66, 0.65, 0.56, 1.0)

var map_data: Dictionary = {}
var current_node_id := ""
var node_positions: Dictionary = {}
var available_ids: Array[String] = []
var scroll_offset_y := 0.0
var dragging := false
var drag_start_mouse := Vector2.ZERO
var drag_start_scroll := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void:
		_focus_current_route()
		_refresh_nodes()
	)

func setup(new_map_data: Dictionary, new_current_node_id: String) -> void:
	map_data = new_map_data
	current_node_id = new_current_node_id
	available_ids = MapConfig.available_node_ids(map_data, current_node_id)
	_focus_current_route()
	_refresh_nodes()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_scroll(scroll_offset_y + 92.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_scroll(scroll_offset_y - 92.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			drag_start_mouse = event.position
			drag_start_scroll = scroll_offset_y
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		_set_scroll(drag_start_scroll + event.position.y - drag_start_mouse.y)
		accept_event()

func _set_scroll(value: float) -> void:
	scroll_offset_y = clamp(value, _min_scroll_offset(), 0.0)
	_refresh_nodes()

func _focus_current_route() -> void:
	if map_data.is_empty() or size.y <= 1.0:
		return
	var floor_range = _floor_range()
	var min_floor = int(floor_range["min"])
	var max_floor = int(floor_range["max"])
	var floor_span = max(1, max_floor - min_floor)
	var focus_floor = min_floor
	if not current_node_id.is_empty():
		var current_node = MapConfig.node_for(map_data, current_node_id)
		if not current_node.is_empty():
			focus_floor = int(current_node.get("floor", min_floor))
	elif not available_ids.is_empty():
		var first = MapConfig.node_for(map_data, available_ids[0])
		if not first.is_empty():
			focus_floor = int(first.get("floor", min_floor))
	var base_top = 82.0
	var base_y = base_top + _content_height() * (1.0 - float(focus_floor - min_floor) / float(floor_span))
	var target_y = size.y * 0.58
	scroll_offset_y = clamp(target_y - base_y, _min_scroll_offset(), 0.0)

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
		var icon_size = Vector2(70, 70) if str(node.get("room_type", "")) == "BOSS" else Vector2(58, 58)
		icon.size = icon_size
		icon.position = node_positions.get(node_id, Vector2.ZERO) - icon_size * 0.5
		icon.setup(node, available_ids.has(node_id), node_id == current_node_id)
		icon.picked.connect(func(picked_id: String) -> void:
			node_selected.emit(picked_id)
		)
		add_child(icon)
	queue_redraw()

func _draw() -> void:
	_draw_cloth_background()
	_draw_edges(false)
	_draw_edges(true)
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(size.x * 0.5 - 170, 48), "选择路线", HORIZONTAL_ALIGNMENT_CENTER, 340, 34, INK)
	draw_string(font, Vector2(size.x * 0.5 - 210, size.y - 24), "按住左键拖动或滚轮查看地图", HORIZONTAL_ALIGNMENT_CENTER, 420, 16, Color(0.12, 0.13, 0.12, 0.54))

func _draw_cloth_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CLOTH, true)
	for x in range(-80, int(size.x) + 120, 62):
		draw_line(Vector2(x, 0), Vector2(x + 180, size.y), Color(0.54, 0.54, 0.48, 0.12), 3.0, true)
	for y in range(12, int(size.y), 54):
		draw_line(Vector2(0, y), Vector2(size.x, y + sin(float(y) * 0.04) * 8.0), Color(0.78, 0.76, 0.66, 0.11), 2.0, true)
	var edge_shadow = Color(0.18, 0.15, 0.10, 0.16)
	draw_rect(Rect2(Vector2(14, 14), size - Vector2(28, 28)), edge_shadow, false, 8.0)
	draw_rect(Rect2(Vector2(26, 26), size - Vector2(52, 52)), Color(0.86, 0.83, 0.68, 0.18), false, 2.0)

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
		if is_available_edge:
			draw_line(from_pos + Vector2(3, 4), to_pos + Vector2(3, 4), Color(0, 0, 0, 0.28), 7.0, true)
			draw_line(from_pos, to_pos, GOLD, 5.0, true)
		else:
			_draw_dashed_line(from_pos, to_pos, FADED_INK, 3.0, 12.0, 10.0)

func _draw_dashed_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var delta = to_pos - from_pos
	var length = delta.length()
	if length <= 0.01:
		return
	var direction = delta / length
	var cursor = 0.0
	while cursor < length:
		var next = min(length, cursor + dash)
		draw_line(from_pos + direction * cursor, from_pos + direction * next, color, width, true)
		cursor += dash + gap

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
	var width = min(size.x - 180.0, 880.0)
	var height = _content_height()
	return Rect2(Vector2((size.x - width) * 0.5, 82.0 + scroll_offset_y), Vector2(width, height))

func _content_height() -> float:
	var floors = _floor_range()
	var floor_count = max(1, int(floors["max"]) - int(floors["min"]) + 1)
	return max(size.y * 2.25, float(floor_count) * 112.0)

func _min_scroll_offset() -> float:
	return min(0.0, size.y - 80.0 - _content_height() - 82.0)
