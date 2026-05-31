extends Control

var selected_button: int = 0 

func _ready():
	$StartButton.pressed.connect(_on_start_pressed)
	$CreditsButton.pressed.connect(_on_credits_pressed)
	$CreditsPanel/BackButton.pressed.connect(_on_credits_back)
	FadeManager.fade_in()
	_update_button_highlight()

func _process(_delta):
	if $CreditsPanel.visible:
		if Input.is_action_just_pressed("luna_up") or Input.is_action_just_pressed("sol_up") or Input.is_action_just_pressed("dismiss_action"):
			_on_credits_back()
		return

	if Input.is_action_just_pressed("luna_left") or Input.is_action_just_pressed("sol_left"):
		print("left pressed")
		selected_button = 0
		_update_button_highlight()
	elif Input.is_action_just_pressed("luna_right") or Input.is_action_just_pressed("sol_right"):
		print("right pressed")
		selected_button = 1
		_update_button_highlight()

	if Input.is_action_just_pressed("luna_up") or Input.is_action_just_pressed("sol_up") or Input.is_action_just_pressed("dismiss_action"):
		if selected_button == 0:
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
