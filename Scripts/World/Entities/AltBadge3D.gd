class_name AltBadge3D
extends Label3D

## Compact 3D "Alt" keycap badge attached to the bottom-right of uninspected items/containers.
## Gently pulses until the player inspects the item with Alt.

static var _pill_tex: ImageTexture = null

var _pulse_tween: Tween = null
var _bg_sprite: Sprite3D = null

static func _get_pill_texture() -> ImageTexture:
	if _pill_tex != null:
		return _pill_tex
	const W := 152
	const H := 96
	const PAD := 6.0
	const RADIUS := 18.0
	const BORDER_W := 4.0
	const AA := 1.8

	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var half_w := W * 0.5 - PAD - RADIUS
	var half_h := H * 0.5 - PAD - RADIUS
	var cx := W * 0.5
	var cy := H * 0.5

	var fill_col := Color(0.06, 0.052, 0.046, 0.94)
	var border_col := Color(0.86, 0.66, 0.30, 0.88)

	for y in H:
		for x in W:
			var dx := absf((x + 0.5) - cx) - half_w
			var dy := absf((y + 0.5) - cy) - half_h
			var outside := Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
			var inside := minf(maxf(dx, dy), 0.0)
			var sdf := outside + inside - RADIUS

			var outer_alpha := clampf((-sdf) / AA, 0.0, 1.0)
			if outer_alpha <= 0.001:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var inner_mix := clampf((-sdf - BORDER_W) / AA, 0.0, 1.0)
			var col := border_col.lerp(fill_col, inner_mix)
			col.a *= outer_alpha
			img.set_pixel(x, y, col)

	_pill_tex = ImageTexture.create_from_image(img)
	return _pill_tex

func _ready() -> void:
	_refresh_key_text()
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("keybinds_changed") and not eb.keybinds_changed.is_connected(_refresh_key_text):
		eb.keybinds_changed.connect(_refresh_key_text)
	font = UIStyle.FONT_FREDOKA_MED
	font_size = 28
	pixel_size = 0.0020
	modulate = Color(1.0, 0.93, 0.78, 1.0)
	outline_modulate = Color(0.06, 0.052, 0.046, 0.92)
	outline_size = 4
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = true
	render_priority = 12
	outline_render_priority = 11

	_bg_sprite = Sprite3D.new()
	_bg_sprite.texture = _get_pill_texture()
	_bg_sprite.pixel_size = 0.00112
	_bg_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bg_sprite.shaded = false
	_bg_sprite.no_depth_test = true
	_bg_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_bg_sprite.render_priority = 10
	add_child(_bg_sprite)

	call_deferred("_start_bob")

func _refresh_key_text() -> void:
	var nav := get_node_or_null("/root/DialogueChoiceNavigator")
	if nav and nav.has_method("get_action_key_label"):
		text = nav.get_action_key_label("pricing_lens", "V")
	else:
		text = "V"

func _start_bob() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var base_y := position.y
	scale = Vector3.ONE
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "position:y", base_y + 0.018, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.parallel().tween_property(_bg_sprite, "modulate", Color(1.12, 1.08, 0.98, 1.0), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "position:y", base_y - 0.006, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.parallel().tween_property(_bg_sprite, "modulate", Color(0.94, 0.92, 0.88, 0.92), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func dismiss_and_free() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
