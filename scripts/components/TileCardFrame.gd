extends RefCounted

const OUTER_COLOR = Color(0.045, 0.036, 0.065, 1.0)
const MID_COLOR = Color(0.0, 0.0, 0.0, 0.34)
const CHOICE_BG = Color(0.035, 0.16, 0.15, 0.96)
const CHOICE_OUTER = Color(0.035, 0.032, 0.052, 1.0)

static func draw_icon_card(canvas: CanvasItem, rect: Rect2, face_color: Color, radius: float = -1.0) -> void:
	var resolved_radius = radius
	if resolved_radius < 0.0:
		resolved_radius = min(rect.size.x, rect.size.y) * 0.12
	_draw_rounded_box(canvas, rect, resolved_radius, OUTER_COLOR)
	_draw_rounded_box(canvas, rect.grow(-3.0), resolved_radius * 0.72, MID_COLOR)
	_draw_rounded_box(canvas, rect.grow(-6.0), resolved_radius * 0.52, face_color.lightened(0.08))

static func draw_choice_frame(canvas: CanvasItem, rect: Rect2, rare_color: Color) -> void:
	_draw_rounded_box(canvas, rect, 3.0, CHOICE_OUTER)
	_draw_rounded_box(canvas, rect.grow(-4.0), 2.0, CHOICE_BG)
	draw_rect_outline(canvas, rect.grow(-2.0), Color.BLACK, 2.0)
	draw_rect_outline(canvas, rect.grow(-5.0), rare_color.darkened(0.35), 2.0)

static func draw_rect_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color, true)
	canvas.draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - width), Vector2(rect.size.x, width)), color, true)
	canvas.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color, true)
	canvas.draw_rect(Rect2(Vector2(rect.end.x - width, rect.position.y), Vector2(width, rect.size.y)), color, true)

static func _draw_rounded_box(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	var corner = int(max(0.0, radius))
	box.corner_radius_top_left = corner
	box.corner_radius_top_right = corner
	box.corner_radius_bottom_left = corner
	box.corner_radius_bottom_right = corner
	canvas.draw_style_box(box, rect)
