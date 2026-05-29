extends Node2D

@export var beam_length: float = 1000.0
@export var rotation_speed: float = 2.0
@export var sweep_range: float = 200.0
@export var sweep_speed: float = 100.0

var active := false
var player_in_range := false
var sweep_direction: float = 1.0
var start_x: float = 0.0
var base_rotation: float = 0.0

func activate():
	active = true

func _ready():
	start_x = position.x
	base_rotation = rotation_degrees
	$RayCast2D.enabled = true
	$RayCast2D.target_position = Vector2(beam_length, 0)
	$Line2D.width = 5.0
	$Line2D.default_color = Color(1.0, 0.0, 0.0)
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("players") and not body.has_shield:
		player_in_range = true

func _on_body_exited(body):
	if body.is_in_group("players") and not body.has_shield:
		player_in_range = false

func _physics_process(delta):
	if not active:
		return

	if not player_in_range:
		position.x += sweep_speed * sweep_direction * delta
		if position.x >= start_x + sweep_range:
			sweep_direction = -1.0
		elif position.x <= start_x - sweep_range:
			sweep_direction = 1.0
		rotation_degrees = base_rotation
	else:
		var target = null
		for player in get_tree().get_nodes_in_group("players"):
			if player is CharacterBody2D and not player.has_shield:
				target = player
				break
		
		if target != null:
			$RayCast2D.force_raycast_update()
			var blocked_by_shield = false
			if $RayCast2D.is_colliding():
				var hit = $RayCast2D.get_collider()
				if hit is CharacterBody2D and hit.has_shield:
					blocked_by_shield = true
			
			if not blocked_by_shield:
				var direction = target.global_position - global_position
				var target_angle = direction.angle()
				rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)

	$RayCast2D.force_raycast_update()
	var end_point: Vector2
	if $RayCast2D.is_colliding():
		var hit = $RayCast2D.get_collider()
		end_point = to_local($RayCast2D.get_collision_point())
		if hit is CharacterBody2D and hit.is_in_group("players") and not hit.has_shield and player_in_range:
			for player in get_tree().get_nodes_in_group("players"):
				if player is CharacterBody2D:
					player.respawn()
	else:
		end_point = $RayCast2D.target_position

	$Line2D.clear_points()
	$Line2D.add_point(Vector2.ZERO)
	$Line2D.add_point(end_point)
