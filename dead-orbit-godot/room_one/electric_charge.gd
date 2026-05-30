extends Area2D

@export var move_distance: float = 300.0
@export var move_speed: float = 0.9
@export var phase_offset: float = 0.0

var start_x: float
var elapsed: float = 0.0

@onready var _vis: Polygon2D = $ChargeVisual
var _glow: Polygon2D

func _ready() -> void:
	start_x = global_position.x
	_build_glow()

func _build_glow() -> void:
	_glow = Polygon2D.new()
	# Mirrors the sawtooth shape but 6px wider at every point — soft halo around the current
	_glow.polygon = PackedVector2Array([
		Vector2(-44, -2), Vector2(-25, -14), Vector2(-12, 1),
		Vector2(0, -14),  Vector2(12, 1),    Vector2(25, -14),
		Vector2(44, -2),  Vector2(44, 12),   Vector2(-44, 12)
	])
	_glow.color = Color(0.0, 0.55, 0.9, 0.0)      
	_glow.position = Vector2(0, 14)
	_glow.z_index = -1
	add_child(_glow)

func _process(delta: float) -> void:
	elapsed += delta
	global_position.x = start_x + sin(elapsed * move_speed + phase_offset) * move_distance

	# Pulse: abs(sin) keeps value in [0,1] so alpha never goes negative
	var pulse = abs(sin(elapsed * 4.5 + phase_offset))
	_glow.color.a = 0.12 + 0.28 * pulse
	_vis.modulate.a  = 0.72 + 0.28 * pulse
