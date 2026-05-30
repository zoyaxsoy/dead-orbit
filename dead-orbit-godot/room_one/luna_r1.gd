extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -560.0
const GRAVITY = 1200.0
const DEATH_Y = 720.0

var start_position: Vector2

func _ready() -> void:
	start_position = global_position
	add_to_group("players")

func respawn() -> void:
	global_position = start_position
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("luna_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("luna_left", "luna_right")
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if global_position.y > DEATH_Y:
		var room = get_tree().get_first_node_in_group("room_controller")
		if room:
			room.respawn_player(self)
