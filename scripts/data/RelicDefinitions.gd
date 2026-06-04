extends RefCounted

const RELIC_CONFIG_PATH = "res://data/relic_config.json"

static func all() -> Dictionary:
	var defs := {}
	var config = _load_config()
	for raw_relic in config.get("relics", []):
		if typeof(raw_relic) != TYPE_DICTIONARY:
			continue
		var definition = _normalize(raw_relic)
		defs[definition["id"]] = definition
	return defs

static func _load_config() -> Dictionary:
	if not FileAccess.file_exists(RELIC_CONFIG_PATH):
		return {}
	var file = FileAccess.open(RELIC_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func _normalize(raw_relic: Dictionary) -> Dictionary:
	var relic_id = str(raw_relic.get("id", "R000"))
	var name = str(raw_relic.get("name", relic_id))
	var description = str(raw_relic.get("displayDescription", raw_relic.get("description", "")))
	return {
		"id": relic_id,
		"name": name,
		"type": str(raw_relic.get("type", "")),
		"rarity": str(raw_relic.get("rarity", "普通")),
		"rarity_code": str(raw_relic.get("rarity_code", "common")),
		"price": int(raw_relic.get("price", 0)),
		"description": str(raw_relic.get("description", description)),
		"displayDescription": description,
		"icon_kind": str(raw_relic.get("icon_kind", "relic")),
		"effects": raw_relic.get("effects", []).duplicate(true),
	}
