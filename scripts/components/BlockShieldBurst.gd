extends Control

const INK = Color(0.02, 0.02, 0.03, 1.0)
const BLUE = Color(0.30, 0.68, 1.0, 1.0)
const LIGHT = Color(0.82, 0.95, 1.0, 1.0)

var shield_alpha := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 1200
	pivot_offset = size * 0.5

func play(center: Vector2, target_size: Vector2 = Vector2(94, 94)) -> void:
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	size = target_size
	pivot_offset = size * 0.5
	global_position = center - size * 0.5
	scale = Vector2(0.44, 0.44)
	shield_alpha = 0.0
	queue_redraw()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.20, 1.20), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.18).set_delay(0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_alpha, 0.0, 1.0, 0.10)
	tween.tween_method(_set_alpha, 1.0, 0.0, 0.22).set_delay(0.36)
	tween.tween_property(self, "position:y", position.y - 18.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)

func _set_alpha(value: float) -> void:
	shield_alpha = value
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var points = [
		Vector2(0.50, 0.07),
		Vector2(0.82, 0.20),
		Vector2(0.76, 0.62),
		Vector2(0.50, 0.90),
		Vector2(0.24, 0.62),
		Vector2(0.18, 0.20)
	]
	_poly(rect, points, Color(0, 0, 0, 0.34 * shield_alpha), Vector2(5, 7))
	_poly(rect, points, Color(0.0, 0.03, 0.10, shield_alpha), Vector2.ZERO)
	var inner = [
		Vector2(0.50, 0.17),
		Vector2(0.70, 0.26),
		Vector2(0.66, 0.56),
		Vector2(0.50, 0.76),
		Vector2(0.34, 0.56),
		Vector2(0.30, 0.26)
	]
	_poly(rect, inner, Color(BLUE.r, BLUE.g, BLUE.b, 0.92 * shield_alpha), Vector2.ZERO)
	draw_line(_pt(rect, Vector2(0.50, 0.20)), _pt(rect, Vector2(0.50, 0.74)), Color(LIGHT.r, LIGHT.g, LIGHT.b, 0.95 * shield_alpha), max(2.0, size.x * 0.055), true)
	draw_arc(size * 0.5, size.x * 0.46, -0.78, 3.88, 18, Color(0.74, 0.94, 1.0, 0.55 * shield_alpha), max(2.0, size.x * 0.035), true)

func _poly(rect: Rect2, points: Array, color: Color, offset: Vector2) -> void:
	var packed = PackedVector2Array()
	for point in points:
		var point_vec: Vector2 = point
		packed.append(_pt(rect, point_vec) + offset)
	draw_polygon(packed, PackedColorArray([color]))

func _pt(rect: Rect2, point: Vector2) -> Vector2:
	return rect.position + Vector2(rect.size.x * point.x, rect.size.y * point.y)
