extends PanelContainer

const RichDescription = preload("res://scripts/components/RichDescription.gd")

var title_label: Label
var rarity_label: Label
var description_label: RichTextLabel
var rarity_colors = {
	"普通": Color(0.45, 0.83, 0.38, 1.0),
	"稀有": Color(0.36, 0.62, 1.0, 1.0),
	"非凡": Color(0.88, 0.40, 1.0, 1.0),
	"传说": Color(1.0, 0.72, 0.20, 1.0),
	"诅咒": Color(0.94, 0.12, 0.30, 1.0)
}

func _ready() -> void:
	z_index = 900
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _panel_style())

	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	stack.custom_minimum_size = Vector2(246, 0)
	add_child(stack)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	stack.add_child(title_label)

	rarity_label = Label.new()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(rarity_label)

	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.scroll_active = false
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(230, 0)
	description_label.add_theme_font_size_override("normal_font_size", 16)
	stack.add_child(description_label)

func show_tile(tile_data: Dictionary, anchor_global_pos: Vector2, viewport_rect: Rect2) -> void:
	title_label.text = str(tile_data.get("tile_name", tile_data.get("name", "")))
	var rarity = str(tile_data.get("tile_rare", tile_data.get("rarity", "普通")))
	rarity_label.text = rarity
	rarity_label.add_theme_color_override("font_color", rarity_colors.get(rarity, Color.WHITE))
	description_label.text = RichDescription.to_bbcode(str(tile_data.get("tile_describe", tile_data.get("description", ""))))
	_place(anchor_global_pos, viewport_rect)

func show_relic(relic_data: Dictionary, anchor_global_pos: Vector2, viewport_rect: Rect2) -> void:
	title_label.text = str(relic_data.get("name", relic_data.get("id", "")))
	var rarity = str(relic_data.get("rarity", "遗物"))
	rarity_label.text = rarity
	rarity_label.add_theme_color_override("font_color", rarity_colors.get(rarity, Color(1.0, 0.82, 0.24)))
	description_label.text = RichDescription.to_bbcode(str(relic_data.get("displayDescription", relic_data.get("description", ""))))
	_place(anchor_global_pos, viewport_rect)

func _place(anchor_global_pos: Vector2, viewport_rect: Rect2) -> void:
	var desc_len = description_label.get_parsed_text().length()
	var estimated_lines = max(2, int(ceil(float(desc_len) / 14.0)))
	custom_minimum_size = Vector2(276, 88 + estimated_lines * 22)
	size = custom_minimum_size
	visible = true
	var tooltip_size = size
	if tooltip_size.x <= 1.0 or tooltip_size.y <= 1.0:
		tooltip_size = Vector2(270, 150)
	var pos = anchor_global_pos + Vector2(18, 18)
	if pos.x + tooltip_size.x > viewport_rect.end.x - 12.0:
		pos.x = anchor_global_pos.x - tooltip_size.x - 18.0
	if pos.y + tooltip_size.y > viewport_rect.end.y - 12.0:
		pos.y = viewport_rect.end.y - tooltip_size.y - 12.0
	pos.x = max(viewport_rect.position.x + 12.0, pos.x)
	pos.y = max(viewport_rect.position.y + 12.0, pos.y)
	global_position = pos

func hide_tooltip() -> void:
	visible = false

func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.052, 0.98)
	style.border_color = Color(1.0, 1.0, 1.0, 0.92)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 6
	style.shadow_offset = Vector2(6, 7)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
