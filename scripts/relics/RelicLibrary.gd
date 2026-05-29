extends RefCounted

const GameCommand = preload("res://scripts/effects/GameCommand.gd")

static func handle_hook(relic_def: Dictionary, hook_name: String, context, payload: Dictionary) -> Array:
	match str(relic_def.get("id", "")):
		"Y001":
			if hook_name == "beforeGainCoins":
				var source_tile = payload.get("sourceTile")
				if source_tile != null and source_tile.has_tag("coin") and int(payload.get("amount", 0)) > 0:
					payload["amount"] = int(payload["amount"]) + int(relic_def.get("config", {}).get("coinBonus", 1))
		"Y002":
			if hook_name == "beforeTileResolve" and context.tile != null and context.tile.has_tag("mine"):
				return [GameCommand.modify_tile_counter(context.tile_index, "hits_remaining", int(relic_def.get("config", {}).get("mineCounterBonus", -1)))]
		"Y003":
			return _handle_mining_manual(relic_def, hook_name, context, payload)
		"Y004":
			if hook_name == "afterTileResolve" and context.tile != null and context.tile.has_tag("graveyard"):
				var commands = []
				for i in range(int(relic_def.get("config", {}).get("count", 2))):
					commands.append(GameCommand.generate_tile(str(relic_def.get("config", {}).get("spawnTileId", "T021")), {"type": "randomEmpty"}))
				return commands
		"Y005":
			if hook_name == "beforeGainCoins":
				var source_tile = payload.get("sourceTile")
				if source_tile != null and source_tile.has_tag("vampire") and int(payload.get("amount", 0)) < 0:
					payload["amount"] = int(relic_def.get("config", {}).get("vampirePenalty", -2))
	return []

static func _handle_mining_manual(relic_def: Dictionary, hook_name: String, context, payload: Dictionary) -> Array:
	var target_ids = relic_def.get("config", {}).get("targetTileIds", [])
	var commands = []
	if hook_name == "onRelicAdded":
		for i in range(context.run_state.board.size()):
			var tile = context.run_state.board.get_tile(i)
			if target_ids.has(tile.id):
				commands.append(GameCommand.modify_tile_counter(i, "hits_remaining", int(relic_def.get("config", {}).get("counterBonus", 4))))
				commands.append(GameCommand.modify_tile_base_coin(i, int(relic_def.get("config", {}).get("baseCoinBonus", 2))))
	if hook_name == "afterGenerateTile" or hook_name == "onTileTransform":
		var tile_index = int(payload.get("tileIndex", -1))
		var tile = context.run_state.board.get_tile(tile_index)
		if tile != null and target_ids.has(tile.id):
			commands.append(GameCommand.modify_tile_counter(tile_index, "hits_remaining", int(relic_def.get("config", {}).get("counterBonus", 4))))
			commands.append(GameCommand.modify_tile_base_coin(tile_index, int(relic_def.get("config", {}).get("baseCoinBonus", 2))))
	return commands
