extends Area2D

var speed: float = 80.0
var fall_speed: float = 450.0

const FLOOR_Y: float = 619.0

# 6-column sprite sheet; pick one of the 6 large rocks in row 0 at random
const _SHEET_COLS = 6
const _CELL_W = 85
const _CELL_H = 90

var is_hazard: bool = true   # set false for atmospheric/visual-only rocks

var _hit: bool = false
var _trail_timer: float = 0.0
var _sprite: Sprite2D
var _col: int = 0   # sheet column chosen for this rock — passed to the impact hole

func _ready() -> void:
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://room_one/room_one_graphics/rocks_sheet.png")
	_sprite.region_enabled = true
	_col = randi() % _SHEET_COLS
	_sprite.region_rect = Rect2(_col * _CELL_W, 0, _CELL_W, _CELL_H)
	_sprite.scale = Vector2(0.6, 0.6)
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	if _hit:
		return

	global_position.x -= speed * delta
	global_position.y += fall_speed * delta
	_sprite.rotation += 3.5 * delta

	_trail_timer += delta
	if _trail_timer >= 0.04:
		_trail_timer = 0.0
		_spawn_ember()

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

func _spawn_ember() -> void:
	var r = randf_range(4.0, 11.0)
	var pts := PackedVector2Array()
	for i in 5:
		var angle = i * TAU / 5.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))

	var ember = Polygon2D.new()
	ember.polygon = pts
	var heat = randf()
	if heat > 0.65:
		ember.color = Color(1.0, 0.95, 0.5, 0.9)
	elif heat > 0.3:
		ember.color = Color(1.0, 0.5, 0.05, 0.88)
	else:
		ember.color = Color(1.0, 0.15, 0.0, 0.82)
	ember.z_index = -3

	var trail_offset = Vector2(randf_range(8.0, 28.0), randf_range(-10.0, 10.0))
	ember.position = global_position + trail_offset

	var level_node = get_parent().get_parent()
	if level_node:
		level_node.add_child(ember)
		var tween = ember.create_tween()
		tween.tween_property(ember, "modulate:a", 0.0, 0.38)
		tween.tween_callback(ember.queue_free)
