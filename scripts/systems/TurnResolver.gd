extends RefCounted

const TurnContext = preload("res://scripts/domain/TurnContext.gd")
const ResolveContext = preload("res://scripts/domain/ResolveContext.gd")
const EffectResolver = preload("res://scripts/effects/EffectResolver.gd")

var effect_resolver = EffectResolver.new()

func plan_roll(run_state, dice_order: Array, dice_rolls: Dictionary) -> Dictionary:
	var plan = {"landings": {}, "paths": {}}
	for dice_id in dice_order:
		var dice_state = run_state.dice[dice_id]
		var roll = int(dice_rolls[dice_id])
		var path: Array[int] = []
		for step in range(1, roll + 1):
			path.append(run_state.board.normalize_index(dice_state.index + step))
		plan["paths"][dice_id] = path
		plan["landings"][dice_id] = path.back() if not path.is_empty() else dice_state.index
	return plan

func resolve_roll(run_state, dice_order: Array, dice_rolls: Dictionary) -> RefCounted:
	return resolve_planned_roll(run_state, dice_order, dice_rolls, plan_roll(run_state, dice_order, dice_rolls))

func resolve_planned_roll(run_state, dice_order: Array, dice_rolls: Dictionary, plan: Dictionary) -> RefCounted:
	run_state.begin_roll()
	var turn = TurnContext.new()
	turn.emit_event("turn_started", {"round": run_state.round_number})
	_record_paths(run_state, turn, dice_order, plan)
	_record_landings(run_state, turn, dice_order, dice_rolls, plan)
	for dice_id in dice_order:
		var dice_state = run_state.dice[dice_id]
		var landing: Dictionary = turn.landed_by_dice.get(dice_id, {})
		var tile = landing.get("tile")
		var tile_index = _current_landing_index(run_state, landing)
		if tile == null or tile_index == -1:
			turn.emit_event("dice_landing_skipped", {"diceId": dice_id, "reason": "tile_missing"})
			continue
		dice_state.index = tile_index
		dice_state.last_roll = int(dice_rolls[dice_id])
		dice_state.moved_steps = int(dice_rolls[dice_id])
		dice_state.record_landing(tile_index, tile.id, "roll")
		var context = ResolveContext.new().setup(run_state, turn, dice_state, tile, tile_index, dice_state.last_roll, "roll")
		effect_resolver.resolve_tile(context)
	var end_context = ResolveContext.new().setup(run_state, turn, null, null, -1, 0, "turn_end")
	effect_resolver.execute_end_of_turn(end_context)
	turn.emit_event("turn_ended", {"gain": turn.total_gain})
	return turn

func _record_landings(run_state, turn, dice_order: Array, dice_rolls: Dictionary, plan: Dictionary) -> void:
	for dice_id in dice_order:
		var tile_index = int(plan["landings"][dice_id])
		var tile = run_state.board.get_tile(tile_index)
		var landing = {"diceId": dice_id, "tileIndex": tile_index, "tile": tile, "tileInstanceId": tile.instance_id if tile != null else "", "diceValue": int(dice_rolls[dice_id])}
		turn.landed_tiles.append(landing)
		turn.landed_by_dice[dice_id] = landing
		turn.emit_event("dice_landed", {"diceId": dice_id, "tileIndex": tile_index, "tileId": tile.id})

func _record_paths(run_state, turn, dice_order: Array, plan: Dictionary) -> void:
	for dice_id in dice_order:
		for tile_index in plan["paths"].get(dice_id, []):
			var tile = run_state.board.get_tile(tile_index)
			turn.emit_event("dice_passed_tile", {"diceId": dice_id, "tileIndex": tile_index, "tileId": tile.id})
			_apply_passive_path_effect(run_state, turn, dice_id, tile_index, tile)

func _apply_passive_path_effect(run_state, turn, _dice_id: String, _tile_index: int, tile) -> void:
	if tile == null:
		return
	if tile.definition.get("passEffects", []).is_empty():
		return
	var context = ResolveContext.new().setup(run_state, turn, run_state.dice[_dice_id], tile, _tile_index, 0, "passed")
	effect_resolver.resolve_pass_tile(context)

func _current_landing_index(run_state, landing: Dictionary) -> int:
	var instance_id = str(landing.get("tileInstanceId", ""))
	if not instance_id.is_empty():
		return run_state.board.find_tile_index_by_instance(instance_id)
	if run_state.board.is_empty():
		return -1
	return run_state.board.normalize_index(int(landing.get("tileIndex", 0)))
