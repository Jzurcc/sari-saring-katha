class_name Shelf
extends StaticBody3D

## A physical shelf unit that groups [ShelfSurface] children.
##
## This node is intentionally thin \u2014 it exists as a physics body,
## a scene group anchor, and a convenience coordinator for its surfaces.
##
## Add [ShelfSurface] nodes as children in the scene editor, positioned
## at the left edge of each physical plank. No runtime container creation
## occurs here; all item placement is handled by the [ShelfSurface] children.
##
## Previous exports (row_offsets, items_per_row, item_spacing) have been
## removed — configure each [ShelfSurface] individually in the Inspector.

## Refresh visibility on all [ShelfSurface] children.
## Call this after any transaction that changes stock levels.
func refresh_all() -> void:
	for child in get_children():
		if child is ShelfSurface:
			child.refresh_visibility()
