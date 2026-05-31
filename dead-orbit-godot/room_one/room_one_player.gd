extends CharacterBody2D

@export var is_sol: bool = true

const SPEED = 250.0
const JUMP_VELOCITY = -560.0
const GRAVITY = 1200.0
const COYOTE_TIME = 0.12   # seconds after leaving floor where a ground jump still fires

var start_position: Vector2
var _coyote_timer: float = 0.0
var _has_air_jump: bool = true   # one double-jump available while airborne

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
	var on_floor := is_on_floor()

	if not on_floor:
		velocity.y += GRAVITY * delta

	var up    = "sol_up"    if is_sol else "luna_up"
	var left  = "sol_left"  if is_sol else "luna_left"
	var right = "sol_right" if is_sol else "luna_right"

	# Coyote time — restore double jump and reset window whenever on the floor
	if on_floor:
		_coyote_timer = COYOTE_TIME
		_has_air_jump = true
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	# Jump: ground / coyote first; one air jump if neither applies
	if Input.is_action_just_pressed(up):
		if on_floor or _coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			_coyote_timer = 0.0   # consume the coyote window so it can't fire twice
		elif _has_air_jump:
			velocity.y = JUMP_VELOCITY
			_has_air_jump = false

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
