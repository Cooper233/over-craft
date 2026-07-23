extends Node

const POOL_SIZE = 32
var pool: Array[AudioStreamPlayer2D] = []
var current_index = 0

var sound_cache: Dictionary = {}

func _ready() -> void:
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer2D.new()
		add_child(player)
		pool.append(player)

func load_sound(path: String) -> AudioStream:
	var full_path = "res://assets/audio/" + path
	if not (full_path.to_lower().ends_with(".wav") or \
			full_path.to_lower().ends_with(".mp3") or \
			full_path.to_lower().ends_with(".ogg")):
		full_path += ".wav"
	if sound_cache.has(full_path):
		return sound_cache[full_path]
	if ResourceLoader.exists(full_path):
		var stream = load(full_path) as AudioStream
		if stream:
			sound_cache[full_path] = stream
			return stream
			
	push_error("SoundManager: 音效文件路径不存在 -> " + full_path)
	return null
@rpc("authority", "call_local", "unreliable")
func _rpc_play_sound(sound_path: String, global_pos: Vector2, volume_db: float, pitch: float) -> void:
	play_sound(sound_path, global_pos, volume_db, pitch)

func playSoundForAll(sound_path: String, global_pos: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not multiplayer.is_server():
		return
	_rpc_play_sound.rpc(sound_path, global_pos, volume_db, pitch)

func play_sound(sound_input: Variant, global_pos: Vector2, volume_db: float = 0.0,pitch:float=1.0) -> void:
	var stream: AudioStream = null
	if sound_input is String:
		stream = load_sound(sound_input)
	elif sound_input is AudioStream:
		stream = sound_input
	if not stream: return
	var player = pool[current_index]
	player.stop() # 确保重置
	player.stream = stream
	player.global_position = global_pos
	player.volume_db = volume_db
	player.pitch_scale=pitch
	player.play()
	current_index = (current_index + 1) % POOL_SIZE
