extends Area2D

signal activated
signal collected_by(player)

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("players"):
		collected_by.emit(body)
		activated.emit()
		queue_free()
