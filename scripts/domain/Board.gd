extends RefCounted

const Tile = preload("res://scripts/domain/Tile.gd")

var tiles: Array = []

func setup_filled(tile_definition: Dictionary, count: int, serial_start: int = 1) -> int:
	tiles.clear()
	var serial = serial_start
	for i in range(count):
		tiles.append(Tile.from_definition(tile_definition, serial))
		serial += 1
	return serial

func size() -> int:
	return tiles.size()

func is_empty() -> bool:
	return tiles.is_empty()

func normalize_index(index: int) -> int:
	if tiles.is_empty():
		return 0
	return posmod(index, tiles.size())

func get_tile(index: int):
	if tiles.is_empty():
		return null
	return tiles[normalize_index(index)]

func set_tile(index: int, tile) -> void:
	if tiles.is_empty():
		tiles.append(tile)
		return
	tiles[normalize_index(index)] = tile

func insert_tile(index: int, tile) -> void:
	tiles.insert(clamp(index, 0, tiles.size()), tile)

func remove_tile(index: int):
	if tiles.is_empty():
		return null
	return tiles.pop_at(normalize_index(index))

func find_tile_index_by_instance(instance_id: String) -> int:
	for i in range(tiles.size()):
		if tiles[i].instance_id == instance_id:
			return i
	return -1

func find_empty_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(tiles.size()):
		if tiles[i].is_empty():
			result.append(i)
	return result

func find_indices_by_tag(tag: String) -> Array[int]:
	var result: Array[int] = []
	for i in range(tiles.size()):
		if tiles[i].has_tag(tag):
			result.append(i)
	return result

func to_display_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tile in tiles:
		result.append(tile.to_display_data())
	return result
