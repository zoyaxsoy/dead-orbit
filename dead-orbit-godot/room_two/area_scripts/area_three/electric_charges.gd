extends Node2D

@export var spawn_interval_min: float = 0.5
@export var spawn_interval_max: float = 2.0
@export var bolt_width: float = 6000  # horizontal spawn range

var active := false

func activate():
	active = true
	_schedule_next()

func _ready():
	pass  # don't start automatically anymore

func _schedule_next():
	if not active:
		return
	var wait = randf_range(spawn_interval_min, spawn_interval_max)
	await get_tree().create_timer(wait).timeout
	_spawn_bolt()
	_schedule_next()

func _spawn_bolt():
	var target = null
	for player in get_tree().get_nodes_in_group("players"):
		if player is CharacterBody2D and not player.has_shield:
			target = player
			break
	if target == null:
		return
	
	var local_pos = to_local(target.global_position)
	var x = local_pos.x
	var start_y = local_pos.y - 600
	var end_y = local_pos.y
	
	var segments = randi_range(6, 12)
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.9, 0.95, 1.0)
	add_child(line)
	var step = (end_y - start_y) / segments
	line.add_point(Vector2(x, start_y))
	for i in range(1, segments):
		var py = start_y + step * i
		var px = x + randf_range(-18, 18)
		line.add_point(Vector2(px, py))
	var end_x = x + randf_range(-8, 8)
	line.add_point(Vector2(end_x, end_y))

	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	area.add_child(shape)
	area.position = Vector2(end_x, end_y)
	add_child(area)
	area.body_entered.connect(_on_bolt_hit)

	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, randf_range(0.1, 0.3))
	tween.tween_callback(line.queue_free)
	tween.tween_callback(area.queue_free)
	
func _on_bolt_hit(body):
	if body.is_in_group("players") and not body.has_shield:
		for player in get_tree().get_nodes_in_group("players"):
			if player is CharacterBody2D:
				player.respawn()
