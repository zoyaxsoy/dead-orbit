extends Node2D

@onready var player_a = $Players/Sol
@onready var player_b = $Players/Luna
@onready var tether_line = $TetherLine
@export var max_distance: float = 500.0
@export var pull_strength: float = 800.0

func _process(delta):
	var a = player_a.global_position
	var b = player_b.global_position
	var mid = (a + b) / 2
	tether_line.points = [
		tether_line.to_local(a),
		tether_line.to_local(mid),
		tether_line.to_local(b)
	]

var is_taut: bool = false

func _physics_process(delta):
	var offset = player_b.global_position - player_a.global_position
	var distance = offset.length()
	is_taut = distance > max_distance
	if is_taut:
		var direction = offset.normalized()
		if player_a.is_on_floor():
			# Player A is anchor — let B swing freely around A
			var correction = (distance - max_distance) * direction
			player_b.global_position -= correction
			# Only remove outward velocity, keep tangential (swinging) velocity
			var radial_speed = player_b.velocity.dot(direction)
			if radial_speed > 0:
				player_b.velocity -= direction * radial_speed * 0.3  # was 1.0, now soft
		elif player_b.is_on_floor():
			# Player B is anchor — let A swing freely around B
			var direction_a = -direction
			var correction = (distance - max_distance) * direction_a
			player_a.global_position -= correction
			var radial_speed = player_a.velocity.dot(direction_a)
			if radial_speed > 0:
				player_a.velocity -= direction_a * radial_speed * 0.3  # soft constraint
		else:
			# Both in air — gentle pull toward each other
			player_a.velocity += direction * pull_strength * delta
			player_b.velocity += -direction * pull_strength * delta

func _ready():
	FadeManager.fade_in()
	var window := get_tree().root
	window.content_scale_size = Vector2i(1152, 648)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	var intro = preload("res://room_two/cut_scenes/beg_cut_scene.gd").new()
	add_child(intro)
	intro.tree_exited.connect(func():
		var w := get_tree().root
		w.content_scale_size = Vector2i(0, 0)
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	)
	
	$Course/AreaTwo/Shield.activated.connect($Course/AreaTwo/MovingPlatform.activate)
	$Course/AreaTwo/Shield.activated.connect($Course/AreaTwo/CanvasLayer/ShieldPopUp.show_popup)
	$Course/AreaTwo/Shield.collected_by.connect(_on_shield_collected)
	$Course/AreaThree/PressurePlate/Area2D.pressed.connect(func(): $Course/AreaThree/Ladder._on_pressure_plate_pressed())
	$Course/AreaThree/PressurePlate/Area2D.released.connect(func(): $Course/AreaThree/Ladder._on_pressure_plate_released())
	$Course/AreaThree/PressurePlate/Area2D.pressed.connect($Course/AreaThree/EnergyNode.start_filling)
	$Course/AreaThree/PressurePlate/Area2D.released.connect($Course/AreaThree/EnergyNode.stop_filling)
	$Course/AreaTwo/PressurePlate/Area2D.pressed.connect($Course/AreaTwo/EnergyNode.start_filling)
	$Course/AreaTwo/PressurePlate/Area2D.released.connect($Course/AreaTwo/EnergyNode.stop_filling)
	$Course/AreaOne/PressurePlate/Area2D.pressed.connect($Course/AreaOne/EnergyNode.start_filling)
	$Course/AreaOne/PressurePlate/Area2D.released.connect($Course/AreaOne/EnergyNode.stop_filling)
	

func _on_shield_collected(player):
	player.collect_shield()
