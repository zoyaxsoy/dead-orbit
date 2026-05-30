extends Node2D

@onready var sol_level = $CanvasLayer/LeftSVC/LeftViewport/SolLevel
@onready var luna_level = $CanvasLayer/RightSVC/RightViewport/LunaLevel
@onready var sol_rocks_label: Label = $CanvasLayer/SolRocksLabel
@onready var luna_rocks_label: Label = $CanvasLayer/LunaRocksLabel

var _sol_complete: bool = false
var _luna_complete: bool = false

func _ready() -> void:
	sol_level.player_reached_exit.connect(_on_sol_at_exit)
	luna_level.player_reached_exit.connect(_on_luna_at_exit)
	sol_level.rocks_started.connect(_on_sol_rocks_started)
	luna_level.rocks_started.connect(_on_luna_rocks_started)
	sol_rocks_label.visible = false
	luna_rocks_label.visible = false

func _on_sol_rocks_started() -> void:
	sol_rocks_label.visible = true
	get_tree().create_timer(2.5).timeout.connect(func(): sol_rocks_label.visible = false)

func _on_luna_rocks_started() -> void:
	luna_rocks_label.visible = true
	get_tree().create_timer(2.5).timeout.connect(func(): luna_rocks_label.visible = false)

func _on_sol_at_exit() -> void:
	_sol_complete = true
	_check_both_done()

func _on_luna_at_exit() -> void:
	_luna_complete = true
	_check_both_done()

func _check_both_done() -> void:
	if _sol_complete and _luna_complete:
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://room_two/room_two.tscn")
