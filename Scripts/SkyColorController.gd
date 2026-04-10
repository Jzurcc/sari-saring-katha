extends Node

## SkyColorController dynamically applies stylized color palettes to the SkyDome
## based on the current time of day, smoothly interpolating between each phase.

@export_node_path("Node") var sky_dome_path: NodePath = NodePath("../SkyDome")
@export_node_path("Node") var time_of_day_path: NodePath = NodePath("../TimeOfDay")

var _sky_dome: SkyDome
var _time_of_day: TimeOfDay

## ─── Color Palettes Per Time Phase ────────────────────────────────────────────
##
## atm_day_tint           → sky color at the zenith
## atm_horizon_light_tint → glowing color at the horizon near the sun
## atm_night_tint         → base tint of the nighttime atmosphere
## sun_light_color        → DirectionalLight color at zenith
## sun_horizon_light_color→ DirectionalLight color when near the horizon
## atm_sun_mie_tint       → color of the halo/glow around the sun disk
## atm_sun_mie_intensity  → strength of that halo
## atm_darkness           → how much the atmosphere darkens
## atm_thickness          → atmospheric density / scattering saturation

const PALETTES: Dictionary = {
	## 00:00 – 05:00 | Midnight — deep navy, cold, still
	"midnight": {
		"atm_day_tint":            Color(0.07, 0.08, 0.20),
		"atm_horizon_light_tint":  Color(0.12, 0.10, 0.28),
		"atm_night_tint":          Color(0.04, 0.04, 0.12),
		"sun_light_color":         Color(0.85, 0.88, 1.0),
		"sun_horizon_light_color": Color(0.72, 0.60, 0.90),
		"atm_sun_mie_tint":        Color(0.70, 0.75, 1.0),
		"atm_sun_mie_intensity":   0.5,
		"atm_darkness":            0.68,
		"atm_thickness":           0.70,
	},
	## 05:00 – 07:00 | Dawn — lavender blush, rose horizon
	"dawn": {
		"atm_day_tint":            Color(0.80, 0.68, 0.90),
		"atm_horizon_light_tint":  Color(0.98, 0.62, 0.58),
		"atm_night_tint":          Color(0.07, 0.05, 0.14),
		"sun_light_color":         Color(1.0, 0.88, 0.80),
		"sun_horizon_light_color": Color(0.98, 0.60, 0.52),
		"atm_sun_mie_tint":        Color(1.0, 0.78, 0.70),
		"atm_sun_mie_intensity":   1.2,
		"atm_darkness":            0.55,
		"atm_thickness":           0.72,
	},
	## 07:00 – 11:00 | Morning — crisp blue sky, gentle gold
	"morning": {
		"atm_day_tint":            Color(0.72, 0.86, 1.0),
		"atm_horizon_light_tint":  Color(0.98, 0.80, 0.60),
		"atm_night_tint":          Color(0.05, 0.05, 0.12),
		"sun_light_color":         Color(1.0, 0.97, 0.90),
		"sun_horizon_light_color": Color(0.98, 0.72, 0.52),
		"atm_sun_mie_tint":        Color(1.0, 0.92, 0.78),
		"atm_sun_mie_intensity":   1.0,
		"atm_darkness":            0.48,
		"atm_thickness":           0.66,
	},
	## 11:00 – 13:00 | Noon — vivid azure sky, crisp high-sun clarity
	"noon": {
		"atm_day_tint":            Color(0.58, 0.80, 1.0),
		"atm_horizon_light_tint":  Color(0.82, 0.82, 0.78),
		"atm_night_tint":          Color(0.05, 0.05, 0.12),
		"sun_light_color":         Color(1.0, 0.98, 0.96),
		"sun_horizon_light_color": Color(0.95, 0.78, 0.58),
		"atm_sun_mie_tint":        Color(1.0, 1.0, 1.0),
		"atm_sun_mie_intensity":   0.8,
		"atm_darkness":            0.42,
		"atm_thickness":           0.60,
	},
	## 13:00 – 15:00 | Afternoon — warm creamy white, honey easing into gold
	"afternoon": {
		"atm_day_tint":            Color(0.90, 0.84, 0.70),
		"atm_horizon_light_tint":  Color(0.98, 0.74, 0.50),
		"atm_night_tint":          Color(0.05, 0.05, 0.12),
		"sun_light_color":         Color(1.0, 0.95, 0.80),
		"sun_horizon_light_color": Color(0.98, 0.68, 0.42),
		"atm_sun_mie_tint":        Color(1.0, 0.92, 0.68),
		"atm_sun_mie_intensity":   1.0,
		"atm_darkness":            0.52,
		"atm_thickness":           0.70,
	},
	## 15:00 – 17:00 | Golden Hour — warm cinematic amber, iconic golden light
	"golden_hour": {
		"atm_day_tint":            Color(0.95, 0.72, 0.48),
		"atm_horizon_light_tint":  Color(0.98, 0.60, 0.28),
		"atm_night_tint":          Color(0.05, 0.05, 0.12),
		"sun_light_color":         Color(1.0, 0.82, 0.52),
		"sun_horizon_light_color": Color(1.0, 0.65, 0.32),
		"atm_sun_mie_tint":        Color(1.0, 0.75, 0.40),
		"atm_sun_mie_intensity":   1.4,
		"atm_darkness":            0.58,
		"atm_thickness":           0.78,
	},
	## 18:00 – 19:30 | Dusk — deep indigo twilight, violet horizon
	"dusk": {
		"atm_day_tint":            Color(0.28, 0.24, 0.58),
		"atm_horizon_light_tint":  Color(0.42, 0.28, 0.72),
		"atm_night_tint":          Color(0.05, 0.04, 0.15),
		"sun_light_color":         Color(0.58, 0.52, 0.92),
		"sun_horizon_light_color": Color(0.48, 0.38, 0.82),
		"atm_sun_mie_tint":        Color(0.62, 0.48, 0.92),
		"atm_sun_mie_intensity":   1.1,
		"atm_darkness":            0.65,
		"atm_thickness":           0.85,
	},
	## 20:30 – 24:00 | Night — deep indigo, soft moonlit blue
	"night": {
		"atm_day_tint":            Color(0.08, 0.09, 0.22),
		"atm_horizon_light_tint":  Color(0.15, 0.12, 0.32),
		"atm_night_tint":          Color(0.04, 0.04, 0.12),
		"sun_light_color":         Color(0.85, 0.88, 1.0),
		"sun_horizon_light_color": Color(0.72, 0.60, 0.88),
		"atm_sun_mie_tint":        Color(0.70, 0.75, 1.0),
		"atm_sun_mie_intensity":   0.5,
		"atm_darkness":            0.68,
		"atm_thickness":           0.70,
	},
}

## ─── Transition Table ──────────────────────────────────────────────────────────
## Each entry: [start_hour, end_hour, from_palette_key, to_palette_key]
const TRANSITIONS: Array = [
	[0.0,  5.0,  "midnight",    "midnight"],
	[5.0,  7.0,  "midnight",    "dawn"],
	[7.0,  11.0, "dawn",        "morning"],
	[11.0, 13.0, "morning",     "noon"],
	[13.0, 15.0, "noon",        "afternoon"],
	[15.0, 17.0, "afternoon",   "golden_hour"],
	[17.0, 19.5, "golden_hour", "dusk"],
	[19.5, 24.0, "dusk",        "night"],
]


func _ready() -> void:
	_sky_dome = get_node_or_null(sky_dome_path) as SkyDome
	_time_of_day = get_node_or_null(time_of_day_path) as TimeOfDay
	if not _sky_dome:
		push_warning("[SkyColorController] Could not find SkyDome at: %s" % sky_dome_path)
	if not _time_of_day:
		push_warning("[SkyColorController] Could not find TimeOfDay at: %s" % time_of_day_path)


func _process(_delta: float) -> void:
	if not _sky_dome or not _time_of_day:
		return
	_apply_palette(_time_of_day.current_time)


func _apply_palette(hour: float) -> void:
	for t: Array in TRANSITIONS:
		if hour >= t[0] and hour < t[1]:
			var progress: float = (hour - t[0]) / (t[1] - t[0])
			var from: Dictionary = PALETTES[t[2]]
			var to: Dictionary   = PALETTES[t[3]]
			_sky_dome.atm_day_tint            = from["atm_day_tint"].lerp(to["atm_day_tint"], progress)
			_sky_dome.atm_horizon_light_tint  = from["atm_horizon_light_tint"].lerp(to["atm_horizon_light_tint"], progress)
			_sky_dome.atm_night_tint          = from["atm_night_tint"].lerp(to["atm_night_tint"], progress)
			_sky_dome.sun_light_color         = from["sun_light_color"].lerp(to["sun_light_color"], progress)
			_sky_dome.sun_horizon_light_color = from["sun_horizon_light_color"].lerp(to["sun_horizon_light_color"], progress)
			_sky_dome.atm_sun_mie_tint        = from["atm_sun_mie_tint"].lerp(to["atm_sun_mie_tint"], progress)
			_sky_dome.atm_sun_mie_intensity   = lerpf(from["atm_sun_mie_intensity"], to["atm_sun_mie_intensity"], progress)
			_sky_dome.atm_darkness            = lerpf(from["atm_darkness"], to["atm_darkness"], progress)
			_sky_dome.atm_thickness           = lerpf(from["atm_thickness"], to["atm_thickness"], progress)
			return
