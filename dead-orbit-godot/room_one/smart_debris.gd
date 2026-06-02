extends "res://room_one/rock.gd"

var path_points := PackedVector2Array()
var impact_x: float = 0.0
var original_impact_x: float = 0.0
var route_speed: float = 310.0
var dive_speed: float = 560.0
var steering_strength: float = 5.5
var tracking_strength: float = 1.25
var max_tracking_offset: float = 220.0
var tracking_lead: float = 65.0
var tracked_player: Node2D = null

var _path_index: int = 1
var _velocity: Vector2 = Vector2.ZERO
var _diving: bool = false

func configure_smart_path(points: PackedVector2Array, target_x: float, player_ref: Node2D = null) -> void:
	path_points = points
	impact_x = target_x
	original_impact_x = target_x
	tracked_player = player_ref
	_path_index = 1
	_diving = false
	if path_points.size() > 0:
		global_position = path_points[0]
	if path_points.size() > 1:
		_velocity = (path_points[1] - global_position).normalized() * route_speed
	else:
		_start_dive()

func _physics_process(delta: float) -> void:
	if _hit:
		return

	if _diving:
		_follow_dive(delta)
	else:
		_follow_route(delta)

	if global_position.y >= FLOOR_Y:
		global_position.y = FLOOR_Y
		_hit = true
		_check_floor_kill()
		_create_impact_hole()
		queue_free()

func _follow_route(delta: float) -> void:
	if _path_index >= path_points.size():
		_start_dive()
		return

	var target := path_points[_path_index]
	var to_target := target - global_position
	var close_enough := maxf(10.0, route_speed * delta * 1.25)
	if to_target.length() <= close_enough:
		global_position = target
		_path_index += 1
		if _path_index >= path_points.size():
			_start_dive()
		return

	var desired := to_target.normalized() * route_speed
	_velocity = _velocity.lerp(desired, clampf(steering_strength * delta, 0.0, 1.0))
	global_position += _velocity * delta

func _start_dive() -> void:
	_diving = true
	var target := Vector2(impact_x, FLOOR_Y)
	_velocity = (target - global_position).normalized() * dive_speed

func _follow_dive(delta: float) -> void:
	_nudge_impact_toward_player(delta)
	var target := Vector2(impact_x, FLOOR_Y)
	var to_target := target - global_position
	if to_target.length() > 1.0:
		var desired := to_target.normalized() * dive_speed
		_velocity = _velocity.lerp(desired, clampf(7.0 * delta, 0.0, 1.0))
	global_position += _velocity * delta

func _nudge_impact_toward_player(delta: float) -> void:
	if not is_instance_valid(tracked_player):
		return
	var desired_x := tracked_player.global_position.x + tracking_lead
	var left_limit := original_impact_x - max_tracking_offset
	var right_limit := original_impact_x + max_tracking_offset
	desired_x = clampf(desired_x, left_limit, right_limit)
	impact_x = lerpf(impact_x, desired_x, clampf(tracking_strength * delta, 0.0, 1.0))
