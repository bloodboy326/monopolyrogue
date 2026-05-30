extends Node

const RunState = preload("res://scripts/domain/RunState.gd")
const TileDefinitions = preload("res://scripts/data/TileDefinitions.gd")
const RelicDefinitions = preload("res://scripts/data/RelicDefinitions.gd")
const BuffLibrary = preload("res://scripts/buffs/BuffLibrary.gd")
const TurnResolver = preload("res://scripts/systems/TurnResolver.gd")
const EffectResolver = preload("res://scripts/effects/EffectResolver.gd")
const GameCommand = preload("res://scripts/effects/GameCommand.gd")
const TurnContext = preload("res://scripts/domain/TurnContext.gd")
const ResolveContext = preload("res://scripts/domain/ResolveContext.gd")
const RichDescription = preload("res://scripts/components/RichDescription.gd")
const TileRuntime = preload("res://scripts/domain/Tile.gd")

var tile_defs: Dictionary
var relic_defs: Dictionary
var buff_defs: Dictionary
var passed := 0

func _ready() -> void:
	tile_defs = TileDefinitions.all()
	relic_defs = RelicDefinitions.all()
	buff_defs = BuffLibrary.definitions()
	_test_buff_duration_and_triggers()
	_test_destroy_modes()
	_test_random_empty_generation()
	_test_generation_inserts_without_replacing()
	_test_temporary_tiles_cleanup_at_round_end()
	_test_bulldozer_buff_destroys_next_tile()
	_test_transform_inheritance()
	_test_relic_hooks()
	_test_chain_limit()
	_test_three_dice_order()
	_test_main_flow_is_not_needed_for_new_tile_effect()
	_test_rich_description_and_display_copy()
	print("RULES_OK tests=%d" % passed)
	get_tree().quit()

func _new_run(tile_ids: Array[String], seed_value: int = 11):
	var run = RunState.new()
	run.setup(tile_defs, relic_defs, buff_defs, seed_value, "T001", max(1, tile_ids.size()))
	run.board.tiles.clear()
	for tile_id in tile_ids:
		run.board.tiles.append(run.create_tile(tile_id))
	for dice_id in run.dice.keys():
		run.dice[dice_id].index = 0
	return run

func _context(run, turn = null, dice_id: String = "red", tile_index: int = 0):
	if turn == null:
		turn = TurnContext.new()
	var dice = run.dice[dice_id] if not dice_id.is_empty() else null
	var tile = run.board.get_tile(tile_index) if tile_index >= 0 and run.board.size() > 0 else null
	return ResolveContext.new().setup(run, turn, dice, tile, tile_index, dice.last_roll if dice != null else 0, "test")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("RULES_TEST_FAILED: %s" % message)
		get_tree().quit(1)
		return
	passed += 1

func _test_buff_duration_and_triggers() -> void:
	var run = _new_run(["T001"], 1)
	run.add_buff({"instanceId": "next_coin_multiplier#test", "id": "next_coin_multiplier", "name": "倍率", "sourceId": "test", "diceId": "red", "durationType": "triggers", "remaining": 1, "tags": [], "config": {"multiplier": 2.0}})
	var turn = TurnResolver.new().resolve_roll(run, ["red"], {"red": 1})
	_assert(run.round_score == 6, "trigger buff doubles next coin gain")
	_assert(run.buffs.is_empty(), "trigger buff is consumed and cleaned")
	run = _new_run(["T001"], 2)
	run.add_buff({"instanceId": "watering#test", "id": "watering", "name": "浇水", "sourceId": "test", "diceId": "red", "durationType": "turns", "remaining": 1, "tags": [], "config": {}})
	turn = TurnResolver.new().resolve_roll(run, ["red"], {"red": 1})
	_assert(run.buffs.is_empty(), "turn buff expires at end of turn")

func _test_destroy_modes() -> void:
	var resolver = EffectResolver.new()
	var run = _new_run(["T001", "T002", "T004"], 3)
	var turn = TurnContext.new()
	var context = _context(run, turn, "red", 1)
	resolver.execute_commands([GameCommand.destroy_tile(1, {"type": "permanent"})], context)
	_assert(run.board.size() == 2 and run.board.get_tile(1).id == "T004", "permanent destroy removes tile")

	run = _new_run(["T001", "T002"], 4)
	turn = TurnContext.new()
	context = _context(run, turn, "red", 1)
	resolver.execute_commands([GameCommand.destroy_tile(1, {"type": "temporary"})], context)
	_assert(bool(run.board.get_tile(1).runtime_flags.get("temporarily_destroyed", false)), "temporary destroy suppresses tile")
	resolver.execute_end_of_turn(context)
	_assert(not bool(run.board.get_tile(1).runtime_flags.get("temporarily_destroyed", false)), "temporary destroy restores after turn")

	run = _new_run(["T001", "T002"], 5)
	turn = TurnContext.new()
	context = _context(run, turn, "red", 1)
	resolver.execute_commands([GameCommand.destroy_tile(1, {"type": "afterTurn"})], context)
	_assert(run.board.size() == 2, "afterTurn destroy waits")
	resolver.execute_end_of_turn(context)
	_assert(run.board.size() == 1, "afterTurn destroy resolves at turn end")

	run = _new_run(["T001", "T002", "T004"], 6)
	turn = TurnContext.new()
	context = _context(run, turn, "red", 1)
	resolver.execute_commands([GameCommand.destroy_tile(1, {"type": "destroyThenMoveNextTurn"})], context)
	_assert(run.dice["red"].next_turn_index_override == 1, "destroyThenMoveNextTurn records next index")

func _test_random_empty_generation() -> void:
	var run = _new_run(["T001", "T000"], 7)
	var resolver = EffectResolver.new()
	var turn = TurnContext.new()
	var context = _context(run, turn, "red", 0)
	resolver.execute_commands([GameCommand.generate_tile("T002", {"type": "randomEmpty"})], context)
	_assert(run.board.size() == 3 and run.board.get_tile(1).id == "T002" and run.board.get_tile(2).id == "T000", "randomEmpty generation inserts at empty slot without replacing it")

func _test_generation_inserts_without_replacing() -> void:
	var run = _new_run(["T001", "T002", "T004"], 15)
	var resolver = EffectResolver.new()
	var turn = TurnContext.new()
	var context = _context(run, turn, "red", 0)
	resolver.execute_commands([GameCommand.generate_tile("T025", {"type": "specificIndex", "index": 1})], context)
	_assert(run.board.size() == 4 and run.board.get_tile(1).id == "T025" and run.board.get_tile(2).id == "T002", "generation inserts an extra tile instead of replacing the target")

func _test_temporary_tiles_cleanup_at_round_end() -> void:
	var run = _new_run(["T001", "T024"], 16)
	run.dice["red"].index = 0
	TurnResolver.new().resolve_roll(run, ["red"], {"red": 1})
	var vampire_count = 0
	for tile in run.board.tiles:
		if tile.id == "T025":
			vampire_count += 1
	_assert(vampire_count == 1 and run.temporary_tile_instances.size() == 1, "coffin generates a round-temporary vampire")
	run.cleanup_round_temporary_tiles()
	_assert(run.board.tiles.all(func(tile): return tile.id != "T025"), "round-temporary vampire is removed at round cleanup")

func _test_bulldozer_buff_destroys_next_tile() -> void:
	var run = _new_run(["T029", "T001", "T002"], 17)
	run.dice["red"].index = 2
	TurnResolver.new().resolve_roll(run, ["red"], {"red": 1})
	_assert(run.has_buff("destroy_on_resolve", "red"), "bulldozer grants a pending destroy buff")
	TurnResolver.new().resolve_roll(run, ["red"], {"red": 1})
	_assert(run.board.size() == 2 and run.board.get_tile(1).id == "T002" and run.buffs.is_empty(), "bulldozer destroy buff removes the next resolved non-bulldozer tile")

func _test_transform_inheritance() -> void:
	var run = _new_run(["T006"], 8)
	run.board.get_tile(0).counters["hits_remaining"] = 9
	var resolver = EffectResolver.new()
	var turn = TurnContext.new()
	var context = _context(run, turn, "red", 0)
	resolver.execute_commands([GameCommand.transform_tile(0, "T007", {"inherit": {"counters": true, "baseCoin": false, "state": false}})], context)
	_assert(run.board.get_tile(0).id == "T007" and int(run.board.get_tile(0).counters["hits_remaining"]) == 9, "transform can inherit counters")
	resolver.execute_commands([GameCommand.transform_tile(0, "T009", {"inherit": {"counters": false, "baseCoin": false, "state": false}})], context)
	_assert(int(run.board.get_tile(0).counters["hits_remaining"]) == 8, "transform can reset counters")

func _test_relic_hooks() -> void:
	var run = _new_run(["T001"], 9)
	run.add_relic("Y001")
	TurnResolver.new().resolve_roll(run, ["red"], {"red": 1})
	_assert(run.round_score == 4, "coin relic modifies coin gain through hook")

	run = _new_run(["T020", "T000", "T000", "T000", "T000", "T000"], 10)
	run.add_relic("Y004")
	TurnResolver.new().resolve_roll(run, ["red"], {"red": 6})
	var ghost_count = 0
	for tile in run.board.tiles:
		if tile.id == "T021":
			ghost_count += 1
	_assert(ghost_count >= 2, "graveyard relic listens after tile resolve and generates ghosts")

func _test_chain_limit() -> void:
	var run = _new_run(["T001", "T001", "T001", "T001"], 12)
	var resolver = EffectResolver.new()
	var turn = TurnContext.new()
	turn.max_chain_per_dice = 2
	var context = _context(run, turn, "red", 0)
	resolver.execute_commands([
		GameCommand.move_dice("red", 1),
		GameCommand.move_dice("red", 1),
		GameCommand.move_dice("red", 1)
	], context)
	var blocked = turn.events.any(func(event): return str(event.get("type", "")) == "chain_blocked")
	_assert(blocked, "extra move chain limit blocks infinite combos")

func _test_three_dice_order() -> void:
	var run = _new_run(["T001", "T002", "T004"], 13)
	run.dice["red"].index = 0
	run.dice["blue"].index = 0
	run.dice["green"].index = 0
	var turn = TurnResolver.new().resolve_roll(run, ["red", "blue", "green"], {"red": 1, "blue": 2, "green": 3})
	var order = []
	for event in turn.events:
		if str(event.get("type", "")) == "dice_landed":
			order.append(str(event.get("diceId", "")))
	_assert(order == ["red", "blue", "green"], "three dice landing order is stable")

func _test_main_flow_is_not_needed_for_new_tile_effect() -> void:
	var custom_defs = tile_defs.duplicate(true)
	var boosted = custom_defs["T001"].duplicate(true)
	boosted["baseCoin"] = 12
	custom_defs["T999"] = boosted
	custom_defs["T999"]["id"] = "T999"
	custom_defs["T999"]["name"] = "测试金币"
	var run = RunState.new()
	run.setup(custom_defs, relic_defs, buff_defs, 14, "T999", 1)
	TurnResolver.new().resolve_roll(run, ["red"], {"red": 1})
	_assert(run.round_score == 12, "new data-only tile resolves without changing Main")

func _test_rich_description_and_display_copy() -> void:
	RichDescription.configure_tile_index(tile_defs)
	var bbcode = RichDescription.to_bbcode("获得3金币，每销毁一个鬼魂地块，金币永久+1")
	_assert(bbcode.contains("[url=tile:T021]"), "rich description links tile names")
	_assert(bbcode.find("[url=tile:T021]", bbcode.find("[url=tile:T021]") + 1) == -1, "rich description does not nest tile links")
	_assert(bbcode.contains("#ffd84a"), "rich description colors numbers")
	var definition = tile_defs["T001"].duplicate(true)
	definition["description"] = "功能描述"
	definition["displayDescription"] = "文案描述"
	var tile = TileRuntime.from_definition(definition, 1)
	_assert(tile.to_display_data()["tile_describe"] == "文案描述" and tile.to_display_data()["description"] == "功能描述", "display copy is separate from functional description")
