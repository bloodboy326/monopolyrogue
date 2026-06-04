extends Control

signal picked(index: int)

const GeneratedRelicIcon = preload("res://scripts/components/GeneratedRelicIcon.gd")

var relic_index := 0
var relic_data: Dictionary = {}
var price := -1
var affordable := true
var purchased := false
var hover := false

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

func setup(index: int, data: Dictionary, card_price: int = -1, can_afford: bool = true, is_purchased: bool = false) -> void:
	relic_index = index
	relic_data = data.duplicate(true)
	price = card_price
	affordable = can_afford
	purchased = is_purchased
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if purchased:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		picked.emit(relic_index)

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var bg = Color(0.08, 0.08, 0.10, 0.96) if not purchased else Color(0.12, 0.12, 0.13, 0.70)
	draw_rect(rect, Color.BLACK, true)
	draw_rect(rect.grow(-4.0), bg, true)
	var border = _rarity_color(str(relic_data.get("rarity_code", "common")))
	draw_rect(rect.grow(-5.0), border, false, 3.0)
	if hover and not purchased:
		draw_rect(rect.grow(-2.0), Color.WHITE, false, 3.0)

	var font = get_theme_default_font()
	var name = str(relic_data.get("name", relic_data.get("id", "")))
	draw_string(font, Vector2(10, 28), name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 19, Color.WHITE)
	var icon_side = min(size.x * 0.46, size.y * 0.34)
	var icon_rect = Rect2(Vector2(size.x * 0.5 - icon_side * 0.5, 44), Vector2(icon_side, icon_side))
	if not GeneratedRelicIcon.draw(self, str(relic_data.get("id", "")), icon_rect):
		_draw_fallback_icon(icon_rect, border)

	var rarity = str(relic_data.get("rarity", "普通"))
	draw_string(font, Vector2(0, icon_rect.end.y + 22), rarity, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, border)
	var desc = str(relic_data.get("displayDescription", relic_data.get("description", "")))
	draw_multiline_string(font, Vector2(12, icon_rect.end.y + 48), desc, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 15, 5, Color(0.92, 0.94, 1.0))
	if price >= 0:
		var price_color = Color(1.0, 0.88, 0.22) if affordable else Color(0.95, 0.25, 0.32)
		var text = "已购买" if purchased else "%d 金币" % price
		draw_string(font, Vector2(0, size.y - 14), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, price_color)

func _draw_fallback_icon(icon_rect: Rect2, accent: Color) -> void:
	var center = icon_rect.get_center()
	draw_circle(center + Vector2(3, 4), icon_rect.size.x * 0.36, Color(0, 0, 0, 0.38))
	draw_circle(center, icon_rect.size.x * 0.34, Color.BLACK)
	draw_circle(center, icon_rect.size.x * 0.27, accent)
	draw_circle(center + Vector2(-icon_rect.size.x * 0.08, -icon_rect.size.x * 0.08), icon_rect.size.x * 0.07, Color.WHITE)

func _rarity_color(code: String) -> Color:
	match code:
		"common":
			return Color(0.50, 0.86, 0.42)
		"rare":
			return Color(0.38, 0.64, 1.0)
		"uncommon":
			return Color(0.72, 0.44, 1.0)
		"boss":
			return Color(1.0, 0.70, 0.20)
		_:
			return Color(0.82, 0.84, 0.88)

func _animate_hover(target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
