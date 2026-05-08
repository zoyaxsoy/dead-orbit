extends TileMapLayer

@export var move_distance: float = 200.0
@export var move_speed: float = 80.0

var origin: Vector2
var is_moving: bool = false

func _ready():
	origin = position

func activate():
	is_moving = true

func _physics_process(delta):
	if is_moving:
		var target_x = origin.x - move_distance
		position.x = move_toward(position.x, target_x, move_speed * delta)
		if position.x == target_x:
			is_moving = false
