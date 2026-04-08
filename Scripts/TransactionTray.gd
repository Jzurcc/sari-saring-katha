class_name TransactionTray
extends Area3D

signal item_placed(item)


func _ready() -> void:
	add_to_group("transaction_tray")

func receive_item(item: DraggableItem) -> void:
	item_placed.emit(item)
