extends Node

const MAIN_SCENE = preload("res://scenes/Main.tscn")
const MapConfig = preload("res://scripts/data/MapConfig.gd")

func _ready() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	if main.run_state == null:
		_fail("run state was not created.")
		return
	if main.tiles_data.size() != 6:
		_fail("starting board does not contain 6 tiles.")
		return
	if main.mode != "map" or not main.map_overlay.visible:
		_fail("new game did not open the act map.")
		return
	var first_choices = MapConfig.available_node_ids(main.act_map, main.current_map_node_id)
	if first_choices.size() != 3:
		_fail("act map should offer three starting routes.")
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
		if str(node.get("room_type", "")) != "REST":
			if main.mode != "play" or main.run_state.monster_id.is_empty():
				_fail("map node did not resolve to battle.")
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
