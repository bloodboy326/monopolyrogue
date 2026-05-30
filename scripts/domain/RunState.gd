extends RefCounted

const Board = preload("res://scripts/domain/Board.gd")
const DiceState = preload("res://scripts/domain/DiceState.gd")
const Tile = preload("res://scripts/domain/Tile.gd")
const GameRng = preload("res://scripts/core/GameRng.gd")
const TileDefinitions = preload("res://scripts/data/TileDefinitions.gd")

var board = Board.new()
var dice: Dictionary = {}
var relics: Array[String] = []
var buffs: Array = []
var coins: int = 0
var round_score: int = 0
var round_number: int = 1
var battle_number: int = 1
var battle_turn: int = 1
var random_seed: int = 1
var tile_pool: Array[String] = []
var tile_definitions: Dictionary = {}
var relic_definitions: Dictionary = {}
var buff_definitions: Dictionary = {}
var temporary_tile_instances: Array[String] = []
var battle_reverts: Array[Dictionary] = []
var rng = GameRng.new(1)
var _tile_serial: int = 1
var delete_count: int = 0

var player_max_hp: int = 80
var player_hp: int = 80
var player_block: int = 0
var next_attack_multiplier: float = 1.0
var pending_roll_bonus: int = 0
var turn_rolls_left: int = 3
var turn_rolls_total: int = 3
var next_turn_roll_bonus: int = 0
var turn_counters: Dictionary = {}
var battle_counters: Dictionary = {}

var monster_id: String = ""
var monster_name: String = ""
var monster_max_hp: int = 1
var monster_hp: int = 1
var monster_block: int = 0
var monster_strength: int = 0
var monster_art_key: String = "slime"
var current_phase_id: String = ""
var current_intent: Dictionary = {}
var intent_history: Array[String] = []
var intent_last_used: Dictionary = {}
var entered_phases: Array[String] = []

func setup(p_tile_definitions: Dictionary, p_relic_definitions: Dictionary, p_buff_definitions: Dictionary, seed_value: int, _start_tile_id: String = "T001", _start_count: int = 6) -> void:
	tile_definitions = p_tile_definitions
	relic_definitions = p_relic_definitions
	buff_definitions = p_buff_definitions
	random_seed = seed_value
	rng.set_seed(seed_value)
	player_hp = player_max_hp
	player_block = 0
	next_attack_multiplier = 1.0
	pending_roll_bonus = 0
	delete_count = 0
	turn_rolls_left = 3
	turn_rolls_total = 3
	next_turn_roll_bonus = 0
	turn_counters.clear()
	battle_counters.clear()
	relics.clear()
	buffs.clear()
	temporary_tile_instances.clear()
	battle_reverts.clear()
	tile_pool.clear()
	for id in tile_definitions.keys():
		var def: Dictionary = tile_definitions[id]
		if bool(def.get("selectable", false)):
			tile_pool.append(id)
	_setup_starting_board(TileDefinitions.starting_deck())
	dice = {
		"red": DiceState.new("red", 0),
		"blue": DiceState.new("blue", 2),
		"green": DiceState.new("green", 4)
	}

func _setup_starting_board(tile_ids: Array[String]) -> void:
	board.tiles.clear()
	_tile_serial = 1
	for tile_id in tile_ids:
		board.tiles.append(create_tile(tile_id))

func start_battle(new_battle_number: int, monster_def: Dictionary) -> void:
	battle_number = new_battle_number
	round_number = new_battle_number
	battle_turn = 1
	player_block = 0
	next_attack_multiplier = 1.0
	pending_roll_bonus = 0
	delete_count = 0
	turn_counters.clear()
	battle_counters.clear()
	next_turn_roll_bonus = 0
	temporary_tile_instances.clear()
	battle_reverts.clear()
	monster_id = str(monster_def.get("monster_id", "slime_boss"))
	monster_name = str(monster_def.get("name", monster_id))
	monster_max_hp = int(monster_def.get("max_hp", 80))
	monster_hp = monster_max_hp
	monster_block = 0
	monster_strength = 0
	monster_art_key = str(monster_def.get("art_key", "slime"))
	current_phase_id = str(monster_def.get("start_phase", ""))
	current_intent.clear()
	intent_history.clear()
	intent_last_used.clear()
	entered_phases.clear()
	for dice_state in dice.values():
		dice_state.begin_turn(board.size())

func begin_player_turn(base_rolls: int = -1) -> void:
	player_block = 0
	pending_roll_bonus = 0
	turn_counters.clear()
	if base_rolls >= 0:
		turn_rolls_total = max(0, base_rolls + next_turn_roll_bonus)
		turn_rolls_left = turn_rolls_total
		next_turn_roll_bonus = 0
	for dice_state in dice.values():
		dice_state.begin_turn(board.size())

func begin_roll() -> void:
	for dice_state in dice.values():
		dice_state.begin_roll()

func set_roll_budget(left: int, total: int) -> void:
	turn_rolls_left = max(0, left)
	turn_rolls_total = max(1, total)

func spend_roll() -> bool:
	if turn_rolls_left <= 0:
		return false
	turn_rolls_left -= 1
	return true

func adjust_rolls(amount: int) -> void:
	turn_rolls_left = max(0, turn_rolls_left + amount)
	if amount > 0:
		turn_rolls_total += amount

func add_next_turn_roll_bonus(amount: int) -> void:
	next_turn_roll_bonus += amount

func increment_counter(scope: String, counter_key: String, amount: int = 1) -> int:
	var store = _counter_store(scope)
	store[counter_key] = int(store.get(counter_key, 0)) + amount
	return int(store[counter_key])

func get_counter(scope: String, counter_key: String) -> int:
	return int(_counter_store(scope).get(counter_key, 0))

func _counter_store(scope: String) -> Dictionary:
	if scope == "battle":
		return battle_counters
	return turn_counters

func get_tile_definition(tile_id: String) -> Dictionary:
	return tile_definitions.get(tile_id, tile_definitions.get("T000", {}))

func create_tile(tile_id: String):
	var tile = Tile.from_definition(get_tile_definition(tile_id), _tile_serial)
	_tile_serial += 1
	return tile

func register_temporary_tile(tile) -> void:
	if tile == null:
		return
	tile.runtime_flags["temporary_tile"] = true
	if not temporary_tile_instances.has(tile.instance_id):
		temporary_tile_instances.append(tile.instance_id)

func forget_temporary_tile(instance_id: String) -> void:
	temporary_tile_instances.erase(instance_id)

func remember_battle_revert(new_instance_id: String, original_tile_id: String) -> void:
	for item in battle_reverts:
		if str(item.get("instance_id", "")) == new_instance_id:
			return
	battle_reverts.append({"instance_id": new_instance_id, "original_tile_id": original_tile_id})

func reindex_dice_after_insert(insert_index: int) -> void:
	for dice_state in dice.values():
		if dice_state.index >= insert_index:
			dice_state.index += 1

func reindex_dice_after_remove(removed_index: int) -> void:
	for dice_state in dice.values():
		if dice_state.index > removed_index:
			dice_state.index -= 1
		elif dice_state.index == removed_index and board.size() > 0:
			dice_state.index = board.normalize_index(removed_index)

func cleanup_battle_reverts() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for item in battle_reverts.duplicate(true):
		var instance_id = str(item.get("instance_id", ""))
		var index = board.find_tile_index_by_instance(instance_id)
		if index == -1:
			continue
		var old_tile = board.get_tile(index)
		var original_id = str(item.get("original_tile_id", "T000"))
		var restored = create_tile(original_id)
		board.set_tile(index, restored)
		events.append({
			"type": "tile_transformed",
			"tileIndex": index,
			"fromTileId": old_tile.id,
			"toTileId": restored.id,
			"fromTileInstanceId": old_tile.instance_id,
			"toTileInstanceId": restored.instance_id
		})
	battle_reverts.clear()
	return events

func cleanup_battle_temporary_tiles() -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	for instance_id in temporary_tile_instances.duplicate():
		var index = board.find_tile_index_by_instance(instance_id)
		if index == -1:
			continue
		var tile = board.remove_tile(index)
		if tile == null:
			continue
		removed.append({"type": "temporary_tile_removed", "tileIndex": index, "tileId": tile.id, "tileInstanceId": tile.instance_id})
		reindex_dice_after_remove(index)
	temporary_tile_instances.clear()
	return removed

func cleanup_round_temporary_tiles() -> Array[Dictionary]:
	var events = cleanup_battle_reverts()
	events.append_array(cleanup_battle_temporary_tiles())
	return events

func cleanup_round_buffs() -> void:
	buffs.clear()

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

func cleanup_end_of_turn() -> void:
	buffs.clear()

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

func draw_relic_choices(_count: int) -> Array[String]:
	return []

func is_monster_intent_attack() -> bool:
	return str(current_intent.get("intent_type", "")) == "ATTACK"

func consume_next_attack_multiplier() -> float:
	var multiplier = max(1.0, next_attack_multiplier)
	next_attack_multiplier = 1.0
	return multiplier

func apply_player_damage(amount: int) -> Dictionary:
	var blocked = min(player_block, max(0, amount))
	player_block -= blocked
	var damage = max(0, amount - blocked)
	player_hp = max(0, player_hp - damage)
	return {"amount": damage, "blocked": blocked, "raw": amount, "playerHp": player_hp, "playerBlock": player_block}

func record_current_intent_used() -> void:
	var intent_id = str(current_intent.get("intent_id", ""))
	if intent_id.is_empty():
		return
	intent_history.append(intent_id)
	intent_last_used[intent_id] = battle_turn

func pick_corruptible_tile_index() -> int:
	var candidates: Array[int] = []
	for i in range(board.size()):
		var tile = board.get_tile(i)
		if tile == null:
			continue
		if tile.id in ["T000", "T010", "T901"]:
			continue
		if bool(tile.runtime_flags.get("temporary_tile", false)):
			continue
		candidates.append(i)
	if candidates.is_empty():
		return -1
	return int(rng.pick_array(candidates))

func _weighted_tile_pool() -> Array:
	var result = []
	for tile_id in tile_pool:
		var def = get_tile_definition(tile_id)
		result.append({"id": tile_id, "weight": _rarity_weight(str(def.get("rarity", "普通")))})
	return result

func _rarity_weight(rarity: String) -> float:
	match rarity:
		"普通":
			return 100.0
		"稀有":
			return 35.0
		"非凡":
			return 12.0
		"诅咒":
			return 0.0
		"基础牌":
			return 0.0
		_:
			return 20.0
