extends Control

## Shared Hades-style boon emblem: a silk-smooth anti-aliased, wider-at-the-bottom
## colored triangle hugging the card's left/bottom inner border behind a rotated,
## double-bordered diamond.
## Colors by kind: EVENT = light green, FAVOR = soft saturated yellow, OMEN = light blue.

var accent: Color = Color(1.0, 0.78, 0.16, 1.0)
var accent_bright: Color = Color(1.0, 0.90, 0.48, 1.0)
## Leave fully transparent to auto-derive a dark accent-tinted inner fill.
var fill_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Set false to render a clean standalone diamond without the left corner ribbon triangle.
var show_triangle: bool = true
## Optional signature ambient effect from DiamondFXLibrary (empty = disabled).
var fx_kind: String = ""
var fx_phase: float = 0.0
var _anim_time: float = 0.0

static func fx_kind_for_id(id_str: String) -> String:
	return DiamondFXLibrary.fx_kind_for_id(id_str)

func set_fx_from_id(canonical_id: String) -> void:
	fx_kind = DiamondFXLibrary.fx_kind_for_id(canonical_id)
	fx_phase = DiamondFXLibrary.fx_phase_for_id(canonical_id)
	set_process(fx_kind != "")

static var _tri_shader: Shader = null
static var _icon_cache: Dictionary = {}
var _tri_rect: ColorRect = null
var _tri_mat: ShaderMaterial = null

static func load_lucide_icon(icon_path: String) -> Texture2D:
	if icon_path == "":
		return null
	if _icon_cache.has(icon_path):
		return _icon_cache[icon_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	elif FileAccess.file_exists(icon_path):
		var img := Image.load_from_file(icon_path)
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_icon_cache[icon_path] = tex
	return tex

static func populate_emblem_glyph(emblem: Control, icon_path: String, fallback_sigil: String, glyph_color: Color, icon_px: float = 36.0, fallback_font_px: int = 34) -> void:
	var tex := load_lucide_icon(icon_path)
	if tex != null:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(icon_px, icon_px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = glyph_color
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(tr)
		emblem.add_child(center)
		emblem.set_meta("_glyph_tr", tr)
		emblem.set_meta("_glyph_base_col", glyph_color)
		return
	var sigil_lbl := Label.new()
	sigil_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	sigil_lbl.text = fallback_sigil
	sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil_lbl.add_theme_font_size_override("font_size", fallback_font_px)
	sigil_lbl.add_theme_color_override("font_color", glyph_color)
	sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(sigil_lbl)

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
		"blessing":
			return {
				"accent": Color(0.95, 0.36, 0.34, 1.0),
				"bright": Color(1.0, 0.80, 0.56, 1.0),
				"bg": Color(0.115, 0.056, 0.058, 0.96),
				"tag": "BLESSING",
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(fx_kind != "")
	if show_triangle:
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

func _process(delta: float) -> void:
	if fx_kind == "" or not is_visible_in_tree():
		return
	_anim_time += delta
	_animate_center_glyph(_anim_time + fx_phase)
	queue_redraw()

func _animate_center_glyph(t: float) -> void:
	if not has_meta("_glyph_tr"):
		return
	var tr := get_meta("_glyph_tr") as TextureRect
	if not is_instance_valid(tr) or tr.size.x <= 1.0:
		return
	tr.pivot_offset = tr.size * 0.5
	var base_col: Color = get_meta("_glyph_base_col", accent_bright)
	match DiamondFXLibrary.glyph_motion_for_fx(fx_kind):
		"pulse_beat":
			var cyc := fmod(t * 0.85, 1.0)
			var beat := maxf(exp(-pow((cyc - 0.12) * 14.0, 2.0)), exp(-pow((cyc - 0.28) * 16.0, 2.0)) * 0.65)
			var s := 1.0 + beat * 0.08
			tr.scale = Vector2(s, s)
			tr.rotation = 0.0
			tr.modulate = base_col.lerp(Color(1.0, 0.98, 0.94, base_col.a), beat * 0.35)
		"float":
			var s := 1.0 + sin(t * 2.0) * 0.025
			tr.scale = Vector2(s, s)
			tr.rotation = sin(t * 1.5) * 0.035
			tr.modulate = base_col
		"shimmer":
			var gl := 0.5 + 0.5 * sin(t * 5.2)
			var s := 1.0 + gl * 0.035
			tr.scale = Vector2(s, s)
			tr.rotation = 0.0
			tr.modulate = base_col.lerp(Color(1.0, 1.0, 0.96, base_col.a), gl * 0.24)
		"sway":
			var s := 1.0 + sin(t * 2.4) * 0.03
			tr.scale = Vector2(s, s)
			tr.rotation = sin(t * 2.2) * 0.055
			tr.modulate = base_col
		_:
			var p := 0.5 + 0.5 * sin(t * 2.1)
			var s := 1.0 + p * 0.04
			tr.scale = Vector2(s, s)
			tr.rotation = 0.0
			tr.modulate = base_col.lerp(Color(1.0, 0.98, 0.92, base_col.a), p * 0.14)

func _sync_triangle_rect() -> void:
	if not is_instance_valid(_tri_rect):
		return
	# Sit slightly inset from the card's left/top/bottom inner border with a wider-than-tall triangle clear of card text
	var h := maxf(size.y, 84.0)
	_tri_rect.position = Vector2(-7.0, -4.0)
	_tri_rect.size = Vector2(minf(h * 1.12, 130.0), h + 8.0)
	if _tri_mat:
		_tri_mat.set_shader_parameter("tri_color", Color(accent.r, accent.g, accent.b, 0.94))

func _draw() -> void:
	var h := size.y
	var c := Vector2(minf(size.x, h) * 0.5, h * 0.5)
	var r := minf(size.x, h) * 0.49
	var t := _anim_time + fx_phase

	if fx_kind != "":
		DiamondFXLibrary.draw_pre_fx(self, fx_kind, c, r, accent, accent_bright, t)

	var outer := _diamond_pts(c, r)
	draw_colored_polygon(outer, Color(0.04, 0.035, 0.03, 0.98))
	draw_polyline(_closed_pts(outer), accent_bright, 2.8, true)

	var inner_fill := fill_color
	if inner_fill.a <= 0.01:
		inner_fill = Color(accent.r * 0.26, accent.g * 0.26, accent.b * 0.26, 0.98)
	var inner := _diamond_pts(c, r * 0.84)
	draw_colored_polygon(inner, inner_fill)

	if fx_kind != "":
		DiamondFXLibrary.draw_inner_fx(self, fx_kind, c, r, accent, accent_bright, t)

	draw_polyline(_closed_pts(inner), Color(accent.r, accent.g, accent.b, 0.88), 1.6, true)

	for pt in outer:
		draw_colored_polygon(_diamond_pts(pt, 3.6), accent_bright)

	if fx_kind != "":
		DiamondFXLibrary.draw_post_fx(self, fx_kind, c, r, outer, accent, accent_bright, t)

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
