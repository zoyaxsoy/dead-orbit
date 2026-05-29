extends Area2D

@export var next_scene: String = "res://rooms/room_three.tscn"
var players_in_zone: int = 0
var triggered := false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("players"):
		players_in_zone += 1
		if players_in_zone >= 2 and not triggered:
			triggered = true
			_start_transition()

func _on_body_exited(body):
	if body.is_in_group("players"):
		players_in_zone -= 1

func _start_transition():
	var hud = CanvasLayer.new()
	add_child(hud)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0.01, 0.015, 0.026, 0.0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	hud.add_child(overlay)
	
	var label = Label.new()
	label.text = ""
	label.position = Vector2(70, 165)
	label.size = Vector2(820, 230)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
	label.add_theme_font_size_override("font_size", 26)
	overlay.add_child(label)
	
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0.01, 0.015, 0.026, 0.92), 1.0)
	tween.tween_interval(0.5)
	tween.tween_callback(func(): label.text = "Your narrative text here.")
	tween.tween_interval(2.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file(next_scene))
