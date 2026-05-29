extends RefCounted

const BuffLibrary = preload("res://scripts/buffs/BuffLibrary.gd")
const RelicLibrary = preload("res://scripts/relics/RelicLibrary.gd")
const TileEffectLibrary = preload("res://scripts/tiles/TileEffectLibrary.gd")

static func collect(hook_name: String, context, payload: Dictionary = {}) -> Array:
	var commands = []
	for buff in context.run_state.get_active_buffs(context.dice.id if context.dice != null else ""):
		var definition = context.run_state.buff_definitions.get(str(buff.get("id", "")), {})
		if definition.get("hooks", []).has(hook_name):
			commands.append_array(BuffLibrary.handle_hook(buff, hook_name, context, payload))
	for relic_id in context.run_state.relics:
		var relic_def = context.run_state.relic_definitions.get(relic_id, {})
		if relic_def.get("hooks", []).has(hook_name):
			commands.append_array(RelicLibrary.handle_hook(relic_def, hook_name, context, payload))
	for i in range(context.run_state.board.size()):
		var listener_tile = context.run_state.board.get_tile(i)
		if listener_tile == null:
			continue
		for hook_id in listener_tile.definition.get("eventHooks", []):
			commands.append_array(TileEffectLibrary.handle_event_hook(str(hook_id), hook_name, listener_tile, i, context, payload))
	return commands
