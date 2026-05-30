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
const VectorBackground = preload("res://scripts/components/VectorBackground.gd")
const RoundStartBanner = preload("res://scripts/components/RoundStartBanner.gd")
const TileInfoTooltip = preload("res://scripts/components/TileInfoTooltip.gd")
const RichDescription = preload("res://scripts/components/RichDescription.gd")
const RunState = preload("res://scripts/domain/RunState.gd")
const TileRuntime = preload("res://scripts/domain/Tile.gd")
const TileDefinitions = preload("res://scripts/data/TileDefinitions.gd")
const RelicDefinitions = preload("res://scripts/data/RelicDefinitions.gd")
const BuffLibrary = preload("res://scripts/buffs/BuffLibrary.gd")
const TurnResolver = preload("res://scripts/systems/TurnResolver.gd")
const EffectResolver = preload("res://scripts/effects/EffectResolver.gd")
const GameCommand = preload("res://scripts/effects/GameCommand.gd")
const TurnContext = preload("res://scripts/domain/TurnContext.gd")
const ResolveContext = preload("res://scripts/domain/ResolveContext.gd")
const ROUND_CONFIG_PATH = "res://data/round_config.json"
const TILE_CONFIG_PATH = "res://data/tile_config.json"
const BOARD_VIEW_SCALE = 1.0
const BOARD_START_ANGLE = -PI * 0.75

var rng = RandomNumberGenerator.new()

var world: Control
var background: Control
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
var round_start_banner: Control
var info_tooltip: Control
var shaker: Node

var tiles_data: Array[Dictionary] = []
var tile_nodes: Array = []
var tile_positions: Array[Vector2] = []
var pawn_nodes = {}
var dice_nodes = {}
var pawn_indices = {"red": 0, "blue": 2, "green": 4}
var pawn_order = ["red", "blue", "green"]
var color_defs = {
	"red": Color(0.96, 0.27, 0.36),
	"blue": Color(0.35, 0.42, 0.96),
	"green": Color(0.16, 0.82, 0.46)
}

var round_number = 1
var target_score = 18
var total_rolls = 3
var rolls_left = 3
var round_score = 0
var assets = 8
var mode = "play"
var roll_locked = false
var round_intro_active = false
var pending_tile: Dictionary = {}
var batch_remaining = 0
var round_configs: Array = []
var default_round_config = {"target_score": 27, "rolls": 3}
var tile_catalog = {}
var reward_tile_ids = ["market", "factory", "haunted_house"]
var run_state
var turn_resolver = TurnResolver.new()
var tile_definitions: Dictionary = {}
var relic_definitions: Dictionary = {}
var buff_definitions: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	_load_game_definitions()
	_load_round_config()
	_build_scene()
	_start_new_game()

func _load_game_definitions() -> void:
	tile_definitions = TileDefinitions.all()
	relic_definitions = RelicDefinitions.all()
	buff_definitions = BuffLibrary.definitions()
	RichDescription.configure_tile_index(tile_definitions)
	reward_tile_ids = []
	for tile_id in tile_definitions.keys():
		if bool(tile_definitions[tile_id].get("selectable", false)):
			reward_tile_ids.append(tile_id)

func _build_scene() -> void:
	world = Control.new()
	world.name = "World"
	world.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)

	background = VectorBackground.new()
	background.name = "VectorBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	round_label = _make_label("第 1 轮", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	hud_layer.add_child(round_label)

	score_label = _make_label("金币 0 / 18", 28, Color(1.0, 0.90, 0.20), HORIZONTAL_ALIGNMENT_LEFT)
	hud_layer.add_child(score_label)

	assets_label = _make_label("资产 8", 22, Color(0.55, 1.0, 0.82), HORIZONTAL_ALIGNMENT_LEFT)
	hud_layer.add_child(assets_label)

	roll_result_label = _make_label("准备投掷", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	roll_result_label.z_index = 120
	hud_layer.add_child(roll_result_label)

	action_banner = _make_label("", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	action_banner.z_index = 120
	action_banner.visible = false
	hud_layer.add_child(action_banner)

	cancel_action_button = _make_button("取消", Color(0.96, 0.27, 0.36))
	cancel_action_button.z_index = 120
	cancel_action_button.visible = false
	cancel_action_button.pressed.connect(_on_cancel_action)
	hud_layer.add_child(cancel_action_button)

	dice_shell = PanelContainer.new()
	dice_shell.name = "DiceDock"
	dice_shell.z_index = 40
	dice_shell.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.055, 0.06, 0.94), Color.BLACK, 10))
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

	roll_button = _make_button("掷骰", Color(1.0, 0.86, 0.22))
	roll_button.custom_minimum_size = Vector2(154, 48)
	roll_button.pressed.connect(_on_roll_pressed)
	roll_stack.add_child(roll_button)

	counter_label = _make_label("3 / 3", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
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

	round_start_banner = RoundStartBanner.new()
	round_start_banner.name = "RoundStartBanner"
	round_start_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	round_start_banner.visible = false
	round_start_banner.z_index = 260
	add_child(round_start_banner)

	info_tooltip = TileInfoTooltip.new()
	info_tooltip.name = "TileInfoTooltip"
	info_tooltip.z_index = 900
	add_child(info_tooltip)

func _start_new_game() -> void:
	round_number = 1
	run_state = RunState.new()
	run_state.setup(tile_definitions, relic_definitions, buff_definitions, rng.randi(), "T001", 8)
	_sync_from_run_state()
	_start_round()

func _reset_pawn_indices() -> void:
	for color_key in pawn_order:
		pawn_indices[color_key] = 0

func _start_round() -> void:
	if run_state != null:
		run_state.begin_round(round_number)
	mode = "play"
	roll_locked = false
	round_intro_active = true
	pending_tile.clear()
	choice_overlay.visible = false
	fail_overlay.visible = false
	_set_action_banner("")
	_setup_round_values()
	rolls_left = total_rolls
	roll_result_label.text = "矢量棋盘已就绪"
	_sync_from_run_state()
	_rebuild_board_tiles()
	_position_pawns()
	_update_ui()
	_flash(Color(1.0, 0.90, 0.22, 0.18), 0.38)
	_play_round_intro()

func _play_round_intro() -> void:
	if round_start_banner == null:
		round_intro_active = false
		_update_ui()
		return
	await round_start_banner.play(round_number, target_score)
	round_intro_active = false
	_update_ui()

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
			"color": Color(0.96, 0.34, 0.42),
			"accent": Color(1.0, 0.86, 0.20)
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
			"color": Color(0.22, 0.56, 0.88),
			"accent": Color(0.16, 0.82, 0.72)
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
			"color": Color(0.46, 0.22, 0.74),
			"accent": Color(0.96, 0.27, 0.36)
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
	if roll_locked or round_intro_active or mode != "play" or rolls_left <= 0:
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
		results[color_key] = run_state.rng.randi_range(1, 6)
	var plan = turn_resolver.plan_roll(run_state, pawn_order, results)

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

	var turn = turn_resolver.resolve_planned_roll(run_state, pawn_order, results, plan)
	var gain = turn.total_gain
	await _play_turn_feedback(turn)
	_sync_from_run_state()
	_rebuild_board_tiles()
	_position_pawns()

	roll_result_label.text = "本次投掷 %s%d" % ["+" if gain >= 0 else "", gain]
	_pulse_node(roll_result_label, Vector2(1.18, 1.18), Vector2.ONE)
	if rolls_left <= 0:
		await get_tree().create_timer(0.45).timeout
		await _finish_round()

func _play_turn_feedback(turn) -> void:
	for event in turn.events:
		if str(event.get("type", "")) != "coins_added":
			continue
		var amount = int(event.get("amount", 0))
		if amount == 0:
			continue
		var source_index = int(event.get("sourceIndex", 0))
		var start = tile_positions[source_index] if source_index >= 0 and source_index < tile_positions.size() else get_viewport_rect().size * 0.5
		var end = score_label.global_position + score_label.size * 0.5
		var float_text = FloatingText.new()
		effects_layer.add_child(float_text)
		if amount >= 0:
			float_text.play("+%d" % amount, start + Vector2(0, -42), Color(1.0, 0.93, 0.24))
			var coins = CoinBurst.new()
			effects_layer.add_child(coins)
			coins.play(start, end, Color(1.0, 0.86, 0.12), 6)
		else:
			float_text.play("%d" % amount, start + Vector2(0, -42), Color(1.0, 0.24, 0.35))
			_negative_feedback(score_label)
		_sync_from_run_state()
		_update_ui()
		_pulse_node(score_label, Vector2(1.10, 1.10), Vector2.ONE)
		shaker.shake(world, 4.0 if amount >= 0 else 8.0, 0.14)
		await get_tree().create_timer(0.12).timeout
	await _play_board_change_feedback(turn.events)

func _play_board_change_feedback(events: Array) -> void:
	var changes: Array[Dictionary] = []
	for event in events:
		var event_type = str(event.get("type", ""))
		if ["tile_generated", "tile_destroyed", "tile_replaced_with_empty", "tile_transformed", "temporary_tile_removed"].has(event_type):
			changes.append(event)
	if changes.is_empty():
		return

	var panel = _make_board_change_panel(changes)
	effects_layer.add_child(panel)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	var open_tween = create_tween()
	open_tween.set_parallel(true)
	open_tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	open_tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await open_tween.finished

	for event in changes:
		await _play_single_board_change(event)
		await get_tree().create_timer(0.08).timeout

	await get_tree().create_timer(0.18).timeout
	var close_tween = create_tween()
	close_tween.set_parallel(true)
	close_tween.tween_property(panel, "modulate:a", 0.0, 0.16)
	close_tween.tween_property(panel, "scale", Vector2(0.96, 0.96), 0.16)
	await close_tween.finished
	panel.queue_free()

func _make_board_change_panel(changes: Array) -> PanelContainer:
	var viewport_size = get_viewport_rect().size
	var panel = PanelContainer.new()
	panel.z_index = 500
	panel.size = Vector2(330, 76 + min(changes.size(), 4) * 34)
	panel.position = Vector2(viewport_size.x - panel.size.x - 28, viewport_size.y * 0.18)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.04, 0.055, 0.96), Color(0.85, 0.95, 1.0, 0.92), 8))
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	var title = _make_label("结算变化", 22, Color(0.92, 0.98, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	title.custom_minimum_size = Vector2(280, 28)
	stack.add_child(title)
	for event in changes.slice(0, 4):
		var label = _make_label(_board_change_message(event), 17, _board_change_color(str(event.get("type", ""))), HORIZONTAL_ALIGNMENT_LEFT)
		label.custom_minimum_size = Vector2(286, 26)
		stack.add_child(label)
	if changes.size() > 4:
		var more = _make_label("还有 %d 个变化" % (changes.size() - 4), 15, Color(0.72, 0.78, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
		more.custom_minimum_size = Vector2(286, 22)
		stack.add_child(more)
	return panel

func _play_single_board_change(event: Dictionary) -> void:
	var event_type = str(event.get("type", ""))
	var index = _event_tile_node_index(event)
	match event_type:
		"tile_generated":
			await _play_generated_tile_preview(int(event.get("tileIndex", -1)), str(event.get("tileId", "T000")), bool(event.get("temporary", false)))
		"tile_destroyed", "tile_replaced_with_empty", "temporary_tile_removed":
			await _play_destroy_tile_preview(index)
		"tile_transformed":
			await _play_transform_tile_preview(index, str(event.get("toTileId", "T000")))

func _play_generated_tile_preview(index: int, tile_id: String, temporary: bool) -> void:
	if run_state == null or run_state.board.is_empty():
		return
	var final_positions = _calculate_board_positions(run_state.board.size())
	if index < 0 or index >= final_positions.size():
		return
	var tile_size = _calculate_tile_size(run_state.board.size())
	var preview = TileJuice.new()
	preview.setup(index, _make_tile(tile_id))
	preview.size = Vector2(tile_size, tile_size)
	preview.custom_minimum_size = preview.size
	preview.position = final_positions[index] - preview.size * 0.5
	preview.pivot_offset = preview.size * 0.5
	preview.scale = Vector2(0.08, 0.08)
	preview.modulate = Color(0.58, 1.0, 0.72, 0.95) if not temporary else Color(0.70, 0.92, 1.0, 0.95)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 70
	effects_layer.add_child(preview)
	var float_text = FloatingText.new()
	effects_layer.add_child(float_text)
	float_text.play("生成", final_positions[index] + Vector2(0, -52), Color(0.55, 1.0, 0.70))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(preview, "scale", Vector2(1.18, 1.18), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "rotation", 0.10, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(preview, "modulate:a", 0.0, 0.22).set_delay(0.36)
	await tween.finished
	preview.queue_free()

func _play_destroy_tile_preview(index: int) -> void:
	if index < 0 or index >= tile_nodes.size():
		return
	var node = tile_nodes[index] as Control
	if node == null:
		return
	var center = node.global_position + node.size * 0.5
	var float_text = FloatingText.new()
	effects_layer.add_child(float_text)
	float_text.play("销毁", center + Vector2(0, -52), Color(1.0, 0.30, 0.36))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(0.10, 0.10), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "rotation", node.rotation + 0.45, 0.22).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate", Color(1.0, 0.22, 0.28, 0.12), 0.22)
	shaker.shake(world, 6.0, 0.18)
	await tween.finished

func _play_transform_tile_preview(index: int, tile_id: String) -> void:
	if index < 0 or index >= tile_nodes.size():
		return
	var node = tile_nodes[index] as Control
	if node == null:
		return
	var center = node.global_position + node.size * 0.5
	var float_text = FloatingText.new()
	effects_layer.add_child(float_text)
	float_text.play("转变", center + Vector2(0, -52), Color(1.0, 0.86, 0.28))
	var preview = TileJuice.new()
	preview.setup(index, _make_tile(tile_id))
	preview.size = node.size
	preview.custom_minimum_size = node.size
	preview.position = node.position
	preview.pivot_offset = node.pivot_offset
	preview.scale = Vector2(0.12, 0.12)
	preview.modulate.a = 0.0
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 80
	tile_layer.add_child(preview)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(0.18, 0.18), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, 0.18)
	tween.tween_property(preview, "scale", Vector2(1.16, 1.16), 0.22).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "modulate:a", 1.0, 0.12).set_delay(0.08)
	tween.tween_property(preview, "scale", Vector2.ONE, 0.14).set_delay(0.30)
	shaker.shake(world, 5.0, 0.18)
	await tween.finished
	preview.queue_free()

func _board_change_message(event: Dictionary) -> String:
	match str(event.get("type", "")):
		"tile_generated":
			var suffix = "（临时）" if bool(event.get("temporary", false)) else ""
			return "生成：%s%s" % [_tile_name_by_id(str(event.get("tileId", ""))), suffix]
		"tile_destroyed", "tile_replaced_with_empty":
			return "销毁：%s" % _tile_name_by_id(str(event.get("tileId", "")))
		"temporary_tile_removed":
			return "消散：%s" % _tile_name_by_id(str(event.get("tileId", "")))
		"tile_transformed":
			return "转变：%s -> %s" % [_tile_name_by_id(str(event.get("fromTileId", ""))), _tile_name_by_id(str(event.get("toTileId", "")))]
	return "变化"

func _board_change_color(event_type: String) -> Color:
	match event_type:
		"tile_generated":
			return Color(0.55, 1.0, 0.70)
		"tile_destroyed", "tile_replaced_with_empty", "temporary_tile_removed":
			return Color(1.0, 0.42, 0.46)
		"tile_transformed":
			return Color(1.0, 0.86, 0.28)
	return Color.WHITE

func _tile_name_by_id(tile_id: String) -> String:
	var definition: Dictionary = tile_definitions.get(tile_id, {})
	return str(definition.get("name", definition.get("tile_name", tile_id)))

func _event_tile_node_index(event: Dictionary) -> int:
	var instance_id = str(event.get("tileInstanceId", event.get("fromTileInstanceId", "")))
	if not instance_id.is_empty():
		for i in range(tiles_data.size()):
			if str(tiles_data[i].get("instance_id", "")) == instance_id:
				return i
	return int(event.get("tileIndex", -1))

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
		run_state.coins += 4 + max(0, int(float(round_score - target_score) / 3.0))
		_sync_from_run_state()
		_update_ui()
		roll_result_label.text = "目标达成"
		_flash(Color(1.0, 0.86, 0.20, 0.24), 0.5)
		shaker.shake(world, 8.0, 0.28)
		await get_tree().create_timer(0.42).timeout
		await _cleanup_round_temporary_tiles_feedback()
		if round_number % 3 == 0:
			_show_relic_choice_overlay()
		else:
			_show_choice_overlay()
	else:
		roll_result_label.text = "未达目标"
		_flash(Color(0.96, 0.20, 0.28, 0.30), 0.46)
		shaker.shake(world, 11.0, 0.35)
		await get_tree().create_timer(0.36).timeout
		_show_fail_overlay()

func _cleanup_round_temporary_tiles_feedback() -> void:
	if run_state == null or run_state.temporary_tile_instances.is_empty():
		return
	var events = run_state.cleanup_round_temporary_tiles()
	if events.is_empty():
		return
	await _play_board_change_feedback(events)
	_sync_from_run_state()
	_rebuild_board_tiles()
	_position_pawns()
	_update_ui()

func _show_choice_overlay() -> void:
	mode = "choice"
	_update_ui()
	_clear_overlay(choice_overlay)
	choice_overlay.visible = true
	var viewport_size = get_viewport_rect().size
	var dim = _make_overlay_dim(Color(0.90, 0.36, 0.39, 0.86))
	choice_overlay.add_child(dim)
	var title = _make_label("通过第 %d 轮：选择一个地块" % round_number, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(viewport_size.x * 0.5 - 330, viewport_size.y * 0.13)
	title.size = Vector2(660, 48)
	choice_overlay.add_child(title)

	var card_width: float = clamp(viewport_size.x * 0.20, 195.0, 238.0)
	var card_height: float = clamp(viewport_size.y * 0.36, 280.0, 318.0)
	var gap: float = 34.0
	var total_width: float = card_width * 3.0 + gap * 2.0
	var start_x: float = viewport_size.x * 0.5 - total_width * 0.5
	var y: float = viewport_size.y * 0.25
	var choices = run_state.draw_tile_choices(3)
	for i in range(3):
		var choice_data = _make_tile(choices[i % choices.size()])
		var card = TileChoiceCard.new()
		card.setup(i, choice_data)
		card.size = Vector2(card_width, card_height)
		card.custom_minimum_size = card.size
		card.position = Vector2(start_x + (card_width + gap) * i, y)
		card.pivot_offset = card.size * 0.5
		card.picked.connect(func(_idx: int) -> void:
			_on_reward_tile_chosen(choice_data)
		)
		card.info_hovered.connect(_show_tile_tooltip)
		card.info_hidden.connect(_hide_tile_tooltip)
		card.reference_hovered.connect(_show_reference_tooltip)
		choice_overlay.add_child(card)
		card.play_spawn()
		card.start_idle(float(i) * 0.75)

	var skip = _make_button("跳过", Color(0.16, 0.82, 0.72))
	skip.position = Vector2(viewport_size.x * 0.5 - 86, viewport_size.y * 0.80)
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

func _show_relic_choice_overlay() -> void:
	mode = "relic_choice"
	_update_ui()
	_clear_overlay(choice_overlay)
	choice_overlay.visible = true
	var viewport_size = get_viewport_rect().size
	choice_overlay.add_child(_make_overlay_dim(Color(0.03, 0.035, 0.08, 0.90)))
	var title = _make_label("第 %d 轮奖励：选择一个遗物" % round_number, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(viewport_size.x * 0.5 - 330, viewport_size.y * 0.12)
	title.size = Vector2(660, 48)
	choice_overlay.add_child(title)
	var choices = run_state.draw_relic_choices(3)
	var card_width: float = clamp(viewport_size.x * 0.22, 210.0, 260.0)
	var card_height: float = clamp(viewport_size.y * 0.32, 245.0, 290.0)
	var gap := 28.0
	var total_width = card_width * 3.0 + gap * 2.0
	var start_x = viewport_size.x * 0.5 - total_width * 0.5
	var y = viewport_size.y * 0.27
	for i in range(choices.size()):
		var card = _make_relic_card(choices[i], Vector2(start_x + (card_width + gap) * i, y), Vector2(card_width, card_height))
		choice_overlay.add_child(card)
	var skip = _make_button("跳过", Color(0.16, 0.82, 0.72))
	skip.position = Vector2(viewport_size.x * 0.5 - 86, viewport_size.y * 0.82)
	skip.size = Vector2(172, 52)
	skip.pressed.connect(_on_relic_choice_done)
	choice_overlay.add_child(skip)

func _make_relic_card(relic_id: String, card_position: Vector2, card_size: Vector2) -> PanelContainer:
	var relic: Dictionary = relic_definitions.get(relic_id, {})
	var panel = PanelContainer.new()
	panel.position = card_position
	panel.size = card_size
	panel.custom_minimum_size = card_size
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.06, 0.12, 0.96), Color(1.0, 0.86, 0.20, 0.9), 8))
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	var name_label = _make_label(str(relic.get("name", relic_id)), 24, Color(1.0, 0.90, 0.22), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.custom_minimum_size = Vector2(card_size.x - 24, 36)
	stack.add_child(name_label)
	var rarity_label = _make_label(str(relic.get("rarity", "")), 17, Color(0.55, 1.0, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	rarity_label.custom_minimum_size = Vector2(card_size.x - 24, 24)
	stack.add_child(rarity_label)
	var desc = Label.new()
	desc.text = str(relic.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	desc.custom_minimum_size = Vector2(card_size.x - 30, card_size.y - 136)
	stack.add_child(desc)
	var pick = _make_button("选择", Color(1.0, 0.86, 0.20))
	pick.custom_minimum_size = Vector2(card_size.x - 34, 48)
	pick.pressed.connect(_on_relic_chosen.bind(relic_id))
	stack.add_child(pick)
	return panel

func _on_relic_chosen(relic_id: String) -> void:
	var effect_resolver = EffectResolver.new()
	var turn = TurnContext.new()
	var context = ResolveContext.new().setup(run_state, turn, null, null, -1, 0, "relic_choice")
	effect_resolver.execute_commands([GameCommand.add_relic(relic_id)], context)
	_sync_from_run_state()
	_on_relic_choice_done()

func _on_relic_choice_done() -> void:
	choice_overlay.visible = false
	_show_choice_overlay()

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
	mode = "busy"
	var insert_at: int = clamp(index + 1, 0, run_state.board.size())
	var inserted_tile_runtime = run_state.create_tile(str(pending_tile.get("id", "T001")))
	run_state.board.insert_tile(insert_at, inserted_tile_runtime)
	for dice_state in run_state.dice.values():
		if dice_state.index >= insert_at:
			dice_state.index += 1
	_sync_from_run_state()
	var inserted_tile = inserted_tile_runtime.to_display_data()
	pending_tile.clear()
	_clear_board_hints()
	_set_action_banner("")
	_update_ui()
	await _play_insert_animation(insert_at, inserted_tile)
	_position_pawns()
	_update_ui()
	_flash(Color(0.16, 0.82, 0.72, 0.22), 0.32)
	await get_tree().create_timer(0.18).timeout
	_after_round_reward_done()

func _play_insert_animation(insert_at: int, inserted_tile: Dictionary) -> void:
	var old_nodes = tile_nodes.duplicate()
	var new_positions = _calculate_board_positions(tiles_data.size())
	var new_tile_size = _calculate_tile_size(tiles_data.size())
	board_path.set_points(new_positions)
	var preview = TileJuice.new()
	preview.setup(insert_at, inserted_tile)
	preview.size = Vector2(new_tile_size, new_tile_size)
	preview.custom_minimum_size = preview.size
	preview.position = new_positions[insert_at] - preview.size * 0.5
	preview.pivot_offset = preview.size * 0.5
	preview.scale = Vector2(0.08, 0.08)
	preview.rotation = -0.16
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 30
	tile_layer.add_child(preview)

	var tween = create_tween()
	tween.set_parallel(true)
	for i in range(old_nodes.size()):
		var node = old_nodes[i] as Control
		if node == null:
			continue
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var new_index = i if i < insert_at else i + 1
		var target_size = Vector2(new_tile_size, new_tile_size)
		tween.tween_property(node, "size", target_size, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "position", new_positions[new_index] - target_size * 0.5, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "rotation", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_rebuild_board_tiles()
	if insert_at >= 0 and insert_at < tile_nodes.size():
		tile_nodes[insert_at].play_step(true)

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
	fail_overlay.add_child(_make_overlay_dim(Color(0.06, 0.025, 0.035, 0.88)))
	var title = _make_label("游戏失败", 44, Color(1.0, 0.32, 0.42), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(viewport_size.x * 0.5 - 220, viewport_size.y * 0.28)
	title.size = Vector2(440, 60)
	fail_overlay.add_child(title)
	var detail = _make_label("第 %d 轮获得 %d / %d 金币" % [round_number, round_score, target_score], 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	detail.position = Vector2(viewport_size.x * 0.5 - 260, viewport_size.y * 0.4)
	detail.size = Vector2(520, 42)
	fail_overlay.add_child(detail)
	var retry = _make_button("重玩", Color(1.0, 0.86, 0.20))
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
		tile.info_hovered.connect(_show_tile_tooltip)
		tile.info_hidden.connect(_hide_tile_tooltip)
		tile_layer.add_child(tile)
		tile_nodes.append(tile)

func _show_tile_tooltip(tile_data: Dictionary, anchor_global_pos: Vector2) -> void:
	if info_tooltip == null:
		return
	info_tooltip.show_tile(tile_data, anchor_global_pos, get_viewport_rect())

func _show_reference_tooltip(tile_id: String, anchor_global_pos: Vector2) -> void:
	_show_tile_tooltip(_make_tile(tile_id), anchor_global_pos)

func _hide_tile_tooltip() -> void:
	if info_tooltip != null:
		info_tooltip.hide_tooltip()

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
	var board_rect = _get_board_panel_rect()
	var center = board_rect.get_center() + Vector2(0.0, 8.0)
	var radius = min(board_rect.size.x * 0.30, board_rect.size.y * 0.43) * BOARD_VIEW_SCALE
	return {"center": center, "radius": radius}

func _get_board_panel_rect() -> Rect2:
	var viewport_size = get_viewport_rect().size
	var panel_height = min(viewport_size.y - 226.0, max(500.0, viewport_size.y * 0.68))
	var panel_width = min(viewport_size.x - 94.0, max(690.0, panel_height * 1.34))
	var panel_pos = Vector2((viewport_size.x - panel_width) * 0.5, 96.0)
	return Rect2(panel_pos, Vector2(panel_width, panel_height))

func _pawn_offset(color_key: String) -> Vector2:
	if color_key == "red":
		return Vector2(-18, -18)
	if color_key == "blue":
		return Vector2(18, -18)
	return Vector2(0, 18)

func _update_ui() -> void:
	if run_state != null:
		_sync_from_run_state()
	round_label.text = "第 %d 轮" % round_number
	score_label.text = "金币 %d / %d" % [round_score, target_score]
	assets_label.text = "资产 %d" % assets
	counter_label.text = "%d / %d" % [rolls_left, total_rolls]
	roll_button.disabled = roll_locked or round_intro_active or mode != "play" or rolls_left <= 0

func _clear_board_hints() -> void:
	for tile in tile_nodes:
		tile.set_insert_hint(false)
		tile.set_delete_hint(false)

func _set_action_banner(message: String) -> void:
	action_banner.text = message
	action_banner.visible = not message.is_empty()
	cancel_action_button.visible = not message.is_empty()

func _make_tile(tile_id: String) -> Dictionary:
	return TileRuntime.from_definition(tile_definitions.get(tile_id, tile_definitions["T000"]), 0).to_display_data()

func _sync_from_run_state() -> void:
	if run_state == null:
		return
	tiles_data = run_state.board.to_display_array()
	round_score = run_state.round_score
	assets = run_state.coins
	for color_key in pawn_order:
		if run_state.dice.has(color_key):
			pawn_indices[color_key] = run_state.dice[color_key].index

func _make_label(text_value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label = Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	return label

func _make_button(text_value: String, accent: Color) -> Button:
	var button = Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.02, 0.02, 0.025))
	button.add_theme_color_override("font_hover_color", Color(0.02, 0.02, 0.025))
	button.add_theme_color_override("font_pressed_color", Color(0.02, 0.02, 0.025))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.58))
	button.add_theme_stylebox_override("normal", _make_panel_style(accent, Color.BLACK, 9))
	button.add_theme_stylebox_override("hover", _make_panel_style(accent.lightened(0.12), Color.BLACK, 9))
	button.add_theme_stylebox_override("pressed", _make_panel_style(accent.darkened(0.10), Color.BLACK, 9))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.34, 0.34, 0.36, 0.88), Color.BLACK, 9))
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
	style.set_border_width_all(4)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(4, 5)
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
	action_banner.position = Vector2(viewport_size.x * 0.5 - 360, 76)
	action_banner.size = Vector2(720, 42)
	cancel_action_button.position = Vector2(viewport_size.x * 0.5 + 270, 78)
	cancel_action_button.size = Vector2(110, 42)

	var shell_size = Vector2(492, 116)
	var shell_position = Vector2(viewport_size.x * 0.5 - shell_size.x * 0.5, viewport_size.y - shell_size.y - 28)
	dice_shell.position = shell_position
	dice_shell.size = shell_size
	roll_result_label.position = Vector2(viewport_size.x * 0.5 - 210, shell_position.y - 45)
	roll_result_label.size = Vector2(420, 34)

	for color_key in pawn_order:
		if dice_nodes.has(color_key):
			dice_nodes[color_key].pivot_offset = dice_nodes[color_key].size * 0.5
	if not tiles_data.is_empty():
		_rebuild_board_tiles()
		_position_pawns()
