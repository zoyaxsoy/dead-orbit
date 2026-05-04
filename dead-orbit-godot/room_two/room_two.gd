extends Node2D
@onready var player_a = $Sol
@onready var player_b = $Luna
@onready var tether_line = $TetherLine

var max_distance := 200

func _process(delta):
	var a = player_a.global_position
	var b = player_b.global_position

	var mid = (a + b) / 2
	# mid.y += 5  # sag amount

	tether_line.points = [
		tether_line.to_local(a),
		tether_line.to_local(mid),
		tether_line.to_local(b)
	]
	
func _physics_process(delta):
	var a_pos = player_a.global_position
	var b_pos = player_b.global_position
	var offset = b_pos - a_pos
	var distance = offset.length()

	if distance > max_distance:
		var direction = offset.normalized()
		var extra_distance = distance - max_distance
		var pull_strength = 8.0

		player_a.global_position += direction * extra_distance * 0.5 * pull_strength * delta
		player_b.global_position -= direction * extra_distance * 0.5 * pull_strength * delta
