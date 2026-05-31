extends Control

func _ready():
	$StartButton.pressed.connect(_on_start_pressed)
	$CreditsButton.pressed.connect(_on_credits_pressed)
	$CreditsPanel/BackButton.pressed.connect(_on_credits_back)
	FadeManager.fade_in()

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
