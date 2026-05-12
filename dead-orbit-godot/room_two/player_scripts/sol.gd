extends CharacterBody2D

const SPEED = 500.0
const JUMP_VELOCITY = -650.0
const GRAVITY = 1200.0

@onready var anim = $AnimatedSprite2D
@onready var room = get_parent().get_parent()

var respawn_point: Vector2 = Vector2.ZERO

func _ready():
	respawn_point = global_position

func respawn():
	global_position = respawn_point
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("sol_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("sol_left", "sol_right")
	if direction != 0:
		velocity.x = direction * SPEED
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if direction > 0:
		anim.flip_h = false
	elif direction < 0:
		anim.flip_h = true

	if is_on_floor() and direction != 0 and not room.is_taut:
		anim.play("walk")
	else:
		anim.stop()
		anim.frame = 0
	
	move_and_slide()
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is RigidBody2D:
			var push_force = 300.0
			var direction_box = col.get_normal() * -1
			collider.apply_central_impulse(direction_box * push_force)
	
