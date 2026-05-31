extends Node

const MAIN_SCENE = preload("res://scenes/Main.tscn")

func _ready() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	if main.run_state == null or main.run_state.monster_id != "red_louse":
		_fail("battle 1 did not start with red_louse.")
		return
	if main.tiles_data.size() != 6:
		_fail("starting board does not contain 6 tiles.")
		return
	if main.rolls_left != 3 or main.total_rolls != 3:
		_fail("starting roll budget is not 3/3.")
		return

	main._show_choice_overlay()
	await get_tree().process_frame
	if not main.choice_overlay.visible:
		_fail("choice overlay did not open.")
		return

	main.choice_overlay.visible = false
	main._clear_overlay(main.choice_overlay)
	var expected_flow = ["red_louse", "jaw_worm", "clacker", "slime_boss"]
	var seen_flow = [str(main.run_state.monster_id)]
	for _i in range(1, expected_flow.size()):
		main._after_round_reward_done()
		await get_tree().process_frame
		seen_flow.append(str(main.run_state.monster_id))
	if seen_flow != expected_flow:
		_fail("battle flow mismatch. expected=%s seen=%s" % [expected_flow, seen_flow])
		return

	main._after_round_reward_done()
	await get_tree().process_frame
	if main.mode != "complete":
		_fail("run did not complete after the configured battle flow.")
		return

	print("SMOKE_OK flow=%s hp=%d/%d tiles=%d" % [seen_flow, main.run_state.monster_hp, main.run_state.monster_max_hp, main.tiles_data.size()])
	main._clear_overlay(main.choice_overlay)
	main.queue_free()
	for _i in range(4):
		await get_tree().process_frame
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("Smoke test failed: %s" % message)
	get_tree().quit(1)
