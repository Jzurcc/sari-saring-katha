##
## TimeOfDayLighting: Cinematic Day-Night Lighting System
##
## This script manages a sophisticated lighting progression across a 24-hour in-game day.
## It smoothly transitions between 6 key mood states using interpolated shader parameters,
## postprocessing effects, and dynamic light energy adjustments.
##
## Keyframes:
## - Sunrise (5-7 AM): Warm orange, soft shadows, low glow
## - Midday (10 AM-3 PM): Neutral white-blue, sharp shadows, clean look
## - Golden Hour (4-5 PM): Rich amber, long shadows, high glow
## - Dusk (6-7 PM): Cool purple-blue, stars visible, maximum bloom
## - Night (8 PM-4 AM): Cool moonlight, stars, deep shadows
## - Early Morning (4-5 AM): Pre-dawn cool blue, stars fading
##
## Connection Flow:
## 1. Listens to TimeOfDay.time_changed signal
## 2. Determines current and next keyframe
## 3. Calculates interpolation factor (0-1)
## 4. Updates shader parameters, environment, and lights every frame
## 5. Smooth 2.5-second tween blends between states
##
## Setup:
## - Attach this script to the Sky3D (WorldEnvironment) node in MainGame.tscn
## - Ensure TimeOfDay, SunLight, MoonLight, NightLight, and OmniLight nodes exist
##
@tool
extends Node

# Reference to parent Environment for postprocessing updates
var _environment: Environment = null
var _sky_material: Material = null
var _sun_light: DirectionalLight3D = null
var _moon_light: DirectionalLight3D = null
var _omni_light: OmniLight3D = null
var _night_light: DirectionalLight3D = null
var _time_of_day: TimeOfDay = null

# Current interpolation state
var _current_from_state: String = ""
var _current_to_state: String = ""
var _current_t: float = 0.0
var _is_transitioning: bool = false
var _transition_tween: Tween = null

# Keyframe definition: each state has shader params, environment params, and light params
var _keyframes: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Find sibling nodes
	var parent = get_parent()
	if parent is WorldEnvironment:
		_environment = parent.environment
		if _environment:
			_sky_material = _environment.sky.sky_material

	# Find TimeOfDay sibling
	_time_of_day = get_parent().get_node_or_null("TimeOfDay")

	# Find lights
	_sun_light = get_parent().get_node_or_null("SunLight")
	_moon_light = get_parent().get_node_or_null("MoonLight")
	_night_light = get_parent().get_node_or_null("NightLight")

	# Find OmniLight (store light) — search in parent of parent
	var store_node = get_parent().get_parent()
	if store_node:
		var lights = store_node.find_children("*", "OmniLight3D")
		if lights.size() > 0:
			_omni_light = lights[0]

	# Initialize keyframes
	_initialize_keyframes()

	# Connect to time signals
	if _time_of_day:
		_time_of_day.time_changed.connect(_on_time_changed)
		# Set initial state
		_on_time_changed(_time_of_day.current_time)

func _initialize_keyframes() -> void:
	# Define 6 mood states with complete shader, environment, and light parameters.
	# Each state contains a time_range (start, end), shader parameters for atmospheric effects,
	# environment settings for postprocessing, and light energy values.
	# The system will smoothly interpolate between adjacent keyframes as in-game time progresses.
	_keyframes = {
		"sunrise": {
			"time_range": Vector2(5.0, 7.0),
			"shader": {
				"atm_sun_intensity": 8.0,
				"sun_disk_intensity": 15.0,
				"atm_day_tint": Color(0.95, 0.85, 0.70, 1),
				"atm_horizon_light_tint": Color(1.0, 0.70, 0.40, 1),
				"starmap_color": Color(0.5, 0.5, 0.5, 0.3),
				"moon_size": 0.07,
				"cumulus_position": Vector2(0.016734878, 0.016734878),
				"cumulus_intensity": 0.6,
				"cumulus_coverage": 0.55,
				"cirrus_position1": Vector2(0.0033469682, 0.0033469682),
				"cirrus_position2": Vector2(0.0033469682, 0.0033469682),
			},
			"environment": {
				"glow_intensity": 0.8,
				"glow_bloom": 0.25,
				"adjustment_saturation": 1.0,
				"ambient_light_energy": 0.4,
			},
			"lights": {
				"sun_energy": 0.4,
				"moon_energy": 0.0,
				"omni_energy": 0.3,
				"night_energy": 0.0,
			}
		},
		"midday": {
			"time_range": Vector2(10.0, 15.0),
			"shader": {
				"atm_sun_intensity": 18.0,
				"sun_disk_intensity": 30.0,
				"atm_day_tint": Color(0.81, 0.91, 1.0, 1),
				"atm_horizon_light_tint": Color(0.98, 0.64, 0.46, 1),
				"starmap_color": Color(0.7, 0.7, 0.7, 0.0),
				"moon_size": 0.0,
				"cumulus_position": Vector2(0.017, 0.017),
				"cumulus_intensity": 0.6,
				"cumulus_coverage": 0.55,
				"cirrus_position1": Vector2(0.0034, 0.0034),
				"cirrus_position2": Vector2(0.0034, 0.0034),
			},
			"environment": {
				"glow_intensity": 1.0,
				"glow_bloom": 0.15,
				"adjustment_saturation": 1.2,
				"ambient_light_energy": 0.8,
			},
			"lights": {
				"sun_energy": 0.8,
				"moon_energy": 0.0,
				"omni_energy": 0.0,
				"night_energy": 0.0,
			}
		},
		"golden_hour": {
			"time_range": Vector2(16.0, 17.5),
			"shader": {
				"atm_sun_intensity": 12.0,
				"sun_disk_intensity": 25.0,
				"atm_day_tint": Color(1.0, 0.88, 0.65, 1),
				"atm_horizon_light_tint": Color(1.0, 0.75, 0.30, 1),
				"starmap_color": Color(0.7, 0.7, 0.7, 0.1),
				"moon_size": 0.04,
				"cumulus_position": Vector2(0.018, 0.018),
				"cumulus_intensity": 0.7,
				"cumulus_coverage": 0.45,
				"cirrus_position1": Vector2(0.0035, 0.0035),
				"cirrus_position2": Vector2(0.0035, 0.0035),
			},
			"environment": {
				"glow_intensity": 1.8,
				"glow_bloom": 0.6,
				"adjustment_saturation": 1.4,
				"ambient_light_energy": 0.65,
			},
			"lights": {
				"sun_energy": 0.65,
				"moon_energy": 0.0,
				"omni_energy": 0.5,
				"night_energy": 0.0,
			}
		},
		"dusk": {
			"time_range": Vector2(18.0, 19.5),
			"shader": {
				"atm_sun_intensity": 4.0,
				"sun_disk_intensity": 0.0,
				"atm_day_tint": Color(0.60, 0.75, 1.0, 1),
				"atm_horizon_light_tint": Color(0.40, 0.30, 0.60, 1),
				"starmap_color": Color(0.8, 0.8, 0.8, 0.5),
				"moon_size": 0.07,
				"atm_moon_mie_intensity": 0.3,
				"cumulus_position": Vector2(0.019, 0.019),
				"cumulus_intensity": 0.8,
				"cumulus_coverage": 0.6,
				"cirrus_position1": Vector2(0.0036, 0.0036),
				"cirrus_position2": Vector2(0.0036, 0.0036),
			},
			"environment": {
				"glow_intensity": 2.0,
				"glow_bloom": 0.8,
				"adjustment_saturation": 1.0,
				"ambient_light_energy": 0.3,
				"volumetric_fog_density": 0.02,
				"volumetric_fog_anisotropy": 0.9,
			},
			"lights": {
				"sun_energy": 0.0,
				"moon_energy": 0.5,
				"omni_energy": 1.2,
				"night_energy": 0.1,
			}
		},
		"night": {
			"time_range": Vector2(20.0, 4.0),
			"shader": {
				"atm_sun_intensity": 0.0,
				"sun_disk_intensity": 0.0,
				"atm_day_tint": Color(0.0, 0.0, 0.0, 1),
				"atm_night_tint": Color(0.14, 0.39, 0.58, 1),
				"starmap_color": Color(1.0, 1.0, 1.0, 1.0),
				"star_scintillation": 0.9,
				"moon_size": 0.08,
				"atm_moon_mie_intensity": 0.5,
				"cumulus_position": Vector2(0.020, 0.020),
				"cumulus_intensity": 0.3,
				"cumulus_coverage": 0.3,
				"cirrus_position1": Vector2(0.0037, 0.0037),
				"cirrus_position2": Vector2(0.0037, 0.0037),
			},
			"environment": {
				"glow_intensity": 0.5,
				"glow_bloom": 0.2,
				"adjustment_saturation": 0.75,
				"ambient_light_energy": 0.15,
				"volumetric_fog_density": 0.015,
				"volumetric_fog_sky_affect": 0.5,
			},
			"lights": {
				"sun_energy": 0.0,
				"moon_energy": 1.0,
				"omni_energy": 1.5,
				"night_energy": 0.3,
			}
		},
		"early_morning": {
			"time_range": Vector2(4.0, 5.0),
			"shader": {
				"atm_sun_intensity": 2.0,
				"sun_disk_intensity": 0.0,
				"atm_day_tint": Color(0.50, 0.65, 0.85, 1),
				"atm_night_tint": Color(0.10, 0.25, 0.40, 1),
				"starmap_color": Color(0.8, 0.8, 0.8, 0.6),
				"moon_size": 0.04,
				"cumulus_position": Vector2(0.0168, 0.0168),
				"cumulus_intensity": 0.5,
				"cumulus_coverage": 0.40,
				"cirrus_position1": Vector2(0.0033, 0.0033),
				"cirrus_position2": Vector2(0.0033, 0.0033),
			},
			"environment": {
				"glow_intensity": 0.6,
				"glow_bloom": 0.15,
				"adjustment_saturation": 0.9,
				"ambient_light_energy": 0.2,
			},
			"lights": {
				"sun_energy": 0.1,
				"moon_energy": 0.3,
				"omni_energy": 0.8,
				"night_energy": 0.0,
			}
		},
	}

func _on_time_changed(time: float) -> void:
	# Triggered by TimeOfDay.time_changed signal each frame.
	# Determines which two keyframes to interpolate between based on current time.
	# If state transition detected, starts a smooth tween blend.
	# Determine which keyframes we're between
	var next_state = _get_current_keyframe_pair(time)

	if next_state.from_state != _current_from_state or next_state.to_state != _current_to_state:
		# State transition detected, start tween
		_start_transition(next_state.from_state, next_state.to_state, next_state.t)

func _get_current_keyframe_pair(time: float) -> Dictionary:
	# Given the current in-game time (0-24 hours), determines:
	# - from_state: the current keyframe we're leaving
	# - to_state: the next keyframe we're entering
	# - t: interpolation factor (0-1) within the current segment
	# Handles wrapping around midnight correctly.
	# Returns a dictionary: {"from_state": str, "to_state": str, "t": float}

	# Determine which two keyframes to interpolate between
	# Returns {"from_state": str, "to_state": str, "t": float(0-1)}

	var sorted_times: Array = []
	for state_name in _keyframes.keys():
		sorted_times.append({"name": state_name, "start": _keyframes[state_name]["time_range"].x})
	sorted_times.sort_custom(func(a, b): return a["start"] < b["start"])

	# Find the current segment
	var from_idx = 0
	for i in range(sorted_times.size()):
		if time >= sorted_times[i]["start"]:
			from_idx = i

	var to_idx = (from_idx + 1) % sorted_times.size()
	var from_name = sorted_times[from_idx]["name"]
	var to_name = sorted_times[to_idx]["name"]

	var from_start = _keyframes[from_name]["time_range"].x
	var from_end = _keyframes[from_name]["time_range"].y

	# Calculate t (0-1) within this segment
	var segment_duration = from_end - from_start
	if to_idx == 0:
		# Wrapping around midnight
		segment_duration = (24.0 - from_start) + _keyframes[to_name]["time_range"].x

	var t = fmod(time - from_start, 24.0) / segment_duration
	t = clamp(t, 0.0, 1.0)

	return {"from_state": from_name, "to_state": to_name, "t": t}

func _start_transition(from_state: String, to_state: String, t: float) -> void:
	# Initiates a smooth 2.5-second tween blend from current state to next state.
	# Kills any previous tween to prevent overlap.
	# Updates _current_t from 0 to the target interpolation factor smoothly.
	# Kill previous tween if running
	if _transition_tween:
		_transition_tween.kill()

	_current_from_state = from_state
	_current_to_state = to_state
	_is_transitioning = true

	# Smooth tween over 2.5 seconds
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(self, "_current_t", t, 2.5)
	_transition_tween.tween_callback(func(): _is_transitioning = false)

func _process(_delta: float) -> void:
	# Called every frame. Updates all lighting systems based on current interpolation state.
	# Only runs in-game (not in editor). Requires all systems to be initialized.
	if Engine.is_editor_hint():
		return

	if not _environment or not _sky_material or not _time_of_day:
		return

	# Update all layers based on current interpolation state
	_update_all_systems()

func _update_all_systems() -> void:
	# Orchestrates updates to all three layers:
	# 1. Shader parameters (atmospheric effects, sky colors, lighting)
	# 2. Environment (postprocessing: glow, bloom, saturation, volumetric effects)
	# 3. Lights (DirectionalLights for sun/moon, OmniLight for store, NightLight for ambient)
	if _current_from_state.is_empty():
		return

	var from_params = _keyframes[_current_from_state]
	var to_params = _keyframes[_current_to_state]

	_update_shader_parameters(from_params, to_params, _current_t)
	_update_environment(from_params, to_params, _current_t)
	_update_lights(from_params, to_params, _current_t)

func _update_shader_parameters(from_params: Dictionary, to_params: Dictionary, t: float) -> void:
	# Interpolates shader parameters between from_params and to_params using factor t.
	# Handles multiple parameter types (floats, colors, vectors).
	# Updates the Sky3D material in real-time.
	var from_shader = from_params["shader"]
	var to_shader = to_params["shader"]

	for param in from_shader.keys():
		var from_val = from_shader[param]
		var to_val = to_shader.get(param, from_val)

		var interpolated = _interpolate_value(from_val, to_val, t)
		_sky_material.set_shader_parameter(param, interpolated)

func _update_environment(from_params: Dictionary, to_params: Dictionary, t: float) -> void:
	# Interpolates postprocessing environment parameters.
	# Dynamically adjusts glow, bloom, saturation, fog, and ambient light
	# to enhance mood and visual quality at each time of day.
	var from_env = from_params["environment"]
	var to_env = to_params["environment"]

	for param in from_env.keys():
		var from_val = from_env[param]
		var to_val = to_env.get(param, from_val)

		var interpolated = _interpolate_value(from_val, to_val, t)

		# Set on environment
		match param:
			"glow_intensity":
				_environment.glow_intensity = interpolated
			"glow_bloom":
				_environment.glow_bloom = interpolated
			"adjustment_saturation":
				_environment.adjustment_saturation = interpolated
			"ambient_light_energy":
				_environment.ambient_light_energy = interpolated
			"volumetric_fog_density":
				_environment.volumetric_fog_density = interpolated
			"volumetric_fog_anisotropy":
				_environment.volumetric_fog_anisotropy = interpolated
			"volumetric_fog_sky_affect":
				_environment.volumetric_fog_sky_affect = interpolated

func _update_lights(from_params: Dictionary, to_params: Dictionary, t: float) -> void:
	# Interpolates light energies for:
	# - SunLight: dominant during day, fades at dusk/night
	# - MoonLight: inactive during day, increases at dusk/night
	# - OmniLight: store interior light, off at day, full at night
	# - NightLight: ambient blue moonlight, active only at night
	var from_lights = from_params["lights"]
	var to_lights = to_params["lights"]

	# Sun light
	if _sun_light:
		var from_sun = from_lights.get("sun_energy", 0.0)
		var to_sun = to_lights.get("sun_energy", 0.0)
		_sun_light.light_energy = _interpolate_value(from_sun, to_sun, t)

	# Moon light
	if _moon_light:
		var from_moon = from_lights.get("moon_energy", 0.0)
		var to_moon = to_lights.get("moon_energy", 0.0)
		_moon_light.light_energy = _interpolate_value(from_moon, to_moon, t)

	# Omni light (store light)
	if _omni_light:
		var from_omni = from_lights.get("omni_energy", 0.0)
		var to_omni = to_lights.get("omni_energy", 0.0)
		_omni_light.light_energy = _interpolate_value(from_omni, to_omni, t)

	# Night light
	if _night_light:
		var from_night = from_lights.get("night_energy", 0.0)
		var to_night = to_lights.get("night_energy", 0.0)
		_night_light.light_energy = _interpolate_value(from_night, to_night, t)

func _interpolate_value(from_val, to_val, t: float):
	# Generic interpolation handler supporting multiple types:
	# - Color: RGBA lerp
	# - float/int: numeric lerp
	# - Vector2/Vector3: component-wise lerp
	# Falls back to target value for unknown types.
	if from_val is Color:
		return from_val.lerp(to_val, t)
	elif from_val is float or from_val is int:
		return lerp(from_val, to_val, t)
	elif from_val is Vector2:
		return from_val.lerp(to_val, t)
	elif from_val is Vector3:
		return from_val.lerp(to_val, t)
	else:
		return to_val  # Fallback: use target value
