extends Area2D

signal pressed
signal released

@export var requires_stay := false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body.is_in_group("players"):
		$"../AnimatedSprite2D".play("down")
		plate_pressed()

func _on_body_exited(body: Node2D):
	if body.is_in_group("players"):
		$"../AnimatedSprite2D".play("up")
		plate_released()

func plate_pressed():
	pressed.emit()

func plate_released():
	released.emit()
