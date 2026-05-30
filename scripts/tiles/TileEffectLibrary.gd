extends RefCounted

const GameCommand = preload("res://scripts/effects/GameCommand.gd")

static func resolve_tile(context) -> Array:
	var commands = []
	if context.tile == null or not context.tile.is_triggerable():
		return commands
	var definition: Dictionary = context.tile.definition
	if bool(definition.get("autoAddBaseCoin", true)) and context.tile.base_coin != 0:
		commands.append(GameCommand.add_coins(context.tile.base_coin, context.tile.id))
	for handler_id in definition.get("customHandlers", []):
		commands.append_array(_handle_custom(str(handler_id), context))
	return commands

static func handle_event_hook(hook_id: String, hook_name: String, _listener_tile, listener_index: int, _context, payload: Dictionary) -> Array:
	match hook_id:
		"mortuary_after_destroy":
			if hook_name == "afterDestroyTile":
				var destroyed_tile = payload.get("destroyedTile")
				if destroyed_tile != null and destroyed_tile.has_tag("ghost"):
					return [GameCommand.modify_tile_base_coin(listener_index, 1)]
		"vampire_lord_after_destroy":
			if hook_name == "afterDestroyTile":
				var destroyed_tile = payload.get("destroyedTile")
				if destroyed_tile != null and destroyed_tile.has_tag("vampire"):
					return [GameCommand.modify_tile_base_coin(listener_index, 5)]
		"jam_after_fruit_clear":
			if hook_name == "afterFruitClear" and int(payload.get("clearedCount", 0)) > 0:
				return [GameCommand.modify_tile_base_coin(listener_index, 5)]
	return []

static func _handle_custom(handler_id: String, context) -> Array:
	match handler_id:
		"piggy_bank":
			var stored = int(context.tile.counters.get("stored", 0))
			if stored <= 0:
				return []
			return [GameCommand.add_coins(stored, context.tile.id), GameCommand.modify_tile_counter(context.tile_index, "stored", -stored)]
		"mine_transform":
			return [_mine_counter_command(context, context.tile.state.get("counterTarget", "T007"))]
		"mine_destroy":
			return [_mine_counter_command(context, "")]
		"casino_parity":
			var want_odd = str(context.tile.state.get("parity", "odd")) == "odd"
			var is_odd = context.dice_value % 2 == 1
			if want_odd == is_odd:
				return [GameCommand.add_coins(int(context.tile.state.get("winCoin", 7)), context.tile.id)]
		"suit_bonus":
			if _turn_has_other_suit(context):
				return [GameCommand.add_coins(3, context.tile.id)]
		"joker_buff":
			return [GameCommand.add_buff({"id": "card_suit_double", "sourceId": context.tile.id, "diceId": "", "durationType": "untilEndOfTurn", "remaining": 1})]
		"card_shark":
			if _landed_card_count(context) >= 3:
				return [GameCommand.add_coins(50, context.tile.id)]
		"graveyard_spawn":
			return [GameCommand.generate_tile("T021", {"type": "randomEmpty"})]
		"coffin_spawn":
			return [GameCommand.generate_tile("T025", {"type": "randomEmpty"})]
		"destroy_self":
			return [GameCommand.destroy_tile(context.tile_index, {"type": "permanent"}, context.tile.id)]
		"bulldozer_buff":
			return [GameCommand.add_buff({"id": "destroy_on_resolve", "sourceId": context.tile.id, "diceId": context.dice.id, "durationType": "triggers", "remaining": 1})]
		"watering_buff":
			return [GameCommand.add_buff({"id": "watering", "sourceId": context.tile.id, "diceId": context.dice.id, "durationType": "turns", "remaining": 1})]
		"fruit_tree":
			return [GameCommand.modify_run_counter(str(context.tile.state.get("fruit", "apple")), 1)]
		"orchard_cashout":
			var fruit_total = 0
			for key in context.run_state.fruit_counters.keys():
				fruit_total += int(context.run_state.fruit_counters[key])
			if fruit_total <= 0:
				return []
			return [GameCommand.add_coins(fruit_total * 5, context.tile.id), GameCommand.clear_run_counters(context.run_state.fruit_counters.keys())]
	return []

static func _mine_counter_command(context, target_tile_id) -> Dictionary:
	var action: Dictionary
	if str(target_tile_id).is_empty():
		action = GameCommand.destroy_tile(context.tile_index, {"type": "permanent"}, context.tile.id)
	else:
		action = GameCommand.transform_tile(context.tile_index, str(target_tile_id), {"inherit": {"counters": false, "baseCoin": false, "state": false}})
	return GameCommand.modify_tile_counter(context.tile_index, "hits_remaining", -1, {"threshold": 0, "action": action})

static func _turn_has_other_suit(context) -> bool:
	for landing in context.turn_context.landed_tiles:
		var tile = landing.get("tile")
		if tile != null and tile.has_tag("suit") and tile.id != context.tile.id:
			return true
	return false

static func _landed_card_count(context) -> int:
	var count = 0
	for landing in context.turn_context.landed_tiles:
		var tile = landing.get("tile")
		if tile != null and tile.has_tag("card"):
			count += 1
	return count
