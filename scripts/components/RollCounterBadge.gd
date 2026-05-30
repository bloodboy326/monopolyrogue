extends Control

var rolls_left := 3
var total_rolls := 3

func set_counts(left: int, total: int) -> void:
	rolls_left = max(0, left)
	total_rolls = max(1, total)
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var center = rect.get_center()
	var radius = min(size.x, size.y) * 0.48
	var points = PackedVector2Array()
	for i in range(8):
		var angle = -PI * 0.5 + TAU * float(i) / 8.0
		var r = radius * (1.0 if i % 2 == 0 else 0.92)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_polygon(points, PackedColorArray([Color(0.32, 0.07, 0.05, 1.0)]))
	var inner = PackedVector2Array()
	for point in points:
		inner.append(center.lerp(point, 0.82))
	draw_polygon(inner, PackedColorArray([Color(0.92, 0.24, 0.16, 1.0)]))
	draw_arc(center, radius * 0.88, -PI * 0.82, PI * 0.15, 18, Color(1.0, 0.72, 0.24, 0.95), 5.0)
	draw_arc(center, radius * 0.72, PI * 0.12, PI * 0.88, 12, Color(0.55, 0.06, 0.04, 0.45), 4.0)
	var font = ThemeDB.fallback_font
	var text = "%d/%d" % [rolls_left, total_rolls]
	draw_string(font, Vector2(0, size.y * 0.61), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(size.y * 0.42), Color.WHITE)
