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
## All transforms are in the [ShelfSurface]'s local coordinate space:
## - X axis: runs left-to-right along the shelf plank
## - Y axis: vertical (items extend upward from Y=0 shelf surface)
## - Z axis: depth (positive = toward viewer)
##
## [param items]: Ordered list of [ItemData] to place. Strategy may place
##                fewer than all items if the surface runs out of room.
## [param shelf_width]: Usable width of the shelf surface in metres.
## [param max_items]: Hard cap on how many items to place regardless of space.
func compute_positions(
		_items: Array[ItemData],
		_shelf_width: float,
		_max_items: int) -> Array[Transform3D]:
	push_warning("[LayoutStrategy] compute_positions() not overridden in " + get_class())
	return []
