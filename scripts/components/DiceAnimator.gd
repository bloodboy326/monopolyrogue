extends Control

signal roll_finished

var dice_color = Color.RED
var value = 1
var rolling = false
var shockwave = 0.0
var rng = RandomNumberGenerator.new()
var animation_player: AnimationPlayer
var roll_target = 1
var face_elapsed = 0.0
var roll_origin = Vector2.ZERO

func configure(new_color: Color, start_value: int = 1) -> void:
	dice_color = new_color
	value = start_value
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	rng.randomize()
	set_process(false)
	animation_player = AnimationPlayer.new()
	animation_player.root_node = NodePath("..")
	add_child(animation_player)
	_build_idle_animation()
	animation_player.play("idle")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func roll_to(final_value: int) -> void:
	rolling = true
	roll_target = final_value
	face_elapsed = 0.0
	roll_origin = position
	animation_player.stop()
	var spin = create_tween()
	spin.set_parallel(true)
	spin.tween_property(self, "rotation", rotation + TAU * 1.8, 0.68).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	spin.tween_property(self, "scale", Vector2(1.24, 1.24), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spin.tween_property(self, "scale", Vector2(0.92, 0.92), 0.1).set_delay(0.12)
	spin.tween_property(self, "scale", Vector2(1.08, 1.08), 0.13).set_delay(0.22)
	spin.tween_property(self, "modulate:a", 0.42, 0.04).set_delay(0.08)
	spin.tween_property(self, "modulate:a", 1.0, 0.04).set_delay(0.13)
	spin.tween_property(self, "modulate:a", 0.56, 0.04).set_delay(0.22)
	spin.tween_property(self, "modulate:a", 1.0, 0.04).set_delay(0.27)
	spin.finished.connect(_on_spin_finished)
	set_process(true)

func _process(delta: float) -> void:
	if not rolling:
		return
	face_elapsed += delta
	if face_elapsed >= 0.045:
		face_elapsed = 0.0
		value = rng.randi_range(1, 6)
		position = roll_origin + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		queue_redraw()

func _on_spin_finished() -> void:
	value = roll_target
	rolling = false
	set_process(false)
	position = roll_origin
	rotation = 0.0
	_play_settle()

func _play_settle() -> void:
	_emit_particles()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.28, 0.78), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_delay(0.08).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_shockwave, 0.0, 1.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		animation_player.play("idle")
		roll_finished.emit()
	)

func _set_shockwave(value_in: float) -> void:
	shockwave = value_in
	queue_redraw()

func _emit_particles() -> void:
	var particles = GPUParticles2D.new()
	particles.position = size * 0.5
	particles.one_shot = true
	particles.amount = 28
	particles.lifetime = 0.42
	particles.explosiveness = 1.0
	particles.z_index = 130
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0.0, -1.0, 0.0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 80.0
	particle_material.initial_velocity_max = 170.0
	particle_material.gravity = Vector3(0.0, 420.0, 0.0)
	particle_material.scale_min = 2.0
	particle_material.scale_max = 5.0
	particle_material.color = dice_color.lightened(0.28)
	particles.process_material = particle_material
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _build_idle_animation() -> void:
	var library = AnimationLibrary.new()
	var animation = Animation.new()
	animation.length = 1.4
	animation.loop_mode = Animation.LOOP_LINEAR
	var track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(".:scale"))
	animation.track_insert_key(track, 0.0, Vector2.ONE)
	animation.track_insert_key(track, 0.7, Vector2(1.035, 1.035))
	animation.track_insert_key(track, 1.4, Vector2.ONE)
	library.add_animation("idle", animation)
	animation_player.add_animation_library("", library)

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var min_side = min(size.x, size.y)
	var radius = min_side * 0.18
	_draw_rounded_box(Rect2(Vector2(5.0, 6.0), size), radius, Color(0.0, 0.0, 0.0, 0.34))
	_draw_rounded_box(rect, radius, Color(0.0, 0.0, 0.0, 1.0))
	_draw_rounded_box(rect.grow(-5.0), radius * 0.75, dice_color)
	draw_line(Vector2(size.x * 0.20, size.y * 0.18), Vector2(size.x * 0.66, size.y * 0.18), Color(1.0, 1.0, 1.0, 0.24 + (0.16 if rolling else 0.0)), 4.0)
	draw_line(Vector2(size.x * 0.18, size.y * 0.76), Vector2(size.x * 0.70, size.y * 0.76), dice_color.lightened(0.32), 4.0)
	_draw_pips()
	if shockwave > 0.0 and shockwave < 1.0:
		var alpha = 1.0 - shockwave
		var wave_color = Color(1.0, 0.92, 0.28, 1.0)
		wave_color.a = alpha * 0.55
		draw_arc(size * 0.5, min_side * (0.35 + shockwave * 0.42), 0.0, TAU, 5, wave_color, 5.0)

func _draw_pips() -> void:
	var points = {
		1: [Vector2(0.5, 0.5)],
		2: [Vector2(0.32, 0.32), Vector2(0.68, 0.68)],
		3: [Vector2(0.32, 0.32), Vector2(0.5, 0.5), Vector2(0.68, 0.68)],
		4: [Vector2(0.32, 0.32), Vector2(0.68, 0.32), Vector2(0.32, 0.68), Vector2(0.68, 0.68)],
		5: [Vector2(0.32, 0.32), Vector2(0.68, 0.32), Vector2(0.5, 0.5), Vector2(0.32, 0.68), Vector2(0.68, 0.68)],
		6: [Vector2(0.32, 0.28), Vector2(0.68, 0.28), Vector2(0.32, 0.5), Vector2(0.68, 0.5), Vector2(0.32, 0.72), Vector2(0.68, 0.72)]
	}
	for point in points[value]:
		draw_circle(point * size, min(size.x, size.y) * 0.070, Color(0.0, 0.0, 0.0, 1.0))
		draw_circle(point * size - Vector2(1.5, 1.5), min(size.x, size.y) * 0.030, Color.WHITE)

func _draw_rounded_box(rect: Rect2, radius: float, color: Color) -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	var corner = int(max(0.0, radius))
	box.corner_radius_top_left = corner
	box.corner_radius_top_right = corner
	box.corner_radius_bottom_left = corner
	box.corner_radius_bottom_right = corner
	draw_style_box(box, rect)
