extends RefCounted

var seed_value: int = 1
var _rng := RandomNumberGenerator.new()

func _init(initial_seed: int = 1) -> void:
	set_seed(initial_seed)

func set_seed(new_seed: int) -> void:
	seed_value = new_seed
	_rng.seed = new_seed

func randi_range(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

func randf() -> float:
	return _rng.randf()

func pick_array(items: Array):
	if items.is_empty():
		return null
	return items[randi_range(0, items.size() - 1)]

func shuffle_copy(items: Array) -> Array:
	var result = items.duplicate(true)
	for i in range(result.size() - 1, 0, -1):
		var j = randi_range(0, i)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result

func pick_weighted(items: Array, weight_key: String = "weight"):
	var total := 0.0
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			total += max(0.0, float(item.get(weight_key, 1.0)))
	if total <= 0.0:
		return pick_array(items)
	var roll = randf() * total
	var cursor := 0.0
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		cursor += max(0.0, float(item.get(weight_key, 1.0)))
		if roll <= cursor:
			return item
	return items.back()
