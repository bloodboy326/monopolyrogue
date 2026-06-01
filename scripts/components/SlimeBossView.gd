extends Control

const INK = Color(0.02, 0.02, 0.025, 1.0)
const SLIME = Color(0.24, 0.78, 0.34, 1.0)
const SLIME_DARK = Color(0.12, 0.44, 0.22, 1.0)
const WORM = Color(0.64, 0.38, 0.20, 1.0)
const SHELL = Color(0.33, 0.56, 0.78, 1.0)
const LOUSE = Color(0.72, 0.22, 0.28, 1.0)
const HIT = Color(0.80, 0.92, 0.34, 1.0)
const DEAD = Color(0.34, 0.38, 0.36, 1.0)
const WHITE = Color(0.96, 0.98, 0.90, 1.0)
const SPRITE_DRAW_SCALE = {
	"goblin": 1.14,
	"slime": 1.22,
	"skeleton_soldier": 1.14,
	"murloc": 1.14,
	"skeleton_archer": 1.14,
	"guard_a": 1.14,
	"guard_b": 1.14,
	"frost_giant": 1.18,
	"baby_dragon": 1.15,
	"skeleton_king": 1.16,
	"werewolf": 1.16,
	"headless_knight": 1.16,
	"void_eye": 1.10,
	"medusa": 1.12,
	"dice_demon": 1.12
}

var state := "normal"
var art_key := "slime"
var wobble := 0.0
var sprite_textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func set_state(value: String) -> void:
	state = value
	queue_redraw()

func set_art_key(value: String) -> void:
	art_key = value
	state = "normal"
	scale = Vector2.ONE
	_load_sprite_textures()
	queue_redraw()

func flash_hit() -> void:
	set_state("hit")
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.10, 0.92), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	tween.finished.connect(func() -> void:
		if state == "hit":
			set_state("normal")
	)

func play_attack() -> void:
	set_state("attack")
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.12, 1.06), 0.10)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	tween.finished.connect(func() -> void:
		if state == "attack":
			set_state("normal")
	)

func play_death() -> void:
	set_state("dead")
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.18, 0.58), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _process(delta: float) -> void:
	wobble += delta
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	_ellipse(Rect2(Vector2(size.x * 0.15, size.y * 0.76), Vector2(size.x * 0.70, size.y * 0.16)), Color(0, 0, 0, 0.22))
	var texture = sprite_textures.get(_sprite_state_key(), null)
	if texture != null:
		_draw_sprite_texture(texture)
		return
	match state:
		"dead":
			_draw_dead(rect)
		_:
			if state == "attack":
				_draw_attack(rect)
			elif state == "hit":
				_draw_hit(rect)
			else:
				_draw_normal(rect)

func _draw_normal(rect: Rect2) -> void:
	var bob = sin(wobble * 3.2) * rect.size.y * 0.025
	_draw_blob(rect, SLIME, bob)
	_draw_face(rect, false, bob)
	_draw_gloss(rect, bob)

func _draw_attack(rect: Rect2) -> void:
	var bob = -rect.size.y * 0.02
	_draw_blob(rect, SLIME.lightened(0.05), bob)
	_poly(rect, [Vector2(0.72, 0.38), Vector2(0.92, 0.30), Vector2(0.78, 0.52)], Color(0.70, 1.0, 0.35, 1.0))
	_draw_face(rect, true, bob)
	_line(rect, Vector2(0.17, 0.35), Vector2(0.39, 0.29), INK, 0.028)
	_line(rect, Vector2(0.83, 0.35), Vector2(0.61, 0.29), INK, 0.028)

func _draw_hit(rect: Rect2) -> void:
	_draw_blob(rect, HIT, rect.size.y * 0.02)
	_draw_face(rect, false, rect.size.y * 0.02)
	_line(rect, Vector2(0.22, 0.24), Vector2(0.34, 0.15), Color(1.0, 0.95, 0.24, 1.0), 0.030)
	_line(rect, Vector2(0.76, 0.20), Vector2(0.88, 0.10), Color(1.0, 0.95, 0.24, 1.0), 0.030)

func _draw_dead(rect: Rect2) -> void:
	var puddle = Rect2(Vector2(rect.size.x * 0.18, rect.size.y * 0.52), Vector2(rect.size.x * 0.64, rect.size.y * 0.28))
	_ellipse(puddle.grow(8), INK)
	_ellipse(puddle, DEAD)
	_line(rect, Vector2(0.40, 0.60), Vector2(0.48, 0.68), INK, 0.026)
	_line(rect, Vector2(0.48, 0.60), Vector2(0.40, 0.68), INK, 0.026)
	_line(rect, Vector2(0.57, 0.60), Vector2(0.65, 0.68), INK, 0.026)
	_line(rect, Vector2(0.65, 0.60), Vector2(0.57, 0.68), INK, 0.026)

func _load_sprite_textures() -> void:
	sprite_textures.clear()
	var asset_key = _sprite_asset_key()
	for key in ["idle", "attack", "hit", "death"]:
		var path = "res://assets/generated/enemies/%s_%s.png" % [asset_key, key]
		if ResourceLoader.exists(path):
			sprite_textures[key] = load(path)

func _sprite_asset_key() -> String:
	return art_key

func _sprite_state_key() -> String:
	match state:
		"attack":
			return "attack"
		"hit":
			return "hit"
		"dead":
			return "death"
		_:
			return "idle"

func _draw_sprite_texture(texture: Texture2D) -> void:
	var tex_size = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_factor = min(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size = tex_size * scale_factor * float(SPRITE_DRAW_SCALE.get(art_key, 1.0))
	if _sprite_state_key() == "idle":
		var breath = 1.0 + sin(wobble * 2.4) * 0.035
		draw_size *= breath
	var draw_rect = Rect2((size - draw_size) * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect, false)

func _draw_blob(rect: Rect2, fill: Color, bob: float) -> void:
	var body = Rect2(Vector2(rect.size.x * 0.18, rect.size.y * 0.20 + bob), Vector2(rect.size.x * 0.64, rect.size.y * 0.56))
	_ellipse(body.grow(8), INK)
	_ellipse(body, fill)
	draw_circle(Vector2(rect.size.x * 0.38, rect.size.y * 0.25 + bob), rect.size.x * 0.16, INK)
	draw_circle(Vector2(rect.size.x * 0.38, rect.size.y * 0.25 + bob), rect.size.x * 0.12, fill)
	draw_circle(Vector2(rect.size.x * 0.62, rect.size.y * 0.25 + bob), rect.size.x * 0.14, INK)
	draw_circle(Vector2(rect.size.x * 0.62, rect.size.y * 0.25 + bob), rect.size.x * 0.105, fill)

func _draw_face(rect: Rect2, angry: bool, bob: float) -> void:
	var left = Vector2(rect.size.x * 0.42, rect.size.y * 0.47 + bob)
	var right = Vector2(rect.size.x * 0.60, rect.size.y * 0.47 + bob)
	draw_circle(left, rect.size.x * 0.035, INK)
	draw_circle(right, rect.size.x * 0.035, INK)
	if angry:
		_line(rect, Vector2(0.37, 0.39), Vector2(0.47, 0.44), INK, 0.020)
		_line(rect, Vector2(0.65, 0.39), Vector2(0.55, 0.44), INK, 0.020)
		_line(rect, Vector2(0.46, 0.60), Vector2(0.60, 0.60), INK, 0.026)
	else:
		_line(rect, Vector2(0.46, 0.58), Vector2(0.56, 0.62), INK, 0.020)
		_line(rect, Vector2(0.56, 0.62), Vector2(0.64, 0.56), INK, 0.020)

func _draw_gloss(rect: Rect2, bob: float) -> void:
	draw_circle(Vector2(rect.size.x * 0.36, rect.size.y * 0.38 + bob), rect.size.x * 0.05, WHITE)
	draw_circle(Vector2(rect.size.x * 0.30, rect.size.y * 0.50 + bob), rect.size.x * 0.025, Color(1, 1, 1, 0.65))

func _line(rect: Rect2, a: Vector2, b: Vector2, color: Color, width_ratio: float) -> void:
	draw_line(_pt(rect, a), _pt(rect, b), color, max(1.0, rect.size.x * width_ratio), true)

func _poly(rect: Rect2, points: Array, color: Color) -> void:
	var packed = PackedVector2Array()
	for point in points:
		var point_vec: Vector2 = point
		packed.append(_pt(rect, point_vec))
	draw_polygon(packed, PackedColorArray([INK]))
	var inner = PackedVector2Array()
	for point in points:
		var inner_point_vec: Vector2 = point
		inner.append(_pt(rect, inner_point_vec).lerp(rect.get_center(), 0.08))
	draw_polygon(inner, PackedColorArray([color]))

func _ellipse(rect: Rect2, color: Color) -> void:
	draw_set_transform(rect.get_center(), 0.0, rect.size * 0.5)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _pt(rect: Rect2, point: Vector2) -> Vector2:
	return rect.position + Vector2(rect.size.x * point.x, rect.size.y * point.y)
