class_name CustomerMotionProfile
extends Resource

## Modular movement, bobbing, opacity, and enter/exit sequence profile for a customer or story chapter.
## Attach to CustomerData.default_motion, CustomerData.alternate_motions,
## CustomerData.ambient_cameo_motions, or ChapterData.motion_override.

const MotionStepScript = preload("res://Scripts/Data/CustomerMotionStep.gd")

enum LocomotionStyle {
	WALK_BOUNCE,
	FLOAT_GLIDE,
	FLAP_HOVER,
	HEAVY_STOMP,
	SKIP_HOP,
	STILL,
}

@export var profile_name: String = ""

@export_group("Locomotion & Bobbing")
@export var locomotion_style: LocomotionStyle = LocomotionStyle.WALK_BOUNCE
@export var base_speed: float = 2.0
@export var bob_frequency: float = 10.0
@export var bob_amplitude: float = 0.08
@export var sway_amount: float = 0.05

@export_group("Idle Presence")
## Constant vertical lift while standing/hovering at the counter.
@export var idle_height_offset: float = 0.0
## Continuous bob amplitude while waiting at the counter (e.g. floating ghosts/flyers).
@export var idle_bob_amplitude: float = 0.0
@export var idle_bob_speed: float = 2.4
@export var idle_sway_amount: float = 0.0
@export_range(0.0, 1.0, 0.01) var idle_opacity: float = 1.0
## Optional slow opacity pulsing while idle at the counter (active when pulse_speed > 0 and max > min).
@export_range(0.0, 1.0, 0.01) var idle_opacity_pulse_min: float = 1.0
@export_range(0.0, 1.0, 0.01) var idle_opacity_pulse_max: float = 1.0
@export var idle_opacity_pulse_speed: float = 0.0
## If false, skips the squash-and-stretch landing thud on arrival (ideal for ghosts/flyers).
@export var play_landing_thud: bool = true

@export_group("Start State")
## When true, teleports the customer to start_anchor + start_offset at spawn instead of SpawnPos.
@export var override_start_anchor: bool = false
@export var start_anchor: MotionStepScript.Anchor = MotionStepScript.Anchor.SPAWN
@export var start_offset: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0, 0.01) var start_opacity: float = 0.0

@export_group("Sequences")
## Ordered steps played when entering the store (or during an ambient cameo).
## Leave empty to use the standard walk-in + fade-in.
@export var enter_steps: Array[MotionStepScript] = []
## Ordered steps played when leaving the store.
## Leave empty to use the standard step-back behind neighbors + walk to exit + fade-out.
@export var exit_steps: Array[MotionStepScript] = []
## If true, custom exit_steps skip the automatic ground step-back behind waiting neighbors.
@export var bypass_default_exit_stepback: bool = false
## Relative weight when choosing randomly among alternate_motions or ambient_cameo_motions.
@export_range(0.05, 5.0, 0.05) var selection_weight: float = 1.0
