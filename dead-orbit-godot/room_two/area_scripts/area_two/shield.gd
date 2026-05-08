extends Area2D

var triggered = false

signal activated

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("players") and not triggered:
		triggered = true
		activated.emit()
