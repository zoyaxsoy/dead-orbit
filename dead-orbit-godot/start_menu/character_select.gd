extends Control

const FIRST_ROOM := "res://cut_scenes/start_to_one.tscn"
const LUNA_PORTRAIT := preload("res://start_menu/character_portraits/luna_standing_labeled.png")
const SOL_PORTRAIT := preload("res://start_menu/character_portraits/sol_standing_labeled.png")
const P1_DEFAULT := preload("res://start_menu/player_icon_states/player_icon_p1.png")
const P1_HOVER := preload("res://start_menu/player_icon_states/player_icon_p1_hover.png")
const P1_LOCKED := preload("res://start_menu/player_icon_states/player_icon_p1_locked.png")
const P2_DEFAULT := preload("res://start_menu/player_icon_states/player_icon_p2.png")
const P2_HOVER := preload("res://start_menu/player_icon_states/player_icon_p2_hover.png")
const P2_LOCKED := preload("res://start_menu/player_icon_states/player_icon_p2_locked.png")
const PRESS_A := preload("res://start_menu/buttons/status_press_a_to_lock_in_large_panel.png")
const LOCKED_IN := preload("res://start_menu/buttons/status_locked_in_large_panel.png")

var p1_hover: int = 0
var p2_hover: int = 0
var p1_locked: bool = false
var p2_locked: bool = false
var p1_joy_moved: bool = false
var p2_joy_moved: bool = false

var center_pos: Vector2
var luna_pos: Vector2
var sol_pos: Vector2

@onready var luna_portrait := $LunaPortrait
@onready var sol_portrait := $SolPortrait
@onready var p1_icon := $P1Icon
@onready var p2_icon := $P2Icon
@onready var p1_status := $P1Status
@onready var p2_status := $P2Status
@onready var confirm_graphic := $ConfirmGraphic

func _ready():
	FadeManager.fade_in(0.1)
	confirm_graphic.visible = false
	p1_status.visible = false
	p2_status.visible = false
	center_pos = get_viewport_rect().size / 2
	luna_pos = Vector2(luna_portrait.position.x + luna_portrait.size.x / 2, luna_portrait.position.y + luna_portrait.size.y / 2)
	sol_pos = Vector2(sol_portrait.position.x + sol_portrait.size.x / 2, sol_portrait.position.y + sol_portrait.size.y / 2)
	p1_icon.position = Vector2(center_pos.x - p1_icon.size.x / 2 - 100, center_pos.y - p1_icon.size.y / 2)
	p2_icon.position = Vector2(center_pos.x - p2_icon.size.x / 2 + 100, center_pos.y - p2_icon.size.y / 2)
	p1_icon.texture = P1_DEFAULT
	p2_icon.texture = P2_DEFAULT

func _process(_delta):
	if not p1_locked:
		if Input.is_action_just_pressed("luna_left") and not p1_joy_moved:
			p1_hover = 1
			p1_joy_moved = true
			_update_p1()
		elif Input.is_action_just_pressed("luna_right") and not p1_joy_moved:
			p1_hover = 2
			p1_joy_moved = true
			_update_p1()
		elif not Input.is_action_pressed("luna_left") and not Input.is_action_pressed("luna_right"):
			p1_joy_moved = false

	if not p2_locked:
		if Input.is_action_just_pressed("sol_left") and not p2_joy_moved:
			p2_hover = 1
			p2_joy_moved = true
			_update_p2()
		elif Input.is_action_just_pressed("sol_right") and not p2_joy_moved:
			p2_hover = 2
			p2_joy_moved = true
			_update_p2()
		elif not Input.is_action_pressed("sol_left") and not Input.is_action_pressed("sol_right"):
			p2_joy_moved = false

	var p1_a := Input.is_action_just_pressed("luna_up")
	if p1_a and not p1_locked and p1_hover != 0:
		if p1_hover != p2_hover or not p2_locked:
			p1_locked = true
			_update_p1()

	var p2_a := Input.is_action_just_pressed("sol_up")
	if p2_a and not p2_locked and p2_hover != 0:
		if p2_hover != p1_hover or not p1_locked:
			p2_locked = true
			_update_p2()

	if p1_locked and p2_locked:
		confirm_graphic.visible = true
		if Input.is_action_just_pressed("luna_up") or Input.is_action_just_pressed("sol_up"):
			_start_game()

func _update_p1():
	if p1_locked:
		p1_icon.texture = P1_LOCKED
		p1_status.visible = true
		p1_status.texture = LOCKED_IN
	elif p1_hover != 0:
		p1_icon.texture = P1_HOVER
		p1_status.visible = true
		p1_status.texture = PRESS_A
	else:
		p1_icon.texture = P1_DEFAULT
		p1_status.visible = false

	var tex_size := PRESS_A.get_size() if not p1_locked else LOCKED_IN.get_size()
	p1_status.size = tex_size
	if p1_hover == 1:
		p1_status.position = Vector2(luna_portrait.position.x + luna_portrait.size.x / 2 - tex_size.x / 2, luna_portrait.position.y - tex_size.y - 35)
	elif p1_hover == 2:
		p1_status.position = Vector2(sol_portrait.position.x + sol_portrait.size.x / 2 - tex_size.x / 2, sol_portrait.position.y - tex_size.y - 35)

	var target := _get_target_pos(p1_hover, p1_icon.size)
	var tween = create_tween()
	tween.tween_property(p1_icon, "position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _update_p2():
	if p2_locked:
		p2_icon.texture = P2_LOCKED
		p2_status.visible = true
		p2_status.texture = LOCKED_IN
	elif p2_hover != 0:
		p2_icon.texture = P2_HOVER
		p2_status.visible = true
		p2_status.texture = PRESS_A
	else:
		p2_icon.texture = P2_DEFAULT
		p2_status.visible = false

	var tex_size := PRESS_A.get_size() if not p2_locked else LOCKED_IN.get_size()
	p2_status.size = tex_size
	if p2_hover == 1:
		p2_status.position = Vector2(luna_portrait.position.x + luna_portrait.size.x / 2 - tex_size.x / 2, luna_portrait.position.y - tex_size.y - 35)
	elif p2_hover == 2:
		p2_status.position = Vector2(sol_portrait.position.x + sol_portrait.size.x / 2 - tex_size.x / 2, sol_portrait.position.y - tex_size.y - 35)

	var target := _get_target_pos(p2_hover, p2_icon.size)
	var tween = create_tween()
	tween.tween_property(p2_icon, "position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _get_target_pos(hover: int, icon_size: Vector2) -> Vector2:
	if hover == 1:
		return Vector2(luna_portrait.position.x + luna_portrait.size.x / 2 - icon_size.x / 2, luna_portrait.position.y + luna_portrait.size.y + 40)
	elif hover == 2:
		return Vector2(sol_portrait.position.x + sol_portrait.size.x / 2 - icon_size.x / 2, sol_portrait.position.y + sol_portrait.size.y + 40)
	return center_pos - icon_size / 2

func _remap_inputs():
	var luna_device := 0 if p1_hover == 1 else 1
	var sol_device := 1 if p1_hover == 1 else 0
	print("luna device: ", luna_device, " sol device: ", sol_device)
	print("p1_hover: ", p1_hover, " p2_hover: ", p2_hover)

	_reassign_action("luna_left", luna_device, JOY_AXIS_LEFT_X, -1)
	_reassign_action("luna_right", luna_device, JOY_AXIS_LEFT_X, 1)
	_reassign_action("luna_up", luna_device, JOY_BUTTON_A, -1)
	_reassign_action("luna_down", luna_device, JOY_AXIS_LEFT_Y, 1)
	_reassign_action("luna_shield", luna_device, JOY_BUTTON_B, -1)

	_reassign_action("sol_left", sol_device, JOY_AXIS_LEFT_X, -1)
	_reassign_action("sol_right", sol_device, JOY_AXIS_LEFT_X, 1)
	_reassign_action("sol_up", sol_device, JOY_BUTTON_A, -1)
	_reassign_action("sol_down", sol_device, JOY_AXIS_LEFT_Y, 1)
	_reassign_action("sol_shield", sol_device, JOY_BUTTON_B, -1)

func _reassign_action(action: String, device: int, axis_or_button: int, axis_value: int) -> void:
	InputMap.action_erase_events(action)
	var event: InputEvent
	if axis_or_button >= JOY_BUTTON_A and axis_or_button <= JOY_BUTTON_MISC1:
		var btn := InputEventJoypadButton.new()
		btn.device = device
		btn.button_index = axis_or_button
		event = btn
	else:
		var axis := InputEventJoypadMotion.new()
		axis.device = device
		axis.axis = axis_or_button
		axis.axis_value = axis_value
		event = axis
	InputMap.action_add_event(action, event)

func _start_game():
	_fade_out(FIRST_ROOM)

func _fade_in():
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _fade_out(next_scene: String):
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	canvas.add_child(overlay)
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 1), 0.8)
	tween.tween_callback(func(): get_tree().change_scene_to_file(next_scene))
