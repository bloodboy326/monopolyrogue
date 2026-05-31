extends Control

signal picked(node_id: String)

const INK = Color(0.02, 0.02, 0.025, 1.0)
const WHITE = Color(0.96, 0.98, 1.0, 1.0)
const GOLD = Color(1.0, 0.82, 0.22, 1.0)
const LOCKED = Color(0.24, 0.25, 0.28, 0.96)

var node_id := ""
var room_type := "MONSTER"
var available := false
var current := false
var hovered := false

func setup(node_data: Dictionary, is_available: bool, is_current: bool) -> void:
	node_id = str(node_data.get("id", ""))
	room_type = str(node_data.get("room_type", "MONSTER"))
	available = is_available
	current = is_current
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _ready() -> void:
	mouse_entered.connect(func() -> void:
		hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hovered = false
		queue_redraw()
	)

func _gui_input(event: InputEvent) -> void:
	if not available:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		picked.emit(node_id)

func _draw() -> void:
	var center = size * 0.5
	var radius = min(size.x, size.y) * (0.39 if not hovered else 0.43)
	var fill = _room_color()
	if not available and not current:
		fill = LOCKED
	draw_circle(center + Vector2(4, 6), radius, Color(0, 0, 0, 0.42))
	draw_circle(center, radius, INK)
	draw_circle(center, radius * 0.82, fill)
	if available:
		draw_arc(center, radius * 1.05, 0.0, TAU, 48, GOLD, 4.0, true)
	if current:
		draw_arc(center, radius * 1.12, 0.0, TAU, 48, Color(0.30, 1.0, 0.58), 5.0, true)
	match room_type:
		"EVENT":
			_draw_question(center, radius)
		"ELITE":
			_draw_elite(center, radius)
		"REST":
			_draw_fire(center, radius)
		"BOSS":
			_draw_boss(center, radius)
		_:
			_draw_monster(center, radius)

func _room_color() -> Color:
	match room_type:
		"EVENT":
			return Color(0.28, 0.56, 0.92, 1.0)
		"ELITE":
			return Color(0.66, 0.35, 0.92, 1.0)
		"REST":
			return Color(1.0, 0.48, 0.18, 1.0)
		"BOSS":
			return Color(0.92, 0.18, 0.26, 1.0)
		_:
			return Color(0.88, 0.30, 0.36, 1.0)

func _draw_question(center: Vector2, radius: float) -> void:
	var font = ThemeDB.fallback_font
	draw_string(font, center + Vector2(-radius * 0.32, radius * 0.43), "?", HORIZONTAL_ALIGNMENT_CENTER, radius * 0.64, int(radius * 1.22), INK)

func _draw_monster(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(-radius * 0.24, -radius * 0.06), radius * 0.11, INK)
	draw_circle(center + Vector2(radius * 0.24, -radius * 0.06), radius * 0.11, INK)
	_line(center, Vector2(-0.34, 0.20), Vector2(-0.12, 0.34), radius, INK, 0.08)
	_line(center, Vector2(0.12, 0.34), Vector2(0.34, 0.20), radius, INK, 0.08)
	_poly(center, radius, [Vector2(-0.52, -0.42), Vector2(-0.18, -0.22), Vector2(-0.36, -0.02)], WHITE)
	_poly(center, radius, [Vector2(0.52, -0.42), Vector2(0.18, -0.22), Vector2(0.36, -0.02)], WHITE)

func _draw_elite(center: Vector2, radius: float) -> void:
	_draw_monster(center, radius)
	_poly(center, radius, [Vector2(-0.48, -0.56), Vector2(-0.22, -0.86), Vector2(0.0, -0.52), Vector2(0.22, -0.86), Vector2(0.48, -0.56), Vector2(0.38, -0.36), Vector2(-0.38, -0.36)], GOLD)

func _draw_fire(center: Vector2, radius: float) -> void:
	_poly(center, radius, [Vector2(0.00, -0.70), Vector2(0.34, -0.10), Vector2(0.20, 0.42), Vector2(-0.24, 0.42), Vector2(-0.38, -0.06)], Color(1.0, 0.92, 0.18))
	_poly(center, radius, [Vector2(0.06, -0.40), Vector2(0.22, 0.02), Vector2(0.04, 0.30), Vector2(-0.16, 0.06)], Color(1.0, 0.25, 0.18))
	_line(center, Vector2(-0.48, 0.48), Vector2(0.48, 0.48), radius, INK, 0.12)

func _draw_boss(center: Vector2, radius: float) -> void:
	_poly(center, radius, [Vector2(-0.76, -0.44), Vector2(-0.36, -0.22), Vector2(-0.58, 0.00)], WHITE)
	_poly(center, radius, [Vector2(0.76, -0.44), Vector2(0.36, -0.22), Vector2(0.58, 0.00)], WHITE)
	draw_circle(center, radius * 0.45, INK)
	draw_circle(center + Vector2(-radius * 0.18, -radius * 0.06), radius * 0.08, WHITE)
	draw_circle(center + Vector2(radius * 0.18, -radius * 0.06), radius * 0.08, WHITE)
	_line(center, Vector2(-0.26, 0.26), Vector2(0.26, 0.26), radius, WHITE, 0.08)

func _line(center: Vector2, a: Vector2, b: Vector2, radius: float, color: Color, width_ratio: float) -> void:
	draw_line(center + a * radius, center + b * radius, color, max(1.0, radius * width_ratio), true)

func _poly(center: Vector2, radius: float, points: Array[Vector2], color: Color) -> void:
	var packed = PackedVector2Array()
	for point in points:
		packed.append(center + point * radius)
	draw_polygon(packed, PackedColorArray([INK]))
	var inner = PackedVector2Array()
	for point in points:
		inner.append((center + point * radius).lerp(center, 0.08))
	draw_polygon(inner, PackedColorArray([color]))
