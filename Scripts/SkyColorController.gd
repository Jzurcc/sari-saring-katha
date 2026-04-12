extends Node

## SkyColorController — scalar-only edition.
##
## All colour tints are left at their Sky3D defaults so Rayleigh + Mie
## scattering can produce a physically-based sky naturally. Only the scalar
## properties that control brightness and atmospheric density are interpolated
## across the day/night cycle.

@export_node_path("Node") var sky_dome_path: NodePath = NodePath("../SkyDome")
@export_node_path("Node") var time_of_day_path: NodePath = NodePath("../TimeOfDay")

var _sky_dome: SkyDome
var _time_of_day: TimeOfDay

## ─── Scalar Phases ────────────────────────────────────────────────────────────
##
## atm_darkness   → how much the atmosphere darkens overall (higher = darker sky)
## atm_thickness  → atmospheric density / scattering saturation
## atm_sun_mie_intensity → strength of the halo/glow around the sun disk

const PHASES: Dictionary = {
	## 00:00 – 04:00 | True night — dark, dense atmosphere
	"midnight": {
		"atm_darkness":          0.76,
		"atm_thickness":         0.62,
		"atm_sun_mie_intensity": 0.3,
	},
	## 04:00 – 07:00 | Pre-dawn / sunrise — atmosphere thins and brightens
	"dawn": {
		"atm_darkness":          0.38,
		"atm_thickness":         0.55,
		"atm_sun_mie_intensity": 1.2,
	},
	## 07:00 – 11:00 | Morning — clear, crisp, moderate haze
	"morning": {
		"atm_darkness":          0.30,
		"atm_thickness":         0.50,
		"atm_sun_mie_intensity": 0.8,
	},
	## 11:00 – 13:00 | Noon — brightest point, thin atmosphere
	"noon": {
		"atm_darkness":          0.25,
		"atm_thickness":         0.45,
		"atm_sun_mie_intensity": 0.6,
	},
	## 13:00 – 15:00 | Afternoon — slightly hazier than noon
	"afternoon": {
		"atm_darkness":          0.32,
		"atm_thickness":         0.52,
		"atm_sun_mie_intensity": 0.8,
	},
	## 15:00 – 17:00 | Golden hour — thicker haze, strong sun glow
	"golden_hour": {
		"atm_darkness":          0.44,
		"atm_thickness":         0.62,
		"atm_sun_mie_intensity": 1.4,
	},
	## 17:00 – 19:30 | Dusk — dense atmosphere, sun glow fading
	"dusk": {
		"atm_darkness":          0.58,
		"atm_thickness":         0.72,
		"atm_sun_mie_intensity": 0.9,
	},
	## 19:30 – 24:00 | Night — dark, thick atmosphere, minimal glow
	"night": {
		"atm_darkness":          0.76,
		"atm_thickness":         0.62,
		"atm_sun_mie_intensity": 0.3,
	},
}

## ─── Transition Table ─────────────────────────────────────────────────────────
## [start_hour, end_hour, from_phase_key, to_phase_key]
const TRANSITIONS: Array = [
	[0.0,  4.0,  "midnight",    "midnight"],
	[4.0,  7.0,  "midnight",    "dawn"],
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
	_apply_scalars(_time_of_day.current_time)


func _apply_scalars(hour: float) -> void:
	for t: Array in TRANSITIONS:
		if hour >= t[0] and hour < t[1]:
			var progress: float = (hour - t[0]) / (t[1] - t[0])
			var from: Dictionary = PHASES[t[2]]
			var to:   Dictionary = PHASES[t[3]]
			_sky_dome.atm_darkness          = lerpf(from["atm_darkness"],          to["atm_darkness"],          progress)
			_sky_dome.atm_thickness         = lerpf(from["atm_thickness"],         to["atm_thickness"],         progress)
			_sky_dome.atm_sun_mie_intensity = lerpf(from["atm_sun_mie_intensity"], to["atm_sun_mie_intensity"], progress)
			return
