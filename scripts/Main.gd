extends Control

signal batch_finished

const DiceAnimator = preload("res://scripts/components/DiceAnimator.gd")
const PawnMover = preload("res://scripts/components/PawnMover.gd")
const TileJuice = preload("res://scripts/components/TileJuice.gd")
const TileChoiceCard = preload("res://scripts/components/TileChoiceCard.gd")
const FloatingText = preload("res://scripts/components/FloatingText.gd")
const ScreenShake = preload("res://scripts/components/ScreenShake.gd")
const BoardPath = preload("res://scripts/components/BoardPath.gd")
const TileInfoTooltip = preload("res://scripts/components/TileInfoTooltip.gd")
const RichDescription = preload("res://scripts/components/RichDescription.gd")
const SlimeBossView = preload("res://scripts/components/SlimeBossView.gd")
const IntentIcon = preload("res://scripts/components/IntentIcon.gd")
const RollCounterBadge = preload("res://scripts/components/RollCounterBadge.gd")
const BlockShieldBurst = preload("res://scripts/components/BlockShieldBurst.gd")
const RollTargetPreview = preload("res://scripts/components/RollTargetPreview.gd")
const RunState = preload("res://scripts/domain/RunState.gd")
const TileRuntime = preload("res://scripts/domain/Tile.gd")
const TileDefinitions = preload("res://scripts/data/TileDefinitions.gd")
const RelicDefinitions = preload("res://scripts/data/RelicDefinitions.gd")
const MonsterConfig = preload("res://scripts/data/MonsterConfig.gd")
const BuffLibrary = preload("res://scripts/buffs/BuffLibrary.gd")
const TurnResolver = preload("res://scripts/systems/TurnResolver.gd")
const EffectResolver = preload("res://scripts/effects/EffectResolver.gd")
const TurnContext = preload("res://scripts/domain/TurnContext.gd")
const ResolveContext = preload("res://scripts/domain/ResolveContext.gd")

const BOARD_VIEW_SCALE = 1.0
const BOARD_START_ANGLE = -PI * 0.5

var rng = RandomNumberGenerator.new()
var monster_config: Dictionary = {}
var tile_definitions: Dictionary = {}
var relic_definitions: Dictionary = {}
var buff_definitions: Dictionary = {}
var run_state
var turn_resolver = TurnResolver.new()

var world: Control
var background: Control
var board_path: Control
var tile_layer: Control
var roll_preview_layer: Control
var boss_layer: Control
var pawn_layer: Node2D
var effects_layer: Node2D
var hud_layer: Control
var dice_shell: PanelContainer
var dice_panel: HBoxContainer
var roll_button: Button
var end_turn_button: Button
var roll_counter_badge: Control
var counter_label: Label
var round_label: Label
var player_hp_label: Label
var player_block_label: Label
var monster_name_label: Label
var monster_hp_label: Label
var roll_result_label: Label
var action_banner: Label
var cancel_action_button: Button
var round_flash: ColorRect
var choice_overlay: Control
var fail_overlay: Control
var info_tooltip: Control
var shaker: Node
var boss_view: Control
var intent_icon: Control
var intent_label: Label

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
var pawn_names = {"red": "红棋", "blue": "蓝棋", "green": "绿棋"}

var battle_number = 1
var total_rolls = 3
var rolls_left = 3
var pending_roll_value = 0
var current_rolls: Dictionary = {}
var roll_preview_target_index := -1
var mode = "play"
var roll_locked = false
var pending_tile: Dictionary = {}
var batch_remaining = 0

func _ready() -> void:
	rng.randomize()
	_load_game_definitions()
	_build_scene()
	_start_new_game()

func _load_game_definitions() -> void:
	tile_definitions = TileDefinitions.all()
	relic_definitions = RelicDefinitions.all()
	buff_definitions = BuffLibrary.definitions()
	monster_config = MonsterConfig.load_config()
	RichDescription.configure_tile_index(tile_definitions)

func _build_scene() -> void:
	world = Control.new()
	world.name = "World"
	world.set_anchors_preset(Control.PRESET_FULL_RECT)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)

	background = TextureRect.new()
	background.name = "VectorBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = load("res://assets/generated/backgrounds/dungeon_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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

	roll_preview_layer = RollTargetPreview.new()
	roll_preview_layer.name = "RollTargetPreview"
	roll_preview_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	roll_preview_layer.z_index = 48
	world.add_child(roll_preview_layer)

	boss_layer = Control.new()
	boss_layer.name = "BossLayer"
	boss_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(boss_layer)

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

	_build_boss()
	_build_hud()
	_build_pawns()
	_build_overlays()

	shaker = ScreenShake.new()
	add_child(shaker)
	resized.connect(_on_resized)
	_on_resized()

func _build_boss() -> void:
	intent_icon = IntentIcon.new()
	intent_icon.name = "IntentIcon"
	intent_icon.z_index = 65
	boss_layer.add_child(intent_icon)

	intent_label = _make_label("准备中", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	intent_label.z_index = 65
	boss_layer.add_child(intent_label)

	boss_view = SlimeBossView.new()
	boss_view.name = "SlimeBoss"
	boss_view.z_index = 55
	boss_layer.add_child(boss_view)

	monster_name_label = _make_label("沼泽史莱姆", 20, Color(0.82, 1.0, 0.70), HORIZONTAL_ALIGNMENT_CENTER)
	monster_name_label.z_index = 70
	boss_layer.add_child(monster_name_label)

	monster_hp_label = _make_label("80 / 80", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	monster_hp_label.z_index = 70
	boss_layer.add_child(monster_hp_label)

func _build_hud() -> void:
	round_label = _make_label("第 1 关", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	hud_layer.add_child(round_label)

	player_hp_label = _make_label("生命 80 / 80", 26, Color(1.0, 0.36, 0.42), HORIZONTAL_ALIGNMENT_LEFT)
	hud_layer.add_child(player_hp_label)

	player_block_label = _make_label("护盾 0", 22, Color(0.55, 0.85, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	hud_layer.add_child(player_block_label)

	roll_result_label = _make_label("准备战斗", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	roll_result_label.z_index = 120
	hud_layer.add_child(roll_result_label)

	action_banner = _make_label("", 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
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

	var dock_stack = VBoxContainer.new()
	dock_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_stack.add_theme_constant_override("separation", 8)
	dice_shell.add_child(dock_stack)

	dice_panel = HBoxContainer.new()
	dice_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_panel.add_theme_constant_override("separation", 12)
	dock_stack.add_child(dice_panel)

	for color_key in pawn_order:
		var dice = DiceAnimator.new()
		dice.name = "%sDice" % color_key.capitalize()
		dice.custom_minimum_size = Vector2(74, 74)
		dice.configure(color_defs[color_key], rng.randi_range(1, 6))
		dice.picked.connect(_on_dice_picked.bind(color_key))
		dice.mouse_entered.connect(_on_dice_hovered.bind(color_key))
		dice.mouse_exited.connect(_on_dice_unhovered.bind(color_key))
		dice_nodes[color_key] = dice
		dice_panel.add_child(dice)

	var control_stack = VBoxContainer.new()
	control_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	control_stack.custom_minimum_size = Vector2(166, 82)
	dice_panel.add_child(control_stack)

	roll_button = _make_button("掷骰", Color(1.0, 0.86, 0.22))
	roll_button.custom_minimum_size = Vector2(150, 40)
	roll_button.pressed.connect(_on_roll_pressed)
	control_stack.add_child(roll_button)

	end_turn_button = _make_button("结束回合", Color(0.16, 0.82, 0.72))
	end_turn_button.custom_minimum_size = Vector2(150, 38)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	control_stack.add_child(end_turn_button)

	counter_label = _make_label("3 / 3", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	counter_label.custom_minimum_size = Vector2(150, 24)
	counter_label.visible = false

	roll_counter_badge = RollCounterBadge.new()
	roll_counter_badge.name = "RollCounterBadge"
	roll_counter_badge.z_index = 90
	roll_counter_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(roll_counter_badge)

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

	info_tooltip = TileInfoTooltip.new()
	info_tooltip.name = "TileInfoTooltip"
	info_tooltip.z_index = 900
	add_child(info_tooltip)

func _start_new_game() -> void:
	battle_number = 1
	run_state = RunState.new()
	run_state.setup(tile_definitions, relic_definitions, buff_definitions, rng.randi(), "T001", 6)
	_start_battle()

func _start_battle() -> void:
	var max_battles = MonsterConfig.battle_count(monster_config)
	if battle_number > max_battles:
		_show_run_complete_overlay()
		return
	var battle = MonsterConfig.battle_for(monster_config, battle_number)
	var monster_def = MonsterConfig.monster(monster_config, str(battle.get("monster_id", "slime_boss")))
	run_state.start_battle(battle_number, monster_def)
	run_state.begin_player_turn(int(battle.get("rolls", 3)))
	total_rolls = run_state.turn_rolls_total
	rolls_left = run_state.turn_rolls_left
	mode = "play"
	roll_locked = false
	pending_roll_value = 0
	current_rolls.clear()
	pending_tile.clear()
	_clear_roll_preview()
	_set_dice_selectable(false)
	choice_overlay.visible = false
	fail_overlay.visible = false
	boss_view.set_art_key(run_state.monster_art_key)
	_choose_next_monster_intent()
	_set_action_banner("")
	roll_result_label.text = "你的回合"
	_sync_from_run_state()
	_rebuild_board_tiles()
	_position_pawns()
	_update_ui()
	_flash(Color(0.55, 1.0, 0.48, 0.16), 0.32)

func _choose_next_monster_intent() -> void:
	var previous_phase = run_state.current_phase_id
	run_state.current_intent = MonsterConfig.choose_intent(monster_config, run_state)
	if run_state.current_phase_id != previous_phase and not run_state.entered_phases.has(run_state.current_phase_id):
		run_state.entered_phases.append(run_state.current_phase_id)
		_apply_phase_enter_effect(run_state.current_phase_id)
	var intent_type = str(run_state.current_intent.get("intent_type", "SPECIAL"))
	intent_icon.set_intent_type(intent_type)
	intent_label.text = str(run_state.current_intent.get("telegraph", "未知意图"))

func _apply_phase_enter_effect(phase_id: String) -> void:
	for phase in monster_config.get("phases", []):
		if str(phase.get("phase_id", "")) != phase_id:
			continue
		var effect = str(phase.get("on_enter_effect", ""))
		if effect.begins_with("ADD_TILE:"):
			var parts = effect.split(":")
			if parts.size() >= 3:
				_add_monster_tile(str(parts[1]), int(parts[2]), false)

func _on_roll_pressed() -> void:
	if roll_locked or mode != "play" or rolls_left <= 0:
		return
	roll_locked = true
	mode = "rolling"
	if not run_state.spend_roll():
		roll_locked = false
		mode = "play"
		return
	rolls_left = run_state.turn_rolls_left
	run_state.begin_roll()
	pending_roll_value = 0
	current_rolls.clear()
	_set_dice_selectable(false)
	roll_result_label.text = "骰子飞转中..."
	_update_ui()
	_pulse_node(roll_button, Vector2(0.96, 0.96), Vector2.ONE)

	batch_remaining = pawn_order.size()
	for color_key in pawn_order:
		current_rolls[color_key] = run_state.rng.randi_range(1, 6)
		dice_nodes[color_key].roll_finished.connect(_mark_batch_item_done, CONNECT_ONE_SHOT)
		dice_nodes[color_key].roll_to(int(current_rolls[color_key]))
	await batch_finished

	mode = "choose_dice"
	roll_locked = false
	roll_result_label.text = "选择一颗骰子行动"
	_set_action_banner("点击一颗骰子，移动同色棋子")
	_set_dice_selectable(true)
	_update_ui()

func _on_dice_picked(color_key: String) -> void:
	if mode != "choose_dice" or not current_rolls.has(color_key):
		return
	_clear_roll_preview()
	pending_roll_value = int(current_rolls[color_key])
	mode = "moving"
	roll_locked = true
	_set_dice_selectable(false)
	_set_action_banner("%s移动 %d 格" % [pawn_names[color_key], pending_roll_value])
	_update_ui()

	var order = [color_key]
	var results = {color_key: pending_roll_value}
	var plan = turn_resolver.plan_roll(run_state, order, results)

	batch_remaining = 1
	pawn_nodes[color_key].movement_finished.connect(_on_pawn_movement_finished.bind(color_key), CONNECT_ONE_SHOT)
	pawn_nodes[color_key].move_steps(tile_positions, pawn_indices[color_key], pending_roll_value)
	await batch_finished

	var turn = turn_resolver.resolve_planned_roll(run_state, order, results, plan)
	await _play_turn_feedback(turn)
	rolls_left = run_state.turn_rolls_left
	total_rolls = run_state.turn_rolls_total
	_sync_from_run_state()
	_rebuild_board_tiles()
	_position_pawns()
	pending_roll_value = 0
	current_rolls.clear()
	roll_locked = false
	_set_action_banner("")
	if run_state.monster_hp <= 0:
		await _finish_battle_victory()
		return
	mode = "play"
	roll_result_label.text = "继续掷骰或结束回合"
	_update_ui()

func _on_dice_hovered(color_key: String) -> void:
	if mode != "choose_dice" or not current_rolls.has(color_key):
		return
	_show_roll_preview(color_key)

func _on_dice_unhovered(color_key: String) -> void:
	if mode == "choose_dice" and current_rolls.has(color_key):
		_clear_roll_preview()

func _on_end_turn_pressed() -> void:
	if mode != "play" or roll_locked:
		return
	mode = "monster"
	roll_locked = true
	_clear_roll_preview()
	_update_ui()
	run_state.begin_monster_turn()
	await _execute_monster_turn()
	if run_state.player_hp <= 0:
		_show_fail_overlay()
		return
	run_state.record_current_intent_used()
	run_state.battle_turn += 1
	run_state.begin_player_turn(int(MonsterConfig.battle_for(monster_config, battle_number).get("rolls", 3)))
	total_rolls = run_state.turn_rolls_total
	rolls_left = run_state.turn_rolls_left
	current_rolls.clear()
	pending_roll_value = 0
	_clear_roll_preview()
	_set_dice_selectable(false)
	_choose_next_monster_intent()
	roll_locked = false
	mode = "play"
	roll_result_label.text = "你的回合"
	_sync_from_run_state()
	_rebuild_board_tiles()
	_position_pawns()
	_update_ui()

func _execute_monster_turn() -> void:
	var intent = run_state.current_intent
	roll_result_label.text = "%s：%s" % [run_state.monster_name, str(intent.get("name", "行动"))]
	if str(intent.get("intent_type", "")) == "ATTACK":
		boss_view.play_attack()
		await get_tree().create_timer(0.16).timeout
	var events: Array[Dictionary] = []
	for effect in intent.get("effects", []):
		match str(effect.get("effect_type", "")):
			"DAMAGE":
				var raw_damage = int(effect.get("value", 0)) + run_state.monster_strength
				var result = run_state.apply_player_damage(raw_damage)
				events.append({"type": "player_damaged", "amount": int(result["amount"]), "blocked": int(result["blocked"]), "raw": int(result["raw"])})
			"BLOCK":
				var amount = int(effect.get("value", 0))
				run_state.monster_block += amount
				events.append({"type": "monster_block_added", "amount": amount})
			"ADD_TILE":
				events.append_array(_add_monster_tile(str(effect.get("param", "T901")), int(effect.get("value", 1)), true))
			"CORRUPT_TILE":
				events.append_array(_corrupt_tiles(str(effect.get("param", "T010")), int(effect.get("value", 1))))
			"STRENGTH":
				var strength_amount = int(effect.get("value", 0))
				run_state.monster_strength += strength_amount
				events.append({"type": "monster_strength_added", "amount": strength_amount, "strength": run_state.monster_strength})
			"NEXT_TURN_ROLLS":
				var roll_delta = int(effect.get("value", 0))
				run_state.add_next_turn_roll_bonus(roll_delta)
				events.append({"type": "next_turn_rolls_changed", "amount": roll_delta})
			"LOSE_ROLLS":
				var lost_roll_delta = -abs(int(effect.get("value", 0)))
				run_state.add_next_turn_roll_bonus(lost_roll_delta)
				events.append({"type": "next_turn_rolls_changed", "amount": lost_roll_delta})
	await _play_monster_feedback(events)

func _add_monster_tile(tile_id: String, count: int, collect_events: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for _i in range(max(0, count)):
		var tile = run_state.create_tile(tile_id)
		var insert_at = run_state.rng.randi_range(0, run_state.board.size())
		run_state.board.insert_tile(insert_at, tile)
		run_state.reindex_dice_after_insert(insert_at)
		run_state.register_temporary_tile(tile)
		if collect_events:
			events.append({"type": "tile_generated", "tileIndex": insert_at, "tileId": tile.id, "tileInstanceId": tile.instance_id, "temporary": true})
	return events

func _corrupt_tiles(target_tile_id: String, count: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for _i in range(max(0, count)):
		var index = run_state.pick_corruptible_tile_index()
		if index == -1:
			continue
		var old_tile = run_state.board.get_tile(index)
		var new_tile = run_state.create_tile(target_tile_id)
		run_state.board.set_tile(index, new_tile)
		run_state.remember_battle_revert(new_tile.instance_id, old_tile.id)
		events.append({"type": "tile_transformed", "tileIndex": index, "fromTileId": old_tile.id, "toTileId": new_tile.id, "fromTileInstanceId": old_tile.instance_id, "toTileInstanceId": new_tile.instance_id})
	return events

func _play_turn_feedback(turn) -> void:
	for event in turn.events:
		var event_type = str(event.get("type", ""))
		match event_type:
			"monster_damaged":
				var amount = int(event.get("amount", 0))
				var blocked = int(event.get("blocked", 0))
				var start = _event_source_position(event)
				if amount > 0:
					await _floating("-%d" % amount, start, Color(1.0, 0.32, 0.38))
					boss_view.flash_hit()
					shaker.shake(world, 7.0, 0.18)
				elif blocked > 0:
					_play_enemy_block_flash()
					await _floating("格挡", start, Color(0.60, 0.82, 1.0))
				_update_ui()
			"player_block_added":
				var amount = int(event.get("amount", 0))
				await _floating("+%d 护盾" % amount, _event_source_position(event), Color(0.55, 0.86, 1.0))
				_pulse_node(player_block_label, Vector2(1.08, 1.08), Vector2.ONE)
				_update_ui()
			"rolls_added":
				var amount = int(event.get("amount", 0))
				rolls_left = int(event.get("rollsLeft", run_state.turn_rolls_left))
				total_rolls = int(event.get("rollsTotal", run_state.turn_rolls_total))
				await _floating(("%+d 骰子" % amount), _event_source_position(event), Color(1.0, 0.90, 0.25))
				_update_ui()
			"attack_multiplier_added":
				await _floating("强化 x%.0f" % float(event.get("multiplier", 2.0)), _event_source_position(event), Color(1.0, 0.78, 1.0))
			"next_turn_rolls_added":
				await _floating("下回合%+d骰" % int(event.get("amount", 0)), _event_source_position(event), Color(0.72, 1.0, 0.36))
			"destroy_next_tile_added":
				await _floating("拆迁待命", _event_source_position(event), Color(1.0, 0.56, 0.18))
	await _play_board_change_feedback(turn.events)

func _play_monster_feedback(events: Array[Dictionary]) -> void:
	for event in events:
		match str(event.get("type", "")):
			"player_damaged":
				var amount = int(event.get("amount", 0))
				var blocked = int(event.get("blocked", 0))
				if amount > 0:
					await _floating("-%d 生命" % amount, player_hp_label.global_position + player_hp_label.size * 0.5, Color(1.0, 0.25, 0.34))
					_negative_feedback(player_hp_label)
					shaker.shake(world, 10.0, 0.28)
				elif blocked > 0:
					await _floating("护盾抵挡", player_block_label.global_position + player_block_label.size * 0.5, Color(0.56, 0.88, 1.0))
			"monster_block_added":
				await _floating("+%d 护甲" % int(event.get("amount", 0)), boss_view.global_position + boss_view.size * 0.5, Color(0.58, 0.82, 1.0))
			"monster_strength_added":
				await _floating("+%d 力量" % int(event.get("amount", 0)), boss_view.global_position + boss_view.size * 0.5, Color(1.0, 0.66, 0.20))
			"next_turn_rolls_changed":
				await _floating("下回合%+d骰" % int(event.get("amount", 0)), dice_shell.global_position + Vector2(40, -12), Color(1.0, 0.72, 0.24))
	await _play_board_change_feedback(events)
	_sync_from_run_state()
	_rebuild_board_tiles()
	_position_pawns()
	_update_ui()

func _finish_battle_victory() -> void:
	mode = "busy"
	roll_locked = true
	_update_ui()
	roll_result_label.text = "击败 %s" % run_state.monster_name
	boss_view.play_death()
	_flash(Color(1.0, 0.86, 0.20, 0.24), 0.5)
	shaker.shake(world, 8.0, 0.28)
	await get_tree().create_timer(0.55).timeout
	await _cleanup_battle_feedback()
	_show_choice_overlay()

func _cleanup_battle_feedback() -> void:
	if run_state == null:
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
	choice_overlay.add_child(_make_overlay_dim(Color(0.05, 0.10, 0.08, 0.88)))
	var title = _make_label("第 %d 关胜利：选择一个地块" % battle_number, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(viewport_size.x * 0.5 - 330, viewport_size.y * 0.13)
	title.size = Vector2(660, 48)
	choice_overlay.add_child(title)

	var choices = run_state.draw_tile_choices(3)
	if choices.is_empty():
		_after_round_reward_done()
		return
	var card_width: float = clamp(viewport_size.x * 0.20, 195.0, 238.0)
	var card_height: float = clamp(viewport_size.y * 0.36, 280.0, 318.0)
	var gap: float = 34.0
	var total_width: float = card_width * 3.0 + gap * 2.0
	var start_x: float = viewport_size.x * 0.5 - total_width * 0.5
	var y: float = viewport_size.y * 0.25
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
	battle_number += 1
	_start_battle()

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
	run_state.reindex_dice_after_insert(insert_at)
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
		tween.tween_property(node, "size", target_size, 0.34)
		tween.tween_property(node, "position", new_positions[new_index] - target_size * 0.5, 0.36)
	tween.tween_property(preview, "scale", Vector2.ONE, 0.36)
	tween.tween_property(preview, "rotation", 0.0, 0.28)
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
	elif mode == "choose_dice":
		current_rolls.clear()
		pending_roll_value = 0
		_set_dice_selectable(false)
		mode = "play"
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
	var detail = _make_label("生命值归零。到达第 %d 关" % battle_number, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	detail.position = Vector2(viewport_size.x * 0.5 - 300, viewport_size.y * 0.4)
	detail.size = Vector2(600, 42)
	fail_overlay.add_child(detail)
	var retry = _make_button("重玩", Color(1.0, 0.86, 0.20))
	retry.position = Vector2(viewport_size.x * 0.5 - 90, viewport_size.y * 0.56)
	retry.size = Vector2(180, 56)
	retry.pressed.connect(_start_new_game)
	fail_overlay.add_child(retry)

func _show_run_complete_overlay() -> void:
	mode = "complete"
	_update_ui()
	_clear_overlay(fail_overlay)
	fail_overlay.visible = true
	var viewport_size = get_viewport_rect().size
	fail_overlay.add_child(_make_overlay_dim(Color(0.03, 0.07, 0.055, 0.90)))
	var title = _make_label("版本通关", 44, Color(0.74, 1.0, 0.56), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(viewport_size.x * 0.5 - 220, viewport_size.y * 0.28)
	title.size = Vector2(440, 60)
	fail_overlay.add_child(title)
	var detail = _make_label("三关史莱姆全部击败，剩余生命 %d / %d" % [run_state.player_hp, run_state.player_max_hp], 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	detail.position = Vector2(viewport_size.x * 0.5 - 340, viewport_size.y * 0.4)
	detail.size = Vector2(680, 42)
	fail_overlay.add_child(detail)
	var retry = _make_button("再玩一次", Color(1.0, 0.86, 0.20))
	retry.position = Vector2(viewport_size.x * 0.5 - 95, viewport_size.y * 0.56)
	retry.size = Vector2(190, 56)
	retry.pressed.connect(_start_new_game)
	fail_overlay.add_child(retry)

func _play_board_change_feedback(events: Array) -> void:
	var changes: Array[Dictionary] = []
	for event in events:
		var event_type = str(event.get("type", ""))
		if ["tile_generated", "tile_destroyed", "tile_replaced_with_empty", "tile_transformed", "temporary_tile_removed"].has(event_type):
			changes.append(event)
	if changes.is_empty():
		return
	for event in changes:
		await _play_single_board_change(event)
		await get_tree().create_timer(0.06).timeout

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
	await _floating("生成", final_positions[index] + Vector2(0, -52), Color(0.55, 1.0, 0.70))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(preview, "scale", Vector2(1.18, 1.18), 0.20)
	tween.tween_property(preview, "modulate:a", 0.0, 0.22).set_delay(0.30)
	await tween.finished
	preview.queue_free()

func _play_destroy_tile_preview(index: int) -> void:
	if index < 0 or index >= tile_nodes.size():
		return
	var node = tile_nodes[index] as Control
	if node == null:
		return
	var center = node.global_position + node.size * 0.5
	await _floating("销毁", center + Vector2(0, -52), Color(1.0, 0.30, 0.36))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2(0.10, 0.10), 0.22)
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
	await _floating("转变", center + Vector2(0, -52), Color(1.0, 0.86, 0.28))
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
	tween.tween_property(node, "scale", Vector2(0.18, 0.18), 0.20)
	tween.tween_property(node, "modulate:a", 0.0, 0.18)
	tween.tween_property(preview, "scale", Vector2(1.12, 1.12), 0.22).set_delay(0.08)
	tween.tween_property(preview, "modulate:a", 1.0, 0.12).set_delay(0.08)
	await tween.finished
	preview.queue_free()

func _event_tile_node_index(event: Dictionary) -> int:
	var instance_id = str(event.get("tileInstanceId", event.get("fromTileInstanceId", "")))
	if not instance_id.is_empty():
		for i in range(tiles_data.size()):
			if str(tiles_data[i].get("instance_id", "")) == instance_id:
				return i
	return int(event.get("tileIndex", -1))

func _event_source_position(event: Dictionary) -> Vector2:
	var source_index = int(event.get("sourceIndex", -1))
	if source_index >= 0 and source_index < tile_positions.size():
		if source_index < tile_nodes.size():
			var tile = tile_nodes[source_index] as Control
			if tile != null:
				tile.play_reward()
		return tile_positions[source_index] + Vector2(0, -42)
	return boss_view.global_position + boss_view.size * 0.5

func _floating(text: String, start: Vector2, color: Color) -> void:
	var float_text = FloatingText.new()
	effects_layer.add_child(float_text)
	float_text.play(text, start, color)
	await get_tree().create_timer(0.15).timeout

func _play_enemy_block_flash() -> void:
	var burst = BlockShieldBurst.new()
	effects_layer.add_child(burst)
	var center = boss_view.global_position + boss_view.size * 0.5 + Vector2(0, -10)
	burst.play(center, Vector2(94, 94))
	shaker.shake(world, 3.2, 0.12)

func _mark_batch_item_done() -> void:
	batch_remaining -= 1
	if batch_remaining <= 0:
		batch_finished.emit()

func _on_pawn_movement_finished(final_index: int, color_key: String) -> void:
	pawn_indices[color_key] = final_index
	_mark_batch_item_done()

func _rebuild_board_tiles() -> void:
	_clear_roll_preview()
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
	var panel_height = min(viewport_size.y - 244.0, max(500.0, viewport_size.y * 0.66))
	var panel_width = min(viewport_size.x - 94.0, max(690.0, panel_height * 1.34))
	var panel_pos = Vector2((viewport_size.x - panel_width) * 0.5, 100.0)
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
		rolls_left = run_state.turn_rolls_left
		total_rolls = run_state.turn_rolls_total
		round_label.text = "第 %d 关" % battle_number
		player_hp_label.text = "生命 %d / %d" % [run_state.player_hp, run_state.player_max_hp]
		player_block_label.text = "护盾 %d" % run_state.player_block
		monster_name_label.text = run_state.monster_name
		monster_hp_label.text = "HP %d / %d    护甲 %d" % [run_state.monster_hp, run_state.monster_max_hp, run_state.monster_block]
	counter_label.text = "%d / %d" % [rolls_left, total_rolls]
	if roll_counter_badge != null:
		roll_counter_badge.set_counts(rolls_left, total_rolls)
	roll_button.disabled = roll_locked or mode != "play" or rolls_left <= 0
	end_turn_button.disabled = roll_locked or mode != "play"

func _clear_board_hints() -> void:
	for tile in tile_nodes:
		tile.set_insert_hint(false)
		tile.set_delete_hint(false)

func _show_roll_preview(color_key: String) -> void:
	if tile_positions.is_empty() or not current_rolls.has(color_key):
		return
	_clear_roll_preview()
	var path = _roll_preview_path_indices(color_key, int(current_rolls[color_key]))
	if path.is_empty():
		return
	roll_preview_target_index = int(path.back())
	if roll_preview_layer != null:
		roll_preview_layer.set_preview(tile_positions, path, color_defs.get(color_key, Color.WHITE), pawn_nodes[color_key].position)
	if roll_preview_target_index >= 0 and roll_preview_target_index < tile_nodes.size():
		tile_nodes[roll_preview_target_index].set_glow(1.0)

func _clear_roll_preview() -> void:
	if roll_preview_layer != null:
		roll_preview_layer.clear_preview()
	if roll_preview_target_index >= 0 and roll_preview_target_index < tile_nodes.size():
		tile_nodes[roll_preview_target_index].set_glow(0.0)
	roll_preview_target_index = -1

func _roll_preview_path_indices(color_key: String, steps: int) -> Array[int]:
	var result: Array[int] = []
	if run_state == null or run_state.board.is_empty():
		return result
	var start_index = int(pawn_indices.get(color_key, 0))
	if run_state.dice.has(color_key):
		start_index = run_state.dice[color_key].index
	for step in range(1, max(0, steps) + 1):
		result.append(run_state.board.normalize_index(start_index + step))
	return result

func _set_action_banner(message: String) -> void:
	action_banner.text = message
	action_banner.visible = not message.is_empty()
	cancel_action_button.visible = mode == "insert"

func _set_dice_selectable(value: bool) -> void:
	if not value:
		_clear_roll_preview()
	for color_key in pawn_order:
		if dice_nodes.has(color_key):
			dice_nodes[color_key].set_selectable(value and mode == "choose_dice")

func _make_tile(tile_id: String) -> Dictionary:
	return TileRuntime.from_definition(tile_definitions.get(tile_id, tile_definitions["T000"]), 0).to_display_data()

func _sync_from_run_state() -> void:
	if run_state == null:
		return
	tiles_data = run_state.board.to_display_array()
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
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color(0.02, 0.02, 0.025))
	button.add_theme_color_override("font_hover_color", Color(0.02, 0.02, 0.025))
	button.add_theme_color_override("font_pressed_color", Color(0.02, 0.02, 0.025))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.58))
	button.add_theme_stylebox_override("normal", _make_panel_style(accent, Color.BLACK, 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(accent.lightened(0.12), Color.BLACK, 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(accent.darkened(0.10), Color.BLACK, 8))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.34, 0.34, 0.36, 0.88), Color.BLACK, 8))
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
	tween.tween_property(node, "scale", peak, 0.08)
	tween.tween_property(node, "scale", rest, 0.18)

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
	player_hp_label.position = Vector2(28, 20)
	player_hp_label.size = Vector2(360, 42)
	player_block_label.position = Vector2(30, 58)
	player_block_label.size = Vector2(260, 34)
	action_banner.position = Vector2(viewport_size.x * 0.5 - 360, 76)
	action_banner.size = Vector2(720, 42)
	cancel_action_button.position = Vector2(viewport_size.x * 0.5 + 270, 78)
	cancel_action_button.size = Vector2(110, 42)

	var circle = _get_board_circle()
	var boss_size = Vector2(190, 170)
	boss_view.position = circle["center"] - boss_size * 0.5 + Vector2(0, -8)
	boss_view.size = boss_size
	intent_icon.position = circle["center"] + Vector2(-30, -156)
	intent_icon.size = Vector2(60, 60)
	intent_label.position = circle["center"] + Vector2(-100, -98)
	intent_label.size = Vector2(200, 26)
	monster_name_label.position = circle["center"] + Vector2(-150, 76)
	monster_name_label.size = Vector2(300, 28)
	monster_hp_label.position = circle["center"] + Vector2(-170, 106)
	monster_hp_label.size = Vector2(340, 28)

	var shell_size = Vector2(510, 116)
	var shell_position = Vector2(viewport_size.x * 0.5 - shell_size.x * 0.5, viewport_size.y - shell_size.y - 28)
	dice_shell.position = shell_position
	dice_shell.size = shell_size
	roll_counter_badge.position = shell_position + Vector2(-18, -18)
	roll_counter_badge.size = Vector2(66, 66)
	roll_result_label.position = Vector2(viewport_size.x * 0.5 - 230, shell_position.y - 42)
	roll_result_label.size = Vector2(460, 34)

	for color_key in pawn_order:
		if dice_nodes.has(color_key):
			dice_nodes[color_key].pivot_offset = dice_nodes[color_key].size * 0.5
	if not tiles_data.is_empty():
		_rebuild_board_tiles()
		_position_pawns()
