extends Node2D
@export var fill_speed := 300
@export var max_energy := 100.0
var energy := 0.0
var is_filling := false
signal filled

func _process(delta):
	if is_filling and energy < max_energy:
		energy += fill_speed * delta
		energy = min(energy, max_energy)
		update_visuals()
		if energy >= max_energy:
			emit_signal("filled")

func start_filling():
	is_filling = true

func stop_filling():
	is_filling = false

func update_visuals():
	var frame = int((energy / max_energy) * 5)
	$AnimatedSprite2D.frame = frame
	
