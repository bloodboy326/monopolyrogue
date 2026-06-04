extends Control

signal picked

var price := 75
var affordable := true
var used := false
var hover := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		hover = true
		_animate_hover(Vector2(1.045, 1.045))
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hover = false
		_animate_hover(Vector2.ONE)
		queue_redraw()
	)

func setup(item_price: int, can_afford: bool, already_used: bool = false) -> void:
	price = item_price
	used = already_used
	affordable = can_afford and not used
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if not affordable:
			return
		picked.emit()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var center = Vector2(size.x * 0.5, size.y * 0.40)
	var radius = min(size.x, size.y) * 0.30
	draw_circle(center + Vector2(6, 8), radius * 1.04, Color(0, 0, 0, 0.34))
	draw_circle(center, radius, Color(0.28, 0.16, 0.04))
	draw_circle(center, radius * 0.90, Color(1.0, 0.76, 0.20))
	draw_arc(center, radius * 0.78, 0.0, TAU, 48, Color(0.42, 0.22, 0.04), 4.0, true)
	_draw_broken_tile(center, radius)
	if hover:
		draw_arc(center, radius * 1.08, 0.0, TAU, 56, Color.WHITE, 4.0, true)
	var font = ThemeDB.fallback_font
	var color = Color(0.98, 0.86, 0.28) if affordable else Color(0.96, 0.25, 0.32)
	draw_string(font, Vector2(0, size.y - 34), "删除地块", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color.WHITE)
	var price_text = "本店已用" if used else "%d 金币" % price
	draw_string(font, Vector2(0, size.y - 10), price_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, color)

func _draw_broken_tile(center: Vector2, radius: float) -> void:
	var tile_rect = Rect2(center - Vector2(radius * 0.42, radius * 0.42), Vector2(radius * 0.84, radius * 0.84))
	draw_rect(Rect2(tile_rect.position + Vector2(4, 5), tile_rect.size), Color(0, 0, 0, 0.32), true)
	draw_rect(tile_rect, Color(0.12, 0.10, 0.08), true)
	draw_rect(tile_rect.grow(-5), Color(0.95, 0.90, 0.72), true)
	var crack = PackedVector2Array([
		tile_rect.position + Vector2(tile_rect.size.x * 0.58, 3),
		tile_rect.position + Vector2(tile_rect.size.x * 0.42, tile_rect.size.y * 0.44),
		tile_rect.position + Vector2(tile_rect.size.x * 0.62, tile_rect.size.y * 0.58),
		tile_rect.position + Vector2(tile_rect.size.x * 0.36, tile_rect.size.y - 3)
	])
	for i in range(crack.size() - 1):
		draw_line(crack[i], crack[i + 1], Color(0.68, 0.10, 0.08), 5.0, true)
	var shard_a = PackedVector2Array([tile_rect.position + Vector2(4, 4), tile_rect.position + Vector2(20, 8), tile_rect.position + Vector2(8, 25)])
	var shard_b = PackedVector2Array([tile_rect.end - Vector2(6, 6), tile_rect.end - Vector2(24, 8), tile_rect.end - Vector2(10, 28)])
	draw_polygon(shard_a, PackedColorArray([Color(0.80, 0.18, 0.12), Color(0.80, 0.18, 0.12), Color(0.80, 0.18, 0.12)]))
	draw_polygon(shard_b, PackedColorArray([Color(0.80, 0.18, 0.12), Color(0.80, 0.18, 0.12), Color(0.80, 0.18, 0.12)]))

func _animate_hover(target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
