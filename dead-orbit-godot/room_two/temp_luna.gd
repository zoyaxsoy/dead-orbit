extends CharacterBody2D 

var direction: Vector2 = Vector2(1,1) 
var speed: int = 500 
@onready var camera = $Camera2D

func _ready() -> void:
	camera.enabled = true

func _physics_process(delta: float) -> void: 
	direction = Input.get_vector("luna_left", "luna_right", "luna_up", "luna_down") 
	velocity = direction * speed 
	move_and_slide()
