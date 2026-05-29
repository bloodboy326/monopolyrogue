extends Control

var points: Array[Vector2] = []
var pulse = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func set_points(new_points: Array[Vector2]) -> void:
	points = new_points
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	var loop_points = PackedVector2Array()
	for point in points:
		loop_points.append(point)
	loop_points.append(points[0])
	draw_polyline(loop_points, Color(0.0, 0.0, 0.0, 1.0), 20.0, true)
	draw_polyline(loop_points, Color(0.94, 0.36, 0.43, 1.0), 12.0, true)
	draw_polyline(loop_points, Color(1.0, 0.86, 0.22, 0.95), 4.0, true)
