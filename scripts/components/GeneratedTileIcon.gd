extends RefCounted

const ICON_PATH_FORMAT = "res://assets/generated/tile_icons/%s.png"

static var _texture_cache: Dictionary = {}

static func get_texture(tile_id: String) -> Texture2D:
	if tile_id.is_empty():
		return null
	if _texture_cache.has(tile_id):
		return _texture_cache[tile_id]
	var path = ICON_PATH_FORMAT % tile_id
	if not ResourceLoader.exists(path):
		_texture_cache[tile_id] = null
		return null
	var texture = load(path) as Texture2D
	_texture_cache[tile_id] = texture
	return texture

static func draw(canvas: CanvasItem, tile_id: String, rect: Rect2) -> bool:
	var texture = get_texture(tile_id)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, rect, false)
	return true
