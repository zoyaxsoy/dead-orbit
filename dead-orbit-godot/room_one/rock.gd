extends Area2D

var speed: float = 80.0
var fall_speed: float = 450.0

const FLOOR_Y: float = 619.0
const ANIM_FPS: float = 14.0

var is_hazard: bool = true   # set false for atmospheric/visual-only rocks

# Preload all 11 meteor frames once at import time
const _FRAMES = [
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0001.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0002.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0003.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0004.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0005.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0006.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0007.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0008.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0009.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0010.png"),
	preload("res://room_one/room_one_graphics/meteor_frames/meteor0011.png"),
]

var _hit: bool = false
var _anim: AnimatedSprite2D
var _col: int = 0   # kept so create_rock_hole call signature stays the same

func _ready() -> void:
	# Collision circle — centred on the rock body (lower portion of the frame)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)

	# Build SpriteFrames from preloaded textures
	var frames = SpriteFrames.new()
	frames.add_animation("fall")
	frames.set_animation_loop("fall", true)
	frames.set_animation_speed("fall", ANIM_FPS)
	for tex in _FRAMES:
		frames.add_frame("fall", tex)

	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = frames
	_anim.play("fall")
	# Randomise starting frame so simultaneous meteors don't animate in sync
	_anim.frame = randi() % _FRAMES.size()

	# Frame is 233×400 px.  Rock sits in the bottom ~25 % (≈ y 300–400).
	# Rock centre ≈ y 350 → 150 px below frame centre (y 200).
	# At scale 0.2 that's 30 px.  Shift sprite UP 30 px so the rock centre
	# sits at the Area2D origin; the flame trails naturally above it.
	_anim.scale    = Vector2(0.2, 0.2)
	_anim.position = Vector2(0.0, -30.0)
	add_child(_anim)

	_col = randi() % 6   # not used for rendering but kept for API compat

func _physics_process(delta: float) -> void:
	if _hit:
		return

	global_position.x -= speed * delta
	global_position.y += fall_speed * delta

	if global_position.y >= FLOOR_Y:
		_hit = true
		_create_impact_hole()
		queue_free()

func _create_impact_hole() -> void:
	if not is_hazard:
		return
	var level_node = get_parent().get_parent()
	if level_node and level_node.has_method("create_rock_hole"):
		level_node.create_rock_hole(global_position.x, _col)
