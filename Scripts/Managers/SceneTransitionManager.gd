extends CanvasLayer

var color_rect: ColorRect

func _ready() -> void:
	layer = 128 # Keep it on top of all UI
	color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)
	
func change_scene(path: String) -> void:
	# Blink to black
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, 0.15).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	
	# Change scene
	get_tree().change_scene_to_file(path)
	
	# Blink from black
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC)
