extends Control

@onready var sol_level = $CanvasLayer/LeftSVC/LeftViewport/SolLevel
@onready var luna_level = $CanvasLayer/RightSVC/RightViewport/LunaLevel
@onready var sol_rocks_label: Label = $CanvasLayer/SolRocksLabel
@onready var luna_rocks_label: Label = $CanvasLayer/LunaRocksLabel

const HOLD_DURATION: float = 5.0   # seconds both players must hold simultaneously

var _sol_complete: bool = false
var _luna_complete: bool = false
var _sol_pressing: bool = false
var _luna_pressing: bool = false
var _button_timer: float = 0.0
var _button_activated: bool = false
var _prompt_cl: CanvasLayer = null
var _progress_bar: ColorRect = null
var _progress_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	FadeManager.fade_in()
	sol_level.player_reached_exit.connect(_on_sol_at_exit)
	luna_level.player_reached_exit.connect(_on_luna_at_exit)
	sol_level.player_left_exit.connect(_on_sol_left_exit)
	luna_level.player_left_exit.connect(_on_luna_left_exit)
	sol_level.button_state_changed.connect(_on_sol_button)
	luna_level.button_state_changed.connect(_on_luna_button)
	sol_level.rocks_started.connect(_on_sol_rocks_started)
	luna_level.rocks_started.connect(_on_luna_rocks_started)
	sol_rocks_label.visible = false
	luna_rocks_label.visible = false
	_setup_player_labels()

func _input(event: InputEvent) -> void:
	$CanvasLayer/LeftSVC/LeftViewport.push_input(event)
	$CanvasLayer/RightSVC/RightViewport.push_input(event)

func _setup_player_labels() -> void:
	var root := Control.new()
	root.anchor_right  = 1.0
	root.anchor_bottom = 1.0
	$CanvasLayer.add_child(root)

	# ── Sol — left half ───────────────────────────────────────────────────────
	_player_lbl(root, "SOL",           14, Color(1.0,  0.45, 0.05, 1.0),  true,  10.0)
	_player_lbl(root, "L. Stick   move", 11, Color(0.50, 0.60, 0.80, 0.70), true,  30.0)
	_player_lbl(root, "X   jump",        11, Color(0.50, 0.60, 0.80, 0.70), true,  46.0)
	_player_lbl(root, "B   button",      11, Color(0.50, 0.60, 0.80, 0.70), true,  62.0)

	# ── Luna — right half ─────────────────────────────────────────────────────
	_player_lbl(root, "LUNA",            14, Color(0.35, 0.82, 1.0,  1.0),  false, 10.0)
	_player_lbl(root, "L. Stick   move", 11, Color(0.50, 0.60, 0.80, 0.70), false, 30.0)
	_player_lbl(root, "X   jump",        11, Color(0.50, 0.60, 0.80, 0.70), false, 46.0)
	_player_lbl(root, "B   button",      11, Color(0.50, 0.60, 0.80, 0.70), false, 62.0)

func _player_lbl(parent: Control, txt: String, font_sz: int, col: Color,
		left_half: bool, top_y: float) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.anchor_left  = 0.0 if left_half else 0.5
	lbl.anchor_right = 0.5 if left_half else 1.0
	lbl.offset_left  = 16.0 if left_half else 0.0
	lbl.offset_right = 0.0 if left_half else -16.0
	lbl.offset_top    = top_y
	lbl.offset_bottom = top_y + font_sz + 4.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left_half else HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 3)
	parent.add_child(lbl)

func _process(delta: float) -> void:
	if not _sol_complete or not _luna_complete or _button_activated:
		return
	if _sol_pressing and _luna_pressing:
		_button_timer = min(_button_timer + delta, HOLD_DURATION)
	else:
		# Drain twice as fast when either player releases
		_button_timer = max(_button_timer - delta * 2.0, 0.0)
	_update_prompt_bar()
	if _button_timer >= HOLD_DURATION:
		_button_activated = true
		_hide_prompt()
		_show_celebration()

# ── Rocks label ───────────────────────────────────────────────────────────────

func _on_sol_rocks_started() -> void:
	sol_rocks_label.visible = true
	get_tree().create_timer(2.5).timeout.connect(func(): sol_rocks_label.visible = false)

func _on_luna_rocks_started() -> void:
	luna_rocks_label.visible = true
	get_tree().create_timer(2.5).timeout.connect(func(): luna_rocks_label.visible = false)

# ── Exit state ────────────────────────────────────────────────────────────────

func _on_sol_at_exit() -> void:
	_sol_complete = true
	_check_both_done()

func _on_luna_at_exit() -> void:
	_luna_complete = true
	_check_both_done()

func _on_sol_left_exit() -> void:
	_sol_complete = false
	_sol_pressing = false
	_button_timer = 0.0
	_button_activated = false
	_hide_prompt()

func _on_luna_left_exit() -> void:
	_luna_complete = false
	_luna_pressing = false
	_button_timer = 0.0
	_button_activated = false
	_hide_prompt()

# ── Button state ──────────────────────────────────────────────────────────────

func _on_sol_button(pressing: bool) -> void:
	_sol_pressing = pressing

func _on_luna_button(pressing: bool) -> void:
	_luna_pressing = pressing

# ── Coordination ──────────────────────────────────────────────────────────────

func _check_both_done() -> void:
	if _sol_complete and _luna_complete:
		_show_button_prompt()

# ── Button prompt (bottom-of-screen shared UI) ────────────────────────────────

func _show_button_prompt() -> void:
	if is_instance_valid(_prompt_cl) or _button_activated:
		return   # already showing or already done
	_button_timer = 0.0

	# Dismiss the per-player banners and button sprites — shared prompt takes over
	sol_level.hide_exit_ui()
	luna_level.hide_exit_ui()

	var cl := CanvasLayer.new()
	cl.layer = 25   # above exit banners (10), below celebration (30)
	add_child(cl)
	_prompt_cl = cl

	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	cl.add_child(root)

	# Same y-zone as the individual exit banners (TOP=110, BOTTOM=270)
	const TOP: float    = 110.0
	const BOTTOM: float = 270.0

	# Dark banner background
	var bg := ColorRect.new()
	bg.anchor_right  = 1.0
	bg.offset_top    = TOP
	bg.offset_bottom = BOTTOM
	bg.color = Color(0.0, 0.02, 0.08, 0.92)
	root.add_child(bg)

	# Cyan accent lines (top and bottom border)
	var top_line := ColorRect.new()
	top_line.anchor_right  = 1.0
	top_line.offset_top    = TOP
	top_line.offset_bottom = TOP + 3.0
	top_line.color = Color(0.05, 0.85, 1.0, 1.0)
	root.add_child(top_line)

	var bot_line := ColorRect.new()
	bot_line.anchor_right  = 1.0
	bot_line.offset_top    = BOTTOM - 3.0
	bot_line.offset_bottom = BOTTOM
	bot_line.color = Color(0.05, 0.85, 1.0, 1.0)
	root.add_child(bot_line)

	# Row 1 — instruction
	var instr := Label.new()
	instr.text = "Both players need to press the button to move on to the next level"
	instr.anchor_right = 1.0
	instr.offset_top    = TOP + 14.0
	instr.offset_bottom = TOP + 34.0
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0, 0.9))
	instr.add_theme_font_size_override("font_size", 12)
	root.add_child(instr)

	# Row 2 — percentage label (large, centered)
	var pct_lbl := Label.new()
	pct_lbl.text = "0%"
	pct_lbl.anchor_right = 1.0
	pct_lbl.offset_top    = TOP + 44.0
	pct_lbl.offset_bottom = TOP + 70.0
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct_lbl.add_theme_color_override("font_color", Color(0.05, 0.90, 1.0, 1.0))
	pct_lbl.add_theme_font_size_override("font_size", 18)
	root.add_child(pct_lbl)
	_progress_label = pct_lbl

	# Row 3 — progress bar background (centre 672 px of the 1152 px window)
	var bar_bg := ColorRect.new()
	bar_bg.offset_left   = 240.0
	bar_bg.offset_right  = 912.0
	bar_bg.offset_top    = TOP + 78.0
	bar_bg.offset_bottom = TOP + 102.0
	bar_bg.color = Color(0.08, 0.10, 0.16, 1.0)
	root.add_child(bar_bg)

	# Row 3 — progress bar fill (right edge driven by _update_prompt_bar)
	var bar := ColorRect.new()
	bar.offset_left   = 240.0
	bar.offset_right  = 240.0    # starts empty
	bar.offset_top    = TOP + 78.0
	bar.offset_bottom = TOP + 102.0
	bar.color = Color(0.05, 0.85, 1.0, 1.0)
	root.add_child(bar)
	_progress_bar = bar

	# Fade in
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.3)

func _prompt_side_label(parent: Control, txt: String, col: Color,
		x_left: float, x_right: float, top_y: float) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.offset_left   = x_left
	lbl.offset_right  = x_right
	lbl.offset_top    = top_y
	lbl.offset_bottom = top_y + 26.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 13)
	parent.add_child(lbl)

func _update_prompt_bar() -> void:
	if not is_instance_valid(_progress_bar):
		return
	var t: float = clamp(_button_timer / HOLD_DURATION, 0.0, 1.0)
	# Bar grows from x=240 to x=912 (672 px total)
	_progress_bar.offset_right = 240.0 + t * 672.0
	# Brighter cyan while both pressing, dim when draining
	_progress_bar.color = Color(0.05, 0.90, 1.0, 1.0) if (_sol_pressing and _luna_pressing) \
						else Color(0.05, 0.55, 0.75, 1.0)
	# Percentage label
	if is_instance_valid(_progress_label):
		_progress_label.text = str(int(t * 100)) + "%"

func _hide_prompt() -> void:
	if is_instance_valid(_prompt_cl):
		_prompt_cl.queue_free()
	_prompt_cl = null
	_progress_bar = null
	_progress_label = null

# ── Celebration ───────────────────────────────────────────────────────────────

func _show_celebration() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 30
	add_child(cl)

	# ── UI root (full-screen Control for all 2D UI elements) ─────────────────
	var root := Control.new()
	root.anchor_right  = 1.0
	root.anchor_bottom = 1.0
	cl.add_child(root)

	# ── Background image — parallax corridor backdrop ─────────────────────────
	var bg_img := TextureRect.new()
	bg_img.texture = load("res://room_one/room_one_graphics/parallax/background.png") as Texture2D
	bg_img.anchor_right  = 1.0
	bg_img.anchor_bottom = 1.0
	bg_img.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(bg_img)

	# ── Dark scrim so text stays readable ────────────────────────────────────
	var overlay := ColorRect.new()
	overlay.anchor_right  = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.0, 0.01, 0.06, 0.55)
	root.add_child(overlay)

	# ── Accent bars ───────────────────────────────────────────────────────────
	var top_bar := ColorRect.new()
	top_bar.anchor_right  = 1.0
	top_bar.offset_bottom = 6.0
	top_bar.color = Color(0.05, 0.85, 1.0, 1.0)
	root.add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.anchor_top    = 1.0
	bot_bar.anchor_right  = 1.0
	bot_bar.anchor_bottom = 1.0
	bot_bar.offset_top    = -6.0
	bot_bar.color = Color(0.05, 0.85, 1.0, 1.0)
	root.add_child(bot_bar)

	# ── Title ─────────────────────────────────────────────────────────────────
	_cel_label(root, "BREACH CLEARED", Color(0.05, 0.90, 1.0, 1.0), 44, 88.0)

	# ── Subtitle ──────────────────────────────────────────────────────────────
	_cel_label(root, "TETHER SECURED", Color(0.90, 0.95, 1.0, 0.80), 16, 154.0)

	# ── Player checkmarks (below the standing sprites) ────────────────────────
	_cel_label_half(root, "SOL  ✓",  Color(1.0, 0.55, 0.05, 1.0), 18, 556.0, true)
	_cel_label_half(root, "LUNA  ✓", Color(0.3,  0.75, 1.0, 1.0), 18, 556.0, false)

	# ── Footer — blinking ─────────────────────────────────────────────────────
	var sub := _cel_label(root, "Entering Room 2...", Color(0.72, 0.76, 0.88, 0.75), 13, 598.0)
	var blink := sub.create_tween().set_loops()
	blink.tween_property(sub, "modulate:a", 0.2, 0.6)
	blink.tween_property(sub, "modulate:a", 1.0, 0.6)

	# ── Sol sprite — left of centre, floating ─────────────────────────────────
	var sol_tex := load("res://rooms/room_three_graphics/room3_sol_eva_sheet.png") as Texture2D
	var sol_spr := Sprite2D.new()
	sol_spr.texture = sol_tex
	sol_spr.hframes  = 6
	sol_spr.frame    = 0
	sol_spr.scale    = Vector2(3.0, 3.0)
	sol_spr.position = Vector2(320.0, 488.0)
	cl.add_child(sol_spr)

	# ── Luna sprite — right of centre, standing ───────────────────────────────
	var luna_tex := load("res://rooms/room_three_graphics/room3_luna_eva_sheet.png") as Texture2D
	var luna_spr := Sprite2D.new()
	luna_spr.texture = luna_tex
	luna_spr.hframes  = 6
	luna_spr.frame    = 0
	luna_spr.scale    = Vector2(3.0, 3.0)
	luna_spr.position = Vector2(832.0, 488.0)
	cl.add_child(luna_spr)

	# ── Tether — draws from Sol to Luna over 1.5 s ───────────────────────────
	var tether := TetherLine.new()
	tether.sol_node  = sol_spr
	tether.luna_node = luna_spr
	cl.add_child(tether)
	# Animate the draw_progress after fade-in completes
	var tether_tw := tether.create_tween()
	tether_tw.tween_interval(0.6)   # wait for fade-in
	tether_tw.tween_property(tether, "draw_progress", 1.0, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# ── Fade everything in together ───────────────────────────────────────────
	root.modulate.a     = 0.0
	sol_spr.modulate.a  = 0.0
	luna_spr.modulate.a = 0.0
	tether.modulate.a   = 0.0
	var fade := root.create_tween()
	fade.tween_property(root,     "modulate:a", 1.0, 0.5)
	fade.parallel().tween_property(sol_spr,  "modulate:a", 1.0, 0.5)
	fade.parallel().tween_property(luna_spr, "modulate:a", 1.0, 0.5)
	fade.parallel().tween_property(tether,   "modulate:a", 1.0, 0.5)

	await get_tree().create_timer(3.5).timeout
	get_tree().change_scene_to_file("res://room_two/room_two.tscn")

# ── Label helpers ─────────────────────────────────────────────────────────────

# Full-width centered label
func _cel_label(parent: Control, txt: String, col: Color,
		font_sz: int, y: float) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.anchor_right = 1.0
	lbl.offset_top    = y
	lbl.offset_bottom = y + font_sz + 10.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", font_sz)
	parent.add_child(lbl)
	return lbl

# Half-width label — left_half=true for Sol, false for Luna
func _cel_label_half(parent: Control, txt: String, col: Color,
		font_sz: int, y: float, left_half: bool) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.anchor_left  = 0.0 if left_half else 0.5
	lbl.anchor_right = 0.5 if left_half else 1.0
	lbl.offset_top    = y
	lbl.offset_bottom = y + font_sz + 10.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", font_sz)
	parent.add_child(lbl)
	return lbl

# ── Tether — animated wavy line connecting Sol and Luna in the celebration ─────

class TetherLine extends Node2D:
	var sol_node:      Node2D = null
	var luna_node:     Node2D = null
	var draw_progress: float  = 0.0   # 0 = hidden, 1 = fully drawn Sol→Luna
	var elapsed:       float  = 0.0

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(sol_node) or not is_instance_valid(luna_node):
			return
		if draw_progress <= 0.0:
			return

		var from_p := sol_node.position  + Vector2( 48.0, 0.0)
		var full_to := luna_node.position + Vector2(-48.0, 0.0)

		# Current tip of the tether (animates from Sol to Luna)
		var current_end := from_p.lerp(full_to, draw_progress)

		# Quadratic bezier control point — gentle droop that grows as line extends
		var droop := 28.0 * draw_progress
		var ctrl  := from_p.lerp(current_end, 0.5) + Vector2(0.0, droop)

		# Build bezier curve
		var count := 32
		var pts   := PackedVector2Array()
		for i in range(count + 1):
			var t  := float(i) / float(count)
			var t1 := 1.0 - t
			# Quadratic bezier: B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
			pts.append(t1 * t1 * from_p + 2.0 * t1 * t * ctrl + t * t * current_end)

		# Very subtle pulse — barely perceptible, just keeps it alive
		var pulse: float = 0.88 + 0.12 * absf(sin(elapsed * 1.4))

		draw_polyline(pts, Color(0.20, 0.75, 1.0, 0.22 * pulse), 7.0, true)   # outer glow
		draw_polyline(pts, Color(0.50, 0.92, 1.0, 0.50 * pulse), 3.0, true)   # mid
		draw_polyline(pts, Color(0.90, 1.00, 1.0, 0.92 * pulse), 1.5, true)   # core
