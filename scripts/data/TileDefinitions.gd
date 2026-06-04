extends RefCounted

const TILE_CONFIG_PATH = "res://data/tile_config.json"

static func all() -> Dictionary:
	var defs := {}
	var config = _load_config()
	for raw_tile in config.get("tiles", []):
		if typeof(raw_tile) != TYPE_DICTIONARY:
			continue
		var definition = _normalize(raw_tile)
		defs[definition["id"]] = definition
	if not defs.has("T000"):
		defs["T000"] = _normalize({
			"id": "T000",
			"type": "空地",
			"name": "空地",
			"rarity": "普通",
			"description": "无",
			"selectable": false,
			"tags": ["empty"],
			"icon_kind": "empty",
			"effects": []
		})
	return defs

static func starting_deck() -> Array[String]:
	var result: Array[String] = []
	var config = _load_config()
	for tile_id in config.get("start_tiles", ["T001", "T002", "T001", "T002", "T001", "T002"]):
		result.append(str(tile_id))
	return result

static func _load_config() -> Dictionary:
	if not FileAccess.file_exists(TILE_CONFIG_PATH):
		return {}
	var file = FileAccess.open(TILE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func _normalize(raw_tile: Dictionary) -> Dictionary:
	var tile_id = str(raw_tile.get("id", "T000"))
	var name = str(raw_tile.get("name", raw_tile.get("tile_name", tile_id)))
	var type_name = str(raw_tile.get("type", raw_tile.get("kind", "技能")))
	var rarity = str(raw_tile.get("rarity", raw_tile.get("tile_rare", "普通")))
	var description = str(raw_tile.get("description", raw_tile.get("tile_describe", "")))
	var display_description = str(raw_tile.get("displayDescription", raw_tile.get("tile_display_description", description)))
	return {
		"id": tile_id,
		"name": name,
		"type": type_name,
		"rarity": rarity,
		"rarity_code": str(raw_tile.get("rarity_code", _rarity_code(rarity))),
		"baseCoin": 0,
		"description": description,
		"displayDescription": display_description,
		"tags": raw_tile.get("tags", []).duplicate(true),
		"selectable": bool(raw_tile.get("selectable", false)),
		"temporary": bool(raw_tile.get("temporary", false)),
		"destroy_after_battle": bool(raw_tile.get("destroy_after_battle", raw_tile.get("destroyAfterBattle", raw_tile.get("temporary", false)))),
		"durability": int(raw_tile.get("durability", 0)),
		"tile_name": name,
		"tile_rare": rarity,
		"tile_describe": display_description,
		"tile_icon": int(raw_tile.get("tile_icon", raw_tile.get("icon", 0))),
		"icon_kind": str(raw_tile.get("icon_kind", raw_tile.get("kind", type_name))),
		"color": raw_tile.get("color", [0.95, 0.36, 0.43, 1.0]),
		"accent": raw_tile.get("accent", [1.0, 0.86, 0.22, 1.0]),
		"counters": raw_tile.get("counters", {}).duplicate(true),
		"state": raw_tile.get("state", {}).duplicate(true),
		"customHandlers": raw_tile.get("customHandlers", []).duplicate(true),
		"eventHooks": raw_tile.get("eventHooks", []).duplicate(true),
		"effects": raw_tile.get("effects", []).duplicate(true),
		"weakEffects": raw_tile.get("weakEffects", []).duplicate(true),
		"passEffects": raw_tile.get("passEffects", []).duplicate(true),
		"destroyEffects": raw_tile.get("destroyEffects", []).duplicate(true),
		"autoAddBaseCoin": false
	}

static func _rarity_code(rarity: String) -> String:
	match rarity:
		"基础牌":
			return "basic"
		"普通":
			return "common"
		"稀有":
			return "rare"
		"非凡":
			return "uncommon"
		"诅咒":
			return "curse"
		_:
			return "common"
