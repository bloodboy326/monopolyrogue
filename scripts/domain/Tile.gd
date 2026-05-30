extends RefCounted

var id: String = "T000"
var instance_id: String = "T000#0"
var name: String = "空地"
var type: String = "empty"
var rarity: String = "普通"
var base_coin: int = 0
var tags: Array = []
var counters: Dictionary = {}
var state: Dictionary = {}
var runtime_flags: Dictionary = {}
var definition: Dictionary = {}

static func from_definition(definition_data: Dictionary, serial: int = 0) -> RefCounted:
	var tile = preload("res://scripts/domain/Tile.gd").new()
	tile.definition = definition_data.duplicate(true)
	tile.id = str(definition_data.get("id", "T000"))
	tile.instance_id = "%s#%d" % [tile.id, serial]
	tile.name = str(definition_data.get("name", definition_data.get("tile_name", tile.id)))
	tile.type = str(definition_data.get("type", definition_data.get("kind", "generic")))
	tile.rarity = str(definition_data.get("rarity", definition_data.get("tile_rare", "普通")))
	tile.base_coin = int(definition_data.get("baseCoin", definition_data.get("base_coin", 0)))
	tile.tags = definition_data.get("tags", []).duplicate(true)
	tile.counters = definition_data.get("counters", {}).duplicate(true)
	tile.state = definition_data.get("state", {}).duplicate(true)
	tile.runtime_flags = definition_data.get("runtimeFlags", {}).duplicate(true)
	return tile

func duplicate_runtime(new_serial: int = -1) -> RefCounted:
	var tile = preload("res://scripts/domain/Tile.gd").new()
	tile.definition = definition.duplicate(true)
	tile.id = id
	tile.instance_id = instance_id if new_serial < 0 else "%s#%d" % [id, new_serial]
	tile.name = name
	tile.type = type
	tile.rarity = rarity
	tile.base_coin = base_coin
	tile.tags = tags.duplicate(true)
	tile.counters = counters.duplicate(true)
	tile.state = state.duplicate(true)
	tile.runtime_flags = runtime_flags.duplicate(true)
	return tile

func has_tag(tag: String) -> bool:
	return tags.has(tag) or type == tag

func is_empty() -> bool:
	return id == "T000" or has_tag("empty")

func is_triggerable() -> bool:
	return not is_empty() and not bool(runtime_flags.get("temporarily_destroyed", false))

func to_display_data() -> Dictionary:
	var display_description = str(definition.get("displayDescription", definition.get("地块文案描述", definition.get("tile_display_description", definition.get("description", definition.get("tile_describe", ""))))))
	return {
		"id": id,
		"instance_id": instance_id,
		"kind": str(definition.get("icon_kind", definition.get("kind", type))),
		"type": type,
		"tile_name": name,
		"name": name,
		"tile_icon": int(definition.get("tile_icon", definition.get("icon", 0))),
		"icon": int(definition.get("tile_icon", definition.get("icon", 0))),
		"tile_rare": rarity,
		"tile_describe": display_description,
		"description": str(definition.get("description", definition.get("tile_describe", ""))),
		"displayDescription": display_description,
		"reward": base_coin,
		"baseCoin": base_coin,
		"color": _color_from_config(definition.get("color", [0.95, 0.36, 0.43, 1.0])),
		"accent": _color_from_config(definition.get("accent", [1.0, 0.86, 0.22, 1.0])),
		"tags": tags.duplicate(true),
		"counters": counters.duplicate(true),
		"state": state.duplicate(true),
		"runtime_flags": runtime_flags.duplicate(true)
	}

func _color_from_config(value) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		var alpha = float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return Color(0.95, 0.36, 0.43, 1.0)
