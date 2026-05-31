extends CanvasLayer

var overlay: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)

func fade_out(duration: float = 0.8) -> void:
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, duration)

func fade_in(duration: float = 0.8) -> void:
	overlay.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.0, duration)

func fade_to_scene(path: String, duration: float = 0.8) -> void:
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, duration)
	tween.tween_callback(func(): get_tree().change_scene_to_file(path))
