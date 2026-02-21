class_name TransactionTray
extends Area3D

signal item_placed(item: DraggableItem)

func _ready() -> void:
    add_to_group("transaction_tray")

func receive_item(item: DraggableItem) -> void:
    # Snap item to center of tray (Vector3)
    var tween = create_tween()
    tween.tween_property(item, "global_position", global_position, 0.1)
    
    item_placed.emit(item)
    print("Item received in 3D Tray")
