extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 1000.0

@onready var anim = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("sol_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("sol_left", "sol_right")
	if is_on_floor():
		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * delta * 10)

	if direction > 0:
		anim.flip_h = false
	elif direction < 0:
		anim.flip_h = true

	if not is_on_floor():
		if velocity.y < 0:
			anim.play("jump")
		else:
			anim.play("fall")
	elif direction != 0:
		anim.play("run")
	else:
		anim.play("idle")

	move_and_slide()
