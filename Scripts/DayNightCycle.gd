class_name DayNightManager
extends Node


signal day_ended(day_number: int)

const CUSTOMERS_PER_DAY: int = 5


var day: int = 1


var customers_served_today: int = 0

## Normalized time of day: 0.0 = sunrise, 0.5 = noon, 1.0 = midnight.
var time_of_day: float = 0.0

# Lighting references
var sun_light: DirectionalLight3D
var world_env: WorldEnvironment
var _sky_material: ProceduralSkyMaterial

# Colour keyframes
# Format: { time: [sun_color, sun_energy, sun_pitch_degrees, sky_top, sky_horizon, ambient_energy] }
const _KEYFRAMES: Array[Dictionary] = [
	# 0.0 — SUNRISE (early morning warm glow)
	{
		"time": 0.0,
		"sun_color": Color(1.0, 0.7, 0.45),
		"sun_energy": 0.6,
		"sun_pitch": -15.0,
		"sky_top": Color(0.35, 0.35, 0.6),
		"sky_horizon": Color(1.0, 0.6, 0.35),
		"ambient_energy": 0.3,
	},
	# 0.25 — LATE MORNING (brightening)
	{
		"time": 0.25,
		"sun_color": Color(1.0, 0.95, 0.85),
		"sun_energy": 1.0,
		"sun_pitch": -45.0,
		"sky_top": Color(0.3, 0.45, 0.75),
		"sky_horizon": Color(0.65, 0.75, 0.85),
		"ambient_energy": 0.5,
	},
	# 0.5 — NOON (bright white overhead)
	{
		"time": 0.5,
		"sun_color": Color(1.0, 0.98, 0.92),
		"sun_energy": 1.2,
		"sun_pitch": -80.0,
		"sky_top": Color(0.25, 0.45, 0.8),
		"sky_horizon": Color(0.55, 0.65, 0.8),
		"ambient_energy": 0.6,
	},
	# 0.7 — SUNSET (warm orange)
	{
		"time": 0.7,
		"sun_color": Color(1.0, 0.5, 0.15),
		"sun_energy": 0.8,
		"sun_pitch": -15.0,
		"sky_top": Color(0.25, 0.2, 0.45),
		"sky_horizon": Color(1.0, 0.45, 0.15),
		"ambient_energy": 0.35,
	},
	# 0.85 — DUSK (fading)
	{
		"time": 0.85,
		"sun_color": Color(0.4, 0.3, 0.5),
		"sun_energy": 0.3,
		"sun_pitch": -5.0,
		"sky_top": Color(0.1, 0.08, 0.2),
		"sky_horizon": Color(0.3, 0.15, 0.2),
		"ambient_energy": 0.2,
	},
	# 1.0 — NIGHT (dark blue)
	{
		"time": 1.0,
		"sun_color": Color(0.15, 0.15, 0.3),
		"sun_energy": 0.1,
		"sun_pitch": 10.0,
		"sky_top": Color(0.03, 0.03, 0.08),
		"sky_horizon": Color(0.05, 0.05, 0.12),
		"ambient_energy": 0.1,
	},
]

func setup(light: DirectionalLight3D, env_node: WorldEnvironment) -> void:
	sun_light = light
	world_env = env_node
	if world_env and world_env.environment:
		var sky := world_env.environment.sky
		if sky and sky.sky_material is ProceduralSkyMaterial:
			_sky_material = sky.sky_material
	_apply_time(0.0)

## Called after each customer interaction.
func advance_time() -> void:
	customers_served_today += 1
	time_of_day = float(customers_served_today) / float(CUSTOMERS_PER_DAY)
	time_of_day = clampf(time_of_day, 0.0, 1.0)

	print("[DayNight] Customer %d/%d served. Time: %.2f" % [customers_served_today, CUSTOMERS_PER_DAY, time_of_day])

	# Smoothly tween to the new time
	var tween := create_tween()
	tween.tween_method(_apply_time, time_of_day - (1.0 / CUSTOMERS_PER_DAY), time_of_day, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	if customers_served_today >= CUSTOMERS_PER_DAY:
		await tween.finished
		day_ended.emit(day)
		# Reset for next day
		day += 1
		customers_served_today = 0
		time_of_day = 0.0
		_apply_time(0.0)

func _apply_time(t: float) -> void:
	# Find the two keyframes we're between
	var kf_a: Dictionary = _KEYFRAMES[0]
	var kf_b: Dictionary = _KEYFRAMES[1]
	for i in range(_KEYFRAMES.size() - 1):
		if t >= _KEYFRAMES[i]["time"] and t <= _KEYFRAMES[i + 1]["time"]:
			kf_a = _KEYFRAMES[i]
			kf_b = _KEYFRAMES[i + 1]
			break

	# Interpolation factor between the two keyframes
	var span: float = kf_b["time"] - kf_a["time"]
	var factor: float = 0.0
	if span > 0.001:
		factor = (t - kf_a["time"]) / span

	# Interpolate all values
	var sun_color: Color = kf_a["sun_color"].lerp(kf_b["sun_color"], factor)
	var sun_energy: float = lerpf(kf_a["sun_energy"], kf_b["sun_energy"], factor)
	var sun_pitch: float = lerpf(kf_a["sun_pitch"], kf_b["sun_pitch"], factor)
	var sky_top: Color = kf_a["sky_top"].lerp(kf_b["sky_top"], factor)
	var sky_horizon: Color = kf_a["sky_horizon"].lerp(kf_b["sky_horizon"], factor)
	var ambient_energy: float = lerpf(kf_a["ambient_energy"], kf_b["ambient_energy"], factor)

	# Apply to sun
	if sun_light:
		sun_light.light_color = sun_color
		sun_light.light_energy = sun_energy
		sun_light.rotation_degrees.x = sun_pitch

	# Apply to sky
	if _sky_material:
		_sky_material.sky_top_color = sky_top
		_sky_material.sky_horizon_color = sky_horizon

	# Apply to environment
	if world_env and world_env.environment:
		world_env.environment.ambient_light_energy = ambient_energy
		world_env.environment.ambient_light_color = sun_color
