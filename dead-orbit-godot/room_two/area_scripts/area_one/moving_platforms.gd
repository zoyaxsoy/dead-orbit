extends AnimatableBody2D

@export var move_distance: float = 100
@export var move_speed: float = 1.5

var start_position: Vector2

func _ready():
	start_position = position

func _physics_process(delta):
	var offset = sin(Time.get_ticks_msec() / 1000.0 * move_speed) * move_distance
	position.y = start_position.y + offset
