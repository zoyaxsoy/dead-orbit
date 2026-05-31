extends Control

const FIRST_ROOM := "res://room_one/room_one.tscn"

var elapsed: float = 0.0
var skipped: bool = false
var label: Label
var overlay: ColorRect

func _ready() -> void:
	FadeManager.fade_in()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	overlay = ColorRect.new()
	overlay.name = "IntroOverlay"
	overlay.color = Color(0.01, 0.015, 0.026, 0.92)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	add_child(overlay)

	label = Label.new()
	label.name = "IntroText"
	label.text = ""
	label.position = Vector2(70, 165)
	label.size = Vector2(820, 230)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 26)
	overlay.add_child(label)

func _process(delta: float) -> void:
	if skipped:
		return

	elapsed += delta

	if elapsed < 2.2:
		label.text = "[PLACEHOLDER] The station has gone dark."
	elif elapsed < 4.8:
		label.text = "[PLACEHOLDER] Two crew members are all that remain."
	else:
		label.text = "[PLACEHOLDER] Dead Orbit begins."

	if elapsed >= 7.0:
		_transition()

	if Input.is_action_just_pressed("luna_shield") or Input.is_action_just_pressed("sol_shield"):
		_transition()

func _transition() -> void:
	if skipped:
		return
	skipped = true
	FadeManager.fade_to_scene(FIRST_ROOM)
