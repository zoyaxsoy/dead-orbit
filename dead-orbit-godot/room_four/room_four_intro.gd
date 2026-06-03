extends CanvasLayer

var _hint: Label
var _dismissed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_blink_hint()

func _input(event: InputEvent) -> void:
	if _dismissed:
		return
	if event.is_action_pressed("dismiss_action") or \
	   event.is_action_pressed("sol_up") or \
	   event.is_action_pressed("luna_up"):
		_dismissed = true
		queue_free()

func _blink_hint() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_hint, "modulate:a", 0.15, 0.7)
	tw.tween_property(_hint, "modulate:a", 1.0,  0.7)

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.anchor_right  = 1.0
	scrim.anchor_bottom = 1.0
	scrim.color = Color(0.0, 0.01, 0.06, 0.82)
	add_child(scrim)

	var top_bar := ColorRect.new()
	top_bar.anchor_right  = 1.0
	top_bar.offset_bottom = 4.0
	top_bar.color = Color(0.05, 0.85, 1.0, 1.0)
	add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.anchor_top    = 1.0
	bot_bar.anchor_right  = 1.0
	bot_bar.anchor_bottom = 1.0
	bot_bar.offset_top    = -4.0
	bot_bar.color = Color(1.0, 0.45, 0.05, 1.0)
	add_child(bot_bar)

	_lbl("ROOM  4", 11, Color(0.05, 0.85, 1.0, 0.70), 18.0, 36.0)

	_lbl("LAST TRANSMISSION", 40, Color(0.90, 0.95, 1.00, 1.0), 40.0, 98.0,
		Color(0.0, 0.0, 0.0, 1.0), 4)

	var div := ColorRect.new()
	div.anchor_left  = 0.5
	div.anchor_right = 0.5
	div.offset_left  = -200.0
	div.offset_right =  200.0
	div.offset_top   =  104.0
	div.offset_bottom = 106.0
	div.color = Color(0.05, 0.85, 1.0, 0.45)
	add_child(div)

	_lbl("OBJECTIVE", 10, Color(0.35, 0.82, 1.0, 0.65), 118.0, 134.0)

	_lbl("Navigate pitch-black relay corridors using only your headlamp. Luna reaches the relay door while Sol tunes the radio signal to recover the crew code. Both players enter the code together to unlock each section.",
		13, Color(0.90, 0.88, 0.80, 0.95), 142.0, 190.0)

	_lbl("HAZARDS", 10, Color(1.0, 0.45, 0.05, 0.65), 204.0, 220.0)

	_lbl_icon("•", "Near-total darkness — only your headlamp illuminates nearby platforms.",
		Color(0.90, 0.88, 0.80, 0.95), 228.0, 250.0)

	_lbl_icon("•", "Platform gaps — missing a platform resets you to the start of the current section.",
		Color(0.90, 0.88, 0.80, 0.95), 256.0, 278.0)

	_lbl_icon("•", "Signal drift — the clean tuning window constantly shifts. Miss it and Sol must re-tune.",
		Color(0.90, 0.88, 0.80, 0.95), 284.0, 306.0)

	_lbl_icon("•", "Code sync pressure — both players must submit the same crew code within 3 seconds. A mismatch resets the attempt.",
		Color(0.90, 0.88, 0.80, 0.95), 312.0, 348.0)

	var div2 := ColorRect.new()
	div2.anchor_left  = 0.5
	div2.anchor_right = 0.5
	div2.offset_left  = -280.0
	div2.offset_right =  280.0
	div2.offset_top   =  406.0
	div2.offset_bottom = 408.0
	div2.color = Color(0.05, 0.85, 1.0, 0.30)
	add_child(div2)

	_hint = _lbl("Press B/X to begin", 13, Color(1.0, 1.0, 1.0, 1.0), 422.0, 446.0)

	_lbl_half("SOL",            12, Color(1.0,  0.45, 0.05, 0.85), 468.0, 484.0, true)
	_lbl_half("LUNA",           12, Color(0.35, 0.82, 1.0,  0.85), 468.0, 484.0, false)
	_lbl_half("L. Stick   move", 11, Color(0.50, 0.60, 0.80, 0.70), 488.0, 504.0, true)
	_lbl_half("L. Stick   move", 11, Color(0.50, 0.60, 0.80, 0.70), 488.0, 504.0, false)
	_lbl_half("X   jump",        11, Color(0.50, 0.60, 0.80, 0.70), 508.0, 524.0, true)
	_lbl_half("X   jump",        11, Color(0.50, 0.60, 0.80, 0.70), 508.0, 524.0, false)
	_lbl_half("Q / E   tune signal",   11, Color(0.50, 0.60, 0.80, 0.70), 528.0, 544.0, true)
	_lbl_half("D-pad   digit entry",   11, Color(0.50, 0.60, 0.80, 0.70), 528.0, 544.0, false)
	_lbl_half("F   capture / submit",  11, Color(0.50, 0.60, 0.80, 0.70), 548.0, 564.0, true)
	_lbl_half("Enter   submit",        11, Color(0.50, 0.60, 0.80, 0.70), 548.0, 564.0, false)

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
