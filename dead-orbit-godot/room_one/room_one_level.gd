extends Node2D

signal player_reached_exit
signal player_left_exit          # fired when player dies after already reaching exit
signal rocks_started
signal button_state_changed(is_pressing: bool)  # player holding exit button

const CAM_Y = 324.0
const CAM_MIN_X = 288.0
const CAM_MAX_X = 5612.0
const HALFWAY_X = 2950.0
const MID_RESPAWN_X = 2950.0
const DEATH_Y = 720.0
const ROCK_SPEED_BASE = 80.0
const ROCK_INTERVAL_MIN = 0.8
const ROCK_INTERVAL_MAX = 1.5
const ROCK_SPAWN_Y = 50.0
const HOLE_RADIUS = 48.0
const ROCK_GRACE_SECONDS = 0.8
const ROCK_SPAWN_CUTOFF = 5800.0   # hazard spawn-ahead cap (= exit x so rocks fall right to door)
const EXIT_X = 5800.0              # matches Exit node position.x
const ROCK_STOP_DIST = 50.0        # stop ALL rocks within the last 50 px of exit
const _BUTTON_X = 5830.0           # floor button world x — right at the exit wall

# Static gap x-ranges — filled in at runtime so only dynamic rock holes exist
const _GAPS = [[3100.0, 3220.0], [3780.0, 3910.0], [4550.0, 4690.0]]
const _FLOOR_TOP = 619.0

@export var player_is_sol: bool = true

@onready var camera: Camera2D = $Camera2D
@onready var player = $Player
@onready var rocks: Node2D = $Rocks
@onready var exit_area: Area2D = $Exit
@onready var back_layer: Parallax2D = $BackLayer
@onready var mid_layer: Parallax2D = $MidLayer
@onready var front_layer: Parallax2D = $FrontLayer

var _parallax_ref_x: float = 0.0
var _rocks_active: bool = false
var _rock_timer: float = 0.0
var _next_rock_time: float = 2.0
var _rock_pause: float = 0.0
var _level_complete: bool = false
var _is_dying: bool = false   # true while death overlay is showing
var _exit_overlay_cl: CanvasLayer = null  # reference so we can dismiss it on full restart
var _button_spr: Sprite2D = null          # floor button visual
var _button_hint_cl: CanvasLayer = null   # world-space "S / ↓ to press" label beside button
var _button_pressing: bool = false        # is this player currently holding the button

# Each entry: {x1, x2, body: StaticBody2D, shape: CollisionShape2D}
var _floor_segs: Array = []
# Visual nodes added by _add_impact_visuals — cleared on respawn
var _hole_visuals: Array = []
# Tile sprite tracking: {x1, x2, node} for every currently-visible tile strip
var _floor_tile_sprites: Array = []
# x1/x2 ranges of original tiles destroyed by a pit — recreated fresh on clear
var _split_original_ranges: Array = []

var _rock_script = preload("res://room_one/rock.gd")

func _ready() -> void:
	# Apply player identity — must happen before first physics frame.
	# Level's _ready() runs after player's _ready() (children first), so we
	# re-apply is_sol here and reinitialise the sprite to match.
	player.is_sol = player_is_sol
	player._setup_sprite()

	camera.make_current()
	camera.global_position = Vector2(CAM_MIN_X, CAM_Y)
	back_layer.scroll_scale = Vector2.ZERO
	mid_layer.scroll_scale = Vector2.ZERO
	front_layer.scroll_scale = Vector2.ZERO

	_build_floor_segs()
	_fill_static_gaps()

	for charge in $Charges.get_children():
		charge.body_entered.connect(_on_hazard_body_entered)

	exit_area.body_entered.connect(_on_exit_body_entered)
	_setup_exit_visual()
	_setup_button()
	_setup_floor_visuals()

func _process(delta: float) -> void:
	if _is_dying:
		return

	# Death check runs in ALL states — even after reaching exit.
	# Falling into a pit at the exit triggers a full restart.
	if player.global_position.y > DEATH_Y:
		_respawn()
		return

	if _level_complete:
		# Keep camera + parallax running so the button (at _BUTTON_X) stays on screen
		# even if the camera was lagging when the exit was triggered.
		_update_camera(delta)
		_update_parallax()
		if _rocks_active:
			_tick_rocks(delta)
			_clean_rocks()
		_update_button_state()
		return

	_update_camera(delta)
	_update_parallax()
	_check_halfway()
	if _rocks_active:
		_tick_rocks(delta)
		_clean_rocks()

func _update_camera(delta: float) -> void:
	camera.global_position.x = clamp(
		lerp(camera.global_position.x, player.global_position.x, 7.0 * delta),
		CAM_MIN_X, CAM_MAX_X
	)
	camera.global_position.y = CAM_Y

func _update_parallax() -> void:
	_parallax_ref_x = camera.global_position.x
	back_layer.scroll_offset = Vector2(-_parallax_ref_x * 0.12, 0.0)
	mid_layer.scroll_offset = Vector2(-_parallax_ref_x * 0.32, 0.0)
	front_layer.scroll_offset = Vector2(-_parallax_ref_x * 0.62, 0.0)

func _check_halfway() -> void:
	if not _rocks_active and player.global_position.x > HALFWAY_X:
		_rocks_active = true
		rocks_started.emit()

func _tick_rocks(delta: float) -> void:
	if _rock_pause > 0.0:
		_rock_pause -= delta
		return
	_rock_timer += delta
	if _rock_timer >= _next_rock_time:
		_rock_timer = 0.0
		_next_rock_time = randf_range(ROCK_INTERVAL_MIN, ROCK_INTERVAL_MAX)
		_spawn_rock()

func _spawn_rock() -> void:
	# Stop ALL rocks (hazard + atmospheric) once player is within 50 px of exit
	if player.global_position.x >= EXIT_X - ROCK_STOP_DIST:
		return

	# ── Hazard rock (ahead of player, punches floor hole, kills on contact) ──
	# 560 px offset: rock enters camera view ~0.65 s into fall with ~0.8 s left
	# before landing — visible long enough to see coming and react.
	var spawn_x = player.global_position.x + 560.0
	if spawn_x <= ROCK_SPAWN_CUTOFF:
		var r = _make_rock(spawn_x, randf_range(380.0, 520.0))
		r.body_entered.connect(_on_hazard_body_entered)

	# ── Atmospheric rocks (behind, on, and slightly in front of player) ──────
	# Range covers the player's body so rocks visibly rain down on the astronaut.
	for _i in randi() % 2 + 1:
		var atm_x = player.global_position.x + randf_range(-200.0, 150.0)
		if atm_x > HALFWAY_X:
			var ar = _make_rock(atm_x, randf_range(160.0, 280.0))
			ar.is_hazard = false  # won't kill; won't punch a floor hole

func _make_rock(spawn_x: float, fall_spd: float) -> Area2D:
	var rock = Area2D.new()
	rock.set_script(_rock_script)
	rocks.add_child(rock)
	rock.speed = ROCK_SPEED_BASE + randf_range(-40.0, 60.0)
	rock.fall_speed = fall_spd
	rock.global_position = Vector2(spawn_x, ROCK_SPAWN_Y)
	return rock

func _clean_rocks() -> void:
	for rock in rocks.get_children():
		if rock.global_position.x < camera.global_position.x - 400.0:
			rock.queue_free()

func _respawn() -> void:
	if _is_dying:
		return
	_is_dying = true

	# Capture exit state NOW before we clear it, so we know which path to take.
	var was_at_exit := _level_complete
	_level_complete = false   # allow _process to run normally after restart

	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	_show_death_overlay()
	await get_tree().create_timer(1.5).timeout
	player.set_physics_process(true)

	if was_at_exit:
		_execute_full_restart()
		player_left_exit.emit()   # tell room_one.gd to reset that player's completion flag
	else:
		_execute_respawn()

	_is_dying = false

func _execute_respawn() -> void:
	if _rocks_active:
		for rock in rocks.get_children():
			rock.queue_free()
		_clear_rock_holes()
		_rock_timer = 0.0
		_next_rock_time = randf_range(ROCK_INTERVAL_MIN, ROCK_INTERVAL_MAX)
		_rock_pause = ROCK_GRACE_SECONDS
		player.global_position = Vector2(MID_RESPAWN_X, _FLOOR_TOP - 32.0)
		player.velocity = Vector2.ZERO
		camera.global_position = Vector2(clamp(MID_RESPAWN_X, CAM_MIN_X, CAM_MAX_X), CAM_Y)
		_parallax_ref_x = MID_RESPAWN_X
	else:
		player.respawn()
		camera.global_position = Vector2(CAM_MIN_X, CAM_Y)
		_parallax_ref_x = 0.0

func _execute_full_restart() -> void:
	# Player died at/near the exit — restart from the very beginning of the level.
	for rock in rocks.get_children():
		rock.queue_free()
	_clear_rock_holes()
	_rock_timer = 0.0
	_next_rock_time = randf_range(ROCK_INTERVAL_MIN, ROCK_INTERVAL_MAX)
	_rock_pause = 0.0
	_rocks_active = false

	# Dismiss the exit-reached banner and hint label
	if is_instance_valid(_exit_overlay_cl):
		_exit_overlay_cl.queue_free()
		_exit_overlay_cl = null
	if is_instance_valid(_button_hint_cl):
		_button_hint_cl.queue_free()
		_button_hint_cl = null

	# Reset button state so room_one.gd knows this player is no longer pressing
	if _button_pressing:
		_button_pressing = false
		button_state_changed.emit(false)
	if is_instance_valid(_button_spr):
		_button_spr.modulate = Color(0.0, 0.0, 0.0, 0.0)   # invisible on full restart
		_button_spr.scale    = Vector2(1.5, 1.5)

	# Return player to the original start position
	player.global_position = Vector2(150.0, _FLOOR_TOP - 32.0)
	player.velocity = Vector2.ZERO
	camera.global_position = Vector2(CAM_MIN_X, CAM_Y)
	_parallax_ref_x = 0.0

func _on_hazard_body_entered(body: Node) -> void:
	if body == player:
		_respawn()

# Called by a hazard rock the moment it hits the floor — catches the case where
# body_entered fires too late (after queue_free) for rocks landing on a standing player.
func rock_hit_floor(ix: float) -> void:
	if abs(player.global_position.x - ix) <= 44.0:
		_respawn()

func _on_exit_body_entered(body: Node) -> void:
	if body == player and not _level_complete:
		_level_complete = true
		# Snap camera so the button is immediately in frame (camera may have lagged behind)
		camera.global_position.x = clamp(float(player.global_position.x), CAM_MIN_X, CAM_MAX_X)
		_show_exit_reached_overlay()
		player_reached_exit.emit()

# ── Exit visual & overlay ─────────────────────────────────────────────────────

func _setup_exit_visual() -> void:
	$Exit/ExitVisual.visible = false
	var spr := Sprite2D.new()
	spr.texture = load("res://room_one/room_one_graphics/parallax/cyberpunk-corridor.png")
	spr.region_enabled = true
	# Bottom-right panel of the 2×3 sprite sheet — neon EXIT corridor
	spr.region_rect = Rect2(144, 406, 368, 202)
	# Scale to fill most of the viewport height so it looks like a real landmark
	# (parallax bg panels are at 3.7×; 2.8× keeps it proportional)
	spr.scale = Vector2(2.8, 2.8)
	# Add to level root at world-space coords so it sits BEHIND the player (z=-1)
	# without inheriting the Exit node's z_index.
	# Bottom aligns with floor: centre y = floor_y − half_height = 619 − 283 = 336
	spr.position = Vector2(EXIT_X, 619.0 - 283.0)   # world pos (5800, 336)
	spr.z_index = -20  # same depth as back parallax layer — fully integrated in background
	add_child(spr)

func _show_exit_reached_overlay() -> void:
	var accent := Color(1.0, 0.55, 0.05) if player_is_sol else Color(0.3, 0.75, 1.0)

	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	_exit_overlay_cl = cl   # save so _execute_full_restart can dismiss it

	# CanvasLayer has no modulate — wrap in Control so we can fade
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	cl.add_child(root)

	# ── Compact banner in the upper-middle area (not stuck to the very top) ───
	# Sits at ~17 % from top (110 px) with 4 rows: title / sub / ⚠ icon / warning text
	const TOP: float    = 110.0
	const BOTTOM: float = 270.0   # 160 px tall — room for 4 rows

	var banner := ColorRect.new()
	banner.anchor_right  = 1.0
	banner.offset_top    = TOP
	banner.offset_bottom = BOTTOM
	banner.color = Color(0.0, 0.02, 0.08, 0.90)
	root.add_child(banner)

	# Accent top-border line
	var top_line := ColorRect.new()
	top_line.anchor_right  = 1.0
	top_line.offset_top    = TOP
	top_line.offset_bottom = TOP + 3.0
	top_line.color = accent
	root.add_child(top_line)

	# Accent bottom-border line
	var bot_line := ColorRect.new()
	bot_line.anchor_right  = 1.0
	bot_line.offset_top    = BOTTOM - 3.0
	bot_line.offset_bottom = BOTTOM
	bot_line.color = accent
	root.add_child(bot_line)

	# Row 1 — "EXIT REACHED"
	_banner_label(root, "EXIT REACHED", accent, 20, TOP + 10.0)

	# Row 2 — "Waiting for partner..."  (blinking)
	var sub := _banner_label(root, "Waiting for partner...",
			Color(0.72, 0.76, 0.88, 0.9), 13, TOP + 48.0)
	var blink := sub.create_tween().set_loops()
	blink.tween_property(sub, "modulate:a", 0.15, 0.65)
	blink.tween_property(sub, "modulate:a", 1.0,  0.65)

	# Row 3 — warning icon (large, stands alone so it reads bold)
	var warn_col := Color(1.0, 0.80, 0.18, 0.95)
	_banner_label(root, "⚠", warn_col, 24, TOP + 74.0)

	# Row 4 — warning text
	_banner_label(root,
			"You can still get hit by rocks or die in the pit. Stay Safe!",
			warn_col, 12, TOP + 108.0)

	# Fade the floor button in and place a hint label right beside it in screen space
	if is_instance_valid(_button_spr):
		_button_spr.create_tween().tween_property(
			_button_spr, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

		# Compute where the button sits on screen (camera is clamped at CAM_MAX_X)
		var sx: float = _button_spr.global_position.x - (camera.global_position.x - 288.0)
		var sy: float = _button_spr.global_position.y - (camera.global_position.y - 324.0)

		var hint_cl := CanvasLayer.new()
		hint_cl.layer = 8   # above world, below exit banner (10)
		add_child(hint_cl)
		_button_hint_cl = hint_cl

		var key_txt := "S  to press" if player_is_sol else "↓  to press"
		var lbl := Label.new()
		lbl.text = key_txt
		lbl.position = Vector2(sx - 32.0, sy - 130.0)  # above the astronaut's head
		lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.15, 0.95))
		lbl.add_theme_font_size_override("font_size", 12)
		hint_cl.add_child(lbl)

		# Fade hint in alongside button
		lbl.modulate.a = 0.0
		lbl.create_tween().tween_property(lbl, "modulate:a", 1.0, 0.4)

	# Fade the whole banner in
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	# Stays until room_one.gd calls hide_exit_ui() when both players arrive

func _banner_label(parent: Control, txt: String, col: Color,
		font_sz: int, top_y: float) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.anchor_right  = 1.0
	lbl.offset_top    = top_y
	lbl.offset_bottom = top_y + font_sz + 10.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", font_sz)
	parent.add_child(lbl)
	return lbl

# ── Exit button ──────────────────────────────────────────────────────────────

func _setup_button() -> void:
	_button_spr = Sprite2D.new()
	_button_spr.texture  = load("res://room_one/room_one_graphics/button.png")
	# Full texture — no region crop (confirmed that the full image loads correctly)
	_button_spr.scale    = Vector2(1.5, 1.5)
	# bottom of sprite = _FLOOR_TOP → centre = _FLOOR_TOP − half rendered height (96/2 × 1.5 = 72)
	_button_spr.position = Vector2(_BUTTON_X, _FLOOR_TOP - 72.0)
	_button_spr.modulate = Color(0.0, 0.0, 0.0, 0.0)   # transparent until exit reached
	# z=1: in front of both floor (z=-5) and player (z=0)
	_button_spr.z_index  = 1
	add_child(_button_spr)

func _update_button_state() -> void:
	var action := "sol_down" if player_is_sol else "luna_down"
	var near: bool     = abs(float(player.global_position.x) - _BUTTON_X) < 50.0 and bool(player.is_on_floor())
	var pressing: bool = near and Input.is_action_pressed(action)

	if pressing != _button_pressing:
		_button_pressing = pressing
		button_state_changed.emit(_button_pressing)

	if is_instance_valid(_button_spr):
		if pressing:
			_button_spr.modulate = Color(1.5, 1.5, 1.5, 1.0)   # overbright when active
			_button_spr.scale    = Vector2(1.5, 1.3)            # squish down when pressed
		elif near:
			_button_spr.modulate = Color(1.2, 1.2, 1.2, 1.0)   # highlight when nearby
			_button_spr.scale    = Vector2(1.5, 1.5)
		else:
			_button_spr.modulate = Color(1.0, 1.0, 1.0, 1.0)   # normal
			_button_spr.scale    = Vector2(1.5, 1.5)

func hide_exit_ui() -> void:
	# Called by room_one.gd when both players reach the exit.
	# Dismisses only the per-player banner; the hint label and button stay
	# visible so both players can still see where to stand.
	if is_instance_valid(_exit_overlay_cl):
		_exit_overlay_cl.queue_free()
		_exit_overlay_cl = null

# ── Floor management ──────────────────────────────────────────────────────────

func _build_floor_segs() -> void:
	var defs = [
		["Floor1", 0.0,    3100.0],
		["Floor2", 3220.0, 3780.0],
		["Floor3", 3910.0, 4550.0],
		["Floor4", 4690.0, 5900.0],
	]
	for d in defs:
		var body: StaticBody2D = $Floors.get_node(d[0])
		var shape: CollisionShape2D = body.get_node("CollisionShape2D")
		_floor_segs.append({"x1": d[1], "x2": d[2], "body": body, "shape": shape})

func _fill_static_gaps() -> void:
	for c in $GapMarkers.get_children():
		c.visible = false

	for gap in _GAPS:
		var gx1: float = gap[0]
		var gx2: float = gap[1]
		var sb = StaticBody2D.new()
		$Floors.add_child(sb)

		var cs = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(gx2 - gx1, 30.0)
		cs.shape = rect
		cs.position = Vector2((gx1 + gx2) * 0.5, 636.0)
		sb.add_child(cs)

		var vis = Polygon2D.new()
		vis.polygon = PackedVector2Array([
			Vector2(gx1, _FLOOR_TOP), Vector2(gx2, _FLOOR_TOP),
			Vector2(gx2, 760.0), Vector2(gx1, 760.0),
		])
		vis.color = Color("#0E121E")
		vis.z_index = -5
		sb.add_child(vis)

		# Tile the floor texture over the gap fill so it matches the main floor
		var tile_spr = _make_floor_tile_sprite(gx1, gx2)
		add_child(tile_spr)   # level-node child, lifecycle managed via _floor_tile_sprites
		_floor_tile_sprites.append({"x1": gx1, "x2": gx2, "node": tile_spr})

		_floor_segs.append({"x1": gx1, "x2": gx2, "body": sb, "shape": cs})

# ── Dynamic rock impact holes ─────────────────────────────────────────────────

func create_rock_hole(ix: float, sprite_col: int = 0) -> void:
	_punch_floor_at(ix)
	_punch_tile_at(ix)
	_add_impact_visuals(ix, sprite_col)
	_check_floor_clearance()

func _check_floor_clearance() -> void:
	# Sum up all walkable floor visible in the current camera view.
	# If it drops below 200 px the player has no room to move — clear all holes.
	var view_left  := camera.global_position.x - 288.0
	var view_right := camera.global_position.x + 288.0
	var walkable := 0.0
	for seg in _floor_segs:
		var ol: float = max(float(seg.x1), view_left)
		var or_: float = min(float(seg.x2), view_right)
		if or_ > ol:
			walkable += or_ - ol
	if walkable < 200.0:
		_clear_rock_holes()

func _punch_floor_at(ix: float) -> void:
	for i in range(_floor_segs.size()):
		var seg = _floor_segs[i]
		if ix > seg.x1 + HOLE_RADIUS and ix < seg.x2 - HOLE_RADIUS:
			_floor_segs.remove_at(i)
			_split_seg(seg, ix)
			return

func _punch_tile_at(ix: float) -> void:
	for i in range(_floor_tile_sprites.size()):
		var entry = _floor_tile_sprites[i]
		if ix > entry.x1 and ix < entry.x2:
			_floor_tile_sprites.remove_at(i)
			# If it's a fresh original, record its range for recreation on clear.
			if not _hole_visuals.has(entry.node):
				_hole_visuals.append(entry.node)
				_split_original_ranges.append({"x1": entry.x1, "x2": entry.x2})
			# Free the punched tile immediately so the pit shows through right away.
			if is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion():
				entry.node.queue_free()
			# Left piece — from segment start to left edge of hole.
			if ix - HOLE_RADIUS > entry.x1:
				var lspr = _make_floor_tile_sprite(entry.x1, ix - HOLE_RADIUS)
				add_child(lspr)
				_floor_tile_sprites.append({"x1": entry.x1, "x2": ix - HOLE_RADIUS, "node": lspr})
				_hole_visuals.append(lspr)
			# Right piece — from right edge of hole to segment end.
			if ix + HOLE_RADIUS < entry.x2:
				var rspr = _make_floor_tile_sprite(ix + HOLE_RADIUS, entry.x2)
				add_child(rspr)
				_floor_tile_sprites.append({"x1": ix + HOLE_RADIUS, "x2": entry.x2, "node": rspr})
				_hole_visuals.append(rspr)
			return

func _split_seg(seg: Dictionary, ix: float) -> void:
	seg.shape.disabled = true

	var lcs = _add_floor_piece(seg.body, seg.x1, ix - HOLE_RADIUS)
	_floor_segs.append({"x1": seg.x1, "x2": ix - HOLE_RADIUS, "body": seg.body, "shape": lcs})

	var rcs = _add_floor_piece(seg.body, ix + HOLE_RADIUS, seg.x2)
	_floor_segs.append({"x1": ix + HOLE_RADIUS, "x2": seg.x2, "body": seg.body, "shape": rcs})

func _add_floor_piece(body: StaticBody2D, x1: float, x2: float) -> CollisionShape2D:
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(x2 - x1, 30.0)
	cs.shape = rect
	cs.position = Vector2((x1 + x2) * 0.5, 636.0)
	body.add_child(cs)
	return cs

func _add_impact_visuals(ix: float, _sprite_col: int) -> void:
	# Pit crater sprite (666×375 px source).
	# Uniform scale 0.28 → ~187 px wide, ~105 px tall.
	# Only the top ~29 px (the orange-glowing rim) is visible at floor level;
	# the rocky depth disappears below the viewport into the abyss — perfect.
	# pitt.png: 1500×375 px.  Squash vertically (y=0.12) to reduce wing height.
	# → 225×45 px.  Centre 8 px below _FLOOR_TOP so top≈604 (inside floor tile
	# band), bottom≈649 — entirely visible, wings don't bleed into the background.
	var pit := Sprite2D.new()
	pit.texture  = load("res://room_one/room_one_graphics/pit_crater.png")
	pit.scale    = Vector2(0.15, 0.12)   # 225 × 45 px
	pit.position = Vector2(ix, _FLOOR_TOP + 8.0)   # top≈604, bottom≈649
	pit.z_index  = 5   # above charges (z=0) and floor tile (z=-1)
	add_child(pit)
	_hole_visuals.append(pit)

func _add_impact_wire(wx: float, dir: float) -> void:
	var pts = PackedVector2Array([
		Vector2(wx,                _FLOOR_TOP),
		Vector2(wx + dir * 4.0,   _FLOOR_TOP + 14.0),
		Vector2(wx - dir * 3.0,   _FLOOR_TOP + 26.0),
	])
	var glow = Line2D.new()
	glow.width = 6.0
	glow.default_color = Color(0.05, 0.60, 1.0, 0.20)
	glow.z_index = 1
	glow.points = pts
	add_child(glow)
	_hole_visuals.append(glow)

	var wire = Line2D.new()
	wire.width = 2.0
	wire.default_color = Color(0.15, 0.78, 1.0, 0.92)
	wire.z_index = 2
	wire.points = pts
	add_child(wire)
	_hole_visuals.append(wire)

func _clear_rock_holes() -> void:
	# Remove any _floor_tile_sprites entries that are about to be freed.
	var hole_set: Dictionary = {}
	for n in _hole_visuals:
		hole_set[n] = true
	var kept: Array = []
	for entry in _floor_tile_sprites:
		if not hole_set.has(entry.node):
			kept.append(entry)
	_floor_tile_sprites = kept

	# Free pit sprites, split pieces, and original tiles that were punched through.
	for n in _hole_visuals:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			n.queue_free()
	_hole_visuals.clear()

	# Recreate original tile strips from stored ranges — fresh nodes, no stale refs.
	for r in _split_original_ranges:
		var spr := _make_floor_tile_sprite(r.x1, r.x2)
		add_child(spr)
		_floor_tile_sprites.append({"x1": r.x1, "x2": r.x2, "node": spr})
	_split_original_ranges.clear()

	# Synchronously restore each original floor body's collision shape
	for seg_name in ["Floor1", "Floor2", "Floor3", "Floor4"]:
		var body: StaticBody2D = $Floors.get_node(seg_name)
		var original_cs: CollisionShape2D = body.get_node("CollisionShape2D")
		original_cs.disabled = false
		for child in body.get_children():
			if child is CollisionShape2D and child != original_cs:
				body.remove_child(child)
				child.free()

	# Synchronously remove gap fill bodies added by _fill_static_gaps
	for child in $Floors.get_children():
		if child.name not in ["Floor1", "Floor2", "Floor3", "Floor4"]:
			$Floors.remove_child(child)
			child.free()

	# Rebuild floor tracking from scratch
	_floor_segs.clear()
	_build_floor_segs()
	_fill_static_gaps()

# ── Death overlay ─────────────────────────────────────────────────────────────

func _show_death_overlay() -> void:
	var accent: Color = Color(1.0, 0.55, 0.05) if player_is_sol else Color(0.3, 0.75, 1.0)

	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)

	# CanvasLayer has no modulate, so wrap everything in a Control for fading
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	cl.add_child(root)

	# Dark background
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.0, 0.0, 0.05, 0.78)
	root.add_child(bg)

	# Thin accent bar along the top
	var bar := ColorRect.new()
	bar.anchor_right = 1.0
	bar.offset_bottom = 4.0
	bar.color = accent
	root.add_child(bar)

	# ☠  skull
	_death_label(root, "☠", accent, 56, 195.0)
	# Main line
	_death_label(root, "ASTRONAUT DOWN", accent, 21, 270.0)
	# Sub line — blinking
	var sub := _death_label(root, "respawning...", Color(0.72, 0.76, 0.88, 0.9), 13, 308.0)
	var blink := sub.create_tween().set_loops()
	blink.tween_property(sub, "modulate:a", 0.15, 0.45)
	blink.tween_property(sub, "modulate:a", 1.0,  0.45)

	# Fade the Control root in (CanvasLayer itself has no modulate)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.2)

	# Self-destruct just before respawn fires
	get_tree().create_timer(1.35).timeout.connect(func():
		if is_instance_valid(cl): cl.queue_free()
	)

func _death_label(parent: Control, txt: String, col: Color,
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

# ── Floor tile visuals ────────────────────────────────────────────────────────

func _setup_floor_visuals() -> void:
	# Recolour the scene FloorVisual polygons to #10141F — this is the "abyss"
	# colour that shows below the floor tile and through pit holes.
	var abyss := Color("#0E121E")
	for floor_name in ["Floor1", "Floor2", "Floor3", "Floor4"]:
		var vis: Polygon2D = $Floors.get_node(floor_name).get_node("FloorVisual")
		vis.color   = abyss
		vis.z_index = -2   # behind tile strip (z=-1) and player (z=0)

	# Tile strips sit ABOVE _FLOOR_TOP so they're fully in the viewport.
	# The tile's bottom edge = _FLOOR_TOP (floor surface); it extends 64 px upward.
	var segs: Array = [
		[0.0,    3100.0],
		[3220.0, 3780.0],
		[3910.0, 4550.0],
		[4690.0, 5900.0],
	]
	for s in segs:
		var spr := _make_floor_tile_sprite(s[0], s[1])
		add_child(spr)
		_floor_tile_sprites.append({"x1": s[0], "x2": s[1], "node": spr})

func _make_floor_tile_sprite(x1: float, x2: float) -> Sprite2D:
	const TILE_H: float = 32.0   # exactly one tile row — no vertical repeat, single stripe
	var spr := Sprite2D.new()
	spr.texture        = load("res://room_one/room_one_graphics/floor_tile.png")
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect    = Rect2(0.0, 0.0, x2 - x1, TILE_H)
	# Bottom of sprite = _FLOOR_TOP; the stripe sits above the floor surface
	spr.position = Vector2((x1 + x2) * 0.5, _FLOOR_TOP - TILE_H * 0.5)
	spr.z_index  = -1   # above abyss polygon (z=-2), below player (z=0)
	return spr
