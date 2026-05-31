extends Node

const RunState = preload("res://scripts/domain/RunState.gd")
const TileDefinitions = preload("res://scripts/data/TileDefinitions.gd")
const RelicDefinitions = preload("res://scripts/data/RelicDefinitions.gd")
const BuffLibrary = preload("res://scripts/buffs/BuffLibrary.gd")
const TurnResolver = preload("res://scripts/systems/TurnResolver.gd")
const MonsterConfig = preload("res://scripts/data/MonsterConfig.gd")
const MapConfig = preload("res://scripts/data/MapConfig.gd")

var tile_defs: Dictionary
var relic_defs: Dictionary
var buff_defs: Dictionary
var passed := 0

func _ready() -> void:
	tile_defs = TileDefinitions.all()
	relic_defs = RelicDefinitions.all()
	buff_defs = BuffLibrary.definitions()
	_test_basic_attack_and_block()
	_test_roll_energy_and_self_destroy()
	_test_battle_removed_tile_restores_after_battle()
	_test_combo_damage_counts_this_turn()
	_test_quick_shot_counters()
	_test_warp_pass_effects()
	_test_destroy_next_tile_triggers_destroy_effect()
	_test_durability_and_weak_state()
	_test_turn_start_generated_tiles_cleanup()
	_test_monster_block_expires_and_reports_full_block()
	_test_monster_tables_include_new_flow()
	_test_act_map_tables_include_first_act()
	print("RULES_OK tests=%d" % passed)
	get_tree().quit()

func _new_run(tile_ids: Array[String], seed_value: int = 11):
	var run = RunState.new()
	run.setup(tile_defs, relic_defs, buff_defs, seed_value, "T001", max(1, tile_ids.size()))
	run.board.tiles.clear()
	for tile_id in tile_ids:
		run.board.tiles.append(run.create_tile(tile_id))
	run.start_battle(1, {"monster_id": "test", "name": "测试怪", "max_hp": 100, "art_key": "slime"})
	run.begin_player_turn(3)
	for dice_id in run.dice.keys():
		run.dice[dice_id].index = 0
	return run

func _roll(run, from_index: int, steps: int = 1):
	run.dice["red"].index = from_index
	run.spend_roll()
	return TurnResolver.new().resolve_roll(run, ["red"], {"red": steps})

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("RULES_TEST_FAILED: %s" % message)
		get_tree().quit(1)
		return
	passed += 1

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if str(event.get("type", "")) == event_type:
			return true
	return false

func _test_basic_attack_and_block() -> void:
	var run = _new_run(["T001", "T002"], 1)
	_roll(run, 1, 1)
	_assert(run.monster_hp == 95, "normal attack deals 5 monster damage")
	_roll(run, 0, 1)
	_assert(run.player_block == 5, "normal defense grants 5 player block")

func _test_roll_energy_and_self_destroy() -> void:
	var run = _new_run(["T012"], 2)
	_roll(run, 0, 1)
	_assert(run.turn_rolls_left == 4, "again charge spends 1 roll then adds 2 rolls")
	_assert(run.board.size() == 0, "non-cleanup self destroy removes the tile during the battle")
	run.start_battle(2, {"monster_id": "test", "name": "测试怪", "max_hp": 100, "art_key": "slime"})
	_assert(run.board.size() == 1 and run.board.get_tile(0).is_triggerable(), "temporary destroyed tile restores next battle")

func _test_battle_removed_tile_restores_after_battle() -> void:
	var run = _new_run(["T032", "T014", "T001"], 12)
	var first_turn = _roll(run, 2, 1)
	_assert(_has_event(first_turn.events, "tile_destroyed"), "self destroy emits tile destroyed event")
	_assert(run.board.size() == 2 and run.board.get_tile(0).id == "T014", "self destroyed tile leaves the board during the battle")
	_assert(run.board.get_tile(0).durability_remaining() == 6, "charge adds durability once")
	run.cleanup_round_temporary_tiles()
	_assert(run.board.size() == 3 and run.board.get_tile(0).id == "T032", "battle removed tile restores at its original slot")
	run.start_battle(2, {"monster_id": "test", "name": "测试怪", "max_hp": 100, "art_key": "slime"})
	_assert(run.board.get_tile(1).durability_remaining() == 3, "restored next battle resets durability")

func _test_combo_damage_counts_this_turn() -> void:
	var run = _new_run(["T006"], 3)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 95, "first combo hit deals 5, hp=%d counter=%d" % [run.monster_hp, run.get_counter("turn", "combo_hits")])
	_roll(run, 0, 1)
	_assert(run.monster_hp == 85, "second combo hit deals 10, hp=%d counter=%d" % [run.monster_hp, run.get_counter("turn", "combo_hits")])

func _test_quick_shot_counters() -> void:
	var run = _new_run(["T017"], 4)
	run.increment_counter("battle", "quick_shot_bonus", 4)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 92, "quick shot uses battle damage bonus")
	_assert(run.get_counter("battle", "quick_shot_destroyed") == 1, "quick shot destruction increments consumed counter")

	run = _new_run(["T020"], 5)
	run.increment_counter("battle", "quick_shot_destroyed", 2)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 90, "golden bullet scales with consumed quick shots")

func _test_warp_pass_effects() -> void:
	var run = _new_run(["T024", "T028", "T029", "T001"], 6)
	_roll(run, 3, 1)
	_assert(run.get_counter("turn", "warp_count") == 1, "warp movement increments warp count")
	_assert(run.monster_hp == 91, "warp pass damage plus final attack resolves")
	_assert(run.player_block == 4, "warp pass block resolves")

func _test_destroy_next_tile_triggers_destroy_effect() -> void:
	var run = _new_run(["T035", "T036"], 7)
	_roll(run, 1, 1)
	_assert(run.get_counter("battle", "destroy_next_tile") == 1, "demolition arms next tile destruction")
	_roll(run, 0, 1)
	_assert(run.monster_hp == 80, "destroyed rotten hilt deals destroy damage only")
	_assert(run.board.size() == 1, "non-cleanup destroyed target leaves the board during the battle")

func _test_durability_and_weak_state() -> void:
	var run = _new_run(["T046"], 8)
	_roll(run, 0, 1)
	_roll(run, 0, 1)
	_roll(run, 0, 1)
	_assert(run.board.get_tile(0).is_weak(), "durability reaches weak state after three triggers")
	var before = run.all_pawns_next_rolls
	_roll(run, 0, 1)
	_assert(run.all_pawns_next_rolls == before, "weak state uses weak effects instead of normal effects")
	run.add_durability_to_all(1)
	_assert(not run.board.get_tile(0).is_weak(), "durability can be replenished out of weak state")

func _test_turn_start_generated_tiles_cleanup() -> void:
	var run = _new_run(["T023"], 9)
	_roll(run, 0, 1)
	run.begin_player_turn(3)
	var events = run.apply_turn_start_tile_spawns()
	_assert(not events.is_empty() and run.board.size() == 1, "turn start generator adds a tile after source leaves the board")
	var generated = run.board.get_tile(int(events[0].get("tileIndex", 0)))
	_assert(generated.id == "T017" and bool(generated.runtime_flags.get("temporary_tile", false)), "turn start generated quick shot is marked for battle cleanup")
	run.cleanup_round_temporary_tiles()
	_assert(run.board.size() == 1 and run.board.get_tile(0).id == "T023", "battle cleanup removes generated cleanup tiles and restores source")

func _test_monster_block_expires_and_reports_full_block() -> void:
	var run = _new_run(["T001"], 10)
	run.monster_block = 7
	var turn = _roll(run, 0, 1)
	var blocked_events = turn.events.filter(func(event): return str(event.get("type", "")) == "monster_damaged" and int(event.get("amount", 0)) == 0 and int(event.get("blocked", 0)) == 5)
	_assert(blocked_events.size() == 1 and run.monster_hp == 100, "full monster block is reported without damage")
	_assert(run.monster_block == 2, "monster block absorbs incoming attack")
	run.begin_monster_turn()
	_assert(run.monster_block == 0, "monster block expires before the monster acts again")

func _test_monster_tables_include_new_flow() -> void:
	var config = MonsterConfig.load_config()
	_assert(MonsterConfig.battle_count(config) == 4, "test flow has four configured battles")
	_assert(str(MonsterConfig.battle_for(config, 1).get("monster_id", "")) == "red_louse", "battle 1 uses red louse")
	_assert(str(MonsterConfig.battle_for(config, 2).get("monster_id", "")) == "jaw_worm", "battle 2 uses jaw worm")
	_assert(str(MonsterConfig.battle_for(config, 3).get("monster_id", "")) == "clacker", "battle 3 uses clacker")
	_assert(str(MonsterConfig.battle_for(config, 4).get("monster_id", "")) == "slime_boss", "battle 4 uses slime boss")
	_assert(not MonsterConfig.effects_for_intent(config, "clacker_jam").is_empty(), "clacker jam has configured effects")

func _test_act_map_tables_include_first_act() -> void:
	var map_config = MapConfig.load_config()
	var local_rng = RandomNumberGenerator.new()
	local_rng.seed = 99
	var act_map = MapConfig.generate_act_map(map_config, 1, local_rng)
	_assert(act_map.get("nodes", []).size() >= 40, "act 1 map has a full path grid")
	_assert(MapConfig.available_node_ids(act_map, "").size() == 3, "act 1 has three starting route choices")
	var boss_nodes = act_map.get("nodes", []).filter(func(node): return str(node.get("room_type", "")) == "BOSS")
	_assert(boss_nodes.size() == 1, "act 1 has one boss node")
	var monster_id = MapConfig.pick_monster_for_node(map_config, boss_nodes[0], local_rng)
	_assert(monster_id == "slime_boss", "act 1 boss pool resolves to slime boss")
	var pool_monsters = map_config.get("monster_pool_entries", []).map(func(entry): return str(entry.get("monster_id", "")))
	_assert(pool_monsters.has("green_louse") and pool_monsters.has("gremlin_nob"), "act 1 pools include new normal and elite monsters")
