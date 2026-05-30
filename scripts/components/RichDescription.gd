extends RefCounted

const NUMBER_COLOR = "#ffd84a"
const TILE_COLOR = "#75d7ff"
const KEYWORD_COLOR = "#ff7d90"
const TEXT_COLOR = "#eef5ff"

static var tile_name_to_id := {}

static func configure_tile_index(tile_definitions: Dictionary) -> void:
	tile_name_to_id.clear()
	for tile_id in tile_definitions.keys():
		var definition: Dictionary = tile_definitions[tile_id]
		var name = str(definition.get("name", definition.get("tile_name", "")))
		if not name.is_empty():
			tile_name_to_id[name] = tile_id
			tile_name_to_id["%s地块" % name] = tile_id

static func to_bbcode(text: String) -> String:
	var result = _format_tile_links(_escape_bbcode(text))
	return "[color=%s]%s[/color]" % [TEXT_COLOR, result]

static func _format_tile_links(text: String) -> String:
	var result = ""
	var plain = ""
	var names = tile_name_to_id.keys()
	names.sort_custom(func(a, b): return str(a).length() > str(b).length())
	var i = 0
	while i < text.length():
		var match = _match_tile_at(text, i, names)
		if not match.is_empty():
			result += _format_plain(plain)
			plain = ""
			result += "[url=tile:%s][color=%s]%s[/color][/url]" % [match["tile_id"], TILE_COLOR, match["text"]]
			i += str(match["text"]).length()
			continue
		plain += text.substr(i, 1)
		i += 1
	return result + _format_plain(plain)

static func _match_tile_at(text: String, index: int, names: Array) -> Dictionary:
	for raw_name in names:
		var name = str(raw_name)
		if name.is_empty():
			continue
		var escaped_name = _escape_bbcode(name)
		if text.substr(index, escaped_name.length()) == escaped_name:
			return {"text": escaped_name, "tile_id": str(tile_name_to_id[name])}
	return {}

static func _format_plain(text: String) -> String:
	var result = _colorize_numbers(text)
	for keyword in ["伤害", "护盾", "护甲", "攻击", "防御", "骰子", "销毁", "生成", "变成", "额外", "翻倍", "废墟"]:
		result = result.replace(keyword, "[color=%s]%s[/color]" % [KEYWORD_COLOR, keyword])
	return result

static func _colorize_numbers(text: String) -> String:
	var result = ""
	var i = 0
	var inside_tag = false
	while i < text.length():
		var c = text.substr(i, 1)
		if c == "[":
			inside_tag = true
			result += c
			i += 1
			continue
		if c == "]":
			inside_tag = false
			result += c
			i += 1
			continue
		if inside_tag:
			result += c
			i += 1
			continue
		var starts_number = c.is_valid_int() or (c == "-" and i + 1 < text.length() and text.substr(i + 1, 1).is_valid_int()) or (c == "+" and i + 1 < text.length() and text.substr(i + 1, 1).is_valid_int())
		if starts_number:
			var start = i
			i += 1
			while i < text.length() and text.substr(i, 1).is_valid_int():
				i += 1
			var number_text = text.substr(start, i - start)
			result += "[color=%s]%s[/color]" % [NUMBER_COLOR, number_text]
		else:
			result += c
			i += 1
	return result

static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "\\[").replace("]", "\\]")
