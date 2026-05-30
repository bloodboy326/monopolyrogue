extends Control

var title_label: Label
var detail_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	title_label = _make_label(42, Color.WHITE)
	detail_label = _make_label(24, Color(1.0, 0.88, 0.24, 1.0))
	add_child(title_label)
	add_child(detail_label)

func play(battle_number: int, _unused_target: int = 0) -> void:
	visible = true
	modulate.a = 1.0
	title_label.text = "第 %d 关" % battle_number
	detail_label.text = "击败当前怪物"
	_layout_labels()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.75)
	tween.tween_property(self, "modulate:a", 0.0, 0.20)
	await tween.finished
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_labels()

func _layout_labels() -> void:
	if title_label == null or detail_label == null:
		return
	title_label.size = Vector2(size.x, 54.0)
	title_label.position = Vector2(0.0, size.y * 0.42)
	detail_label.size = Vector2(size.x, 36.0)
	detail_label.position = Vector2(0.0, size.y * 0.42 + 50.0)

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
