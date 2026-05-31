extends RefCounted
class_name DestroySystem

const GameCommand = preload("res://scripts/effects/GameCommand.gd")
const ResolveContext = preload("res://scripts/domain/ResolveContext.gd")
const TileEffectLibrary = preload("res://scripts/tiles/TileEffectLibrary.gd")

static func apply(command: Dictionary, context) -> Array:
	var raw_mode = command.get("destroyMode", "permanent")
	var mode: Dictionary = raw_mode if typeof(raw_mode) == TYPE_DICTIONARY else {"type": str(raw_mode)}
	var handlers = {
		"permanent": "_apply_permanent",
		"configured": "_apply_configured",
		"temporary": "_apply_temporary",
		"afterTurn": "_apply_after_turn",
		"onStepImmediate": "_apply_on_step_immediate",
		"replaceWithEmpty": "_apply_replace_with_empty",
		"destroyThenMoveNextTurn": "_apply_destroy_then_move_next_turn",
		"destroyAndGenerate": "_apply_destroy_and_generate"
	}
	var mode_type = str(mode.get("type", "permanent"))
	match handlers.get(mode_type, "_apply_permanent"):
		"_apply_configured":
			return _apply_configured(command, context, mode)
		"_apply_temporary":
			return _apply_temporary(command, context, mode)
		"_apply_after_turn":
			return _apply_after_turn(command, context, mode)
		"_apply_on_step_immediate":
			return _apply_on_step_immediate(command, context, mode)
		"_apply_replace_with_empty":
			return _apply_replace_with_empty(command, context, mode)
		"_apply_destroy_then_move_next_turn":
			return _apply_destroy_then_move_next_turn(command, context, mode)
		"_apply_destroy_and_generate":
			return _apply_destroy_and_generate(command, context, mode)
		_:
			return _apply_permanent(command, context, mode)

static func _apply_configured(command: Dictionary, context, mode: Dictionary) -> Array:
	var index = _resolve_target_index(command, context)
	if index == -1:
		return []
	var tile = context.run_state.board.get_tile(index)
	if tile == null:
		return []
	if context.run_state.should_cleanup_after_battle(tile) or bool(tile.runtime_flags.get("temporary_tile", false)):
		return _apply_permanent(command, context, mode)
	return _apply_temporary(command, context, {"type": "temporary"})

static func _apply_permanent(command: Dictionary, context, mode: Dictionary) -> Array:
	var index = _resolve_target_index(command, context)
	if index == -1:
		return []
	var destroyed_tile = context.run_state.board.remove_tile(index)
	if destroyed_tile == null:
		return []
	context.run_state.forget_temporary_tile(destroyed_tile.instance_id)
	context.run_state.delete_count += 1
	_reindex_dice_after_remove(context, index)
	context.turn_context.emit_event("tile_destroyed", {"tileIndex": index, "tileId": destroyed_tile.id, "tileInstanceId": destroyed_tile.instance_id, "mode": mode.get("type", "permanent")})
	return _after_destroy_commands(context, destroyed_tile, index, mode)

static func _apply_temporary(command: Dictionary, context, mode: Dictionary) -> Array:
	var index = _resolve_target_index(command, context)
	if index == -1:
		return []
	var tile = context.run_state.board.get_tile(index)
	tile.runtime_flags["temporarily_destroyed"] = true
	context.turn_context.temporary_destroyed.append(tile.instance_id)
	context.turn_context.emit_event("tile_temporarily_destroyed", {"tileIndex": index, "tileId": tile.id, "tileInstanceId": tile.instance_id})
	return _after_destroy_commands(context, tile, index, mode)

static func _apply_after_turn(command: Dictionary, context, _mode: Dictionary) -> Array:
	var index = _resolve_target_index(command, context)
	if index == -1:
		return []
	var tile = context.run_state.board.get_tile(index)
	tile.runtime_flags["destroy_after_turn"] = true
	context.turn_context.scheduled_end_turn.append(GameCommand.destroy_tile(index, {"type": "permanent"}, str(command.get("source", ""))))
	context.turn_context.emit_event("tile_destroy_scheduled", {"tileIndex": index, "tileId": tile.id, "tileInstanceId": tile.instance_id})
	return []

static func _apply_on_step_immediate(command: Dictionary, context, mode: Dictionary) -> Array:
	return _apply_permanent(command, context, mode)

static func _apply_replace_with_empty(command: Dictionary, context, mode: Dictionary) -> Array:
	var index = _resolve_target_index(command, context)
	if index == -1:
		return []
	var destroyed_tile = context.run_state.board.get_tile(index)
	context.run_state.board.set_tile(index, context.run_state.create_tile("T000"))
	context.run_state.forget_temporary_tile(destroyed_tile.instance_id)
	context.run_state.delete_count += 1
	context.turn_context.emit_event("tile_replaced_with_empty", {"tileIndex": index, "tileId": destroyed_tile.id, "tileInstanceId": destroyed_tile.instance_id})
	return _after_destroy_commands(context, destroyed_tile, index, mode)

static func _apply_destroy_then_move_next_turn(command: Dictionary, context, mode: Dictionary) -> Array:
	var index = _resolve_target_index(command, context)
	if index == -1:
		return []
	var commands = _apply_permanent(command, context, mode)
	if context.dice != null and context.run_state.board.size() > 0:
		context.dice.next_turn_index_override = context.run_state.board.normalize_index(index)
	return commands

static func _apply_destroy_and_generate(command: Dictionary, context, mode: Dictionary) -> Array:
	var commands = _apply_permanent(command, context, mode)
	var tile_id = str(mode.get("generateTileId", "T000"))
	var position_rule = mode.get("positionRule", {"type": "specificIndex", "index": int(command.get("tileIndex", context.tile_index))})
	commands.append(GameCommand.generate_tile(tile_id, position_rule))
	return commands

static func _after_destroy_commands(context, destroyed_tile, index: int, mode: Dictionary) -> Array:
	var payload = {"destroyedTile": destroyed_tile, "tileIndex": index, "mode": mode}
	var commands = preload("res://scripts/systems/HookBus.gd").collect("afterDestroyTile", context, payload)
	var destroy_context = ResolveContext.new().setup(context.run_state, context.turn_context, context.dice, destroyed_tile, index, context.dice_value, "destroyed", payload)
	commands.append_array(TileEffectLibrary.resolve_destroy_tile(destroy_context))
	return commands

static func _reindex_dice_after_remove(context, removed_index: int) -> void:
	for dice_state in context.run_state.dice.values():
		if dice_state.index > removed_index:
			dice_state.index -= 1
		elif dice_state.index == removed_index and context.run_state.board.size() > 0:
			dice_state.index = context.run_state.board.normalize_index(removed_index)

static func _resolve_target_index(command: Dictionary, context) -> int:
	var instance_id = str(command.get("tileInstanceId", ""))
	if not instance_id.is_empty():
		return context.run_state.board.find_tile_index_by_instance(instance_id)
	if context.run_state.board.is_empty():
		return -1
	return context.run_state.board.normalize_index(int(command.get("tileIndex", context.tile_index)))
