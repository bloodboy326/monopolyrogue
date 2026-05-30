extends RefCounted

var events: Array = []
var landed_tiles: Array = []
var landed_by_dice: Dictionary = {}
var damage_by_source: Dictionary = {}
var block_by_source: Dictionary = {}
var total_damage: int = 0
var total_block: int = 0
var total_gain: int = 0
var command_queue: Array = []
var scheduled_end_turn: Array = []
var temporary_destroyed: Array = []
var temporary_tiles: Array = []
var pending_destroy: Array = []
var resolve_depth: int = 0
var max_chain_per_dice: int = 3

func emit_event(event_type: String, payload: Dictionary = {}) -> void:
	var event = payload.duplicate(true)
	event["type"] = event_type
	events.append(event)

func enqueue(command: Dictionary) -> void:
	if not command.is_empty():
		command_queue.append(command)

func enqueue_many(commands: Array) -> void:
	for command in commands:
		enqueue(command)

func add_damage(amount: int, source_id: String, source_index: int, dice_id: String = "", blocked: int = 0) -> void:
	total_damage += amount
	damage_by_source[source_id] = int(damage_by_source.get(source_id, 0)) + amount
	emit_event("monster_damaged", {
		"amount": amount,
		"blocked": blocked,
		"sourceId": source_id,
		"sourceIndex": source_index,
		"diceId": dice_id,
		"turnTotal": total_damage
	})

func add_block(amount: int, source_id: String, source_index: int, dice_id: String = "") -> void:
	total_block += amount
	block_by_source[source_id] = int(block_by_source.get(source_id, 0)) + amount
	emit_event("player_block_added", {
		"amount": amount,
		"sourceId": source_id,
		"sourceIndex": source_index,
		"diceId": dice_id,
		"turnTotal": total_block
	})

func add_gain(amount: int, source_id: String, source_index: int, dice_id: String = "") -> void:
	total_gain += amount
	emit_event("legacy_gain", {"amount": amount, "sourceId": source_id, "sourceIndex": source_index, "diceId": dice_id})
