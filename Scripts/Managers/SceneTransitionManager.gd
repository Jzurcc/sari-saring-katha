extends CanvasLayer

var eyelid_top: ColorRect
var eyelid_bottom: ColorRect

const EYELID_SHADER = """
shader_type canvas_item;
uniform float feather : hint_range(0.0, 1.0) = 0.4;
uniform bool is_bottom = false;

void fragment() {
	float alpha = 1.0;
	if (is_bottom) {
		alpha = smoothstep(0.0, feather, UV.y);
	} else {
		alpha = smoothstep(1.0, 1.0 - feather, UV.y);
	}
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""

func _ready() -> void:
	layer = 128 # Keep it on top of all UI
	
	var shader = Shader.new()
	shader.code = EYELID_SHADER
	
	eyelid_top = ColorRect.new()
	var mat_top = ShaderMaterial.new()
	mat_top.shader = shader
	mat_top.set_shader_parameter("is_bottom", false)
	mat_top.set_shader_parameter("feather", 0.45)
	eyelid_top.material = mat_top
	eyelid_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	eyelid_top.anchor_bottom = 0.0
	eyelid_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eyelid_top)
	
	eyelid_bottom = ColorRect.new()
	var mat_bottom = ShaderMaterial.new()
	mat_bottom.shader = shader
	mat_bottom.set_shader_parameter("is_bottom", true)
	mat_bottom.set_shader_parameter("feather", 0.45)
	eyelid_bottom.material = mat_bottom
	eyelid_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	eyelid_bottom.anchor_top = 1.0
	eyelid_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eyelid_bottom)

func change_scene(path: String) -> void:
	# Block input during transition
	eyelid_top.mouse_filter = Control.MOUSE_FILTER_STOP
	eyelid_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	
	# Single smooth closure
	# We go well past 0.5 to ensure the eyelids overlap significantly and form a solid black fade
	tween.tween_property(eyelid_top, "anchor_bottom", 1.1, 0.4)
	tween.tween_property(eyelid_bottom, "anchor_top", -0.1, 0.4)
	
	await tween.finished
	
	# Change scene
	get_tree().change_scene_to_file(path)
	
	# Wait for scene to load and settle
	await get_tree().create_timer(0.25).timeout
	
	# Smooth open
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	
	tween.tween_property(eyelid_top, "anchor_bottom", 0.0, 0.6)
	tween.tween_property(eyelid_bottom, "anchor_top", 1.0, 0.6)
	
	await tween.finished
	
	# Unblock input
	eyelid_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eyelid_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
