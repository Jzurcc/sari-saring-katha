class_name LightingKeyframe
extends Resource

@export var state_name: String
@export var time_range: Vector2

@export_group("Shader Parameters")
@export var shader_atm_sun_intensity: float
@export var shader_sun_disk_intensity: float
@export var shader_atm_day_tint: Color
@export var shader_atm_horizon_light_tint: Color
@export var shader_atm_night_tint: Color = Color.TRANSPARENT
@export var shader_starmap_color: Color
@export var shader_star_scintillation: float = 0.75
@export var shader_moon_size: float
@export var shader_atm_moon_mie_intensity: float = 0.0

@export_subgroup("Shader Clouds")
@export var shader_cumulus_position: Vector2
@export var shader_cumulus_intensity: float
@export var shader_cumulus_coverage: float
@export var shader_cirrus_position1: Vector2
@export var shader_cirrus_position2: Vector2

@export_group("Environment Parameters")
@export var env_glow_intensity: float
@export var env_glow_bloom: float
@export var env_adjustment_saturation: float
@export var env_ambient_light_energy: float
@export var env_volumetric_fog_density: float = 0.01
@export var env_volumetric_fog_anisotropy: float = 0.7
@export var env_volumetric_fog_sky_affect: float = 0.295

@export_group("Light Energies")
@export var light_sun_energy: float
@export var light_moon_energy: float
@export var light_omni_energy: float
@export var light_night_energy: float
