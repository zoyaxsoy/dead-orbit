extends CharacterBody2D

@export var speed: float = 250.0
@export var jump_velocity: float = -420.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction: float = 0.0
	if Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction += 1.0
	
	velocity.x = direction * speed

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
