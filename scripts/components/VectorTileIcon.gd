extends RefCounted

const INK = Color(0.02, 0.02, 0.025, 1.0)
const PAPER = Color(0.98, 0.96, 0.86, 1.0)
const WHITE = Color(0.98, 0.98, 0.95, 1.0)
const CORAL = Color(0.96, 0.35, 0.43, 1.0)
const TEAL = Color(0.15, 0.82, 0.74, 1.0)
const YELLOW = Color(1.0, 0.86, 0.22, 1.0)
const SKY = Color(0.34, 0.62, 1.0, 1.0)

static func draw_icon(canvas: CanvasItem, kind: String, icon_id: int, rect: Rect2, base_color: Color, accent_color: Color) -> void:
	var resolved = kind
	if resolved.is_empty():
		resolved = _kind_from_icon_id(icon_id)
	match resolved:
		"empty":
			_draw_empty(canvas, rect, accent_color)
		"coin":
			_draw_coin(canvas, rect, accent_color)
		"piggy_bank":
			_draw_piggy_bank(canvas, rect, accent_color)
		"market":
			_draw_market(canvas, rect, accent_color)
		"factory":
			_draw_factory(canvas, rect, accent_color)
		"haunted_house":
			_draw_haunted_house(canvas, rect, accent_color)
		"bank":
			_draw_bank(canvas, rect, accent_color)
		"shop":
			_draw_shop(canvas, rect, accent_color)
		"farm":
			_draw_farm(canvas, rect, accent_color)
		"mine":
			_draw_mine(canvas, rect, accent_color)
		"harbor":
			_draw_harbor(canvas, rect, accent_color)
		"lab":
			_draw_lab(canvas, rect, accent_color)
		"casino":
			_draw_casino(canvas, rect, accent_color)
		"heart":
			_draw_suit(canvas, rect, "heart", CORAL)
		"spade":
			_draw_suit(canvas, rect, "spade", INK)
		"diamond":
			_draw_suit(canvas, rect, "diamond", CORAL)
		"club":
			_draw_suit(canvas, rect, "club", INK)
		"joker":
			_draw_joker(canvas, rect, accent_color)
		"card_shark":
			_draw_card_shark(canvas, rect, accent_color)
		"graveyard":
			_draw_graveyard(canvas, rect, accent_color)
		"ghost":
			_draw_ghost(canvas, rect, accent_color)
		"coffin":
			_draw_coffin(canvas, rect, accent_color)
		"vampire":
			_draw_vampire(canvas, rect, accent_color)
		"bulldozer":
			_draw_bulldozer(canvas, rect, accent_color)
		"water":
			_draw_water(canvas, rect, accent_color)
		"sapling":
			_draw_sapling(canvas, rect, accent_color)
		"tree":
			_draw_tree(canvas, rect, accent_color)
		"orchard":
			_draw_orchard(canvas, rect, accent_color)
		"jam":
			_draw_jam(canvas, rect, accent_color)
		_:
			_draw_fallback(canvas, rect, base_color, accent_color)

static func _kind_from_icon_id(icon_id: int) -> String:
	match icon_id:
		1:
			return "market"
		2:
			return "factory"
		3:
			return "haunted_house"
		4:
			return "bank"
		5:
			return "shop"
		6:
			return "farm"
		7:
			return "mine"
		8:
			return "harbor"
		9:
			return "lab"
		10:
			return "casino"
		_:
			return "fallback"

static func _draw_market(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_box(canvas, rect, 0.22, 0.43, 0.58, 0.34, INK)
	_box(canvas, rect, 0.27, 0.48, 0.48, 0.23, Color(0.60, 0.33, 0.16, 1.0))
	_poly(canvas, rect, [Vector2(0.18, 0.38), Vector2(0.30, 0.20), Vector2(0.70, 0.20), Vector2(0.82, 0.38)], INK)
	for i in range(5):
		var color = CORAL if i % 2 == 0 else PAPER
		_box(canvas, rect, 0.20 + i * 0.12, 0.25, 0.12, 0.18, color)
	_line(canvas, rect, Vector2(0.26, 0.43), Vector2(0.74, 0.43), INK, 0.045)
	canvas.draw_circle(_pt(rect, 0.36, 0.59), rect.size.x * 0.055, YELLOW)
	canvas.draw_circle(_pt(rect, 0.50, 0.58), rect.size.x * 0.055, TEAL)
	canvas.draw_circle(_pt(rect, 0.64, 0.59), rect.size.x * 0.055, accent.lightened(0.08))

static func _draw_empty(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_line(canvas, rect, Vector2(0.26, 0.50), Vector2(0.74, 0.50), Color(1.0, 1.0, 1.0, 0.32), 0.05)
	_line(canvas, rect, Vector2(0.50, 0.26), Vector2(0.50, 0.74), accent.darkened(0.25), 0.035)

static func _draw_coin(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	canvas.draw_circle(_pt(rect, 0.50, 0.50), rect.size.x * 0.31, INK)
	canvas.draw_circle(_pt(rect, 0.50, 0.50), rect.size.x * 0.24, accent)
	canvas.draw_circle(_pt(rect, 0.43, 0.41), rect.size.x * 0.08, Color(1.0, 0.97, 0.72, 0.92))
	_line(canvas, rect, Vector2(0.50, 0.32), Vector2(0.50, 0.68), INK, 0.04)
	_line(canvas, rect, Vector2(0.39, 0.44), Vector2(0.61, 0.44), INK, 0.032)
	_line(canvas, rect, Vector2(0.39, 0.57), Vector2(0.61, 0.57), INK, 0.032)

static func _draw_piggy_bank(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	canvas.draw_circle(_pt(rect, 0.50, 0.52), rect.size.x * 0.27, INK)
	canvas.draw_circle(_pt(rect, 0.50, 0.52), rect.size.x * 0.21, CORAL.lightened(0.12))
	_poly(canvas, rect, [Vector2(0.35, 0.33), Vector2(0.42, 0.20), Vector2(0.47, 0.36)], CORAL.lightened(0.2))
	_box(canvas, rect, 0.70, 0.48, 0.10, 0.07, INK)
	canvas.draw_circle(_pt(rect, 0.60, 0.43), rect.size.x * 0.025, INK)
	_line(canvas, rect, Vector2(0.40, 0.73), Vector2(0.34, 0.82), INK, 0.035)
	_line(canvas, rect, Vector2(0.60, 0.73), Vector2(0.66, 0.82), INK, 0.035)
	_line(canvas, rect, Vector2(0.42, 0.33), Vector2(0.58, 0.33), accent, 0.030)

static func _draw_factory(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_box(canvas, rect, 0.22, 0.40, 0.62, 0.34, INK)
	_box(canvas, rect, 0.28, 0.47, 0.48, 0.20, Color(0.18, 0.44, 0.58, 1.0))
	_poly(canvas, rect, [Vector2(0.22, 0.40), Vector2(0.35, 0.28), Vector2(0.45, 0.40), Vector2(0.58, 0.28), Vector2(0.69, 0.40)], accent)
	_box(canvas, rect, 0.66, 0.21, 0.10, 0.26, INK)
	_box(canvas, rect, 0.69, 0.24, 0.05, 0.20, Color(0.34, 0.35, 0.39, 1.0))
	canvas.draw_circle(_pt(rect, 0.77, 0.18), rect.size.x * 0.045, Color(0.90, 0.90, 0.86, 0.72))
	canvas.draw_circle(_pt(rect, 0.84, 0.12), rect.size.x * 0.034, Color(0.90, 0.90, 0.86, 0.58))
	_box(canvas, rect, 0.34, 0.53, 0.12, 0.09, SKY)
	_box(canvas, rect, 0.54, 0.53, 0.12, 0.09, SKY)

static func _draw_haunted_house(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	canvas.draw_circle(_pt(rect, 0.76, 0.23), rect.size.x * 0.12, YELLOW)
	canvas.draw_circle(_pt(rect, 0.80, 0.20), rect.size.x * 0.11, accent.darkened(0.25))
	_poly(canvas, rect, [Vector2(0.20, 0.50), Vector2(0.33, 0.24), Vector2(0.47, 0.39), Vector2(0.62, 0.20), Vector2(0.80, 0.50)], INK)
	_box(canvas, rect, 0.28, 0.46, 0.42, 0.30, INK)
	_box(canvas, rect, 0.36, 0.55, 0.10, 0.12, YELLOW)
	_box(canvas, rect, 0.55, 0.54, 0.10, 0.13, TEAL)
	_line(canvas, rect, Vector2(0.50, 0.45), Vector2(0.44, 0.36), accent, 0.035)
	_line(canvas, rect, Vector2(0.50, 0.45), Vector2(0.58, 0.36), accent, 0.035)

static func _draw_bank(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_poly(canvas, rect, [Vector2(0.18, 0.37), Vector2(0.50, 0.18), Vector2(0.82, 0.37)], INK)
	_poly(canvas, rect, [Vector2(0.27, 0.34), Vector2(0.50, 0.21), Vector2(0.73, 0.34)], accent)
	for x in [0.31, 0.45, 0.59]:
		_box(canvas, rect, x, 0.40, 0.08, 0.30, INK)
		_box(canvas, rect, x + 0.02, 0.43, 0.04, 0.23, WHITE)
	_box(canvas, rect, 0.24, 0.70, 0.52, 0.07, INK)
	_box(canvas, rect, 0.30, 0.76, 0.40, 0.05, INK)

static func _draw_shop(canvas: CanvasItem, rect: Rect2, _accent: Color) -> void:
	_box(canvas, rect, 0.24, 0.38, 0.52, 0.38, INK)
	_box(canvas, rect, 0.31, 0.48, 0.38, 0.22, Color(0.74, 0.48, 0.24, 1.0))
	for i in range(4):
		var color = CORAL if i % 2 == 0 else PAPER
		_box(canvas, rect, 0.24 + i * 0.13, 0.25, 0.13, 0.17, color)
	_line(canvas, rect, Vector2(0.25, 0.43), Vector2(0.75, 0.43), INK, 0.045)
	_box(canvas, rect, 0.42, 0.54, 0.10, 0.16, TEAL)

static func _draw_farm(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_poly(canvas, rect, [Vector2(0.22, 0.62), Vector2(0.48, 0.30), Vector2(0.74, 0.62)], INK)
	_box(canvas, rect, 0.31, 0.54, 0.34, 0.22, CORAL)
	_line(canvas, rect, Vector2(0.31, 0.54), Vector2(0.65, 0.76), WHITE, 0.028)
	_line(canvas, rect, Vector2(0.65, 0.54), Vector2(0.31, 0.76), WHITE, 0.028)
	for x in [0.23, 0.35, 0.47, 0.59, 0.71]:
		_line(canvas, rect, Vector2(x, 0.80), Vector2(x + 0.07, 0.58), accent, 0.026)

static func _draw_mine(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_poly(canvas, rect, [Vector2(0.16, 0.74), Vector2(0.30, 0.38), Vector2(0.50, 0.22), Vector2(0.70, 0.38), Vector2(0.84, 0.74)], Color(0.43, 0.42, 0.40, 1.0))
	canvas.draw_circle(_pt(rect, 0.50, 0.63), rect.size.x * 0.19, INK)
	_line(canvas, rect, Vector2(0.35, 0.82), Vector2(0.65, 0.82), accent, 0.035)
	_line(canvas, rect, Vector2(0.40, 0.80), Vector2(0.52, 0.65), accent, 0.025)
	_line(canvas, rect, Vector2(0.60, 0.80), Vector2(0.48, 0.65), accent, 0.025)
	_line(canvas, rect, Vector2(0.64, 0.29), Vector2(0.78, 0.45), INK, 0.04)
	_line(canvas, rect, Vector2(0.77, 0.30), Vector2(0.62, 0.44), INK, 0.04)

static func _draw_harbor(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_line(canvas, rect, Vector2(0.25, 0.72), Vector2(0.75, 0.72), SKY, 0.04)
	_line(canvas, rect, Vector2(0.30, 0.82), Vector2(0.70, 0.82), SKY, 0.04)
	_poly(canvas, rect, [Vector2(0.26, 0.54), Vector2(0.74, 0.54), Vector2(0.62, 0.70), Vector2(0.35, 0.70)], INK)
	_poly(canvas, rect, [Vector2(0.36, 0.46), Vector2(0.48, 0.22), Vector2(0.48, 0.52)], accent)
	_line(canvas, rect, Vector2(0.50, 0.22), Vector2(0.50, 0.56), INK, 0.035)

static func _draw_lab(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_box(canvas, rect, 0.42, 0.22, 0.16, 0.18, INK)
	_poly(canvas, rect, [Vector2(0.34, 0.38), Vector2(0.66, 0.38), Vector2(0.76, 0.76), Vector2(0.24, 0.76)], INK)
	_poly(canvas, rect, [Vector2(0.40, 0.44), Vector2(0.60, 0.44), Vector2(0.66, 0.66), Vector2(0.34, 0.66)], TEAL)
	canvas.draw_circle(_pt(rect, 0.33, 0.28), rect.size.x * 0.055, accent)
	canvas.draw_circle(_pt(rect, 0.70, 0.24), rect.size.x * 0.038, WHITE)
	canvas.draw_circle(_pt(rect, 0.64, 0.62), rect.size.x * 0.036, WHITE)

static func _draw_casino(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	canvas.draw_circle(_pt(rect, 0.36, 0.56), rect.size.x * 0.18, INK)
	canvas.draw_circle(_pt(rect, 0.36, 0.56), rect.size.x * 0.12, CORAL)
	_box(canvas, rect, 0.48, 0.30, 0.25, 0.25, INK)
	_box(canvas, rect, 0.52, 0.34, 0.17, 0.17, WHITE)
	canvas.draw_circle(_pt(rect, 0.56, 0.38), rect.size.x * 0.018, INK)
	canvas.draw_circle(_pt(rect, 0.65, 0.47), rect.size.x * 0.018, INK)
	_poly(canvas, rect, [Vector2(0.66, 0.64), Vector2(0.74, 0.56), Vector2(0.82, 0.64), Vector2(0.74, 0.72)], accent)

static func _draw_suit(canvas: CanvasItem, rect: Rect2, suit: String, color: Color) -> void:
	match suit:
		"heart":
			canvas.draw_circle(_pt(rect, 0.40, 0.40), rect.size.x * 0.13, color)
			canvas.draw_circle(_pt(rect, 0.60, 0.40), rect.size.x * 0.13, color)
			_poly(canvas, rect, [Vector2(0.28, 0.45), Vector2(0.72, 0.45), Vector2(0.50, 0.75)], color)
		"diamond":
			_poly(canvas, rect, [Vector2(0.50, 0.20), Vector2(0.76, 0.50), Vector2(0.50, 0.80), Vector2(0.24, 0.50)], color)
		"club":
			canvas.draw_circle(_pt(rect, 0.50, 0.34), rect.size.x * 0.12, color)
			canvas.draw_circle(_pt(rect, 0.38, 0.52), rect.size.x * 0.12, color)
			canvas.draw_circle(_pt(rect, 0.62, 0.52), rect.size.x * 0.12, color)
			_poly(canvas, rect, [Vector2(0.46, 0.58), Vector2(0.54, 0.58), Vector2(0.59, 0.76), Vector2(0.41, 0.76)], color)
		_:
			_poly(canvas, rect, [Vector2(0.50, 0.20), Vector2(0.34, 0.48), Vector2(0.50, 0.42), Vector2(0.66, 0.48)], color)
			canvas.draw_circle(_pt(rect, 0.50, 0.39), rect.size.x * 0.17, color)
			_poly(canvas, rect, [Vector2(0.46, 0.56), Vector2(0.54, 0.56), Vector2(0.61, 0.77), Vector2(0.39, 0.77)], color)

static func _draw_joker(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_poly(canvas, rect, [Vector2(0.24, 0.38), Vector2(0.36, 0.22), Vector2(0.50, 0.40), Vector2(0.64, 0.22), Vector2(0.76, 0.38), Vector2(0.70, 0.72), Vector2(0.30, 0.72)], INK)
	_poly(canvas, rect, [Vector2(0.30, 0.40), Vector2(0.38, 0.30), Vector2(0.50, 0.47), Vector2(0.62, 0.30), Vector2(0.70, 0.40), Vector2(0.65, 0.64), Vector2(0.35, 0.64)], accent)
	canvas.draw_circle(_pt(rect, 0.39, 0.30), rect.size.x * 0.035, YELLOW)
	canvas.draw_circle(_pt(rect, 0.62, 0.30), rect.size.x * 0.035, CORAL)

static func _draw_card_shark(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_poly(canvas, rect, [Vector2(0.20, 0.58), Vector2(0.50, 0.28), Vector2(0.82, 0.58), Vector2(0.62, 0.74), Vector2(0.38, 0.74)], INK)
	_poly(canvas, rect, [Vector2(0.28, 0.57), Vector2(0.50, 0.36), Vector2(0.73, 0.57), Vector2(0.58, 0.66), Vector2(0.42, 0.66)], Color(0.20, 0.74, 0.90, 1.0))
	_poly(canvas, rect, [Vector2(0.50, 0.36), Vector2(0.58, 0.20), Vector2(0.60, 0.44)], accent)
	_line(canvas, rect, Vector2(0.42, 0.58), Vector2(0.60, 0.58), WHITE, 0.02)

static func _draw_graveyard(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_box(canvas, rect, 0.36, 0.32, 0.28, 0.42, INK)
	canvas.draw_circle(_pt(rect, 0.50, 0.33), rect.size.x * 0.14, INK)
	_box(canvas, rect, 0.40, 0.39, 0.20, 0.30, Color(0.56, 0.58, 0.62, 1.0))
	_line(canvas, rect, Vector2(0.50, 0.42), Vector2(0.50, 0.61), accent, 0.03)
	_line(canvas, rect, Vector2(0.43, 0.49), Vector2(0.57, 0.49), accent, 0.03)
	_line(canvas, rect, Vector2(0.24, 0.78), Vector2(0.76, 0.78), INK, 0.04)

static func _draw_ghost(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	canvas.draw_circle(_pt(rect, 0.50, 0.40), rect.size.x * 0.22, INK)
	_box(canvas, rect, 0.28, 0.40, 0.44, 0.32, INK)
	canvas.draw_circle(_pt(rect, 0.50, 0.41), rect.size.x * 0.17, WHITE)
	_box(canvas, rect, 0.34, 0.43, 0.32, 0.25, WHITE)
	canvas.draw_circle(_pt(rect, 0.43, 0.42), rect.size.x * 0.027, INK)
	canvas.draw_circle(_pt(rect, 0.57, 0.42), rect.size.x * 0.027, INK)
	_line(canvas, rect, Vector2(0.36, 0.70), Vector2(0.42, 0.61), accent, 0.025)
	_line(canvas, rect, Vector2(0.50, 0.70), Vector2(0.56, 0.61), accent, 0.025)

static func _draw_coffin(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_poly(canvas, rect, [Vector2(0.40, 0.18), Vector2(0.60, 0.18), Vector2(0.74, 0.34), Vector2(0.66, 0.78), Vector2(0.34, 0.78), Vector2(0.26, 0.34)], INK)
	_poly(canvas, rect, [Vector2(0.43, 0.25), Vector2(0.57, 0.25), Vector2(0.66, 0.37), Vector2(0.60, 0.70), Vector2(0.40, 0.70), Vector2(0.34, 0.37)], Color(0.45, 0.22, 0.12, 1.0))
	_line(canvas, rect, Vector2(0.50, 0.34), Vector2(0.50, 0.61), accent, 0.035)
	_line(canvas, rect, Vector2(0.42, 0.45), Vector2(0.58, 0.45), accent, 0.035)

static func _draw_vampire(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_poly(canvas, rect, [Vector2(0.26, 0.30), Vector2(0.50, 0.18), Vector2(0.74, 0.30), Vector2(0.66, 0.74), Vector2(0.50, 0.62), Vector2(0.34, 0.74)], INK)
	canvas.draw_circle(_pt(rect, 0.50, 0.42), rect.size.x * 0.16, WHITE)
	_line(canvas, rect, Vector2(0.43, 0.52), Vector2(0.46, 0.62), accent, 0.025)
	_line(canvas, rect, Vector2(0.57, 0.52), Vector2(0.54, 0.62), accent, 0.025)
	canvas.draw_circle(_pt(rect, 0.44, 0.39), rect.size.x * 0.022, INK)
	canvas.draw_circle(_pt(rect, 0.56, 0.39), rect.size.x * 0.022, INK)

static func _draw_bulldozer(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_box(canvas, rect, 0.22, 0.47, 0.46, 0.20, INK)
	_box(canvas, rect, 0.30, 0.37, 0.24, 0.15, INK)
	_box(canvas, rect, 0.34, 0.40, 0.15, 0.09, accent)
	_poly(canvas, rect, [Vector2(0.67, 0.45), Vector2(0.83, 0.37), Vector2(0.83, 0.68), Vector2(0.67, 0.63)], INK)
	canvas.draw_circle(_pt(rect, 0.34, 0.70), rect.size.x * 0.07, Color(0.10, 0.10, 0.11, 1.0))
	canvas.draw_circle(_pt(rect, 0.56, 0.70), rect.size.x * 0.07, Color(0.10, 0.10, 0.11, 1.0))

static func _draw_water(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_poly(canvas, rect, [Vector2(0.50, 0.18), Vector2(0.72, 0.52), Vector2(0.61, 0.76), Vector2(0.39, 0.76), Vector2(0.28, 0.52)], INK)
	_poly(canvas, rect, [Vector2(0.50, 0.26), Vector2(0.65, 0.53), Vector2(0.57, 0.68), Vector2(0.43, 0.68), Vector2(0.35, 0.53)], accent)
	canvas.draw_circle(_pt(rect, 0.43, 0.48), rect.size.x * 0.045, Color(1.0, 1.0, 1.0, 0.65))

static func _draw_sapling(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_line(canvas, rect, Vector2(0.50, 0.78), Vector2(0.50, 0.42), Color(0.30, 0.18, 0.10, 1.0), 0.045)
	canvas.draw_circle(_pt(rect, 0.40, 0.44), rect.size.x * 0.12, Color(0.20, 0.72, 0.32, 1.0))
	canvas.draw_circle(_pt(rect, 0.60, 0.40), rect.size.x * 0.12, Color(0.24, 0.82, 0.38, 1.0))
	canvas.draw_circle(_pt(rect, 0.50, 0.32), rect.size.x * 0.10, accent)

static func _draw_tree(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_line(canvas, rect, Vector2(0.50, 0.78), Vector2(0.50, 0.45), Color(0.36, 0.20, 0.10, 1.0), 0.07)
	canvas.draw_circle(_pt(rect, 0.50, 0.36), rect.size.x * 0.22, Color(0.18, 0.66, 0.28, 1.0))
	canvas.draw_circle(_pt(rect, 0.38, 0.49), rect.size.x * 0.16, Color(0.22, 0.76, 0.32, 1.0))
	canvas.draw_circle(_pt(rect, 0.62, 0.50), rect.size.x * 0.16, Color(0.22, 0.76, 0.32, 1.0))
	canvas.draw_circle(_pt(rect, 0.58, 0.38), rect.size.x * 0.045, accent)
	canvas.draw_circle(_pt(rect, 0.42, 0.50), rect.size.x * 0.04, accent)

static func _draw_orchard(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	for x in [0.34, 0.50, 0.66]:
		_line(canvas, rect, Vector2(x, 0.76), Vector2(x, 0.52), Color(0.34, 0.20, 0.10, 1.0), 0.035)
		canvas.draw_circle(_pt(rect, x, 0.45), rect.size.x * 0.11, Color(0.18, 0.66, 0.28, 1.0))
		canvas.draw_circle(_pt(rect, x + 0.04, 0.42), rect.size.x * 0.03, accent)
	_line(canvas, rect, Vector2(0.24, 0.80), Vector2(0.76, 0.80), INK, 0.035)

static func _draw_jam(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	_box(canvas, rect, 0.34, 0.30, 0.32, 0.10, INK)
	_box(canvas, rect, 0.30, 0.38, 0.40, 0.34, INK)
	_box(canvas, rect, 0.35, 0.43, 0.30, 0.23, accent)
	_line(canvas, rect, Vector2(0.38, 0.51), Vector2(0.62, 0.51), WHITE, 0.025)
	canvas.draw_circle(_pt(rect, 0.42, 0.58), rect.size.x * 0.03, WHITE)

static func _draw_fallback(canvas: CanvasItem, rect: Rect2, base: Color, accent: Color) -> void:
	canvas.draw_circle(rect.get_center(), rect.size.x * 0.28, INK)
	canvas.draw_circle(rect.get_center(), rect.size.x * 0.18, base.lightened(0.18))
	_poly(canvas, rect, [Vector2(0.50, 0.24), Vector2(0.68, 0.50), Vector2(0.50, 0.76), Vector2(0.32, 0.50)], accent)

static func _box(canvas: CanvasItem, rect: Rect2, x: float, y: float, w: float, h: float, color: Color) -> void:
	canvas.draw_rect(Rect2(_pt(rect, x, y), Vector2(rect.size.x * w, rect.size.y * h)), color, true)

static func _line(canvas: CanvasItem, rect: Rect2, a: Vector2, b: Vector2, color: Color, width_ratio: float) -> void:
	canvas.draw_line(_pt(rect, a.x, a.y), _pt(rect, b.x, b.y), color, max(1.0, rect.size.x * width_ratio), true)

static func _poly(canvas: CanvasItem, rect: Rect2, points: Array[Vector2], color: Color) -> void:
	var packed = PackedVector2Array()
	for point in points:
		packed.append(_pt(rect, point.x, point.y))
	canvas.draw_polygon(packed, PackedColorArray([color]))

static func _pt(rect: Rect2, x: float, y: float) -> Vector2:
	return rect.position + Vector2(rect.size.x * x, rect.size.y * y)
