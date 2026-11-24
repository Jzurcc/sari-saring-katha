extends Control

## Shared Hades-style boon emblem: a silk-smooth anti-aliased, wider-at-the-bottom
## colored triangle hugging the card's left/bottom inner border behind a rotated,
## double-bordered diamond.
## Colors by kind: EVENT = light green, FAVOR = soft saturated yellow, OMEN = light blue.

var accent: Color = Color(1.0, 0.78, 0.16, 1.0)
var accent_bright: Color = Color(1.0, 0.90, 0.48, 1.0)
## Leave fully transparent to auto-derive a dark accent-tinted inner fill.
var fill_color: Color = Color(0.0, 0.0, 0.0, 0.0)

static var _tri_shader: Shader = null
var _tri_rect: ColorRect = null
var _tri_mat: ShaderMaterial = null

static func palette(kind: String) -> Dictionary:
	match kind:
		"event":
			return {
				"accent": Color(0.34, 0.82, 0.32, 1.0),
				"bright": Color(0.68, 0.97, 0.58, 1.0),
				"bg": Color(0.060, 0.092, 0.064, 0.96),
				"tag": "EVENT",
			}
		"chill", "omen":
			return {
				"accent": Color(0.26, 0.60, 1.0, 1.0),
				"bright": Color(0.64, 0.85, 1.0, 1.0),
				"bg": Color(0.056, 0.076, 0.118, 0.96),
				"tag": "OMEN",
			}
		_:
			return {
				"accent": Color(1.0, 0.78, 0.16, 1.0),
				"bright": Color(1.0, 0.90, 0.48, 1.0),
				"bg": Color(0.098, 0.084, 0.052, 0.96),
				"tag": "FAVOR",
			}

static func _get_tri_shader() -> Shader:
	if _tri_shader == null:
		_tri_shader = Shader.new()
		_tri_shader.code = """
shader_type canvas_item;
uniform vec4 tri_color : source_color = vec4(0.34, 0.82, 0.32, 0.94);
uniform float aa_width = 0.012;
void fragment() {
	// Diagonal from top-left (0,0) to bottom-right (1,1): UV.y > UV.x is inside the triangle.
	// Using fwidth gives pixel-perfect anti-aliasing at any resolution or aspect ratio.
	float d = UV.y - UV.x;
	float fw = max(fwidth(d), aa_width);
	float alpha = smoothstep(-fw, fw, d);
	// Subtle darker vignette near bottom-left for depth
	float shade = mix(0.84, 1.05, clamp(UV.x * 0.65 + (1.0 - UV.y) * 0.35, 0.0, 1.0));
	COLOR = vec4(tri_color.rgb * shade, tri_color.a * alpha);
}
"""
	return _tri_shader

func _ready() -> void:
	_tri_rect = ColorRect.new()
	_tri_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tri_rect.show_behind_parent = true
	_tri_mat = ShaderMaterial.new()
	_tri_mat.shader = _get_tri_shader()
	_tri_mat.set_shader_parameter("tri_color", Color(accent.r, accent.g, accent.b, 0.94))
	_tri_rect.material = _tri_mat
	add_child(_tri_rect)
	move_child(_tri_rect, 0)
	_sync_triangle_rect()
	resized.connect(_sync_triangle_rect)

func _sync_triangle_rect() -> void:
	if not is_instance_valid(_tri_rect):
		return
	# Hug close to the card's left/top/bottom inner border and extend wider along the bottom (Hades proportions!)
	var h := maxf(size.y, 118.0)
	_tri_rect.position = Vector2(-10.0, -7.0)
	_tri_rect.size = Vector2(h * 1.48, h + 14.0)
	if _tri_mat:
		_tri_mat.set_shader_parameter("tri_color", Color(accent.r, accent.g, accent.b, 0.94))

func _draw() -> void:
	var h := size.y
	var c := Vector2(minf(size.x, h) * 0.5, h * 0.5)
	var r := minf(size.x, h) * 0.49

	var outer := _diamond_pts(c, r)
	draw_colored_polygon(outer, Color(0.04, 0.035, 0.03, 0.98))
	draw_polyline(_closed_pts(outer), accent_bright, 2.8, true)

	var inner_fill := fill_color
	if inner_fill.a <= 0.01:
		inner_fill = Color(accent.r * 0.26, accent.g * 0.26, accent.b * 0.26, 0.98)
	var inner := _diamond_pts(c, r * 0.84)
	draw_colored_polygon(inner, inner_fill)
	draw_polyline(_closed_pts(inner), Color(accent.r, accent.g, accent.b, 0.88), 1.6, true)

	for pt in outer:
		draw_colored_polygon(_diamond_pts(pt, 3.6), accent_bright)

func _diamond_pts(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])

func _closed_pts(pts: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed
