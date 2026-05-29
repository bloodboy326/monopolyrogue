extends Control

const TileCardFrame = preload("res://scripts/components/TileCardFrame.gd")

var drift = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	drift += delta
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_space_base()
	_draw_nebula_layers()
	_draw_starfield()
	_draw_ringed_planet()
	_draw_meteor_field()
	_draw_board_panel()

func _draw_space_base() -> void:
	var bands = 30
	for i in range(bands):
		var t = float(i) / float(bands - 1)
		var y = size.y * t
		var band_height = size.y / float(bands) + 1.0
		var color = Color(
			lerp(0.015, 0.045, t),
			lerp(0.018, 0.020, t),
			lerp(0.070, 0.145, t),
			1.0
		)
		if t > 0.42:
			color = color.lerp(Color(0.22, 0.065, 0.18, 1.0), (t - 0.42) * 0.34)
		draw_rect(Rect2(0.0, y, size.x, band_height), color, true)

	var horizon = size.y * 0.63 + sin(drift * 0.20) * 16.0
	for i in range(7):
		var alpha = 0.018 + float(i) * 0.006
		var y = horizon + float(i) * 26.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y + sin(drift * 0.13 + float(i)) * 20.0), Color(0.92, 0.24, 0.42, alpha), 24.0 + float(i) * 7.0, true)

func _draw_nebula_layers() -> void:
	_draw_nebula_ribbon(size.y * 0.18, 44.0, 0.72, Color(0.20, 0.80, 1.00, 0.18), 0.0)
	_draw_nebula_ribbon(size.y * 0.45, 62.0, -0.48, Color(0.95, 0.22, 0.58, 0.16), 2.2)
	_draw_nebula_ribbon(size.y * 0.77, 52.0, 0.56, Color(1.00, 0.78, 0.20, 0.12), 4.5)

func _draw_nebula_ribbon(base_y: float, amplitude: float, speed: float, color: Color, phase: float) -> void:
	var points: Array[Vector2] = []
	var segments = 26
	for i in range(segments + 1):
		var x = -110.0 + (size.x + 220.0) * float(i) / float(segments)
		var wave = sin(x * 0.006 + drift * speed + phase) * amplitude
		wave += sin(x * 0.016 - drift * speed * 0.74 + phase * 1.7) * amplitude * 0.38
		points.append(Vector2(x, base_y + wave))
	_draw_soft_polyline(points, Color(color.r, color.g, color.b, color.a * 0.42), 78.0)
	_draw_soft_polyline(points, Color(color.r, color.g, color.b, color.a * 0.74), 38.0)
	_draw_soft_polyline(points, color.lightened(0.28), 9.0)

func _draw_starfield() -> void:
	_draw_star_layer(54, 0.16, 1.2, 0.55)
	_draw_star_layer(42, 0.32, 1.7, 0.72)
	_draw_star_layer(28, 0.56, 2.3, 0.95)

func _draw_star_layer(count: int, parallax: float, max_radius: float, alpha_scale: float) -> void:
	for i in range(count):
		var star_seed = i + int(parallax * 1000.0)
		var p = Vector2(
			_hash01(star_seed * 17 + 3) * (size.x + 180.0) - 90.0,
			_hash01(star_seed * 19 + 7) * (size.y + 180.0) - 90.0
		)
		p += Vector2(-drift * (18.0 + parallax * 52.0), drift * (4.0 + parallax * 16.0))
		p = _wrap_point(p, 90.0)
		var twinkle = 0.56 + sin(drift * (1.9 + parallax * 2.2) + float(star_seed) * 0.71) * 0.32
		var radius = 0.8 + _hash01(star_seed * 23 + 11) * max_radius
		var color = Color(0.88, 0.94, 1.0, clamp(twinkle * alpha_scale, 0.20, 1.0))
		draw_circle(p, radius, color)
		if i % 13 == 0:
			var flare = radius * (2.5 + parallax * 2.0)
			draw_line(p + Vector2(-flare, 0.0), p + Vector2(flare, 0.0), Color(1.0, 0.97, 0.72, color.a * 0.55), max(1.0, radius * 0.58), true)
			draw_line(p + Vector2(0.0, -flare), p + Vector2(0.0, flare), Color(1.0, 0.97, 0.72, color.a * 0.55), max(1.0, radius * 0.58), true)

func _draw_ringed_planet() -> void:
	var planet_radius = clamp(min(size.x, size.y) * 0.092, 48.0, 82.0)
	var center = Vector2(size.x * 0.84 + sin(drift * 0.18) * 12.0, size.y * 0.24 + cos(drift * 0.15) * 8.0)
	var ring_angle = -0.22 + sin(drift * 0.10) * 0.08
	var ring_radii = Vector2(planet_radius * 1.82, planet_radius * 0.43)

	_draw_ellipse_outline(center, ring_radii, ring_angle, Color(0.06, 0.03, 0.09, 0.70), 12.0)
	_draw_ellipse_outline(center, ring_radii, ring_angle, Color(1.0, 0.78, 0.30, 0.42), 5.0)
	_draw_ellipse_outline(center, ring_radii * 0.78, ring_angle, Color(0.31, 0.84, 1.00, 0.20), 3.0)

	draw_circle(center + Vector2(8.0, 10.0), planet_radius * 1.04, Color(0.0, 0.0, 0.0, 0.30))
	draw_circle(center, planet_radius, Color(0.12, 0.35, 0.72, 0.88))
	draw_circle(center + Vector2(-planet_radius * 0.26, -planet_radius * 0.25), planet_radius * 0.72, Color(0.30, 0.76, 1.0, 0.34))
	draw_line(center + Vector2(-planet_radius * 0.70, -planet_radius * 0.04), center + Vector2(planet_radius * 0.60, planet_radius * 0.10), Color(1.0, 0.92, 0.36, 0.22), planet_radius * 0.18, true)
	draw_line(center + Vector2(-planet_radius * 0.58, planet_radius * 0.28), center + Vector2(planet_radius * 0.46, planet_radius * 0.38), Color(0.95, 0.34, 0.54, 0.20), planet_radius * 0.13, true)
	_draw_ellipse_arc(center, ring_radii, ring_angle, PI * 0.05, PI * 0.95, Color(1.0, 0.86, 0.32, 0.64), 6.0)

func _draw_meteor_field() -> void:
	var direction = Vector2(-1.0, 0.36).normalized()
	var normal = Vector2(-direction.y, direction.x)
	var travel = size.x + size.y + 560.0
	var origin = Vector2(size.x + 260.0, -64.0)
	for i in range(7):
		var lane = -260.0 + float(i) * 156.0
		var speed = 0.095 + float(i % 3) * 0.020
		var t = fmod(drift * speed + float(i) * 0.19, 1.0)
		var head = origin + normal * lane + direction * (travel * t)
		var alpha = _meteor_alpha(t) * (0.70 + float(i % 2) * 0.18)
		if alpha <= 0.01:
			continue
		var length = 210.0 + float(i % 3) * 54.0
		_draw_meteor(head, direction, normal, length, alpha, i)

func _meteor_alpha(t: float) -> float:
	var fade_in = smoothstep(0.00, 0.13, t)
	var fade_out = 1.0 - smoothstep(0.74, 0.98, t)
	return fade_in * fade_out

func _draw_meteor(head: Vector2, direction: Vector2, normal: Vector2, length: float, alpha: float, index: int) -> void:
	var tail = head - direction * length
	var mid_tail = head - direction * (length * 0.58)
	draw_line(tail, head, Color(0.96, 0.18, 0.34, alpha * 0.32), 18.0, true)
	draw_line(mid_tail, head, Color(1.0, 0.77, 0.12, alpha * 0.76), 11.0, true)
	draw_line(head - direction * 58.0, head, Color(1.0, 0.98, 0.66, alpha), 5.5, true)

	for i in range(7):
		var spark_t = (float(i) + 1.0) / 8.0
		var spark_seed = index * 37 + i * 11
		var offset = normal * ((_hash01(spark_seed) - 0.5) * 32.0)
		var p = head - direction * (length * spark_t) + offset
		var spark_alpha = alpha * (1.0 - spark_t) * 0.72
		draw_circle(p, 2.0 + _hash01(spark_seed + 5) * 3.0, Color(1.0, 0.86, 0.18, spark_alpha))

	var star_size = 23.0 + float(index % 3) * 4.0
	draw_circle(head, star_size * 1.15, Color(1.0, 0.86, 0.12, alpha * 0.22))
	_draw_star(head + Vector2(4.0, 5.0), star_size * 1.08, star_size * 0.46, -PI * 0.5, Color(0.0, 0.0, 0.0, alpha * 0.32))
	_draw_star(head, star_size, star_size * 0.44, -PI * 0.5, Color(0.08, 0.05, 0.01, alpha * 0.88))
	_draw_star(head, star_size * 0.78, star_size * 0.34, -PI * 0.5, Color(1.0, 0.88, 0.08, alpha))
	_draw_star(head - direction * 2.0, star_size * 0.34, star_size * 0.16, -PI * 0.5, Color(1.0, 0.98, 0.68, alpha))

func _draw_star(center: Vector2, outer_radius: float, inner_radius: float, angle_offset: float, color: Color) -> void:
	var points: Array[Vector2] = []
	for i in range(10):
		var radius = outer_radius if i % 2 == 0 else inner_radius
		var angle = angle_offset + TAU * float(i) / 10.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_draw_poly(points, color)

func _draw_board_panel() -> void:
	var panel = _get_panel_rect()
	_draw_rounded_box(panel.position + Vector2(10.0, 12.0), panel.size, 8.0, Color(0.0, 0.0, 0.0, 0.42))
	_draw_rounded_box(panel.position, panel.size, 8.0, Color(0.01, 0.012, 0.030, 0.95))
	var inner_panel = Rect2(panel.position + Vector2(7.0, 7.0), panel.size - Vector2(14.0, 14.0))
	_draw_rounded_box(inner_panel.position, inner_panel.size, 2.0, Color(0.035, 0.045, 0.075, 0.96))
	TileCardFrame.draw_rect_outline(self, panel.grow(-2.0), Color(1.0, 0.83, 0.26, 0.38), 3.0)
	TileCardFrame.draw_rect_outline(self, inner_panel.grow(-1.0), Color(0.26, 0.83, 1.0, 0.13), 2.0)

	var cell = 58.0
	var offset = fmod(drift * 8.0, cell)
	var cols = int(ceil(inner_panel.size.x / cell)) + 1
	var rows = int(ceil(inner_panel.size.y / cell)) + 1
	for y in range(rows):
		for x in range(cols):
			if (x + y) % 2 == 0:
				var p = inner_panel.position + Vector2(x * cell - offset, y * cell + offset * 0.35)
				var tile_size = Vector2(
					min(cell, inner_panel.end.x - p.x),
					min(cell, inner_panel.end.y - p.y)
				)
				if tile_size.x > 0.0 and tile_size.y > 0.0:
					draw_rect(Rect2(p, tile_size), Color(1.0, 1.0, 1.0, 0.018), true)

func _get_panel_rect() -> Rect2:
	var panel_height = min(size.y - 226.0, max(500.0, size.y * 0.68))
	var panel_width = min(size.x - 94.0, max(690.0, panel_height * 1.34))
	var panel_pos = Vector2((size.x - panel_width) * 0.5, 96.0)
	return Rect2(panel_pos, Vector2(panel_width, panel_height))

func _draw_soft_polyline(points: Array[Vector2], color: Color, width: float) -> void:
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width, true)

func _draw_ellipse_outline(center: Vector2, radii: Vector2, angle: float, color: Color, width: float) -> void:
	var points = _ellipse_points(center, radii, angle, 72, 0.0, TAU)
	_draw_soft_polyline(points, color, width)

func _draw_ellipse_arc(center: Vector2, radii: Vector2, angle: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var points = _ellipse_points(center, radii, angle, 32, start_angle, end_angle)
	_draw_soft_polyline(points, color, width)

func _ellipse_points(center: Vector2, radii: Vector2, angle: float, count: int, start_angle: float, end_angle: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var c = cos(angle)
	var s = sin(angle)
	for i in range(count + 1):
		var t = lerp(start_angle, end_angle, float(i) / float(count))
		var local = Vector2(cos(t) * radii.x, sin(t) * radii.y)
		points.append(center + Vector2(local.x * c - local.y * s, local.x * s + local.y * c))
	return points

func _wrap_point(point: Vector2, margin: float) -> Vector2:
	return Vector2(
		fposmod(point.x + margin, size.x + margin * 2.0) - margin,
		fposmod(point.y + margin, size.y + margin * 2.0) - margin
	)

func _hash01(hash_seed: int) -> float:
	return fposmod(sin(float(hash_seed) * 12.9898) * 43758.5453, 1.0)

func _draw_poly(points: Array[Vector2], color: Color) -> void:
	var packed = PackedVector2Array()
	for point in points:
		packed.append(point)
	draw_polygon(packed, PackedColorArray([color]))

func _draw_rounded_box(pos: Vector2, box_size: Vector2, radius: float, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, Rect2(pos, box_size))
