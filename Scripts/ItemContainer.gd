class_name ItemContainer
extends Node3D

## A modular item container for the sari-sari store.
##
## Place this node where items should be displayed. The node's origin
## represents the CENTER-BOTTOM of the container area — items are
## arranged horizontally along the local X axis with their sprites
## bottom-aligned to this Y level.
##
## Configure [member accepted_type] and [member accepted_categories]
## to filter which items can appear in this container.

# --- Layout ---

@export_group("Layout")

## Maximum number of item slots in this container.
@export var slot_count: int = 5

## Distance between item centers along the X axis (meters).
@export var slot_spacing: float = 0.25

# --- Filtering ---

@export_group("Filtering")

## Which ItemData.ItemType this container accepts.
@export var accepted_type: ItemData.ItemType = ItemData.ItemType.SHELF

## Optional category filter. Empty array = accept all categories.
@export var accepted_categories: PackedStringArray = []

# --- Internal ---

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

var _spawned_items: Array[DraggableItem] = []


## Populate the container with items from [InventoryManager] that match
## this container's type and category filters.
func populate() -> void:
	clear()
	var candidates := _get_matching_items()
	var count := mini(candidates.size(), slot_count)

	for i in range(count):
		var item_data: ItemData = candidates[i]
		if not item_data.texture:
			continue

		var draggable: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
		add_child(draggable)

		# Pass the slot transform directly into setup() so _original_transform
		# is set correctly. Setting position before setup() would be overwritten
		# by the Transform3D.IDENTITY default inside setup().
		var slot_pos := _get_slot_position(i, count)
		var slot_transform := Transform3D(Basis(), slot_pos)
		draggable.setup(item_data, slot_transform)
		_spawned_items.append(draggable)

	print("[ItemContainer] '%s' populated with %d/%d slots" % [name, _spawned_items.size(), slot_count])


## Remove all item instances spawned by this container.
func clear() -> void:
	for item in _spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	_spawned_items.clear()


## Refresh item visibility based on current inventory stock.
func refresh_visibility() -> void:
	for item in _spawned_items:
		if is_instance_valid(item) and item.item_data:
			item.visible = InventoryManager.is_in_stock(item.item_data)


## Calculate the local position of a slot, centered around X=0.
## [param index]: Slot index (0-based).
## [param total]: Total number of items being placed.
func _get_slot_position(index: int, total: int) -> Vector3:
	var x_offset: float = (index - (total - 1) / 2.0) * slot_spacing
	return Vector3(x_offset, 0.0, 0.0)


## Query [InventoryManager] for items matching this container's filters.
func _get_matching_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		# Type filter
		if item.type != accepted_type:
			continue
		# Category filter (empty = accept all)
		if accepted_categories.size() > 0 and item.category not in accepted_categories:
			continue
		# Stock filter
		if not InventoryManager.is_in_stock(item):
			continue
		result.append(item)
	return result
