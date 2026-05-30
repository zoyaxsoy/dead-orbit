extends CharacterBody2D

@export var is_sol: bool = true

const SPEED = 400.0
const JUMP_VELOCITY = -560.0
const GRAVITY = 1200.0

var start_position: Vector2

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	start_position = global_position
	_setup_sprite()

func _setup_sprite() -> void:
	var sheet_path: String
	if is_sol:
		sheet_path = "res://rooms/room_three_graphics/room3_sol_eva_sheet.png"
	else:
		sheet_path = "res://rooms/room_three_graphics/room3_luna_eva_sheet.png"

	var texture = load(sheet_path)
	var frames = SpriteFrames.new()
	frames.remove_animation("default")

	# 6 walk frames at 64x80 each, horizontally arranged
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 10.0)
	for i in 6:
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * 64, 0, 64, 80)
		frames.add_frame("walk", atlas)

	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 8.0)
	var idle_atlas = AtlasTexture.new()
	idle_atlas.atlas = texture
	idle_atlas.region = Rect2(0, 0, 64, 80)
	frames.add_frame("idle", idle_atlas)

	anim_sprite.sprite_frames = frames
	anim_sprite.scale = Vector2(1.2, 1.2)
	# Shift up so sprite bottom stays aligned with feet (compensates for scale growth)
	anim_sprite.position = Vector2(0, -25)
	anim_sprite.play("idle")

func respawn() -> void:
	global_position = start_position
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var up    = "sol_up"    if is_sol else "luna_up"
	var left  = "sol_left"  if is_sol else "luna_left"
	var right = "sol_right" if is_sol else "luna_right"

	if Input.is_action_just_pressed(up) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis(left, right)
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	if abs(velocity.x) > 20.0:
		if anim_sprite.animation != &"walk":
			anim_sprite.play("walk")
		anim_sprite.flip_h = velocity.x < 0.0
	else:
		if anim_sprite.animation != &"idle":
			anim_sprite.play("idle")
