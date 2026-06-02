extends Control

const SPACE_BACKDROP := preload("res://rooms/room_three_graphics/room3_space_backdrop.png")
const EARTH_PARALLAX := preload("res://rooms/room_three_graphics/room3_earth_parallax.png")
const HULL_PLATFORM := preload("res://rooms/room_three_graphics/room3_hull_platform.png")
const HULL_BULK := preload("res://rooms/room_three_graphics/room3_hull_bulk.png")
const HULL_STRUT := preload("res://rooms/room_three_graphics/room3_hull_strut.png")
const MAG_BLUE := preload("res://rooms/room_three_graphics/room3_mag_blue.png")
const MAG_RED := preload("res://rooms/room_three_graphics/room3_mag_red.png")
const ANCHOR_BLUE := preload("res://rooms/room_three_graphics/room3_anchor_blue.png")
const ANCHOR_RED := preload("res://rooms/room_three_graphics/room3_anchor_red.png")
const BREACH_OPEN := preload("res://rooms/room_three_graphics/room3_breach_open.png")
const BREACH_SEALED := preload("res://rooms/room_three_graphics/room3_breach_sealed.png")
const AIRLOCK_START := preload("res://rooms/room_three_graphics/room3_airlock_start.png")
const AIRLOCK_EXIT := preload("res://rooms/room_three_graphics/room3_airlock_exit.png")
const AIRLOCK_CHECKPOINT := preload("res://rooms/room_three_graphics/room3_airlock_checkpoint.png")
const WARNING_LIGHTS := preload("res://rooms/room_three_graphics/room3_warning_light_sheet.png")
const REPAIR_SPARKS := preload("res://rooms/room_three_graphics/room3_repair_spark_sheet.png")
const LUNA_SHEET := preload("res://rooms/room_three_graphics/room3_luna_eva_sheet.png")
const SOL_SHEET := preload("res://rooms/room_three_graphics/room3_sol_eva_sheet.png")

const LEVEL_WIDTH := 7600.0
const LEVEL_HEIGHT := 1120.0
const CAMERA_CENTER_Y := 600.0
const HULL_TOP_Y := -80.0
const HULL_BOTTOM_Y := 1200.0
const CHALLENGE_SECONDS := 300.0
const PLAYER_FRAME_SIZE := Vector2(64.0, 80.0)
const PLAYER_ORDER := ["luna", "sol"]
const POLARITY_BLUE := "blue"
const POLARITY_RED := "red"
const POLARITY_NEUTRAL := "neutral"
const SIDE_FLOOR := "floor"
const SIDE_CEILING := "ceiling"
const INTERACTION_NEAR_RADIUS := 170.0
const ANCHOR_ACTIVE_RADIUS := 82.0
const BREACH_ACTIVE_RADIUS := 128.0
const TRAVELLING_SPARK_HIT_RADIUS := 34.0
const TRAVELLING_SPARK_TRAVEL_SECONDS := 2.05
const TRAVELLING_SPARK_CYCLE_SECONDS := 3.15

@export var gravity: float = 1450.0
@export var walk_speed: float = 265.0
@export var air_speed: float = 225.0
@export var jump_velocity: float = 545.0
@export var max_fall_speed: float = 790.0
@export var gravity_flip_impulse: float = 270.0
@export var tether_rest_length: float = 360.0
@export var tether_max_length: float = 540.0
@export var tether_snap_length: float = 710.0
@export var tether_pull_strength: float = 560.0
@export var tether_position_correction: float = 0.18
@export var breach_seal_seconds: float = 6.2
@export var breach_decay_per_second: float = 0.18

var world: Node2D
var backdrop_sprite: Sprite2D
var earth_sprite: Sprite2D
var camera: Camera2D
var tether_line: Line2D
var static_body: StaticBody2D
var hud_layer: CanvasLayer
var timer_label: Label
var breach_label: Label
var progress_label: Label
var status_label: Label
var completion_label: Label
var anchor_prompt_label: Label
var breach_prompt_label: Label
var repair_progress_panel: Control
var repair_progress_fill: ColorRect
var repair_progress_label: Label

var players: Dictionary = {}
var platforms: Array = []
var magnetic_zones: Array = []
var breaches: Array = []
var checkpoints: Array = []
var warning_lights: Array = []
var travelling_sparks: Array = []

var current_checkpoint: int = 0
var challenge_time: float = CHALLENGE_SECONDS
var sealed_breach_count: int = 0
var completed: bool = false
var status_time: float = 0.0
var blink_time: float = 0.0
var tether_snap_flash_time: float = 0.0
var spark_hit_cooldown: float = 0.0
var room_four_transition_started: bool = false
var room_four_transition_elapsed: float = 0.0
var room_four_transition_overlay: ColorRect
var room_four_transition_label: Label

func _ready() -> void:
	FadeManager.fade_in()
	var intro = preload("res://rooms/room_three_intro.gd").new()
	add_child(intro)
	_build_level_data()
	_build_world()
	_build_hull_visuals()
	_build_collision()
	_build_airlocks()
	_build_breaches()
	_build_players()
	_build_hud()
	# Hide HUD while intro is showing; reveal it the moment intro dismisses
	hud_layer.visible = false
	intro.tree_exited.connect(func():
		if is_instance_valid(hud_layer):
			hud_layer.visible = true
	)
	_reset_to_checkpoint(0, false, "")
	_update_camera(1.0)
	_update_hud()

func _process(delta: float) -> void:
	blink_time += delta
	status_time = maxf(0.0, status_time - delta)
	tether_snap_flash_time = maxf(0.0, tether_snap_flash_time - delta)
	spark_hit_cooldown = maxf(0.0, spark_hit_cooldown - delta)
	if room_four_transition_started:
		_update_room_four_transition(delta)
	_update_warning_lights()
	_update_repair_sparks()
	_update_travelling_sparks()
	_update_tether_visual()
	_update_hud()

func _physics_process(delta: float) -> void:
	if completed:
		_update_camera(delta)
		return

	challenge_time -= delta
	if challenge_time <= 0.0:
		challenge_time = CHALLENGE_SECONDS
		_soft_reset("EVA CLOCK RESET")

	for player_id in PLAYER_ORDER:
		_apply_player_input(player_id, delta)

	_apply_tether(delta)

	for player_id in PLAYER_ORDER:
		var body: CharacterBody2D = players[player_id]["body"] as CharacterBody2D
		body.move_and_slide()
		_update_player_state_after_move(player_id, delta)

	_check_travelling_spark_hits()
	_update_breaches(delta)
	_update_checkpoints()
	_update_exit_airlock()
	_update_failures()
	_update_camera(delta)

func _build_level_data() -> void:
	var floor_y := 790.0
	var ceiling_y := 210.0
	var surface_h := 142.0
	var floor_a := Rect2(0, floor_y, 1080, surface_h)
	var floor_b := Rect2(1180, floor_y, 1000, surface_h)
	var floor_c := Rect2(2260, floor_y, 1040, surface_h)
	var floor_d := Rect2(3420, floor_y, 1060, surface_h)
	var floor_e := Rect2(4620, floor_y, 1180, surface_h)
	var floor_f := Rect2(5980, floor_y, 800, surface_h)
	var floor_g := Rect2(6940, floor_y, 660, surface_h)
	var ceiling_a := Rect2(1280, ceiling_y, 1020, surface_h)
	var ceiling_b := Rect2(2360, ceiling_y, 980, surface_h)
	var ceiling_c := Rect2(3500, ceiling_y, 980, surface_h)
	var ceiling_d := Rect2(4680, ceiling_y, 1140, surface_h)
	var ceiling_e := Rect2(5980, ceiling_y, 850, surface_h)

	platforms = [
		_surface(floor_a, SIDE_FLOOR),
		_surface(floor_b, SIDE_FLOOR),
		_surface(floor_c, SIDE_FLOOR),
		_surface(floor_d, SIDE_FLOOR),
		_surface(floor_e, SIDE_FLOOR),
		_surface(floor_f, SIDE_FLOOR),
		_surface(floor_g, SIDE_FLOOR),
		_surface(ceiling_a, SIDE_CEILING),
		_surface(ceiling_b, SIDE_CEILING),
		_surface(ceiling_c, SIDE_CEILING),
		_surface(ceiling_d, SIDE_CEILING),
		_surface(ceiling_e, SIDE_CEILING),
	]

	magnetic_zones = [
		_magnetic_segment(floor_b, 1310.0, 100.0, POLARITY_BLUE, SIDE_FLOOR),
		_magnetic_segment(floor_b, 1780.0, 280.0, POLARITY_RED, SIDE_FLOOR),
		_magnetic_segment(ceiling_a, 1340.0, 390.0, POLARITY_BLUE, SIDE_CEILING),
		_magnetic_segment(floor_c, 2320.0, 220.0, POLARITY_BLUE, SIDE_FLOOR),
		_magnetic_segment(floor_c, 2580.0, 180.0, POLARITY_RED, SIDE_FLOOR),
		_magnetic_segment(floor_c, 3020.0, 210.0, POLARITY_BLUE, SIDE_FLOOR),
		_magnetic_segment(ceiling_b, 2580.0, 380.0, POLARITY_RED, SIDE_CEILING),
		_magnetic_segment(floor_d, 3540.0, 260.0, POLARITY_BLUE, SIDE_FLOOR),
		_magnetic_segment(floor_d, 3980.0, 250.0, POLARITY_RED, SIDE_FLOOR),
		_magnetic_segment(ceiling_c, 3760.0, 320.0, POLARITY_BLUE, SIDE_CEILING),
		_magnetic_segment(floor_e, 4860.0, 190.0, POLARITY_BLUE, SIDE_FLOOR),
		_magnetic_segment(floor_e, 5320.0, 310.0, POLARITY_RED, SIDE_FLOOR),
		_magnetic_segment(ceiling_d, 5020.0, 390.0, POLARITY_BLUE, SIDE_CEILING),
		_magnetic_segment(floor_f, 6080.0, 250.0, POLARITY_BLUE, SIDE_FLOOR),
		_magnetic_segment(floor_f, 6460.0, 180.0, POLARITY_RED, SIDE_FLOOR),
		_magnetic_segment(ceiling_e, 6160.0, 330.0, POLARITY_RED, SIDE_CEILING),
		_magnetic_segment(floor_g, 7080.0, 210.0, POLARITY_BLUE, SIDE_FLOOR),
		_magnetic_segment(floor_g, 7340.0, 210.0, POLARITY_RED, SIDE_FLOOR),
	]

	breaches = [
		{
			"name": "Breach 1",
			"position": Vector2(1900, 655),
			"anchor_position": _surface_body_position(ceiling_a, SIDE_CEILING, 1640.0),
			"anchor_side": SIDE_CEILING,
			"anchor_player": "luna",
			"anchor_polarity": POLARITY_BLUE,
			"sealer_player": "sol",
			"checkpoint_index": 1,
			"progress": 0.0,
			"sealed": false,
		},
		{
			"name": "Breach 2",
			"position": Vector2(3060, 655),
			"anchor_position": _surface_body_position(ceiling_b, SIDE_CEILING, 2760.0),
			"anchor_side": SIDE_CEILING,
			"anchor_player": "sol",
			"anchor_polarity": POLARITY_RED,
			"sealer_player": "luna",
			"checkpoint_index": 2,
			"progress": 0.0,
			"sealed": false,
		},
		{
			"name": "Breach 3",
			"position": Vector2(5480, 655),
			"anchor_position": _surface_body_position(ceiling_d, SIDE_CEILING, 5230.0),
			"anchor_side": SIDE_CEILING,
			"anchor_player": "luna",
			"anchor_polarity": POLARITY_BLUE,
			"sealer_player": "sol",
			"checkpoint_index": 3,
			"progress": 0.0,
			"sealed": false,
		},
	]

	checkpoints = [
		{
			"name": "Start Airlock",
			"trigger": Rect2(0, 650, 880, 330),
			"luna": _surface_body_position(floor_a, SIDE_FLOOR, 170.0),
			"sol": _surface_body_position(floor_a, SIDE_FLOOR, 700.0),
			"luna_gravity": 1,
			"sol_gravity": 1,
			"airlock_position": Vector2(230, 690),
			"texture": AIRLOCK_START,
		},
		{
			"name": "Breach 1 Checkpoint",
			"trigger": Rect2(2220, 620, 650, 360),
			"luna": _surface_body_position(floor_c, SIDE_FLOOR, 2365.0),
			"sol": _surface_body_position(floor_c, SIDE_FLOOR, 2665.0),
			"luna_gravity": 1,
			"sol_gravity": 1,
			"airlock_position": Vector2(2440, 690),
			"texture": AIRLOCK_CHECKPOINT,
		},
		{
			"name": "Breach 2 Checkpoint",
			"trigger": Rect2(3380, 620, 780, 360),
			"luna": _surface_body_position(floor_d, SIDE_FLOOR, 3600.0),
			"sol": _surface_body_position(floor_d, SIDE_FLOOR, 4100.0),
			"luna_gravity": 1,
			"sol_gravity": 1,
			"airlock_position": Vector2(3680, 690),
			"texture": AIRLOCK_CHECKPOINT,
		},
		{
			"name": "Breach 3 Checkpoint",
			"trigger": Rect2(5940, 620, 760, 360),
			"luna": _surface_body_position(floor_f, SIDE_FLOOR, 6160.0),
			"sol": _surface_body_position(floor_f, SIDE_FLOOR, 6560.0),
			"luna_gravity": 1,
			"sol_gravity": 1,
			"airlock_position": Vector2(6200, 690),
			"texture": AIRLOCK_CHECKPOINT,
		},
	]

func _surface(surface_rect: Rect2, surface_side: String) -> Dictionary:
	return {
		"rect": surface_rect,
		"side": surface_side,
	}

func _magnetic_segment(surface_rect: Rect2, segment_x: float, segment_width: float, segment_polarity: String, surface_side: String) -> Dictionary:
	var visual_y := surface_rect.position.y - 10.0
	var probe_y := surface_rect.position.y - 38.0
	if surface_side == SIDE_CEILING:
		visual_y = surface_rect.position.y + surface_rect.size.y - 18.0
		probe_y = surface_rect.position.y + surface_rect.size.y - 38.0

	return {
		"rect": Rect2(segment_x, probe_y, segment_width, 76.0),
		"visual_rect": Rect2(segment_x, visual_y, segment_width, 28.0),
		"polarity": segment_polarity,
		"side": surface_side,
	}

func _surface_body_position(surface_rect: Rect2, surface_side: String, body_x: float) -> Vector2:
	if surface_side == SIDE_CEILING:
		return Vector2(body_x, surface_rect.position.y + surface_rect.size.y + 31.0)
	return Vector2(body_x, surface_rect.position.y - 31.0)

func _attachment_rect(surface: Dictionary) -> Rect2:
	var surface_rect: Rect2 = surface["rect"] as Rect2
	var surface_side := str(surface["side"])
	if surface_side == SIDE_CEILING:
		return Rect2(surface_rect.position.x, surface_rect.position.y + surface_rect.size.y - 38.0, surface_rect.size.x, 76.0)
	return Rect2(surface_rect.position.x, surface_rect.position.y - 38.0, surface_rect.size.x, 76.0)

func _build_world() -> void:
	world = Node2D.new()
	world.name = "EVACooperativeHull"
	add_child(world)

	backdrop_sprite = Sprite2D.new()
	backdrop_sprite.name = "ColorfulDeadSpaceBackdrop"
	backdrop_sprite.texture = SPACE_BACKDROP
	backdrop_sprite.centered = false
	backdrop_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop_sprite.position = Vector2(-1800, -340)
	backdrop_sprite.z_index = -120
	world.add_child(backdrop_sprite)

	earth_sprite = Sprite2D.new()
	earth_sprite.name = "EarthParallaxMidRun"
	earth_sprite.texture = EARTH_PARALLAX
	earth_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	earth_sprite.scale = Vector2(0.78, 0.78)
	earth_sprite.z_index = -110
	world.add_child(earth_sprite)

	tether_line = Line2D.new()
	tether_line.name = "SoftPhysicsTether"
	tether_line.width = 4.0
	tether_line.antialiased = false
	tether_line.default_color = Color(0.52, 0.85, 1.0, 0.82)
	tether_line.z_index = 45
	world.add_child(tether_line)

	camera = Camera2D.new()
	camera.name = "EVACamera"
	camera.limit_left = 0
	camera.limit_top = -160
	camera.limit_right = int(LEVEL_WIDTH)
	camera.limit_bottom = 1260
	camera.zoom = Vector2(1.0, 1.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.5
	camera.position = Vector2(480, CAMERA_CENTER_Y)
	world.add_child(camera)
	camera.make_current()

func _build_hull_visuals() -> void:
	for surface in platforms:
		_add_surface_visual(surface)

	for zone in magnetic_zones:
		_add_magnetic_strip_visual(zone)

	var struts := [
		Rect2(1040, 892, 160, 120), Rect2(2180, 892, 110, 120), Rect2(3300, 892, 150, 120),
		Rect2(4480, 892, 170, 120), Rect2(5800, 892, 210, 120), Rect2(6780, 892, 190, 120),
		Rect2(2280, 150, 120, 112), Rect2(3340, 150, 160, 112), Rect2(4480, 150, 210, 112),
		Rect2(5820, 150, 170, 112)
	]
	for strut_rect in struts:
		_add_tiled_sprite(HULL_STRUT, strut_rect, -26, "DamagedHullStrut", false)

func _add_surface_visual(surface: Dictionary) -> void:
	var surface_rect: Rect2 = surface["rect"] as Rect2
	var surface_side := str(surface["side"])
	var flip_tile := surface_side == SIDE_CEILING
	var bulk_rect := Rect2(surface_rect.position.x, surface_rect.position.y + surface_rect.size.y - 8.0, surface_rect.size.x, HULL_BOTTOM_Y - surface_rect.position.y - surface_rect.size.y + 8.0)
	if surface_side == SIDE_CEILING:
		bulk_rect = Rect2(surface_rect.position.x, HULL_TOP_Y, surface_rect.size.x, surface_rect.position.y - HULL_TOP_Y + 8.0)

	_add_tiled_sprite(HULL_BULK, bulk_rect, -34, "SolidDamagedHullMass", flip_tile)
	_add_tiled_sprite(HULL_PLATFORM, surface_rect, -12, "DamagedHullSurface", flip_tile)

func _add_magnetic_strip_visual(zone: Dictionary) -> void:
	var strip_texture: Texture2D = MAG_BLUE if str(zone["polarity"]) == POLARITY_BLUE else MAG_RED
	var strip_rect: Rect2 = zone["visual_rect"] as Rect2
	_add_tiled_sprite(strip_texture, strip_rect, 3, "EmbeddedMagneticStrip", false)

func _build_collision() -> void:
	static_body = StaticBody2D.new()
	static_body.name = "RoomThreeHullCollision"
	world.add_child(static_body)

	for index in range(platforms.size()):
		var surface: Dictionary = platforms[index]
		var surface_rect: Rect2 = surface["rect"] as Rect2
		var shape := RectangleShape2D.new()
		shape.size = surface_rect.size
		var collision := CollisionShape2D.new()
		collision.name = "HullCollision%d" % index
		collision.shape = shape
		collision.position = surface_rect.position + surface_rect.size * 0.5
		static_body.add_child(collision)

func _build_airlocks() -> void:
	_add_airlock_sprite(AIRLOCK_START, Vector2(235, 690), -6, "StartAirlock")
	_add_airlock_sprite(AIRLOCK_CHECKPOINT, Vector2(2440, 690), -6, "CheckpointAirlockA")
	_add_airlock_sprite(AIRLOCK_CHECKPOINT, Vector2(3680, 690), -6, "CheckpointAirlockB")
	_add_airlock_sprite(AIRLOCK_CHECKPOINT, Vector2(6200, 690), -6, "CheckpointAirlockC")
	_add_airlock_sprite(AIRLOCK_EXIT, Vector2(7240, 690), -6, "FarEndExitAirlock")

func _build_breaches() -> void:
	for index in range(breaches.size()):
		var breach: Dictionary = breaches[index]
		var anchor_polarity := str(breach["anchor_polarity"])
		var anchor_side := str(breach["anchor_side"])
		var anchor_position: Vector2 = breach["anchor_position"] as Vector2
		var anchor_texture: Texture2D = ANCHOR_BLUE if anchor_polarity == POLARITY_BLUE else ANCHOR_RED
		var anchor := Sprite2D.new()
		anchor.name = "%s Anchor" % str(breach["name"])
		anchor.texture = anchor_texture
		anchor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anchor.position = anchor_position + (Vector2(0.0, 46.0) if anchor_side == SIDE_CEILING else Vector2(0.0, -46.0))
		anchor.flip_v = anchor_side == SIDE_CEILING
		anchor.z_index = 8
		world.add_child(anchor)
		breach["anchor_sprite"] = anchor

		var breach_sprite := Sprite2D.new()
		breach_sprite.name = str(breach["name"])
		breach_sprite.texture = BREACH_OPEN
		breach_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		breach_sprite.position = breach["position"] as Vector2
		breach_sprite.z_index = 10
		world.add_child(breach_sprite)
		breach["sprite"] = breach_sprite

		var breach_position: Vector2 = breach["position"] as Vector2
		_add_warning_light(breach_position + Vector2(-96.0, -62.0))
		_add_warning_light(breach_position + Vector2(96.0, -58.0))

		var spark := Sprite2D.new()
		spark.name = "%s RepairSparks" % str(breach["name"])
		spark.texture = REPAIR_SPARKS
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spark.region_enabled = true
		spark.region_rect = Rect2(0, 0, 32, 32)
		spark.position = breach_position + Vector2(50.0, 10.0)
		spark.z_index = 22
		spark.visible = false
		world.add_child(spark)
		breach["spark"] = spark
		breaches[index] = breach

		if index > 0:
			_add_travelling_spark(index, breach)

func _build_players() -> void:
	players["luna"] = _create_player("Luna", LUNA_SHEET, POLARITY_BLUE, {
		"left": "luna_left",
		"right": "luna_right",
		"up": "luna_up",
		"down": "luna_down",
		"flip": "luna_gravity_flip",
		"repair": "luna_repair",
	})
	players["sol"] = _create_player("Sol", SOL_SHEET, POLARITY_RED, {
		"left": "sol_left",
		"right": "sol_right",
		"up": "sol_up",
		"down": "sol_down",
		"flip": "sol_gravity_flip",
		"repair": "sol_repair",
	})

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "RoomThreeHUD"
	add_child(hud_layer)

	var top_bar := ColorRect.new()
	top_bar.name = "HudTopBar"
	top_bar.color = Color(0.02, 0.03, 0.05, 0.76)
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 0.0
	top_bar.offset_top = 0.0
	top_bar.offset_right = 0.0
	top_bar.offset_bottom = 48.0
	hud_layer.add_child(top_bar)

	timer_label = _make_label("EVA 05:00", Vector2(18, 10), Vector2(160, 28), Color(0.72, 0.92, 1.0))
	hud_layer.add_child(timer_label)
	breach_label = _make_label("BREACHES 0/3", Vector2(190, 10), Vector2(170, 28), Color(1.0, 0.75, 0.45))
	hud_layer.add_child(breach_label)
	progress_label = _make_label("B1 00  B2 00  B3 00", Vector2(365, 10), Vector2(230, 28), Color(0.82, 0.96, 1.0))
	hud_layer.add_child(progress_label)
	status_label = _make_label("", Vector2(620, 10), Vector2(380, 28), Color(0.9, 1.0, 0.86))
	hud_layer.add_child(status_label)

	completion_label = _make_label("", Vector2(0, 260), Vector2(960, 70), Color(0.78, 1.0, 0.9))
	completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_label.add_theme_font_size_override("font_size", 26)
	completion_label.visible = false
	hud_layer.add_child(completion_label)

	_build_interaction_hud()

func _build_interaction_hud() -> void:
	anchor_prompt_label = _make_label("", Vector2.ZERO, Vector2(260, 34), Color(0.56, 0.86, 1.0))
	anchor_prompt_label.name = "AnchorPrompt"
	anchor_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	anchor_prompt_label.add_theme_font_size_override("font_size", 16)
	anchor_prompt_label.visible = false
	hud_layer.add_child(anchor_prompt_label)

	breach_prompt_label = _make_label("", Vector2.ZERO, Vector2(300, 34), Color(1.0, 0.86, 0.58))
	breach_prompt_label.name = "BreachPrompt"
	breach_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breach_prompt_label.add_theme_font_size_override("font_size", 16)
	breach_prompt_label.visible = false
	hud_layer.add_child(breach_prompt_label)

	repair_progress_panel = Control.new()
	repair_progress_panel.name = "RepairProgressPrompt"
	repair_progress_panel.size = Vector2(210, 34)
	repair_progress_panel.visible = false
	hud_layer.add_child(repair_progress_panel)

	var progress_back := ColorRect.new()
	progress_back.name = "RepairProgressBack"
	progress_back.position = Vector2(0, 18)
	progress_back.size = Vector2(210, 10)
	progress_back.color = Color(0.01, 0.015, 0.024, 0.86)
	repair_progress_panel.add_child(progress_back)

	repair_progress_fill = ColorRect.new()
	repair_progress_fill.name = "RepairProgressFill"
	repair_progress_fill.position = progress_back.position
	repair_progress_fill.size = Vector2(0, progress_back.size.y)
	repair_progress_fill.color = Color(0.36, 0.92, 1.0, 0.95)
	repair_progress_panel.add_child(repair_progress_fill)

	repair_progress_label = _make_label("", Vector2(0, -4), Vector2(210, 20), Color(0.86, 1.0, 1.0))
	repair_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	repair_progress_label.add_theme_font_size_override("font_size", 14)
	repair_progress_panel.add_child(repair_progress_label)

func _create_player(display_name: String, sheet: Texture2D, player_polarity: String, controls: Dictionary) -> Dictionary:
	var body := CharacterBody2D.new()
	body.name = display_name
	body.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	body.floor_snap_length = 14.0
	body.floor_max_angle = deg_to_rad(62.0)
	body.collision_layer = 1
	body.collision_mask = 1
	body.z_index = 40
	world.add_child(body)

	var shape := CapsuleShape2D.new()
	shape.radius = 13.0
	shape.height = 58.0
	var collision := CollisionShape2D.new()
	collision.name = "EVACollision"
	collision.shape = shape
	collision.position = Vector2(0, -2)
	body.add_child(collision)

	var sprite := Sprite2D.new()
	sprite.name = "%sEVASprite" % display_name
	sprite.texture = sheet
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, PLAYER_FRAME_SIZE.x, PLAYER_FRAME_SIZE.y)
	sprite.position = Vector2(0, -12)
	sprite.scale = Vector2(1.05, 1.05)
	body.add_child(sprite)

	var polarity_light := PointLight2D.new()
	polarity_light.name = "PolarityGlow"
	polarity_light.energy = 0.82
	polarity_light.texture_scale = 0.9
	polarity_light.color = Color(0.25, 0.75, 1.0, 1.0) if player_polarity == POLARITY_BLUE else Color(1.0, 0.28, 0.16, 1.0)
	body.add_child(polarity_light)

	return {
		"body": body,
		"sprite": sprite,
		"polarity": player_polarity,
		"controls": controls,
		"gravity_dir": 1,
		"facing": 1.0,
		"anim_time": 0.0,
		"repairing": false,
		"holding_down": false,
		"zone_polarity": POLARITY_NEUTRAL,
	}

func _apply_player_input(player_id: String, delta: float) -> void:
	var state: Dictionary = players[player_id]
	var body: CharacterBody2D = state["body"] as CharacterBody2D
	var controls: Dictionary = state["controls"]
	var gravity_dir := int(state["gravity_dir"])
	body.up_direction = Vector2(0.0, -float(gravity_dir))

	var input_x: float = Input.get_action_strength(str(controls["right"])) - Input.get_action_strength(str(controls["left"]))
	var repair_held := Input.is_action_pressed(str(controls["repair"]))
	var flip_requested := Input.is_action_just_pressed(str(controls["flip"]))
	state["holding_down"] = repair_held

	if flip_requested:
		gravity_dir *= -1
		state["gravity_dir"] = gravity_dir
		body.up_direction = Vector2(0.0, -float(gravity_dir))
		body.velocity.y = float(gravity_dir) * gravity_flip_impulse
		_set_status("%s GRAVITY FLIP" % player_id.to_upper(), 0.8)

	var zone_polarity: String = _zone_polarity_at(_attachment_probe_point(body, gravity_dir))
	var player_polarity: String = str(state["polarity"])
	var matching_zone: bool = zone_polarity == player_polarity
	state["zone_polarity"] = zone_polarity

	var on_surface := body.is_on_floor()
	var current_walk_speed := walk_speed
	var acceleration := 1780.0
	var friction := 1650.0

	if not on_surface:
		current_walk_speed = air_speed
		acceleration = 960.0
	elif matching_zone:
		current_walk_speed = walk_speed * 1.08
		acceleration = 2450.0
		friction = 2900.0

	var target_speed := input_x * current_walk_speed
	if absf(input_x) > 0.01:
		body.velocity.x = move_toward(body.velocity.x, target_speed, acceleration * delta)
		state["facing"] = _direction_sign(input_x)
	elif on_surface:
		body.velocity.x = move_toward(body.velocity.x, 0.0, friction * delta)

	if on_surface and Input.is_action_just_pressed(str(controls["up"])):
		body.velocity.y = -float(gravity_dir) * jump_velocity
	else:
		body.velocity.y = clampf(body.velocity.y + gravity * float(gravity_dir) * delta, -max_fall_speed, max_fall_speed)

	players[player_id] = state

func _apply_tether(delta: float) -> void:
	var luna_body: CharacterBody2D = players["luna"]["body"] as CharacterBody2D
	var sol_body: CharacterBody2D = players["sol"]["body"] as CharacterBody2D
	var delta_position := sol_body.global_position - luna_body.global_position
	var distance := delta_position.length()
	if distance <= 0.01:
		return

	var direction := delta_position / distance
	if distance > tether_rest_length:
		var stretch := distance - tether_rest_length
		var stretch_ratio := clampf(stretch / (tether_max_length - tether_rest_length), 0.0, 1.65)
		var pull := direction * tether_pull_strength * stretch_ratio * delta
		luna_body.velocity += pull
		sol_body.velocity -= pull

	if distance > tether_max_length:
		var correction := direction * (distance - tether_max_length) * tether_position_correction
		luna_body.global_position += correction
		sol_body.global_position -= correction
		luna_body.velocity += correction * 7.0
		sol_body.velocity -= correction * 7.0

func _update_player_state_after_move(player_id: String, delta: float) -> void:
	var state: Dictionary = players[player_id]
	var body: CharacterBody2D = state["body"] as CharacterBody2D
	var sprite: Sprite2D = state["sprite"] as Sprite2D
	var gravity_dir := int(state["gravity_dir"])
	var zone_polarity := _zone_polarity_at(_attachment_probe_point(body, gravity_dir))
	state["zone_polarity"] = zone_polarity

	if body.is_on_floor() and _is_wrong_polarity(zone_polarity, str(state["polarity"])):
		_soft_reset("%s LOST MAG LOCK" % player_id.to_upper())
		return

	var frame := 0
	state["anim_time"] = float(state["anim_time"]) + delta

	if _is_player_repairing(player_id):
		frame = 4
		state["repairing"] = true
	elif not body.is_on_floor():
		frame = 3
		state["repairing"] = false
	elif absf(body.velocity.x) > 18.0:
		frame = 1 + int(float(state["anim_time"]) * 8.0) % 2
		state["repairing"] = false
	else:
		frame = 0
		state["repairing"] = false

	sprite.region_rect = Rect2(frame * PLAYER_FRAME_SIZE.x, 0, PLAYER_FRAME_SIZE.x, PLAYER_FRAME_SIZE.y)
	sprite.flip_h = float(state["facing"]) < 0.0
	sprite.flip_v = gravity_dir < 0
	sprite.position = Vector2(0, 12) if gravity_dir < 0 else Vector2(0, -12)
	players[player_id] = state

func _update_breaches(delta: float) -> void:
	sealed_breach_count = 0

	for index in range(breaches.size()):
		var breach: Dictionary = breaches[index]
		if bool(breach["sealed"]):
			sealed_breach_count += 1
			continue

		var anchor_player: Dictionary = players[str(breach["anchor_player"])]
		var sealer_player: Dictionary = players[str(breach["sealer_player"])]
		var anchor_body: CharacterBody2D = anchor_player["body"] as CharacterBody2D
		var sealer_body: CharacterBody2D = sealer_player["body"] as CharacterBody2D
		var breach_position: Vector2 = breach["position"] as Vector2
		var anchor_position: Vector2 = breach["anchor_position"] as Vector2
		var anchored: bool = anchor_body.global_position.distance_to(anchor_position) <= ANCHOR_ACTIVE_RADIUS
		anchored = anchored and str(anchor_player["zone_polarity"]) == str(breach["anchor_polarity"])
		var sealer_close: bool = sealer_body.global_position.distance_to(breach_position) <= BREACH_ACTIVE_RADIUS
		var sealer_holding: bool = bool(sealer_player["holding_down"])

		if anchored and sealer_close and sealer_holding:
			breach["progress"] = minf(1.0, float(breach["progress"]) + delta / breach_seal_seconds)
			_set_status("%s SEALING" % str(breach["name"]), 0.25)
		else:
			breach["progress"] = maxf(0.0, float(breach["progress"]) - breach_decay_per_second * delta)

		if float(breach["progress"]) >= 1.0:
			breach["sealed"] = true
			var sprite: Sprite2D = breach["sprite"] as Sprite2D
			sprite.texture = BREACH_SEALED
			var checkpoint_index := int(breach["checkpoint_index"])
			current_checkpoint = maxi(current_checkpoint, checkpoint_index)
			_set_status("%s SEALED - CHECKPOINT ONLINE" % str(breach["name"]), 2.0)

		breaches[index] = breach

	sealed_breach_count = 0
	for breach in breaches:
		if bool(breach["sealed"]):
			sealed_breach_count += 1

func _update_checkpoints() -> void:
	for index in range(current_checkpoint + 1, checkpoints.size()):
		var checkpoint: Dictionary = checkpoints[index]
		var trigger: Rect2 = checkpoint["trigger"] as Rect2
		var luna_body: CharacterBody2D = players["luna"]["body"] as CharacterBody2D
		var sol_body: CharacterBody2D = players["sol"]["body"] as CharacterBody2D
		if trigger.has_point(luna_body.global_position) and trigger.has_point(sol_body.global_position):
			current_checkpoint = index
			_set_status("%s ONLINE" % str(checkpoint["name"]), 2.0)

func _update_exit_airlock() -> void:
	if sealed_breach_count < 3:
		return

	var exit_rect := Rect2(6900, 650, 700, 330)
	var luna_body: CharacterBody2D = players["luna"]["body"] as CharacterBody2D
	var sol_body: CharacterBody2D = players["sol"]["body"] as CharacterBody2D
	if exit_rect.has_point(luna_body.global_position) and exit_rect.has_point(sol_body.global_position):
		completed = true
		completion_label.text = "AIRLOCK SECURED - SIGNAL RELAY ROUTE ONLINE"
		completion_label.visible = true
		_set_status("EVA COMPLETE", 3.0)
		_start_room_four_transition()

func _start_room_four_transition() -> void:
	if room_four_transition_started:
		return

	room_four_transition_started = true
	room_four_transition_elapsed = 0.0

	room_four_transition_overlay = ColorRect.new()
	room_four_transition_overlay.name = "SignalRelayTransition"
	room_four_transition_overlay.color = Color(0.01, 0.015, 0.026, 0.92)
	room_four_transition_overlay.anchor_right = 1.0
	room_four_transition_overlay.anchor_bottom = 1.0
	room_four_transition_overlay.offset_left = 0.0
	room_four_transition_overlay.offset_top = 0.0
	room_four_transition_overlay.offset_right = 0.0
	room_four_transition_overlay.offset_bottom = 0.0
	hud_layer.add_child(room_four_transition_overlay)

	room_four_transition_label = _make_label("", Vector2(70, 165), Vector2(820, 230), Color(0.82, 0.96, 1.0))
	room_four_transition_label.name = "SignalRelayTransitionText"
	room_four_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_four_transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_four_transition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_four_transition_label.add_theme_font_size_override("font_size", 26)
	room_four_transition_overlay.add_child(room_four_transition_label)

func _update_room_four_transition(delta: float) -> void:
	room_four_transition_elapsed += delta
	if room_four_transition_label == null:
		return

	if room_four_transition_elapsed < 2.2:
		room_four_transition_label.text = "The hull seals. The station goes quiet."
	elif room_four_transition_elapsed < 4.8:
		room_four_transition_label.text = "CASS: Signal Relay offline. Escape pod access is locked behind a crew code channel."
	else:
		room_four_transition_label.text = "Restore the relay together. Luna follows the dark corridor. Sol tunes the interference."

	if room_four_transition_elapsed >= 7.0:
		FadeManager.fade_to_scene("res://room_four/room_four.tscn")

func _update_failures() -> void:
	var luna_body: CharacterBody2D = players["luna"]["body"] as CharacterBody2D
	var sol_body: CharacterBody2D = players["sol"]["body"] as CharacterBody2D
	if luna_body.global_position.y > 1280.0 or sol_body.global_position.y > 1280.0:
		_soft_reset("CHECKPOINT RESET")
		return
	if luna_body.global_position.y < -140.0 or sol_body.global_position.y < -140.0:
		_soft_reset("CHECKPOINT RESET")
		return

	var far_apart := luna_body.global_position.distance_to(sol_body.global_position) > tether_snap_length
	if far_apart:
		tether_snap_flash_time = 0.8
		_soft_reset("TETHER SNAPPED")

func _update_camera(delta: float) -> void:
	var luna_body: CharacterBody2D = players["luna"]["body"] as CharacterBody2D
	var sol_body: CharacterBody2D = players["sol"]["body"] as CharacterBody2D
	var midpoint := (luna_body.global_position + sol_body.global_position) * 0.5
	var target := Vector2(clampf(midpoint.x, 520.0, LEVEL_WIDTH - 520.0), CAMERA_CENTER_Y)
	if delta >= 1.0:
		camera.global_position = target
	else:
		camera.global_position = camera.global_position.lerp(target, 1.0 - pow(0.001, delta))
	_update_background_parallax()

func _update_background_parallax() -> void:
	if earth_sprite == null:
		return
	earth_sprite.global_position = Vector2(2300.0 + camera.global_position.x * 0.35, 280.0)

func _update_tether_visual() -> void:
	if players.is_empty():
		return

	var luna_body: CharacterBody2D = players["luna"]["body"] as CharacterBody2D
	var sol_body: CharacterBody2D = players["sol"]["body"] as CharacterBody2D
	var start := luna_body.global_position + Vector2(0, -28)
	var finish := sol_body.global_position + Vector2(0, -28)
	var distance := start.distance_to(finish)
	var tension := clampf(inverse_lerp(tether_rest_length, tether_max_length, distance), 0.0, 1.0)
	var sag := lerpf(42.0, 7.0, tension)
	var points := PackedVector2Array()

	for step in range(10):
		var t := float(step) / 9.0
		var point := start.lerp(finish, t)
		point.y += sin(t * PI) * sag
		points.append(point)

	tether_line.points = points
	tether_line.width = lerpf(3.0, 6.0, tension)
	if tether_snap_flash_time > 0.0:
		tether_line.width = 7.0
		tether_line.default_color = Color(1.0, 0.16, 0.08, 0.96)
	else:
		tether_line.default_color = Color(0.46 + 0.34 * tension, 0.82 - 0.28 * tension, 1.0 - 0.42 * tension, 0.78 + 0.18 * tension)

func _update_warning_lights() -> void:
	var frame := int(blink_time * 8.0) % 4
	for light in warning_lights:
		light.region_rect = Rect2(frame * 48, 0, 48, 48)

func _update_repair_sparks() -> void:
	var frame := int(blink_time * 12.0) % 4
	for breach in breaches:
		var spark: Sprite2D = breach["spark"] as Sprite2D
		var active: bool = not bool(breach["sealed"]) and _is_player_repairing_breach(str(breach["sealer_player"]), breach)
		spark.visible = active
		spark.region_rect = Rect2(frame * 32, 0, 32, 32)

func _add_travelling_spark(breach_index: int, breach: Dictionary) -> void:
	var anchor_position: Vector2 = breach["anchor_position"] as Vector2
	var anchor_side := str(breach["anchor_side"])
	var lane_y := anchor_position.y + 42.0
	if anchor_side == SIDE_FLOOR:
		lane_y = anchor_position.y - 42.0

	var lane_start := Vector2(anchor_position.x - 132.0, lane_y)
	var lane_end := Vector2(anchor_position.x + 132.0, lane_y)
	if breach_index % 2 == 0:
		var temp := lane_start
		lane_start = lane_end
		lane_end = temp

	var spark := Sprite2D.new()
	spark.name = "%s TravellingSpark" % str(breach["name"])
	spark.texture = REPAIR_SPARKS
	spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spark.region_enabled = true
	spark.region_rect = Rect2(0, 0, 32, 32)
	spark.scale = Vector2(1.2, 1.2)
	spark.z_index = 35
	spark.visible = false
	world.add_child(spark)

	travelling_sparks.append({
		"sprite": spark,
		"breach_index": breach_index,
		"target_player": str(breach["anchor_player"]),
		"start": lane_start,
		"end": lane_end,
		"phase": float(breach_index) * 0.82,
		"active": false,
	})

func _update_travelling_sparks() -> void:
	var frame := int(blink_time * 14.0) % 4
	for index in range(travelling_sparks.size()):
		var spark_data: Dictionary = travelling_sparks[index]
		var spark: Sprite2D = spark_data["sprite"] as Sprite2D
		var active := _is_travelling_spark_active(spark_data)
		spark_data["active"] = active
		spark.visible = active
		spark.region_rect = Rect2(frame * 32, 0, 32, 32)
		if active:
			var cycle_time := fmod(blink_time + float(spark_data["phase"]), TRAVELLING_SPARK_CYCLE_SECONDS)
			var travel_t := clampf(cycle_time / TRAVELLING_SPARK_TRAVEL_SECONDS, 0.0, 1.0)
			var lane_start: Vector2 = spark_data["start"] as Vector2
			var lane_end: Vector2 = spark_data["end"] as Vector2
			spark.position = lane_start.lerp(lane_end, travel_t)
		travelling_sparks[index] = spark_data

func _is_travelling_spark_active(spark_data: Dictionary) -> bool:
	var breach_index := int(spark_data["breach_index"])
	if breach_index >= breaches.size():
		return false
	var breach: Dictionary = breaches[breach_index]
	if bool(breach["sealed"]):
		return false
	if breach_index > 0 and not bool(breaches[breach_index - 1]["sealed"]):
		return false
	if current_checkpoint < breach_index:
		return false
	var cycle_time := fmod(blink_time + float(spark_data["phase"]), TRAVELLING_SPARK_CYCLE_SECONDS)
	return cycle_time <= TRAVELLING_SPARK_TRAVEL_SECONDS

func _check_travelling_spark_hits() -> void:
	if spark_hit_cooldown > 0.0:
		return
	for spark_data in travelling_sparks:
		if not bool(spark_data["active"]):
			continue
		var player_id := str(spark_data["target_player"])
		if not players.has(player_id):
			continue
		var body: CharacterBody2D = players[player_id]["body"] as CharacterBody2D
		var spark: Sprite2D = spark_data["sprite"] as Sprite2D
		if body.global_position.distance_to(spark.global_position) <= TRAVELLING_SPARK_HIT_RADIUS:
			spark_hit_cooldown = 0.9
			_soft_reset("%s HIT BY ARC" % player_id.to_upper())
			return

func _update_hud() -> void:
	if timer_label == null:
		return

	var seconds_left: int = max(0, int(ceil(challenge_time)))
	var minutes: int = int(float(seconds_left) / 60.0)
	var seconds: int = seconds_left % 60
	timer_label.text = "EVA %02d:%02d" % [minutes, seconds]
	breach_label.text = "BREACHES %d/3" % sealed_breach_count

	var progress_text := ""
	for index in range(breaches.size()):
		if index > 0:
			progress_text += "  "
		progress_text += "B%d %02d" % [index + 1, int(round(float(breaches[index]["progress"]) * 100.0))]
	progress_label.text = progress_text

	if status_time <= 0.0 and not completed:
		if sealed_breach_count < 3:
			status_label.text = "GRAVITY FLIP: SOL Q/RB  LUNA L/RB"
		else:
			status_label.text = "EXIT AIRLOCK READY"

	_update_interaction_prompts()

func _update_interaction_prompts() -> void:
	if anchor_prompt_label == null or breach_prompt_label == null or repair_progress_panel == null:
		return
	if completed:
		_hide_interaction_prompts()
		return

	var breach := _closest_interaction_breach()
	if breach.is_empty():
		_hide_interaction_prompts()
		return

	var anchor_id := str(breach["anchor_player"])
	var sealer_id := str(breach["sealer_player"])
	var anchor_player: Dictionary = players[anchor_id]
	var sealer_player: Dictionary = players[sealer_id]
	var anchor_body: CharacterBody2D = anchor_player["body"] as CharacterBody2D
	var sealer_body: CharacterBody2D = sealer_player["body"] as CharacterBody2D
	var anchor_position: Vector2 = breach["anchor_position"] as Vector2
	var breach_position: Vector2 = breach["position"] as Vector2
	var anchor_distance := anchor_body.global_position.distance_to(anchor_position)
	var sealer_distance := sealer_body.global_position.distance_to(breach_position)
	var anchor_near := anchor_distance <= INTERACTION_NEAR_RADIUS
	var sealer_near := sealer_distance <= INTERACTION_NEAR_RADIUS
	var anchored := anchor_distance <= ANCHOR_ACTIVE_RADIUS and str(anchor_player["zone_polarity"]) == str(breach["anchor_polarity"])
	var sealer_close := sealer_distance <= BREACH_ACTIVE_RADIUS
	var progress := float(breach["progress"])

	anchor_prompt_label.visible = anchor_near
	if anchor_near:
		var polarity := str(breach["anchor_polarity"]).to_upper()
		if anchored:
			anchor_prompt_label.text = "%s: repair point linked" % _player_display_name(anchor_id)
		else:
			anchor_prompt_label.text = "%s: stand on %s repair point" % [_player_display_name(anchor_id), polarity]
		_place_hud_node(anchor_prompt_label, anchor_position, Vector2(0, -94))

	breach_prompt_label.visible = sealer_near
	if sealer_near:
		if sealer_close and anchored:
			breach_prompt_label.text = "%s: hold %s to seal breach" % [_player_display_name(sealer_id), _repair_control_text(sealer_id)]
		elif sealer_close:
			breach_prompt_label.text = "%s: wait for repair point link" % _player_display_name(sealer_id)
		else:
			breach_prompt_label.text = "%s: move closer to breach" % _player_display_name(sealer_id)
		_place_hud_node(breach_prompt_label, breach_position, Vector2(0, -94))

	repair_progress_panel.visible = anchor_near or sealer_near or progress > 0.01
	if repair_progress_panel.visible:
		repair_progress_label.text = "%s repair %02d%%" % [str(breach["name"]), int(round(progress * 100.0))]
		repair_progress_fill.size = Vector2(210.0 * clampf(progress, 0.0, 1.0), repair_progress_fill.size.y)
		_place_hud_node(repair_progress_panel, breach_position, Vector2(0, -52))

func _closest_interaction_breach() -> Dictionary:
	var chosen: Dictionary = {}
	var best_score := INF
	for breach in breaches:
		if bool(breach["sealed"]):
			continue
		var anchor_id := str(breach["anchor_player"])
		var sealer_id := str(breach["sealer_player"])
		var anchor_body: CharacterBody2D = players[anchor_id]["body"] as CharacterBody2D
		var sealer_body: CharacterBody2D = players[sealer_id]["body"] as CharacterBody2D
		var anchor_distance := anchor_body.global_position.distance_to(breach["anchor_position"] as Vector2)
		var sealer_distance := sealer_body.global_position.distance_to(breach["position"] as Vector2)
		var score: float = minf(anchor_distance, sealer_distance)
		if score <= INTERACTION_NEAR_RADIUS or float(breach["progress"]) > 0.01:
			if score < best_score:
				best_score = score
				chosen = breach
	return chosen

func _hide_interaction_prompts() -> void:
	anchor_prompt_label.visible = false
	breach_prompt_label.visible = false
	repair_progress_panel.visible = false

func _place_hud_node(node: Control, world_position: Vector2, offset: Vector2) -> void:
	var hud_position := _world_to_hud(world_position) - node.size * 0.5 + offset
	node.position = _clamp_hud_position(hud_position, node.size)

func _world_to_hud(world_position: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	return viewport_size * 0.5 + (world_position - camera.global_position) * camera.zoom

func _clamp_hud_position(hud_position: Vector2, hud_size: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		clampf(hud_position.x, 8.0, maxf(8.0, viewport_size.x - hud_size.x - 8.0)),
		clampf(hud_position.y, 54.0, maxf(54.0, viewport_size.y - hud_size.y - 8.0))
	)

func _player_display_name(player_id: String) -> String:
	return "LUNA" if player_id == "luna" else "SOL"

func _repair_control_text(player_id: String) -> String:
	return "Down / B" if player_id == "luna" else "S / B"

func _soft_reset(message: String) -> void:
	_reset_to_checkpoint(current_checkpoint, true, message)

func _reset_to_checkpoint(index: int, show_message: bool, message: String) -> void:
	current_checkpoint = clampi(index, 0, checkpoints.size() - 1)
	var checkpoint: Dictionary = checkpoints[current_checkpoint]

	if players.has("luna"):
		_place_player_at_checkpoint("luna", checkpoint, "luna", "luna_gravity")
	if players.has("sol"):
		_place_player_at_checkpoint("sol", checkpoint, "sol", "sol_gravity")

	if show_message:
		_set_status(message, 2.0)

func _place_player_at_checkpoint(player_id: String, checkpoint: Dictionary, position_key: String, gravity_key: String) -> void:
	var state: Dictionary = players[player_id]
	var body: CharacterBody2D = state["body"] as CharacterBody2D
	var sprite: Sprite2D = state["sprite"] as Sprite2D
	var gravity_dir := int(checkpoint[gravity_key])
	body.global_position = checkpoint[position_key] as Vector2
	body.velocity = Vector2.ZERO
	body.up_direction = Vector2(0.0, -float(gravity_dir))
	state["gravity_dir"] = gravity_dir
	state["zone_polarity"] = _zone_polarity_at(_attachment_probe_point(body, gravity_dir))
	sprite.flip_v = gravity_dir < 0
	sprite.position = Vector2(0, 12) if gravity_dir < 0 else Vector2(0, -12)
	players[player_id] = state

func _set_status(message: String, duration: float) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_time = maxf(status_time, duration)

func _is_player_repairing(player_id: String) -> bool:
	var state: Dictionary = players[player_id]
	if not bool(state["holding_down"]):
		return false
	var body: CharacterBody2D = state["body"] as CharacterBody2D
	for breach in breaches:
		if bool(breach["sealed"]):
			continue
		if str(breach["sealer_player"]) == player_id and body.global_position.distance_to(breach["position"] as Vector2) <= BREACH_ACTIVE_RADIUS:
			return true
	return false

func _is_player_repairing_breach(player_id: String, breach: Dictionary) -> bool:
	var state: Dictionary = players[player_id]
	if not bool(state["holding_down"]):
		return false
	if str(breach["sealer_player"]) != player_id:
		return false
	var body: CharacterBody2D = state["body"] as CharacterBody2D
	return body.global_position.distance_to(breach["position"] as Vector2) <= BREACH_ACTIVE_RADIUS

func _attachment_probe_point(body: CharacterBody2D, gravity_dir: int) -> Vector2:
	return body.global_position + Vector2(0.0, 31.0 * float(gravity_dir))

func _zone_polarity_at(point: Vector2) -> String:
	for zone in magnetic_zones:
		var zone_rect: Rect2 = zone["rect"] as Rect2
		if zone_rect.has_point(point):
			return str(zone["polarity"])
	return POLARITY_NEUTRAL

func _is_wrong_polarity(zone_polarity: String, player_polarity: String) -> bool:
	if zone_polarity == POLARITY_NEUTRAL:
		return false
	return zone_polarity != player_polarity

func _direction_sign(value: float) -> float:
	if value < 0.0:
		return -1.0
	if value > 0.0:
		return 1.0
	return 0.0

func _add_tiled_sprite(texture: Texture2D, rect: Rect2, draw_z_index: int, node_name: String, flip_vertical: bool) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = draw_z_index
	world.add_child(root)

	var tile_width := float(texture.get_width())
	var texture_height := float(texture.get_height())
	var x := rect.position.x
	while x < rect.position.x + rect.size.x - 0.5:
		var remaining := rect.position.x + rect.size.x - x
		var take_width := minf(tile_width, remaining)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.flip_v = flip_vertical
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, take_width, texture_height)
		sprite.position = Vector2(x, rect.position.y)
		sprite.scale = Vector2(1.0, rect.size.y / texture_height)
		root.add_child(sprite)
		x += take_width

	return root

func _add_airlock_sprite(texture: Texture2D, world_position: Vector2, draw_z_index: int, node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = world_position
	sprite.z_index = draw_z_index
	world.add_child(sprite)
	return sprite

func _add_warning_light(world_position: Vector2) -> Sprite2D:
	var light := Sprite2D.new()
	light.name = "RasterWarningLight"
	light.texture = WARNING_LIGHTS
	light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.region_enabled = true
	light.region_rect = Rect2(0, 0, 48, 48)
	light.position = world_position
	light.z_index = 25
	world.add_child(light)
	warning_lights.append(light)
	return light

func _make_label(text: String, label_position: Vector2, label_size: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = label_position
	label.size = label_size
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 18)
	return label
