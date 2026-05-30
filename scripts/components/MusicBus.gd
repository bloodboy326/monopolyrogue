extends Node

const DUNGEON_LOOP = "res://assets/audio/bgm/dungeon_adventure_loop.wav"

var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "BgmPlayer"
	player.volume_db = -15.0
	add_child(player)
	if ResourceLoader.exists(DUNGEON_LOOP):
		var stream = load(DUNGEON_LOOP)
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream = stream
		player.finished.connect(func() -> void:
			if player != null:
				player.play()
		)
		player.play()
