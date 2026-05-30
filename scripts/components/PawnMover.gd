extends Node2D

signal step_landed(tile_index: int, final_step: bool)
signal movement_finished(final_index: int)

const MOVE_TIME_SCALE = 1.0 / 1.5

var pawn_color = Color.RED
var label = "R"
var wobble = 0.0
var shadow_scale = 1.0
var path_points: Array[Vector2] = []
var current_index = 0
var steps_left = 0

func configure(new_color: Color, new_label: String) -> void:
	pawn_color = new_color
	label = new_label
	queue_redraw()

func _ready() -> void:
	z_index = 70
	set_process(true)

func _process(delta: float) -> void:
	wobble += delta
	queue_redraw()

func move_steps(points: Array[Vector2], start_index: int, steps: int) -> void:
	if points.is_empty() or steps <= 0:
		movement_finished.emit(start_index)
		return
	path_points = points.duplicate()
	current_index = start_index
	steps_left = steps
	_advance_one_step()

func _advance_one_step() -> void:
	if steps_left <= 0:
		movement_finished.emit(current_index)
		return
	current_index = (current_index + 1) % path_points.size()
	var final_step = steps_left == 1
	_hop_to(path_points[current_index], final_step)

func _hop_to(destination: Vector2, final_step: bool) -> void:
	var start = position
	var height = 34.0 if final_step else 24.0
	var duration = (0.24 if final_step else 0.18) * MOVE_TIME_SCALE
	var tween = create_tween()
	tween.tween_method(_set_hop.bind(start, destination, height), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		_play_squash(final_step)
	)

func _play_squash(final_step: bool) -> void:
	var squash_in = 0.06 * MOVE_TIME_SCALE
	var squash_out = 0.16 * MOVE_TIME_SCALE
	var squash = create_tween()
	squash.set_parallel(true)
	squash.tween_property(self, "scale", Vector2(1.22, 0.78), squash_in)
	squash.tween_property(self, "scale", Vector2(1.0, 1.0), squash_out).set_delay(squash_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	squash.finished.connect(func() -> void:
		step_landed.emit(current_index, final_step)
		steps_left -= 1
		if final_step:
			movement_finished.emit(current_index)
		else:
			_advance_one_step()
	)

func _set_hop(t: float, start: Vector2, destination: Vector2, height: float) -> void:
	position = start.lerp(destination, t) + Vector2(0.0, -sin(t * PI) * height)
	shadow_scale = 1.0 - sin(t * PI) * 0.22
	queue_redraw()

func play_final_pop() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.38, 1.38), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_delay(0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	draw_circle(Vector2(0.0, 20.0), 16.0 * shadow_scale, Color(0.0, 0.0, 0.0, 0.24))
	var body_y = sin(wobble * 5.0) * 1.8
	draw_circle(Vector2(0, body_y), 20.0, Color(0.0, 0.0, 0.0, 1.0))
	draw_circle(Vector2(-2, body_y - 3), 15.0, pawn_color)
	draw_circle(Vector2(-8, body_y - 9), 4.0, Color(1.0, 1.0, 1.0, 0.72))
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(-12.0, body_y + 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, 24.0, 17, Color(0.05, 0.03, 0.08, 1.0))
