class_name TransactionTray
extends Area3D

signal item_placed(item)


func _ready() -> void:
	# Items are handed directly to customers (multi-slot counter); disable tray collision so it never blocks drops.
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	hide()

func receive_item(item: DraggableItem) -> void:
	EventBus.request_sfx.emit("drop")
	item_placed.emit(item)
	EventBus.tray_item_placed.emit(item, global_position)
