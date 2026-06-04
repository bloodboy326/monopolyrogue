extends Control

signal picked(index: int)
signal info_hovered(relic_data: Dictionary, anchor_global_pos: Vector2)
signal info_hidden

const GeneratedRelicIcon = preload("res://scripts/components/GeneratedRelicIcon.gd")

var item_index := 0
var relic_data: Dictionary = {}
var price := 0
var affordable := true
var purchased := false
var hover := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		hover = true
		info_hovered.emit(relic_data, get_global_mouse_position())
		_animate_hover(Vector2(1.06, 1.06))
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hover = false
		info_hidden.emit()
		_animate_hover(Vector2.ONE)
		queue_redraw()
	)

func setup(index: int, data: Dictionary, item_price: int, can_afford: bool, is_purchased: bool = false) -> void:
	item_index = index
	relic_data = data.duplicate(true)
	price = item_price
	affordable = can_afford
	purchased = is_purchased
	queue_redraw()

func set_purchased(value: bool) -> void:
	purchased = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if purchased:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		picked.emit(item_index)

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var font = ThemeDB.fallback_font
	var icon_side = min(size.x * 0.74, size.y * 0.60)
	var icon_rect = Rect2(Vector2(size.x * 0.5 - icon_side * 0.5, 4), Vector2(icon_side, icon_side))
	var tint = Color(1, 1, 1, 0.46) if purchased else Color.WHITE
	draw_circle(icon_rect.get_center() + Vector2(4, 6), icon_side * 0.43, Color(0, 0, 0, 0.28))
	if GeneratedRelicIcon.draw(self, str(relic_data.get("id", "")), icon_rect):
		pass
	else:
		_draw_fallback_icon(icon_rect, _rarity_color(str(relic_data.get("rarity_code", "common"))))
	if purchased:
		draw_rect(icon_rect.grow(6), Color(0.04, 0.04, 0.05, 0.42), true)
	if hover and not purchased:
		draw_arc(icon_rect.get_center(), icon_side * 0.48, 0.0, TAU, 42, Color.WHITE, 3.0, true)
	var price_color = Color(0.98, 0.83, 0.20) if affordable else Color(0.96, 0.24, 0.31)
	if purchased:
		price_color = Color(0.72, 0.74, 0.78)
	var price_text = "已购买" if purchased else "%d" % price
	var coin_center = Vector2(size.x * 0.5 - 22, size.y - 22)
	draw_circle(coin_center, 11, Color(0.25, 0.12, 0.02, 0.55))
	draw_circle(coin_center, 9, Color(0.98, 0.72, 0.16))
	draw_string(font, Vector2(size.x * 0.5 - 8, size.y - 14), price_text, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5, 18, price_color)
	if purchased:
		draw_rect(rect, Color(0.1, 0.1, 0.11, 0.24), true)

func _draw_fallback_icon(icon_rect: Rect2, accent: Color) -> void:
	var center = icon_rect.get_center()
	draw_circle(center, icon_rect.size.x * 0.34, Color.BLACK)
	draw_circle(center, icon_rect.size.x * 0.27, accent)
	draw_circle(center + Vector2(-icon_rect.size.x * 0.08, -icon_rect.size.x * 0.08), icon_rect.size.x * 0.07, Color.WHITE)

func _rarity_color(code: String) -> Color:
	match code:
		"rare":
			return Color(0.38, 0.64, 1.0)
		"uncommon":
			return Color(0.72, 0.44, 1.0)
		"boss":
			return Color(1.0, 0.70, 0.20)
		_:
			return Color(0.50, 0.86, 0.42)

func _animate_hover(target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
