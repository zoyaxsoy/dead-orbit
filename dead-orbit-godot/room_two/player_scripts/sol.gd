extends CharacterBody2D

const JUMP_VELOCITY = -650.0
const GRAVITY = 1800.0
const MAX_FALL_SPEED = 900.0

@export var walk_speed: float = 500.0
@export var acceleration: float = 1780.0
@export var friction: float = 600.0
@export var air_speed: float = 600.0
@export var air_acceleration: float = 2000.0

var can_climb := false
var ladder = null
var climb_speed = 100
@onready var anim = $AnimatedSprite2D
@onready var room = get_parent().get_parent()
var has_shield: bool = false
var respawn_count: int = 0
var first_respawn_point: Vector2 = Vector2.ZERO
var respawn_point: Vector2 = Vector2.ZERO
var first_respawn_point_set: bool = false

func _ready():
	respawn_point = global_position
	if not first_respawn_point_set:
		first_respawn_point = global_position
		first_respawn_point_set = true

func respawn():
	respawn_count += 1
	if respawn_count >= 4:
		global_position = first_respawn_point
		respawn_count = 0
	else:
		global_position = respawn_point
	velocity = Vector2.ZERO

func collect_shield():
	has_shield = true

func _physics_process(delta: float) -> void:
	if can_climb:
		if Input.is_action_pressed("sol_up"):
			velocity.y = -climb_speed
		elif Input.is_action_pressed("sol_down"):
			velocity.y = climb_speed
		else:
			velocity.y = 0
		move_and_slide()
		return

	# gravity
	if not is_on_floor():
		var fall_multiplier = 1.8 if velocity.y > 0 else 0.9
		velocity.y += GRAVITY * fall_multiplier * delta
		velocity.y = minf(velocity.y, MAX_FALL_SPEED)

	# jump
	if Input.is_action_just_pressed("sol_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# horizontal movement
	var direction = Input.get_axis("sol_left", "sol_right")
	var current_speed := walk_speed if is_on_floor() else air_speed
	var current_accel := acceleration if is_on_floor() else air_acceleration

	if absf(direction) > 0.01:
		velocity.x = move_toward(velocity.x, direction * current_speed, current_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# facing
	if direction > 0:
		anim.flip_h = false
	elif direction < 0:
		anim.flip_h = true

	# animation
	if has_shield and Input.is_action_pressed("sol_shield") and direction != 0:
		anim.play("walk_w_shield")
	elif has_shield and Input.is_action_pressed("sol_shield") and direction == 0:
		anim.stop()
		anim.animation = "shield_idle"
		anim.frame = 0
	elif is_on_floor() and direction != 0 and not room.is_taut:
		anim.play("walk")
	else:
		anim.stop()
		anim.animation = "walk"
		anim.frame = 0

	move_and_slide()

	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is RigidBody2D and not has_shield:
			var push_direction = col.get_normal() * -1
			collider.apply_central_impulse(push_direction * 300.0)
