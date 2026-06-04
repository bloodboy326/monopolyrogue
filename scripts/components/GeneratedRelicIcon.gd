extends RefCounted

static var _cache: Dictionary = {}

static func get_texture(relic_id: String) -> Texture2D:
	if _cache.has(relic_id):
		return _cache[relic_id]
	var path = "res://assets/generated/relic_icons/%s.png" % relic_id
	if not ResourceLoader.exists(path):
		_cache[relic_id] = null
		return null
	var texture = load(path)
	_cache[relic_id] = texture
	return texture

static func draw(canvas: CanvasItem, relic_id: String, rect: Rect2) -> bool:
	var texture = get_texture(relic_id)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, rect, false)
	return true
