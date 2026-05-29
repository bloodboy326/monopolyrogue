extends Control

var bar_progress = 0.0
var stripe_time = 0.0
var title_label: Label
var target_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	title_label = _make_label(42, Color.WHITE)
	target_label = _make_label(24, Color(1.0, 0.88, 0.24, 1.0))
	add_child(title_label)
	add_child(target_label)

func _process(delta: float) -> void:
	stripe_time += delta
	queue_redraw()

func play(round_number: int, target_score: int) -> void:
	visible = true
	modulate.a = 1.0
	bar_progress = 0.0
	stripe_time = 0.0
	set_process(true)
	title_label.text = "第 %d 轮" % round_number
	target_label.text = "目标 %d 金币" % target_score
	_layout_labels()
	_prepare_label(title_label)
	_prepare_label(target_label)

	var tween = create_tween()
	tween.tween_method(_set_bar_progress, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_pop_label.bind(title_label, 0.0))
	tween.tween_interval(0.10)
	tween.tween_callback(_pop_label.bind(target_label, 0.0))
	tween.tween_interval(1.05)
	tween.tween_property(self, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_labels()

func _draw() -> void:
	if bar_progress <= 0.0:
		return
	var bar_height = clamp(size.y * 0.135, 104.0, 126.0)
	var y = size.y * 0.38
	var visible_width = size.x * bar_progress
	var x = size.x * 0.5 - visible_width * 0.5
	var rect = Rect2(Vector2(x, y), Vector2(visible_width, bar_height))
	draw_rect(Rect2(rect.position + Vector2(0.0, 9.0), rect.size), Color(0.0, 0.0, 0.0, 0.32), true)
	draw_rect(rect, Color(0.015, 0.015, 0.018, 1.0), true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7.0)), Color(1.0, 0.86, 0.22, 1.0), true)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 7.0), Vector2(rect.size.x, 7.0)), Color(0.96, 0.30, 0.40, 1.0), true)
	_draw_side_ticks(rect)

func _draw_side_ticks(rect: Rect2) -> void:
	var tick_count = 8
	var step = rect.size.x / float(tick_count)
	for i in range(tick_count + 1):
		var alpha = 0.18 + sin(stripe_time * 3.0 + i * 0.7) * 0.06
		var color = Color(1.0, 1.0, 1.0, alpha)
		var x = rect.position.x + step * float(i)
		draw_rect(Rect2(Vector2(x - 2.0, rect.position.y + 16.0), Vector2(4.0, rect.size.y - 32.0)), color, true)

func _set_bar_progress(value: float) -> void:
	bar_progress = value
	queue_redraw()

func _layout_labels() -> void:
	if title_label == null or target_label == null:
		return
	var bar_height = clamp(size.y * 0.135, 104.0, 126.0)
	var y = size.y * 0.38
	title_label.size = Vector2(size.x, 52.0)
	title_label.position = Vector2(0.0, y + 16.0)
	title_label.pivot_offset = title_label.size * 0.5
	target_label.size = Vector2(size.x, 36.0)
	target_label.position = Vector2(0.0, y + bar_height - 48.0)
	target_label.pivot_offset = target_label.size * 0.5

func _prepare_label(label: Label) -> void:
	label.modulate.a = 0.0
	label.scale = Vector2(0.72, 0.72)

func _pop_label(label: Label, _delay: float) -> void:
	var base_position = label.position
	label.position = base_position + Vector2(0.0, 12.0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", base_position, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_delay(0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _make_label(font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	return label
