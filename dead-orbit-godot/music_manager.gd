extends Node

var player: AudioStreamPlayer

func _ready():
	player = AudioStreamPlayer.new()
	player.stream = preload("res://the_mountain-sci-fi-512284.mp3")
	player.autoplay = true
	player.volume_db = -20.0
	add_child(player)
	player.play()

func change_music(new_track: AudioStream):
	player.stream = new_track
	player.play()

func set_volume(db: float):
	player.volume_db = db
