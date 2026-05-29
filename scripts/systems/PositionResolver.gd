extends RefCounted

static func resolve(rule: Dictionary, context) -> int:
	var run_state = context.run_state
	var board = run_state.board
	if board.is_empty():
		return 0
	match str(rule.get("type", "randomAny")):
		"randomEmpty":
			var empty = board.find_empty_indices()
			if empty.is_empty():
				return run_state.rng.randi_range(0, board.size() - 1)
			return run_state.rng.pick_array(empty)
		"randomAny":
			return run_state.rng.randi_range(0, board.size() - 1)
		"adjacentToSource":
			var source = int(rule.get("sourceIndex", context.tile_index))
			var options = [board.normalize_index(source - 1), board.normalize_index(source + 1)]
			return run_state.rng.pick_array(options)
		"nextToDice":
			var dice_index = context.dice.index if context.dice != null else context.tile_index
			var options = [board.normalize_index(dice_index - 1), board.normalize_index(dice_index + 1)]
			return run_state.rng.pick_array(options)
		"byTag":
			var indices = board.find_indices_by_tag(str(rule.get("tag", "")))
			if indices.is_empty():
				return run_state.rng.randi_range(0, board.size() - 1)
			var anchor = run_state.rng.pick_array(indices)
			return board.normalize_index(anchor + run_state.rng.pick_array([-1, 1]))
		"specificIndex":
			return board.normalize_index(int(rule.get("index", 0)))
		"weightedRandom":
			var weighted = []
			for item in rule.get("weights", []):
				if typeof(item) == TYPE_DICTIONARY:
					weighted.append(item)
			var picked = run_state.rng.pick_weighted(weighted)
			if picked == null:
				return run_state.rng.randi_range(0, board.size() - 1)
			return board.normalize_index(int(picked.get("index", 0)))
		_:
			return run_state.rng.randi_range(0, board.size() - 1)
