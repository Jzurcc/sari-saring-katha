class_name TransactionTray
extends Area3D

signal item_placed(item)


func _ready() -> void:
	add_to_group("transaction_tray")

func activate_dropzone() -> void:
	pass

func deactivate_dropzone() -> void:
	pass

func receive_item(item: DraggableItem) -> void:
	# Don't re-show 3D visuals — item came from 2D drag overlay.
	# MainGame._on_item_placed will either free or return the item.
	deactivate_dropzone()
	item_placed.emit(item)
	print("Item received in Tray: ", item.item_data.item_name if item.item_data else "unknown")
