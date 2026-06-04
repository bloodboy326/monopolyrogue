extends RefCounted

const ICON_PATH_FORMAT = "res://assets/generated/map_icons/%s.png"

static var _texture_cache: Dictionary = {}

static func get_texture(icon_key: String) -> Texture2D:
	if icon_key.is_empty():
		return null
	if _texture_cache.has(icon_key):
		return _texture_cache[icon_key]
	var path = ICON_PATH_FORMAT % icon_key
	if not ResourceLoader.exists(path):
		_texture_cache[icon_key] = null
		return null
	var texture = load(path) as Texture2D
	_texture_cache[icon_key] = texture
	return texture

static func draw(canvas: CanvasItem, icon_key: String, rect: Rect2, modulate := Color.WHITE) -> bool:
	var texture = get_texture(icon_key)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, rect, false, modulate)
	return true
