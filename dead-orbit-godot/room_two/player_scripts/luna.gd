extends CharacterBody2D

const SPEED = 500.0
const JUMP_VELOCITY = -650.0
const GRAVITY = 1200.0
var can_climb := false
var ladder = null
var climb_speed = 100

@onready var anim = $AnimatedSprite2D
@onready var room = get_parent().get_parent()

var has_shield: bool = false
var respawn_count: int = 0
var first_respawn_point: Vector2 = Vector2.ZERO
var respawn_point: Vector2 = Vector2.ZERO

func _ready():
	respawn_point = global_position
	first_respawn_point = global_position

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
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("luna_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("luna_left", "luna_right")
	if direction != 0:
		velocity.x = direction * SPEED
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if direction > 0:
		anim.flip_h = false
	elif direction < 0:
		anim.flip_h = true

	if has_shield and Input.is_action_pressed("luna_shield") and direction != 0:
		anim.play("walk_w_shield")
	elif has_shield and Input.is_action_pressed("luna_shield") and direction == 0:
		anim.stop()
		anim.animation = "shield_idle"
		anim.frame = 0
	elif is_on_floor() and direction != 0 and not room.is_taut:
		anim.play("walk")
	else:
		anim.stop()
		anim.animation = "walk"
		anim.frame = 0
		
	if can_climb:
		if Input.is_action_pressed("luna_up"):
			velocity.y = -climb_speed
		elif Input.is_action_pressed("luna_down"):
			velocity.y = climb_speed
		else:
			velocity.y = 0
		move_and_slide()
		return

	# push rigidbodies
	move_and_slide()
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is RigidBody2D and not has_shield:
			var push_direction = col.get_normal() * -1
			collider.apply_central_impulse(push_direction * 300.0)
