extends Control

var selected_button: int = 0
var _joy_moved := false
var _input_enabled := false

func _ready():
	call_deferred("_build_credits_panel")
	$StartButton.pressed.connect(_on_start_pressed)
	$CreditsButton.pressed.connect(_on_credits_pressed)
	FadeManager.fade_in(0.3)
	_update_button_highlight()
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	_input_enabled = true

func _process(_delta):
	if not _input_enabled:
		return
	var axis := maxf(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(1, JOY_AXIS_LEFT_X)
	)
	var axis_min := minf(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(1, JOY_AXIS_LEFT_X)
	)
	if axis > 0.5 and not _joy_moved:
		_joy_moved = true
		selected_button = 1
		_update_button_highlight()
	elif axis_min < -0.5 and not _joy_moved:
		_joy_moved = true
		selected_button = 0
		_update_button_highlight()
	elif absf(axis) < 0.3 and absf(axis_min) < 0.3:
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
	FadeManager.fade_to_scene("res://start_menu/character_select.tscn", 0.1)

func _on_credits_pressed():
	$StartButton.visible = false
	$CreditsButton.visible = false
	$Logo.visible = false
	$CreditsPanel.visible = true

func _on_credits_back():
	$CreditsPanel.visible = false
	$StartButton.visible = true
	$CreditsButton.visible = true
	$Logo.visible = true
	_update_button_highlight()

func _build_credits_panel() -> void:
	var panel := $CreditsPanel
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vp_size := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.size = vp_size
	bg.color = Color(0.02, 0.03, 0.08, 0.85)
	panel.add_child(bg)

	var lbl := Label.new()
	lbl.size = vp_size
	lbl.text = "Developed by Saumya Navani, Zoya Soy, Anushka Raheja\n\nASSETS CREATED BY CODEX OR ROYALTY FREE ASSETS\n\nThank you for playing."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(lbl)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "BACK"
	back_btn.position = Vector2(vp_size.x * 0.5 - 80.0, vp_size.y - 100.0)
	back_btn.size = Vector2(160.0, 44.0)
	back_btn.pressed.connect(_on_credits_back)
	panel.add_child(back_btn)
