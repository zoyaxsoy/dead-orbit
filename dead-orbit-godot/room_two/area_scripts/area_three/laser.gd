extends Node2D

@export var beam_length: float = 1000.0
@export var sweep_range: float = 200.0
@export var sweep_speed: float = 100.0

var sweep_direction: float = 1.0
var start_x: float = 0.0
var active := false
var hit_cooldown: float = 0.0

func activate():
	active = true

func _ready():
	start_x = position.x
	$RayCast2D.enabled = true
	$RayCast2D.target_position = Vector2(beam_length, 0)
	$Line2D.width = 2.5
	$Line2D.default_color = Color(1.0, 0.0, 0.0)

func _physics_process(delta):
	if not active:
		return

	hit_cooldown = maxf(0.0, hit_cooldown - delta)

	position.x += sweep_speed * sweep_direction * delta
	if position.x >= start_x + sweep_range:
		sweep_direction = -1.0
	elif position.x <= start_x - sweep_range:
		sweep_direction = 1.0

	$RayCast2D.force_raycast_update()
	var end_point: Vector2
	if $RayCast2D.is_colliding():
		var hit = $RayCast2D.get_collider()
		end_point = to_local($RayCast2D.get_collision_point())
		if hit_cooldown <= 0.0 and hit is CharacterBody2D and hit.is_in_group("players") and not hit.has_shield:
			hit.respawn()
			hit_cooldown = 1.0
	else:
		end_point = $RayCast2D.target_position

	$Line2D.clear_points()
	$Line2D.add_point(Vector2.ZERO)
	$Line2D.add_point(end_point)
