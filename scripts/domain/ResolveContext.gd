extends RefCounted

var run_state
var turn_context
var dice
var tile
var tile_index: int = -1
var dice_value: int = 0
var reason: String = "landed"
var source_id: String = ""
var payload: Dictionary = {}

func setup(p_run_state, p_turn_context, p_dice, p_tile, p_tile_index: int, p_dice_value: int, p_reason: String = "landed", p_payload: Dictionary = {}) -> RefCounted:
	run_state = p_run_state
	turn_context = p_turn_context
	dice = p_dice
	tile = p_tile
	tile_index = p_tile_index
	dice_value = p_dice_value
	reason = p_reason
	payload = p_payload
	source_id = tile.id if tile != null else ""
	return self
