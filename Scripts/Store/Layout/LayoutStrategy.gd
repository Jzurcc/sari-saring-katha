class_name LayoutStrategy
extends Resource
 
## Abstract base class for item placement strategies.
##
## Subclasses implement [method compute_positions] to define how items
## are laid out on a [ShelfSurface]. This design allows new container
## types (candy jars, hanging racks, fridges) to be added by creating
## a new LayoutStrategy subclass — no changes to ShelfSurface required.
##
## Current implementations:
## - [ProceduralPackStrategy]: Left-to-right bin packing with organic variance

## Returns one local [Transform3D] per item to place.
##
## All transforms are in the [ShelfSurface]'s local coordinate space.
## [param items]: items to place. Strategy stops when shelf runs out of room.
## [param shelf_width]: Usable width of the shelf in metres.
func compute_positions(
		_items: Array[ItemData],
		_shelf_width: float) -> Array[Transform3D]:
	push_warning("[LayoutStrategy] compute_positions() not overridden in " + get_class())
	return []


## Pre-generate transforms for every slot across the full shelf width.
## Returns one transform per slot even if no item occupies it.
## Used by [ShelfSurface] to enable positional drop targeting.
## [param shelf_width]: Usable width of the shelf in metres.
## [param slot_width]: Width of each slot in metres.
func generate_slots(
		_shelf_width: float,
		_slot_width: float) -> Array[Transform3D]:
	push_warning("[LayoutStrategy] generate_slots() not overridden in " + get_class())
	return []
