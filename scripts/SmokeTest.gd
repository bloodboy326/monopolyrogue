extends Node

const MAIN_SCENE = preload("res://scenes/Main.tscn")

func _ready() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	if main.run_state == null or main.run_state.monster_id != "red_louse":
		push_error("Smoke test failed: battle 1 did not start with red_louse.")
		return
	if main.tiles_data.size() != 6:
		push_error("Smoke test failed: starting board does not contain 6 tiles.")
		return
	if main.rolls_left != 3 or main.total_rolls != 3:
		push_error("Smoke test failed: starting roll budget is not 3/3.")
		return

	main._show_choice_overlay()
	await get_tree().process_frame
	if not main.choice_overlay.visible:
		push_error("Smoke test failed: choice overlay did not open.")
		return

	print("SMOKE_OK battle=%s hp=%d/%d tiles=%d choices=%d" % [main.run_state.monster_id, main.run_state.monster_hp, main.run_state.monster_max_hp, main.tiles_data.size(), main.choice_overlay.get_child_count()])
	main._clear_overlay(main.choice_overlay)
	main.queue_free()
	for _i in range(4):
		await get_tree().process_frame
	get_tree().quit()
