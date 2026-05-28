extends Control

signal batch_finished

const DiceAnimator = preload("res://scripts/components/DiceAnimator.gd")
const PawnMover = preload("res://scripts/components/PawnMover.gd")
const TileJuice = preload("res://scripts/components/TileJuice.gd")
const TileChoiceCard = preload("res://scripts/components/TileChoiceCard.gd")
const FloatingText = preload("res://scripts/components/FloatingText.gd")
const CoinBurst = preload("res://scripts/components/CoinBurst.gd")
const ScreenShake = preload("res://scripts/components/ScreenShake.gd")
const BoardPath = preload("res://scripts/components/BoardPath.gd")
const BG_SHADER = preload("res://shaders/background_flow.gdshader")
const ROUND_CONFIG_PATH = "res://data/round_config.json"
const TILE_CONFIG_PATH = "res://data/tile_config.json"
const BOARD_VIEW_SCALE = 1.0
const BOARD_START_ANGLE = -PI * 0.75

var rng = RandomNumberGenerator.new()

var world: Control
var background: ColorRect
var board_path: Control
var tile_layer: Control
var pawn_layer: Node2D
var effects_layer: Node2D
var hud_layer: Control
var dice_shell: PanelContainer
var dice_panel: HBoxContainer
var roll_button: Button
var counter_label: Label
var round_label: Label
var score_label: Label
var assets_label: Label
var roll_result_label: Label
var action_banner: Label
var cancel_action_button: Button
var round_flash: ColorRect
var choice_overlay: Control
var fail_overlay: Control
var shaker: Node

var tiles_data: Array[Dictionary] = []
var tile_nodes: Array = []
var tile_positions: Array[Vector2] = []
var pawn_nodes = {}
var dice_nodes = {}
var pawn_indices = {"red": 0, "blue": 2, "green": 4}
var pawn_order = ["red", "blue", "green"]
var color_defs = {
	"red": Color(1.0, 0.18, 0.30),
	"blue": Color(0.18, 0.62, 1.0),
	"green": Color(0.15, 1.0, 0.48)
}

var round_number = 1
var target_score = 18
var total_rolls = 3
var rolls_left = 3
var round_score = 0
var assets = 8
var mode = "play"
var roll_locked = false
var pending_tile: Dictionary = {}
var batch_remaining = 0
var round_configs: Array = []
var default_round_config = {"target_score": 27, "rolls": 3}
var tile_catalog = {}
var reward_tile_ids = ["market", "factory", "haunted_house"]

func _ready() -> void:
	rng.randomize()
	_load_tile_config()
	_load_round_config()
	_build_scene()
	_start_new_game()

func _build_scene() -> void:
	world = Control.new()
	world.name = "World"
	world.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)

	background = ColorRect.new()
	background.name = "NeonBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_material = ShaderMaterial.new()
	background_material.shader = BG_SHADER
	background.material = background_material
	world.add_child(background)

	board_path = BoardPath.new()
	board_path.name = "BoardPath"
	board_path.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.add_child(board_path)

	tile_layer = Control.new()
	tile_layer.name = "TileLayer"
	tile_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(tile_layer)

	pawn_layer = Node2D.new()
	pawn_layer.name = "PawnLayer"
	world.add_child(pawn_layer)

	effects_layer = Node2D.new()
	effects_layer.name = "EffectsLayer"
	add_child(effects_layer)

	hud_layer = Control.new()
	hud_layer.name = "HudLayer"
	hud_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_layer)

	round_flash = ColorRect.new()
	round_flash.name = "RoundFlash"
	round_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	round_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_flash.modulate.a = 0.0
	add_child(round_flash)

	_build_hud()
	_build_pawns()
	_build_overlays()

	shaker = ScreenShake.new()
	add_child(shaker)
	resized.connect(_on_resized)
	_on_resized()

func _build_hud() -> void:
	round_label = _make_label("第 1 轮", 34, Color(0.93, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	hud_layer.add_child(round_label)

	score_label = _make_label("金币 0 / 18", 28, Color(1.0, 0.93, 0.25), HORIZONTAL_ALIGNMENT_LEFT)
	hud_layer.add_child(score_label)

	assets_label = _make_label("资产 8", 22, Color(0.47, 1.0, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	hud_layer.add_child(assets_label)

	roll_result_label = _make_label("准备投掷", 22, Color(1.0, 0.72, 0.96), HORIZONTAL_ALIGNMENT_CENTER)
	hud_layer.add_child(roll_result_label)

	action_banner = _make_label("", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	action_banner.visible = false
	hud_layer.add_child(action_banner)

	cancel_action_button = _make_button("取消", Color(1.0, 0.28, 0.52))
	cancel_action_button.visible = false
	cancel_action_button.pressed.connect(_on_cancel_action)
	hud_layer.add_child(cancel_action_button)

	dice_shell = PanelContainer.new()
	dice_shell.name = "DiceDock"
	dice_shell.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.02, 0.08, 0.76), Color(0.0, 0.92, 1.0, 0.55), 8))
	hud_layer.add_child(dice_shell)

	dice_panel = HBoxContainer.new()
	dice_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_panel.add_theme_constant_override("separation", 14)
	dice_shell.add_child(dice_panel)

	for color_key in pawn_order:
		var dice = DiceAnimator.new()
		dice.name = "%sDice" % color_key.capitalize()
		dice.custom_minimum_size = Vector2(82, 82)
		dice.configure(color_defs[color_key], rng.randi_range(1, 6))
		dice_nodes[color_key] = dice
		dice_panel.add_child(dice)

	var roll_stack = VBoxContainer.new()
	roll_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	roll_stack.custom_minimum_size = Vector2(172, 82)
	dice_panel.add_child(roll_stack)

	roll_button = _make_button("掷骰", Color(1.0, 0.84, 0.14))
	roll_button.custom_minimum_size = Vector2(154, 48)
	roll_button.pressed.connect(_on_roll_pressed)
	roll_stack.add_child(roll_button)

	counter_label = _make_label("3 / 3", 18, Color(0.92, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	counter_label.custom_minimum_size = Vector2(154, 26)
	roll_stack.add_child(counter_label)

func _build_pawns() -> void:
	for color_key in pawn_order:
		var pawn = PawnMover.new()
		pawn.name = "%sPawn" % color_key.capitalize()
		var label_text: String = {"red": "R", "blue": "B", "green": "G"}[color_key]
		pawn.configure(color_defs[color_key], label_text)
		pawn.step_landed.connect(_on_pawn_step_landed.bind(color_key))
		pawn_nodes[color_key] = pawn
		pawn_layer.add_child(pawn)

func _build_overlays() -> void:
	choice_overlay = Control.new()
	choice_overlay.name = "ChoiceOverlay"
	choice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_overlay.visible = false
	choice_overlay.z_index = 200
	add_child(choice_overlay)

	fail_overlay = Control.new()
	fail_overlay.name = "FailOverlay"
	fail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fail_overlay.visible = false
	fail_overlay.z_index = 200
	add_child(fail_overlay)

func _start_new_game() -> void:
	round_number = 1
	assets = 8
	tiles_data.clear()
	for i in range(8):
		tiles_data.append(_make_tile("market"))
	_reset_pawn_indices()
	_start_round()

func _reset_pawn_indices() -> void:
	for color_key in pawn_order:
		pawn_indices[color_key] = 0

func _start_round() -> void:
	mode = "play"
	roll_locked = false
	pending_tile.clear()
	choice_overlay.visible = false
	fail_overlay.visible = false
	_set_action_banner("")
	round_score = 0
	_setup_round_values()
	rolls_left = total_rolls
	roll_result_label.text = "霓虹棋盘已就绪"
	_reset_pawn_indices()
	_rebuild_board_tiles()
	_position_pawns()
	_update_ui()
	_flash(Color(0.0, 0.9, 1.0, 0.16), 0.38)

func _setup_round_values() -> void:
	var config = _get_round_config(round_number)
	target_score = int(config.get("target_score", default_round_config["target_score"]))
	total_rolls = int(config.get("rolls", default_round_config["rolls"]))

func _load_round_config() -> void:
	if not FileAccess.file_exists(ROUND_CONFIG_PATH):
		return
	var file = FileAccess.open(ROUND_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.has("default") and typeof(data["default"]) == TYPE_DICTIONARY:
		default_round_config = data["default"]
	if data.has("rounds") and typeof(data["rounds"]) == TYPE_ARRAY:
		round_configs = data["rounds"]

func _get_round_config(target_round: int) -> Dictionary:
	for item in round_configs:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("round", -1)) == target_round:
			return item
	return default_round_config

func _load_tile_config() -> void:
	tile_catalog = _default_tile_catalog()
	if not FileAccess.file_exists(TILE_CONFIG_PATH):
		return
	var file = FileAccess.open(TILE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.has("reward_tiles") and typeof(data["reward_tiles"]) == TYPE_ARRAY:
		reward_tile_ids = data["reward_tiles"]
	if not data.has("tiles") or typeof(data["tiles"]) != TYPE_ARRAY:
		return
	for raw_tile in data["tiles"]:
		if typeof(raw_tile) != TYPE_DICTIONARY:
			continue
		var normalized = _normalize_tile_config(raw_tile)
		tile_catalog[normalized["id"]] = normalized

func _default_tile_catalog() -> Dictionary:
	return {
		"market": {
			"id": "market",
			"kind": "market",
			"tile_name": "集市",
			"tile_icon": 1,
			"tile_rare": "普通",
			"tile_describe": "踩中后获得3金币。",
			"name": "集市",
			"icon": 1,
			"reward": 3,
			"color": Color(0.02, 0.66, 0.78),
			"accent": Color(1.0, 0.82, 0.12)
		},
		"factory": {
			"id": "factory",
			"kind": "factory",
			"tile_name": "工厂",
			"tile_icon": 2,
			"tile_rare": "普通",
			"tile_describe": "踩中获得2金币。\n多个骰子同轮踩中时获得5金币。",
			"name": "工厂",
			"icon": 2,
			"reward": 2,
			"combo_reward": 5,
			"color": Color(0.33, 0.42, 0.62),
			"accent": Color(1.0, 0.42, 0.14)
		},
		"haunted_house": {
			"id": "haunted_house",
			"kind": "haunted_house",
			"tile_name": "鬼屋",
			"tile_icon": 3,
			"tile_rare": "稀有",
			"tile_describe": "偶数点数踩中失去3金币。\n奇数点数踩中获得5金币。",
			"name": "鬼屋",
			"icon": 3,
			"odd_reward": 5,
			"even_reward": -3,
			"color": Color(0.34, 0.12, 0.62),
			"accent": Color(0.42, 1.0, 0.64)
		}
	}

func _normalize_tile_config(raw_tile: Dictionary) -> Dictionary:
	var id = str(raw_tile.get("id", "market"))
	var fallback = tile_catalog.get(id, tile_catalog["market"])
	var tile = fallback.duplicate(true)
	tile["id"] = id
	tile["kind"] = str(raw_tile.get("kind", tile.get("kind", id)))
	tile["tile_name"] = str(raw_tile.get("tile_name", raw_tile.get("name", tile.get("tile_name", tile.get("name", id)))))
	tile["tile_icon"] = int(raw_tile.get("tile_icon", raw_tile.get("icon", tile.get("tile_icon", tile.get("icon", 0)))))
	tile["tile_rare"] = str(raw_tile.get("tile_rare", tile.get("tile_rare", "普通")))
	tile["tile_describe"] = str(raw_tile.get("tile_describe", tile.get("tile_describe", "")))
	tile["name"] = tile["tile_name"]
	tile["icon"] = tile["tile_icon"]
	for field in ["reward", "combo_reward", "odd_reward", "even_reward"]:
		if raw_tile.has(field):
			tile[field] = int(raw_tile[field])
	tile["color"] = _color_from_config(raw_tile.get("color", tile.get("color", Color(0.02, 0.66, 0.78))), tile.get("color", Color(0.02, 0.66, 0.78)))
	tile["accent"] = _color_from_config(raw_tile.get("accent", tile.get("accent", Color(1.0, 0.82, 0.12))), tile.get("accent", Color(1.0, 0.82, 0.12)))
	return tile

func _color_from_config(value, fallback: Color) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		var alpha = float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return fallback

func _on_roll_pressed() -> void:
	if roll_locked or mode != "play" or rolls_left <= 0:
		return
	roll_locked = true
	roll_button.disabled = true
	await _play_roll_turn()
	roll_locked = false
	_update_ui()

func _play_roll_turn() -> void:
	rolls_left -= 1
	_update_ui()
	roll_result_label.text = "骰子飞转中..."
	_pulse_node(roll_button, Vector2(0.96, 0.96), Vector2.ONE)

	var results = {}
	for color_key in pawn_order:
		results[color_key] = rng.randi_range(1, 6)

	batch_remaining = pawn_order.size()
	for color_key in pawn_order:
		dice_nodes[color_key].roll_finished.connect(_mark_batch_item_done, CONNECT_ONE_SHOT)
		dice_nodes[color_key].roll_to(results[color_key])
	await batch_finished

	roll_result_label.text = "棋子跳跃中..."
	batch_remaining = pawn_order.size()
	for color_key in pawn_order:
		pawn_nodes[color_key].movement_finished.connect(_on_pawn_movement_finished.bind(color_key), CONNECT_ONE_SHOT)
		pawn_nodes[color_key].move_steps(tile_positions, pawn_indices[color_key], results[color_key])
	await batch_finished

	var landing_counts = _get_landing_counts()
	var gain = 0
	for color_key in pawn_order:
		gain += await _trigger_tile_reward(color_key, pawn_indices[color_key], results[color_key], landing_counts)

	roll_result_label.text = "本次投掷 %s%d" % ["+" if gain >= 0 else "", gain]
	_pulse_node(roll_result_label, Vector2(1.18, 1.18), Vector2.ONE)
	if rolls_left <= 0:
		await get_tree().create_timer(0.45).timeout
		await _finish_round()

func _mark_batch_item_done() -> void:
	batch_remaining -= 1
	if batch_remaining <= 0:
		batch_finished.emit()

func _on_pawn_movement_finished(final_index: int, color_key: String) -> void:
	pawn_indices[color_key] = final_index
	_mark_batch_item_done()

func _get_landing_counts() -> Dictionary:
	var counts = {}
	for color_key in pawn_order:
		var index = pawn_indices[color_key]
		counts[index] = int(counts.get(index, 0)) + 1
	return counts

func _trigger_tile_reward(_color_key: String, tile_index: int, dice_value: int, landing_counts: Dictionary) -> int:
	if tile_index < 0 or tile_index >= tiles_data.size():
		return 0
	var data = tiles_data[tile_index]
	var reward = _get_tile_reward(data, tile_index, dice_value, landing_counts)
	var tile = tile_nodes[tile_index] as Control
	if tile.has_method("play_reward"):
		tile.play_reward()
	var start = tile_positions[tile_index]
	var end = score_label.global_position + score_label.size * 0.5
	var float_text = FloatingText.new()
	effects_layer.add_child(float_text)
	if reward >= 0:
		float_text.play("+%d" % reward, start + Vector2(0, -42), Color(1.0, 0.93, 0.24))
		var coins = CoinBurst.new()
		effects_layer.add_child(coins)
		coins.play(start, end, Color(1.0, 0.86, 0.12), 7)
	else:
		float_text.play("%d" % reward, start + Vector2(0, -42), Color(1.0, 0.24, 0.35))
		_negative_feedback(score_label)
	round_score += reward
	_update_ui()
	_pulse_node(score_label, Vector2(1.12, 1.12), Vector2.ONE)
	shaker.shake(world, 4.0, 0.14)
	await get_tree().create_timer(0.24).timeout
	return reward

func _get_tile_reward(data: Dictionary, tile_index: int, dice_value: int, landing_counts: Dictionary) -> int:
	match str(data.get("kind", "market")):
		"market":
			return int(data.get("reward", 3))
		"factory":
			if int(landing_counts.get(tile_index, 0)) > 1:
				return int(data.get("combo_reward", 5))
			return int(data.get("reward", 2))
		"haunted_house":
			if dice_value % 2 == 0:
				return int(data.get("even_reward", -3))
			return int(data.get("odd_reward", 5))
		_:
			return int(data.get("reward", 0))

func _finish_round() -> void:
	roll_button.disabled = true
	if round_score >= target_score:
		assets += 4 + max(0, int(float(round_score - target_score) / 3.0))
		_update_ui()
		roll_result_label.text = "目标达成，选择新地块"
		_flash(Color(1.0, 0.84, 0.12, 0.23), 0.5)
		shaker.shake(world, 8.0, 0.28)
		await get_tree().create_timer(0.42).timeout
		_show_choice_overlay()
	else:
		roll_result_label.text = "未达目标"
		_flash(Color(1.0, 0.05, 0.12, 0.28), 0.46)
		shaker.shake(world, 11.0, 0.35)
		await get_tree().create_timer(0.36).timeout
		_show_fail_overlay()

func _show_choice_overlay() -> void:
	mode = "choice"
	_update_ui()
	_clear_overlay(choice_overlay)
	choice_overlay.visible = true
	var viewport_size = get_viewport_rect().size
	var dim = _make_overlay_dim(Color(0.01, 0.0, 0.04, 0.76))
	choice_overlay.add_child(dim)
	var title = _make_label("通过第 %d 轮：选择一个地块" % round_number, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(viewport_size.x * 0.5 - 330, viewport_size.y * 0.16)
	title.size = Vector2(660, 48)
	choice_overlay.add_child(title)

	var card_width: float = clamp(viewport_size.x * 0.17, 180.0, 220.0)
	var card_height: float = clamp(viewport_size.y * 0.34, 230.0, 270.0)
	var gap: float = 18.0
	var total_width: float = card_width * 3.0 + gap * 2.0
	var start_x: float = viewport_size.x * 0.5 - total_width * 0.5
	var y: float = viewport_size.y * 0.28
	for i in range(3):
		var choice_data = _make_tile(reward_tile_ids[i % reward_tile_ids.size()])
		var card = TileChoiceCard.new()
		card.setup(i, choice_data)
		card.size = Vector2(card_width, card_height)
		card.custom_minimum_size = card.size
		card.position = Vector2(start_x + (card_width + gap) * i, y)
		card.pivot_offset = card.size * 0.5
		card.picked.connect(func(_idx: int) -> void:
			_on_reward_tile_chosen(choice_data)
		)
		choice_overlay.add_child(card)
		card.play_spawn()

	var skip = _make_button("跳过", Color(0.25, 0.75, 1.0))
	skip.position = Vector2(viewport_size.x * 0.5 - 86, viewport_size.y * 0.76)
	skip.size = Vector2(172, 52)
	skip.pressed.connect(_on_reward_skipped)
	choice_overlay.add_child(skip)

func _on_reward_tile_chosen(tile_data: Dictionary) -> void:
	pending_tile = tile_data.duplicate(true)
	choice_overlay.visible = false
	enter_insert_mode()

func _on_reward_skipped() -> void:
	choice_overlay.visible = false
	_after_round_reward_done()

func _after_round_reward_done() -> void:
	round_number += 1
	_start_round()

func enter_insert_mode() -> void:
	mode = "insert"
	_set_action_banner("选择一个地块：新地块会插在它后面")
	for tile in tile_nodes:
		tile.set_insert_hint(true)
	_update_ui()

func _on_tile_picked(index: int) -> void:
	if mode == "insert":
		_insert_pending_tile_after(index)

func _insert_pending_tile_after(index: int) -> void:
	if pending_tile.is_empty():
		return
	var insert_at: int = clamp(index + 1, 0, tiles_data.size())
	tiles_data.insert(insert_at, pending_tile.duplicate(true))
	for color_key in pawn_order:
		if pawn_indices[color_key] >= insert_at:
			pawn_indices[color_key] += 1
	pending_tile.clear()
	_clear_board_hints()
	_set_action_banner("")
	_rebuild_board_tiles()
	_position_pawns()
	_update_ui()
	if insert_at >= 0 and insert_at < tile_nodes.size():
		tile_nodes[insert_at].play_spawn()
	_flash(Color(0.0, 1.0, 0.76, 0.18), 0.32)
	_after_round_reward_done()

func _on_cancel_action() -> void:
	_clear_board_hints()
	_set_action_banner("")
	if mode == "insert":
		pending_tile.clear()
		_after_round_reward_done()
	else:
		mode = "play"
	_update_ui()

func _show_fail_overlay() -> void:
	mode = "fail"
	_update_ui()
	_clear_overlay(fail_overlay)
	fail_overlay.visible = true
	var viewport_size = get_viewport_rect().size
	fail_overlay.add_child(_make_overlay_dim(Color(0.08, 0.0, 0.025, 0.82)))
	var title = _make_label("游戏失败", 44, Color(1.0, 0.26, 0.38), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(viewport_size.x * 0.5 - 220, viewport_size.y * 0.28)
	title.size = Vector2(440, 60)
	fail_overlay.add_child(title)
	var detail = _make_label("第 %d 轮获得 %d / %d 金币" % [round_number, round_score, target_score], 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	detail.position = Vector2(viewport_size.x * 0.5 - 260, viewport_size.y * 0.4)
	detail.size = Vector2(520, 42)
	fail_overlay.add_child(detail)
	var retry = _make_button("重玩", Color(1.0, 0.84, 0.14))
	retry.position = Vector2(viewport_size.x * 0.5 - 90, viewport_size.y * 0.56)
	retry.size = Vector2(180, 56)
	retry.pressed.connect(_start_new_game)
	fail_overlay.add_child(retry)

func _rebuild_board_tiles() -> void:
	for child in tile_layer.get_children():
		tile_layer.remove_child(child)
		child.queue_free()
	tile_nodes.clear()
	tile_positions = _calculate_board_positions(tiles_data.size())
	board_path.set_points(tile_positions)
	var tile_size = _calculate_tile_size(tiles_data.size())
	for i in range(tiles_data.size()):
		var tile = TileJuice.new()
		tile.setup(i, tiles_data[i])
		tile.size = Vector2(tile_size, tile_size)
		tile.custom_minimum_size = tile.size
		tile.position = tile_positions[i] - tile.size * 0.5
		tile.pivot_offset = tile.size * 0.5
		tile.picked.connect(_on_tile_picked)
		tile_layer.add_child(tile)
		tile_nodes.append(tile)

func _position_pawns() -> void:
	if tile_positions.is_empty():
		return
	for color_key in pawn_order:
		var index = int(pawn_indices[color_key]) % tile_positions.size()
		pawn_indices[color_key] = index
		pawn_nodes[color_key].position = tile_positions[index] + _pawn_offset(color_key)

func _on_pawn_step_landed(tile_index: int, final_step: bool, color_key: String) -> void:
	if tile_index >= 0 and tile_index < tile_nodes.size():
		tile_nodes[tile_index].play_step(final_step)
	if final_step:
		pawn_nodes[color_key].play_final_pop()
		shaker.shake(world, 5.5, 0.16)
	else:
		shaker.shake(world, 1.8, 0.08)

func _calculate_board_positions(count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if count <= 0:
		return points
	var circle = _get_board_circle()
	var center: Vector2 = circle["center"]
	var radius: float = circle["radius"]
	for i in range(count):
		var angle = BOARD_START_ANGLE + TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _calculate_tile_size(count: int) -> float:
	var circle = _get_board_circle()
	var radius: float = circle["radius"]
	var spacing = TAU * radius / max(1.0, float(count))
	return clamp(spacing * 0.62, 46.0, 88.0)

func _get_board_circle() -> Dictionary:
	var viewport_size = get_viewport_rect().size
	var top_limit: float = clamp(viewport_size.y * 0.14, 92.0, 124.0)
	var bottom_limit: float = viewport_size.y - clamp(viewport_size.y * 0.26, 188.0, 224.0)
	var vertical_radius: float = max(120.0, (bottom_limit - top_limit) * 0.5)
	var horizontal_radius: float = max(120.0, viewport_size.x * 0.42)
	var radius: float = min(vertical_radius, horizontal_radius) * BOARD_VIEW_SCALE
	var center = Vector2(viewport_size.x * 0.5, (top_limit + bottom_limit) * 0.5)
	return {"center": center, "radius": radius}

func _pawn_offset(color_key: String) -> Vector2:
	if color_key == "red":
		return Vector2(-18, -18)
	if color_key == "blue":
		return Vector2(18, -18)
	return Vector2(0, 18)

func _update_ui() -> void:
	round_label.text = "第 %d 轮" % round_number
	score_label.text = "金币 %d / %d" % [round_score, target_score]
	assets_label.text = "资产 %d" % assets
	counter_label.text = "%d / %d" % [rolls_left, total_rolls]
	roll_button.disabled = roll_locked or mode != "play" or rolls_left <= 0

func _clear_board_hints() -> void:
	for tile in tile_nodes:
		tile.set_insert_hint(false)
		tile.set_delete_hint(false)

func _set_action_banner(message: String) -> void:
	action_banner.text = message
	action_banner.visible = not message.is_empty()
	cancel_action_button.visible = not message.is_empty()

func _make_tile(tile_id: String) -> Dictionary:
	return tile_catalog.get(tile_id, tile_catalog["market"]).duplicate(true)

func _make_label(text_value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label = Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label

func _make_button(text_value: String, accent: Color) -> Button:
	var button = Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.04, 0.02, 0.08))
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.04, 0.03, 0.10, 0.9), Color(accent.r, accent.g, accent.b, 0.75), 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(accent.darkened(0.5), accent.lightened(0.18), 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(accent.lightened(0.1), Color.WHITE, 8))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.05, 0.05, 0.07, 0.62), Color(0.32, 0.32, 0.38, 0.45), 8))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_pulse_node(button, Vector2(1.04, 1.04), Vector2(1.02, 1.02))
	)
	button.mouse_exited.connect(func() -> void:
		if not button.disabled:
			_pulse_node(button, Vector2.ONE, Vector2.ONE)
	)
	button.button_down.connect(func() -> void:
		if not button.disabled:
			_pulse_node(button, Vector2(0.94, 0.94), Vector2(0.98, 0.98))
	)
	return button

func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_overlay_dim(color: Color) -> ColorRect:
	var dim = ColorRect.new()
	dim.color = color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	return dim

func _pulse_node(node: CanvasItem, peak: Vector2, rest: Vector2) -> void:
	if node == null:
		return
	var tween = create_tween()
	tween.tween_property(node, "scale", peak, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", rest, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _negative_feedback(node: CanvasItem) -> void:
	var original: Vector2 = node.position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate", Color(1.0, 0.16, 0.22), 0.08)
	tween.tween_property(node, "position", original + Vector2(8, 0), 0.04)
	tween.tween_property(node, "position", original - Vector2(8, 0), 0.08).set_delay(0.04)
	tween.tween_property(node, "position", original, 0.06).set_delay(0.12)
	tween.tween_property(node, "modulate", Color.WHITE, 0.16).set_delay(0.12)

func _flash(color: Color, time: float) -> void:
	round_flash.color = color
	round_flash.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(round_flash, "modulate:a", 1.0, time * 0.28)
	tween.tween_property(round_flash, "modulate:a", 0.0, time * 0.72)

func _clear_overlay(overlay: Control) -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()

func _on_resized() -> void:
	var viewport_size = get_viewport_rect().size
	if world == null:
		return
	round_label.position = Vector2(viewport_size.x * 0.5 - 180, 18)
	round_label.size = Vector2(360, 48)
	score_label.position = Vector2(28, 20)
	score_label.size = Vector2(360, 44)
	assets_label.position = Vector2(30, 62)
	assets_label.size = Vector2(260, 34)
	roll_result_label.position = Vector2(viewport_size.x * 0.5 - 210, viewport_size.y - 162)
	roll_result_label.size = Vector2(420, 34)
	action_banner.position = Vector2(viewport_size.x * 0.5 - 360, 76)
	action_banner.size = Vector2(720, 42)
	cancel_action_button.position = Vector2(viewport_size.x * 0.5 + 270, 78)
	cancel_action_button.size = Vector2(110, 42)

	var shell_size = Vector2(492, 116)
	dice_shell.position = Vector2(viewport_size.x * 0.5 - shell_size.x * 0.5, viewport_size.y - shell_size.y - 28)
	dice_shell.size = shell_size

	for color_key in pawn_order:
		if dice_nodes.has(color_key):
			dice_nodes[color_key].pivot_offset = dice_nodes[color_key].size * 0.5
	if not tiles_data.is_empty():
		_rebuild_board_tiles()
		_position_pawns()
