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
    
    if item.has_method("show_visuals"):
        item.show_visuals()
        
    # Snap item to center of tray (Vector3)
    var tween = create_tween()
    tween.tween_property(item, "global_position", global_position, 0.1)
    
    item_placed.emit(item)
    print("Item received in 3D Tray. Current count: ", _current_items.size())
