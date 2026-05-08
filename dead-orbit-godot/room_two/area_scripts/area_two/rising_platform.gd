extends TileMapLayer

@export var rise_distance: float = 250.0
@export var rise_speed: float = 60.0

@onready var area = $Area2D

var plate_origin: Vector2

func _ready():
	plate_origin = position

func _count_players() -> int:
	var count = 0
	for body in area.get_overlapping_bodies():
		if body == self:
			continue
		if body.is_in_group("players"):
			count += 1
	return count

func _physics_process(delta):
	var count = _count_players()
	var is_rising = count == 2
	var target_y = plate_origin.y - rise_distance if is_rising else plate_origin.y
	position.y = move_toward(position.y, target_y, rise_speed * delta)
