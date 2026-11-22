class_name AltBadge3D
extends Label3D

## Compact 3D "Alt" badge attached to the bottom-right of uninspected items/containers.
## Gently pulses (enlarges and shrinks) until the player inspects the item with Alt.

static var _circle_tex: ImageTexture = null

var _pulse_tween: Tween = null
var _bg_sprite: Sprite3D = null

static func _get_circle_texture() -> ImageTexture:
	if _circle_tex != null:
		return _circle_tex
	const SIZE := 128
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE * 0.5, SIZE * 0.5)
	var radius := SIZE * 0.47
	var edge := 2.0
	for y in SIZE:
		for x in SIZE:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf((radius - dist) / edge, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.05, 0.05, 0.07, alpha * 0.82))
	_circle_tex = ImageTexture.create_from_image(img)
	return _circle_tex

func _ready() -> void:
	text = "Alt"
	font = UIStyle.FONT_INDER
	font_size = 36
	pixel_size = 0.0026
	modulate = Color(1.0, 0.94, 0.72, 1.0)
	outline_modulate = Color(0.06, 0.05, 0.04, 0.95)
	outline_size = 11
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = true
	render_priority = 12
	outline_render_priority = 11

	_bg_sprite = Sprite3D.new()
	_bg_sprite.texture = _get_circle_texture()
	_bg_sprite.pixel_size = 0.0018
	_bg_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bg_sprite.shaded = false
	_bg_sprite.no_depth_test = true
	_bg_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_bg_sprite.render_priority = 10
	add_child(_bg_sprite)

	_start_pulse()

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	scale = Vector3.ONE * 0.85
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector3.ONE * 1.18, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", Vector3.ONE * 0.85, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func dismiss_and_free() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
