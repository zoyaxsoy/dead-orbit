extends Node

const DEFAULT_MUSIC_PATH := "res://the_mountain-sci-fi-512284.mp3"

var player: AudioStreamPlayer

func _ready():
	player = AudioStreamPlayer.new()
	player.stream = _load_default_music()
	player.autoplay = true
	player.volume_db = -20.0
	add_child(player)
	if player.stream != null:
		player.play()

func _load_default_music() -> AudioStream:
	if not FileAccess.file_exists(DEFAULT_MUSIC_PATH):
		return null
	return AudioStreamMP3.load_from_file(DEFAULT_MUSIC_PATH)

func change_music(new_track: AudioStream):
	if player == null:
		return
	player.stream = new_track
	if player.stream != null:
		player.play()

func set_volume(db: float):
	if player == null:
		return
	player.volume_db = db
