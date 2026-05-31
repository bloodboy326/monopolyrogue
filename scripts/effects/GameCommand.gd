extends RefCounted

static func damage_monster(amount, source: String = "", attack: bool = true) -> Dictionary:
	return {"type": "DamageMonster", "amount": amount, "source": source, "attack": attack}

static func add_player_block(amount: int, source: String = "") -> Dictionary:
	return {"type": "AddPlayerBlock", "amount": amount, "source": source}

static func add_rolls(amount: int, source: String = "") -> Dictionary:
	return {"type": "AddRolls", "amount": amount, "source": source}

static func add_next_turn_rolls(amount: int, source: String = "") -> Dictionary:
	return {"type": "AddNextTurnRolls", "amount": amount, "source": source}

static func add_roll_start_bonus(amount: int, source: String = "") -> Dictionary:
	return {"type": "AddRollStartBonus", "amount": amount, "source": source}

static func add_next_attack_multiplier(multiplier: float, source: String = "") -> Dictionary:
	return {"type": "AddNextAttackMultiplier", "multiplier": multiplier, "source": source}

static func increment_counter(counter_key: String, amount: int = 1, scope: String = "turn", source: String = "") -> Dictionary:
	return {"type": "IncrementCounter", "counterKey": counter_key, "amount": amount, "scope": scope, "source": source}

static func set_destroy_next_tile(source: String = "") -> Dictionary:
	return {"type": "SetDestroyNextTile", "source": source}

static func add_coins(amount, source: String = "") -> Dictionary:
	return damage_monster(int(amount), source, true)

static func add_buff(buff: Dictionary) -> Dictionary:
	return {"type": "AddBuff", "buff": buff}

static func remove_buff(buff_id: String) -> Dictionary:
	return {"type": "RemoveBuff", "buffId": buff_id}

static func destroy_tile(tile_index: int, destroy_mode = "permanent", source: String = "") -> Dictionary:
	return {"type": "DestroyTile", "tileIndex": tile_index, "destroyMode": destroy_mode, "source": source}

static func destroy_tile_instance(tile_index: int, tile_instance_id: String, destroy_mode = "permanent", source: String = "") -> Dictionary:
	return {"type": "DestroyTile", "tileIndex": tile_index, "tileInstanceId": tile_instance_id, "destroyMode": destroy_mode, "source": source}

static func destroy_tiles_by_rule(target_rule: Dictionary, source: String = "", destroy_mode = "permanent") -> Dictionary:
	return {"type": "DestroyTilesByRule", "targetRule": target_rule, "destroyMode": destroy_mode, "source": source}

static func consume_tile_durability(tile_index: int, tile_instance_id: String, source: String = "") -> Dictionary:
	return {"type": "ConsumeTileDurability", "tileIndex": tile_index, "tileInstanceId": tile_instance_id, "source": source}

static func add_durability_all(amount: int, source: String = "") -> Dictionary:
	return {"type": "AddDurabilityAll", "amount": amount, "source": source}

static func transform_tile(tile_index: int, target_tile_id: String, options: Dictionary = {}) -> Dictionary:
	return {"type": "TransformTile", "tileIndex": tile_index, "targetTileId": target_tile_id, "options": options}

static func transform_tile_for_battle(tile_index: int, target_tile_id: String, source: String = "") -> Dictionary:
	return {"type": "TransformTileForBattle", "tileIndex": tile_index, "targetTileId": target_tile_id, "source": source}

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

static func add_turn_start_tile(tile_id: String, count: int = 1, source: String = "") -> Dictionary:
	return {"type": "AddTurnStartTile", "tileId": tile_id, "count": count, "source": source}

static func set_all_pawns_next_roll(source: String = "") -> Dictionary:
	return {"type": "SetAllPawnsNextRoll", "source": source}

static func schedule_end_of_turn_effect(effect: Dictionary) -> Dictionary:
	return {"type": "ScheduleEndOfTurnEffect", "effect": effect}

static func trigger_tile(tile_index: int, dice_id: String, reason: String = "effect") -> Dictionary:
	return {"type": "TriggerTile", "tileIndex": tile_index, "diceId": dice_id, "reason": reason}
