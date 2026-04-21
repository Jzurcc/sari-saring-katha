##
## TimeOfDayLighting: Cinematic Day-Night Lighting System
##
## This script manages a sophisticated lighting progression across a 24-hour in-game day.
## It smoothly transitions between keyframes defined in the 'keyframes' Export array.
##
extends Node

@export var environmental_omni_light: OmniLight3D = null
@export var wind_direction: Vector2 = Vector2(1, 0)
@export var wind_speed: float = 0.01
@export var keyframes: Array[LightingKeyframe] = []

# Reference to parent Environment for postprocessing updates
var _environment: Environment = null
var _sky_material: Material = null
var _sun_light: DirectionalLight3D = null
var _moon_light: DirectionalLight3D = null
var _exterior_lights: Array[Light3D] = []
var _night_light: DirectionalLight3D = null
var _time_of_day: Node = null

# Current interpolation state
var _current_from_state: LightingKeyframe = null
var _current_to_state: LightingKeyframe = null
var _current_t: float = 0.0
var _is_transitioning: bool = false
var _transition_tween: Tween = null
var _last_signal_time: float = -1.0
var _state_dirty: bool = true
var _sorted_keyframes: Array = []
var _cloud_time_offset: Vector2 = Vector2.ZERO

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

	# Target specific outdoor lights as requested
	var store_node = get_parent().get_parent()
	if store_node:
		var target_names = ["OutsideSpotLight3D", "OutsideOmniLight3D", "OutsideOmniLight3D2", "OutsideOmniLight3D3"]
		for light_name in target_names:
			var light = store_node.get_node_or_null(light_name)
			if light is Light3D:
				_exterior_lights.append(light)
			else:
				# Also try finding it recursively if it's deeper in the tree
				var found = store_node.find_child(light_name, true, false)
				if found is Light3D:
					_exterior_lights.append(found)

	if keyframes.is_empty():
		push_error("[TimeOfDayLighting] Keyframes array empty! Lighting system will not function correctly. Ensure keyframes are assigned in the Inspector.")
		
	_sorted_keyframes = []
	for k in keyframes:
		_sorted_keyframes.append({"kf": k, "start": k.time_range.x})
	_sorted_keyframes.sort_custom(func(a, b): return a["start"] < b["start"])

func _on_time_changed(time: float) -> void:
	var next_state = _get_current_keyframe_pair(time)
	
	# Jump detection
	var diff = abs(time - _last_signal_time)
	if _last_signal_time > time: # Midnight wrap logic
		diff = abs((time + 24.0) - _last_signal_time)
	
	var is_large_jump = diff > 0.1 and _last_signal_time >= 0.0
	var phase_changed = next_state.from_state != _current_from_state or next_state.to_state != _current_to_state
	
	if phase_changed or is_large_jump:
		_last_signal_time = time
		_start_transition(next_state.from_state, next_state.to_state, next_state.t)
	else:
		# Normal incremental tick: follow directly if not in a cinematic sweep.
		if not _is_transitioning:
			# Only update visually if time has moved significantly (approx 0.01 hours)
			if diff > 0.01:
				_current_from_state = next_state.from_state
				_current_to_state = next_state.to_state
				_current_t = next_state.t
				_last_signal_time = time
				_state_dirty = true

func _get_current_keyframe_pair(time: float) -> Dictionary:
	var from_idx = 0
	for i in range(_sorted_keyframes.size()):
		if time >= _sorted_keyframes[i]["start"]:
			from_idx = i

	var to_idx = (from_idx + 1) % _sorted_keyframes.size()
	var from_kf = _sorted_keyframes[from_idx]["kf"]
	var to_kf = _sorted_keyframes[to_idx]["kf"]

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
	_state_dirty = true

	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(self, "_current_t", t, 2.5)
	_transition_tween.tween_callback(func(): _is_transitioning = false)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _environment or not _sky_material or not _time_of_day:
		return

	_cloud_time_offset -= wind_direction * wind_speed * _delta

	if _current_from_state and _current_to_state:
		var f = _current_from_state
		var t = _current_to_state
		var factor = _current_t
		_sky_material.set_shader_parameter("cumulus_position", f.shader_cumulus_position.lerp(t.shader_cumulus_position, factor) + _cloud_time_offset)
		_sky_material.set_shader_parameter("cirrus_position1", f.shader_cirrus_position1.lerp(t.shader_cirrus_position1, factor) + _cloud_time_offset * 1.2)
		_sky_material.set_shader_parameter("cirrus_position2", f.shader_cirrus_position2.lerp(t.shader_cirrus_position2, factor) + _cloud_time_offset * 0.8)

	if not _state_dirty:
		return

	if _current_from_state and _current_to_state:
		_update_all_systems()
		if not _is_transitioning:
			_state_dirty = false

func _update_all_systems() -> void:
	var f = _current_from_state
	var t = _current_to_state
	var factor = _current_t

	_sky_material.set_shader_parameter("atm_sun_intensity", lerp(f.shader_atm_sun_intensity, t.shader_atm_sun_intensity, factor))
	_sky_material.set_shader_parameter("sun_disk_intensity", lerp(f.shader_sun_disk_intensity, t.shader_sun_disk_intensity, factor))
	_sky_material.set_shader_parameter("atm_darkness", lerp(f.atm_darkness, t.atm_darkness, factor))
	_sky_material.set_shader_parameter("atm_thickness", lerp(f.atm_thickness, t.atm_thickness, factor))
	_sky_material.set_shader_parameter("atm_sun_mie_intensity", lerp(f.atm_sun_mie_intensity, t.atm_sun_mie_intensity, factor))
	
	_sky_material.set_shader_parameter("atm_day_tint", f.shader_atm_day_tint.lerp(t.shader_atm_day_tint, factor))
	_sky_material.set_shader_parameter("atm_horizon_light_tint", f.shader_atm_horizon_light_tint.lerp(t.shader_atm_horizon_light_tint, factor))
	_sky_material.set_shader_parameter("atm_night_tint", f.shader_atm_night_tint.lerp(t.shader_atm_night_tint, factor))
	_sky_material.set_shader_parameter("starmap_color", f.shader_starmap_color.lerp(t.shader_starmap_color, factor))
	_sky_material.set_shader_parameter("star_scintillation", lerp(f.shader_star_scintillation, t.shader_star_scintillation, factor))
	_sky_material.set_shader_parameter("moon_size", lerp(f.shader_moon_size, t.shader_moon_size, factor))
	_sky_material.set_shader_parameter("atm_moon_mie_intensity", lerp(f.shader_atm_moon_mie_intensity, t.shader_atm_moon_mie_intensity, factor))
	_sky_material.set_shader_parameter("cumulus_intensity", lerp(f.shader_cumulus_intensity, t.shader_cumulus_intensity, factor))
	_sky_material.set_shader_parameter("cumulus_coverage", lerp(f.shader_cumulus_coverage, t.shader_cumulus_coverage, factor))

	var active_lut = f.env_color_correction if factor < 0.5 else t.env_color_correction
	if active_lut:
		_environment.adjustment_color_correction = active_lut
		_environment.adjustment_enabled = true
	else:
		_environment.adjustment_color_correction = null

	_environment.glow_intensity = lerp(f.env_glow_intensity, t.env_glow_intensity, factor)
	_environment.glow_bloom = lerp(f.env_glow_bloom, t.env_glow_bloom, factor)
	_environment.adjustment_saturation = lerp(f.env_adjustment_saturation, t.env_adjustment_saturation, factor)
	_environment.ambient_light_energy = lerp(f.env_ambient_light_energy, t.env_ambient_light_energy, factor)
	
	if f.state_name == "dusk" or t.state_name == "dusk" or f.state_name == "night" or t.state_name == "night":
		_environment.volumetric_fog_density = lerp(f.env_volumetric_fog_density, t.env_volumetric_fog_density, factor)
		_environment.volumetric_fog_anisotropy = lerp(f.env_volumetric_fog_anisotropy, t.env_volumetric_fog_anisotropy, factor)
		_environment.volumetric_fog_sky_affect = lerp(f.env_volumetric_fog_sky_affect, t.env_volumetric_fog_sky_affect, factor)

	if _sun_light: 
		_sun_light.light_energy = lerp(f.light_sun_energy, t.light_sun_energy, factor)
		_sun_light.light_volumetric_fog_energy = lerp(f.light_sun_volumetric_energy, t.light_sun_volumetric_energy, factor)
	if _moon_light: 
		_moon_light.light_energy = lerp(f.light_moon_energy, t.light_moon_energy, factor)
		_moon_light.light_volumetric_fog_energy = lerp(f.light_moon_volumetric_energy, t.light_moon_volumetric_energy, factor)
	for light in _exterior_lights:
		light.light_energy = lerp(f.light_omni_energy, t.light_omni_energy, factor)
	if _night_light: _night_light.light_energy = lerp(f.light_night_energy, t.light_night_energy, factor)
