extends RefCounted

static func add_coins(amount, source: String = "") -> Dictionary:
	return {"type": "AddCoins", "amount": amount, "source": source}

static func add_buff(buff: Dictionary) -> Dictionary:
	return {"type": "AddBuff", "buff": buff}

static func remove_buff(buff_id: String) -> Dictionary:
	return {"type": "RemoveBuff", "buffId": buff_id}

static func destroy_tile(tile_index: int, destroy_mode = "permanent", source: String = "") -> Dictionary:
	return {"type": "DestroyTile", "tileIndex": tile_index, "destroyMode": destroy_mode, "source": source}

static func transform_tile(tile_index: int, target_tile_id: String, options: Dictionary = {}) -> Dictionary:
	return {"type": "TransformTile", "tileIndex": tile_index, "targetTileId": target_tile_id, "options": options}

static func generate_tile(tile_id: String, position_rule: Dictionary) -> Dictionary:
	return {"type": "GenerateTile", "tileId": tile_id, "positionRule": position_rule}

static func move_dice(dice_id: String, steps: int, reason: String = "effect") -> Dictionary:
	return {"type": "MoveDice", "diceId": dice_id, "steps": steps, "reason": reason}

static func teleport_dice(dice_id: String, target_rule: Dictionary, reason: String = "effect") -> Dictionary:
	return {"type": "TeleportDice", "diceId": dice_id, "targetRule": target_rule, "reason": reason}

static func modify_tile_counter(tile_index: int, counter_key: String, delta: int, options: Dictionary = {}) -> Dictionary:
	return {"type": "ModifyTileCounter", "tileIndex": tile_index, "counterKey": counter_key, "delta": delta, "options": options}

static func modify_tile_base_coin(tile_index: int, delta: int) -> Dictionary:
	return {"type": "ModifyTileBaseCoin", "tileIndex": tile_index, "delta": delta}

static func modify_run_counter(counter_key: String, delta: int) -> Dictionary:
	return {"type": "ModifyRunCounter", "counterKey": counter_key, "delta": delta}

static func clear_run_counters(counter_keys: Array) -> Dictionary:
	return {"type": "ClearRunCounters", "counterKeys": counter_keys}

static func copy_tile(source_tile_index: int, target_position_rule: Dictionary) -> Dictionary:
	return {"type": "CopyTile", "sourceTileIndex": source_tile_index, "targetPositionRule": target_position_rule}

static func add_relic(relic_id: String) -> Dictionary:
	return {"type": "AddRelic", "relicId": relic_id}

static func add_temporary_tile(tile_id: String, duration_rule: Dictionary, position_rule: Dictionary) -> Dictionary:
	return {"type": "AddTemporaryTile", "tileId": tile_id, "durationRule": duration_rule, "positionRule": position_rule}

static func schedule_end_of_turn_effect(effect: Dictionary) -> Dictionary:
	return {"type": "ScheduleEndOfTurnEffect", "effect": effect}

static func trigger_tile(tile_index: int, dice_id: String, reason: String = "effect") -> Dictionary:
	return {"type": "TriggerTile", "tileIndex": tile_index, "diceId": dice_id, "reason": reason}
