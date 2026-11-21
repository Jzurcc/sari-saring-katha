class_name AltBadge3D
extends Label3D

## Compact 3D "ALT" badge attached to the bottom-right of uninspected items/containers.
## Gently pulses (enlarges and shrinks) until the player inspects the item with ALT.

var _pulse_tween: Tween = null

func _ready() -> void:
	text = "ALT"
	font = UIStyle.FONT_INDER
	font_size = 28
	pixel_size = 0.0022
	modulate = Color(1.0, 0.94, 0.72, 1.0)
	outline_modulate = Color(0.08, 0.07, 0.06, 0.98)
	outline_size = 14
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	render_priority = 12
	outline_render_priority = 11
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
