class_name FridgeLayoutStrategy
extends LayoutStrategy

## Neatly aligned layout strategy for fridge and cooler surfaces.
##
## Items are placed left-to-right in strict slots with zero organic variance.
## Perfect for upright glass-door fridges where beverages or frozen goods 
## are stacked in neat, structured rows without messy depth or tilt variations.

func compute_positions(
		_items: Array[ItemData],
		_shelf_width: float) -> Array[Transform3D]:
	# Currently unused by the new slot-based ShelfSurface logic, 
	# but stubbed out to cleanly inherit from LayoutStrategy.
	push_warning("[FridgeLayoutStrategy] compute_positions is deprecated on slot-based surfaces.")
	return []

## Pre-generate one transform per strict slot across the full shelf width.
## Slots are perfectly aligned by [param slot_width], with no messy random
## depth variance or tilt, creating a clean retail fridge presentation.
func generate_slots(shelf_width: float, slot_width: float) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var cursor := slot_width * 0.5
	
	while cursor + slot_width * 0.5 <= shelf_width:
		# Strict uniform placement: flat on Y=0, flush on Z=0 
		var pos := Vector3(cursor, 0.0, 0.0)
		# Absolutely no tilt
		var basis := Basis()
		
		result.append(Transform3D(basis, pos))
		cursor += slot_width
		
	return result
