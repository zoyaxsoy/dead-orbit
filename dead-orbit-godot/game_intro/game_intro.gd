extends CanvasLayer

var _hint: Label

func _ready() -> void:
	_build_ui()
	_blink_hint()

func _build_ui() -> void:
	# ── Full-screen starfield background ─────────────────────────────────────
	var bg := ColorRect.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.0, 0.01, 0.04, 1.0)   # deep space black (shows through shader gaps)

	var shader := load("res://shaders/starfield_shader_v5.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("dimensions",              Vector2(1152.0, 648.0))
	mat.set_shader_parameter("small_stars",             80.0)
	mat.set_shader_parameter("large_stars",             12.0)
	mat.set_shader_parameter("small_stars_far_size",    0.4)
	mat.set_shader_parameter("small_stars_near_size",   0.9)
	mat.set_shader_parameter("large_stars_far_size",    0.5)
	mat.set_shader_parameter("large_stars_near_size",   1.0)
	mat.set_shader_parameter("far_stars_color",         Color(0.40, 0.30, 0.90, 0.85))
	mat.set_shader_parameter("near_stars_color",        Color(0.90, 0.95, 1.00, 1.00))
	mat.set_shader_parameter("base_scroll_speed",       0.01)
	mat.set_shader_parameter("additional_scroll_speed", 0.02)
	# Shader declares sampler2D uniforms for optional texture-based rendering paths
	# (those code paths are commented out, but Godot still needs a bound texture).
	var _img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_img.set_pixel(0, 0, Color.WHITE)
	var _tex := ImageTexture.create_from_image(_img)
	mat.set_shader_parameter("small_stars_texture", _tex)
	mat.set_shader_parameter("large_stars_texture", _tex)
	bg.material = mat
	add_child(bg)

	# ── Dark scrim — dims stars so text stays readable ────────────────────────
	var scrim := ColorRect.new()
	scrim.anchor_right  = 1.0
	scrim.anchor_bottom = 1.0
	scrim.color = Color(0.0, 0.01, 0.04, 0.62)
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

	# ── Game title ────────────────────────────────────────────────────────────
	_lbl("DEAD ORBIT", 44, Color(1.0, 0.50, 0.08, 1.0), 90.0, 148.0,
		Color(0.0, 0.0, 0.0, 1.0), 4)

	# ── Thin divider under title ──────────────────────────────────────────────
	var div := ColorRect.new()
	div.anchor_left  = 0.5
	div.anchor_right = 0.5
	div.offset_left  = -180.0
	div.offset_right =  180.0
	div.offset_top   =  155.0
	div.offset_bottom = 157.0
	div.color = Color(1.0, 0.45, 0.05, 0.45)
	add_child(div)

	# ── Story ─────────────────────────────────────────────────────────────────
	_lbl("The ship has been hit.\nSystems are unstable.\nThe path to safety is falling apart.",
		16, Color(0.90, 0.88, 0.80, 1.0), 175.0, 262.0)

	_lbl(
		"Sol and Luna must work together to cross the damaged sections\nof the ship, avoid the hazards left behind, and find their way\nto the escape pod.",
		14, Color(0.68, 0.74, 0.88, 0.90), 278.0, 360.0)

	_lbl("They cannot escape alone.", 15, Color(0.35, 0.82, 1.0, 1.0), 376.0, 410.0)

	# ── Thin divider above controls ───────────────────────────────────────────
	var div2 := ColorRect.new()
	div2.anchor_left  = 0.5
	div2.anchor_right = 0.5
	div2.offset_left  = -280.0
	div2.offset_right =  280.0
	div2.offset_top   =  430.0
	div2.offset_bottom = 432.0
	div2.color = Color(0.05, 0.85, 1.0, 0.30)
	add_child(div2)

	# ── Press any key ─────────────────────────────────────────────────────────
	_hint = _lbl("Press X to enter Room 1", 13, Color(1.0, 1.0, 1.0, 1.0), 442.0, 466.0)

	# ── Controls — two-column SOL (left) / LUNA (right) ─────────────────────
	_lbl_half("SOL",      14, Color(1.0,  0.45, 0.05, 1.0),  484.0, 504.0, true)
	_lbl_half("LUNA",     14, Color(0.35, 0.82, 1.0,  1.0),  484.0, 504.0, false)
	_lbl_half("L. Stick   move", 12, Color(0.55, 0.65, 0.85, 0.85), 506.0, 524.0, true)
	_lbl_half("L. Stick   move", 12, Color(0.55, 0.65, 0.85, 0.85), 506.0, 524.0, false)
	_lbl_half("X   jump",        12, Color(0.55, 0.65, 0.85, 0.85), 526.0, 544.0, true)
	_lbl_half("X   jump",        12, Color(0.55, 0.65, 0.85, 0.85), 526.0, 544.0, false)

# Helper — half-width centred label (left or right half of screen)
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

# Helper — full-width centred label anchored by top/bottom y offsets
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
		get_tree().change_scene_to_file("res://room_one/room_one.tscn")
