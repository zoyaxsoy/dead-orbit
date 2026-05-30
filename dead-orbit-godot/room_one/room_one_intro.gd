extends CanvasLayer

var _hint: Label

func _ready() -> void:
	get_tree().paused = true
	_build_ui()
	_blink_hint()

func _build_ui() -> void:
	var overlay = ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.0, 0.0, 0.05, 0.88)
	add_child(overlay)

	var box = ColorRect.new()
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -290.0
	box.offset_top = -200.0
	box.offset_right = 290.0
	box.offset_bottom = 200.0
	box.grow_horizontal = 2
	box.grow_vertical = 2
	box.color = Color(0.07, 0.09, 0.15, 0.97)
	add_child(box)

	var top_bar = ColorRect.new()
	top_bar.anchor_left = 0.5
	top_bar.anchor_top = 0.5
	top_bar.anchor_right = 0.5
	top_bar.anchor_bottom = 0.5
	top_bar.offset_left = -290.0
	top_bar.offset_top = -200.0
	top_bar.offset_right = 290.0
	top_bar.offset_bottom = -191.0
	top_bar.grow_horizontal = 2
	top_bar.grow_vertical = 2
	top_bar.color = Color(1.0, 0.45, 0.05, 1.0)
	add_child(top_bar)

	var bot_bar = ColorRect.new()
	bot_bar.anchor_left = 0.5
	bot_bar.anchor_top = 0.5
	bot_bar.anchor_right = 0.5
	bot_bar.anchor_bottom = 0.5
	bot_bar.offset_left = -290.0
	bot_bar.offset_top = 191.0
	bot_bar.offset_right = 290.0
	bot_bar.offset_bottom = 200.0
	bot_bar.grow_horizontal = 2
	bot_bar.grow_vertical = 2
	bot_bar.color = Color(0.05, 0.65, 1.0, 1.0)
	add_child(bot_bar)

	_add_label("— ROOM 1 —", -270.0, -182.0, 270.0, -155.0,
		Color(1.0, 0.45, 0.05, 1.0), Color(0,0,0,0), 0, 15)

	_add_label("CORRIDOR BREACH", -270.0, -150.0, 270.0, -108.0,
		Color(0.95, 0.92, 0.85, 1.0), Color(0, 0, 0, 1.0), 3, 30)

	_add_label(
		"The ship's outer corridor has been breached.\nDebris is raining in from space. Avoid the\nelectric floor currents and jump the hull gaps.\nWatch out — space rocks incoming in the second half!",
		-260.0, -100.0, 260.0, 40.0,
		Color(0.75, 0.80, 0.90, 1.0), Color(0,0,0,0), 0, 14)

	_add_label("SOL: A / D  move    W  jump        LUNA: ← / →  move    ↑  jump",
		-270.0, 50.0, 270.0, 76.0,
		Color(0.35, 0.82, 1.0, 1.0), Color(0,0,0,0), 0, 13)

	_hint = _add_label("Press SPACE to begin", -200.0, 148.0, 200.0, 174.0,
		Color(1.0, 1.0, 1.0, 1.0), Color(0,0,0,0), 0, 14)

func _add_label(txt: String, l: float, t: float, r: float, b: float,
		fg: Color, outline: Color, outline_sz: int, font_sz: int) -> Label:
	var lbl = Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left   = 0.5
	lbl.anchor_top    = 0.5
	lbl.anchor_right  = 0.5
	lbl.anchor_bottom = 0.5
	lbl.offset_left   = l
	lbl.offset_top    = t
	lbl.offset_right  = r
	lbl.offset_bottom = b
	lbl.grow_horizontal = 2
	lbl.grow_vertical   = 2
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", fg)
	if outline_sz > 0:
		lbl.add_theme_color_override("font_outline_color", outline)
		lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.add_theme_font_size_override("font_size", font_sz)
	add_child(lbl)
	return lbl

func _blink_hint() -> void:
	var tw = create_tween().set_loops()
	tw.tween_property(_hint, "modulate:a", 0.15, 0.6)
	tw.tween_property(_hint, "modulate:a", 1.0,  0.6)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("sol_shield") or \
	   Input.is_action_just_pressed("luna_shield") or \
	   Input.is_action_just_pressed("ui_accept"):
		get_tree().paused = false
		queue_free()
