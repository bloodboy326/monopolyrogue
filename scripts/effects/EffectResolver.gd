extends RefCounted

const GameCommand = preload("res://scripts/effects/GameCommand.gd")
const ResolveContext = preload("res://scripts/domain/ResolveContext.gd")
const TileEffectLibrary = preload("res://scripts/tiles/TileEffectLibrary.gd")
const HookBus = preload("res://scripts/systems/HookBus.gd")
const PositionResolver = preload("res://scripts/systems/PositionResolver.gd")
const DestroySystem = preload("res://scripts/systems/DestroySystem.gd")
const BuffSystem = preload("res://scripts/systems/BuffSystem.gd")

func execute_queue(context) -> void:
	while not context.turn_context.command_queue.is_empty():
		var command: Dictionary = context.turn_context.command_queue.pop_front()
		var followups = _execute_command(command, context)
		context.turn_context.enqueue_many(followups)

func execute_commands(commands: Array, context) -> void:
	context.turn_context.enqueue_many(commands)
	execute_queue(context)

func resolve_tile(context) -> void:
	if context.tile == null or not context.tile.is_triggerable():
		return
	context.turn_context.enqueue_many(HookBus.collect("beforeTileResolve", context, {}))
	execute_queue(context)
	context.turn_context.enqueue_many(TileEffectLibrary.resolve_tile(context))
	execute_queue(context)
	context.turn_context.enqueue_many(HookBus.collect("afterTileResolve", context, {}))
	execute_queue(context)

func execute_end_of_turn(context) -> void:
	for command in context.turn_context.scheduled_end_turn.duplicate(true):
		context.turn_context.enqueue(command)
	context.turn_context.scheduled_end_turn.clear()
	execute_queue(context)
	BuffSystem.decrement_turn_buffs(context.run_state)
	context.run_state.cleanup_end_of_turn()

func _execute_command(command: Dictionary, context) -> Array:
	match str(command.get("type", "")):
		"AddCoins":
			return _add_coins(command, context)
		"AddBuff":
			return _add_buff(command, context)
		"RemoveBuff":
			context.run_state.remove_buff(str(command.get("buffId", "")))
		"DestroyTile":
			return DestroySystem.apply(command, context)
		"TransformTile":
			return _transform_tile(command, context)
		"GenerateTile":
			return _generate_tile(command, context)
		"MoveDice":
			return _move_dice(command, context)
		"TeleportDice":
			return _teleport_dice(command, context)
		"ModifyTileCounter":
			return _modify_tile_counter(command, context)
		"ModifyTileBaseCoin":
			return _modify_tile_base_coin(command, context)
		"CopyTile":
			return _copy_tile(command, context)
		"AddRelic":
			return _add_relic(command, context)
		"AddTemporaryTile":
			return _add_temporary_tile(command, context)
		"ScheduleEndOfTurnEffect":
			context.turn_context.scheduled_end_turn.append(command.get("effect", {}))
		"TriggerTile":
			_trigger_tile(command, context)
		"ModifyRunCounter":
			_modify_run_counter(command, context)
		"ClearRunCounters":
			return _clear_run_counters(command, context)
	return []

func _add_coins(command: Dictionary, context) -> Array:
	var amount_value = command.get("amount", 0)
	var amount = context.tile.base_coin if typeof(amount_value) == TYPE_STRING and amount_value == "baseCoin" and context.tile != null else int(amount_value)
	var source_id = str(command.get("source", context.source_id))
	var source_tile = context.tile
	var payload = {"amount": amount, "sourceId": source_id, "sourceTile": source_tile}
	context.turn_context.enqueue_many(HookBus.collect("beforeGainCoins", context, payload))
	amount = int(payload.get("amount", amount))
	context.run_state.coins += amount
	context.run_state.round_score += amount
	context.turn_context.add_gain(amount, source_id, context.tile_index, context.dice.id if context.dice != null else "")
	var after_payload = {"amount": amount, "sourceId": source_id, "sourceTile": source_tile}
	return HookBus.collect("afterGainCoins", context, after_payload)

func _add_buff(command: Dictionary, context) -> Array:
	var raw_buff: Dictionary = command.get("buff", {})
	var buff_id = str(raw_buff.get("id", ""))
	if buff_id.is_empty():
		return []
	var definition = context.run_state.buff_definitions.get(buff_id, {})
	var source_id = str(raw_buff.get("sourceId", context.source_id))
	var dice_id = str(raw_buff.get("diceId", context.dice.id if context.dice != null else ""))
	var buff = BuffSystem.create_buff(buff_id, source_id, dice_id, definition, raw_buff)
	context.run_state.add_buff(buff)
	context.turn_context.emit_event("buff_added", {"buffId": buff_id, "diceId": dice_id, "sourceId": source_id})
	return []

func _transform_tile(command: Dictionary, context) -> Array:
	var index = context.run_state.board.normalize_index(int(command.get("tileIndex", context.tile_index)))
	var old_tile = context.run_state.board.get_tile(index)
	var new_tile = context.run_state.create_tile(str(command.get("targetTileId", "T000")))
	var inherit = command.get("options", {}).get("inherit", {})
	if bool(inherit.get("counters", false)):
		new_tile.counters = old_tile.counters.duplicate(true)
	if bool(inherit.get("baseCoin", false)):
		new_tile.base_coin = old_tile.base_coin
	if bool(inherit.get("state", false)):
		new_tile.state = old_tile.state.duplicate(true)
	context.turn_context.emit_event("tile_transforming", {"tileIndex": index, "fromTileId": old_tile.id, "toTileId": new_tile.id, "fromTileInstanceId": old_tile.instance_id})
	context.run_state.board.set_tile(index, new_tile)
	context.turn_context.emit_event("tile_transformed", {"tileIndex": index, "fromTileId": old_tile.id, "toTileId": new_tile.id, "fromTileInstanceId": old_tile.instance_id, "toTileInstanceId": new_tile.instance_id})
	return HookBus.collect("onTileTransform", context, {"tileIndex": index, "fromTile": old_tile, "toTile": new_tile})

func _generate_tile(command: Dictionary, context) -> Array:
	context.turn_context.enqueue_many(HookBus.collect("beforeGenerateTile", context, command))
	var index = PositionResolver.resolve(command.get("positionRule", {"type": "randomAny"}), context)
	var tile = context.run_state.create_tile(str(command.get("tileId", "T000")))
	var insert_at = clamp(index, 0, context.run_state.board.size())
	context.run_state.board.insert_tile(insert_at, tile)
	context.run_state.reindex_dice_after_insert(insert_at)
	if bool(tile.definition.get("temporary", false)) or bool(command.get("forceTemporary", false)):
		context.run_state.register_temporary_tile(tile)
		context.turn_context.temporary_tiles.append(tile.instance_id)
	context.turn_context.emit_event("tile_generated", {"tileIndex": insert_at, "tileId": tile.id, "tileInstanceId": tile.instance_id, "temporary": bool(tile.runtime_flags.get("temporary_tile", false))})
	return HookBus.collect("afterGenerateTile", context, {"tileIndex": insert_at, "tile": tile})

func _move_dice(command: Dictionary, context) -> Array:
	var dice_id = str(command.get("diceId", context.dice.id if context.dice != null else ""))
	var dice_state = context.run_state.dice.get(dice_id)
	if dice_state == null or context.run_state.board.is_empty():
		return []
	var payload = {"steps": int(command.get("steps", 0)), "diceId": dice_id}
	context.turn_context.enqueue_many(HookBus.collect("onDiceMove", context, payload))
	var steps = int(payload.get("steps", 0))
	dice_state.index = context.run_state.board.normalize_index(dice_state.index + steps)
	dice_state.extra_move_count += 1
	dice_state.chain_count += 1
	context.turn_context.emit_event("dice_moved", {"diceId": dice_id, "steps": steps, "targetIndex": dice_state.index})
	if dice_state.chain_count > context.turn_context.max_chain_per_dice:
		context.turn_context.emit_event("chain_blocked", {"diceId": dice_id, "reason": "max_chain"})
		return []
	return [GameCommand.trigger_tile(dice_state.index, dice_id, str(command.get("reason", "move")))]

func _teleport_dice(command: Dictionary, context) -> Array:
	var dice_id = str(command.get("diceId", context.dice.id if context.dice != null else ""))
	var dice_state = context.run_state.dice.get(dice_id)
	if dice_state == null:
		return []
	var target_index = PositionResolver.resolve(command.get("targetRule", {"type": "randomAny"}), context)
	dice_state.index = target_index
	dice_state.teleported = true
	dice_state.chain_count += 1
	context.turn_context.emit_event("dice_teleported", {"diceId": dice_id, "targetIndex": target_index})
	if dice_state.chain_count > context.turn_context.max_chain_per_dice:
		context.turn_context.emit_event("chain_blocked", {"diceId": dice_id, "reason": "max_chain"})
		return []
	return [GameCommand.trigger_tile(target_index, dice_id, str(command.get("reason", "teleport")))]

func _modify_tile_counter(command: Dictionary, context) -> Array:
	var index = context.run_state.board.normalize_index(int(command.get("tileIndex", context.tile_index)))
	var tile = context.run_state.board.get_tile(index)
	var key = str(command.get("counterKey", "value"))
	tile.counters[key] = int(tile.counters.get(key, 0)) + int(command.get("delta", 0))
	context.turn_context.emit_event("tile_counter_changed", {"tileIndex": index, "tileId": tile.id, "counterKey": key, "value": tile.counters[key]})
	var followups = HookBus.collect("onTileCounterChange", context, {"tileIndex": index, "tile": tile, "counterKey": key, "value": tile.counters[key]})
	var options: Dictionary = command.get("options", {})
	if options.has("threshold") and int(tile.counters[key]) <= int(options["threshold"]):
		var action: Dictionary = options.get("action", {})
		action["tileIndex"] = index
		followups.append(action)
	return followups

func _modify_tile_base_coin(command: Dictionary, context) -> Array:
	var index = context.run_state.board.normalize_index(int(command.get("tileIndex", context.tile_index)))
	var tile = context.run_state.board.get_tile(index)
	tile.base_coin += int(command.get("delta", 0))
	context.turn_context.emit_event("tile_base_coin_changed", {"tileIndex": index, "tileId": tile.id, "baseCoin": tile.base_coin})
	return []

func _copy_tile(command: Dictionary, context) -> Array:
	var source_index = context.run_state.board.normalize_index(int(command.get("sourceTileIndex", context.tile_index)))
	var source_tile = context.run_state.board.get_tile(source_index)
	var target_index = PositionResolver.resolve(command.get("targetPositionRule", {"type": "randomEmpty"}), context)
	var copy = source_tile.duplicate_runtime(context.run_state._tile_serial)
	context.run_state._tile_serial += 1
	var insert_at = clamp(target_index, 0, context.run_state.board.size())
	context.run_state.board.insert_tile(insert_at, copy)
	context.run_state.reindex_dice_after_insert(insert_at)
	context.turn_context.emit_event("tile_copied", {"sourceIndex": source_index, "targetIndex": insert_at, "tileId": source_tile.id})
	return []

func _add_relic(command: Dictionary, context) -> Array:
	var relic_id = str(command.get("relicId", ""))
	context.run_state.add_relic(relic_id)
	context.turn_context.emit_event("relic_added", {"relicId": relic_id})
	var relic_def = context.run_state.relic_definitions.get(relic_id, {})
	if relic_def.get("hooks", []).has("onRelicAdded"):
		return preload("res://scripts/relics/RelicLibrary.gd").handle_hook(relic_def, "onRelicAdded", context, {})
	return []

func _add_temporary_tile(command: Dictionary, context) -> Array:
	var generated = GameCommand.generate_tile(str(command.get("tileId", "T000")), command.get("positionRule", {"type": "randomEmpty"}))
	generated["forceTemporary"] = true
	generated["durationRule"] = command.get("durationRule", {"type": "round"})
	return [generated]

func _trigger_tile(command: Dictionary, context) -> void:
	var dice_state = context.run_state.dice.get(str(command.get("diceId", "")))
	if dice_state == null:
		return
	var index = context.run_state.board.normalize_index(int(command.get("tileIndex", dice_state.index)))
	var tile = context.run_state.board.get_tile(index)
	var nested = ResolveContext.new().setup(context.run_state, context.turn_context, dice_state, tile, index, dice_state.last_roll, str(command.get("reason", "effect")))
	dice_state.record_landing(index, tile.id, nested.reason)
	resolve_tile(nested)

func _modify_run_counter(command: Dictionary, context) -> void:
	var key = str(command.get("counterKey", "value"))
	context.run_state.fruit_counters[key] = int(context.run_state.fruit_counters.get(key, 0)) + int(command.get("delta", 0))
	context.turn_context.emit_event("run_counter_changed", {"counterKey": key, "value": context.run_state.fruit_counters[key]})

func _clear_run_counters(command: Dictionary, context) -> Array:
	var cleared = 0
	for key in command.get("counterKeys", []):
		cleared += int(context.run_state.fruit_counters.get(key, 0))
		context.run_state.fruit_counters[key] = 0
	context.turn_context.emit_event("run_counters_cleared", {"counterKeys": command.get("counterKeys", []), "clearedCount": cleared})
	return HookBus.collect("afterFruitClear", context, {"clearedCount": cleared})
