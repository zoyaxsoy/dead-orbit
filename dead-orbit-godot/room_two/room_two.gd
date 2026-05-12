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
			var correction = (distance - max_distance) * direction
			player_b.global_position -= correction
			var radial_speed = player_b.velocity.dot(direction)
			if radial_speed > 0:
				player_b.velocity -= direction * radial_speed

		elif player_b.is_on_floor():
			var direction_a = -direction
			var correction = (distance - max_distance) * direction_a
			player_a.global_position -= correction
			var radial_speed = player_a.velocity.dot(direction_a)
			if radial_speed > 0:
				player_a.velocity -= direction_a * radial_speed

		else:
			player_a.velocity += direction * pull_strength * delta
			player_b.velocity += -direction * pull_strength * delta

func _ready():
	$Course/AreaTwo/Shield.activated.connect($Course/AreaTwo/MovingPlatform.activate)
	$Course/AreaTwo/Shield.activated.connect($Course/AreaTwo/CanvasLayer/ShieldPopUp.show_popup)
