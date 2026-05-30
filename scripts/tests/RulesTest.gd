extends Node

const RunState = preload("res://scripts/domain/RunState.gd")
const TileDefinitions = preload("res://scripts/data/TileDefinitions.gd")
const RelicDefinitions = preload("res://scripts/data/RelicDefinitions.gd")
const BuffLibrary = preload("res://scripts/buffs/BuffLibrary.gd")
const TurnResolver = preload("res://scripts/systems/TurnResolver.gd")
const MonsterConfig = preload("res://scripts/data/MonsterConfig.gd")

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
	_test_combo_damage_counts_this_turn()
	_test_quick_shot_counters()
	_test_warp_pass_effects()
	_test_destroy_next_tile_triggers_destroy_effect()
	_test_monster_block_expires_and_reports_full_block()
	_test_monster_tables_include_new_flow()
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

func _test_basic_attack_and_block() -> void:
	var run = _new_run(["T001", "T002"], 1)
	_roll(run, 1, 1)
	_assert(run.monster_hp == 95, "normal attack deals 5 monster damage")
	_roll(run, 0, 1)
	_assert(run.player_block == 5, "normal defense grants 5 player block")

func _test_roll_energy_and_self_destroy() -> void:
	var run = _new_run(["T011"], 2)
	_roll(run, 0, 1)
	_assert(run.turn_rolls_left == 4, "again charge spends 1 roll then adds 2 rolls")
	_assert(run.board.size() == 0, "again charge destroys itself")

func _test_combo_damage_counts_this_turn() -> void:
	var run = _new_run(["T006"], 3)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 95, "first combo hit deals 5, hp=%d counter=%d" % [run.monster_hp, run.get_counter("turn", "combo_hits")])
	_roll(run, 0, 1)
	_assert(run.monster_hp == 85, "second combo hit deals 10, hp=%d counter=%d" % [run.monster_hp, run.get_counter("turn", "combo_hits")])

func _test_quick_shot_counters() -> void:
	var run = _new_run(["T016"], 4)
	run.increment_counter("battle", "quick_shot_bonus", 4)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 92, "quick shot uses battle damage bonus")
	_assert(run.get_counter("battle", "quick_shot_destroyed") == 1, "quick shot destruction increments consumed counter")

	run = _new_run(["T019"], 5)
	run.increment_counter("battle", "quick_shot_destroyed", 2)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 90, "golden bullet scales with consumed quick shots")

func _test_warp_pass_effects() -> void:
	var run = _new_run(["T020", "T024", "T025", "T001"], 6)
	_roll(run, 3, 1)
	_assert(run.get_counter("turn", "warp_count") == 1, "warp movement increments warp count")
	_assert(run.monster_hp == 91, "warp pass damage plus final attack resolves")
	_assert(run.player_block == 3, "warp pass block resolves")

func _test_destroy_next_tile_triggers_destroy_effect() -> void:
	var run = _new_run(["T030", "T031"], 7)
	_roll(run, 1, 1)
	_assert(run.get_counter("battle", "destroy_next_tile") == 1, "demolition arms next tile destruction")
	_roll(run, 0, 1)
	_assert(run.monster_hp == 80, "destroyed rotten hilt deals destroy damage only")
	_assert(run.board.size() == 1, "destroyed target is removed from board")

func _test_monster_block_expires_and_reports_full_block() -> void:
	var run = _new_run(["T001"], 8)
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
