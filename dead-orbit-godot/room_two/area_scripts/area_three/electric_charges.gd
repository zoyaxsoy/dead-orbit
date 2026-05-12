extends Node2D

@export var spawn_interval_min: float = 0.5
@export var spawn_interval_max: float = 2.0
@export var bolt_width: float = 6000  # horizontal spawn range

func _ready():
	_schedule_next()

func _schedule_next():
	var wait = randf_range(spawn_interval_min, spawn_interval_max)
	await get_tree().create_timer(wait).timeout
	_spawn_bolt()
	_schedule_next()

func _spawn_bolt():
	var x = randf_range(3800, bolt_width)
	var start_y = -400
	var end_y = randf_range(100.0, 400.0)
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
	line.add_point(Vector2(x + randf_range(-8, 8), end_y))

	# fade out and remove
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, randf_range(0.1, 0.3))
	tween.tween_callback(line.queue_free)
