extends RefCounted

const INK = Color(0.015, 0.014, 0.018, 1.0)
const DARK_PANEL = Color(0.04, 0.045, 0.05, 1.0)
const SHADOW = Color(0.0, 0.0, 0.0, 0.36)
const PAPER = Color(0.98, 0.95, 0.82, 1.0)

static func draw_icon_card(canvas: CanvasItem, rect: Rect2, face_color: Color, radius: float = -1.0) -> void:
	var resolved_radius = radius
	if resolved_radius < 0.0:
		resolved_radius = min(rect.size.x, rect.size.y) * 0.12
	_draw_rounded_box(canvas, Rect2(rect.position + Vector2(5.0, 6.0), rect.size), resolved_radius, SHADOW)
	_draw_rounded_box(canvas, rect, resolved_radius, INK)
	_draw_rounded_box(canvas, rect.grow(-5.0), max(0.0, resolved_radius - 5.0), face_color)

static func draw_choice_frame(canvas: CanvasItem, rect: Rect2, rare_color: Color) -> void:
	_draw_rounded_box(canvas, Rect2(rect.position + Vector2(8.0, 9.0), rect.size), 8.0, SHADOW)
	_draw_rounded_box(canvas, rect, 7.0, INK)
	_draw_rounded_box(canvas, rect.grow(-6.0), 3.0, DARK_PANEL)
	canvas.draw_rect(Rect2(rect.position + Vector2(10.0, 10.0), Vector2(rect.size.x - 20.0, 28.0)), rare_color, true)

static func draw_rect_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color, true)
	canvas.draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - width), Vector2(rect.size.x, width)), color, true)
	canvas.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color, true)
	canvas.draw_rect(Rect2(Vector2(rect.end.x - width, rect.position.y), Vector2(width, rect.size.y)), color, true)

static func draw_vector_button(canvas: CanvasItem, rect: Rect2, fill: Color, pressed: bool = false) -> void:
	var offset = Vector2(3.0, 5.0)
	if pressed:
		offset = Vector2(1.0, 2.0)
	_draw_rounded_box(canvas, Rect2(rect.position + offset, rect.size), 8.0, SHADOW)
	_draw_rounded_box(canvas, rect, 8.0, INK)
	_draw_rounded_box(canvas, rect.grow(-4.0), 4.0, fill)

static func _draw_rounded_box(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	var corner = int(max(0.0, radius))
	box.set_corner_radius_all(corner)
	canvas.draw_style_box(box, rect)
