extends Control

const INK = Color(0.02, 0.02, 0.025, 1.0)
const GOLD = Color(1.0, 0.86, 0.22, 1.0)
const RED = Color(0.96, 0.27, 0.36, 1.0)
const BLUE = Color(0.38, 0.68, 1.0, 1.0)
const WHITE = Color(0.96, 0.98, 1.0, 1.0)

var intent_type := "SPECIAL"

func set_intent_type(value: String) -> void:
	intent_type = value
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var bg = RED if intent_type == "ATTACK" else BLUE if intent_type == "DEFEND" else GOLD
	draw_circle(rect.get_center() + Vector2(4, 5), min(size.x, size.y) * 0.42, Color(0, 0, 0, 0.34))
	draw_circle(rect.get_center(), min(size.x, size.y) * 0.42, INK)
	draw_circle(rect.get_center(), min(size.x, size.y) * 0.34, bg)
	match intent_type:
		"ATTACK":
			_draw_sword(rect)
		"DEFEND":
			_draw_shield(rect)
		_:
			_draw_question(rect)

func _draw_sword(rect: Rect2) -> void:
	_line(rect, Vector2(0.34, 0.70), Vector2(0.70, 0.34), INK, 0.10)
	_line(rect, Vector2(0.36, 0.68), Vector2(0.72, 0.32), WHITE, 0.045)
	_line(rect, Vector2(0.30, 0.58), Vector2(0.44, 0.72), INK, 0.055)

func _draw_shield(rect: Rect2) -> void:
	_poly(rect, [Vector2(0.50, 0.22), Vector2(0.70, 0.31), Vector2(0.66, 0.58), Vector2(0.50, 0.74), Vector2(0.34, 0.58), Vector2(0.30, 0.31)], INK)
	_poly(rect, [Vector2(0.50, 0.30), Vector2(0.62, 0.36), Vector2(0.60, 0.55), Vector2(0.50, 0.65), Vector2(0.40, 0.55), Vector2(0.38, 0.36)], WHITE)

func _draw_question(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(rect.size.x * 0.29, rect.size.y * 0.66), "?", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * 0.42, int(rect.size.y * 0.56), INK)

func _line(rect: Rect2, a: Vector2, b: Vector2, color: Color, width_ratio: float) -> void:
	draw_line(_pt(rect, a), _pt(rect, b), color, max(1.0, rect.size.x * width_ratio), true)

func _poly(rect: Rect2, points: Array[Vector2], color: Color) -> void:
	var packed = PackedVector2Array()
	for point in points:
		packed.append(_pt(rect, point))
	draw_polygon(packed, PackedColorArray([color]))

func _pt(rect: Rect2, point: Vector2) -> Vector2:
	return rect.position + Vector2(rect.size.x * point.x, rect.size.y * point.y)
