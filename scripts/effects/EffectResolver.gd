extends RefCounted

const GameCommand = preload("res://scripts/effects/GameCommand.gd")
const ResolveContext = preload("res://scripts/domain/ResolveContext.gd")
const TileEffectLibrary = preload("res://scripts/tiles/TileEffectLibrary.gd")
const HookBus = preload("res://scripts/systems/HookBus.gd")
const PositionResolver = preload("res://scripts/systems/PositionResolver.gd")
const DestroySystemScript = preload("res://scripts/systems/DestroySystem.gd")
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
	if context.run_state.get_counter("battle", "destroy_next_tile") > 0:
		context.run_state.increment_counter("battle", "destroy_next_tile", -1)
		context.turn_context.enqueue(GameCommand.destroy_tile_instance(context.tile_index, context.tile.instance_id, {"type": "configured"}, "destroy_next_tile"))
		execute_queue(context)
		return
	if context.tile.has_tag("curse") and context.run_state.get_counter("battle", "purify_active") > 0:
		context.turn_context.enqueue(GameCommand.add_rolls(context.run_state.get_counter("battle", "purify_active"), "purify"))
		execute_queue(context)
	context.turn_context.enqueue_many(HookBus.collect("beforeTileResolve", context, {}))
	execute_queue(context)
	context.turn_context.enqueue_many(TileEffectLibrary.resolve_tile(context))
	execute_queue(context)
	context.turn_context.enqueue_many(HookBus.collect("afterTileResolve", context, {}))
	execute_queue(context)

func resolve_pass_tile(context) -> void:
	if context.tile == null or not context.tile.is_triggerable():
		return
	context.turn_context.enqueue_many(TileEffectLibrary.resolve_pass_tile(context))
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
		"DamageMonster":
			return _damage_monster(command, context)
		"AddPlayerBlock":
			_add_player_block(command, context)
		"AddRolls":
			_add_rolls(command, context)
		"AddNextTurnRolls":
			_add_next_turn_rolls(command, context)
		"AddRollStartBonus":
			_add_roll_start_bonus(command, context)
		"AddNextAttackMultiplier":
			_add_next_attack_multiplier(command, context)
		"IncrementCounter":
			_increment_counter(command, context)
		"SetDestroyNextTile":
			_set_destroy_next_tile(command, context)
		"AddBuff":
			return _add_buff(command, context)
		"RemoveBuff":
			context.run_state.remove_buff(str(command.get("buffId", "")))
		"DestroyTile":
			return DestroySystemScript.apply(command, context)
		"DestroyTilesByRule":
			return _destroy_tiles_by_rule(command, context)
		"ConsumeTileDurability":
			_consume_tile_durability(command, context)
		"AddDurabilityAll":
			_add_durability_all(command, context)
		"TransformTile":
			return _transform_tile(command, context, false)
		"TransformTileForBattle":
			return _transform_tile(command, context, true)
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
		"AddTurnStartTile":
			_add_turn_start_tile(command, context)
		"SetAllPawnsNextRoll":
			_set_all_pawns_next_roll(command, context)
		"ScheduleEndOfTurnEffect":
			context.turn_context.scheduled_end_turn.append(command.get("effect", {}))
		"TriggerTile":
			_trigger_tile(command, context)
		"ModifyRunCounter":
			_modify_run_counter(command, context)
		"ClearRunCounters":
			return []
	return []

func _damage_monster(command: Dictionary, context) -> Array:
	var raw_amount = max(0, _resolve_amount(command.get("amount", 0), context))
	if bool(command.get("attack", true)):
		raw_amount = int(round(float(raw_amount) * context.run_state.consume_next_attack_multiplier()))
	var blocked = min(context.run_state.monster_block, raw_amount)
	context.run_state.monster_block -= blocked
	var amount = max(0, raw_amount - blocked)
	context.run_state.monster_hp = max(0, context.run_state.monster_hp - amount)
	var source_id = str(command.get("source", context.source_id))
	context.turn_context.add_damage(amount, source_id, context.tile_index, context.dice.id if context.dice != null else "", blocked)
	return []

func _resolve_amount(raw_value, context) -> int:
	if typeof(raw_value) == TYPE_DICTIONARY:
		var formula: Dictionary = raw_value
		var scope = str(formula.get("scope", "turn"))
		var counter = str(formula.get("counter", ""))
		var base = int(formula.get("base", 0))
		var add = int(formula.get("add", 0))
		var multiplier = int(formula.get("multiplier", 1))
		match str(formula.get("type", "constant")):
			"counter":
				return (context.run_state.get_counter(scope, counter) + add) * multiplier
			"counter_add":
				return (base + context.run_state.get_counter(scope, counter) + add) * multiplier
			"rolls_left_plus":
				return (context.run_state.turn_rolls_left + add) * multiplier
			"dice_value":
				return (context.dice_value + add) * multiplier
			_:
				return int(formula.get("value", 0))
	return int(raw_value)

func _add_player_block(command: Dictionary, context) -> void:
	var amount = max(0, int(command.get("amount", 0)))
	context.run_state.player_block += amount
	context.turn_context.add_block(amount, str(command.get("source", context.source_id)), context.tile_index, context.dice.id if context.dice != null else "")

func _add_rolls(command: Dictionary, context) -> void:
	var amount = int(command.get("amount", 0))
	context.run_state.adjust_rolls(amount)
	context.turn_context.emit_event("rolls_added", {
		"amount": amount,
		"sourceId": str(command.get("source", context.source_id)),
		"sourceIndex": context.tile_index,
		"rollsLeft": context.run_state.turn_rolls_left,
		"rollsTotal": context.run_state.turn_rolls_total
	})

func _add_next_turn_rolls(command: Dictionary, context) -> void:
	var amount = int(command.get("amount", 0))
	context.run_state.add_next_turn_roll_bonus(amount)
	context.turn_context.emit_event("next_turn_rolls_added", {"amount": amount, "sourceId": str(command.get("source", context.source_id)), "sourceIndex": context.tile_index})

func _add_roll_start_bonus(command: Dictionary, context) -> void:
	var amount = int(command.get("amount", 0))
	context.run_state.roll_start_bonus += amount
	context.turn_context.emit_event("roll_start_bonus_added", {"amount": amount, "sourceId": str(command.get("source", context.source_id)), "sourceIndex": context.tile_index})

func _add_next_attack_multiplier(command: Dictionary, context) -> void:
	var multiplier = max(1.0, float(command.get("multiplier", 2.0)))
	context.run_state.next_attack_multiplier *= multiplier
	context.turn_context.emit_event("attack_multiplier_added", {"multiplier": context.run_state.next_attack_multiplier, "sourceId": str(command.get("source", context.source_id)), "sourceIndex": context.tile_index})

func _increment_counter(command: Dictionary, context) -> void:
	var counter_key = str(command.get("counterKey", "value"))
	var scope = str(command.get("scope", "turn"))
	var amount = int(command.get("amount", 1))
	var value = context.run_state.increment_counter(scope, counter_key, amount)
	context.turn_context.emit_event("counter_changed", {
		"counterKey": counter_key,
		"scope": scope,
		"amount": amount,
		"value": value,
		"sourceId": str(command.get("source", context.source_id)),
		"sourceIndex": context.tile_index
	})

func _set_destroy_next_tile(command: Dictionary, context) -> void:
	var value = context.run_state.increment_counter("battle", "destroy_next_tile", 1)
	context.turn_context.emit_event("destroy_next_tile_added", {"value": value, "sourceId": str(command.get("source", context.source_id)), "sourceIndex": context.tile_index})

func _consume_tile_durability(command: Dictionary, context) -> void:
	var event = context.run_state.consume_tile_durability(int(command.get("tileIndex", context.tile_index)), str(command.get("tileInstanceId", "")))
	if not event.is_empty():
		context.turn_context.emit_event(str(event.get("type", "tile_durability_changed")), event)

func _add_durability_all(command: Dictionary, context) -> void:
	for event in context.run_state.add_durability_to_all(int(command.get("amount", 0))):
		context.turn_context.emit_event(str(event.get("type", "tile_durability_changed")), event)

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

func _transform_tile(command: Dictionary, context, battle_only: bool) -> Array:
	var index = context.run_state.board.normalize_index(int(command.get("tileIndex", context.tile_index)))
	var old_tile = context.run_state.board.get_tile(index)
	if old_tile == null:
		return []
	var new_tile = context.run_state.create_tile(str(command.get("targetTileId", "T000")))
	var inherit = command.get("options", {}).get("inherit", {})
	if bool(inherit.get("counters", false)):
		new_tile.counters = old_tile.counters.duplicate(true)
	if bool(inherit.get("state", false)):
		new_tile.state = old_tile.state.duplicate(true)
	context.run_state.board.set_tile(index, new_tile)
	if battle_only:
		context.run_state.remember_battle_revert(new_tile.instance_id, old_tile.id)
	context.turn_context.emit_event("tile_transformed", {
		"tileIndex": index,
		"fromTileId": old_tile.id,
		"toTileId": new_tile.id,
		"fromTileInstanceId": old_tile.instance_id,
		"toTileInstanceId": new_tile.instance_id
	})
	return HookBus.collect("onTileTransform", context, {"tileIndex": index, "fromTile": old_tile, "toTile": new_tile})

func _destroy_tiles_by_rule(command: Dictionary, context) -> Array:
	var result = []
	var rule: Dictionary = command.get("targetRule", {})
	var source = str(command.get("source", context.source_id))
	var mode = command.get("destroyMode", {"type": "permanent"})
	for index in _indices_for_destroy_rule(rule, context):
		var tile = context.run_state.board.get_tile(index)
		if tile == null:
			continue
		result.append(GameCommand.destroy_tile_instance(index, tile.instance_id, mode, source))
	return result

func _indices_for_destroy_rule(rule: Dictionary, context) -> Array[int]:
	var board = context.run_state.board
	var result: Array[int] = []
	if board.is_empty():
		return result
	match str(rule.get("type", "random")):
		"adjacent":
			var left = board.normalize_index(context.tile_index - 1)
			var right = board.normalize_index(context.tile_index + 1)
			for index in [left, right]:
				if not result.has(index):
					result.append(index)
		"random":
			var count = max(1, int(rule.get("count", 1)))
			var exclude_current = bool(rule.get("excludeCurrent", true))
			var allow_empty = bool(rule.get("allowEmpty", false))
			var candidates: Array[int] = []
			for i in range(board.size()):
				if exclude_current and i == context.tile_index:
					continue
				var tile = board.get_tile(i)
				if tile == null:
					continue
				if not allow_empty and tile.id == "T000":
					continue
				candidates.append(i)
			while result.size() < count and not candidates.is_empty():
				var picked = int(context.run_state.rng.pick_array(candidates))
				result.append(picked)
				candidates.erase(picked)
		_:
			var index = board.normalize_index(int(rule.get("index", context.tile_index)))
			result.append(index)
	return result

func _generate_tile(command: Dictionary, context) -> Array:
	context.turn_context.enqueue_many(HookBus.collect("beforeGenerateTile", context, command))
	var index = PositionResolver.resolve(command.get("positionRule", {"type": "randomAny"}), context)
	var tile = context.run_state.create_tile(str(command.get("tileId", "T000")))
	var insert_at = clamp(index, 0, context.run_state.board.size())
	context.run_state.board.insert_tile(insert_at, tile)
	context.run_state.reindex_dice_after_insert(insert_at)
	if context.run_state.should_cleanup_after_battle(tile) or bool(command.get("forceTemporary", false)):
		context.run_state.register_temporary_tile(tile)
		context.turn_context.temporary_tiles.append(tile.instance_id)
	else:
		context.run_state.register_persistent_battle_tile(tile, insert_at)
	context.turn_context.emit_event("tile_generated", {"tileIndex": insert_at, "tileId": tile.id, "tileInstanceId": tile.instance_id, "temporary": bool(tile.runtime_flags.get("temporary_tile", false))})
	return HookBus.collect("afterGenerateTile", context, {"tileIndex": insert_at, "tile": tile})

func _move_dice(command: Dictionary, context) -> Array:
	var dice_id = str(command.get("diceId", context.dice.id if context.dice != null else ""))
	var dice_state = context.run_state.dice.get(dice_id)
	if dice_state == null or context.run_state.board.is_empty():
		return []
	var steps = int(command.get("steps", 0))
	var reason = str(command.get("reason", "effect"))
	var direction = -1 if steps < 0 else 1
	var distance = abs(steps)
	var path: Array[int] = []
	for offset in range(1, distance + 1):
		path.append(context.run_state.board.normalize_index(dice_state.index + direction * offset))
	if reason == "warp" and distance > 0:
		context.run_state.increment_counter("turn", "warp_count", 1)
	for target_index in path:
		var pass_tile = context.run_state.board.get_tile(target_index)
		if pass_tile == null:
			continue
		context.turn_context.emit_event("dice_passed_tile", {"diceId": dice_id, "tileIndex": target_index, "tileId": pass_tile.id, "reason": reason})
		var pass_context = ResolveContext.new().setup(context.run_state, context.turn_context, dice_state, pass_tile, target_index, 0, "%s_passed" % reason)
		resolve_pass_tile(pass_context)
	if not path.is_empty():
		dice_state.index = path.back()
	dice_state.extra_move_count += 1
	dice_state.chain_count += 1
	context.turn_context.emit_event("dice_moved", {"diceId": dice_id, "steps": steps, "targetIndex": dice_state.index})
	if dice_state.chain_count > context.turn_context.max_chain_per_dice:
		context.turn_context.emit_event("chain_blocked", {"diceId": dice_id, "reason": "max_chain"})
		return []
	return [GameCommand.trigger_tile(dice_state.index, dice_id, reason)]

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
	if tile == null:
		return []
	var key = str(command.get("counterKey", "value"))
	tile.counters[key] = int(tile.counters.get(key, 0)) + int(command.get("delta", 0))
	context.turn_context.emit_event("tile_counter_changed", {"tileIndex": index, "tileId": tile.id, "counterKey": key, "value": tile.counters[key]})
	return []

func _modify_tile_base_coin(command: Dictionary, context) -> Array:
	var index = context.run_state.board.normalize_index(int(command.get("tileIndex", context.tile_index)))
	var tile = context.run_state.board.get_tile(index)
	if tile == null:
		return []
	tile.base_coin += int(command.get("delta", 0))
	context.turn_context.emit_event("tile_base_value_changed", {"tileIndex": index, "tileId": tile.id, "baseValue": tile.base_coin})
	return []

func _copy_tile(command: Dictionary, context) -> Array:
	var source_index = context.run_state.board.normalize_index(int(command.get("sourceTileIndex", context.tile_index)))
	var source_tile = context.run_state.board.get_tile(source_index)
	if source_tile == null:
		return []
	var target_index = PositionResolver.resolve(command.get("targetPositionRule", {"type": "randomAny"}), context)
	var copy = source_tile.duplicate_runtime(context.run_state._tile_serial)
	context.run_state._tile_serial += 1
	var insert_at = clamp(target_index, 0, context.run_state.board.size())
	context.run_state.board.insert_tile(insert_at, copy)
	context.run_state.reindex_dice_after_insert(insert_at)
	if bool(copy.runtime_flags.get("temporary_tile", false)):
		context.run_state.register_temporary_tile(copy)
	else:
		context.run_state.register_persistent_battle_tile(copy, insert_at)
	context.turn_context.emit_event("tile_copied", {"sourceIndex": source_index, "targetIndex": insert_at, "tileId": source_tile.id})
	return []

func _add_relic(command: Dictionary, context) -> Array:
	var relic_id = str(command.get("relicId", ""))
	context.run_state.add_relic(relic_id)
	context.turn_context.emit_event("relic_added", {"relicId": relic_id})
	return []

func _add_temporary_tile(command: Dictionary, _context) -> Array:
	var generated = GameCommand.generate_tile(str(command.get("tileId", "T000")), command.get("positionRule", {"type": "randomAny"}))
	generated["forceTemporary"] = true
	generated["durationRule"] = command.get("durationRule", {"type": "battle"})
	return [generated]

func _add_turn_start_tile(command: Dictionary, context) -> void:
	context.run_state.add_turn_start_tile_spawn(str(command.get("tileId", "T000")), int(command.get("count", 1)))
	context.turn_context.emit_event("turn_start_tile_added", {"tileId": str(command.get("tileId", "T000")), "count": int(command.get("count", 1)), "sourceId": str(command.get("source", context.source_id)), "sourceIndex": context.tile_index})

func _set_all_pawns_next_roll(command: Dictionary, context) -> void:
	context.run_state.all_pawns_next_rolls += 1
	context.turn_context.emit_event("all_pawns_next_roll_added", {"sourceId": str(command.get("source", context.source_id)), "sourceIndex": context.tile_index})

func _trigger_tile(command: Dictionary, context) -> void:
	var dice_state = context.run_state.dice.get(str(command.get("diceId", "")))
	if dice_state == null:
		return
	var index = context.run_state.board.normalize_index(int(command.get("tileIndex", dice_state.index)))
	var tile = context.run_state.board.get_tile(index)
	if tile == null:
		return
	var nested = ResolveContext.new().setup(context.run_state, context.turn_context, dice_state, tile, index, dice_state.last_roll, str(command.get("reason", "effect")))
	dice_state.record_landing(index, tile.id, nested.reason)
	resolve_tile(nested)

func _modify_run_counter(_command: Dictionary, _context) -> void:
	var counter_key = str(_command.get("counterKey", "value"))
	var amount = int(_command.get("delta", 0))
	var value = _context.run_state.increment_counter("battle", counter_key, amount)
	_context.turn_context.emit_event("counter_changed", {"counterKey": counter_key, "scope": "battle", "amount": amount, "value": value, "sourceId": str(_command.get("source", _context.source_id)), "sourceIndex": _context.tile_index})
