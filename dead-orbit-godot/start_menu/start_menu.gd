extends Control

var selected_button: int = 0 

func _ready():
	$StartButton.pressed.connect(_on_start_pressed)
	$CreditsButton.pressed.connect(_on_credits_pressed)
	$CreditsPanel/BackButton.pressed.connect(_on_credits_back)
	FadeManager.fade_in()
	_update_button_highlight()

var _joy_moved := false

func _process(_delta):
	var axis := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)

	if axis > 0.5 and not _joy_moved:
		_joy_moved = true
		selected_button = 1
		_update_button_highlight()
	elif axis < -0.5 and not _joy_moved:
		_joy_moved = true
		selected_button = 0
		_update_button_highlight()
	elif absf(axis) < 0.3:
		_joy_moved = false

	if Input.is_action_just_pressed("luna_up") or Input.is_action_just_pressed("sol_up"):
		if $CreditsPanel.visible:
			_on_credits_back()
		elif selected_button == 0:
			_on_start_pressed()
		else:
			_on_credits_pressed()

func _update_button_highlight():
	$StartButton.modulate = Color(1.0, 1.0, 1.0) if selected_button == 0 else Color(0.5, 0.5, 0.5)
	$CreditsButton.modulate = Color(1.0, 1.0, 1.0) if selected_button == 1 else Color(0.5, 0.5, 0.5)

func _on_start_pressed():
	FadeManager.fade_to_scene("res://start_menu/character_select.tscn")

func _on_credits_pressed():
	$StartButton.visible = false
	$CreditsButton.visible = false
	$CreditsPanel.visible = true

func _on_credits_back():
	$CreditsPanel.visible = false
	$StartButton.visible = true
	$CreditsButton.visible = true
	_update_button_highlight()
