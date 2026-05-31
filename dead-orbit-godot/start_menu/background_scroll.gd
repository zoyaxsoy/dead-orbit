extends Node2D

@export var scroll_speed: float = 50.0
var bg_width: float = 0.0

func _ready():
	bg_width = $BG1.texture.get_width()
	$BG2.position.x = bg_width

func _process(delta):
	position.x -= scroll_speed * delta
	if position.x <= -bg_width:
		position.x = 0.0
