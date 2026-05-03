extends Control

@export var rotation_drift: float = 110.0
@export var band_scroll_speed: float = 110.0
@export var surface_top_y: float = -176.0
@export var surface_bottom_y: float = 176.0
@export var top_half_width: float = 88.0
@export var bottom_half_width: float = 356.0
@export var fall_margin: float = 46.0
@export var band_count: int = 10
@export var near_scale: float = 1.1
@export var far_scale: float = 0.7

@onready var viewport_a: SubViewport = $HBoxContainer/SubViewportContainer/SubViewport
@onready var viewport_b: SubViewport = $HBoxContainer/SubViewportContainer2/SubViewport
@onready var player_a: CharacterBody2D = $HBoxContainer/SubViewportContainer/SubViewport/PlayerA
@onready var player_b: CharacterBody2D = $HBoxContainer/SubViewportContainer/SubViewport/PlayerB
@onready var player_camera_a: Camera2D = $HBoxContainer/SubViewportContainer/SubViewport/PlayerA/Camera2D
@onready var player_camera_b: Camera2D = $HBoxContainer/SubViewportContainer/SubViewport/PlayerB/Camera2D
@onready var static_camera_a: Camera2D = $HBoxContainer/SubViewportContainer/SubViewport/StaticCameraA
@onready var static_camera_b: Camera2D = $HBoxContainer/SubViewportContainer2/SubViewport/StaticCameraB
@onready var surface_bands: Node2D = $HBoxContainer/SubViewportContainer/SubViewport/Station/SurfaceBands
@onready var spawn_a: Marker2D = $HBoxContainer/SubViewportContainer/SubViewport/Station/SpawnA
@onready var spawn_b: Marker2D = $HBoxContainer/SubViewportContainer/SubViewport/Station/SpawnB
@onready var sprite_a: Sprite2D = $HBoxContainer/SubViewportContainer/SubViewport/PlayerA/Luna
@onready var sprite_b: Sprite2D = $HBoxContainer/SubViewportContainer/SubViewport/PlayerB/Sol

var band_lines: Array[Line2D] = []
var band_positions: Array[float] = []

func _ready() -> void:
	viewport_b.world_2d = viewport_a.world_2d
	player_camera_a.enabled = false
	player_camera_b.enabled = false
	static_camera_a.enabled = true
	static_camera_b.enabled = true
	player_a.z_index = 20
	player_b.z_index = 20
	sprite_b.modulate = Color(0.9, 0.85, 1.15, 1)
	_build_surface_bands()
	_update_player_perspective(player_a, sprite_a)
	_update_player_perspective(player_b, sprite_b)

func _process(delta: float) -> void:
	_scroll_surface_bands(delta)

func _physics_process(delta: float) -> void:
	_apply_rotation(player_a, spawn_a.position, sprite_a, delta)
	_apply_rotation(player_b, spawn_b.position, sprite_b, delta)

func _build_surface_bands() -> void:
	for child in surface_bands.get_children():
		child.queue_free()

	band_lines.clear()
	band_positions.clear()

	var spacing := (bottom_half_width * 2.0) / float(max(band_count, 1))
	for index in range(band_count + 1):
		var band := Line2D.new()
		band.width = 6.0 if index % 2 == 0 else 3.0
		band.default_color = Color(0.0509804, 0.0705882, 0.109804, 0.5 if index % 2 == 0 else 0.28)
		band.antialiased = true
		surface_bands.add_child(band)

		band_lines.append(band)
		band_positions.append(-bottom_half_width + spacing * index)
		_update_band_line(band, band_positions[index])

func _scroll_surface_bands(delta: float) -> void:
	var wrap_width := bottom_half_width * 2.0

	for index in range(band_lines.size()):
		band_positions[index] += band_scroll_speed * delta
		if band_positions[index] > bottom_half_width + 60.0:
			band_positions[index] -= wrap_width + 120.0
		_update_band_line(band_lines[index], band_positions[index])

func _update_band_line(band: Line2D, x: float) -> void:
	var t := inverse_lerp(-bottom_half_width, bottom_half_width, x)
	var top_x: float = lerp(-top_half_width, top_half_width, t)
	var upper_mid_x: float = lerp(top_x, x, 0.38) + sin((t - 0.5) * PI) * 20.0
	var lower_mid_x: float = lerp(top_x, x, 0.72) + sin((t - 0.5) * PI) * 34.0
	var top_y: float = surface_top_y
	var upper_mid_y: float = lerp(surface_top_y, surface_bottom_y, 0.33)
	var lower_mid_y: float = lerp(surface_top_y, surface_bottom_y, 0.7)
	var bottom_y: float = surface_bottom_y
	band.points = PackedVector2Array([
		Vector2(top_x, top_y),
		Vector2(upper_mid_x, upper_mid_y),
		Vector2(lower_mid_x, lower_mid_y),
		Vector2(x, bottom_y)
	])

func _apply_rotation(player: CharacterBody2D, spawn_position: Vector2, sprite: Sprite2D, delta: float) -> void:
	player.position.x += rotation_drift * delta
	player.position.y = clamp(player.position.y, surface_top_y + 12.0, surface_bottom_y - 8.0)

	var half_width := _surface_half_width(player.position.y)
	if absf(player.position.x) > half_width + fall_margin:
		player.position = spawn_position
		player.velocity = Vector2.ZERO

	_update_player_perspective(player, sprite)

func _surface_half_width(y: float) -> float:
	var t := inverse_lerp(surface_top_y, surface_bottom_y, y)
	return lerp(top_half_width, bottom_half_width, t)

func _update_player_perspective(player: CharacterBody2D, sprite: Sprite2D) -> void:
	var t := inverse_lerp(surface_top_y, surface_bottom_y, player.position.y)
	var scale_value: float = lerp(far_scale, near_scale, t)
	sprite.scale = Vector2(0.03, 0.03) * scale_value
