extends RefCounted

const GameCommand = preload("res://scripts/effects/GameCommand.gd")
const BuffSystem = preload("res://scripts/systems/BuffSystem.gd")

static func definitions() -> Dictionary:
	return {
		"watering": {
			"id": "watering",
			"name": "浇水",
			"durationType": "turns",
			"remaining": 1,
			"tags": ["plant", "utility"],
			"hooks": ["beforeTileResolve"],
			"config": {}
		},
		"destroy_on_resolve": {
			"id": "destroy_on_resolve",
			"name": "销毁",
			"durationType": "turns",
			"remaining": 1,
			"tags": ["destroy"],
			"hooks": ["afterTileResolve"],
			"config": {"blockedTileIds": ["T029"]}
		},
		"next_coin_multiplier": {
			"id": "next_coin_multiplier",
			"name": "倍率",
			"durationType": "triggers",
			"remaining": 1,
			"tags": ["coin", "multiplier"],
			"hooks": ["beforeGainCoins"],
			"config": {"multiplier": 2.0}
		},
		"protect_negative": {
			"id": "protect_negative",
			"name": "保护",
			"durationType": "triggers",
			"remaining": 1,
			"tags": ["protection"],
			"hooks": ["beforeGainCoins"],
			"config": {}
		},
		"extra_move_next": {
			"id": "extra_move_next",
			"name": "助推",
			"durationType": "triggers",
			"remaining": 1,
			"tags": ["move"],
			"hooks": ["onDiceMove"],
			"config": {"bonusSteps": 1}
		},
		"card_suit_double": {
			"id": "card_suit_double",
			"name": "花色倍率",
			"durationType": "untilEndOfTurn",
			"remaining": 1,
			"tags": ["card", "multiplier"],
			"hooks": ["beforeGainCoins"],
			"config": {"multiplier": 2.0, "targetTag": "suit"}
		}
	}

static func handle_hook(buff: Dictionary, hook_name: String, context, payload: Dictionary) -> Array:
	match str(buff.get("id", "")):
		"watering":
			if hook_name == "beforeTileResolve" and context.tile != null and context.tile.has_tag("sapling"):
				var target = str(context.tile.state.get("waterTarget", ""))
				if not target.is_empty():
					BuffSystem.consume_trigger(buff)
					return [GameCommand.transform_tile(context.tile_index, target, {"inherit": {"counters": false, "baseCoin": false, "state": false}})]
		"destroy_on_resolve":
			if hook_name == "afterTileResolve" and context.tile != null:
				var blocked = buff.get("config", {}).get("blockedTileIds", [])
				if not blocked.has(context.tile.id):
					BuffSystem.consume_trigger(buff)
					var target_index = context.run_state.board.find_tile_index_by_instance(context.tile.instance_id)
					if target_index == -1:
						return []
					return [GameCommand.destroy_tile_instance(target_index, context.tile.instance_id, {"type": "permanent"}, buff.get("id", ""))]
		"next_coin_multiplier":
			if hook_name == "beforeGainCoins" and int(payload.get("amount", 0)) > 0:
				payload["amount"] = int(round(float(payload["amount"]) * float(buff.get("config", {}).get("multiplier", 2.0))))
				BuffSystem.consume_trigger(buff)
		"protect_negative":
			if hook_name == "beforeGainCoins" and int(payload.get("amount", 0)) < 0:
				payload["amount"] = 0
				BuffSystem.consume_trigger(buff)
		"extra_move_next":
			if hook_name == "onDiceMove":
				payload["steps"] = int(payload.get("steps", 0)) + int(buff.get("config", {}).get("bonusSteps", 1))
				BuffSystem.consume_trigger(buff)
		"card_suit_double":
			if hook_name == "beforeGainCoins" and int(payload.get("amount", 0)) > 0:
				var source_tile = payload.get("sourceTile")
				if source_tile != null and source_tile.has_tag(str(buff.get("config", {}).get("targetTag", "suit"))):
					payload["amount"] = int(round(float(payload["amount"]) * float(buff.get("config", {}).get("multiplier", 2.0))))
	return []
