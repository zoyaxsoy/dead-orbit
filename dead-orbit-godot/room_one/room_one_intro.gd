extends CanvasLayer

# Room 1 intro — overlaid on top of the live split-screen viewport.
# process_mode is ALWAYS (set in .tscn) so this runs while the tree is paused.

var _hint: Label

func _ready() -> void:
	get_tree().paused = true
	_build_ui()
	_blink_hint()

func _build_ui() -> void:
	# ── Semi-transparent dark scrim — lets the actual room show through ──────
	var scrim := ColorRect.new()
	scrim.anchor_right  = 1.0
	scrim.anchor_bottom = 1.0
	scrim.color = Color(0.0, 0.01, 0.06, 0.82)
	add_child(scrim)

	# ── Top accent bar (orange — Sol) ─────────────────────────────────────────
	var top_bar := ColorRect.new()
	top_bar.anchor_right  = 1.0
	top_bar.offset_bottom = 4.0
	top_bar.color = Color(1.0, 0.45, 0.05, 1.0)
	add_child(top_bar)

	# ── Bottom accent bar (cyan — Luna) ───────────────────────────────────────
	var bot_bar := ColorRect.new()
	bot_bar.anchor_top    = 1.0
	bot_bar.anchor_right  = 1.0
	bot_bar.anchor_bottom = 1.0
	bot_bar.offset_top    = -4.0
	bot_bar.color = Color(0.05, 0.85, 1.0, 1.0)
	add_child(bot_bar)

	# ── Room badge ────────────────────────────────────────────────────────────
	_lbl("ROOM  1", 11, Color(1.0, 0.45, 0.05, 0.70), 18.0, 36.0)

	# ── Room title ────────────────────────────────────────────────────────────
	_lbl("AIRLOCK BREACH", 40, Color(0.90, 0.95, 1.00, 1.0), 40.0, 98.0,
		Color(0.0, 0.0, 0.0, 1.0), 4)

	# ── Orange divider under title ────────────────────────────────────────────
	var div := ColorRect.new()
	div.anchor_left  = 0.5
	div.anchor_right = 0.5
	div.offset_left  = -200.0
	div.offset_right =  200.0
	div.offset_top   =  104.0
	div.offset_bottom = 106.0
	div.color = Color(1.0, 0.45, 0.05, 0.45)
	add_child(div)

	# ── Objective section ─────────────────────────────────────────────────────
	_lbl("OBJECTIVE", 10, Color(0.35, 0.82, 1.0, 0.65), 118.0, 134.0)

	_lbl("Both Sol and Luna must cross the corridor and reach the far end.",
		13, Color(0.90, 0.88, 0.80, 0.95), 142.0, 164.0)

	_lbl("Once both players reach the exit, hold the button together to reunite and unlock the next room.",
		13, Color(0.90, 0.88, 0.80, 0.95), 168.0, 204.0)

	# ── Hazard section (no divider — flows directly from objective) ───────────
	_lbl("HAZARDS", 10, Color(1.0, 0.45, 0.05, 0.65), 218.0, 234.0)

	_lbl_icon("⚡", "Electrical currents move across the damaged floor. Watch the pattern and cross at the right moment.",
		Color(0.90, 0.88, 0.80, 0.95), 242.0, 282.0)

	_lbl_icon("☄", "Debris from the breach can crash through parts of the corridor. Stay alert as you move forward.",
		Color(0.90, 0.88, 0.80, 0.95), 288.0, 328.0)

	_lbl_icon("▲", "Sections of the floor have collapsed. Watch your footing and avoid the openings.",
		Color(0.90, 0.88, 0.80, 0.95), 334.0, 372.0)

	# ── Cyan divider above hint ───────────────────────────────────────────────
	var div2 := ColorRect.new()
	div2.anchor_left  = 0.5
	div2.anchor_right = 0.5
	div2.offset_left  = -280.0
	div2.offset_right =  280.0
	div2.offset_top   =  406.0
	div2.offset_bottom = 408.0
	div2.color = Color(0.05, 0.85, 1.0, 0.30)
	add_child(div2)

	# ── Press Space hint (blinking) ───────────────────────────────────────────
	_hint = _lbl("Press X to begin", 13, Color(1.0, 1.0, 1.0, 1.0), 422.0, 446.0)

	# ── Control reminder — two-column SOL / LUNA ──────────────────────────────
	_lbl_half("SOL",      12, Color(1.0,  0.45, 0.05, 0.85), 468.0, 484.0, true)
	_lbl_half("LUNA",     12, Color(0.35, 0.82, 1.0,  0.85), 468.0, 484.0, false)
	_lbl_half("L. Stick   move", 11, Color(0.50, 0.60, 0.80, 0.70), 488.0, 504.0, true)
	_lbl_half("L. Stick   move", 11, Color(0.50, 0.60, 0.80, 0.70), 488.0, 504.0, false)
	_lbl_half("X   jump",        11, Color(0.50, 0.60, 0.80, 0.70), 508.0, 524.0, true)
	_lbl_half("X   jump",        11, Color(0.50, 0.60, 0.80, 0.70), 508.0, 524.0, false)
	_lbl_half("B   button",      11, Color(0.50, 0.60, 0.80, 0.70), 528.0, 544.0, true)
	_lbl_half("B   button",      11, Color(0.50, 0.60, 0.80, 0.70), 528.0, 544.0, false)

# ── Icon + text row — icon left-pinned, text fills the rest ──────────────────
func _lbl_icon(icon: String, txt: String, col: Color,
		top_y: float, bot_y: float) -> void:
	var ico := Label.new()
	ico.text = icon
	ico.offset_left   = 320.0
	ico.offset_right  = 360.0
	ico.offset_top    = top_y
	ico.offset_bottom = bot_y
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ico.add_theme_font_size_override("font_size", 14)
	ico.add_theme_color_override("font_color", col)
	add_child(ico)

	var lbl := Label.new()
	lbl.text = txt
	lbl.offset_left   = 368.0
	lbl.offset_right  = -320.0
	lbl.anchor_right  = 1.0
	lbl.offset_top    = top_y
	lbl.offset_bottom = bot_y
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	add_child(lbl)

# ── Half-width centred label (left or right half of screen) ──────────────────
func _lbl_half(txt: String, font_sz: int, col: Color,
		top_y: float, bot_y: float, left_half: bool) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left   = 0.0 if left_half else 0.5
	lbl.anchor_right  = 0.5 if left_half else 1.0
	lbl.offset_top    = top_y
	lbl.offset_bottom = bot_y
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	add_child(lbl)
	return lbl

# ── Full-width centred label ──────────────────────────────────────────────────
func _lbl(txt: String, font_sz: int, col: Color,
		top_y: float, bot_y: float,
		outline_col := Color(0, 0, 0, 1), outline_sz := 2) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_right  = 1.0
	lbl.offset_top    = top_y
	lbl.offset_bottom = bot_y
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", outline_col)
	lbl.add_theme_constant_override("outline_size", outline_sz)
	add_child(lbl)
	return lbl

func _blink_hint() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_hint, "modulate:a", 0.15, 0.7)
	tw.tween_property(_hint, "modulate:a", 1.0,  0.7)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().paused = false
		queue_free()
