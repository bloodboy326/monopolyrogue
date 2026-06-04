extends Control

const INK = Color(0.02, 0.02, 0.025, 0.92)
const AIM = Color(1.0, 0.18, 0.24, 0.96)
const AIM_LIGHT = Color(1.0, 0.92, 0.32, 0.90)

var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)

func set_active(value: bool) -> void:
	visible = value
	set_process(value)
	if value:
		time = 0.0
		scale = Vector2.ONE
	queue_redraw()

func _process(delta: float) -> void:
	time += delta
	var pulse = 1.0 + sin(time * 5.2) * 0.075
	scale = Vector2(pulse, pulse)
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	var radius = min(size.x, size.y) * 0.34
	var outer = radius + 9.0 + sin(time * 5.2) * 3.0
	draw_arc(center, outer + 4.0, 0.0, TAU, 72, INK, 7.0, true)
	draw_arc(center, outer, 0.0, TAU, 72, AIM, 5.0, true)
	draw_arc(center, radius * 0.58, 0.0, TAU, 56, AIM_LIGHT, 3.0, true)
	var arm = radius * 0.95
	var gap = radius * 0.32
	_draw_cross_line(center + Vector2(-arm, 0), center + Vector2(-gap, 0))
	_draw_cross_line(center + Vector2(gap, 0), center + Vector2(arm, 0))
	_draw_cross_line(center + Vector2(0, -arm), center + Vector2(0, -gap))
	_draw_cross_line(center + Vector2(0, gap), center + Vector2(0, arm))
	draw_circle(center, max(3.0, radius * 0.10), INK)
	draw_circle(center, max(2.0, radius * 0.065), AIM_LIGHT)

func _draw_cross_line(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, INK, 7.0, true)
	draw_line(a, b, AIM, 4.0, true)
