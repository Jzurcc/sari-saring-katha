class_name CustomerAttentionBadge3D
extends Label3D

## Compact 3D attention bubble floating above customers who are waiting to be
## greeted ("!") or have returned from lingering for optional smalltalk ("...").

enum Mode {
	HIDDEN,
	UNGREETED,
	SMALLTALK,
	THOUGHT,
}

static var _ungreeted_tex: ImageTexture = null
static var _smalltalk_tex: ImageTexture = null
static var _thought_tex: ImageTexture = null

var _mode: Mode = Mode.HIDDEN
var _bg_sprite: Sprite3D = null
var _base_y: float = 0.0
var _mode_y_offset: float = 0.0
var _bob_time: float = 0.0
var _pop_tween: Tween = null


static func _get_bubble_texture(for_mode: Mode) -> ImageTexture:
	if for_mode == Mode.THOUGHT:
		if _thought_tex == null:
			_thought_tex = _build_thought_bubble_texture(
				Color(0.98, 0.94, 0.86, 0.95),
				Color(0.42, 0.30, 0.16, 0.95)
			)
		return _thought_tex
	if for_mode == Mode.SMALLTALK:
		if _smalltalk_tex == null:
			_smalltalk_tex = _build_bubble_texture(
				Color(0.08, 0.12, 0.13, 0.94),
				Color(0.48, 0.89, 0.78, 1.0)
			)
		return _smalltalk_tex

	if _ungreeted_tex == null:
		_ungreeted_tex = _build_bubble_texture(
			Color(0.11, 0.08, 0.06, 0.94),
			Color(0.96, 0.78, 0.42, 1.0)
		)
	return _ungreeted_tex


static func _build_thought_bubble_texture(fill_col: Color, border_col: Color) -> ImageTexture:
	const SIZE := 128
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var box_center := Vector2(64.0, 48.0)
	var box_half := Vector2(38.0, 28.0)
	var corner_r := 22.0
	var border_w := 4.8
	var edge := 2.0
	var dot1_c := Vector2(58.0, 88.0)
	var dot1_r := 7.5
	var dot2_c := Vector2(51.0, 104.0)
	var dot2_r := 4.8

	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(absf(p.x - box_center.x), absf(p.y - box_center.y)) - (box_half - Vector2(corner_r, corner_r))
			var sd_box := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - corner_r
			var sd_d1 := p.distance_to(dot1_c) - dot1_r
			var sd_d2 := p.distance_to(dot2_c) - dot2_r
			var sd := minf(sd_box, minf(sd_d1, sd_d2))
			if sd > edge:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var outer_alpha := clampf((edge - sd) / edge, 0.0, 1.0)
			var inner_blend := clampf((-sd - (border_w - 1.0)) / 1.5, 0.0, 1.0)
			var col := border_col.lerp(fill_col, inner_blend)
			col.a *= outer_alpha
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


static func _build_bubble_texture(fill_col: Color, border_col: Color) -> ImageTexture:
	const SIZE := 128
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var box_center := Vector2(64.0, 54.0)
	var box_half := Vector2(36.0, 28.0)
	var corner_r := 18.0
	var border_w := 5.5
	var edge := 2.0

	# Bottom pointer tail vertices (triangle overlapping slightly into bottom edge)
	var tip_y := 106.0
	var tail_top_y := 78.0
	var tail_half_w := 13.0

	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(absf(p.x - box_center.x), absf(p.y - box_center.y)) - (box_half - Vector2(corner_r, corner_r))
			var sd_box := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - corner_r

			# Signed distance approximation for downward-pointing triangle
			var sd_tri := 100.0
			if p.y >= tail_top_y - 6.0 and p.y <= tip_y + 4.0:
				var t := clampf((p.y - tail_top_y) / (tip_y - tail_top_y), 0.0, 1.0)
				var allowed_hw := tail_half_w * (1.0 - t)
				var dx := absf(p.x - box_center.x) - allowed_hw
				var dy_top := tail_top_y - p.y
				var dy_bot := p.y - tip_y
				# Approximate perpendicular distance on sloped sides (~0.9 factor)
				sd_tri = maxf(dx * 0.89, maxf(dy_top, dy_bot))

			var sd := minf(sd_box, sd_tri)
			if sd > edge:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var outer_alpha := clampf((edge - sd) / edge, 0.0, 1.0)
			var inner_blend := clampf((-sd - (border_w - 1.0)) / 1.5, 0.0, 1.0)
			var col := border_col.lerp(fill_col, inner_blend)
			col.a *= outer_alpha
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


func _ready() -> void:
	text = "!"
	font = UIStyle.FONT_INDER
	font_size = 54
	pixel_size = 0.0032
	modulate = Color(1.0, 0.93, 0.70, 1.0)
	outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
	outline_size = 11
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = true
	render_priority = 12
	outline_render_priority = 11

	_bg_sprite = Sprite3D.new()
	_bg_sprite.texture = _get_bubble_texture(Mode.UNGREETED)
	_bg_sprite.pixel_size = 0.0026
	_bg_sprite.position = Vector3(0.0, -0.024, 0.0)
	_bg_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bg_sprite.shaded = false
	_bg_sprite.no_depth_test = true
	_bg_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_bg_sprite.render_priority = 10
	add_child(_bg_sprite)

	_bob_time = randf() * TAU
	scale = Vector3.ZERO
	visible = false


func set_base_y(y_pos: float) -> void:
	_base_y = y_pos
	position.y = _base_y + _mode_y_offset


func _process(delta: float) -> void:
	if not visible:
		return
	_bob_time += delta
	position.y = _base_y + _mode_y_offset + sin(_bob_time * 3.4) * 0.045


func set_mode(new_mode: Mode) -> void:
	if new_mode == _mode:
		return
	_mode = new_mode

	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
		_pop_tween = null

	if new_mode == Mode.HIDDEN:
		if not visible:
			return
		_pop_tween = create_tween()
		_pop_tween.tween_property(self, "scale", Vector3.ZERO, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_pop_tween.tween_callback(func():
			if _mode == Mode.HIDDEN:
				visible = false
		)
		return

	if new_mode == Mode.SMALLTALK:
		text = "•••"
		font_size = 42
		_mode_y_offset = 0.30
		modulate = Color(0.84, 1.0, 0.95, 1.0)
		outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
		outline_size = 10
	elif new_mode == Mode.THOUGHT:
		font_size = 48
		_mode_y_offset = 0.12
		outline_modulate = Color(0.20, 0.14, 0.08, 0.45)
		outline_size = 4
	else:
		text = "!"
		font_size = 54
		_mode_y_offset = 0.0
		modulate = Color(1.0, 0.93, 0.70, 1.0)
		outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
		outline_size = 11

	position.y = _base_y + _mode_y_offset

	if _bg_sprite:
		_bg_sprite.texture = _get_bubble_texture(new_mode)

	visible = true
	scale = Vector3.ZERO
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_thought(glyph: String, glyph_color: Color = Color(0.24, 0.16, 0.09, 1.0)) -> void:
	text = glyph
	modulate = glyph_color
	_mode = Mode.HIDDEN # Force re-pop animation even if showing a new thought
	set_mode(Mode.THOUGHT)


func is_showing_thought() -> bool:
	return _mode == Mode.THOUGHT and visible
