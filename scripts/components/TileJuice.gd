extends Control

signal picked(index: int)
signal info_hovered(tile_data: Dictionary, anchor_global_pos: Vector2)
signal info_hidden

const TileCardFrame = preload("res://scripts/components/TileCardFrame.gd")
const GeneratedTileIcon = preload("res://scripts/components/GeneratedTileIcon.gd")
const VectorTileIcon = preload("res://scripts/components/VectorTileIcon.gd")

var tile_index = 0
var tile_id = "T000"
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
var weak = false
var durability = 0
var max_durability = 0
var tile_buffs: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(index: int, data: Dictionary) -> void:
	tile_data = data.duplicate(true)
	tile_index = index
	tile_id = str(data.get("id", "T000"))
	tile_name = str(data.get("tile_name", data.get("name", "集市")))
	tile_kind = str(data.get("kind", "market"))
	reward = int(data.get("reward", 3))
	icon = int(data.get("tile_icon", data.get("icon", 0)))
	base_color = data.get("color", Color(0.95, 0.36, 0.43))
	accent_color = data.get("accent", Color(1.0, 0.86, 0.22))
	weak = bool(data.get("weak", false)) or bool(data.get("runtime_flags", {}).get("temporarily_destroyed", false))
	durability = int(data.get("durability", 0))
	max_durability = int(data.get("maxDurability", 0))
	tile_buffs = data.get("tileBuffs", []).duplicate(true)
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
	if not GeneratedTileIcon.draw(self, tile_id, r.grow(-2.0)):
		TileCardFrame.draw_icon_card(self, r.grow(-3.0), base_color, radius)
		_draw_tile_icon()
	if max_durability > 0:
		_draw_durability_badge(r)
	if not tile_buffs.is_empty():
		_draw_tile_buff_icons(r)
	if weak:
		_draw_weak_overlay(r)
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

func _draw_durability_badge(rect: Rect2) -> void:
	var badge_radius = min(size.x, size.y) * 0.17
	var center = rect.position + Vector2(rect.size.x - badge_radius * 0.95, badge_radius * 1.08)
	draw_circle(center + Vector2(2, 3), badge_radius, Color(0, 0, 0, 0.38))
	draw_circle(center, badge_radius, Color(0.05, 0.08, 0.12, 0.96))
	draw_circle(center, badge_radius * 0.78, Color(0.30, 0.62, 1.0, 0.96) if durability > 0 else Color(0.34, 0.35, 0.39, 0.96))
	var font = ThemeDB.fallback_font
	var label = "%d" % durability
	draw_string(font, center + Vector2(-badge_radius * 0.38, badge_radius * 0.34), label, HORIZONTAL_ALIGNMENT_CENTER, badge_radius * 0.76, int(badge_radius * 0.86), Color.WHITE)

func _draw_weak_overlay(rect: Rect2) -> void:
	draw_rect(rect.grow(-6.0), Color(0.03, 0.04, 0.06, 0.52), true)
	TileCardFrame.draw_rect_outline(self, rect.grow(-7.0), Color(0.55, 0.66, 0.78, 0.80), max(2.0, size.x * 0.035))

func _draw_tile_buff_icons(rect: Rect2) -> void:
	var icon_size = clamp(size.x * 0.22, 15.0, 22.0)
	var gap = icon_size * 0.16
	var visible_buffs: Array = []
	for buff in tile_buffs:
		if typeof(buff) == TYPE_DICTIONARY:
			visible_buffs.append(buff)
	var total_width = visible_buffs.size() * icon_size + max(0, visible_buffs.size() - 1) * gap
	var start_x = rect.position.x + rect.size.x * 0.5 - total_width * 0.5
	var y = rect.end.y - icon_size * 0.18
	for i in range(visible_buffs.size()):
		var buff: Dictionary = visible_buffs[i]
		var buff_rect = Rect2(Vector2(start_x + i * (icon_size + gap), y), Vector2(icon_size, icon_size))
		_draw_single_tile_buff(buff_rect, str(buff.get("icon", buff.get("id", ""))))

func _draw_single_tile_buff(rect: Rect2, icon_key: String) -> void:
	var center = rect.get_center()
	var radius = rect.size.x * 0.5
	draw_circle(center + Vector2(1.5, 2.0), radius, Color(0, 0, 0, 0.42))
	draw_circle(center, radius, Color(0.02, 0.03, 0.04, 0.96))
	match icon_key:
		"converge":
			draw_circle(center, radius * 0.78, Color(0.10, 0.74, 0.78, 0.98))
			draw_arc(center, radius * 0.46, PI * 0.08, PI * 1.50, 18, Color.WHITE, max(1.4, radius * 0.16), true)
			var tip = center + Vector2(radius * 0.42, -radius * 0.08)
			draw_polygon(PackedVector2Array([tip, tip + Vector2(-radius * 0.24, -radius * 0.15), tip + Vector2(-radius * 0.08, radius * 0.20)]), PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]))
		_:
			draw_circle(center, radius * 0.78, Color(0.50, 0.54, 0.62, 0.98))
			draw_circle(center, radius * 0.24, Color.WHITE)
