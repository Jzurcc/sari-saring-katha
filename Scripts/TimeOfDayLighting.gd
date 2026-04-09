##
## TimeOfDayLighting: Cinematic Day-Night Lighting System
##
## This script manages a sophisticated lighting progression across a 24-hour in-game day.
## It smoothly transitions between keyframes defined in the 'keyframes' Export array.
##
extends Node

@export var keyframes: Array[LightingKeyframe] = []

# Reference to parent Environment for postprocessing updates
var _environment: Environment = null
var _sky_material: Material = null
var _sun_light: DirectionalLight3D = null
var _moon_light: DirectionalLight3D = null
var _omni_light: OmniLight3D = null
var _night_light: DirectionalLight3D = null
var _time_of_day: Node = null

# Current interpolation state
var _current_from_state: LightingKeyframe = null
var _current_to_state: LightingKeyframe = null
var _current_t: float = 0.0
var _is_transitioning: bool = false
var _transition_tween: Tween = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Find sibling nodes
	var parent = get_parent()
	if parent is WorldEnvironment:
		_environment = parent.environment
		if _environment and _environment.sky:
			_sky_material = _environment.sky.sky_material
			if not _sky_material:
				push_error("[TimeOfDayLighting] Sky material is null. Ensure Sky3D has a valid SkyMaterial assigned.")
				return

	_time_of_day = get_parent().get_node_or_null("TimeOfDay")
	_sun_light = get_parent().get_node_or_null("SunLight")
	_moon_light = get_parent().get_node_or_null("MoonLight")
	_night_light = get_parent().get_node_or_null("NightLight")

	var store_node = get_parent().get_parent()
	if store_node:
		var lights = store_node.find_children("*", "OmniLight3D")
		if lights.size() > 0:
			_omni_light = lights[0]

	if keyframes.is_empty():
		_initialize_fallback_keyframes()

	if _time_of_day:
		_time_of_day.time_changed.connect(_on_time_changed)
		_on_time_changed(_time_of_day.current_time)

func _initialize_fallback_keyframes() -> void:
	# Fallback hardcoded initialization so no data is lost!
	push_warning("[TimeOfDayLighting] Keyframes array empty. Using fallback hardcoded keyframes.")
	var k1 = LightingKeyframe.new()
	k1.state_name = "sunrise"
	k1.time_range = Vector2(5.0, 7.0)
	k1.shader_atm_sun_intensity = 8.0
	k1.shader_sun_disk_intensity = 15.0
	k1.shader_atm_day_tint = Color(0.95, 0.85, 0.70, 1)
	k1.shader_atm_horizon_light_tint = Color(1.0, 0.70, 0.40, 1)
	k1.shader_starmap_color = Color(0.5, 0.5, 0.5, 0.3)
	k1.shader_moon_size = 0.07
	k1.shader_cumulus_position = Vector2(0.016734878, 0.016734878)
	k1.shader_cumulus_intensity = 0.6
	k1.shader_cumulus_coverage = 0.55
	k1.shader_cirrus_position1 = Vector2(0.0033469682, 0.0033469682)
	k1.shader_cirrus_position2 = Vector2(0.0033469682, 0.0033469682)
	k1.env_glow_intensity = 0.8
	k1.env_glow_bloom = 0.25
	k1.env_adjustment_saturation = 1.0
	k1.env_ambient_light_energy = 0.4
	k1.light_sun_energy = 0.4
	k1.light_moon_energy = 0.0
	k1.light_omni_energy = 0.3
	k1.light_night_energy = 0.0
	keyframes.append(k1)
	
	var k2 = LightingKeyframe.new()
	k2.state_name = "midday"
	k2.time_range = Vector2(10.0, 15.0)
	k2.shader_atm_sun_intensity = 18.0
	k2.shader_sun_disk_intensity = 30.0
	k2.shader_atm_day_tint = Color(0.81, 0.91, 1.0, 1)
	k2.shader_atm_horizon_light_tint = Color(0.98, 0.64, 0.46, 1)
	k2.shader_starmap_color = Color(0.7, 0.7, 0.7, 0.0)
	k2.shader_moon_size = 0.0
	k2.shader_cumulus_position = Vector2(0.017, 0.017)
	k2.shader_cumulus_intensity = 0.6
	k2.shader_cumulus_coverage = 0.55
	k2.shader_cirrus_position1 = Vector2(0.0034, 0.0034)
	k2.shader_cirrus_position2 = Vector2(0.0034, 0.0034)
	k2.env_glow_intensity = 1.0
	k2.env_glow_bloom = 0.15
	k2.env_adjustment_saturation = 1.2
	k2.env_ambient_light_energy = 0.8
	k2.light_sun_energy = 0.8
	k2.light_moon_energy = 0.0
	k2.light_omni_energy = 0.0
	k2.light_night_energy = 0.0
	keyframes.append(k2)
	
	var k3 = LightingKeyframe.new()
	k3.state_name = "golden_hour"
	k3.time_range = Vector2(16.0, 17.5)
	k3.shader_atm_sun_intensity = 12.0
	k3.shader_sun_disk_intensity = 25.0
	k3.shader_atm_day_tint = Color(1.0, 0.88, 0.65, 1)
	k3.shader_atm_horizon_light_tint = Color(1.0, 0.75, 0.30, 1)
	k3.shader_starmap_color = Color(0.7, 0.7, 0.7, 0.1)
	k3.shader_moon_size = 0.04
	k3.shader_cumulus_position = Vector2(0.018, 0.018)
	k3.shader_cumulus_intensity = 0.7
	k3.shader_cumulus_coverage = 0.45
	k3.shader_cirrus_position1 = Vector2(0.0035, 0.0035)
	k3.shader_cirrus_position2 = Vector2(0.0035, 0.0035)
	k3.env_glow_intensity = 1.8
	k3.env_glow_bloom = 0.6
	k3.env_adjustment_saturation = 1.4
	k3.env_ambient_light_energy = 0.65
	k3.light_sun_energy = 0.65
	k3.light_moon_energy = 0.0
	k3.light_omni_energy = 0.5
	k3.light_night_energy = 0.0
	keyframes.append(k3)
	
	var k4 = LightingKeyframe.new()
	k4.state_name = "dusk"
	k4.time_range = Vector2(18.0, 19.5)
	k4.shader_atm_sun_intensity = 4.0
	k4.shader_sun_disk_intensity = 0.0
	k4.shader_atm_day_tint = Color(0.60, 0.75, 1.0, 1)
	k4.shader_atm_horizon_light_tint = Color(0.40, 0.30, 0.60, 1)
	k4.shader_starmap_color = Color(0.8, 0.8, 0.8, 0.5)
	k4.shader_moon_size = 0.07
	k4.shader_atm_moon_mie_intensity = 0.3
	k4.shader_cumulus_position = Vector2(0.019, 0.019)
	k4.shader_cumulus_intensity = 0.8
	k4.shader_cumulus_coverage = 0.6
	k4.shader_cirrus_position1 = Vector2(0.0036, 0.0036)
	k4.shader_cirrus_position2 = Vector2(0.0036, 0.0036)
	k4.env_glow_intensity = 2.0
	k4.env_glow_bloom = 0.8
	k4.env_adjustment_saturation = 1.0
	k4.env_ambient_light_energy = 0.3
	k4.env_volumetric_fog_density = 0.02
	k4.env_volumetric_fog_anisotropy = 0.9
	k4.light_sun_energy = 0.0
	k4.light_moon_energy = 0.5
	k4.light_omni_energy = 1.2
	k4.light_night_energy = 0.1
	keyframes.append(k4)
	
	var k5 = LightingKeyframe.new()
	k5.state_name = "night"
	k5.time_range = Vector2(20.0, 4.0)
	k5.shader_atm_sun_intensity = 0.0
	k5.shader_sun_disk_intensity = 0.0
	k5.shader_atm_day_tint = Color(0.0, 0.0, 0.0, 1)
	k5.shader_atm_night_tint = Color(0.14, 0.39, 0.58, 1)
	k5.shader_starmap_color = Color(1.0, 1.0, 1.0, 1.0)
	k5.shader_star_scintillation = 0.9
	k5.shader_moon_size = 0.08
	k5.shader_atm_moon_mie_intensity = 0.5
	k5.shader_cumulus_position = Vector2(0.020, 0.020)
	k5.shader_cumulus_intensity = 0.3
	k5.shader_cumulus_coverage = 0.3
	k5.shader_cirrus_position1 = Vector2(0.0037, 0.0037)
	k5.shader_cirrus_position2 = Vector2(0.0037, 0.0037)
	k5.env_glow_intensity = 0.5
	k5.env_glow_bloom = 0.2
	k5.env_adjustment_saturation = 0.75
	k5.env_ambient_light_energy = 0.15
	k5.env_volumetric_fog_density = 0.015
	k5.env_volumetric_fog_sky_affect = 0.5
	k5.light_sun_energy = 0.0
	k5.light_moon_energy = 1.0
	k5.light_omni_energy = 1.5
	k5.light_night_energy = 0.3
	keyframes.append(k5)
	
	var k6 = LightingKeyframe.new()
	k6.state_name = "early_morning"
	k6.time_range = Vector2(4.0, 5.0)
	k6.shader_atm_sun_intensity = 2.0
	k6.shader_sun_disk_intensity = 0.0
	k6.shader_atm_day_tint = Color(0.50, 0.65, 0.85, 1)
	k6.shader_atm_night_tint = Color(0.10, 0.25, 0.40, 1)
	k6.shader_starmap_color = Color(0.8, 0.8, 0.8, 0.6)
	k6.shader_moon_size = 0.04
	k6.shader_cumulus_position = Vector2(0.0168, 0.0168)
	k6.shader_cumulus_intensity = 0.5
	k6.shader_cumulus_coverage = 0.40
	k6.shader_cirrus_position1 = Vector2(0.0033, 0.0033)
	k6.shader_cirrus_position2 = Vector2(0.0033, 0.0033)
	k6.env_glow_intensity = 0.6
	k6.env_glow_bloom = 0.15
	k6.env_adjustment_saturation = 0.9
	k6.env_ambient_light_energy = 0.2
	k6.light_sun_energy = 0.1
	k6.light_moon_energy = 0.3
	k6.light_omni_energy = 0.8
	k6.light_night_energy = 0.0
	keyframes.append(k6)

func _on_time_changed(time: float) -> void:
	var next_state = _get_current_keyframe_pair(time)

	if next_state.from_state != _current_from_state or next_state.to_state != _current_to_state:
		_start_transition(next_state.from_state, next_state.to_state, next_state.t)

func _get_current_keyframe_pair(time: float) -> Dictionary:
	var sorted_times: Array = []
	for k in keyframes:
		sorted_times.append({"kf": k, "start": k.time_range.x})
	sorted_times.sort_custom(func(a, b): return a["start"] < b["start"])

	var from_idx = 0
	for i in range(sorted_times.size()):
		if time >= sorted_times[i]["start"]:
			from_idx = i

	var to_idx = (from_idx + 1) % sorted_times.size()
	var from_kf = sorted_times[from_idx]["kf"]
	var to_kf = sorted_times[to_idx]["kf"]

	var from_start = from_kf.time_range.x
	var from_end = from_kf.time_range.y

	var segment_duration = from_end - from_start
	if to_idx == 0:
		segment_duration = (24.0 - from_start) + to_kf.time_range.x

	var t = fmod(time - from_start, 24.0) / segment_duration
	t = clamp(t, 0.0, 1.0)

	return {"from_state": from_kf, "to_state": to_kf, "t": t}

func _start_transition(from_state: LightingKeyframe, to_state: LightingKeyframe, t: float) -> void:
	if _transition_tween:
		_transition_tween.kill()

	_current_from_state = from_state
	_current_to_state = to_state
	_is_transitioning = true

	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(self, "_current_t", t, 2.5)
	_transition_tween.tween_callback(func(): _is_transitioning = false)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _environment or not _sky_material or not _time_of_day:
		return

	if _current_from_state and _current_to_state:
		_update_all_systems()

func _update_all_systems() -> void:
	var f = _current_from_state
	var t = _current_to_state
	var factor = _current_t

	_sky_material.set_shader_parameter("atm_sun_intensity", lerp(f.shader_atm_sun_intensity, t.shader_atm_sun_intensity, factor))
	_sky_material.set_shader_parameter("sun_disk_intensity", lerp(f.shader_sun_disk_intensity, t.shader_sun_disk_intensity, factor))
	_sky_material.set_shader_parameter("atm_day_tint", f.shader_atm_day_tint.lerp(t.shader_atm_day_tint, factor))
	_sky_material.set_shader_parameter("atm_horizon_light_tint", f.shader_atm_horizon_light_tint.lerp(t.shader_atm_horizon_light_tint, factor))
	_sky_material.set_shader_parameter("atm_night_tint", f.shader_atm_night_tint.lerp(t.shader_atm_night_tint, factor))
	_sky_material.set_shader_parameter("starmap_color", f.shader_starmap_color.lerp(t.shader_starmap_color, factor))
	_sky_material.set_shader_parameter("star_scintillation", lerp(f.shader_star_scintillation, t.shader_star_scintillation, factor))
	_sky_material.set_shader_parameter("moon_size", lerp(f.shader_moon_size, t.shader_moon_size, factor))
	_sky_material.set_shader_parameter("atm_moon_mie_intensity", lerp(f.shader_atm_moon_mie_intensity, t.shader_atm_moon_mie_intensity, factor))
	_sky_material.set_shader_parameter("cumulus_position", f.shader_cumulus_position.lerp(t.shader_cumulus_position, factor))
	_sky_material.set_shader_parameter("cumulus_intensity", lerp(f.shader_cumulus_intensity, t.shader_cumulus_intensity, factor))
	_sky_material.set_shader_parameter("cumulus_coverage", lerp(f.shader_cumulus_coverage, t.shader_cumulus_coverage, factor))
	_sky_material.set_shader_parameter("cirrus_position1", f.shader_cirrus_position1.lerp(t.shader_cirrus_position1, factor))
	_sky_material.set_shader_parameter("cirrus_position2", f.shader_cirrus_position2.lerp(t.shader_cirrus_position2, factor))

	_environment.glow_intensity = lerp(f.env_glow_intensity, t.env_glow_intensity, factor)
	_environment.glow_bloom = lerp(f.env_glow_bloom, t.env_glow_bloom, factor)
	_environment.adjustment_saturation = lerp(f.env_adjustment_saturation, t.env_adjustment_saturation, factor)
	_environment.ambient_light_energy = lerp(f.env_ambient_light_energy, t.env_ambient_light_energy, factor)
	
	if f.state_name == "dusk" or t.state_name == "dusk" or f.state_name == "night" or t.state_name == "night":
		_environment.volumetric_fog_density = lerp(f.env_volumetric_fog_density, t.env_volumetric_fog_density, factor)
		_environment.volumetric_fog_anisotropy = lerp(f.env_volumetric_fog_anisotropy, t.env_volumetric_fog_anisotropy, factor)
		_environment.volumetric_fog_sky_affect = lerp(f.env_volumetric_fog_sky_affect, t.env_volumetric_fog_sky_affect, factor)

	if _sun_light: _sun_light.light_energy = lerp(f.light_sun_energy, t.light_sun_energy, factor)
	if _moon_light: _moon_light.light_energy = lerp(f.light_moon_energy, t.light_moon_energy, factor)
	if _omni_light: _omni_light.light_energy = lerp(f.light_omni_energy, t.light_omni_energy, factor)
	if _night_light: _night_light.light_energy = lerp(f.light_night_energy, t.light_night_energy, factor)
