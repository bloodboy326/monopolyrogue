extends Node

const RunState = preload("res://scripts/domain/RunState.gd")
const TileDefinitions = preload("res://scripts/data/TileDefinitions.gd")
const RelicDefinitions = preload("res://scripts/data/RelicDefinitions.gd")
const BuffLibrary = preload("res://scripts/buffs/BuffLibrary.gd")
const TurnResolver = preload("res://scripts/systems/TurnResolver.gd")
const MonsterConfig = preload("res://scripts/data/MonsterConfig.gd")
const MapConfig = preload("res://scripts/data/MapConfig.gd")
const GeneratedTileIcon = preload("res://scripts/components/GeneratedTileIcon.gd")

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
	_test_heavy_hit_source_counter_damage()
	_test_quick_shot_counters()
	_test_warp_pass_effects()
	_test_bone_destroys_on_pass_or_landing()
	_test_destroy_next_tile_triggers_destroy_effect()
	_test_durability_and_weak_state()
	_test_turn_start_generated_tiles_cleanup()
	_test_monster_block_expires_and_reports_full_block()
	_test_new_tile_text_is_configured()
	_test_generated_tile_icons_exist()
	_test_group_monsters_take_targeted_damage()
	_test_group_monsters_keep_independent_block()
	_test_monster_tables_include_new_flow()
	_test_new_monster_text_is_configured()
	_test_gold_relic_and_new_tile_rules()
	_test_starting_deck_tile_buffs_and_shop_remove()
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

func _tile_id(tile_name: String, fallback: String = "T000") -> String:
	for tile_id in tile_defs.keys():
		var definition: Dictionary = tile_defs[tile_id]
		if str(definition.get("name", "")) == tile_name:
			return str(tile_id)
	return fallback

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
	var again_charge = _tile_id("再次冲锋", "T014")
	var run = _new_run([again_charge], 2)
	_roll(run, 0, 1)
	_assert(run.turn_rolls_left == 4, "again charge spends 1 roll then adds 2 rolls")
	_assert(run.board.size() == 0, "non-cleanup self destroy removes the tile during the battle")
	run.start_battle(2, {"monster_id": "test", "name": "测试怪", "max_hp": 100, "art_key": "slime"})
	_assert(run.board.size() == 1 and run.board.get_tile(0).is_triggerable(), "temporary destroyed tile restores next battle")

func _test_battle_removed_tile_restores_after_battle() -> void:
	var charge = _tile_id("充能", "T034")
	var overload = _tile_id("超载", "T016")
	var run = _new_run([charge, overload, "T001"], 12)
	var first_turn = _roll(run, 2, 1)
	_assert(_has_event(first_turn.events, "tile_destroyed"), "self destroy emits tile destroyed event")
	_assert(run.board.size() == 2 and run.board.get_tile(0).id == overload, "self destroyed tile leaves the board during the battle")
	_assert(run.board.get_tile(0).durability_remaining() == 5, "charge adds durability once")
	run.cleanup_round_temporary_tiles()
	_assert(run.board.size() == 3 and run.board.get_tile(0).id == charge, "battle removed tile restores at its original slot")
	run.start_battle(2, {"monster_id": "test", "name": "测试怪", "max_hp": 100, "art_key": "slime"})
	_assert(run.board.get_tile(1).durability_remaining() == 2, "restored next battle resets durability")

func _test_combo_damage_counts_this_turn() -> void:
	var combo = _tile_id("连击", "T008")
	var run = _new_run([combo], 3)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 95, "first combo hit deals 5, hp=%d counter=%d" % [run.monster_hp, run.get_counter("turn", "combo_hits")])
	_roll(run, 0, 1)
	_assert(run.monster_hp == 85, "second combo hit deals 10, hp=%d counter=%d" % [run.monster_hp, run.get_counter("turn", "combo_hits")])

func _test_heavy_hit_source_counter_damage() -> void:
	var heavy_hit = _tile_id("重击", "T006")
	var run = _new_run([heavy_hit], 31)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 92, "first heavy hit deals 8 damage")
	_roll(run, 0, 1)
	_assert(run.monster_hp == 83, "second heavy hit deals 9 damage from its source counter")

func _test_quick_shot_counters() -> void:
	var quick_shot = _tile_id("快速射击", "T019")
	var golden_bullet = _tile_id("金色子弹", "T022")
	var run = _new_run([quick_shot], 4)
	run.increment_counter("battle", "quick_shot_bonus", 4)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 92, "quick shot uses battle damage bonus")
	_assert(run.get_counter("battle", "quick_shot_destroyed") == 1, "quick shot destruction increments consumed counter")

	run = _new_run([golden_bullet], 5)
	run.increment_counter("battle", "quick_shot_destroyed", 2)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 90, "golden bullet scales with consumed quick shots")

func _test_warp_pass_effects() -> void:
	var warp3 = _tile_id("快速跃迁3", "T026")
	var warp_shot = _tile_id("跃迁速射", "T030")
	var warp_block = _tile_id("灵活抖动", "T031")
	var run = _new_run([warp3, warp_shot, warp_block, "T001"], 6)
	_roll(run, 3, 1)
	_assert(run.get_counter("turn", "warp_count") == 1, "warp movement increments warp count")
	_assert(run.monster_hp == 91, "warp pass damage plus final attack resolves")
	_assert(run.player_block == 4, "warp pass block resolves")

func _test_bone_destroys_on_pass_or_landing() -> void:
	var bone = _tile_id("骨头", "T070")
	var run = _new_run(["T001", bone, "T002"], 15)
	var turn = _roll(run, 0, 2)
	_assert(_has_event(turn.events, "tile_destroyed"), "passing through bone emits tile destroyed event")
	_assert(run.board.size() == 2 and run.board.get_tile(0).id == "T001" and run.board.get_tile(1).id == "T002", "passed bone leaves the board without shifting landing to a wrong tile")
	_assert(run.player_block == 5, "roll still lands on the original planned target after passed bone is removed")

	run = _new_run(["T001", bone, "T002"], 16)
	turn = _roll(run, 0, 1)
	_assert(_has_event(turn.events, "tile_destroyed"), "landing on bone emits tile destroyed event")
	_assert(run.board.size() == 2 and run.board.get_tile(0).id == "T001" and run.board.get_tile(1).id == "T002", "landed bone leaves the board")
	_assert(run.player_block == 0 and run.monster_hp == 100, "landing on bone does not trigger the shifted neighboring tile")

func _test_destroy_next_tile_triggers_destroy_effect() -> void:
	var demolition = _tile_id("拆迁", "T037")
	var rotten_hilt = _tile_id("腐烂剑柄", "T038")
	var run = _new_run([demolition, rotten_hilt], 7)
	_roll(run, 1, 1)
	_assert(run.get_counter("battle", "destroy_next_tile") == 1, "demolition arms next tile destruction")
	_roll(run, 0, 1)
	_assert(run.monster_hp == 80, "destroyed rotten hilt deals destroy damage only")
	_assert(run.board.size() == 1, "non-cleanup destroyed target leaves the board during the battle")

func _test_durability_and_weak_state() -> void:
	var all_out = _tile_id("全军出击", "T048")
	var run = _new_run([all_out], 8)
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
	var support = _tile_id("后援", "T025")
	var quick_shot = _tile_id("快速射击", "T019")
	var run = _new_run([support], 9)
	_roll(run, 0, 1)
	run.begin_player_turn(3)
	var events = run.apply_turn_start_tile_spawns()
	_assert(not events.is_empty() and run.board.size() == 1, "turn start generator adds a tile after source leaves the board")
	var generated = run.board.get_tile(int(events[0].get("tileIndex", 0)))
	_assert(generated.id == quick_shot and bool(generated.runtime_flags.get("temporary_tile", false)), "turn start generated quick shot is marked for battle cleanup")
	run.cleanup_round_temporary_tiles()
	_assert(run.board.size() == 1 and run.board.get_tile(0).id == support, "battle cleanup removes generated cleanup tiles and restores source")

func _test_monster_block_expires_and_reports_full_block() -> void:
	var run = _new_run(["T001"], 10)
	run.monster_block = 7
	var turn = _roll(run, 0, 1)
	var blocked_events = turn.events.filter(func(event): return str(event.get("type", "")) == "monster_damaged" and int(event.get("amount", 0)) == 0 and int(event.get("blocked", 0)) == 5)
	_assert(blocked_events.size() == 1 and run.monster_hp == 100, "full monster block is reported without damage")
	_assert(run.monster_block == 2, "monster block absorbs incoming attack")
	run.begin_monster_turn()
	_assert(run.monster_block == 0, "monster block expires before the monster acts again")

func _test_new_tile_text_is_configured() -> void:
	var seen_ids: Dictionary = {}
	for tile_id in tile_defs.keys():
		if tile_id == "T000":
			continue
		var tile = tile_defs.get(tile_id, {})
		_assert(not seen_ids.has(tile_id), "%s is unique in the tile table" % tile_id)
		seen_ids[tile_id] = true
		_assert(not str(tile.get("name", "")).is_empty(), "%s has a configured tile name" % tile_id)
		_assert(not str(tile.get("displayDescription", "")).is_empty(), "%s has a configured tile description" % tile_id)
		_assert(not str(tile.get("name", "")).contains("?") and not str(tile.get("displayDescription", "")).contains("?"), "%s has readable tile text" % tile_id)

func _test_generated_tile_icons_exist() -> void:
	for tile_id in tile_defs.keys():
		if tile_id == "T000":
			continue
		_assert(GeneratedTileIcon.get_texture(tile_id) != null, "%s generated tile icon exists" % tile_id)

func _test_group_monsters_take_targeted_damage() -> void:
	var config = MonsterConfig.load_config()
	var group_def = MonsterConfig.encounter(config, "skeleton_pair")
	var run = RunState.new()
	run.setup(tile_defs, relic_defs, buff_defs, 13, "T001", 3)
	run.start_battle(1, group_def)
	_assert(run.enemy_units.size() == 2, "skeleton pair expands to two units")
	var event = run.apply_monster_damage_to_unit(1, 9, "test", 0, "red")
	_assert(int(event.get("unitIndex", -1)) == 1 and int(run.enemy_units[1].get("hp", 0)) == 33, "targeted damage applies to selected unit only")
	_assert(int(run.enemy_units[0].get("hp", 0)) == 48, "other group units keep independent hp")

func _test_group_monsters_keep_independent_block() -> void:
	var config = MonsterConfig.load_config()
	var group_def = MonsterConfig.encounter(config, "guard_pair")
	var run = RunState.new()
	run.setup(tile_defs, relic_defs, buff_defs, 14, "T001", 3)
	run.start_battle(1, group_def)
	run.add_enemy_block(1, 6)
	var event = run.apply_monster_damage_to_unit(1, 4, "test", 0, "red")
	_assert(int(event.get("blocked", 0)) == 4 and int(event.get("amount", 0)) == 0, "target unit block absorbs damage independently")
	_assert(int(run.enemy_units[1].get("block", 0)) == 2 and int(run.enemy_units[0].get("block", 0)) == 0, "other units do not share block")
	run.begin_monster_turn()
	_assert(int(run.enemy_units[1].get("block", 0)) == 0, "group monster block clears before the next monster action")

func _test_monster_tables_include_new_flow() -> void:
	var config = MonsterConfig.load_config()
	_assert(MonsterConfig.battle_count(config) == 15, "test flow has fifteen configured battles")
	_assert(str(MonsterConfig.battle_for(config, 1).get("monster_id", "")) == "goblin", "battle 1 uses goblin")
	_assert(str(MonsterConfig.battle_for(config, 2).get("monster_id", "")) == "slime", "battle 2 uses slime")
	_assert(str(MonsterConfig.battle_for(config, 7).get("monster_id", "")) == "skeleton_pair", "battle 7 uses skeleton pair")
	_assert(str(MonsterConfig.battle_for(config, 12).get("monster_id", "")) == "headless_knight", "battle 12 uses headless knight")
	_assert(str(MonsterConfig.battle_for(config, 14).get("monster_id", "")) == "void_eye", "battle 14 uses void eye")
	_assert(not MonsterConfig.effects_for_intent(config, "goblin_snot").is_empty(), "goblin snot has configured effects")
	_assert(not MonsterConfig.effects_for_intent(config, "skeleton_king_bone_spikes").is_empty(), "skeleton king bone spikes has configured effects")
	_assert(not MonsterConfig.effects_for_intent(config, "dice_demon_fog").is_empty(), "dice demon fog has configured effects")
	_assert(MonsterConfig.encounter(config, "guard_pair").get("units", []).size() == 2, "guard pair is configured as two enemies")

func _test_new_monster_text_is_configured() -> void:
	var config = MonsterConfig.load_config()
	for monster_id in ["goblin", "slime", "skeleton_soldier", "murloc", "skeleton_archer", "frost_giant", "skeleton_pair", "guard_pair", "baby_dragon", "skeleton_king", "werewolf", "headless_knight", "medusa", "void_eye", "dice_demon"]:
		var monster = MonsterConfig.monster(config, monster_id)
		_assert(not str(monster.get("name", "")).contains("?"), "%s has a readable configured name" % monster_id)
	for intent_id in ["goblin_snot", "slime_mud", "headless_flame_combo", "void_eye_void_gaze", "dice_demon_fog"]:
		var intent = config.get("intents_by_id", {}).get(intent_id, {})
		_assert(not str(intent.get("name", "")).contains("?") and not str(intent.get("telegraph", "")).contains("?"), "%s has readable configured intent text" % intent_id)

func _test_gold_relic_and_new_tile_rules() -> void:
	_assert(relic_defs.size() == 15, "relic table config loads fifteen relics")
	_assert(not str(relic_defs.get("R001", {}).get("name", "")).contains("?"), "relic text is readable")
	var gold_tile = _tile_id("黄金", "T081")
	var void_space = _tile_id("虚无空间", "T042")
	var sweep = _tile_id("扫射", "T074")
	var run = _new_run([gold_tile], 17)
	_roll(run, 0, 1)
	_assert(run.coins == 15, "gold tile grants coins")

	run = _new_run([void_space], 18)
	_roll(run, 0, 1)
	var damage = run.apply_player_damage(20)
	_assert(int(damage.get("raw", 0)) == 1 and int(damage.get("amount", 0)) == 1, "void space caps incoming damage to one this turn")

	var config = MonsterConfig.load_config()
	var group_def = MonsterConfig.encounter(config, "guard_pair")
	run = RunState.new()
	run.setup(tile_defs, relic_defs, buff_defs, 19, "T001", 3)
	run.board.tiles.clear()
	run.board.tiles.append(run.create_tile(sweep))
	run.start_battle(1, group_def)
	run.begin_player_turn(3)
	for dice_id in run.dice.keys():
		run.dice[dice_id].index = 0
	_roll(run, 0, 1)
	_assert(int(run.enemy_units[0].get("hp", 0)) == 32 and int(run.enemy_units[1].get("hp", 0)) == 30, "sweep deals damage to all enemy units")

	run = _new_run(["T001"], 20)
	run.add_relic("R002")
	var events = run.apply_relic_battle_start()
	_assert(events.any(func(event): return str(event.get("tileId", "")) == gold_tile), "golden eye relic generates a gold tile at battle start")

func _test_starting_deck_tile_buffs_and_shop_remove() -> void:
	var start_deck = TileDefinitions.starting_deck()
	var repair = _tile_id("修修补补", "T003")
	var charge_sword = _tile_id("充能剑", "T004")
	_assert(start_deck.size() == 8 and start_deck.has(repair) and start_deck.has(charge_sword), "starting deck includes repair and charge sword")
	var run = _new_run([charge_sword], 22)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 90 and run.board.get_tile(0).durability_remaining() == 1, "charge sword deals 10 damage and consumes durability")
	_roll(run, 0, 1)
	_roll(run, 0, 1)
	_assert(run.monster_hp == 78 and run.board.get_tile(0).is_weak(), "charge sword weak state deals 2 damage after durability is spent")
	run = _new_run(["T001", "T002", charge_sword], 21)
	var buff_events = run.add_converge_to_random_tiles(1)
	_assert(buff_events.size() == 1, "supply pack can add a converge tile buff")
	var buffed_index = int(buff_events[0].get("tileIndex", -1))
	_assert(buffed_index >= 0 and run.board.get_tile(buffed_index).has_tile_buff("converge"), "converge is stored as a tile buff")
	run.cleanup_round_temporary_tiles()
	_assert(not run.board.get_tile(buffed_index).has_tile_buff("converge"), "battle duration tile buffs clear after battle")
	run.add_coins(1000)
	_assert(run.shop_remove_price() == 75, "first shop removal costs 75")
	var removed = run.remove_shop_tile(1)
	_assert(not removed.is_empty() and run.board.size() == 2 and run.shop_remove_price() == 100, "shop removal permanently removes a tile and raises price")

func _test_act_map_tables_include_first_act() -> void:
	var map_config = MapConfig.load_config()
	var generator: Dictionary = MapConfig.act_for(map_config, 1).get("generator", {})
	_assert(int(generator.get("columns", 0)) == 7, "act map generator uses seven columns")
	_assert(int(generator.get("path_count", 0)) == 6, "act map generator creates six paths")
	var local_rng = RandomNumberGenerator.new()
	local_rng.seed = 99
	var act_map = MapConfig.generate_act_map(map_config, 1, local_rng)
	_assert(act_map.get("nodes", []).size() >= 24, "act 1 map has a multi-screen path graph")
	_assert(MapConfig.available_node_ids(act_map, "").size() >= 2, "act 1 has multiple starting route choices")
	var boss_nodes = act_map.get("nodes", []).filter(func(node): return str(node.get("room_type", "")) == "BOSS")
	_assert(boss_nodes.size() == 1, "act 1 has one boss node")
	_assert(act_map.get("nodes", []).filter(func(node): return int(node.get("floor", 0)) == 7).all(func(node): return str(node.get("room_type", "")) == "CHEST"), "floor 7 is fixed to chest rooms")
	_assert(act_map.get("nodes", []).filter(func(node): return int(node.get("floor", 0)) == 13).all(func(node): return str(node.get("room_type", "")) == "REST"), "floor 13 is fixed to rest rooms")
	var monster_id = MapConfig.pick_monster_for_node(map_config, boss_nodes[0], local_rng)
	_assert(["medusa", "void_eye", "dice_demon"].has(monster_id), "act 1 boss pool resolves to a configured boss")
	var next_boss_id = MapConfig.pick_monster_for_node(map_config, boss_nodes[0], local_rng, [monster_id])
	_assert(next_boss_id != monster_id, "monster picker avoids the previous monster when alternatives exist")
	var pool_monsters = map_config.get("monster_pool_entries", []).map(func(entry): return str(entry.get("monster_id", "")))
	_assert(pool_monsters.has("goblin") and pool_monsters.has("skeleton_king") and pool_monsters.has("guard_pair"), "act 1 pools include normal, elite, and group monsters")
	var configured_room_types = map_config.get("room_type_weights", []).map(func(entry): return str(entry.get("room_type", "")))
	_assert(configured_room_types.has("SHOP") and configured_room_types.has("CHEST"), "act 1 room weights include shop and chest rooms")
