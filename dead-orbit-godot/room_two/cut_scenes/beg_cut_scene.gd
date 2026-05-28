extends CanvasLayer

@export var dismiss_action: String = "sol_shield"

func _ready():
	get_tree().paused = true

func _process(_delta):
	if Input.is_action_just_pressed(dismiss_action):
		get_tree().paused = false
		queue_free()
