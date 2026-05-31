extends RefCounted

const GameCommand = preload("res://scripts/effects/GameCommand.gd")

static func resolve_tile(context) -> Array:
	if context.tile == null:
		return []
	var effects = context.tile.definition.get("weakEffects", []) if context.tile.is_weak() else context.tile.definition.get("effects", [])
	var commands = _commands_from_effects(effects, context)
	if not context.tile.is_weak() and context.tile.max_durability() > 0:
		commands.append(GameCommand.consume_tile_durability(context.tile_index, context.tile.instance_id, context.source_id))
	return commands

static func resolve_pass_tile(context) -> Array:
	if context.tile == null:
		return []
	return _commands_from_effects(context.tile.definition.get("passEffects", []), context)

static func resolve_destroy_tile(context) -> Array:
	if context.tile == null:
		return []
	return _commands_from_effects(context.tile.definition.get("destroyEffects", []), context)

static func handle_event_hook(_hook_id: String, _hook_name: String, _listener_tile, _listener_index: int, _context, _payload: Dictionary) -> Array:
	return []

static func _commands_from_effects(effects: Array, context) -> Array:
	var commands = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if not _condition_met(effect.get("condition", {}), context):
			continue
		commands.append_array(_command_for_effect(effect, context))
	return commands

static func _command_for_effect(effect: Dictionary, context) -> Array:
	var source_id = context.tile.id if context.tile != null else ""
	match str(effect.get("type", "")):
		"damage":
			return [GameCommand.damage_monster(effect.get("value", effect.get("amount", 0)), source_id, bool(effect.get("attack", true)))]
		"damage_player":
			return [GameCommand.damage_player(_resolve_amount(effect.get("value", effect.get("amount", 0)), context), source_id, bool(effect.get("piercing", false)))]
		"block":
			return [GameCommand.add_player_block(_resolve_amount(effect.get("value", effect.get("amount", 0)), context), source_id)]
		"add_player_strength":
			return [GameCommand.add_player_strength(_resolve_amount(effect.get("value", effect.get("amount", 0)), context), source_id)]
		"add_player_dexterity":
			return [GameCommand.add_player_dexterity(_resolve_amount(effect.get("value", effect.get("amount", 0)), context), source_id)]
		"block_if_monster_attack":
			if context.run_state.is_monster_intent_attack():
				return [GameCommand.add_player_block(_resolve_amount(effect.get("value", 0), context), source_id)]
		"add_rolls":
			return [GameCommand.add_rolls(_resolve_amount(effect.get("value", 0), context), source_id)]
		"lose_rolls":
			return [GameCommand.add_rolls(-_resolve_amount(effect.get("value", 0), context), source_id)]
		"add_next_turn_rolls":
			return [GameCommand.add_next_turn_rolls(_resolve_amount(effect.get("value", 0), context), source_id)]
		"add_roll_start_bonus":
			return [GameCommand.add_roll_start_bonus(_resolve_amount(effect.get("value", 0), context), source_id)]
		"next_attack_multiplier":
			return [GameCommand.add_next_attack_multiplier(float(effect.get("value", 2.0)), source_id)]
		"increment_counter":
			return [GameCommand.increment_counter(str(effect.get("counter", "value")), _resolve_amount(effect.get("value", 1), context), str(effect.get("scope", "turn")), source_id)]
		"increment_source_counter":
			return [GameCommand.increment_counter(_source_counter_key(context, str(effect.get("counter", "value"))), _resolve_amount(effect.get("value", 1), context), str(effect.get("scope", "battle")), source_id)]
		"modify_self_counter":
			return [GameCommand.modify_tile_counter(context.tile_index, str(effect.get("counter", "value")), _resolve_amount(effect.get("value", 1), context))]
		"set_destroy_next_tile":
			return [GameCommand.set_destroy_next_tile(source_id)]
		"add_durability_all":
			return [GameCommand.add_durability_all(_resolve_amount(effect.get("value", effect.get("amount", 0)), context), source_id)]
		"add_turn_start_tile":
			return [GameCommand.add_turn_start_tile(str(effect.get("tile", effect.get("tile_id", "T000"))), _resolve_amount(effect.get("count", 1), context), source_id)]
		"set_all_pawns_next_roll":
			return [GameCommand.set_all_pawns_next_roll(source_id)]
		"generate_tile":
			return _generate_tile_commands(effect, source_id, context)
		"move_self":
			if context.dice == null:
				return []
			return [GameCommand.move_dice(context.dice.id, _resolve_amount(effect.get("steps", effect.get("value", 0)), context), str(effect.get("reason", "effect")))]
		"destroy_tiles":
			var rule: Dictionary = effect.get("targetRule", {"type": str(effect.get("target", "random")), "count": int(effect.get("count", 1))})
			return [GameCommand.destroy_tiles_by_rule(rule, source_id, effect.get("destroyMode", {"type": "configured"}))]
		"transform_self_for_battle":
			return [GameCommand.transform_tile_for_battle(context.tile_index, str(effect.get("target", "T010")), source_id)]
		"destroy_self":
			if context.tile == null:
				return []
			return [GameCommand.destroy_tile_instance(context.tile_index, context.tile.instance_id, effect.get("destroyMode", {"type": "configured"}), source_id)]
	return []

static func _generate_tile_commands(effect: Dictionary, source_id: String, context) -> Array:
	var commands = []
	var tile_id = str(effect.get("tile", effect.get("tile_id", effect.get("target", "T000"))))
	var count = max(0, _resolve_amount(effect.get("count", effect.get("value", 1)), context))
	var position_rule: Dictionary = effect.get("positionRule", {"type": str(effect.get("position", "randomAny"))})
	var temporary = bool(effect.get("temporary", false))
	for _i in range(count):
		if temporary:
			commands.append(GameCommand.add_temporary_tile(tile_id, effect.get("durationRule", {"type": "battle"}), position_rule))
		else:
			var command = GameCommand.generate_tile(tile_id, position_rule)
			command["source"] = source_id
			commands.append(command)
	return commands

static func _resolve_amount(raw_value, context) -> int:
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
			"counter_div":
				var divisor = max(1, int(formula.get("divisor", 1)))
				return int(floor(float(context.run_state.get_counter(scope, counter) + add) / float(divisor))) * multiplier
			"source_counter":
				return (base + context.run_state.get_counter(scope, _source_counter_key(context, counter)) + add) * multiplier
			"tile_counter":
				if context.tile == null:
					return base
				return (base + int(context.tile.counters.get(counter, 0)) + add) * multiplier
			"counter_add":
				return (base + context.run_state.get_counter(scope, counter) + add) * multiplier
			"rolls_left_plus":
				return (context.run_state.turn_rolls_left + add) * multiplier
			"dice_value":
				return (context.dice_value + add) * multiplier
			_:
				return int(formula.get("value", 0))
	return int(raw_value)

static func _condition_met(raw_condition, context) -> bool:
	if typeof(raw_condition) != TYPE_DICTIONARY:
		return true
	var condition: Dictionary = raw_condition
	if condition.is_empty():
		return true
	if condition.has("reason"):
		if context.reason != str(condition.get("reason", "")):
			return false
	if condition.has("reason_in"):
		var allowed: Array = condition.get("reason_in", [])
		if not allowed.has(context.reason):
			return false
	if bool(condition.get("monster_intent_attack", false)) and not context.run_state.is_monster_intent_attack():
		return false
	if bool(condition.get("player_damaged_in_battle", false)) and context.run_state.get_counter("battle", "player_damage_taken") <= 0:
		return false
	if condition.has("pawns_at_tile_at_least"):
		if _pawns_at_tile(context) < int(condition.get("pawns_at_tile_at_least", 0)):
			return false
	if condition.has("pawns_at_tile_at_most"):
		if _pawns_at_tile(context) > int(condition.get("pawns_at_tile_at_most", 0)):
			return false
	if condition.has("dice_extra_moves_less_than"):
		if context.dice == null:
			return false
		var limit = _resolve_amount(condition.get("dice_extra_moves_less_than", 0), context)
		if context.dice.extra_move_count >= limit:
			return false
	return true

static func _source_counter_key(context, counter: String) -> String:
	var instance_id = context.tile.instance_id if context.tile != null else context.source_id
	return "%s:%s" % [instance_id, counter]

static func _pawns_at_tile(context) -> int:
	if context.run_state == null:
		return 0
	var count = 0
	for dice_state in context.run_state.dice.values():
		if dice_state.index == context.tile_index:
			count += 1
	return count
