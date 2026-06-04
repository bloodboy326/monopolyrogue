extends Node

const MAIN_SCENE = preload("res://scenes/Main.tscn")
const MapConfig = preload("res://scripts/data/MapConfig.gd")
const MonsterConfig = preload("res://scripts/data/MonsterConfig.gd")

func _ready() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	if main.run_state == null:
		_fail("run state was not created.")
		return
	if main.tiles_data.size() != 8:
		_fail("starting board does not contain 8 tiles.")
		return
	if main.mode != "map" or not main.map_overlay.visible:
		_fail("new game did not open the act map.")
		return
	main.run_state.add_coins(1000)
	main.current_map_node_id = "smoke_shop"
	main.selected_map_node = {"id": "smoke_shop", "room_type": "SHOP"}
	main._show_shop_overlay()
	await get_tree().process_frame
	if main.current_shop_cards.is_empty():
		_fail("shop did not generate card inventory.")
		return
	var board_size_before_shop = main.run_state.board.size()
	var dummy_card = Control.new()
	var dummy_coins = Label.new()
	main._on_shop_card_picked(0, 0, dummy_card, dummy_coins)
	await get_tree().process_frame
	if main.mode != "insert" or main.pending_insert_return != "shop":
		_fail("buying a shop card did not enter insert mode.")
		return
	await main._insert_pending_tile_after(0)
	if main.run_state.board.size() != board_size_before_shop + 1 or main.mode != "shop":
		_fail("shop card insertion did not return to the same shop.")
		return
	var remove_count_before = main.run_state.shop_remove_count
	main._perform_shop_delete_tile(0)
	await get_tree().process_frame
	if not main.current_shop_remove_used or main.run_state.shop_remove_count != remove_count_before + 1:
		_fail("shop tile removal was not consumed once.")
		return
	main._perform_shop_delete_tile(0)
	await get_tree().process_frame
	if main.run_state.shop_remove_count != remove_count_before + 1:
		_fail("shop allowed a second removal in the same room.")
		return
	var group_monster = MonsterConfig.encounter(main.monster_config, "guard_pair")
	main._begin_battle(group_monster, 1, 3)
	await get_tree().process_frame
	if main.run_state.enemy_units.size() != 2:
		_fail("guard pair did not start as two enemy units.")
		return
	var monster_gap = abs(main.monster_views[0].position.x - main.monster_views[1].position.x)
	if monster_gap < 260.0:
		_fail("group monster layout did not separate units. gap=%.1f" % monster_gap)
		return
	main.current_map_node_id = ""
	main.selected_map_node.clear()
	main._show_map()
	await get_tree().process_frame
	var first_choices = MapConfig.available_node_ids(main.act_map, main.current_map_node_id)
	if first_choices.size() < 2:
		_fail("act map should offer multiple starting routes.")
		return
	main._on_map_node_selected(first_choices[0])
	await get_tree().process_frame
	if main.mode != "play" or main.run_state.monster_id.is_empty():
		_fail("selecting a map node did not start battle.")
		return
	if main.rolls_left != 3 or main.total_rolls != 3:
		_fail("starting roll budget is not 3/3.")
		return

	main._show_choice_overlay()
	await get_tree().process_frame
	if not main.choice_overlay.visible:
		_fail("choice overlay did not open after battle.")
		return

	main.choice_overlay.visible = false
	main._clear_overlay(main.choice_overlay)
	var seen_rooms: Array[String] = [str(main.selected_map_node.get("room_type", ""))]
	var seen_monsters: Array[String] = [str(main.run_state.monster_id)]
	var guard = 0
	while main.mode != "complete" and guard < 24:
		main._after_round_reward_done()
		await get_tree().process_frame
		if main.mode == "complete":
			break
		if main.mode != "map":
			_fail("battle reward did not return to map.")
			return
		var choices = MapConfig.available_node_ids(main.act_map, main.current_map_node_id)
		if choices.is_empty():
			_fail("map path ended before the boss.")
			return
		var next_id = choices[0]
		var node = MapConfig.node_for(main.act_map, next_id)
		main._on_map_node_selected(next_id)
		await get_tree().process_frame
		seen_rooms.append(str(node.get("room_type", "")))
		if ["REST", "SHOP", "CHEST", "EVENT"].has(str(node.get("room_type", ""))):
			if not ["rest", "shop", "chest"].has(main.mode):
				_fail("non-battle map node did not open its room page.")
				return
			main._show_map()
			await get_tree().process_frame
		else:
			if main.mode != "play" or main.run_state.monster_id.is_empty():
				_fail("map node did not resolve to battle. room=%s mode=%s monster=%s" % [str(node.get("room_type", "")), main.mode, main.run_state.monster_id])
				return
			seen_monsters.append(str(main.run_state.monster_id))
		guard += 1
	if main.mode != "complete":
		_fail("map flow did not reach run completion.")
		return

	print("SMOKE_OK rooms=%s monsters=%s tiles=%d" % [seen_rooms, seen_monsters, main.tiles_data.size()])
	main._clear_overlay(main.choice_overlay)
	main.queue_free()
	for _i in range(4):
		await get_tree().process_frame
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("Smoke test failed: %s" % message)
	get_tree().quit(1)
