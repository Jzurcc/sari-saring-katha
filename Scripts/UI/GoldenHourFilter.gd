extends ColorRect

## Controls this node's alpha based on time of day.
## Full opacity during daylight, fades to invisible at dusk and stays
## transparent through night and midnight, then returns from dawn.

## Path to the Sky3D instanced scene to read current_time from.
@export_node_path("Node") var sky3d_path: NodePath = NodePath("../../Sky3D")

## The base warm tint — only alpha is driven by time.
const FILTER_COLOR := Color(1, 0.55, 0.1, 1.0)

## Full opacity (daytime).
const ALPHA_DAY   := 0.15
## Invisible (night / midnight).
const ALPHA_NIGHT := 0.0

var _sky3d: Node


func _ready() -> void:
	_sky3d = get_node_or_null(sky3d_path)
	if not _sky3d:
		push_warning("[GoldenHourFilter] Could not find Sky3D at: %s" % sky3d_path)


func _process(_delta: float) -> void:
	if not _sky3d:
		return
	var c := FILTER_COLOR
	c.a = _get_alpha(_sky3d.current_time)
	color = c


func _get_alpha(hour: float) -> float:
	## Midnight (0 – 5): fully transparent
	if hour < 5.0:
		return ALPHA_NIGHT

	## Dawn (5 – 7): fade in
	if hour < 7.0:
		return lerpf(ALPHA_NIGHT, ALPHA_DAY, (hour - 5.0) / 2.0)

	## Morning through afternoon (7 – 15): full filter
	if hour < 15.0:
		return ALPHA_DAY

	## Golden hour (15 – 17): fade out — hits 0 exactly at dusk
	if hour < 17.0:
		return lerpf(ALPHA_DAY, ALPHA_NIGHT, (hour - 15.0) / 2.0)

	## Dusk, night (17 – 24): fully transparent
	return ALPHA_NIGHT
