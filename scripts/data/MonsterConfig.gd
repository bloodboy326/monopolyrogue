extends RefCounted

const MONSTER_CONFIG_PATH = "res://data/monster_config.json"

static func load_config() -> Dictionary:
	if not FileAccess.file_exists(MONSTER_CONFIG_PATH):
		return {}
	var file = FileAccess.open(MONSTER_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _index_tables(parsed)

static func battle_for(config: Dictionary, battle_number: int) -> Dictionary:
	for battle in config.get("battles", []):
		if typeof(battle) == TYPE_DICTIONARY and int(battle.get("battle", 0)) == battle_number:
			return battle
	return {"battle": battle_number, "monster_id": "slime", "rolls": 3}

static func battle_count(config: Dictionary) -> int:
	return config.get("battles", []).size()

static func monster(config: Dictionary, monster_id: String) -> Dictionary:
	return config.get("monsters_by_id", {}).get(monster_id, {})

static func encounter(config: Dictionary, monster_id: String) -> Dictionary:
	var monster_def = monster(config, monster_id).duplicate(true)
	if monster_def.is_empty():
		return monster_def
	var units: Array = []
	for raw_unit in monster_def.get("units", []):
		if typeof(raw_unit) != TYPE_DICTIONARY:
			continue
		var unit_id = str(raw_unit.get("monster_id", ""))
		var base = monster(config, unit_id).duplicate(true)
		if base.is_empty():
			base = raw_unit.duplicate(true)
		else:
			for key in raw_unit.keys():
				base[key] = raw_unit[key]
		units.append(base)
	if not units.is_empty():
		monster_def["units"] = units.slice(0, 3)
	return monster_def

static func choose_intent(config: Dictionary, run_state) -> Dictionary:
	var phase = phase_for(config, run_state.monster_id, run_state.monster_hp, run_state.monster_max_hp, run_state.battle_turn)
	var pool_id = str(phase.get("intent_pool", ""))
	run_state.current_phase_id = str(phase.get("phase_id", ""))
	var sequence_intent = _sequence_intent_id(phase, run_state.battle_turn)
	if not sequence_intent.is_empty():
		var sequence_result = config.get("intents_by_id", {}).get(sequence_intent, {}).duplicate(true)
		sequence_result["effects"] = effects_for_intent(config, sequence_intent)
		return sequence_result
	var candidates = _available_pool_entries(config, pool_id, run_state, true)
	if candidates.is_empty():
		candidates = _available_pool_entries(config, pool_id, run_state, false)
	if candidates.is_empty():
		return {}
	var picked = run_state.rng.pick_weighted(candidates)
	if picked == null:
		return {}
	var intent_id = str(picked.get("intent_id", ""))
	var intent = config.get("intents_by_id", {}).get(intent_id, {}).duplicate(true)
	intent["effects"] = effects_for_intent(config, intent_id)
	return intent

static func choose_intent_for_unit(config: Dictionary, run_state, unit_index: int) -> Dictionary:
	if unit_index < 0 or unit_index >= run_state.enemy_units.size():
		return {}
	var unit: Dictionary = run_state.enemy_units[unit_index]
	var phase = phase_for(config, str(unit.get("monster_id", "")), int(unit.get("hp", 0)), int(unit.get("max_hp", 1)), run_state.battle_turn)
	var pool_id = str(phase.get("intent_pool", ""))
	unit["current_phase_id"] = str(phase.get("phase_id", ""))
	run_state.enemy_units[unit_index] = unit
	var sequence_intent = _sequence_intent_id(phase, run_state.battle_turn)
	if not sequence_intent.is_empty():
		var sequence_result = config.get("intents_by_id", {}).get(sequence_intent, {}).duplicate(true)
		sequence_result["effects"] = effects_for_intent(config, sequence_intent)
		return sequence_result
	var candidates = _available_pool_entries_for_values(config, pool_id, int(unit.get("hp", 0)), int(unit.get("max_hp", 1)), run_state.battle_turn, unit.get("intent_history", []), unit.get("intent_last_used", {}), true, run_state)
	if candidates.is_empty():
		candidates = _available_pool_entries_for_values(config, pool_id, int(unit.get("hp", 0)), int(unit.get("max_hp", 1)), run_state.battle_turn, unit.get("intent_history", []), unit.get("intent_last_used", {}), false, run_state)
	if candidates.is_empty():
		return {}
	var picked = run_state.rng.pick_weighted(candidates)
	if picked == null:
		return {}
	var intent_id = str(picked.get("intent_id", ""))
	var intent = config.get("intents_by_id", {}).get(intent_id, {}).duplicate(true)
	intent["effects"] = effects_for_intent(config, intent_id)
	return intent

static func phase_for(config: Dictionary, monster_id: String, hp: int, max_hp: int, turn: int) -> Dictionary:
	var fallback := {}
	var selected := {}
	for phase in config.get("phases", []):
		if typeof(phase) != TYPE_DICTIONARY or str(phase.get("monster_id", "")) != monster_id:
			continue
		if str(phase.get("enter_condition", "")) == "START":
			fallback = phase
		if _condition_met(str(phase.get("enter_condition", "")), hp, max_hp, turn):
			selected = phase
	return selected if not selected.is_empty() else fallback

static func effects_for_intent(config: Dictionary, intent_id: String) -> Array:
	var effects = []
	for effect in config.get("intent_effects", []):
		if typeof(effect) == TYPE_DICTIONARY and str(effect.get("intent_id", "")) == intent_id:
			effects.append(effect.duplicate(true))
	effects.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return effects

static func _index_tables(config: Dictionary) -> Dictionary:
	var indexed = config.duplicate(true)
	var monsters_by_id := {}
	for item in indexed.get("monsters", []):
		if typeof(item) == TYPE_DICTIONARY:
			monsters_by_id[str(item.get("monster_id", ""))] = item
	indexed["monsters_by_id"] = monsters_by_id
	var intents_by_id := {}
	for item in indexed.get("intents", []):
		if typeof(item) == TYPE_DICTIONARY:
			intents_by_id[str(item.get("intent_id", ""))] = item
	indexed["intents_by_id"] = intents_by_id
	return indexed

static func _available_pool_entries(config: Dictionary, pool_id: String, run_state, strict: bool) -> Array:
	return _available_pool_entries_for_values(config, pool_id, run_state.monster_hp, run_state.monster_max_hp, run_state.battle_turn, run_state.intent_history, run_state.intent_last_used, strict, run_state)

static func _available_pool_entries_for_values(config: Dictionary, pool_id: String, hp: int, max_hp: int, turn: int, history: Array, last_used: Dictionary, strict: bool, run_state = null) -> Array:
	var result = []
	for entry in config.get("intent_pools", []):
		if typeof(entry) != TYPE_DICTIONARY or str(entry.get("pool_id", "")) != pool_id:
			continue
		if int(entry.get("min_turn", 1)) > turn:
			continue
		if not _condition_met_with_state(str(entry.get("require", "")), hp, max_hp, turn, run_state):
			continue
		var forbid = str(entry.get("forbid", ""))
		if not forbid.is_empty() and _condition_met_with_state(forbid, hp, max_hp, turn, run_state):
			continue
		if strict and _is_blocked_by_history_values(entry, history, last_used, turn):
			continue
		result.append(entry)
	return result

static func _sequence_intent_id(phase: Dictionary, turn: int) -> String:
	var sequence: Array = phase.get("sequence", [])
	if sequence.is_empty():
		return ""
	var start_turn = int(phase.get("sequence_start_turn", 1))
	if turn < start_turn:
		return ""
	var index = (turn - start_turn) % sequence.size()
	return str(sequence[index])

static func _is_blocked_by_history(entry: Dictionary, run_state) -> bool:
	return _is_blocked_by_history_values(entry, run_state.intent_history, run_state.intent_last_used, run_state.battle_turn)

static func _is_blocked_by_history_values(entry: Dictionary, history: Array, last_used: Dictionary, turn: int) -> bool:
	var intent_id = str(entry.get("intent_id", ""))
	var cooldown = int(entry.get("cooldown", 0))
	if cooldown > 0 and last_used.has(intent_id):
		if turn - int(last_used[intent_id]) <= cooldown:
			return true
	var max_repeat = int(entry.get("max_repeat", 99))
	if max_repeat < 99 and _tail_repeat_count(history, intent_id) >= max_repeat:
		return true
	var max_uses = int(entry.get("max_uses", 0))
	if max_uses > 0 and _history_count(history, intent_id) >= max_uses:
		return true
	return false

static func _tail_repeat_count(history: Array, intent_id: String) -> int:
	var count = 0
	for i in range(history.size() - 1, -1, -1):
		if str(history[i]) != intent_id:
			break
		count += 1
	return count

static func _history_count(history: Array, intent_id: String) -> int:
	var count = 0
	for item in history:
		if str(item) == intent_id:
			count += 1
	return count

static func _condition_met_with_state(condition: String, hp: int, max_hp: int, turn: int, run_state) -> bool:
	if _condition_met(condition, hp, max_hp, turn):
		return true
	if condition.begins_with("TURN_MOD:"):
		var rest = condition.substr("TURN_MOD:".length())
		var parts = rest.split("=")
		if parts.size() != 2:
			return false
		var divisor = max(1, int(parts[0]))
		return turn % divisor == int(parts[1])
	if condition.begins_with("TILE_COUNT:"):
		if run_state == null:
			return false
		var rest = condition.substr("TILE_COUNT:".length())
		var ops = [">=", "<=", "==", ">", "<"]
		for op in ops:
			var op_index = rest.find(op)
			if op_index == -1:
				continue
			var tile_id = rest.substr(0, op_index)
			var threshold = int(rest.substr(op_index + op.length()))
			var count = run_state.count_tiles_by_id(tile_id)
			match op:
				">=":
					return count >= threshold
				"<=":
					return count <= threshold
				"==":
					return count == threshold
				">":
					return count > threshold
				"<":
					return count < threshold
	return false

static func _condition_met(condition: String, hp: int, max_hp: int, turn: int) -> bool:
	if condition.is_empty() or condition == "START":
		return true
	if condition.begins_with("HP_PCT<="):
		var threshold = float(condition.get_slice("<=", 1))
		return (float(hp) / max(1.0, float(max_hp))) * 100.0 <= threshold
	if condition.begins_with("HP_PCT>="):
		var threshold = float(condition.get_slice(">=", 1))
		return (float(hp) / max(1.0, float(max_hp))) * 100.0 >= threshold
	if condition.begins_with("TURN>="):
		return turn >= int(condition.get_slice(">=", 1))
	if condition.begins_with("TURN<="):
		return turn <= int(condition.get_slice("<=", 1))
	return false
