extends Control

const INK = Color(0.02, 0.01, 0.01, 1.0)
const TRACK = Color(0.12, 0.05, 0.04, 1.0)
const RED = Color(0.86, 0.08, 0.08, 1.0)
const RED_DARK = Color(0.42, 0.02, 0.02, 1.0)
const GOLD = Color(0.86, 0.58, 0.12, 1.0)
const WHITE = Color(0.96, 0.96, 0.92, 1.0)

var current_value := 1
var max_value := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_values(current: int, maximum: int) -> void:
	current_value = max(0, current)
	max_value = max(1, maximum)
	queue_redraw()

func _draw() -> void:
	var bar_height = clamp(size.y * 0.72, 12.0, 18.0)
	var bar_rect = Rect2(Vector2(0.0, (size.y - bar_height) * 0.5), Vector2(size.x, bar_height))
	var fill_ratio = clamp(float(current_value) / float(max_value), 0.0, 1.0)
	draw_rect(Rect2(bar_rect.position + Vector2(2.0, 3.0), bar_rect.size).grow(3.0), Color(0, 0, 0, 0.42), true)
	draw_rect(bar_rect.grow(2.0), INK, true)
	draw_rect(bar_rect.grow(0.5), GOLD, true)
	draw_rect(bar_rect, TRACK, true)
	if fill_ratio > 0.0:
		var fill_rect = Rect2(bar_rect.position, Vector2(max(2.0, bar_rect.size.x * fill_ratio), bar_rect.size.y))
		draw_rect(fill_rect, RED_DARK, true)
		draw_rect(fill_rect.grow(-1.0), RED, true)
		draw_rect(Rect2(fill_rect.position + Vector2(1.0, 1.0), Vector2(max(0.0, fill_rect.size.x - 2.0), 2.0)), Color(1.0, 0.48, 0.38, 0.78), true)
	draw_line(bar_rect.position + Vector2(0, bar_rect.size.y + 1.0), bar_rect.end + Vector2(0, 1.0), INK, 2.0)
	var font = ThemeDB.fallback_font
	var text = "%d/%d" % [current_value, max_value]
	var font_size = 13
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos = Vector2((size.x - text_size.x) * 0.5, bar_rect.position.y + (bar_rect.size.y + text_size.y) * 0.5 - 2.0)
	draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.95))
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, WHITE)
