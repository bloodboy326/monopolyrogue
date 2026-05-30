extends Control

signal picked(index: int)
signal info_hovered(tile_data: Dictionary, anchor_global_pos: Vector2)
signal info_hidden

const TileCardFrame = preload("res://scripts/components/TileCardFrame.gd")
const VectorTileIcon = preload("res://scripts/components/VectorTileIcon.gd")

var tile_index = 0
var tile_name = "集市"
var tile_kind = "market"
var reward = 3
var icon = 0
var base_color = Color(0.95, 0.36, 0.43)
var accent_color = Color(1.0, 0.86, 0.22)
var glow = 0.0
var hover = false
var insert_hint = false
var delete_hint = false
var tile_data: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(index: int, data: Dictionary) -> void:
	tile_data = data.duplicate(true)
	tile_index = index
	tile_name = str(data.get("tile_name", data.get("name", "集市")))
	tile_kind = str(data.get("kind", "market"))
	reward = int(data.get("reward", 3))
	icon = int(data.get("tile_icon", data.get("icon", 0)))
	base_color = data.get("color", Color(0.95, 0.36, 0.43))
	accent_color = data.get("accent", Color(1.0, 0.86, 0.22))
	queue_redraw()

func set_insert_hint(value: bool) -> void:
	insert_hint = value
	set_glow(0.45 if value else 0.0)

func set_delete_hint(value: bool) -> void:
	delete_hint = value
	set_glow(0.36 if value else 0.0)

func set_glow(value: float) -> void:
	glow = value
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
	info_hovered.emit(tile_data, get_global_mouse_position())
	if not insert_hint and not delete_hint:
		set_glow(0.28)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	hover = false
	info_hidden.emit()
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
	var radius = min(size.x, size.y) * 0.14
	TileCardFrame.draw_icon_card(self, r.grow(-3.0), base_color, radius)
	_draw_tile_icon()
	if glow > 0.0:
		var pulse_color = Color(1.0, 0.94, 0.28, 0.65 * glow)
		if delete_hint:
			pulse_color = Color(1.0, 0.18, 0.28, 0.65 * glow)
		elif not insert_hint:
			pulse_color = Color(1.0, 1.0, 1.0, 0.50 * glow)
		TileCardFrame.draw_rect_outline(self, r.grow(-4.0 - glow * 4.0), pulse_color, max(3.0, size.x * 0.04))
	if hover or insert_hint or delete_hint:
		var outline = Color(1.0, 0.90, 0.18, 1.0) if insert_hint else Color(1.0, 1.0, 1.0, 0.92)
		if delete_hint:
			outline = Color(1.0, 0.18, 0.26, 0.95)
		TileCardFrame.draw_rect_outline(self, r.grow(-5.0), outline, max(3.0, size.x * 0.045))

func _draw_tile_icon() -> void:
	var icon_side = min(size.x, size.y) * 0.84
	var icon_rect = Rect2(size * 0.5 - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
	VectorTileIcon.draw_icon(self, tile_kind, icon, icon_rect, base_color, accent_color)
