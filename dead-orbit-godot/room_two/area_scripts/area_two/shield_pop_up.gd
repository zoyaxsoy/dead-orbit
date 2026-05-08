extends Control

func _ready():
	visible = false

func show_popup():
	visible = true
	get_tree().paused = true
	await get_tree().create_timer(3.0).timeout
	visible = false
	get_tree().paused = false
