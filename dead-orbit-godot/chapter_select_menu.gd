extends Node

var _menu_open: bool = false
var _menu_layer: CanvasLayer = null
var _selected_index: int = 0
var _buttons: Array = []
var _input_cooldown: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

const CHAPTERS = [
	{"name": "Room 1", "scene": "res://room_one/room_one.tscn"},
	{"name": "Room 2", "scene": "res://room_two/room_two.tscn"},
	{"name": "Room 3", "scene": "res://rooms/room_three.tscn"},
	{"name": "Room 4", "scene": "res://room_four/room_four.tscn"},
]

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("open_menu"):
		if _menu_open:
			_close_menu()
		else:
			_open_menu()

	if not _menu_open:
		return

	_input_cooldown = maxf(0.0, _input_cooldown - delta)
	if _input_cooldown > 0.0:
		return

	if Input.is_action_just_pressed("sol_left") or Input.is_action_just_pressed("luna_left"):
		_selected_index = wrapi(_selected_index - 1, 0, _buttons.size())
		_update_selection()
		_input_cooldown = 0.2

	if Input.is_action_just_pressed("sol_right") or Input.is_action_just_pressed("luna_right"):
		_selected_index = wrapi(_selected_index + 1, 0, _buttons.size())
		_update_selection()
		_input_cooldown = 0.2

	if Input.is_action_just_pressed("sol_up") or Input.is_action_just_pressed("luna_up"):
		_confirm_selection()

func _open_menu() -> void:
	_menu_open = true
	_selected_index = 0
	_buttons = []
	_input_cooldown = 0.3
	get_tree().paused = true

	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 100
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_menu_layer)

	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.02, 0.03, 0.08, 0.95)
	_menu_layer.add_child(bg)

	var title := Label.new()
	title.text = "SELECT ROOM"
	title.anchor_right = 1.0
	title.offset_top = 80.0
	title.offset_bottom = 140.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.05, 0.90, 1.0, 1.0))
	_menu_layer.add_child(title)

	# Hint label
	var hint := Label.new()
	hint.text = "L/R to select   B/X to confirm   Menu to close"
	hint.anchor_right = 1.0
	hint.offset_top = 148.0
	hint.offset_bottom = 175.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 0.7))
	_menu_layer.add_child(hint)

	# Build buttons horizontally centered
	var total_width := 0.0
	var button_width := 220.0
	var button_height := 120.0
	var gap := 30.0
	total_width = CHAPTERS.size() * button_width + (CHAPTERS.size() - 1) * gap
	var start_x := -total_width / 2.0

	for i in range(CHAPTERS.size()):
		var chapter = CHAPTERS[i]
		var x := start_x + i * (button_width + gap)
		var btn := _make_button(chapter["name"], chapter["scene"], x, button_width, button_height)
		_buttons.append(btn)

	_update_selection()

func _make_button(label: String, scene_path: String, x: float, w: float, h: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.anchor_top = 0.5
	bg.anchor_bottom = 0.5
	bg.offset_left = x
	bg.offset_right = x + w
	bg.offset_top = -h / 2.0
	bg.offset_bottom = h / 2.0
	bg.color = Color(0.08, 0.10, 0.16, 1.0)
	_menu_layer.add_child(bg)

	# Chapter number label (big)
	var num_lbl := Label.new()
	num_lbl.text = str(_buttons.size() + 1)
	num_lbl.anchor_right = 1.0
	num_lbl.offset_top = 10.0
	num_lbl.offset_bottom = 70.0
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.add_theme_font_size_override("font_size", 42)
	num_lbl.add_theme_color_override("font_color", Color(0.05, 0.90, 1.0, 1.0))
	bg.add_child(num_lbl)

	# Chapter name label (smaller)
	var lbl := Label.new()
	lbl.text = label
	lbl.anchor_right = 1.0
	lbl.offset_top = 72.0
	lbl.offset_bottom = 110.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0, 0.9))
	bg.add_child(lbl)

	bg.set_meta("scene_path", scene_path)

	return bg

func _update_selection() -> void:
	for i in range(_buttons.size()):
		var btn: ColorRect = _buttons[i]
		var num_lbl: Label = btn.get_child(0)
		var name_lbl: Label = btn.get_child(1)
		if i == _selected_index:
			btn.color = Color(0.05, 0.25, 0.35, 1.0)
			num_lbl.add_theme_color_override("font_color", Color(0.05, 0.90, 1.0, 1.0))
			name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			btn.color = Color(0.08, 0.10, 0.16, 1.0)
			num_lbl.add_theme_color_override("font_color", Color(0.3, 0.6, 0.8, 0.6))
			name_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0, 0.5))

func _confirm_selection() -> void:
	var scene_path: String = _buttons[_selected_index].get_meta("scene_path")
	if scene_path == "":
		_close_menu()
		return
	_menu_open = false
	get_tree().paused = false
	if is_instance_valid(_menu_layer):
		_menu_layer.queue_free()
	_menu_layer = null
	_buttons = []
	await get_tree().process_frame
	await get_tree().process_frame
	FadeManager.fade_to_scene(scene_path)

func _close_menu() -> void:
	_menu_open = false
	get_tree().paused = false
	if is_instance_valid(_menu_layer):
		_menu_layer.queue_free()
	_menu_layer = null
	_buttons = []
