extends Node

const OUT_DIR = "res://assets/icons/tiles"
const SIZE = 64

func _ready() -> void:
	var absolute_dir = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	_save_icon("0.png", _draw_fallback())
	_save_icon("1.png", _draw_market())
	_save_icon("2.png", _draw_factory())
	_save_icon("3.png", _draw_haunted_house())
	print("ICONS_OK")

func _new_image() -> Image:
	var image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image

func _save_icon(file_name: String, image: Image) -> void:
	var path = "%s/%s" % [OUT_DIR, file_name]
	var error = image.save_png(path)
	if error != OK:
		push_error("Failed to save icon: %s" % path)

func _draw_fallback() -> Image:
	var image = _new_image()
	_rect(image, 20, 12, 44, 52, Color(1.0, 0.82, 0.12, 1.0))
	_rect(image, 26, 18, 38, 46, Color(0.08, 0.04, 0.14, 1.0))
	_rect(image, 30, 22, 34, 42, Color(1.0, 0.82, 0.12, 1.0))
	return image

func _draw_market() -> Image:
	var image = _new_image()
	_rect(image, 15, 28, 49, 50, Color(0.10, 0.06, 0.18, 1.0))
	_rect(image, 18, 31, 46, 47, Color(0.0, 0.78, 0.80, 1.0))
	_rect(image, 12, 18, 52, 30, Color(0.10, 0.06, 0.18, 1.0))
	_rect(image, 15, 16, 49, 21, Color(1.0, 0.82, 0.12, 1.0))
	_rect(image, 16, 21, 24, 32, Color(1.0, 0.16, 0.48, 1.0))
	_rect(image, 24, 21, 32, 32, Color(1.0, 0.96, 0.70, 1.0))
	_rect(image, 32, 21, 40, 32, Color(1.0, 0.16, 0.48, 1.0))
	_rect(image, 40, 21, 48, 32, Color(1.0, 0.96, 0.70, 1.0))
	_rect(image, 23, 38, 29, 44, Color(1.0, 0.78, 0.08, 1.0))
	_rect(image, 35, 38, 41, 44, Color(1.0, 0.78, 0.08, 1.0))
	_rect(image, 28, 47, 36, 50, Color(0.0, 0.95, 0.88, 1.0))
	return image

func _draw_factory() -> Image:
	var image = _new_image()
	_rect(image, 12, 32, 52, 52, Color(0.08, 0.07, 0.12, 1.0))
	_rect(image, 16, 35, 48, 49, Color(0.40, 0.50, 0.64, 1.0))
	_poly(image, [Vector2i(12, 32), Vector2i(22, 22), Vector2i(29, 32), Vector2i(38, 23), Vector2i(52, 32)], Color(0.95, 0.32, 0.12, 1.0))
	_rect(image, 41, 12, 50, 34, Color(0.08, 0.07, 0.12, 1.0))
	_rect(image, 43, 15, 48, 34, Color(0.53, 0.58, 0.68, 1.0))
	_rect(image, 19, 39, 25, 45, Color(0.05, 0.82, 1.0, 1.0))
	_rect(image, 30, 39, 36, 45, Color(0.05, 0.82, 1.0, 1.0))
	_rect(image, 41, 39, 47, 45, Color(0.05, 0.82, 1.0, 1.0))
	_rect(image, 25, 50, 39, 54, Color(1.0, 0.74, 0.10, 1.0))
	_rect(image, 44, 7, 48, 10, Color(0.75, 0.85, 0.95, 0.85))
	_rect(image, 39, 4, 44, 7, Color(0.75, 0.85, 0.95, 0.65))
	return image

func _draw_haunted_house() -> Image:
	var image = _new_image()
	_rect(image, 17, 29, 47, 53, Color(0.07, 0.04, 0.13, 1.0))
	_poly(image, [Vector2i(13, 30), Vector2i(24, 16), Vector2i(32, 25), Vector2i(40, 15), Vector2i(51, 30)], Color(0.43, 0.12, 0.67, 1.0))
	_rect(image, 21, 33, 43, 51, Color(0.18, 0.08, 0.30, 1.0))
	_rect(image, 27, 42, 37, 53, Color(0.02, 0.01, 0.05, 1.0))
	_rect(image, 22, 35, 28, 41, Color(0.35, 1.0, 0.62, 1.0))
	_rect(image, 38, 35, 44, 41, Color(0.35, 1.0, 0.62, 1.0))
	_rect(image, 28, 9, 32, 19, Color(0.07, 0.04, 0.13, 1.0))
	_rect(image, 25, 9, 35, 12, Color(0.43, 0.12, 0.67, 1.0))
	_rect(image, 45, 13, 52, 16, Color(0.75, 1.0, 0.78, 0.75))
	_rect(image, 50, 16, 54, 19, Color(0.75, 1.0, 0.78, 0.55))
	return image

func _rect(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(max(0, y0), min(SIZE, y1)):
		for x in range(max(0, x0), min(SIZE, x1)):
			image.set_pixel(x, y, color)

func _poly(image: Image, points: Array, color: Color) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			if _point_in_poly(Vector2(x + 0.5, y + 0.5), points):
				image.set_pixel(x, y, color)

func _point_in_poly(point: Vector2, points: Array) -> bool:
	var inside = false
	var j = points.size() - 1
	for i in range(points.size()):
		var pi: Vector2 = points[i]
		var pj: Vector2 = points[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x:
			inside = not inside
		j = i
	return inside
