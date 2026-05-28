extends Node2D

var coins: Array[Dictionary] = []
var elapsed = 0.0
var duration = 0.84
var coin_color = Color(1.0, 0.86, 0.12)

func play(start_position: Vector2, end_position: Vector2, color: Color = Color(1.0, 0.86, 0.12), amount: int = 8) -> void:
	z_index = 140
	coin_color = color
	elapsed = 0.0
	coins.clear()
	for i in range(amount):
		coins.append({
			"start": start_position + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0)),
			"end": end_position + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0)),
			"delay": i * 0.035,
			"arc": randf_range(34.0, 86.0),
			"spin": randf_range(-PI, PI)
		})
	_emit_spark(start_position)
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed > duration + 0.4:
		queue_free()

func _draw() -> void:
	for coin in coins:
		var local_t = clamp((elapsed - float(coin["delay"])) / duration, 0.0, 1.0)
		if local_t <= 0.0:
			continue
		var eased = 1.0 - pow(1.0 - local_t, 3.0)
		var pos = (coin["start"] as Vector2).lerp(coin["end"] as Vector2, eased)
		pos.y -= sin(local_t * PI) * float(coin["arc"])
		var alpha = clamp(1.0 - max(0.0, local_t - 0.78) / 0.22, 0.0, 1.0)
		var radius = 7.0 + sin(local_t * TAU + float(coin["spin"])) * 1.4
		draw_circle(pos, radius + 2.0, Color(1.0, 0.55, 0.05, 0.28 * alpha))
		draw_circle(pos, radius, Color(coin_color.r, coin_color.g, coin_color.b, alpha))
		draw_arc(pos, radius * 0.58, -0.8, 0.8, 10, Color(1.0, 1.0, 1.0, 0.75 * alpha), 2.0)

func _emit_spark(start_position: Vector2) -> void:
	var particles = GPUParticles2D.new()
	particles.position = start_position
	particles.one_shot = true
	particles.amount = 36
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.z_index = 135
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0.0, -1.0, 0.0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 60.0
	particle_material.initial_velocity_max = 180.0
	particle_material.gravity = Vector3(0.0, 460.0, 0.0)
	particle_material.scale_min = 2.0
	particle_material.scale_max = 4.0
	particle_material.color = coin_color
	particles.process_material = particle_material
	add_child(particles)
	particles.emitting = true
