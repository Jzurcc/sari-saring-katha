class_name TransactionTray
extends Area3D

signal item_placed(item)

# Maximum capacity of items the tray can hold
const MAX_CAPACITY: int = 10

# Track current items in tray for capacity management
var _current_items: Array[DraggableItem] = []

func _ready() -> void:
	add_to_group("transaction_tray")

func receive_item(item: DraggableItem) -> void:
	# Capacity validation: Don't accept more items than MAX_CAPACITY
	if _current_items.size() >= MAX_CAPACITY:
		print("TransactionTray is full! Cannot accept more items.")
		return
	
	# Track the new item
	_current_items.append(item)
	
	# Don't re-show 3D visuals — item came from 2D drag overlay.
	# MainGame._on_item_placed will either free or return the item.
	
	item_placed.emit(item)
	print("Item received in Tray: ", item.item_data.item_name if item.item_data else "unknown")
