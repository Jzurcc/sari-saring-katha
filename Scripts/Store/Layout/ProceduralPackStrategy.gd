class_name ProceduralPackStrategy
extends LayoutStrategy
 
## Left-to-right procedural bin-packing layout strategy for shelf surfaces.
##
## Items are packed from left to right using each item's real-world width
## (derived from [member ItemData.display_height_meters] and texture aspect ratio).
## Packing stops when the shelf runs out of room or [param max_items] is reached.
##
## Each item receives:
## - A unique X position (packed left edge + half-width)
## - A random Z offset for depth variance (front/back on the shelf)
## - A Z-axis roll (tilt) composed of random variance + per-item preference
##
## NOTE: Tilt is encoded in the transform's basis as a Z-axis rotation so it
## remains visible even when [Sprite3D] uses billboard mode.

@export_group("Variance")

## Half-range of the random Z offset applied to each item (metres).
## Items shift forward/backward by up to this amount from the shelf face.
## Example: 0.03 → items vary ± 3 cm in depth.
@export var depth_variance: float = 0.03

## Half-range of the random Z-axis tilt (roll) applied to each item (degrees).
## Layered on top of [member ItemData.tilt_offset_deg].
## Example: 3.0 → items lean ± 3° left or right.
@export var tilt_variance_deg: float = 3.0

## Minimum gap between item edges along the X axis (metres).
@export var item_gap: float = 0.01


func compute_positions(
		items: Array[ItemData],
		shelf_width: float) -> Array[Transform3D]:

	var result: Array[Transform3D] = []
	var cursor_x: float = 0.0

	for item in items:
		var item_w := _get_item_width(item)

		# Stop if this item would overflow the shelf surface
		if cursor_x + item_w > shelf_width:
			break

		# --- Position ---
		# Center of item along X; items sit ON the shelf surface (Y=0);
		# random Z shift for organic depth placement.
		var pos := Vector3(
			cursor_x + item_w * 0.5,
			0.0,
			randf_range(-depth_variance, depth_variance)
		)

		# --- Tilt (Z-axis roll) ---
		# Applied as Z-axis rotation so it's visible even with billboard sprites.
		# Composed of: random container variance + per-item personality.
		var roll_deg: float = (
			randf_range(-tilt_variance_deg, tilt_variance_deg)
			+ item.tilt_offset_deg
		)
		var basis := Basis(Vector3.FORWARD, deg_to_rad(roll_deg))

		result.append(Transform3D(basis, pos))

		cursor_x += item_w + item_gap

	return result


## Compute the real-world width of [param item] in metres.
func _get_item_width(item: ItemData) -> float:
	if item.display_width_override > 0.0:
		return item.display_width_override
	return item.display_height_meters * item.get_visual_aspect()


## Pre-generate one transform per slot across the full shelf width.
## Slots are evenly spaced by [param slot_width], with the same organic
## depth and tilt variance applied to each, so items always look natural
## regardless of whether they were placed at startup or dragged in later.
func generate_slots(shelf_width: float, slot_width: float) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var cursor := slot_width * 0.5
	while cursor + slot_width * 0.5 <= shelf_width:
		var pos := Vector3(
			cursor,
			0.0,
			randf_range(-depth_variance, depth_variance)
		)
		var roll_deg := randf_range(-tilt_variance_deg, tilt_variance_deg)
		var basis := Basis(Vector3.FORWARD, deg_to_rad(roll_deg))
		result.append(Transform3D(basis, pos))
		cursor += slot_width
	return result
