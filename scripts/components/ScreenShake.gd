extends Node

var target: CanvasItem
var base_position = Vector2.ZERO
var strength = 0.0
var duration = 0.0
var elapsed = 0.0
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	set_process(false)

func shake(node: CanvasItem, amount: float = 8.0, time: float = 0.24) -> void:
	if node == null:
		return
	target = node
	base_position = target.position
	strength = amount
	duration = max(time, 0.01)
	elapsed = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if target == null:
		set_process(false)
		return
	elapsed += delta
	var left = clamp(1.0 - elapsed / duration, 0.0, 1.0)
	var offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * strength * left
	target.position = base_position + offset
	if elapsed >= duration:
		target.position = base_position
		set_process(false)
