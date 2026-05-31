extends Area2D

@export var move_distance: float = 300.0
@export var move_speed: float = 0.9
@export var phase_offset: float = 0.0

var start_x: float
var elapsed: float = 0.0

const _FRAMES = [
	preload("res://room_one/room_one_graphics/lightning_frames/lightning_skill1_frame1.png"),
	preload("res://room_one/room_one_graphics/lightning_frames/lightning_skill1_frame2.png"),
	preload("res://room_one/room_one_graphics/lightning_frames/lightning_skill1_frame3.png"),
	preload("res://room_one/room_one_graphics/lightning_frames/lightning_skill1_frame4.png"),
]

const BOLT_SCALE  := 0.40
const BOLT_Y      := 12.0   # shifts base of bolt onto the floor line (Area2D is 12 px above floor)

var _shadow: AnimatedSprite2D
var _glow:   AnimatedSprite2D
var _anim:   AnimatedSprite2D

func _ready() -> void:
	start_x = global_position.x
	$ChargeVisual.visible = false

	var sf := _build_frames(12.0)

	# ── Dark border — slightly larger, near-black, drawn furthest back ──────────
	_shadow = AnimatedSprite2D.new()
	_shadow.sprite_frames = sf
	_shadow.play("spark")
	_shadow.frame    = randi() % _FRAMES.size()
	_shadow.scale    = Vector2(BOLT_SCALE + 0.07, BOLT_SCALE + 0.07)
	_shadow.position = Vector2(0.0, BOLT_Y + 1.0)   # 1 px lower = drop-shadow feel
	_shadow.modulate = Color(0.0, 0.02, 0.08, 0.90)
	_shadow.z_index  = -2
	add_child(_shadow)

	# ── Glow layer — soft blue halo ──────────────────────────────────────────────
	_glow = AnimatedSprite2D.new()
	_glow.sprite_frames = sf
	_glow.play("spark")
	_glow.frame    = randi() % _FRAMES.size()
	_glow.scale    = Vector2(BOLT_SCALE + 0.04, BOLT_SCALE + 0.04)
	_glow.position = Vector2(0.0, BOLT_Y)
	_glow.modulate = Color(0.3, 0.7, 2.0, 0.45)
	_glow.z_index  = -1
	add_child(_glow)

	# ── Main bolt — vivid electric blue, sits on the floor ───────────────────────
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = sf
	_anim.play("spark")
	_anim.frame    = randi() % _FRAMES.size()
	_anim.scale    = Vector2(BOLT_SCALE, BOLT_SCALE)
	_anim.position = Vector2(0.0, BOLT_Y)
	_anim.modulate = Color(1.1, 1.5, 2.8, 1.0)
	add_child(_anim)

func _build_frames(fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("spark")
	sf.set_animation_loop("spark", true)
	sf.set_animation_speed("spark", fps)
	for tex in _FRAMES:
		sf.add_frame("spark", tex)
	return sf

func _process(delta: float) -> void:
	elapsed += delta
	global_position.x = start_x + sin(elapsed * move_speed + phase_offset) * move_distance

	var pulse: float = abs(sin(elapsed * 5.0 + phase_offset))
	_anim.modulate.a   = 0.80 + 0.20 * pulse
	_glow.modulate.a   = 0.30 + 0.30 * pulse
	_shadow.modulate.a = 0.75 + 0.15 * pulse
