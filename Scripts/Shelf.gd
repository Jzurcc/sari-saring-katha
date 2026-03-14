class_name Shelf
extends StaticBody3D

## Emitted when a player clicks the shelf (legacy — kept for compatibility).
signal pressed

@onready var area_3d: Area3D = $Area3D

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

## Grid layout settings for items on the shelf
@export var columns: int = 3
@export var row_spacing: float = 0.6
@export var col_spacing: float = 0.55
@export var item_offset: Vector3 = Vector3(0, 0.35, 0.3)  ## Offset from shelf center to first item

var _spawned_items: Array[DraggableItem] = []

func _ready() -> void:
	# Wait for InventoryManager to initialize
	await get_tree().process_frame
	InventoryManager.initialize()
	_spawn_items()

func _spawn_items() -> void:
	# Clear any existing spawned items
	for item in _spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	_spawned_items.clear()

	var shelf_items: Array[ItemData] = InventoryManager.get_items_by_type(ItemData.ItemType.SHELF)
	print("[Shelf] Spawning ", shelf_items.size(), " items")

	for i in range(shelf_items.size()):
		var item_data: ItemData = shelf_items[i]
		if not item_data.texture:
			print("[Shelf] Skipping item '", item_data.item_name, "' — no texture")
			continue
		if not InventoryManager.is_in_stock(item_data):
			continue

		var draggable: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
		add_child(draggable)

		# Position in a grid relative to the shelf
		var row: int = i / columns
		var col: int = i % columns
		# Center the columns: offset so the middle column is at x=0
		var x_offset: float = (col - (columns - 1) / 2.0) * col_spacing
		var y_offset: float = -row * row_spacing
		draggable.position = item_offset + Vector3(x_offset, y_offset, 0)

		draggable.setup(item_data)
		_spawned_items.append(draggable)
		print("[Shelf] Spawned '", item_data.item_name, "' at ", draggable.position)

## Called when an item is returned (drag cancelled) — reshow it.
func refresh_item_visibility() -> void:
	for item in _spawned_items:
		if is_instance_valid(item) and item.item_data:
			item.visible = InventoryManager.is_in_stock(item.item_data)
