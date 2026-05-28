extends Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	z_index = 120
	add_theme_font_size_override("font_size", 28)
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	add_theme_constant_override("shadow_offset_x", 3)
	add_theme_constant_override("shadow_offset_y", 3)

func play(message: String, start_position: Vector2, color: Color = Color.WHITE) -> void:
	text = message
	size = Vector2(150, 48)
	pivot_offset = size * 0.5
	position = start_position - pivot_offset
	modulate = color
	scale = Vector2(0.35, 0.35)
	rotation = randf_range(-0.12, 0.12)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(randf_range(-14.0, 14.0), -82.0), 0.82).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.38).set_delay(0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.34).set_delay(0.48)
	tween.tween_property(self, "rotation", rotation + randf_range(-0.16, 0.16), 0.52)
	await tween.finished
	queue_free()
