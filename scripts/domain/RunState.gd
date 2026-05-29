extends RefCounted

const Board = preload("res://scripts/domain/Board.gd")
const DiceState = preload("res://scripts/domain/DiceState.gd")
const Tile = preload("res://scripts/domain/Tile.gd")
const GameRng = preload("res://scripts/core/GameRng.gd")

var board = Board.new()
var dice: Dictionary = {}
var relics: Array[String] = []
var buffs: Array = []
var coins: int = 0
var round_score: int = 0
var round_number: int = 1
var random_seed: int = 1
var tile_pool: Array[String] = []
var delete_count: int = 0
var fruit_counters: Dictionary = {"apple": 0, "peach": 0, "orange": 0}
var tile_definitions: Dictionary = {}
var relic_definitions: Dictionary = {}
var buff_definitions: Dictionary = {}
var rng = GameRng.new(1)
var _tile_serial: int = 1

func setup(p_tile_definitions: Dictionary, p_relic_definitions: Dictionary, p_buff_definitions: Dictionary, seed_value: int, start_tile_id: String = "T001", start_count: int = 8) -> void:
	tile_definitions = p_tile_definitions
	relic_definitions = p_relic_definitions
	buff_definitions = p_buff_definitions
	random_seed = seed_value
	rng.set_seed(seed_value)
	coins = 0
	round_score = 0
	round_number = 1
	relics.clear()
	buffs.clear()
	fruit_counters = {"apple": 0, "peach": 0, "orange": 0}
	tile_pool = []
	for id in tile_definitions.keys():
		var def: Dictionary = tile_definitions[id]
		if bool(def.get("selectable", false)):
			tile_pool.append(id)
	_tile_serial = board.setup_filled(get_tile_definition(start_tile_id), start_count, _tile_serial)
	dice = {
		"red": DiceState.new("red", 0),
		"blue": DiceState.new("blue", 2),
		"green": DiceState.new("green", 4)
	}

func begin_round(new_round_number: int) -> void:
	round_number = new_round_number
	round_score = 0
	for dice_state in dice.values():
		dice_state.begin_turn(board.size())

func begin_roll() -> void:
	for dice_state in dice.values():
		dice_state.begin_roll()

func get_tile_definition(tile_id: String) -> Dictionary:
	return tile_definitions.get(tile_id, tile_definitions.get("T000", {}))

func create_tile(tile_id: String):
	var tile = Tile.from_definition(get_tile_definition(tile_id), _tile_serial)
	_tile_serial += 1
	return tile

func add_relic(relic_id: String) -> void:
	if not relics.has(relic_id):
		relics.append(relic_id)

func add_buff(buff: Dictionary) -> void:
	buffs.append(buff)

func remove_buff(buff_instance_id: String) -> void:
	buffs = buffs.filter(func(buff): return str(buff.get("instanceId", "")) != buff_instance_id)

func get_active_buffs(dice_id: String = "") -> Array:
	var result = []
	for buff in buffs:
		if int(buff.get("remaining", 1)) == 0:
			continue
		var target_dice = str(buff.get("diceId", ""))
		if dice_id.is_empty() or target_dice.is_empty() or target_dice == dice_id:
			result.append(buff)
	return result

func has_buff(buff_id: String, dice_id: String = "") -> bool:
	for buff in get_active_buffs(dice_id):
		if str(buff.get("id", "")) == buff_id:
			return true
	return false

func cleanup_end_of_turn() -> void:
	buffs = buffs.filter(func(buff):
		var duration_type = str(buff.get("durationType", "turns"))
		if duration_type == "untilEndOfTurn":
			return false
		return int(buff.get("remaining", 1)) != 0
	)
	for tile in board.tiles:
		if bool(tile.runtime_flags.get("temporarily_destroyed", false)):
			tile.runtime_flags.erase("temporarily_destroyed")
		if bool(tile.runtime_flags.get("destroy_after_turn", false)):
			tile.runtime_flags.erase("destroy_after_turn")

func draw_tile_choices(count: int) -> Array[String]:
	var choices: Array[String] = []
	var candidates = _weighted_tile_pool()
	while choices.size() < count and not candidates.is_empty():
		var picked = rng.pick_weighted(candidates)
		if picked == null:
			break
		var tile_id = str(picked.get("id", ""))
		if not choices.has(tile_id):
			choices.append(tile_id)
		candidates.erase(picked)
	return choices

func draw_relic_choices(count: int) -> Array[String]:
	var candidates = []
	for relic_id in relic_definitions.keys():
		if relics.has(relic_id):
			continue
		var def: Dictionary = relic_definitions[relic_id]
		candidates.append({"id": relic_id, "weight": _rarity_weight(str(def.get("rarity", "普通")))})
	var choices: Array[String] = []
	while choices.size() < count and not candidates.is_empty():
		var picked = rng.pick_weighted(candidates)
		var relic_id = str(picked.get("id", ""))
		if not choices.has(relic_id):
			choices.append(relic_id)
		candidates.erase(picked)
	return choices

func _weighted_tile_pool() -> Array:
	var result = []
	for tile_id in tile_pool:
		var def = get_tile_definition(tile_id)
		var weight = _rarity_weight(str(def.get("rarity", "普通")))
		for relic_id in relics:
			var relic_def: Dictionary = relic_definitions.get(relic_id, {})
			var pool_bonus: Dictionary = relic_def.get("poolWeightBonus", {})
			for tag in def.get("tags", []):
				if pool_bonus.has(tag):
					weight *= 1.0 + float(pool_bonus[tag])
			if pool_bonus.has(str(def.get("rarity", ""))):
				weight *= 1.0 + float(pool_bonus[str(def.get("rarity", ""))])
		result.append({"id": tile_id, "weight": weight})
	return result

func _rarity_weight(rarity: String) -> float:
	match rarity:
		"普通":
			return 100.0
		"稀有":
			return 48.0
		"非凡":
			return 18.0
		"传说":
			return 7.0
		"诅咒":
			return 20.0
		_:
			return 30.0
