extends Node

const MAIN_SCENE = preload("res://scenes/Main.tscn")

func _ready() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await main._play_roll_turn()
	if main.round_score <= 0:
		push_error("Smoke test failed: rolling once did not award score.")
		return
	if main.rolls_left != main.total_rolls - 1:
		push_error("Smoke test failed: roll counter did not decrement.")
		return
	main._show_choice_overlay()
	await get_tree().process_frame
	if not main.choice_overlay.visible:
		push_error("Smoke test failed: choice overlay did not open.")
		return
	print("SMOKE_OK score=%d rolls_left=%d tiles=%d choice_cards=%d" % [main.round_score, main.rolls_left, main.tiles_data.size(), main.choice_overlay.get_child_count()])
