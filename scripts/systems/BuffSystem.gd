extends RefCounted

static var _serial := 1

static func create_buff(buff_id: String, source_id: String, dice_id: String, definition: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var duration_type = str(overrides.get("durationType", definition.get("durationType", "turns")))
	var remaining = int(overrides.get("remaining", definition.get("remaining", 1)))
	var buff = {
		"instanceId": "%s#%d" % [buff_id, _serial],
		"id": buff_id,
		"name": str(definition.get("name", buff_id)),
		"sourceId": source_id,
		"diceId": dice_id,
		"durationType": duration_type,
		"remaining": remaining,
		"tags": definition.get("tags", []).duplicate(true),
		"config": definition.get("config", {}).duplicate(true)
	}
	_serial += 1
	return buff

static func consume_trigger(buff: Dictionary) -> void:
	if str(buff.get("durationType", "")) == "triggers":
		buff["remaining"] = max(0, int(buff.get("remaining", 1)) - 1)

static func decrement_turn_buffs(run_state) -> void:
	for buff in run_state.buffs:
		if str(buff.get("durationType", "")) == "turns":
			buff["remaining"] = max(0, int(buff.get("remaining", 1)) - 1)
