extends Node2D

signal player_reached_exit
signal rocks_started

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
# Don't spawn a hazard rock once the player is within ~100 px of the exit
const ROCK_SPAWN_CUTOFF = 5700.0

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

# Each entry: {x1, x2, body: StaticBody2D, shape: CollisionShape2D}
var _floor_segs: Array = []
# Visual nodes added by _add_impact_visuals — cleared on respawn
var _hole_visuals: Array = []

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

func _process(delta: float) -> void:
	if _level_complete:
		return
	_update_camera(delta)
	_update_parallax()
	_check_halfway()
	if _rocks_active:
		_tick_rocks(delta)
		_clean_rocks()
	if player.global_position.y > DEATH_Y:
		_respawn()

func _update_camera(delta: float) -> void:
	camera.global_position.x = clamp(
		lerp(camera.global_position.x, player.global_position.x, 7.0 * delta),
		CAM_MIN_X, CAM_MAX_X
	)
	camera.global_position.y = CAM_Y

func _update_parallax() -> void:
	if player.is_on_floor():
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
	if _rocks_active:
		# Clear all in-flight rocks
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

func _on_hazard_body_entered(body: Node) -> void:
	if body == player:
		_respawn()

func _on_exit_body_entered(body: Node) -> void:
	if body == player and not _level_complete:
		_level_complete = true
		player_reached_exit.emit()

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
		vis.color = Color(0.14, 0.17, 0.24, 1.0)
		vis.z_index = -5
		sb.add_child(vis)

		_floor_segs.append({"x1": gx1, "x2": gx2, "body": sb, "shape": cs})

# ── Dynamic rock impact holes ─────────────────────────────────────────────────

func create_rock_hole(ix: float, sprite_col: int = 0) -> void:
	_punch_floor_at(ix)
	_add_impact_visuals(ix, sprite_col)

func _punch_floor_at(ix: float) -> void:
	for i in range(_floor_segs.size()):
		var seg = _floor_segs[i]
		if ix > seg.x1 + HOLE_RADIUS and ix < seg.x2 - HOLE_RADIUS:
			_floor_segs.remove_at(i)
			_split_seg(seg, ix)
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

func _add_impact_visuals(ix: float, sprite_col: int) -> void:
	# Orange heat glow ring (behind hole)
	var ring = Polygon2D.new()
	var rp = PackedVector2Array()
	for i in 12:
		var a = i * TAU / 12.0
		rp.append(Vector2(ix + cos(a) * (HOLE_RADIUS + 8.0), _FLOOR_TOP + sin(a) * 15.0))
	ring.polygon = rp
	ring.color = Color(1.0, 0.38, 0.05, 0.42)
	ring.z_index = 0
	add_child(ring)
	_hole_visuals.append(ring)

	# Dark hole ellipse on top of floor
	var hole = Polygon2D.new()
	var hp = PackedVector2Array()
	for i in 12:
		var a = i * TAU / 12.0
		hp.append(Vector2(ix + cos(a) * (HOLE_RADIUS + 2.0), _FLOOR_TOP + sin(a) * 13.0))
	hole.polygon = hp
	hole.color = Color(0.03, 0.02, 0.04, 1.0)
	hole.z_index = 1
	add_child(hole)
	_hole_visuals.append(hole)

	# Embedded rock — same sprite column as the rock that caused this hole.
	# Squished vertically so it looks half-buried in the floor.
	var rk = Sprite2D.new()
	rk.texture = load("res://room_one/room_one_graphics/rocks_sheet.png")
	rk.region_enabled = true
	rk.region_rect = Rect2(sprite_col * 85, 0, 85, 90)
	rk.scale = Vector2(0.55, 0.38)   # narrower + flatter = embedded look
	rk.position = Vector2(ix, _FLOOR_TOP - 6.0)
	rk.z_index = 2
	add_child(rk)
	_hole_visuals.append(rk)

	# Wire stubs at hole edges
	_add_impact_wire(ix - HOLE_RADIUS - 2.0, 1.0)
	_add_impact_wire(ix + HOLE_RADIUS + 2.0, -1.0)

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
	for n in _hole_visuals:
		if is_instance_valid(n):
			n.queue_free()
	_hole_visuals.clear()

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
