extends Control

var all_points: Array[Vector2] = []
var path_indices: Array[int] = []
var target_index := -1
var preview_color := Color.WHITE
var pulse := 0.0
var active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func set_preview(points: Array[Vector2], indices: Array[int], color: Color) -> void:
	all_points = points.duplicate()
	path_indices = indices.duplicate()
	target_index = path_indices.back() if not path_indices.is_empty() else -1
	preview_color = color
	active = target_index >= 0 and target_index < all_points.size()
	queue_redraw()

func clear_preview() -> void:
	active = false
	path_indices.clear()
	target_index = -1
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	pulse += delta
	queue_redraw()

func _draw() -> void:
	if not active or path_indices.is_empty() or all_points.is_empty():
		return
	var path_points = PackedVector2Array()
	for index in path_indices:
		if index >= 0 and index < all_points.size():
			path_points.append(all_points[index])
	if path_points.is_empty():
		return
	var glow = 0.65 + sin(pulse * 7.0) * 0.18
	var path_color = Color(preview_color.r, preview_color.g, preview_color.b, 0.62)
	var edge_color = Color(1.0, 1.0, 1.0, 0.58)
	if path_points.size() >= 2:
		draw_polyline(path_points, Color(0.0, 0.0, 0.0, 0.78), 18.0, true)
		draw_polyline(path_points, path_color, 11.0, true)
		draw_polyline(path_points, edge_color, 3.0, true)
	else:
		draw_circle(path_points[0], 10.0, path_color)
	for i in range(path_points.size()):
		var point = path_points[i]
		var radius = 7.0 + float(i % 2) * 2.0
		draw_circle(point, radius + 4.0, Color(0.0, 0.0, 0.0, 0.55))
		draw_circle(point, radius, path_color)
	var target = all_points[target_index]
	var ring_radius = 42.0 + glow * 10.0
	draw_circle(target, ring_radius + 9.0, Color(0.0, 0.0, 0.0, 0.46))
	draw_arc(target, ring_radius, 0.0, TAU, 48, Color(preview_color.r, preview_color.g, preview_color.b, 0.96), 8.0, true)
	draw_arc(target, ring_radius - 12.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.72), 3.0, true)
	_draw_arrow(target + Vector2(0, -ring_radius - 30.0), target + Vector2(0, -ring_radius + 3.0))

func _draw_arrow(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, Color(0, 0, 0, 0.75), 13.0, true)
	draw_line(from, to, Color(1.0, 0.92, 0.25, 0.98), 7.0, true)
	var dir = (to - from).normalized()
	var side = Vector2(-dir.y, dir.x)
	var head = PackedVector2Array([
		to + dir * 8.0,
		to - dir * 18.0 + side * 14.0,
		to - dir * 18.0 - side * 14.0
	])
	draw_polygon(head, PackedColorArray([Color(0, 0, 0, 0.78)]))
	var inner = PackedVector2Array([
		to + dir * 4.0,
		to - dir * 13.0 + side * 9.0,
		to - dir * 13.0 - side * 9.0
	])
	draw_polygon(inner, PackedColorArray([Color(1.0, 0.92, 0.25, 1.0)]))
