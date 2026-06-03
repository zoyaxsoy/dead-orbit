extends Node2D
@onready var player_a = $Players/Sol
@onready var player_b = $Players/Luna
@onready var tether_line = $TetherLine
@export var max_distance: float = 500.0
@export var pull_strength: float = 800.0

var _hud_cl: CanvasLayer = null
var _node_labels: Array = []
var _nodes_filled: Array = [false, false, false]
var _hint_shown: bool = false
var _hint_label: Label = null

func _process(delta):
	var a = player_a.global_position
	var b = player_b.global_position
	var mid = (a + b) / 2
	tether_line.points = [
		tether_line.to_local(a),
		tether_line.to_local(mid),
		tether_line.to_local(b)
	]

var is_taut: bool = false

func _physics_process(delta):
	var offset = player_b.global_position - player_a.global_position
	var distance = offset.length()
	is_taut = distance > max_distance
	if is_taut:
		var direction = offset.normalized()
		if player_a.is_on_floor():
			var correction = (distance - max_distance) * direction
			player_b.global_position -= correction
			var radial_speed = player_b.velocity.dot(direction)
			if radial_speed > 0:
				player_b.velocity -= direction * radial_speed * 0.3
		elif player_b.is_on_floor():
			var direction_a = -direction
			var correction = (distance - max_distance) * direction_a
			player_a.global_position -= correction
			var radial_speed = player_a.velocity.dot(direction_a)
			if radial_speed > 0:
				player_a.velocity -= direction_a * radial_speed * 0.3
		else:
			player_a.velocity += direction * pull_strength * delta
			player_b.velocity += -direction * pull_strength * delta

func _ready():
	FadeManager.fade_in()
	var window := get_tree().root
	window.content_scale_size = Vector2i(1152, 648)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	var intro = preload("res://room_two/cut_scenes/beg_cut_scene.gd").new()
	add_child(intro)
	intro.tree_exited.connect(func():
		var w := get_tree().root
		w.content_scale_size = Vector2i(0, 0)
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		if is_instance_valid(_hud_cl):
			_hud_cl.visible = true
	)

	_build_hud()
	_hud_cl.visible = false

	$Course/AreaTwo/Shield.activated.connect($Course/AreaTwo/MovingPlatform.activate)
	$Course/AreaTwo/Shield.activated.connect($Course/AreaTwo/CanvasLayer/ShieldPopUp.show_popup)
	$Course/AreaTwo/Shield.collected_by.connect(_on_shield_collected)
	$Course/AreaThree/PressurePlate/Area2D.pressed.connect($Course/AreaThree/EnergyNode.start_filling)
	$Course/AreaThree/PressurePlate/Area2D.released.connect($Course/AreaThree/EnergyNode.stop_filling)
	$Course/AreaTwo/PressurePlate/Area2D.pressed.connect($Course/AreaTwo/EnergyNode.start_filling)
	$Course/AreaTwo/PressurePlate/Area2D.released.connect($Course/AreaTwo/EnergyNode.stop_filling)
	$Course/AreaOne/PressurePlate/Area2D.pressed.connect($Course/AreaOne/EnergyNode.start_filling)
	$Course/AreaOne/PressurePlate/Area2D.released.connect($Course/AreaOne/EnergyNode.stop_filling)
	$Course/AreaOne/EnergyNode.filled.connect(func(): _on_node_filled(0))
	$Course/AreaTwo/EnergyNode.filled.connect(func(): _on_node_filled(1))
	$Course/AreaThree/EnergyNode.filled.connect(func(): _on_node_filled(2))
	$Checkpoints/CheckpointThree.body_entered.connect(_on_hint_trigger)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 100
	add_child(hud)
	_hud_cl = hud

	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	hud.add_child(root)

	var top_bar := ColorRect.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_top = 0.0
	top_bar.offset_bottom = 48.0
	top_bar.color = Color(0.02, 0.03, 0.05, 0.76)
	root.add_child(top_bar)
	
	var objective_lbl := Label.new()
	objective_lbl.text = "FILL ALL THE ENERGY NODES TO RESTART THE BACKUP GENERATOR"
	objective_lbl.offset_left = 18.0
	objective_lbl.offset_right = 700.0
	objective_lbl.offset_top = 7.0
	objective_lbl.offset_bottom = 27.0
	objective_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_lbl.add_theme_font_size_override("font_size", 18)
	objective_lbl.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	objective_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	objective_lbl.add_theme_constant_override("shadow_offset_x", 2)
	objective_lbl.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(objective_lbl)

	# Nodes label — far left
	var nodes_lbl := Label.new()
	nodes_lbl.name = "NodesLabel"
	nodes_lbl.text = "ENERGY NODES 0/3"
	nodes_lbl.offset_left = 720.0
	nodes_lbl.offset_right = 940.0
	nodes_lbl.offset_top = 7.0
	nodes_lbl.offset_bottom = 27.0
	nodes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nodes_lbl.add_theme_font_size_override("font_size", 18)
	nodes_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	nodes_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	nodes_lbl.add_theme_constant_override("shadow_offset_x", 2)
	nodes_lbl.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(nodes_lbl)
	_node_labels.append(nodes_lbl)

	# Controls label — after nodes label
	var ctrl_lbl := Label.new()
	ctrl_lbl.text = "L-STICK: MOVE     X (PLAYSTATION) / B (NINTENDO): JUMP     RIGHT-BUMPER: USE SHIELD     DOUBLE PRESS X/B TO DOUBLE JUMP       +/- FOR ROOM SELECT MENU       ASSETS CREATED BY CODEX"
	ctrl_lbl.anchor_right = 1.0
	ctrl_lbl.offset_left = 960.0
	ctrl_lbl.offset_top = 7.0
	ctrl_lbl.offset_bottom = 27.0
	ctrl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ctrl_lbl.add_theme_font_size_override("font_size", 18)
	ctrl_lbl.add_theme_color_override("font_color", Color(0.9, 1.0, 0.86))
	ctrl_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	ctrl_lbl.add_theme_constant_override("shadow_offset_x", 2)
	ctrl_lbl.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(ctrl_lbl)
	
	_hint_label = Label.new()
	_hint_label.text = "TRY SHIELDING ON TOP OF THE OTHER PLAYER"
	_hint_label.anchor_right = 1.0
	_hint_label.offset_top = 60.0
	_hint_label.offset_bottom = 90.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5, 1.0))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	_hint_label.add_theme_constant_override("shadow_offset_x", 2)
	_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	_hint_label.visible = false
	root.add_child(_hint_label)

func _on_shield_collected(player):
	player.collect_shield()
	
func _on_node_filled(index: int) -> void:
	_nodes_filled[index] = true
	if _node_labels.is_empty():
		return
	var count := _nodes_filled.count(true)
	var lbl: Label = _node_labels[0]
	lbl.text = "ENERGY NODES %d/3" % count
	if count >= 3:
		if is_instance_valid(_hud_cl):
			_hud_cl.visible = false


func _on_hint_trigger(body) -> void:
	if body.is_in_group("players") and not _hint_shown:
		_hint_shown = true
		_hint_label.visible = true
