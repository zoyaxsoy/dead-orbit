extends Control 

@onready var player_a = $HBoxContainer/SubViewportContainer/SubViewport/PlayerA
@onready var player_b = $HBoxContainer/SubViewportContainer2/SubViewport/PlayerB

@onready var camera_a = $HBoxContainer/SubViewportContainer/SubViewport/PlayerA/Camera2D 
@onready var camera_b = $HBoxContainer/SubViewportContainer2/SubViewport/PlayerB/Camera2D

@onready var viewport_a = $HBoxContainer/SubViewportContainer/SubViewport
@onready var viewport_b = $HBoxContainer/SubViewportContainer2/SubViewport

func _ready():
	viewport_b.world_2d = viewport_a.world_2d 
