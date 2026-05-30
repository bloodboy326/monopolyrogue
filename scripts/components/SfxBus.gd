extends Node

const SFX_PATHS := {
	"ui_hover": "res://assets/audio/sfx/ui_hover.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"ui_cancel": "res://assets/audio/sfx/ui_cancel.wav",
	"turn_start": "res://assets/audio/sfx/turn_start.wav",
	"turn_end": "res://assets/audio/sfx/turn_end.wav",
	"dice_roll": "res://assets/audio/sfx/dice_roll.wav",
	"dice_land": "res://assets/audio/sfx/dice_land.wav",
	"dice_select": "res://assets/audio/sfx/dice_select.wav",
	"dice_bonus": "res://assets/audio/sfx/dice_bonus.wav",
	"pawn_step": "res://assets/audio/sfx/pawn_step.wav",
	"pawn_land": "res://assets/audio/sfx/pawn_land.wav",
	"tile_trigger": "res://assets/audio/sfx/tile_trigger.wav",
	"tile_attack": "res://assets/audio/sfx/tile_attack.wav",
	"tile_block": "res://assets/audio/sfx/tile_block.wav",
	"tile_buff": "res://assets/audio/sfx/tile_buff.wav",
	"tile_generate": "res://assets/audio/sfx/tile_generate.wav",
	"tile_destroy": "res://assets/audio/sfx/tile_destroy.wav",
	"tile_transform": "res://assets/audio/sfx/tile_transform.wav",
	"insert_tile": "res://assets/audio/sfx/insert_tile.wav",
	"enemy_attack": "res://assets/audio/sfx/enemy_attack.wav",
	"enemy_hit": "res://assets/audio/sfx/enemy_hit.wav",
	"enemy_block": "res://assets/audio/sfx/enemy_block.wav",
	"enemy_block_big": "res://assets/audio/sfx/enemy_block_big.wav",
	"monster_block": "res://assets/audio/sfx/monster_block.wav",
	"monster_strength": "res://assets/audio/sfx/monster_strength.wav",
	"player_hit": "res://assets/audio/sfx/player_hit.wav",
	"player_block": "res://assets/audio/sfx/player_block.wav",
	"debuff": "res://assets/audio/sfx/debuff.wav",
	"victory": "res://assets/audio/sfx/victory.wav",
	"run_complete": "res://assets/audio/sfx/run_complete.wav",
	"defeat": "res://assets/audio/sfx/defeat.wav",
	"reward_open": "res://assets/audio/sfx/reward_open.wav",
	"reward_pick": "res://assets/audio/sfx/reward_pick.wav"
}

const RANDOM_PITCH := {
	"ui_hover": 0.03,
	"ui_click": 0.03,
	"dice_land": 0.04,
	"pawn_step": 0.06,
	"pawn_land": 0.04,
	"tile_trigger": 0.04,
	"tile_attack": 0.03,
	"enemy_hit": 0.035
}

const MAX_PLAYERS := 28

var streams: Dictionary = {}
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for key in SFX_PATHS.keys():
		var path = str(SFX_PATHS[key])
		if ResourceLoader.exists(path):
			streams[key] = load(path)

func play(key: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream = streams.get(key, null)
	if stream == null:
		return
	while get_child_count() >= MAX_PLAYERS:
		var oldest = get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	var random_pitch = float(RANDOM_PITCH.get(key, 0.0))
	if random_pitch > 0.0:
		pitch_scale *= rng.randf_range(1.0 - random_pitch, 1.0 + random_pitch)
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)
	player.play()
