extends Control

const LUNA_LIGHT_SHEET := preload("res://room_four/room_four_graphics/room4_luna_light_sheet.png")
const SOL_LIGHT_SHEET := preload("res://room_four/room_four_graphics/room4_sol_light_sheet.png")
const RELAY_DOOR := preload("res://room_four/room_four_graphics/room4_relay_door.png")
const RELAY_CONSOLE := preload("res://room_four/room_four_graphics/room4_relay_console.png")
const ESCAPE_POD := preload("res://room_four/room_four_graphics/room4_escape_pod.png")
const ESCAPE_CUTSCENE := preload("res://room_four/room_four_graphics/room4_escape_cutscene.png")

const TUNE_AUDIO := preload("res://room_four/audio/room4_tune_blip.wav")
const UNLOCK_AUDIO := preload("res://room_four/audio/room4_unlock.wav")
const LIGHTS_AUDIO := preload("res://room_four/audio/room4_lights_on.wav")
const ESCAPE_AUDIO := preload("res://room_four/audio/room4_escape.wav")
const CODE_AUDIO := {
	"47": preload("res://room_four/audio/room4_voice_47.wav"),
	"29": preload("res://room_four/audio/room4_voice_29.wav"),
	"15": preload("res://room_four/audio/room4_voice_15.wav"),
	"86": preload("res://room_four/audio/room4_voice_86.wav"),
}

enum Phase { SECTION, TUNING, ENTRY, ESCAPE, ENDING }

const CODE_PAIRS := ["47", "29", "15", "86"]
const PLAYER_FRAME_SIZE := Vector2(64.0, 80.0)
const WORLD_WIDTH := 1540.0
const PLAYER_HALF_WIDTH := 18.0
const GRAVITY := 1350.0
const WALK_SPEED := 235.0
const JUMP_SPEED := -455.0
const ENTRY_SYNC_SECONDS := 3.0
const TUNING_SPEED := 0.86
const TUNING_DRIFT_SPEED := 0.075
const CAPTURE_CLARITY_THRESHOLD := 0.78
const HEADLAMP_RANGE := 330.0
const HEADLAMP_CLOSE_RADIUS := 92.0
const HEADLAMP_FULL_DISTANCE := 78.0
const HEADLAMP_EDGE_SOFTNESS := 62.0
const PLATFORM_VISIBLE_THRESHOLD := 0.035
const AMBIENT_STATIC_DB := -35.0
const TUNING_STATIC_DB := -30.0
const CLEAR_STATIC_DB := -18.0
const ENTRY_STATIC_DB := -24.0
const VOICE_DB := 8.0
const SFX_DB := 7.0
const AUDIO_DEBUG := false

var phase: int = Phase.SECTION
var section_index: int = 0
var elapsed_time: float = 0.0
var message_time: float = 0.0
var message_text: String = ""

var luna_sprite: Sprite2D
var sol_sprite: Sprite2D
var escape_pod_sprite: Sprite2D
var status_label: Label
var luna_entry_label: Label
var sol_entry_label: Label
var ending_label: Label
var static_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var luna_pos := Vector2.ZERO
var sol_pos := Vector2.ZERO
var luna_velocity := Vector2.ZERO
var sol_velocity := Vector2.ZERO
var luna_escape_pos := Vector2.ZERO
var sol_escape_pos := Vector2.ZERO
var luna_escape_velocity := Vector2.ZERO
var sol_escape_velocity := Vector2.ZERO
var luna_facing: float = 1.0
var sol_facing: float = 1.0
var luna_anim_time: float = 0.0
var sol_anim_time: float = 0.0
var luna_on_floor: bool = true
var sol_on_floor: bool = true
var luna_jump_count: int = 0
var sol_jump_count: int = 0

var luna_at_door: bool = false
var sol_at_console: bool = false
var needle_value: float = 0.08
var tuning_drift_time: float = 0.0
var pair_revealed: bool = false
var current_clear_min: float = 0.18
var current_clear_max: float = 0.30

var luna_digits := [0, 0]
var sol_digits := [0, 0]
var luna_digit_slot: int = 0
var sol_digit_slot: int = 0
var luna_submitted: bool = false
var sol_submitted: bool = false
var luna_submit_time: float = -10.0
var sol_submit_time: float = -10.0
var luna_submitted_pair: String = ""
var sol_submitted_pair: String = ""
var luna_submit_key_down: bool = false
var sol_submit_key_down: bool = false
var sol_capture_key_down: bool = false

var ending_time: float = 0.0
var audio_debug_contexts := {}
var static_noise_phase: float = 0.0

func _ready() -> void:
	FadeManager.fade_in()
	var window := get_tree().root
	window.content_scale_size = Vector2i(1152, 648)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var intro = preload("res://room_four/room_four_intro.gd").new()
	add_child(intro)
	intro.tree_exited.connect(func():
		var tree := get_tree()
		if tree == null:
			return
		var w := tree.root
		if w == null:
			return
		w.content_scale_size = Vector2i(0, 0)
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		if is_instance_valid(status_label):
			status_label.visible = true
	)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_room_audio_bus()
	_build_nodes()
	status_label.visible = false
	_reset_section(true, false)
	_set_message("Signal Relay: follow the dark corridors to recover the crew code.", 3.0)
	_start_ambient_static("ready")

func _process(delta: float) -> void:
	elapsed_time += delta
	message_time = maxf(0.0, message_time - delta)

	match phase:
		Phase.SECTION:
			_process_section(delta)
		Phase.TUNING:
			_process_tuning(delta)
		Phase.ENTRY:
			_process_entry(delta)
		Phase.ESCAPE:
			_process_escape(delta)
		Phase.ENDING:
			_process_ending(delta)

	_update_sprites(delta)
	_update_labels()
	_feed_static_audio()
	queue_redraw()

func _draw() -> void:
	var screen := _screen_size()
	if phase == Phase.ENDING:
		_draw_ending(screen)
	elif phase == Phase.ESCAPE:
		_draw_escape_bay(screen)
	else:
		_draw_split_room(screen)

func _build_nodes() -> void:
	luna_sprite = _make_sprite("LunaLightSprite", LUNA_LIGHT_SHEET)
	add_child(luna_sprite)

	sol_sprite = _make_sprite("SolLightSprite", SOL_LIGHT_SHEET)
	add_child(sol_sprite)

	escape_pod_sprite = Sprite2D.new()
	escape_pod_sprite.name = "EscapePod"
	escape_pod_sprite.texture = ESCAPE_POD
	escape_pod_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	escape_pod_sprite.visible = false
	add_child(escape_pod_sprite)

	luna_entry_label = _make_label("", 22, Color(0.98, 1.0, 0.78))
	luna_entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(luna_entry_label)

	sol_entry_label = _make_label("", 22, Color(0.78, 0.95, 1.0))
	sol_entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sol_entry_label)

	ending_label = _make_label("", 30, Color(0.9, 1.0, 0.86))
	ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(ending_label)

	# ── HUD CanvasLayer ───────────────────────────────────────────────────────
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var top_bar := ColorRect.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 32.0
	top_bar.color = Color(0.02, 0.03, 0.05, 0.76)
	hud.add_child(top_bar)

	status_label = _make_label("", 16, Color(0.82, 0.96, 1.0))
	status_label.position = Vector2(18, 7)
	status_label.size = Vector2(700, 24)
	hud.add_child(status_label)

	var hint_lbl := Label.new()
	hint_lbl.text = "TUNE FOR THE CODE — BOTH PLAYERS INPUT IT AT THE SAME TIME       +/- FOR ROOM SELECT MENU       ASSETS CREATED BY CODEX"
	hint_lbl.anchor_right = 1.0
	hint_lbl.offset_top = 7.0
	hint_lbl.offset_bottom = 27.0
	hint_lbl.offset_right = -18.0
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_lbl.add_theme_font_size_override("font_size", 16)
	hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	hint_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	hint_lbl.add_theme_constant_override("shadow_offset_x", 2)
	hint_lbl.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(hint_lbl)

	# ── Audio ─────────────────────────────────────────────────────────────────
	static_player = AudioStreamPlayer.new()
	static_player.name = "StaticPlayer"
	var static_stream := AudioStreamGenerator.new()
	static_stream.mix_rate = 44100.0
	static_stream.buffer_length = 0.25
	static_player.stream = static_stream
	static_player.bus = "Master"
	static_player.autoplay = false
	static_player.volume_db = AMBIENT_STATIC_DB
	static_player.finished.connect(_on_static_finished)
	add_child(static_player)

	voice_player = AudioStreamPlayer.new()
	voice_player.name = "CodeVoicePlayer"
	voice_player.bus = "Master"
	voice_player.volume_db = VOICE_DB
	add_child(voice_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "RoomFourSfxPlayer"
	sfx_player.bus = "Master"
	sfx_player.volume_db = SFX_DB
	add_child(sfx_player)

func _make_sprite(node_name: String, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, PLAYER_FRAME_SIZE.x, PLAYER_FRAME_SIZE.y)
	sprite.scale = Vector2(1.08, 1.08)
	return sprite

func _make_label(label_text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _process_section(delta: float) -> void:
	_start_ambient_static("section")

	if not luna_at_door:
		_apply_player_movement("luna", delta)
	else:
		luna_velocity = Vector2.ZERO

	if not sol_at_console:
		_apply_player_movement("sol", delta)
	else:
		sol_velocity = Vector2.ZERO

	if not luna_at_door and _is_at_luna_door():
		luna_at_door = true
		luna_velocity = Vector2.ZERO
		_set_message("Luna is at the relay keypad. Sol needs the console.", 2.0)

	if not sol_at_console and _is_at_sol_console():
		sol_at_console = true
		sol_velocity = Vector2.ZERO
		_set_message("Sol console linked. Tune once Luna reaches the door.", 2.0)
		_play_sfx(TUNE_AUDIO)

	if luna_at_door and sol_at_console:
		_start_tuning()
	elif message_time <= 0.0:
		_set_message("Use the helmet lights. The door and console are hidden until you are close.", 0.25)

func _process_tuning(delta: float) -> void:
	_play_static_loop("tuning")
	var input_x := 0.0
	if Input.is_action_pressed("room4_sol_tune_right"):
		input_x += 1.0
	if Input.is_action_pressed("room4_sol_tune_left"):
		input_x -= 1.0

	tuning_drift_time += delta
	var drift := sin(tuning_drift_time * 1.15 + float(section_index) * 0.9) * TUNING_DRIFT_SPEED
	drift += sin(tuning_drift_time * 0.43 + float(section_index) * 1.7) * TUNING_DRIFT_SPEED * 0.45
	needle_value = clampf(needle_value + input_x * delta * TUNING_SPEED + drift * delta, 0.0, 1.0)

	var clarity := _signal_clarity()
	static_player.volume_db = lerpf(TUNING_STATIC_DB, CLEAR_STATIC_DB, clarity)

	var capture_now := Input.is_action_pressed("room4_sol_capture")
	if capture_now and not sol_capture_key_down:
		_attempt_signal_capture()
	sol_capture_key_down = capture_now

func _process_entry(delta: float) -> void:
	_play_static_loop("entry")
	static_player.volume_db = ENTRY_STATIC_DB
	_process_digit_controls("luna")
	_process_digit_controls("sol")
	_process_submit_keys()

	if luna_submitted and not sol_submitted and elapsed_time - luna_submit_time > ENTRY_SYNC_SECONDS:
		_reset_entry_attempt("Pair reset: Sol submitted too late.")
	elif sol_submitted and not luna_submitted and elapsed_time - sol_submit_time > ENTRY_SYNC_SECONDS:
		_reset_entry_attempt("Pair reset: Luna submitted too late.")

func _process_escape(delta: float) -> void:
	_apply_escape_movement(delta)
	var pod_rect := _escape_pod_rect()
	if pod_rect.has_point(luna_escape_pos) and pod_rect.has_point(sol_escape_pos):
		_start_ending()
	elif message_time <= 0.0:
		_set_message("Lights restored. Both players move right to the escape pod.", 0.25)

func _process_ending(delta: float) -> void:
	ending_time += delta
	luna_sprite.visible = false
	sol_sprite.visible = false
	escape_pod_sprite.visible = false

func _apply_player_movement(player_id: String, delta: float) -> void:
	var is_luna := player_id == "luna"
	var pos := luna_pos if is_luna else sol_pos
	var velocity := luna_velocity if is_luna else sol_velocity
	var on_floor := luna_on_floor if is_luna else sol_on_floor
	var controls := _controls_for(player_id)
	var platforms := _platforms_for(player_id)
	var previous_pos := pos

	var input_x: float = Input.get_action_strength(str(controls["right"])) - Input.get_action_strength(str(controls["left"]))
	if absf(input_x) > 0.05:
		velocity.x = input_x * WALK_SPEED
		if is_luna:
			luna_facing = 1.0 if input_x > 0.0 else -1.0
		else:
			sol_facing = 1.0 if input_x > 0.0 else -1.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 5.0 * delta)

	if on_floor:
		velocity.y = 0.0
		if is_luna:
			luna_jump_count = 0
		else:
			sol_jump_count = 0

	var jump_count := luna_jump_count if is_luna else sol_jump_count
	if Input.is_action_just_pressed(str(controls["up"])) and jump_count < 2:
		var jump_power: float
		if jump_count == 0:
			jump_power = JUMP_SPEED
		else:
			jump_power = JUMP_SPEED * 0.6 if is_luna else JUMP_SPEED * 0.9
		velocity.y = jump_power
		on_floor = false
		if is_luna:
			luna_jump_count += 1
		else:
			sol_jump_count += 1
	elif not on_floor:
		velocity.y += GRAVITY * delta

	pos.x = clampf(pos.x + velocity.x * delta, 42.0, WORLD_WIDTH - 42.0)
	pos.y += velocity.y * delta

	var landed := false
	if velocity.y >= 0.0:
		for platform in platforms:
			var rect: Rect2 = platform
			var was_above := previous_pos.y <= rect.position.y + 2.0
			var crossed_top := pos.y >= rect.position.y
			var within_x := pos.x >= rect.position.x - PLAYER_HALF_WIDTH and pos.x <= rect.end.x + PLAYER_HALF_WIDTH
			if was_above and crossed_top and within_x:
				pos.y = rect.position.y
				velocity.y = 0.0
				landed = true
				break
	on_floor = landed

	if pos.y > _screen_size().y + 160.0:
		_reset_section_positions("Checkpoint reset: missed the platform.")
		return

	if is_luna:
		luna_pos = pos
		luna_velocity = velocity
		luna_on_floor = on_floor
	else:
		sol_pos = pos
		sol_velocity = velocity
		sol_on_floor = on_floor

func _apply_escape_movement(delta: float) -> void:
	var screen := _screen_size()
	var floor_y := _floor_y()
	var luna_input := Input.get_action_strength("luna_right") - Input.get_action_strength("luna_left")
	var sol_input := Input.get_action_strength("sol_right") - Input.get_action_strength("sol_left")

	luna_escape_velocity.x = luna_input * WALK_SPEED
	sol_escape_velocity.x = sol_input * WALK_SPEED
	if absf(luna_input) > 0.05:
		luna_facing = 1.0 if luna_input > 0.0 else -1.0
	if absf(sol_input) > 0.05:
		sol_facing = 1.0 if sol_input > 0.0 else -1.0

	if luna_escape_pos.y >= floor_y:
		luna_escape_pos.y = floor_y
		luna_escape_velocity.y = JUMP_SPEED if Input.is_action_just_pressed("luna_up") else 0.0
	else:
		luna_escape_velocity.y += GRAVITY * delta

	if sol_escape_pos.y >= floor_y:
		sol_escape_pos.y = floor_y
		sol_escape_velocity.y = JUMP_SPEED if Input.is_action_just_pressed("sol_up") else 0.0
	else:
		sol_escape_velocity.y += GRAVITY * delta

	luna_escape_pos += luna_escape_velocity * delta
	sol_escape_pos += sol_escape_velocity * delta
	luna_escape_pos.x = clampf(luna_escape_pos.x, 60.0, screen.x - 82.0)
	sol_escape_pos.x = clampf(sol_escape_pos.x, 60.0, screen.x - 82.0)
	luna_escape_pos.y = minf(luna_escape_pos.y, floor_y)
	sol_escape_pos.y = minf(sol_escape_pos.y, floor_y)

func _process_digit_controls(player_id: String) -> void:
	var controls := _entry_controls_for(player_id)
	var submitted := luna_submitted if player_id == "luna" else sol_submitted
	if submitted:
		return

	if Input.is_action_just_pressed(str(controls["left"])):
		if player_id == "luna":
			luna_digit_slot = 0
		else:
			sol_digit_slot = 0
	elif Input.is_action_just_pressed(str(controls["right"])):
		if player_id == "luna":
			luna_digit_slot = 1
		else:
			sol_digit_slot = 1

	if Input.is_action_just_pressed(str(controls["up"])):
		_change_digit(player_id, 1)
	elif Input.is_action_just_pressed(str(controls["down"])):
		_change_digit(player_id, -1)

func _process_submit_keys() -> void:
	var luna_now := Input.is_action_pressed("room4_luna_submit")
	var sol_now := Input.is_action_pressed("room4_sol_submit")
	if luna_now and not luna_submit_key_down:
		_submit_entry("luna")
	if sol_now and not sol_submit_key_down:
		_submit_entry("sol")
	luna_submit_key_down = luna_now
	sol_submit_key_down = sol_now

func _change_digit(player_id: String, amount: int) -> void:
	if player_id == "luna":
		luna_digits[luna_digit_slot] = wrapi(int(luna_digits[luna_digit_slot]) + amount, 0, 10)
	else:
		sol_digits[sol_digit_slot] = wrapi(int(sol_digits[sol_digit_slot]) + amount, 0, 10)

func _submit_entry(player_id: String) -> void:
	if phase != Phase.ENTRY:
		return

	if player_id == "luna" and not luna_submitted:
		luna_submitted = true
		luna_submit_time = elapsed_time
		luna_submitted_pair = _digits_to_pair(luna_digits)
		_set_message("Luna submitted. Sol has 3 seconds.", 2.0)
	elif player_id == "sol" and not sol_submitted:
		sol_submitted = true
		sol_submit_time = elapsed_time
		sol_submitted_pair = _digits_to_pair(sol_digits)
		_set_message("Sol submitted. Luna has 3 seconds.", 2.0)

	if luna_submitted and sol_submitted:
		_check_submitted_pairs()

func _check_submitted_pairs() -> void:
	var pair := _current_pair()
	var synced := absf(luna_submit_time - sol_submit_time) <= ENTRY_SYNC_SECONDS
	if synced and luna_submitted_pair == pair and sol_submitted_pair == pair:
		_unlock_checkpoint()
	else:
		_reset_entry_attempt("Pair reset: codes must match and sync.")

func _reset_entry_attempt(reason: String) -> void:
	luna_digits = [0, 0]
	sol_digits = [0, 0]
	luna_digit_slot = 0
	sol_digit_slot = 0
	luna_submitted = false
	sol_submitted = false
	luna_submit_time = -10.0
	sol_submit_time = -10.0
	luna_submitted_pair = ""
	sol_submitted_pair = ""
	luna_submit_key_down = Input.is_action_pressed("room4_luna_submit")
	sol_submit_key_down = Input.is_action_pressed("room4_sol_submit")
	_set_message(reason, 2.2)

func _unlock_checkpoint() -> void:
	static_player.volume_db = ENTRY_STATIC_DB
	_play_sfx(UNLOCK_AUDIO)
	if section_index >= CODE_PAIRS.size() - 1:
		_start_escape_phase()
	else:
		section_index += 1
		_reset_section(false)
		_set_message("Relay door unlocked. Next dark section online.", 2.6)

func _start_tuning() -> void:
	phase = Phase.TUNING
	pair_revealed = false
	tuning_drift_time = 0.0
	sol_capture_key_down = Input.is_action_pressed("room4_sol_capture")
	needle_value = clampf(0.08 + float(section_index) * 0.21, 0.06, 0.88)
	current_clear_min = 0.17 + float(section_index) * 0.18
	current_clear_max = current_clear_min + 0.105
	_set_message("Sol: LB/RB tunes. Press CIRCLE or A when the signal clears.", 2.2)
	_play_sfx(TUNE_AUDIO)

func _attempt_signal_capture() -> void:
	if _signal_clarity() >= CAPTURE_CLARITY_THRESHOLD:
		_reveal_pair()
	else:
		_set_message("Signal slipped. Tune again, then press CIRCLE or A when it clears.", 1.4)
		_play_sfx(TUNE_AUDIO)

func _reveal_pair() -> void:
	if pair_revealed:
		return
	pair_revealed = true
	phase = Phase.ENTRY
	_play_static_loop("reveal_pair")
	static_player.volume_db = ENTRY_STATIC_DB
	_reset_entry_attempt("Radio clear. Listen, then both players enter the two digits.")
	voice_player.stop()
	voice_player.stream = CODE_AUDIO[_current_pair()]
	voice_player.play()

func _start_escape_phase() -> void:
	phase = Phase.ESCAPE
	_stop_static()
	voice_player.stop()
	_play_sfx(LIGHTS_AUDIO)
	var screen := _screen_size()
	var floor_y := _floor_y()
	luna_escape_pos = Vector2(100.0, floor_y)
	sol_escape_pos = Vector2(165.0, floor_y)
	luna_escape_velocity = Vector2.ZERO
	sol_escape_velocity = Vector2.ZERO
	luna_sprite.visible = true
	sol_sprite.visible = true
	escape_pod_sprite.visible = true
	escape_pod_sprite.position = Vector2(screen.x - 165.0, floor_y - 44.0)
	_set_message("Lights restored. Escape pod access is open.", 4.0)

func _start_ending() -> void:
	phase = Phase.ENDING
	ending_time = 0.0
	_play_sfx(ESCAPE_AUDIO)

func _reset_section(first_reset: bool, start_audio: bool = true) -> void:
	phase = Phase.SECTION
	pair_revealed = false
	luna_at_door = false
	sol_at_console = false
	if start_audio:
		_start_ambient_static("reset_section")
	voice_player.stop()
	_reset_entry_attempt("Checkpoint %d: find the relay door and console." % (section_index + 1))
	_reset_section_positions("")
	if first_reset:
		message_text = "Signal Relay: follow the dark corridors to recover the crew code."
		message_time = 3.0

func _reset_section_positions(reason: String) -> void:
	var luna_platforms := _platforms_for("luna")
	var sol_platforms := _platforms_for("sol")
	luna_jump_count = 0
	sol_jump_count = 0
	luna_pos = Vector2(luna_platforms[0].position.x + 55.0, luna_platforms[0].position.y)
	sol_pos = Vector2(sol_platforms[0].position.x + 55.0, sol_platforms[0].position.y)
	luna_velocity = Vector2.ZERO
	sol_velocity = Vector2.ZERO
	luna_on_floor = true
	sol_on_floor = true
	luna_facing = 1.0
	sol_facing = 1.0
	if reason != "":
		_set_message(reason, 2.0)

func _update_sprites(delta: float) -> void:
	luna_anim_time += delta
	sol_anim_time += delta
	var screen := _screen_size()
	var split_x := screen.x * 0.5

	if phase == Phase.ESCAPE:
		_place_sprite(luna_sprite, luna_escape_pos, luna_escape_velocity, luna_facing, luna_anim_time)
		_place_sprite(sol_sprite, sol_escape_pos, sol_escape_velocity, sol_facing, sol_anim_time)
	elif phase == Phase.ENDING:
		luna_sprite.visible = false
		sol_sprite.visible = false
	else:
		var luna_camera := _camera_left(luna_pos.x, split_x)
		var sol_camera := _camera_left(sol_pos.x, split_x)
		_place_sprite(luna_sprite, _world_to_panel(luna_pos, 0.0, luna_camera), luna_velocity, luna_facing, luna_anim_time)
		_place_sprite(sol_sprite, _world_to_panel(sol_pos, split_x, sol_camera), sol_velocity, sol_facing, sol_anim_time)
		luna_sprite.visible = true
		sol_sprite.visible = phase == Phase.SECTION and not sol_at_console

func _place_sprite(sprite: Sprite2D, sprite_position: Vector2, velocity: Vector2, facing: float, anim_time: float) -> void:
	if not sprite.visible:
		return
	var frame := 0
	if velocity.y < -20.0:
		frame = 3
	elif absf(velocity.x) > 18.0:
		frame = 1 + int(anim_time * 8.0) % 2
	sprite.position = sprite_position + Vector2(0, -34)
	sprite.region_rect = Rect2(frame * PLAYER_FRAME_SIZE.x, 0, PLAYER_FRAME_SIZE.x, PLAYER_FRAME_SIZE.y)
	sprite.flip_h = facing < 0.0

func _update_labels() -> void:
	var screen := _screen_size()
	status_label.size = Vector2(700, 24)
	status_label.text = message_text if message_time > 0.0 else "Checkpoint %d/4" % (section_index + 1)

	luna_entry_label.visible = phase == Phase.ENTRY
	sol_entry_label.visible = phase == Phase.ENTRY
	luna_entry_label.position = Vector2(18, screen.y - 60)
	luna_entry_label.size = Vector2(screen.x * 0.5 - 36.0, 42)
	sol_entry_label.position = Vector2(screen.x * 0.5 + 18, screen.y - 60)
	sol_entry_label.size = Vector2(screen.x * 0.5 - 36.0, 42)
	luna_entry_label.text = _entry_text("LUNA", luna_digits, luna_digit_slot, luna_submitted, "ENTER/B")
	sol_entry_label.text = _entry_text("SOL", sol_digits, sol_digit_slot, sol_submitted, "F/B")

	ending_label.visible = phase == Phase.ENDING
	ending_label.position = Vector2(72, screen.y - 150)
	ending_label.size = Vector2(screen.x - 144, 110)
	if phase == Phase.ENDING:
		if ending_time < 2.4:
			ending_label.text = "Escape pod clamps released."
		elif ending_time < 5.0:
			ending_label.text = "The Meridian falls quiet behind them."
		else:
			ending_label.text = "You made it. Together."

func _entry_text(player_name: String, digits: Array, slot: int, submitted: bool, submit_key: String) -> String:
	var a := "[%d]" % int(digits[0]) if slot == 0 and not submitted else " %d " % int(digits[0])
	var b := "[%d]" % int(digits[1]) if slot == 1 and not submitted else " %d " % int(digits[1])
	var state := "LOCKED" if submitted else "SUBMIT " + submit_key
	return "%s  %s%s  %s" % [player_name, a, b, state]

func _draw_split_room(screen: Vector2) -> void:
	var split_x := screen.x * 0.5
	draw_rect(Rect2(0, 0, split_x, screen.y), Color.BLACK)
	draw_rect(Rect2(split_x, 0, split_x, screen.y), Color.BLACK)
	draw_line(Vector2(split_x, 0), Vector2(split_x, screen.y), Color(0.05, 0.2, 0.28), 3.0)

	_draw_dark_platform_panel("luna", 0.0, luna_pos, luna_facing, false)
	if sol_at_console or phase == Phase.TUNING or phase == Phase.ENTRY:
		_draw_dashboard(screen)
	else:
		_draw_dark_platform_panel("sol", split_x, sol_pos, sol_facing, true)

	if phase == Phase.ENTRY:
		_draw_luna_keypad(screen)
		_draw_sol_keypad(screen)

func _draw_dark_platform_panel(player_id: String, panel_x: float, player_pos: Vector2, facing: float, draw_console: bool) -> void:
	var screen := _screen_size()
	var split_x := screen.x * 0.5
	var camera := _camera_left(player_pos.x, split_x)
	var panel_rect := Rect2(panel_x, 0, split_x, screen.y)
	draw_rect(panel_rect, Color(0.0, 0.0, 0.0))

	var local_player := _world_to_panel(player_pos, panel_x, camera)
	_draw_headlamp(local_player, facing)

	for platform in _platforms_for(player_id):
		var rect: Rect2 = platform
		var intensity := _rect_light_intensity(rect, player_pos, facing)
		if intensity > PLATFORM_VISIBLE_THRESHOLD:
			var local_rect := Rect2(Vector2(panel_x + rect.position.x - camera, rect.position.y), rect.size)
			draw_rect(local_rect, Color(0.045 + 0.10 * intensity, 0.07 + 0.13 * intensity, 0.08 + 0.15 * intensity, 0.30 + 0.70 * intensity))
			draw_rect(Rect2(local_rect.position, Vector2(local_rect.size.x, 6)), Color(0.12 + 0.22 * intensity, 0.30 + 0.34 * intensity, 0.36 + 0.32 * intensity, 0.25 + 0.75 * intensity))
			draw_rect(local_rect, Color(0.46, 0.92, 1.0, 0.12 + 0.28 * intensity), false, 1.0)

	var target_pos := _target_position_for(player_id)
	var target_intensity := _light_intensity(target_pos, player_pos, facing)
	if target_intensity > PLATFORM_VISIBLE_THRESHOLD:
		var target_tint := Color(0.35 + 0.65 * target_intensity, 0.52 + 0.48 * target_intensity, 0.58 + 0.42 * target_intensity, 0.28 + 0.72 * target_intensity)
		if draw_console:
			var console_rect := Rect2(panel_x + target_pos.x - camera - 56.0, target_pos.y - 88.0, 112.0, 88.0)
			draw_texture_rect(RELAY_CONSOLE, console_rect, false, target_tint)
		else:
			var door_rect := Rect2(panel_x + target_pos.x - camera - 48.0, target_pos.y - 144.0, 96.0, 144.0)
			draw_texture_rect(RELAY_DOOR, door_rect, false, target_tint)

	var title := "LUNA: DARK RELAY CORRIDOR" if player_id == "luna" else "SOL: DARK CONTROL WALKWAY"
	draw_string(ThemeDB.fallback_font, Vector2(panel_x + 18, 52), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.38, 0.75, 0.86))

func _draw_headlamp(local_player: Vector2, facing: float) -> void:
	var origin := local_player + Vector2(18.0 * facing, -68.0)
	for layer in range(4, 0, -1):
		var factor := float(layer) / 4.0
		var reach := HEADLAMP_RANGE * factor
		var tip := origin + Vector2(reach * facing, reach * 0.16)
		var half_height := 42.0 + reach * 0.40
		var alpha := 0.02 + (1.0 - factor) * 0.055
		draw_polygon(PackedVector2Array([
			origin,
			tip + Vector2(0.0, -half_height),
			tip + Vector2(0.0, half_height),
		]), PackedColorArray([
			Color(1.0, 0.96, 0.62, alpha * 3.2),
			Color(0.86, 0.95, 1.0, alpha),
			Color(0.86, 0.95, 1.0, alpha),
		]))
	draw_circle(origin + Vector2(0.0, 20.0), HEADLAMP_CLOSE_RADIUS, Color(0.75, 0.9, 1.0, 0.05))
	draw_circle(origin, 24.0, Color(0.95, 1.0, 0.76, 0.22))

func _draw_dashboard(screen: Vector2) -> void:
	var split_x := screen.x * 0.5
	var rect := Rect2(split_x + 24, 70, split_x - 48, screen.y - 140)
	draw_rect(rect, Color(0.01, 0.018, 0.025))
	draw_rect(rect, Color(0.2, 0.66, 0.78, 0.78), false, 3.0)

	var static_amount := _interference_amount()
	for i in range(70):
		var y := rect.position.y + 16.0 + fmod(float(i * 31 + section_index * 19), rect.size.y - 32.0)
		var alpha := 0.05 + static_amount * (0.05 + float(i % 5) * 0.018)
		draw_line(Vector2(rect.position.x + 12, y), Vector2(rect.end.x - 12, y + float((i % 7) - 3)), Color(0.66, 0.95, 1.0, alpha), 1.0 + static_amount * 2.0)

	if phase == Phase.SECTION and sol_at_console:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(24, 48), "CONSOLE LINKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.78, 1.0, 0.9))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(24, 88), "Waiting for Luna to reach the relay door.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.9, 1.0))
		return

	var rail_y := rect.position.y + rect.size.y * 0.48
	var rail_left := rect.position.x + 70.0
	var rail_right := rect.end.x - 70.0
	draw_line(Vector2(rail_left, rail_y), Vector2(rail_right, rail_y), Color(0.32, 0.75, 0.86), 8.0)
	var needle_x := lerpf(rail_left, rail_right, needle_value)
	draw_line(Vector2(needle_x, rail_y - 62), Vector2(needle_x, rail_y + 62), Color(1.0, 0.92, 0.36), 5.0)
	draw_circle(Vector2(needle_x, rail_y), 13.0, Color(1.0, 0.92, 0.36))

	var clarity := _signal_clarity()
	var signal_rect := Rect2(rect.position + Vector2(68.0, rect.size.y * 0.24), Vector2(rect.size.x - 136.0, 96.0))
	draw_rect(signal_rect, Color(0.0, 0.025, 0.035, 0.82))
	draw_rect(signal_rect, Color(0.25, 0.8, 0.92, 0.18 + clarity * 0.42), false, 2.0)
	var baseline := signal_rect.position.y + signal_rect.size.y * 0.5
	var wave_points := 44
	for i in range(wave_points - 1):
		var t0 := float(i) / float(wave_points - 1)
		var t1 := float(i + 1) / float(wave_points - 1)
		var x0 := lerpf(signal_rect.position.x + 10.0, signal_rect.end.x - 10.0, t0)
		var x1 := lerpf(signal_rect.position.x + 10.0, signal_rect.end.x - 10.0, t1)
		var clean0 := sin(t0 * TAU * 4.0 + elapsed_time * 3.0) * (14.0 + clarity * 18.0)
		var clean1 := sin(t1 * TAU * 4.0 + elapsed_time * 3.0) * (14.0 + clarity * 18.0)
		var noise0 := sin(t0 * TAU * 31.0 + elapsed_time * 17.0) * (1.0 - clarity) * 24.0
		var noise1 := sin(t1 * TAU * 29.0 + elapsed_time * 19.0) * (1.0 - clarity) * 24.0
		var y0 := baseline + clean0 + noise0
		var y1 := baseline + clean1 + noise1
		draw_line(Vector2(x0, y0), Vector2(x1, y1), Color(0.58, 0.96, 1.0, 0.20 + clarity * 0.72), 2.0 + clarity * 1.5)
	for i in range(10):
		var x := lerpf(signal_rect.position.x + 12.0, signal_rect.end.x - 12.0, float(i) / 9.0)
		var marker_alpha := 0.08 + clarity * 0.22
		draw_line(Vector2(x, signal_rect.position.y + 10.0), Vector2(x, signal_rect.end.y - 10.0), Color(0.35, 0.85, 1.0, marker_alpha), 1.0)

	var label := "TRANSMISSION CONTROL"
	if phase == Phase.ENTRY:
		label = "RADIO CLEAR: ENTER WHAT YOU HEARD"
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(24, 42), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.77, 1.0, 0.9))
	if phase == Phase.ENTRY:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(24, 76), "Keypads active: change digits and submit together.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.58, 0.88, 1.0))
	else:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(24, 76), "Sol: LB/RB tunes. CIRCLE/A captures the clean signal.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.58, 0.88, 1.0))

func _draw_luna_keypad(screen: Vector2) -> void:
	var split_x := screen.x * 0.5
	var rect := Rect2(42, 92, split_x - 84, 154)
	_draw_keypad_panel(
		rect, "LUNA KEYPAD", luna_digits, luna_digit_slot, luna_submitted,
		"Slot: Left/Right on D-pad", "Digit: Up/Down on D-pad", "Submit: CIRCLE or A"
	)

func _draw_sol_keypad(screen: Vector2) -> void:
	var split_x := screen.x * 0.5
	var rect := Rect2(split_x + 62, screen.y - 228, split_x - 124, 146)
	_draw_keypad_panel(
		rect, "SOL CONSOLE INPUT", sol_digits, sol_digit_slot, sol_submitted,
		"Slot: Left/Right D-pad", "Digit: Up/Down D-pad", "Submit: CIRCLE or A"
	)

func _draw_keypad_panel(rect: Rect2, title: String, digits: Array, slot: int, submitted: bool, slot_hint: String, digit_hint: String, submit_hint: String) -> void:
	draw_rect(rect, Color(0.015, 0.03, 0.04, 0.94))
	draw_rect(rect, Color(0.32, 0.85, 0.95, 0.72), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.78, 0.97, 1.0))
	for i in range(2):
		var digit_rect := Rect2(rect.position.x + 92 + i * 68, rect.position.y + 44, 50, 48)
		var border := Color(1.0, 0.95, 0.35) if i == slot and not submitted else Color(0.25, 0.75, 0.88)
		draw_rect(digit_rect, Color(0.02, 0.07, 0.095))
		draw_rect(digit_rect, border, false, 3.0)
		draw_string(ThemeDB.fallback_font, digit_rect.position + Vector2(15, 33), str(int(digits[i])), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.92, 1.0, 0.88))
	if submitted:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, rect.size.y - 20), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.95, 0.75))
	else:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, rect.size.y - 50), slot_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.95, 0.75))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, rect.size.y - 34), digit_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.95, 0.75))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, rect.size.y - 18), submit_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.88, 0.58))

func _draw_escape_bay(screen: Vector2) -> void:
	var floor_y := _floor_y()
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.08, 0.15, 0.18))
	for i in range(9):
		var x := float(i) * screen.x / 9.0
		draw_rect(Rect2(x + 12, 78, 60, floor_y - 92), Color(0.13, 0.21, 0.25))
	draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), Color(0.14, 0.2, 0.24))
	draw_rect(Rect2(screen.x - 295, floor_y - 150, 272, 144), Color(0.18, 0.32, 0.38), true)
	draw_rect(Rect2(screen.x - 295, floor_y - 150, 272, 144), Color(0.72, 0.95, 1.0), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 74), "SIGNAL RELAY UNLOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.82, 1.0, 0.86))
	draw_string(ThemeDB.fallback_font, Vector2(screen.x - 304, floor_y - 166), "ESCAPE POD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.82, 1.0, 0.96))

func _draw_ending(screen: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.02))
	var image_rect := Rect2(screen.x * 0.5 - 320, 70, 640, 360)
	draw_texture_rect(ESCAPE_CUTSCENE, image_rect, false)
	draw_rect(image_rect, Color(0.78, 0.96, 1.0, 0.35), false, 3.0)

func _platforms_for(player_id: String) -> Array:
	var base := _floor_y()
	var data := []
	if player_id == "luna":
		data = [
			[[40, 0, 250], [365, -44, 170], [650, 12, 210], [960, -58, 190], [1240, -12, 260]],
			[[40, -10, 230], [330, 48, 185], [600, -22, 175], [860, -74, 205], [1170, -30, 300]],
			[[40, 0, 210], [310, -64, 190], [610, -18, 160], [820, 48, 190], [1110, -42, 330]],
			[[40, 36, 240], [370, -34, 190], [650, 26, 170], [930, -70, 210], [1210, -18, 270]],
		]
	else:
		data = [
			[[40, 16, 240], [360, -28, 190], [650, 34, 210], [960, -36, 180], [1235, -4, 260]],
			[[40, 0, 225], [320, -58, 175], [585, -10, 190], [850, 44, 210], [1170, -34, 300]],
			[[40, 24, 230], [350, -42, 190], [620, 20, 170], [900, -70, 200], [1195, -20, 280]],
			[[40, -6, 230], [330, 52, 190], [620, -30, 180], [880, -78, 190], [1170, -24, 310]],
		]
	var platforms := []
	for segment in data[section_index]:
		platforms.append(Rect2(float(segment[0]), base + float(segment[1]), float(segment[2]), 30.0))
	return platforms

func _target_position_for(player_id: String) -> Vector2:
	var platforms := _platforms_for(player_id)
	var last_platform: Rect2 = platforms[platforms.size() - 1]
	return Vector2(minf(last_platform.end.x - 72.0, WORLD_WIDTH - 95.0), last_platform.position.y)

func _controls_for(player_id: String) -> Dictionary:
	if player_id == "luna":
		return {"left": "luna_left", "right": "luna_right", "up": "luna_up", "down": "luna_down"}
	return {"left": "sol_left", "right": "sol_right", "up": "sol_up", "down": "sol_down"}

func _entry_controls_for(player_id: String) -> Dictionary:
	if player_id == "luna":
		return {
			"left": "room4_luna_slot_left",
			"right": "room4_luna_slot_right",
			"up": "room4_luna_digit_up",
			"down": "room4_luna_digit_down",
		}
	return {
		"left": "room4_sol_slot_left",
		"right": "room4_sol_slot_right",
		"up": "room4_sol_digit_up",
		"down": "room4_sol_digit_down",
	}

func _is_at_luna_door() -> bool:
	return luna_pos.distance_to(_target_position_for("luna")) <= 74.0

func _is_at_sol_console() -> bool:
	return sol_pos.distance_to(_target_position_for("sol")) <= 74.0

func _rect_light_intensity(rect: Rect2, player_pos: Vector2, facing: float) -> float:
	var samples := [
		rect.get_center(), rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(rect.size.x * 0.25, 0.0),
		rect.position + Vector2(rect.size.x * 0.5, 0.0),
		rect.position + Vector2(rect.size.x * 0.75, 0.0),
		rect.position + Vector2(rect.size.x * 0.5, rect.size.y),
		rect.end,
	]
	var best := 0.0
	for sample in samples:
		best = maxf(best, _light_intensity(sample, player_pos, facing))
	return best

func _light_intensity(point: Vector2, player_pos: Vector2, facing: float) -> float:
	var lamp := player_pos + Vector2(18.0 * facing, -68.0)
	var delta := point - lamp
	var distance := delta.length()
	var halo := clampf(1.0 - distance / HEADLAMP_CLOSE_RADIUS, 0.0, 1.0) * 0.55
	var forward := delta.x * facing
	if forward < 0.0 or forward > HEADLAMP_RANGE:
		return halo
	var cone_center_y := forward * 0.16
	var cone_core := 38.0 + forward * 0.24
	var edge_distance := absf(delta.y - cone_center_y)
	var edge_fade := clampf(1.0 - maxf(edge_distance - cone_core, 0.0) / HEADLAMP_EDGE_SOFTNESS, 0.0, 1.0)
	var distance_fade := clampf(1.0 - maxf(forward - HEADLAMP_FULL_DISTANCE, 0.0) / (HEADLAMP_RANGE - HEADLAMP_FULL_DISTANCE), 0.0, 1.0)
	var cone := pow(edge_fade, 1.6) * pow(distance_fade, 1.25)
	return maxf(halo, cone)

func _world_to_panel(world_pos: Vector2, panel_x: float, camera_left: float) -> Vector2:
	return Vector2(panel_x + world_pos.x - camera_left, world_pos.y)

func _camera_left(player_x: float, panel_width: float) -> float:
	return clampf(player_x - panel_width * 0.34, 0.0, WORLD_WIDTH - panel_width)

func _ensure_room_audio_bus() -> void:
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, false)
		AudioServer.set_bus_solo(master_index, false)
		AudioServer.set_bus_volume_db(master_index, 0.0)

func _play_static_loop(context: String = "static") -> void:
	if static_player == null or static_player.stream == null:
		return
	if not static_player.playing:
		static_player.play()
	_feed_static_audio()
	_debug_static_state(context)

func _start_ambient_static(context: String = "ambient") -> void:
	static_player.volume_db = AMBIENT_STATIC_DB
	_play_static_loop(context)

func _stop_static() -> void:
	if static_player.playing:
		static_player.stop()

func _on_static_finished() -> void:
	if phase != Phase.ESCAPE and phase != Phase.ENDING:
		_start_ambient_static("finished")

func _feed_static_audio() -> void:
	if static_player == null or not static_player.playing:
		return
	var playback := static_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames_available := playback.get_frames_available()
	if frames_available <= 0:
		return
	var frames_to_push := mini(frames_available, 4096)
	var clarity := _signal_clarity() if phase == Phase.TUNING else 0.0
	var noise_gain := lerpf(0.22, 0.045, clarity)
	var tone_gain := 0.025 + clarity * 0.09
	for i in range(frames_to_push):
		static_noise_phase = fmod(static_noise_phase + 1.0 / 44100.0, 1.0)
		var hiss := randf_range(-1.0, 1.0) * noise_gain
		var hum := sin(TAU * 146.0 * static_noise_phase) * tone_gain
		var crackle := randf_range(-0.65, 0.65) if randf() > 0.985 else 0.0
		var sample := clampf(hiss + hum + crackle * noise_gain, -0.85, 0.85)
		playback.push_frame(Vector2(sample, sample))

func _debug_static_state(context: String) -> void:
	if not AUDIO_DEBUG or audio_debug_contexts.has(context):
		return
	audio_debug_contexts[context] = true
	var master_index := AudioServer.get_bus_index("Master")
	var master_muted := AudioServer.is_bus_mute(master_index) if master_index >= 0 else true
	var master_volume := AudioServer.get_bus_volume_db(master_index) if master_index >= 0 else -999.0
	print("Room4 audio ", context, ": playing=", static_player.playing, " volume_db=", static_player.volume_db, " master_muted=", master_muted, " master_db=", master_volume)

func _play_sfx(stream: AudioStream) -> void:
	sfx_player.stream = stream
	sfx_player.play()

func _set_message(text: String, seconds: float) -> void:
	message_text = text
	message_time = maxf(message_time, seconds)

func _current_pair() -> String:
	return CODE_PAIRS[section_index]

func _digits_to_pair(digits: Array) -> String:
	return "%d%d" % [int(digits[0]), int(digits[1])]

func _floor_y() -> float:
	return _screen_size().y - 82.0

func _screen_size() -> Vector2:
	var actual := get_viewport_rect().size
	return Vector2(maxf(actual.x, 960.0), maxf(actual.y, 540.0))

func _interference_amount() -> float:
	if phase == Phase.ENTRY:
		return 0.12
	return clampf(1.0 - _signal_clarity() * 0.92, 0.08, 1.0)

func _signal_clarity() -> float:
	var center := (current_clear_min + current_clear_max) * 0.5
	var distance := absf(needle_value - center)
	var half_window := maxf((current_clear_max - current_clear_min) * 0.5, 0.001)
	return clampf(1.0 - distance / half_window, 0.0, 1.0)

func _escape_pod_rect() -> Rect2:
	var pod_pos := escape_pod_sprite.position
	return Rect2(pod_pos.x - 122.0, pod_pos.y - 82.0, 220.0, 120.0)
