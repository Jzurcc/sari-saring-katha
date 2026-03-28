## FlickerLight.gd
## Attach to an OmniLight3D or SpotLight3D.
## Simulates a slightly faulty fluorescent tube — subtle, low-budget realism.
class_name FlickerLight
extends Light3D

## The "normal" power of the light at rest.
@export var base_energy: float = 1.2
## Maximum random deviation each flicker can add/subtract.
@export var flicker_amount: float = 0.15
## How frequently a new flicker target is picked (seconds).
@export var flicker_rate: float = 0.08
## Chance (0-1) each tick will produce a strong dip instead of normal noise.
@export var glitch_chance: float = 0.04
## How deep the glitch dip goes (0 = completely off).
@export var glitch_low: float = 0.1

var _timer: float = 0.0
var _target_energy: float = base_energy

func _ready() -> void:
	light_energy = base_energy

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= flicker_rate:
		_timer = 0.0
		_pick_new_target()
	# Smooth interpolate toward the flickering target
	light_energy = lerp(light_energy, _target_energy, 20.0 * delta)

func _pick_new_target() -> void:
	if randf() < glitch_chance:
		# Occasional dramatic dip — the "bad tube" moment
		_target_energy = randf_range(glitch_low, base_energy * 0.5)
	else:
		_target_energy = base_energy + randf_range(-flicker_amount, flicker_amount)
