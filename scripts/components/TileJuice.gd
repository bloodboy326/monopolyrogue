extends Control

signal picked(index: int)

const TILE_SHADER = preload("res://shaders/tile_glow.gdshader")
const TileCardFrame = preload("res://scripts/components/TileCardFrame.gd")
const ICON_ROOT = "res://assets/icons/tiles/"
const FALLBACK_ICON_PATH = "res://assets/icons/tiles/0.png"

var tile_index = 0
var tile_name = "集市"
var reward = 3
var icon = 0
var icon_texture: Texture2D
var base_color = Color(0.04, 0.74, 0.82)
var accent_color = Color(1.0, 0.86, 0.16)
var glow = 0.0
var hover = false
var insert_hint = false
var delete_hint = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shader_material = ShaderMaterial.new()
	shader_material.shader = TILE_SHADER
	shader_material.set_shader_parameter("glow_color", Color(0.0, 1.0, 0.92, 1.0))
	material = shader_material
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(index: int, data: Dictionary) -> void:
	tile_index = index
	tile_name = str(data.get("tile_name", data.get("name", "集市")))
	reward = int(data.get("reward", 3))
	icon = int(data.get("tile_icon", data.get("icon", 0)))
	base_color = data.get("color", Color(0.04, 0.74, 0.82))
	accent_color = data.get("accent", Color(1.0, 0.86, 0.16))
	icon_texture = _load_icon_texture(icon)
	queue_redraw()

func set_insert_hint(value: bool) -> void:
	insert_hint = value
	if value:
		set_glow(0.45)
	else:
		set_glow(0.0)
	queue_redraw()

func set_delete_hint(value: bool) -> void:
	delete_hint = value
	if value:
		set_glow(0.36)
	else:
		set_glow(0.0)
	queue_redraw()

func set_glow(value: float) -> void:
	glow = value
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("glow", glow)
	queue_redraw()

func play_spawn() -> void:
	scale = Vector2(0.15, 0.15)
	rotation = randf_range(-0.08, 0.08)
	set_glow(0.75)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_glow, 0.75, 0.0, 0.52)

func play_step(final_hit: bool = false) -> void:
	var target_scale = Vector2(1.2, 1.2) if final_hit else Vector2(1.09, 1.09)
	var peak_glow = 1.0 if final_hit else 0.65
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 0.88), 0.06).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", target_scale, 0.14).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_delay(0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_glow, peak_glow, 0.0, 0.48)

func play_reward() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 8.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y, 0.18).set_delay(0.08).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_glow, 1.0, 0.0, 0.5)

func _on_mouse_entered() -> void:
	hover = true
	if not insert_hint and not delete_hint:
		set_glow(0.28)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	hover = false
	if not insert_hint and not delete_hint:
		set_glow(0.0)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		picked.emit(tile_index)

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var radius = min(size.x, size.y) * 0.12
	var shadow = Rect2(Vector2(0, size.y * 0.07), size)
	draw_rect(shadow.grow(-2.0), Color(0.0, 0.0, 0.0, 0.26), true)
	TileCardFrame.draw_icon_card(self, r.grow(-3.0), base_color, radius)
	_draw_tile_icon()
	var outline = Color(0.0, 0.92, 1.0, 0.0)
	if hover or insert_hint or delete_hint:
		outline = Color(1.0, 0.9, 0.18, 0.82) if insert_hint else Color(0.0, 0.95, 1.0, 0.64)
		if delete_hint:
			outline = Color(1.0, 0.18, 0.26, 0.76)
		TileCardFrame.draw_rect_outline(self, r.grow(-4.0), outline, max(2.0, size.x * 0.035))

func _draw_tile_icon() -> void:
	var icon_side = min(size.x, size.y) * 0.68
	var icon_rect = Rect2(size * 0.5 - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
	if icon_texture != null:
		draw_texture_rect(icon_texture, icon_rect, false)
	else:
		_draw_fallback_icon(icon_rect)

func _draw_fallback_icon(rect: Rect2) -> void:
	var center = rect.get_center()
	var radius = rect.size.x * 0.33
	draw_circle(center, radius, Color(1.0, 0.84, 0.16, 1.0))
	draw_circle(center, radius * 0.55, Color(0.1, 0.06, 0.18, 1.0))

func _load_icon_texture(icon_id: int) -> Texture2D:
	var icon_path = "%s%d.png" % [ICON_ROOT, icon_id]
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	if ResourceLoader.exists(FALLBACK_ICON_PATH):
		return load(FALLBACK_ICON_PATH)
	return null
