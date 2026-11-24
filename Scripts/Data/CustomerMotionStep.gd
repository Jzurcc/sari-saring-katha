class_name CustomerMotionStep
extends Resource

## A single composable waypoint/keyframe in a customer's entrance, exit, or ambient cameo motion.
## Offsets are expressed in storefront-relative space so every step works across all counter slots:
##   local_offset.x -> lateral along counter (+left, -right from player POV)
##   local_offset.y -> vertical height (+up into sky)
##   local_offset.z -> forward toward counter (+past/through counter into shop, -further into street)

enum Anchor {
	SPAWN,
	APPROACH_MIDPOINT,
	COUNTER_SLOT,
	BEHIND_COUNTER,
	EXIT,
	STREET_LEFT,
	STREET_RIGHT,
	CURRENT,
}

@export var anchor: Anchor = Anchor.COUNTER_SLOT
@export var local_offset: Vector3 = Vector3.ZERO

## If > 0, travels to this waypoint in an exact duration (seconds) using transition/ease_type.
## If <= 0, travels at (profile.base_speed * speed_multiplier) meters/second.
@export var duration: float = 0.0
@export var speed_multiplier: float = 1.0
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

## Extra parabolic Y arc added during travel (sin(t * PI) * height_arc). Great for swoops/hops.
@export var height_arc: float = 0.0

## Target sprite alpha (0.0..1.0) to smoothly interpolate to over this step. -1.0 keeps current alpha.
@export_range(-1.0, 1.0, 0.01) var target_opacity: float = -1.0
## Fraction of the step duration over which opacity completes its fade (e.g. 0.15 = fast fade).
@export_range(0.05, 1.0, 0.05) var opacity_fade_fraction: float = 1.0
## If true, holds start opacity until the final `opacity_fade_fraction` of the step (ideal for fade-outs at screen edge).
@export var opacity_fade_at_end: bool = false

## Optional pauses before and after reaching this waypoint (seconds).
@export var pause_before: float = 0.0
@export var pause_after: float = 0.0
## Random extra seconds (0..pause_random_extra) added to pause_after for organic hesitation.
@export var pause_random_extra: float = 0.0

## Whether the profile's locomotion bobbing/sway plays while moving through this step.
@export var use_locomotion_bob: bool = true

## Optional sprite scale multiplier applied smoothly during this step (Vector3.ONE = normal).
@export var scale_multiplier: Vector3 = Vector3.ONE
