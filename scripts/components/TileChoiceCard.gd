extends Control

signal picked(index: int)
signal info_hovered(tile_data: Dictionary, anchor_global_pos: Vector2)
signal info_hidden
signal reference_hovered(tile_id: String, anchor_global_pos: Vector2)

const TileCardFrame = preload("res://scripts/components/TileCardFrame.gd")
const VectorTileIcon = preload("res://scripts/components/VectorTileIcon.gd")
const RichDescription = preload("res://scripts/components/RichDescription.gd")

var tile_index = 0
var tile_name = ""
var tile_kind = ""
var tile_icon = 0
var tile_rare = "普通"
var tile_describe = ""
var hover = false
var base_color = Color(0.95, 0.36, 0.43, 1.0)
var accent_color = Color(1.0, 0.86, 0.22, 1.0)
var idle_enabled = false
var idle_time = 0.0
var idle_phase = 0.0
var idle_base_position = Vector2.ZERO
var tile_data: Dictionary = {}
var description_text: RichTextLabel

var rare_colors = {
	"基础牌": Color(0.74, 0.76, 0.80, 1.0),
	"普通": Color(0.45, 0.83, 0.38, 1.0),
	"稀有": Color(0.36, 0.62, 1.0, 1.0),
	"诅咒": Color(0.94, 0.12, 0.30, 1.0)
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_description_label()
	_update_description_label()
	mouse_entered.connect(func() -> void:
		hover = true
		_animate_hover(Vector2(1.035, 1.035))
		info_hovered.emit(tile_data, get_global_mouse_position())
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hover = false
		_animate_hover(Vector2.ONE)
		info_hidden.emit()
		queue_redraw()
	)

func setup(index: int, data: Dictionary) -> void:
	tile_data = data.duplicate(true)
	tile_index = index
	tile_name = str(data.get("tile_name", data.get("name", "")))
	tile_kind = str(data.get("kind", ""))
	tile_icon = int(data.get("tile_icon", data.get("icon", 0)))
	tile_rare = str(data.get("tile_rare", "普通"))
	tile_describe = str(data.get("tile_describe", ""))
	base_color = data.get("color", base_color)
	accent_color = data.get("accent", accent_color)
	_update_description_label()
	queue_redraw()

func play_spawn() -> void:
	scale = Vector2(0.18, 0.18)
	rotation = randf_range(-0.04, 0.04)
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)

func start_idle(phase: float = 0.0) -> void:
	idle_enabled = true
	idle_phase = phase
	idle_time = 0.0
	idle_base_position = position
	set_process(true)

func _process(delta: float) -> void:
	if not idle_enabled:
		return
	idle_time += delta
	position = idle_base_position + Vector2(0.0, sin(idle_time * 1.35 + idle_phase) * 5.5)
	_layout_description_label()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		picked.emit(tile_index)

func _draw() -> void:
	var rare_color: Color = rare_colors.get(tile_rare, rare_colors["普通"])
	var rect = Rect2(Vector2.ZERO, size)
	TileCardFrame.draw_choice_frame(self, rect, rare_color)
	var font = get_theme_default_font()
	draw_string(font, Vector2(12, 30), tile_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 20, Color.WHITE)
	var tile_side = min(size.x * 0.52, size.y * 0.31)
	var tile_rect = Rect2(Vector2(size.x * 0.5 - tile_side * 0.5, 54), Vector2(tile_side, tile_side))
	TileCardFrame.draw_icon_card(self, tile_rect, base_color, max(7.0, tile_side * 0.10))
	var icon_side = tile_side * 0.84
	var icon_rect = Rect2(tile_rect.get_center() - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
	VectorTileIcon.draw_icon(self, tile_kind, tile_icon, icon_rect, base_color, accent_color)
	draw_string(font, Vector2(0, tile_rect.end.y + 27), tile_rare, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, rare_color)
	var line_y = tile_rect.end.y + 37
	draw_line(Vector2(18, line_y), Vector2(size.x - 18, line_y), Color.BLACK, 3.0)
	draw_line(Vector2(19, line_y - 1), Vector2(size.x - 19, line_y - 1), rare_color, 2.0)
	_layout_description_label()
	if hover:
		TileCardFrame.draw_rect_outline(self, rect.grow(-5.0), Color.WHITE, 4.0)

func _animate_hover(target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_description_label() -> void:
	description_text = RichTextLabel.new()
	description_text.name = "DescriptionText"
	description_text.bbcode_enabled = true
	description_text.fit_content = false
	description_text.scroll_active = false
	description_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_text.mouse_filter = Control.MOUSE_FILTER_STOP
	description_text.add_theme_font_size_override("normal_font_size", 15)
	description_text.gui_input.connect(_on_description_gui_input)
	description_text.meta_hover_started.connect(_on_description_meta_hover_started)
	description_text.meta_hover_ended.connect(_on_description_meta_hover_ended)
	add_child(description_text)

func _update_description_label() -> void:
	if description_text == null:
		return
	description_text.text = RichDescription.to_bbcode(tile_describe)
	_layout_description_label()

func _layout_description_label() -> void:
	if description_text == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var tile_side = min(size.x * 0.52, size.y * 0.31)
	var tile_bottom = 54.0 + tile_side
	var line_y = tile_bottom + 37.0
	description_text.position = Vector2(16.0, line_y + 13.0)
	description_text.size = Vector2(size.x - 32.0, max(44.0, size.y - line_y - 26.0))

func _on_description_meta_hover_started(meta) -> void:
	var value = str(meta)
	if value.begins_with("tile:"):
		reference_hovered.emit(value.substr(5), get_global_mouse_position())

func _on_description_meta_hover_ended(_meta) -> void:
	if hover:
		info_hovered.emit(tile_data, get_global_mouse_position())
	else:
		info_hidden.emit()

func _on_description_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		picked.emit(tile_index)
