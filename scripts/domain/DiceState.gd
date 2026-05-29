extends RefCounted

var id: String = ""
var index: int = 0
var last_roll: int = 0
var moved_steps: int = 0
var extra_move_count: int = 0
var teleported: bool = false
var resolve_history: Array = []
var next_turn_index_override: int = -1
var chain_count: int = 0

func _init(dice_id: String = "", start_index: int = 0) -> void:
	id = dice_id
	index = start_index

func begin_turn(board_size: int) -> void:
	_reset_resolve_flags()
	if next_turn_index_override >= 0 and board_size > 0:
		index = posmod(next_turn_index_override, board_size)
		next_turn_index_override = -1

func begin_roll() -> void:
	_reset_resolve_flags()

func _reset_resolve_flags() -> void:
	last_roll = 0
	moved_steps = 0
	extra_move_count = 0
	teleported = false
	resolve_history.clear()
	chain_count = 0

func record_landing(tile_index: int, tile_id: String, reason: String) -> void:
	resolve_history.append({"index": tile_index, "tileId": tile_id, "reason": reason})
