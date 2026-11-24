class_name ColorWheelControl
extends Control

## Compact HSV color wheel widget for the Storefront Drawing Studio.
## Generates the hue/saturation disc once at V=1.0 and tints via _val at draw time
## so brightness slider updates run cleanly with zero image regeneration.

signal color_changed(new_color: Color)

const WHEEL_TEX_SIZE := 156
const WHEEL_MARGIN := 6.0

var _wheel_texture: ImageTexture = null
var _hue: float = 0.0
var _sat: float = 0.0
var _val: float = 0.15
var _is_dragging: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(WHEEL_TEX_SIZE, WHEEL_TEX_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	_build_wheel_texture()


func _build_wheel_texture() -> void:
	var img := Image.create(WHEEL_TEX_SIZE, WHEEL_TEX_SIZE, false, Image.FORMAT_RGBA8)
	var center := float(WHEEL_TEX_SIZE) * 0.5
	var radius := center - WHEEL_MARGIN
	var data := PackedByteArray()
	data.resize(WHEEL_TEX_SIZE * WHEEL_TEX_SIZE * 4)

	var idx := 0
	for py in range(WHEEL_TEX_SIZE):
		var dy := float(py) + 0.5 - center
		for px in range(WHEEL_TEX_SIZE):
			var dx := float(px) + 0.5 - center
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= radius + 1.5:
				var sat := clampf(dist / radius, 0.0, 1.0)
				var hue := fposmod(atan2(dy, dx) / TAU, 1.0)
				var col := Color.from_hsv(hue, sat, 1.0, 1.0)
				var alpha := clampf((radius + 1.0 - dist) / 1.5, 0.0, 1.0)
				data[idx] = int(roundf(col.r * 255.0))
				data[idx + 1] = int(roundf(col.g * 255.0))
				data[idx + 2] = int(roundf(col.b * 255.0))
				data[idx + 3] = int(roundf(alpha * 255.0))
			else:
				data[idx] = 0
				data[idx + 1] = 0
				data[idx + 2] = 0
				data[idx + 3] = 0
			idx += 4

	img.set_data(WHEEL_TEX_SIZE, WHEEL_TEX_SIZE, false, Image.FORMAT_RGBA8, data)
	_wheel_texture = ImageTexture.create_from_image(img)
	queue_redraw()


func get_color() -> Color:
	return Color.from_hsv(_hue, _sat, _val, 1.0)


func get_value_component() -> float:
	return _val


## Updates internal HSV state from an external Color without emitting color_changed.
func set_color_silent(col: Color) -> void:
	_val = col.v
	if col.s > 0.004:
		_hue = col.h
		_sat = col.s
	elif col.v <= 0.004:
		_sat = 0.0
	else:
		_sat = 0.0
	queue_redraw()


## Updates Value (brightness) component silently without emitting color_changed.
func set_value_silent(v: float) -> void:
	_val = clampf(v, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var dim := minf(size.x, size.y)
	if dim <= 4.0:
		return
	var offset := (size - Vector2(dim, dim)) * 0.5
	var center := offset + Vector2(dim, dim) * 0.5
	var scale_ratio := dim / float(WHEEL_TEX_SIZE)
	var radius := (float(WHEEL_TEX_SIZE) * 0.5 - WHEEL_MARGIN) * scale_ratio

	# Outer dark rim
	draw_circle(center, radius + 3.0, Color(0.08, 0.07, 0.06, 0.95))
	draw_arc(center, radius + 3.0, 0.0, TAU, 64, Color(0.835, 0.624, 0.278, 0.75), 1.5, true)

	if _wheel_texture:
		var tint := Color(_val, _val, _val, 1.0)
		draw_texture_rect(_wheel_texture, Rect2(offset, Vector2(dim, dim)), false, tint)

	# Active Hue/Sat reticle
	var angle := _hue * TAU
	var cursor_pos := center + Vector2(cos(angle), sin(angle)) * (_sat * radius)
	draw_circle(cursor_pos, 6.5, Color(0.06, 0.06, 0.06, 0.92))
	draw_circle(cursor_pos, 4.5, get_color())
	draw_arc(cursor_pos, 6.0, 0.0, TAU, 24, Color.WHITE, 1.5, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_pick_at(event.position)
			accept_event()
		else:
			_is_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		_pick_at(event.position)
		accept_event()


func _pick_at(local_pos: Vector2) -> void:
	var dim := minf(size.x, size.y)
	if dim <= 4.0:
		return
	var offset := (size - Vector2(dim, dim)) * 0.5
	var center := offset + Vector2(dim, dim) * 0.5
	var scale_ratio := dim / float(WHEEL_TEX_SIZE)
	var radius := maxf(1.0, (float(WHEEL_TEX_SIZE) * 0.5 - WHEEL_MARGIN) * scale_ratio)

	var delta := local_pos - center
	var dist := minf(delta.length(), radius)
	_sat = clampf(dist / radius, 0.0, 1.0)
	if delta.length_squared() > 0.0001:
		_hue = fposmod(atan2(delta.y, delta.x) / TAU, 1.0)
	queue_redraw()
	color_changed.emit(get_color())
