extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("players"):
		for player in get_tree().get_nodes_in_group("players"):
			if player is CharacterBody2D:
				player.respawn_point = global_position
