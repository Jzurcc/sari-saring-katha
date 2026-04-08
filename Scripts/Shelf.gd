class_name Shelf
extends StaticBody3D

## A shelf unit that manages ItemContainer rows.
##
## Each row of the physical shelf model is represented by an [ItemContainer]
## child node. Configure [member row_offsets] to define where each row's
## container is placed relative to the shelf's origin.

@warning_ignore("unused_signal")
signal pressed

## Offset positions for each shelf row container (local space).
## Each entry creates one [ItemContainer] at that position.
## The Y component should match the shelf surface height for that row.
@export var row_offsets: Array[Vector3] = [Vector3(0.0, 0.35, 0.3)]

## Number of item slots per row.
@export var items_per_row: int = 3

## Horizontal spacing between items within a row (meters).
@export var item_spacing: float = 0.55

@onready var area_3d: Area3D = $Area3D

var _containers: Array[ItemContainer] = []


func _ready() -> void:
	# Disable the shelf's own Area3D collision so it doesn't intercept
	# raycasts meant for the DraggableItem children in front of it.
	if area_3d:
		area_3d.collision_layer = 0
		area_3d.collision_mask = 0

	# Wait one frame for InventoryManager autoload to finish initializing.
	await get_tree().process_frame
	_create_containers()


func _create_containers() -> void:
	for i in range(row_offsets.size()):
		var container := ItemContainer.new()
		container.name = "Row_%d" % i
		container.slot_count = items_per_row
		container.slot_spacing = item_spacing
		container.accepted_type = ItemData.ItemType.SHELF
		container.position = row_offsets[i]

		add_child(container)
		container.populate()
		_containers.append(container)

	print("[Shelf] Created %d row containers" % _containers.size())


## Refresh visibility of items across all row containers.
func refresh_all() -> void:
	for container in _containers:
		if is_instance_valid(container):
			container.refresh_visibility()
