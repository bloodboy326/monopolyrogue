extends RefCounted

const Board = preload("res://scripts/domain/Board.gd")
const DiceState = preload("res://scripts/domain/DiceState.gd")
const Tile = preload("res://scripts/domain/Tile.gd")
const GameRng = preload("res://scripts/core/GameRng.gd")
const TileDefinitions = preload("res://scripts/data/TileDefinitions.gd")
const SHOP_REMOVE_PRICES = [75, 100, 125, 175, 225]

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
var battle_removed_tiles: Array[Dictionary] = []
var turn_start_tile_spawns: Array[Dictionary] = []
var rng = GameRng.new(1)
var _tile_serial: int = 1
var delete_count: int = 0
var shop_remove_count: int = 0

var player_max_hp: int = 80
var player_hp: int = 80
var player_block: int = 0
var player_strength: int = 0
var player_dexterity: int = 0
var next_attack_multiplier: float = 1.0
var pending_roll_bonus: int = 0
var turn_rolls_left: int = 3
var turn_rolls_total: int = 3
var next_turn_roll_bonus: int = 0
var roll_start_bonus: int = 0
var all_pawns_next_rolls: int = 0
var next_turn_locked_dice_count: int = 0
var locked_dice: Array[String] = []
var dice_range_min: int = 1
var dice_range_max: int = 6
var dice_range_turns_left: int = 0
var dice_fog_turns_left: int = 0
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
var enemy_units: Array[Dictionary] = []
var selected_enemy_index: int = 0

func setup(p_tile_definitions: Dictionary, p_relic_definitions: Dictionary, p_buff_definitions: Dictionary, seed_value: int, _start_tile_id: String = "T001", _start_count: int = 6) -> void:
	tile_definitions = p_tile_definitions
	relic_definitions = p_relic_definitions
	buff_definitions = p_buff_definitions
	random_seed = seed_value
	rng.set_seed(seed_value)
	player_hp = player_max_hp
	coins = 0
	player_block = 0
	player_strength = 0
	player_dexterity = 0
	next_attack_multiplier = 1.0
	pending_roll_bonus = 0
	delete_count = 0
	shop_remove_count = 0
	turn_rolls_left = 3
	turn_rolls_total = 3
	next_turn_roll_bonus = 0
	roll_start_bonus = 0
	all_pawns_next_rolls = 0
	next_turn_locked_dice_count = 0
	locked_dice.clear()
	dice_range_min = 1
	dice_range_max = 6
	dice_range_turns_left = 0
	dice_fog_turns_left = 0
	turn_counters.clear()
	battle_counters.clear()
	relics.clear()
	buffs.clear()
	temporary_tile_instances.clear()
	battle_reverts.clear()
	battle_removed_tiles.clear()
	turn_start_tile_spawns.clear()
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
	cleanup_round_temporary_tiles()
	battle_number = new_battle_number
	round_number = new_battle_number
	battle_turn = 1
	player_block = 0
	next_attack_multiplier = 1.0
	player_strength = 0
	player_dexterity = 0
	pending_roll_bonus = 0
	delete_count = 0
	turn_counters.clear()
	battle_counters.clear()
	next_turn_roll_bonus = 0
	roll_start_bonus = 0
	all_pawns_next_rolls = 0
	next_turn_locked_dice_count = 0
	locked_dice.clear()
	dice_range_min = 1
	dice_range_max = 6
	dice_range_turns_left = 0
	dice_fog_turns_left = 0
	temporary_tile_instances.clear()
	battle_reverts.clear()
	battle_removed_tiles.clear()
	turn_start_tile_spawns.clear()
	_reset_battle_tile_state()
	_assign_battle_restore_slots()
	_setup_enemy_units(monster_def)
	for dice_state in dice.values():
		dice_state.begin_turn(board.size())

func _setup_enemy_units(monster_def: Dictionary) -> void:
	enemy_units.clear()
	var raw_units: Array = monster_def.get("units", [])
	if raw_units.is_empty():
		raw_units = [monster_def]
	for raw_unit in raw_units.slice(0, 3):
		if typeof(raw_unit) != TYPE_DICTIONARY:
			continue
		var unit := {
			"monster_id": str(raw_unit.get("monster_id", monster_def.get("monster_id", "slime"))),
			"name": str(raw_unit.get("name", monster_def.get("name", "怪物"))),
			"max_hp": int(raw_unit.get("max_hp", monster_def.get("max_hp", 80))),
			"hp": int(raw_unit.get("hp", raw_unit.get("max_hp", monster_def.get("max_hp", 80)))),
			"block": 0,
			"strength": 0,
			"art_key": str(raw_unit.get("art_key", monster_def.get("art_key", "slime"))),
			"passive": raw_unit.get("passive", monster_def.get("passive", {})).duplicate(true),
			"start_phase": str(raw_unit.get("start_phase", monster_def.get("start_phase", ""))),
			"current_phase_id": str(raw_unit.get("start_phase", monster_def.get("start_phase", ""))),
			"current_intent": {},
			"intent_history": [],
			"intent_last_used": {},
			"entered_phases": []
		}
		enemy_units.append(unit)
	if enemy_units.is_empty():
		enemy_units.append({
			"monster_id": "slime",
			"name": "怪物",
			"max_hp": 80,
			"hp": 80,
			"block": 0,
			"strength": 0,
			"art_key": "slime",
			"passive": {},
			"start_phase": "",
			"current_phase_id": "",
			"current_intent": {},
			"intent_history": [],
			"intent_last_used": {},
			"entered_phases": []
		})
	selected_enemy_index = first_alive_enemy_index()
	_sync_monster_alias()

func _sync_monster_alias() -> void:
	var index = selected_enemy_index
	if index < 0 or index >= enemy_units.size() or int(enemy_units[index].get("hp", 0)) <= 0:
		index = first_alive_enemy_index()
	selected_enemy_index = max(0, index)
	if selected_enemy_index >= enemy_units.size():
		return
	var unit: Dictionary = enemy_units[selected_enemy_index]
	monster_id = str(unit.get("monster_id", ""))
	monster_name = str(unit.get("name", monster_id))
	monster_max_hp = int(unit.get("max_hp", 1))
	monster_hp = int(unit.get("hp", 0))
	monster_block = int(unit.get("block", 0))
	monster_strength = int(unit.get("strength", 0))
	monster_art_key = str(unit.get("art_key", "slime"))
	current_phase_id = str(unit.get("current_phase_id", ""))
	current_intent = unit.get("current_intent", {})
	intent_history.clear()
	for item in unit.get("intent_history", []):
		intent_history.append(str(item))
	intent_last_used = unit.get("intent_last_used", {})
	entered_phases.clear()
	for item in unit.get("entered_phases", []):
		entered_phases.append(str(item))

func first_alive_enemy_index() -> int:
	for i in range(enemy_units.size()):
		if int(enemy_units[i].get("hp", 0)) > 0:
			return i
	return 0

func alive_enemy_count() -> int:
	var count = 0
	for unit in enemy_units:
		if int(unit.get("hp", 0)) > 0:
			count += 1
	return count

func needs_damage_target_choice() -> bool:
	return alive_enemy_count() > 1

func is_dice_locked(dice_id: String) -> bool:
	return locked_dice.has(dice_id)

func is_dice_fogged() -> bool:
	return dice_fog_turns_left > 0

func roll_die_value() -> int:
	return rng.randi_range(dice_range_min, dice_range_max)

func set_forced_roll_range(min_value: int, max_value: int, turns: int) -> Dictionary:
	dice_range_min = clamp(min_value, 1, 6)
	dice_range_max = clamp(max_value, dice_range_min, 6)
	dice_range_turns_left = max(dice_range_turns_left, max(0, turns))
	return {"type": "dice_range_changed", "min": dice_range_min, "max": dice_range_max, "turns": dice_range_turns_left}

func set_dice_fog(turns: int) -> Dictionary:
	dice_fog_turns_left = max(dice_fog_turns_left, max(0, turns))
	return {"type": "dice_fog_changed", "turns": dice_fog_turns_left}

func end_player_turn_statuses() -> void:
	if dice_range_turns_left > 0:
		dice_range_turns_left -= 1
		if dice_range_turns_left <= 0:
			dice_range_min = 1
			dice_range_max = 6
	if dice_fog_turns_left > 0:
		dice_fog_turns_left -= 1

func alive_enemy_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(enemy_units.size()):
		if int(enemy_units[i].get("hp", 0)) > 0:
			result.append(i)
	return result

func begin_player_turn(base_rolls: int = -1) -> void:
	player_block = 0
	pending_roll_bonus = 0
	turn_counters.clear()
	locked_dice.clear()
	if base_rolls >= 0:
		turn_rolls_total = max(0, base_rolls + next_turn_roll_bonus)
		turn_rolls_left = turn_rolls_total
		next_turn_roll_bonus = 0
	if next_turn_locked_dice_count > 0:
		var dice_ids = dice.keys()
		while locked_dice.size() < min(next_turn_locked_dice_count, max(0, dice_ids.size() - 1)) and not dice_ids.is_empty():
			var picked = str(rng.pick_array(dice_ids))
			locked_dice.append(picked)
			dice_ids.erase(picked)
		next_turn_locked_dice_count = 0
	for dice_state in dice.values():
		dice_state.begin_turn(board.size())

func begin_monster_turn() -> void:
	monster_block = 0
	for i in range(enemy_units.size()):
		enemy_units[i]["block"] = 0
	_sync_monster_alias()

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

func tile_id_for_name(tile_name: String, fallback: String = "T000") -> String:
	for tile_id in tile_definitions.keys():
		var definition: Dictionary = tile_definitions[tile_id]
		if str(definition.get("name", "")) == tile_name:
			return str(tile_id)
	return fallback

func create_tile(tile_id: String):
	var tile = Tile.from_definition(get_tile_definition(tile_id), _tile_serial)
	_tile_serial += 1
	return tile

func _reset_battle_tile_state() -> void:
	for tile in board.tiles:
		if tile != null:
			tile.reset_battle_state()

func _assign_battle_restore_slots() -> void:
	var slot = 0
	for tile in board.tiles:
		if tile == null:
			continue
		if bool(tile.runtime_flags.get("temporary_tile", false)):
			continue
		tile.runtime_flags["battle_restore_slot"] = slot
		slot += 1

func should_cleanup_after_battle(tile) -> bool:
	if tile == null:
		return false
	return bool(tile.definition.get("destroy_after_battle", false)) or bool(tile.definition.get("temporary", false))

func register_temporary_tile(tile) -> void:
	if tile == null:
		return
	tile.runtime_flags["temporary_tile"] = true
	if not temporary_tile_instances.has(tile.instance_id):
		temporary_tile_instances.append(tile.instance_id)

func forget_temporary_tile(instance_id: String) -> void:
	temporary_tile_instances.erase(instance_id)

func consume_tile_durability(tile_index: int, instance_id: String) -> Dictionary:
	var index = board.find_tile_index_by_instance(instance_id)
	if index == -1:
		index = board.normalize_index(tile_index) if not board.is_empty() else -1
	if index == -1:
		return {}
	var tile = board.get_tile(index)
	if tile == null or tile.max_durability() <= 0 or tile.is_weak():
		return {}
	var remaining = max(0, tile.durability_remaining() - 1)
	tile.state["durability"] = remaining
	if remaining <= 0:
		tile.runtime_flags["weak"] = true
	return {"type": "tile_durability_changed", "tileIndex": index, "tileId": tile.id, "tileInstanceId": tile.instance_id, "durability": remaining, "maxDurability": tile.max_durability(), "weak": tile.is_weak()}

func add_durability_to_all(amount: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for index in range(board.size()):
		var tile = board.get_tile(index)
		if tile == null or tile.max_durability() <= 0:
			continue
		var current = tile.durability_remaining()
		var next_value = max(0, current + amount)
		tile.state["durability"] = next_value
		if next_value > 0:
			tile.runtime_flags.erase("weak")
		else:
			tile.runtime_flags["weak"] = true
		events.append({"type": "tile_durability_changed", "tileIndex": index, "tileId": tile.id, "tileInstanceId": tile.instance_id, "durability": next_value, "maxDurability": tile.max_durability(), "weak": tile.is_weak()})
	return events

func add_turn_start_tile_spawn(tile_id: String, count: int = 1) -> void:
	if tile_id.is_empty() or count <= 0:
		return
	turn_start_tile_spawns.append({"tileId": tile_id, "count": count})

func apply_turn_start_tile_spawns() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for spawn in turn_start_tile_spawns:
		var count = max(0, int(spawn.get("count", 1)))
		var tile_id = str(spawn.get("tileId", "T000"))
		for _i in range(count):
			events.append(_generate_runtime_tile(tile_id))
	return events

func apply_turn_start_durability_curses() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var weakness_tile_id = tile_id_for_name("虚弱", "T080")
	var weakness_count = count_tiles_by_id(weakness_tile_id)
	if weakness_count <= 0:
		return events
	for _curse in range(weakness_count):
		for index in range(board.size()):
			var tile = board.get_tile(index)
			if tile == null or tile.id == weakness_tile_id or tile.max_durability() <= 0:
				continue
			var remaining = max(0, tile.durability_remaining() - 1)
			tile.state["durability"] = remaining
			if remaining <= 0:
				tile.runtime_flags["weak"] = true
			events.append({"type": "tile_durability_changed", "tileIndex": index, "tileId": tile.id, "tileInstanceId": tile.instance_id, "durability": remaining, "maxDurability": tile.max_durability(), "weak": tile.is_weak()})
	return events

func apply_relic_battle_start() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for relic_id in relics:
		var relic: Dictionary = relic_definitions.get(relic_id, {})
		for effect in relic.get("effects", []):
			match str(effect.get("type", "")):
				"battle_start_tile":
					for _i in range(max(0, int(effect.get("count", 1)))):
						events.append(_generate_runtime_tile(str(effect.get("tile", "T000"))))
				"battle_start_strength":
					player_strength += int(effect.get("amount", 0))
					events.append({"type": "player_strength_added", "amount": int(effect.get("amount", 0)), "strength": player_strength, "sourceId": relic_id, "sourceIndex": -1})
				"battle_start_dexterity":
					player_dexterity += int(effect.get("amount", 0))
					events.append({"type": "player_dexterity_added", "amount": int(effect.get("amount", 0)), "dexterity": player_dexterity, "sourceId": relic_id, "sourceIndex": -1})
	return events

func apply_relic_turn_start() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for relic_id in relics:
		var relic: Dictionary = relic_definitions.get(relic_id, {})
		for effect in relic.get("effects", []):
			match str(effect.get("type", "")):
				"turn_start_rolls":
					if effect.has("turn") and int(effect.get("turn", 1)) != battle_turn:
						continue
					var amount = int(effect.get("amount", 1))
					adjust_rolls(amount)
					events.append({"type": "rolls_added", "amount": amount, "sourceId": relic_id, "sourceIndex": -1, "rollsLeft": turn_rolls_left, "rollsTotal": turn_rolls_total})
				"turn_interval_rolls":
					var interval = max(1, int(effect.get("interval", 1)))
					if battle_turn % interval != 0:
						continue
					var interval_amount = int(effect.get("amount", 1))
					adjust_rolls(interval_amount)
					events.append({"type": "rolls_added", "amount": interval_amount, "sourceId": relic_id, "sourceIndex": -1, "rollsLeft": turn_rolls_left, "rollsTotal": turn_rolls_total})
				"turn_start_block":
					if int(effect.get("turn", 1)) != battle_turn:
						continue
					var block_amount = int(effect.get("amount", 0))
					player_block += block_amount
					events.append({"type": "player_block_added", "amount": block_amount, "sourceId": relic_id, "sourceIndex": -1, "turnTotal": player_block})
	return events

func apply_roll_passive_relics() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var roll_count = get_counter("battle", "player_rolls")
	for relic_id in relics:
		var relic: Dictionary = relic_definitions.get(relic_id, {})
		for effect in relic.get("effects", []):
			match str(effect.get("type", "")):
				"dice_roll_energy":
					var threshold = max(1, int(effect.get("threshold", 10)))
					if roll_count > 0 and roll_count % threshold == 0:
						var amount = int(effect.get("amount", 1))
						adjust_rolls(amount)
						events.append({"type": "rolls_added", "amount": amount, "sourceId": relic_id, "sourceIndex": -1, "rollsLeft": turn_rolls_left, "rollsTotal": turn_rolls_total})
				"dice_roll_hp_loss":
					var hp_threshold = max(1, int(effect.get("threshold", 10)))
					if roll_count > 0 and roll_count % hp_threshold == 0:
						var result = apply_player_damage(int(effect.get("amount", 1)))
						events.append({"type": "player_damaged", "amount": int(result["amount"]), "blocked": int(result["blocked"]), "raw": int(result["raw"]), "sourceId": relic_id, "sourceIndex": -1})
	var storm = get_counter("battle", "stray_bullet_storm")
	if storm > 0:
		var storm_source_id = tile_id_for_name("流弹风暴", "T078")
		for unit_index in alive_enemy_indices():
			events.append(apply_monster_damage_to_unit(unit_index, storm * 2, storm_source_id, -1, ""))
	return events

func record_attack_trigger() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var attack_count = increment_counter("turn", "player_attack_count", 1)
	if has_relic("R012") and attack_count % 3 == 0:
		player_strength += 1
		events.append({"type": "player_strength_added", "amount": 1, "strength": player_strength, "sourceId": "R012", "sourceIndex": -1})
	return events

func record_warp_trigger() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var warp_count = increment_counter("turn", "warp_count", 1)
	if has_relic("R011") and warp_count % 3 == 0:
		adjust_rolls(1)
		events.append({"type": "rolls_added", "amount": 1, "sourceId": "R011", "sourceIndex": -1, "rollsLeft": turn_rolls_left, "rollsTotal": turn_rolls_total})
	return events

func record_durability_consumed() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var consumed = increment_counter("battle", "durability_consumed", 1)
	if has_relic("R010") and consumed % 10 == 0:
		events.append_array(add_durability_to_all(1))
	return events

func add_converge_to_random_tiles(count: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var candidates: Array[int] = []
	for index in range(board.size()):
		var tile = board.get_tile(index)
		if tile == null or tile.is_empty() or tile.has_tag("curse") or tile.has_tile_buff("converge") or bool(tile.runtime_flags.get("converge", false)):
			continue
		candidates.append(index)
	while events.size() < count and not candidates.is_empty():
		var picked = int(rng.pick_array(candidates))
		candidates.erase(picked)
		var tile = board.get_tile(picked)
		tile.add_tile_buff({
			"id": "converge",
			"name": "汇聚",
			"icon": "converge",
			"durationType": "battle",
			"remaining": 1,
			"description": "本场战斗内，踩中该地块时额外获得1点能量"
		})
		tile.runtime_flags["converge"] = true
		events.append({"type": "tile_enhanced", "tileIndex": picked, "tileId": tile.id, "tileInstanceId": tile.instance_id, "enhancement": "converge"})
	return events

func set_tile_weak(tile_index: int, instance_id: String) -> Dictionary:
	var index = board.find_tile_index_by_instance(instance_id)
	if index == -1:
		index = board.normalize_index(tile_index) if not board.is_empty() else -1
	if index == -1:
		return {}
	var tile = board.get_tile(index)
	if tile == null or tile.max_durability() <= 0:
		return {}
	tile.state["durability"] = 0
	tile.runtime_flags["weak"] = true
	return {"type": "tile_durability_changed", "tileIndex": index, "tileId": tile.id, "tileInstanceId": tile.instance_id, "durability": 0, "maxDurability": tile.max_durability(), "weak": true}

func _generate_runtime_tile(tile_id: String) -> Dictionary:
	var tile = create_tile(tile_id)
	var insert_at = rng.randi_range(0, board.size())
	board.insert_tile(insert_at, tile)
	reindex_dice_after_insert(insert_at)
	if should_cleanup_after_battle(tile):
		register_temporary_tile(tile)
	else:
		register_persistent_battle_tile(tile, insert_at)
	return {"type": "tile_generated", "tileIndex": insert_at, "tileId": tile.id, "tileInstanceId": tile.instance_id, "temporary": bool(tile.runtime_flags.get("temporary_tile", false))}

func consume_all_pawns_next_roll() -> bool:
	if all_pawns_next_rolls <= 0:
		return false
	all_pawns_next_rolls -= 1
	return true

func remember_battle_revert(new_instance_id: String, original_tile_id: String) -> void:
	for item in battle_reverts:
		if str(item.get("instance_id", "")) == new_instance_id:
			return
	battle_reverts.append({"instance_id": new_instance_id, "original_tile_id": original_tile_id})

func remember_battle_removed_tile(tile, current_index: int) -> void:
	if tile == null:
		return
	var restore_slot = int(tile.runtime_flags.get("battle_restore_slot", _persistent_slot_for_index(current_index)))
	var restore_tile_id = tile.id
	for item in battle_reverts.duplicate(true):
		if str(item.get("instance_id", "")) == tile.instance_id:
			restore_tile_id = str(item.get("original_tile_id", tile.id))
			battle_reverts.erase(item)
			break
	for item in battle_removed_tiles:
		if str(item.get("instance_id", "")) == tile.instance_id:
			return
	battle_removed_tiles.append({
		"instance_id": tile.instance_id,
		"tile_id": restore_tile_id,
		"restore_slot": restore_slot
	})

func register_persistent_battle_tile(tile, insert_index: int) -> void:
	if tile == null:
		return
	if bool(tile.runtime_flags.get("temporary_tile", false)):
		return
	var slot = _persistent_slot_for_index(insert_index)
	for other in board.tiles:
		if other == null or other == tile:
			continue
		if bool(other.runtime_flags.get("temporary_tile", false)):
			continue
		if int(other.runtime_flags.get("battle_restore_slot", -1)) >= slot:
			other.runtime_flags["battle_restore_slot"] = int(other.runtime_flags.get("battle_restore_slot", 0)) + 1
	for item in battle_removed_tiles:
		if int(item.get("restore_slot", 0)) >= slot:
			item["restore_slot"] = int(item.get("restore_slot", 0)) + 1
	tile.runtime_flags["battle_restore_slot"] = slot

func _persistent_slot_for_index(index: int) -> int:
	var slot = 0
	var limit = clamp(index, 0, board.size())
	for i in range(limit):
		var tile = board.get_tile(i)
		if tile == null:
			continue
		if bool(tile.runtime_flags.get("temporary_tile", false)):
			continue
		slot += 1
	return slot

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

func cleanup_battle_removed_tiles() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	battle_removed_tiles.sort_custom(func(a, b): return int(a.get("restore_slot", 0)) < int(b.get("restore_slot", 0)))
	for item in battle_removed_tiles:
		var tile_id = str(item.get("tile_id", "T000"))
		var restore_slot = int(item.get("restore_slot", board.size()))
		var restored = create_tile(tile_id)
		var insert_at = clamp(restore_slot, 0, board.size())
		board.insert_tile(insert_at, restored)
		reindex_dice_after_insert(insert_at)
		events.append({
			"type": "tile_generated",
			"tileIndex": insert_at,
			"tileId": restored.id,
			"tileInstanceId": restored.instance_id,
			"temporary": false,
			"restored": true
		})
	battle_removed_tiles.clear()
	return events

func cleanup_battle_tile_buffs() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for index in range(board.size()):
		var tile = board.get_tile(index)
		if tile == null:
			continue
		var had_converge = tile.has_tile_buff("converge") or bool(tile.runtime_flags.get("converge", false))
		tile.clear_tile_buffs_for_duration("battle")
		tile.runtime_flags.erase("converge")
		if had_converge:
			events.append({"type": "tile_buff_removed", "tileIndex": index, "tileId": tile.id, "tileInstanceId": tile.instance_id, "buffId": "converge"})
	return events

func cleanup_round_temporary_tiles() -> Array[Dictionary]:
	var events = cleanup_battle_reverts()
	events.append_array(cleanup_battle_temporary_tiles())
	events.append_array(cleanup_battle_removed_tiles())
	events.append_array(cleanup_battle_tile_buffs())
	return events

func cleanup_round_buffs() -> void:
	buffs.clear()

func add_relic(relic_id: String) -> void:
	if not relics.has(relic_id):
		relics.append(relic_id)

func has_relic(relic_id: String) -> bool:
	return relics.has(relic_id)

func add_coins(amount: int) -> int:
	coins = max(0, coins + max(0, amount))
	return coins

func spend_coins(amount: int) -> bool:
	var price = max(0, amount)
	if coins < price:
		return false
	coins -= price
	return true

func shop_remove_price() -> int:
	return int(SHOP_REMOVE_PRICES[min(shop_remove_count, SHOP_REMOVE_PRICES.size() - 1)])

func can_shop_remove_tile() -> bool:
	return board.size() > 1 and coins >= shop_remove_price()

func remove_shop_tile(index: int) -> Dictionary:
	if board.size() <= 1:
		return {}
	var normalized = board.normalize_index(index)
	var removed = board.remove_tile(normalized)
	if removed == null:
		return {}
	reindex_dice_after_remove(normalized)
	shop_remove_count += 1
	return {"type": "tile_destroyed", "tileIndex": normalized, "tileId": removed.id, "tileInstanceId": removed.instance_id, "mode": "shopRemove", "permanent": true}

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

func cleanup_end_of_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in range(board.size() - 1, -1, -1):
		var tile = board.get_tile(i)
		if tile == null:
			continue
		if not bool(tile.definition.get("auto_destroy_end_turn", false)):
			continue
		var removed = board.remove_tile(i)
		if removed == null:
			continue
		forget_temporary_tile(removed.instance_id)
		reindex_dice_after_remove(i)
		events.append({"type": "tile_destroyed", "tileIndex": i, "tileId": removed.id, "tileInstanceId": removed.instance_id, "mode": "autoEndTurn"})
	buffs.clear()
	return events

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

func draw_tile_choices_by_rarity(count: int, rarity_code: String) -> Array[String]:
	var choices: Array[String] = []
	var candidates: Array[String] = []
	for tile_id in tile_pool:
		var def = get_tile_definition(tile_id)
		if str(def.get("rarity_code", _rarity_code(str(def.get("rarity", ""))))) == rarity_code:
			candidates.append(tile_id)
	while choices.size() < count and not candidates.is_empty():
		var picked = str(rng.pick_array(candidates))
		choices.append(picked)
		candidates.erase(picked)
	return choices

func draw_relic_choices(count: int, rarity_filter: String = "") -> Array[String]:
	var choices: Array[String] = []
	var candidates = _weighted_relic_pool(rarity_filter)
	while choices.size() < count and not candidates.is_empty():
		var picked = rng.pick_weighted(candidates)
		if picked == null:
			break
		var relic_id = str(picked.get("id", ""))
		if not choices.has(relic_id):
			choices.append(relic_id)
		candidates.erase(picked)
	return choices

func is_monster_intent_attack() -> bool:
	for unit in enemy_units:
		if int(unit.get("hp", 0)) > 0 and str(unit.get("current_intent", {}).get("intent_type", "")) == "ATTACK":
			return true
	return str(current_intent.get("intent_type", "")) == "ATTACK"

func consume_next_attack_multiplier() -> float:
	var multiplier = max(1.0, next_attack_multiplier)
	next_attack_multiplier = 1.0
	return multiplier

func apply_monster_damage_to_unit(unit_index: int, raw_amount: int, source_id: String = "", source_index: int = -1, dice_id: String = "") -> Dictionary:
	if enemy_units.is_empty():
		return {"type": "monster_damaged", "amount": 0, "blocked": 0, "raw": raw_amount, "unitIndex": -1, "sourceId": source_id, "sourceIndex": source_index, "diceId": dice_id}
	var index = unit_index
	if index < 0 or index >= enemy_units.size() or int(enemy_units[index].get("hp", 0)) <= 0:
		index = first_alive_enemy_index()
	var unit: Dictionary = enemy_units[index]
	if enemy_units.size() == 1 and int(unit.get("block", 0)) == 0 and monster_block > 0:
		unit["block"] = monster_block
	if bool(unit.get("current_intent", {}).get("immune", false)):
		return {
			"type": "monster_damaged",
			"amount": 0,
			"blocked": max(0, raw_amount),
			"raw": raw_amount,
			"unitIndex": index,
			"unitName": str(unit.get("name", "")),
			"sourceId": source_id,
			"sourceIndex": source_index,
			"diceId": dice_id,
			"immune": true
		}
	var blocked = min(int(unit.get("block", 0)), max(0, raw_amount))
	unit["block"] = int(unit.get("block", 0)) - blocked
	var amount = max(0, raw_amount - blocked)
	unit["hp"] = max(0, int(unit.get("hp", 0)) - amount)
	enemy_units[index] = unit
	selected_enemy_index = index if int(unit.get("hp", 0)) > 0 else first_alive_enemy_index()
	_sync_monster_alias()
	var event = {
		"type": "monster_damaged",
		"amount": amount,
		"blocked": blocked,
		"raw": raw_amount,
		"unitIndex": index,
		"unitName": str(unit.get("name", "")),
		"sourceId": source_id,
		"sourceIndex": source_index,
		"diceId": dice_id
	}
	var passive: Dictionary = unit.get("passive", {})
	if amount > 0 and passive.has("on_damaged_add_tile"):
		event["passiveTileId"] = str(passive.get("on_damaged_add_tile", "T000"))
		event["passiveTileCount"] = int(passive.get("count", 1))
	return event

func kill_all_enemies(source_id: String = "gm_kill") -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in range(enemy_units.size()):
		var unit: Dictionary = enemy_units[i]
		var hp = int(unit.get("hp", 0))
		if hp <= 0:
			continue
		unit["hp"] = 0
		enemy_units[i] = unit
		events.append({
			"type": "monster_damaged",
			"amount": hp,
			"blocked": 0,
			"raw": hp,
			"unitIndex": i,
			"unitName": str(unit.get("name", "")),
			"sourceId": source_id,
			"sourceIndex": -1,
			"diceId": ""
		})
	selected_enemy_index = first_alive_enemy_index()
	_sync_monster_alias()
	return events

func add_enemy_block(unit_index: int, amount: int) -> Dictionary:
	if unit_index < 0 or unit_index >= enemy_units.size():
		unit_index = first_alive_enemy_index()
	var unit: Dictionary = enemy_units[unit_index]
	unit["block"] = max(0, int(unit.get("block", 0)) + amount)
	enemy_units[unit_index] = unit
	selected_enemy_index = unit_index
	_sync_monster_alias()
	return {"type": "monster_block_added", "amount": amount, "unitIndex": unit_index, "unitName": str(unit.get("name", "")), "block": int(unit.get("block", 0))}

func add_enemy_strength(unit_index: int, amount: int) -> Dictionary:
	if unit_index < 0 or unit_index >= enemy_units.size():
		unit_index = first_alive_enemy_index()
	var unit: Dictionary = enemy_units[unit_index]
	unit["strength"] = int(unit.get("strength", 0)) + amount
	enemy_units[unit_index] = unit
	selected_enemy_index = unit_index
	_sync_monster_alias()
	return {"type": "monster_strength_added", "amount": amount, "unitIndex": unit_index, "unitName": str(unit.get("name", "")), "strength": int(unit.get("strength", 0))}

func add_enemy_heal(unit_index: int, amount: int) -> Dictionary:
	if unit_index < 0 or unit_index >= enemy_units.size():
		unit_index = first_alive_enemy_index()
	var unit: Dictionary = enemy_units[unit_index]
	var old_hp = int(unit.get("hp", 0))
	var max_hp = int(unit.get("max_hp", 1))
	unit["hp"] = min(max_hp, old_hp + max(0, amount))
	enemy_units[unit_index] = unit
	selected_enemy_index = unit_index
	_sync_monster_alias()
	return {"type": "monster_healed", "amount": int(unit.get("hp", 0)) - old_hp, "unitIndex": unit_index, "unitName": str(unit.get("name", "")), "hp": int(unit.get("hp", 0)), "maxHp": max_hp}

func apply_player_damage(amount: int) -> Dictionary:
	var raw_amount = max(0, amount)
	if raw_amount > 0 and get_counter("turn", "player_damage_cap_1") > 0:
		raw_amount = 1
	var blocked = min(player_block, raw_amount)
	player_block -= blocked
	var damage = max(0, raw_amount - blocked)
	player_hp = max(0, player_hp - damage)
	if damage > 0:
		increment_counter("battle", "player_damage_taken", 1)
	return {"amount": damage, "blocked": blocked, "raw": raw_amount, "playerHp": player_hp, "playerBlock": player_block}

func apply_player_heal(amount: int) -> Dictionary:
	var old_hp = player_hp
	player_hp = min(player_max_hp, player_hp + max(0, amount))
	return {"type": "player_healed", "amount": player_hp - old_hp, "playerHp": player_hp, "playerMaxHp": player_max_hp}

func record_current_intent_used() -> void:
	var intent_id = str(current_intent.get("intent_id", ""))
	if intent_id.is_empty():
		return
	intent_history.append(intent_id)
	intent_last_used[intent_id] = battle_turn

func record_current_intents_used() -> void:
	for i in range(enemy_units.size()):
		var unit: Dictionary = enemy_units[i]
		if int(unit.get("hp", 0)) <= 0:
			continue
		var intent: Dictionary = unit.get("current_intent", {})
		var intent_id = str(intent.get("intent_id", ""))
		if intent_id.is_empty():
			continue
		var history: Array = unit.get("intent_history", [])
		var last_used: Dictionary = unit.get("intent_last_used", {})
		history.append(intent_id)
		last_used[intent_id] = battle_turn
		unit["intent_history"] = history
		unit["intent_last_used"] = last_used
		enemy_units[i] = unit
	_sync_monster_alias()

func pick_corruptible_tile_index() -> int:
	var candidates: Array[int] = []
	var ruin_tile_id = tile_id_for_name("废墟", "T012")
	for i in range(board.size()):
		var tile = board.get_tile(i)
		if tile == null:
			continue
		if tile.id in ["T000", ruin_tile_id, "T901"] or tile.has_tag("curse"):
			continue
		if bool(tile.runtime_flags.get("temporary_tile", false)):
			continue
		candidates.append(i)
	if candidates.is_empty():
		return -1
	return int(rng.pick_array(candidates))

func count_tiles_by_id(tile_id: String) -> int:
	var count = 0
	for tile in board.tiles:
		if tile != null and tile.id == tile_id:
			count += 1
	return count

func advance_moon_counters(delta: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var moon_tile_id = tile_id_for_name("月圆", "T071")
	for i in range(board.size() - 1, -1, -1):
		var tile = board.get_tile(i)
		if tile == null or tile.id != moon_tile_id:
			continue
		var value = int(tile.counters.get("moon", 0)) + delta
		tile.counters["moon"] = max(0, value)
		events.append({"type": "tile_counter_changed", "tileIndex": i, "tileId": tile.id, "tileInstanceId": tile.instance_id, "counterKey": "moon", "value": int(tile.counters["moon"])})
		if int(tile.counters["moon"]) >= 10:
			var removed = board.remove_tile(i)
			if removed == null:
				continue
			forget_temporary_tile(removed.instance_id)
			reindex_dice_after_remove(i)
			events.append({"type": "tile_destroyed", "tileIndex": i, "tileId": removed.id, "tileInstanceId": removed.instance_id, "mode": "moonCounter"})
	return events

func _weighted_tile_pool() -> Array:
	var result = []
	for tile_id in tile_pool:
		var def = get_tile_definition(tile_id)
		result.append({"id": tile_id, "weight": _rarity_weight(str(def.get("rarity", "普通")))})
	return result

func _weighted_relic_pool(rarity_filter: String = "") -> Array:
	var result = []
	for relic_id in relic_definitions.keys():
		if relics.has(str(relic_id)):
			continue
		var def: Dictionary = relic_definitions[relic_id]
		var code = str(def.get("rarity_code", _rarity_code(str(def.get("rarity", "")))))
		if not rarity_filter.is_empty() and code != rarity_filter:
			continue
		result.append({"id": str(relic_id), "weight": _rarity_code_weight(code)})
	return result

func _rarity_code(rarity: String) -> String:
	match rarity:
		"基础牌":
			return "basic"
		"普通":
			return "common"
		"稀有":
			return "rare"
		"非凡":
			return "uncommon"
		"诅咒":
			return "curse"
		"boss":
			return "boss"
		_:
			return "common"

func _rarity_code_weight(code: String) -> float:
	match code:
		"common":
			return 100.0
		"rare":
			return 38.0
		"uncommon":
			return 18.0
		"boss":
			return 0.0
		_:
			return 12.0

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
