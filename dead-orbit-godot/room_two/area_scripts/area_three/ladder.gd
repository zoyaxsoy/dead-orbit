extends Node2D

func _ready():
	$ClimbArea.body_entered.connect(_on_climb_area_entered)
	$ClimbArea.body_exited.connect(_on_climb_area_exited)

func _on_pressure_plate_pressed():
	$AnimatedSprite2D.play("down")

func _on_pressure_plate_released():
	$AnimatedSprite2D.play_backwards("down")

func _on_climb_area_entered(body):
	if body.is_in_group("player"):
		body.can_climb = true
		body.ladder = self

func _on_climb_area_exited(body):
	if body.is_in_group("player"):
		body.can_climb = false
		body.ladder = null
