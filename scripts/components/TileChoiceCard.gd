extends Control

signal picked(index: int)

const ICON_ROOT = "res://assets/icons/tiles/"
const TileCardFrame = preload("res://scripts/components/TileCardFrame.gd")
const FALLBACK_ICON_PATH = "res://assets/icons/tiles/0.png"

var tile_index = 0
var tile_name = ""
var tile_icon = 0
var tile_rare = "普通"
var tile_describe = ""
var icon_texture: Texture2D
var hover = false
var base_color = Color(0.06, 0.26, 0.24, 1.0)

var rare_colors = {
	"普通": Color(0.45, 0.95, 0.86, 1.0),
	"稀有": Color(1.0, 0.82, 0.22, 1.0),
	"非凡": Color(0.40, 0.72, 1.0, 1.0),
	"传说": Color(1.0, 0.42, 0.10, 1.0),
	"诅咒": Color(0.88, 0.18, 0.78, 1.0)
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		hover = true
		_animate_hover(Vector2(1.035, 1.035))
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hover = false
		_animate_hover(Vector2.ONE)
		queue_redraw()
	)

func setup(index: int, data: Dictionary) -> void:
	tile_index = index
	tile_name = str(data.get("tile_name", data.get("name", "")))
	tile_icon = int(data.get("tile_icon", data.get("icon", 0)))
	tile_rare = str(data.get("tile_rare", "普通"))
	tile_describe = str(data.get("tile_describe", ""))
	base_color = data.get("color", base_color)
	icon_texture = _load_icon_texture(tile_icon)
	queue_redraw()

func play_spawn() -> void:
	scale = Vector2(0.18, 0.18)
	rotation = randf_range(-0.04, 0.04)
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		picked.emit(tile_index)

func _draw() -> void:
	var rare_color: Color = rare_colors.get(tile_rare, rare_colors["普通"])
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(Vector2(4, 5), size), Color(0.0, 0.0, 0.0, 0.38), true)
	TileCardFrame.draw_choice_frame(self, rect, rare_color)

	var font = get_theme_default_font()
	draw_string(font, Vector2(0, 28), tile_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 19, Color.WHITE)

	var tile_side = min(size.x * 0.48, size.y * 0.30)
	var tile_rect = Rect2(Vector2(size.x * 0.5 - tile_side * 0.5, 42), Vector2(tile_side, tile_side))
	TileCardFrame.draw_icon_card(self, tile_rect, base_color, max(6.0, tile_side * 0.08))
	var icon_side = tile_side * 0.72
	var icon_rect = Rect2(tile_rect.get_center() - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
	if icon_texture != null:
		draw_texture_rect(icon_texture, icon_rect, false)
	else:
		draw_circle(icon_rect.get_center(), icon_side * 0.34, rare_color)

	draw_string(font, Vector2(0, tile_rect.end.y + 23), tile_rare, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, rare_color)
	var line_y = tile_rect.end.y + 33
	draw_line(Vector2(18, line_y), Vector2(size.x - 18, line_y), rare_color.darkened(0.55), 2.0)
	_draw_description(font, Rect2(Vector2(16, line_y + 14), Vector2(size.x - 32, size.y - line_y - 22)))

	if hover:
		TileCardFrame.draw_rect_outline(self, rect.grow(-5.0), rare_color, 3.0)

func _draw_description(font: Font, rect: Rect2) -> void:
	var lines = tile_describe.split("\n")
	var y = rect.position.y + 17
	for line in lines:
		draw_string(font, Vector2(rect.position.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 14, Color(0.88, 1.0, 0.95, 1.0))
		y += 18

func _load_icon_texture(icon_id: int) -> Texture2D:
	var icon_path = "%s%d.png" % [ICON_ROOT, icon_id]
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	if ResourceLoader.exists(FALLBACK_ICON_PATH):
		return load(FALLBACK_ICON_PATH)
	return null

func _animate_hover(target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
