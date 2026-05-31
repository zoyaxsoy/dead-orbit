extends Control

func _ready():
	$StartButton.pressed.connect(_on_start_pressed)
	$CreditsButton.pressed.connect(_on_credits_pressed)
	$CreditsPanel/BackButton.pressed.connect(_on_credits_back)
	_fade_in()

func _fade_in():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.2)
	tween.tween_callback(overlay.queue_free)

func _fade_out(next_scene: String):
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 1), 0.2)
	tween.tween_callback(func(): get_tree().change_scene_to_file(next_scene))

func _on_start_pressed():
	_fade_out("res://start_menu/character_select.tscn")

func _on_credits_pressed():
	$MainButtons.visible = false
	$CreditsPanel.visible = true

func _on_credits_back():
	$CreditsPanel.visible = false
	$MainButtons.visible = true
