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
	var halo = Color(0.0, 0.9, 1.0, 0.16 + sin(pulse * 2.2) * 0.04)
	var core = Color(1.0, 0.27, 0.78, 0.32 + sin(pulse * 3.4) * 0.05)
	draw_polyline(loop_points, halo, 26.0, true)
	draw_polyline(loop_points, Color(0.05, 0.02, 0.13, 0.88), 17.0, true)
	draw_polyline(loop_points, core, 5.0, true)
